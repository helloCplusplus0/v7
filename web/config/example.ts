 /**
 * 🔧 配置系统使用示例
 * 展示如何在不同场景下使用统一配置
 */

import { config, api, features, ui } from './index';

// ===== 基础用法示例 =====

// 1. 访问应用信息
console.log(`应用名称: ${config.app.name}`);
console.log(`应用版本: ${config.app.version}`);

// 2. 访问API配置
const apiUrl = `${config.api.baseUrl}${config.api.endpoints.hello}`;
console.log(`API地址: ${apiUrl}`);

// 3. 环境判断
if (config.runtime.isDevelopment) {
  console.log('🔧 开发环境模式');
} else {
  console.log('🚀 生产环境模式');
}

// ===== 实际应用场景示例 =====

// 1. API请求封装
export async function apiRequest(endpoint: string, options?: RequestInit) {
  const url = `${api.baseUrl}${endpoint}`;
  
  const defaultOptions: RequestInit = {
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
    ...options,
  };

  // 设置超时（使用AbortController）
  const controller = new AbortController();
  setTimeout(() => controller.abort(), api.timeout);
  defaultOptions.signal = controller.signal;

  if (features.enableDebug) {
    console.log(`🌐 API Request: ${url}`, defaultOptions);
  }

  try {
    const response = await fetch(url, defaultOptions);
    
    if (features.enableDebug) {
      console.log(`✅ API Response: ${response.status}`, response);
    }
    
    return response;
  } catch (error) {
    if (features.enableDebug) {
      console.error(`❌ API Error:`, error);
    }
    throw error;
  }
}

// 2. 条件功能启用
export function setupDevelopmentFeatures() {
  if (!features.enableDebug) return;
  
  // 开发环境专用功能
  console.log('🔧 启用开发调试功能');
  
  // 性能监控
  if (features.enableSourceMap) {
    console.log('📊 启用源码映射');
  }
  
  // Mock数据
  if (features.enableMock) {
    console.log('🎭 启用Mock数据');
  }
}

// 3. UI主题配置
export function applyUIConfig() {
  // 应用主题
  document.documentElement.setAttribute('data-theme', ui.theme);
  
  // 设置语言
  document.documentElement.setAttribute('lang', ui.language);
  
  // 动画设置
  if (!ui.animations) {
    document.documentElement.style.setProperty('--animation-duration', '0s');
  }
  
  console.log(`🎨 UI配置已应用: 主题=${ui.theme}, 语言=${ui.language}`);
}

// 4. 服务器配置使用
export function getServerInfo() {
  return {
    host: config.server.host,
    port: config.server.port,
    hmrEnabled: config.features.enableHMR,
    proxyEnabled: config.server.proxy.enabled,
    proxyTarget: config.server.proxy.target,
  };
}

// 5. 安全配置检查
export function validateSecurityConfig() {
  const issues: string[] = [];
  
  if (!config.security.enableHTTPS && config.runtime.isProduction) {
    issues.push('生产环境应启用HTTPS');
  }
  
  if (!config.security.enableCSP) {
    issues.push('建议启用内容安全策略(CSP)');
  }
  
  if (config.security.trustedDomains.includes('*')) {
    issues.push('不建议信任所有域名');
  }
  
  if (issues.length > 0) {
    console.warn('🔒 安全配置警告:', issues);
  } else {
    console.log('✅ 安全配置检查通过');
  }
  
  return issues;
}

// ===== 配置热更新示例 =====

// 监听配置变化（仅开发环境）
if (config.runtime.isDevelopment) {
  // 模拟配置热更新
  let configVersion = 1;
  
  setInterval(() => {
    if (features.enableDebug) {
      console.log(`🔄 配置版本检查: v${configVersion++}`);
    }
  }, 30000); // 30秒检查一次
}

// ===== 导出便捷函数 =====

export const configUtils = {
  // 获取完整API URL
  getApiUrl: (endpoint: string) => `${api.baseUrl}${endpoint}`,
  
  // 检查功能是否启用
  isFeatureEnabled: (feature: keyof typeof features) => features[feature],
  
  // 获取环境信息
  getEnvironment: () => ({
    isDev: config.runtime.isDevelopment,
    isProd: config.runtime.isProduction,
    mode: config.runtime.mode,
  }),
  
  // 获取调试信息
  getDebugInfo: () => ({
    config: config,
    timestamp: new Date().toISOString(),
    userAgent: navigator.userAgent,
    location: window.location.href,
  }),
};

// 初始化配置
export function initializeConfig() {
  console.log('🔧 初始化配置系统...');
  
  // 应用UI配置
  applyUIConfig();
  
  // 设置开发功能
  setupDevelopmentFeatures();
  
  // 验证安全配置
  validateSecurityConfig();
  
  // 打印配置摘要
  if (features.enableDebug) {
    console.log('📋 配置摘要:', {
      app: config.app.name,
      version: config.app.version,
      environment: config.runtime.mode,
      api: config.api.baseUrl,
      features: Object.entries(features)
        .filter(([, enabled]) => enabled)
        .map(([name]) => name),
    });
  }
  
  console.log('✅ 配置系统初始化完成');
}

// 自动初始化（如果需要）
if (typeof window !== 'undefined') {
  // 浏览器环境下自动初始化
  initializeConfig();
}