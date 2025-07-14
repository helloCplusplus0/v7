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
use crate::infra::{di, cache::MemoryCache, db::SqliteDatabase};

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
        
        // 获取统计服务实例并直接调用Analytics Engine
        let _service = di::inject::<ConcreteStatisticsService>();
        
        // 这里可以实现直接的Analytics Engine代理调用
        // 暂时返回简单响应
        Ok(Response::new(AnalyticsProxyResponse {
            result: format!("{{\"algorithm\": \"{}\", \"data_points\": {}}}", req.algorithm, req.data.len()),
            success: true,
            error: String::new(),
            metrics: std::collections::HashMap::new(),
        }))
    }

    async fn statistics(
        &self,
        request: Request<StatisticsRequest>,
    ) -> Result<Response<StatisticsResponse>, Status> {
        let req = request.into_inner();
        
        // 获取统计服务实例
        let service = di::inject::<ConcreteStatisticsService>();
        
        match req.request_type {
            Some(statistics_request::RequestType::GenerateData(grpc_req)) => {
                // 转换gRPC请求到内部类型
                let internal_req = GenerateRandomDataRequest {
                    count: grpc_req.count,
                    seed: grpc_req.seed,
                    min_value: grpc_req.min_value,
                    max_value: grpc_req.max_value,
                    distribution: grpc_req.distribution,
                };
                
                match mvp_stat::generate_random_data(service, internal_req).await {
                    Ok(internal_resp) => {
                        let grpc_resp = convert_generate_data_response(internal_resp)?;
                        Ok(Response::new(StatisticsResponse {
                            response_type: Some(statistics_response::ResponseType::DataResponse(grpc_resp)),
                            success: true,
                            error: String::new(),
                        }))
                    },
                    Err(e) => Ok(Response::new(StatisticsResponse {
                        response_type: None,
                        success: false,
                        error: e.to_string(),
                    })),
                }
            },
            
            Some(statistics_request::RequestType::CalculateStats(grpc_req)) => {
                // 转换gRPC请求到内部类型
                let internal_req = CalculateStatisticsRequest {
                    data: grpc_req.data,
                    statistics: grpc_req.statistics,
                    percentiles: if grpc_req.percentiles.is_empty() { None } else { Some(grpc_req.percentiles) },
                    use_analytics_engine: grpc_req.use_analytics_engine,
                    prefer_rust: grpc_req.prefer_rust,
                };
                
                match mvp_stat::calculate_statistics(service, internal_req).await {
                    Ok(internal_resp) => {
                        let grpc_resp = convert_calculate_stats_response(internal_resp)?;
                        Ok(Response::new(StatisticsResponse {
                            response_type: Some(statistics_response::ResponseType::StatsResponse(grpc_resp)),
                            success: true,
                            error: String::new(),
                        }))
                    },
                    Err(e) => Ok(Response::new(StatisticsResponse {
                        response_type: None,
                        success: false,
                        error: e.to_string(),
                    })),
                }
            },
            
            Some(statistics_request::RequestType::Comprehensive(grpc_req)) => {
                // 转换gRPC请求到内部类型
                let data_config = grpc_req.data_config.ok_or_else(|| Status::invalid_argument("missing data_config"))?;
                let stats_config = grpc_req.stats_config.ok_or_else(|| Status::invalid_argument("missing stats_config"))?;
                
                let internal_req = ComprehensiveAnalysisRequest {
                    data_config: GenerateRandomDataRequest {
                        count: data_config.count,
                        seed: data_config.seed,
                        min_value: data_config.min_value,
                        max_value: data_config.max_value,
                        distribution: data_config.distribution,
                    },
                    stats_config: CalculateStatisticsRequest {
                        data: stats_config.data,
                        statistics: stats_config.statistics,
                        percentiles: if stats_config.percentiles.is_empty() { None } else { Some(stats_config.percentiles) },
                        use_analytics_engine: stats_config.use_analytics_engine,
                        prefer_rust: stats_config.prefer_rust,
                    },
                };
                
                match mvp_stat::comprehensive_analysis(service, internal_req).await {
                    Ok(internal_resp) => {
                        let grpc_resp = convert_comprehensive_response(internal_resp)?;
                        Ok(Response::new(StatisticsResponse {
                            response_type: Some(statistics_response::ResponseType::ComprehensiveResponse(grpc_resp)),
                            success: true,
                            error: String::new(),
                        }))
                    },
                    Err(e) => Ok(Response::new(StatisticsResponse {
                        response_type: None,
                        success: false,
                        error: e.to_string(),
                    })),
                }
            },
            
            None => {
                Err(Status::invalid_argument("缺少请求类型"))
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
    use proto::{PerformanceInfo as GrpcPerformanceInfo};
    
    Ok(GrpcGenerateRandomDataResponse {
        data: internal.data,
        count: internal.count,
        seed: internal.seed,
        generated_at: internal.generated_at.to_rfc3339(),
        performance: Some(GrpcPerformanceInfo {
            execution_time_ms: internal.performance.execution_time_ms,
            memory_usage_bytes: internal.performance.memory_usage_bytes,
            implementation: internal.performance.implementation,
            metrics: internal.performance.metrics,
        }),
    })
}

/// 转换计算统计响应
fn convert_calculate_stats_response(internal: CalculateStatisticsResponse) -> Result<GrpcCalculateStatisticsResponse, Status> {
    use proto::{PerformanceInfo as GrpcPerformanceInfo};
    
    Ok(GrpcCalculateStatisticsResponse {
        results: Some(convert_statistics_result(internal.results)),
        implementation: internal.implementation,
        performance: Some(GrpcPerformanceInfo {
            execution_time_ms: internal.performance.execution_time_ms,
            memory_usage_bytes: internal.performance.memory_usage_bytes,
            implementation: internal.performance.implementation,
            metrics: internal.performance.metrics,
        }),
    })
}

/// 转换综合分析响应
fn convert_comprehensive_response(internal: ComprehensiveAnalysisResponse) -> Result<GrpcComprehensiveAnalysisResponse, Status> {
    use proto::{DataSummary as GrpcDataSummary, DataRange as GrpcDataRange, PerformanceInfo as GrpcPerformanceInfo};
    
    Ok(GrpcComprehensiveAnalysisResponse {
        data_summary: Some(GrpcDataSummary {
            count: internal.data_summary.count,
            seed: internal.data_summary.seed,
            range: Some(GrpcDataRange {
                min: internal.data_summary.range.0,
                max: internal.data_summary.range.1,
            }),
            distribution: internal.data_summary.distribution,
            preview: internal.data_summary.preview,
        }),
        statistics: Some(convert_statistics_result(internal.statistics)),
        analyzed_at: internal.analyzed_at.to_rfc3339(),
        performance: Some(GrpcPerformanceInfo {
            execution_time_ms: internal.performance.execution_time_ms,
            memory_usage_bytes: internal.performance.memory_usage_bytes,
            implementation: internal.performance.implementation,
            metrics: internal.performance.metrics,
        }),
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