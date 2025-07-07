import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../../lib/shared/cache/cache.dart';
import '../../lib/shared/cache/disk_cache.dart';
import '../../lib/shared/types/result.dart';

void main() {
  group('DiskCache', () {
    late Directory tempDir;
    late String cacheDir;
    late CacheConfig config;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('disk_cache_test_');
      cacheDir = tempDir.path;
      config = const CacheConfig(
        strategy: CacheStrategy.diskOnly,
        maxSize: 100,
        defaultTtl: Duration(hours: 1),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should create string cache successfully', () async {
      final result = await DiskCacheFactory.createStringCache(
        cacheDirectory: cacheDir,
        config: config,
      );

      expect(result.isSuccess, true);
      final cache = result.valueOrNull!;
      expect(cache.name, equals('string_cache'));
      
      await cache.close();
    });

    test('should set and get string values', () async {
      final result = await DiskCacheFactory.createStringCache(
        cacheDirectory: cacheDir,
        config: config,
      );
      expect(result.isSuccess, true);
      
      final cache = result.valueOrNull!;
      
      // 设置值
      final setResult = await cache.set('test_key', 'test_value');
      expect(setResult.isSuccess, true);
      
      // 获取值
      final getResult = await cache.get('test_key');
      expect(getResult.isSuccess, true);
      expect(getResult.valueOrNull, equals('test_value'));
      
      await cache.close();
    });

    test('should handle JSON cache', () async {
      final result = await DiskCacheFactory.createJsonCache(
        cacheDirectory: cacheDir,
        config: config,
      );
      expect(result.isSuccess, true);
      
      final cache = result.valueOrNull!;
      final testData = {'name': 'John', 'age': 30};
      
      // 设置JSON值
      final setResult = await cache.set('json_key', testData);
      expect(setResult.isSuccess, true);
      
      // 获取JSON值
      final getResult = await cache.get('json_key');
      expect(getResult.isSuccess, true);
      expect(getResult.valueOrNull, equals(testData));
      
      await cache.close();
    });
  });
} 