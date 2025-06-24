import { defineConfig } from 'vitest/config';
import solid from 'vite-plugin-solid';

export default defineConfig({
  plugins: [solid() as any],
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
    },
    testTimeout: 30000,
    hookTimeout: 30000,
  },
});
