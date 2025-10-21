# Claude Code Git Hooks Windows 安装脚本
# PowerShell版本，兼容Windows系统

# 颜色输出定义
$RED = [System.ConsoleColor]::Red
$GREEN = [System.ConsoleColor]::Green
$YELLOW = [System.ConsoleColor]::Yellow
$BLUE = [System.ConsoleColor]::Blue
$PURPLE = [System.ConsoleColor]::Magenta
$CYAN = [System.ConsoleColor]::Cyan
$NC = [System.ConsoleColor]::White

# 日志函数
function Write-Log {
    param([string]$Message, [string]$Type = "INFO")

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch($Type) {
        "INFO"    { "[$timestamp] [INFO] " }
        "SUCCESS" { "[$timestamp] [SUCCESS] " }
        "WARNING" { "[$timestamp] [WARNING] " }
        "ERROR"   { "[$timestamp] [ERROR] " }
        "STEP"    { "[$timestamp] [STEP] " }
    }

    switch($Type) {
        "INFO"    { Write-Host "$prefix$Message" -ForegroundColor $BLUE }
        "SUCCESS" { Write-Host "$prefix$Message" -ForegroundColor $GREEN }
        "WARNING" { Write-Host "$prefix$Message" -ForegroundColor $YELLOW }
        "ERROR"   { Write-Host "$prefix$Message" -ForegroundColor $RED }
        "STEP"    { Write-Host "$prefix$Message" -ForegroundColor $PURPLE }
        default   { Write-Host "$prefix$Message" }
    }
}

# 显示欢迎信息
function Show-Welcome {
    Write-Host $CYAN "`n"
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor $CYAN
    Write-Host "║            Claude Code Git Hooks 安装程序                      ║" -ForegroundColor $CYAN
    Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor $CYAN
    Write-Host "║  🤖 将 Claude Code 与 Git Hooks 集成                         ║" -ForegroundColor $CYAN
    Write-Host "║  🛡️  自动化代码审查和质量检查                                  ║" -ForegroundColor $CYAN
    Write-Host "║  🚀 提升开发效率和代码质量                                     ║" -ForegroundColor $CYAN
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor $CYAN
    Write-Host $NC "`n"
}

# 检查系统要求
function Check-Requirements {
    Write-Log "检查系统要求..." -Type "STEP"

    # 检查是否在 Git 仓库中
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log "Git 未安装" -Type "ERROR"
        exit 1
    }

    $gitStatus = git rev-parse --is-inside-work-tree 2>$null
    if ($gitStatus -ne "true") {
        Write-Log "当前目录不是 Git 仓库" -Type "ERROR"
        Write-Log "请先初始化 Git 仓库: git init" -Type "INFO"
        exit 1
    }
    Write-Log "✓ Git 仓库检查通过" -Type "SUCCESS"

    # 检查 Claude Code 是否安装
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Log "✓ Claude Code 已安装" -Type "SUCCESS"
        $claudeVersion = claude --version 2>$null || "未知版本"
        Write-Log "  Claude Code 版本: $claudeVersion" -Type "INFO"
    } else {
        Write-Log "⚠ Claude Code 未安装" -Type "WARNING"
        Write-Log "  请安装 Claude Code: npm install -g @anthropic-ai/claude-code" -Type "INFO"
        $continue = Read-Host "是否继续安装（Claude Code 功能将被跳过）? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            exit 1
        }
    }

    # 检查 API Key
    if ($env:ANTHROPIC_API_KEY) {
        Write-Log "✓ ANTHROPIC_API_KEY 已设置" -Type "SUCCESS"
    } else {
        Write-Log "⚠ ANTHROPIC_API_KEY 未设置" -Type "WARNING"
        Write-Log "  请设置环境变量: `$env:ANTHROPIC_API_KEY = 'your_api_key'" -Type "INFO"
    }
}

# 验证文件完整性
function Verify-Files {
    Write-Log "验证文件完整性..." -Type "STEP"

    $requiredFiles = @(
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

    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $PSScriptRoot $file
        if (Test-Path $filePath) {
            Write-Log "✓ $file" -Type "SUCCESS"
        } else {
            Write-Log "✗ 缺少文件: $file" -Type "ERROR"
            exit 1
        }
    }
}

# 备份现有 hooks
function Backup-ExistingHooks {
    Write-Log "备份现有 Git hooks..." -Type "STEP"

    $gitHooksDir = git rev-parse --git-dir | Join-Path -ChildPath "hooks"
    $hooksToBackup = @("pre-commit", "commit-msg", "pre-push")
    $backupDir = Join-Path $gitHooksDir "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

    foreach ($hook in $hooksToBackup) {
        $hookPath = Join-Path $gitHooksDir $hook
        if (Test-Path $hookPath) {
            Write-Log "  备份 hook: $hook" -Type "INFO"
            Copy-Item $hookPath $backupDir
        }
    }

    $backupItems = Get-ChildItem $backupDir -Name
    if ($backupItems.Count -gt 0) {
        Write-Log "✓ 现有 hooks 已备份到: $backupDir" -Type "SUCCESS"
    } else {
        Write-Log "  未发现需要备份的 hooks" -Type "INFO"
        Remove-Item $backupDir -Force -Recurse
    }
}

# 安装 Git hooks
function Install-Hooks {
    Write-Log "安装 Claude Code Git hooks..." -Type "STEP"

    $gitHooksDir = git rev-parse --git-dir | Join-Path -ChildPath "hooks"
    $hooksConfig = @{
        "pre-commit"    = "pre-commit.sh"
        "commit-msg"    = "commit-msg.sh"
        "pre-push"      = "pre-push.sh"
    }

    foreach ($hookName in $hooksConfig.Keys) {
        $scriptFile = $hooksConfig[$hookName]
        $sourceFile = Join-Path $PSScriptRoot "hooks" $scriptFile
        $targetFile = Join-Path $gitHooksDir $hookName

        if (Test-Path $sourceFile) {
            # 复制脚本文件
            Copy-Item $sourceFile $targetFile

            # 设置文件可执行权限（Windows下主要是去掉只读属性）
            $item = Get-Item $targetFile
            $item.IsReadOnly = $false

            Write-Log "✓ Installed $hookName hook" -Type "SUCCESS"
        } else {
            Write-Log "✗ Source file not found: $sourceFile" -Type "ERROR"
            exit 1
        }
    }
}

# 安装配置文件
function Install-Config {
    Write-Log "安装配置文件..." -Type "STEP"

    $configFile = ".claude-hooks-config.sh"

    if (-not (Test-Path $configFile)) {
        $templateFile = Join-Path $PSScriptRoot "config.example.sh"
        if (Test-Path $templateFile) {
            Copy-Item $templateFile $configFile
        } else {
            # 创建默认配置文件
            @"
#!/bin/bash
# Claude Code Git Hooks 配置文件
# 生成时间: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Claude Code 配置
export CLAUDE_TIMEOUT=${env:CLAUDE_TIMEOUT:-30000}  # 30秒超时
export CLAUDE_MODEL=${env:CLAUDE_MODEL:-"sonnet"}    # 默认模型

# Hook 启用控制
export PRE_COMMIT_ENABLED=${env:PRE_COMMIT_ENABLED:-true}
export COMMIT_MSG_ENABLED=${env:COMMIT_MSG_ENABLED:-true}
export PRE_PUSH_ENABLED=${env:PRE_PUSH_ENABLED:-true}

# 文件类型过滤
export CODE_EXTENSIONS="js|ts|jsx|tsx|py|java|go|rs|php|rb|swift|kt|cs|cpp|c|h"

# 分析级别 (quick, moderate, thorough)
export ANALYSIS_LEVEL=${env:ANALYSIS_LEVEL:-"moderate"}

# 日志控制
export CLAUDE_HOOKS_DEBUG=${env:CLAUDE_HOOKS_DEBUG:-false}
export LOG_FILE=${env:LOG_FILE:-".claude-hooks.log"}

# 性能控制
export MAX_FILE_SIZE=${env:MAX_FILE_SIZE:-100000}  # 100KB
export MAX_FILES_PER_COMMIT=${env:MAX_FILES_PER_COMMIT:-20}

# 审查规则级别 (strict, moderate, lax)
export SECURITY_CHECK_LEVEL=${env:SECURITY_CHECK_LEVEL:-"moderate"}
export PERFORMANCE_CHECK_LEVEL=${env:PERFORMANCE_CHECK_LEVEL:-"moderate"}
export STYLE_CHECK_LEVEL=${env:STYLE_CHECK_LEVEL:-"lax"}

# API 配置
export CLAUDE_API_RETRIES=${env:CLAUDE_API_RETRIES:-3}
export CLAUDE_API_RETRY_DELAY=${env:CLAUDE_API_RETRY_DELAY:-1000}
"@ | Out-File -FilePath $configFile -Encoding UTF8
        }
        Write-Log "✓ 配置文件已创建: $configFile" -Type "SUCCESS"
        Write-Log "  编辑此文件以自定义 hook 行为" -Type "INFO"
    } else {
        Write-Log "  配置文件已存在: $configFile (保持不变)" -Type "INFO"
    }
}

# 安装 .gitignore 条目
function Install-Gitignore {
    Write-Log "更新 .gitignore..." -Type "STEP"

    $gitignoreFile = ".gitignore"
    $patternsToAdd = @(
        ".claude-hooks.log"
        ".claude-hooks-cache/"
        ".claude-hooks-temp/"
        "claude-hooks-backup/"
        ".claude-hooks-team.yml"
    )

    # 创建 .gitignore 如果不存在
    if (-not (Test-Path $gitignoreFile)) {
        New-Item -ItemType File -Path $gitignoreFile | Out-Null
    }

    $addedCount = 0
    foreach ($pattern in $patternsToAdd) {
        if (-not (Select-String -Path $gitignoreFile -Pattern "^$pattern$" -Quiet)) {
            Add-Content $gitignoreFile ""
            Add-Content $gitignoreFile "# Claude Code Git Hooks"
            Add-Content $gitignoreFile $pattern
            $addedCount++
        }
    }

    if ($addedCount -gt 0) {
        Write-Log "✓ 已添加 $addedCount 个条目到 .gitignore" -Type "SUCCESS"
    } else {
        Write-Log "  .gitignore 已包含相关条目" -Type "INFO"
    }
}

# 验证安装
function Verify-Installation {
    Write-Log "验证安装..." -Type "STEP"

    $gitHooksDir = git rev-parse --git-dir | Join-Path -ChildPath "hooks"
    $requiredHooks = @("pre-commit", "commit-msg", "pre-push")
    $allInstalled = $true

    foreach ($hook in $requiredHooks) {
        $hookPath = Join-Path $gitHooksDir $hook
        if ((Test-Path $hookPath) -and (Select-String -Path $hookPath -Pattern "Claude Code" -Quiet)) {
            Write-Log "✓ $hook hook: 已安装并可用" -Type "SUCCESS"
        } else {
            Write-Log "✗ $hook hook: 安装失败" -Type "ERROR"
            $allInstalled = $false
        }
    }

    if ($allInstalled) {
        Write-Log "🎉 所有 hooks 安装成功！" -Type "SUCCESS"
    } else {
        Write-Log "❌ 部分 hooks 安装失败" -Type "ERROR"
        exit 1
    }

    # 测试配置加载
    if (Test-Path ".claude-hooks-config.sh") {
        Write-Log "✓ 配置文件存在" -Type "SUCCESS"
    } else {
        Write-Log "⚠ 配置文件不存在，将使用默认配置" -Type "WARNING"
    }
}

# 显示使用说明
function Show-UsageInstructions {
    Write-Host $CYAN "`n📖 使用说明" -ForegroundColor $CYAN
    Write-Host ""
    Write-Host $BLUE "基本使用:" -ForegroundColor $BLUE
    Write-Host "  git add .                    # 添加文件"
    Write-Host "  git commit -m `"message`"     # 提交（自动触发 pre-commit 检查）"
    Write-Host "  git push origin main         # 推送（自动触发 pre-push 检查）"
    Write-Host ""
    Write-Host $BLUE "跳过检查:" -ForegroundColor $BLUE
    Write-Host "  git commit --no-verify -m `"message`"     # 跳过 pre-commit 检查"
    Write-Host "  git push --no-verify origin main         # 跳过 pre-push 检查"
    Write-Host ""
    Write-Host $BLUE "配置选项:" -ForegroundColor $BLUE
    Write-Host "  编辑 .claude-hooks-config.sh 文件来自定义行为"
    Write-Host "  设置环境变量临时改变配置"
    Write-Host ""
    Write-Host $BLUE "故障排除:" -ForegroundColor $BLUE
    Write-Host "  `$env:CLAUDE_HOOKS_DEBUG = `$true          # 启用调试模式"
    Write-Host "  Get-Content .claude-hooks.log               # 查看日志"
    Write-Host "  .\uninstall.ps1                             # 卸载 hooks"
    Write-Host ""
    Write-Host $GREEN "🚀 Claude Code Git Hooks 安装完成！" -ForegroundColor $GREEN
}

# 主函数
function Main {
    Show-Welcome

    Write-Log "开始安装 Claude Code Git hooks..." -Type "STEP"

    # 确保在项目根目录运行
    Set-Location (git rev-parse --show-toplevel)
    Write-Log "项目根目录: $(Get-Location)" -Type "INFO"

    Check-Requirements
    Verify-Files
    Backup-ExistingHooks
    Install-Hooks
    Install-Config
    Install-Gitignore
    Verify-Installation

    Show-UsageInstructions
}

# 错误处理
trap {
    Write-Log "安装过程中发生错误，请检查错误信息并重试" -Type "ERROR"
    exit 1
}

# 运行主函数
Main