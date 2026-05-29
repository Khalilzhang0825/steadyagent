# Design Notes

## Why Two Guideline Files

Codex and Claude Code share the same operating principles, but their platform affordances differ.

- `AGENTS.md` emphasizes Codex workspace behavior, local tools, `rg`, and minimal file reads.
- `CLAUDE.md` emphasizes Claude Code context layering, subdirectory startup, skills, hooks, MCP, LSP, and large-codebase harness design.

The shared rules should remain aligned. Platform differences should be isolated to platform sections.

## Why Not Put Everything In AGENTS.md / CLAUDE.md

Always-on instructions compete for context. Long permanent rules reduce signal and make future drift harder to manage.

The split is:

- Always-on rules: `AGENTS.md` and `CLAUDE.md`
- Reusable workflow: `SKILL.md`
- Detailed knowledge: `references/`
- Human-facing project notes: `docs/`

## Why Use References

References implement progressive disclosure. The agent reads detailed knowledge only when the task needs it.

Examples:

- HTML artifact work reads `claude-code-practices.md`.
- Refactoring or code review reads `karpathy-guardrails.md`.
- Long loops or conflicting conventions read `mnilax-extensions.md`.

## Why First Release Is Not A Plugin

The first release should be simple and inspectable:

- copyable AGENTS.md
- copyable CLAUDE.md
- installable skill folder
- readable references

Plugin packaging can come after the workflow proves useful.
