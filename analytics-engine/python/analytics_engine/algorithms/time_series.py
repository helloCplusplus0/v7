"""
Time Series Analysis Algorithms

Contains Python implementations of time series analysis algorithms.
"""

import numpy as np
from typing import Dict, List, Any, Tuple
import warnings

# 延迟导入时间序列库
try:
    from scipy import stats
    from scipy.signal import find_peaks
    SCIPY_AVAILABLE = True
except ImportError:
    SCIPY_AVAILABLE = False
    warnings.warn("scipy not available, time series algorithms will be limited")

class TimeSeriesAlgorithms:
    """时间序列分析算法实现"""
    
    def __init__(self):
        self.available = SCIPY_AVAILABLE
    
    def _check_availability(self):
        """检查依赖是否可用"""
        if not self.available:
            raise RuntimeError("scipy not available for time series algorithms")
    
    def arima_forecast(self, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """ARIMA时间序列预测（简化实现）"""
        # 注意：这是一个简化的ARIMA实现，生产环境建议使用statsmodels
        
        if len(data) < 10:
            raise ValueError("ARIMA requires at least 10 data points")
        
        y = np.array(data)
        
        # 获取参数
        order = params.get("order", "1,1,1")
        p, d, q = map(int, order.split(","))
        periods = int(params.get("periods", "5"))
        
        # 简化的差分处理
        if d > 0:
            for _ in range(d):
                y = np.diff(y)
        
        # 简单的AR模型预测（作为ARIMA的简化版本）
        if len(y) >= p + 1:
            # 使用最后p个值进行线性预测
            X = np.column_stack([y[i:-(p-i)] for i in range(p)] if p > 0 else [y[:-1]])
            y_target = y[p:]
            
            # 简单线性回归
            if X.size > 0 and y_target.size > 0:
                coeffs = np.linalg.lstsq(X, y_target, rcond=None)[0]
                
                # 预测未来值
                forecast = []
                last_values = y[-p:].tolist() if p > 0 else [y[-1]]
                
                for _ in range(periods):
                    if p > 0:
                        next_val = np.dot(coeffs, last_values[-p:])
                    else:
                        next_val = last_values[-1]  # 简单持续预测
                    
                    forecast.append(float(next_val))
                    last_values.append(next_val)
                
                # 如果进行了差分，需要逆向恢复
                if d > 0:
                    # 简化的逆差分
                    base_value = data[-1]
                    for i in range(len(forecast)):
                        forecast[i] += base_value
            else:
                forecast = [data[-1]] * periods  # 回退到简单预测
        else:
            forecast = [data[-1]] * periods  # 回退到简单预测
        
        return {
            "forecast": forecast,
            "order": [p, d, q],
            "periods": periods,
            "model": "simplified_arima",
            "residuals": [],  # 简化版本不计算残差
            "aic": 0.0,  # 简化版本不计算AIC
            "bic": 0.0   # 简化版本不计算BIC
        }
    
    def seasonal_decompose(self, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """季节性分解"""
        if len(data) < 4:
            raise ValueError("Seasonal decompose requires at least 4 data points")
        
        y = np.array(data)
        period = int(params.get("period", "4"))
        model = params.get("model", "additive")  # additive or multiplicative
        
        if len(y) < 2 * period:
            period = max(2, len(y) // 2)
        
        # 简化的季节性分解
        def moving_average(arr, window):
            """移动平均"""
            if window >= len(arr):
                return np.full(len(arr), np.mean(arr))
            
            result = np.full(len(arr), np.nan)
            for i in range(len(arr)):
                start = max(0, i - window // 2)
                end = min(len(arr), i + window // 2 + 1)
                result[i] = np.mean(arr[start:end])
            return result
        
        # 趋势分量（移动平均）
        trend = moving_average(y, period)
        
        # 去趋势化
        if model == "additive":
            detrended = y - trend
        else:  # multiplicative
            detrended = y / np.where(trend != 0, trend, 1)
        
        # 季节性分量
        seasonal = np.full(len(y), np.nan)
        for i in range(period):
            seasonal_indices = list(range(i, len(y), period))
            if seasonal_indices:
                seasonal_values = detrended[seasonal_indices]
                seasonal_values = seasonal_values[~np.isnan(seasonal_values)]
                if len(seasonal_values) > 0:
                    season_avg = np.mean(seasonal_values)
                    for idx in seasonal_indices:
                        seasonal[idx] = season_avg
        
        # 填充NaN值
        seasonal = np.where(np.isnan(seasonal), 0, seasonal)
        
        # 残差分量
        if model == "additive":
            residual = y - trend - seasonal
        else:  # multiplicative
            residual = y / (trend * np.where(seasonal != 0, seasonal, 1))
        
        return {
            "trend": np.nan_to_num(trend).tolist(),
            "seasonal": seasonal.tolist(),
            "residual": np.nan_to_num(residual).tolist(),
            "period": period,
            "model": model,
            "original": y.tolist()
        }
    
    def trend_analysis(self, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """趋势分析（Mann-Kendall检验）"""
        self._check_availability()
        
        if len(data) < 3:
            raise ValueError("Trend analysis requires at least 3 data points")
        
        y = np.array(data)
        alpha = float(params.get("alpha", "0.05"))
        
        # Mann-Kendall趋势检验
        n = len(y)
        s = 0
        
        for i in range(n - 1):
            for j in range(i + 1, n):
                if y[j] > y[i]:
                    s += 1
                elif y[j] < y[i]:
                    s -= 1
        
        # 计算方差
        var_s = (n * (n - 1) * (2 * n + 5)) / 18
        
        # 计算标准化统计量
        if s > 0:
            z = (s - 1) / np.sqrt(var_s)
        elif s < 0:
            z = (s + 1) / np.sqrt(var_s)
        else:
            z = 0
        
        # 计算p值
        p_value = 2 * (1 - stats.norm.cdf(abs(z)))
        
        # 判断趋势
        if p_value < alpha:
            if s > 0:
                trend = "increasing"
            else:
                trend = "decreasing"
            significant = True
        else:
            trend = "no trend"
            significant = False
        
        # 计算Theil-Sen斜率估计
        slopes = []
        for i in range(n - 1):
            for j in range(i + 1, n):
                if j != i:
                    slope = (y[j] - y[i]) / (j - i)
                    slopes.append(slope)
        
        if slopes:
            theil_sen_slope = np.median(slopes)
        else:
            theil_sen_slope = 0.0
        
        return {
            "trend": trend,
            "significant": significant,
            "p_value": float(p_value),
            "z_statistic": float(z),
            "s_statistic": int(s),
            "theil_sen_slope": float(theil_sen_slope),
            "alpha": alpha,
            "method": "mann_kendall"
        }
    
    def anomaly_detection(self, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """异常检测"""
        if len(data) < 3:
            raise ValueError("Anomaly detection requires at least 3 data points")
        
        y = np.array(data)
        method = params.get("method", "zscore")
        threshold = float(params.get("threshold", "2.0"))
        
        anomalies = []
        scores = []
        
        if method == "zscore":
            # Z-score方法
            mean_val = np.mean(y)
            std_val = np.std(y)
            
            if std_val == 0:
                z_scores = np.zeros(len(y))
            else:
                z_scores = np.abs((y - mean_val) / std_val)
            
            anomaly_mask = z_scores > threshold
            anomalies = np.where(anomaly_mask)[0].tolist()
            scores = z_scores.tolist()
            
        elif method == "iqr":
            # IQR方法
            q1 = np.percentile(y, 25)
            q3 = np.percentile(y, 75)
            iqr = q3 - q1
            
            lower_bound = q1 - threshold * iqr
            upper_bound = q3 + threshold * iqr
            
            anomaly_mask = (y < lower_bound) | (y > upper_bound)
            anomalies = np.where(anomaly_mask)[0].tolist()
            
            # 计算距离边界的距离作为分数
            scores = []
            for val in y:
                if val < lower_bound:
                    scores.append(float(lower_bound - val))
                elif val > upper_bound:
                    scores.append(float(val - upper_bound))
                else:
                    scores.append(0.0)
                    
        elif method == "isolation":
            # 简化的孤立森林方法
            # 实际实现应该使用sklearn.ensemble.IsolationForest
            mean_val = np.mean(y)
            distances = np.abs(y - mean_val)
            threshold_val = np.percentile(distances, (1 - threshold / 10) * 100)
            
            anomaly_mask = distances > threshold_val
            anomalies = np.where(anomaly_mask)[0].tolist()
            scores = distances.tolist()
        
        return {
            "anomalies": anomalies,
            "scores": scores,
            "method": method,
            "threshold": threshold,
            "n_anomalies": len(anomalies),
            "anomaly_rate": len(anomalies) / len(data),
            "data_length": len(data)
        } 