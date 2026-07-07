# SteadyAgent

**Ship with evidence, not vibes.**  
**用证据交付，而不是凭感觉相信 AI agent。**

SteadyAgent 是一个 local-first 的 AI coding agent 工作流 harness，面向 Codex、Claude Code 等工具。它把随意的 agent 对话变成可复用的工程闭环：明确范围、检查仓库、做最小有效改动、验证行为、独立审查、创建 checkpoint。

[English README](README.md)

> 状态：v1 正在重构中。当前 checkout 已包含公开模板、规则、验证门、Windows-first 工具和第一条公开 hook runtime 纵切，最终 release package 仍在后续阶段完成。

## 为什么需要 SteadyAgent / Why SteadyAgent

AI coding agents 很强，但常见失败模式很稳定：

- 偏离用户要求的范围
- 没理解仓库就开始改
- 没有证据也声称完成
- 长任务或压缩后丢上下文
- 过于随意地执行高风险 shell / Git 操作
- 留不下清晰的审计轨迹

SteadyAgent 不替代 Codex 或 Claude Code。它是在这些 agent 外面加一层可解释、可验证、可复查的工程工作流。

## 当前可用 / Available Today

当前重构分支已经有 dry-run installer，但还没有打包成发布版安装器。现在已经可用的是：

- SteadyAgent-first 的英文 README
- 和英文定位一致的中文 README
- `templates/` 中的 Codex 和 Claude Code 公开模板
- `rules/` 中的 workflow、verification、review、context 和 safety 渐进规则
- `tools/` 中的 dry-run 安装器、Git preflight、checkpoint、hook smoke tests 和 guardrail hooks
- [docs/tools.zh-CN.md](docs/tools.zh-CN.md) 中的 Windows-first 工具说明
- [docs/hook-runtime.zh-CN.md](docs/hook-runtime.zh-CN.md) 中的 hook runtime 说明
- [docs/v1-migration-plan.md](docs/v1-migration-plan.md) 中的 v1 迁移计划
- Phase 0、Phase 1、Phase 2、Phase 3 和 hook runtime 验证脚本
- installer 已支持复制 hook runtime assets，并渲染按目标路径生成的 hook config examples
- 每个阶段都要经过 TDD 和 independent review 的质量门
- 能区分旧版保护和 v1 迭代的本地 checkpoint 轨迹

## v1 计划交付 / Planned For v1

公开 v1 计划包含：

- skill packaging 和 release readiness 检查
- v1 分支可发布后的 fresh-clone instructions

## 核心闭环 / The Loop

```text
understand -> plan -> red check -> smallest change -> green check -> review -> checkpoint
```

这个闭环就是 SteadyAgent 的核心产品。仓库里的每个文件都应该服务于其中一个环节。

## 快速开始 / Quick Start

SteadyAgent 当前 not packaged as an installer yet。如果你看到的是包含 v1 重构文件的 checkout，现在最有用的第一步，是验证仓库叙事和 Phase 3 质量门：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase3.ps1
```

如果还要验证公开 hook runtime 纵切：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-runtime-slice.ps1
```

当前 checkout 已包含 dry-run 安装器、hook templates，以及按目标路径渲染的 host-specific hook config examples。公开 v1 会加入 fresh-clone instructions 和最终 release packaging notes。

## 安全模型 / Safety Model

SteadyAgent 把提示约束和硬检查分开：

| 层级 | 作用 | 示例 |
| --- | --- | --- |
| Instructions | 给 agent 设置常驻期望 | 控制改动范围、验证行为、报告风险 |
| Rules | 按需加载细则 | 审查门、上下文恢复、安全边界 |
| Scripts | 把重复检查变成确定性命令 | Git 预检、checkpoint、验证门 |
| Hooks | 宿主支持时拦截高风险动作 | 危险命令、密钥文件编辑、危险权限请求 |
| Reviews | checkpoint 前发现缺口 | 独立评分、findings first |

Codex 和 Claude Code 的可强制执行能力不同，所以 SteadyAgent 会明确说明差异，不假装一套配置能覆盖所有宿主。

## 兼容性 / Compatibility

SteadyAgent 优先面向本地开发机器。

| 宿主 | v1 目标 | 强制能力 |
| --- | --- | --- |
| Codex | 指令、skills、验证脚本、managed hook templates、Git checkpoint 工作流 | 强提示约束，加上可用的 managed lifecycle hooks |
| Claude Code | 指令、skills、验证脚本、生命周期 hooks、Git checkpoint 工作流 | 通过 settings hooks 获得更强的确定性拦截 |
| 其他 coding agents | 手动复用公开规则和脚本 | 等待后续宿主适配前属于 best-effort |

第一个公开版本会是 Windows-first，因为原始工作流是在 Windows 和 PowerShell 上验证出来的。跨平台支持必须通过真实脚本验证加入，而不是靠 README 里一句“支持”。

## 不是什么 / What SteadyAgent Is Not

SteadyAgent 不是：

- 新的 coding agent
- 模型路由器
- 云端编排平台
- 人工 review 的替代品
- 能保证发现所有密钥的安全产品
- 承诺所有宿主都能执行同一套硬规则的万能配置

它是一套让本地 AI coding 工作更可观察、更安全、更容易恢复的实用 harness。

## 当前 v1 计划 / Current v1 Plan

本地已完成：

1. Phase 0：旧版基线、迁移计划、验证门、独立审查评分和 checkpoint commit。
2. Phase 1：README-first 公开叙事、双语入口和公开质量门。
3. Phase 2：Codex / Claude 公开模板、渐进规则库和规则质量门。
4. Phase 3：公开工具、dry-run 安装器、hook smoke test 和 Windows-first 工具文档。
5. Hook runtime 纵切：面向 Codex 和 Claude Code 的公开 SessionStart、UserPromptSubmit、PreToolUse、PermissionRequest、PostToolUse 和 PreCompact hooks。
6. Installer runtime integration：dry-run / apply 会规划 hook scripts、hook docs，并渲染 host config examples。

剩余 v1 阶段：

1. Skill 打包和发布准备。
2. Fresh-clone release instructions。

完整计划见 [docs/v1-migration-plan.md](docs/v1-migration-plan.md)。

## 适合谁 / Who This Is For

SteadyAgent 适合已经在使用 AI coding agents，并希望在本地工作流里获得更高可靠性的开发者。

尤其适合关注：

- 仓库卫生
- 改动范围控制
- 可复现验证
- 更安全的 Git 操作
- 长任务连续性
- 可复查证据

## 设计原则 / Design Principles

- 常驻上下文保持短。
- 重复出现的规则尽量脚本化或 hook 化。
- 验证行为，不验证自信语气。
- 未完成、跳过、失败必须显性化。
- 在云端自动化之前，先保证 local-first 可控。
- 每个公开 release 都应该是可审计产物。

## 简历项目视角 / Resume Case Study

SteadyAgent 也是一个 harness engineering 案例：不是只写 prompt，而是设计 AI coding agent 周围的环境，让它具备更清晰的范围、更安全的工具、更强的验证和更好的人工监督。

## License

许可证会在 v1 发布准备阶段确定。
