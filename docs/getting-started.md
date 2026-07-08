# Getting Started

Use this guide if you have just installed Codex or Claude Code and do not know where SteadyAgent fits.

SteadyAgent is not another chat app. It is a local workflow harness that installs instructions, rules, a reusable skill, validation scripts, and hook examples into the agent host you already use.

## Requirements

- Windows with PowerShell.
- Git.
- A local checkout of this repository.
- Codex, Claude Code, or both.

Cross-platform installers are not claimed in v1. The public scripts are Windows-first because this is the environment that has been tested end to end.

## Pick Your Path

| You are | Start with |
| --- | --- |
| New to Codex | [New to Codex path](#new-to-codex-path) |
| Already using Claude Code | [Claude Code path](#claude-code-path) |
| Using both hosts | [Both hosts path](#both-hosts-path) |
| Evaluating before installing | [Learn first path](#learn-first-path) |

## New to Codex Path

1. Open PowerShell in the SteadyAgent repository.
2. Validate the checkout:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1
```

3. Preview what would be installed for Codex:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex
```

4. Review the `DRY-RUN` output. It should show `WOULD copy` and `WOULD render` lines. No files are written during this step.
5. Apply only after the plan looks right:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex -Apply
```

6. Smoke-test the installed hook runtime:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\test-agent-hooks.ps1"
```

7. Start Codex in the repository where you want to work. If your host does not automatically load the installed instructions, paste this first prompt:

```text
Use the SteadyAgent workflow for this repository. First inspect the repo and the relevant docs, then give me a short plan before edits. After edits, run the smallest relevant validation and report changed files, verification, risks, and Git status.
```

## Claude Code Path

1. Preview the Claude Code install:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Claude
```

2. Apply after reviewing the dry-run plan:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Claude -Apply
```

3. Smoke-test the installed hook runtime:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\tools\test-agent-hooks.ps1"
```

4. Merge the rendered hook settings into your Claude Code settings only after you understand the generated file. See [hook-runtime.md](hook-runtime.md) for the hook lifecycle and safety boundaries.

## Both Hosts Path

Preview a separated install tree first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Both -TargetRoot .\steadyagent-install-preview
```

When you are ready to install into the default host roots, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Both -Apply
```

The default roots are `$HOME\.codex` for Codex and `$HOME\.claude` for Claude Code. If files already exist, the installer refuses to overwrite them unless you pass `-Overwrite`. Review existing files before doing that.

## Learn First Path

Read these in order:

1. [how-it-works.md](how-it-works.md): what SteadyAgent installs and why each layer exists.
2. [workflow-examples.md](workflow-examples.md): prompts for bug fixes, features, reviews, long tasks, and release checks.
3. [tools.md](tools.md): exact commands and tool behavior.
4. [hook-runtime.md](hook-runtime.md): lifecycle hook examples and what they can or cannot enforce.

## What Gets Installed

| Installed item | Purpose |
| --- | --- |
| `AGENTS.md` or `CLAUDE.md` | Short always-on instructions for the selected host. |
| `rules/` | Progressive workflow, verification, review, context, and safety rules. |
| `skills/steadyagent-workflow/` | A reusable workflow skill with references and agent metadata. |
| `tools/hooks/agent-hook-*.ps1` | Public hook scripts for reminders, context injection, command checks, file checks, permission checks, audit logging, and pre-compact reminders. |
| `tools/test-agent-hooks.ps1` | A smoke test for the installed hook runtime. |
| Rendered hook config example | A host-specific config file with the selected install root substituted in place of `%STEADYAGENT_HOME%`. |

## Daily Use

For normal work, ask your agent for the outcome you want, then expect SteadyAgent to shape the process:

```text
Fix the failing login test. Use SteadyAgent: inspect first, keep the change scoped, run the smallest relevant validation, and checkpoint only after review.
```

The agent should report:

- what it changed
- what it ran to verify the change
- any remaining risk
- Git status

## Troubleshooting

- If PowerShell blocks a script, use `-ExecutionPolicy Bypass` as shown in the examples.
- If install fails because a target already exists, run the dry-run again and compare the existing files before using `-Overwrite`.
- If a host does not load global instructions automatically, paste the first prompt from this guide at the start of the task.
- If hook behavior is unclear, run `tools/test-agent-hooks.ps1` in the installed target root and read [hook-runtime.md](hook-runtime.md).
