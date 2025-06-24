// shared/hooks/useDebounce.ts - 防抖 Hook
import { createSignal, createEffect, Accessor, onCleanup } from 'solid-js';

/**
 * 防抖 Hook - 延迟更新值直到输入停止变化
 * @param value 要防抖的值
 * @param delay 防抖延迟时间（毫秒）
 * @returns 防抖后的值
 */
export function useDebounce<T>(value: Accessor<T>, delay: number): Accessor<T> {
  const [debouncedValue, setDebouncedValue] = createSignal<T>(value());
  let timeoutId: ReturnType<typeof setTimeout> | null = null;
  
  createEffect(() => {
    const currentValue = value();
    
    // 清理之前的定时器
    if (timeoutId !== null) {
      clearTimeout(timeoutId);
    }
    
    // 设置新的定时器
    timeoutId = setTimeout(() => {
      Promise.resolve().then(() => setDebouncedValue(() => currentValue));
      timeoutId = null;
    }, delay);
  });

  onCleanup(() => {
    if (timeoutId !== null) {
      clearTimeout(timeoutId);
      timeoutId = null;
    }
  });

  return debouncedValue;
}

/**
 * 防抖回调函数 Hook
 * @param callback 要防抖的回调函数
 * @param delay 防抖延迟时间（毫秒）
 * @returns 防抖后的回调函数
 */
export function useDebouncedCallback<T extends (...args: any[]) => any>(
  callback: T,
  delay: number
): T {
  let timeoutId: ReturnType<typeof setTimeout> | null = null;

  const debouncedFn = ((...args: Parameters<T>) => {
    if (timeoutId !== null) {
      clearTimeout(timeoutId);
    }

    timeoutId = setTimeout(() => {
      callback(...args);
      timeoutId = null;
    }, delay);
  }) as T;

  onCleanup(() => {
    if (timeoutId !== null) {
      clearTimeout(timeoutId);
      timeoutId = null;
    }
  });

  return debouncedFn;
}

/**
 * 搜索 Hook - 带防抖的搜索输入
 * @param initialValue 初始搜索值
 * @param delay 防抖延迟时间（毫秒）
 * @returns 搜索状态和操作方法
 */
export function useSearch(initialValue = '', delay = 300) {
  const [searchInput, setSearchInput] = createSignal(initialValue);
  const debouncedSearch = useDebounce(searchInput, delay);

  const clearSearch = () => {
    setSearchInput('');
  };

  return {
    searchInput,
    setSearchInput,
    debouncedSearch,
    clearSearch,
  };
} 