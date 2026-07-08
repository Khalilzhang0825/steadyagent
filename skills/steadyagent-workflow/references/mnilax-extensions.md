# Mnilax Extensions

Use this reference when tasks involve conflicting conventions, flaky tests, long loops, partial failures, or deterministic runtime decisions.

Note: the referenced X post is only directly available through X metadata and a short link in this workspace. The rules below are retained as distilled operating rules, not as verbatim source text.

## Conflict Exposure

When requirements, tests, code patterns, or docs conflict:

- report the conflict
- state the consequences of each path
- ask for a decision or recommend one explicitly
- do not blend incompatible patterns into a third mode

## Behavior Over Test Status

Passing tests are evidence, not the goal.

- Verify the user-visible or system behavior.
- Check important boundaries, not only happy paths.
- Treat weak assertions as insufficient.
- If tests pass but behavior is suspect, report the gap.

## Budget and Checkpoints

Long tasks need explicit stopping points.

- Set checkpoints after diagnosis, plan, implementation, and verification.
- Stop after repeated failure or changed assumptions.
- Summarize what was tried, what failed, and what evidence changed.
- Do not keep looping on the same hypothesis.

## Failure Visibility

Make all incomplete states visible:

- skipped checks
- partial implementation
- unverified assumptions
- flaky or inconclusive tests
- missing dependencies
- permissions or environment blockers

Do not present partial completion as success.

## Deterministic Runtime Decisions

Runtime decisions that must be consistent should live in code or configuration:

- retry policy
- model/tool routing
- thresholds
- permission checks
- escalation paths
- timeout and budget limits

Do not rely on model judgment for deterministic behavior that the system must enforce.
