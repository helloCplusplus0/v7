//! 认证业务函数
//! 基于静态分发的零开销抽象实现

use crate::infra::di::inject;
use crate::slices::auth::{
    interfaces::AuthService,
    types::{AuthResult, LoginRequest, LoginResponse, UserSession},
};

/// ⭐ v7核心函数：用户登录
///
/// 使用静态分发，编译器会将整个调用链内联，实现零运行时开销
/// 
/// # Arguments
/// * `auth_service` - 认证服务实现（编译时确定类型）
/// * `req` - 登录请求
///
/// # Returns
/// 
/// 成功返回包含JWT令牌的登录响应
///
/// # Errors
///
/// 返回错误当：
/// - 用户名或密码无效
/// - 内部服务错误
pub async fn login<A>(auth_service: A, req: LoginRequest) -> AuthResult<LoginResponse>
where
    A: AuthService,
{
    // 直接调用服务，编译器会完全内联
    auth_service.authenticate(req).await
}

/// ⭐ v7核心函数：令牌验证
///
/// 静态分发确保最优性能，编译器会完全内联整个验证过程
///
/// # Arguments
/// * `auth_service` - 认证服务实现
/// * `token` - JWT令牌
///
/// # Returns
///
/// 成功返回用户会话信息
///
/// # Errors
///
/// 返回错误当：
/// - 令牌无效或已过期
/// - 用户会话不存在
pub async fn validate_token<A>(auth_service: A, token: String) -> AuthResult<UserSession>
where
    A: AuthService,
{
    auth_service.validate_token(&token).await
}

/// ⭐ v7核心函数：撤销令牌
///
/// 基于静态分发的令牌撤销，编译期优化确保最佳性能
///
/// # Arguments
/// * `auth_service` - 认证服务实现
/// * `token` - 要撤销的JWT令牌
///
/// # Errors
///
/// 返回错误当：
/// - 令牌无效
/// - 服务内部错误
pub async fn revoke_token<A>(auth_service: A, token: String) -> AuthResult<()>
where
    A: AuthService,
{
    auth_service.revoke_token(&token).await
}

/// ⭐ v7辅助函数：获取用户ID
///
/// 从令牌中提取用户ID，利用静态分发的性能优势
///
/// # Arguments
/// * `auth_service` - 认证服务实现
/// * `token` - JWT令牌
///
/// # Returns
///
/// 成功返回用户ID字符串
///
/// # Errors
///
/// 返回错误当：
/// - 令牌验证失败
/// - 用户会话无效
pub async fn get_user_id<A>(auth_service: A, token: String) -> AuthResult<String>
where
    A: AuthService,
{
    let session = validate_token(auth_service, token).await?;
    Ok(session.user_id)
}

/// ⭐ v7核心特性：内部调用示例（编译时优化）
///
/// 这个函数展示了v7的零开销抽象特性
/// 编译器会将整个调用链完全内联
///
/// # Errors
///
/// 返回错误当：
/// - 认证失败
/// - 内部服务错误
pub async fn internal_authenticate(username: &str, password: &str) -> AuthResult<LoginResponse> {
    let user_repo = super::service::MemoryUserRepository::new();
    let token_repo = super::service::MemoryTokenRepository::new();
    let auth_service = super::service::JwtAuthService::new(user_repo, token_repo);

    let req = LoginRequest {
        username: username.to_string(),
        password: password.to_string(),
    };

    // 这个调用会被编译器完全内联，零运行时开销
    login(auth_service, req).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::slices::auth::service::{MemoryTokenRepository, MemoryUserRepository};

    /// ⭐ v7测试优势：静态分发易于测试
    #[tokio::test]
    async fn test_login_static_dispatch() {
        // 创建测试服务
        let user_repo = MemoryUserRepository::new();
        let token_repo = MemoryTokenRepository::new();
        let auth_service = crate::slices::auth::service::JwtAuthService::new(user_repo, token_repo);

        let req = LoginRequest {
            username: "testuser".to_string(),
            password: "password123".to_string(),
        };

        // ⭐ 直接调用静态分发函数，无需复杂的mock
        let result = login(auth_service, req).await;

        assert!(result.is_ok());
        let response = result.unwrap();
        assert_eq!(response.user_id, "user123");
        assert!(!response.token.is_empty());
    }

    /// ⭐ v7性能测试：验证零开销抽象
    #[tokio::test]
    async fn test_internal_call_performance() {
        // 这个测试展示了v7的零开销特性
        let start = std::time::Instant::now();

        let result = internal_authenticate("testuser", "password123").await;

        let duration = start.elapsed();

        assert!(result.is_ok());
        // 由于编译器内联优化，调用应该非常快
        assert!(duration.as_millis() < 100); // 放宽时间限制以适应测试环境
    }
}
