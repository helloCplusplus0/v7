/**
 * 🎯 共享类型定义
 * 定义跨切片使用的通用类型
 */

/**
 * 切片状态枚举
 */
export type SliceStatus = 'idle' | 'active' | 'ready' | 'error' | 'disabled';

/**
 * 切片基础指标接口
 */
export interface SliceMetrics {
  totalRequests: number;
  successfulRequests: number;
  failedRequests: number;
  averageResponseTime: number;
}

/**
 * 切片摘要基础接口
 */
export interface SliceSummary {
  name: string;
  version: string;
  description: string;
  status: SliceStatus;
  lastActivity: Date | null;
  isHealthy: boolean;
  metrics: SliceMetrics;
  dependencies: string[];
  configuration: Record<string, any>;
} 