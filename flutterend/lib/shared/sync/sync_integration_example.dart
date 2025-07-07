// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../types/result.dart';
import 'sync_manager.dart';
import 'conflict_resolver.dart';

/// SyncManager与ConflictResolver集成使用示例
/// 
/// 本文件展示了三种不同的集成方案：
/// 1. 基础模式：仅使用SyncManager的简化冲突解决
/// 2. 高级模式：集成完整的ConflictResolver
/// 3. 自定义模式：根据业务需求自定义冲突解决策略

// ========================================
// 方案一：基础模式 - 简化冲突解决
// ========================================

/// 基础同步服务 - 使用简化的冲突解决
class BasicSyncService {
  BasicSyncService({required this.syncManager});
  
  final SyncManager syncManager;
  
  /// 简单的冲突解决
  Future<void> resolveConflictBasic(String conflictId) async {
    // 使用SyncManager内置的简化冲突解决
    final result = await syncManager.resolveConflict(
      conflictId,
      ConflictResolution.useLocal, // 使用本地版本策略
    );
    
    if (result.isSuccess) {
      debugPrint('冲突已解决: $conflictId');
    } else {
      debugPrint('冲突解决失败: ${result.errorOrNull}');
    }
  }
}

/// 基础模式的Provider
final basicSyncServiceProvider = Provider<BasicSyncService>((ref) {
  final syncManager = ref.watch(syncManagerProvider);
  return BasicSyncService(syncManager: syncManager);
});

// ========================================
// 方案二：高级模式 - 完整冲突解决器
// ========================================

/// 高级同步服务 - 使用完整的ConflictResolver
class AdvancedSyncService {
  AdvancedSyncService({required this.syncManager});
  
  final SyncManager syncManager;
  
  /// 智能冲突解决
  Future<void> resolveConflictIntelligent(String conflictId) async {
    // 检查是否有高级冲突解决器
    if (syncManager.hasAdvancedConflictResolution) {
      // 使用高级冲突解决功能
      final result = await syncManager.resolveConflict(
        conflictId,
        ConflictResolution.merge, // 让ConflictResolver选择最佳策略
      );
      
      if (result.isSuccess) {
        debugPrint('智能冲突解决成功: $conflictId');
      } else {
        debugPrint('智能冲突解决失败: ${result.errorOrNull}');
      }
    } else {
      // 回退到基础模式
      final result = await syncManager.resolveConflict(
        conflictId,
        ConflictResolution.useLocal,
      );
      
      debugPrint('使用基础冲突解决: ${result.isSuccess ? "成功" : "失败"}');
    }
  }
  
  /// 批量智能解决冲突
  Future<void> resolveAllConflictsBatch() async {
    // 需要从状态流中获取当前状态
    final currentState = await syncManager.stateStream.first;
    final conflicts = currentState.conflicts;
    final conflictIds = conflicts.map((c) => c.id).toList();
    
    if (syncManager.hasAdvancedConflictResolution) {
      // 使用高级批量解决
      final results = await syncManager.resolveConflictsAdvanced(conflictIds);
      
      final successCount = results.where((r) => r.isSuccess).length;
      debugPrint('批量冲突解决完成: $successCount/${results.length} 成功');
    } else {
      // 逐个解决
      for (final conflictId in conflictIds) {
        await syncManager.resolveConflict(conflictId, ConflictResolution.useLocal);
      }
      
      debugPrint('基础批量冲突解决完成');
    }
  }
}

/// 高级模式的Provider
final advancedSyncServiceProvider = Provider<AdvancedSyncService>((ref) {
  final syncManager = ref.watch(advancedSyncManagerProvider);
  return AdvancedSyncService(syncManager: syncManager);
});

// ========================================
// 方案三：自定义模式 - 业务特定策略
// ========================================

/// 自定义业务冲突解决策略
class BusinessSpecificStrategy implements ConflictResolutionStrategy {
  @override
  String get name => 'business_specific';
  
  @override
  int get priority => 1;
  
  @override
  bool canHandle(ConflictType conflictType) {
    // 只处理数据冲突，其他类型交给默认策略
    return conflictType == ConflictType.dataConflict;
  }
  
  @override
  Future<Result<SyncItem?, String>> resolve(
    SyncConflict conflict,
    Map<String, dynamic> context,
  ) async {
    // 业务特定的冲突解决逻辑
    // 例如：根据用户权限、数据重要性等因素决定
    
    final userId = context['user_id'] as String?;
    final isAdmin = context['is_admin'] as bool? ?? false;
    
    if (isAdmin) {
      // 管理员优先使用本地版本
      return Result.success(conflict.localItem);
    } else {
      // 普通用户优先使用服务器版本
      return Result.success(conflict.remoteItem);
    }
  }
}

/// 自定义同步服务
class CustomSyncService {
  late final SyncManager syncManager;
  
  CustomSyncService({
    SyncConfig? config,
    bool enableAdvancedResolver = false,
  }) {
    if (enableAdvancedResolver) {
      // 创建自定义冲突解决器
      final conflictResolver = ConflictResolverFactory.create(
        defaultStrategy: BusinessSpecificStrategy(),
        autoResolutionEnabled: true,
      );
      
      // 注册额外的策略
      conflictResolver.registerStrategy(LastModifiedWinsStrategy());
      conflictResolver.registerStrategy(MergeStrategy());
      
      syncManager = SyncManager(
        config: config,
        conflictResolver: conflictResolver,
      );
    } else {
      // 仅使用基础功能
      syncManager = SyncManager(config: config);
    }
  }
  
  /// 上下文感知的冲突解决
  Future<void> resolveWithContext(
    String conflictId, {
    required String userId,
    required bool isAdmin,
  }) async {
    if (syncManager.hasAdvancedConflictResolution) {
      // 传递业务上下文给冲突解决器
      final result = await syncManager.resolveConflict(
        conflictId,
        ConflictResolution.merge,
      );
      
      debugPrint('上下文感知冲突解决: ${result.isSuccess ? "成功" : "失败"}');
    } else {
      // 在应用层实现业务逻辑
      final resolution = isAdmin 
          ? ConflictResolution.useLocal 
          : ConflictResolution.useRemote;
          
      final result = await syncManager.resolveConflict(conflictId, resolution);
      debugPrint('应用层业务冲突解决: ${result.isSuccess ? "成功" : "失败"}');
    }
  }
}

// ========================================
// UI 组件：选择冲突解决模式
// ========================================

/// 冲突解决模式选择器
class ConflictResolutionModeSelector extends ConsumerWidget {
  const ConflictResolutionModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择冲突解决模式',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 基础模式
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('基础模式'),
              subtitle: const Text('使用简化的冲突解决逻辑'),
              onTap: () => _switchToBasicMode(ref),
            ),
            
            // 高级模式
            ListTile(
              leading: const Icon(Icons.psychology),
              title: const Text('高级模式'),
              subtitle: const Text('使用智能冲突解决策略'),
              onTap: () => _switchToAdvancedMode(ref),
            ),
            
            // 自定义模式
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('自定义模式'),
              subtitle: const Text('根据业务需求定制策略'),
              onTap: () => _switchToCustomMode(ref),
            ),
          ],
        ),
      ),
    );
  }
  
  void _switchToBasicMode(WidgetRef ref) {
    // 切换到基础同步服务
    ref.read(basicSyncServiceProvider);
    ScaffoldMessenger.of(ref.context).showSnackBar(
      const SnackBar(content: Text('已切换到基础冲突解决模式')),
    );
  }
  
  void _switchToAdvancedMode(WidgetRef ref) {
    // 切换到高级同步服务
    ref.read(advancedSyncServiceProvider);
    ScaffoldMessenger.of(ref.context).showSnackBar(
      const SnackBar(content: Text('已切换到高级冲突解决模式')),
    );
  }
  
  void _switchToCustomMode(WidgetRef ref) {
    // 创建自定义同步服务
    final customService = CustomSyncService(
      enableAdvancedResolver: true,
    );
    
    ScaffoldMessenger.of(ref.context).showSnackBar(
      const SnackBar(content: Text('已切换到自定义冲突解决模式')),
    );
  }
}

// ========================================
// 最佳实践指南
// ========================================

/// SyncManager与ConflictResolver集成最佳实践
/// 
/// 选择建议：
/// 
/// 1. **简单应用/原型阶段**：
///    - 使用基础模式（syncManagerProvider）
///    - 依赖SyncManager内置的简化冲突解决
///    - 快速开发，满足基本需求
/// 
/// 2. **企业级应用/复杂业务**：
///    - 使用高级模式（advancedSyncManagerProvider）  
///    - 集成完整的ConflictResolver
///    - 获得智能策略、批量处理、历史记录等能力
/// 
/// 3. **特殊业务需求**：
///    - 使用自定义模式
///    - 实现业务特定的冲突解决策略
///    - 在需要的地方注入ConflictResolver
/// 
/// 迁移路径：
/// - 从基础模式开始
/// - 当需要更复杂的冲突解决时，切换到高级模式
/// - 根据具体业务需求，定制策略
/// 
/// 性能考虑：
/// - 基础模式：轻量级，适合简单场景
/// - 高级模式：功能丰富，有一定内存开销
/// - 自定义模式：根据策略复杂度而定 