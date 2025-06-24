//! 配置管理系统
//!
//! 基于v6设计理念的轻量级配置管理，支持环境检测和类型安全配置

use serde::Deserialize;
use std::collections::HashMap;
use std::sync::RwLock;

use crate::core::error::AppError;
use crate::core::result::Result;

/// 配置监听器类型别名
type ConfigWatcher = Box<dyn Fn(&str, &ConfigValue) + Send + Sync>;

/// 应用环境
#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Environment {
    Development,
    Test,
    Staging,
    Production,
}

impl Environment {
    /// 从环境变量检测环境
    #[must_use]
    pub fn from_env() -> Self {
        let env_var = std::env::var("APP_ENV")
            .or_else(|_| std::env::var("RUST_ENV"))
            .unwrap_or_else(|_| "development".to_string());

        match env_var.to_lowercase().as_str() {
            "production" | "prod" => Self::Production,
            "staging" => Self::Staging,
            "test" => Self::Test,
            _ => Self::Development,
        }
    }

    /// 判断是否为生产环境
    #[must_use]
    pub fn is_production(&self) -> bool {
        *self == Self::Production
    }

    /// 判断是否为开发环境
    #[must_use]
    pub fn is_development(&self) -> bool {
        *self == Self::Development
    }

    /// 判断是否为测试环境
    #[must_use]
    pub fn is_test(&self) -> bool {
        *self == Self::Test
    }

    /// 获取环境名称
    #[must_use]
    pub fn name(&self) -> &'static str {
        match self {
            Self::Development => "development",
            Self::Test => "test",
            Self::Staging => "staging",
            Self::Production => "production",
        }
    }
}

/// 配置值类型
#[derive(Debug, Clone)]
pub enum ConfigValue {
    String(String),
    Int(i64),
    Float(f64),
    Bool(bool),
    Array(Vec<ConfigValue>),
}

impl ConfigValue {
    /// 转换为字符串
    #[must_use]
    pub fn as_string(&self) -> Option<String> {
        match self {
            ConfigValue::String(s) => Some(s.clone()),
            _ => None,
        }
    }

    /// 转换为整数
    #[must_use]
    pub fn as_int(&self) -> Option<i64> {
        match self {
            ConfigValue::Int(i) => Some(*i),
            ConfigValue::String(s) => s.parse().ok(),
            _ => None,
        }
    }

    /// 转换为浮点数
    #[must_use]
    pub fn as_float(&self) -> Option<f64> {
        match self {
            ConfigValue::Float(f) => Some(*f),
            ConfigValue::String(s) => s.parse().ok(),
            _ => None,
        }
    }

    /// 转换为布尔值
    #[must_use]
    pub fn as_bool(&self) -> Option<bool> {
        match self {
            ConfigValue::Bool(b) => Some(*b),
            ConfigValue::String(s) => match s.to_lowercase().as_str() {
                "true" | "1" | "yes" | "on" => Some(true),
                "false" | "0" | "no" | "off" => Some(false),
                _ => None,
            },
            _ => None,
        }
    }
}

/// 配置管理器
pub struct Config {
    environment: Environment,
    values: RwLock<HashMap<String, ConfigValue>>,
    watchers: RwLock<Vec<ConfigWatcher>>,
}

impl Config {
    /// 创建新配置
    #[must_use]
    pub fn new(environment: Environment) -> Self {
        Self {
            environment,
            values: RwLock::new(HashMap::new()),
            watchers: RwLock::new(Vec::new()),
        }
    }

    /// 从环境变量创建配置
    #[must_use]
    pub fn from_env() -> Self {
        let environment = Environment::from_env();
        let config = Self::new(environment);

        // 加载.env文件（如果存在）
        if let Ok(env_path) = std::env::var("ENV_FILE") {
            if let Err(e) = dotenv::from_path(&env_path) {
                eprintln!("Warning: Failed to load .env file: {e}");
            }
        } else if environment.is_development() {
            let _ = dotenv::dotenv(); // 尝试加载.env文件
        }

        config
    }

    /// 获取环境
    pub fn environment(&self) -> Environment {
        self.environment
    }

    /// 获取配置值
    pub fn get(&self, key: &str) -> Option<ConfigValue> {
        // 先尝试从内存缓存获取
        if let Some(value) = self.values.read().unwrap().get(key) {
            return Some(value.clone());
        }

        // 再尝试从环境变量获取
        if let Ok(env_value) = std::env::var(key) {
            let config_value = ConfigValue::String(env_value.clone());

            // 缓存结果
            self.values
                .write()
                .unwrap()
                .insert(key.to_string(), config_value.clone());
            return Some(config_value);
        }

        None
    }

    /// 获取字符串值
    pub fn get_string(&self, key: &str) -> Option<String> {
        self.get(key)?.as_string()
    }

    /// 获取带默认值的字符串
    pub fn get_string_or(&self, key: &str, default: &str) -> String {
        self.get_string(key).unwrap_or_else(|| default.to_string())
    }

    /// 获取整数值
    pub fn get_int(&self, key: &str) -> Option<i64> {
        self.get(key)?.as_int()
    }

    /// 获取带默认值的整数
    pub fn get_int_or(&self, key: &str, default: i64) -> i64 {
        self.get_int(key).unwrap_or(default)
    }

    /// 获取浮点值
    pub fn get_float(&self, key: &str) -> Option<f64> {
        self.get(key)?.as_float()
    }

    /// 获取布尔值
    pub fn get_bool(&self, key: &str) -> Option<bool> {
        self.get(key)?.as_bool()
    }

    /// 获取带默认值的布尔值
    pub fn get_bool_or(&self, key: &str, default: bool) -> bool {
        self.get_bool(key).unwrap_or(default)
    }

    /// 设置配置值（改进：支持运行时配置更新）
    pub fn set(&self, key: &str, value: ConfigValue) {
        self.values
            .write()
            .unwrap()
            .insert(key.to_string(), value.clone());

        // 通知所有观察者
        let watchers = self.watchers.read().unwrap();
        for watcher in watchers.iter() {
            watcher(key, &value);
        }
    }

    /// 添加配置变更观察者（改进：支持热更新）
    pub fn add_watcher<F>(&self, watcher: F)
    where
        F: Fn(&str, &ConfigValue) + Send + Sync + 'static,
    {
        self.watchers.write().unwrap().push(Box::new(watcher));
    }

    /// 获取数据库URL
    pub fn database_url(&self) -> String {
        self.get_string("DATABASE_URL")
            .or_else(|| self.get_string("database_url"))
            .unwrap_or_else(|| {
                if self.environment.is_production() {
                    "postgresql://localhost/prod_db".to_string()
                } else {
                    "sqlite:./backend/data/dev.db".to_string()
                }
            })
    }

    /// 获取服务端口
    pub fn port(&self) -> u16 {
        let port_value = self
            .get_int("PORT")
            .or_else(|| self.get_int("port"))
            .unwrap_or(if self.environment.is_production() {
                8080
            } else {
                3000
            });

        u16::try_from(port_value.max(0)).unwrap_or(3000)
    }

    /// 获取服务器主机地址
    pub fn host(&self) -> String {
        self.get_string_or(
            "HOST",
            if self.environment.is_production() {
                "0.0.0.0"
            } else {
                "127.0.0.1"
            },
        )
    }

    /// 获取Redis URL
    pub fn redis_url(&self) -> Option<String> {
        self.get_string("REDIS_URL")
    }

    /// 获取JWT密钥
    pub fn jwt_secret(&self) -> String {
        self.get_string("JWT_SECRET").unwrap_or_else(|| {
            if self.environment.is_production() {
                panic!("JWT_SECRET must be set in production");
            } else {
                "dev-secret-key".to_string()
            }
        })
    }

    /// 获取日志级别
    pub fn log_level(&self) -> String {
        self.get_string_or(
            "LOG_LEVEL",
            match self.environment {
                Environment::Development => "debug",
                Environment::Test => "warn",
                Environment::Staging | Environment::Production => "info",
            },
        )
    }

    /// 检查功能开关是否启用
    pub fn feature_enabled(&self, feature: &str) -> bool {
        let key = format!("FEATURE_{}", feature.to_uppercase());
        self.get_bool_or(&key, false)
    }

    /// 验证配置完整性（改进：配置验证）
    pub fn validate(&self) -> Result<()> {
        // 检查生产环境必需的配置
        if self.environment.is_production() {
            if self.get_string("JWT_SECRET").is_none() {
                return Err(Box::new(AppError::validation(
                    "生产环境必须设置 JWT_SECRET",
                )));
            }

            if self.get_string("DATABASE_URL").is_none() {
                return Err(Box::new(AppError::validation(
                    "生产环境必须设置 DATABASE_URL",
                )));
            }
        }

        // 验证端口范围
        let port = self.port();
        if port == 0 {
            return Err(Box::new(AppError::validation(format!(
                "无效的端口号: {port}"
            ))));
        }

        Ok(())
    }

    /// 获取所有配置（用于调试）
    pub fn dump(&self) -> HashMap<String, ConfigValue> {
        self.values.read().unwrap().clone()
    }
}

/// 全局配置实例
static GLOBAL_CONFIG: std::sync::LazyLock<Config> = std::sync::LazyLock::new(Config::from_env);

/// 获取全局配置
#[must_use]
pub fn config() -> &'static Config {
    &GLOBAL_CONFIG
}

/// 配置辅助宏
#[macro_export]
macro_rules! config_get {
    ($key:expr) => {
        $crate::infra::config::config().get_string($key)
    };
    ($key:expr, $default:expr) => {
        $crate::infra::config::config().get_string_or($key, $default)
    };
}

/// 配置验证宏
#[macro_export]
macro_rules! require_config {
    ($key:expr) => {
        $crate::infra::config::config()
            .get_string($key)
            .ok_or_else(|| {
                $crate::core::error::AppError::validation(format!("缺少必需的配置: {}", $key))
            })?
    };
}
