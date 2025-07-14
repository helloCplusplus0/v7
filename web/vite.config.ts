import { defineConfig } from 'vite';
import solidPlugin from 'vite-plugin-solid';

export default defineConfig({
  plugins: [solidPlugin()],
  
  resolve: {
    alias: {
      '@': '.',
      '@/slices': './slices',
      '@/shared': './src/shared',
      '@/src': './src',
      '@/tests': './tests',
      '@/types': './types',
      '@/config': './config',
    },
  },
  
  server: {
    host: '0.0.0.0',
    port: 5173,
    proxy: {
      // gRPC-Web代理配置 - 代理所有gRPC服务请求
      '/v7.backend.BackendService': {
        target: 'http://192.168.31.84:50053',
        changeOrigin: true,
        secure: false,
        ws: false,
        timeout: 30000, // 30秒超时
        configure: (proxy, _options) => {
          proxy.on('error', (err, req, res) => {
            console.log('🔴 Proxy error:', err);
            console.log('🔴 Request URL:', req.url);
            console.log('🔴 Request method:', req.method);
            if (res && !res.headersSent) {
              res.writeHead(500, { 'Content-Type': 'text/plain' });
              res.end('Proxy error: ' + err.message);
            }
          });
          proxy.on('proxyReq', (proxyReq, req, _res) => {
            console.log('🚀 Proxying request:', req.method, req.url);
            console.log('🚀 Headers:', req.headers);
            
            // 转发所有必要的headers
            const headersToForward = [
              'content-type',
              'connect-protocol-version',
              'connect-timeout-ms',
              'x-grpc-web',
              'grpc-timeout',
              'accept',
              'accept-encoding',
              'user-agent',
              'authorization'
            ];
            
            headersToForward.forEach(header => {
              if (req.headers[header]) {
                proxyReq.setHeader(header, req.headers[header]);
              }
            });
            
            // 确保正确的Content-Length
            if (req.headers['content-length']) {
              proxyReq.setHeader('content-length', req.headers['content-length']);
            }
          });
          proxy.on('proxyRes', (proxyRes, req, _res) => {
            console.log('📡 Proxy response:', proxyRes.statusCode, req.url);
            console.log('📡 Response headers:', proxyRes.headers);
          });
        },
      },
      // 备用代理配置 - 匹配所有可能的gRPC路径
      '^/.*\\..*Service/.*': {
        target: 'http://192.168.31.84:50053',
        changeOrigin: true,
        secure: false,
        ws: false,
        timeout: 30000,
        configure: (proxy, _options) => {
          proxy.on('error', (err, req, res) => {
            console.log('🔴 Fallback proxy error:', err);
            console.log('🔴 Request URL:', req.url);
            if (res && !res.headersSent) {
              res.writeHead(500, { 'Content-Type': 'text/plain' });
              res.end('Fallback proxy error: ' + err.message);
            }
          });
          proxy.on('proxyReq', (proxyReq, req, _res) => {
            console.log('🚀 Fallback proxying request:', req.method, req.url);
            
            // 转发所有必要的headers
            const headersToForward = [
              'content-type',
              'connect-protocol-version',
              'connect-timeout-ms',
              'x-grpc-web',
              'grpc-timeout',
              'accept',
              'accept-encoding',
              'user-agent',
              'authorization'
            ];
            
            headersToForward.forEach(header => {
              if (req.headers[header]) {
                proxyReq.setHeader(header, req.headers[header]);
              }
            });
          });
          proxy.on('proxyRes', (proxyRes, req, _res) => {
            console.log('📡 Fallback proxy response:', proxyRes.statusCode, req.url);
          });
        },
      }
    }
  },
  
  build: {
    target: 'esnext',
    sourcemap: true,
  },
});
