/**
 * 🎯 事件类型定义
 * 定义全局事件总线的事件类型映射
 */

// 导入基础类型
import type { Item } from '../../slices/mvp_crud/types';

// ===== 基础实体类型 =====

/**
 * 用户类型
 */
export interface User {
  id: string;
  name: string;
  email: string;
  token?: string;
}

/**
 * 用户配置文件
 */
export interface Profile {
  id: string;
  userId: string;
  displayName: string;
  avatar?: string;
  bio?: string;
}

/**
 * 购物车项目
 */
export interface CartItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
}

/**
 * 通知类型
 */
export interface Notification {
  id: number;
  message: string;
  type: 'info' | 'error' | 'success' | 'warning';
  timestamp: number;
  duration?: number;
}

// ===== 通用事件类型 =====

/**
 * 通用响应事件
 */
export interface ApiResponseEvent<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  timestamp: number;
}

/**
 * 通用错误事件
 */
export interface ErrorEvent {
  message: string;
  code?: string;
  details?: any;
  timestamp: number;
}

/**
 * 通用加载事件
 */
export interface LoadingEvent {
  isLoading: boolean;
  operation?: string;
  progress?: number;
}

/**
 * 通知事件
 */
export interface NotificationEvent {
  id?: number;
  message: string;
  type: 'success' | 'error' | 'warning' | 'info';
  duration?: number;
  timestamp: number;
}

// ===== 全局事件映射 =====

/**
 * 全局事件映射接口
 * 定义了所有可能的事件类型和其数据结构
 */
export interface GlobalEventMap {
  // 通用系统事件
  'app:init': {};
  'app:ready': {};
  'app:error': ErrorEvent;
  'app:loading': LoadingEvent;
  
  // 通知系统事件
  'notification:show': NotificationEvent;
  'notification:hide': { id: number };
  'notification:clear': {};
  
  // 认证相关事件
  'auth:login': { token: string; user: User };
  'auth:logout': {};
  'auth:token:refresh': { token: string };
  'auth:token:expired': {};
  
  // 用户资料事件
  'profile:updated': { userId: string; profile: Profile };
  
  // 购物车事件
  'cart:item-added': { item: CartItem; total: number };
  
  // CRUD操作事件 - 使用正确的Item类型
  'crud:item:created': { item: Item };
  'crud:item:updated': { item: Item };
  'crud:item:deleted': { itemId: string };
  'crud:items:loaded': { items: Item[]; total: number };
  'crud:error': { operation: string; error: string };
  'crud:operation:start': { operation: string };
  'crud:operation:complete': { operation: string };
  
  // 测试事件
  'test:event': {};
  'test:once': {};
  'test:unsub': {};
  
  // 路由相关事件
  'route:change': { path: string; params?: Record<string, string> };
  'route:before': { from: string; to: string };
  'route:after': { path: string };
  
  // 主题相关事件
  'theme:change': { theme: 'light' | 'dark' };
  'theme:toggle': {};
  
  // 语言相关事件
  'i18n:change': { locale: string };
  
  // 网络相关事件
  'network:online': {};
  'network:offline': {};
  'network:slow': {};
  
  // 数据同步事件
  'sync:start': { type: string };
  'sync:complete': { type: string; success: boolean };
  'sync:conflict': { type: string; data: any };
  
  // 用户操作事件
  'user:action': { action: string; data?: any };
  'user:preference:change': { key: string; value: any };
  
  // 模态框事件
  'modal:open': { id: string; data?: any };
  'modal:close': { id: string };
  
  // 表单事件
  'form:submit': { formId: string; data: any };
  'form:validate': { formId: string; isValid: boolean };
  'form:reset': { formId: string };
  
  // 搜索事件
  'search:query': { query: string; filters?: any };
  'search:results': { query: string; results: any[]; total: number };
  'search:clear': {};
  
  // 文件上传事件
  'upload:start': { fileId: string; fileName: string };
  'upload:progress': { fileId: string; progress: number };
  'upload:complete': { fileId: string; url: string };
  'upload:error': { fileId: string; error: string };
  
  // WebSocket事件
  'websocket:connect': {};
  'websocket:disconnect': {};
  'websocket:message': { type: string; data: any };
  'websocket:error': { error: string };
  
  // 性能监控事件
  'performance:metric': { name: string; value: number; timestamp: number };
  'performance:warning': { metric: string; value: number; threshold: number };
  
  // 缓存事件
  'cache:set': { key: string; value: any };
  'cache:get': { key: string };
  'cache:delete': { key: string };
  'cache:clear': {};
  
  // 权限事件
  'permission:check': { permission: string; granted: boolean };
  'permission:request': { permission: string };
  'permission:denied': { permission: string };
  
  // 配置事件
  'config:change': { key: string; value: any };
  'config:reload': {};
  
  // 调试事件
  'debug:log': { level: string; message: string; data?: any };
  'debug:error': { error: Error; context?: any };
  
  // 统计事件
  'analytics:track': { event: string; properties?: any };
  'analytics:page': { page: string; properties?: any };
  'analytics:user': { userId: string; properties?: any };
  
  // MVP统计分析事件
  'mvp_stat:data_generated': { count: number; distribution: string; seed: number };
  'mvp_stat:stats_calculated': { statistics: string[]; dataSize: number; duration: number };
  'mvp_stat:analysis_completed': { result: any; insights: { dataQuality: string } };
  'mvp_stat:error': { error: string; operation: string };
  'mvp_stat:operation_start': { operation: string };
  'mvp_stat:operation_complete': { operation: string };
}

// ===== 事件处理器类型 =====

/**
 * 事件处理器函数类型
 */
export type EventHandler<T = any> = (data: T) => void | Promise<void>;

/**
 * 事件监听器配置
 */
export interface EventListenerConfig {
  once?: boolean;
  priority?: number;
  passive?: boolean;
}

/**
 * 事件发射器配置
 */
export interface EventEmitterConfig {
  async?: boolean;
  delay?: number;
  maxListeners?: number;
}

// ===== 事件总线接口 =====

/**
 * 事件总线接口
 * 定义了事件总线的基本功能
 */
export interface EventBus {
  // 监听事件
  on<K extends keyof GlobalEventMap>(
    event: K,
    handler: EventHandler<GlobalEventMap[K]>,
    config?: EventListenerConfig
  ): () => void;
  
  // 监听一次性事件
  once<K extends keyof GlobalEventMap>(
    event: K,
    handler: EventHandler<GlobalEventMap[K]>
  ): () => void;

  // 发射事件
  emit<K extends keyof GlobalEventMap>(
    event: K,
    data: GlobalEventMap[K]
  ): void;
  
  // 移除监听器
  off<K extends keyof GlobalEventMap>(
    event: K,
    handler: EventHandler<GlobalEventMap[K]>
  ): void;
  
  // 移除所有监听器
  removeAllListeners(event?: keyof GlobalEventMap): void;
  
  // 获取监听器数量
  listenerCount(event: keyof GlobalEventMap): number;
  
  // 获取所有事件名
  eventNames(): (keyof GlobalEventMap)[];
}

// ===== 工具类型 =====

/**
 * 事件数据提取器
 * 从事件映射中提取特定事件的数据类型
 */
export type EventData<K extends keyof GlobalEventMap> = GlobalEventMap[K];

/**
 * 事件名称联合类型
 */
export type EventName = keyof GlobalEventMap;

/**
 * 事件处理器映射
 */
export type EventHandlerMap = {
  [K in keyof GlobalEventMap]: EventHandler<GlobalEventMap[K]>;
};

// ===== 类型守卫 =====

/**
 * 检查是否为有效的事件名称
 */
export function isValidEventName(name: string): name is EventName {
  // 这里可以添加更严格的验证逻辑
  return typeof name === 'string' && name.length > 0;
}

/**
 * 检查是否为有效的事件数据
 */
export function isValidEventData<K extends keyof GlobalEventMap>(
  event: K,
  data: any
): data is GlobalEventMap[K] {
  // 这里可以添加基于事件类型的数据验证逻辑
  return data !== undefined && data !== null;
}

// ===== 默认值 =====

export const DEFAULT_EVENT_CONFIG: EventListenerConfig = {
  once: false,
  priority: 0,
  passive: false
};

export const DEFAULT_EMITTER_CONFIG: EventEmitterConfig = {
  async: false,
  delay: 0,
  maxListeners: 10
};

// ===== 扩展支持 =====

/**
 * 切片特定事件映射
 * 允许各个切片扩展自己的事件类型
 */
export interface SliceEventMap {
  // 各个切片可以通过模块扩展添加自己的事件类型
}

/**
 * 完整事件映射
 * 合并全局事件和切片事件
 */
export interface CompleteEventMap extends GlobalEventMap, SliceEventMap {}

// 导出主要类型
export type { GlobalEventMap as EventMap };
export type { EventBus as IEventBus }; 