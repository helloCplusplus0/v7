# 🚀 V7 Web Podman 优化镜像
# 多阶段构建 - 专为轻量化和极致性能设计

# ===== 🏗️ 构建阶段 =====
FROM node:18-alpine AS builder

# 📦 安装构建依赖
RUN apk add --no-cache \
    git \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

# 📁 创建工作目录
WORKDIR /build

# 📦 复制依赖文件（利用Docker层缓存）
COPY package.json package-lock.json ./

# 🔨 安装依赖（构建环境需要全部依赖）
RUN npm ci --no-audit --no-fund && \
    npm cache clean --force

# 📁 复制源代码
COPY . .

# 🏗️ 构建应用程序
RUN npm run build && \
    ls -la dist/ && \
    du -sh dist/

# 🧹 清理构建缓存
RUN rm -rf node_modules/.cache

# ===== 🌐 Nginx配置阶段 =====
FROM nginx:1.25-alpine AS nginx-config

# 🔧 创建支持环境变量的Nginx配置模板
RUN cat > /etc/nginx/nginx.conf.template << 'EOF'
# 🚀 V7 Web Nginx 配置 - 支持环境变量的版本
user ${NGINX_USER};
worker_processes ${NGINX_WORKER_PROCESSES};
worker_rlimit_nofile 65535;

error_log /var/log/nginx/error.log ${NGINX_LOG_LEVEL};
pid /var/run/nginx.pid;

events {
    worker_connections ${NGINX_WORKER_CONNECTIONS};
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 📊 日志格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # 🚀 性能优化
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 16M;

    # 🗜️ 压缩配置
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

    # 🔒 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # 📁 包含站点配置
    include /etc/nginx/conf.d/*.conf;
}
EOF

# 🔧 创建支持环境变量的站点配置模板
RUN cat > /etc/nginx/conf.d/default.conf.template << 'EOF'
# 🌐 V7 Web 站点配置 - 支持环境变量
server {
    listen ${NGINX_PORT};
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # 📊 访问日志
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log ${NGINX_LOG_LEVEL};

    # 🏥 健康检查端点
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # 🎯 SPA路由支持
    location / {
        try_files $uri $uri/ /index.html;
        expires 1h;
        add_header Cache-Control "public, immutable";
    }

    # 📦 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # 🔧 API代理（如果需要）
    location /api/ {
        proxy_pass ${BACKEND_URL}/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }

    # 🔒 安全配置
    location ~ /\. {
        deny all;
    }

    location ~ ~$ {
        deny all;
    }
}
EOF

# 🔧 创建配置生成脚本
RUN cat > /docker-entrypoint.d/30-generate-config.sh << 'EOF'
#!/bin/sh
set -e

# 设置默认值
export NGINX_USER=${NGINX_USER:-nginx}
export NGINX_PORT=${NGINX_PORT:-8080}
export NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-auto}
export NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-1024}
export NGINX_LOG_LEVEL=${NGINX_LOG_LEVEL:-warn}
export BACKEND_URL=${BACKEND_URL:-http://backend:3000}

echo "🔧 生成Nginx配置文件..."
echo "   端口: $NGINX_PORT"
echo "   用户: $NGINX_USER"
echo "   后端: $BACKEND_URL"

# 使用envsubst生成最终配置
envsubst '${NGINX_USER} ${NGINX_PORT} ${NGINX_WORKER_PROCESSES} ${NGINX_WORKER_CONNECTIONS} ${NGINX_LOG_LEVEL} ${BACKEND_URL}' \
    < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

envsubst '${NGINX_PORT} ${NGINX_LOG_LEVEL} ${BACKEND_URL}' \
    < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

echo "✅ Nginx配置生成完成"
EOF

RUN chmod +x /docker-entrypoint.d/30-generate-config.sh

# ===== 🏃 运行阶段 =====
FROM nginx:1.25-alpine AS runtime

# 📦 安装运行时依赖
RUN apk add --no-cache \
    curl \
    tzdata \
    gettext \
    && rm -rf /var/cache/apk/*

# 👤 创建应用用户（避免ID冲突）
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

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
                              /etc/nginx/conf.d && \
    chmod -R 755 /var/cache/nginx \
                 /var/log/nginx \
                 /var/run \
                 /usr/share/nginx/html

# 🔧 从nginx配置阶段复制配置模板和脚本
COPY --from=nginx-config /etc/nginx/nginx.conf.template /etc/nginx/nginx.conf.template
COPY --from=nginx-config /etc/nginx/conf.d/default.conf.template /etc/nginx/conf.d/default.conf.template
COPY --from=nginx-config /docker-entrypoint.d/30-generate-config.sh /docker-entrypoint.d/30-generate-config.sh

# 📦 从构建阶段复制静态文件
COPY --from=builder --chown=appuser:appgroup /build/dist/ /usr/share/nginx/html/

# 🌍 设置环境变量（默认值）
ENV NODE_ENV=production
ENV NGINX_USER=appuser
ENV NGINX_PORT=8080
ENV NGINX_WORKER_PROCESSES=auto
ENV NGINX_WORKER_CONNECTIONS=1024
ENV NGINX_LOG_LEVEL=warn
ENV BACKEND_URL=http://backend:3000

# 🔌 暴露非特权端口
EXPOSE 8080

# 👤 切换到非特权用户
USER appuser:appgroup

# 🏥 健康检查（使用环境变量端口）
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${NGINX_PORT}/health || exit 1

# 🏷️ 镜像标签
LABEL maintainer="hellocplusplus0" \
      app="v7-web" \
      version="latest" \
      architecture="podman" \
      description="V7 Web - SolidJS + Web v7 Architecture (Non-privileged)" \
      node.version="18" \
      nginx.version="1.25" \
      nginx.port="8080"

# 🚀 启动命令（nginx会自动执行entrypoint脚本）
CMD ["nginx", "-g", "daemon off;"]

# 📝 构建说明
# 
# 🏗️ 构建命令:
#   podman build -t v7-web:latest -f Dockerfile .
# 
# 🚀 运行命令:
#   podman run -d \
#     --name v7-web \
#     -p 8080:8080 \
#     -e NGINX_PORT=8080 \
#     -e BACKEND_URL=http://backend:3000 \
#     v7-web:latest
# 
# 🔍 镜像信息:
#   podman inspect v7-web:latest
# 
# 🧪 测试健康检查:
#   podman exec v7-web curl -f http://localhost:8080/health
# 
# 📊 性能优化特性:
# - 多阶段构建 (减小最终镜像大小)
# - Nginx 高性能配置
# - Gzip 压缩启用
# - 静态资源缓存优化
# - SPA 路由支持
# - 依赖缓存优化
# 
# 🔒 安全特性:
# - 非特权用户运行 (appuser:appgroup)
# - 非特权端口 (8080)
# - 安全头配置
# - 隐藏文件保护
# - Content Security Policy
# - 环境变量配置支持
# 
# 🎯 最佳实践特性:
# - 支持环境变量动态配置
# - 非特权端口避免权限问题
# - 正确的文件权限设置
# - 健康检查适配动态端口
# - 符合容器安全标准 