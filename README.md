# SteadyAgent

**Ship with evidence, not vibes.**

SteadyAgent is a local-first workflow harness for AI coding agents such as Codex and Claude Code. It turns loose agent chats into a repeatable engineering loop: understand the task, inspect the repository, plan the change, make the smallest useful edit, verify behavior, review the result, and checkpoint the work.

[中文说明](README.zh-CN.md)

> Status: v1.0.0 is released. This checkout includes public templates, progressive rules, validation gates, Windows-first tools, hook runtime assets, host activation docs, and release-readiness evidence.

## Start Here

If you are new, start with [docs/getting-started.md](docs/getting-started.md). It gives separate paths for new Codex users, Claude Code users, dual-host users, and people who want to evaluate before installing.

Use this map to choose the right entry point:

| Need | Read this |
| --- | --- |
| Install SteadyAgent for the first time | [docs/getting-started.md](docs/getting-started.md) |
| Understand what every feature maps to | [docs/feature-map.md](docs/feature-map.md) |
| Make Codex or Claude Code hooks actually run | [docs/activation-guide.md](docs/activation-guide.md) |
| Understand the architecture | [docs/how-it-works.md](docs/how-it-works.md) |
| Try real prompts | [docs/workflow-examples.md](docs/workflow-examples.md) |
| Look up exact commands | [docs/tools.md](docs/tools.md) |
| Understand hook lifecycle behavior | [docs/hook-runtime.md](docs/hook-runtime.md) |

## What SteadyAgent Solves

AI coding agents are useful, but they fail in predictable ways:

- they edit before understanding the repository
- they drift from the requested scope
- they claim completion without running checks
- they lose task state during long sessions
- they treat risky shell or Git commands too casually
- they leave weak evidence for humans to review later

SteadyAgent wraps the agent you already use with a local workflow, deterministic scripts, optional hooks, and release checks. It is not a new model, a cloud service, or a replacement for human review.

## The Core Loop

```text
understand -> plan -> red check -> smallest change -> green check -> review -> checkpoint
```

Every public file in this repository supports one part of that loop.

| Loop step | SteadyAgent support |
| --- | --- |
| Understand | Short host instructions plus progressive rules. |
| Plan | Workflow routing and scoped task planning. |
| Red check | Reproduce or identify observable evidence before editing. |
| Smallest change | Rules that keep edits focused. |
| Green check | Validation scripts, tests, lint, docs checks, or hook smoke tests. |
| Review | Independent review gates before checkpointing risky or multi-file work. |
| Checkpoint | Explicit Git checkpoint workflow with scoped file staging. |

## Available Today

The current release includes:

- Codex and Claude Code entry templates in `templates/`
- progressive workflow, verification, review, context, and safety rules in `rules/`
- the packaged `steadyagent-workflow` skill in `skills/steadyagent-workflow/`
- Windows-first PowerShell tools in `tools/`
- a dry-run installer in `tools/install.ps1`
- hook smoke test coverage through `tools/test-agent-hooks.ps1`
- public hook scripts in `tools/hooks/`
- install diagnosis through `tools/diagnose-install.ps1`
- Codex managed-hook activation through `tools/enable-codex-hooks.ps1`
- release-readiness validation through `tools/validate-release-readiness.ps1`
- beginner, architecture, activation, feature-map, tool, and workflow-example docs in `docs/`
- release assets: MIT license, contributing guide, security policy, release notes, issue templates, PR template, and GitHub validation workflow

## Quick Start

From a clean checkout, first verify the public package:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1
```

For the focused public tool surface check:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase3.ps1
```

Preview the install plan for both hosts without touching your real host directories:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Both -TargetRoot .\steadyagent-install-preview
```

Preview the install plan for Codex:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex
```

Preview the install plan for Claude Code:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Claude
```

Apply only after reviewing the dry-run output:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex -Apply
```

or:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Claude -Apply
```

Smoke-test the installed hook runtime:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\test-agent-hooks.ps1"
```

or:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\tools\test-agent-hooks.ps1"
```

That smoke test proves the hook scripts work. It does not prove the host has loaded them. To make live hooks react inside Codex or Claude Code, complete host activation and restart the host.

For Codex, preview activation first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\enable-codex-hooks.ps1"
```

Then run it from an elevated PowerShell session with `-Apply` after reviewing the plan.

Claude Code users should merge `$HOME\.claude\settings.hooks.example.json` into `$HOME\.claude\settings.json`, then restart Claude Code.

After activation, diagnose the complete setup:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\diagnose-install.ps1" -HostTarget Both -RequireHooksActive
```

## How To Use It Day To Day

Open your project in Codex or Claude Code and ask for the outcome you want. Add `Use SteadyAgent` when you want the agent to follow this harness explicitly:

```text
Use SteadyAgent. Fix the failing login test. Inspect the repo first, keep the change scoped, run the smallest relevant validation, and report changed files, verification, risks, and Git status.
```

Expected behavior:

- the agent inspects the repository before editing
- complex or risky work gets a short plan first
- the change stays scoped to the task
- validation is run before completion is claimed
- remaining risk and Git status are reported
- risky shell, file, and permission actions can be blocked when hooks are active

## Activation vs Installation

Installation copies files. Activation makes the host load hook config.

| State | What works |
| --- | --- |
| Installed only | Entry instructions, rules, skill files, scripts, docs, and hook smoke tests. |
| Activated and restarted | Live hook reminders, command guard, file guard, permission guard, audit log, and pre-compact reminders. |

Use [docs/activation-guide.md](docs/activation-guide.md) when a user says hooks do not react after installing.

## Main Commands

| Command | Purpose |
| --- | --- |
| `tools/install.ps1` | Preview or apply host installation. |
| `tools/diagnose-install.ps1` | Check installed files, rendered configs, active host config, and hook smoke tests. |
| `tools/enable-codex-hooks.ps1` | Safely install Codex managed hooks with dry-run, backup, and elevated-write checks. |
| `tools/test-agent-hooks.ps1` | Send real hook event JSON through stdin and verify hook script behavior. |
| `tools/git-preflight.ps1` | Check repository state before work. |
| `tools/git-checkpoint.ps1` | Create explicit scoped checkpoint commits. |
| `tools/validate-release-readiness.ps1` | Validate public release assets, links, fresh install, diagnostics, and hook runtime behavior. |

See [docs/tools.md](docs/tools.md) for command details.

## Project Map

| Path | Role |
| --- | --- |
| `AGENTS.md` | Compact contributor guide for Codex inside this repository. |
| `CLAUDE.md` | Compact contributor guide for Claude Code inside this repository. |
| `templates/codex/` | Installable Codex entry instructions and managed-hook manifest example. |
| `templates/claude/` | Installable Claude Code entry instructions and settings hook example. |
| `rules/` | Progressive workflow rules for routing, verification, review, context, and safety. |
| `skills/steadyagent-workflow/` | Portable workflow skill with references and agent metadata. |
| `tools/` | Installer, diagnostics, Git helpers, validation gates, and hook smoke tests. |
| `tools/hooks/` | Public lifecycle hook scripts. |
| `docs/` | User guides, implementation explanation, activation guide, feature map, examples, release docs. |

## Safety Model

SteadyAgent separates guidance from enforcement:

| Layer | Purpose | Example |
| --- | --- | --- |
| Instructions | Set default agent behavior | Keep changes scoped, verify behavior, report risks. |
| Rules | Load deeper workflow only when needed | Review gates, context recovery, safety boundaries. |
| Scripts | Make repeated checks deterministic | Git preflight, checkpoint commits, release validation. |
| Hooks | Block or audit supported lifecycle events | Dangerous shell commands, secret-file edits, permission requests. |
| Reviews | Catch gaps before checkpointing | Findings-first independent review. |

Hooks are useful but not a complete security boundary. They reduce common mistakes. Human review and explicit approval still matter.

## Compatibility

SteadyAgent is designed around local developer machines first.

| Host | v1 intent | Enforcement level |
| --- | --- | --- |
| Codex | Instructions, skills, validation scripts, managed hook templates, Git checkpoint workflow | Strong guidance plus managed lifecycle hooks where available. |
| Claude Code | Instructions, skills, validation scripts, lifecycle hooks, Git checkpoint workflow | Stronger deterministic enforcement through settings hooks. |
| Other coding agents | Manual reuse of public rules and scripts | Best-effort until host-specific adapters exist. |

The first public release is Windows-first because the original workflow was proven on Windows and PowerShell. Linux and macOS support should be added through tested scripts, not README promises.

## What SteadyAgent Is Not

SteadyAgent is not:

- a new coding agent
- a model router
- a cloud orchestration platform
- a replacement for human review
- a security product that can guarantee secret detection
- a promise that every host can enforce the same rules

It is a practical harness for making local AI coding work more observable, safer, and easier to recover.

## Release Evidence

The v1.0.0 release is built around reproducible checks:

- `tools/validate-release-readiness.ps1` verifies release assets, Markdown links, fresh workspace installation, rendered host configs, install diagnostics, and installed hook smoke tests.
- `tools/validate-phase3.ps1` verifies the public tool surface and installer behavior.
- `tools/validate-runtime-slice.ps1` verifies the hook runtime slice.
- `tools/test-agent-hooks.ps1` sends real hook event JSON through stdin for smoke coverage.
- `tools/diagnose-install.ps1` checks whether installed assets and active host hook config are present.
- `tools/enable-codex-hooks.ps1` safely installs the Codex managed hook manifest with dry-run, backup, and elevated-write checks.

See [docs/release-checklist.md](docs/release-checklist.md) for maintainer release checks and [docs/github-publication-runbook.md](docs/github-publication-runbook.md) for GitHub push, PR, metadata, tag, and release steps.

## Who This Is For

SteadyAgent is for developers who already use AI coding agents and want a more reliable local workflow before trusting them with larger tasks.

It is especially useful if you care about:

- repository hygiene
- scoped changes
- reproducible verification
- safer Git operations
- long-task continuity
- reviewable evidence

## Design Principles

- Keep always-on context short.
- Turn repeated workflow rules into scripts or hooks.
- Verify behavior, not confidence.
- Make incomplete work visible.
- Prefer local-first control before cloud automation.
- Treat every public release as an audited artifact.

## Resume Case Study

SteadyAgent is also a case study in harness engineering: designing the environment around coding agents so they can operate with clearer scope, safer tools, stronger verification, and better human oversight.

See [docs/resume-case-study.md](docs/resume-case-study.md) for the project narrative.

## License

MIT. See [LICENSE](LICENSE).
