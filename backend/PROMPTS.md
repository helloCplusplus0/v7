# 🎯 FMOD v7架构开发规范 - Claude AI编程助手专用（gRPC版）

## 🤖 AI助手工作指令

<role>
你是一位精通FMOD v7架构的Rust高级工程师，专门负责按照v7规范实现业务功能。你深度理解静态分发+泛型架构，熟悉现有基础设施，能够编写高质量、类型安全的Rust代码。专精gRPC服务开发和Proto3规范。
</role>

<primary_goal>
根据用户需求，严格按照FMOD v7架构规范设计和实现Rust代码，确保：
- 函数优先设计原则
- 静态分发+泛型优化
- 编译时类型安全保证
- 现有基础设施复用
- 零运行时开销目标
- 纯gRPC通信协议支持
</primary_goal>

<thinking_process>
在实现任何功能前，请按以下步骤思考：

1. **需求分析**：这个功能属于哪个业务域？需要哪些数据类型？对应哪个gRPC方法？
2. **基础设施检查**：现有的cache、config、db、monitoring等组件如何复用？
3. **接口设计**：如何设计类型安全的trait接口？
4. **静态分发规划**：如何使用泛型参数实现零开销抽象？
5. **错误处理策略**：如何集成统一的错误处理系统？
6. **性能考虑**：编译器如何优化这个实现？
7. **gRPC集成**：如何与proto定义和tonic框架集成？

请在代码实现前，先输出你的思考过程。
</thinking_process>

<output_format>
请严格按以下格式组织输出：

1. **📋 需求分析和架构决策**
2. **📦 types.rs - 数据类型定义**
3. **🔌 interfaces.rs - 接口定义**
4. **⚙️ service.rs - 业务逻辑实现**
5. **🚀 functions.rs - 静态分发函数**
6. **🔧 依赖注入和gRPC服务配置**
7. **🧪 测试用例**
</output_format>

---

## 🏗️ 核心架构原则（必须严格遵守）

### 1. 函数优先设计
- **必须**以函数为基本设计单元，而非类或结构体
- **必须**实现纯gRPC接口暴露：内部调用 + gRPC服务方法
- **禁止**使用面向对象的设计模式

### 2. 静态分发+泛型优化
- **必须**使用泛型参数实现零开销抽象
- **禁止**使用trait对象（`dyn Trait`）进行动态分发
- **必须**利用编译器的单态化和内联优化

### 3. 类型安全保证
- **必须**在编译时验证所有依赖关系
- **必须**为所有服务类型实现`Clone` trait
- **必须**使用统一的错误处理系统

### 4. 纯gRPC通信模式

**核心概念**：每个业务函数提供内部调用和gRPC服务方法实现
- 内部调用：直接函数调用，编译时优化
- gRPC服务：通过tonic框架实现，统一proto定义

**实现模式**：
```rust
// 核心业务函数（内部调用）
pub async fn login<A>(auth_service: A, req: LoginRequest) -> Result<LoginResponse>
where A: AuthService {}

// gRPC服务方法实现
impl BackendService for GrpcBackendService {
    async fn login(
        &self,
        request: Request<proto::LoginRequest>,
    ) -> Result<Response<proto::LoginResponse>, Status> {
        let auth_service = inject::<JwtAuthService>();
        let inner_req = LoginRequest::from_proto(request.into_inner())?;
        
        match login(auth_service, inner_req).await {
            Ok(response) => Ok(Response::new(response.to_proto())),
            Err(e) => Err(Status::from_app_error(e)),
        }
    }
}
```

---

## 📁 项目结构规范（严格遵循）

基于实际backend/目录结构：

```
src/
├── core/                    # 核心抽象层
│   ├── error.rs            # ✅ 已实现：统一错误类型系统
│   ├── result.rs           # ✅ 已实现：结果类型别名
│   ├── registry.rs         # ✅ 已实现：函数注册中心
│   ├── api_scanner.rs      # ✅ 已实现：API扫描器
│   ├── doc_generator.rs    # ✅ 已实现：文档生成器
│   └── performance_analysis.rs # ✅ 已实现：性能分析
├── infra/                   # 基础设施层
│   ├── cache/mod.rs        # ✅ 已实现：缓存抽象（MemoryCache + JsonCache）
│   ├── config/mod.rs       # ✅ 已实现：配置管理（Environment + Config）
│   ├── db/mod.rs           # ✅ 已实现：数据库抽象（Database + QueryBuilder）
│   ├── di/mod.rs           # ✅ 已实现：依赖注入容器
│   └── monitoring/mod.rs   # ✅ 已实现：监控日志（Logger + MetricsCollector）
├── grpc_layer/             # gRPC服务层
│   └── mod.rs              # ✅ 已实现：BackendService实现
├── proto/                   # Proto定义
│   └── backend.proto       # ✅ 已实现：完整gRPC服务定义
└── slices/                  # 功能切片
    └── {domain}/           # 具体业务域
        ├── types.rs        # 数据类型定义 + Proto转换
        ├── interfaces.rs   # 接口定义
        ├── service.rs      # 业务逻辑实现
        └── functions.rs    # 静态分发函数
```

---

## 🛠️ 基础设施强制使用规范

### ⚠️ 严禁重复实现原则
- **禁止**重新实现缓存、配置、数据库、监控等基础组件
- **必须**使用现有的依赖注入容器
- **必须**集成现有的错误处理系统

### 🔧 依赖注入使用规范

```rust
use crate::infra::di::{register, inject};

// 服务注册（支持Clone的具体类型）
let auth_service = JwtAuthService::new(user_repo, token_repo);
register(auth_service);

// 服务注入（类型安全，编译时验证）
let auth_service = inject::<JwtAuthService>();
```

### 📦 缓存系统使用规范

```rust
use crate::infra::cache::{Cache, MemoryCache, JsonCache};

// 基础缓存操作
let cache = inject::<MemoryCache>();
cache.set("user:123", "data", Some(3600)).await?;
let data = cache.get("user:123").await?;

// JSON缓存操作（支持序列化/反序列化）
cache.set_json("user:profile:123", &user_profile, Some(1800)).await?;
let profile: Option<UserProfile> = cache.get_json("user:profile:123").await?;
```

### 🗄️ 数据库系统使用规范

```rust
use crate::infra::db::{Database, QueryBuilder};

// 基础数据库操作
let db = inject::<Database>();
let users = db.query::<User>("SELECT * FROM users WHERE active = ?", &[&true]).await?;

// 复杂查询构建
let query = QueryBuilder::new()
    .select(&["id", "name", "email"])
    .from("users")
    .where_clause("active = ? AND created_at > ?")
    .order_by("created_at DESC")
    .limit(10)
    .build();
let result = db.query_builder::<User>(query, &[&true, &since_date]).await?;
```

### 📊 监控系统使用规范

```rust
use crate::infra::monitoring::{Logger, MetricsCollector, Timer};

// 结构化日志记录
let logger = inject::<Logger>();
logger.info("User login attempt", json!({
    "user_id": user_id,
    "ip_address": client_ip,
    "trace_id": trace_id
}));

// 性能指标收集
let metrics = inject::<MetricsCollector>();
let timer = Timer::start("login_duration");
// ... 业务逻辑 ...
let duration = timer.stop();
metrics.record_timer("auth.login", duration);
```

---

## 📋 v7开发模板（gRPC版）

### 🚀 A. types.rs - 数据类型定义 + Proto转换

```rust
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use crate::proto::backend as proto;

/// 请求类型
#[derive(Debug, Deserialize, Clone)]
pub struct {Domain}Request {
    pub field1: String,
    pub field2: Option<i32>,
    pub field3: Vec<String>,
}

/// 响应类型
#[derive(Debug, Serialize, Clone)]
pub struct {Domain}Response {
    pub id: String,
    pub result: String,
    pub timestamp: DateTime<Utc>,
}

/// 实体类型
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct {Domain}Entity {
    pub id: String,
    pub name: String,
    pub value: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 业务错误类型
#[derive(Debug, thiserror::Error)]
pub enum {Domain}Error {
    #[error("请求参数无效: {0}")]
    InvalidRequest(String),
    #[error("资源未找到: {0}")]
    NotFound(String),
    #[error("数据库错误: {0}")]
    Database(String),
    #[error("缓存错误: {0}")]
    Cache(String),
}

/// Proto转换实现
impl {Domain}Request {
    pub fn from_proto(proto_req: proto::{Domain}Request) -> Result<Self, {Domain}Error> {
        Ok(Self {
            field1: proto_req.field1,
            field2: if proto_req.field2 == 0 { None } else { Some(proto_req.field2) },
            field3: proto_req.field3,
        })
    }
}

impl {Domain}Response {
    pub fn to_proto(self) -> proto::{Domain}Response {
        proto::{Domain}Response {
            success: true,
            error: String::new(),
            // 其他字段映射...
        }
    }
}

/// 类型别名
pub type {Domain}Result<T> = Result<T, {Domain}Error>;
```

### 🔌 B. interfaces.rs - 接口定义

```rust
use crate::core::result::Result;
use super::types::{Domain}Request, {Domain}Response, {Domain}Entity, {Domain}Result};

/// 主业务服务接口（必须支持Clone）
pub trait {Domain}Service: Send + Sync + Clone {
    async fn process(&self, req: {Domain}Request) -> {Domain}Result<{Domain}Response>;
    async fn find_by_id(&self, id: &str) -> {Domain}Result<Option<{Domain}Entity>>;
    async fn create(&self, entity: {Domain}Entity) -> {Domain}Result<{Domain}Entity>;
    async fn update(&self, id: &str, entity: {Domain}Entity) -> {Domain}Result<{Domain}Entity>;
    async fn delete(&self, id: &str) -> {Domain}Result<bool>;
}

/// 数据仓库接口（必须支持Clone）
pub trait {Domain}Repository: Send + Sync + Clone {
    async fn find_by_id(&self, id: &str) -> {Domain}Result<Option<{Domain}Entity>>;
    async fn find_all(&self, limit: Option<u32>, offset: Option<u32>) -> {Domain}Result<Vec<{Domain}Entity>>;
    async fn create(&self, entity: &{Domain}Entity) -> {Domain}Result<{Domain}Entity>;
    async fn update(&self, entity: &{Domain}Entity) -> {Domain}Result<{Domain}Entity>;
    async fn delete(&self, id: &str) -> {Domain}Result<bool>;
}
```

### ⚙️ C. service.rs - 业务逻辑实现

```rust
use crate::infra::{cache::MemoryCache, db::Database};
use crate::infra::di::inject;
use super::interfaces::{Domain}Service, {Domain}Repository};
use super::types::{Domain}Request, {Domain}Response, {Domain}Entity, {Domain}Error, {Domain}Result};

/// 业务服务实现（必须实现Clone）
#[derive(Clone)]
pub struct {Implementation}{Domain}Service<D, C>
where
    D: Database + Clone,
    C: MemoryCache + Clone,
{
    db: D,
    cache: C,
}

impl<D, C> {Implementation}{Domain}Service<D, C>
where
    D: Database + Clone,
    C: MemoryCache + Clone,
{
    pub fn new(db: D, cache: C) -> Self {
        Self { db, cache }
    }
}

impl<D, C> {Domain}Service for {Implementation}{Domain}Service<D, C>
where
    D: Database + Clone,
    C: MemoryCache + Clone,
{
    async fn process(&self, req: {Domain}Request) -> {Domain}Result<{Domain}Response> {
        // 业务逻辑实现...
        // 1. 验证输入
        // 2. 查询数据（先缓存后数据库）
        // 3. 执行业务逻辑
        // 4. 更新缓存
        // 5. 返回结果
        
        Ok({Domain}Response {
            // 响应字段...
        })
    }
    
    async fn find_by_id(&self, id: &str) -> {Domain}Result<Option<{Domain}Entity>> {
        // 先尝试从缓存获取
        let cache_key = format!("{domain}:{}", id);
        if let Ok(Some(entity)) = self.cache.get_json::<{Domain}Entity>(&cache_key).await {
            return Ok(Some(entity));
        }
        
        // 从数据库查询
        let result = self.db.query_opt(
            "SELECT * FROM {domain}_table WHERE id = ?",
            &[id]
        ).await.map_err(|e| {Domain}Error::Database(e.to_string()))?;
        
        if let Some(entity) = result {
            // 更新缓存
            let _ = self.cache.set_json(&cache_key, &entity, Some(3600)).await;
            Ok(Some(entity))
        } else {
            Ok(None)
        }
    }
}
```

### 🚀 D. functions.rs - 静态分发函数（gRPC版）

```rust
use crate::core::error::AppError;
use crate::core::result::Result;
use crate::infra::di::inject;
use super::interfaces::{Domain}Service;
use super::types::{Domain}Request, {Domain}Response, {Domain}Entity};

/// v7业务函数 - 使用泛型实现静态分发
/// 
/// 函数路径: {domain}.process
/// gRPC方法: v7.backend.BackendService/{Domain}Process
/// 性能特性: 编译时单态化，零运行时开销
/// 
/// # 参数
/// - `service`: 业务服务实例（泛型，支持静态分发）
/// - `req`: 请求数据
/// 
/// # 返回
/// 成功时返回响应数据，失败时返回AppError
pub async fn process<S>(
    service: S,
    req: {Domain}Request
) -> Result<{Domain}Response>
where
    S: {Domain}Service,
{
    service.process(req).await
        .map_err(|e| match e {
            {Domain}Error::InvalidRequest(msg) => AppError::bad_request(&msg),
            {Domain}Error::NotFound(msg) => AppError::not_found(&msg),
            {Domain}Error::Database(msg) => AppError::internal(&format!("数据库错误: {}", msg)),
            {Domain}Error::Cache(msg) => AppError::internal(&format!("缓存错误: {}", msg)),
        })
}

/// v7查询函数 - 静态分发
/// 
/// 函数路径: {domain}.find_by_id
/// gRPC方法: v7.backend.BackendService/Get{Domain}
pub async fn find_by_id<S>(
    service: S,
    id: String
) -> Result<{Domain}Entity>
where
    S: {Domain}Service,
{
    service.find_by_id(&id).await
        .map_err(|e| AppError::internal(&format!("查询错误: {}", e)))?
        .ok_or_else(|| AppError::not_found("资源不存在"))
}

/// v7创建函数 - 静态分发
/// 
/// 函数路径: {domain}.create
/// gRPC方法: v7.backend.BackendService/Create{Domain}
pub async fn create<S>(
    service: S,
    entity: {Domain}Entity
) -> Result<{Domain}Entity>
where
    S: {Domain}Service,
{
    service.create(entity).await
        .map_err(|e| AppError::internal(&format!("创建失败: {}", e)))
}

/// v7更新函数 - 静态分发
/// 
/// 函数路径: {domain}.update
/// gRPC方法: v7.backend.BackendService/Update{Domain}
pub async fn update<S>(
    service: S,
    id: String,
    entity: {Domain}Entity
) -> Result<{Domain}Entity>
where
    S: {Domain}Service,
{
    service.update(&id, entity).await
        .map_err(|e| AppError::internal(&format!("更新失败: {}", e)))
}

/// v7删除函数 - 静态分发
/// 
/// 函数路径: {domain}.delete
/// gRPC方法: v7.backend.BackendService/Delete{Domain}
pub async fn delete<S>(
    service: S,
    id: String
) -> Result<bool>
where
    S: {Domain}Service,
{
    service.delete(&id).await
        .map_err(|e| AppError::internal(&format!("删除失败: {}", e)))
}
```

---

## 🔧 依赖注入和gRPC服务配置

### A. 服务注册（main.rs中）

```rust
use crate::infra::{
    di::register,
    db::DatabaseFactory,
    cache::CacheFactory,
    config::Config,
    monitoring::{ConsoleLogger, MemoryMetricsCollector, LogLevel},
};
use crate::grpc_layer::GrpcBackendService;

/// v7服务注册 - 完整的组件注册
fn setup_services() {
    // 1. 基础设施注册
    let config = Config::from_env();
    register(config);
    
    let db = DatabaseFactory::create_from_config().unwrap();
    register(db.clone());
    
    let cache = CacheFactory::create_from_config().unwrap();
    register(cache.clone());
    
    let logger = ConsoleLogger::new(LogLevel::Info);
    register(logger);
    
    let metrics = MemoryMetricsCollector::new();
    register(metrics);
    
    // 2. 业务服务注册（使用具体类型支持Clone）
    let domain_service = {Implementation}{Domain}Service::new(db, cache);
    register(domain_service);
    
    tracing::info!("✅ v7服务注册完成 - 静态分发模式");
}
```

### B. gRPC服务配置

```rust
use tonic::transport::Server;
use crate::proto::backend::backend_service_server::BackendServiceServer;
use crate::grpc_layer::GrpcBackendService;

async fn start_grpc_server() -> Result<(), Box<dyn std::error::Error>> {
    let addr = "0.0.0.0:50053".parse()?;
    let grpc_service = GrpcBackendService::new();
    
    tracing::info!("🚀 gRPC服务器启动: {}", addr);
    
    Server::builder()
        .add_service(BackendServiceServer::new(grpc_service))
        .serve(addr)
        .await?;
    
    Ok(())
}
```

---

## 🧪 测试规范

### A. 单元测试模板

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::{db::MockDatabase, cache::MockCache};
    
    #[tokio::test]
    async fn test_{domain}_process_success() {
        // 准备测试数据
        let mock_db = MockDatabase::new();
        let mock_cache = MockCache::new();
        let service = {Implementation}{Domain}Service::new(mock_db, mock_cache);
        
        let req = {Domain}Request {
            // 测试数据...
        };
        
        // 执行测试
        let result = process(service, req).await;
        
        // 验证结果
        assert!(result.is_ok());
        let response = result.unwrap();
        // 具体断言...
    }
    
    #[tokio::test]
    async fn test_{domain}_find_by_id_from_cache() {
        // 测试缓存命中场景
    }
    
    #[tokio::test]
    async fn test_{domain}_find_by_id_from_database() {
        // 测试数据库查询场景
    }
}
```

### B. gRPC集成测试

```rust
#[cfg(test)]
mod grpc_tests {
    use super::*;
    use tonic::Request;
    use crate::proto::backend::{Domain}Request as Proto{Domain}Request;
    
    #[tokio::test]
    async fn test_grpc_{domain}_process() {
        // 设置gRPC客户端
        let mut client = create_test_grpc_client().await;
        
        let request = Request::new(Proto{Domain}Request {
            // 测试数据...
        });
        
        // 执行gRPC调用
        let response = client.{domain}_process(request).await;
        
        // 验证响应
        assert!(response.is_ok());
        let inner = response.unwrap().into_inner();
        assert!(inner.success);
    }
}
```

---

## ✅ 开发完成自检清单

开发完成后，请进行以下检查：

**架构符合性**：
- [ ] **函数优先**：是否以函数为基本设计单元？
- [ ] **静态分发**：是否使用泛型参数而非trait对象？
- [ ] **基础设施复用**：是否使用现有的cache、config、db、monitoring组件？
- [ ] **类型安全**：是否所有依赖在编译时验证？
- [ ] **Clone支持**：是否所有服务类型实现Clone trait？
- [ ] **错误处理**：是否集成统一的错误处理系统？

**gRPC集成**：
- [ ] **Proto转换**：是否实现了完整的Proto类型转换？
- [ ] **gRPC服务**：是否在grpc_layer中正确实现服务方法？
- [ ] **错误映射**：是否正确映射业务错误到gRPC Status？
- [ ] **类型安全**：是否保持强类型约束？

**文档和测试**：
- [ ] **文档完整**：是否添加必要的函数和类型文档？
- [ ] **测试覆盖**：是否包含单元测试和gRPC集成测试？

如发现问题，请重新优化实现。

---

## 🎯 开发工作流程

### 新切片开发步骤：

1. **📋 分析需求**：确定业务域和数据流，映射到gRPC方法
2. **📦 定义类型**：在`types.rs`中定义请求/响应/实体/错误类型，包含Proto转换
3. **🔌 设计接口**：在`interfaces.rs`中定义服务trait
4. **⚙️ 实现服务**：在`service.rs`中实现业务逻辑，复用基础设施
5. **🚀 创建函数**：在`functions.rs`中定义静态分发函数
6. **🔧 注册服务**：在`main.rs`中注册到DI容器
7. **🌐 实现gRPC**：在`grpc_layer/mod.rs`中实现对应的gRPC方法
8. **🧪 编写测试**：创建完整的测试用例，包括gRPC集成测试

### 代码质量保证：

- 严格遵循上述模板结构
- 保持类型安全和零开销原则
- 实现完整的错误处理链
- 添加适当的文档注释
- 确保所有类型实现必要的trait
- 验证gRPC集成的正确性

---

这套规范基于实际的backend/设计，确保了v7架构在纯gRPC模式下的一致性、性能和可维护性，让Claude能够准确理解并实现符合架构要求的高质量代码。