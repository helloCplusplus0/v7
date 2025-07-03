import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/service_locator.dart';
import 'models.dart';
import 'service.dart';

/// Demo切片的Provider组件
/// 使用Riverpod进行状态管理和依赖注入

/// TaskService Provider
final taskServiceProvider = Provider<TaskService>((ref) {
  // 从ServiceLocator获取或创建TaskService实例
  if (ServiceLocator.isRegistered<TaskService>()) {
    return ServiceLocator.get<TaskService>();
  } else {
    final service = TaskService();
    ServiceLocator.register<TaskService>(service);
    return service;
  }
});

/// TasksState Provider - 监听TaskService的状态变化
final tasksStateProvider = StreamProvider<TasksState>((ref) {
  final taskService = ref.watch(taskServiceProvider);
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
  Future<void> loadTasks() => _taskService.loadTasks();

  /// 创建新任务
  Future<void> createTask(String title, String description) {
    final request = CreateTaskRequest(title: title, description: description);
    return _taskService.createTask(request);
  }

  /// 切换任务完成状态
  Future<void> toggleTask(String taskId) => _taskService.toggleTaskCompletion(taskId);

  /// 删除任务
  Future<void> deleteTask(String taskId) => _taskService.deleteTask(taskId);
} 