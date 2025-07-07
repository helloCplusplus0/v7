// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:v7_flutter_app/shared/sync/background_sync_service.dart';
import 'package:v7_flutter_app/shared/sync/offline_queue.dart';
import 'package:v7_flutter_app/shared/connectivity/network_monitor.dart';
import 'package:v7_flutter_app/shared/offline/offline_indicator.dart';

void main() {
  // 初始化Flutter测试绑定
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 设置SharedPreferences测试环境
    SharedPreferences.setMockInitialValues({});
  });

  group('BackgroundSyncConfig Tests', () {
    test('should create config with default values', () {
      const config = BackgroundSyncConfig();
      
      expect(config.periodicSyncInterval, const Duration(minutes: 30));
      expect(config.networkRecoveryDelay, const Duration(seconds: 10));
      expect(config.maxRetryAttempts, 3);
      expect(config.retryBackoffMultiplier, 2.0);
      expect(config.enableBatteryOptimization, true);
      expect(config.enableWifiOnlyMode, false);
      expect(config.enableDataSaverMode, false);
      expect(config.maxSyncDuration, const Duration(minutes: 10));
      expect(config.enableDebugLogging, false);
      expect(config.priorityThreshold, OperationPriority.normal);
      expect(config.backgroundSyncEnabled, true);
      expect(config.adaptiveScheduling, true);
    });

    test('should create config with custom values', () {
      const config = BackgroundSyncConfig(
        periodicSyncInterval: Duration(minutes: 60),
        networkRecoveryDelay: Duration(seconds: 30),
        maxRetryAttempts: 5,
        retryBackoffMultiplier: 1.5,
        enableBatteryOptimization: false,
        enableWifiOnlyMode: true,
        enableDataSaverMode: true,
        maxSyncDuration: Duration(minutes: 15),
        enableDebugLogging: true,
        priorityThreshold: OperationPriority.high,
        backgroundSyncEnabled: false,
        adaptiveScheduling: false,
      );
      
      expect(config.periodicSyncInterval, const Duration(minutes: 60));
      expect(config.networkRecoveryDelay, const Duration(seconds: 30));
      expect(config.maxRetryAttempts, 5);
      expect(config.retryBackoffMultiplier, 1.5);
      expect(config.enableBatteryOptimization, false);
      expect(config.enableWifiOnlyMode, true);
      expect(config.enableDataSaverMode, true);
      expect(config.maxSyncDuration, const Duration(minutes: 15));
      expect(config.enableDebugLogging, true);
      expect(config.priorityThreshold, OperationPriority.high);
      expect(config.backgroundSyncEnabled, false);
      expect(config.adaptiveScheduling, false);
    });

    test('should support copyWith method', () {
      const config = BackgroundSyncConfig();
      final updatedConfig = config.copyWith(
        periodicSyncInterval: const Duration(minutes: 45),
        maxRetryAttempts: 5,
        enableWifiOnlyMode: true,
      );
      
      expect(updatedConfig.periodicSyncInterval, const Duration(minutes: 45));
      expect(updatedConfig.maxRetryAttempts, 5);
      expect(updatedConfig.enableWifiOnlyMode, true);
      // 其他值应保持不变
      expect(updatedConfig.networkRecoveryDelay, const Duration(seconds: 10));
      expect(updatedConfig.retryBackoffMultiplier, 2.0);
    });
  });

  group('BackgroundSyncState Tests', () {
    test('should create state with default values', () {
      const state = BackgroundSyncState();
      
      expect(state.isActive, false);
      expect(state.lastSyncTime, null);
      expect(state.nextScheduledSync, null);
      expect(state.pendingTasks, isEmpty);
      expect(state.runningTasks, isEmpty);
      expect(state.completedTasks, isEmpty);
      expect(state.failedTasks, isEmpty);
      expect(state.totalSyncCount, 0);
      expect(state.successfulSyncCount, 0);
      expect(state.failedSyncCount, 0);
      expect(state.averageSyncDuration, Duration.zero);
      expect(state.networkCondition, NetworkQuality.none);
      expect(state.batteryLevel, 1.0);
      expect(state.isCharging, false);
      expect(state.isWifiConnected, false);
      expect(state.error, null);
    });

    test('should calculate success rate correctly', () {
      const state1 = BackgroundSyncState(
        totalSyncCount: 10,
        successfulSyncCount: 8,
      );
      expect(state1.successRate, 0.8);

      const state2 = BackgroundSyncState(
        totalSyncCount: 0,
        successfulSyncCount: 0,
      );
      expect(state2.successRate, 0.0);
    });

    test('should detect pending tasks correctly', () {
      final task = BackgroundSyncTask(
        id: 'test-task',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: DateTime.now(),
      );
      
      const state1 = BackgroundSyncState();
      expect(state1.hasPendingTasks, false);

      final state2 = BackgroundSyncState(pendingTasks: [task]);
      expect(state2.hasPendingTasks, true);
    });

    test('should detect running tasks correctly', () {
      final task = BackgroundSyncTask(
        id: 'test-task',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: DateTime.now(),
        startedAt: DateTime.now(),
      );
      
      const state1 = BackgroundSyncState();
      expect(state1.hasRunningTasks, false);

      final state2 = BackgroundSyncState(runningTasks: [task]);
      expect(state2.hasRunningTasks, true);
    });

    test('should detect failed tasks correctly', () {
      final task = BackgroundSyncTask(
        id: 'test-task',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: DateTime.now(),
        error: 'Test error',
      );
      
      const state1 = BackgroundSyncState();
      expect(state1.hasFailedTasks, false);

      final state2 = BackgroundSyncState(failedTasks: [task]);
      expect(state2.hasFailedTasks, true);
    });

    test('should determine if good for sync', () {
      const state1 = BackgroundSyncState(
        networkCondition: NetworkQuality.excellent,
        batteryLevel: 0.8,
        isCharging: false,
      );
      expect(state1.isGoodForSync, true);

      const state2 = BackgroundSyncState(
        networkCondition: NetworkQuality.poor,
        batteryLevel: 0.8,
        isCharging: false,
      );
      expect(state2.isGoodForSync, false);

      const state3 = BackgroundSyncState(
        networkCondition: NetworkQuality.good,
        batteryLevel: 0.1,
        isCharging: false,
      );
      expect(state3.isGoodForSync, false);

      const state4 = BackgroundSyncState(
        networkCondition: NetworkQuality.good,
        batteryLevel: 0.1,
        isCharging: true,
      );
      expect(state4.isGoodForSync, true);
    });

    test('should support copyWith method', () {
      final now = DateTime.now();
      const state = BackgroundSyncState();
      
      final updatedState = state.copyWith(
        isActive: true,
        lastSyncTime: now,
        totalSyncCount: 5,
        successfulSyncCount: 4,
        networkCondition: NetworkQuality.excellent,
        batteryLevel: 0.8,
        isCharging: true,
        isWifiConnected: true,
      );
      
      expect(updatedState.isActive, true);
      expect(updatedState.lastSyncTime, now);
      expect(updatedState.totalSyncCount, 5);
      expect(updatedState.successfulSyncCount, 4);
      expect(updatedState.networkCondition, NetworkQuality.excellent);
      expect(updatedState.batteryLevel, 0.8);
      expect(updatedState.isCharging, true);
      expect(updatedState.isWifiConnected, true);
    });
  });

  group('BackgroundSyncTask Tests', () {
    test('should create task with required fields', () {
      final now = DateTime.now();
      final task = BackgroundSyncTask(
        id: 'test-task',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: now,
      );
      
      expect(task.id, 'test-task');
      expect(task.type, BackgroundSyncTaskType.periodicSync);
      expect(task.createdAt, now);
      expect(task.priority, OperationPriority.normal);
      expect(task.maxRetries, 3);
      expect(task.retryCount, 0);
      expect(task.startedAt, null);
      expect(task.completedAt, null);
      expect(task.duration, null);
      expect(task.error, null);
      expect(task.data, null);
    });

    test('should detect completed task', () {
      final now = DateTime.now();
      final task1 = BackgroundSyncTask(
        id: 'test-task-1',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: now,
      );
      expect(task1.isCompleted, false);

      final task2 = BackgroundSyncTask(
        id: 'test-task-2',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: now,
        completedAt: now.add(const Duration(seconds: 30)),
      );
      expect(task2.isCompleted, true);
    });

    test('should detect failed task', () {
      final now = DateTime.now();
      final task1 = BackgroundSyncTask(
        id: 'test-task-1',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: now,
      );
      expect(task1.isFailed, false);

      final task2 = BackgroundSyncTask(
        id: 'test-task-2',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: now,
        error: 'Test error',
      );
      expect(task2.isFailed, true);
    });

    test('should detect retryable task', () {
      final now = DateTime.now();
      final task1 = BackgroundSyncTask(
        id: 'test-task-1',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: now,
        retryCount: 2,
        maxRetries: 3,
      );
      expect(task1.canRetry, true);

      final task2 = BackgroundSyncTask(
        id: 'test-task-2',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: now,
        retryCount: 3,
        maxRetries: 3,
      );
      expect(task2.canRetry, false);
    });

    test('should detect running task', () {
      final now = DateTime.now();
      final task1 = BackgroundSyncTask(
        id: 'test-task-1',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: now,
      );
      expect(task1.isRunning, false);

      final task2 = BackgroundSyncTask(
        id: 'test-task-2',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: now,
        startedAt: now,
      );
      expect(task2.isRunning, true);

      final task3 = BackgroundSyncTask(
        id: 'test-task-3',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: now,
        startedAt: now,
        completedAt: now.add(const Duration(seconds: 30)),
      );
      expect(task3.isRunning, false);
    });

    test('should support copyWith method', () {
      final now = DateTime.now();
      final task = BackgroundSyncTask(
        id: 'test-task',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: now,
      );
      
      final updatedTask = task.copyWith(
        startedAt: now.add(const Duration(seconds: 10)),
        priority: OperationPriority.high,
        retryCount: 1,
        error: 'Test error',
      );
      
      expect(updatedTask.id, 'test-task');
      expect(updatedTask.type, BackgroundSyncTaskType.periodicSync);
      expect(updatedTask.createdAt, now);
      expect(updatedTask.startedAt, now.add(const Duration(seconds: 10)));
      expect(updatedTask.priority, OperationPriority.high);
      expect(updatedTask.retryCount, 1);
      expect(updatedTask.error, 'Test error');
    });
  });

  group('BackgroundSyncTaskType Tests', () {
    test('should have all expected task types', () {
      expect(BackgroundSyncTaskType.values, containsAll([
        BackgroundSyncTaskType.periodicSync,
        BackgroundSyncTaskType.networkRecoverySync,
        BackgroundSyncTaskType.offlineQueueProcessing,
        BackgroundSyncTaskType.emergencySync,
        BackgroundSyncTaskType.incrementalSync,
        BackgroundSyncTaskType.fullSync,
      ]));
    });
  });

  group('BackgroundSyncTaskCompletedEvent Tests', () {
    test('should create event with required fields', () {
      final task = BackgroundSyncTask(
        id: 'test-task',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
        duration: const Duration(seconds: 30),
      );
      
      final event = BackgroundSyncTaskCompletedEvent(
        task: task,
        success: true,
      );
      
      expect(event.task, task);
      expect(event.success, true);
      expect(event.type, 'background_sync_task_completed');
    });

    test('should convert to JSON correctly', () {
      final now = DateTime.now();
      final task = BackgroundSyncTask(
        id: 'test-task',
        type: BackgroundSyncTaskType.periodicSync,
        createdAt: now,
        completedAt: now.add(const Duration(seconds: 30)),
        duration: const Duration(seconds: 30),
        error: 'Test error',
      );
      
      final event = BackgroundSyncTaskCompletedEvent(
        task: task,
        success: false,
      );
      
      final json = event.toJson();
      
      expect(json['task_id'], 'test-task');
      expect(json['task_type'], 'periodicSync');
      expect(json['success'], false);
      expect(json['duration'], 30000); // 30 seconds in milliseconds
      expect(json['error'], 'Test error');
      expect(json['completed_at'], isA<String>());
    });
  });
} 