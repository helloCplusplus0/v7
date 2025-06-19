/**
 * Telegram风格底部导航Header
 * 
 * 设计原则：
 * 1. 简洁直接，移除多余装饰
 * 2. 底部固定，最高层级显示
 * 3. 仅保留核心功能：搜索框 + Home按钮
 * 4. 移动端和PC端统一体验
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
    <header class="header-telegram">
      <div class="header-content">
        {/* 搜索框 */}
        <form onSubmit={handleSearch} class="search-form">
          <input
            type="text"
            placeholder="搜索功能切片..."
            value={searchQuery()}
            onInput={(e) => setSearchQuery(e.currentTarget.value)}
            class="search-input"
          />
        </form>

        {/* Home按钮 */}
        <A href="/" class="home-button">
          <span class="home-icon">🏠</span>
        </A>
      </div>
    </header>
  );
} 