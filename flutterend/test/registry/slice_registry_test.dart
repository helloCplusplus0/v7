import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/registry/slice_registry.dart';
import 'package:v7_flutter_app/shared/contracts/slice_summary_contract.dart';

// 测试用的摘要提供者
class TestSliceSummaryProvider implements SliceSummaryProvider {
  final String _sliceName;
  bool _disposed = false;
  
  TestSliceSummaryProvider(this._sliceName);
  
  @override
  Future<SliceSummaryContract> getSummaryData() async {
    if (_disposed) throw StateError('Provider has been disposed');
    
    return SliceSummaryContract(
      title: 'Test $_sliceName Summary',
      status: SliceStatus.healthy,
      metrics: [
        const SliceMetric(
          label: 'Count',
          value: 5,
          trend: 'stable',
          icon: '📊',
        ),
        const SliceMetric(
          label: 'Status',
          value: 'Active',
          trend: 'up',
          icon: '✅',
        ),
      ],
      description: 'Test summary for $_sliceName slice',
      lastUpdated: DateTime.now(),
      alertCount: 0,
    );
  }
  
  @override
  Future<void> refreshData() async {
    if (_disposed) throw StateError('Provider has been disposed');
    // Simulate refresh
  }

  @override
  Future<void> startBackgroundSync() async {
    if (_disposed) throw StateError('Provider has been disposed');
    // Test implementation
  }

  @override
  Future<void> stopBackgroundSync() async {
    if (_disposed) throw StateError('Provider has been disposed');
    // Test implementation
  }

  @override
  Future<void> triggerSync() async {
    if (_disposed) throw StateError('Provider has been disposed');
    // Test implementation
  }

  @override
  Stream<SliceSyncInfo>? get syncStatusStream => null;
  
  @override
  void dispose() {
    _disposed = true;
  }
  
  bool get isDisposed => _disposed;
}

void main() {
  group('SliceRegistry Tests', () {
    late SliceRegistry registry;
    
    setUp(() {
      registry = SliceRegistry();
      // 清空注册表以确保测试隔离
      registry.dispose();
    });
    
    tearDown(() {
      registry.dispose();
    });

    group('切片注册和基本操作', () {
      test('should register and retrieve slice registration', () {
        // Arrange
        final summaryProvider = TestSliceSummaryProvider('test');
        final registration = SliceRegistration(
          name: 'test_slice',
          displayName: 'Test Slice',
          routePath: '/test',
          description: 'A test slice',
          version: '1.0.0',
          summaryProvider: summaryProvider,
          iconColor: 0xFF2196F3,
          category: 'Test',
          author: 'Test Author',
        );

        // Act
        registry.register(registration);
        final retrieved = registry.getRegistration('test_slice');

        // Assert
        expect(retrieved, isNotNull);
        expect(retrieved!.name, equals('test_slice'));
        expect(retrieved.displayName, equals('Test Slice'));
        expect(retrieved.description, equals('A test slice'));
        expect(retrieved.version, equals('1.0.0'));
        expect(retrieved.category, equals('Test'));
        expect(retrieved.author, equals('Test Author'));
      });

      test('should unregister slice and dispose resources', () {
        // Arrange
        final summaryProvider = TestSliceSummaryProvider('test');
        final registration = SliceRegistration(
          name: 'test_slice',
          displayName: 'Test Slice',
          routePath: '/test',
          description: 'A test slice',
          version: '1.0.0',
          summaryProvider: summaryProvider,
        );
        
        registry.register(registration);
        expect(registry.hasSlice('test_slice'), isTrue);
        expect(summaryProvider.isDisposed, isFalse);

        // Act
        registry.unregister('test_slice');

        // Assert
        expect(registry.hasSlice('test_slice'), isFalse);
        expect(registry.getRegistration('test_slice'), isNull);
        expect(summaryProvider.isDisposed, isTrue);
      });

      test('should return null for non-existent slice', () {
        // Act & Assert
        expect(registry.getRegistration('non_existent'), isNull);
        expect(registry.hasSlice('non_existent'), isFalse);
      });
    });

    group('切片列表和查询', () {
      test('should get all slice names', () {
        // Arrange
        registry.register(_createTestRegistration('slice1', 'Slice 1'));
        registry.register(_createTestRegistration('slice2', 'Slice 2'));
        registry.register(_createTestRegistration('slice3', 'Slice 3'));

        // Act
        final names = registry.getSliceNames();

        // Assert
        expect(names, hasLength(3));
        expect(names, containsAll(['slice1', 'slice2', 'slice3']));
      });

      test('should get all registrations', () {
        // Arrange
        registry.register(_createTestRegistration('slice1', 'Slice 1'));
        registry.register(_createTestRegistration('slice2', 'Slice 2'));

        // Act
        final registrations = registry.getAllRegistrations();

        // Assert
        expect(registrations, hasLength(2));
        expect(registrations.map((r) => r.name), containsAll(['slice1', 'slice2']));
      });

      test('should return correct slice count', () {
        // Arrange
        expect(registry.sliceCount, equals(0));

        registry.register(_createTestRegistration('slice1', 'Slice 1'));
        expect(registry.sliceCount, equals(1));

        registry.register(_createTestRegistration('slice2', 'Slice 2'));
        expect(registry.sliceCount, equals(2));

        // Act & Assert
        registry.unregister('slice1');
        expect(registry.sliceCount, equals(1));
      });
    });

    group('按分类和搜索功能', () {
      test('should group slices by category', () {
        // Arrange
        registry.register(_createTestRegistration('slice1', 'Slice 1', category: 'Category A'));
        registry.register(_createTestRegistration('slice2', 'Slice 2', category: 'Category A'));
        registry.register(_createTestRegistration('slice3', 'Slice 3', category: 'Category B'));
        registry.register(_createTestRegistration('slice4', 'Slice 4')); // No category

        // Act
        final categorized = registry.getSlicesByCategory();

        // Assert
        expect(categorized, hasLength(3));
        expect(categorized['Category A'], hasLength(2));
        expect(categorized['Category B'], hasLength(1));
        expect(categorized['其他'], hasLength(1)); // Default category
      });

      test('should search slices by name', () {
        // Arrange
        registry.register(_createTestRegistration('user_management', 'User Management'));
        registry.register(_createTestRegistration('user_profile', 'User Profile'));
        registry.register(_createTestRegistration('task_manager', 'Task Manager'));

        // Act
        final results = registry.searchSlices('user');

        // Assert
        expect(results, hasLength(2));
        expect(results.map((r) => r.name), containsAll(['user_management', 'user_profile']));
      });

      test('should search slices by display name', () {
        // Arrange
        registry.register(_createTestRegistration('mgmt', 'User Management'));
        registry.register(_createTestRegistration('profile', 'User Profile'));
        registry.register(_createTestRegistration('tasks', 'Task Manager'));

        // Act
        final results = registry.searchSlices('User');

        // Assert
        expect(results, hasLength(2));
        expect(results.map((r) => r.displayName), containsAll(['User Management', 'User Profile']));
      });

      test('should search slices by description', () {
        // Arrange
        registry.register(_createTestRegistration('slice1', 'Slice 1', description: 'Manages user authentication'));
        registry.register(_createTestRegistration('slice2', 'Slice 2', description: 'Handles task management'));
        registry.register(_createTestRegistration('slice3', 'Slice 3', description: 'User profile settings'));

        // Act
        final results = registry.searchSlices('user');

        // Assert
        expect(results, hasLength(2));
        expect(results.map((r) => r.name), containsAll(['slice1', 'slice3']));
      });

      test('should return all slices for empty search', () {
        // Arrange
        registry.register(_createTestRegistration('slice1', 'Slice 1'));
        registry.register(_createTestRegistration('slice2', 'Slice 2'));

        // Act
        final results = registry.searchSlices('');

        // Assert
        expect(results, hasLength(2));
      });
    });

    group('摘要提供者操作', () {
      test('should get summary provider', () {
        // Arrange
        final summaryProvider = TestSliceSummaryProvider('test');
        registry.register(SliceRegistration(
          name: 'test_slice',
          displayName: 'Test Slice',
          routePath: '/test',
          summaryProvider: summaryProvider,
        ));

        // Act
        final retrieved = registry.getSummaryProvider('test_slice');

        // Assert
        expect(retrieved, isNotNull);
        expect(retrieved, equals(summaryProvider));
      });

      test('should return null for slice without summary provider', () {
        // Arrange
        registry.register(SliceRegistration(
          name: 'test_slice',
          displayName: 'Test Slice',
          routePath: '/test',
        ));

        // Act
        final provider = registry.getSummaryProvider('test_slice');

        // Assert
        expect(provider, isNull);
      });

      test('should get summary data', () async {
        // Arrange
        final summaryProvider = TestSliceSummaryProvider('test');
        registry.register(SliceRegistration(
          name: 'test_slice',
          displayName: 'Test Slice',
          routePath: '/test',
          summaryProvider: summaryProvider,
        ));

        // Act
        final summaryData = await registry.getSummaryData('test_slice');

        // Assert
        expect(summaryData, isNotNull);
        expect(summaryData!.title, equals('Test test Summary'));
        expect(summaryData.status, equals(SliceStatus.healthy));
        expect(summaryData.metrics, hasLength(2));
        expect(summaryData.metrics.first.label, equals('Count'));
        expect(summaryData.metrics.first.value, equals(5));
      });

      test('should return null for summary data of non-existent slice', () async {
        // Act
        final summaryData = await registry.getSummaryData('non_existent');

        // Assert
        expect(summaryData, isNull);
      });

      test('should refresh summary data', () async {
        // Arrange
        final summaryProvider = TestSliceSummaryProvider('test');
        registry.register(SliceRegistration(
          name: 'test_slice',
          displayName: 'Test Slice',
          routePath: '/test',
          summaryProvider: summaryProvider,
        ));

        // Act & Assert - Should not throw
        await expectLater(
          registry.refreshSummaryData('test_slice'),
          completes,
        );
      });

      test('should refresh all summary data', () async {
        // Arrange
        registry.register(SliceRegistration(
          name: 'slice1',
          displayName: 'Slice 1',
          routePath: '/slice1',
          summaryProvider: TestSliceSummaryProvider('test1'),
        ));
        registry.register(SliceRegistration(
          name: 'slice2',
          displayName: 'Slice 2',
          routePath: '/slice2',
          summaryProvider: TestSliceSummaryProvider('test2'),
        ));

        // Act & Assert - Should not throw
        await expectLater(
          registry.refreshAllSummaryData(),
          completes,
        );
      });
    });

    group('初始化和资源管理', () {
      test('should initialize with demo slice', () {
        // Act
        registry.initialize();

        // Assert
        expect(registry.sliceCount, equals(1));
        expect(registry.hasSlice('demo'), isTrue);
        
        final demoRegistration = registry.getRegistration('demo');
        expect(demoRegistration, isNotNull);
        expect(demoRegistration!.displayName, equals('任务管理'));
        expect(demoRegistration.category, equals('已实现'));
      });

      test('should initialize with dynamic scanning', () async {
        // Act
        await registry.initializeWithDynamicScanning();

        // Assert
        expect(registry.sliceCount, greaterThanOrEqualTo(1));
        expect(registry.hasSlice('demo'), isTrue);
      });

      test('should dispose all resources', () {
        // Arrange
        final provider1 = TestSliceSummaryProvider('test1');
        final provider2 = TestSliceSummaryProvider('test2');
        
        registry.register(SliceRegistration(
          name: 'slice1',
          displayName: 'Slice 1',
          routePath: '/slice1',
          summaryProvider: provider1,
        ));
        registry.register(SliceRegistration(
          name: 'slice2',
          displayName: 'Slice 2',
          routePath: '/slice2',
          summaryProvider: provider2,
        ));

        expect(provider1.isDisposed, isFalse);
        expect(provider2.isDisposed, isFalse);

        // Act
        registry.dispose();

        // Assert
        expect(registry.sliceCount, equals(0));
        expect(provider1.isDisposed, isTrue);
        expect(provider2.isDisposed, isTrue);
      });
    });

    group('单例模式', () {
      test('should always return same instance', () {
        // Act
        final instance1 = SliceRegistry();
        final instance2 = SliceRegistry();

        // Assert
        expect(identical(instance1, instance2), isTrue);
      });

      test('should maintain state across different access', () {
        // Arrange
        final registry1 = SliceRegistry();
        registry1.register(_createTestRegistration('persistent', 'Persistent Slice'));

        // Act
        final registry2 = SliceRegistry();
        final retrieved = registry2.getRegistration('persistent');

        // Assert
        expect(retrieved, isNotNull);
        expect(retrieved!.name, equals('persistent'));
      });
    });
  });
}

// 辅助函数：创建测试注册信息
SliceRegistration _createTestRegistration(
  String name, 
  String displayName, {
  String? description,
  String? category,
  String? author,
}) {
  return SliceRegistration(
    name: name,
    displayName: displayName,
    routePath: '/$name',
    description: description,
    version: '1.0.0',
    summaryProvider: TestSliceSummaryProvider(name),
    iconColor: Colors.blue.value,
    category: category,
    author: author,
  );
}
