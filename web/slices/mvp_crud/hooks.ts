// 🎯 MVP CRUD - 业务逻辑和状态管理
// 使用SolidJS Signal-first响应式设计实现CRUD操作

import { createSignal, createMemo, batch } from 'solid-js';
import { createStore, produce } from 'solid-js/store';
import { crudApi } from './api';
import type {
  Item,
  CreateItemRequest,
  UpdateItemRequest,
  ListItemsQuery,
  CrudState,
  ItemFormData,
  ValidationResult,
  SortField,
} from './types';

// 全局CRUD状态信号
const [crudState, setCrudState] = createStore<CrudState>({
  items: [],
  currentItem: null,
  loading: false,
  error: null,
  total: 0,
  currentPage: 1,
  pageSize: 10,
  sortBy: 'created_at',
  sortOrder: 'desc',
});

// 选中项目的信号
const [selectedIds, setSelectedIds] = createSignal<string[]>([]);

/**
 * 表单验证函数
 */
function validateItemForm(data: ItemFormData): ValidationResult {
  const errors: Record<string, string> = {};

  if (!data['name'].trim()) {
    errors['name'] = '项目名称不能为空';
  } else if (data['name'].length > 100) {
    errors['name'] = '项目名称不能超过100个字符';
  }

  if (data['description'].length > 500) {
    errors['description'] = '项目描述不能超过500个字符';
  }

  if (data['value'] < 0) {
    errors['value'] = '项目值不能为负数';
  }

  return {
    isValid: Object.keys(errors).length === 0,
    errors,
  };
}

/**
 * CRUD操作的核心Hook
 */
export function useCrud() {
  // 异步操作状态
  const [asyncLoading, setAsyncLoading] = createSignal(false);
  const [asyncError, setAsyncError] = createSignal<string | null>(null);

  // 计算属性
  const isLoading = createMemo(() => crudState.loading || asyncLoading());
  const hasItems = createMemo(() => crudState.items.length > 0);
  const totalPages = createMemo(() => Math.ceil(crudState.total / crudState.pageSize));
  const selectedCount = createMemo(() => selectedIds().length);
  const hasSelected = createMemo(() => selectedCount() > 0);

  // 执行异步操作的通用函数
  const executeAsync = async <T>(fn: () => Promise<T>): Promise<T> => {
    try {
      setAsyncLoading(true);
      setAsyncError(null);
      return await fn();
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      setAsyncError(errorMessage);
      throw error;
    } finally {
      setAsyncLoading(false);
    }
  };

  // 加载项目列表
  const loadItems = async (query?: Partial<ListItemsQuery>) => {
    const listQuery: ListItemsQuery = {
      limit: crudState.pageSize,
      offset: (crudState.currentPage - 1) * crudState.pageSize,
      sort_by: crudState.sortBy,
      order: crudState.sortOrder,
      ...query,
    };

    return executeAsync(async () => {
      setCrudState('loading', true);
      setCrudState('error', null);

      try {
        const response = await crudApi.listItems(listQuery);
        
        batch(() => {
          setCrudState('items', response.items);
          setCrudState('total', response.total);
          setCrudState('loading', false);
        });

        return response;
      } catch (error) {
        setCrudState('error', `加载失败: ${error}`);
        setCrudState('loading', false);
        throw error;
      }
    });
  };

  // 获取单个项目
  const getItem = async (id: string) => {
    return executeAsync(async () => {
      const response = await crudApi.getItem(id);
      setCrudState('currentItem', response.item);
      return response.item;
    });
  };

  // 创建项目
  const createItem = async (data: CreateItemRequest) => {
    return executeAsync(async () => {
      const response = await crudApi.createItem(data);
      
      // 添加到本地状态
      setCrudState('items', [response.item, ...crudState.items]);
      setCrudState('total', crudState.total + 1);
      
      return response;
    });
  };

  // 更新项目
  const updateItem = async (id: string, data: UpdateItemRequest) => {
    console.log('🎯 hooks.updateItem called with id:', id, 'data:', data);
    return executeAsync(async () => {
      console.log('📡 Calling crudApi.updateItem');
      const response = await crudApi.updateItem(id, data);
      console.log('📡 crudApi.updateItem response:', response);
      
      // 更新本地状态
      setCrudState('items', produce((items) => {
        const index = items.findIndex(item => item.id === id);
        if (index !== -1) {
          items[index] = response.item;
        }
      }));
      
      // 如果是当前项目，也更新currentItem
      if (crudState.currentItem?.id === id) {
        setCrudState('currentItem', response.item);
      }
      
      return response;
    });
  };

  // 删除项目
  const deleteItem = async (id: string) => {
    return executeAsync(async () => {
      const response = await crudApi.deleteItem(id);
      
      // 从本地状态移除
      setCrudState('items', crudState.items.filter(item => item.id !== id));
      setCrudState('total', crudState.total - 1);
      
      // 如果是当前项目，清除currentItem
      if (crudState.currentItem?.id === id) {
        setCrudState('currentItem', null);
      }
      
      // 从选中列表移除
      setSelectedIds(prev => prev.filter(selectedId => selectedId !== id));
      
      return response;
    });
  };

  // 批量删除
  const deleteSelectedItems = async () => {
    const ids = selectedIds();
    if (ids.length === 0) return;

    return executeAsync(async () => {
      const response = await crudApi.deleteItems(ids);
      
      // 从本地状态移除
      setCrudState('items', crudState.items.filter(item => !ids.includes(item.id)));
      setCrudState('total', crudState.total - response.deleted_count);
      
      // 清空选中状态
      setSelectedIds([]);
      
      return response;
    });
  };

  // 切换项目选中状态
  const toggleSelection = (id: string) => {
    setSelectedIds(prev => {
      if (prev.includes(id)) {
        return prev.filter(selectedId => selectedId !== id);
      } else {
        return [...prev, id];
      }
    });
  };

  // 全选/取消全选
  const toggleSelectAll = () => {
    const allIds = crudState.items.map(item => item.id);
    const isAllSelected = selectedIds().length === crudState.items.length;
    
    if (isAllSelected) {
      setSelectedIds([]);
    } else {
      setSelectedIds(allIds);
    }
  };

  // 排序
  const sort = (field: SortField) => {
    let order: 'asc' | 'desc' = 'asc';
    
    // 如果点击的是当前排序字段，切换排序方向
    if (crudState.sortBy === field) {
      order = crudState.sortOrder === 'asc' ? 'desc' : 'asc';
    }
    
    batch(() => {
      setCrudState('sortBy', field);
      setCrudState('sortOrder', order);
      setCrudState('currentPage', 1); // 重置到第一页
    });
    
    // 重新加载数据
    loadItems();
  };

  // 分页
  const goToPage = (page: number) => {
    if (page < 1 || page > totalPages()) return;
    
    setCrudState('currentPage', page);
    loadItems();
  };

  const nextPage = () => goToPage(crudState.currentPage + 1);
  const prevPage = () => goToPage(crudState.currentPage - 1);

  // 更改页面大小
  const changePageSize = (size: number) => {
    batch(() => {
      setCrudState('pageSize', size);
      setCrudState('currentPage', 1);
    });
    loadItems();
  };

  // 刷新数据
  const refresh = () => {
    setSelectedIds([]);
    return loadItems();
  };

  // 清除错误
  const clearError = () => {
    setCrudState('error', null);
    setAsyncError(null);
  };

  return {
    // 状态
    state: crudState,
    isLoading,
    error: createMemo(() => crudState.error || asyncError()),
    
    // 计算属性
    hasItems,
    totalPages,
    selectedIds,
    selectedCount,
    hasSelected,
    
    // 基本操作
    loadItems,
    getItem,
    createItem,
    updateItem,
    deleteItem,
    
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
    refresh,
    clearError,
    
    // 工具函数
    validateForm: validateItemForm,
  };
}

/**
 * 表单管理Hook
 */
export function useItemForm(initialData?: Partial<ItemFormData>) {
  const [formData, setFormData] = createStore<ItemFormData>({
    name: '',
    description: '',
    value: 0,
    ...initialData,
  });

  const [errors, setErrors] = createSignal<Record<string, string>>({});
  const [touched, setTouched] = createSignal<Record<string, boolean>>({});

  const validation = createMemo(() => validateItemForm(formData));
  const isValid = createMemo(() => validation().isValid);
  const hasErrors = createMemo(() => Object.keys(errors()).length > 0);

  const updateField = (field: keyof ItemFormData, value: any) => {
    setFormData(field, value);
    
    // 标记字段为已修改
    setTouched(prev => ({ ...prev, [field]: true }));
    
    // 实时验证
    const result = validateItemForm(formData);
    setErrors(result.errors);
  };

  const reset = (data?: Partial<ItemFormData>) => {
    setFormData({
      name: '',
      description: '',
      value: 0,
      ...data,
    });
    setErrors({});
    setTouched({});
  };

  const validate = () => {
    const result = validateItemForm(formData);
    setErrors(result.errors);
    
    // 标记所有字段为已修改
    setTouched({
      name: true,
      description: true,
      value: true,
    });
    
    return result.isValid;
  };

  return {
    formData,
    errors,
    touched,
    isValid,
    hasErrors,
    updateField,
    reset,
    validate,
  };
} 