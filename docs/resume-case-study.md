# Resume Case Study

## Project

SteadyAgent is a bilingual, local-first harness for AI coding agents. It turns a personal Codex and Claude Code workflow into a public toolkit with instructions, progressive rules, validation scripts, lifecycle hooks, checkpoint commits, and release-readiness gates.

## Problem

AI coding agents often fail in ways that look like engineering process failures: unclear scope, edits before diagnosis, unverified success claims, unsafe shell or Git behavior, context loss after long tasks, and weak audit trails.

## Approach

- Split always-on instructions from progressive rules and skills.
- Converted repeated workflow rules into PowerShell scripts and host hook templates.
- Used TDD for repository behavior: each phase added a failing validation gate before implementation.
- Added independent review before checkpoint commits for multi-file or high-risk changes.
- Kept English as the default public surface while maintaining a Chinese mirror for full comprehension.

## Evidence

- Public tool validation gate.
- Public hook runtime gate with installed Codex and Claude smoke tests.
- Release-readiness gate that simulates a fresh workspace snapshot and validates install output.
- Scoped change and release evidence through validation output, release notes, and CI.
- Review score target: no P0/P1 findings and score at least 9.5/10 before checkpoint.

## Resume Bullet

Built SteadyAgent, a bilingual local-first harness for AI coding agents that converts ad-hoc Codex and Claude Code sessions into a repeatable workflow with scoped planning, Git preflight checks, safety hooks, state recovery, validation gates, independent review, and checkpoint commits.

## Interview Talking Points

- Why prompts alone are not enough for reliable agent workflows.
- How scripts and hooks turn repeated rules into deterministic guardrails.
- How TDD can validate documentation, installers, and workflow behavior.
- Why Codex and Claude Code need different enforcement models.
- How release-readiness evidence makes an open-source workflow project credible.
