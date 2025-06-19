// tests/shared/utils/utils.test.ts
import { describe, test, expect, beforeEach, vi, afterEach } from 'vitest';
import {
  delay,
  generateId,
  deepClone,
  debounce,
  throttle,
  formatFileSize,
  safeJsonParse
} from '../../../shared/utils';

describe('Utils', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('delay', () => {
    test('应该延迟指定的毫秒数', async () => {
      const start = Date.now();
      const delayPromise = delay(1000);
      
      vi.advanceTimersByTime(1000);
      await delayPromise;
      
      // 在fake timers下，时间不会真正流逝
      expect(vi.getTimerCount()).toBe(0);
    });

    test('应该支持0毫秒延迟', async () => {
      const delayPromise = delay(0);
      
      vi.advanceTimersByTime(0);
      await delayPromise;
      
      expect(vi.getTimerCount()).toBe(0);
    });
  });

  describe('generateId', () => {
    test('应该生成ID', () => {
      const id = generateId();
      
      expect(typeof id).toBe('string');
      expect(id.length).toBeGreaterThan(0);
    });

    test('应该生成唯一的ID', () => {
      const ids = new Set();
      
      // 生成1000个ID，应该都是唯一的
      for (let i = 0; i < 1000; i++) {
        ids.add(generateId());
      }
      
      expect(ids.size).toBe(1000);
    });

    test('应该包含时间戳和随机字符', () => {
      const id = generateId();
      
      // ID格式应该是 timestamp-randomString
      expect(id).toMatch(/^\d+-[a-z0-9]+$/);
    });

    test('应该生成不同的ID', () => {
      const id1 = generateId();
      const id2 = generateId();
      
      expect(id1).not.toBe(id2);
    });
  });

  describe('deepClone', () => {
    test('应该深度克隆对象', () => {
      const original = {
        name: 'test',
        nested: {
          value: 42,
          array: [1, 2, { deep: true }]
        }
      };
      
      const cloned = deepClone(original);
      
      expect(cloned).toEqual(original);
      expect(cloned).not.toBe(original);
      expect(cloned.nested).not.toBe(original.nested);
      expect(cloned.nested.array).not.toBe(original.nested.array);
      expect(cloned.nested.array[2]).not.toBe(original.nested.array[2]);
    });

    test('应该克隆数组', () => {
      const original = [1, 2, { value: 3 }, [4, 5]];
      const cloned = deepClone(original);
      
      expect(cloned).toEqual(original);
      expect(cloned).not.toBe(original);
      expect(cloned[2]).not.toBe(original[2]);
      expect(cloned[3]).not.toBe(original[3]);
    });

    test('应该处理基本类型', () => {
      expect(deepClone(42)).toBe(42);
      expect(deepClone('string')).toBe('string');
      expect(deepClone(true)).toBe(true);
      expect(deepClone(null)).toBe(null);
      expect(deepClone(undefined)).toBe(undefined);
    });

    test('应该处理Date对象', () => {
      const date = new Date('2023-01-01');
      const cloned = deepClone(date);
      
      expect(cloned).toEqual(date);
      expect(cloned).not.toBe(date);
      expect(cloned instanceof Date).toBe(true);
    });

    test('应该处理复杂嵌套对象', () => {
      const obj = {
        name: 'test',
        data: {
          numbers: [1, 2, 3],
          nested: {
            value: 'deep',
            flag: true
          }
        }
      };
      
      const cloned = deepClone(obj);
      
      expect(cloned).toEqual(obj);
      expect(cloned).not.toBe(obj);
      expect(cloned.data).not.toBe(obj.data);
      expect(cloned.data.nested).not.toBe(obj.data.nested);
    });
  });

  describe('debounce', () => {
    test('应该延迟函数执行', () => {
      const fn = vi.fn();
      const debouncedFn = debounce(fn, 1000);
      
      debouncedFn();
      expect(fn).not.toHaveBeenCalled();
      
      vi.advanceTimersByTime(999);
      expect(fn).not.toHaveBeenCalled();
      
      vi.advanceTimersByTime(1);
      expect(fn).toHaveBeenCalledTimes(1);
    });

    test('应该重置延迟时间', () => {
      const fn = vi.fn();
      const debouncedFn = debounce(fn, 1000);
      
      debouncedFn();
      vi.advanceTimersByTime(500);
      
      debouncedFn(); // 重置计时器
      vi.advanceTimersByTime(500);
      expect(fn).not.toHaveBeenCalled();
      
      vi.advanceTimersByTime(500);
      expect(fn).toHaveBeenCalledTimes(1);
    });

    test('应该传递参数', () => {
      const fn = vi.fn();
      const debouncedFn = debounce(fn, 1000);
      
      debouncedFn('arg1', 'arg2');
      vi.advanceTimersByTime(1000);
      
      expect(fn).toHaveBeenCalledWith('arg1', 'arg2');
    });

    test('应该使用最新的参数', () => {
      const fn = vi.fn();
      const debouncedFn = debounce(fn, 1000);
      
      debouncedFn('first');
      vi.advanceTimersByTime(500);
      debouncedFn('second');
      vi.advanceTimersByTime(1000);
      
      expect(fn).toHaveBeenCalledTimes(1);
      expect(fn).toHaveBeenCalledWith('second');
    });
  });

  describe('throttle', () => {
    test('应该限制函数执行频率', () => {
      const fn = vi.fn();
      const throttledFn = throttle(fn, 1000);
      
      throttledFn();
      expect(fn).toHaveBeenCalledTimes(1);
      
      throttledFn();
      throttledFn();
      expect(fn).toHaveBeenCalledTimes(1);
      
      vi.advanceTimersByTime(1000);
      throttledFn();
      expect(fn).toHaveBeenCalledTimes(2);
    });

    test('应该传递参数', () => {
      const fn = vi.fn();
      const throttledFn = throttle(fn, 1000);
      
      throttledFn('arg1', 'arg2');
      expect(fn).toHaveBeenCalledWith('arg1', 'arg2');
    });

    test('应该在间隔期间忽略调用', () => {
      const fn = vi.fn();
      const throttledFn = throttle(fn, 1000);
      
      throttledFn('first');
      throttledFn('second');
      throttledFn('third');
      
      expect(fn).toHaveBeenCalledTimes(1);
      expect(fn).toHaveBeenCalledWith('first');
    });
  });

  describe('formatFileSize', () => {
    test('应该格式化字节数', () => {
      expect(formatFileSize(0)).toBe('0 Bytes');
      expect(formatFileSize(512)).toBe('512 Bytes');
      expect(formatFileSize(1024)).toBe('1 KB');
      expect(formatFileSize(1536)).toBe('1.5 KB');
      expect(formatFileSize(1048576)).toBe('1 MB');
      expect(formatFileSize(1073741824)).toBe('1 GB');
    });

    test('应该处理小数位', () => {
      expect(formatFileSize(1234)).toBe('1.21 KB');
      expect(formatFileSize(1234567)).toBe('1.18 MB');
      expect(formatFileSize(1234567890)).toBe('1.15 GB');
    });

    test('应该处理非常小的数字', () => {
      expect(formatFileSize(1)).toBe('1 Bytes');
      expect(formatFileSize(100)).toBe('100 Bytes');
    });

    test('应该处理边界值', () => {
      expect(formatFileSize(1023)).toBe('1023 Bytes');
      expect(formatFileSize(1025)).toBe('1 KB');
    });
  });

  describe('safeJsonParse', () => {
    test('应该解析有效的JSON', () => {
      const obj = { name: 'test', value: 42 };
      const json = JSON.stringify(obj);
      
      const result = safeJsonParse(json, null);
      expect(result).toEqual(obj);
    });

    test('应该返回默认值对于无效JSON', () => {
      const defaultValue = { error: true };
      
      const result = safeJsonParse('invalid json', defaultValue);
      expect(result).toEqual(defaultValue);
    });

    test('应该使用fallback值', () => {
      const fallback = { default: true };
      const result = safeJsonParse('invalid json', fallback);
      expect(result).toEqual(fallback);
    });

    test('应该处理空字符串', () => {
      const result = safeJsonParse('', null);
      expect(result).toBeNull();
    });

    test('应该处理null和undefined输入', () => {
      expect(safeJsonParse(null as any, null)).toBeNull();
      expect(safeJsonParse(undefined as any, null)).toBeNull();
    });

    test('应该解析数组', () => {
      const array = [1, 2, 3];
      const json = JSON.stringify(array);
      
      const result = safeJsonParse(json, []);
      expect(result).toEqual(array);
    });

    test('应该解析基本类型', () => {
      expect(safeJsonParse('42', 0)).toBe(42);
      expect(safeJsonParse('"string"', '')).toBe('string');
      expect(safeJsonParse('true', false)).toBe(true);
      expect(safeJsonParse('null', {})).toBe(null);
    });

    test('应该处理嵌套对象', () => {
      const nested = {
        user: {
          name: 'John',
          details: {
            age: 30,
            active: true
          }
        }
      };
      
      const json = JSON.stringify(nested);
      const result = safeJsonParse(json, {});
      
      expect(result).toEqual(nested);
    });
  });
}); 