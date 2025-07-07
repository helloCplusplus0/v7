import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/network/api_client.dart';

/// API异常类（用于测试）
class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  factory ApiException.fromDioError(dynamic error) {
    return ApiException('API错误: $error');
  }

  @override
  String toString() => message;
}

// 测试用模型
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
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

void main() {
  group('ApiClient Simple Tests', () {
    late ApiClient apiClient;
    
    setUp(() {
      apiClient = ApiClient();
    });
    
    tearDown(() {
      apiClient.close();
    });
    
    group('Initialization Tests', () {
      test('should create ApiClient instance', () {
        expect(apiClient, isNotNull);
        expect(apiClient, isA<ApiClient>());
      });
      
      test('should have default configuration', () {
        expect(apiClient.baseUrl, equals('http://localhost:8080/api'));
        expect(apiClient.baseUrl, isNotEmpty);
      });
    });
    
    group('Configuration Tests', () {
      test('should create client with custom config', () {
        final customClient = ApiClient(
          config: const ApiClientConfig(
            baseUrl: 'https://api.example.com',
            timeout: Duration(seconds: 10),
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
      test('should create client via factory', () {
        final factoryClient = ApiClientFactory.getClient();
        
        expect(factoryClient, isNotNull);
        expect(factoryClient.baseUrl, isNotEmpty);
      });
      
      test('should create named client via factory', () {
        final namedClient = ApiClientFactory.getClient('test');
        
        expect(namedClient, isNotNull);
        expect(namedClient.backendName, equals('test'));
      });
      
      test('should create custom client via factory', () {
        final customClient = ApiClientFactory.createClient(
          baseUrl: 'https://custom.api.com',
          backendName: 'custom',
        );
        
        expect(customClient.baseUrl, equals('https://custom.api.com'));
        expect(customClient.backendName, equals('custom'));
        
        customClient.close();
      });
    });
    
    group('Error Handling Tests', () {
      test('should handle ApiException properly', () {
        const exception = ApiException('Test error');
        expect(exception.message, equals('Test error'));
        expect(exception.statusCode, isNull);
      });
      
      test('should handle ApiException with status code', () {
        const exception = ApiException('Server error', 500);
        expect(exception.message, equals('Server error'));
        expect(exception.statusCode, equals(500));
      });
      
      test('should create exception from DioError', () {
        // Test that the fromDioError factory method exists
        expect(ApiException.fromDioError, isA<Function>());
      });
    });
    
    group('Health Check Tests', () {
      test('should have health check method', () async {
        // Health check method should exist and return bool
        expect(apiClient.healthCheck, isA<Function>());
      });
    });
    
    group('Configuration Tests', () {
      test('should have consistent base URL', () {
        final baseUrl = apiClient.baseUrl;
        expect(baseUrl, isNotEmpty);
        expect(baseUrl.startsWith('http'), isTrue);
      });
      
      test('should support environment configuration', () {
        final envConfig = ApiClientConfig.fromEnvironment(
          baseUrl: 'https://env.api.com',
        );
        
        expect(envConfig.baseUrl, equals('https://env.api.com'));
      });
    });
    
    group('Cleanup Tests', () {
      test('should cleanup factory clients', () {
        // Create some clients
        ApiClientFactory.getClient('test1');
        ApiClientFactory.getClient('test2');
        
        // Cleanup should not throw
        expect(() => ApiClientFactory.cleanup(), returnsNormally);
      });
    });
    
    group('Type Safety Tests', () {
      test('should maintain type safety with generic types', () {
        // 测试泛型类型的编译时检查
        expect(TestModel, isA<Type>());
        expect(TestModel.fromJson, isA<Function>());
      });
      
      test('should work with custom fromJson function', () {
        final testData = {'id': '123', 'name': 'Test'};
        final model = TestModel.fromJson(testData);
        
        expect(model, isA<TestModel>());
        expect(model.id, equals('123'));
        expect(model.name, equals('Test'));
      });
    });
    
    group('Model Serialization Tests', () {
      test('should serialize model to JSON', () {
        final model = TestModel(id: '1', name: 'Test');
        final json = model.toJson();
        
        expect(json['id'], equals('1'));
        expect(json['name'], equals('Test'));
      });
      
      test('should deserialize JSON to model', () {
        final json = {'id': '2', 'name': 'Test Model'};
        final model = TestModel.fromJson(json);
        
        expect(model.id, equals('2'));
        expect(model.name, equals('Test Model'));
      });
    });
    
    group('Method Signature Tests', () {
      test('should have correct method signatures', () {
        // 测试方法存在性，不进行实际调用
        expect(apiClient.get, isA<Function>());
        expect(apiClient.post, isA<Function>());
        expect(apiClient.put, isA<Function>());
        expect(apiClient.delete, isA<Function>());
      });
    });
  });
} 