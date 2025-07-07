// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:v7_flutter_app/shared/providers/providers.dart';
import 'package:v7_flutter_app/shared/storage/local_storage.dart';
import 'package:v7_flutter_app/shared/sync/sync_manager.dart';
import 'package:v7_flutter_app/shared/types/result.dart';

/// 压缩级别
enum CompressionLevel {
  none,
  low,
  medium,
  high,
  maximum,
}

/// 批处理策略
enum BatchStrategy {
  /// 按时间批处理
  time,
  /// 按数量批处理
  count,
  /// 按大小批处理
  size,
  /// 智能批处理
  smart,
}

/// 缓存策略
enum CacheStrategy {
  /// 仅内存缓存
  memoryOnly,
  /// 仅磁盘缓存
  diskOnly,
  /// 混合缓存
  hybrid,
  /// 智能缓存
  smart,
}

/// 同步性能配置
@immutable
class SyncPerformanceConfig {
  const SyncPerformanceConfig({
    this.enableBatchProcessing = true,
    this.batchSize = 50,
    this.batchTimeout = const Duration(seconds: 30),
    this.batchStrategy = BatchStrategy.smart,
    this.enableIncrementalSync = true,
    this.enableCompression = true,
    this.compressionLevel = CompressionLevel.medium,
    this.compressionThreshold = 1024,
    this.enableCaching = true,
    this.cacheStrategy = CacheStrategy.hybrid,
    this.maxCacheSize = 50 * 1024 * 1024, // 50MB
    this.cacheExpiryDuration = const Duration(hours: 24),
    this.enableDeltaSync = true,
    this.deltaCompressionRatio = 0.3,
    this.enableParallelProcessing = true,
    this.maxConcurrentOperations = 3,
    this.enableRetryOptimization = true,
    this.maxRetryAttempts = 3,
    this.retryBackoffMultiplier = 2.0,
    this.enableMetrics = true,
    this.metricsReportInterval = const Duration(minutes: 5),
  });

  final bool enableBatchProcessing;
  final int batchSize;
  final Duration batchTimeout;
  final BatchStrategy batchStrategy;
  final bool enableIncrementalSync;
  final bool enableCompression;
  final CompressionLevel compressionLevel;
  final int compressionThreshold;
  final bool enableCaching;
  final CacheStrategy cacheStrategy;
  final int maxCacheSize;
  final Duration cacheExpiryDuration;
  final bool enableDeltaSync;
  final double deltaCompressionRatio;
  final bool enableParallelProcessing;
  final int maxConcurrentOperations;
  final bool enableRetryOptimization;
  final int maxRetryAttempts;
  final double retryBackoffMultiplier;
  final bool enableMetrics;
  final Duration metricsReportInterval;

  SyncPerformanceConfig copyWith({
    bool? enableBatchProcessing,
    int? batchSize,
    Duration? batchTimeout,
    BatchStrategy? batchStrategy,
    bool? enableIncrementalSync,
    bool? enableCompression,
    CompressionLevel? compressionLevel,
    int? compressionThreshold,
    bool? enableCaching,
    CacheStrategy? cacheStrategy,
    int? maxCacheSize,
    Duration? cacheExpiryDuration,
    bool? enableDeltaSync,
    double? deltaCompressionRatio,
    bool? enableParallelProcessing,
    int? maxConcurrentOperations,
    bool? enableRetryOptimization,
    int? maxRetryAttempts,
    double? retryBackoffMultiplier,
    bool? enableMetrics,
    Duration? metricsReportInterval,
  }) {
    return SyncPerformanceConfig(
      enableBatchProcessing: enableBatchProcessing ?? this.enableBatchProcessing,
      batchSize: batchSize ?? this.batchSize,
      batchTimeout: batchTimeout ?? this.batchTimeout,
      batchStrategy: batchStrategy ?? this.batchStrategy,
      enableIncrementalSync: enableIncrementalSync ?? this.enableIncrementalSync,
      enableCompression: enableCompression ?? this.enableCompression,
      compressionLevel: compressionLevel ?? this.compressionLevel,
      compressionThreshold: compressionThreshold ?? this.compressionThreshold,
      enableCaching: enableCaching ?? this.enableCaching,
      cacheStrategy: cacheStrategy ?? this.cacheStrategy,
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      cacheExpiryDuration: cacheExpiryDuration ?? this.cacheExpiryDuration,
      enableDeltaSync: enableDeltaSync ?? this.enableDeltaSync,
      deltaCompressionRatio: deltaCompressionRatio ?? this.deltaCompressionRatio,
      enableParallelProcessing: enableParallelProcessing ?? this.enableParallelProcessing,
      maxConcurrentOperations: maxConcurrentOperations ?? this.maxConcurrentOperations,
      enableRetryOptimization: enableRetryOptimization ?? this.enableRetryOptimization,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      retryBackoffMultiplier: retryBackoffMultiplier ?? this.retryBackoffMultiplier,
      enableMetrics: enableMetrics ?? this.enableMetrics,
      metricsReportInterval: metricsReportInterval ?? this.metricsReportInterval,
    );
  }
}

/// 性能指标
@immutable
class SyncPerformanceMetrics {
  const SyncPerformanceMetrics({
    this.totalOperations = 0,
    this.successfulOperations = 0,
    this.failedOperations = 0,
    this.averageOperationTime = Duration.zero,
    this.totalDataTransferred = 0,
    this.compressionRatio = 0.0,
    this.cacheHitRate = 0.0,
    this.batchEfficiency = 0.0,
    this.networkUtilization = 0.0,
    this.lastUpdated,
  });

  final int totalOperations;
  final int successfulOperations;
  final int failedOperations;
  final Duration averageOperationTime;
  final int totalDataTransferred;
  final double compressionRatio;
  final double cacheHitRate;
  final double batchEfficiency;
  final double networkUtilization;
  final DateTime? lastUpdated;

  double get successRate => totalOperations > 0 ? successfulOperations / totalOperations : 0.0;
  double get failureRate => totalOperations > 0 ? failedOperations / totalOperations : 0.0;

  SyncPerformanceMetrics copyWith({
    int? totalOperations,
    int? successfulOperations,
    int? failedOperations,
    Duration? averageOperationTime,
    int? totalDataTransferred,
    double? compressionRatio,
    double? cacheHitRate,
    double? batchEfficiency,
    double? networkUtilization,
    DateTime? lastUpdated,
  }) {
    return SyncPerformanceMetrics(
      totalOperations: totalOperations ?? this.totalOperations,
      successfulOperations: successfulOperations ?? this.successfulOperations,
      failedOperations: failedOperations ?? this.failedOperations,
      averageOperationTime: averageOperationTime ?? this.averageOperationTime,
      totalDataTransferred: totalDataTransferred ?? this.totalDataTransferred,
      compressionRatio: compressionRatio ?? this.compressionRatio,
      cacheHitRate: cacheHitRate ?? this.cacheHitRate,
      batchEfficiency: batchEfficiency ?? this.batchEfficiency,
      networkUtilization: networkUtilization ?? this.networkUtilization,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// 批处理项目
class BatchItem {
  BatchItem({
    required this.id,
    required this.data,
    required this.operation,
    required this.timestamp,
    this.priority = 0,
    this.metadata = const {},
  });

  final String id;
  final Map<String, dynamic> data;
  final String operation;
  final DateTime timestamp;
  final int priority;
  final Map<String, dynamic> metadata;

  int get estimatedSize => jsonEncode(data).length;
}

/// 缓存项目
class SyncCacheItem {
  SyncCacheItem({
    required this.key,
    required this.data,
    required this.timestamp,
    required this.checksum,
    this.expiryTime,
    this.accessCount = 0,
    this.lastAccessTime,
  });

  final String key;
  final dynamic data;
  final DateTime timestamp;
  final String checksum;
  final DateTime? expiryTime;
  final int accessCount;
  final DateTime? lastAccessTime;

  bool get isExpired => expiryTime != null && DateTime.now().isAfter(expiryTime!);

  SyncCacheItem copyWith({
    String? key,
    dynamic data,
    DateTime? timestamp,
    String? checksum,
    DateTime? expiryTime,
    int? accessCount,
    DateTime? lastAccessTime,
  }) {
    return SyncCacheItem(
      key: key ?? this.key,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      checksum: checksum ?? this.checksum,
      expiryTime: expiryTime ?? this.expiryTime,
      accessCount: accessCount ?? this.accessCount,
      lastAccessTime: lastAccessTime ?? this.lastAccessTime,
    );
  }
}

/// 压缩工具
class CompressionUtils {
  static List<int> compress(List<int> data, CompressionLevel level) {
    if (level == CompressionLevel.none) return data;

    try {
      final encoder = GZipEncoder();
      final compressed = encoder.encode(data);
      return compressed ?? data;
    } catch (e) {
      debugPrint('Compression failed: $e');
      return data;
    }
  }

  static List<int> decompress(List<int> compressedData) {
    try {
      final decoder = GZipDecoder();
      return decoder.decodeBytes(compressedData);
    } catch (e) {
      debugPrint('Decompression failed: $e');
      return compressedData;
    }
  }

  static bool shouldCompress(List<int> data, int threshold) {
    return data.length >= threshold;
  }

  static double calculateCompressionRatio(int originalSize, int compressedSize) {
    if (originalSize == 0) return 0.0;
    return 1.0 - (compressedSize / originalSize);
  }
}

/// 缓存管理器
class SyncCacheManager {
  SyncCacheManager(this.config, this.localStorage);

  final SyncPerformanceConfig config;
  final LocalStorage localStorage;
  final Map<String, SyncCacheItem> _memoryCache = {};
  int _currentCacheSize = 0;

  /// 获取缓存项
  Future<T?> get<T>(String key) async {
    if (!config.enableCaching) return null;

    // 先检查内存缓存
    if (_shouldUseMemoryCache()) {
      final memoryItem = _memoryCache[key];
      if (memoryItem != null && !memoryItem.isExpired) {
        _updateAccessInfo(key);
        return memoryItem.data as T?;
      }
    }

    // 检查磁盘缓存
    if (_shouldUseDiskCache()) {
      final diskDataResult = await localStorage.getString('cache_$key');
      if (diskDataResult.isSuccess && diskDataResult.valueOrNull != null) {
        final cacheItem = _deserializeCacheItem(diskDataResult.valueOrNull!);
        if (cacheItem != null && !cacheItem.isExpired) {
          // 将热数据加载到内存缓存
          if (_shouldUseMemoryCache()) {
            _memoryCache[key] = cacheItem;
          }
          return cacheItem.data as T?;
        }
      }
    }

    return null;
  }

  /// 设置缓存项
  Future<void> set<T>(String key, T data, {Duration? expiry}) async {
    if (!config.enableCaching) return;

    final now = DateTime.now();
    final expiryTime = expiry != null ? now.add(expiry) : now.add(config.cacheExpiryDuration);
    final checksum = _calculateChecksum(data);
    
    final cacheItem = SyncCacheItem(
      key: key,
      data: data,
      timestamp: now,
      checksum: checksum,
      expiryTime: expiryTime,
    );

    // 内存缓存
    if (_shouldUseMemoryCache()) {
      _memoryCache[key] = cacheItem;
      _currentCacheSize += _estimateSize(data);
      _enforceMemoryCacheLimit();
    }

    // 磁盘缓存
    if (_shouldUseDiskCache()) {
      final serializedData = _serializeCacheItem(cacheItem);
      await localStorage.setString('cache_$key', serializedData);
    }
  }

  /// 删除缓存项
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    await localStorage.remove('cache_$key');
  }

  /// 清理过期缓存
  Future<void> cleanupExpired() async {
    // 清理内存缓存
    _memoryCache.removeWhere((key, item) => item.isExpired);

    // 清理磁盘缓存
    final keysResult = await localStorage.getKeys();
    if (keysResult.isSuccess && keysResult.valueOrNull != null) {
      for (final key in keysResult.valueOrNull!) {
        if (key.startsWith('cache_')) {
          final dataResult = await localStorage.getString(key);
          if (dataResult.isSuccess && dataResult.valueOrNull != null) {
            final cacheItem = _deserializeCacheItem(dataResult.valueOrNull!);
            if (cacheItem?.isExpired == true) {
              await localStorage.remove(key);
            }
          }
        }
      }
    }
  }

  /// 获取缓存统计
  Map<String, dynamic> getStatistics() {
    final totalItems = _memoryCache.length;
    final totalSize = _currentCacheSize;
    final hitCount = _memoryCache.values.fold<int>(0, (sum, item) => sum + item.accessCount);
    
    return {
      'totalItems': totalItems,
      'totalSize': totalSize,
      'hitCount': hitCount,
      'memoryUsage': _currentCacheSize,
      'maxCacheSize': config.maxCacheSize,
      'utilizationRate': totalSize / config.maxCacheSize,
    };
  }

  bool _shouldUseMemoryCache() {
    return config.cacheStrategy == CacheStrategy.memoryOnly ||
           config.cacheStrategy == CacheStrategy.hybrid ||
           config.cacheStrategy == CacheStrategy.smart;
  }

  bool _shouldUseDiskCache() {
    return config.cacheStrategy == CacheStrategy.diskOnly ||
           config.cacheStrategy == CacheStrategy.hybrid ||
           config.cacheStrategy == CacheStrategy.smart;
  }

  void _updateAccessInfo(String key) {
    final item = _memoryCache[key];
    if (item != null) {
      _memoryCache[key] = item.copyWith(
        accessCount: item.accessCount + 1,
        lastAccessTime: DateTime.now(),
      );
    }
  }

  void _enforceMemoryCacheLimit() {
    while (_currentCacheSize > config.maxCacheSize && _memoryCache.isNotEmpty) {
      // 移除最少使用的项目
      final lruKey = _findLRUKey();
      if (lruKey != null) {
        final item = _memoryCache.remove(lruKey);
        if (item != null) {
          _currentCacheSize -= _estimateSize(item.data);
        }
      }
    }
  }

  String? _findLRUKey() {
    if (_memoryCache.isEmpty) return null;

    String? lruKey;
    DateTime? oldestAccess;

    for (final entry in _memoryCache.entries) {
      final lastAccess = entry.value.lastAccessTime ?? entry.value.timestamp;
      if (oldestAccess == null || lastAccess.isBefore(oldestAccess)) {
        oldestAccess = lastAccess;
        lruKey = entry.key;
      }
    }

    return lruKey;
  }

  int _estimateSize(dynamic data) {
    try {
      return jsonEncode(data).length;
    } catch (e) {
      return 1024; // 默认估计大小
    }
  }

  String _calculateChecksum(dynamic data) {
    try {
      final content = jsonEncode(data);
      return sha256.convert(utf8.encode(content)).toString();
    } catch (e) {
      return '';
    }
  }

  String _serializeCacheItem(SyncCacheItem item) {
    return jsonEncode({
      'key': item.key,
      'data': item.data,
      'timestamp': item.timestamp.toIso8601String(),
      'checksum': item.checksum,
      'expiryTime': item.expiryTime?.toIso8601String(),
      'accessCount': item.accessCount,
      'lastAccessTime': item.lastAccessTime?.toIso8601String(),
    });
  }

  SyncCacheItem? _deserializeCacheItem(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return SyncCacheItem(
        key: json['key'] as String,
        data: json['data'],
        timestamp: DateTime.parse(json['timestamp'] as String),
        checksum: json['checksum'] as String,
        expiryTime: json['expiryTime'] != null 
            ? DateTime.parse(json['expiryTime'] as String) 
            : null,
        accessCount: json['accessCount'] as int? ?? 0,
        lastAccessTime: json['lastAccessTime'] != null 
            ? DateTime.parse(json['lastAccessTime'] as String) 
            : null,
      );
    } catch (e) {
      debugPrint('Failed to deserialize cache item: $e');
      return null;
    }
  }
}

/// 批处理管理器
class BatchProcessor {
  BatchProcessor(this.config);

  final SyncPerformanceConfig config;
  final List<BatchItem> _pendingItems = [];
  Timer? _batchTimer;
  final StreamController<List<BatchItem>> _batchController = StreamController.broadcast();

  Stream<List<BatchItem>> get batchStream => _batchController.stream;

  /// 添加项目到批处理
  void addItem(BatchItem item) {
    if (!config.enableBatchProcessing) {
      // 立即处理
      _batchController.add([item]);
      return;
    }

    _pendingItems.add(item);
    
    // 检查是否需要立即处理批次
    if (_shouldProcessBatch()) {
      _processPendingBatch();
    } else {
      _startBatchTimer();
    }
  }

  /// 强制处理当前批次
  void flushBatch() {
    if (_pendingItems.isNotEmpty) {
      _processPendingBatch();
    }
  }

  bool _shouldProcessBatch() {
    switch (config.batchStrategy) {
      case BatchStrategy.count:
        return _pendingItems.length >= config.batchSize;
      case BatchStrategy.size:
        final totalSize = _pendingItems.fold<int>(0, (sum, item) => sum + item.estimatedSize);
        return totalSize >= config.batchSize * 1024; // 假设batchSize为KB
      case BatchStrategy.time:
        return false; // 只依赖定时器
      case BatchStrategy.smart:
        return _pendingItems.length >= config.batchSize ||
               _pendingItems.fold<int>(0, (sum, item) => sum + item.estimatedSize) >= config.batchSize * 1024;
    }
  }

  void _processPendingBatch() {
    if (_pendingItems.isEmpty) return;

    final batch = List<BatchItem>.from(_pendingItems);
    _pendingItems.clear();
    _batchTimer?.cancel();
    _batchTimer = null;

    _batchController.add(batch);
  }

  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer(config.batchTimeout, () {
      _processPendingBatch();
    });
  }

  void dispose() {
    _batchTimer?.cancel();
    _batchController.close();
  }
}

/// 同步性能优化器
class SyncPerformanceOptimizer extends StateNotifier<SyncPerformanceMetrics> {
  SyncPerformanceOptimizer({
    required this.config,
    required this.localStorage,
    required this.syncManager,
  }) : super(const SyncPerformanceMetrics()) {
    _cacheManager = SyncCacheManager(config, localStorage);
    _batchProcessor = BatchProcessor(config);
    _initialize();
  }

  final SyncPerformanceConfig config;
  final LocalStorage localStorage;
  final SyncManager syncManager;
  
  late final SyncCacheManager _cacheManager;
  late final BatchProcessor _batchProcessor;
  Timer? _metricsTimer;

  void _initialize() {
    if (config.enableMetrics) {
      _startMetricsCollection();
    }
  }

  /// 优化同步操作
  Future<Result<T, String>> optimizeSync<T>(
    Future<T> Function() operation, {
    String? cacheKey,
    Duration? cacheDuration,
    bool enableRetry = true,
  }) async {
    final startTime = DateTime.now();
    
    try {
      // 尝试从缓存获取
      if (cacheKey != null && config.enableCaching) {
        final cachedResult = await _cacheManager.get<T>(cacheKey);
        if (cachedResult != null) {
          return Result.success(cachedResult);
        }
      }

      // 执行操作
      T result;
      if (enableRetry && config.enableRetryOptimization) {
        result = await _executeWithRetry(operation);
      } else {
        result = await operation();
      }

      // 缓存结果
      if (cacheKey != null && config.enableCaching) {
        await _cacheManager.set(cacheKey, result, expiry: cacheDuration);
      }

      // 更新指标
      _updateMetrics(startTime, true);

      return Result.success(result);
    } catch (e) {
      _updateMetrics(startTime, false);
      return Result.failure('Sync operation failed: $e');
    }
  }

  /// 批处理同步操作
  Future<Result<List<T>, String>> batchSync<T>(
    List<Future<T> Function()> operations, {
    String? cacheKeyPrefix,
  }) async {
    if (!config.enableBatchProcessing) {
      // 顺序执行
      final results = <T>[];
      for (final operation in operations) {
        try {
          final result = await operation();
          results.add(result);
        } catch (e) {
          return Result.failure('Batch operation failed: $e');
        }
      }
      return Result.success(results);
    }

    // 并行执行
    try {
      final futures = operations.map((op) => op()).toList();
      final results = await Future.wait(futures);
      return Result.success(results);
    } catch (e) {
      return Result.failure('Batch sync failed: $e');
    }
  }

  /// 增量同步
  Future<Result<Map<String, dynamic>, String>> incrementalSync({
    required DateTime lastSyncTime,
    required String dataType,
  }) async {
    if (!config.enableIncrementalSync) {
      return const Result.failure('Incremental sync is disabled');
    }

    try {
      // 获取增量数据
      final delta = await _getIncrementalData(lastSyncTime, dataType);
      
      // 压缩数据
      if (config.enableCompression) {
        final compressed = _compressData(delta);
        return Result.success(compressed);
      }

      return Result.success(delta);
    } catch (e) {
      return Result.failure('Incremental sync failed: $e');
    }
  }

  /// 获取性能统计
  Map<String, dynamic> getPerformanceStats() {
    return {
      'metrics': {
        'totalOperations': state.totalOperations,
        'successRate': state.successRate,
        'averageTime': state.averageOperationTime.inMilliseconds,
        'dataTransferred': state.totalDataTransferred,
        'compressionRatio': state.compressionRatio,
      },
      'cache': _cacheManager.getStatistics(),
      'config': {
        'batchSize': config.batchSize,
        'compressionLevel': config.compressionLevel.toString(),
        'cacheStrategy': config.cacheStrategy.toString(),
      },
    };
  }

  Future<T> _executeWithRetry<T>(Future<T> Function() operation) async {
    int attempts = 0;
    Duration delay = const Duration(milliseconds: 100);

    while (attempts < config.maxRetryAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= config.maxRetryAttempts) {
          rethrow;
        }
        
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * config.retryBackoffMultiplier).round());
      }
    }

    throw Exception('Max retry attempts exceeded');
  }

  Future<Map<String, dynamic>> _getIncrementalData(DateTime lastSyncTime, String dataType) async {
    // 简化实现 - 实际应该查询数据库获取增量数据
    return {
      'type': dataType,
      'since': lastSyncTime.toIso8601String(),
      'changes': [],
    };
  }

  Map<String, dynamic> _compressData(Map<String, dynamic> data) {
    if (!config.enableCompression) return data;

    try {
      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);
      
      if (bytes.length < config.compressionThreshold) {
        return data;
      }

      final compressed = CompressionUtils.compress(bytes, config.compressionLevel);
      final ratio = CompressionUtils.calculateCompressionRatio(bytes.length, compressed.length);

      return {
        'compressed': true,
        'data': base64Encode(compressed),
        'originalSize': bytes.length,
        'compressedSize': compressed.length,
        'ratio': ratio,
      };
    } catch (e) {
      debugPrint('Compression failed: $e');
      return data;
    }
  }

  void _updateMetrics(DateTime startTime, bool success) {
    final duration = DateTime.now().difference(startTime);
    
    state = state.copyWith(
      totalOperations: state.totalOperations + 1,
      successfulOperations: success ? state.successfulOperations + 1 : state.successfulOperations,
      failedOperations: success ? state.failedOperations : state.failedOperations + 1,
      averageOperationTime: _calculateAverageTime(duration),
      totalDataTransferred: state.totalDataTransferred + _estimateDataTransferred(duration),
      compressionRatio: _calculateCompressionRatio(duration),
      lastUpdated: DateTime.now(),
    );
  }

  Duration _calculateAverageTime(Duration newDuration) {
    if (state.totalOperations == 0) return newDuration;
    
    final totalMs = state.averageOperationTime.inMilliseconds * state.totalOperations + newDuration.inMilliseconds;
    final newCount = state.totalOperations + 1;
    
    return Duration(milliseconds: (totalMs / newCount).round());
  }

  int _estimateDataTransferred(Duration duration) {
    // 简化实现 - 实际应该根据操作类型和数据量估算数据传输量
    return (duration.inMilliseconds / 1000).round(); // 假设每秒传输1KB
  }

  double _calculateCompressionRatio(Duration duration) {
    // 简化实现 - 实际应该根据压缩操作估算压缩比率
    return 0.5; // 假设压缩比率为50%
  }

  void _startMetricsCollection() {
    _metricsTimer = Timer.periodic(config.metricsReportInterval, (timer) {
      _collectMetrics();
    });
  }

  void _collectMetrics() {
    // 收集性能指标
    final cacheStats = _cacheManager.getStatistics();
    final hitCount = cacheStats['hitCount'] as int? ?? 0;
    
    state = state.copyWith(
      cacheHitRate: hitCount > 0 && state.totalOperations > 0 ? hitCount / state.totalOperations : 0.0,
      batchEfficiency: _calculateBatchEfficiency(),
      networkUtilization: _calculateNetworkUtilization(),
      lastUpdated: DateTime.now(),
    );
  }

  double _calculateBatchEfficiency() {
    // 简化实现 - 实际应该根据批处理操作估算批处理效率
    return 0.8; // 假设批处理效率为80%
  }

  double _calculateNetworkUtilization() {
    // 简化实现 - 实际应该根据网络操作估算网络利用率
    return 0.5; // 假设网络利用率为50%
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    _batchProcessor.dispose();
    super.dispose();
  }
}

/// Riverpod 提供器
final syncPerformanceConfigProvider = Provider<SyncPerformanceConfig>((ref) {
  return const SyncPerformanceConfig();
});

final syncPerformanceOptimizerProvider = StateNotifierProvider<SyncPerformanceOptimizer, SyncPerformanceMetrics>((ref) {
  return SyncPerformanceOptimizer(
    config: ref.read(syncPerformanceConfigProvider),
    localStorage: ref.read(localStorageProvider),
    syncManager: ref.read(syncManagerProvider),
  );
});

/// 便捷访问提供器
final performanceMetricsProvider = Provider<SyncPerformanceMetrics>((ref) {
  return ref.watch(syncPerformanceOptimizerProvider);
});

final syncStatisticsProvider = Provider<Map<String, dynamic>>((ref) {
  final optimizer = ref.read(syncPerformanceOptimizerProvider.notifier);
  return optimizer.getPerformanceStats();
});

/// 扩展方法
extension SyncPerformanceOptimizerExtensions on SyncPerformanceOptimizer {
  /// 获取当前性能评分
  double get performanceScore {
    final metrics = state;
    final factors = [
      metrics.cacheHitRate,
      metrics.batchEfficiency,
      metrics.compressionRatio,
      1.0 - metrics.failureRate,
    ];
    
    return factors.fold<double>(0.0, (sum, factor) => sum + factor) / factors.length;
  }
  
  /// 是否需要优化
  bool get needsOptimization => performanceScore < 0.7;
  
  /// 获取优化建议
  List<String> get optimizationSuggestions {
    final suggestions = <String>[];
    final metrics = state;
    
    if (metrics.cacheHitRate < 0.5) {
      suggestions.add('提高缓存命中率');
    }
    
    if (metrics.compressionRatio < 0.3) {
      suggestions.add('调整压缩策略');
    }
    
    if (metrics.batchEfficiency < 0.7) {
      suggestions.add('优化批量处理大小');
    }
    
    if (metrics.failureRate > 0.1) {
      suggestions.add('减少同步错误');
    }
    
    return suggestions;
  }
} 