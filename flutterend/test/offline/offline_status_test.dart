// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/offline/offline_indicator.dart';

void main() {
  group('OfflineStatus', () {
    group('构造函数和基本属性', () {
      test('应该正确创建默认OfflineStatus实例', () {
        const status = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );

        expect(status.operationMode, AppOperationMode.online);
        expect(status.serviceAvailability, ServiceAvailability.available);
        expect(status.isOffline, false);
        expect(status.reason, null);
        expect(status.lastOnlineTime, null);
        expect(status.lastServiceCheckTime, null);
        expect(status.serviceCheckInterval, const Duration(minutes: 2));
        expect(status.serviceResponseTime, null);
        expect(status.offlineDuration, Duration.zero);
        expect(status.canRetry, true);
        expect(status.retryCount, 0);
        expect(status.maxRetryCount, 3);
        expect(status.nextRetryTime, null);
        expect(status.userMessage, null);
        expect(status.technicalDetails, null);
      });

      test('应该正确创建带所有参数的OfflineStatus实例', () {
        final now = DateTime.now();
        final status = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          reason: OfflineReason.noNetwork,
          lastOnlineTime: now,
          lastServiceCheckTime: now,
          serviceCheckInterval: const Duration(minutes: 5),
          serviceResponseTime: const Duration(milliseconds: 200),
          offlineDuration: const Duration(minutes: 10),
          canRetry: false,
          retryCount: 2,
          maxRetryCount: 5,
          nextRetryTime: now.add(const Duration(minutes: 1)),
          userMessage: 'Custom message',
          technicalDetails: 'Technical details',
        );

        expect(status.operationMode, AppOperationMode.fullyOffline);
        expect(status.serviceAvailability, ServiceAvailability.unavailable);
        expect(status.isOffline, true);
        expect(status.reason, OfflineReason.noNetwork);
        expect(status.lastOnlineTime, now);
        expect(status.lastServiceCheckTime, now);
        expect(status.serviceCheckInterval, const Duration(minutes: 5));
        expect(status.serviceResponseTime, const Duration(milliseconds: 200));
        expect(status.offlineDuration, const Duration(minutes: 10));
        expect(status.canRetry, false);
        expect(status.retryCount, 2);
        expect(status.maxRetryCount, 5);
        expect(status.nextRetryTime, now.add(const Duration(minutes: 1)));
        expect(status.userMessage, 'Custom message');
        expect(status.technicalDetails, 'Technical details');
      });
    });

    group('计算属性', () {
      test('shouldShowIndicator应该正确计算', () {
        // 离线状态应该显示指示器
        const offlineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(offlineStatus.shouldShowIndicator, true);

        // 服务离线状态应该显示指示器
        const serviceOfflineStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(serviceOfflineStatus.shouldShowIndicator, true);

        // 在线状态不应该显示指示器
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        expect(onlineStatus.shouldShowIndicator, false);
      });

      test('canSync应该正确计算', () {
        // 在线模式可以同步
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        expect(onlineStatus.canSync, true);

        // 混合模式且服务降级可以同步
        const hybridStatus = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.degraded,
          isOffline: false,
        );
        expect(hybridStatus.canSync, true);

        // 完全离线不能同步
        const offlineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(offlineStatus.canSync, false);

        // 服务离线不能同步
        const serviceOfflineStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(serviceOfflineStatus.canSync, false);
      });

      test('shouldUseOfflineQueue应该正确计算', () {
        // 离线状态应该使用离线队列
        const offlineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(offlineStatus.shouldUseOfflineQueue, true);

        // 不能同步时应该使用离线队列
        const serviceOfflineStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(serviceOfflineStatus.shouldUseOfflineQueue, true);

        // 在线且可以同步时不应该使用离线队列
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        expect(onlineStatus.shouldUseOfflineQueue, false);
      });
    });

    group('消息生成', () {
      test('userFriendlyMessage应该返回正确的消息', () {
        // 自定义消息
        const customStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
          userMessage: 'Custom message',
        );
        expect(customStatus.userFriendlyMessage, 'Custom message');

        // 在线模式
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        expect(onlineStatus.userFriendlyMessage, '在线');

        // 服务离线模式
        const serviceOfflineStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(serviceOfflineStatus.userFriendlyMessage, '服务连接异常');

        // 完全离线模式
        const fullyOfflineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(fullyOfflineStatus.userFriendlyMessage, '离线模式');

        // 混合模式
        const hybridStatus = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.degraded,
          isOffline: false,
        );
        expect(hybridStatus.userFriendlyMessage, '网络不稳定');
      });

      test('detailedMessage应该返回详细消息', () {
        // 基本消息
        const basicStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        expect(basicStatus.detailedMessage, '在线');

        // 带原因的消息
        const reasonStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          reason: OfflineReason.noNetwork,
        );
        expect(reasonStatus.detailedMessage, '离线模式 - 无网络连接');

        // 带时长的消息
        const durationStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          reason: OfflineReason.noNetwork,
          offlineDuration: const Duration(minutes: 5),
        );
        expect(durationStatus.detailedMessage, '离线模式 - 无网络连接 (5分钟)');

        // 测试不同时长格式
        const dayStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration(days: 2),
        );
        expect(dayStatus.detailedMessage.contains('2天'), true);

        const hourStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration(hours: 3),
        );
        expect(hourStatus.detailedMessage.contains('3小时'), true);

        const zeroStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration.zero,
        );
        expect(zeroStatus.detailedMessage.contains('刚刚'), false); // Duration.zero不会显示时长
      });
    });

    group('copyWith方法', () {
      test('应该正确复制和更新属性', () {
        const originalStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );

        final updatedStatus = originalStatus.copyWith(
          operationMode: AppOperationMode.fullyOffline,
          isOffline: true,
          reason: OfflineReason.noNetwork,
        );

        expect(updatedStatus.operationMode, AppOperationMode.fullyOffline);
        expect(updatedStatus.serviceAvailability, ServiceAvailability.available); // 未更改
        expect(updatedStatus.isOffline, true);
        expect(updatedStatus.reason, OfflineReason.noNetwork);
      });

      test('应该保持未指定的属性不变', () {
        final now = DateTime.now();
        final originalStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
          lastOnlineTime: now,
          retryCount: 1,
        );

        final updatedStatus = originalStatus.copyWith(
          isOffline: true,
        );

        expect(updatedStatus.operationMode, AppOperationMode.online);
        expect(updatedStatus.serviceAvailability, ServiceAvailability.available);
        expect(updatedStatus.isOffline, true);
        expect(updatedStatus.lastOnlineTime, now);
        expect(updatedStatus.retryCount, 1);
      });
    });

    group('相等性和hashCode', () {
      test('相同属性的实例应该相等', () {
        const status1 = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
          reason: OfflineReason.noNetwork,
        );

        const status2 = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
          reason: OfflineReason.noNetwork,
        );

        expect(status1, status2);
        expect(status1.hashCode, status2.hashCode);
      });

      test('不同属性的实例应该不相等', () {
        const status1 = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );

        const status2 = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );

        expect(status1, isNot(status2));
        expect(status1.hashCode, isNot(status2.hashCode));
      });
    });

    group('枚举完整性', () {
      test('AppOperationMode应该包含所有预期值', () {
        expect(AppOperationMode.values.length, 4);
        expect(AppOperationMode.values, contains(AppOperationMode.online));
        expect(AppOperationMode.values, contains(AppOperationMode.serviceOffline));
        expect(AppOperationMode.values, contains(AppOperationMode.fullyOffline));
        expect(AppOperationMode.values, contains(AppOperationMode.hybrid));
      });

      test('ServiceAvailability应该包含所有预期值', () {
        expect(ServiceAvailability.values.length, 6);
        expect(ServiceAvailability.values, contains(ServiceAvailability.available));
        expect(ServiceAvailability.values, contains(ServiceAvailability.degraded));
        expect(ServiceAvailability.values, contains(ServiceAvailability.unavailable));
        expect(ServiceAvailability.values, contains(ServiceAvailability.maintenance));
        expect(ServiceAvailability.values, contains(ServiceAvailability.checking));
        expect(ServiceAvailability.values, contains(ServiceAvailability.unknown));
      });

      test('OfflineReason应该包含所有预期值', () {
        expect(OfflineReason.values.length, 7);
        expect(OfflineReason.values, contains(OfflineReason.noNetwork));
        expect(OfflineReason.values, contains(OfflineReason.unstableNetwork));
        expect(OfflineReason.values, contains(OfflineReason.serviceUnavailable));
        expect(OfflineReason.values, contains(OfflineReason.serviceTimeout));
        expect(OfflineReason.values, contains(OfflineReason.serviceError));
        expect(OfflineReason.values, contains(OfflineReason.userChoice));
        expect(OfflineReason.values, contains(OfflineReason.maintenance));
      });
    });
  });
}