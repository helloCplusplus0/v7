use crate::core::{AppError, Result};
use crate::infra::di::inject;
use crate::infra::http::HttpResponse;
use axum::Json;

use super::interfaces::AuthService;
use super::types::{AuthError, LoginRequest, LoginResponse, UserSession};

// 🚀 未来的过程宏使用示例（当前注释掉）
// use crate::core::auto_docs::api_endpoint;

/// ⭐ v7核心特性：静态分发登录函数
///
/// 函数路径: `auth.login`
/// HTTP路由: POST /api/auth/login
/// 性能特性: 编译时单态化，零运行时开销
///
/// # Errors
///
/// 返回错误当：
/// - 用户名或密码无效
/// - 用户不存在
/// - 内部认证服务失败
// #[api_endpoint] // 🚀 未来启用过程宏
pub async fn login<A>(auth_service: A, req: LoginRequest) -> Result<LoginResponse>
where
    A: AuthService,
{
    // 直接调用服务，编译器会完全内联
    auth_service.authenticate(req).await.map_err(|e| {
        Box::new(match e {
            AuthError::InvalidCredentials => AppError::unauthorized("无效的用户名或密码"),
            AuthError::UserNotFound => AppError::not_found("用户不存在"),
            _ => AppError::internal(format!("认证失败: {e}")),
        })
    })
}

/// ⭐ v7核心特性：静态分发令牌验证函数
///
/// 函数路径: `auth.validate_token`
/// HTTP路由: GET /api/auth/validate
///
/// # Errors
///
/// 返回错误当：
/// - 令牌无效
/// - 令牌已过期
/// - 内部验证服务失败
pub async fn validate_token<A>(auth_service: A, token: String) -> Result<UserSession>
where
    A: AuthService,
{
    auth_service.validate_token(&token).await.map_err(|e| {
        Box::new(match e {
            AuthError::InvalidToken => AppError::unauthorized("无效的令牌"),
            AuthError::TokenExpired => AppError::unauthorized("令牌已过期"),
            _ => AppError::internal(format!("令牌验证失败: {e}")),
        })
    })
}

/// ⭐ v7核心特性：撤销令牌函数
///
/// 函数路径: `auth.revoke_token`
/// HTTP路由: POST /api/auth/logout
///
/// # Errors
///
/// 返回错误当：
/// - 令牌撤销失败
/// - 内部服务错误
pub async fn revoke_token<A>(auth_service: A, token: String) -> Result<()>
where
    A: AuthService,
{
    auth_service
        .revoke_token(&token)
        .await
        .map_err(|e| Box::new(AppError::internal(format!("令牌撤销失败: {e}"))))
}

/// ⭐ v7核心特性：跨切片函数调用
///
/// 供其他切片使用的内部函数
/// 函数路径: `auth.get_user_id`
///
/// # Errors
///
/// 返回错误当：
/// - 令牌验证失败
/// - 用户会话无效
pub async fn get_user_id<A>(auth_service: A, token: String) -> Result<String>
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
pub async fn internal_authenticate(username: &str, password: &str) -> Result<LoginResponse> {
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

/// ⭐ v7核心特性：HTTP适配器函数
///
/// 将静态分发的业务函数适配到HTTP层
/// HTTP登录处理函数
///
/// POST /api/auth/login
/// 验证用户凭证并返回JWT令牌
pub async fn api_login(Json(req): Json<LoginRequest>) -> Json<HttpResponse<LoginResponse>> {
    Json(http_login(req).await)
}

pub async fn http_login(req: LoginRequest) -> HttpResponse<LoginResponse> {
    // 从依赖注入容器获取服务
    type AuthServiceType = super::service::JwtAuthService<
        super::service::MemoryUserRepository,
        super::service::MemoryTokenRepository,
    >;
    let auth_service = inject::<AuthServiceType>();

    // 调用静态分发的业务函数
    match login(auth_service, req).await {
        Ok(response) => HttpResponse::success(response),
        Err(error) => HttpResponse {
            status: 400,
            message: "Error".to_string(),
            data: None,
            error: Some(crate::infra::http::ErrorDetail {
                code: "AUTH_ERROR".to_string(),
                message: error.to_string(),
                context: None,
                location: None,
            }),
            trace_id: None,
            timestamp: chrono::Utc::now().timestamp(),
        },
    }
}

/// HTTP令牌验证处理函数
///
/// GET /api/auth/validate
/// 验证JWT令牌的有效性并返回用户会话信息
pub async fn api_validate_token(headers: axum::http::HeaderMap) -> Json<HttpResponse<UserSession>> {
    // 从Authorization头获取令牌
    let token = extract_bearer_token(&headers).unwrap_or_default();
    Json(http_validate_token(token).await)
}

pub async fn http_validate_token(token: String) -> HttpResponse<UserSession> {
    type AuthServiceType = super::service::JwtAuthService<
        super::service::MemoryUserRepository,
        super::service::MemoryTokenRepository,
    >;
    let auth_service = inject::<AuthServiceType>();

    match validate_token(auth_service, token).await {
        Ok(session) => HttpResponse::success(session),
        Err(error) => HttpResponse {
            status: 401,
            message: "Error".to_string(),
            data: None,
            error: Some(crate::infra::http::ErrorDetail {
                code: "AUTH_ERROR".to_string(),
                message: error.to_string(),
                context: None,
                location: None,
            }),
            trace_id: None,
            timestamp: chrono::Utc::now().timestamp(),
        },
    }
}

/// HTTP用户登出处理函数
///
/// POST /api/auth/logout
/// 撤销JWT令牌，使其失效
pub async fn api_revoke_token(headers: axum::http::HeaderMap) -> Json<HttpResponse<()>> {
    // 从Authorization头获取令牌
    let token = extract_bearer_token(&headers).unwrap_or_default();
    Json(http_revoke_token(token).await)
}

pub async fn http_revoke_token(token: String) -> HttpResponse<()> {
    type AuthServiceType = super::service::JwtAuthService<
        super::service::MemoryUserRepository,
        super::service::MemoryTokenRepository,
    >;
    let auth_service = inject::<AuthServiceType>();

    match revoke_token(auth_service, token).await {
        Ok(()) => HttpResponse::success(()),
        Err(error) => HttpResponse {
            status: 400,
            message: "Error".to_string(),
            data: None,
            error: Some(crate::infra::http::ErrorDetail {
                code: "AUTH_ERROR".to_string(),
                message: error.to_string(),
                context: None,
                location: None,
            }),
            trace_id: None,
            timestamp: chrono::Utc::now().timestamp(),
        },
    }
}

/// 从请求头中提取Bearer令牌
fn extract_bearer_token(headers: &axum::http::HeaderMap) -> Option<String> {
    headers
        .get("authorization")
        .and_then(|value| value.to_str().ok())
        .and_then(|auth_header| {
            auth_header
                .strip_prefix("Bearer ")
                .map(std::string::ToString::to_string)
        })
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
