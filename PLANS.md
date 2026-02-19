# ExecPlan 索引

本仓库迁移任务遵循 AGENTS 中 ExecPlan 机制。复杂功能与跨模块迁移必须先落盘计划再实现。

## 活跃计划

1. `docs/plans/2026-02-19-legado-core-first-execplan.md`
   - 标题：Legado -> SoupReader 核心优先迁移（iOS 优先）
   - 状态：`active`
   - 口径：核心功能先完成；扩展能力记录并后续迭代；仿真翻页保留现有 Shader 实现
2. `docs/plans/2026-02-19-legado-extension-roadmap-execplan.md`
   - 标题：Legado -> SoupReader 扩展能力分期迁移（RSS/TTS/Dict/Android API）
   - 状态：`active`
   - 口径：在核心链路稳定基础上，按分期推进扩展能力，逐阶段提供可验证证据

## 已完成计划

1. `docs/plans/2026-02-19-codex-monitor-landlock-execplan.md`
   - 标题：Codex 监控脚本沙箱模式稳定化
   - 状态：`done`
   - 口径：默认使用 Full access 命令，避免 `workspace-write` 在 Landlock 环境下失败

## 状态定义

- `draft`：草案，未进入实现
- `active`：实施中
- `blocked`：遇到阻塞或例外，待确认
- `done`：计划完成并具备验收证据
