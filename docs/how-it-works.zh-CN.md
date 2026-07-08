# SteadyAgent 如何工作

SteadyAgent 把松散的 AI coding 对话变成可复用的本地工程闭环：

```text
understand -> plan -> red check -> smallest change -> green check -> review -> checkpoint
```

实现方式不是只写一段 prompt，而是把短常驻指令、渐进规则、可复用 skill、确定性脚本、hook 示例和发布证据组合起来。

## 核心模型

可以把 SteadyAgent 理解成包在 Codex、Claude Code 或其他 coding agent 外面的六层。六个公开概念是 Instructions、Rules、Skills、Tools、Hooks 和 Validation。

| 层级 | 文件 | 作用 |
| --- | --- | --- |
| 入口指令 | `AGENTS.md`、`CLAUDE.md`、`templates/` | 给宿主一个短项目地图和默认工作规则。 |
| 渐进规则 | `rules/` | 只有需要时才加载细节，避免常驻上下文过重。 |
| 可复用 skill | `skills/steadyagent-workflow/` | 把工作流打包成带参考资料和 agent 元数据的 portable skill。 |
| 工具 | `tools/*.ps1` | 把重复检查变成确定性的 PowerShell 命令。 |
| Hook runtime | `tools/hooks/`、`templates/*/*hooks*` | 演示宿主支持时如何提醒、拦截或审计生命周期事件。 |
| 发布证据 | `validate-*`、发布文档、GitHub workflow | 证明公开包可以被检查、安装和冒烟测试。 |

## 一次请求的生命周期

当你要求 agent 使用 SteadyAgent 工作时，理想路径是：

1. 宿主加载 `AGENTS.md` 或 `CLAUDE.md`。
2. agent 先查看仓库和相关文档，再修改文件。
3. 对复杂任务，agent 读取对应规则，例如 workflow routing、verification、review gates、context management 或 safety boundaries。
4. 修改前运行 Git preflight。
5. 任务复杂或高风险时，先给短计划。
6. 只做满足目标的最小有效改动。
7. 运行最小相关验证，例如测试、脚本 gate、Markdown 检查或 hook 冒烟测试。
8. 如果命中 review gate，在 checkpoint 前由 fresh reviewer 审查 diff。
9. 结束时报告改动文件、验证结果、剩余风险和 Git 状态。

## 每个目录负责什么

| 目录或文件 | 角色 |
| --- | --- |
| `README.md` 和 `README.zh-CN.md` | 公开入口和项目定位。 |
| `docs/getting-started*.md` | 新手上手路径和第一次使用命令。 |
| `docs/how-it-works*.md` | 架构和实现说明。 |
| `docs/feature-map*.md` | 把每个功能映射到实现文件、安装路径、触发方式和验证方式。 |
| `docs/activation-guide*.md` | 说明安装文件和 active host hooks 的区别。 |
| `docs/workflow-examples*.md` | 真实提示词模式和预期 agent 行为。 |
| `rules/` | routing、verification、review、safety、context recovery 等详细规则。 |
| `skills/steadyagent-workflow/` | 面向支持 skill 的 agent 宿主的可复用工作流包。 |
| `templates/codex/` | Codex 专用入口指令和 managed hook config example。 |
| `templates/claude/` | Claude Code 专用入口指令和 settings hook config example。 |
| `tools/install.ps1` | dry-run 优先的宿主安装器。 |
| `tools/diagnose-install.ps1` | 检查安装资产、渲染配置、active host config 和安装后的 hook smoke tests。 |
| `tools/enable-codex-hooks.ps1` | 在 dry-run 审查和管理员确认后安全写入 Codex managed hooks。 |
| `tools/validate-release-readiness.ps1` | 完整公开发布 gate。 |
| `tools/validate-phase3.ps1` 和 `tools/validate-runtime-slice.ps1` | public tools 和 hook runtime 的聚焦 gate。 |
| `tools/test-agent-hooks.ps1` | hook 脚本的端到端冒烟测试。 |

## 为什么入口指令要短

超长常驻 prompt 容易过时，也会污染上下文。SteadyAgent 让宿主入口文件保持短，把细节路由到 `rules/`、`skills/`、docs 或 scripts。

这样有两个好处：

- 新用户不需要读完整规则库，也能理解公开面。
- 专业用户可以直接查看某个行为对应的规则或脚本。

## 为什么需要脚本

Prompt 适合判断，不适合做确定性检查。SteadyAgent 把不应该靠模型临场记忆的事情写成脚本：

- `git-preflight.ps1` 在开工前检查仓库状态。
- `git-checkpoint.ps1` 只暂存显式文件并创建 checkpoint commit。
- `diagnose-install.ps1` 检查宿主目录和 active hook config 是否完整。
- `enable-codex-hooks.ps1` 只在 dry-run 审查和备份后写入 Codex managed hooks。
- `validate-release-readiness.ps1` 检查公开发布面和 fresh install 行为。
- `test-agent-hooks.ps1` 通过 stdin 发送真实 hook event JSON。

目标不是取消人工判断，而是让日常安全和质量检查变得可观察。

## Hook 如何嵌入

Hooks 是可选的宿主集成点。它们可以做提醒、上下文注入、命令检查、文件检查、权限检查、审计日志和压缩前提醒。

Codex 和 Claude Code 的 hook 能力并不完全一样：

| 宿主 | SteadyAgent 集成方式 |
| --- | --- |
| Codex | managed hook config example，加上指令、规则、skills 和验证脚本。 |
| Claude Code | settings hook config example，加上指令、规则、skills 和验证脚本。 |
| 其他 agent | 在有专用 adapter 前，手动复用 rules 和 tools。 |

Hooks 不是完整安全边界。它们只是本地工作流的一层，仍然需要 review、validation，以及用户对高风险动作的显式批准。

安装本身只会复制 hook scripts 并渲染配置示例。真实 hook 行为需要启用宿主配置并重启宿主。启用步骤见 [activation-guide.zh-CN.md](activation-guide.zh-CN.md)，每个行为对应的实现文件见 [feature-map.zh-CN.md](feature-map.zh-CN.md)。

## 为什么是 local-first

第一个版本选择 local-first，因为这套工作流服务的是开发者本机上的日常 agent-assisted development。local-first 也让发布更容易审计：

- 试用核心工作流不需要云账号
- 核心工具不需要凭证
- 可以从 fresh checkout 运行验证
- 写入文件前可以先预览安装计划

## 哪些仍然必须由人判断

SteadyAgent 不决定产品优先级，不保证发现所有敏感信息，也不替代代码审查。它让 agent 的过程更容易被检查：

- 它理解了什么
- 它改了什么
- 它验证了什么
- 它跳过了什么
- 还剩什么风险

这条可审计链路就是核心价值。
