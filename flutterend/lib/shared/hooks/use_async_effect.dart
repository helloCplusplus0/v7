/// 异步副作用Provider和工具
/// 基于Riverpod实现的异步状态管理，用于处理复杂的异步操作
/// 
/// 使用场景：
/// - 组件初始化时的数据加载
/// - 网络请求的状态管理
/// - 自动重试和错误处理

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 异步副作用状态
class AsyncEffectState<T> {
  const AsyncEffectState({
    this.isLoading = false,
    this.data,
    this.error,
    this.lastUpdated,
  });
  
  final bool isLoading;
  final T? data;
  final String? error;
  final DateTime? lastUpdated;
  
  bool get hasData => data != null;
  bool get hasError => error != null;
  bool get isIdle => !isLoading && !hasError && !hasData;
  bool get isSuccess => !isLoading && hasData && !hasError;
  
  AsyncEffectState<T> copyWith({
    bool? isLoading,
    T? data,
    String? error,
    DateTime? lastUpdated,
  }) {
    return AsyncEffectState<T>(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error,  // 允许清除错误
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
  
  /// 转换数据类型
  AsyncEffectState<U> map<U>(U Function(T) mapper) {
    return AsyncEffectState<U>(
      isLoading: isLoading,
      data: hasData ? mapper(data as T) : null,
      error: error,
      lastUpdated: lastUpdated,
    );
  }
  
  /// 加载状态
  AsyncEffectState<T> loading() {
    return copyWith(
      isLoading: true,
      error: null,
    );
  }
  
  /// 成功状态
  AsyncEffectState<T> success(T data) {
    return copyWith(
      isLoading: false,
      data: data,
      error: null,
      lastUpdated: DateTime.now(),
    );
  }
  
  /// 错误状态
  AsyncEffectState<T> failure(String error) {
    return copyWith(
      isLoading: false,
      error: error,
      lastUpdated: DateTime.now(),
    );
  }
  
  @override
  String toString() {
    return 'AsyncEffectState(isLoading: $isLoading, hasData: $hasData, hasError: $hasError)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AsyncEffectState<T> &&
        other.isLoading == isLoading &&
        other.data == data &&
        other.error == error &&
        other.lastUpdated == lastUpdated;
  }
  
  @override
  int get hashCode => Object.hash(isLoading, data, error, lastUpdated);
}

/// 网络请求状态
class AsyncNetworkState<T> extends AsyncEffectState<T> {
  const AsyncNetworkState({
    super.isLoading,
    super.data,
    super.error,
    super.lastUpdated,
    this.retryCount = 0,
    this.maxRetries = 3,
  });
  
  final int retryCount;
  final int maxRetries;
  
  bool get isRetrying => retryCount > 0 && isLoading;
  bool get canRetry => retryCount < maxRetries;
  
  @override
  AsyncNetworkState<T> copyWith({
    bool? isLoading,
    T? data,
    String? error,
    DateTime? lastUpdated,
    int? retryCount,
    int? maxRetries,
  }) {
    return AsyncNetworkState<T>(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }
  
  /// 重试状态
  AsyncNetworkState<T> retry() {
    return copyWith(
      isLoading: true,
      error: null,
      retryCount: retryCount + 1,
    );
  }
  
  /// 重置重试计数
  AsyncNetworkState<T> resetRetry() {
    return copyWith(retryCount: 0);
  }
  
  @override
  String toString() {
    return 'AsyncNetworkState(isLoading: $isLoading, hasData: $hasData, hasError: $hasError, retryCount: $retryCount)';
  }
}

/// 创建异步副作用Provider
/// 
/// 用于管理异步操作的状态，包含加载、成功、失败状态
StateNotifierProvider<AsyncEffectNotifier<T>, AsyncEffectState<T>>
    createAsyncEffectProvider<T>(
  Future<T> Function() effect, {
  String? name,
}) {
  return StateNotifierProvider<AsyncEffectNotifier<T>, AsyncEffectState<T>>(
    (ref) => AsyncEffectNotifier<T>(effect),
    name: name ?? 'AsyncEffect<$T>',
  );
}

/// 异步副作用状态管理器
class AsyncEffectNotifier<T> extends StateNotifier<AsyncEffectState<T>> {
  AsyncEffectNotifier(this._effect) : super(const AsyncEffectState());
  
  final Future<T> Function() _effect;
  Timer? _debounceTimer;
  Completer<void>? _cancelToken;
  
  /// 执行异步副作用
  Future<void> execute() async {
    // 取消之前的操作
    _cancelToken?.complete();
    _cancelToken = Completer<void>();
    
    final currentToken = _cancelToken!;
    
    state = state.loading();
    
    try {
      final result = await _effect();
      
      if (!currentToken.isCompleted) {
        state = state.success(result);
      }
    } catch (error, stackTrace) {
      if (!currentToken.isCompleted) {
        state = state.failure(error.toString());
        
        if (kDebugMode) {
          debugPrint('AsyncEffect error: $error');
          debugPrint('StackTrace: $stackTrace');
        }
      }
    }
  }
  
  /// 防抖执行
  void executeDebounced({Duration delay = const Duration(milliseconds: 500)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, execute);
  }
  
  /// 重试执行
  Future<void> retry() async {
    await execute();
  }
  
  /// 重置状态
  void reset() {
    _cancelToken?.complete();
    state = const AsyncEffectState();
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cancelToken?.complete();
    super.dispose();
  }
}

/// 创建网络请求Provider
/// 
/// 专门处理网络请求，包含自动重试机制
StateNotifierProvider<NetworkEffectNotifier<T>, AsyncNetworkState<T>>
    createNetworkEffectProvider<T>(
  Future<T> Function() request, {
  int maxRetries = 3,
  Duration retryDelay = const Duration(seconds: 1),
  String? name,
}) {
  return StateNotifierProvider<NetworkEffectNotifier<T>, AsyncNetworkState<T>>(
    (ref) => NetworkEffectNotifier<T>(
      request,
      maxRetries: maxRetries,
      retryDelay: retryDelay,
    ),
    name: name ?? 'NetworkEffect<$T>',
  );
}

/// 网络请求状态管理器
class NetworkEffectNotifier<T> extends StateNotifier<AsyncNetworkState<T>> {
  NetworkEffectNotifier(
    this._request, {
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
  }) : super(const AsyncNetworkState());
  
  final Future<T> Function() _request;
  final int maxRetries;
  final Duration retryDelay;
  
  Completer<void>? _cancelToken;
  
  /// 执行网络请求
  Future<void> execute() async {
    // 取消之前的请求
    _cancelToken?.complete();
    _cancelToken = Completer<void>();
    
    await _executeWithRetry(0);
  }
  
  /// 带重试机制的执行
  Future<void> _executeWithRetry(int currentRetry) async {
    final currentToken = _cancelToken!;
    
    if (currentToken.isCompleted) return;
    
    if (currentRetry == 0) {
      state = AsyncNetworkState<T>(
        isLoading: true,
        maxRetries: maxRetries,
      );
    } else {
      state = state.retry();
    }
    
    try {
      final result = await _request();
      
      if (!currentToken.isCompleted) {
        state = AsyncNetworkState<T>(
          isLoading: false,
          data: result,
          lastUpdated: DateTime.now(),
          maxRetries: maxRetries,
        );
      }
    } catch (error) {
      if (!currentToken.isCompleted) {
        if (currentRetry < maxRetries) {
          // 延迟后重试
          await Future.delayed(retryDelay);
          if (!currentToken.isCompleted) {
            await _executeWithRetry(currentRetry + 1);
          }
        } else {
          // 达到最大重试次数
          state = AsyncNetworkState<T>(
            isLoading: false,
            error: error.toString(),
            lastUpdated: DateTime.now(),
            retryCount: currentRetry,
            maxRetries: maxRetries,
          );
        }
      }
    }
  }
  
  /// 手动重试
  Future<void> retry() async {
    if (state.canRetry) {
      await execute();
    }
  }
  
  /// 重置状态
  void reset() {
    _cancelToken?.complete();
    state = AsyncNetworkState<T>(maxRetries: maxRetries);
  }
  
  @override
  void dispose() {
    _cancelToken?.complete();
    super.dispose();
  }
}

/// 批量异步操作Provider
class BatchAsyncEffectNotifier<T> extends StateNotifier<AsyncEffectState<List<T>>> {
  BatchAsyncEffectNotifier(this._effects) : super(const AsyncEffectState());
  
  final List<Future<T> Function()> _effects;
  Completer<void>? _cancelToken;
  
  /// 并行执行所有异步操作
  Future<void> executeParallel() async {
    _cancelToken?.complete();
    _cancelToken = Completer<void>();
    
    final currentToken = _cancelToken!;
    
    state = state.loading();
    
    try {
      final futures = _effects.map((effect) => effect());
      final results = await Future.wait(futures);
      
      if (!currentToken.isCompleted) {
        state = state.success(results);
      }
    } catch (error) {
      if (!currentToken.isCompleted) {
        state = state.failure(error.toString());
      }
    }
  }
  
  /// 串行执行所有异步操作
  Future<void> executeSequential() async {
    _cancelToken?.complete();
    _cancelToken = Completer<void>();
    
    final currentToken = _cancelToken!;
    
    state = state.loading();
    
    try {
      final results = <T>[];
      
      for (final effect in _effects) {
        if (currentToken.isCompleted) break;
        
        final result = await effect();
        results.add(result);
      }
      
      if (!currentToken.isCompleted) {
        state = state.success(results);
      }
    } catch (error) {
      if (!currentToken.isCompleted) {
        state = state.failure(error.toString());
      }
    }
  }
  
  @override
  void dispose() {
    _cancelToken?.complete();
    super.dispose();
  }
}

/// 创建批量异步操作Provider
StateNotifierProvider<BatchAsyncEffectNotifier<T>, AsyncEffectState<List<T>>>
    createBatchAsyncEffectProvider<T>(
  List<Future<T> Function()> effects, {
  String? name,
}) {
  return StateNotifierProvider<BatchAsyncEffectNotifier<T>, AsyncEffectState<List<T>>>(
    (ref) => BatchAsyncEffectNotifier<T>(effects),
    name: name ?? 'BatchAsyncEffect<$T>',
  );
} 