import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/services/service_locator.dart';

// 测试用接口和实现
abstract class TestService {
  String getValue();
}

class TestServiceImpl implements TestService {
  final String value;
  
  TestServiceImpl(this.value);
  
  @override
  String getValue() => value;
}

class AsyncTestService {
  bool _initialized = false;
  
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 10));
    _initialized = true;
  }
  
  bool get isInitialized => _initialized;
}

class DisposableTestService {
  bool _disposed = false;
  
  void dispose() {
    _disposed = true;
  }
  
  bool get isDisposed => _disposed;
}

void main() {
  group('ServiceLocator Enhanced Tests', () {
    late ServiceLocator serviceLocator;
    
    setUp(() {
      serviceLocator = ServiceLocator.instance;
    });
    
    tearDown(() async {
      await serviceLocator.reset();
    });
    
    group('Registration Tests', () {
      test('should register and resolve singleton', () {
        final service = TestServiceImpl('test');
        serviceLocator.registerSingleton<TestService>(service);
        
        final resolved = serviceLocator.get<TestService>();
        
        expect(resolved, equals(service));
        expect(identical(resolved, service), isTrue);
      });
      
      test('should register and resolve factory', () {
        serviceLocator.registerFactory<TestService>(
          () => TestServiceImpl('factory'),
        );
        
        final resolved1 = serviceLocator.get<TestService>();
        final resolved2 = serviceLocator.get<TestService>();
        
        expect(resolved1.getValue(), equals('factory'));
        expect(resolved2.getValue(), equals('factory'));
        expect(identical(resolved1, resolved2), isFalse);
      });
      
      test('should register lazy singleton', () {
        var factoryCalled = false;
        
        serviceLocator.registerLazySingleton<TestService>(() {
          factoryCalled = true;
          return TestServiceImpl('lazy');
        });
        
        expect(factoryCalled, isFalse);
        
        final resolved1 = serviceLocator.get<TestService>();
        expect(factoryCalled, isTrue);
        expect(resolved1.getValue(), equals('lazy'));
        
        final resolved2 = serviceLocator.get<TestService>();
        expect(identical(resolved1, resolved2), isTrue);
      });
      
      test('should handle async registration', () async {
        serviceLocator.registerSingletonAsync<AsyncTestService>(() async {
          final service = AsyncTestService();
          await service.initialize();
          return service;
        });
        
        final resolved = await serviceLocator.getAsync<AsyncTestService>();
        expect(resolved.isInitialized, isTrue);
      });
      
      test('should check if service is registered', () {
        expect(serviceLocator.isRegistered<TestService>(), isFalse);
        
        serviceLocator.registerSingleton<TestService>(
          TestServiceImpl('test'),
        );
        
        expect(serviceLocator.isRegistered<TestService>(), isTrue);
      });
      
      test('should handle complex dependency chains', () {
        serviceLocator.registerFactory<String>(() => 'base_value');
        serviceLocator.registerFactory<TestService>(
          () => TestServiceImpl(serviceLocator.get<String>()),
        );
        
        final service = serviceLocator.get<TestService>();
        expect(service.getValue(), equals('base_value'));
      });
    });
    
    group('Resolution Tests', () {
      test('should throw when service not registered', () {
        expect(
          () => serviceLocator.get<TestService>(),
          throwsA(isA<StateError>()),
        );
      });
      
      test('should resolve with tryGet when registered', () {
        serviceLocator.registerSingleton<TestService>(
          TestServiceImpl('test'),
        );
        
        final result = serviceLocator.tryGet<TestService>();
        expect(result, isNotNull);
        expect(result!.getValue(), equals('test'));
      });
      
      test('should return null with tryGet when not registered', () {
        final result = serviceLocator.tryGet<TestService>();
        expect(result, isNull);
      });
    });
    
    group('Unregistration Tests', () {
      test('should unregister singleton', () {
        final service = TestServiceImpl('test');
        serviceLocator.registerSingleton<TestService>(service);
        
        expect(serviceLocator.isRegistered<TestService>(), isTrue);
        
        serviceLocator.unregister<TestService>();
        
        expect(serviceLocator.isRegistered<TestService>(), isFalse);
        expect(
          () => serviceLocator.get<TestService>(),
          throwsA(isA<StateError>()),
        );
      });
      
      test('should unregister factory', () {
        serviceLocator.registerFactory<TestService>(
          () => TestServiceImpl('factory'),
        );
        
        expect(serviceLocator.isRegistered<TestService>(), isTrue);
        
        serviceLocator.unregister<TestService>();
        
        expect(serviceLocator.isRegistered<TestService>(), isFalse);
      });
    });
    
    group('Async Services Tests', () {
      test('should register and resolve async factory', () async {
        serviceLocator.registerFactoryAsync<AsyncTestService>(() async {
          final service = AsyncTestService();
          await service.initialize();
          return service;
        });
        
        final resolved = await serviceLocator.getAsync<AsyncTestService>();
        expect(resolved.isInitialized, isTrue);
      });
      
      test('should wait for all async services', () async {
        serviceLocator.registerSingletonAsync<AsyncTestService>(() async {
          final service = AsyncTestService();
          await service.initialize();
          return service;
        });
        
        await serviceLocator.allReady();
        
        final resolved = serviceLocator.get<AsyncTestService>();
        expect(resolved.isInitialized, isTrue);
      });
      
      test('should check if async service is ready', () async {
        serviceLocator.registerSingletonAsync<AsyncTestService>(() async {
          final service = AsyncTestService();
          await service.initialize();
          return service;
        });
        
        expect(serviceLocator.isReady<AsyncTestService>(), isFalse);
        
        await serviceLocator.allReady();
        
        expect(serviceLocator.isReady<AsyncTestService>(), isTrue);
      });
    });
    
    group('Performance Tests', () {
      test('should resolve services efficiently', () {
        serviceLocator.registerFactory<TestService>(
          () => TestServiceImpl('performance'),
        );
        
        final stopwatch = Stopwatch()..start();
        
        // Resolve many times
        for (int i = 0; i < 1000; i++) {
          serviceLocator.get<TestService>();
        }
        
        stopwatch.stop();
        
        // Should complete in reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
      
      test('should handle singleton resolution efficiently', () {
        serviceLocator.registerLazySingleton<TestService>(
          () => TestServiceImpl('singleton_perf'),
        );
        
        final stopwatch = Stopwatch()..start();
        
        // First resolution (should create instance)
        final first = serviceLocator.get<TestService>();
        
        // Subsequent resolutions (should return cached instance)
        for (int i = 0; i < 1000; i++) {
          final service = serviceLocator.get<TestService>();
          expect(identical(service, first), isTrue);
        }
        
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(50));
      });
    });
    
    group('Error Handling Tests', () {
      test('should handle exception in factory', () {
        serviceLocator.registerFactory<TestService>(
          () => throw Exception('Factory error'),
        );
        
        expect(
          () => serviceLocator.get<TestService>(),
          throwsException,
        );
      });
      
      test('should handle concurrent access', () async {
        serviceLocator.registerLazySingleton<TestService>(
          () => TestServiceImpl('concurrent'),
        );
        
        // Simulate concurrent access
        final futures = List.generate(10, (index) async {
          return serviceLocator.get<TestService>();
        });
        
        final results = await Future.wait(futures);
        
        // All should be the same instance (singleton)
        final first = results.first;
        expect(results.every((service) => identical(service, first)), isTrue);
      });
    });
  });
} 