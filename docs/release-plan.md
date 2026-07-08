# Release Plan

## v1.0.0 Release

Goal: publish the first usable SteadyAgent release as a bilingual local-first harness for Codex and Claude Code.

Includes:

- English and Chinese README entrypoints
- Codex and Claude Code templates
- progressive rules
- `steadyagent-workflow` skill
- PowerShell tools and hook runtime scripts
- release-readiness gate
- MIT license, contribution guide, security policy, release notes, GitHub issue templates, PR template, and validation workflow
- release checklist and resume case study

Validation:

- `tools/validate-phase3.ps1`
- `tools/validate-runtime-slice.ps1`
- `tools/validate-release-readiness.ps1`
- independent review score at least 9.5/10 with no P0/P1 findings
- no private paths, secrets, or obsolete product naming in the public release surface

Publish boundary:

- Do not push, tag, or publish until the maintainer explicitly approves.
- Keep v1 Windows-first; cross-platform claims require tested scripts.

## After v1

Potential additions:

- Linux and macOS installers
- host adapters beyond Codex and Claude Code
- example repository
- plugin or marketplace packaging
