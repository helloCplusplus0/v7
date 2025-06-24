#!/bin/bash

# 🔍 V7 快速诊断脚本
# 版本: v1.0 - 快速识别本地环境问题
# 目标: 在30秒内识别所有可能导致CI脚本卡住的问题

set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m' 
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}"
echo "🔍 V7 快速诊断工具 - 30秒环境检查"
echo "========================================"
echo -e "${NC}"

ISSUES=0

# 快速检查函数
quick_check() {
    local cmd="$1"
    local description="$2"
    local timeout="${3:-5}"
    
    echo -n "🔍 检查 $description... "
    
    if timeout "$timeout" bash -c "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC}"
        return 0
    else
        echo -e "${RED}❌${NC}"
        ((ISSUES++))
        return 1
    fi
}

# 1. 基础工具检查
echo "📋 1. 基础工具可用性检查"
echo "----------------------------------------"

quick_check "command -v git" "Git" 2
quick_check "command -v node" "Node.js" 2
quick_check "command -v npm" "npm" 2
quick_check "command -v cargo" "Cargo" 2
quick_check "command -v rustc" "Rust编译器" 2

echo ""

# 2. 工具响应性检查
echo "📋 2. 工具响应性检查 (可能卡住的命令)"
echo "----------------------------------------"

quick_check "git --version" "Git版本响应" 5
quick_check "node --version" "Node.js版本响应" 5
quick_check "npm --version" "npm版本响应" 10  # npm经常卡住
quick_check "cargo --version" "Cargo版本响应" 10
quick_check "rustc --version" "Rust版本响应" 10

echo ""

# 3. 项目结构检查
echo "📋 3. 项目结构检查"
echo "----------------------------------------"

quick_check "[ -d backend ]" "backend目录" 1
quick_check "[ -d web ]" "web目录" 1
quick_check "[ -f backend/Cargo.toml ]" "Cargo.toml" 1
quick_check "[ -f web/package.json ]" "package.json" 1
quick_check "[ -f .github/workflows/ci-cd.yml ]" "CI/CD配置" 1

echo ""

# 4. 网络连接检查
echo "📋 4. 网络连接检查"
echo "----------------------------------------"

quick_check "ping -c 1 8.8.8.8" "网络连接" 5
quick_check "curl -s --connect-timeout 5 https://registry.npmjs.org/" "npm registry" 10
quick_check "curl -s --connect-timeout 5 https://crates.io/" "Crates.io" 10

echo ""

# 5. 磁盘空间检查
echo "📋 5. 系统资源检查"
echo "----------------------------------------"

# 检查磁盘空间
available_space=$(df . | tail -1 | awk '{print $4}')
if [ "$available_space" -gt 1000000 ]; then  # 1GB
    echo -e "🔍 检查磁盘空间... ${GREEN}✅${NC} ($(($available_space / 1024))MB 可用)"
else
    echo -e "🔍 检查磁盘空间... ${RED}❌${NC} (仅$(($available_space / 1024))MB 可用)"
    ((ISSUES++))
fi

# 检查内存
available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7}')
if [ "$available_memory" -gt 512 ]; then
    echo -e "🔍 检查可用内存... ${GREEN}✅${NC} (${available_memory}MB 可用)"
else
    echo -e "🔍 检查可用内存... ${RED}❌${NC} (仅${available_memory}MB 可用)"
    ((ISSUES++))
fi

echo ""

# 6. 常见问题诊断
echo "📋 6. 常见问题诊断"
echo "----------------------------------------"

# 检查npm配置
if command -v npm >/dev/null 2>&1; then
    if timeout 5 npm config get registry >/dev/null 2>&1; then
        echo -e "🔍 检查npm配置... ${GREEN}✅${NC}"
    else
        echo -e "🔍 检查npm配置... ${RED}❌${NC} (npm配置可能损坏)"
        ((ISSUES++))
    fi
fi

# 检查Rust工具链
if command -v rustup >/dev/null 2>&1; then
    if timeout 5 rustup show >/dev/null 2>&1; then
        echo -e "🔍 检查Rust工具链... ${GREEN}✅${NC}"
    else
        echo -e "🔍 检查Rust工具链... ${RED}❌${NC} (Rust工具链可能损坏)"
        ((ISSUES++))
    fi
fi

# 检查权限
if [ -w . ]; then
    echo -e "🔍 检查目录写权限... ${GREEN}✅${NC}"
else
    echo -e "🔍 检查目录写权限... ${RED}❌${NC}"
    ((ISSUES++))
fi

echo ""

# 总结
echo "📊 诊断结果总结"
echo "========================================"

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}🎉 环境检查通过！未发现明显问题。${NC}"
    echo ""
    echo "💡 如果local-ci-check.sh仍然卡住，请尝试："
    echo "  1. 重启终端并重新运行"
    echo "  2. 清理npm缓存: npm cache clean --force"
    echo "  3. 更新Rust工具链: rustup update"
    echo "  4. 检查防火墙和代理设置"
else
    echo -e "${RED}❌ 发现 $ISSUES 个问题需要解决${NC}"
    echo ""
    echo "🔧 建议修复步骤："
    echo "  1. 安装缺失的工具"
    echo "  2. 检查网络连接和代理设置"
    echo "  3. 清理损坏的配置文件"
    echo "  4. 释放磁盘空间"
    echo "  5. 重启系统服务"
fi

echo ""
echo "⏱️  诊断完成，用时: $SECONDS 秒"
echo "🔍 下一步: 运行 ./scripts/local-ci-check.sh" 