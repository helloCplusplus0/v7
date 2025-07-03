import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 基础API客户端
/// 为所有功能切片提供统一的网络访问接口
class ApiClient {
  late final Dio _dio;
  static const String baseUrl = 'http://localhost:8080/api';

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ));

    _setupInterceptors();
  }

  void _setupInterceptors() {
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }

    // 错误处理拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        debugPrint('API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  /// GET请求
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? fromJson,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      
      if (fromJson != null) {
        return fromJson(response.data);
      }
      
      return response.data as T;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// POST请求
  Future<T> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic data)? fromJson,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      
      if (fromJson != null) {
        return fromJson(response.data);
      }
      
      return response.data as T;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT请求
  Future<T> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic data)? fromJson,
  }) async {
    try {
      final response = await _dio.put(path, data: data);
      
      if (fromJson != null) {
        return fromJson(response.data);
      }
      
      return response.data as T;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE请求
  Future<void> delete(String path) async {
    try {
      await _dio.delete(path);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 错误处理
  Exception _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return Exception('网络连接超时');
        case DioExceptionType.connectionError:
          return Exception('网络连接失败');
        case DioExceptionType.badResponse:
          return Exception('服务器错误: ${error.response?.statusCode}');
        default:
          return Exception('网络请求失败');
      }
    }
    return Exception('未知错误: $error');
  }
}

/// API异常类
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  factory ApiException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return const ApiException('连接超时，请检查网络');
      case DioExceptionType.sendTimeout:
        return const ApiException('请求超时，请稍后重试');
      case DioExceptionType.receiveTimeout:
        return const ApiException('响应超时，请稍后重试');
      case DioExceptionType.badResponse:
        return ApiException(
          '服务器错误: ${error.response?.statusMessage}',
          error.response?.statusCode,
        );
      case DioExceptionType.cancel:
        return const ApiException('请求已取消');
      default:
        return ApiException('网络错误: ${error.message}');
    }
  }

  @override
  String toString() => message;
} 