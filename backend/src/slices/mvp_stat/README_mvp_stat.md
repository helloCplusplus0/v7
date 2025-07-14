## backend mvp_stat 功能切片交互场景
```mermaid
sequenceDiagram
    participant a as web_mvp_stat
    participant b as backend_mvp_stat
    participant c as analytics-engine

    a->>b: 1. click 随机数按钮，生成1000个随机数
    b->>b: 2. 本地生成1000个随机数
    b-->>a: 3. 返回1000个随机数并在UI展示
    b->>c: 4. 调用analytics-engine的常规统计量算法计算这1000个随机数对应的常规统计量
    c-->>b: 5. 返回常规统计量
    b-->>a: 6. 返回常规统计量并在UI展示
```

## web,backend,analytics-engine 通信流程
```mermaid
sequenceDiagram
    participant a as web
    participant b as backend
    participant c as analytics-engine

    a->>b: 1. grpc-web 请求
    b-->>a: 2. grpc-web 回应

    a->>b: 1. grpc-web 请求
    b->>c: 2. grpc 请求
    c-->>b: 5. grpc 回应
    b-->>a: 6. grpc-web 回应
```



## 常规统计量：

平均值（Mean）
中位数（Median）
众数（Mode）

极差（Range）
方差（Variance）
标准差（Standard Deviation）
四分位距（IQR）

偏度（Skewness）
峰度（Kurtosis）

总数（Count/N）
总和（Sum）
最小值/最大值（Min/Max）
百分位数（Percentiles）