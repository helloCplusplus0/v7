# FMOD v7 全栈项目

基于 FMOD v7 架构的现代全栈开发项目，采用前后端分离设计，集成 Gitea + Podman CI/CD 解决方案。

## 🏗️ 项目架构

```
test_project/
├── backend/              # 🔧 Rust 后端 (FMOD v7 架构) - Port 3000
│   ├── src/             # 源代码
│   ├── data/            # 数据库文件存储目录
│   ├── Dockerfile       # 后端容器化配置
│   └── dev.env          # 开发环境配置
├── web/                  # 🎨 SolidJS 前端 (Web v7 架构) - Port 5173
│   ├── src/             # 源代码
│   ├── slices/          # 业务功能切片
│   ├── shared/          # 共享基础设施
│   ├── Dockerfile       # 前端容器化配置
│   └── nginx.conf       # Nginx 配置
├── .gitea/               # 🚀 Gitea CI/CD 配置
│   ├── workflows/       # CI/CD 工作流
│   ├── issue_template/  # Issue 模板
│   └── pull_request_template/ # PR 模板
├── scripts/              # 🛠️ 自动化脚本
│   ├── deploy.sh        # Podman 部署脚本
│   ├── gitea-init.sh    # Gitea 仓库初始化
│   ├── start.sh         # 全栈启动脚本
│   ├── start-backend.sh # 后端独立启动
│   └── start-frontend.sh# 前端独立启动
├── docker-compose.yml    # Podman Compose 配置
├── docs/                 # 📚 项目文档
│   └── gitea-setup.md   # Gitea 设置指南
└── fmod.yaml            # FMOD 配置
```

## 🎯 技术栈

### 后端 (Port 3000)
- **语言**: Rust 1.75+
- **框架**: FMOD v7 架构 - Function-First + Static Dispatch
- **数据库**: SQLite (开发) / PostgreSQL (生产)
- **特性**: 零运行时开销、类型安全、高性能

### 前端 (Port 5173)
- **语言**: TypeScript 5.0+
- **框架**: SolidJS + Vite
- **架构**: Web v7 - Slice Independence + Signal Reactive
- **UI**: Tailwind CSS + 现代化设计

### DevOps & 部署
- **代码托管**: Gitea (http://192.168.31.84:8081/)
- **CI/CD**: Gitea Actions
- **容器化**: Podman + Podman Compose
- **部署**: 自动化部署 + 健康检查

## 🚀 快速开始

### 1. 开发环境启动

```bash
# 方式一：全栈并发启动（推荐）
npm run dev

# 方式二：使用启动脚本
./scripts/start.sh

# 方式三：分别启动前后端
# 后端
./scripts/start-backend.sh

# 前端  
./scripts/start-frontend.sh
```

### 2. Gitea 托管和 CI/CD

```bash
# 一键初始化 Gitea 仓库
./scripts/gitea-init.sh

# 手动步骤
git remote add origin http://192.168.31.84:8081/username/fmod-v7-project.git
git push -u origin main
```

### 3. Podman 容器化部署

```bash
# 完整部署（构建 + 启动）
./scripts/deploy.sh deploy

# 仅构建镜像
./scripts/deploy.sh build

# 启动服务
./scripts/deploy.sh start

# 查看状态
./scripts/deploy.sh status

# 查看日志
./scripts/deploy.sh logs
```

## 🔄 开发工作流

### Git Flow 开发流程

```bash
# 1. 功能开发
git checkout develop
git checkout -b feature/new-feature

# 2. 本地开发
npm run dev                    # 前后端开发服务器
./scripts/deploy.sh build     # 本地容器化测试

# 3. 提交代码
git add .
git commit -m "feat: add new feature"
git push origin feature/new-feature

# 4. 创建 Pull Request (在 Gitea 界面)
# 目标分支: develop
# CI/CD 自动运行：代码检查 → 测试 → 构建

# 5. 发布流程
# develop → main (触发生产环境部署)
```

### CI/CD 流水线

#### 🔍 代码质量检查
- Rust: `cargo fmt`, `cargo clippy`
- Frontend: ESLint, TypeScript 检查

#### 🧪 自动化测试
- 后端: 单元测试 + 集成测试
- 前端: Vitest + 测试覆盖率

#### 🏗️ 镜像构建
- 多阶段 Dockerfile 优化
- Podman 镜像构建和推送

#### 🚀 自动部署
- 测试环境: develop 分支自动部署
- 生产环境: main 分支部署（需审批）

## 📊 服务地址

| 服务 | 开发环境 | 生产环境 |
|------|----------|----------|
| 前端应用 | http://localhost:5173 | http://localhost |
| 后端 API | http://localhost:3000 | http://localhost:3000 |
| Gitea 仓库 | http://192.168.31.84:8081 | - |

## 🗄️ 数据库配置

```bash
# 开发环境
DATABASE_URL=sqlite:./backend/data/dev.db

# 生产环境
DATABASE_URL=sqlite:./data/prod.db  # 容器内路径
```

**数据库特性**:
- ✅ 自动迁移和表结构创建
- ✅ 数据持久化存储
- ✅ 自动备份机制
- ✅ 测试数据自动生成

## 🛠️ 可用脚本

### 开发脚本
```bash
npm run dev                    # 全栈开发服务器
npm run dev:backend           # 仅后端
npm run dev:frontend          # 仅前端
npm run build                 # 全栈构建
npm run test                  # 全栈测试
```

### 部署脚本
```bash
./scripts/deploy.sh deploy    # 完整部署
./scripts/deploy.sh start     # 启动服务
./scripts/deploy.sh stop      # 停止服务
./scripts/deploy.sh restart   # 重启服务
./scripts/deploy.sh logs      # 查看日志
./scripts/deploy.sh backup    # 数据备份
./scripts/deploy.sh cleanup   # 清理资源
./scripts/deploy.sh status    # 服务状态
```

### Gitea 脚本
```bash
./scripts/gitea-init.sh       # 初始化 Gitea 仓库
```

## 🔧 环境配置

### 开发环境要求
- **Node.js**: 18+
- **Rust**: 1.75+
- **Podman**: 4.0+
- **Git**: 2.40+

### 环境变量
```bash
# 后端配置
RUST_LOG=info
DATABASE_URL=sqlite:./backend/data/dev.db
ENABLE_PERSISTENCE=true
CREATE_TEST_DATA=true

# 前端配置
VITE_API_BASE_URL=http://localhost:3000
VITE_APP_TITLE=FMOD v7 Project
```

## 📚 文档

- 📖 [Gitea 设置指南](docs/gitea-setup.md) - 完整的 CI/CD 配置指南
- 🏗️ [后端架构文档](backend/README.md) - FMOD v7 架构说明
- 🎨 [前端架构文档](web/README.md) - Web v7 架构说明

## 🤝 贡献指南

1. Fork 项目到您的 Gitea 账户
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 在 Gitea 中创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

---

## 🎯 核心特性

### ✅ FMOD v7 后端架构
- Function-First 设计
- Static Dispatch + 泛型优化
- 零运行时开销
- 完整类型安全

### ✅ Web v7 前端架构  
- Slice Independence 原则
- Signal-First 响应式设计
- 四种解耦通信机制
- 零编译依赖

### ✅ 现代化 DevOps
- Gitea + Podman CI/CD
- 自动化部署流水线
- 容器化生产部署
- 数据备份和监控

**通过这套完整的技术栈，您将获得企业级的开发体验和生产级的部署能力！**
