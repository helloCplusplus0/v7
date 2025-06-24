//! 功能切片注册表
//!
//! 负责管理所有功能切片的注册、路由配置和服务初始化

use axum::Router;
use std::collections::HashMap;

/// 切片注册表
pub struct SliceRegistry {
    slices: HashMap<String, SliceConfig>,
}

/// 切片配置
#[derive(Debug, Clone)]
pub struct SliceConfig {
    pub name: String,
    pub version: String,
    pub enabled: bool,
    pub routes: Vec<String>,
}

impl SliceRegistry {
    /// 创建新的切片注册表
    #[must_use]
    pub fn new() -> Self {
        Self {
            slices: HashMap::new(),
        }
    }

    /// 注册新的功能切片
    pub fn register_slice(&mut self, config: SliceConfig) {
        self.slices.insert(config.name.clone(), config);
    }

    /// 获取所有已启用的切片
    #[must_use]
    pub fn enabled_slices(&self) -> Vec<&SliceConfig> {
        self.slices.values().filter(|slice| slice.enabled).collect()
    }

    /// 构建应用路由
    pub fn build_routes(&self) -> Router {
        // 这里将来会添加各个切片的路由
        // 例如：app = app.nest("/api/v1/hello", hello_slice_routes());

        Router::new()
    }

    /// 获取切片信息
    #[must_use]
    pub fn get_slice(&self, name: &str) -> Option<&SliceConfig> {
        self.slices.get(name)
    }

    /// 列出所有切片名称
    #[must_use]
    pub fn list_slice_names(&self) -> Vec<&String> {
        self.slices.keys().collect()
    }
}

impl Default for SliceRegistry {
    fn default() -> Self {
        Self::new()
    }
}

/// 初始化默认的切片注册表
#[must_use]
pub fn initialize_slice_registry() -> SliceRegistry {
    // 这里将来会注册各个功能切片
    // 例如：
    // registry.register_slice(SliceConfig {
    //     name: "hello_fmod".to_string(),
    //     version: "1.0.0".to_string(),
    //     enabled: true,
    //     routes: vec!["/hello".to_string(), "/fmod".to_string()],
    // });

    SliceRegistry::new()
}
