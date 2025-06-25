# 🔐 GitHub Container Registry 权限问题 - 快速修复指南

## 🎯 问题诊断

**错误信息**: `failed to push ***:latest: denied: permission_denied: The token provided does not match expected scopes.`

**根本原因**: GitHub Actions使用的`GITHUB_TOKEN`对GitHub Container Registry的权限不足，需要使用具有`write:packages`权限的Personal Access Token (PAT)。

---

## ⚡ 快速修复步骤

### 1️⃣ 创建PAT Token（2分钟）

1. 访问：https://github.com/settings/tokens
2. 点击 **"Generate new token (classic)"**
3. 配置权限：
   ```
   ✅ repo
   ✅ write:packages  
   ✅ read:packages
   ✅ delete:packages
   ```
4. 复制生成的token（格式：`ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`）

### 2️⃣ 配置GitHub Secret（1分钟）

1. 访问：https://github.com/hellocplusplus0/v7/settings/secrets/actions
2. 点击 **"New repository secret"**
3. 添加Secret：
   - **Name**: `GHCR_TOKEN`
   - **Secret**: 粘贴刚才的PAT token

### 3️⃣ 验证配置（可选）

运行本地测试脚本：
```bash
cd /home/ubuntu/containers/v7
./scripts/test-ghcr-auth.sh
```

### 4️⃣ 触发CI/CD（1分钟）

```bash
cd /home/ubuntu/containers/v7

# 创建小变更触发CI/CD
echo "# GHCR Fix - $(date)" >> README.md
git add README.md
git commit -m "fix: add GHCR_TOKEN for container registry authentication"
git push origin main
```

---

## ✅ 验证成功标志

### GitHub Actions日志中应该看到：
```
✅ Login to GitHub Container Registry - 成功
✅ Build and Push Backend Image - 成功  
✅ Build and Push Web Image - 成功
✅ 没有 "permission_denied" 错误
```

### 本地验证：
```bash
# 测试拉取新构建的镜像
podman pull ghcr.io/hellocplusplus0/v7/backend:latest
podman pull ghcr.io/hellocplusplus0/v7/web:latest
```

---

## 🔧 如果问题依然存在

### 检查清单：
- [ ] PAT token包含`write:packages`权限
- [ ] GitHub Secret名称正确：`GHCR_TOKEN`
- [ ] Token格式正确（以`ghp_`开头）
- [ ] 仓库权限设置正确

### 故障排除：
1. **重新生成PAT token**：删除旧token，创建新的
2. **检查包权限**：确保packages设置为public或正确的私有权限
3. **查看详细日志**：GitHub Actions中的完整错误信息
4. **本地测试**：使用`./scripts/test-ghcr-auth.sh`验证

---

## 📋 相关文档

- **详细指南**: `docs/github-container-registry-fix.md`
- **认证测试**: `scripts/test-ghcr-auth.sh`
- **GitHub Secrets配置**: `docs/github-secrets-checklist.md`

---

**🎯 预期结果**: CI/CD可以成功推送镜像，自动化部署流程恢复正常工作。 