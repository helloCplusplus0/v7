# 🔐 GitHub Container Registry (GHCR) 认证问题完整解决方案

## 📋 问题概述

**错误现象**：
```
Error: initializing source docker://ghcr.io/hellocplusplus0/v7/backend:latest: 
Requesting bearer token: invalid status code from registry 403 (Forbidden)
```

**根本原因**：
- CI/CD流程中GitHub Actions可以成功推送镜像到GHCR
- 但服务器在拉取镜像时缺少认证token，无法从私有仓库拉取镜像
- GHCR默认将个人仓库设置为私有，需要认证才能访问

## 🔍 问题分析

### 1. 认证流程差异

| 阶段 | 环境 | 认证状态 | 说明 |
|------|------|----------|------|
| **推送** | GitHub Actions | ✅ 已认证 | 使用 `GITHUB_TOKEN` 或 `GHCR_TOKEN` |
| **拉取** | 目标服务器 | ❌ 未认证 | 缺少认证token |

### 2. GHCR权限模型

```
ghcr.io/USERNAME/REPOSITORY:TAG
└── 私有仓库（默认）
    ├── 推送权限：需要 write:packages
    └── 拉取权限：需要 read:packages
```

## ✅ 完整解决方案

### 1. 🔧 服务器端认证增强

**文件**：`v7/scripts/deploy.sh`

添加了多层认证机制：

```bash
# 🔐 容器注册表认证
authenticate_registry() {
    step "认证容器注册表..."
    
    # 检查是否已经认证
    if podman login ghcr.io --get-login 2>/dev/null | grep -q "hellocplusplus0"; then
        log "已经认证到GHCR"
        return 0
    fi
    
    # 尝试多种认证方式
    local auth_success=false
    
    # 方式1: 使用环境变量中的token
    if [[ -n "${GHCR_TOKEN:-}" ]]; then
        info "尝试使用GHCR_TOKEN认证..."
        if echo "$GHCR_TOKEN" | podman login ghcr.io -u hellocplusplus0 --password-stdin; then
            log "使用GHCR_TOKEN认证成功"
            auth_success=true
        else
            warn "GHCR_TOKEN认证失败"
        fi
    fi
    
    # 方式2: 使用GitHub Token
    if [[ "$auth_success" != "true" && -n "${GITHUB_TOKEN:-}" ]]; then
        info "尝试使用GITHUB_TOKEN认证..."
        if echo "$GITHUB_TOKEN" | podman login ghcr.io -u hellocplusplus0 --password-stdin; then
            log "使用GITHUB_TOKEN认证成功"
            auth_success=true
        else
            warn "GITHUB_TOKEN认证失败"
        fi
    fi
    
    # 方式3: 检查本地保存的认证信息
    if [[ "$auth_success" != "true" ]]; then
        info "检查本地保存的认证信息..."
        if podman login ghcr.io --get-login >/dev/null 2>&1; then
            log "使用本地保存的认证信息"
            auth_success=true
        fi
    fi
    
    # 方式4: 从文件读取token
    local token_file="$HOME/.ghcr_token"
    if [[ "$auth_success" != "true" && -f "$token_file" ]]; then
        info "尝试从文件读取token: $token_file"
        if GHCR_TOKEN=$(cat "$token_file") && [[ -n "$GHCR_TOKEN" ]]; then
            if echo "$GHCR_TOKEN" | podman login ghcr.io -u hellocplusplus0 --password-stdin; then
                log "使用文件token认证成功"
                auth_success=true
            fi
        fi
    fi
    
    if [[ "$auth_success" != "true" ]]; then
        error "容器注册表认证失败"
        echo ""
        echo "🔧 解决方案："
        echo "1. 设置环境变量 GHCR_TOKEN 或 GITHUB_TOKEN"
        echo "2. 手动执行: podman login ghcr.io -u hellocplusplus0"
        echo "3. 将token保存到文件: ~/.ghcr_token"
        echo ""
        echo "📝 获取token方法："
        echo "1. 访问 https://github.com/settings/tokens"
        echo "2. 创建Personal Access Token"
        echo "3. 勾选权限: write:packages, read:packages"
        echo ""
        return 1
    fi
    
    # 验证认证状态
    if podman login ghcr.io --get-login 2>/dev/null | grep -q "hellocplusplus0"; then
        log "容器注册表认证验证成功"
    else
        error "认证验证失败"
        return 1
    fi
}
```

### 2. 🚀 CI/CD流程增强

**文件**：`v7/.github/workflows/ci-cd.yml`

#### A. 认证设置步骤

```yaml
- name: 🔐 Setup Container Registry Authentication
  run: |
    echo "🔐 在服务器上配置容器注册表认证..."
    
    # 创建认证脚本，使用GitHub Token
    cat > setup-auth.sh << 'SCRIPT_EOF'
    #!/bin/bash
    echo "🔐 配置GitHub Container Registry认证..."
    
    # 使用GitHub Token进行认证
    GHCR_TOKEN="${GITHUB_TOKEN}"
    REGISTRY_USER="hellocplusplus0"
    
    if [[ -n "$GHCR_TOKEN" ]]; then
      echo "🔑 使用GitHub Token认证GHCR..."
      echo "$GHCR_TOKEN" | podman login ghcr.io -u "$REGISTRY_USER" --password-stdin
      if [[ $? -eq 0 ]]; then
        echo "✅ GitHub Container Registry认证成功"
        
        # 验证认证状态
        if podman login ghcr.io --get-login 2>/dev/null | grep -q "$REGISTRY_USER"; then
          echo "✅ 认证状态验证成功"
        else
          echo "⚠️ 认证状态验证异常，但继续执行"
        fi
      else
        echo "❌ GitHub Container Registry认证失败"
        exit 1
      fi
    else
      echo "❌ 缺少GITHUB_TOKEN，无法认证"
      exit 1
    fi
    SCRIPT_EOF
    
    chmod +x setup-auth.sh
    
    # 上传认证脚本
    scp -i ~/.ssh/id_rsa -P ${{ secrets.SERVER_PORT || 22 }} -o StrictHostKeyChecking=no \
      setup-auth.sh \
      ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_HOST }}:${{ secrets.DEPLOY_PATH }}/
    
    # 在服务器上执行认证，传递GitHub Token
    ssh -i ~/.ssh/id_rsa -p ${{ secrets.SERVER_PORT || 22 }} -o StrictHostKeyChecking=no \
      ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_HOST }} \
      "cd ${{ secrets.DEPLOY_PATH }} && GITHUB_TOKEN='${{ secrets.GITHUB_TOKEN }}' bash setup-auth.sh"
```

#### B. 部署执行增强

```yaml
- name: 🚀 Execute Deployment
  run: |
    echo "🚀 在服务器上执行部署..."
    
    # 在服务器上执行部署，传递必要的环境变量
    ssh -i ~/.ssh/id_rsa -p ${{ secrets.SERVER_PORT || 22 }} -o StrictHostKeyChecking=no \
      ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_HOST }} \
      "cd ${{ secrets.DEPLOY_PATH }} && \
       GITHUB_TOKEN='${{ secrets.GITHUB_TOKEN }}' \
       GHCR_TOKEN='${{ secrets.GITHUB_TOKEN }}' \
       bash deploy.sh"
```

### 3. 🔑 认证机制说明

#### A. 认证优先级

1. **GHCR_TOKEN** 环境变量（最高优先级）
2. **GITHUB_TOKEN** 环境变量
3. **本地保存的认证信息**
4. **文件token** (`~/.ghcr_token`)

#### B. 认证验证

```bash
# 检查认证状态
podman login ghcr.io --get-login

# 验证能否访问私有仓库
podman pull ghcr.io/hellocplusplus0/v7/backend:latest
```

## 🛠️ 手动修复方法

### 1. 创建Personal Access Token

1. 访问 https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. 设置权限：
   - ✅ `read:packages` - 拉取容器镜像
   - ✅ `write:packages` - 推送容器镜像
4. 复制生成的token

### 2. 服务器手动认证

```bash
# 方法1: 直接登录
podman login ghcr.io -u hellocplusplus0

# 方法2: 使用token文件
echo "YOUR_TOKEN_HERE" > ~/.ghcr_token
chmod 600 ~/.ghcr_token

# 方法3: 环境变量
export GHCR_TOKEN="YOUR_TOKEN_HERE"
export GITHUB_TOKEN="YOUR_TOKEN_HERE"
```

### 3. 验证修复

```bash
# 测试认证状态
podman login ghcr.io --get-login

# 测试拉取镜像
podman pull ghcr.io/hellocplusplus0/v7/backend:latest
podman pull ghcr.io/hellocplusplus0/v7/web:latest
```

## 🔍 故障排除

### 1. 常见错误

#### A. 403 Forbidden
```
Error: initializing source docker://ghcr.io/...: 
Requesting bearer token: invalid status code from registry 403 (Forbidden)
```

**解决方案**：检查认证token是否有效，权限是否正确

#### B. 401 Unauthorized
```
Error: authenticating creds for "ghcr.io": 
invalid username/password
```

**解决方案**：检查用户名和token是否正确

#### C. 镜像不存在
```
Error: initializing source docker://ghcr.io/...: 
manifest unknown: manifest unknown
```

**解决方案**：检查镜像名称和标签是否正确

### 2. 调试命令

```bash
# 检查podman认证状态
podman login ghcr.io --get-login

# 列出本地认证信息
podman login --get-login

# 测试网络连接
curl -I https://ghcr.io/v2/

# 查看详细错误信息
podman pull ghcr.io/hellocplusplus0/v7/backend:latest --log-level=debug
```

## 📊 解决方案总结

### ✅ 修复内容

1. **服务器端认证机制** - 添加多层认证逻辑
2. **CI/CD认证传递** - 在部署时传递GitHub Token
3. **认证验证** - 确保认证成功后再拉取镜像
4. **错误处理** - 提供详细的错误信息和解决建议
5. **多种认证方式** - 支持环境变量、文件、本地保存等多种方式

### 🎯 预期效果

- ✅ 服务器能够成功认证GHCR
- ✅ 可以拉取私有仓库的容器镜像
- ✅ 部署流程不再因认证问题中断
- ✅ 提供清晰的错误诊断和修复建议

### 🔄 持续改进

1. **监控认证状态** - 定期检查token有效性
2. **自动token刷新** - 考虑实现token自动更新机制
3. **认证缓存** - 优化认证性能
4. **安全性增强** - 定期轮换token

---

## 🎉 结论

通过这次修复，我们建立了一个完整的GHCR认证体系，确保了容器镜像的安全拉取。这个解决方案不仅解决了当前的403错误，还为未来的认证问题提供了robust的处理机制。

**关键改进**：
- 🔐 多层认证机制
- 🚀 CI/CD集成认证
- 🛠️ 详细错误诊断
- 📖 完整故障排除指南

现在部署流程应该能够顺利完成，不再受到GHCR认证问题的困扰。 