/// SQLite数据库具体实现
/// 基于sqflite包实现Database接口，提供离线优先的数据存储

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import '../types/result.dart';
import 'database.dart';

/// SQLite数据库实现
class SQLiteDatabase implements Database {
  SQLiteDatabase._({
    required this.config,
    required sqflite.Database database,
  }) : _database = database;

  final DatabaseConfig config;
  final sqflite.Database _database;
  
  bool _isOpen = true;

  /// 创建SQLite数据库实例
  static Future<AppResult<SQLiteDatabase>> create(DatabaseConfig config) async {
    try {
      // 验证配置
      final configValidation = _validateConfig(config);
      if (configValidation.isFailure) {
        return AppResult.failure(configValidation.errorOrNull!);
      }

      // 获取数据库路径
      final dbPath = await _getDatabasePath(config);
      
      // 打开数据库
      final database = await sqflite.openDatabase(
        dbPath,
        version: config.version,
        onCreate: (db, version) => _onCreate(db, version, config),
        onUpgrade: (db, oldVersion, newVersion) => _onUpgrade(db, oldVersion, newVersion, config),
        onDowngrade: (db, oldVersion, newVersion) => _onDowngrade(db, oldVersion, newVersion, config),
        onConfigure: (db) => _onConfigure(db, config),
        readOnly: config.readOnly,
        singleInstance: config.singleInstance,
      );

      final instance = SQLiteDatabase._(
        config: config,
        database: database,
      );

      // 执行初始化配置
      await instance._initialize();

      return AppResult.success(instance);
    } catch (e, stackTrace) {
      return AppResult.failure(
        DatabaseException(
          'Failed to create SQLite database: $e',
          e,
          DatabaseErrorType.connection,
        ),
      );
    }
  }

  /// 验证数据库配置
  static AppResult<void> _validateConfig(DatabaseConfig config) {
    if (config.name.isEmpty) {
      return AppResult.failure(
        const DatabaseConfigException('Database name cannot be empty'),
      );
    }

    if (config.version <= 0) {
      return AppResult.failure(
        const DatabaseConfigException('Database version must be positive'),
      );
    }

    // 验证迁移版本连续性
    final migrationVersions = config.migrations.map((m) => m.version).toList()..sort();
    for (int i = 0; i < migrationVersions.length - 1; i++) {
      if (migrationVersions[i + 1] != migrationVersions[i] + 1) {
        return AppResult.failure(
          DatabaseConfigException(
            'Migration versions must be consecutive, found gap between ${migrationVersions[i]} and ${migrationVersions[i + 1]}',
          ),
        );
      }
    }

    return AppResult.success(null);
  }

  /// 获取数据库路径
  static Future<String> _getDatabasePath(DatabaseConfig config) async {
    if (config.path != null) {
      return config.path!;
    }

    final databasesPath = await sqflite.getDatabasesPath();
    return '$databasesPath/${config.name}.db';
  }

  /// 数据库创建回调
  static Future<void> _onCreate(
    sqflite.Database db,
    int version,
    DatabaseConfig config,
  ) async {
    // 执行所有迁移到当前版本
    for (final migration in config.migrations) {
      if (migration.version <= version) {
        final txn = _SQLiteTransaction(db);
        await migration.upgrade(txn, 0, migration.version);
      }
    }
  }

  /// 数据库升级回调
  static Future<void> _onUpgrade(
    sqflite.Database db,
    int oldVersion,
    int newVersion,
    DatabaseConfig config,
  ) async {
    for (final migration in config.migrations) {
      if (migration.version > oldVersion && migration.version <= newVersion) {
        final txn = _SQLiteTransaction(db);
        
        // 检查迁移前置条件
        final canMigrate = await migration.canMigrate(txn, oldVersion);
        if (!canMigrate) {
          throw DatabaseException(
            'Migration ${migration.version} preconditions not met',
            null,
            DatabaseErrorType.migration,
          );
        }
        
        await migration.upgrade(txn, oldVersion, migration.version);
        oldVersion = migration.version;
      }
    }
  }

  /// 数据库降级回调
  static Future<void> _onDowngrade(
    sqflite.Database db,
    int oldVersion,
    int newVersion,
    DatabaseConfig config,
  ) async {
    // 按版本倒序执行降级
    final migrations = config.migrations.where((m) => m.version > newVersion && m.version <= oldVersion).toList()
      ..sort((a, b) => b.version.compareTo(a.version));

    for (final migration in migrations) {
      final txn = _SQLiteTransaction(db);
      await migration.downgrade(txn, oldVersion, newVersion);
    }
  }

  /// 数据库配置回调
  static Future<void> _onConfigure(sqflite.Database db, DatabaseConfig config) async {
    if (config.enableForeignKeys) {
      await db.execute('PRAGMA foreign_keys = ON');
    }

    if (config.enableWAL) {
      await db.execute('PRAGMA journal_mode = WAL');
    }

    if (config.pageSize != null) {
      await db.execute('PRAGMA page_size = ${config.pageSize}');
    }

    if (config.cacheSize != null) {
      await db.execute('PRAGMA cache_size = ${config.cacheSize}');
    }

    if (config.busyTimeout != null) {
      await db.execute('PRAGMA busy_timeout = ${config.busyTimeout!.inMilliseconds}');
    }
  }

  /// 初始化数据库
  Future<void> _initialize() async {
    // 执行初始化查询验证数据库状态
    await _database.rawQuery('SELECT 1');
  }

  @override
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
  }) async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      final result = await _database.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

      return AppResult.success(result);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Query failed: $e',
          e,
          DatabaseErrorType.syntax,
          table,
          'query',
        ),
      );
    }
  }

  @override
  Future<AppResult<List<Map<String, dynamic>>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      final result = await _database.rawQuery(sql, arguments);
      return AppResult.success(result);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Raw query failed: $e',
          e,
          DatabaseErrorType.syntax,
          null,
          'rawQuery',
          sql,
        ),
      );
    }
  }

  @override
  Future<AppResult<int>> insert(
    String table,
    Map<String, dynamic> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      final result = await _database.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: _mapConflictAlgorithm(conflictAlgorithm),
      );

      return AppResult.success(result);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Insert failed: $e',
          e,
          _mapSQLiteError(e),
          table,
          'insert',
        ),
      );
    }
  }

  @override
  Future<AppResult<List<int>>> insertBatch(
    String table,
    List<Map<String, dynamic>> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      final batch = _database.batch();
      for (final value in values) {
        batch.insert(
          table,
          value,
          conflictAlgorithm: _mapConflictAlgorithm(conflictAlgorithm),
        );
      }

      final results = await batch.commit();
      return AppResult.success(results.cast<int>());
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Batch insert failed: $e',
          e,
          _mapSQLiteError(e),
          table,
          'insertBatch',
        ),
      );
    }
  }

  @override
  Future<AppResult<int>> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      final result = await _database.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: _mapConflictAlgorithm(conflictAlgorithm),
      );

      return AppResult.success(result);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Update failed: $e',
          e,
          _mapSQLiteError(e),
          table,
          'update',
        ),
      );
    }
  }

  @override
  Future<AppResult<int>> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      final result = await _database.delete(
        table,
        where: where,
        whereArgs: whereArgs,
      );

      return AppResult.success(result);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Delete failed: $e',
          e,
          _mapSQLiteError(e),
          table,
          'delete',
        ),
      );
    }
  }

  @override
  Future<AppResult<int>> rawDelete(String sql, [List<dynamic>? arguments]) async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      final result = await _database.rawDelete(sql, arguments);
      return AppResult.success(result);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Raw delete failed: $e',
          e,
          _mapSQLiteError(e),
          null,
          'rawDelete',
          sql,
        ),
      );
    }
  }

  @override
  Future<AppResult<int>> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      final result = await _database.rawUpdate(sql, arguments);
      return AppResult.success(result);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Raw update failed: $e',
          e,
          _mapSQLiteError(e),
          null,
          'rawUpdate',
          sql,
        ),
      );
    }
  }

  @override
  Future<AppResult<int>> rawInsert(String sql, [List<dynamic>? arguments]) async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      final result = await _database.rawInsert(sql, arguments);
      return AppResult.success(result);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Raw insert failed: $e',
          e,
          _mapSQLiteError(e),
          null,
          'rawInsert',
          sql,
        ),
      );
    }
  }

  @override
  Future<AppResult<T>> transaction<T>(
    Future<T> Function(DatabaseTransaction txn) action, {
    bool? exclusive,
  }) async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      final result = await _database.transaction<T>((txn) async {
        final transaction = _SQLiteTransaction(txn);
        return await action(transaction);
      }, exclusive: exclusive);

      return AppResult.success(result);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Transaction failed: $e',
          e,
          _mapSQLiteError(e),
          null,
          'transaction',
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> batch(Future<void> Function(DatabaseBatch batch) action) async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      final batch = _database.batch();
      final batchWrapper = _SQLiteBatch(batch);
      await action(batchWrapper);
      await batch.commit();

      return AppResult.success(null);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Batch operation failed: $e',
          e,
          _mapSQLiteError(e),
          null,
          'batch',
        ),
      );
    }
  }

  @override
  Future<AppResult<int>> getVersion() async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      final version = await _database.getVersion();
      return AppResult.success(version);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Failed to get version: $e',
          e,
          _mapSQLiteError(e),
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> setVersion(int version) async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      await _database.setVersion(version);
      return AppResult.success(null);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Failed to set version: $e',
          e,
          _mapSQLiteError(e),
        ),
      );
    }
  }

  @override
  Future<AppResult<bool>> tableExists(String table) async {
    final result = await rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );

    return result.map((rows) => rows.isNotEmpty);
  }

  @override
  Future<AppResult<List<TableInfo>>> getTables() async {
    final result = await rawQuery(
      "SELECT name, type, rootpage, sql FROM sqlite_master WHERE type='table'",
    );

    return result.map((rows) {
      return rows.map((row) {
        return TableInfo(
          name: row['name'] as String,
          type: row['type'] as String,
          rootPage: row['rootpage'] as int,
          sql: row['sql'] as String?,
        );
      }).toList();
    });
  }

  @override
  Future<AppResult<List<ColumnInfo>>> getTableColumns(String table) async {
    final result = await rawQuery('PRAGMA table_info($table)');

    return result.map((rows) {
      return rows.map((row) {
        return ColumnInfo(
          cid: row['cid'] as int,
          name: row['name'] as String,
          type: row['type'] as String,
          notNull: (row['notnull'] as int) == 1,
          defaultValue: row['dflt_value'],
          primaryKey: (row['pk'] as int) == 1,
        );
      }).toList();
    });
  }

  @override
  Future<AppResult<void>> createIndex(String name, String table, List<String> columns) async {
    final sql = 'CREATE INDEX IF NOT EXISTS $name ON $table (${columns.join(', ')})';
    final result = await rawQuery(sql);
    return result.map((_) => null);
  }

  @override
  Future<AppResult<void>> dropIndex(String name) async {
    final sql = 'DROP INDEX IF EXISTS $name';
    final result = await rawQuery(sql);
    return result.map((_) => null);
  }

  @override
  Future<AppResult<DatabaseHealth>> healthCheck() async {
    try {
      // 获取基本信息
      final versionResult = await getVersion();
      if (versionResult.isFailure) {
        return AppResult.failure(versionResult.errorOrNull!);
      }

      final tablesResult = await getTables();
      if (tablesResult.isFailure) {
        return AppResult.failure(tablesResult.errorOrNull!);
      }

      // 获取数据库大小
      final sizeResult = await rawQuery('PRAGMA page_size; PRAGMA page_count;');
      int size = 0;
      if (sizeResult.isSuccess) {
        final rows = sizeResult.valueOrNull!;
        if (rows.length >= 2) {
          final pageSize = rows[0]['page_size'] as int? ?? 0;
          final pageCount = rows[1]['page_count'] as int? ?? 0;
          size = pageSize * pageCount;
        }
      }

      // 获取索引信息
      final indexResult = await rawQuery(
        "SELECT COUNT(*) as count FROM sqlite_master WHERE type='index'",
      );
      final indexCount = indexResult.isSuccess 
          ? (indexResult.valueOrNull!.first['count'] as int? ?? 0)
          : 0;

      // 完整性检查
      final integrityResult = await rawQuery('PRAGMA integrity_check(1)');
      final integrityOk = integrityResult.isSuccess &&
          integrityResult.valueOrNull!.isNotEmpty &&
          integrityResult.valueOrNull!.first.values.first == 'ok';

      final errors = <String>[];
      final warnings = <String>[];

      if (!integrityOk) {
        errors.add('Database integrity check failed');
      }

      // 检查是否需要优化
      if (size > 100 * 1024 * 1024) { // 100MB
        warnings.add('Database size is large, consider optimization');
      }

      final health = DatabaseHealth(
        isHealthy: errors.isEmpty,
        version: versionResult.valueOrNull!,
        size: size,
        tableCount: tablesResult.valueOrNull!.length,
        indexCount: indexCount,
        errors: errors,
        warnings: warnings,
        integrityCheck: integrityOk,
      );

      return AppResult.success(health);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Health check failed: $e',
          e,
          _mapSQLiteError(e),
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> vacuum() async {
    if (!isOpen) {
      return AppResult.failure(
        const DatabaseException(
          'Database is closed',
          null,
          DatabaseErrorType.connection,
        ),
      );
    }

    try {
      await _database.execute('VACUUM');
      return AppResult.success(null);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Vacuum failed: $e',
          e,
          _mapSQLiteError(e),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    if (_isOpen) {
      await _database.close();
      _isOpen = false;
    }
  }

  @override
  bool get isOpen => _isOpen && _database.isOpen;

  @override
  String? get path => _database.path;

  /// 映射冲突算法
  sqflite.ConflictAlgorithm? _mapConflictAlgorithm(ConflictAlgorithm? algorithm) {
    switch (algorithm) {
      case ConflictAlgorithm.rollback:
        return sqflite.ConflictAlgorithm.rollback;
      case ConflictAlgorithm.abort:
        return sqflite.ConflictAlgorithm.abort;
      case ConflictAlgorithm.fail:
        return sqflite.ConflictAlgorithm.fail;
      case ConflictAlgorithm.ignore:
        return sqflite.ConflictAlgorithm.ignore;
      case ConflictAlgorithm.replace:
        return sqflite.ConflictAlgorithm.replace;
      case null:
        return null;
    }
  }

  /// 映射SQLite错误类型
  DatabaseErrorType _mapSQLiteError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('constraint')) {
      return DatabaseErrorType.constraint;
    }
    if (errorString.contains('syntax')) {
      return DatabaseErrorType.syntax;
    }
    if (errorString.contains('not found') || errorString.contains('no such')) {
      return DatabaseErrorType.notFound;
    }
    if (errorString.contains('permission') || errorString.contains('access')) {
      return DatabaseErrorType.permission;
    }
    if (errorString.contains('corrupt') || errorString.contains('malformed')) {
      return DatabaseErrorType.corruption;
    }
    if (errorString.contains('timeout')) {
      return DatabaseErrorType.timeout;
    }
    
    return DatabaseErrorType.unknown;
  }
}

/// SQLite事务实现
class _SQLiteTransaction implements DatabaseTransaction {
  _SQLiteTransaction(this._transaction);

  final sqflite.DatabaseExecutor _transaction;

  @override
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
  }) {
    return _transaction.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) {
    return _transaction.rawQuery(sql, arguments);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _transaction.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: _mapConflictAlgorithm(conflictAlgorithm),
    );
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _transaction.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: _mapConflictAlgorithm(conflictAlgorithm),
    );
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) {
    return _transaction.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  @override
  Future<int> rawDelete(String sql, [List<dynamic>? arguments]) {
    return _transaction.rawDelete(sql, arguments);
  }

  @override
  Future<int> rawUpdate(String sql, [List<dynamic>? arguments]) {
    return _transaction.rawUpdate(sql, arguments);
  }

  @override
  Future<int> rawInsert(String sql, [List<dynamic>? arguments]) {
    return _transaction.rawInsert(sql, arguments);
  }

  /// 映射冲突算法
  sqflite.ConflictAlgorithm? _mapConflictAlgorithm(ConflictAlgorithm? algorithm) {
    switch (algorithm) {
      case ConflictAlgorithm.rollback:
        return sqflite.ConflictAlgorithm.rollback;
      case ConflictAlgorithm.abort:
        return sqflite.ConflictAlgorithm.abort;
      case ConflictAlgorithm.fail:
        return sqflite.ConflictAlgorithm.fail;
      case ConflictAlgorithm.ignore:
        return sqflite.ConflictAlgorithm.ignore;
      case ConflictAlgorithm.replace:
        return sqflite.ConflictAlgorithm.replace;
      case null:
        return null;
    }
  }
}

/// SQLite批量操作实现
class _SQLiteBatch implements DatabaseBatch {
  _SQLiteBatch(this._batch);

  final sqflite.Batch _batch;

  @override
  void insert(
    String table,
    Map<String, dynamic> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _batch.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: _mapConflictAlgorithm(conflictAlgorithm),
    );
  }

  @override
  void update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _batch.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: _mapConflictAlgorithm(conflictAlgorithm),
    );
  }

  @override
  void delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) {
    _batch.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  @override
  void rawInsert(String sql, [List<dynamic>? arguments]) {
    _batch.rawInsert(sql, arguments);
  }

  @override
  void rawUpdate(String sql, [List<dynamic>? arguments]) {
    _batch.rawUpdate(sql, arguments);
  }

  @override
  void rawDelete(String sql, [List<dynamic>? arguments]) {
    _batch.rawDelete(sql, arguments);
  }

  @override
  Future<List<dynamic>> commit({bool? exclusive, bool? noResult}) {
    return _batch.commit(exclusive: exclusive, noResult: noResult);
  }

  /// 映射冲突算法
  sqflite.ConflictAlgorithm? _mapConflictAlgorithm(ConflictAlgorithm? algorithm) {
    switch (algorithm) {
      case ConflictAlgorithm.rollback:
        return sqflite.ConflictAlgorithm.rollback;
      case ConflictAlgorithm.abort:
        return sqflite.ConflictAlgorithm.abort;
      case ConflictAlgorithm.fail:
        return sqflite.ConflictAlgorithm.fail;
      case ConflictAlgorithm.ignore:
        return sqflite.ConflictAlgorithm.ignore;
      case ConflictAlgorithm.replace:
        return sqflite.ConflictAlgorithm.replace;
      case null:
        return null;
    }
  }
}

/// 数据库工厂
class SQLiteDatabaseFactory {
  /// 创建SQLite数据库
  static Future<AppResult<Database>> create(DatabaseConfig config) {
    return SQLiteDatabase.create(config);
  }

  /// 检查SQLite是否可用
  static Future<bool> isAvailable() async {
    try {
      // 尝试获取数据库路径来检查SQLite是否可用
      await sqflite.getDatabasesPath();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 删除数据库文件
  static Future<AppResult<void>> deleteDatabase(String path) async {
    try {
      await sqflite.deleteDatabase(path);
      return AppResult.success(null);
    } catch (e) {
      return AppResult.failure(
        DatabaseException(
          'Failed to delete database: $e',
          e,
          DatabaseErrorType.permission,
        ),
      );
    }
  }

  /// 获取数据库路径
  static Future<String> getDatabasesPath() {
    return sqflite.getDatabasesPath();
  }
} 