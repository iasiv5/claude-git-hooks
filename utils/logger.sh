#!/bin/bash

# Claude Code Git Hooks - 日志工具模块
# 提供统一的日志记录功能

# =============================================================================
# 全局变量
# =============================================================================

# 日志级别定义
readonly LOG_LEVEL_DEBUG="DEBUG"
readonly LOG_LEVEL_INFO="INFO"
readonly LOG_LEVEL_WARN="WARN"
readonly LOG_LEVEL_ERROR="ERROR"

# 日志级别数字映射
declare -A LOG_LEVEL_MAP=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
)

# 颜色输出定义
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[1;37m'
readonly COLOR_GRAY='\033[0;90m'

# 当前日志级别
CURRENT_LOG_LEVEL="${LOG_LEVEL:-"INFO"}"

# 日志文件路径
LOG_FILE_PATH="${LOG_FILE:-".claude-hooks.log"}"

# 是否启用彩色输出
ENABLE_COLOR_OUTPUT="${COLOR_OUTPUT:-true}"

# 是否启用文件日志
ENABLE_FILE_LOGGING="${ENABLE_FILE_LOGGING:-true}"

# 日志格式
LOG_FORMAT="[%timestamp%] [%level%] %message%"

# =============================================================================
# 配置函数
# =============================================================================

# 设置日志级别
set_log_level() {
    local level="$1"

    if [[ -n "${LOG_LEVEL_MAP[$level]}" ]]; then
        CURRENT_LOG_LEVEL="$level"
        log_debug "日志级别设置为: $level"
    else
        log_error "无效的日志级别: $level"
        return 1
    fi
}

# 启用/禁用彩色输出
set_color_output() {
    local enabled="$1"

    case "$enabled" in
        true|1|yes|on)
            ENABLE_COLOR_OUTPUT=true
            ;;
        false|0|no|off)
            ENABLE_COLOR_OUTPUT=false
            ;;
        *)
            log_error "无效的彩色输出设置: $enabled"
            return 1
            ;;
    esac
}

# 启用/禁用文件日志
set_file_logging() {
    local enabled="$1"

    case "$enabled" in
        true|1|yes|on)
            ENABLE_FILE_LOGGING=true
            ;;
        false|0|no|off)
            ENABLE_FILE_LOGGING=false
            ;;
        *)
            log_error "无效的文件日志设置: $enabled"
            return 1
            ;;
    esac
}

# 设置日志文件路径
set_log_file() {
    local file_path="$1"

    LOG_FILE_PATH="$file_path"
    log_debug "日志文件路径设置为: $file_path"
}

# 设置日志格式
set_log_format() {
    local format="$1"

    LOG_FORMAT="$format"
    log_debug "日志格式设置为: $format"
}

# =============================================================================
# 内部工具函数
# =============================================================================

# 获取当前时间戳
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S.%3N'
}

# 获取颜色代码
get_color() {
    local level="$1"

    if [[ "$ENABLE_COLOR_OUTPUT" != "true" ]]; then
        echo ""
        return
    fi

    case "$level" in
        DEBUG)
            echo "$COLOR_PURPLE"
            ;;
        INFO)
            echo "$COLOR_BLUE"
            ;;
        WARN)
            echo "$COLOR_YELLOW"
            ;;
        ERROR)
            echo "$COLOR_RED"
            ;;
        SUCCESS)
            echo "$COLOR_GREEN"
            ;;
        *)
            echo "$COLOR_WHITE"
            ;;
    esac
}

# 检查是否应该输出该级别的日志
should_log() {
    local level="$1"
    local current_level_num="${LOG_LEVEL_MAP[$CURRENT_LOG_LEVEL]}"
    local level_num="${LOG_LEVEL_MAP[$level]}"

    if [[ -z "$current_level_num" || -z "$level_num" ]]; then
        return 1
    fi

    [[ $level_num -ge $current_level_num ]]
}

# 格式化日志消息
format_message() {
    local level="$1"
    local message="$2"
    local timestamp="$3"

    local formatted="$LOG_FORMAT"
    formatted="${formatted//%timestamp%/$timestamp}"
    formatted="${formatted//%level%/$level}"
    formatted="${formatted//%message%/$message}"

    echo "$formatted"
}

# 写入日志文件
write_to_file() {
    local message="$1"

    if [[ "$ENABLE_FILE_LOGGING" != "true" ]]; then
        return
    fi

    # 确保日志文件存在
    touch "$LOG_FILE_PATH" 2>/dev/null || {
        echo "无法创建日志文件: $LOG_FILE_PATH" >&2
        return 1
    }

    # 写入日志（无颜色格式）
    local no_color_message
    no_color_message=$(echo "$message" | sed 's/\x1b\[[0-9;]*m//g')

    echo "$no_color_message" >> "$LOG_FILE_PATH"

    # 如果日志文件过大，进行轮转
    local file_size
    file_size=$(wc -c < "$LOG_FILE_PATH" 2>/dev/null || echo "0")

    if [[ $file_size -gt 10485760 ]]; then  # 10MB
        rotate_log_file
    fi
}

# 日志文件轮转
rotate_log_file() {
    local max_backups="${LOG_ROTATION_BACKUPS:-5}"
    local i

    # 删除最老的备份
    if [[ -f "${LOG_FILE_PATH}.${max_backups}" ]]; then
        rm -f "${LOG_FILE_PATH}.${max_backups}"
    fi

    # 轮转备份文件
    for ((i=max_backups-1; i>=1; i--)); do
        if [[ -f "${LOG_FILE_PATH}.${i}" ]]; then
            mv "${LOG_FILE_PATH}.${i}" "${LOG_FILE_PATH}.$((i+1))"
        fi
    done

    # 备份当前日志文件
    if [[ -f "$LOG_FILE_PATH" ]]; then
        mv "$LOG_FILE_PATH" "${LOG_FILE_PATH}.1"

        # 创建新的日志文件
        touch "$LOG_FILE_PATH"
        log_debug "日志文件已轮转，保留 $max_backups 个备份"
    fi
}

# =============================================================================
# 公共日志函数
# =============================================================================

# 调试日志
log_debug() {
    local message="$1"

    if ! should_log "DEBUG"; then
        return
    fi

    local timestamp
    timestamp=$(get_timestamp)
    local color
    color=$(get_color "DEBUG")
    local formatted_message
    formatted_message=$(format_message "DEBUG" "$message" "$timestamp")

    # 输出到控制台
    echo -e "${color}[DEBUG]${COLOR_RESET} $message" >&2

    # 写入文件
    write_to_file "[$timestamp] [DEBUG] $message"
}

# 信息日志
log_info() {
    local message="$1"

    if ! should_log "INFO"; then
        return
    fi

    local timestamp
    timestamp=$(get_timestamp)
    local color
    color=$(get_color "INFO")
    local formatted_message
    formatted_message=$(format_message "INFO" "$message" "$timestamp")

    # 输出到控制台
    echo -e "${color}[INFO]${COLOR_RESET} $message" >&2

    # 写入文件
    write_to_file "[$timestamp] [INFO] $message"
}

# 警告日志
log_warn() {
    local message="$1"

    if ! should_log "WARN"; then
        return
    fi

    local timestamp
    timestamp=$(get_timestamp)
    local color
    color=$(get_color "WARN")
    local formatted_message
    formatted_message=$(format_message "WARN" "$message" "$timestamp")

    # 输出到控制台
    echo -e "${color}[WARN]${COLOR_RESET} $message" >&2

    # 写入文件
    write_to_file "[$timestamp] [WARN] $message"
}

# 错误日志
log_error() {
    local message="$1"

    if ! should_log "ERROR"; then
        return
    fi

    local timestamp
    timestamp=$(get_timestamp)
    local color
    color=$(get_color "ERROR")
    local formatted_message
    formatted_message=$(format_message "ERROR" "$message" "$timestamp")

    # 输出到控制台
    echo -e "${color}[ERROR]${COLOR_RESET} $message" >&2

    # 写入文件
    write_to_file "[$timestamp] [ERROR] $message"
}

# 成功日志
log_success() {
    local message="$1"

    if ! should_log "INFO"; then
        return
    fi

    local timestamp
    timestamp=$(get_timestamp)
    local color
    color=$(get_color "SUCCESS")
    local formatted_message
    formatted_message=$(format_message "SUCCESS" "$message" "$timestamp")

    # 输出到控制台
    echo -e "${color}[SUCCESS]${COLOR_RESET} $message" >&2

    # 写入文件
    write_to_file "[$timestamp] [SUCCESS] $message"
}

# =============================================================================
# 高级日志函数
# =============================================================================

# 带标题的日志
log_header() {
    local title="$1"
    local level="${2:-INFO}"

    if ! should_log "$level"; then
        return
    fi

    local color
    color=$(get_color "$level")
    local separator
    separator=$(printf '=%.0s' {1..60})

    echo -e "\n${color}$separator${COLOR_RESET}" >&2
    echo -e "${color}  $title${COLOR_RESET}" >&2
    echo -e "${color}$separator${COLOR_RESET}\n" >&2
}

# 带数据的日志
log_data() {
    local label="$1"
    local data="$2"
    local level="${3:-DEBUG}"

    if ! should_log "$level"; then
        return
    fi

    local color
    color=$(get_color "$level")

    echo -e "${color}[$label]${COLOR_RESET} $data" >&2
}

# 带计数器的日志
log_counter() {
    local label="$1"
    local count="$2"
    local level="${3:-INFO}"

    if ! should_log "$level"; then
        return
    fi

    local color
    color=$(get_color "$level")

    echo -e "${color}[COUNTER]${COLOR_RESET} $label: $count" >&2
}

# 进度条日志
log_progress() {
    local current="$1"
    local total="$2"
    local label="${3:-Progress}"

    if ! should_log "INFO"; then
        return
    fi

    local percentage=0
    if [[ $total -gt 0 ]]; then
        percentage=$((current * 100 / total))
    fi

    local bar_width=30
    local filled_width=$((percentage * bar_width / 100))
    local empty_width=$((bar_width - filled_width))

    local filled_bar
    filled_bar=$(printf '█%.0s' {1..$filled_width})
    local empty_bar
    empty_bar=$(printf '░%.0s' {1..$empty_width})

    echo -ne "\r${COLOR_BLUE}[PROGRESS]${COLOR_RESET} $label: [${COLOR_GREEN}$filled_bar${COLOR_GRAY}$empty_bar${COLOR_RESET}] $percentage% ($current/$total)" >&2

    # 如果完成，输出换行
    if [[ $current -eq $total ]]; then
        echo >&2
    fi
}

# 时间测量日志
log_timer() {
    local timer_name="$1"
    local action="${2:-start}"

    case "$action" in
        start)
            # 存储开始时间（使用全局变量）
            local start_var="TIMER_${timer_name//[^a-zA-Z0-9_]/_}_START"
            export "$start_var=$(date +%s%N)"
            log_debug "计时器启动: $timer_name"
            ;;
        end)
            local start_var="TIMER_${timer_name//[^a-zA-Z0-9_]/_}_START"
            local start_time="${!start_var}"

            if [[ -n "$start_time" ]]; then
                local end_time
                end_time=$(date +%s%N)
                local duration
                duration=$(( (end_time - start_time) / 1000000 ))

                log_info "计时器结束: $timer_name (${duration}ms)"
                unset "$start_var"
            else
                log_warn "计时器未启动: $timer_name"
            fi
            ;;
        *)
            log_error "无效的计时器操作: $action"
            return 1
            ;;
    esac
}

# =============================================================================
# 批量日志函数
# =============================================================================

# 开始批量操作
log_batch_start() {
    local batch_name="$1"
    local total_items="$2"

    export BATCH_${batch_name//[^a-zA-Z0-9_]/_}_TOTAL="$total_items"
    export BATCH_${batch_name//[^a-zA-Z0-9_]/_}_CURRENT=0
    export BATCH_${batch_name//[^a-zA-Z0-9_]/_}_START=$(date +%s%N)

    log_info "批量操作开始: $batch_name (共 $total_items 项)"
}

# 批量操作进度
log_batch_progress() {
    local batch_name="$1"
    local increment="${2:-1}"

    local total_var="BATCH_${batch_name//[^a-zA-Z0-9_]/_}_TOTAL"
    local current_var="BATCH_${batch_name//[^a-zA-Z0-9_]/_}_CURRENT"

    local total="${!total_var}"
    local current="${!current_var}"

    if [[ -n "$total" && -n "$current" ]]; then
        current=$((current + increment))
        export "$current_var=$current"

        if should_log "INFO"; then
            log_progress "$current" "$total" "$batch_name"
        fi
    fi
}

# 结束批量操作
log_batch_end() {
    local batch_name="$1"

    local total_var="BATCH_${batch_name//[^a-zA-Z0-9_]/_}_TOTAL"
    local current_var="BATCH_${batch_name//[^a-zA-Z0-9_]/_}_CURRENT"
    local start_var="BATCH_${batch_name//[^a-zA-Z0-9_]/_}_START"

    local total="${!total_var}"
    local current="${!current_var}"
    local start_time="${!start_var}"

    if [[ -n "$start_time" ]]; then
        local end_time
        end_time=$(date +%s%N)
        local duration
        duration=$(( (end_time - start_time) / 1000000 ))

        log_success "批量操作完成: $batch_name ($current/$total 项, ${duration}ms)"
    else
        log_success "批量操作完成: $batch_name ($current/$total 项)"
    fi

    # 清理环境变量
    unset "$total_var"
    unset "$current_var"
    unset "$start_var"
}

# =============================================================================
# 日志查询函数
# =============================================================================

# 查看最近的日志
log_tail() {
    local lines="${1:-20}"
    local log_file="${2:-$LOG_FILE_PATH}"

    if [[ -f "$log_file" ]]; then
        tail -n "$lines" "$log_file"
    else
        echo "日志文件不存在: $log_file"
        return 1
    fi
}

# 搜索日志
log_search() {
    local pattern="$1"
    local log_file="${2:-$LOG_FILE_PATH}"

    if [[ -f "$log_file" ]]; then
        grep --color=auto "$pattern" "$log_file"
    else
        echo "日志文件不存在: $log_file"
        return 1
    fi
}

# 统计日志级别
log_stats() {
    local log_file="${1:-$LOG_FILE_PATH}"

    if [[ -f "$log_file" ]]; then
        echo "日志统计 - $log_file:"
        echo "=================="
        grep -c '\[DEBUG\]' "$log_file" | xargs -I {} echo "DEBUG: {}"
        grep -c '\[INFO\]' "$log_file" | xargs -I {} echo "INFO: {}"
        grep -c '\[WARN\]' "$log_file" | xargs -I {} echo "WARN: {}"
        grep -c '\[ERROR\]' "$log_file" | xargs -I {} echo "ERROR: {}"
        grep -c '\[SUCCESS\]' "$log_file" | xargs -I {} echo "SUCCESS: {}"
    else
        echo "日志文件不存在: $log_file"
        return 1
    fi
}

# 清理旧日志
log_cleanup() {
    local days="${1:-7}"
    local log_file="${2:-$LOG_FILE_PATH}"

    if [[ -f "$log_file" ]]; then
        local cutoff_date
        cutoff_date=$(date -d "$days days ago" '+%Y-%m-%d')

        # 创建临时文件
        local temp_file
        temp_file=$(mktemp)

        # 保留最近几天的日志
        awk -v cutoff="$cutoff_date" '{if ($1 >= cutoff) print}' "$log_file" > "$temp_file"

        # 替换原文件
        mv "$temp_file" "$log_file"

        log_info "日志清理完成，保留最近 $days 天的日志"
    else
        echo "日志文件不存在: $log_file"
        return 1
    fi
}

# =============================================================================
# 初始化函数
# =============================================================================

# 初始化日志系统
init_logger() {
    # 确保日志目录存在
    local log_dir
    log_dir=$(dirname "$LOG_FILE_PATH")

    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || {
            echo "无法创建日志目录: $log_dir" >&2
            return 1
        }
    fi

    # 创建日志文件
    touch "$LOG_FILE_PATH" 2>/dev/null || {
        echo "无法创建日志文件: $LOG_FILE_PATH" >&2
        return 1
    }

    # 设置日志级别
    set_log_level "$CURRENT_LOG_LEVEL"

    # 设置颜色输出
    set_color_output "$ENABLE_COLOR_OUTPUT"

    # 设置文件日志
    set_file_logging "$ENABLE_FILE_LOGGING"

    log_debug "日志系统初始化完成"
    log_debug "日志级别: $CURRENT_LOG_LEVEL"
    log_debug "日志文件: $LOG_FILE_PATH"
    log_debug "彩色输出: $ENABLE_COLOR_OUTPUT"
    log_debug "文件日志: $ENABLE_FILE_LOGGING"

    return 0
}

# =============================================================================
# 模块加载检查
# =============================================================================

# 如果直接执行此文件，运行测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Claude Code Git Hooks - 日志工具测试"
    echo "=========================================="

    # 初始化日志
    init_logger

    # 测试各种日志级别
    log_debug "这是一条调试信息"
    log_info "这是一条普通信息"
    log_warn "这是一条警告信息"
    log_error "这是一条错误信息"
    log_success "这是一条成功信息"

    # 测试高级功能
    log_header "测试标题" "INFO"
    log_data "测试数据" "value=123"
    log_counter "测试计数" 42
    log_timer "test_timer" "start"
    sleep 1
    log_timer "test_timer" "end"

    # 测试批量操作
    log_batch_start "test_batch" 5
    for i in {1..5}; do
        sleep 0.1
        log_batch_progress "test_batch"
    done
    log_batch_end "test_batch"

    echo ""
    echo "测试完成！"
fi