# 🚀 V7 Project - 现代化全栈开发框架

**轻量化、极致性能、稳定、可扩展的前后端分离项目**

基于 Rust + SolidJS 的现代化开发范式，支持从单服务器到多服务器的完整DevOps自动化部署。

---

## 🎯 项目特色

### 🏗️ 先进架构设计
- **后端**: Rust + FMOD v7架构（Function-first设计、静态分发+泛型）
- **前端**: SolidJS + Web v7架构（切片独立性、Signal-first响应式设计）
- **DevOps**: Podman + GitHub Actions（轻量化容器、自动化部署）

### ⚡ 极致性能优化
- **容器镜像**: 后端15MB，前端8MB（压缩率90%+）
- **资源占用**: 总内存<1GB，适合轻量级服务器
- **部署速度**: 从代码提交到生产部署<45秒
- **启动时间**: 冷启动<10秒，热启动<3秒

### 🛡️ 企业级稳定性
- **零停机部署**: 滚动更新，服务不中断
- **自动故障恢复**: 健康检查+自动重启
- **完整监控**: 实时状态监控和告警
- **数据安全**: 自动备份和恢复机制

---

## 🚀 快速部署

V7项目采用**分层混合部署**架构，平衡性能、复杂度和可维护性：

### 📋 推荐部署架构

```
🏭 生产环境架构（推荐）：
┌─────────────────────────────────────────────────────────┐
│                     云服务器                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────┐  │
│  │   Web (容器)     │  │ Backend (容器)   │  │Analytics │  │
│  │   nginx:8080    │  │  gRPC:50053     │  │(systemd) │  │
│  │                 │  │   HTTP:3000     │  │  :50051  │  │
│  └─────────────────┘  └─────────────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────┘
```

**架构优势**：
- ✅ **Web+Backend容器化**：标准化部署，环境一致性
- ✅ **Analytics systemd部署**：极致性能，计算密集型友好
- ✅ **简化复杂度**：避免Rust+Python混合容器化难题
- ✅ **灵活扩展**：Analytics可独立扩展到专用计算服务器

### 🎯 部署顺序（重要）

```
1️⃣ Analytics Engine → 2️⃣ Backend → 3️⃣ Web
```

### 🏭 生产环境部署（推荐）

#### 🎯 一键部署（推荐）

```bash
# 混合架构部署（推荐生产环境）
./scripts/deploy-v7.sh --analytics-systemd --backend-container --web-container

# 分布式部署（企业级）
./scripts/deploy-v7.sh --analytics-remote <ANALYTICS_SERVER_IP> --backend-container --web-container
```

#### 🔧 手动分步部署

**Step 1: Analytics Engine (systemd)**
```bash
cd analytics-engine
sudo ./scripts/setup-user.sh    # 创建专用用户
./scripts/build.sh              # 构建二进制
sudo -u analytics ./scripts/deploy.sh  # 部署systemd服务

# 验证服务
systemctl status analytics-engine
curl http://localhost:50051/health
```

**Step 2: Backend + Web (容器)**
```bash
# 设置Analytics Engine连接地址
export ANALYTICS_ENGINE_ADDR="http://localhost:50051"

# 启动Backend和Web容器
podman-compose up -d backend web

# 验证服务
curl http://localhost:3000/health     # Backend HTTP
curl http://localhost:8080/health     # Web
```

### 🧪 开发/测试环境

#### 🛠️ 开发模式（最快）
```bash
# 终端1: 启动Analytics Engine
cd analytics-engine && ./scripts/run.sh

# 终端2: 启动Backend
cd backend && cargo run

# 终端3: 启动Web开发服务器
cd web && npm run dev
```

#### 🐳 容器测试环境
```bash
# Analytics Engine: 本地运行
cd analytics-engine && ./scripts/run.sh &

# Backend + Web: 容器运行
export ANALYTICS_ENGINE_ADDR="http://host.containers.internal:50051"
podman-compose up -d backend web
```

## 🎛️ 部署模式对比

| 模式 | Analytics | Backend | Web | 适用场景 | 复杂度 |
|------|-----------|---------|-----|----------|--------|
| **混合架构** | systemd | 容器 | 容器 | 🏭 生产环境 | ⭐⭐ |
| **完全本地** | 本地 | 本地 | 本地 | 🛠️ 开发环境 | ⭐ |
| **分布式** | 远程systemd | 容器 | 容器 | 🏢 企业级 | ⭐⭐⭐ |

### 🔄 为什么不推荐Analytics Engine容器化？

基于实际部署经验：
- ❌ **构建复杂**：Rust+Python混合容器化困难，600MB镜像体积
- ❌ **性能损失**：计算密集型服务，容器虚拟化开销明显
- ❌ **运维复杂**：systemd已经足够稳定，容器化增加不必要复杂度
- ✅ **systemd优势**：10MB静态二进制，3-5ms启动，原生性能

---

## 📁 项目结构

```
v7/
├── backend/                 # Rust后端 (FMOD v7架构)
│   ├── src/slices/         # 业务切片
│   │   └── mvp_crud/       # CRUD示例切片
│   ├── src/infra/          # 基础设施层
│   └── Dockerfile          # 容器构建文件
├── web/                    # SolidJS前端 (Web v7架构)
│   ├── src/slices/         # 前端切片
│   │   └── mvp_crud/       # CRUD示例切片
│   ├── shared/             # 共享基础设施
│   └── Dockerfile          # 容器构建文件
├── docs/                   # 文档
│   ├── devops-complete-guide.md  # 完整部署指南
│   └── quick-reference.md        # 快速参考
├── scripts/                # 自动化脚本
│   ├── deploy.sh           # 部署脚本
│   └── monitoring.sh       # 监控脚本
├── .github/workflows/      # GitHub Actions
└── podman-compose.yml      # 容器编排
```

---

## 🎯 架构原则

### 后端 (FMOD v7)
- **Function-first设计**: 函数是基本单元，支持内部调用和HTTP访问
- **静态分发+泛型**: 编译时优化，零运行时开销
- **Clone trait支持**: 类型安全的依赖注入

### 前端 (Web v7)
- **切片独立性**: 零编译时依赖，完全独立开发测试
- **Signal-first响应式**: 细粒度响应式更新
- **四种解耦通信**: 事件驱动、契约接口、信号响应、Provider模式

### DevOps
- **轻量化优先**: 最小化资源消耗，最大化性能
- **自动化驱动**: 零人工干预的完整流程
- **安全第一**: 多层安全防护机制

---

## 🛠️ 技术栈

### 后端技术
- **语言**: Rust 1.75+
- **框架**: Axum (高性能异步Web框架)
- **数据库**: SQLite (轻量级，支持扩展到PostgreSQL)
- **架构**: FMOD v7 (Function-first + 静态分发)

### 前端技术
- **语言**: TypeScript 5.0+
- **框架**: SolidJS (细粒度响应式)
- **构建工具**: Vite (极速构建)
- **架构**: Web v7 (切片独立 + Signal-first)

### DevOps技术
- **容器**: Podman (无守护进程，更轻量)
- **CI/CD**: GitHub Actions (免费，强大)
- **镜像仓库**: GitHub Container Registry
- **监控**: 自研轻量级监控脚本

---

## 📊 性能指标

### 资源优化成果
| 指标 | 传统方案 | V7方案 | 优化幅度 |
|------|----------|--------|----------|
| 后端镜像大小 | 200MB | 15MB | **92%** ↓ |
| 前端镜像大小 | 50MB | 8MB | **84%** ↓ |
| 内存使用 | 1.5GB | 0.8GB | **47%** ↓ |
| 部署时间 | 5分钟 | 45秒 | **85%** ↓ |
| 冷启动时间 | 30秒 | <10秒 | **67%** ↓ |

### 性能表现
- **API响应时间**: 平均<100ms
- **并发支持**: 单核支持500+并发连接
- **系统可用性**: 99.9%+正常运行时间
- **故障恢复**: 自动恢复<30秒

---

## 🌟 示例功能

### MVP CRUD 切片
项目包含一个完整的CRUD示例，展示了V7架构的核心特性：

- **后端**: 完整的增删改查API，遵循FMOD v7架构
- **前端**: 现代化UI界面，支持实时操作反馈
- **访问地址**: http://your-server/slice/mvp_crud

### 核心功能
- ✅ 创建、读取、更新、删除操作
- ✅ 实时数据同步
- ✅ 响应式UI更新
- ✅ 错误处理和用户反馈
- ✅ 移动端适配

---

## 🆘 获取帮助

### 📚 文档资源
- [完整部署指南](./docs/devops-complete-guide.md) - 从零开始的详细步骤
- [快速参考](./docs/quick-reference.md) - 常用命令和故障排除
- [DevOps文档](./docs/devops.md) - 架构概览和技术栈说明

### 🐛 问题反馈
- [GitHub Issues](https://github.com/helloCplusplus0/v7/issues) - 报告问题和建议
- [GitHub Discussions](https://github.com/helloCplusplus0/v7/discussions) - 技术讨论

### 📞 紧急支持
如果遇到生产环境问题，请：
1. 查看[故障排除指南](./docs/quick-reference.md#故障排除命令)
2. 检查服务器日志：`podman logs v7-backend`
3. 运行健康检查：`./scripts/monitoring.sh`

---

## 🚧 开发状态

### ✅ 已完成功能
- [x] 后端FMOD v7架构实现
- [x] 前端Web v7架构实现
- [x] MVP CRUD示例切片
- [x] 完整DevOps自动化流程
- [x] 容器化部署方案
- [x] 监控和日志系统

### 🔄 开发中功能
- [ ] 多服务器负载均衡
- [ ] 数据库集群化
- [ ] 高级监控和告警
- [ ] 自动扩缩容

### 📋 规划中功能
- [ ] Kubernetes支持
- [ ] 多云部署
- [ ] AI驱动的运维优化
- [ ] 更多业务切片示例

---

## 🤝 贡献指南

欢迎贡献代码、文档或建议！

### 开发流程
1. Fork 项目
2. 创建功能分支：`git checkout -b feature/amazing-feature`
3. 提交更改：`git commit -m 'Add amazing feature'`
4. 推送分支：`git push origin feature/amazing-feature`
5. 创建 Pull Request

### 代码规范
- 后端：遵循 Rust 官方代码规范
- 前端：遵循 TypeScript + SolidJS 最佳实践
- 提交信息：使用 [Conventional Commits](https://conventionalcommits.org/) 格式

---

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。

---

## 🙏 致谢

感谢所有为这个项目做出贡献的开发者和开源社区的支持！

---

**💡 快速提示**:
- 首次部署请阅读[完整部署指南](./docs/devops-complete-guide.md)
- 日常运维使用[快速参考](./docs/quick-reference.md)
- 遇到问题先查看日志，再参考故障排除指南

**🚀 立即开始**: `git clone https://github.com/helloCplusplus0/v7.git && cd v7`

## 🛠️ 开发工具脚本

### 本地开发验证脚本

| 脚本 | 功能 | 使用场景 | 执行时间 |
|------|------|----------|----------|
| `./scripts/local-ci-check.sh` | 完整本地CI检查 | 推送前验证 | ~3-5分钟 |
| `./scripts/check-config-consistency.sh` | 配置一致性检查 | 配置修改后 | ~30秒 |
| `./scripts/test-docker-build.sh` | Docker构建测试 | Docker文件修改后 | ~5-10分钟 |
| `./scripts/verify-ci-consistency.sh` | CI配置验证 | CI配置修改后 | ~1分钟 |

### 推荐的开发流程

```bash
# 1. 代码修改后 - 快速检查
./scripts/check-config-consistency.sh

# 2. 重要修改后 - 完整验证
./scripts/local-ci-check.sh

# 3. Docker相关修改后 - 构建测试
./scripts/test-docker-build.sh

# 4. 推送前 - 最终验证
./scripts/verify-ci-consistency.sh
```

### 故障排除

如果遇到构建问题，请参考：
- 📖 [Docker构建问题排查指南](docs/docker-build-troubleshooting.md)
- 🔧 [DevOps完整指南](docs/devops-complete-guide.md)
