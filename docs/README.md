# FMOD v7 项目文档

本目录包含项目的核心文档。

## 📚 文档结构

### 核心文档
- `gitea-checklist.md` - Gitea CI/CD 配置和使用指南
- `local-deployment-setup.md` - 本地部署配置说明

### 目录说明
- `archive/` - 存档文档（当前为空）

## 📋 使用说明

### 开发者快速上手
1. 阅读 `local-deployment-setup.md` 了解本地环境配置
2. 查看 `gitea-checklist.md` 了解 CI/CD 流程

### 文档维护原则
- 只保留对当前开发有价值的文档
- 临时性开发记录不应放在此目录
- 重要的架构决策和配置说明应当记录在这里

## 🎯 工作流程

**标准开发流程**：
```bash
# 本地开发
npm run dev              # 前端: http://localhost:5173
cargo run               # 后端: http://localhost:3000

# 提交代码触发自动化
git add .
git commit -m "feat: 新功能"
git push origin develop  # 自动部署到测试环境
git push origin main     # 自动部署到生产环境
```

**部署管理**：
```bash
./scripts/deploy.sh status    # 查看服务状态
./scripts/deploy.sh ports     # 查看端口配置
./scripts/deploy.sh deploy    # 手动本地部署测试
``` 