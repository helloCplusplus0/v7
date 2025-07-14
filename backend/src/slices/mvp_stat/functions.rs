use super::interfaces::StatisticsService;
use super::types::{
    GenerateRandomDataRequest, GenerateRandomDataResponse,
    CalculateStatisticsRequest, CalculateStatisticsResponse,
    ComprehensiveAnalysisRequest, ComprehensiveAnalysisResponse,
    StatResult, StatError,
};
// gRPC专用模块 - 不再需要HTTP相关导入

/// ⭐ v7核心业务函数：生成随机数据（静态分发）
///
/// 函数路径: `mvp_stat.generate_random_data`
/// HTTP路由: POST /api/stats/random-data
/// 性能特性: 编译时单态化，零运行时开销
///
/// # Errors
///
/// 此函数可能返回以下错误：
/// - `StatError::Validation` - 当输入参数验证失败时
/// - `StatError::InvalidDistribution` - 当分布类型无效时
/// - `StatError::Calculation` - 当数据生成失败时
pub async fn generate_random_data<S>(
    service: S, 
    req: GenerateRandomDataRequest
) -> StatResult<GenerateRandomDataResponse>
where
    S: StatisticsService,
{
    service.generate_random_data(req).await
}

/// ⭐ v7核心业务函数：计算统计量（静态分发）
///
/// 函数路径: `mvp_stat.calculate_statistics`
/// HTTP路由: POST /api/stats/calculate
/// 性能特性: 编译时单态化，零运行时开销
///
/// # Errors
///
/// 此函数可能返回以下错误：
/// - `StatError::EmptyData` - 当数据为空时
/// - `StatError::Validation` - 当输入数据验证失败时
/// - `StatError::AnalyticsEngine` - 当Analytics Engine调用失败时
/// - `StatError::Calculation` - 当统计计算失败时
pub async fn calculate_statistics<S>(
    service: S, 
    req: CalculateStatisticsRequest
) -> StatResult<CalculateStatisticsResponse>
where
    S: StatisticsService,
{
    service.calculate_statistics(req).await
}

/// ⭐ v7核心业务函数：综合分析（静态分发）
///
/// 函数路径: `mvp_stat.comprehensive_analysis`
/// HTTP路由: POST /api/stats/comprehensive
/// 性能特性: 编译时单态化，零运行时开销
///
/// 执行完整的MVP统计分析流程：
/// 1. 生成10000个随机数
/// 2. 计算完整统计量
/// 3. 返回综合分析结果
///
/// # Errors
///
/// 此函数可能返回以下错误：
/// - `StatError::Validation` - 当配置参数验证失败时
/// - `StatError::AnalyticsEngine` - 当Analytics Engine调用失败时
/// - `StatError::Calculation` - 当数据生成或统计计算失败时
pub async fn comprehensive_analysis<S>(
    service: S, 
    req: ComprehensiveAnalysisRequest
) -> StatResult<ComprehensiveAnalysisResponse>
where
    S: StatisticsService,
{
    service.comprehensive_analysis(req).await
}

// =============================================================================
// HTTP适配器已移除 - 统计分析功能已完全迁移到gRPC
// =============================================================================

// =============================================================================
// 便利函数 - 提供常用的预设配置
// =============================================================================

/// 快速生成10000个均匀分布随机数（默认配置）
pub async fn generate_default_random_data<S>(service: S) -> StatResult<GenerateRandomDataResponse>
where
    S: StatisticsService,
{
    let req = GenerateRandomDataRequest {
        count: Some(10000),
        seed: None, // 自动生成种子
        min_value: Some(0.0),
        max_value: Some(100.0),
        distribution: Some("uniform".to_string()),
    };
    
    generate_random_data(service, req).await
}

/// 快速计算全部统计量（默认配置）
pub async fn calculate_all_statistics<S>(
    service: S, 
    data: Vec<f64>
) -> StatResult<CalculateStatisticsResponse>
where
    S: StatisticsService,
{
    let req = CalculateStatisticsRequest {
        data,
        statistics: CalculateStatisticsRequest::get_default_statistics(),
        percentiles: Some(vec![5.0, 10.0, 25.0, 50.0, 75.0, 90.0, 95.0, 99.0]),
        use_analytics_engine: Some(true),
        prefer_rust: Some(true),
    };
    
    calculate_statistics(service, req).await
}

/// MVP完整演示：生成数据+计算统计量
pub async fn mvp_demonstration<S>(service: S) -> StatResult<ComprehensiveAnalysisResponse>
where
    S: StatisticsService,
{
    let req = ComprehensiveAnalysisRequest {
        data_config: GenerateRandomDataRequest {
            count: Some(10000),
            seed: Some(42), // 固定种子确保可重现
            min_value: Some(0.0),
            max_value: Some(100.0),
            distribution: Some("uniform".to_string()),
        },
        stats_config: CalculateStatisticsRequest {
            data: vec![], // 将由生成的数据填充
            statistics: CalculateStatisticsRequest::get_default_statistics(),
            percentiles: Some(vec![1.0, 5.0, 10.0, 25.0, 50.0, 75.0, 90.0, 95.0, 99.0]),
            use_analytics_engine: Some(true),
            prefer_rust: Some(true),
        },
    };
    
    comprehensive_analysis(service, req).await
}

// =============================================================================
// 内部工具函数 - 仅供切片内部使用
// =============================================================================

/// 内部函数：验证数据质量
pub(crate) fn validate_data_quality(data: &[f64]) -> StatResult<()> {
    if data.is_empty() {
        return Err(StatError::EmptyData);
    }
    
    // 检查是否包含无效值
    for (i, &value) in data.iter().enumerate() {
        if value.is_nan() {
            return Err(StatError::Validation {
                message: format!("数据包含NaN值，位置: {}", i),
            });
        }
        if value.is_infinite() {
            return Err(StatError::Validation {
                message: format!("数据包含无限值，位置: {}", i),
            });
        }
    }
    
    Ok(())
}

/// 内部函数：格式化性能报告
pub(crate) fn format_performance_report(
    data_gen_ms: u64,
    stats_calc_ms: u64,
    total_data_points: u32,
    implementation: &str
) -> String {
    format!(
        "📊 MVP统计性能报告\n\
         • 数据量: {} 个数据点\n\
         • 数据生成: {}ms\n\
         • 统计计算: {}ms\n\
         • 总计用时: {}ms\n\
         • 使用实现: {}\n\
         • 处理速率: {:.2} 数据点/ms",
        total_data_points,
        data_gen_ms,
        stats_calc_ms,
        data_gen_ms + stats_calc_ms,
        implementation,
        total_data_points as f64 / (data_gen_ms + stats_calc_ms) as f64
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::slices::mvp_stat::service::{
        DefaultStatisticsService, DefaultRandomDataGenerator, 
        GrpcAnalyticsClient, DefaultIntelligentDispatcher
    };

    /// 创建测试用的服务实例
    fn create_test_service() -> impl StatisticsService {
        let generator = DefaultRandomDataGenerator::new();
        let analytics_client = GrpcAnalyticsClient::new("http://localhost:50051".to_string());
        let dispatcher = DefaultIntelligentDispatcher::new(analytics_client.clone());
        DefaultStatisticsService::new(generator, analytics_client, dispatcher)
    }

    #[tokio::test]
    async fn test_generate_random_data_uniform() {
        let service = create_test_service();
        
        let req = GenerateRandomDataRequest {
            count: Some(1000),
            seed: Some(42),
            min_value: Some(0.0),
            max_value: Some(10.0),
            distribution: Some("uniform".to_string()),
        };
        
        let result = generate_random_data(service, req).await;
        assert!(result.is_ok(), "生成随机数据应该成功: {:?}", result.err());
        
        let response = result.unwrap();
        assert_eq!(response.count, 1000);
        assert_eq!(response.seed, 42);
        assert_eq!(response.data.len(), 1000);
        
        // 验证数据范围
        for &value in &response.data {
            assert!(value >= 0.0 && value <= 10.0, "数据值应该在指定范围内: {}", value);
        }
    }

    #[tokio::test]
    async fn test_calculate_statistics_basic() {
        let service = create_test_service();
        
        let test_data = vec![1.0, 2.0, 3.0, 4.0, 5.0];
        let req = CalculateStatisticsRequest {
            data: test_data,
            statistics: vec!["mean".to_string(), "median".to_string(), "std".to_string()],
            percentiles: Some(vec![25.0, 50.0, 75.0]),
            use_analytics_engine: Some(false), // 使用本地实现测试
            prefer_rust: Some(true),
        };
        
        let result = calculate_statistics(service, req).await;
        assert!(result.is_ok(), "计算统计量应该成功: {:?}", result.err());
        
        let response = result.unwrap();
        assert_eq!(response.results.basic.mean, 3.0);
        assert_eq!(response.results.distribution.median, 3.0);
        assert!(response.results.distribution.std_dev > 0.0);
    }

    #[tokio::test]
    async fn test_comprehensive_analysis() {
        let service = create_test_service();
        
        let req = ComprehensiveAnalysisRequest {
            data_config: GenerateRandomDataRequest {
                count: Some(100),
                seed: Some(123),
                min_value: Some(-10.0),
                max_value: Some(10.0),
                distribution: Some("uniform".to_string()),
            },
            stats_config: CalculateStatisticsRequest {
                data: vec![], // 将由生成数据填充
                statistics: vec!["mean".to_string(), "std".to_string()],
                percentiles: Some(vec![50.0]),
                use_analytics_engine: Some(false),
                prefer_rust: Some(true),
            },
        };
        
        let result = comprehensive_analysis(service, req).await;
        assert!(result.is_ok(), "综合分析应该成功: {:?}", result.err());
        
        let response = result.unwrap();
        assert_eq!(response.data_summary.count, 100);
        assert_eq!(response.data_summary.seed, 123);
        assert_eq!(response.data_summary.preview.len(), 10);
    }

    #[tokio::test]
    async fn test_mvp_demonstration() {
        let service = create_test_service();
        
        let result = mvp_demonstration(service).await;
        assert!(result.is_ok(), "MVP演示应该成功: {:?}", result.err());
        
        let response = result.unwrap();
        assert_eq!(response.data_summary.count, 10000);
        assert_eq!(response.data_summary.seed, 42);
        assert!(response.statistics.basic.count == 10000);
    }

    #[tokio::test]
    async fn test_validate_data_quality() {
        // 测试正常数据
        let valid_data = vec![1.0, 2.0, 3.0, 4.0, 5.0];
        assert!(validate_data_quality(&valid_data).is_ok());
        
        // 测试空数据
        let empty_data = vec![];
        assert!(validate_data_quality(&empty_data).is_err());
        
        // 测试包含NaN的数据
        let nan_data = vec![1.0, f64::NAN, 3.0];
        assert!(validate_data_quality(&nan_data).is_err());
        
        // 测试包含无限值的数据
        let inf_data = vec![1.0, f64::INFINITY, 3.0];
        assert!(validate_data_quality(&inf_data).is_err());
    }

    #[test]
    fn test_format_performance_report() {
        let report = format_performance_report(100, 50, 10000, "rust");
        assert!(report.contains("10000"));
        assert!(report.contains("100ms"));
        assert!(report.contains("50ms"));
        assert!(report.contains("rust"));
    }
} 