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

import '../../shared/contracts/slice_summary_contract.dart';
import '../../shared/events/event_bus.dart';
import '../../shared/services/service_locator.dart';
import 'service.dart';
import 'models.dart';

/// Demo任务管理切片摘要提供者
class DemoTaskSummaryProvider implements SliceSummaryProvider {
  DemoTaskSummaryProvider() {
    _initialize();
  }

  TaskService? _taskService;
  
  // 当前状态缓存
  SliceSummaryContract? _cachedSummary;
  DateTime? _lastUpdateTime;

  /// 初始化
  void _initialize() {
    try {
      _taskService = ServiceLocator.get<TaskService>();
    } catch (e) {
      // 如果服务未注册，忽略错误
      debugPrint('TaskService未注册，使用模拟数据');
    }

    // 监听任务事件，实时更新摘要
    // 注意：EventBus没有直接的stream，需要通过on方法监听特定事件
    _setupEventListeners();
  }

  /// 设置事件监听器
  void _setupEventListeners() {
    // 监听任务相关的各种事件
    final taskEvents = [
      'tasks:loaded',
      'task:created',
      'task:toggled', 
      'task:deleted',
      'task:error'
    ];

    for (final eventType in taskEvents) {
      eventBus.on(eventType, (data) {
        // 清除缓存，强制下次获取时重新计算
        _cachedSummary = null;
      });
    }
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

      // 判断系统状态
      SliceStatus status;
      if (currentState.isLoading) {
        status = SliceStatus.loading;
      } else if (currentState.error != null) {
        status = SliceStatus.error;
      } else if (pendingTasks > 10) {
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
      ];

      // 构建自定义操作
      final customActions = [
        SliceAction(
          label: '新建任务',
          onPressed: () {
            // 发布创建任务事件
            eventBus.emit('ui:request_create_task', {});
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
      ];

      return SliceSummaryContract(
        title: '任务管理',
        status: status,
        metrics: metrics,
        description: _getStatusDescription(status, totalTasks, pendingTasks),
        lastUpdated: DateTime.now(),
        alertCount: pendingTasks > 10 ? 1 : 0,
        customActions: customActions,
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
        const SliceMetric(
          label: '状态',
          value: '离线',
          trend: 'stable',
          icon: '📱',
        ),
      ],
      description: '当前运行在演示模式下，数据为模拟数据',
      lastUpdated: DateTime.now(),
      alertCount: 0,
      customActions: [
        SliceAction(
          label: '查看详情',
          onPressed: () {
            eventBus.emit('ui:navigate_to_slice', {'slice': 'demo'});
          },
          icon: '👀',
          variant: SliceActionVariant.secondary,
        ),
      ],
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
    eventBus.emit('demo:summary_refreshed', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  void dispose() {
    // 注意：当前EventBus设计不支持返回StreamSubscription
    // 这里只是清理内部状态
    _taskService = null;
    _cachedSummary = null;
    _lastUpdateTime = null;
  }
} 