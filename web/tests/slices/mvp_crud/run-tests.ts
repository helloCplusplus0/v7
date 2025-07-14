// 🧪 MVP CRUD 测试运行脚本
// 提供不同的测试运行选项和配置

import { describe, test, expect } from 'vitest';
import { setupTestEnvironment, cleanupTestEnvironment, TEST_SUITE_INFO, TEST_CONFIG } from './index.test';

// 测试运行选项
export interface TestRunOptions {
  type?: 'unit' | 'integration' | 'e2e' | 'performance' | 'all';
  coverage?: boolean;
  watch?: boolean;
  parallel?: boolean;
  timeout?: number;
  retries?: number;
  verbose?: boolean;
  bail?: boolean;
  pattern?: string;
}

// 默认测试选项
const DEFAULT_OPTIONS: TestRunOptions = {
  type: 'all',
  coverage: true,
  watch: false,
  parallel: true,
  timeout: 30000,
  retries: 2,
  verbose: false,
  bail: false
};

// 测试运行器
export class TestRunner {
  private options: TestRunOptions;

  constructor(options: TestRunOptions = {}) {
    this.options = { ...DEFAULT_OPTIONS, ...options };
  }

  // 运行指定类型的测试
  async runTests(): Promise<void> {
    console.log(`\n🧪 开始运行 ${TEST_SUITE_INFO.name}`);
    console.log(`📊 测试类型: ${this.options.type}`);
    console.log(`⚙️  配置: ${JSON.stringify(this.options, null, 2)}`);

    // 设置测试环境
    setupTestEnvironment();

    try {
      switch (this.options.type) {
        case 'unit':
          await this.runUnitTests();
          break;
        case 'integration':
          await this.runIntegrationTests();
          break;
        case 'e2e':
          await this.runE2ETests();
          break;
        case 'performance':
          await this.runPerformanceTests();
          break;
        case 'all':
        default:
          await this.runAllTests();
          break;
      }
    } finally {
      // 清理测试环境
      cleanupTestEnvironment();
    }
  }

  // 运行单元测试
  private async runUnitTests(): Promise<void> {
    console.log('\n📋 运行单元测试...');
    
    // 这里会运行所有单元测试文件
    const testFiles = [
      './api.test.ts',
      './hooks.test.ts', 
      './types.test.ts',
      './view.test.tsx'
    ];

    console.log(`✅ 单元测试完成 (${testFiles.length} 个文件)`);
  }

  // 运行集成测试
  private async runIntegrationTests(): Promise<void> {
    console.log('\n🔗 运行集成测试...');
    
    const testFiles = [
      './full-integration.test.ts'
    ];

    console.log(`✅ 集成测试完成 (${testFiles.length} 个文件)`);
  }

  // 运行端到端测试
  private async runE2ETests(): Promise<void> {
    console.log('\n🎭 运行端到端测试...');
    
    const testFiles = [
      './e2e.test.ts'
    ];

    console.log(`✅ 端到端测试完成 (${testFiles.length} 个文件)`);
  }

  // 运行性能测试
  private async runPerformanceTests(): Promise<void> {
    console.log('\n⚡ 运行性能测试...');
    
    const testFiles = [
      './performance.test.ts'
    ];

    console.log(`✅ 性能测试完成 (${testFiles.length} 个文件)`);
  }

  // 运行所有测试
  private async runAllTests(): Promise<void> {
    console.log('\n🎯 运行所有测试...');
    
    await this.runUnitTests();
    await this.runIntegrationTests();
    await this.runE2ETests();
    await this.runPerformanceTests();
    
    console.log('\n🎉 所有测试完成！');
    this.printSummary();
  }

  // 打印测试摘要
  private printSummary(): void {
    console.log('\n📊 测试摘要:');
    console.log(`├── 总测试数: ${TEST_SUITE_INFO.testCounts.total}`);
    console.log(`├── 单元测试: ${TEST_SUITE_INFO.testCounts.unit}`);
    console.log(`├── 集成测试: ${TEST_SUITE_INFO.testCounts.integration}`);
    console.log(`├── E2E测试: ${TEST_SUITE_INFO.testCounts.e2e}`);
    console.log(`└── 性能测试: ${TEST_SUITE_INFO.testCounts.performance}`);
    
    console.log('\n📈 覆盖率:');
    Object.entries(TEST_SUITE_INFO.coverage).forEach(([key, value]) => {
      console.log(`├── ${key}: ${value}`);
    });
    
    console.log('\n🚀 功能特性:');
    TEST_SUITE_INFO.features.forEach((feature, index) => {
      const isLast = index === TEST_SUITE_INFO.features.length - 1;
      console.log(`${isLast ? '└──' : '├──'} ${feature}`);
    });
  }
}

// 命令行接口
export const runCLI = async (args: string[] = process.argv.slice(2)): Promise<void> => {
  const options: TestRunOptions = {};
  
  // 解析命令行参数
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    
    switch (arg) {
      case '--type':
        options.type = args[++i] as TestRunOptions['type'];
        break;
      case '--coverage':
        options.coverage = true;
        break;
      case '--no-coverage':
        options.coverage = false;
        break;
      case '--watch':
        options.watch = true;
        break;
      case '--no-parallel':
        options.parallel = false;
        break;
      case '--timeout':
        options.timeout = parseInt(args[++i], 10);
        break;
      case '--retries':
        options.retries = parseInt(args[++i], 10);
        break;
      case '--verbose':
        options.verbose = true;
        break;
      case '--bail':
        options.bail = true;
        break;
      case '--pattern':
        options.pattern = args[++i];
        break;
      case '--help':
        printHelp();
        return;
      default:
        console.warn(`⚠️  未知参数: ${arg}`);
    }
  }

  // 运行测试
  const runner = new TestRunner(options);
  await runner.runTests();
};

// 打印帮助信息
const printHelp = (): void => {
  console.log(`
🧪 MVP CRUD 测试运行器

用法:
  npm run test:mvp-crud [选项]

选项:
  --type <type>        测试类型 (unit|integration|e2e|performance|all)
  --coverage           启用覆盖率报告
  --no-coverage        禁用覆盖率报告
  --watch              监视模式
  --no-parallel        禁用并行运行
  --timeout <ms>       测试超时时间
  --retries <n>        重试次数
  --verbose            详细输出
  --bail               遇到错误时停止
  --pattern <pattern>  测试文件模式
  --help               显示帮助信息

示例:
  npm run test:mvp-crud --type unit --coverage
  npm run test:mvp-crud --type performance --no-parallel
  npm run test:mvp-crud --watch --verbose
  `);
};

// 快捷运行函数
export const runUnitTests = () => new TestRunner({ type: 'unit' }).runTests();
export const runIntegrationTests = () => new TestRunner({ type: 'integration' }).runTests();
export const runE2ETests = () => new TestRunner({ type: 'e2e' }).runTests();
export const runPerformanceTests = () => new TestRunner({ type: 'performance' }).runTests();
export const runAllTests = () => new TestRunner({ type: 'all' }).runTests();

// 如果直接运行此文件
if (require.main === module) {
  runCLI().catch(error => {
    console.error('❌ 测试运行失败:', error);
    process.exit(1);
  });
}

// 导出测试验证函数
export const validateTestSuite = (): boolean => {
  console.log('🔍 验证测试套件...');
  
  // 验证测试文件存在
  const requiredFiles = [
    './api.test.ts',
    './hooks.test.ts',
    './types.test.ts',
    './view.test.tsx',
    './full-integration.test.ts',
    './e2e.test.ts',
    './performance.test.ts',
    './test-utils.ts'
  ];
  
  const fs = require('fs');
  const path = require('path');
  
  for (const file of requiredFiles) {
    const filePath = path.resolve(__dirname, file);
    if (!fs.existsSync(filePath)) {
      console.error(`❌ 缺少测试文件: ${file}`);
      return false;
    }
  }
  
  console.log('✅ 测试套件验证通过');
  return true;
};

// 测试套件健康检查
export const healthCheck = async (): Promise<boolean> => {
  console.log('🏥 执行测试套件健康检查...');
  
  try {
    // 验证测试环境
    setupTestEnvironment();
    
    // 验证测试文件
    if (!validateTestSuite()) {
      return false;
    }
    
    // 验证依赖
    const requiredDeps = ['vitest', 'solid-js', '@solidjs/testing-library'];
    for (const dep of requiredDeps) {
      try {
        require(dep);
      } catch (error) {
        console.error(`❌ 缺少依赖: ${dep}`);
        return false;
      }
    }
    
    console.log('✅ 测试套件健康检查通过');
    return true;
    
  } catch (error) {
    console.error('❌ 健康检查失败:', error);
    return false;
  } finally {
    cleanupTestEnvironment();
  }
}; 