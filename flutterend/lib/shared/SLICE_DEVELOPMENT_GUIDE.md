# 🚀 v7 Flutter 切片开发指南

## 概述

v7架构实现了**一处配置、全局生效**的切片开发模式。开发者只需要在一个地方配置切片信息，系统会自动处理注册、路由和UI集成。

## 🎯 核心优势

- **零配置路由**：无需手动配置路由，系统自动生成
- **统一注册**：一处配置，多处生效
- **类型安全**：编译时检查，运行时安全
- **热重载友好**：开发时实时预览
- **标准化流程**：统一的开发模式

## 📋 快速开始

### 1. 创建切片目录结构

```
lib/slices/your_slice_name/
├── index.dart              # 统一导出
├── models.dart             # 数据模型
├── repository.dart         # 数据访问层
├── service.dart            # 业务逻辑层
├── providers.dart          # 状态管理
├── widgets.dart            # UI组件
└── summary_provider.dart   # 摘要提供者
```

### 2. 实现核心组件

#### 2.1 数据模型 (models.dart)
```dart
import 'package:equatable/equatable.dart';

// 定义你的数据模型
class YourDataModel extends Equatable {
  final String id;
  final String name;
  // ... 其他字段

  const YourDataModel({
    required this.id,
    required this.name,
  });

  @override
  List<Object?> get props => [id, name];
}

// 状态模型
class YourSliceState extends Equatable {
  final List<YourDataModel> items;
  final bool isLoading;
  final String? error;

  const YourSliceState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  YourSliceState copyWith({
    List<YourDataModel>? items,
    bool? isLoading,
    String? error,
  }) {
    return YourSliceState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [items, isLoading, error];
}
```

#### 2.2 业务逻辑层 (service.dart)
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../shared/events/event_bus.dart';
import '../../shared/services/service_locator.dart';
import 'models.dart';
import 'repository.dart';

class YourSliceService {
  final YourSliceRepository _repository;
  final StreamController<YourSliceState> _stateController = StreamController.broadcast();
  
  YourSliceState _currentState = const YourSliceState();

  YourSliceService({bool autoRegister = true}) 
      : _repository = YourSliceRepositoryImpl() {
    if (autoRegister) {
      _initialize();
    }
  }

  YourSliceService.withoutAutoRegister() : this(autoRegister: false);

  Stream<YourSliceState> get stateStream => _stateController.stream;
  YourSliceState get currentState => _currentState;

  void _initialize() {
    if (!ServiceLocator.instance.isRegistered<YourSliceService>()) {
      ServiceLocator.instance.registerSingleton<YourSliceService>(this);
    }
  }

  Future<void> loadData() async {
    try {
      _updateState(_currentState.copyWith(isLoading: true, error: null));
      
      final items = await _repository.getData();
      
      _updateState(_currentState.copyWith(
        items: items,
        isLoading: false,
        error: null,
      ));
    } catch (e) {
      _updateState(_currentState.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  void _updateState(YourSliceState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  void dispose() {
    _stateController.close();
  }
}
```

#### 2.3 状态管理 (providers.dart)
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/service_locator.dart';
import 'models.dart';
import 'service.dart';

final yourSliceServiceProvider = Provider<YourSliceService>((ref) {
  if (ServiceLocator.instance.isRegistered<YourSliceService>()) {
    return ServiceLocator.instance.get<YourSliceService>();
  }
  
  final service = YourSliceService.withoutAutoRegister();
  ServiceLocator.instance.registerSingleton<YourSliceService>(service);
  
  return service;
});

final yourSliceStateProvider = StreamProvider<YourSliceState>((ref) {
  final service = ref.watch(yourSliceServiceProvider);
  
  if (service.currentState.items.isEmpty && !service.currentState.isLoading) {
    Future.microtask(() => service.loadData());
  }
  
  return service.stateStream;
});
```

#### 2.4 UI组件 (widgets.dart)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import 'providers.dart';

class YourSliceWidget extends ConsumerStatefulWidget {
  const YourSliceWidget({super.key});

  @override
  ConsumerState<YourSliceWidget> createState() => _YourSliceWidgetState();
}

class _YourSliceWidgetState extends ConsumerState<YourSliceWidget> {
  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(yourSliceStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('你的切片'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(yourSliceServiceProvider).loadData(),
          ),
        ],
      ),
      body: asyncState.when(
        data: (state) => _buildContent(state),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('错误: $error')),
      ),
    );
  }

  Widget _buildContent(YourSliceState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(child: Text('错误: ${state.error}'));
    }

    if (state.items.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return ListView.builder(
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        return ListTile(
          title: Text(item.name),
          // 添加更多UI元素
        );
      },
    );
  }
}
```

#### 2.5 摘要提供者 (summary_provider.dart)
```dart
import 'package:flutter/material.dart';
import '../../shared/contracts/slice_summary_contract.dart';
import '../../shared/services/service_locator.dart';
import 'service.dart';

class YourSliceSummaryProvider implements SliceSummaryProvider {
  YourSliceService? _service;

  YourSliceSummaryProvider() {
    try {
      _service = ServiceLocator.instance.get<YourSliceService>();
    } catch (e) {
      debugPrint('YourSliceService未注册，使用模拟数据');
    }
  }

  @override
  Future<SliceSummaryContract> getSummaryData() async {
    if (_service == null) {
      return _getOfflineSummary();
    }

    try {
      final state = _service!.currentState;
      final itemCount = state.items.length;

      return SliceSummaryContract(
        title: '你的切片',
        status: state.isLoading ? SliceStatus.loading : SliceStatus.healthy,
        metrics: [
          SliceMetric(
            label: '数据项',
            value: itemCount,
            trend: 'stable',
            icon: '📊',
            unit: '个',
          ),
        ],
        description: '当前有 $itemCount 个数据项',
        lastUpdated: DateTime.now(),
        alertCount: 0,
      );
    } catch (error) {
      return _getErrorSummary(error.toString());
    }
  }

  SliceSummaryContract _getOfflineSummary() {
    return SliceSummaryContract(
      title: '你的切片',
      status: SliceStatus.warning,
      metrics: [
        const SliceMetric(
          label: '状态',
          value: '离线',
          trend: 'stable',
          icon: '📱',
        ),
      ],
      description: '当前运行在离线模式',
      lastUpdated: DateTime.now(),
      alertCount: 0,
    );
  }

  SliceSummaryContract _getErrorSummary(String error) {
    return SliceSummaryContract(
      title: '你的切片',
      status: SliceStatus.error,
      metrics: [
        const SliceMetric(
          label: '状态',
          value: '错误',
          trend: 'down',
          icon: '❌',
        ),
      ],
      description: '发生错误: $error',
      lastUpdated: DateTime.now(),
      alertCount: 1,
    );
  }

  @override
  Future<void> refreshData() async {
    await _service?.loadData();
  }

  @override
  void dispose() {
    _service = null;
  }
}
```

### 3. 注册切片

在 `lib/shared/registry/slice_registry.dart` 的 `SliceConfigs._configs` 中添加你的切片：

```dart
static final List<SliceConfig> _configs = [
  // 现有切片...
  
  // 你的新切片
  SliceConfig(
    name: 'your_slice_name',
    displayName: '你的切片显示名称',
    description: '切片功能描述',
    widgetBuilder: YourSliceWidget.new,
    summaryProvider: YourSliceSummaryProvider(),
    iconColor: 0xFF4CAF50,
    category: '已实现',
    author: '你的名字',
    isEnabled: true,
    dependencies: const ['shared'],
  ),
];
```

### 4. 完成！

就这样！你的切片已经自动集成到系统中：

- ✅ 自动注册到切片注册中心
- ✅ 自动生成路由 `/slice/your_slice_name`
- ✅ 自动在Dashboard中显示
- ✅ 自动支持摘要数据显示
- ✅ 自动支持网络状态集成

## 🔧 高级功能

### 自定义路由参数

如果需要支持路由参数，可以在Widget中处理：

```dart
class YourSliceWidget extends ConsumerStatefulWidget {
  final String? param;
  
  const YourSliceWidget({super.key, this.param});

  @override
  ConsumerState<YourSliceWidget> createState() => _YourSliceWidgetState();
}
```

### 切片间通信

使用事件总线进行切片间通信：

```dart
// 发送事件
EventBus.instance.emit(YourCustomEvent(data: 'some data'));

// 监听事件
eventBus.on<YourCustomEvent>((event) {
  // 处理事件
});
```

### 离线支持

在Repository中实现离线逻辑：

```dart
@override
Future<List<YourDataModel>> getData() async {
  try {
    // 尝试从API获取数据
    return await _apiClient.get<List<YourDataModel>>('/your-endpoint');
  } catch (e) {
    // 回退到本地缓存
    return await _localStorage.getCachedData();
  }
}
```

## 📝 最佳实践

1. **命名规范**：使用小写加下划线的切片名称
2. **状态管理**：使用Riverpod进行状态管理
3. **错误处理**：提供友好的错误提示
4. **性能优化**：使用懒加载和缓存策略
5. **测试覆盖**：为每个切片编写单元测试

## 🐛 常见问题

### Q: 切片不显示在Dashboard中？
A: 检查 `SliceConfigs` 中的 `isEnabled` 是否为 `true`

### Q: 路由导航失败？
A: 确保 `widgetBuilder` 返回的Widget构造函数正确

### Q: 摘要数据不更新？
A: 检查 `SummaryProvider` 的 `refreshData` 方法是否正确实现

### Q: 服务注册失败？
A: 确保在 `Service` 构造函数中正确调用 `_initialize()`

## 🎉 恭喜！

你已经掌握了v7切片开发的核心技能。现在可以开始构建你的功能切片了！

---

*更多详细信息请参考项目文档和示例代码* 