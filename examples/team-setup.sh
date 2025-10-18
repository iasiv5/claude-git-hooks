#!/bin/bash

# Claude Code Git Hooks - 团队协作设置脚本
# 为团队协作环境配置 Claude Code Git Hooks

set -e

# 颜色输出定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
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
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║            Claude Code Git Hooks 团队设置                       ║
╠══════════════════════════════════════════════════════════════╣
║  👥 为团队协作环境配置 Claude Code                        ║
║  🛡️  统一的代码审查和质量标准                              ║
║  📋 项目特定的审查规则和策略                               ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 创建团队配置文件
create_team_config() {
    log_step "创建团队配置文件..."

    local config_file=".claude-hooks-team.yml"

    if [[ -f "$config_file" ]]; then
        log_warning "团队配置文件已存在: $config_file"
        read -p "是否覆盖现有配置？(y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "保持现有配置文件"
            return 0
        fi
    fi

    # 获取项目信息
    local project_name
    project_name=$(basename "$(pwd)")

    # 获取主要编程语言
    local primary_language="unknown"
    if [[ -f "package.json" ]]; then
        primary_language="javascript"
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        primary_language="python"
    elif [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]]; then
        primary_language="java"
    elif [[ -f "go.mod" ]]; then
        primary_language="go"
    elif [[ -f "Cargo.toml" ]]; then
        primary_language="rust"
    fi

    # 确定项目类型
    local project_type="web"
    if [[ "$project_name" =~ ^api|server|backend ]]; then
        project_type="backend"
    elif [[ "$project_name" =~ ^app|mobile|client ]]; then
        project_type="mobile"
    elif [[ "$project_name" =~ lib|sdk|package ]]; then
        project_type="library"
    fi

    # 创建配置文件
    cat > "$config_file" << EOF
# Claude Code Git Hooks 团队配置
# 版本: 1.0
# 项目: $project_name
# 生成时间: $(date)

# =============================================================================
# 项目配置
# =============================================================================
project:
  name: "$project_name"
  type: "$project_type"
  primary_language: "$primary_language"
  created_at: "$(date -Iseconds)"
  version: "1.0"

# =============================================================================
# Hook 启用配置
# =============================================================================
hooks:
  pre-commit:
    enabled: true
    description: "提交前代码审查"
    severity: "high"

  commit-msg:
    enabled: true
    description: "提交消息质量检查"
    severity: "medium"

  pre-push:
    enabled: true
    description: "推送前最终检查"
    severity: "critical"

# =============================================================================
# 文件类型过滤
# =============================================================================
file_filters:
  # 包含的文件扩展名
  include_extensions:
    - "js"
    - "ts"
    - "jsx"
    - "tsx"
    - "py"
    - "java"
    - "go"
    - "rs"
    - "php"
    - "rb"
    - "swift"
    - "kt"
    - "cs"
    - "cpp"
    - "c"
    - "h"

  # 排除的文件模式
  exclude_patterns:
    - "test"
    - "spec"
    - ".min."
    - "node_modules"
    - "dist"
    - "build"
    - ".git"
    - "vendor"
    - "target"
    - "__pycache__"

  # 文件大小限制（字节）
  max_file_size: 100000  # 100KB

  # 单次提交最大文件数
  max_files_per_commit: 20

# =============================================================================
# 分析级别配置
# =============================================================================
analysis:
  # 默认分析级别
  default_level: "moderate"

  # 按文件类型设置不同级别
  level_by_file_type:
    "js|ts": "moderate"
    "py": "thorough"
    "java": "thorough"
    "go": "thorough"
    "rs": "thorough"
    "cpp|h": "thorough"
    "php|rb": "moderate"

  # 按代码路径设置不同级别
  level_by_path:
    "src/.*": "moderate"
    "tests/.*": "quick"
    "docs/.*": "quick"
    "scripts/.*": "moderate"

# =============================================================================
# 审查规则配置
# =============================================================================
review_rules:
  # 安全检查级别
  security:
    level: "moderate"
    rules:
      - "sql_injection"
      - "xss_vulnerability"
      - "csrf_protection"
      - "input_validation"
      - "output_encoding"
      - "authentication"
      - "authorization"

  # 性能检查级别
  performance:
    level: "moderate"
    rules:
      - "algorithm_complexity"
      - "memory_usage"
      - "database_optimization"
      - "caching_strategy"
      - "concurrency_handling"

  # 代码质量检查
  quality:
    level: "strict"
    rules:
      - "code_duplication"
      - "function_length"
      - "naming_conventions"
      - "code_structure"
      - "error_handling"
      - "documentation"

  # 测试检查
  testing:
    level: "moderate"
    rules:
      - "test_coverage"
      - "test_quality"
      - "integration_tests"
      - "unit_tests"

  # 自定义检查规则
  custom_rules:
    - name: "todo_comments"
      level: "warning"
      pattern: "TODO|FIXME|HACK"
      message: "发现 TODO/FIXME 注释"

    - name: "debug_code"
      level: "error"
      pattern: "console\\.log|debugger|alert\\("
      message: "发现调试代码"

    - name: "long_functions"
      level: "warning"
      max_lines: 50
      message: "函数过长，建议拆分"

    - name: "deep_nesting"
      level: "warning"
      max_depth: 4
      message: "嵌套层级过深"

# =============================================================================
# 提交消息规则
# =============================================================================
commit_message:
  # 是否强制使用 Conventional Commits
  enforce_conventional: true

  # 允许的提交类型
  allowed_types:
    - "feat"      # 新功能
    - "fix"       # 修复
    - "docs"      # 文档
    - "style"     # 代码格式
    - "refactor"  # 重构
    - "test"      # 测试
    - "chore"     # 构建工具或依赖管理
    - "perf"      # 性能优化
    - "build"     # 构建系统或依赖变更
    - "ci"        # CI 配置变更
    - "revert"    # 回滚
    - "wip"       # 进行中的工作

  # 提交消息长度限制
  max_title_length: 72
  min_description_length: 10

  # 是否允许空的描述
  allow_empty_description: false

  # 是否要求范围 (scope)
  require_scope: false

  # 是否要求 breaking change 标识
  require_breaking_change: false

# =============================================================================
# 推送检查配置
# =============================================================================
push_checks:
  # 是否检查受保护分支
  protected_branches:
    - "main"
    - "master"
    - "develop"
    - "production"
    - "staging"

  # 是否检查提交数量
  max_commits_per_push: 50

  # 是否检查大的二进制文件
  check_large_binaries: true

  # 是否检查合并提交
  check_merge_commits: true

  # 是否检查空提交
  check_empty_commits: true

  # 是否要求 CI 状态
  require_ci_status: false

# =============================================================================
# API 配置
# =============================================================================
api:
  # 默认 Claude 模型
  default_model: "sonnet"

  # API 超时设置（毫秒）
  timeout:
    pre_commit: 30000
    commit_msg: 15000
    pre_push: 60000

  # 重试配置
  retries:
    max_retries: 3
    retry_delay: 1000

  # 缓存配置
  cache:
    enabled: true
    ttl: 3600  # 1小时
    max_size: 100  # MB

# =============================================================================
# 通知配置
# =============================================================================
notifications:
  # 是否启用通知
  enabled: false

  # 通知类型
  types:
    - "desktop"
    - "email"
    - "slack"

  # 通知级别
  levels:
    - "error"
    - "warning"

  # 通知命令
  desktop_command: "notify-send"
  email_recipients: []
  slack_webhook: ""

# =============================================================================
# 报告配置
# =============================================================================
reports:
  # 是否生成报告
  enabled: true

  # 报告格式
  formats:
    - "text"
    - "json"
    - "html"

  # 报告输出目录
  output_dir: ".claude-hooks-reports"

  # 是否在控制台显示报告
  show_in_console: true

  # 是否保存到文件
  save_to_file: true

# =============================================================================
# 集成配置
# =============================================================================
integrations:
  # CI/CD 集成
  cicd:
    github_actions: false
    jenkins: false
    gitlab_ci: false
    azure_devops: false

  # 项目管理工具集成
  project_management:
    jira: false
    trello: false
    asana: false

  # 通信工具集成
  communication:
    slack: false
    teams: false
    discord: false

# =============================================================================
# 团队成员配置
# =============================================================================
team_members:
  # 团队成员权限
  permissions:
    # 谁可以跳过 hooks
    skip_hooks:
      users: []
      groups: ["admins", "leads"]

    # 谁可以修改配置
    modify_config:
      users: []
      groups: ["admins"]

    # 谁可以查看报告
    view_reports:
      users: []
      groups: ["all"]

# =============================================================================
# 自定义脚本
# =============================================================================
custom_scripts:
  # 提交前的自定义检查
  pre_commit:
    - "scripts/lint.sh"
    - "scripts/test.sh"
    - "scripts/security-scan.sh"

  # 提交后的自定义操作
  post_commit:
    - "scripts/notify.sh"

  # 推送前的自定义检查
  pre_push:
    - "scripts/integration-test.sh"
    - "scripts/deployment-check.sh"

# =============================================================================
# 高级配置
# =============================================================================
advanced:
  # 并行处理
  parallel_processing:
    enabled: false
    max_workers: 4

  # 性能优化
  performance:
    batch_size: 10
    chunk_timeout: 5000

  # 调试模式
  debug:
    enabled: false
    log_level: "INFO"
    detailed_logging: false

  # 备份配置
  backup:
    enabled: true
    max_backups: 5
    backup_interval: 86400  # 24小时

# =============================================================================
# 注释和说明
# =============================================================================
# 此配置文件用于团队协作环境下的 Claude Code Git Hooks 设置
#
# 主要功能：
# 1. 统一代码审查标准
# 2. 项目特定的检查规则
# 3. 团队成员权限管理
# 4. CI/CD 集成配置
# 5. 通知和报告设置
#
# 使用说明：
# 1. 复制此文件到项目根目录
# 2. 根据团队需求调整配置
# 3. 运行安装脚本应用配置
# 4. 提交到版本控制系统
#
# 配置优先级：
# 1. 环境变量（最高）
# 2. 团队配置文件
# 3. 个人配置文件
# 4. 默认配置（最低）
EOF

    log_success "✅ 团队配置文件已创建: $config_file"
}

# 创建示例脚本目录
create_example_scripts() {
    log_step "创建示例脚本目录..."

    local scripts_dir="scripts"
    mkdir -p "$scripts_dir"

    # 创建 lint 脚本示例
    cat > "$scripts_dir/lint.sh" << 'EOF'
#!/bin/bash
# 示例 Lint 脚本
echo "🔍 Running lint checks..."
# 在此添加你的 lint 命令
# npm run lint
# flake8 .
# java -jar checkstyle.jar ...
echo "✅ Lint checks completed"
EOF

    # 创建测试脚本示例
    cat > "$scripts_dir/test.sh" << 'EOF'
#!/bin/bash
# 示例测试脚本
echo "🧪 Running tests..."
# 在此添加你的测试命令
# npm test
# python -m pytest
# mvn test
echo "✅ Tests completed"
EOF

    # 创建安全扫描脚本示例
    cat > "$scripts_dir/security-scan.sh" << 'EOF'
#!/bin/bash
# 示例安全扫描脚本
echo "🔒 Running security scan..."
# 在此添加你的安全扫描命令
# npm audit
# bandit -r .
# sonar-scanner
echo "✅ Security scan completed"
EOF

    # 设置执行权限
    chmod +x "$scripts_dir"/*.sh

    log_success "✅ 示例脚本已创建: $scripts_dir/"
}

# 创建 Git 忽略文件
update_gitignore() {
    log_step "更新 .gitignore 文件..."

    local gitignore_file=".gitignore"
    local patterns_to_add=(
        "# Claude Code Git Hooks"
        ".claude-hooks-team.yml"
        ".claude-hooks-personal.yml"
        ".claude-hooks.log"
        ".claude-hooks-cache/"
        ".claude-hooks-reports/"
        ".claude-hooks-temp/"
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
        log_success "✅ 已添加 $added_count 个条目到 .gitignore"
    else
        log_info "  .gitignore 已包含相关条目"
    fi
}

# 创建 README 文件
create_team_readme() {
    log_step "创建团队使用说明..."

    local readme_file="CLAude-HOOKS-TEAM.md"

    cat > "$readme_file" << EOF
# Claude Code Git Hooks 团队使用指南

## 简介

本项目配置了 Claude Code Git Hooks，用于自动化代码审查和质量检查。

## 快速开始

### 1. 安装 Claude Code

\`\`\`bash
npm install -g @anthropic-ai/claude-code
\`\`\`

### 2. 设置 API Key

\`\`\`bash
export ANTHROPIC_API_KEY=your_api_key_here
\`\`\`

### 3. 安装 Hooks

\`\`\`bash
./claude-git-hooks/install.sh
\`\`\`

## 配置说明

### 团队配置文件

项目使用 \`.claude-hooks-team.yml\` 进行团队级别的配置。

主要配置项：
- **项目信息**: 项目名称、类型、主要语言
- **Hook 启用**: 控制哪些 hook 生效
- **文件过滤**: 指定要检查的文件类型
- **分析级别**: 不同文件类型的分析深度
- **审查规则**: 安全、性能、质量等检查规则

### 个人配置

可以在项目根目录创建 \`.claude-hooks-personal.yml\` 进行个人配置覆盖。

## 使用方法

### 日常使用

\`\`\`bash
git add .
git commit -m "feat: add new feature"  # 自动触发 pre-commit 和 commit-msg 检查
git push origin main                    # 自动触发 pre-push 检查
\`\`\`

### 跳过检查

\`\`\`bash
git commit --no-verify -m "message"     # 跳过 pre-commit 检查
git push --no-verify origin main         # 跳过 pre-push 检查
\`\`\`

### 调试模式

\`\`\`bash
export CLAUDE_HOOKS_DEBUG=true          # 启用详细日志
tail -f .claude-hooks.log               # 查看日志
\`\`\`

## 审查标准

### 代码质量

- **安全**: SQL 注入、XSS、输入验证等
- **性能**: 算法效率、资源使用、并发处理
- **质量**: 代码结构、命名规范、错误处理
- **测试**: 测试覆盖度、测试质量

### 提交消息

- 使用 Conventional Commits 格式
- 标题行不超过 72 字符
- 清晰描述变更内容

### 推送检查

- 受保护分支需要特殊权限
- 单次推送不超过 50 个提交
- 检查大文件和二进制文件

## 故障排除

### 常见问题

1. **Hook 不执行**
   - 检查文件权限: \`chmod +x .git/hooks/pre-commit\`
   - 检查 Claude Code 安装: \`claude --version\`

2. **API 错误**
   - 检查 API Key: \`echo \$ANTHROPIC_API_KEY\`
   - 检查网络连接

3. **性能问题**
   - 减少检查文件数: \`MAX_FILES_PER_COMMIT=10\`
   - 缩短超时时间: \`CLAUDE_TIMEOUT=15000\`

### 查看日志

\`\`\`bash
# 查看实时日志
tail -f .claude-hooks.log

# 搜索特定错误
grep -i "error" .claude-hooks.log
\`\`\`

## 自定义脚本

可以在 \`scripts/\` 目录下添加自定义检查脚本：

- \`lint.sh\`: 代码风格检查
- \`test.sh\`: 运行测试
- \`security-scan.sh\`: 安全扫描

## 集成 CI/CD

### GitHub Actions 示例

\`\`\`yaml
# .github/workflows/claude-review.yml
name: Claude Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  claude-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Claude Code
        run: |
          npm install -g @anthropic-ai/claude-code
          echo "\${{ secrets.ANTHROPIC_API_KEY }}" > .claude-api-key
      - name: Run Claude Review
        run: |
          claude --print --system-prompt="You are a code reviewer" "Please review the changes"
\`\`\`

## 联系支持

- 遇到问题请检查故障排除部分
- 查看 Claude Code 官方文档
- 联系团队管理员

---

*文档最后更新: $(date)*
EOF

    log_success "✅ 团队使用说明已创建: $readme_file"
}

# 创建个人配置模板
create_personal_config_template() {
    log_step "创建个人配置模板..."

    local personal_config=".claude-hooks-personal.yml.example"

    cat > "$personal_config" << EOF
# Claude Code Git Hooks 个人配置
# 复制此文件为 .claude-hooks-personal.yml 并根据需要修改

# =============================================================================
# 个人设置
# =============================================================================
personal:
  name: "Your Name"
  email: "your.email@example.com"

  # 是否启用桌面通知
  notifications:
    enabled: true
    sound: true

# =============================================================================
# Hook 覆盖配置
# =============================================================================
hooks:
  # 覆盖团队配置的 hook 启用状态
  pre-commit:
    enabled: true
    skip_patterns: ["*.test.js", "tests/"]

  commit_msg:
    enabled: true
    skip_for_wip: true

  pre-push:
    enabled: true
    skip_for_feature_branches: true

# =============================================================================
# 分析级别覆盖
# =============================================================================
analysis:
  # 个人偏好的分析级别
  personal_level: "moderate"

  # 特定项目或路径的覆盖
  overrides:
    "experimental/": "thorough"
    "legacy/": "quick"

# =============================================================================
# API 配置覆盖
# =============================================================================
api:
  # 个人 API 设置
  timeout:
    pre_commit: 45000    # 比团队配置更长
    commit_msg: 20000
    pre_push: 90000

  # 模型选择
  model: "sonnet"  # 可以选择 "opus" 或 "haiku"

  # 缓存设置
  cache:
    enabled: true
    ttl: 7200  # 2小时

# =============================================================================
# 调试和开发
# =============================================================================
debug:
  # 开发模式
  enabled: false
  log_level: "DEBUG"
  show_timing: true

  # 性能监控
  profile:
    enabled: false
    save_stats: true

# =============================================================================
# 集成设置
# =============================================================================
integrations:
  # IDE 集成
  ide:
    vscode:
      enabled: true
      show_problems: true

    # 编辑器配置
    editor:
      format_on_save: false
      lint_on_save: true

# =============================================================================
# 自定义脚本和命令
# =============================================================================
custom:
  # 提交前的个人脚本
  pre_commit:
    - "scripts/personal-check.sh"

  # 自定义命令
  aliases:
    review: "claude --print --system-prompt='You are a code reviewer'"
    test: "npm run test && npm run lint"
EOF

    log_success "✅ 个人配置模板已创建: $personal_config"
    log_info "  复制为 .claude-hooks-personal.yml 并修改以使用"
}

# 显示使用说明
show_usage_instructions() {
    echo
    echo -e "${CYAN}📋 团队设置完成！${NC}"
    echo
    echo -e "${BLUE}下一步操作:${NC}"
    echo "1. ${GREEN}安装 Claude Code${NC}"
    echo "   npm install -g @anthropic-ai/claude-code"
    echo
    echo "2. ${GREEN}设置 API Key${NC}"
    echo "   export ANTHROPIC_API_KEY=your_api_key_here"
    echo
    echo "3. ${GREEN}安装 Hooks${NC}"
    echo "   ./claude-git-hooks/install.sh"
    echo
    echo "4. ${GREEN}提交配置文件${NC}"
    echo "   git add .claude-hooks-team.yml"
    echo "   git commit -m \"feat: add Claude Code Git Hooks team config\""
    echo
    echo "5. ${GREEN}团队其他成员设置${NC}"
    echo "   分享此仓库，其他成员运行安装脚本即可"
    echo
    echo -e "${YELLOW}💡 提示:${NC}"
    echo "- 查看文档: CLAUDE-HOOKS-TEAM.md"
    echo "- 个人配置: 复制 .claude-hooks-personal.yml.example"
    echo "- 故障排除: 检查 .claude-hooks.log"
    echo
    echo -e "${GREEN}🎉 团队协作设置完成！${NC}"
}

# 主函数
main() {
    show_welcome

    log_step "开始 Claude Code Git Hooks 团队设置..."

    # 确保在 Git 仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "当前目录不是 Git 仓库"
        echo "请先运行: git init"
        exit 1
    fi

    # 确保在项目根目录
    cd "$(git rev-parse --show-toplevel)"
    log_info "项目根目录: $(pwd)"

    create_team_config
    create_example_scripts
    update_gitignore
    create_team_readme
    create_personal_config_template
    show_usage_instructions
}

# 运行主函数
main "$@"