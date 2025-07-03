/// 切片注册中心
/// 参考 web/src/shared/registry.ts 设计
/// 
/// 统一管理切片组件和摘要提供者
/// 支持动态注册和查询切片信息

import 'package:flutter/material.dart';
import '../contracts/slice_summary_contract.dart';
import '../../slices/demo/summary_provider.dart';

/// 切片注册中心
class SliceRegistry {
  static final SliceRegistry _instance = SliceRegistry._internal();
  factory SliceRegistry() => _instance;
  SliceRegistry._internal();

  final Map<String, SliceRegistration> _registry = {};

  /// 初始化注册中心 - 只注册真实实现的切片
  void initialize() {
    // 清空注册中心，避免重复注册
    _registry.clear();
    
    // 🎯 只注册Demo切片 - 真实已实现的功能切片
    register(SliceRegistration(
      name: 'demo',
      displayName: '任务管理',
      routePath: '/slice/demo',
      description: 'Flutter v7切片架构演示，包含完整的任务管理功能实现',
      version: '1.0.0',
      summaryProvider: DemoTaskSummaryProvider(),
      iconColor: const Color(0xFF0088CC).value,
      category: '已实现',
      author: 'v7 Team',
    ));

    debugPrint('✅ 切片注册中心初始化完成，注册了 ${_registry.length} 个真实功能切片');
  }

  /// 动态扫描并初始化注册中心
  Future<void> initializeWithDynamicScanning() async {
    // 先注册已实现的切片
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
    debugPrint('📋 获取所有切片: ${registrations.length} 个真实功能切片');
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