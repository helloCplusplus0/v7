# 生成的Proto代码

此目录包含从backend proto文件自动生成的TypeScript代码。

## 🚨 重要提示

**请勿手动修改此目录中的文件！**

所有文件都是通过 `scripts/generate-modern-proto.sh` 脚本自动生成的。

## 📁 文件说明

- `backend_pb.ts` - Proto消息类型定义
- `backend_connect.ts` - ConnectRPC服务定义
- `README.md` - 此说明文件

## 🔄 重新生成

当Backend的proto文件发生变化时，运行以下命令重新生成：

```bash
./scripts/generate-modern-proto.sh
```

## 📦 使用方法

```typescript
// 导入生成的类型
import { CreateItemRequest, Item } from './generated/backend_pb';

// 导入ConnectRPC服务
import { BackendService } from './generated/backend_connect';

// 使用统一的gRPC客户端
import { grpcClient } from '../unified-client';

// 调用API
const response = await grpcClient.createItem({
  name: "新项目",
  description: "项目描述",
  value: 100
});
```

## 🔧 特性

- ✅ 完整的TypeScript类型安全
- ✅ ConnectRPC现代化客户端
- ✅ 自动重试和错误处理
- ✅ 无需Envoy代理
- ✅ 与后端proto定义100%同步

## 📊 生成统计

- 生成时间: 2025年 07月 13日 星期日 16:57:11 CST
- 执行时长: 20秒
- 工具版本: Buf CLI 1.55.1
- 后端Proto: ../backend/proto/backend.proto
- 脚本版本: v7 增强版

## 🛡️ 质量保证

- ✅ Proto文件语法检查
- ✅ Breaking change检测
- ✅ TypeScript类型验证
- ✅ 自动备份和恢复
- ✅ 完整的错误处理
