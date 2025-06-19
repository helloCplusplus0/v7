/**
 * 统一类型定义
 * 合并所有应用类型，提供单一导入入口
 */

// 切片状态枚举
export type SliceStatus = 'healthy' | 'warning' | 'error' | 'loading';

// 趋势类型
export type TrendType = 'up' | 'down' | 'stable' | 'warning';

// 切片指标接口
export interface SliceMetric {
  label: string;
  value: string | number;
  trend?: TrendType;
  icon?: string;
  unit?: string;
}

// 切片操作接口
export interface SliceAction {
  label: string;
  action: () => void;
  icon?: string;
  variant?: 'primary' | 'secondary' | 'danger';
}

// 切片摘要契约接口
export interface SliceSummaryContract {
  title: string;
  status: SliceStatus;
  metrics: SliceMetric[];
  description?: string;
  lastUpdated?: Date;
  alertCount?: number;
  customActions?: SliceAction[];
}

// 切片摘要提供者接口
export interface SliceSummaryProvider {
  getSummaryData(): Promise<SliceSummaryContract>;
  refreshData?(): Promise<void>;
}

// 扩展的切片注册接口
export interface SliceRegistration {
  name: string;
  displayName: string;
  path: string;
  description?: string;
  version?: string;
  componentLoader: () => Promise<{ default: any }>;
  summaryProvider?: SliceSummaryProvider;
}

// 切片注册表类型
export interface SliceRegistry {
  [key: string]: SliceRegistration;
}

// 路由定义接口
export interface RouteDefinition {
  path: string;
  component: any;
  name: string;
  displayName: string;
  description?: string;
}

// 应用配置类型 - 从统一配置系统导入
export type { AppConfig } from '../../config/types';

// 全局声明
declare global {
  interface ImportMetaEnv {
    readonly VITE_API_BASE_URL: string;
    readonly VITE_APP_TITLE: string;
  }

  interface ImportMeta {
    readonly env: ImportMetaEnv;
  }
} 