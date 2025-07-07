import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/service_locator.dart';
import 'models.dart';
import 'service.dart';

/// Demo切片的Provider组件
/// 使用Riverpod进行状态管理和依赖注入

/// TaskService Provider - 修复版本
final taskServiceProvider = Provider<TaskService>((ref) {
  // 确保不会重复创建服务
  if (ServiceLocator.instance.isRegistered<TaskService>()) {
    return ServiceLocator.instance.get<TaskService>();
  }
  
  // 创建新的TaskService实例，但不在构造函数中自注册
  final service = TaskService.withoutAutoRegister();
  
  // 手动注册到ServiceLocator
    ServiceLocator.instance.registerSingleton<TaskService>(service);
  
  if (kDebugMode) {
    debugPrint('✅ TaskService创建并注册成功');
  }
  
  return service;
});

/// TasksState Provider - 监听TaskService的状态变化
final tasksStateProvider = StreamProvider<TasksState>((ref) {
  final taskService = ref.watch(taskServiceProvider);
  
  // 确保服务已初始化，如果没有数据则触发加载
  if (taskService.currentState.tasks.isEmpty && !taskService.currentState.isLoading) {
    // 使用Future.microtask避免在build过程中修改状态
    Future.microtask(() {
      taskService.loadTasks();
    });
  }
  
  return taskService.stateStream;
});

/// 当前任务列表Provider
final tasksProvider = Provider<List<Task>>((ref) {
  final asyncState = ref.watch(tasksStateProvider);
  return asyncState.when(
    data: (state) => state.tasks,
    loading: () => [],
    error: (_, __) => [],
  );
});

/// 加载状态Provider
final tasksLoadingProvider = Provider<bool>((ref) {
  final asyncState = ref.watch(tasksStateProvider);
  return asyncState.when(
    data: (state) => state.isLoading,
    loading: () => true,
    error: (_, __) => false,
  );
});

/// 错误状态Provider
final tasksErrorProvider = Provider<String?>((ref) {
  final asyncState = ref.watch(tasksStateProvider);
  return asyncState.when(
    data: (state) => state.error,
    loading: () => null,
    error: (error, _) => error.toString(),
  );
});

/// 已完成任务数量Provider
final completedTasksCountProvider = Provider<int>((ref) {
  final tasks = ref.watch(tasksProvider);
  return tasks.where((task) => task.isCompleted).length;
});

/// 待完成任务数量Provider
final pendingTasksCountProvider = Provider<int>((ref) {
  final tasks = ref.watch(tasksProvider);
  return tasks.where((task) => !task.isCompleted).length;
});

/// 任务完成率Provider
final taskCompletionRateProvider = Provider<double>((ref) {
  final tasks = ref.watch(tasksProvider);
  final completedCount = ref.watch(completedTasksCountProvider);
  
  if (tasks.isEmpty) return 0.0;
  return (completedCount / tasks.length) * 100;
});

/// 任务操作Provider - 封装常用操作
final taskActionsProvider = Provider<TaskActions>((ref) {
  final taskService = ref.watch(taskServiceProvider);
  return TaskActions(taskService);
});

/// 任务操作类
class TaskActions {
  final TaskService _taskService;

  TaskActions(this._taskService);

  /// 加载任务列表
  Future<void> loadTasks() async {
    try {
      await _taskService.loadTasks();
      if (kDebugMode) {
        debugPrint('✅ 任务列表加载成功');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 任务列表加载失败: $e');
      }
      rethrow;
    }
  }

  /// 创建新任务
  Future<void> createTask(String title, String description) async {
    try {
    final request = CreateTaskRequest(title: title, description: description);
      await _taskService.createTask(request);
      if (kDebugMode) {
        debugPrint('✅ 任务创建成功: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 任务创建失败: $e');
      }
      rethrow;
    }
  }

  /// 切换任务完成状态
  Future<void> toggleTask(String taskId) async {
    try {
      await _taskService.toggleTaskCompletion(taskId);
      if (kDebugMode) {
        debugPrint('✅ 任务状态切换成功: $taskId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 任务状态切换失败: $e');
      }
      rethrow;
    }
  }

  /// 删除任务
  Future<void> deleteTask(String taskId) async {
    try {
      await _taskService.deleteTask(taskId);
      if (kDebugMode) {
        debugPrint('✅ 任务删除成功: $taskId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 任务删除失败: $e');
      }
      rethrow;
    }
  }
} 