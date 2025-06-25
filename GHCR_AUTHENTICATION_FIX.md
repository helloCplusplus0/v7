# 🔐 GitHub Container Registry (GHCR) 认证问题修复指南

## 🚨 问题描述

在GitHub Actions CI/CD流程中遇到以下错误：

```
ERROR: failed to build: invalid tag "ghcr.io/helloCplusplus0/test:auth-check": repository name must be lowercase
```

## 🔍 根本原因分析

### 1. GHCR命名规则限制
- **GitHub Container Registry (GHCR) 要求所有仓库名称必须全部小写**
- 用户名 `helloCplusplus0` 包含大写字母 `C`，违反了GHCR的命名规范
- 这是GitHub在2021年引入的新规则，用于统一容器镜像命名规范

### 2. GitHub Actions变量映射问题
- `${{ github.actor }}` 返回原始用户名（包含大写字母）
- `${{ github.repository_owner }}` 也返回原始用户名
- 需要在CI/CD流程中进行大小写转换

## ✅ 修复方案

### 1. 核心修复策略

#### A. 用户名大小写转换
```yaml
# 在CI/CD流程中添加用户名转换步骤
- name: 🔧 Setup Registry Configuration
  id: registry-setup
  run: |
    # 将用户名转换为小写以符合GHCR要求
    REGISTRY_USER_LOWER="${{ github.repository_owner }}"
    REGISTRY_USER_LOWER=$(echo "$REGISTRY_USER_LOWER" | tr '[:upper:]' '[:lower:]')
    echo "registry-user-lower=$REGISTRY_USER_LOWER" >> $GITHUB_OUTPUT
```

#### B. 镜像标签构建
```yaml
# 使用小写用户名构建镜像地址
REGISTRY_USER_LOWER="${{ env.REGISTRY_USER_LOWER }}"
BACKEND_BASE="ghcr.io/${REGISTRY_USER_LOWER}/v7/backend"
WEB_BASE="ghcr.io/${REGISTRY_USER_LOWER}/v7/web"
```

#### C. 认证和推送分离
```yaml
# 认证使用原始用户名
echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY" -u "$REGISTRY_USER" --password-stdin

# 推送使用小写用户名构建的标签
TEST_TAG="$REGISTRY/$REGISTRY_USER_LOWER/test:auth-check"
```

### 2. 完整修复清单

#### ✅ 已修复的问题：

1. **环境变量配置**
   - 添加 `REGISTRY_USER_LOWER` 环境变量
   - 在 `environment-check` job 中添加用户名转换步骤

2. **镜像标签生成**
   - 使用小写用户名构建所有镜像标签
   - 添加大小写格式验证检查

3. **认证流程优化**
   - 认证使用原始用户名（GitHub要求）
   - 推送使用小写标签（GHCR要求）

4. **测试推送修复**
   - 测试标签使用小写用户名
   - 添加标签格式验证

5. **部署配置更新**
   - 默认镜像地址使用小写用户名
   - 添加最终格式验证

## 🎯 技术细节

### 1. GitHub Actions 最新最佳实践 (2024)

#### A. 权限配置
```yaml
permissions:
  contents: read
  packages: write    # 必需：用于推送到GHCR
  id-token: write   # 推荐：用于OIDC认证
```

#### B. 认证Token优先级
```yaml
# 优先使用专用的GHCR Token
GHCR_TOKEN > GITHUB_TOKEN
```

#### C. 镜像构建优化
```yaml
# 使用最新的Docker Buildx
- name: 🐳 Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

# 使用最新的构建推送Action
- name: 🦀 Build and Push Backend Image
  uses: docker/build-push-action@v5
```

### 2. GHCR 命名规范

#### ✅ 正确格式：
```
ghcr.io/hellocplusplus0/v7/backend:latest    # 全部小写
ghcr.io/hellocplusplus0/v7/web:latest        # 全部小写
```

#### ❌ 错误格式：
```
ghcr.io/helloCplusplus0/v7/backend:latest    # 包含大写字母
ghcr.io/HelloCplusplus0/v7/web:latest        # 包含大写字母
```

### 3. 验证检查

#### A. 编译时验证
```bash
# 检查镜像标签格式
if [[ "$BACKEND_IMAGE" =~ [A-Z] ]]; then
  echo "❌ 错误: 后端镜像标签包含大写字母: $BACKEND_IMAGE"
  exit 1
fi
```

#### B. 推送权限测试
```bash
# 使用小写标签进行测试推送
TEST_TAG="$REGISTRY/$REGISTRY_USER_LOWER/test:auth-check"
echo "FROM alpine:latest" | docker build -t "$TEST_TAG" -
docker push "$TEST_TAG"
```

## 🚀 部署验证

### 1. 本地验证步骤

```bash
# 1. 验证镜像标签格式
echo "ghcr.io/hellocplusplus0/v7/backend:latest" | grep -q '[A-Z]' && echo "包含大写字母" || echo "格式正确"

# 2. 测试镜像拉取
podman pull ghcr.io/hellocplusplus0/v7/backend:latest
podman pull ghcr.io/hellocplusplus0/v7/web:latest

# 3. 验证容器运行
podman run --rm ghcr.io/hellocplusplus0/v7/backend:latest --version
```

### 2. CI/CD 验证流程

```yaml
# 在CI/CD中添加验证步骤
- name: 🔍 Post-Build Verification
  run: |
    # 验证镜像是否成功推送
    if docker pull "$BACKEND_TAG"; then
      echo "✅ 后端镜像推送验证成功"
    else
      echo "❌ 后端镜像推送验证失败"
      exit 1
    fi
```

## 📚 相关资源

### 1. GitHub 官方文档
- [GitHub Container Registry 文档](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [GitHub Actions 权限配置](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)

### 2. Docker 最佳实践
- [Docker Build Push Action v5](https://github.com/docker/build-push-action)
- [Docker Buildx Action v3](https://github.com/docker/setup-buildx-action)

### 3. 容器镜像命名规范
- [OCI Image Spec](https://github.com/opencontainers/image-spec)
- [Docker Registry API](https://docs.docker.com/registry/spec/api/)

## 🎉 修复效果

### 修复前：
```
❌ ERROR: invalid tag "ghcr.io/helloCplusplus0/test:auth-check": repository name must be lowercase
```

### 修复后：
```
✅ 推送权限验证成功
✅ 后端镜像推送验证成功  
✅ 前端镜像推送验证成功
🎉 所有镜像构建和推送成功！
```

## 🔧 故障排除

### 常见问题：

1. **Q: 为什么认证使用原始用户名，但推送使用小写？**
   - A: GitHub认证API要求原始用户名，但GHCR存储要求小写标签

2. **Q: 是否需要修改GitHub用户名？**
   - A: 不需要，只需要在CI/CD流程中进行转换

3. **Q: 这个修复是否影响其他功能？**
   - A: 不影响，只是标准化了镜像命名规范

---

**本修复方案确保了v7项目的CI/CD流程完全符合GitHub Container Registry的最新要求，同时保持了向后兼容性。** 