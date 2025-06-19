 /**
 * 🔧 配置系统类型定义
 */

export interface AppConfig {
    app: AppInfo;
    api: ApiConfig;
    server: ServerConfig;
    ui: UiConfig;
    features: FeatureFlags;
    mock: MockConfig;
    monitoring: MonitoringConfig;
    security: SecurityConfig;
    runtime: RuntimeInfo;
  }
  
  export interface AppInfo {
    name: string;
    version: string;
    description: string;
    author: string;
    homepage: string;
  }
  
  export interface ApiConfig {
    baseUrl: string;
    timeout: number;
    retryAttempts: number;
    retryDelay: number;
    endpoints: {
      health: string;
      hello: string;
      slices: string;
    };
  }
  
  export interface ServerConfig {
    host: string;
    port: number;
    hmr: {
      port: number;
      host: string;
      overlay: boolean;
    };
    proxy: {
      enabled: boolean;
      target: string;
      changeOrigin: boolean;
      secure: boolean;
    };
    cors: {
      enabled: boolean;
      origin: string | string[];
      methods: string[];
      headers: string[];
    };
  }
  
  export interface UiConfig {
    theme: 'telegram' | 'dark' | 'light';
    language: 'zh' | 'en';
    animations: boolean;
    notifications: boolean;
    autoRefresh: boolean;
    refreshInterval: number;
  }
  
  // Mock 控制策略
  export type MockStrategy = 
    | 'auto'      // 自动检测：后端可用时使用真实数据，不可用时使用 Mock
    | 'force'     // 强制使用 Mock 数据
    | 'disabled'  // 禁用 Mock，只使用真实数据
    | 'hybrid';   // 混合模式：部分接口使用 Mock，部分使用真实数据

  export interface MockConfig {
    strategy: MockStrategy;
    fallbackTimeout: number;  // 后端检测超时时间(ms)
    showIndicator: boolean;   // 是否显示 Mock 状态指示器
    logRequests: boolean;     // 是否记录请求日志
    hybridEndpoints?: string[]; // 混合模式下使用 Mock 的端点列表
  }

  export interface FeatureFlags {
    enableMock: boolean;
    enableDebug: boolean;
    enableHMR: boolean;
    enableSourceMap: boolean;
    enableCoverage: boolean;
    enableE2E: boolean;
    enablePWA: boolean;
    enableAnalytics: boolean;
  }
  
  export interface MonitoringConfig {
    enabled: boolean;
    endpoint: string;
    sampleRate: number;
    enablePerformance: boolean;
    enableErrors: boolean;
    enableUserActions: boolean;
  }
  
  export interface SecurityConfig {
    enableCSP: boolean;
    enableCORS: boolean;
    enableHTTPS: boolean;
    trustedDomains: string[];
    apiKeyHeader: string;
  }
  
  export interface RuntimeInfo {
    isDevelopment: boolean;
    isProduction: boolean;
    mode: string;
    timestamp: string;
  }