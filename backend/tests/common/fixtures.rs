//! 测试夹具
//! 
//! 提供测试数据生成和管理功能

use fake::{Fake, Faker};
use serde_json::json;

/// 生成测试用的JSON数据
pub fn generate_test_json() -> serde_json::Value {
    json!({
        "message": "Hello from test fixture",
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "data": {
            "test": true,
            "id": uuid::Uuid::new_v4()
        }
    })
}

/// 生成随机测试字符串
pub fn generate_test_string() -> String {
    Faker.fake::<String>()
}

/// 测试配置常量
pub const TEST_PORT: u16 = 8080;
pub const TEST_HOST: &str = "127.0.0.1"; 