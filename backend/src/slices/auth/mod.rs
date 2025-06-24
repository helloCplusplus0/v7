pub mod functions;
pub mod interfaces;
pub mod service;
pub mod types;

// 重导出公共API
pub use functions::{get_user_id, login, validate_token};
pub use interfaces::AuthService;
pub use service::{JwtAuthService, MemoryTokenRepository, MemoryUserRepository};
pub use types::{LoginRequest, LoginResponse, UserSession};
