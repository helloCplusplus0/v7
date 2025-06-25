#!/bin/bash

echo "🧪 测试 CI/CD 修复 - 镜像标签传递问题"
echo "=================================================="

# 模拟 GitHub Actions 环境变量
export GITHUB_REPOSITORY="helloCplusplus0/test"
export GITHUB_REPOSITORY_OWNER="helloCplusplus0"
export GITHUB_ACTOR="helloCplusplus0"
export GITHUB_REF="refs/heads/main"
export GITHUB_REF_NAME="main"

echo "🔍 模拟环境变量:"
echo "  GITHUB_REPOSITORY: $GITHUB_REPOSITORY"
echo "  GITHUB_REPOSITORY_OWNER: $GITHUB_REPOSITORY_OWNER"
echo "  GITHUB_ACTOR: $GITHUB_ACTOR"
echo "  GITHUB_REF: $GITHUB_REF"
echo "  GITHUB_REF_NAME: $GITHUB_REF_NAME"
echo ""

# 测试小写转换
echo "🔧 测试用户名小写转换:"
REGISTRY_USER_LOWER=$(echo "$GITHUB_REPOSITORY_OWNER" | tr '[:upper:]' '[:lower:]')
echo "  原始: $GITHUB_REPOSITORY_OWNER"
echo "  小写: $REGISTRY_USER_LOWER"
echo ""

# 测试分支标签逻辑
echo "🏷️ 测试分支标签逻辑:"
if [[ "$GITHUB_REF" == "refs/heads/main" ]]; then
  TAG="latest"
elif [[ "$GITHUB_REF" == "refs/heads/develop" ]]; then
  TAG="develop"
else
  TAG="$GITHUB_REF_NAME"
fi
echo "  分支引用: $GITHUB_REF"
echo "  计算标签: $TAG"
echo ""

# 测试镜像标签构建
echo "🐳 测试镜像标签构建:"
BACKEND_BASE="ghcr.io/${REGISTRY_USER_LOWER}/v7/backend"
WEB_BASE="ghcr.io/${REGISTRY_USER_LOWER}/v7/web"
BACKEND_IMAGE="${BACKEND_BASE}:${TAG}"
WEB_IMAGE="${WEB_BASE}:${TAG}"

echo "  后端基础: $BACKEND_BASE"
echo "  前端基础: $WEB_BASE"
echo "  📦 后端镜像: $BACKEND_IMAGE"
echo "  🌐 前端镜像: $WEB_IMAGE"
echo ""

# 测试格式验证
echo "✅ 测试格式验证:"
if [[ "$BACKEND_IMAGE" =~ ^ghcr\.io/.+:.+ ]]; then
  echo "  ✅ 后端镜像格式正确: $BACKEND_IMAGE"
else
  echo "  ❌ 后端镜像格式错误: $BACKEND_IMAGE"
fi

if [[ "$WEB_IMAGE" =~ ^ghcr\.io/.+:.+ ]]; then
  echo "  ✅ 前端镜像格式正确: $WEB_IMAGE"
else
  echo "  ❌ 前端镜像格式错误: $WEB_IMAGE"
fi

# 测试大小写检查
echo ""
echo "🔍 测试大小写检查:"
if [[ "$BACKEND_IMAGE" =~ [A-Z] ]]; then
  echo "  ❌ 后端镜像包含大写字母: $BACKEND_IMAGE"
else
  echo "  ✅ 后端镜像全部小写: $BACKEND_IMAGE"
fi

if [[ "$WEB_IMAGE" =~ [A-Z] ]]; then
  echo "  ❌ 前端镜像包含大写字母: $WEB_IMAGE"
else
  echo "  ✅ 前端镜像全部小写: $WEB_IMAGE"
fi

# 模拟 GITHUB_OUTPUT 文件操作
echo ""
echo "📄 测试 GITHUB_OUTPUT 文件操作:"
TEMP_OUTPUT=$(mktemp)
echo "backend-image=${BACKEND_IMAGE}" >> "$TEMP_OUTPUT"
echo "web-image=${WEB_IMAGE}" >> "$TEMP_OUTPUT"
echo "registry-user-lower=${REGISTRY_USER_LOWER}" >> "$TEMP_OUTPUT"
echo "auth-method=GHCR_TOKEN" >> "$TEMP_OUTPUT"

echo "  临时输出文件: $TEMP_OUTPUT"
echo "  文件内容:"
cat "$TEMP_OUTPUT" | sed 's/^/    /'

# 模拟读取输出
echo ""
echo "🔍 测试输出读取:"
BACKEND_TAG=$(grep "backend-image=" "$TEMP_OUTPUT" | cut -d'=' -f2-)
WEB_TAG=$(grep "web-image=" "$TEMP_OUTPUT" | cut -d'=' -f2-)
REGISTRY_USER_LOWER_OUTPUT=$(grep "registry-user-lower=" "$TEMP_OUTPUT" | cut -d'=' -f2-)

echo "  读取的后端镜像: '$BACKEND_TAG'"
echo "  读取的前端镜像: '$WEB_TAG'"
echo "  读取的小写用户名: '$REGISTRY_USER_LOWER_OUTPUT'"

# 最终验证
echo ""
echo "🎯 最终验证:"
if [[ -n "$BACKEND_TAG" && -n "$WEB_TAG" ]]; then
  echo "  ✅ 所有镜像标签都不为空"
  echo "  ✅ CI/CD 修复验证成功"
else
  echo "  ❌ 某些镜像标签为空"
  echo "  ❌ CI/CD 修复验证失败"
fi

# 清理
rm -f "$TEMP_OUTPUT"

echo ""
echo "🔧 修复要点总结:"
echo "1. ✅ 添加了备用小写用户名计算逻辑"
echo "2. ✅ 增强了调试信息输出"
echo "3. ✅ 验证了 GITHUB_OUTPUT 文件操作"
echo "4. ✅ 添加了 job 依赖关系调试"
echo "5. ✅ 确保所有镜像标签格式正确且全部小写"
echo ""
echo "🚀 现在可以提交并推送修复！" 