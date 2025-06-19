#!/bin/bash

# 🧪 测试新切片自动发现功能

echo "🧪 测试新切片自动发现功能"
echo "================================"

# 创建一个临时的测试切片
echo "📝 1. 创建测试切片..."
mkdir -p src/slices/test_slice

cat > src/slices/test_slice/mod.rs << 'EOF'
//! 测试切片 - 用于验证自动发现功能

pub mod functions;
pub mod types;

pub use functions::*;
pub use types::*;
EOF

cat > src/slices/test_slice/types.rs << 'EOF'
//! 测试切片的类型定义

use serde::{Deserialize, Serialize};

/// 测试请求
#[derive(Debug, Serialize, Deserialize)]
pub struct TestRequest {
    pub name: String,
    pub value: i32,
}

/// 测试响应
#[derive(Debug, Serialize, Deserialize)]
pub struct TestResponse {
    pub result: String,
    pub processed_at: String,
}
EOF

cat > src/slices/test_slice/functions.rs << 'EOF'
//! 测试切片的函数实现

use crate::core::Result;
use super::types::*;

/// 测试API端点
/// 
/// 函数路径: `test_slice.process`
/// HTTP路由: POST /api/test/process
/// 
/// # Errors
/// 
/// 返回错误当：
/// - 输入数据无效
/// - 处理失败
pub async fn process_test(req: TestRequest) -> Result<TestResponse> {
    Ok(TestResponse {
        result: format!("Processed: {}", req.name),
        processed_at: chrono::Utc::now().to_rfc3339(),
    })
}

/// 内部测试函数
/// 
/// 函数路径: `test_slice.internal_helper`
/// 
/// # Errors
/// 
/// 返回错误当：
/// - 内部处理失败
pub async fn internal_helper(value: i32) -> Result<String> {
    Ok(format!("Helper result: {}", value * 2))
}
EOF

echo "📝 2. 更新切片模块..."
# 检查mod.rs是否存在test_slice模块
if ! grep -q "pub mod test_slice" src/slices/mod.rs; then
    # 在auth模块后添加test_slice模块
    sed -i '/^pub mod auth;/a pub mod test_slice;' src/slices/mod.rs
    echo "✅ 已添加test_slice模块到src/slices/mod.rs"
else
    echo "✅ test_slice模块已存在于src/slices/mod.rs"
fi

echo "🔧 3. 运行自动文档生成器..."
cargo run --bin auto_docs

echo ""
echo "📊 4. 检查是否发现了新切片..."
if cargo run --bin auto_docs 2>&1 | grep -q "test_slice"; then
    echo "✅ 新切片已被发现"
else
    echo "❌ 新切片未被发现"
fi

echo ""
echo "📝 5. 显示新生成的API..."
echo "生成的OpenAPI规范中的端点："
if [ -f "docs/api/openapi.json" ]; then
    # 使用jq解析JSON，如果没有jq则使用grep
    if command -v jq &> /dev/null; then
        jq '.paths | keys[]' docs/api/openapi.json 2>/dev/null || grep -o '"/api/[^"]*"' docs/api/openapi.json
    else
        grep -o '"/api/[^"]*"' docs/api/openapi.json
    fi
else
    echo "❌ OpenAPI文件未生成"
fi

echo ""
echo "TypeScript类型定义："
if [ -f "frontend/src/types/api.ts" ]; then
    grep -E "(interface|export)" frontend/src/types/api.ts | head -10
else
    echo "❌ TypeScript类型文件未生成"
fi

echo ""
echo "🧹 6. 清理测试文件..."
rm -rf src/slices/test_slice
# 从mod.rs中移除test_slice模块
sed -i '/pub mod test_slice;/d' src/slices/mod.rs

echo ""
echo "🎉 测试完成！" 