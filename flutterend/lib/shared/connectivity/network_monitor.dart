// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../types/result.dart';
import '../events/events.dart';
import '../events/event_bus.dart';
import '../signals/app_signals.dart';

/// 网络连接状态枚举
enum NetworkStatus {
  /// 离线
  offline,
  /// 在线
  online,
  /// 连接受限
  limited,
  /// 未知状态
  unknown,
}

/// 网络连接类型枚举
enum NetworkType {
  /// WiFi连接
  wifi,
  /// 移动网络
  mobile,
  /// 以太网
  ethernet,
  /// VPN连接
  vpn,
  /// 蓝牙
  bluetooth,
  /// 其他
  other,
  /// 无连接
  none,
}

/// 网络质量评级
enum NetworkQuality {
  /// 优秀
  excellent,
  /// 良好
  good,
  /// 一般
  fair,
  /// 差
  poor,
  /// 无连接
  none,
}

/// 网络监控统计数据
@immutable
class NetworkStats {
  const NetworkStats({
    this.latency = Duration.zero,
    this.downloadSpeed = 0.0,
    this.uploadSpeed = 0.0,
    this.packetLoss = 0.0,
    this.connectionStability = 1.0,
    this.lastUpdated,
  });

  /// 延迟
  final Duration latency;
  /// 下载速度 (MB/s)
  final double downloadSpeed;
  /// 上传速度 (MB/s)
  final double uploadSpeed;
  /// 丢包率 (0.0-1.0)
  final double packetLoss;
  /// 连接稳定性 (0.0-1.0)
  final double connectionStability;
  /// 最后更新时间
  final DateTime? lastUpdated;

  /// 计算网络质量
  NetworkQuality get quality {
    if (latency == Duration.zero) return NetworkQuality.none;
    
    final latencyMs = latency.inMilliseconds;
    final stability = connectionStability;
    final loss = packetLoss;
    
    // 简化的综合评分算法
    double score = 100.0;
    
    // 延迟影响 (权重: 50%)
    if (latencyMs <= 50) {
      score -= 0;
    } else if (latencyMs <= 100) {
      score -= (latencyMs - 50) * 0.6;
    } else if (latencyMs <= 200) {
      score -= 30 + (latencyMs - 100) * 0.3;
    } else {
      score -= 60;
    }
    
    // 稳定性影响 (权重: 25%)
    score -= (1.0 - stability) * 25;
    
    // 丢包率影响 (权重: 25%)
    score -= loss * 25;
    
    if (score >= 80) return NetworkQuality.excellent;
    if (score >= 60) return NetworkQuality.good;
    if (score >= 40) return NetworkQuality.fair;
    return NetworkQuality.poor;
  }

  NetworkStats copyWith({
    Duration? latency,
    double? downloadSpeed,
    double? uploadSpeed,
    double? packetLoss,
    double? connectionStability,
    DateTime? lastUpdated,
  }) {
    return NetworkStats(
      latency: latency ?? this.latency,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      packetLoss: packetLoss ?? this.packetLoss,
      connectionStability: connectionStability ?? this.connectionStability,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkStats &&
        other.latency == latency &&
        other.downloadSpeed == downloadSpeed &&
        other.uploadSpeed == uploadSpeed &&
        other.packetLoss == packetLoss &&
        other.connectionStability == connectionStability &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode {
    return Object.hash(
      latency,
      downloadSpeed,
      uploadSpeed,
      packetLoss,
      connectionStability,
      lastUpdated,
    );
  }
}

/// 网络监控状态
@immutable
class NetworkMonitorState {
  const NetworkMonitorState({
    this.status = NetworkStatus.unknown,
    this.type = NetworkType.none,
    this.isConnected = false,
    this.stats = const NetworkStats(),
    this.lastConnectionChange,
    this.connectionHistory = const [],
    this.isMonitoring = false,
    this.error,
  });

  /// 网络状态
  final NetworkStatus status;
  /// 连接类型
  final NetworkType type;
  /// 是否已连接
  final bool isConnected;
  /// 网络统计
  final NetworkStats stats;
  /// 最后连接变化时间
  final DateTime? lastConnectionChange;
  /// 连接历史记录
  final List<NetworkConnectionEvent> connectionHistory;
  /// 是否正在监控
  final bool isMonitoring;
  /// 错误信息
  final String? error;

  /// 网络质量
  NetworkQuality get quality => stats.quality;

  /// 是否为稳定连接
  bool get isStable => stats.connectionStability >= 0.8;

  /// 是否为高速连接
  bool get isHighSpeed => stats.downloadSpeed >= 1.0; // >= 1MB/s

  NetworkMonitorState copyWith({
    NetworkStatus? status,
    NetworkType? type,
    bool? isConnected,
    NetworkStats? stats,
    DateTime? lastConnectionChange,
    List<NetworkConnectionEvent>? connectionHistory,
    bool? isMonitoring,
    String? error,
  }) {
    return NetworkMonitorState(
      status: status ?? this.status,
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      stats: stats ?? this.stats,
      lastConnectionChange: lastConnectionChange ?? this.lastConnectionChange,
      connectionHistory: connectionHistory ?? this.connectionHistory,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkMonitorState &&
        other.status == status &&
        other.type == type &&
        other.isConnected == isConnected &&
        other.stats == stats &&
        other.lastConnectionChange == lastConnectionChange &&
        listEquals(other.connectionHistory, connectionHistory) &&
        other.isMonitoring == isMonitoring &&
        other.error == error;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      type,
      isConnected,
      stats,
      lastConnectionChange,
      Object.hashAll(connectionHistory),
      isMonitoring,
      error,
    );
  }
}

/// 网络连接事件
@immutable
class NetworkConnectionEvent {
  const NetworkConnectionEvent({
    required this.timestamp,
    required this.status,
    required this.type,
    this.previousStatus,
    this.previousType,
    this.duration,
  });

  final DateTime timestamp;
  final NetworkStatus status;
  final NetworkType type;
  final NetworkStatus? previousStatus;
  final NetworkType? previousType;
  final Duration? duration;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkConnectionEvent &&
        other.timestamp == timestamp &&
        other.status == status &&
        other.type == type &&
        other.previousStatus == previousStatus &&
        other.previousType == previousType &&
        other.duration == duration;
  }

  @override
  int get hashCode {
    return Object.hash(
      timestamp,
      status,
      type,
      previousStatus,
      previousType,
      duration,
    );
  }
}

/// 网络监控器配置
@immutable
class NetworkMonitorConfig {
  const NetworkMonitorConfig({
    this.enableConnectivityCheck = true,
    this.enableLatencyCheck = true,
    this.enableSpeedTest = false,
    this.checkInterval = const Duration(seconds: 30),
    this.latencyTestHost = 'google.com',
    this.latencyTestPort = 80,
    this.maxHistorySize = 100,
    this.connectivityTimeout = const Duration(seconds: 10),
    this.enableDebugLog = false,
  });

  /// 启用连接检测
  final bool enableConnectivityCheck;
  /// 启用延迟检测
  final bool enableLatencyCheck;
  /// 启用速度测试
  final bool enableSpeedTest;
  /// 检测间隔
  final Duration checkInterval;
  /// 延迟测试主机
  final String latencyTestHost;
  /// 延迟测试端口
  final int latencyTestPort;
  /// 最大历史记录数
  final int maxHistorySize;
  /// 连接超时时间
  final Duration connectivityTimeout;
  /// 启用调试日志
  final bool enableDebugLog;

  NetworkMonitorConfig copyWith({
    bool? enableConnectivityCheck,
    bool? enableLatencyCheck,
    bool? enableSpeedTest,
    Duration? checkInterval,
    String? latencyTestHost,
    int? latencyTestPort,
    int? maxHistorySize,
    Duration? connectivityTimeout,
    bool? enableDebugLog,
  }) {
    return NetworkMonitorConfig(
      enableConnectivityCheck: enableConnectivityCheck ?? this.enableConnectivityCheck,
      enableLatencyCheck: enableLatencyCheck ?? this.enableLatencyCheck,
      enableSpeedTest: enableSpeedTest ?? this.enableSpeedTest,
      checkInterval: checkInterval ?? this.checkInterval,
      latencyTestHost: latencyTestHost ?? this.latencyTestHost,
      latencyTestPort: latencyTestPort ?? this.latencyTestPort,
      maxHistorySize: maxHistorySize ?? this.maxHistorySize,
      connectivityTimeout: connectivityTimeout ?? this.connectivityTimeout,
      enableDebugLog: enableDebugLog ?? this.enableDebugLog,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkMonitorConfig &&
        other.enableConnectivityCheck == enableConnectivityCheck &&
        other.enableLatencyCheck == enableLatencyCheck &&
        other.enableSpeedTest == enableSpeedTest &&
        other.checkInterval == checkInterval &&
        other.latencyTestHost == latencyTestHost &&
        other.latencyTestPort == latencyTestPort &&
        other.maxHistorySize == maxHistorySize &&
        other.connectivityTimeout == connectivityTimeout &&
        other.enableDebugLog == enableDebugLog;
  }

  @override
  int get hashCode {
    return Object.hash(
      enableConnectivityCheck,
      enableLatencyCheck,
      enableSpeedTest,
      checkInterval,
      latencyTestHost,
      latencyTestPort,
      maxHistorySize,
      connectivityTimeout,
      enableDebugLog,
    );
  }
}

/// 网络监控器 - 核心实现
class NetworkMonitor extends StateNotifier<NetworkMonitorState> {
  NetworkMonitor({
    NetworkMonitorConfig? config,
    Connectivity? connectivity,
  }) : _config = config ?? const NetworkMonitorConfig(),
       _connectivity = connectivity ?? Connectivity(),
       super(const NetworkMonitorState()) {
    _initialize();
  }

  final NetworkMonitorConfig _config;
  final Connectivity _connectivity;
  Timer? _monitorTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final List<Duration> _latencyHistory = [];
  DateTime? _lastConnectionChange;

  /// 初始化监控器
  void _initialize() {
    if (_config.enableDebugLog) {
      debugPrint('NetworkMonitor: 正在初始化...');
    }
    
    _setupConnectivityListener();
    _performInitialCheck();
  }

  /// 设置连接状态监听
  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleConnectivityChange(results);
      },
      onError: (error) {
        if (_config.enableDebugLog) {
          debugPrint('NetworkMonitor: 连接监听错误: $error');
        }
        state = state.copyWith(error: error.toString());
      },
    );
  }

  /// 处理连接状态变化
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final now = DateTime.now();
    final connectionType = _mapConnectivityResult(results);
    final isConnected = connectionType != NetworkType.none;
    
    final previousStatus = state.status;
    final previousType = state.type;
    
    // 计算连接持续时间
    Duration? duration;
    if (_lastConnectionChange != null) {
      duration = now.difference(_lastConnectionChange!);
    }
    
    // 创建连接事件
    final connectionEvent = NetworkConnectionEvent(
      timestamp: now,
      status: isConnected ? NetworkStatus.online : NetworkStatus.offline,
      type: connectionType,
      previousStatus: previousStatus,
      previousType: previousType,
      duration: duration,
    );
    
    // 更新历史记录
    final updatedHistory = [...state.connectionHistory, connectionEvent];
    if (updatedHistory.length > _config.maxHistorySize) {
      updatedHistory.removeAt(0);
    }
    
    // 更新状态
    state = state.copyWith(
      status: isConnected ? NetworkStatus.online : NetworkStatus.offline,
      type: connectionType,
      isConnected: isConnected,
      lastConnectionChange: now,
      connectionHistory: updatedHistory,
      error: null,
    );
    
    _lastConnectionChange = now;
    
    // 发送事件到事件总线
    _emitNetworkEvent(connectionEvent);
    
    // 如果连接恢复，开始网络质量检测
    if (isConnected && _config.enableLatencyCheck) {
      _scheduleNetworkCheck();
    }
    
    if (_config.enableDebugLog) {
      debugPrint('NetworkMonitor: 连接状态变化 $previousType -> $connectionType');
    }
  }

  /// 映射connectivity_plus结果到内部类型
  NetworkType _mapConnectivityResult(List<ConnectivityResult> results) {
    if (results.isEmpty) return NetworkType.none;
    
    // 修正优先级顺序：ethernet > wifi > vpn > mobile > other  
    // 按重要性排序，确保最高优先级的连接类型被选中
    final priorities = {
      ConnectivityResult.ethernet: 1,
      ConnectivityResult.wifi: 2,
      ConnectivityResult.vpn: 3,
      ConnectivityResult.mobile: 4,
      ConnectivityResult.bluetooth: 5,
      ConnectivityResult.other: 6,
      ConnectivityResult.none: 7,
    };
    
    // 找到优先级最高的连接类型
    ConnectivityResult? bestResult;
    int bestPriority = 8;
    
    for (final result in results) {
      final priority = priorities[result] ?? 8;
      if (priority < bestPriority) {
        bestPriority = priority;
        bestResult = result;
      }
    }
    
    switch (bestResult) {
      case ConnectivityResult.ethernet:
        return NetworkType.ethernet;
      case ConnectivityResult.wifi:
        return NetworkType.wifi;
      case ConnectivityResult.mobile:
        return NetworkType.mobile;
      case ConnectivityResult.vpn:
        return NetworkType.vpn;
      case ConnectivityResult.bluetooth:
        return NetworkType.bluetooth;
      case ConnectivityResult.other:
        return NetworkType.other;
      case ConnectivityResult.none:
      case null:
        return NetworkType.none;
    }
  }

  /// 执行初始检查
  Future<void> _performInitialCheck() async {
    try {
      // 添加生命周期检查
      if (!mounted) return;
      
      final connectivityResult = await _connectivity.checkConnectivity();
      
      // 再次检查生命周期
      if (!mounted) return;
      
      _handleConnectivityChange(connectivityResult);
    } catch (e) {
      if (_config.enableDebugLog && mounted) {
        debugPrint('NetworkMonitor: 初始检查失败: $e');
      }
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
    }
  }

  /// 调度网络检测
  void _scheduleNetworkCheck() {
    _monitorTimer?.cancel();
    
    if (!state.isConnected || !_config.enableLatencyCheck) return;
    
    _monitorTimer = Timer(_config.checkInterval, () {
      _performNetworkCheck();
    });
  }

  /// 执行网络检测
  Future<void> _performNetworkCheck() async {
    if (!mounted || !state.isConnected) return;
    
    try {
      final latency = await _measureLatency();
      final stability = _calculateStability();
      
      if (!mounted) return;
      
      final updatedStats = state.stats.copyWith(
        latency: latency,
        connectionStability: stability,
        lastUpdated: DateTime.now(),
      );
      
      state = state.copyWith(stats: updatedStats);
      
      // 继续调度下次检测
      _scheduleNetworkCheck();
    } catch (e) {
      if (_config.enableDebugLog && mounted) {
        debugPrint('NetworkMonitor: 网络检测失败: $e');
      }
    }
  }

  /// 测量网络延迟
  Future<Duration> _measureLatency() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final socket = await Socket.connect(
        _config.latencyTestHost,
        _config.latencyTestPort,
        timeout: _config.connectivityTimeout,
      );
      
      stopwatch.stop();
      await socket.close();
      
      final latency = stopwatch.elapsed;
      _latencyHistory.add(latency);
      
      // 保持历史记录大小
      if (_latencyHistory.length > 10) {
        _latencyHistory.removeAt(0);
      }
      
      return latency;
    } catch (e) {
      stopwatch.stop();
      // 连接失败时返回一个很高的延迟值
      return const Duration(milliseconds: 5000);
    }
  }

  /// 计算连接稳定性
  double _calculateStability() {
    if (_latencyHistory.length < 3) return 1.0;
    
    // 计算延迟变化的标准差
    final latencies = _latencyHistory.map((d) => d.inMilliseconds.toDouble()).toList();
    final mean = latencies.reduce((a, b) => a + b) / latencies.length;
    final variance = latencies.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / latencies.length;
    final standardDeviation = math.sqrt(variance);
    
    // 标准差越小，稳定性越高
    final maxStdDev = 500.0; // 500ms标准差认为是完全不稳定
    final stability = math.max(0.0, 1.0 - (standardDeviation / maxStdDev));
    
    return stability;
  }

  /// 发送网络事件到事件总线
  void _emitNetworkEvent(NetworkConnectionEvent connectionEvent) {
    final networkEvent = EventFactory.networkConnectivityChanged(
      isConnected: state.isConnected,
      connectionType: _mapNetworkTypeToString(state.type),
    );
    
    EventBus.instance.emit(networkEvent);
  }

  /// 映射网络类型到字符串
  String _mapNetworkTypeToString(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
        return 'wifi';
      case NetworkType.mobile:
        return 'cellular';
      case NetworkType.ethernet:
        return 'ethernet';
      case NetworkType.vpn:
        return 'vpn';
      case NetworkType.bluetooth:
        return 'bluetooth';
      case NetworkType.other:
        return 'other';
      case NetworkType.none:
        return 'none';
    }
  }

  /// 开始监控
  Future<AppResult<void>> startMonitoring() async {
    if (state.isMonitoring) {
      return const Result.success(null);
    }
    
    try {
      state = state.copyWith(isMonitoring: true);
      
      if (_config.enableLatencyCheck && state.isConnected) {
        _scheduleNetworkCheck();
      }
      
      if (_config.enableDebugLog) {
        debugPrint('NetworkMonitor: 开始监控');
      }
      
      return const Result.success(null);
    } catch (e) {
      return Result.failure(BusinessError('启动网络监控失败', e));
    }
  }

  /// 停止监控
  Future<void> stopMonitoring() async {
    state = state.copyWith(isMonitoring: false);
    _monitorTimer?.cancel();
    
    if (_config.enableDebugLog) {
      debugPrint('NetworkMonitor: 停止监控');
    }
  }

  /// 手动刷新网络状态
  Future<AppResult<void>> refresh() async {
    try {
      await _performInitialCheck();
      
      if (state.isConnected && _config.enableLatencyCheck) {
        await _performNetworkCheck();
      }
      
      return const Result.success(null);
    } catch (e) {
      return Result.failure(BusinessError('刷新网络状态失败', e));
    }
  }

  /// 获取网络状态摘要
  String getNetworkSummary() {
    if (!state.isConnected) {
      return '离线';
    }
    
    final typeStr = _getNetworkTypeDisplayName(state.type);
    final qualityStr = _getQualityDisplayName(state.quality);
    
    if (state.stats.latency != Duration.zero) {
      return '$typeStr - $qualityStr (${state.stats.latency.inMilliseconds}ms)';
    }
    
    return '$typeStr - $qualityStr';
  }

  /// 获取网络类型显示名称
  String _getNetworkTypeDisplayName(NetworkType type) {
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

  /// 获取质量显示名称
  String _getQualityDisplayName(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return '优秀';
      case NetworkQuality.good:
        return '良好';
      case NetworkQuality.fair:
        return '一般';
      case NetworkQuality.poor:
        return '差';
      case NetworkQuality.none:
        return '无连接';
    }
  }

  /// 释放资源
  @override
  void dispose() {
    _monitorTimer?.cancel();
    _connectivitySubscription?.cancel();
    
    if (_config.enableDebugLog && mounted) {
      debugPrint('NetworkMonitor: 已释放资源');
    }
    
    super.dispose();
  }
}

/// 网络监控器提供器
final networkMonitorProvider = StateNotifierProvider<NetworkMonitor, NetworkMonitorState>(
  (ref) {
    final monitor = NetworkMonitor();
    
    // 自动启动监控
    monitor.startMonitoring();
    
    ref.onDispose(() {
      monitor.dispose();
    });
    
    return monitor;
  },
  name: 'NetworkMonitor',
);

/// 网络监控器扩展方法
extension NetworkMonitorExtensions on NetworkMonitor {
  /// 等待网络连接
  Future<bool> waitForConnection({Duration? timeout}) async {
    if (state.isConnected) return true;
    
    final completer = Completer<bool>();
    late StreamSubscription subscription;
    
    subscription = stream.listen((state) {
      if (state.isConnected && !completer.isCompleted) {
        completer.complete(true);
        subscription.cancel();
      }
    });
    
    if (timeout != null) {
      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(false);
          subscription.cancel();
        }
      });
    }
    
    return completer.future;
  }

  /// 检查是否为计费网络
  bool get isMeteredConnection {
    return state.type == NetworkType.mobile;
  }

  /// 检查是否适合大文件传输
  bool get isSuitableForLargeTransfer {
    return state.isConnected &&
           state.quality != NetworkQuality.poor &&
           state.stats.connectionStability >= 0.7;
  }
}