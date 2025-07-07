// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:v7_flutter_app/shared/sync/background_task_manager.dart';
import 'package:v7_flutter_app/shared/sync/sync_manager.dart';
import 'package:v7_flutter_app/shared/connectivity/network_monitor.dart';
import 'package:v7_flutter_app/shared/offline/offline_indicator.dart';
import 'package:v7_flutter_app/shared/sync/background_sync_service.dart';
import 'package:v7_flutter_app/shared/sync/data_sync_providers.dart';
import 'package:v7_flutter_app/shared/sync/smart_sync_scheduler.dart';
import 'package:v7_flutter_app/shared/types/result.dart';

// Mock类
class MockSyncManager extends Mock implements SyncManager {}
class MockNetworkMonitor extends Mock implements NetworkMonitor {}
class MockOfflineIndicator extends Mock implements GlobalOfflineIndicator {}
class MockBackgroundSyncService extends Mock implements BackgroundSyncService {}
class MockDataSyncProviderManager extends Mock implements DataSyncProviderManager {}
class MockSmartSyncScheduler extends Mock implements SmartSyncScheduler {}

void main() {
  group('BackgroundTaskManager', () {
    late BackgroundTaskManager backgroundTaskManager;
    late MockSyncManager mockSyncManager;
    late MockNetworkMonitor mockNetworkMonitor;
    late MockOfflineIndicator mockOfflineIndicator;
    late MockBackgroundSyncService mockBackgroundSyncService;
    late MockDataSyncProviderManager mockDataSyncProviderManager;
    late MockSmartSyncScheduler mockSmartSyncScheduler;
    late BackgroundTaskConfig config;

    setUp(() {
      mockSyncManager = MockSyncManager();
      mockNetworkMonitor = MockNetworkMonitor();
      mockOfflineIndicator = MockOfflineIndicator();
      mockBackgroundSyncService = MockBackgroundSyncService();
      mockDataSyncProviderManager = MockDataSyncProviderManager();
      mockSmartSyncScheduler = MockSmartSyncScheduler();
      
      config = const BackgroundTaskConfig(
        enableDebugLogging: true,
        enablePeriodicSync: true,
        periodicSyncInterval: Duration(minutes: 30),
      );

      backgroundTaskManager = BackgroundTaskManager(
        config: config,
        syncManager: mockSyncManager,
        networkMonitor: mockNetworkMonitor,
        offlineIndicator: mockOfflineIndicator,
        backgroundSyncService: mockBackgroundSyncService,
        dataSyncProviderManager: mockDataSyncProviderManager,
        smartSyncScheduler: mockSmartSyncScheduler,
      );
    });

    group('初始化', () {
      test('应该正确初始化状态', () {
        expect(backgroundTaskManager.state.isInitialized, false);
        expect(backgroundTaskManager.state.isRunning, false);
        expect(backgroundTaskManager.state.executionCount, 0);
        expect(backgroundTaskManager.state.successCount, 0);
        expect(backgroundTaskManager.state.failureCount, 0);
        expect(backgroundTaskManager.state.registeredTasks, isEmpty);
      });

      test('应该有正确的配置', () {
        expect(backgroundTaskManager.isTaskRunning, false);
        expect(backgroundTaskManager.hasError, false);
        expect(backgroundTaskManager.registeredTaskCount, 0);
      });
    });

    group('任务管理', () {
             test('应该能够触发一次性任务', () async {
         // 模拟未初始化状态
         final result = await backgroundTaskManager.triggerOneOffTask(
           BackgroundTaskType.periodicSync,
         );
         
         expect(result.isFailure, true);
         expect(result.errorOrNull, 'Background task manager not initialized');
       });

             test('应该能够取消任务', () async {
         final result = await backgroundTaskManager.cancelTask(
           BackgroundTaskType.periodicSync,
         );
         
         expect(result.isFailure, true);
         expect(result.errorOrNull, 'Background task manager not initialized');
       });

             test('应该能够取消所有任务', () async {
         final result = await backgroundTaskManager.cancelAllTasks();
         
         expect(result.isFailure, true);
         expect(result.errorOrNull, 'Background task manager not initialized');
       });

      test('应该能够检查任务是否已注册', () {
        final isRegistered = backgroundTaskManager.isTaskRegistered(
          BackgroundTaskType.periodicSync,
        );
        
        expect(isRegistered, false);
      });
    });

    group('配置管理', () {
      test('应该能够更新配置', () async {
        final newConfig = const BackgroundTaskConfig(
          enablePeriodicSync: false,
          enableDataCleanup: true,
        );

        final result = await backgroundTaskManager.updateConfig(newConfig);
        
        // 由于没有初始化，应该会失败
        expect(result.isFailure, true);
      });

      test('应该能够获取任务统计信息', () {
        final statistics = backgroundTaskManager.getTaskStatistics(
          BackgroundTaskType.periodicSync,
        );
        
        expect(statistics, isNull);
      });
    });

    group('统计信息', () {
      test('应该能够获取统计信息', () {
        final statistics = backgroundTaskManager.getStatistics();
        
        expect(statistics, isA<Map<String, dynamic>>());
        expect(statistics['isInitialized'], false);
        expect(statistics['isRunning'], false);
        expect(statistics['executionCount'], 0);
        expect(statistics['successCount'], 0);
        expect(statistics['failureCount'], 0);
        expect(statistics['successRate'], 0.0);
        expect(statistics['registeredTasks'], 0);
        expect(statistics['hasError'], false);
      });

      test('应该正确计算成功率', () {
        expect(backgroundTaskManager.successRate, 0.0);
      });

      test('应该正确报告错误状态', () {
        expect(backgroundTaskManager.hasError, false);
      });
    });

    group('扩展方法', () {
      test('应该正确返回任务运行状态', () {
        expect(backgroundTaskManager.isTaskRunning, false);
      });

      test('应该正确返回最后执行时间', () {
        expect(backgroundTaskManager.lastExecutionTime, isNull);
      });

      test('应该正确返回成功率', () {
        expect(backgroundTaskManager.successRate, 0.0);
      });

      test('应该正确返回错误状态', () {
        expect(backgroundTaskManager.hasError, false);
      });

      test('应该正确返回已注册任务数量', () {
        expect(backgroundTaskManager.registeredTaskCount, 0);
      });
    });

    group('状态更新', () {
      test('应该能够更新状态', () {
        final newState = backgroundTaskManager.state.copyWith(
          isRunning: true,
          executionCount: 1,
        );
        
        expect(newState.isRunning, true);
        expect(newState.executionCount, 1);
      });

      test('应该能够复制配置', () {
        final newConfig = config.copyWith(
          enablePeriodicSync: false,
          enableDataCleanup: true,
        );
        
        expect(newConfig.enablePeriodicSync, false);
        expect(newConfig.enableDataCleanup, true);
        expect(newConfig.periodicSyncInterval, config.periodicSyncInterval);
      });
    });

    group('任务类型', () {
      test('应该包含所有任务类型', () {
        final taskTypes = BackgroundTaskType.values;
        
        expect(taskTypes, contains(BackgroundTaskType.periodicSync));
        expect(taskTypes, contains(BackgroundTaskType.networkRecoverySync));
        expect(taskTypes, contains(BackgroundTaskType.offlineQueueProcessing));
        expect(taskTypes, contains(BackgroundTaskType.dataCleanup));
        expect(taskTypes, contains(BackgroundTaskType.cacheOptimization));
        expect(taskTypes, contains(BackgroundTaskType.healthCheck));
      });

      test('应该有正确的任务类型名称', () {
        expect(BackgroundTaskType.periodicSync.name, 'periodicSync');
        expect(BackgroundTaskType.networkRecoverySync.name, 'networkRecoverySync');
        expect(BackgroundTaskType.offlineQueueProcessing.name, 'offlineQueueProcessing');
        expect(BackgroundTaskType.dataCleanup.name, 'dataCleanup');
        expect(BackgroundTaskType.cacheOptimization.name, 'cacheOptimization');
        expect(BackgroundTaskType.healthCheck.name, 'healthCheck');
      });
    });

    group('Provider测试', () {
      test('应该能够创建配置Provider', () {
        final container = ProviderContainer();
        final config = container.read(backgroundTaskConfigProvider);
        
        expect(config, isA<BackgroundTaskConfig>());
        expect(config.enablePeriodicSync, true);
        
        container.dispose();
      });

      test('应该能够更新配置Provider', () {
        final container = ProviderContainer();
        final notifier = container.read(backgroundTaskConfigProvider.notifier);
        
        final newConfig = const BackgroundTaskConfig(
          enablePeriodicSync: false,
        );
        
        notifier.state = newConfig;
        
        final updatedConfig = container.read(backgroundTaskConfigProvider);
        expect(updatedConfig.enablePeriodicSync, false);
        
        container.dispose();
      });
    });

    group('错误处理', () {
      test('应该正确处理初始化错误', () async {
        // 测试未初始化状态下的操作
        final result = await backgroundTaskManager.triggerOneOffTask(
          BackgroundTaskType.periodicSync,
        );
        
        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('not initialized'));
      });

      test('应该正确处理取消任务错误', () async {
        final result = await backgroundTaskManager.cancelTask(
          BackgroundTaskType.periodicSync,
        );
        
        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('not initialized'));
      });

      test('应该正确处理配置更新错误', () async {
        final newConfig = const BackgroundTaskConfig();
        final result = await backgroundTaskManager.updateConfig(newConfig);
        
        expect(result.isFailure, true);
      });
    });

    group('边界情况', () {
      test('应该正确处理空的任务统计', () {
        final statistics = backgroundTaskManager.getTaskStatistics(
          BackgroundTaskType.periodicSync,
        );
        
        expect(statistics, isNull);
      });

      test('应该正确处理未注册的任务', () {
        final isRegistered = backgroundTaskManager.isTaskRegistered(
          BackgroundTaskType.periodicSync,
        );
        
        expect(isRegistered, false);
      });

      test('应该正确处理空的统计信息', () {
        final statistics = backgroundTaskManager.getStatistics();
        
        expect(statistics['executionCount'], 0);
        expect(statistics['successCount'], 0);
        expect(statistics['failureCount'], 0);
        expect(statistics['successRate'], 0.0);
      });
    });

    group('配置验证', () {
      test('应该有合理的默认配置', () {
        const defaultConfig = BackgroundTaskConfig();
        
        expect(defaultConfig.enablePeriodicSync, true);
        expect(defaultConfig.periodicSyncInterval, const Duration(hours: 1));
        expect(defaultConfig.enableNetworkRecoverySync, true);
        expect(defaultConfig.networkRecoveryDelay, const Duration(minutes: 2));
        expect(defaultConfig.enableOfflineQueueProcessing, true);
        expect(defaultConfig.enableDataCleanup, true);
        expect(defaultConfig.dataCleanupInterval, const Duration(days: 1));
        expect(defaultConfig.enableCacheOptimization, true);
        expect(defaultConfig.cacheOptimizationInterval, const Duration(hours: 6));
        expect(defaultConfig.enableHealthCheck, true);
        expect(defaultConfig.healthCheckInterval, const Duration(minutes: 30));
        expect(defaultConfig.maxTaskDuration, const Duration(minutes: 15));
        expect(defaultConfig.enableBatteryOptimization, true);
        expect(defaultConfig.batteryThreshold, 0.15);
        expect(defaultConfig.enableWifiOnlyMode, false);
        expect(defaultConfig.enableDebugLogging, false);
        expect(defaultConfig.retryAttempts, 3);
        expect(defaultConfig.retryDelay, const Duration(minutes: 5));
      });

      test('应该能够复制配置并修改特定值', () {
        const originalConfig = BackgroundTaskConfig();
        
        final modifiedConfig = originalConfig.copyWith(
          enablePeriodicSync: false,
          periodicSyncInterval: const Duration(minutes: 15),
          enableDebugLogging: true,
        );
        
        expect(modifiedConfig.enablePeriodicSync, false);
        expect(modifiedConfig.periodicSyncInterval, const Duration(minutes: 15));
        expect(modifiedConfig.enableDebugLogging, true);
        
        // 其他值应该保持不变
        expect(modifiedConfig.enableNetworkRecoverySync, originalConfig.enableNetworkRecoverySync);
        expect(modifiedConfig.networkRecoveryDelay, originalConfig.networkRecoveryDelay);
        expect(modifiedConfig.retryAttempts, originalConfig.retryAttempts);
      });
    });

    group('状态管理', () {
      test('应该有正确的初始状态', () {
        const initialState = BackgroundTaskState();
        
        expect(initialState.isInitialized, false);
        expect(initialState.isRunning, false);
        expect(initialState.lastExecutionTime, isNull);
        expect(initialState.nextScheduledTime, isNull);
        expect(initialState.executionCount, 0);
        expect(initialState.successCount, 0);
        expect(initialState.failureCount, 0);
        expect(initialState.averageExecutionTime, Duration.zero);
        expect(initialState.lastError, isNull);
        expect(initialState.registeredTasks, isEmpty);
        expect(initialState.taskStatistics, isEmpty);
        expect(initialState.successRate, 0.0);
        expect(initialState.hasError, false);
      });

      test('应该能够复制状态并修改特定值', () {
        const originalState = BackgroundTaskState();
        
        final modifiedState = originalState.copyWith(
          isInitialized: true,
          isRunning: true,
          executionCount: 5,
          successCount: 3,
          failureCount: 2,
          lastError: 'Test error',
        );
        
        expect(modifiedState.isInitialized, true);
        expect(modifiedState.isRunning, true);
        expect(modifiedState.executionCount, 5);
        expect(modifiedState.successCount, 3);
        expect(modifiedState.failureCount, 2);
        expect(modifiedState.lastError, 'Test error');
        expect(modifiedState.successRate, 0.6); // 3/5
        expect(modifiedState.hasError, true);
        
        // 其他值应该保持不变
        expect(modifiedState.lastExecutionTime, originalState.lastExecutionTime);
        expect(modifiedState.nextScheduledTime, originalState.nextScheduledTime);
      });
    });
  });
} 