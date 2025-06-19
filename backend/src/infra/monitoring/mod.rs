//! 监控与日志模块
//! 
//! 基于v6设计理念的轻量级监控与日志，支持分布式追踪

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use uuid::Uuid;
use serde::{Deserialize, Serialize};

// use crate::core::result::Result; // 暂时注释，后续实现时使用
// use crate::core::error::AppError; // 暂时注释，后续实现时使用

/// 日志级别
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum LogLevel {
    Trace,
    Debug,
    Info,
    Warn,
    Error,
}

impl LogLevel {
    /// 从字符串解析日志级别
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "trace" => Some(Self::Trace),
            "debug" => Some(Self::Debug),
            "info" => Some(Self::Info),
            "warn" | "warning" => Some(Self::Warn),
            "error" => Some(Self::Error),
            _ => None,
        }
    }

    /// 转换为字符串
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Trace => "trace",
            Self::Debug => "debug",
            Self::Info => "info",
            Self::Warn => "warn",
            Self::Error => "error",
        }
    }
}

/// 结构化日志条目
#[derive(Debug, Clone, Serialize)]
pub struct LogEntry {
    /// 时间戳
    pub timestamp: i64,
    /// 日志级别
    pub level: LogLevel,
    /// 日志消息
    pub message: String,
    /// 追踪ID（改进：分布式追踪支持）
    pub trace_id: Option<String>,
    /// 关联ID
    pub correlation_id: Option<String>,
    /// 用户ID
    pub user_id: Option<String>,
    /// 请求ID
    pub request_id: Option<String>,
    /// 组件/模块名称
    pub component: Option<String>,
    /// 文件名
    pub file: Option<String>,
    /// 行号
    pub line: Option<u32>,
    /// 附加字段
    pub fields: HashMap<String, serde_json::Value>,
}

impl LogEntry {
    /// 创建新的日志条目
    #[must_use]
    pub fn new(level: LogLevel, message: String) -> Self {
        Self {
            timestamp: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_millis() as i64,
            level,
            message,
            trace_id: None,
            correlation_id: None,
            user_id: None,
            request_id: None,
            component: None,
            file: None,
            line: None,
            fields: HashMap::new(),
        }
    }

    /// 设置追踪ID
    #[must_use]
    pub fn with_trace_id(mut self, trace_id: String) -> Self {
        self.trace_id = Some(trace_id);
        self
    }

    /// 设置关联ID
    #[must_use]
    pub fn with_correlation_id(mut self, correlation_id: String) -> Self {
        self.correlation_id = Some(correlation_id);
        self
    }

    /// 设置用户ID
    #[must_use]
    pub fn with_user_id(mut self, user_id: String) -> Self {
        self.user_id = Some(user_id);
        self
    }

    /// 设置请求ID
    #[must_use]
    pub fn with_request_id(mut self, request_id: String) -> Self {
        self.request_id = Some(request_id);
        self
    }

    /// 设置组件名称
    #[must_use]
    pub fn with_component(mut self, component: String) -> Self {
        self.component = Some(component);
        self
    }

    /// 设置位置信息
    #[must_use]
    pub fn with_location(mut self, file: String, line: u32) -> Self {
        self.file = Some(file);
        self.line = Some(line);
        self
    }

    /// 添加字段
    #[must_use]
    pub fn with_field<T: Serialize>(mut self, key: &str, value: T) -> Self {
        if let Ok(json_value) = serde_json::to_value(value) {
            self.fields.insert(key.to_string(), json_value);
        }
        self
    }
}

/// 日志记录器接口
pub trait Logger: Send + Sync {
    /// 记录日志
    fn log(&self, entry: LogEntry);
    
    /// 记录追踪日志
    fn trace(&self, message: &str);
    
    /// 记录调试日志
    fn debug(&self, message: &str);
    
    /// 记录信息日志
    fn info(&self, message: &str);
    
    /// 记录警告日志
    fn warn(&self, message: &str);
    
    /// 记录错误日志
    fn error(&self, message: &str);
    
    /// 设置最小日志级别
    fn set_level(&mut self, level: LogLevel);
    
    /// 检查是否应该记录指定级别的日志
    fn should_log(&self, level: LogLevel) -> bool;
}

/// 简单控制台日志记录器
pub struct ConsoleLogger {
    min_level: LogLevel,
}

impl ConsoleLogger {
    #[must_use]
    pub fn new(min_level: LogLevel) -> Self {
        Self { min_level }
    }
}

impl Logger for ConsoleLogger {
    fn log(&self, entry: LogEntry) {
        if entry.level >= self.min_level {
            // 简化的控制台输出
            let timestamp = chrono::DateTime::from_timestamp_millis(entry.timestamp)
                .unwrap_or_else(|| chrono::Utc::now())
                .format("%Y-%m-%d %H:%M:%S");
            
            let mut output = format!("[{}] [{}] {}", timestamp, entry.level.as_str().to_uppercase(), entry.message);
            
            // 添加追踪信息
            if let Some(trace_id) = &entry.trace_id {
                output.push_str(&format!(" [trace_id={}]", trace_id));
            }
            
            if let Some(correlation_id) = &entry.correlation_id {
                output.push_str(&format!(" [correlation_id={}]", correlation_id));
            }
            
            // 添加位置信息
            if let (Some(file), Some(line)) = (&entry.file, entry.line) {
                output.push_str(&format!(" [{}:{}]", file, line));
            }
            
            println!("{}", output);
        }
    }
    
    fn trace(&self, message: &str) {
        self.log(LogEntry::new(LogLevel::Trace, message.to_string()));
    }
    
    fn debug(&self, message: &str) {
        self.log(LogEntry::new(LogLevel::Debug, message.to_string()));
    }
    
    fn info(&self, message: &str) {
        self.log(LogEntry::new(LogLevel::Info, message.to_string()));
    }
    
    fn warn(&self, message: &str) {
        self.log(LogEntry::new(LogLevel::Warn, message.to_string()));
    }
    
    fn error(&self, message: &str) {
        self.log(LogEntry::new(LogLevel::Error, message.to_string()));
    }
    
    fn set_level(&mut self, level: LogLevel) {
        self.min_level = level;
    }
    
    fn should_log(&self, level: LogLevel) -> bool {
        level >= self.min_level
    }
}

/// 性能指标类型
#[derive(Debug, Clone, Serialize)]
pub enum MetricType {
    /// 计数器（累计值）
    Counter,
    /// 仪表（瞬时值）
    Gauge,
    /// 直方图（分布统计）
    Histogram,
    /// 计时器（耗时统计）
    Timer,
}

/// 性能指标
#[derive(Debug, Clone, Serialize)]
pub struct Metric {
    /// 指标名称
    pub name: String,
    /// 指标类型
    pub metric_type: MetricType,
    /// 指标值
    pub value: f64,
    /// 时间戳
    pub timestamp: i64,
    /// 标签
    pub labels: HashMap<String, String>,
    /// 描述
    pub description: Option<String>,
}

impl Metric {
    /// 创建计数器指标
    #[must_use]
    pub fn counter(name: &str, value: f64) -> Self {
        Self {
            name: name.to_string(),
            metric_type: MetricType::Counter,
            value,
            timestamp: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_millis() as i64,
            labels: HashMap::new(),
            description: None,
        }
    }

    /// 创建仪表指标
    #[must_use]
    pub fn gauge(name: &str, value: f64) -> Self {
        Self {
            name: name.to_string(),
            metric_type: MetricType::Gauge,
            value,
            timestamp: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_millis() as i64,
            labels: HashMap::new(),
            description: None,
        }
    }

    /// 添加标签
    #[must_use]
    pub fn with_label(mut self, key: &str, value: &str) -> Self {
        self.labels.insert(key.to_string(), value.to_string());
        self
    }

    /// 添加描述
    #[must_use]
    pub fn with_description(mut self, description: &str) -> Self {
        self.description = Some(description.to_string());
        self
    }
}

/// 指标收集器接口
pub trait MetricsCollector: Send + Sync {
    /// 记录指标
    fn record(&self, metric: Metric);
    
    /// 增加计数器
    fn increment_counter(&self, name: &str, value: f64);
    
    /// 设置仪表值
    fn set_gauge(&self, name: &str, value: f64);
    
    /// 记录计时器
    fn record_timer(&self, name: &str, duration: Duration);
    
    /// 获取所有指标
    fn get_metrics(&self) -> Vec<Metric>;
    
    /// 清除指标
    fn clear(&self);
}

/// 内存指标收集器
pub struct MemoryMetricsCollector {
    metrics: Arc<Mutex<Vec<Metric>>>,
}

impl Default for MemoryMetricsCollector {
    fn default() -> Self {
        Self::new()
    }
}

impl MemoryMetricsCollector {
    #[must_use]
    pub fn new() -> Self {
        Self {
            metrics: Arc::new(Mutex::new(Vec::new())),
        }
    }
}

impl MetricsCollector for MemoryMetricsCollector {
    fn record(&self, metric: Metric) {
        let mut metrics = self.metrics.lock().unwrap();
        metrics.push(metric);
    }
    
    fn increment_counter(&self, name: &str, value: f64) {
        self.record(Metric::counter(name, value));
    }
    
    fn set_gauge(&self, name: &str, value: f64) {
        self.record(Metric::gauge(name, value));
    }
    
    fn record_timer(&self, name: &str, duration: Duration) {
        let value = duration.as_secs_f64();
        self.record(Metric {
            name: name.to_string(),
            metric_type: MetricType::Timer,
            value,
            timestamp: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_millis() as i64,
            labels: HashMap::new(),
            description: None,
        });
    }
    
    fn get_metrics(&self) -> Vec<Metric> {
        let metrics = self.metrics.lock().unwrap();
        metrics.clone()
    }
    
    fn clear(&self) {
        let mut metrics = self.metrics.lock().unwrap();
        metrics.clear();
    }
}

/// 追踪上下文（改进：分布式追踪支持）
#[derive(Debug, Clone)]
pub struct TraceContext {
    /// 追踪ID
    pub trace_id: String,
    /// 当前span ID
    pub span_id: String,
    /// 父span ID
    pub parent_span_id: Option<String>,
    /// 采样标志
    pub sampled: bool,
    /// 追踪状态
    pub flags: u8,
}

impl Default for TraceContext {
    fn default() -> Self {
        Self::new()
    }
}

impl TraceContext {
    /// 创建新的追踪上下文
    #[must_use]
    pub fn new() -> Self {
        Self {
            trace_id: Uuid::new_v4().to_string(),
            span_id: Uuid::new_v4().to_string(),
            parent_span_id: None,
            sampled: true,
            flags: 0,
        }
    }

    /// 创建子span
    #[must_use]
    pub fn child_span(&self) -> Self {
        Self {
            trace_id: self.trace_id.clone(),
            span_id: Uuid::new_v4().to_string(),
            parent_span_id: Some(self.span_id.clone()),
            sampled: self.sampled,
            flags: self.flags,
        }
    }

    /// 从HTTP头解析追踪上下文
    #[must_use]
    pub fn from_headers(headers: &HashMap<String, String>) -> Option<Self> {
        let trace_id = headers.get("x-trace-id")?.clone();
        let span_id = headers.get("x-span-id").cloned().unwrap_or_else(|| Uuid::new_v4().to_string());
        let parent_span_id = headers.get("x-parent-span-id").cloned();
        
        Some(Self {
            trace_id,
            span_id,
            parent_span_id,
            sampled: true,
            flags: 0,
        })
    }

    /// 转换为HTTP头
    #[must_use]
    pub fn to_headers(&self) -> HashMap<String, String> {
        let mut headers = HashMap::new();
        headers.insert("x-trace-id".to_string(), self.trace_id.clone());
        headers.insert("x-span-id".to_string(), self.span_id.clone());
        if let Some(parent_span_id) = &self.parent_span_id {
            headers.insert("x-parent-span-id".to_string(), parent_span_id.clone());
        }
        headers
    }
}

/// 性能计时器
pub struct Timer {
    start: Instant,
    name: String,
}

impl Timer {
    /// 开始计时
    #[must_use]
    pub fn start(name: &str) -> Self {
        Self {
            start: Instant::now(),
            name: name.to_string(),
        }
    }

    /// 停止计时并记录
    pub fn stop(self) -> Duration {
        let duration = self.start.elapsed();
        
        // 记录到指标收集器
        if let Ok(collector_guard) = GLOBAL_METRICS.try_lock() {
            if let Some(ref collector) = *collector_guard {
                collector.record_timer(&self.name, duration);
            }
        }
        
        duration
    }
}

/// 全局日志记录器
static GLOBAL_LOGGER: std::sync::LazyLock<Arc<Mutex<Box<dyn Logger>>>> = 
    std::sync::LazyLock::new(|| {
        let config = crate::infra::config::config();
        let level = LogLevel::from_str(&config.log_level()).unwrap_or(LogLevel::Info);
        Arc::new(Mutex::new(Box::new(ConsoleLogger::new(level))))
    });

/// 全局指标收集器
static GLOBAL_METRICS: std::sync::LazyLock<Arc<Mutex<Option<Box<dyn MetricsCollector>>>>> = 
    std::sync::LazyLock::new(|| {
        Arc::new(Mutex::new(Some(Box::new(MemoryMetricsCollector::new()))))
    });

/// 获取全局日志记录器
pub fn logger() -> Arc<Mutex<Box<dyn Logger>>> {
    GLOBAL_LOGGER.clone()
}

/// 获取全局指标收集器
pub fn metrics() -> Arc<Mutex<Option<Box<dyn MetricsCollector>>>> {
    GLOBAL_METRICS.clone()
}

/// 日志便利宏
#[macro_export]
macro_rules! log_trace {
    ($msg:expr) => {
        if let Ok(logger) = crate::infra::monitoring::logger().try_lock() {
            logger.trace($msg);
        }
    };
    ($msg:expr, $($field:expr),*) => {
        if let Ok(logger) = crate::infra::monitoring::logger().try_lock() {
            let mut entry = crate::infra::monitoring::LogEntry::new(
                crate::infra::monitoring::LogLevel::Trace,
                $msg.to_string()
            );
            $(entry = entry.with_field(stringify!($field), $field);)*
            logger.log(entry);
        }
    };
}

#[macro_export]
macro_rules! log_info {
    ($msg:expr) => {
        if let Ok(logger) = crate::infra::monitoring::logger().try_lock() {
            logger.info($msg);
        }
    };
    ($msg:expr, trace_id = $trace_id:expr) => {
        if let Ok(logger) = crate::infra::monitoring::logger().try_lock() {
            let entry = crate::infra::monitoring::LogEntry::new(
                crate::infra::monitoring::LogLevel::Info,
                $msg.to_string()
            ).with_trace_id($trace_id);
            logger.log(entry);
        }
    };
}

#[macro_export]
macro_rules! log_error {
    ($msg:expr) => {
        if let Ok(logger) = crate::infra::monitoring::logger().try_lock() {
            logger.error($msg);
        }
    };
    ($msg:expr, trace_id = $trace_id:expr) => {
        if let Ok(logger) = crate::infra::monitoring::logger().try_lock() {
            let entry = crate::infra::monitoring::LogEntry::new(
                crate::infra::monitoring::LogLevel::Error,
                $msg.to_string()
            ).with_trace_id($trace_id);
            logger.log(entry);
        }
    };
}

/// 指标便利宏
#[macro_export]
macro_rules! metric_counter {
    ($name:expr, $value:expr) => {
        if let Ok(metrics) = crate::infra::monitoring::metrics().try_lock() {
            if let Some(ref collector) = *metrics {
                collector.increment_counter($name, $value);
            }
        }
    };
}

#[macro_export]
macro_rules! metric_gauge {
    ($name:expr, $value:expr) => {
        if let Ok(metrics) = crate::infra::monitoring::metrics().try_lock() {
            if let Some(ref collector) = *metrics {
                collector.set_gauge($name, $value);
            }
        }
    };
}

/// 计时器便利宏
#[macro_export]
macro_rules! time_block {
    ($name:expr, $block:block) => {{
        let timer = crate::infra::monitoring::Timer::start($name);
        let result = $block;
        timer.stop();
        result
    }};
} 