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

# 📦 安装运行时依赖
RUN apk add --no-cache \
    curl \
    tzdata \
    && rm -rf /var/cache/apk/*

# 👤 创建应用用户（使用与部署环境一致的ID）
RUN addgroup -g 1002 -S appgroup && \
    adduser -u 1002 -S appuser -G appgroup

# 📁 为nginx创建必要的目录和权限 - 使用标准路径
RUN mkdir -p /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp \
             /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp \
             /var/log/nginx \
             /var/run \
             /usr/share/nginx/html && \
    # 修改nginx配置目录权限
    chown -R appuser:appgroup /var/cache/nginx \
                              /var/log/nginx \
                              /var/run \
                              /usr/share/nginx/html \
                              /etc/nginx/conf.d && \
    # 创建nginx.pid文件并设置权限
    touch /var/run/nginx.pid && \
    chown appuser:appgroup /var/run/nginx.pid && \
    chmod 644 /var/run/nginx.pid

# 📦 复制构建产物
COPY --from=builder --chown=appuser:appgroup /build/dist /usr/share/nginx/html

# 🔧 复制nginx配置
COPY --chown=appuser:appgroup nginx.conf /etc/nginx/nginx.conf

# 👤 切换到非特权用户
USER appuser

# 🚀 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# 📡 暴露端口（使用8080避免特权端口）
EXPOSE 8080

# 🏃 启动命令
CMD ["nginx", "-g", "daemon off;"] 