resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-lt-"
  image_id      = aws_instance.app_server.ami
  instance_type = "t3.micro"

  vpc_security_group_ids = [
    aws_security_group.app_sg.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo snap install aws-cli --classic
    sudo apt-get install -y curl unzip awscli

    
    # Install and configure services
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    sudo apt-get install -y git

    # Create default web page
    echo "Hello from Auto Scaling EC2" > /var/www/html/index.html

    # create app config directory
    mkdir -p /opt/stan

    # Retrieve secrets from AWS Systems Manager Parameter Store
    JWT_SECRET=$(aws ssm get-parameter \
      --name "/app/prod/jwt_secret" \
      --with-decryption \
      --query "Parameter.Value" \
      --output text \
      --region eu-north-1)

    MONGO_URI=$(aws ssm get-parameter \
      --name "/app/prod/mongo_uri" \
      --with-decryption \
      --query "Parameter.Value" \
      --output text \
      --region eu-north-1)
    
    cat > /opt/stan/.env <<ENVEOF
    
    JWT_SECRET=$JWT_SECRET
    MONGO_CONN_STR=$MONGO_URI
    PORT=3500
    
    ENVEOF
    
    #log in to ECR and pull the Docker image
    aws ecr get-login-password --region eu-north-1 | sudo docker login --username AWS --password-stdin 969759464709.dkr.ecr.eu-north-1.amazonaws.com

    # Pull backend image (example v2)
 
    docker pull 969759464709.dkr.ecr.eu-north-1.amazonaws.com/production-ec2-infrastructure-backend:v2

    # Run container
    docker run -d \
      --env-file /opt/stan/.env \
      -p 3500:3500 \
      --restart always \
      --name backend \
      969759464709.dkr.ecr.eu-north-1.amazonaws.com/production-ec2-infrastructure-backend:v2

  EOF

  )



  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "autoscaling-app"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }
}