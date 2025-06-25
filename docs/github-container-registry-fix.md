# 🔐 GitHub Container Registry 权限问题完整解决方案

## 🎯 问题分析

### 错误信息
```
ERROR: failed to push ***:latest: denied: permission_denied: The token provided does not match expected scopes.
```

### 根本原因
1. **Token权限不足**: `GITHUB_TOKEN` 对GitHub Packages的权限有限
2. **Scope不匹配**: 需要`write:packages`权限才能推送镜像
3. **认证配置错误**: CI/CD中的认证配置不完整

---

## 🚀 完整解决方案

### 步骤1: 创建Personal Access Token (PAT)

#### 1.1 生成新的PAT Token
1. 登录GitHub，进入 **Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. 点击 **"Generate new token (classic)"**
3. 设置以下配置：
   - **Note**: `V7 Project GHCR Access`
   - **Expiration**: `90 days` 或 `No expiration`
   - **Select scopes**: 勾选以下权限：
     ```
     ✅ repo (Full control of private repositories)
     ✅ write:packages (Upload packages to GitHub Package Registry)
     ✅ read:packages (Download packages from GitHub Package Registry)
     ✅ delete:packages (Delete packages from GitHub Package Registry)
     ```

#### 1.2 复制Token
```bash
# 示例token (请使用你自己生成的)
ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 步骤2: 配置GitHub Repository Secrets

#### 2.1 添加GHCR_TOKEN Secret
1. 进入GitHub仓库 **Settings → Secrets and variables → Actions**
2. 点击 **"New repository secret"**
3. 配置：
   - **Name**: `GHCR_TOKEN`
   - **Secret**: 粘贴刚才生成的PAT token

#### 2.2 验证其他必需Secrets
确保以下Secrets已配置：
```bash
✅ GHCR_TOKEN          # 刚才创建的PAT token
✅ SERVER_HOST         # 服务器IP: 43.134.119.134
✅ SERVER_USER         # 部署用户: deploy
✅ SERVER_SSH_KEY      # SSH私钥内容
✅ DEPLOY_PATH         # 部署路径: /home/deploy/containers/v7-project
```

### 步骤3: 修复CI/CD配置

#### 3.1 更新环境变量配置
当前CI/CD配置已经正确设置了回退机制：
```yaml
env:
  REGISTRY_PASSWORD: ${{ secrets.GHCR_TOKEN || secrets.GITHUB_TOKEN }}
```

#### 3.2 添加权限验证步骤
CI/CD中已包含认证验证：
```yaml
- name: 🔍 Verify Registry Authentication
  run: |
    echo "🔍 验证容器注册表认证..."
    echo "Registry: ${{ env.REGISTRY }}"
    echo "User: ${{ env.REGISTRY_USER }}"
```

### 步骤4: 本地测试认证

#### 4.1 本地验证PAT Token
```bash
# 使用新的PAT token测试登录
echo "你的GHCR_TOKEN" | podman login ghcr.io -u hellocplusplus0 --password-stdin

# 验证登录状态
podman login ghcr.io --get-login

# 测试推送权限（可选）
podman pull hello-world
podman tag hello-world ghcr.io/hellocplusplus0/test:latest
podman push ghcr.io/hellocplusplus0/test:latest
```

#### 4.2 清理测试镜像
```bash
# 删除测试镜像
podman rmi ghcr.io/hellocplusplus0/test:latest
```

### 步骤5: 重新触发CI/CD

#### 5.1 提交代码变更
```bash
cd /home/ubuntu/containers/v7

# 创建一个小的变更来触发CI/CD
echo "# CI/CD Fix - $(date)" >> README.md

# 提交并推送
git add README.md
git commit -m "fix: update GHCR_TOKEN for container registry authentication"
git push origin main
```

#### 5.2 监控CI/CD执行
1. 前往GitHub仓库的 **Actions** 标签页
2. 查看最新的工作流执行
3. 重点关注 **"Build & Push Containers"** 阶段

---

## 🔍 故障排除指南

### 问题1: Token仍然权限不足
**症状**: 依然收到`permission_denied`错误
**解决方案**:
```bash
# 1. 检查token权限范围
# 确保包含 write:packages 权限

# 2. 重新生成token
# 删除旧token，生成新的PAT token

# 3. 更新GitHub Secret
# 用新token替换GHCR_TOKEN
```

### 问题2: 用户名不匹配
**症状**: `authentication required` 或用户名错误
**解决方案**:
```bash
# 确认GitHub用户名
echo "GitHub用户名: hellocplusplus0"

# 检查CI/CD配置中的用户名
# 应该是: ${{ github.actor }}
```

### 问题3: 镜像推送超时
**症状**: 推送过程中超时
**解决方案**:
```bash
# 1. 检查网络连接
# 2. 重试推送
# 3. 考虑使用镜像缓存
```

### 问题4: 包可见性设置
**症状**: 包创建后无法访问
**解决方案**:
1. 前往GitHub仓库的 **Packages** 标签页
2. 找到对应的包
3. 点击 **Package settings**
4. 设置 **Visibility** 为 **Public** 或正确的私有权限

---

## 📊 验证成功的标志

### CI/CD成功指标
```bash
✅ "Login to GitHub Container Registry" 步骤成功
✅ "Build and Push Backend Image" 步骤成功  
✅ "Build and Push Web Image" 步骤成功
✅ 没有 "permission_denied" 错误
✅ 镜像成功推送到 ghcr.io
```

### 本地验证
```bash
# 1. 检查镜像是否可以拉取
podman pull ghcr.io/hellocplusplus0/v7/backend:latest
podman pull ghcr.io/hellocplusplus0/v7/web:latest

# 2. 检查镜像信息
podman inspect ghcr.io/hellocplusplus0/v7/backend:latest
```

### 服务器验证
```bash
# SSH到服务器
ssh deploy@43.134.119.134

# 检查部署状态
cd /home/deploy/containers/v7-project
podman-compose ps

# 检查服务健康
curl http://localhost:3000/health
curl http://localhost:8080/health
```

---

## 🔐 安全最佳实践

### PAT Token管理
1. **定期轮换**: 每90天更新一次token
2. **最小权限**: 只授予必需的权限
3. **监控使用**: 定期检查token使用情况
4. **及时撤销**: 不再使用时立即删除

### CI/CD安全
1. **使用Secrets**: 永远不要在代码中硬编码token
2. **权限分离**: 生产和测试环境使用不同的token
3. **审计日志**: 定期检查CI/CD执行日志
4. **失败告警**: 设置构建失败通知

---

## 📞 紧急联系方案

如果问题依然存在，请按以下顺序排查：

1. **检查GitHub Status**: https://www.githubstatus.com/
2. **验证token有效性**: 在GitHub Settings中检查token状态
3. **查看详细日志**: GitHub Actions中的完整错误日志
4. **测试本地认证**: 在本地环境测试相同的认证流程

---

**🎯 预期结果**: 
- ✅ CI/CD可以成功推送镜像到GitHub Container Registry
- ✅ 自动化部署流程完全正常工作
- ✅ 服务器可以拉取最新的容器镜像
- ✅ 整个DevOps流程端到端运行成功 