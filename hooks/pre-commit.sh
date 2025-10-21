#!/bin/bash

# Claude Code Pre-commit Hook
# 在提交代码前进行自动化代码审查

set -e

# =============================================================================
# 颜色输出定义
# =============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# =============================================================================
# 日志函数
# =============================================================================

# 日志文件（可通过环境变量覆盖）
LOG_FILE="${LOG_FILE:-.claude-hooks.log}"

write_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    # 去除颜色后写入文件
    printf '[%s] [%s] %s\n' "$timestamp" "$level" "$message" >> "$LOG_FILE" 2>/dev/null || true
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
    write_log "INFO" "$1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
    write_log "SUCCESS" "$1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
    write_log "WARNING" "$1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    write_log "ERROR" "$1"
}

log_debug() {
    if [[ "${CLAUDE_HOOKS_DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1" >&2
        write_log "DEBUG" "$1"
    fi
}

# =============================================================================
# 全局变量
# =============================================================================

readonly HOOK_NAME="pre-commit"
readonly TEMP_DIR=$(mktemp -d)
readonly RESULT_FILE="$TEMP_DIR/pre-commit-result.txt"
readonly ANALYSIS_FILE="$TEMP_DIR/analysis-summary.json"

# 清理函数
cleanup() {
    log_debug "清理临时文件: $TEMP_DIR"
    rm -rf "$TEMP_DIR"
}

# 注册清理函数
trap cleanup EXIT INT TERM

# =============================================================================
# 配置加载
# =============================================================================

load_claude_hooks_config() {
    local config_file=".claude-hooks-config.sh"

    if [[ -f "$config_file" ]]; then
        log_debug "加载配置文件: $config_file"
        source "$config_file"
    else
        log_debug "配置文件不存在，使用默认配置"
    fi

    # 设置默认值
    export CLAUDE_TIMEOUT=${CLAUDE_TIMEOUT:-30000}
    export CLAUDE_MODEL=${CLAUDE_MODEL:-"sonnet"}
    export PRE_COMMIT_ENABLED=${PRE_COMMIT_ENABLED:-true}
    export ANALYSIS_LEVEL=${ANALYSIS_LEVEL:-"moderate"}
    export MAX_FILES_PER_COMMIT=${MAX_FILES_PER_COMMIT:-20}
    export MAX_FILE_SIZE=${MAX_FILE_SIZE:-100000}
    export CODE_EXTENSIONS=${CODE_EXTENSIONS:-"js|ts|jsx|tsx|py|java|go|rs|php|rb|swift|kt|cs|cpp|c|h"}
    export EXCLUDE_PATTERNS=${EXCLUDE_PATTERNS:-"test|spec|\.min\.|node_modules|dist|build|\.git"}
    export LOG_LEVEL=${LOG_LEVEL:-"INFO"}
    export CLAUDE_HOOKS_DEBUG=${CLAUDE_HOOKS_DEBUG:-false}
}

# =============================================================================
# Claude Code 检查
# =============================================================================

check_claude_availability() {
    if ! command -v claude &> /dev/null; then
        log_warning "Claude Code 未安装，跳过代码审查"
        exit 0
    fi

    if [[ -z "$ANTHROPIC_API_KEY" ]]; then
        log_warning "ANTHROPIC_API_KEY 未设置，跳过代码审查"
        exit 0
    fi

    log_debug "Claude Code 可用，API Key 已设置"
}

# =============================================================================
# 文件处理函数
# =============================================================================

get_staged_files() {
    local extensions="$1"
    local excludes="$2"

    log_debug "获取暂存的文件，扩展名: $extensions，排除模式: $excludes"

    git diff --cached --name-only --diff-filter=ACM | \
        grep -E "\.($extensions)$" | \
        grep -v -E "($excludes)" | \
        head -n "${MAX_FILES_PER_COMMIT}"
}

is_file_too_large() {
    local file_path="$1"
    local max_size="$2"

    # 获取文件大小（字节）
    local file_size
    file_size=$(git show ":$file_path" | wc -c)

    if [[ $file_size -gt $max_size ]]; then
        log_warning "文件过大，跳过分析: $file_path ($file_size bytes)"
        return 0
    fi

    return 1
}

get_file_content() {
    local file_path="$1"
    local max_lines="${2:-100}"

    # 获取暂存文件的内容
    local content
    content=$(git show ":$file_path" | head -n "$max_lines")

    local total_lines
    total_lines=$(git show ":$file_path" | wc -l)

    if [[ $total_lines -gt $max_lines ]]; then
        echo "$content"
        echo ""
        echo "[...内容截断，共 $total_lines 行...]"
    else
        echo "$content"
    fi
}

# =============================================================================
# Claude 分析函数
# =============================================================================

build_review_prompt() {
    local files_list="$1"
    local analysis_level="$2"
    local project_info="$3"

    log_debug "构建审查提示，分析级别: $analysis_level"

    cat << EOF
You are a senior software engineer conducting pre-commit code review.

## Analysis Level
$analysis_level

## Project Information
$project_info

## Changed Files List
$files_list

## Review Focus

### Bug Detection
- Syntax errors and compilation issues
- Logic errors and algorithm problems
- Edge cases and exception handling
- Resource management and memory leaks

### Security Issues
- Input validation and output encoding
- SQL injection and XSS attacks
- Sensitive information leakage
- Access control and authentication issues

### Performance Issues
- Algorithm complexity and efficiency
- Resource usage and memory consumption
- Database query optimization
- Caching and concurrency handling

### Best Practices
- Code standards and naming conventions
- Design patterns and architectural principles
- Maintainability and scalability
- Error handling and logging

### Testing and Quality
- Unit test coverage
- Integration testing completeness
- Code testability
- Test case quality

## Output Format Requirements

### If issues found:
\`\`\`
ERROR [Severity] Filename:Line - Problem Description

[File Path]
Problem code location...

Problem Details:
- Type: [Security/Performance/Logic/Style/Test]
- Severity: [CRITICAL/HIGH/MEDIUM/LOW]
- Description: Detailed problem description
- Fix Suggestion: Specific fix solution
- Prevention: Suggestions to avoid similar issues
\`\`\`

### If no serious issues:
\`\`\`
PASS - Code quality is good, can be committed

Analysis Summary:
- Files checked: X files
- Main strengths: Code style, logic clarity, etc.
- Areas for improvement: Optimizable areas (if any)
\`\`\`

## Analysis Strategy
- $analysis_level level analysis
- Focus on newly submitted code
- Consider project context and business logic
- Provide actionable improvement suggestions

Please start analysis...
EOF
}

run_claude_analysis() {
    local files_to_analyze="$1"
    local analysis_level="$2"
    local project_info="$3"

    log_info "运行 Claude Code 分析..."
    log_debug "文件列表: $files_to_analyze"
    log_debug "分析级别: $analysis_level"

    # 构建文件内容
    local file_contents=""
    local file_count=0

    for file in $files_to_analyze; do
        if ! is_file_too_large "$file" "$MAX_FILE_SIZE"; then
            file_contents+="
--- $file ---
"
            file_contents+=$(get_file_content "$file" 150)
            file_contents+="
"
            ((file_count++))
        fi
    done

    if [[ $file_count -eq 0 ]]; then
        log_info "没有合适的文件需要分析"
        echo "PASS - 无需分析的文件" > "$RESULT_FILE"
        return 0
    fi

    # 构建分析提示
    local review_prompt
    review_prompt=$(build_review_prompt "$files_to_analyze" "$ANALYSIS_LEVEL" "$project_info")

    # 运行 Claude 分析
    log_info "分析 $file_count 个文件..."

    local timeout_seconds=$((CLAUDE_TIMEOUT / 1000))

    if timeout "$timeout_seconds" claude --print \
        --model "$CLAUDE_MODEL" \
        --system-prompt="You are a senior software engineer conducting pre-commit code review. Focus on quality, security, and best practices." \
        << EOF > "$RESULT_FILE" 2>&1
$review_prompt

## File Content Preview
$file_contents

Please analyze the code quality based on the content above.
EOF
    then
        log_success "Claude Code 分析完成"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "Claude Code 分析超时 ($timeout_seconds 秒)"
        else
            log_error "Claude Code 分析失败 (退出码: $exit_code)"
        fi
        return 1
    fi
}

# =============================================================================
# 结果分析函数
# =============================================================================

analyze_results() {
    local result_file="$1"
    local files_list="$2"

    if [[ ! -f "$result_file" ]]; then
        log_error "分析结果文件不存在"
        return 1
    fi

    log_debug "分析结果文件: $result_file"

    # 检查结果内容
    local result_content
    result_content=$(cat "$result_file")

    # 保存分析摘要
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"hook\": \"$HOOK_NAME\","
        echo "  \"analysis_level\": \"$ANALYSIS_LEVEL\","
        echo "  \"files_analyzed\": $(echo "$files_list" | wc -l | awk '{print $1}'),"
        echo "  \"result\": \"$(echo "$result_content" | head -n 1 | sed 's/["\\]/\\&/g' | cut -c1-50)\""
        echo "}"
    } > "$ANALYSIS_FILE"

    # 分析结果
    if echo "$result_content" | grep -q "PASS"; then
        log_success "代码审查通过"
        echo -e "\n${CYAN}[分析结果]:${NC}"
        echo "$result_content"
        return 0
    elif echo "$result_content" | grep -q "ERROR.*CRITICAL\|ERROR.*HIGH"; then
        log_error "发现严重问题，阻止提交"
        echo -e "\n${RED}[严重问题]:${NC}"
        echo "$result_content"

        echo -e "\n${YELLOW}[建议]:${NC}"
        echo "  1. 修复上述问题后重新提交"
        echo "  2. 使用 git commit --no-verify 跳过检查"
        echo "  3. 临时禁用此 hook: export PRE_COMMIT_ENABLED=false"

        return 1
    elif echo "$result_content" | grep -q "ERROR\|WARNING"; then
        log_warning "发现问题，建议关注"
        echo -e "\n${YELLOW}[发现问题]:${NC}"
        echo "$result_content"

        echo -e "\n${BLUE}[是否继续提交?]${NC}"
        read -p "继续提交可能引入问题，是否仍要提交？(y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "提交已取消"
            return 1
        else
            log_info "继续提交"
            return 0
        fi
    else
        log_success "分析完成，未发现严重问题"
        echo -e "\n${CYAN}[分析结果]:${NC}"
        echo "$result_content"
        return 0
    fi
}

# =============================================================================
# 主执行函数
# =============================================================================

execute_pre_commit_hook() {
    log_info "Claude Code Pre-commit Hook 开始执行..."

    # 加载配置
    load_claude_hooks_config

    # 检查是否启用
    if [[ "$PRE_COMMIT_ENABLED" != "true" ]]; then
        log_info "Pre-commit hook 已禁用"
        exit 0
    fi

    # 检查 Claude Code 可用性
    check_claude_availability

    # 获取项目信息
    local project_info
    project_info=$(cat << EOF
Project Name: ${PROJECT_NAME:-$(basename "$(pwd)")}
Project Type: ${PROJECT_TYPE:-unknown}
Primary Language: ${PRIMARY_LANGUAGE:-unknown}
Analysis Level: $ANALYSIS_LEVEL
Check Time: $(date)
EOF
)

    # 获取需要分析的文件
    log_info "获取暂存的代码文件..."
    local staged_files
    staged_files=$(get_staged_files "$CODE_EXTENSIONS" "$EXCLUDE_PATTERNS")

    if [[ -z "$staged_files" ]]; then
        log_info "没有需要分析的代码文件"
        exit 0
    fi

    log_info "发现 $(echo "$staged_files" | wc -l | awk '{print $1}') 个文件需要分析"

    # 显示文件列表
    if [[ "$CLAUDE_HOOKS_DEBUG" == "true" ]]; then
        echo "$staged_files" | sed 's/^/   - /'
    fi

    # 运行 Claude 分析
    if ! run_claude_analysis "$staged_files" "$ANALYSIS_LEVEL" "$project_info"; then
        log_error "Claude Code 分析失败"
        exit 1
    fi

    # 分析结果
    if ! analyze_results "$RESULT_FILE" "$staged_files"; then
        exit 1
    fi

    log_success "Pre-commit hook 执行完成"
}

# =============================================================================
# 入口点
# =============================================================================

# 确保在项目根目录执行
cd "$(git rev-parse --show-toplevel)" 2>/dev/null || {
    log_error "无法切换到项目根目录"
    exit 1
}

# 执行主函数
execute_pre_commit_hook "$@"