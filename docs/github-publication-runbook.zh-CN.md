# GitHub Publication Runbook

本文件用于本地 release-readiness 通过后、公开 push / tag / GitHub release 前的最终执行。

## 当前远端差距

2026-07-07 只读核对远端状态：

- Remote：当前 `origin` GitHub repository
- 默认分支：`main`
- 公开 `main` 仍显示旧中文 workflow README 和 `zsh-agent-workflow` skill。
- 公开仓库描述仍是旧项目定位。
- 当前没有 GitHub releases。

本地 `codex/steadyagent-v1` 分支包含 SteadyAgent v1 release-candidate 工作。不要直接覆盖远端；推荐通过 branch + PR 保留可审计证据链。

## 必备本地证据

在干净 working tree 根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase3.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-runtime-slice.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\test-agent-hooks.ps1
```

当前期望结果：

- release-readiness：`82/0`
- Phase 3：`89/0`
- runtime slice：`60/0`
- hook smoke：`30/0`
- independent review：`9.7/10`，无 P0/P1/P2/P3

## Maintainer 决策

2026-07-07 已确认：

- License：保留 MIT。
- 仓库名：重命名为 `steadyagent`。
- Release 类型：发布 `v1.0.0`。
- Merge 方式：使用 PR merge commit，保留 checkpoint 证据链。

为了简历证据链，推荐先 push branch、开 PR、等待 GitHub Actions 通过，再用 merge commit 合并，这样阶段 checkpoint 会保留在公开历史里。

## Push And PR

只有得到 maintainer 明确批准后才运行；approval boundary: explicit maintainer approval。

```powershell
git push -u origin codex/steadyagent-v1
```

PR 文案：

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

推荐 GitHub description：

```text
SteadyAgent: a bilingual local-first harness for Codex and Claude Code with workflow rules, safety hooks, validation gates, checkpoint commits, and release evidence.
```

推荐 topics：

```text
ai-agents, coding-agents, codex, claude-code, agents-md, claude-md, developer-tools, powershell, workflow-automation, prompt-engineering
```

仓库重命名目标是 `steadyagent`。GitHub 通常会重定向旧 URL，但重命名后仍要更新本地 `origin` URL、README、release notes 和简历链接。

## Release

只有 maintainer 明确批准 tag/release、版本号、发布类型和目标 commit 后，才可以创建 tag 或 GitHub release。

PR 合并、GitHub Actions 通过且获得上述批准后，创建 release：

```text
Tag: v1.0.0
Title: SteadyAgent v1.0.0
```

Release body：

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

## 发布后检查

- 确认 README 在 GitHub 正常渲染。
- 确认 GitHub Actions 通过。
- 确认 release 页面指向正确 tag。
- 确认 repository description 和 topics 已更新。
- 确认公开页面没有私有路径或本地专属承诺。
- 保存 PR URL、GitHub Actions run URL、release URL、tag、commit hash、repository metadata update notes 和验证输出，作为简历证据链。
