/**
 * 🎯 MVP统计分析 - TypeScript类型定义
 * 
 * 本文件定义了MVP统计分析功能的所有TypeScript类型，包括：
 * - API请求/响应类型
 * - 本地状态类型  
 * - 组件Props类型
 * - 业务逻辑类型
 */

// 导入backend生成的proto类型
import type {
  GenerateRandomDataRequest,
  GenerateRandomDataResponse,
  CalculateStatisticsRequest,
  CalculateStatisticsResponse,
  ComprehensiveAnalysisRequest,
  ComprehensiveAnalysisResponse,
  StatisticsResult,
  BasicStatistics,
  DistributionStatistics,
  PercentileInfo,
  ShapeStatistics,
  PerformanceInfo,
  DataSummary,
  DataRange
} from '../../shared/api/generated/backend_pb';

// ================================
// 1. 业务请求类型（简化版）
// ================================

/**
 * 数据生成请求
 */
export interface GenerateDataRequest {
  count?: number;
  seed?: number;
  minValue?: number;
  maxValue?: number;
  distribution?: 'uniform' | 'normal' | 'exponential';
}

/**
 * 统计计算请求
 */
export interface CalculateStatsRequest {
  data: number[];
  statistics?: string[];
  percentiles?: number[];
  useAnalyticsEngine?: boolean;
  preferRust?: boolean;
}

/**
 * 综合分析请求
 */
export interface ComprehensiveRequest {
  dataConfig: GenerateDataRequest;
  statsConfig: Omit<CalculateStatsRequest, 'data'>;
}

// ================================
// 2. 业务响应类型
// ================================

/**
 * 数据生成结果
 */
export interface GeneratedDataResult {
  data: number[];
  count: number;
  seed: number;
  performance: PerformanceInfo;
  summary: {
    distribution: string;
    range: string;
    generationTime: string;
    min: number;
    max: number;
    preview: number[];
  };
}

/**
 * 统计计算结果
 */
export interface StatisticsCalculationResult {
  results: StatisticsResult;
  performance: PerformanceInfo;
  implementation: string;
  computedAt: string;
}

/**
 * 综合分析结果
 */
export interface ComprehensiveAnalysisResult {
  dataSummary: DataSummary;
  statistics: StatisticsResult;
  performance: PerformanceInfo;
  analyzedAt: string;
  insights: {
    dataQuality: 'excellent' | 'good' | 'fair' | 'poor';
    distributionType: string;
    outlierCount: number;
    recommendations: string[];
  };
}

// ================================
// 3. 本地状态类型
// ================================

/**
 * MVP STAT 切片状态
 */
export interface MvpStatState {
  // 操作状态
  isGenerating: boolean;
  isCalculating: boolean;
  isAnalyzing: boolean;
  
  // 数据状态
  generatedData: number[] | null;
  statisticsResult: StatisticsCalculationResult | null;
  comprehensiveResult: ComprehensiveAnalysisResult | null;
  
  // 配置状态
  dataConfig: GenerateDataRequest;
  statsConfig: CalculateStatsRequest;
  
  // 错误状态
  error: string | null;
  
  // 历史记录
  history: OperationHistory[];
  
  // 用户偏好
  preferences: StatPreferences;
}

/**
 * 操作历史记录
 */
export interface OperationHistory {
  id: string;
  type: 'generate' | 'calculate' | 'comprehensive';
  timestamp: string;
  config: any;
  result: any;
  performance: PerformanceInfo;
}

/**
 * 统计偏好设置
 */
export interface StatPreferences {
  defaultDistribution: 'uniform' | 'normal' | 'exponential';
  defaultDataCount: number;
  preferredStatistics: string[];
  enableAnalyticsEngine: boolean;
  preferRust: boolean;
  showAdvancedOptions: boolean;
}

// ================================
// 4. 组件Props类型
// ================================

/**
 * MVP STAT 主视图Props
 */
export interface MvpStatViewProps {
  initialTab?: 'generate' | 'calculate' | 'comprehensive';
  onError?: (error: string) => void;
  onSuccess?: (result: any) => void;
}

/**
 * 数据生成器Props
 */
export interface DataGeneratorProps {
  config: GenerateDataRequest;
  onConfigChange: (config: GenerateDataRequest) => void;
  onGenerate: () => void;
  isGenerating: boolean;
  result: GeneratedDataResult | null;
  error: string | null;
}

/**
 * 统计计算器Props
 */
export interface StatisticsCalculatorProps {
  data: number[] | null;
  config: CalculateStatsRequest;
  onConfigChange: (config: CalculateStatsRequest) => void;
  onCalculate: () => void;
  isCalculating: boolean;
  result: StatisticsCalculationResult | null;
  error: string | null;
}

/**
 * 综合分析器Props
 */
export interface ComprehensiveAnalyzerProps {
  config: ComprehensiveRequest;
  onConfigChange: (config: ComprehensiveRequest) => void;
  onAnalyze: () => void;
  isAnalyzing: boolean;
  result: ComprehensiveAnalysisResult | null;
  error: string | null;
}

/**
 * 统计显示Props
 */
export interface StatisticsDisplayProps {
  result: StatisticsResult;
  compact?: boolean;
}

/**
 * 数据可视化Props
 */
export interface DataVisualizationProps {
  data: number[];
  statistics: StatisticsResult;
  title?: string;
  showHistogram?: boolean;
  showBoxPlot?: boolean;
  height?: number;
}

// ================================
// 5. 配置和常量
// ================================

/**
 * 可用统计量选项
 */
export const AVAILABLE_STATISTICS = [
  { key: 'mean', label: '均值', category: '基本统计' },
  { key: 'median', label: '中位数', category: '基本统计' },
  { key: 'mode', label: '众数', category: '基本统计' },
  { key: 'min', label: '最小值', category: '基本统计' },
  { key: 'max', label: '最大值', category: '基本统计' },
  { key: 'range', label: '极差', category: '基本统计' },
  { key: 'std', label: '标准差', category: '分布统计' },
  { key: 'variance', label: '方差', category: '分布统计' },
  { key: 'iqr', label: '四分位距', category: '分布统计' },
  { key: 'q1', label: 'Q1', category: '分位数' },
  { key: 'q3', label: 'Q3', category: '分位数' },
  { key: 'skewness', label: '偏度', category: '形状统计' },
  { key: 'kurtosis', label: '峰度', category: '形状统计' }
] as const;

/**
 * 分布选项
 */
export const DISTRIBUTION_OPTIONS = [
  { value: 'uniform', label: '均匀分布', description: '在指定范围内均匀分布' },
  { value: 'normal', label: '正态分布', description: '标准正态分布' },
  { value: 'exponential', label: '指数分布', description: '指数分布' }
] as const;

/**
 * 数据质量阈值
 */
export const DATA_QUALITY_THRESHOLDS = {
  excellent: { outlierRatio: 0.01, skewnessRange: [-0.5, 0.5], kurtosisRange: [-0.5, 0.5] },
  good: { outlierRatio: 0.05, skewnessRange: [-1, 1], kurtosisRange: [-1, 1] },
  fair: { outlierRatio: 0.1, skewnessRange: [-2, 2], kurtosisRange: [-2, 2] },
  poor: { outlierRatio: 1, skewnessRange: [-Infinity, Infinity], kurtosisRange: [-Infinity, Infinity] }
} as const;

/**
 * 默认数据配置
 */
export const DEFAULT_DATA_CONFIG: GenerateDataRequest = {
  count: 1000,
  seed: 42,
  minValue: 0,
  maxValue: 100,
  distribution: 'uniform'
};

/**
 * 默认统计配置
 */
export const DEFAULT_STATS_CONFIG: Omit<CalculateStatsRequest, 'data'> = {
  statistics: ['mean', 'median', 'std', 'min', 'max', 'range'],
  percentiles: [25, 50, 75],
  useAnalyticsEngine: true,
  preferRust: true
};

// ================================
// 6. 工具类型
// ================================

/**
 * 统计量键类型
 */
export type StatisticKey = typeof AVAILABLE_STATISTICS[number]['key'];

/**
 * 分布类型
 */
export type DistributionType = typeof DISTRIBUTION_OPTIONS[number]['value'];

/**
 * 数据质量等级
 */
export type DataQualityLevel = keyof typeof DATA_QUALITY_THRESHOLDS;

/**
 * 操作类型
 */
export type OperationType = 'generate' | 'calculate' | 'comprehensive';

/**
 * 导出格式
 */
export type ExportFormat = 'json' | 'csv' | 'excel';

/**
 * 标签页类型
 */
export type TabType = 'generate' | 'calculate' | 'comprehensive';

export interface ValidationResult {
  valid: boolean;
  errors: string[];
}

export interface QualityAssessment {
  score: number;
  level: 'excellent' | 'good' | 'fair' | 'poor';
  issues: string[];
  suggestions: string[];
}

// ================================
// 7. 事件类型（用于v7通信机制）
// ================================

export interface MvpStatEventMap {
  'mvp_stat:data_generated': { result: GeneratedDataResult };
  'mvp_stat:statistics_calculated': { result: StatisticsCalculationResult };
  'mvp_stat:analysis_completed': { result: ComprehensiveAnalysisResult };
  'mvp_stat:error': { error: string; operation: string };
  'mvp_stat:config_changed': { type: string; config: any };
  'mvp_stat:operation_start': { operation: string };
  'mvp_stat:operation_complete': { operation: string };
}

// ================================
// 8. Hook返回类型
// ================================

/**
 * useMvpStat Hook返回类型
 */
export interface UseMvpStatReturn {
  // 状态
  state: MvpStatState;
  
  // 数据生成
  generateData: (config: GenerateDataRequest) => Promise<void>;
  
  // 统计计算
  calculateStatistics: (config: CalculateStatsRequest) => Promise<void>;
  
  // 综合分析
  comprehensiveAnalysis: (config: ComprehensiveRequest) => Promise<void>;
  
  // 配置管理
  updateDataConfig: (config: Partial<GenerateDataRequest>) => void;
  updateStatsConfig: (config: Partial<CalculateStatsRequest>) => void;
  
  // 状态管理
  clearError: () => void;
  clearResults: () => void;
  resetState: () => void;
  
  // 历史管理
  getHistory: () => OperationHistory[];
  clearHistory: () => void;
  
  // 偏好管理
  updatePreferences: (preferences: Partial<StatPreferences>) => void;
}

// ================================
// 9. 契约接口（v7通信机制）
// ================================

/**
 * MVP STAT 切片契约
 */
export interface MvpStatSliceContract {
  // 基本信息
  name: string;
  version: string;
  description: string;
  
  // 核心功能
  generateRandomData: (config: GenerateDataRequest) => Promise<GeneratedDataResult>;
  calculateStatistics: (config: CalculateStatsRequest) => Promise<StatisticsCalculationResult>;
  comprehensiveAnalysis: (config: ComprehensiveRequest) => Promise<ComprehensiveAnalysisResult>;
  
  // 状态管理
  getState: () => MvpStatState;
  setState: (state: Partial<MvpStatState>) => void;
  
  // 验证
  validateConfig: (config: any) => ValidationResult;
  
  // 工具方法
  formatStatistics: (stats: StatisticsResult) => string;
  exportResults: (format: 'json' | 'csv' | 'excel') => string;
}

// ================================
// 10. 导出所有类型
// ================================

export type {
  // Proto类型重导出
  GenerateRandomDataRequest,
  GenerateRandomDataResponse,
  CalculateStatisticsRequest,
  CalculateStatisticsResponse,
  ComprehensiveAnalysisRequest,
  ComprehensiveAnalysisResponse,
  StatisticsResult,
  BasicStatistics,
  DistributionStatistics,
  PercentileInfo,
  ShapeStatistics,
  PerformanceInfo,
  DataSummary,
  DataRange
}; 