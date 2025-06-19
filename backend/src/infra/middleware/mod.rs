//! 中间件模块
//! 
//! 提供HTTP中间件功能，包括CORS、日志记录、认证等

use axum::{
    extract::Request,
    http::{HeaderValue, Method, StatusCode, HeaderName},
    middleware::Next,
    response::Response,
};
use tower_http::cors::{Any, CorsLayer};
use std::time::Instant;

/// 创建CORS中间件
pub fn cors_middleware() -> CorsLayer {
    CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE, Method::OPTIONS])
        .allow_headers(Any)
        .expose_headers([
            HeaderName::from_static("x-request-id"),
            HeaderName::from_static("x-response-time"),
        ])
}

/// 请求日志中间件
pub async fn logging_middleware(
    request: Request,
    next: Next,
) -> Response {
    let start = Instant::now();
    let method = request.method().clone();
    let uri = request.uri().clone();
    let request_id = uuid::Uuid::new_v4().to_string();
    
    tracing::info!(
        request_id = %request_id,
        method = %method,
        uri = %uri,
        "请求开始"
    );
    
    let mut response = next.run(request).await;
    
    let duration = start.elapsed();
    let status = response.status();
    
    // 添加响应头
    response.headers_mut().insert(
        "x-request-id",
        HeaderValue::from_str(&request_id).unwrap_or_else(|_| HeaderValue::from_static("unknown"))
    );
    response.headers_mut().insert(
        "x-response-time",
        HeaderValue::from_str(&format!("{}ms", duration.as_millis())).unwrap_or_else(|_| HeaderValue::from_static("0ms"))
    );
    
    tracing::info!(
        request_id = %request_id,
        method = %method,
        uri = %uri,
        status = %status,
        duration_ms = %duration.as_millis(),
        "请求完成"
    );
    
    response
}

/// 认证中间件
/// 
/// # Errors
/// 
/// 当请求未包含有效的Authorization头或令牌为空时返回`StatusCode::UNAUTHORIZED`
pub async fn auth_middleware(
    request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    // 检查是否为公开路径
    let path = request.uri().path();
    if is_public_path(path) {
        return Ok(next.run(request).await);
    }
    
    // 检查Authorization头
    let auth_header = request
        .headers()
        .get("authorization")
        .and_then(|value| value.to_str().ok());
    
    match auth_header {
        Some(header) if header.starts_with("Bearer ") => {
            let token = &header[7..];
            
            // 这里应该验证令牌，简化示例直接通过
            if token.is_empty() {
                Err(StatusCode::UNAUTHORIZED)
            } else {
                Ok(next.run(request).await)
            }
        }
        _ => Err(StatusCode::UNAUTHORIZED),
    }
}

/// 检查是否为公开路径
fn is_public_path(path: &str) -> bool {
    matches!(path, 
        "/" | 
        "/health" | 
        "/api/info" | 
        "/api/auth/login"
    )
}

/// 速率限制中间件（简化版）
/// 
/// # Errors
/// 
/// 当请求超过速率限制时返回`StatusCode::TOO_MANY_REQUESTS`（当前实现总是允许请求通过）
pub async fn rate_limit_middleware(
    request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    // 简化实现：实际应该使用Redis或内存存储来跟踪请求频率
    let client_ip = request
        .headers()
        .get("x-forwarded-for")
        .or_else(|| request.headers().get("x-real-ip"))
        .and_then(|value| value.to_str().ok())
        .unwrap_or("unknown");
    
    tracing::debug!("速率限制检查: {}", client_ip);
    
    // 这里应该实现真正的速率限制逻辑
    // 现在直接通过
    Ok(next.run(request).await)
}

/// 安全头中间件
pub async fn security_headers_middleware(
    request: Request,
    next: Next,
) -> Response {
    let mut response = next.run(request).await;
    
    let headers = response.headers_mut();
    
    // 添加安全头
    headers.insert("X-Content-Type-Options", HeaderValue::from_static("nosniff"));
    headers.insert("X-Frame-Options", HeaderValue::from_static("DENY"));
    headers.insert("X-XSS-Protection", HeaderValue::from_static("1; mode=block"));
    headers.insert("Referrer-Policy", HeaderValue::from_static("strict-origin-when-cross-origin"));
    headers.insert(
        "Content-Security-Policy",
        HeaderValue::from_static("default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'")
    );
    
    response
} 