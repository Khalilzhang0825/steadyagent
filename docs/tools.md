# SteadyAgent Tools

SteadyAgent ships a Windows-first PowerShell tool slice because the workflow was proven on Windows before being generalized.

If you are installing SteadyAgent for the first time, start with [getting-started.md](getting-started.md). If you want the architecture before the commands, read [how-it-works.md](how-it-works.md).

## Commands

- `tools/install.ps1`: dry-run installer for Codex and Claude Code templates, rules, the `steadyagent-workflow` skill, hook runtime scripts, and hook docs. It prints the copy/render plan by default and writes only when `-Apply` is passed.
- `tools/diagnose-install.ps1`: checks installed host roots, rendered hook configs, active host hook configs, and installed hook smoke tests.
- `tools/enable-codex-hooks.ps1`: safely installs the rendered Codex managed-hook manifest into the active Codex managed config path. It is dry-run by default and backs up existing config before replacement.
- `tools/git-preflight.ps1`: checks Git identity, repository root, branch, remotes, status, `.gitignore`, and large untracked files.
- `tools/git-checkpoint.ps1`: stages explicit files and creates a checkpoint commit. Use `-DryRun` to preview the plan.
- `tools/test-hooks.ps1`: smoke-tests the public hook script in a temporary repository.
- `tools/test-agent-hooks.ps1`: smoke-tests the public agent hook runtime by sending hook event JSON through real stdin.
- `tools/validate-runtime-slice.ps1`: validates the public hook runtime files, templates, docs, and smoke tests.
- `tools/validate-release-readiness.ps1`: validates release assets, local Markdown links, a fresh workspace snapshot, rendered host configs, and installed hook smoke tests.
- `tools/hooks/pre-commit.ps1`: sample pre-commit hook that scans staged files for possible secrets and large files.
- `tools/hooks/agent-hook-*.ps1`: public SessionStart, UserPromptSubmit, PreToolUse, PermissionRequest, PostToolUse, and PreCompact hook scripts.

## Dry-Run First

Run the installer without `-Apply` first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex
```

The output should start with `DRY-RUN` and `WOULD copy` lines. Review the plan before applying it.

The installer renders hook config examples with the selected target root in place of `STEADYAGENT_HOME`: Codex gets `requirements.managed-hooks.example.toml`, and Claude Code gets `settings.hooks.example.json`.

The installer also copies the packaged skill to `skills/steadyagent-workflow/` under the selected target root.

After applying to a target root, run that target's `tools/test-agent-hooks.ps1` to smoke-test the installed hook runtime before merging the generated hook config into the host.

`test-agent-hooks.ps1` proves the hook scripts work. It does not prove the host has registered those scripts. Use `diagnose-install.ps1 -RequireHooksActive` after activating the host config and restarting the host.

`-Apply` refuses to overwrite existing targets by default. Use `-Overwrite` only after reviewing the dry-run plan and existing files. When `-HostTarget Both` is used with `-TargetRoot`, the installer plans separate `codex/` and `claude/` subdirectories under that root.

## Diagnose Installation

Run after installing assets:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\diagnose-install.ps1" -HostTarget Codex
```

Run after activating hooks and restarting the host:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\diagnose-install.ps1" -HostTarget Codex -RequireHooksActive
```

The script prints `PASS`, `WARN`, and `FAIL` rows. Missing active hook config is a warning by default and a failure with `-RequireHooksActive`.

## Enable Codex Hooks

Preview first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\enable-codex-hooks.ps1"
```

Apply from an elevated PowerShell session:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\enable-codex-hooks.ps1" -Apply
```

If a different Codex managed config already exists, the script refuses to replace it unless `-ForceReplace` is supplied. Review the target file and backup plan before using that switch.

## Cross-platform Status

Cross-platform support is not claimed yet. The scripts are written for PowerShell and Git on Windows. Linux/macOS support should be added through tested scripts, not README promises.

## Hook Runtime

The hook runtime is documented separately in [docs/hook-runtime.md](hook-runtime.md). Use [activation-guide.md](activation-guide.md) for the full host activation path. Use `templates/codex/requirements.managed-hooks.example.toml` for Codex managed hooks and `templates/claude/settings.hooks.example.json` for Claude Code settings hooks.
