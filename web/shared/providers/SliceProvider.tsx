// shared/providers/SliceProvider.tsx - 切片提供者
import { createContext, useContext } from 'solid-js';

interface SliceConfig {
  name: string;
  version: string;
  dependencies?: string[];
}

interface SliceRegistry {
  [key: string]: SliceConfig;
}

const SliceContext = createContext<SliceRegistry>({});

export function SliceProvider(props: {
  slices: SliceRegistry;
  children: any;
}) {
  return (
    <SliceContext.Provider value={props.slices}>
      {props.children}
    </SliceContext.Provider>
  );
}

export function useSliceRegistry(): SliceRegistry {
  return useContext(SliceContext);
}

export function useSlice(sliceName: string): SliceConfig | null {
  const registry = useSliceRegistry();
  return registry[sliceName] || null;
} 