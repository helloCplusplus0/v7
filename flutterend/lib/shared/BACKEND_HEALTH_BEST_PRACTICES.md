# 🎯 后端健康检查最佳实践指南

## 📋 设计理念

基于v7架构的**切片独立性**原则，我们采用**切片级别的后端健康检查**而不是全局配置管理，这样的设计更符合实际业务需求和架构最佳实践。

## 🏗️ 架构对比

### ❌ 全局配置方案的问题

```dart
// 全局配置方案 - 不推荐
class AppConfig {
  static final backends = {
    'primary': BackendConfig(baseUrl: 'http://localhost:8080'),
    'secondary': BackendConfig(baseUrl: 'http://localhost:8081'),
  };
}

// 问题：
// 1. 违反切片独立性原则
// 2. 配置复杂，难以维护
// 3. 不同切片可能需要不同的健康检查策略
// 4. 硬编码问题仍然存在
```

### ✅ 切片级别方案的优势

```dart
// 切片级别方案 - 推荐
class DemoTaskSummaryProvider {
  DemoTaskSummaryProvider({
    this.backendBaseUrl = 'http://localhost:8080',
    this.requiredEndpoints = const ['/api/items', '/api/info'],
    this.healthCheckInterval = const Duration(minutes: 2),
  });
  
  // 优势：
  // 1. 完全符合切片独立性
  // 2. 每个切片管理自己的后端依赖
  // 3. 灵活的健康检查策略
  // 4. 真实的业务API检查
}
```

## 🔍 核心设计原则

### 1. **切片独立性优先**
- 每个切片负责自己的后端连接
- 切片可以独立配置后端地址和检查策略
- 不同切片可以连接不同的后端服务

### 2. **真实业务API检查**
- 不仅仅检查 `/health` 端点
- 检查切片实际使用的业务API
- 确保业务功能的真实可用性

### 3. **灵活的配置策略**
- 支持环境变量覆盖
- 支持运行时配置
- 支持不同的检查间隔和策略

## 🎨 实现模式

### 1. **Summary Provider扩展模式**

```dart
class YourSliceSummaryProvider implements SliceSummaryProvider {
  YourSliceSummaryProvider({
    this.backendBaseUrl = 'http://localhost:8080',
    this.requiredEndpoints = const ['/api/your-feature'],
    this.healthCheckInterval = const Duration(minutes: 2),
  });

  // 后端健康检查逻辑
  Future<void> _checkBackendHealth() async {
    // 检查实际业务API
    for (final endpoint in requiredEndpoints) {
      final response = await http.get(Uri.parse('$backendBaseUrl$endpoint'));
      // 处理响应...
    }
  }

  @override
  Future<SliceSummaryContract> getSummaryData() async {
    // 返回包含后端状态的摘要
    return SliceSummaryContract(
      // ...其他数据
      backendService: _backendServiceInfo,
    );
  }
}
```

### 2. **UI集成模式**

```dart
// 切片卡片自动显示后端状态
class TelegramSliceCard extends ConsumerWidget {
  Widget _buildStatusIndicators() {
    return Row(
      children: [
        _buildNetworkIndicator(),      // 网络状态
        _buildBackendServiceIndicator(), // 后端服务状态
        _buildSliceStatusIndicator(),   // 切片业务状态
      ],
    );
  }
}
```

## 📊 健康检查策略

### 1. **多层次检查**

```dart
// 基础连通性检查
final response = await http.get(Uri.parse('$backendBaseUrl/health'));

// 业务API检查
final businessResponse = await http.get(Uri.parse('$backendBaseUrl/api/your-feature'));

// 性能检查
final stopwatch = Stopwatch()..start();
// ... API调用
final responseTime = stopwatch.elapsedMilliseconds;
```

### 2. **智能状态判断**

```dart
BackendHealthStatus _determineHealthStatus({
  required List<String> checkedEndpoints,
  required List<String> requiredEndpoints,
  required int avgResponseTime,
}) {
  if (checkedEndpoints.length < requiredEndpoints.length) {
    return BackendHealthStatus.error;
  }
  
  if (avgResponseTime > 2000) {
    return BackendHealthStatus.warning;
  }
  
  return BackendHealthStatus.healthy;
}
```

### 3. **错误处理和重试**

```dart
Future<void> _checkBackendHealth() async {
  int retryCount = 0;
  const maxRetries = 3;
  
  while (retryCount < maxRetries) {
    try {
      // 执行健康检查
      await _performHealthCheck();
      break;
    } catch (e) {
      retryCount++;
      if (retryCount >= maxRetries) {
        _backendServiceInfo = _backendServiceInfo.copyWith(
          status: BackendHealthStatus.error,
          errorMessage: e.toString(),
        );
      }
      await Future.delayed(Duration(seconds: retryCount * 2));
    }
  }
}
```

## 🎯 配置管理

### 1. **环境变量支持**

```dart
class YourSliceSummaryProvider {
  YourSliceSummaryProvider({
    String? backendBaseUrl,
    // ...其他参数
  }) : backendBaseUrl = backendBaseUrl ?? 
         Platform.environment['YOUR_BACKEND_URL'] ?? 
         'http://localhost:8080';
}
```

### 2. **配置文件支持**

```dart
// assets/config/slice_config.json
{
  "demo_slice": {
    "backend_url": "http://localhost:8080",
    "required_endpoints": ["/api/items", "/api/info"],
    "health_check_interval": 120
  }
}
```

### 3. **运行时配置**

```dart
// 支持运行时修改配置
void updateBackendConfig({
  String? newBaseUrl,
  List<String>? newEndpoints,
}) {
  if (newBaseUrl != null) {
    backendBaseUrl = newBaseUrl;
  }
  // 重新开始健康检查
  _startBackendHealthCheck();
}
```

## 🔄 与现有系统集成

### 1. **保持向后兼容**

```dart
// 如果需要全局状态，可以通过事件总线通信
class SliceSummaryProvider {
  void _updateGlobalStatus() {
    eventBus.emit(BackendHealthChangedEvent(
      sliceName: 'demo',
      status: _backendServiceInfo.status,
    ));
  }
}
```

### 2. **与离线队列集成**

```dart
// 根据后端状态决定是否使用离线队列
bool get shouldUseOfflineQueue {
  return !_backendServiceInfo.isAvailable;
}
```

### 3. **与同步管理器集成**

```dart
// 通知同步管理器后端状态变化
void _notifySyncManager() {
  if (_backendServiceInfo.isAvailable) {
    eventBus.emit(BackendAvailableEvent(sliceName: 'demo'));
  } else {
    eventBus.emit(BackendUnavailableEvent(sliceName: 'demo'));
  }
}
```

## 🎨 UI/UX最佳实践

### 1. **状态指示器设计**

```dart
// 三层状态指示：网络 -> 后端 -> 业务
Widget _buildStatusIndicators() {
  return Row(
    children: [
      NetworkIndicator(),     // 🟢 网络连接状态
      BackendIndicator(),     // 🟢 后端服务状态  
      BusinessIndicator(),    // 🟢 业务功能状态
    ],
  );
}
```

### 2. **用户友好的错误信息**

```dart
String get userFriendlyErrorMessage {
  switch (_backendServiceInfo.status) {
    case BackendHealthStatus.error:
      return '服务暂时不可用，请稍后重试';
    case BackendHealthStatus.warning:
      return '服务响应较慢，功能可能受影响';
    default:
      return '服务正常';
  }
}
```

### 3. **操作反馈**

```dart
// 提供手动检查按钮
SliceAction(
  label: '检查后端',
  onPressed: () async {
    // 显示加载状态
    setState(() => _isChecking = true);
    
    await _checkBackendHealth();
    
    // 显示结果
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_backendServiceInfo.statusDescription)),
    );
    
    setState(() => _isChecking = false);
  },
  icon: '🔍',
)
```

## 🚀 性能优化

### 1. **智能检查间隔**

```dart
Duration get adaptiveCheckInterval {
  switch (_backendServiceInfo.status) {
    case BackendHealthStatus.error:
      return const Duration(minutes: 1); // 错误时频繁检查
    case BackendHealthStatus.warning:
      return const Duration(minutes: 2); // 警告时适中检查
    default:
      return const Duration(minutes: 5); // 正常时较少检查
  }
}
```

### 2. **缓存策略**

```dart
// 缓存健康检查结果
bool get shouldCheckHealth {
  if (_lastHealthCheck == null) return true;
  return DateTime.now().difference(_lastHealthCheck!) > adaptiveCheckInterval;
}
```

### 3. **批量检查**

```dart
// 批量检查多个端点
Future<void> _batchCheckEndpoints() async {
  final futures = requiredEndpoints.map((endpoint) => 
    http.get(Uri.parse('$backendBaseUrl$endpoint'))
  );
  
  final responses = await Future.wait(futures, eagerError: false);
  // 处理批量响应...
}
```

## 📝 总结

这种**切片级别的后端健康检查**方案具有以下优势：

1. **🎯 符合v7架构原则** - 切片独立性
2. **🔍 真实业务检查** - 不仅仅是健康端点
3. **🎨 灵活配置** - 每个切片独立配置
4. **🚀 性能优化** - 智能检查策略
5. **🎭 用户体验** - 清晰的状态指示

相比全局AppConfig方案，这种方案更加**实用、灵活、可维护**，真正解决了业务场景中的实际问题。 