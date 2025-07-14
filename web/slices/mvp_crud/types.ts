// 📦 MVP CRUD - 数据类型定义
// 遵循Web v7架构规范，与后端gRPC proto完全一致

// ===== 核心实体类型 =====

/**
 * 项目实体 - 与后端proto Item消息完全对应
 * 注意：使用proto字段名（camelCase）而非snake_case
 */
export interface Item {
  id: string;
  name: string;
  description?: string;
  value: number;
  createdAt: string;    // proto字段名：createdAt
  updatedAt: string;    // proto字段名：updatedAt
}

// ===== API请求/响应类型 =====

/**
 * 创建项目请求 - 对应proto CreateItemRequest
 */
export interface CreateItemRequest {
  name: string;
  description?: string;
  value?: number;
}

/**
 * 更新项目请求 - 对应proto UpdateItemRequest
 */
export interface UpdateItemRequest {
  name?: string;
  description?: string;
  value?: number;
}

/**
 * 获取项目请求 - 对应proto GetItemRequest
 */
export interface GetItemRequest {
  id: string;
}

/**
 * 删除项目请求 - 对应proto DeleteItemRequest
 */
export interface DeleteItemRequest {
  id: string;
}

/**
 * 列表查询请求 - 对应proto ListItemsRequest
 */
export interface ListItemsRequest {
  limit?: number;
  offset?: number;
  search?: string;
}

/**
 * 创建项目响应 - 对应proto CreateItemResponse
 */
export interface CreateItemResponse {
  success: boolean;
  error: string;
  item?: Item;
}

/**
 * 获取项目响应 - 对应proto GetItemResponse
 */
export interface GetItemResponse {
  success: boolean;
  error: string;
  item?: Item;
}

/**
 * 更新项目响应 - 对应proto UpdateItemResponse
 */
export interface UpdateItemResponse {
  success: boolean;
  error: string;
  item?: Item;
}

/**
 * 删除项目响应 - 对应proto DeleteItemResponse
 */
export interface DeleteItemResponse {
  success: boolean;
  error: string;
}

/**
 * 列表项目响应 - 对应proto ListItemsResponse
 */
export interface ListItemsResponse {
  success: boolean;
  error: string;
  items: Item[];
  total: number;
}

// ===== 本地状态类型 =====

/**
 * 单个信号状态（遵循v7 Signal-first原则）
 */
export interface CrudSignals {
  items: Item[];
  selectedItem: Item | null;
  loading: boolean;
  error: string | null;
  searchTerm: string;
  currentPage: number;
  pageSize: number;
  sortField: SortField;
  sortOrder: SortOrder;
  total: number;
}

/**
 * 表单数据类型
 */
export interface ItemFormData {
  name: string;
  description: string;
  value: number;
}

/**
 * 表单验证结果
 */
export interface ValidationResult {
  isValid: boolean;
  errors: Record<string, string>;
}

// ===== 枚举类型 =====

/**
 * 排序字段
 */
export type SortField = 'name' | 'value' | 'createdAt' | 'updatedAt';

/**
 * 排序方向
 */
export type SortOrder = 'asc' | 'desc';

/**
 * CRUD操作类型
 */
export type CrudOperation = 'create' | 'read' | 'update' | 'delete' | 'list';

/**
 * 操作状态
 */
export type OperationStatus = 'idle' | 'pending' | 'success' | 'error';

// ===== 事件类型（用于EventBus） =====

/**
 * CRUD事件映射 - 扩展全局EventMap
 */
export interface CrudEventMap {
  'crud:item:created': { item: Item };
  'crud:item:updated': { item: Item };
  'crud:item:deleted': { itemId: string };
  'crud:items:loaded': { items: Item[]; total: number };
  'crud:error': { operation: CrudOperation; error: string };
  'crud:operation:start': { operation: CrudOperation };
  'crud:operation:complete': { operation: CrudOperation };
}

// ===== 契约接口类型 =====

/**
 * CRUD契约接口 - 定义对外提供的服务
 */
export interface CrudContract {
  // 查询操作
  getItems(): Promise<Item[]>;
  getItem(id: string): Promise<Item | null>;
  
  // 修改操作
  createItem(data: CreateItemRequest): Promise<Item>;
  updateItem(id: string, data: UpdateItemRequest): Promise<Item>;
  deleteItem(id: string): Promise<void>;
  
  // 状态查询
  getTotalCount(): number;
  isLoading(): boolean;
  getError(): string | null;
}

// ===== 组件Props类型 =====

/**
 * CRUD视图组件Props
 */
export interface CrudViewProps {
  className?: string;
  onItemSelect?: (item: Item) => void;
  onItemCreate?: (item: Item) => void;
  onItemUpdate?: (item: Item) => void;
  onItemDelete?: (itemId: string) => void;
  showCreateButton?: boolean;
  showSearch?: boolean;
  pageSize?: number;
}

/**
 * 项目卡片组件Props
 */
export interface ItemCardProps {
  item: Item;
  selected?: boolean;
  onSelect?: (item: Item) => void;
  onEdit?: (item: Item) => void;
  onDelete?: (item: Item) => void;
  className?: string;
}

/**
 * 项目表单组件Props
 */
export interface ItemFormProps {
  item?: Item;
  onSubmit: (data: ItemFormData) => Promise<void>;
  onCancel: () => void;
  loading?: boolean;
  className?: string;
}

// ===== 工具类型 =====

/**
 * 分页信息
 */
export interface PaginationInfo {
  current: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

/**
 * 排序信息
 */
export interface SortInfo {
  field: SortField;
  order: SortOrder;
}

/**
 * 搜索过滤器
 */
export interface SearchFilter {
  term: string;
  fields: (keyof Item)[];
}

/**
 * 批量操作结果
 */
export interface BatchOperationResult {
  success: number;
  failed: number;
  errors: string[];
}

// ===== 用户偏好设置类型 =====

/**
 * 用户偏好设置
 */
export interface UserPreferences {
  pageSize: number;
  sortField: SortField;
  sortOrder: SortOrder;
}

// ===== 类型守卫函数 =====

/**
 * 检查对象是否为有效的Item
 */
export function isValidItem(obj: any): obj is Item {
  if (!obj || typeof obj !== 'object' || obj === null) {
    return false;
  }
  
  return (
    typeof obj.id === 'string' &&
    obj.id.trim().length > 0 &&
    typeof obj.name === 'string' &&
    obj.name.trim().length > 0 &&
    typeof obj.value === 'number' &&
    !isNaN(obj.value) &&
    typeof obj.createdAt === 'string' &&
    obj.createdAt.length > 0 &&
    typeof obj.updatedAt === 'string' &&
    obj.updatedAt.length > 0 &&
    // 可选字段验证
    (obj.description === undefined || (typeof obj.description === 'string' && obj.description.trim().length > 0))
  );
}

/**
 * 检查对象是否为有效的CreateItemRequest
 */
export function isValidCreateRequest(obj: any): obj is CreateItemRequest {
  if (!obj || typeof obj !== 'object' || obj === null) {
    return false;
  }
  
  return (
    typeof obj.name === 'string' &&
    obj.name.trim().length > 0 &&
    // 可选字段验证
    (obj.description === undefined || (typeof obj.description === 'string')) &&
    (obj.value === undefined || (typeof obj.value === 'number' && !isNaN(obj.value)))
  );
}

// ===== 默认值常量 =====

export const DEFAULT_PAGE_SIZE = 10;
export const DEFAULT_SORT_FIELD: SortField = 'createdAt';
export const DEFAULT_SORT_ORDER: SortOrder = 'desc';

export const ITEM_NAME_MAX_LENGTH = 100;
export const ITEM_DESCRIPTION_MAX_LENGTH = 500;
export const ITEM_VALUE_MIN = 0;
export const ITEM_VALUE_MAX = 999999; 