# Karpathy Guardrails

Use this reference when writing, reviewing, refactoring, or debugging code.

## 1. Think Before Coding

Do not silently choose an interpretation when the task is ambiguous.

- State assumptions.
- Ask when uncertainty blocks correctness.
- Present multiple interpretations when they materially change the solution.
- Push back when a simpler path exists.
- Stop and name confusion instead of coding through it.

## 2. Simplicity First

Write the minimum code that solves the real problem.

- No speculative features.
- No abstraction for single-use code.
- No unrequested configurability.
- No error handling for impossible states.
- If a senior engineer would call it overcomplicated, simplify.

## 3. Surgical Changes

Every changed line should trace to the user's request.

- Do not improve adjacent code, formatting, or comments unless required.
- Do not refactor unrelated code.
- Match existing style.
- Mention unrelated dead code instead of deleting it.
- Remove only the unused imports, variables, or functions created by your own changes.

## 4. Goal-Driven Execution

Convert tasks into verifiable goals.

- "Fix the bug" -> reproduce it, then make the reproduction pass.
- "Add validation" -> test invalid inputs, then implement validation.
- "Refactor X" -> show behavior before and after remains valid.

For multi-step tasks, pair each step with a verification check.

## Signs This Is Working

- Diffs contain fewer unrelated changes.
- The first implementation is simpler.
- Clarifying questions happen before mistakes.
- PRs are smaller and easier to review.
- Success is defined by behavior and evidence, not by activity.
