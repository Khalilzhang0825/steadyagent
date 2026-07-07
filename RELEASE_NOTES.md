# Release Notes

## v1.0.0 Release Candidate

SteadyAgent v1 turns the original personal workflow into a public, bilingual, Windows-first agent harness for Codex and Claude Code.

### Included

- English and Chinese README entrypoints.
- Public Codex and Claude Code templates.
- Progressive workflow, verification, review, context, and safety rules.
- PowerShell tools for dry-run install, Git preflight, checkpoint commits, hook smoke tests, and release validation.
- Public hook runtime scripts for SessionStart, UserPromptSubmit, PreToolUse, PermissionRequest, PostToolUse, and PreCompact.
- Release-readiness gate that validates a fresh workspace snapshot, rendered host configs, installed hook smoke tests, local Markdown links, and public release assets.
- MIT license, contribution guide, security policy, issue templates, PR template, release checklist, and resume case study.

### Known Limits

- The first release is Windows-first and PowerShell-based.
- Codex and Claude Code expose different hook surfaces; the docs describe those differences instead of promising identical enforcement.
- The release gate validates generated config shape and installed hook smoke tests, but it does not install into a user's real global Codex or Claude Code configuration.
