// 全局类型定义
import { vi } from 'vitest';

declare global {
  // 测试环境全局变量
  var global: typeof globalThis;
  
  // Vitest全局函数
  var describe: typeof import('vitest').describe;
  var test: typeof import('vitest').test;
  var expect: typeof import('vitest').expect;
  var beforeEach: typeof import('vitest').beforeEach;
  var afterEach: typeof import('vitest').afterEach;
  var vi: typeof import('vitest').vi;

  // 浏览器API模拟
  interface Window {
    fetch: typeof fetch;
  }

  // 自定义事件类型
  interface CustomEventMap {
    'navigate-to-slice': CustomEvent<{ slice: string; action: string }>;
  }
}

export {}; 