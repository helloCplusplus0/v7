import 'dart:async';

import 'package:v7_flutter_app/shared/contracts/base_contract.dart';

/// 事件总线
/// 为功能切片提供解耦的事件通信机制

class EventBus {
  static final EventBus _instance = EventBus._internal();
  static EventBus get instance => _instance;

  final Map<String, Set<StreamController<Map<String, dynamic>>>> _controllers = {};

  EventBus._internal();

  /// 订阅事件
  StreamSubscription<Map<String, dynamic>> on(
    String event,
    void Function(Map<String, dynamic> data) handler,
  ) {
    final controllers = _controllers[event] ??= <StreamController<Map<String, dynamic>>>{};
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    controllers.add(controller);

    final subscription = controller.stream.listen(handler);

    // 返回包装的订阅，用于清理
    return subscription;
  }

  /// 发布事件
  void emit(String event, Map<String, dynamic> data) {
    final controllers = _controllers[event];
    if (controllers != null) {
      for (final controller in controllers) {
        if (!controller.isClosed) {
          controller.add(data);
        }
      }
    }
  }

  /// 移除事件监听器
  void off(String event) {
    final controllers = _controllers[event];
    if (controllers != null) {
      for (final controller in controllers) {
        controller.close();
      }
      _controllers.remove(event);
    }
  }

  /// 清理所有事件监听器
  void clear() {
    for (final controllers in _controllers.values) {
      for (final controller in controllers) {
        controller.close();
      }
    }
    _controllers.clear();
  }
}

/// 全局事件总线实例
final eventBus = EventBus.instance;

/// v7 架构预定义事件类型
class AppEvent {
  const AppEvent();
}

/// 通知类型枚举
enum NotificationType {
  info,
  warning,
  error,
  success,
}

/// 用户事件
class UserLoginEvent extends AppEvent {
  const UserLoginEvent(this.user);
  final User user;
}

class UserLogoutEvent extends AppEvent {
  const UserLogoutEvent();
}

/// 导航事件
class NavigationEvent extends AppEvent {
  const NavigationEvent(this.route, {this.parameters});
  final String route;
  final Map<String, dynamic>? parameters;
}

/// 通知事件
class NotificationEvent extends AppEvent {
  const NotificationEvent({
    required this.message,
    required this.type,
    this.duration,
  });
  final String message;
  final NotificationType type;
  final Duration? duration;
}

/// 网络状态事件
class NetworkStatusEvent extends AppEvent {
  const NetworkStatusEvent(this.isConnected);
  final bool isConnected;
}

/// 应用生命周期事件
class AppLifecycleEvent extends AppEvent {
  const AppLifecycleEvent(this.state);
  final AppLifecycleState state;
}

enum AppLifecycleState {
  resumed,
  inactive,
  paused,
  detached,
} 