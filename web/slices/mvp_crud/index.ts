// 📤 MVP CRUD - 统一导出
// 遵循Web v7架构规范的切片导出

// ===== 内部导入（用于工厂函数） =====
import { CrudView } from './view';
import { useCrud, useItemForm, createCrudContract } from './hooks';
import { crudApi } from './api';

// ===== 主要组件导出 =====

// 默认导出slice组件
export { CrudView as default } from './view';

// 导出所有UI组件
export { CrudView } from './view';

// ===== 业务逻辑导出 =====

// 导出业务逻辑hooks
export { useCrud, useItemForm, createCrudContract } from './hooks';

// 导出API客户端
export { crudApi, mvpCrudApi } from './api';

// ===== 摘要提供者导出 =====

// 导出摘要提供者（用于切片注册表）
export { 
  MvpCrudSummaryProvider, 
  mvpCrudSummaryProvider, 
  CrudSummaryProvider, 
  useCrudSummary 
} from './summaryProvider';

// ===== 类型定义导出 =====

// 导出核心实体类型
export type {
  Item,
  CreateItemRequest,
  UpdateItemRequest,
  GetItemRequest,
  DeleteItemRequest,
  ListItemsRequest,
  CreateItemResponse,
  GetItemResponse,
  UpdateItemResponse,
  DeleteItemResponse,
  ListItemsResponse
} from './types';

// 导出本地状态类型
export type {
  CrudSignals,
  ItemFormData,
  ValidationResult,
  SortField,
  SortOrder,
  CrudOperation,
  OperationStatus
} from './types';

// 导出事件和契约类型
export type {
  CrudEventMap,
  CrudContract
} from './types';

// 导出组件Props类型
export type {
  CrudViewProps,
  ItemCardProps,
  ItemFormProps
} from './types';

// 导出工具类型
export type {
  PaginationInfo,
  SortInfo,
  SearchFilter,
  BatchOperationResult
} from './types';

// 导出类型守卫函数
export { isValidItem, isValidCreateRequest } from './types';

// 导出常量
export {
  DEFAULT_PAGE_SIZE,
  DEFAULT_SORT_FIELD,
  DEFAULT_SORT_ORDER,
  ITEM_NAME_MAX_LENGTH,
  ITEM_DESCRIPTION_MAX_LENGTH,
  ITEM_VALUE_MIN,
  ITEM_VALUE_MAX
} from './types';

// ===== 切片元信息 =====

/**
 * MVP CRUD切片元信息
 * 用于v7架构的切片注册和依赖管理
 */
export const SLICE_INFO = {
  // 基本信息
  name: 'mvp_crud',
  version: '2.0.0',
  description: 'MVP CRUD功能切片 - 展示Web v7架构实现',
  
  // 架构信息
  architecture: 'v7',
  pattern: 'signal-first',
  
  // 路由配置
  routes: [
    '/crud',
    '/crud/create',
    '/crud/edit/:id',
    '/slice/mvp_crud'
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
      'shared/providers/ContractProvider',
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
      provides: ['crud'],    // 提供CRUD契约接口
      consumes: []           // 暂不消费其他契约
    },
    
    // 信号响应式
    signals: {
      uses: [
        'user',             // 用户状态访问器
        'notification'      // 通知状态访问器
      ]
    },
    
    // Provider模式
    providers: {
      registers: [],        // 不注册服务
      injects: []           // 不注入服务（暂时）
    }
  },
  
  // 功能特性
  features: [
    'gRPC-Web通信',
    'Signal-first响应式',
    '细粒度状态管理',
    '实时搜索和过滤',
    '分页和排序',
    '批量操作',
    '表单验证',
    '错误处理',
    '加载状态管理',
    '本地存储偏好',
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
    'debounced-search': true,
    'local-storage-cache': true,
    'batch-operations': true
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
  
  // 更新日志
  changelog: {
    '2.0.0': {
      date: '2025-07-13',
      changes: [
        '完全重写为v7架构',
        '实现Signal-first响应式设计',
        '集成gRPC-Web真实通信',
        '添加四种v7通信机制',
        '优化UI组件和用户体验',
        '增强类型安全和错误处理'
      ]
    },
    '1.0.0': {
      date: '2025-07-12',
      changes: [
        '初始版本',
        '基本CRUD功能',
        '模拟数据和API'
      ]
    }
  }
} as const;

// ===== 切片工厂函数 =====

/**
 * 创建CRUD切片实例
 * 用于在其他切片中集成CRUD功能
 */
export function createCrudSlice(config?: {
  apiEndpoint?: string;
  pageSize?: number;
  enableBulkOperations?: boolean;
  enableSearch?: boolean;
}) {
  const defaultConfig = {
    apiEndpoint: '/api/crud',
    pageSize: 10,
    enableBulkOperations: true,
    enableSearch: true,
    ...config
  };

  return {
    config: defaultConfig,
    hooks: { useCrud, useItemForm },
    components: { CrudView },
    api: crudApi,
    contract: createCrudContract(),
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
       hasComponents: typeof CrudView === 'function',
       hasHooks: typeof useCrud === 'function' && typeof useItemForm === 'function',
       hasApi: typeof crudApi === 'object' && crudApi !== null,
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
      bundleSize: 'estimated-small',
      memoryUsage: 'low',
      renderOptimization: 'compile-time'
    };
  }
};

// 仅在开发环境下导出开发工具
if (import.meta.env.DEV) {
  (globalThis as any).__CRUD_SLICE_DEV_TOOLS__ = devTools;
} 