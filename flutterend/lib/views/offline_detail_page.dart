/// 🌐 离线状态详情页面 - v7架构网络状态管理中心
/// 
/// 设计原则：
/// 1. Material 3设计规范，与v7主题保持一致
/// 2. 分层信息展示：网络状态 → 同步队列 → 数据统计 → 操作控制
/// 3. 离线优先架构，强调本地数据可用性
/// 4. 实时状态更新，响应式UI设计

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../shared/connectivity/connectivity_providers.dart';
import '../shared/connectivity/network_monitor.dart';
import '../shared/sync/sync_manager.dart';
import '../shared/sync/offline_queue.dart';
import '../shared/ui/sync_status_components.dart';

class OfflineDetailPage extends ConsumerStatefulWidget {
  const OfflineDetailPage({super.key});

  @override
  ConsumerState<OfflineDetailPage> createState() => _OfflineDetailPageState();
}

class _OfflineDetailPageState extends ConsumerState<OfflineDetailPage> 
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSecondary,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNetworkStatusTab(),
          _buildSyncQueueTab(),
          _buildDataStatisticsTab(),
        ],
      ),
    );
  }

  /// 🎯 应用栏构建
  PreferredSizeWidget _buildAppBar() {
    final isConnected = ref.watch(isConnectedProvider);
    final networkQuality = ref.watch(networkQualityProvider);
    
    return AppBar(
      backgroundColor: AppTheme.bgPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.go('/'),
      ),
      title: Row(
        children: [
          Icon(
            isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: isConnected ? AppTheme.successColor : AppTheme.errorColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '网络状态',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _getStatusSubtitle(isConnected, networkQuality),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _handleRefresh,
          tooltip: '刷新状态',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.primaryColor,
        tabs: const [
          Tab(icon: Icon(Icons.network_check_rounded), text: '网络状态'),
          Tab(icon: Icon(Icons.sync_rounded), text: '同步队列'),
          Tab(icon: Icon(Icons.analytics_rounded), text: '数据统计'),
        ],
      ),
    );
  }

  /// 🌐 网络状态标签页
  Widget _buildNetworkStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNetworkOverviewCard(),
          const SizedBox(height: 16),
          _buildNetworkQualityCard(),
          const SizedBox(height: 16),
          _buildConnectivityHistoryCard(),
        ],
      ),
    );
  }

  /// 🔄 同步队列标签页
  Widget _buildSyncQueueTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSyncOverviewCard(),
          const SizedBox(height: 16),
          _buildPendingActionsCard(),
          const SizedBox(height: 16),
          _buildSyncHistoryCard(),
        ],
      ),
    );
  }

  /// 📊 数据统计标签页
  Widget _buildDataStatisticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDataOverviewCard(),
          const SizedBox(height: 16),
          _buildStorageUsageCard(),
          const SizedBox(height: 16),
          _buildCacheStatisticsCard(),
        ],
      ),
    );
  }

  /// 🌐 网络概览卡片
  Widget _buildNetworkOverviewCard() {
    final networkState = ref.watch(networkMonitorProvider);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.network_check_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  '网络连接概览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow('连接状态', _getConnectionStatusText(networkState.isConnected), 
                networkState.isConnected ? AppTheme.successColor : AppTheme.errorColor),
            _buildStatusRow('网络类型', _getNetworkTypeText(networkState.type), AppTheme.textPrimary),
            _buildStatusRow('网络质量', _getNetworkQualityText(networkState.quality), 
                _getQualityColor(networkState.quality)),
                         if (networkState.stats.latency != Duration.zero)
               _buildStatusRow('延迟', '${networkState.stats.latency.inMilliseconds}ms', AppTheme.textPrimary),
            if (networkState.error != null)
              _buildStatusRow('错误信息', networkState.error!, AppTheme.errorColor),
          ],
        ),
      ),
    );
  }

  /// 📶 网络质量卡片
  Widget _buildNetworkQualityCard() {
    final networkState = ref.watch(networkMonitorProvider);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.signal_wifi_4_bar_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  '网络质量评估',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildQualityIndicator(networkState.quality),
            const SizedBox(height: 12),
            Text(
              _getQualityDescription(networkState.quality),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📜 连接历史卡片
  Widget _buildConnectivityHistoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  '连接历史',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // TODO: 实现连接历史列表
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    '连接历史功能正在开发中',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔄 同步概览卡片
  Widget _buildSyncOverviewCard() {
    return Column(
      children: [
        // 使用新的同步状态指示器
        const SyncStatusIndicator(
          showDetails: true,
          compact: false,
        ),
        const SizedBox(height: 16),
        // 使用新的同步详情卡片
        const SyncDetailCard(),
        const SizedBox(height: 16),
        // 使用新的同步进度指示器
        const SyncProgressIndicator(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _handleManualSync,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('立即同步'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  /// 📋 待处理操作卡片
  Widget _buildPendingActionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pending_actions_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  '待处理操作',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // TODO: 实现待处理操作列表
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    '当前没有待处理的操作',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📜 同步历史卡片
  Widget _buildSyncHistoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  '同步历史',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // TODO: 实现同步历史列表
            ...List.generate(3, (index) => _buildSyncHistoryItem(
              '数据同步 #${index + 1}',
              '成功',
              '${5 + index * 2}分钟前',
              AppTheme.successColor,
            )),
          ],
        ),
      ),
    );
  }

  /// 📊 数据概览卡片
  Widget _buildDataOverviewCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  '数据统计概览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow('本地数据', '1,234条记录', AppTheme.textPrimary),
            _buildStatusRow('缓存命中率', '89.5%', AppTheme.successColor),
            _buildStatusRow('离线可用性', '100%', AppTheme.successColor),
            _buildStatusRow('数据完整性', '正常', AppTheme.successColor),
          ],
        ),
      ),
    );
  }

  /// 💾 存储使用情况卡片
  Widget _buildStorageUsageCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  '存储使用情况',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStorageBar('数据库', 45.2, AppTheme.primaryColor),
            const SizedBox(height: 12),
            _buildStorageBar('缓存', 23.8, AppTheme.successColor),
            const SizedBox(height: 12),
            _buildStorageBar('媒体文件', 12.5, AppTheme.warningColor),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '总使用量: 234.5 MB',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _handleClearCache,
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text('清理缓存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 📈 缓存统计卡片
  Widget _buildCacheStatisticsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cached_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  '缓存性能统计',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatisticItem('缓存命中', '1,245', AppTheme.successColor),
                ),
                Expanded(
                  child: _buildStatisticItem('缓存未命中', '168', AppTheme.warningColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatisticItem('命中率', '88.1%', AppTheme.primaryColor),
                ),
                Expanded(
                  child: _buildStatisticItem('平均响应', '12ms', AppTheme.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🎯 辅助方法

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityIndicator(NetworkQuality quality) {
    final qualityValue = _getQualityValue(quality);
    final color = _getQualityColor(quality);
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: qualityValue,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(qualityValue * 100).toInt()}%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncHistoryItem(String title, String status, String time, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildStatisticItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 状态获取方法
  String _getStatusSubtitle(bool isConnected, NetworkQuality quality) {
    if (!isConnected) return '设备离线';
    return '${_getNetworkQualityText(quality)} • 数据同步正常';
  }

  String _getConnectionStatusText(bool isConnected) {
    return isConnected ? '已连接' : '未连接';
  }

  String _getNetworkTypeText(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
        return 'WiFi';
      case NetworkType.mobile:
        return '移动网络';
      case NetworkType.ethernet:
        return '以太网';
      case NetworkType.vpn:
        return 'VPN';
      case NetworkType.bluetooth:
        return '蓝牙';
      case NetworkType.other:
        return '其他';
      case NetworkType.none:
        return '无连接';
    }
  }

  String _getNetworkQualityText(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return '优秀';
      case NetworkQuality.good:
        return '良好';
      case NetworkQuality.fair:
        return '一般';
      case NetworkQuality.poor:
        return '较差';
      case NetworkQuality.none:
        return '无连接';
    }
  }

  double _getQualityValue(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return 1.0;
      case NetworkQuality.good:
        return 0.8;
      case NetworkQuality.fair:
        return 0.6;
      case NetworkQuality.poor:
        return 0.3;
      case NetworkQuality.none:
        return 0.0;
    }
  }

  Color _getQualityColor(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
      case NetworkQuality.good:
        return AppTheme.successColor;
      case NetworkQuality.fair:
        return AppTheme.warningColor;
      case NetworkQuality.poor:
      case NetworkQuality.none:
        return AppTheme.errorColor;
    }
  }

  String _getQualityDescription(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return '网络连接优秀，所有功能正常运行。延迟低，稳定性高。';
      case NetworkQuality.good:
        return '网络连接良好，大部分功能正常运行。偶有轻微延迟。';
      case NetworkQuality.fair:
        return '网络连接一般，基础功能可用。可能存在延迟和不稳定。';
      case NetworkQuality.poor:
        return '网络连接较差，部分功能受限。建议检查网络设置。';
      case NetworkQuality.none:
        return '无网络连接，只能使用离线功能。';
    }
  }

  // 操作处理方法
  void _handleRefresh() {
    // TODO: 实现刷新逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在刷新状态...')),
    );
  }

  void _handleManualSync() {
    // TODO: 实现手动同步逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('开始手动同步...')),
    );
  }

  void _handleClearCache() {
    // TODO: 实现清理缓存逻辑
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text('确定要清理所有缓存数据吗？这不会影响您的个人数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清理')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}