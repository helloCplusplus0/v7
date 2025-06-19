# FMOD v7 全栈项目

基于 FMOD v7 架构的现代全栈开发项目，采用前后端分离设计，集成**智能端口管理 Gitea + Podman CI/CD** 解决方案。

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
├── .gitea/               # 🚀 智能端口管理 Gitea CI/CD 配置
│   └── workflows/       # CI/CD 工作流
├── scripts/              # 🛠️ 自动化脚本
│   ├── deploy.sh        # 智能端口管理 Podman 部署脚本
│   ├── gitea-init.sh    # Gitea 仓库初始化
│   ├── start.sh         # 全栈启动脚本
│   ├── start-backend.sh # 后端独立启动
│   └── start-frontend.sh# 前端独立启动
├── docker-compose.yml    # Podman Compose 配置（可选）
├── docs/                 # 📚 项目文档
│   ├── gitea-checklist.md    # 智能端口管理配置清单
│   └── local-deployment-setup.md # 本地部署指南
├── .port-config         # 🎯 智能分配的端口配置文件（自动生成）
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
- **特性**: 零虚拟DOM、细粒度响应式、切片独立

### 🧠 智能端口管理系统
- **端口冲突检测**: 自动扫描端口占用状况
- **智能分配策略**: 首选端口被占用时自动递增查找
- **配置持久化**: 端口信息保存在 `.port-config` 文件
- **状态透明化**: 清晰的端口分配报告和状态显示

## 🚀 快速开始

### 1. 环境准备
```bash
# 克隆项目
git clone http://192.168.31.84:8081/username/fmod-v7-project.git
cd fmod-v7-project

# 一键初始化 Gitea 仓库
./scripts/gitea-init.sh
```

### 2. 本地开发
```bash
# 开发环境（热重载）
npm run dev                     # 全栈开发：前端 5173，后端 3000

# 或分别启动
npm run dev:frontend           # 仅前端：http://localhost:5173
npm run dev:backend            # 仅后端：http://localhost:3000

# 生产环境构建
npm run build                  # 全栈构建
npm run test                   # 全栈测试
```

### 3. 🎯 智能端口容器化部署
```bash
# 完整部署（推荐）
./scripts/deploy.sh deploy     # 智能端口分配 + 构建 + 部署

# 单独操作
./scripts/deploy.sh build      # 仅构建镜像
./scripts/deploy.sh start      # 智能端口启动
./scripts/deploy.sh ports      # 查看当前端口配置
./scripts/deploy.sh status     # 完整状态报告
```

### 4. 自动化 CI/CD
```bash
# 测试环境部署
git push origin develop         # → 自动部署到测试环境

# 生产环境部署  
git push origin main           # → 自动部署到生产环境
```

## 🧠 智能端口管理特性

### ✅ 自动端口分配策略

| 环境 | 前端首选端口 | 后端首选端口 | 冲突处理策略 |
|------|-------------|-------------|-------------|
| **开发环境** | 5173 | 3000 | 标准开发端口 |
| **测试环境** (staging) | 5173 | 3001 | 自动递增查找可用端口 |
| **生产环境** (production) | 8080 | 3000 | 自动递增查找可用端口 |

### 🔧 端口冲突智能解决

```bash
# 示例场景：端口 8080 被占用
首选端口 8080 (被占用) → 自动分配 8081 ✅
首选端口 8081 (被占用) → 自动分配 8082 ✅
...继续扫描直到找到可用端口

# 实时查看分配结果
./scripts/deploy.sh ports
```

### 📊 端口分配报告示例

```bash
🎯 部署完成报告：
┌─────────────────────────────────────────┐
│              FMOD v7 部署状态           │
├─────────────────────────────────────────┤
│ 环境: production                        │
│ 前端: ✅ http://localhost:8081          │
│ 后端: ✅ http://localhost:3000          │
│ API:  http://localhost:3000/health      │
└─────────────────────────────────────────┘
```

## 🌐 CI/CD 自动化部署

### 🔄 双环境自动部署策略

- **测试环境**: develop 分支自动部署，智能端口分配（首选 5173/3001）
- **生产环境**: main 分支自动部署，智能端口分配（首选 8080/3000）

## 📊 服务地址配置

| 服务 | 开发环境 | 测试环境 | 生产环境 |
|------|----------|----------|----------|
| 前端应用 | http://localhost:5173 | http://localhost:5173+ | http://localhost:8080+ |
| 后端 API | http://localhost:3000 | http://localhost:3001+ | http://localhost:3000+ |
| 健康检查 | http://localhost:3000/health | http://localhost:3001+/health | http://localhost:3000+/health |
| Gitea 仓库 | http://192.168.31.84:8081 | - | - |

**注**：`+` 表示如果首选端口被占用，会自动递增到下一个可用端口

## 🗄️ 数据库配置

```bash
# 开发环境
DATABASE_URL=sqlite:./backend/data/dev.db

# 容器环境（自动管理）
# 测试环境: fmod-data-staging volume
# 生产环境: fmod-data-production volume
```

**数据库特性**:
- ✅ 自动迁移和表结构创建
- ✅ 数据持久化存储（Podman volumes）
- ✅ 自动备份机制
- ✅ 测试数据自动生成
- ✅ 环境隔离（测试/生产独立数据）

## 🛠️ 可用脚本

### 开发脚本
```bash
npm run dev                    # 全栈开发服务器
npm run dev:backend           # 仅后端
npm run dev:frontend          # 仅前端
npm run build                 # 全栈构建
npm run test                  # 全栈测试
```

### 智能端口部署脚本
```bash
./scripts/deploy.sh deploy    # 完整部署（智能端口分配）
./scripts/deploy.sh start     # 启动服务（智能端口分配）
./scripts/deploy.sh stop      # 停止服务
./scripts/deploy.sh restart   # 重启服务（重新分配端口）
./scripts/deploy.sh logs      # 查看日志
./scripts/deploy.sh backup    # 数据备份
./scripts/deploy.sh cleanup   # 清理资源
./scripts/deploy.sh status    # 完整服务状态
./scripts/deploy.sh ports     # 端口配置信息
./scripts/deploy.sh help      # 帮助信息
```

### 端口管理环境变量
```bash
# 自定义端口配置（可选）
FRONTEND_PORT_PRODUCTION=9090 ./scripts/deploy.sh deploy  # 生产环境自定义前端端口
ENVIRONMENT=staging ./scripts/deploy.sh start            # 启动测试环境
```

### Gitea 脚本
```bash
./scripts/gitea-init.sh       # 初始化 Gitea 仓库
```

## 🔧 环境配置

### 开发环境要求
- **Node.js**: 18+
- **Rust**: 1.75+
- **Podman**: 4.0+（CI 会自动安装）
- **Git**: 2.40+

### 系统要求
- **磁盘空间**: 2GB+（用于镜像和数据）
- **内存**: 2GB+（运行容器）
- **操作系统**: Ubuntu 20.04+ / CentOS 8+

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

# 智能端口管理配置（可选）
FRONTEND_PORT_PRODUCTION=8080   # 生产环境前端首选端口
BACKEND_PORT_PRODUCTION=3000    # 生产环境后端首选端口
FRONTEND_PORT_STAGING=5173      # 测试环境前端首选端口
BACKEND_PORT_STAGING=3001       # 测试环境后端首选端口
```

## 🐳 容器管理

### 智能端口容器命名规则
```bash
# 测试环境容器
fmod-frontend-staging    # 前端测试容器 (端口 5173+)
fmod-backend-staging     # 后端测试容器 (端口 3001+)

# 生产环境容器
fmod-frontend-production # 前端生产容器 (端口 8080+)
fmod-backend-production  # 后端生产容器 (端口 3000+)
```

### 常用管理命令
```bash
# 查看智能分配的端口
./scripts/deploy.sh ports

# 查看容器状态
podman ps | grep fmod

# 查看日志
podman logs -f fmod-backend-production

# 重启特定容器（会重新分配端口）
./scripts/deploy.sh restart

# 进入容器调试
podman exec -it fmod-backend-production /bin/bash

# 查看资源使用
podman stats
```

## 🚫 端口冲突解决方案

### 为什么不再使用端口 80？

1. **权限问题**：端口 80 需要 sudo 权限
2. **常被占用**：系统 Web 服务器（Apache/Nginx）通常占用 80 端口
3. **更安全**：8080 端口无需特殊权限
4. **CI/CD 友好**：自动化部署无需权限配置

### 智能端口管理优势

- ✅ **零配置冲突处理**：自动检测和解决端口冲突
- ✅ **透明状态报告**：清晰显示分配结果
- ✅ **持久化配置**：端口信息自动保存
- ✅ **友好错误提示**：详细的错误信息和解决建议

## 📚 文档

- 📖 [智能端口管理配置清单](docs/gitea-checklist.md) - 快速配置指南
- 🏠 [本地部署指南](docs/local-deployment-setup.md) - 详细部署说明
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
- 零虚拟DOM性能优化
- 四种解耦通信机制

### ✅ 智能端口管理 CI/CD
- 自动端口冲突检测和解决
- 双环境自动化部署（测试/生产）
- 零配置容器化部署
- 数据持久化和备份

## 🔍 故障排除

### 端口冲突问题

```bash
# 查看当前端口分配
./scripts/deploy.sh ports

# 重新部署以重新分配端口
./scripts/deploy.sh restart

# 手动停止冲突服务
sudo netstat -tulpn | grep :8080
```

### 服务健康检查

```bash
# 检查服务状态
curl http://localhost:$(cat .port-config | grep BACKEND_PORT | cut -d'=' -f2)/health

# 查看详细状态
./scripts/deploy.sh status

# 查看容器日志
./scripts/deploy.sh logs
```

---

## 🎉 开始使用

```bash
# 1. 克隆并初始化
git clone http://192.168.31.84:8081/username/fmod-v7-project.git
cd fmod-v7-project
./scripts/gitea-init.sh

# 2. 本地开发
npm run dev

# 3. 智能端口部署
./scripts/deploy.sh deploy

# 4. 自动化部署
git push origin main
```

**现在您完全不用担心端口冲突了！** 🎯 专注于业务开发，让智能端口管理系统处理基础设施问题。
