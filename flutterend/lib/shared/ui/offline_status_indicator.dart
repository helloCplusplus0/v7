// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline/offline_indicator.dart';

/// 离线状态指示器UI组件
class OfflineStatusIndicator extends ConsumerWidget {
  const OfflineStatusIndicator({
    super.key,
    this.showDetails = false,
    this.onTap,
    this.compact = false,
  });

  /// 是否显示详细信息
  final bool showDetails;
  /// 点击回调
  final VoidCallback? onTap;
  /// 是否使用紧凑模式
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineStatus = ref.watch(offlineIndicatorProvider);
    
    if (!offlineStatus.shouldShowIndicator) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8.0 : 12.0,
          vertical: compact ? 4.0 : 8.0,
        ),
        decoration: BoxDecoration(
          color: _getStatusColor(offlineStatus.operationMode),
          borderRadius: BorderRadius.circular(compact ? 12.0 : 16.0),
          border: Border.all(
            color: _getStatusColor(offlineStatus.operationMode).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getStatusIcon(offlineStatus.operationMode),
              size: compact ? 14.0 : 16.0,
              color: _getIconColor(offlineStatus.operationMode),
            ),
            if (!compact) ...[
              const SizedBox(width: 8.0),
              Text(
                offlineStatus.userFriendlyMessage,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: _getTextColor(offlineStatus.operationMode),
                ),
              ),
            ],
            if (showDetails && offlineStatus.offlineDuration.inMinutes > 0) ...[
              const SizedBox(width: 4.0),
              Text(
                '(${_formatDuration(offlineStatus.offlineDuration)})',
                style: TextStyle(
                  fontSize: 10.0,
                  color: _getTextColor(offlineStatus.operationMode).withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AppOperationMode mode) {
    return switch (mode) {
      AppOperationMode.online => Colors.green.shade100,
      AppOperationMode.serviceOffline => Colors.orange.shade100,
      AppOperationMode.fullyOffline => Colors.red.shade100,
      AppOperationMode.hybrid => Colors.yellow.shade100,
    };
  }

  IconData _getStatusIcon(AppOperationMode mode) {
    return switch (mode) {
      AppOperationMode.online => Icons.wifi,
      AppOperationMode.serviceOffline => Icons.cloud_off,
      AppOperationMode.fullyOffline => Icons.wifi_off,
      AppOperationMode.hybrid => Icons.signal_wifi_bad,
    };
  }

  Color _getIconColor(AppOperationMode mode) {
    return switch (mode) {
      AppOperationMode.online => Colors.green.shade700,
      AppOperationMode.serviceOffline => Colors.orange.shade700,
      AppOperationMode.fullyOffline => Colors.red.shade700,
      AppOperationMode.hybrid => Colors.yellow.shade700,
    };
  }

  Color _getTextColor(AppOperationMode mode) {
    return switch (mode) {
      AppOperationMode.online => Colors.green.shade800,
      AppOperationMode.serviceOffline => Colors.orange.shade800,
      AppOperationMode.fullyOffline => Colors.red.shade800,
      AppOperationMode.hybrid => Colors.yellow.shade800,
    };
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}天';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}小时';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}分钟';
    } else {
      return '刚刚';
    }
  }
}

/// 离线状态浮动指示器
class OfflineStatusFloatingIndicator extends ConsumerWidget {
  const OfflineStatusFloatingIndicator({
    super.key,
    this.onTap,
    this.position = FloatingIndicatorPosition.topRight,
  });

  final VoidCallback? onTap;
  final FloatingIndicatorPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineStatus = ref.watch(offlineIndicatorProvider);
    
    if (!offlineStatus.shouldShowIndicator) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: position.isTop ? 16.0 : null,
      bottom: position.isBottom ? 16.0 : null,
      left: position.isLeft ? 16.0 : null,
      right: position.isRight ? 16.0 : null,
      child: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(20.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: _getStatusColor(offlineStatus.operationMode),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(offlineStatus.operationMode),
                  size: 16.0,
                  color: _getIconColor(offlineStatus.operationMode),
                ),
                const SizedBox(width: 8.0),
                Text(
                  offlineStatus.userFriendlyMessage,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(AppOperationMode mode) {
    return switch (mode) {
      AppOperationMode.online => Colors.green,
      AppOperationMode.serviceOffline => Colors.orange,
      AppOperationMode.fullyOffline => Colors.red,
      AppOperationMode.hybrid => Colors.yellow,
    };
  }

  IconData _getStatusIcon(AppOperationMode mode) {
    return switch (mode) {
      AppOperationMode.online => Icons.wifi,
      AppOperationMode.serviceOffline => Icons.cloud_off,
      AppOperationMode.fullyOffline => Icons.wifi_off,
      AppOperationMode.hybrid => Icons.signal_wifi_bad,
    };
  }

  Color _getIconColor(AppOperationMode mode) {
    return switch (mode) {
      AppOperationMode.online => Colors.green.shade700,
      AppOperationMode.serviceOffline => Colors.orange.shade700,
      AppOperationMode.fullyOffline => Colors.red.shade700,
      AppOperationMode.hybrid => Colors.yellow.shade700,
    };
  }
}

/// 浮动指示器位置枚举
enum FloatingIndicatorPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  bool get isTop => this == topLeft || this == topRight;
  bool get isBottom => this == bottomLeft || this == bottomRight;
  bool get isLeft => this == topLeft || this == bottomLeft;
  bool get isRight => this == topRight || this == bottomRight;
}

/// 离线状态详情卡片
class OfflineStatusDetailCard extends ConsumerWidget {
  const OfflineStatusDetailCard({
    super.key,
    this.onRetry,
    this.onViewDetails,
  });

  final VoidCallback? onRetry;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineStatus = ref.watch(offlineIndicatorProvider);
    
    if (!offlineStatus.shouldShowIndicator) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(offlineStatus.operationMode),
                  color: _getIconColor(offlineStatus.operationMode),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offlineStatus.userFriendlyMessage,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (offlineStatus.reason != null)
                        Text(
                          _getReasonText(offlineStatus.reason!),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (offlineStatus.offlineDuration.inMinutes > 0) ...[
              const SizedBox(height: 8.0),
              Text(
                '离线时长: ${_formatDuration(offlineStatus.offlineDuration)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (offlineStatus.canRetry) ...[
              const SizedBox(height: 12.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onViewDetails != null)
                    TextButton(
                      onPressed: onViewDetails,
                      child: const Text('查看详情'),
                    ),
                  const SizedBox(width: 8.0),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('重试连接'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(AppOperationMode mode) {
    return switch (mode) {
      AppOperationMode.online => Icons.wifi,
      AppOperationMode.serviceOffline => Icons.cloud_off,
      AppOperationMode.fullyOffline => Icons.wifi_off,
      AppOperationMode.hybrid => Icons.signal_wifi_bad,
    };
  }

  Color _getIconColor(AppOperationMode mode) {
    return switch (mode) {
      AppOperationMode.online => Colors.green,
      AppOperationMode.serviceOffline => Colors.orange,
      AppOperationMode.fullyOffline => Colors.red,
      AppOperationMode.hybrid => Colors.yellow,
    };
  }

  String _getReasonText(OfflineReason reason) {
    return switch (reason) {
      OfflineReason.noNetwork => '设备无网络连接',
      OfflineReason.unstableNetwork => '网络连接不稳定',
      OfflineReason.serviceUnavailable => '服务器无法连接',
      OfflineReason.serviceTimeout => '服务器响应超时',
      OfflineReason.serviceError => '服务器错误',
      OfflineReason.userChoice => '用户选择离线模式',
      OfflineReason.maintenance => '系统维护中',
    };
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}天 ${duration.inHours % 24}小时';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}小时 ${duration.inMinutes % 60}分钟';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}分钟';
    } else {
      return '刚刚';
    }
  }
} 