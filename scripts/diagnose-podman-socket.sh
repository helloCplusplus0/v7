#!/bin/bash

# FMOD v7 Podman Socket 诊断和修复脚本
# 专门解决容器化环境中的 Podman socket 问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 FMOD v7 Podman Socket 诊断脚本${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

echo -e "${BLUE}📋 步骤1: 基础环境检查${NC}"

# 检查 Podman 版本
if command -v podman &> /dev/null; then
    PODMAN_VERSION=$(podman --version)
    echo -e "${GREEN}✅ Podman 可用: $PODMAN_VERSION${NC}"
else
    echo -e "${RED}❌ Podman 未安装${NC}"
    exit 1
fi

# 检查系统信息
echo -e "${BLUE}🖥️  系统信息:${NC}"
echo "  操作系统: $(lsb_release -d 2>/dev/null | cut -f2 || echo "未知")"
echo "  内核版本: $(uname -r)"
echo "  当前用户: $(whoami)"
echo "  用户组: $(groups)"

echo ""
echo -e "${BLUE}📋 步骤2: Podman Socket 状态诊断${NC}"

# 检查各种可能的 socket 位置
SOCKET_LOCATIONS=(
    "/run/podman/podman.sock"
    "/run/user/$(id -u)/podman/podman.sock"
    "/tmp/podman-run-$(id -u)/podman/podman.sock"
    "/var/run/podman/podman.sock"
)

echo -e "${BLUE}🔍 检查 Socket 文件位置...${NC}"
FOUND_SOCKET=""
for socket in "${SOCKET_LOCATIONS[@]}"; do
    if [ -S "$socket" ]; then
        echo -e "${GREEN}✅ 找到 Socket: $socket${NC}"
        FOUND_SOCKET="$socket"
        break
    else
        echo -e "${YELLOW}⚠️  Socket 不存在: $socket${NC}"
    fi
done

if [ -n "$FOUND_SOCKET" ]; then
    echo -e "${GREEN}✅ 可用的 Podman Socket: $FOUND_SOCKET${NC}"
    
    # 检查权限
    echo -e "${BLUE}🔍 检查 Socket 权限...${NC}"
    ls -la "$FOUND_SOCKET"
    
    # 测试访问
    echo -e "${BLUE}🧪 测试 Socket 访问...${NC}"
    if timeout 5 podman --remote --url "unix://$FOUND_SOCKET" version >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Socket 访问正常${NC}"
        SOCKET_WORKING=true
    else
        echo -e "${RED}❌ Socket 访问失败${NC}"
        SOCKET_WORKING=false
    fi
else
    echo -e "${YELLOW}⚠️  未找到可用的 Podman Socket${NC}"
    SOCKET_WORKING=false
fi

echo ""
echo -e "${BLUE}📋 步骤3: 服务状态检查${NC}"

# 检查系统级服务
echo -e "${BLUE}🔍 检查系统级 Podman 服务...${NC}"
if systemctl is-active --quiet podman.socket 2>/dev/null; then
    echo -e "${GREEN}✅ 系统级 podman.socket 运行中${NC}"
    SYSTEM_SOCKET_ACTIVE=true
else
    echo -e "${YELLOW}⚠️  系统级 podman.socket 未运行${NC}"
    SYSTEM_SOCKET_ACTIVE=false
fi

# 检查用户级服务
echo -e "${BLUE}🔍 检查用户级 Podman 服务...${NC}"
if systemctl --user is-active --quiet podman.socket 2>/dev/null; then
    echo -e "${GREEN}✅ 用户级 podman.socket 运行中${NC}"
    USER_SOCKET_ACTIVE=true
else
    echo -e "${YELLOW}⚠️  用户级 podman.socket 未运行${NC}"
    USER_SOCKET_ACTIVE=false
fi

echo ""
echo -e "${BLUE}📋 步骤4: 智能修复策略${NC}"

if [ "$SOCKET_WORKING" = true ]; then
    echo -e "${GREEN}✅ Socket 工作正常，无需修复${NC}"
    
    echo ""
    echo -e "${BLUE}📋 建议的 Gitea Runner 配置:${NC}"
    echo -e "${GREEN}使用 Socket: $FOUND_SOCKET${NC}"
    
    # 生成修复后的命令
    cat > gitea-runner-fix-commands.sh << EOF
#!/bin/bash
# 自动生成的 Gitea Runner 修复命令

# 停止现有容器
podman stop gitea-runner-sqlite 2>/dev/null || true
podman rm gitea-runner-sqlite 2>/dev/null || true

# 使用发现的工作 Socket 重新创建 Runner
podman run -d \\
  --name gitea-runner-sqlite \\
  --restart unless-stopped \\
  -v $FOUND_SOCKET:/var/run/docker.sock:Z \\
  -v gitea-runner-data:/data \\
  -e GITEA_INSTANCE_URL="http://localhost:8081" \\
  --network container:gitea-sqlite \\
  docker.io/gitea/act_runner:nightly

echo "✅ Gitea Runner 已使用工作的 Socket 重新创建"
EOF
    
    chmod +x gitea-runner-fix-commands.sh
    echo -e "${GREEN}📄 已生成修复命令脚本: gitea-runner-fix-commands.sh${NC}"
    
else
    echo -e "${YELLOW}🔧 需要修复 Podman Socket...${NC}"
    
    # 修复策略1：启动用户级服务
    if [ "$USER_SOCKET_ACTIVE" = false ]; then
        echo -e "${BLUE}🔧 策略1: 启动用户级 Podman Socket...${NC}"
        
        if systemctl --user enable --now podman.socket 2>/dev/null; then
            echo -e "${GREEN}✅ 用户级 socket 启动成功${NC}"
            sleep 3
            
            # 重新检查
            USER_SOCKET_PATH="/run/user/$(id -u)/podman/podman.sock"
            if [ -S "$USER_SOCKET_PATH" ]; then
                echo -e "${GREEN}✅ 用户级 Socket 创建成功: $USER_SOCKET_PATH${NC}"
                FOUND_SOCKET="$USER_SOCKET_PATH"
                SOCKET_WORKING=true
            fi
        else
            echo -e "${YELLOW}⚠️  用户级 socket 启动失败${NC}"
        fi
    fi
    
    # 修复策略2：如果用户级失败，尝试系统级
    if [ "$SOCKET_WORKING" = false ] && [ "$SYSTEM_SOCKET_ACTIVE" = false ]; then
        echo -e "${BLUE}🔧 策略2: 启动系统级 Podman Socket...${NC}"
        
        echo -e "${YELLOW}需要 sudo 权限来启动系统级服务...${NC}"
        if sudo systemctl enable --now podman.socket 2>/dev/null; then
            echo -e "${GREEN}✅ 系统级 socket 启动成功${NC}"
            sleep 3
            
            # 重新检查
            if [ -S "/run/podman/podman.sock" ]; then
                echo -e "${GREEN}✅ 系统级 Socket 创建成功: /run/podman/podman.sock${NC}"
                sudo chmod 666 /run/podman/podman.sock
                FOUND_SOCKET="/run/podman/podman.sock"
                SOCKET_WORKING=true
            fi
        else
            echo -e "${YELLOW}⚠️  系统级 socket 启动失败${NC}"
        fi
    fi
    
    # 修复策略3：手动创建 socket
    if [ "$SOCKET_WORKING" = false ]; then
        echo -e "${BLUE}🔧 策略3: 手动启动 Podman 守护进程...${NC}"
        
        # 创建用户运行时目录
        mkdir -p "/run/user/$(id -u)/podman"
        
        # 尝试手动启动 podman 系统服务
        echo -e "${YELLOW}尝试手动启动 Podman 系统服务...${NC}"
        podman system service --time=0 "unix:///run/user/$(id -u)/podman/podman.sock" &
        PODMAN_SERVICE_PID=$!
        
        sleep 5
        
        if [ -S "/run/user/$(id -u)/podman/podman.sock" ]; then
            echo -e "${GREEN}✅ 手动 Socket 创建成功${NC}"
            FOUND_SOCKET="/run/user/$(id -u)/podman/podman.sock"
            SOCKET_WORKING=true
            
            echo -e "${YELLOW}注意: 这是临时解决方案，重启后需要重新运行${NC}"
            echo "Podman 服务 PID: $PODMAN_SERVICE_PID"
        else
            echo -e "${RED}❌ 手动启动也失败了${NC}"
        fi
    fi
fi

echo ""
echo -e "${BLUE}📋 步骤5: 最终结果和建议${NC}"

if [ "$SOCKET_WORKING" = true ]; then
    echo -e "${GREEN}🎉 Socket 修复成功！${NC}"
    echo -e "${GREEN}可用 Socket: $FOUND_SOCKET${NC}"
    
    echo ""
    echo -e "${BLUE}📋 现在可以运行 Gitea Runner 修复命令:${NC}"
    echo -e "${GREEN}./gitea-runner-fix-commands.sh${NC}"
    
    echo ""
    echo -e "${BLUE}📋 或者手动运行以下命令:${NC}"
    echo -e "${YELLOW}podman stop gitea-runner-sqlite${NC}"
    echo -e "${YELLOW}podman rm gitea-runner-sqlite${NC}"
    echo -e "${YELLOW}podman run -d \\\\${NC}"
    echo -e "${YELLOW}  --name gitea-runner-sqlite \\\\${NC}"
    echo -e "${YELLOW}  --restart unless-stopped \\\\${NC}"
    echo -e "${YELLOW}  -v $FOUND_SOCKET:/var/run/docker.sock:Z \\\\${NC}"
    echo -e "${YELLOW}  -v gitea-runner-data:/data \\\\${NC}"
    echo -e "${YELLOW}  -e GITEA_INSTANCE_URL=\"http://localhost:8081\" \\\\${NC}"
    echo -e "${YELLOW}  --network container:gitea-sqlite \\\\${NC}"
    echo -e "${YELLOW}  docker.io/gitea/act_runner:nightly${NC}"
    
else
    echo -e "${RED}❌ Socket 修复失败${NC}"
    echo ""
    echo -e "${BLUE}📋 替代方案建议:${NC}"
    echo -e "${YELLOW}1. 重启系统后重试${NC}"
    echo -e "${YELLOW}2. 检查 Podman 安装是否完整${NC}"
    echo -e "${YELLOW}3. 考虑使用特权模式容器${NC}"
    echo -e "${YELLOW}4. 使用宿主机直接运行 CI/CD 命令${NC}"
    
    # 生成特权模式备用方案
    cat > gitea-runner-privileged-fallback.sh << EOF
#!/bin/bash
# 特权模式备用方案

echo "🔧 使用特权模式创建 Gitea Runner..."

podman stop gitea-runner-sqlite 2>/dev/null || true
podman rm gitea-runner-sqlite 2>/dev/null || true

podman run -d \\
  --name gitea-runner-sqlite \\
  --restart unless-stopped \\
  --privileged \\
  -v gitea-runner-data:/data \\
  -e GITEA_INSTANCE_URL="http://localhost:8081" \\
  --network host \\
  docker.io/gitea/act_runner:nightly

echo "✅ 特权模式 Runner 已创建"
EOF
    
    chmod +x gitea-runner-privileged-fallback.sh
    echo -e "${GREEN}📄 已生成特权模式备用脚本: gitea-runner-privileged-fallback.sh${NC}"
fi

echo ""
echo -e "${GREEN}🎯 诊断完成！${NC}" 