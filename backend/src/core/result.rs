//! 结果类型别名
//!
//! 提供统一的Result类型，简化错误处理

use super::error::AppError;

/// 应用统一结果类型 - 使用Box减少错误类型大小
pub type Result<T> = std::result::Result<T, Box<AppError>>;

/// 异步结果类型别名
pub type AsyncResult<T> = Result<T>;

/// 可选结果类型，用于可能不存在的数据
pub type OptionResult<T> = Result<Option<T>>;

/// 结果辅助宏
#[macro_export]
macro_rules! ok {
    ($value:expr) => {
        Ok($value)
    };
}

/// 错误结果宏 - 自动Boxing
#[macro_export]
macro_rules! err {
    ($code:expr, $msg:expr) => {
        Err(Box::new($crate::core::error::AppError::new($code, $msg)))
    };
}

/// 结果链式处理扩展
pub trait ResultExt<T> {
    /// 添加上下文信息
    fn with_context(self, context: &str) -> Result<T>;

    /// 添加追踪信息
    fn with_trace(self, trace_id: &str) -> Result<T>;

    /// 转换错误类型
    fn map_err_to(self, error_code: crate::core::error::ErrorCode, message: &str) -> Result<T>;
}

impl<T> ResultExt<T> for Result<T> {
    fn with_context(self, context: &str) -> Result<T> {
        self.map_err(|e| Box::new(e.with_context(context)))
    }

    fn with_trace(self, trace_id: &str) -> Result<T> {
        self.map_err(|e| Box::new(e.with_trace_id(trace_id)))
    }

    fn map_err_to(self, error_code: crate::core::error::ErrorCode, message: &str) -> Result<T> {
        self.map_err(|_| Box::new(AppError::new(error_code, message)))
    }
}
