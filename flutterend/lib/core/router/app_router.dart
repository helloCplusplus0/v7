import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../views/dashboard_view.dart';
import '../../views/persistent_shell.dart';
import '../../views/offline_detail_page.dart';
import '../../shared/registry/slice_registry.dart';
import '../theme/app_theme.dart';

/// v7 Flutter 应用路由配置
/// 
/// 基于 GoRouter 实现的声明式路由系统
/// 支持切片动态路由和深度链接
class AppRouter {
  /// 获取 GoRouter 实例
  static GoRouter get router => _router;

  /// 私有路由实例
  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      // Shell路由 - PersistentShell包含所有子路由
      ShellRoute(
        builder: (context, state, child) => PersistentShell(child: child),
    routes: [
      // 主页路由
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const DashboardView(),
      ),

          // 离线状态详情页面路由
          GoRoute(
            path: '/offline-detail',
            name: 'offline-detail',
            builder: (context, state) => const OfflineDetailPage(),
          ),

          // 🎯 动态切片路由 - 基于SliceConfigs自动生成
      GoRoute(
        path: '/slice/:sliceName',
        name: 'slice',
        builder: (context, state) {
          final sliceName = state.pathParameters['sliceName'];
              if (sliceName == null) {
                return _buildNotFoundPage(context, '缺少切片名称');
              }
              
              // 从切片配置中获取Widget构建器
              final widgetBuilder = SliceConfigs.getWidgetBuilder(sliceName);
              if (widgetBuilder != null) {
                return widgetBuilder();
              }
              
              // 检查切片是否存在但未启用
              if (SliceConfigs.hasSlice(sliceName)) {
                return _buildDisabledSlicePage(context, sliceName);
              }
              
              // 切片不存在
              return _buildNotFoundPage(context, sliceName);
        },
      ),

      // 切片详情路由
      GoRoute(
        path: '/slice/:sliceName/detail/:itemId',
        name: 'slice-detail',
        builder: (context, state) {
          final sliceName = state.pathParameters['sliceName'];
          final itemId = state.pathParameters['itemId'];
          
          return Scaffold(
                         appBar: AppBar(
               title: Text('$sliceName 详情'),
               backgroundColor: AppTheme.primaryColor,
               foregroundColor: Colors.white,
             ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('切片: $sliceName'),
                  Text('项目ID: $itemId'),
                  ElevatedButton(
                    onPressed: () => context.go('/slice/$sliceName'),
                    child: const Text('返回切片'),
                  ),
                ],
              ),
            ),
          );
        },
          ),
        ],
      ),
    ],
  );

  /// 构建切片未找到页面
  static Widget _buildNotFoundPage(BuildContext context, String sliceName) {
    return Scaffold(
      appBar: AppBar(
        title: Text('未知切片: $sliceName'),
        backgroundColor: AppTheme.primaryColor,
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
              '切片 "$sliceName" 未找到',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请检查切片名称是否正确',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home),
              label: const Text('返回首页'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showAvailableSlices(context),
              child: const Text('查看可用切片'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建切片已禁用页面
  static Widget _buildDisabledSlicePage(BuildContext context, String sliceName) {
    final config = SliceConfigs.getConfig(sliceName);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(config?.displayName ?? sliceName),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.construction,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              '${config?.displayName ?? sliceName} 开发中',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (config?.description != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  config!.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home),
              label: const Text('返回首页'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示可用切片列表
  static void _showAvailableSlices(BuildContext context) {
    final enabledSlices = SliceConfigs.enabledConfigs;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('可用切片'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: enabledSlices.length,
            itemBuilder: (context, index) {
              final config = enabledSlices[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(config.iconColor),
                  child: Text(
                    config.displayName.substring(0, 1),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(config.displayName),
                subtitle: Text(config.description),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(config.routePath);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
} 