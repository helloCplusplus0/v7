import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v7_flutter_app/shared/signals/app_signals.dart';
import 'package:v7_flutter_app/shared/types/user.dart';

void main() {
  group('AppSignals (Riverpod StateNotifiers)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('AppStateNotifier', () {
      test('初始状态应该正确', () {
        final appState = container.read(appStateProvider);
        
        expect(appState.themeMode, equals(ThemeMode.system));
        expect(appState.language, equals('zh'));
        expect(appState.isNetworkConnected, isTrue);
        expect(appState.isLoading, isFalse);
        expect(appState.loadingMessage, isNull);
      });

      test('updateTheme应该更新主题模式', () {
        final notifier = container.read(appStateProvider.notifier);
        
        notifier.updateTheme(ThemeMode.dark);
        
        final appState = container.read(appStateProvider);
        expect(appState.themeMode, equals(ThemeMode.dark));
      });

      test('updateLanguage应该更新语言设置', () {
        final notifier = container.read(appStateProvider.notifier);
        
        notifier.updateLanguage('en');
        
        final appState = container.read(appStateProvider);
        expect(appState.language, equals('en'));
      });

      test('updateNetworkStatus应该更新网络状态', () {
        final notifier = container.read(appStateProvider.notifier);
        
        notifier.updateNetworkStatus(false);
        
        final appState = container.read(appStateProvider);
        expect(appState.isNetworkConnected, isFalse);
      });

      test('updateLoadingState应该更新加载状态', () {
        final notifier = container.read(appStateProvider.notifier);
        
        notifier.updateLoadingState(true, message: '加载中...');
        
        final appState = container.read(appStateProvider);
        expect(appState.isLoading, isTrue);
        expect(appState.loadingMessage, equals('加载中...'));
        
        notifier.updateLoadingState(false);
        
        final updatedState = container.read(appStateProvider);
        expect(updatedState.isLoading, isFalse);
      });
    });

    group('UserStateNotifier', () {
      test('初始状态应该正确', () {
        final userState = container.read(userStateProvider);
        
        expect(userState.user, isNull);
        expect(userState.token, isNull);
        expect(userState.isAuthenticated, isFalse);
      });

      test('login应该设置用户信息和认证状态', () {
        final notifier = container.read(userStateProvider.notifier);
        const testUser = User(
          id: '1',
          name: 'Test User',
          email: 'test@example.com',
        );
        const testToken = 'test-token-123';
        
        notifier.login(testUser, testToken);
        
        final userState = container.read(userStateProvider);
        expect(userState.user, equals(testUser));
        expect(userState.token, equals(testToken));
        expect(userState.isAuthenticated, isTrue);
      });

      test('logout应该清除所有用户信息', () {
        final notifier = container.read(userStateProvider.notifier);
        const testUser = User(
          id: '1',
          name: 'Test User',
          email: 'test@example.com',
        );
        
        // 先登录
        notifier.login(testUser, 'test-token');
        expect(container.read(userStateProvider).isAuthenticated, isTrue);
        
        // 再登出
        notifier.logout();
        
        final userState = container.read(userStateProvider);
        expect(userState.user, isNull);
        expect(userState.token, isNull);
        expect(userState.isAuthenticated, isFalse);
      });

      test('updateProfile应该更新用户信息', () {
        final notifier = container.read(userStateProvider.notifier);
        const initialUser = User(
          id: '1',
          name: 'Initial User',
          email: 'initial@example.com',
        );
        const updatedUser = User(
          id: '1',
          name: 'Updated User',
          email: 'updated@example.com',
        );
        
        notifier.login(initialUser, 'test-token');
        notifier.updateProfile(updatedUser);
        
        final userState = container.read(userStateProvider);
        expect(userState.user, equals(updatedUser));
        expect(userState.isAuthenticated, isTrue); // 应该保持认证状态
      });

      test('updateToken应该更新令牌', () {
        final notifier = container.read(userStateProvider.notifier);
        const testUser = User(
          id: '1',
          name: 'Test User',
          email: 'test@example.com',
        );
        
        notifier.login(testUser, 'old-token');
        notifier.updateToken('new-token');
        
        final userState = container.read(userStateProvider);
        expect(userState.token, equals('new-token'));
        expect(userState.user, equals(testUser)); // 用户信息应该保持不变
      });
    });

    group('NavigationStateNotifier', () {
      test('初始状态应该正确', () {
        final navState = container.read(navigationStateProvider);
        
        expect(navState.currentRoute, equals('/'));
        expect(navState.routeParameters, isNull);
        expect(navState.routeHistory, isEmpty);
      });

      test('updateCurrentRoute应该更新当前路由', () {
        final notifier = container.read(navigationStateProvider.notifier);
        
        notifier.updateCurrentRoute('/home', parameters: {'id': '123'});
        
        final navState = container.read(navigationStateProvider);
        expect(navState.currentRoute, equals('/home'));
        expect(navState.routeParameters, equals({'id': '123'}));
      });

      test('addToHistory应该添加路由到历史记录', () {
        final notifier = container.read(navigationStateProvider.notifier);
        
        notifier.addToHistory('/home');
        notifier.addToHistory('/profile');
        
        final navState = container.read(navigationStateProvider);
        expect(navState.routeHistory, equals(['/home', '/profile']));
      });

      test('clearHistory应该清空路由历史', () {
        final notifier = container.read(navigationStateProvider.notifier);
        
        notifier.addToHistory('/home');
        notifier.addToHistory('/profile');
        expect(container.read(navigationStateProvider).routeHistory, isNotEmpty);
        
        notifier.clearHistory();
        
        final navState = container.read(navigationStateProvider);
        expect(navState.routeHistory, isEmpty);
      });
    });

    group('Data Classes', () {
      test('AppState copyWith应该正确工作', () {
        const initialState = AppState();
        final updatedState = initialState.copyWith(
          themeMode: ThemeMode.dark,
          language: 'en',
        );
        
        expect(updatedState.themeMode, equals(ThemeMode.dark));
        expect(updatedState.language, equals('en'));
        expect(updatedState.isNetworkConnected, equals(initialState.isNetworkConnected));
        expect(updatedState.isLoading, equals(initialState.isLoading));
      });

      test('UserState copyWith应该正确工作', () {
        const initialState = UserState();
        const testUser = User(
          id: '1',
          name: 'Test User',
          email: 'test@example.com',
        );
        final updatedState = initialState.copyWith(
          user: testUser,
          isAuthenticated: true,
        );
        
        expect(updatedState.user, equals(testUser));
        expect(updatedState.isAuthenticated, isTrue);
        expect(updatedState.token, equals(initialState.token));
      });

      test('NavigationState copyWith应该正确工作', () {
        const initialState = NavigationState();
        final updatedState = initialState.copyWith(
          currentRoute: '/home',
          routeHistory: ['/splash', '/home'],
        );
        
        expect(updatedState.currentRoute, equals('/home'));
        expect(updatedState.routeHistory, equals(['/splash', '/home']));
        expect(updatedState.routeParameters, equals(initialState.routeParameters));
      });
    });

    group('Provider Integration', () {
      test('providers应该返回正确的notifier类型', () {
        final appNotifier = container.read(appStateProvider.notifier);
        final userNotifier = container.read(userStateProvider.notifier);
        final navNotifier = container.read(navigationStateProvider.notifier);
        
        expect(appNotifier, isA<AppStateNotifier>());
        expect(userNotifier, isA<UserStateNotifier>());
        expect(navNotifier, isA<NavigationStateNotifier>());
      });

      test('状态变化应该被provider正确跟踪', () {
        final notifier = container.read(userStateProvider.notifier);
        const testUser = User(
          id: '1',
          name: 'Test User',
          email: 'test@example.com',
        );
        
        // 监听状态变化
        bool stateChanged = false;
        container.listen(userStateProvider, (previous, next) {
          stateChanged = true;
        });
        
        notifier.login(testUser, 'test-token');
        
        expect(stateChanged, isTrue);
        expect(container.read(userStateProvider).user, equals(testUser));
             });
     });
   });
 } 