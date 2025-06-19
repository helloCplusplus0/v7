// slices/mvp_crud/types_test.ts - MVP CRUD 类型验证单元测试
import { describe, test, expect } from 'vitest';
import type {
  Item,
  CreateItemRequest,
  UpdateItemRequest,
  ListItemsQuery,
  CrudState,
  ItemFormData,
  CrudError,
  ValidationResult,
  SortField,
  CrudOperation
} from './types';

describe('MVP CRUD Types', () => {
  describe('Item Interface', () => {
    test('应该有正确的必需字段', () => {
      const validItem: Item = {
        id: '123',
        name: 'Test Item',
        description: 'Test description',
        value: 100,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z'
      };

      expect(validItem.id).toBeDefined();
      expect(validItem.name).toBeDefined();
      expect(validItem.value).toBeDefined();
      expect(validItem.created_at).toBeDefined();
      expect(validItem.updated_at).toBeDefined();
    });

    test('description 字段应该是可选的', () => {
      const itemWithoutDescription: Item = {
        id: '123',
        name: 'Test Item',
        value: 100,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z'
      };

      expect(itemWithoutDescription).toBeDefined();
    });
  });

  describe('CreateItemRequest Interface', () => {
    test('应该包含必需的创建字段', () => {
      const createRequest: CreateItemRequest = {
        name: 'New Item',
        description: 'New description',
        value: 200
      };

      expect(createRequest.name).toBeDefined();
      expect(createRequest.value).toBeDefined();
    });

    test('description 字段应该是可选的', () => {
      const minimalRequest: CreateItemRequest = {
        name: 'Minimal Item',
        value: 50
      };

      expect(minimalRequest).toBeDefined();
      expect(minimalRequest.description).toBeUndefined();
    });
  });

  describe('UpdateItemRequest Interface', () => {
    test('所有字段都应该是可选的', () => {
      const updateRequest: UpdateItemRequest = {};
      expect(updateRequest).toBeDefined();

      const partialUpdate: UpdateItemRequest = {
        name: 'Updated Name'
      };
      expect(partialUpdate.name).toBe('Updated Name');

      const fullUpdate: UpdateItemRequest = {
        name: 'Full Update',
        description: 'Updated description',
        value: 300
      };
      expect(fullUpdate.name).toBe('Full Update');
      expect(fullUpdate.description).toBe('Updated description');
      expect(fullUpdate.value).toBe(300);
    });
  });

  describe('ListItemsQuery Interface', () => {
    test('应该支持分页和排序参数', () => {
      const query: ListItemsQuery = {
        limit: 10,
        offset: 0,
        sort_by: 'created_at',
        order: 'desc'
      };

      expect(query.limit).toBe(10);
      expect(query.offset).toBe(0);
      expect(query.sort_by).toBe('created_at');
      expect(query.order).toBe('desc');
    });

    test('所有字段都应该是可选的', () => {
      const emptyQuery: ListItemsQuery = {};
      expect(emptyQuery).toBeDefined();
    });

    test('order 字段应该只接受 asc 或 desc', () => {
      const ascQuery: ListItemsQuery = { order: 'asc' };
      const descQuery: ListItemsQuery = { order: 'desc' };
      
      expect(ascQuery.order).toBe('asc');
      expect(descQuery.order).toBe('desc');
    });
  });

  describe('CrudState Interface', () => {
    test('应该包含完整的状态字段', () => {
      const initialState: CrudState = {
        items: [],
        currentItem: null,
        loading: false,
        error: null,
        total: 0,
        currentPage: 1,
        pageSize: 10,
        sortBy: 'created_at',
        sortOrder: 'desc'
      };

      expect(Array.isArray(initialState.items)).toBe(true);
      expect(initialState.currentItem).toBeNull();
      expect(initialState.loading).toBe(false);
      expect(initialState.error).toBeNull();
      expect(initialState.total).toBe(0);
      expect(initialState.currentPage).toBe(1);
      expect(initialState.pageSize).toBe(10);
      expect(initialState.sortBy).toBe('created_at');
      expect(initialState.sortOrder).toBe('desc');
    });

    test('应该支持设置当前项目', () => {
      const item: Item = {
        id: '123',
        name: 'Test Item',
        value: 100,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z'
      };

      const stateWithItem: CrudState = {
        items: [item],
        currentItem: item,
        loading: false,
        error: null,
        total: 1,
        currentPage: 1,
        pageSize: 10,
        sortBy: 'created_at',
        sortOrder: 'desc'
      };

      expect(stateWithItem.currentItem).toEqual(item);
      expect(stateWithItem.items).toContain(item);
    });
  });

  describe('ItemFormData Interface', () => {
    test('应该包含表单必需字段', () => {
      const formData: ItemFormData = {
        name: 'Form Item',
        description: 'Form description',
        value: 150
      };

      expect(formData.name).toBe('Form Item');
      expect(formData.description).toBe('Form description');
      expect(formData.value).toBe(150);
    });
  });

  describe('CrudError Interface', () => {
    test('应该支持不同的错误类型', () => {
      const validationError: CrudError = {
        type: 'validation',
        message: 'Name is required',
        field: 'name'
      };

      const networkError: CrudError = {
        type: 'network',
        message: 'Network connection failed'
      };

      const serverError: CrudError = {
        type: 'server',
        message: 'Internal server error'
      };

      expect(validationError.type).toBe('validation');
      expect(validationError.field).toBe('name');
      expect(networkError.type).toBe('network');
      expect(networkError.field).toBeUndefined();
      expect(serverError.type).toBe('server');
    });
  });

  describe('ValidationResult Interface', () => {
    test('应该包含验证状态和错误信息', () => {
      const validResult: ValidationResult = {
        isValid: true,
        errors: {}
      };

      const invalidResult: ValidationResult = {
        isValid: false,
        errors: {
          name: 'Name is required',
          value: 'Value must be positive'
        }
      };

      expect(validResult.isValid).toBe(true);
      expect(Object.keys(validResult.errors)).toHaveLength(0);
      expect(invalidResult.isValid).toBe(false);
      expect(invalidResult.errors['name']).toBe('Name is required');
      expect(invalidResult.errors['value']).toBe('Value must be positive');
    });
  });

  describe('Type Unions', () => {
    test('SortField 应该包含正确的字段选项', () => {
      const validSortFields: SortField[] = ['name', 'value', 'created_at', 'updated_at'];
      
      validSortFields.forEach(field => {
        expect(['name', 'value', 'created_at', 'updated_at']).toContain(field);
      });
    });

    test('CrudOperation 应该包含所有CRUD操作', () => {
      const validOperations: CrudOperation[] = ['create', 'read', 'update', 'delete', 'list'];
      
      validOperations.forEach(operation => {
        expect(['create', 'read', 'update', 'delete', 'list']).toContain(operation);
      });
    });
  });

  describe('Type Compatibility', () => {
    test('CreateItemRequest 应该与 ItemFormData 兼容', () => {
      const formData: ItemFormData = {
        name: 'Test Item',
        description: 'Test description',
        value: 100
      };

      const createRequest: CreateItemRequest = {
        name: formData.name,
        description: formData.description,
        value: formData.value
      };

      expect(createRequest.name).toBe(formData.name);
      expect(createRequest.description).toBe(formData.description);
      expect(createRequest.value).toBe(formData.value);
    });

    test('Item 应该包含 CreateItemRequest 的所有字段', () => {
      const createRequest: CreateItemRequest = {
        name: 'New Item',
        description: 'New description',
        value: 200
      };

      const item: Item = {
        id: '123',
        name: createRequest.name,
        value: createRequest.value,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        ...(createRequest.description && { description: createRequest.description })
      };

      expect(item.name).toBe(createRequest.name);
      if (createRequest.description) {
        expect(item.description).toBe(createRequest.description);
      }
      expect(item.value).toBe(createRequest.value);
    });
  });
}); 