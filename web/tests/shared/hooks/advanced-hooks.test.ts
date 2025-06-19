// tests/shared/hooks/advanced-hooks.test.ts
import { describe, test, expect, beforeEach, afterEach, vi } from 'vitest';
import { createRoot, createSignal } from 'solid-js';
import { useDebounce, useDebouncedCallback, useSearch } from '../../../shared/hooks/useDebounce';

describe('Advanced Hooks', () => {
  // 不再使用fake timers，使用真实定时器
  // beforeEach(() => {
  //   vi.useFakeTimers();
  // });

  // afterEach(() => {
  //   vi.useRealTimers();
  // });

  describe('useDebounce', () => {
    test('应该延迟更新值', async () => {
      await new Promise<void>((resolve) => {
        createRoot(async () => {
          const [value, setValue] = createSignal('initial');
          const debouncedValue = useDebounce(value, 50); // 缩短延迟时间

          expect(debouncedValue()).toBe('initial');

          setValue('updated');
          expect(debouncedValue()).toBe('initial'); // 还没更新

          // 等待25ms（还没到防抖时间）
          setTimeout(() => {
            expect(debouncedValue()).toBe('initial'); // 还没到时间
            
            // 再等待30ms（总共55ms，超过50ms）
            setTimeout(() => {
              expect(debouncedValue()).toBe('updated'); // 现在更新了
              resolve();
            }, 30);
          }, 25);
        });
      });
    });

    test('应该重置计时器当值快速变化时', async () => {
      await new Promise<void>((resolve) => {
        createRoot(async () => {
          const [value, setValue] = createSignal('initial');
          const debouncedValue = useDebounce(value, 50);

          setValue('first');
          setTimeout(() => {
            setValue('second');
            setTimeout(() => {
              setValue('final');
              
              // 检查还没更新
              setTimeout(() => {
                expect(debouncedValue()).toBe('initial'); // 还没更新
                
                // 等待防抖时间过去
                setTimeout(() => {
                  expect(debouncedValue()).toBe('final'); // 最终值
                  resolve();
                }, 30);
              }, 25);
            }, 15);
          }, 15);
        });
      });
    });
  });

  describe('useDebouncedCallback', () => {
    test('应该防抖函数调用', async () => {
      const mockFn = vi.fn();
      const debouncedFn = useDebouncedCallback(mockFn, 30);

      debouncedFn('arg1');
      debouncedFn('arg2');
      debouncedFn('arg3');

      expect(mockFn).not.toHaveBeenCalled();

      await new Promise(resolve => setTimeout(resolve, 35));
      expect(mockFn).toHaveBeenCalledTimes(1);
      expect(mockFn).toHaveBeenCalledWith('arg3'); // 只调用最后一次
    });

    test('应该保持正确的参数类型', async () => {
      const mockFn = vi.fn((a: number, b: string) => a + b.length);
      const debouncedFn = useDebouncedCallback(mockFn, 30);

      debouncedFn(5, 'hello');
      await new Promise(resolve => setTimeout(resolve, 35));

      expect(mockFn).toHaveBeenCalledWith(5, 'hello');
    });
  });

  describe('useSearch', () => {
    test('应该返回正确的搜索状态', async () => {
      await new Promise<void>((resolve) => {
        createRoot(async () => {
          const search = useSearch('initial', 50);

          expect(search.searchInput()).toBe('initial');
          expect(search.debouncedSearch()).toBe('initial');

          search.setSearchInput('new search');
          expect(search.searchInput()).toBe('new search');
          expect(search.debouncedSearch()).toBe('initial'); // 还没防抖更新

          setTimeout(() => {
            expect(search.debouncedSearch()).toBe('new search'); // 现在更新了
            resolve();
          }, 60);
        });
      });
    });

    test('应该能清空搜索', () => {
      createRoot(() => {
        const search = useSearch('initial');

        search.setSearchInput('some search');
        expect(search.searchInput()).toBe('some search');

        search.clearSearch();
        expect(search.searchInput()).toBe('');
      });
    });

    test('应该使用默认值', () => {
      createRoot(() => {
        const search = useSearch();

        expect(search.searchInput()).toBe('');
        expect(search.debouncedSearch()).toBe('');
      });
    });
  });
}); 