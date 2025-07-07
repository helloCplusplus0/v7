/// Flutter v7 数据库抽象层
/// 提供统一的数据库访问接口，支持离线优先的数据存储

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../types/result.dart';

/// 数据库异常类型
enum DatabaseErrorType {
  connection,
  syntax,
  constraint,
  notFound,
  permission,
  corruption,
  migration,
  timeout,
  unknown,
}

/// 数据库异常
class DatabaseException extends AppError {
  const DatabaseException(
    super.message, [
    super.cause,
    this.type = DatabaseErrorType.unknown,
    this.table,
    this.operation,
    this.sql,
  ]);

  final DatabaseErrorType type;
  final String? table;
  final String? operation;
  final String? sql;

  @override
  String toString() {
    final buffer = StringBuffer('DatabaseException: $message');
    if (type != DatabaseErrorType.unknown) {
      buffer.write(' (type: ${type.name})');
    }
    if (table != null) buffer.write(' (table: $table)');
    if (operation != null) buffer.write(' (operation: $operation)');
    if (sql != null) buffer.write(' (sql: $sql)');
    return buffer.toString();
  }
}

/// 数据库配置验证异常
class DatabaseConfigException extends AppError {
  const DatabaseConfigException(super.message, [super.cause]);
}

/// 数据库接口
/// 定义统一的数据库操作API
abstract class Database {
  /// 执行查询
  Future<AppResult<List<Map<String, dynamic>>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  });
  
  /// 执行原始SQL查询
  Future<AppResult<List<Map<String, dynamic>>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]);
  
  /// 插入数据
  Future<AppResult<int>> insert(
    String table,
    Map<String, dynamic> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  });
  
  /// 批量插入
  Future<AppResult<List<int>>> insertBatch(
    String table,
    List<Map<String, dynamic>> values, {
    ConflictAlgorithm? conflictAlgorithm,
  });
  
  /// 更新数据
  Future<AppResult<int>> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  });
  
  /// 删除数据
  Future<AppResult<int>> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  });
  
  /// 执行原始SQL
  Future<AppResult<int>> rawDelete(String sql, [List<dynamic>? arguments]);
  Future<AppResult<int>> rawUpdate(String sql, [List<dynamic>? arguments]);
  Future<AppResult<int>> rawInsert(String sql, [List<dynamic>? arguments]);
  
  /// 事务操作
  Future<AppResult<T>> transaction<T>(
    Future<T> Function(DatabaseTransaction txn) action, {
    bool? exclusive,
  });
  
  /// 批量操作
  Future<AppResult<void>> batch(Future<void> Function(DatabaseBatch batch) action);
  
  /// 获取数据库版本
  Future<AppResult<int>> getVersion();
  
  /// 设置数据库版本
  Future<AppResult<void>> setVersion(int version);
  
  /// 检查表是否存在
  Future<AppResult<bool>> tableExists(String table);
  
  /// 获取表信息
  Future<AppResult<List<TableInfo>>> getTables();
  
  /// 获取表列信息
  Future<AppResult<List<ColumnInfo>>> getTableColumns(String table);
  
  /// 创建索引
  Future<AppResult<void>> createIndex(String name, String table, List<String> columns);
  
  /// 删除索引
  Future<AppResult<void>> dropIndex(String name);
  
  /// 数据库健康检查
  Future<AppResult<DatabaseHealth>> healthCheck();
  
  /// 优化数据库
  Future<AppResult<void>> vacuum();
  
  /// 关闭数据库
  Future<void> close();
  
  /// 数据库是否已打开
  bool get isOpen;
  
  /// 数据库路径
  String? get path;
}

/// 冲突处理算法
enum ConflictAlgorithm {
  rollback,
  abort,
  fail,
  ignore,
  replace,
}

/// 数据库事务接口
abstract class DatabaseTransaction {
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  });
  
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]);
  
  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  });
  
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  });
  
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  });
  
  Future<int> rawDelete(String sql, [List<dynamic>? arguments]);
  Future<int> rawUpdate(String sql, [List<dynamic>? arguments]);
  Future<int> rawInsert(String sql, [List<dynamic>? arguments]);
}

/// 数据库批量操作接口
abstract class DatabaseBatch {
  void insert(
    String table,
    Map<String, dynamic> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  });
  
  void update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  });
  
  void delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  });
  
  void rawInsert(String sql, [List<dynamic>? arguments]);
  void rawUpdate(String sql, [List<dynamic>? arguments]);
  void rawDelete(String sql, [List<dynamic>? arguments]);
  
  Future<List<dynamic>> commit({bool? exclusive, bool? noResult});
}

/// 表信息
class TableInfo {
  const TableInfo({
    required this.name,
    required this.type,
    required this.rootPage,
    required this.sql,
  });
  
  final String name;
  final String type;
  final int rootPage;
  final String? sql;
  
  @override
  String toString() => 'TableInfo(name: $name, type: $type)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type == other.type &&
          rootPage == other.rootPage &&
          sql == other.sql;

  @override
  int get hashCode => Object.hash(name, type, rootPage, sql);
}

/// 列信息
class ColumnInfo {
  const ColumnInfo({
    required this.cid,
    required this.name,
    required this.type,
    required this.notNull,
    required this.defaultValue,
    required this.primaryKey,
  });
  
  final int cid;
  final String name;
  final String type;
  final bool notNull;
  final dynamic defaultValue;
  final bool primaryKey;
  
  @override
  String toString() => 'ColumnInfo(name: $name, type: $type, notNull: $notNull)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColumnInfo &&
          runtimeType == other.runtimeType &&
          cid == other.cid &&
          name == other.name &&
          type == other.type &&
          notNull == other.notNull &&
          defaultValue == other.defaultValue &&
          primaryKey == other.primaryKey;

  @override
  int get hashCode => Object.hash(cid, name, type, notNull, defaultValue, primaryKey);
}

/// 数据库健康状态
class DatabaseHealth {
  const DatabaseHealth({
    required this.isHealthy,
    required this.version,
    required this.size,
    required this.tableCount,
    required this.indexCount,
    this.errors = const [],
    this.warnings = const [],
    this.lastVacuum,
    this.integrityCheck,
  });
  
  final bool isHealthy;
  final int version;
  final int size; // 数据库大小（字节）
  final int tableCount;
  final int indexCount;
  final List<String> errors;
  final List<String> warnings;
  final DateTime? lastVacuum;
  final bool? integrityCheck;
  
  /// 格式化大小显示
  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
  
  /// 是否需要优化
  bool get needsOptimization {
    return warnings.isNotEmpty || 
           (lastVacuum != null && DateTime.now().difference(lastVacuum!).inDays > 30);
  }
  
  @override
  String toString() {
    return 'DatabaseHealth(healthy: $isHealthy, version: $version, '
           'size: $formattedSize, tables: $tableCount, indexes: $indexCount)';
  }
}

/// 数据库迁移接口
abstract class DatabaseMigration {
  /// 迁移版本
  int get version;
  
  /// 迁移描述
  String get description;
  
  /// 执行向上迁移
  Future<void> upgrade(DatabaseTransaction txn, int oldVersion, int newVersion);
  
  /// 执行向下迁移（可选）
  Future<void> downgrade(DatabaseTransaction txn, int oldVersion, int newVersion) async {
    throw UnsupportedError('Downgrade not supported for migration $version');
  }
  
  /// 验证迁移前置条件
  Future<bool> canMigrate(DatabaseTransaction txn, int fromVersion) async => true;
}

/// 数据库配置
class DatabaseConfig {
  const DatabaseConfig({
    required this.name,
    required this.version,
    this.path,
    this.migrations = const [],
    this.readOnly = false,
    this.singleInstance = true,
    this.pageSize,
    this.cacheSize,
    this.enableForeignKeys = true,
    this.enableWAL = true,
    this.busyTimeout,
    this.maxConnections = 1,
    this.connectionTimeout,
  });
  
  final String name;
  final int version;
  final String? path;
  final List<DatabaseMigration> migrations;
  final bool readOnly;
  final bool singleInstance;
  final int? pageSize;
  final int? cacheSize;
  final bool enableForeignKeys;
  final bool enableWAL; // Write-Ahead Logging
  final Duration? busyTimeout;
  final int maxConnections;
  final Duration? connectionTimeout;
  
  /// 验证配置
  void validate() {
    if (name.isEmpty) {
      throw const DatabaseConfigException('Database name cannot be empty');
    }
    
    if (version <= 0) {
      throw const DatabaseConfigException('Database version must be positive');
    }
    
    if (pageSize != null && (pageSize! < 512 || pageSize! > 65536)) {
      throw const DatabaseConfigException('Page size must be between 512 and 65536');
    }
    
    if (cacheSize != null && cacheSize! < 0) {
      throw const DatabaseConfigException('Cache size cannot be negative');
    }
    
    if (maxConnections <= 0) {
      throw const DatabaseConfigException('Max connections must be positive');
    }
    
    // 验证迁移版本连续性
    final migrationVersions = migrations.map((m) => m.version).toList()..sort();
    for (int i = 0; i < migrationVersions.length - 1; i++) {
      if (migrationVersions[i + 1] != migrationVersions[i] + 1) {
        throw DatabaseConfigException(
          'Migration versions must be consecutive, found gap between '
          '${migrationVersions[i]} and ${migrationVersions[i + 1]}'
        );
      }
    }
    
    if (migrationVersions.isNotEmpty && migrationVersions.last != version) {
      throw DatabaseConfigException(
        'Latest migration version (${migrationVersions.last}) '
        'does not match database version ($version)'
      );
    }
  }
  
  /// 复制配置
  DatabaseConfig copyWith({
    String? name,
    int? version,
    String? path,
    List<DatabaseMigration>? migrations,
    bool? readOnly,
    bool? singleInstance,
    int? pageSize,
    int? cacheSize,
    bool? enableForeignKeys,
    bool? enableWAL,
    Duration? busyTimeout,
    int? maxConnections,
    Duration? connectionTimeout,
  }) {
    return DatabaseConfig(
      name: name ?? this.name,
      version: version ?? this.version,
      path: path ?? this.path,
      migrations: migrations ?? this.migrations,
      readOnly: readOnly ?? this.readOnly,
      singleInstance: singleInstance ?? this.singleInstance,
      pageSize: pageSize ?? this.pageSize,
      cacheSize: cacheSize ?? this.cacheSize,
      enableForeignKeys: enableForeignKeys ?? this.enableForeignKeys,
      enableWAL: enableWAL ?? this.enableWAL,
      busyTimeout: busyTimeout ?? this.busyTimeout,
      maxConnections: maxConnections ?? this.maxConnections,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
    );
  }
}

/// 数据库工厂
abstract class DatabaseFactory {
  /// 打开数据库
  Future<AppResult<Database>> openDatabase(DatabaseConfig config);
  
  /// 删除数据库
  Future<AppResult<void>> deleteDatabase(String path);
  
  /// 检查数据库是否存在
  Future<AppResult<bool>> databaseExists(String path);
  
  /// 获取数据库路径
  Future<AppResult<String>> getDatabasePath(String name);
  
  /// 获取数据库目录
  Future<AppResult<String>> getDatabasesPath();
  
  /// 检查工厂可用性
  Future<bool> isAvailable();
  
  /// 获取实现类型
  String get implementationType;
  
  /// 获取支持的特性
  Set<DatabaseFeature> get supportedFeatures;
}

/// 数据库特性
enum DatabaseFeature {
  transactions,
  batchOperations,
  foreignKeys,
  writeAheadLogging,
  fullTextSearch,
  jsonSupport,
  encryption,
  compression,
}

/// JOIN 类型
enum JoinType {
  inner('INNER JOIN'),
  left('LEFT JOIN'),
  right('RIGHT JOIN'),
  full('FULL OUTER JOIN'),
  cross('CROSS JOIN');
  
  const JoinType(this.sql);
  final String sql;
}

/// 查询构建器
class QueryBuilder {
  QueryBuilder._(this._table);
  
  static QueryBuilder table(String table) => QueryBuilder._(table);
  
  final String _table;
  List<String>? _columns;
  String? _where;
  List<dynamic>? _whereArgs;
  String? _groupBy;
  String? _having;
  String? _orderBy;
  int? _limit;
  int? _offset;
  bool? _distinct;
  final List<_JoinClause> _joins = [];
  final List<_UnionClause> _unions = [];
  
  QueryBuilder select(List<String> columns) {
    _columns = columns;
    return this;
  }
  
  QueryBuilder where(String condition, [List<dynamic>? args]) {
    _where = condition;
    _whereArgs = args;
    return this;
  }
  
  /// 添加 AND 条件
  QueryBuilder and(String condition, [List<dynamic>? args]) {
    if (_where == null) {
      return where(condition, args);
    }
    _where = '($_where) AND ($condition)';
    if (args != null) {
      _whereArgs = [...(_whereArgs ?? []), ...args];
    }
    return this;
  }
  
  /// 添加 OR 条件
  QueryBuilder or(String condition, [List<dynamic>? args]) {
    if (_where == null) {
      return where(condition, args);
    }
    _where = '($_where) OR ($condition)';
    if (args != null) {
      _whereArgs = [...(_whereArgs ?? []), ...args];
    }
    return this;
  }
  
  /// 添加 JOIN
  QueryBuilder join(String table, String on, {JoinType type = JoinType.inner}) {
    _joins.add(_JoinClause(type, table, on));
    return this;
  }
  
  /// 添加 LEFT JOIN
  QueryBuilder leftJoin(String table, String on) {
    return join(table, on, type: JoinType.left);
  }
  
  /// 添加 INNER JOIN
  QueryBuilder innerJoin(String table, String on) {
    return join(table, on, type: JoinType.inner);
  }
  
  QueryBuilder groupBy(String column) {
    _groupBy = column;
    return this;
  }
  
  QueryBuilder having(String condition) {
    _having = condition;
    return this;
  }
  
  QueryBuilder orderBy(String column, {bool desc = false}) {
    _orderBy = desc ? '$column DESC' : '$column ASC';
    return this;
  }
  
  /// 添加多个排序条件
  QueryBuilder orderByMultiple(List<String> columns, {bool desc = false}) {
    final orderClauses = columns.map((col) => desc ? '$col DESC' : '$col ASC');
    _orderBy = orderClauses.join(', ');
    return this;
  }
  
  QueryBuilder limit(int count, {int? offset}) {
    _limit = count;
    _offset = offset;
    return this;
  }
  
  QueryBuilder distinct() {
    _distinct = true;
    return this;
  }
  
  /// 添加 UNION
  QueryBuilder union(QueryBuilder other) {
    _unions.add(_UnionClause(false, other));
    return this;
  }
  
  /// 添加 UNION ALL
  QueryBuilder unionAll(QueryBuilder other) {
    _unions.add(_UnionClause(true, other));
    return this;
  }
  
  Future<AppResult<List<Map<String, dynamic>>>> execute(Database db) {
    return db.rawQuery(toSql(), _whereArgs);
  }
  
  /// 获取查询参数
  List<dynamic>? get parameters => _whereArgs;
  
  String toSql() {
    final buffer = StringBuffer();
    buffer.write('SELECT ');
    
    if (_distinct == true) {
      buffer.write('DISTINCT ');
    }
    
    if (_columns?.isNotEmpty == true) {
      buffer.write(_columns!.join(', '));
    } else {
      buffer.write('*');
    }
    
    buffer.write(' FROM $_table');
    
    // 添加 JOIN 子句
    for (final join in _joins) {
      buffer.write(' ${join.type.sql} ${join.table} ON ${join.on}');
    }
    
    if (_where?.isNotEmpty == true) {
      buffer.write(' WHERE $_where');
    }
    
    if (_groupBy?.isNotEmpty == true) {
      buffer.write(' GROUP BY $_groupBy');
    }
    
    if (_having?.isNotEmpty == true) {
      buffer.write(' HAVING $_having');
    }
    
    if (_orderBy?.isNotEmpty == true) {
      buffer.write(' ORDER BY $_orderBy');
    }
    
    if (_limit != null) {
      buffer.write(' LIMIT $_limit');
      if (_offset != null) {
        buffer.write(' OFFSET $_offset');
      }
    }
    
    // 添加 UNION 子句
    for (final union in _unions) {
      buffer.write(union.all ? ' UNION ALL (' : ' UNION (');
      buffer.write(union.query.toSql());
      buffer.write(')');
    }
    
    return buffer.toString();
  }
  
  /// 重置构建器
  QueryBuilder reset() {
    _columns = null;
    _where = null;
    _whereArgs = null;
    _groupBy = null;
    _having = null;
    _orderBy = null;
    _limit = null;
    _offset = null;
    _distinct = null;
    _joins.clear();
    _unions.clear();
    return this;
  }
}

/// JOIN 子句
class _JoinClause {
  const _JoinClause(this.type, this.table, this.on);
  
  final JoinType type;
  final String table;
  final String on;
}

/// UNION 子句
class _UnionClause {
  const _UnionClause(this.all, this.query);
  
  final bool all;
  final QueryBuilder query;
}

/// 数据库事件
abstract class DatabaseEvent {
  DatabaseEvent({DateTime? timestamp}) 
      : timestamp = timestamp ?? DateTime.now();
  
  final DateTime timestamp;
  
  /// 事件类型
  String get eventType => runtimeType.toString();
}

/// 数据库连接事件
class DatabaseConnectedEvent extends DatabaseEvent {
  DatabaseConnectedEvent({required this.path, super.timestamp});
  
  final String path;
}

/// 数据库断开事件
class DatabaseDisconnectedEvent extends DatabaseEvent {
  DatabaseDisconnectedEvent({required this.path, super.timestamp});
  
  final String path;
}

/// 数据库迁移事件
class DatabaseMigrationEvent extends DatabaseEvent {
  DatabaseMigrationEvent({
    required this.fromVersion,
    required this.toVersion,
    required this.description,
    super.timestamp,
  });
  
  final int fromVersion;
  final int toVersion;
  final String description;
}

/// 数据库错误事件
class DatabaseErrorEvent extends DatabaseEvent {
  DatabaseErrorEvent({
    required this.error,
    required this.operation,
    this.table,
    super.timestamp,
  });
  
  final dynamic error;
  final String operation;
  final String? table;
}

/// 数据库查询事件
class DatabaseQueryEvent extends DatabaseEvent {
  DatabaseQueryEvent({
    required this.sql,
    required this.duration,
    this.rowsAffected,
    super.timestamp,
  });
  
  final String sql;
  final Duration duration;
  final int? rowsAffected;
}

/// 数据库监听器
typedef DatabaseListener = void Function(DatabaseEvent event);

/// 可观察的数据库接口
mixin ObservableDatabase on Database {
  final List<DatabaseListener> _listeners = [];
  
  void addListener(DatabaseListener listener) {
    _listeners.add(listener);
  }
  
  void removeListener(DatabaseListener listener) {
    _listeners.remove(listener);
  }
  
  @protected
  void notifyListeners(DatabaseEvent event) {
    for (final listener in _listeners) {
      try {
        listener(event);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Database listener error: $e');
        }
      }
    }
  }
  
  void clearListeners() {
    _listeners.clear();
  }
  
  /// 添加特定类型的监听器
  void addTypedListener<T extends DatabaseEvent>(void Function(T event) listener) {
    addListener((event) {
      if (event is T) {
        listener(event);
      }
    });
  }
  
  /// 监听数据库错误
  void onError(void Function(DatabaseErrorEvent event) listener) {
    addTypedListener<DatabaseErrorEvent>(listener);
  }
  
  /// 监听数据库连接状态
  void onConnectionChange(void Function(DatabaseEvent event) listener) {
    addListener((event) {
      if (event is DatabaseConnectedEvent || event is DatabaseDisconnectedEvent) {
        listener(event);
      }
    });
  }
} 