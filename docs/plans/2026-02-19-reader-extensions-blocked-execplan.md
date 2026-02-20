# Legado -> SoupReader 扩展阅读能力冻结（漫画/TTS/朗读引擎）

- 状态：`blocked`
- 负责人：`Core-Migration`
- 更新时间：`2026-02-20`
- 解锁条件：需求方明确下达“开始做扩展功能”

## 背景与目标

### 背景
- 本仓库执行“核心优先、扩展后置”策略。
- 需求方在 `2026-02-20` 最新确认：TTS、漫画、朗读等扩展能力当前阶段暂不做，统一 `blocked`。

### 目标
- 明确扩展功能冻结边界，避免提前实现扩展入口、流程、文案与配置。
- 与主计划保持一致：`docs/plans/2026-02-20-source-management-reader-full-parity-execplan.md`。

### 非目标
- 本计划不进行任何扩展功能实现，仅用于冻结与追踪。

## 差异点清单（冻结项）

| ID | 能力 | legado 参考位置 | 冻结原因 | 影响 |
| --- | --- | --- | --- | --- |
| E-01 | 漫画阅读配置迁移 | `/home/server/legado/app/src/main/java/io/legado/app/ui/book/manga` | 需求方确认“暂不做扩展” | 漫画配置与交互暂不迁移 |
| E-02 | 朗读引擎配置 | `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/SpeakEngineDialog.kt` | 需求方确认“暂不做扩展” | 引擎选择流程暂不迁移 |
| E-03 | HTTP TTS 配置 | `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/HttpTtsEditDialog.kt` | 需求方确认“暂不做扩展” | 在线朗读扩展暂不迁移 |

## 实施步骤

### Step 1：冻结声明落盘（已完成）
- 在计划中记录冻结范围、解锁条件和禁止事项。

### Step 2：冻结状态同步到主计划（已完成）
- 在主计划记录扩展冻结例外：`EX-BLK-EXT-01`。

### Step 3：等待解锁指令（进行中）
- 收到“开始做扩展功能”前，持续维持 `blocked`。

## 风险与回滚

- 风险：若误将扩展改动混入当前核心迁移，会破坏执行顺序与验收口径。
- 控制：
  - 扩展项不得并行启动；
  - 若发现误触发，立即停止并回到 `blocked` 追踪。

## 验收与证据

- 验收标准：
  - 扩展项未被提前实现；
  - 主计划与冻结计划口径一致，均显示扩展为 `blocked`。

## Progress

- [x] Step 1：冻结声明落盘
- [x] Step 2：冻结状态同步到主计划
- [ ] Step 3：等待解锁指令

## Surprises & Discoveries

- 需求方口径在 `2026-02-20` 再次明确：扩展能力当前阶段暂不做，需恢复并保持冻结状态。

## Decision Log

- 决策 1：在未解锁前，不允许以“预埋接口”“顺手优化”等名义提前启动扩展开发。
- 决策 2（2026-02-20）：将本计划状态切换回 `blocked`，并与主计划例外 `EX-BLK-EXT-01` 同步。

## Outcomes & Retrospective

- 当前阶段扩展能力已重新纳入冻结管理。
- 后续仅在需求方明确“开始做扩展功能”后解除 `blocked` 并回补实现计划。
