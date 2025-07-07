// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:v7_flutter_app/shared/network/api_client.dart';
import 'package:v7_flutter_app/shared/providers/providers.dart';
import 'package:v7_flutter_app/shared/storage/local_storage.dart';
import 'package:v7_flutter_app/shared/sync/sync_manager.dart';
import 'package:v7_flutter_app/shared/types/result.dart';

/// 同步数据类型
enum SyncDataType {
  /// 用户配置
  userSettings,
  /// 用户数据
  userData,
  /// 应用状态
  appState,
  /// 文件数据
  fileData,
  /// 缓存数据
  cacheData,
}

/// 同步项目基类
abstract class SyncItem {
  const SyncItem({
    required this.id,
    required this.type,
    required this.lastModified,
    required this.data,
    this.checksum,
  });

  final String id;
  final SyncDataType type;
  final DateTime lastModified;
  final Map<String, dynamic> data;
  final String? checksum;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'lastModified': lastModified.toIso8601String(),
    'data': data,
    'checksum': checksum,
  };
}

/// 用户设置同步项
class UserSettingsSyncItem extends SyncItem {
  const UserSettingsSyncItem({
    required super.id,
    required super.lastModified,
    required super.data,
    super.checksum,
  }) : super(type: SyncDataType.userSettings);

  factory UserSettingsSyncItem.fromJson(Map<String, dynamic> json) {
    return UserSettingsSyncItem(
      id: json['id'] as String,
      lastModified: DateTime.parse(json['lastModified'] as String),
      data: json['data'] as Map<String, dynamic>,
      checksum: json['checksum'] as String?,
    );
  }
}

/// 用户数据同步项
class UserDataSyncItem extends SyncItem {
  const UserDataSyncItem({
    required super.id,
    required super.lastModified,
    required super.data,
    super.checksum,
  }) : super(type: SyncDataType.userData);

  factory UserDataSyncItem.fromJson(Map<String, dynamic> json) {
    return UserDataSyncItem(
      id: json['id'] as String,
      lastModified: DateTime.parse(json['lastModified'] as String),
      data: json['data'] as Map<String, dynamic>,
      checksum: json['checksum'] as String?,
    );
  }
}

/// 同步数据提供者接口
abstract class DataSyncProvider<T extends SyncItem> {
  /// 获取本地数据
  Future<Result<List<T>, String>> getLocalData();
  
  /// 获取远程数据
  Future<Result<List<T>, String>> getRemoteData();
  
  /// 保存本地数据
  Future<Result<void, String>> saveLocalData(List<T> items);
  
  /// 上传远程数据
  Future<Result<void, String>> uploadRemoteData(List<T> items);
  
  /// 获取数据类型
  SyncDataType get dataType;
}

/// 用户设置同步提供者
class UserSettingsSyncProvider implements DataSyncProvider<UserSettingsSyncItem> {
  UserSettingsSyncProvider({
    required this.localStorage,
    required this.apiClient,
  });

  final LocalStorage localStorage;
  final ApiClient apiClient;

  @override
  SyncDataType get dataType => SyncDataType.userSettings;

  @override
  Future<Result<List<UserSettingsSyncItem>, String>> getLocalData() async {
    try {
      final result = await localStorage.getString('user_settings');
      if (result.isFailure) {
        return Result.failure('Failed to get local user settings: ${result.errorOrNull}');
      }
      
      if (result.valueOrNull != null) {
        final jsonString = result.valueOrNull!;
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final items = <UserSettingsSyncItem>[];
        
        for (final entry in data.entries) {
          items.add(UserSettingsSyncItem(
            id: entry.key,
            lastModified: DateTime.now(),
            data: {'value': entry.value},
          ));
        }
        
        return Result.success(items);
      }
      return const Result.success([]);
    } catch (e) {
      return Result.failure('Failed to get local user settings: $e');
    }
  }

  @override
  Future<Result<List<UserSettingsSyncItem>, String>> getRemoteData() async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/sync/user-settings',
      );
      
      final items = <UserSettingsSyncItem>[];
      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      
      for (final entry in data.entries) {
        items.add(UserSettingsSyncItem(
          id: entry.key,
          lastModified: DateTime.now(),
          data: {'value': entry.value},
        ));
      }
      
      return Result.success(items);
    } catch (e) {
      return Result.failure('Failed to get remote user settings: $e');
    }
  }

  @override
  Future<Result<void, String>> saveLocalData(List<UserSettingsSyncItem> items) async {
    try {
      final data = <String, dynamic>{};
      for (final item in items) {
        data[item.id] = item.data['value'];
      }
      
      final jsonString = jsonEncode(data);
      final result = await localStorage.setString('user_settings', jsonString);
      
      if (result.isSuccess) {
        return const Result.success(null);
      } else {
        return Result.failure('Failed to save local user settings: ${result.errorOrNull}');
      }
    } catch (e) {
      return Result.failure('Failed to save local user settings: $e');
    }
  }

  @override
  Future<Result<void, String>> uploadRemoteData(List<UserSettingsSyncItem> items) async {
    try {
      final data = <String, dynamic>{};
      for (final item in items) {
        data[item.id] = item.data['value'];
      }
      
      await apiClient.post<void>(
        '/sync/user-settings',
        data: {'data': data},
      );
      
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Failed to upload user settings: $e');
    }
  }
}

/// 用户数据同步提供者
class UserDataSyncProvider implements DataSyncProvider<UserDataSyncItem> {
  UserDataSyncProvider({
    required this.localStorage,
    required this.apiClient,
  });

  final LocalStorage localStorage;
  final ApiClient apiClient;

  @override
  SyncDataType get dataType => SyncDataType.userData;

  @override
  Future<Result<List<UserDataSyncItem>, String>> getLocalData() async {
    try {
      final result = await localStorage.getString('user_data');
      if (result.isFailure) {
        return Result.failure('Failed to get local user data: ${result.errorOrNull}');
      }
      
      if (result.valueOrNull != null) {
        final jsonString = result.valueOrNull!;
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final items = <UserDataSyncItem>[];
        
        for (final entry in data.entries) {
          items.add(UserDataSyncItem(
            id: entry.key,
            lastModified: DateTime.now(),
            data: entry.value as Map<String, dynamic>,
          ));
        }
        
        return Result.success(items);
      }
      return const Result.success([]);
    } catch (e) {
      return Result.failure('Failed to get local user data: $e');
    }
  }

  @override
  Future<Result<List<UserDataSyncItem>, String>> getRemoteData() async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/sync/user-data',
      );
      
      final items = <UserDataSyncItem>[];
      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      
      for (final entry in data.entries) {
        items.add(UserDataSyncItem(
          id: entry.key,
          lastModified: DateTime.now(),
          data: entry.value as Map<String, dynamic>,
        ));
      }
      
      return Result.success(items);
    } catch (e) {
      return Result.failure('Failed to get remote user data: $e');
    }
  }

  @override
  Future<Result<void, String>> saveLocalData(List<UserDataSyncItem> items) async {
    try {
      final data = <String, dynamic>{};
      for (final item in items) {
        data[item.id] = item.data;
      }
      
      final jsonString = jsonEncode(data);
      final result = await localStorage.setString('user_data', jsonString);
      
      if (result.isSuccess) {
        return const Result.success(null);
      } else {
        return Result.failure('Failed to save local user data: ${result.errorOrNull}');
      }
    } catch (e) {
      return Result.failure('Failed to save local user data: $e');
    }
  }

  @override
  Future<Result<void, String>> uploadRemoteData(List<UserDataSyncItem> items) async {
    try {
      final data = <String, dynamic>{};
      for (final item in items) {
        data[item.id] = item.data;
      }
      
      await apiClient.post<void>(
        '/sync/user-data',
        data: {'data': data},
      );
      
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Failed to upload user data: $e');
    }
  }
}

/// 同步提供者管理器
class DataSyncProviderManager {
  DataSyncProviderManager({
    required this.localStorage,
    required this.apiClient,
  }) {
    _providers = {
      SyncDataType.userSettings: UserSettingsSyncProvider(
        localStorage: localStorage,
        apiClient: apiClient,
      ),
      SyncDataType.userData: UserDataSyncProvider(
        localStorage: localStorage,
        apiClient: apiClient,
      ),
    };
  }

  final LocalStorage localStorage;
  final ApiClient apiClient;
  late final Map<SyncDataType, DataSyncProvider> _providers;

  /// 获取指定类型的同步提供者
  DataSyncProvider<T>? getProvider<T extends SyncItem>(SyncDataType type) {
    return _providers[type] as DataSyncProvider<T>?;
  }

  /// 获取所有支持的数据类型
  List<SyncDataType> get supportedTypes => _providers.keys.toList();

  /// 同步指定类型的数据
  Future<Result<void, String>> syncData(SyncDataType type) async {
    final provider = _providers[type];
    if (provider == null) {
      return Result.failure('No provider found for type: $type');
    }

    try {
      // 获取本地数据
      final localResult = await provider.getLocalData();
      if (localResult.isFailure) {
        return Result.failure('Failed to get local data: ${localResult.errorOrNull}');
      }

      // 获取远程数据
      final remoteResult = await provider.getRemoteData();
      if (remoteResult.isFailure) {
        return Result.failure('Failed to get remote data: ${remoteResult.errorOrNull}');
      }

      // 简化的同步逻辑：以远程数据为准
      final remoteData = remoteResult.valueOrNull ?? [];
      if (remoteData.isNotEmpty) {
        final saveResult = await provider.saveLocalData(remoteData);
        if (saveResult.isFailure) {
          return Result.failure('Failed to save local data: ${saveResult.errorOrNull}');
        }
      }

      return const Result.success(null);
    } catch (e) {
      return Result.failure('Sync failed: $e');
    }
  }

  /// 同步所有支持的数据类型
  Future<Result<void, String>> syncAllData() async {
    final errors = <String>[];

    for (final type in supportedTypes) {
      final result = await syncData(type);
      if (result.isFailure) {
        errors.add('${type.name}: ${result.errorOrNull}');
      }
    }

    if (errors.isNotEmpty) {
      return Result.failure('Sync errors: ${errors.join(', ')}');
    }

    return const Result.success(null);
  }
}

/// Riverpod 提供器
final dataSyncProviderManagerProvider = Provider<DataSyncProviderManager>((ref) {
  return DataSyncProviderManager(
    localStorage: ref.read(localStorageProvider),
    apiClient: ref.read(apiClientProvider),
  );
});

final userSettingsSyncProvider = Provider<UserSettingsSyncProvider>((ref) {
  return UserSettingsSyncProvider(
    localStorage: ref.read(localStorageProvider),
    apiClient: ref.read(apiClientProvider),
  );
});

final userDataSyncProvider = Provider<UserDataSyncProvider>((ref) {
  return UserDataSyncProvider(
    localStorage: ref.read(localStorageProvider),
    apiClient: ref.read(apiClientProvider),
  );
}); 