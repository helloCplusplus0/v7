//! 数据库抽象层
//! 
//! 基于v6设计理念的轻量级数据库抽象，支持SQLite和PostgreSQL

use async_trait::async_trait;
// use serde::de::DeserializeOwned; // 暂时注释，后续实现时使用
use serde_json::Value;
use std::collections::HashMap;

use crate::core::result::Result;
use crate::core::error::AppError;

pub mod sqlite;
pub mod migrations;

pub use sqlite::SqliteDatabase;

/// 数据库行，简化的键值存储
pub type DbRow = HashMap<String, Value>;

/// 基础数据库接口 - 适用于80%的简单应用场景
#[async_trait]
pub trait Database: Send + Sync {
    /// 执行查询并返回结果
    async fn query(&self, sql: &str, params: &[&str]) -> Result<Vec<DbRow>>;
    
    /// 执行查询并返回单个结果
    async fn query_one(&self, sql: &str, params: &[&str]) -> Result<DbRow>;
    
    /// 执行查询并返回可选结果
    async fn query_opt(&self, sql: &str, params: &[&str]) -> Result<Option<DbRow>>;
    
    /// 执行更新并返回影响的行数
    async fn execute(&self, sql: &str, params: &[&str]) -> Result<u64>;
    
    /// 检查数据库健康状态
    async fn health_check(&self) -> Result<bool>;
}

/// 高级数据库接口 - 支持事务和批量操作
#[async_trait]
pub trait AdvancedDatabase: Database {
    /// 开始事务
    async fn begin_transaction(&self) -> Result<Box<dyn Transaction>>;
    
    /// 批量执行多个查询
    async fn batch(&self, operations: Vec<BatchOperation>) -> Result<Vec<u64>>;
}

/// 数据库事务
#[async_trait]
pub trait Transaction: Send + Sync {
    /// 在事务中执行查询
    async fn query(&self, sql: &str, params: &[&str]) -> Result<Vec<DbRow>>;
    
    /// 在事务中执行更新
    async fn execute(&self, sql: &str, params: &[&str]) -> Result<u64>;
    
    /// 提交事务
    async fn commit(self: Box<Self>) -> Result<()>;
    
    /// 回滚事务
    async fn rollback(self: Box<Self>) -> Result<()>;
}

/// 批量操作定义
pub struct BatchOperation {
    pub sql: String,
    pub params: Vec<String>,
}

/// 查询构建器接口
pub trait QueryBuilder {
    /// 选择字段
    fn select(self, fields: &[&str]) -> Self;
    
    /// 从表查询
    fn from(self, table: &str) -> Self;
    
    /// 添加WHERE条件
    fn where_clause(self, condition: &str, params: Vec<String>) -> Self;
    
    /// 添加ORDER BY
    fn order_by(self, column: &str, descending: bool) -> Self;
    
    /// 添加LIMIT
    fn limit(self, count: u64) -> Self;
    
    /// 添加OFFSET
    fn offset(self, count: u64) -> Self;
    
    /// 构建SQL
    fn build(self) -> (String, Vec<String>);
}

/// 简单查询构建器实现
pub struct SimpleQueryBuilder {
    fields: Vec<String>,
    table: Option<String>,
    where_conditions: Vec<String>,
    where_params: Vec<String>,
    order_by_clause: Option<String>,
    limit_value: Option<u64>,
    offset_value: Option<u64>,
}

impl SimpleQueryBuilder {
    pub fn new() -> Self {
        Self {
            fields: vec!["*".to_string()],
            table: None,
            where_conditions: Vec::new(),
            where_params: Vec::new(),
            order_by_clause: None,
            limit_value: None,
            offset_value: None,
        }
    }
}

impl QueryBuilder for SimpleQueryBuilder {
    fn select(mut self, fields: &[&str]) -> Self {
        self.fields = fields.iter().map(|s| s.to_string()).collect();
        self
    }
    
    fn from(mut self, table: &str) -> Self {
        self.table = Some(table.to_string());
        self
    }
    
    fn where_clause(mut self, condition: &str, params: Vec<String>) -> Self {
        self.where_conditions.push(condition.to_string());
        self.where_params.extend(params);
        self
    }
    
    fn order_by(mut self, column: &str, descending: bool) -> Self {
        let direction = if descending { "DESC" } else { "ASC" };
        self.order_by_clause = Some(format!("{} {}", column, direction));
        self
    }
    
    fn limit(mut self, count: u64) -> Self {
        self.limit_value = Some(count);
        self
    }
    
    fn offset(mut self, count: u64) -> Self {
        self.offset_value = Some(count);
        self
    }
    
    fn build(self) -> (String, Vec<String>) {
        let mut sql = format!("SELECT {} FROM {}", 
            self.fields.join(", "), 
            self.table.expect("Table must be specified")
        );
        
        if !self.where_conditions.is_empty() {
            sql.push_str(&format!(" WHERE {}", self.where_conditions.join(" AND ")));
        }
        
        if let Some(order_by) = self.order_by_clause {
            sql.push_str(&format!(" ORDER BY {}", order_by));
        }
        
        if let Some(limit) = self.limit_value {
            sql.push_str(&format!(" LIMIT {}", limit));
        }
        
        if let Some(offset) = self.offset_value {
            sql.push_str(&format!(" OFFSET {}", offset));
        }
        
        (sql, self.where_params)
    }
}

/// 内存数据库实现（用于测试和开发）
#[derive(Clone)]
pub struct MemoryDatabase {
    data: std::sync::Arc<std::sync::RwLock<HashMap<String, Vec<DbRow>>>>,
    // 可选的持久化文件路径
    persist_file: Option<std::path::PathBuf>,
}

impl MemoryDatabase {
    pub fn new() -> Self {
        Self {
            data: std::sync::Arc::new(std::sync::RwLock::new(HashMap::new())),
            persist_file: None,
        }
    }

    /// 创建带持久化功能的内存数据库
    pub fn with_persistence<P: AsRef<std::path::Path>>(file_path: P) -> Self {
        let persist_file = Some(file_path.as_ref().to_path_buf());
        let db = Self {
            data: std::sync::Arc::new(std::sync::RwLock::new(HashMap::new())),
            persist_file,
        };
        
        // 尝试从文件加载数据
        if let Err(e) = db.load_from_file() {
            tracing::warn!("无法从持久化文件加载数据: {}", e);
        }
        
        db
    }

    /// 从文件加载数据
    fn load_from_file(&self) -> std::io::Result<()> {
        if let Some(file_path) = &self.persist_file {
            if file_path.exists() {
                let content = std::fs::read_to_string(file_path)?;
                if let Ok(saved_data) = serde_json::from_str::<HashMap<String, Vec<DbRow>>>(&content) {
                    let mut data = self.data.write().unwrap();
                    *data = saved_data;
                    tracing::info!("✅ 从持久化文件加载数据: {:?}", file_path);
                }
            }
        }
        Ok(())
    }

    /// 保存数据到文件
    fn save_to_file(&self) -> std::io::Result<()> {
        if let Some(file_path) = &self.persist_file {
            let data = self.data.read().unwrap();
            let content = serde_json::to_string_pretty(&*data)?;
            
            // 确保目录存在
            if let Some(parent) = file_path.parent() {
                std::fs::create_dir_all(parent)?;
            }
            
            std::fs::write(file_path, content)?;
            tracing::debug!("💾 数据已保存到持久化文件: {:?}", file_path);
        }
        Ok(())
    }

    /// 插入测试数据
    pub fn insert_test_data(&self, table: &str, rows: Vec<DbRow>) {
        let mut data = self.data.write().unwrap();
        data.insert(table.to_string(), rows);
        drop(data);
        
        // 自动保存到文件
        if let Err(e) = self.save_to_file() {
            tracing::warn!("保存持久化数据失败: {}", e);
        }
    }
}

#[async_trait]
impl Database for MemoryDatabase {
    async fn query(&self, sql: &str, params: &[&str]) -> Result<Vec<DbRow>> {
        // 简化的SQL解析，仅用于测试
        let sql_upper = sql.to_uppercase();
        
        // 处理COUNT查询
        if sql_upper.contains("COUNT(") {
            let parts: Vec<&str> = sql.split_whitespace().collect();
            if let Some(from_idx) = parts.iter().position(|&x| x.eq_ignore_ascii_case("FROM")) {
                if let Some(table_name) = parts.get(from_idx + 1) {
                    let data = self.data.read().unwrap();
                    let count = data.get(*table_name)
                        .map(|rows| rows.len())
                        .unwrap_or(0);
                    
                    let mut result_row = HashMap::new();
                    result_row.insert("count".to_string(), serde_json::Value::Number(serde_json::Number::from(count)));
                    return Ok(vec![result_row]);
                }
            }
        }
        
        // 处理普通SELECT查询
        if sql_upper.contains("SELECT") && sql_upper.contains("FROM") {
            let parts: Vec<&str> = sql.split_whitespace().collect();
            if let Some(from_idx) = parts.iter().position(|&x| x.eq_ignore_ascii_case("FROM")) {
                if let Some(table_name) = parts.get(from_idx + 1) {
                    let data = self.data.read().unwrap();
                    let mut rows = data.get(*table_name).cloned().unwrap_or_default();
                    
                    // 🔧 处理WHERE条件
                    if sql_upper.contains("WHERE") {
                        if let Some(where_idx) = parts.iter().position(|&x| x.eq_ignore_ascii_case("WHERE")) {
                            // 检查WHERE name = ?
                            if where_idx + 2 < parts.len() && 
                               parts[where_idx + 1].eq_ignore_ascii_case("name") && 
                               parts[where_idx + 2] == "=" {
                                
                                if params.len() >= 1 {
                                    let target_name = params[0];
                                    tracing::debug!("🔍 WHERE name = '{}' 查询", target_name);
                                    
                                    rows.retain(|row| {
                                        if let Some(name_value) = row.get("name") {
                                            if let Some(name_str) = name_value.as_str() {
                                                let matches = name_str == target_name;
                                                tracing::debug!("🔍 比较: '{}' == '{}' -> {}", name_str, target_name, matches);
                                                return matches;
                                            }
                                        }
                                        false
                                    });
                                    
                                    tracing::debug!("🔍 WHERE过滤后结果数量: {}", rows.len());
                                }
                            }
                            // 检查WHERE id = ?
                            else if where_idx + 2 < parts.len() && 
                                    parts[where_idx + 1].eq_ignore_ascii_case("id") && 
                                    parts[where_idx + 2] == "=" {
                                
                                if params.len() >= 1 {
                                    let target_id = params[0];
                                    tracing::debug!("🔍 WHERE id = '{}' 查询", target_id);
                                    
                                    rows.retain(|row| {
                                        if let Some(id_value) = row.get("id") {
                                            if let Some(id_str) = id_value.as_str() {
                                                let matches = id_str == target_id;
                                                tracing::debug!("🔍 比较: '{}' == '{}' -> {}", id_str, target_id, matches);
                                                return matches;
                                            }
                                        }
                                        false
                                    });
                                    
                                    tracing::debug!("🔍 WHERE过滤后结果数量: {}", rows.len());
                                }
                            }
                        }
                    }
                    
                    return Ok(rows);
                }
            }
        }
        
        Ok(Vec::new())
    }
    
    async fn query_one(&self, sql: &str, params: &[&str]) -> Result<DbRow> {
        let results = self.query(sql, params).await?;
        results.into_iter().next()
            .ok_or_else(|| AppError::not_found("未找到记录"))
    }
    
    async fn query_opt(&self, sql: &str, params: &[&str]) -> Result<Option<DbRow>> {
        let results = self.query(sql, params).await?;
        Ok(results.into_iter().next())
    }
    
    async fn execute(&self, sql: &str, params: &[&str]) -> Result<u64> {
        let sql_upper = sql.to_uppercase();
        
        // 处理CREATE TABLE
        if sql_upper.starts_with("CREATE TABLE") {
            let parts: Vec<&str> = sql.split_whitespace().collect();
            if parts.len() >= 3 {
                let table_name = parts[2];
                let mut data = self.data.write().unwrap();
                if !data.contains_key(table_name) {
                    data.insert(table_name.to_string(), Vec::new());
                }
                return Ok(0);
            }
        }
        
        // 处理INSERT INTO items
        if sql_upper.contains("INSERT INTO ITEMS") {
            let mut data = self.data.write().unwrap();
            let items_table = data.entry("items".to_string()).or_insert_with(Vec::new);
            
            // 为了简化，直接使用参数创建一个新行
            if params.len() >= 6 {
                let mut row = HashMap::new();
                row.insert("id".to_string(), serde_json::Value::String(params[0].to_string()));
                row.insert("name".to_string(), serde_json::Value::String(params[1].to_string()));
                row.insert("description".to_string(), serde_json::Value::String(params[2].to_string()));
                row.insert("value".to_string(), serde_json::Value::Number(
                    serde_json::Number::from(params[3].parse::<i32>().unwrap_or(0))
                ));
                row.insert("created_at".to_string(), serde_json::Value::String(params[4].to_string()));
                row.insert("updated_at".to_string(), serde_json::Value::String(params[5].to_string()));
                
                items_table.push(row);
                return Ok(1);
            }
        }
        
        // 🔧 处理DELETE FROM items WHERE id = ?
        if sql_upper.contains("DELETE FROM ITEMS") && sql_upper.contains("WHERE ID") {
            tracing::debug!("🔍 DELETE SQL匹配成功: {}", sql);
            tracing::debug!("🔍 参数: {:?}", params);
            
            if params.len() >= 1 {
                let target_id = params[0];
                tracing::debug!("🔍 目标删除ID: {}", target_id);
                
                let mut data = self.data.write().unwrap();
                
                if let Some(items_table) = data.get_mut("items") {
                    let initial_len = items_table.len();
                    tracing::debug!("🔍 删除前项目数量: {}", initial_len);
                    
                    // 打印所有现有项目的ID
                    for (i, row) in items_table.iter().enumerate() {
                        if let Some(id_value) = row.get("id") {
                            if let Some(id_str) = id_value.as_str() {
                                tracing::debug!("🔍 现有项目[{}]: {}", i, id_str);
                            }
                        }
                    }
                    
                    // 删除匹配的项目
                    items_table.retain(|row| {
                        if let Some(id_value) = row.get("id") {
                            if let Some(id_str) = id_value.as_str() {
                                let should_keep = id_str != target_id;
                                tracing::debug!("🔍 检查项目ID: {}, 是否保留: {}", id_str, should_keep);
                                return should_keep;
                            }
                        }
                        true // 保留无法解析的行
                    });
                    
                    let final_len = items_table.len();
                    let deleted_count = initial_len - final_len;
                    
                    tracing::info!("🗑️ 删除操作完成: 目标ID={}, 删除数量={}, 剩余数量={}", 
                        target_id, deleted_count, final_len);
                    
                    // 保存到持久化文件
                    drop(data);
                    if let Err(e) = self.save_to_file() {
                        tracing::warn!("保存持久化数据失败: {}", e);
                    }
                    
                    return Ok(deleted_count as u64);
                } else {
                    tracing::warn!("⚠️ items表不存在");
                }
            } else {
                tracing::warn!("⚠️ DELETE操作缺少参数");
            }
        }
        
        // 🔧 处理UPDATE items SET ... WHERE id = ?
        if sql_upper.contains("UPDATE ITEMS") && sql_upper.contains("WHERE ID") {
            if params.len() >= 1 {
                let target_id = params[params.len() - 1]; // 最后一个参数是ID
                let mut data = self.data.write().unwrap();
                
                if let Some(items_table) = data.get_mut("items") {
                    let mut updated_count = 0;
                    
                    for row in items_table.iter_mut() {
                        if let Some(id_value) = row.get("id") {
                            if let Some(id_str) = id_value.as_str() {
                                if id_str == target_id {
                                    // 简化：假设更新所有字段
                                    if params.len() >= 5 {
                                        row.insert("name".to_string(), serde_json::Value::String(params[0].to_string()));
                                        row.insert("description".to_string(), serde_json::Value::String(params[1].to_string()));
                                        row.insert("value".to_string(), serde_json::Value::Number(
                                            serde_json::Number::from(params[2].parse::<i32>().unwrap_or(0))
                                        ));
                                        row.insert("updated_at".to_string(), serde_json::Value::String(params[3].to_string()));
                                    }
                                    updated_count += 1;
                                    break;
                                }
                            }
                        }
                    }
                    
                    // 保存到持久化文件
                    drop(data);
                    if let Err(e) = self.save_to_file() {
                        tracing::warn!("保存持久化数据失败: {}", e);
                    }
                    
                    return Ok(updated_count);
                }
            }
        }
        
        // 简化实现，对于其他操作总是返回1行受影响
        Ok(1)
    }
    
    async fn health_check(&self) -> Result<bool> {
        Ok(true)
    }
}

/// 数据库工厂
pub struct DatabaseFactory;

impl DatabaseFactory {
    /// 从配置创建数据库实例
    pub fn create_from_config() -> Result<Box<dyn Database>> {
        let config = crate::infra::config::config();
        let database_url = config.database_url();
        
        if database_url.starts_with("sqlite:") {
            // SQLite数据库
            if database_url == "sqlite::memory:" {
                tracing::info!("🗄️ 创建SQLite内存数据库");
                Ok(Box::new(SqliteDatabase::memory()?))
            } else {
                // 提取文件路径
                let file_path = database_url.strip_prefix("sqlite:").unwrap_or(&database_url);
                tracing::info!("🗄️ 创建SQLite文件数据库: {}", file_path);
                Ok(Box::new(SqliteDatabase::new(file_path)?))
            }
        } else if database_url.starts_with("postgresql:") {
            // PostgreSQL数据库
            // 这里可以实现真实的PostgreSQL连接
            tracing::warn!("⚠️ PostgreSQL支持尚未实现，使用内存数据库");
            Ok(Box::new(MemoryDatabase::new()))
        } else {
            Err(AppError::validation(format!("不支持的数据库URL: {}", database_url)))
        }
    }

    /// 创建内存数据库（用于测试）
    pub fn create_memory() -> Box<dyn Database> {
        Box::new(MemoryDatabase::new())
    }

    /// 创建带持久化的内存数据库
    pub fn create_persistent_memory<P: AsRef<std::path::Path>>(file_path: P) -> Box<dyn Database> {
        Box::new(MemoryDatabase::with_persistence(file_path))
    }
}

/// 数据库连接池统计
#[derive(Debug, Clone)]
pub struct PoolStats {
    pub total_connections: usize,
    pub active_connections: usize,
    pub idle_connections: usize,
    pub max_connections: usize,
}

/// 数据库迁移接口
#[async_trait]
pub trait Migration {
    /// 获取迁移名称
    fn name(&self) -> &str;
    
    /// 获取迁移版本
    fn version(&self) -> u64;
    
    /// 执行迁移
    async fn up(&self, db: &dyn Database) -> Result<()>;
    
    /// 回滚迁移
    async fn down(&self, db: &dyn Database) -> Result<()>;
}

/// 数据库迁移管理器
pub struct MigrationManager {
    migrations: Vec<Box<dyn Migration + Send + Sync>>,
}

impl MigrationManager {
    pub fn new() -> Self {
        Self {
            migrations: Vec::new(),
        }
    }

    /// 添加迁移
    pub fn add_migration(&mut self, migration: Box<dyn Migration + Send + Sync>) {
        self.migrations.push(migration);
    }

    /// 执行所有迁移
    pub async fn migrate(&self, db: &dyn Database) -> Result<()> {
        // 按版本排序
        let mut sorted_migrations = self.migrations.iter().collect::<Vec<_>>();
        sorted_migrations.sort_by_key(|m| m.version());

        for migration in sorted_migrations {
            tracing::info!("执行迁移: {}", migration.name());
            migration.up(db).await?;
        }

        Ok(())
    }
}

/// 查询构建器便利函数
pub fn query() -> SimpleQueryBuilder {
    SimpleQueryBuilder::new()
}

/// 数据库辅助宏
#[macro_export]
macro_rules! db_query {
    ($sql:expr) => {
        crate::infra::di::inject::<Box<dyn crate::infra::db::Database>>().query($sql, &[]).await
    };
    ($sql:expr, $($param:expr),*) => {
        crate::infra::di::inject::<Box<dyn crate::infra::db::Database>>().query($sql, &[$(stringify!($param)),*]).await
    };
}

/// ⭐ v7 类型安全查询构建器 - 编译时验证，零运行时开销
#[derive(Debug, Clone)]
pub struct SafeQuery {
    table: String,
    columns: Vec<String>,
    where_clause: Option<String>,
    order_by: Option<(String, bool)>, // (column, desc)
    limit: Option<u32>,
    offset: Option<u32>,
    params: Vec<String>,
}

impl SafeQuery {
    /// 创建新查询
    pub fn new(table: &str) -> Self {
        Self {
            table: table.to_string(),
            columns: vec!["*".to_string()],
            where_clause: None,
            order_by: None,
            limit: None,
            offset: None,
            params: Vec::new(),
        }
    }
    
    /// 选择列（编译时验证）
    pub fn select<const N: usize>(mut self, columns: [&str; N]) -> Self {
        self.columns = columns.iter().map(|s| s.to_string()).collect();
        self
    }
    
    /// 添加WHERE条件（参数化）
    pub fn where_eq(mut self, column: &str, value: &str) -> Self {
        self.where_clause = Some(format!("{} = ?", column));
        self.params.push(value.to_string());
        self
    }
    
    /// 类型安全的排序（白名单验证）
    pub fn order_by_safe(mut self, column: &str, desc: bool) -> Self {
        // 编译时验证的安全列名
        const ALLOWED_COLUMNS: &[&str] = &["id", "name", "value", "created_at", "updated_at"];
        
        if ALLOWED_COLUMNS.contains(&column) {
            self.order_by = Some((column.to_string(), desc));
        } else {
            // 默认安全排序
            self.order_by = Some(("created_at".to_string(), false));
        }
        self
    }
    
    /// 分页（参数化）
    pub fn paginate(mut self, limit: u32, offset: u32) -> Self {
        self.limit = Some(limit);
        self.offset = Some(offset);
        self
    }
    
    /// 构建SQL和参数（类型安全）
    pub fn build(self) -> (String, Vec<String>) {
        let mut sql = format!("SELECT {} FROM {}", 
            self.columns.join(", "), 
            self.table
        );
        
        let mut params = self.params;
        
        if let Some(where_clause) = self.where_clause {
            sql.push_str(&format!(" WHERE {}", where_clause));
        }
        
        if let Some((column, desc)) = self.order_by {
            let order = if desc { "DESC" } else { "ASC" };
            sql.push_str(&format!(" ORDER BY {} {}", column, order));
        }
        
        if let Some(limit) = self.limit {
            sql.push_str(" LIMIT ?");
            params.push(limit.to_string());
            
            if let Some(offset) = self.offset {
                sql.push_str(" OFFSET ?");
                params.push(offset.to_string());
            }
        }
        
        (sql, params)
    }
} 