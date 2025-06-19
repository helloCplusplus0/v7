 /**
 * 🎭 智能 Mock 管理器
 * 
 * 功能：
 * - 自动检测后端服务状态
 * - 智能切换 Mock/真实数据
 * - 提供状态指示器
 * - 记录请求日志
 */

import { config } from '@/config';
import type { MockStrategy } from '@/config/types';

export interface MockStatus {
  isActive: boolean;
  strategy: MockStrategy;
  backendAvailable: boolean;
  lastCheck: Date;
  requestCount: number;
  mockCount: number;
}

class MockManager {
  private status: MockStatus = {
    isActive: false,
    strategy: 'auto',
    backendAvailable: false,
    lastCheck: new Date(),
    requestCount: 0,
    mockCount: 0
  };

  private backendCheckPromise: Promise<boolean> | null = null;
  private indicator: HTMLElement | null = null;

  constructor() {
    this.status.strategy = config.mock.strategy;
    this.initializeIndicator();
    this.checkBackendStatus();
  }

  /**
   * 检查后端服务是否可用
   */
  async checkBackendStatus(): Promise<boolean> {
    // 避免重复检查
    if (this.backendCheckPromise) {
      return this.backendCheckPromise;
    }

    this.backendCheckPromise = this.performBackendCheck();
    const result = await this.backendCheckPromise;
    this.backendCheckPromise = null;
    
    return result;
  }

  private async performBackendCheck(): Promise<boolean> {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), config.mock.fallbackTimeout);

      const response = await fetch(config.api.baseUrl + config.api.endpoints.health, {
        method: 'GET',
        signal: controller.signal,
        headers: {
          'X-Health-Check': 'true'
        }
      });

      clearTimeout(timeoutId);
      
      const isAvailable = response.ok;
      this.updateBackendStatus(isAvailable);
      
      if (config.mock.logRequests) {
        console.log(`🏥 Backend health check: ${isAvailable ? '✅ Available' : '❌ Unavailable'}`);
      }
      
      return isAvailable;
    } catch (error) {
      this.updateBackendStatus(false);
      
      if (config.mock.logRequests) {
        console.log('🏥 Backend health check: ❌ Failed', error);
      }
      
      return false;
    }
  }

  private updateBackendStatus(available: boolean) {
    this.status.backendAvailable = available;
    this.status.lastCheck = new Date();
    this.updateIndicator();
  }

  /**
   * 判断是否应该使用 Mock 数据
   */
  async shouldUseMock(endpoint: string): Promise<boolean> {
    this.status.requestCount++;

    switch (this.status.strategy) {
      case 'force':
        this.status.mockCount++;
        this.status.isActive = true;
        this.updateIndicator();
        return true;

      case 'disabled':
        this.status.isActive = false;
        this.updateIndicator();
        return false;

      case 'hybrid':
        const shouldMock = config.mock.hybridEndpoints?.includes(endpoint) || false;
        if (shouldMock) {
          this.status.mockCount++;
          this.status.isActive = true;
        }
        this.updateIndicator();
        return shouldMock;

      case 'auto':
      default:
        const backendAvailable = await this.checkBackendStatus();
        const shouldUseMock = !backendAvailable;
        
        if (shouldUseMock) {
          this.status.mockCount++;
          this.status.isActive = true;
        } else {
          this.status.isActive = false;
        }
        
        this.updateIndicator();
        return shouldUseMock;
    }
  }

  /**
   * 手动切换 Mock 策略
   */
  setStrategy(strategy: MockStrategy) {
    this.status.strategy = strategy;
    
    if (config.mock.logRequests) {
      console.log(`🎭 Mock strategy changed to: ${strategy}`);
    }
    
    this.updateIndicator();
  }

  /**
   * 获取当前状态
   */
  getStatus(): MockStatus {
    return { ...this.status };
  }

  /**
   * 初始化状态指示器
   */
  private initializeIndicator() {
    if (!config.mock.showIndicator || typeof document === 'undefined') {
      return;
    }

    this.indicator = document.createElement('div');
    this.indicator.id = 'mock-indicator';
    this.indicator.style.cssText = `
      position: fixed;
      top: 10px;
      right: 10px;
      z-index: 9999;
      padding: 8px 12px;
      border-radius: 6px;
      font-family: monospace;
      font-size: 12px;
      font-weight: bold;
      color: white;
      cursor: pointer;
      transition: all 0.3s ease;
      user-select: none;
    `;

    this.indicator.addEventListener('click', () => {
      this.showDetailedStatus();
    });

    document.body.appendChild(this.indicator);
    this.updateIndicator();
  }

  /**
   * 更新状态指示器
   */
  private updateIndicator() {
    if (!this.indicator) return;

    const { isActive, strategy, backendAvailable, requestCount, mockCount } = this.status;
    
    if (isActive) {
      this.indicator.style.backgroundColor = '#ff6b35';
      this.indicator.textContent = `🎭 MOCK (${strategy.toUpperCase()})`;
      this.indicator.title = `Mock 模式激活\n策略: ${strategy}\n请求: ${requestCount}\nMock: ${mockCount}`;
    } else {
      this.indicator.style.backgroundColor = backendAvailable ? '#28a745' : '#6c757d';
      this.indicator.textContent = backendAvailable ? '🔗 REAL' : '⚠️ OFFLINE';
      this.indicator.title = `真实数据模式\n后端: ${backendAvailable ? '可用' : '不可用'}\n请求: ${requestCount}`;
    }
  }

  /**
   * 显示详细状态信息
   */
  private showDetailedStatus() {
    const status = this.getStatus();
    const info = [
      `🎭 Mock Manager Status`,
      ``,
      `Strategy: ${status.strategy}`,
      `Mock Active: ${status.isActive ? 'Yes' : 'No'}`,
      `Backend Available: ${status.backendAvailable ? 'Yes' : 'No'}`,
      `Last Check: ${status.lastCheck.toLocaleTimeString()}`,
      `Total Requests: ${status.requestCount}`,
      `Mock Requests: ${status.mockCount}`,
      `Real Requests: ${status.requestCount - status.mockCount}`,
      ``,
      `Click to copy status to clipboard`
    ].join('\n');

    console.log(info);
    
    // 复制到剪贴板
    if (navigator.clipboard) {
      navigator.clipboard.writeText(info).then(() => {
        console.log('📋 Status copied to clipboard');
      });
    }
  }

  /**
   * 重置统计信息
   */
  resetStats() {
    this.status.requestCount = 0;
    this.status.mockCount = 0;
    this.updateIndicator();
  }
}

// 创建全局实例
export const mockManager = new MockManager();

// 导出便捷方法
export const shouldUseMock = (endpoint: string) => mockManager.shouldUseMock(endpoint);
export const setMockStrategy = (strategy: MockStrategy) => mockManager.setStrategy(strategy);
export const getMockStatus = () => mockManager.getStatus();
export const resetMockStats = () => mockManager.resetStats();

// 开发环境下暴露到全局
if (config.runtime.isDevelopment && typeof window !== 'undefined') {
  (window as any).mockManager = {
    shouldUseMock,
    setStrategy: setMockStrategy,
    getStatus: getMockStatus,
    resetStats: resetMockStats,
    checkBackend: () => mockManager.checkBackendStatus()
  };
}