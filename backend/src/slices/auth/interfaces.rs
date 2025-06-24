use super::types::{AuthResult, LoginRequest, LoginResponse, UserSession};
use crate::core::Result;
use async_trait::async_trait;

/// 认证服务接口（继承v6设计，添加Clone支持）
#[async_trait]
pub trait AuthService: Send + Sync + Clone {
    /// 验证用户凭证并生成令牌
    async fn authenticate(&self, req: LoginRequest) -> AuthResult<LoginResponse>;

    /// 验证令牌有效性并返回用户会话
    async fn validate_token(&self, token: &str) -> AuthResult<UserSession>;

    /// 撤销指定令牌
    async fn revoke_token(&self, token: &str) -> AuthResult<()>;
}

/// 用户存储接口（继承v6设计，添加Clone支持）
#[async_trait]
pub trait UserRepository: Send + Sync + Clone {
    /// 通过用户名查找用户
    async fn find_by_username(&self, username: &str) -> Result<Option<User>>;

    /// 验证用户凭证
    async fn verify_credentials(&self, username: &str, password: &str) -> Result<bool>;
}

/// 令牌存储接口（继承v6设计，添加Clone支持）
#[async_trait]
pub trait TokenRepository: Send + Sync + Clone {
    /// 创建新令牌
    async fn create_token(&self, user_id: &str) -> Result<String>;

    /// 获取令牌关联的会话
    async fn get_session(&self, token: &str) -> Result<Option<UserSession>>;

    /// 撤销令牌
    async fn revoke(&self, token: &str) -> Result<()>;
}

/// 用户模型
#[derive(Debug, Clone)]
pub struct User {
    pub id: String,
    pub username: String,
    pub password_hash: String,
}
