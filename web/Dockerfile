# ===== 🏗️ 构建阶段 =====
FROM node:18-alpine AS builder

# 📦 设置工作目录
WORKDIR /build

# 🔧 复制package文件并安装所有依赖（包括开发依赖）
COPY package*.json ./
RUN npm ci

# 📦 复制源代码
COPY . .

# 🌍 设置构建环境变量
ENV NODE_ENV=production
ENV VITE_API_BASE_URL=/api

# 🏗️ 构建应用
RUN npm run build

# ===== 🏃 运行阶段 =====
FROM nginx:1.25-alpine AS runtime

# 📦 安装运行时依赖和dumb-init
RUN apk add --no-cache \
    curl \
    tzdata \
    dumb-init \
    && rm -rf /var/cache/apk/*

# 🔧 复制nginx配置文件
COPY nginx.conf /etc/nginx/nginx.conf

# 👤 创建nginxuser用户（基于Docker Forums最佳实践）
RUN adduser --system --uid 1002 --no-create-home --disabled-login --group nginxuser

# 📁 设置nginx目录权限（基于专家建议）
RUN chown -R nginxuser:nginxuser /var/cache/nginx \
    && chown -R nginxuser:nginxuser /var/log/nginx \
    && chown -R nginxuser:nginxuser /etc/nginx/conf.d \
    && touch /var/run/nginx.pid \
    && chown -R nginxuser:nginxuser /var/run/nginx.pid

# 📦 复制构建产物到nginx默认目录
COPY --from=builder --chown=nginxuser:nginxuser /build/dist /usr/share/nginx/html

# 👤 切换到非特权用户
USER nginxuser

# 🌐 暴露8080端口（非特权端口）
EXPOSE 8080

# 🚀 使用dumb-init启动nginx
ENTRYPOINT ["dumb-init", "nginx", "-g", "daemon off;"] 