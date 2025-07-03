import 'package:flutter/material.dart';

/// 切片状态枚举
enum SliceStatus {
  running,  // 运行中
  warning,  // 警告
  error,    // 错误
  stopped,  // 已停止
}

/// 指标趋势枚举
enum MetricTrend {
  up,       // 上升
  down,     // 下降
  stable,   // 稳定
}

/// 切片状态信息
class StatusInfo {
  const StatusInfo({
    required this.icon,
    required this.text,
    required this.color,
  });

  final String icon;
  final String text;
  final Color color;

  /// 根据状态创建状态信息
  factory StatusInfo.fromStatus(SliceStatus status) {
    switch (status) {
      case SliceStatus.running:
        return const StatusInfo(
          icon: '🟢',
          text: '运行中',
          color: Colors.green,
        );
      case SliceStatus.warning:
        return const StatusInfo(
          icon: '🟡',
          text: '警告',
          color: Colors.orange,
        );
      case SliceStatus.error:
        return const StatusInfo(
          icon: '🔴',
          text: '异常',
          color: Colors.red,
        );
      case SliceStatus.stopped:
        return const StatusInfo(
          icon: '⚫',
          text: '已停止',
          color: Colors.grey,
        );
    }
  }
}

/// 指标信息
class MetricInfo {
  const MetricInfo({
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
  });

  final String label;    // 指标标签
  final String value;    // 指标数值
  final MetricTrend trend; // 趋势
  final IconData icon;   // 图标

  /// 获取趋势图标
  IconData get trendIcon {
    switch (trend) {
      case MetricTrend.up:
        return Icons.trending_up;
      case MetricTrend.down:
        return Icons.trending_down;
      case MetricTrend.stable:
        return Icons.trending_flat;
    }
  }

  /// 获取趋势颜色
  Color get trendColor {
    switch (trend) {
      case MetricTrend.up:
        return Colors.green;
      case MetricTrend.down:
        return Colors.red;
      case MetricTrend.stable:
        return Colors.grey;
    }
  }
}

/// 切片信息模型
/// v7架构中功能切片的元数据描述
class SliceInfo {
  final String id;              // 切片唯一标识
  final String title;           // 切片标题
  final String description;     // 切片描述
  final String category;        // 切片分类
  final String author;          // 作者
  final String version;         // 版本号
  final Color iconColor;        // 图标颜色
  final String routePath;       // 路由路径

  const SliceInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.author,
    required this.version,
    required this.iconColor,
    required this.routePath,
  });

  /// 复制并修改
  SliceInfo copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? author,
    String? version,
    Color? iconColor,
    String? routePath,
  }) {
    return SliceInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      author: author ?? this.author,
      version: version ?? this.version,
      iconColor: iconColor ?? this.iconColor,
      routePath: routePath ?? this.routePath,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SliceInfo &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.category == category &&
        other.author == author &&
        other.version == version &&
        other.iconColor == iconColor &&
        other.routePath == routePath;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      description,
      category,
      author,
      version,
      iconColor,
      routePath,
    );
  }

  @override
  String toString() {
    return 'SliceInfo(id: $id, title: $title, category: $category, version: $version)';
  }
} 