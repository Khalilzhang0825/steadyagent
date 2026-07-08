# SteadyAgent 功能实现地图

这份文档把 SteadyAgent 的每个用户可见功能映射到实现文件、安装后位置、触发方式和验证方式。

你可以用它回答一个关键问题：这个功能只是文档说明，还是仓库里真的有对应实现？

## 快速查看

| 功能 | 实现文件 | 安装后位置 | 如何触发 | 如何验证 |
| --- | --- | --- | --- | --- |
| Codex 入口指令 | `templates/codex/AGENTS.md` | `$HOME\.codex\AGENTS.md` | 启动 Codex，或要求 agent 使用 SteadyAgent | 让 Codex 说明当前仓库的工作规则 |
| Claude Code 入口指令 | `templates/claude/CLAUDE.md` | `$HOME\.claude\CLAUDE.md` | 启动 Claude Code | 让 Claude Code 说明当前仓库的工作规则 |
| 渐进工作流规则 | `rules/*.md` | `$HOME\.codex\rules\` 或 `$HOME\.claude\rules\` | 提出实现、审查、验证、上下文恢复或安全相关任务 | 确认 agent 修改前读取了相关规则 |
| 可复用 workflow skill | `skills/steadyagent-workflow/` | `<host-root>\skills\steadyagent-workflow\` | 在支持 skill 的宿主中调用，或要求 agent 使用 SteadyAgent workflow | 确认 `SKILL.md` 存在且宿主能路由到它 |
| Dry-run 安装器 | `tools/install.ps1` | 从仓库 checkout 运行 | `tools/install.ps1 -HostTarget Codex`、`Claude` 或 `Both` | 输出以 `DRY-RUN` 开头，且不写入文件 |
| 安装资产复制 | `tools/install.ps1` | 选中的宿主根目录 | 看过 dry-run 后加 `-Apply` 重新运行 | 目标宿主目录下出现预期文件 |
| Git preflight | `tools/git-preflight.ps1` | 仓库工具，不由安装器复制 | 修改文件前运行 | 输出仓库根、分支、远端、状态、身份和 ignore 检查 |
| Git checkpoint | `tools/git-checkpoint.ps1` | 仓库工具，不由安装器复制 | 验证通过后用显式 `-Files` 运行 | 只把点名文件写入 checkpoint commit |
| Hook runtime scripts | `tools/hooks/agent-hook-*.ps1` | `<host-root>\tools\hooks\` | hooks 启用后由宿主生命周期事件触发 | `tools/test-agent-hooks.ps1` 报告 `0 failed` |
| Codex managed hook manifest | `templates/codex/requirements.managed-hooks.example.toml` | `$HOME\.codex\requirements.managed-hooks.example.toml` | 在管理员 PowerShell 中运行 `tools/enable-codex-hooks.ps1 -Apply` | `tools/diagnose-install.ps1 -HostTarget Codex -RequireHooksActive` |
| Claude Code hook settings example | `templates/claude/settings.hooks.example.json` | `$HOME\.claude\settings.hooks.example.json` | 合并到 `$HOME\.claude\settings.json` 后重启 Claude Code | `tools/diagnose-install.ps1 -HostTarget Claude -RequireHooksActive` |
| 安装诊断 | `tools/diagnose-install.ps1` | `<host-root>\tools\diagnose-install.ps1` | 安装和启用 hooks 后运行 | 输出 assets、config、hook smoke tests 的 pass、warn、fail 计数 |
| Codex hook 启用助手 | `tools/enable-codex-hooks.ps1` | `$HOME\.codex\tools\enable-codex-hooks.ps1` | 默认预览；管理员 PowerShell 中加 `-Apply` 写入 | managed config 存在，并包含 SteadyAgent hook 条目 |
| Hook 冒烟测试 | `tools/test-agent-hooks.ps1` | `<host-root>\tools\test-agent-hooks.ps1` | 安装后手动运行 | 逐项报告 hook 行为，最后显示 `0 failed` |
| 发布可用性 gate | `tools/validate-release-readiness.ps1` | 仓库工具 | 发布前或公开改动前运行 | 检查发布文件、文档、链接、安装、诊断和 hook smoke tests |
| GitHub 验证工作流 | `.github/workflows/validate.yml` | GitHub Actions | GitHub push 或 PR | Windows workflow 运行 release-readiness gate |

## 功能细节

### 入口指令

SteadyAgent 让宿主入口指令保持短。Codex 使用 `AGENTS.md`，Claude Code 使用 `CLAUDE.md`。

这些文件会要求 agent 控制改动范围、编辑前阅读相关文档、验证行为、报告风险，并遵守发布边界。它们不会塞进所有细则，而是把 agent 指向 `rules/`、docs、tools 和验证脚本。

### 规则

`rules/` 是更深一层的操作手册：

| 规则文件 | 作用 |
| --- | --- |
| `workflow-routing.md` | 选择工作模式：诊断、实现、审查、发布或长任务恢复。 |
| `verification.md` | 定义如何证明任务真的完成。 |
| `review-gates.md` | 判断 checkpoint 前是否必须独立审查。 |
| `context-management.md` | 处理长任务、压缩、恢复和任务状态文件。 |
| `safety-boundaries.md` | 定义必须显式批准或硬拦截的高风险操作。 |

触发方式就是用户请求。例如 bug 修复应该让 agent 先检查和复现或找到证据，再做最小改动、运行验证并报告剩余风险。

### Skill

`skills/steadyagent-workflow/` 把同一套工作流打包成可复用 skill，供支持 skills 的宿主使用。它包含 `SKILL.md`、参考资料和 agent 元数据。

安装后路径是：

```text
<host-root>\skills\steadyagent-workflow\
```

如果宿主支持 skill routing，可以直接调用。即使宿主不支持 skills，同一套工作流仍然可以通过入口指令、文档、规则和脚本使用。

### 工具

工具把可重复行为变成可观察命令：

| 工具 | 它证明什么 |
| --- | --- |
| `install.ps1` | 公开包可以不靠手动复制完成安装。 |
| `diagnose-install.ps1` | 本机宿主目录拥有预期文件和已启用的 hook 配置。 |
| `enable-codex-hooks.ps1` | Codex managed hooks 可以安全启用，不会静默覆盖已有配置。 |
| `git-preflight.ps1` | agent 修改前能看到仓库状态。 |
| `git-checkpoint.ps1` | checkpoint 只包含显式指定文件。 |
| `test-agent-hooks.ps1` | hook scripts 接收真实 hook event JSON 时行为正确。 |
| `validate-release-readiness.ps1` | 公开包可以从 fresh workspace snapshot 验证。 |

### Hooks

Hook scripts 是实现，不只是文档。它们位于 `tools/hooks/`，覆盖这些生命周期事件：

| 事件 | 脚本 | 行为 |
| --- | --- | --- |
| `SessionStart` | `agent-hook-context.ps1` | 注入精简提醒，并在 resume 或 compact 后恢复 `PROJECT_STATE.md` 或 `.agent/state.md`。 |
| `UserPromptSubmit` | `agent-hook-prompt-reminder.ps1` | 针对 push、release、delete、install 等请求追加风险提醒。 |
| `PreToolUse` | `agent-hook-command-guard.ps1` | 拒绝已知高风险 shell 和 Git 命令。 |
| `PreToolUse` | `agent-hook-file-guard.ps1` | 拒绝编辑敏感文件，同时允许安全 example 文件。 |
| `PermissionRequest` | `agent-hook-permission-guard.ps1` | 拒绝已知危险提权请求。 |
| `PostToolUse` | `agent-hook-posttool-audit.ps1` | 记录紧凑审计日志，命令文本会脱敏并写入 hash。 |
| `PreCompact` | `agent-hook-precompact.ps1` | 压缩前提醒 agent 固化任务状态。 |

`test-agent-hooks.ps1` 直接验证这些脚本。宿主是否真正注册这些脚本是另一层问题，由 `diagnose-install.ps1` 检查。

## 哪些需要宿主启用

安装后就能工作的功能：

- 复制到宿主根目录的入口指令
- 可在磁盘上读取的 rules 和 skill 文件
- installer dry-run 和 apply
- hook script 冒烟测试
- 仓库验证 gates

必须启用宿主 hooks 并重启会话后才会实时生效的功能：

- Codex managed lifecycle hooks
- Claude Code settings hooks
- 实时命令拦截
- 实时文件拦截
- permission request 拦截
- 来自真实宿主事件的 tool audit log
- 来自真实宿主事件的 pre-compact reminder

这层区分很重要。hook 冒烟测试通过只证明脚本可用，不证明宿主已经注册这些脚本。完整启用路径见 [activation-guide.zh-CN.md](activation-guide.zh-CN.md)。
