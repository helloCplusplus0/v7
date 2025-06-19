## 目录结构
```markdown
backend/
├── 📂 src/                    # 核心源代码
│   ├── 📄 main.rs            # ✅ HTTP服务器入口
│   ├── 📄 lib.rs             # ✅ 库根模块  
│   └── 📂 slices/            # ✅ 功能切片
│       ├── 📄 mod.rs         # ✅ 模块声明
│       └── 📄 registry.rs    # ✅ 切片注册表
├── 📂 tests/                 # 分层测试
│   ├── 📂 common/            # ✅ 公共测试工具
│   ├── 📂 integration/       # ✅ 集成测试
│   └── 📂 e2e/               # ✅ 端到端测试
├── 📂 config/                # ✅ 配置管理
│   └── 📄 app.toml           # ✅ 应用配置
├── 📂 data/                  # ✅ 数据存储
│   └── 📄 .gitkeep           # ✅ Git跟踪文件
├── 📄 Cargo.toml             # ✅ 项目配置（已存在）
├── 📄 TESTING.md             # ✅ 测试文档（已存在）
└── 📂 scripts/               # ✅ 开发脚本（已存在）
```

## 🚀 快速开始

### 1. 运行测试
```bash
# 编译并运行所有测试
cargo test
```

### 2. API文档生成（推荐）
```bash
# 使用运行时数据收集生成100%准确的API文档
./scripts/runtime_api_export.sh
```

### 3. 查看生成的API文档
```bash
# 查看API文档
cat docs/api/README.md

# 查看OpenAPI规范
cat docs/api/openapi.json

# 查看生成的TypeScript类型
cat frontend/src/types/api.ts
```

- 生产环境和前端集成请只使用 `runtime_api_export.sh` 的输出

## 📖 详细文档

- **[API导出工作流程](docs/API_EXPORT_WORKFLOW.md)** - 完整的API文档生成指南
- **[测试文档](TESTING.md)** - 测试策略和执行指南
- **[v7架构文档](docs/v7.md)** - FMOD v7架构详细说明

## 🎯 技术特性

- ✅ **静态分派+泛型**：零运行时开销的架构设计
- ✅ **函数优先**：以函数为核心的设计模式
- ✅ **运行时API收集**：100%准确的API文档生成
- ✅ **类型安全**：编译时类型检查保证
- ✅ **基础设施复用**：完善的缓存、配置、数据库等组件