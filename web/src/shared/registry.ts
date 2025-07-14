/**
 * 🎯 v7 Web架构 - 切片注册表
 * 统一管理所有功能切片的注册和访问
 */

import type { SliceRegistry, SliceRegistration, SliceSummaryProvider, SliceSummaryContract } from './types';

// 导入摘要提供者
import { mvpCrudSummaryProvider } from '../../slices/mvp_crud/summaryProvider';
import { getMvpStatSummaryProvider } from '../../slices/mvp_stat/summaryProvider';

// 创建 mvp_stat 的适配器
const createMvpStatAdapter = (): SliceSummaryProvider => {
  const summaryMemo = getMvpStatSummaryProvider();
  
  return {
    async getSummaryData(): Promise<SliceSummaryContract> {
      const summary = await summaryMemo();
      
      // 状态映射：将mvp_stat的状态映射到registry的状态
      const mapStatus = (status: string): SliceSummaryContract['status'] => {
        switch (status) {
          case 'active': return 'loading';
          case 'ready': return 'healthy';
          case 'error': return 'error';
          case 'idle':
          default: return 'healthy';
        }
      };
      
      return {
        title: summary.name === 'mvp_stat' ? 'MVP 统计分析' : summary.name,
        status: mapStatus(summary.status),
        metrics: [
          {
            label: '数据生成',
            value: summary.metrics.totalDataGenerated.toString(),
            icon: '📊',
            trend: 'stable'
          },
          {
            label: '统计计算',
            value: summary.metrics.totalCalculations.toString(),
            icon: '🧮',
            trend: 'stable'
          },
          {
            label: '后端连通性',
            value: summary.metrics.backendConnectivity.value,
            icon: summary.metrics.backendConnectivity.icon,
            trend: summary.metrics.backendConnectivity.trend
          }
        ],
        description: summary.description,
        lastUpdated: summary.lastActivity || new Date()
      };
    },
    
    async refreshData(): Promise<void> {
      // 刷新数据 - 重新调用memo函数
      await summaryMemo();
    }
  };
};

// 统一的切片注册表
export const sliceRegistry: SliceRegistry = {
  mvp_crud: {
    name: 'mvp_crud',
    displayName: 'MVP CRUD',
    path: '/mvp_crud',
    description: 'MVP CRUD功能演示',
    version: '1.0.0',
    componentLoader: () => import('../../slices/mvp_crud'),
    summaryProvider: mvpCrudSummaryProvider
  },
  mvp_stat: {
    name: 'mvp_stat',
    displayName: 'MVP 统计分析',
    path: '/mvp_stat',
    description: '随机数据生成、统计量计算、综合分析功能演示',
    version: '1.0.0',
    componentLoader: () => import('../../slices/mvp_stat'),
    summaryProvider: createMvpStatAdapter()
  }
};

// 辅助函数
export const getSliceNames = (): string[] => Object.keys(sliceRegistry);

export const getSliceRegistration = (name: string): SliceRegistration => {
  const slice = sliceRegistry[name];
  if (!slice) {
    throw new Error(`切片 "${name}" 未找到`);
  }
  return slice;
};

export const getSliceComponent = (name: string) => {
  return getSliceRegistration(name).componentLoader;
};

export const getSliceMetadata = (name: string) => {
  const slice = getSliceRegistration(name);
  return {
    name: slice.name,
    displayName: slice.displayName,
    path: slice.path,
    description: slice.description,
    version: slice.version
  };
};

export const getSliceSummaryProvider = (name: string) => {
  return getSliceRegistration(name).summaryProvider;
};

export const hasSlice = (name: string): boolean => name in sliceRegistry;

export const getAllSliceRegistrations = (): SliceRegistration[] => 
  Object.values(sliceRegistry);