import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'events.dart';

/// 简单的事件总线实现
class EventBus {
  static final EventBus _instance = EventBus._internal();
  static EventBus get instance => _instance;
  
  EventBus._internal();
  
  final Map<Type, List<Function>> _subscriptions = {};
  
  /// 发布事件
  void emit<T extends AppEvent>(T event) {
    if (kDebugMode) {
      developer.log('Event emitted: ${event.runtimeType}', name: 'EventBus');
    }
    
    // 直接类型匹配
    final subscriptions = _subscriptions[T];
    if (subscriptions != null) {
      // 创建副本避免并发修改
      final handlers = List<Function>.from(subscriptions);
      for (final handler in handlers) {
        try {
          handler(event);
        } catch (e) {
          if (kDebugMode) {
            developer.log('Error in event handler: $e', name: 'EventBus');
          }
        }
      }
    }
    
    // 运行时类型匹配
    final runtimeSubscriptions = _subscriptions[event.runtimeType];
    if (runtimeSubscriptions != null && runtimeSubscriptions != subscriptions) {
      // 创建副本避免并发修改
      final handlers = List<Function>.from(runtimeSubscriptions);
      for (final handler in handlers) {
        try {
          handler(event);
        } catch (e) {
          if (kDebugMode) {
            developer.log('Error in event handler: $e', name: 'EventBus');
          }
        }
      }
    }
    
    // 父类型匹配
    final subscriptionEntries = _subscriptions.entries.toList();
    for (final entry in subscriptionEntries) {
      if (entry.key == T || entry.key == event.runtimeType) continue;
      
      if (_isInstanceOfType(event, entry.key)) {
        // 创建副本避免并发修改
        final handlers = List<Function>.from(entry.value);
        for (final handler in handlers) {
          try {
            handler(event);
          } catch (e) {
            if (kDebugMode) {
              developer.log('Error in event handler: $e', name: 'EventBus');
            }
          }
        }
      }
    }
  }
  
  /// 订阅事件
  VoidCallback on<T extends AppEvent>(void Function(T) handler) {
    _subscriptions.putIfAbsent(T, () => []).add(handler);
    
    if (kDebugMode) {
      developer.log('Event subscription added for: $T', name: 'EventBus');
    }
    
    return () {
      _subscriptions[T]?.remove(handler);
      if (_subscriptions[T]?.isEmpty == true) {
        _subscriptions.remove(T);
      }
    };
  }
  
  /// 订阅一次性事件
  VoidCallback once<T extends AppEvent>(void Function(T) handler) {
    VoidCallback? unsubscribe;
    
    unsubscribe = on<T>((event) {
      unsubscribe?.call();
      handler(event);
    });
    
    return unsubscribe;
  }
  
  /// 等待特定事件
  Future<T> waitFor<T extends AppEvent>({Duration? timeout}) {
    final completer = Completer<T>();
    VoidCallback? unsubscribe;
    Timer? timeoutTimer;
    
    unsubscribe = on<T>((event) {
      timeoutTimer?.cancel();
      unsubscribe?.call();
      if (!completer.isCompleted) {
        completer.complete(event);
      }
    });
    
    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        unsubscribe?.call();
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException('Event $T not received within $timeout', timeout),
          );
        }
      });
    }
    
    return completer.future;
  }
  
  /// 条件订阅事件
  VoidCallback onWhen<T extends AppEvent>(
    bool Function(T) condition,
    void Function(T) handler,
  ) {
    return on<T>((event) {
      if (condition(event)) {
        handler(event);
      }
    });
  }
  
  /// 清除所有订阅
  void clear() {
    _subscriptions.clear();
    if (kDebugMode) {
      developer.log('EventBus cleared', name: 'EventBus');
    }
  }
  
  /// 获取活跃的订阅数量
  int get activeSubscriptionCount {
    int count = 0;
    for (final subscriptions in _subscriptions.values) {
      count += subscriptions.length;
    }
    return count;
  }
  
  /// 检查是否是指定类型的实例
  bool _isInstanceOfType(AppEvent event, Type type) {
    final targetTypeString = type.toString();
    
    if (event is UserEvent && targetTypeString == 'UserEvent') return true;
    if (event is DataSyncEvent && targetTypeString == 'DataSyncEvent') return true;
    if (event is NetworkEvent && targetTypeString == 'NetworkEvent') return true;
    if (event is AppLifecycleEvent && targetTypeString == 'AppLifecycleEvent') return true;
    if (event is CacheEvent && targetTypeString == 'CacheEvent') return true;
    
    return false;
  }
}

/// 事件总线错误事件
class EventBusErrorEvent extends AppEvent {
  const EventBusErrorEvent({
    required this.originalEvent,
    required this.error,
    required this.stackTrace,
    super.timestamp,
  });
  
  final AppEvent originalEvent;
  final Object error;
  final StackTrace stackTrace;
  
  @override
  String toString() => 'EventBusErrorEvent(original: $originalEvent, error: $error)';
}

/// Riverpod Provider for EventBus
final eventBusProvider = Provider<EventBus>((ref) {
  return EventBus.instance;
});

/// Widget扩展，简化事件订阅
extension EventBusWidget on ConsumerWidget {
  /// 在Widget中订阅事件，自动处理生命周期
  void useEventListener<T extends AppEvent>(
    WidgetRef ref,
    void Function(T) handler, {
    List<Object?> keys = const [],
  }) {
    final eventBus = ref.watch(eventBusProvider);
    eventBus.on<T>(handler);
  }
}

/// 统一事件发布接口
mixin EventPublisher {
  void publishEvent<T extends AppEvent>(T event) {
    EventBus.instance.emit(event);
  }
}

/// 全局事件总线实例
final eventBus = EventBus.instance; 