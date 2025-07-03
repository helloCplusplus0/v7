/// Demo切片 - 统一导出
/// v7功能切片架构示例实现
/// 
/// 本切片展示了完整的v7架构实现，包括：
/// - models: 数据模型定义
/// - repository: 数据访问层
/// - service: 业务逻辑层  
/// - providers: 状态管理层
/// - widgets: UI组件层
/// - index: 统一导出层

// 核心模型
export 'models.dart';

// 数据访问层
export 'repository.dart';

// 业务逻辑层
export 'service.dart';

// 状态管理层
export 'providers.dart';

// UI组件层
export 'widgets.dart';

// 摘要提供者
export 'summary_provider.dart';

/// 切片元信息
class DemoSliceInfo {
  static const String name = 'demo';
  static const String title = '任务管理演示';
  static const String description = 'v7功能切片架构的完整示例，包含任务管理功能';
  static const String version = '1.0.0';
  static const List<String> dependencies = ['shared'];
  static const List<String> events = [
    'tasks:loaded',
    'task:created', 
    'task:toggled',
    'task:deleted',
    'task:error'
  ];
}

/// 切片配置
class DemoSliceConfig {
  /// 是否启用离线模式
  static const bool enableOfflineMode = true;
  
  /// API超时时间（毫秒）
  static const int apiTimeout = 5000;
  
  /// 缓存过期时间（毫秒）
  static const int cacheExpiration = 300000; // 5分钟
  
  /// 自动刷新间隔（毫秒）
  static const int autoRefreshInterval = 60000; // 1分钟
} 