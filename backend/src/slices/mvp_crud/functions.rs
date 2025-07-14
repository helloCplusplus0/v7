use super::interfaces::CrudService;
use super::types::{
    CreateItemRequest, CreateItemResponse, CrudResult, DeleteItemResponse,
    GetItemResponse, ListItemsQuery, ListItemsResponse, UpdateItemRequest, UpdateItemResponse,
};

/// ⭐ v7核心业务函数：创建项目（静态分发）
///
/// 函数路径: `mvp_crud.create_item`
/// gRPC方法: v7.backend.BackendService/CreateItem
/// 性能特性: 编译时单态化，零运行时开销
///
/// # Errors
///
/// 此函数可能返回以下错误：
/// - `CrudError::Validation` - 当输入数据验证失败时
/// - `CrudError::ItemNameExists` - 当项目名称已存在时
/// - `CrudError::Database` - 当数据库操作失败时
/// - `CrudError::Cache` - 当缓存操作失败时
pub async fn create_item<S>(service: S, req: CreateItemRequest) -> CrudResult<CreateItemResponse>
where
    S: CrudService,
{
    service.create_item(req).await
}

/// ⭐ v7核心业务函数：获取项目（静态分发）
///
/// 函数路径: `mvp_crud.get_item`
/// gRPC方法: v7.backend.BackendService/GetItem
/// 性能特性: 编译时单态化，零运行时开销
///
/// # Errors
///
/// 此函数可能返回以下错误：
/// - `CrudError::ItemNotFound` - 当指定ID的项目不存在时
/// - `CrudError::Database` - 当数据库操作失败时
/// - `CrudError::Cache` - 当缓存操作失败时
pub async fn get_item<S>(service: S, id: String) -> CrudResult<GetItemResponse>
where
    S: CrudService,
{
    service.get_item(&id).await
}

/// ⭐ v7核心业务函数：更新项目（静态分发）
///
/// 函数路径: `mvp_crud.update_item`
/// gRPC方法: v7.backend.BackendService/UpdateItem
/// 性能特性: 编译时单态化，零运行时开销
///
/// # Errors
///
/// 此函数可能返回以下错误：
/// - `CrudError::ItemNotFound` - 当指定ID的项目不存在时
/// - `CrudError::Validation` - 当输入数据验证失败时
/// - `CrudError::ItemNameExists` - 当更新的名称已存在时
/// - `CrudError::Database` - 当数据库操作失败时
/// - `CrudError::Cache` - 当缓存操作失败时
pub async fn update_item<S>(
    service: S,
    id: String,
    req: UpdateItemRequest,
) -> CrudResult<UpdateItemResponse>
where
    S: CrudService,
{
    service.update_item(&id, req).await
}

/// ⭐ v7核心业务函数：删除项目（静态分发）
///
/// 函数路径: `mvp_crud.delete_item`
/// gRPC方法: v7.backend.BackendService/DeleteItem
/// 性能特性: 编译时单态化，零运行时开销
///
/// # Errors
///
/// 此函数可能返回以下错误：
/// - `CrudError::ItemNotFound` - 当指定ID的项目不存在时
/// - `CrudError::Database` - 当数据库操作失败时
/// - `CrudError::Cache` - 当缓存操作失败时
pub async fn delete_item<S>(service: S, id: String) -> CrudResult<DeleteItemResponse>
where
    S: CrudService,
{
    service.delete_item(&id).await
}

/// ⭐ v7核心业务函数：列出项目（静态分发）
///
/// 函数路径: `mvp_crud.list_items`
/// gRPC方法: v7.backend.BackendService/ListItems
/// 性能特性: 编译时单态化，零运行时开销
///
/// # Errors
///
/// 此函数可能返回以下错误：
/// - `CrudError::Validation` - 当查询参数验证失败时
/// - `CrudError::Database` - 当数据库操作失败时
/// - `CrudError::Cache` - 当缓存操作失败时
pub async fn list_items<S>(service: S, query: ListItemsQuery) -> CrudResult<ListItemsResponse>
where
    S: CrudService,
{
    service.list_items(query).await
}

// HTTP适配器函数已移除 - 转移至纯gRPC模式

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::cache::MemoryCache;
    use crate::infra::db::sqlite::SqliteDatabase;
    use crate::slices::mvp_crud::service::{SqliteCrudService, SqliteItemRepository};
    use crate::slices::mvp_crud::types::CrudError;

    /// 测试用的具体服务类型
    type ConcreteCrudService = SqliteCrudService<SqliteItemRepository<SqliteDatabase>, MemoryCache>;

    /// 创建测试用的服务实例 - 包含完整的数据库初始化
    async fn create_test_service() -> ConcreteCrudService {
        let db = SqliteDatabase::memory().expect("Failed to create in-memory SQLite");
        let repository = SqliteItemRepository::new(db);

        // ✅ 关键修复：初始化数据库表结构
        repository
            .init_table()
            .await
            .expect("Failed to initialize database table");

        let cache = MemoryCache::new();
        SqliteCrudService::new(repository, cache)
    }

    /// 创建测试数据的辅助函数
    fn create_test_request(name: &str, value: i32) -> CreateItemRequest {
        CreateItemRequest {
            name: name.to_string(),
            description: Some(format!("{name} 的描述")),
            value,
        }
    }

    #[tokio::test]
    async fn test_create_item_success() {
        let service = create_test_service().await;
        let req = create_test_request("测试项目", 100);

        let result = create_item(service, req).await;
        assert!(
            result.is_ok(),
            "创建项目应该成功，但失败了: {:?}",
            result.err()
        );

        let response = result.unwrap();
        assert_eq!(response.item.name, "测试项目");
        assert_eq!(response.item.value, 100);
        assert!(response.item.description.is_some());
        assert_eq!(response.message, "项目创建成功");

        // 验证ID不为空
        assert!(!response.item.id.is_empty());

        // 验证时间戳
        assert!(response.item.created_at <= chrono::Utc::now());
        assert!(response.item.updated_at <= chrono::Utc::now());
    }

    #[tokio::test]
    async fn test_create_item_validation_error() {
        let service = create_test_service().await;

        // 测试空名称
        let req = CreateItemRequest {
            name: String::new(),
            description: None,
            value: 100,
        };

        let result = create_item(service, req).await;
        assert!(result.is_err(), "空名称应该验证失败");

        match result.unwrap_err() {
            CrudError::Validation { .. } => {} // 期望的错误类型
            other => panic!("期望Validation错误，但得到: {other:?}"),
        }
    }

    #[tokio::test]
    async fn test_create_item_duplicate_name() {
        let service = create_test_service().await;

        // 先创建一个项目
        let req1 = create_test_request("重复名称项目", 100);
        let result1 = create_item(service.clone(), req1).await;
        assert!(result1.is_ok(), "第一次创建应该成功");

        // 尝试创建同名项目
        let req2 = create_test_request("重复名称项目", 200);
        let result2 = create_item(service, req2).await;
        assert!(result2.is_err(), "重复名称应该失败");

        match result2.unwrap_err() {
            CrudError::ItemNameExists { .. } => {} // 期望的错误类型
            other => panic!("期望ItemNameExists错误，但得到: {other:?}"),
        }
    }

    #[tokio::test]
    async fn test_get_item_success() {
        let service = create_test_service().await;

        // 先创建一个项目
        let create_req = create_test_request("获取测试项目", 150);
        let create_result = create_item(service.clone(), create_req).await;
        assert!(create_result.is_ok());

        let created_item = create_result.unwrap().item;

        // 获取项目
        let get_result = get_item(service, created_item.id.clone()).await;
        assert!(get_result.is_ok(), "获取项目应该成功");

        let response = get_result.unwrap();
        assert_eq!(response.item.id, created_item.id);
        assert_eq!(response.item.name, "获取测试项目");
        assert_eq!(response.item.value, 150);
    }

    #[tokio::test]
    async fn test_get_item_not_found() {
        let service = create_test_service().await;
        let result = get_item(service, "不存在的ID".to_string()).await;

        assert!(result.is_err(), "获取不存在的项目应该失败");
        match result.unwrap_err() {
            CrudError::ItemNotFound { id } => {
                assert_eq!(id, "不存在的ID");
            }
            other => panic!("期望ItemNotFound错误，但得到: {other:?}"),
        }
    }

    #[tokio::test]
    async fn test_update_item_success() {
        let service = create_test_service().await;

        // 先创建一个项目
        let create_req = create_test_request("更新测试项目", 200);
        let create_result = create_item(service.clone(), create_req).await;
        assert!(create_result.is_ok());

        let created_item = create_result.unwrap().item;

        // 更新项目
        let update_req = UpdateItemRequest {
            name: Some("更新后的项目".to_string()),
            description: Some("更新后的描述".to_string()),
            value: Some(250),
        };

        let update_result = update_item(service, created_item.id.clone(), update_req).await;
        assert!(update_result.is_ok(), "更新项目应该成功");

        let response = update_result.unwrap();
        assert_eq!(response.item.name, "更新后的项目");
        assert_eq!(response.item.value, 250);
        assert_eq!(response.item.description, Some("更新后的描述".to_string()));
        assert_eq!(response.message, "项目更新成功");

        // 验证更新时间
        assert!(response.item.updated_at > response.item.created_at);
    }

    #[tokio::test]
    async fn test_update_item_not_found() {
        let service = create_test_service().await;

        let update_req = UpdateItemRequest {
            name: Some("不存在的项目".to_string()),
            description: None,
            value: Some(100),
        };

        let result = update_item(service, "不存在的ID".to_string(), update_req).await;
        assert!(result.is_err(), "更新不存在的项目应该失败");

        match result.unwrap_err() {
            CrudError::ItemNotFound { id } => {
                assert_eq!(id, "不存在的ID");
            }
            other => panic!("期望ItemNotFound错误，但得到: {other:?}"),
        }
    }

    #[tokio::test]
    async fn test_delete_item_success() {
        let service = create_test_service().await;

        // 先创建一个项目
        let create_req = create_test_request("删除测试项目", 300);
        let create_result = create_item(service.clone(), create_req).await;
        assert!(create_result.is_ok());

        let created_item = create_result.unwrap().item;

        // 删除项目
        let delete_result = delete_item(service.clone(), created_item.id.clone()).await;
        assert!(delete_result.is_ok(), "删除项目应该成功");

        let response = delete_result.unwrap();
        assert_eq!(response.deleted_id, created_item.id);
        assert_eq!(response.message, "项目删除成功");

        // 验证项目已被删除
        let get_result = get_item(service, created_item.id).await;
        assert!(get_result.is_err());
        match get_result.unwrap_err() {
            CrudError::ItemNotFound { .. } => {}
            other => panic!("删除后获取应该返回ItemNotFound，但得到: {other:?}"),
        }
    }

    #[tokio::test]
    async fn test_delete_item_not_found() {
        let service = create_test_service().await;

        let result = delete_item(service, "不存在的ID".to_string()).await;
        assert!(result.is_err(), "删除不存在的项目应该失败");

        match result.unwrap_err() {
            CrudError::ItemNotFound { id } => {
                assert_eq!(id, "不存在的ID");
            }
            other => panic!("期望ItemNotFound错误，但得到: {other:?}"),
        }
    }

    #[tokio::test]
    async fn test_list_items_empty() {
        let service = create_test_service().await;

        let query = ListItemsQuery {
            limit: Some(10),
            offset: Some(0),
            sort_by: None,
            order: None,
        };

        let result = list_items(service, query).await;
        assert!(result.is_ok(), "列出空项目应该成功");

        let response = result.unwrap();
        assert_eq!(response.items.len(), 0);
        assert_eq!(response.total, 0);
        assert_eq!(response.limit, 10);
        assert_eq!(response.offset, 0);
    }

    #[tokio::test]
    async fn test_list_items_with_data() {
        let service = create_test_service().await;

        // 创建多个项目
        let items_to_create = vec![("项目A", 100), ("项目B", 200), ("项目C", 300)];

        for (name, value) in items_to_create {
            let req = create_test_request(name, value);
            let result = create_item(service.clone(), req).await;
            assert!(result.is_ok(), "创建项目 {name} 应该成功");
        }

        // 列出项目
        let query = ListItemsQuery {
            limit: Some(10),
            offset: Some(0),
            sort_by: Some("name".to_string()),
            order: Some("asc".to_string()),
        };

        let result = list_items(service, query).await;
        assert!(result.is_ok(), "列出项目应该成功");

        let response = result.unwrap();
        assert_eq!(response.items.len(), 3);
        assert_eq!(response.total, 3);

        // 验证排序
        assert_eq!(response.items[0].name, "项目A");
        assert_eq!(response.items[1].name, "项目B");
        assert_eq!(response.items[2].name, "项目C");
    }

    #[tokio::test]
    async fn test_list_items_pagination() {
        let service = create_test_service().await;

        // 创建5个项目
        for i in 1..=5 {
            let req = create_test_request(&format!("分页项目{i}"), i * 100);
            let result = create_item(service.clone(), req).await;
            assert!(result.is_ok());
        }

        // 测试分页 - 第一页
        let query1 = ListItemsQuery {
            limit: Some(2),
            offset: Some(0),
            sort_by: Some("name".to_string()),
            order: Some("asc".to_string()),
        };

        let result1 = list_items(service.clone(), query1).await;
        assert!(result1.is_ok());

        let response1 = result1.unwrap();
        assert_eq!(response1.items.len(), 2);
        assert_eq!(response1.total, 5);
        assert_eq!(response1.limit, 2);
        assert_eq!(response1.offset, 0);

        // 测试分页 - 第二页
        let query2 = ListItemsQuery {
            limit: Some(2),
            offset: Some(2),
            sort_by: Some("name".to_string()),
            order: Some("asc".to_string()),
        };

        let result2 = list_items(service, query2).await;
        assert!(result2.is_ok());

        let response2 = result2.unwrap();
        assert_eq!(response2.items.len(), 2);
        assert_eq!(response2.total, 5);
        assert_eq!(response2.limit, 2);
        assert_eq!(response2.offset, 2);

        // 验证不同页的数据不重复
        assert_ne!(response1.items[0].id, response2.items[0].id);
    }
}
