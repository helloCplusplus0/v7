import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/shared/sync/background_task_executor.dart';
import '../../lib/shared/types/result.dart';
import '../../lib/shared/events/event_bus.dart';

void main() {
  group('BackgroundTaskExecutor', () {
    late BackgroundTaskExecutor executor;
    late EventBus eventBus;

    setUp(() {
      eventBus = EventBus.instance;
      executor = BackgroundTaskExecutor(
        maxConcurrentTasks: 2,
        eventBus: eventBus,
      );
    });

    tearDown(() async {
      await executor.dispose();
    });

    test('should execute task successfully', () async {
      final task = _TestTask('task1');
      
      final result = await executor.submitTask(task);
      expect(result.isSuccess, true);
      
      final taskId = result.valueOrNull!;
      
      // 等待任务完成
      await Future.delayed(const Duration(milliseconds: 100));
      
      final taskInstance = executor.getTask(taskId);
      expect(taskInstance?.status, TaskStatus.completed);
    });

    test('should handle task failure', () async {
      final task = _FailingTask('failing_task');
      
      final result = await executor.submitTask(task);
      expect(result.isSuccess, true);
      
      final taskId = result.valueOrNull!;
      
      // 等待任务完成或重试
      await Future.delayed(const Duration(milliseconds: 200));
      
      final taskInstance = executor.getTask(taskId);
      // 任务可能处于失败或重试状态
      expect(taskInstance?.status, isIn([TaskStatus.failed, TaskStatus.retrying]));
    });

    test('should cancel task', () async {
      final task = _SlowTask('slow_task');
      
      final result = await executor.submitTask(task);
      expect(result.isSuccess, true);
      
      final taskId = result.valueOrNull!;
      
      // 立即取消任务
      await executor.cancelTask(taskId);
      
      final taskInstance = executor.getTask(taskId);
      expect(taskInstance?.status, TaskStatus.cancelled);
    });
  });

  group('CancellationToken', () {
    test('should cancel properly', () {
      final token = CancellationToken();
      
      expect(token.isCancelled, false);
      
      token.cancel();
      expect(token.isCancelled, true);
    });

    test('should call cancellation callbacks', () {
      final token = CancellationToken();
      bool callbackCalled = false;
      
      token.onCancelled(() {
        callbackCalled = true;
      });
      
      token.cancel();
      expect(callbackCalled, true);
    });
  });
}

// Test task implementations

class _TestTask extends BackgroundTask {
  _TestTask(this._id);
  
  final String _id;
  
  @override
  String get id => _id;
  
  @override
  String get name => _id;
  
  @override
  String get description => 'Test task $_id';
  
  @override
  TaskPriority get priority => TaskPriority.normal;
  
  @override
  Future<AppResult<dynamic>> execute(TaskExecutionContext context) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return AppResult.success('$_id executed');
  }
}

class _FailingTask extends BackgroundTask {
  _FailingTask(this._id);
  
  final String _id;
  
  @override
  String get id => _id;
  
  @override
  String get name => _id;
  
  @override
  String get description => 'Failing task $_id';
  
  @override
  TaskPriority get priority => TaskPriority.normal;
  
  @override
  Future<AppResult<dynamic>> execute(TaskExecutionContext context) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return AppResult.failure(BusinessError('Task failed: $_id'));
  }
}

class _SlowTask extends BackgroundTask {
  _SlowTask(this._id);
  
  final String _id;
  
  @override
  String get id => _id;
  
  @override
  String get name => _id;
  
  @override
  String get description => 'Slow task $_id';
  
  @override
  TaskPriority get priority => TaskPriority.normal;
  
  @override
  Future<AppResult<dynamic>> execute(TaskExecutionContext context) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return AppResult.success('$_id completed');
  }
} 