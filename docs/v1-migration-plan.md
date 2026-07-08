# SteadyAgent v1 Migration Plan

SteadyAgent turns a personal AI coding workflow into a public, testable harness for developers who use Codex, Claude Code, or both.

中文摘要：SteadyAgent 是把个人 AI coding 工作流产品化后的开源 harness，目标不是堆 prompt，而是提供可安装、可验证、可复查的工程闭环。

## Product Positioning

**Name:** SteadyAgent  
**Tagline:** Ship with evidence, not vibes.  
**Category:** Local-first agent harness for AI coding workflows.

SteadyAgent should be presented as a practical control layer around AI coding agents:

- concise always-on instructions
- progressive rules and skills
- preflight checks before edits
- checkpoint commits after verified work
- hard safety guards where the host supports hooks
- recovery state for long tasks
- independent review gates for risky changes

中文定位：面向真实开发任务，减少 AI agent 跑偏、误删、无验证修改、上下文丢失和“看起来完成但不可复查”的问题。

## Bilingual Strategy

English is the default public surface because it maximizes GitHub reach, searchability, and resume value.

Chinese is kept as a first-class mirror, not a partial appendix:

- `README.md` is English-first.
- `README.zh-CN.md` mirrors the core README.
- Every human-facing guide has a paired `.zh-CN.md` file by v1 release.
- Scripts and machine-facing output stay English where possible.
- Personal paths, private preferences, and local-only assumptions are removed or templated.

中文策略：英文负责传播和简历价值，中文负责完整解释、复盘和中文用户上手；两边都要能独立阅读。

## Target Repository Structure

Current v1 release structure:

```text
steadyagent/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   ├── pull_request_template.md
│   └── workflows/
├── README.md
├── README.zh-CN.md
├── LICENSE
├── CONTRIBUTING.md
├── SECURITY.md
├── RELEASE_NOTES.md
├── PROJECT_STATE.md
├── templates/
│   ├── codex/
│   │   ├── AGENTS.md
│   │   └── requirements.managed-hooks.example.toml
│   └── claude/
│       ├── CLAUDE.md
│       └── settings.hooks.example.json
├── rules/
│   ├── README.md
│   ├── README.zh-CN.md
│   ├── workflow-routing.md
│   ├── verification.md
│   ├── review-gates.md
│   ├── context-management.md
│   └── safety-boundaries.md
├── tools/
│   ├── install.ps1
│   ├── git-preflight.ps1
│   ├── git-checkpoint.ps1
│   ├── test-hooks.ps1
│   ├── test-agent-hooks.ps1
│   ├── validate-phase0.ps1
│   ├── validate-phase1.ps1
│   ├── validate-phase2.ps1
│   ├── validate-phase3.ps1
│   ├── validate-runtime-slice.ps1
│   ├── validate-release-readiness.ps1
│   └── hooks/
├── skills/
│   └── steadyagent-workflow/
├── docs/
│   ├── hook-runtime.md
│   ├── hook-runtime.zh-CN.md
│   ├── tools.md
│   ├── tools.zh-CN.md
│   ├── release-checklist.md
│   ├── release-checklist.zh-CN.md
│   ├── resume-case-study.md
│   ├── resume-case-study.zh-CN.md
│   ├── release-plan.md
│   ├── design-notes.md
│   ├── sources.md
│   └── v1-migration-plan.md
```

The old root `AGENTS.md`, `CLAUDE.md`, and legacy workflow skill can be treated as source material, not final v1 architecture.

After v1, separate architecture, safety-model, and troubleshooting guides can be added when they have tested content instead of duplicating the README.

## TDD And Review Gates

Each phase uses one vertical slice:

1. Define a user-visible behavior or repository quality requirement.
2. Add or update the smallest validation check that can fail for that requirement.
3. Run it and confirm RED when appropriate.
4. Implement the smallest change that makes it pass.
5. Run validation.
6. Send the diff to an independent reviewer.
7. Score the phase and iterate until the review gate passes.

Scoring rubric:

- 10: production-quality, clear, verified, no meaningful gaps.
- 9.5: shippable with only explicitly documented minor residual risk.
- 8-9: useful but needs another revision before release.
- below 8: not acceptable for the public repo.

Acceptance gate:

- no P0/P1 findings
- score >= 9.5/10
- validation commands pass
- no private paths, secrets, or local-only assumptions in public files unless clearly templated
- the maintainer can explain the phase as a resume project decision

中文执行原则：每阶段都要有“先失败、再实现、再验证、再独立审查、再修正”的闭环；不是写完文档就算完成。

## Phase Plan

### Phase 0 - Baseline And Migration Plan

Deliverables:

- create a working branch
- tag the old baseline locally
- add `PROJECT_STATE.md`
- add this migration plan
- add a Phase 0 validation script

Validation:

- `tools/validate-phase0.ps1`
- `git status --short --branch`
- independent review score

### Phase 1 - README And Public Narrative

Deliverables:

- rewrite `README.md`
- add `README.zh-CN.md`
- define the first-screen value proposition
- make quick start believable and copy-pasteable

Validation:

- README section checker
- link checker
- reviewer score focused on clarity and user adoption

### Phase 2 - Public Templates And Rules

Deliverables:

- move personal global rules into public templates
- remove private paths and maintainer-specific instructions
- document Codex vs Claude Code differences honestly

Validation:

- path/privacy scan
- template structure check
- reviewer score focused on safety and portability

### Phase 3 - Tools And Hooks

Deliverables:

- publish sanitized scripts
- provide dry-run install
- provide hook tests
- document Windows-first support and cross-platform limits

Validation:

- PowerShell syntax checks
- hook smoke tests
- dry-run install test
- reviewer score focused on operational reliability

### Phase 4 - Skill Packaging And Release Readiness

Deliverables:

- rename and update the skill to `steadyagent-workflow`
- add release notes
- add license, contributing, security, issue and PR templates
- prepare v1 release checklist

Validation:

- skill metadata check
- repository health check
- fresh workspace install check
- final independent release review

## Resume Narrative

Resume-ready project summary:

> Built SteadyAgent, a bilingual local-first harness for AI coding agents that turns personal Codex and Claude Code workflows into a reusable open-source toolkit with preflight checks, safety guards, checkpoint commits, state recovery, verification gates, and independent review loops.

Technical points the maintainer should be able to explain:

- why instructions alone are not enough for reliable agents
- how hooks and scripts turn repeated rules into deterministic guardrails
- how TDD applies to documentation and workflow tooling through observable repository checks
- how bilingual docs increase reach without compromising clarity
- why Codex and Claude Code need different safety models
- how review scoring creates an auditable quality loop before release

中文简历讲法：

> 将自用 AI Coding 工作流重构为开源工具 SteadyAgent，设计了规则分层、脚本化预检、提交检查、安全拦截、长任务状态恢复、验证门禁和独立审查评分流程，解决 AI agent 在真实开发中的跑偏、误操作、上下文丢失和不可验证交付问题。
