// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:v7_flutter_app/shared/database/database.dart';
import 'package:v7_flutter_app/shared/network/api_client.dart';
import 'package:v7_flutter_app/shared/storage/local_storage.dart';
import 'package:v7_flutter_app/shared/types/result.dart';

/// 简单的内存LocalStorage实现（用于测试和开发）
class MemoryLocalStorage extends LocalStorage {
  final Map<String, String> _data = {};

  @override
  Future<AppResult<void>> setString(String key, String value) async {
    _data[key] = value;
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<String?>> getString(String key) async {
    return AppResult.success(_data[key]);
  }

  @override
  Future<AppResult<void>> setInt(String key, int value) async {
    _data[key] = value.toString();
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<int?>> getInt(String key) async {
    final value = _data[key];
    if (value == null) return const AppResult.success(null);
    try {
      return AppResult.success(int.parse(value));
    } catch (e) {
      return AppResult.failure(StorageException(
        StorageErrorType.typeMismatch,
        'Failed to parse int: $e',
        e,
      ));
    }
  }

  @override
  Future<AppResult<void>> setBool(String key, bool value) async {
    _data[key] = value.toString();
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<bool?>> getBool(String key) async {
    final value = _data[key];
    if (value == null) return const AppResult.success(null);
    return AppResult.success(value.toLowerCase() == 'true');
  }

  @override
  Future<AppResult<void>> setDouble(String key, double value) async {
    _data[key] = value.toString();
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<double?>> getDouble(String key) async {
    final value = _data[key];
    if (value == null) return const AppResult.success(null);
    try {
      return AppResult.success(double.parse(value));
    } catch (e) {
      return AppResult.failure(StorageException(
        StorageErrorType.typeMismatch,
        'Failed to parse double: $e',
        e,
      ));
    }
  }

  @override
  Future<AppResult<void>> setStringList(String key, List<String> value) async {
    _data[key] = value.join('\n');
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<List<String>?>> getStringList(String key) async {
    final value = _data[key];
    if (value == null) return const AppResult.success(null);
    return AppResult.success(value.split('\n'));
  }

  @override
  Future<AppResult<void>> setJson<T>(String key, T value, {Map<String, dynamic> Function(T)? toJson}) async {
    // 简化实现，直接存储toString
    _data[key] = value.toString();
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<T?>> getJson<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    // 简化实现，返回null
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<void>> setWithExpiry<T>(String key, T value, Duration ttl) async {
    _data[key] = value.toString();
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<T?>> getWithExpiry<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<void>> remove(String key) async {
    _data.remove(key);
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<bool>> containsKey(String key) async {
    return AppResult.success(_data.containsKey(key));
  }

  @override
  Future<AppResult<void>> clear() async {
    _data.clear();
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<Set<String>>> getKeys() async {
    return AppResult.success(_data.keys.toSet());
  }

  @override
  Future<AppResult<Set<String>>> getKeysByPrefix(String prefix) async {
    final keys = _data.keys.where((key) => key.startsWith(prefix)).toSet();
    return AppResult.success(keys);
  }

  @override
  Future<AppResult<void>> setBatch(Map<String, dynamic> data) async {
    for (final entry in data.entries) {
      _data[entry.key] = entry.value.toString();
    }
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<Map<String, dynamic>>> getBatch(Set<String> keys) async {
    final result = <String, dynamic>{};
    for (final key in keys) {
      if (_data.containsKey(key)) {
        result[key] = _data[key];
      }
    }
    return AppResult.success(result);
  }

  @override
  Future<AppResult<void>> removeBatch(Set<String> keys) async {
    for (final key in keys) {
      _data.remove(key);
    }
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<int>> getSize() async {
    int totalSize = 0;
    for (final entry in _data.entries) {
      totalSize += entry.key.length + entry.value.length;
    }
    return AppResult.success(totalSize);
  }

  @override
  Future<AppResult<int>> getKeySize(String key) async {
    final value = _data[key];
    if (value == null) return const AppResult.success(0);
    return AppResult.success(key.length + value.length);
  }

  @override
  Future<void> dispose() async {
    _data.clear();
  }
}

/// API客户端提供器
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

/// 数据库提供器
final databaseProvider = Provider<Database>((ref) {
  throw UnimplementedError('Database provider not implemented');
});

/// 本地存储提供器
final localStorageProvider = Provider<LocalStorage>((ref) {
  return MemoryLocalStorage();
}); 