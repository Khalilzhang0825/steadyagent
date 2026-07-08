# Release Checklist

Use this checklist before publishing a SteadyAgent v1 tag or GitHub release.

## Required Gates

Run these from a clean repository checkout:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase3.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-runtime-slice.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1
```

The release-readiness gate includes a fresh-clone style workspace snapshot, installer apply check, rendered Codex/Claude config checks, installed hook smoke tests, local Markdown link checks, and public asset checks.

During local WIP before the checkpoint commit, use `-AllowDirty` to validate the current uncommitted release surface. For final release evidence, run the command without `-AllowDirty` from a clean checkout.

## Manual Review

- Confirm `README.md` and `README.zh-CN.md` describe the same v1 surface.
- Confirm `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`, and `RELEASE_NOTES.md` are present.
- Confirm `.github/` templates and the validation workflow are present.
- Confirm the public skill path is `skills/steadyagent-workflow/`.
- Confirm [docs/github-publication-runbook.md](github-publication-runbook.md) is followed before any remote push, PR, tag, or GitHub release.
- Confirm `git diff --check` has no whitespace errors.
- Confirm `git status --short` is clean after the checkpoint commit.
- Do not push, tag, or publish until the maintainer explicitly approves the release.

## Release Evidence To Save

- Validation command outputs.
- Independent review score and findings.
- Checkpoint commit hash.
- PR URL, GitHub Actions URL, release URL, and repository metadata update notes after publication.
- Known limits: Windows-first scripts, host-specific hook differences, no real global host install during automated validation.
