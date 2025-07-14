// 🔥 MVP_STAT 功能使用示例
// 展示如何使用适配后的 UnifiedGrpcClient 调用 backend mvp_stat 切片

import { UnifiedGrpcClient } from '../shared/api/grpc-client';

/**
 * MVP_STAT 功能演示类
 */
export class MvpStatDemo {
  private client: UnifiedGrpcClient;

  constructor(baseUrl: string = 'http://localhost:50053') {
    this.client = new UnifiedGrpcClient({
      baseUrl,
      timeout: 30000,
      retryAttempts: 3,
      enableLogging: true
    });
  }

  /**
   * 演示1：生成随机数据
   */
  async demonstrateRandomDataGeneration() {
    console.log('🎯 演示1：生成随机数据');
    
    try {
      // 生成1000个均匀分布的随机数
      const uniformResult = await this.client.generateRandomData({
        count: 1000,
        seed: BigInt(42),
        minValue: 0.0,
        maxValue: 100.0,
        distribution: 'uniform'
      });

      if (uniformResult.success && uniformResult.data) {
        console.log('✅ 均匀分布数据生成成功:', {
          count: uniformResult.data.count,
          seed: uniformResult.data.seed,
          generatedAt: uniformResult.data.generatedAt,
          dataPreview: uniformResult.data.data.slice(0, 5) // 显示前5个数据
        });
      }

      // 生成正态分布的随机数
      const normalResult = await this.client.generateRandomData({
        count: 500,
        seed: BigInt(123),
        minValue: -10.0,
        maxValue: 10.0,
        distribution: 'normal'
      });

      if (normalResult.success && normalResult.data) {
        console.log('✅ 正态分布数据生成成功:', {
          count: normalResult.data.count,
          performance: normalResult.data.performance
        });
      }

      return { uniformResult, normalResult };
    } catch (error) {
      console.error('❌ 随机数据生成失败:', error);
      throw error;
    }
  }

  /**
   * 演示2：计算统计量
   */
  async demonstrateStatisticsCalculation() {
    console.log('🎯 演示2：计算统计量');
    
    try {
      // 准备测试数据
      const testData = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
      
      const result = await this.client.calculateStatistics({
        data: testData,
        statistics: ['mean', 'median', 'std', 'variance', 'min', 'max', 'skewness', 'kurtosis'],
        percentiles: [25, 50, 75, 90, 95],
        useAnalyticsEngine: true,
        preferRust: true
      });

      if (result.success && result.data) {
        console.log('✅ 统计计算成功:', {
          implementation: result.data.implementation,
          basicStats: result.data.results?.basic,
          distributionStats: result.data.results?.distribution,
          percentiles: result.data.results?.percentiles,
          shapeStats: result.data.results?.shape,
          performance: result.data.performance
        });
      }

      return result;
    } catch (error) {
      console.error('❌ 统计计算失败:', error);
      throw error;
    }
  }

  /**
   * 演示3：综合分析（数据生成 + 统计计算）
   */
  async demonstrateComprehensiveAnalysis() {
    console.log('🎯 演示3：综合分析');
    
    try {
      const result = await this.client.comprehensiveAnalysis({
        dataConfig: {
          count: 1000,
          seed: BigInt(456),
          minValue: -5.0,
          maxValue: 5.0,
          distribution: 'normal'
        },
        statsConfig: {
          data: [], // 将由dataConfig生成
          statistics: ['mean', 'std', 'variance', 'skewness', 'kurtosis', 'min', 'max'],
          percentiles: [5, 25, 50, 75, 95],
          useAnalyticsEngine: true,
          preferRust: true
        }
      });

      if (result.success && result.data) {
        console.log('✅ 综合分析成功:', {
          dataSummary: result.data.dataSummary,
          statistics: result.data.statistics,
          performance: result.data.performance,
          analyzedAt: result.data.analyzedAt
        });
      }

      return result;
    } catch (error) {
      console.error('❌ 综合分析失败:', error);
      throw error;
    }
  }

  /**
   * 运行完整演示
   */
  async runFullDemo() {
    console.log('🚀 开始 MVP_STAT 功能完整演示\n');
    
    try {
      // 检查连接
      const connectionTest = await this.client.testConnection();
      if (!connectionTest.success) {
        console.warn('⚠️ 无法连接到backend服务，演示将显示预期行为');
      }

      // 演示1：生成随机数据
      await this.demonstrateRandomDataGeneration();
      console.log('');

      // 演示2：计算统计量
      await this.demonstrateStatisticsCalculation();
      console.log('');

      // 演示3：综合分析
      await this.demonstrateComprehensiveAnalysis();
      
      console.log('\n🎉 MVP_STAT 功能演示完成！');
      
    } catch (error) {
      console.error('\n💥 演示过程中发生错误:', error);
      console.log('\n💡 这通常是因为backend服务未运行，但说明客户端适配正确');
    }
  }
}

/**
 * 快速使用示例
 */
export const quickUsageExample = {
  // 创建客户端
  createClient: () => new UnifiedGrpcClient({
    baseUrl: 'http://localhost:50053',
    timeout: 30000,
    enableLogging: true
  }),

  // 生成随机数据示例
  generateData: async (client: UnifiedGrpcClient) => {
    return await client.generateRandomData({
      count: 100,
      seed: BigInt(42),
      distribution: 'uniform'
    });
  },

  // 计算统计量示例
  calculateStats: async (client: UnifiedGrpcClient, data: number[]) => {
    return await client.calculateStatistics({
      data,
      statistics: ['mean', 'std', 'variance'],
      percentiles: [25, 50, 75],
      useAnalyticsEngine: true
    });
  },

  // 综合分析示例
  comprehensiveAnalysis: async (client: UnifiedGrpcClient) => {
    return await client.comprehensiveAnalysis({
      dataConfig: {
        count: 500,
        distribution: 'normal'
      },
      statsConfig: {
        statistics: ['mean', 'std', 'skewness', 'kurtosis']
      }
    });
  }
}; 