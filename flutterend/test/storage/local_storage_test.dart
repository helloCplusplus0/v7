import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/storage/local_storage.dart';
import 'package:v7_flutter_app/shared/types/result.dart';

void main() {
  group('StorageException Tests', () {
    test('should create storage exception with correct type and message', () {
      const exception = StorageException(
        StorageErrorType.keyNotFound,
        'Key not found',
      );
      
      expect(exception.type, equals(StorageErrorType.keyNotFound));
      expect(exception.message, equals('Key not found'));
      expect(exception.toString(), contains('StorageException'));
      expect(exception.toString(), contains('Key not found'));
      expect(exception.toString(), contains('keyNotFound'));
    });
    
    test('should create storage exception with cause', () {
      final originalError = Exception('Original error');
      final exception = StorageException(
        StorageErrorType.serializationError,
        'Failed to serialize',
        originalError,
      );
      
      expect(exception.cause, equals(originalError));
    });
  });
  
  group('StorageConfig Tests', () {
    test('should create default config', () {
      const config = StorageConfig();
      
      expect(config.strategy, equals(StorageStrategy.persistent));
      expect(config.encryptionEnabled, isFalse);
      expect(config.compressionEnabled, isFalse);
      expect(config.maxSize, isNull);
      expect(config.defaultTtl, isNull);
      expect(config.keyPrefix, isNull);
      expect(config.autoCleanup, isTrue);
      expect(config.cleanupInterval, equals(Duration(hours: 1)));
    });
    
    test('should create config with custom values', () {
      const config = StorageConfig(
        strategy: StorageStrategy.secure,
        encryptionEnabled: true,
        compressionEnabled: true,
        maxSize: 1024 * 1024,
        defaultTtl: Duration(minutes: 30),
        keyPrefix: 'app_',
        autoCleanup: false,
        cleanupInterval: Duration(minutes: 30),
      );
      
      expect(config.strategy, equals(StorageStrategy.secure));
      expect(config.encryptionEnabled, isTrue);
      expect(config.compressionEnabled, isTrue);
      expect(config.maxSize, equals(1024 * 1024));
      expect(config.defaultTtl, equals(Duration(minutes: 30)));
      expect(config.keyPrefix, equals('app_'));
      expect(config.autoCleanup, isFalse);
      expect(config.cleanupInterval, equals(Duration(minutes: 30)));
    });
    
    test('should copy config with updated values', () {
      const originalConfig = StorageConfig(
        strategy: StorageStrategy.memory,
        encryptionEnabled: false,
      );
      
      final updatedConfig = originalConfig.copyWith(
        strategy: StorageStrategy.persistent,
        encryptionEnabled: true,
      );
      
      expect(updatedConfig.strategy, equals(StorageStrategy.persistent));
      expect(updatedConfig.encryptionEnabled, isTrue);
      expect(updatedConfig.compressionEnabled, equals(originalConfig.compressionEnabled));
    });
  });
  
  group('StorageItem Tests', () {
    test('should create storage item correctly', () {
      final now = DateTime.now();
      final expiresAt = now.add(Duration(hours: 1));
      
      final item = StorageItem(
        value: 'test_value',
        createdAt: now,
        expiresAt: expiresAt,
        metadata: {'version': 1},
      );
      
      expect(item.value, equals('test_value'));
      expect(item.createdAt, equals(now));
      expect(item.expiresAt, equals(expiresAt));
      expect(item.metadata, equals({'version': 1}));
    });
    
    test('should detect expired items correctly', () {
      final pastTime = DateTime.now().subtract(Duration(hours: 1));
      final futureTime = DateTime.now().add(Duration(hours: 1));
      
      final expiredItem = StorageItem(
        value: 'expired',
        createdAt: DateTime.now().subtract(Duration(hours: 2)),
        expiresAt: pastTime,
      );
      
      final validItem = StorageItem(
        value: 'valid',
        createdAt: DateTime.now(),
        expiresAt: futureTime,
      );
      
      final neverExpiresItem = StorageItem(
        value: 'never_expires',
        createdAt: DateTime.now(),
      );
      
      expect(expiredItem.isExpired, isTrue);
      expect(validItem.isExpired, isFalse);
      expect(neverExpiresItem.isExpired, isFalse);
    });
    
    test('should calculate remaining TTL correctly', () {
      final futureTime = DateTime.now().add(Duration(minutes: 30));
      
      final item = StorageItem(
        value: 'test',
        createdAt: DateTime.now(),
        expiresAt: futureTime,
      );
      
      final remainingTtl = item.remainingTtl;
      expect(remainingTtl, isNotNull);
      expect(remainingTtl!.inMinutes, lessThanOrEqualTo(30));
      expect(remainingTtl.inMinutes, greaterThan(25)); // Allow some time tolerance
    });
    
    test('should return null TTL for non-expiring items', () {
      final item = StorageItem(
        value: 'test',
        createdAt: DateTime.now(),
      );
      
      expect(item.remainingTtl, isNull);
    });
    
    test('should return zero TTL for expired items', () {
      final pastTime = DateTime.now().subtract(Duration(hours: 1));
      
      final item = StorageItem(
        value: 'expired',
        createdAt: DateTime.now().subtract(Duration(hours: 2)),
        expiresAt: pastTime,
      );
      
      expect(item.remainingTtl, equals(Duration.zero));
    });
  });
  
  group('Storage Events Tests', () {
    test('should create storage set event', () {
      final event = StorageSetEvent(
        key: 'test_key',
        value: 'test_value',
        oldValue: 'old_value',
      );
      
      expect(event.key, equals('test_key'));
      expect(event.value, equals('test_value'));
      expect(event.oldValue, equals('old_value'));
      expect(event.timestamp, isA<DateTime>());
    });
    
    test('should create storage remove event', () {
      final event = StorageRemoveEvent(
        key: 'removed_key',
        removedValue: 'removed_value',
      );
      
      expect(event.key, equals('removed_key'));
      expect(event.removedValue, equals('removed_value'));
    });
    
    test('should create storage clear event', () {
      final event = StorageClearEvent(clearedCount: 5);
      
      expect(event.key, equals('*'));
      expect(event.clearedCount, equals(5));
    });
    
    test('should create storage expired event', () {
      final event = StorageExpiredEvent(
        key: 'expired_key',
        expiredValue: 'expired_value',
      );
      
      expect(event.key, equals('expired_key'));
      expect(event.expiredValue, equals('expired_value'));
    });
  });
  
  group('StorageStats Tests', () {
    test('should create storage stats correctly', () {
      final stats = StorageStats(
        totalKeys: 10,
        totalSize: 1024,
        expiredKeys: 2,
        lastAccessed: DateTime(2024, 1, 1),
        hitCount: 8,
        missCount: 2,
        errorCount: 1,
        averageKeySize: 102,
        largestKeySize: 512,
      );
      
      expect(stats.totalKeys, equals(10));
      expect(stats.totalSize, equals(1024));
      expect(stats.expiredKeys, equals(2));
      expect(stats.hitCount, equals(8));
      expect(stats.missCount, equals(2));
      expect(stats.errorCount, equals(1));
    });
    
    test('should calculate hit rate correctly', () {
      final stats = StorageStats(
        totalKeys: 10,
        totalSize: 1024,
        expiredKeys: 0,
        lastAccessed: DateTime(2024, 1, 1),
        hitCount: 8,
        missCount: 2,
      );
      
      expect(stats.hitRate, equals(0.8));
    });
    
    test('should calculate error rate correctly', () {
      final stats = StorageStats(
        totalKeys: 10,
        totalSize: 1024,
        expiredKeys: 0,
        lastAccessed: DateTime(2024, 1, 1),
        hitCount: 7,
        missCount: 2,
        errorCount: 1,
      );
      
      expect(stats.errorRate, equals(0.1));
    });
    
    test('should handle zero operations gracefully', () {
      final stats = StorageStats(
        totalKeys: 0,
        totalSize: 0,
        expiredKeys: 0,
        lastAccessed: DateTime(2024, 1, 1),
        hitCount: 0,
        missCount: 0,
        errorCount: 0,
      );
      
      expect(stats.hitRate, equals(0.0));
      expect(stats.errorRate, equals(0.0));
    });
    
    test('should format size correctly', () {
      final bytesStats = StorageStats(
        totalKeys: 1,
        totalSize: 512,
        expiredKeys: 0,
        lastAccessed: DateTime(2024, 1, 1),
      );
      expect(bytesStats.formattedSize, equals('512B'));
      
      final kbStats = StorageStats(
        totalKeys: 1,
        totalSize: 1536, // 1.5KB
        expiredKeys: 0,
        lastAccessed: DateTime(2024, 1, 1),
      );
      expect(kbStats.formattedSize, equals('1.5KB'));
      
      final mbStats = StorageStats(
        totalKeys: 1,
        totalSize: 1572864, // 1.5MB
        expiredKeys: 0,
        lastAccessed: DateTime(2024, 1, 1),
      );
      expect(mbStats.formattedSize, equals('1.5MB'));
    });
    
    test('should copy with updated values', () {
      final originalStats = StorageStats(
        totalKeys: 10,
        totalSize: 1024,
        expiredKeys: 1,
        lastAccessed: DateTime(2024, 1, 1),
        hitCount: 5,
        missCount: 3,
      );
      
      final updatedStats = originalStats.copyWith(
        totalKeys: 12,
        hitCount: 7,
      );
      
      expect(updatedStats.totalKeys, equals(12));
      expect(updatedStats.hitCount, equals(7));
      expect(updatedStats.totalSize, equals(originalStats.totalSize));
      expect(updatedStats.missCount, equals(originalStats.missCount));
    });
    
    test('should generate meaningful toString', () {
      final stats = StorageStats(
        totalKeys: 10,
        totalSize: 1536,
        expiredKeys: 2,
        lastAccessed: DateTime(2024, 1, 1),
        hitCount: 8,
        missCount: 2,
        errorCount: 1,
      );
      
      final string = stats.toString();
      expect(string, contains('keys: 10'));
      expect(string, contains('size: 1.5KB'));
      expect(string, contains('expired: 2'));
      expect(string, contains('hitRate: 80.0%'));
      expect(string, contains('errorRate: 9.1%'));
    });
  });
  
  group('StorageUtils Tests', () {
    test('should validate keys correctly', () {
      expect(StorageUtils.isValidKey('valid_key'), isTrue);
      expect(StorageUtils.isValidKey('valid.key'), isTrue);
      expect(StorageUtils.isValidKey('valid-key'), isTrue);
      expect(StorageUtils.isValidKey('valid123'), isTrue);
      
      // Invalid keys
      expect(StorageUtils.isValidKey(''), isFalse);
      expect(StorageUtils.isValidKey('a' * 256), isFalse); // Too long
      expect(StorageUtils.isValidKey('invalid\x00key'), isFalse); // Control character
      expect(StorageUtils.isValidKey('invalid\x1Fkey'), isFalse); // Control character
    });
    
    test('should generate valid keys', () {
      final key1 = StorageUtils.generateKey(prefix: 'user', suffix: 'profile');
      expect(key1, equals('user_profile'));
      
      final key2 = StorageUtils.generateKey(suffix: 'config');
      expect(key2, equals('config'));
      
      final key3 = StorageUtils.generateKey(prefix: 'invalid!@#', suffix: 'test');
      expect(key3, equals('invalid____test'));
      
      final key4 = StorageUtils.generateKey(prefix: '', suffix: 'empty_prefix');
      expect(key4, equals('empty_prefix'));
    });
    
    test('should serialize primitive values correctly', () {
      expect(StorageUtils.serializeValue(null).valueOrNull, equals('null'));
      expect(StorageUtils.serializeValue('string').valueOrNull, equals('string'));
      expect(StorageUtils.serializeValue(42).valueOrNull, equals('42'));
      expect(StorageUtils.serializeValue(3.14).valueOrNull, equals('3.14'));
      expect(StorageUtils.serializeValue(true).valueOrNull, equals('true'));
      expect(StorageUtils.serializeValue(false).valueOrNull, equals('false'));
    });
    
    test('should serialize complex values as JSON', () {
      final list = [1, 2, 3];
      final result = StorageUtils.serializeValue(list);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, equals('[1,2,3]'));
      
      final map = {'key': 'value', 'number': 42};
      final result2 = StorageUtils.serializeValue(map);
      expect(result2.isSuccess, isTrue);
      expect(result2.valueOrNull, contains('"key":"value"'));
      expect(result2.valueOrNull, contains('"number":42'));
    });
    
    test('should handle null and empty serialization', () {
      expect(StorageUtils.deserializeValue<String?>(null, (v) => v as String?).valueOrNull, isNull);
      expect(StorageUtils.deserializeValue<String?>('null', (v) => v as String?).valueOrNull, isNull);
    });
    
    test('should calculate data size correctly', () {
      expect(StorageUtils.calculateSize('hello'), equals(5));
      expect(StorageUtils.calculateSize(''), equals(0));
      
      // UTF-8 characters should take more bytes
      final unicodeSize = StorageUtils.calculateSize('你好');
      expect(unicodeSize, greaterThan(2)); // More than 2 ASCII characters
      
      final emojiSize = StorageUtils.calculateSize('😀');
      expect(emojiSize, greaterThan(1)); // Emoji takes multiple bytes
    });
  });
  
  group('Storage Strategy Tests', () {
    test('should have all required storage strategies', () {
      expect(StorageStrategy.values, contains(StorageStrategy.memory));
      expect(StorageStrategy.values, contains(StorageStrategy.persistent));
      expect(StorageStrategy.values, contains(StorageStrategy.secure));
      expect(StorageStrategy.values, contains(StorageStrategy.temporary));
    });
  });
  
  group('Storage Error Types Tests', () {
    test('should have all required error types', () {
      expect(StorageErrorType.values, contains(StorageErrorType.keyNotFound));
      expect(StorageErrorType.values, contains(StorageErrorType.typeMismatch));
      expect(StorageErrorType.values, contains(StorageErrorType.serializationError));
      expect(StorageErrorType.values, contains(StorageErrorType.insufficientStorage));
      expect(StorageErrorType.values, contains(StorageErrorType.permissionDenied));
      expect(StorageErrorType.values, contains(StorageErrorType.networkError));
      expect(StorageErrorType.values, contains(StorageErrorType.unknown));
    });
  });
}

/// 测试用的用户类
class TestUser {
  const TestUser({required this.name, required this.email});
  
  final String name;
  final String email;
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
  };
  
  static TestUser fromJson(Map<String, dynamic> json) => TestUser(
    name: json['name'] as String,
    email: json['email'] as String,
  );
} 