
use async_trait::async_trait;
use super::types::{
    Item, CreateItemRequest, UpdateItemRequest, 
    CreateItemResponse, GetItemResponse, UpdateItemResponse, 
    DeleteItemResponse, ListItemsQuery, ListItemsResponse, CrudResult
};

/// ⭐ v7 CRUD服务接口 - 必须支持Clone以实现静态分发
#[async_trait]
pub trait CrudService: Send + Sync + Clone {
    /// 创建新项目
    async fn create_item(&self, req: CreateItemRequest) -> CrudResult<CreateItemResponse>;
    
    /// 根据ID获取项目
    async fn get_item(&self, id: &str) -> CrudResult<GetItemResponse>;
    
    /// 更新项目
    async fn update_item(&self, id: &str, req: UpdateItemRequest) -> CrudResult<UpdateItemResponse>;
    
    /// 删除项目
    async fn delete_item(&self, id: &str) -> CrudResult<DeleteItemResponse>;
    
    /// 列出项目（支持分页和排序）
    async fn list_items(&self, query: ListItemsQuery) -> CrudResult<ListItemsResponse>;
}

/// ⭐ v7 数据仓库接口 - 必须支持Clone以实现静态分发
#[async_trait]
pub trait ItemRepository: Send + Sync + Clone {
    /// 保存项目
    async fn save(&self, item: &Item) -> CrudResult<()>;
    
    /// 根据ID查找项目
    async fn find_by_id(&self, id: &str) -> CrudResult<Option<Item>>;
    
    /// 根据名称查找项目（用于检查重复）
    async fn find_by_name(&self, name: &str) -> CrudResult<Option<Item>>;
    
    /// 更新项目
    async fn update(&self, item: &Item) -> CrudResult<()>;
    
    /// 删除项目
    async fn delete(&self, id: &str) -> CrudResult<bool>;
    
    /// 列出项目（支持分页和排序）
    async fn list(&self, limit: u32, offset: u32, sort_by: Option<&str>, desc: bool) -> CrudResult<(Vec<Item>, u32)>;
    
    /// 计算总数
    async fn count(&self) -> CrudResult<u32>;
} 