//! MVP CRUD slice - 基于FMOD v7架构的基础CRUD操作实现
//! 
//! 提供对Item实体的完整CRUD操作，支持SQLite3数据库
//! 遵循v7架构规范：静态分发 + 泛型 + Clone trait

pub mod types;
pub mod interfaces;
pub mod service;
pub mod functions;

// 重新导出公共API
pub use types::*;
pub use interfaces::{CrudService, ItemRepository};
pub use service::{SqliteCrudService, SqliteItemRepository};
pub use functions::{
    // 静态分发核心函数
    create_item, get_item, update_item, delete_item, list_items,
    // HTTP适配器函数
    http_create_item, http_get_item, http_update_item, http_delete_item, http_list_items,
}; 