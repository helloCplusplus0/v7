import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:v7_flutter_app/shared/network/api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:v7_flutter_app/shared/types/result.dart';
import 'dart:convert';

// Mock classes
class MockDio extends Mock implements Dio {}

class MockRequestOptions extends Mock implements RequestOptions {}

class MockResponse<T> extends Mock implements Response<T> {}

// Test data classes
class TestModel {
  final String id;
  final String name;

  TestModel({required this.id, required this.name});

  factory TestModel.fromJson(Map<String, dynamic> json) {
    return TestModel(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

/// API异常类（用于测试）
class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  factory ApiException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return const ApiException('连接超时，请检查网络');
      case DioExceptionType.sendTimeout:
        return const ApiException('请求超时，请稍后重试');
      case DioExceptionType.receiveTimeout:
        return const ApiException('响应超时，请稍后重试');
      case DioExceptionType.cancel:
        return const ApiException('请求已取消');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        return ApiException('服务器错误 ($statusCode)', statusCode);
      case DioExceptionType.connectionError:
        return const ApiException('网络错误，请检查网络连接');
      case DioExceptionType.unknown:
      default:
        return const ApiException('网络错误，请稍后重试');
    }
  }

  @override
  String toString() => message;
}

void main() {
  group('ApiClient Tests', () {
    late ApiClient apiClient;

    setUp(() {
      apiClient = ApiClient();
    });

    tearDown(() {
      apiClient.close();
    });

    group('Initialization Tests', () {
      test('should create ApiClient instance successfully', () {
        expect(apiClient, isNotNull);
        expect(apiClient, isA<ApiClient>());
        
        expect(apiClient.baseUrl, equals('http://localhost:8080/api'));
      });
    });

    group('Error Handling Tests', () {
      test('should handle connection timeout error', () {
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        );
        
        final apiException = ApiException.fromDioError(dioError);
        
        expect(apiException.message, equals('连接超时，请检查网络'));
      });

      test('should handle different timeout types', () {
        // 连接超时
        var dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        );
        var apiException = ApiException.fromDioError(dioError);
        expect(apiException.message, equals('连接超时，请检查网络'));

        // 发送超时
        dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.sendTimeout,
        );
        apiException = ApiException.fromDioError(dioError);
        expect(apiException.message, equals('请求超时，请稍后重试'));

        // 接收超时
        dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.receiveTimeout,
        );
        apiException = ApiException.fromDioError(dioError);
        expect(apiException.message, equals('响应超时，请稍后重试'));

        // 请求取消
        dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.cancel,
        );
        apiException = ApiException.fromDioError(dioError);
        expect(apiException.message, equals('请求已取消'));
      });

      test('should handle bad response error with status code', () {
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 404,
          ),
        );
        
        final apiException = ApiException.fromDioError(dioError);
        
        expect(apiException.message, contains('服务器错误'));
        expect(apiException.statusCode, equals(404));
      });

      test('should create ApiException with message and status code', () {
        const apiException = ApiException('Test error', 500);
        
        expect(apiException.message, equals('Test error'));
        expect(apiException.statusCode, equals(500));
      });

      test('should handle connection error', () {
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
        );
        
        final apiException = ApiException.fromDioError(dioError);
        
        expect(apiException.message, contains('网络错误'));
      });

      test('should handle unknown error', () {
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.unknown,
        );
        
        final apiException = ApiException.fromDioError(dioError);
        
        expect(apiException.message, contains('网络错误'));
      });
    });

    group('Base URL Tests', () {
      test('should have correct base URL', () {
        expect(apiClient.baseUrl, equals('http://localhost:8080/api'));
      });
    });

    group('ApiException Tests', () {
      test('should create exception with message only', () {
        const exception = ApiException('Test message');
        
        expect(exception.message, equals('Test message'));
        expect(exception.statusCode, isNull);
      });

      test('should create exception with message and status code', () {
        const exception = ApiException('Test message', 400);
        
        expect(exception.message, equals('Test message'));
        expect(exception.statusCode, equals(400));
      });

      test('should convert to string correctly', () {
        const exception = ApiException('Test message', 400);
        
        expect(exception.toString(), equals('Test message'));
      });
    });

    group('Configuration Tests', () {
      test('should support custom configuration', () {
        final customClient = ApiClient(
          config: const ApiClientConfig(
            baseUrl: 'https://api.example.com',
            timeout: Duration(seconds: 10),
            enableLogging: true,
          ),
        );
        
        expect(customClient.baseUrl, equals('https://api.example.com'));
        
        customClient.close();
      });

      test('should support backend name', () {
        final namedClient = ApiClient(backendName: 'test-backend');
        
        expect(namedClient.backendName, equals('test-backend'));
        
        namedClient.close();
      });
    });

    group('Factory Tests', () {
      test('should create clients via factory', () {
        final defaultClient = ApiClientFactory.getClient();
        final namedClient = ApiClientFactory.getClient('test');
        
        expect(defaultClient, isNotNull);
        expect(namedClient, isNotNull);
        expect(namedClient.backendName, equals('test'));
      });

      test('should create custom client via factory', () {
        final customClient = ApiClientFactory.createClient(
          baseUrl: 'https://custom.api.com',
          backendName: 'custom',
          timeout: const Duration(seconds: 15),
        );
        
        expect(customClient.baseUrl, equals('https://custom.api.com'));
        expect(customClient.backendName, equals('custom'));
        
        customClient.close();
      });
    });

    group('Health Check Tests', () {
      test('should have health check method', () {
        expect(apiClient.healthCheck, isA<Function>());
      });
    });

    group('Cleanup Tests', () {
      test('should cleanup all factory clients', () {
        // Create some test clients
        ApiClientFactory.getClient('test1');
        ApiClientFactory.getClient('test2');
        
        // Cleanup should not throw
        expect(() => ApiClientFactory.cleanup(), returnsNormally);
      });
    });
  });
}

// Mock classes for testing
class MockHttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  
  MockHttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });
}

class ApiRequest {
  final String method;
  final String url;
  final Map<String, String> headers;
  final dynamic body;
  
  ApiRequest({
    required this.method,
    required this.url,
    required this.headers,
    this.body,
  });
}

enum NetworkErrorType {
  timeout,
  connection,
  server,
  parsing,
}

class NetworkError {
  final NetworkErrorType type;
  final String message;
  final int? statusCode;
  
  NetworkError(this.type, this.message, [this.statusCode]);
  
  factory NetworkError.timeout() => NetworkError(
    NetworkErrorType.timeout,
    'Request timeout',
  );
  
  factory NetworkError.connection(String message) => NetworkError(
    NetworkErrorType.connection,
    message,
  );
  
  factory NetworkError.server(int statusCode, String message) => NetworkError(
    NetworkErrorType.server,
    message,
    statusCode,
  );
  
  factory NetworkError.parsing(String message) => NetworkError(
    NetworkErrorType.parsing,
    message,
  );
} 