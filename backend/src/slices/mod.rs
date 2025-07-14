//! 功能切片模块
//!
//! 本模块包含所有的功能切片，每个切片都实现完整的洋葱架构：
//! - Domain层：纯业务逻辑
//! - Service层：业务用例
//! - Adapter层：外部接口适配

pub mod auth;
pub mod mvp_crud;
pub mod mvp_stat;
pub mod registry;
// 切片模块将在实现时添加
// pub mod user;

// 重新导出切片注册表
pub use registry::*;
