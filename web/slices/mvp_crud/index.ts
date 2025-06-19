// 📤 MVP CRUD - 统一导出
// 遵循Web v7架构规范的切片导出

// 导出类型定义
export type {
  Item,
  CreateItemRequest,
  UpdateItemRequest,
  ListItemsQuery,
  CreateItemResponse,
  GetItemResponse,
  UpdateItemResponse,
  DeleteItemResponse,
  ListItemsResponse,
  CrudState,
  ItemFormData,
  CrudError,
  CrudEvents,
  CrudOperation,
  SortField,
  ValidationResult,
} from './types';

// 导出API客户端
export { crudApi } from './api';
export type { CrudApiMethods } from './api';

// 导出业务逻辑hooks
export { useCrud, useItemForm } from './hooks';

// 导出UI组件
export { CrudView } from './view';

// 导出摘要提供者
export { mvpCrudSummaryProvider } from './summaryProvider';

// 切片元信息
export const SLICE_INFO = {
  name: 'mvp_crud',
  version: '1.0.0',
  description: 'MVP CRUD功能切片 - 展示Web v7架构实现',
  dependencies: [],
  routes: [
    '/crud',
    '/crud/create',
    '/crud/edit/:id',
  ],
} as const;

// 默认导出主组件 - 符合切片注册表期望
export { CrudView as default } from './view'; 