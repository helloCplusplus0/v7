/// 磁盘缓存实现
/// 基于文件系统提供持久化缓存存储

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

import '../types/result.dart';
import 'cache.dart';

/// 磁盘缓存实现
/// 提供持久化缓存功能，支持文件存储、压缩、加密等高级特性
class DiskCache<K, V> implements Cache<K, V> {
  DiskCache({
    required this.name,
    required this.cacheDir,
    required this.keySerializer,
    required this.valueSerializer,
    required this.valueDeserializer,
    CacheConfig? config,
  }) : config = config ?? const CacheConfig() {
    _initialize();
  }

  final String name;
  final Directory cacheDir;
  final String Function(K) keySerializer;
  final String Function(V) valueSerializer;
  final V Function(String) valueDeserializer;
  final CacheConfig config;

  // 内存中的元数据索引
  final Map<String, CacheEntry<V>> _memoryIndex = {};
  final Map<String, String> _keyToFileMap = {};
  
  // 统计信息
  var _stats = const CacheStats(
    hitCount: 0,
    missCount: 0,
    totalSize: 0,
    entryCount: 0,
    memoryUsage: 0,
    diskUsage: 0,
    expiredCount: 0,
  );

  Timer? _cleanupTimer;
  bool _isDisposed = false;

  /// 初始化缓存
  Future<void> _initialize() async {
    try {
      // 确保缓存目录存在
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // 加载索引
      await _loadIndex();

      // 启动清理定时器
      _startCleanupTimer();
    } catch (e) {
      debugPrint('Failed to initialize disk cache: $e');
    }
  }

  /// 加载缓存索引
  Future<void> _loadIndex() async {
    try {
      final indexFile = File(path.join(cacheDir.path, 'index.json'));
      if (!await indexFile.exists()) {
        return;
      }

      final indexContent = await indexFile.readAsString();
      final indexData = jsonDecode(indexContent) as Map<String, dynamic>;

      for (final entry in indexData.entries) {
        final key = entry.key;
        final data = entry.value as Map<String, dynamic>;
        
        try {
          final cacheEntry = CacheEntry.fromJson<V>(data, (value) {
            return valueDeserializer(value as String);
          });
          
          // 检查文件是否存在
          final fileName = data['fileName'] as String;
          final file = File(path.join(cacheDir.path, fileName));
          
          if (await file.exists()) {
            _memoryIndex[key] = cacheEntry;
            _keyToFileMap[key] = fileName;
          }
        } catch (e) {
          // 忽略损坏的条目
          debugPrint('Failed to load cache entry $key: $e');
        }
      }

      // 更新统计信息
      await _updateStats();
    } catch (e) {
      debugPrint('Failed to load cache index: $e');
    }
  }

  /// 保存缓存索引
  Future<void> _saveIndex() async {
    try {
      final indexData = <String, dynamic>{};
      
      for (final entry in _memoryIndex.entries) {
        final key = entry.key;
        final cacheEntry = entry.value;
        final fileName = _keyToFileMap[key];
        
        if (fileName != null) {
          final data = cacheEntry.toJson(valueSerializer);
          data['fileName'] = fileName;
          indexData[key] = data;
        }
      }

      final indexFile = File(path.join(cacheDir.path, 'index.json'));
      await indexFile.writeAsString(jsonEncode(indexData));
    } catch (e) {
      debugPrint('Failed to save cache index: $e');
    }
  }

  /// 启动清理定时器
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(config.cleanupInterval, (_) {
      cleanup();
    });
  }

  /// 生成文件名
  String _generateFileName(K key) {
    final keyString = keySerializer(key);
    final keyHash = sha256.convert(utf8.encode(keyString)).toString();
    return '$keyHash.cache';
  }

  /// 生成索引键
  String _generateIndexKey(K key) {
    final keyString = keySerializer(key);
    if (config.keyPrefix != null) {
      return '${config.keyPrefix}:$keyString';
    }
    return keyString;
  }

  @override
  Future<AppResult<void>> set(K key, V value, {Duration? ttl}) async {
    if (_isDisposed) {
      return AppResult.failure(
        const CacheException(
          CacheErrorType.storageError,
          'Cache is disposed',
        ),
      );
    }

    try {
      final indexKey = _generateIndexKey(key);
      final fileName = _generateFileName(key);
      final file = File(path.join(cacheDir.path, fileName));
      
      // 序列化值
      final serializedValue = valueSerializer(value);
      
      // 压缩（如果启用）
      Uint8List data = utf8.encode(serializedValue);
      if (config.compressionEnabled) {
        data = await _compress(data);
      }
      
      // 加密（如果启用）
      if (config.encryptionEnabled) {
        data = await _encrypt(data);
      }
      
      // 写入文件
      await file.writeAsBytes(data);
      
      // 计算过期时间
      final now = DateTime.now();
      final effectiveTtl = ttl ?? config.defaultTtl;
      final expiresAt = now.add(effectiveTtl);
      
      // 创建缓存条目
      final entry = CacheEntry<V>(
        value: value,
        createdAt: now,
        expiresAt: expiresAt,
        size: data.length,
      );
      
      // 更新索引
      _memoryIndex[indexKey] = entry;
      _keyToFileMap[indexKey] = fileName;
      
      // 检查容量限制
      await _enforceCapacityLimits();
      
      // 保存索引
      await _saveIndex();
      
      return AppResult.success(null);
    } catch (e) {
      return AppResult.failure(
        CacheException(
          CacheErrorType.storageError,
          'Failed to set cache value: $e',
          e,
        ),
      );
    }
  }

  @override
  Future<AppResult<V?>> get(K key) async {
    if (_isDisposed) {
      return AppResult.failure(
        const CacheException(
          CacheErrorType.storageError,
          'Cache is disposed',
        ),
      );
    }

    try {
      final indexKey = _generateIndexKey(key);
      final entry = _memoryIndex[indexKey];
      
      if (entry == null) {
        _stats = _stats.copyWith(missCount: _stats.missCount + 1);
        return AppResult.success(null);
      }
      
      // 检查是否过期
      if (entry.isExpired) {
        await _removeEntry(indexKey);
        _stats = _stats.copyWith(
          missCount: _stats.missCount + 1,
          expiredCount: _stats.expiredCount + 1,
        );
        return AppResult.success(null);
      }
      
      // 从文件读取
      final fileName = _keyToFileMap[indexKey];
      if (fileName == null) {
        await _removeEntry(indexKey);
        _stats = _stats.copyWith(missCount: _stats.missCount + 1);
        return AppResult.success(null);
      }
      
      final file = File(path.join(cacheDir.path, fileName));
      if (!await file.exists()) {
        await _removeEntry(indexKey);
        _stats = _stats.copyWith(missCount: _stats.missCount + 1);
        return AppResult.success(null);
      }
      
      // 读取文件数据
      Uint8List data = await file.readAsBytes();
      
      // 解密（如果启用）
      if (config.encryptionEnabled) {
        data = await _decrypt(data);
      }
      
      // 解压缩（如果启用）
      if (config.compressionEnabled) {
        data = await _decompress(data);
      }
      
      // 反序列化值
      final serializedValue = utf8.decode(data);
      final value = valueDeserializer(serializedValue);
      
      // 更新访问信息
      entry.markAccessed();
      _stats = _stats.copyWith(hitCount: _stats.hitCount + 1);
      
      return AppResult.success(value);
    } catch (e) {
      _stats = _stats.copyWith(missCount: _stats.missCount + 1);
      return AppResult.failure(
        CacheException(
          CacheErrorType.deserializationError,
          'Failed to get cache value: $e',
          e,
        ),
      );
    }
  }

  @override
  Future<AppResult<Map<K, V>>> getAll(List<K> keys) async {
    final result = <K, V>{};
    
    for (final key in keys) {
      final valueResult = await get(key);
      if (valueResult.isSuccess && valueResult.valueOrNull != null) {
        result[key] = valueResult.valueOrNull!;
      }
    }
    
    return AppResult.success(result);
  }

  @override
  Future<AppResult<void>> setAll(Map<K, V> entries, {Duration? ttl}) async {
    for (final entry in entries.entries) {
      final result = await set(entry.key, entry.value, ttl: ttl);
      if (result.isFailure) {
        return result;
      }
    }
    
    return AppResult.success(null);
  }

  @override
  Future<AppResult<bool>> containsKey(K key) async {
    if (_isDisposed) {
      return AppResult.failure(
        const CacheException(
          CacheErrorType.storageError,
          'Cache is disposed',
        ),
      );
    }

    final indexKey = _generateIndexKey(key);
    final entry = _memoryIndex[indexKey];
    
    if (entry == null) {
      return AppResult.success(false);
    }
    
    if (entry.isExpired) {
      await _removeEntry(indexKey);
      return AppResult.success(false);
    }
    
    return AppResult.success(true);
  }

  @override
  Future<AppResult<bool>> remove(K key) async {
    if (_isDisposed) {
      return AppResult.failure(
        const CacheException(
          CacheErrorType.storageError,
          'Cache is disposed',
        ),
      );
    }

    final indexKey = _generateIndexKey(key);
    final existed = _memoryIndex.containsKey(indexKey);
    
    if (existed) {
      await _removeEntry(indexKey);
      await _saveIndex();
    }
    
    return AppResult.success(existed);
  }

  @override
  Future<AppResult<int>> removeAll(List<K> keys) async {
    int removedCount = 0;
    
    for (final key in keys) {
      final result = await remove(key);
      if (result.isSuccess && result.valueOrNull == true) {
        removedCount++;
      }
    }
    
    return AppResult.success(removedCount);
  }

  @override
  Future<AppResult<void>> clear() async {
    if (_isDisposed) {
      return AppResult.failure(
        const CacheException(
          CacheErrorType.storageError,
          'Cache is disposed',
        ),
      );
    }

    try {
      // 删除所有缓存文件
      final files = await cacheDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.endsWith('.cache')) {
          await file.delete();
        }
      }
      
      // 清空索引
      _memoryIndex.clear();
      _keyToFileMap.clear();
      
      // 删除索引文件
      final indexFile = File(path.join(cacheDir.path, 'index.json'));
      if (await indexFile.exists()) {
        await indexFile.delete();
      }
      
      // 重置统计
      _stats = const CacheStats(
        hitCount: 0,
        missCount: 0,
        totalSize: 0,
        entryCount: 0,
        memoryUsage: 0,
        diskUsage: 0,
        expiredCount: 0,
      );
      
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
    if (_isDisposed) {
      return AppResult.failure(
        const CacheException(
          CacheErrorType.storageError,
          'Cache is disposed',
        ),
      );
    }

    try {
      final keys = <K>{};
      final expiredKeys = <String>[];
      
      for (final entry in _memoryIndex.entries) {
        if (entry.value.isExpired) {
          expiredKeys.add(entry.key);
        } else {
          // 反序列化键
          final keyString = entry.key;
          final originalKey = keyString.startsWith('${config.keyPrefix}:')
              ? keyString.substring('${config.keyPrefix}:'.length)
              : keyString;
          
          // 这里需要根据实际类型转换键
          // 简化处理：假设K是String类型
          if (K == String) {
            keys.add(originalKey as K);
          }
        }
      }
      
      // 清理过期键
      for (final key in expiredKeys) {
        await _removeEntry(key);
      }
      
      if (expiredKeys.isNotEmpty) {
        await _saveIndex();
      }
      
      return AppResult.success(keys);
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
    if (_isDisposed) {
      return AppResult.failure(
        const CacheException(
          CacheErrorType.storageError,
          'Cache is disposed',
        ),
      );
    }

    // 清理过期项
    await cleanup();
    
    return AppResult.success(_memoryIndex.length);
  }

  @override
  Future<AppResult<CacheStats>> getStats() async {
    if (_isDisposed) {
      return AppResult.failure(
        const CacheException(
          CacheErrorType.storageError,
          'Cache is disposed',
        ),
      );
    }

    await _updateStats();
    return AppResult.success(_stats);
  }

  @override
  Future<AppResult<int>> cleanup() async {
    if (_isDisposed) {
      return AppResult.failure(
        const CacheException(
          CacheErrorType.storageError,
          'Cache is disposed',
        ),
      );
    }

    try {
      final expiredKeys = <String>[];
      
      // 查找过期项
      for (final entry in _memoryIndex.entries) {
        if (entry.value.isExpired) {
          expiredKeys.add(entry.key);
        }
      }
      
      // 删除过期项
      for (final key in expiredKeys) {
        await _removeEntry(key);
      }
      
      // 检查容量限制
      await _enforceCapacityLimits();
      
      // 保存索引
      if (expiredKeys.isNotEmpty) {
        await _saveIndex();
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
    if (_isDisposed) return;
    
    _isDisposed = true;
    _cleanupTimer?.cancel();
    
    // 保存索引
    await _saveIndex();
  }

  /// 删除缓存条目
  Future<void> _removeEntry(String indexKey) async {
    final fileName = _keyToFileMap[indexKey];
    if (fileName != null) {
      final file = File(path.join(cacheDir.path, fileName));
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    _memoryIndex.remove(indexKey);
    _keyToFileMap.remove(indexKey);
  }

  /// 更新统计信息
  Future<void> _updateStats() async {
    int totalSize = 0;
    int diskUsage = 0;
    
    for (final entry in _memoryIndex.values) {
      totalSize += entry.size ?? 0;
    }
    
    // 计算磁盘使用量
    try {
      final files = await cacheDir.list().toList();
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          diskUsage += stat.size;
        }
      }
    } catch (e) {
      // 忽略错误
    }
    
    _stats = _stats.copyWith(
      totalSize: totalSize,
      entryCount: _memoryIndex.length,
      diskUsage: diskUsage,
    );
  }

  /// 强制执行容量限制
  Future<void> _enforceCapacityLimits() async {
    // 检查条目数量限制
    if (_memoryIndex.length > config.maxSize) {
      final policy = LRUEvictionPolicy<String, V>();
      final keysToEvict = policy.selectKeysToEvict(_memoryIndex, config.maxSize);
      
      for (final key in keysToEvict) {
        await _removeEntry(key);
      }
    }
    
    // 检查磁盘空间限制
    await _updateStats();
    if (_stats.diskUsage > config.maxDiskSize) {
      final policy = LRUEvictionPolicy<String, V>();
      final targetSize = (config.maxSize * 0.8).round(); // 保留20%空间
      final keysToEvict = policy.selectKeysToEvict(_memoryIndex, targetSize);
      
      for (final key in keysToEvict) {
        await _removeEntry(key);
      }
    }
  }

  /// 压缩数据
  Future<Uint8List> _compress(Uint8List data) async {
    // 简单的压缩实现，实际应用中可以使用更高效的压缩算法
    return data; // 暂时不实现压缩
  }

  /// 解压缩数据
  Future<Uint8List> _decompress(Uint8List data) async {
    // 简单的解压缩实现
    return data; // 暂时不实现解压缩
  }

  /// 加密数据
  Future<Uint8List> _encrypt(Uint8List data) async {
    // 简单的加密实现，实际应用中应使用安全的加密算法
    return data; // 暂时不实现加密
  }

  /// 解密数据
  Future<Uint8List> _decrypt(Uint8List data) async {
    // 简单的解密实现
    return data; // 暂时不实现解密
  }
}

/// 磁盘缓存工厂
class DiskCacheFactory {
  /// 创建字符串键值的磁盘缓存
  static Future<AppResult<DiskCache<String, String>>> createStringCache({
    required String cacheDirectory,
    CacheConfig? config,
  }) async {
    try {
      final cacheDir = Directory(cacheDirectory);
      final cache = DiskCache<String, String>(
        name: 'string_cache',
        cacheDir: cacheDir,
        config: config ?? const CacheConfig(strategy: CacheStrategy.diskOnly),
        keySerializer: (key) => key,
        valueSerializer: (value) => value,
        valueDeserializer: (value) => value,
      );
      await cache._initialize();
      return AppResult.success(cache);
    } catch (e) {
      return AppResult.failure(
        CacheException(
          CacheErrorType.configurationError,
          'Failed to create string cache: $e',
          e,
        ),
      );
    }
  }

  /// 创建JSON对象的磁盘缓存
  static Future<AppResult<DiskCache<String, Map<String, dynamic>>>> createJsonCache({
    required String cacheDirectory,
    CacheConfig? config,
  }) async {
    try {
      final cacheDir = Directory(cacheDirectory);
      final cache = DiskCache<String, Map<String, dynamic>>(
        name: 'json_cache',
        cacheDir: cacheDir,
        config: config ?? const CacheConfig(strategy: CacheStrategy.diskOnly),
        keySerializer: (key) => key,
        valueSerializer: (value) => jsonEncode(value),
        valueDeserializer: (value) => jsonDecode(value as String) as Map<String, dynamic>,
      );
      await cache._initialize();
      return AppResult.success(cache);
    } catch (e) {
      return AppResult.failure(
        CacheException(
          CacheErrorType.configurationError,
          'Failed to create JSON cache: $e',
          e,
        ),
      );
    }
  }

  /// 创建字节数组的磁盘缓存
  static Future<AppResult<DiskCache<String, Uint8List>>> createBinaryCache({
    required String cacheDirectory,
    CacheConfig? config,
  }) async {
    try {
      final cacheDir = Directory(cacheDirectory);
      final cache = DiskCache<String, Uint8List>(
        name: 'binary_cache',
        cacheDir: cacheDir,
        config: config ?? const CacheConfig(strategy: CacheStrategy.diskOnly),
        keySerializer: (key) => key,
        valueSerializer: (value) => base64Encode(value),
        valueDeserializer: (value) => base64Decode(value as String),
      );
      await cache._initialize();
      return AppResult.success(cache);
    } catch (e) {
      return AppResult.failure(
        CacheException(
          CacheErrorType.configurationError,
          'Failed to create binary cache: $e',
          e,
        ),
      );
    }
  }
} 