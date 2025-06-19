 /**
 * 🔧 FMOD Web 统一配置管理系统
 * 
 * 提供开发和生产环境的统一配置管理
 * 所有配置项都在此文件中定义，避免分散配置
 */

import { developmentConfig } from './development';
import { productionConfig } from './production';
import { commonConfig } from './common';
import type { AppConfig } from './types';

// 获取当前环境
const isDevelopment = import.meta.env.DEV;
const isProduction = import.meta.env.PROD;

// 合并配置
const environmentConfig = isDevelopment ? developmentConfig : productionConfig;

// 合并配置并确保类型完整性
const mergedConfig = {
  ...commonConfig,
  ...environmentConfig,
  // 运行时信息
  runtime: {
    isDevelopment,
    isProduction,
    mode: import.meta.env.MODE,
    timestamp: new Date().toISOString(),
  }
};

// 导出最终配置
export const config: AppConfig = mergedConfig as AppConfig;

// 便捷导出
export const {
  app,
  api,
  server,
  ui,
  features,
  monitoring,
  security,
  runtime
} = config;

// 调试信息（仅开发环境）
if (isDevelopment) {
  console.log('🔧 Configuration loaded:', {
    mode: runtime.mode,
    api: api.baseUrl,
    features: Object.keys(features).filter(key => features[key as keyof typeof features]),
    timestamp: runtime.timestamp
  });
}

export default config;