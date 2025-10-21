#!/bin/bash

# Claude Code Git Hooks 安装脚本
# 版本: 1.0.0

set -e  # 遇到错误立即退出

# 颜色输出定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 脚本路径
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HOOKS_DIR="$SCRIPT_DIR/hooks"
readonly TEMPLATES_DIR="$SCRIPT_DIR/templates"
readonly UTILS_DIR="$SCRIPT_DIR/utils"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# 显示欢迎信息
show_welcome() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║            Claude Code Git Hooks 安装程序                      ║
╠══════════════════════════════════════════════════════════════╣
║  🤖 将 Claude Code 与 Git Hooks 集成                         ║
║  🛡️  自动化代码审查和质量检查                                  ║
║  🚀 提升开发效率和代码质量                                     ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检查系统要求
check_requirements() {
    log_step "检查系统要求..."

    # 检查是否在 Git 仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "当前目录不是 Git 仓库"
        log_info "请先初始化 Git 仓库: git init"
        exit 1
    fi
    log_success "✓ Git 仓库检查通过"

    # 检查 Claude Code 是否安装
    if command -v claude > /dev/null 2>&1; then
        log_success "✓ Claude Code 已安装"
        CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "未知版本")
        log_info "  Claude Code 版本: $CLAUDE_VERSION"
    else
        log_warning "⚠ Claude Code 未安装"
        log_info "  请安装 Claude Code: npm install -g @anthropic-ai/claude-code"
        read -p "是否继续安装（Claude Code 功能将被跳过）? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # 检查 API Key
    if [[ -n "$ANTHROPIC_API_KEY" ]]; then
        log_success "✓ ANTHROPIC_API_KEY 已设置"
    else
        log_warning "⚠ ANTHROPIC_API_KEY 未设置"
        log_info "  请设置环境变量: export ANTHROPIC_API_KEY=your_api_key"
    fi

    # 检查 Bash 版本
    if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
        log_warning "⚠ Bash 版本较低 (${BASH_VERSION})"
        log_info "  建议使用 Bash 4.0 或更高版本"
    fi
}

# 验证文件完整性
verify_files() {
    log_step "验证文件完整性..."

    local required_files=(
        "hooks/pre-commit.sh"
        "hooks/commit-msg.sh"
        "hooks/pre-push.sh"
        "templates/review-prompt.txt"
        "templates/commit-prompt.txt"
        "templates/push-prompt.txt"
        "utils/logger.sh"
        "utils/file-utils.sh"
        "utils/claude-client.sh"
    )

    for file in "${required_files[@]}"; do
        local filepath="$SCRIPT_DIR/$file"
        if [[ -f "$filepath" ]]; then
            log_success "✓ $file"
        else
            log_error "✗ 缺少文件: $file"
            exit 1
        fi
    done
}

# 备份现有 hooks
backup_existing_hooks() {
    log_step "备份现有 Git hooks..."

    local git_hooks_dir
    git_hooks_dir=$(git rev-parse --git-dir)/hooks

    local hooks_to_backup=("pre-commit" "commit-msg" "pre-push")
    local backup_dir="$git_hooks_dir/backup-$(date +%Y%m%d-%H%M%S)"

    mkdir -p "$backup_dir"

    for hook in "${hooks_to_backup[@]}"; do
        local hook_path="$git_hooks_dir/$hook"
        if [[ -f "$hook_path" ]]; then
            # 检查是否是 Claude hook
            if grep -q "Claude Code" "$hook_path" 2>/dev/null; then
                log_info "  备份 Claude hook: $hook"
                cp "$hook_path" "$backup_dir/"
            else
                log_info "  备份自定义 hook: $hook"
                cp "$hook_path" "$backup_dir/"
            fi
        fi
    done

    if [[ -d "$backup_dir" ]] && [[ $(ls -A "$backup_dir") ]]; then
        log_success "✓ 现有 hooks 已备份到: $backup_dir"
    else
        log_info "  未发现需要备份的 hooks"
        rm -rf "$backup_dir"
    fi
}

# 安装 Git hooks
install_hooks() {
    log_step "安装 Claude Code Git hooks..."

    local git_hooks_dir
    git_hooks_dir=$(git rev-parse --git-dir)/hooks

    local hooks_config=(
        "pre-commit:pre-commit.sh"
        "commit-msg:commit-msg.sh"
        "pre-push:pre-push.sh"
    )

    for hook_config in "${hooks_config[@]}"; do
        local hook_name="${hook_config%%:*}"
        local script_file="${hook_config##*:}"
        local source_file="$HOOKS_DIR/$script_file"
        local target_file="$git_hooks_dir/$hook_name"

        if [[ -f "$source_file" ]]; then
            # 直接安装实际的 hook 脚本，保持脚本自包含逻辑
            cp "$source_file" "$target_file"
            chmod +x "$target_file"
            log_success "✓ Installed $hook_name hook"
        else
            log_error "✗ Source file not found: $source_file"
            exit 1
        fi
    done
}

# 安装配置文件
install_config() {
    log_step "安装配置文件..."

    local config_file=".claude-hooks-config.sh"

    if [[ ! -f "$config_file" ]]; then
        cp "$SCRIPT_DIR/config.example.sh" "$config_file" 2>/dev/null || {
            # 如果模板文件不存在，创建默认配置
            cat > "$config_file" << EOF
#!/bin/bash
# Claude Code Git Hooks 配置文件
# 生成时间: $(date)

# Claude Code 配置
export CLAUDE_TIMEOUT=${CLAUDE_TIMEOUT:-30000}  # 30秒超时
export CLAUDE_MODEL=${CLAUDE_MODEL:-"sonnet"}    # 默认模型

# Hook 启用控制
export PRE_COMMIT_ENABLED=${PRE_COMMIT_ENABLED:-true}
export COMMIT_MSG_ENABLED=${COMMIT_MSG_ENABLED:-true}
export PRE_PUSH_ENABLED=${PRE_PUSH_ENABLED:-true}

# 文件类型过滤
export CODE_EXTENSIONS="js|ts|jsx|tsx|py|java|go|rs|php|rb|swift|kt|cs|cpp|c|h"

# 分析级别 (quick, moderate, thorough)
export ANALYSIS_LEVEL=${ANALYSIS_LEVEL:-"moderate"}

# 日志控制
export CLAUDE_HOOKS_DEBUG=${CLAUDE_HOOKS_DEBUG:-false}
export LOG_FILE=${LOG_FILE:-".claude-hooks.log"}

# 性能控制
export MAX_FILE_SIZE=${MAX_FILE_SIZE:-100000}  # 100KB
export MAX_FILES_PER_COMMIT=${MAX_FILES_PER_COMMIT:-20}

# 审查规则级别 (strict, moderate, lax)
export SECURITY_CHECK_LEVEL=${SECURITY_CHECK_LEVEL:-"moderate"}
export PERFORMANCE_CHECK_LEVEL=${PERFORMANCE_CHECK_LEVEL:-"moderate"}
export STYLE_CHECK_LEVEL=${STYLE_CHECK_LEVEL:-"lax"}

# API 配置
export CLAUDE_API_RETRIES=${CLAUDE_API_RETRIES:-3}
export CLAUDE_API_RETRY_DELAY=${CLAUDE_API_RETRY_DELAY:-1000}
EOF
        }
        log_success "✓ 配置文件已创建: $config_file"
        log_info "  编辑此文件以自定义 hook 行为"
    else
        log_info "  配置文件已存在: $config_file (保持不变)"
    fi
}

# 安装 .gitignore 条目
install_gitignore() {
    log_step "更新 .gitignore..."

    local gitignore_file=".gitignore"
    local patterns_to_add=(
        ".claude-hooks.log"
        ".claude-hooks-cache/"
        ".claude-hooks-temp/"
        "claude-hooks-backup/"
        ".claude-hooks-team.yml"
    )

    # 创建 .gitignore 如果不存在
    if [[ ! -f "$gitignore_file" ]]; then
        touch "$gitignore_file"
    fi

    local added_count=0
    for pattern in "${patterns_to_add[@]}"; do
        if ! grep -q "^$pattern$" "$gitignore_file" 2>/dev/null; then
            echo "" >> "$gitignore_file"
            echo "# Claude Code Git Hooks" >> "$gitignore_file"
            echo "$pattern" >> "$gitignore_file"
            ((added_count++))
        fi
    done

    if [[ $added_count -gt 0 ]]; then
        log_success "✓ 已添加 $added_count 个条目到 .gitignore"
    else
        log_info "  .gitignore 已包含相关条目"
    fi
}

# 验证安装
verify_installation() {
    log_step "验证安装..."

    local git_hooks_dir
    git_hooks_dir=$(git rev-parse --git-dir)/hooks

    local required_hooks=("pre-commit" "commit-msg" "pre-push")
    local all_installed=true

    for hook in "${required_hooks[@]}"; do
        local hook_path="$git_hooks_dir/$hook"
        if [[ -x "$hook_path" ]] && grep -q "Claude Code" "$hook_path"; then
            log_success "✓ $hook hook: 已安装并可用"
        else
            log_error "✗ $hook hook: 安装失败"
            all_installed=false
        fi
    done

    if [[ "$all_installed" == "true" ]]; then
        log_success "🎉 所有 hooks 安装成功！"
    else
        log_error "❌ 部分 hooks 安装失败"
        exit 1
    fi

    # 测试配置加载
    if source ".claude-hooks-config.sh" 2>/dev/null; then
        log_success "✓ 配置文件加载正常"
    else
        log_warning "⚠ 配置文件加载失败，将使用默认配置"
    fi
}

# 显示使用说明
show_usage_instructions() {
    echo -e "\n${CYAN}📖 使用说明${NC}"
    echo
    echo -e "${BLUE}基本使用:${NC}"
    echo "  git add .                    # 添加文件"
    echo "  git commit -m \"message\"     # 提交（自动触发 pre-commit 检查）"
    echo "  git push origin main         # 推送（自动触发 pre-push 检查）"
    echo
    echo -e "${BLUE}跳过检查:${NC}"
    echo "  git commit --no-verify -m \"message\"     # 跳过 pre-commit 检查"
    echo "  git push --no-verify origin main         # 跳过 pre-push 检查"
    echo
    echo -e "${BLUE}配置选项:${NC}"
    echo "  编辑 .claude-hooks-config.sh 文件来自定义行为"
    echo "  设置环境变量临时改变配置"
    echo
    echo -e "${BLUE}故障排除:${NC}"
    echo "  export CLAUDE_HOOKS_DEBUG=true          # 启用调试模式"
    echo "  tail -f .claude-hooks.log               # 查看日志"
    echo "  ./uninstall.sh                          # 卸载 hooks"
    echo
    echo -e "${GREEN}🚀 Claude Code Git Hooks 安装完成！${NC}"
}

# 主函数
main() {
    show_welcome

    log_step "开始安装 Claude Code Git hooks..."

    # 确保在项目根目录运行
    cd "$(git rev-parse --show-toplevel)"
    log_info "项目根目录: $(pwd)"

    check_requirements
    verify_files
    backup_existing_hooks
    install_hooks
    install_config
    install_gitignore
    verify_installation

    show_usage_instructions
}

# 错误处理
trap 'log_error "安装过程中发生错误，请检查错误信息并重试"' ERR

# 运行主函数
main "$@"