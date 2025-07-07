import 'package:flutter_test/flutter_test.dart';
import 'package:v7_flutter_app/shared/contracts/base_contract.dart';
import 'package:v7_flutter_app/shared/types/result.dart';

// 测试用契约实现
class TestContract extends AsyncContract with ObservableContract, CacheableContract {
  @override
  String get contractName => 'test_contract';
  
  bool _initCalled = false;
  bool _disposeCalled = false;
  
  bool get initCalled => _initCalled;
  bool get disposeCalled => _disposeCalled;
  
  @override
  Future<void> onInitialize() async {
    await Future.delayed(const Duration(milliseconds: 10));
    _initCalled = true;
  }
  
  @override
  Future<void> onDispose() async {
    await disposeObservable();
    _disposeCalled = true;
  }
  
  // 测试方法 - 自动初始化
  Future<String> testMethod() async {
    if (!isInitialized) {
      await initialize();
    }
    ensureInitialized();
    return 'test_result';
  }
  
  void triggerStateChange() {
    notifyStateChange('testProperty', 'oldValue', 'newValue');
  }
}

class FailingContract extends AsyncContract {
  @override
  String get contractName => 'failing_contract';
  
  @override
  Future<void> onInitialize() async {
    throw Exception('Initialization failed');
  }
  
  @override
  Future<void> onDispose() async {
    // Empty implementation
  }
}

void main() {
  group('BaseContract Tests', () {
    group('AsyncContract', () {
      late TestContract contract;
      
      setUp(() {
        contract = TestContract();
      });
      
      tearDown(() async {
        if (contract.isInitialized) {
          await contract.dispose();
        }
      });
      
      test('should initialize successfully', () async {
        expect(contract.isInitialized, isFalse);
        expect(contract.isDisposed, isFalse);
        
        final result = await contract.initialize();
        
        expect(result.isSuccess, isTrue);
        expect(contract.isInitialized, isTrue);
        expect(contract.initCalled, isTrue);
        expect(contract.isDisposed, isFalse);
      });
      
      test('should wait for initialization to complete', () async {
        final initFuture = contract.initialize();
        final readyFuture = contract.ready;
        
        await initFuture;
        await readyFuture;
        
        expect(contract.isInitialized, isTrue);
      });
      
      test('should not reinitialize if already initialized', () async {
        await contract.initialize();
        expect(contract.isInitialized, isTrue);
        
        final result = await contract.initialize();
        expect(result.isSuccess, isTrue);
      });
      
      test('should handle initialization failure', () async {
        final failingContract = FailingContract();
        
        final result = await failingContract.initialize();
        
        expect(result.isFailure, isTrue);
        expect(failingContract.isInitialized, isFalse);
        expect(result.errorOrNull, isA<BusinessError>());
      });
      
      test('should not initialize disposed contract', () async {
        await contract.initialize();
        await contract.dispose();
        
        final result = await contract.initialize();
        
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<BusinessError>());
      });
      
      test('should dispose successfully', () async {
        await contract.initialize();
        expect(contract.isInitialized, isTrue);
        
        await contract.dispose();
        
        expect(contract.isDisposed, isTrue);
        expect(contract.disposeCalled, isTrue);
      });
      
      test('should not dispose multiple times', () async {
        await contract.initialize();
        await contract.dispose();
        expect(contract.isDisposed, isTrue);
        
        // Second dispose should not throw
        await contract.dispose();
        expect(contract.isDisposed, isTrue);
      });
      
      test('should ensure initialization before operations', () async {
        final result = await contract.testMethod();
        
        expect(result, equals('test_result'));
        expect(contract.isInitialized, isTrue);
      });
    });
    
    group('ObservableContract', () {
      late TestContract contract;
      
      setUp(() {
        contract = TestContract();
      });
      
      tearDown(() async {
        if (contract.isInitialized) {
          await contract.dispose();
        }
      });
      
      test('should notify state changes', () async {
        await contract.initialize();
        
        ContractStateChange? receivedChange;
        contract.stateChanges.listen((change) {
          receivedChange = change;
        });
        
        contract.triggerStateChange();
        
        await Future.delayed(const Duration(milliseconds: 10));
        
        expect(receivedChange, isNotNull);
        expect(receivedChange!.contractName, equals('test_contract'));
        expect(receivedChange!.property, equals('testProperty'));
        expect(receivedChange!.oldValue, equals('oldValue'));
        expect(receivedChange!.newValue, equals('newValue'));
      });
      
      test('should dispose state change controller', () async {
        await contract.initialize();
        
        var streamClosed = false;
        contract.stateChanges.listen(
          (_) {},
          onDone: () => streamClosed = true,
        );
        
        await contract.dispose();
        
        await Future.delayed(const Duration(milliseconds: 10));
        expect(streamClosed, isTrue);
      });
    });
    
    group('CacheableContract', () {
      late TestContract contract;
      
      setUp(() async {
        contract = TestContract();
        await contract.initialize();
      });
      
      tearDown(() async {
        await contract.dispose();
      });
      
      test('should set and get cache values', () {
        const key = 'test_key';
        const value = 'test_value';
        
        contract.setCache(key, value);
        final retrieved = contract.getFromCache<String>(key);
        
        expect(retrieved, equals(value));
      });
      
      test('should return null for non-existent cache key', () {
        final retrieved = contract.getFromCache<String>('non_existent');
        expect(retrieved, isNull);
      });
      
      test('should handle cache expiration', () async {
        const key = 'expiring_key';
        const value = 'expiring_value';
        
        contract.setCache(key, value, ttl: const Duration(milliseconds: 50));
        
        // Should exist immediately
        expect(contract.getFromCache<String>(key), equals(value));
        
        // Wait for expiration
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Should be expired
        expect(contract.getFromCache<String>(key), isNull);
      });
      
      test('should clear specific cache entry', () {
        const key = 'test_key';
        const value = 'test_value';
        
        contract.setCache(key, value);
        expect(contract.getFromCache<String>(key), equals(value));
        
        contract.clearCache(key);
        expect(contract.getFromCache<String>(key), isNull);
      });
      
      test('should clear all cache', () {
        contract.setCache('key1', 'value1');
        contract.setCache('key2', 'value2');
        
        expect(contract.getFromCache<String>('key1'), equals('value1'));
        expect(contract.getFromCache<String>('key2'), equals('value2'));
        
        contract.clearAllCache();
        
        expect(contract.getFromCache<String>('key1'), isNull);
        expect(contract.getFromCache<String>('key2'), isNull);
      });
      
      test('should cleanup expired cache', () async {
        contract.setCache('valid_key', 'valid_value', ttl: const Duration(minutes: 1));
        contract.setCache('expired_key', 'expired_value', ttl: const Duration(milliseconds: 50));
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        contract.cleanupExpiredCache();
        
        expect(contract.getFromCache<String>('valid_key'), equals('valid_value'));
        expect(contract.getFromCache<String>('expired_key'), isNull);
      });
      
      test('should provide cache statistics', () {
        contract.setCache('key1', 'value1', ttl: const Duration(minutes: 1));
        contract.setCache('key2', 'value2', ttl: const Duration(milliseconds: 1));
        
        final stats = contract.cacheStats;
        expect(stats.totalEntries, equals(2));
        expect(stats.validEntries, equals(2));
        expect(stats.expiredEntries, equals(0));
      });
      
      test('should set default cache TTL', () {
        contract.setDefaultCacheTtl(const Duration(milliseconds: 100));
        
        contract.setCache('test_key', 'test_value');
        
        // Should exist immediately
        expect(contract.getFromCache<String>('test_key'), equals('test_value'));
      });
    });
    
    group('ContractRegistry', () {
      late ContractRegistry registry;
      
      setUp(() {
        registry = ContractRegistry.instance;
      });
      
      tearDown(() async {
        await registry.clearSingletons();
      });
      
      test('should register and get contract factory', () {
        final factory = TestContractFactory();
        
        registry.register<TestContract>(factory);
        
        expect(registry.isRegistered<TestContract>(), isTrue);
        
        final contract = registry.get<TestContract>();
        expect(contract, isA<TestContract>());
      });
      
      test('should return same instance for singleton factory', () {
        final factory = TestContractFactory();
        registry.register<TestContract>(factory);
        
        final contract1 = registry.get<TestContract>();
        final contract2 = registry.get<TestContract>();
        
        expect(identical(contract1, contract2), isTrue);
      });
      
      test('should throw for unregistered contract', () async {
        // Clear any existing registrations first
        await registry.clear();
        expect(
          () => registry.get<TestContract>(),
          throwsStateError,
        );
      });
      
      test('should get registered types', () {
        final factory = TestContractFactory();
        registry.register<TestContract>(factory);
        
        final types = registry.registeredTypes;
        expect(types, contains(TestContract));
      });
      
      test('should clear singletons', () async {
        final factory = TestContractFactory();
        registry.register<TestContract>(factory);
        
        final contract = registry.get<TestContract>();
        await contract.initialize();
        expect(contract.isInitialized, isTrue);
        
        await registry.clearSingletons();
        
        expect(contract.isDisposed, isTrue);
      });
    });
  });
}

// 测试用契约工厂
class TestContractFactory extends ContractFactory<TestContract> {
  @override
  TestContract create() => TestContract();
} 