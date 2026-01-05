FROM node:18-alpine AS build
WORKDIR /app

# Install dependencies
COPY package.json ./
RUN npm install

# Copy source and build
COPY . .

# Fix OpenSSL issue
ENV NODE_OPTIONS=--openssl-legacy-provider

RUN npm run build

FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html

# Optional: expose port 80 and run nginx in foreground
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
