#!/bin/bash

# Backend开发环境设置脚本
# 用于快速配置开发环境和安装必要工具

set -e

echo "🚀 开始设置Backend开发环境..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查Rust工具链
check_rust() {
    log_info "检查Rust工具链..."
    
    if ! command -v rustc &> /dev/null; then
        log_error "Rust未安装，请先安装Rust: https://rustup.rs/"
        exit 1
    fi
    
    local rust_version=$(rustc --version)
    log_success "Rust已安装: $rust_version"
    
    # 检查是否为最新稳定版
    log_info "更新Rust工具链..."
    rustup update stable
    rustup default stable
}

# 安装开发工具
install_dev_tools() {
    log_info "安装开发工具..."
    
    # 代码监控工具
    if ! command -v cargo-watch &> /dev/null; then
        log_info "安装cargo-watch..."
        cargo install cargo-watch
    else
        log_success "cargo-watch已安装"
    fi
    
    # 测试覆盖率工具
    if ! command -v cargo-tarpaulin &> /dev/null; then
        log_info "安装cargo-tarpaulin..."
        cargo install cargo-tarpaulin
    else
        log_success "cargo-tarpaulin已安装"
    fi
    
    # 安全审计工具
    if ! command -v cargo-audit &> /dev/null; then
        log_info "安装cargo-audit..."
        cargo install cargo-audit
    else
        log_success "cargo-audit已安装"
    fi
    
    # 代码格式化和检查工具
    log_info "安装rustfmt和clippy..."
    rustup component add rustfmt clippy
    
    # 基准测试工具
    if ! command -v cargo-criterion &> /dev/null; then
        log_info "安装cargo-criterion..."
        cargo install cargo-criterion
    else
        log_success "cargo-criterion已安装"
    fi
    
    # 依赖树查看工具
    if ! command -v cargo-tree &> /dev/null; then
        log_info "安装cargo-tree..."
        cargo install cargo-tree
    else
        log_success "cargo-tree已安装"
    fi
}

# 设置数据库
setup_database() {
    log_info "设置数据库..."
    
    # 创建数据目录
    mkdir -p data
    mkdir -p logs
    
    # 检查SQLite
    if ! command -v sqlite3 &> /dev/null; then
        log_warning "SQLite3未安装，请手动安装"
        case "$(uname -s)" in
            Linux*)
                log_info "Ubuntu/Debian: sudo apt-get install sqlite3"
                log_info "CentOS/RHEL: sudo yum install sqlite"
                ;;
            Darwin*)
                log_info "macOS: brew install sqlite"
                ;;
            *)
                log_info "请查阅系统文档安装SQLite3"
                ;;
        esac
    else
        log_success "SQLite3已安装"
    fi
    
    # 检查PostgreSQL客户端（可选）
    if command -v psql &> /dev/null; then
        log_success "PostgreSQL客户端已安装"
    else
        log_warning "PostgreSQL客户端未安装（可选）"
    fi
}

# 配置Git hooks
setup_git_hooks() {
    log_info "配置Git hooks..."
    
    if [ ! -d ".git" ]; then
        log_warning "不在Git仓库中，跳过Git hooks配置"
        return
    fi
    
    # 创建pre-commit hook
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook for Rust project

echo "运行pre-commit检查..."

# 格式化检查
echo "检查代码格式..."
if ! cargo fmt --all -- --check; then
    echo "❌ 代码格式不正确，请运行: cargo fmt"
    exit 1
fi

# Clippy检查
echo "运行Clippy检查..."
if ! cargo clippy --all-targets --all-features -- -D warnings; then
    echo "❌ Clippy检查失败"
    exit 1
fi

# 运行测试
echo "运行测试..."
if ! cargo test --all-features; then
    echo "❌ 测试失败"
    exit 1
fi

echo "✅ 所有检查通过"
EOF
    
    chmod +x .git/hooks/pre-commit
    log_success "Git pre-commit hook已配置"
}

# 创建开发配置
setup_dev_config() {
    log_info "创建开发配置..."
    
    # 创建.env文件（如果不存在）
    if [ ! -f ".env" ]; then
        cat > .env << 'EOF'
# 开发环境变量
RUST_LOG=debug
RUST_BACKTRACE=1
DATABASE_URL=sqlite:data/hello_fmod.db

# 可选：PostgreSQL配置
# DATABASE_HOST=localhost
# DATABASE_USER=postgres
# DATABASE_PASSWORD=password
# DATABASE_NAME=hello_fmod_dev

# JWT密钥（开发用）
JWT_SECRET=dev_secret_key_change_in_production
EOF
        log_success "创建了.env文件"
    else
        log_success ".env文件已存在"
    fi
    
    # 创建开发用的配置目录
    mkdir -p config
    
    # 确保配置文件存在
    if [ ! -f "config/development.toml" ]; then
        log_warning "development.toml不存在，请检查配置"
    fi
}

# 验证环境
verify_environment() {
    log_info "验证开发环境..."
    
    # 检查编译
    log_info "测试编译..."
    if cargo check --all-features; then
        log_success "编译检查通过"
    else
        log_error "编译检查失败"
        exit 1
    fi
    
    # 运行测试
    log_info "运行测试套件..."
    if cargo test --all-features; then
        log_success "测试通过"
    else
        log_error "测试失败"
        exit 1
    fi
    
    # 检查代码质量
    log_info "检查代码质量..."
    if cargo clippy --all-targets --all-features -- -D warnings; then
        log_success "代码质量检查通过"
    else
        log_warning "代码质量检查有警告"
    fi
}

# 显示使用说明
show_usage() {
    log_success "🎉 开发环境设置完成！"
    echo
    echo "常用开发命令："
    echo "  cargo run                    # 运行应用"
    echo "  cargo test                   # 运行测试"
    echo "  cargo watch -x test          # 监控文件变化并运行测试"
    echo "  cargo watch -x run           # 监控文件变化并运行应用"
    echo "  cargo fmt                    # 格式化代码"
    echo "  cargo clippy                 # 代码检查"
    echo "  cargo audit                  # 安全审计"
    echo "  cargo tarpaulin --out Html   # 生成测试覆盖率报告"
    echo
    echo "配置文件："
    echo "  .env                         # 环境变量"
    echo "  config/development.toml      # 开发环境配置"
    echo "  .cargo/config.toml           # Cargo配置"
    echo
    echo "开发工作流："
    echo "  1. 修改代码"
    echo "  2. 运行测试: cargo test"
    echo "  3. 检查格式: cargo fmt"
    echo "  4. 代码检查: cargo clippy"
    echo "  5. 提交代码（会自动运行pre-commit检查）"
}

# 主函数
main() {
    echo "Backend开发环境设置脚本"
    echo "========================"
    echo
    
    check_rust
    install_dev_tools
    setup_database
    setup_git_hooks
    setup_dev_config
    verify_environment
    show_usage
}

# 运行主函数
main "$@"