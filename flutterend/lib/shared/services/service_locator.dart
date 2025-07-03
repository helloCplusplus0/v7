import 'package:get_it/get_it.dart';
import '../network/api_client.dart';

/// 服务定位器
/// 为功能切片提供依赖注入能力
class ServiceLocator {
  static final GetIt _getIt = GetIt.instance;

  /// 初始化所有服务
  static Future<void> initialize() async {
    // 注册API客户端
    _getIt.registerSingleton<ApiClient>(ApiClient());
  }

  /// 获取服务实例
  static T get<T extends Object>() {
    return _getIt.get<T>();
  }

  /// 注册服务
  static void register<T extends Object>(T instance) {
    if (!_getIt.isRegistered<T>()) {
      _getIt.registerSingleton<T>(instance);
    }
  }

  /// 注册懒加载服务
  static void registerLazy<T extends Object>(T Function() factory) {
    if (!_getIt.isRegistered<T>()) {
      _getIt.registerLazySingleton<T>(factory);
    }
  }

  /// 重置服务
  static Future<void> reset() async {
    await _getIt.reset();
  }

  /// 检查服务是否已注册
  static bool isRegistered<T extends Object>() {
    return _getIt.isRegistered<T>();
  }
} 