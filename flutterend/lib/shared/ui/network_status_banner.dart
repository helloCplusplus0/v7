// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../connectivity/connectivity_providers.dart';
import '../connectivity/network_monitor.dart';
import '../offline/offline_indicator.dart';
import '../sync/sync_manager.dart';

/// 横幅类型枚举 - 支持完整的网络和离线状态
enum BannerType {
  /// 完全离线
  fullyOffline,
  /// 服务离线
  serviceOffline,
  /// 网络质量差
  poorConnection,
  /// 混合模式（不稳定）
  hybridMode,
  /// 同步错误
  syncError,
  /// 同步中
  syncing,
  /// 数据恢复中
  dataRecovering,
}

/// 横幅信息数据结构
class BannerInfo {
  final BannerType type;
  final String message;
  final String? description;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final List<BannerAction> actions;
  final bool isDismissible;
  final Duration? autoDismissAfter;
  final bool showProgress;
  final double? progress;

  const BannerInfo({
    required this.type,
    required this.message,
    this.description,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
    this.actions = const [],
    this.isDismissible = true,
    this.autoDismissAfter,
    this.showProgress = false,
    this.progress,
  });
}

/// 横幅操作
class BannerAction {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const BannerAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });
}

/// 网络状态横幅关闭状态提供器
final bannerDismissalProvider = StateNotifierProvider<BannerDismissalNotifier, Map<BannerType, DateTime>>((ref) {
  return BannerDismissalNotifier();
});

/// 智能横幅关闭状态管理器
class BannerDismissalNotifier extends StateNotifier<Map<BannerType, DateTime>> {
  BannerDismissalNotifier() : super({});

  /// 关闭横幅
  void dismissBanner(BannerType type) {
    state = {...state, type: DateTime.now()};
    debugPrint('🚫 横幅已关闭: $type');
  }

  /// 检查是否应该显示横幅
  bool shouldShowBanner(BannerType type) {
    final dismissTime = state[type];
    if (dismissTime == null) return true;
    
    final cooldownMinutes = _getCooldownMinutes(type);
    final timeSinceDismiss = DateTime.now().difference(dismissTime).inMinutes;
    
    return timeSinceDismiss >= cooldownMinutes;
  }

  /// 重置横幅状态
  void resetBanner(BannerType type) {
    final newState = Map<BannerType, DateTime>.from(state);
    newState.remove(type);
    state = newState;
    debugPrint('🔄 横幅重置: $type');
  }

  /// 网络状态变化时的智能重置
  void onNetworkStateChanged(bool isConnected, NetworkQuality quality) {
    final newState = Map<BannerType, DateTime>.from(state);
    
    if (isConnected) {
      // 网络恢复时重置离线相关横幅
      newState.remove(BannerType.fullyOffline);
      newState.remove(BannerType.serviceOffline);
      
      if (quality != NetworkQuality.poor) {
        newState.remove(BannerType.poorConnection);
        newState.remove(BannerType.hybridMode);
      }
      debugPrint('🌐 网络恢复，重置相关横幅');
    }
    
    state = newState;
  }

  /// 离线状态变化时的智能重置
  void onOfflineStateChanged(AppOperationMode mode) {
    final newState = Map<BannerType, DateTime>.from(state);
    
    if (mode == AppOperationMode.online) {
      // 恢复在线时重置所有离线横幅
      newState.remove(BannerType.fullyOffline);
      newState.remove(BannerType.serviceOffline);
      newState.remove(BannerType.hybridMode);
      newState.remove(BannerType.syncError);
      debugPrint('📱 恢复在线，重置所有离线横幅');
    }
    
    state = newState;
  }

  /// 获取不同类型横幅的冷却时间
  int _getCooldownMinutes(BannerType type) {
    switch (type) {
      case BannerType.fullyOffline:
        return 5;
      case BannerType.serviceOffline:
        return 10;
      case BannerType.poorConnection:
        return 10;
      case BannerType.hybridMode:
        return 15;
      case BannerType.syncError:
        return 3;
      case BannerType.syncing:
        return 1;
      case BannerType.dataRecovering:
        return 2;
    }
  }

  /// 强制显示横幅（用于紧急状态）
  void forceShowBanner(BannerType type) {
    resetBanner(type);
    debugPrint('🚨 强制显示横幅: $type');
  }

  /// 重置所有横幅
  void resetAllBanners() {
    state = {};
    debugPrint('🔄 所有横幅已重置');
  }
}

/// 🌐 网络状态横幅组件 - v7架构统一状态指示器
/// 
/// 设计原则：
/// 1. 统一网络状态和离线状态指示
/// 2. 智能显示策略，避免信息过载
/// 3. Material Design横幅规范
/// 4. 与离线优先架构完美集成

class NetworkStatusBanner extends ConsumerWidget {
  const NetworkStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听多个状态源
    final isConnected = ref.watch(isConnectedProvider);
    final networkQuality = ref.watch(networkQualityProvider);
    final offlineStatus = ref.watch(offlineIndicatorProvider);
    final syncState = ref.watch(syncStateProvider);
    final dismissalNotifier = ref.read(bannerDismissalProvider.notifier);
    
    // 响应状态变化
    ref.listen(isConnectedProvider, (previous, next) {
      if (previous != next) {
        dismissalNotifier.onNetworkStateChanged(next, networkQuality);
      }
    });
    
    ref.listen(offlineIndicatorProvider, (previous, next) {
      if (previous?.operationMode != next.operationMode) {
        dismissalNotifier.onOfflineStateChanged(next.operationMode);
      }
    });

    // 确定要显示的横幅
    final bannerInfo = _determineBannerInfo(
      isConnected: isConnected,
      networkQuality: networkQuality,
      offlineStatus: offlineStatus,
      syncState: syncState.valueOrNull,
      context: context,
    );

    // 检查是否应该显示
    if (bannerInfo == null || !dismissalNotifier.shouldShowBanner(bannerInfo.type)) {
      return const SizedBox.shrink();
    }

    return _buildBanner(context, ref, bannerInfo);
  }

  /// 确定要显示的横幅信息
  BannerInfo? _determineBannerInfo({
    required bool isConnected,
    required NetworkQuality networkQuality,
    required OfflineStatus offlineStatus,
    SyncState? syncState,
    required BuildContext context,
  }) {
    // 优先级排序：完全离线 > 服务离线 > 混合模式 > 网络质量差 > 同步状态

    // 1. 完全离线（最高优先级）
    if (offlineStatus.operationMode == AppOperationMode.fullyOffline) {
      return BannerInfo(
        type: BannerType.fullyOffline,
        message: '设备离线',
        description: '正在使用离线模式，部分功能受限',
        icon: Icons.wifi_off_rounded,
        backgroundColor: Colors.red.shade50,
        textColor: Colors.red.shade800,
        iconColor: Colors.red.shade600,
        actions: [
          BannerAction(
            label: '查看详情',
            onPressed: () => context.go('/offline-detail'),
          ),
        ],
      );
    }

    // 2. 服务离线
    if (offlineStatus.operationMode == AppOperationMode.serviceOffline) {
      return BannerInfo(
        type: BannerType.serviceOffline,
        message: '服务连接异常',
        description: '网络正常但无法连接服务器',
        icon: Icons.cloud_off_rounded,
        backgroundColor: Colors.orange.shade50,
        textColor: Colors.orange.shade800,
        iconColor: Colors.orange.shade600,
        actions: [
          BannerAction(
            label: '查看详情',
            onPressed: () => context.go('/offline-detail'),
          ),
        ],
      );
    }

    // 3. 混合模式（网络不稳定）
    if (offlineStatus.operationMode == AppOperationMode.hybrid) {
      return BannerInfo(
        type: BannerType.hybridMode,
        message: '网络不稳定',
        description: '连接不稳定，部分功能可能受影响',
        icon: Icons.signal_wifi_bad_rounded,
        backgroundColor: Colors.yellow.shade50,
        textColor: Colors.yellow.shade800,
        iconColor: Colors.yellow.shade600,
        actions: [
          BannerAction(
            label: '查看详情',
            onPressed: () => context.go('/offline-detail'),
          ),
        ],
      );
    }

    // 4. 网络质量差
    if (isConnected && networkQuality == NetworkQuality.poor) {
      return BannerInfo(
        type: BannerType.poorConnection,
        message: '网络质量较差',
        description: '当前网络延迟较高，可能影响使用体验',
        icon: Icons.signal_wifi_bad_rounded,
        backgroundColor: Colors.amber.shade50,
        textColor: Colors.amber.shade800,
        iconColor: Colors.amber.shade600,
        actions: [
          BannerAction(
            label: '网络诊断',
            onPressed: () => context.go('/offline-detail'),
          ),
        ],
      );
    }

    // 5. 同步状态
    if (syncState != null) {
      if (syncState.status == SyncStatus.syncing) {
        return BannerInfo(
          type: BannerType.syncing,
          message: '数据同步中',
          description: '正在同步最新数据...',
          icon: Icons.sync_rounded,
          backgroundColor: Colors.blue.shade50,
          textColor: Colors.blue.shade800,
          iconColor: Colors.blue.shade600,
          actions: [],
          isDismissible: false,
          autoDismissAfter: const Duration(seconds: 5),
          showProgress: syncState.syncProgress != null,
          progress: syncState.syncProgress,
        );
      }
      
      if (syncState.status == SyncStatus.failed) {
        return BannerInfo(
          type: BannerType.syncError,
          message: '数据同步失败',
          description: '部分数据可能不是最新版本',
          icon: Icons.sync_problem_rounded,
          backgroundColor: Colors.red.shade50,
          textColor: Colors.red.shade800,
          iconColor: Colors.red.shade600,
          actions: [
            BannerAction(
              label: '重试同步',
              onPressed: () => _retrySync(),
              isPrimary: true,
            ),
          ],
        );
      }
    }

    return null; // 无需显示横幅
  }

  /// 构建横幅UI
  Widget _buildBanner(BuildContext context, WidgetRef ref, BannerInfo bannerInfo) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Material(
        color: bannerInfo.backgroundColor,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: bannerInfo.iconColor.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // 图标
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: bannerInfo.iconColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          bannerInfo.icon,
                          color: bannerInfo.iconColor,
                          size: 20,
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // 内容
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              bannerInfo.message,
                              style: TextStyle(
                                color: bannerInfo.textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (bannerInfo.description != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                bannerInfo.description!,
                                style: TextStyle(
                                  color: bannerInfo.textColor.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            // 进度条
                            if (bannerInfo.showProgress && bannerInfo.progress != null) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: bannerInfo.progress,
                                backgroundColor: bannerInfo.iconColor.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(bannerInfo.iconColor),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // 操作按钮
                      if (bannerInfo.actions.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: bannerInfo.actions.map((action) => 
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: action.isPrimary
                                  ? FilledButton(
                                      onPressed: action.onPressed,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: bannerInfo.iconColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        action.label,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )
                                  : TextButton(
                                      onPressed: action.onPressed,
                                      style: TextButton.styleFrom(
                                        foregroundColor: bannerInfo.iconColor,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        action.label,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                            ),
                          ).toList(),
                        ),
                      ],
                      
                      // 关闭按钮
                      if (bannerInfo.isDismissible) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => ref.read(bannerDismissalProvider.notifier).dismissBanner(bannerInfo.type),
                          icon: Icon(
                            Icons.close_rounded,
                            color: bannerInfo.iconColor,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 操作方法
  void _retrySync() {
    // 重试数据同步
    debugPrint('🔄 重试数据同步');
  }
}

/// 同步状态提供器
final syncStateProvider = Provider<AsyncValue<SyncState?>>((ref) {
  // 这里应该连接到实际的同步管理器
  // 暂时返回空状态
  return const AsyncValue.data(null);
});

/// 同步状态模型
class SyncState {
  final SyncStatus status;
  final double? syncProgress;
  final bool hasErrors;
  final bool isSyncing;

  const SyncState({
    required this.status,
    this.syncProgress,
    this.hasErrors = false,
    this.isSyncing = false,
  });
}

/// 同步状态枚举
enum SyncStatus {
  idle,
  syncing,
  completed,
  failed,
}