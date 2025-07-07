import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/events/event_bus.dart';
import 'package:v7_flutter_app/shared/events/events.dart';
import 'dart:async';

void main() {
  group('EventBus Tests', () {
    late EventBus eventBus;
    
    setUp(() {
      eventBus = EventBus.instance;
      // 清理之前的订阅
      eventBus.clear();
    });
    
    tearDown(() {
      // 测试后清理
      eventBus.clear();
    });
    
    test('should emit and receive events', () async {
      UserLoginEvent? receivedEvent;
      
      final unsubscribe = eventBus.on<UserLoginEvent>((event) {
        receivedEvent = event;
      });
      
      const testEvent = UserLoginEvent(
        userId: '123',
        userName: 'test_user',
        loginMethod: 'email',
      );
      
      eventBus.emit(testEvent);
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(receivedEvent, isNotNull);
      expect(receivedEvent, isA<UserLoginEvent>());
      expect(receivedEvent!.userId, equals('123'));
      
      unsubscribe();
    });
    
    test('should handle multiple subscribers', () async {
      final receivedEvents = <UserEvent>[];
      
      final unsubscribe1 = eventBus.on<UserEvent>((event) {
        receivedEvents.add(event);
      });
      
      final unsubscribe2 = eventBus.on<UserEvent>((event) {
        receivedEvents.add(event);
      });
      
      const testEvent = UserLogoutEvent(
        userId: '123',
        reason: 'test_logout',
      );
      eventBus.emit(testEvent);
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(receivedEvents, hasLength(2));
      expect(receivedEvents.every((e) => e is UserLogoutEvent), isTrue);
      
      unsubscribe1();
      unsubscribe2();
    });
    
    test('should not receive events after unsubscription', () async {
      UserEvent? receivedEvent;
      
      final unsubscribe = eventBus.on<UserEvent>((event) {
        receivedEvent = event;
      });
      
      unsubscribe();
      
      const testEvent = UserLoginEvent(
        userId: '123',
        userName: 'test_user',
      );
      
      eventBus.emit(testEvent);
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(receivedEvent, isNull);
    });
    
    test('should handle event types properly', () async {
      UserEvent? userEvent;
      AppLifecycleEvent? lifecycleEvent;
      
      final userUnsubscribe = eventBus.on<UserEvent>((event) {
        userEvent = event;
      });
      
      final lifecycleUnsubscribe = eventBus.on<AppLifecycleEvent>((event) {
        lifecycleEvent = event;
      });
      
      // Emit user event
      const userTestEvent = UserLoginEvent(
        userId: '123',
        userName: 'test_user',
      );
      eventBus.emit(userTestEvent);
      
      // Emit lifecycle event
      const lifecycleTestEvent = AppStartedEvent(coldStart: true);
      eventBus.emit(lifecycleTestEvent);
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(userEvent, isNotNull);
      expect(userEvent, isA<UserLoginEvent>());
      expect(lifecycleEvent, isNotNull);
      expect(lifecycleEvent, isA<AppStartedEvent>());
      
      userUnsubscribe();
      lifecycleUnsubscribe();
    });
    
    test('should handle once subscription', () async {
      var callCount = 0;
      
      final unsubscribe = eventBus.once<UserEvent>((event) {
        callCount++;
      });
      
      const testEvent = UserLoginEvent(
        userId: '123',
        userName: 'test_user',
      );
      
      // Emit multiple times
      eventBus.emit(testEvent);
      eventBus.emit(testEvent);
      eventBus.emit(testEvent);
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(callCount, equals(1));
      
      unsubscribe(); // Should not throw
    });
    
    test('should wait for specific event', () async {
      // Start waiting for event
      final eventFuture = eventBus.waitFor<UserLogoutEvent>(
        timeout: const Duration(seconds: 1),
      );
      
      // Emit the event after a delay
      Timer(const Duration(milliseconds: 100), () {
        eventBus.emit(const UserLogoutEvent(
          userId: '123',
          reason: 'test_wait',
        ));
      });
      
      final receivedEvent = await eventFuture;
      
      expect(receivedEvent, isA<UserLogoutEvent>());
      expect(receivedEvent.userId, equals('123'));
    });
    
    test('should handle waitFor timeout', () async {
      expect(
        () => eventBus.waitFor<UserEvent>(
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
    
    test('should handle conditional subscription', () async {
      var callCount = 0;
      
      final unsubscribe = eventBus.onWhen<UserLoginEvent>(
        (event) => event.loginMethod == 'oauth',
        (event) => callCount++,
      );
      
      // This should not trigger the handler
      eventBus.emit(const UserLoginEvent(
        userId: '123',
        userName: 'test_user',
        loginMethod: 'email',
      ));
      
      // This should trigger the handler
      eventBus.emit(const UserLoginEvent(
        userId: '456',
        userName: 'oauth_user',
        loginMethod: 'oauth',
      ));
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(callCount, equals(1));
      
      unsubscribe();
    });
    
    test('should handle multiple event types with different subscriptions', () async {
      final receivedEvents = <AppEvent>[];
      
      final userUnsubscribe = eventBus.on<UserEvent>((event) {
        receivedEvents.add(event);
      });
      
      final syncUnsubscribe = eventBus.on<DataSyncEvent>((event) {
        receivedEvents.add(event);
      });
      
      const userEvent = UserLoginEvent(userId: '123', userName: 'test');
      const syncEvent = DataSyncStartedEvent(syncType: 'manual');
      
      eventBus.emit(userEvent);
      eventBus.emit(syncEvent);
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(receivedEvents, hasLength(2));
      expect(receivedEvents[0], isA<UserLoginEvent>());
      expect(receivedEvents[1], isA<DataSyncStartedEvent>());
      
      userUnsubscribe();
      syncUnsubscribe();
    });
  });
} 