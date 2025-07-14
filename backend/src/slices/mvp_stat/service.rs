use super::interfaces::{StatisticsService, RandomDataGenerator, AnalyticsClient, IntelligentDispatcher};
use super::types::{
    GenerateRandomDataRequest, GenerateRandomDataResponse,
    CalculateStatisticsRequest, CalculateStatisticsResponse,
    ComprehensiveAnalysisRequest, ComprehensiveAnalysisResponse,
    StatResult, StatError, PerformanceInfo, DataSummary, StatisticsResult,
    BasicStatistics, DistributionStatistics, PercentileInfo, ShapeStatistics,
    SeedGenerator,
};
use crate::infra::monitoring::{Timer, LogLevel, LogEntry, logger, metrics};
use async_trait::async_trait;
use chrono::Utc;
use rand::{Rng, SeedableRng};
use rand_distr::{Normal, Uniform, Exp, Distribution};
use std::collections::HashMap;
use std::sync::Arc;
use tonic::transport::Channel;

// 导入Analytics Engine的gRPC客户端
use crate::analytics::{
    analytics_engine_client::AnalyticsEngineClient,
    AnalysisRequest, AnalysisOptions, Empty, HealthCheckRequest,
};

/// ⭐ v7默认统计服务实现
#[derive(Clone)]
pub struct DefaultStatisticsService<R, A, D> 
where
    R: RandomDataGenerator,
    A: AnalyticsClient,
    D: IntelligentDispatcher,
{
    random_generator: R,
    analytics_client: A,
    dispatcher: D,
}

impl<R, A, D> DefaultStatisticsService<R, A, D>
where
    R: RandomDataGenerator,
    A: AnalyticsClient,
    D: IntelligentDispatcher,
{
    pub fn new(random_generator: R, analytics_client: A, dispatcher: D) -> Self {
        Self {
            random_generator,
            analytics_client,
            dispatcher,
        }
    }
}

#[async_trait]
impl<R, A, D> StatisticsService for DefaultStatisticsService<R, A, D>
where
    R: RandomDataGenerator,
    A: AnalyticsClient,
    D: IntelligentDispatcher,
{
    async fn generate_random_data(&self, req: GenerateRandomDataRequest) -> StatResult<GenerateRandomDataResponse> {
        let timer = Timer::start("stat_generate_random_data");
        
        // 验证请求
        req.validate()?;
        
        let count = req.count.unwrap_or(10000);
        let mut seed_gen = SeedGenerator::new();
        let seed = req.seed.unwrap_or_else(|| seed_gen.next_seed());
        let distribution = req.distribution.as_deref().unwrap_or("uniform");
        
        // 记录日志
        let log_entry = LogEntry::new(
            LogLevel::Info, 
            format!("开始生成随机数据: count={}, seed={}, distribution={}", count, seed, distribution)
        );
        logger().lock().unwrap().log(log_entry);
        
        // 生成数据
        let data = match distribution {
            "normal" => {
                let mean = req.min_value.unwrap_or(0.0);
                let std_dev = req.max_value.unwrap_or(1.0);
                self.random_generator.generate_normal(count, seed, mean, std_dev).await?
            },
            "exponential" => {
                let lambda = req.min_value.unwrap_or(1.0);
                self.random_generator.generate_exponential(count, seed, lambda).await?
            },
            _ => { // uniform
                let min = req.min_value.unwrap_or(0.0);
                let max = req.max_value.unwrap_or(100.0);
                self.random_generator.generate_uniform(count, seed, min, max).await?
            }
        };
        
        let duration = timer.stop();
        
        // 记录性能指标
        metrics()
            .lock()
            .unwrap()
            .as_ref()
            .unwrap()
            .record_timer("stat.generate_random_data", duration);
        
        let mut perf_metrics = self.random_generator.get_performance_metrics();
        perf_metrics.insert("data_points".to_string(), count.to_string());
        
        Ok(GenerateRandomDataResponse {
            data,
            count,
            seed,
            generated_at: Utc::now(),
            performance: PerformanceInfo {
                execution_time_ms: duration.as_millis() as u64,
                memory_usage_bytes: Some((count as u64) * 8), // f64 = 8 bytes
                implementation: "rust".to_string(),
                metrics: perf_metrics,
            },
        })
    }
    
    async fn calculate_statistics(&self, req: CalculateStatisticsRequest) -> StatResult<CalculateStatisticsResponse> {
        let timer = Timer::start("stat_calculate_statistics");
        
        // 验证请求
        req.validate()?;
        
        let use_analytics = req.use_analytics_engine.unwrap_or(true);
        let prefer_rust = req.prefer_rust.unwrap_or(true);
        
        let statistics = if req.statistics.is_empty() {
            CalculateStatisticsRequest::get_default_statistics()
        } else {
            req.statistics.clone()
        };
        
        let mut results = HashMap::new();
        let mut implementation = "rust".to_string();
        
        // 完全使用Analytics Engine - 移除本地算法实现
        for stat_type in &statistics {
            let (result, impl_used) = self.dispatcher
                .dispatch_calculation(stat_type, &req.data, prefer_rust, true)
                .await?;
            results.insert(stat_type.clone(), result);
            implementation = impl_used; // 记录使用的实现
        }
        
        // 构建统计结果
        let stats_result = self.build_statistics_result(&results, &req.data, &req.percentiles)?;
        
        let duration = timer.stop();
        
        // 记录性能指标
        metrics()
            .lock()
            .unwrap()
            .as_ref()
            .unwrap()
            .record_timer("stat.calculate_statistics", duration);
        
        Ok(CalculateStatisticsResponse {
            results: stats_result,
            performance: PerformanceInfo {
                execution_time_ms: duration.as_millis() as u64,
                memory_usage_bytes: Some((req.data.len() as u64) * 8),
                implementation: implementation.clone(),
                metrics: HashMap::new(),
            },
            implementation,
        })
    }
    
    async fn comprehensive_analysis(&self, req: ComprehensiveAnalysisRequest) -> StatResult<ComprehensiveAnalysisResponse> {
        let timer = Timer::start("stat_comprehensive_analysis");
        
        // 1. 生成随机数据
        let data_response = self.generate_random_data(req.data_config).await?;
        
        // 2. 构造统计计算请求
        let mut stats_req = req.stats_config;
        stats_req.data = data_response.data.clone();
        
        // 3. 计算统计量
        let stats_response = self.calculate_statistics(stats_req).await?;
        
        let duration = timer.stop();
        
        // 构建数据摘要
        let data_summary = DataSummary {
            count: data_response.count,
            seed: data_response.seed,
            range: {
                let min = data_response.data.iter().fold(f64::INFINITY, |a, &b| a.min(b));
                let max = data_response.data.iter().fold(f64::NEG_INFINITY, |a, &b| a.max(b));
                (min, max)
            },
            distribution: "uniform".to_string(), // TODO: 从请求中获取
            preview: data_response.data.iter().take(10).copied().collect(),
        };
        
        Ok(ComprehensiveAnalysisResponse {
            data_summary,
            statistics: stats_response.results,
            performance: PerformanceInfo {
                execution_time_ms: duration.as_millis() as u64,
                memory_usage_bytes: Some((data_response.data.len() as u64) * 8),
                implementation: stats_response.implementation,
                metrics: HashMap::new(),
            },
            analyzed_at: Utc::now(),
        })
    }
}

impl<R, A, D> DefaultStatisticsService<R, A, D>
where
    R: RandomDataGenerator,
    A: AnalyticsClient,
    D: IntelligentDispatcher,
{
    // 本地算法实现已移除 - 完全依赖Analytics Engine
    
    /// 构建完整的统计结果 - 基于Analytics Engine的计算结果
    fn build_statistics_result(
        &self, 
        results: &HashMap<String, serde_json::Value>,
        data: &[f64],
        custom_percentiles: &Option<Vec<f64>>
    ) -> StatResult<StatisticsResult> {
        let count = data.len() as u32;
        
        // 从Analytics Engine结果中提取数值
        let get_value = |key: &str| -> f64 {
            results.get(key)
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0)
        };
        
        let sum = get_value("sum");
        let mean = get_value("mean");
        let min = get_value("min");
        let max = get_value("max");
        let range = max - min;
        
        let median = get_value("median");
        let variance = get_value("variance");
        let std_dev = get_value("std");
        let q1 = get_value("q1");
        let q3 = get_value("q3");
        let iqr = q3 - q1;
        
        let mut custom_perc = HashMap::new();
        if let Some(percentiles) = custom_percentiles {
            for &p in percentiles {
                let value = get_value(&format!("percentile_{}", p));
                custom_perc.insert(format!("p{}", p), value);
            }
        }
        
        Ok(StatisticsResult {
            basic: BasicStatistics {
                count,
                sum,
                mean,
                min,
                max,
                range,
            },
            distribution: DistributionStatistics {
                median,
                mode: vec![], // 由Analytics Engine计算
                variance,
                std_dev,
                iqr,
            },
            percentiles: PercentileInfo {
                q1,
                q2: median,
                q3,
                custom: custom_perc,
            },
            shape: ShapeStatistics {
                skewness: get_value("skewness"),
                kurtosis: get_value("kurtosis"),
                distribution_shape: "analytics_engine".to_string(),
            },
        })
    }
    
    // 本地统计算法已全部移除 - 所有计算均通过Analytics Engine完成
}

/// ⭐ v7默认随机数生成器实现
#[derive(Clone)]
pub struct DefaultRandomDataGenerator {
    performance_metrics: Arc<std::sync::Mutex<HashMap<String, String>>>,
}

impl Default for DefaultRandomDataGenerator {
    fn default() -> Self {
        Self::new()
    }
}

impl DefaultRandomDataGenerator {
    pub fn new() -> Self {
        Self {
            performance_metrics: Arc::new(std::sync::Mutex::new(HashMap::new())),
        }
    }
}

#[async_trait]
impl RandomDataGenerator for DefaultRandomDataGenerator {
    async fn generate_uniform(&self, count: u32, seed: u64, min: f64, max: f64) -> StatResult<Vec<f64>> {
        let mut rng = rand::rngs::StdRng::seed_from_u64(seed);
        let uniform = Uniform::new(min, max);
        
        let data: Vec<f64> = (0..count)
            .map(|_| uniform.sample(&mut rng))
            .collect();
        
        // 更新性能指标
        {
            let mut metrics = self.performance_metrics.lock().unwrap();
            metrics.insert("last_distribution".to_string(), "uniform".to_string());
            metrics.insert("last_count".to_string(), count.to_string());
        }
        
        Ok(data)
    }
    
    async fn generate_normal(&self, count: u32, seed: u64, mean: f64, std_dev: f64) -> StatResult<Vec<f64>> {
        let mut rng = rand::rngs::StdRng::seed_from_u64(seed);
        let normal = Normal::new(mean, std_dev)
            .map_err(|e| StatError::Calculation {
                message: format!("无效的正态分布参数: {}", e),
            })?;
        
        let data: Vec<f64> = (0..count)
            .map(|_| normal.sample(&mut rng))
            .collect();
        
        // 更新性能指标
        {
            let mut metrics = self.performance_metrics.lock().unwrap();
            metrics.insert("last_distribution".to_string(), "normal".to_string());
            metrics.insert("last_count".to_string(), count.to_string());
        }
        
        Ok(data)
    }
    
    async fn generate_exponential(&self, count: u32, seed: u64, lambda: f64) -> StatResult<Vec<f64>> {
        let mut rng = rand::rngs::StdRng::seed_from_u64(seed);
        let exp = Exp::new(lambda)
            .map_err(|e| StatError::Calculation {
                message: format!("无效的指数分布参数: {}", e),
            })?;
        
        let data: Vec<f64> = (0..count)
            .map(|_| exp.sample(&mut rng))
            .collect();
        
        // 更新性能指标
        {
            let mut metrics = self.performance_metrics.lock().unwrap();
            metrics.insert("last_distribution".to_string(), "exponential".to_string());
            metrics.insert("last_count".to_string(), count.to_string());
        }
        
        Ok(data)
    }
    
    fn get_performance_metrics(&self) -> HashMap<String, String> {
        self.performance_metrics.lock().unwrap().clone()
    }
}

/// ⭐ v7 gRPC Analytics客户端实现 - 真实gRPC连接
#[derive(Clone)]
pub struct GrpcAnalyticsClient {
    endpoint: String,
    channel: Option<Arc<Channel>>,
}

impl GrpcAnalyticsClient {
    pub fn new(endpoint: String) -> Self {
        Self {
            endpoint,
            channel: None,
        }
    }
    
    /// 建立到Analytics Engine的真实gRPC连接
    async fn get_or_create_channel(&self) -> StatResult<Arc<Channel>> {
        // 如果已有连接，直接返回
        if let Some(channel) = &self.channel {
            return Ok(channel.clone());
        }
        
        // 建立新的gRPC连接
        let channel = Channel::from_shared(self.endpoint.clone())
            .map_err(|e| StatError::Grpc { 
                message: format!("创建gRPC通道失败: {}", e) 
            })?
            .connect()
            .await
            .map_err(|e| StatError::Grpc { 
                message: format!("连接Analytics Engine失败: {}", e) 
            })?;
        
        let channel = Arc::new(channel);
        // 注意：这里应该使用内部可变性来更新channel，但为了简化，我们每次都创建新连接
        Ok(channel)
    }
    
    /// 调用Analytics Engine进行真实计算
    async fn call_analytics_engine(&self, algorithm: &str, data: &[f64]) -> StatResult<serde_json::Value> {
        // 获取gRPC连接
        let channel = self.get_or_create_channel().await?;
        let mut client = AnalyticsEngineClient::new((*channel).clone());
        
        // 构建Analytics Engine请求
        let request = tonic::Request::new(AnalysisRequest {
            request_id: format!("stat_{}_{}", algorithm, chrono::Utc::now().timestamp_millis()),
            algorithm: algorithm.to_string(),
            data: data.to_vec(),
            params: HashMap::new(), // 可以根据需要添加参数
            options: Some(AnalysisOptions {
                prefer_rust: true,
                allow_python: true,
                timeout_ms: 30000, // 30秒超时
                include_metadata: true,
            }),
        });
        
        // 发送gRPC请求
        let response = client
            .analyze(request)
            .await
            .map_err(|e| StatError::Grpc { 
                message: format!("Analytics Engine调用失败: {}", e) 
            })?;
        
        let analytics_response = response.into_inner();
        
        // 检查响应状态
        if !analytics_response.success {
            return Err(StatError::AnalyticsEngine { 
                message: analytics_response.error_message 
            });
        }
        
        // 解析结果
        serde_json::from_str(&analytics_response.result_json)
            .map_err(|e| StatError::AnalyticsEngine { 
                message: format!("解析Analytics Engine响应失败: {}", e) 
            })
    }
}

#[async_trait]
impl AnalyticsClient for GrpcAnalyticsClient {
    async fn calculate_statistics(
        &self, 
        algorithm: &str, 
        data: &[f64], 
        _parameters: HashMap<String, String>
    ) -> StatResult<serde_json::Value> {
        // 使用真实的gRPC调用代替模拟实现
        self.call_analytics_engine(algorithm, data).await
    }
    
    async fn batch_calculate(
        &self,
        requests: Vec<(String, Vec<f64>, HashMap<String, String>)>
    ) -> StatResult<Vec<serde_json::Value>> {
        let mut results = Vec::new();
        
        for (algorithm, data, _parameters) in requests {
            let result = self.call_analytics_engine(&algorithm, &data).await?;
            results.push(result);
        }
        
        Ok(results)
    }
    
    async fn health_check(&self) -> StatResult<bool> {
        // 真实的健康检查
        match self.get_or_create_channel().await {
            Ok(channel) => {
                let mut client = AnalyticsEngineClient::new((*channel).clone());
                let request = tonic::Request::new(HealthCheckRequest {});
                
                match client.health_check(request).await {
                    Ok(response) => Ok(response.into_inner().healthy),
                    Err(_) => Ok(false),
                }
            }
            Err(_) => Ok(false),
        }
    }
    
    async fn get_supported_algorithms(&self) -> StatResult<Vec<String>> {
        // 从Analytics Engine获取真实的支持算法列表
        let channel = self.get_or_create_channel().await?;
        let mut client = AnalyticsEngineClient::new((*channel).clone());
        let request = tonic::Request::new(Empty {});
        
        match client.get_supported_algorithms(request).await {
            Ok(response) => {
                let algorithms: Vec<String> = response
                    .into_inner()
                    .algorithms
                    .into_iter()
                    .map(|alg| alg.name)
                    .collect();
                Ok(algorithms)
            }
            Err(e) => Err(StatError::Grpc { 
                message: format!("获取支持算法列表失败: {}", e) 
            }),
        }
    }
}

/// ⭐ v7智能分发器实现
#[derive(Clone)]
pub struct DefaultIntelligentDispatcher<A> 
where
    A: AnalyticsClient,
{
    analytics_client: A,
    performance_stats: Arc<std::sync::Mutex<HashMap<String, HashMap<String, u64>>>>,
}

impl<A> DefaultIntelligentDispatcher<A>
where
    A: AnalyticsClient,
{
    pub fn new(analytics_client: A) -> Self {
        Self {
            analytics_client,
            performance_stats: Arc::new(std::sync::Mutex::new(HashMap::new())),
        }
    }
}

#[async_trait]
impl<A> IntelligentDispatcher for DefaultIntelligentDispatcher<A>
where
    A: AnalyticsClient,
{
    async fn dispatch_calculation(
        &self,
        algorithm: &str,
        data: &[f64],
        _prefer_rust: bool,
        _allow_python: bool
    ) -> StatResult<(serde_json::Value, String)> {
        // 完全依赖Analytics Engine - 不再有本地实现
        let result = self.analytics_client
            .calculate_statistics(algorithm, data, HashMap::new())
            .await?;
        
        // Analytics Engine会内部决定使用Rust还是Python实现
        Ok((result, "analytics_engine".to_string()))
    }
    
    fn get_recommended_implementation(&self, _algorithm: &str, _data_size: usize) -> &'static str {
        // 始终使用Analytics Engine - 它会内部决定最优实现
        "analytics_engine"
    }
    
    fn update_performance_stats(&self, implementation: &str, algorithm: &str, duration_ms: u64) {
        let mut stats = self.performance_stats.lock().unwrap();
        let impl_stats = stats.entry(implementation.to_string()).or_insert_with(HashMap::new);
        impl_stats.insert(algorithm.to_string(), duration_ms);
    }
}

// 本地算法实现已移除 - 完全依赖Analytics Engine

/// 类型别名，方便使用
pub type ConcreteStatisticsService = DefaultStatisticsService<
    DefaultRandomDataGenerator,
    GrpcAnalyticsClient,
    DefaultIntelligentDispatcher<GrpcAnalyticsClient>
>;

pub type ConcreteRandomDataGenerator = DefaultRandomDataGenerator;
pub type ConcreteAnalyticsClient = GrpcAnalyticsClient;
pub type ConcreteIntelligentDispatcher = DefaultIntelligentDispatcher<GrpcAnalyticsClient>; 