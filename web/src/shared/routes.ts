/**
 * 路由配置
 * 基于切片注册表自动生成路由
 */

import type { RouteDefinition } from './types';
import { 
  sliceMetadata, 
  getSliceComponent, 
  getSliceNames 
} from './registry';

// 获取所有路由配置
export const getRoutes = (): RouteDefinition[] => {
  const sliceNames = getSliceNames();
  
  return sliceNames.map(name => {
    const metadata = sliceMetadata[name];
    const component = getSliceComponent(name);
    
    return {
      path: metadata?.path || `/${name}`,
      component,
      name,
      displayName: metadata?.displayName || name,
      description: metadata?.description || '',
    };
  });
};

// 默认路由（首页）
export const getDefaultRoute = (): RouteDefinition | null => {
  const routes = getRoutes();
  return routes.length > 0 ? (routes[0] || null) : null;
};

// 根据名称获取路由
export const getRouteByName = (name: string): RouteDefinition | null => {
  const routes = getRoutes();
  return routes.find(route => route.name === name) ?? null;
};

// 检查路由是否存在
export const hasRoute = (path: string): boolean => {
  const routes = getRoutes();
  return routes.some(route => route.path === path);
};

// 导出所有路由（向后兼容）
export const routes = getRoutes(); 