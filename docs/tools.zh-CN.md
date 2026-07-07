# SteadyAgent 工具

Phase 3 发布第一组可运行工具。当前工具是 Windows-first，并基于 PowerShell，因为这套 workflow 先在 Windows 上验证，再逐步公开化。

## 命令

- `tools/install.ps1`：Codex 和 Claude Code 模板的 dry-run 安装器。默认只打印复制计划，只有传入 `-Apply` 才会写入文件。
- `tools/git-preflight.ps1`：检查 Git 身份、仓库根目录、分支、远端、状态、`.gitignore` 和大体积未跟踪文件。
- `tools/git-checkpoint.ps1`：只暂存显式文件并创建 checkpoint commit。使用 `-DryRun` 可以预览计划。
- `tools/test-hooks.ps1`：在临时仓库里 smoke-test 公开 hook 脚本。
- `tools/test-agent-hooks.ps1`：通过真实 stdin 发送 hook event JSON，smoke-test 公开 agent hook runtime。
- `tools/validate-runtime-slice.ps1`：验证公开 hook runtime 文件、模板、文档和 smoke tests。
- `tools/hooks/pre-commit.ps1`：示例 pre-commit hook，用于扫描 staged 文件里的可能 secrets 和 large files。
- `tools/hooks/agent-hook-*.ps1`：公开的 SessionStart、UserPromptSubmit、PreToolUse、PermissionRequest、PostToolUse 和 PreCompact hook scripts。

## Dry-run 优先

先不带 `-Apply` 运行安装器：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex
```

输出应该以 `DRY-RUN` 开头，并包含 `WOULD copy` 行。确认计划后再决定是否应用。

`-Apply` 默认拒绝覆盖已有目标。只有在看过 dry-run 计划和已有文件后，才使用 `-Overwrite`。当 `-HostTarget Both` 搭配 `-TargetRoot` 使用时，安装器会在该目录下规划独立的 `codex/` 和 `claude/` 子目录。

## Cross-platform 状态

当前不承诺 Cross-platform 支持。脚本面向 Windows 上的 PowerShell 和 Git。Linux/macOS 支持必须通过真实脚本验证加入，而不是靠 README 承诺。

## Hook Runtime

Hook runtime 单独写在 [docs/hook-runtime.zh-CN.md](hook-runtime.zh-CN.md)。Codex managed hooks 使用 `templates/codex/requirements.managed-hooks.example.toml`，Claude Code settings hooks 使用 `templates/claude/settings.hooks.example.json`。
