# 📱 Web v7 移动端优化指南

## 🎯 概述

Web v7架构的移动端优化遵循**移动端优先**的设计原则，确保在各种设备上都能提供出色的用户体验。本指南涵盖了从基础设置到高级优化的完整移动端适配方案。

## 🏗️ 架构层面的移动端支持

### 1. 基础设施层优化

#### HTML基础设置
```html
<!-- web/index.html -->
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<meta name="theme-color" content="#0088cc" />
<meta name="apple-mobile-web-app-capable" content="yes" />
<meta name="apple-mobile-web-app-status-bar-style" content="default" />
```

#### CSS基础优化
```css
/* web/src/app/App.css */
html {
  -webkit-text-size-adjust: 100%;
  -moz-text-size-adjust: 100%;
  text-size-adjust: 100%;
}

body {
  overflow-x: hidden; /* 防止横向滚动 */
}
```

### 2. 响应式断点系统

Web v7采用细致的响应式断点，适配各种设备：

```css
/* 大屏幕（桌面） */
@media (min-width: 1200px) { /* 桌面优化 */ }

/* 中等屏幕（平板横屏） */
@media (max-width: 1024px) { /* 平板横屏 */ }

/* 小平板（平板竖屏） */
@media (max-width: 768px) { /* 平板竖屏 */ }

/* 大手机（iPhone Plus/Max系列） */
@media (max-width: 640px) { /* 大屏手机 */ }

/* 标准手机（iPhone 12/13/14系列） */
@media (max-width: 480px) { /* 标准手机 */ }

/* 小手机（iPhone SE系列） */
@media (max-width: 375px) { /* 小屏手机 */ }

/* 超小屏幕（iPhone SE 1代等） */
@media (max-width: 320px) { /* 超小屏 */ }
```

### 3. 安全区域（Safe Area）支持

```css
/* 考虑iPhone X系列的刘海和Home指示器 */
.app-container {
  padding-bottom: calc(80px + env(safe-area-inset-bottom));
}

.header-telegram {
  padding-bottom: calc(12px + env(safe-area-inset-bottom));
}
```

## 🎨 UI组件移动端优化

### 1. 触摸友好的交互设计

#### 最小触摸目标
```css
/* 所有可点击元素至少44px */
.touch-friendly {
  min-height: 44px;
  min-width: 44px;
  touch-action: manipulation;
  -webkit-tap-highlight-color: rgba(0, 0, 0, 0.1);
}
```

#### 按钮优化
```css
.mobile-button {
  min-height: 44px;
  padding: 12px 16px;
  font-size: 16px;
  touch-action: manipulation;
  -webkit-tap-highlight-color: rgba(0, 0, 0, 0.1);
}

.mobile-button:active {
  transform: scale(0.98); /* 触摸反馈 */
}
```

### 2. 输入框优化

#### 防止iOS缩放
```css
.mobile-input {
  font-size: 16px; /* 防止iOS自动缩放 */
  min-height: 44px;
  padding: 12px 16px;
}
```

#### 表单优化
```css
.mobile-form-input:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}
```

### 3. 卡片和列表优化

#### 卡片交互
```css
.mobile-card {
  touch-action: manipulation;
  -webkit-tap-highlight-color: rgba(0, 0, 0, 0.05);
}

.mobile-card:active {
  transform: translateY(1px);
}
```

#### 列表项优化
```css
.mobile-list-item {
  min-height: 44px;
  padding: 16px;
  touch-action: manipulation;
}

.mobile-list-item:active {
  background-color: #f8f9fa;
}
```

## 🔧 切片级别的移动端适配

### 1. 使用共享移动端样式

在切片中引入通用移动端样式：

```css
/* web/slices/your_slice/styles.css */
@import '../../src/shared/styles/mobile-optimizations.css';

.your-slice-container {
  /* 使用移动端工具类 */
  @extend .mobile-container;
  @extend .mobile-optimized;
}
```

### 2. 切片响应式设计模式

```css
/* 移动端优先的切片样式 */
.slice-content {
  padding: 16px;
  
  /* 平板适配 */
  @media (min-width: 768px) {
    padding: 24px;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 20px;
  }
  
  /* 桌面适配 */
  @media (min-width: 1024px) {
    padding: 32px;
    max-width: 1200px;
    margin: 0 auto;
  }
}
```

### 3. 切片内模态框优化

```typescript
// 移动端友好的模态框
export const MobileModal = (props: ModalProps) => {
  return (
    <div class="mobile-modal-overlay">
      <div class="mobile-modal">
        <div class="mobile-modal-header">
          <h2 class="mobile-modal-title">{props.title}</h2>
          <button 
            class="mobile-modal-close"
            onClick={props.onClose}
          >
            ✕
          </button>
        </div>
        <div class="mobile-modal-content">
          {props.children}
        </div>
      </div>
    </div>
  );
};
```

## 🎯 性能优化

### 1. 图片和资源优化

```css
/* 响应式图片 */
.responsive-image {
  width: 100%;
  height: auto;
  max-width: 100%;
  object-fit: cover;
}

/* 高分辨率屏幕优化 */
@media (-webkit-min-device-pixel-ratio: 2), (min-resolution: 192dpi) {
  .high-res-border {
    border-width: 0.5px;
  }
}
```

### 2. 动画性能优化

```css
/* 硬件加速 */
.hardware-accelerated {
  transform: translateZ(0);
  -webkit-transform: translateZ(0);
}

/* 减少动画偏好支持 */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

### 3. 文本和字体优化

```css
/* 响应式文本 */
.text-responsive {
  font-size: clamp(14px, 4vw, 18px);
  line-height: 1.5;
}

/* 文本溢出处理 */
.text-truncate {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.text-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
```

## 🌙 深色模式支持

```css
@media (prefers-color-scheme: dark) {
  .mobile-card {
    background: #1f2937;
    border-color: #374151;
    color: #f9fafb;
  }
  
  .mobile-input {
    background: #374151;
    border-color: #4b5563;
    color: #f9fafb;
  }
  
  .mobile-modal {
    background: #1f2937;
    color: #f9fafb;
  }
}
```

## 📐 布局工具类

### 1. 容器和网格

```css
/* 移动端容器 */
.mobile-container {
  max-width: 100%;
  margin: 0 auto;
  padding: 0 16px;
}

/* 移动端网格 */
.mobile-grid {
  display: grid;
  gap: 16px;
  grid-template-columns: 1fr;
}

/* 平板及以上 */
@media (min-width: 768px) {
  .mobile-grid {
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 20px;
  }
}
```

### 2. 弹性布局

```css
.mobile-flex {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.mobile-flex-row {
  display: flex;
  flex-direction: row;
  gap: 12px;
  align-items: center;
}
```

### 3. 间距工具

```css
.mobile-spacing-sm { padding: 8px; }
.mobile-spacing-md { padding: 16px; }
.mobile-spacing-lg { padding: 24px; }
```

## 🔍 可访问性优化

### 1. 焦点管理

```css
.mobile-button:focus {
  outline: 2px solid #3b82f6;
  outline-offset: 2px;
}

.mobile-input:focus {
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}
```

### 2. 触摸目标

```css
/* 确保所有交互元素至少44px */
.touch-target {
  min-height: 44px;
  min-width: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
}
```

## 🧪 测试和调试

### 1. 设备测试清单

- [ ] iPhone SE (320px)
- [ ] iPhone 12/13/14 (375px)
- [ ] iPhone 12/13/14 Plus (414px)
- [ ] iPad (768px)
- [ ] iPad Pro (1024px)
- [ ] 横屏模式测试
- [ ] 深色模式测试
- [ ] 触摸交互测试

### 2. 性能测试

```javascript
// 检查移动设备
const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);

// 检查触摸支持
const hasTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;

// 检查网络状态
const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
const isSlowConnection = connection && connection.effectiveType === 'slow-2g';
```

## 🚀 最佳实践

### 1. 移动端优先设计

```css
/* ✅ 正确：移动端优先 */
.component {
  /* 移动端样式 */
  padding: 16px;
  font-size: 14px;
}

@media (min-width: 768px) {
  .component {
    /* 桌面端增强 */
    padding: 24px;
    font-size: 16px;
  }
}
```

### 2. 触摸友好设计

```css
/* ✅ 正确：触摸友好 */
.button {
  min-height: 44px;
  padding: 12px 16px;
  touch-action: manipulation;
  -webkit-tap-highlight-color: rgba(0, 0, 0, 0.1);
}

.button:active {
  transform: scale(0.98);
}
```

### 3. 性能优化

```css
/* ✅ 正确：硬件加速 */
.animated-element {
  transform: translateZ(0);
  will-change: transform;
}

/* ✅ 正确：减少重排 */
.layout-element {
  contain: layout style paint;
}
```

## 📊 工具类参考

### 显示控制
- `.mobile-only` - 仅移动端显示
- `.desktop-only` - 仅桌面端显示
- `.mobile-hidden` - 移动端隐藏

### 安全区域
- `.safe-area-top` - 顶部安全区域
- `.safe-area-bottom` - 底部安全区域
- `.safe-area-left` - 左侧安全区域
- `.safe-area-right` - 右侧安全区域

### 交互优化
- `.touch-friendly` - 触摸友好
- `.no-select` - 防止选择
- `.hardware-accelerated` - 硬件加速

## 🎯 总结

Web v7的移动端优化体系提供了：

1. **完整的响应式断点系统** - 适配所有主流设备
2. **触摸友好的交互设计** - 符合移动端用户习惯
3. **性能优化的最佳实践** - 确保流畅的用户体验
4. **可访问性支持** - 包容性设计原则
5. **一致的视觉体验** - 跨设备的统一感受

通过遵循这些指南，可以确保Web v7应用在各种移动设备上都能提供出色的用户体验。 