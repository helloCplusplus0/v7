// 🧪 MVP CRUD 类型定义单元测试
// 测试类型守卫函数、验证逻辑和常量定义

import { describe, test, expect } from 'vitest';
import {
  isValidItem,
  isValidCreateRequest,
  DEFAULT_PAGE_SIZE,
  DEFAULT_SORT_FIELD,
  DEFAULT_SORT_ORDER,
  ITEM_NAME_MAX_LENGTH,
  ITEM_DESCRIPTION_MAX_LENGTH,
  ITEM_VALUE_MIN,
  ITEM_VALUE_MAX
} from '../../../slices/mvp_crud/types';
import type {
  Item,
  CreateItemRequest,
  UpdateItemRequest,
  SortField,
  SortOrder,
  CrudOperation,
  OperationStatus
} from '../../../slices/mvp_crud/types';
import {
  createMockItem,
  createMockCreateRequest,
  TEST_CONSTANTS
} from './test-utils';

describe('MVP CRUD Types', () => {
  describe('常量定义', () => {
    test('应该有正确的默认值', () => {
      expect(DEFAULT_PAGE_SIZE).toBe(10);
      expect(DEFAULT_SORT_FIELD).toBe('createdAt');
      expect(DEFAULT_SORT_ORDER).toBe('desc');
      
      expect(ITEM_NAME_MAX_LENGTH).toBe(100);
      expect(ITEM_DESCRIPTION_MAX_LENGTH).toBe(500);
      expect(ITEM_VALUE_MIN).toBe(0);
      expect(ITEM_VALUE_MAX).toBe(999999);
    });

    test('常量应该是合理的数值', () => {
      expect(DEFAULT_PAGE_SIZE).toBeGreaterThan(0);
      expect(DEFAULT_PAGE_SIZE).toBeLessThanOrEqual(TEST_CONSTANTS.MAX_ITEMS_PER_PAGE);
      
      expect(ITEM_NAME_MAX_LENGTH).toBeGreaterThan(0);
      expect(ITEM_DESCRIPTION_MAX_LENGTH).toBeGreaterThan(ITEM_NAME_MAX_LENGTH);
      
      expect(ITEM_VALUE_MIN).toBeGreaterThanOrEqual(0);
      expect(ITEM_VALUE_MAX).toBeGreaterThan(ITEM_VALUE_MIN);
    });
  });

  describe('isValidItem类型守卫', () => {
    test('应该验证有效的项目对象', () => {
      const validItem = createMockItem();
      expect(isValidItem(validItem)).toBe(true);
    });

    test('应该验证完整的项目对象', () => {
      const completeItem: Item = {
        id: 'test-id',
        name: '测试项目',
        description: '测试描述',
        value: 100,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      };
      expect(isValidItem(completeItem)).toBe(true);
    });

    test('应该验证最小项目对象', () => {
      const minimalItem: Item = {
        id: 'test-id',
        name: '测试项目',
        value: 0,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      };
      expect(isValidItem(minimalItem)).toBe(true);
    });

    test('应该拒绝null和undefined', () => {
      expect(isValidItem(null)).toBe(false);
      expect(isValidItem(undefined)).toBe(false);
    });

    test('应该拒绝非对象类型', () => {
      expect(isValidItem('string')).toBe(false);
      expect(isValidItem(123)).toBe(false);
      expect(isValidItem(true)).toBe(false);
      expect(isValidItem([])).toBe(false);
    });

    test('应该拒绝缺少必需字段的对象', () => {
      expect(isValidItem({})).toBe(false);
      
      expect(isValidItem({
        name: '测试项目',
        value: 100,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(false); // 缺少id
      
      expect(isValidItem({
        id: 'test-id',
        value: 100,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(false); // 缺少name
      
      expect(isValidItem({
        id: 'test-id',
        name: '测试项目',
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(false); // 缺少value
      
      expect(isValidItem({
        id: 'test-id',
        name: '测试项目',
        value: 100,
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(false); // 缺少createdAt
      
      expect(isValidItem({
        id: 'test-id',
        name: '测试项目',
        value: 100,
        createdAt: '2024-01-01T00:00:00Z'
      })).toBe(false); // 缺少updatedAt
    });

    test('应该拒绝错误类型的字段', () => {
      expect(isValidItem({
        id: 123, // 应该是string
        name: '测试项目',
        value: 100,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(false);
      
      expect(isValidItem({
        id: 'test-id',
        name: 123, // 应该是string
        value: 100,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(false);
      
      expect(isValidItem({
        id: 'test-id',
        name: '测试项目',
        value: '100', // 应该是number
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(false);
      
      expect(isValidItem({
        id: 'test-id',
        name: '测试项目',
        value: 100,
        createdAt: 123, // 应该是string
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(false);
      
      expect(isValidItem({
        id: 'test-id',
        name: '测试项目',
        value: 100,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: 123 // 应该是string
      })).toBe(false);
    });

    test('应该处理边界情况', () => {
      // 空字符串ID（无效）
      expect(isValidItem({
        id: '',
        name: '测试项目',
        value: 100,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(false);
      
      // 空字符串名称（无效）
      expect(isValidItem({
        id: 'test-id',
        name: '',
        value: 100,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(false);
      
      // 负数值（有效，类型检查通过）
      expect(isValidItem({
        id: 'test-id',
        name: '测试项目',
        value: -1,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(true);
      
      // 很大的数值（有效）
      expect(isValidItem({
        id: 'test-id',
        name: '测试项目',
        value: Number.MAX_SAFE_INTEGER,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(true);
    });

    test('应该处理可选字段', () => {
      // description是可选的
      expect(isValidItem({
        id: 'test-id',
        name: '测试项目',
        description: undefined,
        value: 100,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(true);
      
      // 但如果提供了description，必须是string
      expect(isValidItem({
        id: 'test-id',
        name: '测试项目',
        description: 123,
        value: 100,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      })).toBe(false);
    });
  });

  describe('isValidCreateRequest类型守卫', () => {
    test('应该验证有效的创建请求', () => {
      const validRequest = createMockCreateRequest();
      expect(isValidCreateRequest(validRequest)).toBe(true);
    });

    test('应该验证最小创建请求', () => {
      const minimalRequest: CreateItemRequest = {
        name: '测试项目'
      };
      expect(isValidCreateRequest(minimalRequest)).toBe(true);
    });

    test('应该验证完整创建请求', () => {
      const completeRequest: CreateItemRequest = {
        name: '测试项目',
        description: '测试描述',
        value: 100
      };
      expect(isValidCreateRequest(completeRequest)).toBe(true);
    });

    test('应该拒绝null和undefined', () => {
      expect(isValidCreateRequest(null)).toBe(false);
      expect(isValidCreateRequest(undefined)).toBe(false);
    });

    test('应该拒绝非对象类型', () => {
      expect(isValidCreateRequest('string')).toBe(false);
      expect(isValidCreateRequest(123)).toBe(false);
      expect(isValidCreateRequest(true)).toBe(false);
      expect(isValidCreateRequest([])).toBe(false);
    });

    test('应该拒绝缺少name字段的对象', () => {
      expect(isValidCreateRequest({})).toBe(false);
      
      expect(isValidCreateRequest({
        description: '测试描述',
        value: 100
      })).toBe(false);
    });

    test('应该拒绝错误类型的name字段', () => {
      expect(isValidCreateRequest({
        name: 123
      })).toBe(false);
      
      expect(isValidCreateRequest({
        name: null
      })).toBe(false);
      
      expect(isValidCreateRequest({
        name: undefined
      })).toBe(false);
    });

    test('应该拒绝空字符串name', () => {
      expect(isValidCreateRequest({
        name: ''
      })).toBe(false);
      
      expect(isValidCreateRequest({
        name: '   ' // 仅空格
      })).toBe(false);
    });

    test('应该接受有效的name字段', () => {
      expect(isValidCreateRequest({
        name: 'a' // 最短有效名称
      })).toBe(true);
      
      expect(isValidCreateRequest({
        name: '测试项目名称'
      })).toBe(true);
      
      expect(isValidCreateRequest({
        name: 'Project Name with Spaces'
      })).toBe(true);
      
      expect(isValidCreateRequest({
        name: '🚀 项目名称 ✨'
      })).toBe(true);
    });

    test('应该处理可选字段', () => {
      // description是可选的
      expect(isValidCreateRequest({
        name: '测试项目',
        description: undefined
      })).toBe(true);
      
      expect(isValidCreateRequest({
        name: '测试项目',
        description: ''
      })).toBe(true);
      
      expect(isValidCreateRequest({
        name: '测试项目',
        description: '描述'
      })).toBe(true);
      
      // value是可选的
      expect(isValidCreateRequest({
        name: '测试项目',
        value: undefined
      })).toBe(true);
      
      expect(isValidCreateRequest({
        name: '测试项目',
        value: 0
      })).toBe(true);
      
      expect(isValidCreateRequest({
        name: '测试项目',
        value: 100
      })).toBe(true);
    });

    test('应该处理边界情况', () => {
      // 极长的名称（类型检查通过，业务验证另行处理）
      expect(isValidCreateRequest({
        name: 'A'.repeat(1000)
      })).toBe(true);
      
      // 特殊字符
      expect(isValidCreateRequest({
        name: '!@#$%^&*()_+{}|:"<>?[]\\;\',./'
      })).toBe(true);
      
      // Unicode字符
      expect(isValidCreateRequest({
        name: '测试 🚀 ✨ العربية 日本語 한국어'
      })).toBe(true);
    });
  });

  describe('类型联合和枚举', () => {
    test('SortField应该包含有效的排序字段', () => {
      const validSortFields: SortField[] = ['name', 'value', 'createdAt', 'updatedAt'];
      
      validSortFields.forEach(field => {
        expect(['name', 'value', 'createdAt', 'updatedAt']).toContain(field);
      });
    });

    test('SortOrder应该包含有效的排序方向', () => {
      const validSortOrders: SortOrder[] = ['asc', 'desc'];
      
      validSortOrders.forEach(order => {
        expect(['asc', 'desc']).toContain(order);
      });
    });

    test('CrudOperation应该包含有效的操作类型', () => {
      const validOperations: CrudOperation[] = ['create', 'read', 'update', 'delete', 'list'];
      
      validOperations.forEach(operation => {
        expect(['create', 'read', 'update', 'delete', 'list']).toContain(operation);
      });
    });

    test('OperationStatus应该包含有效的状态', () => {
      const validStatuses: OperationStatus[] = ['idle', 'pending', 'success', 'error'];
      
      validStatuses.forEach(status => {
        expect(['idle', 'pending', 'success', 'error']).toContain(status);
      });
    });
  });

  describe('接口类型结构', () => {
    test('Item接口应该有正确的结构', () => {
      const item: Item = createMockItem();
      
      // 验证必需字段存在
      expect(item).toHaveProperty('id');
      expect(item).toHaveProperty('name');
      expect(item).toHaveProperty('value');
      expect(item).toHaveProperty('createdAt');
      expect(item).toHaveProperty('updatedAt');
      
      // 验证字段类型
      expect(typeof item.id).toBe('string');
      expect(typeof item.name).toBe('string');
      expect(typeof item.value).toBe('number');
      expect(typeof item.createdAt).toBe('string');
      expect(typeof item.updatedAt).toBe('string');
      
      // description是可选的
      if (item.description !== undefined) {
        expect(typeof item.description).toBe('string');
      }
    });

    test('CreateItemRequest接口应该有正确的结构', () => {
      const request: CreateItemRequest = createMockCreateRequest();
      
      // 验证必需字段
      expect(request).toHaveProperty('name');
      expect(typeof request.name).toBe('string');
      
      // 验证可选字段类型
      if (request.description !== undefined) {
        expect(typeof request.description).toBe('string');
      }
      
      if (request.value !== undefined) {
        expect(typeof request.value).toBe('number');
      }
    });

    test('UpdateItemRequest接口应该有正确的结构', () => {
      const request: UpdateItemRequest = {
        name: '更新的名称',
        description: '更新的描述',
        value: 200
      };
      
      // 所有字段都是可选的
      if (request.name !== undefined) {
        expect(typeof request.name).toBe('string');
      }
      
      if (request.description !== undefined) {
        expect(typeof request.description).toBe('string');
      }
      
      if (request.value !== undefined) {
        expect(typeof request.value).toBe('number');
      }
    });
  });

  describe('类型兼容性测试', () => {
    test('CreateItemRequest应该与Item兼容', () => {
      const createRequest: CreateItemRequest = {
        name: '测试项目',
        description: '测试描述',
        value: 100
      };
      
      // 应该能够从CreateItemRequest创建Item（添加必需字段）
      const item: Item = {
        id: 'generated-id',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        name: createRequest.name,
        description: createRequest.description,
        value: createRequest.value ?? 0
      };
      
      expect(isValidItem(item)).toBe(true);
    });

    test('UpdateItemRequest应该与Item兼容', () => {
      const existingItem: Item = createMockItem();
      const updateRequest: UpdateItemRequest = {
        name: '更新的名称',
        value: 200
      };
      
      // 应该能够从UpdateItemRequest更新Item
      const updatedItem: Item = {
        ...existingItem,
        ...updateRequest,
        updatedAt: new Date().toISOString()
      };
      
      expect(isValidItem(updatedItem)).toBe(true);
      expect(updatedItem.name).toBe(updateRequest.name);
      expect(updatedItem.value).toBe(updateRequest.value);
    });

    test('部分更新应该保持数据完整性', () => {
      const existingItem: Item = createMockItem();
      const partialUpdate: UpdateItemRequest = {
        name: '仅更新名称'
      };
      
      const updatedItem: Item = {
        ...existingItem,
        ...partialUpdate,
        updatedAt: new Date().toISOString()
      };
      
      expect(isValidItem(updatedItem)).toBe(true);
      expect(updatedItem.name).toBe(partialUpdate.name);
      expect(updatedItem.description).toBe(existingItem.description);
      expect(updatedItem.value).toBe(existingItem.value);
      expect(updatedItem.id).toBe(existingItem.id);
      expect(updatedItem.createdAt).toBe(existingItem.createdAt);
    });
  });

  describe('性能测试', () => {
    test('类型守卫函数应该高效执行', () => {
      const item = createMockItem();
      const iterations = 10000;
      
      const startTime = performance.now();
      
      for (let i = 0; i < iterations; i++) {
        isValidItem(item);
      }
      
      const endTime = performance.now();
      const executionTime = endTime - startTime;
      
      // 10000次调用应该在合理时间内完成
      expect(executionTime).toBeLessThan(100); // 100ms
    });

    test('类型守卫应该能处理大量无效数据', () => {
      const invalidData = [
        null,
        undefined,
        '',
        123,
        [],
        {},
        { id: 'test' },
        { name: 'test' },
        { invalid: 'data' }
      ];
      
      const startTime = performance.now();
      
      invalidData.forEach(data => {
        expect(isValidItem(data)).toBe(false);
      });
      
      const endTime = performance.now();
      const executionTime = endTime - startTime;
      
      expect(executionTime).toBeLessThan(10); // 10ms
    });
  });
}); 