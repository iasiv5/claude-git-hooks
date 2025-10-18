#!/bin/bash

# Claude Code Git Hooks - 文件处理工具模块
# 提供文件操作和处理的通用功能

# =============================================================================
# 全局变量
# =============================================================================

# 默认文件大小限制（字节）
readonly DEFAULT_MAX_FILE_SIZE=100000  # 100KB

# 默认行数限制
readonly DEFAULT_MAX_LINES=500

# 支持的文件扩展名
readonly SUPPORTED_EXTENSIONS="js|ts|jsx|tsx|py|java|go|rs|php|rb|swift|kt|cs|cpp|c|h"

# 要排除的文件模式
readonly DEFAULT_EXCLUDE_PATTERNS="test|spec|\.min\.|node_modules|dist|build|\.git|\.log|\.tmp"

# 二进制文件签名
readonly BINARY_SIGNATURES=(
    "PK\x03\x04"  # ZIP
    "\x7fELF"     # ELF
    "\x25PDF"     # PDF
    "\xff\xd8\xff" # JPEG
    "\x89PNG"     # PNG
    "BM"          # BMP
    "GIF8"       # GIF
    "WAVE"       # WAV
    "\x1a\x45\xdf\xa3" # Matroska/WebM
)

# =============================================================================
# 文件类型检测函数
# =============================================================================

# 检查文件是否为二进制文件
is_binary_file() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        return 1
    fi

    # 使用 file 命令检测（如果可用）
    if command -v file &> /dev/null; then
        local file_output
        file_output=$(file -b --mime-type "$file_path" 2>/dev/null)
        if [[ "$file_output" =~ binary|octet-stream|application/.*-binary ]]; then
            return 0
        fi
    fi

    # 手动检测二进制签名
    if [[ -r "$file_path" ]]; then
        local signature
        signature=$(head -c 8 "$file_path" 2>/dev/null | od -A n -t x1 | tr -d ' \n')

        for bin_sig in "${BINARY_SIGNATURES[@]}"; do
            local hex_sig
            hex_sig=$(echo -n "$bin_sig" | od -A n -t x1 | tr -d ' \n')
            if [[ "$signature" == "$hex_sig"* ]]; then
                return 0
            fi
        done
    fi

    # 检查文件是否包含大量不可打印字符
    local non_printable
    non_printable=$(head -c 1024 "$file_path" 2>/dev/null | tr -d '[:print:][:space:]\0' | wc -c)
    local total_chars
    total_chars=$(head -c 1024 "$file_path" 2>/dev/null | wc -c)

    if [[ $total_chars -gt 0 ]] && [[ $non_printable -gt $((total_chars / 4)) ]]; then
        return 0
    fi

    return 1
}

# 检查文件扩展名是否受支持
is_supported_extension() {
    local file_path="$1"
    local extensions="${2:-$SUPPORTED_EXTENSIONS}"

    local filename
    filename=$(basename "$file_path")
    local extension
    extension="${filename##*.}"

    if [[ -z "$extension" ]]; then
        return 1
    fi

    echo "$extension" | grep -q -E "^($extensions)$"
}

# 检查文件是否应该被排除
should_exclude_file() {
    local file_path="$1"
    local patterns="${2:-$DEFAULT_EXCLUDE_PATTERNS}"

    local filename
    filename=$(basename "$file_path")
    local filepath
    filepath=$(echo "$file_path" | sed 's|/||g')

    # 检查排除模式
    echo "$filepath" | grep -q -E "($patterns)" || echo "$filename" | grep -q -E "($patterns)"
}

# =============================================================================
# 文件大小检查函数
# =============================================================================

# 获取文件大小（字节）
get_file_size() {
    local file_path="$1"

    if [[ -f "$file_path" ]]; then
        wc -c < "$file_path" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# 格式化文件大小
format_file_size() {
    local size_bytes="$1"
    local precision="${2:-1}"

    if [[ $size_bytes -lt 1024 ]]; then
        echo "${size_bytes}B"
    elif [[ $size_bytes -lt 1048576 ]]; then
        echo " $(echo "scale=$precision; $size_bytes/1024" | bc -l)KB"
    elif [[ $size_bytes -lt 1073741824 ]]; then
        echo " $(echo "scale=$precision; $size_bytes/1048576" | bc -l)MB"
    else
        echo " $(echo "scale=$precision; $size_bytes/1073741824" | bc -l)GB"
    fi
}

# 检查文件是否过大
is_file_too_large() {
    local file_path="$1"
    local max_size="${2:-$DEFAULT_MAX_FILE_SIZE}"

    local file_size
    file_size=$(get_file_size "$file_path")

    [[ $file_size -gt $max_size ]]
}

# =============================================================================
# 文件内容获取函数
# =============================================================================

# 安全地读取文件内容
read_file_safely() {
    local file_path="$1"
    local max_lines="${2:-$DEFAULT_MAX_LINES}"

    if [[ ! -f "$file_path" ]]; then
        echo "错误：文件不存在: $file_path" >&2
        return 1
    fi

    if is_binary_file "$file_path"; then
        echo "警告：跳过二进制文件: $file_path" >&2
        return 1
    fi

    # 检查文件大小
    if is_file_too_large "$file_path"; then
        local file_size
        file_size=$(format_file_size "$(get_file_size "$file_path")")
        echo "警告：文件过大 ($file_size)，只读取前 $max_lines 行" >&2
    fi

    # 读取文件内容
    local line_count=0
    local truncate_message=""

    while IFS= read -r line; do
        echo "$line"
        ((line_count++))

        if [[ $line_count -eq $max_lines ]]; then
            truncate_message="\n[...内容已截断，文件较大，只显示前 $max_lines 行...]"
            break
        fi
    done < "$file_path"

    if [[ -n "$truncate_message" ]]; then
        echo -e "$truncate_message"
    fi
}

# 获取文件头信息
get_file_header() {
    local file_path="$1"
    local lines="${2:-10}"

    if [[ ! -f "$file_path" ]]; then
        return 1
    fi

    head -n "$lines" "$file_path" 2>/dev/null
}

# 获取文件尾信息
get_file_tail() {
    local file_path="$1"
    local lines="${2:-10}"

    if [[ ! -f "$file_path" ]]; then
        return 1
    fi

    tail -n "$lines" "$file_path" 2>/dev/null
}

# 获取文件统计信息
get_file_stats() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        echo "文件不存在: $file_path"
        return 1
    fi

    local line_count
    local word_count
    local char_count
    local file_size

    line_count=$(wc -l < "$file_path" 2>/dev/null || echo "0")
    word_count=$(wc -w < "$file_path" 2>/dev/null || echo "0")
    char_count=$(wc -m < "$file_path" 2>/dev/null || echo "0")
    file_size=$(get_file_size "$file_path")

    cat << EOF
文件统计: $file_path
====================
行数: $line_count
单词数: $word_count
字符数: $char_count
文件大小: $(format_file_size "$file_size")
编码: $(file -b --mime-encoding "$file_path" 2>/dev/null || echo "unknown")
类型: $(file -b --mime-type "$file_path" 2>/dev/null || echo "unknown")
二进制: $(is_binary_file "$file_path" && echo "是" || echo "否")
EOF
}

# =============================================================================
# 文件过滤函数
# =============================================================================

# 过滤文件列表
filter_files() {
    local file_list="$1"
    local extensions="${2:-$SUPPORTED_EXTENSIONS}"
    local exclude_patterns="${3:-$DEFAULT_EXCLUDE_PATTERNS}"
    local max_size="${4:-$DEFAULT_MAX_FILE_SIZE}"

    local filtered_files=""

    for file in $file_list; do
        # 跳过不存在的文件
        if [[ ! -f "$file" ]]; then
            continue
        fi

        # 检查扩展名
        if ! is_supported_extension "$file" "$extensions"; then
            continue
        fi

        # 检查排除模式
        if should_exclude_file "$file" "$exclude_patterns"; then
            continue
        fi

        # 检查文件大小
        if is_file_too_large "$file" "$max_size"; then
            echo "警告：跳过过大文件: $file ($(format_file_size "$(get_file_size "$file")"))" >&2
            continue
        fi

        # 检查是否为二进制文件
        if is_binary_file "$file"; then
            echo "警告：跳过二进制文件: $file" >&2
            continue
        fi

        # 添加到过滤列表
        filtered_files="$filtered_files $file"
    done

    echo "$filtered_files" | xargs -n1 | sort -u
}

# 获取 Git 暂存的文件列表
get_staged_files() {
    local extensions="${1:-$SUPPORTED_EXTENSIONS}"
    local exclude_patterns="${2:-$DEFAULT_EXCLUDE_PATTERNS}"
    local max_size="${3:-$DEFAULT_MAX_FILE_SIZE}"

    # 获取暂存文件列表
    local staged_files
    staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)

    # 过滤文件
    filter_files "$staged_files" "$extensions" "$exclude_patterns" "$max_size"
}

# 获取 Git 修改的文件列表
get_modified_files() {
    local commit_range="${1:-HEAD}"
    local extensions="${2:-$SUPPORTED_EXTENSIONS}"
    local exclude_patterns="${3:-$DEFAULT_EXCLUDE_PATTERNS}"
    local max_size="${4:-$DEFAULT_MAX_FILE_SIZE}"

    # 获取修改文件列表
    local modified_files
    modified_files=$(git diff --name-only "$commit_range" 2>/dev/null)

    # 过滤文件
    filter_files "$modified_files" "$extensions" "$exclude_patterns" "$max_size"
}

# =============================================================================
# 文件内容分析函数
# =============================================================================

# 分析文件复杂度
analyze_file_complexity() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        return 1
    fi

    local line_count
    local function_count
    local max_function_length
    local nesting_level
    local complexity_score

    line_count=$(wc -l < "$file_path" 2>/dev/null || echo "0")

    # 计算函数数量（简单方法）
    function_count=$(grep -c -E "^\s*(function|def |class |public |private |protected |static |async |const |let |var )" "$file_path" 2>/dev/null || echo "0")

    # 计算最大函数长度（简单方法）
    max_function_length=$(awk '
        /^[[:space:]]*(function|def |class |public |private |protected |static |async |const |let |var )/ {
            if (func_start) {
                length = NR - func_start - 1
                if (length > max_length) max_length = length
            }
            func_start = NR
        }
        END {
            if (func_start) {
                length = NR - func_start
                if (length > max_length) max_length = length
            }
            print max_length + 1
        }
    ' "$file_path" 2>/dev/null || echo "0")

    # 计算嵌套级别（简单方法）
    nesting_level=$(awk '
        {
            gsub(/\/\*.*\*\//, "")  # 移除多行注释
            gsub(/\/\/.*/, "")      # 移除单行注释
            gsub(/".*"/, "\"\"")   # 替换字符串
            gsub(/'.*'/, "''")     # 替换字符串
        }
        {
            depth += gsub(/\{/, "")
            depth += gsub(/\(/, "")
            if (depth > max_depth) max_depth = depth
            depth -= gsub(/\}/, "")
            depth -= gsub(/\)/, "")
            if (depth < 0) depth = 0
        }
        END {
            print max_depth
        }
    ' "$file_path" 2>/dev/null || echo "0")

    # 计算复杂度分数
    complexity_score=$((line_count + function_count * 10 + max_function_length * 2 + nesting_level * 5))

    cat << EOF
文件复杂度分析: $file_path
=========================
行数: $line_count
函数/类数量: $function_count
最大函数长度: $max_function_length 行
最大嵌套级别: $nesting_level
复杂度分数: $complexity_score
风险等级: $([[ $complexity_score -lt 100 ]] && echo "低" || [[ $complexity_score -lt 200 ]] && echo "中" || echo "高")
EOF
}

# 检测代码模式
detect_code_patterns() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        return 1
    fi

    local todo_count
    local fixme_count
    local hack_count
    local debug_count
    local console_count

    todo_count=$(grep -c -i "todo" "$file_path" 2>/dev/null || echo "0")
    fixme_count=$(grep -c -i "fixme" "$file_path" 2>/dev/null || echo "0")
    hack_count=$(grep -c -i "hack" "$file_path" 2>/dev/null || echo "0")
    debug_count=$(grep -c -i "debug\|console\.log\|console\.debug\|console\.error" "$file_path" 2>/dev/null || echo "0")

    cat << EOF
代码模式检测: $file_path
=====================
TODO 注释: $todo_count
FIXME 注释: $fixme_count
HACK 注释: $hack_count
调试代码: $debug_count
EOF
}

# =============================================================================
# 文件内容搜索函数
# =============================================================================

# 在文件中搜索模式
search_in_file() {
    local file_path="$1"
    local pattern="$2"
    local context_lines="${3:-2}"

    if [[ ! -f "$file_path" ]]; then
        return 1
    fi

    if command -v grep &> /dev/null; then
        grep --color=auto -n -C "$context_lines" "$pattern" "$file_path" 2>/dev/null
    else
        echo "grep 命令不可用"
        return 1
    fi
}

# 在多个文件中搜索模式
search_in_files() {
    local file_list="$1"
    local pattern="$2"
    local context_lines="${3:-2}"

    if [[ -z "$file_list" ]]; then
        return 1
    fi

    if command -v grep &> /dev/null; then
        echo "$file_list" | xargs grep --color=auto -n -C "$context_lines" "$pattern" 2>/dev/null
    else
        echo "grep 命令不可用"
        return 1
    fi
}

# =============================================================================
# 文件比较函数
# =============================================================================

# 比较两个文件的差异
compare_files() {
    local file1="$1"
    local file2="$2"

    if [[ ! -f "$file1" ]]; then
        echo "文件不存在: $file1" >&2
        return 1
    fi

    if [[ ! -f "$file2" ]]; then
        echo "文件不存在: $file2" >&2
        return 1
    fi

    if command -v diff &> /dev/null; then
        diff -u "$file1" "$file2" 2>/dev/null || {
            echo "文件不同:"
            echo "  $file1"
            echo "  $file2"
            return 1
        }
        echo "文件相同"
    else
        echo "diff 命令不可用"
        return 1
    fi
}

# =============================================================================
# 文件备份函数
# =============================================================================

# 备份文件
backup_file() {
    local file_path="$1"
    local backup_dir="${2:-.backups}"

    if [[ ! -f "$file_path" ]]; then
        return 1
    fi

    # 创建备份目录
    mkdir -p "$backup_dir" 2>/dev/null || return 1

    # 生成备份文件名
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local filename
    filename=$(basename "$file_path")
    local backup_path
    backup_path="$backup_dir/${filename}.$timestamp.backup"

    # 执行备份
    cp "$file_path" "$backup_path" 2>/dev/null || return 1

    echo "文件已备份: $backup_path"
    return 0
}

# =============================================================================
# 工具函数
# =============================================================================

# 显示文件信息
show_file_info() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        echo "文件不存在: $file_path" >&2
        return 1
    fi

    local file_size
    file_size=$(format_file_size "$(get_file_size "$file_path")")
    local modification_time
    modification_time=$(stat -c '%y' "$file_path" 2>/dev/null || stat -f '%Sm' "$file_path" 2>/dev/null || echo "unknown")
    local file_type
    file_type=$(file -b "$file_path" 2>/dev/null || echo "unknown")

    cat << EOF
文件信息: $file_path
==================
大小: $file_size
修改时间: $modification_time
类型: $file_type
路径: $(readlink -f "$file_path" 2>/dev/null || echo "$file_path")
可读: $([[ -r "$file_path" ]] && echo "是" || echo "否")
可写: $([[ -w "$file_path" ]] && echo "是" || echo "否")
可执行: $([[ -x "$file_path" ]] && echo "是" || echo "否")
EOF
}

# 验证文件路径
validate_file_path() {
    local file_path="$1"

    # 检查路径是否为空
    if [[ -z "$file_path" ]]; then
        echo "错误：文件路径为空" >&2
        return 1
    fi

    # 检查路径是否包含可疑字符
    if [[ "$file_path" =~ [^a-zA-Z0-9_/.\-~] ]]; then
        echo "警告：文件路径包含特殊字符: $file_path" >&2
    fi

    # 检查路径长度
    if [[ ${#file_path} -gt 4096 ]]; then
        echo "错误：文件路径过长" >&2
        return 1
    fi

    return 0
}

# =============================================================================
# 模块测试函数
# =============================================================================

# 运行文件工具测试
test_file_utils() {
    echo "Claude Code Git Hooks - 文件工具测试"
    echo "================================="

    # 创建测试文件
    local test_file="/tmp/claude_test.txt"
    echo "测试内容" > "$test_file"

    echo "测试文件信息:"
    show_file_info "$test_file"
    echo

    echo "测试文件过滤:"
    local test_files="$test_file /tmp/nonexistent.txt"
    filter_files "$test_files" 2>/dev/null
    echo

    echo "测试文件统计:"
    get_file_stats "$test_file"
    echo

    echo "测试代码模式检测:"
    echo "TODO: fix this" > "$test_file"
    detect_code_patterns "$test_file"
    echo

    echo "测试文件备份:"
    backup_file "$test_file" "/tmp/test_backups"
    echo

    # 清理测试文件
    rm -f "$test_file"
    rm -rf "/tmp/test_backups"

    echo "测试完成！"
}

# =============================================================================
# 模块加载检查
# =============================================================================

# 如果直接执行此文件，运行测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_file_utils
fi