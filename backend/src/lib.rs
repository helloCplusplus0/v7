//! Hello FMOD Backend 库
//! 
//! 基于v6架构的现代化Rust后端库：函数注册 + 切片动态演进

pub mod core;
pub mod infra;
pub mod slices;

// 重新导出核心功能
pub use core::error;
pub use core::result;
pub use infra::*;
pub use slices::registry;
