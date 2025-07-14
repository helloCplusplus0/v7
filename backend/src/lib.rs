//! Hello FMOD Backend 库
//!
//! 基于v6架构的现代化Rust后端库：函数注册 + 切片动态演进

pub mod core;
pub mod infra;
pub mod slices;
pub mod grpc_layer;

// 导入gRPC生成的代码
pub mod analytics;

// Backend gRPC服务定义
#[path = "v7.backend.rs"]
pub mod v7_backend;

// gRPC生成的代码（暂时注释掉）
// pub mod v7 {
//     pub mod backend {
//         tonic::include_proto!("v7.backend");
//     }
// }

// pub mod analytics {
//     tonic::include_proto!("analytics");
// }

// 重新导出核心功能
pub use core::error;
pub use core::result;
pub use infra::*;
pub use slices::registry;
