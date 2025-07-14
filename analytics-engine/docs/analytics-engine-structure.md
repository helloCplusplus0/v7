# 🎯 Analytics Engine 目录结构设计

## 核心设计理念
- **Rust优先**：所有数据分析功能首先尝试Rust实现
- **Python按需**：Rust能力不足时，无缝引入Python
- **统一接口**：调用者无需知道底层实现语言
- **零配置**：开发者专注代码，构建自动处理

## 📁 推荐目录结构

```
v7/
├── backend/                     # 现有Rust FMOD v7后端
│   └── src/slices/analytics/    # 分析功能切片
│       ├── types.rs
│       ├── interfaces.rs
│       ├── service.rs
│       ├── functions.rs
│       └── mod.rs
└── analytics-engine/            # 🆕 混合计算引擎
    ├── Cargo.toml              # Rust项目配置
    ├── pyproject.toml          # Python项目配置
    ├── build.rs                # 自动构建脚本
    ├── src/                    # Rust实现
    │   ├── lib.rs              # 库入口
    │   ├── core/               # 核心计算模块
    │   │   ├── mod.rs
    │   │   ├── stats.rs        # 统计分析（Rust实现）
    │   │   ├── transform.rs    # 数据转换（Rust实现）
    │   │   └── ml_basic.rs     # 基础机器学习（Rust实现）
    │   ├── python_bridge/      # Python桥接
    │   │   ├── mod.rs
    │   │   ├── bridge.rs       # PyO3桥接代码
    │   │   └── dispatcher.rs   # 自动分发器
    │   └── api/                # 统一API接口
    │       ├── mod.rs
    │       └── functions.rs    # 对外暴露的函数
    ├── python/                 # Python实现
    │   ├── __init__.py
    │   ├── algorithms/         # 高级算法实现
    │   │   ├── __init__.py
    │   │   ├── ml_advanced.py  # 高级机器学习
    │   │   ├── nlp.py          # 自然语言处理
    │   │   └── deep_learning.py # 深度学习
    │   └── utils/              # Python工具函数
    │       ├── __init__.py
    │       └── data_prep.py    # 数据预处理
    ├── tests/                  # 测试
    │   ├── rust/               # Rust测试
    │   └── python/             # Python测试
    └── scripts/                # 构建脚本
        ├── setup.sh            # 环境设置
        ├── build.sh            # 构建脚本
        └── test.sh             # 测试脚本
```

## 🔧 关键文件说明

### 1. Cargo.toml - Rust项目配置
```toml
[package]
name = "analytics-engine"
version = "0.1.0"
edition = "2021"

[lib]
name = "analytics_engine"
crate-type = ["cdylib", "rlib"]

[dependencies]
pyo3 = { version = "0.20", features = ["auto-initialize"] }
polars = "0.35"
ndarray = "0.15"
serde = { version = "1.0", features = ["derive"] }
anyhow = "1.0"

[build-dependencies]
pyo3-build-config = "0.20"

[features]
default = ["python-bridge"]
python-bridge = ["pyo3"]
rust-only = []
```

### 2. pyproject.toml - Python项目配置
```toml
[build-system]
requires = ["maturin>=1.0,<2.0"]
build-backend = "maturin"

[project]
name = "analytics-engine"
requires-python = ">=3.8"
dependencies = [
    "numpy>=1.21.0",
    "pandas>=1.3.0",
    "scikit-learn>=1.0.0",
    "torch>=1.12.0",
    "transformers>=4.20.0",
]

[tool.maturin]
features = ["pyo3/extension-module"]
```

### 3. build.rs - 自动构建脚本
```rust
use std::env;
use std::path::PathBuf;

fn main() {
    // 自动检测Python环境
    pyo3_build_config::add_extension_module_link_args();
    
    // 设置Python模块路径
    let python_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap())
        .join("python");
    println!("cargo:rustc-env=PYTHON_MODULE_PATH={}", python_dir.display());
    
    // 如果Python不可用，只构建Rust部分
    if env::var("ANALYTICS_RUST_ONLY").is_ok() {
        println!("cargo:rustc-cfg=feature=\"rust-only\"");
    }
}
```

## 🎯 实现策略

### 1. 统一API接口（src/api/functions.rs）
```rust
use anyhow::Result;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct AnalysisRequest {
    pub data: Vec<f64>,
    pub algorithm: String,
    pub params: serde_json::Value,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub result: serde_json::Value,
    pub metadata: serde_json::Value,
    pub implementation: String, // "rust" or "python"
}

/// 统一分析函数 - 自动选择Rust或Python实现
pub fn analyze(request: AnalysisRequest) -> Result<AnalysisResult> {
    match request.algorithm.as_str() {
        // Rust优先实现的算法
        "mean" | "median" | "std" => {
            crate::core::stats::analyze_rust(request)
        }
        "linear_regression" | "kmeans" => {
            crate::core::ml_basic::analyze_rust(request)
        }
        
        // Python实现的高级算法
        "deep_learning" | "nlp" | "advanced_ml" => {
            #[cfg(feature = "python-bridge")]
            {
                crate::python_bridge::dispatcher::analyze_python(request)
            }
            #[cfg(not(feature = "python-bridge"))]
            {
                Err(anyhow::anyhow!("Python bridge not available"))
            }
        }
        
        // 自动分发：先尝试Rust，失败则用Python
        _ => {
            match crate::core::stats::try_analyze_rust(&request) {
                Ok(result) => Ok(result),
                Err(_) => {
                    #[cfg(feature = "python-bridge")]
                    {
                        crate::python_bridge::dispatcher::analyze_python(request)
                    }
                    #[cfg(not(feature = "python-bridge"))]
                    {
                        Err(anyhow::anyhow!("Algorithm not supported"))
                    }
                }
            }
        }
    }
}
```

### 2. Python桥接器（src/python_bridge/dispatcher.rs）
```rust
use pyo3::prelude::*;
use anyhow::Result;
use crate::api::{AnalysisRequest, AnalysisResult};

pub fn analyze_python(request: AnalysisRequest) -> Result<AnalysisResult> {
    Python::with_gil(|py| {
        // 导入Python模块
        let analytics_module = py.import("analytics_engine.algorithms")?;
        
        // 选择具体的Python函数
        let py_function = match request.algorithm.as_str() {
            "deep_learning" => analytics_module.getattr("deep_learning_analyze")?,
            "nlp" => analytics_module.getattr("nlp_analyze")?,
            "advanced_ml" => analytics_module.getattr("advanced_ml_analyze")?,
            _ => analytics_module.getattr("generic_analyze")?,
        };
        
        // 调用Python函数
        let py_request = pythonize::pythonize(py, &request)?;
        let py_result = py_function.call1((py_request,))?;
        
        // 转换结果
        let mut result: AnalysisResult = depythonize::depythonize(py_result)?;
        result.implementation = "python".to_string();
        
        Ok(result)
    })
}
```

### 3. 构建脚本（scripts/build.sh）
```bash
#!/bin/bash

echo "🔧 构建Analytics Engine..."

# 1. 检查Python环境
if command -v python3 &> /dev/null; then
    echo "✅ Python环境可用"
    export PYTHON_AVAILABLE=1
    
    # 安装Python依赖
    python3 -m pip install -r requirements.txt
else
    echo "⚠️  Python环境不可用，仅构建Rust部分"
    export ANALYTICS_RUST_ONLY=1
fi

# 2. 构建Rust部分
echo "🦀 构建Rust核心..."
cargo build --release

# 3. 如果Python可用，构建Python桥接
if [ "$PYTHON_AVAILABLE" = "1" ]; then
    echo "🐍 构建Python桥接..."
    maturin build --release
    
    # 安装生成的wheel包
    pip install target/wheels/*.whl --force-reinstall
fi

echo "✅ 构建完成！"
```

## 🚀 使用示例

### 在FMOD v7中集成使用

```rust
// backend/src/slices/analytics/functions.rs
use analytics_engine::analyze;
use analytics_engine::{AnalysisRequest, AnalysisResult};

pub async fn data_analysis<A>(
    analytics_service: A,
    data: Vec<f64>,
    algorithm: String
) -> Result<AnalysisResult>
where
    A: AnalyticsService,
{
    let request = AnalysisRequest {
        data,
        algorithm,
        params: serde_json::json!({}),
    };
    
    // 自动选择Rust或Python实现
    let result = analyze(request)?;
    
    // 记录使用的实现
    log::info!("Analysis completed using: {}", result.implementation);
    
    Ok(result)
}
```

## 🎯 开发工作流

### 1. 新增分析功能
```bash
# 1. 首先尝试Rust实现
# 编辑 src/core/stats.rs 或 src/core/ml_basic.rs

# 2. 如果Rust能力不足，添加Python实现
# 编辑 python/algorithms/相应文件

# 3. 更新分发器
# 编辑 src/api/functions.rs 中的匹配逻辑

# 4. 构建和测试
./scripts/build.sh
./scripts/test.sh
```

### 2. 部署配置
```yaml
# podman-compose.yml 中的analytics服务
analytics:
  build:
    context: ./analytics-engine
    dockerfile: Dockerfile
  environment:
    - RUST_LOG=info
    - PYTHON_PATH=/app/python
  volumes:
    - ./analytics-engine/python:/app/python:ro
```

## ✅ 核心优势

1. **开发者友好**：只需编写算法代码，构建自动处理
2. **渐进式增强**：Rust优先，Python按需，无缝切换
3. **性能优化**：Rust实现零开销，Python实现按需加载
4. **部署简单**：单一容器，自动检测环境能力
5. **类型安全**：统一接口，编译时类型检查
6. **测试完整**：Rust和Python实现都有完整测试覆盖

这个设计让您专注于算法实现，而不用担心构建和集成的复杂性！ 