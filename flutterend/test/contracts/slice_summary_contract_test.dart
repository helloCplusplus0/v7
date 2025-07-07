import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/contracts/slice_summary_contract.dart';

void main() {
  group('SliceSummaryContract Tests', () {
    group('SliceMetric Tests', () {
      test('should create metric with required fields', () {
        // Act
        const metric = SliceMetric(
          label: 'Users',
          value: 150,
        );

        // Assert
        expect(metric.label, equals('Users'));
        expect(metric.value, equals(150));
        expect(metric.trend, isNull);
        expect(metric.icon, isNull);
        expect(metric.unit, isNull);
      });

      test('should create metric with all fields', () {
        // Act
        const metric = SliceMetric(
          label: 'CPU Usage',
          value: 75.5,
          trend: 'up',
          icon: '📈',
          unit: '%',
        );

        // Assert
        expect(metric.label, equals('CPU Usage'));
        expect(metric.value, equals(75.5));
        expect(metric.trend, equals('up'));
        expect(metric.icon, equals('📈'));
        expect(metric.unit, equals('%'));
      });

      test('should support equality comparison', () {
        // Arrange
        const metric1 = SliceMetric(
          label: 'Users',
          value: 150,
          trend: 'stable',
          icon: '👥',
        );
        const metric2 = SliceMetric(
          label: 'Users',
          value: 150,
          trend: 'stable',
          icon: '👥',
        );
        const metric3 = SliceMetric(
          label: 'Users',
          value: 200,
          trend: 'stable',
          icon: '👥',
        );

        // Assert
        expect(metric1, equals(metric2));
        expect(metric1, isNot(equals(metric3)));
      });

      test('should have consistent hashCode', () {
        // Arrange
        const metric1 = SliceMetric(
          label: 'Users',
          value: 150,
          trend: 'stable',
        );
        const metric2 = SliceMetric(
          label: 'Users',
          value: 150,
          trend: 'stable',
        );

        // Assert
        expect(metric1.hashCode, equals(metric2.hashCode));
      });

      test('should have proper toString representation', () {
        // Arrange
        const metric = SliceMetric(
          label: 'Tasks',
          value: 42,
          trend: 'up',
          icon: '📋',
          unit: 'items',
        );

        // Act
        final result = metric.toString();

        // Assert
        expect(result, contains('Tasks'));
        expect(result, contains('42'));
        expect(result, contains('up'));
        expect(result, contains('📋'));
        expect(result, contains('items'));
      });
    });

    group('SliceAction Tests', () {
      test('should create action with required fields', () {
        // Arrange
        var callbackCalled = false;
        void testCallback() {
          callbackCalled = true;
        }

        // Act
        final action = SliceAction(
          label: 'Refresh',
          onPressed: testCallback,
        );

        // Assert
        expect(action.label, equals('Refresh'));
        expect(action.icon, isNull);
        expect(action.variant, equals(SliceActionVariant.secondary));
        
        // Test callback
        action.onPressed();
        expect(callbackCalled, isTrue);
      });

      test('should create action with all fields', () {
        // Arrange
        var callbackCalled = false;
        void testCallback() {
          callbackCalled = true;
        }

        // Act
        final action = SliceAction(
          label: 'Delete',
          onPressed: testCallback,
          icon: '🗑️',
          variant: SliceActionVariant.danger,
        );

        // Assert
        expect(action.label, equals('Delete'));
        expect(action.icon, equals('🗑️'));
        expect(action.variant, equals(SliceActionVariant.danger));
        
        // Test callback
        action.onPressed();
        expect(callbackCalled, isTrue);
      });

      test('should support equality comparison', () {
        // Arrange
        void callback1() {}
        void callback2() {}

        final action1 = SliceAction(
          label: 'Save',
          onPressed: callback1,
          icon: '💾',
          variant: SliceActionVariant.primary,
        );
        final action2 = SliceAction(
          label: 'Save',
          onPressed: callback2, // Different callback, but should still be equal
          icon: '💾',
          variant: SliceActionVariant.primary,
        );
        final action3 = SliceAction(
          label: 'Cancel',
          onPressed: callback1,
          icon: '💾',
          variant: SliceActionVariant.primary,
        );

        // Assert
        expect(action1, equals(action2)); // Callbacks not compared
        expect(action1, isNot(equals(action3))); // Different label
      });

      test('should have proper toString representation', () {
        // Arrange
        final action = SliceAction(
          label: 'Export',
          onPressed: () {},
          icon: '📤',
          variant: SliceActionVariant.primary,
        );

        // Act
        final result = action.toString();

        // Assert
        expect(result, contains('Export'));
        expect(result, contains('📤'));
        expect(result, contains('primary'));
      });
    });

    group('SliceSummaryContract Tests', () {
      test('should create contract with required fields', () {
        // Act
        const contract = SliceSummaryContract(
          title: 'Test Slice',
          status: SliceStatus.healthy,
          metrics: [],
        );

        // Assert
        expect(contract.title, equals('Test Slice'));
        expect(contract.status, equals(SliceStatus.healthy));
        expect(contract.metrics, isEmpty);
        expect(contract.description, isNull);
        expect(contract.lastUpdated, isNull);
        expect(contract.alertCount, equals(0));
        expect(contract.customActions, isEmpty);
      });

      test('should create contract with all fields', () {
        // Arrange
        final metrics = [
          const SliceMetric(label: 'Users', value: 100),
          const SliceMetric(label: 'Tasks', value: 50),
        ];
        final actions = [
          SliceAction(label: 'Refresh', onPressed: () {}),
        ];
        final lastUpdated = DateTime.now();

        // Act
        final contract = SliceSummaryContract(
          title: 'Task Manager',
          status: SliceStatus.warning,
          metrics: metrics,
          description: 'Manages tasks efficiently',
          lastUpdated: lastUpdated,
          alertCount: 3,
          customActions: actions,
        );

        // Assert
        expect(contract.title, equals('Task Manager'));
        expect(contract.status, equals(SliceStatus.warning));
        expect(contract.metrics, equals(metrics));
        expect(contract.description, equals('Manages tasks efficiently'));
        expect(contract.lastUpdated, equals(lastUpdated));
        expect(contract.alertCount, equals(3));
        expect(contract.customActions, equals(actions));
      });

      test('should copy with updated fields', () {
        // Arrange
        const original = SliceSummaryContract(
          title: 'Original Title',
          status: SliceStatus.healthy,
          metrics: [],
          alertCount: 0,
        );

        // Act
        final updated = original.copyWith(
          title: 'Updated Title',
          status: SliceStatus.error,
          alertCount: 5,
        );

        // Assert
        expect(updated.title, equals('Updated Title'));
        expect(updated.status, equals(SliceStatus.error));
        expect(updated.alertCount, equals(5));
        expect(updated.metrics, isEmpty); // Unchanged
      });

      test('should support equality comparison', () {
        // Arrange
        final metrics = [
          const SliceMetric(label: 'Users', value: 100),
        ];
        final actions = [
          SliceAction(label: 'Test', onPressed: () {}),
        ];
        final lastUpdated = DateTime(2024, 1, 1);

        final contract1 = SliceSummaryContract(
          title: 'Test',
          status: SliceStatus.healthy,
          metrics: metrics,
          description: 'Test description',
          lastUpdated: lastUpdated,
          alertCount: 1,
          customActions: actions,
        );
        final contract2 = SliceSummaryContract(
          title: 'Test',
          status: SliceStatus.healthy,
          metrics: metrics,
          description: 'Test description',
          lastUpdated: lastUpdated,
          alertCount: 1,
          customActions: actions,
        );
        final contract3 = SliceSummaryContract(
          title: 'Different',
          status: SliceStatus.healthy,
          metrics: metrics,
          description: 'Test description',
          lastUpdated: lastUpdated,
          alertCount: 1,
          customActions: actions,
        );

        // Assert
        expect(contract1, equals(contract2));
        expect(contract1, isNot(equals(contract3)));
      });

      test('should have proper toString representation', () {
        // Arrange
        const contract = SliceSummaryContract(
          title: 'Test Slice',
          status: SliceStatus.warning,
          metrics: [],
          description: 'Test description',
          alertCount: 2,
        );

        // Act
        final result = contract.toString();

        // Assert
        expect(result, contains('Test Slice'));
        expect(result, contains('warning'));
        expect(result, contains('Test description'));
        expect(result, contains('2'));
      });
    });

    group('SliceRegistration Tests', () {
      test('should create registration with required fields', () {
        // Act
        const registration = SliceRegistration(
          name: 'test_slice',
          displayName: 'Test Slice',
          routePath: '/test',
        );

        // Assert
        expect(registration.name, equals('test_slice'));
        expect(registration.displayName, equals('Test Slice'));
        expect(registration.routePath, equals('/test'));
        expect(registration.description, isNull);
        expect(registration.version, isNull);
        expect(registration.summaryProvider, isNull);
        expect(registration.iconColor, isNull);
        expect(registration.category, isNull);
        expect(registration.author, isNull);
      });

      test('should create registration with all fields', () {
        // Arrange
        final summaryProvider = TestSummaryProvider();

        // Act
        final registration = SliceRegistration(
          name: 'user_management',
          displayName: 'User Management',
          routePath: '/users',
          description: 'Manages user accounts',
          version: '2.1.0',
          summaryProvider: summaryProvider,
          iconColor: 0xFF2196F3,
          category: 'Administration',
          author: 'Development Team',
        );

        // Assert
        expect(registration.name, equals('user_management'));
        expect(registration.displayName, equals('User Management'));
        expect(registration.routePath, equals('/users'));
        expect(registration.description, equals('Manages user accounts'));
        expect(registration.version, equals('2.1.0'));
        expect(registration.summaryProvider, equals(summaryProvider));
        expect(registration.iconColor, equals(0xFF2196F3));
        expect(registration.category, equals('Administration'));
        expect(registration.author, equals('Development Team'));
      });

      test('should support equality comparison', () {
        // Arrange
        const registration1 = SliceRegistration(
          name: 'slice1',
          displayName: 'Slice 1',
          routePath: '/slice1',
          version: '1.0.0',
        );
        const registration2 = SliceRegistration(
          name: 'slice1',
          displayName: 'Slice 1',
          routePath: '/slice1',
          version: '1.0.0',
        );
        const registration3 = SliceRegistration(
          name: 'slice2',
          displayName: 'Slice 1',
          routePath: '/slice1',
          version: '1.0.0',
        );

        // Assert
        expect(registration1, equals(registration2));
        expect(registration1, isNot(equals(registration3)));
      });

      test('should have proper toString representation', () {
        // Arrange
        const registration = SliceRegistration(
          name: 'analytics',
          displayName: 'Analytics Dashboard',
          routePath: '/analytics',
          version: '1.2.3',
          category: 'Reporting',
        );

        // Act
        final result = registration.toString();

        // Assert
        expect(result, contains('analytics'));
        expect(result, contains('Analytics Dashboard'));
        expect(result, contains('/analytics'));
        expect(result, contains('1.2.3'));
        expect(result, contains('Reporting'));
      });
    });

    group('Enum Tests', () {
      test('should have all SliceStatus values', () {
        // Assert
        expect(SliceStatus.values, hasLength(4));
        expect(SliceStatus.values, contains(SliceStatus.healthy));
        expect(SliceStatus.values, contains(SliceStatus.warning));
        expect(SliceStatus.values, contains(SliceStatus.error));
        expect(SliceStatus.values, contains(SliceStatus.loading));
      });

      test('should have all SliceActionVariant values', () {
        // Assert
        expect(SliceActionVariant.values, hasLength(3));
        expect(SliceActionVariant.values, contains(SliceActionVariant.primary));
        expect(SliceActionVariant.values, contains(SliceActionVariant.secondary));
        expect(SliceActionVariant.values, contains(SliceActionVariant.danger));
      });
    });

    group('SliceSummaryProvider Interface Tests', () {
      test('should implement interface correctly', () {
        // Arrange
        final provider = TestSummaryProvider();

        // Assert
        expect(provider, isA<SliceSummaryProvider>());
        expect(provider.getSummaryData, isA<Function>());
        expect(provider.refreshData, isA<Function>());
        expect(provider.dispose, isA<Function>());
      });

      test('should call getSummaryData', () async {
        // Arrange
        final provider = TestSummaryProvider();

        // Act
        final result = await provider.getSummaryData();

        // Assert
        expect(result, isA<SliceSummaryContract>());
        expect(result.title, equals('Test Summary'));
      });

      test('should call refreshData', () async {
        // Arrange
        final provider = TestSummaryProvider();

        // Act & Assert - Should not throw
        await expectLater(
          provider.refreshData(),
          completes,
        );
      });

      test('should call dispose', () {
        // Arrange
        final provider = TestSummaryProvider();

        // Act & Assert - Should not throw
        expect(() => provider.dispose(), returnsNormally);
      });
    });
  });
}

// Test implementation of SliceSummaryProvider
class TestSummaryProvider implements SliceSummaryProvider {
  @override
  Future<SliceSummaryContract> getSummaryData() async {
    return const SliceSummaryContract(
      title: 'Test Summary',
      status: SliceStatus.healthy,
      metrics: [
        SliceMetric(label: 'Test', value: 123),
      ],
    );
  }

  @override
  Future<void> refreshData() async {
    // Test implementation
  }

  @override
  Future<void> startBackgroundSync() async {
    // Test implementation
  }

  @override
  Future<void> stopBackgroundSync() async {
    // Test implementation
  }

  @override
  Future<void> triggerSync() async {
    // Test implementation
  }

  @override
  Stream<SliceSyncInfo>? get syncStatusStream => null;

  @override
  void dispose() {
    // Test implementation
  }
}
