/// 后台任务执行器
/// 提供强大的任务调度、执行和监控能力

import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../types/result.dart';
import '../events/events.dart';
import '../events/event_bus.dart';

/// 任务优先级
enum TaskPriority {
  low(1),
  normal(2),
  high(3),
  critical(4);

  const TaskPriority(this.value);
  final int value;
}

/// 任务状态
enum TaskStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
  retrying,
}

/// 任务执行策略
enum TaskExecutionStrategy {
  /// 立即执行
  immediate,
  /// 延迟执行
  delayed,
  /// 定期执行
  periodic,
  /// 条件执行
  conditional,
  /// 依赖执行
  dependent,
}

/// 任务重试策略
enum TaskRetryStrategy {
  /// 不重试
  none,
  /// 固定间隔重试
  fixed,
  /// 指数退避重试
  exponentialBackoff,
  /// 自定义重试
  custom,
}

/// 任务执行上下文
class TaskExecutionContext {
  TaskExecutionContext({
    required this.taskId,
    required this.attempt,
    required this.startTime,
    this.metadata = const {},
    this.cancellationToken,
  });

  final String taskId;
  final int attempt;
  final DateTime startTime;
  final Map<String, dynamic> metadata;
  final CancellationToken? cancellationToken;

  Duration get elapsed => DateTime.now().difference(startTime);

  bool get isCancelled => cancellationToken?.isCancelled ?? false;
}

/// 取消令牌
class CancellationToken {
  CancellationToken();

  bool _isCancelled = false;
  String? _reason;
  final List<VoidCallback> _callbacks = [];

  bool get isCancelled => _isCancelled;
  String? get reason => _reason;

  void cancel([String? reason]) {
    if (_isCancelled) return;
    
    _isCancelled = true;
    _reason = reason;
    
    for (final callback in _callbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error in cancellation callback: $e');
      }
    }
    _callbacks.clear();
  }

  void onCancelled(VoidCallback callback) {
    if (_isCancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw TaskCancelledException(_reason);
    }
  }
}

/// 任务取消异常
class TaskCancelledException extends AppError {
  const TaskCancelledException(String? reason) : super(reason ?? 'Task was cancelled');
  
  @override
  String toString() => 'TaskCancelledException: $message';
}

/// 任务执行异常
class TaskExecutionException extends AppError {
  const TaskExecutionException(String message, [dynamic cause]) : super(message, cause);
  
  @override
  String toString() => 'TaskExecutionException: $message';
}

/// 任务定义
abstract class BackgroundTask {
  /// 任务ID
  String get id;
  
  /// 任务名称
  String get name;
  
  /// 任务描述
  String get description;
  
  /// 任务优先级
  TaskPriority get priority => TaskPriority.normal;
  
  /// 执行策略
  TaskExecutionStrategy get executionStrategy => TaskExecutionStrategy.immediate;
  
  /// 重试策略
  TaskRetryStrategy get retryStrategy => TaskRetryStrategy.exponentialBackoff;
  
  /// 最大重试次数
  int get maxRetries => 3;
  
  /// 重试延迟
  Duration get retryDelay => const Duration(seconds: 30);
  
  /// 任务超时
  Duration get timeout => const Duration(minutes: 5);
  
  /// 任务依赖
  List<String> get dependencies => const [];
  
  /// 执行条件
  Future<bool> canExecute(TaskExecutionContext context) async => true;
  
  /// 执行任务
  Future<AppResult<dynamic>> execute(TaskExecutionContext context);
  
  /// 任务完成后的清理
  Future<void> cleanup(TaskExecutionContext context) async {}
  
  /// 任务失败后的处理
  Future<void> onFailure(TaskExecutionContext context, dynamic error) async {}
}

/// 任务实例
class TaskInstance {
  TaskInstance({
    required this.task,
    required this.id,
    required this.createdAt,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.status = TaskStatus.pending,
    this.priority,
    this.attempt = 0,
    this.result,
    this.error,
    this.metadata = const {},
    this.cancellationToken,
  });

  final BackgroundTask task;
  final String id;
  final DateTime createdAt;
  DateTime? scheduledAt;
  DateTime? startedAt;
  DateTime? completedAt;
  TaskStatus status;
  TaskPriority? priority;
  int attempt;
  AppResult<dynamic>? result;
  dynamic error;
  Map<String, dynamic> metadata;
  CancellationToken? cancellationToken;

  TaskPriority get effectivePriority => priority ?? task.priority;
  
  Duration? get executionTime {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }
  
  Duration? get waitTime {
    if (scheduledAt == null || startedAt == null) return null;
    return startedAt!.difference(scheduledAt!);
  }
  
  bool get isCompleted => [TaskStatus.completed, TaskStatus.failed, TaskStatus.cancelled].contains(status);
  
  bool get canRetry => status == TaskStatus.failed && attempt < task.maxRetries;
}

/// 任务队列
class TaskQueue {
  TaskQueue({this.maxSize = 1000});

  final int maxSize;
  final List<TaskInstance> _tasks = [];
  final Map<String, TaskInstance> _taskMap = {};

  int get length => _tasks.length;
  bool get isEmpty => _tasks.isEmpty;
  bool get isNotEmpty => _tasks.isNotEmpty;
  bool get isFull => _tasks.length >= maxSize;

  /// 添加任务
  bool enqueue(TaskInstance task) {
    if (isFull) return false;
    
    _tasks.add(task);
    _taskMap[task.id] = task;
    
    // 按优先级排序
    _tasks.sort((a, b) {
      final priorityCompare = b.effectivePriority.value.compareTo(a.effectivePriority.value);
      if (priorityCompare != 0) return priorityCompare;
      
      // 相同优先级按创建时间排序
      return a.createdAt.compareTo(b.createdAt);
    });
    
    return true;
  }

  /// 获取下一个任务
  TaskInstance? dequeue() {
    if (isEmpty) return null;
    
    final task = _tasks.removeAt(0);
    _taskMap.remove(task.id);
    return task;
  }

  /// 获取任务
  TaskInstance? getTask(String id) => _taskMap[id];

  /// 移除任务
  bool remove(String id) {
    final task = _taskMap[id];
    if (task == null) return false;
    
    _tasks.remove(task);
    _taskMap.remove(id);
    return true;
  }

  /// 清空队列
  void clear() {
    _tasks.clear();
    _taskMap.clear();
  }

  /// 获取所有任务
  List<TaskInstance> get allTasks => List.unmodifiable(_tasks);
}

/// 任务执行器状态
class TaskExecutorState {
  const TaskExecutorState({
    this.isRunning = false,
    this.activeTaskCount = 0,
    this.completedTaskCount = 0,
    this.failedTaskCount = 0,
    this.totalTaskCount = 0,
    this.averageExecutionTime = Duration.zero,
    this.lastError,
  });

  final bool isRunning;
  final int activeTaskCount;
  final int completedTaskCount;
  final int failedTaskCount;
  final int totalTaskCount;
  final Duration averageExecutionTime;
  final String? lastError;

  double get successRate => totalTaskCount > 0 ? completedTaskCount / totalTaskCount : 0.0;
  double get failureRate => totalTaskCount > 0 ? failedTaskCount / totalTaskCount : 0.0;

  TaskExecutorState copyWith({
    bool? isRunning,
    int? activeTaskCount,
    int? completedTaskCount,
    int? failedTaskCount,
    int? totalTaskCount,
    Duration? averageExecutionTime,
    String? lastError,
  }) {
    return TaskExecutorState(
      isRunning: isRunning ?? this.isRunning,
      activeTaskCount: activeTaskCount ?? this.activeTaskCount,
      completedTaskCount: completedTaskCount ?? this.completedTaskCount,
      failedTaskCount: failedTaskCount ?? this.failedTaskCount,
      totalTaskCount: totalTaskCount ?? this.totalTaskCount,
      averageExecutionTime: averageExecutionTime ?? this.averageExecutionTime,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// 后台任务执行器
class BackgroundTaskExecutor {
  BackgroundTaskExecutor({
    this.maxConcurrentTasks = 3,
    this.eventBus,
  });

  final int maxConcurrentTasks;
  final EventBus? eventBus;

  final TaskQueue _taskQueue = TaskQueue();
  final Map<String, TaskInstance> _activeTasks = {};
  final Map<String, TaskInstance> _completedTasks = {};
  final Map<String, Timer> _scheduledTasks = {};

  var _state = const TaskExecutorState();
  bool _isDisposed = false;

  /// 当前状态
  TaskExecutorState get state => _state;

  /// 任务状态变更流
  final _stateController = StreamController<TaskExecutorState>.broadcast();
  Stream<TaskExecutorState> get stateStream => _stateController.stream;

  /// 任务事件流
  final _taskEventController = StreamController<TaskEvent>.broadcast();
  Stream<TaskEvent> get taskEventStream => _taskEventController.stream;

  /// 提交任务
  Future<AppResult<String>> submitTask(BackgroundTask task, {
    TaskPriority? priority,
    Duration? delay,
    Map<String, dynamic>? metadata,
  }) async {
    if (_isDisposed) {
      return AppResult.failure(
        const TaskExecutionException('Task executor is disposed'),
      );
    }

    final taskId = _generateTaskId();
    final now = DateTime.now();
    final scheduledAt = delay != null ? now.add(delay) : now;

    final instance = TaskInstance(
      task: task,
      id: taskId,
      createdAt: now,
      scheduledAt: scheduledAt,
      priority: priority,
      metadata: metadata ?? {},
      cancellationToken: CancellationToken(),
    );

    if (delay != null) {
      // 延迟执行
      _scheduleTask(instance, delay);
    } else {
      // 立即加入队列
      if (!_taskQueue.enqueue(instance)) {
        return AppResult.failure(
          const TaskExecutionException('Task queue is full'),
        );
      }
      _processQueue();
    }

    _updateState();
    _emitTaskEvent(TaskEvent.created(taskId, task.name));

    return AppResult.success(taskId);
  }

  /// 取消任务
  Future<AppResult<void>> cancelTask(String taskId, [String? reason]) async {
    if (_isDisposed) {
      return AppResult.failure(
        const TaskExecutionException('Task executor is disposed'),
      );
    }

    // 检查活动任务
    final activeTask = _activeTasks[taskId];
    if (activeTask != null) {
      activeTask.cancellationToken?.cancel(reason);
      activeTask.status = TaskStatus.cancelled;
      _activeTasks.remove(taskId);
      _completedTasks[taskId] = activeTask;
      _updateState();
      _emitTaskEvent(TaskEvent.cancelled(taskId, reason ?? 'Cancelled'));
      return AppResult.success(null);
    }

    // 检查队列中的任务
    final queuedTask = _taskQueue.getTask(taskId);
    if (queuedTask != null) {
      queuedTask.status = TaskStatus.cancelled;
      _taskQueue.remove(taskId);
      _completedTasks[taskId] = queuedTask;
      _updateState();
      _emitTaskEvent(TaskEvent.cancelled(taskId, reason ?? 'Cancelled'));
      return AppResult.success(null);
    }

    // 检查计划任务
    final scheduledTimer = _scheduledTasks[taskId];
          if (scheduledTimer != null) {
        scheduledTimer.cancel();
        _scheduledTasks.remove(taskId);
        _emitTaskEvent(TaskEvent.cancelled(taskId, reason ?? 'Cancelled'));
        return AppResult.success(null);
      }

    return AppResult.failure(
      const TaskExecutionException('Task not found'),
    );
  }

  /// 获取任务状态
  TaskInstance? getTask(String taskId) {
    return _activeTasks[taskId] ?? 
           _taskQueue.getTask(taskId) ?? 
           _completedTasks[taskId];
  }

  /// 获取所有任务
  List<TaskInstance> getAllTasks() {
    final tasks = <TaskInstance>[];
    tasks.addAll(_activeTasks.values);
    tasks.addAll(_taskQueue.allTasks);
    tasks.addAll(_completedTasks.values);
    return tasks;
  }

  /// 等待任务完成
  Future<AppResult<dynamic>> waitForTask(String taskId, {Duration? timeout}) async {
    final task = getTask(taskId);
    if (task == null) {
      return AppResult.failure(
        const TaskExecutionException('Task not found'),
      );
    }

    if (task.isCompleted) {
      return task.result ?? AppResult.failure(BusinessError(task.error?.toString() ?? 'Unknown error'));
    }

    final completer = Completer<AppResult<dynamic>>();
    late StreamSubscription subscription;

    subscription = taskEventStream.listen((event) {
      if (event.taskId == taskId) {
        if (event.type == TaskEventType.completed) {
          final completedTask = getTask(taskId);
          subscription.cancel();
          completer.complete(
            completedTask?.result ?? AppResult.success(null),
          );
        } else if (event.type == TaskEventType.failed) {
          final failedTask = getTask(taskId);
          subscription.cancel();
          completer.complete(
            AppResult.failure(BusinessError(failedTask?.error?.toString() ?? 'Unknown error')),
          );
        } else if (event.type == TaskEventType.cancelled) {
          subscription.cancel();
          completer.complete(
            AppResult.failure(const TaskCancelledException(null)),
          );
        }
      }
    });

    if (timeout != null) {
      Timer(timeout, () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(
            AppResult.failure(const TaskExecutionException('Task timeout')),
          );
        }
      });
    }

    return completer.future;
  }

  /// 处理任务队列
  void _processQueue() {
    while (_activeTasks.length < maxConcurrentTasks && _taskQueue.isNotEmpty) {
      final task = _taskQueue.dequeue();
      if (task != null) {
        _executeTask(task);
      }
    }
  }

  /// 执行任务
  Future<void> _executeTask(TaskInstance instance) async {
    if (_isDisposed) return;

    instance.status = TaskStatus.running;
    instance.startedAt = DateTime.now();
    _activeTasks[instance.id] = instance;
    _updateState();
    _emitTaskEvent(TaskEvent.started(instance.id, instance.task.name));

    try {
      // 创建执行上下文
      final context = TaskExecutionContext(
        taskId: instance.id,
        attempt: instance.attempt + 1,
        startTime: instance.startedAt!,
        metadata: instance.metadata,
        cancellationToken: instance.cancellationToken,
      );

      // 检查执行条件
      if (!await instance.task.canExecute(context)) {
        throw const TaskExecutionException('Task execution conditions not met');
      }

      // 执行任务
      final result = await instance.task.execute(context).timeout(
        instance.task.timeout,
        onTimeout: () => AppResult.failure(
          const TaskExecutionException('Task execution timeout'),
        ),
      );

      // 任务完成
      instance.result = result;
      instance.status = result.isSuccess ? TaskStatus.completed : TaskStatus.failed;
      instance.completedAt = DateTime.now();
      instance.error = result.isFailure ? result.errorOrNull : null;

      if (result.isSuccess) {
        _emitTaskEvent(TaskEvent.completed(instance.id, instance.task.name));
      } else {
        await instance.task.onFailure(context, result.errorOrNull);
        
        if (instance.canRetry) {
          _scheduleRetry(instance);
          return;
        } else {
          _emitTaskEvent(TaskEvent.failed(instance.id, instance.task.name, result.errorOrNull));
        }
      }
    } catch (error, stackTrace) {
      instance.error = error;
      instance.status = TaskStatus.failed;
      instance.completedAt = DateTime.now();

      final context = TaskExecutionContext(
        taskId: instance.id,
        attempt: instance.attempt + 1,
        startTime: instance.startedAt!,
        metadata: instance.metadata,
        cancellationToken: instance.cancellationToken,
      );

      await instance.task.onFailure(context, error);

      if (instance.canRetry) {
        _scheduleRetry(instance);
        return;
      } else {
        _emitTaskEvent(TaskEvent.failed(instance.id, instance.task.name, error));
      }
    } finally {
      // 清理
      try {
        final context = TaskExecutionContext(
          taskId: instance.id,
          attempt: instance.attempt + 1,
          startTime: instance.startedAt!,
          metadata: instance.metadata,
          cancellationToken: instance.cancellationToken,
        );
        await instance.task.cleanup(context);
      } catch (e) {
        debugPrint('Error in task cleanup: $e');
      }

      // 移动到完成列表
      _activeTasks.remove(instance.id);
      _completedTasks[instance.id] = instance;
      _updateState();

      // 处理下一个任务
      _processQueue();
    }
  }

  /// 调度任务
  void _scheduleTask(TaskInstance instance, Duration delay) {
    final timer = Timer(delay, () {
      _scheduledTasks.remove(instance.id);
      if (!_taskQueue.enqueue(instance)) {
        instance.status = TaskStatus.failed;
        instance.error = 'Task queue is full';
        _completedTasks[instance.id] = instance;
        _emitTaskEvent(TaskEvent.failed(instance.id, instance.task.name, instance.error));
      } else {
        _processQueue();
      }
    });
    _scheduledTasks[instance.id] = timer;
  }

  /// 调度重试
  void _scheduleRetry(TaskInstance instance) {
    instance.status = TaskStatus.retrying;
    instance.attempt++;
    _emitTaskEvent(TaskEvent.retrying(instance.id, instance.task.name, instance.attempt));

    Duration delay;
    switch (instance.task.retryStrategy) {
      case TaskRetryStrategy.none:
        return;
      case TaskRetryStrategy.fixed:
        delay = instance.task.retryDelay;
      case TaskRetryStrategy.exponentialBackoff:
        delay = Duration(
          milliseconds: (instance.task.retryDelay.inMilliseconds * 
                        pow(2, instance.attempt - 1)).round(),
        );
      case TaskRetryStrategy.custom:
        delay = instance.task.retryDelay;
    }

    _scheduleTask(instance, delay);
  }

  /// 更新状态
  void _updateState() {
    final executionTimes = _completedTasks.values
        .where((task) => task.executionTime != null)
        .map((task) => task.executionTime!)
        .toList();

    final averageExecutionTime = executionTimes.isNotEmpty
        ? Duration(
            milliseconds: executionTimes
                .map((d) => d.inMilliseconds)
                .reduce((a, b) => a + b) ~/
                executionTimes.length,
          )
        : Duration.zero;

    _state = TaskExecutorState(
      isRunning: _activeTasks.isNotEmpty,
      activeTaskCount: _activeTasks.length,
      completedTaskCount: _completedTasks.values
          .where((task) => task.status == TaskStatus.completed)
          .length,
      failedTaskCount: _completedTasks.values
          .where((task) => task.status == TaskStatus.failed)
          .length,
      totalTaskCount: _completedTasks.length,
      averageExecutionTime: averageExecutionTime,
    );

    _stateController.add(_state);
  }

  /// 发送任务事件
  void _emitTaskEvent(TaskEvent event) {
    _taskEventController.add(event);
    eventBus?.emit(event);
  }

  /// 生成任务ID
  String _generateTaskId() {
    return 'task_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  /// 关闭执行器
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    // 取消所有活动任务
    for (final task in _activeTasks.values) {
      task.cancellationToken?.cancel('Executor disposed');
    }

    // 取消所有计划任务
    for (final timer in _scheduledTasks.values) {
      timer.cancel();
    }

    // 清理资源
    _taskQueue.clear();
    _activeTasks.clear();
    _scheduledTasks.clear();

    await _stateController.close();
    await _taskEventController.close();
  }
}

/// 任务事件类型
enum TaskEventType {
  created,
  started,
  completed,
  failed,
  cancelled,
  retrying,
}

/// 任务事件
class TaskEvent extends AppEvent {
  const TaskEvent({
    required this.type,
    required this.taskId,
    required this.taskName,
    this.attempt,
    this.error,
    this.reason,
    DateTime? timestamp,
  }) : super(timestamp: timestamp);

  final TaskEventType type;
  final String taskId;
  final String taskName;
  final int? attempt;
  final dynamic error;
  final String? reason;

  factory TaskEvent.created(String taskId, String taskName) {
    return TaskEvent(
      type: TaskEventType.created,
      taskId: taskId,
      taskName: taskName,
    );
  }

  factory TaskEvent.started(String taskId, String taskName) {
    return TaskEvent(
      type: TaskEventType.started,
      taskId: taskId,
      taskName: taskName,
    );
  }

  factory TaskEvent.completed(String taskId, String taskName) {
    return TaskEvent(
      type: TaskEventType.completed,
      taskId: taskId,
      taskName: taskName,
    );
  }

  factory TaskEvent.failed(String taskId, String taskName, dynamic error) {
    return TaskEvent(
      type: TaskEventType.failed,
      taskId: taskId,
      taskName: taskName,
      error: error,
    );
  }

  factory TaskEvent.cancelled(String taskId, String taskName, [String? reason]) {
    return TaskEvent(
      type: TaskEventType.cancelled,
      taskId: taskId,
      taskName: taskName,
      reason: reason,
    );
  }

  factory TaskEvent.retrying(String taskId, String taskName, int attempt) {
    return TaskEvent(
      type: TaskEventType.retrying,
      taskId: taskId,
      taskName: taskName,
      attempt: attempt,
    );
  }

  @override
  String toString() {
    return 'TaskEvent(type: $type, taskId: $taskId, taskName: $taskName)';
  }
} 