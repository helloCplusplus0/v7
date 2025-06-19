// 📦 MVP CRUD - 数据类型定义
// 与后端API保持一致的类型定义

export interface Item {
  id: string;
  name: string;
  description?: string;
  value: number;
  created_at: string;
  updated_at: string;
}

export interface CreateItemRequest {
  name: string;
  description?: string;
  value: number;
}

export interface UpdateItemRequest {
  name?: string;
  description?: string;
  value?: number;
}

export interface ListItemsQuery {
  limit?: number;
  offset?: number;
  sort_by?: string;
  order?: 'asc' | 'desc';
}

export interface CreateItemResponse {
  item: Item;
  message: string;
}

export interface GetItemResponse {
  item: Item;
}

export interface UpdateItemResponse {
  item: Item;
  message: string;
}

export interface DeleteItemResponse {
  message: string;
  deleted_id: string;
}

export interface ListItemsResponse {
  items: Item[];
  total: number;
  limit: number;
  offset: number;
}

// UI状态类型
export interface CrudState {
  items: Item[];
  currentItem: Item | null;
  loading: boolean;
  error: string | null;
  total: number;
  currentPage: number;
  pageSize: number;
  sortBy: string;
  sortOrder: 'asc' | 'desc';
}

// 表单状态类型
export interface ItemFormData {
  name: string;
  description: string;
  value: number;
}

// 错误类型
export interface CrudError {
  type: 'validation' | 'network' | 'server' | 'not_found' | 'conflict';
  message: string;
  field?: string;
}

// 事件类型
export interface CrudEvents {
  'crud:item:created': { item: Item };
  'crud:item:updated': { item: Item };
  'crud:item:deleted': { id: string };
  'crud:list:refreshed': { total: number };
}

// 操作类型
export type CrudOperation = 'create' | 'read' | 'update' | 'delete' | 'list';

// 排序字段类型
export type SortField = 'name' | 'value' | 'created_at' | 'updated_at';

// 表单验证结果
export interface ValidationResult {
  isValid: boolean;
  errors: Record<string, string>;
} 