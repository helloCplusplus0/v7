//! HTTP适配器层
//!
//! `基于v6设计理念的HTTP响应包装和中间件支持`

use axum::response::{IntoResponse, Response};
use axum::Json;
use chrono::Utc;
use serde::{Deserialize, Serialize};

// 重新导出StatusCode以便外部使用
pub use axum::http::StatusCode as HttpStatusCode;

use crate::core::error::AppError;
use crate::core::result::Result;

/// 统一HTTP响应格式
#[derive(Debug, Serialize, Deserialize)]
pub struct HttpResponse<T>
where
    T: Serialize,
{
    /// HTTP状态码
    pub status: u16,
    /// 响应消息
    pub message: String,
    /// 响应数据（成功时）
    pub data: Option<T>,
    /// 错误详情（失败时）
    pub error: Option<ErrorDetail>,
    /// 追踪ID
    pub trace_id: Option<String>,
    /// 时间戳
    pub timestamp: i64,
}

/// 错误详情
#[derive(Debug, Serialize, Deserialize)]
pub struct ErrorDetail {
    /// 错误代码
    pub code: String,
    /// 错误消息
    pub message: String,
    /// 错误上下文
    pub context: Option<String>,
    /// 错误位置
    pub location: Option<String>,
}

impl<T> HttpResponse<T>
where
    T: Serialize,
{
    /// 创建成功响应
    #[must_use]
    pub fn success(data: T) -> Self {
        Self {
            status: 200,
            message: "Success".to_string(),
            data: Some(data),
            error: None,
            trace_id: None,
            timestamp: Utc::now().timestamp(),
        }
    }

    /// 创建空成功响应
    #[must_use]
    pub fn ok() -> HttpResponse<()> {
        HttpResponse {
            status: 200,
            message: "OK".to_string(),
            data: Some(()),
            error: None,
            trace_id: None,
            timestamp: Utc::now().timestamp(),
        }
    }

    /// 创建错误响应
    #[must_use]
    pub fn error(status: HttpStatusCode, message: &str) -> Self {
        Self {
            status: status.as_u16(),
            message: "Error".to_string(),
            data: None,
            error: Some(ErrorDetail {
                code: format!("{status:?}"),
                message: message.to_string(),
                context: None,
                location: None,
            }),
            trace_id: None,
            timestamp: Utc::now().timestamp(),
        }
    }

    /// 从应用错误创建HTTP响应
    #[must_use]
    pub fn from_app_error(error: AppError) -> HttpResponse<()> {
        HttpResponse {
            status: error.code.status_code(),
            message: error.message.clone(),
            data: None,
            error: Some(ErrorDetail {
                code: format!("{:?}", error.code),
                message: error.message,
                context: error.context,
                location: error.location.map(std::string::ToString::to_string),
            }),
            trace_id: error.trace_id,
            timestamp: Utc::now().timestamp(),
        }
    }

    /// 添加追踪ID
    #[must_use]
    pub fn with_trace_id(mut self, trace_id: String) -> Self {
        self.trace_id = Some(trace_id);
        self
    }
}

impl<T: Serialize> IntoResponse for HttpResponse<T> {
    fn into_response(self) -> Response {
        let status =
            HttpStatusCode::from_u16(self.status).unwrap_or(HttpStatusCode::INTERNAL_SERVER_ERROR);
        (status, Json(self)).into_response()
    }
}

/// 分页请求参数
#[derive(Debug, Deserialize)]
pub struct PaginationQuery {
    /// 页码（从1开始）
    pub page: Option<u32>,
    /// 每页大小
    pub size: Option<u32>,
    /// 排序字段
    pub sort: Option<String>,
    /// 排序方向（asc/desc）
    pub order: Option<String>,
}

impl PaginationQuery {
    /// 获取页码（从1开始）
    #[must_use]
    pub fn page(&self) -> u32 {
        self.page.unwrap_or(1).max(1)
    }

    /// 获取每页大小（限制在1-100之间）
    #[must_use]
    pub fn size(&self) -> u32 {
        self.size.unwrap_or(20).clamp(1, 100)
    }

    /// 计算偏移量
    #[must_use]
    pub fn offset(&self) -> u32 {
        (self.page() - 1) * self.size()
    }

    /// 获取排序字段
    #[must_use]
    pub fn sort_field(&self) -> Option<&str> {
        self.sort.as_deref()
    }

    /// 是否降序排列
    #[must_use]
    pub fn is_desc(&self) -> bool {
        self.order.as_deref() == Some("desc")
    }
}

/// 分页响应数据
#[derive(Debug, Serialize)]
pub struct PaginatedResponse<T> {
    /// 数据列表
    pub items: Vec<T>,
    /// 分页信息
    pub pagination: PaginationInfo,
}

/// 分页信息
#[derive(Debug, Serialize)]
pub struct PaginationInfo {
    /// 当前页码
    pub page: u32,
    /// 每页大小
    pub size: u32,
    /// 总记录数
    pub total: u64,
    /// 总页数
    pub pages: u32,
    /// 是否有下一页
    pub has_next: bool,
    /// 是否有上一页
    pub has_prev: bool,
}

impl<T> PaginatedResponse<T> {
    /// 创建分页响应
    #[must_use]
    pub fn new(items: Vec<T>, query: &PaginationQuery, total: u64) -> Self {
        let page = query.page();
        let size = query.size();
        let pages = ((total as f64) / f64::from(size)).ceil() as u32;

        Self {
            items,
            pagination: PaginationInfo {
                page,
                size,
                total,
                pages,
                has_next: page < pages,
                has_prev: page > 1,
            },
        }
    }
}

/// HTTP状态码扩展
pub trait StatusCodeExt {
    /// 检查是否为成功状态码
    fn is_success(&self) -> bool;
    /// 检查是否为客户端错误
    fn is_client_error(&self) -> bool;
    /// 检查是否为服务器错误
    fn is_server_error(&self) -> bool;
}

impl StatusCodeExt for HttpStatusCode {
    fn is_success(&self) -> bool {
        self.as_u16() >= 200 && self.as_u16() < 300
    }

    fn is_client_error(&self) -> bool {
        self.as_u16() >= 400 && self.as_u16() < 500
    }

    fn is_server_error(&self) -> bool {
        self.as_u16() >= 500
    }
}

/// `转换为HTTP响应的trait`
pub trait IntoHttpResponse<T>
where
    T: Serialize,
{
    /// 转换为HTTP响应
    fn into_http_response(self) -> HttpResponse<T>;

    /// 转换为带追踪ID的HTTP响应
    fn into_http_response_with_trace(self, trace_id: String) -> HttpResponse<T>;
}

impl<T> IntoHttpResponse<T> for Result<T>
where
    T: Serialize,
{
    fn into_http_response(self) -> HttpResponse<T> {
        match self {
            Ok(data) => HttpResponse::success(data),
            Err(error) => HttpResponse {
                status: 500,
                message: "Error".to_string(),
                data: None,
                error: Some(ErrorDetail {
                    code: "INTERNAL_ERROR".to_string(),
                    message: error.to_string(),
                    context: None,
                    location: None,
                }),
                trace_id: None,
                timestamp: Utc::now().timestamp(),
            },
        }
    }

    fn into_http_response_with_trace(self, trace_id: String) -> HttpResponse<T> {
        match self {
            Ok(data) => HttpResponse::success(data).with_trace_id(trace_id),
            Err(error) => HttpResponse {
                status: 500,
                message: "Error".to_string(),
                data: None,
                error: Some(ErrorDetail {
                    code: "INTERNAL_ERROR".to_string(),
                    message: error.to_string(),
                    context: None,
                    location: None,
                }),
                trace_id: Some(trace_id),
                timestamp: Utc::now().timestamp(),
            },
        }
    }
}

/// HTTP客户端接口
#[async_trait::async_trait]
pub trait HttpClient: Send + Sync {
    /// GET请求
    async fn get(&self, url: &str) -> Result<String>;

    /// POST请求
    async fn post(&self, url: &str, body: &str) -> Result<String>;

    /// PUT请求
    async fn put(&self, url: &str, body: &str) -> Result<String>;

    /// DELETE请求
    async fn delete(&self, url: &str) -> Result<String>;

    /// 设置默认超时时间
    fn with_timeout(self, timeout_seconds: u64) -> Self
    where
        Self: Sized;

    /// 添加默认请求头
    fn with_header(self, key: &str, value: &str) -> Self
    where
        Self: Sized;
}

/// 简单HTTP客户端实现（用于开发和测试）
pub struct SimpleHttpClient {
    timeout: std::time::Duration,
    headers: std::collections::HashMap<String, String>,
}

impl Default for SimpleHttpClient {
    fn default() -> Self {
        Self::new()
    }
}

impl SimpleHttpClient {
    #[must_use]
    pub fn new() -> Self {
        Self {
            timeout: std::time::Duration::from_secs(30),
            headers: std::collections::HashMap::new(),
        }
    }
}

#[async_trait::async_trait]
impl HttpClient for SimpleHttpClient {
    async fn get(&self, url: &str) -> Result<String> {
        // 简化实现，实际应该使用reqwest等HTTP客户端
        tracing::info!("模拟GET请求: {}", url);
        Ok(format!("{{\"url\": \"{url}\", \"method\": \"GET\"}}"))
    }

    async fn post(&self, url: &str, body: &str) -> Result<String> {
        tracing::info!("模拟POST请求: {} (body: {})", url, body);
        Ok(format!(
            "{{\"url\": \"{url}\", \"method\": \"POST\", \"body\": \"{body}\"}}"
        ))
    }

    async fn put(&self, url: &str, body: &str) -> Result<String> {
        tracing::info!("模拟PUT请求: {} (body: {})", url, body);
        Ok(format!(
            "{{\"url\": \"{url}\", \"method\": \"PUT\", \"body\": \"{body}\"}}"
        ))
    }

    async fn delete(&self, url: &str) -> Result<String> {
        tracing::info!("模拟DELETE请求: {}", url);
        Ok(format!("{{\"url\": \"{url}\", \"method\": \"DELETE\"}}"))
    }

    fn with_timeout(mut self, timeout_seconds: u64) -> Self {
        self.timeout = std::time::Duration::from_secs(timeout_seconds);
        self
    }

    fn with_header(mut self, key: &str, value: &str) -> Self {
        self.headers.insert(key.to_string(), value.to_string());
        self
    }
}

/// HTTP工厂
pub struct HttpFactory;

impl HttpFactory {
    /// 创建HTTP客户端
    #[must_use]
    pub fn create_client() -> Box<dyn HttpClient> {
        Box::new(SimpleHttpClient::new())
    }
}

/// HTTP响应便利宏
#[macro_export]
macro_rules! http_ok {
    () => {
        $crate::infra::http::HttpResponse::ok()
    };
    ($data:expr) => {
        $crate::infra::http::HttpResponse::success($data)
    };
}

#[macro_export]
macro_rules! http_error {
    ($status:expr, $message:expr) => {
        $crate::infra::http::HttpResponse::error($status, $message)
    };
}
