/// 🎨 v7 Flutter切片卡片 - 完全对齐Web端Telegram风格
/// 
/// 设计原则：
/// 1. 黄金比例布局（1.618:1）
/// 2. 状态优先显示
/// 3. 指标展示和趋势图标
/// 4. 最后更新时间
/// 5. Telegram美学设计

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../contracts/slice_summary_contract.dart';

class TelegramSliceCard extends StatefulWidget {
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
  State<TelegramSliceCard> createState() => _TelegramSliceCardState();
}

class _TelegramSliceCardState extends State<TelegramSliceCard>
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
        _buildStatusIndicator(),
      ],
    );
  }

  /// 🎯 状态指示器
  Widget _buildStatusIndicator() {
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