#!/bin/bash

# Analytics Engine User Setup Script
# 创建analytics专用用户和配置权限

set -e

echo "🔧 Setting up Analytics Engine user and permissions..."

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
ANALYTICS_USER="analytics"
ANALYTICS_UID=2001
ANALYTICS_GID=2001
ANALYTICS_HOME="/home/analytics"
DEPLOY_PATH="/opt/v7/analytics-engine"
BACKUP_PATH="/opt/v7/backups"

# 检查是否为root或sudo用户
check_privileges() {
    echo -e "${BLUE}🔐 Checking user privileges...${NC}"
    
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        echo -e "${RED}❌ This script requires root privileges or sudo access${NC}"
        echo -e "${YELLOW}💡 Please run: sudo $0${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Privileges OK${NC}"
}

# 创建analytics用户
create_analytics_user() {
    echo -e "${BLUE}👤 Creating analytics user...${NC}"
    
    # 检查用户是否已存在
    if id "$ANALYTICS_USER" &>/dev/null; then
        echo -e "${YELLOW}⚠️  User $ANALYTICS_USER already exists${NC}"
        return 0
    fi
    
    # 创建用户组
    if ! getent group "$ANALYTICS_USER" >/dev/null; then
        sudo groupadd -g $ANALYTICS_GID "$ANALYTICS_USER"
        echo -e "${GREEN}✅ Created group: $ANALYTICS_USER (GID: $ANALYTICS_GID)${NC}"
    fi
    
    # 创建用户
    sudo useradd \
        -u $ANALYTICS_UID \
        -g $ANALYTICS_USER \
        -d $ANALYTICS_HOME \
        -m \
        -s /bin/bash \
        -c "Analytics Engine Service User" \
        "$ANALYTICS_USER"
    
    echo -e "${GREEN}✅ Created user: $ANALYTICS_USER (UID: $ANALYTICS_UID)${NC}"
    
    # 启用用户服务持久化（linger）
    echo -e "${BLUE}⚡ Enabling user service persistence (linger)...${NC}"
    sudo loginctl enable-linger "$ANALYTICS_USER"
    echo -e "${GREEN}✅ User service persistence enabled${NC}"
    
    # 设置密码（可选）
    if [[ "${SET_PASSWORD:-}" == "true" ]]; then
        echo -e "${BLUE}🔑 Setting password for $ANALYTICS_USER...${NC}"
        sudo passwd "$ANALYTICS_USER"
    else
        echo -e "${YELLOW}⚠️  No password set for $ANALYTICS_USER (sudo access only)${NC}"
    fi
}

# 创建必要目录
create_directories() {
    echo -e "${BLUE}📁 Creating directories...${NC}"
    
    # 创建部署目录
    sudo mkdir -p "$DEPLOY_PATH"/{bin,data,logs,config,tmp}
    sudo mkdir -p "$BACKUP_PATH/analytics-engine"
    sudo mkdir -p "/var/log/analytics-engine"
    sudo mkdir -p "/etc/analytics-engine"
    
    # 设置目录权限
    sudo chown -R "$ANALYTICS_USER:$ANALYTICS_USER" "$DEPLOY_PATH"
    sudo chown -R "$ANALYTICS_USER:$ANALYTICS_USER" "$BACKUP_PATH/analytics-engine"
    sudo chown -R "$ANALYTICS_USER:$ANALYTICS_USER" "/var/log/analytics-engine"
    sudo chown -R "$ANALYTICS_USER:$ANALYTICS_USER" "/etc/analytics-engine"
    
    # 设置权限
    sudo chmod 755 "$DEPLOY_PATH"
    sudo chmod 750 "$DEPLOY_PATH"/{data,logs,config}
    sudo chmod 755 "$DEPLOY_PATH"/{bin,tmp}
    
    echo -e "${GREEN}✅ Directories created and configured${NC}"
}

# 配置sudo权限（可选）
configure_sudo() {
    if [[ "${ENABLE_SUDO:-}" == "true" ]]; then
        echo -e "${BLUE}🔧 Configuring sudo access for $ANALYTICS_USER...${NC}"
        
        # 创建sudoers文件
        cat > "/tmp/analytics-sudoers" << EOF
# Analytics Engine service management permissions
$ANALYTICS_USER ALL=(ALL) NOPASSWD: /bin/systemctl start analytics-engine
$ANALYTICS_USER ALL=(ALL) NOPASSWD: /bin/systemctl stop analytics-engine
$ANALYTICS_USER ALL=(ALL) NOPASSWD: /bin/systemctl restart analytics-engine
$ANALYTICS_USER ALL=(ALL) NOPASSWD: /bin/systemctl status analytics-engine
$ANALYTICS_USER ALL=(ALL) NOPASSWD: /bin/systemctl enable analytics-engine
$ANALYTICS_USER ALL=(ALL) NOPASSWD: /bin/systemctl disable analytics-engine
$ANALYTICS_USER ALL=(ALL) NOPASSWD: /bin/journalctl -u analytics-engine*
EOF
        
        # 验证并安装sudoers文件
        if sudo visudo -c -f "/tmp/analytics-sudoers"; then
            sudo cp "/tmp/analytics-sudoers" "/etc/sudoers.d/analytics-engine"
            sudo chmod 440 "/etc/sudoers.d/analytics-engine"
            echo -e "${GREEN}✅ Sudo permissions configured${NC}"
        else
            echo -e "${RED}❌ Invalid sudoers configuration${NC}"
            return 1
        fi
        
        sudo rm -f "/tmp/analytics-sudoers"
    fi
}

# 创建SSH密钥（可选，用于自动化部署）
setup_ssh_keys() {
    if [[ "${SETUP_SSH:-}" == "true" ]]; then
        echo -e "${BLUE}🔑 Setting up SSH keys for $ANALYTICS_USER...${NC}"
        
        # 切换到analytics用户创建SSH密钥
        sudo -u "$ANALYTICS_USER" bash << 'EOF'
cd ~
if [[ ! -f ~/.ssh/id_rsa ]]; then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "analytics@$(hostname)"
    chmod 600 ~/.ssh/id_rsa
    chmod 644 ~/.ssh/id_rsa.pub
    echo "✅ SSH key pair generated"
else
    echo "⚠️  SSH key already exists"
fi
EOF
        
        echo -e "${GREEN}✅ SSH keys configured${NC}"
        echo -e "${YELLOW}💡 Public key location: $ANALYTICS_HOME/.ssh/id_rsa.pub${NC}"
    fi
}

# 显示配置信息
show_configuration() {
    echo -e "${BLUE}📋 Configuration Summary:${NC}"
    echo -e "${GREEN}User:${NC} $ANALYTICS_USER"
    echo -e "${GREEN}UID/GID:${NC} $ANALYTICS_UID/$ANALYTICS_GID"
    echo -e "${GREEN}Home:${NC} $ANALYTICS_HOME"
    echo -e "${GREEN}Deploy Path:${NC} $DEPLOY_PATH"
    echo -e "${GREEN}Backup Path:${NC} $BACKUP_PATH"
    echo -e "${GREEN}Log Path:${NC} /var/log/analytics-engine"
    
    echo -e "\n${BLUE}🚀 Next Steps:${NC}"
    echo -e "1. Run deployment: ${YELLOW}sudo -u $ANALYTICS_USER ./scripts/deploy.sh${NC}"
    echo -e "2. Or switch user: ${YELLOW}sudo su - $ANALYTICS_USER${NC}"
    echo -e "3. Check status: ${YELLOW}sudo systemctl status analytics-engine${NC}"
}

# 显示使用说明
show_usage() {
    echo -e "${YELLOW}Usage: $0 [OPTIONS]${NC}"
    echo -e "${BLUE}Options:${NC}"
    echo -e "  -p, --password        Set password for analytics user"
    echo -e "  -s, --sudo           Enable limited sudo access"
    echo -e "  -k, --ssh-keys       Setup SSH keys for automation"
    echo -e "  -h, --help           Show this help message"
    echo -e ""
    echo -e "${BLUE}Examples:${NC}"
    echo -e "  $0                   # Basic user creation"
    echo -e "  $0 -p -s -k         # Full setup with password, sudo, and SSH"
    echo -e "  SET_PASSWORD=true ENABLE_SUDO=true $0  # Environment variables"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--password)
            SET_PASSWORD=true
            shift
            ;;
        -s|--sudo)
            ENABLE_SUDO=true
            shift
            ;;
        -k|--ssh-keys)
            SETUP_SSH=true
            shift
            ;;
        -h|--help)
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

# 主执行流程
main() {
    echo -e "${GREEN}🎯 Analytics Engine User Setup${NC}"
    echo -e "${BLUE}================================${NC}"
    
    check_privileges
    create_analytics_user
    create_directories
    
    if [[ "${ENABLE_SUDO:-}" == "true" ]]; then
        configure_sudo
    fi
    
    if [[ "${SETUP_SSH:-}" == "true" ]]; then
        setup_ssh_keys
    fi
    
    show_configuration
    
    echo -e "\n${GREEN}🎉 Analytics Engine user setup completed!${NC}"
}

# 执行主函数
main "$@" 