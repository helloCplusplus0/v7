// 🎯 MVP CRUD - 业务逻辑和状态管理
// 遵循Web v7架构规范：Signal-first响应式设计 + 四种解耦通信机制

import { createSignal, createMemo, createEffect, onMount, onCleanup, batch } from 'solid-js';
import { createStore, produce } from 'solid-js/store';

// v7共享基础设施
import { useAsync } from '../../shared/hooks/useAsync';
import { useDebounce, useSearch } from '../../shared/hooks/useDebounce';
import { useLocalStorage } from '../../shared/hooks/useLocalStorage';
import { eventBus } from '../../shared/events/EventBus';
import { useContract } from '../../shared/providers/ContractProvider';
import { createUserAccessor, createNotificationAccessor } from '../../shared/signals/accessors';

// 本地模块
import { crudApi } from './api';
import type {
  Item,
  CreateItemRequest,
  UpdateItemRequest,
  ItemFormData,
  ValidationResult,
  SortField,
  SortOrder,
  CrudEventMap,
  CrudContract,
  UserPreferences
} from './types';
import {
  DEFAULT_PAGE_SIZE,
  DEFAULT_SORT_FIELD,
  DEFAULT_SORT_ORDER,
  ITEM_NAME_MAX_LENGTH,
  ITEM_DESCRIPTION_MAX_LENGTH,
  ITEM_VALUE_MIN,
  ITEM_VALUE_MAX
} from './types';

// ===== 全局信号状态（Signal-first设计） =====

// 项目列表信号
const [items, setItems] = createSignal<Item[]>([]);

// 选中项目信号
const [selectedItem, setSelectedItem] = createSignal<Item | null>(null);

// 加载状态信号
const [loading, setLoading] = createSignal(false);

// 错误状态信号
const [error, setError] = createSignal<string | null>(null);

// 搜索状态信号
const [searchTerm, setSearchTerm] = createSignal('');

// 分页信号
const [currentPage, setCurrentPage] = createSignal(1);
const [pageSize, setPageSize] = createSignal(DEFAULT_PAGE_SIZE);
const [total, setTotal] = createSignal(0);

// 排序信号
const [sortField, setSortField] = createSignal<SortField>(DEFAULT_SORT_FIELD);
const [sortOrder, setSortOrder] = createSignal<SortOrder>(DEFAULT_SORT_ORDER);

// 选中项目ID列表信号
const [selectedIds, setSelectedIds] = createSignal<string[]>([]);

// ===== 计算属性（细粒度响应式） =====

const totalPages = createMemo(() => Math.ceil(total() / pageSize()));
const hasItems = createMemo(() => items().length > 0);
const selectedCount = createMemo(() => selectedIds().length);
const hasSelection = createMemo(() => selectedCount() > 0);
const isEmpty = createMemo(() => !hasItems() && !loading());

// 过滤后的项目列表（本地搜索）
const filteredItems = createMemo(() => {
  const term = searchTerm().toLowerCase().trim();
  if (!term) return items();
  
  return items().filter(item => 
    item.name.toLowerCase().includes(term) ||
    (item.description && item.description.toLowerCase().includes(term))
  );
});

// 排序后的项目列表
const sortedItems = createMemo(() => {
  const itemsToSort = [...filteredItems()];
  const field = sortField();
  const order = sortOrder();
  
  return itemsToSort.sort((a, b) => {
    let aVal: any = a[field];
    let bVal: any = b[field];
    
    // 处理不同类型的排序
    if (field === 'value') {
      aVal = Number(aVal) || 0;
      bVal = Number(bVal) || 0;
    } else if (field === 'createdAt' || field === 'updatedAt') {
      aVal = new Date(aVal).getTime();
      bVal = new Date(bVal).getTime();
    } else {
      aVal = String(aVal).toLowerCase();
      bVal = String(bVal).toLowerCase();
    }
    
    if (aVal < bVal) return order === 'asc' ? -1 : 1;
    if (aVal > bVal) return order === 'asc' ? 1 : -1;
    return 0;
  });
});

// ===== 验证函数 =====

/**
 * 验证项目表单数据
 */
function validateItemForm(data: ItemFormData): ValidationResult {
  const errors: Record<string, string> = {};

  // 名称验证
  if (!data.name.trim()) {
    errors.name = '项目名称不能为空';
  } else if (data.name.length > ITEM_NAME_MAX_LENGTH) {
    errors.name = `项目名称不能超过${ITEM_NAME_MAX_LENGTH}个字符`;
  }

  // 描述验证
  if (data.description.length > ITEM_DESCRIPTION_MAX_LENGTH) {
    errors.description = `项目描述不能超过${ITEM_DESCRIPTION_MAX_LENGTH}个字符`;
  }

  // 数值验证
  if (data.value < ITEM_VALUE_MIN) {
    errors.value = `项目值不能小于${ITEM_VALUE_MIN}`;
  } else if (data.value > ITEM_VALUE_MAX) {
    errors.value = `项目值不能大于${ITEM_VALUE_MAX}`;
  }

  return {
    isValid: Object.keys(errors).length === 0,
    errors
  };
}

// ===== 核心CRUD操作Hook =====

/**
 * 主要的CRUD操作Hook
 * 使用v7四种通信机制：事件驱动、契约接口、信号响应式、Provider模式
 */
export function useCrud() {
  // v7通信机制：访问器模式（信号响应式）
  const userAccessor = createUserAccessor();
  const notificationAccessor = createNotificationAccessor();
  
  // v7通信机制：契约接口（如果需要其他服务）
  // const authContract = useContract('auth');
  // const notificationContract = useContract('notification');

  // 本地存储偏好设置
  const [preferences, setPreferences] = useLocalStorage('crud-preferences', {
    pageSize: DEFAULT_PAGE_SIZE,
    sortField: DEFAULT_SORT_FIELD,
    sortOrder: DEFAULT_SORT_ORDER
  });

  // 防抖搜索
  const debouncedSearch = useDebounce(searchTerm, 300);

     // 异步加载项目列表
   const loadItems = async () => {
     console.log('🔄 [useCrud] 开始加载项目列表');
     setLoading(true);
     setError(null);

     try {
       const response = await crudApi.listItems(
         pageSize(),
         (currentPage() - 1) * pageSize(),
         debouncedSearch() || undefined
       );

       batch(() => {
         setItems(response.items);
         setTotal(response.total);
         setLoading(false);
       });

       console.log('✅ [useCrud] 项目列表加载成功:', response);
       return response;
     } catch (err) {
       const errorMessage = err instanceof Error ? err.message : String(err);
       setError(errorMessage);
       setLoading(false);
       
       // v7通信机制：事件驱动（错误通知）
       eventBus.emit('notification:show', { 
         message: `加载失败: ${errorMessage}`, 
         type: 'error',
         timestamp: Date.now()
       });

       throw err;
     }
   };

  // 创建项目
  const createItem = async (data: CreateItemRequest): Promise<Item> => {
    console.log('🎯 [useCrud] 创建项目:', data);
    
         // 发布操作开始事件（使用通用事件）
    
    try {
      const newItem = await crudApi.createItem(data);
      
      // 更新本地状态
      setItems(prev => [newItem, ...prev]);
      setTotal(prev => prev + 1);
      
             // v7通信机制：事件驱动（成功通知）
      
      // 显示成功通知
      notificationAccessor.addNotification({
        id: Date.now(),
        message: `项目"${newItem.name}"创建成功`,
        type: 'success',
        timestamp: Date.now()
      });
      
      console.log('✅ [useCrud] 项目创建成功:', newItem);
      return newItem;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      
             // v7通信机制：事件驱动（错误通知）
      
      // 显示错误通知
      notificationAccessor.addNotification({
        id: Date.now(),
        message: `创建失败: ${errorMessage}`,
        type: 'error',
        timestamp: Date.now()
      });
      
      throw error;
    }
  };

  // 更新项目
  const updateItem = async (id: string, data: UpdateItemRequest): Promise<Item> => {
    console.log('🎯 [useCrud] 更新项目:', { id, data });
    
    eventBus.emit('crud:operation:start', { operation: 'update' });
    
    try {
      const updatedItem = await crudApi.updateItem(id, data);
      
      // 更新本地状态
      setItems(produce(items => {
        const index = items.findIndex(item => item.id === id);
        if (index !== -1) {
          items[index] = updatedItem;
        }
      }));
      
      // 如果更新的是当前选中项目，也要更新选中状态
      if (selectedItem()?.id === id) {
        setSelectedItem(updatedItem);
      }
      
      // v7通信机制：事件驱动
      eventBus.emit('crud:item:updated', { item: updatedItem });
      eventBus.emit('crud:operation:complete', { operation: 'update' });
      
      // 显示成功通知
      notificationAccessor.addNotification({
        id: Date.now(),
        message: `项目"${updatedItem.name}"更新成功`,
        type: 'success',
        timestamp: Date.now()
      });
      
      console.log('✅ [useCrud] 项目更新成功:', updatedItem);
      return updatedItem;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      
      eventBus.emit('crud:error', { operation: 'update', error: errorMessage });
      
      notificationAccessor.addNotification({
        id: Date.now(),
        message: `更新失败: ${errorMessage}`,
        type: 'error',
        timestamp: Date.now()
      });
      
      throw error;
    }
  };

  // 删除项目
  const deleteItem = async (id: string): Promise<void> => {
    console.log('🎯 [useCrud] 删除项目:', id);
    
    eventBus.emit('crud:operation:start', { operation: 'delete' });
    
    try {
      await crudApi.deleteItem(id);
      
      // 更新本地状态
      setItems(prev => prev.filter(item => item.id !== id));
      setTotal(prev => prev - 1);
      setSelectedIds(prev => prev.filter(selectedId => selectedId !== id));
      
      // 如果删除的是当前选中项目，清除选中状态
      if (selectedItem()?.id === id) {
        setSelectedItem(null);
      }
      
      // v7通信机制：事件驱动
      eventBus.emit('crud:item:deleted', { itemId: id });
      eventBus.emit('crud:operation:complete', { operation: 'delete' });
      
      // 显示成功通知
      notificationAccessor.addNotification({
        id: Date.now(),
        message: '项目删除成功',
        type: 'success',
        timestamp: Date.now()
      });
      
      console.log('✅ [useCrud] 项目删除成功');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      
      eventBus.emit('crud:error', { operation: 'delete', error: errorMessage });
      
      notificationAccessor.addNotification({
        id: Date.now(),
        message: `删除失败: ${errorMessage}`,
        type: 'error',
        timestamp: Date.now()
      });
      
      throw error;
    }
  };

  // 批量删除项目
  const deleteSelectedItems = async (): Promise<void> => {
    const ids = selectedIds();
    if (ids.length === 0) return;
    
    console.log('🎯 [useCrud] 批量删除项目:', ids);
    
    try {
      const result = await crudApi.batchDeleteItems(ids);
      
      if (result.success > 0) {
        // 刷新列表
        await loadItems();
        setSelectedIds([]);
        
        notificationAccessor.addNotification({
          id: Date.now(),
          message: `成功删除 ${result.success} 个项目`,
          type: 'success',
          timestamp: Date.now()
        });
      }
      
      if (result.failed > 0) {
        notificationAccessor.addNotification({
          id: Date.now(),
          message: `${result.failed} 个项目删除失败`,
          type: 'error',
          timestamp: Date.now()
        });
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      notificationAccessor.addNotification({
        id: Date.now(),
        message: `批量删除失败: ${errorMessage}`,
        type: 'error',
        timestamp: Date.now()
      });
    }
  };

  // 选择操作
  const toggleSelection = (id: string) => {
    setSelectedIds(prev => 
      prev.includes(id) 
        ? prev.filter(selectedId => selectedId !== id)
        : [...prev, id]
    );
  };

  const toggleSelectAll = () => {
    const allIds = sortedItems().map(item => item.id);
    setSelectedIds(prev => 
      prev.length === allIds.length ? [] : allIds
    );
  };

  // 分页操作
  const goToPage = (page: number) => {
    if (page >= 1 && page <= totalPages()) {
      setCurrentPage(page);
    }
  };

  const nextPage = () => goToPage(currentPage() + 1);
  const prevPage = () => goToPage(currentPage() - 1);

  const changePageSize = (size: number) => {
    setPageSize(size);
    setCurrentPage(1);
    setPreferences({ 
      ...preferences(), 
      pageSize: size 
    });
  };

  // 排序操作
  const sort = (field: SortField) => {
    if (sortField() === field) {
      // 切换排序方向
      const newOrder = sortOrder() === 'asc' ? 'desc' : 'asc';
      setSortOrder(newOrder);
      setPreferences({ 
        ...preferences(), 
        sortOrder: newOrder 
      });
    } else {
      // 切换排序字段
      setSortField(field);
      setSortOrder('asc');
      setPreferences({ 
        ...preferences(), 
        sortField: field, 
        sortOrder: 'asc' 
      });
    }
  };

  // 搜索操作
  const clearSearch = () => setSearchTerm('');

  // 刷新操作
  const refresh = () => {
    if (shouldLoad()) {
      setLoadTrigger(prev => prev + 1);
    }
  };

  // 清除错误
  const clearError = () => setError(null);

  // 获取项目详情
  const getItem = async (id: string): Promise<Item | null> => {
    try {
      return await crudApi.getItem(id);
    } catch (error) {
      console.error('获取项目详情失败:', error);
      return null;
    }
  };

  // 🔄 数据加载控制信号
  const [shouldLoad, setShouldLoad] = createSignal(false);
  const [loadTrigger, setLoadTrigger] = createSignal(0);

  // v7通信机制：事件监听（组件挂载时）
  onMount(() => {
    // 监听认证状态变化
    const unsubscribeAuth = eventBus.on('auth:logout', () => {
      // 用户登出时清除数据
      batch(() => {
        setItems([]);
        setSelectedItem(null);
        setSelectedIds([]);
        setTotal(0);
        setCurrentPage(1);
        clearError();
      });
    });

    // 监听其他切片的相关事件
    const unsubscribeItemUpdate = eventBus.on('crud:item:updated', ({ item }) => {
      console.log('📡 [useCrud] 收到项目更新事件:', item);
    });

    // 初始化加载偏好设置
    batch(() => {
      setPageSize(preferences().pageSize);
      setSortField(preferences().sortField);
      setSortOrder(preferences().sortOrder);
      // 标记可以开始加载数据
      setShouldLoad(true);
    });

    // 清理函数
    onCleanup(() => {
      unsubscribeAuth();
      unsubscribeItemUpdate();
    });
  });

  // 🎯 统一的数据加载effect - 避免重复请求
  createEffect(() => {
    // 只有在允许加载且有加载触发时才执行
    if (!shouldLoad()) return;
    
    const trigger = loadTrigger();
    const term = debouncedSearch();
    const page = currentPage();
    const size = pageSize();
    
    // 确保基本参数有效
    if (page > 0 && size > 0) {
      console.log('🔄 [useCrud] 统一加载触发:', { trigger, term, page, size });
      loadItems();
    }
  });

  // 监听搜索变化，触发加载
  createEffect(() => {
    const term = debouncedSearch();
    if (shouldLoad() && term !== undefined) {
      setCurrentPage(1);
      setLoadTrigger(prev => prev + 1);
    }
  });

  // 监听分页变化，触发加载
  createEffect(() => {
    const page = currentPage();
    const size = pageSize();
    if (shouldLoad() && page > 0 && size > 0) {
      setLoadTrigger(prev => prev + 1);
    }
  });

  return {
    // 状态信号
    items: sortedItems,
    selectedItem,
    loading: createMemo(() => loading()),
    error,
    searchTerm,
    currentPage,
    pageSize,
    total,
    sortField,
    sortOrder,
    selectedIds,
    
    // 计算属性
    totalPages,
    hasItems,
    selectedCount,
    hasSelection,
    isEmpty,
    filteredItems,
    
    // 基本操作
    loadItems,
    createItem,
    updateItem,
    deleteItem,
    getItem,
    
    // 批量操作
    deleteSelectedItems,
    toggleSelection,
    toggleSelectAll,
    
    // 列表操作
    sort,
    goToPage,
    nextPage,
    prevPage,
    changePageSize,
    
    // 搜索操作
    setSearchTerm,
    clearSearch,
    
    // 其他操作
    refresh,
    clearError,
    setSelectedItem,
    
    // 工具函数
    validateForm: validateItemForm
  };
}

// ===== 表单管理Hook =====

/**
 * 项目表单管理Hook
 * 专门处理表单状态、验证和提交
 */
export function useItemForm(initialData?: Partial<ItemFormData>) {
  const [formData, setFormData] = createStore<ItemFormData>({
    name: '',
    description: '',
    value: 0,
    ...initialData
  });

  const [errors, setErrors] = createSignal<Record<string, string>>({});
  const [touched, setTouched] = createSignal<Record<string, boolean>>({});
  const [submitting, setSubmitting] = createSignal(false);

  // 实时验证
  const validation = createMemo(() => validateItemForm(formData));
  const isValid = createMemo(() => validation().isValid);
  const hasErrors = createMemo(() => Object.keys(errors()).length > 0);
  const canSubmit = createMemo(() => isValid() && !submitting());

  // 更新字段
  const updateField = (field: keyof ItemFormData, value: any) => {
    setFormData(field, value);
    
    // 标记字段为已修改
    setTouched(prev => ({ ...prev, [field]: true }));
    
    // 实时验证
    const result = validateItemForm(formData);
    setErrors(result.errors);
  };

  // 重置表单
  const reset = (data?: Partial<ItemFormData>) => {
    setFormData({
      name: '',
      description: '',
      value: 0,
      ...data
    });
    setErrors({});
    setTouched({});
    setSubmitting(false);
  };

  // 验证所有字段
  const validate = () => {
    const result = validateItemForm(formData);
    setErrors(result.errors);
    
    // 标记所有字段为已修改
    setTouched({
      name: true,
      description: true,
      value: true
    });
    
    return result.isValid;
  };

  // 提交表单
  const submit = async (onSubmit: (data: ItemFormData) => Promise<void>) => {
    if (!validate()) return false;
    
    setSubmitting(true);
    try {
      await onSubmit(formData);
      reset();
      return true;
    } catch (error) {
      console.error('表单提交失败:', error);
      return false;
    } finally {
      setSubmitting(false);
    }
  };

  return {
    // 状态
    formData,
    errors,
    touched,
    submitting,
    
    // 计算属性
    isValid,
    hasErrors,
    canSubmit,
    
    // 操作方法
    updateField,
    reset,
    validate,
    submit
  };
}

// ===== 契约接口实现 =====

/**
 * CRUD契约接口实现
 * 为其他切片提供标准化的CRUD服务
 */
export function createCrudContract(): CrudContract {
  return {
    async getItems() {
      return items();
    },
    
    async getItem(id: string) {
      return items().find(item => item.id === id) || null;
    },
    
    async createItem(data: CreateItemRequest) {
      return crudApi.createItem(data);
    },
    
    async updateItem(id: string, data: UpdateItemRequest) {
      return crudApi.updateItem(id, data);
    },
    
    async deleteItem(id: string) {
      await crudApi.deleteItem(id);
    },
    
    getTotalCount() {
      return total();
    },
    
    isLoading() {
      return loading();
    },
    
    getError() {
      return error();
    }
  };
} 