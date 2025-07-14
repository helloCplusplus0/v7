"""
Analytics Algorithms Package

Contains Python implementations of advanced algorithms that complement
the Rust core implementations.
"""

import json
import time
import sys
from typing import Any, Dict, List, Union

from .ml_advanced import AdvancedMLAlgorithms
from .time_series import TimeSeriesAlgorithms
from .nlp import NLPAlgorithms

class AlgorithmDispatcher:
    """主算法分发器"""
    
    def __init__(self):
        self.ml_algorithms = AdvancedMLAlgorithms()
        self.ts_algorithms = TimeSeriesAlgorithms()
        self.nlp_algorithms = NLPAlgorithms()
        
        # 注册所有可用算法
        self._algorithms = {
            # 机器学习算法
            "kmeans": self.ml_algorithms.kmeans_clustering,
            "dbscan": self.ml_algorithms.dbscan_clustering,
            "pca": self.ml_algorithms.pca_analysis,
            "linear_regression": self.ml_algorithms.linear_regression,
            "random_forest": self.ml_algorithms.random_forest_analysis,
            
            # 时间序列算法
            "arima": self.ts_algorithms.arima_forecast,
            "seasonal_decompose": self.ts_algorithms.seasonal_decompose,
            "trend_analysis": self.ts_algorithms.trend_analysis,
            "anomaly_detection": self.ts_algorithms.anomaly_detection,
            
            # NLP算法 (需要额外依赖)
            "sentiment_analysis": self.nlp_algorithms.sentiment_analysis,
            "text_similarity": self.nlp_algorithms.text_similarity,
            "keyword_extraction": self.nlp_algorithms.keyword_extraction,
        }

    def analyze(self, algorithm: str, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """
        执行分析算法
        
        Args:
            algorithm: 算法名称
            data: 输入数据
            params: 算法参数
            
        Returns:
            包含结果和统计信息的字典
        """
        start_time = time.time()
        
        if algorithm not in self._algorithms:
            raise ValueError(f"Algorithm '{algorithm}' not supported in Python implementation")
        
        try:
            # 执行算法
            result = self._algorithms[algorithm](data, params)
            
            execution_time = (time.time() - start_time) * 1000  # 转换为毫秒
            
            # 构建响应
            response = {
                "result": json.dumps(result),
                "stats": {
                    "execution_time_ms": str(int(execution_time)),
                    "python_version": f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
                    "data_points": str(len(data)),
                    "algorithm": algorithm,
                }
            }
            
            return response
            
        except Exception as e:
            raise RuntimeError(f"Python algorithm '{algorithm}' failed: {str(e)}")

    def get_supported_algorithms(self) -> List[Dict[str, Any]]:
        """获取支持的算法列表"""
        return [
            # 机器学习算法
            {
                "name": "kmeans",
                "description": "K-means clustering algorithm",
                "required_params": ["k"],
                "optional_params": ["max_iter", "random_state"]
            },
            {
                "name": "dbscan",
                "description": "DBSCAN clustering algorithm", 
                "required_params": [],
                "optional_params": ["eps", "min_samples"]
            },
            {
                "name": "pca",
                "description": "Principal Component Analysis",
                "required_params": [],
                "optional_params": ["n_components"]
            },
            {
                "name": "linear_regression",
                "description": "Linear regression analysis",
                "required_params": ["target"],
                "optional_params": ["fit_intercept"]
            },
            {
                "name": "random_forest",
                "description": "Random Forest analysis",
                "required_params": ["target"],
                "optional_params": ["n_estimators", "max_depth", "random_state"]
            },
            
            # 时间序列算法
            {
                "name": "arima",
                "description": "ARIMA time series forecasting",
                "required_params": ["order"],
                "optional_params": ["seasonal_order", "periods"]
            },
            {
                "name": "seasonal_decompose",
                "description": "Seasonal decomposition of time series",
                "required_params": ["period"],
                "optional_params": ["model"]
            },
            {
                "name": "trend_analysis",
                "description": "Trend analysis using Mann-Kendall test",
                "required_params": [],
                "optional_params": ["alpha"]
            },
            {
                "name": "anomaly_detection",
                "description": "Statistical anomaly detection",
                "required_params": [],
                "optional_params": ["method", "threshold"]
            },
            
            # NLP算法
            {
                "name": "sentiment_analysis",
                "description": "Text sentiment analysis",
                "required_params": ["text"],
                "optional_params": ["model"]
            },
            {
                "name": "text_similarity",
                "description": "Text similarity calculation",
                "required_params": ["text1", "text2"],
                "optional_params": ["method"]
            },
            {
                "name": "keyword_extraction",
                "description": "Keyword extraction from text",
                "required_params": ["text"],
                "optional_params": ["n_keywords", "method"]
            },
        ]

# 全局分发器实例
_dispatcher = AlgorithmDispatcher()

# 导出主要函数
def analyze(algorithm: str, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
    """主分析函数，供Rust端调用"""
    return _dispatcher.analyze(algorithm, data, params)

def get_supported_algorithms() -> List[Dict[str, Any]]:
    """获取支持的算法列表，供Rust端调用"""
    return _dispatcher.get_supported_algorithms()

__all__ = ["analyze", "get_supported_algorithms"] 