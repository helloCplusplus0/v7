use async_trait::async_trait;
use chrono::{Duration, Utc};
use std::sync::Arc;
use uuid::Uuid;

use super::interfaces::{AuthService, TokenRepository, User, UserRepository};
use super::types::{AuthError, AuthResult, LoginRequest, LoginResponse, UserSession};
use crate::core::Result;

/// JWT认证服务实现（v7设计：使用泛型而非trait object）
#[derive(Clone)]
pub struct JwtAuthService<U, T>
where
    U: UserRepository,
    T: TokenRepository,
{
    user_repo: U,
    token_repo: T,
}

impl<U, T> JwtAuthService<U, T>
where
    U: UserRepository,
    T: TokenRepository,
{
    pub fn new(user_repo: U, token_repo: T) -> Self {
        Self {
            user_repo,
            token_repo,
        }
    }
}

#[async_trait]
impl<U, T> AuthService for JwtAuthService<U, T>
where
    U: UserRepository,
    T: TokenRepository,
{
    async fn authenticate(&self, req: LoginRequest) -> AuthResult<LoginResponse> {
        // 验证凭证
        let valid = self
            .user_repo
            .verify_credentials(&req.username, &req.password)
            .await
            .map_err(|e| AuthError::Database(e.to_string()))?;

        if !valid {
            return Err(AuthError::InvalidCredentials);
        }

        // 获取用户信息
        let user = self
            .user_repo
            .find_by_username(&req.username)
            .await
            .map_err(|e| AuthError::Database(e.to_string()))?
            .ok_or(AuthError::UserNotFound)?;

        // 创建令牌
        let token = self
            .token_repo
            .create_token(&user.id)
            .await
            .map_err(|e| AuthError::Database(e.to_string()))?;

        // 构建响应
        Ok(LoginResponse {
            token,
            user_id: user.id,
            expires_at: Utc::now() + Duration::hours(24),
        })
    }

    async fn validate_token(&self, token: &str) -> AuthResult<UserSession> {
        let session = self
            .token_repo
            .get_session(token)
            .await
            .map_err(|e| AuthError::Database(e.to_string()))?
            .ok_or(AuthError::InvalidToken)?;

        // 检查令牌是否过期
        if session.expires_at < Utc::now() {
            return Err(AuthError::TokenExpired);
        }

        Ok(session)
    }

    async fn revoke_token(&self, token: &str) -> AuthResult<()> {
        self.token_repo
            .revoke(token)
            .await
            .map_err(|e| AuthError::Database(e.to_string()))
    }
}

/// 内存用户仓库实现（继承v6设计，添加Clone）
#[derive(Clone)]
pub struct MemoryUserRepository {
    users: Arc<Vec<User>>,
}

impl Default for MemoryUserRepository {
    fn default() -> Self {
        Self::new()
    }
}

impl MemoryUserRepository {
    #[must_use]
    pub fn new() -> Self {
        let users = vec![User {
            id: "user123".to_string(),
            username: "testuser".to_string(),
            password_hash: "hashed_password".to_string(),
        }];

        Self {
            users: Arc::new(users),
        }
    }
}

#[async_trait]
impl UserRepository for MemoryUserRepository {
    async fn find_by_username(&self, username: &str) -> Result<Option<User>> {
        let user = self.users.iter().find(|u| u.username == username).cloned();
        Ok(user)
    }

    async fn verify_credentials(&self, username: &str, password: &str) -> Result<bool> {
        if let Some(_user) = self.find_by_username(username).await? {
            // 简化实现：实际应使用bcrypt等
            Ok(password == "password123")
        } else {
            Ok(false)
        }
    }
}

/// 内存令牌仓库实现（继承v6设计，添加Clone）
#[derive(Clone)]
pub struct MemoryTokenRepository {
    tokens: Arc<std::sync::Mutex<std::collections::HashMap<String, UserSession>>>,
}

impl Default for MemoryTokenRepository {
    fn default() -> Self {
        Self::new()
    }
}

impl MemoryTokenRepository {
    #[must_use]
    pub fn new() -> Self {
        Self {
            tokens: Arc::new(std::sync::Mutex::new(std::collections::HashMap::new())),
        }
    }
}

#[async_trait]
impl TokenRepository for MemoryTokenRepository {
    async fn create_token(&self, user_id: &str) -> Result<String> {
        let token = Uuid::new_v4().to_string();
        let now = Utc::now();
        let expires = now + Duration::hours(24);

        let session = UserSession {
            user_id: user_id.to_string(),
            username: "testuser".to_string(), // 简化示例
            created_at: now,
            expires_at: expires,
        };

        let mut tokens = self.tokens.lock().unwrap();
        tokens.insert(token.clone(), session);

        Ok(token)
    }

    async fn get_session(&self, token: &str) -> Result<Option<UserSession>> {
        let tokens = self.tokens.lock().unwrap();
        Ok(tokens.get(token).cloned())
    }

    async fn revoke(&self, token: &str) -> Result<()> {
        let mut tokens = self.tokens.lock().unwrap();
        tokens.remove(token);
        Ok(())
    }
}
