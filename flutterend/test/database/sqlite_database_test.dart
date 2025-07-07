import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../lib/shared/database/database.dart';
import '../../lib/shared/database/sqlite_database.dart';
import '../../lib/shared/types/result.dart';

void main() {
  // 初始化sqflite ffi用于测试
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SQLiteDatabase', () {
    late Directory tempDir;
    late String dbPath;
    late DatabaseConfig config;

    setUp(() async {
      // 创建临时目录
      tempDir = await Directory.systemTemp.createTemp('sqlite_test_');
      dbPath = path.join(tempDir.path, 'test.db');
      
      config = DatabaseConfig(
        name: 'test',
        version: 1,
        path: dbPath,
        migrations: [_TestMigration()],
      );
    });

    tearDown(() async {
      // 清理临时文件
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should create database successfully', () async {
      final result = await SQLiteDatabase.create(config);
      
      if (result.isFailure) {
        print('Database creation failed: ${result.errorOrNull}');
      }
      
      expect(result.isSuccess, true);
      final db = result.valueOrNull!;
      expect(db.isOpen, true);
      expect(db.path, dbPath);
      
      await db.close();
    });

    test('should execute basic operations', () async {
      final result = await SQLiteDatabase.create(config);
      
      if (result.isFailure) {
        print('Database creation failed: ${result.errorOrNull}');
      }
      
      expect(result.isSuccess, true);
      
      final db = result.valueOrNull!;
      
      // 插入数据
      final insertResult = await db.insert('test_table', {
        'name': 'Test User',
        'email': 'test@example.com',
      });
      expect(insertResult.isSuccess, true);
      
      // 查询数据
      final queryResult = await db.query('test_table');
      expect(queryResult.isSuccess, true);
      expect(queryResult.valueOrNull!.length, 1);
      
      await db.close();
    });
  });
}

/// 测试迁移类
class _TestMigration implements DatabaseMigration {
  @override
  int get version => 1;

  @override
  String get description => 'Create test table';

  @override
  Future<void> upgrade(DatabaseTransaction txn, int oldVersion, int newVersion) async {
    await txn.rawInsert('''
      CREATE TABLE test_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL
      )
    ''');
  }

  @override
  Future<bool> canMigrate(DatabaseTransaction txn, int oldVersion) async {
    return true;
  }

  @override
  Future<void> downgrade(DatabaseTransaction txn, int oldVersion, int newVersion) async {
    await txn.rawInsert('DROP TABLE IF EXISTS test_table');
  }
} 