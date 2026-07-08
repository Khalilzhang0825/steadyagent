# SteadyAgent 工具

SteadyAgent 发布的是一组 Windows-first 的 PowerShell 工具，因为这套 workflow 先在 Windows 上验证，再逐步公开化。

如果你是第一次安装 SteadyAgent，先读 [getting-started.zh-CN.md](getting-started.zh-CN.md)。如果想先理解架构，再读 [how-it-works.zh-CN.md](how-it-works.zh-CN.md)。

## 命令

- `tools/install.ps1`：Codex 和 Claude Code 模板、rules、`steadyagent-workflow` skill、hook runtime scripts 和 hook docs 的 dry-run 安装器。默认只打印复制 / 渲染计划，只有传入 `-Apply` 才会写入文件。
- `tools/diagnose-install.ps1`：检查已安装宿主目录、渲染后的 hook config、active host hook config 和安装后的 hook smoke tests。
- `tools/enable-codex-hooks.ps1`：把渲染后的 Codex managed-hook manifest 安全安装到 active Codex managed config path。默认 dry-run，替换已有配置前会备份。
- `tools/git-preflight.ps1`：检查 Git 身份、仓库根目录、分支、远端、状态、`.gitignore` 和大体积未跟踪文件。
- `tools/git-checkpoint.ps1`：只暂存显式文件并创建 checkpoint commit。使用 `-DryRun` 可以预览计划。
- `tools/test-hooks.ps1`：在临时仓库里 smoke-test 公开 hook 脚本。
- `tools/test-agent-hooks.ps1`：通过真实 stdin 发送 hook event JSON，smoke-test 公开 agent hook runtime。
- `tools/validate-runtime-slice.ps1`：验证公开 hook runtime 文件、模板、文档和 smoke tests。
- `tools/validate-release-readiness.ps1`：验证 release assets、本地 Markdown 链接、fresh workspace snapshot、渲染后的 host configs 和安装后的 hook smoke tests。
- `tools/hooks/pre-commit.ps1`：示例 pre-commit hook，用于扫描 staged 文件里的可能 secrets 和 large files。
- `tools/hooks/agent-hook-*.ps1`：公开的 SessionStart、UserPromptSubmit、PreToolUse、PermissionRequest、PostToolUse 和 PreCompact hook scripts。

## Dry-run 优先

先不带 `-Apply` 运行安装器：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex
```

输出应该以 `DRY-RUN` 开头，并包含 `WOULD copy` 行。确认计划后再决定是否应用。

安装器会把 hook config examples 里的 `STEADYAGENT_HOME` 替换成目标根目录：Codex 得到 `requirements.managed-hooks.example.toml`，Claude Code 得到 `settings.hooks.example.json`。

安装器也会把已打包的 skill 复制到目标根目录下的 `skills/steadyagent-workflow/`。

应用到目标目录后，先运行该目标目录里的 `tools/test-agent-hooks.ps1`，确认已安装 hook runtime 冒烟测试通过，再把生成的 hook config 合并到宿主配置里。

`test-agent-hooks.ps1` 证明 hook scripts 自身可用，不证明宿主已经注册这些脚本。宿主配置启用并重启后，用 `diagnose-install.ps1 -RequireHooksActive` 检查完整生效状态。

`-Apply` 默认拒绝覆盖已有目标。只有在看过 dry-run 计划和已有文件后，才使用 `-Overwrite`。当 `-HostTarget Both` 搭配 `-TargetRoot` 使用时，安装器会在该目录下规划独立的 `codex/` 和 `claude/` 子目录。

## 诊断安装

安装文件后运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\diagnose-install.ps1" -HostTarget Codex
```

启用 hooks 并重启宿主后运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\diagnose-install.ps1" -HostTarget Codex -RequireHooksActive
```

脚本会输出 `PASS`、`WARN` 和 `FAIL`。默认情况下缺少 active hook config 是 warning；加上 `-RequireHooksActive` 后会变成 failure。

## 启用 Codex Hooks

先预览：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\enable-codex-hooks.ps1"
```

在管理员 PowerShell 中应用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\enable-codex-hooks.ps1" -Apply
```

如果已有不同的 Codex managed config，脚本会拒绝替换，除非显式传入 `-ForceReplace`。使用该开关前必须先查看目标文件和备份计划。

## Cross-platform 状态

当前不承诺 Cross-platform 支持。脚本面向 Windows 上的 PowerShell 和 Git。Linux/macOS 支持必须通过真实脚本验证加入，而不是靠 README 承诺。

## Hook Runtime

Hook runtime 单独写在 [docs/hook-runtime.zh-CN.md](hook-runtime.zh-CN.md)。完整宿主启用路径见 [activation-guide.zh-CN.md](activation-guide.zh-CN.md)。Codex managed hooks 使用 `templates/codex/requirements.managed-hooks.example.toml`，Claude Code settings hooks 使用 `templates/claude/settings.hooks.example.json`。
