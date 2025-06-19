// shared/hooks/useDebounce.ts - 防抖 Hook
import { createSignal, createEffect, Accessor, onCleanup, batch } from 'solid-js';

/**
 * 防抖 Hook - 延迟更新值直到输入停止变化
 * @param value 要防抖的值
 * @param delay 防抖延迟时间（毫秒）
 * @returns 防抖后的值
 */
export function useDebounce<T>(value: Accessor<T>, delay: number): Accessor<T> {
  const [debouncedValue, setDebouncedValue] = createSignal<T>(value());
  let timeoutRef: ReturnType<typeof setTimeout> | null = null;
  
  createEffect(() => {
    const val = value();
    
    // 清理之前的定时器
    if (timeoutRef !== null) {
      clearTimeout(timeoutRef);
    }
    
    // 创建新的定时器
    timeoutRef = setTimeout(() => {
      batch(() => {
        setDebouncedValue(() => val);
      });
    }, delay);
  });

  onCleanup(() => {
    if (timeoutRef !== null) {
      clearTimeout(timeoutRef);
    }
  });

  return debouncedValue;
}

/**
 * 防抖回调 Hook - 防抖函数调用
 * @param callback 要防抖的回调函数
 * @param delay 防抖延迟时间（毫秒）
 * @returns 防抖后的回调函数
 */
export function useDebouncedCallback<T extends (...args: any[]) => any>(
  callback: T,
  delay: number
): T {
  let timeoutId: ReturnType<typeof setTimeout>;

  return ((...args: Parameters<T>) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => {
      callback(...args);
    }, delay);
  }) as T;
}

/**
 * 搜索防抖 Hook - 专门用于搜索输入的防抖
 * @param initialValue 初始搜索值
 * @param delay 防抖延迟时间，默认300ms
 * @returns 包含输入值、防抖值和设置函数的对象
 */
export function useSearch(initialValue = '', delay = 300) {
  const [searchInput, setSearchInput] = createSignal(initialValue);
  const debouncedSearch = useDebounce(searchInput, delay);

  return {
    searchInput,
    setSearchInput,
    debouncedSearch,
    clearSearch: () => setSearchInput('')
  };
} 