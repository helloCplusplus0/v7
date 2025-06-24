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
  },
  
  build: {
    target: 'esnext',
    sourcemap: true,
  },
});
