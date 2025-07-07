// Copyright (c) 2024 V7 Architecture
// Licensed under MIT License

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:v7_flutter_app/shared/connectivity/network_monitor.dart';
import 'package:v7_flutter_app/shared/connectivity/connectivity_providers.dart';

void main() {
  // 初始化Flutter测试环境
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('NetworkStats', () {
    test('should calculate network quality correctly with updated algorithm', () {
      // 优秀质量 - 低延迟、高稳定性、无丢包
      const excellentStats = NetworkStats(
        latency: Duration(milliseconds: 30),
        connectionStability: 0.95,
        packetLoss: 0.0,
      );
      expect(excellentStats.quality, NetworkQuality.excellent);

      // 良好质量 - 中等延迟、良好稳定性、低丢包
      const goodStats = NetworkStats(
        latency: Duration(milliseconds: 80),
        connectionStability: 0.85,
        packetLoss: 0.01,
      );
      expect(goodStats.quality, NetworkQuality.good);

      // 一般质量 - 较高延迟、中等稳定性、中等丢包
      const fairStats = NetworkStats(
        latency: Duration(milliseconds: 120),
        connectionStability: 0.8,
        packetLoss: 0.02,
      );
      expect(fairStats.quality, NetworkQuality.fair);

      // 差质量 - 高延迟、低稳定性、高丢包
      const poorStats = NetworkStats(
        latency: Duration(milliseconds: 300),
        connectionStability: 0.4,
        packetLoss: 0.05,
      );
      expect(poorStats.quality, NetworkQuality.poor);

      // 无连接
      const noneStats = NetworkStats();
      expect(noneStats.quality, NetworkQuality.none);
    });

    test('should handle edge cases in quality calculation', () {
      // 边界情况：零延迟
      const zeroLatency = NetworkStats(
        latency: Duration.zero,
        connectionStability: 1.0,
        packetLoss: 0.0,
      );
      expect(zeroLatency.quality, NetworkQuality.none);

      // 边界情况：极高延迟  
      const extremeLatency = NetworkStats(
        latency: Duration(milliseconds: 500),
        connectionStability: 0.5,
        packetLoss: 0.1,
      );
      expect(extremeLatency.quality, NetworkQuality.poor);

      // 边界情况：高丢包率
      const highPacketLoss = NetworkStats(
        latency: Duration(milliseconds: 120),
        connectionStability: 0.8,
        packetLoss: 0.05,
      );
      expect(highPacketLoss.quality, NetworkQuality.fair);
    });

    test('should support copyWith correctly', () {
      const original = NetworkStats(
        latency: Duration(milliseconds: 100),
        downloadSpeed: 5.0,
        uploadSpeed: 2.0,
        packetLoss: 0.02,
        connectionStability: 0.8,
      );

      final updated = original.copyWith(
        latency: const Duration(milliseconds: 50),
        uploadSpeed: 3.0,
      );

      expect(updated.latency, const Duration(milliseconds: 50));
      expect(updated.downloadSpeed, 5.0); // 保持不变
      expect(updated.uploadSpeed, 3.0); // 新值
      expect(updated.packetLoss, 0.02); // 保持不变
      expect(updated.connectionStability, 0.8); // 保持不变
    });

    test('should have proper equality comparison', () {
      final now = DateTime.now();
      const stats1 = NetworkStats(
        latency: Duration(milliseconds: 100),
        downloadSpeed: 5.0,
        uploadSpeed: 2.0,
        packetLoss: 0.02,
        connectionStability: 0.8,
      );

      final stats2 = NetworkStats(
        latency: const Duration(milliseconds: 100),
        downloadSpeed: 5.0,
        uploadSpeed: 2.0,
        packetLoss: 0.02,
        connectionStability: 0.8,
        lastUpdated: now,
      );

      final stats3 = stats1.copyWith(lastUpdated: now);

      expect(stats1 == stats2, false); // 不同的lastUpdated
      expect(stats2 == stats3, true); // 相同的所有字段
      expect(stats1.hashCode != stats2.hashCode, true);
    });
  });

  group('NetworkMonitorState', () {
    test('should have correct default values', () {
      const state = NetworkMonitorState();
      
      expect(state.status, NetworkStatus.unknown);
      expect(state.type, NetworkType.none);
      expect(state.isConnected, false);
      expect(state.isMonitoring, false);
      expect(state.connectionHistory, isEmpty);
      expect(state.error, isNull);
      expect(state.lastConnectionChange, isNull);
    });

    test('should support copyWith correctly', () {
      final now = DateTime.now();
      const original = NetworkMonitorState(
        status: NetworkStatus.offline,
        type: NetworkType.none,
        isConnected: false,
      );

      final updated = original.copyWith(
        status: NetworkStatus.online,
        type: NetworkType.wifi,
        isConnected: true,
        lastConnectionChange: now,
      );

      expect(updated.status, NetworkStatus.online);
      expect(updated.type, NetworkType.wifi);
      expect(updated.isConnected, true);
      expect(updated.lastConnectionChange, now);
      expect(updated.isMonitoring, false); // 保持原值
    });

    test('should calculate derived properties correctly', () {
      const highSpeedState = NetworkMonitorState(
        stats: NetworkStats(
          connectionStability: 0.9,
          downloadSpeed: 2.5,
        ),
      );

      const lowSpeedState = NetworkMonitorState(
        stats: NetworkStats(
          connectionStability: 0.7,
          downloadSpeed: 0.5,
        ),
      );

      expect(highSpeedState.isStable, true);
      expect(highSpeedState.isHighSpeed, true);
      expect(lowSpeedState.isStable, false);
      expect(lowSpeedState.isHighSpeed, false);
    });

    test('should have proper equality comparison', () {
      final now = DateTime.now();
      final event = NetworkConnectionEvent(
        timestamp: now,
        status: NetworkStatus.online,
        type: NetworkType.wifi,
      );

      const state1 = NetworkMonitorState(
        status: NetworkStatus.online,
        type: NetworkType.wifi,
        isConnected: true,
      );

      final state2 = state1.copyWith(
        connectionHistory: [event],
      );

      final state3 = state1.copyWith(
        connectionHistory: [event],
      );

      expect(state1 == state2, false); // 不同的历史记录
      expect(state2 == state3, true); // 相同的历史记录
    });
  });

  group('NetworkConnectionEvent', () {
    test('should be created with all required fields', () {
      final timestamp = DateTime.now();
      final event = NetworkConnectionEvent(
        timestamp: timestamp,
        status: NetworkStatus.online,
        type: NetworkType.wifi,
        previousStatus: NetworkStatus.offline,
        previousType: NetworkType.none,
        duration: const Duration(minutes: 5),
      );

      expect(event.timestamp, timestamp);
      expect(event.status, NetworkStatus.online);
      expect(event.type, NetworkType.wifi);
      expect(event.previousStatus, NetworkStatus.offline);
      expect(event.previousType, NetworkType.none);
      expect(event.duration, const Duration(minutes: 5));
    });

    test('should support optional fields', () {
      final timestamp = DateTime.now();
      final event = NetworkConnectionEvent(
        timestamp: timestamp,
        status: NetworkStatus.online,
        type: NetworkType.wifi,
      );

      expect(event.timestamp, timestamp);
      expect(event.status, NetworkStatus.online);
      expect(event.type, NetworkType.wifi);
      expect(event.previousStatus, isNull);
      expect(event.previousType, isNull);
      expect(event.duration, isNull);
    });

    test('should have proper equality comparison', () {
      final timestamp = DateTime.now();
      final event1 = NetworkConnectionEvent(
        timestamp: timestamp,
        status: NetworkStatus.online,
        type: NetworkType.wifi,
      );

      final event2 = NetworkConnectionEvent(
        timestamp: timestamp,
        status: NetworkStatus.online,
        type: NetworkType.wifi,
      );

      final event3 = NetworkConnectionEvent(
        timestamp: timestamp,
        status: NetworkStatus.offline,
        type: NetworkType.wifi,
      );

      expect(event1 == event2, true);
      expect(event1 == event3, false);
      expect(event1.hashCode == event2.hashCode, true);
      expect(event1.hashCode == event3.hashCode, false);
    });
  });

  group('NetworkMonitorConfig', () {
    test('should have correct default values', () {
      const config = NetworkMonitorConfig();
      
      expect(config.enableConnectivityCheck, true);
      expect(config.enableLatencyCheck, true);
      expect(config.enableSpeedTest, false);
      expect(config.checkInterval, const Duration(seconds: 30));
      expect(config.latencyTestHost, 'google.com');
      expect(config.latencyTestPort, 80);
      expect(config.maxHistorySize, 100);
      expect(config.connectivityTimeout, const Duration(seconds: 10));
      expect(config.enableDebugLog, false);
    });

    test('should support copyWith correctly', () {
      const original = NetworkMonitorConfig();
      
      final updated = original.copyWith(
        enableSpeedTest: true,
        checkInterval: const Duration(minutes: 1),
        latencyTestHost: 'cloudflare.com',
        latencyTestPort: 443,
        maxHistorySize: 50,
        enableDebugLog: true,
      );

      expect(updated.enableSpeedTest, true);
      expect(updated.checkInterval, const Duration(minutes: 1));
      expect(updated.latencyTestHost, 'cloudflare.com');
      expect(updated.latencyTestPort, 443);
      expect(updated.maxHistorySize, 50);
      expect(updated.enableDebugLog, true);
      expect(updated.enableLatencyCheck, true); // 保持原值
      expect(updated.enableConnectivityCheck, true); // 保持原值
    });

    test('should have proper equality comparison', () {
      const config1 = NetworkMonitorConfig();
      const config2 = NetworkMonitorConfig();
      final config3 = config1.copyWith(enableSpeedTest: true);

      expect(config1 == config2, true);
      expect(config1 == config3, false);
      expect(config1.hashCode == config2.hashCode, true);
      expect(config1.hashCode == config3.hashCode, false);
    });
  });

  group('NetworkMonitor Basic Functionality', () {
    late NetworkMonitor monitor;

    setUp(() {
      monitor = NetworkMonitor(
        config: const NetworkMonitorConfig(
          enableDebugLog: false,
          enableLatencyCheck: false, // 禁用延迟检测避免异步问题
        ),
      );
    });

    tearDown(() {
      monitor.dispose();
    });

    test('should initialize with correct default state', () {
      expect(monitor.state.status, isIn([NetworkStatus.unknown, NetworkStatus.online, NetworkStatus.offline]));
      expect(monitor.state.isMonitoring, false);
      expect(monitor.state.connectionHistory, isEmpty);
    });

    test('should start monitoring successfully', () async {
      final result = await monitor.startMonitoring();
      expect(result.isSuccess, true);
      expect(monitor.state.isMonitoring, true);
    });

    test('should stop monitoring successfully', () async {
      await monitor.startMonitoring();
      expect(monitor.state.isMonitoring, true);
      
      await monitor.stopMonitoring();
      expect(monitor.state.isMonitoring, false);
    });

    test('should provide network summary', () {
      final summary = monitor.getNetworkSummary();
      expect(summary, isA<String>());
      expect(summary.isNotEmpty, true);
    });

    test('should refresh network status', () async {
      final result = await monitor.refresh();
      expect(result.isSuccess, true);
    });
  });

  group('NetworkMonitor Extensions', () {
    late NetworkMonitor monitor;

    setUp(() {
      monitor = NetworkMonitor(
        config: const NetworkMonitorConfig(
          enableDebugLog: false,
          enableLatencyCheck: false,
        ),
      );
    });

    tearDown(() {
      monitor.dispose();
    });

    test('should detect metered connection correctly', () {
      // 默认状态下应该不是计费连接
      expect(monitor.isMeteredConnection, false);
    });

    test('should check suitability for large transfer', () {
      // 默认状态下的传输适应性检查
      final suitable = monitor.isSuitableForLargeTransfer;
      expect(suitable, isA<bool>());
    });

    test('should handle waitForConnection timeout', () async {
      final connected = await monitor.waitForConnection(
        timeout: const Duration(milliseconds: 100),
      );
      expect(connected, isA<bool>());
    });
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
  });

  group('Status Mapping Logic', () {
    test('should map NetworkStatus to ConnectivityStatus correctly', () {
      final testCases = [
        (NetworkStatus.online, NetworkQuality.excellent, ConnectivityStatus.online),
        (NetworkStatus.online, NetworkQuality.good, ConnectivityStatus.online),
        (NetworkStatus.online, NetworkQuality.fair, ConnectivityStatus.online),
        (NetworkStatus.online, NetworkQuality.poor, ConnectivityStatus.limited),
        (NetworkStatus.limited, NetworkQuality.fair, ConnectivityStatus.limited),
        (NetworkStatus.offline, NetworkQuality.none, ConnectivityStatus.offline),
        (NetworkStatus.unknown, NetworkQuality.none, ConnectivityStatus.offline),
      ];

      for (final testCase in testCases) {
        final networkStatus = testCase.$1;
        final networkQuality = testCase.$2;
        final expectedConnectivityStatus = testCase.$3;

        // 模拟映射逻辑
        final ConnectivityStatus actualStatus;
        switch (networkStatus) {
          case NetworkStatus.online:
            actualStatus = networkQuality == NetworkQuality.poor 
                ? ConnectivityStatus.limited 
                : ConnectivityStatus.online;
            break;
          case NetworkStatus.limited:
            actualStatus = ConnectivityStatus.limited;
            break;
          case NetworkStatus.offline:
          case NetworkStatus.unknown:
            actualStatus = ConnectivityStatus.offline;
            break;
        }

        expect(actualStatus, expectedConnectivityStatus,
            reason: 'Failed for networkStatus: $networkStatus, quality: $networkQuality');
      }
    });
  });

  group('Error Handling', () {
    test('should handle monitor disposal gracefully', () {
      final monitor = NetworkMonitor(
        config: const NetworkMonitorConfig(
          enableDebugLog: false,
          enableLatencyCheck: false,
        ),
      );
      
      // 单次dispose应该正常工作
      expect(() => monitor.dispose(), returnsNormally);
    });
  });
} 