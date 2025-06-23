#!/bin/bash
# 自动生成的 Gitea Runner 修复命令

# 停止现有容器
podman stop gitea-runner-sqlite 2>/dev/null || true
podman rm gitea-runner-sqlite 2>/dev/null || true

# 使用发现的工作 Socket 重新创建 Runner
podman run -d \
  --name gitea-runner-sqlite \
  --restart unless-stopped \
  -v /run/user/1000/podman/podman.sock:/var/run/docker.sock:Z \
  -v gitea-runner-data:/data \
  -e GITEA_INSTANCE_URL="http://localhost:8081" \
  --network container:gitea-sqlite \
  docker.io/gitea/act_runner:nightly

echo "✅ Gitea Runner 已使用工作的 Socket 重新创建"
