# SteadyAgent

**Ship with evidence, not vibes.**  
**用证据交付，而不是凭感觉相信 AI agent。**

SteadyAgent 是一个 local-first 的 AI coding agent 工作流 harness，面向 Codex、Claude Code 等工具。它把松散的 agent 对话变成可复用的工程闭环：理解任务、检查仓库、规划改动、做最小有效编辑、验证行为、审查结果、创建 checkpoint。

[English README](README.md)

> 状态：v1.0.0 已发布。当前 checkout 已包含公开模板、渐进规则、验证门、Windows-first 工具、hook runtime 资产、宿主启用文档和 release-readiness 证据链。

## 从这里开始 / Start Here

如果你是新用户，先读 [docs/getting-started.zh-CN.md](docs/getting-started.zh-CN.md)。它把 Codex 新手、Claude Code 用户、双宿主用户和只读评估用户分成不同路径。

按你的需求选择入口：

| 需求 | 阅读这里 |
| --- | --- |
| 第一次安装 SteadyAgent | [docs/getting-started.zh-CN.md](docs/getting-started.zh-CN.md) |
| 查看每个功能对应的实现文件 | [docs/feature-map.zh-CN.md](docs/feature-map.zh-CN.md) |
| 让 Codex 或 Claude Code hooks 真正运行 | [docs/activation-guide.zh-CN.md](docs/activation-guide.zh-CN.md) |
| 理解架构 | [docs/how-it-works.zh-CN.md](docs/how-it-works.zh-CN.md) |
| 直接尝试真实提示词 | [docs/workflow-examples.zh-CN.md](docs/workflow-examples.zh-CN.md) |
| 查具体命令 | [docs/tools.zh-CN.md](docs/tools.zh-CN.md) |
| 理解 hook 生命周期 | [docs/hook-runtime.zh-CN.md](docs/hook-runtime.zh-CN.md) |

## SteadyAgent 解决什么 / What SteadyAgent Solves

AI coding agents 很有用，但常见失败模式很稳定：

- 没理解仓库就开始改
- 偏离用户要求的范围
- 没跑检查也声称完成
- 长任务或上下文压缩后丢状态
- 对高风险 shell / Git 命令过于随意
- 留不下清晰证据，后续很难复查

SteadyAgent 不替代 Codex 或 Claude Code。它是在你已经使用的 agent 外面加一层本地工作流、确定性脚本、可选 hooks 和发布检查。

## 核心闭环 / The Core Loop

```text
understand -> plan -> red check -> smallest change -> green check -> review -> checkpoint
```

仓库里的每个公开文件都服务于这个闭环的一部分。

| 闭环步骤 | SteadyAgent 提供什么 |
| --- | --- |
| Understand | 短入口指令和渐进规则。 |
| Plan | workflow routing 和范围明确的任务计划。 |
| Red check | 修改前先复现或找到可观察证据。 |
| Smallest change | 约束 agent 只改当前目标需要的范围。 |
| Green check | 测试、lint、文档检查、脚本 gate 或 hook smoke test。 |
| Review | 高风险或多文件改动在 checkpoint 前触发独立审查。 |
| Checkpoint | 只暂存显式文件的 Git checkpoint 工作流。 |

## 当前可用 / Available Today

当前 release 包含：

- `templates/` 中的 Codex 和 Claude Code 入口模板
- `rules/` 中的 workflow、verification、review、context 和 safety 渐进规则
- `skills/steadyagent-workflow/` 中打包好的 workflow skill
- `tools/` 中的 Windows-first PowerShell 工具
- `tools/install.ps1` 中的 dry-run installer
- `tools/test-agent-hooks.ps1` 提供 hook smoke test coverage
- `tools/hooks/` 中的公开 hook scripts
- `tools/diagnose-install.ps1` 提供安装诊断
- `tools/enable-codex-hooks.ps1` 提供 Codex managed-hook 启用
- `tools/validate-release-readiness.ps1` 提供 release-readiness validation
- `docs/` 中的新手、架构、启用、功能地图、工具和工作流示例文档
- 发布资产：MIT license、contributing guide、security policy、release notes、issue templates、PR template 和 GitHub validation workflow

## 快速开始 / Quick Start

在干净 checkout 中先验证公开包：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-release-readiness.ps1
```

如果只想做 public tool surface 的聚焦检查：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-phase3.ps1
```

如果只想预览两个宿主的安装结构，不写入真实宿主目录：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Both -TargetRoot .\steadyagent-install-preview
```

预览 Codex 安装计划：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex
```

预览 Claude Code 安装计划：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Claude
```

看过 dry-run 输出后，再应用到对应宿主：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Codex -Apply
```

或：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install.ps1 -HostTarget Claude -Apply
```

对已安装的 hook runtime 做冒烟测试：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\test-agent-hooks.ps1"
```

或：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\tools\test-agent-hooks.ps1"
```

这个 smoke test 证明 hook scripts 自身能运行，不证明宿主已经加载它们。要让 hooks 在 Codex 或 Claude Code 真实会话里响应，需要完成宿主启用并重启宿主。

Codex 先预览启用计划：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\enable-codex-hooks.ps1"
```

看过计划后，在管理员 PowerShell 中加 `-Apply` 执行。

Claude Code 用户需要把 `$HOME\.claude\settings.hooks.example.json` 合并进 `$HOME\.claude\settings.json`，然后重启 Claude Code。

启用后运行完整诊断：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\tools\diagnose-install.ps1" -HostTarget Both -RequireHooksActive
```

## 日常如何使用 / How To Use It Day To Day

在 Codex 或 Claude Code 中打开你的项目，然后直接说明你想要的结果。需要明确使用这套 harness 时，加上 `Use SteadyAgent`：

```text
Use SteadyAgent. Fix the failing login test. Inspect the repo first, keep the change scoped, run the smallest relevant validation, and report changed files, verification, risks, and Git status.
```

预期行为：

- agent 修改前先检查仓库
- 复杂或高风险任务先给短计划
- 改动范围只围绕当前目标
- 声称完成前先运行验证
- 结束时报告剩余风险和 Git 状态
- hooks 启用后，可以拦截高风险 shell、文件和权限动作

## 安装和启用的区别 / Activation vs Installation

安装只是复制文件。启用是让宿主加载 hook 配置。

| 状态 | 哪些功能可用 |
| --- | --- |
| 只安装 | 入口指令、rules、skill 文件、脚本、文档和 hook smoke tests。 |
| 启用并重启 | 实时 hook reminders、command guard、file guard、permission guard、audit log 和 pre-compact reminders。 |

如果用户说“安装后 hooks 没反应”，先看 [docs/activation-guide.zh-CN.md](docs/activation-guide.zh-CN.md)。

## 主要命令 / Main Commands

| 命令 | 作用 |
| --- | --- |
| `tools/install.ps1` | 预览或应用宿主安装。 |
| `tools/diagnose-install.ps1` | 检查安装文件、渲染配置、active host config 和 hook smoke tests。 |
| `tools/enable-codex-hooks.ps1` | 通过 dry-run、备份和提权写入检查，安全安装 Codex managed hooks。 |
| `tools/test-agent-hooks.ps1` | 通过 stdin 发送真实 hook event JSON，验证 hook script 行为。 |
| `tools/git-preflight.ps1` | 修改前检查仓库状态。 |
| `tools/git-checkpoint.ps1` | 创建只包含显式文件的 scoped checkpoint commit。 |
| `tools/validate-release-readiness.ps1` | 验证公开发布资产、链接、fresh install、diagnostics 和 hook runtime 行为。 |

命令细节见 [docs/tools.zh-CN.md](docs/tools.zh-CN.md)。

## 项目地图 / Project Map

| 路径 | 作用 |
| --- | --- |
| `AGENTS.md` | 本仓库内给 Codex 的简短贡献指南。 |
| `CLAUDE.md` | 本仓库内给 Claude Code 的简短贡献指南。 |
| `templates/codex/` | 可安装的 Codex 入口指令和 managed-hook manifest 示例。 |
| `templates/claude/` | 可安装的 Claude Code 入口指令和 settings hook 示例。 |
| `rules/` | routing、verification、review、context 和 safety 渐进规则。 |
| `skills/steadyagent-workflow/` | 带参考资料和 agent 元数据的 portable workflow skill。 |
| `tools/` | 安装器、诊断、Git helpers、验证 gates 和 hook smoke tests。 |
| `tools/hooks/` | 公开 lifecycle hook scripts。 |
| `docs/` | 用户指南、实现说明、启用指南、功能地图、示例和发布文档。 |

## 安全模型 / Safety Model

SteadyAgent 把提示约束和硬检查分开：

| 层级 | 作用 | 示例 |
| --- | --- | --- |
| Instructions | 设置 agent 默认行为 | 控制改动范围、验证行为、报告风险。 |
| Rules | 按需加载更深的工作流 | 审查门、上下文恢复、安全边界。 |
| Scripts | 把重复检查变成确定性命令 | Git preflight、checkpoint、release validation。 |
| Hooks | 拦截或审计受支持的生命周期事件 | 危险 shell 命令、密钥文件编辑、权限请求。 |
| Reviews | checkpoint 前发现缺口 | findings-first 独立审查。 |

Hooks 有用，但不是完整安全边界。它们减少常见错误，不能替代人工 review 和显式批准。

## 兼容性 / Compatibility

SteadyAgent 优先面向本地开发机器。

| 宿主 | v1 目标 | 强制能力 |
| --- | --- | --- |
| Codex | 指令、skills、验证脚本、managed hook templates、Git checkpoint workflow | 强提示约束，加上可用的 managed lifecycle hooks。 |
| Claude Code | 指令、skills、验证脚本、lifecycle hooks、Git checkpoint workflow | 通过 settings hooks 获得更强的确定性拦截。 |
| 其他 coding agents | 手动复用公开 rules 和 scripts | 在有专用 adapter 前属于 best-effort。 |

第一个公开版本是 Windows-first，因为原始工作流是在 Windows 和 PowerShell 上验证出来的。Linux 和 macOS 支持必须通过真实脚本验证加入，不能只靠 README 承诺。

## 不是什么 / What SteadyAgent Is Not

SteadyAgent 不是：

- 新的 coding agent
- 模型路由器
- 云端编排平台
- 人工 review 的替代品
- 能保证发现所有密钥的安全产品
- 承诺所有宿主都能执行同一套硬规则的万能配置

它是一套让本地 AI coding 工作更可观察、更安全、更容易恢复的实用 harness。

## 发布证据 / Release Evidence

v1.0.0 release 依赖可复现检查：

- `tools/validate-release-readiness.ps1` 验证 release assets、Markdown 链接、fresh workspace 安装、渲染后的 host configs、安装诊断和安装后的 hook smoke tests。
- `tools/validate-phase3.ps1` 验证 public tool surface 和 installer 行为。
- `tools/validate-runtime-slice.ps1` 验证 hook runtime 纵切。
- `tools/test-agent-hooks.ps1` 通过 stdin 发送真实 hook event JSON，做 smoke coverage。
- `tools/diagnose-install.ps1` 检查安装文件和 active host hook config 是否存在。
- `tools/enable-codex-hooks.ps1` 通过 dry-run、备份和提权写入检查，安全安装 Codex managed hook manifest。

Maintainer 发布检查见 [docs/release-checklist.zh-CN.md](docs/release-checklist.zh-CN.md)，GitHub push、PR、metadata、tag 和 release 执行顺序见 [docs/github-publication-runbook.zh-CN.md](docs/github-publication-runbook.zh-CN.md)。

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

项目叙事见 [docs/resume-case-study.zh-CN.md](docs/resume-case-study.zh-CN.md)。

## License

MIT。见 [LICENSE](LICENSE)。
