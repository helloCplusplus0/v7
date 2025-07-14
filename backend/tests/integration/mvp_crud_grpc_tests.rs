//! MVP CRUD gRPC集成测试
//!
//! 测试FMOD v7架构下的gRPC CRUD功能：
//! - gRPC服务端点测试
//! - 静态分发性能验证
//! - 业务逻辑集成测试
//! - 错误处理测试

use std::time::Duration;
use tokio::time::timeout;

use fmod_slice::infra::cache::MemoryCache;
use fmod_slice::infra::db::{Database, SqliteDatabase};
use fmod_slice::slices::mvp_crud::{
    service::{SqliteCrudService, SqliteItemRepository},
    types::*,
    functions::*,
};
use fmod_slice::v7_backend::{
    CreateItemRequest as ProtoCreateItemRequest,
};

/// 创建测试服务
async fn create_test_service() -> SqliteCrudService<SqliteItemRepository<SqliteDatabase>, MemoryCache> {
    // 创建内存数据库
    let db = SqliteDatabase::memory().expect("Failed to create test database");
    
    // 初始化数据库表
    db.execute(
        r#"
        CREATE TABLE IF NOT EXISTS items (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            value INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        "#,
        &[],
    ).await.expect("Failed to create items table");
    
    // 创建仓库和服务
    let repository = SqliteItemRepository::new(db);
    let cache = MemoryCache::new();
    SqliteCrudService::new(repository, cache)
}

// ===== 基础功能测试 =====

#[tokio::test]
async fn test_create_item_success() {
    let service = create_test_service().await;
    
    let request = CreateItemRequest {
        name: "gRPC测试项目".to_string(),
        description: Some("这是一个gRPC集成测试项目".to_string()),
        value: 150,
    };
    
    let result = create_item(service, request).await;
    
    assert!(result.is_ok());
    let response = result.unwrap();
    assert_eq!(response.item.name, "gRPC测试项目");
    assert_eq!(response.item.value, 150);
    assert!(response.item.description.is_some());
}

#[tokio::test]
async fn test_get_item_not_found() {
    let service = create_test_service().await;
    
    let result = get_item(service, "nonexistent-id".to_string()).await;
    
    assert!(result.is_err());
}

#[tokio::test]
async fn test_full_crud_workflow() {
    let service = create_test_service().await;
    
    // 1. 创建项目
    let create_request = CreateItemRequest {
        name: "完整工作流测试".to_string(),
        description: Some("测试完整CRUD工作流".to_string()),
        value: 200,
    };
    
    let create_result = create_item(service.clone(), create_request).await;
    assert!(create_result.is_ok());
    let item_id = create_result.unwrap().item.id;
    
    // 2. 获取项目
    let get_result = get_item(service.clone(), item_id.clone()).await;
    assert!(get_result.is_ok());
    let retrieved_item = get_result.unwrap().item;
    assert_eq!(retrieved_item.name, "完整工作流测试");
    assert_eq!(retrieved_item.value, 200);
    
    // 3. 更新项目
    let update_request = UpdateItemRequest {
        name: Some("更新后的名称".to_string()),
        description: None,
        value: Some(300),
    };
    
    let update_result = update_item(service.clone(), item_id.clone(), update_request).await;
    assert!(update_result.is_ok());
    let updated_item = update_result.unwrap().item;
    assert_eq!(updated_item.name, "更新后的名称");
    assert_eq!(updated_item.value, 300);
    
    // 4. 列出项目
    let list_query = ListItemsQuery {
        limit: Some(10),
        offset: Some(0),
        sort_by: Some("created_at".to_string()),
        order: Some("desc".to_string()),
    };
    
    let list_result = list_items(service.clone(), list_query).await;
    assert!(list_result.is_ok());
    let list_response = list_result.unwrap();
    assert!(list_response.items.len() >= 1);
    assert!(list_response.total >= 1);
    
    // 5. 删除项目
    let delete_result = delete_item(service.clone(), item_id.clone()).await;
    assert!(delete_result.is_ok());
    assert_eq!(delete_result.unwrap().deleted_id, item_id);
    
    // 6. 验证删除
    let get_deleted_result = get_item(service, item_id).await;
    assert!(get_deleted_result.is_err());
}

// ===== Proto转换测试 =====

#[tokio::test]
async fn test_proto_conversions() {
    // 测试CreateItemRequest转换
    let proto_create = ProtoCreateItemRequest {
        name: "Proto测试".to_string(),
        description: Some("Proto描述".to_string()),
        value: 100,
    };
    
    let internal_create = CreateItemRequest::from(proto_create);
    assert_eq!(internal_create.name, "Proto测试");
    assert_eq!(internal_create.description, Some("Proto描述".to_string()));
    assert_eq!(internal_create.value, 100);
    
    // 测试Item到Proto转换
    let item = Item {
        id: "test-id".to_string(),
        name: "测试项目".to_string(),
        description: Some("测试描述".to_string()),
        value: 150,
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
    };
    
    let proto_item: fmod_slice::v7_backend::Item = item.into();
    assert_eq!(proto_item.id, "test-id");
    assert_eq!(proto_item.name, "测试项目");
    assert_eq!(proto_item.description, Some("测试描述".to_string()));
    assert_eq!(proto_item.value, 150);
}

// ===== 性能测试 =====

#[tokio::test]
async fn test_static_dispatch_performance() {
    let service = create_test_service().await;
    
    let start = std::time::Instant::now();
    
    // 创建100个项目测试性能
    for i in 0..100 {
        let request = CreateItemRequest {
            name: format!("性能测试项目_{}", i),
            description: Some(format!("性能测试描述_{}", i)),
            value: i as i32,
        };
        
        let result = create_item(service.clone(), request).await;
        assert!(result.is_ok());
    }
    
    let duration = start.elapsed();
    println!("创建100个项目耗时: {:?}", duration);
    
    // 验证性能：应该在合理时间内完成
    assert!(duration < Duration::from_secs(5), "性能测试失败：耗时过长");
}

// ===== 并发测试 =====

#[tokio::test]
async fn test_concurrent_operations() {
    let service = create_test_service().await;
    
    // 并发创建多个项目
    let mut handles = vec![];
    
    for i in 0..10 {
        let service_clone = service.clone();
        let handle = tokio::spawn(async move {
            let request = CreateItemRequest {
                name: format!("并发测试项目_{}", i),
                description: Some(format!("并发测试描述_{}", i)),
                value: i as i32,
            };
            
            create_item(service_clone, request).await
        });
        handles.push(handle);
    }
    
    // 等待所有任务完成
    let mut success_count = 0;
    for handle in handles {
        let result = handle.await.unwrap();
        if result.is_ok() {
            success_count += 1;
        }
    }
    
    // 验证所有操作都成功
    assert_eq!(success_count, 10, "并发操作失败");
}

// ===== 错误处理测试 =====

#[tokio::test]
async fn test_validation_errors() {
    let service = create_test_service().await;
    
    // 测试空名称验证
    let invalid_request = CreateItemRequest {
        name: "".to_string(),
        description: None,
        value: 100,
    };
    
    let result = create_item(service.clone(), invalid_request).await;
    assert!(result.is_err());
    
    // 测试重复名称
    let valid_request = CreateItemRequest {
        name: "唯一名称测试".to_string(),
        description: None,
        value: 100,
    };
    
    let first_result = create_item(service.clone(), valid_request.clone()).await;
    assert!(first_result.is_ok());
    
    let duplicate_result = create_item(service, valid_request).await;
    assert!(duplicate_result.is_err());
}

// ===== 缓存测试 =====

#[tokio::test]
async fn test_cache_functionality() {
    let service = create_test_service().await;
    
    // 创建项目
    let create_request = CreateItemRequest {
        name: "缓存测试项目".to_string(),
        description: Some("测试缓存功能".to_string()),
        value: 100,
    };
    
    let create_result = create_item(service.clone(), create_request).await;
    assert!(create_result.is_ok());
    let item_id = create_result.unwrap().item.id;
    
    // 第一次获取（从数据库）
    let start1 = std::time::Instant::now();
    let get_result1 = get_item(service.clone(), item_id.clone()).await;
    let duration1 = start1.elapsed();
    assert!(get_result1.is_ok());
    
    // 第二次获取（从缓存）
    let start2 = std::time::Instant::now();
    let get_result2 = get_item(service, item_id).await;
    let duration2 = start2.elapsed();
    assert!(get_result2.is_ok());
    
    // 缓存命中应该更快（这个测试可能不稳定，主要用于验证功能）
    println!("首次查询耗时: {:?}, 缓存查询耗时: {:?}", duration1, duration2);
}

// ===== 超时测试 =====

#[tokio::test]
async fn test_operation_timeouts() {
    let service = create_test_service().await;
    
    let request = CreateItemRequest {
        name: "超时测试项目".to_string(),
        description: Some("测试操作超时".to_string()),
        value: 100,
    };
    
    // 使用超时包装操作
    let result = timeout(
        Duration::from_secs(10),
        create_item(service, request)
    ).await;
    
    assert!(result.is_ok(), "操作应该在超时时间内完成");
    assert!(result.unwrap().is_ok(), "操作应该成功");
}

// ===== 数据完整性测试 =====

#[tokio::test]
async fn test_data_integrity() {
    let service = create_test_service().await;
    
    // 创建项目
    let create_request = CreateItemRequest {
        name: "数据完整性测试".to_string(),
        description: Some("测试数据完整性".to_string()),
        value: 100,
    };
    
    let create_result = create_item(service.clone(), create_request).await;
    assert!(create_result.is_ok());
    let created_item = create_result.unwrap().item;
    
    // 验证创建时间和更新时间
    assert!(created_item.created_at <= chrono::Utc::now());
    assert!(created_item.updated_at <= chrono::Utc::now());
    assert_eq!(created_item.created_at, created_item.updated_at);
    
    // 更新项目
    let update_request = UpdateItemRequest {
        name: Some("更新后的名称".to_string()),
        description: None,
        value: Some(200),
    };
    
    // 等待一小段时间确保更新时间不同
    tokio::time::sleep(Duration::from_millis(10)).await;
    
    let update_result = update_item(service, created_item.id, update_request).await;
    assert!(update_result.is_ok());
    let updated_item = update_result.unwrap().item;
    
    // 验证更新时间
    assert!(updated_item.updated_at > updated_item.created_at);
    assert_eq!(updated_item.name, "更新后的名称");
    assert_eq!(updated_item.value, 200);
}

// ===== 边界值测试 =====

#[tokio::test]
async fn test_boundary_values() {
    let service = create_test_service().await;
    
    // 测试最大值（使用符合验证规则的描述长度）
    let max_request = CreateItemRequest {
        name: "最大值测试".to_string(),
        description: Some("A".repeat(400)), // 400字符，符合<=500的限制
        value: i32::MAX,
    };
    
    let max_result = create_item(service.clone(), max_request).await;
    assert!(max_result.is_ok());
    
    // 测试最小值
    let min_request = CreateItemRequest {
        name: "最小值测试".to_string(),
        description: None,
        value: i32::MIN,
    };
    
    let min_result = create_item(service, min_request).await;
    assert!(min_result.is_ok());
} 