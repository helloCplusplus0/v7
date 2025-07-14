// 📊 MVP CRUD - 摘要数据提供者
// 为仪表板提供切片的关键指标和状态信息

import type { 
  SliceSummaryProvider, 
  SliceSummaryContract, 
  SliceMetric,
  SliceAction,
  SliceStatus
} from '../../src/shared/types';
import { crudApi } from './api';
import type { Item } from './types';

/**
 * MVP CRUD 摘要提供者
 * 实现 SliceSummaryProvider 接口，为仪表板提供实时的业务数据摘要
 * v7.2 更新：添加后端连通性检测，状态指示器基于连通性而非业务数据量
 */
export class MvpCrudSummaryProvider implements SliceSummaryProvider {
  private lastRefreshTime: Date | null = null;
  private cachedData: SliceSummaryContract | null = null;
  private cacheExpiryMs = 30000; // 30秒缓存过期时间
  
  // 连通性检测相关
  private lastConnectivityCheck: Date | null = null;
  private connectivityCacheMs = 10000; // 10秒连通性缓存
  private isBackendConnected: boolean = false;

  /**
   * 获取摘要数据
   * 提供项目管理的关键指标和状态
   */
  async getSummaryData(): Promise<SliceSummaryContract> {
    try {
      // 检查缓存是否有效
      if (this.cachedData && this.lastRefreshTime && 
          Date.now() - this.lastRefreshTime.getTime() < this.cacheExpiryMs) {
        return this.cachedData;
      }

      // 🎯 v7.2 新增：优先检查后端连通性
      const connectivityStatus = await this.checkBackendConnectivity();
      
      // 如果后端连通失败，直接返回错误状态
      if (!connectivityStatus.isConnected) {
        return this.getConnectivityErrorSummary(connectivityStatus.error);
      }

      // 后端连通正常，获取业务数据
      const response = await crudApi.listItems(100, 0); // 获取前100个项目用于统计
      const items = response.items || [];
      const totalCount = response.total || 0;
      
      // 计算业务指标
      const metrics = this.calculateMetrics(items, totalCount, connectivityStatus);
      
      // 🎯 v7.2 更新：状态基于连通性判断
      const status = this.determineStatusByConnectivity(connectivityStatus, items, totalCount);
      
      // 构建摘要数据
      this.cachedData = {
        title: 'MVP CRUD 项目管理',
        status,
        metrics,
        description: this.generateDescription(items, totalCount, connectivityStatus),
        lastUpdated: new Date(),
        alertCount: this.calculateAlertCount(items, totalCount),
        customActions: this.buildCustomActions()
      };

      this.lastRefreshTime = new Date();
      return this.cachedData;

    } catch (error) {
      console.error('❌ [MvpCrudSummaryProvider] 获取摘要数据失败:', error);
      return this.getErrorSummary(error);
    }
  }

  /**
   * 🎯 v7.2 新增：检查后端连通性
   * 返回连通性状态和错误信息
   */
  private async checkBackendConnectivity(): Promise<{
    isConnected: boolean;
    responseTime?: number;
    error?: string;
    lastCheck: Date;
  }> {
    // 检查连通性缓存
    if (this.lastConnectivityCheck && 
        Date.now() - this.lastConnectivityCheck.getTime() < this.connectivityCacheMs) {
      return {
        isConnected: this.isBackendConnected,
        lastCheck: this.lastConnectivityCheck,
        error: this.isBackendConnected ? undefined : '连接失败（缓存）'
      };
    }

    const startTime = Date.now();
    
    try {
      console.log('🔍 [MvpCrudSummaryProvider] 检查后端连通性...');
      
      // 使用健康检查API
      const isHealthy = await crudApi.healthCheck();
      const responseTime = Date.now() - startTime;
      
      // 更新缓存
      this.isBackendConnected = isHealthy;
      this.lastConnectivityCheck = new Date();
      
      console.log(isHealthy ? 
        `✅ [MvpCrudSummaryProvider] 后端连通正常 (${responseTime}ms)` : 
        `❌ [MvpCrudSummaryProvider] 后端健康检查失败 (${responseTime}ms)`
      );
      
      return {
        isConnected: isHealthy,
        responseTime,
        lastCheck: this.lastConnectivityCheck,
        error: isHealthy ? undefined : '健康检查失败'
      };
      
    } catch (error) {
      const responseTime = Date.now() - startTime;
      const errorMessage = error instanceof Error ? error.message : String(error);
      
      // 更新缓存
      this.isBackendConnected = false;
      this.lastConnectivityCheck = new Date();
      
      console.error(`❌ [MvpCrudSummaryProvider] 后端连通性检查异常 (${responseTime}ms):`, error);
      
      return {
        isConnected: false,
        responseTime,
        lastCheck: this.lastConnectivityCheck,
        error: errorMessage
      };
    }
  }

  /**
   * 刷新数据
   * 清除缓存并重新获取数据
   */
  async refreshData(): Promise<void> {
    this.cachedData = null;
    this.lastRefreshTime = null;
    // 🎯 v7.2 新增：同时清除连通性缓存
    this.lastConnectivityCheck = null;
    await this.getSummaryData();
  }

  /**
   * 🎯 v7.2 更新：计算业务指标，包含连通性信息
   */
  private calculateMetrics(items: Item[], totalCount: number, connectivity: any): SliceMetric[] {
    const metrics: SliceMetric[] = [];

    // 🎯 v7.2 新增：连通性指标（优先显示）
    metrics.push({
      label: '后端连通性',
      value: connectivity.isConnected ? '运行中' : '离线',
      trend: connectivity.isConnected ? 'up' : 'warning',
      icon: connectivity.isConnected ? '🟢' : '🔴',
      unit: connectivity.responseTime ? `${connectivity.responseTime}ms` : undefined
    });

    // 总项目数指标
    metrics.push({
      label: '总项目数',
      value: totalCount,
      trend: this.calculateTrend(totalCount),
      icon: '📦',
      unit: '个'
    });

    // 项目价值统计
    if (items.length > 0) {
      const totalValue = items.reduce((sum, item) => sum + (item.value || 0), 0);
      const avgValue = Math.round(totalValue / items.length);
      
      metrics.push({
        label: '总价值',
        value: totalValue.toLocaleString(),
        trend: totalValue > 10000 ? 'up' : totalValue > 1000 ? 'stable' : 'down',
        icon: '💰',
        unit: '元'
      });

      metrics.push({
        label: '平均价值',
        value: avgValue.toLocaleString(),
        trend: avgValue > 1000 ? 'up' : avgValue > 100 ? 'stable' : 'down',
        icon: '📊',
        unit: '元'
      });
    }

    // 最近活动指标
    const recentItems = items.filter(item => {
      const updatedAt = new Date(item.updatedAt);
      const now = new Date();
      const diffHours = (now.getTime() - updatedAt.getTime()) / (1000 * 60 * 60);
      return diffHours < 24; // 24小时内更新的项目
    });

    metrics.push({
      label: '近24h活动',
      value: recentItems.length,
      trend: recentItems.length > 0 ? 'up' : 'stable',
      icon: '🔄',
      unit: '个项目'
    });

    return metrics;
  }

  /**
   * 🎯 v7.2 更新：基于连通性确定整体状态
   * 连通性优先，业务数据其次
   */
  private determineStatusByConnectivity(
    connectivity: any, 
    items: Item[], 
    totalCount: number
  ): SliceStatus {
    // 🎯 连通性检查优先
    if (!connectivity.isConnected) {
      return 'error'; // 🔴 后端离线
    }
    
    // 连通性正常，返回健康状态
    return 'healthy'; // 🟢 后端连通正常
  }

  /**
   * 计算趋势
   */
  private calculateTrend(value: number): 'up' | 'down' | 'stable' | 'warning' {
    if (value === 0) return 'warning';
    if (value > 20) return 'up';
    if (value > 5) return 'stable';
    return 'down';
  }

  /**
   * 🎯 v7.2 更新：生成描述文本，包含连通性信息
   */
  private generateDescription(items: Item[], totalCount: number, connectivity: any): string {
    // 连通性状态描述
    const connectivityDesc = connectivity.isConnected ? 
      `后端服务连通正常（响应时间: ${connectivity.responseTime}ms）` : 
      `后端服务连接失败: ${connectivity.error}`;
    
    if (totalCount === 0) {
      return `${connectivityDesc}。暂无项目数据，点击"创建项目"开始管理您的第一个项目。`;
    }

    const totalValue = items.reduce((sum, item) => sum + (item.value || 0), 0);
    const avgValue = Math.round(totalValue / items.length);
    
    const recentCount = items.filter(item => {
      const updatedAt = new Date(item.updatedAt);
      const now = new Date();
      const diffHours = (now.getTime() - updatedAt.getTime()) / (1000 * 60 * 60);
      return diffHours < 24;
    }).length;

    return `${connectivityDesc}。共管理 ${totalCount} 个项目，总价值 ${totalValue.toLocaleString()} 元，平均价值 ${avgValue.toLocaleString()} 元。最近24小时内有 ${recentCount} 个项目发生更新。`;
  }

  /**
   * 计算警告数量
   */
  private calculateAlertCount(items: Item[], totalCount: number): number {
    let alertCount = 0;

    // 🎯 v7.2 更新：连通性问题不算警告（已反映在状态中）
    // 只计算业务相关的警告

    // 无数据警告
    if (totalCount === 0) {
      alertCount += 1;
    }

    // 低价值项目警告
    const lowValueItems = items.filter(item => (item.value || 0) < 10);
    if (lowValueItems.length > totalCount * 0.3) { // 超过30%的项目价值过低
      alertCount += 1;
    }

    // 长期未更新警告
    const staleItems = items.filter(item => {
      const updatedAt = new Date(item.updatedAt);
      const now = new Date();
      const diffDays = (now.getTime() - updatedAt.getTime()) / (1000 * 60 * 60 * 24);
      return diffDays > 30; // 30天未更新
    });
    
    if (staleItems.length > 0) {
      alertCount += 1;
    }

    return alertCount;
  }

  /**
   * 构建自定义操作按钮
   */
  private buildCustomActions(): SliceAction[] {
    return [
      {
        label: '创建项目',
        action: () => {
          // 通过事件总线通知导航到创建页面
          window.dispatchEvent(new CustomEvent('navigate-to-slice', { 
            detail: { slice: 'mvp_crud', action: 'create' } 
          }));
        },
        icon: '➕',
        variant: 'primary'
      },
      {
        label: '查看列表',
        action: () => {
          // 通过事件总线通知导航到列表页面
          window.dispatchEvent(new CustomEvent('navigate-to-slice', { 
            detail: { slice: 'mvp_crud', action: 'list' } 
          }));
        },
        icon: '📋',
        variant: 'secondary'
      },
      {
        label: '连通性检测',
        action: () => {
          // 手动触发连通性检测
          this.lastConnectivityCheck = null; // 清除缓存
          this.refreshData();
          window.dispatchEvent(new CustomEvent('show-notification', { 
            detail: { 
              message: '连通性检测已刷新', 
              type: 'info' 
            } 
          }));
        },
        icon: '🔍',
        variant: 'secondary'
      },
      {
        label: '刷新数据',
        action: () => {
          // 刷新摘要数据
          this.refreshData();
          // 通知用户数据已刷新
          window.dispatchEvent(new CustomEvent('show-notification', { 
            detail: { 
              message: '数据已刷新', 
              type: 'success' 
            } 
          }));
        },
        icon: '🔄',
        variant: 'secondary'
      }
    ];
  }

  /**
   * 🎯 v7.2 新增：获取连通性错误状态的摘要
   */
  private getConnectivityErrorSummary(error?: string): SliceSummaryContract {
    return {
      title: 'MVP CRUD 项目管理',
      status: 'error', // 🔴 连通性失败
      metrics: [
        {
          label: '后端连通性',
          value: '离线',
          trend: 'warning',
          icon: '🔴'
        },
        {
          label: '错误原因',
          value: error && error.length > 20 ? error.substring(0, 20) + '...' : (error || '未知错误'),
          icon: '⚠️'
        },
        {
          label: '最后检查',
          value: this.lastConnectivityCheck ? this.lastConnectivityCheck.toLocaleTimeString() : '未检查',
          icon: '🕒'
        }
      ],
      description: `后端服务连接失败: ${error || '未知错误'}。请检查网络连接和后端服务状态。`,
      lastUpdated: new Date(),
      alertCount: 1,
      customActions: [
        {
          label: '重试连接',
          action: () => {
            this.lastConnectivityCheck = null; // 清除缓存
            this.refreshData();
          },
          icon: '🔄',
          variant: 'primary'
        },
        {
          label: '检查服务',
          action: () => {
            window.dispatchEvent(new CustomEvent('check-backend-status', { 
              detail: { service: 'mvp_crud' } 
            }));
          },
          icon: '🔧',
          variant: 'secondary'
        }
      ]
    };
  }

  /**
   * 获取错误状态的摘要
   */
  private getErrorSummary(error: any): SliceSummaryContract {
    const errorMessage = error instanceof Error ? error.message : String(error);
    
    return {
      title: 'MVP CRUD 项目管理',
      status: 'error',
      metrics: [
        {
          label: '连接状态',
          value: '连接失败',
          trend: 'warning',
          icon: '❌'
        },
        {
          label: '错误信息',
          value: errorMessage.length > 20 ? errorMessage.substring(0, 20) + '...' : errorMessage,
          icon: '⚠️'
        },
        {
          label: '最后尝试',
          value: '刚刚',
          icon: '🔄'
        }
      ],
      description: `无法连接到项目管理服务：${errorMessage}。请检查网络连接和后端服务状态。`,
      lastUpdated: new Date(),
      alertCount: 1,
      customActions: [
        {
          label: '重试连接',
          action: () => {
            this.refreshData();
          },
          icon: '🔄',
          variant: 'primary'
        },
        {
          label: '检查服务',
          action: () => {
            window.dispatchEvent(new CustomEvent('check-backend-status', { 
              detail: { service: 'mvp_crud' } 
            }));
          },
          icon: '🔧',
          variant: 'secondary'
        }
      ]
    };
  }
}

// 导出单例实例
export const mvpCrudSummaryProvider = new MvpCrudSummaryProvider();

// 向后兼容的导出
export const CrudSummaryProvider = MvpCrudSummaryProvider;
export const useCrudSummary = () => {
  return {
    getSummaryData: () => mvpCrudSummaryProvider.getSummaryData(),
    refreshData: () => mvpCrudSummaryProvider.refreshData(),
    provider: mvpCrudSummaryProvider
  };
}; 