import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../types/result.dart';
import '../events/events.dart';
import '../network/api_client.dart';

/// Flutter优化的服务定位器
/// 
/// 结合GetIt和Riverpod的优势：
/// - GetIt负责服务注册和依赖管理
/// - Riverpod负责生命周期管理和响应式更新
/// - 支持异步初始化和延迟加载
/// - 类型安全的服务获取
class ServiceLocator {
  ServiceLocator._();
  
  static final ServiceLocator _instance = ServiceLocator._();
  static ServiceLocator get instance => _instance;
  
  final GetIt _getIt = GetIt.instance;
  final Map<Type, ServiceConfig> _configs = {};
  bool _isInitialized = false;
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 初始化服务定位器
  Future<AppResult<void>> initialize() async {
    if (_isInitialized) {
      return const Result.success(null);
    }
    
    try {
      // 初始化核心服务
      await _initializeCoreServices();
      
      // 初始化异步服务
      await _initializeAsyncServices();
      
      _isInitialized = true;
      
             // 发布初始化完成事件
       // EventBus.instance.emit(ServiceLocatorInitializedEvent());
       
       if (kDebugMode) {
         debugPrint('ServiceLocator initialized with ${_getIt.allReadySync()} services');
       }
      
      return const Result.success(null);
    } catch (e, stackTrace) {
      return Result.failure(BusinessError(
        'Failed to initialize ServiceLocator',
        e,
      ));
    }
  }
  
  /// 注册单例服务
  void registerSingleton<T extends Object>(
    T instance, {
    String? instanceName,
    bool signalsReady = false,
  }) {
    _getIt.registerSingleton<T>(
      instance,
      instanceName: instanceName,
      signalsReady: signalsReady,
    );
    
    _configs[T] = ServiceConfig(
      type: T,
      isSingleton: true,
      isAsync: false,
      instanceName: instanceName,
    );
    
    if (kDebugMode) {
      debugPrint('Singleton registered: $T${instanceName != null ? ' ($instanceName)' : ''}');
    }
  }
  
  /// 注册懒加载单例
  void registerLazySingleton<T extends Object>(
    T Function() factory, {
    String? instanceName,
  }) {
    _getIt.registerLazySingleton<T>(
      factory,
      instanceName: instanceName,
    );
    
    _configs[T] = ServiceConfig(
      type: T,
      isSingleton: true,
      isAsync: false,
      isLazy: true,
      instanceName: instanceName,
    );
    
    if (kDebugMode) {
      debugPrint('Lazy singleton registered: $T${instanceName != null ? ' ($instanceName)' : ''}');
    }
  }
  
  /// 注册工厂服务
  void registerFactory<T extends Object>(
    T Function() factory, {
    String? instanceName,
  }) {
    _getIt.registerFactory<T>(
      factory,
      instanceName: instanceName,
    );
    
    _configs[T] = ServiceConfig(
      type: T,
      isSingleton: false,
      isAsync: false,
      instanceName: instanceName,
    );
    
    if (kDebugMode) {
      debugPrint('Factory registered: $T${instanceName != null ? ' ($instanceName)' : ''}');
    }
  }
  
  /// 注册异步单例
  void registerSingletonAsync<T extends Object>(
    Future<T> Function() factory, {
    String? instanceName,
    Iterable<Type>? dependsOn,
  }) {
    _getIt.registerSingletonAsync<T>(
      factory,
      instanceName: instanceName,
      dependsOn: dependsOn,
    );
    
    _configs[T] = ServiceConfig(
      type: T,
      isSingleton: true,
      isAsync: true,
      instanceName: instanceName,
      dependsOn: dependsOn?.toSet(),
    );
    
    if (kDebugMode) {
      debugPrint('Async singleton registered: $T${instanceName != null ? ' ($instanceName)' : ''}');
    }
  }
  
  /// 注册异步工厂
  void registerFactoryAsync<T extends Object>(
    Future<T> Function() factory, {
    String? instanceName,
  }) {
    _getIt.registerFactoryAsync<T>(
      factory,
      instanceName: instanceName,
    );
    
    _configs[T] = ServiceConfig(
      type: T,
      isSingleton: false,
      isAsync: true,
      instanceName: instanceName,
    );
    
    if (kDebugMode) {
      debugPrint('Async factory registered: $T${instanceName != null ? ' ($instanceName)' : ''}');
    }
  }
  
  /// 获取服务实例
  T get<T extends Object>({String? instanceName}) {
    try {
      return _getIt.get<T>(instanceName: instanceName);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to get service: $T${instanceName != null ? ' ($instanceName)' : ''} - $e');
      }
      rethrow;
    }
  }
  
  /// 异步获取服务实例
  Future<T> getAsync<T extends Object>({String? instanceName}) async {
    try {
      return await _getIt.getAsync<T>(instanceName: instanceName);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to get async service: $T${instanceName != null ? ' ($instanceName)' : ''} - $e');
      }
      rethrow;
    }
  }
  
  /// 尝试获取服务实例
  T? tryGet<T extends Object>({String? instanceName}) {
    try {
      return _getIt.get<T>(instanceName: instanceName);
    } catch (e) {
      return null;
    }
  }
  
  /// 检查服务是否已注册
  bool isRegistered<T extends Object>({String? instanceName}) {
    return _getIt.isRegistered<T>(instanceName: instanceName);
  }
  
  /// 检查异步服务是否已准备就绪
  bool isReady<T extends Object>({String? instanceName}) {
    try {
      _getIt.get<T>(instanceName: instanceName);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 等待所有异步服务准备就绪
  Future<void> allReady() async {
    await _getIt.allReady();
  }
  
     /// 等待特定服务准备就绪
   Future<void> waitForReady<T extends Object>({String? instanceName}) async {
     final config = _configs[T];
     
     // 如果是异步服务，等待其准备就绪
     if (config?.isAsync == true) {
       await _getIt.isReady<T>(instanceName: instanceName);
     } else {
       // 对于同步服务，检查是否已注册即可
       if (!isRegistered<T>(instanceName: instanceName)) {
         throw StateError('Service $T${instanceName != null ? ' ($instanceName)' : ''} is not registered');
       }
       // 同步服务立即准备就绪，无需等待
     }
   }
  
  /// 注销服务
  Future<void> unregister<T extends Object>({String? instanceName}) async {
    await _getIt.unregister<T>(instanceName: instanceName);
    _configs.remove(T);
    
    if (kDebugMode) {
      debugPrint('Service unregistered: $T${instanceName != null ? ' ($instanceName)' : ''}');
    }
  }
  
  /// 重置所有服务
  Future<void> reset() async {
    await _getIt.reset();
    _configs.clear();
    _isInitialized = false;
    
    if (kDebugMode) {
      debugPrint('ServiceLocator reset');
    }
  }
  
  /// 获取服务配置
  ServiceConfig? getConfig<T extends Object>() {
    return _configs[T];
  }
  
  /// 获取所有注册的服务类型
  Set<Type> get registeredTypes => Set.unmodifiable(_configs.keys);
  
  /// 获取服务统计信息
  ServiceStats get stats {
    final allServices = _configs.values;
    return ServiceStats(
      totalServices: allServices.length,
      singletons: allServices.where((c) => c.isSingleton).length,
      factories: allServices.where((c) => !c.isSingleton).length,
      asyncServices: allServices.where((c) => c.isAsync).length,
             readyServices: 0, // TODO: Get actual ready services count
    );
  }
  
     /// 初始化核心服务
   Future<void> _initializeCoreServices() async {
    // 注册核心网络服务
    registerSingleton<ApiClient>(ApiClient());
    
    // 注册事件总线等其他核心服务
    // TODO: 根据需要添加其他核心服务的注册
    
    if (kDebugMode) {
      debugPrint('Core services registered: ${registeredTypes.length} services');
    }
   }
  
  /// 初始化异步服务
  Future<void> _initializeAsyncServices() async {
    // 等待所有异步服务准备就绪
    try {
      await _getIt.allReady(timeout: const Duration(seconds: 30));
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('Warning: Some async services did not complete initialization within timeout');
      }
    }
  }
}

/// 服务配置信息
class ServiceConfig {
  const ServiceConfig({
    required this.type,
    required this.isSingleton,
    required this.isAsync,
    this.isLazy = false,
    this.instanceName,
    this.dependsOn,
  });
  
  final Type type;
  final bool isSingleton;
  final bool isAsync;
  final bool isLazy;
  final String? instanceName;
  final Set<Type>? dependsOn;
  
  @override
  String toString() {
    return 'ServiceConfig('
        'type: $type, '
        'singleton: $isSingleton, '
        'async: $isAsync, '
        'lazy: $isLazy'
        '${instanceName != null ? ', name: $instanceName' : ''}'
        ')';
  }
}

/// 服务统计信息
class ServiceStats {
  const ServiceStats({
    required this.totalServices,
    required this.singletons,
    required this.factories,
    required this.asyncServices,
    required this.readyServices,
  });
  
  final int totalServices;
  final int singletons;
  final int factories;
  final int asyncServices;
  final int readyServices;
  
  @override
  String toString() {
    return 'ServiceStats('
        'total: $totalServices, '
        'singletons: $singletons, '
        'factories: $factories, '
        'async: $asyncServices, '
        'ready: $readyServices'
        ')';
  }
}

/// Riverpod Provider桥接
/// 
/// 为ServiceLocator提供Riverpod Provider支持
final serviceLocatorProvider = Provider<ServiceLocator>((ref) {
  return ServiceLocator.instance;
});

/// 通用服务Provider
Provider<T> serviceProvider<T extends Object>([String? instanceName]) {
  return Provider<T>((ref) {
    final locator = ref.read(serviceLocatorProvider);
    return locator.get<T>(instanceName: instanceName);
  });
}

/// 异步服务Provider
FutureProvider<T> asyncServiceProvider<T extends Object>([String? instanceName]) {
  return FutureProvider<T>((ref) async {
    final locator = ref.read(serviceLocatorProvider);
    return await locator.getAsync<T>(instanceName: instanceName);
  });
}

/// 可选服务Provider
Provider<T?> optionalServiceProvider<T extends Object>([String? instanceName]) {
  return Provider<T?>((ref) {
    final locator = ref.read(serviceLocatorProvider);
    return locator.tryGet<T>(instanceName: instanceName);
  });
}

/// 服务初始化器
abstract class ServiceInitializer {
  /// 初始化优先级（数字越小优先级越高）
  int get priority => 100;
  
  /// 初始化服务
  Future<void> initialize(ServiceLocator locator);
  
  /// 服务名称
  String get name;
}

/// 服务初始化管理器
class ServiceInitializationManager {
  static final List<ServiceInitializer> _initializers = [];
  
  /// 注册初始化器
  static void register(ServiceInitializer initializer) {
    _initializers.add(initializer);
    _initializers.sort((a, b) => a.priority.compareTo(b.priority));
  }
  
  /// 执行所有初始化器
  static Future<AppResult<void>> initializeAll(ServiceLocator locator) async {
    try {
      for (final initializer in _initializers) {
        if (kDebugMode) {
          debugPrint('Initializing service: ${initializer.name}');
        }
        
        await initializer.initialize(locator);
        
        if (kDebugMode) {
          debugPrint('Service initialized: ${initializer.name}');
        }
      }
      
      return const Result.success(null);
    } catch (e, stackTrace) {
      return Result.failure(BusinessError(
        'Service initialization failed',
        e,
      ));
    }
  }
  
  /// 清理所有初始化器
  static void clear() {
    _initializers.clear();
  }
}

/// 服务健康检查
mixin ServiceHealthCheck {
  /// 健康检查
  Future<bool> healthCheck();
  
  /// 健康状态描述
  String get healthStatus;
}

/// 服务监控
class ServiceMonitor {
  static final Map<Type, ServiceMetrics> _metrics = {};
  
  /// 记录服务获取
  static void recordGet<T>(Duration duration) {
    _metrics.putIfAbsent(T, () => ServiceMetrics()).recordGet(duration);
  }
  
  /// 记录服务创建
  static void recordCreate<T>(Duration duration) {
    _metrics.putIfAbsent(T, () => ServiceMetrics()).recordCreate(duration);
  }
  
  /// 获取服务指标
  static ServiceMetrics? getMetrics<T>() => _metrics[T];
  
  /// 获取所有指标
  static Map<Type, ServiceMetrics> get allMetrics => Map.unmodifiable(_metrics);
  
  /// 清理指标
  static void clearMetrics() {
    _metrics.clear();
  }
}

/// 服务指标
class ServiceMetrics {
  int _getCount = 0;
  int _createCount = 0;
  Duration _totalGetTime = Duration.zero;
  Duration _totalCreateTime = Duration.zero;
  
  /// 记录获取操作
  void recordGet(Duration duration) {
    _getCount++;
    _totalGetTime += duration;
  }
  
  /// 记录创建操作
  void recordCreate(Duration duration) {
    _createCount++;
    _totalCreateTime += duration;
  }
  
  /// 获取次数
  int get getCount => _getCount;
  
  /// 创建次数
  int get createCount => _createCount;
  
  /// 平均获取时间
  Duration get averageGetTime => 
      _getCount > 0 ? Duration(microseconds: _totalGetTime.inMicroseconds ~/ _getCount) : Duration.zero;
  
  /// 平均创建时间
  Duration get averageCreateTime => 
      _createCount > 0 ? Duration(microseconds: _totalCreateTime.inMicroseconds ~/ _createCount) : Duration.zero;
  
  @override
  String toString() {
    return 'ServiceMetrics('
        'gets: $_getCount, '
        'creates: $_createCount, '
        'avgGet: ${averageGetTime.inMilliseconds}ms, '
        'avgCreate: ${averageCreateTime.inMilliseconds}ms'
        ')';
  }
}

/// 服务定位器事件
class ServiceLocatorInitializedEvent extends AppEvent {
  const ServiceLocatorInitializedEvent({super.timestamp});
  
  @override
  String toString() => 'ServiceLocatorInitializedEvent()';
}

class ServiceRegisteredEvent extends AppEvent {
  const ServiceRegisteredEvent({
    required this.serviceType,
    this.instanceName,
    super.timestamp,
  });
  
  final Type serviceType;
  final String? instanceName;
  
  @override
  String toString() => 'ServiceRegisteredEvent(type: $serviceType${instanceName != null ? ', name: $instanceName' : ''})';
}

class ServiceUnregisteredEvent extends AppEvent {
  const ServiceUnregisteredEvent({
    required this.serviceType,
    this.instanceName,
    super.timestamp,
  });
  
  final Type serviceType;
  final String? instanceName;
  
  @override
  String toString() => 'ServiceUnregisteredEvent(type: $serviceType${instanceName != null ? ', name: $instanceName' : ''})';
} 