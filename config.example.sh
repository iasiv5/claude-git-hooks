#!/bin/bash

# Claude Code Git Hooks 配置文件示例
# 复制此文件为 config.sh 并根据需要修改配置

# =============================================================================
# Claude Code 配置
# =============================================================================

# Claude API 超时时间（毫秒）
# 建议值：15000（15秒）到 60000（60秒）
export CLAUDE_TIMEOUT=${CLAUDE_TIMEOUT:-30000}

# 使用的 Claude 模型
# 可选值：sonnet, opus, haiku
export CLAUDE_MODEL=${CLAUDE_MODEL:-"sonnet"}

# Claude API 重试次数
export CLAUDE_API_RETRIES=${CLAUDE_API_RETRIES:-3}

# Claude API 重试延迟（毫秒）
export CLAUDE_API_RETRY_DELAY=${CLAUDE_API_RETRY_DELAY:-1000}

# =============================================================================
# Hook 启用控制
# =============================================================================

# 是否启用 Pre-commit Hook
# true：每次提交前进行代码审查
# false：跳过 pre-commit 检查
export PRE_COMMIT_ENABLED=${PRE_COMMIT_ENABLED:-true}

# 是否启用 Commit Message Hook
# true：每次提交时检查提交消息质量
# false：跳过提交消息检查
export COMMIT_MSG_ENABLED=${COMMIT_MSG_ENABLED:-true}

# 是否启用 Pre-push Hook
# true：每次推送前进行最终质量检查
# false：跳过 pre-push 检查
export PRE_PUSH_ENABLED=${PRE_PUSH_ENABLED:-true}

# =============================================================================
# 文件类型过滤
# =============================================================================

# 需要检查的文件扩展名（正则表达式）
# 默认包含主流编程语言文件
export CODE_EXTENSIONS=${CODE_EXTENSIONS:-"js|ts|jsx|tsx|py|java|go|rs|php|rb|swift|kt|cs|cpp|c|h"}

# 排除的文件模式（正则表达式）
# 默认排除测试文件、构建产物等
export EXCLUDE_PATTERNS=${EXCLUDE_PATTERNS:-"test|spec|\.min\.|node_modules|dist|build|\.git"}

# 单个文件最大大小（字节）
# 超过此大小的文件将被跳过
# 默认：100KB
export MAX_FILE_SIZE=${MAX_FILE_SIZE:-100000}

# 单次提交最大检查文件数
# 超过此数量将只检查前 N 个文件
# 默认：20 个文件
export MAX_FILES_PER_COMMIT=${MAX_FILES_PER_COMMIT:-20}

# =============================================================================
# 分析级别配置
# =============================================================================

# 总体分析级别
# quick：快速检查，只检查明显问题
# moderate：标准检查，平衡速度和深度
# thorough：深度检查，进行全面分析
export ANALYSIS_LEVEL=${ANALYSIS_LEVEL:-"moderate"}

# 安全检查级别
# strict：严格安全检查
# moderate：标准安全检查
# lax：宽松安全检查
export SECURITY_CHECK_LEVEL=${SECURITY_CHECK_LEVEL:-"moderate"}

# 性能检查级别
# strict：严格性能检查
# moderate：标准性能检查
# lax：宽松性能检查
export PERFORMANCE_CHECK_LEVEL=${PERFORMANCE_CHECK_LEVEL:-"moderate"}

# 代码风格检查级别
# strict：严格风格检查
# moderate：标准风格检查
# lax：宽松风格检查
export STYLE_CHECK_LEVEL=${STYLE_CHECK_LEVEL:-"lax"}

# =============================================================================
# 日志和调试配置
# =============================================================================

# 是否启用调试模式
# true：显示详细的调试信息
# false：只显示基本日志
export CLAUDE_HOOKS_DEBUG=${CLAUDE_HOOKS_DEBUG:-false}

# 日志文件路径
export LOG_FILE=${LOG_FILE:-".claude-hooks.log"}

# 日志级别
# DEBUG：显示所有日志
# INFO：显示信息级别以上日志
# WARN：显示警告级别以上日志
# ERROR：只显示错误日志
export LOG_LEVEL=${LOG_LEVEL:-"INFO"}

# 是否彩色输出
export COLOR_OUTPUT=${COLOR_OUTPUT:-true}

# =============================================================================
# 性能优化配置
# =============================================================================

# 是否启用并行处理
# true：并行分析多个文件
# false：串行分析文件
export ENABLE_PARALLEL_PROCESSING=${ENABLE_PARALLEL_PROCESSING:-false}

# 并行处理的最大进程数
export MAX_PARALLEL_PROCESSES=${MAX_PARALLEL_PROCESSES:-4}

# 是否启用结果缓存
# true：缓存分析结果以提高性能
# false：每次都重新分析
export ENABLE_CACHE=${ENABLE_CACHE:-true}

# 缓存目录
export CACHE_DIR=${CACHE_DIR:-".claude-hooks-cache"}

# 缓存过期时间（秒）
# 默认：1小时
export CACHE_EXPIRY=${CACHE_EXPIRY:-3600}

# =============================================================================
# API 配置
# =============================================================================

# Claude API 端点（通常不需要修改）
export CLAUDE_API_ENDPOINT=${CLAUDE_API_ENDPOINT:-"https://api.anthropic.com"}

# API 请求超时（秒）
export API_REQUEST_TIMEOUT=${API_REQUEST_TIMEOUT:-30}

# API 连接超时（秒）
export API_CONNECT_TIMEOUT=${API_CONNECT_TIMEOUT:-10}

# =============================================================================
# 项目特定配置
# =============================================================================

# 项目名称（用于日志和报告）
export PROJECT_NAME=${PROJECT_NAME:-$(basename "$(pwd)")}

# 项目类型（影响分析策略）
# 可选值：web, mobile, backend, frontend, fullstack, library, cli
export PROJECT_TYPE=${PROJECT_TYPE:-"web"}

# 编程语言（主要语言）
# 用于优化分析策略
export PRIMARY_LANGUAGE=${PRIMARY_LANGUAGE:-"javascript"}

# 测试框架（用于优化测试相关检查）
export TEST_FRAMEWORK=${TEST_FRAMEWORK:-"jest"}

# 构建工具（用于优化构建相关检查）
export BUILD_TOOL=${BUILD_TOOL:-"npm"}

# =============================================================================
# 自定义审查规则
# =============================================================================

# 自定义检查规则列表
export CUSTOM_RULES=${CUSTOM_RULES:-""}

# 检查是否包含 TODO 注释
export CHECK_TODO_COMMENTS=${CHECK_TODO_COMMENTS:-true}

# 检查是否包含 FIXME 注释
export CHECK_FIXME_COMMENTS=${CHECK_FIXME_COMMENTS:-true}

# 检查是否包含调试代码
export CHECK_DEBUG_CODE=${CHECK_DEBUG_CODE:-true}

# 检查是否包含 console.log 等
export CHECK_CONSOLE_STATEMENTS=${CHECK_CONSOLE_STATEMENTS:-true}

# 检查是否包含硬编码的秘密信息
export CHECK_SECRETS=${CHECK_SECRETS:-true}

# 检查大文件
export CHECK_LARGE_FILES=${CHECK_LARGE_FILES:-true}

# 检查长函数
export CHECK_LONG_FUNCTIONS=${CHECK_LONG_FUNCTIONS:-true}

# 检查复杂条件
export CHECK_COMPLEX_CONDITIONS=${CHECK_COMPLEX_CONDITIONS:-true}

# =============================================================================
# 报告配置
# =============================================================================

# 报告格式
# text：纯文本格式
# json：JSON 格式
# html：HTML 格式
export REPORT_FORMAT=${REPORT_FORMAT:-"text"}

# 报告输出目录
export REPORT_OUTPUT_DIR=${REPORT_OUTPUT_DIR:-".claude-hooks-reports"}

# 是否在控制台显示详细报告
export SHOW_DETAILED_REPORT=${SHOW_DETAILED_REPORT:-true}

# 是否保存报告到文件
export SAVE_REPORT_TO_FILE=${SAVE_REPORT_TO_FILE:-false}

# =============================================================================
# 通知配置
# =============================================================================

# 检查失败时是否发送桌面通知
export NOTIFY_ON_FAILURE=${NOTIFY_ON_FAILURE:-false}

# 检查通过时是否发送桌面通知
export NOTIFY_ON_SUCCESS=${NOTIFY_ON_SUCCESS:-false}

# 通知命令（需要系统支持）
export NOTIFY_COMMAND=${NOTIFY_COMMAND:-"notify-send"}

# =============================================================================
# Git 集成配置
# =============================================================================

# 是否检查提交消息格式
export ENFORCE_COMMIT_MESSAGE_FORMAT=${ENFORCE_COMMIT_MESSAGE_FORMAT:-true}

# 提交消息格式正则表达式
# 默认：支持 Conventional Commits 格式
export COMMIT_MESSAGE_FORMAT_REGEX=${COMMIT_MESSAGE_FORMAT_REGEX:-"^(feat|fix|docs|style|refactor|test|chore|perf|build|ci|revert|wip)(\(.+\))?!?: .+"}

# 提交消息最大长度
export COMMIT_MESSAGE_MAX_LENGTH=${COMMIT_MESSAGE_MAX_LENGTH:-72}

# 提交消息描述最小长度
export COMMIT_MESSAGE_MIN_LENGTH=${COMMIT_MESSAGE_MIN_LENGTH:-10}

# =============================================================================
# 网络配置
# =============================================================================

# 是否启用离线模式
# true：跳过需要网络的检查
# false：正常进行所有检查
export OFFLINE_MODE=${OFFLINE_MODE:-false}

# HTTP 代理设置
export HTTP_PROXY=${HTTP_PROXY:-""}
export HTTPS_PROXY=${HTTPS_PROXY:-""}

# =============================================================================
# 开发者配置（通常不需要修改）
# =============================================================================

# 开发模式
# true：启用开发模式功能
# false：正常模式
export DEVELOPER_MODE=${DEVELOPER_MODE:-false}

# 测试模式
# true：使用模拟 API 调用
# false：真实 API 调用
export TEST_MODE=${TEST_MODE:-false}

# 是否显示统计信息
export SHOW_STATISTICS=${SHOW_STATISTICS:-false}

# 统计信息文件路径
export STATISTICS_FILE=${STATISTICS_FILE:-".claude-hooks-stats.json"}

# =============================================================================
# 使用说明
# =============================================================================

# 1. 复制此文件为 config.sh：
#    cp config.example.sh config.sh
#
# 2. 根据需要修改配置值：
#    nano config.sh
#
# 3. 重启 Git 会话以使配置生效
#
# 4. 或者设置环境变量临时覆盖配置：
#    export CLAUDE_TIMEOUT=60000
#    export ANALYSIS_LEVEL="thorough"

echo "Claude Code Git Hooks 配置文件已加载"
echo "配置文件路径: $0"
echo "项目名称: $PROJECT_NAME"
echo "分析级别: $ANALYSIS_LEVEL"
echo "调试模式: $CLAUDE_HOOKS_DEBUG"