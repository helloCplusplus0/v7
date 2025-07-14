//! 核心抽象层
//!
//! 提供系统核心抽象：错误处理、结果类型、函数注册等

pub mod error;
pub mod performance_analysis;
pub mod registry;
pub mod result;

// 重导出常用类型
pub use error::{AppError, ErrorCode};
pub use registry::{global_registry, FunctionMetadata, FunctionRegistry};
pub use result::Result;
