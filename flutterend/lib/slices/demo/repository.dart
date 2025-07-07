import '../../shared/network/api_client.dart';
import '../../shared/services/service_locator.dart';
import 'models.dart';

/// Demo切片的数据访问层
/// 负责与backend API交互，处理网络请求和本地缓存

abstract class TaskRepository {
  Future<List<Task>> getTasks();
  Future<Task> getTask(String id);
  Future<Task> createTask(CreateTaskRequest request);
  Future<Task> updateTask(String id, Task task);
  Future<void> deleteTask(String id);
}

class TaskRepositoryImpl implements TaskRepository {
  final ApiClient _apiClient;

  TaskRepositoryImpl() : _apiClient = ServiceLocator.instance.get<ApiClient>();

  @override
  Future<List<Task>> getTasks() async {
    try {
      final response = await _apiClient.get<List<dynamic>>('/tasks');
      final data = response.data as List<dynamic>;
      return data.map((json) => Task.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      // 模拟离线场景，返回本地模拟数据
      return _getMockTasks();
    }
  }

  @override
  Future<Task> getTask(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/tasks/$id');
      return Task.fromJson(response.data!);
    } catch (e) {
      // 模拟数据
      final mockTasks = _getMockTasks();
      final task = mockTasks.firstWhere(
        (t) => t.id == id,
        orElse: () => throw Exception('Task not found'),
      );
      return task;
    }
  }

  @override
  Future<Task> createTask(CreateTaskRequest request) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/tasks',
        data: request.toJson(),
      );
      return Task.fromJson(response.data!);
    } catch (e) {
      // 模拟创建成功
      return Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: request.title,
        description: request.description,
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<Task> updateTask(String id, Task task) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        '/tasks/$id',
        data: task.toJson(),
      );
      return Task.fromJson(response.data!);
    } catch (e) {
      // 模拟更新成功
      return task.copyWith(updatedAt: DateTime.now());
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      await _apiClient.delete('/tasks/$id');
    } catch (e) {
      // 模拟删除成功（静默处理）
    }
  }

  /// 获取模拟数据
  /// 在没有backend连接时提供演示数据
  List<Task> _getMockTasks() {
    final now = DateTime.now();
    return [
      Task(
        id: '1',
        title: '学习Flutter v7架构',
        description: '深入理解切片独立性、四种解耦通信机制和离线优先架构',
        isCompleted: false,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      Task(
        id: '2',
        title: '实现功能切片',
        description: '创建具备完整功能的应用模块，利用backend API',
        isCompleted: true,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      Task(
        id: '3',
        title: '测试通信机制',
        description: '验证事件驱动、契约接口、状态管理和Provider模式',
        isCompleted: false,
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
    ];
  }
} 