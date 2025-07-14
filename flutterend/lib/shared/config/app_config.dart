/// 简化的Flutter v7 应用配置系统
/// 专注于核心功能：多后端支持 + 环境变量覆盖

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../network/api_client.dart' show BackendConfig;

/// 简化的应用配置
class AppConfig {
  static AppConfig? _instance;
  static AppConfig get instance {
    if (_instance == null) {
      throw Exception('AppConfig未初始化，请先调用AppConfig.initialize()');
    }
    return _instance!;
  }

  final Map<String, BackendConfig> _backends;
  final String _defaultBackendName;

  AppConfig._({
    required Map<String, BackendConfig> backends,
    required String defaultBackendName,
  })  : _backends = backends,
        _defaultBackendName = defaultBackendName;

  /// 简化的初始化
  static Future<void> initialize({
    String? configAssetPath,
    Map<String, String?>? envOverrides,
  }) async {
    try {
      Map<String, dynamic> config = {};
      
      // 加载配置文件
      if (configAssetPath != null) {
        try {
          final configString = await rootBundle.loadString(configAssetPath);
          config = json.decode(configString) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('⚠️ 配置文件加载失败，使用默认配置: $e');
        }
      }

      // 应用环境变量覆盖（简化版）
      config = _applyEnvOverrides(config, envOverrides);

      // 解析后端配置
      final backends = <String, BackendConfig>{};
      final backendsConfig = config['backends'] as Map<String, dynamic>? ?? {};
      
      for (final entry in backendsConfig.entries) {
        final backendData = entry.value as Map<String, dynamic>;
        backends[entry.key] = BackendConfig(
          name: entry.key,
          baseUrl: backendData['baseUrl'] as String,
          timeout: Duration(seconds: backendData['timeout'] as int? ?? 30),
          retryAttempts: backendData['retryAttempts'] as int? ?? 3,
          healthEndpoint: backendData['healthEndpoint'] as String? ?? '/health',
        );
      }

      // 确保有默认后端 - 如果配置文件中没有后端，则抛出错误
      if (backends.isEmpty) {
        throw StateError('配置文件中没有定义任何后端服务。请检查app_config.json中的backends配置。');
      }

      final defaultBackend = config['defaultBackend'] as String? ?? backends.keys.first;

      _instance = AppConfig._(
        backends: backends,
        defaultBackendName: defaultBackend,
      );

      debugPrint('✅ AppConfig 初始化成功，后端数量: ${backends.length}');
    } catch (e) {
      debugPrint('❌ AppConfig 初始化失败: $e');
      rethrow;
    }
  }

  /// 应用环境变量覆盖（简化版）
  static Map<String, dynamic> _applyEnvOverrides(
    Map<String, dynamic> config,
    Map<String, String?>? envOverrides,
  ) {
    final result = Map<String, dynamic>.from(config);
    
    // 处理传入的环境变量覆盖
    if (envOverrides != null) {
      // 这里可以实现更复杂的路径覆盖逻辑
      // 目前保持简单实现
    }
    
    // 检查主要的环境变量
    final apiBaseUrl = Platform.environment['API_BASE_URL'];
    if (apiBaseUrl != null) {
      // 更新默认后端的baseUrl
      final backends = result['backends'] as Map<String, dynamic>? ?? {};
      final defaultBackendName = result['defaultBackend'] as String? ?? 'primary';
      
      if (backends.containsKey(defaultBackendName)) {
        final defaultBackend = backends[defaultBackendName] as Map<String, dynamic>;
        defaultBackend['baseUrl'] = apiBaseUrl;
      }
    }
    
    return result;
  }

  /// 获取后端配置
  BackendConfig getBackendConfig(String name) {
    final config = _backends[name];
    if (config == null) {
      throw Exception('后端配置 $name 未找到');
    }
    return config;
  }

  /// 获取默认后端配置
  BackendConfig get defaultBackend => getBackendConfig(_defaultBackendName);

  /// 获取所有后端配置
  List<BackendConfig> get allBackends => _backends.values.toList();

  /// 获取后端名称列表
  List<String> get backendNames => _backends.keys.toList();

  /// 检查后端是否存在
  bool hasBackend(String name) => _backends.containsKey(name);
}

 