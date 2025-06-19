 /**
 * 🔧 生产环境配置
 * 针对生产部署优化的配置
 */

import type { ApiConfig, ServerConfig, FeatureFlags, MonitoringConfig, MockConfig } from './types';

export const productionConfig = {
  app: {
    name: 'FMOD Web Application'
  },

  api: {
    baseUrl: import.meta.env['VITE_API_BASE_URL'] || '/api',
    timeout: 8000 // 生产环境更短的超时时间
  } as Partial<ApiConfig>,

  server: {
    host: '0.0.0.0',
    port: 80,
    hmr: {
      port: 0, // 生产环境禁用HMR
      host: '0.0.0.0',
      overlay: false
    },
    proxy: {
      enabled: false, // 生产环境通常不需要代理
      target: '',
      changeOrigin: false,
      secure: true
    },
    cors: {
      enabled: true,
      origin: [
        'https://yourdomain.com',
        'https://www.yourdomain.com'
      ],
      methods: ['GET', 'POST', 'PUT', 'DELETE'],
      headers: ['Origin', 'X-Requested-With', 'Content-Type', 'Accept', 'Authorization']
    }
  } as ServerConfig,

  features: {
    enableMock: false, // 由 mock.strategy 控制
    enableDebug: import.meta.env['VITE_ENABLE_DEBUG'] === 'true',
    enableHMR: false, // 生产环境强制禁用
    enableSourceMap: import.meta.env['VITE_ENABLE_SOURCE_MAP'] === 'true',
    enableCoverage: false, // 生产环境强制禁用
    enableE2E: false, // 生产环境强制禁用
    enablePWA: import.meta.env['VITE_ENABLE_PWA'] !== 'false', // 默认开启
    enableAnalytics: import.meta.env['VITE_ENABLE_ANALYTICS'] !== 'false' // 默认开启
  } as FeatureFlags,

  mock: {
    strategy: (import.meta.env['VITE_MOCK_STRATEGY'] as any) || 'disabled', // 生产环境默认禁用
    fallbackTimeout: parseInt(import.meta.env['VITE_MOCK_FALLBACK_TIMEOUT'] || '1000'),
    showIndicator: false, // 生产环境不显示指示器
    logRequests: false, // 生产环境不记录日志
    hybridEndpoints: []
  } as MockConfig,

  monitoring: {
    enabled: true,
    endpoint: '/api/monitoring',
    sampleRate: 0.1, // 生产环境10%采样
    enablePerformance: true,
    enableErrors: true,
    enableUserActions: false // 生产环境不记录用户操作
  } as MonitoringConfig,

  security: {
    enableHTTPS: true,
    trustedDomains: ['yourdomain.com', 'www.yourdomain.com']
  }
};