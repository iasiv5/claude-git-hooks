#!/bin/bash

# Claude Code Git Hooks - Claude 客户端封装模块
# 提供 Claude Code API 调用的统一接口

# =============================================================================
# 全局变量
# =============================================================================

# Claude API 配置
readonly CLAUDE_API_BASE_URL="${CLAUDE_API_ENDPOINT:-https://api.anthropic.com}"
readonly CLAUDE_API_VERSION="2023-06-01"
readonly CLAUDE_DEFAULT_MODEL="sonnet"
readonly CLAUDE_DEFAULT_TIMEOUT=30000

# API 请求配置
readonly API_REQUEST_TIMEOUT="${API_REQUEST_TIMEOUT:-30}"
readonly API_CONNECT_TIMEOUT="${API_CONNECT_TIMEOUT:-10}"
readonly API_READ_TIMEOUT="${API_READ_TIMEOUT:-30}"

# 重试配置
readonly DEFAULT_MAX_RETRIES=3
readonly DEFAULT_RETRY_DELAY=1000

# 错误代码
readonly ERROR_API_TIMEOUT=1
readonly ERROR_API_UNAUTHORIZED=2
readonly ERROR_API_RATE_LIMIT=3
readonly ERROR_API_SERVER_ERROR=4
readonly ERROR_CLIENT_ERROR=5

# 缓存配置
readonly CACHE_ENABLED="${ENABLE_CACHE:-true}"
readonly CACHE_TTL="${CACHE_EXPIRY:-3600}"
readonly CACHE_DIR="${CACHE_DIR:-.claude-cache}"

# =============================================================================
# Claude 客户端类
# =============================================================================

# Claude API 响应结构
declare -A CLAUDE_RESPONSE
declare -A CLAUDE_REQUEST

# =============================================================================
# 配置验证函数
# =============================================================================

# 验证 Claude API 配置
validate_claude_config() {
    local config="$1"

    # 检查 API Key
    if [[ -z "${config[api_key]}" ]]; then
        if [[ -n "$ANTHROPIC_API_KEY" ]]; then
            config[api_key]="$ANTHROPIC_API_KEY"
        else
            echo "错误：Claude API Key 未设置" >&2
            return $ERROR_CLIENT_ERROR
        fi
    fi

    # 设置默认值
    config[model]="${config[model]:-$CLAUDE_DEFAULT_MODEL}"
    config[timeout]="${config[timeout]:-$CLAUDE_DEFAULT_TIMEOUT}"
    config[max_retries]="${config[max_retries]:-$DEFAULT_MAX_RETRIES}"
    config[retry_delay]="${config[retry_delay]:-$DEFAULT_RETRY_DELAY}"
    config[base_url]="${config[base_url]:-$CLAUDE_API_BASE_URL}"

    # 验证超时设置
    if [[ ${config[timeout]} -lt 1000 ]]; then
        echo "警告：超时时间过短，建议至少 1000 毫秒" >&2
    fi

    # 验证模型名称
    case "${config[model]}" in
        sonnet|opus|haiku|claude-*)
            ;;
        *)
            echo "错误：不支持的模型: ${config[model]}" >&2
            return $ERROR_CLIENT_ERROR
            ;;
    esac

    return 0
}

# 验证请求参数
validate_request_params() {
    local prompt="$1"
    local system_prompt="$2"
    local model="$3"

    # 检查提示词
    if [[ -z "$prompt" ]]; then
        echo "错误：提示词不能为空" >&2
        return $ERROR_CLIENT_ERROR
    fi

    # 检查模型
    if [[ -n "$model" ]]; then
        case "$model" in
            sonnet|opus|haiku|claude-*)
                ;;
            *)
                echo "错误：不支持的模型: $model" >&2
                return $ERROR_CLIENT_ERROR
                ;;
        esac
    fi

    return 0
}

# =============================================================================
# 缓存管理函数
# =============================================================================

# 初始化缓存
init_cache() {
    if [[ "$CACHE_ENABLED" != "true" ]]; then
        return 1
    fi

    # 创建缓存目录
    mkdir -p "$CACHE_DIR" 2>/dev/null || return 1

    return 0
}

# 生成缓存键
generate_cache_key() {
    local prompt="$1"
    local system_prompt="$2"
    local model="$3"

    # 组合所有参数生成唯一键
    local cache_input="${prompt}${system_prompt}${model}"

    # 使用 SHA256 生成哈希
    if command -v sha256sum &> /dev/null; then
        echo -n "$cache_input" | sha256sum | cut -d' ' -f1
    elif command -v shasum &> /dev/null; then
        echo -n "$cache_input" | shasum -a 256 | cut -d' ' -f1
    else
        # 如果没有哈希命令，使用简单哈希
        echo -n "$cache_input" | cksum | cut -d' ' -f1
    fi
}

# 从缓存获取响应
get_from_cache() {
    local cache_key="$1"

    if [[ "$CACHE_ENABLED" != "true" ]]; then
        return 1
    fi

    local cache_file="$CACHE_DIR/response_$cache_key.json"

    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi

    # 检查缓存是否过期
    local current_time
    current_time=$(date +%s)
    local cache_time
    cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)

    if [[ $((current_time - cache_time)) -gt $CACHE_TTL ]]; then
        rm -f "$cache_file"
        return 1
    fi

    # 读取缓存内容
    cat "$cache_file"
    return 0
}

# 保存响应到缓存
save_to_cache() {
    local cache_key="$1"
    local response="$2"

    if [[ "$CACHE_ENABLED" != "true" ]]; then
        return 1
    fi

    local cache_file="$CACHE_DIR/response_$cache_key.json"

    echo "$response" > "$cache_file"
    return 0
}

# 清理过期缓存
cleanup_cache() {
    if [[ "$CACHE_ENABLED" != "true" ]]; then
        return 0
    fi

    if [[ ! -d "$CACHE_DIR" ]]; then
        return 0
    fi

    local current_time
    current_time=$(date +%s)
    local cleaned_count=0

    while IFS= read -r -d '' cache_file; do
        local cache_time
        cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)

        if [[ $((current_time - cache_time)) -gt $CACHE_TTL ]]; then
            rm -f "$cache_file"
            ((cleaned_count++))
        fi
    done < <(find "$CACHE_DIR" -name "response_*.json" -type f -print0 2>/dev/null)

    echo "清理了 $cleaned_count 个过期缓存文件"
    return 0
}

# =============================================================================
# HTTP 请求函数
# =============================================================================

# 构建 HTTP 请求头
build_request_headers() {
    local api_key="$1"
    local model="$2"

    local headers=()

    # 基本认证头
    headers+=("x-api-key: $api_key")
    headers+=("anthropic-version: $CLAUDE_API_VERSION")
    headers+=("content-type: application/json")

    # 模型特定头
    if [[ "$model" == *"opus"* ]]; then
        headers+=("anthropic-beta: messages-2023-12-15")
    fi

    echo "${headers[@]}"
}

# 构建 JSON 请求体
build_request_body() {
    local prompt="$1"
    local system_prompt="$2"
    local model="$3"
    local max_tokens="${4:-4096}"
    local temperature="${5:-0.7}"
    local stream="${6:-false}"

    cat << EOF
{
    "model": "$model",
    "max_tokens": $max_tokens,
    "temperature": $temperature,
    "stream": $stream,
EOF

    if [[ -n "$system_prompt" ]]; then
        cat << EOF
    "system": "$(echo "$system_prompt" | sed 's/"/\\"/g')",
EOF
    fi

    cat << EOF
    "messages": [
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": "$(echo "$prompt" | sed 's/"/\\"/g')"
                }
            ]
        }
    ]
}
EOF
}

# 执行 HTTP 请求
execute_http_request() {
    local url="$1"
    local headers=("${@:2}")
    local body="$4"
    local timeout="$5"

    # 检查 curl 是否可用
    if ! command -v curl &> /dev/null; then
        echo "错误：curl 命令不可用" >&2
        return $ERROR_CLIENT_ERROR
    fi

    # 构建 curl 命令
    local curl_cmd="curl"
    curl_cmd+=" -s"
    curl_cmd+=" --connect-timeout $API_CONNECT_TIMEOUT"
    curl_cmd+=" --max-time $timeout"
    curl_cmd+=" --fail"

    # 添加请求头
    for header in "${headers[@]}"; do
        curl_cmd+=" -H \"$header\""
    done

    # 添加请求体
    if [[ -n "$body" ]]; then
        curl_cmd+=" -d \"$body\""
    fi

    # 设置 URL
    curl_cmd+=" \"$url\""

    # 执行请求
    local response
    local exit_code

    if [[ "$CLAUDE_HOOKS_DEBUG" == "true" ]]; then
        echo "执行请求: $curl_cmd" >&2
    fi

    response=$(eval "$curl_cmd")
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        case $exit_code in
            28)
                echo "错误：请求超时" >&2
                return $ERROR_API_TIMEOUT
                ;;
            22)
                echo "错误：HTTP 请求失败 (HTTP 4xx/5xx)" >&2
                return $ERROR_API_SERVER_ERROR
                ;;
            *)
                echo "错误：curl 命令失败 (退出码: $exit_code)" >&2
                return $ERROR_CLIENT_ERROR
                ;;
        esac
    fi

    echo "$response"
    return 0
}

# =============================================================================
# API 响应解析函数
# =============================================================================

# 解析 API 响应
parse_api_response() {
    local response="$1"

    if [[ -z "$response" ]]; then
        echo "错误：空响应" >&2
        return $ERROR_CLIENT_ERROR
    fi

    # 尝试解析 JSON
    if command -v jq &> /dev/null; then
        if ! echo "$response" | jq empty 2>/dev/null; then
            echo "错误：无效的 JSON 响应" >&2
            return $ERROR_CLIENT_ERROR
        fi

        # 提取错误信息
        local error_type
        error_type=$(echo "$response" | jq -r '.error.type // ""' 2>/dev/null)

        if [[ -n "$error_type" ]]; then
            local error_message
            error_message=$(echo "$response" | jq -r '.error.message // "未知错误"' 2>/dev/null)

            case "$error_type" in
                "authentication_error")
                    echo "错误：API 认证失败 - $error_message" >&2
                    return $ERROR_API_UNAUTHORIZED
                    ;;
                "rate_limit_error")
                    echo "错误：API 速率限制 - $error_message" >&2
                    return $ERROR_API_RATE_LIMIT
                    ;;
                "overloaded_error")
                    echo "错误：API 服务过载 - $error_message" >&2
                    return $ERROR_API_SERVER_ERROR
                    ;;
                *)
                    echo "错误：API 错误 ($error_type) - $error_message" >&2
                    return $ERROR_API_SERVER_ERROR
                    ;;
            esac
        fi

        # 提取内容
        echo "$response" | jq -r '.content[0].text // ""' 2>/dev/null
        return 0
    else
        # 如果没有 jq，尝试简单的文本提取
        if [[ "$response" == *"error"* ]]; then
            echo "错误：API 返回错误响应" >&2
            return $ERROR_API_SERVER_ERROR
        fi

        # 返回原始响应
        echo "$response"
        return 0
    fi
}

# =============================================================================
# Claude API 调用函数
# =============================================================================

# 调用 Claude API
call_claude_api() {
    local prompt="$1"
    local system_prompt="$2"
    local model="$3"
    local max_tokens="$4"
    local temperature="$5"
    local stream="$6"

    local -A config
    config[model]="$model"
    config[timeout]="$API_REQUEST_TIMEOUT"

    # 验证配置
    if ! validate_claude_config config; then
        return $?
    fi

    # 验证请求参数
    if ! validate_request_params "$prompt" "$system_prompt" "$model"; then
        return $?
    fi

    # 初始化缓存
    init_cache

    # 检查缓存
    local cache_key
    cache_key=$(generate_cache_key "$prompt" "$system_prompt" "${config[model]}")

    local cached_response
    if cached_response=$(get_from_cache "$cache_key"); then
        if [[ "$CLAUDE_HOOKS_DEBUG" == "true" ]]; then
            echo "从缓存获取响应" >&2
        fi
        echo "$cached_response"
        return 0
    fi

    # 构建 API 请求
    local url="${config[base_url]}/v1/messages"
    local headers
    readarray -t headers < <(build_request_headers "${config[api_key]}" "${config[model]}")
    local body
    body=$(build_request_body "$prompt" "$system_prompt" "${config[model]}" "$max_tokens" "$temperature" "$stream")

    # 设置重试次数和延迟
    local max_retries="${config[max_retries]}"
    local retry_delay="${config[retry_delay]}"
    local retry_count=0
    local last_error=0

    while [[ $retry_count -lt $max_retries ]]; do
        if [[ $retry_count -gt 0 ]]; then
            if [[ "$CLAUDE_HOOKS_DEBUG" == "true" ]]; then
                echo "重试 $retry_count/$max_retries (延迟 ${retry_delay}ms)..." >&2
            fi
            sleep $((retry_delay / 1000))
            # 指数退避
            retry_delay=$((retry_delay * 2))
        fi

        # 执行 API 请求
        local response
        local api_result=0

        if ! response=$(execute_http_request "$url" "${headers[@]}" "$body" "${config[timeout]}"); then
            api_result=$?
            last_error=$api_result
            ((retry_count++))
            continue
        fi

        # 解析响应
        local parsed_response
        local parse_result=0

        if ! parsed_response=$(parse_api_response "$response"); then
            parse_result=$?
            last_error=$parse_result
            ((retry_count++))
            continue
        fi

        # 保存到缓存
        if [[ -n "$parsed_response" ]]; then
            save_to_cache "$cache_key" "$parsed_response" 2>/dev/null || true
        fi

        # 返回响应
        echo "$parsed_response"
        return 0
    done

    # 所有重试都失败
    case $last_error in
        $ERROR_API_TIMEOUT)
            echo "错误：Claude API 请求超时（重试 $max_retries 次后）" >&2
            ;;
        $ERROR_API_UNAUTHORIZED)
            echo "错误：Claude API 认证失败" >&2
            ;;
        $ERROR_API_RATE_LIMIT)
            echo "错误：Claude API 速率限制（重试 $max_retries 次后）" >&2
            ;;
        $ERROR_API_SERVER_ERROR)
            echo "错误：Claude API 服务器错误（重试 $max_retries 次后）" >&2
            ;;
        *)
            echo "错误：Claude API 调用失败（重试 $max_retries 次后）" >&2
            ;;
    esac

    return $last_error
}

# =============================================================================
# 便利函数
# =============================================================================

# 简化的 Claude 调用
claude() {
    local prompt="$1"
    local system_prompt="${2:-}"
    local model="${3:-$CLAUDE_DEFAULT_MODEL}"
    local timeout="${4:-$CLAUDE_DEFAULT_TIMEOUT}"
    local max_tokens="${5:-4096}"
    local temperature="${6:-0.7}"

    # 设置超时
    export API_REQUEST_TIMEOUT=$((timeout / 1000))

    if [[ "$CLAUDE_HOOKS_DEBUG" == "true" ]]; then
        echo "Claude API 调用参数:" >&2
        echo "  Model: $model" >&2
        echo "  Timeout: ${timeout}ms" >&2
        echo "  Max tokens: $max_tokens" >&2
        echo "  Temperature: $temperature" >&2
        echo "  Prompt length: ${#prompt} characters" >&2
        if [[ -n "$system_prompt" ]]; then
            echo "  System prompt length: ${#system_prompt} characters" >&2
        fi
    fi

    # 调用 API
    local result
    if ! result=$(call_claude_api "$prompt" "$system_prompt" "$model" "$max_tokens" "$temperature"); then
        local exit_code=$?
        echo "Claude API 调用失败" >&2
        return $exit_code
    fi

    echo "$result"
    return 0
}

# 批量处理
claude_batch() {
    local -a prompts=("$@")
    local results=()
    local total=${#prompts[@]}

    if [[ $total -eq 0 ]]; then
        echo "错误：没有提供提示词" >&2
        return 1
    fi

    echo "批量处理 $total 个请求..." >&2

    local i=0
    for prompt in "${prompts[@]}"; do
        ((i++))
        if [[ "$CLAUDE_HOOKS_DEBUG" == "true" ]]; then
            echo "处理请求 $i/$total..." >&2
        fi

        local result
        if ! result=$(claude "$prompt"); then
            echo "请求 $i/$total 失败" >&2
            results+=("ERROR: Request failed")
        else
            results+=("$result")
        fi
    done

    # 输出所有结果
    printf '%s\n' "${results[@]}"
}

# 流式处理
claude_stream() {
    local prompt="$1"
    local system_prompt="${2:-}"
    local model="${3:-$CLAUDE_DEFAULT_MODEL}"

    # 流式处理需要特殊处理
    echo "警告：流式处理功能尚未实现，使用普通请求" >&2
    claude "$prompt" "$system_prompt" "$model"
}

# =============================================================================
# 健康检查函数
# =============================================================================

# 检查 Claude API 健康状态
check_claude_health() {
    local model="${1:-$CLAUDE_DEFAULT_MODEL}"

    echo "检查 Claude API 健康状态..." >&2

    # 简单的健康检查
    local test_prompt="Hello, this is a health check."
    local response

    if ! response=$(claude "$test_prompt" "You are a health check endpoint" "$model" 10000); then
        echo "❌ Claude API 不健康" >&2
        return 1
    fi

    if [[ -n "$response" ]]; then
        echo "✅ Claude API 健康" >&2
        return 0
    else
        echo "❌ Claude API 返回空响应" >&2
        return 1
    fi
}

# 检查 API 配置
check_claude_config() {
    echo "Claude API 配置检查:" >&2
    echo "====================" >&2

    # 检查 API Key
    if [[ -n "$ANTHROPIC_API_KEY" ]]; then
        echo "✅ API Key: 已设置" >&2
        echo "   Key 长度: ${#ANTHROPIC_API_KEY} 字符" >&2
        # 隐藏大部分 key
        local masked_key="${ANTHROPIC_API_KEY:0:8}...${ANTHROPIC_API_KEY: -4}"
        echo "   Key 内容: $masked_key" >&2
    else
        echo "❌ API Key: 未设置" >&2
        return 1
    fi

    # 检查模型
    local model="${CLAUDE_MODEL:-$CLAUDE_DEFAULT_MODEL}"
    echo "✅ 模型: $model" >&2

    # 检查 curl
    if command -v curl &> /dev/null; then
        local curl_version
        curl_version=$(curl --version | head -n1)
        echo "✅ curl: 可用" >&2
        echo "   版本: $curl_version" >&2
    else
        echo "❌ curl: 不可用" >&2
        return 1
    fi

    # 检查 JSON 处理工具
    if command -v jq &> /dev/null; then
        local jq_version
        jq_version=$(jq --version)
        echo "✅ jq: 可用" >&2
        echo "   版本: $jq_version" >&2
    else
        echo "⚠️  jq: 不可用（可选，用于更好的 JSON 处理）" >&2
    fi

    echo "" >&2
    return 0
}

# =============================================================================
# 模块测试函数
# =============================================================================

# 测试 Claude 客户端
test_claude_client() {
    echo "Claude Code Git Hooks - Claude 客户端测试"
    echo "======================================="

    # 检查配置
    if ! check_claude_config; then
        echo "配置检查失败" >&2
        return 1
    fi

    # 健康检查
    if [[ "$CLAUDE_HOOKS_DEBUG" == "true" ]]; then
        if ! check_claude_health; then
            echo "健康检查失败" >&2
            return 1
        fi
    fi

    # 简单测试
    echo "执行简单测试..." >&2
    local test_prompt="请回复'测试成功'"
    local response

    if response=$(claude "$test_prompt"); then
        echo "测试成功！响应:" >&2
        echo "$response" | head -c 200
        echo "" >&2
    else
        echo "测试失败" >&2
        return 1
    fi

    # 测试缓存
    if [[ "$CACHE_ENABLED" == "true" ]]; then
        echo "测试缓存功能..." >&2
        local cache_key
        cache_key=$(generate_cache_key "$test_prompt" "" "$CLAUDE_DEFAULT_MODEL")
        echo "缓存键: $cache_key" >&2

        if [[ -f "$CACHE_DIR/response_$cache_key.json" ]]; then
            echo "✅ 缓存工作正常" >&2
        else
            echo "⚠️  缓存可能不工作" >&2
        fi
    fi

    echo "" >&2
    echo "Claude 客户端测试完成！" >&2
}

# =============================================================================
# 模块加载检查
# =============================================================================

# 如果直接执行此文件，运行测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_claude_client
fi