import 'dart:async';
import '../../shared/events/event_bus.dart';
import '../../shared/services/service_locator.dart';
import 'models.dart';
import 'repository.dart';

/// Demo切片的业务逻辑层
/// 封装任务相关的业务逻辑，处理状态变化和事件发布

class TaskService {
  final TaskRepository _repository;
  final StreamController<TasksState> _stateController = StreamController.broadcast();
  
  TasksState _currentState = const TasksState();

  TaskService() : _repository = TaskRepositoryImpl() {
    _initialize();
  }

  /// 状态流
  Stream<TasksState> get stateStream => _stateController.stream;
  
  /// 当前状态
  TasksState get currentState => _currentState;

  void _initialize() {
    // 注册服务到ServiceLocator
    if (!ServiceLocator.isRegistered<TaskService>()) {
      ServiceLocator.register<TaskService>(this);
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
      EventBus.instance.emit('tasks:loaded', {'count': tasks.length});
      
    } catch (e) {
      _updateState(_currentState.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
      
      // 发布错误事件
      EventBus.instance.emit('tasks:error', {'error': e.toString()});
    }
  }

  /// 创建任务
  Future<void> createTask(CreateTaskRequest request) async {
    try {
      final newTask = await _repository.createTask(request);
      
      final updatedTasks = [..._currentState.tasks, newTask];
      _updateState(_currentState.copyWith(tasks: updatedTasks));
      
      // 发布任务创建事件
      EventBus.instance.emit('task:created', {
        'task': newTask.toJson(),
        'title': newTask.title,
      });
      
    } catch (e) {
      _updateState(_currentState.copyWith(error: e.toString()));
      
      // 发布错误事件
      EventBus.instance.emit('task:error', {'error': e.toString()});
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
      EventBus.instance.emit('task:toggled', {
        'taskId': taskId,
        'isCompleted': updatedTask.isCompleted,
        'title': updatedTask.title,
      });
      
    } catch (e) {
      _updateState(_currentState.copyWith(error: e.toString()));
      
      // 发布错误事件
      EventBus.instance.emit('task:error', {'error': e.toString()});
    }
  }

  /// 删除任务
  Future<void> deleteTask(String taskId) async {
    try {
      await _repository.deleteTask(taskId);
      
      final updatedTasks = _currentState.tasks.where((t) => t.id != taskId).toList();
      _updateState(_currentState.copyWith(tasks: updatedTasks));
      
      // 发布任务删除事件
      EventBus.instance.emit('task:deleted', {
        'taskId': taskId,
        'remainingCount': updatedTasks.length,
      });
      
    } catch (e) {
      _updateState(_currentState.copyWith(error: e.toString()));
      
      // 发布错误事件
      EventBus.instance.emit('task:error', {'error': e.toString()});
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