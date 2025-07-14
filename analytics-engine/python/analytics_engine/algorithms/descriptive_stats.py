"""
描述性统计算法模块

提供复杂的描述性统计量计算，包括：
- 方差、标准差
- 偏度、峰度
- 众数分析
- 分布形状分析

设计原则：
- 使用SciPy统计函数提供精确计算
- 处理各种分布形状和异常值
- 提供详细的统计诊断信息
"""

from typing import Dict, List, Any, Optional, Tuple
import numpy as np
from scipy import stats
from collections import Counter
import warnings

# 忽略可能的数值警告
warnings.filterwarnings('ignore', category=RuntimeWarning)


def variance_and_std(data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
    """计算方差和标准差
    
    Args:
        data: 数值数据列表
        params: 参数字典，支持:
               - ddof: 自由度修正，0为总体，1为样本(默认)
               - method: 'biased' 或 'unbiased'(默认)
    
    Returns:
        包含方差和标准差的字典
    """
    if not data:
        return {"result": None, "error": "Empty data"}
    
    if len(data) < 2:
        return {"result": None, "error": "Need at least 2 data points"}
    
    try:
        arr = np.array(data, dtype=np.float64)
        
        # 自由度修正
        ddof = int(params.get("ddof", "1"))
        method = params.get("method", "unbiased")
        
        if method == "unbiased":
            ddof = 1
        elif method == "biased":
            ddof = 0
        
        variance = float(np.var(arr, ddof=ddof))
        std_dev = float(np.std(arr, ddof=ddof))
        
        result = {
            "variance": variance,
            "std_dev": std_dev,
            "coefficient_of_variation": std_dev / np.mean(arr) if np.mean(arr) != 0 else None,
        }
        
        return {
            "result": result,
            "algorithm": "variance_and_std",
            "method": method,
            "ddof": ddof,
            "data_size": len(data),
            "implementation": "python_numpy"
        }
    except Exception as e:
        return {"result": None, "error": str(e)}


def skewness_and_kurtosis(data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
    """计算偏度和峰度
    
    Args:
        data: 数值数据列表
        params: 参数字典，支持:
               - method: 'fisher'(默认) 或 'pearson'
               - bias: 是否使用有偏估计
    
    Returns:
        包含偏度和峰度的字典
    """
    if not data:
        return {"result": None, "error": "Empty data"}
    
    if len(data) < 3:
        return {"result": None, "error": "Need at least 3 data points for skewness"}
    
    try:
        arr = np.array(data, dtype=np.float64)
        
        # 参数设置
        bias = params.get("bias", "false").lower() == "true"
        method = params.get("method", "fisher")
        
        # 计算偏度和峰度
        skewness = float(stats.skew(arr, bias=bias))
        
        if len(data) >= 4:
            if method == "fisher":
                # Fisher定义：正态分布的峰度为0
                kurtosis = float(stats.kurtosis(arr, bias=bias, fisher=True))
            else:
                # Pearson定义：正态分布的峰度为3
                kurtosis = float(stats.kurtosis(arr, bias=bias, fisher=False))
        else:
            kurtosis = None
        
        # 形状解释
        skew_interpretation = _interpret_skewness(skewness)
        kurt_interpretation = _interpret_kurtosis(kurtosis, method) if kurtosis is not None else None
        
        result = {
            "skewness": skewness,
            "skewness_interpretation": skew_interpretation,
            "kurtosis": kurtosis,
            "kurtosis_interpretation": kurt_interpretation,
        }
        
        return {
            "result": result,
            "algorithm": "skewness_and_kurtosis",
            "method": method,
            "bias": bias,
            "data_size": len(data),
            "implementation": "python_scipy"
        }
    except Exception as e:
        return {"result": None, "error": str(e)}


def mode_analysis(data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
    """计算众数分析
    
    Args:
        data: 数值数据列表
        params: 参数字典，支持:
               - tolerance: 浮点数容差，用于分组相近的值
               - max_modes: 最大众数个数
    
    Returns:
        包含众数分析的字典
    """
    if not data:
        return {"result": None, "error": "Empty data"}
    
    try:
        arr = np.array(data, dtype=np.float64)
        tolerance = float(params.get("tolerance", "1e-10"))
        max_modes = int(params.get("max_modes", "5"))
        
        # 对于连续数据，需要考虑容差
        if tolerance > 0:
            # 四舍五入到指定精度
            decimal_places = max(0, -int(np.log10(tolerance)))
            rounded_data = np.round(arr, decimal_places)
            counter = Counter(rounded_data)
        else:
            counter = Counter(arr)
        
        # 找出出现频率最高的值
        if not counter:
            return {"result": None, "error": "No valid data for mode calculation"}
        
        max_count = counter.most_common(1)[0][1]
        modes = [value for value, count in counter.items() if count == max_count]
        
        # 限制返回的众数个数
        if len(modes) > max_modes:
            modes = modes[:max_modes]
        
        # 计算众数统计
        mode_frequency = max_count
        mode_percentage = (mode_frequency / len(data)) * 100
        is_multimodal = len(modes) > 1
        
        result = {
            "modes": [float(mode) for mode in modes],
            "mode_count": len(modes),
            "mode_frequency": mode_frequency,
            "mode_percentage": mode_percentage,
            "is_multimodal": is_multimodal,
            "distribution_type": _classify_distribution_by_modes(len(modes))
        }
        
        return {
            "result": result,
            "algorithm": "mode_analysis",
            "tolerance": tolerance,
            "data_size": len(data),
            "implementation": "python_collections"
        }
    except Exception as e:
        return {"result": None, "error": str(e)}


def distribution_analysis(data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
    """综合分布形状分析
    
    Args:
        data: 数值数据列表
        params: 参数字典
    
    Returns:
        包含分布形状分析的字典
    """
    if not data:
        return {"result": None, "error": "Empty data"}
    
    if len(data) < 3:
        return {"result": None, "error": "Need at least 3 data points"}
    
    try:
        arr = np.array(data, dtype=np.float64)
        
        # 基础统计
        mean_val = float(np.mean(arr))
        median_val = float(np.median(arr))
        std_val = float(np.std(arr, ddof=1))
        
        # 偏度和峰度
        skewness = float(stats.skew(arr))
        kurtosis = float(stats.kurtosis(arr, fisher=True)) if len(arr) >= 4 else None
        
        # 分布类型判断
        distribution_shape = _analyze_distribution_shape(mean_val, median_val, skewness, kurtosis)
        
        # 正态性检验
        normality_test = _test_normality(arr)
        
        result = {
            "shape_analysis": distribution_shape,
            "normality_test": normality_test,
            "symmetry": _analyze_symmetry(mean_val, median_val, skewness),
            "tail_behavior": _analyze_tail_behavior(kurtosis) if kurtosis is not None else None,
        }
        
        return {
            "result": result,
            "algorithm": "distribution_analysis",
            "data_size": len(data),
            "implementation": "python_scipy"
        }
    except Exception as e:
        return {"result": None, "error": str(e)}


def comprehensive_stats(data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
    """综合描述性统计分析
    
    整合所有描述性统计量，提供完整的数据描述
    
    Args:
        data: 数值数据列表
        params: 参数字典
    
    Returns:
        包含所有描述性统计量的字典
    """
    if not data:
        return {"result": None, "error": "Empty data"}
    
    try:
        # 调用各个子函数
        variance_result = variance_and_std(data, params)
        skew_kurt_result = skewness_and_kurtosis(data, params)
        mode_result = mode_analysis(data, params)
        distribution_result = distribution_analysis(data, params)
        
        # 整合结果
        result = {
            "variance_analysis": variance_result.get("result"),
            "shape_analysis": skew_kurt_result.get("result"),
            "mode_analysis": mode_result.get("result"),
            "distribution_analysis": distribution_result.get("result"),
        }
        
        return {
            "result": result,
            "algorithm": "comprehensive_stats",
            "data_size": len(data),
            "implementation": "python_composite"
        }
    except Exception as e:
        return {"result": None, "error": str(e)}


# 辅助函数
def _interpret_skewness(skewness: float) -> str:
    """解释偏度值"""
    if abs(skewness) < 0.5:
        return "approximately_symmetric"
    elif skewness > 0.5:
        return "right_skewed" 
    else:
        return "left_skewed"


def _interpret_kurtosis(kurtosis: float, method: str) -> str:
    """解释峰度值"""
    if method == "fisher":
        # Fisher定义：0为正态
        if abs(kurtosis) < 0.5:
            return "mesokurtic"  # 正态峰度
        elif kurtosis > 0.5:
            return "leptokurtic"  # 高峰度
        else:
            return "platykurtic"  # 低峰度
    else:
        # Pearson定义：3为正态
        if abs(kurtosis - 3) < 0.5:
            return "mesokurtic"
        elif kurtosis > 3.5:
            return "leptokurtic"
        else:
            return "platykurtic"


def _classify_distribution_by_modes(mode_count: int) -> str:
    """根据众数数量分类分布"""
    if mode_count == 0:
        return "no_mode"
    elif mode_count == 1:
        return "unimodal"
    elif mode_count == 2:
        return "bimodal"
    else:
        return "multimodal"


def _analyze_distribution_shape(mean: float, median: float, skewness: float, kurtosis: Optional[float]) -> Dict[str, str]:
    """分析分布形状"""
    shape_info = {
        "symmetry": _interpret_skewness(skewness),
        "central_tendency": "mean_median_close" if abs(mean - median) < 0.1 * abs(mean) else "mean_median_different"
    }
    
    if kurtosis is not None:
        shape_info["tail_weight"] = _interpret_kurtosis(kurtosis, "fisher")
    
    return shape_info


def _analyze_symmetry(mean: float, median: float, skewness: float) -> Dict[str, Any]:
    """分析对称性"""
    return {
        "mean_median_ratio": (mean - median) / median if median != 0 else None,
        "skewness_category": _interpret_skewness(skewness),
        "is_symmetric": abs(skewness) < 0.5
    }


def _analyze_tail_behavior(kurtosis: float) -> Dict[str, Any]:
    """分析尾部行为"""
    return {
        "tail_weight": _interpret_kurtosis(kurtosis, "fisher"),
        "excess_kurtosis": kurtosis,
        "heavy_tails": kurtosis > 1.0
    }


def _test_normality(data: np.ndarray) -> Dict[str, Any]:
    """简单的正态性检验"""
    try:
        if len(data) < 8:
            return {"test": "insufficient_data", "p_value": None, "is_normal": None}
        
        # Shapiro-Wilk检验 (适用于小样本)
        if len(data) <= 5000:
            statistic, p_value = stats.shapiro(data)
            test_name = "shapiro_wilk"
        else:
            # D'Agostino检验 (适用于大样本)
            statistic, p_value = stats.normaltest(data)
            test_name = "dagostino"
        
        is_normal = p_value > 0.05  # 95%置信度
        
        return {
            "test": test_name,
            "statistic": float(statistic),
            "p_value": float(p_value),
            "is_normal": is_normal,
            "confidence_level": 0.95
        }
    except Exception:
        return {"test": "failed", "p_value": None, "is_normal": None} 