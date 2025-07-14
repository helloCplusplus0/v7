// 🧪 MVP CRUD API 单元测试 - 简化版本
// 专注核心CRUD功能测试，避免复杂的mock设置

import { describe, test, expect, beforeEach, vi } from 'vitest';
import { CrudApiClient } from '../../../slices/mvp_crud/api';
import { createMockItem, createMockCreateRequest } from './test-utils';

// Mock grpc client
vi.mock('../../../shared/api', () => ({
  grpcClient: {
    createItem: vi.fn(),
    getItem: vi.fn(),
    updateItem: vi.fn(),
    deleteItem: vi.fn(),
    listItems: vi.fn(),
    healthCheck: vi.fn()
  }
}));

describe('CrudApiClient - 核心功能测试', () => {
  let apiClient: CrudApiClient;
  let mockGrpcClient: any;

  beforeEach(async () => {
    vi.clearAllMocks();
    const { grpcClient } = await import('../../../shared/api');
    mockGrpcClient = grpcClient;
    apiClient = new CrudApiClient();
  });

  describe('基础功能', () => {
    test('应该正确初始化', () => {
      expect(apiClient).toBeInstanceOf(CrudApiClient);
    });

    test('应该有所有必需的方法', () => {
      expect(typeof apiClient.createItem).toBe('function');
      expect(typeof apiClient.getItem).toBe('function');
      expect(typeof apiClient.updateItem).toBe('function');
      expect(typeof apiClient.deleteItem).toBe('function');
      expect(typeof apiClient.listItems).toBe('function');
      expect(typeof apiClient.healthCheck).toBe('function');
    });
  });

  describe('创建项目', () => {
    test('应该成功创建项目', async () => {
      const mockRequest = createMockCreateRequest();
      const mockResponse = createMockItem();
      
      mockGrpcClient.createItem.mockResolvedValue({
        success: true,
        data: { item: mockResponse }
      });

      const result = await apiClient.createItem(mockRequest);
      
      expect(mockGrpcClient.createItem).toHaveBeenCalledWith(mockRequest);
      expect(result).toEqual(mockResponse);
    });

    test('应该处理创建失败', async () => {
      const mockRequest = createMockCreateRequest();
      
      mockGrpcClient.createItem.mockRejectedValue(new Error('创建失败'));

      await expect(apiClient.createItem(mockRequest)).rejects.toThrow('创建失败');
    });
  });

  describe('获取项目', () => {
    test('应该成功获取项目', async () => {
      const mockId = 'test-id';
      const mockResponse = createMockItem({ id: mockId });
      
      mockGrpcClient.getItem.mockResolvedValue({
        success: true,
        data: { item: mockResponse }
      });

      const result = await apiClient.getItem(mockId);
      
             expect(mockGrpcClient.getItem).toHaveBeenCalledWith({ id: mockId });
      expect(result).toEqual(mockResponse);
    });

    test('应该处理获取失败', async () => {
      const mockId = 'test-id';
      
      mockGrpcClient.getItem.mockRejectedValue(new Error('项目不存在'));

      await expect(apiClient.getItem(mockId)).rejects.toThrow('项目不存在');
    });
  });

  describe('更新项目', () => {
    test('应该成功更新项目', async () => {
      const mockId = 'test-id';
      const mockData = { name: '更新后的名称' };
      const mockResponse = createMockItem({ id: mockId, ...mockData });
      
      mockGrpcClient.updateItem.mockResolvedValue({
        success: true,
        data: { item: mockResponse }
      });

      const result = await apiClient.updateItem(mockId, mockData);
      
             expect(mockGrpcClient.updateItem).toHaveBeenCalledWith({
         id: mockId,
         ...mockData
       });
      expect(result).toEqual(mockResponse);
    });

    test('应该处理更新失败', async () => {
      const mockId = 'test-id';
      const mockData = { name: '更新后的名称' };
      
      mockGrpcClient.updateItem.mockRejectedValue(new Error('更新失败'));

      await expect(apiClient.updateItem(mockId, mockData)).rejects.toThrow('更新失败');
    });
  });

  describe('删除项目', () => {
    test('应该成功删除项目', async () => {
      const mockId = 'test-id';
      
      mockGrpcClient.deleteItem.mockResolvedValue({
        success: true,
        data: {}
      });

      await apiClient.deleteItem(mockId);
      
             expect(mockGrpcClient.deleteItem).toHaveBeenCalledWith({ id: mockId });
    });

    test('应该处理删除失败', async () => {
      const mockId = 'test-id';
      
      mockGrpcClient.deleteItem.mockRejectedValue(new Error('删除失败'));

      await expect(apiClient.deleteItem(mockId)).rejects.toThrow('删除失败');
    });
  });

  describe('列出项目', () => {
    test('应该成功列出项目', async () => {
      const mockItems = [createMockItem(), createMockItem()];
      const mockResponse = {
        items: mockItems,
        total: mockItems.length
      };
      
      mockGrpcClient.listItems.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await apiClient.listItems();
      
      expect(mockGrpcClient.listItems).toHaveBeenCalled();
      expect(result).toEqual(mockResponse);
    });

         test('应该支持查询参数', async () => {
       const limit = 10;
       const offset = 0;
       const search = '测试';
       
       const mockResponse = {
         items: [],
         total: 0
       };
       
       mockGrpcClient.listItems.mockResolvedValue({
         success: true,
         data: mockResponse
       });

       const result = await apiClient.listItems(limit, offset, search);
       
       expect(mockGrpcClient.listItems).toHaveBeenCalledWith({
         limit,
         offset,
         search
       });
       expect(result).toEqual(mockResponse);
     });

    test('应该处理列表失败', async () => {
      mockGrpcClient.listItems.mockRejectedValue(new Error('获取列表失败'));

      await expect(apiClient.listItems()).rejects.toThrow('获取列表失败');
    });
  });

  describe('健康检查', () => {
         test('应该成功执行健康检查', async () => {
       const mockResponse = { status: 'healthy' };
       
       mockGrpcClient.healthCheck.mockResolvedValue({
         success: true,
         data: mockResponse
       });

       const result = await apiClient.healthCheck();
       
       expect(mockGrpcClient.healthCheck).toHaveBeenCalled();
       expect(result).toBe(true);
     });

         test('应该处理健康检查失败', async () => {
       mockGrpcClient.healthCheck.mockRejectedValue(new Error('服务不可用'));

       const result = await apiClient.healthCheck();
       expect(result).toBe(false);
     });
  });

  describe('批量操作', () => {
    test('应该支持批量删除', async () => {
      const mockIds = ['id1', 'id2', 'id3'];
      
      mockGrpcClient.deleteItem.mockResolvedValue({
        success: true,
        data: {}
      });

      await apiClient.batchDeleteItems(mockIds);
      
      expect(mockGrpcClient.deleteItem).toHaveBeenCalledTimes(mockIds.length);
             mockIds.forEach(id => {
         expect(mockGrpcClient.deleteItem).toHaveBeenCalledWith({ id });
       });
    });

         test('应该处理批量删除失败', async () => {
       const mockIds = ['id1', 'id2'];
       
       mockGrpcClient.deleteItem.mockRejectedValue(new Error('删除失败'));

       const result = await apiClient.batchDeleteItems(mockIds);
       
       expect(result.success).toBe(0);
       expect(result.failed).toBe(2);
       expect(result.errors).toHaveLength(2);
     });
  });

  describe('错误处理', () => {
    test('应该正确处理网络错误', async () => {
      mockGrpcClient.listItems.mockRejectedValue(new Error('Network error'));

      await expect(apiClient.listItems()).rejects.toThrow('Network error');
    });

    test('应该正确处理服务器错误', async () => {
      mockGrpcClient.createItem.mockRejectedValue(new Error('Server error'));

      await expect(apiClient.createItem(createMockCreateRequest())).rejects.toThrow('Server error');
    });
  });

  describe('参数验证', () => {
    test('创建项目时应该验证必需参数', async () => {
      const invalidRequest = {} as any;
      
      await expect(apiClient.createItem(invalidRequest)).rejects.toThrow();
    });

    test('获取项目时应该验证ID', async () => {
      await expect(apiClient.getItem('')).rejects.toThrow();
    });

    test('更新项目时应该验证ID和数据', async () => {
      await expect(apiClient.updateItem('', {})).rejects.toThrow();
    });

    test('删除项目时应该验证ID', async () => {
      await expect(apiClient.deleteItem('')).rejects.toThrow();
    });
  });

  describe('兼容性方法', () => {
         test('应该支持 create 方法', async () => {
       const mockRequest = createMockCreateRequest();
       const mockResponse = createMockItem();
       
       mockGrpcClient.createItem.mockResolvedValue({
         success: true,
         data: { item: mockResponse }
       });

       const result = await apiClient.create(mockRequest);
       
       expect(result).toEqual({
         success: true,
         data: mockResponse
       });
     });

         test('应该支持 get 方法', async () => {
       const mockId = 'test-id';
       const mockResponse = createMockItem({ id: mockId });
       
       mockGrpcClient.getItem.mockResolvedValue({
         success: true,
         data: { item: mockResponse }
       });

       const result = await apiClient.get(mockId);
       
       expect(result).toEqual({
         success: true,
         data: mockResponse
       });
     });

         test('应该支持 update 方法', async () => {
       const mockId = 'test-id';
       const mockData = { name: '更新名称' };
       const mockResponse = createMockItem({ id: mockId, ...mockData });
       
       mockGrpcClient.updateItem.mockResolvedValue({
         success: true,
         data: { item: mockResponse }
       });

       const result = await apiClient.update(mockId, mockData);
       
       expect(result).toEqual({
         success: true,
         data: mockResponse
       });
     });

         test('应该支持 delete 方法', async () => {
       const mockId = 'test-id';
       
       mockGrpcClient.deleteItem.mockResolvedValue({
         success: true,
         data: {}
       });

       const result = await apiClient.delete(mockId);
       
       expect(mockGrpcClient.deleteItem).toHaveBeenCalledWith({ id: mockId });
       expect(result).toEqual({
         success: true
       });
     });

         test('应该支持 list 方法', async () => {
       const mockResponse = {
         items: [createMockItem()],
         total: 1
       };
       
       mockGrpcClient.listItems.mockResolvedValue({
         success: true,
         data: mockResponse
       });

       const result = await apiClient.list();
       
       expect(result).toEqual({
         success: true,
         data: mockResponse.items,
         total: mockResponse.total
       });
     });
  });
}); 