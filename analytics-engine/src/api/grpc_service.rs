use tonic::{Request, Response, Status};
use tracing::{info, warn, error};
use std::collections::HashMap;
use futures_util::Stream;
use std::pin::Pin;

use crate::api::types as internal_types;
use crate::core::dispatcher;

// 包含生成的gRPC代码
pub mod analytics_grpc {
    tonic::include_proto!("analytics");
}

use analytics_grpc::analytics_engine_server::{AnalyticsEngine, AnalyticsEngineServer};
use analytics_grpc::{
    AnalysisRequest as GrpcAnalysisRequest,
    AnalysisResponse as GrpcAnalysisResponse,
    BatchAnalysisRequest as GrpcBatchAnalysisRequest,
    ExecutionMetadata as GrpcExecutionMetadata,
    AlgorithmInfo as GrpcAlgorithmInfo,
    HealthCheckRequest, HealthCheckResponse,
    SupportedAlgorithmsResponse, Empty
};

#[derive(Debug, Default)]
pub struct AnalyticsService {
    // 服务状态，可以添加缓存、连接池等
}

impl AnalyticsService {
    pub fn new() -> Self {
        Self::default()
    }
    
    pub fn into_server(self) -> AnalyticsEngineServer<Self> {
        AnalyticsEngineServer::new(self)
    }
}

#[tonic::async_trait]
impl AnalyticsEngine for AnalyticsService {
    async fn analyze(
        &self,
        request: Request<GrpcAnalysisRequest>,
    ) -> Result<Response<GrpcAnalysisResponse>, Status> {
        let grpc_request = request.into_inner();
        
        info!("Received analysis request: {} - {}", 
              grpc_request.request_id, grpc_request.algorithm);
        
        // 转换gRPC请求到内部类型
        let internal_request = convert_grpc_to_internal_request(grpc_request)?;
        
        // 执行分析
        match dispatcher::analyze(internal_request).await {
            Ok(result) => {
                info!("Analysis completed successfully");
                let grpc_response = convert_internal_to_grpc_response(
                    result, true, None
                );
                Ok(Response::new(grpc_response))
            }
            Err(e) => {
                error!("Analysis failed: {}", e);
                let grpc_response = GrpcAnalysisResponse {
                    request_id: "".to_string(),
                    success: false,
                                                error_message: e.to_string(),
                    result_json: String::new(),
                    metadata: None,
                };
                Ok(Response::new(grpc_response))
            }
        }
    }
    
    type BatchAnalyzeStream = Pin<Box<dyn Stream<Item = Result<GrpcAnalysisResponse, Status>> + Send>>;
    
    async fn batch_analyze(
        &self,
        request: Request<GrpcBatchAnalysisRequest>,
    ) -> Result<Response<Self::BatchAnalyzeStream>, Status> {
        let batch_request = request.into_inner();
        
        info!("Received batch analysis request: {} with {} requests", 
              batch_request.batch_id, batch_request.requests.len());
        
        let requests = batch_request.requests;
        
        // 创建异步流处理批量请求
        let stream = async_stream::try_stream! {
            for grpc_req in requests {
                let request_id = grpc_req.request_id.clone();
                
                match convert_grpc_to_internal_request(grpc_req) {
                    Ok(internal_request) => {
                        match dispatcher::analyze(internal_request).await {
                            Ok(result) => {
                                yield convert_internal_to_grpc_response(result, true, None);
                            }
                            Err(e) => {
                                warn!("Batch item {} failed: {}", request_id, e);
                                yield GrpcAnalysisResponse {
                                    request_id,
                                    success: false,
                                    error_message: e.to_string(),
                                    result_json: String::new(),
                                    metadata: None,
                                };
                            }
                        }
                    }
                    Err(e) => {
                        yield GrpcAnalysisResponse {
                            request_id,
                            success: false,
                            error_message: format!("Request conversion error: {}", e),
                            result_json: String::new(),
                            metadata: None,
                        };
                    }
                }
            }
        };
        
        Ok(Response::new(Box::pin(stream)))
    }
    
    async fn health_check(
        &self,
        _request: Request<HealthCheckRequest>,
    ) -> Result<Response<HealthCheckResponse>, Status> {
        let mut capabilities = HashMap::new();
        
        // 检查Rust能力
        capabilities.insert("rust".to_string(), "available".to_string());
        
        // 检查Python能力
        #[cfg(feature = "python-bridge")]
        {
            if crate::python_bridge::dispatcher::is_python_available() {
                capabilities.insert("python".to_string(), "available".to_string());
            } else {
                capabilities.insert("python".to_string(), "unavailable".to_string());
            }
        }
        
        #[cfg(not(feature = "python-bridge"))]
        {
            capabilities.insert("python".to_string(), "disabled".to_string());
        }
        
        let response = HealthCheckResponse {
            healthy: true,
            version: crate::VERSION.to_string(),
            capabilities,
        };
        
        Ok(Response::new(response))
    }
    
    async fn get_supported_algorithms(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<SupportedAlgorithmsResponse>, Status> {
        let algorithms = dispatcher::get_supported_algorithms();
        
        let grpc_algorithms: Vec<GrpcAlgorithmInfo> = algorithms
            .into_iter()
            .map(|algo| GrpcAlgorithmInfo {
                name: algo.name,
                description: algo.description,
                implementations: algo.implementations,
                required_params: algo.required_params,
                optional_params: algo.optional_params,
            })
            .collect();
        
        let response = SupportedAlgorithmsResponse {
            algorithms: grpc_algorithms,
        };
        
        Ok(Response::new(response))
    }
}

// 类型转换函数
fn convert_grpc_to_internal_request(
    grpc_req: GrpcAnalysisRequest,
) -> Result<internal_types::AnalysisRequest, Status> {
    let options = grpc_req.options.unwrap_or_default();
    
    Ok(internal_types::AnalysisRequest {
        request_id: grpc_req.request_id,
        algorithm: grpc_req.algorithm,
        data: grpc_req.data,
        params: grpc_req.params,
        options: internal_types::AnalysisOptions {
            prefer_rust: options.prefer_rust,
            allow_python: options.allow_python,
            timeout_ms: options.timeout_ms,
            include_metadata: options.include_metadata,
        },
    })
}

fn convert_internal_to_grpc_response(
    result: internal_types::AnalysisResult,
    success: bool,
    error_message: Option<String>,
) -> GrpcAnalysisResponse {
    let metadata = GrpcExecutionMetadata {
        implementation: result.metadata.implementation,
        execution_time_ms: result.metadata.execution_time_ms as i64,
        algorithm: result.metadata.algorithm,
        data_size: result.metadata.data_size as i32,
        stats: result.metadata.stats,
    };
    
    GrpcAnalysisResponse {
        request_id: "".to_string(), // 在调用处设置
        success,
        error_message: error_message.unwrap_or_default(),
        result_json: serde_json::to_string(&result.result).unwrap_or_default(),
        metadata: Some(metadata),
    }
}

// 为了支持async_stream宏
use async_stream; 