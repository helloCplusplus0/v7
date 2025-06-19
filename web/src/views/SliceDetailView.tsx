/**
 * 切片详细视图 - 纯容器组件
 * 
 * 功能：
 * 1. 仅负责加载和渲染切片组件
 * 2. 不提供任何全局 UI 元素
 * 3. 保持切片的完全独立性
 */

import { useParams } from "@solidjs/router";
import { createSignal, onMount, Suspense } from "solid-js";
import { getSliceComponent, hasSlice } from "../shared/registry";

export default function SliceDetailView() {
  const params = useParams();
  const sliceName = () => params['name'] || '';
  
  const [error, setError] = createSignal<string | null>(null);

  onMount(() => {
    const name = sliceName();
    if (!name || !hasSlice(name)) {
      setError(`切片 "${name}" 不存在`);
    }
  });

  if (error()) {
    return (
      <div class="slice-detail-error">
        <h2>切片未找到</h2>
        <p>{error()}</p>
        <p>请检查切片名称是否正确，或返回首页查看可用切片。</p>
      </div>
    );
  }

  const name = sliceName();
  const SliceComponent = getSliceComponent(name);

  return (
    <div class="slice-detail-container">
      {/* 纯容器 - 不提供任何全局 UI 元素 */}
      <Suspense fallback={<div class="loading">正在加载切片...</div>}>
        <SliceComponent />
      </Suspense>
    </div>
  );
} 