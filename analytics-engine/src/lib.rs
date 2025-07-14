pub mod api;
pub mod core;

#[cfg(feature = "python-bridge")]
pub mod python_bridge;

// Re-export main types
pub use api::{AnalysisRequest, AnalysisResponse, AnalysisResult, AnalysisEngine};

// Re-export core functionality
pub use core::dispatcher::analyze;

// Version info
pub const VERSION: &str = env!("CARGO_PKG_VERSION"); 