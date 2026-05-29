# zsh-agent-rules

面向中文用户的 AI Coding Agent 协作规范与 workflow skill。

这个项目把 Codex、Claude Code、Claude Code 博客实践、Karpathy 编码防错规则、Mnilax 扩展规则和个人协作方法论分层整理成可复制、可安装、可迭代的工作流。

## 适合谁

- 使用 Codex 的中文用户
- 使用 Claude Code 的中文用户
- 想减少模型跑偏、上下文混乱、过度设计和无验证修改的开发者
- 想把个人 AI coding 方法论沉淀成总纲、skill 和 references 的团队

## 快速开始

### Codex

复制 `AGENTS.md` 到你的 Codex 全局目录或项目根目录：

```powershell
Copy-Item .\AGENTS.md "$env:USERPROFILE\.codex\AGENTS.md"
```

### Claude Code

复制 `CLAUDE.md` 到你的 Claude Code 全局目录或项目根目录：

```powershell
Copy-Item .\CLAUDE.md "$env:USERPROFILE\.claude\CLAUDE.md"
```

### Skill

复制 skill 目录到 Codex skills 目录：

```powershell
Copy-Item .\skills\zsh-agent-workflow "$env:USERPROFILE\.codex\skills\zsh-agent-workflow" -Recurse
```

之后在复杂任务中让 Codex 使用 `zsh-agent-workflow`。

## 文件结构

```text
zsh-agent-rules/
├── AGENTS.md
├── CLAUDE.md
├── skills/
│   └── zsh-agent-workflow/
│       ├── SKILL.md
│       ├── agents/openai.yaml
│       └── references/
└── docs/
```

## 设计原则

- 总纲短：`AGENTS.md` 和 `CLAUDE.md` 只放每次会话都值得加载的硬约束。
- Skill 管流程：`zsh-agent-workflow` 负责复杂任务的阶段化执行。
- References 管深度：博客、帖子、规则和提示词模板按需读取，不污染常驻上下文。
- 验证优先：完成不等于成功，必须有测试、检查或最小验收步骤。
- 冲突显性化：发现需求、测试或代码约定冲突时，不自行折中。

## 方法论核心

1. 先收敛，再展开。
2. 明确时间尺度。
3. 根据阶段选模式。
4. 常驻上下文保持短。
5. 复杂输出优先 HTML artifact。
6. 子代理只用于隔离、并行和独立审查。
7. 编码修改保持 surgical。
8. 行为正确优先于测试通过。
9. 失败、跳过和部分完成必须显性化。
10. 规则必须对应真实失败模式。

## 来源与致谢

主要来源和设计说明见 `docs/sources.md` 与 `docs/design-notes.md`。

## 版本计划

- `v0.1.0`: 中文初版，总纲、skill、references 和 docs。
- `v0.2.0`: 安装脚本和更多示例。
- `v0.3.0`: 评估插件化或 marketplace 分发。
