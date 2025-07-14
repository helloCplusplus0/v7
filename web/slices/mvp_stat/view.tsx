// 🎨 MVP STAT - UI组件实现
// 遵循Web v7架构规范：SolidJS细粒度响应式 + 现代化UI设计

import { createSignal, createMemo, For, Show, onMount, Switch, Match } from 'solid-js';
import { useMvpStat, useDataGenerator, useStatisticsCalculator, useComprehensiveAnalyzer } from './hooks';
import { eventBus } from '../../shared/events/EventBus';
import type { 
  MvpStatViewProps, 
  DataGeneratorProps, 
  StatisticsCalculatorProps,
  ComprehensiveAnalyzerProps,
  StatisticsDisplayProps,
  DataVisualizationProps
} from './types';
import { DISTRIBUTION_OPTIONS, AVAILABLE_STATISTICS } from './types';
import './styles.css'; // 引入切片独立样式

// ===== 子组件定义 =====

/**
 * 数据生成器组件 - 细粒度响应式
 */
const DataGenerator = (props: DataGeneratorProps) => {
  const [showAdvanced, setShowAdvanced] = createSignal(false);

  return (
    <div class="data-generator">
      <div class="config-section">
        <h4>数据生成配置</h4>
        
        <div class="config-grid">
          <div class="config-item">
            <label>数据量:</label>
            <input
              type="number"
              value={props.config.count || 1000}
              min="10"
              max="100000"
              onInput={(e) => props.onConfigChange({
                ...props.config,
                count: parseInt(e.currentTarget.value) || 1000
              })}
            />
          </div>

          <div class="config-item">
            <label>分布类型:</label>
            <select
              value={props.config.distribution || 'uniform'}
              onChange={(e) => props.onConfigChange({
                ...props.config,
                distribution: e.currentTarget.value as 'uniform' | 'normal' | 'exponential'
              })}
            >
              <For each={DISTRIBUTION_OPTIONS}>
                {(option) => (
                  <option value={option.value}>{option.label}</option>
                )}
              </For>
            </select>
          </div>

          <div class="config-item">
            <label>随机种子:</label>
            <input
              type="number"
              value={props.config.seed || 42}
              onInput={(e) => props.onConfigChange({
                ...props.config,
                seed: parseInt(e.currentTarget.value) || 42
              })}
            />
          </div>
        </div>

        <div class="advanced-toggle">
          <button 
            class="toggle-button"
            onClick={() => setShowAdvanced(!showAdvanced())}
          >
            {showAdvanced() ? '隐藏' : '显示'}高级选项
          </button>
        </div>

        <Show when={showAdvanced()}>
          <div class="advanced-config">
            <div class="config-item">
              <label>最小值:</label>
              <input
                type="number"
                value={props.config.minValue || 0}
                onInput={(e) => props.onConfigChange({
                  ...props.config,
                  minValue: parseFloat(e.currentTarget.value) || 0
                })}
              />
            </div>

            <div class="config-item">
              <label>最大值:</label>
              <input
                type="number"
                value={props.config.maxValue || 100}
                onInput={(e) => props.onConfigChange({
                  ...props.config,
                  maxValue: parseFloat(e.currentTarget.value) || 100
                })}
              />
            </div>
          </div>
        </Show>
      </div>

      <div class="action-section">
        <button
          class="generate-button primary"
          onClick={props.onGenerate}
          disabled={props.isGenerating}
        >
          {props.isGenerating ? '生成中...' : '生成随机数据'}
        </button>
      </div>

      <Show when={props.error}>
        <div class="error-message">
          <span class="error-icon">⚠️</span>
          <span>{props.error}</span>
        </div>
      </Show>

      <Show when={props.result && !props.isGenerating}>
        <div class="result-section">
          <div class="result-card">
            <h5>生成结果</h5>
            <div class="result-stats">
              <div class="stat-item">
                <span class="stat-label">数据量:</span>
                <span class="stat-value">{props.result!.count.toLocaleString()}</span>
              </div>
              
              <div class="stat-item">
                <span class="stat-label">分布类型:</span>
                <span class="stat-value">{props.result!.summary.distribution}</span>
              </div>
              
              <div class="stat-item">
                <span class="stat-label">随机种子:</span>
                <span class="stat-value">{props.result!.seed}</span>
              </div>
              
              <div class="stat-item">
                <span class="stat-label">范围:</span>
                <span class="stat-value">
                  [{props.result!.summary.min?.toFixed(2) || 'N/A'}, {props.result!.summary.max?.toFixed(2) || 'N/A'}]
                </span>
              </div>
              
              <div class="stat-item">
                <span class="stat-label">生成时间:</span>
                <span class="stat-value">{props.result!.summary.generationTime}</span>
              </div>
            </div>

            <div class="data-preview">
              <h5>数据预览 (前10个):</h5>
              <div class="preview-values">
                <For each={props.result!.summary.preview || []}>
                  {(value) => <span class="preview-value">{value.toFixed(3)}</span>}
                </For>
              </div>
            </div>
          </div>
        </div>
      </Show>
    </div>
  );
};

/**
 * 统计计算器组件
 */
const StatisticsCalculator = (props: StatisticsCalculatorProps) => {
  const [selectedStats, setSelectedStats] = createSignal<string[]>(
    props.config.statistics || ['mean', 'median', 'std', 'min', 'max', 'range']
  );

  const toggleStatistic = (stat: string) => {
    const current = selectedStats();
    const updated = current.includes(stat)
      ? current.filter(s => s !== stat)
      : [...current, stat];
    
    setSelectedStats(updated);
    props.onConfigChange({
      ...props.config,
      statistics: updated
    });
  };

  return (
    <div class="statistics-calculator">
      <Show when={!props.data}>
        <div class="no-data-message">
          <span class="info-icon">ℹ️</span>
          <span>请先生成数据或输入数据</span>
        </div>
      </Show>

      <Show when={props.data}>
        <div class="config-section">
          <h4>统计计算配置</h4>
          
          <div class="statistics-selection">
            <h5>选择统计量:</h5>
            <div class="stats-grid">
              <For each={AVAILABLE_STATISTICS}>
                {(stat) => (
                  <div class="stat-checkbox">
                    <input
                      type="checkbox"
                      id={stat.key}
                      checked={selectedStats().includes(stat.key)}
                      onChange={() => toggleStatistic(stat.key)}
                    />
                    <span class="checkbox-label">{stat.label}</span>
                    <span class="stat-category">({stat.category})</span>
                  </div>
                )}
              </For>
            </div>
          </div>

          <div class="advanced-options">
            <div class="config-item">
              <label>
                <input
                  type="checkbox"
                  checked={props.config.useAnalyticsEngine || true}
                  onChange={(e) => props.onConfigChange({
                    ...props.config,
                    useAnalyticsEngine: e.currentTarget.checked
                  })}
                />
                使用 Analytics Engine
              </label>
            </div>

            <div class="config-item">
              <label>
                <input
                  type="checkbox"
                  checked={props.config.preferRust || true}
                  onChange={(e) => props.onConfigChange({
                    ...props.config,
                    preferRust: e.currentTarget.checked
                  })}
                />
                优先使用 Rust 实现
              </label>
            </div>
          </div>
        </div>

        <div class="action-section">
          <button
            class="calculate-button primary"
            onClick={props.onCalculate}
            disabled={props.isCalculating || selectedStats().length === 0}
          >
            {props.isCalculating ? '计算中...' : '计算统计量'}
          </button>
        </div>
      </Show>

      <Show when={props.error}>
        <div class="error-message">
          <span class="error-icon">⚠️</span>
          <span>{props.error}</span>
        </div>
      </Show>

      <Show when={props.result && !props.isCalculating}>
        <div class="result-section">
          <StatisticsDisplay 
            result={props.result!.results}
            compact={false}
          />
        </div>
      </Show>
    </div>
  );
};

/**
 * 综合分析器组件
 */
const ComprehensiveAnalyzer = (props: ComprehensiveAnalyzerProps) => {
  return (
    <div class="comprehensive-analyzer">
      <div class="feature-description">
        <div class="description-card">
          <h4>🔬 综合分析功能</h4>
          <p>
            综合分析是一站式数据分析服务，将<strong>自动生成随机数据</strong>并<strong>计算统计量</strong>，
            最后提供<strong>智能洞察和建议</strong>。无需手动生成数据，一键完成全流程分析。
          </p>
          <div class="feature-highlights">
            <span class="highlight">✨ 自动数据生成</span>
            <span class="highlight">📊 智能统计计算</span>
            <span class="highlight">🎯 质量评估</span>
            <span class="highlight">💡 分析建议</span>
          </div>
        </div>
      </div>

      <div class="config-section">
        <h4>综合分析配置</h4>
        
        <div class="config-tabs">
          <div class="tab-content">
            <h5>数据生成配置</h5>
            <div class="config-grid">
              <div class="config-item">
                <label>数据量:</label>
                <input
                  type="number"
                  value={props.config.dataConfig.count || 1000}
                  min="10"
                  max="100000"
                  onInput={(e) => props.onConfigChange({
                    ...props.config,
                    dataConfig: {
                      ...props.config.dataConfig,
                      count: parseInt(e.currentTarget.value) || 1000
                    }
                  })}
                />
                <span class="config-hint">推荐1000-10000个数据点</span>
              </div>

              <div class="config-item">
                <label>分布类型:</label>
                <select
                  value={props.config.dataConfig.distribution || 'uniform'}
                  onChange={(e) => props.onConfigChange({
                    ...props.config,
                    dataConfig: {
                      ...props.config.dataConfig,
                      distribution: e.currentTarget.value as 'uniform' | 'normal' | 'exponential'
                    }
                  })}
                >
                  <For each={DISTRIBUTION_OPTIONS}>
                    {(option) => (
                      <option value={option.value}>{option.label}</option>
                    )}
                  </For>
                </select>
              </div>

              <div class="config-item">
                <label>随机种子:</label>
                <input
                  type="number"
                  value={props.config.dataConfig.seed || 42}
                  min="1"
                  max="999999"
                  onInput={(e) => props.onConfigChange({
                    ...props.config,
                    dataConfig: {
                      ...props.config.dataConfig,
                      seed: parseInt(e.currentTarget.value) || 42
                    }
                  })}
                />
                <span class="config-hint">确保结果可重现</span>
              </div>
            </div>

            <h5>统计计算配置</h5>
            <div class="config-item">
              <label>
                <input
                  type="checkbox"
                  checked={props.config.statsConfig.useAnalyticsEngine !== false}
                  onChange={(e) => props.onConfigChange({
                    ...props.config,
                    statsConfig: {
                      ...props.config.statsConfig,
                      useAnalyticsEngine: e.currentTarget.checked
                    }
                  })}
                />
                使用 Analytics Engine
                <span class="config-hint">高性能Rust/Python混合实现</span>
              </label>
            </div>

            <div class="config-item">
              <label>
                <input
                  type="checkbox"
                  checked={props.config.statsConfig.preferRust !== false}
                  onChange={(e) => props.onConfigChange({
                    ...props.config,
                    statsConfig: {
                      ...props.config.statsConfig,
                      preferRust: e.currentTarget.checked
                    }
                  })}
                />
                优先使用Rust实现
                <span class="config-hint">更快的计算性能</span>
              </label>
            </div>
          </div>
        </div>
      </div>

      <div class="action-section">
        <button
          class="analyze-button primary"
          onClick={props.onAnalyze}
          disabled={props.isAnalyzing}
        >
          {props.isAnalyzing ? (
            <>
              <span class="loading-spinner">⏳</span>
              分析中...
            </>
          ) : (
            <>
              <span class="action-icon">🚀</span>
              开始综合分析
            </>
          )}
        </button>
        <div class="action-hint">
          将自动生成 {props.config.dataConfig.count || 1000} 个 {
            DISTRIBUTION_OPTIONS.find(opt => opt.value === (props.config.dataConfig.distribution || 'uniform'))?.label
          } 分布数据并计算统计量
        </div>
      </div>

      <Show when={props.error}>
        <div class="error-message">
          <span class="error-icon">⚠️</span>
          <span>{props.error}</span>
          <div class="error-suggestion">
            💡 建议：请检查配置参数或稍后重试
          </div>
        </div>
      </Show>

      <Show when={props.result && !props.isAnalyzing}>
        <div class="result-section">
          <div class="comprehensive-results">
            <div class="result-grid">
              <div class="result-card data-summary">
                <h5>📊 数据摘要</h5>
                <div class="summary-stats">
                  <div class="stat-item">
                    <span class="stat-label">数据量:</span>
                    <span class="stat-value">{props.result!.dataSummary.count.toLocaleString()}</span>
                  </div>
                  <div class="stat-item">
                    <span class="stat-label">分布类型:</span>
                    <span class="stat-value">{props.result!.dataSummary.distribution}</span>
                  </div>
                  <div class="stat-item">
                    <span class="stat-label">数据范围:</span>
                    <span class="stat-value">
                      [{props.result!.dataSummary.range?.min.toFixed(2)}, {props.result!.dataSummary.range?.max.toFixed(2)}]
                    </span>
                  </div>
                  <div class="stat-item">
                    <span class="stat-label">数据质量:</span>
                    <span class={`stat-value quality-${props.result!.insights.dataQuality}`}>
                      {props.result!.insights.dataQuality === 'excellent' ? '🟢 优秀' :
                       props.result!.insights.dataQuality === 'good' ? '🟡 良好' :
                       props.result!.insights.dataQuality === 'fair' ? '🟠 一般' : '🔴 较差'}
                    </span>
                  </div>
                </div>
              </div>

              <div class="result-card statistics">
                <h5>📈 统计分析</h5>
                <StatisticsDisplay 
                  result={props.result!.statistics}
                  compact={true}
                />
              </div>

              <div class="result-card insights">
                <h5>💡 智能洞察</h5>
                <div class="insights-content">
                  <div class="insight-item">
                    <span class="insight-label">分布特征:</span>
                    <span class="insight-value">{props.result!.insights.distributionType}</span>
                  </div>
                  <div class="insight-item">
                    <span class="insight-label">异常值:</span>
                    <span class="insight-value">{props.result!.insights.outlierCount} 个</span>
                  </div>
                  <div class="recommendations">
                    <h6>🎯 分析建议:</h6>
                    <ul>
                      <For each={props.result!.insights.recommendations}>
                        {(recommendation) => (
                          <li>{recommendation}</li>
                        )}
                      </For>
                    </ul>
                  </div>
                </div>
              </div>

              <div class="result-card performance">
                <h5>⚡ 性能信息</h5>
                <div class="performance-stats">
                  <div class="stat-item">
                    <span class="stat-label">执行时间:</span>
                    <span class="stat-value">{String(props.result!.performance.executionTimeMs)}ms</span>
                  </div>
                  <div class="stat-item">
                    <span class="stat-label">实现方式:</span>
                    <span class="stat-value">{props.result!.performance.implementation}</span>
                  </div>
                  <div class="stat-item">
                    <span class="stat-label">分析时间:</span>
                    <span class="stat-value">{props.result!.analyzedAt}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </Show>
    </div>
  );
};

/**
 * 统计结果展示组件
 */
const StatisticsDisplay = (props: StatisticsDisplayProps) => {
  const [showDetails, setShowDetails] = createSignal(false);

  // 🔧 修复：格式化分布形状显示
  const formatDistributionShape = (shape: string) => {
    const shapeMap: Record<string, string> = {
      'analytics_engine': '智能分析',
      'uniform': '均匀分布',
      'normal': '正态分布',
      'exponential': '指数分布',
      'left_skewed': '左偏分布',
      'right_skewed': '右偏分布',
      'symmetric': '对称分布'
    };
    return shapeMap[shape] || shape;
  };

  return (
    <div class="statistics-display">
      <div class="stats-overview">
        <div class="stats-grid">
          <Show when={props.result.basic}>
            <div class="stat-group basic">
              <h6>基本统计</h6>
              <div class="stat-item">
                <span class="stat-label">数量:</span>
                <span class="stat-value">{props.result.basic!.count.toLocaleString()}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">均值:</span>
                <span class="stat-value">{props.result.basic!.mean.toFixed(4)}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">最小值:</span>
                <span class="stat-value">{props.result.basic!.min.toFixed(4)}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">最大值:</span>
                <span class="stat-value">{props.result.basic!.max.toFixed(4)}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">极差:</span>
                <span class="stat-value">{props.result.basic!.range.toFixed(4)}</span>
              </div>
            </div>
          </Show>

          <Show when={props.result.distribution}>
            <div class="stat-group distribution">
              <h6>分布统计</h6>
              <div class="stat-item">
                <span class="stat-label">中位数:</span>
                <span class="stat-value">{props.result.distribution!.median.toFixed(4)}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">标准差:</span>
                <span class="stat-value">{props.result.distribution!.stdDev.toFixed(4)}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">方差:</span>
                <span class="stat-value">{props.result.distribution!.variance.toFixed(4)}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">四分位距:</span>
                <span class="stat-value">{props.result.distribution!.iqr.toFixed(4)}</span>
              </div>
            </div>
          </Show>

          <Show when={props.result.percentiles}>
            <div class="stat-group percentiles">
              <h6>分位数</h6>
              <div class="stat-item">
                <span class="stat-label">Q1 (25%):</span>
                <span class="stat-value">{props.result.percentiles!.q1.toFixed(4)}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">Q2 (50%):</span>
                <span class="stat-value">{props.result.percentiles!.q2.toFixed(4)}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">Q3 (75%):</span>
                <span class="stat-value">{props.result.percentiles!.q3.toFixed(4)}</span>
              </div>
            </div>
          </Show>

          <Show when={props.result.shape}>
            <div class="stat-group shape">
              <h6>形状统计</h6>
              <div class="stat-item">
                <span class="stat-label">偏度:</span>
                <span class="stat-value">{props.result.shape!.skewness.toFixed(4)}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">峰度:</span>
                <span class="stat-value">{props.result.shape!.kurtosis.toFixed(4)}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">分布形状:</span>
                <span class="stat-value">{formatDistributionShape(props.result.shape!.distributionShape)}</span>
              </div>
            </div>
          </Show>
        </div>
      </div>

      <Show when={!props.compact}>
        <div class="details-toggle">
          <button 
            class="toggle-button"
            onClick={() => setShowDetails(!showDetails())}
          >
            {showDetails() ? '隐藏' : '显示'}详细信息
          </button>
        </div>

        <Show when={showDetails()}>
          <div class="detailed-stats">
            <div class="detail-section">
              <h6>详细统计信息</h6>
              <div class="detail-grid">
                {/* 🔧 修复：只在总和有意义时显示 */}
                <Show when={props.result.basic?.sum !== undefined && Math.abs(props.result.basic.sum) > 0.0001}>
                  <div class="detail-item">
                    <span class="detail-label">总和:</span>
                    <span class="detail-value">{props.result.basic!.sum.toFixed(4)}</span>
                  </div>
                </Show>
                
                {/* 添加更多有用的详细信息 */}
                <Show when={props.result.basic?.count}>
                  <div class="detail-item">
                    <span class="detail-label">样本数量:</span>
                    <span class="detail-value">{props.result.basic!.count.toLocaleString()}</span>
                  </div>
                </Show>
                
                <Show when={props.result.distribution?.variance}>
                  <div class="detail-item">
                    <span class="detail-label">变异系数:</span>
                    <span class="detail-value">
                      {((props.result.distribution!.stdDev / Math.abs(props.result.basic?.mean || 1)) * 100).toFixed(2)}%
                    </span>
                  </div>
                </Show>
              </div>
            </div>
          </div>
        </Show>
      </Show>
    </div>
  );
};

// ===== 主组件 =====

/**
 * MVP STAT 主视图组件
 * 使用SolidJS细粒度响应式，最小化重新渲染
 */
export function MvpStatView(props: MvpStatViewProps = {}) {
  const mvpStat = useMvpStat();
  const dataGenerator = useDataGenerator();
  const statsCalculator = useStatisticsCalculator();
  const comprehensiveAnalyzer = useComprehensiveAnalyzer();

  // 本地UI状态
  const [activeTab, setActiveTab] = createSignal<'generate' | 'calculate' | 'comprehensive'>(
    props.initialTab || 'generate'
  );

  // 计算属性 - 细粒度响应式
  const hasAnyData = createMemo(() => mvpStat.hasGeneratedData());
  const hasAnyResults = createMemo(() => 
    mvpStat.hasStatisticsResult() || mvpStat.hasComprehensiveResult()
  );
  const isAnyLoading = createMemo(() => mvpStat.isAnyLoading());

  // 页面加载时的初始化
  onMount(() => {
    console.log('🎯 [MvpStatView] 组件初始化');
  });

  // 事件处理函数
  const handleTabChange = (tab: 'generate' | 'calculate' | 'comprehensive') => {
    setActiveTab(tab);
    mvpStat.setActiveTab(tab);
  };

  const handleDataGenerated = (result: any) => {
    // 自动切换到计算标签
    if (activeTab() === 'generate') {
      handleTabChange('calculate');
    }
  };

  const handleStatisticsCalculated = (result: any) => {
    // 🔧 修复：自动切换到综合分析标签
    if (activeTab() === 'calculate') {
      // 延迟切换，让用户看到计算结果
      setTimeout(() => {
        handleTabChange('comprehensive');
        // 显示引导提示
        eventBus.emit('notification:show', {
          message: '统计计算完成！现在可以进行综合分析了',
          type: 'info',
          timestamp: Date.now(),
          duration: 3000
        });
      }, 1500);
    }
  };

  const handleAnalysisCompleted = (result: any) => {
    // 处理分析完成
  };

  return (
    <div class="mvp-stat-container mobile-optimized">
      <div class="stat-navigation">
        <div class="nav-tabs">
          <button
            class={`nav-tab ${activeTab() === 'generate' ? 'active' : ''}`}
            onClick={() => handleTabChange('generate')}
          >
            🎲 数据生成
          </button>
          <button
            class={`nav-tab ${activeTab() === 'calculate' ? 'active' : ''}`}
            onClick={() => handleTabChange('calculate')}
            disabled={!hasAnyData()}
          >
            📊 统计计算
          </button>
          <button
            class={`nav-tab ${activeTab() === 'comprehensive' ? 'active' : ''}`}
            onClick={() => handleTabChange('comprehensive')}
            title="🔬 一键完成数据生成+统计计算+智能洞察，获得全面分析报告"
          >
            🔬 综合分析
            <Show when={hasAnyResults() && activeTab() !== 'comprehensive'}>
              <span class="tab-badge">推荐</span>
            </Show>
          </button>
        </div>
      </div>

      <div class="stat-content">
        <Show when={mvpStat.error()}>
          <div class="global-error">
            <span class="error-icon">⚠️</span>
            <span class="error-text">{mvpStat.error()}</span>
            <button class="error-close" onClick={mvpStat.clearError}>×</button>
          </div>
        </Show>

        <Switch>
          <Match when={activeTab() === 'generate'}>
            <DataGenerator
              config={dataGenerator.config()}
              onConfigChange={dataGenerator.setConfig}
              onGenerate={() => dataGenerator.generate().then(handleDataGenerated).catch(() => {})}
              isGenerating={dataGenerator.loading()}
              result={dataGenerator.result()}
              error={dataGenerator.error()}
            />
          </Match>

          <Match when={activeTab() === 'calculate'}>
            <StatisticsCalculator
              data={statsCalculator.data()}
              config={statsCalculator.config()}
              onConfigChange={statsCalculator.setConfig}
              onCalculate={() => statsCalculator.calculate().then(handleStatisticsCalculated).catch(() => {})}
              isCalculating={statsCalculator.loading()}
              result={statsCalculator.result()}
              error={statsCalculator.error()}
            />
          </Match>

          <Match when={activeTab() === 'comprehensive'}>
            <ComprehensiveAnalyzer
              config={{
                dataConfig: comprehensiveAnalyzer.dataConfig(),
                statsConfig: comprehensiveAnalyzer.statsConfig()
              }}
              onConfigChange={(config) => {
                comprehensiveAnalyzer.setDataConfig(config.dataConfig);
                comprehensiveAnalyzer.setStatsConfig({
                  ...config.statsConfig,
                  data: [] // 综合分析时数据会自动生成
                });
              }}
              onAnalyze={() => comprehensiveAnalyzer.analyze().then(handleAnalysisCompleted).catch(() => {})}
              isAnalyzing={comprehensiveAnalyzer.loading()}
              result={comprehensiveAnalyzer.result()}
              error={comprehensiveAnalyzer.error()}
            />
          </Match>
        </Switch>
      </div>
    </div>
  );
} 