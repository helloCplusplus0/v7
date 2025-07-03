import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:v7_flutter_app/views/dashboard_view.dart';
// 移除slice_detail_view导入 - 不再需要
import 'package:v7_flutter_app/views/persistent_shell.dart';
import 'package:v7_flutter_app/slices/demo/widgets.dart';
import 'package:v7_flutter_app/shared/contracts/slice_summary_contract.dart';

/// V7 Flutter App 路由配置
/// 使用 GoRouter 实现现代化路由管理，解决底部header跳动问题
class AppRouter {
  // 全局导航键
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  /// 路由配置
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    
    routes: [
      // 持久化Shell路由 - 解决底部header跳动问题
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return PersistentShell(child: child);
        },
        routes: [
          // 🏠 主页 - 瀑布流仪表板
          GoRoute(
            path: '/',
            name: 'dashboard',
            builder: (context, state) => const DashboardView(),
          ),
          
          // 🎯 Demo切片 - 任务管理
          GoRoute(
            path: '/slice/demo',
            name: 'demo_slice',
            builder: (context, state) => const TasksWidget(),
          ),
        ],
      ),
      
      // 📌 注意：移除了slice-detail路由
      // 在v7架构中，开发中切片通过dialog提示，不需要单独页面
    ],
    
    // 错误页面
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('页面未找到'),
        backgroundColor: const Color(0xFF0088CC),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              '页面不存在',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '请检查地址是否正确',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => const DashboardView(),
              icon: const Icon(Icons.home),
              label: const Text('返回首页'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0088CC),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
} 