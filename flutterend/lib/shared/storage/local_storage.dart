/// Flutter v7 本地存储抽象接口
/// 为离线优先架构提供统一的数据持久化能力

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../types/result.dart';

/// 存储错误类型
enum StorageErrorType {
  /// 键不存在
  keyNotFound,
  /// 值类型错误
  typeMismatch,
  /// 序列化错误
  serializationError,
  /// 存储空间不足
  insufficientStorage,
  /// 权限错误
  permissionDenied,
  /// 网络错误
  networkError,
  /// 未知错误
  unknown,
}

/// 存储异常
class StorageException extends AppError {
  const StorageException(this.type, super.message, [super.cause]);
  
  final StorageErrorType type;
  
  @override
  String toString() => 'StorageException: $message (type: $type)';
}

/// 本地存储接口
/// 定义统一的存储API，支持多种存储实现
abstract class LocalStorage {
  /// 存储字符串值
  Future<AppResult<void>> setString(String key, String value);
  
  /// 获取字符串值
  Future<AppResult<String?>> getString(String key);
  
  /// 存储整数值
  Future<AppResult<void>> setInt(String key, int value);
  
  /// 获取整数值
  Future<AppResult<int?>> getInt(String key);
  
  /// 存储布尔值
  Future<AppResult<void>> setBool(String key, bool value);
  
  /// 获取布尔值
  Future<AppResult<bool?>> getBool(String key);
  
  /// 存储双精度浮点数
  Future<AppResult<void>> setDouble(String key, double value);
  
  /// 获取双精度浮点数
  Future<AppResult<double?>> getDouble(String key);
  
  /// 存储字符串列表
  Future<AppResult<void>> setStringList(String key, List<String> value);
  
  /// 获取字符串列表
  Future<AppResult<List<String>?>> getStringList(String key);
  
  /// 存储JSON对象
  Future<AppResult<void>> setJson<T>(String key, T value, {Map<String, dynamic> Function(T)? toJson});
  
  /// 获取JSON对象
  Future<AppResult<T?>> getJson<T>(String key, T Function(Map<String, dynamic>) fromJson);
  
  /// 存储带过期时间的值
  Future<AppResult<void>> setWithExpiry<T>(String key, T value, Duration ttl);
  
  /// 获取带过期时间检查的值
  Future<AppResult<T?>> getWithExpiry<T>(String key, T Function(Map<String, dynamic>) fromJson);
  
  /// 删除键值
  Future<AppResult<void>> remove(String key);
  
  /// 检查键是否存在
  Future<AppResult<bool>> containsKey(String key);
  
  /// 清空所有数据
  Future<AppResult<void>> clear();
  
  /// 获取所有键
  Future<AppResult<Set<String>>> getKeys();
  
  /// 根据前缀获取键
  Future<AppResult<Set<String>>> getKeysByPrefix(String prefix);
  
  /// 批量设置
  Future<AppResult<void>> setBatch(Map<String, dynamic> data);
  
  /// 批量获取
  Future<AppResult<Map<String, dynamic>>> getBatch(Set<String> keys);
  
  /// 批量删除
  Future<AppResult<void>> removeBatch(Set<String> keys);
  
  /// 存储大小（字节）
  Future<AppResult<int>> getSize();
  
  /// 获取键对应值的大小
  Future<AppResult<int>> getKeySize(String key);
  
  /// 释放资源
  Future<void> dispose();
}

/// 安全存储接口（用于敏感数据）
abstract class SecureStorage {
  /// 存储敏感数据
  Future<AppResult<void>> setSecure(String key, String value);
  
  /// 获取敏感数据
  Future<AppResult<String?>> getSecure(String key);
  
  /// 删除敏感数据
  Future<AppResult<void>> removeSecure(String key);
  
  /// 检查敏感数据是否存在
  Future<AppResult<bool>> containsSecureKey(String key);
  
  /// 清空所有敏感数据
  Future<AppResult<void>> clearSecure();
  
  /// 获取所有敏感数据键
  Future<AppResult<Set<String>>> getSecureKeys();
}

/// 存储策略
enum StorageStrategy {
  /// 仅内存存储（应用重启丢失）
  memory,
  /// 持久化存储（应用重启保留）
  persistent,
  /// 安全存储（加密）
  secure,
  /// 临时存储（有过期时间）
  temporary,
}

/// 存储配置
class StorageConfig {
  const StorageConfig({
    this.strategy = StorageStrategy.persistent,
    this.encryptionEnabled = false,
    this.compressionEnabled = false,
    this.maxSize,
    this.defaultTtl,
    this.keyPrefix,
    this.autoCleanup = true,
    this.cleanupInterval = const Duration(hours: 1),
  });
  
  final StorageStrategy strategy;
  final bool encryptionEnabled;
  final bool compressionEnabled;
  final int? maxSize; // 最大存储大小（字节）
  final Duration? defaultTtl; // 默认生存时间
  final String? keyPrefix; // 键前缀
  final bool autoCleanup; // 自动清理过期数据
  final Duration cleanupInterval; // 清理间隔
  
  StorageConfig copyWith({
    StorageStrategy? strategy,
    bool? encryptionEnabled,
    bool? compressionEnabled,
    int? maxSize,
    Duration? defaultTtl,
    String? keyPrefix,
    bool? autoCleanup,
    Duration? cleanupInterval,
  }) {
    return StorageConfig(
      strategy: strategy ?? this.strategy,
      encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
      compressionEnabled: compressionEnabled ?? this.compressionEnabled,
      maxSize: maxSize ?? this.maxSize,
      defaultTtl: defaultTtl ?? this.defaultTtl,
      keyPrefix: keyPrefix ?? this.keyPrefix,
      autoCleanup: autoCleanup ?? this.autoCleanup,
      cleanupInterval: cleanupInterval ?? this.cleanupInterval,
    );
  }
}

/// 带过期时间的存储项
class StorageItem<T> {
  const StorageItem({
    required this.value,
    required this.createdAt,
    this.expiresAt,
    this.metadata,
  });
  
  final T value;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? metadata;
  
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
  
  Duration? get remainingTtl {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }
  
  Map<String, dynamic> toJson([dynamic Function(T)? valueToJson]) {
    return {
      'value': valueToJson?.call(value) ?? value,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  static StorageItem<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(dynamic) valueFromJson,
  ) {
    try {
      return StorageItem<T>(
        value: valueFromJson(json['value']),
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: json['expiresAt'] != null 
            ? DateTime.parse(json['expiresAt'] as String) 
            : null,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      throw StorageException(
        StorageErrorType.serializationError,
        'Failed to parse StorageItem from JSON: $e',
        e,
      );
    }
  }
  
  StorageItem<T> copyWith({
    T? value,
    DateTime? createdAt,
    DateTime? expiresAt,
    Map<String, dynamic>? metadata,
  }) {
    return StorageItem<T>(
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// 存储事件
abstract class StorageEvent {
  StorageEvent({required this.key, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
  
  final String key;
  final DateTime timestamp;
}

/// 存储设置事件
class StorageSetEvent extends StorageEvent {
  StorageSetEvent({
    required super.key,
    required this.value,
    this.oldValue,
    super.timestamp,
  });
  
  final dynamic value;
  final dynamic oldValue;
}

/// 存储删除事件
class StorageRemoveEvent extends StorageEvent {
  StorageRemoveEvent({
    required super.key,
    this.removedValue,
    super.timestamp,
  });
  
  final dynamic removedValue;
}

/// 存储清空事件
class StorageClearEvent extends StorageEvent {
  StorageClearEvent({this.clearedCount = 0, super.timestamp}) : super(key: '*');
  
  final int clearedCount;
}

/// 存储过期事件
class StorageExpiredEvent extends StorageEvent {
  StorageExpiredEvent({
    required super.key,
    this.expiredValue,
    super.timestamp,
  });
  
  final dynamic expiredValue;
}

/// 存储监听器
typedef StorageListener = void Function(StorageEvent event);

/// 可观察的存储接口
mixin ObservableStorage on LocalStorage {
  final List<StorageListener> _listeners = [];
  
  /// 添加监听器
  void addListener(StorageListener listener) {
    _listeners.add(listener);
  }
  
  /// 移除监听器
  void removeListener(StorageListener listener) {
    _listeners.remove(listener);
  }
  
  /// 通知监听器
  @protected
  void notifyListeners(StorageEvent event) {
    for (final listener in _listeners) {
      try {
        listener(event);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Storage listener error: $e');
        }
      }
    }
  }
  
  /// 清理监听器
  void clearListeners() {
    _listeners.clear();
  }
  
  /// 获取监听器数量
  int get listenerCount => _listeners.length;
}

/// 存储工厂
abstract class StorageFactory {
  /// 创建本地存储实例
  LocalStorage createLocalStorage({
    required String name,
    StorageConfig? config,
  });
  
  /// 创建安全存储实例
  SecureStorage createSecureStorage({
    required String name,
    StorageConfig? config,
  });
  
  /// 获取存储实现类型
  String get implementationType;
  
  /// 检查存储可用性
  Future<bool> isAvailable();
  
  /// 获取支持的功能
  Set<String> get supportedFeatures;
}

/// 存储统计信息
class StorageStats {
  const StorageStats({
    required this.totalKeys,
    required this.totalSize,
    required this.expiredKeys,
    required this.lastAccessed,
    this.hitCount = 0,
    this.missCount = 0,
    this.errorCount = 0,
    this.averageKeySize = 0,
    this.largestKeySize = 0,
  });
  
  final int totalKeys;
  final int totalSize;
  final int expiredKeys;
  final DateTime lastAccessed;
  final int hitCount;
  final int missCount;
  final int errorCount;
  final int averageKeySize;
  final int largestKeySize;
  
  double get hitRate {
    final total = hitCount + missCount;
    return total > 0 ? hitCount / total : 0.0;
  }
  
  double get errorRate {
    final total = hitCount + missCount + errorCount;
    return total > 0 ? errorCount / total : 0.0;
  }
  
  String get formattedSize {
    if (totalSize < 1024) return '${totalSize}B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)}KB';
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  
  @override
  String toString() {
    return 'StorageStats(keys: $totalKeys, size: $formattedSize, '
           'expired: $expiredKeys, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
           'errorRate: ${(errorRate * 100).toStringAsFixed(1)}%)';
  }
  
  StorageStats copyWith({
    int? totalKeys,
    int? totalSize,
    int? expiredKeys,
    DateTime? lastAccessed,
    int? hitCount,
    int? missCount,
    int? errorCount,
    int? averageKeySize,
    int? largestKeySize,
  }) {
    return StorageStats(
      totalKeys: totalKeys ?? this.totalKeys,
      totalSize: totalSize ?? this.totalSize,
      expiredKeys: expiredKeys ?? this.expiredKeys,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      hitCount: hitCount ?? this.hitCount,
      missCount: missCount ?? this.missCount,
      errorCount: errorCount ?? this.errorCount,
      averageKeySize: averageKeySize ?? this.averageKeySize,
      largestKeySize: largestKeySize ?? this.largestKeySize,
    );
  }
}

/// 存储健康检查
mixin StorageHealthCheck on LocalStorage {
  /// 执行健康检查
  Future<AppResult<StorageStats>> healthCheck();
  
  /// 清理过期数据
  Future<AppResult<int>> cleanupExpired();
  
  /// 压缩存储空间
  Future<AppResult<void>> compact();
  
  /// 获取存储统计
  Future<AppResult<StorageStats>> getStats();
  
  /// 验证存储完整性
  Future<AppResult<bool>> validateIntegrity();
  
  /// 修复损坏的数据
  Future<AppResult<int>> repairCorrupted();
}

/// 存储工具类
class StorageUtils {
  StorageUtils._();
  
  /// 验证键名
  static bool isValidKey(String key) {
    if (key.isEmpty) return false;
    if (key.length > 255) return false;
    // 不允许控制字符
    return !key.contains(RegExp(r'[\x00-\x1F\x7F]'));
  }
  
  /// 生成键名
  static String generateKey({String? prefix, required String suffix}) {
    final cleanPrefix = prefix?.replaceAll(RegExp(r'[^\w.-]'), '_') ?? '';
    final cleanSuffix = suffix.replaceAll(RegExp(r'[^\w.-]'), '_');
    return cleanPrefix.isEmpty ? cleanSuffix : '${cleanPrefix}_$cleanSuffix';
  }
  
  /// 序列化值
  static AppResult<String> serializeValue(dynamic value) {
    try {
      if (value == null) return const AppResult.success('null');
      if (value is String) return AppResult.success(value);
      if (value is num || value is bool) return AppResult.success(value.toString());
      return AppResult.success(jsonEncode(value));
    } catch (e) {
      return AppResult.failure(StorageException(
        StorageErrorType.serializationError,
        'Failed to serialize value: $e',
        e,
      ));
    }
  }
  
  /// 反序列化值
  static AppResult<T?> deserializeValue<T>(String? serialized, T Function(dynamic) fromJson) {
    try {
      if (serialized == null || serialized == 'null') return const AppResult.success(null);
      
      if (T == String) return AppResult.success(serialized as T);
      if (T == int) return AppResult.success(int.parse(serialized) as T);
      if (T == double) return AppResult.success(double.parse(serialized) as T);
      if (T == bool) return AppResult.success((serialized.toLowerCase() == 'true') as T);
      
      final decoded = jsonDecode(serialized);
      return AppResult.success(fromJson(decoded));
    } catch (e) {
      return AppResult.failure(StorageException(
        StorageErrorType.serializationError,
        'Failed to deserialize value: $e',
        e,
      ));
    }
  }
  
  /// 计算数据大小
  static int calculateSize(String data) {
    return utf8.encode(data).length;
  }
} 