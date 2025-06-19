// 📊 MVP CRUD 切片摘要提供者
// 实现 SliceSummaryProvider 接口，为瀑布流展示提供摘要信息

import type { 
  SliceSummaryProvider, 
  SliceSummaryContract, 
  SliceMetric,
  SliceAction 
} from '../../src/shared/types';
import { crudApi } from './api';

export class MvpCrudSummaryProvider implements SliceSummaryProvider {
  async getSummaryData(): Promise<SliceSummaryContract> {
    try {
      // 获取实时数据统计
      const response = await crudApi.listItems({ limit: 1, offset: 0 }); // 只获取总数信息
      
      // BaseApiClient 现在自动解包响应，直接使用 response
      const totalItems = response.total || 0; // 使用 total 字段
      const itemsCount = response.items?.length || 0; // 当前页的项目数量
      
      // 计算状态
      const status = totalItems > 0 ? 'healthy' : 'warning';
      
      // 构建指标
      const metrics: SliceMetric[] = [
        {
          label: '总项目数',
          value: totalItems,
          trend: totalItems > 5 ? 'up' : totalItems > 0 ? 'stable' : 'down',
          icon: '📦',
          unit: '个'
        },
        {
          label: '状态',
          value: totalItems > 0 ? '活跃' : '空闲',
          icon: totalItems > 0 ? '✅' : '💤'
        },
        {
          label: '最近更新',
          value: '刚刚',
          icon: '🔄'
        }
      ];

      // 自定义操作
      const customActions: SliceAction[] = [
        {
          label: '创建项目',
          action: () => {
            // 通过事件总线通知切换到创建模式
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
            window.dispatchEvent(new CustomEvent('navigate-to-slice', { 
              detail: { slice: 'mvp_crud', action: 'list' } 
            }));
          },
          icon: '📋',
          variant: 'secondary'
        }
      ];

      return {
        title: 'MVP CRUD 管理',
        status,
        metrics,
        description: `项目管理系统，当前共有 ${totalItems} 个项目。支持创建、查看、编辑和删除操作。`,
        lastUpdated: new Date(),
        alertCount: totalItems === 0 ? 1 : 0, // 无项目时显示提醒
        customActions
      };
    } catch (error) {
      console.error('Failed to load CRUD summary data:', error);
      
      // 错误状态的默认摘要
      return {
        title: 'MVP CRUD 管理',
        status: 'error',
        metrics: [
          {
            label: '状态',
            value: '连接失败',
            trend: 'warning',
            icon: '❌'
          },
          {
            label: '操作',
            value: '请检查网络',
            icon: '🔧'
          }
        ],
        description: '无法连接到后端服务，请检查网络连接和后端服务状态。',
        lastUpdated: new Date(),
        alertCount: 1,
        customActions: [
          {
            label: '重试连接',
            action: () => {
              this.refreshData?.();
            },
            icon: '🔄',
            variant: 'primary'
          }
        ]
      };
    }
  }

  async refreshData(): Promise<void> {
    // 刷新数据的实现
    // 这里可以清除缓存，重新获取数据
    console.log('Refreshing MVP CRUD summary data...');
  }
}

// 导出单例实例
export const mvpCrudSummaryProvider = new MvpCrudSummaryProvider(); 