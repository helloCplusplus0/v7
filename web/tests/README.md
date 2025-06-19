 # Web 测试体系说明文档

## 📋 测试架构概览

本项目采用基于**功能切片 + 洋葱架构 + FCIS**的分层测试策略，确保代码质量和系统稳定性。

### 🔹 测试金字塔结构

```
        E2E Tests (少量)
       /              \
    Contract Tests (中等)
   /                    \
Integration Tests (适量)
/                        \
Unit Tests (大量)
```

## 📁 测试目录结构

```
web/
├── tests/                          # 集中测试目录
│   ├── setup.ts                   # 全局测试设置
│   ├── contracts/                 # 契约测试
│   │   └── hello_fmod.contract.test.ts
│   ├── integration/               # 集成测试
│   │   └── hello_fmod.integration.test.ts
│   ├── e2e/                      # 端到端测试
│   │   └── hello_fmod.e2e.test.ts
│   └── utils/                    # 测试工具
│       └── test-helpers.ts
├── slices/                        # 切片目录
│   └── hello_fmod/
│       ├── domain/
│       │   ├── logic.ts
│       │   └── logic_test.ts      # 就近单元测试
│       ├── service/
│       │   ├── useHelloFmod.ts
│       │   └── useHelloFmod_test.ts
│       └── adapter/
│           ├── api/
│           │   ├── client.ts
│           │   └── client_test.ts
│           └── ui/
│               ├── HelloFmodView.tsx
│               └── HelloFmodView_test.tsx
└── src/                          # 应用源码
```

## 🎯 测试类型说明

### 1. 单元测试（就近原则）
- **位置**: 与源文件同目录，后缀 `_test.ts[x]`
- **目的**: 测试单个函数、组件或模块的行为
- **特点**: 快速执行、高覆盖率、隔离性强
- **工具**: Vitest + @solidjs/testing-library

**示例**:
```typescript
// domain/logic_test.ts
describe('validateHelloMessage', () => {
  test('应该接受有效的hello消息', () => {
    expect(validateHelloMessage('Hello fmod!')).toBe(true);
  });
});
```

### 2. 集成测试（切片内）
- **位置**: `tests/integration/`
- **目的**: 测试切片内各层（Domain → Service → Adapter）的协作
- **特点**: 验证数据流、状态管理、错误处理
- **工具**: Vitest + MSW + @solidjs/testing-library

**示例**:
```typescript
// tests/integration/hello_fmod.integration.test.ts
test('完整的数据流：API调用 → 业务逻辑验证 → UI渲染', async () => {
  render(() => <HelloFmodView />);
  await waitFor(() => {
    expect(screen.getByText('Hello fmod!')).toBeInTheDocument();
  });
});
```

### 3. 契约测试（切片间）
- **位置**: `tests/contracts/`
- **目的**: 验证API接口的稳定性和类型安全
- **特点**: 确保向后兼容、类型一致性
- **工具**: Vitest + MSW + TypeScript

**示例**:
```typescript
// tests/contracts/hello_fmod.contract.test.ts
test('GET /api/hello 应该返回正确的数据结构', async () => {
  const response = await fetch('/api/hello');
  const data = await response.json();
  expect(data).toHaveProperty('message');
  expect(typeof data.message).toBe('string');
});
```

### 4. 端到端测试（系统级）
- **位置**: `tests/e2e/`
- **目的**: 模拟真实用户场景，验证完整功能流程
- **特点**: 覆盖关键用户路径、性能验证
- **工具**: Vitest + @solidjs/testing-library

**示例**:
```typescript
// tests/e2e/hello_fmod.e2e.test.ts
test('用户首次访问应用，能看到HelloFmod切片正常工作', async () => {
  render(() => <App />);
  await waitFor(() => {
    expect(screen.getByText('Hello fmod!')).toBeInTheDocument();
  });
});
```

## 🛠️ 测试工具配置

### 核心工具栈
- **Vitest**: 测试运行器和断言库
- **@solidjs/testing-library**: SolidJS组件测试
- **MSW**: API Mock服务
- **jsdom**: 浏览器环境模拟

### Mock策略
- **切片内Mock**: 每个切片维护自己的mock数据
- **API Mock**: 使用MSW模拟外部API调用
- **组件Mock**: 模拟复杂的子组件依赖

## 🚀 运行测试

### 开发阶段
```bash
# 运行所有测试
npm run test

# 监听模式运行测试
npm run test:watch

# 运行特定切片的测试
npm run test hello_fmod

# 生成覆盖率报告
npm run test:coverage
```

### 分类运行
```bash
# 运行单元测试
npm run test:unit

# 运行集成测试
npm run test:integration

# 运行契约测试
npm run test:contracts

# 运行端到端测试
npm run test:e2e

# 运行完整测试套件
npm run test:all
```

### CI/CD流程
```bash
# 生成测试报告
npm run test:report

# 检查测试覆盖率
npm run test:coverage
```

## 📊 测试覆盖率目标

| 测试类型 | 覆盖率目标 | 执行频率 |
|---------|-----------|----------|
| 单元测试 | 80%+ | 每次提交 |
| 集成测试 | 70%+ | 每次提交 |
| 契约测试 | 100% | 每次发布 |
| E2E测试 | 关键路径 | 每日构建 |

## 🔧 最佳实践

### 1. 测试命名规范
```typescript
describe('组件/功能名称 - 测试类型', () => {
  test('应该 + 期望行为', () => {
    // 测试实现
  });
});
```

### 2. 测试结构模式（AAA）
```typescript
test('测试描述', () => {
  // Arrange - 准备测试数据
  const input = 'test data';
  
  // Act - 执行被测试的操作
  const result = functionUnderTest(input);
  
  // Assert - 验证结果
  expect(result).toBe(expectedOutput);
});
```

### 3. Mock使用原则
- 只Mock外部依赖，不Mock被测试的代码
- 使用类型安全的Mock
- 在每个测试后清理Mock状态

### 4. 测试数据管理
- 使用工厂函数创建测试数据
- 避免测试间的数据污染
- 使用有意义的测试数据

## 🚨 注意事项

1. **避免测试实现细节**: 测试行为而非实现
2. **保持测试独立性**: 每个测试应该能独立运行
3. **及时更新测试**: 代码变更时同步更新测试
4. **重视测试质量**: 测试代码也需要维护和重构

## 📚 相关资源

- [Vitest官方文档](https://vitest.dev/)
- [SolidJS测试指南](https://docs.solidjs.com/guides/testing)
- [MSW文档](https://mswjs.io/)
- [功能切片设计](https://feature-sliced.design/)
- [洋葱架构原理](https://jeffreypalermo.com/2008/07/the-onion-architecture-part-1/)

## 🔄 持续改进

测试体系是一个持续改进的过程，我们会根据项目发展和团队反馈不断优化：

1. **定期审查测试覆盖率**
2. **优化测试执行性能**
3. **更新测试工具和最佳实践**
4. **收集团队反馈并改进流程**

---

通过遵循这套测试体系，我们能够确保代码质量、提高开发效率、降低维护成本，为项目的长期成功奠定坚实基础。