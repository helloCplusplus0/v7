// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:v7_flutter_app/shared/connectivity/network_monitor.dart';
import 'package:v7_flutter_app/shared/sync/sync_manager.dart';
import 'package:v7_flutter_app/shared/sync/sync_performance_optimizer.dart';
import 'package:v7_flutter_app/shared/types/result.dart';
import 'package:v7_flutter_app/shared/storage/local_storage.dart';

// Mock类
class MockLocalStorage extends Mock implements LocalStorage {}
class MockSyncManager extends Mock implements SyncManager {}

void main() {
  group('SyncPerformanceOptimizer', () {
    late SyncPerformanceOptimizer optimizer;
    late MockLocalStorage mockLocalStorage;
    late MockSyncManager mockSyncManager;
    late SyncPerformanceConfig config;

    setUp(() {
      mockLocalStorage = MockLocalStorage();
      mockSyncManager = MockSyncManager();
      config = const SyncPerformanceConfig(
        enableMetrics: false, // 禁用定时器避免测试复杂性
      );
      optimizer = SyncPerformanceOptimizer(
        config: config,
        localStorage: mockLocalStorage,
        syncManager: mockSyncManager,
      );
    });

    tearDown(() {
      optimizer.dispose();
    });

    group('初始化', () {
      test('应该有正确的初始状态', () {
        expect(optimizer.state.totalOperations, 0);
        expect(optimizer.state.successfulOperations, 0);
        expect(optimizer.state.failedOperations, 0);
        expect(optimizer.state.successRate, 0.0);
        expect(optimizer.state.failureRate, 0.0);
      });

      test('应该有正确的配置', () {
        expect(optimizer.config, config);
        expect(optimizer.config.enableBatchProcessing, true);
        expect(optimizer.config.enableCompression, true);
        expect(optimizer.config.enableCaching, true);
      });
    });

    group('性能优化', () {
      test('应该能够优化同步操作', () async {
        // 模拟成功的操作
        final operation = () async => 'test_result';

        final result = await optimizer.optimizeSync(operation);

        expect(result.isSuccess, true);
        expect(result.valueOrNull, 'test_result');
        expect(optimizer.state.totalOperations, 1);
        expect(optimizer.state.successfulOperations, 1);
      });

      test('应该能够处理失败的操作', () async {
        // 模拟失败的操作
        final operation = () async => throw Exception('Test error');

        final result = await optimizer.optimizeSync(operation);

        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('Sync operation failed'));
        expect(optimizer.state.totalOperations, 1);
        expect(optimizer.state.failedOperations, 1);
      });

      test('应该能够使用缓存', () async {
        // 设置localStorage mock
        when(() => mockLocalStorage.getString('cache_test_key'))
            .thenAnswer((_) async => const Result.success(null));
        when(() => mockLocalStorage.setString('cache_test_key', any()))
            .thenAnswer((_) async => const Result.success(null));

        final operation = () async => 'cached_result';

        final result = await optimizer.optimizeSync(
          operation,
          cacheKey: 'test_key',
        );

        expect(result.isSuccess, true);
        expect(result.valueOrNull, 'cached_result');
      });
    });

    group('批处理同步', () {
      test('应该能够批处理多个操作', () async {
        final operations = [
          () async => 'result1',
          () async => 'result2',
          () async => 'result3',
        ];

        final result = await optimizer.batchSync(operations);

        expect(result.isSuccess, true);
        expect(result.valueOrNull, ['result1', 'result2', 'result3']);
      });

      test('批处理操作失败时应该返回错误', () async {
        final operations = [
          () async => 'result1',
          () async => throw Exception('Batch error'),
          () async => 'result3',
        ];

        final result = await optimizer.batchSync(operations);

        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('Batch sync failed'));
      });
    });

    group('增量同步', () {
      test('应该能够执行增量同步', () async {
        final lastSyncTime = DateTime(2024, 1, 1);
        
        final result = await optimizer.incrementalSync(
          lastSyncTime: lastSyncTime,
          dataType: 'user_data',
        );

        expect(result.isSuccess, true);
        final data = result.valueOrNull!;
        expect(data['type'], 'user_data');
        expect(data['since'], lastSyncTime.toIso8601String());
      });

      test('禁用增量同步时应该返回错误', () async {
        final disabledConfig = config.copyWith(enableIncrementalSync: false);
        final disabledOptimizer = SyncPerformanceOptimizer(
          config: disabledConfig,
          localStorage: mockLocalStorage,
          syncManager: mockSyncManager,
        );

        final result = await disabledOptimizer.incrementalSync(
          lastSyncTime: DateTime.now(),
          dataType: 'test',
        );

        expect(result.isFailure, true);
        expect(result.errorOrNull, 'Incremental sync is disabled');

        disabledOptimizer.dispose();
      });
    });

    group('性能统计', () {
      test('应该能够获取性能统计', () {
        final stats = optimizer.getPerformanceStats();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['metrics'], isA<Map<String, dynamic>>());
        expect(stats['cache'], isA<Map<String, dynamic>>());
        expect(stats['config'], isA<Map<String, dynamic>>());
        
        expect(stats['metrics']['totalOperations'], 0);
        expect(stats['metrics']['successRate'], 0.0);
      });

      test('应该正确计算成功率', () async {
        // 执行一些操作
        await optimizer.optimizeSync(() async => 'success1');
        await optimizer.optimizeSync(() async => 'success2');
        await optimizer.optimizeSync(() async => throw Exception('fail'));

        expect(optimizer.state.totalOperations, 3);
        expect(optimizer.state.successfulOperations, 2);
        expect(optimizer.state.failedOperations, 1);
        expect(optimizer.state.successRate, closeTo(0.67, 0.01));
        expect(optimizer.state.failureRate, closeTo(0.33, 0.01));
      });
    });

    group('扩展方法', () {
      test('应该能够计算性能评分', () {
        final score = optimizer.performanceScore;
        expect(score, isA<double>());
        expect(score, greaterThanOrEqualTo(0.0));
        expect(score, lessThanOrEqualTo(1.0));
      });

      test('应该能够判断是否需要优化', () {
        final needsOpt = optimizer.needsOptimization;
        expect(needsOpt, isA<bool>());
      });

      test('应该能够获取优化建议', () {
        final suggestions = optimizer.optimizationSuggestions;
        expect(suggestions, isA<List<String>>());
      });
    });

    group('配置管理', () {
      test('应该有合理的默认配置', () {
        const defaultConfig = SyncPerformanceConfig();
        
        expect(defaultConfig.enableBatchProcessing, true);
        expect(defaultConfig.batchSize, 50);
        expect(defaultConfig.enableCompression, true);
        expect(defaultConfig.compressionLevel, CompressionLevel.medium);
        expect(defaultConfig.enableCaching, true);
        expect(defaultConfig.cacheStrategy, CacheStrategy.hybrid);
        expect(defaultConfig.enableIncrementalSync, true);
        expect(defaultConfig.enableParallelProcessing, true);
        expect(defaultConfig.maxConcurrentOperations, 3);
      });

      test('应该能够复制和修改配置', () {
        const originalConfig = SyncPerformanceConfig();
        
        final modifiedConfig = originalConfig.copyWith(
          batchSize: 100,
          enableCompression: false,
          compressionLevel: CompressionLevel.high,
        );
        
        expect(modifiedConfig.batchSize, 100);
        expect(modifiedConfig.enableCompression, false);
        expect(modifiedConfig.compressionLevel, CompressionLevel.high);
        
        // 其他值应该保持不变
        expect(modifiedConfig.enableBatchProcessing, originalConfig.enableBatchProcessing);
        expect(modifiedConfig.enableCaching, originalConfig.enableCaching);
      });
    });

    group('压缩工具', () {
      test('应该能够压缩和解压数据', () {
        final originalData = List.generate(1000, (i) => i % 256);
        
        final compressed = CompressionUtils.compress(originalData, CompressionLevel.medium);
        final decompressed = CompressionUtils.decompress(compressed);
        
        expect(decompressed, originalData);
      });

      test('应该正确判断是否需要压缩', () {
        final smallData = [1, 2, 3];
        final largeData = List.generate(2000, (i) => i % 256);
        
        expect(CompressionUtils.shouldCompress(smallData, 1024), false);
        expect(CompressionUtils.shouldCompress(largeData, 1024), true);
      });

      test('应该正确计算压缩比率', () {
        final ratio = CompressionUtils.calculateCompressionRatio(1000, 500);
        expect(ratio, 0.5);
        
        final noCompression = CompressionUtils.calculateCompressionRatio(0, 0);
        expect(noCompression, 0.0);
      });
    });

    group('Provider测试', () {
      test('应该能够创建配置Provider', () {
        final container = ProviderContainer();
        final config = container.read(syncPerformanceConfigProvider);
        
        expect(config, isA<SyncPerformanceConfig>());
        expect(config.enableBatchProcessing, true);
        
        container.dispose();
      });

      test('应该能够创建优化器Provider', () {
        final container = ProviderContainer(
          overrides: [
            syncPerformanceConfigProvider.overrideWithValue(const SyncPerformanceConfig()),
          ],
        );

        final optimizer = container.read(syncPerformanceOptimizerProvider.notifier);
        expect(optimizer, isA<SyncPerformanceOptimizer>());

        final metrics = container.read(performanceMetricsProvider);
        expect(metrics, isA<SyncPerformanceMetrics>());

        container.dispose();
      });
    });

    group('枚举类型', () {
      test('压缩级别枚举应该包含所有值', () {
        final levels = CompressionLevel.values;
        expect(levels, contains(CompressionLevel.none));
        expect(levels, contains(CompressionLevel.low));
        expect(levels, contains(CompressionLevel.medium));
        expect(levels, contains(CompressionLevel.high));
        expect(levels, contains(CompressionLevel.maximum));
      });

      test('批处理策略枚举应该包含所有值', () {
        final strategies = BatchStrategy.values;
        expect(strategies, contains(BatchStrategy.time));
        expect(strategies, contains(BatchStrategy.count));
        expect(strategies, contains(BatchStrategy.size));
        expect(strategies, contains(BatchStrategy.smart));
      });

      test('缓存策略枚举应该包含所有值', () {
        final strategies = CacheStrategy.values;
        expect(strategies, contains(CacheStrategy.memoryOnly));
        expect(strategies, contains(CacheStrategy.diskOnly));
        expect(strategies, contains(CacheStrategy.hybrid));
        expect(strategies, contains(CacheStrategy.smart));
      });
    });

    group('性能指标', () {
      test('应该有正确的初始指标', () {
        const metrics = SyncPerformanceMetrics();
        
        expect(metrics.totalOperations, 0);
        expect(metrics.successfulOperations, 0);
        expect(metrics.failedOperations, 0);
        expect(metrics.averageOperationTime, Duration.zero);
        expect(metrics.totalDataTransferred, 0);
        expect(metrics.compressionRatio, 0.0);
        expect(metrics.cacheHitRate, 0.0);
        expect(metrics.batchEfficiency, 0.0);
        expect(metrics.networkUtilization, 0.0);
        expect(metrics.successRate, 0.0);
        expect(metrics.failureRate, 0.0);
      });

      test('应该能够复制和修改指标', () {
        const originalMetrics = SyncPerformanceMetrics();
        
        final modifiedMetrics = originalMetrics.copyWith(
          totalOperations: 10,
          successfulOperations: 8,
          failedOperations: 2,
          compressionRatio: 0.5,
        );
        
        expect(modifiedMetrics.totalOperations, 10);
        expect(modifiedMetrics.successfulOperations, 8);
        expect(modifiedMetrics.failedOperations, 2);
        expect(modifiedMetrics.compressionRatio, 0.5);
        expect(modifiedMetrics.successRate, 0.8);
        expect(modifiedMetrics.failureRate, 0.2);
      });
    });

    group('边界情况', () {
      test('应该正确处理空操作', () async {
        final operation = () async => null;
        
        final result = await optimizer.optimizeSync(operation);
        
        expect(result.isSuccess, true);
        expect(result.valueOrNull, isNull);
      });

      test('应该正确处理空批处理', () async {
        final result = await optimizer.batchSync(<Future<String> Function()>[]);
        
        expect(result.isSuccess, true);
        expect(result.valueOrNull, isEmpty);
      });

      test('应该正确处理无效缓存键', () async {
        when(() => mockLocalStorage.getString(any()))
            .thenAnswer((_) async => const Result.success(null));

        final operation = () async => 'result';
        
        final result = await optimizer.optimizeSync(
          operation,
          cacheKey: '',
        );
        
        expect(result.isSuccess, true);
      });
    });
  });
} 