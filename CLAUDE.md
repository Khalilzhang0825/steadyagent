# CLAUDE.md - SteadyAgent Claude Code Guide

This file gives Claude Code a compact project map for contributing to SteadyAgent.

## Project Intent

SteadyAgent is a local-first harness for AI coding agents. It turns ad-hoc Codex and Claude Code sessions into a repeatable loop with scoped planning, repository preflight, deterministic checks, lifecycle hooks, independent review, and checkpoint evidence.

## Working Rules

- Start from the relevant files and docs instead of exploring the whole repository.
- Keep always-on guidance short; move detailed workflow knowledge into `rules/`, `skills/`, or `docs/`.
- Prefer scripts and hooks for repeatable checks.
- Preserve host differences honestly: Codex and Claude Code do not expose identical enforcement surfaces.
- Keep public files free of private paths, local credentials, unpublished plans, and maintainer-only state.
- Update English and Chinese documentation together when user-facing behavior changes.

## Validation

Run the smallest relevant gate before committing:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1
```

Focused checks:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase3.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-runtime-slice.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\test-agent-hooks.ps1
```

Use `-AllowDirty` with `validate-release-readiness.ps1` only while reviewing an intentional work-in-progress tree.

## Release Discipline

- Do not publish, retag, or rewrite remote history without explicit maintainer approval.
- Treat each public release as an audited artifact: clean history, reproducible validation, and clear release notes.
- Use [docs/github-publication-runbook.md](docs/github-publication-runbook.md) for public release steps.
