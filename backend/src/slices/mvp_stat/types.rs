use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// 随机数生成请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerateRandomDataRequest {
    /// 数据量，默认10000
    pub count: Option<u32>,
    /// 随机种子，用于结果重现
    pub seed: Option<u64>,
    /// 数据范围最小值
    pub min_value: Option<f64>,
    /// 数据范围最大值
    pub max_value: Option<f64>,
    /// 分布类型：normal, uniform, exponential
    pub distribution: Option<String>,
}

/// 随机数生成响应
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerateRandomDataResponse {
    /// 生成的随机数据
    pub data: Vec<f64>,
    /// 实际生成的数据量
    pub count: u32,
    /// 使用的种子
    pub seed: u64,
    /// 生成时间戳
    pub generated_at: DateTime<Utc>,
    /// 生成性能信息
    pub performance: PerformanceInfo,
}

/// 统计计算请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CalculateStatisticsRequest {
    /// 要分析的数据
    pub data: Vec<f64>,
    /// 请求的统计量类型
    pub statistics: Vec<String>,
    /// 分位数列表 (0-100)
    pub percentiles: Option<Vec<f64>>,
    /// 是否使用Analytics Engine
    pub use_analytics_engine: Option<bool>,
    /// 是否优先使用Rust实现
    pub prefer_rust: Option<bool>,
}

/// 统计计算响应
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CalculateStatisticsResponse {
    /// 统计结果
    pub results: StatisticsResult,
    /// 计算性能信息
    pub performance: PerformanceInfo,
    /// 使用的实现（rust/python）
    pub implementation: String,
}

/// 综合分析请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComprehensiveAnalysisRequest {
    /// 随机数生成配置
    pub data_config: GenerateRandomDataRequest,
    /// 统计计算配置
    pub stats_config: CalculateStatisticsRequest,
}

/// 综合分析响应
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComprehensiveAnalysisResponse {
    /// 生成的数据信息
    pub data_summary: DataSummary,
    /// 统计计算结果
    pub statistics: StatisticsResult,
    /// 整体性能信息
    pub performance: PerformanceInfo,
    /// 分析时间戳
    pub analyzed_at: DateTime<Utc>,
}

/// 数据摘要
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataSummary {
    /// 数据量
    pub count: u32,
    /// 使用的种子
    pub seed: u64,
    /// 数据范围
    pub range: (f64, f64),
    /// 分布类型
    pub distribution: String,
    /// 数据预览（前10个）
    pub preview: Vec<f64>,
}

/// 统计结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StatisticsResult {
    /// 基础统计量
    pub basic: BasicStatistics,
    /// 分布统计量
    pub distribution: DistributionStatistics,
    /// 分位数统计
    pub percentiles: PercentileInfo,
    /// 形状统计量
    pub shape: ShapeStatistics,
}

/// 基础统计量
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BasicStatistics {
    /// 总数
    pub count: u32,
    /// 总和
    pub sum: f64,
    /// 算术平均值
    pub mean: f64,
    /// 最小值
    pub min: f64,
    /// 最大值
    pub max: f64,
    /// 极差
    pub range: f64,
}

/// 分布统计量
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DistributionStatistics {
    /// 中位数
    pub median: f64,
    /// 众数列表
    pub mode: Vec<f64>,
    /// 方差
    pub variance: f64,
    /// 标准差
    pub std_dev: f64,
    /// 四分位距
    pub iqr: f64,
}

/// 分位数信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PercentileInfo {
    /// Q1 (25th percentile)
    pub q1: f64,
    /// Q2 (50th percentile / median)
    pub q2: f64,
    /// Q3 (75th percentile)  
    pub q3: f64,
    /// 自定义分位数
    pub custom: HashMap<String, f64>,
}

/// 形状统计量
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ShapeStatistics {
    /// 偏度
    pub skewness: f64,
    /// 峰度
    pub kurtosis: f64,
    /// 分布解释
    pub distribution_shape: String,
}

/// 性能信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceInfo {
    /// 执行时间（毫秒）
    pub execution_time_ms: u64,
    /// 内存使用（字节）
    pub memory_usage_bytes: Option<u64>,
    /// 使用的实现
    pub implementation: String,
    /// 额外指标
    pub metrics: HashMap<String, String>,
}

/// MVP统计错误类型
#[derive(Debug, thiserror::Error)]
pub enum StatError {
    #[error("数据验证失败: {message}")]
    Validation { message: String },
    
    #[error("数据为空或无效")]
    EmptyData,
    
    #[error("无效的分布类型: {distribution}")]
    InvalidDistribution { distribution: String },
    
    #[error("无效的分位数值: {percentile}")]
    InvalidPercentile { percentile: f64 },
    
    #[error("Analytics Engine 错误: {message}")]
    AnalyticsEngine { message: String },
    
    #[error("gRPC 通信错误: {message}")]
    Grpc { message: String },
    
    #[error("计算错误: {message}")]
    Calculation { message: String },
    
    #[error("内部错误: {message}")]
    Internal { message: String },
}

/// 统一结果类型
pub type StatResult<T> = Result<T, StatError>;

/// 随机数种子生成器
#[derive(Debug, Clone)]
pub struct SeedGenerator {
    counter: u64,
    base_time: u64,
}

impl SeedGenerator {
    pub fn new() -> Self {
        Self {
            counter: 0,
            base_time: chrono::Utc::now().timestamp_millis() as u64,
        }
    }
    
    pub fn next_seed(&mut self) -> u64 {
        self.counter += 1;
        self.base_time.wrapping_add(self.counter)
    }
}

impl Default for SeedGenerator {
    fn default() -> Self {
        Self::new()
    }
}

/// 请求验证扩展
impl GenerateRandomDataRequest {
    pub fn validate(&self) -> StatResult<()> {
        let count = self.count.unwrap_or(10000);
        if count == 0 || count > 1_000_000 {
            return Err(StatError::Validation {
                message: "数据量必须在1到1,000,000之间".to_string(),
            });
        }
        
        if let (Some(min), Some(max)) = (self.min_value, self.max_value) {
            if min >= max {
                return Err(StatError::Validation {
                    message: "最小值必须小于最大值".to_string(),
                });
            }
        }
        
        if let Some(ref dist) = self.distribution {
            match dist.as_str() {
                "normal" | "uniform" | "exponential" => {},
                _ => return Err(StatError::InvalidDistribution {
                    distribution: dist.clone(),
                }),
            }
        }
        
        Ok(())
    }
}

impl CalculateStatisticsRequest {
    pub fn validate(&self) -> StatResult<()> {
        if self.data.is_empty() {
            return Err(StatError::EmptyData);
        }
        
        if self.data.len() > 10_000_000 {
            return Err(StatError::Validation {
                message: "数据量过大，最多支持10,000,000个数据点".to_string(),
            });
        }
        
        if let Some(ref percentiles) = self.percentiles {
            for &p in percentiles {
                if !(0.0..=100.0).contains(&p) {
                    return Err(StatError::InvalidPercentile { percentile: p });
                }
            }
        }
        
        Ok(())
    }
    
    /// 获取默认统计量列表
    pub fn get_default_statistics() -> Vec<String> {
        vec![
            "mean".to_string(),
            "median".to_string(),
            "mode".to_string(),
            "std".to_string(),
            "variance".to_string(),
            "min".to_string(),
            "max".to_string(),
            "range".to_string(),
            "skewness".to_string(),
            "kurtosis".to_string(),
            "q1".to_string(),
            "q3".to_string(),
            "iqr".to_string(),
        ]
    }
} 