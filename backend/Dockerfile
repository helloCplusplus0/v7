# 多阶段构建 - 构建阶段
FROM rust:1.75-slim as builder

# 安装构建依赖
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    sqlite3 \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制 Cargo 配置文件
COPY Cargo.toml Cargo.lock ./
COPY build.rs ./

# 复制源代码
COPY src/ ./src/
COPY config/ ./config/

# 构建发布版本
RUN cargo build --release

# 运行阶段
FROM debian:bookworm-slim

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    ca-certificates \
    sqlite3 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# 创建应用用户
RUN useradd -r -s /bin/false fmod

# 设置工作目录
WORKDIR /app

# 创建数据目录
RUN mkdir -p /app/data && chown fmod:fmod /app/data

# 从构建阶段复制二进制文件
COPY --from=builder /app/target/release/backend /app/fmod-backend

# 复制配置文件
COPY dev.env ./

# 设置权限
RUN chown fmod:fmod /app/fmod-backend && chmod +x /app/fmod-backend

# 切换到应用用户
USER fmod

# 暴露端口
EXPOSE 3000

# 设置环境变量
ENV RUST_LOG=info
ENV DATABASE_URL=sqlite:./data/prod.db

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# 启动应用
CMD ["./fmod-backend"] 