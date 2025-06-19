 /**
 * 🔧 通用配置
 * 适用于所有环境的基础配置
 */

import type { AppInfo, ApiConfig } from './types';

export const commonConfig = {
  app: {
    name: 'FMOD Web Application',
    version: '1.0.0',
    description: 'FMOD Slice Management Web Interface',
    author: 'FMOD Team',
    homepage: 'https://github.com/fmod/slice'
  } as AppInfo,

  api: {
    timeout: 10000,
    retryAttempts: 3,
    retryDelay: 1000,
    endpoints: {
      health: '/api/health',
      hello: '/api/hello',
      slices: '/api/slices'
    }
  } as Partial<ApiConfig>,

  ui: {
    theme: 'telegram' as const,
    language: 'zh' as const,
    animations: true,
    notifications: true,
    autoRefresh: true,
    refreshInterval: 30000 // 30秒
  },

  security: {
    enableCSP: true,
    enableCORS: true,
    enableHTTPS: false, // 开发环境为false，生产环境为true
    trustedDomains: ['localhost', '127.0.0.1', '192.168.31.84'],
    apiKeyHeader: 'X-API-Key'
  }
};