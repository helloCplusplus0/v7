//! 基础集成测试
//!
//! 测试基本的切片注册和功能

use fmod_slice::slices::registry::{SliceConfig, SliceRegistry};

#[test]
fn test_slice_registry_creation() {
    let registry = SliceRegistry::new();
    assert_eq!(registry.list_slice_names().len(), 0);
}

#[test]
fn test_slice_registration() {
    let mut registry = SliceRegistry::new();

    let config = SliceConfig {
        name: "test_slice".to_string(),
        version: "1.0.0".to_string(),
        enabled: true,
        routes: vec!["/api/test".to_string()],
    };

    registry.register_slice(config);

    assert_eq!(registry.list_slice_names().len(), 1);
    assert!(registry.get_slice("test_slice").is_some());
}

#[test]
fn test_enabled_slices_filter() {
    let mut registry = SliceRegistry::new();

    // 注册启用的切片
    registry.register_slice(SliceConfig {
        name: "enabled_slice".to_string(),
        version: "1.0.0".to_string(),
        enabled: true,
        routes: vec!["/api/enabled".to_string()],
    });

    // 注册禁用的切片
    registry.register_slice(SliceConfig {
        name: "disabled_slice".to_string(),
        version: "1.0.0".to_string(),
        enabled: false,
        routes: vec!["/api/disabled".to_string()],
    });

    let enabled_slices = registry.enabled_slices();
    assert_eq!(enabled_slices.len(), 1);
    assert_eq!(enabled_slices[0].name, "enabled_slice");
}

#[test]
fn test_route_building() {
    let registry = SliceRegistry::new();
    let _router = registry.build_routes();

    // 基本测试：确保路由器可以创建
    // 实际的路由测试应该在web_test.rs中进行
    // 使用_router前缀表示这是有意的未使用变量
}
