// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../types/result.dart';
import '../events/events.dart';
import '../contracts/base_contract.dart';
import 'sync_manager.dart';

/// 冲突解决策略接口
abstract class ConflictResolutionStrategy {
  /// 策略名称
  String get name;
  
  /// 解决冲突
  Future<Result<SyncItem?, String>> resolve(
    SyncConflict conflict,
    Map<String, dynamic> context,
  );
  
  /// 是否适用于指定冲突类型
  bool canHandle(ConflictType conflictType);
  
  /// 策略优先级 (数值越小优先级越高)
  int get priority;
}

/// 冲突解决上下文
@immutable
class ConflictResolutionContext {
  const ConflictResolutionContext({
    required this.userId,
    required this.deviceId,
    required this.timestamp,
    this.metadata = const {},
    this.customOptions = const {},
  });

  final String userId;
  final String deviceId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> customOptions;

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'device_id': deviceId,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
    'custom_options': customOptions,
  };

  ConflictResolutionContext copyWith({
    String? userId,
    String? deviceId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? customOptions,
  }) {
    return ConflictResolutionContext(
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      customOptions: customOptions ?? this.customOptions,
    );
  }
}

/// 冲突解决结果
@immutable
class ConflictResolutionResult {
  const ConflictResolutionResult({
    required this.conflictId,
    required this.resolution,
    required this.resolvedItem,
    required this.strategy,
    required this.timestamp,
    this.metadata = const {},
  });

  final String conflictId;
  final ConflictResolution resolution;
  final SyncItem? resolvedItem;
  final String strategy;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
    'conflict_id': conflictId,
    'resolution': resolution.name,
    'resolved_item': resolvedItem?.toJson(),
    'strategy': strategy,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };
}

/// 冲突解决器接口
abstract class ConflictResolver implements BaseContract {
  /// 解决冲突
  Future<Result<ConflictResolutionResult, String>> resolveConflict(
    SyncConflict conflict,
    ConflictResolutionContext context,
  );

  /// 批量解决冲突
  Future<List<Result<ConflictResolutionResult, String>>> resolveConflicts(
    List<SyncConflict> conflicts,
    ConflictResolutionContext context,
  );

  /// 注册冲突解决策略
  void registerStrategy(ConflictResolutionStrategy strategy);

  /// 取消注册策略
  void unregisterStrategy(String strategyName);

  /// 获取所有策略
  List<ConflictResolutionStrategy> getStrategies();

  /// 获取适用策略
  List<ConflictResolutionStrategy> getApplicableStrategies(
    ConflictType conflictType,
  );

  /// 设置默认策略
  void setDefaultStrategy(ConflictResolutionStrategy strategy);

  /// 启用自动解决
  void enableAutoResolution(bool enabled);

  /// 清理历史记录
  Future<void> clearHistory();

  /// 获取解决历史
  Future<List<ConflictResolutionResult>> getResolutionHistory({
    String? conflictType,
    DateTime? since,
    int? limit,
  });
}

/// 默认冲突解决器实现
class DefaultConflictResolver implements ConflictResolver {
  DefaultConflictResolver({
    ConflictResolutionStrategy? defaultStrategy,
    bool autoResolutionEnabled = false,
  }) : _autoResolutionEnabled = autoResolutionEnabled {
    
    // 注册内置策略
    _registerBuiltinStrategies();
    
    // 设置默认策略
    if (defaultStrategy != null) {
      setDefaultStrategy(defaultStrategy);
    } else if (_strategies.isNotEmpty) {
      _defaultStrategy = _strategies.values.first;
    }
  }

  final Map<String, ConflictResolutionStrategy> _strategies = {};
  final List<ConflictResolutionResult> _resolutionHistory = [];
  ConflictResolutionStrategy? _defaultStrategy;
  bool _autoResolutionEnabled;

  @override
  String get contractName => 'ConflictResolver';

  @override
  String get contractVersion => '1.0.0';

  @override
  bool get isInitialized => _strategies.isNotEmpty;

  @override
  bool get isDisposed => false;

  @override
  Future<AppResult<void>> initialize() async {
    return const Result.success(null);
  }

  @override
  Future<void> dispose() async {
    _strategies.clear();
    _resolutionHistory.clear();
  }

  // 保留原有的metadata getter用于向后兼容
  Map<String, dynamic> get metadata => {
    'strategies_count': _strategies.length,
    'auto_resolution_enabled': _autoResolutionEnabled,
    'default_strategy': _defaultStrategy?.name,
    'resolution_history_count': _resolutionHistory.length,
  };

  @override
  Future<Result<ConflictResolutionResult, String>> resolveConflict(
    SyncConflict conflict,
    ConflictResolutionContext context,
  ) async {
    try {
      // 获取适用的策略
      final applicableStrategies = getApplicableStrategies(conflict.conflictType);
      
      if (applicableStrategies.isEmpty) {
        return Result.failure('没有找到适用于冲突类型 ${conflict.conflictType.name} 的解决策略');
      }

      // 按优先级排序
      applicableStrategies.sort((a, b) => a.priority.compareTo(b.priority));

      // 尝试使用策略解决冲突
      for (final strategy in applicableStrategies) {
        final strategyResult = await strategy.resolve(
          conflict,
          context.toJson(),
        );

                 if (strategyResult.isSuccess) {
           final resolvedItem = strategyResult.valueOrNull;
          
          // 确定解决方案类型
          final resolution = _determineResolution(
            conflict,
            resolvedItem,
            strategy,
          );

          final result = ConflictResolutionResult(
            conflictId: conflict.id,
            resolution: resolution,
            resolvedItem: resolvedItem,
            strategy: strategy.name,
            timestamp: DateTime.now(),
            metadata: {
              'conflict_type': conflict.conflictType.name,
              'strategy_priority': strategy.priority,
              'context': context.toJson(),
            },
          );

          // 记录到历史
          _resolutionHistory.add(result);

          // 发送事件
          _emitResolutionEvent(conflict, result);

          return Result.success(result);
        }
      }

      return Result.failure('所有策略都无法解决此冲突');
    } catch (e) {
      return Result.failure('解决冲突时发生错误: $e');
    }
  }

  @override
  Future<List<Result<ConflictResolutionResult, String>>> resolveConflicts(
    List<SyncConflict> conflicts,
    ConflictResolutionContext context,
  ) async {
    final results = <Result<ConflictResolutionResult, String>>[];

    for (final conflict in conflicts) {
      final result = await resolveConflict(conflict, context);
      results.add(result);
    }

    return results;
  }

  @override
  void registerStrategy(ConflictResolutionStrategy strategy) {
    _strategies[strategy.name] = strategy;
    
    // 如果是第一个策略，设为默认策略
    _defaultStrategy ??= strategy;
    
    debugPrint('已注册冲突解决策略: ${strategy.name}');
  }

  @override
  void unregisterStrategy(String strategyName) {
    final strategy = _strategies.remove(strategyName);
    
    if (strategy != null) {
      // 如果移除的是默认策略，选择新的默认策略
      if (_defaultStrategy == strategy && _strategies.isNotEmpty) {
        _defaultStrategy = _strategies.values.first;
      }
      
      debugPrint('已移除冲突解决策略: $strategyName');
    }
  }

  @override
  List<ConflictResolutionStrategy> getStrategies() {
    return _strategies.values.toList();
  }

  @override
  List<ConflictResolutionStrategy> getApplicableStrategies(
    ConflictType conflictType,
  ) {
    return _strategies.values
        .where((strategy) => strategy.canHandle(conflictType))
        .toList();
  }

  @override
  void setDefaultStrategy(ConflictResolutionStrategy strategy) {
    if (!_strategies.containsKey(strategy.name)) {
      registerStrategy(strategy);
    }
    _defaultStrategy = strategy;
    debugPrint('设置默认冲突解决策略: ${strategy.name}');
  }

  @override
  void enableAutoResolution(bool enabled) {
    _autoResolutionEnabled = enabled;
    debugPrint('自动冲突解决: ${enabled ? '已启用' : '已禁用'}');
  }

  @override
  Future<void> clearHistory() async {
    _resolutionHistory.clear();
    debugPrint('已清理冲突解决历史记录');
  }

  @override
  Future<List<ConflictResolutionResult>> getResolutionHistory({
    String? conflictType,
    DateTime? since,
    int? limit,
  }) async {
    var filtered = _resolutionHistory.toList();

    // 按冲突类型过滤
    if (conflictType != null) {
      filtered = filtered.where((result) => 
          result.metadata['conflict_type'] == conflictType).toList();
    }

    // 按时间过滤
    if (since != null) {
      filtered = filtered.where((result) => 
          result.timestamp.isAfter(since)).toList();
    }

    // 按时间倒序排列
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // 限制数量
    if (limit != null && limit > 0) {
      filtered = filtered.take(limit).toList();
    }

    return filtered;
  }

  /// 注册内置策略
  void _registerBuiltinStrategies() {
    registerStrategy(LastModifiedWinsStrategy());
    registerStrategy(ClientWinsStrategy());
    registerStrategy(ServerWinsStrategy());
    registerStrategy(MergeStrategy());
    registerStrategy(ManualResolutionStrategy());
  }

  /// 确定解决方案类型
  ConflictResolution _determineResolution(
    SyncConflict conflict,
    SyncItem? resolvedItem,
    ConflictResolutionStrategy strategy,
  ) {
    if (resolvedItem == null) {
      return ConflictResolution.skip;
    }

    // 比较resolved item和原始items
    if (resolvedItem.id == conflict.localItem.id &&
        resolvedItem.checksum == conflict.localItem.checksum) {
      return ConflictResolution.useLocal;
    }

    if (resolvedItem.id == conflict.remoteItem.id &&
        resolvedItem.checksum == conflict.remoteItem.checksum) {
      return ConflictResolution.useRemote;
    }

    return ConflictResolution.merge;
  }

  /// 发送解决事件
  void _emitResolutionEvent(
    SyncConflict conflict,
    ConflictResolutionResult result,
  ) {
    final event = ConflictResolvedEvent(
      conflict: conflict,
      result: result,
    );

    // 通过事件总线发送事件
    // 这里假设有全局事件总线，实际实现中需要注入
    debugPrint('冲突已解决: ${conflict.id} -> ${result.resolution.name}');
  }
}

/// 最后修改时间优先策略
class LastModifiedWinsStrategy implements ConflictResolutionStrategy {
  @override
  String get name => 'LastModifiedWins';

  @override
  int get priority => 1;

  @override
  bool canHandle(ConflictType conflictType) {
    return conflictType == ConflictType.dataConflict ||
           conflictType == ConflictType.versionConflict;
  }

  @override
  Future<Result<SyncItem?, String>> resolve(
    SyncConflict conflict,
    Map<String, dynamic> context,
  ) async {
    try {
      final localTime = conflict.localItem.lastModified;
      final remoteTime = conflict.remoteItem.lastModified;

      // 选择最新修改的版本
      final winner = localTime.isAfter(remoteTime) 
          ? conflict.localItem 
          : conflict.remoteItem;

      return Result.success(winner);
    } catch (e) {
      return Result.failure('LastModifiedWins策略执行失败: $e');
    }
  }
}

/// 客户端优先策略
class ClientWinsStrategy implements ConflictResolutionStrategy {
  @override
  String get name => 'ClientWins';

  @override
  int get priority => 2;

  @override
  bool canHandle(ConflictType conflictType) {
    return true; // 适用于所有冲突类型
  }

  @override
  Future<Result<SyncItem?, String>> resolve(
    SyncConflict conflict,
    Map<String, dynamic> context,
  ) async {
    return Result.success(conflict.localItem);
  }
}

/// 服务端优先策略
class ServerWinsStrategy implements ConflictResolutionStrategy {
  @override
  String get name => 'ServerWins';

  @override
  int get priority => 3;

  @override
  bool canHandle(ConflictType conflictType) {
    return true; // 适用于所有冲突类型
  }

  @override
  Future<Result<SyncItem?, String>> resolve(
    SyncConflict conflict,
    Map<String, dynamic> context,
  ) async {
    return Result.success(conflict.remoteItem);
  }
}

/// 合并策略 (简化实现)
class MergeStrategy implements ConflictResolutionStrategy {
  @override
  String get name => 'Merge';

  @override
  int get priority => 4;

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
      // 简化的合并逻辑 - 实际实现需要根据具体数据类型定制
      final localData = conflict.localItem.toJson();
      final remoteData = conflict.remoteItem.toJson();
      
      // 基础合并策略：保留本地修改，补充远程新增字段
      final mergedData = Map<String, dynamic>.from(localData);
      
      for (final entry in remoteData.entries) {
        if (!mergedData.containsKey(entry.key)) {
          mergedData[entry.key] = entry.value;
        }
      }

      // 创建合并后的项目 (这里需要具体的SyncItem实现)
      // 暂时返回本地版本作为占位符
      return Result.success(conflict.localItem);
    } catch (e) {
      return Result.failure('合并策略执行失败: $e');
    }
  }
}

/// 手动解决策略
class ManualResolutionStrategy implements ConflictResolutionStrategy {
  @override
  String get name => 'Manual';

  @override
  int get priority => 10; // 最低优先级

  @override
  bool canHandle(ConflictType conflictType) {
    return true; // 适用于所有冲突类型，作为后备方案
  }

  @override
  Future<Result<SyncItem?, String>> resolve(
    SyncConflict conflict,
    Map<String, dynamic> context,
  ) async {
    // 手动解决策略不自动处理，返回null表示需要人工干预
    return Result.failure('需要手动解决此冲突');
  }
}

/// 冲突解决事件
class ConflictResolvedEvent extends AppEvent {
  const ConflictResolvedEvent({
    required this.conflict,
    required this.result,
  });

  final SyncConflict conflict;
  final ConflictResolutionResult result;

  @override
  String get type => 'conflict_resolved';

  @override
  Map<String, dynamic> toJson() => {
    'conflict': {
      'id': conflict.id,
      'type': conflict.type,
      'conflict_type': conflict.conflictType.name,
    },
    'result': result.toJson(),
  };
}

/// 冲突解决器工厂
class ConflictResolverFactory {
  static ConflictResolver create({
    ConflictResolutionStrategy? defaultStrategy,
    bool autoResolutionEnabled = false,
    List<ConflictResolutionStrategy>? customStrategies,
  }) {
    final resolver = DefaultConflictResolver(
      defaultStrategy: defaultStrategy,
      autoResolutionEnabled: autoResolutionEnabled,
    );

    // 注册自定义策略
    if (customStrategies != null) {
      for (final strategy in customStrategies) {
        resolver.registerStrategy(strategy);
      }
    }

    return resolver;
  }
} 