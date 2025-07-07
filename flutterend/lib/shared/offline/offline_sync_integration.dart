// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_indicator.dart';
import '../sync/sync_manager.dart';
import '../connectivity/connectivity_providers.dart';
import '../connectivity/network_monitor.dart';

/// 离线状态与同步管理器集成Provider
final offlineSyncIntegrationProvider = Provider<void>((ref) {
  // 监听离线状态变化
  ref.listen(offlineIndicatorProvider, (previous, next) {
    if (previous?.canSync != next.canSync) {
      _handleSyncAvailabilityChange(ref, next.canSync);
    }
    
    if (previous?.operationMode != next.operationMode) {
      _handleOperationModeChange(ref, next.operationMode);
    }
  });

  return;
});

/// 处理同步可用性变化
void _handleSyncAvailabilityChange(Ref ref, bool canSync) {
  // 这里可以添加同步管理器的状态更新逻辑
  // 例如：暂停或恢复自动同步
  
  if (canSync) {
    // 网络恢复，可以开始同步
    // 触发待同步数据的处理
    _triggerPendingSync(ref);
  } else {
    // 网络不可用，暂停同步
    _pauseSync(ref);
  }
}

/// 处理操作模式变化
void _handleOperationModeChange(Ref ref, AppOperationMode mode) {
  switch (mode) {
    case AppOperationMode.online:
      // 在线模式：启用实时同步
      _enableRealTimeSync(ref);
      break;
    case AppOperationMode.serviceOffline:
      // 服务离线：启用离线队列
      _enableOfflineQueue(ref);
      break;
    case AppOperationMode.fullyOffline:
      // 完全离线：仅本地操作
      _enableLocalOnlyMode(ref);
      break;
    case AppOperationMode.hybrid:
      // 混合模式：谨慎同步
      _enableCautiousSync(ref);
      break;
  }
}

/// 触发待同步数据处理
void _triggerPendingSync(Ref ref) {
  // 实现待同步数据的处理逻辑
  // 这里可以调用同步管理器的相关方法
}

/// 暂停同步
void _pauseSync(Ref ref) {
  // 实现暂停同步的逻辑
}

/// 启用实时同步
void _enableRealTimeSync(Ref ref) {
  // 实现实时同步的逻辑
}

/// 启用离线队列
void _enableOfflineQueue(Ref ref) {
  // 实现离线队列的逻辑
}

/// 启用仅本地模式
void _enableLocalOnlyMode(Ref ref) {
  // 实现仅本地模式的逻辑
}

/// 启用谨慎同步模式
void _enableCautiousSync(Ref ref) {
  // 实现谨慎同步的逻辑
}

/// 同步策略Provider - 根据离线状态动态调整同步策略
final adaptiveSyncStrategyProvider = Provider<SyncStrategy>((ref) {
  final offlineStatus = ref.watch(offlineIndicatorProvider);
  final networkQuality = ref.watch(networkQualityProvider);
  
  // 根据离线状态和网络质量动态调整同步策略
  if (!offlineStatus.canSync) {
    // 无法同步时，优先保存本地数据
    return SyncStrategy.clientWins;
  }
  
  if (offlineStatus.operationMode == AppOperationMode.hybrid) {
    // 网络不稳定时，使用最后修改时间策略
    return SyncStrategy.lastModified;
  }
  
  // 网络良好时，使用服务器优先策略
  return SyncStrategy.serverWins;
});

/// 同步间隔Provider - 根据网络状态调整同步间隔
final adaptiveSyncIntervalProvider = Provider<Duration>((ref) {
  final offlineStatus = ref.watch(offlineIndicatorProvider);
  final networkQuality = ref.watch(networkQualityProvider);
  
  if (!offlineStatus.canSync) {
    // 无法同步时，设置较长间隔
    return const Duration(hours: 1);
  }
  
  return switch (networkQuality) {
    NetworkQuality.excellent => const Duration(minutes: 5),
    NetworkQuality.good => const Duration(minutes: 10),
    NetworkQuality.fair => const Duration(minutes: 15),
    NetworkQuality.poor => const Duration(minutes: 30),
    NetworkQuality.none => const Duration(hours: 1),
  };
});

/// 批量大小Provider - 根据网络质量调整批量大小
final adaptiveBatchSizeProvider = Provider<int>((ref) {
  final networkQuality = ref.watch(networkQualityProvider);
  final offlineStatus = ref.watch(offlineIndicatorProvider);
  
  if (!offlineStatus.canSync) {
    return 10; // 离线时使用小批量
  }
  
  return switch (networkQuality) {
    NetworkQuality.excellent => 100,
    NetworkQuality.good => 50,
    NetworkQuality.fair => 25,
    NetworkQuality.poor => 10,
    NetworkQuality.none => 5,
  };
});

/// 智能同步配置Provider - 综合考虑各种因素的同步配置
final smartSyncConfigProvider = Provider<SyncConfig>((ref) {
  final strategy = ref.watch(adaptiveSyncStrategyProvider);
  final interval = ref.watch(adaptiveSyncIntervalProvider);
  final batchSize = ref.watch(adaptiveBatchSizeProvider);
  final offlineStatus = ref.watch(offlineIndicatorProvider);
  
  return SyncConfig(
    strategy: strategy,
    syncInterval: interval,
    batchSize: batchSize,
    enableAutoSync: offlineStatus.canSync,
    enableOfflineQueue: offlineStatus.shouldUseOfflineQueue,
    retryAttempts: offlineStatus.operationMode == AppOperationMode.hybrid ? 5 : 3,
    retryDelay: offlineStatus.operationMode == AppOperationMode.hybrid 
        ? const Duration(seconds: 10) 
        : const Duration(seconds: 5),
  );
});

/// 数据同步决策Provider - 决定是否应该执行同步
final shouldSyncProvider = Provider<bool>((ref) {
  final offlineStatus = ref.watch(offlineIndicatorProvider);
  final networkQuality = ref.watch(networkQualityProvider);
  
  // 基本条件：必须能够同步
  if (!offlineStatus.canSync) return false;
  
  // 网络质量太差时不同步
  if (networkQuality == NetworkQuality.poor && 
      offlineStatus.operationMode == AppOperationMode.hybrid) {
    return false;
  }
  
  // 其他情况可以同步
  return true;
});

/// 离线操作队列状态Provider
final offlineQueueStatusProvider = Provider<String>((ref) {
  final offlineStatus = ref.watch(offlineIndicatorProvider);
  
  if (!offlineStatus.shouldUseOfflineQueue) {
    return '在线模式';
  }
  
  return switch (offlineStatus.operationMode) {
    AppOperationMode.serviceOffline => '服务离线 - 操作已排队',
    AppOperationMode.fullyOffline => '完全离线 - 操作已保存',
    AppOperationMode.hybrid => '网络不稳定 - 操作已缓存',
    AppOperationMode.online => '在线模式',
  };
});

/// 用户友好的同步状态消息Provider
final syncStatusMessageProvider = Provider<String>((ref) {
  final offlineStatus = ref.watch(offlineIndicatorProvider);
  final shouldSync = ref.watch(shouldSyncProvider);
  
  if (!shouldSync) {
    return offlineStatus.detailedMessage;
  }
  
  if (offlineStatus.operationMode == AppOperationMode.hybrid) {
    return '网络不稳定，同步可能较慢';
  }
  
  return '同步正常';
}); 