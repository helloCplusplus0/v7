use anyhow::Result;
use dotenvy::dotenv;
use std::net::SocketAddr;
use tonic::transport::Server;
use tracing::{info, warn};
use tracing_subscriber;

use analytics_engine::api::grpc_service::AnalyticsService;

#[tokio::main]
async fn main() -> Result<()> {
    // 初始化日志
    tracing_subscriber::fmt::init();
    
    // 加载环境变量
    dotenv().ok();
    
    info!("Starting Analytics Engine v{}", analytics_engine::VERSION);
    
    // 初始化Python桥接（如果启用）
    #[cfg(feature = "python-bridge")]
    {
        match analytics_engine::python_bridge::dispatcher::initialize_python() {
            Ok(_) => info!("Python bridge initialized successfully"),
            Err(e) => warn!("Python bridge initialization failed: {}", e),
        }
    }
    
    // 创建gRPC服务
    let analytics_service = AnalyticsService::new();
    let server = analytics_service.into_server();
    
    // 获取监听地址和模式
    let socket_path = std::env::var("ANALYTICS_SOCKET_PATH").ok();
    let listen_addr = std::env::var("ANALYTICS_LISTEN_ADDR")
        .unwrap_or_else(|_| "0.0.0.0:50051".to_string());
    
    // 检查是否使用Unix Domain Socket
    if let Some(socket_path) = socket_path {
        if std::path::Path::new(&socket_path).exists() {
            std::fs::remove_file(&socket_path)?;
        }
        
        info!("Starting gRPC server on Unix socket: {}", socket_path);
        
        #[cfg(unix)]
        {
            warn!("Unix socket mode not fully implemented, falling back to TCP");
            let addr: SocketAddr = "127.0.0.1:50051".parse()?;
            info!("Starting gRPC server on TCP fallback: {}", addr);
            
            Server::builder()
                .add_service(server)
                .serve_with_shutdown(addr, shutdown_signal())
                .await?;
        }
        
        #[cfg(not(unix))]
        {
            warn!("Unix Domain Sockets not supported on this platform, falling back to TCP");
            let addr: SocketAddr = "127.0.0.1:50051".parse()?;
            info!("Starting gRPC server on TCP fallback: {}", addr);
            
            Server::builder()
                .add_service(server)
                .serve_with_shutdown(addr, shutdown_signal())
                .await?;
        }
    } else {
        // 使用TCP监听
        let addr: SocketAddr = listen_addr.parse()?;
        info!("Starting gRPC server on TCP: {}", addr);
        
        Server::builder()
            .add_service(server)
            .serve_with_shutdown(addr, shutdown_signal())
            .await?;
    }
    
    info!("Analytics Engine server stopped");
    Ok(())
}

async fn shutdown_signal() {
    use tokio::signal;
    
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };
    
    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };
    
    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();
    
    tokio::select! {
        _ = ctrl_c => {
            info!("Received Ctrl+C signal, shutting down gracefully...");
        },
        _ = terminate => {
            info!("Received SIGTERM signal, shutting down gracefully...");
        },
    }
} 