import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../contracts/base_contract.dart';

/// v7 架构全局信号系统
/// 基于 Riverpod 实现的响应式状态管理

/// 应用状态信号
class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier() : super(const AppState());
  
  void updateTheme(ThemeMode theme) {
    state = state.copyWith(themeMode: theme);
  }
  
  void updateLanguage(String language) {
    state = state.copyWith(language: language);
  }
  
  void updateNetworkStatus(bool isConnected) {
    state = state.copyWith(isNetworkConnected: isConnected);
  }
  
  void updateLoadingState(bool isLoading, {String? message}) {
    state = state.copyWith(
      isLoading: isLoading,
      loadingMessage: message,
    );
  }
}

/// 用户状态信号
class UserStateNotifier extends StateNotifier<UserState> {
  UserStateNotifier() : super(const UserState());
  
  void login(User user, String token) {
    state = state.copyWith(
      user: user,
      token: token,
      isAuthenticated: true,
    );
  }
  
  void logout() {
    state = const UserState();
  }
  
  void updateProfile(User user) {
    state = state.copyWith(user: user);
  }
  
  void updateToken(String token) {
    state = state.copyWith(token: token);
  }
}

/// 导航状态信号
class NavigationStateNotifier extends StateNotifier<NavigationState> {
  NavigationStateNotifier() : super(const NavigationState());
  
  void updateCurrentRoute(String route, {Map<String, dynamic>? parameters}) {
    state = state.copyWith(
      currentRoute: route,
      routeParameters: parameters,
    );
  }
  
  void addToHistory(String route) {
    final updatedHistory = [...state.routeHistory, route];
    state = state.copyWith(routeHistory: updatedHistory);
  }
  
  void clearHistory() {
    state = state.copyWith(routeHistory: []);
  }
}

/// 应用状态数据类
class AppState {
  const AppState({
    this.themeMode = ThemeMode.system,
    this.language = 'zh',
    this.isNetworkConnected = true,
    this.isLoading = false,
    this.loadingMessage,
  });
  
  final ThemeMode themeMode;
  final String language;
  final bool isNetworkConnected;
  final bool isLoading;
  final String? loadingMessage;
  
  AppState copyWith({
    ThemeMode? themeMode,
    String? language,
    bool? isNetworkConnected,
    bool? isLoading,
    String? loadingMessage,
  }) {
    return AppState(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      isNetworkConnected: isNetworkConnected ?? this.isNetworkConnected,
      isLoading: isLoading ?? this.isLoading,
      loadingMessage: loadingMessage ?? this.loadingMessage,
    );
  }
}

/// 用户状态数据类
class UserState {
  const UserState({
    this.user,
    this.token,
    this.isAuthenticated = false,
  });
  
  final User? user;
  final String? token;
  final bool isAuthenticated;
  
  UserState copyWith({
    User? user,
    String? token,
    bool? isAuthenticated,
  }) {
    return UserState(
      user: user ?? this.user,
      token: token ?? this.token,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

/// 导航状态数据类
class NavigationState {
  const NavigationState({
    this.currentRoute = '/',
    this.routeParameters,
    this.routeHistory = const [],
  });
  
  final String currentRoute;
  final Map<String, dynamic>? routeParameters;
  final List<String> routeHistory;
  
  NavigationState copyWith({
    String? currentRoute,
    Map<String, dynamic>? routeParameters,
    List<String>? routeHistory,
  }) {
    return NavigationState(
      currentRoute: currentRoute ?? this.currentRoute,
      routeParameters: routeParameters ?? this.routeParameters,
      routeHistory: routeHistory ?? this.routeHistory,
    );
  }
}

/// 全局信号提供器
final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});

final userStateProvider = StateNotifierProvider<UserStateNotifier, UserState>((ref) {
  return UserStateNotifier();
});

final navigationStateProvider = StateNotifierProvider<NavigationStateNotifier, NavigationState>((ref) {
  return NavigationStateNotifier();
});

/// 便捷的信号访问器
extension AppSignalsExtension on WidgetRef {
  /// 应用状态访问器
  AppState get appState => watch(appStateProvider);
  AppStateNotifier get appStateNotifier => read(appStateProvider.notifier);
  
  /// 用户状态访问器
  UserState get userState => watch(userStateProvider);
  UserStateNotifier get userStateNotifier => read(userStateProvider.notifier);
  
  /// 导航状态访问器
  NavigationState get navigationState => watch(navigationStateProvider);
  NavigationStateNotifier get navigationStateNotifier => read(navigationStateProvider.notifier);
} 