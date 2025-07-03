/// 🎨 v7 Flutter Persistent Shell - 完全对齐Web端Telegram风格
/// 
/// 设计原则：
/// 1. 底部固定导航，最高层级显示
/// 2. 仅保留核心功能：搜索框 + Home按钮
/// 3. 移动端和PC端统一体验
/// 4. 背景模糊效果和Telegram美学

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';

class PersistentShell extends StatefulWidget {
  const PersistentShell({
    super.key,
    required this.child,
  });
  
  final Widget child;

  @override
  State<PersistentShell> createState() => _PersistentShellState();
}

class _PersistentShellState extends State<PersistentShell> {
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
      body: Stack(
        children: [
          // 🎯 主内容区域
          Positioned.fill(
            bottom: 80, // 为底部导航留空间
            child: widget.child,
          ),
          
          // 🎯 Telegram风格底部导航
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildTelegramBottomNavigation(),
          ),
        ],
      ),
    );
  }

  /// 🎨 Telegram风格底部导航栏
  Widget _buildTelegramBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary,
        border: const Border(
          top: BorderSide(color: AppTheme.borderLight, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, -2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: AppTheme.bgPrimary.withOpacity(0.8),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: _buildNavigationContent(),
          ),
        ),
      ),
    );
  }

  /// 🎯 导航内容
  Widget _buildNavigationContent() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Row(
        children: [
          // 🔍 搜索框
          Expanded(
            child: _buildSearchBox(),
          ),
          
          const SizedBox(width: 12),
          
          // 🏠 Home按钮
          _buildHomeButton(),
        ],
      ),
    );
  }

  /// 🔍 搜索框组件
  Widget _buildSearchBox() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: '搜索功能切片...',
          hintStyle: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.textMuted,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _handleSearchChanged('');
                  },
                  splashRadius: 16,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          isDense: true,
        ),
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        textInputAction: TextInputAction.search,
        onChanged: _handleSearchChanged,
        onSubmitted: _handleSearchSubmitted,
      ),
    );
  }

  /// 🏠 Home按钮组件
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

  /// 🔍 搜索变化处理
  void _handleSearchChanged(String query) {
    setState(() {
      // 更新UI状态以显示/隐藏清除按钮
    });
    
    // TODO: 实现搜索功能
    if (query.isNotEmpty) {
      debugPrint('🔍 搜索: $query');
    }
  }

  /// 🔍 搜索提交处理
  void _handleSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    
    // 触发触觉反馈
    HapticFeedback.lightImpact();
    
    // 失去焦点
    _searchFocusNode.unfocus();
    
    // TODO: 实现搜索导航
    debugPrint('🔍 执行搜索: $query');
    
    // 可以导航到搜索结果页面
    // context.go('/search?q=${Uri.encodeComponent(query)}');
  }

  /// 🏠 Home导航处理
  void _handleHomeNavigation() {
    final currentLocation = GoRouterState.of(context).uri.toString();
    
    if (currentLocation != '/') {
      // 触发触觉反馈
      HapticFeedback.lightImpact();
      
      // 导航到首页
      context.go('/');
      
      // 清空搜索框
      if (_searchController.text.isNotEmpty) {
        _searchController.clear();
      }
      
      // 失去搜索框焦点
      _searchFocusNode.unfocus();
    } else {
      // 如果已经在首页，触发轻微震动提示
      HapticFeedback.selectionClick();
    }
  }
} 