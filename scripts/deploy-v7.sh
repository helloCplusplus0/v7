#!/bin/bash

# V7项目统一部署编排脚本
# 正确部署顺序：Analytics Engine → Backend → Web

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 配置变量
ANALYTICS_DEPLOYMENT_MODE=""  # local, remote, container
BACKEND_DEPLOYMENT_MODE=""    # local, container
WEB_DEPLOYMENT_MODE=""        # local, container
REMOTE_ANALYTICS_HOST=""
SKIP_ANALYTICS=false
SKIP_BACKEND=false
SKIP_WEB=false

# 显示使用说明
show_usage() {
    echo -e "${YELLOW}V7 Project Deployment Orchestration${NC}"
    echo -e "${BLUE}Usage: $0 [OPTIONS]${NC}"
    echo -e ""
    echo -e "${BLUE}Deployment Modes:${NC}"
    echo -e "  --analytics-local                 Deploy Analytics Engine locally"
    echo -e "  --analytics-remote HOST           Deploy Analytics Engine to remote host"
    echo -e "  --analytics-container             Analytics Engine in container (podman-compose)"
    echo -e "  --backend-local                   Deploy Backend locally"
    echo -e "  --backend-container               Deploy Backend as container"
    echo -e "  --web-local                       Deploy Web locally"
    echo -e "  --web-container                   Deploy Web as container"
    echo -e ""
    echo -e "${BLUE}Selective Deployment:${NC}"
    echo -e "  --skip-analytics                  Skip Analytics Engine deployment"
    echo -e "  --skip-backend                    Skip Backend deployment"
    echo -e "  --skip-web                        Skip Web deployment"
    echo -e ""
    echo -e "${BLUE}Common Scenarios:${NC}"
    echo -e "  ${GREEN}# 完全本地部署（测试环境）${NC}"
    echo -e "  $0 --analytics-local --backend-local --web-local"
    echo -e ""
    echo -e "  ${GREEN}# 混合部署（推荐生产）${NC}"
    echo -e "  $0 --analytics-local --backend-container --web-container"
    echo -e ""
    echo -e "  ${GREEN}# 分布式部署（企业级）${NC}"
    echo -e "  $0 --analytics-remote 10.0.1.100 --backend-container --web-container"
    echo -e ""
    echo -e "  ${GREEN}# 只部署Backend（Analytics已部署）${NC}"
    echo -e "  $0 --skip-analytics --backend-container --web-container"
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --analytics-local)
                ANALYTICS_DEPLOYMENT_MODE="local"
                shift
                ;;
            --analytics-remote)
                ANALYTICS_DEPLOYMENT_MODE="remote"
                REMOTE_ANALYTICS_HOST="$2"
                shift 2
                ;;
            --analytics-container)
                ANALYTICS_DEPLOYMENT_MODE="container"
                shift
                ;;
            --backend-local)
                BACKEND_DEPLOYMENT_MODE="local"
                shift
                ;;
            --backend-container)
                BACKEND_DEPLOYMENT_MODE="container"
                shift
                ;;
            --web-local)
                WEB_DEPLOYMENT_MODE="local"
                shift
                ;;
            --web-container)
                WEB_DEPLOYMENT_MODE="container"
                shift
                ;;
            --skip-analytics)
                SKIP_ANALYTICS=true
                shift
                ;;
            --skip-backend)
                SKIP_BACKEND=true
                shift
                ;;
            --skip-web)
                SKIP_WEB=true
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

# 验证部署配置
validate_config() {
    echo -e "${BLUE}🔍 Validating deployment configuration...${NC}"
    
    if [[ "$SKIP_ANALYTICS" == "false" && -z "$ANALYTICS_DEPLOYMENT_MODE" ]]; then
        echo -e "${RED}❌ Analytics Engine deployment mode not specified${NC}"
        exit 1
    fi
    
    if [[ "$SKIP_BACKEND" == "false" && -z "$BACKEND_DEPLOYMENT_MODE" ]]; then
        echo -e "${RED}❌ Backend deployment mode not specified${NC}"
        exit 1
    fi
    
    if [[ "$SKIP_WEB" == "false" && -z "$WEB_DEPLOYMENT_MODE" ]]; then
        echo -e "${RED}❌ Web deployment mode not specified${NC}"
        exit 1
    fi
    
    if [[ "$ANALYTICS_DEPLOYMENT_MODE" == "remote" && -z "$REMOTE_ANALYTICS_HOST" ]]; then
        echo -e "${RED}❌ Remote Analytics host not specified${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Configuration validated${NC}"
}

# 部署Analytics Engine
deploy_analytics_engine() {
    if [[ "$SKIP_ANALYTICS" == "true" ]]; then
        echo -e "${YELLOW}⏭️  Skipping Analytics Engine deployment${NC}"
        return 0
    fi
    
    echo -e "${PURPLE}🚀 Step 1: Deploying Analytics Engine${NC}"
    echo -e "${BLUE}Mode: $ANALYTICS_DEPLOYMENT_MODE${NC}"
    
    cd analytics-engine
    
    case "$ANALYTICS_DEPLOYMENT_MODE" in
        "local")
            # 本地部署
            echo -e "${BLUE}📦 Building Analytics Engine...${NC}"
            ./scripts/build.sh
            
            echo -e "${BLUE}⚙️  Deploying locally...${NC}"
            sudo -u analytics ./scripts/deploy.sh --enable-remote
            ;;
        "remote")
            # 远程部署
            echo -e "${BLUE}📦 Building Analytics Engine...${NC}"
            ./scripts/build.sh
            
            echo -e "${BLUE}🌐 Deploying to remote host: $REMOTE_ANALYTICS_HOST${NC}"
            ./scripts/deploy.sh --remote-host "$REMOTE_ANALYTICS_HOST"
            ;;
        "container")
            echo -e "${YELLOW}🐳 Analytics Engine will be deployed via container${NC}"
            echo -e "${BLUE}Please use podman-compose to deploy analytics-engine service${NC}"
            return 0
            ;;
        *)
            echo -e "${RED}❌ Invalid Analytics deployment mode: $ANALYTICS_DEPLOYMENT_MODE${NC}"
            exit 1
            ;;
    esac
    
    cd ..
    echo -e "${GREEN}✅ Analytics Engine deployment completed${NC}"
}

# 获取Analytics Engine连接地址
get_analytics_connection_addr() {
    local analytics_addr=""
    
    case "$ANALYTICS_DEPLOYMENT_MODE" in
        "local")
            # 本地部署：获取本机IP
            local server_ip=$(hostname -I | awk '{print $1}')
            analytics_addr="http://${server_ip}:50051"
            ;;
        "remote")
            # 远程部署：使用远程主机IP
            analytics_addr="http://${REMOTE_ANALYTICS_HOST}:50051"
            ;;
        "container")
            # 容器部署：使用服务名
            analytics_addr="http://analytics-engine:50051"
            ;;
        *)
            # 跳过Analytics部署时，尝试从环境变量获取或使用默认值
            analytics_addr="${ANALYTICS_ENGINE_ADDR:-http://localhost:50051}"
            ;;
    esac
    
    echo "$analytics_addr"
}

# 部署Backend
deploy_backend() {
    if [[ "$SKIP_BACKEND" == "true" ]]; then
        echo -e "${YELLOW}⏭️  Skipping Backend deployment${NC}"
        return 0
    fi
    
    echo -e "${PURPLE}🚀 Step 2: Deploying Backend${NC}"
    echo -e "${BLUE}Mode: $BACKEND_DEPLOYMENT_MODE${NC}"
    
    # 获取Analytics Engine连接地址
    local analytics_addr=$(get_analytics_connection_addr)
    echo -e "${BLUE}Analytics Engine Address: ${GREEN}$analytics_addr${NC}"
    
    # 设置环境变量
    export ANALYTICS_ENGINE_ADDR="$analytics_addr"
    
    cd backend
    
    case "$BACKEND_DEPLOYMENT_MODE" in
        "local")
            echo -e "${BLUE}📦 Building Backend...${NC}"
            cargo build --release
            
            echo -e "${BLUE}⚙️  Deploying locally...${NC}"
            # 这里需要创建Backend的本地部署脚本
            echo -e "${YELLOW}⚠️  Backend local deployment script not implemented yet${NC}"
            echo -e "${BLUE}Please run manually with: ANALYTICS_ENGINE_ADDR=$analytics_addr cargo run${NC}"
            ;;
        "container")
            echo -e "${BLUE}🐳 Building Backend container...${NC}"
            podman build -t v7-backend:latest .
            
            echo -e "${BLUE}🚀 Running Backend container...${NC}"
            podman run -d \
                --name v7-backend \
                -p 3000:3000 \
                -p 50053:50053 \
                -e ANALYTICS_ENGINE_ADDR="$analytics_addr" \
                -e RUST_LOG=info \
                --add-host host.containers.internal:host-gateway \
                v7-backend:latest
            ;;
        *)
            echo -e "${RED}❌ Invalid Backend deployment mode: $BACKEND_DEPLOYMENT_MODE${NC}"
            exit 1
            ;;
    esac
    
    cd ..
    echo -e "${GREEN}✅ Backend deployment completed${NC}"
}

# 部署Web
deploy_web() {
    if [[ "$SKIP_WEB" == "true" ]]; then
        echo -e "${YELLOW}⏭️  Skipping Web deployment${NC}"
        return 0
    fi
    
    echo -e "${PURPLE}🚀 Step 3: Deploying Web${NC}"
    echo -e "${BLUE}Mode: $WEB_DEPLOYMENT_MODE${NC}"
    
    cd web
    
    case "$WEB_DEPLOYMENT_MODE" in
        "local")
            echo -e "${BLUE}📦 Building Web...${NC}"
            npm install
            npm run build
            
            echo -e "${YELLOW}⚠️  Web local deployment not fully implemented${NC}"
            echo -e "${BLUE}Please use: npm run preview or deploy dist/ to nginx${NC}"
            ;;
        "container")
            echo -e "${BLUE}🐳 Building Web container...${NC}"
            podman build -t v7-web:latest .
            
            echo -e "${BLUE}🚀 Running Web container...${NC}"
            podman run -d \
                --name v7-web \
                -p 8080:8080 \
                --add-host host.containers.internal:host-gateway \
                v7-web:latest
            ;;
        *)
            echo -e "${RED}❌ Invalid Web deployment mode: $WEB_DEPLOYMENT_MODE${NC}"
            exit 1
            ;;
    esac
    
    cd ..
    echo -e "${GREEN}✅ Web deployment completed${NC}"
}

# 显示部署总结
show_deployment_summary() {
    echo -e "${GREEN}🎉 V7 Project Deployment Completed!${NC}"
    echo -e "${BLUE}📋 Deployment Summary:${NC}"
    
    if [[ "$SKIP_ANALYTICS" == "false" ]]; then
        echo -e "   Analytics Engine: ${GREEN}$ANALYTICS_DEPLOYMENT_MODE${NC}"
        if [[ "$ANALYTICS_DEPLOYMENT_MODE" == "remote" ]]; then
            echo -e "   Analytics Host: ${GREEN}$REMOTE_ANALYTICS_HOST${NC}"
        fi
    fi
    
    if [[ "$SKIP_BACKEND" == "false" ]]; then
        echo -e "   Backend: ${GREEN}$BACKEND_DEPLOYMENT_MODE${NC}"
        echo -e "   Analytics Connection: ${GREEN}$(get_analytics_connection_addr)${NC}"
    fi
    
    if [[ "$SKIP_WEB" == "false" ]]; then
        echo -e "   Web: ${GREEN}$WEB_DEPLOYMENT_MODE${NC}"
    fi
    
    echo -e ""
    echo -e "${BLUE}🔗 Access URLs:${NC}"
    if [[ "$WEB_DEPLOYMENT_MODE" == "container" ]]; then
        echo -e "   Web UI: ${GREEN}http://localhost:8080${NC}"
    fi
    if [[ "$BACKEND_DEPLOYMENT_MODE" == "container" ]]; then
        echo -e "   Backend API: ${GREEN}http://localhost:3000${NC}"
        echo -e "   Backend gRPC: ${GREEN}http://localhost:50053${NC}"
    fi
    
    echo -e ""
    echo -e "${YELLOW}📝 Next Steps:${NC}"
    echo -e "   1. Test the deployment: curl http://localhost:8080/health"
    echo -e "   2. Monitor logs: podman logs -f v7-web v7-backend"
    echo -e "   3. Check service status: systemctl status analytics-engine"
}

# 主函数
main() {
    echo -e "${PURPLE}🎯 V7 Project Deployment Orchestration${NC}"
    echo -e "${BLUE}Deployment Order: Analytics Engine → Backend → Web${NC}"
    echo -e ""
    
    parse_arguments "$@"
    validate_config
    
    # 按正确顺序部署
    deploy_analytics_engine
    deploy_backend  
    deploy_web
    
    show_deployment_summary
}

# 执行主函数
main "$@" 