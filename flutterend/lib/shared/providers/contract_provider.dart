import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../contracts/base_contract.dart';

/// v7 架构合约注册中心
class ContractRegistry {
  ContractRegistry._internal();
  static final ContractRegistry _instance = ContractRegistry._internal();
  factory ContractRegistry() => _instance;
  
  final Map<String, BaseContract> _contracts = {};
  final Map<Type, BaseContract> _typeContracts = {};
  
  /// 注册合约
  void register<T extends BaseContract>(T contract) {
    _contracts[contract.contractName] = contract;
    _typeContracts[T] = contract;
  }
  
  /// 获取合约（按名称）
  T? getContract<T extends BaseContract>(String contractName) {
    return _contracts[contractName] as T?;
  }
  
  /// 获取合约（按类型）
  T? getContractByType<T extends BaseContract>() {
    return _typeContracts[T] as T?;
  }
  
  /// 检查合约是否注册
  bool isRegistered<T extends BaseContract>(String contractName) {
    return _contracts.containsKey(contractName);
  }
  
  /// 获取所有已注册的合约名称
  List<String> getRegisteredContractNames() {
    return _contracts.keys.toList();
  }
  
  /// 注销合约
  void unregister(String contractName) {
    final contract = _contracts.remove(contractName);
    if (contract != null) {
      _typeContracts.removeWhere((key, value) => value == contract);
    }
  }
  
  /// 清空所有合约
  void clear() {
    _contracts.clear();
    _typeContracts.clear();
  }
}

/// 全局合约注册中心
final contractRegistry = ContractRegistry();

/// Riverpod 合约提供器
final contractProvider = Provider.family<BaseContract?, String>((ref, contractName) {
  return contractRegistry.getContract(contractName);
});

/// 认证合约提供器
final authContractProvider = Provider<AuthContract?>((ref) {
  return contractRegistry.getContractByType<AuthContract>();
});

/// 通知合约提供器
final notificationContractProvider = Provider<NotificationContract?>((ref) {
  return contractRegistry.getContractByType<NotificationContract>();
});

/// 导航合约提供器
final navigationContractProvider = Provider<NavigationContract?>((ref) {
  return contractRegistry.getContractByType<NavigationContract>();
});

/// 合约注入混入类
mixin ContractMixin {
  /// 注入合约
  T? getContract<T extends BaseContract>(String contractName) {
    return contractRegistry.getContract<T>(contractName);
  }
  
  /// 注入认证合约
  AuthContract? get authContract => 
      contractRegistry.getContractByType<AuthContract>();
  
  /// 注入通知合约
  NotificationContract? get notificationContract => 
      contractRegistry.getContractByType<NotificationContract>();
  
  /// 注入导航合约
  NavigationContract? get navigationContract => 
      contractRegistry.getContractByType<NavigationContract>();
}

/// 合约工厂类
class ContractFactory {
  /// 创建并注册合约
  static Future<void> registerContracts() async {
    // 这里将在具体实现时注册各种合约
    // 例如：
    // final authContract = AuthContractImpl();
    // await authContract.initialize();
    // contractRegistry.register(authContract);
  }
  
  /// 注销所有合约
  static Future<void> unregisterAll() async {
    for (final contractName in contractRegistry.getRegisteredContractNames()) {
      final contract = contractRegistry.getContract(contractName);
      if (contract != null) {
        await contract.dispose();
      }
    }
    contractRegistry.clear();
  }
} 