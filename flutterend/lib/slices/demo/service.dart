import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../shared/events/event_bus.dart';
import '../../shared/events/events.dart';
import '../../shared/services/service_locator.dart';
import 'models.dart';
import 'repository.dart';

/// Demo切片的业务逻辑层
/// 封装任务相关的业务逻辑，处理状态变化和事件发布

class TaskService {
  final TaskRepository _repository;
  final StreamController<TasksState> _stateController = StreamController.broadcast();
  final bool _autoRegister;
  
  TasksState _currentState = const TasksState();

  TaskService({bool autoRegister = true}) 
      : _repository = TaskRepositoryImpl(),
        _autoRegister = autoRegister {
    if (_autoRegister) {
    _initialize();
    }
  }

  /// 创建不自动注册的TaskService实例
  TaskService.withoutAutoRegister() : this(autoRegister: false);

  /// 状态流
  Stream<TasksState> get stateStream => _stateController.stream;
  
  /// 当前状态
  TasksState get currentState => _currentState;

  void _initialize() {
    // 注册服务到ServiceLocator
    if (!ServiceLocator.instance.isRegistered<TaskService>()) {
      ServiceLocator.instance.registerSingleton<TaskService>(this);
      if (kDebugMode) {
        debugPrint('✅ TaskService已自动注册到ServiceLocator');
      }
    }
  }

  /// 加载任务列表
  Future<void> loadTasks() async {
    try {
      _updateState(_currentState.copyWith(isLoading: true, error: null));
      
      final tasks = await _repository.getTasks();
      
      _updateState(_currentState.copyWith(
        tasks: tasks,
        isLoading: false,
        error: null,
      ));

      // 发布任务加载事件
      EventBus.instance.emit(TasksLoadedEvent(count: tasks.length));
      
      if (kDebugMode) {
        debugPrint('✅ 任务列表加载成功，共${tasks.length}个任务');
      }
      
    } catch (e) {
      _updateState(_currentState.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
      
      // 发布错误事件
      EventBus.instance.emit(TaskErrorEvent(error: e.toString()));
      
      if (kDebugMode) {
        debugPrint('❌ 任务列表加载失败: $e');
      }
    }
  }

  /// 创建任务
  Future<void> createTask(CreateTaskRequest request) async {
    try {
      final newTask = await _repository.createTask(request);
      
      final updatedTasks = [..._currentState.tasks, newTask];
      _updateState(_currentState.copyWith(tasks: updatedTasks));
      
      // 发布任务创建事件
      EventBus.instance.emit(TaskCreatedEvent(
        taskId: newTask.id,
        title: newTask.title,
      ));
      
    } catch (e) {
      _updateState(_currentState.copyWith(error: e.toString()));
      
      // 发布错误事件
      EventBus.instance.emit(TaskErrorEvent(error: e.toString()));
      rethrow;
    }
  }

  /// 切换任务完成状态
  Future<void> toggleTaskCompletion(String taskId) async {
    try {
      final taskIndex = _currentState.tasks.indexWhere((t) => t.id == taskId);
      if (taskIndex == -1) return;

      final task = _currentState.tasks[taskIndex];
      final updatedTask = task.copyWith(
        isCompleted: !task.isCompleted,
        updatedAt: DateTime.now(),
      );

      await _repository.updateTask(taskId, updatedTask);

      final updatedTasks = [..._currentState.tasks];
      updatedTasks[taskIndex] = updatedTask;
      _updateState(_currentState.copyWith(tasks: updatedTasks));

      // 发布任务状态变化事件
      EventBus.instance.emit(TaskToggledEvent(
        taskId: taskId,
        isCompleted: updatedTask.isCompleted,
      ));
      
    } catch (e) {
      _updateState(_currentState.copyWith(error: e.toString()));
      
      // 发布错误事件
      EventBus.instance.emit(TaskErrorEvent(error: e.toString()));
    }
  }

  /// 删除任务
  Future<void> deleteTask(String taskId) async {
    try {
      await _repository.deleteTask(taskId);
      
      final updatedTasks = _currentState.tasks.where((t) => t.id != taskId).toList();
      _updateState(_currentState.copyWith(tasks: updatedTasks));
      
      // 发布任务删除事件
      EventBus.instance.emit(TaskDeletedEvent(taskId: taskId));
      
    } catch (e) {
      _updateState(_currentState.copyWith(error: e.toString()));
      
      // 发布错误事件
      EventBus.instance.emit(TaskErrorEvent(error: e.toString()));
      rethrow;
    }
  }

  /// 获取已完成任务数量
  int get completedTasksCount {
    return _currentState.tasks.where((task) => task.isCompleted).length;
  }

  /// 获取待完成任务数量
  int get pendingTasksCount {
    return _currentState.tasks.where((task) => !task.isCompleted).length;
  }

  /// 获取完成率（百分比）
  double get completionRate {
    if (_currentState.tasks.isEmpty) return 0.0;
    return (completedTasksCount / _currentState.tasks.length) * 100;
  }

  /// 更新状态并通知监听者
  void _updateState(TasksState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  /// 释放资源
  void dispose() {
    _stateController.close();
  }
} 