 /**
 * 🔧 开发环境配置
 * 针对本地开发优化的配置
 */

import type { ApiConfig, ServerConfig, FeatureFlags, MonitoringConfig, MockConfig } from './types';

export const developmentConfig = {
  app: {
    name: 'FMOD Web Application [DEV]'
  },

  api: {
    baseUrl: import.meta.env.VITE_API_BASE_URL || 'http://192.168.31.84:3000/api',
    timeout: parseInt(import.meta.env['VITE_API_TIMEOUT'] || '15000') // 开发环境更长的超时时间
  } as Partial<ApiConfig>,

  server: {
    host: import.meta.env['VITE_DEV_SERVER_HOST'] || '0.0.0.0',
    port: parseInt(import.meta.env['VITE_DEV_SERVER_PORT'] || '5173'),
    hmr: {
      port: parseInt(import.meta.env['VITE_HMR_PORT'] || '5174'),
      host: import.meta.env['VITE_HMR_HOST'] || '192.168.31.84', // 修复：使用具体IP而非0.0.0.0
      overlay: true
    },
    proxy: {
      enabled: true,
      target: import.meta.env['VITE_API_BASE_URL'] || 'http://192.168.31.84:3000',
      changeOrigin: true,
      secure: false
    },
    cors: {
      enabled: true,
      origin: '*',
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      headers: ['Origin', 'X-Requested-With', 'Content-Type', 'Accept', 'Authorization']
    }
  } as ServerConfig,

  features: {
    enableMock: false, // 由 mock.strategy 控制，这里保持向后兼容
    enableDebug: import.meta.env['VITE_ENABLE_DEBUG'] !== 'false', // 默认开启
    enableHMR: import.meta.env['VITE_ENABLE_HMR'] !== 'false', // 默认开启
    enableSourceMap: import.meta.env['VITE_ENABLE_SOURCE_MAP'] !== 'false', // 默认开启
    enableCoverage: import.meta.env['VITE_ENABLE_COVERAGE'] !== 'false', // 默认开启
    enableE2E: import.meta.env['VITE_ENABLE_E2E'] === 'true',
    enablePWA: import.meta.env['VITE_ENABLE_PWA'] === 'true',
    enableAnalytics: import.meta.env['VITE_ENABLE_ANALYTICS'] === 'true'
  } as FeatureFlags,

  mock: {
    strategy: (import.meta.env['VITE_MOCK_STRATEGY'] as any) || 'auto',
    fallbackTimeout: parseInt(import.meta.env['VITE_MOCK_FALLBACK_TIMEOUT'] || '3000'),
    showIndicator: import.meta.env['VITE_MOCK_SHOW_INDICATOR'] !== 'false', // 默认显示
    logRequests: import.meta.env['VITE_MOCK_LOG_REQUESTS'] !== 'false', // 默认记录
    hybridEndpoints: import.meta.env['VITE_MOCK_HYBRID_ENDPOINTS']?.split(',') || []
  } as MockConfig,

  monitoring: {
    enabled: true,
    endpoint: '/api/monitoring',
    sampleRate: 1.0, // 开发环境100%采样
    enablePerformance: true,
    enableErrors: true,
    enableUserActions: true
  } as MonitoringConfig,

  security: {
    enableHTTPS: false,
    trustedDomains: ['localhost', '127.0.0.1', '192.168.31.84', '0.0.0.0']
  }
};