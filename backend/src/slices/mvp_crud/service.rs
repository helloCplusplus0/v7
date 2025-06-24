use async_trait::async_trait;
use uuid::Uuid;

use super::interfaces::{CrudService, ItemRepository};
use super::types::{
    CreateItemRequest, CreateItemResponse, CrudError, CrudResult, DeleteItemResponse,
    GetItemResponse, Item, ListItemsQuery, ListItemsResponse, UpdateItemRequest,
    UpdateItemResponse,
};
use crate::infra::cache::{Cache, JsonCache};
use crate::infra::db::{Database, DbRow};
use crate::infra::monitoring::{logger, metrics, LogEntry, LogLevel, Timer};

/// ⭐ v7 CRUD服务实现 - 支持Clone的静态分发设计
#[derive(Clone)]
pub struct SqliteCrudService<R, C>
where
    R: ItemRepository,
    C: Cache,
{
    repository: R,
    cache: C,
}

impl<R, C> SqliteCrudService<R, C>
where
    R: ItemRepository,
    C: Cache,
{
    pub fn new(repository: R, cache: C) -> Self {
        Self { repository, cache }
    }
}

#[async_trait]
impl<R, C> CrudService for SqliteCrudService<R, C>
where
    R: ItemRepository,
    C: Cache + JsonCache + Clone,
{
    async fn create_item(&self, req: CreateItemRequest) -> CrudResult<CreateItemResponse> {
        let timer = Timer::start("crud_create_item");

        // 验证请求
        req.validate()?;

        // 检查名称是否已存在
        if let Some(_existing) = self.repository.find_by_name(&req.name).await? {
            return Err(CrudError::ItemNameExists { name: req.name });
        }

        // 创建新项目
        let id = Uuid::new_v4().to_string();
        let item = Item::new(id.clone(), req.name, req.description, req.value);

        // 保存到数据库
        self.repository.save(&item).await?;

        // 缓存项目
        let cache_key = format!("item:{id}");
        let _ = self.cache.set_json(&cache_key, &item, Some(3600)).await;

        // 记录日志
        let log_entry = LogEntry::new(LogLevel::Info, format!("创建项目成功: {id}"))
            .with_field("item_id", &id)
            .with_field("item_name", &item.name);
        logger().lock().unwrap().log(log_entry);

        // 记录指标
        let duration = timer.stop();
        metrics()
            .lock()
            .unwrap()
            .as_ref()
            .unwrap()
            .record_timer("crud.create_item", duration);

        Ok(CreateItemResponse {
            item,
            message: "项目创建成功".to_string(),
        })
    }

    async fn get_item(&self, id: &str) -> CrudResult<GetItemResponse> {
        let timer = Timer::start("crud_get_item");

        // 首先尝试从缓存获取
        let cache_key = format!("item:{id}");
        if let Ok(Some(item)) = self.cache.get_json::<Item>(&cache_key).await {
            let duration = timer.stop();
            metrics()
                .lock()
                .unwrap()
                .as_ref()
                .unwrap()
                .record_timer("crud.get_item_cache", duration);

            return Ok(GetItemResponse { item });
        }

        // 从数据库获取
        match self.repository.find_by_id(id).await? {
            Some(item) => {
                // 缓存结果
                let _ = self.cache.set_json(&cache_key, &item, Some(3600)).await;

                let duration = timer.stop();
                metrics()
                    .lock()
                    .unwrap()
                    .as_ref()
                    .unwrap()
                    .record_timer("crud.get_item_db", duration);

                Ok(GetItemResponse { item })
            }
            None => Err(CrudError::ItemNotFound { id: id.to_string() }),
        }
    }

    async fn update_item(
        &self,
        id: &str,
        req: UpdateItemRequest,
    ) -> CrudResult<UpdateItemResponse> {
        let timer = Timer::start("crud_update_item");

        // 验证请求
        req.validate()?;

        if !req.has_updates() {
            return Err(CrudError::InvalidParameter {
                message: "没有提供更新字段".to_string(),
            });
        }

        // 获取现有项目
        let Some(mut item) = self.repository.find_by_id(id).await? else {
            return Err(CrudError::ItemNotFound { id: id.to_string() });
        };

        // 检查名称冲突（如果更新了名称）
        if let Some(new_name) = &req.name {
            if new_name != &item.name {
                if let Some(_existing) = self.repository.find_by_name(new_name).await? {
                    return Err(CrudError::ItemNameExists {
                        name: new_name.clone(),
                    });
                }
            }
        }

        // 应用更新
        item.apply_update(&req);

        // 保存到数据库
        self.repository.update(&item).await?;

        // 更新缓存
        let cache_key = format!("item:{id}");
        let _ = self.cache.set_json(&cache_key, &item, Some(3600)).await;

        // 记录日志
        let log_entry = LogEntry::new(LogLevel::Info, format!("更新项目成功: {id}"))
            .with_field("item_id", id)
            .with_field("item_name", &item.name);
        logger().lock().unwrap().log(log_entry);

        let duration = timer.stop();
        metrics()
            .lock()
            .unwrap()
            .as_ref()
            .unwrap()
            .record_timer("crud.update_item", duration);

        Ok(UpdateItemResponse {
            item,
            message: "项目更新成功".to_string(),
        })
    }

    async fn delete_item(&self, id: &str) -> CrudResult<DeleteItemResponse> {
        let timer = Timer::start("crud_delete_item");

        // 检查项目是否存在
        if self.repository.find_by_id(id).await?.is_none() {
            return Err(CrudError::ItemNotFound { id: id.to_string() });
        }

        // 删除项目
        if !self.repository.delete(id).await? {
            return Err(CrudError::Database {
                message: "删除操作失败".to_string(),
            });
        }

        // 清除缓存
        let cache_key = format!("item:{id}");
        let _ = self.cache.delete(&cache_key).await;

        // 记录日志
        let log_entry =
            LogEntry::new(LogLevel::Info, format!("删除项目成功: {id}")).with_field("item_id", id);
        logger().lock().unwrap().log(log_entry);

        let duration = timer.stop();
        metrics()
            .lock()
            .unwrap()
            .as_ref()
            .unwrap()
            .record_timer("crud.delete_item", duration);

        Ok(DeleteItemResponse {
            message: "项目删除成功".to_string(),
            deleted_id: id.to_string(),
        })
    }

    async fn list_items(&self, query: ListItemsQuery) -> CrudResult<ListItemsResponse> {
        let timer = Timer::start("crud_list_items");

        let limit = query.limit.unwrap_or(20).min(100);
        let offset = query.offset.unwrap_or(0);

        let sort_by = query.sort_by.as_deref();
        let desc = query.order.as_deref() == Some("desc");

        // 获取项目列表和总数
        let (items, total) = self.repository.list(limit, offset, sort_by, desc).await?;

        let duration = timer.stop();
        metrics()
            .lock()
            .unwrap()
            .as_ref()
            .unwrap()
            .record_timer("crud.list_items", duration);

        Ok(ListItemsResponse {
            items,
            total,
            limit,
            offset,
        })
    }
}

/// ⭐ v7 `SQLite` Repository实现 - 支持Clone的静态分发设计
#[derive(Clone)]
pub struct SqliteItemRepository<D>
where
    D: Database + Clone,
{
    db: D,
}

impl<D> SqliteItemRepository<D>
where
    D: Database + Clone,
{
    pub fn new(db: D) -> Self {
        Self { db }
    }

    /// 初始化数据库表
    ///
    /// # Errors
    ///
    /// 此函数可能返回以下错误：
    /// - `CrudError::Database` - 当数据库表创建失败时
    pub async fn init_table(&self) -> CrudResult<()> {
        let sql = r"
            CREATE TABLE IF NOT EXISTS items (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                description TEXT,
                value INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        ";

        self.db
            .execute(sql, &[])
            .await
            .map_err(|e| CrudError::Database {
                message: format!("初始化表失败: {e}"),
            })?;

        Ok(())
    }

    /// 将数据库行转换为Item
    fn row_to_item(row: &DbRow) -> CrudResult<Item> {
        let id = row
            .get("id")
            .and_then(serde_json::Value::as_str)
            .ok_or_else(|| CrudError::Database {
                message: "缺少id字段".to_string(),
            })?
            .to_string();

        let name = row
            .get("name")
            .and_then(serde_json::Value::as_str)
            .ok_or_else(|| CrudError::Database {
                message: "缺少name字段".to_string(),
            })?
            .to_string();

        let description = row
            .get("description")
            .and_then(serde_json::Value::as_str)
            .map(std::string::ToString::to_string);

        let value = row
            .get("value")
            .and_then(serde_json::Value::as_i64)
            .ok_or_else(|| CrudError::Database {
                message: "缺少value字段".to_string(),
            })?;

        let value = i32::try_from(value).map_err(|_| CrudError::Database {
            message: "value字段超出范围".to_string(),
        })?;

        let created_at = row
            .get("created_at")
            .and_then(serde_json::Value::as_str)
            .and_then(|s| s.parse().ok())
            .ok_or_else(|| CrudError::Database {
                message: "无效的created_at字段".to_string(),
            })?;

        let updated_at = row
            .get("updated_at")
            .and_then(serde_json::Value::as_str)
            .and_then(|s| s.parse().ok())
            .ok_or_else(|| CrudError::Database {
                message: "无效的updated_at字段".to_string(),
            })?;

        Ok(Item {
            id,
            name,
            description,
            value,
            created_at,
            updated_at,
        })
    }
}

#[async_trait]
impl<D> ItemRepository for SqliteItemRepository<D>
where
    D: Database + Clone,
{
    async fn save(&self, item: &Item) -> CrudResult<()> {
        let sql = r"
            INSERT INTO items (id, name, description, value, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
        ";

        let description = item.description.as_deref().unwrap_or("");
        let value_str = item.value.to_string();
        let created_at_str = item.created_at.to_rfc3339();
        let updated_at_str = item.updated_at.to_rfc3339();

        let params = [
            &item.id,
            &item.name,
            description,
            &value_str,
            &created_at_str,
            &updated_at_str,
        ];

        self.db
            .execute(sql, &params)
            .await
            .map_err(|e| CrudError::Database {
                message: format!("保存项目失败: {e}"),
            })?;

        Ok(())
    }

    async fn find_by_id(&self, id: &str) -> CrudResult<Option<Item>> {
        let sql = "SELECT * FROM items WHERE id = ?";

        match self.db.query_opt(sql, &[id]).await {
            Ok(Some(row)) => Ok(Some(Self::row_to_item(&row)?)),
            Ok(None) => Ok(None),
            Err(e) => Err(CrudError::Database {
                message: format!("查询项目失败: {e}"),
            }),
        }
    }

    async fn find_by_name(&self, name: &str) -> CrudResult<Option<Item>> {
        let sql = "SELECT * FROM items WHERE name = ?";

        match self.db.query_opt(sql, &[name]).await {
            Ok(Some(row)) => Ok(Some(Self::row_to_item(&row)?)),
            Ok(None) => Ok(None),
            Err(e) => Err(CrudError::Database {
                message: format!("查询项目失败: {e}"),
            }),
        }
    }

    async fn update(&self, item: &Item) -> CrudResult<()> {
        let sql = r"
            UPDATE items 
            SET name = ?, description = ?, value = ?, updated_at = ?
            WHERE id = ?
        ";

        let description = item.description.as_deref().unwrap_or("");
        let value_str = item.value.to_string();
        let updated_at_str = item.updated_at.to_rfc3339();

        let params = [
            &item.name,
            description,
            &value_str,
            &updated_at_str,
            &item.id,
        ];

        let affected_rows =
            self.db
                .execute(sql, &params)
                .await
                .map_err(|e| CrudError::Database {
                    message: format!("更新项目失败: {e}"),
                })?;

        if affected_rows == 0 {
            return Err(CrudError::ItemNotFound {
                id: item.id.clone(),
            });
        }

        Ok(())
    }

    async fn delete(&self, id: &str) -> CrudResult<bool> {
        let sql = "DELETE FROM items WHERE id = ?";

        let affected_rows = self
            .db
            .execute(sql, &[id])
            .await
            .map_err(|e| CrudError::Database {
                message: format!("删除项目失败: {e}"),
            })?;

        Ok(affected_rows > 0)
    }

    async fn list(
        &self,
        limit: u32,
        offset: u32,
        sort_by: Option<&str>,
        desc: bool,
    ) -> CrudResult<(Vec<Item>, u32)> {
        let sort_column = match sort_by {
            Some("name") => "name",
            Some("value") => "value",
            _ => "created_at",
        };

        let order = if desc { "DESC" } else { "ASC" };

        let sql = format!(
            "SELECT id, name, description, value, created_at, updated_at FROM items ORDER BY {sort_column} {order} LIMIT ? OFFSET ?"
        );

        let limit_str = limit.to_string();
        let offset_str = offset.to_string();
        let params = [limit_str.as_str(), offset_str.as_str()];

        let rows = self
            .db
            .query(&sql, &params)
            .await
            .map_err(|e| CrudError::Database {
                message: format!("查询项目列表失败: {e} - SQL: {sql}"),
            })?;

        let mut items = Vec::new();
        for row in rows {
            items.push(Self::row_to_item(&row)?);
        }

        let total = self.count().await?;

        Ok((items, total))
    }

    async fn count(&self) -> CrudResult<u32> {
        let sql = "SELECT COUNT(*) as count FROM items";

        let row = self
            .db
            .query_one(sql, &[])
            .await
            .map_err(|e| CrudError::Database {
                message: format!("统计项目数量失败: {e}"),
            })?;

        let count = row
            .get("count")
            .and_then(serde_json::Value::as_i64)
            .ok_or_else(|| CrudError::Database {
                message: "无效的计数结果".to_string(),
            })?;

        u32::try_from(count).map_err(|_| CrudError::Database {
            message: "计数结果超出范围".to_string(),
        })
    }
}
