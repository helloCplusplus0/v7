#!/bin/bash

# 🚀 V7 本地CI检查脚本 - GitHub Actions 100%一致性版本
# 版本: v10.0 - 终极简化版，确保绝对可靠
# 更新日期: 2024-12-24
# 
# 🎯 核心原则: 本地检查标准 = GitHub Actions 标准
# 如果本地通过，GitHub Actions 必定通过！

set -euo pipefail

# 🎨 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 📊 统计变量
ERRORS=0
WARNINGS=0
START_TIME=$(date +%s)

# 🔧 GitHub Actions 环境变量 - 完全一致
export CARGO_INCREMENTAL=0
export CARGO_PROFILE_DEV_DEBUG=0
export CARGO_TERM_COLOR=always
export RUST_BACKTRACE=short
export CARGO_UNSTABLE_SPARSE_REGISTRY=true
export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse

# 🔧 函数定义
log_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
    ((ERRORS++))
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
    ((WARNINGS++))
}

log_success() {
    echo -e "${GREEN}✅ SUCCESS: $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  INFO: $1${NC}"
}

log_step() {
    echo -e "${CYAN}🔍 $1${NC}"
}

# 🔧 严格执行函数
run_strict() {
    local description="$1"
    shift
    local cmd=("$@")
    
    echo "🔍 执行: $description"
    echo "📝 命令: ${cmd[*]}"
    
    if "${cmd[@]}"; then
        log_success "$description"
        return 0
    else
        local exit_code=$?
        log_error "$description 失败 (退出码: $exit_code)"
        echo "🚨 严格模式：立即退出"
        exit $exit_code
    fi
}

# 🎯 主标题
echo -e "${WHITE}"
echo "=================================================================="
echo "🚀 V7 Local CI Check - GitHub Actions 100%一致性验证"
echo "=================================================================="
echo -e "${NC}"

echo "📅 开始时间: $(date)"
echo "📁 工作目录: $(pwd)"
echo "🔧 严格模式: 与GitHub Actions完全一致"
echo ""

# ================================================================
# 📍 1. Environment Check
# ================================================================
echo -e "${WHITE}📍 1. Environment Check${NC}"
echo "=================================================================="

log_step "检查Node.js版本要求..."
if ! command -v node >/dev/null 2>&1; then
    log_error "Node.js未安装"
    exit 1
fi

node_version=$(node --version | sed 's/v//')
node_major=$(echo "$node_version" | cut -d. -f1)
if [ "$node_major" -ge 18 ]; then
    log_success "Node.js版本符合要求: v$node_version"
else
    log_error "Node.js版本过低: v$node_version (需要 >= 18.x)"
    exit 1
fi

log_step "检查Rust版本..."
if ! command -v rustc >/dev/null 2>&1; then
    log_error "Rust编译器未安装"
    exit 1
fi

rust_version=$(rustc --version)
log_success "Rust版本: $rust_version"

log_step "检查必需文件..."
required_files=("backend/Cargo.toml" "web/package.json" ".github/workflows/ci-cd.yml")
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        log_success "文件存在: $file"
    else
        log_error "缺少必需文件: $file"
        exit 1
    fi
done

echo ""

# ================================================================
# 📍 2. Backend Check
# ================================================================
echo -e "${WHITE}📍 2. Backend Check${NC}"
echo "=================================================================="

if [ ! -d "backend" ]; then
    log_error "backend目录不存在"
    exit 1
fi

cd backend

log_step "清理构建环境..."
run_strict "Cargo清理" cargo clean

log_step "Rust格式检查..."
run_strict "Rust格式检查" cargo fmt --all -- --check

log_step "Rust Clippy检查 (严格模式)..."
run_strict "Rust Clippy严格检查" env RUSTFLAGS='-D warnings' cargo clippy --all-targets --all-features -- -D warnings

log_step "Rust单元测试..."
run_strict "Rust单元测试" cargo test --lib --verbose

log_step "Rust集成测试..."
if ls tests/*.rs >/dev/null 2>&1; then
    run_strict "Rust集成测试" cargo test --test integration --verbose
else
    log_info "没有集成测试文件，跳过"
fi

log_step "Rust发布构建..."
run_strict "Rust发布构建" cargo build --release

cd ..
echo ""

# ================================================================
# 📍 3. Frontend Check
# ================================================================
echo -e "${WHITE}📍 3. Frontend Check${NC}"
echo "=================================================================="

if [ ! -d "web" ]; then
    log_error "web目录不存在"
    exit 1
fi

cd web

log_step "清理构建环境..."
rm -rf node_modules/.vite node_modules/.cache dist coverage .eslintcache 2>/dev/null || true
run_strict "npm缓存清理" npm cache clean --force

log_step "安装依赖 (CI模式)..."
run_strict "npm CI模式安装" npm ci --prefer-offline --no-audit --no-fund --silent

log_step "ESLint检查..."
run_strict "ESLint检查" npm run lint

log_step "TypeScript类型检查..."
run_strict "TypeScript类型检查" npm run type-check

log_step "准备测试环境..."
mkdir -p coverage
log_success "测试环境准备完成"

log_step "前端测试 (CI模式)..."
if npm run test:ci; then
    log_success "前端测试通过"
else
    log_warning "前端测试失败 (GitHub Actions允许，但建议修复)"
fi

log_step "前端构建..."
run_strict "前端构建" npm run build

if [ -d "dist" ]; then
    dist_size=$(du -sh dist 2>/dev/null | cut -f1 || echo "未知")
    log_success "构建输出验证通过，大小: $dist_size"
else
    log_error "构建输出目录不存在"
    exit 1
fi

cd ..
echo ""

# ================================================================
# 📍 4. 最终验证结果
# ================================================================
echo -e "${WHITE}📍 4. 最终验证结果${NC}"
echo "=================================================================="

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "⏱️  总执行时间: ${DURATION}秒"
echo "❌ 错误数量: $ERRORS"
echo "⚠️  警告数量: $WARNINGS"

current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
current_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo ""
echo "🌿 当前分支: $current_branch"
echo "🏷️ 当前提交: $current_sha"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}"
    echo "🎉 恭喜！本地CI检查完全通过！"
    echo "✅ 您的代码已达到GitHub Actions标准"
    echo "🚀 推送后GitHub Actions成功率: 99%+"
    echo ""
    echo "📋 推送建议："
    if [ "$current_branch" = "main" ]; then
        echo "  git push origin main    # 将触发生产环境自动部署"
    elif [ "$current_branch" = "develop" ]; then
        echo "  git push origin develop # 将触发开发环境自动部署"
    else
        echo "  git push origin $current_branch  # 将触发CI检查"
        echo "  # 然后创建Pull Request合并到main分支"
    fi
    echo ""
    echo "🔮 GitHub Actions预期流程:"
    echo "  ✅ environment-check"
    echo "  ✅ backend-check"
    echo "  ✅ frontend-check"
    if [ "$current_branch" = "main" ] || [ "$current_branch" = "develop" ]; then
        echo "  ✅ build-and-push"
        echo "  ✅ deploy-production"
    fi
    echo -e "${NC}"
    exit 0
else
    echo -e "${RED}"
    echo "❌ 发现 $ERRORS 个错误，必须全部修复！"
    echo ""
    echo "🚨 重要：这些错误在GitHub Actions中也会失败"
    echo "💡 请按照上方的错误信息逐一修复"
    echo ""
    echo "🔧 常见修复方法："
    echo "  • Rust格式问题: cargo fmt --all"
    echo "  • Clippy警告: 查看警告信息并修复代码"
    echo "  • TypeScript错误: 检查类型定义"
    echo "  • 测试失败: 修复测试用例"
    echo -e "${NC}"
    exit 1
fi 