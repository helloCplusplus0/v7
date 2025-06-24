//! 统一错误处理系统
//!
//! 基于v6设计理念的轻量级错误处理，支持分布式追踪

use std::fmt;
use thiserror::Error;
use uuid::Uuid;

/// 应用错误码
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorCode {
    // 客户端错误（400系列）
    BadRequest,      // 400
    Unauthorized,    // 401
    Forbidden,       // 403
    NotFound,        // 404
    Validation,      // 422
    TooManyRequests, // 429

    // 服务器错误（500系列）
    Internal,           // 500
    NotImplemented,     // 501
    ServiceUnavailable, // 503
    Database,           // 500 (数据库错误)
    Timeout,            // 504
}

impl ErrorCode {
    /// 获取HTTP状态码
    #[must_use]
    pub fn status_code(&self) -> u16 {
        match self {
            Self::BadRequest => 400,
            Self::Unauthorized => 401,
            Self::Forbidden => 403,
            Self::NotFound => 404,
            Self::Validation => 422,
            Self::TooManyRequests => 429,
            Self::Internal => 500,
            Self::NotImplemented => 501,
            Self::ServiceUnavailable => 503,
            Self::Database => 500,
            Self::Timeout => 504,
        }
    }

    /// 判断是否为客户端错误
    #[must_use]
    pub fn is_client_error(&self) -> bool {
        self.status_code() < 500
    }

    /// 判断是否为服务器错误  
    #[must_use]
    pub fn is_server_error(&self) -> bool {
        self.status_code() >= 500
    }
}

/// 统一应用错误类型
#[derive(Error, Debug)]
pub struct AppError {
    /// 错误代码
    pub code: ErrorCode,
    /// 错误消息
    pub message: String,
    /// 错误上下文（可选）
    pub context: Option<String>,
    /// 分布式追踪ID（改进：支持分布式追踪）
    pub trace_id: Option<String>,
    /// 关联ID（改进：便于日志关联分析）
    pub correlation_id: Option<String>,
    /// 源错误（可选）
    #[source]
    pub source: Option<Box<dyn std::error::Error + Send + Sync>>,
    /// 错误发生位置
    pub location: Option<&'static str>,
}

impl AppError {
    /// 创建新错误
    pub fn new(code: ErrorCode, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
            context: None,
            trace_id: None,
            correlation_id: None,
            source: None,
            location: None,
        }
    }

    /// 添加上下文
    pub fn with_context(mut self, context: impl Into<String>) -> Self {
        self.context = Some(context.into());
        self
    }

    /// 添加追踪ID（改进：支持分布式追踪）
    pub fn with_trace_id(mut self, trace_id: impl Into<String>) -> Self {
        self.trace_id = Some(trace_id.into());
        self
    }

    /// 添加关联ID（改进：便于日志关联）
    pub fn with_correlation_id(mut self, correlation_id: impl Into<String>) -> Self {
        self.correlation_id = Some(correlation_id.into());
        self
    }

    /// 添加源错误
    pub fn with_source<E: std::error::Error + Send + Sync + 'static>(mut self, source: E) -> Self {
        self.source = Some(Box::new(source));
        self
    }

    /// 添加位置信息
    #[must_use]
    pub fn with_location(mut self, location: &'static str) -> Self {
        self.location = Some(location);
        self
    }

    /// 生成新的追踪ID
    #[must_use]
    pub fn generate_trace_id() -> String {
        Uuid::new_v4().to_string()
    }

    // 便利构造函数
    pub fn bad_request(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::BadRequest, message)
    }

    pub fn unauthorized(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::Unauthorized, message)
    }

    pub fn forbidden(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::Forbidden, message)
    }

    pub fn not_found(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::NotFound, message)
    }

    pub fn validation(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::Validation, message)
    }

    pub fn internal(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::Internal, message)
    }

    pub fn database(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::Database, message)
    }

    pub fn timeout(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::Timeout, message)
    }
}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[{}] {}", self.code.status_code(), self.message)?;

        if let Some(context) = &self.context {
            write!(f, " (Context: {context})")?;
        }

        if let Some(trace_id) = &self.trace_id {
            write!(f, " (TraceID: {trace_id})")?;
        }

        if let Some(correlation_id) = &self.correlation_id {
            write!(f, " (CorrelationID: {correlation_id})")?;
        }

        if let Some(location) = self.location {
            write!(f, " (Location: {location})")?;
        }

        Ok(())
    }
}

/// 错误定位函数（替代宏）
#[must_use]
pub fn with_location(mut error: AppError, location: &'static str) -> AppError {
    error.location = Some(location);
    error
}

/// 带追踪的错误函数（替代宏）
#[must_use]
pub fn with_trace(mut error: AppError, trace_id: String, location: &'static str) -> AppError {
    error.trace_id = Some(trace_id);
    error.location = Some(location);
    error
}

/// 完整错误函数（替代宏）
#[must_use]
pub fn with_full_trace(
    mut error: AppError,
    trace_id: String,
    correlation_id: String,
    location: &'static str,
) -> AppError {
    error.trace_id = Some(trace_id);
    error.correlation_id = Some(correlation_id);
    error.location = Some(location);
    error
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_creation() {
        let error = AppError::bad_request("测试错误");
        assert_eq!(error.code, ErrorCode::BadRequest);
        assert_eq!(error.message, "测试错误");
        assert_eq!(error.code.status_code(), 400);
    }

    #[test]
    fn test_error_with_context() {
        let error = AppError::internal("内部错误").with_context("用户ID: 123");

        assert_eq!(error.code, ErrorCode::Internal);
        assert_eq!(error.context, Some("用户ID: 123".to_string()));
    }

    #[test]
    fn test_error_display() {
        let error = AppError::not_found("用户不存在").with_context("查询用户信息");

        let display_str = format!("{error}");
        assert!(display_str.contains("404"));
        assert!(display_str.contains("用户不存在"));
        assert!(display_str.contains("查询用户信息"));
    }
}
