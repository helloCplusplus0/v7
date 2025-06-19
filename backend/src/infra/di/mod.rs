//! 依赖注入容器
//! 
//! 基于v7设计理念的轻量级DI容器，支持静态分发和Clone trait

use std::any::{Any, TypeId};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};

/// ⭐ v7依赖注入容器 - 简化设计，支持静态分发
pub struct Container {
    singletons: HashMap<TypeId, Arc<dyn Any + Send + Sync>>,
}

impl Container {
    pub fn new() -> Self {
        Self {
            singletons: HashMap::new(),
        }
    }
    
    /// 注册服务实例（支持Clone trait）
    pub fn register<T: 'static + Send + Sync>(&mut self, instance: T) {
        let type_id = TypeId::of::<T>();
        self.singletons.insert(type_id, Arc::new(instance));
    }
    
    /// 解析服务实例（支持Clone trait）
    pub fn resolve<T: 'static + Send + Sync + Clone>(&self) -> Option<T> {
        let type_id = TypeId::of::<T>();
        self.singletons.get(&type_id).and_then(|any| {
            any.downcast_ref::<T>().map(|t| t.clone())
        })
    }
    
    /// 检查服务是否已注册
    pub fn is_registered<T: 'static>(&self) -> bool {
        let type_id = TypeId::of::<T>();
        self.singletons.contains_key(&type_id)
    }
    
    /// 获取容器统计信息
    pub fn stats(&self) -> ContainerStats {
        ContainerStats {
            total_services: self.singletons.len(),
        }
    }
}

/// 容器统计信息
#[derive(Debug)]
pub struct ContainerStats {
    pub total_services: usize,
}

// 全局容器
static CONTAINER: RwLock<Option<Container>> = RwLock::new(None);



/// ⭐ v7核心函数：为静态分发优化的注入函数
pub fn inject<T: 'static + Send + Sync + Clone>() -> T {
    let container = CONTAINER.read().unwrap();
    container.as_ref()
        .and_then(|c| c.resolve::<T>())
        .unwrap_or_else(|| panic!("Service not registered: {}", std::any::type_name::<T>()))
}

/// 尝试注入服务（不抛出错误）
pub fn try_inject<T: 'static + Send + Sync + Clone>() -> Option<T> {
    let container = CONTAINER.read().unwrap();
    container.as_ref().and_then(|c| c.resolve::<T>())
}

/// 注册服务到全局容器
pub fn register<T: 'static + Send + Sync>(instance: T) {
    let mut container = CONTAINER.write().unwrap();
    if container.is_none() {
        *container = Some(Container::new());
    }
    container.as_mut().unwrap().register(instance);
}

/// 检查服务是否已注册
pub fn is_registered<T: 'static>() -> bool {
    let container = CONTAINER.read().unwrap();
    container.as_ref()
        .map(|c| c.is_registered::<T>())
        .unwrap_or(false)
}

/// 获取容器统计信息
pub fn get_stats() -> Option<ContainerStats> {
    let container = CONTAINER.read().unwrap();
    container.as_ref().map(|c| c.stats())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Debug, Clone, PartialEq)]
    struct TestService {
        id: u32,
    }

    impl TestService {
        fn new(id: u32) -> Self {
            Self { id }
        }
        
        fn get_id(&self) -> u32 {
            self.id
        }
    }

    #[test]
    fn test_container_register_and_resolve() {
        let mut container = Container::new();
        let service = TestService::new(42);
        
        container.register(service.clone());
        
        let resolved = container.resolve::<TestService>().unwrap();
        assert_eq!(resolved.get_id(), 42);
    }

    #[test]
    fn test_global_container() {
        let service = TestService::new(123);
        register(service);
        
        let resolved = inject::<TestService>();
        assert_eq!(resolved.get_id(), 123);
        
        assert!(is_registered::<TestService>());
    }

    #[test]
    fn test_try_inject() {
        let service = TestService::new(456);
        register(service);
        
        let resolved = try_inject::<TestService>().unwrap();
        assert_eq!(resolved.get_id(), 456);
        
        // 测试不存在的服务
        let not_found = try_inject::<String>();
        assert!(not_found.is_none());
    }
} 