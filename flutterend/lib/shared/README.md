# Flutter v7 基础设施库

## 概述

本库为Flutter v7架构提供完整的基础设施支持，专注于离线优先的业务功能实现。通过配置驱动的设计，支持多后端架构，确保切片独立性和高度可扩展性。

## 🏗️ 架构特点

### 1. 配置驱动架构
- **类似前端.env的配置系统**：通过JSON配置文件管理所有设置
- **环境变量覆盖**：支持运行时配置覆盖
- **多后端支持**：可同时配置和监控多个后端服务
- **类型安全**：完整的Dart类型支持和编译时检查

### 2. 多后端架构支持
- **后端服务配置**：每个后端独立配置URL、超时、重试等参数
- **健康检查**：独立监控各后端服务的健康状态
- **负载均衡**：支持主备后端切换和故障转移
- **切片级别选择**：不同切片可以使用不同的后端服务

### 3. 切片独立性
- **全局离线指示器**：监控所有后端服务的整体状态
- **切片级别离线指示器**：每个切片可以独立监控特定后端
- **自定义健康检查端点**：切片可以指定特定的健康检查API
- **独立配置**：每个切片的离线检测完全独立

## 🚀 快速开始

### 1. 配置初始化

```dart
// 在main.dart中初始化配置
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化应用配置
  await AppConfig.initialize(
    configFile: 'assets/config/app_config.json',
    envOverrides: {
      'backends.primary.baseUrl': 'https://api.production.com',
      'debug.enabled': 'false',
    },
  );
  
  runApp(MyApp());
}
```

### 2. 配置文件示例

```json
{
  "environment": "development",
  "backends": {
    "primary": {
      "name": "primary",
      "baseUrl": "http://localhost:8080/api",
      "healthEndpoint": "/health",
      "timeout": 5,
      "retryAttempts": 3,
      "headers": {
        "Content-Type": "application/json"
      },
      "isDefault": true
    },
    "secondary": {
      "name": "secondary",
      "baseUrl": "http://localhost:8081/api",
      "healthEndpoint": "/health",
      "timeout": 5,
      "retryAttempts": 3,
      "headers": {
        "Content-Type": "application/json"
      },
      "isDefault": false
    }
  },
  "features": {
    "offlineMode": true,
    "backgroundSync": true,
    "conflictResolution": true
  }
}
```

### 3. API客户端使用

```dart
// 使用默认后端
final apiClient = ApiClientFactory.getClient();

// 使用指定后端
final primaryClient = ApiClientFactory.getClient('primary');
final secondaryClient = ApiClientFactory.getClient('secondary');

// 发起请求
final response = await apiClient.get('/users');
final user = await apiClient.post('/users', data: userData);

// 健康检查
final isHealthy = await apiClient.healthCheck();
```

### 4. 离线状态监控

#### 全局离线指示器
```dart
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineStatus = ref.watch(globalOfflineProvider);
    
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            if (offlineStatus.shouldShowIndicator)
              OfflineBanner(status: offlineStatus),
            Expanded(child: MyContent()),
          ],
        ),
      ),
    );
  }
}
```

#### 切片级别离线指示器
```dart
// 在切片中创建专用的离线指示器
final userSliceOfflineProvider = createSliceOfflineProvider(
  sliceName: 'user',
  backendName: 'primary',
  customHealthEndpoint: '/api/user/health',
  checkInterval: Duration(minutes: 1),
);

class UserSliceWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineStatus = ref.watch(userSliceOfflineProvider);
    
    if (offlineStatus.isOffline) {
      return OfflineUserInterface();
    }
    
    return OnlineUserInterface();
  }
}
```

## 📁 目录结构

```
lib/shared/
├── config/                 # 配置管理
│   └── app_config.dart    # 应用配置类
├── network/               # 网络层
│   └── api_client.dart    # API客户端和工厂
├── offline/               # 离线功能
│   └── offline_indicator.dart  # 离线状态指示器
├── connectivity/          # 网络连接监控
├── database/             # 数据库抽象层
├── cache/                # 缓存系统
├── sync/                 # 数据同步
├── storage/              # 存储抽象
├── events/               # 事件系统
├── providers/            # Riverpod提供器
├── services/             # 服务层
├── utils/                # 工具函数
├── widgets/              # 共享组件
└── ui/                   # UI组件
```

## 🔧 高级配置

### 环境变量覆盖
支持通过环境变量覆盖配置，使用点号分隔的嵌套路径：

```dart
await AppConfig.initialize(
  envOverrides: {
    'backends.primary.baseUrl': Platform.environment['API_BASE_URL'],
    'backends.primary.timeout': Platform.environment['API_TIMEOUT'],
    'debug.enabled': Platform.environment['DEBUG_MODE'],
  },
);
```

### 多后端健康检查
```dart
// 检查所有后端健康状态
final healthStatuses = await ApiClientFactory.checkAllHealthStatus();

// 结果: {'primary': true, 'secondary': false}
for (final entry in healthStatuses.entries) {
  print('${entry.key}: ${entry.value ? '健康' : '不健康'}');
}
```

### 自定义离线指示器
```dart
class CustomOfflineIndicator extends SliceOfflineIndicator {
  CustomOfflineIndicator({
    required super.sliceName,
    required super.backendName,
    super.customHealthEndpoint,
    super.checkInterval,
  });

  @override
  Future<bool> _checkBackendHealth() async {
    // 自定义健康检查逻辑
    try {
      final response = await _apiClient.get('/custom/health');
      return response['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }
}
```

## 🎯 最佳实践

### 1. 配置管理
- **集中配置**：所有配置统一管理，避免硬编码
- **环境区分**：开发、测试、生产环境使用不同配置
- **敏感信息**：通过环境变量传递敏感配置

### 2. 后端选择
- **主备模式**：配置主后端和备用后端，支持故障转移
- **功能分离**：不同功能使用不同后端，提高系统可用性
- **就近访问**：根据地理位置选择最近的后端服务

### 3. 离线处理
- **全局监控**：使用全局离线指示器监控整体状态
- **切片独立**：关键功能使用独立的离线指示器
- **用户体验**：提供清晰的离线状态提示和操作引导

### 4. 性能优化
- **客户端复用**：通过工厂模式复用API客户端实例
- **健康检查间隔**：根据业务需求调整检查频率
- **缓存策略**：合理使用缓存减少网络请求

## 🔍 故障排查

### 配置问题
```dart
// 检查配置是否正确加载
print('Environment: ${AppConfig.instance.environment}');
print('Backends: ${AppConfig.instance.backends.keys.join(', ')}');
print('Default backend: ${AppConfig.instance.defaultBackend.name}');
```

### 网络问题
```dart
// 检查网络连接状态
final networkState = ref.watch(networkMonitorProvider);
print('Network connected: ${networkState.isConnected}');
print('Network quality: ${networkState.quality}');
```

### 后端健康状态
```dart
// 检查后端健康状态
final healthStatuses = ref.watch(backendHealthProvider);
for (final entry in healthStatuses.entries) {
  final status = entry.value;
  print('${entry.key}: ${status.isHealthy ? '健康' : '不健康'}');
  if (!status.isHealthy && status.error != null) {
    print('  错误: ${status.error}');
  }
}
```

## 🤝 贡献指南

1. **遵循v7架构原则**：确保切片独立性和可扩展性
2. **配置驱动**：新功能应该通过配置文件控制
3. **类型安全**：使用强类型和编译时检查
4. **测试覆盖**：为新功能添加完整的单元测试
5. **文档更新**：及时更新文档和使用示例

## 📚 相关文档

- [SLICE_DEVELOPMENT_GUIDE.md](./SLICE_DEVELOPMENT_GUIDE.md) - 切片开发指南
- [INFRASTRUCTURE_SUMMARY.md](./INFRASTRUCTURE_SUMMARY.md) - 基础设施总结
- [plan_2.md](./plan_2.md) - 开发计划和路线图 