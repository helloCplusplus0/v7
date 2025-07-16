# 🚀 V7 Web 前端优化镜像
# SolidJS + TypeScript + Vite 应用容器化部署
# 轻量化、极致性能、安全强化的多阶段构建

# 📐 构建参数（参数化管理）
ARG NODE_VERSION=18
ARG NGINX_VERSION=1.25-alpine
ARG WEB_PORT=3000
ARG WEB_USER=appuser
ARG WEB_UID=1003
ARG WEB_GID=1003

# ===== 🏗️ 依赖安装阶段 =====
FROM node:${NODE_VERSION}-alpine AS deps

# 📦 安装构建依赖
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# 📦 复制依赖配置文件（缓存优化）
COPY package.json package-lock.json ./

# 🔧 安装全部依赖（包括开发依赖，修复构建错误）
RUN npm ci --verbose && \
    npm cache clean --force

# ===== 🏗️ 构建阶段 =====
FROM node:${NODE_VERSION}-alpine AS builder

WORKDIR /app

# 📦 从依赖阶段复制node_modules
COPY --from=deps /app/node_modules ./node_modules

# 📁 复制源代码
COPY . .

# 🔧 设置构建环境变量
ENV NODE_ENV=production
ENV VITE_BUILD_TARGET=production

# 🏗️ 构建应用（优化构建过程）
RUN npm run build && \
    npm run type-check && \
    find dist -name "*.map" -delete && \
    ls -la dist/

# 🔍 验证构建产物
RUN test -f dist/index.html || (echo "❌ Build failed: index.html not found" && exit 1) && \
    echo "✅ Build successful: $(du -sh dist/)"

# ===== 🏃 生产运行阶段 =====
FROM nginx:${NGINX_VERSION} AS runtime

# 📐 运行时参数（重新声明）
ARG WEB_PORT=3000
ARG WEB_USER=appuser
ARG WEB_UID=1003
ARG WEB_GID=1003

# 📦 安装最小运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    && rm -rf /var/cache/apk/* \
    && rm -rf /etc/nginx/conf.d/default.conf

# 👤 创建非特权用户（安全最佳实践）
RUN addgroup -g ${WEB_GID} -S webgroup && \
    adduser -u ${WEB_UID} -S ${WEB_USER} -G webgroup -D

# 📁 创建应用目录结构（权限优化）
RUN mkdir -p /usr/share/nginx/html && \
    mkdir -p /var/cache/nginx && \
    mkdir -p /var/log/nginx && \
    mkdir -p /tmp/nginx && \
    chown -R ${WEB_USER}:webgroup /usr/share/nginx/html && \
    chown -R ${WEB_USER}:webgroup /var/cache/nginx && \
    chown -R ${WEB_USER}:webgroup /var/log/nginx && \
    chown -R ${WEB_USER}:webgroup /tmp/nginx && \
    chmod 755 /usr/share/nginx/html

# 📦 从构建阶段复制静态文件
COPY --from=builder --chown=${WEB_USER}:webgroup /app/dist /usr/share/nginx/html

# 🔧 创建优化的nginx配置
RUN cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
pid /tmp/nginx/nginx.pid;

error_log /var/log/nginx/error.log warn;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 日志格式优化
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # 性能优化
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 16M;

    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    server {
        listen WEB_PORT_PLACEHOLDER;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;

        # 静态资源缓存
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            try_files $uri =404;
        }

        # SPA路由支持
        location / {
            try_files $uri $uri/ /index.html;
        }

        # 健康检查
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # 安全配置
        location ~ /\. {
            deny all;
        }
    }
}
EOF

# 🔧 替换端口占位符
RUN sed -i "s/WEB_PORT_PLACEHOLDER/${WEB_PORT}/g" /etc/nginx/nginx.conf

# 🌍 设置环境变量
ENV NGINX_PORT=${WEB_PORT}

# 🔌 暴露端口
EXPOSE ${WEB_PORT}

# 📁 数据卷（日志和缓存）
VOLUME ["/var/log/nginx", "/tmp/nginx"]

# 👤 切换到非特权用户
USER ${WEB_USER}:webgroup

# 🏥 健康检查（轻量化）
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${WEB_PORT}/health || exit 1

# 🏷️ 镜像标签（详细元数据）
LABEL maintainer="v7-team" \
      app="v7-web" \
      version="v7-optimized" \
      architecture="solidjs+typescript+vite" \
      description="V7 Web Frontend - SolidJS + TypeScript + Vite with nginx" \
      node.version="${NODE_VERSION}" \
      nginx.version="${NGINX_VERSION}" \
      optimization="multi-stage+gzip+cache+security" \
      security="non-root+csp+xss-protection" \
      performance="extreme+static-cache" \
      port="${WEB_PORT}"

# 🚀 启动命令
CMD ["nginx", "-g", "daemon off;"] 