import { vi } from 'vitest';

/**
 * 等待异步操作完成
 */
export function waitForAsync(timeout = 1000): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, timeout);
  });
}

/**
 * 创建Mock函数的工厂
 */
export function createMockFunction<T extends (...args: any[]) => any>(
  implementation?: T
): any {
  const mockFn = vi.fn() as any;
  if (implementation) {
    mockFn.mockImplementation(implementation);
  }
  return mockFn;
}

/**
 * 测试数据生成器
 */
export class TestDataGenerator {
  static randomString(length = 10): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }

  static randomNumber(min = 0, max = 100): number {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  static randomBoolean(): boolean {
    return Math.random() < 0.5;
  }
} 