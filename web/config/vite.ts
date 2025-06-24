 /**
 * 🔧 Vite 配置工具
 * 为Vite提供统一的配置生成
 */

import { loadEnv, type UserConfig } from 'vite';

export interface ViteConfigOptions {
  mode: string;
  isDevelopment: boolean;
  isProduction: boolean;
  env: Record<string, string>;
}

export function createViteConfig(options: ViteConfigOptions): UserConfig {
  const { isDevelopment, isProduction, env } = options;
  
  // 服务器配置
  const serverConfig = {
    host: env['VITE_DEV_SERVER_HOST'] || '0.0.0.0',
    port: parseInt(env['VITE_DEV_SERVER_PORT'] || '5173'),
    hmrPort: parseInt(env['VITE_HMR_PORT'] || '5173'),
    hmrHost: env['VITE_HMR_HOST'] || env['VITE_DEV_SERVER_HOST'] || '192.168.31.84', // 修复：使用具体IP
    apiBaseUrl: env['VITE_API_BASE_URL'] || (isDevelopment ? 'http://192.168.31.84:3000' : '/api')
  };
  
  return {
    server: {
      port: serverConfig.port,
      host: serverConfig.host,
      strictPort: true,
      open: false,

      
      ...(isDevelopment && {
        proxy: {
          '/api': {
            target: serverConfig.apiBaseUrl,
            changeOrigin: true,
            rewrite: (path) => path.replace(/^\/api/, '/api'),
            secure: false,
            timeout: 10000,
          }
        }
      }),
      
      fs: {
        allow: ['..', '../..']
      },
      
      hmr: isDevelopment ? {
        port: serverConfig.hmrPort,
        host: serverConfig.hmrHost,
        overlay: true,
        clientPort: serverConfig.hmrPort
      } : false,
      
      cors: true,
    },
    
    build: {
      target: 'esnext',
      outDir: 'dist',
      assetsDir: 'assets',
      sourcemap: isDevelopment,
      minify: isProduction ? 'esbuild' : false,
      
      rollupOptions: {
        output: {
          manualChunks: {
            vendor: ['solid-js'],
            router: ['@solidjs/router'],
          }
        }
      },
      
      chunkSizeWarningLimit: 1000,
    },
    
    optimizeDeps: {
      include: ['solid-js', 'solid-js/web'],
      exclude: ['@solidjs/router', '@solidjs/testing-library']
    },
    
    define: {
      __DEV__: isDevelopment,
      __PROD__: isProduction,
    },
  };
}

export function loadViteEnv(mode: string) {
  return loadEnv(mode, '.', '');
}