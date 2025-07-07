import 'package:flutter_test/flutter_test.dart';
import '../../lib/shared/types/result.dart';
import '../../lib/shared/cache/cache.dart';

void main() {
  group('基础设施核心功能测试', () {
    test('Result类型应该正常工作', () {
      // 测试成功结果
      final success = AppResult.success('test value');
      expect(success.isSuccess, true);
      expect(success.isFailure, false);
      expect(success.valueOrNull, 'test value');
      expect(success.errorOrNull, isNull);

      // 测试失败结果
      final failure = AppResult.failure(BusinessError('test error'));
      expect(failure.isSuccess, false);
      expect(failure.isFailure, true);
      expect(failure.valueOrNull, isNull);
      expect(failure.errorOrNull, isA<BusinessError>());
    });

    test('缓存配置应该正常验证', () {
      // 有效配置
      const validConfig = CacheConfig(
        maxSize: 100,
        maxDiskSize: 1024 * 1024,
      );
      final validResult = validConfig.validate();
      expect(validResult.isSuccess, true);

      // 无效配置
      const invalidConfig = CacheConfig(
        maxSize: -1,
        maxDiskSize: -1,
      );
      final invalidResult = invalidConfig.validate();
      expect(invalidResult.isFailure, true);
    });

    test('缓存条目应该正确处理过期', () {
      final now = DateTime.now();
      
      // 未过期的条目
      final notExpired = CacheEntry<String>(
        value: 'test',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      expect(notExpired.isExpired, false);

      // 已过期的条目
      final expired = CacheEntry<String>(
        value: 'test',
        createdAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );
      expect(expired.isExpired, true);

      // 永不过期的条目
      final neverExpires = CacheEntry<String>(
        value: 'test',
        createdAt: now,
      );
      expect(neverExpires.isExpired, false);
    });
  });
} 