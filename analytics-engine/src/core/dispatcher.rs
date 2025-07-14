use anyhow::{Result, anyhow};
use tracing::{info, warn, debug};
use crate::api::{AnalysisRequest, AnalysisResult, AlgorithmInfo};
use crate::core::stats;

/// 主分析函数 - 自动选择最优实现
pub async fn analyze(request: AnalysisRequest) -> Result<AnalysisResult> {
    let start_time = std::time::Instant::now();
    
    debug!("Starting analysis for algorithm: {}", request.algorithm);
    
    // 1. 首先尝试Rust实现（如果启用）
    if request.options.prefer_rust {
        if let Ok(result) = stats::analyze_rust(&request).await {
            info!("Successfully executed {} using Rust implementation in {:?}", 
                  request.algorithm, start_time.elapsed());
            return Ok(result);
        } else {
            debug!("Rust implementation failed or not available for {}", request.algorithm);
        }
    }
    
    // 2. 如果Rust失败且允许Python，尝试Python实现
    #[cfg(feature = "python-bridge")]
    if request.options.allow_python {
        match crate::python_bridge::dispatcher::analyze_python(&request).await {
            Ok(result) => {
                info!("Successfully executed {} using Python implementation in {:?}", 
                      request.algorithm, start_time.elapsed());
                return Ok(result);
            }
            Err(e) => {
                warn!("Python implementation also failed for {}: {}", request.algorithm, e);
            }
        }
    }
    
    // 3. 都失败了
    Err(anyhow!(
        "No implementation available for algorithm '{}'. Rust preferred: {}, Python allowed: {}",
        request.algorithm,
        request.options.prefer_rust,
        request.options.allow_python
    ))
}

/// 获取支持的算法列表
pub fn get_supported_algorithms() -> Vec<AlgorithmInfo> {
    let mut algorithms = vec![
        // Rust实现的算法
        AlgorithmInfo {
            name: "mean".to_string(),
            description: "Calculate arithmetic mean".to_string(),
            implementations: vec!["rust".to_string()],
            required_params: vec![],
            optional_params: vec![],
        },
        AlgorithmInfo {
            name: "median".to_string(),
            description: "Calculate median value".to_string(),
            implementations: vec!["rust".to_string()],
            required_params: vec![],
            optional_params: vec![],
        },
        AlgorithmInfo {
            name: "std".to_string(),
            description: "Calculate standard deviation".to_string(),
            implementations: vec!["rust".to_string()],
            required_params: vec![],
            optional_params: vec![],
        },
        AlgorithmInfo {
            name: "variance".to_string(),
            description: "Calculate variance".to_string(),
            implementations: vec!["rust".to_string()],
            required_params: vec![],
            optional_params: vec![],
        },
        AlgorithmInfo {
            name: "min".to_string(),
            description: "Find minimum value".to_string(),
            implementations: vec!["rust".to_string()],
            required_params: vec![],
            optional_params: vec![],
        },
        AlgorithmInfo {
            name: "max".to_string(),
            description: "Find maximum value".to_string(),
            implementations: vec!["rust".to_string()],
            required_params: vec![],
            optional_params: vec![],
        },
        AlgorithmInfo {
            name: "range".to_string(),
            description: "Calculate range (max - min)".to_string(),
            implementations: vec!["rust".to_string()],
            required_params: vec![],
            optional_params: vec![],
        },
        AlgorithmInfo {
            name: "percentile".to_string(),
            description: "Calculate percentile".to_string(),
            implementations: vec!["rust".to_string()],
            required_params: vec![],
            optional_params: vec!["percentile".to_string()],
        },
        AlgorithmInfo {
            name: "correlation".to_string(),
            description: "Calculate autocorrelation".to_string(),
            implementations: vec!["rust".to_string()],
            required_params: vec![],
            optional_params: vec![],
        },
        AlgorithmInfo {
            name: "summary".to_string(),
            description: "Calculate comprehensive statistics summary".to_string(),
            implementations: vec!["rust".to_string()],
            required_params: vec![],
            optional_params: vec![],
        },
    ];
    
    // 添加Python实现的算法（如果可用）
    #[cfg(feature = "python-bridge")]
    {
        algorithms.extend(crate::python_bridge::dispatcher::get_python_algorithms());
    }
    
    algorithms
}

/// 检查算法是否支持指定实现
pub fn is_algorithm_supported(algorithm: &str, implementation: &str) -> bool {
    get_supported_algorithms()
        .iter()
        .any(|algo| algo.name == algorithm && algo.implementations.contains(&implementation.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use crate::api::AnalysisOptions;
    
    #[tokio::test]
    async fn test_rust_dispatcher() {
        let request = AnalysisRequest {
            request_id: "test-rust".to_string(),
            algorithm: "mean".to_string(),
            data: vec![1.0, 2.0, 3.0, 4.0, 5.0],
            params: HashMap::new(),
            options: AnalysisOptions {
                prefer_rust: true,
                allow_python: false,
                timeout_ms: 5000,
                include_metadata: true,
            },
        };
        
        let result = analyze(request).await.unwrap();
        assert_eq!(result.metadata.implementation, "rust");
        assert_eq!(result.result, serde_json::json!(3.0));
    }
    
    #[test]
    fn test_algorithm_support() {
        assert!(is_algorithm_supported("mean", "rust"));
        assert!(is_algorithm_supported("summary", "rust"));
        assert!(!is_algorithm_supported("nonexistent", "rust"));
    }
    
    #[test]
    fn test_get_algorithms() {
        let algorithms = get_supported_algorithms();
        assert!(!algorithms.is_empty());
        assert!(algorithms.iter().any(|a| a.name == "mean"));
        assert!(algorithms.iter().any(|a| a.name == "summary"));
    }
} 