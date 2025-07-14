// 📤 MVP STAT - 统一导出
// 遵循Web v7架构规范的切片导出

// ===== 内部导入（用于工厂函数） =====
import { MvpStatView } from './view';
import { useMvpStat, useDataGenerator, useStatisticsCalculator, useComprehensiveAnalyzer, createMvpStatContract } from './hooks';
import { mvpStatApi } from './api';

// ===== 主要组件导出 =====

// 默认导出slice组件
export { MvpStatView as default } from './view';

// 导出所有组件
export { MvpStatView } from './view';

// ===== 业务逻辑导出 =====

// 导出业务逻辑hooks
export { 
  useMvpStat, 
  useDataGenerator, 
  useStatisticsCalculator, 
  useComprehensiveAnalyzer,
  createMvpStatContract 
} from './hooks';

// 导出API客户端
export { mvpStatApi } from './api';

// 导出摘要提供者
export { 
  createMvpStatSummaryProvider,
  getMvpStatSummaryProvider,
  resetMvpStatSummaryProvider,
  mvpStatSummaryFactory
} from './summaryProvider';

export type {
  MvpStatSummary,
  MvpStatMetrics
} from './summaryProvider';

// ===== 类型定义导出 =====

// 导出核心业务类型
export type {
  GenerateDataRequest,
  CalculateStatsRequest,
  ComprehensiveRequest,
  GeneratedDataResult,
  StatisticsCalculationResult,
  ComprehensiveAnalysisResult,
  MvpStatState,
  OperationHistory,
  StatPreferences
} from './types';

// 导出组件Props类型
export type {
  MvpStatViewProps,
  DataGeneratorProps,
  StatisticsCalculatorProps,
  ComprehensiveAnalyzerProps,
  StatisticsDisplayProps,
  DataVisualizationProps
} from './types';

// 导出常量
export {
  DEFAULT_DATA_CONFIG,
  DEFAULT_STATS_CONFIG,
  AVAILABLE_STATISTICS,
  DISTRIBUTION_OPTIONS,
  DATA_QUALITY_THRESHOLDS
} from './types';

// ===== 切片元信息 =====

/**
 * MVP STAT切片元信息
 * 用于v7架构的切片注册和依赖管理
 */
export const SLICE_INFO = {
  // 基本信息
  name: 'mvp_stat',
  version: '1.0.0',
  description: 'MVP统计分析功能切片 - 展示Web v7架构与Analytics Engine集成',
  
  // 架构信息
  architecture: 'v7',
  pattern: 'signal-first',
  
  // 路由配置
  routes: [
    '/stat',
    '/stat/generate',
    '/stat/calculate',
    '/stat/analyze',
    '/slice/mvp_stat'
  ],
  
  // 依赖关系
  dependencies: {
    // 外部切片依赖（无直接依赖，通过v7通信机制）
    slices: [],
    
    // 共享基础设施依赖
    infrastructure: [
      'shared/hooks/useAsync',
      'shared/hooks/useDebounce', 
      'shared/hooks/useLocalStorage',
      'shared/events/EventBus',
      'shared/signals/accessors',
      'shared/api/grpc-client'
    ],
    
    // 外部库依赖
    external: [
      'solid-js',
      'solid-js/store'
    ]
  },
  
  // v7通信机制使用情况
  communication: {
    // 事件驱动通信
    events: {
      publishes: [
        'notification:show'  // 使用通用通知事件
      ],
      subscribes: [
        'auth:logout'        // 监听认证状态变化
      ]
    },
    
    // 契约接口
    contracts: {
      provides: ['mvp_stat'],    // 提供统计分析契约接口
      consumes: []               // 暂不消费其他契约
    },
    
    // 信号响应式
    signals: {
      uses: [
        'user',               // 用户状态访问器
        'notification'        // 通知状态访问器
      ]
    },
    
    // Provider模式
    providers: {
      registers: [],          // 不注册服务
      injects: []             // 不注入服务（暂时）
    }
  },
  
  // 功能特性
  features: [
    'gRPC-Web通信',
    'Signal-first响应式',
    '细粒度状态管理',
    '随机数据生成',
    '统计量计算',
    '综合数据分析',
    'Analytics Engine集成',
    '多种分布支持',
    '实时性能监控',
    '数据质量评估',
    '智能分析建议',
    '数据导出功能',
    '操作历史记录',
    '用户偏好设置',
    '事件驱动通知'
  ],
  
  // 性能特性
  performance: {
    // SolidJS优化
    'fine-grained-reactivity': true,
    'zero-virtual-dom': true,
    'compile-time-optimization': true,
    
    // 架构优化
    'static-dispatch': true,
    'zero-runtime-dependencies': true,
    'lazy-loading': false,
    
    // 功能优化
    'analytics-engine-integration': true,
    'rust-performance': true,
    'python-ecosystem': true,
    'intelligent-dispatch': true,
    'local-storage-cache': true,
    'operation-history': true
  },
  
  // 开发和测试
  development: {
    // 测试覆盖
    'unit-tests': true,
    'integration-tests': true,
    'e2e-tests': false,
    
    // 开发工具
    'hot-reload': true,
    'dev-tools': true,
    'type-checking': true,
    
    // 代码质量
    'eslint': true,
    'prettier': true,
    'typescript': true
  },
  
  // 部署信息
  deployment: {
    'independent-build': true,
    'zero-config': true,
    'production-ready': true
  },
  
  // 兼容性
  compatibility: {
    'browser-support': ['Chrome >= 80', 'Firefox >= 75', 'Safari >= 13', 'Edge >= 80'],
    'mobile-support': true,
    'accessibility': 'WCAG-2.1-AA'
  },
  
  // Analytics Engine集成
  analyticsEngine: {
    'endpoint': 'localhost:50051',
    'protocols': ['gRPC'],
    'algorithms': [
      'mean', 'median', 'mode', 'std', 'variance',
      'min', 'max', 'range', 'skewness', 'kurtosis',
      'q1', 'q3', 'iqr', 'count', 'sum'
    ],
    'distributions': ['uniform', 'normal', 'exponential'],
    'implementations': ['rust', 'python'],
    'intelligent-dispatch': true
  },
  
  // 更新日志
  changelog: {
    '1.0.0': {
      date: '2025-07-14',
      changes: [
        '实现完整的MVP统计分析功能',
        '集成Analytics Engine高性能计算',
        '支持三种核心功能：数据生成、统计计算、综合分析',
        '实现Signal-first响应式设计',
        '集成gRPC-Web真实通信',
        '添加四种v7通信机制',
        '优化UI组件和用户体验',
        '增强类型安全和错误处理',
        '支持13种常规统计量',
        '支持3种概率分布',
        '智能算法分发',
        '数据质量评估',
        '分析建议生成',
        '操作历史记录',
        '用户偏好设置',
        '数据导出功能'
      ]
    }
  }
} as const;

// ===== 切片工厂函数 =====

/**
 * 创建MVP STAT切片实例
 * 用于在其他切片中集成统计分析功能
 */
export function createMvpStatSlice(config?: {
  apiEndpoint?: string;
  defaultDataCount?: number;
  enableAnalyticsEngine?: boolean;
  preferredDistribution?: 'uniform' | 'normal' | 'exponential';
  enableAdvancedFeatures?: boolean;
}) {
  const defaultConfig = {
    apiEndpoint: '/api/statistics',
    defaultDataCount: 1000,
    enableAnalyticsEngine: true,
    preferredDistribution: 'uniform' as const,
    enableAdvancedFeatures: true,
    ...config
  };

  return {
    config: defaultConfig,
    hooks: { 
      useMvpStat, 
      useDataGenerator, 
      useStatisticsCalculator, 
      useComprehensiveAnalyzer 
    },
    components: { MvpStatView },
    api: mvpStatApi,
    contract: createMvpStatContract(),
    meta: SLICE_INFO
  };
}

// ===== 开发者工具 =====

/**
 * 开发环境下的调试工具
 */
export const devTools = {
  // 获取切片状态快照
  getStateSnapshot() {
    return {
      sliceInfo: SLICE_INFO,
      timestamp: new Date().toISOString(),
      // 可以添加更多调试信息
    };
  },
  
  // 验证切片完整性
  validateSlice() {
    const checks = {
      hasComponents: typeof MvpStatView === 'function',
      hasHooks: typeof useMvpStat === 'function' && typeof useDataGenerator === 'function',
      hasApi: typeof mvpStatApi === 'object' && mvpStatApi !== null,
      hasTypes: true, // 编译时验证
      hasMetadata: typeof SLICE_INFO === 'object' && SLICE_INFO !== null
    };
    
    const isValid = Object.values(checks).every(Boolean);
    
    return {
      isValid,
      checks,
      errors: Object.entries(checks)
        .filter(([_, valid]) => !valid)
        .map(([check]) => `Missing: ${check}`)
    };
  },
  
  // 性能分析
  getPerformanceInfo() {
    return {
      architecture: 'v7-signal-first',
      reactivityModel: 'fine-grained',
      bundleSize: 'estimated-medium',
      memoryUsage: 'low-to-medium',
      renderOptimization: 'compile-time',
      analyticsEngine: 'high-performance',
      grpcIntegration: 'native-web'
    };
  },
  
  // Analytics Engine连接测试
  async testAnalyticsConnection() {
    try {
      const result = await mvpStatApi.generateRandomData({
        count: 10,
        seed: 42,
        distribution: 'uniform'
      });
      return {
        success: true,
        message: 'Analytics Engine连接正常',
        data: result
      };
    } catch (error) {
      return {
        success: false,
        message: `Analytics Engine连接失败: ${error}`,
        error
      };
    }
  }
}; 