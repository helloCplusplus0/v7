/// 切片同步混入 - 为切片提供后台同步能力
/// 
/// 设计原则：
/// 1. 切片独立性：每个切片管理自己的同步逻辑
/// 2. 按需集成：切片可以选择性地启用后台同步
/// 3. 统一接口：与全局同步管理器无缝集成
/// 4. 状态透明：同步状态通过SliceSummaryContract暴露

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'slice_summary_contract.dart';
import '../sync/sync_manager.dart';
import '../sync/offline_queue.dart';
import '../types/result.dart';

/// 切片同步混入
/// 
/// 使用方法：
/// ```dart
/// class MySliceSummaryProvider extends SliceSummaryProvider with SliceSyncMixin {
///   @override
///   String get sliceName => 'my_slice';
///   
///   @override
///   SliceSyncConfig get syncConfig => const SliceSyncConfig(
///     enableBackgroundSync: true,
///     syncInterval: Duration(minutes: 10),
///     syncTypes: ['my_data_type'],
///   );
/// }
/// ```
mixin SliceSyncMixin on SliceSummaryProvider {
  /// 切片名称（必须实现）
  String get sliceName;
  
  /// 同步配置（必须实现）
  SliceSyncConfig get syncConfig;
  
  /// 同步提供者（可选实现）
  SyncProvider? get syncProvider => null;
  
  // 内部状态
  SliceSyncInfo _syncInfo = const SliceSyncInfo(status: SliceSyncStatus.idle);
  StreamController<SliceSyncInfo>? _syncStatusController;
  Timer? _syncTimer;
  bool _isInitialized = false;
  bool _isDisposed = false;

  /// 获取同步状态流
  @override
  Stream<SliceSyncInfo>? get syncStatusStream => _syncStatusController?.stream;

  /// 当前同步信息
  SliceSyncInfo get currentSyncInfo => _syncInfo;

  /// 初始化同步混入
  Future<void> initializeSync(Ref ref) async {
    if (_isInitialized || _isDisposed) return;

    _syncStatusController = StreamController<SliceSyncInfo>.broadcast();
    
    // 注册同步提供者到全局同步管理器
    if (syncProvider != null) {
      final syncManager = ref.read(syncManagerProvider);
      syncManager.registerSyncProvider(syncProvider!);
    }

    // 启动后台同步
    if (syncConfig.enableBackgroundSync) {
      await startBackgroundSync();
    }

    _isInitialized = true;
    debugPrint('🔄 切片同步已初始化: $sliceName');
  }

  /// 启动后台同步
  @override
  Future<void> startBackgroundSync() async {
    if (!syncConfig.enableBackgroundSync || _isDisposed) return;

    _scheduleNextSync();
    debugPrint('🔄 切片后台同步已启动: $sliceName');
  }

  /// 停止后台同步
  @override
  Future<void> stopBackgroundSync() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('⏹️ 切片后台同步已停止: $sliceName');
  }

  /// 手动触发同步
  @override
  Future<void> triggerSync() async {
    if (_isDisposed) return;

    await _performSync(isManual: true);
  }

  /// 调度下次同步
  void _scheduleNextSync() {
    _syncTimer?.cancel();
    
    if (!syncConfig.enableBackgroundSync || _isDisposed) return;

    _syncTimer = Timer(syncConfig.syncInterval, () {
      _performSync(isManual: false);
    });

    _updateSyncInfo(_syncInfo.copyWith(
      nextSyncTime: DateTime.now().add(syncConfig.syncInterval),
    ));
  }

  /// 执行同步
  Future<void> _performSync({required bool isManual}) async {
    if (_syncInfo.isSyncing || _isDisposed) return;

    _updateSyncInfo(_syncInfo.copyWith(
      status: SliceSyncStatus.syncing,
      syncProgress: 0.0,
      error: null,
    ));

    try {
      await _executeSyncLogic(isManual);
      
      _updateSyncInfo(_syncInfo.copyWith(
        status: SliceSyncStatus.success,
        lastSyncTime: DateTime.now(),
        syncProgress: 1.0,
        error: null,
      ));

      debugPrint('✅ 切片同步成功: $sliceName');
    } catch (e) {
      _updateSyncInfo(_syncInfo.copyWith(
        status: SliceSyncStatus.failed,
        error: e.toString(),
        syncProgress: null,
      ));

      debugPrint('❌ 切片同步失败: $sliceName - $e');
    }

    // 调度下次同步
    if (!isManual) {
      _scheduleNextSync();
    }
  }

  /// 执行具体的同步逻辑（子类可重写）
  Future<void> _executeSyncLogic(bool isManual) async {
    // 默认实现：模拟同步过程
    await Future.delayed(const Duration(seconds: 2));
    
    // 子类可以重写此方法来实现具体的同步逻辑
    await performSliceSync(isManual);
  }

  /// 执行切片特定的同步逻辑（子类实现）
  Future<void> performSliceSync(bool isManual) async {
    // 默认空实现，子类可重写
  }

  /// 更新同步信息
  void _updateSyncInfo(SliceSyncInfo newSyncInfo) {
    _syncInfo = newSyncInfo;
    _syncStatusController?.add(newSyncInfo);
  }

  /// 释放资源
  @override
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    _syncTimer?.cancel();
    _syncStatusController?.close();
    
    super.dispose();
    debugPrint('🗑️ 切片同步已释放: $sliceName');
  }
}

/// 切片同步提供者基类
/// 
/// 提供更完整的同步能力，包括数据转换、冲突处理等
abstract class SliceSyncProvider<T extends SyncItem> extends SyncProvider<T> {
  SliceSyncProvider({
    required this.sliceName,
    required this.dataType,
  });

  final String sliceName;
  final String dataType;

  @override
  String get type => dataType;

  /// 获取切片特定的本地数据
  Future<List<T>> getSliceLocalData();

  /// 获取切片特定的远程数据
  Future<List<T>> getSliceRemoteData(DateTime? since);

  /// 转换切片数据为同步项目
  T convertToSyncItem(Map<String, dynamic> data);

  /// 转换同步项目为切片数据
  Map<String, dynamic> convertFromSyncItem(T item);

  // 实现基础同步方法
  @override
  Future<List<T>> getLocalChanges() async {
    return await getSliceLocalData();
  }

  @override
  Future<List<T>> getRemoteChanges(DateTime? since) async {
    return await getSliceRemoteData(since);
  }

  @override
  Future<Result<void, String>> saveLocal(T item) async {
    try {
      final data = convertFromSyncItem(item);
      await saveSliceData(data);
      return const Result.success(null);
    } catch (e) {
      return Result.failure('保存本地数据失败: $e');
    }
  }

  /// 保存切片数据（子类实现）
  Future<void> saveSliceData(Map<String, dynamic> data);

  @override
  Future<Result<T, String>> resolveConflict(
    T localItem,
    T remoteItem,
    ConflictResolution resolution,
  ) async {
    switch (resolution) {
      case ConflictResolution.useLocal:
        return Result.success(localItem);
      case ConflictResolution.useRemote:
        return Result.success(remoteItem);
      case ConflictResolution.merge:
        return await mergeConflictItems(localItem, remoteItem);
      case ConflictResolution.skip:
        return Result.success(localItem); // 跳过时保持本地版本
    }
  }

  /// 合并冲突项目（子类可重写）
  Future<Result<T, String>> mergeConflictItems(T localItem, T remoteItem) async {
    // 默认使用远程版本
    return Result.success(remoteItem);
  }

  @override
  Future<Result<void, String>> uploadItem(T item) async {
    // 实现上传逻辑
    return const Result.success(null);
  }

  @override
  Future<Result<T, String>> downloadItem(String id) async {
    // 实现下载逻辑
    throw UnimplementedError('downloadItem not implemented');
  }

  @override
  Future<Result<void, String>> deleteLocal(String id) async {
    // 实现删除逻辑
    return const Result.success(null);
  }

  @override
  Future<void> markAsSynced(String id) async {
    // 实现标记为已同步逻辑
  }

  @override
  Future<String> getChecksum(String id) async {
    // 实现校验和逻辑
    return id.hashCode.toString();
  }
} 