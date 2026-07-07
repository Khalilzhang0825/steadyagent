# Context Management

## Purpose

Keep long-running agent work recoverable after interruption, compaction, or a fresh session.

## Use When

Use this rule for multi-phase work, tasks that may span sessions, or any time the conversation context may be compressed.

## Rules

- Maintain a small `PROJECT_STATE.md` or equivalent state file for long tasks.
- Record only durable facts: goal, scope, decisions, progress, validation, risks, next step, and fact source.
- Update the state file before major phase changes, checkpoint commits, or expected interruption.
- After compaction or interruption, reread the state file and current Git status before continuing.
- Treat summaries as working memory, not the source of truth.
- Keep detailed design notes in docs, not in the always-on template.
- Do not let status files become a timeline dump; update current facts in place.

## Validation

- The state file tells the next agent what phase is active and what to do next.
- The state file references the latest relevant commit or validation result.
- The state file does not contain private paths, secrets, or stale pass counts.
