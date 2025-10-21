#!/bin/bash

# Claude Code Commit Message Hook
# 检查 Git 提交消息的质量和格式

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

readonly HOOK_NAME="commit-msg"
readonly COMMIT_MSG_FILE="$1"
readonly TEMP_DIR=$(mktemp -d)
readonly RESULT_FILE="$TEMP_DIR/commit-msg-result.txt"

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
    export COMMIT_MSG_ENABLED=${COMMIT_MSG_ENABLED:-true}
    export CLAUDE_TIMEOUT=${CLAUDE_TIMEOUT:-15000}
    export CLAUDE_MODEL=${CLAUDE_MODEL:-"sonnet"}
    export ENFORCE_COMMIT_MESSAGE_FORMAT=${ENFORCE_COMMIT_MESSAGE_FORMAT:-true}
    export COMMIT_MESSAGE_FORMAT_REGEX=${COMMIT_MESSAGE_FORMAT_REGEX:-"^(feat|fix|docs|style|refactor|test|chore|perf|build|ci|revert|wip)(\(.+\))?!?: .+"}
    export COMMIT_MESSAGE_MAX_LENGTH=${COMMIT_MESSAGE_MAX_LENGTH:-72}
    export COMMIT_MESSAGE_MIN_LENGTH=${COMMIT_MESSAGE_MIN_LENGTH:-10}
    export LOG_LEVEL=${LOG_LEVEL:-"INFO"}
    export CLAUDE_HOOKS_DEBUG=${CLAUDE_HOOKS_DEBUG:-false}
}

# =============================================================================
# 提交消息分析函数
# =============================================================================

validate_commit_message_format() {
    local commit_msg="$1"

    log_debug "验证提交消息格式"

    # 检查是否为空
    if [[ -z "$commit_msg" ]]; then
        log_error "❌ 提交消息不能为空"
        return 1
    fi

    # 检查长度（仅检查标题行）
    local first_line
    first_line=$(echo "$commit_msg" | head -n 1)
    local title_length=${#first_line}
    if [[ $title_length -gt $COMMIT_MESSAGE_MAX_LENGTH ]]; then
        log_error "❌ 提交标题过长 ($title_length > $COMMIT_MESSAGE_MAX_LENGTH 字符)"
        return 1
    fi

    if [[ $title_length -lt $COMMIT_MESSAGE_MIN_LENGTH ]]; then
        log_warning "⚠️ 提交标题过短 ($title_length < $COMMIT_MESSAGE_MIN_LENGTH 字符)"
    fi

    # 检查格式（如果启用）
    if [[ "$ENFORCE_COMMIT_MESSAGE_FORMAT" == "true" ]]; then
        # 获取第一行（标题行）
        local first_line
        first_line=$(echo "$commit_msg" | head -n 1)

        if [[ ! "$first_line" =~ $COMMIT_MESSAGE_FORMAT_REGEX ]]; then
            log_warning "⚠️ 提交消息格式不符合 Conventional Commits 规范"
            log_info "   建议格式: <type>(<scope>): <description>"
            log_info "   类型: feat, fix, docs, style, refactor, test, chore, perf, build, ci, revert, wip"
            return 2  # 警告级别，不阻止提交
        fi
    fi

    # 检查是否包含常见的坏实践
    if echo "$commit_msg" | grep -q -i "fix.*fix\|bug.*bug\|work.*work\|test.*test"; then
        log_warning "⚠️ 提交消息可能包含重复词汇"
    fi

    # 检查是否只有单个字符
    if [[ "$commit_msg" =~ ^[a-zA-Z0-9]$ ]]; then
        log_warning "⚠️ 提交消息过于简单"
    fi

    return 0
}

# =============================================================================
# Claude 检查函数
# =============================================================================

check_claude_availability() {
    if ! command -v claude &> /dev/null; then
        log_warning "Claude Code 未安装，跳过智能检查"
        return 1
    fi

    if [[ -z "$ANTHROPIC_API_KEY" ]]; then
        log_warning "ANTHROPIC_API_KEY 未设置，跳过智能检查"
        return 1
    fi

    return 0
}

run_claude_message_analysis() {
    local commit_msg="$1"
    local git_diff="$2"

    log_info "🤖 运行 Claude Code 提交消息分析..."

    # 构建分析提示
    local analysis_prompt
    analysis_prompt=$(cat << EOF
你是一个软件开发专家，专门评估 Git 提交消息的质量。

## 提交消息内容
"$commit_msg"

## 代码变更预览
$git_diff

## 评估维度

### 1. 清晰度和描述性
- 是否清楚地描述了变更内容
- 是否包含了足够的具体信息
- 是否避免了模糊和笼统的描述

### 2. 完整性和准确性
- 提交消息是否与实际代码变更匹配
- 是否遗漏了重要的变更说明
- 是否准确反映了变更的范围

### 3. 格式和规范
- 是否遵循 Conventional Commits 格式（如果要求）
- 标题行是否简洁明了
- 是否使用了合适的类型标签（feat, fix, docs 等）

### 4. 最佳实践
- 是否使用了命令式语气
- 是否避免了无意义的消息
- 是否包含了适当的上下文信息

## 输出要求

### 如果消息质量优秀：
```
✅ PASS - 提交消息质量优秀

📊 评估结果：
- 清晰度：优秀/良好/一般
- 完整性：优秀/良好/一般
- 格式：符合规范/需改进
- 最佳实践：遵循良好/基本符合/需改进

💡 建议：（可选的改进建议）
```

### 如果消息需要改进：
```
⚠️ NEEDS_IMPROVEMENT - 提交消息需要改进

🔍 主要问题：
- [具体问题1]
- [具体问题2]

📝 改进建议：
1. [具体建议1]
2. [具体建议2]

📋 示例改进：
[改进后的消息示例]
```

### 如果消息质量较差：
```
❌ REJECT - 提交消息质量较差，建议重写

🚨 严重问题：
- [严重问题1]
- [严重问题2]

💡 重写建议：
[详细的重写指导和示例]
```

请开始评估...
EOF
)

    # 运行 Claude 分析
    local timeout_seconds=$((CLAUDE_TIMEOUT / 1000))

    if timeout "$timeout_seconds" claude --print \
        --model "$CLAUDE_MODEL" \
        --system-prompt="You are a software engineering expert evaluating Git commit message quality. Focus on clarity, completeness, and best practices." \
        << EOF > "$RESULT_FILE" 2>&1
$analysis_prompt
EOF
    then
        log_success "✅ Claude Code 分析完成"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "❌ Claude Code 分析超时 ($timeout_seconds 秒)"
        else
            log_error "❌ Claude Code 分析失败 (退出码: $exit_code)"
        fi
        return 1
    fi
}

# =============================================================================
# 结果分析函数
# =============================================================================

analyze_claude_results() {
    local result_file="$1"

    if [[ ! -f "$result_file" ]]; then
        log_warning "Claude Code 分析结果文件不存在，跳过智能检查"
        return 0
    fi

    local result_content
    result_content=$(cat "$result_file")

    echo -e "\n${CYAN}🤖 Claude Code 分析结果:${NC}"
    echo "$result_content"

    # 分析 Claude 的建议
    if echo "$result_content" | grep -q "✅ PASS"; then
        log_success "🎉 提交消息质量优秀"
        return 0
    elif echo "$result_content" | grep -q "⚠️ NEEDS_IMPROVEMENT"; then
        log_warning "⚠️ 提交消息需要改进"

        echo -e "\n${YELLOW}💡 是否根据建议修改消息？${NC}"
        echo "  y - 重新编写提交消息"
        echo "  n - 继续使用当前消息"
        echo "  v - 查看详细建议"

        read -p "选择 (y/n/v): " -r
        case $REPLY in
            [Yy])
                echo "请重新输入提交消息:"
                read -r new_message
                echo "$new_message" > "$COMMIT_MSG_FILE"
                log_info "📝 提交消息已更新"
                return 2  # 需要重新检查
                ;;
            [Vv])
                echo -e "\n${CYAN}📋 详细建议:${NC}"
                echo "$result_content" | grep -A 20 "💡 改进建议"
                echo -e "\n${YELLOW}💡 是否继续提交？ (y/N):${NC}"
                read -p "" -r
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "❌ 提交已取消"
                    exit 1
                fi
                ;;
            *)
                log_info "✅ 继续使用当前提交消息"
                ;;
        esac
        return 0
    elif echo "$result_content" | grep -q "❌ REJECT"; then
        log_error "🚨 提交消息质量较差，Claude Code 建议重写"

        echo -e "\n${RED}💡 建议:${NC}"
        echo "  1. 根据建议重新编写提交消息"
        echo "  2. 使用 git commit --amend 修改消息"
        echo "  3. 临时跳过检查: git commit --no-verify"

        echo -e "\n${YELLOW}🤔 是否重新编写消息？(y/N):${NC}"
        read -p "" -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "请重新输入提交消息:"
            read -r new_message
            echo "$new_message" > "$COMMIT_MSG_FILE"
            log_info "📝 提交消息已更新，请重新提交"
            exit 1
        else
            echo -e "\n${YELLOW}💡 是否仍要提交？(y/N):${NC}"
            read -p "" -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "❌ 提交已取消"
                exit 1
            fi
        fi
        return 0
    else
        log_success "✅ Claude Code 检查完成"
        return 0
    fi
}

# =============================================================================
# 主执行函数
# =============================================================================

execute_commit_msg_hook() {
    log_info "📝 Claude Code Commit Message Hook 开始执行..."

    # 检查参数
    if [[ -z "$COMMIT_MSG_FILE" ]]; then
        log_error "❌ 缺少提交消息文件参数"
        exit 1
    fi

    if [[ ! -f "$COMMIT_MSG_FILE" ]]; then
        log_error "❌ 提交消息文件不存在: $COMMIT_MSG_FILE"
        exit 1
    fi

    # 加载配置
    load_claude_hooks_config

    # 检查是否启用
    if [[ "$COMMIT_MSG_ENABLED" != "true" ]]; then
        log_info "ℹ️ Commit message hook 已禁用"
        exit 0
    fi

    # 读取提交消息
    local commit_msg
    commit_msg=$(cat "$COMMIT_MSG_FILE")

    # 跳过特殊提交
    if [[ "$commit_msg" =~ ^(Merge|Revert|fixup!|squash!) ]]; then
        log_info "ℹ️ 跳过特殊提交类型: ${commit_msg:0:20}..."
        exit 0
    fi

    log_debug "提交消息: $commit_msg"

    # 获取代码变更预览
    local git_diff
    git_diff=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | head -10 | sed 's/^/   - /')
    local changed_files
    changed_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | wc -l)

    echo -e "\n${CYAN}📋 提交信息:${NC}"
    echo "   消息: $commit_msg"
    echo "   变更文件数: $changed_files"

    if [[ -n "$git_diff" ]]; then
        echo -e "\n${CYAN}📁 变更文件:${NC}"
        echo "$git_diff"
    fi

    # 基本格式验证
    log_info "🔍 验证提交消息格式..."
    if ! validate_commit_message_format "$commit_msg"; then
        log_error "❌ 提交消息格式验证失败"
        exit 1
    fi

    # Claude Code 智能检查（如果可用）
    if check_claude_availability; then
        # 获取代码变更详情
        local code_changes
        code_changes=$(git diff --cached --no-color --unified=3 2>/dev/null | head -200)

        if [[ -n "$code_changes" ]]; then
            log_info "🤖 进行智能提交消息分析..."
            if run_claude_message_analysis "$commit_msg" "$code_changes"; then
                # 分析 Claude 的结果
                local claude_result
                claude_result=$(analyze_claude_results "$RESULT_FILE")
                case $claude_result in
                    0)
                        # 继续提交
                        ;;
                    2)
                        # 需要重新检查
                        if [[ -f "$COMMIT_MSG_FILE" ]]; then
                            commit_msg=$(cat "$COMMIT_MSG_FILE")
                            log_debug "重新验证更新后的消息: $commit_msg"
                            if ! validate_commit_message_format "$commit_msg"; then
                                log_error "❌ 更新后的消息格式验证失败"
                                exit 1
                            fi
                        fi
                        ;;
                    *)
                        # 其他情况，继续
                        ;;
                esac
            else
                log_warning "⚠️ Claude Code 分析失败，只进行基本格式检查"
            fi
        else
            log_info "ℹ️ 没有代码变更，跳过智能检查"
        fi
    else
        log_info "ℹ️ Claude Code 不可用，只进行基本格式检查"
    fi

    log_success "🎉 Commit message hook 执行完成"
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
execute_commit_msg_hook "$@"