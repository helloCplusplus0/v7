import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core imports
import 'package:v7_flutter_app/core/router/app_router.dart';
import 'package:v7_flutter_app/core/theme/app_theme.dart';
import 'package:v7_flutter_app/shared/services/service_locator.dart';
import 'package:v7_flutter_app/shared/registry/slice_registry.dart';
import 'package:v7_flutter_app/shared/connectivity/connectivity_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化服务定位器
  await ServiceLocator.instance.initialize();
  
  // 初始化切片注册中心（动态扫描）
  await sliceRegistry.initializeWithDynamicScanning();
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 激活网络集成，确保网络状态自动同步到全局应用状态
    ref.watch(networkIntegrationProvider);
    
    return MaterialApp.router(
      title: 'V7 Flutter App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}