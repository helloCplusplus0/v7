# GitHub Actions 配置修复指南

## 🐛 问题分析

在 `deploy-production` 阶段，环境变量 `BACKEND_IMAGE` 和 `WEB_IMAGE` 为空，导致 `podman pull ""` 失败。

## 🔧 修复方案

### 方案1：直接在 .env.production 中使用 GitHub Actions 语法

在 `.github/workflows/ci-cd.yml` 的第415行附近，将：

```yaml
# 🐳 容器镜像配置
BACKEND_IMAGE=${BACKEND_IMAGE}
WEB_IMAGE=${WEB_IMAGE}
```

修改为：

```yaml
# 🐳 容器镜像配置
BACKEND_IMAGE=${{ needs.environment-check.outputs.backend-image }}
WEB_IMAGE=${{ needs.environment-check.outputs.web-image }}
```

### 方案2：添加变量验证和默认值

在生成 .env.production 文件后，添加验证：

```bash
# 验证镜像变量不为空
if grep -q "BACKEND_IMAGE=$" .env.production; then
  echo "❌ 警告：后端镜像变量为空，使用默认值"
  sed -i 's/BACKEND_IMAGE=$/BACKEND_IMAGE=ghcr.io\/hellocplusplus0\/v7\/backend:latest/' .env.production
fi

if grep -q "WEB_IMAGE=$" .env.production; then
  echo "❌ 警告：前端镜像变量为空，使用默认值"
  sed -i 's/WEB_IMAGE=$/WEB_IMAGE=ghcr.io\/hellocplusplus0\/v7\/web:latest/' .env.production
fi
```

### 方案3：环境变量直接传递

在 `deploy.sh` 脚本中，直接传递环境变量：

```bash
# 在部署脚本中设置默认值
BACKEND_IMAGE="${BACKEND_IMAGE:-ghcr.io/hellocplusplus0/v7/backend:latest}"
WEB_IMAGE="${WEB_IMAGE:-ghcr.io/hellocplusplus0/v7/web:latest}"
```

## 🎯 推荐方案

使用方案1 + 方案2的组合，既直接使用GitHub Actions的输出，又有默认值保护。
