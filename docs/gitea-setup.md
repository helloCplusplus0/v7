# Gitea + Podman CI/CD 完整设置指南

## 🎯 项目概述

基于 Gitea + Podman 的 FMOD v7 全栈 CI/CD 解决方案，实现代码托管、自动化构建、测试和部署。

## 📋 前置条件

### 1. Gitea 服务器要求
- ✅ Gitea 实例: `http://192.168.31.84:8081/`
- ✅ Gitea Actions 已启用
- ✅ Runner 已配置并运行

### 2. 开发环境要求
```bash
# 必需工具
- Git 2.40+
- Podman 4.0+
- Podman Compose
- Node.js 18+
- Rust 1.75+
```

## 🚀 第一步：项目托管到 Gitea

### 1.1 创建 Gitea 仓库
1. 访问 `http://192.168.31.84:8081/`
2. 登录并创建新仓库 `fmod-v7-project`
3. 设置仓库为 Private（推荐）

### 1.2 推送代码到 Gitea
```bash
# 添加 Gitea 远程仓库
git remote add origin http://192.168.31.84:8081/username/fmod-v7-project.git

# 推送代码
git add .
git commit -m "Initial commit: FMOD v7 project setup"
git push -u origin main

# 创建 develop 分支
git checkout -b develop
git push -u origin develop
```

## 🔧 第二步：配置 Gitea Actions

### 2.1 启用 Actions
在 Gitea 仓库设置中：
1. 进入 `Settings` → `Actions`
2. 启用 `Enable Repository Actions`
3. 设置 Actions 权限为 `Allow all actions`

### 2.2 配置 Runner
```bash
# 在服务器上安装 Gitea Runner
curl -L https://dl.gitea.com/act_runner/latest/act_runner-linux-amd64 -o act_runner
chmod +x act_runner

# 注册 Runner
./act_runner register --instance http://192.168.31.84:8081 --token YOUR_RUNNER_TOKEN

# 启动 Runner 服务
./act_runner daemon
```

### 2.3 配置 Secrets
在仓库设置中添加以下 Secrets：
- `REGISTRY_URL`: `192.168.31.84:5000`
- `DEPLOY_HOST`: 部署服务器地址
- `DEPLOY_USER`: 部署用户
- `DEPLOY_KEY`: SSH 私钥

## 🏗️ 第三步：CI/CD 工作流

### 3.1 工作流触发条件
```yaml
# 自动触发
- Push to main/develop 分支
- Pull Request 到 main 分支
- 手动触发（workflow_dispatch）

# 定时触发（可选）
- 每日构建：0 2 * * *
- 安全扫描：0 6 * * 1
```

### 3.2 流水线阶段

#### Stage 1: 代码质量检查
- ✅ Rust 代码格式检查 (`cargo fmt`)
- ✅ Rust 代码静态分析 (`cargo clippy`)
- ✅ 前端代码规范检查 (`eslint`)
- ✅ TypeScript 类型检查

#### Stage 2: 自动化测试
- ✅ Rust 单元测试 (`cargo test`)
- ✅ Rust 集成测试
- ✅ 前端单元测试 (`vitest`)
- ✅ 前端集成测试
- ✅ 测试覆盖率报告

#### Stage 3: 镜像构建
- ✅ 多阶段 Dockerfile 构建
- ✅ Podman 镜像构建
- ✅ 镜像安全扫描
- ✅ 镜像推送到私有仓库

#### Stage 4: 自动部署
- ✅ 测试环境自动部署（develop 分支）
- ✅ 生产环境部署（main 分支，需要审批）
- ✅ 数据库备份
- ✅ 健康检查

## 🔄 第四步：开发工作流

### 4.1 功能开发流程
```bash
# 1. 创建功能分支
git checkout develop
git pull origin develop
git checkout -b feature/new-feature

# 2. 开发功能
# ... 编写代码 ...

# 3. 本地测试
npm run dev                    # 启动开发服务器
./scripts/deploy.sh build     # 本地构建测试

# 4. 提交代码
git add .
git commit -m "feat: add new feature"
git push origin feature/new-feature

# 5. 创建 Pull Request
# 在 Gitea 界面创建 PR 到 develop 分支
```

### 4.2 发布流程
```bash
# 1. 合并到 develop
# PR 审核通过后合并

# 2. 创建发布 PR
git checkout develop
git pull origin develop
git checkout main
git pull origin main
git checkout -b release/v1.0.0

# 3. 更新版本号
# 更新 Cargo.toml 和 package.json 版本号

# 4. 创建 PR 到 main
# 触发生产环境部署流程
```

## 📊 第五步：监控和运维

### 5.1 应用监控
```bash
# 检查服务状态
./scripts/deploy.sh status

# 查看服务日志
./scripts/deploy.sh logs

# 重启服务
./scripts/deploy.sh restart
```

### 5.2 数据备份
```bash
# 手动备份
./scripts/deploy.sh backup

# 自动备份（cron）
0 2 * * * cd /path/to/project && ./scripts/deploy.sh backup
```

### 5.3 性能监控
- CPU、内存、网络使用率
- 数据库查询性能
- API 响应时间
- 错误率监控

## 🛡️ 第六步：安全最佳实践

### 6.1 代码安全
- 依赖漏洞扫描 (`cargo audit`, `npm audit`)
- 代码静态安全分析
- 敏感信息检测

### 6.2 镜像安全
- 基础镜像漏洞扫描
- 非 root 用户运行
- 最小权限原则

### 6.3 部署安全
- 网络隔离
- 访问控制
- 日志审计

## 📈 第七步：优化和扩展

### 7.1 性能优化
- 镜像大小优化
- 构建缓存策略
- 并行构建优化

### 7.2 功能扩展
- 多环境部署
- 蓝绿部署
- 金丝雀发布
- 自动回滚

### 7.3 集成扩展
- 代码质量报告（SonarQube）
- 性能测试（Apache Bench）
- 安全扫描（Trivy）

## 🎯 Gitea 最大化价值实现

### 1. **完整 DevOps 平台**
- ✅ 代码托管 + Issues + Wiki
- ✅ PR Review + 代码协作
- ✅ CI/CD + 自动化部署
- ✅ Package Registry + 依赖管理

### 2. **自托管优势**
- ✅ 数据完全控制
- ✅ 网络安全隔离
- ✅ 自定义配置
- ✅ 成本可控

### 3. **团队协作**
- ✅ 用户权限管理
- ✅ 组织架构管理
- ✅ 项目模板
- ✅ 工作流自动化

### 4. **集成生态**
- ✅ IDE 集成（VS Code, IntelliJ）
- ✅ 第三方工具集成
- ✅ Webhook 事件处理
- ✅ API 接口扩展

## 🚀 快速开始命令

```bash
# 1. 克隆项目
git clone http://192.168.31.84:8081/username/fmod-v7-project.git
cd fmod-v7-project

# 2. 本地开发
./scripts/start.sh

# 3. 构建部署
./scripts/deploy.sh deploy

# 4. 查看状态
./scripts/deploy.sh status
```

---

通过这个完整的 Gitea + Podman CI/CD 方案，您将获得：
- 🎯 **专业级 DevOps 工作流**
- 🔒 **企业级安全控制**
- 📈 **可扩展的架构设计**
- 💰 **成本效益最优化** 