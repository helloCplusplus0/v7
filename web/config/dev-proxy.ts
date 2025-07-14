/**
 * 🚀 开发环境轻量级API代理
 * 用于npm run dev时直接与backend通信，避免复杂的gRPC桥接
 * 
 * 流程：Browser → Vite Dev Server → HTTP Proxy → Backend HTTP API
 */

interface ProxyTarget {
  backend: string;
  analytics: string;
}

// 开发环境代理配置
export const DEV_PROXY_CONFIG: ProxyTarget = {
  backend: process.env.VITE_BACKEND_URL || 'http://localhost:3000',
  analytics: process.env.VITE_ANALYTICS_URL || 'http://localhost:50051',
};

// 代理路径映射
export const PROXY_ROUTES = {
  '/api/mvp': 'backend',     // MVP CRUD API
  '/api/analytics': 'analytics', // Analytics Engine API
  '/api/health': 'backend',  // 健康检查
} as const;

// 获取代理目标
export function getProxyTarget(path: string): string | null {
  for (const [route, target] of Object.entries(PROXY_ROUTES)) {
    if (path.startsWith(route)) {
      return DEV_PROXY_CONFIG[target as keyof ProxyTarget];
    }
  }
  return null;
}

// 开发环境检查
export const isDevelopment = () => import.meta.env.DEV;

// 日志工具
export const devLog = (message: string, ...args: any[]) => {
  if (isDevelopment()) {
    console.log(`🔧 [Dev-Proxy] ${message}`, ...args);
  }
}; 