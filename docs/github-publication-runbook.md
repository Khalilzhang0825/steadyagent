# GitHub Publication Runbook

Use this runbook after local release-readiness passes and before any public push, tag, or GitHub release.

## Current Remote Gap

Read-only remote audit on 2026-07-07:

- Remote: current `origin` GitHub repository
- Default branch: `main`
- Public `main` still shows the legacy Chinese workflow README and `zsh-agent-workflow` skill.
- Public repository metadata still describes the legacy project.
- No GitHub releases are published.

Local branch `codex/steadyagent-v1` contains the SteadyAgent v1 release-candidate work. Do not overwrite remote state casually; publish through an auditable branch and PR.

## Required Local Evidence

Run from a clean working tree:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase3.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-runtime-slice.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\test-agent-hooks.ps1
```

Expected current results:

- release-readiness: `82/0`
- Phase 3: `89/0`
- runtime slice: `60/0`
- hook smoke: `30/0`
- independent review: `9.7/10`, no P0/P1/P2/P3 findings

## Maintainer Decisions

Confirm these before publishing:

- License: keep MIT.
- Repository name: keep `zsh-agent-rules` for continuity or rename to `steadyagent`.
- Release type: publish `v1.0.0` or start with `v1.0.0-rc.1`.
- Merge style: preserve commit history for evidence, or squash for a cleaner `main`.

Recommended path for resume evidence: push the branch, open a PR, let GitHub Actions run, then merge with a merge commit so the phase checkpoints remain visible.

## Push And PR

Only run after explicit maintainer approval:

```powershell
git push -u origin codex/steadyagent-v1
```

Open a PR:

```text
Title: SteadyAgent v1 release candidate

Summary:
- Replaces the legacy personal workflow with SteadyAgent, a bilingual local-first harness for Codex and Claude Code.
- Adds templates, rules, tools, hook runtime scripts, installer flow, packaged skill, release docs, CI, and resume case-study evidence.
- Adds release-readiness validation covering clean-vs-WIP mode, fresh workspace snapshot, rendered configs, installed hook smoke tests, and legacy skill cleanup.

Validation:
- tools/validate-release-readiness.ps1 => 82/0
- tools/validate-phase3.ps1 => 89/0
- tools/validate-runtime-slice.ps1 => 60/0
- tools/test-agent-hooks.ps1 => 30/0
- Independent review => 9.7/10, no P0/P1/P2/P3 findings

Risks:
- Windows-first PowerShell release.
- Automated validation does not write real global Codex or Claude Code configs.
- Legacy installed targets may need explicit `-RemoveLegacySkill` during upgrade.
```

## Repository Metadata

Recommended GitHub description:

```text
SteadyAgent: a bilingual local-first harness for Codex and Claude Code with workflow rules, safety hooks, validation gates, checkpoint commits, and release evidence.
```

Recommended topics:

```text
ai-agents, coding-agents, codex, claude-code, agents-md, claude-md, developer-tools, powershell, workflow-automation, prompt-engineering
```

If renaming the repository, prefer `steadyagent`. GitHub should redirect the old URL, but update README links, release notes, and resume links after the rename.

## Release

Do not create the tag or GitHub release until explicit maintainer approval confirms the tag name, release type, and target commit.

After PR merge, green GitHub Actions, and that approval, create a release:

```text
Tag: v1.0.0
Title: SteadyAgent v1.0.0
```

Release body:

```text
SteadyAgent v1.0.0 turns a personal Codex and Claude Code workflow into a public, bilingual, local-first agent harness.

Included:
- Codex and Claude Code templates
- Progressive workflow, verification, review, context, and safety rules
- PowerShell tools for install, Git preflight, checkpoint commits, and validation
- Public hook runtime scripts and smoke tests
- Packaged steadyagent-workflow skill
- Release-readiness gate with fresh workspace and installed runtime checks
- MIT license, contribution guide, security policy, issue templates, PR template, and CI workflow

Validation:
- release-readiness: 82/0
- Phase 3: 89/0
- runtime slice: 60/0
- hook smoke: 30/0
- independent review: 9.7/10

Known limits:
- Windows-first and PowerShell-first
- Host enforcement differs between Codex and Claude Code
- Automated tests do not modify real global host configuration
```

## Post-Publish Checks

- Confirm README renders on GitHub.
- Confirm GitHub Actions is green.
- Confirm release page links to the correct tag.
- Confirm repository description and topics are updated.
- Confirm no private paths or local-only claims appear in public pages.
- Save PR URL, GitHub Actions run URL, release URL, tag, commit hash, repository metadata update notes, and validation outputs for the resume evidence chain.
