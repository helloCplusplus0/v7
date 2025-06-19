//! 缓存抽象层
//! 
//! 基于v6设计理念的轻量级缓存抽象，支持内存和Redis缓存

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::RwLock;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::core::result::Result;
use crate::core::error::AppError;

/// 缓存接口
#[async_trait]
pub trait Cache: Send + Sync {
    /// 获取值
    async fn get(&self, key: &str) -> Result<Option<String>>;
    
    /// 设置值
    async fn set(&self, key: &str, value: &str, ttl_seconds: Option<u64>) -> Result<()>;
    
    /// 删除值
    async fn delete(&self, key: &str) -> Result<()>;
    
    /// 检查键是否存在
    async fn exists(&self, key: &str) -> Result<bool>;
    
    /// 清空缓存
    async fn clear(&self) -> Result<()>;
    
    /// 增加计数器
    async fn increment(&self, key: &str, amount: i64) -> Result<i64>;
    
    /// 设置键过期时间
    async fn expire(&self, key: &str, seconds: u64) -> Result<()>;
    
    /// 获取缓存统计信息
    async fn stats(&self) -> Result<CacheStats>;
}

/// 缓存统计信息
#[derive(Debug, Clone)]
pub struct CacheStats {
    pub total_keys: usize,
    pub expired_keys: usize,
    pub memory_usage_bytes: u64,
    pub hit_count: u64,
    pub miss_count: u64,
    pub hit_rate: f64,
}

/// 缓存项（用于内存缓存）
#[derive(Debug, Clone)]
struct CacheItem {
    value: String,
    expires_at: Option<u64>,
    #[allow(dead_code)]
    created_at: u64,
    access_count: u64,
}

impl CacheItem {
    fn new(value: String, ttl_seconds: Option<u64>) -> Self {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
            
        let expires_at = ttl_seconds.map(|ttl| now + ttl);
        
        Self {
            value,
            expires_at,
            created_at: now,
            access_count: 1,
        }
    }
    
    fn is_expired(&self) -> bool {
        if let Some(expires_at) = self.expires_at {
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs();
            now > expires_at
        } else {
            false
        }
    }
    
    fn access(&mut self) {
        self.access_count += 1;
    }
}

/// 内存缓存实现
#[derive(Clone)]
pub struct MemoryCache {
    data: std::sync::Arc<RwLock<HashMap<String, CacheItem>>>,
    hit_count: std::sync::Arc<std::sync::atomic::AtomicU64>,
    miss_count: std::sync::Arc<std::sync::atomic::AtomicU64>,
}

impl MemoryCache {
    pub fn new() -> Self {
        Self {
            data: std::sync::Arc::new(RwLock::new(HashMap::new())),
            hit_count: std::sync::Arc::new(std::sync::atomic::AtomicU64::new(0)),
            miss_count: std::sync::Arc::new(std::sync::atomic::AtomicU64::new(0)),
        }
    }
    
    /// 清理过期键
    fn cleanup_expired(&self) {
        let mut data = self.data.write().unwrap();
        data.retain(|_, item| !item.is_expired());
    }
    
    /// 计算内存使用量
    fn calculate_memory_usage(&self) -> u64 {
        let data = self.data.read().unwrap();
        data.iter().fold(0u64, |acc, (key, item)| {
            acc + key.len() as u64 + item.value.len() as u64 + 64 // 估算结构体开销
        })
    }
}

#[async_trait]
impl Cache for MemoryCache {
    async fn get(&self, key: &str) -> Result<Option<String>> {
        // 先清理过期键
        self.cleanup_expired();
        
        let mut data = self.data.write().unwrap();
        
        if let Some(item) = data.get_mut(key) {
            if item.is_expired() {
                data.remove(key);
                self.miss_count.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                Ok(None)
            } else {
                item.access();
                self.hit_count.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                Ok(Some(item.value.clone()))
            }
        } else {
            self.miss_count.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            Ok(None)
        }
    }
    
    async fn set(&self, key: &str, value: &str, ttl_seconds: Option<u64>) -> Result<()> {
        let mut data = self.data.write().unwrap();
        let item = CacheItem::new(value.to_string(), ttl_seconds);
        data.insert(key.to_string(), item);
        Ok(())
    }
    
    async fn delete(&self, key: &str) -> Result<()> {
        let mut data = self.data.write().unwrap();
        data.remove(key);
        Ok(())
    }
    
    async fn exists(&self, key: &str) -> Result<bool> {
        self.cleanup_expired();
        let data = self.data.read().unwrap();
        
        if let Some(item) = data.get(key) {
            Ok(!item.is_expired())
        } else {
            Ok(false)
        }
    }
    
    async fn clear(&self) -> Result<()> {
        let mut data = self.data.write().unwrap();
        data.clear();
        self.hit_count.store(0, std::sync::atomic::Ordering::Relaxed);
        self.miss_count.store(0, std::sync::atomic::Ordering::Relaxed);
        Ok(())
    }
    
    async fn increment(&self, key: &str, amount: i64) -> Result<i64> {
        let mut data = self.data.write().unwrap();
        
        if let Some(item) = data.get_mut(key) {
            if item.is_expired() {
                data.remove(key);
                return Err(AppError::not_found("键已过期"));
            }
            
            let current_value = item.value.parse::<i64>()
                .map_err(|_| AppError::validation("值不是有效的整数"))?;
            
            let new_value = current_value + amount;
            item.value = new_value.to_string();
            item.access();
            
            Ok(new_value)
        } else {
            // 键不存在，创建新键
            let new_value = amount;
            let item = CacheItem::new(new_value.to_string(), None);
            data.insert(key.to_string(), item);
            Ok(new_value)
        }
    }
    
    async fn expire(&self, key: &str, seconds: u64) -> Result<()> {
        let mut data = self.data.write().unwrap();
        
        if let Some(item) = data.get_mut(key) {
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs();
            item.expires_at = Some(now + seconds);
            Ok(())
        } else {
            Err(AppError::not_found("键不存在"))
        }
    }
    
    async fn stats(&self) -> Result<CacheStats> {
        self.cleanup_expired();
        
        let data = self.data.read().unwrap();
        let total_keys = data.len();
        let memory_usage = self.calculate_memory_usage();
        
        let hit_count = self.hit_count.load(std::sync::atomic::Ordering::Relaxed);
        let miss_count = self.miss_count.load(std::sync::atomic::Ordering::Relaxed);
        
        let total_requests = hit_count + miss_count;
        let hit_rate = if total_requests > 0 {
            hit_count as f64 / total_requests as f64
        } else {
            0.0
        };
        
        Ok(CacheStats {
            total_keys,
            expired_keys: 0, // 在cleanup中已删除
            memory_usage_bytes: memory_usage,
            hit_count,
            miss_count,
            hit_rate,
        })
    }
}

/// 缓存键生成器特性
pub trait CacheKeyGenerator: Send + Sync {
    /// 生成缓存键
    fn generate(&self, prefix: &str, parts: &[&str]) -> String {
        format!("{}:{}", prefix, parts.join(":"))
    }
    
    /// 生成实体缓存键
    fn entity_key(&self, entity_type: &str, id: &str) -> String {
        self.generate(entity_type, &[id])
    }
    
    /// 生成列表缓存键
    fn list_key(&self, entity_type: &str, filter: &str) -> String {
        self.generate(&format!("{}:list", entity_type), &[filter])
    }
    
    /// 生成用户相关缓存键
    fn user_key(&self, user_id: &str, resource: &str) -> String {
        self.generate("user", &[user_id, resource])
    }
    
    /// 生成会话缓存键
    fn session_key(&self, session_id: &str) -> String {
        self.generate("session", &[session_id])
    }
    
    /// 生成权限缓存键
    fn permission_key(&self, user_id: &str, resource: &str, action: &str) -> String {
        self.generate("permission", &[user_id, resource, action])
    }
}

/// 默认缓存键生成器
pub struct DefaultCacheKeyGenerator;

impl CacheKeyGenerator for DefaultCacheKeyGenerator {}

/// 带过期的缓存装饰器
pub struct ExpiringCache<T: Cache> {
    inner: T,
    default_ttl: Option<u64>,
}

impl<T: Cache> ExpiringCache<T> {
    pub fn new(inner: T, default_ttl: Option<u64>) -> Self {
        Self { inner, default_ttl }
    }
}

#[async_trait]
impl<T: Cache> Cache for ExpiringCache<T> {
    async fn get(&self, key: &str) -> Result<Option<String>> {
        self.inner.get(key).await
    }
    
    async fn set(&self, key: &str, value: &str, ttl_seconds: Option<u64>) -> Result<()> {
        let ttl = ttl_seconds.or(self.default_ttl);
        self.inner.set(key, value, ttl).await
    }
    
    async fn delete(&self, key: &str) -> Result<()> {
        self.inner.delete(key).await
    }
    
    async fn exists(&self, key: &str) -> Result<bool> {
        self.inner.exists(key).await
    }
    
    async fn clear(&self) -> Result<()> {
        self.inner.clear().await
    }
    
    async fn increment(&self, key: &str, amount: i64) -> Result<i64> {
        self.inner.increment(key, amount).await
    }
    
    async fn expire(&self, key: &str, seconds: u64) -> Result<()> {
        self.inner.expire(key, seconds).await
    }
    
    async fn stats(&self) -> Result<CacheStats> {
        self.inner.stats().await
    }
}

/// 缓存工厂
pub struct CacheFactory;

impl CacheFactory {
    /// 从配置创建缓存实例
    pub fn create_from_config() -> Result<Box<dyn Cache>> {
        let config = crate::infra::config::config();
        
        if let Some(_redis_url) = config.redis_url() {
            // 如果配置了Redis URL，创建Redis缓存
            // 这里可以实现真实的Redis连接
            tracing::info!("Redis缓存未实现，回退到内存缓存");
            Ok(Box::new(MemoryCache::new()))
        } else {
            // 否则使用内存缓存
            Ok(Box::new(MemoryCache::new()))
        }
    }
    
    /// 创建内存缓存
    pub fn create_memory() -> Box<dyn Cache> {
        Box::new(MemoryCache::new())
    }
    
    /// 创建带默认过期时间的缓存
    pub fn create_expiring(ttl_seconds: u64) -> Box<dyn Cache> {
        let inner = MemoryCache::new();
        Box::new(ExpiringCache::new(inner, Some(ttl_seconds)))
    }
}

/// JSON序列化缓存扩展特性
#[async_trait]
pub trait JsonCache {
    /// 获取并反序列化JSON值
    async fn get_json<T: for<'de> Deserialize<'de>>(&self, key: &str) -> Result<Option<T>>;
    
    /// 序列化并设置JSON值
    async fn set_json<T: Serialize + Sync>(&self, key: &str, value: &T, ttl_seconds: Option<u64>) -> Result<()>;
}

#[async_trait]
impl<C: Cache> JsonCache for C {
    async fn get_json<T: for<'de> Deserialize<'de>>(&self, key: &str) -> Result<Option<T>> {
        if let Some(json_str) = self.get(key).await? {
            let value = serde_json::from_str(&json_str)
                .map_err(|e| AppError::internal(format!("JSON反序列化失败: {}", e)))?;
            Ok(Some(value))
        } else {
            Ok(None)
        }
    }
    
    async fn set_json<T: Serialize + Sync>(&self, key: &str, value: &T, ttl_seconds: Option<u64>) -> Result<()> {
        let json_str = serde_json::to_string(value)
            .map_err(|e| AppError::internal(format!("JSON序列化失败: {}", e)))?;
        self.set(key, &json_str, ttl_seconds).await
    }
}

/// 缓存辅助宏
#[macro_export]
macro_rules! cache_get {
    ($key:expr) => {
        crate::infra::di::inject::<Box<dyn crate::infra::cache::Cache>>().get($key).await
    };
}

#[macro_export]
macro_rules! cache_set {
    ($key:expr, $value:expr) => {
        crate::infra::di::inject::<Box<dyn crate::infra::cache::Cache>>().set($key, $value, None).await
    };
    ($key:expr, $value:expr, $ttl:expr) => {
        crate::infra::di::inject::<Box<dyn crate::infra::cache::Cache>>().set($key, $value, Some($ttl)).await
    };
} 