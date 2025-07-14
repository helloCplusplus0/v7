# Analytics Engine - Multi-stage Dockerfile
# 支持Rust+Python混合分析引擎的容器化部署

# 阶段1：构建环境
FROM ubuntu:22.04 as builder

# 设置非交互式模式
ENV DEBIAN_FRONTEND=noninteractive

# 安装构建依赖
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    pkg-config \
    libssl-dev \
    python3 \
    python3-pip \
    python3-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# 安装Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# 安装Python构建工具
RUN pip3 install maturin

# 设置工作目录
WORKDIR /workspace

# 复制项目文件
COPY Cargo.toml Cargo.lock pyproject.toml build.rs ./
COPY src/ src/
COPY python/ python/
COPY scripts/ scripts/

# 构建项目
ENV FEATURES=python-bridge
ENV BUILD_MODE=release
RUN ./scripts/build.sh

# 阶段2：运行时环境
FROM ubuntu:22.04 as runtime

# 设置非交互式模式
ENV DEBIAN_FRONTEND=noninteractive

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 安装Python运行时依赖
RUN pip3 install --no-cache-dir \
    numpy>=1.24.0 \
    pandas>=2.0.0 \
    scikit-learn>=1.3.0 \
    scipy>=1.10.0

# 创建用户
RUN useradd -m -u 1000 analytics
USER analytics
WORKDIR /home/analytics

# 从构建阶段复制文件
COPY --from=builder --chown=analytics:analytics /workspace/target/release/analytics-server /usr/local/bin/
COPY --from=builder --chown=analytics:analytics /workspace/python/ ./python/
COPY --from=builder --chown=analytics:analytics /workspace/scripts/run.sh ./

# 设置Python路径
ENV PYTHONPATH="/home/analytics/python:${PYTHONPATH}"

# 暴露端口
EXPOSE 50051

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD grpcurl -plaintext localhost:50051 analytics.AnalyticsEngine/HealthCheck || exit 1

# 默认命令
CMD ["/usr/local/bin/analytics-server"] 