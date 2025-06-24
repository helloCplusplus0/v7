//! 函数注册中心
//!
//! v6架构的核心组件，管理所有暴露函数的元数据和调用路径

use std::collections::HashMap;
use std::sync::RwLock;

/// 函数元数据
#[derive(Debug, Clone)]
pub struct FunctionMetadata {
    /// 函数路径（如 "auth.login"）
    pub fn_path: String,
    /// HTTP路由信息（可选）
    pub http_route: Option<HttpRoute>,
    /// 是否内联优化
    pub inline: bool,
    /// 访问级别
    pub access: AccessLevel,
    /// 函数版本
    pub version: String,
    /// 函数描述
    pub description: Option<String>,
}

/// HTTP路由信息
#[derive(Debug, Clone)]
pub struct HttpRoute {
    /// HTTP方法
    pub method: HttpMethod,
    /// 路径
    pub path: String,
}

/// HTTP方法
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum HttpMethod {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,
}

impl std::str::FromStr for HttpMethod {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_uppercase().as_str() {
            "GET" => Ok(Self::GET),
            "POST" => Ok(Self::POST),
            "PUT" => Ok(Self::PUT),
            "DELETE" => Ok(Self::DELETE),
            "PATCH" => Ok(Self::PATCH),
            "HEAD" => Ok(Self::HEAD),
            "OPTIONS" => Ok(Self::OPTIONS),
            _ => Err(format!("Unknown HTTP method: {s}")),
        }
    }
}

/// 访问级别
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AccessLevel {
    Public,
    Internal,
    Private,
}

impl std::str::FromStr for AccessLevel {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "public" => Ok(Self::Public),
            "internal" => Ok(Self::Internal),
            "private" => Ok(Self::Private),
            _ => Err(format!("Unknown access level: {s}")),
        }
    }
}

/// 函数调用器类型
pub type FunctionCaller = Box<dyn Fn(&[u8]) -> Result<Vec<u8>, String> + Send + Sync>;

/// 函数注册中心
pub struct FunctionRegistry {
    /// 函数元数据映射
    metadata: RwLock<HashMap<String, FunctionMetadata>>,
    /// 函数调用器映射
    callers: RwLock<HashMap<String, FunctionCaller>>,
    /// HTTP路由到函数路径的映射
    http_routes: RwLock<HashMap<String, String>>, // "GET /api/auth/login" -> "auth.login"
}

impl Default for FunctionRegistry {
    fn default() -> Self {
        Self::new()
    }
}

impl FunctionRegistry {
    /// 创建新的注册中心
    #[must_use]
    pub fn new() -> Self {
        Self {
            metadata: RwLock::new(HashMap::new()),
            callers: RwLock::new(HashMap::new()),
            http_routes: RwLock::new(HashMap::new()),
        }
    }

    /// 注册函数
    pub fn register_function(
        &self,
        metadata: FunctionMetadata,
        caller: FunctionCaller,
    ) -> Result<(), String> {
        let fn_path = metadata.fn_path.clone();

        // 注册元数据
        {
            let mut meta_map = self.metadata.write().unwrap();
            if meta_map.contains_key(&fn_path) {
                return Err(format!("Function already registered: {fn_path}"));
            }
            meta_map.insert(fn_path.clone(), metadata.clone());
        }

        // 注册调用器
        {
            let mut caller_map = self.callers.write().unwrap();
            caller_map.insert(fn_path.clone(), caller);
        }

        // 注册HTTP路由（如果有）
        if let Some(ref route) = metadata.http_route {
            let route_key = format!("{:?} {}", route.method, route.path);
            let mut route_map = self.http_routes.write().unwrap();
            route_map.insert(route_key, fn_path.clone());
        }

        Ok(())
    }

    /// 通过函数路径调用函数
    pub fn call_function(&self, fn_path: &str, input: &[u8]) -> Result<Vec<u8>, String> {
        let callers = self.callers.read().unwrap();
        match callers.get(fn_path) {
            Some(caller) => caller(input),
            None => Err(format!("Function not found: {fn_path}")),
        }
    }

    /// 通过HTTP路由查找函数路径
    pub fn find_function_by_route(&self, method: &HttpMethod, path: &str) -> Option<String> {
        let route_key = format!("{method:?} {path}");
        let routes = self.http_routes.read().unwrap();
        routes.get(&route_key).cloned()
    }

    /// 获取函数元数据
    pub fn get_metadata(&self, fn_path: &str) -> Option<FunctionMetadata> {
        let metadata = self.metadata.read().unwrap();
        metadata.get(fn_path).cloned()
    }

    /// 列出所有注册的函数
    pub fn list_functions(&self) -> Vec<String> {
        let metadata = self.metadata.read().unwrap();
        metadata.keys().cloned().collect()
    }

    /// 列出所有HTTP路由
    pub fn list_http_routes(&self) -> Vec<(String, String)> {
        let routes = self.http_routes.read().unwrap();
        routes.iter().map(|(k, v)| (k.clone(), v.clone())).collect()
    }

    /// 获取统计信息
    pub fn stats(&self) -> RegistryStats {
        let metadata = self.metadata.read().unwrap();
        let routes = self.http_routes.read().unwrap();

        RegistryStats {
            total_functions: metadata.len(),
            http_functions: routes.len(),
            public_functions: metadata
                .values()
                .filter(|m| m.access == AccessLevel::Public)
                .count(),
            internal_functions: metadata
                .values()
                .filter(|m| m.access == AccessLevel::Internal)
                .count(),
        }
    }
}

/// 注册中心统计信息
#[derive(Debug, Clone)]
pub struct RegistryStats {
    pub total_functions: usize,
    pub http_functions: usize,
    pub public_functions: usize,
    pub internal_functions: usize,
}

/// 全局函数注册中心
static GLOBAL_REGISTRY: std::sync::LazyLock<FunctionRegistry> =
    std::sync::LazyLock::new(FunctionRegistry::new);

/// 获取全局注册中心
#[must_use]
pub fn global_registry() -> &'static FunctionRegistry {
    &GLOBAL_REGISTRY
}

/// 注册函数到全局注册中心
pub fn register_global_function(
    metadata: FunctionMetadata,
    caller: FunctionCaller,
) -> Result<(), String> {
    global_registry().register_function(metadata, caller)
}

/// 通过函数路径调用全局函数
pub fn call_global_function(fn_path: &str, input: &[u8]) -> Result<Vec<u8>, String> {
    global_registry().call_function(fn_path, input)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_function_registration() {
        let registry = FunctionRegistry::new();

        let metadata = FunctionMetadata {
            fn_path: "test.hello".to_string(),
            http_route: Some(HttpRoute {
                method: HttpMethod::GET,
                path: "/api/hello".to_string(),
            }),
            inline: true,
            access: AccessLevel::Public,
            version: "1.0.0".to_string(),
            description: Some("Test function".to_string()),
        };

        let caller =
            Box::new(|_input: &[u8]| -> Result<Vec<u8>, String> { Ok(b"Hello, World!".to_vec()) });

        assert!(registry.register_function(metadata, caller).is_ok());

        // 测试调用
        let result = registry.call_function("test.hello", b"").unwrap();
        assert_eq!(result, b"Hello, World!");

        // 测试路由查找
        let fn_path = registry.find_function_by_route(&HttpMethod::GET, "/api/hello");
        assert_eq!(fn_path, Some("test.hello".to_string()));
    }

    #[test]
    fn test_registry_stats() {
        let registry = FunctionRegistry::new();

        let metadata1 = FunctionMetadata {
            fn_path: "test.public".to_string(),
            http_route: Some(HttpRoute {
                method: HttpMethod::POST,
                path: "/api/public".to_string(),
            }),
            inline: false,
            access: AccessLevel::Public,
            version: "1.0.0".to_string(),
            description: None,
        };

        let metadata2 = FunctionMetadata {
            fn_path: "test.internal".to_string(),
            http_route: None,
            inline: true,
            access: AccessLevel::Internal,
            version: "1.0.0".to_string(),
            description: None,
        };

        let dummy_caller1 = Box::new(|_: &[u8]| Ok(Vec::new()));
        let dummy_caller2 = Box::new(|_: &[u8]| Ok(Vec::new()));

        registry
            .register_function(metadata1, dummy_caller1)
            .unwrap();
        registry
            .register_function(metadata2, dummy_caller2)
            .unwrap();

        let stats = registry.stats();
        assert_eq!(stats.total_functions, 2);
        assert_eq!(stats.http_functions, 1);
        assert_eq!(stats.public_functions, 1);
        assert_eq!(stats.internal_functions, 1);
    }
}
