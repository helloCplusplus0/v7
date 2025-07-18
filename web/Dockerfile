# 🚀 V7 Web 前端优化镜像
# SolidJS + TypeScript + Vite 应用容器化部署
# 轻量化、极致性能、安全强化的多阶段构建

# 📐 构建参数（参数化管理）
ARG NODE_VERSION=18
ARG NGINX_VERSION=1.25-alpine
ARG WEB_PORT=8080
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

# 📐 运行时参数（重新声明，保持一致）
ARG WEB_PORT=8080
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

# 📁 一次性创建所有必要目录并设置权限（优化镜像层）
RUN mkdir -p /usr/share/nginx/html \
             /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp \
             /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp \
             /var/log/nginx \
             /var/run \
    && chown -R ${WEB_USER}:webgroup \
              /usr/share/nginx/html \
              /var/cache/nginx \
              /var/log/nginx \
              /var/run \
    && chmod 755 /usr/share/nginx/html \
                 /var/cache/nginx \
                 /var/log/nginx \
                 /var/run

# 📦 从构建阶段复制静态文件
COPY --from=builder --chown=${WEB_USER}:webgroup /app/dist /usr/share/nginx/html

# 📦 复制nginx配置文件
COPY --chown=${WEB_USER}:webgroup nginx.conf /etc/nginx/nginx.conf

# 🌍 设置运行时环境变量
ENV NODE_ENV=production \
    PORT=${WEB_PORT} \
    NGINX_USER=${WEB_USER}

# 🔌 暴露端口
EXPOSE ${WEB_PORT}

# 📁 数据卷（日志和缓存）
VOLUME ["/var/log/nginx", "/var/cache/nginx"]

# 👤 切换到非特权用户
USER ${WEB_USER}:webgroup

# 🏥 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${WEB_PORT}/health || exit 1

# 🏷️ 镜像标签
LABEL maintainer="v7-team" \
      app="v7-web" \
      version="v7-solidjs" \
      description="V7 Web Frontend - SolidJS + TypeScript + Vite + nginx" \
      architecture="solidjs+typescript+vite" \
      optimization="vite-build+nginx-static+multi-stage" \
      security="non-root+minimal-deps" \
      performance="static-assets+gzip+caching" \
      ports.http="${WEB_PORT}"

# 🚀 启动命令
CMD ["nginx", "-g", "daemon off;"] 