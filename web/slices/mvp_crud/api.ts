// 🌐 MVP CRUD - API客户端实现
// 复用shared/api基础设施，实现类型安全的CRUD API调用

import { BaseApiClient } from '../../shared/api/base';
import type {
  Item,
  CreateItemRequest,
  UpdateItemRequest,
  ListItemsQuery,
  CreateItemResponse,
  GetItemResponse,
  UpdateItemResponse,
  DeleteItemResponse,
  ListItemsResponse,
} from './types';

class CrudApiClient extends BaseApiClient {
  private readonly itemsPath = '/api/items';

  /**
   * 创建新项目
   */
  async createItem(data: CreateItemRequest): Promise<CreateItemResponse> {
    return this.post<CreateItemResponse>(this.itemsPath, data);
  }

  /**
   * 获取项目列表
   */
  async listItems(query: ListItemsQuery = {}): Promise<ListItemsResponse> {
    const params = new URLSearchParams();
    
    if (query.limit !== undefined) params.append('limit', query.limit.toString());
    if (query.offset !== undefined) params.append('offset', query.offset.toString());
    if (query.sort_by) params.append('sort_by', query.sort_by);
    if (query.order) params.append('order', query.order);

    const url = params.toString() ? `${this.itemsPath}?${params}` : this.itemsPath;
    return this.get<ListItemsResponse>(url);
  }

  /**
   * 根据ID获取单个项目
   */
  async getItem(id: string): Promise<GetItemResponse> {
    return this.get<GetItemResponse>(`${this.itemsPath}/${id}`);
  }

  /**
   * 更新项目
   */
  async updateItem(id: string, data: UpdateItemRequest): Promise<UpdateItemResponse> {
    return this.put<UpdateItemResponse>(`${this.itemsPath}/${id}`, data);
  }

  /**
   * 删除项目
   */
  async deleteItem(id: string): Promise<DeleteItemResponse> {
    return this.delete<DeleteItemResponse>(`${this.itemsPath}/${id}`);
  }

  /**
   * 批量删除项目
   */
  async deleteItems(ids: string[]): Promise<{ deleted_count: number; deleted_ids: string[] }> {
    return this.post<{ deleted_count: number; deleted_ids: string[] }>(
      `${this.itemsPath}/batch-delete`,
      { ids }
    );
  }

  /**
   * 检查项目名称是否存在
   */
  async checkNameExists(name: string, excludeId?: string): Promise<{ exists: boolean }> {
    const params = new URLSearchParams({ name });
    if (excludeId) params.append('exclude_id', excludeId);
    
    return this.get<{ exists: boolean }>(
      `${this.itemsPath}/check-name?${params}`
    );
  }
}

// 导出单例实例
export const crudApi = new CrudApiClient();

// 导出类型化的API方法（便于测试和模拟）
export type CrudApiMethods = {
  createItem: typeof crudApi.createItem;
  listItems: typeof crudApi.listItems;
  getItem: typeof crudApi.getItem;
  updateItem: typeof crudApi.updateItem;
  deleteItem: typeof crudApi.deleteItem;
  deleteItems: typeof crudApi.deleteItems;
  checkNameExists: typeof crudApi.checkNameExists;
}; 