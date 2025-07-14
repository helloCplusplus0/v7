#!/bin/bash

# Analytics Engine Build Script
# 自动构建Rust+Python混合分析引擎

set -e  # 出错时退出

echo "🚀 Building Analytics Engine..."

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查必要工具
check_requirements() {
    echo -e "${BLUE}📋 Checking requirements...${NC}"
    
    # 检查Rust
    if ! command -v cargo &> /dev/null; then
        echo -e "${RED}❌ Cargo not found. Please install Rust.${NC}"
        exit 1
    fi
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}❌ Python3 not found. Please install Python 3.9+.${NC}"
        exit 1
    fi
    
    # 检查maturin（如果需要Python集成）
    if [[ "${FEATURES}" == *"python-bridge"* ]]; then
        if ! command -v maturin &> /dev/null; then
            echo -e "${YELLOW}⚠️  maturin not found. Installing...${NC}"
            pip install maturin
        fi
    fi
    
    echo -e "${GREEN}✅ Requirements check passed${NC}"
}

# 设置环境变量
setup_environment() {
    echo -e "${BLUE}🔧 Setting up environment...${NC}"
    
    # 默认features
    export FEATURES=${FEATURES:-"default"}
    
    # 设置构建模式
    export BUILD_MODE=${BUILD_MODE:-"release"}
    
    # Python路径
    export PYTHONPATH="${PWD}/python:${PYTHONPATH}"
    
    echo -e "${GREEN}✅ Environment setup complete${NC}"
    echo -e "   Features: ${FEATURES}"
    echo -e "   Build mode: ${BUILD_MODE}"
}

# 构建Rust组件
build_rust() {
    echo -e "${BLUE}🦀 Building Rust components...${NC}"
    
    # 清理之前的构建
    cargo clean
    
    # 构建参数
    BUILD_ARGS=""
    if [[ "${BUILD_MODE}" == "release" ]]; then
        BUILD_ARGS="--release"
    fi
    
    if [[ "${FEATURES}" != "default" ]]; then
        BUILD_ARGS="${BUILD_ARGS} --features ${FEATURES}"
    fi
    
    # 构建库
    echo -e "${YELLOW}📦 Building library...${NC}"
    cargo build ${BUILD_ARGS}
    
    # 构建二进制
    echo -e "${YELLOW}🔧 Building server binary...${NC}"
    cargo build ${BUILD_ARGS} --bin analytics-server
    
    echo -e "${GREEN}✅ Rust build complete${NC}"
}

# 构建Python组件（如果启用）
build_python() {
    if [[ "${FEATURES}" == *"python-bridge"* ]]; then
        echo -e "${BLUE}🐍 Setting up Python environment...${NC}"
        
        # 安装Python依赖
        echo -e "${YELLOW}📦 Installing Python dependencies...${NC}"
        if [[ -f "requirements.txt" ]]; then
            pip install -r requirements.txt
        else
            echo -e "${YELLOW}⚠️  No requirements.txt found, installing basic dependencies...${NC}"
            pip install numpy pandas scikit-learn scipy || echo -e "${YELLOW}⚠️  Python dependencies installation failed, continuing...${NC}"
        fi
        
        echo -e "${GREEN}✅ Python environment setup complete${NC}"
    else
        echo -e "${YELLOW}⏭️  Python bridge disabled, skipping Python setup${NC}"
    fi
}

# 运行测试
run_tests() {
    if [[ "${SKIP_TESTS}" != "true" ]]; then
        echo -e "${BLUE}🧪 Running tests...${NC}"
        
        # Rust测试
        echo -e "${YELLOW}🦀 Running Rust tests...${NC}"
        cargo test
        
        # Python测试（如果启用）
        if [[ "${FEATURES}" == *"python-bridge"* ]]; then
            echo -e "${YELLOW}🐍 Running Python tests...${NC}"
            cd python && python -m pytest tests/ || echo -e "${YELLOW}⚠️  Python tests not found, skipping${NC}"
            cd ..
        fi
        
        echo -e "${GREEN}✅ Tests passed${NC}"
    else
        echo -e "${YELLOW}⏭️  Tests skipped${NC}"
    fi
}

# 生成构建信息
generate_build_info() {
    echo -e "${BLUE}📊 Generating build info...${NC}"
    
    BUILD_INFO_FILE="target/build_info.json"
    
    cat > "${BUILD_INFO_FILE}" << EOF
{
  "version": "$(cargo pkgid | cut -d# -f2)",
  "build_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "build_mode": "${BUILD_MODE}",
  "features": "${FEATURES}",
  "rust_version": "$(rustc --version)",
  "python_version": "$(python3 --version)",
  "git_commit": "$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')",
  "git_branch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
}
EOF
    
    echo -e "${GREEN}✅ Build info generated: ${BUILD_INFO_FILE}${NC}"
}

# 清理函数
cleanup() {
    echo -e "${BLUE}🧹 Cleaning up...${NC}"
    # 可以在这里添加清理逻辑
}

# 主构建流程
main() {
    echo -e "${GREEN}🎯 Analytics Engine Build Started${NC}"
    
    # 设置错误处理
    trap cleanup EXIT
    
    check_requirements
    setup_environment
    build_rust
    build_python
    run_tests
    generate_build_info
    
    echo -e "${GREEN}🎉 Build completed successfully!${NC}"
    echo -e "${BLUE}📍 Binary location: target/${BUILD_MODE}/analytics-server${NC}"
    
    # 显示下一步
    echo -e "${YELLOW}"
    echo "🚀 Next steps:"
    echo "  1. Run tests: ./scripts/test.sh"
    echo "  2. Start server: ./scripts/run.sh"
    echo "  3. Deploy: ./scripts/deploy.sh"
    echo -e "${NC}"
}

# 运行主函数
main "$@" 