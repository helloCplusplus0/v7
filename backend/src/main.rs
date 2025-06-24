use axum::{
    extract::{Json, Path, Query},
    http::HeaderMap,
    middleware,
    response::Html,
    routing::{delete, get, post, put},
    Router,
};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use fmod_slice::core::runtime_api_collector::{api_collection_middleware, runtime_collector};
use fmod_slice::infra::cache::MemoryCache;
use fmod_slice::infra::db::{migrations::setup_migrations, SqliteDatabase};
use fmod_slice::infra::di;
use fmod_slice::infra::http::HttpResponse;
use fmod_slice::infra::middleware::{
    cors_middleware, logging_middleware, rate_limit_middleware, security_headers_middleware,
};
use fmod_slice::slices::auth::{
    functions::{http_login, http_revoke_token, http_validate_token},
    service::{JwtAuthService, MemoryTokenRepository, MemoryUserRepository},
    types::{LoginRequest, LoginResponse, UserSession},
};
use fmod_slice::slices::mvp_crud::{
    functions::{
        http_create_item, http_delete_item, http_get_item, http_list_items, http_update_item,
    },
    interfaces::ItemRepository,
    service::{SqliteCrudService, SqliteItemRepository},
    types::{CreateItemRequest, ListItemsQuery, UpdateItemRequest},
};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // 初始化日志
    tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer())
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    // ⭐ v7服务注册 - 适配静态分发
    setup_services().await;

    // 构建应用路由
    let app = Router::new()
        .route("/", get(root))
        .route("/health", get(health_check))
        // ⭐ v7认证路由 - 完整的认证API
        .route("/api/auth/login", post(auth_login_handler))
        .route("/api/auth/validate", get(auth_validate_handler))
        .route("/api/auth/logout", post(auth_logout_handler))
        // ⭐ v7 CRUD路由 - MVP CRUD操作
        .route("/api/items", post(crud_create_handler))
        .route("/api/items", get(crud_list_handler))
        .route("/api/items/:id", get(crud_get_handler))
        .route("/api/items/:id", put(crud_update_handler))
        .route("/api/items/:id", delete(crud_delete_handler))
        // ⭐ API信息路由
        .route("/api/info", get(api_info_handler))
        // ⭐ 运行时API导出端点 - 100%准确的API文档生成
        .route("/api/runtime/export-openapi", get(runtime_export_openapi))
        .route(
            "/api/runtime/export-typescript",
            get(runtime_export_typescript),
        )
        .route("/api/runtime/export-client", get(runtime_export_client))
        .route("/api/runtime/report", get(runtime_export_report))
        .route("/api/runtime/data", get(runtime_export_data))
        // ⭐ 中间件层 - 按顺序应用（运行时收集器放在最前面）
        .layer(middleware::from_fn(api_collection_middleware))
        .layer(middleware::from_fn(security_headers_middleware))
        .layer(middleware::from_fn(rate_limit_middleware))
        .layer(middleware::from_fn(logging_middleware))
        .layer(cors_middleware());

    // 启动服务器
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;

    tracing::info!("🚀 v7架构服务器启动在 http://0.0.0.0:3000");
    tracing::info!("✅ 静态分发+泛型架构已激活");
    tracing::info!("🛡️  安全中间件已启用");
    tracing::info!("📊 请求日志记录已启用");
    tracing::info!("🌐 CORS支持已启用");
    tracing::info!("⚡ 速率限制已启用");
    tracing::info!("📋 可用API端点:");
    tracing::info!("   认证端点:");
    tracing::info!("     POST /api/auth/login    - 用户登录");
    tracing::info!("     GET  /api/auth/validate - 验证令牌");
    tracing::info!("     POST /api/auth/logout   - 用户登出");
    tracing::info!("   CRUD端点:");
    tracing::info!("     POST   /api/items       - 创建项目");
    tracing::info!("     GET    /api/items       - 列出项目");
    tracing::info!("     GET    /api/items/:id   - 获取项目");
    tracing::info!("     PUT    /api/items/:id   - 更新项目");
    tracing::info!("     DELETE /api/items/:id   - 删除项目");
    tracing::info!("   系统端点:");
    tracing::info!("     GET  /api/info          - API信息");
    tracing::info!("     GET  /health            - 健康检查");

    axum::serve(listener, app).await?;

    Ok(())
}

/// ⭐ v7服务注册 - 支持静态分发的依赖注入
async fn setup_services() {
    // 创建认证服务实例 - v7设计：直接使用具体类型，无需Arc包装
    let user_repo = MemoryUserRepository::new();
    let token_repo = MemoryTokenRepository::new();
    let auth_service = JwtAuthService::new(user_repo, token_repo);

    // 创建CRUD服务实例 - 使用真实的SQLite数据库
    let config = fmod_slice::infra::config::config();
    let database_url = config.database_url();

    let db = if database_url.starts_with("sqlite:") {
        if database_url == "sqlite::memory:" {
            let db = SqliteDatabase::memory().expect("无法创建SQLite内存数据库");
            tracing::info!("🗄️ 创建SQLite内存数据库: {}", db.file_path());
            db
        } else {
            let file_path = database_url
                .strip_prefix("sqlite:")
                .unwrap_or(&database_url);
            let db = SqliteDatabase::new(file_path).expect("无法创建SQLite文件数据库");
            tracing::info!("🗄️ 创建SQLite文件数据库: {}", db.file_path());
            db
        }
    } else {
        panic!("目前仅支持SQLite数据库");
    };

    let crud_repository = SqliteItemRepository::new(db.clone());

    // 🔧 执行数据库迁移
    let migration_manager = setup_migrations();
    if let Err(e) = migration_manager.migrate(&db).await {
        tracing::error!("数据库迁移失败: {}", e);
        panic!("无法执行数据库迁移");
    }
    tracing::info!("✅ 数据库迁移完成");

    // 🔧 只在首次启动且数据库为空时创建测试数据
    // 使用环境变量控制是否创建测试数据
    let should_create_test_data = std::env::var("CREATE_TEST_DATA")
        .map(|v| v.to_lowercase() == "true")
        .unwrap_or(false);

    match crud_repository.count().await {
        Ok(count) if count == 0 && should_create_test_data => {
            tracing::info!("数据库为空且启用测试数据创建，创建测试数据...");
            let test_items = vec![
                fmod_slice::slices::mvp_crud::types::Item::new(
                    "test-item-1".to_string(),
                    "测试项目 1".to_string(),
                    Some("这是第一个测试项目".to_string()),
                    100,
                ),
                fmod_slice::slices::mvp_crud::types::Item::new(
                    "test-item-2".to_string(),
                    "测试项目 2".to_string(),
                    Some("这是第二个测试项目".to_string()),
                    200,
                ),
                fmod_slice::slices::mvp_crud::types::Item::new(
                    "test-item-3".to_string(),
                    "测试项目 3".to_string(),
                    Some("这是第三个测试项目".to_string()),
                    300,
                ),
            ];

            for item in test_items {
                if let Err(e) = crud_repository.save(&item).await {
                    tracing::warn!("创建测试数据失败: {}", e);
                }
            }
            tracing::info!("✅ 测试数据创建完成");
        }
        Ok(0) => {
            tracing::info!("数据库为空，但未启用测试数据创建 (设置 CREATE_TEST_DATA=true 来启用)");
        }
        Ok(count) => {
            tracing::info!("数据库已有 {} 个项目，跳过测试数据创建", count);
        }
        Err(e) => {
            tracing::warn!("检查数据库项目数量失败: {}", e);
        }
    }

    let cache = MemoryCache::new();
    let crud_service = SqliteCrudService::new(crud_repository, cache);

    // 注册到DI容器
    di::register(auth_service);
    di::register(crud_service);

    tracing::info!("✅ 服务注册完成 - v7静态分发模式");
    tracing::info!("   - 认证服务: JwtAuthService");
    tracing::info!("   - CRUD服务: SqliteCrudService");
}

/// ⭐ v7 HTTP处理器 - 用户登录
async fn auth_login_handler(Json(req): Json<LoginRequest>) -> Json<HttpResponse<LoginResponse>> {
    Json(http_login(req).await)
}

/// ⭐ v7 HTTP处理器 - 验证令牌
async fn auth_validate_handler(headers: HeaderMap) -> Json<HttpResponse<UserSession>> {
    // 从Authorization头获取令牌
    let token = extract_bearer_token(&headers).unwrap_or_default();

    Json(http_validate_token(token).await)
}

/// ⭐ v7 HTTP处理器 - 用户登出
async fn auth_logout_handler(headers: HeaderMap) -> Json<HttpResponse<()>> {
    // 从Authorization头获取令牌
    let token = extract_bearer_token(&headers).unwrap_or_default();

    Json(http_revoke_token(token).await)
}

// ===== ⭐ v7 CRUD处理器 =====

/// ⭐ v7 HTTP处理器 - 创建项目
async fn crud_create_handler(
    Json(req): Json<CreateItemRequest>,
) -> impl axum::response::IntoResponse {
    http_create_item(req).await
}

/// ⭐ v7 HTTP处理器 - 获取项目
async fn crud_get_handler(Path(id): Path<String>) -> impl axum::response::IntoResponse {
    http_get_item(id).await
}

/// ⭐ v7 HTTP处理器 - 更新项目
async fn crud_update_handler(
    Path(id): Path<String>,
    Json(req): Json<UpdateItemRequest>,
) -> impl axum::response::IntoResponse {
    http_update_item(id, req).await
}

/// ⭐ v7 HTTP处理器 - 删除项目
async fn crud_delete_handler(Path(id): Path<String>) -> impl axum::response::IntoResponse {
    http_delete_item(id).await
}

/// ⭐ v7 HTTP处理器 - 列出项目
async fn crud_list_handler(
    Query(query): Query<ListItemsQuery>,
) -> impl axum::response::IntoResponse {
    http_list_items(query).await
}

/// ⭐ API信息处理器
async fn api_info_handler() -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "name": "FMOD v7 API",
        "version": "0.7.0",
        "architecture": "静态分发+泛型",
        "features": [
            "零运行时开销",
            "编译时单态化",
            "类型安全依赖注入",
            "函数式设计",
            "完整中间件支持",
            "安全头保护",
            "请求日志记录",
            "CORS支持",
            "速率限制"
        ],
        "endpoints": {
            "auth": {
                "login": "POST /api/auth/login",
                "validate": "GET /api/auth/validate",
                "logout": "POST /api/auth/logout"
            },
            "crud": {
                "create": "POST /api/items",
                "read": "GET /api/items/{id}",
                "update": "PUT /api/items/{id}",
                "delete": "DELETE /api/items/{id}",
                "list": "GET /api/items"
            },
            "system": {
                "health": "GET /health",
                "info": "GET /api/info"
            }
        },
        "middleware": [
            "CORS",
            "Security Headers",
            "Request Logging",
            "Rate Limiting"
        ]
    }))
}

/// 从请求头中提取Bearer令牌
fn extract_bearer_token(headers: &HeaderMap) -> Option<String> {
    headers
        .get("authorization")
        .and_then(|value| value.to_str().ok())
        .and_then(|auth_header| {
            auth_header
                .strip_prefix("Bearer ")
                .map(std::string::ToString::to_string)
        })
}

async fn root() -> Html<&'static str> {
    Html(
        r#"
        <h1>🚀 FMOD v7架构</h1>
        <p>静态分发+泛型架构运行正常！</p>
        <h2>🛡️ 安全特性</h2>
        <ul>
            <li>✅ CORS支持</li>
            <li>✅ 安全头保护</li>
            <li>✅ 请求日志记录</li>
            <li>✅ 速率限制</li>
        </ul>
        <h2>📋 API端点</h2>
        <h3>🔐 认证端点</h3>
        <ul>
            <li><code>POST /api/auth/login</code> - 用户登录</li>
            <li><code>GET /api/auth/validate</code> - 验证令牌</li>
            <li><code>POST /api/auth/logout</code> - 用户登出</li>
        </ul>
        <h3>📝 CRUD端点</h3>
        <ul>
            <li><code>POST /api/items</code> - 创建项目</li>
            <li><code>GET /api/items</code> - 列出项目</li>
            <li><code>GET /api/items/{id}</code> - 获取项目</li>
            <li><code>PUT /api/items/{id}</code> - 更新项目</li>
            <li><code>DELETE /api/items/{id}</code> - 删除项目</li>
        </ul>
        <h3>🔧 系统端点</h3>
        <ul>
            <li><code>GET /api/info</code> - API信息</li>
            <li><code>GET /health</code> - 健康检查</li>
        </ul>
        <h2>🔧 测试命令</h2>
        <h3>🔐 认证测试</h3>
        <pre>
# 登录
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password"}'

# 验证令牌
curl -X GET http://localhost:3000/api/auth/validate \
  -H "Authorization: Bearer YOUR_TOKEN"
        </pre>
        <h3>📝 CRUD测试</h3>
        <pre>
# 创建项目
curl -X POST http://localhost:3000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"测试项目","description":"这是一个测试项目","value":100}'

# 列出项目
curl -X GET "http://localhost:3000/api/items?limit=10&offset=0"

# 获取项目
curl -X GET http://localhost:3000/api/items/PROJECT_ID

# 更新项目
curl -X PUT http://localhost:3000/api/items/PROJECT_ID \
  -H "Content-Type: application/json" \
  -d '{"name":"更新的项目","value":200}'

# 删除项目
curl -X DELETE http://localhost:3000/api/items/PROJECT_ID
        </pre>
        <h3>🔧 系统测试</h3>
        <pre>
# 获取API信息
curl -X GET http://localhost:3000/api/info

# 健康检查
curl -X GET http://localhost:3000/health
        </pre>
    "#,
    )
}

async fn health_check() -> Html<&'static str> {
    Html(
        r#"
    <!DOCTYPE html>
    <html>
    <head>
        <title>FMOD v7 健康检查</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
            .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .status { color: #28a745; font-weight: bold; font-size: 1.2em; }
            .info { margin-top: 20px; color: #666; }
            .feature { background: #e9f7ef; padding: 10px; margin: 5px 0; border-radius: 4px; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 FMOD v7 架构</h1>
            <p class="status">✅ 服务运行正常</p>
            
            <div class="info">
                <h3>🏗️ 架构特性</h3>
                <div class="feature">⚡ 静态分发 + 泛型优化</div>
                <div class="feature">🔒 编译时类型安全</div>
                <div class="feature">🚀 零运行时开销</div>
                <div class="feature">🛡️ 完整安全中间件</div>
                <div class="feature">📊 实时API监控</div>
                
                <h3>🔗 可用端点</h3>
                <p><strong>认证API:</strong> /api/auth/login, /api/auth/validate, /api/auth/logout</p>
                <p><strong>CRUD API:</strong> /api/items (GET, POST, PUT, DELETE)</p>
                <p><strong>系统API:</strong> /api/info, /health</p>
                <p><strong>运行时导出:</strong> /api/runtime/export-openapi, /api/runtime/report</p>
            </div>
        </div>
    </body>
    </html>
    "#,
    )
}

// ===== ⭐ 运行时API导出端点处理器 =====

/// 导出OpenAPI规范（基于运行时数据）
async fn runtime_export_openapi() -> axum::response::Response {
    let openapi_spec = runtime_collector().generate_openapi();

    axum::response::Response::builder()
        .header("content-type", "application/json")
        .header("access-control-allow-origin", "*")
        .body(axum::body::Body::from(openapi_spec.to_string()))
        .unwrap()
}

/// `导出TypeScript类型定义`
async fn runtime_export_typescript() -> axum::response::Response {
    let openapi_spec = runtime_collector().generate_openapi();
    let typescript_types = generate_typescript_from_openapi(&openapi_spec);

    axum::response::Response::builder()
        .header("content-type", "text/plain; charset=utf-8")
        .header("access-control-allow-origin", "*")
        .body(axum::body::Body::from(typescript_types))
        .unwrap()
}

/// `导出TypeScript` API客户端
async fn runtime_export_client() -> axum::response::Response {
    let openapi_spec = runtime_collector().generate_openapi();
    let client_code = generate_typescript_client_from_openapi(&openapi_spec);

    axum::response::Response::builder()
        .header("content-type", "text/plain; charset=utf-8")
        .header("access-control-allow-origin", "*")
        .body(axum::body::Body::from(client_code))
        .unwrap()
}

/// 导出运行时收集报告
async fn runtime_export_report() -> axum::response::Response {
    let report = runtime_collector().generate_report();

    axum::response::Response::builder()
        .header("content-type", "text/markdown; charset=utf-8")
        .header("access-control-allow-origin", "*")
        .body(axum::body::Body::from(report))
        .unwrap()
}

/// 导出原始运行时数据
async fn runtime_export_data() -> Json<serde_json::Value> {
    Json(runtime_collector().export_data())
}

/// `从OpenAPI规范生成TypeScript类型定义`
fn generate_typescript_from_openapi(openapi: &serde_json::Value) -> String {
    let mut typescript = String::new();

    typescript.push_str("// 🎯 FMOD v7 API Types - 运行时生成，100%准确\n");
    typescript.push_str("// 生成时间: ");
    typescript.push_str(
        &chrono::Utc::now()
            .format("%Y-%m-%d %H:%M:%S UTC")
            .to_string(),
    );
    typescript.push_str("\n\n");

    // 从OpenAPI paths生成接口类型
    if let Some(paths) = openapi.get("paths").and_then(|p| p.as_object()) {
        for (path, methods) in paths {
            if let Some(methods_obj) = methods.as_object() {
                for (method, operation) in methods_obj {
                    let interface_name = format!(
                        "{}{}Response",
                        method.to_uppercase(),
                        path.replace(['/', '{', '}'], "")
                            .split_whitespace()
                            .collect::<Vec<_>>()
                            .join("")
                    );

                    typescript.push_str(&format!("// {} {}\n", method.to_uppercase(), path));

                    // 生成请求类型
                    if let Some(request_body) = operation.get("requestBody") {
                        if let Some(schema) = request_body
                            .get("content")
                            .and_then(|c| c.get("application/json"))
                            .and_then(|j| j.get("schema"))
                        {
                            let request_interface =
                                format!("{}Request", interface_name.replace("Response", ""));
                            typescript
                                .push_str(&format!("export interface {request_interface} {{\n"));

                            if let Some(properties) =
                                schema.get("properties").and_then(|p| p.as_object())
                            {
                                for (prop_name, prop_schema) in properties {
                                    let ts_type = json_schema_to_typescript_type(prop_schema);
                                    typescript.push_str(&format!("  {prop_name}: {ts_type};\n"));
                                }
                            }

                            typescript.push_str("}\n\n");
                        }
                    }

                    // 生成响应类型
                    if let Some(responses) = operation.get("responses").and_then(|r| r.as_object())
                    {
                        for (status_code, response) in responses {
                            if status_code.starts_with('2') {
                                // 只处理成功响应
                                if let Some(schema) = response
                                    .get("content")
                                    .and_then(|c| c.get("application/json"))
                                    .and_then(|j| j.get("schema"))
                                {
                                    typescript.push_str(&format!(
                                        "export interface {interface_name} {{\n"
                                    ));

                                    if let Some(properties) =
                                        schema.get("properties").and_then(|p| p.as_object())
                                    {
                                        for (prop_name, prop_schema) in properties {
                                            let ts_type =
                                                json_schema_to_typescript_type(prop_schema);
                                            typescript
                                                .push_str(&format!("  {prop_name}: {ts_type};\n"));
                                        }
                                    }

                                    typescript.push_str("}\n\n");
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 添加通用HTTP响应类型
    typescript.push_str("// 通用HTTP响应包装器\n");
    typescript.push_str("export interface HttpResponse<T> {\n");
    typescript.push_str("  status: number;\n");
    typescript.push_str("  message: string;\n");
    typescript.push_str("  data?: T;\n");
    typescript.push_str("  error?: {\n");
    typescript.push_str("    code: string;\n");
    typescript.push_str("    message: string;\n");
    typescript.push_str("    context?: string;\n");
    typescript.push_str("  };\n");
    typescript.push_str("  trace_id?: string;\n");
    typescript.push_str("  timestamp: number;\n");
    typescript.push_str("}\n\n");

    typescript
}

/// `从OpenAPI规范生成TypeScript` API客户端
fn generate_typescript_client_from_openapi(openapi: &serde_json::Value) -> String {
    let mut client = String::new();

    client.push_str("// 🎯 FMOD v7 API Client - 运行时生成，100%准确\n");
    client.push_str("// 生成时间: ");
    client.push_str(
        &chrono::Utc::now()
            .format("%Y-%m-%d %H:%M:%S UTC")
            .to_string(),
    );
    client.push_str("\n\n");

    client.push_str("import { HttpResponse } from './types/api';\n\n");

    client.push_str("export class ApiClient {\n");
    client.push_str("  private baseUrl: string;\n");
    client.push_str("  private headers: Record<string, string>;\n\n");

    client.push_str("  constructor(baseUrl: string = 'http://localhost:3000') {\n");
    client.push_str("    this.baseUrl = baseUrl;\n");
    client.push_str("    this.headers = {\n");
    client.push_str("      'Content-Type': 'application/json',\n");
    client.push_str("    };\n");
    client.push_str("  }\n\n");

    client.push_str("  setAuthToken(token: string) {\n");
    client.push_str("    this.headers['Authorization'] = `Bearer ${token}`;\n");
    client.push_str("  }\n\n");

    client.push_str("  private async request<T>(method: string, path: string, body?: any): Promise<HttpResponse<T>> {\n");
    client.push_str("    const response = await fetch(`${this.baseUrl}${path}`, {\n");
    client.push_str("      method,\n");
    client.push_str("      headers: this.headers,\n");
    client.push_str("      body: body ? JSON.stringify(body) : undefined,\n");
    client.push_str("    });\n\n");
    client.push_str("    return response.json();\n");
    client.push_str("  }\n\n");

    // 从OpenAPI paths生成方法
    if let Some(paths) = openapi.get("paths").and_then(|p| p.as_object()) {
        for (path, methods) in paths {
            if let Some(methods_obj) = methods.as_object() {
                for (method, operation) in methods_obj {
                    let method_name = format!(
                        "{}{}",
                        method.to_lowercase(),
                        path.replace("/api/", "")
                            .replace('/', "_")
                            .replace(['{', '}'], "")
                            .split('_')
                            .map(|s| {
                                let mut chars = s.chars();
                                match chars.next() {
                                    None => String::new(),
                                    Some(first) => {
                                        first.to_uppercase().collect::<String>() + chars.as_str()
                                    }
                                }
                            })
                            .collect::<String>()
                    );

                    let has_request_body = operation.get("requestBody").is_some();
                    let path_with_params = path.replace("{id}", "${id}");

                    if path.contains("{id}") {
                        if has_request_body {
                            client.push_str(&format!("  async {method_name}(id: string, data: any): Promise<HttpResponse<any>> {{\n"));
                            client.push_str(&format!(
                                "    return this.request('{}', `{}`, data);\n",
                                method.to_uppercase(),
                                path_with_params
                            ));
                        } else {
                            client.push_str(&format!(
                                "  async {method_name}(id: string): Promise<HttpResponse<any>> {{\n"
                            ));
                            client.push_str(&format!(
                                "    return this.request('{}', `{}`);\n",
                                method.to_uppercase(),
                                path_with_params
                            ));
                        }
                    } else if has_request_body {
                        client.push_str(&format!(
                            "  async {method_name}(data: any): Promise<HttpResponse<any>> {{\n"
                        ));
                        client.push_str(&format!(
                            "    return this.request('{}', '{}', data);\n",
                            method.to_uppercase(),
                            path
                        ));
                    } else {
                        client.push_str(&format!(
                            "  async {method_name}(): Promise<HttpResponse<any>> {{\n"
                        ));
                        client.push_str(&format!(
                            "    return this.request('{}', '{}');\n",
                            method.to_uppercase(),
                            path
                        ));
                    }
                    client.push_str("  }\n\n");
                }
            }
        }
    }

    client.push_str("}\n\n");
    client.push_str("export const apiClient = new ApiClient();\n");

    client
}

/// 将JSON `Schema类型转换为TypeScript类型`
fn json_schema_to_typescript_type(schema: &serde_json::Value) -> String {
    match schema.get("type").and_then(|t| t.as_str()) {
        Some("string") => "string".to_string(),
        Some("number") => "number".to_string(),
        Some("integer") => "number".to_string(),
        Some("boolean") => "boolean".to_string(),
        Some("array") => {
            if let Some(items) = schema.get("items") {
                format!("{}[]", json_schema_to_typescript_type(items))
            } else {
                "any[]".to_string()
            }
        }
        Some("object") => {
            if let Some(properties) = schema.get("properties").and_then(|p| p.as_object()) {
                let mut obj_type = String::from("{\n");
                for (prop_name, prop_schema) in properties {
                    let ts_type = json_schema_to_typescript_type(prop_schema);
                    obj_type.push_str(&format!("    {prop_name}: {ts_type};\n"));
                }
                obj_type.push_str("  }");
                obj_type
            } else {
                "object".to_string()
            }
        }
        _ => "any".to_string(),
    }
}
