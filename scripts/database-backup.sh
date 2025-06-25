#!/bin/bash
# 🗄️ V7项目数据库备份和恢复脚本
# 确保生产数据安全的完整解决方案

set -euo pipefail

# 🎨 颜色配置
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 📝 日志函数
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"; }

# 📊 配置变量
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly DEPLOY_PATH="${DEPLOY_PATH:-../v7-project}"
readonly DATA_DIR="${DEPLOY_PATH}/data"
readonly BACKUP_DIR="${DEPLOY_PATH}/backups/database"
readonly DATABASE_FILE="${DATA_DIR}/prod.db"

# 📁 初始化备份目录
init_backup_dirs() {
    info "初始化备份目录结构..."
    mkdir -p "$BACKUP_DIR"/{daily,weekly,monthly}
    chmod 755 "$BACKUP_DIR"
    log "备份目录初始化完成"
}

# 💾 创建数据库备份
create_backup() {
    local backup_type="${1:-manual}"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_name="v7_database_${backup_type}_${timestamp}"
    
    info "开始创建数据库备份: $backup_name"
    
    # 检查数据库文件是否存在
    if [[ ! -f "$DATABASE_FILE" ]]; then
        error "数据库文件不存在: $DATABASE_FILE"
        return 1
    fi
    
    # 选择备份目录
    local target_dir="$BACKUP_DIR"
    case $backup_type in
        "daily")   target_dir="$BACKUP_DIR/daily" ;;
        "weekly")  target_dir="$BACKUP_DIR/weekly" ;;
        "monthly") target_dir="$BACKUP_DIR/monthly" ;;
        *)         target_dir="$BACKUP_DIR" ;;
    esac
    
    local backup_file="$target_dir/${backup_name}.db"
    local backup_info="$target_dir/${backup_name}.info"
    
    # 创建备份（使用SQLite的backup命令确保一致性）
    if command -v sqlite3 &> /dev/null; then
        # 使用SQLite backup命令（热备份，不锁定数据库）
        sqlite3 "$DATABASE_FILE" ".backup '$backup_file'"
        
        # 验证备份文件完整性
        if sqlite3 "$backup_file" "PRAGMA integrity_check;" | grep -q "ok"; then
            log "数据库备份创建成功: $backup_file"
        else
            error "备份文件完整性检查失败"
            rm -f "$backup_file"
            return 1
        fi
    else
        # 备用方法：文件复制（需要停止服务）
        warn "SQLite3未安装，使用文件复制方法（建议停止服务）"
        cp "$DATABASE_FILE" "$backup_file"
        log "数据库文件复制完成: $backup_file"
    fi
    
    # 创建备份信息文件
    cat > "$backup_info" << EOF
# V7数据库备份信息
备份名称: $backup_name
备份类型: $backup_type
创建时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)
源文件: $DATABASE_FILE
备份文件: $backup_file
文件大小: $(du -h "$backup_file" | cut -f1)
MD5校验: $(md5sum "$backup_file" | cut -d' ' -f1)

# 数据库统计信息
EOF
    
    # 添加数据库统计信息
    if command -v sqlite3 &> /dev/null; then
        echo "表数量: $(sqlite3 "$backup_file" ".tables" | wc -w)" >> "$backup_info"
        echo "数据库大小: $(sqlite3 "$backup_file" "PRAGMA page_count;" | head -1) 页" >> "$backup_info"
        echo "数据库版本: $(sqlite3 "$backup_file" "PRAGMA user_version;" | head -1)" >> "$backup_info"
    fi
    
    # 压缩备份文件（可选）
    if command -v gzip &> /dev/null && [[ "${COMPRESS_BACKUP:-true}" == "true" ]]; then
        gzip "$backup_file"
        backup_file="${backup_file}.gz"
        log "备份文件已压缩: $backup_file"
    fi
    
    log "数据库备份完成: $backup_name"
    echo "$backup_file"
}

# 🔄 恢复数据库
restore_backup() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        error "请指定要恢复的备份文件"
        return 1
    fi
    
    # 检查备份文件是否存在
    if [[ ! -f "$backup_file" ]]; then
        # 尝试查找压缩文件
        if [[ -f "${backup_file}.gz" ]]; then
            backup_file="${backup_file}.gz"
        else
            error "备份文件不存在: $backup_file"
            return 1
        fi
    fi
    
    info "开始恢复数据库: $backup_file"
    
    # 创建当前数据库的安全备份
    if [[ -f "$DATABASE_FILE" ]]; then
        local safety_backup="${DATABASE_FILE}.before_restore_$(date +%Y%m%d_%H%M%S)"
        cp "$DATABASE_FILE" "$safety_backup"
        log "已创建安全备份: $safety_backup"
    fi
    
    # 解压缩（如果需要）
    local temp_backup="$backup_file"
    if [[ "$backup_file" =~ \.gz$ ]]; then
        temp_backup="/tmp/v7_restore_$(date +%Y%m%d_%H%M%S).db"
        gunzip -c "$backup_file" > "$temp_backup"
        log "备份文件已解压缩"
    fi
    
    # 验证备份文件完整性
    if command -v sqlite3 &> /dev/null; then
        if ! sqlite3 "$temp_backup" "PRAGMA integrity_check;" | grep -q "ok"; then
            error "备份文件损坏，无法恢复"
            [[ "$temp_backup" != "$backup_file" ]] && rm -f "$temp_backup"
            return 1
        fi
        log "备份文件完整性验证通过"
    fi
    
    # 停止相关服务（可选）
    if command -v podman-compose &> /dev/null && [[ -f "$DEPLOY_PATH/podman-compose.yml" ]]; then
        warn "建议停止服务以确保数据一致性"
        read -p "是否停止v7服务？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "停止v7服务..."
            cd "$DEPLOY_PATH" && podman-compose stop backend
        fi
    fi
    
    # 恢复数据库
    cp "$temp_backup" "$DATABASE_FILE"
    chmod 644 "$DATABASE_FILE"
    chown 1001:1001 "$DATABASE_FILE" 2>/dev/null || true
    
    # 清理临时文件
    [[ "$temp_backup" != "$backup_file" ]] && rm -f "$temp_backup"
    
    log "数据库恢复完成: $DATABASE_FILE"
    
    # 重启服务（如果之前停止了）
    if command -v podman-compose &> /dev/null && [[ -f "$DEPLOY_PATH/podman-compose.yml" ]]; then
        read -p "是否重启v7服务？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "重启v7服务..."
            cd "$DEPLOY_PATH" && podman-compose start backend
        fi
    fi
}

# 📋 列出可用备份
list_backups() {
    info "可用的数据库备份:"
    echo
    
    for backup_dir in "$BACKUP_DIR" "$BACKUP_DIR/daily" "$BACKUP_DIR/weekly" "$BACKUP_DIR/monthly"; do
        if [[ -d "$backup_dir" ]]; then
            local dir_name=$(basename "$backup_dir")
            [[ "$dir_name" == "database" ]] && dir_name="manual"
            
            echo -e "${BLUE}📁 $dir_name 备份:${NC}"
            
            local found_backups=false
            for backup_file in "$backup_dir"/v7_database_*.{db,db.gz}; do
                if [[ -f "$backup_file" ]]; then
                    found_backups=true
                    local file_name=$(basename "$backup_file")
                    local file_size=$(du -h "$backup_file" | cut -f1)
                    local file_date=$(stat -c %y "$backup_file" | cut -d' ' -f1)
                    
                    echo "  📄 $file_name ($file_size, $file_date)"
                    
                    # 显示备份信息（如果存在）
                    local info_file="${backup_file%.*}.info"
                    [[ "$backup_file" =~ \.gz$ ]] && info_file="${backup_file%.db.gz}.info"
                    if [[ -f "$info_file" ]]; then
                        local md5_hash=$(grep "MD5校验:" "$info_file" | cut -d' ' -f2)
                        [[ -n "$md5_hash" ]] && echo "     MD5: $md5_hash"
                    fi
                fi
            done
            
            if [[ "$found_backups" == "false" ]]; then
                echo "  (无备份文件)"
            fi
            echo
        fi
    done
}

# 🧹 清理旧备份
cleanup_old_backups() {
    info "清理旧备份文件..."
    
    # 清理daily备份（保留7天）
    find "$BACKUP_DIR/daily" -name "v7_database_daily_*" -type f -mtime +7 -delete 2>/dev/null || true
    
    # 清理weekly备份（保留4周）
    find "$BACKUP_DIR/weekly" -name "v7_database_weekly_*" -type f -mtime +28 -delete 2>/dev/null || true
    
    # 清理monthly备份（保留12个月）
    find "$BACKUP_DIR/monthly" -name "v7_database_monthly_*" -type f -mtime +365 -delete 2>/dev/null || true
    
    # 清理manual备份（保留30天）
    find "$BACKUP_DIR" -maxdepth 1 -name "v7_database_manual_*" -type f -mtime +30 -delete 2>/dev/null || true
    
    log "旧备份清理完成"
}

# 📊 数据库状态检查
check_database_status() {
    info "检查数据库状态..."
    
    if [[ ! -f "$DATABASE_FILE" ]]; then
        warn "数据库文件不存在: $DATABASE_FILE"
        return 1
    fi
    
    echo -e "${BLUE}📊 数据库信息:${NC}"
    echo "  📁 文件路径: $DATABASE_FILE"
    echo "  📏 文件大小: $(du -h "$DATABASE_FILE" | cut -f1)"
    echo "  📅 修改时间: $(stat -c %y "$DATABASE_FILE")"
    echo "  🔒 文件权限: $(stat -c %A "$DATABASE_FILE")"
    echo "  👤 文件所有者: $(stat -c %U:%G "$DATABASE_FILE")"
    
    if command -v sqlite3 &> /dev/null; then
        echo "  🗂️  表数量: $(sqlite3 "$DATABASE_FILE" ".tables" | wc -w)"
        echo "  📄 页数量: $(sqlite3 "$DATABASE_FILE" "PRAGMA page_count;")"
        echo "  🔢 用户版本: $(sqlite3 "$DATABASE_FILE" "PRAGMA user_version;")"
        
        # 完整性检查
        if sqlite3 "$DATABASE_FILE" "PRAGMA integrity_check;" | grep -q "ok"; then
            echo "  ✅ 完整性检查: 通过"
        else
            echo "  ❌ 完整性检查: 失败"
        fi
    fi
}

# 📅 自动备份调度
schedule_backups() {
    info "设置自动备份调度..."
    
    # 创建cron任务脚本
    local cron_script="$DEPLOY_PATH/scripts/auto-backup.sh"
    cat > "$cron_script" << EOF
#!/bin/bash
# V7数据库自动备份脚本
cd "$(dirname "\$0")"

# 每日备份
if [[ "\$(date +%H)" == "02" ]]; then
    ./database-backup.sh backup daily
fi

# 每周备份（周日）
if [[ "\$(date +%w)" == "0" && "\$(date +%H)" == "03" ]]; then
    ./database-backup.sh backup weekly
fi

# 每月备份（每月1号）
if [[ "\$(date +%d)" == "01" && "\$(date +%H)" == "04" ]]; then
    ./database-backup.sh backup monthly
fi

# 清理旧备份
./database-backup.sh cleanup
EOF
    
    chmod +x "$cron_script"
    
    echo "自动备份脚本已创建: $cron_script"
    echo
    echo "要启用自动备份，请添加以下cron任务:"
    echo "0 2-4 * * * $cron_script"
    echo
    echo "或运行: crontab -e 并添加上述行"
}

# 📖 显示帮助信息
show_help() {
    echo -e "${BLUE}🗄️ V7数据库备份和恢复工具${NC}"
    echo
    echo "用法: $0 <command> [options]"
    echo
    echo "命令:"
    echo "  backup [type]     - 创建数据库备份"
    echo "                      type: manual(默认), daily, weekly, monthly"
    echo "  restore <file>    - 从备份文件恢复数据库"
    echo "  list             - 列出所有可用备份"
    echo "  cleanup          - 清理旧备份文件"
    echo "  status           - 检查数据库状态"
    echo "  schedule         - 设置自动备份调度"
    echo "  help             - 显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 backup daily              # 创建每日备份"
    echo "  $0 restore backup_file.db    # 恢复指定备份"
    echo "  $0 list                      # 列出所有备份"
    echo "  $0 status                    # 检查数据库状态"
    echo
    echo "环境变量:"
    echo "  DEPLOY_PATH      - 部署路径 (默认: ../v7-project)"
    echo "  COMPRESS_BACKUP  - 压缩备份 (默认: true)"
}

# 🎯 主函数
main() {
    case "${1:-help}" in
        "backup")
            init_backup_dirs
            create_backup "${2:-manual}"
            ;;
        "restore")
            if [[ -z "${2:-}" ]]; then
                error "请指定要恢复的备份文件"
                exit 1
            fi
            restore_backup "$2"
            ;;
        "list")
            list_backups
            ;;
        "cleanup")
            cleanup_old_backups
            ;;
        "status")
            check_database_status
            ;;
        "schedule")
            schedule_backups
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
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 