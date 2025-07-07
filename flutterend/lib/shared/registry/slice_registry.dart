/// 切片注册中心 - v7统一配置系统
/// 参考 web/src/shared/registry.ts 设计
/// 
/// 统一管理切片组件和摘要提供者
/// 支持动态注册和查询切片信息
/// 实现一处配置、自动注册的最佳实践

import 'package:flutter/material.dart';
import '../contracts/slice_summary_contract.dart';
import '../../slices/demo/summary_provider.dart';
import '../../slices/demo/widgets.dart';

/// 切片配置定义
/// 每个切片只需要在这里配置一次，系统会自动处理注册和路由
class SliceConfig {
  const SliceConfig({
    required this.name,
    required this.displayName,
    required this.description,
    required this.widgetBuilder,
    required this.summaryProvider,
    this.version = '1.0.0',
    this.iconColor = 0xFF0088CC,
    this.category = '功能切片',
    this.author = 'v7 Team',
    this.isEnabled = true,
    this.dependencies = const [],
  });

  final String name;
  final String displayName;
  final String description;
  final Widget Function() widgetBuilder;
  final SliceSummaryProvider summaryProvider;
  final String version;
  final int iconColor;
  final String category;
  final String author;
  final bool isEnabled;
  final List<String> dependencies;

  /// 路由路径
  String get routePath => '/slice/$name';

  /// 转换为SliceRegistration
  SliceRegistration toRegistration() {
    return SliceRegistration(
      name: name,
      displayName: displayName,
      routePath: routePath,
      description: description,
      version: version,
      summaryProvider: summaryProvider,
      iconColor: iconColor,
      category: category,
      author: author,
    );
  }
}

/// 🎯 切片配置中心 - 一处配置，全局生效
/// 
/// 新增切片步骤：
/// 1. 在这里添加切片配置
/// 2. 创建切片Widget和SummaryProvider
/// 3. 系统自动处理注册和路由
class SliceConfigs {
  static final List<SliceConfig> _configs = [
    // Demo切片 - 任务管理
    SliceConfig(
      name: 'demo',
      displayName: '任务管理',
      description: 'Flutter v7切片架构演示，包含完整的任务管理功能实现',
      widgetBuilder: TasksWidget.new,
      summaryProvider: DemoTaskSummaryProvider(),
      iconColor: 0xFF0088CC,
      category: '已实现',
      author: 'v7 Team',
      isEnabled: true,
      dependencies: const ['shared'],
    ),
    
    // 🚀 未来切片配置示例（暂时禁用）
    // SliceConfig(
    //   name: 'user_management',
    //   displayName: '用户管理',
    //   description: '用户账户管理和权限控制',
    //   widgetBuilder: UserManagementWidget.new,
    //   summaryProvider: UserManagementSummaryProvider(),
    //   iconColor: 0xFF4CAF50,
    //   category: '开发中',
    //   isEnabled: false,
    // ),
  ];

  /// 获取所有启用的切片配置
  static List<SliceConfig> get enabledConfigs => 
      _configs.where((config) => config.isEnabled).toList();

  /// 获取所有切片配置
  static List<SliceConfig> get allConfigs => List.unmodifiable(_configs);

  /// 根据名称获取切片配置
  static SliceConfig? getConfig(String name) {
    try {
      return _configs.firstWhere((config) => config.name == name);
    } catch (e) {
      return null;
    }
  }

  /// 检查切片是否存在
  static bool hasSlice(String name) => getConfig(name) != null;

  /// 检查切片是否启用
  static bool isSliceEnabled(String name) {
    final config = getConfig(name);
    return config?.isEnabled ?? false;
  }

  /// 获取切片Widget构建器
  static Widget Function()? getWidgetBuilder(String name) {
    final config = getConfig(name);
    return config?.widgetBuilder;
  }
}

/// 切片注册中心
class SliceRegistry {
  static final SliceRegistry _instance = SliceRegistry._internal();
  factory SliceRegistry() => _instance;
  SliceRegistry._internal();

  final Map<String, SliceRegistration> _registry = {};

  /// 初始化注册中心 - 基于配置自动注册
  void initialize() {
    // 清空注册中心，避免重复注册
    _registry.clear();
    
    // 🎯 自动注册所有启用的切片
    for (final config in SliceConfigs.enabledConfigs) {
      register(config.toRegistration());
    }

    debugPrint('✅ 切片注册中心初始化完成，注册了 ${_registry.length} 个功能切片');
    
    // 打印注册详情
    for (final registration in _registry.values) {
      debugPrint('📦 切片已注册: ${registration.name} (${registration.displayName}) - ${registration.category}');
    }
  }

  /// 动态扫描并初始化注册中心
  Future<void> initializeWithDynamicScanning() async {
    // 基于配置初始化
    initialize();
    
    debugPrint('🔍 切片注册中心初始化完成，共注册 ${_registry.length} 个切片');
    
    // TODO: 在实际项目中，这里可以扫描lib/slices目录
    // 动态发现并注册新切片
    // await _scanAndRegisterSlices();
  }

  /// 注册切片
  void register(SliceRegistration registration) {
    _registry[registration.name] = registration;
    debugPrint('📦 注册切片: ${registration.name} (${registration.displayName})');
  }

  /// 注销切片
  void unregister(String name) {
    final registration = _registry[name];
    if (registration?.summaryProvider != null) {
      registration!.summaryProvider!.dispose();
    }
    _registry.remove(name);
    debugPrint('🗑️ 注销切片: $name');
  }

  /// 获取切片注册信息
  SliceRegistration? getRegistration(String name) {
    return _registry[name];
  }

  /// 获取所有切片名称
  List<String> getSliceNames() {
    return _registry.keys.toList();
  }

  /// 获取所有切片注册信息
  List<SliceRegistration> getAllRegistrations() {
    final registrations = _registry.values.toList();
    debugPrint('📋 获取所有切片: ${registrations.length} 个功能切片');
    return registrations;
  }

  /// 获取切片摘要提供者
  SliceSummaryProvider? getSummaryProvider(String name) {
    return _registry[name]?.summaryProvider;
  }

  /// 检查切片是否存在
  bool hasSlice(String name) {
    return _registry.containsKey(name);
  }

  /// 获取切片数量
  int get sliceCount => _registry.length;

  /// 按分类获取切片
  Map<String, List<SliceRegistration>> getSlicesByCategory() {
    final Map<String, List<SliceRegistration>> categorized = {};
    
    for (final registration in _registry.values) {
      final category = registration.category ?? '其他';
      categorized.putIfAbsent(category, () => []);
      categorized[category]!.add(registration);
    }
    
    return categorized;
  }

  /// 搜索切片
  List<SliceRegistration> searchSlices(String query) {
    if (query.isEmpty) {
      return getAllRegistrations();
    }
    
    final lowerQuery = query.toLowerCase();
    return _registry.values.where((registration) {
      return registration.name.toLowerCase().contains(lowerQuery) ||
             registration.displayName.toLowerCase().contains(lowerQuery) ||
             (registration.description?.toLowerCase().contains(lowerQuery) ?? false) ||
             (registration.category?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// 获取切片摘要数据
  Future<SliceSummaryContract?> getSummaryData(String name) async {
    final provider = getSummaryProvider(name);
    if (provider == null) {
      debugPrint('⚠️ 切片 $name 没有摘要提供者');
      return null;
    }
    
    try {
      final summary = await provider.getSummaryData();
      debugPrint('✅ 成功获取切片 $name 的摘要数据: ${summary.title}');
      return summary;
    } catch (error) {
      debugPrint('❌ 获取切片 $name 摘要数据失败: $error');
      return null;
    }
  }

  /// 刷新切片摘要数据
  Future<void> refreshSummaryData(String name) async {
    final provider = getSummaryProvider(name);
    if (provider == null) return;
    
    try {
      await provider.refreshData();
      debugPrint('🔄 刷新切片 $name 摘要数据成功');
    } catch (error) {
      debugPrint('❌ 刷新切片 $name 摘要数据失败: $error');
    }
  }

  /// 刷新所有切片摘要数据
  Future<void> refreshAllSummaryData() async {
    await Future.wait(
      _registry.keys.map((name) => refreshSummaryData(name)),
    );
  }

  /// 释放资源
  void dispose() {
    for (final registration in _registry.values) {
      registration.summaryProvider?.dispose();
    }
    _registry.clear();
    debugPrint('🧹 切片注册中心资源已释放');
  }

  /// TODO: 未来实现的动态切片扫描功能
  /// 扫描 lib/slices/ 目录，自动发现并注册新切片
  Future<void> _scanAndRegisterSlices() async {
    // 实现目录扫描逻辑
    // 1. 扫描 lib/slices/ 目录
    // 2. 检查每个子目录是否包含 index.dart
    // 3. 动态导入并注册切片
    // 4. 验证切片完整性
    debugPrint('🔍 动态切片扫描功能 - 待实现');
  }
}

/// 全局切片注册中心实例
final sliceRegistry = SliceRegistry(); 