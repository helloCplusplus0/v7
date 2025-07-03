/// 🎨 v7 Flutter主题系统 - 完全对齐Web端Telegram风格
/// 
/// 设计原则：
/// 1. 与Web端保持像素级一致
/// 2. Telegram风格的视觉语言
/// 3. Material 3 + Telegram美学融合
/// 4. 响应式设计支持

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // 🎯 Telegram风格色彩体系 - 与Web端完全一致
  static const Color primaryColor = Color(0xFF0088CC);      // Telegram蓝
  static const Color primaryHover = Color(0xFF006699);       // 悬停状态
  static const Color primaryLight = Color(0x190088CC);       // 浅色背景
  
  // 语义色彩
  static const Color successColor = Color(0xFF10B981);       // 成功绿
  static const Color warningColor = Color(0xFFF59E0B);       // 警告橙
  static const Color errorColor = Color(0xFFEF4444);         // 错误红
  
  // 文本色彩
  static const Color textPrimary = Color(0xFF2C3E50);        // 主文本
  static const Color textSecondary = Color(0xFF657786);      // 次要文本
  static const Color textMuted = Color(0xFF8892A0);          // 静音文本
  
  // 背景色彩
  static const Color bgPrimary = Color(0xFFFFFFFF);          // 纯白背景
  static const Color bgSecondary = Color(0xFFF8F9FA);        // 浅灰背景
  static const Color bgMuted = Color(0xFFE9ECEF);            // 静音背景
  
  // 边框色彩
  static const Color borderLight = Color(0xFFE1E8ED);        // 淡边框
  static const Color borderMedium = Color(0xFFCED4DA);       // 中等边框
  
  // 🎨 Material 3 ColorScheme - Telegram风格定制
  static ColorScheme _lightColorScheme = ColorScheme.light(
    // 主色调
    primary: primaryColor,
    onPrimary: Colors.white,
    primaryContainer: primaryLight,
    onPrimaryContainer: primaryColor,
    
    // 次要色调
    secondary: textSecondary,
    onSecondary: Colors.white,
    secondaryContainer: bgMuted,
    onSecondaryContainer: textPrimary,
    
    // 表面色
    surface: bgPrimary,
    onSurface: textPrimary,
    surfaceVariant: bgSecondary,
    onSurfaceVariant: textSecondary,
    
    // 背景色
    background: bgSecondary,
    onBackground: textPrimary,
    
    // 错误色
    error: errorColor,
    onError: Colors.white,
    errorContainer: Color(0xFFFFEDEA),
    onErrorContainer: errorColor,
    
    // 轮廓色
    outline: borderLight,
    outlineVariant: borderMedium,
    
    // 其他
    shadow: Color(0x140088CC),
    scrim: Color(0x80000000),
    inverseSurface: textPrimary,
    onInverseSurface: bgPrimary,
    inversePrimary: primaryLight,
  );

  static ColorScheme _darkColorScheme = ColorScheme.dark(
    // 主色调
    primary: primaryColor,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF004466),
    onPrimaryContainer: Color(0xFF66CCFF),
    
    // 次要色调
    secondary: Color(0xFF9AA0A6),
    onSecondary: Color(0xFF1F1F1F),
    secondaryContainer: Color(0xFF303134),
    onSecondaryContainer: Color(0xFFE8EAED),
    
    // 表面色
    surface: Color(0xFF1F1F1F),
    onSurface: Color(0xFFE8EAED),
    surfaceVariant: Color(0xFF303134),
    onSurfaceVariant: Color(0xFF9AA0A6),
    
    // 背景色
    background: Color(0xFF121212),
    onBackground: Color(0xFFE8EAED),
    
    // 错误色
    error: Color(0xFFFF6B6B),
    onError: Color(0xFF1F1F1F),
    errorContainer: Color(0xFF5F1A1A),
    onErrorContainer: Color(0xFFFFDADA),
    
    // 轮廓色
    outline: Color(0xFF5F6368),
    outlineVariant: Color(0xFF303134),
    
    // 其他
    shadow: Color(0xFF000000),
    scrim: Color(0x80000000),
    inverseSurface: Color(0xFFE8EAED),
    onInverseSurface: Color(0xFF1F1F1F),
    inversePrimary: primaryColor,
  );

  // 🔤 Telegram风格字体系统
  static const String _fontFamily = 'SF Pro Display'; // iOS风格字体
  
  static TextTheme _textTheme = const TextTheme(
    // 大标题
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      height: 1.2,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.3,
    ),
    
    // 标题
    headlineLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.4,
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.4,
    ),
    
    // 正文
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: textPrimary,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: textPrimary,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: textSecondary,
      height: 1.4,
    ),
    
    // 标签
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textPrimary,
      height: 1.4,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: textSecondary,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: textMuted,
      height: 1.3,
    ),
  );

  // 🎨 主题数据 - 亮色主题
  static ThemeData lightTheme = ThemeData(
    // 基础配置
    useMaterial3: true,
    colorScheme: _lightColorScheme,
    fontFamily: _fontFamily,
    textTheme: _textTheme,
    
    // 🏗️ 架构组件主题
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      iconTheme: IconThemeData(color: textPrimary, size: 24),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    
    // 🔘 按钮主题 - Telegram风格
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: borderLight, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    
    // 📱 卡片主题 - 黄金比例
    cardTheme: const CardThemeData(
      elevation: 0,
      color: bgPrimary,
      shadowColor: Color(0x140088CC),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: borderLight, width: 1),
      ),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    
    // 📝 输入框主题
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: bgSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: errorColor),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(color: textMuted, fontSize: 14),
    ),
    
    // 🎯 底部导航栏主题 - Telegram风格
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: bgPrimary,
      elevation: 8,
      selectedItemColor: primaryColor,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    ),
    
    // 🔧 其他组件主题
    scaffoldBackgroundColor: bgSecondary,
    dividerColor: borderLight,
    iconTheme: const IconThemeData(color: textSecondary, size: 24),
    
    // ⚡ 动画配置
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );

  // 🌙 暗色主题
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _darkColorScheme,
    fontFamily: _fontFamily,
    textTheme: _textTheme.apply(
      bodyColor: Color(0xFFE8EAED),
      displayColor: Color(0xFFE8EAED),
    ),
    scaffoldBackgroundColor: Color(0xFF121212),
    // ... 其他暗色主题配置
  );

  // 🎨 自定义组件样式
  
  /// Telegram风格切片卡片样式
  static BoxDecoration get sliceCardDecoration => BoxDecoration(
    color: bgPrimary,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: borderLight, width: 1),
    boxShadow: const [
      BoxShadow(
        color: Color(0x140088CC),
        offset: Offset(0, 2),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ],
  );
  
  /// 悬停状态切片卡片样式
  static BoxDecoration get sliceCardHoverDecoration => BoxDecoration(
    color: bgPrimary,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: primaryColor, width: 1),
    boxShadow: const [
      BoxShadow(
        color: Color(0x190088CC),
        offset: Offset(0, 4),
        blurRadius: 12,
        spreadRadius: 0,
      ),
    ],
  );
  
  /// 状态指示器颜色
  static Color getStatusColor(String status) {
    switch (status) {
      case 'healthy': return successColor;
      case 'warning': return warningColor;
      case 'error': return errorColor;
      default: return textMuted;
    }
  }
  
  /// 状态指示器图标
  static String getStatusIcon(String status) {
    switch (status) {
      case 'healthy': return '🟢';
      case 'warning': return '🟡';
      case 'error': return '🔴';
      default: return '⚪';
    }
  }
  
  /// 趋势图标
  static String getTrendIcon(String? trend) {
    switch (trend) {
      case 'up': return '📈';
      case 'down': return '📉';
      case 'warning': return '⚠️';
      default: return '➖';
    }
  }

  // 🎯 响应式设计断点
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1024;
  
  /// 获取是否为移动端
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }
  
  /// 获取是否为平板端
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }
  
  /// 获取黄金比例尺寸
  static double getGoldenRatio(double width) {
    return width / 1.618; // 黄金比例：1.618:1
  }
} 