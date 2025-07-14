/**
 * 简化Header设计 - 搜索框 + Home按钮
 * 
 * 设计原则：
 * 1. 移动端：简洁的搜索框和Home按钮水平布局
 * 2. 桌面端：完整搜索框 + Home按钮
 * 3. 全面采用mobile-optimizations.css优化
 * 4. 避免复杂的图标导航，保持直观简洁
 */

import { createSignal } from "solid-js";
import { A } from "@solidjs/router";

export default function Header() {
  const [searchQuery, setSearchQuery] = createSignal("");

  const handleSearch = (e: Event) => {
    e.preventDefault();
    // 搜索功能实现
    console.log("搜索:", searchQuery());
  };

  return (
    <header class="header-telegram mobile-optimized">
      <div class="header-content">
        {/* 搜索表单 */}
        <form onSubmit={handleSearch} class="search-form">
          <input
            type="text"
            placeholder="搜索功能切片..."
            value={searchQuery()}
            onInput={(e) => setSearchQuery(e.currentTarget.value)}
            class="search-input mobile-input touch-friendly"
          />
        </form>

        {/* Home按钮 */}
        <A href="/" class="home-button mobile-button touch-friendly">
          <span class="home-icon">🏠</span>
        </A>
      </div>
    </header>
  );
} 