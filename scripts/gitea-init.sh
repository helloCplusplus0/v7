#!/bin/bash

# Gitea 仓库初始化脚本
set -e

# 配置变量
GITEA_URL="http://192.168.31.84:8081"
REPO_NAME="fmod-v7-project"
USERNAME="" # 需要用户输入
PASSWORD="" # 需要用户输入

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 获取用户凭据
get_credentials() {
    echo "🔐 请输入 Gitea 凭据:"
    read -p "用户名: " USERNAME
    read -s -p "密码: " PASSWORD
    echo ""
}

# 检查 Git 配置
check_git_config() {
    log_info "检查 Git 配置..."
    
    if ! git config user.name >/dev/null; then
        read -p "请输入 Git 用户名: " git_name
        git config --global user.name "$git_name"
    fi
    
    if ! git config user.email >/dev/null; then
        read -p "请输入 Git 邮箱: " git_email
        git config --global user.email "$git_email"
    fi
    
    log_success "Git 配置完成"
}

# 初始化 Git 仓库
init_git_repo() {
    log_info "初始化 Git 仓库..."
    
    if [ ! -d ".git" ]; then
        git init
        log_success "Git 仓库已初始化"
    else
        log_info "Git 仓库已存在"
    fi
}

# 添加 Gitea 远程仓库
add_remote() {
    local remote_url="$GITEA_URL/$USERNAME/$REPO_NAME.git"
    
    log_info "添加远程仓库: $remote_url"
    
    # 删除现有的 origin（如果存在）
    git remote remove origin 2>/dev/null || true
    
    # 添加新的远程仓库
    git remote add origin "$remote_url"
    
    log_success "远程仓库已添加"
}

# 准备初始提交
prepare_initial_commit() {
    log_info "准备初始提交..."
    
    # 确保所有必要文件都被添加
    git add .
    
    # 检查是否有变更
    if git diff --staged --quiet; then
        log_warning "没有文件需要提交"
        return
    fi
    
    # 创建初始提交
    git commit -m "Initial commit: FMOD v7 project with Gitea CI/CD setup

Features included:
- ✅ Rust backend with FMOD v7 architecture
- ✅ SolidJS frontend with Web v7 architecture  
- ✅ Podman containerization
- ✅ Gitea Actions CI/CD pipeline
- ✅ Comprehensive deployment scripts
- ✅ Database migration support
- ✅ Development environment setup

Architecture:
- Backend: Rust + FMOD v7 (Port 3000)
- Frontend: SolidJS + Vite (Port 5173)
- Database: SQLite (Development)
- Containerization: Podman + Compose
- CI/CD: Gitea Actions"

    log_success "初始提交已创建"
}

# 推送到 Gitea
push_to_gitea() {
    log_info "推送代码到 Gitea..."
    
    # 推送主分支
    git push -u origin main
    
    # 创建并推送 develop 分支
    log_info "创建 develop 分支..."
    git checkout -b develop
    git push -u origin develop
    
    # 切换回 main 分支
    git checkout main
    
    log_success "代码已推送到 Gitea"
}

# 创建 Issue 模板
create_issue_templates() {
    log_info "创建 Issue 模板..."
    
    mkdir -p .gitea/issue_template
    
    # Bug 报告模板
    cat > .gitea/issue_template/bug_report.md << 'EOF'
---
name: Bug 报告
about: 创建 Bug 报告来帮助我们改进
title: '[BUG] '
labels: bug
assignees: ''
---

## 🐛 Bug 描述
简要描述出现的问题

## 🔄 复现步骤
1. 打开 '...'
2. 点击 '....'
3. 滚动到 '....'
4. 看到错误

## 🎯 期望行为
描述你期望发生的情况

## 📸 截图
如果可能，添加截图来帮助解释问题

## 🖥️ 环境信息
- OS: [e.g. Ubuntu 22.04]
- Browser: [e.g. Chrome 120]
- Version: [e.g. v1.0.0]

## 📝 附加信息
添加其他有关问题的背景信息
EOF

    # 功能请求模板
    cat > .gitea/issue_template/feature_request.md << 'EOF'
---
name: 功能请求
about: 建议项目的新功能
title: '[FEATURE] '
labels: enhancement
assignees: ''
---

## 🚀 功能描述
简要描述你想要的功能

## 💡 动机
为什么需要这个功能？它能解决什么问题？

## 📋 详细描述
详细描述功能的预期行为

## 🎨 替代方案
描述你考虑过的任何替代解决方案或功能

## 📝 附加信息
添加其他有关功能请求的背景信息
EOF

    log_success "Issue 模板已创建"
}

# 创建 PR 模板
create_pr_template() {
    log_info "创建 Pull Request 模板..."
    
    mkdir -p .gitea/pull_request_template
    
    cat > .gitea/pull_request_template/default.md << 'EOF'
## 📝 变更描述
简要描述这个 PR 的变更内容

## 🔗 相关 Issue
Fixes #(issue number)

## 📋 变更类型
请删除不相关的选项：
- [ ] Bug 修复 (非破坏性变更，修复了一个问题)
- [ ] 新功能 (非破坏性变更，添加了功能)
- [ ] 破坏性变更 (修复或功能会导致现有功能无法正常工作)
- [ ] 文档更新

## 🧪 测试
- [ ] 我已经测试了我的变更
- [ ] 我已经添加了必要的测试
- [ ] 所有新的和现有的测试都通过了

## ✅ 检查清单
- [ ] 我的代码遵循了这个项目的代码规范
- [ ] 我已经执行了自我代码审查
- [ ] 我已经对我的代码进行了相应的注释，特别是在难以理解的地方
- [ ] 我已经对相应的文档进行了变更
- [ ] 我的变更不会产生新的警告
- [ ] 新的和现有的单元测试都通过了

## 📸 截图（如果适用）
添加截图来展示变更效果
EOF

    log_success "PR 模板已创建"
}

# 显示后续步骤
show_next_steps() {
    log_success "🎉 Gitea 仓库初始化完成！"
    echo ""
    echo "📋 后续步骤："
    echo "1. 访问 $GITEA_URL/$USERNAME/$REPO_NAME"
    echo "2. 启用 Repository Actions"
    echo "3. 配置 Gitea Runner"
    echo "4. 设置 Repository Secrets"
    echo "5. 开始开发："
    echo "   git checkout develop"
    echo "   git checkout -b feature/your-feature"
    echo ""
    echo "🔗 快速链接："
    echo "   仓库地址: $GITEA_URL/$USERNAME/$REPO_NAME"
    echo "   Actions: $GITEA_URL/$USERNAME/$REPO_NAME/actions"
    echo "   Issues: $GITEA_URL/$USERNAME/$REPO_NAME/issues"
    echo ""
    echo "📚 详细文档：查看 docs/gitea-setup.md"
}

# 主函数
main() {
    echo "🚀 FMOD v7 Gitea 仓库初始化脚本"
    echo "=================================="
    echo ""
    
    get_credentials
    check_git_config
    init_git_repo
    add_remote
    create_issue_templates
    create_pr_template
    prepare_initial_commit
    push_to_gitea
    show_next_steps
}

# 执行主函数
main "$@" 