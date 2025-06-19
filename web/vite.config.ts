import { defineConfig } from 'vite';
import solidPlugin from 'vite-plugin-solid';
import path from 'path';
import { fileURLToPath } from 'url';
import { createViteConfig, loadViteEnv } from './config/vite';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export default defineConfig(({ mode }) => {
  // 加载环境变量
  const env = loadViteEnv(mode);
  
  // 环境判断
  const isDevelopment = mode === 'development';
  const isProduction = mode === 'production';
  
  // 获取基础配置
  const baseConfig = createViteConfig({
    mode,
    isDevelopment,
    isProduction,
    env
  });
  
  return {
    plugins: [solidPlugin()],
    
    resolve: {
      alias: {
        '@': path.resolve(__dirname, '.'),
        '@/slices': path.resolve(__dirname, './slices'),
        '@/shared': path.resolve(__dirname, './src/shared'),
        '@/src': path.resolve(__dirname, './src'),
        '@/tests': path.resolve(__dirname, './tests'),
        '@/types': path.resolve(__dirname, './types'),
        '@/config': path.resolve(__dirname, './config'),
      },
    },
    
    // 使用统一配置
    ...baseConfig,
  };
});
