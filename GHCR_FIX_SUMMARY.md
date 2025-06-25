# 🔐 GitHub Container Registry 权限问题 - 完整解决方案

## 🎯 问题诊断

**错误信息**: `failed to push ***:latest: denied: permission_denied: The token provided does not match expected scopes.`

**根本原因**: GitHub Actions使用的token对GitHub Container Registry的权限不足。有两种认证方式：
1. **Personal Access Token (PAT)** - 需要手动创建，权限完整
2. **GitHub Actions Token** - 自动提供，但权限有限

---

## ⚡ 完整解决方案

### 🔑 方案一：使用Personal Access Token（推荐）

#### 1️⃣ 创建PAT Token（2分钟）

1. **访问GitHub设置**：https://github.com/settings/tokens
2. **点击 "Generate new token (classic)"**
3. **配置token权限**：
   ```
   ✅ repo (Full control of private repositories)
   ✅ write:packages (Upload packages to GitHub Package Registry)  
   ✅ read:packages (Download packages from GitHub Package Registry)
   ✅ delete:packages (Delete packages from GitHub Package Registry)
   ```
4. **设置过期时间**：建议90天或无过期
5. **复制生成的token**（格式：`ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`）

#### 2️⃣ 配置GitHub Secret（1分钟）

1. **访问仓库设置**：https://github.com/hellocplusplus0/v7/settings/secrets/actions
2. **点击 "New repository secret"**
3. **添加Secret**：
   - **Name**: `GHCR_TOKEN`
   - **Secret**: 粘贴刚才的PAT token

### 🔑 方案二：使用GitHub Actions Token（备用）

如果不想创建PAT token，CI/CD配置已经包含自动回退到`GITHUB_TOKEN`的机制。但需要确保仓库设置正确：

1. **访问仓库设置** → **Actions** → **General**
2. **确保 "Workflow permissions" 设置为**：
   - ✅ "Read and write permissions"
   - ✅ "Allow GitHub Actions to create and approve pull requests"

---

## 🧪 验证配置

### 本地验证（推荐）

使用我们提供的验证脚本：

```bash
# 设置你的PAT token
export GHCR_TOKEN=ghp_your_token_here

# 运行验证脚本
./scripts/verify-github-auth.sh
```

验证脚本会检查：
- ✅ GitHub API访问权限
- ✅ GitHub Packages权限
- ✅ 容器注册表登录
- ✅ 镜像拉取权限
- ✅ 镜像推送权限
- ✅ 仓库访问权限

### 在线验证

也可以使用轻量级验证脚本：

```bash
./scripts/test-ghcr-auth.sh
```

---

## 🔧 CI/CD增强机制

我们的CI/CD配置包含完备的认证机制：

### 1. 智能认证选择
```yaml
# 自动选择最佳认证方式
- 优先使用 GHCR_TOKEN（如果配置）
- 自动回退到 GITHUB_TOKEN（备用）
- 详细的认证状态验证
```

### 2. 全面权限验证
```yaml
# 构建前验证
- Token格式检查
- 权限范围验证  
- 推送权限测试
- 镜像标签验证
```

### 3. 构建后确认
```yaml
# 构建后验证
- 镜像推送状态确认
- 镜像拉取验证
- 详细构建报告
```

---

## 🚀 立即修复步骤

### 如果你已经配置了GHCR_TOKEN：

1. **验证配置**：
   ```bash
   ./scripts/verify-github-auth.sh
   ```

2. **触发构建**：
   ```bash
   git add .
   git commit -m "fix: update GHCR authentication"
   git push origin main
   ```

3. **检查构建日志**：
   - 访问：https://github.com/hellocplusplus0/v7/actions
   - 查看最新的workflow运行状态

### 如果还没有配置GHCR_TOKEN：

1. **立即创建PAT Token**：
   - 访问：https://github.com/settings/tokens
   - 按照上面的步骤创建

2. **立即配置Secret**：
   - 访问：https://github.com/hellocplusplus0/v7/settings/secrets/actions
   - 添加 `GHCR_TOKEN` secret

3. **立即验证**：
   ```bash
   export GHCR_TOKEN=your_new_token
   ./scripts/verify-github-auth.sh
   ```

---

## 🔍 故障排除

### 常见问题1：Token权限不足
**症状**：`permission_denied: The token provided does not match expected scopes`
**解决**：
- 确保PAT token包含 `write:packages` 权限
- 重新创建token并更新Secret

### 常见问题2：Secret配置错误
**症状**：CI/CD显示认证成功但推送失败
**解决**：
- 检查Secret名称是否为 `GHCR_TOKEN`
- 确认token值没有多余的空格或换行

### 常见问题3：镜像标签错误
**症状**：`invalid reference format`
**解决**：
- CI/CD已包含镜像标签验证机制
- 检查仓库名称和用户名是否正确

### 常见问题4：网络问题
**症状**：连接超时或网络错误
**解决**：
- GitHub Actions runner网络通常正常
- 检查是否有防火墙或代理问题

---

## 📊 认证机制对比

| 认证方式 | 设置复杂度 | 权限完整性 | 安全性 | 推荐度 |
|----------|------------|------------|--------|--------|
| **PAT Token** | 简单 | 完整 | 高 | ⭐⭐⭐⭐⭐ |
| **GitHub Token** | 无需设置 | 有限 | 中等 | ⭐⭐⭐ |

---

## 📝 验证检查清单

构建成功后，确认以下项目：

- [ ] CI/CD显示认证方式（GHCR_TOKEN 或 GITHUB_TOKEN）
- [ ] 构建日志显示 "✅ 容器注册表认证成功"
- [ ] 构建日志显示 "✅ 推送权限验证成功"
- [ ] 镜像成功推送到 ghcr.io
- [ ] 构建后验证显示 "✅ 镜像推送验证成功"

---

## 🎉 成功标志

当你看到以下日志时，表示问题已完全解决：

```
🔑 认证方式: GHCR_TOKEN
✅ 容器注册表认证成功
✅ 推送权限验证成功
🦀 后端镜像: ghcr.io/hellocplusplus0/v7/backend:latest
🌐 前端镜像: ghcr.io/hellocplusplus0/v7/web:latest
✅ 后端镜像推送验证成功
✅ 前端镜像推送验证成功
🎉 所有镜像构建和推送成功！
```

---

**💡 重要提示**: 
- 推荐使用PAT Token方式，权限更完整
- 验证脚本可以快速确认配置是否正确
- CI/CD包含自动回退机制，确保最大兼容性
- 遇到问题时，先运行验证脚本诊断具体原因 