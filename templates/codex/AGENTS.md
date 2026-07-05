# AGENTS.md - SteadyAgent Codex Template

Use this file as a copy-ready Codex instruction template. Copy this template together with the `rules/` directory, or adjust the rule paths after copying. Keep it short. Load detailed rules from `rules/` only when the task needs them.

## Core Loop

`understand -> plan -> red check -> smallest change -> green check -> review -> checkpoint`

## Default Behavior

- Start by understanding the user's goal, scope, constraints, likely files, validation path, and risks.
- Prefer repository-local patterns, scripts, tests, and documentation over new abstractions.
- Make the smallest useful change that satisfies the current task.
- Verify behavior with the narrowest relevant check before claiming success.
- Report skipped checks, partial work, blockers, and residual risk explicitly.
- Create a checkpoint after verified work when the user or project workflow expects one.

## When To Load Rules

Load detailed rules from `rules/` as needed:

- `rules/workflow-routing.md` for task triage, scope, conflicts, and phase selection.
- `rules/verification.md` for choosing and reporting checks.
- `rules/review-gates.md` for independent review and scoring.
- `rules/context-management.md` for long tasks, compaction, and recovery state.
- `rules/safety-boundaries.md` for destructive actions, secrets, push, install, and publish boundaries.

## Codex Host Boundary

- Codex instructions are strong guidance, not a full sandbox.
- Codex has no pre-tool hook for blocking every risky shell command before execution.
- Git hooks can still protect commits when configured by the user.
- Do not run destructive Git commands unless the user explicitly asks for that operation.
- Do not write secrets, private credentials, local-only paths, or sensitive vulnerability details into the repository.
- Ask before push, publish, deploy, install dependencies, run migrations, or perform broad file moves.

## Response Shape

- Lead with the conclusion.
- Keep progress updates short: what is being done, why, and what was found.
- Finish with changed files, verification, remaining risk, and Git status.
