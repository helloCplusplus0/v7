/// 切片摘要契约接口
/// 参考 web/src/shared/types.ts 的 SliceSummaryContract 设计
/// 
/// 为切片提供摘要信息，支持：
/// - 实时状态和指标数据
/// - 自定义操作按钮
/// - 错误处理和重试机制

import 'package:flutter/foundation.dart';
import '../sync/offline_queue.dart';
import '../sync/sync_manager.dart';

/// 切片状态枚举
enum SliceStatus {
  healthy,  // 运行正常
  warning,  // 有警告
  error,    // 错误状态
  loading,  // 加载中
}

/// 切片指标
@immutable
class SliceMetric {
  const SliceMetric({
    required this.label,
    required this.value,
    this.trend,
    this.icon,
    this.unit,
  });

  final String label;
  final dynamic value;  // 支持 String、int、double 等类型
  final String? trend;  // 'up', 'down', 'stable', 'warning'
  final String? icon;   // emoji 图标
  final String? unit;   // 单位

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SliceMetric &&
        other.label == label &&
        other.value == value &&
        other.trend == trend &&
        other.icon == icon &&
        other.unit == unit;
  }

  @override
  int get hashCode {
    return Object.hash(label, value, trend, icon, unit);
  }

  @override
  String toString() {
    return 'SliceMetric(label: $label, value: $value, trend: $trend, icon: $icon, unit: $unit)';
  }
}

/// 切片操作
@immutable
class SliceAction {
  const SliceAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = SliceActionVariant.secondary,
  });

  final String label;
  final VoidCallback onPressed;
  final String? icon;  // emoji 图标
  final SliceActionVariant variant;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SliceAction &&
        other.label == label &&
        other.icon == icon &&
        other.variant == variant;
  }

  @override
  int get hashCode {
    return Object.hash(label, icon, variant);
  }

  @override
  String toString() {
    return 'SliceAction(label: $label, icon: $icon, variant: $variant)';
  }
}

/// 切片操作变体
enum SliceActionVariant {
  primary,    // 主要操作
  secondary,  // 次要操作
  danger,     // 危险操作
}

/// 后端服务健康状态
enum BackendHealthStatus {
  /// 健康 - 所有API都可用
  healthy,
  /// 警告 - 部分API可用或响应较慢
  warning,
  /// 错误 - 后端不可达或API失败
  error,
  /// 检查中 - 正在检查状态
  checking,
  /// 未知 - 尚未检查
  unknown,
}

/// 后端服务信息
class BackendServiceInfo {
  const BackendServiceInfo({
    required this.name,
    required this.baseUrl,
    required this.status,
    this.responseTime,
    this.lastCheckTime,
    this.errorMessage,
    this.checkedEndpoints = const [],
  });

  /// 后端服务名称
  final String name;
  /// 后端基础URL
  final String baseUrl;
  /// 健康状态
  final BackendHealthStatus status;
  /// 响应时间（毫秒）
  final int? responseTime;
  /// 最后检查时间
  final DateTime? lastCheckTime;
  /// 错误信息
  final String? errorMessage;
  /// 已检查的端点列表
  final List<String> checkedEndpoints;

  /// 是否可用
  bool get isAvailable => status == BackendHealthStatus.healthy || status == BackendHealthStatus.warning;

  /// 用户友好的状态描述
  String get statusDescription {
    switch (status) {
      case BackendHealthStatus.healthy:
        return '服务正常';
      case BackendHealthStatus.warning:
        return '服务异常';
      case BackendHealthStatus.error:
        return '服务不可用';
      case BackendHealthStatus.checking:
        return '检查中...';
      case BackendHealthStatus.unknown:
        return '未知状态';
    }
  }

  BackendServiceInfo copyWith({
    String? name,
    String? baseUrl,
    BackendHealthStatus? status,
    int? responseTime,
    DateTime? lastCheckTime,
    String? errorMessage,
    List<String>? checkedEndpoints,
  }) {
    return BackendServiceInfo(
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      status: status ?? this.status,
      responseTime: responseTime ?? this.responseTime,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      errorMessage: errorMessage ?? this.errorMessage,
      checkedEndpoints: checkedEndpoints ?? this.checkedEndpoints,
    );
  }
}

/// 切片同步配置
class SliceSyncConfig {
  const SliceSyncConfig({
    this.enableBackgroundSync = false,
    this.syncInterval = const Duration(minutes: 15),
    this.syncOnNetworkRecover = true,
    this.syncOnAppResume = true,
    this.maxRetryAttempts = 3,
    this.syncPriority = OperationPriority.normal,
    this.syncTypes = const [],
    this.conflictResolution = ConflictResolution.useLocal,
  });

  /// 是否启用后台同步
  final bool enableBackgroundSync;
  /// 同步间隔
  final Duration syncInterval;
  /// 网络恢复时是否同步
  final bool syncOnNetworkRecover;
  /// 应用恢复时是否同步
  final bool syncOnAppResume;
  /// 最大重试次数
  final int maxRetryAttempts;
  /// 同步优先级
  final OperationPriority syncPriority;
  /// 同步的数据类型
  final List<String> syncTypes;
  /// 冲突解决策略
  final ConflictResolution conflictResolution;

  SliceSyncConfig copyWith({
    bool? enableBackgroundSync,
    Duration? syncInterval,
    bool? syncOnNetworkRecover,
    bool? syncOnAppResume,
    int? maxRetryAttempts,
    OperationPriority? syncPriority,
    List<String>? syncTypes,
    ConflictResolution? conflictResolution,
  }) {
    return SliceSyncConfig(
      enableBackgroundSync: enableBackgroundSync ?? this.enableBackgroundSync,
      syncInterval: syncInterval ?? this.syncInterval,
      syncOnNetworkRecover: syncOnNetworkRecover ?? this.syncOnNetworkRecover,
      syncOnAppResume: syncOnAppResume ?? this.syncOnAppResume,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      syncPriority: syncPriority ?? this.syncPriority,
      syncTypes: syncTypes ?? this.syncTypes,
      conflictResolution: conflictResolution ?? this.conflictResolution,
    );
  }
}

/// 切片同步状态
enum SliceSyncStatus {
  /// 空闲状态
  idle,
  /// 同步中
  syncing,
  /// 同步成功
  success,
  /// 同步失败
  failed,
  /// 同步暂停
  paused,
}

/// 切片同步信息
class SliceSyncInfo {
  const SliceSyncInfo({
    required this.status,
    this.lastSyncTime,
    this.nextSyncTime,
    this.syncProgress,
    this.error,
    this.syncedItemCount = 0,
    this.totalItemCount = 0,
    this.conflictCount = 0,
  });

  /// 同步状态
  final SliceSyncStatus status;
  /// 最后同步时间
  final DateTime? lastSyncTime;
  /// 下次同步时间
  final DateTime? nextSyncTime;
  /// 同步进度 (0.0 - 1.0)
  final double? syncProgress;
  /// 错误信息
  final String? error;
  /// 已同步项目数量
  final int syncedItemCount;
  /// 总项目数量
  final int totalItemCount;
  /// 冲突数量
  final int conflictCount;

  /// 是否正在同步
  bool get isSyncing => status == SliceSyncStatus.syncing;
  
  /// 是否有错误
  bool get hasError => error != null;
  
  /// 是否有冲突
  bool get hasConflicts => conflictCount > 0;

  /// 同步成功率
  double get syncSuccessRate {
    if (totalItemCount == 0) return 1.0;
    return syncedItemCount / totalItemCount;
  }

  /// 用户友好的状态描述
  String get statusDescription {
    switch (status) {
      case SliceSyncStatus.idle:
        return '待同步';
      case SliceSyncStatus.syncing:
        return '同步中';
      case SliceSyncStatus.success:
        return '同步成功';
      case SliceSyncStatus.failed:
        return '同步失败';
      case SliceSyncStatus.paused:
        return '已暂停';
    }
  }

  SliceSyncInfo copyWith({
    SliceSyncStatus? status,
    DateTime? lastSyncTime,
    DateTime? nextSyncTime,
    double? syncProgress,
    String? error,
    int? syncedItemCount,
    int? totalItemCount,
    int? conflictCount,
  }) {
    return SliceSyncInfo(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      nextSyncTime: nextSyncTime ?? this.nextSyncTime,
      syncProgress: syncProgress ?? this.syncProgress,
      error: error,
      syncedItemCount: syncedItemCount ?? this.syncedItemCount,
      totalItemCount: totalItemCount ?? this.totalItemCount,
      conflictCount: conflictCount ?? this.conflictCount,
    );
  }
}

/// 切片摘要契约
@immutable
class SliceSummaryContract {
  const SliceSummaryContract({
    required this.title,
    required this.status,
    required this.metrics,
    this.description,
    this.lastUpdated,
    this.alertCount = 0,
    this.customActions = const [],
    this.backendService,
    this.syncConfig, // 新增：同步配置
    this.syncInfo,   // 新增：同步信息
  });

  final String title;
  final SliceStatus status;
  final List<SliceMetric> metrics;
  final String? description;
  final DateTime? lastUpdated;
  final int alertCount;
  final List<SliceAction> customActions;
  final BackendServiceInfo? backendService;
  final SliceSyncConfig? syncConfig;
  final SliceSyncInfo? syncInfo;

  /// 是否有警告
  bool get hasWarnings => alertCount > 0;

  /// 是否有后端服务信息
  bool get hasBackendService => backendService != null;

  /// 后端是否可用
  bool get isBackendAvailable => backendService?.isAvailable ?? true;

  /// 是否启用了后台同步
  bool get hasBackgroundSync => syncConfig?.enableBackgroundSync ?? false;

  /// 是否正在同步
  bool get isSyncing => syncInfo?.isSyncing ?? false;

  /// 是否有同步错误
  bool get hasSyncError => syncInfo?.hasError ?? false;

  /// 综合状态（考虑后端状态和同步状态）
  SliceStatus get overallStatus {
    // 优先级：同步错误 > 后端不可用 > 原始状态
    if (hasSyncError) {
      return SliceStatus.error;
    }
    if (backendService != null && !isBackendAvailable) {
      return SliceStatus.error;
    }
    if (isSyncing) {
      return SliceStatus.loading;
    }
    return status;
  }

  /// 创建副本
  SliceSummaryContract copyWith({
    String? title,
    SliceStatus? status,
    List<SliceMetric>? metrics,
    String? description,
    DateTime? lastUpdated,
    int? alertCount,
    List<SliceAction>? customActions,
    BackendServiceInfo? backendService,
    SliceSyncConfig? syncConfig,
    SliceSyncInfo? syncInfo,
  }) {
    return SliceSummaryContract(
      title: title ?? this.title,
      status: status ?? this.status,
      metrics: metrics ?? this.metrics,
      description: description ?? this.description,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      alertCount: alertCount ?? this.alertCount,
      customActions: customActions ?? this.customActions,
      backendService: backendService ?? this.backendService,
      syncConfig: syncConfig ?? this.syncConfig,
      syncInfo: syncInfo ?? this.syncInfo,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SliceSummaryContract &&
        other.title == title &&
        other.status == status &&
        listEquals(other.metrics, metrics) &&
        other.description == description &&
        other.lastUpdated == lastUpdated &&
        other.alertCount == alertCount &&
        listEquals(other.customActions, customActions) &&
        other.backendService == backendService &&
        other.syncConfig == syncConfig &&
        other.syncInfo == syncInfo;
  }

  @override
  int get hashCode {
    return Object.hash(
      title,
      status,
      Object.hashAll(metrics),
      description,
      lastUpdated,
      alertCount,
      Object.hashAll(customActions),
      backendService,
      syncConfig,
      syncInfo,
    );
  }

  @override
  String toString() {
    return 'SliceSummaryContract(title: $title, status: $status, metrics: $metrics, description: $description, lastUpdated: $lastUpdated, alertCount: $alertCount, customActions: $customActions, backendService: $backendService, syncConfig: $syncConfig, syncInfo: $syncInfo)';
  }
}

/// 切片摘要提供者接口
abstract class SliceSummaryProvider {
  /// 获取摘要数据
  Future<SliceSummaryContract> getSummaryData();

  /// 刷新数据（可选实现）
  Future<void> refreshData() async {
    // 默认空实现
  }

  /// 启动后台同步（可选实现）
  Future<void> startBackgroundSync() async {
    // 默认空实现
  }

  /// 停止后台同步（可选实现）
  Future<void> stopBackgroundSync() async {
    // 默认空实现
  }

  /// 手动触发同步（可选实现）
  Future<void> triggerSync() async {
    // 默认空实现
  }

  /// 获取同步状态流（可选实现）
  Stream<SliceSyncInfo>? get syncStatusStream => null;

  /// 释放资源（可选实现）
  void dispose() {
    // 默认空实现
  }
}

/// 切片注册信息
@immutable
class SliceRegistration {
  const SliceRegistration({
    required this.name,
    required this.displayName,
    required this.routePath,
    this.description,
    this.version,
    this.summaryProvider,
    this.iconColor,
    this.category,
    this.author,
  });

  final String name;
  final String displayName;
  final String routePath;
  final String? description;
  final String? version;
  final SliceSummaryProvider? summaryProvider;
  final int? iconColor;  // Material Color value
  final String? category;
  final String? author;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SliceRegistration &&
        other.name == name &&
        other.displayName == displayName &&
        other.routePath == routePath &&
        other.description == description &&
        other.version == version &&
        other.iconColor == iconColor &&
        other.category == category &&
        other.author == author;
  }

  @override
  int get hashCode {
    return Object.hash(
      name,
      displayName,
      routePath,
      description,
      version,
      iconColor,
      category,
      author,
    );
  }

  @override
  String toString() {
    return 'SliceRegistration(name: $name, displayName: $displayName, routePath: $routePath, description: $description, version: $version, iconColor: $iconColor, category: $category, author: $author)';
  }
} 