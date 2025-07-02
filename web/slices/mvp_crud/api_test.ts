// slices/mvp_crud/api_test.ts - MVP CRUD API客户端单元测试
import { describe, test, expect, beforeEach, afterEach, vi } from 'vitest';
import { crudApi } from './api';
import type {
  CreateItemRequest,
  UpdateItemRequest,
  ListItemsQuery
} from './types';

// Mock BaseApiClient
vi.mock('../../shared/api/base', () => ({
  BaseApiClient: class MockBaseApiClient {
    async get(url: string) {
      return { url, method: 'GET' };
    }
    async post(url: string, data?: any) {
      return { url, method: 'POST', data };
    }
    async put(url: string, data?: any) {
      return { url, method: 'PUT', data };
    }
    async delete(url: string) {
      return { url, method: 'DELETE' };
    }
  }
}));

describe('CrudApiClient', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('createItem', () => {
    test('应该调用正确的POST端点', async () => {
      const createData: CreateItemRequest = {
        name: 'Test Item',
        description: 'Test description',
        value: 100
      };

      const result = await crudApi.createItem(createData);

      expect(result).toEqual({
        url: '/items',
        method: 'POST',
        data: createData
      });
    });

    test('应该处理没有description的请求', async () => {
      const createData: CreateItemRequest = {
        name: 'Minimal Item',
        value: 50
      };

      const result = await crudApi.createItem(createData);

      expect(result).toEqual({
        url: '/items',
        method: 'POST',
        data: createData
      });
    });
  });

  describe('listItems', () => {
    test('应该在没有查询参数时调用基础端点', async () => {
      const result = await crudApi.listItems();

      expect(result).toEqual({
        url: '/items',
        method: 'GET'
      });
    });

    test('应该正确构建查询参数', async () => {
      const query: ListItemsQuery = {
        limit: 10,
        offset: 20,
        sort_by: 'name',
        order: 'asc'
      };

      const result = await crudApi.listItems(query);

      expect(result).toEqual({
        url: '/items?limit=10&offset=20&sort_by=name&order=asc',
        method: 'GET'
      });
    });

    test('应该只包含提供的查询参数', async () => {
      const query: ListItemsQuery = {
        limit: 5,
        sort_by: 'created_at'
      };

      const result = await crudApi.listItems(query);

      expect(result).toEqual({
        url: '/items?limit=5&sort_by=created_at',
        method: 'GET'
      });
    });

    test('应该处理空查询对象', async () => {
      const result = await crudApi.listItems({});

      expect(result).toEqual({
        url: '/items',
        method: 'GET'
      });
    });
  });

  describe('getItem', () => {
    test('应该调用正确的GET端点', async () => {
      const itemId = '123';

      const result = await crudApi.getItem(itemId);

      expect(result).toEqual({
        url: '/items/123',
        method: 'GET'
      });
    });
  });

  describe('updateItem', () => {
    test('应该调用正确的PUT端点', async () => {
      const itemId = '123';
      const updateData: UpdateItemRequest = {
        name: 'Updated Item',
        value: 200
      };

      const result = await crudApi.updateItem(itemId, updateData);

      expect(result).toEqual({
        url: '/items/123',
        method: 'PUT',
        data: updateData
      });
    });

    test('应该处理部分更新', async () => {
      const itemId = '123';
      const updateData: UpdateItemRequest = {
        name: 'Only Name Updated'
      };

      const result = await crudApi.updateItem(itemId, updateData);

      expect(result).toEqual({
        url: '/items/123',
        method: 'PUT',
        data: updateData
      });
    });

    test('应该处理空更新对象', async () => {
      const itemId = '123';
      const updateData: UpdateItemRequest = {};

      const result = await crudApi.updateItem(itemId, updateData);

      expect(result).toEqual({
        url: '/items/123',
        method: 'PUT',
        data: updateData
      });
    });
  });

  describe('deleteItem', () => {
    test('应该调用正确的DELETE端点', async () => {
      const itemId = '123';

      const result = await crudApi.deleteItem(itemId);

      expect(result).toEqual({
        url: '/items/123',
        method: 'DELETE'
      });
    });
  });

  describe('deleteItems', () => {
    test('应该调用批量删除端点', async () => {
      const ids = ['123', '456', '789'];

      const result = await crudApi.deleteItems(ids);

      expect(result).toEqual({
        url: '/items/batch-delete',
        method: 'POST',
        data: { ids }
      });
    });

    test('应该处理空ID数组', async () => {
      const ids: string[] = [];

      const result = await crudApi.deleteItems(ids);

      expect(result).toEqual({
        url: '/items/batch-delete',
        method: 'POST',
        data: { ids: [] }
      });
    });
  });

  describe('checkNameExists', () => {
    test('应该检查名称是否存在', async () => {
      const name = 'Test Item';

      const result = await crudApi.checkNameExists(name);

      expect(result).toEqual({
        url: '/items/check-name?name=Test+Item',
        method: 'GET'
      });
    });

    test('应该支持排除特定ID', async () => {
      const name = 'Test Item';
      const excludeId = '123';

      const result = await crudApi.checkNameExists(name, excludeId);

      expect(result).toEqual({
        url: '/items/check-name?name=Test+Item&exclude_id=123',
        method: 'GET'
      });
    });

    test('应该正确编码URL参数', async () => {
      const name = 'Test Item & Special Characters!';

      const result = await crudApi.checkNameExists(name);

      expect(result).toEqual({
        url: '/items/check-name?name=Test+Item+%26+Special+Characters%21',
        method: 'GET'
      });
    });
  });

  describe('URL构建', () => {
    test('应该正确处理特殊字符在ID中', async () => {
      const specialId = 'item-123_test';

      const result = await crudApi.getItem(specialId);

      expect(result).toEqual({
        url: '/items/item-123_test',
        method: 'GET'
      });
    });

    test('应该正确处理数字类型的查询参数', async () => {
      const query: ListItemsQuery = {
        limit: 0,
        offset: 0
      };

      const result = await crudApi.listItems(query);

      expect(result).toEqual({
        url: '/items?limit=0&offset=0',
        method: 'GET'
      });
    });
  });

  describe('类型安全性', () => {
    test('createItem应该只接受CreateItemRequest类型', () => {
      const validData: CreateItemRequest = {
        name: 'Valid Item',
        value: 100
      };

      // 这应该编译通过
      expect(() => crudApi.createItem(validData)).not.toThrow();
    });

    test('updateItem应该只接受UpdateItemRequest类型', () => {
      const validData: UpdateItemRequest = {
        name: 'Updated Name'
      };

      // 这应该编译通过
      expect(() => crudApi.updateItem('123', validData)).not.toThrow();
    });

    test('listItems应该只接受ListItemsQuery类型', () => {
      const validQuery: ListItemsQuery = {
        limit: 10,
        order: 'desc'
      };

      // 这应该编译通过
      expect(() => crudApi.listItems(validQuery)).not.toThrow();
    });
  });
}); 