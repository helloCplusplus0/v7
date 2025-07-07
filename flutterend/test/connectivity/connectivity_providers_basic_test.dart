// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter_test/flutter_test.dart';

import 'package:v7_flutter_app/shared/connectivity/connectivity_providers.dart';

void main() {
  // 初始化Flutter测试环境
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ConnectivityStatus Enum', () {
    test('should have correct enum values', () {
      expect(ConnectivityStatus.online.toString(), 'ConnectivityStatus.online');
      expect(ConnectivityStatus.offline.toString(), 'ConnectivityStatus.offline');
      expect(ConnectivityStatus.limited.toString(), 'ConnectivityStatus.limited');
    });

    test('should work in switch statements', () {
      const status = ConnectivityStatus.online;
      String result = switch (status) {
        ConnectivityStatus.online => 'online',
        ConnectivityStatus.offline => 'offline',
        ConnectivityStatus.limited => 'limited',
      };
      expect(result, 'online');
    });

    test('should support all enum values in switch', () {
      final results = <String>[];
      
      for (final status in ConnectivityStatus.values) {
        final result = switch (status) {
          ConnectivityStatus.online => 'connected',
          ConnectivityStatus.offline => 'disconnected',
          ConnectivityStatus.limited => 'limited',
        };
        results.add(result);
      }
      
      expect(results, hasLength(3));
      expect(results, contains('connected'));
      expect(results, contains('disconnected'));
      expect(results, contains('limited'));
    });
  });

  group('Enum Compatibility', () {
    test('should be compatible with v7flutterules.md patterns', () {
      // 验证枚举值与示例代码兼容
      expect(ConnectivityStatus.online, isA<ConnectivityStatus>());
      expect(ConnectivityStatus.offline, isA<ConnectivityStatus>());
      expect(ConnectivityStatus.limited, isA<ConnectivityStatus>());
      
      // 验证可以在条件语句中使用
      bool isOnline(ConnectivityStatus status) {
        return status == ConnectivityStatus.online;
      }
      
      expect(isOnline(ConnectivityStatus.online), true);
      expect(isOnline(ConnectivityStatus.offline), false);
      expect(isOnline(ConnectivityStatus.limited), false);
    });

    test('should support comparison operations', () {
      const status1 = ConnectivityStatus.online;
      const status2 = ConnectivityStatus.online;
      const status3 = ConnectivityStatus.offline;
      
      expect(status1 == status2, true);
      expect(status1 == status3, false);
      expect(status1 != status3, true);
    });
  });
} 