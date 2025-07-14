// 🧪 gRPC客户端测试套件
// 验证UnifiedGrpcClient的功能完整性和生产环境可用性

import { describe, test, expect, beforeEach, vi } from 'vitest';

// Mock ConnectRPC modules first - before any imports
vi.mock('@connectrpc/connect-web', () => ({
  createConnectTransport: vi.fn(() => ({
    unary: vi.fn(),
    stream: vi.fn(),
    serverStreaming: vi.fn(),
    clientStreaming: vi.fn(),
    duplex: vi.fn()
  }))
}));

vi.mock('@connectrpc/connect', () => ({
  createClient: vi.fn(() => ({
    healthCheck: vi.fn(),
    login: vi.fn(),
    createItem: vi.fn(),
    getItem: vi.fn(),
    updateItem: vi.fn(),
    deleteItem: vi.fn(),
    listItems: vi.fn()
  }))
}));

// Now import the modules after mocking
import { UnifiedGrpcClient, grpcClient, type GrpcClientConfig, type GrpcResponse } from '../../../shared/api/grpc-client';
import { 
  HealthRequest, 
  HealthResponse, 
  LoginRequest, 
  CreateItemRequest, 
  ListItemsRequest 
} from '../../../shared/api';

describe('UnifiedGrpcClient', () => {
  let client: UnifiedGrpcClient;
  let mockClient: any;

  beforeEach(() => {
    vi.clearAllMocks();
    
    // 创建测试客户端实例
    client = new UnifiedGrpcClient({
      baseUrl: 'http://localhost:50053',
      timeout: 5000,
      retryAttempts: 3,
      enableLogging: false
    });

    // 获取mock客户端
    mockClient = (client as any).client;
  });

  describe('构造函数和配置', () => {
    test('应该使用默认配置创建客户端', () => {
      const defaultClient = new UnifiedGrpcClient();
      const config = defaultClient.getConfig();
      
      expect(config.baseUrl).toBe('http://192.168.31.84:50053');
      expect(config.timeout).toBe(10000);
      expect(config.retryAttempts).toBe(3);
      expect(config.enableLogging).toBe(true);
    });

    test('应该使用自定义配置创建客户端', () => {
      const customConfig: GrpcClientConfig = {
        baseUrl: 'http://custom:8080',
        timeout: 15000,
        retryAttempts: 5,
        enableLogging: false,
        headers: { 'Custom-Header': 'test' }
      };

      const customClient = new UnifiedGrpcClient(customConfig);
      const config = customClient.getConfig();
      
      expect(config.baseUrl).toBe('http://custom:8080');
      expect(config.timeout).toBe(15000);
      expect(config.retryAttempts).toBe(5);
      expect(config.enableLogging).toBe(false);
      expect(config.headers).toEqual({ 'Custom-Header': 'test' });
    });

    test('应该支持配置更新', () => {
      const initialConfig = client.getConfig();
      expect(initialConfig.baseUrl).toBe('http://localhost:50053');

      client.updateConfig({ baseUrl: 'http://updated:9090' });
      const updatedConfig = client.getConfig();
      expect(updatedConfig.baseUrl).toBe('http://updated:9090');
      expect(updatedConfig.timeout).toBe(5000);
    });
  });

  describe('健康检查功能', () => {
    test('应该成功执行健康检查', async () => {
      const mockResponse = new HealthResponse({
        status: 'healthy',
        version: '1.0.0',
        timestamp: BigInt(Date.now())
      });

      mockClient.healthCheck.mockResolvedValue(mockResponse);

      const result = await client.healthCheck();

      expect(result.success).toBe(true);
      expect(result.data).toBe(mockResponse);
      expect(result.metadata).toBeDefined();
      expect(mockClient.healthCheck).toHaveBeenCalledWith(expect.any(HealthRequest));
    });

    test('应该处理健康检查失败', async () => {
      const error = new Error('Service unavailable');
      mockClient.healthCheck.mockRejectedValue(error);

      const result = await client.healthCheck();

      expect(result.success).toBe(false);
      expect(result.error).toBe('Service unavailable');
      expect(result.data).toBeUndefined();
    });
  });

  describe('用户认证功能', () => {
    test('应该成功执行登录', async () => {
      const mockResponse = {
        success: true,
        error: '',
        session: {
          token: 'test-token',
          userId: 'user-123',
          username: 'testuser',
          expiresAt: BigInt(Date.now() + 3600000)
        }
      };

      mockClient.login.mockResolvedValue(mockResponse);

      const result = await client.login({
        username: 'testuser',
        password: 'password123'
      });

      expect(result.success).toBe(true);
      expect(result.data).toBe(mockResponse);
      expect(mockClient.login).toHaveBeenCalledWith(expect.any(LoginRequest));
    });

    test('应该处理登录失败', async () => {
      const error = new Error('Invalid credentials');
      mockClient.login.mockRejectedValue(error);

      const result = await client.login({
        username: 'invalid',
        password: 'wrong'
      });

      expect(result.success).toBe(false);
      expect(result.error).toBe('Invalid credentials');
    });
  });

  describe('CRUD操作功能', () => {
    test('应该成功创建项目', async () => {
      const mockResponse = {
        success: true,
        error: '',
        item: {
          id: 'item-123',
          name: 'Test Item',
          description: 'Test Description',
          value: 100,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString()
        }
      };

      mockClient.createItem.mockResolvedValue(mockResponse);

      const result = await client.createItem({
        name: 'Test Item',
        description: 'Test Description',
        value: 100
      });

      expect(result.success).toBe(true);
      expect(result.data).toBe(mockResponse);
      expect(mockClient.createItem).toHaveBeenCalledWith(expect.any(CreateItemRequest));
    });

    test('应该成功获取项目列表', async () => {
      const mockResponse = {
        success: true,
        error: '',
        items: [
          { id: 'item-1', name: 'Item 1' },
          { id: 'item-2', name: 'Item 2' }
        ],
        total: 2
      };

      mockClient.listItems.mockResolvedValue(mockResponse);

      const result = await client.listItems({
        limit: 10,
        offset: 0
      });

      expect(result.success).toBe(true);
      expect(result.data).toBe(mockResponse);
      expect(mockClient.listItems).toHaveBeenCalledWith(expect.any(ListItemsRequest));
    });
  });

  describe('错误处理和重试机制', () => {
    test('应该在失败后进行重试', async () => {
      const error = new Error('Network error');
      
      // 第一次和第二次调用失败，第三次成功
      mockClient.healthCheck
        .mockRejectedValueOnce(error)
        .mockRejectedValueOnce(error)
        .mockResolvedValueOnce({ status: 'healthy' });

      const result = await client.healthCheck();

      expect(result.success).toBe(true);
      expect(mockClient.healthCheck).toHaveBeenCalledTimes(3);
    });

    test('应该在达到最大重试次数后返回失败', async () => {
      const error = new Error('Persistent error');
      mockClient.healthCheck.mockRejectedValue(error);

      const result = await client.healthCheck();

      expect(result.success).toBe(false);
      expect(result.error).toBe('Persistent error');
      expect(mockClient.healthCheck).toHaveBeenCalledTimes(3); // 配置重试3次
    });
  });

  describe('类型安全性验证', () => {
    test('应该返回正确的响应类型', async () => {
      mockClient.healthCheck.mockResolvedValue({ status: 'healthy' });

      const result: GrpcResponse<any> = await client.healthCheck();

      expect(typeof result.success).toBe('boolean');
      expect(result.data !== undefined || result.error !== undefined).toBe(true);
      
      if (result.metadata) {
        expect(typeof result.metadata).toBe('object');
      }
    });
  });
});

describe('全局grpcClient实例', () => {
  test('应该导出配置好的客户端实例', () => {
    expect(grpcClient).toBeInstanceOf(UnifiedGrpcClient);
    
    const config = grpcClient.getConfig();
    expect(config.baseUrl).toBe('http://192.168.31.84:50053');
  });

  test('应该与新创建的实例功能一致', () => {
    const newClient = new UnifiedGrpcClient();
    expect(grpcClient.getConfig()).toEqual(newClient.getConfig());
  });
});

describe('生产环境可用性验证', () => {
  let prodClient: UnifiedGrpcClient;
  let prodMockClient: any;

  beforeEach(() => {
    vi.clearAllMocks();
    
    prodClient = new UnifiedGrpcClient({
      baseUrl: 'http://localhost:50053',
      timeout: 5000,
      retryAttempts: 1,
      enableLogging: false
    });

    prodMockClient = (prodClient as any).client;
  });

  test('应该处理大量并发请求', async () => {
    prodMockClient.healthCheck.mockResolvedValue({ status: 'healthy' });

    const promises = Array(50).fill(0).map(() => prodClient.healthCheck());
    const results = await Promise.all(promises);

    expect(results).toHaveLength(50);
    expect(results.every((r: any) => r.success)).toBe(true);
  });

  test('应该正确处理超时场景', async () => {
    const timeoutClient = new UnifiedGrpcClient({
      timeout: 100,
      retryAttempts: 1
    });

    const mockTimeoutClient = (timeoutClient as any).client;
    
    mockTimeoutClient.healthCheck.mockImplementation(() => 
      new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Timeout')), 200)
      )
    );

    const result = await timeoutClient.healthCheck();

    expect(result.success).toBe(false);
    expect(result.error).toBe('Timeout');
  });

  test('应该支持自定义请求头', () => {
    const clientWithHeaders = new UnifiedGrpcClient({
      headers: {
        'Authorization': 'Bearer token',
        'X-Client-Version': '1.0.0'
      }
    });

    const config = clientWithHeaders.getConfig();
    expect(config.headers).toEqual({
      'Authorization': 'Bearer token',
      'X-Client-Version': '1.0.0'
    });
  });

  test('应该正确处理空响应', async () => {
    prodMockClient.healthCheck.mockResolvedValue(null);

    const result = await prodClient.healthCheck();

    expect(result.success).toBe(true);
    expect(result.data).toBe(null);
  });

  test('应该正确处理部分失败的批量操作', async () => {
    const items = ['item1', 'item2', 'item3'];
    
    prodMockClient.getItem
      .mockResolvedValueOnce({ success: true, item: { id: 'item1' } })
      .mockRejectedValueOnce(new Error('Not found'))
      .mockResolvedValueOnce({ success: true, item: { id: 'item3' } });

    const results = await Promise.allSettled(
      items.map(id => prodClient.getItem({ id }))
    );

    // 所有Promise都应该fulfilled，因为callMethod捕获了错误
    expect(results[0].status).toBe('fulfilled');
    expect(results[1].status).toBe('fulfilled');
    expect(results[2].status).toBe('fulfilled');

    const responses = results.map((r: any) => 
      r.status === 'fulfilled' ? r.value : null
    );

    expect(responses[0]?.success).toBe(true);
    expect(responses[1]?.success).toBe(false);
    expect(responses[1]?.error).toBe('Not found');
    expect(responses[2]?.success).toBe(true);
  });
}); 