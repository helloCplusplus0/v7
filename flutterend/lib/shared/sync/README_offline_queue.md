# 离线队列使用指南

> 本文档说明如何在v7 Flutter架构中使用离线操作队列实现离线优先功能

## 📖 概述

离线队列（OfflineQueue）是v7架构中的核心离线组件，提供以下功能：

- ✅ **离线操作缓存**：在网络不可用时缓存用户操作
- ✅ **智能重试机制**：网络恢复后自动重试失败操作
- ✅ **优先级管理**：支持不同优先级的操作排序
- ✅ **批量处理**：高效处理大量操作
- ✅ **依赖管理**：支持操作间的依赖关系
- ✅ **持久化存储**：应用重启后恢复队列状态
- ✅ **类型安全**：完整的泛型支持和错误处理

## 🏗️ 架构设计

### 核心组件

```
OfflineQueue
├── QueueConfig          # 队列配置
├── QueueState           # 队列状态
├── OfflineOperation     # 离线操作
├── OperationExecutor    # 操作执行器
└── SyncManager集成      # 与同步管理器集成
```

### 操作类型

```dart
enum OfflineOperationType {
  create,   // 创建操作
  update,   // 更新操作
  delete,   // 删除操作
  upload,   // 上传操作
  sync,     // 同步操作
}
```

### 操作状态

```dart
enum OperationStatus {
  pending,    // 等待执行
  executing,  // 执行中
  completed,  // 已完成
  failed,     // 执行失败
  cancelled,  // 已取消
  retrying,   // 重试中
}
```

## 🚀 快速开始

### 1. 基本配置

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lib/shared/sync/offline_queue.dart';
import 'lib/shared/sync/sync_manager.dart';

// 使用默认配置的离线队列
final queue = ref.watch(offlineQueueProvider);

// 使用完整功能的同步管理器（包含离线队列）
final syncManager = ref.watch(fullFeaturedSyncManagerProvider);
```

### 2. 创建离线操作

```dart
final operation = OfflineOperation(
  id: 'task-create-${DateTime.now().millisecondsSinceEpoch}',
  type: OfflineOperationType.create,
  entityType: 'task',
  data: {
    'title': '新任务',
    'description': '任务描述',
    'completed': false,
  },
  priority: OperationPriority.normal,
);

// 将操作加入队列
final result = await queue.enqueue(operation);
if (result.isSuccess) {
  print('操作已加入队列: ${result.valueOrNull}');
}
```

### 3. 监听队列状态

```dart
class QueueStatusWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(queueStateStreamProvider);
    
    return queueState.when(
      data: (state) => Column(
        children: [
          Text('待处理: ${state.pendingOperations}'),
          Text('执行中: ${state.executingOperations}'),
          Text('已完成: ${state.completedOperations}'),
          Text('失败: ${state.failedOperations}'),
          LinearProgressIndicator(
            value: state.totalOperations > 0 
                ? state.completedOperations / state.totalOperations 
                : 0.0,
          ),
        ],
      ),
      loading: () => CircularProgressIndicator(),
      error: (error, _) => Text('错误: $error'),
    );
  }
}
```

## 💡 高级用法

### 1. 自定义操作执行器

```dart
class TaskOperationExecutor implements OperationExecutor {
  @override
  String get type => 'task_executor';

  @override
  bool supports(OfflineOperationType operationType, String entityType) {
    return entityType == 'task';
  }

  @override
  Future<Result<void, String>> execute(OfflineOperation operation) async {
    switch (operation.type) {
      case OfflineOperationType.create:
        return await _createTask(operation.data);
      case OfflineOperationType.update:
        return await _updateTask(operation.entityId!, operation.data);
      case OfflineOperationType.delete:
        return await _deleteTask(operation.entityId!);
      default:
        return Result.failure('Unsupported operation: ${operation.type}');
    }
  }

  @override
  Duration estimateExecutionTime(OfflineOperation operation) {
    return const Duration(seconds: 2);
  }

  @override
  Future<bool> canExecute(OfflineOperation operation) async {
    // 检查网络状态、权限等
    return true;
  }

  Future<Result<void, String>> _createTask(Map<String, dynamic> data) async {
    // 实现任务创建逻辑
    return Result.success(null);
  }

  // ... 其他方法实现
}

// 注册自定义执行器
queue.registerExecutor(TaskOperationExecutor());
```

### 2. 批量操作

```dart
final operations = [
  OfflineOperation(
    id: 'task-1',
    type: OfflineOperationType.create,
    entityType: 'task',
    data: {'title': '任务1'},
  ),
  OfflineOperation(
    id: 'task-2', 
    type: OfflineOperationType.create,
    entityType: 'task',
    data: {'title': '任务2'},
  ),
];

final result = await queue.enqueueBatch(operations);
if (result.isSuccess) {
  print('批量操作已加入队列: ${result.valueOrNull!.length} 个操作');
}
```

### 3. 操作依赖

```dart
// 创建父操作
final parentOperation = OfflineOperation(
  id: 'parent-task',
  type: OfflineOperationType.create,
  entityType: 'task',
  data: {'title': '父任务'},
);

// 创建依赖于父操作的子操作
final childOperation = OfflineOperation(
  id: 'child-task',
  type: OfflineOperationType.create,
  entityType: 'task',
  data: {'title': '子任务'},
  dependencies: ['parent-task'], // 依赖父操作
);

// 子操作会等待父操作完成后才执行
await queue.enqueue(parentOperation);
await queue.enqueue(childOperation);
```

### 4. 自定义队列配置

```dart
final customQueue = OfflineQueue(
  config: const QueueConfig(
    maxOperations: 500,           // 最大操作数
    maxRetries: 5,                // 最大重试次数
    retryDelay: Duration(seconds: 10), // 重试间隔
    batchSize: 20,                // 批处理大小
    processingInterval: Duration(minutes: 1), // 处理间隔
    persistenceEnabled: true,     // 启用持久化
    autoProcessing: true,         // 自动处理
  ),
  storage: customStorage,
  database: customDatabase,
);
```

## 🎯 与SyncManager集成

### 1. 完整集成示例

```dart
class OfflineTaskService {
  OfflineTaskService({required SyncManager syncManager}) 
      : _syncManager = syncManager;

  final SyncManager _syncManager;

  Future<Result<String, String>> createTask({
    required String title,
    required String description,
  }) async {
    final taskId = Uuid().v4();
    final task = TaskData(
      id: taskId,
      title: title,
      description: description,
      completed: false,
      createdAt: DateTime.now(),
    );

    // 优先使用离线队列
    if (_syncManager.hasOfflineQueue) {
      final operation = OfflineOperation(
        id: Uuid().v4(),
        type: OfflineOperationType.create,
        entityType: 'task',
        entityId: taskId,
        data: task.toJson(),
        priority: OperationPriority.normal,
      );

      return await _syncManager.enqueueOfflineOperation(operation);
    }

    // 回退到直接同步
    if (_syncManager.currentState.isOnline) {
      // 直接执行创建操作
      return Result.success(taskId);
    }

    return Result.failure('无法创建任务：离线且无队列支持');
  }
}
```

### 2. 使用Provider

```dart
// 服务提供者
final offlineTaskServiceProvider = Provider<OfflineTaskService>((ref) {
  final syncManager = ref.watch(fullFeaturedSyncManagerProvider);
  return OfflineTaskService(syncManager: syncManager);
});

// 在组件中使用
class TaskCreateButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskService = ref.watch(offlineTaskServiceProvider);
    
    return ElevatedButton(
      onPressed: () async {
        final result = await taskService.createTask(
          title: '新任务',
          description: '任务描述',
        );
        
        if (result.isSuccess) {
          // 显示成功消息
        } else {
          // 显示错误消息
        }
      },
      child: Text('创建任务'),
    );
  }
}
```

## 🛠️ 最佳实践

### 1. 操作设计原则

- **幂等性**：确保操作可以安全地重复执行
- **原子性**：每个操作应该是不可分割的
- **数据完整性**：操作数据包含执行所需的所有信息

### 2. 错误处理策略

```dart
// 自定义重试策略
final operation = OfflineOperation(
  id: 'retry-example',
  type: OfflineOperationType.update,
  entityType: 'task',
  data: {...},
  maxRetries: 3,
  retryDelay: Duration(seconds: 5),
);

// 处理失败的操作
final failedOps = await queue.getOperationsByStatus(OperationStatus.failed);
if (failedOps.isSuccess) {
  for (final op in failedOps.valueOrNull!) {
    if (op.canRetry) {
      await queue.retryOperation(op.id);
    } else {
      // 手动处理或清理失败操作
      await queue.removeOperation(op.id);
    }
  }
}
```

### 3. 性能优化

- **批量处理**：合并相似操作以提高效率
- **优先级设置**：重要操作使用高优先级
- **定期清理**：清理已完成的旧操作
- **监控指标**：跟踪队列性能和成功率

### 4. 测试策略

```dart
// 模拟离线场景
test('should queue operations when offline', () async {
  final mockExecutor = MockOperationExecutor();
  queue.registerExecutor(mockExecutor);
  
  final operation = OfflineOperation(
    id: 'test-op',
    type: OfflineOperationType.create,
    entityType: 'test',
    data: {'test': true},
  );
  
  await queue.enqueue(operation);
  
  expect(queue.currentState.pendingOperations, 1);
  
  // 模拟网络恢复，处理队列
  await queue.processNext();
  
  expect(mockExecutor.executedOperations.length, 1);
});
```

## 🔍 故障排除

### 常见问题

1. **操作卡在待处理状态**
   - 检查是否注册了对应的执行器
   - 确认执行器的`supports`方法返回true
   - 验证网络状态和执行器的`canExecute`方法

2. **持久化失败**
   - 检查存储权限
   - 确认存储空间充足
   - 验证序列化/反序列化逻辑

3. **内存占用过高**
   - 调整`maxOperations`配置
   - 定期清理已完成操作
   - 检查操作数据大小

### 调试工具

```dart
// 启用详细日志
const config = QueueConfig(
  debugMode: true, // 如果有的话
);

// 监控队列状态
queue.stateStream.listen((state) {
  print('Queue State: ${state.totalOperations} total, '
        '${state.pendingOperations} pending, '
        '${state.failedOperations} failed');
});

// 查看特定类型的操作
final taskOps = await queue.getOperationsByType('task');
print('Task operations: ${taskOps.valueOrNull?.length ?? 0}');
```

## 📚 参考资源

- [SyncManager集成文档](./README_sync_manager.md)
- [ConflictResolver使用指南](./README_conflict_resolver.md)
- [离线优先架构设计](../../../docs/offline_first_architecture.md)
- [v7架构最佳实践](../../../docs/v7_best_practices.md)

---

## 💡 总结

离线队列是v7架构中实现离线优先功能的核心组件。通过合理配置和使用，可以为用户提供流畅的离线体验，确保数据的完整性和一致性。

关键要点：
- 使用类型安全的操作定义
- 实现自定义执行器以处理业务逻辑
- 监控队列状态以提供用户反馈
- 与SyncManager集成以获得完整的同步能力
- 遵循最佳实践以确保稳定性和性能 