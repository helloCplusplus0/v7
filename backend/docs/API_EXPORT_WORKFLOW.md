# API导出工作流程指南

## 🎯 唯一推荐方案：运行时数据收集

**主要命令**：
```bash
./scripts/runtime_api_export.sh
```

### 为什么只使用运行时收集？

| 特性 | 运行时收集 | 优势 |
|------|------------|------|
| **数据准确性** | 100% | ✅ 基于真实运行时数据 |
| **类型安全** | 真实序列化 | ✅ 完全准确的类型映射 |
| **错误处理** | 真实错误响应 | ✅ 捕获所有实际错误场景 |
| **性能指标** | 真实测量 | ✅ 实际性能数据 |
| **中间件效果** | 完整链路 | ✅ 包含所有中间件影响 |

## 🚀 完整工作流程

### 1. 准备阶段
```bash
# 确保所有测试都已编写并通过
cargo test
```

### 2. 运行时数据收集
```bash
# 执行运行时API收集（唯一方案）
./scripts/runtime_api_export.sh
```

### 3. 输出验证
检查生成的文件：
- `docs/api/openapi-runtime.json` - 100%准确的OpenAPI规范
- `docs/api/README-runtime.md` - API文档
- `frontend/src/api/client-runtime.ts` - TypeScript客户端
- `frontend/src/types/api-runtime.ts` - TypeScript类型定义

### 4. 前端集成
```bash
cd frontend
npm install
npm run type-check  # 验证生成的类型
```

## 🎯 最佳实践

### 测试覆盖要求
为确保API收集的完整性，请确保测试覆盖：
- ✅ 所有HTTP端点
- ✅ 各种响应状态码
- ✅ 错误场景
- ✅ 不同的请求参数组合

### CI/CD集成
```yaml
# .github/workflows/api-docs.yml
- name: Generate API Documentation
  run: |
    ./scripts/runtime_api_export.sh
    # 提交生成的文件到文档分支
```

## 🔍 故障排查

### 如果API数据不完整
1. 检查测试覆盖率：`cargo tarpaulin --out Stdout`
2. 添加缺失的测试用例
3. 重新运行 `runtime_api_export.sh`

### 如果TypeScript编译失败
1. 检查 `frontend/src/types/api-runtime.ts` 的类型定义
2. 确保所有Rust类型都有对应的TypeScript映射
3. 运行 `npm run type-check` 验证

## 📊 架构决策

**v7架构原则：简洁、准确、高效**

- ✅ **单一方案**：只使用运行时收集，避免选择困难
- ✅ **100%准确**：确保文档与代码完全一致
- ✅ **零维护负担**：自动化生成，无需手动维护
- ✅ **类型安全**：编译时验证所有类型

**结论**：`runtime_api_export.sh` 是唯一推荐的API导出方案。
