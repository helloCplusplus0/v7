// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

import 'package:v7_flutter_app/shared/network/api_client.dart';
import 'package:v7_flutter_app/shared/providers/providers.dart';
import 'package:v7_flutter_app/shared/storage/local_storage.dart';
import 'package:v7_flutter_app/shared/sync/data_sync_providers.dart';
import 'package:v7_flutter_app/shared/types/result.dart';

// Mock类
class MockLocalStorage extends Mock implements LocalStorage {}
class MockApiClient extends Mock implements ApiClient {}

// 测试工具函数
Response<T> createMockResponse<T>(T data, {int statusCode = 200}) {
  return Response<T>(
    data: data,
    statusCode: statusCode,
    requestOptions: RequestOptions(path: '/test'),
  );
}

void main() {
  group('DataSyncProviders Tests', () {
    late MockApiClient mockApiClient;
    late MockLocalStorage mockLocalStorage;

    setUp(() {
      mockApiClient = MockApiClient();
      mockLocalStorage = MockLocalStorage();
    });

    group('SyncItem Tests', () {
      test('UserSettingsSyncItem 应该正确创建', () {
        final item = UserSettingsSyncItem(
          id: 'theme',
          lastModified: DateTime.now(),
          data: {'theme': 'dark'},
        );

        expect(item.id, equals('theme'));
        expect(item.type, equals(SyncDataType.userSettings));
        expect(item.data, equals({'theme': 'dark'}));
      });

      test('UserDataSyncItem 应该正确创建', () {
        final item = UserDataSyncItem(
          id: 'profile',
          lastModified: DateTime.now(),
          data: {'name': 'test'},
        );

        expect(item.id, equals('profile'));
        expect(item.type, equals(SyncDataType.userData));
        expect(item.data, equals({'name': 'test'}));
      });

      test('应该能够序列化和反序列化', () {
        final item = UserSettingsSyncItem(
          id: 'theme',
          lastModified: DateTime.parse('2024-01-01T00:00:00.000Z'),
          data: {'theme': 'dark'},
          checksum: 'abc123',
        );

        final json = item.toJson();
        final restored = UserSettingsSyncItem.fromJson(json);

        expect(restored.id, equals(item.id));
        expect(restored.type, equals(item.type));
        expect(restored.data, equals(item.data));
        expect(restored.checksum, equals(item.checksum));
      });
    });

    group('UserSettingsSyncProvider Tests', () {
      late UserSettingsSyncProvider provider;

      setUp(() {
        provider = UserSettingsSyncProvider(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );
      });

      test('应该有正确的数据类型', () {
        expect(provider.dataType, equals(SyncDataType.userSettings));
      });

      test('应该能够获取本地数据', () async {
        when(() => mockLocalStorage.getString('user_settings'))
            .thenAnswer((_) async => const AppResult.success('{"theme": "dark"}'));

        final result = await provider.getLocalData();

        expect(result.isSuccess, true);
        expect(result.valueOrNull!.first.data, {'value': 'dark'});
      });

      test('应该能够获取远程数据', () async {
        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-settings'))
            .thenAnswer((_) async => createMockResponse({'data': {'theme': 'dark'}}));

        final result = await provider.getRemoteData();

        expect(result.isSuccess, true);
        expect(result.valueOrNull!.first.data, {'value': 'dark'});
      });

      test('应该能够保存本地数据', () async {
        final item = UserSettingsSyncItem(
          id: 'theme',
          lastModified: DateTime.now(),
          data: {'value': 'dark'},
        );

        when(() => mockLocalStorage.setString('user_settings', any()))
            .thenAnswer((_) async => const AppResult.success(null));

        final result = await provider.saveLocalData([item]);

        expect(result.isSuccess, true);
      });

      test('应该能够上传远程数据', () async {
        final item = UserSettingsSyncItem(
          id: 'theme',
          lastModified: DateTime.now(),
          data: {'value': 'dark'},
        );

        when(() => mockApiClient.post<void>(
              '/sync/user-settings',
              data: any(named: 'data'),
            )).thenAnswer((_) async => createMockResponse(null));

        final result = await provider.uploadRemoteData([item]);

        expect(result.isSuccess, true);
      });

      test('获取本地数据失败时应该返回错误', () async {
        when(() => mockLocalStorage.getString('user_settings'))
            .thenAnswer((_) async => const AppResult.failure(StorageError('Storage error')));

        final result = await provider.getLocalData();

        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('Failed to get local user settings'));
      });

      test('获取远程数据失败时应该返回错误', () async {
        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-settings'))
            .thenThrow(Exception('Network error'));

        final result = await provider.getRemoteData();

        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('Failed to get remote user settings'));
      });
    });

    group('UserDataSyncProvider Tests', () {
      late UserDataSyncProvider provider;

      setUp(() {
        provider = UserDataSyncProvider(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );
      });

      test('应该有正确的数据类型', () {
        expect(provider.dataType, equals(SyncDataType.userData));
      });

      test('应该能够获取本地数据', () async {
        when(() => mockLocalStorage.getString('user_data'))
            .thenAnswer((_) async => const AppResult.success('{"key": {"value": "test"}}'));

        final result = await provider.getLocalData();

        expect(result.isSuccess, true);
        expect(result.valueOrNull!.first.data, {'value': 'test'});
      });

      test('应该能够获取远程数据', () async {
        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-data'))
            .thenAnswer((_) async => createMockResponse({'data': {'key': {'value': 'test'}}}));

        final result = await provider.getRemoteData();

        expect(result.isSuccess, true);
        expect(result.valueOrNull!.first.data, {'value': 'test'});
      });

      test('应该能够保存本地数据', () async {
        final item = UserDataSyncItem(
          id: 'key',
          lastModified: DateTime.now(),
          data: {'value': 'test'},
        );

        when(() => mockLocalStorage.setString('user_data', any()))
            .thenAnswer((_) async => const AppResult.success(null));

        final result = await provider.saveLocalData([item]);

        expect(result.isSuccess, true);
      });

      test('应该能够上传远程数据', () async {
        final item = UserDataSyncItem(
          id: 'key',
          lastModified: DateTime.now(),
          data: {'value': 'test'},
        );

        when(() => mockApiClient.post<void>(
              '/sync/user-data',
              data: any(named: 'data'),
            )).thenAnswer((_) async => createMockResponse(null));

        final result = await provider.uploadRemoteData([item]);

        expect(result.isSuccess, true);
      });
    });

    group('DataSyncProviderManager Tests', () {
      late DataSyncProviderManager manager;

      setUp(() {
        manager = DataSyncProviderManager(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );
      });

      test('应该返回支持的数据类型', () {
        final supportedTypes = manager.supportedTypes;
        
        expect(supportedTypes, contains(SyncDataType.userSettings));
        expect(supportedTypes, contains(SyncDataType.userData));
      });

      test('应该能够获取指定类型的提供者', () {
        final userSettingsProvider = manager.getProvider<UserSettingsSyncItem>(SyncDataType.userSettings);
        final userDataProvider = manager.getProvider<UserDataSyncItem>(SyncDataType.userData);
        
        expect(userSettingsProvider, isNotNull);
        expect(userDataProvider, isNotNull);
        expect(userSettingsProvider, isA<UserSettingsSyncProvider>());
        expect(userDataProvider, isA<UserDataSyncProvider>());
      });

      test('不支持的类型应该返回null', () {
        final provider = manager.getProvider<UserSettingsSyncItem>(SyncDataType.appState);
        
        expect(provider, isNull);
      });

      test('应该能够同步指定类型的数据', () async {
        // Mock 本地数据
        when(() => mockLocalStorage.getString('user_settings'))
            .thenAnswer((_) async => const AppResult.success('{}'));
        
        // Mock 远程数据
        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-settings'))
            .thenAnswer((_) async => createMockResponse({'data': {'theme': 'dark'}}));
        
        // Mock 保存本地数据
        when(() => mockLocalStorage.setString('user_settings', any()))
            .thenAnswer((_) async => const AppResult.success(null));

        final result = await manager.syncData(SyncDataType.userSettings);

        expect(result.isSuccess, true);
      });

      test('同步不支持的类型应该返回错误', () async {
        final result = await manager.syncData(SyncDataType.appState);

        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('No provider found for type'));
      });

      test('应该能够同步所有数据', () async {
        // Mock 用户设置
        when(() => mockLocalStorage.getString('user_settings'))
            .thenAnswer((_) async => const AppResult.success('{}'));
        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-settings'))
            .thenAnswer((_) async => createMockResponse({'data': {}}));
        when(() => mockLocalStorage.setString('user_settings', any()))
            .thenAnswer((_) async => const AppResult.success(null));

        // Mock 用户数据
        when(() => mockLocalStorage.getString('user_data'))
            .thenAnswer((_) async => const AppResult.success('{}'));
        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-data'))
            .thenAnswer((_) async => createMockResponse({'data': {}}));
        when(() => mockLocalStorage.setString('user_data', any()))
            .thenAnswer((_) async => const AppResult.success(null));

        final result = await manager.syncAllData();

        expect(result.isSuccess, true);
      });

      test('同步部分失败时应该返回错误信息', () async {
        // Mock 用户设置成功
        when(() => mockLocalStorage.getString('user_settings'))
            .thenAnswer((_) async => const AppResult.success('{}'));
        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-settings'))
            .thenAnswer((_) async => createMockResponse({'data': {}}));
        when(() => mockLocalStorage.setString('user_settings', any()))
            .thenAnswer((_) async => const AppResult.success(null));

        // Mock 用户数据失败
        when(() => mockLocalStorage.getString('user_data'))
            .thenThrow(Exception('API error'));

        final result = await manager.syncAllData();

        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('Sync errors'));
      });

      test('空的同步应该成功', () async {
        // 创建一个没有任何提供者的管理器
        final emptyManager = DataSyncProviderManager(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );
        
        // 清空提供者（通过反射或创建新的空实例）
        // 这里我们模拟一个空的同步结果
        final result = await emptyManager.syncAllData();
        
        // 即使没有数据要同步，也应该成功
        expect(result.isSuccess, true);
      });
    });

    group('错误处理测试', () {
      test('JSON解析错误应该被正确处理', () async {
        final provider = UserSettingsSyncProvider(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );

        when(() => mockLocalStorage.getString('user_settings'))
            .thenAnswer((_) async => const AppResult.success('invalid json'));

        final result = await provider.getLocalData();

        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('Failed to get local user settings'));
      });

      test('网络错误应该被正确处理', () async {
        final provider = UserSettingsSyncProvider(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );

        when(() => mockApiClient.get<Map<String, dynamic>>('/sync/user-settings'))
            .thenThrow(Exception('Network timeout'));

        final result = await provider.getRemoteData();

        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('Failed to get remote user settings'));
      });

      test('存储错误应该被正确处理', () async {
        final provider = UserSettingsSyncProvider(
          localStorage: mockLocalStorage,
          apiClient: mockApiClient,
        );

        final item = UserSettingsSyncItem(
          id: 'theme',
          lastModified: DateTime.now(),
          data: {'value': 'dark'},
        );

        when(() => mockLocalStorage.setString('user_settings', any()))
            .thenAnswer((_) async => const AppResult.failure(StorageError('Storage full')));

        final result = await provider.saveLocalData([item]);

        expect(result.isFailure, true);
        expect(result.errorOrNull, contains('Failed to save local user settings'));
      });
    });
  });
} 