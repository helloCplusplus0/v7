use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// 认证请求（继承v6设计）
#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    /// 用户名
    pub username: String,
    /// 密码
    pub password: String,
}

/// 认证响应（继承v6设计）
#[derive(Debug, Serialize)]
pub struct LoginResponse {
    /// JWT令牌
    pub token: String,
    /// 用户ID
    pub user_id: String,
    /// 过期时间
    pub expires_at: DateTime<Utc>,
}

/// 用户会话模型（继承v6设计）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserSession {
    /// 用户ID
    pub user_id: String,
    /// 用户名
    pub username: String,
    /// 创建时间
    pub created_at: DateTime<Utc>,
    /// 过期时间
    pub expires_at: DateTime<Utc>,
}

/// 认证错误（继承v6设计）
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
