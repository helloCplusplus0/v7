import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/utils/debounce.dart';
import 'dart:async';

void main() {
  group('Debouncer Tests', () {
    test('should debounce function calls', () async {
      var callCount = 0;
      var lastValue = '';
      
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      
      void testFunction(String value) {
        callCount++;
        lastValue = value;
      }
      
      // Rapid calls
      debouncer.call(() => testFunction('first'));
      debouncer.call(() => testFunction('second'));
      debouncer.call(() => testFunction('third'));
      
      // Should not have executed yet
      expect(callCount, equals(0));
      expect(debouncer.isPending, isTrue);
      expect(debouncer.callCount, equals(3));
      
      // Wait for debounce to trigger
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Should have executed only once with the last value
      expect(callCount, equals(1));
      expect(lastValue, equals('third'));
      expect(debouncer.isPending, isFalse);
      expect(debouncer.callCount, equals(0));
      
      debouncer.dispose();
    });
    
    test('should cancel previous timer on new call', () async {
      var callCount = 0;
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      
      debouncer.call(() => callCount++);
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Call again before first timer completes
      debouncer.call(() => callCount++);
      
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Should only execute once (the second call)
      expect(callCount, equals(1));
      
      debouncer.dispose();
    });
    
    test('should execute immediately when immediate is called', () {
      var executed = false;
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      
      debouncer.call(() => executed = false);
      expect(debouncer.isPending, isTrue);
      
      debouncer.immediate(() => executed = true);
      
      expect(executed, isTrue);
      expect(debouncer.isPending, isFalse);
      expect(debouncer.callCount, equals(0));
      
      debouncer.dispose();
    });
    
    test('should cancel pending execution', () async {
      var executed = false;
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      
      debouncer.call(() => executed = true);
      expect(debouncer.isPending, isTrue);
      
      debouncer.cancel();
      
      await Future.delayed(const Duration(milliseconds: 150));
      
      expect(executed, isFalse);
      expect(debouncer.isPending, isFalse);
      
      debouncer.dispose();
    });
    
    test('should dispose timer properly', () {
      var executed = false;
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      
      debouncer.call(() => executed = true);
      expect(debouncer.isPending, isTrue);
      
      debouncer.dispose();
      
      expect(executed, isFalse);
    });
  });
  
  group('AsyncDebouncer Tests', () {
    test('should execute async action after delay', () async {
      var result = '';
      final debouncer = AsyncDebouncer(delay: const Duration(milliseconds: 100));
      
      final future = debouncer.call(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        result = 'executed';
        return result;
      });
      
      final returnedResult = await future;
      
      expect(result, equals('executed'));
      expect(returnedResult, equals('executed'));
      
      debouncer.dispose();
    });
    
    test('should cancel previous async call', () async {
      var firstExecuted = false;
      var secondExecuted = false;
      final debouncer = AsyncDebouncer(delay: const Duration(milliseconds: 100));
      
      final firstFuture = debouncer.call(() async {
        firstExecuted = true;
        return 'first';
      });
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      final secondFuture = debouncer.call(() async {
        secondExecuted = true;
        return 'second';
      });
      
      expect(firstFuture, throwsA(isA<DebounceCancelledException>()));
      
      final result = await secondFuture;
      
      expect(firstExecuted, isFalse);
      expect(secondExecuted, isTrue);
      expect(result, equals('second'));
      
      debouncer.dispose();
    });
    
    test('should execute immediately when immediate is called', () async {
      var immediateExecuted = false;
      final debouncer = AsyncDebouncer(delay: const Duration(milliseconds: 100));
      
      final result = await debouncer.immediate(() async {
        immediateExecuted = true;
        return 'immediate';
      });
      
      expect(immediateExecuted, isTrue);
      expect(result, equals('immediate'));
      
      debouncer.dispose();
    });
    
    test('should throw DebounceCancelledException when cancelled', () async {
      final debouncer = AsyncDebouncer(delay: const Duration(milliseconds: 100));
      
      final future = debouncer.call(() async => 'test');
      debouncer.cancel();
      
      expect(future, throwsA(isA<DebounceCancelledException>()));
      
      debouncer.dispose();
    });
  });
  
  group('SearchDebouncer Tests', () {
    test('should search after delay when query is long enough', () async {
      final searchResults = <String>[];
      
      final searchDebouncer = SearchDebouncer(
        delay: const Duration(milliseconds: 100),
        minLength: 2,
        onSearch: (query) => searchResults.add(query),
        onClear: () => searchResults.clear(),
      );
      
      searchDebouncer.search('test');
      
      expect(searchResults, isEmpty);
      
      await Future.delayed(const Duration(milliseconds: 150));
      expect(searchResults, contains('test'));
      
      searchDebouncer.dispose();
    });
    
    test('should clear when query is too short', () {
      final searchResults = <String>['previous'];
      
      final searchDebouncer = SearchDebouncer(
        delay: const Duration(milliseconds: 100),
        minLength: 2,
        onSearch: (query) => searchResults.add(query),
        onClear: () => searchResults.clear(),
      );
      
      searchDebouncer.search('a'); // Too short
      
      expect(searchResults, isEmpty);
      
      searchDebouncer.dispose();
    });
    
    test('should not search for duplicate queries', () async {
      final searchResults = <String>[];
      
      final searchDebouncer = SearchDebouncer(
        delay: const Duration(milliseconds: 50),
        onSearch: (query) => searchResults.add(query),
      );
      
      searchDebouncer.search('test');
      await Future.delayed(const Duration(milliseconds: 70));
      
      searchResults.clear();
      searchDebouncer.search('test'); // Same query
      await Future.delayed(const Duration(milliseconds: 70));
      
      expect(searchResults, isEmpty);
      
      searchDebouncer.dispose();
    });
    
    test('should track current query', () {
      final searchDebouncer = SearchDebouncer();
      
      searchDebouncer.search('test query');
      
      expect(searchDebouncer.currentQuery, equals('test query'));
      
      searchDebouncer.dispose();
    });
  });
  
  group('Throttler Tests', () {
    test('should execute immediately on first call', () {
      var executed = false;
      final throttler = Throttler(duration: const Duration(milliseconds: 100));
      
      throttler.call(() => executed = true);
      
      expect(executed, isTrue);
      
      throttler.dispose();
    });
    
    test('should throttle subsequent calls', () async {
      var callCount = 0;
      final throttler = Throttler(duration: const Duration(milliseconds: 100));
      
      throttler.call(() => callCount++); // Should execute immediately
      throttler.call(() => callCount++); // Should be throttled
      throttler.call(() => callCount++); // Should be throttled
      
      expect(callCount, equals(1));
      
      await Future.delayed(const Duration(milliseconds: 150));
      
      expect(callCount, equals(2));
      
      throttler.dispose();
    });
    
    test('should reset throttler state', () {
      var callCount = 0;
      final throttler = Throttler(duration: const Duration(milliseconds: 100));
      
      throttler.call(() => callCount++);
      
      throttler.reset();
      throttler.call(() => callCount++);
      
      expect(callCount, equals(2));
      
      throttler.dispose();
    });
    
    test('should calculate time until next execution', () {
      final throttler = Throttler(duration: const Duration(milliseconds: 100));
      
      throttler.call(() {});
      final timeUntilNext = throttler.timeUntilNextExecution;
      
      expect(timeUntilNext, isNotNull);
      expect(timeUntilNext!.inMilliseconds, greaterThan(0));
      expect(timeUntilNext.inMilliseconds, lessThanOrEqualTo(100));
      
      throttler.dispose();
    });
  });
} 