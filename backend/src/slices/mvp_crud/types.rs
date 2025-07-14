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
#[derive(Debug, Clone, Deserialize)]
pub struct CreateItemRequest {
    pub name: String,
    pub description: Option<String>,
    pub value: i32,
}

/// 更新Item请求
#[derive(Debug, Clone, Deserialize)]
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

// ===== Proto转换实现 =====
use crate::v7_backend as proto;

impl From<proto::CreateItemRequest> for CreateItemRequest {
    fn from(proto_req: proto::CreateItemRequest) -> Self {
        Self {
            name: proto_req.name,
            description: proto_req.description,
            value: proto_req.value,
        }
    }
}

impl From<proto::UpdateItemRequest> for (String, UpdateItemRequest) {
    fn from(proto_req: proto::UpdateItemRequest) -> Self {
        let update_req = UpdateItemRequest {
            name: proto_req.name,
            description: proto_req.description,
            value: proto_req.value,
        };
        (proto_req.id, update_req)
    }
}

impl From<proto::ListItemsRequest> for ListItemsQuery {
    fn from(proto_req: proto::ListItemsRequest) -> Self {
        Self {
            limit: proto_req.limit.map(|l| l as u32),
            offset: proto_req.offset.map(|o| o as u32),
            sort_by: None, // Proto中没有sort_by字段，保持None
            order: None,   // Proto中没有order字段，保持None
        }
    }
}

impl From<Item> for proto::Item {
    fn from(item: Item) -> Self {
        Self {
            id: item.id,
            name: item.name,
            description: item.description,
            value: item.value,
            created_at: item.created_at.to_rfc3339(),
            updated_at: item.updated_at.to_rfc3339(),
        }
    }
}

impl From<CreateItemResponse> for proto::CreateItemResponse {
    fn from(resp: CreateItemResponse) -> Self {
        Self {
            success: true,
            error: String::new(),
            item: Some(resp.item.into()),
        }
    }
}

impl From<GetItemResponse> for proto::GetItemResponse {
    fn from(resp: GetItemResponse) -> Self {
        Self {
            success: true,
            error: String::new(),
            item: Some(resp.item.into()),
        }
    }
}

impl From<UpdateItemResponse> for proto::UpdateItemResponse {
    fn from(resp: UpdateItemResponse) -> Self {
        Self {
            success: true,
            error: String::new(),
            item: Some(resp.item.into()),
        }
    }
}

impl From<DeleteItemResponse> for proto::DeleteItemResponse {
    fn from(_resp: DeleteItemResponse) -> Self {
        Self {
            success: true,
            error: String::new(),
        }
    }
}

impl From<ListItemsResponse> for proto::ListItemsResponse {
    fn from(resp: ListItemsResponse) -> Self {
        Self {
            success: true,
            error: String::new(),
            items: resp.items.into_iter().map(|item| item.into()).collect(),
            total: resp.total as i32,
        }
    }
}

/// 错误到gRPC Proto响应的转换
impl From<CrudError> for proto::CreateItemResponse {
    fn from(error: CrudError) -> Self {
        Self {
            success: false,
            error: error.to_string(),
            item: None,
        }
    }
}

impl From<CrudError> for proto::GetItemResponse {
    fn from(error: CrudError) -> Self {
        Self {
            success: false,
            error: error.to_string(),
            item: None,
        }
    }
}

impl From<CrudError> for proto::UpdateItemResponse {
    fn from(error: CrudError) -> Self {
        Self {
            success: false,
            error: error.to_string(),
            item: None,
        }
    }
}

impl From<CrudError> for proto::DeleteItemResponse {
    fn from(error: CrudError) -> Self {
        Self {
            success: false,
            error: error.to_string(),
        }
    }
}

impl From<CrudError> for proto::ListItemsResponse {
    fn from(error: CrudError) -> Self {
        Self {
            success: false,
            error: error.to_string(),
            items: vec![],
            total: 0,
        }
    }
}

#[cfg(test)]
mod proto_conversion_tests {
    use super::*;
    use crate::v7_backend as proto;
    use chrono::Utc;

    #[test]
    fn test_create_item_request_conversion() {
        let proto_req = proto::CreateItemRequest {
            name: "测试项目".to_string(),
            description: Some("测试描述".to_string()),
            value: 100,
        };

        let internal_req: CreateItemRequest = proto_req.into();
        assert_eq!(internal_req.name, "测试项目");
        assert_eq!(internal_req.description, Some("测试描述".to_string()));
        assert_eq!(internal_req.value, 100);
    }

    #[test]
    fn test_item_to_proto_conversion() {
        let item = Item {
            id: "test-id".to_string(),
            name: "测试项目".to_string(),
            description: Some("测试描述".to_string()),
            value: 100,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };

        let proto_item: proto::Item = item.into();
        assert_eq!(proto_item.id, "test-id");
        assert_eq!(proto_item.name, "测试项目");
        assert_eq!(proto_item.description, Some("测试描述".to_string()));
        assert_eq!(proto_item.value, 100);
    }

    #[test]
    fn test_create_item_response_conversion() {
        let item = Item {
            id: "test-id".to_string(),
            name: "测试项目".to_string(),
            description: Some("测试描述".to_string()),
            value: 100,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };

        let response = CreateItemResponse {
            item: item.clone(),
            message: "创建成功".to_string(),
        };

        let proto_response: proto::CreateItemResponse = response.into();
        assert!(proto_response.success);
        assert!(proto_response.error.is_empty());
        assert!(proto_response.item.is_some());
        
        let proto_item = proto_response.item.unwrap();
        assert_eq!(proto_item.id, "test-id");
        assert_eq!(proto_item.name, "测试项目");
        assert_eq!(proto_item.description, Some("测试描述".to_string()));
    }

    #[test]
    fn test_error_to_proto_conversion() {
        let error = CrudError::ItemNotFound { id: "test-id".to_string() };
        let proto_response: proto::CreateItemResponse = error.into();
        
        assert!(!proto_response.success);
        assert!(proto_response.error.contains("Item不存在"));
        assert!(proto_response.error.contains("test-id"));
        assert!(proto_response.item.is_none());
    }
}
