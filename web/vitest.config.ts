import { defineConfig } from 'vitest/config';
import { resolve } from 'path';
import solid from 'vite-plugin-solid';

export default defineConfig({
  plugins: [solid()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./tests/setup.ts'],
    include: [
      'src/**/*_test.{ts,tsx}',
      'slices/**/*_test.{ts,tsx}',
      'tests/**/*.test.{ts,tsx}',
    ],
    exclude: [
      'node_modules/**',
      'dist/**',
      '.vite/**',
    ],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/**',
        'tests/**',
        '**/*.test.{ts,tsx}',
        '**/*_test.{ts,tsx}',
        'dist/**',
        '.vite/**',
        'vite.config.ts',
        'vitest.config.ts',
      ],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 80,
          statements: 80,
        },
      },
    },
    server: {
      deps: {
        inline: ['@solidjs/testing-library', '@solidjs/router', 'msw'],
      },
    },
    testTimeout: 10000,
    hookTimeout: 10000,
  },
  resolve: {
    conditions: ['development', 'browser'],
    alias: {
      '@': resolve(__dirname, '.'),
      '@/slices': resolve(__dirname, './slices'),
      '@/shared': resolve(__dirname, './src/shared'),
      '@/src': resolve(__dirname, './src'),
      '@/tests': resolve(__dirname, './tests'),
      '@/types': resolve(__dirname, './types'),
      '@/config': resolve(__dirname, './config'),
    },
  },
}); 