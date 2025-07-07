import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/shared/cache/cache.dart';
import '../../lib/shared/types/result.dart';

void main() {
  group('Cache System Tests', () {
    // ========== 枚举和异常测试 ==========
    group('Enums and Exceptions', () {
      test('CacheErrorType should have all expected values', () {
        const expectedTypes = [
          CacheErrorType.keyNotFound,
          CacheErrorType.serializationError,
          CacheErrorType.deserializationError,
          CacheErrorType.compressionError,
          CacheErrorType.encryptionError,
          CacheErrorType.storageError,
          CacheErrorType.configurationError,
          CacheErrorType.operationTimeout,
          CacheErrorType.capacityExceeded,
        ];
        
        expect(CacheErrorType.values, equals(expectedTypes));
      });

      test('CacheStrategy should have all expected values', () {
        const expectedStrategies = [
          CacheStrategy.memoryOnly,
          CacheStrategy.diskOnly,
          CacheStrategy.memoryWithDiskBackup,
          CacheStrategy.tiered,
          CacheStrategy.lru,
          CacheStrategy.lfu,
          CacheStrategy.fifo,
        ];
        
        expect(CacheStrategy.values, equals(expectedStrategies));
      });
    });

    // ========== 异常测试 ==========
    group('CacheException', () {
      test('should create exception with type and message', () {
        const exception = CacheException(
          CacheErrorType.storageError,
          'Storage failed',
        );
        
        expect(exception.type, equals(CacheErrorType.storageError));
        expect(exception.message, equals('Storage failed'));
        expect(exception.cause, isNull);
      });

      test('should create exception with cause', () {
        final cause = Exception('Original error');
        final exception = CacheException(
          CacheErrorType.serializationError,
          'Serialization failed',
          cause,
        );
        
        expect(exception.type, equals(CacheErrorType.serializationError));
        expect(exception.message, equals('Serialization failed'));
        expect(exception.cause, equals(cause));
      });

      test('should have proper toString', () {
        final exception = CacheException(
          CacheErrorType.configurationError,
          'Invalid config',
        );
        
        expect(exception.toString(), 'CacheException(CacheErrorType.configurationError): Invalid config');
      });
    });

    // ========== 配置测试 ==========
    group('CacheConfig', () {
      test('CacheConfig should create with default values', () {
        const config = CacheConfig();
        
        expect(config.maxSize, 1000);
        expect(config.maxMemorySize, 50 * 1024 * 1024);
        expect(config.maxDiskSize, 200 * 1024 * 1024);
        expect(config.defaultTtl, Duration(hours: 1));
        expect(config.cleanupInterval, Duration(minutes: 10));
        expect(config.compressionEnabled, false);
        expect(config.encryptionEnabled, false);
        expect(config.strategy, CacheStrategy.memoryOnly);
        expect(config.persistToDisk, false);
      });

      test('should create with custom values', () {
        const config = CacheConfig(
          strategy: CacheStrategy.lru,
          maxSize: 500,
          maxMemorySize: 25 * 1024 * 1024,
          maxDiskSize: 100 * 1024 * 1024,
          defaultTtl: Duration(minutes: 30),
          cleanupInterval: Duration(minutes: 5),
          compressionEnabled: true,
          encryptionEnabled: true,
          keyPrefix: 'test:',
          persistToDisk: true,
        );
        
        expect(config.strategy, equals(CacheStrategy.lru));
        expect(config.maxSize, equals(500));
        expect(config.maxMemorySize, equals(25 * 1024 * 1024));
        expect(config.maxDiskSize, equals(100 * 1024 * 1024));
        expect(config.defaultTtl, equals(Duration(minutes: 30)));
        expect(config.cleanupInterval, equals(Duration(minutes: 5)));
        expect(config.compressionEnabled, isTrue);
        expect(config.encryptionEnabled, isTrue);
        expect(config.keyPrefix, equals('test:'));
        expect(config.persistToDisk, isTrue);
      });

      test('should validate successfully with valid config', () {
        const config = CacheConfig();
        final result = config.validate();
        
        expect(result.isSuccess, isTrue);
      });

      test('should fail validation with invalid maxSize', () {
        const config = CacheConfig(maxSize: 0);
        final result = config.validate();
        
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<CacheException>());
        expect((result.errorOrNull as CacheException).type, 
               equals(CacheErrorType.configurationError));
      });

      test('should fail validation with invalid maxMemorySize', () {
        const config = CacheConfig(maxMemorySize: -1);
        final result = config.validate();
        
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<CacheException>());
      });

      test('should fail validation with invalid maxDiskSize', () {
        const config = CacheConfig(maxDiskSize: 0);
        final result = config.validate();
        
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<CacheException>());
      });

      test('should copyWith correctly', () {
        const original = CacheConfig();
        final copy = original.copyWith(
          strategy: CacheStrategy.lfu,
          maxSize: 2000,
        );
        
        expect(copy.strategy, equals(CacheStrategy.lfu));
        expect(copy.maxSize, equals(2000));
        expect(copy.maxMemorySize, equals(original.maxMemorySize));
        expect(copy.defaultTtl, equals(original.defaultTtl));
      });
    });

    // ========== 缓存项测试 ==========
    group('CacheEntry', () {
      test('should create cache entry', () {
        final now = DateTime.now();
        final entry = CacheEntry<String>(
          value: 'test value',
          createdAt: now,
        );
        
        expect(entry.value, equals('test value'));
        expect(entry.createdAt, equals(now));
        expect(entry.expiresAt, isNull);
        expect(entry.lastAccessTime, isNull);
        expect(entry.accessCount, equals(0));
        expect(entry.size, isNull);
        expect(entry.metadata, isNull);
      });

      test('should track expiration correctly', () {
        final now = DateTime.now();
        final pastTime = now.subtract(const Duration(hours: 1));
        final futureTime = now.add(const Duration(hours: 1));
        
        final expiredEntry = CacheEntry<String>(
          value: 'expired',
          createdAt: pastTime,
          expiresAt: pastTime,
        );
        
        final validEntry = CacheEntry<String>(
          value: 'valid',
          createdAt: now,
          expiresAt: futureTime,
        );
        
        final noExpiryEntry = CacheEntry<String>(
          value: 'no expiry',
          createdAt: now,
        );
        
        expect(expiredEntry.isExpired, isTrue);
        expect(validEntry.isExpired, isFalse);
        expect(noExpiryEntry.isExpired, isFalse);
      });

      test('should track access correctly', () {
        final entry = CacheEntry<String>(
          value: 'test',
          createdAt: DateTime.now(),
        );
        
        expect(entry.accessCount, equals(0));
        expect(entry.lastAccessTime, isNull);
        
        entry.markAccessed();
        
        expect(entry.accessCount, equals(1));
        expect(entry.lastAccessTime, isNotNull);
        
        entry.markAccessed();
        
        expect(entry.accessCount, equals(2));
      });

      test('should calculate age correctly', () {
        final pastTime = DateTime.now().subtract(const Duration(minutes: 30));
        final entry = CacheEntry<String>(
          value: 'test',
          createdAt: pastTime,
        );
        
        final age = entry.age;
        expect(age.inMinutes, greaterThanOrEqualTo(29));
        expect(age.inMinutes, lessThanOrEqualTo(31));
      });

      test('should calculate time since last access', () {
        final entry = CacheEntry<String>(
          value: 'test',
          createdAt: DateTime.now(),
        );
        
        expect(entry.timeSinceLastAccess, isNull);
        
        entry.markAccessed();
        // 小延迟确保时间差异
        expect(entry.timeSinceLastAccess, isNotNull);
        expect(entry.timeSinceLastAccess!.inMilliseconds, greaterThanOrEqualTo(0));
      });

      test('should copyWith correctly', () {
        final original = CacheEntry<String>(
          value: 'original',
          createdAt: DateTime.now(),
          accessCount: 5,
        );
        
        final copy = original.copyWith(
          value: 'modified',
          accessCount: 10,
        );
        
        expect(copy.value, equals('modified'));
        expect(copy.accessCount, equals(10));
        expect(copy.createdAt, equals(original.createdAt));
      });

      test('should serialize and deserialize to JSON', () {
        final now = DateTime.now();
        final entry = CacheEntry<Map<String, dynamic>>(
          value: {'key': 'value'},
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
          accessCount: 3,
          size: 100,
          metadata: {'source': 'test'},
        );
        
        final json = entry.toJson((value) => value);
        final restored = CacheEntry.fromJson<Map<String, dynamic>>(
          json,
          (data) => data as Map<String, dynamic>,
        );
        
        expect(restored.value, equals(entry.value));
        expect(restored.createdAt.millisecondsSinceEpoch, 
               equals(entry.createdAt.millisecondsSinceEpoch));
        expect(restored.expiresAt?.millisecondsSinceEpoch, 
               equals(entry.expiresAt?.millisecondsSinceEpoch));
        expect(restored.accessCount, equals(entry.accessCount));
        expect(restored.size, equals(entry.size));
        expect(restored.metadata, equals(entry.metadata));
      });
    });

    // ========== 缓存统计测试 ==========
    group('CacheStats', () {
      test('should create cache stats', () {
        const stats = CacheStats(
          hitCount: 100,
          missCount: 20,
          totalSize: 1000,
          entryCount: 50,
          memoryUsage: 2048,
          diskUsage: 4096,
          expiredCount: 5,
          evictionCount: 2,
          averageAccessTime: Duration(milliseconds: 10),
        );
        
        expect(stats.hitCount, equals(100));
        expect(stats.missCount, equals(20));
        expect(stats.totalSize, equals(1000));
        expect(stats.entryCount, equals(50));
        expect(stats.memoryUsage, equals(2048));
        expect(stats.diskUsage, equals(4096));
        expect(stats.expiredCount, equals(5));
        expect(stats.evictionCount, equals(2));
        expect(stats.averageAccessTime, equals(const Duration(milliseconds: 10)));
      });

      test('should calculate metrics correctly', () {
        const stats = CacheStats(
          hitCount: 80,
          missCount: 20,
          totalSize: 1000,
          entryCount: 50,
          memoryUsage: 2048,
          diskUsage: 4096,
          expiredCount: 5,
        );
        
        expect(stats.totalAccess, equals(100));
        expect(stats.hitRate, equals(0.8));
        expect(stats.missRate, equals(0.2));
      });

      test('should handle zero access correctly', () {
        const stats = CacheStats(
          hitCount: 0,
          missCount: 0,
          totalSize: 0,
          entryCount: 0,
          memoryUsage: 0,
          diskUsage: 0,
          expiredCount: 0,
        );
        
        expect(stats.totalAccess, equals(0));
        expect(stats.hitRate, equals(0.0));
        expect(stats.missRate, equals(0.0));
      });

      test('should copyWith correctly', () {
        const original = CacheStats(
          hitCount: 100,
          missCount: 20,
          totalSize: 1000,
          entryCount: 50,
          memoryUsage: 2048,
          diskUsage: 4096,
          expiredCount: 5,
        );
        
        final copy = original.copyWith(
          hitCount: 150,
          missCount: 30,
        );
        
        expect(copy.hitCount, equals(150));
        expect(copy.missCount, equals(30));
        expect(copy.totalSize, equals(original.totalSize));
        expect(copy.entryCount, equals(original.entryCount));
      });

      test('should have proper toString', () {
        const stats = CacheStats(
          hitCount: 80,
          missCount: 20,
          totalSize: 1000,
          entryCount: 50,
          memoryUsage: 2048,
          diskUsage: 4096,
          expiredCount: 5,
        );
        
        final string = stats.toString();
        expect(string, contains('entries: 50'));
        expect(string, contains('hits: 80'));
        expect(string, contains('misses: 20'));
        expect(string, contains('hitRate: 80.0%'));
        expect(string, contains('memoryUsage: 2048B'));
        expect(string, contains('diskUsage: 4096B'));
      });
    });

    // ========== 驱逐策略测试 ==========
    group('Eviction Policies', () {
      late Map<String, CacheEntry<String>> testEntries;
      
      setUp(() {
        final now = DateTime.now();
        testEntries = {
          'key1': CacheEntry<String>(
            value: 'value1',
            createdAt: now.subtract(const Duration(minutes: 10)),
            lastAccessTime: now.subtract(const Duration(minutes: 5)),
            accessCount: 5,
          ),
          'key2': CacheEntry<String>(
            value: 'value2',
            createdAt: now.subtract(const Duration(minutes: 5)),
            lastAccessTime: now.subtract(const Duration(minutes: 2)),
            accessCount: 2,
          ),
          'key3': CacheEntry<String>(
            value: 'value3',
            createdAt: now.subtract(const Duration(minutes: 2)),
            lastAccessTime: now.subtract(const Duration(minutes: 1)),
            accessCount: 10,
          ),
        };
      });

      test('LRUEvictionPolicy should evict least recently used', () {
        final policy = LRUEvictionPolicy<String, String>();
        expect(policy.name, equals('LRU'));
        
        final keysToEvict = policy.selectKeysToEvict(testEntries, 2);
        expect(keysToEvict, hasLength(1));
        expect(keysToEvict.first, equals('key1')); // 最久未访问
      });

      test('LFUEvictionPolicy should evict least frequently used', () {
        final policy = LFUEvictionPolicy<String, String>();
        expect(policy.name, equals('LFU'));
        
        final keysToEvict = policy.selectKeysToEvict(testEntries, 2);
        expect(keysToEvict, hasLength(1));
        expect(keysToEvict.first, equals('key2')); // 访问次数最少
      });

      test('FIFOEvictionPolicy should evict first in', () {
        final policy = FIFOEvictionPolicy<String, String>();
        expect(policy.name, equals('FIFO'));
        
        final keysToEvict = policy.selectKeysToEvict(testEntries, 2);
        expect(keysToEvict, hasLength(1));
        expect(keysToEvict.first, equals('key1')); // 最早创建
      });

      test('should return empty list when no eviction needed', () {
        final policy = LRUEvictionPolicy<String, String>();
        final keysToEvict = policy.selectKeysToEvict(testEntries, 5);
        
        expect(keysToEvict, isEmpty);
      });
    });

    // ========== 序列化器测试 ==========
    group('Serializers', () {
      test('JsonCacheSerializer should work correctly', () {
        final serializer = JsonCacheSerializer();
        final testData = {'name': 'John', 'age': 30, 'active': true};
        
        final serialized = serializer.serialize(testData);
        expect(serialized, isA<Uint8List>());
        
        final deserialized = serializer.deserialize(serialized);
        expect(deserialized, equals(testData));
        
        final estimatedSize = serializer.estimateSize(testData);
        expect(estimatedSize, greaterThan(0));
      });

      test('JsonCacheSerializer should handle serialization errors', () {
        final serializer = JsonCacheSerializer();
        
        // 创建一个无法序列化的对象
        final badData = <String, dynamic>{
          'function': () => 'test', // 函数无法序列化
        };
        
        expect(
          () => serializer.serialize(badData),
          throwsA(isA<CacheException>()),
        );
      });

      test('JsonCacheSerializer should handle deserialization errors', () {
        final serializer = JsonCacheSerializer();
        final invalidData = Uint8List.fromList([0xFF, 0xFE, 0xFD]); // 无效的UTF-8
        
        expect(
          () => serializer.deserialize(invalidData),
          throwsA(isA<CacheException>()),
        );
      });

      test('StringCacheSerializer should work correctly', () {
        final serializer = StringCacheSerializer();
        const testString = 'Hello, World! 你好世界';
        
        final serialized = serializer.serialize(testString);
        expect(serialized, isA<Uint8List>());
        
        final deserialized = serializer.deserialize(serialized);
        expect(deserialized, equals(testString));
        
        final estimatedSize = serializer.estimateSize(testString);
        expect(estimatedSize, greaterThan(testString.length)); // UTF-8编码可能更长
      });
    });

    // ========== 键生成器测试 ==========
    group('Key Generators', () {
      test('StringCacheKeyGenerator should work correctly', () {
        final generator = StringCacheKeyGenerator();
        const input = 'test_key';
        
        expect(generator.generateKey(input), equals(input));
        expect(
          generator.generateKeyWithPrefix('prefix', input),
          equals('prefix:test_key'),
        );
      });

      test('HashCacheKeyGenerator should work correctly', () {
        final generator = HashCacheKeyGenerator();
        const input = 'test_object';
        
        final key = generator.generateKey(input);
        expect(key, equals(input.hashCode.toString()));
        
        final keyWithPrefix = generator.generateKeyWithPrefix('prefix', input);
        expect(keyWithPrefix, equals('prefix:${input.hashCode}'));
      });
    });

    // ========== 事件系统测试 ==========
    group('Cache Events', () {
      test('should create cache events correctly', () {
        final now = DateTime.now();
        
        final hitEvent = CacheHitEvent<String>(key: 'test_key');
        expect(hitEvent.key, equals('test_key'));
        expect(hitEvent.timestamp, isNotNull);
        
        final missEvent = CacheMissEvent<String>(key: 'missing_key');
        expect(missEvent.key, equals('missing_key'));
        
        final setValue = {'data': 'test'};
        final setEvent = CacheSetEvent<String, Map<String, String>>(
          key: 'set_key',
          value: setValue,
          ttl: const Duration(minutes: 30),
        );
        expect(setEvent.key, equals('set_key'));
        expect(setEvent.value, equals(setValue));
        expect(setEvent.ttl, equals(const Duration(minutes: 30)));
        
        final removeEvent = CacheRemoveEvent<String>(key: 'remove_key');
        expect(removeEvent.key, equals('remove_key'));
        
        final evictEvent = CacheEvictEvent<String>(
          key: 'evict_key',
          reason: 'Capacity exceeded',
        );
        expect(evictEvent.key, equals('evict_key'));
        expect(evictEvent.reason, equals('Capacity exceeded'));
        
        final clearEvent = CacheClearEvent<String>();
        expect(clearEvent.key, isNull);
      });

      test('should use custom timestamp when provided', () {
        final customTime = DateTime(2024, 1, 1, 12, 0, 0);
        final event = CacheHitEvent<String>(
          key: 'test',
          timestamp: customTime,
        );
        
        expect(event.timestamp, equals(customTime));
      });
    });

    // ========== 内存缓存测试 ==========
    group('MemoryCache', () {
      late MemoryCache<String, String> cache;
      
      setUp(() {
        cache = MemoryCache<String, String>(
          name: 'test_cache',
          config: const CacheConfig(
            maxSize: 3,
            defaultTtl: Duration(minutes: 5),
            cleanupInterval: Duration(seconds: 1),
          ),
        );
      });
      
      tearDown(() async {
        await cache.close();
      });

      test('should set and get values', () async {
        final setResult = await cache.set('key1', 'value1');
        expect(setResult.isSuccess, isTrue);
        
        final getResult = await cache.get('key1');
        expect(getResult.isSuccess, isTrue);
        expect(getResult.valueOrNull, equals('value1'));
      });

      test('should return null for non-existent keys', () async {
        final result = await cache.get('non_existent');
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });

      test('should handle TTL correctly', () async {
        await cache.set('temp_key', 'temp_value', ttl: const Duration(milliseconds: 100));
        
        // 立即获取应该成功
        final immediateResult = await cache.get('temp_key');
        expect(immediateResult.valueOrNull, equals('temp_value'));
        
        // 等待过期
        await Future.delayed(const Duration(milliseconds: 150));
        
        final expiredResult = await cache.get('temp_key');
        expect(expiredResult.valueOrNull, isNull);
      });

      test('should handle batch operations', () async {
        final entries = {
          'key1': 'value1',
          'key2': 'value2',
          'key3': 'value3',
        };
        
        final setAllResult = await cache.setAll(entries);
        expect(setAllResult.isSuccess, isTrue);
        
        final getAllResult = await cache.getAll(['key1', 'key2', 'key3']);
        expect(getAllResult.isSuccess, isTrue);
        expect(getAllResult.valueOrNull, equals(entries));
      });

      test('should check key existence', () async {
        await cache.set('existing_key', 'value');
        
        final existsResult = await cache.containsKey('existing_key');
        expect(existsResult.isSuccess, isTrue);
        expect(existsResult.valueOrNull, isTrue);
        
        final notExistsResult = await cache.containsKey('non_existent');
        expect(notExistsResult.isSuccess, isTrue);
        expect(notExistsResult.valueOrNull, isFalse);
      });

      test('should remove values', () async {
        await cache.set('to_remove', 'value');
        
        final removeResult = await cache.remove('to_remove');
        expect(removeResult.isSuccess, isTrue);
        expect(removeResult.valueOrNull, isTrue);
        
        final getResult = await cache.get('to_remove');
        expect(getResult.valueOrNull, isNull);
        
        // 删除不存在的键
        final removeNonExistentResult = await cache.remove('non_existent');
        expect(removeNonExistentResult.isSuccess, isTrue);
        expect(removeNonExistentResult.valueOrNull, isFalse);
      });

      test('should handle batch removal', () async {
        await cache.setAll({
          'key1': 'value1',
          'key2': 'value2',
          'key3': 'value3',
        });
        
        final removeAllResult = await cache.removeAll(['key1', 'key3']);
        expect(removeAllResult.isSuccess, isTrue);
        expect(removeAllResult.valueOrNull, equals(2));
        
        final remainingResult = await cache.get('key2');
        expect(remainingResult.valueOrNull, equals('value2'));
      });

      test('should clear all values', () async {
        await cache.setAll({
          'key1': 'value1',
          'key2': 'value2',
        });
        
        final clearResult = await cache.clear();
        expect(clearResult.isSuccess, isTrue);
        
        final sizeResult = await cache.size();
        expect(sizeResult.valueOrNull, equals(0));
      });

      test('should get cache keys', () async {
        final entries = {'key1': 'value1', 'key2': 'value2'};
        await cache.setAll(entries);
        
        final keysResult = await cache.keys();
        expect(keysResult.isSuccess, isTrue);
        expect(keysResult.valueOrNull, equals(entries.keys.toSet()));
      });

      test('should get cache size', () async {
        final sizeEmptyResult = await cache.size();
        expect(sizeEmptyResult.valueOrNull, equals(0));
        
        await cache.setAll({
          'key1': 'value1',
          'key2': 'value2',
        });
        
        final sizeResult = await cache.size();
        expect(sizeResult.valueOrNull, equals(2));
      });

      test('should provide cache stats', () async {
        // 添加一些数据并访问
        await cache.set('key1', 'value1');
        await cache.get('key1'); // hit
        await cache.get('key2'); // miss
        
        final statsResult = await cache.getStats();
        expect(statsResult.isSuccess, isTrue);
        
        final stats = statsResult.valueOrNull!;
        expect(stats.hitCount, equals(1));
        expect(stats.missCount, equals(1));
        expect(stats.entryCount, equals(1));
        expect(stats.hitRate, equals(0.5));
        expect(stats.missRate, equals(0.5));
      });

      test('should cleanup expired entries', () async {
        await cache.set('key1', 'value1', ttl: const Duration(milliseconds: 50));
        await cache.set('key2', 'value2'); // 无过期时间
        
        // 等待过期
        await Future.delayed(const Duration(milliseconds: 100));
        
        final cleanupResult = await cache.cleanup();
        expect(cleanupResult.isSuccess, isTrue);
        expect(cleanupResult.valueOrNull, equals(1)); // 应该清理1个过期项
        
        final remainingResult = await cache.get('key2');
        expect(remainingResult.valueOrNull, equals('value2'));
      });

      test('should evict entries when exceeding capacity', () async {
        // 添加超过容量的项目（最大容量为3）
        await cache.set('key1', 'value1');
        await cache.set('key2', 'value2');
        await cache.set('key3', 'value3');
        await cache.set('key4', 'value4'); // 应该触发驱逐
        
        final sizeResult = await cache.size();
        expect(sizeResult.valueOrNull, lessThanOrEqualTo(3));
      });

      test('should handle event listeners', () async {
        final events = <CacheEvent<String>>[];
        
        cache.addListener((event) {
          events.add(event);
        });
        
        await cache.set('key1', 'value1');
        await cache.get('key1');
        await cache.get('missing');
        await cache.remove('key1');
        await cache.clear();
        
        expect(events, hasLength(5));
        expect(events[0], isA<CacheSetEvent<String, String>>());
        expect(events[1], isA<CacheHitEvent<String>>());
        expect(events[2], isA<CacheMissEvent<String>>());
        expect(events[3], isA<CacheRemoveEvent<String>>());
        expect(events[4], isA<CacheClearEvent<String>>());
        
        cache.clearListeners();
      });
    });

    // ========== 装饰器测试 ==========
    group('Cache Decorators', () {
      late MemoryCache<String, String> baseCache;
      
      setUp(() {
        baseCache = MemoryCache<String, String>(
          name: 'base_cache',
        );
      });
      
      tearDown(() async {
        await baseCache.close();
      });

      test('TimedCacheDecorator should work correctly', () async {
        final timedCache = TimedCacheDecorator(baseCache);
        
        await timedCache.set('key1', 'value1');
        final result = await timedCache.get('key1');
        
        expect(result.valueOrNull, equals('value1'));
      });

      test('RetryCacheDecorator should retry on failure', () async {
        // 创建一个总是失败的缓存
        final failingCache = _FailingCache<String, String>();
        final retryCache = RetryCacheDecorator(
          failingCache,
          maxRetries: 2,
          retryDelay: const Duration(milliseconds: 10),
        );
        
        final result = await retryCache.get('key1');
        expect(result.isFailure, isTrue);
        expect(failingCache.getCallCount, equals(3)); // 初始调用 + 2次重试
      });
    });

    // ========== 工厂测试 ==========
    group('Cache Factory', () {
      test('DefaultCacheFactory should create memory cache', () {
        final factory = DefaultCacheFactory();
        
        expect(factory.implementationType, equals('DefaultCacheFactory'));
        
        final cache = factory.createMemoryCache<String, String>(
          name: 'test_cache',
          config: const CacheConfig(maxSize: 100),
        );
        
        expect(cache, isA<MemoryCache<String, String>>());
      });

      test('DefaultCacheFactory should report availability', () async {
        final factory = DefaultCacheFactory();
        final isAvailable = await factory.isAvailable();
        
        expect(isAvailable, isTrue);
      });

      test('DefaultCacheFactory should throw for unimplemented features', () {
        final factory = DefaultCacheFactory();
        
        expect(
          () => factory.createDiskCache<String, String>(
            name: 'disk_cache',
            directory: '/tmp',
          ),
          throwsUnimplementedError,
        );
        
        expect(
          () => factory.createTieredCache<String, String>(
            name: 'tiered_cache',
            l1Cache: MemoryCache(name: 'l1'),
            l2Cache: MemoryCache(name: 'l2'),
          ),
          throwsUnimplementedError,
        );
      });
    });
  });
}

/// 测试用的总是失败的缓存实现
class _FailingCache<K, V> implements Cache<K, V> {
  int getCallCount = 0;
  
  @override
  Future<AppResult<V?>> get(K key) async {
    getCallCount++;
    return AppResult.failure(
      const CacheException(
        CacheErrorType.storageError,
        'Simulated failure',
      ),
    );
  }
  
  @override
  Future<AppResult<void>> set(K key, V value, {Duration? ttl}) async {
    return AppResult.failure(
      const CacheException(
        CacheErrorType.storageError,
        'Simulated failure',
      ),
    );
  }
  
  @override
  Future<AppResult<Map<K, V>>> getAll(List<K> keys) async {
    return AppResult.failure(
      const CacheException(
        CacheErrorType.storageError,
        'Simulated failure',
      ),
    );
  }
  
  @override
  Future<AppResult<void>> setAll(Map<K, V> entries, {Duration? ttl}) async {
    return AppResult.failure(
      const CacheException(
        CacheErrorType.storageError,
        'Simulated failure',
      ),
    );
  }
  
  @override
  Future<AppResult<bool>> containsKey(K key) async {
    return AppResult.failure(
      const CacheException(
        CacheErrorType.storageError,
        'Simulated failure',
      ),
    );
  }
  
  @override
  Future<AppResult<bool>> remove(K key) async {
    return AppResult.failure(
      const CacheException(
        CacheErrorType.storageError,
        'Simulated failure',
      ),
    );
  }
  
  @override
  Future<AppResult<int>> removeAll(List<K> keys) async {
    return AppResult.failure(
      const CacheException(
        CacheErrorType.storageError,
        'Simulated failure',
      ),
    );
  }
  
  @override
  Future<AppResult<void>> clear() async {
    return AppResult.failure(
      const CacheException(
        CacheErrorType.storageError,
        'Simulated failure',
      ),
    );
  }
  
  @override
  Future<AppResult<Set<K>>> keys() async {
    return AppResult.failure(
      const CacheException(
        CacheErrorType.storageError,
        'Simulated failure',
      ),
    );
  }
  
  @override
  Future<AppResult<int>> size() async {
    return AppResult.failure(
      const CacheException(
        CacheErrorType.storageError,
        'Simulated failure',
      ),
    );
  }
  
  @override
  Future<AppResult<CacheStats>> getStats() async {
    return AppResult.failure(
      const CacheException(
        CacheErrorType.storageError,
        'Simulated failure',
      ),
    );
  }
  
  @override
  Future<AppResult<int>> cleanup() async {
    return AppResult.failure(
      const CacheException(
        CacheErrorType.storageError,
        'Simulated failure',
      ),
    );
  }
  
  @override
  Future<void> close() async {}
}
