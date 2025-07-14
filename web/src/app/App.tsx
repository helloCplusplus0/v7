/**
 * Telegram风格主应用组件
 * 
 * 设计原则：
 * 1. 简洁直接的布局
 * 2. 底部导航，最高层级
 * 3. 统一的视觉体验
 * 4. 移动端优先的响应式设计
 */

import { Router, Route } from "@solidjs/router";
import { Suspense } from "solid-js";
import DashboardView from "../views/DashboardView";
import SliceDetailView from "../views/SliceDetailView";
import Header from "../shared/components/Header";
import "./App.css";
import "../shared/styles/mobile-optimizations.css"; // 引入移动端优化样式

// 布局组件，包含Header
function Layout(props: { children: any }) {
  return (
    <div class="app-container mobile-optimized">
      {/* 主内容区域 */}
      <main>
        <Suspense fallback={<div class="loading mobile-loading">加载中...</div>}>
          {props.children}
        </Suspense>
      </main>
      
      {/* Telegram风格底部导航 */}
      <Header />
    </div>
  );
}

export default function App() {
  return (
    <Router>
      <Route path="/" component={() => <Layout><DashboardView /></Layout>} />
      <Route path="/slice/:name" component={() => <Layout><SliceDetailView /></Layout>} />
    </Router>
  );
} 