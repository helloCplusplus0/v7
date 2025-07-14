 //! MVP 统计分析切片 - 基于FMOD v7架构的数据分析功能实现
//!
//! 提供10000个随机数生成和完整统计量计算，支持gRPC与Analytics Engine通信
//! 遵循v7架构规范：静态分发 + 泛型 + Clone trait

pub mod functions;
pub mod interfaces;
pub mod service;
pub mod types;

// 重新导出公共API - 纯gRPC接口
pub use functions::{
    // 静态分发核心函数
    generate_random_data,
    calculate_statistics,
    comprehensive_analysis,
    // 便利函数
    generate_default_random_data,
    calculate_all_statistics,
    mvp_demonstration,
};
pub use interfaces::{StatisticsService, RandomDataGenerator, AnalyticsClient};
pub use service::{DefaultStatisticsService, DefaultRandomDataGenerator, GrpcAnalyticsClient};
pub use types::*;