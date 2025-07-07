/// 防抖工具类
/// 用于限制函数调用频率，避免过于频繁的操作（如搜索、API调用等）
/// 
/// 使用场景：
/// - 搜索输入防抖
/// - API请求限流
/// - 按钮防重复点击
/// - 滚动事件优化

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 防抖器
/// 
/// 在指定时间内，只会执行最后一次调用
class Debouncer {
  Debouncer({
    required this.delay,
    this.onDebug,
  });
  
  final Duration delay;
  final VoidCallback? onDebug;
  
  Timer? _timer;
  int _callCount = 0;
  
  /// 执行防抖函数
  void call(VoidCallback action) {
    _callCount++;
    
    // 取消之前的计时器
    _timer?.cancel();
    
    // 设置新的计时器
    _timer = Timer(delay, () {
      action();
      
      if (kDebugMode && onDebug != null) {
        debugPrint('Debouncer executed after $_callCount calls');
        onDebug?.call();
      }
      
      _callCount = 0;
    });
  }
  
  /// 立即执行（忽略防抖）
  void immediate(VoidCallback action) {
    _timer?.cancel();
    action();
    _callCount = 0;
  }
  
  /// 取消等待中的执行
  void cancel() {
    _timer?.cancel();
    _callCount = 0;
  }
  
  /// 是否有等待中的执行
  bool get isPending => _timer?.isActive ?? false;
  
  /// 获取调用次数（用于调试）
  int get callCount => _callCount;
  
  /// 释放资源
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// 异步防抖器
/// 
/// 支持异步函数的防抖执行
class AsyncDebouncer {
  AsyncDebouncer({
    required this.delay,
    this.onDebug,
  });
  
  final Duration delay;
  final VoidCallback? onDebug;
  
  Timer? _timer;
  Completer<void>? _completer;
  int _callCount = 0;
  
  /// 执行异步防抖函数
  Future<T> call<T>(Future<T> Function() action) async {
    _callCount++;
    
    // 取消之前的计时器和完成器
    _timer?.cancel();
    _completer?.completeError('Cancelled by new call');
    
    // 创建新的完成器
    _completer = Completer<void>();
    
    // 设置新的计时器
    _timer = Timer(delay, () {
      _completer?.complete();
    });
    
    try {
      // 等待防抖时间
      await _completer!.future;
      
      // 执行实际操作
      final result = await action();
      
      if (kDebugMode && onDebug != null) {
        debugPrint('AsyncDebouncer executed after $_callCount calls');
        onDebug?.call();
      }
      
      _callCount = 0;
      return result;
    } catch (e) {
      if (e.toString().contains('Cancelled')) {
        throw DebounceCancelledException();
      }
      rethrow;
    }
  }
  
  /// 立即执行异步函数（忽略防抖）
  Future<T> immediate<T>(Future<T> Function() action) async {
    _timer?.cancel();
    _completer?.completeError('Cancelled by immediate call');
    
    final result = await action();
    _callCount = 0;
    return result;
  }
  
  /// 取消等待中的执行
  void cancel() {
    _timer?.cancel();
    _completer?.completeError('Cancelled manually');
    _callCount = 0;
  }
  
  /// 是否有等待中的执行
  bool get isPending => _timer?.isActive ?? false;
  
  /// 获取调用次数（用于调试）
  int get callCount => _callCount;
  
  /// 释放资源
  void dispose() {
    _timer?.cancel();
    if (_completer != null && !_completer!.isCompleted) {
      try {
        _completer!.completeError(DebounceCancelledException('Disposed'));
      } catch (e) {
        // 忽略已完成的Future错误
      }
    }
    _timer = null;
    _completer = null;
  }
}

/// 防抖取消异常
class DebounceCancelledException implements Exception {
  const DebounceCancelledException([this.message = 'Debounce call was cancelled']);
  
  final String message;
  
  @override
  String toString() => 'DebounceCancelledException: $message';
}

/// 搜索防抖器
/// 
/// 专门为搜索场景优化的防抖器
class SearchDebouncer {
  SearchDebouncer({
    this.delay = const Duration(milliseconds: 500),
    this.minLength = 0,
    this.onSearch,
    this.onClear,
  });
  
  final Duration delay;
  final int minLength;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onClear;
  
  late final Debouncer _debouncer = Debouncer(delay: delay);
  String _lastQuery = '';
  
  /// 搜索函数
  void search(String query) {
    query = query.trim();
    
    // 如果查询为空或长度不足，清空搜索
    if (query.isEmpty || query.length < minLength) {
      _debouncer.cancel();
      if (_lastQuery.isNotEmpty) {
        _lastQuery = '';
      }
      // 总是调用onClear来清空结果，即使_lastQuery为空
      onClear?.call();
      return;
    }
    
    // 如果查询没有变化，不执行搜索
    if (query == _lastQuery) {
      return;
    }
    
    _lastQuery = query;
    _debouncer.call(() {
      onSearch?.call(query);
    });
  }
  
  /// 立即搜索（忽略防抖）
  void searchImmediate(String query) {
    query = query.trim();
    _lastQuery = query;
    
    if (query.isEmpty || query.length < minLength) {
      onClear?.call();
    } else {
      onSearch?.call(query);
    }
  }
  
  /// 清空搜索
  void clear() {
    _debouncer.cancel();
    _lastQuery = '';
    onClear?.call();
  }
  
  /// 当前查询
  String get currentQuery => _lastQuery;
  
  /// 是否有等待中的搜索
  bool get isPending => _debouncer.isPending;
  
  /// 释放资源
  void dispose() {
    _debouncer.dispose();
  }
}

/// 节流器
/// 
/// 在指定时间内，最多只会执行一次
class Throttler {
  Throttler({
    required this.duration,
    this.onDebug,
  });
  
  final Duration duration;
  final VoidCallback? onDebug;
  
  DateTime? _lastExecutionTime;
  Timer? _timer;
  bool _hasScheduledExecution = false;
  
  /// 执行节流函数
  void call(VoidCallback action) {
    final now = DateTime.now();
    
    if (_lastExecutionTime == null ||
        now.difference(_lastExecutionTime!) >= duration) {
      // 立即执行
      _lastExecutionTime = now;
      action();
      
      if (kDebugMode && onDebug != null) {
        debugPrint('Throttler executed immediately');
        onDebug?.call();
      }
    } else if (!_hasScheduledExecution) {
      // 调度延迟执行
      _hasScheduledExecution = true;
      final remainingTime = duration - now.difference(_lastExecutionTime!);
      
      _timer = Timer(remainingTime, () {
        _lastExecutionTime = DateTime.now();
        _hasScheduledExecution = false;
        action();
        
        if (kDebugMode && onDebug != null) {
          debugPrint('Throttler executed after delay');
          onDebug?.call();
        }
      });
    }
  }
  
  /// 取消等待中的执行
  void cancel() {
    _timer?.cancel();
    _hasScheduledExecution = false;
  }
  
  /// 重置节流器
  void reset() {
    _timer?.cancel();
    _lastExecutionTime = null;
    _hasScheduledExecution = false;
  }
  
  /// 是否有等待中的执行
  bool get isPending => _hasScheduledExecution;
  
  /// 距离下次可执行的时间
  Duration? get timeUntilNextExecution {
    if (_lastExecutionTime == null) return null;
    
    final elapsed = DateTime.now().difference(_lastExecutionTime!);
    if (elapsed >= duration) return Duration.zero;
    
    return duration - elapsed;
  }
  
  /// 释放资源
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// 防抖和节流的组合工具
class DebounceThrottle {
  DebounceThrottle({
    required this.debounceDelay,
    required this.throttleDuration,
  });
  
  final Duration debounceDelay;
  final Duration throttleDuration;
  
  late final Debouncer _debouncer = Debouncer(delay: debounceDelay);
  late final Throttler _throttler = Throttler(duration: throttleDuration);
  
  /// 执行函数（先节流后防抖）
  void call(VoidCallback action) {
    _throttler.call(() {
      _debouncer.call(action);
    });
  }
  
  /// 立即执行
  void immediate(VoidCallback action) {
    _debouncer.cancel();
    _throttler.cancel();
    action();
  }
  
  /// 取消所有等待中的执行
  void cancel() {
    _debouncer.cancel();
    _throttler.cancel();
  }
  
  /// 重置状态
  void reset() {
    _debouncer.cancel();
    _throttler.reset();
  }
  
  /// 是否有等待中的执行
  bool get isPending => _debouncer.isPending || _throttler.isPending;
  
  /// 释放资源
  void dispose() {
    _debouncer.dispose();
    _throttler.dispose();
  }
}

/// 防抖工厂类
/// 
/// 提供常用防抖器的快速创建方法
class DebounceFactory {
  /// 创建搜索防抖器
  static SearchDebouncer search({
    Duration delay = const Duration(milliseconds: 500),
    int minLength = 1,
    ValueChanged<String>? onSearch,
    VoidCallback? onClear,
  }) {
    return SearchDebouncer(
      delay: delay,
      minLength: minLength,
      onSearch: onSearch,
      onClear: onClear,
    );
  }
  
  /// 创建API请求防抖器
  static AsyncDebouncer apiRequest({
    Duration delay = const Duration(milliseconds: 300),
  }) {
    return AsyncDebouncer(
      delay: delay,
      onDebug: () => debugPrint('API request debounced'),
    );
  }
  
  /// 创建按钮点击防抖器
  static Debouncer buttonClick({
    Duration delay = const Duration(milliseconds: 1000),
  }) {
    return Debouncer(
      delay: delay,
      onDebug: () => debugPrint('Button click debounced'),
    );
  }
  
  /// 创建滚动事件节流器
  static Throttler scrollEvent({
    Duration duration = const Duration(milliseconds: 100),
  }) {
    return Throttler(
      duration: duration,
      onDebug: () => debugPrint('Scroll event throttled'),
    );
  }
} 