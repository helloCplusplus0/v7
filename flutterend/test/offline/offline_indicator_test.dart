// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/offline/offline_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('OfflineIndicator', () {
    group('OfflineStatus数据模型', () {
      test('应该创建默认的离线状态', () {
        const status = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.unknown,
          isOffline: false,
        );
        
        expect(status.operationMode, AppOperationMode.online);
        expect(status.serviceAvailability, ServiceAvailability.unknown);
        expect(status.isOffline, false);
        expect(status.reason, null);
        expect(status.offlineDuration, Duration.zero);
        expect(status.canRetry, true);
        expect(status.retryCount, 0);
        expect(status.maxRetryCount, 3);
      });

      test('应该正确计算shouldShowIndicator', () {
        // 在线状态不显示指示器
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        expect(onlineStatus.shouldShowIndicator, false);
        
        // 离线状态显示指示器
        const offlineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(offlineStatus.shouldShowIndicator, true);
        
        // 服务离线状态显示指示器
        const serviceOfflineStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: false,
        );
        expect(serviceOfflineStatus.shouldShowIndicator, true);
      });

      test('应该正确计算canSync', () {
        // 在线模式可以同步
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        expect(onlineStatus.canSync, true);
        
        // 混合模式且服务降级可以同步
        const hybridDegradedStatus = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.degraded,
          isOffline: false,
        );
        expect(hybridDegradedStatus.canSync, true);
        
        // 混合模式但服务不可用不能同步
        const hybridUnavailableStatus = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: false,
        );
        expect(hybridUnavailableStatus.canSync, false);
        
        // 完全离线不能同步
        const fullyOfflineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(fullyOfflineStatus.canSync, false);
      });

      test('应该正确计算shouldUseOfflineQueue', () {
        // 在线且可以同步不使用队列
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        expect(onlineStatus.shouldUseOfflineQueue, false);
        
        // 离线使用队列
        const offlineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(offlineStatus.shouldUseOfflineQueue, true);
        
        // 不能同步使用队列
        const noSyncStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: false,
        );
        expect(noSyncStatus.shouldUseOfflineQueue, true);
      });
    });

    group('用户友好消息', () {
      test('应该返回正确的userFriendlyMessage', () {
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        expect(onlineStatus.userFriendlyMessage, '在线');
        
        const serviceOfflineStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: false,
        );
        expect(serviceOfflineStatus.userFriendlyMessage, '服务连接异常');
        
        const fullyOfflineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(fullyOfflineStatus.userFriendlyMessage, '离线模式');
        
        const hybridStatus = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.degraded,
          isOffline: false,
        );
        expect(hybridStatus.userFriendlyMessage, '网络不稳定');
      });

      test('应该支持自定义用户消息', () {
        const customStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          userMessage: '自定义离线消息',
        );
        expect(customStatus.userFriendlyMessage, '自定义离线消息');
      });
    });

    group('详细消息', () {
      test('应该生成基本的详细消息', () {
        const status = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        expect(status.detailedMessage, '离线模式');
      });

      test('应该包含离线原因', () {
        const statusWithReason = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          reason: OfflineReason.noNetwork,
        );
        expect(statusWithReason.detailedMessage, '离线模式 - 无网络连接');
      });

      test('应该包含离线时长', () {
        const statusWithDuration = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration(minutes: 5),
        );
        expect(statusWithDuration.detailedMessage.contains('5分钟'), true);
      });

      test('应该包含原因和时长', () {
        const fullStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          reason: OfflineReason.serviceUnavailable,
          offlineDuration: Duration(hours: 1),
        );
        final message = fullStatus.detailedMessage;
        expect(message.contains('离线模式'), true);
        expect(message.contains('服务器无法连接'), true);
        expect(message.contains('1小时'), true);
      });
    });

    group('时长格式化', () {
      test('应该正确格式化不同的时长', () {
        // 分钟
        const minuteStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration(minutes: 30),
        );
        expect(minuteStatus.detailedMessage.contains('30分钟'), true);
        
        // 小时
        const hourStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration(hours: 2),
        );
        expect(hourStatus.detailedMessage.contains('2小时'), true);
        
        // 天
        const dayStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration(days: 1),
        );
        expect(dayStatus.detailedMessage.contains('1天'), true);
      });

      test('应该处理零时长', () {
        const zeroStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
          offlineDuration: Duration.zero,
        );
        expect(zeroStatus.detailedMessage, '离线模式');
      });
    });

    group('copyWith方法', () {
      test('应该正确复制和更新属性', () {
        const originalStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
          retryCount: 1,
        );
        
        final updatedStatus = originalStatus.copyWith(
          operationMode: AppOperationMode.fullyOffline,
          isOffline: true,
          retryCount: 2,
        );
        
        expect(updatedStatus.operationMode, AppOperationMode.fullyOffline);
        expect(updatedStatus.serviceAvailability, ServiceAvailability.available); // 未更改
        expect(updatedStatus.isOffline, true);
        expect(updatedStatus.retryCount, 2);
      });

      test('应该处理null参数', () {
        const originalStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        
        final copiedStatus = originalStatus.copyWith();
        
        expect(copiedStatus.operationMode, originalStatus.operationMode);
        expect(copiedStatus.serviceAvailability, originalStatus.serviceAvailability);
        expect(copiedStatus.isOffline, originalStatus.isOffline);
      });
    });

    group('相等性和hashCode', () {
      test('应该正确比较相等的对象', () {
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

      test('应该正确比较不同的对象', () {
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
      });
    });

    group('枚举完整性', () {
      test('所有AppOperationMode枚举值都应该有对应的消息', () {
        for (final mode in AppOperationMode.values) {
          final status = OfflineStatus(
            operationMode: mode,
            serviceAvailability: ServiceAvailability.available,
            isOffline: mode != AppOperationMode.online,
          );
          
          expect(status.userFriendlyMessage.isNotEmpty, true);
        }
      });

      test('所有OfflineReason枚举值都应该有对应的描述', () {
        for (final reason in OfflineReason.values) {
          final status = OfflineStatus(
            operationMode: AppOperationMode.fullyOffline,
            serviceAvailability: ServiceAvailability.unavailable,
            isOffline: true,
            reason: reason,
          );
          
          expect(status.detailedMessage.isNotEmpty, true);
          expect(status.detailedMessage.contains('-'), true); // 应该包含原因描述
        }
      });
    });

    group('重试机制', () {
      test('应该正确设置重试参数', () {
        const retryStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: false,
          canRetry: true,
          retryCount: 2,
          maxRetryCount: 5,
        );
        
        expect(retryStatus.canRetry, true);
        expect(retryStatus.retryCount, 2);
        expect(retryStatus.maxRetryCount, 5);
      });

      test('应该正确判断重试限制', () {
        const maxRetryStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: false,
          canRetry: false,
          retryCount: 3,
          maxRetryCount: 3,
        );
        
        expect(maxRetryStatus.canRetry, false);
        expect(maxRetryStatus.retryCount, maxRetryStatus.maxRetryCount);
      });
    });

    group('技术详情', () {
      test('应该支持技术详情信息', () {
        const technicalStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: false,
          technicalDetails: 'HTTP 500 - Internal Server Error',
        );
        
        expect(technicalStatus.technicalDetails, 'HTTP 500 - Internal Server Error');
      });
    });
  });
} 