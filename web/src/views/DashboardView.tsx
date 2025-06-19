/**
 * Telegram风格Dashboard视图
 * 
 * 设计原则：
 * 1. 突出切片摘要信息和运行状态
 * 2. 整个切片区域为热点激活区
 * 3. 移除多余引导文字
 * 4. 采用黄金比例设计
 * 5. 简洁直接的信息展示
 */

import { For, createResource } from "solid-js";
import { A } from "@solidjs/router";
import { 
  getSliceNames, 
  getSliceMetadata, 
  getSliceSummaryProvider
} from "../shared/registry";
import type { SliceSummaryContract } from "../shared/types";

// 获取切片摘要数据
const getSliceSummaryData = async (sliceName: string): Promise<SliceSummaryContract> => {
  const provider = getSliceSummaryProvider(sliceName);
  
  if (provider) {
    try {
      return await provider.getSummaryData();
    } catch (error) {
      console.error(`获取切片 ${sliceName} 摘要数据失败:`, error);
    }
  }
  
  // 默认摘要数据
  return {
    title: getSliceMetadata(sliceName).displayName || sliceName,
    status: 'loading',
    metrics: [
      {
        label: '状态',
        value: '静态显示',
        trend: 'stable',
        icon: '📋'
      }
    ],
    description: '静态切片，无实时功能'
  };
};

export default function DashboardView() {
  const [slicesData] = createResource(async () => {
    const sliceNames = getSliceNames();
    const slicesWithSummary = await Promise.all(
      sliceNames.map(async (sliceName) => ({
        ...getSliceMetadata(sliceName),
        summaryData: await getSliceSummaryData(sliceName)
      }))
    );
    return slicesWithSummary;
  });

  const getStatusIndicator = (status: string) => {
    switch (status) {
      case 'healthy': return { icon: '🟢', text: '运行中' };
      case 'warning': return { icon: '🟡', text: '警告' };
      case 'error': return { icon: '🔴', text: '异常' };
      default: return { icon: '⚪', text: '静态' };
    }
  };

  const getTrendIcon = (trend: string) => {
    switch (trend) {
      case 'up': return '📈';
      case 'down': return '📉';
      case 'warning': return '⚠️';
      default: return '➖';
    }
  };

  return (
    <div class="dashboard-telegram">
      <div class="slices-container">
        <For each={slicesData() || []}>
          {(slice) => {
            const status = getStatusIndicator(slice.summaryData.status);
            return (
              <A href={`/slice/${slice.name}`} class="slice-card-telegram">
                {/* 切片头部：名称 + 状态 */}
                <div class="slice-header-telegram">
                  <h3 class="slice-title-telegram">{slice.summaryData.title}</h3>
                  <div class="slice-status-telegram">
                    <span class="status-icon">{status.icon}</span>
                    <span class="status-text">{status.text}</span>
                  </div>
                </div>

                {/* 切片描述 */}
                {slice.summaryData.description && (
                  <p class="slice-description-telegram">
                    {slice.summaryData.description}
                  </p>
                )}

                {/* 核心指标 */}
                <div class="slice-metrics-telegram">
                  <For each={slice.summaryData.metrics.slice(0, 3)}>
                    {(metric) => (
                      <div class="metric-item-telegram">
                        <div class="metric-info">
                          <span class="metric-icon">{metric.icon}</span>
                          <span class="metric-label">{metric.label}</span>
                        </div>
                        <div class="metric-value-container">
                          <span class="metric-value">{metric.value}</span>
                          <span class="metric-trend">{getTrendIcon(metric.trend || 'stable')}</span>
                        </div>
                      </div>
                    )}
                  </For>
                </div>

                {/* 最后更新时间 */}
                {slice.summaryData.lastUpdated && (
                  <div class="slice-footer-telegram">
                    <span class="update-time">
                      {new Date(slice.summaryData.lastUpdated).toLocaleTimeString()}
                    </span>
                  </div>
                )}
              </A>
            );
          }}
        </For>
      </div>
    </div>
  );
} 