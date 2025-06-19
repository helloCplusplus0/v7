pub mod types;
pub mod interfaces;
pub mod service;
pub mod functions;

// 重导出公共API
pub use types::{LoginRequest, LoginResponse, UserSession};
pub use interfaces::AuthService;
pub use service::{JwtAuthService, MemoryUserRepository, MemoryTokenRepository};
pub use functions::{login, validate_token, get_user_id}; 