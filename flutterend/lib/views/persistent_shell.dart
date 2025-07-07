/// 🎨 v7 Flutter Persistent Shell - 统一网络状态指示系统
/// 
/// 设计原则：
/// 1. 统一的状态指示系统，避免信息冗余
/// 2. 智能显示策略，减少用户干扰
/// 3. 保持Telegram风格的简洁美学
/// 4. 响应式设计，适配不同设备
/// 5. 多层次状态提醒：横幅 → 浮动指示器 → 快捷按钮

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../shared/ui/network_status_banner.dart';
import '../shared/offline/offline_indicator.dart';
import '../shared/connectivity/connectivity_providers.dart';

class PersistentShell extends ConsumerStatefulWidget {
  const PersistentShell({
    super.key,
    required this.child,
  });
  
  final Widget child;

  @override
  ConsumerState<PersistentShell> createState() => _PersistentShellState();
}

class _PersistentShellState extends ConsumerState<PersistentShell> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSecondary,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // 🎯 统一网络状态横幅
          const NetworkStatusBanner(),
          
          // 🎯 主内容区域 - 不再使用Stack，避免内容遮挡
          Expanded(
            child: Column(
              children: [
                // 主内容
                Expanded(
                  child: widget.child,
                ),
                
                // 🎯 Telegram风格底部导航
                _buildTelegramBottomNavigation(),
              ],
            ),
          ),
        ],
      ),
    );
  }



  /// 🎨 Telegram风格底部导航栏
  Widget _buildTelegramBottomNavigation() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary.withOpacity(0.95),
                  border: Border(
            top: BorderSide(
              color: AppTheme.borderLight.withOpacity(0.2),
              width: 0.5,
            ),
          ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // 🔍 搜索框
                  Expanded(
                    child: _buildSearchField(),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // 🏠 Home按钮
                  _buildHomeButton(),
                  
                  const SizedBox(width: 8),
                  
                  // 📶 网络状态快捷按钮
                  _buildNetworkStatusButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 🔍 搜索框
  Widget _buildSearchField() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.borderLight.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _handleSearchChanged,
        onSubmitted: _handleSearchSubmitted,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: '搜索...',
          hintStyle: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.textSecondary,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: AppTheme.textSecondary,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  /// 🏠 Home按钮
  Widget _buildHomeButton() {
    final isCurrentlyHome = GoRouterState.of(context).uri.toString() == '/';
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isCurrentlyHome 
          ? AppTheme.primaryColor 
          : AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22),
        border: isCurrentlyHome 
          ? null 
          : Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1),
        boxShadow: isCurrentlyHome
          ? [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                offset: const Offset(0, 2),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ]
          : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleHomeNavigation,
          borderRadius: BorderRadius.circular(22),
          child: Icon(
            isCurrentlyHome ? Icons.home_rounded : Icons.home_outlined,
            color: isCurrentlyHome ? Colors.white : AppTheme.primaryColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  /// 📊 网络状态快捷按钮
  Widget _buildNetworkStatusButton() {
    return Consumer(
      builder: (context, ref, child) {
        final isConnected = ref.watch(isConnectedProvider);
        final offlineStatus = ref.watch(offlineIndicatorProvider);
        
        final (icon, color) = _getNetworkButtonStyle(isConnected, offlineStatus);
        
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/offline-detail'),
              borderRadius: BorderRadius.circular(22),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
        );
      },
    );
  }

  /// 获取网络按钮样式
  (IconData, Color) _getNetworkButtonStyle(bool isConnected, OfflineStatus offlineStatus) {
    if (!isConnected || offlineStatus.operationMode == AppOperationMode.fullyOffline) {
      return (Icons.wifi_off_rounded, Colors.red.shade600);
    }
    
    if (offlineStatus.operationMode == AppOperationMode.serviceOffline) {
      return (Icons.cloud_off_rounded, Colors.orange.shade600);
    }
    
    if (offlineStatus.operationMode == AppOperationMode.hybrid) {
      return (Icons.signal_wifi_bad_rounded, Colors.yellow.shade700);
    }
    
    return (Icons.wifi_rounded, Colors.green.shade600);
  }

  // 事件处理方法
  void _handleSearchChanged(String query) {
    setState(() {});
  }

  void _handleSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    _searchFocusNode.unfocus();
  }

  void _handleHomeNavigation() {
    HapticFeedback.lightImpact();
    context.go('/');
  }
} 