/// Demo切片摘要提供者
/// 为任务管理切片提供实时摘要数据
/// 
/// 包含：
/// - 任务统计信息
/// - 系统状态监控
/// - 快捷操作按钮

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../shared/contracts/slice_summary_contract.dart';
import '../../shared/events/event_bus.dart';
import '../../shared/events/events.dart';
import '../../shared/services/service_locator.dart';
import 'service.dart';
import 'models.dart';

/// Demo任务管理切片摘要提供者
class DemoTaskSummaryProvider implements SliceSummaryProvider {
  DemoTaskSummaryProvider({
    this.backendBaseUrl = 'http://localhost:8080',
    this.requiredEndpoints = const ['/api/items', '/api/info'],
    this.healthCheckInterval = const Duration(minutes: 2),
  }) {
    _initialize();
  }

  /// 后端基础URL（可配置）
  final String backendBaseUrl;
  /// 必需的API端点列表
  final List<String> requiredEndpoints;
  /// 健康检查间隔
  final Duration healthCheckInterval;

  TaskService? _taskService;
  Timer? _healthCheckTimer;
  
  // 当前状态缓存
  SliceSummaryContract? _cachedSummary;
  DateTime? _lastUpdateTime;
  
  // 后端服务状态
  BackendServiceInfo _backendServiceInfo = const BackendServiceInfo(
    name: 'demo-backend',
    baseUrl: 'http://localhost:8080',
    status: BackendHealthStatus.unknown,
  );

  /// 初始化
  void _initialize() {
    try {
      _taskService = ServiceLocator.instance.get<TaskService>();
    } catch (e) {
      // 如果服务未注册，忽略错误
      debugPrint('TaskService未注册，使用模拟数据');
    }

    // 监听任务事件，实时更新摘要
    _setupEventListeners();
    
    // 开始后端健康检查
    _startBackendHealthCheck();
  }

  /// 开始后端健康检查
  void _startBackendHealthCheck() {
    // 立即检查一次
    _checkBackendHealth();
    
    // 定期检查
    _healthCheckTimer = Timer.periodic(healthCheckInterval, (_) {
      _checkBackendHealth();
    });
  }

  /// 检查后端健康状态
  Future<void> _checkBackendHealth() async {
    try {
      _backendServiceInfo = _backendServiceInfo.copyWith(
        status: BackendHealthStatus.checking,
      );

      final checkedEndpoints = <String>[];
      final responseTimes = <int>[];
      String? errorMessage;

      // 检查每个必需的端点
      for (final endpoint in requiredEndpoints) {
        try {
          final stopwatch = Stopwatch()..start();
          final response = await http.get(
            Uri.parse('$backendBaseUrl$endpoint'),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 10));
          
          stopwatch.stop();
          
          if (response.statusCode == 200) {
            checkedEndpoints.add(endpoint);
            responseTimes.add(stopwatch.elapsedMilliseconds);
          } else {
            errorMessage = 'API $endpoint 返回状态码 ${response.statusCode}';
            break;
          }
        } catch (e) {
          errorMessage = 'API $endpoint 检查失败: ${e.toString()}';
          break;
        }
      }

      // 确定健康状态
      BackendHealthStatus status;
      if (checkedEndpoints.length == requiredEndpoints.length) {
        final avgResponseTime = responseTimes.isEmpty 
            ? 0 
            : responseTimes.reduce((a, b) => a + b) ~/ responseTimes.length;
        
        if (avgResponseTime < 1000) {
          status = BackendHealthStatus.healthy;
        } else {
          status = BackendHealthStatus.warning;
          errorMessage = '响应时间较慢 (${avgResponseTime}ms)';
        }
      } else {
        status = BackendHealthStatus.error;
      }

      _backendServiceInfo = _backendServiceInfo.copyWith(
        status: status,
        responseTime: responseTimes.isEmpty ? null : responseTimes.first,
        lastCheckTime: DateTime.now(),
        errorMessage: errorMessage,
        checkedEndpoints: checkedEndpoints,
      );

      // 清除缓存，触发UI更新
      _cachedSummary = null;
      
    } catch (e) {
      _backendServiceInfo = _backendServiceInfo.copyWith(
        status: BackendHealthStatus.error,
        lastCheckTime: DateTime.now(),
        errorMessage: '健康检查异常: ${e.toString()}',
      );
    }
  }

  /// 设置事件监听器
  void _setupEventListeners() {
    // 监听任务相关事件，清除缓存，强制下次获取时重新计算
    eventBus.on<TasksLoadedEvent>((event) {
      _cachedSummary = null;
    });
    
    eventBus.on<TaskCreatedEvent>((event) {
      _cachedSummary = null;
    });
    
    eventBus.on<TaskToggledEvent>((event) {
      _cachedSummary = null;
    });
    
    eventBus.on<TaskDeletedEvent>((event) {
      _cachedSummary = null;
    });
    
    eventBus.on<TaskErrorEvent>((event) {
      _cachedSummary = null;
    });
  }

  @override
  Future<SliceSummaryContract> getSummaryData() async {
    // 缓存策略：30秒内使用缓存数据
    if (_cachedSummary != null && 
        _lastUpdateTime != null &&
        DateTime.now().difference(_lastUpdateTime!).inSeconds < 30) {
      return _cachedSummary!;
    }

    try {
      // 获取任务统计数据
      final summary = await _generateSummaryData();
      
      // 更新缓存
      _cachedSummary = summary;
      _lastUpdateTime = DateTime.now();
      
      return summary;
    } catch (error) {
      debugPrint('获取Demo切片摘要数据失败: $error');
      return _getErrorSummary(error.toString());
    }
  }

  /// 生成摘要数据
  Future<SliceSummaryContract> _generateSummaryData() async {
    if (_taskService == null) {
      return _getOfflineSummary();
    }

    try {
      // 获取当前任务状态
      final currentState = _taskService!.currentState;
      final tasks = currentState.tasks;
      
      final totalTasks = tasks.length;
      final completedTasks = tasks.where((task) => task.isCompleted).length;
      final pendingTasks = totalTasks - completedTasks;
      final completionRate = totalTasks > 0 
          ? (completedTasks / totalTasks * 100).round() 
          : 0;

      // 判断系统状态（结合后端状态）
      SliceStatus status;
      if (currentState.isLoading) {
        status = SliceStatus.loading;
      } else if (currentState.error != null || !_backendServiceInfo.isAvailable) {
        status = SliceStatus.error;
      } else if (pendingTasks > 10 || _backendServiceInfo.status == BackendHealthStatus.warning) {
        status = SliceStatus.warning;
      } else {
        status = SliceStatus.healthy;
      }

      // 构建指标数据
      final metrics = [
        SliceMetric(
          label: '总任务数',
          value: totalTasks,
          trend: _getTrend(totalTasks, 'total'),
          icon: '📋',
          unit: '个',
        ),
        SliceMetric(
          label: '已完成',
          value: completedTasks,
          trend: _getTrend(completedTasks, 'completed'),
          icon: '✅',
          unit: '个',
        ),
        SliceMetric(
          label: '待完成',
          value: pendingTasks,
          trend: _getTrend(pendingTasks, 'pending'),
          icon: '⏳',
          unit: '个',
        ),
        SliceMetric(
          label: '完成率',
          value: '$completionRate%',
          trend: _getTrend(completionRate, 'rate'),
          icon: '📊',
        ),
        // 添加后端状态指标
        SliceMetric(
          label: '后端状态',
          value: _backendServiceInfo.statusDescription,
          trend: _backendServiceInfo.isAvailable ? 'up' : 'down',
          icon: _backendServiceInfo.isAvailable ? '🟢' : '🔴',
        ),
      ];

      // 构建自定义操作
      final customActions = [
        SliceAction(
          label: '新建任务',
          onPressed: () {
            // 发布创建任务事件
            eventBus.emit(UIRequestCreateTaskEvent());
          },
          icon: '➕',
          variant: SliceActionVariant.primary,
        ),
        SliceAction(
          label: '刷新数据',
          onPressed: () async {
            await refreshData();
          },
          icon: '🔄',
          variant: SliceActionVariant.secondary,
        ),
        SliceAction(
          label: '检查后端',
          onPressed: () async {
            await _checkBackendHealth();
          },
          icon: '🔍',
          variant: SliceActionVariant.secondary,
        ),
      ];

      return SliceSummaryContract(
        title: '任务管理',
        status: status,
        metrics: metrics,
        description: _getStatusDescription(status, totalTasks, pendingTasks),
        lastUpdated: DateTime.now(),
        alertCount: pendingTasks > 10 ? 1 : 0,
        customActions: customActions,
        backendService: _backendServiceInfo, // 包含后端服务信息
      );
    } catch (error) {
      return _getErrorSummary(error.toString());
    }
  }

  /// 获取离线模式摘要
  SliceSummaryContract _getOfflineSummary() {
    return SliceSummaryContract(
      title: '任务管理',
      status: SliceStatus.warning,
      metrics: [
        const SliceMetric(
          label: '模式',
          value: '演示模式',
          trend: 'stable',
          icon: '🔒',
        ),
        SliceMetric(
          label: '后端状态',
          value: _backendServiceInfo.statusDescription,
          trend: _backendServiceInfo.isAvailable ? 'up' : 'down',
          icon: _backendServiceInfo.isAvailable ? '🟢' : '🔴',
        ),
      ],
      description: '当前运行在演示模式下，数据仅供展示',
      lastUpdated: DateTime.now(),
      alertCount: 1,
      customActions: [
        SliceAction(
          label: '检查后端',
          onPressed: () async {
            await _checkBackendHealth();
          },
          icon: '🔍',
          variant: SliceActionVariant.secondary,
        ),
      ],
      backendService: _backendServiceInfo,
    );
  }

  /// 获取错误状态摘要
  SliceSummaryContract _getErrorSummary(String error) {
    return SliceSummaryContract(
      title: '任务管理',
      status: SliceStatus.error,
      metrics: [
        const SliceMetric(
          label: '状态',
          value: '错误',
          trend: 'down',
          icon: '❌',
        ),
        SliceMetric(
          label: '错误时间',
          value: DateTime.now().toLocal().toString().substring(11, 19),
          trend: 'stable',
          icon: '⏰',
        ),
      ],
      description: '获取任务数据时发生错误: $error',
      lastUpdated: DateTime.now(),
      alertCount: 1,
      customActions: [
        SliceAction(
          label: '重试',
          onPressed: () async {
            await refreshData();
          },
          icon: '🔄',
          variant: SliceActionVariant.primary,
        ),
      ],
    );
  }

  /// 获取状态描述
  String _getStatusDescription(SliceStatus status, int total, int pending) {
    switch (status) {
      case SliceStatus.healthy:
        return '任务管理运行正常，当前有 $total 个任务';
      case SliceStatus.warning:
        return '待完成任务较多（$pending 个），建议及时处理';
      case SliceStatus.error:
        return '任务数据获取失败，请检查网络连接';
      case SliceStatus.loading:
        return '正在加载任务数据...';
    }
  }

  /// 获取趋势指标（简化实现）
  String? _getTrend(dynamic value, String type) {
    // 简化的趋势计算逻辑
    // 实际项目中可以基于历史数据计算趋势
    switch (type) {
      case 'total':
        final numValue = value is int ? value : (int.tryParse(value.toString()) ?? 0);
        return numValue > 5 ? 'up' : 'stable';
      case 'completed':
        final numValue = value is int ? value : (int.tryParse(value.toString()) ?? 0);
        return numValue > 0 ? 'up' : 'stable';
      case 'pending':
        final numValue = value is int ? value : (int.tryParse(value.toString()) ?? 0);
        return numValue > 10 ? 'warning' : 'stable';
      case 'rate':
        final rate = int.tryParse(value.toString().replaceAll('%', '')) ?? 0;
        if (rate >= 80) return 'up';
        if (rate <= 30) return 'down';
        return 'stable';
      default:
        return 'stable';
    }
  }

  @override
  Future<void> refreshData() async {
    // 清除缓存
    _cachedSummary = null;
    _lastUpdateTime = null;
    
    // 如果有任务服务，触发数据刷新
    if (_taskService != null) {
      try {
        await _taskService!.loadTasks();
      } catch (error) {
        debugPrint('刷新任务数据失败: $error');
      }
    }
    
    // 发布刷新事件
    eventBus.emit(DemoSummaryRefreshedEvent(
      totalTasks: _taskService?.currentState.tasks.length ?? 0,
      completedTasks: _taskService?.currentState.tasks.where((t) => t.isCompleted).length ?? 0,
    ));
  }

  @override
  Future<void> startBackgroundSync() async {
    // Demo切片的后台同步实现
    debugPrint('Demo切片开始后台同步');
  }

  @override
  Future<void> stopBackgroundSync() async {
    // Demo切片的停止后台同步实现
    debugPrint('Demo切片停止后台同步');
  }

  @override
  Future<void> triggerSync() async {
    // Demo切片的手动同步实现
    debugPrint('Demo切片触发手动同步');
    await refreshData();
  }

  @override
  Stream<SliceSyncInfo>? get syncStatusStream => null;

  /// 释放资源
  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _taskService = null;
    _cachedSummary = null;
    _lastUpdateTime = null;
  }
} 