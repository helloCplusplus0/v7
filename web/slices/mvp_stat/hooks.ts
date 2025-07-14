// 🎯 MVP STAT - 业务逻辑和状态管理
// 遵循Web v7架构规范：Signal-first响应式设计 + 四种解耦通信机制

import { createSignal, createMemo, createEffect, onMount, onCleanup, batch } from 'solid-js';
import { createStore, produce } from 'solid-js/store';

// v7共享基础设施
import { useAsync } from '../../shared/hooks/useAsync';
import { useDebounce } from '../../shared/hooks/useDebounce';
import { useLocalStorage } from '../../shared/hooks/useLocalStorage';
import { eventBus } from '../../shared/events/EventBus';
import { createUserAccessor, createNotificationAccessor } from '../../shared/signals/accessors';

// 本地模块
import { mvpStatApi } from './api';
import type {
  GenerateDataRequest,
  CalculateStatsRequest,
  ComprehensiveRequest,
  GeneratedDataResult,
  StatisticsCalculationResult,
  ComprehensiveAnalysisResult,
  StatPreferences,
  OperationHistory,
  MvpStatSliceContract
} from './types';

import { PerformanceInfo } from '../../shared/api/generated/backend_pb';

import {
  DEFAULT_DATA_CONFIG,
  DEFAULT_STATS_CONFIG,
  AVAILABLE_STATISTICS
} from './types';

// 移除debug-helper导入，采用简化的数据处理逻辑

// ===== 全局信号状态（Signal-first设计） =====

// 数据状态信号
const [generatedData, setGeneratedData] = createSignal<number[] | null>(null);
const [generatedDataResult, setGeneratedDataResult] = createSignal<GeneratedDataResult | null>(null);
const [statisticsResult, setStatisticsResult] = createSignal<any>(null);
const [comprehensiveResult, setComprehensiveResult] = createSignal<ComprehensiveAnalysisResult | null>(null);

// 加载状态信号
const [isGenerating, setIsGenerating] = createSignal(false);
const [isCalculating, setIsCalculating] = createSignal(false);
const [isAnalyzing, setIsAnalyzing] = createSignal(false);

// 错误状态信号
const [error, setError] = createSignal<string | null>(null);

// 配置状态信号
const [dataConfig, setDataConfig] = createSignal<GenerateDataRequest>(DEFAULT_DATA_CONFIG);
const [statsConfig, setStatsConfig] = createSignal<CalculateStatsRequest>({ ...DEFAULT_STATS_CONFIG, data: [] });

// UI状态信号
const [activeTab, setActiveTab] = createSignal<'generate' | 'calculate' | 'comprehensive'>('generate');
const [showAdvancedOptions, setShowAdvancedOptions] = createSignal(false);
const [selectedMetrics, setSelectedMetrics] = createSignal<string[]>(DEFAULT_STATS_CONFIG.statistics || []);

// 历史记录状态
const [operationHistory, setOperationHistory] = createSignal<OperationHistory[]>([]);

// ===== 计算属性（细粒度响应式） =====

const hasGeneratedData = createMemo(() => generatedData() !== null && generatedData()!.length > 0);
const hasStatisticsResult = createMemo(() => statisticsResult() !== null);
const hasComprehensiveResult = createMemo(() => comprehensiveResult() !== null);
const isAnyLoading = createMemo(() => isGenerating() || isCalculating() || isAnalyzing());
const canCalculateStats = createMemo(() => hasGeneratedData() && !isCalculating());
const canAnalyze = createMemo(() => !isAnalyzing());

// 数据质量评估
const dataQuality = createMemo(() => {
  const data = generatedData();
  if (!data) return null;
  
  const size = data.length;
  if (size >= 1000) return 'excellent';
  if (size >= 500) return 'good';
  if (size >= 100) return 'fair';
  return 'poor';
});

// 统计摘要
const statisticsSummary = createMemo(() => {
  const result = statisticsResult();
  if (!result) return null;
  
  const basic = result.basic || {};
  const distribution = result.distribution || {};
  const shape = result.shape || {};
  
  return {
    mean: basic.mean || 0,
    median: distribution.median || 0,
    stdDev: distribution.stdDev || 0,
    skewness: shape.skewness || 0,
    kurtosis: shape.kurtosis || 0
  };
});

// ===== 核心MVP STAT操作Hook =====

/**
 * 主要的MVP STAT操作Hook
 * 使用v7四种通信机制：事件驱动、契约接口、信号响应式、Provider模式
 */
export function useMvpStat() {
  // v7通信机制：访问器模式（信号响应式）
  const userAccessor = createUserAccessor();
  const notificationAccessor = createNotificationAccessor();

  // 本地存储偏好设置
  const [preferences, setPreferences] = useLocalStorage<StatPreferences>('mvp-stat-preferences', {
    defaultDataCount: 1000,
    defaultDistribution: 'uniform',
    preferredStatistics: ['mean', 'median', 'std', 'min', 'max'],
    enableAnalyticsEngine: true,
    preferRust: true,
    showAdvancedOptions: false
  });

  // 生成随机数据
  const generateRandomData = async (config?: Partial<GenerateDataRequest>) => {
    console.log('🎲 [useMvpStat] 开始生成随机数据');
    setIsGenerating(true);
    setError(null);

    try {
      const finalConfig = { ...dataConfig(), ...config };
      const startTime = Date.now();
      
      const result = await mvpStatApi.generateRandomData(finalConfig);
      
      batch(() => {
        setGeneratedData(result.data);
        setGeneratedDataResult(result);
        setDataConfig(finalConfig);
        setIsGenerating(false);
      });

      // 记录操作历史
      addToHistory({
        type: 'generate',
        config: finalConfig,
        result,
        performance: new PerformanceInfo({
          executionTimeMs: BigInt(Date.now() - startTime),
          implementation: 'grpc-web',
          metrics: {}
        })
      });

      // v7通信机制：事件驱动（成功通知）
      eventBus.emit('notification:show', { 
        message: `成功生成 ${result.count} 个随机数`, 
        type: 'success',
        timestamp: Date.now()
      });

      console.log('✅ [useMvpStat] 随机数据生成成功:', result);
      return result;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      setError(errorMessage);
      setIsGenerating(false);
      
      // 记录失败历史
      addToHistory({
        type: 'generate',
        config: config || dataConfig(),
        result: null,
        performance: new PerformanceInfo({
          executionTimeMs: BigInt(0),
          implementation: 'grpc-web',
          metrics: {}
        })
      });

      // v7通信机制：事件驱动（错误通知）
      eventBus.emit('notification:show', { 
        message: `生成失败: ${errorMessage}`, 
        type: 'error',
        timestamp: Date.now()
      });

      throw err;
    }
  };

  // 计算统计量
  const calculateStatistics = async (config?: Partial<CalculateStatsRequest>) => {
    console.log('📊 [useMvpStat] 开始计算统计量');
    
    const rawData = generatedData();
    if (!rawData || rawData.length === 0) {
      throw new Error('没有可用的数据进行统计计算');
    }

    // 🔧 数据格式修复和验证
    console.log('🔍 [useMvpStat] 原始数据分析:', {
      type: typeof rawData,
      isArray: Array.isArray(rawData),
      length: rawData.length,
      sample: rawData.slice(0, 5)
    });

    // 简化的数据格式处理和验证
    const fixedData = rawData.filter(value => 
      typeof value === 'number' && !isNaN(value) && isFinite(value)
    );
    
    console.log('✅ [useMvpStat] 数据处理完成:', {
      原始长度: rawData.length,
      有效数据: fixedData.length,
      样本: fixedData.slice(0, 5)
    });

    // 基础数据验证
    if (fixedData.length === 0) {
      throw new Error('数据为空或无有效数值');
    }
    if (fixedData.length < 2) {
      throw new Error('数据量至少需要2个有效数值');
    }

    setIsCalculating(true);
    setError(null);

    try {
      const finalConfig = { 
        ...statsConfig(), 
        ...config, 
        data: config?.data || fixedData  // 使用修复后的数据
      };
      const startTime = Date.now();
      
      const result = await mvpStatApi.calculateStatistics(finalConfig);
      
      batch(() => {
        setStatisticsResult(result);
        setStatsConfig(finalConfig);
        setIsCalculating(false);
      });

      // 记录操作历史
      addToHistory({
        type: 'calculate',
        config: finalConfig,
        result,
        performance: new PerformanceInfo({
          executionTimeMs: BigInt(Date.now() - startTime),
          implementation: 'grpc-web',
          metrics: {}
        })
      });

      // v7通信机制：事件驱动（成功通知）
      eventBus.emit('notification:show', { 
        message: `统计计算完成，实现：${result.implementation}`, 
        type: 'success',
        timestamp: Date.now()
      });

      console.log('✅ [useMvpStat] 统计量计算成功:', result);
      return result;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      setError(errorMessage);
      setIsCalculating(false);
      
      // v7通信机制：事件驱动（错误通知）
      eventBus.emit('notification:show', { 
        message: `计算失败: ${errorMessage}`, 
        type: 'error',
        timestamp: Date.now()
      });

      throw err;
    }
  };

  // 综合分析
  const comprehensiveAnalysis = async (config?: Partial<ComprehensiveRequest>) => {
    console.log('🔬 [useMvpStat] 开始综合分析');
    setIsAnalyzing(true);
    setError(null);

    try {
      const finalConfig: ComprehensiveRequest = {
        dataConfig: { ...dataConfig(), ...config?.dataConfig },
        statsConfig: { ...statsConfig(), ...config?.statsConfig }
      };
      const startTime = Date.now();
      
      const result = await mvpStatApi.comprehensiveAnalysis(finalConfig);
      
      batch(() => {
        // 更新所有相关状态
        if (result.dataSummary?.preview) {
          setGeneratedData(result.dataSummary.preview);
        }
        setStatisticsResult(result.statistics);
        setComprehensiveResult(result);
        setIsAnalyzing(false);
      });

      // 记录操作历史
      addToHistory({
        type: 'comprehensive',
        config: finalConfig,
        result,
        performance: new PerformanceInfo({
          executionTimeMs: BigInt(Date.now() - startTime),
          implementation: 'grpc-web',
          metrics: {}
        })
      });

      // v7通信机制：事件驱动（成功通知）
      eventBus.emit('mvp_stat:analysis_completed', { result, insights: result.insights });
      notificationAccessor.show(`综合分析完成，数据质量: ${result.insights.dataQuality}`, 'success');

      console.log('✅ [useMvpStat] 综合分析成功:', result);
      return result;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      setError(errorMessage);
      setIsAnalyzing(false);
      
      // v7通信机制：事件驱动（错误通知）
      eventBus.emit('mvp_stat:error', { error: errorMessage, operation: 'comprehensive' });
      notificationAccessor.show(`分析失败: ${errorMessage}`, 'error');

      throw err;
    }
  };

  // 添加到历史记录
  const addToHistory = (operation: Omit<OperationHistory, 'id' | 'timestamp'>) => {
    const historyItem: OperationHistory = {
      id: `${operation.type}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      timestamp: new Date().toISOString(),
      ...operation
    };
    
    setOperationHistory(prev => [historyItem, ...prev].slice(0, 50)); // 保留最近50条记录
  };

  // 清除数据
  const clearData = () => {
    batch(() => {
      setGeneratedData(null);
      setGeneratedDataResult(null);
      setStatisticsResult(null);
      setComprehensiveResult(null);
      setError(null);
    });
    
    notificationAccessor.show('数据已清除', 'info');
  };

  // 重置配置
  const resetConfig = () => {
    batch(() => {
      setDataConfig(DEFAULT_DATA_CONFIG);
      setStatsConfig({ ...DEFAULT_STATS_CONFIG, data: [] });
      setSelectedMetrics(DEFAULT_STATS_CONFIG.statistics || []);
    });
    
    notificationAccessor.show('配置已重置', 'info');
  };

  // 导出数据
  const exportData = (format: 'json' | 'csv' = 'json') => {
    const data = generatedData();
    const stats = statisticsResult();
    
    if (!data && !stats) {
      throw new Error('没有可导出的数据');
    }
    
    const exportData = {
      generatedData: data,
      statisticsResult: stats,
      comprehensiveResult: comprehensiveResult(),
      exportedAt: new Date().toISOString(),
      config: {
        dataConfig: dataConfig(),
        statsConfig: statsConfig()
      }
    };
    
    if (format === 'json') {
      const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `mvp_stat_export_${Date.now()}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } else if (format === 'csv' && data) {
      const csvContent = data.map((value, index) => `${index},${value}`).join('\n');
      const csvHeader = 'Index,Value\n';
      const blob = new Blob([csvHeader + csvContent], { type: 'text/csv' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `mvp_stat_data_${Date.now()}.csv`;
      a.click();
      URL.revokeObjectURL(url);
    }
    
    notificationAccessor.show(`数据已导出为 ${format.toUpperCase()} 格式`, 'success');
  };

  // 事件监听
  onMount(() => {
    // 监听认证状态变化
    const unsubscribeAuth = eventBus.on('auth:logout', () => {
      console.log('🔒 [useMvpStat] 用户登出，清除数据');
      clearData();
    });
    
    onCleanup(unsubscribeAuth);
  });

  return {
    // 状态信号
    generatedData,
    generatedDataResult,
    statisticsResult,
    comprehensiveResult,
    isGenerating: createMemo(() => isGenerating()),
    isCalculating: createMemo(() => isCalculating()),
    isAnalyzing: createMemo(() => isAnalyzing()),
    error,
    dataConfig,
    statsConfig,
    activeTab,
    showAdvancedOptions,
    selectedMetrics,
    operationHistory,
    
    // 计算属性
    hasGeneratedData,
    hasStatisticsResult,
    hasComprehensiveResult,
    isAnyLoading,
    canCalculateStats,
    canAnalyze,
    dataQuality,
    statisticsSummary,
    
    // 操作方法
    generateRandomData,
    calculateStatistics,
    comprehensiveAnalysis,
    clearData,
    resetConfig,
    exportData,
    
    // 配置方法
    setDataConfig,
    setStatsConfig,
    setActiveTab,
    setShowAdvancedOptions,
    setSelectedMetrics,
    
    // 偏好设置
    preferences: () => preferences,
    setPreferences,
    
    // 工具方法
    clearError: () => setError(null),
    getAvailableStatistics: () => AVAILABLE_STATISTICS
  };
}

// ===== 专用Hooks =====

/**
 * 数据生成专用Hook
 */
export function useDataGenerator() {
  const mvpStat = useMvpStat();
  
  // 防抖生成配置
  const debouncedConfig = useDebounce(mvpStat.dataConfig, 500);
  
  // 自动生成效果
  createEffect(() => {
    const config = debouncedConfig();
    const prefs = mvpStat.preferences()();
    if (config) {
      // 自动刷新逻辑可以在这里实现
    }
  });
  
  return {
    config: mvpStat.dataConfig,
    setConfig: mvpStat.setDataConfig,
    generate: mvpStat.generateRandomData,
    loading: mvpStat.isGenerating,
    result: generatedDataResult,
    error: mvpStat.error,
    quality: mvpStat.dataQuality
  };
}

/**
 * 统计计算专用Hook
 */
export function useStatisticsCalculator() {
  const mvpStat = useMvpStat();
  
  return {
    data: mvpStat.generatedData,
    config: mvpStat.statsConfig,
    setConfig: mvpStat.setStatsConfig,
    calculate: mvpStat.calculateStatistics,
    loading: mvpStat.isCalculating,
    result: mvpStat.statisticsResult,
    summary: mvpStat.statisticsSummary,
    error: mvpStat.error,
    canCalculate: mvpStat.canCalculateStats,
    selectedMetrics: mvpStat.selectedMetrics,
    setSelectedMetrics: mvpStat.setSelectedMetrics,
    availableStatistics: mvpStat.getAvailableStatistics
  };
}

/**
 * 综合分析专用Hook
 */
export function useComprehensiveAnalyzer() {
  const mvpStat = useMvpStat();
  
  return {
    dataConfig: mvpStat.dataConfig,
    statsConfig: mvpStat.statsConfig,
    setDataConfig: mvpStat.setDataConfig,
    setStatsConfig: mvpStat.setStatsConfig,
    analyze: mvpStat.comprehensiveAnalysis,
    loading: mvpStat.isAnalyzing,
    result: mvpStat.comprehensiveResult,
    error: mvpStat.error,
    canAnalyze: mvpStat.canAnalyze
  };
}

// ===== 契约接口实现 =====

/**
 * MVP STAT 契约接口实现
 * 为其他切片提供标准化的统计分析服务
 */
export function createMvpStatContract(): MvpStatSliceContract {
  const mvpStat = useMvpStat();
  
  return {
    name: 'mvp_stat',
    version: '1.0.0',
    description: 'MVP统计分析切片',
    
    async generateRandomData(config: GenerateDataRequest) {
      await mvpStat.generateRandomData(config);
      return mvpStat.generatedDataResult()!;
    },
    
    async calculateStatistics(config: CalculateStatsRequest) {
      await mvpStat.calculateStatistics(config);
      return mvpStat.statisticsResult()!;
    },
    
    async comprehensiveAnalysis(config: ComprehensiveRequest) {
      await mvpStat.comprehensiveAnalysis(config);
      return mvpStat.comprehensiveResult()!;
    },
    
    getState() {
      return {
        isGenerating: mvpStat.isGenerating(),
        isCalculating: mvpStat.isCalculating(),
        isAnalyzing: mvpStat.isAnalyzing(),
        generatedData: mvpStat.generatedData(),
        statisticsResult: mvpStat.statisticsResult(),
        comprehensiveResult: mvpStat.comprehensiveResult(),
        dataConfig: mvpStat.dataConfig(),
        statsConfig: mvpStat.statsConfig(),
        error: mvpStat.error(),
        history: [],
        preferences: mvpStat.preferences()()
      };
    },
    
    setState(state: any) {
      // 实现状态设置逻辑
    },
    
    validateConfig(config: any) {
      return { valid: true, errors: [] };
    },
    
    formatStatistics(stats: any) {
      return JSON.stringify(stats, null, 2);
    },
    
    exportResults(format: 'json' | 'csv' | 'excel') {
      mvpStat.exportData(format as 'json' | 'csv');
      return '';
    }
  };
} 