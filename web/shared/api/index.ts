// ============================================================================
// 🎯 v7 Web API客户端统一导出
// ============================================================================

// 🎯 推荐使用：统一gRPC客户端（使用生成的Proto文件）
export { 
  UnifiedGrpcClient,
  grpcClient,
  type GrpcClientConfig,
  type GrpcResponse
} from './grpc-client';

// 🎯 生成的类型定义（来自backend.proto）
// 注意：这些是class，不是type，所以直接导出
export {
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
  UserSession,
  ValidateTokenRequest,
  ValidateTokenResponse,
  LogoutRequest,
  LogoutResponse
} from './generated/backend_pb';

// 🎯 服务定义（来自backend.proto）
export { BackendService } from './generated/backend_connect';

// ============================================================================
// 🎯 推荐使用方式示例
// ============================================================================

/*
import { grpcClient } from '@/shared/api';

// 健康检查
const health = await grpcClient.healthCheck();

// 创建项目
const createResult = await grpcClient.createItem({
  name: '测试项目',
  description: '这是一个测试项目',
  value: 100
});

// 获取项目列表
const listResult = await grpcClient.listItems({
  limit: 10,
  offset: 0
});

// 所有方法都返回统一的 GrpcResponse<T> 格式：
// {
//   success: boolean;
//   data?: T;
//   error?: string;
//   metadata?: Record<string, any>;
// }
*/ 