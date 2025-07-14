use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use anyhow::Result;

/// 分析请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisRequest {
    pub request_id: String,
    pub algorithm: String,
    pub data: Vec<f64>,
    pub params: HashMap<String, String>,
    pub options: AnalysisOptions,
}

/// 分析选项
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisOptions {
    pub prefer_rust: bool,
    pub allow_python: bool,
    pub timeout_ms: i32,
    pub include_metadata: bool,
}

impl Default for AnalysisOptions {
    fn default() -> Self {
        Self {
            prefer_rust: true,
            allow_python: true,
            timeout_ms: 30000, // 30秒默认超时
            include_metadata: true,
        }
    }
}

/// 分析结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub result: serde_json::Value,
    pub metadata: ExecutionMetadata,
}

/// 分析响应
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResponse {
    pub request_id: String,
    pub success: bool,
    pub error_message: Option<String>,
    pub result: Option<AnalysisResult>,
}

/// 执行元数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionMetadata {
    pub implementation: String,     // "rust" or "python"
    pub execution_time_ms: u64,    // 执行时间
    pub algorithm: String,         // 使用的算法
    pub data_size: usize,         // 数据大小
    pub stats: HashMap<String, String>, // 额外统计信息
}

/// 算法信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AlgorithmInfo {
    pub name: String,
    pub description: String,
    pub implementations: Vec<String>, // ["rust", "python"]
    pub required_params: Vec<String>,
    pub optional_params: Vec<String>,
}

/// 分析引擎trait
pub trait AnalysisEngine: Send + Sync {
    async fn analyze(&self, request: AnalysisRequest) -> Result<AnalysisResult>;
    fn get_supported_algorithms(&self) -> Vec<AlgorithmInfo>;
} 