use crate::infra::http::HttpResponse;
use crate::infra::di::inject;
use crate::infra::cache::MemoryCache;
use crate::infra::db::sqlite::SqliteDatabase;
use super::interfaces::CrudService;
use super::service::{SqliteCrudService, SqliteItemRepository};
use super::types::{
    CreateItemRequest, UpdateItemRequest, ListItemsQuery,
    CreateItemResponse, GetItemResponse, UpdateItemResponse, 
    DeleteItemResponse, ListItemsResponse, CrudResult, CrudError
};

/// ⭐ v7核心业务函数：创建项目（静态分发）
/// 
/// 函数路径: mvp_crud.create_item
/// HTTP路由: POST /api/items
/// 性能特性: 编译时单态化，零运行时开销
pub async fn create_item<S>(
    service: S,
    req: CreateItemRequest
) -> CrudResult<CreateItemResponse>
where
    S: CrudService,
{
    service.create_item(req).await
}

/// ⭐ v7核心业务函数：获取项目（静态分发）
/// 
/// 函数路径: mvp_crud.get_item
/// HTTP路由: GET /api/items/{id}
/// 性能特性: 编译时单态化，零运行时开销
pub async fn get_item<S>(
    service: S,
    id: String
) -> CrudResult<GetItemResponse>
where
    S: CrudService,
{
    service.get_item(&id).await
}

/// ⭐ v7核心业务函数：更新项目（静态分发）
/// 
/// 函数路径: mvp_crud.update_item
/// HTTP路由: PUT /api/items/{id}
/// 性能特性: 编译时单态化，零运行时开销
pub async fn update_item<S>(
    service: S,
    id: String,
    req: UpdateItemRequest
) -> CrudResult<UpdateItemResponse>
where
    S: CrudService,
{
    service.update_item(&id, req).await
}

/// ⭐ v7核心业务函数：删除项目（静态分发）
/// 
/// 函数路径: mvp_crud.delete_item
/// HTTP路由: DELETE /api/items/{id}
/// 性能特性: 编译时单态化，零运行时开销
pub async fn delete_item<S>(
    service: S,
    id: String
) -> CrudResult<DeleteItemResponse>
where
    S: CrudService,
{
    service.delete_item(&id).await
}

/// ⭐ v7核心业务函数：列出项目（静态分发）
/// 
/// 函数路径: mvp_crud.list_items
/// HTTP路由: GET /api/items
/// 性能特性: 编译时单态化，零运行时开销
pub async fn list_items<S>(
    service: S,
    query: ListItemsQuery
) -> CrudResult<ListItemsResponse>
where
    S: CrudService,
{
    service.list_items(query).await
}

// ===== HTTP适配器函数 =====

type ConcreteCrudService = SqliteCrudService<SqliteItemRepository<SqliteDatabase>, MemoryCache>;

/// HTTP适配器：创建项目
pub async fn http_create_item(req: CreateItemRequest) -> HttpResponse<CreateItemResponse> {
    let service = inject::<ConcreteCrudService>();
    match create_item(service, req).await {
        Ok(response) => HttpResponse::success(response),
        Err(e) => HttpResponse::error(
            axum::http::StatusCode::BAD_REQUEST, 
            &format!("创建项目失败: {}", e)
        ),
    }
}

/// HTTP适配器：获取项目
pub async fn http_get_item(id: String) -> HttpResponse<GetItemResponse> {
    let service = inject::<ConcreteCrudService>();
    match get_item(service, id).await {
        Ok(response) => HttpResponse::success(response),
        Err(e) => {
            let status_code = match e {
                CrudError::ItemNotFound { .. } => axum::http::StatusCode::NOT_FOUND,
                _ => axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            };
            HttpResponse::error(status_code, &format!("获取项目失败: {}", e))
        }
    }
}

/// HTTP适配器：更新项目
pub async fn http_update_item(
    id: String, 
    req: UpdateItemRequest
) -> HttpResponse<UpdateItemResponse> {
    let service = inject::<ConcreteCrudService>();
    match update_item(service, id, req).await {
        Ok(response) => HttpResponse::success(response),
        Err(e) => {
            let status_code = match e {
                CrudError::ItemNotFound { .. } => axum::http::StatusCode::NOT_FOUND,
                CrudError::ItemNameExists { .. } => axum::http::StatusCode::CONFLICT,
                CrudError::Validation { .. } => axum::http::StatusCode::BAD_REQUEST,
                _ => axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            };
            HttpResponse::error(status_code, &format!("更新项目失败: {}", e))
        }
    }
}

/// HTTP适配器：删除项目
pub async fn http_delete_item(id: String) -> HttpResponse<DeleteItemResponse> {
    let service = inject::<ConcreteCrudService>();
    match delete_item(service, id).await {
        Ok(response) => HttpResponse::success(response),
        Err(e) => {
            let status_code = match e {
                CrudError::ItemNotFound { .. } => axum::http::StatusCode::NOT_FOUND,
                _ => axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            };
            HttpResponse::error(status_code, &format!("删除项目失败: {}", e))
        }
    }
}

/// HTTP适配器：列出项目
pub async fn http_list_items(query: ListItemsQuery) -> HttpResponse<ListItemsResponse> {
    let service = inject::<ConcreteCrudService>();
    match list_items(service, query).await {
        Ok(response) => HttpResponse::success(response),
        Err(e) => HttpResponse::error(
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            &format!("获取项目列表失败: {}", e)
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::cache::MemoryCache;
    use crate::infra::db::MemoryDatabase;

    /// 创建测试用的服务实例
    fn create_test_service() -> ConcreteCrudService {
        let db = SqliteDatabase::memory().expect("Failed to create in-memory SQLite");
        let repository = SqliteItemRepository::new(db);
        let cache = MemoryCache::new();
        SqliteCrudService::new(repository, cache)
    }

    #[tokio::test]
    async fn test_create_item_success() {
        let service = create_test_service();
        let req = CreateItemRequest {
            name: "测试项目".to_string(),
            description: Some("这是一个测试项目".to_string()),
            value: 100,
        };

        let result = create_item(service, req).await;
        assert!(result.is_ok());
        
        let response = result.unwrap();
        assert_eq!(response.item.name, "测试项目");
        assert_eq!(response.item.value, 100);
    }

    #[tokio::test]
    async fn test_create_item_validation_error() {
        let service = create_test_service();
        let req = CreateItemRequest {
            name: "".to_string(), // 空名称应该验证失败
            description: None,
            value: 100,
        };

        let result = create_item(service, req).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_get_item_not_found() {
        let service = create_test_service();
        let result = get_item(service, "不存在的ID".to_string()).await;
        
        assert!(result.is_err());
        match result.unwrap_err() {
            CrudError::ItemNotFound { .. } => {} // 期望的错误类型
            _ => panic!("期望ItemNotFound错误"),
        }
    }
} 