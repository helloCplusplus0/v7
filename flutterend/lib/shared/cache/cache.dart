/// Flutter v7 缓存管理系统
/// 提供统一的缓存接口，支持内存、磁盘和混合缓存策略

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../types/result.dart';

/// 缓存异常类型
enum CacheErrorType {
  keyNotFound,
  serializationError,
  deserializationError,
  compressionError,
  encryptionError,
  storageError,
  configurationError,
  operationTimeout,
  capacityExceeded,
}

/// 缓存异常
class CacheException extends AppError {
  const CacheException(
    this.type,
    String message, [
    dynamic cause,
  ]) : super(message, cause);

  final CacheErrorType type;

  @override
  String toString() => 'CacheException($type): $message';
}

/// 缓存接口
/// 定义统一的缓存操作API
abstract class Cache<K, V> {
  /// 设置缓存值
  Future<AppResult<void>> set(K key, V value, {Duration? ttl});
  
  /// 获取缓存值
  Future<AppResult<V?>> get(K key);
  
  /// 批量获取
  Future<AppResult<Map<K, V>>> getAll(List<K> keys);
  
  /// 批量设置
  Future<AppResult<void>> setAll(Map<K, V> entries, {Duration? ttl});
  
  /// 检查键是否存在
  Future<AppResult<bool>> containsKey(K key);
  
  /// 删除缓存
  Future<AppResult<bool>> remove(K key);
  
  /// 批量删除
  Future<AppResult<int>> removeAll(List<K> keys);
  
  /// 清空缓存
  Future<AppResult<void>> clear();
  
  /// 获取所有键
  Future<AppResult<Set<K>>> keys();
  
  /// 获取缓存大小
  Future<AppResult<int>> size();
  
  /// 获取缓存统计
  Future<AppResult<CacheStats>> getStats();
  
  /// 清理过期项
  Future<AppResult<int>> cleanup();
  
  /// 关闭缓存
  Future<void> close();
}

/// 缓存策略
enum CacheStrategy {
  /// 仅内存缓存
  memoryOnly,
  /// 仅磁盘缓存
  diskOnly,
  /// 内存优先，磁盘备份
  memoryWithDiskBackup,
  /// 分层缓存（L1内存，L2磁盘）
  tiered,
  /// LRU缓存
  lru,
  /// LFU缓存
  lfu,
  /// FIFO缓存
  fifo,
}

/// 缓存配置
class CacheConfig {
  const CacheConfig({
    this.strategy = CacheStrategy.memoryOnly,
    this.maxSize = 1000,
    this.maxMemorySize = 50 * 1024 * 1024, // 50MB
    this.maxDiskSize = 200 * 1024 * 1024,  // 200MB
    this.defaultTtl = const Duration(hours: 1),
    this.cleanupInterval = const Duration(minutes: 10),
    this.compressionEnabled = false,
    this.encryptionEnabled = false,
    this.keyPrefix,
    this.persistToDisk = false,
  });
  
  final CacheStrategy strategy;
  final int maxSize;
  final int maxMemorySize;
  final int maxDiskSize;
  final Duration defaultTtl;
  final Duration cleanupInterval;
  final bool compressionEnabled;
  final bool encryptionEnabled;
  final String? keyPrefix;
  final bool persistToDisk;

  /// 验证配置
  AppResult<void> validate() {
    if (maxSize <= 0) {
      return AppResult.failure(
        const CacheException(
          CacheErrorType.configurationError,
          'maxSize must be positive',
        ),
      );
    }
    
    if (maxMemorySize <= 0) {
      return AppResult.failure(
        const CacheException(
          CacheErrorType.configurationError,
          'maxMemorySize must be positive',
        ),
      );
    }
    
    if (maxDiskSize <= 0) {
      return AppResult.failure(
        const CacheException(
          CacheErrorType.configurationError,
          'maxDiskSize must be positive',
        ),
      );
    }
    
    return AppResult.success(null);
  }

  /// 复制配置
  CacheConfig copyWith({
    CacheStrategy? strategy,
    int? maxSize,
    int? maxMemorySize,
    int? maxDiskSize,
    Duration? defaultTtl,
    Duration? cleanupInterval,
    bool? compressionEnabled,
    bool? encryptionEnabled,
    String? keyPrefix,
    bool? persistToDisk,
  }) {
    return CacheConfig(
      strategy: strategy ?? this.strategy,
      maxSize: maxSize ?? this.maxSize,
      maxMemorySize: maxMemorySize ?? this.maxMemorySize,
      maxDiskSize: maxDiskSize ?? this.maxDiskSize,
      defaultTtl: defaultTtl ?? this.defaultTtl,
      cleanupInterval: cleanupInterval ?? this.cleanupInterval,
      compressionEnabled: compressionEnabled ?? this.compressionEnabled,
      encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
      keyPrefix: keyPrefix ?? this.keyPrefix,
      persistToDisk: persistToDisk ?? this.persistToDisk,
    );
  }
}

/// 缓存项
class CacheEntry<V> {
  CacheEntry({
    required this.value,
    required this.createdAt,
    this.expiresAt,
    this.lastAccessTime,
    this.accessCount = 0,
    this.size,
    this.metadata,
  });
  
  final V value;
  final DateTime createdAt;
  final DateTime? expiresAt;
  DateTime? lastAccessTime;
  int accessCount;
  final int? size; // 字节大小
  final Map<String, dynamic>? metadata;
  
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
  
  Duration get age => DateTime.now().difference(createdAt);
  
  Duration? get timeSinceLastAccess {
    if (lastAccessTime == null) return null;
    return DateTime.now().difference(lastAccessTime!);
  }
  
  void markAccessed() {
    lastAccessTime = DateTime.now();
    accessCount++;
  }

  /// 创建副本
  CacheEntry<V> copyWith({
    V? value,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? lastAccessTime,
    int? accessCount,
    int? size,
    Map<String, dynamic>? metadata,
  }) {
    return CacheEntry<V>(
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastAccessTime: lastAccessTime ?? this.lastAccessTime,
      accessCount: accessCount ?? this.accessCount,
      size: size ?? this.size,
      metadata: metadata ?? this.metadata,
    );
  }
  
  Map<String, dynamic> toJson(dynamic Function(V) valueToJson) {
    return {
      'value': valueToJson(value),
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'lastAccessTime': lastAccessTime?.toIso8601String(),
      'accessCount': accessCount,
      'size': size,
      'metadata': metadata,
    };
  }
  
  static CacheEntry<V> fromJson<V>(
    Map<String, dynamic> json,
    V Function(dynamic) valueFromJson,
  ) {
    return CacheEntry<V>(
      value: valueFromJson(json['value']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      lastAccessTime: json['lastAccessTime'] != null
          ? DateTime.parse(json['lastAccessTime'] as String)
          : null,
      accessCount: json['accessCount'] as int? ?? 0,
      size: json['size'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// 缓存统计
class CacheStats {
  const CacheStats({
    required this.hitCount,
    required this.missCount,
    required this.totalSize,
    required this.entryCount,
    required this.memoryUsage,
    required this.diskUsage,
    required this.expiredCount,
    this.evictionCount = 0,
    this.averageAccessTime,
  });
  
  final int hitCount;
  final int missCount;
  final int totalSize;
  final int entryCount;
  final int memoryUsage;
  final int diskUsage;
  final int expiredCount;
  final int evictionCount;
  final Duration? averageAccessTime;
  
  int get totalAccess => hitCount + missCount;
  
  double get hitRate {
    return totalAccess > 0 ? hitCount / totalAccess : 0.0;
  }
  
  double get missRate {
    return totalAccess > 0 ? missCount / totalAccess : 0.0;
  }

  /// 复制统计
  CacheStats copyWith({
    int? hitCount,
    int? missCount,
    int? totalSize,
    int? entryCount,
    int? memoryUsage,
    int? diskUsage,
    int? expiredCount,
    int? evictionCount,
    Duration? averageAccessTime,
  }) {
    return CacheStats(
      hitCount: hitCount ?? this.hitCount,
      missCount: missCount ?? this.missCount,
      totalSize: totalSize ?? this.totalSize,
      entryCount: entryCount ?? this.entryCount,
      memoryUsage: memoryUsage ?? this.memoryUsage,
      diskUsage: diskUsage ?? this.diskUsage,
      expiredCount: expiredCount ?? this.expiredCount,
      evictionCount: evictionCount ?? this.evictionCount,
      averageAccessTime: averageAccessTime ?? this.averageAccessTime,
    );
  }
  
  @override
  String toString() {
    return 'CacheStats(entries: $entryCount, hits: $hitCount, misses: $missCount, '
           'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
           'memoryUsage: ${memoryUsage}B, diskUsage: ${diskUsage}B)';
  }
}

/// 缓存驱逐策略
abstract class EvictionPolicy<K, V> {
  /// 选择要驱逐的键
  List<K> selectKeysToEvict(
    Map<K, CacheEntry<V>> entries,
    int targetSize,
  );
  
  /// 策略名称
  String get name;
}

/// LRU驱逐策略
class LRUEvictionPolicy<K, V> implements EvictionPolicy<K, V> {
  @override
  String get name => 'LRU';
  
  @override
  List<K> selectKeysToEvict(
    Map<K, CacheEntry<V>> entries,
    int targetSize,
  ) {
    if (entries.length <= targetSize) return [];
    
    final sortedEntries = entries.entries.toList()
      ..sort((a, b) {
        final aTime = a.value.lastAccessTime ?? a.value.createdAt;
        final bTime = b.value.lastAccessTime ?? b.value.createdAt;
        return aTime.compareTo(bTime);
      });
    
    final toEvict = <K>[];
    for (int i = 0; i < sortedEntries.length - targetSize; i++) {
      toEvict.add(sortedEntries[i].key);
    }
    
    return toEvict;
  }
}

/// LFU驱逐策略
class LFUEvictionPolicy<K, V> implements EvictionPolicy<K, V> {
  @override
  String get name => 'LFU';
  
  @override
  List<K> selectKeysToEvict(
    Map<K, CacheEntry<V>> entries,
    int targetSize,
  ) {
    if (entries.length <= targetSize) return [];
    
    final sortedEntries = entries.entries.toList()
      ..sort((a, b) => a.value.accessCount.compareTo(b.value.accessCount));
    
    final toEvict = <K>[];
    for (int i = 0; i < sortedEntries.length - targetSize; i++) {
      toEvict.add(sortedEntries[i].key);
    }
    
    return toEvict;
  }
}

/// FIFO驱逐策略
class FIFOEvictionPolicy<K, V> implements EvictionPolicy<K, V> {
  @override
  String get name => 'FIFO';
  
  @override
  List<K> selectKeysToEvict(
    Map<K, CacheEntry<V>> entries,
    int targetSize,
  ) {
    if (entries.length <= targetSize) return [];
    
    final sortedEntries = entries.entries.toList()
      ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));
    
    final toEvict = <K>[];
    for (int i = 0; i < sortedEntries.length - targetSize; i++) {
      toEvict.add(sortedEntries[i].key);
    }
    
    return toEvict;
  }
}

/// 缓存序列化器
abstract class CacheSerializer<V> {
  /// 序列化值
  Uint8List serialize(V value);
  
  /// 反序列化值
  V deserialize(Uint8List data);
  
  /// 估算序列化大小
  int estimateSize(V value);
}

/// JSON缓存序列化器
class JsonCacheSerializer implements CacheSerializer<Map<String, dynamic>> {
  @override
  Uint8List serialize(Map<String, dynamic> value) {
    try {
      final jsonString = jsonEncode(value);
      return Uint8List.fromList(utf8.encode(jsonString));
    } catch (e) {
      throw CacheException(
        CacheErrorType.serializationError,
        'Failed to serialize JSON: $e',
        e,
      );
    }
  }
  
  @override
  Map<String, dynamic> deserialize(Uint8List data) {
    try {
      final jsonString = utf8.decode(data);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw CacheException(
        CacheErrorType.deserializationError,
        'Failed to deserialize JSON: $e',
        e,
      );
    }
  }
  
  @override
  int estimateSize(Map<String, dynamic> value) {
    try {
      return utf8.encode(jsonEncode(value)).length;
    } catch (e) {
      // 粗略估算：每个字符平均 3 字节
      return value.toString().length * 3;
    }
  }
}

/// 字符串缓存序列化器
class StringCacheSerializer implements CacheSerializer<String> {
  @override
  Uint8List serialize(String value) {
    try {
      return Uint8List.fromList(utf8.encode(value));
    } catch (e) {
      throw CacheException(
        CacheErrorType.serializationError,
        'Failed to serialize string: $e',
        e,
      );
    }
  }
  
  @override
  String deserialize(Uint8List data) {
    try {
      return utf8.decode(data);
    } catch (e) {
      throw CacheException(
        CacheErrorType.deserializationError,
        'Failed to deserialize string: $e',
        e,
      );
    }
  }
  
  @override
  int estimateSize(String value) {
    return utf8.encode(value).length;
  }
}

/// 缓存压缩器
abstract class CacheCompressor {
  /// 压缩数据
  Uint8List compress(Uint8List data);
  
  /// 解压数据
  Uint8List decompress(Uint8List data);
  
  /// 压缩比例
  double get compressionRatio;
}

/// 缓存加密器
abstract class CacheEncryptor {
  /// 加密数据
  Uint8List encrypt(Uint8List data);
  
  /// 解密数据
  Uint8List decrypt(Uint8List data);
}

/// 缓存工厂
abstract class CacheFactory {
  /// 创建内存缓存
  Cache<K, V> createMemoryCache<K, V>({
    required String name,
    CacheConfig? config,
    EvictionPolicy<K, V>? evictionPolicy,
  });
  
  /// 创建磁盘缓存
  Cache<K, V> createDiskCache<K, V>({
    required String name,
    required String directory,
    CacheConfig? config,
    CacheSerializer<V>? serializer,
  });
  
  /// 创建分层缓存
  Cache<K, V> createTieredCache<K, V>({
    required String name,
    required Cache<K, V> l1Cache,
    required Cache<K, V> l2Cache,
    CacheConfig? config,
  });
  
  /// 检查可用性
  Future<bool> isAvailable();
  
  /// 获取实现类型
  String get implementationType;
}

/// 缓存事件
abstract class CacheEvent<K> {
  CacheEvent({
    required this.key,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  final K? key; // 允许 null 以支持 CacheClearEvent
  final DateTime timestamp;
}

/// 缓存命中事件
class CacheHitEvent<K> extends CacheEvent<K> {
  CacheHitEvent({
    required K key,
    super.timestamp,
  }) : super(key: key);
}

/// 缓存未命中事件
class CacheMissEvent<K> extends CacheEvent<K> {
  CacheMissEvent({
    required K key,
    super.timestamp,
  }) : super(key: key);
}

/// 缓存设置事件
class CacheSetEvent<K, V> extends CacheEvent<K> {
  CacheSetEvent({
    required K key,
    required this.value,
    this.ttl,
    super.timestamp,
  }) : super(key: key);
  
  final V value;
  final Duration? ttl;
}

/// 缓存删除事件
class CacheRemoveEvent<K> extends CacheEvent<K> {
  CacheRemoveEvent({
    required K key,
    super.timestamp,
  }) : super(key: key);
}

/// 缓存驱逐事件
class CacheEvictEvent<K> extends CacheEvent<K> {
  CacheEvictEvent({
    required K key,
    required this.reason,
    super.timestamp,
  }) : super(key: key);
  
  final String reason;
}

/// 缓存清空事件
class CacheClearEvent<K> extends CacheEvent<K> {
  CacheClearEvent({super.timestamp}) : super(key: null);
}

/// 缓存监听器
typedef CacheListener<K> = void Function(CacheEvent<K> event);

/// 可观察的缓存接口
mixin ObservableCache<K, V> on Cache<K, V> {
  final List<CacheListener<K>> _listeners = [];
  
  void addListener(CacheListener<K> listener) {
    _listeners.add(listener);
  }
  
  void removeListener(CacheListener<K> listener) {
    _listeners.remove(listener);
  }
  
  @protected
  void notifyListeners(CacheEvent<K> event) {
    for (final listener in _listeners) {
      try {
        listener(event);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Cache listener error: $e');
        }
      }
    }
  }
  
  void clearListeners() {
    _listeners.clear();
  }
}

/// 缓存键生成器
abstract class CacheKeyGenerator<T> {
  /// 生成缓存键
  String generateKey(T input);
  
  /// 生成带前缀的键
  String generateKeyWithPrefix(String prefix, T input) {
    return '$prefix:${generateKey(input)}';
  }
}

/// 默认字符串键生成器
class StringCacheKeyGenerator implements CacheKeyGenerator<String> {
  @override
  String generateKey(String input) => input;
  
  @override
  String generateKeyWithPrefix(String prefix, String input) {
    return '$prefix:${generateKey(input)}';
  }
}

/// 哈希键生成器
class HashCacheKeyGenerator implements CacheKeyGenerator<dynamic> {
  @override
  String generateKey(dynamic input) {
    return input.hashCode.toString();
  }
  
  @override
  String generateKeyWithPrefix(String prefix, dynamic input) {
    return '$prefix:${generateKey(input)}';
  }
}

/// 缓存装饰器模式
abstract class CacheDecorator<K, V> implements Cache<K, V> {
  CacheDecorator(this.cache);
  
  final Cache<K, V> cache;
  
  @override
  Future<AppResult<V?>> get(K key) => cache.get(key);
  
  @override
  Future<AppResult<void>> set(K key, V value, {Duration? ttl}) =>
      cache.set(key, value, ttl: ttl);
  
  @override
  Future<AppResult<bool>> remove(K key) => cache.remove(key);
  
  @override
  Future<AppResult<void>> clear() => cache.clear();
  
  @override
  Future<AppResult<bool>> containsKey(K key) => cache.containsKey(key);
  
  @override
  Future<AppResult<Map<K, V>>> getAll(List<K> keys) => cache.getAll(keys);
  
  @override
  Future<AppResult<void>> setAll(Map<K, V> entries, {Duration? ttl}) =>
      cache.setAll(entries, ttl: ttl);
  
  @override
  Future<AppResult<int>> removeAll(List<K> keys) => cache.removeAll(keys);
  
  @override
  Future<AppResult<Set<K>>> keys() => cache.keys();
  
  @override
  Future<AppResult<int>> size() => cache.size();
  
  @override
  Future<AppResult<CacheStats>> getStats() => cache.getStats();
  
  @override
  Future<AppResult<int>> cleanup() => cache.cleanup();
  
  @override
  Future<void> close() => cache.close();
}

/// 计时缓存装饰器
class TimedCacheDecorator<K, V> extends CacheDecorator<K, V> {
  TimedCacheDecorator(super.cache);
  
  @override
  Future<AppResult<V?>> get(K key) async {
    final stopwatch = Stopwatch()..start();
    final result = await super.get(key);
    stopwatch.stop();
    
    if (kDebugMode) {
      debugPrint('Cache get($key) took ${stopwatch.elapsedMicroseconds}μs');
    }
    
    return result;
  }
  
  @override
  Future<AppResult<void>> set(K key, V value, {Duration? ttl}) async {
    final stopwatch = Stopwatch()..start();
    final result = await super.set(key, value, ttl: ttl);
    stopwatch.stop();
    
    if (kDebugMode) {
      debugPrint('Cache set($key) took ${stopwatch.elapsedMicroseconds}μs');
    }
    
    return result;
  }
}

/// 重试缓存装饰器
class RetryCacheDecorator<K, V> extends CacheDecorator<K, V> {
  RetryCacheDecorator(
    super.cache, {
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 100),
  });
  
  final int maxRetries;
  final Duration retryDelay;
  
  @override
  Future<AppResult<V?>> get(K key) async {
    for (int i = 0; i <= maxRetries; i++) {
      final result = await super.get(key);
      if (result.isSuccess || i == maxRetries) {
        return result;
      }
      
      await Future.delayed(retryDelay);
    }
    
    return AppResult.failure(
      const CacheException(
        CacheErrorType.operationTimeout,
        'Max retries exceeded for cache get operation',
      ),
    );
  }
}

/// 内存缓存基类
abstract class _BaseCacheImpl<K, V> implements Cache<K, V> {}

/// 内存缓存实现
class MemoryCache<K, V> extends _BaseCacheImpl<K, V> with ObservableCache<K, V> {
  MemoryCache({
    required this.name,
    CacheConfig? config,
    EvictionPolicy<K, V>? evictionPolicy,
  }) : _config = config ?? const CacheConfig(),
       _evictionPolicy = evictionPolicy ?? LRUEvictionPolicy<K, V>(),
       _startTime = DateTime.now() {
    _startCleanupTimer();
  }
  
  final String name;
  final CacheConfig _config;
  final EvictionPolicy<K, V> _evictionPolicy;
  final DateTime _startTime;
  
  final Map<K, CacheEntry<V>> _cache = {};
  Timer? _cleanupTimer;
  
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  @override
  Future<AppResult<void>> set(K key, V value, {Duration? ttl}) async {
    try {
      final expiry = ttl != null
          ? DateTime.now().add(ttl)
          : ((_config.defaultTtl != Duration.zero) 
              ? DateTime.now().add(_config.defaultTtl) 
              : null);
      
      final entry = CacheEntry<V>(
        value: value,
        createdAt: DateTime.now(),
        expiresAt: expiry,
      );
      
      _cache[key] = entry;
      
      // 检查是否需要驱逐
      await _evictIfNecessary();
      
      // 发布事件
      notifyListeners(CacheSetEvent<K, V>(
        key: key,
        value: value,
        ttl: ttl,
      ));
      
      return AppResult.success(null);
    } catch (e) {
      return AppResult.failure(
        CacheException(
          CacheErrorType.storageError,
          'Failed to set cache entry: $e',
          e,
        ),
      );
    }
  }

  @override
  Future<AppResult<V?>> get(K key) async {
    try {
      final entry = _cache[key];
      
      if (entry == null) {
        _missCount++;
        notifyListeners(CacheMissEvent<K>(key: key));
        return AppResult.success(null);
      }
      
      if (entry.isExpired) {
        _cache.remove(key);
        _missCount++;
        notifyListeners(CacheMissEvent<K>(key: key));
        return AppResult.success(null);
      }
      
      entry.markAccessed();
      _hitCount++;
      notifyListeners(CacheHitEvent<K>(key: key));
      
      return AppResult.success(entry.value);
    } catch (e) {
      return AppResult.failure(
        CacheException(
          CacheErrorType.storageError,
          'Failed to get cache entry: $e',
          e,
        ),
      );
    }
  }

  @override
  Future<AppResult<Map<K, V>>> getAll(List<K> keys) async {
    final result = <K, V>{};
    
    for (final key in keys) {
      final getResult = await get(key);
      if (getResult.isSuccess && getResult.valueOrNull != null) {
        result[key] = getResult.valueOrNull!;
      }
    }
    
    return AppResult.success(result);
  }

  @override
  Future<AppResult<void>> setAll(Map<K, V> entries, {Duration? ttl}) async {
    for (final entry in entries.entries) {
      final setResult = await set(entry.key, entry.value, ttl: ttl);
      if (setResult.isFailure) {
        return setResult;
      }
    }
    
    return AppResult.success(null);
  }

  @override
  Future<AppResult<bool>> containsKey(K key) async {
    final entry = _cache[key];
    if (entry == null) return AppResult.success(false);
    
    if (entry.isExpired) {
      _cache.remove(key);
      return AppResult.success(false);
    }
    
    return AppResult.success(true);
  }

  @override
  Future<AppResult<bool>> remove(K key) async {
    try {
      final existed = _cache.containsKey(key);
      _cache.remove(key);
      
      if (existed) {
        notifyListeners(CacheRemoveEvent<K>(key: key));
      }
      
      return AppResult.success(existed);
    } catch (e) {
      return AppResult.failure(
        CacheException(
          CacheErrorType.storageError,
          'Failed to remove cache entry: $e',
          e,
        ),
      );
    }
  }

  @override
  Future<AppResult<int>> removeAll(List<K> keys) async {
    int removed = 0;
    
    for (final key in keys) {
      final removeResult = await remove(key);
      if (removeResult.isSuccess && removeResult.valueOrNull == true) {
        removed++;
      }
    }
    
    return AppResult.success(removed);
  }

  @override
  Future<AppResult<void>> clear() async {
    try {
      _cache.clear();
      notifyListeners(CacheClearEvent<K>());
      return AppResult.success(null);
    } catch (e) {
      return AppResult.failure(
        CacheException(
          CacheErrorType.storageError,
          'Failed to clear cache: $e',
          e,
        ),
      );
    }
  }

  @override
  Future<AppResult<Set<K>>> keys() async {
    try {
      // 先清理过期项
      await cleanup();
      return AppResult.success(_cache.keys.toSet());
    } catch (e) {
      return AppResult.failure(
        CacheException(
          CacheErrorType.storageError,
          'Failed to get cache keys: $e',
          e,
        ),
      );
    }
  }

  @override
  Future<AppResult<int>> size() async {
    try {
      await cleanup();
      return AppResult.success(_cache.length);
    } catch (e) {
      return AppResult.failure(
        CacheException(
          CacheErrorType.storageError,
          'Failed to get cache size: $e',
          e,
        ),
      );
    }
  }

  @override
  Future<AppResult<CacheStats>> getStats() async {
    try {
      await cleanup();
      
      final stats = CacheStats(
        hitCount: _hitCount,
        missCount: _missCount,
        totalSize: _cache.length,
        entryCount: _cache.length,
        memoryUsage: _cache.length * 100, // 粗略估算
        diskUsage: 0, // 内存缓存无磁盘使用
        expiredCount: 0, // cleanup后应该为0
        evictionCount: _evictionCount,
        averageAccessTime: _calculateAverageAccessTime(),
      );
      
      return AppResult.success(stats);
    } catch (e) {
      return AppResult.failure(
        CacheException(
          CacheErrorType.storageError,
          'Failed to get cache stats: $e',
          e,
        ),
      );
    }
  }

  @override
  Future<AppResult<int>> cleanup() async {
    try {
      final now = DateTime.now();
      final expiredKeys = <K>[];
      
      for (final entry in _cache.entries) {
        if (entry.value.isExpired) {
          expiredKeys.add(entry.key);
        }
      }
      
      for (final key in expiredKeys) {
        _cache.remove(key);
      }
      
      return AppResult.success(expiredKeys.length);
    } catch (e) {
      return AppResult.failure(
        CacheException(
          CacheErrorType.storageError,
          'Failed to cleanup cache: $e',
          e,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _cleanupTimer?.cancel();
    _cache.clear();
    clearListeners();
  }

  /// 开始清理定时器
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(_config.cleanupInterval, (_) {
      cleanup();
    });
  }

  /// 如有必要进行驱逐
  Future<void> _evictIfNecessary() async {
    if (_cache.length <= _config.maxSize) return;
    
    final keysToEvict = _evictionPolicy.selectKeysToEvict(
      _cache,
      _config.maxSize,
    );
    
    for (final key in keysToEvict) {
      _cache.remove(key);
      _evictionCount++;
      notifyListeners(CacheEvictEvent<K>(
        key: key,
        reason: 'Capacity exceeded, evicted by ${_evictionPolicy.name}',
      ));
    }
  }

  /// 计算平均访问时间
  Duration? _calculateAverageAccessTime() {
    if (_cache.isEmpty) return null;
    
    final now = DateTime.now();
    final totalMs = _cache.values
        .map((entry) => now.difference(entry.lastAccessTime ?? entry.createdAt).inMilliseconds)
        .reduce((a, b) => a + b);
    
    return Duration(milliseconds: totalMs ~/ _cache.length);
  }
}

/// 默认缓存工厂实现
class DefaultCacheFactory implements CacheFactory {
  @override
  String get implementationType => 'DefaultCacheFactory';

  @override
  Cache<K, V> createMemoryCache<K, V>({
    required String name,
    CacheConfig? config,
    EvictionPolicy<K, V>? evictionPolicy,
  }) {
    return MemoryCache<K, V>(
      name: name,
      config: config,
      evictionPolicy: evictionPolicy,
    );
  }

  @override
  Cache<K, V> createDiskCache<K, V>({
    required String name,
    required String directory,
    CacheConfig? config,
    CacheSerializer<V>? serializer,
  }) {
    // TODO: 实现磁盘缓存
    throw UnimplementedError('Disk cache implementation pending');
  }

  @override
  Cache<K, V> createTieredCache<K, V>({
    required String name,
    required Cache<K, V> l1Cache,
    required Cache<K, V> l2Cache,
    CacheConfig? config,
  }) {
    // TODO: 实现分层缓存
    throw UnimplementedError('Tiered cache implementation pending');
  }

  @override
  Future<bool> isAvailable() async => true;
} 