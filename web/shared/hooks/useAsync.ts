// shared/hooks/useAsync.ts - 异步操作hooks
import { createSignal, createEffect, Accessor, onCleanup } from 'solid-js';

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
  let currentCall = 0;

  const execute = async (): Promise<T> => {
    const callId = ++currentCall;
    setLoading(true);
    setError(null);
    try {
      const result = await asyncFunction();
      if (callId === currentCall) {
        setData(() => result);
        setLoading(false);
      }
      return result;
    } catch (err) {
      if (callId === currentCall) {
        setError(err instanceof Error ? err : new Error(String(err)));
        setLoading(false);
      }
      throw err;
    }
  };

  createEffect(() => {
    if (deps) {
      deps();
      execute();
    }
  });

  return { loading, data, error, execute };
} 