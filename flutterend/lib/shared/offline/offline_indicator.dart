// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/network_monitor.dart';
import '../network/api_client.dart';
import '../events/events.dart';
import '../events/event_bus.dart';

/// 后端服务健康状态
class BackendHealthStatus {
  const BackendHealthStatus({
    required this.backendName,
    required this.isHealthy,
    this.responseTime,
    this.lastCheckTime,
    this.error,
  });

  final String backendName;
  final bool isHealthy;
  final Duration? responseTime;
  final DateTime? lastCheckTime;
  final String? error;

  BackendHealthStatus copyWith({
    String? backendName,
    bool? isHealthy,
    Duration? responseTime,
    DateTime? lastCheckTime,
    String? error,
  }) {
    return BackendHealthStatus(
      backendName: backendName ?? this.backendName,
      isHealthy: isHealthy ?? this.isHealthy,
      responseTime: responseTime ?? this.responseTime,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      error: error ?? this.error,
    );
  }
}

/// 服务可用性状态枚举
enum ServiceAvailability {
  /// 服务完全可用
  available,
  /// 服务部分可用（某些API可用）
  degraded,
  /// 服务不可用
  unavailable,
  /// 服务维护中
  maintenance,
  /// 检测中
  checking,
  /// 未知状态
  unknown,
}

/// 应用运行模式枚举
enum AppOperationMode {
  /// 在线模式：网络连接正常 + backend/服务可用
  online,
  /// 服务离线模式：有网络连接但backend/不可用
  serviceOffline,
  /// 完全离线模式：无网络连接
  fullyOffline,
  /// 混合模式：网络不稳定或服务部分可用
  hybrid,
}

/// 离线原因枚举
enum OfflineReason {
  /// 无网络连接
  noNetwork,
  /// 网络连接不稳定
  unstableNetwork,
  /// Backend服务不可达
  serviceUnavailable,
  /// Backend服务响应超时
  serviceTimeout,
  /// Backend服务返回错误
  serviceError,
  /// 用户手动设置离线模式
  userChoice,
  /// 系统维护
  maintenance,
}

/// 离线状态详情
@immutable
class OfflineStatus {
  const OfflineStatus({
    required this.operationMode,
    required this.serviceAvailability,
    required this.isOffline,
    this.reason,
    this.lastOnlineTime,
    this.lastServiceCheckTime,
    this.serviceCheckInterval = const Duration(minutes: 2),
    this.serviceResponseTime,
    this.offlineDuration = Duration.zero,
    this.canRetry = true,
    this.retryCount = 0,
    this.maxRetryCount = 3,
    this.nextRetryTime,
    this.userMessage,
    this.technicalDetails,
    this.backendHealthStatuses = const {},
  });

  /// 应用运行模式
  final AppOperationMode operationMode;
  /// 服务可用性
  final ServiceAvailability serviceAvailability;
  /// 是否处于离线状态
  final bool isOffline;
  /// 离线原因
  final OfflineReason? reason;
  /// 最后在线时间
  final DateTime? lastOnlineTime;
  /// 最后服务检查时间
  final DateTime? lastServiceCheckTime;
  /// 服务检查间隔
  final Duration serviceCheckInterval;
  /// 服务响应时间
  final Duration? serviceResponseTime;
  /// 离线持续时间
  final Duration offlineDuration;
  /// 是否可以重试
  final bool canRetry;
  /// 重试次数
  final int retryCount;
  /// 最大重试次数
  final int maxRetryCount;
  /// 下次重试时间
  final DateTime? nextRetryTime;
  /// 用户友好的消息
  final String? userMessage;
  /// 技术详情
  final String? technicalDetails;
  /// 各后端服务健康状态
  final Map<String, BackendHealthStatus> backendHealthStatuses;

  /// 是否需要显示离线指示器
  bool get shouldShowIndicator {
    return isOffline || operationMode == AppOperationMode.serviceOffline;
  }

  /// 是否可以进行数据同步
  bool get canSync {
    return operationMode == AppOperationMode.online || 
           (operationMode == AppOperationMode.hybrid && 
            serviceAvailability == ServiceAvailability.degraded);
  }

  /// 是否应该使用离线队列
  bool get shouldUseOfflineQueue {
    return isOffline || !canSync;
  }

  /// 获取健康的后端数量
  int get healthyBackendCount {
    return backendHealthStatuses.values.where((status) => status.isHealthy).length;
  }

  /// 获取总后端数量
  int get totalBackendCount => backendHealthStatuses.length;

  /// 检查指定后端是否健康
  bool isBackendHealthy(String backendName) {
    return backendHealthStatuses[backendName]?.isHealthy ?? false;
  }

  /// 获取用户友好的状态描述
  String get userFriendlyMessage {
    if (userMessage != null) return userMessage!;
    
    return switch (operationMode) {
      AppOperationMode.online => '在线',
      AppOperationMode.serviceOffline => '服务连接异常',
      AppOperationMode.fullyOffline => '离线模式',
      AppOperationMode.hybrid => '网络不稳定',
    };
  }

  /// 获取详细的状态说明
  String get detailedMessage {
    final buffer = StringBuffer();
    buffer.write(userFriendlyMessage);
    
    if (reason != null) {
      final reasonText = switch (reason!) {
        OfflineReason.noNetwork => '无网络连接',
        OfflineReason.unstableNetwork => '网络连接不稳定',
        OfflineReason.serviceUnavailable => '服务器无法连接',
        OfflineReason.serviceTimeout => '服务器响应超时',
        OfflineReason.serviceError => '服务器错误',
        OfflineReason.userChoice => '用户设置离线模式',
        OfflineReason.maintenance => '系统维护中',
      };
      buffer.write(' - $reasonText');
    }
    
    if (offlineDuration > Duration.zero) {
      final duration = _formatDuration(offlineDuration);
      buffer.write(' (已离线 $duration)');
    }
    
    return buffer.toString();
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}天';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}小时';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}分钟';
    } else {
      return '${duration.inSeconds}秒';
    }
  }

  OfflineStatus copyWith({
    AppOperationMode? operationMode,
    ServiceAvailability? serviceAvailability,
    bool? isOffline,
    OfflineReason? reason,
    DateTime? lastOnlineTime,
    DateTime? lastServiceCheckTime,
    Duration? serviceCheckInterval,
    Duration? serviceResponseTime,
    Duration? offlineDuration,
    bool? canRetry,
    int? retryCount,
    int? maxRetryCount,
    DateTime? nextRetryTime,
    String? userMessage,
    String? technicalDetails,
    Map<String, BackendHealthStatus>? backendHealthStatuses,
  }) {
    return OfflineStatus(
      operationMode: operationMode ?? this.operationMode,
      serviceAvailability: serviceAvailability ?? this.serviceAvailability,
      isOffline: isOffline ?? this.isOffline,
      reason: reason ?? this.reason,
      lastOnlineTime: lastOnlineTime ?? this.lastOnlineTime,
      lastServiceCheckTime: lastServiceCheckTime ?? this.lastServiceCheckTime,
      serviceCheckInterval: serviceCheckInterval ?? this.serviceCheckInterval,
      serviceResponseTime: serviceResponseTime ?? this.serviceResponseTime,
      offlineDuration: offlineDuration ?? this.offlineDuration,
      canRetry: canRetry ?? this.canRetry,
      retryCount: retryCount ?? this.retryCount,
      maxRetryCount: maxRetryCount ?? this.maxRetryCount,
      nextRetryTime: nextRetryTime ?? this.nextRetryTime,
      userMessage: userMessage ?? this.userMessage,
      technicalDetails: technicalDetails ?? this.technicalDetails,
      backendHealthStatuses: backendHealthStatuses ?? this.backendHealthStatuses,
    );
  }
}

/// 离线指示器抽象基类
/// 为不同使用场景提供统一接口
abstract class BaseOfflineIndicator extends StateNotifier<OfflineStatus> {
  BaseOfflineIndicator() : super(const OfflineStatus(
    operationMode: AppOperationMode.online,
    serviceAvailability: ServiceAvailability.checking,
    isOffline: false,
  ));

  /// 开始监控
  Future<void> startMonitoring();

  /// 停止监控
  Future<void> stopMonitoring();

  /// 手动检查状态
  Future<void> checkStatus();

  /// 获取监控的后端列表
  List<String> get monitoredBackends;
}

/// 切片级别的离线指示器
/// 允许切片指定特定的后端和健康检查端点
class SliceOfflineIndicator extends BaseOfflineIndicator {
  SliceOfflineIndicator({
    required this.sliceName,
    required this.backendName,
    this.customHealthEndpoint,
    this.checkInterval = const Duration(minutes: 2),
  });

  final String sliceName;
  final String backendName;
  final String? customHealthEndpoint;
  final Duration checkInterval;

  Timer? _checkTimer;
  late final ApiClient _apiClient;

  @override
  List<String> get monitoredBackends => [backendName];

  @override
  Future<void> startMonitoring() async {
    _apiClient = ApiClientFactory.getClient(backendName);
    
    // 立即检查一次
    await checkStatus();
    
    // 定期检查
    _checkTimer = Timer.periodic(checkInterval, (_) => checkStatus());
  }

  @override
  Future<void> stopMonitoring() async {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  @override
  Future<void> checkStatus() async {
    try {
      final isHealthy = await _checkBackendHealth();
      final now = DateTime.now();
      
      final healthStatus = BackendHealthStatus(
        backendName: backendName,
        isHealthy: isHealthy,
        lastCheckTime: now,
        responseTime: null, // 可以在实际实现中测量
      );

      final operationMode = isHealthy 
          ? AppOperationMode.online 
          : AppOperationMode.serviceOffline;

      state = state.copyWith(
        operationMode: operationMode,
        serviceAvailability: isHealthy 
            ? ServiceAvailability.available 
            : ServiceAvailability.unavailable,
        isOffline: !isHealthy,
        reason: isHealthy ? null : OfflineReason.serviceUnavailable,
        lastServiceCheckTime: now,
        backendHealthStatuses: {backendName: healthStatus},
      );
    } catch (e) {
      // 处理检查失败
      state = state.copyWith(
        operationMode: AppOperationMode.serviceOffline,
        serviceAvailability: ServiceAvailability.unavailable,
        isOffline: true,
        reason: OfflineReason.serviceUnavailable,
        technicalDetails: e.toString(),
      );
    }
  }

  Future<bool> _checkBackendHealth() async {
    if (customHealthEndpoint != null) {
      // 使用自定义健康检查端点
      try {
        await _apiClient.get(customHealthEndpoint!);
        return true;
      } catch (e) {
        return false;
      }
    } else {
      // 使用默认健康检查
      return await _apiClient.healthCheck();
    }
  }
}

/// 全局离线指示器
/// 监控默认后端服务
class GlobalOfflineIndicator extends BaseOfflineIndicator {
  GlobalOfflineIndicator({
    this.checkInterval = const Duration(minutes: 2),
  });

  final Duration checkInterval;
  Timer? _checkTimer;

  @override
  List<String> get monitoredBackends => ['default'];

  @override
  Future<void> startMonitoring() async {
    // 立即检查一次
    await checkStatus();
    
    // 定期检查
    _checkTimer = Timer.periodic(checkInterval, (_) => checkStatus());
  }

  @override
  Future<void> stopMonitoring() async {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  @override
  Future<void> checkStatus() async {
    try {
      final client = ApiClientFactory.getClient();
      final isHealthy = await client.healthCheck();
      final now = DateTime.now();
      
      final healthStatus = BackendHealthStatus(
        backendName: 'default',
        isHealthy: isHealthy,
        lastCheckTime: now,
      );

      ServiceAvailability serviceAvailability;
      AppOperationMode operationMode;
      bool isOffline;
      OfflineReason? reason;

      if (isHealthy) {
        serviceAvailability = ServiceAvailability.available;
        operationMode = AppOperationMode.online;
        isOffline = false;
        reason = null;
      } else {
        serviceAvailability = ServiceAvailability.unavailable;
        operationMode = AppOperationMode.serviceOffline;
        isOffline = true;
        reason = OfflineReason.serviceUnavailable;
      }

      state = state.copyWith(
        operationMode: operationMode,
        serviceAvailability: serviceAvailability,
        isOffline: isOffline,
        reason: reason,
        lastServiceCheckTime: now,
        backendHealthStatuses: {'default': healthStatus},
      );
    } catch (e) {
      // 处理检查失败
      state = state.copyWith(
        operationMode: AppOperationMode.serviceOffline,
        serviceAvailability: ServiceAvailability.unavailable,
        isOffline: true,
        reason: OfflineReason.serviceUnavailable,
        technicalDetails: e.toString(),
      );
    }
  }
}

/// 创建切片级别的离线指示器Provider
StateNotifierProvider<SliceOfflineIndicator, OfflineStatus> createSliceOfflineProvider({
  required String sliceName,
  required String backendName,
  String? customHealthEndpoint,
  Duration checkInterval = const Duration(minutes: 2),
}) {
  return StateNotifierProvider<SliceOfflineIndicator, OfflineStatus>((ref) {
    final indicator = SliceOfflineIndicator(
      sliceName: sliceName,
      backendName: backendName,
      customHealthEndpoint: customHealthEndpoint,
      checkInterval: checkInterval,
    );
    
    // 自动开始监控
    indicator.startMonitoring();
    
    // 在dispose时停止监控
    ref.onDispose(() {
      indicator.stopMonitoring();
    });
    
    return indicator;
  });
}

/// 全局离线指示器Provider
final globalOfflineProvider = StateNotifierProvider<GlobalOfflineIndicator, OfflineStatus>((ref) {
  final indicator = GlobalOfflineIndicator();
  
  // 自动开始监控
  indicator.startMonitoring();
  
  // 在dispose时停止监控
  ref.onDispose(() {
    indicator.stopMonitoring();
  });
  
  return indicator;
});

/// 默认离线状态提供器（向后兼容）
final offlineIndicatorProvider = globalOfflineProvider;

/// 快捷访问提供器
final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(offlineIndicatorProvider.select((state) => state.isOffline));
});

final canSyncProvider = Provider<bool>((ref) {
  return ref.watch(offlineIndicatorProvider.select((state) => state.canSync));
});

final operationModeProvider = Provider<AppOperationMode>((ref) {
  return ref.watch(offlineIndicatorProvider.select((state) => state.operationMode));
});

final serviceAvailabilityProvider = Provider<ServiceAvailability>((ref) {
  return ref.watch(offlineIndicatorProvider.select((state) => state.serviceAvailability));
});

/// 后端健康状态提供器
final backendHealthProvider = Provider<Map<String, BackendHealthStatus>>((ref) {
  return ref.watch(offlineIndicatorProvider.select((state) => state.backendHealthStatuses));
});

/// 离线事件类
class AppOfflineEvent extends AppEvent {
  final OfflineReason? reason;
  final DateTime timestamp;

  AppOfflineEvent({
    this.reason,
    required this.timestamp,
  }) : super(timestamp: timestamp);
}

class AppOnlineEvent extends AppEvent {
  final DateTime timestamp;
  final Duration? serviceResponseTime;

  AppOnlineEvent({
    required this.timestamp,
    this.serviceResponseTime,
  }) : super(timestamp: timestamp);
} 