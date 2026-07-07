# Claude Code Practices

Use this reference for Claude Code workflows, HTML artifacts, CLAUDE.md design, subagents, code review, tool design, and large codebases.

## System Model

Claude Code works best as an agentic engineering harness, not as a chat box. The model needs:

- navigable context
- useful tools
- clear task boundaries
- verification loops
- output surfaces humans can inspect
- periodic cleanup of stale rules and tools

## HTML Artifacts

Use HTML instead of Markdown when the output needs dense structure, comparison, interaction, or sharing:

- implementation plans with diagrams and acceptance criteria
- PR or diff explainers with severity annotations
- technical reports and incident reviews
- design prototypes and component state sheets
- temporary editors for JSON, feature flags, ticket sorting, prompts, or configs

HTML is useful only when it improves reading, comparison, interaction, export, or verification. Short answers and simple lists should remain Markdown.

## CLAUDE.md Design

A strong CLAUDE.md is a short persistent map:

- project purpose and key directories
- common commands
- testing and linting entry points
- local conventions
- dangerous areas or gotchas
- workflow expectations

Do not put low-frequency documentation into CLAUDE.md. Link to docs or use skills/references for progressive disclosure. In large repositories, root CLAUDE.md should contain the global map; subdirectory CLAUDE.md files should contain local conventions and commands.

## Subagents

Use subagents for:

- reading many files and returning a synthesis
- parallel independent tasks
- unbiased review with fresh context
- staged pipelines such as research -> plan -> implementation -> testing

Avoid subagents for:

- small tasks
- strongly sequential work
- parallel edits to the same file
- tasks requiring direct coordination between agents

Good subagent prompts specify scope, permissions, whether work can run in parallel, output format, and whether fresh context is required.

## Code Review

Agent review should increase depth, not replace human approval. It is most valuable for:

- authentication
- encryption
- payments
- migrations
- caching
- concurrency
- permission boundaries
- high-risk large PRs

Review output should report actionable findings with severity, impact, evidence, and suggested verification.

## Tool Design

Design tools from the model's point of view:

- Prefer structured tools when free-form output is unreliable.
- Keep tool count low; every tool increases selection cost.
- Use progressive disclosure for low-frequency knowledge.
- Revisit tools after model upgrades; old compensating rules can become constraints.

## Large Codebases

Large-codebase success depends on the harness:

- layered CLAUDE.md files
- ignored generated/vendor/build files
- local test/lint commands
- lightweight code maps when directories are unclear
- LSP for symbol navigation
- MCP for internal systems and structured data
- subagents for isolated exploration
- ownership and governance for shared rules and plugins

Start in the relevant subdirectory when possible. Avoid full-suite checks when a scoped check is enough.
