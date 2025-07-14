use super::types::{
    GenerateRandomDataRequest, GenerateRandomDataResponse,
    CalculateStatisticsRequest, CalculateStatisticsResponse,
    ComprehensiveAnalysisRequest, ComprehensiveAnalysisResponse,
    StatResult,
};
use async_trait::async_trait;

/// ⭐ v7统计服务接口 - 必须支持Clone以实现静态分发
#[async_trait]
pub trait StatisticsService: Send + Sync + Clone {
    /// 生成随机数据
    async fn generate_random_data(&self, req: GenerateRandomDataRequest) -> StatResult<GenerateRandomDataResponse>;
    
    /// 计算统计量
    async fn calculate_statistics(&self, req: CalculateStatisticsRequest) -> StatResult<CalculateStatisticsResponse>;
    
    /// 综合分析（生成数据+计算统计量）
    async fn comprehensive_analysis(&self, req: ComprehensiveAnalysisRequest) -> StatResult<ComprehensiveAnalysisResponse>;
}

/// ⭐ v7随机数生成器接口 - 必须支持Clone以实现静态分发
#[async_trait]
pub trait RandomDataGenerator: Send + Sync + Clone {
    /// 生成均匀分布随机数
    async fn generate_uniform(&self, count: u32, seed: u64, min: f64, max: f64) -> StatResult<Vec<f64>>;
    
    /// 生成正态分布随机数
    async fn generate_normal(&self, count: u32, seed: u64, mean: f64, std_dev: f64) -> StatResult<Vec<f64>>;
    
    /// 生成指数分布随机数
    async fn generate_exponential(&self, count: u32, seed: u64, lambda: f64) -> StatResult<Vec<f64>>;
    
    /// 获取性能信息
    fn get_performance_metrics(&self) -> std::collections::HashMap<String, String>;
}

/// ⭐ v7分析引擎客户端接口 - 必须支持Clone以实现静态分发
#[async_trait]
pub trait AnalyticsClient: Send + Sync + Clone {
    /// 调用Analytics Engine进行统计计算
    async fn calculate_statistics(
        &self, 
        algorithm: &str, 
        data: &[f64], 
        parameters: std::collections::HashMap<String, String>
    ) -> StatResult<serde_json::Value>;
    
    /// 批量调用多个算法
    async fn batch_calculate(
        &self,
        requests: Vec<(String, Vec<f64>, std::collections::HashMap<String, String>)>
    ) -> StatResult<Vec<serde_json::Value>>;
    
    /// 检查Analytics Engine健康状态
    async fn health_check(&self) -> StatResult<bool>;
    
    /// 获取支持的算法列表
    async fn get_supported_algorithms(&self) -> StatResult<Vec<String>>;
}

/// ⭐ v7智能分发器接口 - 负责选择最优实现
#[async_trait]
pub trait IntelligentDispatcher: Send + Sync + Clone {
    /// 根据算法复杂度和数据大小选择实现
    async fn dispatch_calculation(
        &self,
        algorithm: &str,
        data: &[f64],
        prefer_rust: bool,
        allow_python: bool
    ) -> StatResult<(serde_json::Value, String)>; // (结果, 使用的实现)
    
    /// 获取算法推荐实现
    fn get_recommended_implementation(&self, algorithm: &str, data_size: usize) -> &'static str;
    
    /// 更新实现性能统计
    fn update_performance_stats(&self, implementation: &str, algorithm: &str, duration_ms: u64);
} 