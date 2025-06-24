#!/bin/bash
# 🔍 V7 Podman 轻量化监控脚本
# 专为轻量级服务器(2核2G)设计的监控解决方案

set -euo pipefail

# 🎨 颜色输出配置
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
debug() { echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] 🔍 $1${NC}"; }

# 🔧 配置变量
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly DEPLOY_PATH="${DEPLOY_PATH:-/opt/v7}"
readonly LOG_PATH="${LOG_PATH:-$DEPLOY_PATH/logs}"
readonly MONITOR_LOG="$LOG_PATH/monitor.log"

# 🌍 环境配置
readonly BACKEND_PORT="${BACKEND_PORT:-3000}"
readonly WEB_PORT="${WEB_PORT:-8080}"
readonly MONITOR_INTERVAL="${MONITOR_INTERVAL:-30}"
readonly ALERT_THRESHOLD_CPU="${ALERT_THRESHOLD_CPU:-80}"
readonly ALERT_THRESHOLD_MEMORY="${ALERT_THRESHOLD_MEMORY:-85}"
readonly ALERT_THRESHOLD_DISK="${ALERT_THRESHOLD_DISK:-90}"

# 📊 性能阈值配置（轻量级服务器）
readonly MAX_LOAD_AVERAGE="2.0"
readonly MIN_FREE_MEMORY="200"  # MB
readonly MIN_FREE_DISK="1"      # GB

# 🏥 健康检查函数
check_service_health() {
    local service_name="$1"
    local port="$2"
    local endpoint="${3:-/health}"
    
    if curl -sf "http://localhost:$port$endpoint" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 📊 获取容器状态函数
get_container_status() {
    local container_name="$1"
    
    if podman ps --format "{{.Names}}" | grep -q "^$container_name$"; then
        echo "running"
    elif podman ps -a --format "{{.Names}}" | grep -q "^$container_name$"; then
        echo "stopped"
    else
        echo "missing"
    fi
}

# 📈 获取容器资源使用情况
get_container_stats() {
    local container_name="$1"
    
    if [ "$(get_container_status "$container_name")" = "running" ]; then
        # 获取容器统计信息
        local stats=$(podman stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}}" "$container_name" 2>/dev/null || echo "0%,0B / 0B,0%")
        echo "$stats"
    else
        echo "0%,0B / 0B,0%"
    fi
}

# 💻 获取系统资源使用情况
get_system_resources() {
    # CPU使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    # 内存使用情况
    local memory_info=$(free -m | awk '/^Mem:/ {printf "%.1f,%.1f,%.1f", $3, $2, ($3/$2)*100}')
    
    # 磁盘使用情况
    local disk_info=$(df -h "$DEPLOY_PATH" | awk 'NR==2 {gsub("%","",$5); printf "%s,%.1f", $5, ($2=="1K"?$4/1024/1024:substr($4,1,length($4)-1))}')
    
    # 负载平均值
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    
    echo "$cpu_usage,$memory_info,$disk_info,$load_avg"
}

# 🌐 检查网络连接
check_network_connectivity() {
    local backend_status="❌"
    local web_status="❌"
    local external_status="❌"
    
    # 检查后端服务
    if check_service_health "backend" "$BACKEND_PORT"; then
        backend_status="✅"
    fi
    
    # 检查前端服务
    if check_service_health "web" "$WEB_PORT"; then
        web_status="✅"
    fi
    
    # 检查外部网络连接
    if ping -c 1 8.8.8.8 &>/dev/null; then
        external_status="✅"
    fi
    
    echo "$backend_status,$web_status,$external_status"
}

# 🗄️ 检查数据库状态
check_database_status() {
    local db_status="❌"
    local db_size="0"
    local db_path="$DEPLOY_PATH/data/prod.db"
    
    if [ -f "$db_path" ]; then
        db_status="✅"
        db_size=$(du -h "$db_path" | cut -f1)
    fi
    
    echo "$db_status,$db_size"
}

# 📝 记录监控日志
log_monitoring_data() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    local system_resources=$(get_system_resources)
    local backend_stats=$(get_container_stats "v7-backend")
    local web_stats=$(get_container_stats "v7-web")
    local network_status=$(check_network_connectivity)
    local db_status=$(check_database_status)
    
    # 创建日志目录
    mkdir -p "$(dirname "$MONITOR_LOG")"
    
    # 写入CSV格式的监控数据
    echo "$timestamp,$system_resources,$backend_stats,$web_stats,$network_status,$db_status" >> "$MONITOR_LOG"
}

# 🚨 检查告警条件
check_alerts() {
    local system_resources=$(get_system_resources)
    IFS=',' read -ra RESOURCES <<< "$system_resources"
    
    local cpu_usage=${RESOURCES[0]}
    local memory_used=${RESOURCES[1]}
    local memory_total=${RESOURCES[2]}
    local memory_percent=${RESOURCES[3]}
    local disk_percent=${RESOURCES[4]}
    local disk_free=${RESOURCES[5]}
    local load_avg=${RESOURCES[6]}
    
    local alerts=()
    
    # CPU使用率告警
    if (( $(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        alerts+=("🔥 CPU使用率过高: ${cpu_usage}% (阈值: ${ALERT_THRESHOLD_CPU}%)")
    fi
    
    # 内存使用率告警
    if (( $(echo "$memory_percent > $ALERT_THRESHOLD_MEMORY" | bc -l) )); then
        alerts+=("💾 内存使用率过高: ${memory_percent}% (阈值: ${ALERT_THRESHOLD_MEMORY}%)")
    fi
    
    # 磁盘使用率告警
    if (( $(echo "$disk_percent > $ALERT_THRESHOLD_DISK" | bc -l) )); then
        alerts+=("💿 磁盘使用率过高: ${disk_percent}% (阈值: ${ALERT_THRESHOLD_DISK}%)")
    fi
    
    # 负载平均值告警
    if (( $(echo "$load_avg > $MAX_LOAD_AVERAGE" | bc -l) )); then
        alerts+=("⚡ 系统负载过高: $load_avg (阈值: $MAX_LOAD_AVERAGE)")
    fi
    
    # 可用内存告警
    if (( $(echo "$memory_total - $memory_used < $MIN_FREE_MEMORY" | bc -l) )); then
        alerts+=("🚨 可用内存不足: $(echo "$memory_total - $memory_used" | bc)MB (阈值: ${MIN_FREE_MEMORY}MB)")
    fi
    
    # 可用磁盘空间告警
    if (( $(echo "$disk_free < $MIN_FREE_DISK" | bc -l) )); then
        alerts+=("💾 可用磁盘空间不足: ${disk_free}GB (阈值: ${MIN_FREE_DISK}GB)")
    fi
    
    # 服务健康检查告警
    if ! check_service_health "backend" "$BACKEND_PORT"; then
        alerts+=("🦀 后端服务不可用")
    fi
    
    if ! check_service_health "web" "$WEB_PORT"; then
        alerts+=("🌐 前端服务不可用")
    fi
    
    # 容器状态检查
    if [ "$(get_container_status "v7-backend")" != "running" ]; then
        alerts+=("📦 后端容器未运行")
    fi
    
    if [ "$(get_container_status "v7-web")" != "running" ]; then
        alerts+=("📦 前端容器未运行")
    fi
    
    # 输出告警信息
    if [ ${#alerts[@]} -gt 0 ]; then
        error "⚠️  发现 ${#alerts[@]} 个告警:"
        for alert in "${alerts[@]}"; do
            echo -e "${RED}  $alert${NC}"
        done
        return 1
    else
        return 0
    fi
}

# 📊 显示实时状态
show_realtime_status() {
    clear
    echo -e "${CYAN}==================== 🔍 V7 实时监控 ====================${NC}"
    echo "更新时间: $(date +'%Y-%m-%d %H:%M:%S')"
    echo
    
    # 系统资源状态
    local system_resources=$(get_system_resources)
    IFS=',' read -ra RESOURCES <<< "$system_resources"
    
    echo -e "${BLUE}💻 系统资源:${NC}"
    echo "  CPU使用率: ${RESOURCES[0]}%"
    echo "  内存使用: ${RESOURCES[1]}MB / ${RESOURCES[2]}MB (${RESOURCES[3]}%)"
    echo "  磁盘使用: ${RESOURCES[4]}% (可用: ${RESOURCES[5]}GB)"
    echo "  负载平均: ${RESOURCES[6]}"
    echo
    
    # 容器状态
    echo -e "${BLUE}📦 容器状态:${NC}"
    
    # 后端容器
    local backend_status=$(get_container_status "v7-backend")
    local backend_stats=$(get_container_stats "v7-backend")
    IFS=',' read -ra BACKEND <<< "$backend_stats"
    
    if [ "$backend_status" = "running" ]; then
        echo -e "  🦀 后端容器: ${GREEN}运行中${NC}"
        echo "    CPU: ${BACKEND[0]}, 内存: ${BACKEND[1]} (${BACKEND[2]})"
    else
        echo -e "  🦀 后端容器: ${RED}$backend_status${NC}"
    fi
    
    # 前端容器
    local web_status=$(get_container_status "v7-web")
    local web_stats=$(get_container_stats "v7-web")
    IFS=',' read -ra WEB <<< "$web_stats"
    
    if [ "$web_status" = "running" ]; then
        echo -e "  🌐 前端容器: ${GREEN}运行中${NC}"
        echo "    CPU: ${WEB[0]}, 内存: ${WEB[1]} (${WEB[2]})"
    else
        echo -e "  🌐 前端容器: ${RED}$web_status${NC}"
    fi
    echo
    
    # 服务健康状态
    echo -e "${BLUE}🏥 服务健康:${NC}"
    local network_status=$(check_network_connectivity)
    IFS=',' read -ra NETWORK <<< "$network_status"
    
    echo "  后端API (端口 $BACKEND_PORT): ${NETWORK[0]}"
    echo "  前端服务 (端口 $WEB_PORT): ${NETWORK[1]}"
    echo "  外部网络连接: ${NETWORK[2]}"
    echo
    
    # 数据库状态
    local db_status=$(check_database_status)
    IFS=',' read -ra DB <<< "$db_status"
    
    echo -e "${BLUE}🗄️  数据库状态:${NC}"
    echo "  数据库文件: ${DB[0]}"
    echo "  数据库大小: ${DB[1]}"
    echo
    
    # 访问地址
    echo -e "${BLUE}🌐 访问地址:${NC}"
    echo "  前端应用: http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
    echo "  后端API:  http://$(hostname -I | awk '{print $1}'):$BACKEND_PORT"
    echo
    
    # 检查告警
    if check_alerts &>/dev/null; then
        echo -e "${GREEN}✅ 系统状态正常${NC}"
    else
        echo -e "${RED}⚠️  发现告警，请检查上述状态${NC}"
    fi
    
    echo -e "${CYAN}=====================================================${NC}"
    echo "按 Ctrl+C 退出监控"
}

# 📈 生成监控报告
generate_report() {
    local report_file="$LOG_PATH/monitor_report_$(date +%Y%m%d_%H%M%S).txt"
    
    echo "🔍 V7 Podman 监控报告" > "$report_file"
    echo "生成时间: $(date)" >> "$report_file"
    echo "======================================" >> "$report_file"
    echo "" >> "$report_file"
    
    # 系统信息
    echo "📊 系统信息:" >> "$report_file"
    echo "操作系统: $(uname -a)" >> "$report_file"
    echo "Podman版本: $(podman --version)" >> "$report_file"
    echo "运行时间: $(uptime)" >> "$report_file"
    echo "" >> "$report_file"
    
    # 当前状态
    echo "📈 当前状态:" >> "$report_file"
    local system_resources=$(get_system_resources)
    IFS=',' read -ra RESOURCES <<< "$system_resources"
    echo "CPU使用率: ${RESOURCES[0]}%" >> "$report_file"
    echo "内存使用: ${RESOURCES[1]}MB / ${RESOURCES[2]}MB (${RESOURCES[3]}%)" >> "$report_file"
    echo "磁盘使用: ${RESOURCES[4]}% (可用: ${RESOURCES[5]}GB)" >> "$report_file"
    echo "负载平均: ${RESOURCES[6]}" >> "$report_file"
    echo "" >> "$report_file"
    
    # 容器状态
    echo "📦 容器状态:" >> "$report_file"
    echo "后端容器: $(get_container_status "v7-backend")" >> "$report_file"
    echo "前端容器: $(get_container_status "v7-web")" >> "$report_file"
    echo "" >> "$report_file"
    
    # 最近的监控日志
    if [ -f "$MONITOR_LOG" ]; then
        echo "📝 最近监控记录 (最后10条):" >> "$report_file"
        tail -10 "$MONITOR_LOG" >> "$report_file"
    fi
    
    log "监控报告已生成: $report_file"
}

# 🧹 清理日志文件
cleanup_logs() {
    info "清理监控日志文件..."
    
    # 清理超过7天的监控日志
    find "$LOG_PATH" -name "monitor*.log" -type f -mtime +7 -delete 2>/dev/null || true
    
    # 清理超过30天的报告文件
    find "$LOG_PATH" -name "monitor_report_*.txt" -type f -mtime +30 -delete 2>/dev/null || true
    
    # 如果监控日志文件过大，进行轮转
    if [ -f "$MONITOR_LOG" ] && [ $(stat -f%z "$MONITOR_LOG" 2>/dev/null || stat -c%s "$MONITOR_LOG") -gt 10485760 ]; then  # 10MB
        mv "$MONITOR_LOG" "${MONITOR_LOG}.$(date +%Y%m%d_%H%M%S)"
        touch "$MONITOR_LOG"
        log "监控日志已轮转"
    fi
    
    log "日志清理完成"
}

# 🔄 持续监控模式
continuous_monitoring() {
    info "启动持续监控模式 (间隔: ${MONITOR_INTERVAL}秒)"
    info "按 Ctrl+C 停止监控"
    
    # 设置信号处理
    trap 'info "停止监控..."; exit 0' SIGINT SIGTERM
    
    while true; do
        # 记录监控数据
        log_monitoring_data
        
        # 检查告警
        if ! check_alerts; then
            # 如果有告警，记录到单独的告警日志
            echo "$(date +'%Y-%m-%d %H:%M:%S') - 告警检测" >> "$LOG_PATH/alerts.log"
        fi
        
        # 等待下一次检查
        sleep "$MONITOR_INTERVAL"
    done
}

# 📋 显示帮助信息
show_help() {
    echo "🔍 V7 Podman 监控脚本"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "可用命令:"
    echo "  status      - 显示当前状态 (默认)"
    echo "  monitor     - 启动持续监控模式"
    echo "  realtime    - 显示实时状态面板"
    echo "  health      - 执行健康检查"
    echo "  alerts      - 检查告警条件"
    echo "  report      - 生成监控报告"
    echo "  cleanup     - 清理日志文件"
    echo "  help        - 显示此帮助信息"
    echo ""
    echo "环境变量:"
    echo "  DEPLOY_PATH              - 部署路径 (默认: /opt/v7)"
    echo "  BACKEND_PORT             - 后端端口 (默认: 3000)"
    echo "  WEB_PORT                 - 前端端口 (默认: 8080)"
    echo "  MONITOR_INTERVAL         - 监控间隔秒数 (默认: 30)"
    echo "  ALERT_THRESHOLD_CPU      - CPU告警阈值 (默认: 80%)"
    echo "  ALERT_THRESHOLD_MEMORY   - 内存告警阈值 (默认: 85%)"
    echo "  ALERT_THRESHOLD_DISK     - 磁盘告警阈值 (默认: 90%)"
    echo ""
    echo "示例:"
    echo "  $0 status                # 显示当前状态"
    echo "  $0 monitor               # 启动持续监控"
    echo "  MONITOR_INTERVAL=60 $0 monitor  # 60秒间隔监控"
}

# 🎯 主函数
main() {
    # 检查必要工具
    if ! command -v podman &> /dev/null; then
        error "Podman 未安装"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        warn "bc 计算器未安装，某些功能可能受限"
    fi
    
    # 创建日志目录
    mkdir -p "$LOG_PATH"
    
    case "${1:-status}" in
        "status")
            show_realtime_status
            ;;
        "monitor")
            continuous_monitoring
            ;;
        "realtime")
            while true; do
                show_realtime_status
                sleep 5
            done
            ;;
        "health")
            if check_service_health "backend" "$BACKEND_PORT" && check_service_health "web" "$WEB_PORT"; then
                log "所有服务健康"
                exit 0
            else
                error "服务健康检查失败"
                exit 1
            fi
            ;;
        "alerts")
            if check_alerts; then
                log "没有发现告警"
                exit 0
            else
                exit 1
            fi
            ;;
        "report")
            generate_report
            ;;
        "cleanup")
            cleanup_logs
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 🚀 脚本入口
main "$@" 