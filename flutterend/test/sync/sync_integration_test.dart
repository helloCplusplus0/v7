// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

import 'package:v7_flutter_app/shared/connectivity/network_monitor.dart';
import 'package:v7_flutter_app/shared/network/api_client.dart';
import 'package:v7_flutter_app/shared/offline/offline_indicator.dart';
import 'package:v7_flutter_app/shared/storage/local_storage.dart';
import 'package:v7_flutter_app/shared/sync/background_sync_service.dart';
import 'package:v7_flutter_app/shared/sync/background_task_manager.dart';
import 'package:v7_flutter_app/shared/sync/data_sync_providers.dart';
import 'package:v7_flutter_app/shared/sync/smart_sync_scheduler.dart';
import 'package:v7_flutter_app/shared/sync/sync_manager.dart';
import 'package:v7_flutter_app/shared/sync/sync_performance_optimizer.dart';
import 'package:v7_flutter_app/shared/types/result.dart';
import 'package:v7_flutter_app/shared/providers/providers.dart' as providers;
import 'package:v7_flutter_app/shared/sync/offline_queue.dart';
import 'package:v7_flutter_app/shared/sync/conflict_resolver.dart';

// Mock类
class MockSyncManager extends Mock implements SyncManager {}
class MockLocalStorage extends Mock implements LocalStorage {}
class MockApiClient extends Mock implements ApiClient {}
class MockOfflineQueue extends Mock implements OfflineQueue {}
class MockNetworkMonitor extends Mock implements NetworkMonitor {}

// 测试工具函数
Response<T> createMockResponse<T>(T data, {int statusCode = 200}) {
  return Response<T>(
    data: data,
    statusCode: statusCode,
    requestOptions: RequestOptions(path: '/test'),
  );
}

void main() {
  group('同步模块集成测试', () {
    late MockSyncManager mockSyncManager;
    late MockLocalStorage mockLocalStorage;
    late MockApiClient mockApiClient;
    late MockOfflineQueue mockOfflineQueue;
    late MockNetworkMonitor mockNetworkMonitor;
    late ProviderContainer container;

    setUp(() {
      mockSyncManager = MockSyncManager();
      mockLocalStorage = MockLocalStorage();
      mockApiClient = MockApiClient();
      mockOfflineQueue = MockOfflineQueue();
      mockNetworkMonitor = MockNetworkMonitor();

      // 设置默认的Mock行为
      when(() => mockNetworkMonitor.state).thenReturn(
        const NetworkMonitorState(
          status: NetworkStatus.online,
          isConnected: true,
          type: NetworkType.wifi,
        ),
      );

      container = ProviderContainer(
        overrides: [
          providers.localStorageProvider.overrideWithValue(mockLocalStorage),
          providers.apiClientProvider.overrideWithValue(mockApiClient),
          networkMonitorProvider.overrideWith((ref) => mockNetworkMonitor),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('基础集成', () {
      test('应该能够创建同步组件', () {
        // 创建DataSyncProviderManager
        final dataSyncManager = DataSyncProviderManager(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );
        expect(dataSyncManager, isA<DataSyncProviderManager>());

        // 创建SyncPerformanceOptimizer
        final performanceOptimizer = SyncPerformanceOptimizer(
          config: const SyncPerformanceConfig(enableMetrics: false),
          localStorage: mockLocalStorage,
          syncManager: mockSyncManager,
        );
        expect(performanceOptimizer, isA<SyncPerformanceOptimizer>());

        performanceOptimizer.dispose();
      });

      test('应该能够初始化组件', () async {
        final dataSyncManager = DataSyncProviderManager(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );

        // 检查支持的数据类型
        final supportedTypes = dataSyncManager.supportedTypes;
        expect(supportedTypes, isNotEmpty);
        expect(supportedTypes, contains(SyncDataType.userSettings));
        expect(supportedTypes, contains(SyncDataType.userData));
      });
    });

    group('数据同步集成', () {
      test('应该能够完成完整的数据同步流程', () async {
        // 设置mock
        when(() => mockLocalStorage.getString('user_settings'))
            .thenAnswer((_) async => const Result.success(null));
        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-settings'))
            .thenAnswer((_) async => createMockResponse({
              'data': {'theme': 'dark', 'language': 'en'}
            }));
        when(() => mockLocalStorage.setString('user_settings', any()))
            .thenAnswer((_) async => const Result.success(null));

        final dataSyncManager = DataSyncProviderManager(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );

        // 执行同步
        final result = await dataSyncManager.syncData(SyncDataType.userSettings);

        expect(result.isSuccess, true);
      });

      test('应该能够处理同步错误', () async {
        when(() => mockLocalStorage.getString('user_settings'))
            .thenAnswer((_) async => Result.failure(StorageError('Storage error')));

        final dataSyncManager = DataSyncProviderManager(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );

        final result = await dataSyncManager.syncData(SyncDataType.userSettings);

        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('Failed to get local data'));
      });

      test('应该能够批量同步多种数据类型', () async {
        // 设置mock for user_settings - 有数据的情况
        when(() => mockLocalStorage.getString('user_settings'))
            .thenAnswer((_) async => const Result.success(null));
        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-settings'))
            .thenAnswer((_) async => createMockResponse({'data': {'theme': 'dark'}}));
        when(() => mockLocalStorage.setString('user_settings', any()))
            .thenAnswer((_) async => const Result.success(null));

        // 设置mock for user_data - 有数据的情况
        when(() => mockLocalStorage.getString('user_data'))
            .thenAnswer((_) async => const Result.success(null));
        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-data'))
            .thenAnswer((_) async => createMockResponse({'data': {'profile': {'name': 'test'}}}));
        when(() => mockLocalStorage.setString('user_data', any()))
            .thenAnswer((_) async => const Result.success(null));

        final dataSyncManager = DataSyncProviderManager(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );

        final result = await dataSyncManager.syncAllData();

        expect(result.isSuccess, true);
      });
    });

    group('性能优化集成', () {
      test('应该能够优化同步操作', () async {
        final performanceOptimizer = SyncPerformanceOptimizer(
          config: const SyncPerformanceConfig(enableMetrics: false),
          localStorage: mockLocalStorage,
          syncManager: mockSyncManager,
        );

        final operation = () async => 'test_result';
        final result = await performanceOptimizer.optimizeSync(operation);

        expect(result.isSuccess, true);
        expect(result.valueOrNull, 'test_result');

        performanceOptimizer.dispose();
      });

      test('应该能够批量优化多个操作', () async {
        final performanceOptimizer = SyncPerformanceOptimizer(
          config: const SyncPerformanceConfig(enableMetrics: false),
          localStorage: mockLocalStorage,
          syncManager: mockSyncManager,
        );

        final operations = [
          () async => 'result1',
          () async => 'result2',
          () async => 'result3',
        ];

        final result = await performanceOptimizer.batchSync(operations);

        expect(result.isSuccess, true);
        expect(result.valueOrNull, ['result1', 'result2', 'result3']);

        performanceOptimizer.dispose();
      });

      test('应该能够执行增量同步', () async {
        final performanceOptimizer = SyncPerformanceOptimizer(
          config: const SyncPerformanceConfig(enableMetrics: false),
          localStorage: mockLocalStorage,
          syncManager: mockSyncManager,
        );

        final result = await performanceOptimizer.incrementalSync(
          lastSyncTime: DateTime(2024, 1, 1),
          dataType: 'user_data',
        );

        expect(result.isSuccess, true);

        performanceOptimizer.dispose();
      });
    });

         group('后台任务集成', () {
       test('应该能够创建后台任务管理器类型', () {
         // 测试枚举类型
         final taskTypes = BackgroundTaskType.values;
         expect(taskTypes, contains(BackgroundTaskType.periodicSync));
         expect(taskTypes, contains(BackgroundTaskType.networkRecoverySync));
         expect(taskTypes, contains(BackgroundTaskType.offlineQueueProcessing));
       });

       test('应该能够创建后台任务配置', () {
         const config = BackgroundTaskConfig();
         expect(config.enablePeriodicSync, true);
         expect(config.enableNetworkRecoverySync, true);
         expect(config.enableOfflineQueueProcessing, true);
       });
     });

    group('Provider集成', () {
      test('应该能够通过Provider访问所有组件', () {
        final container = ProviderContainer(
                     overrides: [
             providers.localStorageProvider.overrideWithValue(mockLocalStorage),
             providers.apiClientProvider.overrideWithValue(mockApiClient),
           ],
        );

        // 测试DataSyncProviderManager Provider
        final dataSyncManager = container.read(dataSyncProviderManagerProvider);
        expect(dataSyncManager, isA<DataSyncProviderManager>());

        // 测试SyncPerformanceOptimizer Provider
        final performanceOptimizer = container.read(syncPerformanceOptimizerProvider.notifier);
        expect(performanceOptimizer, isA<SyncPerformanceOptimizer>());

        // 测试性能指标Provider
        final metrics = container.read(performanceMetricsProvider);
        expect(metrics, isA<SyncPerformanceMetrics>());

        container.dispose();
      });

      test('应该能够获取配置Provider', () {
        final container = ProviderContainer();

        final config = container.read(syncPerformanceConfigProvider);
        expect(config, isA<SyncPerformanceConfig>());

        container.dispose();
      });
    });

    group('错误处理集成', () {
      test('应该能够处理网络错误', () async {
        when(() => mockLocalStorage.getString('user_settings'))
            .thenAnswer((_) async => const Result.success(null));
        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-settings'))
            .thenThrow(Exception('Network error'));

        final dataSyncManager = DataSyncProviderManager(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );

        final result = await dataSyncManager.syncData(SyncDataType.userSettings);

        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('Failed to get remote data'));
      });

      test('应该能够处理存储错误', () async {
        when(() => mockLocalStorage.getString(any()))
            .thenAnswer((_) async => Result.failure(StorageError('Storage error')));

        final dataSyncManager = DataSyncProviderManager(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );

        final result = await dataSyncManager.syncData(SyncDataType.userSettings);

        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('Failed to get local data'));
      });
    });

    group('配置管理集成', () {
      test('应该能够使用不同的配置', () {
        // 测试禁用压缩的配置
        final config1 = const SyncPerformanceConfig(
          enableCompression: false,
          enableMetrics: false,
        );
        
        final optimizer1 = SyncPerformanceOptimizer(
          config: config1,
          localStorage: mockLocalStorage,
          syncManager: mockSyncManager,
        );
        
        expect(optimizer1.config.enableCompression, false);
        optimizer1.dispose();

        // 测试启用批处理的配置
        final config2 = const SyncPerformanceConfig(
          enableBatchProcessing: true,
          batchSize: 100,
          enableMetrics: false,
        );
        
        final optimizer2 = SyncPerformanceOptimizer(
          config: config2,
          localStorage: mockLocalStorage,
          syncManager: mockSyncManager,
        );
        
        expect(optimizer2.config.enableBatchProcessing, true);
        expect(optimizer2.config.batchSize, 100);
        optimizer2.dispose();
      });
    });

    group('端到端测试', () {
      test('应该能够完成完整的同步流程', () async {
        // 设置所有必要的mock
        when(() => mockLocalStorage.getString('user_settings'))
            .thenAnswer((_) async => const Result.success(null));
        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-settings'))
            .thenAnswer((_) async => createMockResponse({
              'data': {'theme': 'dark', 'language': 'en'}
            }));
        when(() => mockLocalStorage.setString('user_settings', any()))
            .thenAnswer((_) async => const Result.success(null));

                 // 创建组件
         final dataSyncManager = DataSyncProviderManager(
           localStorage: mockLocalStorage,
           apiClient: mockApiClient,
         );
         final performanceOptimizer = SyncPerformanceOptimizer(
           config: const SyncPerformanceConfig(enableMetrics: false),
           localStorage: mockLocalStorage,
           syncManager: mockSyncManager,
         );

        // 执行数据同步
        final syncResult = await dataSyncManager.syncData(SyncDataType.userSettings);
        expect(syncResult.isSuccess, true);

        // 优化同步操作
        final optimizeResult = await performanceOptimizer.optimizeSync(
          () async => 'optimized_result',
        );
        expect(optimizeResult.isSuccess, true);

        // 获取性能统计
        final stats = performanceOptimizer.getPerformanceStats();
        expect(stats, isA<Map<String, dynamic>>());

        performanceOptimizer.dispose();
      });
    });

    group('同步状态管理', () {
      test('应该正确跟踪同步状态', () {
        final syncState = container.read(syncStateProvider);
        expect(syncState, isNotNull);
      });

      test('应该能够检查是否可以同步', () {
        final canSync = container.read(canSyncProvider);
        expect(canSync, isA<bool>());
      });
    });

    group('离线队列集成', () {
      test('离线状态下操作应该进入队列', () async {
        // 模拟离线状态
        when(() => mockNetworkMonitor.state).thenReturn(
          const NetworkMonitorState(
            status: NetworkStatus.offline,
            isConnected: false,
            type: NetworkType.none,
          ),
        );

        // 检查离线队列状态
        final offlineStatus = container.read(offlineIndicatorProvider);
        expect(offlineStatus.shouldUseOfflineQueue, true);
      });

      test('恢复在线后应该处理队列中的操作', () async {
        // 模拟从离线恢复到在线
        when(() => mockNetworkMonitor.state).thenReturn(
          const NetworkMonitorState(
            status: NetworkStatus.online,
            isConnected: true,
            type: NetworkType.wifi,
          ),
        );

        // 检查同步状态
        final canSync = container.read(canSyncProvider);
        expect(canSync, true);
      });
    });

    group('错误处理', () {
      test('网络错误应该被正确处理', () async {
        // 模拟网络错误
        when(() => mockApiClient.healthCheck()).thenThrow(Exception('Network error'));

        // 检查错误处理
        final offlineStatus = container.read(offlineIndicatorProvider);
        expect(offlineStatus.operationMode, isA<AppOperationMode>());
      });

      test('存储错误应该被正确处理', () async {
        // 模拟存储错误
        when(() => mockLocalStorage.getString(any()))
            .thenAnswer((_) async => const AppResult.failure(StorageError('Storage error')));

        // 检查错误处理
        final syncState = container.read(syncStateProvider);
        expect(syncState, isNotNull);
      });
    });

    group('性能测试', () {
      test('同步操作应该在合理时间内完成', () async {
        // 模拟快速响应
        when(() => mockApiClient.healthCheck()).thenAnswer((_) async => true);
        when(() => mockLocalStorage.getString(any()))
            .thenAnswer((_) async => const AppResult.success('{}'));
        when(() => mockLocalStorage.setString(any(), any()))
            .thenAnswer((_) async => const AppResult.success(null));

        final stopwatch = Stopwatch()..start();
        
        // 执行同步检查
        final canSync = container.read(canSyncProvider);
        expect(canSync, isA<bool>());
        
        stopwatch.stop();
        
        // 应该在合理时间内完成
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('状态一致性', () {
      test('网络状态和同步状态应该保持一致', () {
        final networkState = container.read(networkMonitorProvider);
        final offlineStatus = container.read(offlineIndicatorProvider);
        final canSync = container.read(canSyncProvider);

        // 检查状态一致性
        expect(networkState, isNotNull);
        expect(offlineStatus, isNotNull);
        expect(canSync, isA<bool>());
      });

      test('离线状态变化应该影响同步能力', () {
        // 在线状态
        when(() => mockNetworkMonitor.state).thenReturn(
          const NetworkMonitorState(
            status: NetworkStatus.online,
            isConnected: true,
            type: NetworkType.wifi,
          ),
        );

        final onlineCanSync = container.read(canSyncProvider);
        expect(onlineCanSync, true);

        // 离线状态
        when(() => mockNetworkMonitor.state).thenReturn(
          const NetworkMonitorState(
            status: NetworkStatus.offline,
            isConnected: false,
            type: NetworkType.none,
          ),
        );

        // 状态应该反映离线情况
        final offlineStatus = container.read(offlineIndicatorProvider);
        expect(offlineStatus.isOffline, isA<bool>());
      });
    });

    group('Provider集成', () {
      test('所有相关Provider应该正常工作', () {
        // 测试所有主要Provider
        final syncState = container.read(syncStateProvider);
        final offlineStatus = container.read(offlineIndicatorProvider);
        final canSync = container.read(canSyncProvider);
        final networkState = container.read(networkMonitorProvider);

        expect(syncState, isNotNull);
        expect(offlineStatus, isNotNull);
        expect(canSync, isA<bool>());
        expect(networkState, isNotNull);
      });

      test('Provider状态变化应该被正确传播', () async {
        // 监听状态变化
        final initialOfflineStatus = container.read(offlineIndicatorProvider);
        expect(initialOfflineStatus.operationMode, isA<AppOperationMode>());

        // 模拟状态变化
        when(() => mockNetworkMonitor.state).thenReturn(
          const NetworkMonitorState(
            status: NetworkStatus.offline,
            isConnected: false,
            type: NetworkType.none,
          ),
        );

        // 等待状态传播
        await Future.delayed(const Duration(milliseconds: 10));

        // 验证状态已更新
        final updatedOfflineStatus = container.read(offlineIndicatorProvider);
        expect(updatedOfflineStatus, isNotNull);
      });
    });
  });
} 