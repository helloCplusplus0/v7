/**
 * 🚀 MVP CRUD API服务
 * 基于统一的gRPC-Web客户端与Backend gRPC服务直接通信的API层
 */

import { grpcClient } from '../../shared/api';
import type { 
  Item as ProtoItem
} from '../../shared/api';
import type { 
  Item, 
  CreateItemRequest, 
  UpdateItemRequest, 
  GetItemRequest,
  DeleteItemRequest,
  ListItemsRequest,
  CreateItemResponse,
  GetItemResponse,
  UpdateItemResponse,
  DeleteItemResponse,
  ListItemsResponse 
} from './types';

/**
 * MVP CRUD API客户端
 * 使用统一的gRPC-Web客户端进行真实的后端通信
 */
class CrudApiClient {
  constructor() {
    // 使用共享的gRPC-Web客户端，符合v7基础设施复用原则
  }

  /**
   * 创建项目
   * @param data 创建请求数据
   * @returns 创建的项目
   */
  async createItem(data: CreateItemRequest): Promise<Item> {
    try {
      console.log('🚀 [CrudAPI] 调用 createItem:', data);
      
      const response = await grpcClient.createItem({
        name: data.name,
        description: data.description,
        value: data.value || 0
      });

      console.log('📡 [CrudAPI] createItem 响应:', response);

      if (!response.success) {
        throw new Error(response.error || '创建项目失败');
      }

      if (!response.data?.item) {
        throw new Error('服务器返回的项目数据为空');
      }

      // 直接使用proto字段名，无需映射
      const item: Item = {
        id: response.data.item.id || '',
        name: response.data.item.name || '',
        description: response.data.item.description || undefined,
        value: response.data.item.value || 0,
        createdAt: response.data.item.createdAt || '',
        updatedAt: response.data.item.updatedAt || ''
      };

      console.log('✅ [CrudAPI] createItem 成功:', item);
      return item;
    } catch (error) {
      console.error('❌ [CrudAPI] createItem 失败:', error);
      throw new Error(`创建项目失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取项目详情
   * @param id 项目ID
   * @returns 项目详情
   */
  async getItem(id: string): Promise<Item> {
    try {
      console.log('🚀 [CrudAPI] 调用 getItem:', id);
      
      const response = await grpcClient.getItem({ id });
      
      console.log('📡 [CrudAPI] getItem 响应:', response);

      if (!response.success) {
        throw new Error(response.error || '获取项目失败');
      }

      if (!response.data?.item) {
        throw new Error('项目不存在');
      }

      // 直接使用proto字段名，无需映射
      const item: Item = {
        id: response.data.item.id || '',
        name: response.data.item.name || '',
        description: response.data.item.description || undefined,
        value: response.data.item.value || 0,
        createdAt: response.data.item.createdAt || '',
        updatedAt: response.data.item.updatedAt || ''
      };

      console.log('✅ [CrudAPI] getItem 成功:', item);
      return item;
    } catch (error) {
      console.error('❌ [CrudAPI] getItem 失败:', error);
      throw new Error(`获取项目失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 更新项目
   * @param id 项目ID
   * @param data 更新数据
   * @returns 更新后的项目
   */
  async updateItem(id: string, data: UpdateItemRequest): Promise<Item> {
    try {
      console.log('🚀 [CrudAPI] 调用 updateItem:', { id, data });
      
      const response = await grpcClient.updateItem({
        id,
        name: data.name,
        description: data.description,
        value: data.value
      });

      console.log('📡 [CrudAPI] updateItem 响应:', response);

      if (!response.success) {
        throw new Error(response.error || '更新项目失败');
      }

      if (!response.data?.item) {
        throw new Error('服务器返回的项目数据为空');
      }

      // 直接使用proto字段名，无需映射
      const item: Item = {
        id: response.data.item.id || '',
        name: response.data.item.name || '',
        description: response.data.item.description || undefined,
        value: response.data.item.value || 0,
        createdAt: response.data.item.createdAt || '',
        updatedAt: response.data.item.updatedAt || ''
      };

      console.log('✅ [CrudAPI] updateItem 成功:', item);
      return item;
    } catch (error) {
      console.error('❌ [CrudAPI] updateItem 失败:', error);
      throw new Error(`更新项目失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 删除项目
   * @param id 项目ID
   */
  async deleteItem(id: string): Promise<void> {
    try {
      console.log('🚀 [CrudAPI] 调用 deleteItem:', id);
      
      const response = await grpcClient.deleteItem({ id });
      
      console.log('📡 [CrudAPI] deleteItem 响应:', response);

      if (!response.success) {
        throw new Error(response.error || '删除项目失败');
      }

      console.log('✅ [CrudAPI] deleteItem 成功');
    } catch (error) {
      console.error('❌ [CrudAPI] deleteItem 失败:', error);
      throw new Error(`删除项目失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取项目列表
   * @param limit 限制数量
   * @param offset 偏移量
   * @param search 搜索关键词
   * @returns 项目列表和总数
   */
  async listItems(
    limit: number = 10, 
    offset: number = 0, 
    search?: string
  ): Promise<{ items: Item[]; total: number }> {
    try {
      console.log('🚀 [CrudAPI] 调用 listItems:', { limit, offset, search });
      
      const response = await grpcClient.listItems({
        limit,
        offset,
        search
      });

      console.log('📡 [CrudAPI] listItems 响应:', response);

      if (!response.success) {
        throw new Error(response.error || '获取项目列表失败');
      }

      if (!response.data) {
        throw new Error('服务器返回的数据为空');
      }

      // 直接使用proto字段名，无需映射
      const items: Item[] = (response.data.items || []).map((item: ProtoItem) => ({
        id: item.id || '',
        name: item.name || '',
        description: item.description || undefined,
        value: item.value || 0,
        createdAt: item.createdAt || '',
        updatedAt: item.updatedAt || ''
      }));

      const result = {
        items,
        total: response.data.total || 0
      };

      console.log('✅ [CrudAPI] listItems 成功:', result);
      return result;
    } catch (error) {
      console.error('❌ [CrudAPI] listItems 失败:', error);
      throw new Error(`获取项目列表失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 批量删除项目
   * @param ids 项目ID数组
   * @returns 删除结果统计
   */
  async batchDeleteItems(ids: string[]): Promise<{ success: number; failed: number; errors: string[] }> {
    const results = {
      success: 0,
      failed: 0,
      errors: [] as string[]
    };

    for (const id of ids) {
      try {
        await this.deleteItem(id);
        results.success++;
      } catch (error) {
        results.failed++;
        results.errors.push(`删除项目 ${id} 失败: ${error instanceof Error ? error.message : String(error)}`);
      }
    }

    console.log('📊 [CrudAPI] batchDeleteItems 结果:', results);
    return results;
  }

  /**
   * 健康检查 - 验证API连接状态
   */
  async healthCheck(): Promise<boolean> {
    try {
      console.log('🏥 [CrudAPI] 执行健康检查');
      
      const response = await grpcClient.healthCheck();
      
      const isHealthy = response.success && response.data?.status === 'healthy';
      console.log(isHealthy ? '✅ [CrudAPI] 健康检查通过' : '❌ [CrudAPI] 健康检查失败');
      
      return isHealthy;
    } catch (error) {
      console.error('❌ [CrudAPI] 健康检查异常:', error);
      return false;
    }
  }

  // ===== 测试兼容性方法别名 =====

  /**
   * 健康检查 - 测试兼容性别名
   */
  async checkHealth(): Promise<boolean> {
    return this.healthCheck();
  }

  /**
   * 列表查询 - 测试兼容性别名
   */
  async list(options?: { limit?: number; offset?: number; search?: string }) {
    const { limit = 10, offset = 0, search } = options || {};
    const result = await this.listItems(limit, offset, search);
    return {
      success: true,
      data: result.items,
      total: result.total
    };
  }

  /**
   * 创建项目 - 测试兼容性别名
   */
  async create(data: CreateItemRequest) {
    const item = await this.createItem(data);
    return {
      success: true,
      data: item
    };
  }

  /**
   * 获取项目 - 测试兼容性别名
   */
  async get(id: string) {
    try {
      const item = await this.getItem(id);
      return {
        success: true,
        data: item
      };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : '获取失败'
      };
    }
  }

  /**
   * 更新项目 - 测试兼容性别名
   */
  async update(id: string, data: UpdateItemRequest) {
    const item = await this.updateItem(id, data);
    return {
      success: true,
      data: item
    };
  }

  /**
   * 删除项目 - 测试兼容性别名
   */
  async delete(id: string) {
    try {
      await this.deleteItem(id);
      return {
        success: true
      };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : '删除失败'
      };
    }
  }
}

// 导出类和类型
export { CrudApiClient };
export type { 
  CreateItemRequest, 
  UpdateItemRequest, 
  GetItemRequest,
  DeleteItemRequest,
  ListItemsRequest,
  CreateItemResponse,
  GetItemResponse,
  UpdateItemResponse,
  DeleteItemResponse,
  ListItemsResponse 
} from './types';

// 导出单例实例，符合v7架构模式
export const crudApi = new CrudApiClient();

// 向后兼容的导出别名
export const mvpCrudApi = crudApi;
export const MvpCrudApiService = CrudApiClient;

// 默认导出
export default crudApi; 