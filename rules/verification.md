# Verification

## Purpose

Verify behavior before claiming completion. Passing a check is evidence, not the goal.

## Use When

Use this rule for code changes, scripts, documentation gates, config changes, release work, or any task where correctness matters.

## Rules

- Choose the narrowest check that proves the relevant behavior.
- Prefer public interfaces and real commands over implementation-detail checks.
- For scripts, run the script and check both exit code and meaningful output.
- For documentation, check links, required sections, copy-paste commands, privacy, and current-vs-planned claims.
- For frontend or visual work, use a browser or screenshot-level check when the result depends on rendering.
- If a check fails, explain the cause before changing direction.
- If a check is skipped, say why it was skipped and give the smallest manual acceptance step.

## Validation

- The final report names each verification command that ran.
- The result includes pass/fail status and the relevant output summary.
- Skipped checks are visible, not hidden.
