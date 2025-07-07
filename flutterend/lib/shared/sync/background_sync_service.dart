// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart' as workmanager;

import 'package:v7_flutter_app/shared/connectivity/network_monitor.dart';
import 'package:v7_flutter_app/shared/events/event_bus.dart';
import 'package:v7_flutter_app/shared/events/events.dart';
import 'package:v7_flutter_app/shared/offline/offline_indicator.dart';
import 'package:v7_flutter_app/shared/sync/offline_queue.dart';
import 'package:v7_flutter_app/shared/sync/sync_manager.dart';
import 'package:v7_flutter_app/shared/types/result.dart';

/// 后台同步任务类型
enum BackgroundSyncTaskType {
  /// 定期同步
  periodicSync,
  /// 网络恢复同步
  networkRecoverySync,
  /// 离线队列处理
  offlineQueueProcessing,
  /// 紧急数据同步
  emergencySync,
  /// 增量同步
  incrementalSync,
  /// 完整同步
  fullSync,
}

/// 后台同步配置
@immutable
class BackgroundSyncConfig {
  const BackgroundSyncConfig({
    this.periodicSyncInterval = const Duration(minutes: 30),
    this.networkRecoveryDelay = const Duration(seconds: 10),
    this.maxRetryAttempts = 3,
    this.retryBackoffMultiplier = 2.0,
    this.enableBatteryOptimization = true,
    this.enableWifiOnlyMode = false,
    this.enableDataSaverMode = false,
    this.maxSyncDuration = const Duration(minutes: 10),
    this.enableDebugLogging = false,
    this.priorityThreshold = OperationPriority.normal,
    this.backgroundSyncEnabled = true,
    this.adaptiveScheduling = true,
  });

  /// 定期同步间隔
  final Duration periodicSyncInterval;
  /// 网络恢复后的延迟时间
  final Duration networkRecoveryDelay;
  /// 最大重试次数
  final int maxRetryAttempts;
  /// 重试退避乘数
  final double retryBackoffMultiplier;
  /// 启用电池优化
  final bool enableBatteryOptimization;
  /// 仅WiFi模式
  final bool enableWifiOnlyMode;
  /// 启用数据节省模式
  final bool enableDataSaverMode;
  /// 最大同步时长
  final Duration maxSyncDuration;
  /// 启用调试日志
  final bool enableDebugLogging;
  /// 优先级阈值
  final OperationPriority priorityThreshold;
  /// 后台同步是否启用
  final bool backgroundSyncEnabled;
  /// 自适应调度
  final bool adaptiveScheduling;

  BackgroundSyncConfig copyWith({
    Duration? periodicSyncInterval,
    Duration? networkRecoveryDelay,
    int? maxRetryAttempts,
    double? retryBackoffMultiplier,
    bool? enableBatteryOptimization,
    bool? enableWifiOnlyMode,
    bool? enableDataSaverMode,
    Duration? maxSyncDuration,
    bool? enableDebugLogging,
    OperationPriority? priorityThreshold,
    bool? backgroundSyncEnabled,
    bool? adaptiveScheduling,
  }) {
    return BackgroundSyncConfig(
      periodicSyncInterval: periodicSyncInterval ?? this.periodicSyncInterval,
      networkRecoveryDelay: networkRecoveryDelay ?? this.networkRecoveryDelay,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      retryBackoffMultiplier: retryBackoffMultiplier ?? this.retryBackoffMultiplier,
      enableBatteryOptimization: enableBatteryOptimization ?? this.enableBatteryOptimization,
      enableWifiOnlyMode: enableWifiOnlyMode ?? this.enableWifiOnlyMode,
      enableDataSaverMode: enableDataSaverMode ?? this.enableDataSaverMode,
      maxSyncDuration: maxSyncDuration ?? this.maxSyncDuration,
      enableDebugLogging: enableDebugLogging ?? this.enableDebugLogging,
      priorityThreshold: priorityThreshold ?? this.priorityThreshold,
      backgroundSyncEnabled: backgroundSyncEnabled ?? this.backgroundSyncEnabled,
      adaptiveScheduling: adaptiveScheduling ?? this.adaptiveScheduling,
    );
  }
}

/// 后台同步状态
@immutable
class BackgroundSyncState {
  const BackgroundSyncState({
    this.isActive = false,
    this.lastSyncTime,
    this.nextScheduledSync,
    this.pendingTasks = const [],
    this.runningTasks = const [],
    this.completedTasks = const [],
    this.failedTasks = const [],
    this.totalSyncCount = 0,
    this.successfulSyncCount = 0,
    this.failedSyncCount = 0,
    this.averageSyncDuration = Duration.zero,
    this.networkCondition = NetworkQuality.none,
    this.batteryLevel = 1.0,
    this.isCharging = false,
    this.isWifiConnected = false,
    this.error,
  });

  /// 是否活跃
  final bool isActive;
  /// 最后同步时间
  final DateTime? lastSyncTime;
  /// 下次计划同步时间
  final DateTime? nextScheduledSync;
  /// 待处理任务
  final List<BackgroundSyncTask> pendingTasks;
  /// 运行中任务
  final List<BackgroundSyncTask> runningTasks;
  /// 已完成任务
  final List<BackgroundSyncTask> completedTasks;
  /// 失败任务
  final List<BackgroundSyncTask> failedTasks;
  /// 总同步次数
  final int totalSyncCount;
  /// 成功同步次数
  final int successfulSyncCount;
  /// 失败同步次数
  final int failedSyncCount;
  /// 平均同步时长
  final Duration averageSyncDuration;
  /// 网络条件
  final NetworkQuality networkCondition;
  /// 电池电量
  final double batteryLevel;
  /// 是否充电中
  final bool isCharging;
  /// 是否WiFi连接
  final bool isWifiConnected;
  /// 错误信息
  final String? error;

  /// 成功率
  double get successRate => totalSyncCount > 0 ? successfulSyncCount / totalSyncCount : 0.0;

  /// 是否有待处理任务
  bool get hasPendingTasks => pendingTasks.isNotEmpty;

  /// 是否有运行中任务
  bool get hasRunningTasks => runningTasks.isNotEmpty;

  /// 是否有失败任务
  bool get hasFailedTasks => failedTasks.isNotEmpty;

  /// 是否适合同步
  bool get isGoodForSync {
    return networkCondition != NetworkQuality.none &&
           networkCondition != NetworkQuality.poor &&
           (batteryLevel > 0.2 || isCharging);
  }

  BackgroundSyncState copyWith({
    bool? isActive,
    DateTime? lastSyncTime,
    DateTime? nextScheduledSync,
    List<BackgroundSyncTask>? pendingTasks,
    List<BackgroundSyncTask>? runningTasks,
    List<BackgroundSyncTask>? completedTasks,
    List<BackgroundSyncTask>? failedTasks,
    int? totalSyncCount,
    int? successfulSyncCount,
    int? failedSyncCount,
    Duration? averageSyncDuration,
    NetworkQuality? networkCondition,
    double? batteryLevel,
    bool? isCharging,
    bool? isWifiConnected,
    String? error,
  }) {
    return BackgroundSyncState(
      isActive: isActive ?? this.isActive,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      nextScheduledSync: nextScheduledSync ?? this.nextScheduledSync,
      pendingTasks: pendingTasks ?? this.pendingTasks,
      runningTasks: runningTasks ?? this.runningTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      failedTasks: failedTasks ?? this.failedTasks,
      totalSyncCount: totalSyncCount ?? this.totalSyncCount,
      successfulSyncCount: successfulSyncCount ?? this.successfulSyncCount,
      failedSyncCount: failedSyncCount ?? this.failedSyncCount,
      averageSyncDuration: averageSyncDuration ?? this.averageSyncDuration,
      networkCondition: networkCondition ?? this.networkCondition,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      isWifiConnected: isWifiConnected ?? this.isWifiConnected,
      error: error,
    );
  }
}

/// 后台同步任务
@immutable
class BackgroundSyncTask {
  const BackgroundSyncTask({
    required this.id,
    required this.type,
    required this.createdAt,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.priority = OperationPriority.normal,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.data,
    this.error,
    this.duration,
  });

  /// 任务ID
  final String id;
  /// 任务类型
  final BackgroundSyncTaskType type;
  /// 创建时间
  final DateTime createdAt;
  /// 计划执行时间
  final DateTime? scheduledAt;
  /// 开始时间
  final DateTime? startedAt;
  /// 完成时间
  final DateTime? completedAt;
  /// 优先级
  final OperationPriority priority;
  /// 重试次数
  final int retryCount;
  /// 最大重试次数
  final int maxRetries;
  /// 任务数据
  final Map<String, dynamic>? data;
  /// 错误信息
  final String? error;
  /// 执行时长
  final Duration? duration;

  /// 是否完成
  bool get isCompleted => completedAt != null;

  /// 是否失败
  bool get isFailed => error != null;

  /// 是否可以重试
  bool get canRetry => retryCount < maxRetries && !isCompleted;

  /// 是否正在运行
  bool get isRunning => startedAt != null && !isCompleted;

  BackgroundSyncTask copyWith({
    String? id,
    BackgroundSyncTaskType? type,
    DateTime? createdAt,
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? completedAt,
    OperationPriority? priority,
    int? retryCount,
    int? maxRetries,
    Map<String, dynamic>? data,
    String? error,
    Duration? duration,
  }) {
    return BackgroundSyncTask(
      id: id ?? this.id,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      priority: priority ?? this.priority,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      data: data ?? this.data,
      error: error,
      duration: duration ?? this.duration,
    );
  }
}

/// 后台同步服务
class BackgroundSyncService extends StateNotifier<BackgroundSyncState> {
  BackgroundSyncService(
    this._ref, {
    BackgroundSyncConfig? config,
  }) : _config = config ?? const BackgroundSyncConfig(),
       super(const BackgroundSyncState()) {
    _initialize();
  }

  final Ref _ref;
  BackgroundSyncConfig _config;
  
  Timer? _schedulerTimer;
  Timer? _monitoringTimer;
  /// 获取配置
  BackgroundSyncConfig get config => _config;

  /// 初始化服务
  void _initialize() {
    _setupEventListeners();
    _setupMonitoring();
    _loadPersistedState();
    
    if (_config.backgroundSyncEnabled) {
      _startScheduler();
    }
  }

  /// 设置事件监听器
  void _setupEventListeners() {
    // 监听网络状态变化
    _ref.listen(networkMonitorProvider, (previous, next) {
      _handleNetworkStateChange(previous, next);
    });

    // 监听离线状态变化
    _ref.listen(offlineIndicatorProvider, (previous, next) {
      _handleOfflineStateChange(previous, next);
    });

    // 监听同步状态变化
    _ref.listen(syncStateProvider, (previous, next) {
      next.whenData((syncState) {
        _handleSyncStateChange(syncState);
      });
    });
  }

  /// 设置监控
  void _setupMonitoring() {
    _monitoringTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateSystemConditions(),
    );
  }

  /// 加载持久化状态
  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTimeString = prefs.getString('last_background_sync_time');
      final totalSyncCount = prefs.getInt('total_background_sync_count') ?? 0;
      final successfulSyncCount = prefs.getInt('successful_background_sync_count') ?? 0;
      final failedSyncCount = prefs.getInt('failed_background_sync_count') ?? 0;

      DateTime? lastSyncTime;
      if (lastSyncTimeString != null) {
        lastSyncTime = DateTime.tryParse(lastSyncTimeString);
      }

      state = state.copyWith(
        lastSyncTime: lastSyncTime,
        totalSyncCount: totalSyncCount,
        successfulSyncCount: successfulSyncCount,
        failedSyncCount: failedSyncCount,
      );
    } catch (e) {
      _logError('Failed to load persisted state: $e');
    }
  }

  /// 保存持久化状态
  Future<void> _savePersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (state.lastSyncTime != null) {
        await prefs.setString('last_background_sync_time', state.lastSyncTime!.toIso8601String());
      }
      
      await prefs.setInt('total_background_sync_count', state.totalSyncCount);
      await prefs.setInt('successful_background_sync_count', state.successfulSyncCount);
      await prefs.setInt('failed_background_sync_count', state.failedSyncCount);
    } catch (e) {
      _logError('Failed to save persisted state: $e');
    }
  }

  /// 处理网络状态变化
  void _handleNetworkStateChange(
    NetworkMonitorState? previous,
    NetworkMonitorState current,
  ) {
    state = state.copyWith(
      networkCondition: current.quality,
      isWifiConnected: current.type == NetworkType.wifi,
    );

    // 网络恢复时触发同步
    if (previous != null && 
        !previous.isConnected && 
        current.isConnected &&
        _config.backgroundSyncEnabled) {
      _scheduleNetworkRecoverySync();
    }
  }

  /// 处理离线状态变化
  void _handleOfflineStateChange(
    OfflineStatus? previous,
    OfflineStatus current,
  ) {
    // 当从离线状态恢复到在线状态时，处理离线队列
    if (previous != null && 
        previous.isOffline && 
        !current.isOffline &&
        _config.backgroundSyncEnabled) {
      _scheduleOfflineQueueProcessing();
    }
  }

  /// 处理同步状态变化
  void _handleSyncStateChange(SyncState syncState) {
    // 根据同步状态更新后台同步状态
    if (syncState.status == SyncStatus.success) {
      _recordSuccessfulSync(syncState);
    } else if (syncState.status == SyncStatus.failed) {
      _recordFailedSync(syncState);
    }
  }

  /// 更新系统条件
  void _updateSystemConditions() {
    // 这里可以添加电池状态、充电状态等系统条件的监控
    // 在实际实现中，可以使用 battery_plus 插件
    
    state = state.copyWith(
      batteryLevel: 1.0, // 模拟值，实际应从系统获取
      isCharging: false,  // 模拟值，实际应从系统获取
    );
  }

  /// 开始调度器
  void _startScheduler() {
    if (!_config.backgroundSyncEnabled) return;

    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(
      const Duration(minutes: 5), // 每5分钟检查一次
      (_) => _runScheduler(),
    );

    // 立即运行一次调度器
    _runScheduler();
  }

  /// 运行调度器
  void _runScheduler() {
    if (!_config.backgroundSyncEnabled) return;

    // 检查是否需要定期同步
    _checkPeriodicSync();
    
    // 处理待处理任务
    _processPendingTasks();
    
    // 清理已完成任务
    _cleanupCompletedTasks();
    
    // 更新下次计划同步时间
    _updateNextScheduledSync();
  }

  /// 检查定期同步
  void _checkPeriodicSync() {
    final now = DateTime.now();
    final shouldSync = state.lastSyncTime == null || 
                      now.difference(state.lastSyncTime!) >= _config.periodicSyncInterval;

    if (shouldSync && state.isGoodForSync && !state.hasRunningTasks) {
      scheduleTask(BackgroundSyncTaskType.periodicSync);
    }
  }

  /// 处理待处理任务
  void _processPendingTasks() {
    if (!state.isGoodForSync || state.hasRunningTasks) return;

    final sortedTasks = List<BackgroundSyncTask>.from(state.pendingTasks)
      ..sort((a, b) => _comparePriority(a.priority, b.priority));

    for (final task in sortedTasks) {
      if (state.runningTasks.length >= 1) break; // 限制并发任务数

      _executeTask(task);
    }
  }

  /// 比较优先级
  int _comparePriority(OperationPriority a, OperationPriority b) {
    const priorities = {
      OperationPriority.critical: 4,
      OperationPriority.high: 3,
      OperationPriority.normal: 2,
      OperationPriority.low: 1,
    };
    return priorities[b]! - priorities[a]!;
  }

  /// 执行任务
  Future<void> _executeTask(BackgroundSyncTask task) async {
    // 移动任务到运行中列表
    final updatedPendingTasks = List<BackgroundSyncTask>.from(state.pendingTasks)
      ..remove(task);
    
    final runningTask = task.copyWith(startedAt: DateTime.now());
    final updatedRunningTasks = List<BackgroundSyncTask>.from(state.runningTasks)
      ..add(runningTask);

    state = state.copyWith(
      pendingTasks: updatedPendingTasks,
      runningTasks: updatedRunningTasks,
    );

    try {
      await _performTask(runningTask);
      _completeTask(runningTask, null);
    } catch (e) {
      _completeTask(runningTask, e.toString());
    }
  }

  /// 执行具体任务
  Future<void> _performTask(BackgroundSyncTask task) async {
    final syncManager = _ref.read(syncManagerProvider);
    
    switch (task.type) {
      case BackgroundSyncTaskType.periodicSync:
        await _performPeriodicSync(syncManager);
        break;
      case BackgroundSyncTaskType.networkRecoverySync:
        await _performNetworkRecoverySync(syncManager);
        break;
      case BackgroundSyncTaskType.offlineQueueProcessing:
        await _performOfflineQueueProcessing(syncManager);
        break;
      case BackgroundSyncTaskType.emergencySync:
        await _performEmergencySync(syncManager, task.data);
        break;
      case BackgroundSyncTaskType.incrementalSync:
        await _performIncrementalSync(syncManager, task.data);
        break;
      case BackgroundSyncTaskType.fullSync:
        await _performFullSync(syncManager);
        break;
    }
  }

  /// 执行定期同步
  Future<void> _performPeriodicSync(SyncManager syncManager) async {
    final result = await syncManager.startSync();
    if (!result.isSuccess) {
      throw Exception('Periodic sync failed: ${result.errorOrNull}');
    }
  }

  /// 执行网络恢复同步
  Future<void> _performNetworkRecoverySync(SyncManager syncManager) async {
    // 等待网络稳定
    await Future<void>.delayed(_config.networkRecoveryDelay);
    
    final result = await syncManager.startSync(force: true);
    if (!result.isSuccess) {
      throw Exception('Network recovery sync failed: ${result.errorOrNull}');
    }
  }

  /// 执行离线队列处理
  Future<void> _performOfflineQueueProcessing(SyncManager syncManager) async {
    final result = await syncManager.processOfflineQueue();
    if (!result.isSuccess) {
      throw Exception('Offline queue processing failed: ${result.errorOrNull}');
    }
  }

  /// 执行紧急同步
  Future<void> _performEmergencySync(SyncManager syncManager, Map<String, dynamic>? data) async {
    final types = data?['types'] as List<String>?;
    final result = await syncManager.startSync(types: types, force: true);
    if (!result.isSuccess) {
      throw Exception('Emergency sync failed: ${result.errorOrNull}');
    }
  }

  /// 执行增量同步
  Future<void> _performIncrementalSync(SyncManager syncManager, Map<String, dynamic>? data) async {
    final types = data?['types'] as List<String>?;
    final result = await syncManager.startSync(types: types);
    if (!result.isSuccess) {
      throw Exception('Incremental sync failed: ${result.errorOrNull}');
    }
  }

  /// 执行完整同步
  Future<void> _performFullSync(SyncManager syncManager) async {
    // 清理本地同步状态
    await syncManager.clearSyncData();
    
    // 执行完整同步
    final result = await syncManager.startSync(force: true);
    if (!result.isSuccess) {
      throw Exception('Full sync failed: ${result.errorOrNull}');
    }
  }

  /// 完成任务
  void _completeTask(BackgroundSyncTask task, String? error) {
    final completedAt = DateTime.now();
    final duration = completedAt.difference(task.startedAt!);
    
    final completedTask = task.copyWith(
      completedAt: completedAt,
      duration: duration,
      error: error,
    );

    final updatedRunningTasks = List<BackgroundSyncTask>.from(state.runningTasks)
      ..remove(task);

    List<BackgroundSyncTask> updatedCompletedTasks;
    List<BackgroundSyncTask> updatedFailedTasks;

    if (error == null) {
      updatedCompletedTasks = List<BackgroundSyncTask>.from(state.completedTasks)
        ..add(completedTask);
      updatedFailedTasks = state.failedTasks;
    } else {
      updatedCompletedTasks = state.completedTasks;
      updatedFailedTasks = List<BackgroundSyncTask>.from(state.failedTasks)
        ..add(completedTask);
    }

    state = state.copyWith(
      runningTasks: updatedRunningTasks,
      completedTasks: updatedCompletedTasks,
      failedTasks: updatedFailedTasks,
      lastSyncTime: error == null ? completedAt : state.lastSyncTime,
      totalSyncCount: state.totalSyncCount + 1,
      successfulSyncCount: error == null ? state.successfulSyncCount + 1 : state.successfulSyncCount,
      failedSyncCount: error != null ? state.failedSyncCount + 1 : state.failedSyncCount,
      averageSyncDuration: _calculateAverageDuration(duration, error == null),
    );

    // 保存状态
    _savePersistedState();

    // 发送事件
    EventBus.instance.emit(BackgroundSyncTaskCompletedEvent(
      task: completedTask,
      success: error == null,
    ));
  }

  /// 计算平均时长
  Duration _calculateAverageDuration(Duration newDuration, bool success) {
    if (!success) return state.averageSyncDuration;
    
    final totalDuration = state.averageSyncDuration.inMilliseconds * state.successfulSyncCount +
                         newDuration.inMilliseconds;
    final newCount = state.successfulSyncCount + 1;
    
    return Duration(milliseconds: (totalDuration / newCount).round());
  }

  /// 记录成功同步
  void _recordSuccessfulSync(SyncState syncState) {
    state = state.copyWith(
      lastSyncTime: DateTime.now(),
    );
  }

  /// 记录失败同步
  void _recordFailedSync(SyncState syncState) {
    state = state.copyWith(
      error: syncState.errors.isNotEmpty ? syncState.errors.first : 'Unknown sync error',
    );
  }

  /// 计划网络恢复同步
  void _scheduleNetworkRecoverySync() {
    scheduleTask(
      BackgroundSyncTaskType.networkRecoverySync,
      priority: OperationPriority.high,
    );
  }

  /// 计划离线队列处理
  void _scheduleOfflineQueueProcessing() {
    scheduleTask(
      BackgroundSyncTaskType.offlineQueueProcessing,
      priority: OperationPriority.high,
    );
  }

  /// 清理已完成任务
  void _cleanupCompletedTasks() {
    final now = DateTime.now();
    const maxAge = Duration(hours: 24);

    final updatedCompletedTasks = state.completedTasks
        .where((task) => now.difference(task.completedAt!) < maxAge)
        .toList();

    final updatedFailedTasks = state.failedTasks
        .where((task) => now.difference(task.completedAt!) < maxAge)
        .toList();

    if (updatedCompletedTasks.length != state.completedTasks.length ||
        updatedFailedTasks.length != state.failedTasks.length) {
      state = state.copyWith(
        completedTasks: updatedCompletedTasks,
        failedTasks: updatedFailedTasks,
      );
    }
  }

  /// 更新下次计划同步时间
  void _updateNextScheduledSync() {
    if (state.lastSyncTime != null) {
      final nextSync = state.lastSyncTime!.add(_config.periodicSyncInterval);
      state = state.copyWith(nextScheduledSync: nextSync);
    }
  }

  /// 公共方法

  /// 计划任务
  void scheduleTask(
    BackgroundSyncTaskType type, {
    OperationPriority priority = OperationPriority.normal,
    DateTime? scheduledAt,
    Map<String, dynamic>? data,
  }) {
    final task = BackgroundSyncTask(
      id: _generateTaskId(),
      type: type,
      createdAt: DateTime.now(),
      scheduledAt: scheduledAt,
      priority: priority,
      data: data,
    );

    final updatedPendingTasks = List<BackgroundSyncTask>.from(state.pendingTasks)
      ..add(task);

    state = state.copyWith(pendingTasks: updatedPendingTasks);

    _log('Scheduled background sync task: ${type.name} (Priority: ${priority.name})');
  }

  /// 立即执行同步
  Future<Result<void, String>> syncNow({
    BackgroundSyncTaskType type = BackgroundSyncTaskType.emergencySync,
    Map<String, dynamic>? data,
  }) async {
    if (!state.isGoodForSync) {
      return const Result.failure('Network conditions not suitable for sync');
    }

    try {
      final task = BackgroundSyncTask(
        id: _generateTaskId(),
        type: type,
        createdAt: DateTime.now(),
        startedAt: DateTime.now(),
        priority: OperationPriority.critical,
        data: data,
      );

      await _performTask(task);
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Immediate sync failed: $e');
    }
  }

  /// 暂停后台同步
  void pauseBackgroundSync() {
    _schedulerTimer?.cancel();
    state = state.copyWith(isActive: false);
    _log('Background sync paused');
  }

  /// 恢复后台同步
  void resumeBackgroundSync() {
    if (_config.backgroundSyncEnabled) {
      _startScheduler();
      state = state.copyWith(isActive: true);
      _log('Background sync resumed');
    }
  }

  /// 更新配置
  void updateConfig(BackgroundSyncConfig config) {
    _config = config;
    
    if (config.backgroundSyncEnabled) {
      _startScheduler();
    } else {
      _schedulerTimer?.cancel();
    }
    
    _log('Background sync config updated');
  }

  /// 清理失败任务
  void clearFailedTasks() {
    state = state.copyWith(failedTasks: []);
    _log('Failed tasks cleared');
  }

  /// 重试失败任务
  void retryFailedTasks() {
    final retryableTasks = state.failedTasks
        .where((task) => task.canRetry)
        .map((task) => task.copyWith(
          retryCount: task.retryCount + 1,
          error: null,
          completedAt: null,
        ))
        .toList();

    final updatedPendingTasks = List<BackgroundSyncTask>.from(state.pendingTasks)
      ..addAll(retryableTasks);

    final updatedFailedTasks = state.failedTasks
        .where((task) => !task.canRetry)
        .toList();

    state = state.copyWith(
      pendingTasks: updatedPendingTasks,
      failedTasks: updatedFailedTasks,
    );

    _log('Retrying ${retryableTasks.length} failed tasks');
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    return {
      'totalSyncCount': state.totalSyncCount,
      'successfulSyncCount': state.successfulSyncCount,
      'failedSyncCount': state.failedSyncCount,
      'successRate': state.successRate,
      'averageSyncDuration': state.averageSyncDuration.inMilliseconds,
      'lastSyncTime': state.lastSyncTime?.toIso8601String(),
      'nextScheduledSync': state.nextScheduledSync?.toIso8601String(),
      'pendingTasksCount': state.pendingTasks.length,
      'runningTasksCount': state.runningTasks.length,
      'completedTasksCount': state.completedTasks.length,
      'failedTasksCount': state.failedTasks.length,
      'networkCondition': state.networkCondition.name,
      'isGoodForSync': state.isGoodForSync,
    };
  }

  /// 生成任务ID
  String _generateTaskId() {
    return 'bg_sync_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';
  }

  /// 日志记录
  void _log(String message) {
    if (_config.enableDebugLogging) {
      debugPrint('🔄 BackgroundSync: $message');
    }
  }

  /// 错误日志记录
  void _logError(String message) {
    if (_config.enableDebugLogging) {
      debugPrint('❌ BackgroundSync Error: $message');
    }
  }

  /// 释放资源
  @override
  void dispose() {
    _schedulerTimer?.cancel();
    _monitoringTimer?.cancel();
    
    super.dispose();
  }
}

/// 后台同步任务完成事件
class BackgroundSyncTaskCompletedEvent extends AppEvent {
  const BackgroundSyncTaskCompletedEvent({
    required this.task,
    required this.success,
  });

  final BackgroundSyncTask task;
  final bool success;

  @override
  String get type => 'background_sync_task_completed';

  @override
  Map<String, dynamic> toJson() => {
    'task_id': task.id,
    'task_type': task.type.name,
    'success': success,
    'duration': task.duration?.inMilliseconds,
    'error': task.error,
    'completed_at': task.completedAt?.toIso8601String(),
  };
}

/// Riverpod 提供器
final backgroundSyncConfigProvider = StateProvider<BackgroundSyncConfig>((ref) {
  return const BackgroundSyncConfig();
});

final backgroundSyncServiceProvider = StateNotifierProvider<BackgroundSyncService, BackgroundSyncState>((ref) {
  final config = ref.watch(backgroundSyncConfigProvider);
  return BackgroundSyncService(ref, config: config);
});

/// 便捷访问提供器
final backgroundSyncStateProvider = Provider<BackgroundSyncState>((ref) {
  return ref.watch(backgroundSyncServiceProvider);
});

final isBackgroundSyncActiveProvider = Provider<bool>((ref) {
  return ref.watch(backgroundSyncServiceProvider.select((state) => state.isActive));
});

final backgroundSyncStatisticsProvider = Provider<Map<String, dynamic>>((ref) {
  final service = ref.read(backgroundSyncServiceProvider.notifier);
  return service.getStatistics();
});

/// 扩展方法
extension BackgroundSyncServiceExtensions on BackgroundSyncService {
  /// 检查是否适合同步
  bool get canSyncNow => state.isGoodForSync && !state.hasRunningTasks;
  
  /// 获取下次同步时间
  DateTime? get nextSyncTime => state.nextScheduledSync;
  
  /// 获取最近的错误
  String? get lastError => state.error;
  
  /// 是否有待处理的高优先级任务
  bool get hasHighPriorityTasks {
    return state.pendingTasks.any((task) => 
      task.priority == OperationPriority.high || 
      task.priority == OperationPriority.critical
    );
  }
} 