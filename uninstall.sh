#!/bin/bash

# Claude Code Git Hooks 卸载脚本
# 版本: 1.0.0

set -e

# 颜色输出定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

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
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║            Claude Code Git Hooks 卸载程序                      ║
╠══════════════════════════════════════════════════════════════╣
║  🗑️  移除 Claude Code Git Hooks                             ║
║  🔄 恢复原始 Git 配置                                        ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 确认卸载
confirm_uninstall() {
    echo
    echo -e "${YELLOW}⚠️  警告：即将卸载 Claude Code Git Hooks${NC}"
    echo "这将："
    echo "  - 移除所有 Claude Code hooks"
    echo "  - 恢复之前备份的 hooks（如果存在）"
    echo "  - 删除配置文件和日志文件"
    echo
    read -p "是否继续卸载？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "卸载已取消"
        exit 0
    fi
}

# 查找并恢复备份的 hooks
restore_backup_hooks() {
    log_step "查找备份的 hooks..."

    local git_hooks_dir
    git_hooks_dir=$(git rev-parse --git-dir)/hooks

    # 查找备份目录
    local backup_dirs=()
    while IFS= read -r -d '' backup_dir; do
        if [[ -d "$backup_dir" ]]; then
            backup_dirs+=("$backup_dir")
        fi
    done < <(find "$git_hooks_dir" -maxdepth 1 -name "backup-*" -type d -print0 2>/dev/null)

    if [[ ${#backup_dirs[@]} -eq 0 ]]; then
        log_info "  未找到备份的 hooks"
        return 0
    fi

    # 选择最新的备份
    local latest_backup=$(printf "%s\n" "${backup_dirs[@]}" | sort -r | head -n1)
    log_info "  找到备份: $latest_backup"

    # 恢复 hooks
    local hooks_to_restore=("pre-commit" "commit-msg" "pre-push")
    local restored_count=0

    for hook in "${hooks_to_restore[@]}"; do
        local backup_hook="$latest_backup/$hook"
        local target_hook="$git_hooks_dir/$hook"

        if [[ -f "$backup_hook" ]]; then
            if [[ -f "$target_hook" ]] && grep -q "Claude Code" "$target_hook"; then
                rm "$target_hook"
                cp "$backup_hook" "$target_hook"
                chmod +x "$target_hook"
                log_success "✓ 已恢复 $hook hook"
                ((restored_count++))
            fi
        fi
    done

    if [[ $restored_count -gt 0 ]]; then
        log_success "✓ 已恢复 $restored_count 个 hooks"
    else
        log_info "  没有需要恢复的 hooks"
    fi

    # 询问是否删除备份
    read -p "是否删除备份目录？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$latest_backup"
        log_success "✓ 已删除备份目录"
    fi
}

# 移除 Claude Code hooks
remove_claude_hooks() {
    log_step "移除 Claude Code hooks..."

    local git_hooks_dir
    git_hooks_dir=$(git rev-parse --git-dir)/hooks

    local claude_hooks=("pre-commit" "commit-msg" "pre-push")
    local removed_count=0

    for hook in "${claude_hooks[@]}"; do
        local hook_path="$git_hooks_dir/$hook"

        if [[ -f "$hook_path" ]] && grep -q "Claude Code" "$hook_path"; then
            rm "$hook_path"
            log_success "✓ 已移除 Claude $hook hook"
            ((removed_count++))
        elif [[ -f "$hook_path" ]]; then
            log_info "  $hook hook 存在但不是 Claude hook，保持不变"
        else
            log_info "  $hook hook 不存在"
        fi
    done

    if [[ $removed_count -gt 0 ]]; then
        log_success "✓ 已移除 $removed_count 个 Claude hooks"
    else
        log_info "  未找到 Claude hooks"
    fi
}

# 清理配置文件
cleanup_config_files() {
    log_step "清理配置文件..."

    local config_files=(
        ".claude-hooks-config.sh"
        ".claude-hooks.log"
        ".claude-hooks-cache"
        ".claude-hooks-temp"
        ".claude-hooks-team.yml"
    )

    local removed_count=0
    for file in "${config_files[@]}"; do
        if [[ -e "$file" ]]; then
            rm -rf "$file"
            log_success "✓ 已删除: $file"
            ((removed_count++))
        fi
    done

    if [[ $removed_count -gt 0 ]]; then
        log_success "✓ 已清理 $removed_count 个配置文件"
    else
        log_info "  没有需要清理的配置文件"
    fi
}

# 清理 .gitignore 条目
cleanup_gitignore() {
    log_step "清理 .gitignore..."

    local gitignore_file=".gitignore"
    if [[ ! -f "$gitignore_file" ]]; then
        log_info "  .gitignore 文件不存在"
        return 0
    fi

    # 要移除的模式
    local patterns_to_remove=(
        ".claude-hooks.log"
        ".claude-hooks-cache/"
        ".claude-hooks-temp/"
        "claude-hooks-backup/"
        ".claude-hooks-team.yml"
    )

    # 创建临时文件
    local temp_file=$(mktemp)
    local removed_count=0
    local in_claude_section=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^#.*Claude Code Git Hooks ]]; then
            in_claude_section=true
            ((removed_count++))
            continue
        elif [[ "$line" =~ ^# ]] && [[ "$in_claude_section" == "true" ]]; then
            in_claude_section=false
        fi

        # 检查是否是需要移除的行
        local should_remove=false
        for pattern in "${patterns_to_remove[@]}"; do
            if [[ "$line" == "$pattern" ]]; then
                should_remove=true
                ((removed_count++))
                break
            fi
        done

        if [[ "$should_remove" == "false" ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$gitignore_file"

    # 替换原文件
    if [[ $removed_count -gt 0 ]]; then
        mv "$temp_file" "$gitignore_file"
        log_success "✓ 已从 .gitignore 移除 Claude hooks 相关条目"
    else
        rm -f "$temp_file"
        log_info "  .gitignore 中没有 Claude hooks 相关条目"
    fi
}

# 验证卸载
verify_uninstall() {
    log_step "验证卸载结果..."

    local git_hooks_dir
    git_hooks_dir=$(git rev-parse --git-dir)/hooks

    local claude_hooks=("pre-commit" "commit-msg" "pre-push")
    local remaining_claude_hooks=0

    for hook in "${claude_hooks[@]}"; do
        local hook_path="$git_hooks_dir/$hook"

        if [[ -f "$hook_path" ]] && grep -q "Claude Code" "$hook_path"; then
            log_error "✗ $hook hook 仍然存在"
            ((remaining_claude_hooks++))
        else
            log_success "✓ $hook hook 已清理"
        fi
    done

    if [[ $remaining_claude_hooks -eq 0 ]]; then
        log_success "✓ 所有 Claude hooks 已移除"
    else
        log_error "✗ 仍有 $remaining_claude_hooks 个 Claude hooks 未移除"
        return 1
    fi

    # 检查配置文件
    local remaining_config_files=0
    for config_file in ".claude-hooks-config.sh" ".claude-hooks.log"; do
        if [[ -e "$config_file" ]]; then
            log_warning "⚠ 配置文件仍存在: $config_file"
            ((remaining_config_files++))
        fi
    done

    if [[ $remaining_config_files -eq 0 ]]; then
        log_success "✓ 所有配置文件已清理"
    fi
}

# 显示卸载完成信息
show_completion_info() {
    echo
    echo -e "${GREEN}🎉 Claude Code Git Hooks 卸载完成！${NC}"
    echo
    echo -e "${BLUE}总结:${NC}"
    echo "  ✅ 所有 Claude Code hooks 已移除"
    echo "  ✅ 配置文件已清理"
    echo "  ✅ .gitignore 条目已清理"
    echo
    echo -e "${BLUE}重新安装:${NC}"
    echo "  如需重新安装，请运行: ./install.sh"
    echo
    echo -e "${BLUE}感谢使用 Claude Code Git Hooks！${NC}"
    echo
}

# 主函数
main() {
    show_welcome
    confirm_uninstall

    log_step "开始卸载 Claude Code Git hooks..."

    # 确保在项目根目录
    cd "$(git rev-parse --show-toplevel)"
    log_info "项目根目录: $(pwd)"

    restore_backup_hooks
    remove_claude_hooks
    cleanup_config_files
    cleanup_gitignore
    verify_uninstall

    show_completion_info
}

# 错误处理
trap 'log_error "卸载过程中发生错误，请检查错误信息并重试"' ERR

# 运行主函数
main "$@"