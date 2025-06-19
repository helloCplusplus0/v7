//! 测试辅助函数
//! 
//! 提供测试中使用的工具函数和设置函数

use axum::Router;
use std::net::SocketAddr;
use tokio::net::TcpListener;

/// 创建测试应用
pub fn create_test_app() -> Router {
    Router::new()
        .route("/test", axum::routing::get(test_handler))
}

/// 测试处理函数
async fn test_handler() -> &'static str {
    "Test OK"
}

/// 启动测试服务器
pub async fn start_test_server() -> (SocketAddr, TcpListener) {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    (addr, listener)
}

/// 等待一段时间
pub async fn wait_ms(ms: u64) {
    tokio::time::sleep(tokio::time::Duration::from_millis(ms)).await;
}

/// 测试断言辅助函数
pub fn assert_json_contains(json: &serde_json::Value, key: &str) {
    assert!(json.get(key).is_some(), "JSON should contain key: {}", key);
} 