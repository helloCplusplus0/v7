// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

/// 离线队列与SyncManager集成使用示例
/// 
/// 本文件展示如何在v7 Flutter架构中使用离线队列
/// 实现真正的离线优先应用功能

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:v7_flutter_app/shared/sync/offline_queue.dart';
import 'package:v7_flutter_app/shared/sync/sync_manager.dart';
import 'package:v7_flutter_app/shared/types/result.dart';

/// 示例数据类型
class TaskData {
  const TaskData({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final bool completed;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TaskData copyWith({
    String? id,
    String? title,
    String? description,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskData(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'completed': completed,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory TaskData.fromJson(Map<String, dynamic> json) {
    return TaskData(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      completed: json['completed'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

/// 离线任务管理服务
class OfflineTaskService {
  OfflineTaskService({
    required SyncManager syncManager,
  }) : _syncManager = syncManager;

  final SyncManager _syncManager;
  final _uuid = const Uuid();
  SyncState? _currentSyncState;

  /// 获取当前同步状态
  SyncState get _currentState => _currentSyncState ?? const SyncState();

  /// 初始化服务（监听状态变化）
  void initialize() {
    _syncManager.stateStream.listen((state) {
      _currentSyncState = state;
    });
  }

  /// 创建任务（离线优先）
  Future<Result<String, String>> createTask({
    required String title,
    required String description,
  }) async {
    final taskId = _uuid.v4();
    final task = TaskData(
      id: taskId,
      title: title,
      description: description,
      completed: false,
      createdAt: DateTime.now(),
    );

    // 如果有离线队列，将操作加入队列
    if (_syncManager.hasOfflineQueue) {
      final operation = OfflineOperation(
        id: _uuid.v4(),
        type: OfflineOperationType.create,
        entityType: 'task',
        entityId: taskId,
        data: task.toJson(),
      );

      final result = await _syncManager.enqueueOfflineOperation(operation);
      if (result.isSuccess) {
        debugPrint('Task creation queued: $taskId');
        return Result.success(taskId);
      } else {
        return Result.failure('Failed to queue task creation: ${result.errorOrNull}');
      }
    }

    // 回退：直接同步（如果在线）
    if (_currentState.isOnline) {
      // 这里通常会调用同步提供者的方法
      debugPrint('Creating task online: $taskId');
      return Result.success(taskId);
    }

    return Result.failure('Cannot create task: offline and no queue available');
  }

  /// 更新任务（离线优先）
  Future<Result<void, String>> updateTask({
    required String taskId,
    String? title,
    String? description,
    bool? completed,
  }) async {
    // 构建更新数据
    final updateData = <String, dynamic>{
      'id': taskId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (title != null) updateData['title'] = title;
    if (description != null) updateData['description'] = description;
    if (completed != null) updateData['completed'] = completed;

    // 如果有离线队列，将操作加入队列
    if (_syncManager.hasOfflineQueue) {
      final operation = OfflineOperation(
        id: _uuid.v4(),
        type: OfflineOperationType.update,
        entityType: 'task',
        entityId: taskId,
        data: updateData,
      );

      final result = await _syncManager.enqueueOfflineOperation(operation);
      if (result.isSuccess) {
        debugPrint('Task update queued: $taskId');
        return const Result.success(null);
      } else {
        return Result.failure('Failed to queue task update: ${result.errorOrNull}');
      }
    }

    // 回退：直接同步（如果在线）
    if (_currentState.isOnline) {
      debugPrint('Updating task online: $taskId');
      return const Result.success(null);
    }

    return Result.failure('Cannot update task: offline and no queue available');
  }

  /// 删除任务（离线优先）
  Future<Result<void, String>> deleteTask(String taskId) async {
    // 如果有离线队列，将操作加入队列
    if (_syncManager.hasOfflineQueue) {
      final operation = OfflineOperation(
        id: _uuid.v4(),
        type: OfflineOperationType.delete,
        entityType: 'task',
        entityId: taskId,
        data: {'id': taskId},
        priority: OperationPriority.high, // 删除操作优先级较高
      );

      final result = await _syncManager.enqueueOfflineOperation(operation);
      if (result.isSuccess) {
        debugPrint('Task deletion queued: $taskId');
        return const Result.success(null);
      } else {
        return Result.failure('Failed to queue task deletion: ${result.errorOrNull}');
      }
    }

    // 回退：直接同步（如果在线）
    if (_currentState.isOnline) {
      debugPrint('Deleting task online: $taskId');
      return const Result.success(null);
    }

    return Result.failure('Cannot delete task: offline and no queue available');
  }

  /// 同步所有任务
  Future<Result<void, String>> syncTasks() async {
    final syncResult = await _syncManager.startSync(types: ['task']);
    
    if (syncResult.isSuccess) {
      return const Result.success(null);
    } else {
      return Result.failure('Sync failed: ${syncResult.errorOrNull}');
    }
  }

  /// 处理离线队列
  Future<Result<void, String>> processOfflineQueue() async {
    return await _syncManager.processOfflineQueue();
  }
}

/// Riverpod提供者
final offlineTaskServiceProvider = Provider<OfflineTaskService>((ref) {
  final syncManager = ref.watch(fullFeaturedSyncManagerProvider);
  return OfflineTaskService(syncManager: syncManager);
});

/// 任务状态提供者
final taskSyncStateProvider = StreamProvider<SyncState>((ref) {
  final syncManager = ref.watch(fullFeaturedSyncManagerProvider);
  return syncManager.stateStream;
});

/// 离线队列状态提供者
final offlineQueueStateProvider = StreamProvider<QueueState?>((ref) {
  final syncManager = ref.watch(fullFeaturedSyncManagerProvider);
  final queueStream = syncManager.offlineQueueState;
  
  if (queueStream == null) {
    return Stream.value(null);
  }
  
  return queueStream;
});

/// 示例UI组件
class OfflineTaskDashboard extends ConsumerWidget {
  const OfflineTaskDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskService = ref.watch(offlineTaskServiceProvider);
    final syncState = ref.watch(taskSyncStateProvider);
    final queueState = ref.watch(offlineQueueStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('离线任务管理'),
        actions: [
          // 同步状态指示器
          syncState.when(
            data: (state) => _buildSyncIndicator(state),
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => const Icon(Icons.error, color: Colors.red),
          ),
        ],
      ),
      body: Column(
        children: [
          // 队列状态卡片
          queueState.when(
            data: (state) => state != null ? _buildQueueStatusCard(state, context) : const SizedBox.shrink(),
            loading: () => const Card(child: LinearProgressIndicator()),
            error: (error, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: const Text('队列状态错误'),
                subtitle: Text(error.toString()),
              ),
            ),
          ),
          
          // 操作按钮
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8.0,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _createSampleTask(taskService),
                  icon: const Icon(Icons.add),
                  label: const Text('创建任务'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _syncTasks(taskService),
                  icon: const Icon(Icons.sync),
                  label: const Text('同步任务'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _processOfflineQueue(taskService),
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('处理离线队列'),
                ),
              ],
            ),
          ),
          
          // 任务列表（示例）
          Expanded(
            child: _buildTaskList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncIndicator(SyncState state) {
    IconData icon;
    Color color;
    String tooltip;

    if (!state.isOnline) {
      icon = Icons.offline_bolt;
      color = Colors.orange;
      tooltip = '离线模式';
    } else if (state.isSyncing) {
      icon = Icons.sync;
      color = Colors.blue;
      tooltip = '同步中...';
    } else if (state.hasErrors) {
      icon = Icons.error;
      color = Colors.red;
      tooltip = '同步错误';
    } else {
      icon = Icons.cloud_done;
      color = Colors.green;
      tooltip = '已同步';
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color),
    );
  }

  Widget _buildQueueStatusCard(QueueState state, BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '离线操作队列',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQueueStat('总计', state.totalOperations.toString()),
                _buildQueueStat('待处理', state.pendingOperations.toString()),
                _buildQueueStat('执行中', state.executingOperations.toString()),
                _buildQueueStat('已完成', state.completedOperations.toString()),
                _buildQueueStat('失败', state.failedOperations.toString()),
              ],
            ),
            if (state.hasOperations) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: state.totalOperations > 0 
                    ? state.completedOperations / state.totalOperations 
                    : 0.0,
              ),
              const SizedBox(height: 4),
              Text(
                '成功率: ${(state.successRate * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQueueStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTaskList() {
    // 这里应该显示实际的任务列表
    // 为了简化示例，显示一个占位符
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '任务列表',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            '这里会显示离线任务列表\n集成实际的数据提供者后完善',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _createSampleTask(OfflineTaskService service) async {
    final result = await service.createTask(
      title: '示例任务 ${DateTime.now().millisecondsSinceEpoch}',
      description: '这是一个离线创建的示例任务',
    );

    if (result.isSuccess) {
      debugPrint('Task created: ${result.valueOrNull}');
    } else {
      debugPrint('Failed to create task: ${result.errorOrNull}');
    }
  }

  Future<void> _syncTasks(OfflineTaskService service) async {
    final result = await service.syncTasks();
    
    if (result.isSuccess) {
      debugPrint('Task sync initiated');
    } else {
      debugPrint('Failed to sync tasks: ${result.errorOrNull}');
    }
  }

  Future<void> _processOfflineQueue(OfflineTaskService service) async {
    final result = await service.processOfflineQueue();
    
    if (result.isSuccess) {
      debugPrint('Offline queue processing initiated');
    } else {
      debugPrint('Failed to process offline queue: ${result.errorOrNull}');
    }
  }
}

/// 扩展的SyncManager，演示如何自定义离线行为
class AdvancedOfflineTaskManager {
  AdvancedOfflineTaskManager({
    required SyncManager syncManager,
  }) : _syncManager = syncManager;

  final SyncManager _syncManager;
  SyncState? _currentSyncState;

  /// 获取当前同步状态
  SyncState get _currentState => _currentSyncState ?? const SyncState();

  /// 初始化管理器
  void initialize() {
    _syncManager.stateStream.listen((state) {
      _currentSyncState = state;
    });
  }

  /// 智能离线策略：根据网络状态自动选择操作模式
  Future<Result<void, String>> smartTaskOperation({
    required String operation,
    required Map<String, dynamic> data,
    OperationPriority priority = OperationPriority.normal,
  }) async {
    final state = _currentState;
    
    // 如果在线且没有冲突，直接执行
    if (state.isOnline && !state.hasConflicts && !state.isSyncing) {
      return await _executeTaskOperationDirectly(operation, data);
    }
    
    // 否则使用离线队列
    if (_syncManager.hasOfflineQueue) {
      return await _enqueueTaskOperation(operation, data, priority);
    }
    
    return const Result.failure('Cannot execute operation: offline and no queue available');
  }

  /// 批量操作优化
  Future<Result<void, String>> batchTaskOperations(
    List<Map<String, dynamic>> operations,
  ) async {
    if (!_syncManager.hasOfflineQueue) {
      return const Result.failure('Batch operations require offline queue');
    }

    final offlineOperations = operations.map((opData) {
      return OfflineOperation(
        id: const Uuid().v4(),
        type: _mapOperationType(opData['type'] as String),
        entityType: 'task',
        entityId: opData['entityId'] as String?,
        data: opData,
        priority: OperationPriority.normal,
      );
    }).toList();

    // 注意：这里不能访问私有字段，应该通过公共接口
    // 实际实现中需要SyncManager提供批量操作的公共方法
    debugPrint('Would batch ${operations.length} task operations (需要SyncManager支持批量操作)');
    return const Result.success(null);
  }

  /// 离线状态恢复
  Future<Result<void, String>> recoverFromOffline() async {
    if (!_syncManager.hasOfflineQueue) {
      return const Result.failure('Recovery requires offline queue');
    }

    // 处理所有待处理的操作
    final processResult = await _syncManager.processOfflineQueue();
    if (!processResult.isSuccess) {
      return processResult;
    }

    // 注意：重试操作需要通过公共接口
    debugPrint('离线恢复处理完成 (重试失败操作需要额外的公共接口)');
    return const Result.success(null);
  }

  Future<Result<void, String>> _executeTaskOperationDirectly(
    String operation,
    Map<String, dynamic> data,
  ) async {
    // 模拟直接执行操作
    debugPrint('Executing task operation directly: $operation');
    await Future.delayed(const Duration(seconds: 1));
    return const Result.success(null);
  }

  Future<Result<void, String>> _enqueueTaskOperation(
    String operation,
    Map<String, dynamic> data,
    OperationPriority priority,
  ) async {
    final offlineOperation = OfflineOperation(
      id: const Uuid().v4(),
      type: _mapOperationType(operation),
      entityType: 'task',
      data: data,
      priority: priority,
    );

    final result = await _syncManager.enqueueOfflineOperation(offlineOperation);
    
    if (result.isSuccess) {
      debugPrint('Task operation enqueued: $operation');
      return const Result.success(null);
    } else {
      return Result.failure('Failed to enqueue operation: ${result.errorOrNull}');
    }
  }

  OfflineOperationType _mapOperationType(String operation) {
    switch (operation.toLowerCase()) {
      case 'create':
        return OfflineOperationType.create;
      case 'update':
        return OfflineOperationType.update;
      case 'delete':
        return OfflineOperationType.delete;
      case 'sync':
        return OfflineOperationType.sync;
      case 'upload':
        return OfflineOperationType.upload;
      default:
        return OfflineOperationType.sync;
    }
  }
}