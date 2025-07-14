# 🚀 实际开发示例

## 场景1：添加统计分析功能

### 步骤1：先尝试Rust实现
```rust
// analytics-engine/src/core/stats.rs

use anyhow::Result;
use crate::api::{AnalysisRequest, AnalysisResult};
use serde_json::json;

pub fn analyze_rust(request: AnalysisRequest) -> Result<AnalysisResult> {
    let result_value = match request.algorithm.as_str() {
        "mean" => calculate_mean(&request.data)?,
        "median" => calculate_median(&request.data)?,
        "std" => calculate_std(&request.data)?,
        "correlation" => {
            // Rust实现相关性分析
            calculate_correlation(&request.data)?
        }
        _ => return Err(anyhow::anyhow!("Algorithm not implemented in Rust"))
    };
    
    Ok(AnalysisResult {
        result: json!(result_value),
        metadata: json!({
            "algorithm": request.algorithm,
            "data_size": request.data.len(),
            "execution_time_ms": 1.2 // 示例
        }),
        implementation: "rust".to_string(),
    })
}

fn calculate_mean(data: &[f64]) -> Result<f64> {
    if data.is_empty() {
        return Err(anyhow::anyhow!("Empty data"));
    }
    Ok(data.iter().sum::<f64>() / data.len() as f64)
}

fn calculate_correlation(data: &[f64]) -> Result<f64> {
    // 简单的自相关计算示例
    if data.len() < 2 {
        return Err(anyhow::anyhow!("Insufficient data for correlation"));
    }
    
    // 使用ndarray或polars实现更复杂的相关性分析
    // 这里是简化示例
    Ok(0.85) // 示例结果
}
```

### 步骤2：如果需要Python实现
```python
# analytics-engine/python/algorithms/ml_advanced.py

import numpy as np
from sklearn.decomposition import PCA
from sklearn.cluster import DBSCAN
import json

def advanced_ml_analyze(request_dict):
    """高级机器学习分析 - Rust无法高效实现的算法"""
    
    algorithm = request_dict['algorithm']
    data = np.array(request_dict['data'])
    params = request_dict.get('params', {})
    
    if algorithm == "pca":
        return pca_analysis(data, params)
    elif algorithm == "dbscan":
        return dbscan_clustering(data, params)
    elif algorithm == "time_series_forecast":
        return time_series_forecast(data, params)
    else:
        raise ValueError(f"Algorithm {algorithm} not implemented")

def pca_analysis(data, params):
    """主成分分析"""
    n_components = params.get('n_components', 2)
    
    # 重塑数据为二维数组
    if data.ndim == 1:
        data = data.reshape(-1, 1)
    
    pca = PCA(n_components=n_components)
    transformed = pca.fit_transform(data)
    
    return {
        "result": {
            "transformed_data": transformed.tolist(),
            "explained_variance_ratio": pca.explained_variance_ratio_.tolist(),
            "components": pca.components_.tolist()
        },
        "metadata": {
            "algorithm": "pca",
            "n_components": n_components,
            "original_shape": list(data.shape),
            "explained_variance_total": float(pca.explained_variance_ratio_.sum())
        }
    }

def dbscan_clustering(data, params):
    """DBSCAN聚类"""
    eps = params.get('eps', 0.5)
    min_samples = params.get('min_samples', 5)
    
    if data.ndim == 1:
        data = data.reshape(-1, 1)
    
    dbscan = DBSCAN(eps=eps, min_samples=min_samples)
    labels = dbscan.fit_predict(data)
    
    return {
        "result": {
            "labels": labels.tolist(),
            "n_clusters": len(set(labels)) - (1 if -1 in labels else 0),
            "n_noise": list(labels).count(-1)
        },
        "metadata": {
            "algorithm": "dbscan",
            "eps": eps,
            "min_samples": min_samples,
            "data_points": len(data)
        }
    }
```

## 场景2：开发者日常工作流

### 1. 新功能开发
```bash
# 开发者只需要关心算法实现，不用管构建
cd analytics-engine

# 1. 尝试Rust实现新算法
vim src/core/stats.rs
# 添加新的统计函数

# 2. 如果Rust实现困难，使用Python
vim python/algorithms/ml_advanced.py
# 添加Python实现

# 3. 更新分发逻辑（一行代码）
vim src/api/functions.rs
# 在match语句中添加新算法的分发规则

# 4. 构建和测试（自动处理所有复杂性）
./scripts/build.sh
./scripts/test.sh
```

### 2. 在FMOD v7中调用
```rust
// backend/src/slices/analytics/functions.rs
use analytics_engine::{analyze, AnalysisRequest};

pub async fn statistical_analysis<A>(
    _analytics_service: A,
    data: Vec<f64>,
    algorithm: String
) -> Result<serde_json::Value>
where
    A: AnalyticsService,
{
    // 构建请求
    let request = AnalysisRequest {
        data,
        algorithm,
        params: serde_json::json!({}),
    };
    
    // 调用分析引擎（自动选择Rust或Python）
    let result = analyze(request)?;
    
    // 返回结果，调用者不需要知道底层实现
    Ok(serde_json::json!({
        "analysis_result": result.result,
        "metadata": result.metadata,
        "implementation_used": result.implementation
    }))
}

// HTTP适配器
pub async fn http_statistical_analysis(
    req: StatisticalAnalysisRequest
) -> HttpResponse<serde_json::Value> {
    let analytics_service = inject::<MockAnalyticsService>();
    
    match statistical_analysis(analytics_service, req.data, req.algorithm).await {
        Ok(result) => HttpResponse::success(result),
        Err(e) => HttpResponse::from_error(e),
    }
}
```

## 场景3：自动构建和部署

### Dockerfile示例
```dockerfile
# analytics-engine/Dockerfile
FROM rust:1.75 as rust-builder

WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src/ ./src/
COPY build.rs ./

# 构建Rust部分
RUN cargo build --release

FROM python:3.11-slim as python-builder

WORKDIR /app

# 安装maturin和依赖
RUN pip install maturin

COPY pyproject.toml ./
COPY python/ ./python/
COPY --from=rust-builder /app/target/release/libanalytics_engine.so ./

# 构建Python桥接
RUN maturin build --release

FROM python:3.11-slim

WORKDIR /app

# 安装Python依赖
COPY requirements.txt ./
RUN pip install -r requirements.txt

# 复制构建产物
COPY --from=python-builder /app/target/wheels/*.whl ./
RUN pip install *.whl

# 复制Python模块
COPY python/ ./python/

ENV PYTHONPATH=/app/python
EXPOSE 8080

CMD ["python", "-m", "analytics_engine.server"]
```

### 集成到podman-compose.yml
```yaml
# v7/podman-compose.yml
version: '3.8'

services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    depends_on:
      - analytics
  
  analytics:
    build: ./analytics-engine
    ports:
      - "8080:8080"
    environment:
      - RUST_LOG=info
      - PYTHON_PATH=/app/python
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
  
  web:
    build: ./web
    ports:
      - "3000:3000"
    depends_on:
      - backend
```

## 场景4：性能监控和调试

### 自动性能对比
```rust
// analytics-engine/src/api/functions.rs 中的增强版本

pub fn analyze_with_benchmark(request: AnalysisRequest) -> Result<AnalysisResult> {
    use std::time::Instant;
    
    let start = Instant::now();
    
    // 先尝试Rust实现
    if let Ok(rust_result) = try_rust_implementation(&request) {
        let duration = start.elapsed();
        log::info!("Rust implementation took: {:?}", duration);
        
        let mut result = rust_result;
        result.metadata = serde_json::json!({
            "implementation": "rust",
            "execution_time_ms": duration.as_millis(),
            "algorithm": request.algorithm
        });
        return Ok(result);
    }
    
    // 回退到Python实现
    #[cfg(feature = "python-bridge")]
    {
        let start_python = Instant::now();
        match crate::python_bridge::dispatcher::analyze_python(request) {
            Ok(mut python_result) => {
                let duration = start_python.elapsed();
                log::info!("Python implementation took: {:?}", duration);
                
                python_result.metadata = serde_json::json!({
                    "implementation": "python",
                    "execution_time_ms": duration.as_millis(),
                    "algorithm": python_result.metadata["algorithm"]
                });
                Ok(python_result)
            }
            Err(e) => Err(e)
        }
    }
    
    #[cfg(not(feature = "python-bridge"))]
    {
        Err(anyhow::anyhow!("No implementation available"))
    }
}
```

## ✅ 开发者体验总结

1. **编写算法**：只需在对应的文件中添加函数
2. **更新分发**：在`functions.rs`中添加一行匹配规则
3. **构建部署**：运行`./scripts/build.sh`即可
4. **性能透明**：自动记录使用的实现和执行时间
5. **渐进增强**：Rust优先，Python按需，无缝切换

这样的设计让您专注于业务逻辑，而不用担心技术细节！ 