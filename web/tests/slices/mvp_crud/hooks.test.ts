// 🧪 MVP CRUD Hooks 单元测试 - 核心功能版本
// 专注测试核心业务逻辑，避免复杂的mock设置

import { describe, test, expect, beforeEach, vi } from 'vitest';
import { createRoot } from 'solid-js';
import { createMockItem, createMockCreateRequest } from './test-utils';

// 简化的Mock设置 - 只mock必要的依赖
vi.mock('../../../slices/mvp_crud/api', () => ({
  crudApi: {
    createItem: vi.fn(),
    getItem: vi.fn(),
    updateItem: vi.fn(),
    deleteItem: vi.fn(),
    listItems: vi.fn(),
    batchDeleteItems: vi.fn(),
    healthCheck: vi.fn()
  }
}));

vi.mock('../../../shared/events/EventBus', () => ({
  eventBus: {
    emit: vi.fn(),
    on: vi.fn(() => vi.fn()), // 返回unsubscribe函数
    off: vi.fn(),
    removeAllListeners: vi.fn()
  }
}));

// 简化的信号访问器mock
vi.mock('../../../shared/signals/accessors', () => ({
  createUserAccessor: vi.fn(() => ({
    getUser: vi.fn(() => ({ id: 'test-user', name: 'Test User' })),
    setUser: vi.fn(),
    isAuthenticated: vi.fn(() => true),
    getUserId: vi.fn(() => 'test-user')
  })),
  createNotificationAccessor: vi.fn(() => ({
    getNotifications: vi.fn(() => []),
    setNotifications: vi.fn(),
    addNotification: vi.fn(),
    removeNotification: vi.fn(),
    clearNotifications: vi.fn()
  }))
}));

// 简化的本地存储mock
vi.mock('../../../shared/hooks/useLocalStorage', () => ({
  useLocalStorage: vi.fn(() => [
    vi.fn(() => ({ pageSize: 10, sortField: 'createdAt', sortOrder: 'desc' })),
    vi.fn()
  ])
}));

// 简化的防抖mock
vi.mock('../../../shared/hooks/useDebounce', () => ({
  useDebounce: vi.fn((value) => value),
  useSearch: vi.fn(() => ({
    searchInput: vi.fn(() => ''),
    setSearchInput: vi.fn(),
    debouncedSearch: vi.fn(() => ''),
    clearSearch: vi.fn()
  }))
}));

describe('MVP CRUD Hooks - 核心功能测试', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('useItemForm Hook', () => {
    test('应该正确初始化表单状态', async () => {
      const { useItemForm } = await import('../../../slices/mvp_crud/hooks');
      
      createRoot(() => {
        const form = useItemForm();
        
        expect(form.formData.name).toBe('');
        expect(form.formData.description).toBe('');
        expect(form.formData.value).toBe(0);
        expect(form.submitting()).toBe(false);
        expect(form.isValid()).toBe(false); // 因为name为空
      });
    });

    test('应该支持字段更新', async () => {
      const { useItemForm } = await import('../../../slices/mvp_crud/hooks');
      
      createRoot(() => {
        const form = useItemForm();
        
        form.updateField('name', '测试项目');
        expect(form.formData.name).toBe('测试项目');
        
        form.updateField('value', 100);
        expect(form.formData.value).toBe(100);
      });
    });

    test('应该支持表单重置', async () => {
      const { useItemForm } = await import('../../../slices/mvp_crud/hooks');
      
      createRoot(() => {
        const form = useItemForm();
        
        form.updateField('name', '测试项目');
        form.updateField('value', 100);
        
        form.reset();
        
        expect(form.formData.name).toBe('');
        expect(form.formData.value).toBe(0);
      });
    });

    test('应该支持表单验证', async () => {
      const { useItemForm } = await import('../../../slices/mvp_crud/hooks');
      
      createRoot(() => {
        const form = useItemForm();
        
        // 无效状态
        expect(form.validate()).toBe(false);
        expect(form.canSubmit()).toBe(false);
        
        // 有效状态
        form.updateField('name', '测试项目');
        expect(form.validate()).toBe(true);
        expect(form.canSubmit()).toBe(true);
      });
    });
  });

  describe('createCrudContract', () => {
    test('应该创建有效的契约接口', async () => {
      const { createCrudContract } = await import('../../../slices/mvp_crud/hooks');
      
      const contract = createCrudContract();
      
      expect(contract).toBeDefined();
      expect(typeof contract.getItems).toBe('function');
      expect(typeof contract.getItem).toBe('function');
      expect(typeof contract.createItem).toBe('function');
      expect(typeof contract.updateItem).toBe('function');
      expect(typeof contract.deleteItem).toBe('function');
      expect(typeof contract.getTotalCount).toBe('function');
      expect(typeof contract.isLoading).toBe('function');
      expect(typeof contract.getError).toBe('function');
    });

    test('契约方法应该返回正确的类型', async () => {
      const { createCrudContract } = await import('../../../slices/mvp_crud/hooks');
      
      const contract = createCrudContract();
      
      // 测试同步方法
      expect(typeof contract.getTotalCount()).toBe('number');
      expect(typeof contract.isLoading()).toBe('boolean');
      
      // 测试异步方法
      expect(contract.getItems()).toBeInstanceOf(Promise);
      expect(contract.getItem('test-id')).toBeInstanceOf(Promise);
    });
  });

  describe('数据验证', () => {
    test('应该正确验证项目数据', async () => {
      const { useItemForm } = await import('../../../slices/mvp_crud/hooks');
      
      createRoot(() => {
        const form = useItemForm();
        
        // 测试名称验证
        form.updateField('name', '');
        expect(form.errors().name).toBeTruthy();
        
        form.updateField('name', '测试项目');
        expect(form.errors().name).toBeFalsy();
        
        // 测试数值验证
        form.updateField('value', -1);
        expect(form.errors().value).toBeTruthy();
        
        form.updateField('value', 100);
        expect(form.errors().value).toBeFalsy();
      });
    });

    test('应该处理边界值', async () => {
      const { useItemForm } = await import('../../../slices/mvp_crud/hooks');
      
      createRoot(() => {
        const form = useItemForm();
        
        // 测试最大长度
        const longName = 'a'.repeat(101);
        form.updateField('name', longName);
        expect(form.errors().name).toBeTruthy();
        
        // 测试最大值
        form.updateField('value', 1000000);
        expect(form.errors().value).toBeTruthy();
      });
    });
  });

  describe('错误处理', () => {
    test('表单应该处理提交错误', async () => {
      const { useItemForm } = await import('../../../slices/mvp_crud/hooks');
      
      createRoot(async () => {
        const form = useItemForm();
        
        form.updateField('name', '测试项目');
        
        const mockSubmit = vi.fn().mockRejectedValue(new Error('提交失败'));
        const result = await form.submit(mockSubmit);
        
        expect(result).toBe(false);
        expect(form.submitting()).toBe(false);
      });
    });

    test('表单应该处理成功提交', async () => {
      const { useItemForm } = await import('../../../slices/mvp_crud/hooks');
      
      createRoot(async () => {
        const form = useItemForm();
        
        form.updateField('name', '测试项目');
        
        const mockSubmit = vi.fn().mockResolvedValue(undefined);
        const result = await form.submit(mockSubmit);
        
        expect(result).toBe(true);
        expect(form.formData.name).toBe(''); // 应该重置
      });
    });
  });

  describe('性能和稳定性', () => {
    test('多个表单实例应该独立工作', async () => {
      const { useItemForm } = await import('../../../slices/mvp_crud/hooks');
      
      createRoot(() => {
        const form1 = useItemForm();
        const form2 = useItemForm();
        
        form1.updateField('name', '项目1');
        form2.updateField('name', '项目2');
        
        expect(form1.formData.name).toBe('项目1');
        expect(form2.formData.name).toBe('项目2');
      });
    });

    test('表单应该正确处理大量数据', async () => {
      const { useItemForm } = await import('../../../slices/mvp_crud/hooks');
      
      createRoot(() => {
        const form = useItemForm();
        
        // 模拟大量字段更新
        for (let i = 0; i < 100; i++) {
          form.updateField('name', `项目${i}`);
        }
        
        expect(form.formData.name).toBe('项目99');
        expect(form.isValid()).toBe(true);
      });
    });
  });
}); 