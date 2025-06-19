
## 4. 切片实现示例

### 4.1 用户认证切片(auth)

#### 目录结构

```
slices/
└── auth/
    ├── functions.rs       # 暴露的API函数
    ├── types.rs           # 数据模型和请求/响应类型
    ├── interfaces.rs      # 接口定义
    ├── service.rs         # 业务逻辑实现
    └── mod.rs             # 模块入口
```

#### types.rs - 数据类型定义

```rust
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

/// 认证请求
#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

/// 认证响应
#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub token: String,
    pub user_id: String,
    pub expires_at: DateTime<Utc>,
}

/// 用户会话模型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserSession {
    pub user_id: String,
    pub username: String,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
}

/// 认证错误
#[derive(Debug, thiserror::Error)]
pub enum AuthError {
    #[error("无效的凭证")]
    InvalidCredentials,
    
    #[error("用户不存在")]
    UserNotFound,
    
    #[error("令牌已过期")]
    TokenExpired,
    
    #[error("令牌无效")]
    InvalidToken,
    
    #[error("数据库错误: {0}")]
    Database(String),
}

/// 统一结果类型
pub type AuthResult<T> = Result<T, AuthError>;
```

#### interfaces.rs - 接口定义

```rust
use crate::core::error::AppResult;
use super::types::{LoginRequest, LoginResponse, UserSession, AuthResult};

/// 认证服务接口
pub trait AuthService {
    /// 验证用户凭证并生成令牌
    fn authenticate(&self, req: &LoginRequest) -> AuthResult<LoginResponse>;
    
    /// 验证令牌有效性并返回用户会话
    fn validate_token(&self, token: &str) -> AuthResult<UserSession>;
    
    /// 撤销指定令牌
    fn revoke_token(&self, token: &str) -> AuthResult<()>;
}

/// 用户存储接口
pub trait UserRepository {
    /// 通过用户名查找用户
    fn find_by_username(&self, username: &str) -> AppResult<Option<UserModel>>;
    
    /// 验证用户凭证
    fn verify_credentials(&self, username: &str, password: &str) -> AppResult<bool>;
}

/// 令牌存储接口
pub trait TokenRepository {
    /// 创建新令牌
    fn create_token(&self, user_id: &str) -> AppResult<String>;
    
    /// 获取令牌关联的会话
    fn get_session(&self, token: &str) -> AppResult<Option<UserSession>>;
    
    /// 撤销令牌
    fn revoke(&self, token: &str) -> AppResult<()>;
}
```

#### service.rs - 业务逻辑实现

```rust
use chrono::{Duration, Utc};
use argon2::{self, Config};
use rand::Rng;
use uuid::Uuid;

use crate::core::error::AppError;
use crate::infra::db::Database;
use crate::infra::cache::Cache;

use super::interfaces::{AuthService, UserRepository, TokenRepository};
use super::types::{LoginRequest, LoginResponse, UserSession, AuthError, AuthResult};

/// 用户仓库实现
pub struct DbUserRepository {
    db: Database,
}

impl DbUserRepository {
    pub fn new(db: Database) -> Self {
        Self { db }
    }
}

impl UserRepository for DbUserRepository {
    fn find_by_username(&self, username: &str) -> AppResult<Option<UserModel>> {
        let query = format!("SELECT * FROM users WHERE username = '{}'", username);
        let result = self.db.query_one(&query)?;
        
        if result.is_empty() {
            return Ok(None);
        }
        
        // 简化示例，实际应使用参数化查询和正确的解析
        let user = UserModel {
            id: result.get("id").unwrap_or_default().to_string(),
            username: result.get("username").unwrap_or_default().to_string(),
            password_hash: result.get("password_hash").unwrap_or_default().to_string(),
        };
        
        Ok(Some(user))
    }
    
    fn verify_credentials(&self, username: &str, password: &str) -> AppResult<bool> {
        let user = self.find_by_username(username)?;
        
        match user {
            Some(user) => {
                let matches = argon2::verify_encoded(&user.password_hash, password.as_bytes())
                    .map_err(|e| AppError::internal(&format!("密码验证错误: {}", e)))?;
                Ok(matches)
            },
            None => Ok(false),
        }
    }
}

/// 令牌仓库实现
pub struct CacheTokenRepository {
    cache: Cache,
}

impl CacheTokenRepository {
    pub fn new(cache: Cache) -> Self {
        Self { cache }
    }
    
    // 生成安全的随机令牌
    fn generate_token() -> String {
        Uuid::new_v4().to_string()
    }
}

impl TokenRepository for CacheTokenRepository {
    fn create_token(&self, user_id: &str) -> AppResult<String> {
        let token = Self::generate_token();
        let now = Utc::now();
        let expires = now + Duration::hours(24);
        
        let session = UserSession {
            user_id: user_id.to_string(),
            username: "".to_string(), // 简化示例，实际应获取用户名
            created_at: now,
            expires_at: expires,
        };
        
        let session_json = serde_json::to_string(&session)
            .map_err(|e| AppError::internal(&format!("序列化会话失败: {}", e)))?;
        
        self.cache.set(&format!("token:{}", token), &session_json, Some(86400))?;
        
        Ok(token)
    }
    
    fn get_session(&self, token: &str) -> AppResult<Option<UserSession>> {
        let key = format!("token:{}", token);
        let data = self.cache.get(&key)?;
        
        match data {
            Some(json) => {
                let session = serde_json::from_str(&json)
                    .map_err(|e| AppError::internal(&format!("反序列化会话失败: {}", e)))?;
                Ok(Some(session))
            },
            None => Ok(None),
        }
    }
    
    fn revoke(&self, token: &str) -> AppResult<()> {
        let key = format!("token:{}", token);
        self.cache.delete(&key)
    }
}

/// 认证服务实现
pub struct JwtAuthService {
    user_repo: Box<dyn UserRepository>,
    token_repo: Box<dyn TokenRepository>,
}

impl JwtAuthService {
    pub fn new(
        user_repo: Box<dyn UserRepository>,
        token_repo: Box<dyn TokenRepository>
    ) -> Self {
        Self { user_repo, token_repo }
    }
}

impl AuthService for JwtAuthService {
    fn authenticate(&self, req: &LoginRequest) -> AuthResult<LoginResponse> {
        // 验证凭证
        let valid = self.user_repo.verify_credentials(&req.username, &req.password)
            .map_err(|e| AuthError::Database(e.to_string()))?;
        
        if !valid {
            return Err(AuthError::InvalidCredentials);
        }
        
        // 获取用户ID
        let user = self.user_repo.find_by_username(&req.username)
            .map_err(|e| AuthError::Database(e.to_string()))?
            .ok_or(AuthError::UserNotFound)?;
        
        // 创建令牌
        let token = self.token_repo.create_token(&user.id)
            .map_err(|e| AuthError::Database(e.to_string()))?;
        
        // 构建响应
        Ok(LoginResponse {
            token,
            user_id: user.id,
            expires_at: Utc::now() + Duration::hours(24),
        })
    }
    
    fn validate_token(&self, token: &str) -> AuthResult<UserSession> {
        let session = self.token_repo.get_session(token)
            .map_err(|e| AuthError::Database(e.to_string()))?
            .ok_or(AuthError::InvalidToken)?;
        
        // 检查令牌是否过期
        if session.expires_at < Utc::now() {
            return Err(AuthError::TokenExpired);
        }
        
        Ok(session)
    }
    
    fn revoke_token(&self, token: &str) -> AuthResult<()> {
        self.token_repo.revoke(token)
            .map_err(|e| AuthError::Database(e.to_string()))
    }
}
```

#### functions.rs - 暴露函数

```rust
use crate::core::di::inject;
use crate::core::error::AppError;
use crate::infra::http::{HttpResponse, StatusCode};

use super::interfaces::AuthService;
use super::types::{LoginRequest, LoginResponse, AuthError};

/// 用户登录API
#[expose(
    // 函数路径，用于内部调用
    fn_path = "auth.login",
    // HTTP路由
    http = "POST /api/auth/login",
    // 性能提示，有利于编译优化
    inline = true
)]
pub fn login(req: LoginRequest) -> HttpResponse<LoginResponse> {
    // 注入依赖
    let auth_service = inject::<dyn AuthService>();
    
    // 调用服务执行业务逻辑
    match auth_service.authenticate(&req) {
        Ok(response) => HttpResponse::success(response),
        Err(e) => match e {
            AuthError::InvalidCredentials => {
                HttpResponse::error(StatusCode::UNAUTHORIZED, "无效的用户名或密码")
            },
            AuthError::UserNotFound => {
                HttpResponse::error(StatusCode::NOT_FOUND, "用户不存在")
            },
            _ => HttpResponse::error(
                StatusCode::INTERNAL_SERVER_ERROR, 
                &format!("认证失败: {}", e)
            ),
        },
    }
}

/// 验证令牌API
#[expose(
    fn_path = "auth.validate",
    http = "GET /api/auth/validate"
)]
pub fn validate_token(token: String) -> HttpResponse<bool> {
    let auth_service = inject::<dyn AuthService>();
    
    match auth_service.validate_token(&token) {
        Ok(_) => HttpResponse::success(true),
        Err(e) => match e {
            AuthError::InvalidToken => {
                HttpResponse::error(StatusCode::UNAUTHORIZED, "无效的令牌")
            },
            AuthError::TokenExpired => {
                HttpResponse::error(StatusCode::UNAUTHORIZED, "令牌已过期")
            },
            _ => HttpResponse::error(
                StatusCode::INTERNAL_SERVER_ERROR, 
                &format!("令牌验证失败: {}", e)
            ),
        },
    }
}

/// 撤销令牌API
#[expose(
    fn_path = "auth.revoke",
    http = "POST /api/auth/logout"
)]
pub fn revoke_token(token: String) -> HttpResponse<()> {
    let auth_service = inject::<dyn AuthService>();
    
    match auth_service.revoke_token(&token) {
        Ok(_) => HttpResponse::success(()),
        Err(e) => HttpResponse::error(
            StatusCode::INTERNAL_SERVER_ERROR, 
            &format!("令牌撤销失败: {}", e)
        ),
    }
}

/// 内部函数：验证令牌并返回用户ID
/// 仅供内部使用，不暴露HTTP端点
#[expose(fn_path = "auth.get_user_id")]
pub fn get_user_id(token: String) -> Result<String, AppError> {
    let auth_service = inject::<dyn AuthService>();
    
    let session = auth_service.validate_token(&token)
        .map_err(|e| AppError::unauthorized(&format!("无效的令牌: {}", e)))?;
    
    Ok(session.user_id)
}
```

#### mod.rs - 模块入口

```rust
pub mod functions;
pub mod types;
pub mod interfaces;
pub mod service;

// 重导出公共API和类型
pub use functions::*;
pub use types::{LoginRequest, LoginResponse, UserSession, AuthError};
pub use interfaces::AuthService;
```

### 4.2 用户管理切片(user)

#### 目录结构

```
slices/
└── user/
    ├── functions.rs       # 暴露的API函数
    ├── types.rs           # 数据模型和请求/响应类型
    ├── interfaces.rs      # 接口定义
    ├── service.rs         # 业务逻辑实现
    └── mod.rs             # 模块入口
```

#### 核心文件实现示例

```rust
// types.rs
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

#[derive(Debug, Serialize, Deserialize)]
pub struct User {
    pub id: String,
    pub username: String,
    pub email: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdateProfileRequest {
    pub email: Option<String>,
    pub display_name: Option<String>,
}

// interfaces.rs
use crate::core::error::AppResult;
use super::types::User;

pub trait UserService {
    fn get_profile(&self, user_id: &str) -> AppResult<User>;
    fn update_profile(&self, user_id: &str, email: Option<String>, display_name: Option<String>) -> 
AppResult<User>;
}

// functions.rs
use crate::core::di::inject;
use crate::infra::http::{HttpResponse, StatusCode};
use crate::slices::auth::functions::get_user_id;

use super::interfaces::UserService;
use super::types::{User, UpdateProfileRequest};

#[expose(
    fn_path = "user.get_profile",
    http = "GET /api/user/profile"
)]
pub fn get_profile(auth_token: String) -> HttpResponse<User> {
    // 1. 验证令牌获取用户ID
    let user_id = match get_user_id(auth_token) {
        Ok(id) => id,
        Err(e) => return HttpResponse::error(StatusCode::UNAUTHORIZED, &e.to_string()),
    };
    
    // 2. 获取用户资料
    let user_service = inject::<dyn UserService>();
    match user_service.get_profile(&user_id) {
        Ok(user) => HttpResponse::success(user),
        Err(e) => HttpResponse::error(StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    }
}

#[expose(
    fn_path = "user.update_profile",
    http = "PUT /api/user/profile"
)]
pub fn update_profile(auth_token: String, req: UpdateProfileRequest) -> HttpResponse<User> {
    // 类似的实现...
    // 1. 验证令牌获取用户ID
    // 2. 更新用户资料
}
```

## 5. 注册与依赖注入

```rust
// app/di.rs - 依赖注入容器
use std::any::{Any, TypeId};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};

use crate::slices::auth::interfaces::AuthService;
use crate::slices::auth::service::{DbUserRepository, CacheTokenRepository, JwtAuthService};
use crate::slices::user::interfaces::UserService;
use crate::slices::user::service::DbUserService;

use crate::infra::db::Database;
use crate::infra::cache::Cache;

// 依赖注入容器 - 轻量级实现
pub struct Container {
    services: RwLock<HashMap<TypeId, Arc<dyn Any + Send + Sync>>>,
}

impl Container {
    pub fn new() -> Self {
        Self {
            services: RwLock::new(HashMap::new()),
        }
    }
    
    // 注册服务实例
    pub fn register<T: 'static + ?Sized, U: 'static + Send + Sync>(&self, instance: U) 
    where
        U: AsRef<T>
    {
        let type_id = TypeId::of::<T>();
        let mut services = self.services.write().unwrap();
        services.insert(type_id, Arc::new(instance));
    }
    
    // 解析服务实例
    pub fn resolve<T: 'static + ?Sized>(&self) -> Option<Arc<T>> {
        let type_id = TypeId::of::<T>();
        let services = self.services.read().unwrap();
        
        services.get(&type_id).and_then(|service| {
            let any_ref = service.clone();
            
            // 这是一个不安全的向下转换，但由于我们根据TypeId确保了类型安全
            unsafe {
                let ptr = Arc::into_raw(any_ref) as *const T;
                if ptr.is_null() {
                    None
                } else {
                    Some(Arc::from_raw(ptr))
                }
            }
        })
    }
}

// 全局容器单例
lazy_static! {
    static ref CONTAINER: Container = {
        let container = Container::new();
        
        // 初始化基础设施
        let db = Database::new(std::env::var("DATABASE_URL").unwrap_or_else(|_| 
            "sqlite::memory:".to_string()
        ));
        
        let cache = Cache::new(std::env::var("REDIS_URL").ok());
        
        // 注册数据存储层
        let user_repo = DbUserRepository::new(db.clone());
        let token_repo = CacheTokenRepository::new(cache.clone());
        
        // 注册服务层
        let auth_service = JwtAuthService::new(
            Box::new(user_repo.clone()),
            Box::new(token_repo.clone())
        );
        
        let user_service = DbUserService::new(db.clone());
        
        // 注册接口实现
        container.register::<dyn AuthService>(auth_service);
        container.register::<dyn UserService>(user_service);
        
        // 注册基础设施
        container.register::<Database>(db);
        container.register::<Cache>(cache);
        
        container
    };
}

// 依赖注入宏简化服务获取
#[macro_export]
macro_rules! inject {
    ($type:ty) => {
        crate::core::di::get_container()
            .resolve::<$type>()
            .expect(concat!("Failed to resolve: ", stringify!($type)))
    };
}

// 获取全局容器
pub fn get_container() -> &'static Container {
    &CONTAINER
}
```

## 6. HTTP集成与应用启动

```rust
// main.rs
use axum::{
    routing::{get, post, put},
    Router, Extension,
};

mod core;
mod infra;
mod slices;

#[tokio::main]
async fn main() {
    // 初始化日志
    tracing_subscriber::fmt::init();
    
    // 初始化依赖注入容器（通过lazy_static自动完成）
    let container = core::di::get_container();
    
    // 构建路由
    let app = Router::new()
        // 认证路由
        .route("/api/auth/login", post(slices::auth::functions::login))
        .route("/api/auth/validate", get(slices::auth::functions::validate_token))
        .route("/api/auth/logout", post(slices::auth::functions::revoke_token))
        
        // 用户路由
        .route("/api/user/profile", get(slices::user::functions::get_profile))
        .route("/api/user/profile", put(slices::user::functions::update_profile))
        
        // 全局中间件和扩展
        .layer(Extension(container))
        .layer(tower_http::cors::CorsLayer::permissive())
        .layer(tower_http::trace::TraceLayer::new_for_http());
    
    // 启动服务器
    let addr = "[::1]:3000".parse().unwrap();
    tracing::info!("🚀 服务器启动于 http://localhost:3000");
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}
```

这个MVP示例展示了v6架构的核心特性:

1. **函数优先**: 通过`#[expose]`宏暴露函数，而非结构体方法
2. **类型安全注入**: 使用`inject!`宏获取类型安全的依赖
3. **接口驱动**: 通过接口分离定义与实现，保持松耦合
4. **分层设计**: 清晰划分API函数、业务服务和数据访问
5. **错误处理**: 统一的错误类型和传播机制
6. **零依赖冲突**: 通过依赖注入容器管理服务生命周期

该架构既保持了v5的函数化设计理念，又解决了其依赖管理和错误处理的问题，是一个平衡性能与可维护性的最佳实践方案。