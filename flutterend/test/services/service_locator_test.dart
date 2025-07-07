import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/services/service_locator.dart';

// 测试用的服务接口和实现
abstract class TestService {
  String getName();
}

class TestServiceImpl implements TestService {
  final String name;
  
  TestServiceImpl(this.name);
  
  @override
  String getName() => name;
}

class AnotherTestService {
  final int value;
  
  AnotherTestService(this.value);
}

void main() {
  group('ServiceLocator Tests', () {
    late ServiceLocator serviceLocator;

    setUp(() {
      serviceLocator = ServiceLocator.instance;
      // 重置服务定位器状态
      serviceLocator.reset();
    });

    tearDown(() async {
      await serviceLocator.reset();
    });

    group('服务注册和获取', () {
      test('should register and get singleton service', () {
        // Arrange
        final service = TestServiceImpl('test');

        // Act
        serviceLocator.registerSingleton<TestService>(service);
        final retrieved = serviceLocator.get<TestService>();

        // Assert
        expect(retrieved, isA<TestService>());
        expect(retrieved.getName(), equals('test'));
        expect(identical(retrieved, service), isTrue);
      });

      test('should register and get factory service', () {
        // Arrange
        var instanceCount = 0;
        serviceLocator.registerFactory<TestService>(() {
          instanceCount++;
          return TestServiceImpl('factory_$instanceCount');
        });

        // Act
        final instance1 = serviceLocator.get<TestService>();
        final instance2 = serviceLocator.get<TestService>();

        // Assert
        expect(instance1.getName(), equals('factory_1'));
        expect(instance2.getName(), equals('factory_2'));
        expect(identical(instance1, instance2), isFalse);
      });

      test('should register and get lazy singleton', () {
        // Arrange
        var created = false;
        serviceLocator.registerLazySingleton<TestService>(() {
          created = true;
          return TestServiceImpl('lazy');
        });

        // Assert - not created yet
        expect(created, isFalse);

        // Act
        final instance1 = serviceLocator.get<TestService>();
        final instance2 = serviceLocator.get<TestService>();

        // Assert
        expect(created, isTrue);
        expect(instance1.getName(), equals('lazy'));
        expect(identical(instance1, instance2), isTrue);
      });

      test('should register with instance name', () {
        // Arrange
        final service1 = TestServiceImpl('service1');
        final service2 = TestServiceImpl('service2');

        // Act
        serviceLocator.registerSingleton<TestService>(service1, instanceName: 'first');
        serviceLocator.registerSingleton<TestService>(service2, instanceName: 'second');

        final retrieved1 = serviceLocator.get<TestService>(instanceName: 'first');
        final retrieved2 = serviceLocator.get<TestService>(instanceName: 'second');

        // Assert
        expect(retrieved1.getName(), equals('service1'));
        expect(retrieved2.getName(), equals('service2'));
      });
    });

    group('服务查询和检查', () {
      test('should check if service is registered', () {
        // Arrange
        final service = TestServiceImpl('test');

        // Act & Assert - before registration
        expect(serviceLocator.isRegistered<TestService>(), isFalse);

        // Register and check again
        serviceLocator.registerSingleton<TestService>(service);
        expect(serviceLocator.isRegistered<TestService>(), isTrue);
      });

      test('should check if async service is ready', () {
        // Arrange
        final service = TestServiceImpl('test');
        serviceLocator.registerSingleton<TestService>(service);

        // Act & Assert
        expect(serviceLocator.isReady<TestService>(), isTrue);
        expect(serviceLocator.isReady<AnotherTestService>(), isFalse);
      });

      test('should try to get optional service', () {
        // Arrange
        final service = TestServiceImpl('test');
        serviceLocator.registerSingleton<TestService>(service);

        // Act
        final existing = serviceLocator.tryGet<TestService>();
        final missing = serviceLocator.tryGet<AnotherTestService>();

        // Assert
        expect(existing, isNotNull);
        expect(existing!.getName(), equals('test'));
        expect(missing, isNull);
      });

      test('should get all registered service types', () {
        // Arrange
        serviceLocator.registerSingleton<TestService>(TestServiceImpl('test'));
        serviceLocator.registerSingleton<AnotherTestService>(AnotherTestService(42));

        // Act
        final types = serviceLocator.registeredTypes;

        // Assert
        expect(types, hasLength(2));
        expect(types, contains(TestService));
        expect(types, contains(AnotherTestService));
      });
    });

    group('服务生命周期管理', () {
      test('should unregister service', () async {
        // Arrange
        final service = TestServiceImpl('test');
        serviceLocator.registerSingleton<TestService>(service);
        expect(serviceLocator.isRegistered<TestService>(), isTrue);

        // Act
        await serviceLocator.unregister<TestService>();

        // Assert
        expect(serviceLocator.isRegistered<TestService>(), isFalse);
      });

      test('should reset all services', () async {
        // Arrange
        serviceLocator.registerSingleton<TestService>(TestServiceImpl('test'));
        serviceLocator.registerSingleton<AnotherTestService>(AnotherTestService(42));
        expect(serviceLocator.registeredTypes, hasLength(2));

        // Act
        await serviceLocator.reset();

        // Assert
        expect(serviceLocator.registeredTypes, isEmpty);
      });

      test('should wait for ready service', () async {
        // Arrange
        final service = TestServiceImpl('test');
        serviceLocator.registerSingleton<TestService>(service);

        // Act & Assert - Add timeout to prevent hanging
        await expectLater(
          serviceLocator.waitForReady<TestService>().timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw TimeoutException('Service should be ready immediately for registered singleton'),
          ),
          completes,
        );
      }, timeout: const Timeout(Duration(seconds: 5)));
    });

    group('服务配置和统计', () {
      test('should get service configuration', () {
        // Arrange
        final service = TestServiceImpl('test');
        serviceLocator.registerSingleton<TestService>(service);

        // Act
        final config = serviceLocator.getConfig<TestService>();

        // Assert
        expect(config, isNotNull);
        expect(config!.type, equals(TestService));
        expect(config.isSingleton, isTrue);
        expect(config.isAsync, isFalse);
      });

      test('should provide service statistics', () {
        // Arrange
        serviceLocator.registerSingleton<TestService>(TestServiceImpl('test'));
        serviceLocator.registerFactory<AnotherTestService>(() => AnotherTestService(42));

        // Act
        final stats = serviceLocator.stats;

        // Assert
        expect(stats.totalServices, equals(2));
        expect(stats.singletons, equals(1));
        expect(stats.factories, equals(1));
        expect(stats.asyncServices, equals(0));
      });
    });

    group('错误处理', () {
      test('should throw when getting unregistered service', () {
        // Act & Assert
        expect(
          () => serviceLocator.get<TestService>(),
          throwsA(isA<Error>()),
        );
      });

      test('should handle duplicate registration gracefully', () {
        // Arrange
        final service1 = TestServiceImpl('test1');
        final service2 = TestServiceImpl('test2');

        // Act - register twice
        serviceLocator.registerSingleton<TestService>(service1);
        
        // Assert - should handle gracefully or throw expected error
        expect(
          () => serviceLocator.registerSingleton<TestService>(service2),
          throwsA(isA<Error>()),
        );
      });
    });

    group('初始化和设置', () {
      test('should initialize service locator', () async {
        // Act
        await serviceLocator.initialize();

        // Assert
        expect(serviceLocator.isInitialized, isTrue);
      });

      test('should handle multiple initialization calls', () async {
        // Act
        await serviceLocator.initialize();
        await serviceLocator.initialize(); // Should not throw

        // Assert
        expect(serviceLocator.isInitialized, isTrue);
      });
    });

    group('命名实例支持', () {
      test('should support multiple named instances of same type', () {
        // Arrange
        final dev = TestServiceImpl('dev');
        final prod = TestServiceImpl('prod');

        // Act
        serviceLocator.registerSingleton<TestService>(dev, instanceName: 'dev');
        serviceLocator.registerSingleton<TestService>(prod, instanceName: 'prod');

        final devInstance = serviceLocator.get<TestService>(instanceName: 'dev');
        final prodInstance = serviceLocator.get<TestService>(instanceName: 'prod');

        // Assert
        expect(devInstance.getName(), equals('dev'));
        expect(prodInstance.getName(), equals('prod'));
        expect(identical(devInstance, prodInstance), isFalse);
      });

      test('should check registration with instance name', () {
        // Arrange
        final service = TestServiceImpl('named');
        serviceLocator.registerSingleton<TestService>(service, instanceName: 'named');

        // Act & Assert
        expect(serviceLocator.isRegistered<TestService>(), isFalse); // No default instance
        expect(serviceLocator.isRegistered<TestService>(instanceName: 'named'), isTrue);
      });
    });
  });

  group('ServiceLocator Singleton Instance', () {
    test('should always return same instance', () {
      // Act
      final instance1 = ServiceLocator.instance;
      final instance2 = ServiceLocator.instance;

      // Assert
      expect(identical(instance1, instance2), isTrue);
    });

    test('should maintain state across access', () {
      // Arrange
      final locator1 = ServiceLocator.instance;
      locator1.registerSingleton<TestService>(TestServiceImpl('persistent'));

      // Act
      final locator2 = ServiceLocator.instance;
      final service = locator2.get<TestService>();

      // Assert
      expect(service.getName(), equals('persistent'));
    });
  });
} 