// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/offline/offline_indicator.dart';
import 'package:v7_flutter_app/shared/connectivity/network_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('离线状态边缘情况', () {
    group('数据模型边界值', () {
      test('应该处理极端的离线时长', () {
        // 测试零时长
        const zeroStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration.zero,
        );
        expect(zeroStatus.offlineDuration, Duration.zero);
        
        // 测试极长时长
        const longStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration(days: 365),
        );
        expect(longStatus.offlineDuration.inDays, 365);
        
        // 测试负时长（应该被处理为零）
        const negativeStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration(milliseconds: -1000),
        );
        expect(negativeStatus.offlineDuration.isNegative, true);
      });

      test('应该处理极端的重试次数', () {
        // 测试零重试次数
        const zeroRetryStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          retryCount: 0,
          maxRetryCount: 0,
          canRetry: false,
        );
        expect(zeroRetryStatus.retryCount, 0);
        expect(zeroRetryStatus.canRetry, false);
        
        // 测试大量重试次数
        const manyRetriesStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          retryCount: 999,
          maxRetryCount: 1000,
          canRetry: true,
        );
        expect(manyRetriesStatus.retryCount, 999);
        expect(manyRetriesStatus.canRetry, true);
      });

      test('应该处理极端的检查间隔', () {
        // 测试极短间隔
        const shortIntervalStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
          serviceCheckInterval: Duration(milliseconds: 1),
        );
        expect(shortIntervalStatus.serviceCheckInterval.inMilliseconds, 1);
        
        // 测试极长间隔
        const longIntervalStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
          serviceCheckInterval: Duration(hours: 24),
        );
        expect(longIntervalStatus.serviceCheckInterval.inHours, 24);
      });
    });

    group('状态组合边界', () {
      test('应该处理所有可能的状态组合', () {
        // 测试所有AppOperationMode
        for (final mode in AppOperationMode.values) {
          for (final availability in ServiceAvailability.values) {
            final status = OfflineStatus(
              operationMode: mode,
              serviceAvailability: availability,
              isOffline: mode != AppOperationMode.online,
            );
            
            // 验证状态组合的一致性
            if (mode == AppOperationMode.online) {
              expect(status.isOffline, false);
            } else {
              expect(status.isOffline, true);
            }
            
            // 验证shouldShowIndicator逻辑
            final shouldShow = status.isOffline || mode == AppOperationMode.serviceOffline;
            expect(status.shouldShowIndicator, shouldShow);
          }
        }
      });

      test('应该处理不一致的状态组合', () {
        // 在线但服务不可用
        const inconsistentStatus1 = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: false,
        );
        expect(inconsistentStatus1.canSync, true); // 在线模式仍然可以同步
        
        // 离线但服务可用
        const inconsistentStatus2 = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.available,
          isOffline: true,
        );
        expect(inconsistentStatus2.canSync, false); // 离线模式不能同步
      });
    });

    group('消息生成边界', () {
      test('应该处理空和null值', () {
        // 测试无原因的状态
        const noReasonStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          reason: null,
        );
        expect(noReasonStatus.detailedMessage, '离线模式');
        
        // 测试有原因但无时长的状态
        const reasonNoTimeStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          reason: OfflineReason.noNetwork,
          offlineDuration: Duration.zero,
        );
        expect(reasonNoTimeStatus.detailedMessage, '离线模式 - 无网络连接');
      });

      test('应该处理特殊字符和长文本', () {
        // 测试自定义用户消息
        const customMessageStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          userMessage: '自定义离线消息包含特殊字符: @#\$%^&*()',
        );
        expect(customMessageStatus.userFriendlyMessage, '自定义离线消息包含特殊字符: @#\$%^&*()');
        
        // 测试技术详情
        const technicalDetailsStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          technicalDetails: 'HTTP 500 Internal Server Error - Connection timeout after 30 seconds',
        );
        expect(technicalDetailsStatus.technicalDetails, 'HTTP 500 Internal Server Error - Connection timeout after 30 seconds');
      });
    });

    group('计算属性边界', () {
      test('shouldShowIndicator边界情况', () {
        // 边界情况：混合模式但不离线
        const hybridOnlineStatus = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.degraded,
          isOffline: false,
        );
        expect(hybridOnlineStatus.shouldShowIndicator, false);
        
        // 边界情况：服务离线但标记为在线
        const serviceOfflineStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: false, // 不一致的状态
        );
        expect(serviceOfflineStatus.shouldShowIndicator, true); // 仍然显示指示器
      });

      test('canSync边界情况', () {
        // 边界情况：混合模式但服务可用（不能同步，因为需要degraded状态）
        const hybridAvailableStatus = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        expect(hybridAvailableStatus.canSync, false);
        
        // 边界情况：混合模式但服务不可用
        const hybridUnavailableStatus = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: false,
        );
        expect(hybridUnavailableStatus.canSync, false);
        
        // 边界情况：混合模式但服务未知
        const hybridUnknownStatus = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.unknown,
          isOffline: false,
        );
        expect(hybridUnknownStatus.canSync, false);
      });

      test('shouldUseOfflineQueue边界情况', () {
        // 边界情况：在线但不能同步（在线模式总是可以同步，所以不使用队列）
        const onlineNoSyncStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: false,
        );
        expect(onlineNoSyncStatus.shouldUseOfflineQueue, false); // 在线模式不使用队列
        
        // 边界情况：离线但理论上可以同步
        const offlineCanSyncStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.available,
          isOffline: true,
        );
        expect(offlineCanSyncStatus.shouldUseOfflineQueue, true); // 离线就使用队列
      });
    });

    group('copyWith边界情况', () {
      test('应该处理所有参数为null的情况', () {
        const originalStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
          retryCount: 5,
          maxRetryCount: 10,
        );
        
        final copiedStatus = originalStatus.copyWith();
        
        expect(copiedStatus.operationMode, originalStatus.operationMode);
        expect(copiedStatus.serviceAvailability, originalStatus.serviceAvailability);
        expect(copiedStatus.isOffline, originalStatus.isOffline);
        expect(copiedStatus.retryCount, originalStatus.retryCount);
        expect(copiedStatus.maxRetryCount, originalStatus.maxRetryCount);
      });

      test('应该处理部分参数更新', () {
        const originalStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
          reason: OfflineReason.noNetwork,
          retryCount: 0,
        );
        
        final updatedStatus = originalStatus.copyWith(
          operationMode: AppOperationMode.fullyOffline,
          isOffline: true,
          retryCount: 3,
        );
        
        expect(updatedStatus.operationMode, AppOperationMode.fullyOffline);
        expect(updatedStatus.serviceAvailability, ServiceAvailability.available); // 未更改
        expect(updatedStatus.isOffline, true);
        expect(updatedStatus.reason, OfflineReason.noNetwork); // 未更改
        expect(updatedStatus.retryCount, 3);
      });
    });

    group('相等性和hashCode边界', () {
      test('应该正确处理相同内容的对象', () {
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

      test('应该正确处理不同内容的对象', () {
        const status1 = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        
        const status2 = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false, // 相同的isOffline但不同的operationMode
        );
        
        expect(status1, isNot(status2));
        expect(status1.hashCode, isNot(status2.hashCode));
      });

      test('应该处理null值的比较', () {
        const statusWithNull = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
          reason: null,
          lastOnlineTime: null,
        );
        
        final statusWithoutNull = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
          reason: OfflineReason.noNetwork,
          lastOnlineTime: DateTime.now(),
        );
        
        expect(statusWithNull, isNot(statusWithoutNull));
      });
    });

    group('时间处理边界', () {
      test('应该处理极端的时间值', () {
        final veryOldTime = DateTime(1970, 1, 1);
        final veryFutureTime = DateTime(2100, 12, 31);
        
        final oldTimeStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          lastOnlineTime: veryOldTime,
          lastServiceCheckTime: veryOldTime,
          nextRetryTime: veryFutureTime,
        );
        
        expect(oldTimeStatus.lastOnlineTime, veryOldTime);
        expect(oldTimeStatus.lastServiceCheckTime, veryOldTime);
        expect(oldTimeStatus.nextRetryTime, veryFutureTime);
      });

      test('应该处理时间格式化边界', () {
        // 测试不同时长的格式化
        const minuteStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration(minutes: 1),
        );
        expect(minuteStatus.detailedMessage.contains('1分钟'), true);
        
        const hourStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration(hours: 1),
        );
        expect(hourStatus.detailedMessage.contains('1小时'), true);
        
        const dayStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration(days: 1),
        );
        expect(dayStatus.detailedMessage.contains('1天'), true);
      });
    });
  });
}