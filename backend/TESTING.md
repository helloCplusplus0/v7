# 🧪 FMOD v7 测试指南

## 📋 问题说明

在开发过程中发现了一个数据恢复问题：
- **现象**: 删除项目后，刷新页面数据又出现了
- **根因**: `MemoryDatabase`在应用重启时会重新创建测试数据

## 🛠️ 解决方案

### 方案1: 环境变量控制（推荐用于开发）

```bash
# 启用数据持久化
export ENABLE_PERSISTENCE=true
export PERSIST_PATH=./data/dev_memory_db.json

# 控制测试数据创建
export CREATE_TEST_DATA=true  # 首次启动时创建
# 或
export CREATE_TEST_DATA=false # 不自动创建测试数据

# 启动应用
cargo run
```

### 方案2: 使用配置文件

```bash
# 复制开发配置
cp dev.env .env

# 编辑配置
nano .env

# 启动应用
cargo run
```

### 方案3: 纯内存模式（默认）

```bash
# 不设置任何环境变量，使用纯内存数据库
cargo run
```

## 🔧 配置选项详解

### 数据持久化配置

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| `ENABLE_PERSISTENCE` | `false` | 是否启用数据持久化到文件 |
| `PERSIST_PATH` | `./data/memory_db.json` | 持久化文件路径 |

### 测试数据配置

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| `CREATE_TEST_DATA` | `false` | 是否在数据库为空时创建测试数据 |

## 🎯 不同场景的推荐配置

### 开发调试（数据需要保持）
```bash
ENABLE_PERSISTENCE=true
PERSIST_PATH=./data/dev_db.json
CREATE_TEST_DATA=true
```

### 功能测试（每次重新开始）
```bash
ENABLE_PERSISTENCE=false
CREATE_TEST_DATA=true
```

### 生产环境（不创建测试数据）
```bash
ENABLE_PERSISTENCE=true
PERSIST_PATH=/var/lib/app/db.json
CREATE_TEST_DATA=false
```

### 单元测试（隔离环境）
```bash
ENABLE_PERSISTENCE=false
CREATE_TEST_DATA=false
```

## 🚀 快速启动命令

```bash
# 开发模式（带持久化和测试数据）
ENABLE_PERSISTENCE=true CREATE_TEST_DATA=true cargo run

# 测试模式（纯内存，有测试数据）
CREATE_TEST_DATA=true cargo run

# 生产模式（持久化，无测试数据）
ENABLE_PERSISTENCE=true CREATE_TEST_DATA=false cargo run
```

## 📁 文件结构

持久化启用后，数据文件结构：
```
backend/
├── data/
│   └── dev_memory_db.json  # 持久化的内存数据库文件
├── dev.env                 # 开发环境配置
└── TESTING.md             # 本文档
```

## 🔍 调试日志

启用调试日志查看数据操作：
```bash
RUST_LOG=debug cargo run
```

查看持久化相关日志：
```bash
RUST_LOG=fmod_slice::infra::db=debug cargo run
```

# Backend 测试指南

## 🎯 测试体系概览

本项目采用基于**功能切片 + 洋葱架构 + FCIS**的分层测试策略，确保代码质量和系统稳定性。

### 🔹 测试金字塔结构

```
        E2E Tests (少量)
       /              \
    Contract Tests (中等)
   /                    \
Integration Tests (适量)
/                        \
Unit Tests (大量)
```

## 🎯 测试原则与策略

### 单元测试原则
- **就近测试**：测试文件与源文件放在同一目录
- **纯函数优先**：重点测试Domain层的纯业务逻辑
- **快速执行**：单个测试应在毫秒级完成
- **高覆盖率**：目标覆盖率85%以上（Rust的类型安全性要求更高覆盖率）

### 集成测试原则
- **切片内协作**：测试Domain → Service → Adapter的数据流
- **数据库隔离**：每个测试使用独立的数据库事务
- **真实场景**：模拟实际的HTTP请求/响应
- **依赖方向验证**：确保洋葱架构的依赖方向正确

### 契约测试原则
- **API稳定性**：确保HTTP API的稳定性
- **向后兼容**：新版本不能破坏现有API契约
- **类型安全**：验证序列化/反序列化的正确性
- **错误处理**：验证各种错误场景的响应格式

### 端到端测试原则
- **关键路径**：只测试最重要的业务流程
- **真实环境**：使用真实的数据库和HTTP服务
- **并发测试**：验证高并发场景下的系统稳定性
- **性能验证**：包含响应时间和吞吐量测试

## 🛠️ 测试工具

### 核心框架
- **Rust 内置测试**：`#[test]` 用于单元测试
- **sqlx::test**：`#[sqlx::test]` 用于数据库集成测试
- **axum-test**：HTTP API 测试
- **tokio-test**：异步代码测试

### 辅助工具
- **fake**：测试数据生成
- **wiremock**：外部API模拟
- **criterion**：性能基准测试
- **tarpaulin**：代码覆盖率

## 🛠️ 测试工具配置

### 测试框架
- **内置测试**：Rust标准库的`#[cfg(test)]`
- **tokio-test**：异步代码测试
- **axum-test**：HTTP API测试
- **sqlx-test**：数据库测试

### Mock策略
- **切片内Mock**：每个切片维护自己的mock数据
- **数据库Mock**：使用内存SQLite进行快速测试
- **HTTP Mock**：使用wiremock模拟外部API调用
- **时间Mock**：使用mockall模拟时间相关操作

### 测试数据管理
- **Fixture工厂**：使用fake.rs生成测试数据
- **数据库迁移**：每个测试前重置数据库状态
- **环境隔离**：测试环境与开发环境完全隔离


## 📋 测试层级

### 1. 单元测试（Unit Tests）
- **位置**：与源文件同目录的 `*_test.rs` 文件
- **目标**：测试纯函数式业务逻辑，无副作用
- **执行速度**：毫秒级
- **覆盖率目标**：85%+

### 2. 集成测试（Integration Tests）
- **位置**：`tests/integration/` 目录
- **目标**：测试切片内各层协作
- **特点**：使用真实数据库，每个测试独立

### 3. 端到端测试（E2E Tests）
- **位置**：`tests/e2e/` 目录
- **目标**：测试完整的HTTP请求/响应流程
- **特点**：模拟真实用户场景


## 🚀 运行测试

### 快速开始

```bash
# 运行所有单元测试（最快）
cargo test --lib

# 运行所有测试
cargo test

# 监听模式
cargo watch -x test
```

### 使用测试脚本

```bash
# 给脚本执行权限
chmod +x scripts/test.sh

# 运行不同类型的测试
./scripts/test.sh unit        # 单元测试
./scripts/test.sh integration # 集成测试
./scripts/test.sh e2e         # 端到端测试
./scripts/test.sh all         # 所有测试
./scripts/test.sh coverage    # 生成覆盖率报告
./scripts/test.sh watch       # 监听模式
```

## 🗄️ 数据库测试设置

### PostgreSQL 设置（推荐）

1. **启动测试数据库**：
```bash
docker run -d \
  --name postgres-test \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=postgres \
  -p 5432:5432 \
  postgres:15
```

2. **设置环境变量**：
```bash
export DATABASE_URL="postgresql://postgres:password@localhost:5432/postgres"
```

3. **运行数据库测试**：
```bash
cargo test --test integration
```

### SQLite 设置（轻量级）

SQLite 测试不需要外部数据库，使用内存数据库：

```bash
export DATABASE_URL="sqlite::memory:"
cargo test --test integration
```

## 📁 测试文件组织

```
backend/
├── src/
│   └── slices/
│       └── hello_fmod/
│           ├── domain/
│           │   ├── model.rs
│           │   └── model_test.rs      # ✅ Domain层单元测试
│           ├── service/
│           │   ├── logic.rs
│           │   └── logic_test.rs      # ✅ Service层单元测试
│           └── adapter/
│               ├── controller.rs
│               └── controller_test.rs # ✅ Adapter层单元测试
├── tests/
│   ├── common/                        # ✅ 共享测试工具
│   │   ├── mod.rs
│   │   ├── fixtures.rs
│   │   └── helpers.rs
│   ├── integration/                   # ✅ 集成测试
│   │   └── hello_fmod_db_test.rs
│   └── e2e/                          # ✅ 端到端测试
│       └── hello_fmod_e2e.rs
└── scripts/
    └── test.sh                       # ✅ 测试运行脚本
```

## 🎯 测试最佳实践

### 1. 测试命名规范
```rust
#[test]
fn should_create_valid_hello_message() {
    // 测试实现
}

#[test]
fn should_reject_empty_message() {
    // 测试实现
}
```

### 2. AAA 模式（Arrange-Act-Assert）
```rust
#[test]
fn test_example() {
    // Arrange - 准备测试数据
    let input = "test data";
    
    // Act - 执行被测试的操作
    let result = function_under_test(input);
    
    // Assert - 验证结果
    assert_eq!(result, expected_output);
}
```

### 3. 数据库测试模式
```rust
#[sqlx::test]
async fn test_database_operation(pool: PgPool) {
    // 自动创建独立的测试数据库
    // 测试完成后自动清理
}
```

### 4. HTTP API 测试模式
```rust
#[tokio::test]
async fn test_api_endpoint() {
    let app = create_test_app();
    let server = TestServer::new(app).unwrap();
    
    let response = server
        .post("/api/hello")
        .json(&json!({"message": "test"}))
        .await;
    
    response.assert_status_ok();
}
```

## 📊 覆盖率报告

### 生成覆盖率报告
```bash
# 安装 tarpaulin
cargo install cargo-tarpaulin

# 生成 HTML 报告
cargo tarpaulin --out Html --output-dir target/coverage

# 查看报告
open target/coverage/tarpaulin-report.html
```
## 📊 测试覆盖率目标

| 测试类型 | 覆盖率目标 | 执行频率 | 执行时间 |
|---------|-----------|----------|----------|
| 单元测试 | 85%+ | 每次提交 | < 30s |
| 集成测试 | 75%+ | 每次提交 | < 2min |
| 契约测试 | 100% | 每次发布 | < 1min |
| E2E测试 | 关键路径 | 每日构建 | < 5min |
| 性能测试 | 基准对比 | 每周构建 | < 10min |

## 🚨 常见问题

### 1. 数据库连接失败
```bash
# 检查数据库是否运行
docker ps | grep postgres

# 检查环境变量
echo $DATABASE_URL

# 重启数据库容器
docker restart postgres-test
```

### 2. 测试超时
```rust
// 增加超时时间
#[tokio::test]
#[timeout(Duration::from_secs(30))]
async fn long_running_test() {
    // 测试实现
}
```

### 3. 并发测试冲突
```bash
# 串行运行测试
cargo test -- --test-threads=1

# 或者使用独立的数据库
#[sqlx::test]
async fn isolated_test(pool: PgPool) {
    // 每个测试自动获得独立数据库
}
```

## 🔧 CI/CD 集成

### GitHub Actions 示例
```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: password
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      - uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      
      - name: Run tests
        run: cargo test
        env:
          DATABASE_URL: postgresql://postgres:password@localhost:5432/postgres
```


## 🚨 注意事项

### 1. Rust特有的测试考虑
- **所有权测试**：验证数据所有权转移的正确性
- **生命周期测试**：确保引用的生命周期正确
- **错误处理测试**：充分测试Result和Option的各种情况
- **并发安全测试**：验证多线程环境下的数据安全

### 2. 性能测试重点
- **内存使用**：监控内存分配和释放
- **CPU使用率**：测试高负载下的CPU表现
- **响应时间**：API响应时间基准测试
- **吞吐量**：并发请求处理能力

### 3. 安全测试要点
- **输入验证**：测试各种恶意输入
- **SQL注入防护**：验证参数化查询
- **认证授权**：测试权限边界
- **数据泄露防护**：确保敏感数据不泄露


## 🔄 与前端测试的协调

### API契约同步
- 使用OpenAPI规范确保前后端API一致性
- 自动生成API客户端代码
- 契约测试覆盖所有API端点

### 数据格式验证
- JSON Schema验证请求/响应格式
- 类型定义在前后端保持同步
- 错误响应格式标准化

### 测试数据共享
- 使用相同的测试数据集
- 保持测试场景的一致性
- 协调集成测试的执行顺序

## 📚 参考资源

- [Rust 测试官方文档](https://doc.rust-lang.org/book/ch11-00-testing.html)
- [sqlx::test 文档](https://docs.rs/sqlx/latest/sqlx/attr.test.html)
- [axum-test 使用指南](https://docs.rs/axum-test/latest/axum_test/)
- [测试最佳实践](https://rust-lang.github.io/api-guidelines/testing.html)
