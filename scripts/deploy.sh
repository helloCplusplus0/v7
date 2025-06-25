#!/bin/bash
# 🚀 V7 Project Deployment Script
# 适用于轻量级云服务器的完整部署解决方案

set -euo pipefail

# 🎨 颜色配置
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 📝 日志函数
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"; }
step() { echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] 🔄 $1${NC}"; }

# 📊 配置变量
readonly DEPLOY_PATH="${DEPLOY_PATH:-/home/deploy/containers/v7-project}"
readonly BACKUP_DIR="${DEPLOY_PATH}/backups"
readonly LOG_DIR="${DEPLOY_PATH}/logs"
readonly DATA_DIR="${DEPLOY_PATH}/data"
readonly BACKEND_IMAGE="${BACKEND_IMAGE:-ghcr.io/hellocplusplus0/v7/backend:latest}"
readonly WEB_IMAGE="${WEB_IMAGE:-ghcr.io/hellocplusplus0/v7/web:latest}"
readonly MAX_DEPLOY_TIME=600  # 10分钟超时
readonly HEALTH_CHECK_RETRIES=30
readonly HEALTH_CHECK_INTERVAL=10

# 🔍 环境检查
check_prerequisites() {
    step "检查部署环境..."
    
    # 检查必要工具
    local tools=("podman" "podman-compose" "curl" "jq")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "缺少必要工具: $tool"
            exit 1
        fi
    done
    
    # 检查用户权限
    if [[ $EUID -eq 0 ]]; then
        warn "不建议以root用户运行部署脚本"
    fi
    
    # 检查磁盘空间
    local available_space=$(df "$DEPLOY_PATH" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if [[ $available_space -lt 1048576 ]]; then  # 1GB
        warn "可用磁盘空间不足1GB，当前: $(($available_space/1024))MB"
    fi
    
    # 检查内存
    local available_memory=$(free | awk 'NR==2{printf "%.0f", $7/1024}')
    if [[ $available_memory -lt 512 ]]; then
        warn "可用内存不足512MB，当前: ${available_memory}MB"
    fi
    
    log "环境检查通过"
}

# 📁 准备部署目录
prepare_directories() {
    step "准备部署目录结构..."
    
    mkdir -p "$DEPLOY_PATH"/{data,logs/{backend,web},backups,scripts}
    chmod 755 "$DEPLOY_PATH"
    
    # 设置日志轮转
    if [[ ! -f "$LOG_DIR/logrotate.conf" ]]; then
        cat > "$LOG_DIR/logrotate.conf" << 'EOF'
/var/log/v7/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 deploy deploy
}
EOF
    fi
    
    log "目录结构准备完成"
}

# 💾 备份现有数据
backup_data() {
    step "备份现有数据..."
    
    local backup_timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_name="backup_${backup_timestamp}"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    mkdir -p "$backup_path"
    
    # 备份数据库
    if [[ -f "$DATA_DIR/prod.db" ]]; then
        cp "$DATA_DIR/prod.db" "$backup_path/prod.db"
        log "数据库备份完成: $backup_path/prod.db"
    fi
    
    # 备份配置文件
    if [[ -f "$DEPLOY_PATH/podman-compose.yml" ]]; then
        cp "$DEPLOY_PATH/podman-compose.yml" "$backup_path/"
        cp "$DEPLOY_PATH/.env" "$backup_path/" 2>/dev/null || true
    fi
    
    # 备份日志
    if [[ -d "$LOG_DIR" ]]; then
        tar -czf "$backup_path/logs.tar.gz" -C "$LOG_DIR" . 2>/dev/null || true
    fi
    
    # 清理旧备份（保留最近7天）
    find "$BACKUP_DIR" -name "backup_*" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    
    log "备份完成: $backup_name"
    echo "$backup_name" > "$BACKUP_DIR/latest_backup"
}

# 🔐 容器注册表认证
authenticate_registry() {
    step "认证容器注册表..."
    
    # 检查是否已经认证
    if podman login ghcr.io --get-login 2>/dev/null | grep -q "hellocplusplus0"; then
        log "已经认证到GHCR"
        return 0
    fi
    
    # 尝试多种认证方式
    local auth_success=false
    
    # 方式1: 使用环境变量中的token
    if [[ -n "${GHCR_TOKEN:-}" ]]; then
        info "尝试使用GHCR_TOKEN认证..."
        if echo "$GHCR_TOKEN" | podman login ghcr.io -u hellocplusplus0 --password-stdin; then
            log "使用GHCR_TOKEN认证成功"
            auth_success=true
        else
            warn "GHCR_TOKEN认证失败"
        fi
    fi
    
    # 方式2: 使用GitHub Token
    if [[ "$auth_success" != "true" && -n "${GITHUB_TOKEN:-}" ]]; then
        info "尝试使用GITHUB_TOKEN认证..."
        if echo "$GITHUB_TOKEN" | podman login ghcr.io -u hellocplusplus0 --password-stdin; then
            log "使用GITHUB_TOKEN认证成功"
            auth_success=true
        else
            warn "GITHUB_TOKEN认证失败"
        fi
    fi
    
    # 方式3: 检查是否有保存的认证信息
    if [[ "$auth_success" != "true" ]]; then
        info "检查本地保存的认证信息..."
        if podman login ghcr.io --get-login >/dev/null 2>&1; then
            log "使用本地保存的认证信息"
            auth_success=true
        fi
    fi
    
    # 方式4: 尝试从文件读取token
    local token_file="$HOME/.ghcr_token"
    if [[ "$auth_success" != "true" && -f "$token_file" ]]; then
        info "尝试从文件读取token: $token_file"
        if GHCR_TOKEN=$(cat "$token_file") && [[ -n "$GHCR_TOKEN" ]]; then
            if echo "$GHCR_TOKEN" | podman login ghcr.io -u hellocplusplus0 --password-stdin; then
                log "使用文件token认证成功"
                auth_success=true
            fi
        fi
    fi
    
    if [[ "$auth_success" != "true" ]]; then
        error "容器注册表认证失败"
        echo ""
        echo "🔧 解决方案："
        echo "1. 设置环境变量 GHCR_TOKEN 或 GITHUB_TOKEN"
        echo "2. 手动执行: podman login ghcr.io -u hellocplusplus0"
        echo "3. 将token保存到文件: ~/.ghcr_token"
        echo ""
        echo "📝 获取token方法："
        echo "1. 访问 https://github.com/settings/tokens"
        echo "2. 创建Personal Access Token"
        echo "3. 勾选权限: write:packages, read:packages"
        echo ""
        return 1
    fi
    
    # 验证认证状态
    if podman login ghcr.io --get-login 2>/dev/null | grep -q "hellocplusplus0"; then
        log "容器注册表认证验证成功"
    else
        error "认证验证失败"
        return 1
    fi
}

# 🐳 拉取和验证镜像
pull_images() {
    step "拉取最新镜像..."
    
    # 执行认证
    if ! authenticate_registry; then
        error "容器注册表认证失败，无法拉取镜像"
        exit 1
    fi
    
    # 拉取后端镜像
    if ! podman pull "$BACKEND_IMAGE"; then
        error "拉取后端镜像失败: $BACKEND_IMAGE"
        exit 1
    fi
    
    # 拉取前端镜像
    if ! podman pull "$WEB_IMAGE"; then
        error "拉取前端镜像失败: $WEB_IMAGE"
        exit 1
    fi
    
    # 验证镜像
    local backend_digest=$(podman inspect "$BACKEND_IMAGE" --format '{{.Digest}}' 2>/dev/null || echo "unknown")
    local web_digest=$(podman inspect "$WEB_IMAGE" --format '{{.Digest}}' 2>/dev/null || echo "unknown")
    
    info "后端镜像摘要: $backend_digest"
    info "前端镜像摘要: $web_digest"
    
    log "镜像拉取完成"
}

# 🛑 停止现有服务
stop_services() {
    step "停止现有服务..."
    
    cd "$DEPLOY_PATH"
    
    if [[ -f "podman-compose.yml" ]]; then
        # 优雅停止服务
        timeout 120 podman-compose down --remove-orphans || {
            warn "优雅停止超时，强制停止"
            podman-compose kill
            podman-compose down --remove-orphans --volumes
        }
    fi
    
    # 清理孤立容器
    podman container prune -f
    
    log "服务停止完成"
}

# 📝 生成配置文件
generate_config() {
    step "生成配置文件..."
    
    # 生成环境变量文件
    cat > "$DEPLOY_PATH/.env" << EOF
# V7 Project Environment Configuration
# Generated: $(date)

# Images
BACKEND_IMAGE=$BACKEND_IMAGE
WEB_IMAGE=$WEB_IMAGE

# Database
DATABASE_URL=${DATABASE_URL:-sqlite:./data/prod.db}

# Logging
RUST_LOG=${RUST_LOG:-info}

# Environment
NODE_ENV=${NODE_ENV:-production}

# Timezone
TZ=Asia/Shanghai
EOF

    # 确保compose文件存在
    if [[ ! -f "$DEPLOY_PATH/podman-compose.yml" ]]; then
        error "podman-compose.yml文件不存在"
        exit 1
    fi
    
    log "配置文件生成完成"
}

# 🚀 启动服务
start_services() {
    step "启动服务..."
    
    cd "$DEPLOY_PATH"
    
    # 启动服务
    if ! timeout $MAX_DEPLOY_TIME podman-compose up -d; then
        error "服务启动失败"
        exit 1
    fi
    
    log "服务启动命令执行完成"
}

# 🏥 健康检查
health_check() {
    step "执行健康检查..."
    
    # 等待容器启动
    sleep 30
    
    # 检查容器状态
    info "检查容器状态..."
    podman-compose ps
    
    # 检查后端健康状态
    info "检查后端服务健康状态..."
    local backend_healthy=false
    for ((i=1; i<=HEALTH_CHECK_RETRIES; i++)); do
        if curl -f -s "http://localhost:3000/health" >/dev/null 2>&1; then
            log "后端服务健康检查通过"
            backend_healthy=true
            break
        fi
        warn "等待后端服务启动... ($i/$HEALTH_CHECK_RETRIES)"
        sleep $HEALTH_CHECK_INTERVAL
    done
    
    if [[ "$backend_healthy" != "true" ]]; then
        error "后端服务健康检查失败"
        show_logs
        exit 1
    fi
    
    # 检查前端健康状态
    info "检查前端服务健康状态..."
    local web_healthy=false
    for ((i=1; i<=HEALTH_CHECK_RETRIES; i++)); do
        if curl -f -s "http://localhost:8080/health" >/dev/null 2>&1; then
            log "前端服务健康检查通过"
            web_healthy=true
            break
        fi
        warn "等待前端服务启动... ($i/$HEALTH_CHECK_RETRIES)"
        sleep $HEALTH_CHECK_INTERVAL
    done
    
    if [[ "$web_healthy" != "true" ]]; then
        error "前端服务健康检查失败"
        show_logs
        exit 1
    fi
    
    log "所有服务健康检查通过"
}

# 🧪 功能测试
smoke_test() {
    step "执行冒烟测试..."
    
    # 测试API端点
    local tests=(
        "http://localhost:3000/health::Backend Health"
        "http://localhost:8080/health::Frontend Health"
        "http://localhost:3000/api/items::MVP CRUD API"
    )
    
    for test in "${tests[@]}"; do
        local url=$(echo "$test" | cut -d':' -f1)
        local name=$(echo "$test" | cut -d':' -f3)
        
        info "测试 $name..."
        if curl -f -s "$url" >/dev/null; then
            log "$name 测试通过"
        else
            error "$name 测试失败"
            exit 1
        fi
    done
    
    log "冒烟测试完成"
}

# 📊 显示部署信息
show_deployment_info() {
    step "部署信息总结..."
    
    echo ""
    echo -e "${CYAN}🎉 部署成功完成！${NC}"
    echo ""
    echo -e "${BLUE}📋 服务信息:${NC}"
    echo -e "  🌐 前端访问地址: http://$(curl -s ifconfig.me):8080"
    echo -e "  🔧 后端API地址:  http://$(curl -s ifconfig.me):3000"
    echo -e "  📊 健康检查:     http://$(curl -s ifconfig.me):3000/health"
    echo ""
    echo -e "${BLUE}📁 重要路径:${NC}"
    echo -e "  📂 部署目录: $DEPLOY_PATH"
    echo -e "  💾 数据目录: $DATA_DIR"
    echo -e "  📜 日志目录: $LOG_DIR"
    echo -e "  🗄️  备份目录: $BACKUP_DIR"
    echo ""
    echo -e "${BLUE}💻 系统资源:${NC}"
    echo -e "  🖥️  CPU使用: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    echo -e "  🧠 内存使用: $(free -h | awk '/^Mem:/ {print $3"/"$2}')"
    echo -e "  💽 磁盘使用: $(df -h "$DEPLOY_PATH" | awk 'NR==2 {print $3"/"$2" ("$5")"}')"
    echo ""
    echo -e "${BLUE}🐳 容器状态:${NC}"
    podman-compose ps
    echo ""
}

# 📜 显示日志
show_logs() {
    warn "显示最近的服务日志..."
    echo ""
    echo -e "${CYAN}=== 后端服务日志 ===${NC}"
    podman-compose logs --tail=20 backend || true
    echo ""
    echo -e "${CYAN}=== 前端服务日志 ===${NC}"
    podman-compose logs --tail=20 web || true
}

# 🔄 回滚功能
rollback() {
    error "部署失败，开始回滚..."
    
    local latest_backup=$(cat "$BACKUP_DIR/latest_backup" 2>/dev/null || echo "")
    if [[ -z "$latest_backup" ]]; then
        error "找不到备份，无法回滚"
        exit 1
    fi
    
    local backup_path="$BACKUP_DIR/$latest_backup"
    if [[ ! -d "$backup_path" ]]; then
        error "备份目录不存在: $backup_path"
        exit 1
    fi
    
    step "从备份回滚: $latest_backup"
    
    # 停止当前服务
    podman-compose down --remove-orphans || true
    
    # 恢复数据
    if [[ -f "$backup_path/prod.db" ]]; then
        cp "$backup_path/prod.db" "$DATA_DIR/"
        log "数据库回滚完成"
    fi
    
    # 恢复配置
    if [[ -f "$backup_path/podman-compose.yml" ]]; then
        cp "$backup_path/podman-compose.yml" "$DEPLOY_PATH/"
        cp "$backup_path/.env" "$DEPLOY_PATH/" 2>/dev/null || true
        log "配置文件回滚完成"
    fi
    
    # 重启服务
    podman-compose up -d
    
    log "回滚完成"
}

# 🧹 清理资源
cleanup() {
    step "清理资源..."
    
    # 清理未使用的镜像
    podman image prune -f
    
    # 清理旧镜像（保留最近3个版本）
    local backend_images=$(podman images --format "{{.Repository}}:{{.Tag}} {{.Created}}" | \
                          grep "$(echo "$BACKEND_IMAGE" | cut -d':' -f1)" | \
                          sort -k2 -r | tail -n +4 | awk '{print $1}')
    local web_images=$(podman images --format "{{.Repository}}:{{.Tag}} {{.Created}}" | \
                      grep "$(echo "$WEB_IMAGE" | cut -d':' -f1)" | \
                      sort -k2 -r | tail -n +4 | awk '{print $1}')
    
    for image in $backend_images $web_images; do
        podman rmi "$image" 2>/dev/null || true
    done
    
    log "资源清理完成"
}

# 🎯 主函数
main() {
    echo -e "${PURPLE}"
    echo "🚀 V7 Project Deployment Script"
    echo "==============================="
    echo -e "${NC}"
    
    # 错误处理
    trap 'error "部署过程中发生错误"; show_logs; rollback; exit 1' ERR
    
    # 执行部署流程
    check_prerequisites
    prepare_directories
    backup_data
    pull_images
    stop_services
    generate_config
    start_services
    health_check
    smoke_test
    cleanup
    show_deployment_info
    
    log "部署流程全部完成！"
}

# 🚀 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 