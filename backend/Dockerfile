FROM node:20-alpine

WORKDIR /app

# Cài đặt build tools cho native addons (bcrypt) nếu cần biên dịch trên môi trường Alpine musl
RUN apk add --no-cache python3 make g++

# Cài đặt dependencies chuẩn xác theo lockfile
COPY package*.json ./
RUN npm ci

# Copy mã nguồn (được bảo vệ bởi .dockerignore, không copy node_modules từ Windows)
COPY . .

# Biên dịch TypeScript sang JavaScript
RUN npm run build

# Đảm bảo thư mục lưu trữ ảnh uploads tồn tại
RUN mkdir -p /app/uploads

EXPOSE 3000

CMD ["npm", "start"]
