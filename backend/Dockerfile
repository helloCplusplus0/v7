# 🚀 V7 Backend Podman 优化镜像
# 多阶段构建 - 专为轻量化和极致性能设计

# 📐 构建参数（参数化管理）
ARG RUST_VERSION=1.87
ARG ALPINE_VERSION=3.19
ARG TARGET_ARCH=x86_64-unknown-linux-musl
ARG BACKEND_PORT=3000
ARG GRPC_PORT=50053
ARG APP_USER=appuser
ARG APP_UID=1002
ARG APP_GID=1002

# ===== 🏗️ 构建阶段 =====
FROM rust:${RUST_VERSION}-alpine AS builder

# 📐 重新声明构建参数（多阶段构建需要）
ARG TARGET_ARCH=x86_64-unknown-linux-musl

# 📦 安装构建依赖
RUN apk add --no-cache \
    musl-dev \
    pkgconfig \
    openssl-dev \
    openssl-libs-static \
    sqlite-dev \
    sqlite-static \
    build-base \
    protobuf-dev \
    bash \
    coreutils \
    && rm -rf /var/cache/apk/*

# 🛠️ 修复/tmp权限和空间问题
RUN mkdir -p /tmp && chmod 1777 /tmp
ENV TMPDIR=/tmp

# 🔧 设置构建环境变量（增强优化）
ENV RUSTFLAGS="-C target-feature=+crt-static -C link-arg=-static-pie -C target-cpu=native"
ENV PKG_CONFIG_ALLOW_CROSS=1
ENV OPENSSL_STATIC=1
ENV OPENSSL_DIR=/usr
ENV CARGO_NET_GIT_FETCH_WITH_CLI=true

# 📁 创建工作目录
WORKDIR /build

# 📦 复制依赖文件（利用Docker层缓存）
COPY Cargo.toml Cargo.lock build.rs ./
COPY proto/ proto/

# 🔨 预构建依赖（缓存优化）- 正确处理混合项目
RUN mkdir -p src && \
    echo "fn main() {}" > src/main.rs && \
    echo "// Dummy lib for dependency caching" > src/lib.rs && \
    cargo build --release --target ${TARGET_ARCH} && \
    rm -rf src target/${TARGET_ARCH}/release/deps/fmod*

# 📁 复制源代码
COPY src/ src/

# 🏗️ 构建应用程序 - 启用所有优化
RUN cargo build \
    --release \
    --target ${TARGET_ARCH} \
    --config "profile.release.lto=true" \
    --config "profile.release.codegen-units=1" \
    --config "profile.release.panic='abort'" \
    --config "profile.release.strip=true" \
    --config "profile.release.opt-level=3" \
    && cp target/${TARGET_ARCH}/release/fmod_slice /build/v7-backend

# 🔍 验证二进制文件
RUN file /build/v7-backend && \
    ldd /build/v7-backend || echo "✅ Static binary - no dynamic dependencies" && \
    ls -lh /build/v7-backend

# ===== 🏃 运行阶段 =====
FROM alpine:${ALPINE_VERSION} AS runtime

# 📦 安装运行时依赖（最小化，移除curl）
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    && rm -rf /var/cache/apk/*

# 👤 创建非特权用户（参数化用户配置）
RUN addgroup -g ${APP_GID} -S appgroup && \
    adduser -u ${APP_UID} -S ${APP_USER} -G appgroup

# 📁 创建应用目录（增强权限管理）
RUN mkdir -p /app/{data,logs,config,tmp} && \
    mkdir -p /tmp/app-runtime && \
    chown -R ${APP_USER}:appgroup /app /tmp/app-runtime && \
    chmod 755 /app && \
    chmod 750 /app/data /app/logs /app/config && \
    chmod 755 /app/tmp

# 📋 设置工作目录
WORKDIR /app

# 📦 从构建阶段复制二进制文件
COPY --from=builder --chown=${APP_USER}:appgroup /build/v7-backend /app/backend

# 🔧 设置执行权限（安全优化）
RUN chmod 755 /app/backend

# 🌍 设置环境变量（参数化端口配置）
ENV RUST_LOG=info \
    DATABASE_URL=sqlite:/app/data/prod.db \
    HTTP_PORT=${BACKEND_PORT} \
    GRPC_PORT=${GRPC_PORT} \
    RUST_BACKTRACE=1 \
    MALLOC_ARENA_MAX=2 \
    MALLOC_TRIM_THRESHOLD_=131072

# 🔌 暴露端口（参数化）
EXPOSE ${BACKEND_PORT} ${GRPC_PORT}

# 📁 数据卷（只读文件系统支持）
VOLUME ["/app/data", "/app/logs", "/tmp/app-runtime"]

# 👤 切换到非特权用户
USER ${APP_USER}:appgroup

# 🏥 健康检查（移除外部依赖，使用内建健康检查）
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /app/backend --health-check 2>/dev/null || exit 1

# 🏷️ 镜像标签（增强元数据）
LABEL maintainer="v7-team" \
      app="v7-backend" \
      version="v7-optimized" \
      architecture="rust+fmod-v7" \
      description="V7 Backend - Rust + FMOD v7 Architecture with gRPC support" \
      rust.version="${RUST_VERSION}" \
      optimization="lto+strip+static+no-external-deps" \
      security="non-root+minimal-deps+readonly-fs" \
      performance="extreme+static-binary" \
      ports.http="${BACKEND_PORT}" \
      ports.grpc="${GRPC_PORT}"

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