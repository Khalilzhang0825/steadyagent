# Safety Boundaries

## Purpose

Make dangerous actions explicit. SteadyAgent should reduce accidental damage from agents, not hide risk behind confident language.

## Use When

Use this rule before destructive operations, file moves, installs, dependency changes, migration work, publishing, pushing, secret handling, or hook changes.

## Rules

- Do not run destructive Git commands unless the user explicitly asks for that operation.
- Do not push, publish, deploy, install dependencies, or run migrations without explicit confirmation.
- Do not write secrets, credentials, private keys, local-only paths, or sensitive vulnerability details into public files.
- Prefer dry-run behavior before copying files into a user's agent configuration.
- Keep temporary work reversible and document how to verify and remove it.
- Codex and Claude Code have different enforcement surfaces. Codex may rely more on model discipline and Git hooks; Claude Code can add lifecycle hooks when configured.
- Hooks should block stable, deterministic risks. They should not replace engineering judgment.
- Public templates must not assume a private machine layout, a specific username, or a hidden local script.

## Validation

- Public files pass privacy and secret scans.
- Risky actions were either avoided or explicitly confirmed.
- Host-specific limits are documented instead of implied.
