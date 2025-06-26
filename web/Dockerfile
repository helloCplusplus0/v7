# ===== 🏗️ 构建阶段 =====
FROM node:18-alpine AS builder

# 📦 设置工作目录
WORKDIR /build

# 🔧 复制package文件并安装依赖
COPY package*.json ./
RUN npm ci --only=production

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

# 📁 创建必要目录并设置权限
RUN mkdir -p /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp \
             /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp \
             /var/log/nginx \
             /var/run \
             /usr/share/nginx/html && \
    chown -R appuser:appgroup /var/cache/nginx \
                              /var/log/nginx \
                              /var/run \
                              /usr/share/nginx/html \
                              /etc/nginx && \
    chmod -R 755 /var/cache/nginx \
                 /var/log/nginx \
                 /var/run \
                 /usr/share/nginx/html \
                 /etc/nginx

# 🔧 复制静态nginx配置
COPY --chown=appuser:appgroup nginx.conf /etc/nginx/nginx.conf

# 📦 从构建阶段复制静态文件
COPY --from=builder --chown=appuser:appgroup /build/dist/ /usr/share/nginx/html/

# 🌍 设置环境变量
ENV NODE_ENV=production

# 🔌 暴露非特权端口
EXPOSE 8080

# 👤 切换到非特权用户
USER appuser:appgroup

# 🏥 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# 🏷️ 镜像标签
LABEL maintainer="hellocplusplus0" \
      app="v7-web" \
      version="latest" \
      architecture="podman" \
      description="V7 Web - SolidJS + Web v7 Architecture (Simplified)" \
      node.version="18" \
      nginx.version="1.25" \
      nginx.port="8080"

# 🚀 启动命令
CMD ["nginx", "-g", "daemon off;"] 