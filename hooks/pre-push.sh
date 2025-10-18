#!/bin/bash

# Claude Code Pre-push Hook
# 在代码推送到远程仓库前进行最终质量检查

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

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [[ "${CLAUDE_HOOKS_DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1" >&2
    fi
}

# =============================================================================
# 全局变量
# =============================================================================

readonly HOOK_NAME="pre-push"
readonly REMOTE="$1"
readonly URL="$2"
readonly TEMP_DIR=$(mktemp -d)
readonly RESULT_FILE="$TEMP_DIR/pre-push-result.txt"
readonly SUMMARY_FILE="$TEMP_DIR/push-summary.json"

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
    export PRE_PUSH_ENABLED=${PRE_PUSH_ENABLED:-true}
    export CLAUDE_TIMEOUT=${CLAUDE_TIMEOUT:-60000}
    export CLAUDE_MODEL=${CLAUDE_MODEL:-"sonnet"}
    export ANALYSIS_LEVEL=${ANALYSIS_LEVEL:-"thorough"}
    export LOG_LEVEL=${LOG_LEVEL:-"INFO"}
    export CLAUDE_HOOKS_DEBUG=${CLAUDE_HOOKS_DEBUG:-false}
}

# =============================================================================
# 推送信息获取函数
# =============================================================================

get_push_info() {
    log_debug "获取推送信息..."

    # 获取当前分支
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    log_debug "当前分支: $current_branch"

    # 获取远程分支
    local remote_branch
    remote_branch=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "${REMOTE:-origin}/$(git branch --show-current)")
    log_debug "远程分支: $remote_branch"

    # 获取推送范围
    local commit_range
    if git rev-parse "$remote_branch" > /dev/null 2>&1; then
        commit_range="$remote_branch..HEAD"
        log_debug "提交范围: $commit_range"
    else
        commit_range="HEAD"
        log_debug "首次推送，检查所有提交: $commit_range"
    fi

    # 获取提交数量
    local commit_count
    commit_count=$(git rev-list --count "$commit_range" 2>/dev/null || echo "0")
    log_debug "提交数量: $commit_count"

    # 如果没有要推送的提交，直接通过
    if [[ "$commit_count" -eq 0 ]]; then
        log_info "✅ 没有需要推送的提交"
        exit 0
    fi

    # 获取变更文件列表
    local changed_files
    changed_files=$(git diff --name-only "$commit_range" 2>/dev/null | head -30 | sort | uniq)
    log_debug "变更文件数量: $(echo "$changed_files" | wc -l | awk '{print $1}')"

    # 获取提交信息摘要
    local commit_summary
    commit_summary=$(git log --oneline --format="%h %s" "$commit_range" 2>/dev/null)
    log_debug "提交摘要: ${commit_summary:0:100}..."

    # 返回推送信息
    cat << EOF
当前分支: $current_branch
远程分支: $remote_branch
提交数量: $commit_count
提交范围: $commit_range
远程仓库: ${REMOTE:-unknown}
仓库URL: ${URL:-unknown}

提交摘要:
$commit_summary

变更文件:
$(echo "$changed_files" | sed 's/^/   - /')
EOF
}

# =============================================================================
# Claude 检查函数
# =============================================================================

check_claude_availability() {
    if ! command -v claude &> /dev/null; then
        log_warning "Claude Code 未安装，跳过深度检查"
        return 1
    fi

    if [[ -z "$ANTHROPIC_API_KEY" ]]; then
        log_warning "ANTHROPIC_API_KEY 未设置，跳过深度检查"
        return 1
    fi

    return 0
}

build_push_analysis_prompt() {
    local push_info="$1"
    local code_diff="$2"
    local analysis_level="$3"

    log_debug "构建推送分析提示，分析级别: $analysis_level"

    cat << EOF
你是一个资深软件工程师和 DevOps 专家，正在进行代码推送前的最终质量检查。

## 推送信息
$push_info

## 分析级别
$analysis_level

## 重点检查领域

### 🔒 安全风险（CRITICAL）
- 新增的安全漏洞和攻击面
- 敏感信息泄露风险
- 权限和认证机制变更
- 数据保护和隐私合规

### 🚨 关键 Bug 和生产问题（CRITICAL）
- 可能导致生产环境崩溃的变更
- 数据丢失或损坏风险
- 性能严重退化
- 向后兼容性问题

### 📊 架构和设计影响（HIGH）
- 破坏性 API 变更
- 数据库架构变更
- 微服务接口变更
- 依赖关系变更

### 🧪 测试和质量保证（HIGH）
- 关键功能的测试覆盖度
- 集成测试完整性
- 端到端测试验证
- 性能测试结果

### 🔄 CI/CD 影响（MEDIUM）
- 构建流程变更
- 部署脚本修改
- 环境配置更新
- 监控和日志变更

## 代码变更预览
$code_diff

## 输出要求

### 可以安全推送：
```
✅ PUSH_READY - 代码已准备好推送到生产环境

📊 分析摘要：
- 推送影响：低/中/高
- 主要变更：关键功能/优化/修复
- 风险评估：低/中/高
- 建议关注：需要关注的点（如果有）

💡 部署建议：
1. [部署建议1]
2. [部署建议2]
```

### 需要关注但可以推送：
```
⚠️ PUSH_WITH_ATTENTION - 代码可推送但需要关注

🔍 发现的问题：
- [问题1，严重程度：中]
- [问题2，严重程度：低]

📝 注意事项：
1. [注意事项1]
2. [注意事项2]

💡 推送建议：
- 建议的部署策略
- 需要监控的指标
- 回滚预案
```

### 建议推迟推送：
```
❌ DELAY_PUSH - 建议推迟推送，解决关键问题

🚨 关键问题：
- [关键问题1]
- [关键问题2]

💡 解决方案：
1. [解决方案1]
2. [解决方案2]

📋 推荐行动计划：
- [具体行动步骤]
```

### 阻止推送：
```
🚫 BLOCK_PUSH - 存在严重问题，必须修复后才能推送

🚨 阻塞问题：
- [阻塞问题1]
- [阻塞问题2]

🛠️ 必须修复：
1. [修复方案1]
2. [修复方案2]

📋 验证清单：
- [必须验证的项目]
```

请开始最终推送分析...
EOF
}

run_claude_push_analysis() {
    local push_info="$1"
    local analysis_level="$2"

    log_info "🤖 运行 Claude Code 推送分析..."
    log_debug "分析级别: $analysis_level"

    # 获取代码变更详情
    local code_diff
    code_diff=$(git diff "$commit_range" --no-color --unified=3 2>/dev/null | head -500)

    if [[ -z "$code_diff" ]]; then
        log_warning "⚠️ 无法获取代码变更详情，可能为空推送"
        return 0
    fi

    # 构建分析提示
    local analysis_prompt
    analysis_prompt=$(build_push_analysis_prompt "$push_info" "$code_diff" "$analysis_level")

    # 运行 Claude 分析
    local timeout_seconds=$((CLAUDE_TIMEOUT / 1000))

    log_info "🔍 分析 $(echo "$commit_count" | awk '{print $1}') 个提交的代码变更..."

    if timeout "$timeout_seconds" claude --print \
        --model "$CLAUDE_MODEL" \
        --system-prompt="You are a senior software engineer and DevOps expert conducting final pre-push code review. Focus on production readiness, security, and deployment impact." \
        << EOF > "$RESULT_FILE" 2>&1
$analysis_prompt
EOF
    then
        log_success "✅ Claude Code 推送分析完成"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "❌ Claude Code 推送分析超时 ($timeout_seconds 秒)"
        else
            log_error "❌ Claude Code 推送分析失败 (退出码: $exit_code)"
        fi
        return 1
    fi
}

# =============================================================================
# 结果分析函数
# =============================================================================

analyze_push_results() {
    local result_file="$1"
    local push_info="$2"

    if [[ ! -f "$result_file" ]]; then
        log_warning "分析结果文件不存在，跳过深度检查"
        return 0
    fi

    local result_content
    result_content=$(cat "$result_file")

    # 保存分析摘要
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"hook\": \"$HOOK_NAME\","
        echo "  \"analysis_level\": \"$ANALYSIS_LEVEL\","
        echo "  \"remote\": \"$REMOTE\","
        echo "  \"branch\": \"$(echo "$push_info" | grep '当前分支:' | cut -d' ' -f2-)\","
        echo "  \"commit_count\": \"$(echo "$push_info" | grep '提交数量:' | cut -d' ' -f2-)\","
        echo "  \"result\": \"$(echo "$result_content" | head -n 1 | sed 's/["\\]/\\&/g' | cut -c1-50)\""
        echo "}"
    } > "$SUMMARY_FILE"

    # 分析 Claude 的结果
    echo -e "\n${CYAN}🤖 Claude Code 推送分析结果:${NC}"
    echo "$result_content"

    if echo "$result_content" | grep -q "✅ PUSH_READY"; then
        log_success "🎉 代码已准备好推送到生产环境"
        return 0
    elif echo "$result_content" | grep -q "⚠️ PUSH_WITH_ATTENTION"; then
        log_warning "⚠️ 代码可推送但需要关注"
        echo -e "\n${YELLOW}💡 建议:${NC}"
        echo "  推送代码，但请关注上述问题"
        echo "  建议在部署后密切监控系统状态"
        return 0
    elif echo "$result_content" | grep -q "❌ DELAY_PUSH"; then
        log_error "🚨 建议推迟推送，解决关键问题"

        echo -e "\n${RED}💡 建议:${NC}"
        echo "  1. 解决上述关键问题"
        echo "  2. 在测试环境中验证修复"
        echo "  3. 重新提交后再推送"

        echo -e "\n${YELLOW}🤔 是否仍要推送？(y/N):${NC}"
        read -p "" -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "❌ 推送已取消"
            exit 1
        fi
        return 0
    elif echo "$result_content" | grep -q "🚫 BLOCK_PUSH"; then
        log_error "🚫 存在严重问题，必须修复后才能推送"

        echo -e "\n${RED}🛠️ 必须修复:${NC}"
        echo "  1. 解决所有阻塞问题"
        echo "  2. 运行完整测试套件"
        echo "  3. 获取必要的代码审查"

        echo -e "\n${YELLOW}💡 推送已被阻止${NC}"
        echo "  修复问题后重试"
        echo "  使用 --no-verify 跳过检查（不推荐）"

        exit 1
    else
        log_success "✅ 分析完成，未发现严重问题"
        return 0
    fi
}

# =============================================================================
# 基本检查函数
# =============================================================================

perform_basic_checks() {
    local push_info="$1"

    log_info "🔍 执行基本推送检查..."

    # 检查是否推送到了受保护分支
    local current_branch
    current_branch=$(echo "$push_info" | grep '当前分支:' | cut -d' ' -f2-)

    if [[ "$current_branch" =~ ^(main|master|develop|production|prod)$ ]]; then
        log_warning "⚠️ 推送到受保护分支: $current_branch"
        echo -e "${YELLOW}💡 确认推送到受保护分支? (y/N):${NC}"
        read -p "" -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "❌ 推送已取消"
            exit 1
        fi
    fi

    # 检查是否有未提交的更改
    if ! git diff-index --quiet HEAD --; then
        log_warning "⚠️ 检测到未提交的更改"
        echo -e "${YELLOW}💡 是否包含未提交的更改一起推送? (y/N):${NC}"
        read -p "" -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "📝 将未提交的更改添加到暂存区"
            git add -A
        else
            log_warning "⚠️ 继续推送，但不包含未提交的更改"
        fi
    fi

    # 检查提交消息格式（可选）
    local commit_count
    commit_count=$(echo "$push_info" | grep '提交数量:' | cut -d' ' -f2-)

    if [[ "$commit_count" -gt 5 ]]; then
        log_warning "⚠️ 较多提交数量 ($commit_count)，建议整理或 squash"
        echo -e "${YELLOW}💡 建议:${NC}"
        echo "  1. 使用 git rebase -i 整理提交"
        echo "  2. 使用 git merge --squash 合并提交"
        echo -e "\n${YELLOW}🤔 是否继续推送? (y/N):${NC}"
        read -p "" -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "❌ 推送已取消"
            exit 1
        fi
    fi

    log_success "✅ 基本检查通过"
}

# =============================================================================
# 主执行函数
# =============================================================================

execute_pre_push_hook() {
    log_info "🚀 Claude Code Pre-push Hook 开始执行..."

    # 加载配置
    load_claude_hooks_config

    # 检查是否启用
    if [[ "$PRE_PUSH_ENABLED" != "true" ]]; then
        log_info "ℹ️ Pre-push hook 已禁用"
        exit 0
    fi

    # 获取推送信息
    log_info "📋 获取推送信息..."
    local push_info
    push_info=$(get_push_info)

    echo -e "\n${CYAN}📋 推送信息:${NC}"
    echo "$push_info"

    # 执行基本检查
    perform_basic_checks "$push_info"

    # Claude Code 深度检查（如果可用）
    if check_claude_availability; then
        log_info "🤖 进行 Claude Code 深度分析..."

        # 从 push_info 中提取变量
        local commit_range
        commit_range=$(echo "$push_info" | grep '提交范围:' | cut -d' ' -f2-)
        local commit_count
        commit_count=$(echo "$push_info" | grep '提交数量:' | cut -d' ' -f2-)

        if [[ "$commit_count" -gt 0 ]]; then
            if ! run_claude_push_analysis "$push_info" "$ANALYSIS_LEVEL"; then
                log_warning "⚠️ Claude Code 分析失败，仅执行基本检查"
            else
                if ! analyze_push_results "$RESULT_FILE" "$push_info"; then
                    exit 1
                fi
            fi
        else
            log_info "ℹ️ 没有需要分析的提交"
        fi
    else
        log_info "ℹ️ Claude Code 不可用，只进行基本检查"
    fi

    log_success "🎉 Pre-push hook 执行完成"
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
execute_pre_push_hook "$@"