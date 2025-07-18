// 🎯 v7统一gRPC客户端 - 使用标准gRPC-Web协议
// 与后端tonic-web兼容的实现

import {
  HealthRequest,
  HealthResponse,
  LoginRequest,
  LoginResponse,
  CreateItemRequest,
  CreateItemResponse,
  GetItemRequest,
  GetItemResponse,
  UpdateItemRequest,
  UpdateItemResponse,
  DeleteItemRequest,
  DeleteItemResponse,
  ListItemsRequest,
  ListItemsResponse,
  Item,
  // 🔥 MVP_STAT 功能相关类型
  StatisticsRequest,
  StatisticsResponse,
  GenerateRandomDataRequest,
  GenerateRandomDataResponse,
  CalculateStatisticsRequest,
  CalculateStatisticsResponse,
  ComprehensiveAnalysisRequest,
  ComprehensiveAnalysisResponse,
  DataSummary,
  StatisticsResult,
  BasicStatistics,
  DistributionStatistics,
  PercentileInfo,
  ShapeStatistics,
  PerformanceInfo,
  DataRange
} from './generated/backend_pb';

/**
 * 统一gRPC客户端配置
 */
export interface GrpcClientConfig {
  baseUrl: string;
  timeout?: number;
  retryAttempts?: number;
  enableLogging?: boolean;
  headers?: Record<string, string>;
}

/**
 * gRPC响应包装器
 */
export interface GrpcResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  metadata?: Record<string, any>;
}

/**
 * gRPC错误类型
 */
export class GrpcError extends Error {
  constructor(
    message: string,
    public code?: number,
    public details?: string
  ) {
    super(message);
    this.name = 'GrpcError';
  }
}

/**
 * v7统一gRPC客户端 - 标准gRPC-Web协议
 * 
 * 特性：
 * - 使用标准gRPC-Web协议，与tonic-web兼容
 * - 统一的错误处理
 * - 自动重试机制
 * - 请求/响应日志
 * - 完整类型安全
 * - 开发环境自动使用Vite代理
 */
export class UnifiedGrpcClient {
  private config: Required<GrpcClientConfig>;

  constructor(config: Partial<GrpcClientConfig> = {}) {
    // 🔧 智能环境检测和配置
    const isDev = import.meta.env.DEV;
    
    // 🎯 统一代理模式：开发和生产环境都通过当前域名的代理访问Backend
    // 开发环境：localhost:5173 通过Vite代理 → Backend:50053
    // 生产环境：域名:8080 通过nginx代理 → Backend:3000/50053
    const defaultBaseUrl = `${window.location.protocol}//${window.location.host}`;
    
    this.config = {
      baseUrl: config.baseUrl || defaultBaseUrl,
      timeout: config.timeout || 30000,  // 增加超时时间
      retryAttempts: config.retryAttempts || 3,
      enableLogging: config.enableLogging ?? true,
      headers: config.headers || {}
    };

    if (this.config.enableLogging) {
      console.log(`🔧 [gRPC] 初始化客户端:`, {
        environment: isDev ? 'development' : 'production',
        baseUrl: this.config.baseUrl,
        mode: 'unified-proxy-mode',
        description: isDev 
          ? 'Using Vite proxy to Backend:50053' 
          : 'Using nginx proxy to Backend:3000/50053',
        timeout: this.config.timeout,
        currentHost: window.location.host,
        currentProtocol: window.location.protocol
      });
    }
  }

  /**
   * 健康检查
   */
  async healthCheck(request?: Partial<HealthRequest>): Promise<GrpcResponse<HealthResponse>> {
    const req = new HealthRequest({
      service: request?.service || 'backend'
    });
    return this.callMethod('HealthCheck', req);
  }

  /**
   * 用户登录
   */
  async login(request: Partial<LoginRequest>): Promise<GrpcResponse<LoginResponse>> {
    const req = new LoginRequest({
      username: request.username || '',
      password: request.password || ''
    });
    return this.callMethod('Login', req);
  }

  /**
   * 创建项目
   */
  async createItem(request: Partial<CreateItemRequest>): Promise<GrpcResponse<CreateItemResponse>> {
    const req = new CreateItemRequest({
      name: request.name || '',
      description: request.description,
      value: request.value || 0
    });
    return this.callMethod('CreateItem', req);
  }

  /**
   * 获取项目
   */
  async getItem(request: Partial<GetItemRequest>): Promise<GrpcResponse<GetItemResponse>> {
    const req = new GetItemRequest({
      id: request.id || ''
    });
    return this.callMethod('GetItem', req);
  }

  /**
   * 更新项目
   */
  async updateItem(request: Partial<UpdateItemRequest>): Promise<GrpcResponse<UpdateItemResponse>> {
    const req = new UpdateItemRequest({
      id: request.id || '',
      name: request.name,
      description: request.description,
      value: request.value
    });
    return this.callMethod('UpdateItem', req);
  }

  /**
   * 删除项目
   */
  async deleteItem(request: Partial<DeleteItemRequest>): Promise<GrpcResponse<DeleteItemResponse>> {
    const req = new DeleteItemRequest({
      id: request.id || ''
    });
    return this.callMethod('DeleteItem', req);
  }

  /**
   * 列出项目
   */
  async listItems(request?: Partial<ListItemsRequest>): Promise<GrpcResponse<ListItemsResponse>> {
    const req = new ListItemsRequest({
      limit: request?.limit,
      offset: request?.offset,
      search: request?.search
    });
    return this.callMethod('ListItems', req);
  }

  // ===== 🔥 MVP_STAT 统计分析功能 =====

  /**
   * 生成随机数据
   */
  async generateRandomData(request: Partial<GenerateRandomDataRequest>): Promise<GrpcResponse<GenerateRandomDataResponse>> {
    const req = new StatisticsRequest({
      requestType: {
        case: 'generateData',
        value: new GenerateRandomDataRequest({
          count: request.count,
          seed: request.seed ? BigInt(request.seed) : undefined,
          minValue: request.minValue,
          maxValue: request.maxValue,
          distribution: request.distribution
        })
      }
    });
    
    const response = await this.callMethod<StatisticsRequest, StatisticsResponse>('Statistics', req);
    
    if (response.success && response.data?.responseType?.case === 'dataResponse') {
      return {
        success: true,
        data: response.data.responseType.value,
        metadata: response.metadata
      };
    }
    
    return {
      success: false,
      error: response.error || '生成随机数据失败'
    };
  }

  /**
   * 计算统计量
   */
  async calculateStatistics(request: Partial<CalculateStatisticsRequest>): Promise<GrpcResponse<CalculateStatisticsResponse>> {
    const req = new StatisticsRequest({
      requestType: {
        case: 'calculateStats',
        value: new CalculateStatisticsRequest({
          data: request.data || [],
          statistics: request.statistics || [],
          percentiles: request.percentiles || [],
          useAnalyticsEngine: request.useAnalyticsEngine,
          preferRust: request.preferRust
        })
      }
    });
    
    const response = await this.callMethod<StatisticsRequest, StatisticsResponse>('Statistics', req);
    
    if (response.success && response.data?.responseType?.case === 'statsResponse') {
      return {
        success: true,
        data: response.data.responseType.value,
        metadata: response.metadata
      };
    }
    
    return {
      success: false,
      error: response.error || '计算统计量失败'
    };
  }

  /**
   * 综合分析（生成数据 + 计算统计量）
   */
  async comprehensiveAnalysis(request: {
    dataConfig?: Partial<GenerateRandomDataRequest>;
    statsConfig?: Partial<CalculateStatisticsRequest>;
  }): Promise<GrpcResponse<ComprehensiveAnalysisResponse>> {
    const req = new StatisticsRequest({
      requestType: {
        case: 'comprehensive',
        value: new ComprehensiveAnalysisRequest({
          dataConfig: request.dataConfig ? new GenerateRandomDataRequest(request.dataConfig) : undefined,
          statsConfig: request.statsConfig ? new CalculateStatisticsRequest(request.statsConfig) : undefined
        })
      }
    });
    
    const response = await this.callMethod<StatisticsRequest, StatisticsResponse>('Statistics', req);
    
    if (response.success && response.data?.responseType?.case === 'comprehensiveResponse') {
      return {
        success: true,
        data: response.data.responseType.value,
        metadata: response.metadata
      };
    }
    
    return {
      success: false,
      error: response.error || '综合分析失败'
    };
  }

  // ===== 通用方法 =====

  /**
   * 通用gRPC方法调用
   */
  private async callMethod<TRequest, TResponse>(
    methodName: string,
    request: TRequest
  ): Promise<GrpcResponse<TResponse>> {
    const startTime = Date.now();
    
    if (this.config.enableLogging) {
      console.log(`🚀 [gRPC] ${methodName}:`, request);
    }

    let lastError: Error | null = null;
    
    for (let attempt = 1; attempt <= this.config.retryAttempts; attempt++) {
      try {
        const response = await this.makeRequest<TRequest, TResponse>(methodName, request);
        
        if (this.config.enableLogging) {
          const duration = Date.now() - startTime;
          console.log(`✅ [gRPC] ${methodName} 成功 (${duration}ms):`, response);
        }
        
        return response;
      } catch (error) {
        lastError = error as Error;
        
        if (this.config.enableLogging) {
          console.warn(`⚠️ [gRPC] ${methodName} 失败 (尝试 ${attempt}/${this.config.retryAttempts}):`, error);
        }
        
        if (attempt < this.config.retryAttempts) {
          const delay = Math.min(Math.pow(2, attempt) * 1000, 5000); // 最大5秒
          await this.delay(delay);
        }
      }
    }

    const duration = Date.now() - startTime;
    if (this.config.enableLogging) {
      console.error(`❌ [gRPC] ${methodName} 最终失败 (${duration}ms):`, lastError);
    }

    return {
      success: false,
      error: lastError?.message || '未知错误'
    };
  }

  /**
   * 使用标准gRPC-Web协议发起请求
   */
  private async makeRequest<TRequest, TResponse>(
    methodName: string,
    request: TRequest
  ): Promise<GrpcResponse<TResponse>> {
    try {
      // 序列化请求
      const serializedRequest = (request as any).toBinary();
      
      // 构建URL
      const url = `${this.config.baseUrl}/v7.backend.BackendService/${methodName}`;
      
      // 构建headers
      const headers = new Headers({
        'Content-Type': 'application/grpc-web+proto',
        'X-Grpc-Web': '1',
        ...this.config.headers
      });

      if (this.config.enableLogging) {
        console.log('🔧 [gRPC] 发送请求:', {
          url,
          method: 'POST',
          headers: Object.fromEntries(headers.entries()),
          bodyLength: serializedRequest.length
        });
      }

      // 发送请求
      const response = await fetch(url, {
        method: 'POST',
        headers,
        body: this.encodeGrpcWebRequest(serializedRequest),
        signal: AbortSignal.timeout(this.config.timeout)
      });

      if (this.config.enableLogging) {
        console.log('📡 [gRPC] 收到响应:', {
          status: response.status,
          statusText: response.statusText,
          headers: Object.fromEntries(response.headers.entries())
        });
      }

      if (!response.ok) {
        throw new GrpcError(
          `HTTP ${response.status}: ${response.statusText}`,
          response.status
        );
      }

      // 解析响应
      const responseData = await response.arrayBuffer();
      const decodedResponse = this.decodeGrpcWebResponse(new Uint8Array(responseData));

      // 检查gRPC状态
      const grpcStatus = response.headers.get('grpc-status');
      if (grpcStatus && grpcStatus !== '0') {
        const grpcMessage = response.headers.get('grpc-message') || 'Unknown gRPC error';
        throw new GrpcError(
          `gRPC Error: ${grpcMessage}`,
          parseInt(grpcStatus),
          grpcMessage
        );
      }

      // 反序列化响应
      let deserializedResponse: TResponse;
      try {
        deserializedResponse = this.deserializeResponse<TResponse>(methodName, decodedResponse);
      } catch (error) {
        throw new GrpcError(`Failed to deserialize response: ${error}`);
      }

      return {
        success: true,
        data: deserializedResponse,
        metadata: {
          method: methodName,
          timestamp: new Date().toISOString(),
          baseUrl: this.config.baseUrl
        }
      };
    } catch (error) {
      // 增强错误处理
      if (error instanceof GrpcError) {
        throw error;
      }
      
      if (error instanceof Error) {
        // 检查是否是网络错误
        if (error.message.includes('Failed to fetch') || error.name === 'TypeError') {
          throw new GrpcError(`网络连接失败: 无法连接到服务器 (${this.config.baseUrl})`);
        }
        // 检查是否是超时错误
        if (error.name === 'TimeoutError' || error.message.includes('timeout')) {
          throw new GrpcError(`请求超时: 服务器响应时间过长`);
        }
        // 检查是否是CORS错误
        if (error.message.includes('CORS')) {
          throw new GrpcError(`跨域请求被阻止: 请检查服务器CORS配置`);
        }
      }
      
      throw new GrpcError(`请求失败: ${error}`);
    }
  }

  /**
   * 编码gRPC-Web请求
   */
  private encodeGrpcWebRequest(data: Uint8Array): Uint8Array {
    // gRPC-Web格式: [compressed_flag(1字节)] + [length(4字节)] + [data]
    const result = new Uint8Array(5 + data.length);
    result[0] = 0; // 未压缩
    
    // 写入长度 (big-endian)
    const length = data.length;
    result[1] = (length >>> 24) & 0xff;
    result[2] = (length >>> 16) & 0xff;
    result[3] = (length >>> 8) & 0xff;
    result[4] = length & 0xff;
    
    // 写入数据
    result.set(data, 5);
    
    return result;
  }

  /**
   * 解码gRPC-Web响应
   */
  private decodeGrpcWebResponse(data: Uint8Array): Uint8Array {
    if (data.length < 5) {
      throw new GrpcError('Invalid gRPC-Web response: too short');
    }
    
    // 读取压缩标志
    const compressed = data[0] === 1;
    if (compressed) {
      throw new GrpcError('Compressed responses not supported');
    }
    
    // 读取长度 (big-endian)
    const length = (data[1] << 24) | (data[2] << 16) | (data[3] << 8) | data[4];
    
    if (data.length < 5 + length) {
      throw new GrpcError('Invalid gRPC-Web response: length mismatch');
    }
    
    // 返回数据部分
    return data.slice(5, 5 + length);
  }

  /**
   * 反序列化响应数据
   */
  private deserializeResponse<T>(methodName: string, data: Uint8Array): T {
    // 根据方法名选择正确的响应类型进行反序列化
    switch (methodName) {
      case 'HealthCheck':
        return HealthResponse.fromBinary(data) as T;
      case 'Login':
        return LoginResponse.fromBinary(data) as T;
      case 'CreateItem':
        return CreateItemResponse.fromBinary(data) as T;
      case 'GetItem':
        return GetItemResponse.fromBinary(data) as T;
      case 'UpdateItem':
        return UpdateItemResponse.fromBinary(data) as T;
      case 'DeleteItem':
        return DeleteItemResponse.fromBinary(data) as T;
      case 'ListItems':
        return ListItemsResponse.fromBinary(data) as T;
      // 🔥 MVP_STAT 统计分析功能
      case 'Statistics':
        return StatisticsResponse.fromBinary(data) as T;
      default:
        throw new GrpcError(`Unknown method: ${methodName}`);
    }
  }

  /**
   * 延迟函数
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 获取配置
   */
  getConfig(): Required<GrpcClientConfig> {
    return { ...this.config };
  }

  /**
   * 更新配置
   */
  updateConfig(newConfig: Partial<GrpcClientConfig>): void {
    this.config = { ...this.config, ...newConfig };
    
    if (this.config.enableLogging) {
      console.log('🔧 [gRPC] 配置已更新:', this.config);
    }
  }

  /**
   * 测试连接
   */
  async testConnection(): Promise<{ success: boolean; message: string; details?: any }> {
    try {
      const result = await this.healthCheck();
      if (result.success) {
        return {
          success: true,
          message: '连接测试成功',
          details: result.data
        };
      } else {
        return {
          success: false,
          message: `连接测试失败: ${result.error}`,
          details: result
        };
      }
    } catch (error) {
      return {
        success: false,
        message: `连接测试异常: ${error instanceof Error ? error.message : String(error)}`,
        details: error
      };
    }
  }
}

// 导出单例实例
export const grpcClient = new UnifiedGrpcClient();

// 导出类型
export type {
  HealthRequest,
  HealthResponse,
  LoginRequest,
  LoginResponse,
  CreateItemRequest,
  CreateItemResponse,
  GetItemRequest,
  GetItemResponse,
  UpdateItemRequest,
  UpdateItemResponse,
  DeleteItemRequest,
  DeleteItemResponse,
  ListItemsRequest,
  ListItemsResponse,
  Item,
  StatisticsRequest,
  StatisticsResponse,
  GenerateRandomDataRequest,
  GenerateRandomDataResponse,
  CalculateStatisticsRequest,
  CalculateStatisticsResponse,
  ComprehensiveAnalysisRequest,
  ComprehensiveAnalysisResponse,
  DataSummary,
  StatisticsResult,
  BasicStatistics,
  DistributionStatistics,
  PercentileInfo,
  ShapeStatistics,
  PerformanceInfo,
  DataRange
}; 