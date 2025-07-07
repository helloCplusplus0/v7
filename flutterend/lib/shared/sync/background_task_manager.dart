// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workmanager/workmanager.dart' as workmanager;

import 'package:v7_flutter_app/shared/connectivity/network_monitor.dart';
import '../offline/offline_indicator.dart';
import 'package:v7_flutter_app/shared/sync/background_sync_service.dart';
import 'package:v7_flutter_app/shared/sync/data_sync_providers.dart';
import 'package:v7_flutter_app/shared/sync/smart_sync_scheduler.dart';
import 'package:v7_flutter_app/shared/sync/sync_manager.dart';
import 'package:v7_flutter_app/shared/types/result.dart';

/// 后台任务类型
enum BackgroundTaskType {
  /// 定期同步任务
  periodicSync,
  /// 网络恢复同步
  networkRecoverySync,
  /// 离线队列处理
  offlineQueueProcessing,
  /// 数据清理任务
  dataCleanup,
  /// 缓存优化任务
  cacheOptimization,
  /// 健康检查任务
  healthCheck,
}

/// 后台任务配置
@immutable
class BackgroundTaskConfig {
  const BackgroundTaskConfig({
    this.enablePeriodicSync = true,
    this.periodicSyncInterval = const Duration(hours: 1),
    this.enableNetworkRecoverySync = true,
    this.networkRecoveryDelay = const Duration(minutes: 2),
    this.enableOfflineQueueProcessing = true,
    this.enableDataCleanup = true,
    this.dataCleanupInterval = const Duration(days: 1),
    this.enableCacheOptimization = true,
    this.cacheOptimizationInterval = const Duration(hours: 6),
    this.enableHealthCheck = true,
    this.healthCheckInterval = const Duration(minutes: 30),
    this.maxTaskDuration = const Duration(minutes: 15),
    this.enableBatteryOptimization = true,
    this.batteryThreshold = 0.15,
    this.enableWifiOnlyMode = false,
    this.enableDebugLogging = false,
    this.retryAttempts = 3,
    this.retryDelay = const Duration(minutes: 5),
  });

  /// 启用定期同步
  final bool enablePeriodicSync;
  /// 定期同步间隔
  final Duration periodicSyncInterval;
  /// 启用网络恢复同步
  final bool enableNetworkRecoverySync;
  /// 网络恢复延迟
  final Duration networkRecoveryDelay;
  /// 启用离线队列处理
  final bool enableOfflineQueueProcessing;
  /// 启用数据清理
  final bool enableDataCleanup;
  /// 数据清理间隔
  final Duration dataCleanupInterval;
  /// 启用缓存优化
  final bool enableCacheOptimization;
  /// 缓存优化间隔
  final Duration cacheOptimizationInterval;
  /// 启用健康检查
  final bool enableHealthCheck;
  /// 健康检查间隔
  final Duration healthCheckInterval;
  /// 最大任务持续时间
  final Duration maxTaskDuration;
  /// 启用电池优化
  final bool enableBatteryOptimization;
  /// 电池阈值
  final double batteryThreshold;
  /// 仅WiFi模式
  final bool enableWifiOnlyMode;
  /// 启用调试日志
  final bool enableDebugLogging;
  /// 重试次数
  final int retryAttempts;
  /// 重试延迟
  final Duration retryDelay;

  BackgroundTaskConfig copyWith({
    bool? enablePeriodicSync,
    Duration? periodicSyncInterval,
    bool? enableNetworkRecoverySync,
    Duration? networkRecoveryDelay,
    bool? enableOfflineQueueProcessing,
    bool? enableDataCleanup,
    Duration? dataCleanupInterval,
    bool? enableCacheOptimization,
    Duration? cacheOptimizationInterval,
    bool? enableHealthCheck,
    Duration? healthCheckInterval,
    Duration? maxTaskDuration,
    bool? enableBatteryOptimization,
    double? batteryThreshold,
    bool? enableWifiOnlyMode,
    bool? enableDebugLogging,
    int? retryAttempts,
    Duration? retryDelay,
  }) {
    return BackgroundTaskConfig(
      enablePeriodicSync: enablePeriodicSync ?? this.enablePeriodicSync,
      periodicSyncInterval: periodicSyncInterval ?? this.periodicSyncInterval,
      enableNetworkRecoverySync: enableNetworkRecoverySync ?? this.enableNetworkRecoverySync,
      networkRecoveryDelay: networkRecoveryDelay ?? this.networkRecoveryDelay,
      enableOfflineQueueProcessing: enableOfflineQueueProcessing ?? this.enableOfflineQueueProcessing,
      enableDataCleanup: enableDataCleanup ?? this.enableDataCleanup,
      dataCleanupInterval: dataCleanupInterval ?? this.dataCleanupInterval,
      enableCacheOptimization: enableCacheOptimization ?? this.enableCacheOptimization,
      cacheOptimizationInterval: cacheOptimizationInterval ?? this.cacheOptimizationInterval,
      enableHealthCheck: enableHealthCheck ?? this.enableHealthCheck,
      healthCheckInterval: healthCheckInterval ?? this.healthCheckInterval,
      maxTaskDuration: maxTaskDuration ?? this.maxTaskDuration,
      enableBatteryOptimization: enableBatteryOptimization ?? this.enableBatteryOptimization,
      batteryThreshold: batteryThreshold ?? this.batteryThreshold,
      enableWifiOnlyMode: enableWifiOnlyMode ?? this.enableWifiOnlyMode,
      enableDebugLogging: enableDebugLogging ?? this.enableDebugLogging,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
    );
  }
}

/// 后台任务状态
@immutable
class BackgroundTaskState {
  const BackgroundTaskState({
    this.isInitialized = false,
    this.isRunning = false,
    this.lastExecutionTime,
    this.nextScheduledTime,
    this.executionCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.averageExecutionTime = Duration.zero,
    this.lastError,
    this.registeredTasks = const {},
    this.taskStatistics = const {},
  });

  /// 是否已初始化
  final bool isInitialized;
  /// 是否正在运行
  final bool isRunning;
  /// 最后执行时间
  final DateTime? lastExecutionTime;
  /// 下次计划时间
  final DateTime? nextScheduledTime;
  /// 执行次数
  final int executionCount;
  /// 成功次数
  final int successCount;
  /// 失败次数
  final int failureCount;
  /// 平均执行时间
  final Duration averageExecutionTime;
  /// 最后错误
  final String? lastError;
  /// 已注册任务
  final Map<BackgroundTaskType, bool> registeredTasks;
  /// 任务统计
  final Map<BackgroundTaskType, Map<String, dynamic>> taskStatistics;

  /// 成功率
  double get successRate => executionCount > 0 ? successCount / executionCount : 0.0;

  /// 是否有错误
  bool get hasError => lastError != null;

  BackgroundTaskState copyWith({
    bool? isInitialized,
    bool? isRunning,
    DateTime? lastExecutionTime,
    DateTime? nextScheduledTime,
    int? executionCount,
    int? successCount,
    int? failureCount,
    Duration? averageExecutionTime,
    String? lastError,
    Map<BackgroundTaskType, bool>? registeredTasks,
    Map<BackgroundTaskType, Map<String, dynamic>>? taskStatistics,
  }) {
    return BackgroundTaskState(
      isInitialized: isInitialized ?? this.isInitialized,
      isRunning: isRunning ?? this.isRunning,
      lastExecutionTime: lastExecutionTime ?? this.lastExecutionTime,
      nextScheduledTime: nextScheduledTime ?? this.nextScheduledTime,
      executionCount: executionCount ?? this.executionCount,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      averageExecutionTime: averageExecutionTime ?? this.averageExecutionTime,
      lastError: lastError,
      registeredTasks: registeredTasks ?? this.registeredTasks,
      taskStatistics: taskStatistics ?? this.taskStatistics,
    );
  }
}

/// 后台任务管理器
class BackgroundTaskManager extends StateNotifier<BackgroundTaskState> {
  BackgroundTaskManager({
    required BackgroundTaskConfig config,
    required this.syncManager,
    required this.networkMonitor,
    required this.offlineIndicator,
    required this.backgroundSyncService,
    required this.dataSyncProviderManager,
    required this.smartSyncScheduler,
  }) : _config = config,
       super(const BackgroundTaskState());

  final BackgroundTaskConfig _config;
  final SyncManager syncManager;
  final NetworkMonitor networkMonitor;
  final GlobalOfflineIndicator offlineIndicator;
  final BackgroundSyncService backgroundSyncService;
  final DataSyncProviderManager dataSyncProviderManager;
  final SmartSyncScheduler smartSyncScheduler;

  static const String _periodicSyncTaskName = 'periodic_sync_task';
  static const String _networkRecoveryTaskName = 'network_recovery_task';
  static const String _offlineQueueTaskName = 'offline_queue_task';
  static const String _dataCleanupTaskName = 'data_cleanup_task';
  static const String _cacheOptimizationTaskName = 'cache_optimization_task';
  static const String _healthCheckTaskName = 'health_check_task';
  static const String _isolatePortName = 'background_task_isolate';

  /// 初始化后台任务管理器
  Future<Result<void, String>> initialize() async {
    try {
      // 初始化Workmanager
      await workmanager.Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: _config.enableDebugLogging,
      );

      // 设置isolate通信
      await _setupIsolateCommunication();

      // 注册任务
      await _registerTasks();

      state = state.copyWith(isInitialized: true);
      return const Result.success(null);
    } catch (e) {
      final error = 'Failed to initialize background task manager: $e';
      state = state.copyWith(lastError: error);
      return Result.failure(error);
    }
  }

  /// 注册所有任务
  Future<void> _registerTasks() async {
    final registeredTasks = <BackgroundTaskType, bool>{};

    // 注册定期同步任务
    if (_config.enablePeriodicSync) {
      await workmanager.Workmanager().registerPeriodicTask(
        _periodicSyncTaskName,
        _periodicSyncTaskName,
        frequency: _config.periodicSyncInterval,
        inputData: {
          'taskType': BackgroundTaskType.periodicSync.name,
          'config': _configToJson(),
        },
      );
      registeredTasks[BackgroundTaskType.periodicSync] = true;
    }

    // 注册网络恢复任务
    if (_config.enableNetworkRecoverySync) {
      await workmanager.Workmanager().registerOneOffTask(
        _networkRecoveryTaskName,
        _networkRecoveryTaskName,
        constraints: workmanager.Constraints(
          networkType: workmanager.NetworkType.connected,
          requiresBatteryNotLow: _config.enableBatteryOptimization,
        ),
        inputData: {
          'taskType': BackgroundTaskType.networkRecoverySync.name,
          'config': _configToJson(),
        },
      );
      registeredTasks[BackgroundTaskType.networkRecoverySync] = true;
    }

    // 注册离线队列处理任务
    if (_config.enableOfflineQueueProcessing) {
      await workmanager.Workmanager().registerOneOffTask(
        _offlineQueueTaskName,
        _offlineQueueTaskName,
        constraints: workmanager.Constraints(
          networkType: workmanager.NetworkType.connected,
          requiresBatteryNotLow: _config.enableBatteryOptimization,
        ),
        inputData: {
          'taskType': BackgroundTaskType.offlineQueueProcessing.name,
          'config': _configToJson(),
        },
      );
      registeredTasks[BackgroundTaskType.offlineQueueProcessing] = true;
    }

    // 注册数据清理任务
    if (_config.enableDataCleanup) {
      await workmanager.Workmanager().registerPeriodicTask(
        _dataCleanupTaskName,
        _dataCleanupTaskName,
        frequency: _config.dataCleanupInterval,
        inputData: {
          'taskType': BackgroundTaskType.dataCleanup.name,
          'config': _configToJson(),
        },
      );
      registeredTasks[BackgroundTaskType.dataCleanup] = true;
    }

    // 注册缓存优化任务
    if (_config.enableCacheOptimization) {
      await workmanager.Workmanager().registerPeriodicTask(
        _cacheOptimizationTaskName,
        _cacheOptimizationTaskName,
        frequency: _config.cacheOptimizationInterval,
        inputData: {
          'taskType': BackgroundTaskType.cacheOptimization.name,
          'config': _configToJson(),
        },
      );
      registeredTasks[BackgroundTaskType.cacheOptimization] = true;
    }

    // 注册健康检查任务
    if (_config.enableHealthCheck) {
      await workmanager.Workmanager().registerPeriodicTask(
        _healthCheckTaskName,
        _healthCheckTaskName,
        frequency: _config.healthCheckInterval,
        inputData: {
          'taskType': BackgroundTaskType.healthCheck.name,
          'config': _configToJson(),
        },
      );
      registeredTasks[BackgroundTaskType.healthCheck] = true;
    }

    state = state.copyWith(registeredTasks: registeredTasks);
  }

  /// 设置isolate通信
  Future<void> _setupIsolateCommunication() async {
    final receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(receivePort.sendPort, _isolatePortName);
    
    receivePort.listen((dynamic data) {
      if (data is Map<String, dynamic>) {
        _handleIsolateMessage(data);
      }
    });
  }

  /// 处理isolate消息
  void _handleIsolateMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    
    switch (type) {
      case 'task_started':
        _handleTaskStarted(message);
      case 'task_completed':
        _handleTaskCompleted(message);
      case 'task_failed':
        _handleTaskFailed(message);
    }
  }

  /// 处理任务开始
  void _handleTaskStarted(Map<String, dynamic> message) {
    state = state.copyWith(
      isRunning: true,
      lastExecutionTime: DateTime.now(),
    );
    
    _log('Background task started: ${message['taskName']}');
  }

  /// 处理任务完成
  void _handleTaskCompleted(Map<String, dynamic> message) {
    final duration = Duration(milliseconds: message['duration'] as int? ?? 0);
    
    state = state.copyWith(
      isRunning: false,
      executionCount: state.executionCount + 1,
      successCount: state.successCount + 1,
      averageExecutionTime: _calculateAverageExecutionTime(duration),
      lastError: null,
    );
    
    _log('Background task completed: ${message['taskName']} in ${duration.inMilliseconds}ms');
  }

  /// 处理任务失败
  void _handleTaskFailed(Map<String, dynamic> message) {
    final error = message['error'] as String? ?? 'Unknown error';
    
    state = state.copyWith(
      isRunning: false,
      executionCount: state.executionCount + 1,
      failureCount: state.failureCount + 1,
      lastError: error,
    );
    
    _log('Background task failed: ${message['taskName']} - $error');
  }

  /// 计算平均执行时间
  Duration _calculateAverageExecutionTime(Duration newDuration) {
    if (state.successCount == 0) return newDuration;
    
    final totalMilliseconds = state.averageExecutionTime.inMilliseconds * state.successCount +
                             newDuration.inMilliseconds;
    final newCount = state.successCount + 1;
    
    return Duration(milliseconds: (totalMilliseconds / newCount).round());
  }

  /// 配置转JSON
  Map<String, dynamic> _configToJson() {
    return {
      'enablePeriodicSync': _config.enablePeriodicSync,
      'periodicSyncInterval': _config.periodicSyncInterval.inMilliseconds,
      'enableNetworkRecoverySync': _config.enableNetworkRecoverySync,
      'networkRecoveryDelay': _config.networkRecoveryDelay.inMilliseconds,
      'enableOfflineQueueProcessing': _config.enableOfflineQueueProcessing,
      'enableDataCleanup': _config.enableDataCleanup,
      'dataCleanupInterval': _config.dataCleanupInterval.inMilliseconds,
      'enableCacheOptimization': _config.enableCacheOptimization,
      'cacheOptimizationInterval': _config.cacheOptimizationInterval.inMilliseconds,
      'enableHealthCheck': _config.enableHealthCheck,
      'healthCheckInterval': _config.healthCheckInterval.inMilliseconds,
      'maxTaskDuration': _config.maxTaskDuration.inMilliseconds,
      'enableBatteryOptimization': _config.enableBatteryOptimization,
      'batteryThreshold': _config.batteryThreshold,
      'enableWifiOnlyMode': _config.enableWifiOnlyMode,
      'enableDebugLogging': _config.enableDebugLogging,
      'retryAttempts': _config.retryAttempts,
      'retryDelay': _config.retryDelay.inMilliseconds,
    };
  }

  /// 触发一次性任务
  Future<Result<void, String>> triggerOneOffTask(BackgroundTaskType taskType) async {
    if (!state.isInitialized) {
      return const Result.failure('Background task manager not initialized');
    }

    try {
      final taskName = _getTaskName(taskType);
      
      await workmanager.Workmanager().registerOneOffTask(
        '${taskName}_manual',
        taskName,
        constraints: workmanager.Constraints(
          networkType: _config.enableWifiOnlyMode ? workmanager.NetworkType.unmetered : workmanager.NetworkType.connected,
          requiresBatteryNotLow: _config.enableBatteryOptimization,
        ),
        inputData: {
          'taskType': taskType.name,
          'config': _configToJson(),
          'isManual': true,
        },
      );

      _log('Triggered one-off task: $taskName');
      return const Result.success(null);
    } catch (e) {
      final error = 'Failed to trigger task: $e';
      state = state.copyWith(lastError: error);
      return Result.failure(error);
    }
  }

  /// 取消任务
  Future<Result<void, String>> cancelTask(BackgroundTaskType taskType) async {
    if (!state.isInitialized) {
      return const Result.failure('Background task manager not initialized');
    }

    try {
      final taskName = _getTaskName(taskType);
      await workmanager.Workmanager().cancelByUniqueName(taskName);

      final updatedTasks = Map<BackgroundTaskType, bool>.from(state.registeredTasks);
      updatedTasks[taskType] = false;
      
      state = state.copyWith(registeredTasks: updatedTasks);
      
      _log('Cancelled task: $taskName');
      return const Result.success(null);
    } catch (e) {
      final error = 'Failed to cancel task: $e';
      state = state.copyWith(lastError: error);
      return Result.failure(error);
    }
  }

  /// 取消所有任务
  Future<Result<void, String>> cancelAllTasks() async {
    if (!state.isInitialized) {
      return const Result.failure('Background task manager not initialized');
    }

    try {
      await workmanager.Workmanager().cancelAll();
      
      state = state.copyWith(registeredTasks: {});
      
      _log('Cancelled all tasks');
      return const Result.success(null);
    } catch (e) {
      final error = 'Failed to cancel all tasks: $e';
      state = state.copyWith(lastError: error);
      return Result.failure(error);
    }
  }

  /// 获取任务名称
  String _getTaskName(BackgroundTaskType taskType) {
    switch (taskType) {
      case BackgroundTaskType.periodicSync:
        return _periodicSyncTaskName;
      case BackgroundTaskType.networkRecoverySync:
        return _networkRecoveryTaskName;
      case BackgroundTaskType.offlineQueueProcessing:
        return _offlineQueueTaskName;
      case BackgroundTaskType.dataCleanup:
        return _dataCleanupTaskName;
      case BackgroundTaskType.cacheOptimization:
        return _cacheOptimizationTaskName;
      case BackgroundTaskType.healthCheck:
        return _healthCheckTaskName;
    }
  }

  /// 获取任务状态
  bool isTaskRegistered(BackgroundTaskType taskType) {
    return state.registeredTasks[taskType] ?? false;
  }

  /// 获取任务统计
  Map<String, dynamic>? getTaskStatistics(BackgroundTaskType taskType) {
    return state.taskStatistics[taskType];
  }

  /// 更新配置
  Future<Result<void, String>> updateConfig(BackgroundTaskConfig newConfig) async {
    try {
      // 取消现有任务
      await cancelAllTasks();
      
      // 更新配置
      final updatedManager = BackgroundTaskManager(
        config: newConfig,
        syncManager: syncManager,
        networkMonitor: networkMonitor,
        offlineIndicator: offlineIndicator,
        backgroundSyncService: backgroundSyncService,
        dataSyncProviderManager: dataSyncProviderManager,
        smartSyncScheduler: smartSyncScheduler,
      );
      
      // 重新注册任务
      await updatedManager._registerTasks();
      
      _log('Configuration updated');
      return const Result.success(null);
    } catch (e) {
      final error = 'Failed to update configuration: $e';
      state = state.copyWith(lastError: error);
      return Result.failure(error);
    }
  }

  /// 执行定期同步
  Future<void> _executePeriodicSync() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    // 实现定期同步逻辑
  }

  /// 执行网络恢复同步
  Future<void> _executeNetworkRecoverySync() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    // 实现网络恢复同步逻辑
  }

  /// 执行离线队列处理
  Future<void> _executeOfflineQueueProcessing() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    // 实现离线队列处理逻辑
  }

  /// 执行数据清理
  Future<void> _executeDataCleanup() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    // 实现数据清理逻辑
  }

  /// 执行缓存优化
  Future<void> _executeCacheOptimization() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    // 实现缓存优化逻辑
  }

  /// 执行健康检查
  Future<void> _executeHealthCheck() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    // 实现健康检查逻辑
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    return {
      'isInitialized': state.isInitialized,
      'isRunning': state.isRunning,
      'executionCount': state.executionCount,
      'successCount': state.successCount,
      'failureCount': state.failureCount,
      'successRate': state.successRate,
      'averageExecutionTime': state.averageExecutionTime?.inMilliseconds,
      'lastExecutionTime': state.lastExecutionTime?.toIso8601String(),
      'registeredTasks': state.registeredTasks.length,
      'hasError': state.hasError,
      'lastError': state.lastError,
    };
  }

  /// 日志记录
  void _log(String message) {
    if (_config.enableDebugLogging) {
      debugPrint('[BackgroundTaskManager] $message');
    }
  }
}

/// 后台任务回调分发器
@pragma('vm:entry-point')
void callbackDispatcher() {
  workmanager.Workmanager().executeTask((String task, Map<String, dynamic>? inputData) async {
    try {
      final taskType = inputData?['taskType'] as String?;
      final config = inputData?['config'] as Map<String, dynamic>?;
      
      if (taskType == null || config == null) {
        return Future.value(false);
      }

      final backgroundTaskType = BackgroundTaskType.values.firstWhere(
        (type) => type.name == taskType,
        orElse: () => BackgroundTaskType.periodicSync,
      );

      // 发送任务开始消息
      final sendPort = IsolateNameServer.lookupPortByName('background_task_isolate');
      sendPort?.send({
        'type': 'task_started',
        'taskName': task,
        'taskType': taskType,
      });

      final startTime = DateTime.now();
      bool success = false;

      try {
        // 执行任务
        switch (backgroundTaskType) {
          case BackgroundTaskType.periodicSync:
            success = await _executePeriodicSyncTask(config);
          case BackgroundTaskType.networkRecoverySync:
            success = await _executeNetworkRecoverySyncTask(config);
          case BackgroundTaskType.offlineQueueProcessing:
            success = await _executeOfflineQueueProcessingTask(config);
          case BackgroundTaskType.dataCleanup:
            success = await _executeDataCleanupTask(config);
          case BackgroundTaskType.cacheOptimization:
            success = await _executeCacheOptimizationTask(config);
          case BackgroundTaskType.healthCheck:
            success = await _executeHealthCheckTask(config);
        }

        // 发送任务完成消息
        final duration = DateTime.now().difference(startTime);
        sendPort?.send({
          'type': 'task_completed',
          'taskName': task,
          'taskType': taskType,
          'duration': duration.inMilliseconds,
        });

        return Future.value(success);
      } catch (e) {
        // 发送任务失败消息
        sendPort?.send({
          'type': 'task_failed',
          'taskName': task,
          'taskType': taskType,
          'error': e.toString(),
        });

        return Future.value(false);
      }
    } catch (e) {
      return Future.value(false);
    }
  });
}

/// 执行定期同步任务
Future<bool> _executePeriodicSyncTask(Map<String, dynamic> config) async {
  // 实现定期同步逻辑
  return true;
}

/// 执行网络恢复同步任务
Future<bool> _executeNetworkRecoverySyncTask(Map<String, dynamic> config) async {
  // 实现网络恢复同步逻辑
  return true;
}

/// 执行离线队列处理任务
Future<bool> _executeOfflineQueueProcessingTask(Map<String, dynamic> config) async {
  // 实现离线队列处理逻辑
  return true;
}

/// 执行数据清理任务
Future<bool> _executeDataCleanupTask(Map<String, dynamic> config) async {
  // 实现数据清理逻辑
  return true;
}

/// 执行缓存优化任务
Future<bool> _executeCacheOptimizationTask(Map<String, dynamic> config) async {
  // 实现缓存优化逻辑
  return true;
}

/// 执行健康检查任务
Future<bool> _executeHealthCheckTask(Map<String, dynamic> config) async {
  // 实现健康检查逻辑
  return true;
}

/// Riverpod 提供器
final backgroundTaskConfigProvider = StateProvider<BackgroundTaskConfig>((ref) {
  return const BackgroundTaskConfig();
});

// 简化的后台任务管理器提供器
final backgroundTaskManagerProvider = StateNotifierProvider<BackgroundTaskManager, BackgroundTaskState>((ref) {
  final config = ref.watch(backgroundTaskConfigProvider);
  
  // 获取基础依赖项
  final syncManager = ref.read(syncManagerProvider);
  final networkMonitor = ref.read(networkMonitorProvider.notifier);
  final offlineIndicator = ref.read(offlineIndicatorProvider.notifier);
  final dataSyncProviderManager = ref.read(dataSyncProviderManagerProvider);
  
  // 创建简化的服务实例
  final backgroundSyncService = BackgroundSyncService(ref);
  final smartSyncScheduler = SmartSyncScheduler(ref);
  
  return BackgroundTaskManager(
    config: config,
    syncManager: syncManager,
    networkMonitor: networkMonitor,
    offlineIndicator: offlineIndicator,
    backgroundSyncService: backgroundSyncService,
    dataSyncProviderManager: dataSyncProviderManager,
    smartSyncScheduler: smartSyncScheduler,
  );
});

/// 便捷访问提供器
final backgroundTaskStateProvider = Provider<BackgroundTaskState>((ref) {
  return ref.watch(backgroundTaskManagerProvider);
});

final isBackgroundTaskRunningProvider = Provider<bool>((ref) {
  return ref.watch(backgroundTaskManagerProvider.select((state) => state.isRunning));
});

final backgroundTaskStatisticsProvider = Provider<Map<String, dynamic>>((ref) {
  final manager = ref.read(backgroundTaskManagerProvider.notifier);
  return manager.getStatistics();
});

/// 扩展方法
extension BackgroundTaskManagerExtensions on BackgroundTaskManager {
  /// 是否任务正在运行
  bool get isTaskRunning => state.isRunning;
  
  /// 获取最后执行时间
  DateTime? get lastExecutionTime => state.lastExecutionTime;
  
  /// 获取成功率
  double get successRate => state.successRate;
  
  /// 是否有错误
  bool get hasError => state.hasError;
  
  /// 获取已注册任务数量
  int get registeredTaskCount => state.registeredTasks.values.where((v) => v).length;
}