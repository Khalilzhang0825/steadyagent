# SteadyAgent Activation Guide

Installation and activation are different steps.

`tools/install.ps1` copies SteadyAgent assets into a host root and renders hook config examples. Real-time hooks only run after the host is configured to load those examples and the host session is restarted.

Use this guide after [getting-started.md](getting-started.md).

## Activation Checklist

| Step | Codex | Claude Code |
| --- | --- | --- |
| Install assets | `tools/install.ps1 -HostTarget Codex -Apply` | `tools/install.ps1 -HostTarget Claude -Apply` |
| Smoke-test scripts | `$HOME\.codex\tools\test-agent-hooks.ps1` | `$HOME\.claude\tools\test-agent-hooks.ps1` |
| Activate host hooks | `tools/enable-codex-hooks.ps1 -Apply` from elevated PowerShell | Merge `settings.hooks.example.json` into `settings.json` |
| Restart host | Restart Codex | Restart Claude Code |
| Diagnose complete setup | `tools/diagnose-install.ps1 -HostTarget Codex -RequireHooksActive` | `tools/diagnose-install.ps1 -HostTarget Claude -RequireHooksActive` |
| Functional probe | Try a disposable `.env` edit or risky Git command and expect a denial | Same |

## Codex Full Activation

1. Install SteadyAgent assets:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex -Apply
```

2. Confirm the hook scripts work by themselves:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\test-agent-hooks.ps1"
```

Expected result:

```text
Smoke test: 30 passed, 0 failed
```

The exact pass count can increase in future releases. The important part is `0 failed`.

3. Preview managed-hook activation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\enable-codex-hooks.ps1"
```

This command is dry-run by default. It shows:

- source rendered manifest: `$HOME\.codex\requirements.managed-hooks.example.toml`
- target managed manifest: `%ProgramData%\OpenAI\Codex\requirements.toml`
- whether Administrator rights are needed
- whether an existing managed manifest would be overwritten

4. Open PowerShell as Administrator, then apply:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\enable-codex-hooks.ps1" -Apply
```

If a different managed manifest already exists, the script refuses to replace it. Review the existing file and either merge manually or run with `-ForceReplace` after you understand what will be replaced. The script creates a backup before replacing an existing file.

5. Restart Codex.

6. Diagnose the full setup:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\diagnose-install.ps1" -HostTarget Codex -RequireHooksActive
```

The diagnosis should report zero failures. Warnings mean something is usable but incomplete or not fully activated.

## Claude Code Full Activation

1. Install SteadyAgent assets:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Claude -Apply
```

2. Confirm the hook scripts work by themselves:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\tools\test-agent-hooks.ps1"
```

3. Open the rendered hook settings:

```powershell
notepad "$HOME\.claude\settings.hooks.example.json"
```

4. Merge the `hooks` object into your active Claude Code settings file:

```text
$HOME\.claude\settings.json
```

Do not blindly replace your settings if you already have other Claude Code settings. Back up the file first, then merge the generated `hooks` object.

5. Restart Claude Code. Claude Code registers hook changes at session start.

6. Diagnose the full setup:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\tools\diagnose-install.ps1" -HostTarget Claude -RequireHooksActive
```

## Both Hosts

Install both hosts:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Both -Apply
```

Activate Codex and Claude Code separately. They use different config files and different host registration paths.

Run the combined diagnosis after both are activated:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\diagnose-install.ps1" -HostTarget Both -RequireHooksActive
```

You can run the same command from the repository copy of `tools/diagnose-install.ps1`; the installed copy is provided so users can diagnose after moving away from the checkout.

## How To Trigger Features After Activation

Use a disposable test repository for probes. Do not run destructive probes inside a real project.

### Entry Instructions Probe

Ask:

```text
Use SteadyAgent for this repository. Before editing, tell me which repo checks and validation steps you will run.
```

Expected behavior:

- the agent inspects the repo before editing
- it gives a short plan for non-trivial work
- it reports validation and Git status at the end

### Command Guard Probe

In a disposable repository, ask:

```text
Use SteadyAgent. Try to run `git reset --hard HEAD` only as a guardrail test. The hook should deny it. Report the hook result and do not try to bypass it.
```

Expected behavior: the hook denies the command.

### File Guard Probe

In a disposable repository, ask:

```text
Use SteadyAgent. Try to create `.env` with `TEST_SECRET=1` only as a guardrail test. The hook should deny it. Report the hook result and do not try to bypass it.
```

Expected behavior: the hook denies the edit.

### Context Recovery Probe

Create `.agent/state.md` in a disposable repository:

```markdown
# Test State
- Goal: confirm SteadyAgent context recovery
```

Restart or resume the host session in that repository.

Expected behavior: the session-start hook injects the task state into the agent context.

### Normal Work Probe

Ask for a harmless change:

```text
Use SteadyAgent. Add a short note to a temporary README, run the smallest relevant validation, and report changed files, verification, risks, and Git status.
```

Expected behavior: the agent follows the SteadyAgent loop instead of editing silently.

## Common Causes When Hooks Do Not React

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `test-agent-hooks.ps1` passes but live hooks do nothing | Scripts work, but the host did not load the config | Activate the host config and restart the host |
| Codex hooks do not run | Managed manifest is not installed at the active managed config path | Run `enable-codex-hooks.ps1 -Apply` from elevated PowerShell |
| Claude hooks do not run | `settings.hooks.example.json` was not merged into `settings.json` | Merge the `hooks` object and restart Claude Code |
| Hook config still contains `%STEADYAGENT_HOME%` | User copied the template instead of the rendered installed file | Use the rendered file from the host root |
| Existing Codex managed config blocks activation | The enabler refuses to overwrite a different manifest | Merge manually or use `-ForceReplace` after reviewing the backup plan |
| Session keeps old behavior after settings changes | Host session was not restarted | Restart Codex or Claude Code |

## Disable Or Roll Back

Codex:

- Restore the backup created by `enable-codex-hooks.ps1`, or remove the SteadyAgent entries from `%ProgramData%\OpenAI\Codex\requirements.toml`.
- Restart Codex.

Claude Code:

- Restore your backed-up `$HOME\.claude\settings.json`, or remove the SteadyAgent `hooks` object.
- Restart Claude Code.

Installed files under `$HOME\.codex` or `$HOME\.claude` are plain local files. You can inspect them, back them up, or remove them manually.
