# Review Gates

## Purpose

Use review to catch gaps that implementation momentum hides. Self-review is useful, but it is not a substitute for independent review when risk is material.

## Use When

Use this rule before checkpointing multi-file changes, scripts, hooks, safety rules, release changes, public docs, or any work the user asks to have reviewed.

## Rules

- Request independent review before checkpointing risky or multi-file work.
- Review must be read-only unless explicitly assigned a separate write scope.
- Review output should be Findings first, ordered by severity.
- Each finding should include severity, location, problem, impact, and suggested fix.
- The default gate is no P0/P1 findings and score >= 9.5.
- Treat 8-9 as useful but not ready for public release.
- Handle actionable findings, rerun validation, then request incremental review if needed.
- If review tooling is unavailable, state that limitation and do not pretend the gate passed.

## Validation

- The final report includes the review score or explains why review could not run.
- All P0/P1 findings are fixed or the task is not marked complete.
- Residual testing gaps and risks are explicit.
