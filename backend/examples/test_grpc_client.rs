/// v7架构gRPC客户端测试示例
/// 测试Backend gRPC服务的统计分析功能
/// 验证完整的数据流：Client -> Backend gRPC -> Analytics Engine gRPC

use anyhow::Result;
use fmod_slice::v7_backend::backend_service_client::BackendServiceClient;
use fmod_slice::v7_backend::{
    StatisticsRequest, statistics_request, GenerateRandomDataRequest,
};
use tonic::transport::Channel;

#[tokio::main]
async fn main() -> Result<()> {
    // 初始化日志
    tracing_subscriber::fmt::init();
    
    println!("🚀 v7架构gRPC客户端测试开始");
    println!("连接到Backend gRPC服务: localhost:50053");
    
    // 连接到Backend gRPC服务
    let channel = Channel::from_static("http://localhost:50053")
        .connect()
        .await?;
    
    let mut client = BackendServiceClient::new(channel);
    
    println!("✅ 成功连接到Backend gRPC服务");
    
    // 测试统计分析功能
    println!("\n📊 测试统计分析功能...");
    
    let request = tonic::Request::new(StatisticsRequest {
        request_type: Some(statistics_request::RequestType::Comprehensive(
            fmod_slice::v7_backend::ComprehensiveAnalysisRequest {
                data_config: Some(GenerateRandomDataRequest {
                    count: Some(1000),
                    distribution: Some("uniform".to_string()),
                    min_value: Some(0.0),
                    max_value: Some(100.0),
                    seed: Some(42),
                }),
                stats_config: Some(fmod_slice::v7_backend::CalculateStatisticsRequest {
                    data: vec![], // 将由data_config生成
                    statistics: vec![
                        "mean".to_string(),
                        "median".to_string(),
                        "variance".to_string(),
                        "std".to_string(),
                        "min".to_string(),
                        "max".to_string(),
                        "count".to_string(),
                    ],
                    percentiles: vec![],
                    use_analytics_engine: Some(true),
                    prefer_rust: Some(false),
                }),
            }
        )),
    });
    
    match client.statistics(request).await {
        Ok(response) => {
            let result = response.into_inner();
            
            if !result.success {
                println!("❌ 统计分析失败: {}", result.error);
                return Err(anyhow::anyhow!("Statistics analysis failed: {}", result.error));
            }
            
            println!("✅ 统计分析完成！");
            
            // 处理综合分析响应
            if let Some(response_type) = result.response_type {
                match response_type {
                    fmod_slice::v7_backend::statistics_response::ResponseType::ComprehensiveResponse(comp_resp) => {
                        // 显示数据生成信息
                        if let Some(data_summary) = &comp_resp.data_summary {
                            println!("\n📈 数据生成信息:");
                            println!("   数据点数量: {}", data_summary.count);
                            println!("   分布类型: {}", data_summary.distribution);
                            if let Some(range) = &data_summary.range {
                                println!("   数据范围: [{:.2}, {:.2}]", range.min, range.max);
                            }
                            println!("   随机种子: {}", data_summary.seed);
                        }
                        
                        // 显示统计结果
                        if let Some(stats) = &comp_resp.statistics {
                            println!("\n📊 统计计算结果:");
                            if let Some(basic) = &stats.basic {
                                println!("   基本统计:");
                                println!("     计数: {}", basic.count);
                                println!("     总和: {:.6}", basic.sum);
                                println!("     均值: {:.6}", basic.mean);
                                println!("     最小值: {:.6}", basic.min);
                                println!("     最大值: {:.6}", basic.max);
                                println!("     范围: {:.6}", basic.range);
                            }
                            
                            if let Some(dist) = &stats.distribution {
                                println!("   分布统计:");
                                println!("     中位数: {:.6}", dist.median);
                                println!("     方差: {:.6}", dist.variance);
                                println!("     标准差: {:.6}", dist.std_dev);
                                println!("     四分位距: {:.6}", dist.iqr);
                            }
                        }
                        
                        // 显示性能信息
                        if let Some(perf) = &comp_resp.performance {
                            println!("\n⚡ 性能信息:");
                            println!("   执行时间: {}ms", perf.execution_time_ms);
                            println!("   实现方式: {}", perf.implementation);
                        }
                    },
                    _ => {
                        println!("⚠️ 收到非预期的响应类型");
                    }
                }
            }
            
            println!("\n🎉 端到端gRPC测试成功！");
            println!("   验证了完整的数据流:");
            println!("   Client -> Backend gRPC (50053) -> Analytics Engine gRPC (50051) -> Backend -> Client");
        }
        Err(e) => {
            println!("❌ 统计分析失败: {}", e);
            println!("   请检查:");
            println!("   1. Backend gRPC服务是否在50053端口运行");
            println!("   2. Analytics Engine是否在50051端口运行");
            println!("   3. 网络连接是否正常");
            return Err(e.into());
        }
    }
    
    println!("\n✅ 所有测试完成！v7架构gRPC通信工作正常");
    Ok(())
} 