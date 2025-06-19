use async_trait::async_trait;
use rusqlite::{Connection, Row, params_from_iter};
use serde_json::Value;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use crate::core::result::Result;
use crate::core::error::AppError;
use super::{Database, DbRow, Transaction, AdvancedDatabase, BatchOperation};

/// SQLite数据库实现
#[derive(Clone)]
pub struct SqliteDatabase {
    connection: Arc<Mutex<Connection>>,
    file_path: String,
}

impl SqliteDatabase {
    /// 创建新的SQLite数据库连接
    pub fn new<P: AsRef<std::path::Path>>(file_path: P) -> Result<Self> {
        let path_str = file_path.as_ref().to_string_lossy().to_string();
        
        // 确保数据库文件所在目录存在
        if let Some(parent_dir) = file_path.as_ref().parent() {
            std::fs::create_dir_all(parent_dir)
                .map_err(|e| AppError::database(format!("无法创建数据库目录 {}: {}", parent_dir.display(), e)))?;
        }
        
        // 创建连接
        let conn = Connection::open(&file_path)
            .map_err(|e| AppError::database(format!("无法打开SQLite数据库 {}: {}", path_str, e)))?;
            
        // 启用外键约束
        conn.execute("PRAGMA foreign_keys = ON", [])
            .map_err(|e| AppError::database(format!("无法启用外键约束: {}", e)))?;
            
        // 设置WAL模式以提高并发性能（仅对文件数据库有效）
        if path_str != ":memory:" {
            // 尝试设置WAL模式，失败时继续（某些SQLite版本可能不支持）
            if let Err(e) = conn.execute("PRAGMA journal_mode = WAL", []) {
                tracing::warn!("无法设置WAL模式，继续使用默认模式: {}", e);
            } else {
                tracing::debug!("成功设置WAL模式");
            }
        }
            
        Ok(Self {
            connection: Arc::new(Mutex::new(conn)),
            file_path: path_str,
        })
    }
    
    /// 创建内存SQLite数据库
    pub fn memory() -> Result<Self> {
        Self::new(":memory:")
    }
    
    /// 将rusqlite的Row转换为DbRow
    fn row_to_dbrow(row: &Row) -> rusqlite::Result<DbRow> {
        let mut map = HashMap::new();
        let column_count = row.as_ref().column_count();
        
        for i in 0..column_count {
            let column_name = row.as_ref().column_name(i)?;
            let value: Value = match row.get_ref(i)? {
                rusqlite::types::ValueRef::Null => Value::Null,
                rusqlite::types::ValueRef::Integer(i) => Value::Number(serde_json::Number::from(i)),
                rusqlite::types::ValueRef::Real(f) => {
                    if let Some(num) = serde_json::Number::from_f64(f) {
                        Value::Number(num)
                    } else {
                        Value::Null
                    }
                },
                rusqlite::types::ValueRef::Text(s) => {
                    Value::String(String::from_utf8_lossy(s).to_string())
                },
                rusqlite::types::ValueRef::Blob(b) => {
                    // 将blob转换为十六进制字符串（简化处理）
                    let hex_string = b.iter()
                        .map(|byte| format!("{:02x}", byte))
                        .collect::<String>();
                    Value::String(hex_string)
                },
            };
            map.insert(column_name.to_string(), value);
        }
        
        Ok(map)
    }
    
    /// 执行SQL查询的内部实现
    fn execute_query_internal(&self, sql: &str, params: &[&str]) -> Result<Vec<DbRow>> {
        let conn = self.connection.lock()
            .map_err(|e| AppError::database(format!("无法获取数据库连接锁: {}", e)))?;
            
        let mut stmt = conn.prepare(sql)
            .map_err(|e| AppError::database(format!("SQL语句准备失败: {} - {}", sql, e)))?;
            
        let rows = stmt.query_map(params_from_iter(params), Self::row_to_dbrow)
            .map_err(|e| AppError::database(format!("查询执行失败: {}", e)))?;
            
        let mut result = Vec::new();
        for row_result in rows {
            let row = row_result
                .map_err(|e| AppError::database(format!("行数据解析失败: {}", e)))?;
            result.push(row);
        }
        
        Ok(result)
    }
    
    /// 执行SQL更新的内部实现
    fn execute_update_internal(&self, sql: &str, params: &[&str]) -> Result<u64> {
        let conn = self.connection.lock()
            .map_err(|e| AppError::database(format!("无法获取数据库连接锁: {}", e)))?;
            
        let affected_rows = conn.execute(sql, params_from_iter(params))
            .map_err(|e| AppError::database(format!("SQL执行失败: {} - {}", sql, e)))?;
            
        Ok(affected_rows as u64)
    }
}

#[async_trait]
impl Database for SqliteDatabase {
    async fn query(&self, sql: &str, params: &[&str]) -> Result<Vec<DbRow>> {
        // 使用tokio::task::spawn_blocking在线程池中执行同步操作
        let sql = sql.to_string();
        let params = params.iter().map(|s| s.to_string()).collect::<Vec<_>>();
        let db = self.clone();
        
        tokio::task::spawn_blocking(move || {
            let params_refs: Vec<&str> = params.iter().map(|s| s.as_str()).collect();
            db.execute_query_internal(&sql, &params_refs)
        })
        .await
        .map_err(|e| AppError::database(format!("异步任务执行失败: {}", e)))?
    }
    
    async fn query_one(&self, sql: &str, params: &[&str]) -> Result<DbRow> {
        let rows = self.query(sql, params).await?;
        rows.into_iter().next()
            .ok_or_else(|| AppError::not_found("查询结果为空".to_string()))
    }
    
    async fn query_opt(&self, sql: &str, params: &[&str]) -> Result<Option<DbRow>> {
        let rows = self.query(sql, params).await?;
        Ok(rows.into_iter().next())
    }
    
    async fn execute(&self, sql: &str, params: &[&str]) -> Result<u64> {
        let sql = sql.to_string();
        let params = params.iter().map(|s| s.to_string()).collect::<Vec<_>>();
        let db = self.clone();
        
        tokio::task::spawn_blocking(move || {
            let params_refs: Vec<&str> = params.iter().map(|s| s.as_str()).collect();
            db.execute_update_internal(&sql, &params_refs)
        })
        .await
        .map_err(|e| AppError::database(format!("异步任务执行失败: {}", e)))?
    }
    
    async fn health_check(&self) -> Result<bool> {
        match self.query("SELECT 1", &[]).await {
            Ok(_) => Ok(true),
            Err(_) => Ok(false),
        }
    }
}

/// SQLite事务实现
pub struct SqliteTransaction {
    connection: Arc<Mutex<Connection>>,
    committed: bool,
}

impl SqliteTransaction {
    pub fn new(connection: Arc<Mutex<Connection>>) -> Result<Self> {
        // 开始事务
        {
            let conn = connection.lock()
                .map_err(|e| AppError::database(format!("无法获取连接锁: {}", e)))?;
            conn.execute("BEGIN", [])
                .map_err(|e| AppError::database(format!("无法开始事务: {}", e)))?;
        }
        
        Ok(Self {
            connection,
            committed: false,
        })
    }
}

#[async_trait]
impl Transaction for SqliteTransaction {
    async fn query(&self, sql: &str, params: &[&str]) -> Result<Vec<DbRow>> {
        let conn = self.connection.lock()
            .map_err(|e| AppError::database(format!("无法获取连接锁: {}", e)))?;
            
        let mut stmt = conn.prepare(sql)
            .map_err(|e| AppError::database(format!("SQL语句准备失败: {}", e)))?;
            
        let rows = stmt.query_map(params_from_iter(params), SqliteDatabase::row_to_dbrow)
            .map_err(|e| AppError::database(format!("查询执行失败: {}", e)))?;
            
        let mut result = Vec::new();
        for row_result in rows {
            let row = row_result
                .map_err(|e| AppError::database(format!("行数据解析失败: {}", e)))?;
            result.push(row);
        }
        
        Ok(result)
    }
    
    async fn execute(&self, sql: &str, params: &[&str]) -> Result<u64> {
        let conn = self.connection.lock()
            .map_err(|e| AppError::database(format!("无法获取连接锁: {}", e)))?;
            
        let affected_rows = conn.execute(sql, params_from_iter(params))
            .map_err(|e| AppError::database(format!("SQL执行失败: {}", e)))?;
            
        Ok(affected_rows as u64)
    }
    
    async fn commit(mut self: Box<Self>) -> Result<()> {
        let conn = self.connection.lock()
            .map_err(|e| AppError::database(format!("无法获取连接锁: {}", e)))?;
            
        conn.execute("COMMIT", [])
            .map_err(|e| AppError::database(format!("事务提交失败: {}", e)))?;
            
        self.committed = true;
        Ok(())
    }
    
    async fn rollback(mut self: Box<Self>) -> Result<()> {
        if !self.committed {
            let conn = self.connection.lock()
                .map_err(|e| AppError::database(format!("无法获取连接锁: {}", e)))?;
                
            conn.execute("ROLLBACK", [])
                .map_err(|e| AppError::database(format!("事务回滚失败: {}", e)))?;
        }
        Ok(())
    }
}

impl Drop for SqliteTransaction {
    fn drop(&mut self) {
        if !self.committed {
            // 尝试回滚事务
            if let Ok(conn) = self.connection.lock() {
                let _ = conn.execute("ROLLBACK", []);
            }
        }
    }
}

#[async_trait]
impl AdvancedDatabase for SqliteDatabase {
    async fn begin_transaction(&self) -> Result<Box<dyn Transaction>> {
        let transaction = SqliteTransaction::new(self.connection.clone())?;
        Ok(Box::new(transaction))
    }
    
    async fn batch(&self, operations: Vec<BatchOperation>) -> Result<Vec<u64>> {
        let mut results = Vec::new();
        
        // 在事务中执行批量操作
        let transaction = self.begin_transaction().await?;
        
        for operation in operations {
            let params: Vec<&str> = operation.params.iter().map(|s| s.as_str()).collect();
            let affected_rows = transaction.execute(&operation.sql, &params).await?;
            results.push(affected_rows);
        }
        
        transaction.commit().await?;
        Ok(results)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;
    
    #[tokio::test]
    async fn test_sqlite_database_creation() {
        let temp_file = NamedTempFile::new().unwrap();
        let db = SqliteDatabase::new(temp_file.path()).unwrap();
        
        assert!(db.health_check().await.unwrap());
    }
    
    #[tokio::test]
    async fn test_sqlite_memory_database() {
        let db = SqliteDatabase::memory().unwrap();
        assert!(db.health_check().await.unwrap());
    }
    
    #[tokio::test]
    async fn test_basic_operations() {
        let db = SqliteDatabase::memory().unwrap();
        
        // 创建表
        db.execute(
            "CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT, value INTEGER)",
            &[]
        ).await.unwrap();
        
        // 插入数据
        let affected = db.execute(
            "INSERT INTO test_table (name, value) VALUES (?, ?)",
            &["test", "42"]
        ).await.unwrap();
        assert_eq!(affected, 1);
        
        // 查询数据
        let rows = db.query("SELECT * FROM test_table", &[]).await.unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].get("name").unwrap().as_str().unwrap(), "test");
        assert_eq!(rows[0].get("value").unwrap().as_i64().unwrap(), 42);
    }
    
    #[tokio::test]
    async fn test_transaction() {
        let db = SqliteDatabase::memory().unwrap();
        
        // 创建表
        db.execute(
            "CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT)",
            &[]
        ).await.unwrap();
        
        // 测试事务提交
        {
            let tx = db.begin_transaction().await.unwrap();
            tx.execute("INSERT INTO test_table (name) VALUES (?)", &["test1"]).await.unwrap();
            tx.commit().await.unwrap();
        }
        
        let rows = db.query("SELECT COUNT(*) as count FROM test_table", &[]).await.unwrap();
        assert_eq!(rows[0].get("count").unwrap().as_i64().unwrap(), 1);
        
        // 测试事务回滚
        {
            let tx = db.begin_transaction().await.unwrap();
            tx.execute("INSERT INTO test_table (name) VALUES (?)", &["test2"]).await.unwrap();
            tx.rollback().await.unwrap();
        }
        
        let rows = db.query("SELECT COUNT(*) as count FROM test_table", &[]).await.unwrap();
        assert_eq!(rows[0].get("count").unwrap().as_i64().unwrap(), 1);
    }
} 