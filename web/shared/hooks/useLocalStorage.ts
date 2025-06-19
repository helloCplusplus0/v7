// shared/hooks/useLocalStorage.ts - 本地存储hooks
import { createSignal, createEffect } from 'solid-js';

export function useLocalStorage<T>(
  key: string,
  defaultValue: T
): [() => T, (value: T) => void] {
  // 从localStorage获取初始值
  const getStoredValue = (): T => {
    try {
      const item = localStorage.getItem(key);
      return item ? JSON.parse(item) : defaultValue;
    } catch (error) {
      console.warn(`Error reading localStorage key "${key}":`, error);
      return defaultValue;
    }
  };

  const [storedValue, setStoredValue] = createSignal<T>(getStoredValue());

  const setValue = (value: T) => {
    try {
      // 更新信号
      setStoredValue(() => value);
      // 保存到localStorage
      localStorage.setItem(key, JSON.stringify(value));
    } catch (error) {
      console.warn(`Error setting localStorage key "${key}":`, error);
    }
  };

  // 监听其他标签页的localStorage变化
  createEffect(() => {
    const handleStorageChange = (e: StorageEvent) => {
      if (e.key === key && e.newValue !== null) {
        try {
          setStoredValue(JSON.parse(e.newValue));
        } catch (error) {
          console.warn(`Error parsing localStorage key "${key}":`, error);
        }
      }
    };

    window.addEventListener('storage', handleStorageChange);
    return () => window.removeEventListener('storage', handleStorageChange);
  });

  return [storedValue, setValue];
} 