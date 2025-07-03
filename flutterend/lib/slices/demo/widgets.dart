import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'models.dart';
import 'providers.dart';

/// Demo切片UI组件
/// 任务管理界面，展示v7功能切片的完整实现

class TasksWidget extends ConsumerStatefulWidget {
  const TasksWidget({super.key});

  @override
  ConsumerState<TasksWidget> createState() => _TasksWidgetState();
}

class _TasksWidgetState extends ConsumerState<TasksWidget> 
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化页面进入动画
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.fastOutSlowIn,
    ));
    
    // 初始化时加载任务并启动动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskActionsProvider).loadTasks();
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final isLoading = ref.watch(tasksLoadingProvider);
    final error = ref.watch(tasksErrorProvider);
    final completedCount = ref.watch(completedTasksCountProvider);
    final pendingCount = ref.watch(pendingTasksCountProvider);
    final completionRate = ref.watch(taskCompletionRateProvider);

    return SlideTransition(
      position: _slideAnimation,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('任务管理'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          automaticallyImplyLeading: false, // 禁用自动返回按钮
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _refreshData(),
            ),
          ],
        ),
        body: Column(
          children: [
            // 统计信息卡片
            _buildStatsCard(completedCount, pendingCount, completionRate),
            
            // 错误提示
            if (error != null) _buildErrorCard(error),
            
            // 任务列表
            Expanded(
              child: isLoading && tasks.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : tasks.isEmpty
                      ? const Center(child: Text('暂无任务'))
                      : _buildTasksList(tasks),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateTaskDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  /// 🎯 数据刷新逻辑
  Future<void> _refreshData() async {
    try {
      await ref.read(taskActionsProvider).loadTasks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('数据已刷新'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刷新失败: $error'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 构建统计信息卡片
  Widget _buildStatsCard(int completed, int pending, double rate) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$completed',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('已完成'),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$pending',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('待完成'),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('完成率'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建错误卡片
  Widget _buildErrorCard(String error) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建任务列表
  Widget _buildTasksList(List<Task> tasks) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskItem(task);
      },
    );
  }

  /// 构建单个任务项
  Widget _buildTaskItem(Task task) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (_) => ref.read(taskActionsProvider).toggleTask(task.id),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty)
              Text(task.description),
            const SizedBox(height: 4),
            Text(
              '创建: ${_formatDate(task.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _confirmDelete(task);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('删除'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示创建任务对话框
  void _showCreateTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建新任务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: '描述 (可选)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();
              
              if (title.isNotEmpty) {
                ref.read(taskActionsProvider).createTask(title, description);
                Navigator.of(context).pop();
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  /// 确认删除
  void _confirmDelete(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务 "${task.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(taskActionsProvider).deleteTask(task.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
} 