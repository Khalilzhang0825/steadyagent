# SteadyAgent Hook Runtime

这一阶段把 SteadyAgent 从文档型工作流推进到 hook-driven local harness。当前实现是 Windows-first，基于 PowerShell。

## Runtime Events

- `SessionStart`：注入精简操作提醒，并在 resume/compact 后恢复 `PROJECT_STATE.md` 或 `.agent/state.md`。
- `UserPromptSubmit`：注入短规则指针，并按风险关键词补充提醒。
- `PreToolUse`：在工具执行前拦截确定性的危险 shell 命令和密钥文件编辑。
- `PermissionRequest`：对已知危险提权请求做二次拒绝，不只依赖 approval prompt。
- `PostToolUse`：工具执行后记录紧凑审计日志；命令文本会脱敏并记录 hash。
- `PreCompact`：压缩前通过受支持的 `systemMessage` 提醒 agent 固化任务状态。

## Managed Hooks

Codex 可以走 managed hooks。这个路径下，用户级 `hooks.json` 可以保持为空，由运行时托管配置负责注册 hook。公开模板见 `templates/codex/requirements.managed-hooks.example.toml`。

Claude Code 使用 `settings.json` 注册 hook，公开模板见 `templates/claude/settings.hooks.example.json`。

两个模板都使用 `STEADYAGENT_HOME` 作为占位符。真正应用前需要替换成 checkout 或安装目录。

当传入目标根目录时，`tools/install.ps1` 会自动渲染 host-specific examples：Codex 得到已替换目标路径的 `requirements.managed-hooks.example.toml`，Claude Code 得到已替换目标路径的 `settings.hooks.example.json`。

渲染配置文件不等于启用宿主 hooks。完整路径见 [activation-guide.zh-CN.md](activation-guide.zh-CN.md)：Codex 需要写入 active managed manifest，Claude Code 需要合并 settings，然后重启宿主。用 `tools/diagnose-install.ps1 -RequireHooksActive` 检查完整设置。

## Logs

如果设置了 `STEADYAGENT_LOG_DIR`，hook 日志写入该目录；否则写入用户本地应用数据目录。

## Verification

运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\test-agent-hooks.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-runtime-slice.ps1
```

测试会通过真实 stdin 模拟 hook event JSON，验证可观察行为，而不是只检查内部函数。

这些测试证明脚本能运行，不证明 Codex 或 Claude Code 已经把这些脚本加载为真实 hooks。
