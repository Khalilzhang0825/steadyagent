# SteadyAgent Hook Runtime

This slice turns SteadyAgent from a documentation-only workflow into a hook-driven local harness. The runtime is Windows-first and PowerShell-based.

## Runtime Events

- `SessionStart`: injects compact operating reminders and restores `PROJECT_STATE.md` or `.agent/state.md` after resume/compaction.
- `UserPromptSubmit`: injects a short rule pointer and risk-specific reminders.
- `PreToolUse`: blocks deterministic unsafe shell commands and secret-file edits before they run.
- `PermissionRequest`: denies known dangerous escalation requests instead of relying only on the approval prompt.
- `PostToolUse`: records a compact audit trail after shell/edit tool calls. Command text is redacted and hashed.
- `PreCompact`: emits a supported `systemMessage` reminder to preserve task state before context compaction.

## Managed Hooks

Codex can use managed hooks supplied by the runtime environment. For that path, keep user `hooks.json` empty and configure the managed hook manifest from `templates/codex/requirements.managed-hooks.example.toml`.

Claude Code uses `settings.json`; start from `templates/claude/settings.hooks.example.json`.

Both templates use `STEADYAGENT_HOME` as a placeholder. Replace it with the checkout or install directory before applying.

`tools/install.ps1` renders host-specific examples for you when a target root is provided. It writes Codex `requirements.managed-hooks.example.toml` and Claude Code `settings.hooks.example.json` with the selected target root already substituted.

Rendering a config file is not the same as activating host hooks. Use [activation-guide.md](activation-guide.md) to install the active Codex managed manifest or merge Claude Code settings, then restart the host. Use `tools/diagnose-install.ps1 -RequireHooksActive` to check the full setup.

## Logs

Hook logs go to `STEADYAGENT_LOG_DIR` when that environment variable is set. Otherwise they default to a user-local application data directory.

## Verification

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\test-agent-hooks.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-runtime-slice.ps1
```

These tests simulate hook event JSON through real stdin and verify observable behavior, not internal functions.

They prove the scripts work. They do not prove Codex or Claude Code has loaded the scripts as live hooks.
