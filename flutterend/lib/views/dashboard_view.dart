/// 🎨 v7 Flutter Dashboard - 极简切片展示
/// 
/// 设计原则：
/// 1. 功能切片为唯一焦点
/// 2. 移除所有非必要UI元素
/// 3. 采用黄金比例设计
/// 4. 简洁直接的信息展示

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../shared/registry/slice_registry.dart';
import '../shared/contracts/slice_summary_contract.dart';
import '../shared/widgets/slice_card.dart';

// Provider for slice registry
final sliceRegistryProvider = Provider<SliceRegistry>((ref) => sliceRegistry);

// 刷新状态 Provider
final isRefreshingProvider = StateProvider<bool>((ref) => false);

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> 
    with TickerProviderStateMixin {
  
  late AnimationController _refreshController;
  late Animation<double> _refreshAnimation;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _refreshAnimation = CurvedAnimation(
      parent: _refreshController,
      curve: Curves.elasticOut,
    );
    
    // 初始加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sliceRegistry = ref.watch(sliceRegistryProvider);
    final isRefreshing = ref.watch(isRefreshingProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.bgSecondary,
      body: RefreshIndicator(
        onRefresh: _handlePullToRefresh,
        color: AppTheme.primaryColor,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // 🎯 顶部安全区域间距
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.top + 20,
              ),
            ),
            
            // 🎯 切片瀑布流 - 性能优化版本
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  childAspectRatio: 1.618, // 黄金比例
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final slices = sliceRegistry.getAllRegistrations();
                    if (index >= slices.length) return null;
                    
                    final slice = slices[index];
                    
                    // ✅ 优化4：简化卡片构建，移除复杂的FutureBuilder
                    return OptimizedSliceCard(
                      slice: slice,
                      onTap: () => _handleSliceNavigation(context, slice),
                      index: index,
                    );
                  },
                  childCount: sliceRegistry.getAllRegistrations().length,
                ),
              ),
            ),
            
            // 底部间距（为底部导航留空间）
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎯 数据刷新逻辑 - 性能优化版
  Future<void> _refreshData() async {
    if (ref.read(isRefreshingProvider)) return;
    
    ref.read(isRefreshingProvider.notifier).state = true;
    _refreshController.forward();
    
    try {
      final sliceRegistry = ref.read(sliceRegistryProvider);
      
      // 刷新所有切片的摘要数据
      await sliceRegistry.refreshAllSummaryData();
      
      // ✅ 优化5：移除模拟延迟，提高响应速度
      // 移除: await Future.delayed(const Duration(milliseconds: 500));
      
      // 触发UI重建
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('❌ 刷新数据失败: $error');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刷新数据失败: $error'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        ref.read(isRefreshingProvider.notifier).state = false;
        _refreshController.reverse();
      }
    }
  }

  /// 🎯 下拉刷新处理
  Future<void> _handlePullToRefresh() async {
    await _refreshData();
  }

  /// 🎯 获取摘要数据
  Future<SliceSummaryContract?> _getSummaryData(SliceRegistration slice) async {
    try {
      return await sliceRegistry.getSummaryData(slice.name);
    } catch (e) {
      return null;
    }
  }

  /// 🎯 响应式列数计算
  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 1;           // 手机：1列
    if (width < 900) return 2;           // 平板：2列
    if (width < 1200) return 3;          // 小屏幕：3列
    return 4;                            // 大屏幕：4列
  }

  /// 🎯 极速优化的切片导航处理 - 移除性能瓶颈
  void _handleSliceNavigation(BuildContext context, SliceRegistration slice) {
    if (slice.category == '已实现') {
      // ✅ 优化1：立即响应，移除等待时间
      // 移除 await _refreshData() - 不在导航时刷新数据
      
      // ✅ 优化2：使用简单直接的导航，移除复杂动画
      context.go(slice.routePath);
      
      // ✅ 优化3：后台异步刷新数据（不阻塞导航）
      _refreshDataInBackground();
    } else {
      // 显示开发中提示
      _showDevelopmentDialog(context, slice);
    }
  }

  /// 🎯 后台数据刷新 - 不阻塞UI
  void _refreshDataInBackground() {
    // 异步执行，不影响用户体验
    Future.microtask(() async {
      try {
        final sliceRegistry = ref.read(sliceRegistryProvider);
        await sliceRegistry.refreshAllSummaryData();
        if (mounted) {
          setState(() {});
        }
      } catch (error) {
        debugPrint('后台刷新失败: $error');
      }
    });
  }

  /// 🎯 开发中对话框
  void _showDevelopmentDialog(BuildContext context, SliceRegistration slice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('🚧'),
            const SizedBox(width: 8),
            Text(
              '功能开发中',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          '${slice.displayName} 功能正在开发中，敬请期待！',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

/// 🎨 性能优化的切片卡片 - 移除不必要的动画
class OptimizedSliceCard extends StatelessWidget {
  const OptimizedSliceCard({
    super.key,
    required this.slice,
    required this.onTap,
    required this.index,
  });

  final SliceRegistration slice;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TelegramSliceCard(
      slice: slice,
      summary: null, // ✅ 优化：移除摘要数据获取，减少构建延迟
      onTap: onTap,
    );
  }
}

/// 🎨 带动画的切片卡片包装器
class AnimatedSliceCard extends StatefulWidget {
  const AnimatedSliceCard({
    super.key,
    required this.slice,
    required this.onTap,
    required this.index,
    this.summary,
  });

  final SliceRegistration slice;
  final SliceSummaryContract? summary;
  final VoidCallback onTap;
  final int index;

  @override
  State<AnimatedSliceCard> createState() => _AnimatedSliceCardState();
}

class _AnimatedSliceCardState extends State<AnimatedSliceCard>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: Duration(milliseconds: 300 + (widget.index * 100)),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.fastOutSlowIn,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeIn,
    ));
    
    // 延迟启动动画
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) {
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: TelegramSliceCard(
          slice: widget.slice,
          summary: widget.summary,
          onTap: widget.onTap,
        ),
      ),
    );
  }
} 