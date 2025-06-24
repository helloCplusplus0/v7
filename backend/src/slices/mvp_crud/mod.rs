//! MVP CRUD slice - 基于FMOD v7架构的基础CRUD操作实现
//!
//! 提供对Item实体的完整CRUD操作，支持SQLite3数据库
//! 遵循v7架构规范：静态分发 + 泛型 + Clone trait

pub mod functions;
pub mod interfaces;
pub mod service;
pub mod types;

// 重新导出公共API
pub use functions::{
    // 静态分发核心函数
    create_item,
    delete_item,
    get_item,
    // HTTP适配器函数
    http_create_item,
    http_delete_item,
    http_get_item,
    http_list_items,
    http_update_item,
    list_items,
    update_item,
};
pub use interfaces::{CrudService, ItemRepository};
pub use service::{SqliteCrudService, SqliteItemRepository};
pub use types::*;
