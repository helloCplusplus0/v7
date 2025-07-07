// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../types/result.dart';
import '../events/events.dart';
import '../storage/local_storage.dart';
import '../database/database.dart';
import 'sync_manager.dart';

/// 离线操作类型枚举
enum OfflineOperationType {
  create,   // 创建操作
  update,   // 更新操作
  delete,   // 删除操作
  upload,   // 上传操作
  sync,     // 同步操作
}

/// 操作优先级枚举
enum OperationPriority {
  low,      // 低优先级
  normal,   // 普通优先级
  high,     // 高优先级
  critical, // 紧急优先级
}

/// 操作状态枚举
enum OperationStatus {
  pending,    // 等待执行
  executing,  // 执行中
  completed,  // 已完成
  failed,     // 执行失败
  cancelled,  // 已取消
  retrying,   // 重试中
}

/// 离线操作类
@immutable
class OfflineOperation {
  OfflineOperation({
    required this.id,
    required this.type,
    required this.entityType,
    required this.data,
    this.entityId,
    this.priority = OperationPriority.normal,
    this.status = OperationStatus.pending,
    DateTime? createdAt,
    this.updatedAt,
    this.scheduledAt,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 5),
    this.dependencies = const [],
    this.metadata = const {},
    this.errorMessage,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final OfflineOperationType type;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic> data;
  final OperationPriority priority;
  final OperationStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? scheduledAt;
  final int retryCount;
  final int maxRetries;
  final Duration retryDelay;
  final List<String> dependencies;
  final Map<String, dynamic> metadata;
  final String? errorMessage;

  /// 是否可以执行
  bool get canExecute => 
      status == OperationStatus.pending || 
      (status == OperationStatus.failed && retryCount < maxRetries);

  /// 是否需要重试
  bool get needsRetry => 
      status == OperationStatus.failed && retryCount < maxRetries;

  /// 是否已完成
  bool get isCompleted => status == OperationStatus.completed;

  /// 是否已失败
  bool get isFailed => status == OperationStatus.failed && retryCount >= maxRetries;

  /// 是否可以取消
  bool get canCancel => status == OperationStatus.pending;

  /// 优先级数值（用于排序）
  int get priorityValue {
    switch (priority) {
      case OperationPriority.critical:
        return 4;
      case OperationPriority.high:
        return 3;
      case OperationPriority.normal:
        return 2;
      case OperationPriority.low:
        return 1;
    }
  }

  OfflineOperation copyWith({
    String? id,
    OfflineOperationType? type,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? data,
    OperationPriority? priority,
    OperationStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? scheduledAt,
    int? retryCount,
    int? maxRetries,
    Duration? retryDelay,
    List<String>? dependencies,
    Map<String, dynamic>? metadata,
    String? errorMessage,
  }) {
    return OfflineOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      data: data ?? this.data,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      dependencies: dependencies ?? this.dependencies,
      metadata: metadata ?? this.metadata,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'entity_type': entityType,
    'entity_id': entityId,
    'data': data,
    'priority': priority.name,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'scheduled_at': scheduledAt?.toIso8601String(),
    'retry_count': retryCount,
    'max_retries': maxRetries,
    'retry_delay_ms': retryDelay.inMilliseconds,
    'dependencies': dependencies,
    'metadata': metadata,
    'error_message': errorMessage,
  };

  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'] as String,
      type: OfflineOperationType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      data: Map<String, dynamic>.from(json['data'] as Map),
      priority: OperationPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => OperationPriority.normal,
      ),
      status: OperationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => OperationStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      retryCount: json['retry_count'] as int? ?? 0,
      maxRetries: json['max_retries'] as int? ?? 3,
      retryDelay: Duration(milliseconds: json['retry_delay_ms'] as int? ?? 5000),
      dependencies: List<String>.from(json['dependencies'] as List? ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      errorMessage: json['error_message'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfflineOperation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'OfflineOperation(id: $id, type: $type, status: $status)';
}

/// 队列配置类
@immutable
class QueueConfig {
  const QueueConfig({
    this.maxConcurrentOperations = 3,
    this.maxQueueSize = 1000,
    this.defaultRetryAttempts = 3,
    this.defaultRetryDelay = const Duration(seconds: 5),
    this.processingInterval = const Duration(seconds: 1),
    this.persistenceEnabled = true,
    this.compressionEnabled = false,
    this.encryptionEnabled = false,
    this.retryBackoffMultiplier = 2.0,
    this.maxRetryDelay = const Duration(minutes: 5),
    this.enableMetrics = true,
    this.autoStart = true,
  });

  final int maxConcurrentOperations;
  final int maxQueueSize;
  final int defaultRetryAttempts;
  final Duration defaultRetryDelay;
  final Duration processingInterval;
  final bool persistenceEnabled;
  final bool compressionEnabled;
  final bool encryptionEnabled;
  final double retryBackoffMultiplier;
  final Duration maxRetryDelay;
  final bool enableMetrics;
  final bool autoStart;

  QueueConfig copyWith({
    int? maxConcurrentOperations,
    int? maxQueueSize,
    int? defaultRetryAttempts,
    Duration? defaultRetryDelay,
    Duration? processingInterval,
    bool? persistenceEnabled,
    bool? compressionEnabled,
    bool? encryptionEnabled,
    double? retryBackoffMultiplier,
    Duration? maxRetryDelay,
    bool? enableMetrics,
    bool? autoStart,
  }) {
    return QueueConfig(
      maxConcurrentOperations: maxConcurrentOperations ?? this.maxConcurrentOperations,
      maxQueueSize: maxQueueSize ?? this.maxQueueSize,
      defaultRetryAttempts: defaultRetryAttempts ?? this.defaultRetryAttempts,
      defaultRetryDelay: defaultRetryDelay ?? this.defaultRetryDelay,
      processingInterval: processingInterval ?? this.processingInterval,
      persistenceEnabled: persistenceEnabled ?? this.persistenceEnabled,
      compressionEnabled: compressionEnabled ?? this.compressionEnabled,
      encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
      retryBackoffMultiplier: retryBackoffMultiplier ?? this.retryBackoffMultiplier,
      maxRetryDelay: maxRetryDelay ?? this.maxRetryDelay,
      enableMetrics: enableMetrics ?? this.enableMetrics,
      autoStart: autoStart ?? this.autoStart,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueueConfig &&
        other.maxConcurrentOperations == maxConcurrentOperations &&
        other.maxQueueSize == maxQueueSize &&
        other.defaultRetryAttempts == defaultRetryAttempts &&
        other.defaultRetryDelay == defaultRetryDelay &&
        other.processingInterval == processingInterval &&
        other.persistenceEnabled == persistenceEnabled &&
        other.compressionEnabled == compressionEnabled &&
        other.encryptionEnabled == encryptionEnabled &&
        other.retryBackoffMultiplier == retryBackoffMultiplier &&
        other.maxRetryDelay == maxRetryDelay &&
        other.enableMetrics == enableMetrics &&
        other.autoStart == autoStart;
  }

  @override
  int get hashCode {
    return Object.hash(
      maxConcurrentOperations,
      maxQueueSize,
      defaultRetryAttempts,
      defaultRetryDelay,
      processingInterval,
      persistenceEnabled,
      compressionEnabled,
      encryptionEnabled,
      retryBackoffMultiplier,
      maxRetryDelay,
      enableMetrics,
      autoStart,
    );
  }
}

/// 队列状态类
@immutable
class QueueState {
  const QueueState({
    this.isRunning = false,
    this.totalOperations = 0,
    this.pendingOperations = 0,
    this.executingOperations = 0,
    this.completedOperations = 0,
    this.failedOperations = 0,
    this.retryingOperations = 0,
    this.lastProcessedAt,
    this.lastError,
    this.averageProcessingTime = Duration.zero,
    this.throughput = 0.0,
  });

  final bool isRunning;
  final int totalOperations;
  final int pendingOperations;
  final int executingOperations;
  final int completedOperations;
  final int failedOperations;
  final int retryingOperations;
  final DateTime? lastProcessedAt;
  final String? lastError;
  final Duration averageProcessingTime;
  final double throughput; // 操作数/秒

  bool get hasOperations => totalOperations > 0;
  bool get hasErrors => lastError != null;
  double get successRate => totalOperations > 0 
      ? completedOperations / totalOperations 
      : 0.0;

  QueueState copyWith({
    bool? isRunning,
    int? totalOperations,
    int? pendingOperations,
    int? executingOperations,
    int? completedOperations,
    int? failedOperations,
    int? retryingOperations,
    DateTime? lastProcessedAt,
    String? lastError,
    Duration? averageProcessingTime,
    double? throughput,
  }) {
    return QueueState(
      isRunning: isRunning ?? this.isRunning,
      totalOperations: totalOperations ?? this.totalOperations,
      pendingOperations: pendingOperations ?? this.pendingOperations,
      executingOperations: executingOperations ?? this.executingOperations,
      completedOperations: completedOperations ?? this.completedOperations,
      failedOperations: failedOperations ?? this.failedOperations,
      retryingOperations: retryingOperations ?? this.retryingOperations,
      lastProcessedAt: lastProcessedAt ?? this.lastProcessedAt,
      lastError: lastError ?? this.lastError,
      averageProcessingTime: averageProcessingTime ?? this.averageProcessingTime,
      throughput: throughput ?? this.throughput,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueueState &&
        other.isRunning == isRunning &&
        other.totalOperations == totalOperations &&
        other.pendingOperations == pendingOperations &&
        other.executingOperations == executingOperations &&
        other.completedOperations == completedOperations &&
        other.failedOperations == failedOperations &&
        other.retryingOperations == retryingOperations &&
        other.lastProcessedAt == lastProcessedAt &&
        other.lastError == lastError &&
        other.averageProcessingTime == averageProcessingTime &&
        other.throughput == throughput;
  }

  @override
  int get hashCode {
    return Object.hash(
      isRunning,
      totalOperations,
      pendingOperations,
      executingOperations,
      completedOperations,
      failedOperations,
      retryingOperations,
      lastProcessedAt,
      lastError,
      averageProcessingTime,
      throughput,
    );
  }
}

/// 操作执行器接口
abstract class OperationExecutor {
  /// 执行器类型
  String get type;
  
  /// 是否支持指定的操作类型
  bool supports(OfflineOperationType operationType, String entityType);
  
  /// 执行操作
  Future<Result<void, String>> execute(OfflineOperation operation);
  
  /// 估算执行时间
  Duration estimateExecutionTime(OfflineOperation operation);
  
  /// 检查操作是否可以执行
  Future<bool> canExecute(OfflineOperation operation);
}

/// 离线操作队列接口
abstract class IOfflineQueue {
  /// 队列状态流
  Stream<QueueState> get stateStream;
  
  /// 当前队列状态
  QueueState get currentState;
  
  /// 队列配置
  QueueConfig get config;
  
  /// 添加操作到队列
  Future<Result<String, String>> enqueue(OfflineOperation operation);
  
  /// 批量添加操作
  Future<Result<List<String>, String>> enqueueBatch(List<OfflineOperation> operations);
  
  /// 从队列移除操作
  Future<Result<void, String>> dequeue(String operationId);
  
  /// 获取操作详情
  Future<Result<OfflineOperation?, String>> getOperation(String operationId);
  
  /// 获取队列中的所有操作
  Future<Result<List<OfflineOperation>, String>> getAllOperations();
  
  /// 获取指定状态的操作
  Future<Result<List<OfflineOperation>, String>> getOperationsByStatus(
    OperationStatus status,
  );
  
  /// 获取指定类型的操作
  Future<Result<List<OfflineOperation>, String>> getOperationsByType(
    String entityType,
  );
  
  /// 启动队列处理
  Future<Result<void, String>> start();
  
  /// 停止队列处理
  Future<Result<void, String>> stop();
  
  /// 暂停队列处理
  Future<Result<void, String>> pause();
  
  /// 恢复队列处理
  Future<Result<void, String>> resume();
  
  /// 清空队列
  Future<Result<void, String>> clear();
  
  /// 重试失败的操作
  Future<Result<void, String>> retryOperation(String operationId);
  
  /// 重试所有失败的操作
  Future<Result<void, String>> retryAllFailed();
  
  /// 取消操作
  Future<Result<void, String>> cancelOperation(String operationId);
  
  /// 更新队列配置
  Future<Result<void, String>> updateConfig(QueueConfig config);
  
  /// 注册操作执行器
  void registerExecutor(OperationExecutor executor);
  
  /// 注销操作执行器
  void unregisterExecutor(String type);
  
  /// 释放资源
  Future<void> dispose();
}

/// 离线操作队列实现
class OfflineQueue implements IOfflineQueue {
  OfflineQueue({
    QueueConfig? config,
    LocalStorage? storage,
    Database? database,
  }) : _config = config ?? const QueueConfig(),
       _storage = storage,
       _database = database {
    _initialize();
  }

  QueueConfig _config;
  @override
  QueueConfig get config => _config;

  final LocalStorage? _storage;
  final Database? _database;
  
  final Map<String, OfflineOperation> _operations = {};
  final Map<String, OperationExecutor> _executors = {};
  final Set<String> _executingOperations = {};
  
  final StreamController<QueueState> _stateController = 
      StreamController<QueueState>.broadcast();
  
  Timer? _processingTimer;
  QueueState _currentState = const QueueState();
  bool _isPaused = false;
  
  final List<Duration> _processingTimes = [];
  DateTime? _startTime;

  @override
  Stream<QueueState> get stateStream => _stateController.stream;

  @override
  QueueState get currentState => _currentState;

  /// 初始化队列
  void _initialize() {
    _loadPersistedOperations();
    
    if (_config.autoStart) {
      start();
    }
  }

  /// 加载持久化的操作
  Future<void> _loadPersistedOperations() async {
    if (!_config.persistenceEnabled || _storage == null) return;
    
    try {
      final result = await _storage!.getString('offline_queue_operations');
      if (result.isSuccess) {
        final data = result.valueOrNull;
        if (data != null) {
          final dynamic decodedData = jsonDecode(data);
          if (decodedData is List) {
            for (final opJson in decodedData) {
              final operation = OfflineOperation.fromJson(opJson as Map<String, dynamic>);
              _operations[operation.id] = operation;
            }
          }
          
          debugPrint('Loaded ${_operations.length} persisted operations');
          _updateState();
        }
      }
    } catch (e) {
      debugPrint('Failed to load persisted operations: $e');
    }
  }

  /// 持久化操作到存储
  Future<void> _persistOperations() async {
    if (!_config.persistenceEnabled || _storage == null) return;
    
    try {
      final operationsJson = _operations.values
          .map((op) => op.toJson())
          .toList();
      
      final result = await _storage!.setString(
        'offline_queue_operations', 
        jsonEncode(operationsJson),
      );
      
      if (!result.isSuccess) {
        debugPrint('Failed to persist operations: ${result.errorOrNull}');
      }
    } catch (e) {
      debugPrint('Error persisting operations: $e');
    }
  }

  @override
  Future<Result<String, String>> enqueue(OfflineOperation operation) async {
    if (_operations.length >= _config.maxQueueSize) {
      return Result.failure('Queue is full (max: ${_config.maxQueueSize})');
    }

    // 检查依赖关系
    for (final dependency in operation.dependencies) {
      if (!_operations.containsKey(dependency)) {
        return Result.failure('Dependency operation not found: $dependency');
      }
    }

    _operations[operation.id] = operation;
    await _persistOperations();
    _updateState();
    
    debugPrint('Enqueued operation: ${operation.id} (${operation.type})');
    
    return Result.success(operation.id);
  }

  @override
  Future<Result<List<String>, String>> enqueueBatch(
    List<OfflineOperation> operations,
  ) async {
    if (_operations.length + operations.length > _config.maxQueueSize) {
      return Result.failure(
        'Batch would exceed queue size limit (${_config.maxQueueSize})',
      );
    }

    final operationIds = <String>[];
    
    for (final operation in operations) {
      // 检查依赖关系
      for (final dependency in operation.dependencies) {
        if (!_operations.containsKey(dependency) && 
            !operations.any((op) => op.id == dependency)) {
          return Result.failure(
            'Dependency operation not found: $dependency for ${operation.id}',
          );
        }
      }
      
      _operations[operation.id] = operation;
      operationIds.add(operation.id);
    }
    
    await _persistOperations();
    _updateState();
    
    debugPrint('Enqueued batch: ${operationIds.length} operations');
    
    return Result.success(operationIds);
  }

  @override
  Future<Result<void, String>> dequeue(String operationId) async {
    final operation = _operations[operationId];
    if (operation == null) {
      return Result.failure('Operation not found: $operationId');
    }

    if (operation.status == OperationStatus.executing) {
      return Result.failure('Cannot dequeue executing operation: $operationId');
    }

    _operations.remove(operationId);
    await _persistOperations();
    _updateState();
    
    debugPrint('Dequeued operation: $operationId');
    
    return Result.success(null);
  }

  @override
  Future<Result<OfflineOperation?, String>> getOperation(String operationId) async {
    return Result.success(_operations[operationId]);
  }

  @override
  Future<Result<List<OfflineOperation>, String>> getAllOperations() async {
    final sortedOperations = _operations.values.toList()
      ..sort(_compareOperations);
    
    return Result.success(sortedOperations);
  }

  @override
  Future<Result<List<OfflineOperation>, String>> getOperationsByStatus(
    OperationStatus status,
  ) async {
    final filteredOperations = _operations.values
        .where((op) => op.status == status)
        .toList()
      ..sort(_compareOperations);
    
    return Result.success(filteredOperations);
  }

  @override
  Future<Result<List<OfflineOperation>, String>> getOperationsByType(
    String entityType,
  ) async {
    final filteredOperations = _operations.values
        .where((op) => op.entityType == entityType)
        .toList()
      ..sort(_compareOperations);
    
    return Result.success(filteredOperations);
  }

  @override
  Future<Result<void, String>> start() async {
    if (_currentState.isRunning) {
      return Result.failure('Queue is already running');
    }

    _isPaused = false;
    _startTime = DateTime.now();
    
    _processingTimer = Timer.periodic(_config.processingInterval, (_) {
      if (!_isPaused) {
        _processQueue();
      }
    });

    _updateState(_currentState.copyWith(isRunning: true));
    
    debugPrint('Offline queue started');
    
    return Result.success(null);
  }

  @override
  Future<Result<void, String>> stop() async {
    _processingTimer?.cancel();
    _processingTimer = null;
    _isPaused = false;
    
    // 等待正在执行的操作完成
    while (_executingOperations.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _updateState(_currentState.copyWith(isRunning: false));
    
    debugPrint('Offline queue stopped');
    
    return Result.success(null);
  }

  @override
  Future<Result<void, String>> pause() async {
    if (!_currentState.isRunning) {
      return Result.failure('Queue is not running');
    }

    _isPaused = true;
    
    debugPrint('Offline queue paused');
    
    return Result.success(null);
  }

  @override
  Future<Result<void, String>> resume() async {
    if (!_currentState.isRunning) {
      return Result.failure('Queue is not running');
    }

    _isPaused = false;
    
    debugPrint('Offline queue resumed');
    
    return Result.success(null);
  }

  @override
  Future<Result<void, String>> clear() async {
    // 不能清除正在执行的操作
    final executingCount = _operations.values
        .where((op) => op.status == OperationStatus.executing)
        .length;
    
    if (executingCount > 0) {
      return Result.failure('Cannot clear queue with executing operations');
    }

    _operations.clear();
    await _persistOperations();
    _updateState();
    
    debugPrint('Offline queue cleared');
    
    return Result.success(null);
  }

  @override
  Future<Result<void, String>> retryOperation(String operationId) async {
    final operation = _operations[operationId];
    if (operation == null) {
      return Result.failure('Operation not found: $operationId');
    }

    if (!operation.needsRetry) {
      return Result.failure('Operation does not need retry: $operationId');
    }

    final retried = operation.copyWith(
      status: OperationStatus.pending,
      updatedAt: DateTime.now(),
    );

    _operations[operationId] = retried;
    await _persistOperations();
    _updateState();
    
    debugPrint('Retry scheduled for operation: $operationId');
    
    return Result.success(null);
  }

  @override
  Future<Result<void, String>> retryAllFailed() async {
    final failedOperations = _operations.values
        .where((op) => op.needsRetry)
        .toList();

    for (final operation in failedOperations) {
      final retried = operation.copyWith(
        status: OperationStatus.pending,
        updatedAt: DateTime.now(),
      );
      _operations[operation.id] = retried;
    }

    await _persistOperations();
    _updateState();
    
    debugPrint('Retry scheduled for ${failedOperations.length} failed operations');
    
    return Result.success(null);
  }

  @override
  Future<Result<void, String>> cancelOperation(String operationId) async {
    final operation = _operations[operationId];
    if (operation == null) {
      return Result.failure('Operation not found: $operationId');
    }

    if (!operation.canCancel) {
      return Result.failure('Operation cannot be cancelled: $operationId');
    }

    final cancelled = operation.copyWith(
      status: OperationStatus.cancelled,
      updatedAt: DateTime.now(),
    );

    _operations[operationId] = cancelled;
    await _persistOperations();
    _updateState();
    
    debugPrint('Cancelled operation: $operationId');
    
    return Result.success(null);
  }

  @override
  Future<Result<void, String>> updateConfig(QueueConfig config) async {
    _config = config;
    
    // 重启处理定时器如果配置改变
    if (_currentState.isRunning) {
      _processingTimer?.cancel();
      _processingTimer = Timer.periodic(_config.processingInterval, (_) {
        if (!_isPaused) {
          _processQueue();
        }
      });
    }
    
    return Result.success(null);
  }

  @override
  void registerExecutor(OperationExecutor executor) {
    _executors[executor.type] = executor;
    debugPrint('Registered operation executor: ${executor.type}');
  }

  @override
  void unregisterExecutor(String type) {
    _executors.remove(type);
    debugPrint('Unregistered operation executor: $type');
  }

  /// 处理队列
  Future<void> _processQueue() async {
    if (_executingOperations.length >= _config.maxConcurrentOperations) {
      return; // 已达到最大并发限制
    }

    final readyOperations = _getReadyOperations();
    if (readyOperations.isEmpty) {
      return; // 没有可执行的操作
    }

    final availableSlots = _config.maxConcurrentOperations - _executingOperations.length;
    final operationsToExecute = readyOperations.take(availableSlots).toList();

    for (final operation in operationsToExecute) {
      _executeOperation(operation);
    }
  }

  /// 获取可执行的操作
  List<OfflineOperation> _getReadyOperations() {
    final now = DateTime.now();
    
    return _operations.values
        .where((op) => _canExecuteOperation(op, now))
        .toList()
      ..sort(_compareOperations);
  }

  /// 检查操作是否可以执行
  bool _canExecuteOperation(OfflineOperation operation, DateTime now) {
    // 基本条件检查
    if (!operation.canExecute) return false;
    if (_executingOperations.contains(operation.id)) return false;

    // 检查调度时间
    if (operation.scheduledAt != null && now.isBefore(operation.scheduledAt!)) {
      return false;
    }

    // 检查依赖关系
    for (final dependencyId in operation.dependencies) {
      final dependency = _operations[dependencyId];
      if (dependency == null || !dependency.isCompleted) {
        return false;
      }
    }

    // 检查是否有合适的执行器
    final executor = _findExecutor(operation);
    return executor != null;
  }

  /// 查找操作执行器
  OperationExecutor? _findExecutor(OfflineOperation operation) {
    for (final executor in _executors.values) {
      if (executor.supports(operation.type, operation.entityType)) {
        return executor;
      }
    }
    return null;
  }

  /// 执行操作
  Future<void> _executeOperation(OfflineOperation operation) async {
    final executor = _findExecutor(operation);
    if (executor == null) {
      _markOperationFailed(operation, 'No suitable executor found');
      return;
    }

    _executingOperations.add(operation.id);
    
    final executing = operation.copyWith(
      status: OperationStatus.executing,
      updatedAt: DateTime.now(),
    );
    _operations[operation.id] = executing;
    _updateState();

    final startTime = DateTime.now();
    
    try {
      final result = await executor.execute(operation);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      _processingTimes.add(duration);
      if (_processingTimes.length > 100) {
        _processingTimes.removeAt(0); // 保持最近100次的记录
      }

      if (result.isSuccess) {
        _markOperationCompleted(operation);
      } else {
        _markOperationFailed(operation, result.errorOrNull ?? 'Unknown error');
      }
    } catch (e) {
      _markOperationFailed(operation, e.toString());
    } finally {
      _executingOperations.remove(operation.id);
      await _persistOperations();
      _updateState();
    }
  }

  /// 标记操作为完成
  void _markOperationCompleted(OfflineOperation operation) {
    final completed = operation.copyWith(
      status: OperationStatus.completed,
      updatedAt: DateTime.now(),
    );
    _operations[operation.id] = completed;
    
    debugPrint('Operation completed: ${operation.id}');
  }

  /// 标记操作为失败
  void _markOperationFailed(OfflineOperation operation, String error) {
    final status = operation.retryCount < operation.maxRetries
        ? OperationStatus.failed
        : OperationStatus.failed;
        
    final nextRetryDelay = _calculateRetryDelay(operation);
    
    final failed = operation.copyWith(
      status: status,
      retryCount: operation.retryCount + 1,
      errorMessage: error,
      scheduledAt: operation.retryCount < operation.maxRetries
          ? DateTime.now().add(nextRetryDelay)
          : null,
      updatedAt: DateTime.now(),
    );
    
    _operations[operation.id] = failed;
    
    debugPrint('Operation failed: ${operation.id}, retry: ${failed.retryCount}/${operation.maxRetries}');
  }

  /// 计算重试延迟
  Duration _calculateRetryDelay(OfflineOperation operation) {
    final baseDelay = operation.retryDelay;
    final backoffDelay = Duration(
      milliseconds: (baseDelay.inMilliseconds * 
          math.pow(_config.retryBackoffMultiplier, operation.retryCount)).round(),
    );
    
    return backoffDelay > _config.maxRetryDelay 
        ? _config.maxRetryDelay 
        : backoffDelay;
  }

  /// 比较操作（用于排序）
  int _compareOperations(OfflineOperation a, OfflineOperation b) {
    // 1. 优先级排序
    final priorityComparison = b.priorityValue.compareTo(a.priorityValue);
    if (priorityComparison != 0) return priorityComparison;
    
    // 2. 创建时间排序
    return a.createdAt.compareTo(b.createdAt);
  }

  /// 更新状态
  void _updateState([QueueState? newState]) {
    final operations = _operations.values;
    final now = DateTime.now();
    
    _currentState = newState ?? QueueState(
      isRunning: _currentState.isRunning,
      totalOperations: operations.length,
      pendingOperations: operations.where((op) => op.status == OperationStatus.pending).length,
      executingOperations: operations.where((op) => op.status == OperationStatus.executing).length,
      completedOperations: operations.where((op) => op.status == OperationStatus.completed).length,
      failedOperations: operations.where((op) => op.status == OperationStatus.failed).length,
      retryingOperations: operations.where((op) => op.status == OperationStatus.retrying).length,
      lastProcessedAt: operations.any((op) => op.status == OperationStatus.completed) ? now : null,
      averageProcessingTime: _calculateAverageProcessingTime(),
      throughput: _calculateThroughput(),
    );

    _stateController.add(_currentState);
  }

  /// 计算平均处理时间
  Duration _calculateAverageProcessingTime() {
    if (_processingTimes.isEmpty) return Duration.zero;
    
    final totalMs = _processingTimes
        .map((d) => d.inMilliseconds)
        .reduce((a, b) => a + b);
    
    return Duration(milliseconds: totalMs ~/ _processingTimes.length);
  }

  /// 计算吞吐量
  double _calculateThroughput() {
    if (_startTime == null || _currentState.completedOperations == 0) {
      return 0.0;
    }
    
    final elapsedSeconds = DateTime.now().difference(_startTime!).inSeconds;
    return elapsedSeconds > 0 ? _currentState.completedOperations / elapsedSeconds : 0.0;
  }

  @override
  Future<void> dispose() async {
    _processingTimer?.cancel();
    await _stateController.close();
  }
}

/// 操作事件类
abstract class OperationEvent extends AppEvent {
  const OperationEvent({
    required this.operationId,
    required this.operation,
  });

  final String operationId;
  final OfflineOperation operation;

  @override
  Map<String, dynamic> toJson() => {
    'operation_id': operationId,
    'operation': operation.toJson(),
  };
}

/// 操作入队事件
class OperationEnqueuedEvent extends OperationEvent {
  const OperationEnqueuedEvent({
    required super.operationId,
    required super.operation,
  });

  @override
  String get type => 'operation_enqueued';
}

/// 操作开始执行事件
class OperationStartedEvent extends OperationEvent {
  const OperationStartedEvent({
    required super.operationId,
    required super.operation,
  });

  @override
  String get type => 'operation_started';
}

/// 操作完成事件
class OperationCompletedEvent extends OperationEvent {
  const OperationCompletedEvent({
    required super.operationId,
    required super.operation,
    required this.duration,
  });

  final Duration duration;

  @override
  String get type => 'operation_completed';

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'duration_ms': duration.inMilliseconds,
  };
}

/// 操作失败事件
class OperationFailedEvent extends OperationEvent {
  const OperationFailedEvent({
    required super.operationId,
    required super.operation,
    required this.error,
    required this.willRetry,
  });

  final String error;
  final bool willRetry;

  @override
  String get type => 'operation_failed';

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'error': error,
    'will_retry': willRetry,
  };
}

/// Riverpod 提供者
final offlineQueueProvider = Provider<OfflineQueue>((ref) {
  return OfflineQueue();
});

final queueStateProvider = StreamProvider<QueueState>((ref) {
  final queue = ref.watch(offlineQueueProvider);
  return queue.stateStream;
});

/// 带配置的离线队列提供者
final configuredOfflineQueueProvider = Provider.family<OfflineQueue, QueueConfig>(
  (ref, config) {
    return OfflineQueue(config: config);
  },
); 