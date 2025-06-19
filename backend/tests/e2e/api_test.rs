//! 端到端API测试
//! 
//! 测试完整的HTTP API流程

use axum_test::TestServer;
use serde_json::json;

mod common;
use common::*;

#[tokio::test]
async fn test_health_check_endpoint() {
    let app = create_test_app();
    let server = TestServer::new(app).unwrap();

    let response = server.get("/test").await;
    
    response.assert_status_ok();
    response.assert_text("Test OK");
}

#[tokio::test]
async fn test_json_response() {
    let test_json = generate_test_json();
    
    // 验证测试数据结构
    assert_json_contains(&test_json, "message");
    assert_json_contains(&test_json, "timestamp");
    assert_json_contains(&test_json, "data");
}

#[tokio::test]
async fn test_concurrent_requests() {
    let app = create_test_app();
    let server = TestServer::new(app).unwrap();
    
    // 并发发送10个请求
    let mut handles = vec![];
    
    for _ in 0..10 {
        let server_clone = server.clone();
        let handle = tokio::spawn(async move {
            server_clone.get("/test").await.assert_status_ok();
        });
        handles.push(handle);
    }
    
    // 等待所有请求完成
    for handle in handles {
        handle.await.unwrap();
    }
} 