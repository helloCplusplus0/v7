# 离线状态系统使用指南

## 概述

离线状态系统为您的 Flutter 应用提供了精确的离线状态检测和管理功能。该系统区分了"网络连接状态"和"服务可用性状态"，为 flutterend/-(api)->backend/ 架构提供了完整的离线支持。

## 核心概念

### 1. 离线状态定义

**离线状态 = 无法与backend/进行数据交互的状态**

包括：
- **完全离线**：设备无网络连接
- **服务离线**：有网络但无法连接backend/
- **功能离线**：连接不稳定，API调用频繁失败

### 2. 状态层次

#### 网络连接状态 (NetworkStatus)
- `online` - 有网络连接
- `offline` - 无网络连接
- `limited` - 连接受限
- `unknown` - 未知状态

#### 服务可用性状态 (ServiceAvailability)
- `available` - 服务完全可用
- `degraded` - 服务部分可用
- `unavailable` - 服务不可用
- `maintenance` - 服务维护中
- `checking` - 检测中
- `unknown` - 未知状态

#### 应用运行模式 (AppOperationMode)
- `online` - 在线模式：网络连接正常 + backend/服务可用
- `serviceOffline` - 服务离线模式：有网络连接但backend/不可用
- `fullyOffline` - 完全离线模式：无网络连接
- `hybrid` - 混合模式：网络不稳定或服务部分可用

## 使用方法

### 1. 基本使用

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:your_app/shared/offline/offline_indicator.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineStatus = ref.watch(offlineIndicatorProvider);
    
    if (offlineStatus.isOffline) {
      return Text('离线模式: ${offlineStatus.userFriendlyMessage}');
    }
    
    return Text('在线模式');
  }
}
```

### 2. 检查是否可以同步数据

```dart
final canSync = ref.watch(canSyncProvider);
if (canSync) {
  // 可以进行数据同步
  await syncData();
} else {
  // 将操作添加到离线队列
  await addToOfflineQueue(operation);
}
```

### 3. 监听离线状态变化

```dart
class MyNotifier extends StateNotifier<MyState> {
  MyNotifier(this.ref) : super(MyState.initial()) {
    // 监听离线状态变化
    ref.listen(offlineIndicatorProvider, (previous, next) {
      if (previous?.isOffline != next.isOffline) {
        _handleOfflineStateChange(next.isOffline);
      }
    });
  }
  
  void _handleOfflineStateChange(bool isOffline) {
    if (isOffline) {
      // 切换到离线模式
      state = state.copyWith(mode: AppMode.offline);
    } else {
      // 切换到在线模式，触发数据同步
      state = state.copyWith(mode: AppMode.online);
      _triggerDataSync();
    }
  }
}
```

### 4. 使用UI组件

#### 基本指示器
```dart
OfflineStatusIndicator(
  showDetails: true,
  onTap: () {
    // 点击查看详情
    Navigator.pushNamed(context, '/offline-detail');
  },
)
```

#### 浮动指示器
```dart
Stack(
  children: [
    // 您的主要内容
    MyMainContent(),
    
    // 浮动离线指示器
    OfflineStatusFloatingIndicator(
      position: FloatingIndicatorPosition.topRight,
      onTap: () => _showOfflineDetails(),
    ),
  ],
)
```

#### 详情卡片
```dart
OfflineStatusDetailCard(
  onRetry: () async {
    await ref.read(offlineIndicatorProvider.notifier).retryConnection();
  },
  onViewDetails: () {
    Navigator.pushNamed(context, '/offline-detail');
  },
)
```

### 5. 智能同步配置

```dart
// 自动根据网络状态调整同步策略
final syncConfig = ref.watch(smartSyncConfigProvider);

// 检查是否应该执行同步
final shouldSync = ref.watch(shouldSyncProvider);
if (shouldSync) {
  await performSync(syncConfig);
}
```

## 集成步骤

### 1. 在main.dart中激活离线监控

```dart
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 激活离线状态监控
    ref.watch(offlineIndicatorProvider);
    
    // 激活离线状态与同步管理器的集成
    ref.watch(offlineSyncIntegrationProvider);
    
    return MaterialApp(
      // 您的应用配置
    );
  }
}
```

### 2. 在需要的地方添加UI指示器

```dart
// 在AppBar中显示
AppBar(
  title: Text('我的应用'),
  actions: [
    OfflineStatusIndicator(compact: true),
  ],
)

// 在底部显示详情
if (offlineStatus.shouldShowIndicator)
  OfflineStatusDetailCard(
    onRetry: _retryConnection,
    onViewDetails: _showOfflineDetails,
  ),
```

### 3. 在业务逻辑中使用离线状态

```dart
class DataService {
  final Ref ref;
  
  DataService(this.ref);
  
  Future<void> saveData(Data data) async {
    final offlineStatus = ref.read(offlineIndicatorProvider);
    
    if (offlineStatus.canSync) {
      // 可以直接同步到服务器
      await _syncToServer(data);
    } else {
      // 保存到本地，添加到离线队列
      await _saveLocally(data);
      await _addToOfflineQueue(data);
    }
  }
}
```

## 最佳实践

### 1. 用户体验优化

- **渐进式降级**：在线功能逐步降级到离线功能
- **状态透明**：清楚地向用户显示当前状态
- **操作反馈**：离线操作要给用户明确的反馈

### 2. 数据同步策略

- **冲突解决**：制定明确的数据冲突解决策略
- **优先级队列**：重要操作优先同步
- **增量同步**：只同步变化的数据

### 3. 性能优化

- **智能重试**：根据网络状态调整重试策略
- **批量操作**：合并多个操作减少网络请求
- **缓存策略**：合理使用本地缓存

### 4. 错误处理

- **用户友好的错误消息**：避免技术术语
- **重试机制**：自动和手动重试选项
- **降级方案**：服务不可用时的替代方案

## 配置选项

### 服务检查间隔
```dart
// 默认每2分钟检查一次服务可用性
// 可以通过修改 OfflineStatus 的 serviceCheckInterval 调整
```

### 重试策略
```dart
// 默认最多重试3次
// 可以通过 maxRetryCount 调整
```

### 超时设置
```dart
// API客户端默认连接超时5秒，响应超时3秒
// 可以在 ApiClient 中调整
```

## 故障排除

### 1. 离线状态不准确
- 检查网络权限
- 验证API端点是否正确
- 查看后端服务状态

### 2. 同步失败
- 检查数据格式是否正确
- 验证API认证
- 查看网络连接质量

### 3. UI不更新
- 确保使用了ConsumerWidget
- 检查Provider是否正确watch
- 验证状态变化是否触发

## 调试

启用调试模式查看详细日志：

```dart
// 在debug模式下，系统会自动输出详细的状态变化日志
// 查看Flutter控制台获取调试信息
```

## 扩展

### 自定义离线检测逻辑
```dart
class CustomOfflineIndicator extends OfflineIndicator {
  // 重写检测逻辑
  @override
  Future<void> _checkServiceAvailability() async {
    // 您的自定义检测逻辑
  }
}
```

### 自定义UI组件
```dart
class CustomOfflineIndicator extends ConsumerWidget {
  // 创建您自己的离线状态UI组件
}
``` 