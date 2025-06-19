//! MVP CRUD集成测试
//! 
//! 测试FMOD v7架构下的CRUD功能：
//! - 静态分发性能验证
//! - HTTP端点测试
//! - 业务逻辑测试
//! - 错误处理测试

use axum::{
    body::Body,
    http::{Request, StatusCode},
    Router,
};
use serde_json::{json, Value};
use tower::ServiceExt;

use fmod_slice::infra::di;
use fmod_slice::infra::cache::MemoryCache;
use fmod_slice::infra::db::DatabaseFactory;
use fmod_slice::slices::mvp_crud::{
    service::{SqliteCrudService, SqliteItemRepository},
    types::{CreateItemRequest, UpdateItemRequest, ListItemsQuery},
    functions::*,
};

/// 创建测试用的应用路由
fn create_test_app() -> Router {
    // 设置测试服务
    let db = DatabaseFactory::create_memory();
    let repository = SqliteItemRepository::new(db);
    let cache = MemoryCache::new();
    let crud_service = SqliteCrudService::new(repository, cache);
    
    // 注册服务
    di::register(crud_service);
    
    // 创建路由
    Router::new()
        .route("/api/items", axum::routing::post(http_create_item_handler))
        .route("/api/items", axum::routing::get(http_list_items_handler))
        .route("/api/items/:id", axum::routing::get(http_get_item_handler))
        .route("/api/items/:id", axum::routing::put(http_update_item_handler))
        .route("/api/items/:id", axum::routing::delete(http_delete_item_handler))
}

// HTTP处理器适配函数
async fn http_create_item_handler(
    axum::extract::Json(req): axum::extract::Json<CreateItemRequest>
) -> impl axum::response::IntoResponse {
    http_create_item(req).await
}

async fn http_get_item_handler(
    axum::extract::Path(id): axum::extract::Path<String>
) -> impl axum::response::IntoResponse {
    http_get_item(id).await
}

async fn http_update_item_handler(
    axum::extract::Path(id): axum::extract::Path<String>,
    axum::extract::Json(req): axum::extract::Json<UpdateItemRequest>
) -> impl axum::response::IntoResponse {
    http_update_item(id, req).await
}

async fn http_delete_item_handler(
    axum::extract::Path(id): axum::extract::Path<String>
) -> impl axum::response::IntoResponse {
    http_delete_item(id).await
}

async fn http_list_items_handler(
    axum::extract::Query(query): axum::extract::Query<ListItemsQuery>
) -> impl axum::response::IntoResponse {
    http_list_items(query).await
}

/// 测试工具函数：发送JSON请求
async fn send_json_request(
    app: &Router,
    method: &str,
    uri: &str,
    body: Option<Value>,
) -> (StatusCode, Value) {
    let request = Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json");
    
    let request = if let Some(body) = body {
        request.body(Body::from(serde_json::to_vec(&body).unwrap())).unwrap()
    } else {
        request.body(Body::empty()).unwrap()
    };
    
    let response = app.clone().oneshot(request).await.unwrap();
    let status = response.status();
    
    let body = axum::body::to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let json: Value = serde_json::from_slice(&body).unwrap_or(json!({}));
    
    (status, json)
}

// ===== 集成测试 =====

#[tokio::test]
async fn test_crud_create_item_success() {
    let app = create_test_app();
    
    let create_request = json!({
        "name": "测试项目",
        "description": "这是一个集成测试项目",
        "value": 150
    });
    
    let (status, response) = send_json_request(&app, "POST", "/api/items", Some(create_request)).await;
    
    assert_eq!(status, StatusCode::OK);
    assert_eq!(response["status"], 200);
    assert!(response["data"]["item"]["id"].is_string());
    assert_eq!(response["data"]["item"]["name"], "测试项目");
    assert_eq!(response["data"]["item"]["value"], 150);
}

#[tokio::test]
async fn test_crud_create_item_validation_error() {
    let app = create_test_app();
    
    let invalid_request = json!({
        "name": "", // 空名称应该验证失败
        "value": 100
    });
    
    let (status, response) = send_json_request(&app, "POST", "/api/items", Some(invalid_request)).await;
    
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert!(response["error"]["message"].as_str().unwrap().contains("验证失败"));
}

#[tokio::test]
async fn test_crud_get_item_not_found() {
    let app = create_test_app();
    
    let (status, response) = send_json_request(&app, "GET", "/api/items/nonexistent-id", None).await;
    
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert!(response["error"]["message"].as_str().unwrap().contains("不存在"));
}

#[tokio::test]
async fn test_crud_full_workflow() {
    let app = create_test_app();
    
    // 1. 创建项目
    let create_request = json!({
        "name": "工作流测试项目",
        "description": "测试完整CRUD工作流",
        "value": 200
    });
    
    let (status, response) = send_json_request(&app, "POST", "/api/items", Some(create_request)).await;
    assert_eq!(status, StatusCode::OK);
    
    let item_id = response["data"]["item"]["id"].as_str().unwrap();
    
    // 2. 获取项目
    let (status, response) = send_json_request(&app, "GET", &format!("/api/items/{}", item_id), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(response["data"]["item"]["name"], "工作流测试项目");
    
    // 3. 更新项目
    let update_request = json!({
        "name": "更新后的项目名称",
        "value": 300
    });
    
    let (status, response) = send_json_request(&app, "PUT", &format!("/api/items/{}", item_id), Some(update_request)).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(response["data"]["item"]["name"], "更新后的项目名称");
    assert_eq!(response["data"]["item"]["value"], 300);
    
    // 4. 列出项目
    let (status, response) = send_json_request(&app, "GET", "/api/items?limit=10", None).await;
    assert_eq!(status, StatusCode::OK);
    assert!(response["data"]["items"].is_array());
    assert!(response["data"]["total"].as_u64().unwrap() >= 1);
    
    // 5. 删除项目
    let (status, response) = send_json_request(&app, "DELETE", &format!("/api/items/{}", item_id), None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(response["data"]["deleted_id"], item_id);
    
    // 6. 验证删除成功
    let (status, _) = send_json_request(&app, "GET", &format!("/api/items/{}", item_id), None).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn test_crud_list_with_pagination() {
    let app = create_test_app();
    
    // 创建多个项目
    for i in 1..=5 {
        let create_request = json!({
            "name": format!("项目{}", i),
            "description": format!("描述{}", i),
            "value": i * 10
        });
        
        let (status, _) = send_json_request(&app, "POST", "/api/items", Some(create_request)).await;
        assert_eq!(status, StatusCode::OK);
    }
    
    // 测试分页
    let (status, response) = send_json_request(&app, "GET", "/api/items?limit=3&offset=0", None).await;
    assert_eq!(status, StatusCode::OK);
    
    let items = response["data"]["items"].as_array().unwrap();
    assert!(items.len() <= 3);
    assert!(response["data"]["total"].as_u64().unwrap() >= 5);
}

#[tokio::test]
async fn test_crud_update_name_conflict() {
    let app = create_test_app();
    
    // 创建两个项目
    let create_request1 = json!({
        "name": "项目A",
        "value": 100
    });
    
    let create_request2 = json!({
        "name": "项目B", 
        "value": 200
    });
    
    let (_, response1) = send_json_request(&app, "POST", "/api/items", Some(create_request1)).await;
    let (_, response2) = send_json_request(&app, "POST", "/api/items", Some(create_request2)).await;
    
    let item_id2 = response2["data"]["item"]["id"].as_str().unwrap();
    
    // 尝试将项目B的名称更新为项目A（应该冲突）
    let update_request = json!({
        "name": "项目A"
    });
    
    let (status, response) = send_json_request(&app, "PUT", &format!("/api/items/{}", item_id2), Some(update_request)).await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert!(response["error"]["message"].as_str().unwrap().contains("已存在"));
}

// ===== 单元测试 =====

#[tokio::test]
async fn test_static_dispatch_functions() {
    // 创建测试服务
    let db = DatabaseFactory::create_memory();
    let repository = SqliteItemRepository::new(db);
    let cache = MemoryCache::new();
    let service = SqliteCrudService::new(repository, cache);
    
    // 测试静态分发函数
    let create_req = CreateItemRequest {
        name: "静态分发测试".to_string(),
        description: Some("测试v7静态分发特性".to_string()),
        value: 500,
    };
    
    // 测试创建
    let create_result = create_item(service.clone(), create_req).await;
    assert!(create_result.is_ok());
    
    let response = create_result.unwrap();
    let item_id = response.item.id.clone();
    
    // 测试获取
    let get_result = get_item(service.clone(), item_id.clone()).await;
    assert!(get_result.is_ok());
    assert_eq!(get_result.unwrap().item.name, "静态分发测试");
    
    // 测试更新
    let update_req = UpdateItemRequest {
        name: Some("更新后的名称".to_string()),
        description: None,
        value: Some(600),
    };
    
    let update_result = update_item(service.clone(), item_id.clone(), update_req).await;
    assert!(update_result.is_ok());
    assert_eq!(update_result.unwrap().item.value, 600);
    
    // 测试删除
    let delete_result = delete_item(service.clone(), item_id.clone()).await;
    assert!(delete_result.is_ok());
}

// ===== 性能测试 =====

#[tokio::test]
async fn test_performance_static_dispatch() {
    use std::time::Instant;
    
    let db = DatabaseFactory::create_memory();
    let repository = SqliteItemRepository::new(db);
    let cache = MemoryCache::new();
    let service = SqliteCrudService::new(repository, cache);
    
    // 测试批量创建性能
    let start = Instant::now();
    
    for i in 0..100 {
        let create_req = CreateItemRequest {
            name: format!("性能测试项目{}", i),
            description: Some(format!("性能测试描述{}", i)),
            value: i,
        };
        
        let result = create_item(service.clone(), create_req).await;
        assert!(result.is_ok());
    }
    
    let duration = start.elapsed();
    println!("创建100个项目耗时: {:?}", duration);
    
    // v7静态分发应该有很好的性能表现
    assert!(duration.as_millis() < 1000, "性能测试失败：创建100个项目超过1秒");
}

#[tokio::test]
async fn test_error_handling() {
    let db = DatabaseFactory::create_memory();
    let repository = SqliteItemRepository::new(db);
    let cache = MemoryCache::new();
    let service = SqliteCrudService::new(repository, cache);
    
    // 测试验证错误
    let invalid_req = CreateItemRequest {
        name: "".to_string(), // 空名称
        description: None,
        value: 100,
    };
    
    let result = create_item(service.clone(), invalid_req).await;
    assert!(result.is_err());
    
    // 测试重复名称错误
    let create_req = CreateItemRequest {
        name: "重复测试".to_string(),
        description: None,
        value: 100,
    };
    
    let result1 = create_item(service.clone(), create_req.clone()).await;
    assert!(result1.is_ok());
    
    let result2 = create_item(service.clone(), create_req).await;
    assert!(result2.is_err());
    
    // 测试不存在的项目
    let get_result = get_item(service.clone(), "不存在的ID".to_string()).await;
    assert!(result2.is_err());
} 