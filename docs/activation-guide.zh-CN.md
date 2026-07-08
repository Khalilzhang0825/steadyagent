# SteadyAgent 完整启用指南

安装和启用不是同一件事。

`tools/install.ps1` 会把 SteadyAgent 文件复制到宿主目录，并渲染 hook 配置示例。实时 hooks 只有在宿主真的加载这些配置，并且重启宿主会话后才会运行。

建议先读 [getting-started.zh-CN.md](getting-started.zh-CN.md)，再按本文完成启用。

## 启用清单

| 步骤 | Codex | Claude Code |
| --- | --- | --- |
| 安装文件 | `tools/install.ps1 -HostTarget Codex -Apply` | `tools/install.ps1 -HostTarget Claude -Apply` |
| 冒烟测试脚本 | `$HOME\.codex\tools\test-agent-hooks.ps1` | `$HOME\.claude\tools\test-agent-hooks.ps1` |
| 启用宿主 hooks | 在管理员 PowerShell 中运行 `tools/enable-codex-hooks.ps1 -Apply` | 把 `settings.hooks.example.json` 合并进 `settings.json` |
| 重启宿主 | 重启 Codex | 重启 Claude Code |
| 诊断完整安装 | `tools/diagnose-install.ps1 -HostTarget Codex -RequireHooksActive` | `tools/diagnose-install.ps1 -HostTarget Claude -RequireHooksActive` |
| 功能触发测试 | 在临时仓库测试 `.env` 编辑或危险 Git 命令，预期被拒绝 | 同左 |

## Codex 完整启用

1. 安装 SteadyAgent 文件：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex -Apply
```

2. 先确认 hook scripts 自身可用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\test-agent-hooks.ps1"
```

预期结果：

```text
Smoke test: 30 passed, 0 failed
```

未来版本 pass 数可能增加，关键是 `0 failed`。

3. 预览 managed-hook 启用计划：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\enable-codex-hooks.ps1"
```

这个命令默认 dry-run。它会显示：

- source rendered manifest：`$HOME\.codex\requirements.managed-hooks.example.toml`
- target managed manifest：`%ProgramData%\OpenAI\Codex\requirements.toml`
- 是否需要管理员权限
- 是否会遇到已有 managed manifest

4. 用管理员身份打开 PowerShell，然后应用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\enable-codex-hooks.ps1" -Apply
```

如果目标位置已经有不同的 managed manifest，脚本会拒绝直接替换。你应该先查看已有文件，再选择手动合并，或在理解风险后使用 `-ForceReplace`。脚本在替换已有文件前会创建备份。

5. 重启 Codex。

6. 诊断完整安装：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\diagnose-install.ps1" -HostTarget Codex -RequireHooksActive
```

理想结果是没有 failure。warning 代表可用但不完整，或者宿主还没有完全启用。

## Claude Code 完整启用

1. 安装 SteadyAgent 文件：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Claude -Apply
```

2. 确认 hook scripts 自身可用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\tools\test-agent-hooks.ps1"
```

3. 打开渲染后的 hook settings：

```powershell
notepad "$HOME\.claude\settings.hooks.example.json"
```

4. 把其中的 `hooks` object 合并进 Claude Code 的 active settings 文件：

```text
$HOME\.claude\settings.json
```

如果你已有 Claude Code settings，不要直接覆盖。先备份，再合并生成文件里的 `hooks` object。

5. 重启 Claude Code。Claude Code 的 hook 注册发生在会话启动时。

6. 诊断完整安装：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\tools\diagnose-install.ps1" -HostTarget Claude -RequireHooksActive
```

## 双宿主

安装两个宿主：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Both -Apply
```

Codex 和 Claude Code 需要分别启用。它们的配置文件和宿主注册方式不同。

两个宿主都启用后，运行联合诊断：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\diagnose-install.ps1" -HostTarget Both -RequireHooksActive
```

也可以从仓库里的 `tools/diagnose-install.ps1` 运行同一条命令。安装器也会复制一份到宿主目录，方便用户离开 checkout 后继续诊断。

## 启用后如何触发功能

下面的 probe 都应该在临时仓库里做。不要在真实项目里跑破坏性测试。

### 入口指令测试

发送：

```text
Use SteadyAgent for this repository. Before editing, tell me which repo checks and validation steps you will run.
```

预期行为：

- agent 修改前先检查仓库
- 非简单任务会先给短计划
- 结束时报告验证和 Git 状态

### 命令拦截测试

在临时仓库中发送：

```text
Use SteadyAgent. Try to run `git reset --hard HEAD` only as a guardrail test. The hook should deny it. Report the hook result and do not try to bypass it.
```

预期行为：hook 拒绝这个命令。

### 文件拦截测试

在临时仓库中发送：

```text
Use SteadyAgent. Try to create `.env` with `TEST_SECRET=1` only as a guardrail test. The hook should deny it. Report the hook result and do not try to bypass it.
```

预期行为：hook 拒绝这次编辑。

### 上下文恢复测试

在临时仓库中创建 `.agent/state.md`：

```markdown
# Test State
- Goal: confirm SteadyAgent context recovery
```

然后重启或恢复该仓库里的宿主会话。

预期行为：SessionStart hook 把任务状态注入到 agent 上下文。

### 正常工作测试

发送一个无害任务：

```text
Use SteadyAgent. Add a short note to a temporary README, run the smallest relevant validation, and report changed files, verification, risks, and Git status.
```

预期行为：agent 按 SteadyAgent 闭环工作，而不是静默编辑。

## Hooks 没反应的常见原因

| 现象 | 常见原因 | 处理方式 |
| --- | --- | --- |
| `test-agent-hooks.ps1` 通过，但真实 hooks 没反应 | 脚本可用，但宿主没有加载配置 | 启用宿主配置并重启宿主 |
| Codex hooks 不运行 | managed manifest 没写到 active managed config path | 在管理员 PowerShell 中运行 `enable-codex-hooks.ps1 -Apply` |
| Claude hooks 不运行 | `settings.hooks.example.json` 没合并进 `settings.json` | 合并 `hooks` object 并重启 Claude Code |
| hook config 里还有 `%STEADYAGENT_HOME%` | 用户复制了模板，而不是安装器渲染后的文件 | 使用宿主根目录里的渲染文件 |
| Codex 已有 managed config 导致启用失败 | enabler 拒绝覆盖不同 manifest | 手动合并，或确认备份计划后使用 `-ForceReplace` |
| 修改 settings 后仍然旧行为 | 宿主会话未重启 | 重启 Codex 或 Claude Code |

## 关闭或回滚

Codex：

- 恢复 `enable-codex-hooks.ps1` 创建的备份，或从 `%ProgramData%\OpenAI\Codex\requirements.toml` 中移除 SteadyAgent 条目。
- 重启 Codex。

Claude Code：

- 恢复你备份的 `$HOME\.claude\settings.json`，或移除其中的 SteadyAgent `hooks` object。
- 重启 Claude Code。

安装到 `$HOME\.codex` 或 `$HOME\.claude` 的文件都是本地普通文件，可以手动查看、备份或删除。
