use async_trait::async_trait;
use crate::core::result::Result;
use super::{Database, Migration};

/// Items表初始化迁移
pub struct CreateItemsTableMigration;

#[async_trait]
impl Migration for CreateItemsTableMigration {
    fn name(&self) -> &str {
        "create_items_table"
    }
    
    fn version(&self) -> u64 {
        1
    }
    
    async fn up(&self, db: &dyn Database) -> Result<()> {
        let sql = r#"
            CREATE TABLE IF NOT EXISTS items (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                description TEXT,
                value INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        "#;
        
        db.execute(sql, &[]).await?;
        
        // 创建索引以提高查询性能
        db.execute("CREATE INDEX IF NOT EXISTS idx_items_name ON items(name)", &[]).await?;
        db.execute("CREATE INDEX IF NOT EXISTS idx_items_created_at ON items(created_at)", &[]).await?;
        
        tracing::info!("✅ 创建items表和索引成功");
        Ok(())
    }
    
    async fn down(&self, db: &dyn Database) -> Result<()> {
        db.execute("DROP INDEX IF EXISTS idx_items_created_at", &[]).await?;
        db.execute("DROP INDEX IF EXISTS idx_items_name", &[]).await?;
        db.execute("DROP TABLE IF EXISTS items", &[]).await?;
        
        tracing::info!("✅ 删除items表和索引成功");
        Ok(())
    }
}

/// 数据库迁移初始化函数
pub fn setup_migrations() -> super::MigrationManager {
    let mut manager = super::MigrationManager::new();
    
    // 添加items表迁移
    manager.add_migration(Box::new(CreateItemsTableMigration));
    
    // 这里可以添加更多迁移...
    
    manager
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::db::sqlite::SqliteDatabase;
    
    #[tokio::test]
    async fn test_create_items_table_migration() {
        let db = SqliteDatabase::memory().unwrap();
        let migration = CreateItemsTableMigration;
        
        // 执行迁移
        migration.up(&db).await.unwrap();
        
        // 验证表是否存在
        let tables = db.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='items'",
            &[]
        ).await.unwrap();
        
        assert_eq!(tables.len(), 1);
        assert_eq!(tables[0].get("name").unwrap().as_str().unwrap(), "items");
        
        // 验证索引是否存在
        let indexes = db.query(
            "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='items'",
            &[]
        ).await.unwrap();
        
        assert!(indexes.len() >= 2); // 至少有我们创建的两个索引
        
        // 测试回滚
        migration.down(&db).await.unwrap();
        
        // 验证表是否被删除
        let tables = db.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='items'",
            &[]
        ).await.unwrap();
        
        assert_eq!(tables.len(), 0);
    }
    
    #[tokio::test]
    async fn test_migration_manager() {
        let db = SqliteDatabase::memory().unwrap();
        let manager = setup_migrations();
        
        // 执行所有迁移
        manager.migrate(&db).await.unwrap();
        
        // 验证表是否存在
        let tables = db.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='items'",
            &[]
        ).await.unwrap();
        
        assert_eq!(tables.len(), 1);
    }
} 