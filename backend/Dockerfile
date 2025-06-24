# 🚀 V7 Backend Podman 优化镜像
# 多阶段构建 - 专为轻量化和极致性能设计

# ===== 🏗️ 构建阶段 =====
FROM rust:1.87-alpine AS builder

# 📦 安装构建依赖
RUN apk add --no-cache \
    musl-dev \
    pkgconfig \
    openssl-dev \
    openssl-libs-static \
    sqlite-dev \
    sqlite-static \
    build-base \
    curl \
    && rm -rf /var/cache/apk/*

# 🔧 设置构建环境变量
ENV RUSTFLAGS="-C target-feature=+crt-static -C link-arg=-static-pie"
ENV PKG_CONFIG_ALLOW_CROSS=1
ENV OPENSSL_STATIC=1
ENV OPENSSL_DIR=/usr

# 📁 创建工作目录
WORKDIR /build

# 📦 复制依赖文件（利用Docker层缓存）
COPY Cargo.toml Cargo.lock build.rs ./
COPY src/main.rs src/main.rs

# 🔨 预构建依赖（缓存优化）
RUN mkdir -p src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release --target x86_64-unknown-linux-musl && \
    rm -rf src

# 📁 复制源代码
COPY src/ src/

# 🏗️ 构建应用程序 - 启用所有优化
RUN cargo build \
    --release \
    --target x86_64-unknown-linux-musl \
    --config "profile.release.lto=true" \
    --config "profile.release.codegen-units=1" \
    --config "profile.release.panic='abort'" \
    --config "profile.release.strip=true" \
    && cp target/x86_64-unknown-linux-musl/release/backend /build/v7-backend

# 🔍 验证二进制文件
RUN file /build/v7-backend && \
    ldd /build/v7-backend || echo "Static binary - no dynamic dependencies" && \
    ls -la /build/v7-backend

# ===== 🏃 运行阶段 =====
FROM alpine:3.19 AS runtime

# 📦 安装运行时依赖（最小化）
RUN apk add --no-cache \
    ca-certificates \
    curl \
    tzdata \
    && rm -rf /var/cache/apk/*

# 👤 创建非特权用户
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# 📁 创建应用目录
RUN mkdir -p /app/{data,logs,config} && \
    chown -R appuser:appgroup /app

# 📋 设置工作目录
WORKDIR /app

# 📦 从构建阶段复制二进制文件
COPY --from=builder --chown=appuser:appgroup /build/v7-backend /app/backend

# 🔧 设置执行权限
RUN chmod +x /app/backend

# 🌍 设置环境变量
ENV RUST_LOG=info
ENV DATABASE_URL=sqlite:./data/prod.db
ENV PORT=3000
ENV RUST_BACKTRACE=1

# 🔌 暴露端口
EXPOSE 3000

# 👤 切换到非特权用户
USER appuser:appgroup

# 🏥 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# 🏷️ 镜像标签
LABEL maintainer="hellocplusplus0" \
      app="v7-backend" \
      version="latest" \
      architecture="podman" \
      description="V7 Backend - Rust + FMOD v7 Architecture" \
      rust.version="1.87" \
      build.optimization="lto+strip+static"

# 🚀 启动命令
ENTRYPOINT ["/app/backend"]

# 📝 构建说明
# 
# 🏗️ 构建命令:
#   podman build -t v7-backend:latest -f Dockerfile .
# 
# 🚀 运行命令:
#   podman run -d \
#     --name v7-backend \
#     -p 3000:3000 \
#     -v ./data:/app/data:Z \
#     -e RUST_LOG=info \
#     v7-backend:latest
# 
# 🔍 镜像信息:
#   podman inspect v7-backend:latest
# 
# 🧪 测试健康检查:
#   podman exec v7-backend curl -f http://localhost:3000/health
# 
# 📊 性能优化特性:
# - 静态链接二进制文件 (无动态依赖)
# - LTO (链接时优化)
# - Strip symbols (减小二进制大小)
# - Alpine Linux (最小基础镜像)
# - 多阶段构建 (减小最终镜像大小)
# - 依赖缓存优化 (加快构建速度)
# 
# 🔒 安全特性:
# - 非特权用户运行
# - 只读文件系统支持
# - 最小化攻击面
# - 健康检查内置 