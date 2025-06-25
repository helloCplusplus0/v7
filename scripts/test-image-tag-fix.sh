#!/bin/bash

echo "🧪 测试镜像标签修复"
echo "==================="

# 模拟 GitHub Actions 环境变量
export GITHUB_REPOSITORY_OWNER="helloCplusplus0"
export GITHUB_REF="refs/heads/main"
export GITHUB_REF_NAME="main"

echo "🔍 模拟环境:"
echo "  GITHUB_REPOSITORY_OWNER: $GITHUB_REPOSITORY_OWNER"
echo "  GITHUB_REF: $GITHUB_REF"
echo "  GITHUB_REF_NAME: $GITHUB_REF_NAME"
echo ""

# 测试备用镜像标签构建逻辑
echo "🔧 测试备用镜像标签构建逻辑:"

# 模拟空的输出（就像CI中发生的问题）
BACKEND_TAG=""
WEB_TAG=""

echo "  初始状态:"
echo "    后端标签: '$BACKEND_TAG'"
echo "    前端标签: '$WEB_TAG'"

# 如果镜像标签为空，尝试重新构建（复制CI逻辑）
if [[ -z "$BACKEND_TAG" ]] || [[ -z "$WEB_TAG" ]]; then
  echo "⚠️ 镜像标签为空，尝试重新构建..."
  
  # 获取基础信息
  REGISTRY_USER_LOWER=""
  
  # 如果小写用户名也为空，直接计算
  if [[ -z "$REGISTRY_USER_LOWER" ]]; then
    REGISTRY_USER_LOWER="$GITHUB_REPOSITORY_OWNER"
    REGISTRY_USER_LOWER=$(echo "$REGISTRY_USER_LOWER" | tr '[:upper:]' '[:lower:]')
    echo "🔧 重新计算小写用户名: $REGISTRY_USER_LOWER"
  fi
  
  # 基于分支设置标签
  if [[ "$GITHUB_REF" == "refs/heads/main" ]]; then
    TAG="latest"
  elif [[ "$GITHUB_REF" == "refs/heads/develop" ]]; then
    TAG="develop"
  else
    TAG="$GITHUB_REF_NAME"
  fi
  
  echo "🏷️ 分支标签: $TAG"
  
  # 重新构建镜像标签
  if [[ -z "$BACKEND_TAG" ]]; then
    BACKEND_TAG="ghcr.io/${REGISTRY_USER_LOWER}/v7/backend:${TAG}"
    echo "🔧 重新构建后端标签: $BACKEND_TAG"
  fi
  
  if [[ -z "$WEB_TAG" ]]; then
    WEB_TAG="ghcr.io/${REGISTRY_USER_LOWER}/v7/web:${TAG}"
    echo "🔧 重新构建前端标签: $WEB_TAG"
  fi
fi

echo ""
echo "🔍 最终验证:"

# 最后的安全检查
if [[ -z "$BACKEND_TAG" ]]; then
  echo "❌ 致命错误：后端镜像标签为空！"
  exit 1
fi

if [[ -z "$WEB_TAG" ]]; then
  echo "❌ 致命错误：前端镜像标签为空！"
  exit 1
fi

# 验证镜像标签格式
if [[ ! "$BACKEND_TAG" =~ ^ghcr\.io/.+:.+ ]]; then
  echo "❌ 后端镜像标签格式错误: $BACKEND_TAG"
  exit 1
fi

if [[ ! "$WEB_TAG" =~ ^ghcr\.io/.+:.+ ]]; then
  echo "❌ 前端镜像标签格式错误: $WEB_TAG"
  exit 1
fi

# 验证标签不包含大写字母
if [[ "$BACKEND_TAG" =~ [A-Z] ]]; then
  echo "❌ 后端镜像标签包含大写字母: $BACKEND_TAG"
  exit 1
fi

if [[ "$WEB_TAG" =~ [A-Z] ]]; then
  echo "❌ 前端镜像标签包含大写字母: $WEB_TAG"
  exit 1
fi

echo "✅ 镜像标签验证通过"
echo "  📦 后端镜像: $BACKEND_TAG"
echo "  🌐 前端镜像: $WEB_TAG"

echo ""
echo "🎉 修复测试成功！"
echo "==================="
echo "修复要点:"
echo "1. ✅ 备用镜像标签构建逻辑"
echo "2. ✅ 用户名小写转换"
echo "3. ✅ 分支标签映射"
echo "4. ✅ 格式验证"
echo "5. ✅ 大小写检查"
echo "===================" 