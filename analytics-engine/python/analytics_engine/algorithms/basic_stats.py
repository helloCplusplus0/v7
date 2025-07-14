"""
基础统计量算法模块

提供高效的基础统计量计算，包括：
- 均值、总和、计数
- 最小值、最大值、极差
- 基础分位数计算

设计原则：
- 使用NumPy向量化操作提升性能
- 提供类型安全的参数验证
- 支持大数据集的内存优化处理
"""

from typing import Dict, List, Any, Optional
import numpy as np
from numpy.typing import NDArray


def mean(data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
    """计算算术平均值
    
    Args:
        data: 数值数据列表
        params: 参数字典，支持:
               - method: 'arithmetic'(默认), 'geometric', 'harmonic'
    
    Returns:
        包含计算结果的字典
    """
    if not data:
        return {"result": None, "error": "Empty data"}
    
    arr = np.array(data, dtype=np.float64)
    method = params.get("method", "arithmetic")
    
    try:
        if method == "arithmetic":
            result = float(np.mean(arr))
        elif method == "geometric":
            if np.any(arr <= 0):
                return {"result": None, "error": "Geometric mean requires positive values"}
            result = float(np.exp(np.mean(np.log(arr))))
        elif method == "harmonic":
            if np.any(arr == 0):
                return {"result": None, "error": "Harmonic mean undefined for zero values"}
            result = float(len(arr) / np.sum(1.0 / arr))
        else:
            return {"result": None, "error": f"Unknown method: {method}"}
        
        return {
            "result": result,
            "algorithm": "mean",
            "method": method,
            "data_size": len(data),
            "implementation": "python_numpy"
        }
    except Exception as e:
        return {"result": None, "error": str(e)}


def basic_summary(data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
    """计算基础统计摘要
    
    Args:
        data: 数值数据列表
        params: 参数字典
    
    Returns:
        包含多个基础统计量的字典
    """
    if not data:
        return {"result": None, "error": "Empty data"}
    
    try:
        arr = np.array(data, dtype=np.float64)
        
        result = {
            "count": len(arr),
            "sum": float(np.sum(arr)),
            "mean": float(np.mean(arr)),
            "min": float(np.min(arr)),
            "max": float(np.max(arr)),
            "range": float(np.ptp(arr)),  # peak-to-peak (max - min)
        }
        
        return {
            "result": result,
            "algorithm": "basic_summary",
            "data_size": len(data),
            "implementation": "python_numpy"
        }
    except Exception as e:
        return {"result": None, "error": str(e)}


def percentiles(data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
    """计算分位数
    
    Args:
        data: 数值数据列表
        params: 参数字典，支持:
               - percentiles: 逗号分隔的分位数字符串，如 "25,50,75,90,95,99"
               - method: numpy分位数插值方法
    
    Returns:
        包含分位数结果的字典
    """
    if not data:
        return {"result": None, "error": "Empty data"}
    
    try:
        arr = np.array(data, dtype=np.float64)
        
        # 解析分位数参数
        percentiles_str = params.get("percentiles", "25,50,75,90,95,99")
        percentiles_list = [float(p) for p in percentiles_str.split(",")]
        
        # 验证分位数范围
        if any(p < 0 or p > 100 for p in percentiles_list):
            return {"result": None, "error": "Percentiles must be between 0 and 100"}
        
        method = params.get("method", "linear")
        
        # 计算分位数
        percentile_values = np.percentile(arr, percentiles_list, method=method)
        
        # 构建结果字典
        result = {}
        for p, value in zip(percentiles_list, percentile_values):
            key = f"p{int(p)}" if p == int(p) else f"p{p}"
            result[key] = float(value)
        
        return {
            "result": result,
            "algorithm": "percentiles",
            "method": method,
            "data_size": len(data),
            "implementation": "python_numpy"
        }
    except Exception as e:
        return {"result": None, "error": str(e)}


def quantiles(data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
    """计算四分位数
    
    Args:
        data: 数值数据列表
        params: 参数字典
    
    Returns:
        包含四分位数的字典
    """
    if not data:
        return {"result": None, "error": "Empty data"}
    
    try:
        arr = np.array(data, dtype=np.float64)
        
        q1, q2, q3 = np.percentile(arr, [25, 50, 75])
        iqr = q3 - q1
        
        result = {
            "q1": float(q1),      # 第一四分位数
            "q2": float(q2),      # 第二四分位数(中位数)
            "q3": float(q3),      # 第三四分位数
            "iqr": float(iqr),    # 四分位距
        }
        
        return {
            "result": result,
            "algorithm": "quantiles",
            "data_size": len(data),
            "implementation": "python_numpy"
        }
    except Exception as e:
        return {"result": None, "error": str(e)}


def count_and_sum(data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
    """计算计数和总和
    
    高效的计数和求和运算，支持大数据集
    
    Args:
        data: 数值数据列表
        params: 参数字典
    
    Returns:
        包含计数和总和的字典
    """
    if not data:
        return {"result": {"count": 0, "sum": 0.0}, "algorithm": "count_and_sum"}
    
    try:
        arr = np.array(data, dtype=np.float64)
        
        result = {
            "count": len(arr),
            "sum": float(np.sum(arr)),
        }
        
        return {
            "result": result,
            "algorithm": "count_and_sum",
            "data_size": len(data),
            "implementation": "python_numpy"
        }
    except Exception as e:
        return {"result": None, "error": str(e)}


def min_max(data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
    """计算最小值和最大值
    
    Args:
        data: 数值数据列表
        params: 参数字典
    
    Returns:
        包含最小值、最大值和极差的字典
    """
    if not data:
        return {"result": None, "error": "Empty data"}
    
    try:
        arr = np.array(data, dtype=np.float64)
        
        min_val = float(np.min(arr))
        max_val = float(np.max(arr))
        range_val = max_val - min_val
        
        result = {
            "min": min_val,
            "max": max_val,
            "range": range_val,
        }
        
        return {
            "result": result,
            "algorithm": "min_max",
            "data_size": len(data),
            "implementation": "python_numpy"
        }
    except Exception as e:
        return {"result": None, "error": str(e)} 