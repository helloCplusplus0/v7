use anyhow::{Result, anyhow};
use pyo3::prelude::*;
use pyo3::types::{PyDict, PyList};
use std::collections::HashMap;
use tracing::{debug, warn, info};
use crate::api::{AnalysisRequest, AnalysisResult, ExecutionMetadata, AlgorithmInfo};

/// Python算法分发器
pub async fn analyze_python(request: &AnalysisRequest) -> Result<AnalysisResult> {
    let start = std::time::Instant::now();
    
    debug!("Attempting Python implementation for algorithm: {}", request.algorithm);
    
    // 在tokio的blocking_task中运行Python代码
    let request_clone = request.clone();
    let result = tokio::task::spawn_blocking(move || {
        execute_python_analysis(&request_clone)
    }).await??;
    
    info!("Python analysis completed in {:?}", start.elapsed());
    Ok(result)
}

/// 执行Python分析（在阻塞线程中）
fn execute_python_analysis(request: &AnalysisRequest) -> Result<AnalysisResult> {
    let start = std::time::Instant::now();
    
    Python::with_gil(|py| {
        // 导入analytics_engine.algorithms模块
        let algorithms_module = py.import("analytics_engine.algorithms")?;
        
        // 获取分析函数
        let analyze_func = algorithms_module.getattr("analyze")?;
        
        // 转换数据
        let data_list = PyList::new(py, &request.data);
        let params_dict = PyDict::new(py);
        for (key, value) in &request.params {
            params_dict.set_item(key, value)?;
        }
        
        // 调用Python函数
        let result = analyze_func.call1((
            request.algorithm.clone(),
            data_list,
            params_dict,
        ))?;
        
        // 解析结果
        let result_dict: &PyDict = result.downcast()
            .map_err(|e| anyhow!("Failed to downcast Python result: {}", e))?;
        let result_item = result_dict.get_item("result")?
            .ok_or_else(|| anyhow!("Missing 'result' field"))?;
        let result_value: serde_json::Value = serde_json::from_str(
            result_item.str().map_err(|e| anyhow!("Python string conversion error: {}", e))?.to_str()?
        )?;
        
        let execution_time = start.elapsed().as_millis() as u64;
        
        // 构建元数据
        let mut stats = HashMap::new();
        stats.insert("python_version".to_string(), 
                     format!("{}.{}.{}", 
                         py.version_info().major,
                         py.version_info().minor,
                         py.version_info().patch));
        stats.insert("data_points".to_string(), 
                     request.data.len().to_string());
        
        // 获取Python端的额外统计信息
        if let Ok(Some(py_stats)) = result_dict.get_item("stats") {
            if let Ok(py_stats_dict) = py_stats.downcast::<PyDict>() {
                for (key, value) in py_stats_dict {
                    if let (Ok(k), Ok(v)) = (key.str(), value.str()) {
                        stats.insert(format!("py_{}", k), v.to_string());
                    }
                }
            }
        }
        
        Ok(AnalysisResult {
            result: result_value,
            metadata: ExecutionMetadata {
                implementation: "python".to_string(),
                execution_time_ms: execution_time,
                algorithm: request.algorithm.clone(),
                data_size: request.data.len(),
                stats,
            },
        })
    })
}

/// 获取Python实现的算法列表
pub fn get_python_algorithms() -> Vec<AlgorithmInfo> {
    match Python::with_gil(|py| -> PyResult<Vec<AlgorithmInfo>> {
        let algorithms_module = py.import("analytics_engine.algorithms")?;
        let get_algorithms_func = algorithms_module.getattr("get_supported_algorithms")?;
        let algorithms_list = get_algorithms_func.call0()?;
        
        let mut algorithms = Vec::new();
        
        for item in algorithms_list.iter()? {
            let algo_dict: &PyDict = item?.downcast()?;
            
            let name = algo_dict.get_item("name")?
                .ok_or_else(|| PyErr::new::<pyo3::exceptions::PyKeyError, _>("Missing 'name'"))?
                .str()?
                .to_string();
                
            let description = algo_dict.get_item("description").unwrap_or(None)
                .map(|d| d.str().map(|s| s.to_str().unwrap_or("").to_string()).unwrap_or_default())
                .unwrap_or_default();
                
            let implementations = vec!["python".to_string()];
            
            let required_params = if let Ok(Some(params_list)) = algo_dict.get_item("required_params") {
                params_list.iter()?
                    .map(|p| p?.str().map(|s| s.to_str().unwrap_or("").to_string()))
                    .collect::<PyResult<Vec<_>>>()?
            } else {
                Vec::new()
            };
            
            let optional_params = if let Ok(Some(params_list)) = algo_dict.get_item("optional_params") {
                params_list.iter()?
                    .map(|p| p?.str().map(|s| s.to_str().unwrap_or("").to_string()))
                    .collect::<PyResult<Vec<_>>>()?
            } else {
                Vec::new()
            };
            
            algorithms.push(AlgorithmInfo {
                name,
                description,
                implementations,
                required_params,
                optional_params,
            });
        }
        
        Ok(algorithms)
    }) {
        Ok(algorithms) => algorithms,
        Err(e) => {
            warn!("Failed to get Python algorithms: {}", e);
            Vec::new()
        }
    }
}

/// 检查Python环境是否可用
pub fn is_python_available() -> bool {
    Python::with_gil(|py| {
        py.import("analytics_engine.algorithms").is_ok()
    })
}

/// 初始化Python模块路径
pub fn initialize_python() -> Result<()> {
    Python::with_gil(|py| {
        // 添加当前项目的Python模块路径
        let sys = py.import("sys")?;
        let path = sys.getattr("path")?;
        
        // 获取项目根目录
        let current_dir = std::env::current_dir()?;
        let python_path = current_dir.join("python");
        
        if python_path.exists() {
            path.call_method1("insert", (0, python_path.to_string_lossy().as_ref()))?;
            info!("Added Python module path: {}", python_path.display());
        }
        
        Ok(())
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::AnalysisOptions;
    
    #[test]
    fn test_python_availability() {
        // 这个测试在没有Python环境时会失败，这是预期的
        let available = is_python_available();
        println!("Python available: {}", available);
    }
    
    #[tokio::test]
    async fn test_python_initialization() {
        let result = initialize_python();
        match result {
            Ok(_) => println!("Python initialization successful"),
            Err(e) => println!("Python initialization failed: {}", e),
        }
    }
} 