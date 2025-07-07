// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

/// 冲突解决器使用示例
/// 
/// 本文件展示如何在v7 Flutter架构中集成和使用冲突解决器
/// 处理离线同步时的数据冲突问题

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conflict_resolver.dart';
import 'sync_manager.dart';
import '../types/result.dart';

/// 示例：用户数据同步项
class UserSyncItem implements SyncItem {
  const UserSyncItem({
    required this.id,
    required this.name,
    required this.email,
    required this.lastModified,
    required this.version,
    this.avatar,
    this.metadata = const {},
  });

  @override
  final String id;
  
  final String name;
  final String email;
  final String? avatar;
  final Map<String, dynamic> metadata;

  @override
  final DateTime lastModified;

  @override
  final int version;

  @override
  String get type => 'user';

  @override
  String get checksum => 
      '${id}_${name}_${email}_${version}_${lastModified.millisecondsSinceEpoch}';

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatar': avatar,
    'metadata': metadata,
    'last_modified': lastModified.toIso8601String(),
    'version': version,
  };

  UserSyncItem copyWith({
    String? id,
    String? name,
    String? email,
    String? avatar,
    Map<String, dynamic>? metadata,
    DateTime? lastModified,
    int? version,
  }) {
    return UserSyncItem(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      metadata: metadata ?? this.metadata,
      lastModified: lastModified ?? this.lastModified,
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSyncItem && other.checksum == checksum;
  }

  @override
  int get hashCode => checksum.hashCode;
}

/// 自定义用户合并策略
class UserMergeStrategy implements ConflictResolutionStrategy {
  @override
  String get name => 'UserMerge';

  @override
  int get priority => 1; // 高优先级

  @override
  bool canHandle(ConflictType conflictType) {
    return conflictType == ConflictType.dataConflict;
  }

  @override
  Future<Result<SyncItem?, String>> resolve(
    SyncConflict conflict,
    Map<String, dynamic> context,
  ) async {
    try {
      if (conflict.localItem is! UserSyncItem || 
          conflict.remoteItem is! UserSyncItem) {
        return Result.failure('只能处理UserSyncItem类型的冲突');
      }

      final localUser = conflict.localItem as UserSyncItem;
      final remoteUser = conflict.remoteItem as UserSyncItem;

      // 智能合并策略：
      // 1. 使用最新的基本信息
      // 2. 合并metadata
      // 3. 保留最新的头像
      final mergedMetadata = Map<String, dynamic>.from(localUser.metadata);
      mergedMetadata.addAll(remoteUser.metadata);

      final mergedUser = localUser.copyWith(
        name: remoteUser.lastModified.isAfter(localUser.lastModified) 
            ? remoteUser.name 
            : localUser.name,
        email: remoteUser.lastModified.isAfter(localUser.lastModified)
            ? remoteUser.email 
            : localUser.email,
        avatar: remoteUser.avatar ?? localUser.avatar, // 保留非空头像
        metadata: mergedMetadata,
        lastModified: remoteUser.lastModified.isAfter(localUser.lastModified)
            ? remoteUser.lastModified 
            : localUser.lastModified,
        version: [localUser.version, remoteUser.version].reduce((a, b) => a > b ? a : b) + 1,
      );

      return Result.success(mergedUser);
    } catch (e) {
      return Result.failure('用户合并策略执行失败: $e');
    }
  }
}

/// 冲突解决服务
class ConflictResolutionService {
  ConflictResolutionService({
    ConflictResolver? conflictResolver,
  }) : _conflictResolver = conflictResolver ?? _createDefaultResolver();

  final ConflictResolver _conflictResolver;

  static ConflictResolver _createDefaultResolver() {
    return ConflictResolverFactory.create(
      defaultStrategy: LastModifiedWinsStrategy(),
      autoResolutionEnabled: true,
      customStrategies: [
        UserMergeStrategy(),
      ],
    );
  }

  /// 初始化服务
  Future<void> initialize() async {
    await _conflictResolver.initialize();
  }

  /// 处理用户数据冲突
  Future<Result<UserSyncItem?, String>> resolveUserConflict(
    UserSyncItem localUser,
    UserSyncItem remoteUser,
    String userId,
    String deviceId,
  ) async {
    final conflict = SyncConflict(
      id: '${localUser.id}_${DateTime.now().millisecondsSinceEpoch}',
      type: 'user',
      localItem: localUser,
      remoteItem: remoteUser,
      conflictType: ConflictType.dataConflict,
    );

    final context = ConflictResolutionContext(
      userId: userId,
      deviceId: deviceId,
      timestamp: DateTime.now(),
      metadata: {
        'local_version': localUser.version,
        'remote_version': remoteUser.version,
      },
    );

    final result = await _conflictResolver.resolveConflict(conflict, context);
    
    if (result.isSuccess) {
      final resolutionResult = result.valueOrNull!;
      return Result.success(resolutionResult.resolvedItem as UserSyncItem?);
    } else {
      return Result.failure(result.errorOrNull ?? '冲突解决失败');
    }
  }

  /// 获取解决历史
  Future<List<ConflictResolutionResult>> getHistory({
    DateTime? since,
    int limit = 50,
  }) async {
    return _conflictResolver.getResolutionHistory(
      since: since,
      limit: limit,
    );
  }

  /// 释放资源
  Future<void> dispose() async {
    await _conflictResolver.dispose();
  }
}

/// Riverpod提供者
final conflictResolutionServiceProvider = Provider<ConflictResolutionService>((ref) {
  return ConflictResolutionService();
});

/// 冲突解决状态管理
class ConflictResolutionNotifier extends StateNotifier<AsyncValue<List<SyncConflict>>> {
  ConflictResolutionNotifier(this._service) : super(const AsyncValue.data([]));

  final ConflictResolutionService _service;

  /// 解决所有冲突
  Future<void> resolveAllConflicts(
    List<SyncConflict> conflicts,
    String userId,
    String deviceId,
  ) async {
    state = const AsyncValue.loading();
    
    try {
      final context = ConflictResolutionContext(
        userId: userId,
        deviceId: deviceId,
        timestamp: DateTime.now(),
      );

      final results = await _service._conflictResolver.resolveConflicts(
        conflicts,
        context,
      );

      // 过滤出未解决的冲突
      final unresolved = <SyncConflict>[];
      for (int i = 0; i < conflicts.length; i++) {
        if (results[i].isFailure) {
          unresolved.add(conflicts[i]);
        }
      }

      state = AsyncValue.data(unresolved);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 手动解决冲突
  Future<void> resolveManually(
    SyncConflict conflict,
    ConflictResolution resolution,
    SyncItem? customItem,
  ) async {
    // 实现手动解决逻辑
    final currentConflicts = state.value ?? [];
    final updatedConflicts = currentConflicts
        .where((c) => c.id != conflict.id)
        .toList();
    
    state = AsyncValue.data(updatedConflicts);
  }
}

final conflictResolutionProvider = StateNotifierProvider<ConflictResolutionNotifier, AsyncValue<List<SyncConflict>>>((ref) {
  final service = ref.watch(conflictResolutionServiceProvider);
  return ConflictResolutionNotifier(service);
});

/// 冲突解决UI组件
class ConflictResolutionWidget extends ConsumerWidget {
  const ConflictResolutionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(conflictResolutionProvider);

    return conflictsAsync.when(
      data: (conflicts) {
        if (conflicts.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('没有待解决的冲突'),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text('发现 ${conflicts.length} 个同步冲突'),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => _resolveAllConflicts(context, ref),
                      child: const Text('自动解决'),
                    ),
                  ],
                ),
              ),
            ),
            ...conflicts.map((conflict) => ConflictItemWidget(conflict: conflict)),
          ],
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在解决冲突...'),
            ],
          ),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text('冲突解决失败: $error')),
            ],
          ),
        ),
      ),
    );
  }

  void _resolveAllConflicts(BuildContext context, WidgetRef ref) {
    final conflicts = ref.read(conflictResolutionProvider).value ?? [];
    ref.read(conflictResolutionProvider.notifier).resolveAllConflicts(
      conflicts,
      'current_user_id', // 实际应用中从认证服务获取
      'current_device_id', // 实际应用中从设备信息获取
    );
  }
}

/// 单个冲突项组件
class ConflictItemWidget extends ConsumerWidget {
  const ConflictItemWidget({
    required this.conflict,
    super.key,
  });

  final SyncConflict conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getConflictIcon(conflict.conflictType)),
                const SizedBox(width: 8),
                Text(
                  '${conflict.type} 冲突',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  _getConflictTypeText(conflict.conflictType),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('本地版本: ${conflict.localItem.version}'),
            Text('远程版本: ${conflict.remoteItem.version}'),
            Text('本地修改: ${_formatDateTime(conflict.localItem.lastModified)}'),
            Text('远程修改: ${_formatDateTime(conflict.remoteItem.lastModified)}'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _resolveConflict(ref, ConflictResolution.useLocal),
                  child: const Text('使用本地'),
                ),
                ElevatedButton(
                  onPressed: () => _resolveConflict(ref, ConflictResolution.useRemote),
                  child: const Text('使用远程'),
                ),
                if (conflict.conflictType == ConflictType.dataConflict)
                  ElevatedButton(
                    onPressed: () => _resolveConflict(ref, ConflictResolution.merge),
                    child: const Text('合并'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resolveConflict(WidgetRef ref, ConflictResolution resolution) {
    ref.read(conflictResolutionProvider.notifier).resolveManually(
      conflict,
      resolution,
      null,
    );
  }

  IconData _getConflictIcon(ConflictType type) {
    switch (type) {
      case ConflictType.dataConflict:
        return Icons.compare_arrows;
      case ConflictType.deleteConflict:
        return Icons.delete_forever;
      case ConflictType.typeConflict:
        return Icons.category;
      case ConflictType.versionConflict:
        return Icons.history;
    }
  }

  String _getConflictTypeText(ConflictType type) {
    switch (type) {
      case ConflictType.dataConflict:
        return '数据冲突';
      case ConflictType.deleteConflict:
        return '删除冲突';
      case ConflictType.typeConflict:
        return '类型冲突';
      case ConflictType.versionConflict:
        return '版本冲突';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// 使用示例
class SyncConflictExamplePage extends ConsumerStatefulWidget {
  const SyncConflictExamplePage({super.key});

  @override
  ConsumerState<SyncConflictExamplePage> createState() => _SyncConflictExamplePageState();
}

class _SyncConflictExamplePageState extends ConsumerState<SyncConflictExamplePage> {
  @override
  void initState() {
    super.initState();
    _initializeConflictService();
  }

  Future<void> _initializeConflictService() async {
    final service = ref.read(conflictResolutionServiceProvider);
    await service.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('同步冲突管理'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            ConflictResolutionWidget(),
            // 这里可以添加更多UI组件
          ],
        ),
      ),
    );
  }
} 