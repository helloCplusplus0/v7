"""
Advanced Machine Learning Algorithms

Contains Python implementations of advanced ML algorithms that are
difficult to implement efficiently in Rust or require specialized libraries.
"""

import numpy as np
from typing import Dict, List, Any, Union
import warnings

# 延迟导入，处理可能的依赖缺失
try:
    from sklearn.cluster import KMeans, DBSCAN
    from sklearn.decomposition import PCA
    from sklearn.linear_model import LinearRegression
    from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier
    from sklearn.preprocessing import StandardScaler
    from sklearn.metrics import mean_squared_error, r2_score
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False
    warnings.warn("scikit-learn not available, ML algorithms will be limited")

class AdvancedMLAlgorithms:
    """高级机器学习算法实现"""
    
    def __init__(self):
        if not SKLEARN_AVAILABLE:
            self.available = False
        else:
            self.available = True
    
    def _check_availability(self):
        """检查依赖是否可用"""
        if not self.available:
            raise RuntimeError("scikit-learn not available for ML algorithms")
    
    def kmeans_clustering(self, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """K-means聚类分析"""
        self._check_availability()
        
        # 转换数据为2D数组（假设data是1D，转为列向量）
        X = np.array(data).reshape(-1, 1)
        
        # 获取参数
        k = int(params.get("k", "3"))
        max_iter = int(params.get("max_iter", "300"))
        random_state = int(params.get("random_state", "42"))
        
        # 执行K-means
        kmeans = KMeans(n_clusters=k, max_iter=max_iter, random_state=random_state, n_init=10)
        labels = kmeans.fit_predict(X)
        centers = kmeans.cluster_centers_.flatten().tolist()
        
        # 计算轮廓系数（如果数据足够）
        silhouette_score = 0.0
        if len(set(labels)) > 1 and len(data) > k:
            try:
                from sklearn.metrics import silhouette_score as sklearn_silhouette_score
                silhouette_score = float(sklearn_silhouette_score(X, labels))
            except ImportError:
                pass
        
        return {
            "clusters": labels.tolist(),
            "centers": centers,
            "n_clusters": k,
            "inertia": float(kmeans.inertia_),
            "silhouette_score": silhouette_score,
            "n_iter": int(kmeans.n_iter_)
        }
    
    def dbscan_clustering(self, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """DBSCAN聚类分析"""
        self._check_availability()
        
        X = np.array(data).reshape(-1, 1)
        
        # 获取参数
        eps = float(params.get("eps", "0.5"))
        min_samples = int(params.get("min_samples", "5"))
        
        # 执行DBSCAN
        dbscan = DBSCAN(eps=eps, min_samples=min_samples)
        labels = dbscan.fit_predict(X)
        
        # 分析结果
        n_clusters = len(set(labels)) - (1 if -1 in labels else 0)
        n_noise = list(labels).count(-1)
        
        return {
            "clusters": labels.tolist(),
            "n_clusters": n_clusters,
            "n_noise_points": n_noise,
            "eps": eps,
            "min_samples": min_samples,
            "core_samples": dbscan.core_sample_indices_.tolist()
        }
    
    def pca_analysis(self, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """主成分分析"""
        self._check_availability()
        
        # 对于1D数据，我们创建一个简单的多维数据用于演示
        # 实际使用中应该传入多维数据
        if len(data) < 2:
            raise ValueError("PCA requires at least 2 data points")
        
        # 创建一个简单的2D数据集用于演示
        X = np.column_stack([data, np.roll(data, 1)])
        
        # 获取参数
        n_components = params.get("n_components")
        if n_components:
            n_components = int(n_components)
        else:
            n_components = min(2, X.shape[1])
        
        # 标准化数据
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)
        
        # 执行PCA
        pca = PCA(n_components=n_components)
        X_pca = pca.fit_transform(X_scaled)
        
        return {
            "transformed_data": X_pca.tolist(),
            "explained_variance_ratio": pca.explained_variance_ratio_.tolist(),
            "explained_variance": pca.explained_variance_.tolist(),
            "components": pca.components_.tolist(),
            "n_components": n_components,
            "total_variance_explained": float(sum(pca.explained_variance_ratio_))
        }
    
    def linear_regression(self, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """线性回归分析"""
        self._check_availability()
        
        if len(data) < 2:
            raise ValueError("Linear regression requires at least 2 data points")
        
        # 创建特征矩阵（时间序列索引作为X）
        X = np.arange(len(data)).reshape(-1, 1)
        y = np.array(data)
        
        # 获取参数
        fit_intercept = params.get("fit_intercept", "true").lower() == "true"
        
        # 执行线性回归
        model = LinearRegression(fit_intercept=fit_intercept)
        model.fit(X, y)
        
        # 预测
        y_pred = model.predict(X)
        
        # 计算指标
        mse = mean_squared_error(y, y_pred)
        r2 = r2_score(y, y_pred)
        
        return {
            "coefficients": model.coef_.tolist(),
            "intercept": float(model.intercept_) if fit_intercept else 0.0,
            "predictions": y_pred.tolist(),
            "mse": float(mse),
            "r2_score": float(r2),
            "rmse": float(np.sqrt(mse)),
            "fit_intercept": fit_intercept
        }
    
    def random_forest_analysis(self, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """随机森林分析"""
        self._check_availability()
        
        if len(data) < 2:
            raise ValueError("Random Forest requires at least 2 data points")
        
        # 创建特征矩阵
        X = np.arange(len(data)).reshape(-1, 1)
        y = np.array(data)
        
        # 获取参数
        n_estimators = int(params.get("n_estimators", "100"))
        max_depth = params.get("max_depth")
        if max_depth:
            max_depth = int(max_depth)
        random_state = int(params.get("random_state", "42"))
        
        # 执行随机森林回归
        model = RandomForestRegressor(
            n_estimators=n_estimators,
            max_depth=max_depth,
            random_state=random_state
        )
        model.fit(X, y)
        
        # 预测
        y_pred = model.predict(X)
        
        # 计算指标
        mse = mean_squared_error(y, y_pred)
        r2 = r2_score(y, y_pred)
        
        return {
            "predictions": y_pred.tolist(),
            "feature_importances": model.feature_importances_.tolist(),
            "n_estimators": n_estimators,
            "max_depth": max_depth,
            "mse": float(mse),
            "r2_score": float(r2),
            "rmse": float(np.sqrt(mse)),
            "oob_score": float(getattr(model, 'oob_score_', 0.0))
        } 