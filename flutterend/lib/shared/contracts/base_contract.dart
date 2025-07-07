import 'dart:async';
import 'package:flutter/foundation.dart';
import '../types/result.dart';
import '../types/user.dart';

/// v7 架构基础合约接口
/// 定义切片间通信的核心规范

/// 契约接口基类
/// 
/// 所有业务契约都应该继承此接口，确保类型安全和生命周期管理
abstract class BaseContract {
  /// 初始化契约
  /// 
  /// 在使用契约前必须调用此方法进行初始化
  Future<AppResult<void>> initialize();
  
  /// 销毁契约
  /// 
  /// 清理资源，取消订阅等
  Future<void> dispose();
  
  /// 契约是否已初始化
  bool get isInitialized;
  
  /// 契约是否已销毁
  bool get isDisposed;
  
  /// 契约名称
  String get contractName;
  
  /// 契约版本
  String get contractVersion => '1.0.0';
}

/// 认证合约接口
abstract class AuthContract extends BaseContract {
  @override
  String get contractName => 'auth';
  
  /// 当前用户信息
  User? getCurrentUser();
  
  /// 是否已认证
  bool get isAuthenticated;
  
  /// 登录
  Future<AuthResult> login(LoginRequest request);
  
  /// 登出
  Future<void> logout();
  
  /// 刷新令牌
  Future<String?> refreshToken();
  
  /// 验证令牌
  Future<bool> validateToken(String token);
}

/// 通知合约接口
abstract class NotificationContract extends BaseContract {
  @override
  String get contractName => 'notification';
  
  /// 显示通知
  void show(String message, NotificationType type);
  
  /// 显示加载状态
  void showLoading({String? message});
  
  /// 隐藏加载状态
  void hideLoading();
  
  /// 显示确认对话框
  Future<bool> showConfirmDialog(String title, String message);
  
  /// 显示错误
  void showError(String message, {String? details});
  
  /// 显示成功提示
  void showSuccess(String message);
}

/// 导航合约接口
abstract class NavigationContract extends BaseContract {
  @override
  String get contractName => 'navigation';
  
  /// 导航到指定路由
  Future<void> navigateTo(String route, {Map<String, dynamic>? parameters});
  
  /// 替换当前路由
  Future<void> replaceTo(String route, {Map<String, dynamic>? parameters});
  
  /// 返回上一页
  void goBack();
  
  /// 清空导航栈并导航到指定路由
  Future<void> navigateAndClearStack(String route);
  
  /// 获取当前路由
  String? getCurrentRoute();
}

/// 认证结果
class AuthResult {
  const AuthResult({
    required this.success,
    this.user,
    this.token,
    this.error,
  });
  
  final bool success;
  final User? user;
  final String? token;
  final String? error;
}

/// 登录请求
class LoginRequest {
  const LoginRequest({
    required this.email,
    required this.password,
  });
  
  final String email;
  final String password;
}

/// 通知类型
enum NotificationType {
  info,
  success,
  warning,
  error,
}

/// 异步契约接口
/// 
/// 为需要异步操作的契约提供基础实现
abstract class AsyncContract extends BaseContract {
  final Completer<void> _initCompleter = Completer<void>();
  bool _isInitialized = false;
  bool _isDisposed = false;
  
  @override
  bool get isInitialized => _isInitialized;
  
  @override
  bool get isDisposed => _isDisposed;
  
  /// 等待初始化完成
  Future<void> get ready => _initCompleter.future;
  
  @override
  Future<AppResult<void>> initialize() async {
    if (_isDisposed) {
      return Result.failure(BusinessError(
        'Cannot initialize disposed contract: $contractName',
      ));
    }
    
    if (_isInitialized) {
      return const Result.success(null);
    }
    
    try {
      await onInitialize();
      _isInitialized = true;
      
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      
      if (kDebugMode) {
        debugPrint('Contract initialized: $contractName');
      }
      
      return const Result.success(null);
    } catch (e, stackTrace) {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      
      return Result.failure(BusinessError(
        'Failed to initialize contract: $contractName',
        e,
      ));
    }
  }
  
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    try {
      await onDispose();
      _isDisposed = true;
      
      if (kDebugMode) {
        debugPrint('Contract disposed: $contractName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error disposing contract $contractName: $e');
      }
    }
  }
  
  /// 子类实现的初始化逻辑
  @protected
  Future<void> onInitialize();
  
  /// 子类实现的销毁逻辑
  @protected
  Future<void> onDispose();
  
  /// 确保契约已初始化
  @protected
  void ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('Contract $contractName is not initialized');
    }
    
    if (_isDisposed) {
      throw StateError('Contract $contractName is disposed');
    }
  }
  
  /// 安全执行方法，确保契约状态正确
  @protected
  Future<AppResult<T>> safeExecute<T>(
    Future<T> Function() operation,
  ) async {
    try {
      ensureInitialized();
      final result = await operation();
      return Result.success(result);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error in contract $contractName: $e');
        debugPrint('StackTrace: $stackTrace');
      }
      
      return Result.failure(BusinessError(
        'Operation failed in contract: $contractName',
        e,
      ));
    }
  }
}

/// 同步契约接口
/// 
/// 为不需要异步操作的契约提供基础实现
abstract class SyncContract extends BaseContract {
  bool _isInitialized = false;
  bool _isDisposed = false;
  
  @override
  bool get isInitialized => _isInitialized;
  
  @override
  bool get isDisposed => _isDisposed;
  
  @override
  Future<AppResult<void>> initialize() async {
    if (_isDisposed) {
      return Result.failure(BusinessError(
        'Cannot initialize disposed contract: $contractName',
      ));
    }
    
    if (_isInitialized) {
      return const Result.success(null);
    }
    
    try {
      onInitialize();
      _isInitialized = true;
      
      if (kDebugMode) {
        debugPrint('Contract initialized: $contractName');
      }
      
      return const Result.success(null);
    } catch (e) {
      return Result.failure(BusinessError(
        'Failed to initialize contract: $contractName',
        e,
      ));
    }
  }
  
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    try {
      onDispose();
      _isDisposed = true;
      
      if (kDebugMode) {
        debugPrint('Contract disposed: $contractName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error disposing contract $contractName: $e');
      }
    }
  }
  
  /// 子类实现的初始化逻辑
  @protected
  void onInitialize();
  
  /// 子类实现的销毁逻辑
  @protected
  void onDispose();
}

/// 切片摘要契约接口
abstract class SliceSummaryContract extends BaseContract {
  @override
  String get contractName => 'slice_summary';
  
  /// 获取切片摘要
  Future<String> getSummary(String sliceName);
  
  /// 批量获取切片摘要
  Future<Map<String, String>> getBatchSummaries(List<String> sliceNames);
  
  /// 检查切片是否可用
  bool isSliceAvailable(String sliceName);
  
  /// 获取所有可用的切片
  List<String> getAvailableSlices();
}

/// 可观察的契约接口
/// 
/// 为需要发布状态变化的契约提供观察者模式支持
mixin ObservableContract {
  final StreamController<ContractStateChange> _stateController = 
      StreamController<ContractStateChange>.broadcast();
  
  /// 状态变化流
  Stream<ContractStateChange> get stateChanges => _stateController.stream;
  
  /// 发布状态变化
  @protected
  void notifyStateChange(String property, dynamic oldValue, dynamic newValue) {
    if (!_stateController.isClosed) {
      _stateController.add(ContractStateChange(
        contractName: (this as BaseContract).contractName,
        property: property,
        oldValue: oldValue,
        newValue: newValue,
        timestamp: DateTime.now(),
      ));
    }
  }
  
  /// 清理观察者资源
  @protected
  Future<void> disposeObservable() async {
    await _stateController.close();
  }
}

/// 契约状态变化事件
class ContractStateChange {
  const ContractStateChange({
    required this.contractName,
    required this.property,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
  });
  
  final String contractName;
  final String property;
  final dynamic oldValue;
  final dynamic newValue;
  final DateTime timestamp;
  
  @override
  String toString() => 
      'ContractStateChange($contractName.$property: $oldValue → $newValue)';
}

/// 契约依赖接口
/// 
/// 为需要依赖其他契约的契约提供依赖管理
mixin DependentContract {
  final Set<BaseContract> _dependencies = {};
  
  /// 添加依赖
  @protected
  void addDependency(BaseContract contract) {
    _dependencies.add(contract);
  }
  
  /// 移除依赖
  @protected
  void removeDependency(BaseContract contract) {
    _dependencies.remove(contract);
  }
  
  /// 获取所有依赖
  @protected
  Set<BaseContract> get dependencies => Set.unmodifiable(_dependencies);
  
  /// 等待所有依赖初始化完成
  @protected
  Future<void> waitForDependencies() async {
    final futures = _dependencies
        .where((contract) => contract is AsyncContract)
        .map((contract) => (contract as AsyncContract).ready);
    
    await Future.wait(futures);
  }
  
  /// 检查依赖状态
  @protected
  bool get dependenciesReady {
    return _dependencies.every((contract) => contract.isInitialized);
  }
  
  /// 清理依赖资源
  @protected
  Future<void> disposeDependencies() async {
    // 不直接dispose依赖，只清除引用
    _dependencies.clear();
  }
}

/// 可缓存的契约接口
/// 
/// 为需要缓存数据的契约提供缓存管理
mixin CacheableContract {
  final Map<String, _CacheEntry> _cache = {};
  Duration _defaultTtl = const Duration(minutes: 5);
  
  /// 设置默认缓存TTL
  @protected
  void setDefaultCacheTtl(Duration ttl) {
    _defaultTtl = ttl;
  }
  
  /// 从缓存获取数据
  @protected
  T? getFromCache<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    
    return entry.value as T?;
  }
  
  /// 存储到缓存
  @protected
  void setCache<T>(String key, T value, {Duration? ttl}) {
    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? _defaultTtl),
    );
  }
  
  /// 清除缓存项
  @protected
  void clearCache(String key) {
    _cache.remove(key);
  }
  
  /// 清除所有缓存
  @protected
  void clearAllCache() {
    _cache.clear();
  }
  
  /// 清理过期缓存
  @protected
  void cleanupExpiredCache() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) => entry.expiresAt.isBefore(now));
  }
  
  /// 获取缓存统计
  @protected
  CacheStats get cacheStats {
    final now = DateTime.now();
    final validEntries = _cache.values.where((entry) => entry.expiresAt.isAfter(now));
    
    return CacheStats(
      totalEntries: _cache.length,
      validEntries: validEntries.length,
      expiredEntries: _cache.length - validEntries.length,
    );
  }
}

/// 缓存条目
class _CacheEntry {
  const _CacheEntry({
    required this.value,
    required this.expiresAt,
  });
  
  final dynamic value;
  final DateTime expiresAt;
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// 缓存统计
class CacheStats {
  const CacheStats({
    required this.totalEntries,
    required this.validEntries,
    required this.expiredEntries,
  });
  
  final int totalEntries;
  final int validEntries;
  final int expiredEntries;
  
  @override
  String toString() => 
      'CacheStats(total: $totalEntries, valid: $validEntries, expired: $expiredEntries)';
}

/// 契约工厂接口
abstract class ContractFactory<T extends BaseContract> {
  /// 创建契约实例
  T create();
  
  /// 契约类型
  Type get contractType => T;
  
  /// 是否为单例
  bool get isSingleton => true;
}

/// 契约注册器
class ContractRegistry {
  static final ContractRegistry _instance = ContractRegistry._();
  static ContractRegistry get instance => _instance;
  
  ContractRegistry._();
  
  final Map<Type, ContractFactory> _factories = {};
  final Map<Type, BaseContract> _singletons = {};
  
  /// 注册契约工厂
  void register<T extends BaseContract>(ContractFactory<T> factory) {
    _factories[T] = factory;
    
    if (kDebugMode) {
      debugPrint('Contract factory registered: $T');
    }
  }
  
  /// 获取契约实例
  T get<T extends BaseContract>() {
    final factory = _factories[T] as ContractFactory<T>?;
    if (factory == null) {
      throw StateError('Contract factory not found for type: $T');
    }
    
    if (factory.isSingleton) {
      return _singletons.putIfAbsent(T, () => factory.create()) as T;
    }
    
    return factory.create();
  }
  
  /// 检查契约是否已注册
  bool isRegistered<T extends BaseContract>() {
    return _factories.containsKey(T);
  }
  
  /// 获取所有已注册的契约类型
  Set<Type> get registeredTypes => Set.unmodifiable(_factories.keys);
  
  /// 清理单例实例
  Future<void> clearSingletons() async {
    for (final contract in _singletons.values) {
      await contract.dispose();
    }
    _singletons.clear();
  }
  
  /// 清理所有注册
  Future<void> clear() async {
    await clearSingletons();
    _factories.clear();
  }
}

/// 契约验证器
class ContractValidator {
  /// 验证契约实现
  static AppResult<void> validate(BaseContract contract) {
    final errors = <String>[];
    
    // 检查契约名称
    if (contract.contractName.isEmpty) {
      errors.add('Contract name cannot be empty');
    }
    
    // 检查契约版本
    if (contract.contractVersion.isEmpty) {
      errors.add('Contract version cannot be empty');
    }
    
    // 检查异步契约的实现
    if (contract is AsyncContract) {
      // 可以添加更多异步契约特定的验证
    }
    
    if (errors.isNotEmpty) {
      return Result.failure(ValidationError(
        'Contract validation failed: ${errors.join(', ')}',
      ));
    }
    
    return const Result.success(null);
  }
} 