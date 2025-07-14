use axum::{
    extract::Json,
    routing::get,
    Router,
};
use fmod_slice::grpc_layer::BackendGrpcService;
use fmod_slice::v7_backend::backend_service_server::BackendServiceServer;
use tonic::transport::Server;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use fmod_slice::infra::cache::MemoryCache;
use fmod_slice::infra::db::{migrations::setup_migrations, SqliteDatabase};
use fmod_slice::infra::di;
use fmod_slice::slices::auth::{
    service::{JwtAuthService, MemoryTokenRepository, MemoryUserRepository},
};
use fmod_slice::slices::mvp_crud::{
    interfaces::ItemRepository,
    service::{SqliteCrudService, SqliteItemRepository},
};
use tower::Layer;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // 🔧 修复：显式加载环境配置文件 - 在日志初始化之前
    load_environment_config();
    
    // 初始化日志
    tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer())
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    tracing::info!("🚀 v7架构服务启动中 - 纯gRPC模式");

    // 设置服务
    setup_services().await;
    
    // 启动HTTP健康检查服务器（轻量）
    let health_listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
    
    // 启动gRPC服务器（主要服务）
    let grpc_addr = "0.0.0.0:50053".parse()?;

    tracing::info!("🏥 v7架构健康检查服务启动在 http://0.0.0.0:3000/health");
    tracing::info!("🚀 v7架构主gRPC服务器启动在 grpc://0.0.0.0:50053 (支持gRPC + gRPC-Web)");
    tracing::info!("✅ 静态分发+泛型架构已激活 - gRPC/gRPC-Web双协议模式");

    // 并行启动服务
    tokio::try_join!(
        // 轻量HTTP健康检查服务
        async {
            let health_router = Router::new()
                .route("/health", get(health_check))
                .route("/metrics", get(metrics_endpoint));
            
            tracing::info!("健康检查服务就绪");
            axum::serve(health_listener, health_router).await
                .map_err(|e| anyhow::anyhow!("健康检查服务错误: {}", e))
        },
        
        // 主gRPC服务器 (同时支持gRPC和gRPC-Web)
        async {
            let grpc_service = BackendServiceServer::new(BackendGrpcService::new());
            
            tracing::info!("gRPC服务就绪 (支持gRPC + gRPC-Web)");
            
            // 配置CORS层 - 完整支持ConnectRPC和gRPC-Web
            use tower_http::cors::{CorsLayer, Any};
            use axum::http::{Method, HeaderValue};
            
            let cors = CorsLayer::new()
                .allow_origin(tower_http::cors::AllowOrigin::predicate(|origin: &HeaderValue, _| {
                    let origin_str = origin.to_str().unwrap_or("");
                    // 允许的来源列表
                    matches!(origin_str, 
                        "http://192.168.31.84:5173" | 
                        "http://localhost:5173" | 
                        "http://127.0.0.1:5173"
                    )
                }))
                .allow_methods([Method::GET, Method::POST, Method::OPTIONS])
                .allow_headers([
                    // 标准HTTP headers
                    axum::http::header::HeaderName::from_static("content-type"),
                    axum::http::header::HeaderName::from_static("authorization"),
                    axum::http::header::HeaderName::from_static("x-user-agent"),
                    
                    // ConnectRPC所需headers
                    axum::http::header::HeaderName::from_static("connect-protocol-version"),
                    axum::http::header::HeaderName::from_static("connect-timeout-ms"),
                    
                    // gRPC-Web所需headers
                    axum::http::header::HeaderName::from_static("x-grpc-web"),
                    axum::http::header::HeaderName::from_static("grpc-timeout"),
                    
                    // 其他可能需要的headers
                    axum::http::header::HeaderName::from_static("accept"),
                    axum::http::header::HeaderName::from_static("accept-encoding"),
                    axum::http::header::HeaderName::from_static("user-agent"),
                ])
                .expose_headers(vec![
                    // gRPC响应headers
                    axum::http::header::HeaderName::from_static("grpc-status"),
                    axum::http::header::HeaderName::from_static("grpc-message"),
                    axum::http::header::HeaderName::from_static("grpc-status-details-bin"),
                    
                    // ConnectRPC响应headers
                    axum::http::header::HeaderName::from_static("connect-protocol-version"),
                    
                    // 其他可能需要的响应headers
                    axum::http::header::HeaderName::from_static("content-length"),
                    axum::http::header::HeaderName::from_static("date"),
                ])
                .max_age(std::time::Duration::from_secs(86400));
            
            Server::builder()
                .accept_http1(true)
                // 启用HTTP/1.1支持gRPC-Web
                .layer(cors) // 先添加CORS层
                .layer(tonic_web::GrpcWebLayer::new()) // 然后添加gRPC-Web层
                .add_service(grpc_service)
                .serve(grpc_addr)
                .await
                .map_err(|e| anyhow::anyhow!("gRPC服务器错误: {}", e))
        }
    )?;

    Ok(())
}

/// 🔧 加载环境配置文件
fn load_environment_config() {
    // 配置加载已经在 Config::from_env() 中处理了
    // 这里只需要打印调试信息
    
    // 打印关键配置信息用于调试
    if let Ok(db_url) = std::env::var("DATABASE_URL") {
        println!("📊 数据库配置: {}", db_url);
    } else {
        println!("📊 数据库配置: 使用默认值");
    }
    
    if let Ok(create_test_data) = std::env::var("CREATE_TEST_DATA") {
        println!("🔧 测试数据创建: {}", create_test_data);
    } else {
        println!("🔧 测试数据创建: 使用默认值");
    }
}

/// ⭐ v7服务注册 - 支持静态分发的依赖注入
async fn setup_services() {
    // 创建认证服务实例 - v7设计：直接使用具体类型，无需Arc包装
    let user_repo = MemoryUserRepository::new();
    let token_repo = MemoryTokenRepository::new();
    let auth_service = JwtAuthService::new(user_repo, token_repo);

    // 创建CRUD服务实例 - 使用真实的SQLite数据库
    let config = fmod_slice::infra::config::config();
    let database_url = config.database_url();

    let db = if database_url.starts_with("sqlite:") {
        if database_url == "sqlite::memory:" {
            let db = SqliteDatabase::memory().expect("无法创建SQLite内存数据库");
            tracing::info!("🗄️ 创建SQLite内存数据库: {}", db.file_path());
            db
        } else {
            let file_path = database_url
                .strip_prefix("sqlite:")
                .unwrap_or(&database_url);
            let db = SqliteDatabase::new(file_path).expect("无法创建SQLite文件数据库");
            tracing::info!("🗄️ 创建SQLite文件数据库: {}", db.file_path());
            db
        }
    } else {
        panic!("目前仅支持SQLite数据库");
    };

    let crud_repository = SqliteItemRepository::new(db.clone());

    // 🔧 执行数据库迁移
    let migration_manager = setup_migrations();
    if let Err(e) = migration_manager.migrate(&db).await {
        tracing::error!("数据库迁移失败: {}", e);
        panic!("无法执行数据库迁移");
    }
    tracing::info!("✅ 数据库迁移完成");

    // 🔧 只在首次启动且数据库为空时创建测试数据
    // 使用环境变量控制是否创建测试数据
    let should_create_test_data = std::env::var("CREATE_TEST_DATA")
        .map(|v| v.to_lowercase() == "true")
        .unwrap_or(false);

    match crud_repository.count().await {
        Ok(count) if count == 0 && should_create_test_data => {
            tracing::info!("数据库为空且启用测试数据创建，创建测试数据...");
            let test_items = vec![
                fmod_slice::slices::mvp_crud::types::Item::new(
                    "test-item-1".to_string(),
                    "测试项目 1".to_string(),
                    Some("这是第一个测试项目".to_string()),
                    100,
                ),
                fmod_slice::slices::mvp_crud::types::Item::new(
                    "test-item-2".to_string(),
                    "测试项目 2".to_string(),
                    Some("这是第二个测试项目".to_string()),
                    200,
                ),
                fmod_slice::slices::mvp_crud::types::Item::new(
                    "test-item-3".to_string(),
                    "测试项目 3".to_string(),
                    Some("这是第三个测试项目".to_string()),
                    300,
                ),
            ];

            for item in test_items {
                if let Err(e) = crud_repository.save(&item).await {
                    tracing::warn!("创建测试数据失败: {}", e);
                }
            }
            tracing::info!("✅ 测试数据创建完成");
        }
        Ok(0) => {
            tracing::info!("数据库为空，但未启用测试数据创建 (设置 CREATE_TEST_DATA=true 来启用)");
        }
        Ok(count) => {
            tracing::info!("数据库已有 {} 个项目，跳过测试数据创建", count);
        }
        Err(e) => {
            tracing::warn!("检查数据库项目数量失败: {}", e);
        }
    }

    let cache = MemoryCache::new();
    let crud_service = SqliteCrudService::new(crud_repository, cache);

    // 创建统计分析服务实例
    let random_generator = fmod_slice::slices::mvp_stat::service::DefaultRandomDataGenerator::new();
    let analytics_client = fmod_slice::slices::mvp_stat::service::GrpcAnalyticsClient::new(
        "http://localhost:50051".to_string() // Analytics Engine地址 - 修复端口号
    );
    let dispatcher = fmod_slice::slices::mvp_stat::service::DefaultIntelligentDispatcher::new(
        analytics_client.clone()
    );
    let stat_service = fmod_slice::slices::mvp_stat::service::DefaultStatisticsService::new(
        random_generator,
        analytics_client,
        dispatcher
    );

    // 注册到DI容器
    di::register(auth_service);
    di::register(crud_service);
    di::register(stat_service);

    tracing::info!("✅ 服务注册完成 - v7静态分发模式");
    tracing::info!("   - 认证服务: JwtAuthService");
    tracing::info!("   - CRUD服务: SqliteCrudService");
    tracing::info!("   - 统计服务: DefaultStatisticsService");
}

async fn health_check() -> impl axum::response::IntoResponse {
    Json(serde_json::json!({
        "status": "healthy",
        "service": "v7-backend-grpc",
        "timestamp": chrono::Utc::now(),
        "version": env!("CARGO_PKG_VERSION"),
        "architecture": "FMOD v7 - 纯gRPC模式"
    }))
}

async fn metrics_endpoint() -> impl axum::response::IntoResponse {
    Json(serde_json::json!({
        "grpc_connections": "active",
        "analytics_engine": "connected", 
        "uptime": "tracking",
        "mode": "pure-grpc"
    }))
}
