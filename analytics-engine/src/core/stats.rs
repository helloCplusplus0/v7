use anyhow::{Result, anyhow};
use serde_json::json;
use std::collections::HashMap;
use crate::api::{AnalysisRequest, AnalysisResult, ExecutionMetadata};

/// Rust实现的统计分析
pub async fn analyze_rust(request: &AnalysisRequest) -> Result<AnalysisResult> {
    let start = std::time::Instant::now();
    
    if request.data.is_empty() {
        return Err(anyhow!("Empty data"));
    }
    
    let result_value = match request.algorithm.as_str() {
        "mean" => json!(calculate_mean(&request.data)?),
        "median" => json!(calculate_median(&request.data)?),
        "std" => json!(calculate_std(&request.data)?),
        "variance" => json!(calculate_variance(&request.data)?),
        "min" => json!(calculate_min(&request.data)?),
        "max" => json!(calculate_max(&request.data)?),
        "range" => json!(calculate_range(&request.data)?),
        "correlation" => json!(calculate_autocorrelation(&request.data)?),
        "percentile" => {
            let p = request.params.get("percentile")
                .and_then(|s| s.parse::<f64>().ok())
                .unwrap_or(50.0);
            json!(calculate_percentile(&request.data, p)?)
        },
        "summary" => json!(calculate_summary_stats(&request.data)?),
        _ => return Err(anyhow!("Algorithm '{}' not implemented in Rust", request.algorithm))
    };
    
    let duration = start.elapsed();
    
    let mut stats = HashMap::new();
    stats.insert("rust_version".to_string(), env!("CARGO_PKG_VERSION").to_string());
    stats.insert("data_points".to_string(), request.data.len().to_string());
    
    Ok(AnalysisResult {
        result: result_value,
        metadata: ExecutionMetadata {
            implementation: "rust".to_string(),
            execution_time_ms: duration.as_millis() as u64,
            algorithm: request.algorithm.clone(),
            data_size: request.data.len(),
            stats,
        },
    })
}

fn calculate_mean(data: &[f64]) -> Result<f64> {
    if data.is_empty() {
        return Err(anyhow!("Empty data"));
    }
    Ok(data.iter().sum::<f64>() / data.len() as f64)
}

fn calculate_median(data: &[f64]) -> Result<f64> {
    if data.is_empty() {
        return Err(anyhow!("Empty data"));
    }
    
    let mut sorted = data.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
    
    let n = sorted.len();
    if n % 2 == 0 {
        Ok((sorted[n/2 - 1] + sorted[n/2]) / 2.0)
    } else {
        Ok(sorted[n/2])
    }
}

fn calculate_std(data: &[f64]) -> Result<f64> {
    let variance = calculate_variance(data)?;
    Ok(variance.sqrt())
}

fn calculate_variance(data: &[f64]) -> Result<f64> {
    if data.len() < 2 {
        return Err(anyhow!("Need at least 2 data points for variance"));
    }
    
    let mean = calculate_mean(data)?;
    let sum_sq_diff: f64 = data.iter()
        .map(|x| (x - mean).powi(2))
        .sum();
    
    Ok(sum_sq_diff / (data.len() - 1) as f64)
}

fn calculate_min(data: &[f64]) -> Result<f64> {
    data.iter()
        .min_by(|a, b| a.partial_cmp(b).unwrap())
        .copied()
        .ok_or_else(|| anyhow!("Empty data"))
}

fn calculate_max(data: &[f64]) -> Result<f64> {
    data.iter()
        .max_by(|a, b| a.partial_cmp(b).unwrap())
        .copied()
        .ok_or_else(|| anyhow!("Empty data"))
}

fn calculate_range(data: &[f64]) -> Result<f64> {
    let min = calculate_min(data)?;
    let max = calculate_max(data)?;
    Ok(max - min)
}

fn calculate_percentile(data: &[f64], percentile: f64) -> Result<f64> {
    if data.is_empty() {
        return Err(anyhow!("Empty data"));
    }
    if !(0.0..=100.0).contains(&percentile) {
        return Err(anyhow!("Percentile must be between 0 and 100"));
    }
    
    let mut sorted = data.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
    
    let index = (percentile / 100.0) * (sorted.len() - 1) as f64;
    let lower = index.floor() as usize;
    let upper = index.ceil() as usize;
    
    if lower == upper {
        Ok(sorted[lower])
    } else {
        let weight = index - lower as f64;
        Ok(sorted[lower] * (1.0 - weight) + sorted[upper] * weight)
    }
}

fn calculate_autocorrelation(data: &[f64]) -> Result<f64> {
    if data.len() < 2 {
        return Err(anyhow!("Need at least 2 data points for autocorrelation"));
    }
    
    let mean = calculate_mean(data)?;
    let n = data.len();
    
    // 计算lag-1自相关
    let mut numerator = 0.0;
    let mut denominator = 0.0;
    
    for i in 0..n-1 {
        numerator += (data[i] - mean) * (data[i+1] - mean);
    }
    
    for &x in data {
        denominator += (x - mean).powi(2);
    }
    
    if denominator == 0.0 {
        return Ok(0.0);
    }
    
    Ok(numerator / denominator)
}

fn calculate_summary_stats(data: &[f64]) -> Result<serde_json::Value> {
    Ok(json!({
        "count": data.len(),
        "mean": calculate_mean(data)?,
        "median": calculate_median(data)?,
        "std": calculate_std(data)?,
        "variance": calculate_variance(data)?,
        "min": calculate_min(data)?,
        "max": calculate_max(data)?,
        "range": calculate_range(data)?,
        "q25": calculate_percentile(data, 25.0)?,
        "q75": calculate_percentile(data, 75.0)?,
        "autocorr": calculate_autocorrelation(data)?,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_basic_stats() {
        let data = vec![1.0, 2.0, 3.0, 4.0, 5.0];
        
        assert_eq!(calculate_mean(&data).unwrap(), 3.0);
        assert_eq!(calculate_median(&data).unwrap(), 3.0);
        assert_eq!(calculate_min(&data).unwrap(), 1.0);
        assert_eq!(calculate_max(&data).unwrap(), 5.0);
        assert_eq!(calculate_range(&data).unwrap(), 4.0);
    }
    
    #[tokio::test]
    async fn test_rust_analysis() {
        let request = AnalysisRequest {
            request_id: "test".to_string(),
            algorithm: "mean".to_string(),
            data: vec![1.0, 2.0, 3.0, 4.0, 5.0],
            params: HashMap::new(),
            options: Default::default(),
        };
        
        let result = analyze_rust(&request).await.unwrap();
        assert_eq!(result.result, json!(3.0));
        assert_eq!(result.metadata.implementation, "rust");
    }
} 