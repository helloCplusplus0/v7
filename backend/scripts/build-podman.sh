#!/bin/bash

# V7 Backend Podman构建脚本
# 使用Docker格式支持HEALTHCHECK

set -e

echo "🚀 构建V7 Backend镜像（Podman + Docker格式）"

# 使用Docker格式构建以支持HEALTHCHECK
podman build \
  --format docker \
  --network=host \
  -t v7-backend:latest \
  .

echo "✅ 构建完成"
echo "📊 镜像信息："
podman images | grep v7-backend

echo ""
echo "🧪 健康检查测试："
echo "   容器运行: podman run -d --name test-backend -p 3000:3000 -p 50053:50053 v7-backend:latest"
echo "   HTTP检查: curl http://localhost:3000/health"
echo "   容器检查: podman healthcheck run test-backend" 