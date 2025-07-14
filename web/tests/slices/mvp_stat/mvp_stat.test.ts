// 🧪 MVP STAT - 测试用例
// 验证MVP统计分析功能切片的正确性

import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest';
import { cleanup } from '@solidjs/testing-library';
import type { 
  GenerateDataRequest, 
  CalculateStatsRequest
} from '../../../slices/mvp_stat/types';

// Mock shared API
vi.mock('../../../shared/api/grpc-client', () => ({
  grpcClient: {
    generateRandomData: vi.fn(),
    calculateStatistics: vi.fn(),
    comprehensiveAnalysis: vi.fn()
  }
}));

// Mock shared hooks
vi.mock('../../../shared/hooks/useDebounce', () => ({
  useDebounce: vi.fn((value) => () => value())
}));

// Mock shared signals
vi.mock('../../../shared/signals/accessors', () => ({
  createNotificationAccessor: () => ({
    show: vi.fn(),
    getNotifications: () => [],
    setNotifications: vi.fn(),
    addNotification: vi.fn(),
    removeNotification: vi.fn(),
    clearNotifications: vi.fn()
  })
}));

// Mock event bus
vi.mock('../../../shared/events/EventBus', () => ({
  eventBus: {
    emit: vi.fn(),
    on: vi.fn(() => () => {}),
    off: vi.fn(),
    removeAllListeners: vi.fn()
  }
}));

describe('MVP Stat API', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    cleanup();
  });

  describe('generateRandomData', () => {
    test('应该成功生成随机数据', async () => {
      const mockResponse = {
        success: true,
        data: {
          data: [1, 2, 3, 4, 5],
          count: 5,
          seed: 42n,
          generatedAt: new Date().toISOString(),
          performance: {
            executionTimeMs: 10n,
            implementation: 'rust',
            metrics: {}
          }
        }
      };

      const { grpcClient } = await import('../../../shared/api/grpc-client');
      vi.mocked(grpcClient.generateRandomData).mockResolvedValue(mockResponse as any);

      const request: GenerateDataRequest = {
        count: 5,
        distribution: 'uniform',
        minValue: 0,
        maxValue: 10,
        seed: 42
      };

      const { mvpStatApi } = await import('../../../slices/mvp_stat/api');
      const result = await mvpStatApi.generateRandomData(request);
      
      expect(result).toBeDefined();
      expect(result.data).toHaveLength(5);
      expect(result.count).toBe(5);
      expect(grpcClient.generateRandomData).toHaveBeenCalledWith({
        count: 5,
        distribution: 'uniform',
        minValue: 0,
        maxValue: 10,
        seed: 42
      });
    });
  });

  describe('calculateStatistics', () => {
    test('应该成功计算统计量', async () => {
      const mockResponse = {
        success: true,
        data: {
          results: {
            basic: {
              count: 5,
              mean: 3,
              min: 1,
              max: 5,
              sum: 15,
              range: 4
            },
            distribution: {
              median: 3,
              stdDev: 1.58,
              variance: 2.5,
              mode: [],
              iqr: 2
            }
          },
          performance: {
            executionTimeMs: 5n,
            implementation: 'rust',
            metrics: {}
          },
          implementation: 'rust'
        }
      };

      const { grpcClient } = await import('../../../shared/api/grpc-client');
      vi.mocked(grpcClient.calculateStatistics).mockResolvedValue(mockResponse as any);

      const request: CalculateStatsRequest = {
        data: [1, 2, 3, 4, 5],
        statistics: ['mean', 'median', 'std'],
        useAnalyticsEngine: true
      };

      const { mvpStatApi } = await import('../../../slices/mvp_stat/api');
      const result = await mvpStatApi.calculateStatistics(request);
      
      expect(result).toBeDefined();
      expect(result.results.basic?.mean).toBe(3);
      expect(result.results.distribution?.median).toBe(3);
      expect(grpcClient.calculateStatistics).toHaveBeenCalledWith({
        data: [1, 2, 3, 4, 5],
        statistics: ['mean', 'median', 'std'],
        percentiles: [],
        useAnalyticsEngine: true,
        preferRust: true
      });
    });
  });

  describe('错误处理', () => {
    test('应该正确处理网络错误', async () => {
      const { grpcClient } = await import('../../../shared/api/grpc-client');
      vi.mocked(grpcClient.generateRandomData).mockRejectedValue(new Error('Network error'));

      const { mvpStatApi } = await import('../../../slices/mvp_stat/api');
      
      await expect(mvpStatApi.generateRandomData({ count: 10 })).rejects.toThrow('Network error');
    });

    test('应该正确处理服务端错误', async () => {
      const { grpcClient } = await import('../../../shared/api/grpc-client');
      vi.mocked(grpcClient.generateRandomData).mockResolvedValue({
        success: false,
        error: 'Invalid parameters'
      });

      const { mvpStatApi } = await import('../../../slices/mvp_stat/api');
      
      await expect(mvpStatApi.generateRandomData({ count: -1 })).rejects.toThrow('Invalid parameters');
    });
  });

  describe('性能测试', () => {
    test('应该在合理时间内完成大数据量生成', async () => {
      const largeDataConfig: GenerateDataRequest = {
        count: 10000,
        distribution: 'normal',
        minValue: 0,
        maxValue: 100
      };

      const mockResponse = {
        success: true,
        data: {
          data: new Array(10000).fill(0).map(() => Math.random() * 100),
          count: 10000,
          seed: 42n,
          generatedAt: new Date().toISOString(),
          performance: { 
            executionTimeMs: 10n, 
            implementation: 'rust', 
            metrics: {}
          }
        }
      };

      const { grpcClient } = await import('../../../shared/api/grpc-client');
      vi.mocked(grpcClient.generateRandomData).mockResolvedValue(mockResponse as any);

      const { mvpStatApi } = await import('../../../slices/mvp_stat/api');
      const startTime = Date.now();
      const result = await mvpStatApi.generateRandomData(largeDataConfig);
      const endTime = Date.now();

      expect(result.count).toBe(10000);
      expect(endTime - startTime).toBeLessThan(1000); // 应该在1秒内完成
    });
  });

  describe('集成测试', () => {
    test('应该能够完成完整的数据生成和统计计算流程', async () => {
      // Mock 数据生成响应
      const generateResponse = {
        success: true,
        data: {
          data: [1, 2, 3, 4, 5],
          count: 5,
          seed: 42n,
          generatedAt: new Date().toISOString(),
          performance: { 
            executionTimeMs: 10n, 
            implementation: 'rust', 
            metrics: {}
          }
        }
      };

      // Mock 统计计算响应
      const calculateResponse = {
        success: true,
        data: {
          results: {
            basic: { 
              count: 5, 
              mean: 3, 
              min: 1, 
              max: 5,
              sum: 15,
              range: 4
            },
            distribution: { 
              median: 3, 
              stdDev: 1.58, 
              variance: 2.5,
              mode: [],
              iqr: 2
            }
          },
          performance: { 
            executionTimeMs: 5n, 
            implementation: 'rust', 
            metrics: {}
          },
          implementation: 'rust'
        }
      };

      // Mock 综合分析响应
      const comprehensiveResponse = {
        success: true,
        data: {
          dataSummary: { 
            count: 5, 
            preview: [1, 2, 3, 4, 5],
            seed: 42n,
            distribution: 'uniform'
          },
          statistics: {
            basic: { 
              count: 5, 
              mean: 3, 
              min: 1, 
              max: 5,
              sum: 15,
              range: 4
            },
            distribution: { 
              median: 3, 
              stdDev: 1.58, 
              variance: 2.5,
              mode: [],
              iqr: 2
            }
          },
          performance: { 
            executionTimeMs: 15n, 
            implementation: 'rust', 
            metrics: {}
          },
          analyzedAt: new Date().toISOString(),
          insights: {
            dataQuality: 'fair',
            distributionType: 'uniform',
            outlierCount: 0,
            recommendedActions: []
          }
        }
      };

      const { grpcClient } = await import('../../../shared/api/grpc-client');
      vi.mocked(grpcClient.generateRandomData).mockResolvedValue(generateResponse as any);
      vi.mocked(grpcClient.calculateStatistics).mockResolvedValue(calculateResponse as any);
      vi.mocked(grpcClient.comprehensiveAnalysis).mockResolvedValue(comprehensiveResponse as any);

      const { mvpStatApi } = await import('../../../slices/mvp_stat/api');

      // 执行完整流程
      const generateResult = await mvpStatApi.generateRandomData({
        count: 5,
        distribution: 'uniform'
      });
      expect(generateResult.count).toBe(5);

      const calculateResult = await mvpStatApi.calculateStatistics({
        data: generateResult.data,
        statistics: ['mean', 'median']
      });
      expect(calculateResult.results.basic?.mean).toBe(3);

      const comprehensiveResult = await mvpStatApi.comprehensiveAnalysis({
        dataConfig: { count: 5, distribution: 'uniform' },
        statsConfig: { statistics: ['mean', 'median'] }
      });
      expect(comprehensiveResult.insights.dataQuality).toBe('fair');
    });
  });
}); 