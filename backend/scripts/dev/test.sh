 #!/bin/bash

# Backend 测试运行脚本
# 提供不同级别的测试执行选项

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查依赖
check_dependencies() {
    print_info "检查测试依赖..."
    
    if ! command -v cargo &> /dev/null; then
        print_error "Cargo 未安装"
        exit 1
    fi
    
    if ! command -v sqlx &> /dev/null; then
        print_warning "SQLx CLI 未安装，某些数据库测试可能失败"
    fi
    
    print_success "依赖检查完成"
}

# 运行单元测试
run_unit_tests() {
    print_info "运行单元测试..."
    cargo test --lib --bins
    print_success "单元测试完成"
}

# 运行集成测试
run_integration_tests() {
    print_info "运行集成测试..."
    cargo test --test integration
    print_success "集成测试完成"
}

# 运行契约测试
run_contract_tests() {
    print_info "运行契约测试..."
    cargo test --test contracts
    print_success "契约测试完成"
}

# 运行端到端测试
run_e2e_tests() {
    print_info "运行端到端测试..."
    cargo test --test e2e
    print_success "端到端测试完成"
}

# 运行性能测试
run_performance_tests() {
    print_info "运行性能测试..."
    cargo test --test performance --release
    print_success "性能测试完成"
}

# 生成覆盖率报告
generate_coverage() {
    print_info "生成测试覆盖率报告..."
    
    if command -v cargo-tarpaulin &> /dev/null; then
        cargo tarpaulin --out Html --output-dir target/coverage
        print_success "覆盖率报告已生成: target/coverage/tarpaulin-report.html"
    else
        print_warning "cargo-tarpaulin 未安装，跳过覆盖率报告"
        print_info "安装命令: cargo install cargo-tarpaulin"
    fi
}

# 运行所有测试
run_all_tests() {
    print_info "运行完整测试套件..."
    
    run_unit_tests
    run_integration_tests
    run_contract_tests
    run_e2e_tests
    
    print_success "所有测试完成"
}

# 快速测试（仅单元测试）
run_quick_tests() {
    print_info "运行快速测试（仅单元测试）..."
    cargo test --lib --bins --quiet
    print_success "快速测试完成"
}

# 监听模式
run_watch_mode() {
    print_info "启动测试监听模式..."
    
    if command -v cargo-watch &> /dev/null; then
        cargo watch -x "test --lib --bins"
    else
        print_error "cargo-watch 未安装"
        print_info "安装命令: cargo install cargo-watch"
        exit 1
    fi
}

# 清理测试环境
cleanup() {
    print_info "清理测试环境..."
    cargo clean
    rm -rf target/coverage
    print_success "清理完成"
}

# 显示帮助信息
show_help() {
    echo "Backend 测试运行脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  unit        运行单元测试"
    echo "  integration 运行集成测试"
    echo "  contract    运行契约测试"
    echo "  e2e         运行端到端测试"
    echo "  performance 运行性能测试"
    echo "  coverage    生成覆盖率报告"
    echo "  all         运行所有测试"
    echo "  quick       快速测试（仅单元测试）"
    echo "  watch       监听模式"
    echo "  clean       清理测试环境"
    echo "  help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 unit                # 运行单元测试"
    echo "  $0 all                 # 运行所有测试"
    echo "  $0 coverage            # 生成覆盖率报告"
    echo "  $0 watch               # 监听模式"
}

# 主函数
main() {
    case "${1:-all}" in
        "unit")
            check_dependencies
            run_unit_tests
            ;;
        "integration")
            check_dependencies
            run_integration_tests
            ;;
        "contract")
            check_dependencies
            run_contract_tests
            ;;
        "e2e")
            check_dependencies
            run_e2e_tests
            ;;
        "performance")
            check_dependencies
            run_performance_tests
            ;;
        "coverage")
            check_dependencies
            run_unit_tests
            generate_coverage
            ;;
        "all")
            check_dependencies
            run_all_tests
            ;;
        "quick")
            check_dependencies
            run_quick_tests
            ;;
        "watch")
            check_dependencies
            run_watch_mode
            ;;
        "clean")
            cleanup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"