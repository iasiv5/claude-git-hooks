# Claude Code Git Hooks 故障排除指南

## 常见问题解决方案

### 1. Hook 不执行

#### 问题症状
- 提交代码时没有看到 Claude Code 的输出
- Hook 似乎被完全忽略

#### 可能原因
1. Hook 文件没有执行权限
2. Git 配置问题
3. Hook 安装不正确

#### 解决方案

**1. 检查 Hook 权限**

```bash
# 检查 Hook 文件权限
ls -la .git/hooks/

# 设置执行权限
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/commit-msg
chmod +x .git/hooks/pre-push
```

**2. 检查 Git 配置**

```bash
# 检查是否启用了 hooks
git config --get core.hooksPath

# 如果设置了错误的路径，重置
git config --unset core.hooksPath
```

**3. 重新安装 Hooks**

```bash
# 运行安装脚本
./claude-git-hooks/install.sh

# 或者手动复制
cp claude-git-hooks/hooks/pre-commit.sh .git/hooks/pre-commit
cp claude-git-hooks/hooks/commit-msg.sh .git/hooks/commit-msg
cp claude-git-hooks/hooks/pre-push.sh .git/hooks/pre-push
chmod +x .git/hooks/*
```

### 2. Claude Code API 错误

#### 问题症状
- 看到 "Claude Code 未安装" 或 "API Key 未设置" 错误
- API 调用失败，超时或认证错误

#### 可能原因
1. Claude Code 未正确安装
2. API Key 配置错误
3. 网络连接问题
4. API 限制或配额用尽

#### 解决方案

**1. 检查 Claude Code 安装**

```bash
# 检查 Claude Code 是否安装
claude --version

# 如果未安装，安装它
npm install -g @anthropic-ai/claude-code
```

**2. 检查 API Key 配置**

```bash
# 检查环境变量
echo $ANTHROPIC_API_KEY

# 设置 API Key
export ANTHROPIC_API_KEY="your_api_key_here"

# 或者添加到 shell 配置文件
echo 'export ANTHROPIC_API_KEY="your_api_key_here"' >> ~/.bashrc
source ~/.bashrc
```

**3. 测试 API 连接**

```bash
# 测试 Claude Code 连接
claude --print --system-prompt="test" "Hello, please respond with 'API test successful'"
```

**4. 检查网络连接**

```bash
# 测试网络连接
curl -I https://api.anthropic.com

# 如果使用代理，设置代理
export HTTP_PROXY="http://proxy.example.com:8080"
export HTTPS_PROXY="http://proxy.example.com:8080"
```

### 3. 权限错误

#### 问题症状
- 看到 "权限拒绝" 错误
- 无法访问 Git hooks 目录或文件

#### 可能原因
1. 文件系统权限问题
2. Git 仓库权限问题
3. 系统安全策略限制

#### 解决方案

**1. 检查文件权限**

```bash
# 检查 Git hooks 目录权限
ls -la .git/

# 修复权限
chmod 755 .git
chmod 755 .git/hooks
chmod 644 .git/hooks/*
```

**2. 检查 Git 仓库权限**

```bash
# 检查仓库权限
git status

# 修复仓库权限
chmod -R 755 .git
```

**3. 检查系统权限（Windows）**

```bash
# 在 Windows 上，可能需要管理员权限
# 尝试以管理员身份运行终端或 Git Bash
```

### 4. 配置问题

#### 问题症状
- Hook 执行但配置未生效
- 看到配置相关的错误信息

#### 可能原因
1. 配置文件格式错误
2. 配置文件权限问题
3. 环境变量配置错误

#### 解决方案

**1. 检查配置文件**

```bash
# 检查配置文件是否存在
ls -la .claude-hooks-config.sh

# 验证配置文件语法
bash -n .claude-hooks-config.sh
```

**2. 重新创建配置文件**

```bash
# 备份旧配置
cp .claude-hooks-config.sh .claude-hooks-config.sh.backup

# 重新创建配置文件
cp claude-git-hooks/config.example.sh .claude-hooks-config.sh

# 编辑新配置
nano .claude-hooks-config.sh
```

**3. 检查环境变量**

```bash
# 检查相关环境变量
env | grep -E "(CLAUDE|ANTHROPIC|HOOKS)"

# 设置正确的环境变量
export CLAUDE_HOOKS_DEBUG=true
export CLAUDE_TIMEOUT=60000
export PRE_COMMIT_ENABLED=true
```

### 5. 性能问题

#### 问题症状
- Hook 执行缓慢
- 提交操作卡住
- 超时错误

#### 可能原因
1. 文件分析过多
2. API 响应慢
3. 网络延迟
4. 系统资源不足

#### 解决方案

**1. 优化文件过滤**

```bash
# 编辑配置文件
nano .claude-hooks-config.sh

# 减少检查的文件数量
export MAX_FILES_PER_COMMIT=10

# 限制文件大小
export MAX_FILE_SIZE=50000

# 设置更严格的分析级别
export ANALYSIS_LEVEL="quick"
```

**2. 调整超时设置**

```bash
# 设置更长的超时时间
export CLAUDE_TIMEOUT=60000  # 60秒

# 或者在配置文件中设置
echo 'export CLAUDE_TIMEOUT=60000' >> .claude-hooks-config.sh
```

**3. 启用缓存**

```bash
# 在配置文件中启用缓存
echo 'export ENABLE_CACHE=true' >> .claude-hooks-config.sh
echo 'export CACHE_TTL=7200' >> .claude-hooks-config.sh  # 2小时
```

**4. 跳过大型文件**

```bash
# 在配置文件中添加排除模式
export EXCLUDE_PATTERNS="test|spec|\.min\.|node_modules|dist|build|\.git|vendor|target|__pycache__|*.log|*.tmp|*.bin"
```

### 6. 兼容性问题

#### 问题症状
- Hook 在不同操作系统上表现不同
- 特定编辑器或工具集成问题

#### 可能原因
1. Shell 兼容性问题
2. 路径格式问题
3. 工具链兼容性

#### 解决方案

**1. 检查 Shell 版本**

```bash
# 检查 Bash 版本
bash --version

# 如果版本过低，考虑升级
# macOS: brew install bash
# Ubuntu: sudo apt-get install bash
```

**2. 处理路径问题**

```bash
# 在 Windows 上处理路径
export MSYS2_PATH_TYPE=inherit
export MSYS=winsymlinks

# 或者在 Git Bash 中使用 POSIX 路径
```

**3. 编辑器集成**

```bash
# VS Code 集成
# 确保使用 Git Bash 作为终端
# 在 VS Code 设置中配置：
# "terminal.integrated.shell.windows": "C:\\Program Files\\Git\\bin\\bash.exe"

# 其他编辑器类似配置
```

### 7. 调试模式

#### 启用详细日志

```bash
# 启用调试模式
export CLAUDE_HOOKS_DEBUG=true

# 提交代码查看详细日志
git commit -m "test commit"

# 查看日志文件
tail -f .claude-hooks.log

# 搜索特定错误
grep -i "error" .claude-hooks.log
```

#### 测试单个 Hook

```bash
# 测试 pre-commit hook
.git/hooks/pre-commit

# 测试 commit-msg hook
echo "test message" | .git/hooks/commit-msg .git/COMMIT_EDITMSG

# 测试 pre-push hook
.git/hooks/pre-push origin main
```

#### 手动运行 Claude

```bash
# 测试 Claude Code 是否正常工作
claude --print --system-prompt="test" "Hello, please respond with 'test successful'"

# 测试特定的审查提示
claude --print --system-prompt="You are a code reviewer" "Please review this simple function: function test() { return 1; }"
```

### 8. 高级故障排除

#### 使用系统调用跟踪

```bash
# 在 Linux/macOS 上使用 strace/dtruss
strace -f -e trace=file,process -o strace.log git commit -m "test"

# 在 Windows 上使用 ProcMon 或类似工具
```

#### 检查 Git 内部状态

```bash
# 检查 Git 配置
git config --list

# 检查 Git 状态
git status --porcelain

# 检查暂存的文件
git diff --cached --name-status

# 检查 Hook 配置
git config --get core.hooksPath
```

#### 网络诊断

```bash
# 测试 API 端点连接
curl -v https://api.anthropic.com/v1/messages

# 测试 DNS 解析
nslookup api.anthropic.com

# 测试网络延迟
ping api.anthropic.com
```

### 9. 恢复和重置

#### 备份当前配置

```bash
# 备份当前 hooks
cp -r .git/hooks .git/hooks.backup.$(date +%Y%m%d_%H%M%S)

# 备份配置文件
cp .claude-hooks-config.sh .claude-hooks-config.sh.backup

# 备份日志
cp .claude-hooks.log .claude-hooks.log.backup
```

#### 完全重置

```bash
# 删除现有 hooks
rm -f .git/hooks/pre-commit
rm -f .git/hooks/commit-msg
rm -f .git/hooks/pre-push

# 删除配置文件
rm -f .claude-hooks-config.sh
rm -f .claude-hooks.log

# 重新安装
./claude-git-hooks/install.sh
```

#### 手动安装

```bash
# 手动创建最简单的 pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "Pre-commit hook running..."
# 在这里添加你的检查逻辑
exit 0
EOF

chmod +x .git/hooks/pre-commit
```

### 10. 获取帮助

#### 查看文档

```bash
# 查看 Hook 文档
cat claude-git-hooks/README.md

# 查看 Hook 文件注释
less claude-git-hooks/hooks/pre-commit.sh
```

#### 社区支持

- GitHub Issues: [项目问题跟踪]
- Stack Overflow: [搜索相关问题]
- Claude Code 官方文档: [API 文档]

#### 联系团队

如果问题仍然无法解决：

1. 收集错误信息和日志
2. 描述复现步骤
3. 提供系统环境信息
4. 联系团队管理员或技术支持

---

**提示**: 始终在测试环境中先尝试解决方案，然后再应用到生产环境。