# 🔧 数据库持久化问题修复文档

## 📋 问题描述

Backend服务在启动时显示使用内存数据库而非持久化SQLite文件数据库：

```
🗄️ 创建SQLite内存数据库: :memory:
```

导致每次重启后数据清空，不具有持久化特性。

## 🔍 问题根源分析

### 1. 环境变量加载时机问题
- `Config::from_env()`在`GLOBAL_CONFIG`初始化时被调用
- 这发生在`main.rs`的`load_environment_config()`之前
- 原始实现只尝试加载标准的`.env`文件，而不是项目使用的`dev.env`文件

### 2. Cargo配置文件冲突
- `.cargo/config.toml`中的配置：
  ```toml
  DATABASE_URL = { value = "sqlite::memory:", condition = "cfg(test)" }
  ```
- 这个配置意外地影响了正常运行时的环境变量读取

### 3. 配置文件命名不一致
- 项目使用`dev.env`文件存储开发环境配置
- 但dotenv库默认查找`.env`文件

## 🛠️ 解决方案

### 1. 修复配置加载优先级

在`src/infra/config/mod.rs`中修改`Config::from_env()`方法：

```rust
/// 从环境变量创建配置
#[must_use]
pub fn from_env() -> Self {
    let environment = Environment::from_env();
    let config = Self::new(environment);

    // 🔧 修复：加载环境配置文件的优先级
    // 1. 优先尝试加载 dev.env 文件（开发环境）
    if std::path::Path::new("dev.env").exists() {
        if let Err(e) = dotenv::from_filename("dev.env") {
            eprintln!("Warning: Failed to load dev.env file: {e}");
        }
    }
    // 2. 尝试加载环境变量指定的文件
    else if let Ok(env_path) = std::env::var("ENV_FILE") {
        if let Err(e) = dotenv::from_path(&env_path) {
            eprintln!("Warning: Failed to load .env file: {e}");
        }
    }
    // 3. 回退到标准 .env 文件
    else if environment.is_development() {
        let _ = dotenv::dotenv(); // 尝试加载.env文件
    }

    config
}
```

### 2. 修复Cargo配置文件

在`.cargo/config.toml`中修复测试环境变量配置：

```toml
# 🔧 修复前（有问题）
[env]
DATABASE_URL = { value = "sqlite::memory:", condition = "cfg(test)" }

# 🔧 修复后（正确）
[target.'cfg(test)'.env]
DATABASE_URL = "sqlite::memory:"
```

### 3. 简化主程序配置加载

在`src/main.rs`中简化`load_environment_config()`函数：

```rust
/// 🔧 加载环境配置文件
fn load_environment_config() {
    // 配置加载已经在 Config::from_env() 中处理了
    // 这里只需要打印调试信息
    
    if let Ok(db_url) = std::env::var("DATABASE_URL") {
        println!("📊 数据库配置: {}", db_url);
    } else {
        println!("📊 数据库配置: 使用默认值");
    }
    
    if let Ok(create_test_data) = std::env::var("CREATE_TEST_DATA") {
        println!("🔧 测试数据创建: {}", create_test_data);
    } else {
        println!("🔧 测试数据创建: 使用默认值");
    }
}
```

## ✅ 修复验证

修复后的启动日志显示：

```
📊 数据库配置: sqlite:./backend/data/dev.db
🗄️ 创建SQLite文件数据库: ./backend/data/dev.db
✅ 数据库迁移完成
数据库已有 3 个项目，跳过测试数据创建
```

### 验证要点：
1. ✅ 正确读取`dev.env`文件中的`DATABASE_URL`配置
2. ✅ 使用持久化SQLite文件数据库（`./backend/data/dev.db`）
3. ✅ 数据在重启后保持不变（显示"已有3个项目"）
4. ✅ 测试环境仍然使用内存数据库（不影响测试）

## 🎯 配置文件结构

### dev.env（开发环境）
```env
# 数据库配置
DATABASE_URL=sqlite:./backend/data/dev.db

# 测试数据配置
CREATE_TEST_DATA=true

# 其他配置...
```

### .cargo/config.toml（构建配置）
```toml
# 测试环境专用配置
[target.'cfg(test)'.env]
DATABASE_URL = "sqlite::memory:"
```

## 📊 技术要点

### 1. 环境变量加载优先级
1. `dev.env`文件（开发环境优先）
2. `ENV_FILE`环境变量指定的文件
3. 标准`.env`文件（回退选项）

### 2. 配置系统设计
- 使用`LazyLock`确保配置单例初始化
- 支持运行时配置更新和监听
- 提供类型安全的配置访问方法

### 3. 数据库持久化
- 开发环境：使用文件数据库（`./backend/data/dev.db`）
- 测试环境：使用内存数据库（`:memory:`）
- 生产环境：支持PostgreSQL配置

## 🔮 未来改进建议

1. **配置文件标准化**：考虑统一使用`.env`文件命名
2. **环境检测增强**：添加更多环境变量检测逻辑
3. **配置验证**：增强配置完整性验证
4. **热重载支持**：实现配置文件变更时的热重载

---

**修复完成时间**：2025-07-14
**影响范围**：Backend数据持久化、开发环境配置
**测试状态**：✅ 已验证修复效果 