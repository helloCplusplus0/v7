use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Item实体 - CRUD操作的目标对象
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Item {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub value: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 创建Item请求
#[derive(Debug, Deserialize)]
pub struct CreateItemRequest {
    pub name: String,
    pub description: Option<String>,
    pub value: i32,
}

/// 更新Item请求
#[derive(Debug, Deserialize)]
pub struct UpdateItemRequest {
    pub name: Option<String>,
    pub description: Option<String>,
    pub value: Option<i32>,
}

/// 创建Item响应
#[derive(Debug, Serialize)]
pub struct CreateItemResponse {
    pub item: Item,
    pub message: String,
}

/// 获取Item响应
#[derive(Debug, Serialize)]
pub struct GetItemResponse {
    pub item: Item,
}

/// 更新Item响应
#[derive(Debug, Serialize)]
pub struct UpdateItemResponse {
    pub item: Item,
    pub message: String,
}

/// 删除Item响应
#[derive(Debug, Serialize)]
pub struct DeleteItemResponse {
    pub message: String,
    pub deleted_id: String,
}

/// 列表查询参数
#[derive(Debug, Deserialize)]
pub struct ListItemsQuery {
    pub limit: Option<u32>,
    pub offset: Option<u32>,
    pub sort_by: Option<String>,
    pub order: Option<String>, // "asc" or "desc"
}

/// 列表响应
#[derive(Debug, Serialize)]
pub struct ListItemsResponse {
    pub items: Vec<Item>,
    pub total: u32,
    pub limit: u32,
    pub offset: u32,
}

/// CRUD错误类型
#[derive(Debug, thiserror::Error)]
pub enum CrudError {
    #[error("Item不存在：{id}")]
    ItemNotFound { id: String },
    #[error("Item名称已存在：{name}")]
    ItemNameExists { name: String },
    #[error("无效的参数：{message}")]
    InvalidParameter { message: String },
    #[error("数据库错误：{message}")]
    Database { message: String },
    #[error("验证错误：{message}")]
    Validation { message: String },
}

/// CRUD结果类型
pub type CrudResult<T> = Result<T, CrudError>;

impl CreateItemRequest {
    /// 验证创建请求
    ///
    /// # Errors
    ///
    /// 当以下情况发生时返回验证错误：
    /// - 名称为空或只包含空格
    /// - 名称长度超过100字符  
    /// - 描述长度超过500字符
    pub fn validate(&self) -> CrudResult<()> {
        if self.name.trim().is_empty() {
            return Err(CrudError::Validation {
                message: "名称不能为空".to_string(),
            });
        }

        if self.name.len() > 100 {
            return Err(CrudError::Validation {
                message: "名称长度不能超过100字符".to_string(),
            });
        }

        if let Some(desc) = &self.description {
            if desc.len() > 500 {
                return Err(CrudError::Validation {
                    message: "描述长度不能超过500字符".to_string(),
                });
            }
        }

        Ok(())
    }
}

impl UpdateItemRequest {
    /// 验证更新请求
    ///
    /// # Errors
    ///
    /// 当以下情况发生时返回验证错误：
    /// - 名称为空或只包含空格
    /// - 名称长度超过100字符
    /// - 描述长度超过500字符
    pub fn validate(&self) -> CrudResult<()> {
        if let Some(name) = &self.name {
            if name.trim().is_empty() {
                return Err(CrudError::Validation {
                    message: "名称不能为空".to_string(),
                });
            }

            if name.len() > 100 {
                return Err(CrudError::Validation {
                    message: "名称长度不能超过100字符".to_string(),
                });
            }
        }

        if let Some(desc) = &self.description {
            if desc.len() > 500 {
                return Err(CrudError::Validation {
                    message: "描述长度不能超过500字符".to_string(),
                });
            }
        }

        Ok(())
    }

    /// 检查是否有任何字段需要更新
    #[must_use]
    pub fn has_updates(&self) -> bool {
        self.name.is_some() || self.description.is_some() || self.value.is_some()
    }
}

impl Item {
    /// 创建新的Item实例
    #[must_use]
    pub fn new(id: String, name: String, description: Option<String>, value: i32) -> Self {
        let now = Utc::now();
        Self {
            id,
            name,
            description,
            value,
            created_at: now,
            updated_at: now,
        }
    }

    /// 应用更新请求
    pub fn apply_update(&mut self, req: &UpdateItemRequest) {
        if let Some(name) = &req.name {
            self.name.clone_from(name);
        }

        if let Some(description) = &req.description {
            self.description = Some(description.clone());
        }

        if let Some(value) = req.value {
            self.value = value;
        }

        self.updated_at = Utc::now();
    }
}
