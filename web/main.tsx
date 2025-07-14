import { render } from "solid-js/web";
import App from "./src/app/App";
import { config } from "./config";

// 打印详细环境信息
console.log('🌍 Environment Info:', {
  isDev: config.runtime.isDevelopment,
  baseUrl: import.meta.env.BASE_URL,
  mode: config.runtime.mode,
  timestamp: config.runtime.timestamp,
  userAgent: navigator.userAgent,
  location: window.location.href,
  apiBaseUrl: config.api.baseUrl
});

// 添加全局错误处理
window.addEventListener('error', (event) => {
  // 过滤掉来自浏览器扩展的错误
  if (event.filename && (
    event.filename.includes('extension://') ||
    event.filename.includes('moz-extension://') ||
    event.filename.includes('chrome-extension://') ||
    event.filename.includes('injected.js') ||
    event.filename.includes('inpage.js')
  )) {
    console.warn('⚠️ Ignoring browser extension error:', event.error);
    return;
  }
  
  console.error('🚨 Global error:', event.error);
});

window.addEventListener('unhandledrejection', (event) => {
  // 过滤掉浏览器扩展的JSON-RPC错误
  if (event.reason && 
      typeof event.reason === 'object' && 
      event.reason.code === -32603 && 
      event.reason.message === 'Internal JSON-RPC error.') {
    console.warn('⚠️ Ignoring browser extension JSON-RPC error:', event.reason);
    event.preventDefault(); // 阻止错误冒泡
    return;
  }
  
  // 只记录应用相关的错误
  console.error('🚨 Unhandled promise rejection:', event.reason);
});

// 渲染应用 - App.tsx 中已经包含了 Router
console.log('🚀 Starting application render at', new Date().toISOString());
try {
  render(
    () => <App />,
    document.getElementById("root") as HTMLElement
  );
  console.log('✅ Application rendered successfully');
} catch (error) {
  console.error('❌ Application render failed:', error);
} 