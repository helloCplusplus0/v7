// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../types/result.dart';
import '../connectivity/network_monitor.dart';
import '../offline/offline_indicator.dart';
import 'background_sync_service.dart';
import 'sync_manager.dart';
import 'offline_queue.dart';

/// 同步调度策略
enum SyncScheduleStrategy {
  /// 保守策略 - 仅在理想条件下同步
  conservative,
  /// 平衡策略 - 在良好条件下同步
  balanced,
  /// 积极策略 - 在可用条件下同步
  aggressive,
  /// 自适应策略 - 根据历史数据动态调整
  adaptive,
}

/// 用户行为模式
enum UserBehaviorPattern {
  /// 活跃用户
  active,
  /// 普通用户
  normal,
  /// 不活跃用户
  inactive,
  /// 新用户
  newUser,
}

/// 同步时机
enum SyncTiming {
  /// 应用启动时
  appStart,
  /// 用户活跃时
  userActive,
  /// 用户空闲时
  userIdle,
  /// 网络恢复时
  networkRecovery,
  /// 定期同步
  periodic,
  /// 应用退到后台时
  appBackground,
  /// 充电时
  charging,
}

/// 智能调度配置
@immutable
class SmartScheduleConfig {
  const SmartScheduleConfig({
    this.strategy = SyncScheduleStrategy.adaptive,
    this.minSyncInterval = const Duration(minutes: 5),
    this.maxSyncInterval = const Duration(hours: 4),
    this.userIdleThreshold = const Duration(minutes: 10),
    this.batteryThreshold = 0.2,
    this.enableUserBehaviorAnalysis = true,
    this.enableNetworkQualityAdaptation = true,
    this.enableBatteryOptimization = true,
    this.enableDataSaverMode = false,
    this.enableNightModeOptimization = true,
    this.nightModeStartHour = 22,
    this.nightModeEndHour = 7,
    this.maxConcurrentSyncs = 1,
    this.syncPriorityWeights = const {
      OperationPriority.critical: 1.0,
      OperationPriority.high: 0.8,
      OperationPriority.normal: 0.6,
      OperationPriority.low: 0.4,
    },
  });

  /// 调度策略
  final SyncScheduleStrategy strategy;
  /// 最小同步间隔
  final Duration minSyncInterval;
  /// 最大同步间隔
  final Duration maxSyncInterval;
  /// 用户空闲阈值
  final Duration userIdleThreshold;
  /// 电池阈值
  final double batteryThreshold;
  /// 启用用户行为分析
  final bool enableUserBehaviorAnalysis;
  /// 启用网络质量自适应
  final bool enableNetworkQualityAdaptation;
  /// 启用电池优化
  final bool enableBatteryOptimization;
  /// 启用数据节省模式
  final bool enableDataSaverMode;
  /// 启用夜间模式优化
  final bool enableNightModeOptimization;
  /// 夜间模式开始时间
  final int nightModeStartHour;
  /// 夜间模式结束时间
  final int nightModeEndHour;
  /// 最大并发同步数
  final int maxConcurrentSyncs;
  /// 同步优先级权重
  final Map<OperationPriority, double> syncPriorityWeights;

  SmartScheduleConfig copyWith({
    SyncScheduleStrategy? strategy,
    Duration? minSyncInterval,
    Duration? maxSyncInterval,
    Duration? userIdleThreshold,
    double? batteryThreshold,
    bool? enableUserBehaviorAnalysis,
    bool? enableNetworkQualityAdaptation,
    bool? enableBatteryOptimization,
    bool? enableDataSaverMode,
    bool? enableNightModeOptimization,
    int? nightModeStartHour,
    int? nightModeEndHour,
    int? maxConcurrentSyncs,
    Map<OperationPriority, double>? syncPriorityWeights,
  }) {
    return SmartScheduleConfig(
      strategy: strategy ?? this.strategy,
      minSyncInterval: minSyncInterval ?? this.minSyncInterval,
      maxSyncInterval: maxSyncInterval ?? this.maxSyncInterval,
      userIdleThreshold: userIdleThreshold ?? this.userIdleThreshold,
      batteryThreshold: batteryThreshold ?? this.batteryThreshold,
      enableUserBehaviorAnalysis: enableUserBehaviorAnalysis ?? this.enableUserBehaviorAnalysis,
      enableNetworkQualityAdaptation: enableNetworkQualityAdaptation ?? this.enableNetworkQualityAdaptation,
      enableBatteryOptimization: enableBatteryOptimization ?? this.enableBatteryOptimization,
      enableDataSaverMode: enableDataSaverMode ?? this.enableDataSaverMode,
      enableNightModeOptimization: enableNightModeOptimization ?? this.enableNightModeOptimization,
      nightModeStartHour: nightModeStartHour ?? this.nightModeStartHour,
      nightModeEndHour: nightModeEndHour ?? this.nightModeEndHour,
      maxConcurrentSyncs: maxConcurrentSyncs ?? this.maxConcurrentSyncs,
      syncPriorityWeights: syncPriorityWeights ?? this.syncPriorityWeights,
    );
  }
}

/// 调度决策
@immutable
class ScheduleDecision {
  const ScheduleDecision({
    required this.shouldSync,
    required this.delay,
    required this.priority,
    required this.reason,
    this.conditions = const {},
    this.confidence = 1.0,
  });

  /// 是否应该同步
  final bool shouldSync;
  /// 延迟时间
  final Duration delay;
  /// 优先级
  final OperationPriority priority;
  /// 决策原因
  final String reason;
  /// 条件评估
  final Map<String, dynamic> conditions;
  /// 决策信心度
  final double confidence;
}

/// 用户行为分析器
class UserBehaviorAnalyzer {
  UserBehaviorAnalyzer();

  final List<DateTime> _appUsageTimes = [];
  final List<DateTime> _syncTimes = [];
  final Map<int, int> _hourlyUsage = {};
  
  DateTime? _lastActivityTime;
  int _dailyUsageCount = 0;
  Duration _totalUsageTime = Duration.zero;

  /// 记录用户活动
  void recordUserActivity() {
    final now = DateTime.now();
    _lastActivityTime = now;
    _appUsageTimes.add(now);
    _dailyUsageCount++;
    
    // 统计每小时使用情况
    final hour = now.hour;
    _hourlyUsage[hour] = (_hourlyUsage[hour] ?? 0) + 1;
    
    // 保持最近7天的数据
    _cleanupOldData();
  }

  /// 记录同步时间
  void recordSyncTime() {
    _syncTimes.add(DateTime.now());
    _cleanupOldData();
  }

  /// 获取用户行为模式
  UserBehaviorPattern getUserBehaviorPattern() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    
    final recentUsage = _appUsageTimes
        .where((time) => time.isAfter(weekAgo))
        .length;
    
    if (recentUsage == 0) return UserBehaviorPattern.newUser;
    
    final dailyAverage = recentUsage / 7;
    
    if (dailyAverage > 20) return UserBehaviorPattern.active;
    if (dailyAverage > 5) return UserBehaviorPattern.normal;
    return UserBehaviorPattern.inactive;
  }

  /// 获取最佳同步时间
  List<int> getBestSyncHours() {
    if (_hourlyUsage.isEmpty) return [9, 14, 19]; // 默认时间
    
    final sortedHours = _hourlyUsage.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedHours.take(3).map((e) => e.key).toList();
  }

  /// 是否用户空闲
  bool isUserIdle(Duration idleThreshold) {
    if (_lastActivityTime == null) return true;
    return DateTime.now().difference(_lastActivityTime!) > idleThreshold;
  }

  /// 预测下次活动时间
  DateTime? predictNextActivity() {
    if (_appUsageTimes.isEmpty) return null;
    
    final bestHours = getBestSyncHours();
    final now = DateTime.now();
    
    for (final hour in bestHours) {
      final nextTime = DateTime(now.year, now.month, now.day, hour);
      if (nextTime.isAfter(now)) {
        return nextTime;
      }
    }
    
    // 如果今天没有合适时间，返回明天第一个最佳时间
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, bestHours.first);
  }

  /// 清理旧数据
  void _cleanupOldData() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    
    _appUsageTimes.removeWhere((time) => time.isBefore(weekAgo));
    _syncTimes.removeWhere((time) => time.isBefore(weekAgo));
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    return {
      'totalUsageTimes': _appUsageTimes.length,
      'dailyUsageCount': _dailyUsageCount,
      'totalUsageTime': _totalUsageTime.inMinutes,
      'hourlyUsage': _hourlyUsage,
      'behaviorPattern': getUserBehaviorPattern().name,
      'bestSyncHours': getBestSyncHours(),
      'isCurrentlyIdle': isUserIdle(const Duration(minutes: 10)),
      'predictedNextActivity': predictNextActivity()?.toIso8601String(),
    };
  }
}

/// 智能同步调度器
class SmartSyncScheduler extends StateNotifier<ScheduleDecision> {
  SmartSyncScheduler(
    this._ref, {
    SmartScheduleConfig? config,
  }) : _config = config ?? const SmartScheduleConfig(),
       super(const ScheduleDecision(
         shouldSync: false,
         delay: Duration.zero,
         priority: OperationPriority.normal,
         reason: 'Initializing',
       )) {
    _initialize();
  }

  final Ref _ref;
  SmartScheduleConfig _config;
  
  final UserBehaviorAnalyzer _behaviorAnalyzer = UserBehaviorAnalyzer();
  Timer? _evaluationTimer;
  Timer? _userActivityTimer;
  
  DateTime? _lastSyncTime;
  final List<ScheduleDecision> _decisionHistory = [];
  final Map<String, double> _conditionWeights = {};

  /// 获取配置
  SmartScheduleConfig get config => _config;

  /// 获取用户行为分析器
  UserBehaviorAnalyzer get behaviorAnalyzer => _behaviorAnalyzer;

  /// 初始化调度器
  void _initialize() {
    _loadHistoricalData();
    _setupEvaluationTimer();
    _setupUserActivityMonitoring();
    _initializeConditionWeights();
  }

  /// 加载历史数据
  Future<void> _loadHistoricalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString('last_smart_sync_time');
      if (lastSyncString != null) {
        _lastSyncTime = DateTime.tryParse(lastSyncString);
      }
    } catch (e) {
      debugPrint('Failed to load historical data: $e');
    }
  }

  /// 设置评估定时器
  void _setupEvaluationTimer() {
    _evaluationTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _evaluateScheduleDecision(),
    );
  }

  /// 设置用户活动监控
  void _setupUserActivityMonitoring() {
    _userActivityTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkUserActivity(),
    );
  }

  /// 初始化条件权重
  void _initializeConditionWeights() {
    _conditionWeights.addAll({
      'networkQuality': 0.3,
      'batteryLevel': 0.2,
      'userBehavior': 0.2,
      'timingOptimization': 0.15,
      'dataUsage': 0.1,
      'systemLoad': 0.05,
    });
  }

  /// 评估调度决策
  void _evaluateScheduleDecision() {
    final networkState = _ref.read(networkMonitorProvider);
    final offlineState = _ref.read(offlineIndicatorProvider);
    final backgroundSyncState = _ref.read(backgroundSyncStateProvider);
    
    final decision = _makeScheduleDecision(
      networkState: networkState,
      offlineState: offlineState,
      backgroundSyncState: backgroundSyncState,
    );
    
    _recordDecision(decision);
    state = decision;
    
    // 如果决策是同步，触发同步
    if (decision.shouldSync) {
      _triggerSync(decision);
    }
  }

  /// 制定调度决策
  ScheduleDecision _makeScheduleDecision({
    required NetworkMonitorState networkState,
    required OfflineStatus offlineState,
    required BackgroundSyncState backgroundSyncState,
  }) {
    final conditions = _evaluateConditions(
      networkState: networkState,
      offlineState: offlineState,
      backgroundSyncState: backgroundSyncState,
    );
    
    final score = _calculateScheduleScore(conditions);
    final shouldSync = _shouldSyncBasedOnScore(score, conditions);
    
    return ScheduleDecision(
      shouldSync: shouldSync,
      delay: _calculateOptimalDelay(conditions),
      priority: _calculatePriority(conditions),
      reason: _generateReason(shouldSync, conditions),
      conditions: conditions,
      confidence: _calculateConfidence(conditions),
    );
  }

  /// 评估条件
  Map<String, dynamic> _evaluateConditions({
    required NetworkMonitorState networkState,
    required OfflineStatus offlineState,
    required BackgroundSyncState backgroundSyncState,
  }) {
    final now = DateTime.now();
    
    return {
      // 网络条件
      'networkQuality': _evaluateNetworkQuality(networkState),
      'isConnected': networkState.isConnected,
      'isWifi': networkState.type == NetworkType.wifi,
      'networkStability': networkState.isStable,
      
      // 离线状态
      'canSync': offlineState.canSync,
      'operationMode': offlineState.operationMode,
      'hasOfflineQueue': offlineState.shouldUseOfflineQueue,
      
      // 后台同步状态
      'isBackgroundSyncActive': backgroundSyncState.isActive,
      'hasPendingTasks': backgroundSyncState.hasPendingTasks,
      'hasRunningTasks': backgroundSyncState.hasRunningTasks,
      'lastSyncTime': backgroundSyncState.lastSyncTime,
      
      // 时间条件
      'isNightMode': _isNightMode(now),
      'timeSinceLastSync': _getTimeSinceLastSync(),
      'isOptimalTime': _isOptimalSyncTime(now),
      
      // 用户行为
      'userBehaviorPattern': _behaviorAnalyzer.getUserBehaviorPattern(),
      'isUserIdle': _behaviorAnalyzer.isUserIdle(_config.userIdleThreshold),
      'predictedNextActivity': _behaviorAnalyzer.predictNextActivity(),
      
      // 系统条件
      'batteryLevel': backgroundSyncState.batteryLevel,
      'isCharging': backgroundSyncState.isCharging,
      'systemLoad': _estimateSystemLoad(),
      
      // 数据使用
      'dataUsageOptimization': _shouldOptimizeDataUsage(networkState),
    };
  }

  /// 评估网络质量
  double _evaluateNetworkQuality(NetworkMonitorState networkState) {
    if (!networkState.isConnected) return 0.0;
    
    return switch (networkState.quality) {
      NetworkQuality.excellent => 1.0,
      NetworkQuality.good => 0.8,
      NetworkQuality.fair => 0.6,
      NetworkQuality.poor => 0.3,
      NetworkQuality.none => 0.0,
    };
  }

  /// 是否夜间模式
  bool _isNightMode(DateTime time) {
    if (!_config.enableNightModeOptimization) return false;
    
    final hour = time.hour;
    if (_config.nightModeStartHour < _config.nightModeEndHour) {
      return hour >= _config.nightModeStartHour && hour < _config.nightModeEndHour;
    } else {
      return hour >= _config.nightModeStartHour || hour < _config.nightModeEndHour;
    }
  }

  /// 获取距离上次同步的时间
  Duration _getTimeSinceLastSync() {
    if (_lastSyncTime == null) return const Duration(hours: 24);
    return DateTime.now().difference(_lastSyncTime!);
  }

  /// 是否最佳同步时间
  bool _isOptimalSyncTime(DateTime time) {
    if (!_config.enableUserBehaviorAnalysis) return true;
    
    final bestHours = _behaviorAnalyzer.getBestSyncHours();
    return bestHours.contains(time.hour);
  }

  /// 估算系统负载
  double _estimateSystemLoad() {
    // 简化实现，实际可以通过系统API获取
    return 0.5; // 假设中等负载
  }

  /// 是否应该优化数据使用
  bool _shouldOptimizeDataUsage(NetworkMonitorState networkState) {
    if (!_config.enableDataSaverMode) return false;
    return networkState.type == NetworkType.mobile;
  }

  /// 计算调度分数
  double _calculateScheduleScore(Map<String, dynamic> conditions) {
    double score = 0.0;
    
    // 网络质量权重
    score += (conditions['networkQuality'] as double) * _conditionWeights['networkQuality']!;
    
    // 电池电量权重
    final batteryLevel = conditions['batteryLevel'] as double;
    final batteryScore = batteryLevel > _config.batteryThreshold ? 1.0 : 0.0;
    score += batteryScore * _conditionWeights['batteryLevel']!;
    
    // 用户行为权重
    final userBehaviorScore = _calculateUserBehaviorScore(conditions);
    score += userBehaviorScore * _conditionWeights['userBehavior']!;
    
    // 时间优化权重
    final timingScore = _calculateTimingScore(conditions);
    score += timingScore * _conditionWeights['timingOptimization']!;
    
    // 数据使用权重
    final dataUsageScore = conditions['dataUsageOptimization'] as bool ? 0.5 : 1.0;
    score += dataUsageScore * _conditionWeights['dataUsage']!;
    
    // 系统负载权重
    final systemLoadScore = 1.0 - (conditions['systemLoad'] as double);
    score += systemLoadScore * _conditionWeights['systemLoad']!;
    
    return math.min(score, 1.0);
  }

  /// 计算用户行为分数
  double _calculateUserBehaviorScore(Map<String, dynamic> conditions) {
    if (!_config.enableUserBehaviorAnalysis) return 0.8;
    
    final isUserIdle = conditions['isUserIdle'] as bool;
    final behaviorPattern = conditions['userBehaviorPattern'] as UserBehaviorPattern;
    
    double score = 0.0;
    
    // 用户空闲时同步更好
    if (isUserIdle) score += 0.5;
    
    // 根据用户行为模式调整
    switch (behaviorPattern) {
      case UserBehaviorPattern.active:
        score += 0.3;
        break;
      case UserBehaviorPattern.normal:
        score += 0.4;
        break;
      case UserBehaviorPattern.inactive:
        score += 0.5;
        break;
      case UserBehaviorPattern.newUser:
        score += 0.3;
        break;
    }
    
    return math.min(score, 1.0);
  }

  /// 计算时间分数
  double _calculateTimingScore(Map<String, dynamic> conditions) {
    double score = 0.0;
    
    final timeSinceLastSync = conditions['timeSinceLastSync'] as Duration;
    final isOptimalTime = conditions['isOptimalTime'] as bool;
    final isNightMode = conditions['isNightMode'] as bool;
    
    // 距离上次同步时间越长，分数越高
    final timeFactor = math.min(timeSinceLastSync.inMinutes / _config.maxSyncInterval.inMinutes, 1.0);
    score += timeFactor * 0.4;
    
    // 最佳时间加分
    if (isOptimalTime) score += 0.3;
    
    // 夜间模式减分
    if (isNightMode) score -= 0.2;
    
    return math.max(score, 0.0);
  }

  /// 是否应该同步
  bool _shouldSyncBasedOnScore(double score, Map<String, dynamic> conditions) {
    // 基础条件检查
    if (!(conditions['isConnected'] as bool) || !(conditions['canSync'] as bool)) {
      return false;
    }
    
    // 如果有运行中任务，不启动新同步
    if (conditions['hasRunningTasks'] as bool) {
      return false;
    }
    
    // 根据策略决定阈值
    final threshold = switch (_config.strategy) {
      SyncScheduleStrategy.conservative => 0.8,
      SyncScheduleStrategy.balanced => 0.6,
      SyncScheduleStrategy.aggressive => 0.4,
      SyncScheduleStrategy.adaptive => _getAdaptiveThreshold(),
    };
    
    return score >= threshold;
  }

  /// 获取自适应阈值
  double _getAdaptiveThreshold() {
    // 基于历史决策调整阈值
    if (_decisionHistory.isEmpty) return 0.6;
    
    final recentDecisions = _decisionHistory.take(10).toList();
    final successRate = recentDecisions.where((d) => d.shouldSync).length / recentDecisions.length;
    
    if (successRate > 0.8) return 0.7; // 提高阈值
    if (successRate < 0.3) return 0.5; // 降低阈值
    return 0.6; // 保持默认
  }

  /// 计算最佳延迟
  Duration _calculateOptimalDelay(Map<String, dynamic> conditions) {
    final isUserIdle = conditions['isUserIdle'] as bool;
    final networkQuality = conditions['networkQuality'] as double;
    final predictedNextActivity = conditions['predictedNextActivity'] as DateTime?;
    
    // 用户活跃时延迟同步
    if (!isUserIdle) {
      return const Duration(minutes: 5);
    }
    
    // 网络质量差时延迟
    if (networkQuality < 0.5) {
      return const Duration(minutes: 10);
    }
    
    // 如果预测到用户下次活动时间，在之前同步
    if (predictedNextActivity != null) {
      final timeUntilActivity = predictedNextActivity.difference(DateTime.now());
      if (timeUntilActivity > const Duration(minutes: 30)) {
        return const Duration(minutes: 2);
      }
    }
    
    return Duration.zero;
  }

  /// 计算优先级
  OperationPriority _calculatePriority(Map<String, dynamic> conditions) {
    final hasPendingTasks = conditions['hasPendingTasks'] as bool;
    final hasOfflineQueue = conditions['hasOfflineQueue'] as bool;
    final timeSinceLastSync = conditions['timeSinceLastSync'] as Duration;
    
    // 有离线队列时优先级较高
    if (hasOfflineQueue) return OperationPriority.high;
    
    // 长时间未同步时优先级较高
    if (timeSinceLastSync > _config.maxSyncInterval) return OperationPriority.high;
    
    // 有待处理任务时优先级中等
    if (hasPendingTasks) return OperationPriority.normal;
    
    return OperationPriority.low;
  }

  /// 生成决策原因
  String _generateReason(bool shouldSync, Map<String, dynamic> conditions) {
    if (!shouldSync) {
      if (!(conditions['isConnected'] as bool)) return '网络未连接';
      if (!(conditions['canSync'] as bool)) return '服务不可用';
      if (conditions['hasRunningTasks'] as bool) return '同步任务进行中';
      return '条件不满足同步要求';
    }
    
    final reasons = <String>[];
    
    if (conditions['hasOfflineQueue'] as bool) {
      reasons.add('处理离线队列');
    }
    
    final timeSinceLastSync = conditions['timeSinceLastSync'] as Duration;
    if (timeSinceLastSync > _config.maxSyncInterval) {
      reasons.add('定期同步');
    }
    
    if (conditions['isUserIdle'] as bool) {
      reasons.add('用户空闲');
    }
    
    if (conditions['isOptimalTime'] as bool) {
      reasons.add('最佳时间');
    }
    
    return reasons.isEmpty ? '智能调度决策' : reasons.join('、');
  }

  /// 计算信心度
  double _calculateConfidence(Map<String, dynamic> conditions) {
    double confidence = 0.5;
    
    // 网络质量高时信心度高
    final networkQuality = conditions['networkQuality'] as double;
    confidence += networkQuality * 0.3;
    
    // 用户行为分析可用时信心度高
    if (_config.enableUserBehaviorAnalysis) {
      confidence += 0.2;
    }
    
    return math.min(confidence, 1.0);
  }

  /// 记录决策
  void _recordDecision(ScheduleDecision decision) {
    _decisionHistory.add(decision);
    
    // 保持最近100个决策
    if (_decisionHistory.length > 100) {
      _decisionHistory.removeAt(0);
    }
  }

  /// 触发同步
  void _triggerSync(ScheduleDecision decision) {
    final backgroundSyncService = _ref.read(backgroundSyncServiceProvider.notifier);
    
    // 根据决策延迟执行
    if (decision.delay > Duration.zero) {
      Timer(decision.delay, () {
        _executeSyncWithPriority(backgroundSyncService, decision.priority);
      });
    } else {
      _executeSyncWithPriority(backgroundSyncService, decision.priority);
    }
  }

  /// 执行同步
  void _executeSyncWithPriority(BackgroundSyncService service, OperationPriority priority) {
    final taskType = switch (priority) {
      OperationPriority.critical => BackgroundSyncTaskType.emergencySync,
      OperationPriority.high => BackgroundSyncTaskType.networkRecoverySync,
      OperationPriority.normal => BackgroundSyncTaskType.periodicSync,
      OperationPriority.low => BackgroundSyncTaskType.incrementalSync,
    };
    
    service.scheduleTask(taskType, priority: priority);
    _lastSyncTime = DateTime.now();
    _behaviorAnalyzer.recordSyncTime();
    
    // 保存同步时间
    _saveLastSyncTime();
  }

  /// 保存最后同步时间
  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastSyncTime != null) {
        await prefs.setString('last_smart_sync_time', _lastSyncTime!.toIso8601String());
      }
    } catch (e) {
      debugPrint('Failed to save last sync time: $e');
    }
  }

  /// 检查用户活动
  void _checkUserActivity() {
    // 这里可以集成用户活动检测逻辑
    // 例如：监听路由变化、触摸事件等
    _behaviorAnalyzer.recordUserActivity();
  }

  /// 公共方法

  /// 手动触发评估
  void triggerEvaluation() {
    _evaluateScheduleDecision();
  }

  /// 更新配置
  void updateConfig(SmartScheduleConfig config) {
    _config = config;
    _initializeConditionWeights();
  }

  /// 获取决策历史
  List<ScheduleDecision> getDecisionHistory() {
    return List.unmodifiable(_decisionHistory);
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    final userStats = _behaviorAnalyzer.getStatistics();
    final recentDecisions = _decisionHistory.take(24).toList();
    
    return {
      'totalDecisions': _decisionHistory.length,
      'recentSyncDecisions': recentDecisions.where((d) => d.shouldSync).length,
      'averageConfidence': recentDecisions.isEmpty ? 0.0 : 
          recentDecisions.map((d) => d.confidence).reduce((a, b) => a + b) / recentDecisions.length,
      'strategy': _config.strategy.name,
      'conditionWeights': _conditionWeights,
      'userBehavior': userStats,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
    };
  }

  /// 重置统计数据
  void resetStatistics() {
    _decisionHistory.clear();
    _lastSyncTime = null;
  }

  /// 释放资源
  @override
  void dispose() {
    _evaluationTimer?.cancel();
    _userActivityTimer?.cancel();
    super.dispose();
  }
}

/// Riverpod 提供器
final smartScheduleConfigProvider = StateProvider<SmartScheduleConfig>((ref) {
  return const SmartScheduleConfig();
});

final smartSyncSchedulerProvider = StateNotifierProvider<SmartSyncScheduler, ScheduleDecision>((ref) {
  final config = ref.watch(smartScheduleConfigProvider);
  return SmartSyncScheduler(ref, config: config);
});

/// 便捷访问提供器
final currentScheduleDecisionProvider = Provider<ScheduleDecision>((ref) {
  return ref.watch(smartSyncSchedulerProvider);
});

final shouldSyncNowProvider = Provider<bool>((ref) {
  return ref.watch(smartSyncSchedulerProvider.select((decision) => decision.shouldSync));
});

final syncScheduleStatisticsProvider = Provider<Map<String, dynamic>>((ref) {
  final scheduler = ref.read(smartSyncSchedulerProvider.notifier);
  return scheduler.getStatistics();
});

final userBehaviorPatternProvider = Provider<UserBehaviorPattern>((ref) {
  final scheduler = ref.read(smartSyncSchedulerProvider.notifier);
  return scheduler.behaviorAnalyzer.getUserBehaviorPattern();
});

/// 扩展方法
extension SmartSyncSchedulerExtensions on SmartSyncScheduler {
  /// 是否在最佳同步时间
  bool get isOptimalSyncTime {
    final now = DateTime.now();
    return behaviorAnalyzer.getBestSyncHours().contains(now.hour);
  }
  
  /// 获取下次推荐同步时间
  DateTime? get nextRecommendedSyncTime {
    return behaviorAnalyzer.predictNextActivity();
  }
  
  /// 获取当前决策信心度
  double get currentConfidence => state.confidence;
  
  /// 是否用户当前活跃
  bool get isUserCurrentlyActive {
    return !behaviorAnalyzer.isUserIdle(config.userIdleThreshold);
  }
} 