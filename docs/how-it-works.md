# How SteadyAgent Works

SteadyAgent turns a loose AI coding chat into a repeatable local engineering loop:

```text
understand -> plan -> red check -> smallest change -> green check -> review -> checkpoint
```

The project does this by combining short always-on instructions with deeper rules, reusable skills, deterministic scripts, hook examples, and release evidence.

## Mental Model

Think of SteadyAgent as six layers around Codex, Claude Code, or another coding agent. The six public concepts are Instructions, Rules, Skills, Tools, Hooks, and Validation.

| Layer | Files | What it does |
| --- | --- | --- |
| Entry instructions | `AGENTS.md`, `CLAUDE.md`, `templates/` | Gives the host a compact project map and default working rules. |
| Progressive rules | `rules/` | Keeps detailed workflow knowledge out of always-on context until it is needed. |
| Reusable skill | `skills/steadyagent-workflow/` | Packages the workflow as a portable skill with references and agent metadata. |
| Tools | `tools/*.ps1` | Turns repeated checks into deterministic PowerShell commands. |
| Hook runtime | `tools/hooks/`, `templates/*/*hooks*` | Shows how supported hosts can remind, block, or audit lifecycle events. |
| Release evidence | `validate-*`, release docs, GitHub workflow | Proves the public package can be checked, installed, and smoke-tested. |

## Request Lifecycle

When you ask an agent to do work with SteadyAgent, the intended path is:

1. The host loads `AGENTS.md` or `CLAUDE.md`.
2. The agent inspects the repository and nearest relevant docs before editing.
3. For larger work, it reads the matching rule files, such as workflow routing, verification, review gates, context management, or safety boundaries.
4. It runs Git preflight before modifying files.
5. It gives a short plan when the task is complex or risky.
6. It makes the smallest useful change that satisfies the goal.
7. It runs the smallest relevant validation, such as a test, script gate, Markdown check, or hook smoke test.
8. If the change crosses a review gate, a fresh reviewer checks the diff before checkpointing.
9. The task ends with changed files, verification result, remaining risk, and Git status.

## What Each Directory Is For

| Directory or file | Role |
| --- | --- |
| `README.md` and `README.zh-CN.md` | Public entry points and positioning. |
| `docs/getting-started*.md` | Beginner onboarding and first-use commands. |
| `docs/how-it-works*.md` | Architecture and implementation explanation. |
| `docs/workflow-examples*.md` | Real prompt patterns and expected agent behavior. |
| `rules/` | Detailed workflow rules for routing, verification, review, safety, and context recovery. |
| `skills/steadyagent-workflow/` | Reusable workflow bundle for agent hosts that support skills. |
| `templates/codex/` | Codex-specific entry instruction and managed hook config example. |
| `templates/claude/` | Claude Code-specific entry instruction and settings hook config example. |
| `tools/install.ps1` | Dry-run-first installer for host targets. |
| `tools/validate-release-readiness.ps1` | Full public release gate. |
| `tools/validate-phase3.ps1` and `tools/validate-runtime-slice.ps1` | Focused gates for public tools and hook runtime. |
| `tools/test-agent-hooks.ps1` | End-to-end smoke test for hook scripts. |

## Why Instructions Are Short

Long always-on prompts become stale and expensive. SteadyAgent keeps host entry files short, then routes detailed behavior into `rules/`, `skills/`, docs, or scripts.

This gives two benefits:

- New users can understand the surface without reading every internal rule.
- Advanced users can inspect the exact rule or script that governs a behavior.

## Why Scripts Exist

Prompts are useful for judgment, but bad for deterministic checks. SteadyAgent uses scripts for things that should not depend on the model remembering them:

- `git-preflight.ps1` checks repository state before work.
- `git-checkpoint.ps1` stages explicit files and creates a checkpoint commit.
- `validate-release-readiness.ps1` checks the public release surface and fresh install behavior.
- `test-agent-hooks.ps1` sends real hook event JSON through stdin.

The goal is not to remove human judgment. The goal is to make routine safety and quality checks observable.

## How Hooks Fit In

Hooks are optional host integration points. They can provide reminders, context injection, command guards, file guards, permission checks, audit logs, and pre-compact reminders.

Codex and Claude Code do not expose identical hook surfaces:

| Host | SteadyAgent integration |
| --- | --- |
| Codex | Managed hook config example plus instructions, rules, skills, and validation scripts. |
| Claude Code | Settings hook config example plus instructions, rules, skills, and validation scripts. |
| Other agents | Manual reuse of rules and tools until a host-specific adapter exists. |

Hooks are not a complete security boundary. They are one layer in a local workflow that still depends on review, validation, and explicit user approval for risky actions.

## Why Local-First

The first version is local-first because the workflow is meant to improve day-to-day agent-assisted development on a developer machine. Local-first also makes the release easier to audit:

- no cloud account is required to try the workflow
- no credentials are needed for the core tools
- validation can run from a fresh checkout
- installation can be previewed before writing files

## What Remains Human

SteadyAgent does not decide product priorities, guarantee every secret is detected, or replace code review. It makes the agent's process easier to inspect:

- what it understood
- what it changed
- what it verified
- what it skipped
- what risk remains

That audit trail is the core value.
