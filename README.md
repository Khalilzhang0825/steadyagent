# SteadyAgent

**Ship with evidence, not vibes.**

SteadyAgent is a local-first harness for AI coding agents such as Codex and Claude Code. It turns ad-hoc agent chats into a repeatable engineering loop: scope the task, check the repo, make the smallest useful change, verify behavior, review the diff, and checkpoint the result.

[中文说明](README.zh-CN.md)

> Status: v1.0.0 is released. This checkout includes public templates, rules, validation gates, Windows-first tools, the public hook runtime slice, and release-readiness evidence.

## Start Here

If you are new, start with [docs/getting-started.md](docs/getting-started.md). It gives separate paths for a new Codex user, a Claude Code user, both hosts, and read-only evaluation.

If you want to understand the system before installing it, read:

- [docs/how-it-works.md](docs/how-it-works.md) for the architecture and implementation model
- [docs/workflow-examples.md](docs/workflow-examples.md) for real prompts and expected agent behavior
- [docs/tools.md](docs/tools.md) for exact commands
- [docs/hook-runtime.md](docs/hook-runtime.md) for hook lifecycle details

## Why SteadyAgent

AI coding agents are powerful, but they fail in predictable ways:

- they drift from the requested scope
- they edit before understanding the repo
- they claim success without evidence
- they lose context during long tasks
- they run risky shell or Git operations too casually
- they leave humans with no clear audit trail

SteadyAgent wraps the agents you already use with practical workflow guardrails. It does not replace Codex or Claude Code. It makes them easier to trust on real development work.

## Available Today

The current branch gives you:

- a SteadyAgent-first English README
- a Chinese README with the same public positioning
- public Codex and Claude Code templates in `templates/`
- progressive workflow, verification, review, context, and safety rules in `rules/`
- public tools in `tools/`: dry-run installer, Git preflight, checkpoint, hook smoke tests, and guardrail hooks
- beginner onboarding in [docs/getting-started.md](docs/getting-started.md)
- implementation explanation in [docs/how-it-works.md](docs/how-it-works.md)
- practical workflow examples in [docs/workflow-examples.md](docs/workflow-examples.md)
- Windows-first tool documentation in [docs/tools.md](docs/tools.md)
- a hook runtime guide in [docs/hook-runtime.md](docs/hook-runtime.md)
- concise design notes in [docs/design-notes.md](docs/design-notes.md)
- focused validation scripts for the public tools, hook runtime, and release surface
- installer support for copying hook runtime assets and rendering host-specific hook config examples
- a release-readiness gate that validates a fresh workspace snapshot and installed hook runtime
- the packaged `steadyagent-workflow` skill
- release assets: MIT license, contributing guide, security policy, release notes, GitHub issue templates, PR template, and validation workflow
- documented TDD and independent review expectations

## After v1

Future releases can add:

- tested Linux and macOS installers
- more host adapters
- richer examples for team repositories

## The Loop

```text
understand -> plan -> red check -> smallest change -> green check -> review -> checkpoint
```

That loop is the core product. Every file in the repo exists to make one step more reliable.

## Quick Start

From a clean checkout, first verify the public package:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1
```

Preview the install plan for the host you use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex
```

or:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Claude
```

Apply only after reviewing the matching dry-run plan:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex -Apply
```

or:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Claude -Apply
```

Smoke-test the installed hook runtime for the host you installed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\test-agent-hooks.ps1"
```

or:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\tools\test-agent-hooks.ps1"
```

The installer is dry-run by default. It copies host instructions, `rules/`, the `steadyagent-workflow` skill, hook scripts, hook docs, and a rendered hook config example. Add `-Apply` only after reviewing the plan. See [docs/getting-started.md](docs/getting-started.md) for the full beginner path.

To evaluate both host layouts without touching your real host directories, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Both -TargetRoot .\steadyagent-install-preview
```

For smaller scoped checks, run the Phase 3 and hook runtime gates:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase3.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-runtime-slice.ps1
```

See [docs/release-checklist.md](docs/release-checklist.md) before publishing a tag or GitHub release.
For the GitHub push, PR, metadata, and release sequence, use [docs/github-publication-runbook.md](docs/github-publication-runbook.md).

## Safety Model

SteadyAgent separates soft guidance from hard checks:

| Layer | Purpose | Example |
| --- | --- | --- |
| Instructions | Set expectations for the agent | Keep changes scoped, verify behavior, report risks |
| Rules | Load detailed workflow only when needed | Review gates, context recovery, safety boundaries |
| Scripts | Make routine checks deterministic | Git preflight, checkpoint commits, validation gates |
| Hooks | Block risky actions when supported | Dangerous shell commands, secret file edits, risky permission requests |
| Reviews | Catch gaps before checkpointing | Independent score, findings first |

Codex and Claude Code do not expose the same enforcement surfaces, so SteadyAgent documents those differences instead of pretending one setup fits every host.

## Compatibility

SteadyAgent is designed around local developer machines first.

| Host | v1 intent | Enforcement level |
| --- | --- | --- |
| Codex | Instructions, skills, validation scripts, managed hook templates, Git checkpoint workflow | Strong guidance plus managed lifecycle hooks where available |
| Claude Code | Instructions, skills, validation scripts, lifecycle hooks, Git checkpoint workflow | Stronger deterministic enforcement through settings hooks |
| Other coding agents | Reuse the public rules and scripts manually | Best-effort until host-specific adapters exist |

The first public release is Windows-first because the original workflow was proven on Windows and PowerShell. Cross-platform support should be added through tested scripts, not undocumented assumptions.

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

- `tools/validate-release-readiness.ps1` verifies public release assets, Markdown links, fresh workspace installation, rendered host configs, and installed hook smoke tests.
- `tools/validate-phase3.ps1` verifies the public tool surface and installer behavior.
- `tools/validate-runtime-slice.ps1` verifies the hook runtime slice.
- `tools/test-agent-hooks.ps1` sends real hook event JSON through stdin for end-to-end smoke coverage.

See [docs/release-checklist.md](docs/release-checklist.md) for maintainer release checks and [docs/resume-case-study.md](docs/resume-case-study.md) for the project narrative.

## Who This Is For

SteadyAgent is for developers who already use AI coding agents and want a more reliable local workflow before trusting them with larger tasks.

It is especially useful if you care about:

- repo hygiene
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

## License

MIT. See [LICENSE](LICENSE).
