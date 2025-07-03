/// v7 架构基础合约接口
/// 定义切片间通信的核心规范
abstract class BaseContract {
  /// 合约名称
  String get contractName;
  
  /// 合约版本
  String get version => '1.0.0';
  
  /// 初始化合约
  Future<void> initialize();
  
  /// 销毁合约
  Future<void> dispose();
  
  /// 健康检查
  bool get isHealthy;
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

/// 用户基础信息
class User {
  const User({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.displayName,
  });
  
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? displayName;
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
    required this.username,
    required this.password,
  });
  
  final String username;
  final String password;
}

/// 通知类型
enum NotificationType {
  info,
  success,
  warning,
  error,
} 