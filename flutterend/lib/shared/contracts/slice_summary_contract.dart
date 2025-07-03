/// 切片摘要契约接口
/// 参考 web/src/shared/types.ts 的 SliceSummaryContract 设计
/// 
/// 为切片提供摘要信息，支持：
/// - 实时状态和指标数据
/// - 自定义操作按钮
/// - 错误处理和重试机制

import 'package:flutter/foundation.dart';

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
  });

  final String title;
  final SliceStatus status;
  final List<SliceMetric> metrics;
  final String? description;
  final DateTime? lastUpdated;
  final int alertCount;
  final List<SliceAction> customActions;

  /// 创建副本
  SliceSummaryContract copyWith({
    String? title,
    SliceStatus? status,
    List<SliceMetric>? metrics,
    String? description,
    DateTime? lastUpdated,
    int? alertCount,
    List<SliceAction>? customActions,
  }) {
    return SliceSummaryContract(
      title: title ?? this.title,
      status: status ?? this.status,
      metrics: metrics ?? this.metrics,
      description: description ?? this.description,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      alertCount: alertCount ?? this.alertCount,
      customActions: customActions ?? this.customActions,
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
        listEquals(other.customActions, customActions);
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
    );
  }

  @override
  String toString() {
    return 'SliceSummaryContract(title: $title, status: $status, metrics: $metrics, description: $description, lastUpdated: $lastUpdated, alertCount: $alertCount, customActions: $customActions)';
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