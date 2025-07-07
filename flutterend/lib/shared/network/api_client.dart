// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// API客户端配置
class ApiClientConfig {
  const ApiClientConfig({
    required this.baseUrl,
    required this.timeout,
    this.enableLogging = false,
  });

  final String baseUrl;
  final Duration timeout;
  final bool enableLogging;

  /// 默认配置
  static const ApiClientConfig defaultConfig = ApiClientConfig(
    baseUrl: 'http://localhost:8080/api',
    timeout: Duration(seconds: 30),
    enableLogging: kDebugMode,
  );

  /// 从环境变量创建配置
  factory ApiClientConfig.fromEnvironment({
    String? baseUrl,
    Duration? timeout,
    bool? enableLogging,
  }) {
    return ApiClientConfig(
      baseUrl: baseUrl ?? 
               const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080/api'),
      timeout: timeout ?? const Duration(seconds: 30),
      enableLogging: enableLogging ?? kDebugMode,
    );
  }
}

/// HTTP API客户端
class ApiClient {
  ApiClient({
    String? backendName,
    ApiClientConfig? config,
  }) : _backendName = backendName,
       _config = config ?? ApiClientConfig.defaultConfig {
    _setupDio();
  }

  final String? _backendName;
  final ApiClientConfig _config;
  late final Dio _dio;

  void _setupDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: _config.timeout,
      receiveTimeout: _config.timeout,
      sendTimeout: _config.timeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    if (_config.enableLogging) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: false,
        error: true,
        logPrint: (obj) => debugPrint('[$_backendName] $obj'),
      ));
    }

    // 添加错误拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        if (_config.enableLogging) {
          debugPrint('[$_backendName] API错误: ${error.message}');
        }
        handler.next(error);
      },
    ));
  }

  /// GET请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PUT请求
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// DELETE请求
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 健康检查
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      if (_config.enableLogging) {
        debugPrint('[$_backendName] 健康检查失败: $e');
      }
      return false;
    }
  }

  /// 处理Dio错误
  Exception _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return SocketException('请求超时');
      case DioExceptionType.connectionError:
        return const SocketException('网络连接失败');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final message = error.response?.data?.toString() ?? '服务器错误';
        return HttpException('HTTP错误 $statusCode: $message');
      case DioExceptionType.cancel:
        return const SocketException('请求已取消');
      case DioExceptionType.unknown:
      default:
        return Exception('未知错误: ${error.message}');
    }
  }

  /// 获取基础URL
  String get baseUrl => _config.baseUrl;

  /// 获取后端名称
  String? get backendName => _backendName;

  /// 关闭客户端
  void close() {
    _dio.close();
  }
}

/// API客户端工厂
class ApiClientFactory {
  static final Map<String, ApiClient> _clients = {};

  /// 获取客户端实例
  static ApiClient getClient([String? backendName]) {
    final key = backendName ?? 'default';
    
    if (!_clients.containsKey(key)) {
      _clients[key] = ApiClient(
        backendName: backendName,
        config: ApiClientConfig.fromEnvironment(),
      );
    }
    
    return _clients[key]!;
  }

  /// 创建自定义客户端
  static ApiClient createClient({
    String? backendName,
    required String baseUrl,
    Duration? timeout,
    bool? enableLogging,
  }) {
    final config = ApiClientConfig(
      baseUrl: baseUrl,
      timeout: timeout ?? const Duration(seconds: 30),
      enableLogging: enableLogging ?? kDebugMode,
    );
    
    return ApiClient(
      backendName: backendName,
      config: config,
    );
  }

  /// 检查所有客户端的健康状态
  static Future<Map<String, bool>> checkAllHealthStatus() async {
    final results = <String, bool>{};
    
    for (final entry in _clients.entries) {
      results[entry.key] = await entry.value.healthCheck();
    }
    
    return results;
  }

  /// 清理所有客户端
  static void cleanup() {
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
  }
} 