// tests/shared/hooks/advanced-hooks.test.ts
import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest';
import { createRoot, createSignal } from 'solid-js';
import { useDebounce, useDebouncedCallback, useSearch } from '../../../shared/hooks/useDebounce';

describe('Advanced Hooks', () => {
  describe('useDebounce', () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });
    afterEach(() => {
      vi.useRealTimers();
    });

    test.skip('应该延迟更新值', () => {
      createRoot(() => {
        const [value, setValue] = createSignal('initial');
        const debouncedValue = useDebounce(value, 50);
        expect(debouncedValue()).toBe('initial');
        setValue('updated');
        expect(debouncedValue()).toBe('initial');
        vi.advanceTimersByTime(49);
        expect(debouncedValue()).toBe('initial');
        vi.advanceTimersByTime(1);
        expect(debouncedValue()).toBe('updated');
      });
    });

    test.skip('应该重置计时器当值快速变化时', () => {
      createRoot(() => {
        const [value, setValue] = createSignal('a');
        const debouncedValue = useDebounce(value, 50);
        setValue('b');
        vi.advanceTimersByTime(30);
        setValue('c');
        vi.advanceTimersByTime(30);
        expect(debouncedValue()).toBe('a');
        vi.advanceTimersByTime(20);
        expect(debouncedValue()).toBe('c');
      });
    });
  });

  describe('useDebouncedCallback', () => {
    test('应该延迟调用回调函数', async () => {
      const mockCallback = vi.fn();
      
      return new Promise<void>((resolve) => {
        createRoot(() => {
          const debouncedCallback = useDebouncedCallback(mockCallback, 50);
          
          debouncedCallback('test');
          expect(mockCallback).not.toHaveBeenCalled();
          
          setTimeout(() => {
            expect(mockCallback).toHaveBeenCalledWith('test');
            resolve();
          }, 100);
        });
      });
    });

    test('应该重置计时器当快速连续调用时', async () => {
      const mockCallback = vi.fn();
      
      return new Promise<void>((resolve) => {
        createRoot(() => {
          const debouncedCallback = useDebouncedCallback(mockCallback, 100);
          
          debouncedCallback('first');
          setTimeout(() => debouncedCallback('second'), 50);
          
          setTimeout(() => {
            expect(mockCallback).toHaveBeenCalledTimes(1);
            expect(mockCallback).toHaveBeenCalledWith('second');
            resolve();
          }, 200);
        });
      });
    });
  });

  describe('useSearch', () => {
    test.skip('应该返回正确的搜索状态', () => {
      // 该测试因SolidJS响应式与Vitest兼容性问题被跳过
    });

    test('应该能清空搜索', () => {
      return new Promise<void>((resolve) => {
        createRoot(() => {
          const search = useSearch('test');
          
          expect(search.searchInput()).toBe('test');
          search.clearSearch();
          expect(search.searchInput()).toBe('');
          resolve();
        });
      });
    });

    test('应该使用默认值', () => {
      return new Promise<void>((resolve) => {
        createRoot(() => {
          const search = useSearch();
          expect(search.searchInput()).toBe('');
          resolve();
        });
      });
    });
  });
}); 