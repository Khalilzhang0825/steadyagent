# SteadyAgent Feature Map

This page maps each user-facing SteadyAgent feature to the files that implement it, where it lands after install, how a user triggers it, and how to verify it.

Use this page when you want to answer one question: "Is this feature only documented, or is there an actual implementation behind it?"

## Quick Reading

| Feature | Implementation files | Installed location | Trigger | Verification |
| --- | --- | --- | --- | --- |
| Codex entry instructions | `templates/codex/AGENTS.md` | `$HOME\.codex\AGENTS.md` | Start Codex or ask the agent to use SteadyAgent | Ask Codex to explain its working rules for the repo |
| Claude Code entry instructions | `templates/claude/CLAUDE.md` | `$HOME\.claude\CLAUDE.md` | Start Claude Code | Ask Claude Code to explain its working rules for the repo |
| Progressive workflow rules | `rules/*.md` | `$HOME\.codex\rules\` or `$HOME\.claude\rules\` | Ask for implementation, review, verification, context recovery, or safety-sensitive work | Confirm the agent reads the relevant rule before edits |
| Reusable workflow skill | `skills/steadyagent-workflow/` | `<host-root>\skills\steadyagent-workflow\` | Invoke the skill in a host that supports skills, or ask the agent to use the SteadyAgent workflow | Confirm `SKILL.md` exists and the host can route to it |
| Dry-run installer | `tools/install.ps1` | Runs from the repository checkout | `tools/install.ps1 -HostTarget Codex`, `Claude`, or `Both` | Output starts with `DRY-RUN` and writes no files |
| Installed asset copy | `tools/install.ps1` | Selected host root | Re-run installer with `-Apply` after reviewing dry-run output | Expected files exist under the host root |
| Git preflight | `tools/git-preflight.ps1` | Repository tool, not copied by the installer | Run before file edits | Prints repo root, branch, remotes, status, identity, and ignore checks |
| Git checkpoint | `tools/git-checkpoint.ps1` | Repository tool, not copied by the installer | Run after validation with explicit `-Files` | Creates a commit using only named files |
| Hook runtime scripts | `tools/hooks/agent-hook-*.ps1` | `<host-root>\tools\hooks\` | Host lifecycle events after hooks are activated | `tools/test-agent-hooks.ps1` reports `0 failed` |
| Codex managed hook manifest | `templates/codex/requirements.managed-hooks.example.toml` | `$HOME\.codex\requirements.managed-hooks.example.toml` | Run `tools/enable-codex-hooks.ps1 -Apply` from an elevated PowerShell session | `tools/diagnose-install.ps1 -HostTarget Codex -RequireHooksActive` |
| Claude Code hook settings example | `templates/claude/settings.hooks.example.json` | `$HOME\.claude\settings.hooks.example.json` | Merge into `$HOME\.claude\settings.json`, then restart Claude Code | `tools/diagnose-install.ps1 -HostTarget Claude -RequireHooksActive` |
| Install diagnostics | `tools/diagnose-install.ps1` | `<host-root>\tools\diagnose-install.ps1` | Run after installing and activating hooks | Prints pass, warn, and fail counts for assets, config, and hook smoke tests |
| Codex hook activation helper | `tools/enable-codex-hooks.ps1` | `$HOME\.codex\tools\enable-codex-hooks.ps1` | Preview by default, then run with `-Apply` from elevated PowerShell | Managed config file exists and contains SteadyAgent hook entries |
| Hook smoke test | `tools/test-agent-hooks.ps1` | `<host-root>\tools\test-agent-hooks.ps1` | Run manually after install | Reports each hook behavior and ends with `0 failed` |
| Release readiness gate | `tools/validate-release-readiness.ps1` | Repository tool | Run before release or public changes | Checks release files, docs, links, install, diagnostics, and hook smoke tests |
| Public validation workflow | `.github/workflows/validate.yml` | GitHub Actions | Push or PR on GitHub | Windows workflow runs the release-readiness gate |

## Feature Details

### Entry Instructions

SteadyAgent keeps host entry instructions short. Codex receives `AGENTS.md`; Claude Code receives `CLAUDE.md`.

The files tell the agent to keep changes scoped, read relevant docs before editing, verify behavior, report risk, and respect release boundaries. They do not contain every rule. They point the agent to `rules/`, docs, tools, and validation scripts.

### Rules

The `rules/` directory is the deeper operating manual:

| Rule file | Purpose |
| --- | --- |
| `workflow-routing.md` | Chooses the right work mode: diagnosis, implementation, review, release, or long-task recovery. |
| `verification.md` | Defines how to prove work is actually done. |
| `review-gates.md` | Decides when independent review is required before checkpointing. |
| `context-management.md` | Handles long tasks, compaction, resume, and task state files. |
| `safety-boundaries.md` | Defines risky operations that need explicit approval or hard blocking. |

The trigger is a user request. For example, a bug fix should cause the agent to inspect first, reproduce or find evidence, change the smallest useful surface, run validation, and report residual risk.

### Skill

`skills/steadyagent-workflow/` packages the same workflow as a reusable skill for hosts that support skills. It includes a `SKILL.md`, references, and agent metadata.

The installed path is:

```text
<host-root>\skills\steadyagent-workflow\
```

The skill is useful when a host supports skill routing. If the host does not support skills, the same workflow is still available through instructions, docs, rules, and scripts.

### Tools

Tools make repeatable behavior observable:

| Tool | What it proves |
| --- | --- |
| `install.ps1` | The package can be installed without hand-copying files. |
| `diagnose-install.ps1` | The local host root has the expected files and active hook config. |
| `enable-codex-hooks.ps1` | Codex managed hooks can be activated without silently overwriting existing config. |
| `git-preflight.ps1` | The agent sees repository state before editing. |
| `git-checkpoint.ps1` | Checkpoints are explicit and scoped to named files. |
| `test-agent-hooks.ps1` | Hook scripts behave correctly when fed real hook event JSON. |
| `validate-release-readiness.ps1` | The public package can be validated from a fresh workspace snapshot. |

### Hooks

Hook scripts are implementation, not just documentation. They live under `tools/hooks/` and cover these lifecycle events:

| Event | Script | Behavior |
| --- | --- | --- |
| `SessionStart` | `agent-hook-context.ps1` | Injects a compact reminder and restores `PROJECT_STATE.md` or `.agent/state.md` on resume or compact. |
| `UserPromptSubmit` | `agent-hook-prompt-reminder.ps1` | Adds risk-specific reminders for push, release, delete, install, and similar requests. |
| `PreToolUse` | `agent-hook-command-guard.ps1` | Denies known risky shell and Git commands. |
| `PreToolUse` | `agent-hook-file-guard.ps1` | Denies edits to secret-like files while allowing safe examples. |
| `PermissionRequest` | `agent-hook-permission-guard.ps1` | Denies known dangerous escalation requests. |
| `PostToolUse` | `agent-hook-posttool-audit.ps1` | Records compact audit logs with redacted command text and command hashes. |
| `PreCompact` | `agent-hook-precompact.ps1` | Reminds the agent to preserve task state before compaction. |

`test-agent-hooks.ps1` validates the scripts directly. Host activation is a separate step and is checked by `diagnose-install.ps1`.

## What Requires Host Activation

These features work after installation alone:

- entry instructions copied to the host root
- rules and skill files available on disk
- installer dry-run and apply
- hook script smoke tests
- repository validation gates

These features require host activation and a restarted host session:

- Codex managed lifecycle hooks
- Claude Code settings hooks
- real-time command guards
- real-time file guards
- permission request guards
- tool audit logging from live host events
- pre-compact reminders from live host events

That separation matters. A passing hook smoke test proves the scripts work. It does not prove the host has registered those scripts. Use [activation-guide.md](activation-guide.md) for the full activation path.
