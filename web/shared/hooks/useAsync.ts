// shared/hooks/useAsync.ts - 异步操作hooks
import { createSignal, createEffect, Accessor } from 'solid-js';

export interface AsyncState<T> {
  loading: Accessor<boolean>;
  data: Accessor<T | null>;
  error: Accessor<Error | null>;
  execute: () => Promise<T>;
}

export function useAsync<T>(
  asyncFunction: () => Promise<T>,
  deps?: () => any[]
): AsyncState<T> {
  const [loading, setLoading] = createSignal(false);
  const [data, setData] = createSignal<T | null>(null);
  const [error, setError] = createSignal<Error | null>(null);

  const execute = async (): Promise<T> => {
    try {
      setLoading(true);
      setError(null);
      
      const result = await asyncFunction();
      
      setData(() => result);
      return result;
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err));
      setError(error);
      throw error;
    } finally {
      setLoading(false);
    }
  };

  // 如果提供了依赖数组，监听依赖变化并自动执行
  if (deps) {
    createEffect(() => {
      const currentDeps = deps();
      execute();
    });
  }

  return {
    loading,
    data,
    error,
    execute,
  };
} 