# 简历案例

## 项目

SteadyAgent 是一个 bilingual、local-first 的 AI coding agent harness。它把个人 Codex 和 Claude Code 工作流转成公开工具包，包含常驻指令、渐进规则、验证脚本、生命周期 hooks、checkpoint commits 和 release-readiness gates。

## 问题

AI coding agents 的常见失败不是单纯“模型不聪明”，而是工程流程失控：范围不清、未诊断就修改、没有证据也声称完成、shell / Git 操作风险高、长任务后上下文丢失、审计轨迹薄弱。

## 方法

- 把 always-on instructions、progressive rules 和 skills 分层。
- 将重复工作流规则沉淀为 PowerShell scripts 和 host hook templates。
- 用 TDD 验证仓库行为：每个阶段先加入会失败的 validation gate，再实现。
- 多文件或高风险改动在 checkpoint 前做 independent review。
- 英文作为默认公开入口，同时保留完整中文镜像，方便解释和复盘。

## 证据

- Public tool validation gate。
- Public hook runtime gate，并覆盖安装后的 Codex / Claude smoke tests。
- Release-readiness gate，会模拟 fresh workspace snapshot 并验证安装产物。
- 通过验证输出、release notes 和 CI 保留 scoped change 与 release evidence。
- Review score 目标：checkpoint 前无 P0/P1，且评分至少 9.5/10。

## 简历 Bullet

构建 SteadyAgent：一个 bilingual local-first AI coding agent harness，将 Codex 和 Claude Code 的临时对话转为可复用工程闭环，覆盖范围规划、Git preflight、安全 hooks、状态恢复、验证门禁、独立审查和 checkpoint commits。

## 面试讲解点

- 为什么只写 prompt 不足以让 agent workflow 可靠。
- scripts 和 hooks 如何把重复规则变成确定性 guardrails。
- TDD 如何用于验证文档、安装器和 workflow 行为。
- 为什么 Codex 和 Claude Code 需要不同 enforcement model。
- release-readiness 证据链如何让开源 workflow 项目更可信。
