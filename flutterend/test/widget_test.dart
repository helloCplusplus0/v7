// V7 Flutter App 简化测试
// 测试重构后的 GoRouter + PersistentShell 架构基本功能

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:v7_flutter_app/main.dart';
import 'package:v7_flutter_app/views/dashboard_view.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    // Test app initialization
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    
    // Wait for initialization
    await tester.pumpAndSettle();
    
    // Verify app loads successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Dashboard view loads', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    
    // Wait for initialization
    await tester.pumpAndSettle();
    
    // Verify dashboard elements are present
    expect(find.byType(DashboardView), findsOneWidget);
  });
}
