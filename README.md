# Claude Code Git Hooks 集成方案

将 Claude Code 与 Git Hooks 集成，在本地开发过程中实时进行代码审查和质量检查。

## 功能特性

- 🤖 **Pre-commit 检查**：提交前自动进行代码审查
- 📝 **Commit Message 检查**：评估提交消息质量
- 🚀 **Pre-push 检查**：推送前进行最终质量验证
- ⚡ **智能过滤**：只检查相关文件类型
- 🎯 **分级检查**：支持不同级别的分析深度
- 🛡️ **安全控制**：可配置权限和跳过机制

## 快速开始

### 1. 安装 Hooks

```bash
# 进入你的 Git 项目目录
cd /path/to/your/project

# 克隆或下载本仓库
git clone <repository-url> claude-git-hooks
cd claude-git-hooks

# 运行安装脚本
chmod +x install.sh
./install.sh
```

### 2. 配置环境（可选）

```bash
# 复制配置文件到项目根目录（首次安装时 install.sh 也会自动生成）
cp config.example.sh .claude-hooks-config.sh

# 编辑配置文件
nano .claude-hooks-config.sh
```

### 3. 正常使用 Git

```bash
# 添加文件
git add .

# 提交代码（自动触发 pre-commit 检查）
git commit -m "feat: add new feature"

# 推送代码（自动触发 pre-push 检查）
git push origin main
```

## 项目结构

```
claude-git-hooks/
├── README.md                    # 本文件
├── install.sh                   # 安装脚本
├── uninstall.sh                 # 卸载脚本
├── config.example.sh            # 配置文件模板
├── hooks/
│   ├── pre-commit.sh            # Pre-commit hook
│   ├── commit-msg.sh            # Commit message hook
│   └── pre-push.sh              # Pre-push hook
├── templates/
│   ├── review-prompt.txt        # 代码审查提示模板
│   ├── commit-prompt.txt        # 提交消息检查模板
│   └── push-prompt.txt          # 推送检查模板
├── utils/
│   ├── logger.sh                # 日志工具
│   ├── file-utils.sh           # 文件处理工具
│   └── claude-client.sh        # Claude 客户端封装
└── examples/
    ├── team-setup.sh           # 团队配置示例
    └── troubleshooting.md       # 故障排除指南
```

## 配置选项

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `CLAUDE_TIMEOUT` | 30000 | Claude API 超时时间（毫秒） |
| `CLAUDE_MODEL` | sonnet | 使用的 Claude 模型 |
| `PRE_COMMIT_ENABLED` | true | 是否启用 pre-commit 检查 |
| `ANALYSIS_LEVEL` | moderate | 分析级别：quick/moderate/thorough |
| `MAX_FILES_PER_COMMIT` | 20 | 单次提交最大检查文件数 |
| `CLAUDE_HOOKS_DEBUG` | false | 是否启用调试模式 |

### 文件类型过滤

默认支持的文件类型：
- JavaScript/TypeScript: `.js`, `.ts`, `.jsx`, `.tsx`
- Python: `.py`
- Java: `.java`
- Go: `.go`
- Rust: `.rs`
- PHP: `.php`
- Ruby: `.rb`
- Swift: `.swift`
- Kotlin: `.kt`
- C#: `.cs`
- C/C++: `.c`, `.cpp`, `.h`

## 使用示例

### 跳过检查

```bash
# 跳过 pre-commit 检查
git commit --no-verify -m "message"

# 跳过 pre-push 检查
git push --no-verify origin main
```

### 调试模式

```bash
# 启用调试模式
export CLAUDE_HOOKS_DEBUG=true

# 查看详细日志
tail -f .claude-hooks.log
```

### 自定义分析级别

```bash
# 快速检查（适合大型项目）
export ANALYSIS_LEVEL=quick

# 深度分析（适合关键项目）
export ANALYSIS_LEVEL=thorough
```

## 故障排除

### 常见问题

1. **Hook 不执行**
   ```bash
   # 检查权限
   ls -la .git/hooks/pre-commit
   chmod +x .git/hooks/pre-commit
   ```

2. **Claude API 错误**
   ```bash
   # 检查 API Key
   echo $ANTHROPIC_API_KEY
   # 测试连接
   claude --print --system-prompt="test" "hello"
   ```

3. **Hook 执行缓慢**
   ```bash
   # 减少检查文件数
   export MAX_FILES_PER_COMMIT=10
   # 缩短超时时间
   export CLAUDE_TIMEOUT=15000
   ```

### 查看日志

```bash
# 查看 Hook 执行日志
cat .claude-hooks.log

# 实时查看日志
tail -f .claude-hooks.log
```

## 团队协作

### 共享配置

```bash
# 在项目根目录创建团队配置
cat > .claude-hooks-team.yml << EOF
version: 1
hooks:
  pre-commit:
    enabled: true
    file_types: [js, ts, py, java]
    rules:
      security: strict
      performance: moderate
  pre-push:
    enabled: true
    require_ci: true
EOF

# 添加到 .gitignore
echo ".claude-hooks-team.yml" >> .gitignore
```

### CI/CD 集成

```yaml
# .github/workflows/claude-check.yml
name: Claude Code Check

on: [push, pull_request]

jobs:
  claude-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Claude Code
        run: |
          npm install -g @anthropic-ai/claude-code
          echo "${{ secrets.ANTHROPIC_API_KEY }}" > .claude-api-key
      - name: Run Claude Review
        run: claude --print --system-prompt="You are a code reviewer" "Please review the code changes"
```

## 性能优化

- **增量检查**：只分析变更的文件
- **并行处理**：使用多进程分析不同类型文件
- **缓存机制**：缓存分析结果避免重复检查
- **智能过滤**：基于文件大小、类型和内容进行过滤

## 贡献指南

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/new-feature`
3. 提交更改：`git commit -am 'Add new feature'`
4. 推送分支：`git push origin feature/new-feature`
5. 提交 Pull Request

## 许可证

MIT License - 详见 LICENSE 文件

## 支持

- 📧 Email: support@example.com
- 💬 Issues: [GitHub Issues](https://github.com/your-repo/issues)
- 📖 Docs: [Documentation](https://docs.example.com)