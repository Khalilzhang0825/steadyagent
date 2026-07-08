# 快速上手

如果你刚安装 Codex 或 Claude Code，还不知道 SteadyAgent 应该怎么嵌入自己的工作流，从这里开始。

SteadyAgent 不是新的聊天软件。它是一套本地工作流 harness，会把指令、规则、可复用 skill、验证脚本和 hook 示例安装到你已经在使用的 agent 宿主里。

## 前置条件

- Windows 和 PowerShell。
- Git。
- 本仓库的本地 checkout。
- Codex、Claude Code，或两者都用。

v1 暂不承诺跨平台 installer。公开脚本是 Windows-first，因为这套环境已经做过端到端验证。

## 选择你的路径

| 你的情况 | 从这里开始 |
| --- | --- |
| 刚开始用 Codex | [Codex 新手路径](#codex-新手路径) |
| 已经在用 Claude Code | [Claude Code 路径](#claude-code-路径) |
| 两个宿主都用 | [双宿主路径](#双宿主路径) |
| 先评估不安装 | [先理解项目](#先理解项目) |

## Codex 新手路径

1. 在 SteadyAgent 仓库里打开 PowerShell。
2. 先验证当前 checkout：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1
```

3. 预览 Codex 安装计划：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex
```

4. 检查 `DRY-RUN` 输出。正常情况下会看到 `WOULD copy` 和 `WOULD render` 行。这一步不会写入文件。
5. 确认计划没问题后再应用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex -Apply
```

6. 冒烟测试已安装的 hook runtime：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\test-agent-hooks.ps1"
```

7. 启用 Codex managed hooks。先预览：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\enable-codex-hooks.ps1"
```

看过计划后，用管理员 PowerShell 加 `-Apply` 运行同一条命令。

8. 重启 Codex。

9. 诊断完整安装：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\diagnose-install.ps1" -HostTarget Codex -RequireHooksActive
```

10. 在你要开发的项目仓库里启动 Codex。如果宿主没有自动加载已安装的指令，可以把下面这段作为第一条提示词：

```text
Use the SteadyAgent workflow for this repository. First inspect the repo and the relevant docs, then give me a short plan before edits. After edits, run the smallest relevant validation and report changed files, verification, risks, and Git status.
```

## Claude Code 路径

1. 预览 Claude Code 安装计划：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Claude
```

2. 检查 dry-run 计划后再应用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Claude -Apply
```

3. 冒烟测试已安装的 hook runtime：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\tools\test-agent-hooks.ps1"
```

4. 只有在理解生成文件后，再把渲染后的 hook settings 合并进 Claude Code settings。生成文件是：

```text
$HOME\.claude\settings.hooks.example.json
```

把其中的 `hooks` object 合并进：

```text
$HOME\.claude\settings.json
```

5. 重启 Claude Code。

6. 诊断完整安装：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\tools\diagnose-install.ps1" -HostTarget Claude -RequireHooksActive
```

hook 生命周期和安全边界见 [activation-guide.zh-CN.md](activation-guide.zh-CN.md)。

## 双宿主路径

先预览一个隔离安装目录：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Both -TargetRoot .\steadyagent-install-preview
```

准备安装到默认宿主目录时再运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Both -Apply
```

默认目录是 Codex 的 `$HOME\.codex` 和 Claude Code 的 `$HOME\.claude`。如果目标文件已经存在，安装器会拒绝覆盖，除非传入 `-Overwrite`。使用 `-Overwrite` 前必须先看清已有文件。

## 先理解项目

按这个顺序读：

1. [how-it-works.zh-CN.md](how-it-works.zh-CN.md)：SteadyAgent 安装什么，以及每层为什么存在。
2. [feature-map.zh-CN.md](feature-map.zh-CN.md)：每个功能对应哪些文件、安装位置、触发方式和检查方式。
3. [activation-guide.zh-CN.md](activation-guide.zh-CN.md)：如何让 Codex 和 Claude Code 真正加载已安装 hooks。
4. [workflow-examples.zh-CN.md](workflow-examples.zh-CN.md)：bug 修复、feature、review、长任务和发布检查的提示词示例。
5. [tools.zh-CN.md](tools.zh-CN.md)：具体命令和工具行为。
6. [hook-runtime.zh-CN.md](hook-runtime.zh-CN.md)：生命周期 hook 示例，以及它们能和不能强制什么。

## 会安装什么

| 安装项 | 作用 |
| --- | --- |
| `AGENTS.md` 或 `CLAUDE.md` | 对应宿主的短常驻指令。 |
| `rules/` | 渐进加载的 workflow、verification、review、context 和 safety 规则。 |
| `skills/steadyagent-workflow/` | 可复用 workflow skill，包含参考资料和 agent 元数据。 |
| `tools/hooks/agent-hook-*.ps1` | 公开 hook 脚本，用于提醒、上下文注入、命令检查、文件检查、权限检查、审计日志和压缩前提醒。 |
| `tools/test-agent-hooks.ps1` | 已安装 hook runtime 的冒烟测试。 |
| `tools/diagnose-install.ps1` | 检查安装文件、active host config 和 hook smoke tests 的诊断脚本。 |
| `tools/enable-codex-hooks.ps1` | Codex 启用助手，只在 dry-run 审查和管理员确认后写入 managed hook manifest。 |
| 渲染后的 hook config example | 按目标安装目录替换 `%STEADYAGENT_HOME%` 后生成的宿主配置示例。 |

## 日常怎么用

正常工作时，你只需要告诉 agent 想要的结果，然后让 SteadyAgent 约束过程：

```text
Fix the failing login test. Use SteadyAgent: inspect first, keep the change scoped, run the smallest relevant validation, and checkpoint only after review.
```

agent 应该报告：

- 改了什么
- 用什么验证
- 还剩什么风险
- Git 状态

## 常见问题

- 如果 PowerShell 阻止脚本执行，按示例加上 `-ExecutionPolicy Bypass`。
- 如果安装失败并提示目标已存在，先重新 dry-run，对比已有文件后再决定是否使用 `-Overwrite`。
- 如果宿主没有自动加载全局指令，在任务开始时粘贴本文的第一条提示词。
- 如果不确定 hook 是否生效，在目标安装目录运行 `tools/test-agent-hooks.ps1`，并阅读 [hook-runtime.zh-CN.md](hook-runtime.zh-CN.md)。
- 如果 hook scripts 通过但真实会话里 hooks 没反应，阅读 [activation-guide.zh-CN.md](activation-guide.zh-CN.md)，并运行 `tools/diagnose-install.ps1 -RequireHooksActive`。
