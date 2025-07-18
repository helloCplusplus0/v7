#!/bin/bash

# Analytics Engine Unified Deployment Script
# 统一部署脚本 - 支持单服务器和跨服务器部署

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
DEPLOY_USER=${DEPLOY_USER:-"analytics"}
DEPLOY_PATH=${DEPLOY_PATH:-"/opt/v7/analytics-engine"}
SERVICE_NAME="analytics-engine"
BACKUP_PATH="/opt/v7/backups/analytics-engine"

# 部署模式
ENABLE_REMOTE=false
REMOTE_HOST=""
SSH_USER="root"
SSH_PORT="22"
SSH_KEY="~/.ssh/id_rsa"
LISTEN_ADDR=""
SKIP_FIREWALL=false
DRY_RUN=false

# 显示使用说明
show_usage() {
    echo -e "${YELLOW}Usage: $0 [OPTIONS]${NC}"
    echo -e "${BLUE}Options:${NC}"
    echo -e "  --enable-remote                    Enable remote access (open firewall)"
    echo -e "  --remote-host HOSTNAME            Deploy to remote host via SSH"
    echo -e "  --ssh-user USER                   SSH user name (default: root)"
    echo -e "  --ssh-port PORT                   SSH port (default: 22)"
    echo -e "  --ssh-key PATH                    SSH key for remote deployment"
    echo -e "  --target-dir DIR                  Target directory (default: /opt/v7/analytics-engine)"
    echo -e "  --listen-addr ADDR                Listen address (default: auto-detect)"
    echo -e "  --skip-firewall                   Skip firewall configuration"
    echo -e "  --dry-run                         Simulate execution, don't actually deploy"
    echo -e "  --help                            Show this help message"
    echo -e ""
    echo -e "${BLUE}Examples:${NC}"
    echo -e "  ./deploy.sh                                   # Local deployment (auto-detect containers)"
    echo -e "  ./deploy.sh --enable-remote                  # Local with remote access"
    echo -e "  ./deploy.sh --listen-addr 0.0.0.0:50051     # Force external access"
    echo -e "  ./deploy.sh --remote-host 10.0.1.100        # Remote deployment (root user)"
    echo -e "  ./deploy.sh --remote-host 10.0.1.100 --ssh-user ubuntu # Remote deployment (ubuntu user)"
    echo -e "  ./deploy.sh --remote-host 10.0.1.100 --ssh-port 2222    # Custom SSH port"
    echo -e ""
    echo -e "${BLUE}🐳 Container Environment:${NC}"
    echo -e "  When Backend containers are detected, Analytics Engine automatically"
    echo -e "  configures to listen on 0.0.0.0:50051 to allow container connections."
    echo -e "  Backend should use environment variable:"
    echo -e "  ${GREEN}ANALYTICS_ENGINE_ADDR=http://host.containers.internal:50051${NC}"
    echo -e ""
    echo -e "${YELLOW}注意：此脚本需要适当权限来安装systemd服务${NC}"
    echo -e "${YELLOW}推荐：使用具有sudo权限的用户运行${NC}"
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --enable-remote)
                ENABLE_REMOTE=true
                shift
                ;;
            --remote-host)
                REMOTE_HOST="$2"
                shift 2
                ;;
            --ssh-user)
                SSH_USER="$2"
                shift 2
                ;;
            --ssh-port)
                SSH_PORT="$2"
                shift 2
                ;;
            --ssh-key)
                SSH_KEY="$2"
                shift 2
                ;;
            --target-dir)
                DEPLOY_PATH="$2"
                shift 2
                ;;
            --listen-addr)
                LISTEN_ADDR="$2"
                shift 2
                ;;
            --skip-firewall)
                SKIP_FIREWALL=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
}

# 检查权限
check_permissions() {
    echo -e "${BLUE}🔐 Checking deployment permissions...${NC}"
    
    local current_user=$(whoami)
    
    # 场景1：root用户（远程部署或本地root）
    if [[ $EUID -eq 0 ]]; then
        echo -e "${GREEN}✅ Running as root - full permissions${NC}"
        return 0
    fi
    
    # 场景2：有sudo权限的用户（推荐本地部署）
    if sudo -n true 2>/dev/null; then
        echo -e "${GREEN}✅ Running with sudo access - sufficient permissions${NC}"
        return 0
    fi
    
    # 场景3：analytics用户但在容器/chroot环境中
    if [[ "$current_user" == "$DEPLOY_USER" ]] && [[ -f "/.dockerenv" || -f "/run/.containerenv" ]]; then
        echo -e "${YELLOW}⚠️  Container environment detected - limited deployment${NC}"
        return 0
    fi
    
    # 场景4：权限不足
    echo -e "${RED}❌ Insufficient permissions for deployment${NC}"
    echo -e "${YELLOW}💡 Deployment options:${NC}"
    echo -e "${BLUE}   Local:  ./scripts/deploy.sh                    # (recommended)${NC}"
    echo -e "${BLUE}   Remote: ./scripts/deploy.sh --remote-host IP   # (as root/sudo user)${NC}"
    echo -e "${BLUE}   Manual: sudo ./scripts/deploy.sh               # (explicit sudo)${NC}"
    exit 1
}

# 检查构建文件
check_build() {
    echo -e "${BLUE}🔍 Checking build files...${NC}"
    
    if [[ ! -f "target/release/analytics-server" ]]; then
        echo -e "${RED}❌ Binary not found. Please run ./scripts/build.sh first${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Build files OK${NC}"
}

# 停止现有服务
stop_service() {
    echo -e "${BLUE}🛑 Stopping Analytics Engine service...${NC}"
    
    if sudo systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
        sudo systemctl stop $SERVICE_NAME
        echo -e "${GREEN}✅ Service stopped${NC}"
    else
        echo -e "${YELLOW}⚠️  Service not running${NC}"
    fi
}

# 备份当前版本
backup_current() {
    if [[ -d "$DEPLOY_PATH" ]]; then
        echo -e "${BLUE}📦 Backing up current version...${NC}"
        
        sudo mkdir -p "$BACKUP_PATH"
        BACKUP_DIR="$BACKUP_PATH/backup-$(date +%Y%m%d-%H%M%S)"
        
        sudo cp -r "$DEPLOY_PATH" "$BACKUP_DIR"
        echo -e "${GREEN}✅ Backup created: $BACKUP_DIR${NC}"
    fi
}

# 部署新版本
deploy_binary() {
    echo -e "${BLUE}🚀 Deploying new version...${NC}"
    
    # 创建部署目录
    sudo mkdir -p "$DEPLOY_PATH"/{bin,python,data,logs,config}
    
    # 复制二进制文件
    sudo cp target/release/analytics-server "$DEPLOY_PATH/bin/"
    sudo chmod +x "$DEPLOY_PATH/bin/analytics-server"
    
    # 复制Python模块
    if [[ -d "python" ]]; then
        sudo cp -r python/ "$DEPLOY_PATH/"
    fi
    
    # 复制配置文件
    if [[ -f "env.example" ]]; then
        sudo cp env.example "$DEPLOY_PATH/config/env"
    fi
    
    # 设置权限
    sudo chown -R $DEPLOY_USER:$DEPLOY_USER "$DEPLOY_PATH"
    
    echo -e "${GREEN}✅ Files deployed${NC}"
}

# 安装系统服务
install_service() {
    echo -e "${BLUE}⚙️  Installing systemd service...${NC}"
    
    # 确定监听地址 - 增强容器环境检测
    local listen_addr
    if [[ -n "$LISTEN_ADDR" ]]; then
        listen_addr="$LISTEN_ADDR"  # 使用用户指定的地址
    elif [[ "$ENABLE_REMOTE" == "true" ]] || [[ -n "$REMOTE_HOST" ]]; then
        listen_addr="0.0.0.0:50051"  # 允许外部访问
    else
        # 🐳 容器环境检测：检查是否有Backend容器需要连接
        if command -v podman &>/dev/null && podman ps --format "table {{.Names}}" | grep -q "v7-backend"; then
            echo -e "${YELLOW}🐳 检测到Backend容器运行，配置允许容器访问${NC}"
            listen_addr="0.0.0.0:50051"  # 容器环境：允许外部访问
        elif command -v docker &>/dev/null && docker ps --format "table {{.Names}}" | grep -q "v7-backend"; then
            echo -e "${YELLOW}🐳 检测到Backend容器运行，配置允许容器访问${NC}"
            listen_addr="0.0.0.0:50051"  # 容器环境：允许外部访问
        elif [[ -f "/.dockerenv" ]] || [[ -f "/run/.containerenv" ]]; then
            echo -e "${YELLOW}🐳 检测到容器环境，配置允许外部访问${NC}"
            listen_addr="0.0.0.0:50051"  # 容器环境：允许外部访问
        else
            listen_addr="127.0.0.1:50051"  # 仅本地访问
        fi
    fi
    
    # 创建临时服务文件
    local temp_service="/tmp/$SERVICE_NAME.service"
    cat > "$temp_service" << EOF
[Unit]
Description=V7 Analytics Engine - Rust+Python混合分析引擎
Documentation=https://github.com/v7-project/analytics-engine
After=network.target

[Service]
Type=simple
User=$DEPLOY_USER
Group=$DEPLOY_USER
WorkingDirectory=$DEPLOY_PATH
ExecStart=$DEPLOY_PATH/bin/analytics-server
ExecReload=/bin/kill -HUP \$MAINPID

# 环境变量
Environment=RUST_LOG=info
Environment=ANALYTICS_LISTEN_ADDR=$listen_addr
Environment=PYTHONPATH=$DEPLOY_PATH/python
Environment=PYTHONUNBUFFERED=1

# 重启策略
Restart=always
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DEPLOY_PATH/data $DEPLOY_PATH/logs

# 资源限制
LimitNOFILE=65536
MemoryMax=2G
TasksMax=4096

[Install]
WantedBy=multi-user.target
EOF

    # 使用sudo安装服务文件
    if ! sudo cp "$temp_service" "/etc/systemd/system/$SERVICE_NAME.service"; then
        echo -e "${RED}❌ Failed to install service file${NC}"
        rm -f "$temp_service"
        return 1
    fi
    
    # 清理临时文件
    rm -f "$temp_service"
    
    # 重新加载systemd并启用服务
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    
    echo -e "${GREEN}✅ Service installed and enabled${NC}"
}

# 配置防火墙
configure_firewall() {
    if [[ "$SKIP_FIREWALL" == "true" ]]; then
        echo -e "${YELLOW}⏭️ Skipping firewall configuration${NC}"
        return 0
    fi
    
    if [[ "$ENABLE_REMOTE" == "true" ]] || [[ -n "$REMOTE_HOST" ]] || [[ "$LISTEN_ADDR" == "0.0.0.0:"* ]]; then
        echo -e "${BLUE}🔥 Configuring firewall for remote access...${NC}"
        
        # 配置ufw防火墙
        if command -v ufw &>/dev/null; then
            ufw allow 50051/tcp comment "Analytics Engine gRPC" 2>/dev/null || true
            echo -e "${GREEN}✅ Firewall configured for remote access${NC}"
        else
            echo -e "${YELLOW}⚠️  UFW not available, please manually configure firewall${NC}"
        fi
    else
        echo -e "${YELLOW}💡 Local deployment - no firewall changes needed${NC}"
    fi
}

# 启动服务
start_service() {
    echo -e "${BLUE}🎯 Starting Analytics Engine service...${NC}"
    
    sudo systemctl start $SERVICE_NAME
    
    # 等待服务启动
    sleep 3
    
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}✅ Service started successfully${NC}"
    else
        echo -e "${RED}❌ Service failed to start${NC}"
        sudo journalctl -u $SERVICE_NAME --no-pager -l
        exit 1
    fi
}

# 健康检查
health_check() {
    echo -e "${BLUE}🏥 Running health check...${NC}"
    
    # 等待服务完全启动
    sleep 5
    
    # 检查端口监听
    if netstat -tlnp 2>/dev/null | grep :50051 > /dev/null; then
        echo -e "${GREEN}✅ Service listening on port 50051${NC}"
    else
        echo -e "${RED}❌ Service not listening on port 50051${NC}"
        exit 1
    fi
    
    # 测试gRPC健康检查（如果grpcurl可用）
    if command -v grpcurl &> /dev/null; then
        echo -e "${YELLOW}🔍 Testing gRPC health check...${NC}"
        if timeout 10 grpcurl -plaintext localhost:50051 analytics.AnalyticsEngine/HealthCheck 2>/dev/null; then
            echo -e "${GREEN}✅ gRPC health check passed${NC}"
        else
            echo -e "${YELLOW}⚠️  gRPC health check failed or timed out${NC}"
        fi
    fi
}

# 显示部署信息
show_deployment_info() {
    echo -e "${GREEN}🎉 Analytics Engine Deployment completed successfully!${NC}"
    echo -e "${BLUE}📍 Deployment Information:${NC}"
    echo -e "   Service: $SERVICE_NAME"
    echo -e "   Path: $DEPLOY_PATH"
    echo -e "   User: $DEPLOY_USER"
    echo -e "   Port: 50051"
    
    # 🔧 关键：输出Backend连接地址配置
    local backend_connection_addr
    if [[ "$ENABLE_REMOTE" == "true" ]] || [[ "$LISTEN_ADDR" == "0.0.0.0:"* ]]; then
        # 外部访问模式：获取本机IP
        local server_ip=$(hostname -I | awk '{print $1}')
        backend_connection_addr="http://${server_ip}:50051"
        echo -e "   ${GREEN}✅ External Access Mode${NC}"
        echo -e "   Analytics Engine URL: ${GREEN}${backend_connection_addr}${NC}"
    else
        # 本地访问模式：适用于同机部署
        backend_connection_addr="http://localhost:50051"
        echo -e "   ${YELLOW}📍 Local Access Mode${NC}"
        echo -e "   Analytics Engine URL: ${GREEN}${backend_connection_addr}${NC}"
    fi
    
    echo -e ""
    echo -e "${YELLOW}🔗 Next Step - Deploy Backend:${NC}"
    echo -e "${BLUE}   Export environment variable:${NC}"
    echo -e "   ${GREEN}export ANALYTICS_ENGINE_ADDR=\"${backend_connection_addr}\"${NC}"
    echo -e ""
    echo -e "${BLUE}   Then deploy Backend:${NC}"
    echo -e "   ${GREEN}cd ../backend && ./scripts/deploy.sh${NC}"
    echo -e ""
    echo -e "${BLUE}   Or deploy Backend container:${NC}"
    echo -e "   ${GREEN}podman run -e ANALYTICS_ENGINE_ADDR=\"${backend_connection_addr}\" ...${NC}"
    
    echo -e ""
    echo -e "${YELLOW}🔧 Management Commands:${NC}"
    echo -e "   Status:  systemctl status $SERVICE_NAME"
    echo -e "   Logs:    journalctl -u $SERVICE_NAME -f"
    echo -e "   Manage:  ./scripts/manage-service.sh"
    echo -e ""
    echo -e "${BLUE}🌐 Analytics Engine is ready for Backend connections!${NC}"
}

# 远程部署功能
deploy_remote() {
    echo -e "${BLUE}🌐 Deploying to remote host: $REMOTE_HOST${NC}"
    echo -e "${BLUE}   SSH User: $SSH_USER${NC}"
    echo -e "${BLUE}   SSH Port: $SSH_PORT${NC}"
    
    # 扩展SSH密钥路径
    SSH_KEY=$(eval echo "$SSH_KEY")
    
    # 检查SSH连接 - 先尝试密钥认证
    echo -e "${YELLOW}🔑 Testing SSH connection with key authentication...${NC}"
    if ssh -i "$SSH_KEY" -p "$SSH_PORT" -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$SSH_USER@$REMOTE_HOST" "echo 'SSH key connection successful'" 2>/dev/null; then
        echo -e "${GREEN}✅ SSH key authentication successful${NC}"
        SSH_AUTH_MODE="key"
    else
        echo -e "${YELLOW}⚠️  SSH key authentication failed, trying interactive mode...${NC}"
        echo -e "${BLUE}💡 Please enter password for $SSH_USER@$REMOTE_HOST${NC}"
        if ssh -p "$SSH_PORT" -o ConnectTimeout=30 -o StrictHostKeyChecking=accept-new "$SSH_USER@$REMOTE_HOST" "echo 'SSH password connection successful'"; then
            echo -e "${GREEN}✅ SSH password authentication successful${NC}"
            SSH_AUTH_MODE="password"
        else
            echo -e "${RED}❌ SSH connection failed to $SSH_USER@$REMOTE_HOST:$SSH_PORT${NC}"
            echo -e "${YELLOW}💡 Troubleshooting tips:${NC}"
            echo -e "   1. Check if SSH service is running: ssh $SSH_USER@$REMOTE_HOST"
            echo -e "   2. Verify SSH key: ssh-copy-id -p $SSH_PORT $SSH_USER@$REMOTE_HOST"
            echo -e "   3. Check firewall: telnet $REMOTE_HOST $SSH_PORT"
            exit 1
        fi
    fi
    
    # Dry run模式检查
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}🧪 DRY RUN: Would deploy to $SSH_USER@$REMOTE_HOST:$SSH_PORT${NC}"
        echo -e "${YELLOW}   Auth mode: $SSH_AUTH_MODE${NC}"
        echo -e "${YELLOW}   Target directory: $DEPLOY_PATH${NC}"
        return 0
    fi
    
    # 打包文件
    echo -e "${BLUE}📦 Packaging deployment files...${NC}"
    TEMP_DIR=$(mktemp -d)
    TAR_FILE="$TEMP_DIR/analytics-engine.tar.gz"
    tar -czf "$TAR_FILE" target/release/analytics-server python/ env.example scripts/
    
    # 上传并执行远程部署
    echo -e "${BLUE}📤 Uploading files to remote host...${NC}"
    if [[ "$SSH_AUTH_MODE" == "key" ]]; then
        scp -i "$SSH_KEY" -P "$SSH_PORT" "$TAR_FILE" "$SSH_USER@$REMOTE_HOST:/tmp/"
        SSH_CMD="ssh -i '$SSH_KEY' -p '$SSH_PORT' '$SSH_USER@$REMOTE_HOST'"
    else
        scp -P "$SSH_PORT" "$TAR_FILE" "$SSH_USER@$REMOTE_HOST:/tmp/"
        SSH_CMD="ssh -p '$SSH_PORT' '$SSH_USER@$REMOTE_HOST'"
    fi
    
    echo -e "${BLUE}🚀 Executing remote deployment...${NC}"
    eval "$SSH_CMD" << 'EOF'
        cd /tmp
        tar -xzf analytics-engine.tar.gz
        
        # 移动文件到正确位置
        mkdir -p /tmp/analytics-deploy
        cp target/release/analytics-server /tmp/analytics-deploy/
        if [ -d python/ ]; then
            cp -r python/ /tmp/analytics-deploy/
        fi
        if [ -f env.example ]; then
            cp env.example /tmp/analytics-deploy/
        fi
        
        cd scripts
        chmod +x *.sh
        
        # 创建用户和部署（root用户统一执行）
        ./setup-user.sh || true
        
        # 验证二进制文件
        echo "🔍 Verifying binary..."
        if [ -x /tmp/analytics-deploy/analytics-server ]; then
            echo "✅ Binary verification successful"
        else
            echo "❌ Binary not executable"
            exit 1
        fi
        
        # 手动执行本地部署步骤，避免递归调用
        echo "🛑 Stopping existing service..."
        sudo systemctl stop analytics-engine 2>/dev/null || true
        
        # 终止可能占用端口的进程
        sudo pkill -f analytics-server 2>/dev/null || true
        sleep 2
        
        echo "📦 Backing up current version..."
        if [ -d "/opt/v7/analytics-engine" ]; then
            BACKUP_DIR="/opt/v7/backups/analytics-engine/backup-$(date +%Y%m%d-%H%M%S)"
            sudo mkdir -p "$BACKUP_DIR"
            sudo cp -r /opt/v7/analytics-engine "$BACKUP_DIR" 2>/dev/null || true
        fi
        
        echo "🚀 Deploying new version..."
        sudo mkdir -p /opt/v7/analytics-engine/{bin,python,data,logs,config}
        sudo cp /tmp/analytics-deploy/analytics-server /opt/v7/analytics-engine/bin/
        sudo chmod +x /opt/v7/analytics-engine/bin/analytics-server
        
        if [ -d /tmp/analytics-deploy/python ]; then
            sudo cp -r /tmp/analytics-deploy/python/ /opt/v7/analytics-engine/
        fi
        
        if [ -f /tmp/analytics-deploy/env.example ]; then
            sudo cp /tmp/analytics-deploy/env.example /opt/v7/analytics-engine/config/env
        fi
        
        sudo chown -R analytics:analytics /opt/v7/analytics-engine
        
        echo "⚙️ Installing systemd service..."
        sudo bash -c 'cat > /etc/systemd/system/analytics-engine.service' << 'SERVICE_EOF'
[Unit]
Description=V7 Analytics Engine - Rust+Python混合分析引擎
Documentation=https://github.com/v7-project/analytics-engine
After=network.target

[Service]
Type=simple
User=analytics
Group=analytics
WorkingDirectory=/opt/v7/analytics-engine
ExecStart=/opt/v7/analytics-engine/bin/analytics-server
ExecReload=/bin/kill -HUP $MAINPID

# 环境变量
Environment=RUST_LOG=info
Environment=ANALYTICS_LISTEN_ADDR=0.0.0.0:50051
Environment=PYTHONPATH=/opt/v7/analytics-engine/python
Environment=PYTHONUNBUFFERED=1

# 重启策略
Restart=always
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/v7/analytics-engine/data /opt/v7/analytics-engine/logs

# 资源限制
LimitNOFILE=65536
MemoryMax=2G
TasksMax=4096

[Install]
WantedBy=multi-user.target
SERVICE_EOF

        sudo systemctl daemon-reload
        sudo systemctl enable analytics-engine
        
        echo "🔥 Configuring firewall..."
        if command -v ufw &>/dev/null; then
            sudo ufw allow 50051/tcp comment "Analytics Engine gRPC" 2>/dev/null || true
        fi
        
        echo "🎯 Starting service..."
        sudo systemctl start analytics-engine
        
        # 等待服务启动
        sleep 5
        
        if sudo systemctl is-active --quiet analytics-engine; then
            echo "✅ Service started successfully"
            
            # 检查端口监听
            if sudo netstat -tlnp 2>/dev/null | grep :50051 > /dev/null; then
                echo "✅ Service listening on port 50051"
            else
                echo "⚠️ Service not listening on port 50051 yet"
            fi
        else
            echo "❌ Service failed to start"
            sudo journalctl -u analytics-engine --no-pager -l
            exit 1
        fi
        
        echo "🎉 Remote deployment completed successfully!"
        echo "📍 Service: analytics-engine"
        echo "📍 Path: /opt/v7/analytics-engine" 
        echo "📍 Port: 50051"
        echo "📍 Access: External (0.0.0.0:50051)"
        
        # 清理临时文件
        rm -rf /tmp/analytics-deploy /tmp/analytics-engine.tar.gz
EOF
    
    # 清理临时文件
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}✅ Remote deployment completed${NC}"
}

# 主部署流程
main() {
    echo -e "${GREEN}🎯 Analytics Engine Deployment${NC}"
    echo -e "${BLUE}Target: $DEPLOY_PATH${NC}"
    echo -e "${BLUE}User: $DEPLOY_USER${NC}"
    
    parse_arguments "$@"
    
    # 远程部署
    if [[ -n "$REMOTE_HOST" ]]; then
        check_build
        deploy_remote
        return
    fi
    
    # 本地部署
    check_permissions
    check_build
    stop_service
    backup_current
    deploy_binary
    install_service
    configure_firewall
    start_service
    health_check
    show_deployment_info
}

# 执行主函数
main "$@" 