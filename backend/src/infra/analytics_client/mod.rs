// backend/src/infra/analytics_client/mod.rs
//! 🧮 Analytics Engine客户端连接管理器
//!
//! 本模块负责管理与analytics-engine服务的gRPC连接和通信。
//! 
//! ## 架构说明
//! - **本地开发**：直接连接到127.0.0.1:50051
//! - **生产部署**：通过WireGuard VPN连接到10.0.0.1:50051 (analytics-engine在192.168.31.84)
//! 
//! ## 通信特点
//! - **主从关系**：backend(主) → analytics-engine(从)
//! - **调用方式**：按需调用，无主动通信
//! - **连接管理**：自动重连、超时处理、健康检查
//! 
//! ## 使用示例
//! ```rust
//! let client = inject::<AnalyticsEngineClient>();
//! let response = client.analyze(request).await?;
//! ```

use anyhow::Result;
use std::time::Duration;
use tonic::transport::{Channel, Endpoint};
use tonic::Request;
use tracing::{info, warn, error, debug};
use std::sync::Arc;
use tokio::sync::RwLock;

// 引入analytics相关proto定义
use crate::analytics::{
    analytics_engine_client::AnalyticsEngineClient as GrpcAnalyticsEngineClient,
    AnalysisRequest, AnalysisResponse,
    HealthCheckRequest, HealthCheckResponse,
};

/// Analytics Engine客户端连接管理器
/// 
/// 功能特性：
/// - 自动连接管理和重连机制
/// - 请求超时和连接超时控制
/// - 健康检查和连接状态监控
/// - 线程安全的连接池
#[derive(Clone)]
pub struct AnalyticsEngineClient {
    /// gRPC客户端连接（懒加载）
    client: Arc<RwLock<Option<GrpcAnalyticsEngineClient<Channel>>>>,
    /// analytics-engine服务端点
    endpoint: String,
    /// 连接超时时间
    connection_timeout: Duration,
    /// 请求超时时间
    request_timeout: Duration,
}

impl AnalyticsEngineClient {
    /// 创建新的Analytics Engine客户端
    /// 
    /// # 参数
    /// - `endpoint`: analytics-engine服务地址 (如: http://127.0.0.1:50051)
    pub fn new(endpoint: String) -> Self {
        Self {
            client: Arc::new(RwLock::new(None)),
            endpoint,
            connection_timeout: Duration::from_secs(10),
            request_timeout: Duration::from_secs(30),
        }
    }

    /// 从环境配置创建客户端
    pub fn from_config() -> Result<Self> {
        let endpoint = std::env::var("ANALYTICS_ENGINE_ENDPOINT")
            .unwrap_or_else(|_| "http://127.0.0.1:50051".to_string());
        
        let connection_timeout = std::env::var("ANALYTICS_CONNECTION_TIMEOUT_SEC")
            .unwrap_or_else(|_| "10".to_string())
            .parse::<u64>()
            .unwrap_or(10);
            
        let request_timeout = std::env::var("ANALYTICS_REQUEST_TIMEOUT_SEC")
            .unwrap_or_else(|_| "30".to_string())
            .parse::<u64>()
            .unwrap_or(30);
        
        info!("🧮 创建Analytics Engine客户端: {}", endpoint);
        
        Ok(Self {
            client: Arc::new(RwLock::new(None)),
            endpoint,
            connection_timeout: Duration::from_secs(connection_timeout),
            request_timeout: Duration::from_secs(request_timeout),
        })
    }

    /// 获取或创建gRPC连接
    async fn get_client(&self) -> Result<GrpcAnalyticsEngineClient<Channel>> {
        // 检查现有连接
        {
            let client_guard = self.client.read().await;
            if let Some(client) = client_guard.as_ref() {
                return Ok(client.clone());
            }
        }

        // 创建新连接
        debug!("🔗 建立Analytics Engine连接: {}", self.endpoint);
        
        let endpoint = Endpoint::from_shared(self.endpoint.clone())?
            .timeout(self.connection_timeout)
            .tcp_keepalive(Some(Duration::from_secs(60)));

        let channel = endpoint.connect().await.map_err(|e| {
            error!("❌ Analytics Engine连接失败: {}", e);
            anyhow::anyhow!("连接Analytics Engine失败: {}", e)
        })?;

        let client = GrpcAnalyticsEngineClient::new(channel)
            .max_decoding_message_size(16 * 1024 * 1024)  // 16MB
            .max_encoding_message_size(16 * 1024 * 1024); // 16MB

        // 缓存连接
        {
            let mut client_guard = self.client.write().await;
            *client_guard = Some(client.clone());
        }

        info!("✅ Analytics Engine连接已建立");
        Ok(client)
    }

    /// 执行算法分析
    /// 
    /// # 参数
    /// - `request`: 分析请求
    /// 
    /// # 返回
    /// 成功时返回分析结果，失败时返回错误
    pub async fn analyze(&self, request: AnalysisRequest) -> Result<AnalysisResponse> {
        let mut client = self.get_client().await?;
        
        debug!("🧮 执行算法分析: {}", request.algorithm);
        
        let response = tokio::time::timeout(
            self.request_timeout,
            client.analyze(Request::new(request))
        ).await.map_err(|_| {
            warn!("⏰ Analytics请求超时");
            anyhow::anyhow!("Analytics请求超时")
        })?.map_err(|e| {
            error!("❌ Analytics分析失败: {}", e);
            
            // 连接错误时清除缓存的连接
            if e.code() == tonic::Code::Unavailable {
                let client_arc = self.client.clone();
                tokio::spawn(async move {
                    let mut client_guard = client_arc.write().await;
                    *client_guard = None;
                });
            }
            
            anyhow::anyhow!("Analytics分析失败: {}", e)
        })?;

        let analysis_response = response.into_inner();
        
        if analysis_response.success {
            debug!("✅ Analytics分析完成: {}", analysis_response.request_id);
        } else {
            warn!("⚠️ Analytics分析失败: {}", analysis_response.error_message);
        }
        
        Ok(analysis_response)
    }

    /// 健康检查
    /// 
    /// 检查analytics-engine服务是否可用
    pub async fn health_check(&self) -> Result<bool> {
        let mut client = self.get_client().await?;
        
        let response = tokio::time::timeout(
            Duration::from_secs(5), // 健康检查使用较短超时
            client.health_check(Request::new(HealthCheckRequest {}))
        ).await.map_err(|_| {
            anyhow::anyhow!("健康检查超时")
        })?.map_err(|e| {
            anyhow::anyhow!("健康检查失败: {}", e)
        })?;

        let health_response = response.into_inner();
        Ok(health_response.healthy)
    }

    /// 获取连接状态
    pub async fn is_connected(&self) -> bool {
        let client_guard = self.client.read().await;
        client_guard.is_some()
    }

    /// 断开连接
    pub async fn disconnect(&self) {
        let mut client_guard = self.client.write().await;
        *client_guard = None;
        info!("🔌 Analytics Engine连接已断开");
    }
}

/// Analytics Engine客户端工厂
pub struct AnalyticsEngineClientFactory;

impl AnalyticsEngineClientFactory {
    /// 从配置创建客户端实例
    pub fn create_from_config() -> Result<AnalyticsEngineClient> {
        AnalyticsEngineClient::from_config()
    }
    
    /// 创建开发环境客户端
    pub fn create_dev() -> AnalyticsEngineClient {
        AnalyticsEngineClient::new("http://127.0.0.1:50051".to_string())
    }
    
    /// 创建生产环境客户端（WireGuard VPN）
    pub fn create_prod() -> AnalyticsEngineClient {
        AnalyticsEngineClient::new("http://10.0.0.1:50051".to_string())
    }
} 