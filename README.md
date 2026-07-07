# SteadyAgent

**Ship with evidence, not vibes.**

SteadyAgent is a local-first harness for AI coding agents such as Codex and Claude Code. It turns ad-hoc agent chats into a repeatable engineering loop: scope the task, check the repo, make the smallest useful change, verify behavior, review the diff, and checkpoint the result.

[中文说明](README.zh-CN.md)

> Status: v1 rebuild in progress. This checkout includes public templates, rules, validation gates, Windows-first tools, and the first public hook runtime slice before the final release package.

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

This rebuild is not packaged as an installer yet. The current branch gives you:

- a SteadyAgent-first English README
- a Chinese README with the same public positioning
- public Codex and Claude Code templates in `templates/`
- progressive workflow, verification, review, context, and safety rules in `rules/`
- public tools in `tools/`: dry-run installer, Git preflight, checkpoint, hook smoke tests, and guardrail hooks
- Windows-first tool documentation in [docs/tools.md](docs/tools.md)
- a hook runtime guide in [docs/hook-runtime.md](docs/hook-runtime.md)
- a v1 migration plan in [docs/v1-migration-plan.md](docs/v1-migration-plan.md)
- Phase 0, Phase 1, Phase 2, Phase 3, and hook runtime validation scripts
- installer support for copying hook runtime assets and rendering host-specific hook config examples
- a documented TDD and independent review gate for every phase
- a local checkpoint trail that separates legacy preservation from v1 work

## Planned For v1

The public v1 release is planned to include:

- skill packaging and release readiness checks
- fresh-clone release instructions after the v1 branch is ready to publish

## The Loop

```text
understand -> plan -> red check -> smallest change -> green check -> review -> checkpoint
```

That loop is the core product. Every file in the repo exists to make one step more reliable.

## Quick Start

SteadyAgent is not packaged as an installer yet. If you are reading this from a checkout that contains the v1 rebuild files, the useful first step is to verify the repository narrative and quality gate:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase3.ps1
```

To verify the public hook runtime slice as well:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-runtime-slice.ps1
```

This checkout already includes a dry-run installer, hook templates, and host-specific rendered hook config examples. The public v1 release will add fresh-clone instructions and final release packaging notes.

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

## Current v1 Plan

Completed locally:

1. Phase 0: baseline, migration plan, validation gate, independent review score, and checkpoint commit.
2. Phase 1: README-first public narrative, bilingual entrypoint, and public quality gate.
3. Phase 2: public Codex / Claude templates, progressive rules, and rule quality gate.
4. Phase 3: public tools, dry-run installer, hook smoke test, and Windows-first tool docs.
5. Hook runtime slice: public SessionStart, UserPromptSubmit, PreToolUse, PermissionRequest, PostToolUse, and PreCompact hooks for Codex and Claude Code.
6. Installer runtime integration: dry-run/apply planning for hook scripts, hook docs, and rendered host config examples.

Remaining v1 phases:

1. Skill packaging and release readiness.
2. Fresh-clone release instructions.

See [docs/v1-migration-plan.md](docs/v1-migration-plan.md) for the full plan.

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

License selection is part of the v1 release-readiness phase.
