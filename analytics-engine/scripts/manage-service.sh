#!/bin/bash

# Analytics Engine Service Manager
# 服务管理脚本 - 提供友好的服务管理界面

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SERVICE_NAME="analytics-engine"

# 显示服务状态
show_status() {
    echo -e "${BLUE}📊 Analytics Engine Service Status${NC}"
    echo -e "${CYAN}=================================${NC}"
    
    # 服务状态
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "Status: ${GREEN}🟢 Running${NC}"
    else
        echo -e "Status: ${RED}🔴 Stopped${NC}"
    fi
    
    # 开机自启状态
    if sudo systemctl is-enabled --quiet $SERVICE_NAME; then
        echo -e "Auto-start: ${GREEN}✅ Enabled${NC}"
    else
        echo -e "Auto-start: ${YELLOW}❌ Disabled${NC}"
    fi
    
    # 屏蔽状态
    if sudo systemctl is-masked --quiet $SERVICE_NAME; then
        echo -e "Masked: ${RED}🚫 Yes${NC}"
    else
        echo -e "Masked: ${GREEN}✅ No${NC}"
    fi
    
    echo ""
    
    # 详细状态信息
    sudo systemctl status $SERVICE_NAME --no-pager -l || true
}

# 启动服务
start_service() {
    echo -e "${BLUE}🚀 Starting Analytics Engine...${NC}"
    
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}⚠️  Service is already running${NC}"
        return 0
    fi
    
    sudo systemctl start $SERVICE_NAME
    
    # 等待服务启动
    sleep 3
    
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}✅ Service started successfully${NC}"
        
        # 检查端口监听
        if netstat -tlnp 2>/dev/null | grep :50051 > /dev/null; then
            echo -e "${GREEN}✅ Port 50051 is listening${NC}"
        else
            echo -e "${YELLOW}⚠️  Port 50051 not detected yet${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to start service${NC}"
        echo -e "${YELLOW}📋 Recent logs:${NC}"
        sudo journalctl -u $SERVICE_NAME --no-pager -n 10
        return 1
    fi
}

# 停止服务
stop_service() {
    echo -e "${BLUE}🛑 Stopping Analytics Engine...${NC}"
    
    if ! sudo systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}⚠️  Service is already stopped${NC}"
        return 0
    fi
    
    sudo systemctl stop $SERVICE_NAME
    
    # 等待服务停止
    sleep 3
    
    if ! sudo systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}✅ Service stopped successfully${NC}"
    else
        echo -e "${RED}❌ Failed to stop service${NC}"
        return 1
    fi
}

# 重启服务
restart_service() {
    echo -e "${BLUE}🔄 Restarting Analytics Engine...${NC}"
    
    sudo systemctl restart $SERVICE_NAME
    
    # 等待服务重启
    sleep 3
    
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}✅ Service restarted successfully${NC}"
    else
        echo -e "${RED}❌ Failed to restart service${NC}"
        echo -e "${YELLOW}📋 Recent logs:${NC}"
        sudo journalctl -u $SERVICE_NAME --no-pager -n 10
        return 1
    fi
}

# 启用开机自启
enable_service() {
    echo -e "${BLUE}⚡ Enabling auto-start...${NC}"
    
    if sudo systemctl is-enabled --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}⚠️  Auto-start is already enabled${NC}"
        return 0
    fi
    
    sudo systemctl enable $SERVICE_NAME
    echo -e "${GREEN}✅ Auto-start enabled${NC}"
}

# 禁用开机自启
disable_service() {
    echo -e "${BLUE}❌ Disabling auto-start...${NC}"
    
    if ! sudo systemctl is-enabled --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}⚠️  Auto-start is already disabled${NC}"
        return 0
    fi
    
    sudo systemctl disable $SERVICE_NAME
    echo -e "${GREEN}✅ Auto-start disabled${NC}"
}

# 屏蔽服务
mask_service() {
    echo -e "${BLUE}🚫 Masking service (complete disable)...${NC}"
    echo -e "${YELLOW}⚠️  This will prevent the service from being started by any means${NC}"
    read -p "Are you sure? (y/N): " -r
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled${NC}"
        return 0
    fi
    
    sudo systemctl mask $SERVICE_NAME
    echo -e "${GREEN}✅ Service masked${NC}"
}

# 解除屏蔽
unmask_service() {
    echo -e "${BLUE}🔓 Unmasking service...${NC}"
    
    if ! sudo systemctl is-masked --quiet $SERVICE_NAME; then
        echo -e "${YELLOW}⚠️  Service is not masked${NC}"
        return 0
    fi
    
    sudo systemctl unmask $SERVICE_NAME
    echo -e "${GREEN}✅ Service unmasked${NC}"
}

# 查看日志
show_logs() {
    echo -e "${BLUE}📝 Analytics Engine Logs${NC}"
    echo -e "${CYAN}========================${NC}"
    
    case "${1:-recent}" in
        "live")
            echo -e "${YELLOW}Showing live logs (Press Ctrl+C to exit)${NC}"
            sudo journalctl -u $SERVICE_NAME -f
            ;;
        "today")
            echo -e "${YELLOW}Showing today's logs${NC}"
            sudo journalctl -u $SERVICE_NAME --since today
            ;;
        "hour")
            echo -e "${YELLOW}Showing last hour's logs${NC}"
            sudo journalctl -u $SERVICE_NAME --since "1 hour ago"
            ;;
        "recent")
            echo -e "${YELLOW}Showing recent logs (last 50 lines)${NC}"
            sudo journalctl -u $SERVICE_NAME --no-pager -n 50
            ;;
        *)
            echo -e "${RED}Invalid log option. Use: recent, live, today, hour${NC}"
            return 1
            ;;
    esac
}

# 健康检查
health_check() {
    echo -e "${BLUE}🏥 Health Check${NC}"
    echo -e "${CYAN}===============${NC}"
    
    # 检查服务状态
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}✅ Service is running${NC}"
    else
        echo -e "${RED}❌ Service is not running${NC}"
        return 1
    fi
    
    # 检查端口监听
    if netstat -tlnp 2>/dev/null | grep :50051 > /dev/null; then
        echo -e "${GREEN}✅ Port 50051 is listening${NC}"
    else
        echo -e "${RED}❌ Port 50051 is not listening${NC}"
        return 1
    fi
    
    # 检查gRPC服务（如果grpcurl可用）
    if command -v grpcurl &> /dev/null; then
        echo -e "${YELLOW}🔍 Testing gRPC health check...${NC}"
        if timeout 10 grpcurl -plaintext localhost:50051 analytics.AnalyticsEngine/HealthCheck 2>/dev/null; then
            echo -e "${GREEN}✅ gRPC health check passed${NC}"
        else
            echo -e "${YELLOW}⚠️  gRPC health check failed or timed out${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  grpcurl not available, skipping gRPC test${NC}"
    fi
    
    # 检查资源使用
    local pid=$(pgrep analytics-server 2>/dev/null)
    if [[ -n "$pid" ]]; then
        echo -e "${YELLOW}📊 Resource usage:${NC}"
        ps -p $pid -o pid,ppid,user,%cpu,%mem,vsz,rss,stat,start,time,comm --no-headers
    fi
}

# 显示主菜单
show_menu() {
    echo -e "${PURPLE}🚀 Analytics Engine Service Manager${NC}"
    echo -e "${CYAN}====================================${NC}"
    echo ""
    echo -e "${YELLOW}Service Control:${NC}"
    echo -e "  ${GREEN}1)${NC} Start service"
    echo -e "  ${GREEN}2)${NC} Stop service"
    echo -e "  ${GREEN}3)${NC} Restart service"
    echo -e "  ${GREEN}4)${NC} Show status"
    echo ""
    echo -e "${YELLOW}Auto-start Control:${NC}"
    echo -e "  ${GREEN}5)${NC} Enable auto-start"
    echo -e "  ${GREEN}6)${NC} Disable auto-start"
    echo ""
    echo -e "${YELLOW}Advanced Control:${NC}"
    echo -e "  ${GREEN}7)${NC} Mask service (complete disable)"
    echo -e "  ${GREEN}8)${NC} Unmask service"
    echo ""
    echo -e "${YELLOW}Monitoring:${NC}"
    echo -e "  ${GREEN}9)${NC} Show recent logs"
    echo -e "  ${GREEN}10)${NC} Show live logs"
    echo -e "  ${GREEN}11)${NC} Health check"
    echo ""
    echo -e "  ${GREEN}0)${NC} Exit"
    echo ""
}

# 交互式菜单
interactive_menu() {
    while true; do
        show_menu
        read -p "Select an option (0-11): " choice
        echo ""
        
        case $choice in
            1) start_service ;;
            2) stop_service ;;
            3) restart_service ;;
            4) show_status ;;
            5) enable_service ;;
            6) disable_service ;;
            7) mask_service ;;
            8) unmask_service ;;
            9) show_logs recent ;;
            10) show_logs live ;;
            11) health_check ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option. Please try again.${NC}" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        clear
    done
}

# 显示使用说明
show_usage() {
    echo -e "${YELLOW}Usage: $0 [COMMAND] [OPTIONS]${NC}"
    echo ""
    echo -e "${BLUE}Commands:${NC}"
    echo -e "  start           Start the service"
    echo -e "  stop            Stop the service"
    echo -e "  restart         Restart the service"
    echo -e "  status          Show service status"
    echo -e "  enable          Enable auto-start"
    echo -e "  disable         Disable auto-start"
    echo -e "  mask            Mask service (complete disable)"
    echo -e "  unmask          Unmask service"
    echo -e "  logs [TYPE]     Show logs (recent|live|today|hour)"
    echo -e "  health          Perform health check"
    echo -e "  menu            Show interactive menu"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo -e "  $0 start"
    echo -e "  $0 logs live"
    echo -e "  $0 health"
    echo -e "  $0 menu"
}

# 主函数
main() {
    # 检查是否安装了服务
    if ! sudo systemctl list-unit-files | grep -q "^$SERVICE_NAME.service"; then
        echo -e "${RED}❌ Analytics Engine service is not installed${NC}"
        echo -e "${YELLOW}💡 Please run the deployment script first:${NC}"
        echo -e "   sudo ./scripts/deploy.sh"
        exit 1
    fi
    
    case "${1:-menu}" in
        "start") start_service ;;
        "stop") stop_service ;;
        "restart") restart_service ;;
        "status") show_status ;;
        "enable") enable_service ;;
        "disable") disable_service ;;
        "mask") mask_service ;;
        "unmask") unmask_service ;;
        "logs") show_logs "${2:-recent}" ;;
        "health") health_check ;;
        "menu") interactive_menu ;;
        "help"|"--help") show_usage ;;
        *) 
            echo -e "${RED}❌ Unknown command: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@" 