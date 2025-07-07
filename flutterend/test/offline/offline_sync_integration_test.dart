// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/offline/offline_indicator.dart';
import 'package:v7_flutter_app/shared/connectivity/network_monitor.dart';
import 'package:v7_flutter_app/shared/sync/sync_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('离线同步集成', () {
    group('同步策略适配', () {
      test('应该根据离线状态选择合适的同步策略', () {
        // 测试在线状态 - 服务器优先
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        
        final onlineStrategy = _adaptSyncStrategy(onlineStatus, NetworkQuality.excellent);
        expect(onlineStrategy, SyncStrategy.serverWins);
        
        // 测试混合模式 - 最后修改时间优先
        const hybridStatus = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.degraded,
          isOffline: false,
        );
        
        final hybridStrategy = _adaptSyncStrategy(hybridStatus, NetworkQuality.fair);
        expect(hybridStrategy, SyncStrategy.lastModified);
        
        // 测试离线状态 - 客户端优先
        const offlineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        
        final offlineStrategy = _adaptSyncStrategy(offlineStatus, NetworkQuality.none);
        expect(offlineStrategy, SyncStrategy.clientWins);
      });
    });

    group('同步间隔适配', () {
      test('应该根据网络质量调整同步间隔', () {
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        
        // 优秀网络质量 - 短间隔
        final excellentInterval = _adaptSyncInterval(onlineStatus, NetworkQuality.excellent);
        expect(excellentInterval, const Duration(minutes: 5));
        
        // 良好网络质量 - 中等间隔
        final goodInterval = _adaptSyncInterval(onlineStatus, NetworkQuality.good);
        expect(goodInterval, const Duration(minutes: 10));
        
        // 差网络质量 - 长间隔
        final poorInterval = _adaptSyncInterval(onlineStatus, NetworkQuality.poor);
        expect(poorInterval, const Duration(minutes: 30));
        
        // 离线状态 - 最长间隔
        const offlineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        
        final offlineInterval = _adaptSyncInterval(offlineStatus, NetworkQuality.none);
        expect(offlineInterval, const Duration(hours: 1));
      });
    });

    group('批量大小适配', () {
      test('应该根据网络质量调整批量大小', () {
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        
        // 优秀网络质量 - 大批量
        final excellentBatch = _adaptBatchSize(onlineStatus, NetworkQuality.excellent);
        expect(excellentBatch, 100);
        
        // 良好网络质量 - 中等批量
        final goodBatch = _adaptBatchSize(onlineStatus, NetworkQuality.good);
        expect(goodBatch, 50);
        
        // 差网络质量 - 小批量
        final poorBatch = _adaptBatchSize(onlineStatus, NetworkQuality.poor);
        expect(poorBatch, 10);
        
        // 离线状态 - 最小批量
        const offlineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        
        final offlineBatch = _adaptBatchSize(offlineStatus, NetworkQuality.none);
        expect(offlineBatch, 10);
      });
    });

    group('智能同步配置', () {
      test('应该生成完整的同步配置', () {
        const status = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        
        final config = _generateSyncConfig(status, NetworkQuality.good);
        
        expect(config.strategy, SyncStrategy.serverWins);
        expect(config.syncInterval, const Duration(minutes: 10));
        expect(config.batchSize, 50);
        expect(config.enableAutoSync, true);
        expect(config.enableOfflineQueue, false);
        expect(config.retryAttempts, 3);
      });

      test('应该为混合模式调整配置', () {
        const status = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.degraded,
          isOffline: false,
        );
        
        final config = _generateSyncConfig(status, NetworkQuality.fair);
        
        expect(config.strategy, SyncStrategy.lastModified);
        expect(config.retryAttempts, 5);
        expect(config.retryDelay, const Duration(seconds: 10));
      });

      test('应该为离线状态调整配置', () {
        const status = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        
        final config = _generateSyncConfig(status, NetworkQuality.none);
        
        expect(config.strategy, SyncStrategy.clientWins);
        expect(config.enableAutoSync, false);
        expect(config.enableOfflineQueue, true);
      });
    });

    group('同步决策', () {
      test('应该正确判断是否应该同步', () {
        // 在线状态 - 应该同步
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        
        expect(_shouldSync(onlineStatus, NetworkQuality.good), true);
        
        // 混合模式良好网络 - 应该同步
        const hybridStatus = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.degraded,
          isOffline: false,
        );
        
        expect(_shouldSync(hybridStatus, NetworkQuality.good), true);
        
        // 混合模式差网络 - 不应该同步
        expect(_shouldSync(hybridStatus, NetworkQuality.poor), false);
        
        // 离线状态 - 不应该同步
        const offlineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        
        expect(_shouldSync(offlineStatus, NetworkQuality.none), false);
      });
    });

    group('离线队列状态', () {
      test('应该根据模式返回正确的状态消息', () {
        // 在线模式
        const onlineStatus = OfflineStatus(
          operationMode: AppOperationMode.online,
          serviceAvailability: ServiceAvailability.available,
          isOffline: false,
        );
        
        final onlineMessage = _getQueueStatusMessage(onlineStatus);
        expect(onlineMessage, '实时同步');
        
        // 混合模式
        const hybridStatus = OfflineStatus(
          operationMode: AppOperationMode.hybrid,
          serviceAvailability: ServiceAvailability.degraded,
          isOffline: false,
        );
        
        final hybridMessage = _getQueueStatusMessage(hybridStatus);
        expect(hybridMessage, '谨慎同步模式');
        
        // 服务离线模式
        const serviceOfflineStatus = OfflineStatus(
          operationMode: AppOperationMode.serviceOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        
        final serviceOfflineMessage = _getQueueStatusMessage(serviceOfflineStatus);
        expect(serviceOfflineMessage, '离线队列模式');
        
        // 完全离线模式
        const fullyOfflineStatus = OfflineStatus(
          operationMode: AppOperationMode.fullyOffline,
          serviceAvailability: ServiceAvailability.unavailable,
          isOffline: true,
        );
        
        final fullyOfflineMessage = _getQueueStatusMessage(fullyOfflineStatus);
        expect(fullyOfflineMessage, '仅本地模式');
      });
    });
  });
}

// 辅助函数 - 模拟同步策略适配逻辑
SyncStrategy _adaptSyncStrategy(OfflineStatus status, NetworkQuality quality) {
  if (!status.canSync) {
    return SyncStrategy.clientWins;
  }
  
  if (status.operationMode == AppOperationMode.hybrid) {
    return SyncStrategy.lastModified;
  }
  
  return SyncStrategy.serverWins;
}

// 辅助函数 - 模拟同步间隔适配逻辑
Duration _adaptSyncInterval(OfflineStatus status, NetworkQuality quality) {
  if (!status.canSync) {
    return const Duration(hours: 1);
  }
  
  return switch (quality) {
    NetworkQuality.excellent => const Duration(minutes: 5),
    NetworkQuality.good => const Duration(minutes: 10),
    NetworkQuality.fair => const Duration(minutes: 15),
    NetworkQuality.poor => const Duration(minutes: 30),
    NetworkQuality.none => const Duration(hours: 1),
  };
}

// 辅助函数 - 模拟批量大小适配逻辑
int _adaptBatchSize(OfflineStatus status, NetworkQuality quality) {
  if (!status.canSync) {
    return 10;
  }
  
  return switch (quality) {
    NetworkQuality.excellent => 100,
    NetworkQuality.good => 50,
    NetworkQuality.fair => 25,
    NetworkQuality.poor => 10,
    NetworkQuality.none => 5,
  };
}

// 辅助函数 - 模拟同步配置生成逻辑
SyncConfig _generateSyncConfig(OfflineStatus status, NetworkQuality quality) {
  final strategy = _adaptSyncStrategy(status, quality);
  final interval = _adaptSyncInterval(status, quality);
  final batchSize = _adaptBatchSize(status, quality);
  
  return SyncConfig(
    strategy: strategy,
    syncInterval: interval,
    batchSize: batchSize,
    enableAutoSync: status.canSync,
    enableOfflineQueue: status.shouldUseOfflineQueue,
    retryAttempts: status.operationMode == AppOperationMode.hybrid ? 5 : 3,
    retryDelay: status.operationMode == AppOperationMode.hybrid 
        ? const Duration(seconds: 10) 
        : const Duration(seconds: 5),
  );
}

// 辅助函数 - 模拟同步决策逻辑
bool _shouldSync(OfflineStatus status, NetworkQuality quality) {
  if (!status.canSync) return false;
  
  if (quality == NetworkQuality.poor && 
      status.operationMode == AppOperationMode.hybrid) {
    return false;
  }
  
  return true;
}

// 辅助函数 - 模拟队列状态消息逻辑
String _getQueueStatusMessage(OfflineStatus status) {
  return switch (status.operationMode) {
    AppOperationMode.online => '实时同步',
    AppOperationMode.hybrid => '谨慎同步模式',
    AppOperationMode.serviceOffline => '离线队列模式',
    AppOperationMode.fullyOffline => '仅本地模式',
  };
}