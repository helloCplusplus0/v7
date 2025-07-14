//! 基础机器学习算法
//!
//! 提供简单易用的机器学习算法实现，作为Python高级算法的补充

use anyhow::Result;
#[allow(unused_imports)]
use ndarray::{Array1, Array2};
use serde_json::{json, Value};
use std::collections::HashMap;

/// K-均值聚类算法（简化版）
pub fn k_means_clustering(data: &[f64], k: usize, max_iterations: usize) -> Result<Value> {
    if data.is_empty() || k == 0 {
        return Ok(json!({
            "clusters": [],
            "centroids": [],
            "algorithm": "k_means",
            "message": "Empty data or invalid k"
        }));
    }

    // 简化实现：一维数据聚类
    let mut centroids: Vec<f64> = (0..k)
        .map(|i| data[i * data.len() / k])
        .collect();
    
    let mut assignments = vec![0; data.len()];
    
    for _iteration in 0..max_iterations {
        // 分配点到最近的中心
        for (i, &point) in data.iter().enumerate() {
            let mut min_distance = f64::INFINITY;
            let mut best_cluster = 0;
            
            for (j, &centroid) in centroids.iter().enumerate() {
                let distance = (point - centroid).abs();
                if distance < min_distance {
                    min_distance = distance;
                    best_cluster = j;
                }
            }
            assignments[i] = best_cluster;
        }
        
        // 更新中心点
        for j in 0..k {
            let cluster_points: Vec<f64> = data.iter()
                .enumerate()
                .filter(|(i, _)| assignments[*i] == j)
                .map(|(_, &val)| val)
                .collect();
            
            if !cluster_points.is_empty() {
                centroids[j] = cluster_points.iter().sum::<f64>() / cluster_points.len() as f64;
            }
        }
    }
    
    // 计算每个聚类的统计信息
    let mut clusters = Vec::new();
    for cluster_id in 0..k {
        let cluster_points: Vec<f64> = data.iter()
            .enumerate()
            .filter(|(i, _)| assignments[*i] == cluster_id)
            .map(|(_, &val)| val)
            .collect();
        
        clusters.push(json!({
            "cluster_id": cluster_id,
            "centroid": centroids[cluster_id],
            "size": cluster_points.len(),
            "points": cluster_points
        }));
    }
    
    Ok(json!({
        "clusters": clusters,
        "centroids": centroids,
        "assignments": assignments,
        "algorithm": "k_means",
        "k": k,
        "iterations": max_iterations
    }))
}

/// 线性回归（最小二乘法）
pub fn linear_regression(x_data: &[f64], y_data: &[f64]) -> Result<Value> {
    if x_data.len() != y_data.len() || x_data.is_empty() {
        return Ok(json!({
            "slope": 0.0,
            "intercept": 0.0,
            "r_squared": 0.0,
            "algorithm": "linear_regression",
            "message": "Invalid or empty data"
        }));
    }
    
    let n = x_data.len() as f64;
    let sum_x: f64 = x_data.iter().sum();
    let sum_y: f64 = y_data.iter().sum();
    let sum_xy: f64 = x_data.iter().zip(y_data.iter()).map(|(x, y)| x * y).sum();
    let sum_x2: f64 = x_data.iter().map(|x| x * x).sum();
    let _sum_y2: f64 = y_data.iter().map(|y| y * y).sum();
    
    // 计算斜率和截距
    let slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x);
    let intercept = (sum_y - slope * sum_x) / n;
    
    // 计算R²
    let y_mean = sum_y / n;
    let ss_tot: f64 = y_data.iter().map(|y| (y - y_mean).powi(2)).sum();
    let ss_res: f64 = x_data.iter().zip(y_data.iter())
        .map(|(x, y)| {
            let predicted = slope * x + intercept;
            (y - predicted).powi(2)
        })
        .sum();
    
    let r_squared = if ss_tot > 0.0 { 1.0 - (ss_res / ss_tot) } else { 0.0 };
    
    // 生成预测值
    let predictions: Vec<f64> = x_data.iter()
        .map(|x| slope * x + intercept)
        .collect();
    
    Ok(json!({
        "slope": slope,
        "intercept": intercept,
        "r_squared": r_squared,
        "predictions": predictions,
        "equation": format!("y = {:.4}x + {:.4}", slope, intercept),
        "algorithm": "linear_regression",
        "sample_size": x_data.len()
    }))
}

/// 简单移动平均
pub fn moving_average(data: &[f64], window_size: usize) -> Result<Value> {
    if data.is_empty() || window_size == 0 || window_size > data.len() {
        return Ok(json!({
            "moving_averages": [],
            "algorithm": "moving_average",
            "message": "Invalid parameters"
        }));
    }
    
    let mut moving_averages = Vec::new();
    
    for i in window_size - 1..data.len() {
        let window = &data[i + 1 - window_size..=i];
        let average = window.iter().sum::<f64>() / window_size as f64;
        moving_averages.push(average);
    }
    
    Ok(json!({
        "moving_averages": moving_averages,
        "window_size": window_size,
        "original_length": data.len(),
        "result_length": moving_averages.len(),
        "algorithm": "moving_average"
    }))
}

/// 异常值检测（基于IQR方法）
pub fn outlier_detection(data: &[f64]) -> Result<Value> {
    if data.is_empty() {
        return Ok(json!({
            "outliers": [],
            "outlier_indices": [],
            "algorithm": "iqr_outliers",
            "message": "Empty data"
        }));
    }
    
    let mut sorted_data = data.to_vec();
    sorted_data.sort_by(|a, b| a.partial_cmp(b).unwrap());
    
    let n = sorted_data.len();
    let q1_idx = n / 4;
    let q3_idx = 3 * n / 4;
    
    let q1 = sorted_data[q1_idx];
    let q3 = sorted_data[q3_idx];
    let iqr = q3 - q1;
    
    let lower_bound = q1 - 1.5 * iqr;
    let upper_bound = q3 + 1.5 * iqr;
    
    let mut outliers = Vec::new();
    let mut outlier_indices = Vec::new();
    
    for (i, &value) in data.iter().enumerate() {
        if value < lower_bound || value > upper_bound {
            outliers.push(value);
            outlier_indices.push(i);
        }
    }
    
    Ok(json!({
        "outliers": outliers,
        "outlier_indices": outlier_indices,
        "q1": q1,
        "q3": q3,
        "iqr": iqr,
        "lower_bound": lower_bound,
        "upper_bound": upper_bound,
        "outlier_count": outliers.len(),
        "algorithm": "iqr_outliers"
    }))
}

/// 相关性分析
pub fn correlation_analysis(x_data: &[f64], y_data: &[f64]) -> Result<Value> {
    if x_data.len() != y_data.len() || x_data.len() < 2 {
        return Ok(json!({
            "correlation": 0.0,
            "algorithm": "pearson_correlation",
            "message": "Insufficient or mismatched data"
        }));
    }
    
    let n = x_data.len() as f64;
    let sum_x: f64 = x_data.iter().sum();
    let sum_y: f64 = y_data.iter().sum();
    let sum_xy: f64 = x_data.iter().zip(y_data.iter()).map(|(x, y)| x * y).sum();
    let sum_x2: f64 = x_data.iter().map(|x| x * x).sum();
    let sum_y2: f64 = y_data.iter().map(|y| y * y).sum();
    
    let numerator = n * sum_xy - sum_x * sum_y;
    let denominator = ((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y)).sqrt();
    
    let correlation = if denominator != 0.0 {
        numerator / denominator
    } else {
        0.0
    };
    
    // 解释相关性强度
    let strength = match correlation.abs() {
        x if x >= 0.9 => "very_strong",
        x if x >= 0.7 => "strong", 
        x if x >= 0.5 => "moderate",
        x if x >= 0.3 => "weak",
        _ => "very_weak"
    };
    
    Ok(json!({
        "correlation": correlation,
        "strength": strength,
        "sample_size": x_data.len(),
        "algorithm": "pearson_correlation"
    }))
}

/// 获取支持的基础ML算法列表
pub fn get_supported_algorithms() -> Vec<&'static str> {
    vec![
        "k_means",
        "linear_regression", 
        "moving_average",
        "outlier_detection",
        "correlation_analysis"
    ]
}

/// 算法调度器
pub fn dispatch_algorithm(algorithm: &str, data: &[f64], params: &HashMap<String, String>) -> Result<Value> {
    match algorithm {
        "k_means" => {
            let k = params.get("k")
                .and_then(|s| s.parse().ok())
                .unwrap_or(3);
            let max_iter = params.get("max_iterations")
                .and_then(|s| s.parse().ok())
                .unwrap_or(100);
            k_means_clustering(data, k, max_iter)
        },
        "linear_regression" => {
            // 需要x和y数据，假设data前半部分是x，后半部分是y
            let mid = data.len() / 2;
            if data.len() >= 2 && data.len() % 2 == 0 {
                linear_regression(&data[0..mid], &data[mid..])
            } else {
                // 如果只有一组数据，用索引作为x
                let x_data: Vec<f64> = (0..data.len()).map(|i| i as f64).collect();
                linear_regression(&x_data, data)
            }
        },
        "moving_average" => {
            let window = params.get("window_size")
                .and_then(|s| s.parse().ok())
                .unwrap_or(5);
            moving_average(data, window)
        },
        "outlier_detection" => outlier_detection(data),
        "correlation_analysis" => {
            // 需要两组数据
            let mid = data.len() / 2;
            if data.len() >= 2 && data.len() % 2 == 0 {
                correlation_analysis(&data[0..mid], &data[mid..])
            } else {
                let x_data: Vec<f64> = (0..data.len()).map(|i| i as f64).collect();
                correlation_analysis(&x_data, data)
            }
        },
        _ => Ok(json!({
            "error": format!("Unsupported algorithm: {}", algorithm),
            "supported_algorithms": get_supported_algorithms()
        }))
    }
} 