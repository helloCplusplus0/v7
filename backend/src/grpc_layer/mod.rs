use tonic::{transport::Server, Request, Response, Status};
use tokio::sync::oneshot;
use std::net::SocketAddr;

// 直接使用已生成的gRPC代码
use crate::v7_backend as proto;

use proto::backend_service_server::{BackendService, BackendServiceServer};
use proto::{
    HealthRequest, HealthResponse, 
    // Auth相关
    LoginRequest, LoginResponse, 
    ValidateTokenRequest, ValidateTokenResponse,
    LogoutRequest, LogoutResponse,
    UserSession as GrpcUserSession,
    // CRUD相关
    CreateItemRequest, CreateItemResponse,
    GetItemRequest, GetItemResponse,
    UpdateItemRequest, UpdateItemResponse,
    DeleteItemRequest, DeleteItemResponse,
    ListItemsRequest, ListItemsResponse,
    // Analytics相关
    AnalyticsProxyRequest, AnalyticsProxyResponse,
    StatisticsRequest, StatisticsResponse,
    statistics_request, statistics_response,
    GenerateRandomDataResponse as GrpcGenerateRandomDataResponse,
    CalculateStatisticsResponse as GrpcCalculateStatisticsResponse,
    ComprehensiveAnalysisResponse as GrpcComprehensiveAnalysisResponse,
};

// 导入业务层模块
use crate::slices::auth::{
    functions as auth_functions,
    service::{JwtAuthService, MemoryTokenRepository, MemoryUserRepository},
    types::{LoginRequest as AuthLoginRequest, UserSession},
};
use crate::slices::mvp_crud::{
    functions as crud_functions,
    service::{SqliteCrudService},
};
use crate::slices::mvp_stat::{
    self,
    service::ConcreteStatisticsService,
    types::{
        GenerateRandomDataRequest, GenerateRandomDataResponse,
        CalculateStatisticsRequest, CalculateStatisticsResponse,
        ComprehensiveAnalysisRequest, ComprehensiveAnalysisResponse,
    },
};
use crate::infra::{di, cache::MemoryCache, db::SqliteDatabase, analytics_client::AnalyticsEngineClient};

#[derive(Clone)]
pub struct BackendGrpcService {
    // 使用依赖注入模式，无需存储状态
}

impl BackendGrpcService {
    pub fn new() -> Self {
        Self {}
    }
}

#[tonic::async_trait]
impl BackendService for BackendGrpcService {
    async fn health_check(
        &self,
        _request: Request<HealthRequest>,
    ) -> Result<Response<HealthResponse>, Status> {
        tracing::info!("🏥 收到健康检查请求");
        
        let response = HealthResponse {
            status: "healthy".to_string(),
            version: env!("CARGO_PKG_VERSION").to_string(),
            timestamp: chrono::Utc::now().timestamp(),
        };
        
        tracing::info!("🏥 健康检查响应: status={}, version={}", response.status, response.version);
        Ok(Response::new(response))
    }

    // ===== Auth相关gRPC方法 =====
    
    async fn login(
        &self,
        request: Request<LoginRequest>,
    ) -> Result<Response<LoginResponse>, Status> {
        let req = request.into_inner();
        
        // 获取认证服务实例
        let auth_service = di::inject::<JwtAuthService<MemoryUserRepository, MemoryTokenRepository>>();
        
        // 转换gRPC请求到内部类型
        let internal_req = AuthLoginRequest {
            username: req.username,
            password: req.password,
        };
        
        // 调用业务层函数
        match auth_functions::login(auth_service, internal_req).await {
            Ok(internal_resp) => {
                let grpc_resp = LoginResponse {
                    success: true,
                    error: String::new(),
                    session: Some(GrpcUserSession {
                        token: internal_resp.token,
                        user_id: internal_resp.user_id.clone(),
                        username: "".to_string(), // LoginResponse中没有username，需要从其他地方获取
                        expires_at: internal_resp.expires_at.timestamp(),
                    }),
                };
                Ok(Response::new(grpc_resp))
            },
            Err(e) => {
                let grpc_resp = LoginResponse {
                    success: false,
                    error: e.to_string(),
                    session: None,
                };
                Ok(Response::new(grpc_resp))
            }
        }
    }

    async fn validate_token(
        &self,
        request: Request<ValidateTokenRequest>,
    ) -> Result<Response<ValidateTokenResponse>, Status> {
        let req = request.into_inner();
        
        // 获取认证服务实例
        let auth_service = di::inject::<JwtAuthService<MemoryUserRepository, MemoryTokenRepository>>();
        
        // 调用业务层函数
        match auth_functions::validate_token(auth_service, req.token).await {
            Ok(session) => {
                let grpc_resp = ValidateTokenResponse {
                    success: true,
                    error: String::new(),
                    session: Some(convert_user_session(session)),
                };
                Ok(Response::new(grpc_resp))
            },
            Err(e) => {
                let grpc_resp = ValidateTokenResponse {
                    success: false,
                    error: e.to_string(),
                    session: None,
                };
                Ok(Response::new(grpc_resp))
            }
        }
    }

    async fn logout(
        &self,
        request: Request<LogoutRequest>,
    ) -> Result<Response<LogoutResponse>, Status> {
        let req = request.into_inner();
        
        // 获取认证服务实例
        let auth_service = di::inject::<JwtAuthService<MemoryUserRepository, MemoryTokenRepository>>();
        
        // 调用业务层函数
        match auth_functions::revoke_token(auth_service, req.token).await {
            Ok(_) => {
                let grpc_resp = LogoutResponse {
                    success: true,
                    error: String::new(),
                };
                Ok(Response::new(grpc_resp))
            },
            Err(e) => {
                let grpc_resp = LogoutResponse {
                    success: false,
                    error: e.to_string(),
                };
                Ok(Response::new(grpc_resp))
            }
        }
    }

    // ===== CRUD相关gRPC方法 =====

    async fn create_item(
        &self,
        request: Request<CreateItemRequest>,
    ) -> Result<Response<CreateItemResponse>, Status> {
        let proto_req = request.into_inner();
        tracing::info!("➕ 收到创建项目请求: name={}, value={}", proto_req.name, proto_req.value);
        
        // 获取CRUD服务实例
        let crud_service = di::inject::<SqliteCrudService<crate::slices::mvp_crud::service::SqliteItemRepository<SqliteDatabase>, MemoryCache>>();
        
        // 转换gRPC请求到内部类型
        let internal_req = proto_req.into();
        
        // 调用业务层函数
        match crud_functions::create_item(crud_service, internal_req).await {
            Ok(internal_resp) => {
                tracing::info!("➕ 创建项目成功: id={}, name={}", internal_resp.item.id, internal_resp.item.name);
                Ok(Response::new(internal_resp.into()))
            },
            Err(e) => {
                tracing::error!("➕ 创建项目失败: {}", e);
                Ok(Response::new(e.into()))
            }
        }
    }

    async fn get_item(
        &self,
        request: Request<GetItemRequest>,
    ) -> Result<Response<GetItemResponse>, Status> {
        let proto_req = request.into_inner();
        
        // 获取CRUD服务实例
        let crud_service = di::inject::<SqliteCrudService<crate::slices::mvp_crud::service::SqliteItemRepository<SqliteDatabase>, MemoryCache>>();
        
        // 调用业务层函数
        match crud_functions::get_item(crud_service, proto_req.id).await {
            Ok(internal_resp) => Ok(Response::new(internal_resp.into())),
            Err(e) => Ok(Response::new(e.into())),
        }
    }

    async fn update_item(
        &self,
        request: Request<UpdateItemRequest>,
    ) -> Result<Response<UpdateItemResponse>, Status> {
        let proto_req = request.into_inner();
        
        // 获取CRUD服务实例
        let crud_service = di::inject::<SqliteCrudService<crate::slices::mvp_crud::service::SqliteItemRepository<SqliteDatabase>, MemoryCache>>();
        
        // 转换gRPC请求到内部类型
        let (id, internal_req) = proto_req.into();
        
        // 调用业务层函数
        match crud_functions::update_item(crud_service, id, internal_req).await {
            Ok(internal_resp) => Ok(Response::new(internal_resp.into())),
            Err(e) => Ok(Response::new(e.into())),
        }
    }

    async fn delete_item(
        &self,
        request: Request<DeleteItemRequest>,
    ) -> Result<Response<DeleteItemResponse>, Status> {
        let proto_req = request.into_inner();
        
        // 获取CRUD服务实例
        let crud_service = di::inject::<SqliteCrudService<crate::slices::mvp_crud::service::SqliteItemRepository<SqliteDatabase>, MemoryCache>>();
        
        // 调用业务层函数
        match crud_functions::delete_item(crud_service, proto_req.id).await {
            Ok(internal_resp) => Ok(Response::new(internal_resp.into())),
            Err(e) => Ok(Response::new(e.into())),
        }
    }

    async fn list_items(
        &self,
        request: Request<ListItemsRequest>,
    ) -> Result<Response<ListItemsResponse>, Status> {
        let proto_req = request.into_inner();
        tracing::info!("📋 收到列表项目请求: limit={:?}, offset={:?}", proto_req.limit, proto_req.offset);
        
        // 获取CRUD服务实例
        let crud_service = di::inject::<SqliteCrudService<crate::slices::mvp_crud::service::SqliteItemRepository<SqliteDatabase>, MemoryCache>>();
        
        // 转换gRPC请求到内部类型
        let query = proto_req.into();
        
        // 调用业务层函数
        match crud_functions::list_items(crud_service, query).await {
            Ok(internal_resp) => {
                tracing::info!("📋 列表项目成功: 返回{}个项目，总计{}", internal_resp.items.len(), internal_resp.total);
                Ok(Response::new(internal_resp.into()))
            },
            Err(e) => {
                tracing::error!("📋 列表项目失败: {}", e);
                Ok(Response::new(e.into()))
            }
        }
    }

    // ===== Analytics相关gRPC方法 =====

    async fn analytics_proxy(
        &self,
        request: Request<AnalyticsProxyRequest>,
    ) -> Result<Response<AnalyticsProxyResponse>, Status> {
        let req = request.into_inner();
        tracing::info!("🧮 Analytics代理请求: algorithm={}, data_points={}", 
            req.algorithm, req.data.len());
        
        // 获取Analytics Engine客户端
        let analytics_client = di::inject::<AnalyticsEngineClient>();
        
        // 构建analytics-engine请求
        let analysis_request = crate::analytics::AnalysisRequest {
            request_id: uuid::Uuid::new_v4().to_string(),
            algorithm: req.algorithm.clone(),
            data: req.data.clone(),
            params: req.parameters.clone(),
            options: Some(crate::analytics::AnalysisOptions {
                prefer_rust: true,
                allow_python: true,
                timeout_ms: 30000,
                include_metadata: true,
            }),
        };
        
        // 调用analytics-engine
        match analytics_client.analyze(analysis_request).await {
            Ok(response) => {
                if response.success {
                    tracing::info!("✅ Analytics分析成功: {}", response.request_id);
        Ok(Response::new(AnalyticsProxyResponse {
                        result: response.result_json,
            success: true,
            error: String::new(),
                        metrics: if let Some(metadata) = response.metadata {
                            let mut metrics = std::collections::HashMap::new();
                            metrics.insert("execution_time_ms".to_string(), metadata.execution_time_ms as f64);
                            metrics.insert("data_size".to_string(), metadata.data_size as f64);
                            metrics.insert("implementation".to_string(), 
                                if metadata.implementation == "rust" { 1.0 } else { 0.0 });
                            metrics
                        } else {
                            std::collections::HashMap::new()
                        },
                    }))
                } else {
                    tracing::warn!("⚠️ Analytics分析失败: {}", response.error_message);
                    Err(Status::internal(format!("Analytics分析失败: {}", response.error_message)))
                }
            }
            Err(e) => {
                tracing::error!("❌ Analytics Engine调用失败: {}", e);
                Err(Status::unavailable(format!("Analytics Engine不可用: {}", e)))
            }
        }
    }

    async fn statistics(
        &self,
        request: Request<StatisticsRequest>,
    ) -> Result<Response<StatisticsResponse>, Status> {
        let proto_req = request.into_inner();
        tracing::info!("📊 收到统计分析请求");
        
        // 获取统计服务实例
        let service = di::inject::<ConcreteStatisticsService>();
        
        // 根据请求类型分发处理
        match proto_req.request_type {
            Some(statistics_request::RequestType::GenerateData(proto_data_req)) => {
                // 转换gRPC请求到内部类型
                let internal_req = GenerateRandomDataRequest {
                    count: proto_data_req.count,
                    seed: proto_data_req.seed,
                    min_value: proto_data_req.min_value,
                    max_value: proto_data_req.max_value,
                    distribution: proto_data_req.distribution,
                };
                
                // 调用业务层函数
                match mvp_stat::functions::generate_random_data(service, internal_req).await {
                    Ok(internal_resp) => {
                        tracing::info!("📊 生成随机数据成功: {} 个数据点", internal_resp.count);
                        
                        // 转换响应
                        match convert_generate_data_response(internal_resp) {
                            Ok(proto_resp) => {
                                Ok(Response::new(StatisticsResponse {
                                    response_type: Some(statistics_response::ResponseType::DataResponse(proto_resp)),
                                    success: true,
                                    error: String::new(),
                                }))
                            }
                            Err(e) => Err(e),
                        }
                    },
                    Err(e) => {
                        tracing::error!("📊 生成随机数据失败: {}", e);
                        Ok(Response::new(StatisticsResponse {
                            response_type: None,
                            success: false,
                            error: format!("生成随机数据失败: {}", e),
                        }))
                    }
                }
            },
            Some(statistics_request::RequestType::CalculateStats(proto_stats_req)) => {
                // 转换gRPC请求到内部类型
                let internal_req = CalculateStatisticsRequest {
                    data: proto_stats_req.data,
                    statistics: proto_stats_req.statistics,
                    percentiles: if proto_stats_req.percentiles.is_empty() {
                        None
                    } else {
                        Some(proto_stats_req.percentiles)
                    },
                    use_analytics_engine: proto_stats_req.use_analytics_engine,
                    prefer_rust: proto_stats_req.prefer_rust,
                };
                
                // 调用业务层函数
                match mvp_stat::functions::calculate_statistics(service, internal_req).await {
                    Ok(internal_resp) => {
                        tracing::info!("📊 计算统计量成功，使用实现: {}", internal_resp.implementation);
                        
                        // 转换响应
                        match convert_calculate_stats_response(internal_resp) {
                            Ok(proto_resp) => {
                                Ok(Response::new(StatisticsResponse {
                                    response_type: Some(statistics_response::ResponseType::StatsResponse(proto_resp)),
                                    success: true,
                                    error: String::new(),
                                }))
                            }
                            Err(e) => Err(e),
                        }
                    },
                    Err(e) => {
                        tracing::error!("📊 计算统计量失败: {}", e);
                        Ok(Response::new(StatisticsResponse {
                            response_type: None,
                            success: false,
                            error: format!("计算统计量失败: {}", e),
                        }))
                    }
                }
            },
            Some(statistics_request::RequestType::Comprehensive(proto_comp_req)) => {
                // 转换gRPC请求到内部类型
                let data_config = if let Some(data_cfg) = proto_comp_req.data_config {
                    GenerateRandomDataRequest {
                        count: data_cfg.count,
                        seed: data_cfg.seed,
                        min_value: data_cfg.min_value,
                        max_value: data_cfg.max_value,
                        distribution: data_cfg.distribution,
                    }
                } else {
                    return Err(Status::invalid_argument("缺少数据生成配置"));
                };
                
                let stats_config = if let Some(stats_cfg) = proto_comp_req.stats_config {
                    CalculateStatisticsRequest {
                        data: stats_cfg.data,
                        statistics: stats_cfg.statistics,
                        percentiles: if stats_cfg.percentiles.is_empty() {
                            None
                        } else {
                            Some(stats_cfg.percentiles)
                        },
                        use_analytics_engine: stats_cfg.use_analytics_engine,
                        prefer_rust: stats_cfg.prefer_rust,
                    }
                } else {
                    return Err(Status::invalid_argument("缺少统计计算配置"));
                };
                
                let internal_req = ComprehensiveAnalysisRequest {
                    data_config,
                    stats_config,
                };
                
                // 调用业务层函数
                match mvp_stat::functions::comprehensive_analysis(service, internal_req).await {
                    Ok(internal_resp) => {
                        tracing::info!("📊 综合分析成功: {} 个数据点", internal_resp.data_summary.count);
                        
                        // 转换响应
                        match convert_comprehensive_response(internal_resp) {
                            Ok(proto_resp) => {
                                Ok(Response::new(StatisticsResponse {
                                    response_type: Some(statistics_response::ResponseType::ComprehensiveResponse(proto_resp)),
                                    success: true,
                                    error: String::new(),
                                }))
                            }
                            Err(e) => Err(e),
                        }
                    },
                    Err(e) => {
                        tracing::error!("📊 综合分析失败: {}", e);
                        Ok(Response::new(StatisticsResponse {
                            response_type: None,
                            success: false,
                            error: format!("综合分析失败: {}", e),
                        }))
                    }
                }
            },
            None => {
                tracing::warn!("📊 收到空的统计请求");
                Err(Status::invalid_argument("请求类型不能为空"))
            }
        }
    }
}

// =============================================================================
// 类型转换函数 - 内部类型 ↔ gRPC类型
// =============================================================================

/// 转换用户会话
fn convert_user_session(session: UserSession) -> GrpcUserSession {
    GrpcUserSession {
        token: String::new(), // UserSession不包含token字段，gRPC响应中token需要单独处理
        user_id: session.user_id,
        username: session.username,
        expires_at: session.expires_at.timestamp(),
    }
}

/// 转换生成随机数据响应
fn convert_generate_data_response(internal: GenerateRandomDataResponse) -> Result<GrpcGenerateRandomDataResponse, Status> {
    Ok(GrpcGenerateRandomDataResponse {
        data: internal.data,
        count: internal.count,
        seed: internal.seed,
        generated_at: internal.generated_at.to_rfc3339(),
        performance: Some(proto::PerformanceInfo {
            execution_time_ms: internal.performance.execution_time_ms,
            memory_usage_bytes: internal.performance.memory_usage_bytes,
            implementation: internal.performance.implementation,
            metrics: internal.performance.metrics,
        }),
    })
}

/// 转换计算统计响应
fn convert_calculate_stats_response(internal: CalculateStatisticsResponse) -> Result<GrpcCalculateStatisticsResponse, Status> {
    Ok(GrpcCalculateStatisticsResponse {
        results: Some(convert_statistics_result(internal.results)),
        performance: Some(proto::PerformanceInfo {
            execution_time_ms: internal.performance.execution_time_ms,
            memory_usage_bytes: internal.performance.memory_usage_bytes,
            implementation: internal.performance.implementation,
            metrics: internal.performance.metrics,
        }),
        implementation: internal.implementation,
    })
}

/// 转换综合分析响应
fn convert_comprehensive_response(internal: ComprehensiveAnalysisResponse) -> Result<GrpcComprehensiveAnalysisResponse, Status> {
    Ok(GrpcComprehensiveAnalysisResponse {
        data_summary: Some(proto::DataSummary {
            count: internal.data_summary.count,
            seed: internal.data_summary.seed,
            range: Some(proto::DataRange {
                min: internal.data_summary.range.0,
                max: internal.data_summary.range.1,
            }),
            distribution: internal.data_summary.distribution,
            preview: internal.data_summary.preview,
        }),
        statistics: Some(convert_statistics_result(internal.statistics)),
        performance: Some(proto::PerformanceInfo {
            execution_time_ms: internal.performance.execution_time_ms,
            memory_usage_bytes: internal.performance.memory_usage_bytes,
            implementation: internal.performance.implementation,
            metrics: internal.performance.metrics,
        }),
        analyzed_at: internal.analyzed_at.to_rfc3339(),
    })
}

/// 转换统计结果
fn convert_statistics_result(internal: crate::slices::mvp_stat::types::StatisticsResult) -> proto::StatisticsResult {
    use proto::{
        BasicStatistics as GrpcBasicStats,
        DistributionStatistics as GrpcDistStats,
        PercentileInfo as GrpcPercentileInfo,
        ShapeStatistics as GrpcShapeStats,
    };
    
    proto::StatisticsResult {
        basic: Some(GrpcBasicStats {
            count: internal.basic.count,
            sum: internal.basic.sum,
            mean: internal.basic.mean,
            min: internal.basic.min,
            max: internal.basic.max,
            range: internal.basic.range,
        }),
        distribution: Some(GrpcDistStats {
            median: internal.distribution.median,
            mode: internal.distribution.mode,
            variance: internal.distribution.variance,
            std_dev: internal.distribution.std_dev,
            iqr: internal.distribution.iqr,
        }),
        percentiles: Some(GrpcPercentileInfo {
            q1: internal.percentiles.q1,
            q2: internal.percentiles.q2,
            q3: internal.percentiles.q3,
            custom: internal.percentiles.custom,
        }),
        shape: Some(GrpcShapeStats {
            skewness: internal.shape.skewness,
            kurtosis: internal.shape.kurtosis,
            distribution_shape: internal.shape.distribution_shape,
        }),
    }
}

pub async fn start_grpc_server(
    addr: SocketAddr,
    shutdown_rx: oneshot::Receiver<()>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let grpc_service = BackendGrpcService::new();

    println!("🚀 Backend gRPC server starting on {}", addr);

    Server::builder()
        .add_service(BackendServiceServer::new(grpc_service))
        .serve_with_shutdown(addr, async {
            shutdown_rx.await.ok();
            println!("🛑 Backend gRPC server shutting down gracefully");
        })
        .await?;

    Ok(())
} 