/// 🎨 v7 Flutter切片卡片 - 完全对齐Web端Telegram风格
/// 
/// 设计原则：
/// 1. 黄金比例布局（1.618:1）
/// 2. 状态优先显示
/// 3. 指标展示和趋势图标
/// 4. 最后更新时间
/// 5. Telegram美学设计

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../contracts/slice_summary_contract.dart';
import '../connectivity/connectivity_providers.dart';
import '../connectivity/network_monitor.dart';

class TelegramSliceCard extends ConsumerStatefulWidget {
  const TelegramSliceCard({
    super.key,
    required this.slice,
    required this.onTap,
    this.summary,
  });

  final SliceRegistration slice;
  final SliceSummaryContract? summary;
  final VoidCallback onTap;

  @override
  ConsumerState<TelegramSliceCard> createState() => _TelegramSliceCardState();
}

class _TelegramSliceCardState extends ConsumerState<TelegramSliceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _handleTapDown(),
            onTapUp: (_) => _handleTapUp(),
            onTapCancel: () => _handleTapCancel(),
            onTap: widget.onTap,
            child: Container(
              decoration: _isPressed
                  ? AppTheme.sliceCardHoverDecoration
                  : AppTheme.sliceCardDecoration,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 12),
                          _buildDescription(),
                          const SizedBox(height: 16),
                          _buildMetrics(),
                          const Spacer(),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 🎯 切片头部：名称 + 状态
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.slice.displayName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _buildStatusIndicators(),
      ],
    );
  }

  /// 🎯 状态指示器组合：网络状态 + 后端状态 + 同步状态 + 切片状态
  Widget _buildStatusIndicators() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 网络状态指示器
        _buildNetworkIndicator(),
        
        const SizedBox(width: 6),
        
        // 后端服务状态指示器（如果有）
        if (widget.summary?.hasBackendService == true) ...[
          _buildBackendServiceIndicator(),
          const SizedBox(width: 6),
        ],
        
        // 同步状态指示器（如果启用了后台同步）
        if (widget.summary?.hasBackgroundSync == true) ...[
          _buildSyncStatusIndicator(),
          const SizedBox(width: 6),
        ],
        
        // 切片状态指示器
        _buildSliceStatusIndicator(),
      ],
    );
  }

  /// 🎯 网络状态指示器
  Widget _buildNetworkIndicator() {
    final isConnected = ref.watch(isConnectedProvider);
    final networkQuality = ref.watch(networkQualityProvider);
    final networkType = ref.watch(networkTypeProvider);
    
    // 获取网络状态信息
    final networkInfo = _getNetworkStatusInfo(
      isConnected: isConnected,
      quality: networkQuality,
      type: networkType,
    );
    
    return Tooltip(
      message: networkInfo.tooltip,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: networkInfo.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          networkInfo.icon,
          size: 12,
          color: networkInfo.color,
        ),
      ),
    );
  }

  /// 🎯 后端服务状态指示器
  Widget _buildBackendServiceIndicator() {
    final backendService = widget.summary?.backendService;
    if (backendService == null) return const SizedBox.shrink();
    
    final statusInfo = _getBackendStatusInfo(backendService.status);
    
    return Tooltip(
      message: '${backendService.name}: ${backendService.statusDescription}',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: statusInfo.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          statusInfo.icon,
          size: 12,
          color: statusInfo.color,
        ),
      ),
    );
  }

  /// 🎯 同步状态指示器
  Widget _buildSyncStatusIndicator() {
    final syncInfo = widget.summary?.syncInfo;
    if (syncInfo == null) return const SizedBox.shrink();
    
    final statusInfo = _getSyncStatusInfo(syncInfo.status);
    
    return Tooltip(
      message: '同步状态: ${syncInfo.statusDescription}',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: statusInfo.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          statusInfo.icon,
          size: 12,
          color: statusInfo.color,
        ),
      ),
    );
  }

  /// 🎯 切片状态指示器
  Widget _buildSliceStatusIndicator() {
    final status = widget.summary?.status ?? SliceStatus.loading;
    final statusInfo = _getStatusInfo(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusInfo.icon,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(width: 4),
          Text(
            statusInfo.text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: statusInfo.color,
            ),
          ),
        ],
      ),
    );
  }

  /// 🎯 切片描述
  Widget _buildDescription() {
    final description = widget.summary?.description ?? widget.slice.description;
    
    if (description?.isNotEmpty != true) {
      return const SizedBox.shrink();
    }
    
    return Expanded(
      child: Text(
        description!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.textSecondary,
          height: 1.4,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 🎯 核心指标
  Widget _buildMetrics() {
    final metrics = widget.summary?.metrics ?? [];
    
    if (metrics.isEmpty) {
      return _buildDefaultMetrics();
    }
    
    return Column(
      children: metrics.take(3).map((metric) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            // 指标信息
            Row(
              children: [
                if (metric.icon?.isNotEmpty == true) ...[
                  Text(
                    metric.icon!,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  metric.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // 指标值和趋势
            Row(
              children: [
                Text(
                  '${metric.value}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  AppTheme.getTrendIcon(metric.trend),
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }

  /// 🎯 默认指标（当没有摘要数据时）
  Widget _buildDefaultMetrics() {
    return Column(
      children: [
        _buildMetricRow('状态', widget.slice.category ?? '未知', '📋'),
        const SizedBox(height: 8),
        _buildMetricRow('版本', 'v${widget.slice.version ?? '0.0.0'}', '🏷️'),
      ],
    );
  }

  /// 🎯 指标行
  Widget _buildMetricRow(String label, String value, String icon) {
    return Row(
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 🎯 切片底部：最后更新时间
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.borderLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 12,
            color: AppTheme.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            _formatUpdateTime(widget.summary?.lastUpdated),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const Spacer(),
          if (widget.slice.version?.isNotEmpty == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.bgSecondary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'v${widget.slice.version}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 🎯 触摸交互处理
  void _handleTapDown() {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapUp() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  /// 🎯 状态信息映射
  ({String icon, String text, Color color}) _getStatusInfo(SliceStatus status) {
    switch (status) {
      case SliceStatus.healthy:
        return (icon: '🟢', text: '运行中', color: AppTheme.successColor);
      case SliceStatus.warning:
        return (icon: '🟡', text: '警告', color: AppTheme.warningColor);
      case SliceStatus.error:
        return (icon: '🔴', text: '异常', color: AppTheme.errorColor);
      case SliceStatus.loading:
        return (icon: '⚪', text: '加载中', color: AppTheme.textMuted);
    }
  }

  /// 🎯 网络状态信息映射
  ({IconData icon, Color color, String tooltip}) _getNetworkStatusInfo({
    required bool isConnected,
    required NetworkQuality quality,
    required NetworkType type,
  }) {
    if (!isConnected) {
      return (icon: Icons.signal_wifi_off_rounded, color: AppTheme.errorColor, tooltip: '未连接网络');
    }

    switch (quality) {
      case NetworkQuality.excellent:
        return (icon: Icons.signal_wifi_4_bar_rounded, color: AppTheme.successColor, tooltip: '网络优秀');
      case NetworkQuality.good:
        return (icon: Icons.wifi_rounded, color: AppTheme.successColor, tooltip: '网络良好');
      case NetworkQuality.fair:
        return (icon: Icons.signal_wifi_statusbar_null_rounded, color: AppTheme.warningColor, tooltip: '网络一般');
      case NetworkQuality.poor:
        return (icon: Icons.signal_wifi_bad_rounded, color: AppTheme.warningColor, tooltip: '网络较差');
      case NetworkQuality.none:
        return (icon: Icons.signal_wifi_off_rounded, color: AppTheme.textMuted, tooltip: '无网络连接');
    }
  }

  /// 🎯 后端服务状态信息映射
  ({IconData icon, Color color}) _getBackendStatusInfo(BackendHealthStatus status) {
    switch (status) {
      case BackendHealthStatus.healthy:
        return (icon: Icons.cloud_done_rounded, color: AppTheme.successColor);
      case BackendHealthStatus.warning:
        return (icon: Icons.cloud_queue_rounded, color: AppTheme.warningColor);
      case BackendHealthStatus.error:
        return (icon: Icons.cloud_off_rounded, color: AppTheme.errorColor);
      case BackendHealthStatus.checking:
        return (icon: Icons.cloud_sync_rounded, color: AppTheme.textMuted);
      case BackendHealthStatus.unknown:
        return (icon: Icons.help_outline_rounded, color: AppTheme.textMuted);
    }
  }

  /// 🎯 同步状态信息映射
  ({IconData icon, Color color}) _getSyncStatusInfo(SliceSyncStatus status) {
    switch (status) {
      case SliceSyncStatus.idle:
        return (icon: Icons.pause_rounded, color: AppTheme.textMuted);
      case SliceSyncStatus.syncing:
        return (icon: Icons.sync_rounded, color: AppTheme.warningColor);
      case SliceSyncStatus.success:
        return (icon: Icons.check_circle_rounded, color: AppTheme.successColor);
      case SliceSyncStatus.failed:
        return (icon: Icons.error_rounded, color: AppTheme.errorColor);
      case SliceSyncStatus.paused:
        return (icon: Icons.pause_circle_rounded, color: AppTheme.textMuted);
    }
  }

  /// 🎯 格式化更新时间
  String _formatUpdateTime(DateTime? time) {
    if (time == null) return '未知';
    
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
} 