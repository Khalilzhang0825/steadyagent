# SteadyAgent Tools

Phase 3 publishes the first operational tool slice. The tools are Windows-first and PowerShell-based because the workflow was proven on Windows before being generalized.

## Commands

- `tools/install.ps1`: dry-run installer for Codex and Claude Code templates, rules, hook runtime scripts, and hook docs. It prints the copy/render plan by default and writes only when `-Apply` is passed.
- `tools/git-preflight.ps1`: checks Git identity, repository root, branch, remotes, status, `.gitignore`, and large untracked files.
- `tools/git-checkpoint.ps1`: stages explicit files and creates a checkpoint commit. Use `-DryRun` to preview the plan.
- `tools/test-hooks.ps1`: smoke-tests the public hook script in a temporary repository.
- `tools/test-agent-hooks.ps1`: smoke-tests the public agent hook runtime by sending hook event JSON through real stdin.
- `tools/validate-runtime-slice.ps1`: validates the public hook runtime files, templates, docs, and smoke tests.
- `tools/hooks/pre-commit.ps1`: sample pre-commit hook that scans staged files for possible secrets and large files.
- `tools/hooks/agent-hook-*.ps1`: public SessionStart, UserPromptSubmit, PreToolUse, PermissionRequest, PostToolUse, and PreCompact hook scripts.

## Dry-Run First

Run the installer without `-Apply` first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex
```

The output should start with `DRY-RUN` and `WOULD copy` lines. Review the plan before applying it.

The installer renders hook config examples with the selected target root in place of `STEADYAGENT_HOME`: Codex gets `requirements.managed-hooks.example.toml`, and Claude Code gets `settings.hooks.example.json`.

After applying to a target root, run that target's `tools/test-agent-hooks.ps1` to smoke-test the installed hook runtime before merging the generated hook config into the host.

`-Apply` refuses to overwrite existing targets by default. Use `-Overwrite` only after reviewing the dry-run plan and existing files. When `-HostTarget Both` is used with `-TargetRoot`, the installer plans separate `codex/` and `claude/` subdirectories under that root.

## Cross-platform Status

Cross-platform support is not claimed yet. The scripts are written for PowerShell and Git on Windows. Linux/macOS support should be added through tested scripts, not README promises.

## Hook Runtime

The hook runtime is documented separately in [docs/hook-runtime.md](hook-runtime.md). Use `templates/codex/requirements.managed-hooks.example.toml` for Codex managed hooks and `templates/claude/settings.hooks.example.json` for Claude Code settings hooks.
