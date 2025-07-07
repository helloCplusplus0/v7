// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../sync/sync_manager.dart';
import '../sync/background_sync_service.dart';
import '../sync/smart_sync_scheduler.dart';
import '../sync/background_task_manager.dart';
import '../offline/offline_indicator.dart';
import '../connectivity/network_monitor.dart';

/// 同步状态指示器
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({
    super.key,
    this.showDetails = false,
    this.compact = false,
    this.onTap,
  });

  final bool showDetails;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final backgroundSyncState = ref.watch(backgroundSyncStateProvider);
    final offlineStatus = ref.watch(offlineIndicatorProvider);
    
    return syncState.when(
      data: (state) => _buildIndicator(
        context,
        state,
        backgroundSyncState,
        offlineStatus,
      ),
      loading: () => _buildLoadingIndicator(context),
      error: (error, stack) => _buildErrorIndicator(context, error.toString()),
    );
  }

  Widget _buildIndicator(
    BuildContext context,
    SyncState syncState,
    BackgroundSyncState backgroundSyncState,
    OfflineStatus offlineStatus,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final status = _determineSyncStatus(syncState, backgroundSyncState, offlineStatus);
    final color = _getStatusColor(status, colorScheme);
    final icon = _getStatusIcon(status);
    final message = _getStatusMessage(status, syncState, backgroundSyncState);
    
    if (compact) {
      return _buildCompactIndicator(context, icon, color, message);
    }
    
    return _buildFullIndicator(context, icon, color, message, status, syncState);
  }

  Widget _buildCompactIndicator(
    BuildContext context,
    IconData icon,
    Color color,
    String message,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullIndicator(
    BuildContext context,
    IconData icon,
    Color color,
    String message,
    SyncStatusType status,
    SyncState syncState,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (status == SyncStatusType.syncing && syncState.progress != null)
                  Text(
                    '${(syncState.progress! * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              _buildSyncDetails(context, syncState, color),
            ],
            if (status == SyncStatusType.syncing && syncState.progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: syncState.progress,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncDetails(BuildContext context, SyncState syncState, Color color) {
    final details = <String>[];
    
    if (syncState.lastSyncTime != null) {
      final lastSync = syncState.lastSyncTime!;
      final now = DateTime.now();
      final difference = now.difference(lastSync);
      
      if (difference.inMinutes < 1) {
        details.add('刚刚同步');
      } else if (difference.inHours < 1) {
        details.add('${difference.inMinutes}分钟前同步');
      } else if (difference.inDays < 1) {
        details.add('${difference.inHours}小时前同步');
      } else {
        details.add('${difference.inDays}天前同步');
      }
    }
    
    if (syncState.totalItems > 0) {
      details.add('${syncState.processedItems}/${syncState.totalItems} 项目');
    }
    
    if (syncState.conflicts.isNotEmpty) {
      details.add('${syncState.conflicts.length} 个冲突');
    }
    
    if (syncState.errors.isNotEmpty) {
      details.add('${syncState.errors.length} 个错误');
    }
    
    if (details.isEmpty) return const SizedBox.shrink();
    
    return Text(
      details.join(' • '),
      style: TextStyle(
        fontSize: 12,
        color: color.withOpacity(0.8),
      ),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _buildErrorIndicator(BuildContext context, String error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 16, color: colorScheme.error),
          const SizedBox(width: 4),
          Text(
            '同步错误',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  SyncStatusType _determineSyncStatus(
    SyncState syncState,
    BackgroundSyncState backgroundSyncState,
    OfflineStatus offlineStatus,
  ) {
    if (!offlineStatus.canSync) {
      return SyncStatusType.offline;
    }
    
    if (syncState.status == SyncStatus.syncing || backgroundSyncState.hasRunningTasks) {
      return SyncStatusType.syncing;
    }
    
    if (syncState.status == SyncStatus.failed || syncState.errors.isNotEmpty) {
      return SyncStatusType.error;
    }
    
    if (syncState.conflicts.isNotEmpty) {
      return SyncStatusType.conflict;
    }
    
    if (syncState.status == SyncStatus.success) {
      return SyncStatusType.success;
    }
    
    return SyncStatusType.idle;
  }

  Color _getStatusColor(SyncStatusType status, ColorScheme colorScheme) {
    switch (status) {
      case SyncStatusType.syncing:
        return colorScheme.primary;
      case SyncStatusType.success:
        return Colors.green;
      case SyncStatusType.error:
        return colorScheme.error;
      case SyncStatusType.conflict:
        return Colors.orange;
      case SyncStatusType.offline:
        return Colors.grey;
      case SyncStatusType.idle:
        return colorScheme.outline;
    }
  }

  IconData _getStatusIcon(SyncStatusType status) {
    switch (status) {
      case SyncStatusType.syncing:
        return Icons.sync;
      case SyncStatusType.success:
        return Icons.check_circle_outline;
      case SyncStatusType.error:
        return Icons.error_outline;
      case SyncStatusType.conflict:
        return Icons.warning_amber_outlined;
      case SyncStatusType.offline:
        return Icons.cloud_off_outlined;
      case SyncStatusType.idle:
        return Icons.cloud_done_outlined;
    }
  }

  String _getStatusMessage(
    SyncStatusType status,
    SyncState syncState,
    BackgroundSyncState backgroundSyncState,
  ) {
    switch (status) {
      case SyncStatusType.syncing:
        if (syncState.currentItem != null) {
          return '正在同步 ${syncState.currentItem}';
        }
        return '同步中';
      case SyncStatusType.success:
        return '同步完成';
      case SyncStatusType.error:
        return '同步失败';
      case SyncStatusType.conflict:
        return '存在冲突';
      case SyncStatusType.offline:
        return '离线模式';
      case SyncStatusType.idle:
        return '已同步';
    }
  }
}

/// 同步状态类型
enum SyncStatusType {
  syncing,
  success,
  error,
  conflict,
  offline,
  idle,
}

/// 同步进度指示器
class SyncProgressIndicator extends ConsumerWidget {
  const SyncProgressIndicator({
    super.key,
    this.size = 24,
    this.strokeWidth = 2,
    this.showPercentage = false,
  });

  final double size;
  final double strokeWidth;
  final bool showPercentage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    
    return syncState.when(
      data: (state) {
        if (state.status != SyncStatus.syncing || state.progress == null) {
          return const SizedBox.shrink();
        }
        
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: state.progress,
                strokeWidth: strokeWidth,
              ),
              if (showPercentage)
                Text(
                  '${(state.progress! * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: size * 0.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: strokeWidth),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// 同步详情卡片
class SyncDetailCard extends ConsumerWidget {
  const SyncDetailCard({
    super.key,
    this.onRetry,
    this.onResolveConflicts,
    this.onViewLogs,
  });

  final VoidCallback? onRetry;
  final VoidCallback? onResolveConflicts;
  final VoidCallback? onViewLogs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final backgroundSyncState = ref.watch(backgroundSyncStateProvider);
    final offlineStatus = ref.watch(offlineIndicatorProvider);
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '同步状态',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            syncState.when(
              data: (state) => _buildSyncDetails(
                context,
                state,
                backgroundSyncState,
                offlineStatus,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorDetails(context, error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncDetails(
    BuildContext context,
    SyncState syncState,
    BackgroundSyncState backgroundSyncState,
    OfflineStatus offlineStatus,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 当前状态
        _buildStatusRow(
          context,
          '当前状态',
          _getStatusText(syncState, backgroundSyncState, offlineStatus),
          _getStatusColor(syncState, backgroundSyncState, offlineStatus, theme.colorScheme),
        ),
        
        const SizedBox(height: 12),
        
        // 同步进度
        if (syncState.status == SyncStatus.syncing) ...[
          _buildProgressSection(context, syncState),
          const SizedBox(height: 12),
        ],
        
        // 最后同步时间
        if (syncState.lastSyncTime != null) ...[
          _buildStatusRow(
            context,
            '最后同步',
            _formatDateTime(syncState.lastSyncTime!),
            theme.colorScheme.onSurface,
          ),
          const SizedBox(height: 12),
        ],
        
        // 下次同步时间
        if (syncState.nextSyncTime != null) ...[
          _buildStatusRow(
            context,
            '下次同步',
            _formatDateTime(syncState.nextSyncTime!),
            theme.colorScheme.onSurface,
          ),
          const SizedBox(height: 12),
        ],
        
        // 统计信息
        _buildStatisticsSection(context, syncState, backgroundSyncState),
        
        // 错误和冲突
        if (syncState.errors.isNotEmpty || syncState.conflicts.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildIssuesSection(context, syncState),
        ],
        
        // 操作按钮
        const SizedBox(height: 16),
        _buildActionButtons(context, syncState, offlineStatus),
      ],
    );
  }

  Widget _buildStatusRow(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection(BuildContext context, SyncState syncState) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '同步进度',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            if (syncState.progress != null)
              Text(
                '${(syncState.progress! * 100).toInt()}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (syncState.progress != null)
          LinearProgressIndicator(
            value: syncState.progress,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        if (syncState.currentItem != null) ...[
          const SizedBox(height: 4),
          Text(
            '正在处理: ${syncState.currentItem}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
        if (syncState.totalItems > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${syncState.processedItems} / ${syncState.totalItems} 项目',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatisticsSection(
    BuildContext context,
    SyncState syncState,
    BackgroundSyncState backgroundSyncState,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '统计信息',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                '总同步次数',
                '${backgroundSyncState.totalSyncCount}',
              ),
            ),
            Expanded(
              child: _buildStatItem(
                context,
                '成功率',
                '${(backgroundSyncState.successRate * 100).toInt()}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                '平均时长',
                '${backgroundSyncState.averageSyncDuration.inSeconds}秒',
              ),
            ),
            Expanded(
              child: _buildStatItem(
                context,
                '待处理任务',
                '${backgroundSyncState.pendingTasks.length}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildIssuesSection(BuildContext context, SyncState syncState) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '问题',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (syncState.errors.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.error.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '错误 (${syncState.errors.length})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...syncState.errors.take(3).map((error) => Text(
                  '• $error',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )),
                if (syncState.errors.length > 3)
                  Text(
                    '... 还有 ${syncState.errors.length - 3} 个错误',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (syncState.conflicts.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_outlined,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '冲突 (${syncState.conflicts.length})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...syncState.conflicts.take(3).map((conflict) => Text(
                  '• ${conflict.type}: ${conflict.id}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                  ),
                )),
                if (syncState.conflicts.length > 3)
                  Text(
                    '... 还有 ${syncState.conflicts.length - 3} 个冲突',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    SyncState syncState,
    OfflineStatus offlineStatus,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (syncState.status != SyncStatus.syncing && offlineStatus.canSync)
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('立即同步'),
          ),
        if (syncState.conflicts.isNotEmpty)
          OutlinedButton.icon(
            onPressed: onResolveConflicts,
            icon: const Icon(Icons.merge_type, size: 18),
            label: const Text('解决冲突'),
          ),
        OutlinedButton.icon(
          onPressed: onViewLogs,
          icon: const Icon(Icons.list_alt, size: 18),
          label: const Text('查看日志'),
        ),
      ],
    );
  }

  Widget _buildErrorDetails(BuildContext context, String error) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                '同步服务错误',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(
    SyncState syncState,
    BackgroundSyncState backgroundSyncState,
    OfflineStatus offlineStatus,
  ) {
    if (!offlineStatus.canSync) {
      return '离线模式';
    }
    
    if (syncState.status == SyncStatus.syncing || backgroundSyncState.hasRunningTasks) {
      return '同步中';
    }
    
    if (syncState.status == SyncStatus.failed || syncState.errors.isNotEmpty) {
      return '同步失败';
    }
    
    if (syncState.conflicts.isNotEmpty) {
      return '存在冲突';
    }
    
    if (syncState.status == SyncStatus.success) {
      return '同步完成';
    }
    
    return '空闲';
  }

  Color _getStatusColor(
    SyncState syncState,
    BackgroundSyncState backgroundSyncState,
    OfflineStatus offlineStatus,
    ColorScheme colorScheme,
  ) {
    if (!offlineStatus.canSync) {
      return Colors.grey;
    }
    
    if (syncState.status == SyncStatus.syncing || backgroundSyncState.hasRunningTasks) {
      return colorScheme.primary;
    }
    
    if (syncState.status == SyncStatus.failed || syncState.errors.isNotEmpty) {
      return colorScheme.error;
    }
    
    if (syncState.conflicts.isNotEmpty) {
      return Colors.orange;
    }
    
    if (syncState.status == SyncStatus.success) {
      return Colors.green;
    }
    
    return colorScheme.onSurface;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// 智能同步状态横幅
class SmartSyncStatusBanner extends ConsumerWidget {
  const SmartSyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final scheduleDecision = ref.watch(currentScheduleDecisionProvider);
    final offlineStatus = ref.watch(offlineIndicatorProvider);
    
    // 只在特定情况下显示横幅
    if (!_shouldShowBanner(syncState.valueOrNull, scheduleDecision, offlineStatus)) {
      return const SizedBox.shrink();
    }
    
    return _buildBanner(context, ref, syncState.valueOrNull, scheduleDecision);
  }

  bool _shouldShowBanner(
    SyncState? syncState,
    ScheduleDecision scheduleDecision,
    OfflineStatus offlineStatus,
  ) {
    // 离线时不显示同步横幅（由离线横幅处理）
    if (!offlineStatus.canSync) return false;
    
    // 同步中时显示
    if (syncState?.status == SyncStatus.syncing) return true;
    
    // 有冲突时显示
    if (syncState?.conflicts.isNotEmpty == true) return true;
    
    // 同步失败时显示
    if (syncState?.status == SyncStatus.failed) return true;
    
    // 智能调度建议同步时显示
    if (scheduleDecision.shouldSync && scheduleDecision.confidence > 0.8) return true;
    
    return false;
  }

  Widget _buildBanner(
    BuildContext context,
    WidgetRef ref,
    SyncState? syncState,
    ScheduleDecision scheduleDecision,
  ) {
    final theme = Theme.of(context);
    
    late final Color backgroundColor;
    late final Color textColor;
    late final IconData icon;
    late final String message;
    late final List<Widget> actions;
    
    if (syncState?.status == SyncStatus.syncing) {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.1);
      textColor = theme.colorScheme.primary;
      icon = Icons.sync;
      message = '正在同步数据...';
      actions = [
        TextButton(
          onPressed: () => context.go('/sync-detail'),
          child: const Text('查看详情'),
        ),
      ];
    } else if (syncState?.conflicts.isNotEmpty == true) {
      backgroundColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange;
      icon = Icons.warning_amber_outlined;
      message = '发现 ${syncState!.conflicts.length} 个数据冲突';
      actions = [
        TextButton(
          onPressed: () => context.go('/sync-conflicts'),
          child: const Text('解决冲突'),
        ),
      ];
    } else if (syncState?.status == SyncStatus.failed) {
      backgroundColor = theme.colorScheme.error.withOpacity(0.1);
      textColor = theme.colorScheme.error;
      icon = Icons.error_outline;
      message = '数据同步失败';
      actions = [
        TextButton(
          onPressed: () => _retrySyncNow(ref),
          child: const Text('重试'),
        ),
        TextButton(
          onPressed: () => context.go('/sync-detail'),
          child: const Text('查看详情'),
        ),
      ];
    } else if (scheduleDecision.shouldSync) {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.1);
      textColor = theme.colorScheme.primary;
      icon = Icons.cloud_sync_outlined;
      message = '建议立即同步：${scheduleDecision.reason}';
      actions = [
        TextButton(
          onPressed: () => _syncNow(ref),
          child: const Text('立即同步'),
        ),
        TextButton(
          onPressed: () => _dismissSuggestion(ref),
          child: const Text('稍后'),
        ),
      ];
    } else {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: textColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...actions.map((action) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: action,
          )),
        ],
      ),
    );
  }

  void _retrySyncNow(WidgetRef ref) {
    final syncManager = ref.read(syncManagerProvider);
    syncManager.startSync(force: true);
  }

  void _syncNow(WidgetRef ref) {
    final backgroundSyncService = ref.read(backgroundSyncServiceProvider.notifier);
    backgroundSyncService.syncNow();
  }

  void _dismissSuggestion(WidgetRef ref) {
    // 实现横幅关闭逻辑
  }
}

/// 浮动同步按钮
class FloatingSyncButton extends ConsumerWidget {
  const FloatingSyncButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final offlineStatus = ref.watch(offlineIndicatorProvider);
    
    return syncState.when(
      data: (state) {
        if (!offlineStatus.canSync || state.status == SyncStatus.syncing) {
          return const SizedBox.shrink();
        }
        
        return FloatingActionButton(
          onPressed: () => _triggerSync(ref),
          tooltip: '立即同步',
          child: const Icon(Icons.sync),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _triggerSync(WidgetRef ref) {
    final backgroundSyncService = ref.read(backgroundSyncServiceProvider.notifier);
    backgroundSyncService.syncNow();
  }
} 