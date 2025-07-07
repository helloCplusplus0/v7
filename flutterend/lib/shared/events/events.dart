import 'package:flutter/foundation.dart';

/// 应用事件基类
/// 
/// 所有应用事件都必须继承此类以确保类型安全
abstract class AppEvent {
  const AppEvent({
    this.timestamp,
  });
  
  final DateTime? timestamp;
  
  /// 获取事件时间戳，如果为null则返回当前时间
  DateTime get eventTime => timestamp ?? DateTime.now();
  
  @override
  String toString() => '${runtimeType}(timestamp: $timestamp)';
}

/// 用户相关事件
abstract class UserEvent extends AppEvent {
  const UserEvent({super.timestamp});
}

/// 用户登录事件
class UserLoginEvent extends UserEvent {
  const UserLoginEvent({
    required this.userId,
    required this.userName,
    this.loginMethod,
    super.timestamp,
  });
  
  final String userId;
  final String userName;
  final String? loginMethod;
  
  @override
  String toString() => 'UserLoginEvent(userId: $userId, userName: $userName, method: $loginMethod)';
}

/// 用户登出事件
class UserLogoutEvent extends UserEvent {
  const UserLogoutEvent({
    required this.userId,
    this.reason,
    super.timestamp,
  });
  
  final String userId;
  final String? reason;
  
  @override
  String toString() => 'UserLogoutEvent(userId: $userId, reason: $reason)';
}

/// 用户资料更新事件
class UserProfileUpdatedEvent extends UserEvent {
  const UserProfileUpdatedEvent({
    required this.userId,
    required this.updatedFields,
    super.timestamp,
  });
  
  final String userId;
  final Map<String, dynamic> updatedFields;
  
  @override
  String toString() => 'UserProfileUpdatedEvent(userId: $userId, fields: ${updatedFields.keys})';
}

/// 数据同步事件
abstract class DataSyncEvent extends AppEvent {
  const DataSyncEvent({super.timestamp});
}

/// 数据同步开始事件
class DataSyncStartedEvent extends DataSyncEvent {
  const DataSyncStartedEvent({
    required this.syncType,
    this.entityType,
    super.timestamp,
  });
  
  final String syncType;
  final String? entityType;
  
  @override
  String toString() => 'DataSyncStartedEvent(type: $syncType, entity: $entityType)';
}

/// 数据同步完成事件
class DataSyncCompletedEvent extends DataSyncEvent {
  const DataSyncCompletedEvent({
    required this.syncType,
    required this.success,
    this.syncedCount,
    this.failedCount,
    this.error,
    super.timestamp,
  });
  
  final String syncType;
  final bool success;
  final int? syncedCount;
  final int? failedCount;
  final String? error;
  
  @override
  String toString() => 'DataSyncCompletedEvent(type: $syncType, success: $success, synced: $syncedCount, failed: $failedCount)';
}

/// 网络状态事件
abstract class NetworkEvent extends AppEvent {
  const NetworkEvent({super.timestamp});
}

/// 网络连接状态变化事件
class NetworkConnectivityChangedEvent extends NetworkEvent {
  const NetworkConnectivityChangedEvent({
    required this.isConnected,
    required this.connectionType,
    super.timestamp,
  });
  
  final bool isConnected;
  final String connectionType; // wifi, cellular, none
  
  @override
  String toString() => 'NetworkConnectivityChangedEvent(connected: $isConnected, type: $connectionType)';
}

/// API请求事件
class ApiRequestEvent extends NetworkEvent {
  const ApiRequestEvent({
    required this.method,
    required this.endpoint,
    required this.statusCode,
    this.duration,
    this.error,
    super.timestamp,
  });
  
  final String method;
  final String endpoint;
  final int statusCode;
  final Duration? duration;
  final String? error;
  
  @override
  String toString() => 'ApiRequestEvent($method $endpoint -> $statusCode${duration != null ? ' (${duration!.inMilliseconds}ms)' : ''})';
}

/// 应用生命周期事件
abstract class AppLifecycleEvent extends AppEvent {
  const AppLifecycleEvent({super.timestamp});
}

/// 应用启动事件
class AppStartedEvent extends AppLifecycleEvent {
  const AppStartedEvent({
    this.coldStart = true,
    super.timestamp,
  });
  
  final bool coldStart;
  
  @override
  String toString() => 'AppStartedEvent(coldStart: $coldStart)';
}

/// 应用暂停事件
class AppPausedEvent extends AppLifecycleEvent {
  const AppPausedEvent({super.timestamp});
  
  @override
  String toString() => 'AppPausedEvent()';
}

/// 应用恢复事件
class AppResumedEvent extends AppLifecycleEvent {
  const AppResumedEvent({super.timestamp});
  
  @override
  String toString() => 'AppResumedEvent()';
}

/// 缓存事件
abstract class CacheEvent extends AppEvent {
  const CacheEvent({super.timestamp});
}

/// 缓存命中事件
class CacheHitEvent extends CacheEvent {
  const CacheHitEvent({
    required this.key,
    required this.cacheType,
    super.timestamp,
  });
  
  final String key;
  final String cacheType; // memory, disk
  
  @override
  String toString() => 'CacheHitEvent(key: $key, type: $cacheType)';
}

/// 缓存未命中事件
class CacheMissEvent extends CacheEvent {
  const CacheMissEvent({
    required this.key,
    required this.cacheType,
    super.timestamp,
  });
  
  final String key;
  final String cacheType;
  
  @override
  String toString() => 'CacheMissEvent(key: $key, type: $cacheType)';
}

/// 缓存清理事件
class CacheEvictedEvent extends CacheEvent {
  const CacheEvictedEvent({
    required this.key,
    required this.reason,
    super.timestamp,
  });
  
  final String key;
  final String reason; // expired, memory_pressure, manual
  
  @override
  String toString() => 'CacheEvictedEvent(key: $key, reason: $reason)';
}

/// 错误事件
abstract class ErrorEvent extends AppEvent {
  const ErrorEvent({super.timestamp});
}

/// 应用错误事件
class AppErrorEvent extends ErrorEvent {
  const AppErrorEvent({
    required this.error,
    required this.stackTrace,
    this.context,
    this.fatal = false,
    super.timestamp,
  });
  
  final Object error;
  final StackTrace stackTrace;
  final Map<String, dynamic>? context;
  final bool fatal;
  
  @override
  String toString() => 'AppErrorEvent(error: $error, fatal: $fatal)';
}

/// 事件总线错误事件
class EventBusErrorEvent extends ErrorEvent {
  const EventBusErrorEvent({
    required this.originalEvent,
    required this.error,
    required this.stackTrace,
    super.timestamp,
  });
  
  final AppEvent originalEvent;
  final Object error;
  final StackTrace stackTrace;
  
  @override
  String toString() => 'EventBusErrorEvent(originalEvent: ${originalEvent.runtimeType}, error: $error)';
}

/// 导航事件
abstract class NavigationEvent extends AppEvent {
  const NavigationEvent({super.timestamp});
}

/// 路由变化事件
class RouteChangedEvent extends NavigationEvent {
  const RouteChangedEvent({
    required this.from,
    required this.to,
    this.arguments,
    super.timestamp,
  });
  
  final String from;
  final String to;
  final Map<String, dynamic>? arguments;
  
  @override
  String toString() => 'RouteChangedEvent(from: $from, to: $to)';
}

/// 切片导航事件
class SliceNavigationEvent extends NavigationEvent {
  const SliceNavigationEvent({
    required this.sliceId,
    required this.action,
    this.data,
    super.timestamp,
  });
  
  final String sliceId;
  final String action; // open, close, navigate
  final Map<String, dynamic>? data;
  
  @override
  String toString() => 'SliceNavigationEvent(slice: $sliceId, action: $action)';
}

/// 性能事件
abstract class PerformanceEvent extends AppEvent {
  const PerformanceEvent({super.timestamp});
}

/// 性能指标事件
class PerformanceMetricEvent extends PerformanceEvent {
  const PerformanceMetricEvent({
    required this.metric,
    required this.value,
    required this.unit,
    this.context,
    super.timestamp,
  });
  
  final String metric; // frame_time, memory_usage, startup_time
  final double value;
  final String unit; // ms, mb, fps
  final Map<String, dynamic>? context;
  
  @override
  String toString() => 'PerformanceMetricEvent(metric: $metric, value: $value$unit)';
}

/// UI事件
abstract class UIEvent extends AppEvent {
  const UIEvent({super.timestamp});
}

/// 主题变化事件
class ThemeChangedEvent extends UIEvent {
  const ThemeChangedEvent({
    required this.themeMode,
    this.customTheme,
    super.timestamp,
  });
  
  final String themeMode; // light, dark, system
  final String? customTheme;
  
  @override
  String toString() => 'ThemeChangedEvent(mode: $themeMode, custom: $customTheme)';
}

/// 语言变化事件
class LanguageChangedEvent extends UIEvent {
  const LanguageChangedEvent({
    required this.languageCode,
    required this.countryCode,
    super.timestamp,
  });
  
  final String languageCode;
  final String? countryCode;
  
  @override
  String toString() => 'LanguageChangedEvent(language: $languageCode, country: $countryCode)';
}

/// 请求创建任务事件
class UIRequestCreateTaskEvent extends UIEvent {
  const UIRequestCreateTaskEvent({super.timestamp});
  
  @override
  String toString() => 'UIRequestCreateTaskEvent()';
}

/// 导航到切片事件
class UINavigateToSliceEvent extends UIEvent {
  const UINavigateToSliceEvent({
    required this.slice,
    super.timestamp,
  });
  
  final String slice;
  
  @override
  String toString() => 'UINavigateToSliceEvent(slice: $slice)';
}

/// 权限事件
abstract class PermissionEvent extends AppEvent {
  const PermissionEvent({super.timestamp});
}

/// 权限请求事件
class PermissionRequestEvent extends PermissionEvent {
  const PermissionRequestEvent({
    required this.permission,
    required this.granted,
    super.timestamp,
  });
  
  final String permission;
  final bool granted;
  
  @override
  String toString() => 'PermissionRequestEvent(permission: $permission, granted: $granted)';
}

/// 分析事件
abstract class AnalyticsEvent extends AppEvent {
  const AnalyticsEvent({super.timestamp});
}

/// 用户行为事件
class UserActionEvent extends AnalyticsEvent {
  const UserActionEvent({
    required this.action,
    required this.target,
    this.properties,
    super.timestamp,
  });
  
  final String action; // tap, swipe, scroll, etc.
  final String target; // button_id, screen_name, etc.
  final Map<String, dynamic>? properties;
  
  @override
  String toString() => 'UserActionEvent(action: $action, target: $target)';
}

/// 页面浏览事件
class PageViewEvent extends AnalyticsEvent {
  const PageViewEvent({
    required this.pageName,
    required this.duration,
    this.properties,
    super.timestamp,
  });
  
  final String pageName;
  final Duration duration;
  final Map<String, dynamic>? properties;
  
  @override
  String toString() => 'PageViewEvent(page: $pageName, duration: ${duration.inSeconds}s)';
}

/// 任务相关事件
abstract class TaskEvent extends AppEvent {
  const TaskEvent({super.timestamp});
}

/// 任务加载完成事件
class TasksLoadedEvent extends TaskEvent {
  const TasksLoadedEvent({
    required this.count,
    super.timestamp,
  });
  
  final int count;
  
  @override
  String toString() => 'TasksLoadedEvent(count: $count)';
}

/// 任务创建事件
class TaskCreatedEvent extends TaskEvent {
  const TaskCreatedEvent({
    required this.taskId,
    required this.title,
    super.timestamp,
  });
  
  final String taskId;
  final String title;
  
  @override
  String toString() => 'TaskCreatedEvent(id: $taskId, title: $title)';
}

/// 任务状态切换事件
class TaskToggledEvent extends TaskEvent {
  const TaskToggledEvent({
    required this.taskId,
    required this.isCompleted,
    super.timestamp,
  });
  
  final String taskId;
  final bool isCompleted;
  
  @override
  String toString() => 'TaskToggledEvent(id: $taskId, completed: $isCompleted)';
}

/// 任务删除事件
class TaskDeletedEvent extends TaskEvent {
  const TaskDeletedEvent({
    required this.taskId,
    super.timestamp,
  });
  
  final String taskId;
  
  @override
  String toString() => 'TaskDeletedEvent(id: $taskId)';
}

/// 任务错误事件
class TaskErrorEvent extends TaskEvent {
  const TaskErrorEvent({
    required this.error,
    super.timestamp,
  });
  
  final String error;
  
  @override
  String toString() => 'TaskErrorEvent(error: $error)';
}

/// Demo摘要刷新事件
class DemoSummaryRefreshedEvent extends AppEvent {
  const DemoSummaryRefreshedEvent({
    required this.totalTasks,
    required this.completedTasks,
    super.timestamp,
  });
  
  final int totalTasks;
  final int completedTasks;
  
  @override
  String toString() => 'DemoSummaryRefreshedEvent(total: $totalTasks, completed: $completedTasks)';
}





/// 自定义事件
class CustomEvent extends AppEvent {
  const CustomEvent({
    required this.name,
    this.data,
    super.timestamp,
  });
  
  final String name;
  final Map<String, dynamic>? data;
  
  @override
  String toString() => 'CustomEvent(name: $name, data: $data)';
}

/// 事件工厂
class EventFactory {
  /// 创建用户登录事件
  static UserLoginEvent userLogin({
    required String userId,
    required String userName,
    String? loginMethod,
  }) {
    return UserLoginEvent(
      userId: userId,
      userName: userName,
      loginMethod: loginMethod,
    );
  }
  
  /// 创建用户登出事件
  static UserLogoutEvent userLogout({
    required String userId,
    String? reason,
  }) {
    return UserLogoutEvent(
      userId: userId,
      reason: reason,
    );
  }
  
  /// 创建网络连接变化事件
  static NetworkConnectivityChangedEvent networkConnectivityChanged({
    required bool isConnected,
    required String connectionType,
  }) {
    return NetworkConnectivityChangedEvent(
      isConnected: isConnected,
      connectionType: connectionType,
    );
  }
  
  /// 创建API请求事件
  static ApiRequestEvent apiRequest({
    required String method,
    required String endpoint,
    required int statusCode,
    Duration? duration,
    String? error,
  }) {
    return ApiRequestEvent(
      method: method,
      endpoint: endpoint,
      statusCode: statusCode,
      duration: duration,
      error: error,
    );
  }
  
  /// 创建应用错误事件
  static AppErrorEvent appError({
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
    bool fatal = false,
  }) {
    return AppErrorEvent(
      error: error,
      stackTrace: stackTrace,
      context: context,
      fatal: fatal,
    );
  }
  
  /// 创建用户行为事件
  static UserActionEvent userAction({
    required String action,
    required String target,
    Map<String, dynamic>? properties,
  }) {
    return UserActionEvent(
      action: action,
      target: target,
      properties: properties,
    );
  }
  
  /// 创建性能指标事件
  static PerformanceMetricEvent performanceMetric({
    required String metric,
    required double value,
    required String unit,
    Map<String, dynamic>? context,
  }) {
    return PerformanceMetricEvent(
      metric: metric,
      value: value,
      unit: unit,
      context: context,
    );
  }
  
  /// 创建自定义事件
  static CustomEvent custom({
    required String name,
    Map<String, dynamic>? data,
  }) {
    return CustomEvent(
      name: name,
      data: data,
    );
  }
}

/// 事件类型检查工具
class EventTypeUtils {
  /// 检查是否为用户事件
  static bool isUserEvent(AppEvent event) => event is UserEvent;
  
  /// 检查是否为网络事件
  static bool isNetworkEvent(AppEvent event) => event is NetworkEvent;
  
  /// 检查是否为错误事件
  static bool isErrorEvent(AppEvent event) => event is ErrorEvent;
  
  /// 检查是否为性能事件
  static bool isPerformanceEvent(AppEvent event) => event is PerformanceEvent;
  
  /// 检查是否为分析事件
  static bool isAnalyticsEvent(AppEvent event) => event is AnalyticsEvent;
  
  /// 获取事件类别
  static String getEventCategory(AppEvent event) {
    if (event is UserEvent) return 'user';
    if (event is NetworkEvent) return 'network';
    if (event is DataSyncEvent) return 'data_sync';
    if (event is AppLifecycleEvent) return 'app_lifecycle';
    if (event is CacheEvent) return 'cache';
    if (event is ErrorEvent) return 'error';
    if (event is NavigationEvent) return 'navigation';
    if (event is PerformanceEvent) return 'performance';
    if (event is UIEvent) return 'ui';
    if (event is PermissionEvent) return 'permission';
    if (event is AnalyticsEvent) return 'analytics';
    if (event is CustomEvent) return 'custom';
    return 'unknown';
  }
} 