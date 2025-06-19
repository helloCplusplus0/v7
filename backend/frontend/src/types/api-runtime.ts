// 🎯 FMOD v7 API Types - 运行时生成，100%准确
// 自动生成，请勿手动修改
// 生成时间: 2025-06-18 08:21:43 UTC

// =============================================================================
// HTTP响应包装器
// =============================================================================

export interface HttpResponse<T> {
  status: number;
  message: string;
  data?: T;
  error?: {
    code: string;
    message: string;
    context?: string;
  };
  trace_id?: string;
  timestamp: number;
}

// =============================================================================
// 认证相关类型
// =============================================================================

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user_id: string;
  expires_at: string;
}

export interface UserSession {
  user_id: string;
  username: string;
  token_expires: string;
}

// =============================================================================
// Items CRUD 类型
// =============================================================================

export interface Item {
  id: string;
  name: string;
  description?: string;
  value?: number;
  created_at: string;
  updated_at: string;
}

export interface CreateItemRequest {
  name: string;
  description?: string;
  value?: number;
}

export interface UpdateItemRequest {
  name?: string;
  description?: string;
  value?: number;
}

export interface ItemsListResponse {
  items: Item[];
  total: number;
  page: number;
  page_size: number;
  has_next: boolean;
  has_prev: boolean;
}

export interface ListItemsQuery {
  page?: number;
  page_size?: number;
  search?: string;
  sort_by?: string;
  sort_order?: 'asc' | 'desc';
}

// =============================================================================
// 系统相关类型
// =============================================================================

export interface HealthResponse {
  status: 'healthy' | 'unhealthy';
  timestamp: string;
  version: string;
  uptime: number;
  environment: string;
}

export interface ApiInfo {
  name: string;
  version: string;
  architecture: string;
  features: string[];
  endpoints: Record<string, any>;
  middleware: string[];
}

// =============================================================================
// 用户事件类型
// =============================================================================

export interface UserEvent {
  id: string;
  user_id: string;
  event_type: string;
  data: Record<string, any>;
  timestamp: string;
}

export interface UserEventsResponse {
  events: UserEvent[];
  total: number;
  page: number;
  page_size: number;
}

// =============================================================================
// 错误类型
// =============================================================================

export interface ApiError {
  code: string;
  message: string;
  context?: string;
  trace_id?: string;
  timestamp: string;
}

// =============================================================================
// 分页查询参数
// =============================================================================

export interface PaginationQuery {
  page?: number;
  page_size?: number;
  sort_by?: string;
  sort_order?: 'asc' | 'desc';
}

// =============================================================================
// 运行时统计信息
// =============================================================================

export interface RuntimeStats {
  total_requests: number;
  endpoints: EndpointStats[];
  generated_at: string;
}

export interface EndpointStats {
  path: string;
  method: string;
  count: number;
  avg_response_time: number;
  last_called: string;
}
