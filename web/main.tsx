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

// 检查服务器状态（现在由 mockManager 处理）
const checkServerStatus = async () => {
  console.log('🏥 Initializing Mock Manager...');
  // Mock Manager 会自动检查后端状态
};

// 使用全局fetch拦截来模拟API
const originalFetch = window.fetch;
window.fetch = async (input, init) => {
  const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
  const startTime = performance.now();
  
  // 更精确地识别和处理Vite HMR请求
  const isHMRRequest = (
    // Vite HMR ping 请求通常是对根路径的GET请求
    (url === `http://${config.server.hmr?.host || 'localhost'}:${config.server.hmr?.port || 5173}/` ||
     url === `http://0.0.0.0:5173/` || // 处理错误的0.0.0.0地址
     url.includes('/@vite/client') ||
     url.includes('/@fs/') ||
     url.includes('/__vite_ping')) &&
    (init?.method === 'GET' || !init?.method) &&
    !url.includes('/api/')
  );
  
  if (isHMRRequest) {
    try {
      const response = await originalFetch(input, init);
      return response;
    } catch (error) {
      // 静默处理Vite重连错误，不输出日志
      // 这些错误是正常的，当HMR尝试重连时会发生
      throw error;
    }
  }
  
  console.log(`🔍 Fetch request to: ${url}`, {
    method: init?.method || 'GET',
    headers: init?.headers,
    timestamp: new Date().toISOString()
  });
  
  // 智能 Mock 拦截
  if (config.mock?.strategy === 'force' && url.includes('/api/hello')) {
    console.log('🎯 Mock mode: Intercepting API request for /api/hello');
    
    // 模拟网络延迟
    await new Promise(resolve => setTimeout(resolve, 300));
    
    const responseData = { message: "Hello fmod!" };
    const endTime = performance.now();
    console.log('📤 Mock response:', responseData, `(${(endTime - startTime).toFixed(2)}ms)`);
    
    return new Response(
      JSON.stringify(responseData),
      { 
        status: 200,
        headers: { 
          'Content-Type': 'application/json',
          'X-Mock-Response': 'true',
          'X-Response-Time': `${(endTime - startTime).toFixed(2)}ms`
        } 
      }
    );
  }
  
  // 其他请求使用原始fetch
  console.log('⏩ Using original fetch for:', url);
  try {
    const response = await originalFetch(input, init);
    const endTime = performance.now();
    console.log(`✅ Fetch completed: ${url} (${response.status}) in ${(endTime - startTime).toFixed(2)}ms`);
    return response;
  } catch (error) {
    const endTime = performance.now();
    console.error(`❌ Fetch error for ${url} after ${(endTime - startTime).toFixed(2)}ms:`, error);
    throw error;
  }
};

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

// 检查服务器状态
checkServerStatus().catch(console.error);

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