# SteadyAgent Tools

Phase 3 publishes the first operational tool slice. The tools are Windows-first and PowerShell-based because the workflow was proven on Windows before being generalized.

## Commands

- `tools/install.ps1`: dry-run installer for Codex and Claude Code templates. It prints the copy plan by default and writes only when `-Apply` is passed.
- `tools/git-preflight.ps1`: checks Git identity, repository root, branch, remotes, status, `.gitignore`, and large untracked files.
- `tools/git-checkpoint.ps1`: stages explicit files and creates a checkpoint commit. Use `-DryRun` to preview the plan.
- `tools/test-hooks.ps1`: smoke-tests the public hook script in a temporary repository.
- `tools/hooks/pre-commit.ps1`: sample pre-commit hook that scans staged files for possible secrets and Large files.

## Dry-Run First

Run the installer without `-Apply` first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex
```

The output should start with `DRY-RUN` and `WOULD copy` lines. Review the plan before applying it.

`-Apply` refuses to overwrite existing targets by default. Use `-Overwrite` only after reviewing the dry-run plan and existing files. When `-HostTarget Both` is used with `-TargetRoot`, the installer plans separate `codex/` and `claude/` subdirectories under that root.

## Cross-platform Status

Cross-platform support is not claimed yet. The scripts are written for PowerShell and Git on Windows. Linux/macOS support should be added through tested scripts, not README promises.
