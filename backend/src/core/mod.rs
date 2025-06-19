//! 核心抽象层
//! 
//! 提供系统核心抽象：错误处理、结果类型、函数注册等

pub mod error;
pub mod result;
pub mod registry;
pub mod performance_analysis;
pub mod runtime_api_collector;

// 重导出常用类型
pub use error::{AppError, ErrorCode};
pub use result::Result;
pub use registry::{FunctionRegistry, FunctionMetadata, global_registry};
pub use runtime_api_collector::{RuntimeApiCollector, runtime_collector}; 