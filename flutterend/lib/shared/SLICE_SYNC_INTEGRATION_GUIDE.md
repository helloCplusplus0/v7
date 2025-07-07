# 切片级别后台同步集成指南

## 🎯 设计理念

基于对现有架构的深入分析，我们推荐采用**切片级别按需集成**的后台同步策略，而不是整体集成。

### 为什么选择切片级别集成？

| 维度 | 切片级别集成 | 整体集成 |
|------|-------------|----------|
| **符合v7架构** | ✅ 完全符合切片独立性 | ❌ 违反切片独立性原则 |
| **开发效率** | ✅ 切片独立开发和部署 | ❌ 需要修改全局基础设施 |
| **维护复杂度** | ✅ 切片内部维护 | ❌ 全局维护，影响面大 |
| **性能影响** | ✅ 按需同步，性能更好 | ❌ 全局同步，资源消耗大 |
| **用户体验** | ✅ 精确的状态反馈 | ❌ 笼统的状态信息 |
| **测试难度** | ✅ 独立测试 | ❌ 集成测试复杂 |
| **部署灵活性** | ✅ 支持切片独立部署 | ❌ 需要整体部署 |

## 🏗️ 架构设计

### 现有基础设施保持不变

1. **全局网络状态横幅**：`NetworkStatusBanner` 继续提供统一的网络状态指示
2. **离线详情页面**：`OfflineDetailPage` 继续展示全局的网络和系统状态
3. **同步管理器**：`SyncManager` 等基础设施保持不变，作为共享服务

### 切片级别扩展

1. **切片摘要契约**：扩展 `SliceSummaryContract` 支持同步配置和状态
2. **切片同步混入**：`SliceSyncMixin` 提供切片级别的后台同步能力
3. **切片同步提供者**：`SliceSyncProvider` 处理切片特定的数据同步

## 🚀 快速开始

### 1. 基础集成

```dart
// 1. 扩展你的切片摘要提供者
class MySliceSummaryProvider extends SliceSummaryProvider with SliceSyncMixin {
  MySliceSummaryProvider(this._ref);
  
  final Ref _ref;

  @override
  String get sliceName => 'my_slice';

  @override
  SliceSyncConfig get syncConfig => const SliceSyncConfig(
    enableBackgroundSync: true,
    syncInterval: Duration(minutes: 15),
    syncOnNetworkRecover: true,
    syncOnAppResume: true,
    syncTypes: ['my_data_type'],
    syncPriority: OperationPriority.normal,
  );

  @override
  Future<SliceSummaryContract> getSummaryData() async {
    // 获取业务数据
    final businessData = await _getBusinessData();
    
    // 获取后端健康状态
    final backendInfo = await _checkBackendHealth();
    
    // 返回包含同步信息的摘要
    return SliceSummaryContract(
      title: '我的切片',
      status: SliceStatus.healthy,
      metrics: businessData,
      backendService: backendInfo,
      syncConfig: syncConfig,
      syncInfo: currentSyncInfo, // 来自SliceSyncMixin
    );
  }

  @override
  Future<void> performSliceSync(bool isManual) async {
    // 实现切片特定的同步逻辑
    debugPrint('🔄 执行切片同步: $sliceName (手动: $isManual)');
    
    // 示例：同步切片数据
    await _syncSliceData();
  }

  Future<void> _syncSliceData() async {
    // 具体的同步实现
    // 例如：从API获取数据，保存到本地数据库等
  }

  // 其他业务方法...
}
```

### 2. 高级集成（使用同步提供者）

```dart
// 1. 定义切片数据项
class MySliceDataItem extends SyncItem {
  const MySliceDataItem({
    required super.id,
    required super.lastModified,
    required super.data,
    super.checksum,
  }) : super(type: 'my_slice_data');

  factory MySliceDataItem.fromJson(Map<String, dynamic> json) {
    return MySliceDataItem(
      id: json['id'] as String,
      lastModified: DateTime.parse(json['lastModified'] as String),
      data: json['data'] as Map<String, dynamic>,
      checksum: json['checksum'] as String?,
    );
  }
}

// 2. 创建切片同步提供者
class MySliceSyncProvider extends SliceSyncProvider<MySliceDataItem> {
  MySliceSyncProvider({
    required this.apiClient,
    required this.localStorage,
  }) : super(
    sliceName: 'my_slice',
    dataType: 'my_slice_data',
  );

  final ApiClient apiClient;
  final LocalStorage localStorage;

  @override
  Future<List<MySliceDataItem>> getSliceLocalData() async {
    // 从本地存储获取数据
    final localData = await localStorage.getItems('my_slice_data');
    return localData.map((data) => MySliceDataItem.fromJson(data)).toList();
  }

  @override
  Future<List<MySliceDataItem>> getSliceRemoteData(DateTime? since) async {
    // 从API获取远程数据
    final response = await apiClient.get('/my-slice/data', queryParams: {
      if (since != null) 'since': since.toIso8601String(),
    });
    
    final List<dynamic> items = response.data['items'];
    return items.map((item) => MySliceDataItem.fromJson(item)).toList();
  }

  @override
  MySliceDataItem convertToSyncItem(Map<String, dynamic> data) {
    return MySliceDataItem.fromJson(data);
  }

  @override
  Map<String, dynamic> convertFromSyncItem(MySliceDataItem item) {
    return item.data;
  }

  @override
  Future<void> saveSliceData(Map<String, dynamic> data) async {
    await localStorage.setItem('my_slice_data_${data['id']}', data);
  }

  @override
  Future<Result<void, String>> uploadItem(MySliceDataItem item) async {
    try {
      await apiClient.post('/my-slice/data', data: item.data);
      return const Result.success(null);
    } catch (e) {
      return Result.failure('上传失败: $e');
    }
  }

  @override
  Future<Result<MySliceDataItem, String>> downloadItem(String id) async {
    try {
      final response = await apiClient.get('/my-slice/data/$id');
      final item = MySliceDataItem.fromJson(response.data);
      return Result.success(item);
    } catch (e) {
      return Result.failure('下载失败: $e');
    }
  }
}

// 3. 在摘要提供者中使用同步提供者
class MyAdvancedSliceSummaryProvider extends SliceSummaryProvider with SliceSyncMixin {
  MyAdvancedSliceSummaryProvider(this._ref) {
    _syncProvider = MySliceSyncProvider(
      apiClient: _ref.read(apiClientProvider),
      localStorage: _ref.read(localStorageProvider),
    );
  }

  final Ref _ref;
  late final MySliceSyncProvider _syncProvider;

  @override
  String get sliceName => 'my_advanced_slice';

  @override
  SliceSyncConfig get syncConfig => const SliceSyncConfig(
    enableBackgroundSync: true,
    syncInterval: Duration(minutes: 10),
    syncTypes: ['my_slice_data'],
    conflictResolution: ConflictResolution.merge,
  );

  @override
  SyncProvider? get syncProvider => _syncProvider;

  // 其他实现...
}
```

### 3. UI集成

切片卡片会自动显示同步状态：

```dart
// 切片卡片会显示：
// - 网络连接状态（来自全局监控）
// - 后端服务状态（来自BackendServiceInfo）
// - 同步状态（来自SliceSyncInfo）

// 在切片摘要中，可以添加同步相关的指标：
List<SliceMetric> _buildSyncMetrics() {
  final syncInfo = currentSyncInfo;
  
  return [
    SliceMetric(
      label: '同步状态',
      value: syncInfo.statusDescription,
      icon: _getSyncIcon(syncInfo.status),
      trend: syncInfo.hasError ? 'warning' : 'stable',
    ),
    if (syncInfo.lastSyncTime != null)
      SliceMetric(
        label: '最后同步',
        value: _formatLastSyncTime(syncInfo.lastSyncTime!),
        icon: '🕒',
      ),
    if (syncInfo.hasConflicts)
      SliceMetric(
        label: '冲突数量',
        value: syncInfo.conflictCount.toString(),
        icon: '⚠️',
        trend: 'warning',
      ),
  ];
}
```

## 📋 完整示例：TodoList切片

```dart
// 1. Todo数据模型
class TodoItem extends SyncItem {
  const TodoItem({
    required super.id,
    required super.lastModified,
    required this.title,
    required this.completed,
    super.checksum,
  }) : super(
    type: 'todo',
    data: const {},
  );

  final String title;
  final bool completed;

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      lastModified: DateTime.parse(json['lastModified'] as String),
      title: json['title'] as String,
      completed: json['completed'] as bool,
      checksum: json['checksum'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      'lastModified': lastModified.toIso8601String(),
      'checksum': checksum,
    };
  }
}

// 2. Todo同步提供者
class TodoSyncProvider extends SliceSyncProvider<TodoItem> {
  TodoSyncProvider({
    required this.apiClient,
    required this.database,
  }) : super(
    sliceName: 'todo_list',
    dataType: 'todo',
  );

  final ApiClient apiClient;
  final Database database;

  @override
  Future<List<TodoItem>> getSliceLocalData() async {
    final todos = await database.query('todos');
    return todos.map((todo) => TodoItem.fromJson(todo)).toList();
  }

  @override
  Future<List<TodoItem>> getSliceRemoteData(DateTime? since) async {
    final response = await apiClient.get('/todos', queryParams: {
      if (since != null) 'since': since.toIso8601String(),
    });
    
    final List<dynamic> todos = response.data['todos'];
    return todos.map((todo) => TodoItem.fromJson(todo)).toList();
  }

  @override
  TodoItem convertToSyncItem(Map<String, dynamic> data) {
    return TodoItem.fromJson(data);
  }

  @override
  Map<String, dynamic> convertFromSyncItem(TodoItem item) {
    return item.toJson();
  }

  @override
  Future<void> saveSliceData(Map<String, dynamic> data) async {
    await database.insert('todos', data);
  }

  @override
  Future<Result<void, String>> uploadItem(TodoItem item) async {
    try {
      await apiClient.post('/todos', data: item.toJson());
      return const Result.success(null);
    } catch (e) {
      return Result.failure('上传Todo失败: $e');
    }
  }

  @override
  Future<Result<TodoItem, String>> downloadItem(String id) async {
    try {
      final response = await apiClient.get('/todos/$id');
      final todo = TodoItem.fromJson(response.data);
      return Result.success(todo);
    } catch (e) {
      return Result.failure('下载Todo失败: $e');
    }
  }

  @override
  Future<Result<TodoItem, String>> mergeConflictItems(
    TodoItem localItem, 
    TodoItem remoteItem
  ) async {
    // 智能合并：保留最新的修改时间，合并标题和完成状态
    final merged = TodoItem(
      id: localItem.id,
      lastModified: localItem.lastModified.isAfter(remoteItem.lastModified)
          ? localItem.lastModified
          : remoteItem.lastModified,
      title: remoteItem.title, // 优先使用远程标题
      completed: localItem.completed || remoteItem.completed, // 任一完成即为完成
    );
    
    return Result.success(merged);
  }
}

// 3. Todo切片摘要提供者
class TodoSliceSummaryProvider extends SliceSummaryProvider with SliceSyncMixin {
  TodoSliceSummaryProvider(this._ref) {
    _syncProvider = TodoSyncProvider(
      apiClient: _ref.read(apiClientProvider),
      database: _ref.read(databaseProvider),
    );
    
    // 初始化同步
    initializeSync(_ref);
  }

  final Ref _ref;
  late final TodoSyncProvider _syncProvider;

  @override
  String get sliceName => 'todo_list';

  @override
  SliceSyncConfig get syncConfig => const SliceSyncConfig(
    enableBackgroundSync: true,
    syncInterval: Duration(minutes: 5),
    syncOnNetworkRecover: true,
    syncOnAppResume: true,
    syncTypes: ['todo'],
    syncPriority: OperationPriority.normal,
    conflictResolution: ConflictResolution.merge,
  );

  @override
  SyncProvider? get syncProvider => _syncProvider;

  @override
  Future<SliceSummaryContract> getSummaryData() async {
    // 获取Todo统计
    final todos = await _syncProvider.getSliceLocalData();
    final completedCount = todos.where((todo) => todo.completed).length;
    final totalCount = todos.length;
    
    // 检查后端健康状态
    final backendInfo = await _checkBackendHealth();
    
    // 构建指标
    final metrics = [
      SliceMetric(
        label: '总任务',
        value: totalCount.toString(),
        icon: '📝',
      ),
      SliceMetric(
        label: '已完成',
        value: completedCount.toString(),
        icon: '✅',
        trend: completedCount > 0 ? 'up' : 'stable',
      ),
      SliceMetric(
        label: '完成率',
        value: totalCount > 0 ? '${(completedCount / totalCount * 100).toInt()}%' : '0%',
        icon: '📊',
        unit: '%',
      ),
      // 添加同步相关指标
      ..._buildSyncMetrics(),
    ];

    return SliceSummaryContract(
      title: 'Todo列表',
      status: _determineSliceStatus(currentSyncInfo, backendInfo),
      metrics: metrics,
      description: '任务管理和同步',
      lastUpdated: DateTime.now(),
      customActions: [
        SliceAction(
          label: '手动同步',
          onPressed: () => triggerSync(),
          icon: '🔄',
          variant: SliceActionVariant.secondary,
        ),
        SliceAction(
          label: '添加任务',
          onPressed: () => _showAddTodoDialog(),
          icon: '➕',
          variant: SliceActionVariant.primary,
        ),
      ],
      backendService: backendInfo,
      syncConfig: syncConfig,
      syncInfo: currentSyncInfo,
    );
  }

  @override
  Future<void> performSliceSync(bool isManual) async {
    debugPrint('🔄 同步Todo数据 (手动: $isManual)');
    
    // 具体的同步逻辑由SyncProvider处理
    // 这里可以添加切片特定的同步前后处理
    
    // 同步完成后刷新UI
    refreshData();
  }

  List<SliceMetric> _buildSyncMetrics() {
    final syncInfo = currentSyncInfo;
    
    final metrics = <SliceMetric>[];
    
    // 同步状态
    metrics.add(SliceMetric(
      label: '同步状态',
      value: syncInfo.statusDescription,
      icon: _getSyncStatusIcon(syncInfo.status),
      trend: syncInfo.hasError ? 'warning' : 'stable',
    ));
    
    // 最后同步时间
    if (syncInfo.lastSyncTime != null) {
      metrics.add(SliceMetric(
        label: '最后同步',
        value: _formatRelativeTime(syncInfo.lastSyncTime!),
        icon: '🕒',
      ));
    }
    
    // 冲突数量
    if (syncInfo.hasConflicts) {
      metrics.add(SliceMetric(
        label: '冲突',
        value: syncInfo.conflictCount.toString(),
        icon: '⚠️',
        trend: 'warning',
      ));
    }
    
    return metrics;
  }

  SliceStatus _determineSliceStatus(SliceSyncInfo syncInfo, BackendServiceInfo? backendInfo) {
    // 优先级：同步错误 > 后端不可用 > 同步中 > 正常
    if (syncInfo.hasError) return SliceStatus.error;
    if (backendInfo != null && !backendInfo.isAvailable) return SliceStatus.error;
    if (syncInfo.isSyncing) return SliceStatus.loading;
    if (syncInfo.hasConflicts) return SliceStatus.warning;
    return SliceStatus.healthy;
  }

  String _getSyncStatusIcon(SliceSyncStatus status) {
    switch (status) {
      case SliceSyncStatus.idle: return '⏸️';
      case SliceSyncStatus.syncing: return '🔄';
      case SliceSyncStatus.success: return '✅';
      case SliceSyncStatus.failed: return '❌';
      case SliceSyncStatus.paused: return '⏸️';
    }
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) return '刚刚';
    if (difference.inMinutes < 60) return '${difference.inMinutes}分钟前';
    if (difference.inHours < 24) return '${difference.inHours}小时前';
    return '${difference.inDays}天前';
  }

  Future<BackendServiceInfo> _checkBackendHealth() async {
    try {
      final response = await _ref.read(apiClientProvider).get('/health');
      return BackendServiceInfo(
        name: 'Todo API',
        baseUrl: _ref.read(apiClientProvider).baseUrl,
        status: BackendHealthStatus.healthy,
        responseTime: 100, // 从响应中获取
        lastCheckTime: DateTime.now(),
        checkedEndpoints: ['/health', '/todos'],
      );
    } catch (e) {
      return BackendServiceInfo(
        name: 'Todo API',
        baseUrl: _ref.read(apiClientProvider).baseUrl,
        status: BackendHealthStatus.error,
        lastCheckTime: DateTime.now(),
        errorMessage: e.toString(),
        checkedEndpoints: ['/health'],
      );
    }
  }

  void _showAddTodoDialog() {
    // 实现添加Todo对话框
  }
}

// 4. Riverpod提供者
final todoSliceSummaryProvider = Provider<TodoSliceSummaryProvider>((ref) {
  return TodoSliceSummaryProvider(ref);
});
```

## 📊 状态展示

切片卡片将显示三层状态信息：

1. **网络连接状态**：来自全局网络监控
2. **后端服务状态**：来自切片的BackendServiceInfo
3. **切片同步状态**：来自SliceSyncInfo

这样用户可以清楚地了解：
- 网络是否连通
- 切片的后端服务是否可用
- 切片数据是否正在同步或有错误

## 🎛️ 配置选项

### SliceSyncConfig配置

```dart
const SliceSyncConfig(
  enableBackgroundSync: true,           // 是否启用后台同步
  syncInterval: Duration(minutes: 15),  // 同步间隔
  syncOnNetworkRecover: true,           // 网络恢复时是否同步
  syncOnAppResume: true,                // 应用恢复时是否同步
  maxRetryAttempts: 3,                  // 最大重试次数
  syncPriority: OperationPriority.normal, // 同步优先级
  syncTypes: ['my_data_type'],          // 同步的数据类型
  conflictResolution: ConflictResolution.merge, // 冲突解决策略
)
```

## 🔧 最佳实践

### 1. 切片独立性
- 每个切片管理自己的同步配置和逻辑
- 避免切片间的同步依赖
- 使用独立的数据类型标识

### 2. 性能优化
- 根据切片重要性设置不同的同步间隔
- 使用增量同步减少数据传输
- 在网络质量差时降低同步频率

### 3. 用户体验
- 提供清晰的同步状态指示
- 支持手动触发同步
- 智能处理冲突，减少用户干预

### 4. 错误处理
- 提供详细的错误信息
- 实现重试机制
- 优雅降级到离线模式

### 5. 测试策略
- 独立测试每个切片的同步逻辑
- 模拟网络异常情况
- 验证冲突解决策略

## 🚀 迁移指南

### 从静态切片迁移

如果你有现有的静态切片（如demo切片），可以按以下步骤迁移：

1. **添加同步混入**：
```dart
class ExistingSliceProvider extends SliceSummaryProvider with SliceSyncMixin {
  // 现有代码...
  
  @override
  String get sliceName => 'existing_slice';
  
  @override
  SliceSyncConfig get syncConfig => const SliceSyncConfig(
    enableBackgroundSync: false, // 开始时禁用
  );
}
```

2. **逐步启用功能**：
```dart
// 第一步：只添加后端健康检查
@override
SliceSyncConfig get syncConfig => const SliceSyncConfig(
  enableBackgroundSync: false,
);

// 第二步：启用基础同步
@override
SliceSyncConfig get syncConfig => const SliceSyncConfig(
  enableBackgroundSync: true,
  syncInterval: Duration(minutes: 30), // 较长间隔
);

// 第三步：优化配置
@override
SliceSyncConfig get syncConfig => const SliceSyncConfig(
  enableBackgroundSync: true,
  syncInterval: Duration(minutes: 15),
  syncOnNetworkRecover: true,
);
```

3. **实现同步逻辑**：
```dart
@override
Future<void> performSliceSync(bool isManual) async {
  // 逐步实现同步逻辑
}
```

## 📈 监控和调试

### 日志输出
切片同步混入会自动输出调试日志：

```
🔄 切片同步已初始化: my_slice
🔄 切片后台同步已启动: my_slice
✅ 切片同步成功: my_slice
❌ 切片同步失败: my_slice - Network error
🗑️ 切片同步已释放: my_slice
```

### 状态监控
可以通过同步状态流监控切片同步：

```dart
class MySliceProvider extends SliceSummaryProvider with SliceSyncMixin {
  @override
  Future<void> initializeSync(Ref ref) async {
    await super.initializeSync(ref);
    
    // 监听同步状态变化
    syncStatusStream?.listen((syncInfo) {
      debugPrint('切片同步状态变化: ${syncInfo.status}');
      
      if (syncInfo.hasError) {
        // 处理同步错误
        _handleSyncError(syncInfo.error!);
      }
    });
  }
  
  void _handleSyncError(String error) {
    // 实现错误处理逻辑
  }
}
```

## 🎯 总结

通过切片级别的后台同步集成：

1. **保持架构一致性**：符合v7架构的切片独立性原则
2. **提供灵活性**：切片可以选择性地启用后台同步
3. **优化用户体验**：精确的状态反馈和智能同步策略
4. **简化维护**：每个切片独立维护自己的同步逻辑
5. **支持渐进式迁移**：现有切片可以逐步添加同步能力

这种设计既保持了现有基础设施的稳定性，又为切片提供了强大的后台同步能力，是最符合v7架构理念的最佳实践方案。 