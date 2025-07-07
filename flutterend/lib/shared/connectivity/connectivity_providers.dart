// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'network_monitor.dart';
import '../signals/app_signals.dart';

/// 兼容性支持 - 与v7flutterules.md中的示例代码保持兼容
enum ConnectivityStatus {
  /// 在线
  online,
  /// 离线
  offline,
  /// 连接受限
  limited,
}

/// 网络状态快捷访问提供器
final networkStatusProvider = Provider<NetworkStatus>((ref) {
  return ref.watch(networkMonitorProvider.select((state) => state.status));
});

/// 网络连接状态快捷访问提供器
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(networkMonitorProvider.select((state) => state.isConnected));
});

/// 网络质量快捷访问提供器
final networkQualityProvider = Provider<NetworkQuality>((ref) {
  return ref.watch(networkMonitorProvider.select((state) => state.quality));
});

/// 网络类型快捷访问提供器
final networkTypeProvider = Provider<NetworkType>((ref) {
  return ref.watch(networkMonitorProvider.select((state) => state.type));
});

/// 连接状态提供器 - 兼容v7flutterules.md中的示例代码
final connectivityProvider = Provider<AsyncValue<ConnectivityStatus>>((ref) {
  final networkState = ref.watch(networkMonitorProvider);
  
  if (networkState.error != null) {
    return AsyncValue.error(Exception(networkState.error!), StackTrace.current);
  }
  
  final status = switch (networkState.status) {
    NetworkStatus.online => networkState.quality == NetworkQuality.poor 
        ? ConnectivityStatus.limited 
        : ConnectivityStatus.online,
    NetworkStatus.limited => ConnectivityStatus.limited,
    NetworkStatus.offline || NetworkStatus.unknown => ConnectivityStatus.offline,
  };
  
  return AsyncValue.data(status);
});

/// 集成提供器 - 自动将网络状态同步到全局应用状态
final networkIntegrationProvider = Provider<void>((ref) {
  // 监听网络状态变化，更新全局应用状态
  ref.listen(isConnectedProvider, (previous, next) {
    if (previous != next) {
      // 安全地更新全局应用状态中的网络连接状态
      try {
        ref.read(appStateProvider.notifier).updateNetworkStatus(next);
      } catch (e) {
        // 静默处理错误，避免影响provider链
      }
    }
  });
  
  return;
}); 