name: FMOD v7 容器化环境 CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

env:
  PROJECT_NAME: fmod-v7

jobs:
  # 代码质量检查（不需要容器）
  quality-check:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          cache-dependency-path: web/package-lock.json

      # 后端代码检查
      - name: Rust Format Check
        run: |
          cd backend
          cargo fmt --check

      - name: Rust Clippy
        run: |
          cd backend
          cargo clippy --all-targets --all-features -- -D warnings

      # 前端代码检查
      - name: Install Frontend Dependencies
        run: |
          cd web
          npm ci

      - name: TypeScript Check
        run: |
          cd web
          npm run type-check

      - name: Frontend Lint
        run: |
          cd web
          npm run lint

  # 测试阶段
  test:
    runs-on: ubuntu-latest
    needs: quality-check
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Rust
        uses: dtolnay/rust-toolchain@stable

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          cache-dependency-path: web/package-lock.json

      # 后端测试
      - name: Run Backend Tests
        run: |
          cd backend
          cargo test --verbose

      # 前端测试
      - name: Install Frontend Dependencies
        run: |
          cd web
          npm ci

      - name: Run Frontend Tests
        run: |
          cd web
          npm run test

  # 容器化部署
  deploy:
    runs-on: ubuntu-latest
    needs: [quality-check, test]
    if: github.event_name == 'push' && (github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop')
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure Container Runtime
        run: |
          echo "🔧 配置容器运行时环境..."
          
          # 检测可用的容器运行时
          if command -v podman &> /dev/null; then
            echo "✅ 检测到 Podman"
            export CONTAINER_CMD="podman"
            export CONTAINER_RUNTIME="podman"
          elif command -v docker &> /dev/null; then
            echo "✅ 检测到 Docker"
            export CONTAINER_CMD="docker"
            export CONTAINER_RUNTIME="docker"
          else
            echo "❌ 未找到容器运行时，尝试安装 Podman..."
            sudo apt-get update && sudo apt-get install -y podman
            export CONTAINER_CMD="podman"
            export CONTAINER_RUNTIME="podman"
          fi
          
          echo "CONTAINER_CMD=$CONTAINER_CMD" >> $GITHUB_ENV
          echo "CONTAINER_RUNTIME=$CONTAINER_RUNTIME" >> $GITHUB_ENV

      - name: Smart Port Detection and Container Deployment
        run: |
          echo "🚀 开始智能端口管理部署..."
          
          # 使用环境变量中的容器命令
          CONTAINER_CMD="${CONTAINER_CMD:-podman}"
          
          # 设置环境变量
          export ENVIRONMENT=${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
          
          # 智能端口检测函数
          find_available_port() {
            local start_port=$1
            local max_port=$((start_port + 100))
            
            for port in $(seq $start_port $max_port); do
              if ! ss -tulpn | grep -q ":$port "; then
                echo $port
                return 0
              fi
            done
            echo $start_port
          }
          
          # 端口配置策略
          if [ "$ENVIRONMENT" = "production" ]; then
            PREFERRED_FRONTEND_PORT=${{ vars.FRONTEND_PORT_PRODUCTION || '8080' }}
            PREFERRED_BACKEND_PORT=${{ vars.BACKEND_PORT_PRODUCTION || '3000' }}
          else
            PREFERRED_FRONTEND_PORT=${{ vars.FRONTEND_PORT_STAGING || '5173' }}
            PREFERRED_BACKEND_PORT=${{ vars.BACKEND_PORT_STAGING || '3001' }}
          fi
          
          # 智能端口分配
          FRONTEND_PORT=$(find_available_port $PREFERRED_FRONTEND_PORT)
          BACKEND_PORT=$(find_available_port $PREFERRED_BACKEND_PORT)
          
          echo "📊 端口分配结果："
          echo "  环境: $ENVIRONMENT"
          echo "  容器运行时: $CONTAINER_CMD"
          echo "  前端端口: $FRONTEND_PORT (首选: $PREFERRED_FRONTEND_PORT)"
          echo "  后端端口: $BACKEND_PORT (首选: $PREFERRED_BACKEND_PORT)"
          
          echo "🏗️ 构建镜像..."
          # 使用检测到的容器命令构建镜像
          $CONTAINER_CMD build -t fmod-backend:latest -f backend/Dockerfile backend/
          $CONTAINER_CMD build -t fmod-frontend:latest -f web/Dockerfile web/
          
          echo "🔄 安全停止旧容器..."
          # 优雅停止现有容器
          if $CONTAINER_CMD ps -q --filter name=fmod-backend-$ENVIRONMENT | grep -q .; then
            echo "停止现有后端容器..."
            $CONTAINER_CMD stop fmod-backend-$ENVIRONMENT --timeout 30 || true
            $CONTAINER_CMD rm fmod-backend-$ENVIRONMENT || true
          fi
          
          if $CONTAINER_CMD ps -q --filter name=fmod-frontend-$ENVIRONMENT | grep -q .; then
            echo "停止现有前端容器..."
            $CONTAINER_CMD stop fmod-frontend-$ENVIRONMENT --timeout 30 || true
            $CONTAINER_CMD rm fmod-frontend-$ENVIRONMENT || true
          fi
          
          echo "🚀 启动新容器..."
          # 创建数据卷（如果不存在）
          $CONTAINER_CMD volume create fmod-data-$ENVIRONMENT 2>/dev/null || true
          
          # 启动后端容器
          $CONTAINER_CMD run -d \
            --name fmod-backend-$ENVIRONMENT \
            -p $BACKEND_PORT:3000 \
            -v fmod-data-$ENVIRONMENT:/app/data \
            -e RUST_LOG=info \
            -e DATABASE_URL=sqlite:./data/prod.db \
            -e ENABLE_PERSISTENCE=true \
            -e CREATE_TEST_DATA=false \
            --restart unless-stopped \
            fmod-backend:latest
          
          # 启动前端容器
          $CONTAINER_CMD run -d \
            --name fmod-frontend-$ENVIRONMENT \
            -p $FRONTEND_PORT:80 \
            --restart unless-stopped \
            fmod-frontend:latest
          
          echo "🧪 健康检查..."
          # 等待服务启动
          sleep 10
          
          # 健康检查（最多尝试6次，每次间隔5秒）
          for i in {1..6}; do
            echo "健康检查尝试 $i/6..."
            
            # 检查后端健康状态
            if curl -f http://localhost:$BACKEND_PORT/health > /dev/null 2>&1; then
              echo "✅ 后端服务健康"
              BACKEND_HEALTHY=true
            else
              echo "⚠️  后端服务未就绪，等待..."
              BACKEND_HEALTHY=false
            fi
            
            # 检查前端服务
            if curl -f http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
              echo "✅ 前端服务健康"
              FRONTEND_HEALTHY=true
            else
              echo "⚠️  前端服务未就绪，等待..."
              FRONTEND_HEALTHY=false
            fi
            
            if [ "$BACKEND_HEALTHY" = true ] && [ "$FRONTEND_HEALTHY" = true ]; then
              echo "🎉 所有服务都已健康启动！"
              break
            fi
            
            if [ $i -eq 6 ]; then
              echo "❌ 健康检查失败，请检查容器日志"
              echo "后端日志："
              $CONTAINER_CMD logs fmod-backend-$ENVIRONMENT --tail 20
              echo "前端日志："
              $CONTAINER_CMD logs fmod-frontend-$ENVIRONMENT --tail 20
              exit 1
            fi
            
            sleep 5
          done
          
          echo "📋 部署完成报告："
          echo "  环境: $ENVIRONMENT"
          echo "  前端地址: http://localhost:$FRONTEND_PORT"
          echo "  后端地址: http://localhost:$BACKEND_PORT"
          echo "  容器运行时: $CONTAINER_CMD"
          
          # 保存端口配置
          echo "FRONTEND_PORT=$FRONTEND_PORT" > .port-config
          echo "BACKEND_PORT=$BACKEND_PORT" >> .port-config
          echo "ENVIRONMENT=$ENVIRONMENT" >> .port-config
          echo "CONTAINER_RUNTIME=$CONTAINER_CMD" >> .port-config
          
          echo "📄 端口配置已保存到 .port-config 文件"

# Gitea Runner 容器化环境 Podman 权限修复指南

## 🚨 问题描述

当 **Gitea** 和 **Gitea Actions Runner** 都运行在 Podman 容器内时，出现权限错误：
```
failed to create container: 'Error response from daemon: container create: statfs /var/run/docker.sock: permission denied'
```

**根本原因**：
- Gitea Runner 容器内尝试访问宿主机的容器运行时
- 容器间没有正确配置 Podman socket 共享
- Runner 容器缺少访问宿主机 Podman 的权限

## 📋 当前环境检查

基于你提供的容器列表：
```
32ee7be75682  docker.io/gitea/act_runner:nightly    gitea-runner-sqlite
cae41ccbc551  docker.io/gitea/gitea:1.22.2          gitea-sqlite
```

## ✅ 解决方案

### **方案一：重新配置 Gitea Runner 容器以挂载 Podman Socket**

#### 步骤1：停止并备份当前配置

```bash
# 停止当前 runner 容器
podman stop gitea-runner-sqlite

# 检查当前容器的配置（备份）
podman inspect gitea-runner-sqlite > gitea-runner-backup.json

# 可选：备份 runner 数据
podman cp gitea-runner-sqlite:/data ./gitea-runner-data-backup
```

#### 步骤2：重新启动带有正确挂载的 Runner 容器

```bash
# 删除旧容器
podman rm gitea-runner-sqlite

# 重新创建容器，挂载 Podman socket
podman run -d \
  --name gitea-runner-sqlite \
  --restart unless-stopped \
  -v /run/podman/podman.sock:/var/run/docker.sock:Z \
  -v gitea-runner-data:/data \
  -e GITEA_INSTANCE_URL="http://gitea-sqlite:3000" \
  -e GITEA_RUNNER_REGISTRATION_TOKEN="your-token-here" \
  --network container:gitea-sqlite \
  docker.io/gitea/act_runner:nightly
```

**关键配置说明**：
- `-v /run/podman/podman.sock:/var/run/docker.sock:Z` - 挂载宿主机 Podman socket
- `:Z` 标签用于 SELinux 上下文
- `--network container:gitea-sqlite` - 共享网络

### **方案二：使用 Podman-in-Podman 模式**

```bash
# 停止当前容器
podman stop gitea-runner-sqlite
podman rm gitea-runner-sqlite

# 使用特权模式运行 Runner
podman run -d \
  --name gitea-runner-sqlite \
  --restart unless-stopped \
  --privileged \
  -v /run/podman/podman.sock:/var/run/docker.sock:Z \
  -v gitea-runner-data:/data \
  -v /var/lib/containers:/var/lib/containers \
  -e GITEA_INSTANCE_URL="http://gitea-sqlite:3000" \
  -e GITEA_RUNNER_REGISTRATION_TOKEN="your-token-here" \
  --network container:gitea-sqlite \
  docker.io/gitea/act_runner:nightly
```

### **方案三：修改 CI/CD 配置使用宿主机安装的工具**

更新你的 `.gitea/workflows/ci.yml`，避免在容器内构建容器：

```yaml
# 在 deploy job 中添加
- name: Deploy via Host Podman
  run: |
    echo "🚀 使用宿主机 Podman 进行部署..."
    
    # 检查是否能访问宿主机 Podman
    if ! podman version > /dev/null 2>&1; then
      echo "❌ 无法访问宿主机 Podman"
      exit 1
    fi
    
    echo "✅ 宿主机 Podman 可访问"
    
    # 智能端口检测
    find_available_port() {
      local start_port=$1
      local max_port=$((start_port + 100))
      
      for port in $(seq $start_port $max_port); do
        if ! ss -tulpn | grep -q ":$port "; then
          echo $port
          return 0
        fi
      done
      echo $start_port
    }
    
    # 其余部署逻辑...
```

## 🔧 验证配置

### 检查 Socket 访问

```bash
# 在 Runner 容器内测试
podman exec -it gitea-runner-sqlite sh
# 在容器内运行：
ls -la /var/run/docker.sock
# 应该显示 socket 文件

# 测试容器命令
podman ps  # 或 docker ps
```

### 检查权限

```bash
# 检查 Podman socket 权限
ls -la /run/podman/podman.sock

# 如果权限不正确，修复：
sudo chmod 666 /run/podman/podman.sock
```

## 📋 完整重新配置脚本

```bash
#!/bin/bash

echo "🔧 重新配置 Gitea Runner 容器..."

# 保存当前配置
echo "📦 备份当前配置..."
podman inspect gitea-runner-sqlite > gitea-runner-backup.json 2>/dev/null || echo "无现有容器需要备份"

# 停止并删除旧容器
echo "🛑 停止旧容器..."
podman stop gitea-runner-sqlite 2>/dev/null || true
podman rm gitea-runner-sqlite 2>/dev/null || true

# 确保 Podman socket 存在且可访问
echo "🔍 检查 Podman socket..."
if [ ! -S /run/podman/podman.sock ]; then
  echo "启动 Podman socket..."
  sudo systemctl enable --now podman.socket
fi

# 设置正确权限
sudo chmod 666 /run/podman/podman.sock

# 获取 Gitea 容器信息
GITEA_IP=$(podman inspect gitea-sqlite --format='{{.NetworkSettings.IPAddress}}' 2>/dev/null || echo "localhost")

echo "🚀 启动新的 Runner 容器..."
podman run -d \
  --name gitea-runner-sqlite \
  --restart unless-stopped \
  -v /run/podman/podman.sock:/var/run/docker.sock:Z \
  -v gitea-runner-data:/data \
  -e GITEA_INSTANCE_URL="http://${GITEA_IP}:3000" \
  --network container:gitea-sqlite \
  docker.io/gitea/act_runner:nightly

echo "⏳ 等待容器启动..."
sleep 10

echo "🧪 验证配置..."
if podman exec gitea-runner-sqlite ls -la /var/run/docker.sock; then
  echo "✅ Socket 挂载成功"
else
  echo "❌ Socket 挂载失败"
  exit 1
fi

if podman exec gitea-runner-sqlite podman version > /dev/null 2>&1; then
  echo "✅ Podman 访问成功"
else
  echo "❌ Podman 访问失败"
  exit 1
fi

echo "🎉 配置完成！现在可以重新触发 CI/CD"
```

## 🚀 测试修复结果

```bash
# 运行配置脚本
chmod +x fix-gitea-runner.sh
./fix-gitea-runner.sh

# 提交代码触发 CI/CD 测试
git commit --allow-empty -m "test: 验证容器化 Runner 配置"
git push origin main
```

## 🐛 故障排除

### 问题1：Socket 权限问题
```bash
# 临时修复权限
sudo chmod 666 /run/podman/podman.sock

# 永久修复（创建 udev 规则）
echo 'SUBSYSTEM=="unix", KERNEL=="podman.sock", MODE="0666"' | sudo tee /etc/udev/rules.d/99-podman.rules
sudo udevadm control --reload-rules
```

### 问题2：SELinux 上下文问题
```bash
# 检查 SELinux 状态
getenforce

# 如果是 Enforcing，添加 SELinux 标签
sudo setsebool -P container_manage_cgroup true
```

### 问题3：网络连接问题
```bash
# 检查容器网络
podman network ls
podman inspect gitea-sqlite --format='{{.NetworkSettings}}'
```

这个解决方案专门针对你的容器化环境，应该能解决 Gitea Runner 在容器内访问宿主机 Podman 的权限问题。 