// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../types/result.dart';
import '../events/events.dart';
import '../contracts/base_contract.dart';
import 'conflict_resolver.dart';
import 'offline_queue.dart';

/// 同步状态枚举
enum SyncStatus {
  idle,           // 空闲状态
  syncing,        // 同步中
  success,        // 同步成功
  failed,         // 同步失败
  paused,         // 暂停同步
  conflict,       // 存在冲突
}

/// 同步策略枚举
enum SyncStrategy {
  clientWins,     // 客户端优先
  serverWins,     // 服务端优先
  lastModified,   // 最后修改时间优先
  manual,         // 手动解决
  merge,          // 合并策略
}

/// 同步方向枚举
enum SyncDirection {
  upload,         // 仅上传
  download,       // 仅下载
  bidirectional,  // 双向同步
}

/// 同步配置类
@immutable
class SyncConfig {
  const SyncConfig({
    this.strategy = SyncStrategy.lastModified,
    this.direction = SyncDirection.bidirectional,
    this.batchSize = 50,
    this.retryAttempts = 3,
    this.retryDelay = const Duration(seconds: 5),
    this.syncInterval = const Duration(minutes: 15),
    this.enableAutoSync = true,
    this.enableConflictResolution = true,
    this.maxConcurrentSyncs = 3,
    this.compressionEnabled = true,
    this.encryptionEnabled = false,
    this.enableOfflineQueue = true,
  });

  final SyncStrategy strategy;
  final SyncDirection direction;
  final int batchSize;
  final int retryAttempts;
  final Duration retryDelay;
  final Duration syncInterval;
  final bool enableAutoSync;
  final bool enableConflictResolution;
  final int maxConcurrentSyncs;
  final bool compressionEnabled;
  final bool encryptionEnabled;
  final bool enableOfflineQueue;

  SyncConfig copyWith({
    SyncStrategy? strategy,
    SyncDirection? direction,
    int? batchSize,
    int? retryAttempts,
    Duration? retryDelay,
    Duration? syncInterval,
    bool? enableAutoSync,
    bool? enableConflictResolution,
    int? maxConcurrentSyncs,
    bool? compressionEnabled,
    bool? encryptionEnabled,
    bool? enableOfflineQueue,
  }) {
    return SyncConfig(
      strategy: strategy ?? this.strategy,
      direction: direction ?? this.direction,
      batchSize: batchSize ?? this.batchSize,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
      syncInterval: syncInterval ?? this.syncInterval,
      enableAutoSync: enableAutoSync ?? this.enableAutoSync,
      enableConflictResolution: enableConflictResolution ?? this.enableConflictResolution,
      maxConcurrentSyncs: maxConcurrentSyncs ?? this.maxConcurrentSyncs,
      compressionEnabled: compressionEnabled ?? this.compressionEnabled,
      encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
      enableOfflineQueue: enableOfflineQueue ?? this.enableOfflineQueue,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncConfig &&
        other.strategy == strategy &&
        other.direction == direction &&
        other.batchSize == batchSize &&
        other.retryAttempts == retryAttempts &&
        other.retryDelay == retryDelay &&
        other.syncInterval == syncInterval &&
        other.enableAutoSync == enableAutoSync &&
        other.enableConflictResolution == enableConflictResolution &&
        other.maxConcurrentSyncs == maxConcurrentSyncs &&
        other.compressionEnabled == compressionEnabled &&
        other.encryptionEnabled == encryptionEnabled &&
        other.enableOfflineQueue == enableOfflineQueue;
  }

  @override
  int get hashCode {
    return Object.hash(
      strategy,
      direction,
      batchSize,
      retryAttempts,
      retryDelay,
      syncInterval,
      enableAutoSync,
      enableConflictResolution,
      maxConcurrentSyncs,
      compressionEnabled,
      encryptionEnabled,
      enableOfflineQueue,
    );
  }
}

/// 同步项目接口
abstract class SyncItem {
  String get id;
  String get type;
  DateTime get lastModified;
  Map<String, dynamic> toJson();
  String get checksum;
  int get version;
}

/// 冲突类型枚举
enum ConflictType {
  dataConflict,    // 数据冲突
  deleteConflict,  // 删除冲突
  typeConflict,    // 类型冲突
  versionConflict, // 版本冲突
}

/// 冲突解决方案枚举
enum ConflictResolution {
  useLocal,        // 使用本地版本
  useRemote,       // 使用远程版本
  merge,           // 合并版本
  skip,            // 跳过此项
}

/// 同步冲突类
@immutable
class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.type,
    required this.localItem,
    required this.remoteItem,
    required this.conflictType,
    this.resolvedItem,
    this.resolution,
  });

  final String id;
  final String type;
  final SyncItem localItem;
  final SyncItem remoteItem;
  final ConflictType conflictType;
  final SyncItem? resolvedItem;
  final ConflictResolution? resolution;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncConflict &&
        other.id == id &&
        other.type == type &&
        other.conflictType == conflictType &&
        other.resolution == resolution;
  }

  @override
  int get hashCode {
    return Object.hash(id, type, conflictType, resolution);
  }
}

/// 同步结果类
@immutable
class SyncResult {
  const SyncResult({
    required this.status,
    required this.uploadedCount,
    required this.downloadedCount,
    required this.conflictCount,
    required this.errorCount,
    required this.duration,
    this.errors = const [],
    this.conflicts = const [],
    this.message,
  });

  final SyncStatus status;
  final int uploadedCount;
  final int downloadedCount;
  final int conflictCount;
  final int errorCount;
  final Duration duration;
  final List<String> errors;
  final List<SyncConflict> conflicts;
  final String? message;

  bool get hasErrors => errorCount > 0;
  bool get hasConflicts => conflictCount > 0;
  bool get isSuccess => status == SyncStatus.success;
  int get totalProcessed => uploadedCount + downloadedCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncResult &&
        other.status == status &&
        other.uploadedCount == uploadedCount &&
        other.downloadedCount == downloadedCount &&
        other.conflictCount == conflictCount &&
        other.errorCount == errorCount &&
        other.duration == duration &&
        listEquals(other.errors, errors) &&
        listEquals(other.conflicts, conflicts) &&
        other.message == message;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      uploadedCount,
      downloadedCount,
      conflictCount,
      errorCount,
      duration,
      Object.hashAll(errors),
      Object.hashAll(conflicts),
      message,
    );
  }
}

/// 同步状态类
@immutable
class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.progress = 0.0,
    this.currentItem,
    this.totalItems = 0,
    this.processedItems = 0,
    this.lastSyncTime,
    this.nextSyncTime,
    this.conflicts = const [],
    this.errors = const [],
    this.isOnline = true,
  });

  final SyncStatus status;
  final double progress;
  final String? currentItem;
  final int totalItems;
  final int processedItems;
  final DateTime? lastSyncTime;
  final DateTime? nextSyncTime;
  final List<SyncConflict> conflicts;
  final List<String> errors;
  final bool isOnline;

  bool get isSyncing => status == SyncStatus.syncing;
  bool get hasConflicts => conflicts.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
  bool get canSync => isOnline && !isSyncing;

  SyncState copyWith({
    SyncStatus? status,
    double? progress,
    String? currentItem,
    int? totalItems,
    int? processedItems,
    DateTime? lastSyncTime,
    DateTime? nextSyncTime,
    List<SyncConflict>? conflicts,
    List<String>? errors,
    bool? isOnline,
  }) {
    return SyncState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentItem: currentItem ?? this.currentItem,
      totalItems: totalItems ?? this.totalItems,
      processedItems: processedItems ?? this.processedItems,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      nextSyncTime: nextSyncTime ?? this.nextSyncTime,
      conflicts: conflicts ?? this.conflicts,
      errors: errors ?? this.errors,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncState &&
        other.status == status &&
        other.progress == progress &&
        other.currentItem == currentItem &&
        other.totalItems == totalItems &&
        other.processedItems == processedItems &&
        other.lastSyncTime == lastSyncTime &&
        other.nextSyncTime == nextSyncTime &&
        listEquals(other.conflicts, conflicts) &&
        listEquals(other.errors, errors) &&
        other.isOnline == isOnline;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      progress,
      currentItem,
      totalItems,
      processedItems,
      lastSyncTime,
      nextSyncTime,
      Object.hashAll(conflicts),
      Object.hashAll(errors),
      isOnline,
    );
  }
}

/// 同步统计类
@immutable
class SyncStats {
  const SyncStats({
    required this.totalSyncs,
    required this.successfulSyncs,
    required this.failedSyncs,
    required this.totalItemsSynced,
    required this.totalConflicts,
    required this.averageSyncTime,
    required this.lastSyncTime,
  });

  final int totalSyncs;
  final int successfulSyncs;
  final int failedSyncs;
  final int totalItemsSynced;
  final int totalConflicts;
  final Duration averageSyncTime;
  final DateTime? lastSyncTime;

  double get successRate => 
    totalSyncs > 0 ? successfulSyncs / totalSyncs : 0.0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncStats &&
        other.totalSyncs == totalSyncs &&
        other.successfulSyncs == successfulSyncs &&
        other.failedSyncs == failedSyncs &&
        other.totalItemsSynced == totalItemsSynced &&
        other.totalConflicts == totalConflicts &&
        other.averageSyncTime == averageSyncTime &&
        other.lastSyncTime == lastSyncTime;
  }

  @override
  int get hashCode {
    return Object.hash(
      totalSyncs,
      successfulSyncs,
      failedSyncs,
      totalItemsSynced,
      totalConflicts,
      averageSyncTime,
      lastSyncTime,
    );
  }
}

/// 同步提供者接口
abstract class SyncProvider<T extends SyncItem> {
  String get type;
  
  /// 获取本地变更项目
  Future<List<T>> getLocalChanges();
  
  /// 获取远程变更项目
  Future<List<T>> getRemoteChanges(DateTime? since);
  
  /// 上传项目到服务器
  Future<Result<void, String>> uploadItem(T item);
  
  /// 从服务器下载项目
  Future<Result<T, String>> downloadItem(String id);
  
  /// 保存项目到本地
  Future<Result<void, String>> saveLocal(T item);
  
  /// 删除本地项目
  Future<Result<void, String>> deleteLocal(String id);
  
  /// 标记项目为已同步
  Future<void> markAsSynced(String id);
  
  /// 获取项目检查和
  Future<String> getChecksum(String id);
  
  /// 解决冲突
  Future<Result<T, String>> resolveConflict(
    T localItem,
    T remoteItem,
    ConflictResolution resolution,
  );
}

/// 同步管理器接口
abstract class ISyncManager {
  /// 当前同步状态
  Stream<SyncState> get stateStream;
  
  /// 同步配置
  SyncConfig get config;
  
  /// 开始同步
  Future<Result<SyncResult, String>> startSync({
    List<String>? types,
    bool force = false,
  });
  
  /// 停止同步
  Future<void> stopSync();
  
  /// 暂停同步
  Future<void> pauseSync();
  
  /// 恢复同步
  Future<void> resumeSync();
  
  /// 解决冲突
  Future<Result<void, String>> resolveConflict(
    String conflictId,
    ConflictResolution resolution,
    {SyncItem? customItem}
  );
  
  /// 更新配置
  Future<void> updateConfig(SyncConfig config);
  
  /// 注册同步提供者
  void registerSyncProvider<T extends SyncItem>(SyncProvider<T> provider);
  
  /// 注销同步提供者
  void unregisterSyncProvider(String type);
  
  /// 清理同步数据
  Future<void> clearSyncData();
  
  /// 获取同步统计
  Future<SyncStats> getSyncStats();
  
  /// 离线队列相关方法
  
  /// 将操作加入离线队列
  Future<Result<String, String>> enqueueOfflineOperation(OfflineOperation operation);
  
  /// 获取离线队列状态
  Stream<QueueState>? get offlineQueueState;
  
  /// 处理离线队列中的操作
  Future<Result<void, String>> processOfflineQueue();
}

/// 同步管理器实现
class SyncManager extends ISyncManager {
  SyncManager({
    SyncConfig? config,
    ConflictResolver? conflictResolver,
    OfflineQueue? offlineQueue,
  }) : _config = config ?? const SyncConfig(),
       _conflictResolver = conflictResolver,
       _offlineQueue = offlineQueue {
    _initialize();
  }

  SyncConfig _config;
  @override
  SyncConfig get config => _config;

  final Map<String, SyncProvider> _providers = {};
  final StreamController<SyncState> _stateController = 
      StreamController<SyncState>.broadcast();
  
  /// 可选的高级冲突解决器
  final ConflictResolver? _conflictResolver;
  
  /// 可选的离线操作队列
  final OfflineQueue? _offlineQueue;
  
  Timer? _syncTimer;
  final List<Completer<void>> _activeSyncs = [];
  bool _isPaused = false;
  SyncState _currentState = const SyncState();
  
  @override
  Stream<SyncState> get stateStream => _stateController.stream;

  /// 检查是否启用了高级冲突解决器
  bool get hasAdvancedConflictResolution => _conflictResolver != null;

  /// 检查是否启用了离线队列
  bool get hasOfflineQueue => _offlineQueue != null && _config.enableOfflineQueue;

  /// 初始化同步管理器
  void _initialize() {
    _setupAutoSync();
    _loadSyncState();
    _setupOfflineQueue();
  }

  /// 设置离线队列
  void _setupOfflineQueue() {
    if (!hasOfflineQueue) return;
    
    // 注册默认的同步操作执行器
    _offlineQueue!.registerExecutor(DefaultSyncOperationExecutor(this));
    
    debugPrint('Offline queue configured with SyncManager');
  }

  /// 设置自动同步
  void _setupAutoSync() {
    if (_config.enableAutoSync) {
      _scheduleSync();
    }
  }

  /// 调度同步
  void _scheduleSync() {
    _syncTimer?.cancel();
    
    if (!_config.enableAutoSync) return;
    
    _syncTimer = Timer(_config.syncInterval, () {
      if (_currentState.canSync && !_isPaused) {
        startSync();
      }
    });
    
    _updateState(_currentState.copyWith(
      nextSyncTime: DateTime.now().add(_config.syncInterval),
    ));
  }

  /// 加载同步状态
  Future<void> _loadSyncState() async {
    try {
      // 在实际实现中，这里应该从本地存储加载状态
      _updateState(const SyncState());
    } catch (e) {
      debugPrint('Failed to load sync state: $e');
    }
  }

  /// 更新状态
  void _updateState(SyncState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  @override
  Future<Result<SyncResult, String>> startSync({
    List<String>? types,
    bool force = false,
  }) async {
    if (_currentState.isSyncing && !force) {
      return Result.failure('Sync is already in progress');
    }

    if (!_currentState.isOnline) {
      return Result.failure('No internet connection');
    }

    if (_isPaused && !force) {
      return Result.failure('Sync is paused');
    }

    final completer = Completer<void>();
    _activeSyncs.add(completer);

    try {
      _updateState(_currentState.copyWith(
        status: SyncStatus.syncing,
        progress: 0.0,
        errors: [],
        conflicts: [],
      ));

      final result = await _performSync(types);

      _updateState(_currentState.copyWith(
        status: result.status,
        progress: 1.0,
        lastSyncTime: DateTime.now(),
        errors: result.errors,
        conflicts: result.conflicts,
      ));

      _scheduleSync();
      
      return Result.success(result);
    } catch (e) {
      _updateState(_currentState.copyWith(
        status: SyncStatus.failed,
        errors: [..._currentState.errors, e.toString()],
      ));
      
      return Result.failure('Sync failed: $e');
    } finally {
      _activeSyncs.remove(completer);
      completer.complete();
    }
  }

  /// 执行同步
  Future<SyncResult> _performSync(List<String>? types) async {
    final targetTypes = types ?? _providers.keys.toList();
    
    // 简化的同步逻辑 - 实际实现中会更复杂
    final overallStatus = SyncStatus.success;

    return SyncResult(
      status: overallStatus,
      uploadedCount: 0,
      downloadedCount: 0,
      conflictCount: 0,
      errorCount: 0,
      duration: Duration.zero,
      errors: const [],
      conflicts: const [],
    );
  }

  @override
  Future<void> stopSync() async {
    _syncTimer?.cancel();
    _isPaused = false;
    
    // 等待所有活动同步完成
    await Future.wait(_activeSyncs.map((c) => c.future));
    
    _updateState(_currentState.copyWith(
      status: SyncStatus.idle,
      progress: 0.0,
      currentItem: null,
    ));
  }

  @override
  Future<void> pauseSync() async {
    _isPaused = true;
    _syncTimer?.cancel();
    
    _updateState(_currentState.copyWith(
      status: SyncStatus.paused,
      nextSyncTime: null,
    ));
  }

  @override
  Future<void> resumeSync() async {
    _isPaused = false;
    
    if (_config.enableAutoSync) {
      _scheduleSync();
    }
    
    _updateState(_currentState.copyWith(
      status: SyncStatus.idle,
    ));
  }

  @override
  Future<Result<void, String>> resolveConflict(
    String conflictId,
    ConflictResolution resolution,
    {SyncItem? customItem}
  ) async {
    try {
      // 如果配置了高级冲突解决器，使用它来处理冲突
      if (_conflictResolver != null && _config.enableConflictResolution) {
        return await _resolveConflictWithAdvancedResolver(
          conflictId, 
          resolution, 
          customItem
        );
      }

      // 否则使用简化的冲突解决逻辑（向后兼容）
      return await _resolveConflictSimple(conflictId, resolution, customItem);
    } catch (e) {
      return Result.failure('Failed to resolve conflict: $e');
    }
  }

  /// 使用高级冲突解决器处理冲突
  Future<Result<void, String>> _resolveConflictWithAdvancedResolver(
    String conflictId,
    ConflictResolution resolution,
    SyncItem? customItem,
  ) async {
    // 找到对应的冲突
    final conflict = _currentState.conflicts
        .where((c) => c.id == conflictId)
        .firstOrNull;
    
    if (conflict == null) {
      return Result.failure('Conflict not found: $conflictId');
    }

    final context = ConflictResolutionContext(
      userId: 'current_user', // 从用户上下文获取
      deviceId: 'current_device', // 从设备信息获取
      timestamp: DateTime.now(),
      metadata: {
        'sync_manager_resolution': resolution.name,
        'custom_item_provided': customItem != null,
      },
    );

    final result = await _conflictResolver!.resolveConflict(
      conflict, 
      context
    );

    if (result.isSuccess) {
      final resolutionResult = result.valueOrNull!;
      // 更新冲突状态
      _updateConflictResolution(conflictId, resolution, resolutionResult.resolvedItem);
      return Result.success(null);
    } else {
      return Result.failure(result.errorOrNull ?? 'Unknown error');
    }
  }

  /// 简化的冲突解决逻辑（向后兼容）
  Future<Result<void, String>> _resolveConflictSimple(
    String conflictId,
    ConflictResolution resolution,
    SyncItem? customItem,
  ) async {
    // 原始的简化逻辑
    _updateConflictResolution(conflictId, resolution, customItem);
    return Result.success(null);
  }

  /// 更新冲突解决状态
  void _updateConflictResolution(
    String conflictId,
    ConflictResolution resolution,
    SyncItem? resolvedItem,
  ) {
    final updatedConflicts = _currentState.conflicts.map((conflict) {
      if (conflict.id == conflictId) {
        return SyncConflict(
          id: conflict.id,
          type: conflict.type,
          localItem: conflict.localItem,
          remoteItem: conflict.remoteItem,
          conflictType: conflict.conflictType,
          resolution: resolution,
          resolvedItem: resolvedItem,
        );
      }
      return conflict;
    }).toList();

    _updateState(_currentState.copyWith(
      conflicts: updatedConflicts,
    ));
  }

  /// 映射冲突类型
  String _mapConflictType(ConflictType type) {
    switch (type) {
      case ConflictType.dataConflict:
        return 'data_conflict';
      case ConflictType.deleteConflict:
        return 'delete_conflict';
      case ConflictType.typeConflict:
        return 'type_conflict';
      case ConflictType.versionConflict:
        return 'version_conflict';
    }
  }

  /// 批量解决冲突（增强版）
  Future<List<Result<void, String>>> resolveConflictsAdvanced(
    List<String> conflictIds, {
    ConflictResolutionStrategy? strategy,
  }) async {
    if (_conflictResolver == null) {
      // 如果没有高级解决器，回退到简单模式
      return Future.wait(conflictIds.map((id) => 
        resolveConflict(id, ConflictResolution.useLocal)
      ));
    }

    final conflicts = _currentState.conflicts
        .where((c) => conflictIds.contains(c.id))
        .toList();

    final context = ConflictResolutionContext(
      userId: 'current_user',
      deviceId: 'current_device', 
      timestamp: DateTime.now(),
      metadata: {'batch_resolution': true},
    );

    final results = await _conflictResolver!.resolveConflicts(conflicts, context);
    
    // 更新状态
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      if (result.isSuccess) {
        final resolutionResult = result.valueOrNull!;
        _updateConflictResolution(
          conflicts[i].id, 
          ConflictResolution.merge, // 默认为合并
          resolutionResult.resolvedItem,
        );
      }
    }

    return results.map<Result<void, String>>((r) {
      if (r.isSuccess) {
        return const Result.success(null);
      } else {
        return Result.failure(r.errorOrNull ?? 'Unknown error');
      }
    }).toList();
  }

  @override
  Future<void> updateConfig(SyncConfig config) async {
    _config = config;
    
    // 重新设置自动同步
    _syncTimer?.cancel();
    if (config.enableAutoSync) {
      _setupAutoSync();
    }
  }

  @override
  void registerSyncProvider<T extends SyncItem>(SyncProvider<T> provider) {
    _providers[provider.type] = provider;
    debugPrint('Registered sync provider for type: ${provider.type}');
  }

  @override
  void unregisterSyncProvider(String type) {
    _providers.remove(type);
    debugPrint('Unregistered sync provider for type: $type');
  }

  @override
  Future<void> clearSyncData() async {
    _updateState(const SyncState());
  }

  @override
  Future<SyncStats> getSyncStats() async {
    return const SyncStats(
      totalSyncs: 0,
      successfulSyncs: 0,
      failedSyncs: 0,
      totalItemsSynced: 0,
      totalConflicts: 0,
      averageSyncTime: Duration.zero,
      lastSyncTime: null,
    );
  }

  @override
  Future<Result<String, String>> enqueueOfflineOperation(OfflineOperation operation) async {
    if (!hasOfflineQueue) {
      return Result.failure('Offline queue is not enabled or available');
    }
    
    return await _offlineQueue!.enqueue(operation);
  }

  @override
  Stream<QueueState>? get offlineQueueState {
    if (!hasOfflineQueue) return null;
    return _offlineQueue!.stateStream;
  }

  @override
  Future<Result<void, String>> processOfflineQueue() async {
    if (!hasOfflineQueue) {
      return Result.failure('Offline queue is not enabled or available');
    }

    try {
      // 获取所有待处理的操作
      final operationsResult = await _offlineQueue!.getOperationsByStatus(
        OperationStatus.pending,
      );
      
      if (!operationsResult.isSuccess) {
        return Result.failure('Failed to get pending operations: ${operationsResult.errorOrNull}');
      }

      final operations = operationsResult.valueOrNull!;
      debugPrint('Processing ${operations.length} offline operations');

      // 这里可以添加更复杂的处理逻辑
      // 比如批量处理、优先级排序等
      
      return Result.success(null);
    } catch (e) {
      return Result.failure('Failed to process offline queue: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _syncTimer?.cancel();
    _stateController.close();
    _conflictResolver?.dispose();
    _offlineQueue?.dispose();
  }
}

/// 同步状态变更事件
class SyncStateChangedEvent extends AppEvent {
  const SyncStateChangedEvent({
    required this.previousState,
    required this.currentState,
  });

  final SyncState previousState;
  final SyncState currentState;

  @override
  String get type => 'sync_state_changed';

  @override
  Map<String, dynamic> toJson() => {
    'previous_state': _syncStateToJson(previousState),
    'current_state': _syncStateToJson(currentState),
  };

  Map<String, dynamic> _syncStateToJson(SyncState state) => {
    'status': state.status.name,
    'progress': state.progress,
    'current_item': state.currentItem,
    'total_items': state.totalItems,
    'processed_items': state.processedItems,
    'last_sync_time': state.lastSyncTime?.toIso8601String(),
    'next_sync_time': state.nextSyncTime?.toIso8601String(),
    'conflicts_count': state.conflicts.length,
    'errors_count': state.errors.length,
    'is_online': state.isOnline,
  };
}

/// Riverpod 提供者
final syncManagerProvider = Provider<SyncManager>((ref) {
  return SyncManager();
});

/// 带高级冲突解决器的同步管理器提供者
final advancedSyncManagerProvider = Provider<SyncManager>((ref) {
  final conflictResolver = ConflictResolverFactory.create(
    defaultStrategy: LastModifiedWinsStrategy(),
    autoResolutionEnabled: true,
  );
  
  return SyncManager(
    conflictResolver: conflictResolver,
  );
});

/// 带离线队列的同步管理器提供者
final offlineSyncManagerProvider = Provider<SyncManager>((ref) {
  final offlineQueue = ref.watch(offlineQueueProvider);
  
  return SyncManager(
    offlineQueue: offlineQueue,
  );
});

/// 完整功能的同步管理器提供者
final fullFeaturedSyncManagerProvider = Provider<SyncManager>((ref) {
  final conflictResolver = ConflictResolverFactory.create(
    defaultStrategy: LastModifiedWinsStrategy(),
    autoResolutionEnabled: true,
  );
  final offlineQueue = ref.watch(offlineQueueProvider);
  
  return SyncManager(
    conflictResolver: conflictResolver,
    offlineQueue: offlineQueue,
  );
});

final syncStateProvider = StreamProvider<SyncState>((ref) {
  final syncManager = ref.watch(syncManagerProvider);
  return syncManager.stateStream;
});

/// 扩展方法
extension SyncManagerExtensions on SyncManager {
  /// 同步特定实体
  Future<Result<SyncResult, String>> syncEntity<T extends SyncItem>(
    String entityType, {
    String? entityId,
  }) async {
    return startSync(types: [entityType]);
  }
  
  /// 批量解决冲突
  Future<List<Result<void, String>>> resolveConflicts(
    Map<String, ConflictResolution> resolutions,
  ) async {
    final results = <Result<void, String>>[];
    
    for (final entry in resolutions.entries) {
      final result = await resolveConflict(entry.key, entry.value);
      results.add(result);
    }
    
    return results;
  }
  
  /// 获取冲突详情
  List<SyncConflict> getConflictsByType(String type) {
    return _currentState.conflicts
        .where((conflict) => conflict.type == type)
        .toList();
  }
  
  /// 检查是否有特定类型的冲突
  bool hasConflictsForType(String type) {
    return _currentState.conflicts.any((conflict) => conflict.type == type);
  }
}

/// 默认的同步操作执行器
/// 
/// 这个执行器将离线队列中的操作转换为SyncManager的同步操作
class DefaultSyncOperationExecutor implements OperationExecutor {
  DefaultSyncOperationExecutor(this._syncManager);

  final SyncManager _syncManager;

  @override
  String get type => 'default_sync';

  @override
  bool supports(OfflineOperationType operationType, String entityType) {
    // 支持所有基本的同步操作类型
    switch (operationType) {
      case OfflineOperationType.sync:
      case OfflineOperationType.upload:
      case OfflineOperationType.create:
      case OfflineOperationType.update:
      case OfflineOperationType.delete:
        return true;
    }
  }

  @override
  Future<Result<void, String>> execute(OfflineOperation operation) async {
    try {
      switch (operation.type) {
        case OfflineOperationType.sync:
          return await _executeSync(operation);
        case OfflineOperationType.upload:
          return await _executeUpload(operation);
        case OfflineOperationType.create:
        case OfflineOperationType.update:
        case OfflineOperationType.delete:
          return await _executeCRUDOperation(operation);
      }
    } catch (e) {
      return Result.failure('Operation execution failed: $e');
    }
  }

  @override
  Duration estimateExecutionTime(OfflineOperation operation) {
    // 基于操作类型估算执行时间
    switch (operation.type) {
      case OfflineOperationType.sync:
        return const Duration(seconds: 10);
      case OfflineOperationType.upload:
        return const Duration(seconds: 5);
      case OfflineOperationType.create:
      case OfflineOperationType.update:
      case OfflineOperationType.delete:
        return const Duration(seconds: 3);
    }
  }

  @override
  Future<bool> canExecute(OfflineOperation operation) async {
    // 检查网络状态和同步器状态
    if (!_syncManager._currentState.isOnline) {
      return false;
    }

    if (_syncManager._currentState.isSyncing) {
      return false;
    }

    // 检查是否有相应的提供者
    final provider = _syncManager._providers[operation.entityType];
    return provider != null;
  }

  /// 执行同步操作
  Future<Result<void, String>> _executeSync(OfflineOperation operation) async {
    final result = await _syncManager.startSync(
      types: [operation.entityType],
      force: true,
    );

    if (result.isSuccess) {
      return Result.success(null);
    } else {
      return Result.failure(result.errorOrNull ?? 'Sync failed');
    }
  }

  /// 执行上传操作
  Future<Result<void, String>> _executeUpload(OfflineOperation operation) async {
    final provider = _syncManager._providers[operation.entityType];
    if (provider == null) {
      return Result.failure('No provider found for type: ${operation.entityType}');
    }

    // 这里需要根据operation.data创建SyncItem
    // 简化实现，实际中需要根据具体的数据结构来转换
    try {
      // 模拟上传操作
      debugPrint('Uploading ${operation.entityType} item: ${operation.entityId}');
      
      // 实际实现中，这里会调用provider的uploadItem方法
      // final uploadResult = await provider.uploadItem(syncItem);
      
      return Result.success(null);
    } catch (e) {
      return Result.failure('Upload failed: $e');
    }
  }

  /// 执行CRUD操作
  Future<Result<void, String>> _executeCRUDOperation(OfflineOperation operation) async {
    final provider = _syncManager._providers[operation.entityType];
    if (provider == null) {
      return Result.failure('No provider found for type: ${operation.entityType}');
    }

    try {
      switch (operation.type) {
        case OfflineOperationType.create:
        case OfflineOperationType.update:
          debugPrint('Saving ${operation.entityType} item: ${operation.entityId}');
          // 实际实现中会调用 provider.saveLocal(syncItem)
          break;
        case OfflineOperationType.delete:
          debugPrint('Deleting ${operation.entityType} item: ${operation.entityId}');
          // 实际实现中会调用 provider.deleteLocal(operation.entityId!)
          break;
        default:
          return Result.failure('Unsupported CRUD operation: ${operation.type}');
      }
      
      return Result.success(null);
    } catch (e) {
      return Result.failure('CRUD operation failed: $e');
    }
  }
} 