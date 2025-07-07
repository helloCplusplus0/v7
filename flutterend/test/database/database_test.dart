import 'package:flutter_test/flutter_test.dart';
import '../../lib/shared/database/database.dart';
import '../../lib/shared/types/result.dart';

void main() {
  group('DatabaseErrorType', () {
    test('should have all expected error types', () {
      const expectedTypes = {
        DatabaseErrorType.connection,
        DatabaseErrorType.syntax,
        DatabaseErrorType.constraint,
        DatabaseErrorType.notFound,
        DatabaseErrorType.permission,
        DatabaseErrorType.corruption,
        DatabaseErrorType.migration,
        DatabaseErrorType.timeout,
        DatabaseErrorType.unknown,
      };
      
      expect(DatabaseErrorType.values.toSet(), equals(expectedTypes));
    });
    
    test('should have correct string representations', () {
      expect(DatabaseErrorType.connection.name, equals('connection'));
      expect(DatabaseErrorType.syntax.name, equals('syntax'));
      expect(DatabaseErrorType.unknown.name, equals('unknown'));
    });
  });

  group('DatabaseException', () {
    test('should create with minimal parameters', () {
      const exception = DatabaseException('Test error');
      
      expect(exception.message, equals('Test error'));
      expect(exception.type, equals(DatabaseErrorType.unknown));
      expect(exception.table, isNull);
      expect(exception.operation, isNull);
      expect(exception.sql, isNull);
      expect(exception.cause, isNull);
    });
    
    test('should create with all parameters', () {
      final originalError = Exception('Original error');
      final exception = DatabaseException(
        'Database connection failed',
        originalError,
        DatabaseErrorType.connection,
        'users',
        'SELECT',
        'SELECT * FROM users',
      );
      
      expect(exception.message, equals('Database connection failed'));
      expect(exception.type, equals(DatabaseErrorType.connection));
      expect(exception.table, equals('users'));
      expect(exception.operation, equals('SELECT'));
      expect(exception.sql, equals('SELECT * FROM users'));
      expect(exception.cause, equals(originalError));
    });
    
    test('should have proper toString representation', () {
      final exception = DatabaseException(
        'Query failed',
        null,
        DatabaseErrorType.syntax,
        'users',
        'INSERT',
        'INSERT INTO users VALUES (1, "test")',
      );
      
      final result = exception.toString();
      expect(result, contains('DatabaseException'));
      expect(result, contains('syntax'));
      expect(result, contains('Query failed'));
      expect(result, contains('users'));
    });
    
    test('toString should handle unknown type correctly', () {
      const exception = DatabaseException('Unknown error');
      final result = exception.toString();
      expect(result, equals('DatabaseException: Unknown error'));
    });
  });

  group('DatabaseConfigException', () {
    test('should create with message only', () {
      const exception = DatabaseConfigException('Invalid config');
      expect(exception.message, equals('Invalid config'));
      expect(exception.cause, isNull);
    });
    
    test('should create with cause', () {
      final originalError = ArgumentError('Invalid argument');
      final exception = DatabaseConfigException('Config validation failed', originalError);
      expect(exception.message, equals('Config validation failed'));
      expect(exception.cause, equals(originalError));
    });
  });

  group('ConflictAlgorithm', () {
    test('should have all expected algorithms', () {
      const expectedAlgorithms = {
        ConflictAlgorithm.rollback,
        ConflictAlgorithm.abort,
        ConflictAlgorithm.fail,
        ConflictAlgorithm.ignore,
        ConflictAlgorithm.replace,
      };
      
      expect(ConflictAlgorithm.values.toSet(), equals(expectedAlgorithms));
    });
  });

  group('TableInfo', () {
    test('should create with required parameters', () {
      const tableInfo = TableInfo(
        name: 'users',
        type: 'table',
        rootPage: 1,
        sql: 'CREATE TABLE users (id INTEGER PRIMARY KEY)',
      );
      
      expect(tableInfo.name, equals('users'));
      expect(tableInfo.type, equals('table'));
      expect(tableInfo.rootPage, equals(1));
      expect(tableInfo.sql, equals('CREATE TABLE users (id INTEGER PRIMARY KEY)'));
    });
    
    test('should have proper toString representation', () {
      const tableInfo = TableInfo(
        name: 'products',
        type: 'table',
        rootPage: 2,
        sql: null,
      );
      
      expect(tableInfo.toString(), equals('TableInfo(name: products, type: table)'));
    });
    
    test('should support equality comparison', () {
      const tableInfo1 = TableInfo(
        name: 'users',
        type: 'table',
        rootPage: 1,
        sql: 'CREATE TABLE users',
      );
      
      const tableInfo2 = TableInfo(
        name: 'users',
        type: 'table',
        rootPage: 1,
        sql: 'CREATE TABLE users',
      );
      
      const tableInfo3 = TableInfo(
        name: 'products',
        type: 'table',
        rootPage: 1,
        sql: 'CREATE TABLE users',
      );
      
      expect(tableInfo1, equals(tableInfo2));
      expect(tableInfo1, isNot(equals(tableInfo3)));
      expect(tableInfo1.hashCode, equals(tableInfo2.hashCode));
    });
  });

  group('ColumnInfo', () {
    test('should create with all parameters', () {
      const columnInfo = ColumnInfo(
        cid: 0,
        name: 'id',
        type: 'INTEGER',
        notNull: true,
        defaultValue: null,
        primaryKey: true,
      );
      
      expect(columnInfo.cid, equals(0));
      expect(columnInfo.name, equals('id'));
      expect(columnInfo.type, equals('INTEGER'));
      expect(columnInfo.notNull, isTrue);
      expect(columnInfo.defaultValue, isNull);
      expect(columnInfo.primaryKey, isTrue);
    });
    
    test('should have proper toString representation', () {
      const columnInfo = ColumnInfo(
        cid: 1,
        name: 'email',
        type: 'TEXT',
        notNull: false,
        defaultValue: 'unknown@example.com',
        primaryKey: false,
      );
      
      expect(columnInfo.toString(), equals('ColumnInfo(name: email, type: TEXT, notNull: false)'));
    });
    
    test('should support equality comparison', () {
      const columnInfo1 = ColumnInfo(
        cid: 0,
        name: 'id',
        type: 'INTEGER',
        notNull: true,
        defaultValue: null,
        primaryKey: true,
      );
      
      const columnInfo2 = ColumnInfo(
        cid: 0,
        name: 'id',
        type: 'INTEGER',
        notNull: true,
        defaultValue: null,
        primaryKey: true,
      );
      
      const columnInfo3 = ColumnInfo(
        cid: 1,
        name: 'name',
        type: 'TEXT',
        notNull: false,
        defaultValue: null,
        primaryKey: false,
      );
      
      expect(columnInfo1, equals(columnInfo2));
      expect(columnInfo1, isNot(equals(columnInfo3)));
      expect(columnInfo1.hashCode, equals(columnInfo2.hashCode));
    });
  });

  group('DatabaseHealth', () {
    test('should create with required parameters', () {
      final health = DatabaseHealth(
        isHealthy: true,
        version: 1,
        size: 1024,
        tableCount: 5,
        indexCount: 3,
      );
      
      expect(health.isHealthy, isTrue);
      expect(health.version, equals(1));
      expect(health.size, equals(1024));
      expect(health.tableCount, equals(5));
      expect(health.indexCount, equals(3));
      expect(health.errors, isEmpty);
      expect(health.warnings, isEmpty);
    });
    
    test('should create with optional parameters', () {
      final lastVacuum = DateTime(2024, 1, 1);
      final health = DatabaseHealth(
        isHealthy: false,
        version: 2,
        size: 2048,
        tableCount: 10,
        indexCount: 7,
        errors: ['Constraint violation'],
        warnings: ['Index not used'],
        lastVacuum: lastVacuum,
        integrityCheck: false,
      );
      
      expect(health.isHealthy, isFalse);
      expect(health.errors, equals(['Constraint violation']));
      expect(health.warnings, equals(['Index not used']));
      expect(health.lastVacuum, equals(lastVacuum));
      expect(health.integrityCheck, isFalse);
    });
    
    test('should format size correctly', () {
      const healthB = DatabaseHealth(isHealthy: true, version: 1, size: 512, tableCount: 1, indexCount: 0);
      const healthKB = DatabaseHealth(isHealthy: true, version: 1, size: 1536, tableCount: 1, indexCount: 0); // 1.5KB
      const healthMB = DatabaseHealth(isHealthy: true, version: 1, size: 1572864, tableCount: 1, indexCount: 0); // 1.5MB
      const healthGB = DatabaseHealth(isHealthy: true, version: 1, size: 1610612736, tableCount: 1, indexCount: 0); // 1.5GB
      
      expect(healthB.formattedSize, equals('512B'));
      expect(healthKB.formattedSize, equals('1.5KB'));
      expect(healthMB.formattedSize, equals('1.5MB'));
      expect(healthGB.formattedSize, equals('1.5GB'));
    });
    
    test('should detect need for optimization', () {
      final oldVacuum = DateTime.now().subtract(const Duration(days: 35));
      const healthWithWarnings = DatabaseHealth(
        isHealthy: true,
        version: 1,
        size: 1024,
        tableCount: 1,
        indexCount: 0,
        warnings: ['Performance warning'],
      );
      
      final healthWithOldVacuum = DatabaseHealth(
        isHealthy: true,
        version: 1,
        size: 1024,
        tableCount: 1,
        indexCount: 0,
        lastVacuum: oldVacuum,
      );
      
      const healthGood = DatabaseHealth(
        isHealthy: true,
        version: 1,
        size: 1024,
        tableCount: 1,
        indexCount: 0,
      );
      
      expect(healthWithWarnings.needsOptimization, isTrue);
      expect(healthWithOldVacuum.needsOptimization, isTrue);
      expect(healthGood.needsOptimization, isFalse);
    });
    
    test('should have proper toString representation', () {
      const health = DatabaseHealth(
        isHealthy: true,
        version: 2,
        size: 2048,
        tableCount: 3,
        indexCount: 1,
      );
      
      expect(health.toString(), 
        equals('DatabaseHealth(healthy: true, version: 2, size: 2.0KB, tables: 3, indexes: 1)'));
    });
  });

  group('DatabaseConfig', () {
    test('should create with minimal parameters', () {
      const config = DatabaseConfig(
        name: 'test.db',
        version: 1,
      );
      
      expect(config.name, equals('test.db'));
      expect(config.version, equals(1));
      expect(config.path, isNull);
      expect(config.migrations, isEmpty);
      expect(config.readOnly, isFalse);
      expect(config.singleInstance, isTrue);
      expect(config.enableForeignKeys, isTrue);
      expect(config.enableWAL, isTrue);
      expect(config.maxConnections, equals(1));
    });
    
    test('should create with all parameters', () {
      const config = DatabaseConfig(
        name: 'app.db',
        version: 3,
        path: '/data/app.db',
        migrations: [],
        readOnly: true,
        singleInstance: false,
        pageSize: 4096,
        cacheSize: 2000,
        enableForeignKeys: false,
        enableWAL: false,
        busyTimeout: Duration(seconds: 30),
        maxConnections: 5,
        connectionTimeout: Duration(seconds: 10),
      );
      
      expect(config.name, equals('app.db'));
      expect(config.version, equals(3));
      expect(config.path, equals('/data/app.db'));
      expect(config.readOnly, isTrue);
      expect(config.singleInstance, isFalse);
      expect(config.pageSize, equals(4096));
      expect(config.cacheSize, equals(2000));
      expect(config.enableForeignKeys, isFalse);
      expect(config.enableWAL, isFalse);
      expect(config.busyTimeout, equals(const Duration(seconds: 30)));
      expect(config.maxConnections, equals(5));
      expect(config.connectionTimeout, equals(const Duration(seconds: 10)));
    });
    
    test('should validate name correctly', () {
      expect(() => const DatabaseConfig(name: '', version: 1).validate(), 
        throwsA(isA<DatabaseConfigException>()));
      
      expect(() => const DatabaseConfig(name: 'valid.db', version: 1).validate(), 
        returnsNormally);
    });
    
    test('should validate version correctly', () {
      expect(() => const DatabaseConfig(name: 'test.db', version: 0).validate(), 
        throwsA(isA<DatabaseConfigException>()));
      
      expect(() => const DatabaseConfig(name: 'test.db', version: -1).validate(), 
        throwsA(isA<DatabaseConfigException>()));
      
      expect(() => const DatabaseConfig(name: 'test.db', version: 1).validate(), 
        returnsNormally);
    });
    
    test('should validate page size correctly', () {
      expect(() => const DatabaseConfig(name: 'test.db', version: 1, pageSize: 256).validate(), 
        throwsA(isA<DatabaseConfigException>()));
      
      expect(() => const DatabaseConfig(name: 'test.db', version: 1, pageSize: 70000).validate(), 
        throwsA(isA<DatabaseConfigException>()));
      
      expect(() => const DatabaseConfig(name: 'test.db', version: 1, pageSize: 4096).validate(), 
        returnsNormally);
    });
    
    test('should validate cache size correctly', () {
      expect(() => const DatabaseConfig(name: 'test.db', version: 1, cacheSize: -1).validate(), 
        throwsA(isA<DatabaseConfigException>()));
      
      expect(() => const DatabaseConfig(name: 'test.db', version: 1, cacheSize: 0).validate(), 
        returnsNormally);
      
      expect(() => const DatabaseConfig(name: 'test.db', version: 1, cacheSize: 1000).validate(), 
        returnsNormally);
    });
    
    test('should validate max connections correctly', () {
      expect(() => const DatabaseConfig(name: 'test.db', version: 1, maxConnections: 0).validate(), 
        throwsA(isA<DatabaseConfigException>()));
      
      expect(() => const DatabaseConfig(name: 'test.db', version: 1, maxConnections: -1).validate(), 
        throwsA(isA<DatabaseConfigException>()));
      
      expect(() => const DatabaseConfig(name: 'test.db', version: 1, maxConnections: 1).validate(), 
        returnsNormally);
    });
    
    test('should copy with different parameters', () {
      const original = DatabaseConfig(name: 'test.db', version: 1, readOnly: false);
      final copied = original.copyWith(version: 2, readOnly: true);
      
      expect(copied.name, equals('test.db'));
      expect(copied.version, equals(2));
      expect(copied.readOnly, isTrue);
    });
  });

  group('DatabaseFeature', () {
    test('should have all expected features', () {
      const expectedFeatures = {
        DatabaseFeature.transactions,
        DatabaseFeature.batchOperations,
        DatabaseFeature.foreignKeys,
        DatabaseFeature.writeAheadLogging,
        DatabaseFeature.fullTextSearch,
        DatabaseFeature.jsonSupport,
        DatabaseFeature.encryption,
        DatabaseFeature.compression,
      };
      
      expect(DatabaseFeature.values.toSet(), equals(expectedFeatures));
    });
  });

  group('JoinType', () {
    test('should have correct SQL representations', () {
      expect(JoinType.inner.sql, equals('INNER JOIN'));
      expect(JoinType.left.sql, equals('LEFT JOIN'));
      expect(JoinType.right.sql, equals('RIGHT JOIN'));
      expect(JoinType.full.sql, equals('FULL OUTER JOIN'));
      expect(JoinType.cross.sql, equals('CROSS JOIN'));
    });
  });

  group('QueryBuilder', () {
    test('should build simple SELECT query', () {
      final query = QueryBuilder.table('users')
          .select(['id', 'name'])
          .where('age > ?', [18])
          .orderBy('name')
          .limit(10);
      
      expect(query.toSql(), equals('SELECT id, name FROM users WHERE age > ? ORDER BY name ASC LIMIT 10'));
    });
    
    test('should build SELECT ALL query', () {
      final query = QueryBuilder.table('products');
      expect(query.toSql(), equals('SELECT * FROM products'));
    });
    
    test('should build DISTINCT query', () {
      final query = QueryBuilder.table('orders')
          .select(['customer_id'])
          .distinct();
      
      expect(query.toSql(), equals('SELECT DISTINCT customer_id FROM orders'));
    });
    
    test('should build complex query with GROUP BY and HAVING', () {
      final query = QueryBuilder.table('sales')
          .select(['product_id', 'SUM(amount) as total'])
          .where('date >= ?', ['2024-01-01'])
          .groupBy('product_id')
          .having('SUM(amount) > 1000')
          .orderBy('total', desc: true)
          .limit(5, offset: 10);
      
      final expectedSql = 'SELECT product_id, SUM(amount) as total FROM sales '
                         'WHERE date >= ? GROUP BY product_id HAVING SUM(amount) > 1000 '
                         'ORDER BY total DESC LIMIT 5 OFFSET 10';
      expect(query.toSql(), equals(expectedSql));
    });
    
    test('should build query with AND conditions', () {
      final query = QueryBuilder.table('users')
          .where('age > ?', [18])
          .and('status = ?', ['active'])
          .and('role IN (?, ?)', ['admin', 'user']);
      
      expect(query.toSql(), equals('SELECT * FROM users WHERE ((age > ?) AND (status = ?)) AND (role IN (?, ?))'));
    });
    
    test('should build query with OR conditions', () {
      final query = QueryBuilder.table('products')
          .where('category = ?', ['electronics'])
          .or('price < ?', [100])
          .or('on_sale = ?', [true]);
      
      expect(query.toSql(), equals('SELECT * FROM products WHERE ((category = ?) OR (price < ?)) OR (on_sale = ?)'));
    });
    
    test('should build query with JOINs', () {
      final query = QueryBuilder.table('users')
          .select(['users.id', 'users.name', 'profiles.bio'])
          .innerJoin('profiles', 'users.id = profiles.user_id')
          .leftJoin('addresses', 'users.id = addresses.user_id')
          .where('users.active = ?', [true]);
      
      final expectedSql = 'SELECT users.id, users.name, profiles.bio FROM users '
                         'INNER JOIN profiles ON users.id = profiles.user_id '
                         'LEFT JOIN addresses ON users.id = addresses.user_id '
                         'WHERE users.active = ?';
      expect(query.toSql(), equals(expectedSql));
    });
    
    test('should build query with custom JOIN', () {
      final query = QueryBuilder.table('orders')
          .join('customers', 'orders.customer_id = customers.id', type: JoinType.right);
      
      expect(query.toSql(), equals('SELECT * FROM orders RIGHT JOIN customers ON orders.customer_id = customers.id'));
    });
    
    test('should build query with multiple ORDER BY', () {
      final query = QueryBuilder.table('products')
          .orderByMultiple(['category', 'price', 'name'], desc: true);
      
      expect(query.toSql(), equals('SELECT * FROM products ORDER BY category DESC, price DESC, name DESC'));
    });
    
    test('should build query with UNION', () {
      final query1 = QueryBuilder.table('employees').select(['name', 'email']);
      final query2 = QueryBuilder.table('customers').select(['name', 'email']);
      
      query1.union(query2);
      
      expect(query1.toSql(), equals('SELECT name, email FROM employees UNION (SELECT name, email FROM customers)'));
    });
    
    test('should build query with UNION ALL', () {
      final query1 = QueryBuilder.table('products').select(['name']);
      final query2 = QueryBuilder.table('archived_products').select(['name']);
      
      query1.unionAll(query2);
      
      expect(query1.toSql(), equals('SELECT name FROM products UNION ALL (SELECT name FROM archived_products)'));
    });
    
    test('should reset query builder', () {
      final query = QueryBuilder.table('users')
          .select(['id', 'name'])
          .where('age > ?', [18])
          .limit(10);
      
      expect(query.toSql(), contains('WHERE'));
      
      query.reset();
      expect(query.toSql(), equals('SELECT * FROM users'));
    });
    
    test('should handle parameters correctly', () {
      final query = QueryBuilder.table('users')
          .where('age > ?', [18])
          .and('name LIKE ?', ['%John%'])
          .or('status IN (?, ?)', ['active', 'pending']);
      
      expect(query.parameters, equals([18, '%John%', 'active', 'pending']));
    });
  });

  group('DatabaseEvent', () {
    test('should create database connected event', () {
      final event = DatabaseConnectedEvent(path: '/data/test.db');
      
      expect(event.path, equals('/data/test.db'));
      expect(event.eventType, equals('DatabaseConnectedEvent'));
      expect(event.timestamp, isA<DateTime>());
    });
    
    test('should create database disconnected event', () {
      final customTime = DateTime(2024, 1, 1, 12, 0, 0);
      final event = DatabaseDisconnectedEvent(path: '/data/test.db', timestamp: customTime);
      
      expect(event.path, equals('/data/test.db'));
      expect(event.timestamp, equals(customTime));
    });
    
    test('should create database migration event', () {
      final event = DatabaseMigrationEvent(
        fromVersion: 1,
        toVersion: 2,
        description: 'Add user profile table',
      );
      
      expect(event.fromVersion, equals(1));
      expect(event.toVersion, equals(2));
      expect(event.description, equals('Add user profile table'));
    });
    
    test('should create database error event', () {
      const error = DatabaseException('Connection failed');
      final event = DatabaseErrorEvent(
        error: error,
        operation: 'connect',
        table: 'users',
      );
      
      expect(event.error, equals(error));
      expect(event.operation, equals('connect'));
      expect(event.table, equals('users'));
    });
    
    test('should create database query event', () {
      final event = DatabaseQueryEvent(
        sql: 'SELECT * FROM users',
        duration: const Duration(milliseconds: 150),
        rowsAffected: 5,
      );
      
      expect(event.sql, equals('SELECT * FROM users'));
      expect(event.duration, equals(const Duration(milliseconds: 150)));
      expect(event.rowsAffected, equals(5));
    });
  });

  group('ObservableDatabase', () {
    late TestObservableDatabase testDb;
    
    setUp(() {
      testDb = TestObservableDatabase();
    });
    
    test('should add and remove listeners', () {
      var eventCount = 0;
      void listener(DatabaseEvent event) {
        eventCount++;
      }
      
      testDb.addListener(listener);
      testDb.testNotifyListeners(DatabaseConnectedEvent(path: '/test.db'));
      expect(eventCount, equals(1));
      
      testDb.removeListener(listener);
      testDb.testNotifyListeners(DatabaseDisconnectedEvent(path: '/test.db'));
      expect(eventCount, equals(1)); // Should not increase
    });
    
    test('should handle listener errors gracefully', () {
      void badListener(DatabaseEvent event) {
        throw Exception('Listener error');
      }
      
      var goodEventCount = 0;
      void goodListener(DatabaseEvent event) {
        goodEventCount++;
      }
      
      testDb.addListener(badListener);
      testDb.addListener(goodListener);
      
      // Should not throw despite bad listener
      expect(() => testDb.testNotifyListeners(DatabaseConnectedEvent(path: '/test.db')), 
        returnsNormally);
      expect(goodEventCount, equals(1));
    });
    
    test('should clear all listeners', () {
      var eventCount = 0;
      void listener(DatabaseEvent event) {
        eventCount++;
      }
      
      testDb.addListener(listener);
      testDb.addListener(listener);
      testDb.clearListeners();
      
      testDb.testNotifyListeners(DatabaseConnectedEvent(path: '/test.db'));
      expect(eventCount, equals(0));
    });
    
    test('should support typed listeners', () {
      var errorEventCount = 0;
      var connectionEventCount = 0;
      
      testDb.addTypedListener<DatabaseErrorEvent>((event) {
        errorEventCount++;
      });
      
      testDb.onConnectionChange((event) {
        connectionEventCount++;
      });
      
      // Fire different event types
      testDb.testNotifyListeners(DatabaseErrorEvent(error: 'Error', operation: 'test'));
      testDb.testNotifyListeners(DatabaseConnectedEvent(path: '/test.db'));
      testDb.testNotifyListeners(DatabaseDisconnectedEvent(path: '/test.db'));
      testDb.testNotifyListeners(DatabaseMigrationEvent(
        fromVersion: 1, 
        toVersion: 2, 
        description: 'Migration'
      ));
      
      expect(errorEventCount, equals(1));
      expect(connectionEventCount, equals(2)); // Connected + Disconnected
    });
    
    test('should support error-specific listener', () {
      var errorEventCount = 0;
      
      testDb.onError((event) {
        errorEventCount++;
      });
      
      testDb.testNotifyListeners(DatabaseErrorEvent(error: 'Error', operation: 'test'));
      testDb.testNotifyListeners(DatabaseConnectedEvent(path: '/test.db'));
      
      expect(errorEventCount, equals(1));
    });
  });

  group('Integration Tests', () {
    test('should handle complex query building scenarios', () {
      // 测试复杂的查询构建场景
      final complexQuery = QueryBuilder.table('orders')
          .select([
            'o.id',
            'o.total',
            'c.name as customer_name',
            'p.name as product_name',
            'COUNT(oi.id) as item_count'
          ])
          .innerJoin('customers c', 'o.customer_id = c.id')
          .leftJoin('order_items oi', 'o.id = oi.order_id')
          .leftJoin('products p', 'oi.product_id = p.id')
          .where('o.created_at >= ?', ['2024-01-01'])
          .and('o.status IN (?, ?)', ['confirmed', 'shipped'])
          .groupBy('o.id, c.name')
          .having('COUNT(oi.id) > 0')
          .orderByMultiple(['o.total', 'o.created_at'], desc: true)
          .limit(50, offset: 0);
      
      final expectedSql = 'SELECT o.id, o.total, c.name as customer_name, p.name as product_name, COUNT(oi.id) as item_count '
                         'FROM orders '
                         'INNER JOIN customers c ON o.customer_id = c.id '
                         'LEFT JOIN order_items oi ON o.id = oi.order_id '
                         'LEFT JOIN products p ON oi.product_id = p.id '
                         'WHERE (o.created_at >= ?) AND (o.status IN (?, ?)) '
                         'GROUP BY o.id, c.name '
                         'HAVING COUNT(oi.id) > 0 '
                         'ORDER BY o.total DESC, o.created_at DESC '
                         'LIMIT 50 OFFSET 0';
      
      expect(complexQuery.toSql(), equals(expectedSql));
      expect(complexQuery.parameters, equals(['2024-01-01', 'confirmed', 'shipped']));
    });
    
    test('should validate database configuration thoroughly', () {
      // 有效配置
      const validConfig = DatabaseConfig(
        name: 'app.db',
        version: 1,
        pageSize: 4096,
        cacheSize: 1000,
        maxConnections: 1,
      );
      
      expect(() => validConfig.validate(), returnsNormally);
      
      // 测试各种无效配置
      const invalidConfigs = [
        DatabaseConfig(name: '', version: 1), // 空名称
        DatabaseConfig(name: 'test.db', version: 0), // 无效版本
        DatabaseConfig(name: 'test.db', version: 1, pageSize: 256), // 页面太小
        DatabaseConfig(name: 'test.db', version: 1, pageSize: 70000), // 页面太大
        DatabaseConfig(name: 'test.db', version: 1, cacheSize: -1), // 负缓存大小
        DatabaseConfig(name: 'test.db', version: 1, maxConnections: 0), // 无连接
      ];
      
      for (final config in invalidConfigs) {
        expect(() => config.validate(), throwsA(isA<DatabaseConfigException>()));
      }
    });
    
    test('should handle database events lifecycle', () {
      final testDb = TestObservableDatabase();
      final events = <DatabaseEvent>[];
      
      // 添加通用监听器
      testDb.addListener((event) {
        events.add(event);
      });
      
      // 模拟数据库生命周期
      testDb.testNotifyListeners(DatabaseConnectedEvent(path: '/test.db'));
      testDb.testNotifyListeners(DatabaseMigrationEvent(
        fromVersion: 1,
        toVersion: 2,
        description: 'Schema update',
      ));
      testDb.testNotifyListeners(DatabaseQueryEvent(
        sql: 'SELECT COUNT(*) FROM users',
        duration: const Duration(milliseconds: 50),
        rowsAffected: 1,
      ));
      testDb.testNotifyListeners(DatabaseErrorEvent(
        error: 'Connection timeout',
        operation: 'query',
        table: 'users',
      ));
      testDb.testNotifyListeners(DatabaseDisconnectedEvent(path: '/test.db'));
      
      // 验证事件序列
      expect(events.length, equals(5));
      expect(events[0], isA<DatabaseConnectedEvent>());
      expect(events[1], isA<DatabaseMigrationEvent>());
      expect(events[2], isA<DatabaseQueryEvent>());
      expect(events[3], isA<DatabaseErrorEvent>());
      expect(events[4], isA<DatabaseDisconnectedEvent>());
    });
  });
}

// 测试用的可观察数据库实现
class TestObservableDatabase implements Database {
  final List<DatabaseListener> _listeners = [];
  
  @override
  bool get isOpen => true;
  
  @override
  String? get path => '/test.db';
  
  // ObservableDatabase mixin 功能的手动实现
  void addListener(DatabaseListener listener) {
    _listeners.add(listener);
  }
  
  void removeListener(DatabaseListener listener) {
    _listeners.remove(listener);
  }
  
  void notifyListeners(DatabaseEvent event) {
    for (final listener in _listeners) {
      try {
        listener(event);
      } catch (e) {
        // 忽略监听器错误
      }
    }
  }
  
  void clearListeners() {
    _listeners.clear();
  }
  
  void addTypedListener<T extends DatabaseEvent>(void Function(T event) listener) {
    addListener((event) {
      if (event is T) {
        listener(event);
      }
    });
  }
  
  void onError(void Function(DatabaseErrorEvent event) listener) {
    addTypedListener<DatabaseErrorEvent>(listener);
  }
  
  void onConnectionChange(void Function(DatabaseEvent event) listener) {
    addListener((event) {
      if (event is DatabaseConnectedEvent || event is DatabaseDisconnectedEvent) {
        listener(event);
      }
    });
  }
  
  // 测试方法，暴露受保护的 notifyListeners 方法
  void testNotifyListeners(DatabaseEvent event) {
    notifyListeners(event);
  }
  
  // 实现所有必需的Database方法（简化版本）
  @override
  Future<void> close() async {}
  
  @override
  Future<AppResult<void>> batch(Future<void> Function(DatabaseBatch batch) action) async {
    return Result.success(null);
  }
  
  @override
  Future<AppResult<void>> createIndex(String name, String table, List<String> columns) async {
    return Result.success(null);
  }
  
  @override
  Future<AppResult<int>> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    return Result.success(1);
  }
  
  @override
  Future<AppResult<void>> dropIndex(String name) async {
    return Result.success(null);
  }
  
  @override
  Future<AppResult<List<ColumnInfo>>> getTableColumns(String table) async {
    return Result.success([]);
  }
  
  @override
  Future<AppResult<List<TableInfo>>> getTables() async {
    return Result.success([]);
  }
  
  @override
  Future<AppResult<int>> getVersion() async {
    return Result.success(1);
  }
  
  @override
  Future<AppResult<DatabaseHealth>> healthCheck() async {
    return Result.success(DatabaseHealth(
      isHealthy: true,
      version: 1,
      size: 1024,
      tableCount: 1,
      indexCount: 0,
    ));
  }
  
  @override
  Future<AppResult<int>> insert(String table, Map<String, dynamic> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    return Result.success(1);
  }
  
  @override
  Future<AppResult<List<int>>> insertBatch(String table, List<Map<String, dynamic>> values, {ConflictAlgorithm? conflictAlgorithm}) async {
    return Result.success([1, 2, 3]);
  }
  
  @override
  Future<AppResult<List<Map<String, dynamic>>>> query(String table, {List<String>? columns, String? where, List<dynamic>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset, bool? distinct}) async {
    return Result.success([]);
  }
  
  @override
  Future<AppResult<int>> rawDelete(String sql, [List<dynamic>? arguments]) async {
    return Result.success(1);
  }
  
  @override
  Future<AppResult<int>> rawInsert(String sql, [List<dynamic>? arguments]) async {
    return Result.success(1);
  }
  
  @override
  Future<AppResult<List<Map<String, dynamic>>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    return Result.success([]);
  }
  
  @override
  Future<AppResult<int>> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    return Result.success(1);
  }
  
  @override
  Future<AppResult<void>> setVersion(int version) async {
    return Result.success(null);
  }
  
  @override
  Future<AppResult<bool>> tableExists(String table) async {
    return Result.success(true);
  }
  
  @override
  Future<AppResult<T>> transaction<T>(Future<T> Function(DatabaseTransaction txn) action, {bool? exclusive}) async {
    return Result.success(null as T);
  }
  
  @override
  Future<AppResult<int>> update(String table, Map<String, dynamic> values, {String? where, List<dynamic>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) async {
    return Result.success(1);
  }
  
  @override
  Future<AppResult<void>> vacuum() async {
    return Result.success(null);
  }
} 