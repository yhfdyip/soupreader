# 阅读器“朗读（TTS）”入口与点击动作对齐 legado ExecPlan

- 状态：`active`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（扩展功能，已冻结）`

## 背景与目标

### 背景

当前 soupreader 阅读器中的朗读链路仍为占位实现：

- 底部菜单 `朗读` 点击后仅提示“语音朗读即将上线”；
- 九宫格点击动作 `朗读上一段/朗读下一段/朗读暂停继续` 统一走占位提示；
- `_detectReadAloudCapability` 固定返回不可用；
- 退出页面缺少朗读会话清理。

legado 对照基准（已完整读取）：

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/model/ReadAloud.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/model/ReadBook.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/service/BaseReadAloudService.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/service/TTSReadAloudService.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/ReadView.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/entities/TextChapter.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/entities/TextPage.kt`

### 目标（Success Criteria）

1. 底部菜单 `朗读` 不再是占位，点击支持 `开始/暂停/继续` 状态流转。
2. 九宫格点击动作 `朗读上一段/朗读下一段/朗读暂停继续` 接入真实朗读控制。
3. 朗读状态与章节切换联动：切换章节后可继续朗读，不丢失会话状态。
4. 阅读页面销毁时会停止朗读并清理资源，避免泄漏或后台残留。
5. 保持 legado 同义的可观测提示（启动失败、无可朗读内容、状态切换提示）。

### 非目标（Non-goals）

1. 本轮不实现 legado 的完整“朗读设置弹窗”（定时器、引擎管理、HTTP TTS）。
2. 不改动与朗读无关的抓取链路（search/explore/bookInfo/toc/content）。
3. 不引入无 legado 依据的额外朗读入口。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| T1 | `simple_reader_view.dart:_openReadAloudAction` | `ReadBookActivity.onClickReadAloud` | 当前仅提示“即将上线”，缺少开始/暂停/继续流转 | 底部菜单朗读不可用 |
| T2 | `simple_reader_view.dart:_handleClickAction` | `ReadView.click(action=5/6/13)` | 朗读相关点击动作全部占位，无上一段/下一段/暂停继续 | 九宫格配置失效 |
| T3 | `simple_reader_view.dart:_detectReadAloudCapability` | `ReadAloud + BaseReadAloudService` | 能力检测固定不可用，未接入真实 TTS 能力 | 入口被永久禁用 |
| T4 | `reader_bottom_menu.dart` | `ReadMenu.kt` | 仅点击回调，无长按/状态反馈 | 交互语义弱于 legado |
| T5 | 无独立朗读服务层 | `ReadAloud.kt + TTSReadAloudService.kt` | 缺少会话状态、段落游标与资源清理抽象 | 生命周期与边界处理不一致 |

## 逐项检查清单（强制）

- 入口：底部菜单 `朗读` 是否触发真实朗读而非占位提示。
- 状态：开始/暂停/继续与 UI 提示是否一致，章节切换后是否延续。
- 异常：空正文、TTS 初始化失败、无可用段落时是否可观测且不崩溃。
- 文案：`开始朗读/暂停朗读/继续朗读/朗读已停止` 等语义是否准确。
- 排版：底部菜单新增朗读状态指示/长按行为不破坏现有两行布局与热区。
- 交互触发：九宫格 `上一段/下一段/暂停继续` 是否按设定动作生效。

## 实施步骤（依赖与并行）

### Step 1（串行，前置）

- 目标：落盘 ExecPlan、差异清单、检查清单。
- 状态：`completed`
- 验证：`PLANS.md` 可索引本任务文档。

### Step 2（串行，依赖 Step 1）

- 目标：新增朗读服务层并接入阅读页状态机。
- 涉及：
  - `lib/features/reader/services/read_aloud_service.dart`（新增）
  - `lib/features/reader/views/simple_reader_view.dart`
- 预期结果：
  - 具备 `start/pause/resume/stop/prevParagraph/nextParagraph` 语义；
  - 与当前章节内容、章节切换、页面销毁正确联动。
- 状态：`in_progress`

### Step 3（可并行，依赖 Step 2）

- 分支 3A（owner: A）
  - 目标：底部菜单 `朗读` 点击/长按对齐 legacy 语义。
  - 涉及：
    - `lib/features/reader/widgets/reader_bottom_menu.dart`
    - `lib/features/reader/views/simple_reader_view.dart`
  - 状态：`pending`
- 分支 3B（owner: B）
  - 目标：九宫格朗读动作接入真实控制。
  - 涉及：
    - `lib/features/reader/views/simple_reader_view.dart`
    - `lib/features/reader/models/reading_settings.dart`（仅在动作映射需要时调整）
  - 状态：`pending`

### Step 4（串行，依赖 Step 3）

- 目标：补齐测试与逐项对照回填。
- 涉及：
  - `test/read_aloud_service_test.dart`（新增）
  - `test/simple_reader_view_compile_test.dart`（必要时补充）
  - 本 ExecPlan 文档回填
- 状态：`pending`

## 风险与回滚

### 失败模式

1. 第三方 TTS 初始化失败导致入口不可用或崩溃。
2. 段落切分策略不稳定，`上一段/下一段` 跳转出现越界。
3. 页面销毁未停止朗读，出现后台残留播报。

### 阻塞条件（触发即标记 `blocked`）

1. 当前 Flutter 端无法稳定获取可用 TTS 引擎（平台能力缺失）。
2. 与现有阅读模式（滚动/翻页）联动时出现不可接受的状态错乱且无回滚路径。

### 回滚策略

1. 朗读逻辑集中在独立服务文件，可按文件粒度回滚。
2. `simple_reader_view.dart` 仅保留入口接线改动，失败可函数级回退到占位实现。
3. 底部菜单交互改动与测试改动独立回滚，避免影响目录/界面/设置入口。

## 验收与证据

### 手工回归路径

1. 阅读页 -> 底部 `朗读`：首次点击开始朗读，再次点击暂停，再次点击继续。
2. 九宫格分别配置并触发：`朗读上一段/朗读下一段/朗读暂停继续`。
3. 朗读中切换上一章/下一章，确认朗读会话能继续或合理重置。
4. 退出阅读页，确认朗读停止且无后台继续播报。
5. 空章节或仅空白正文，触发朗读时应有提示且不崩溃。

### 命令验证

- 开发过程：仅执行定向测试，不执行 `flutter analyze`。
- 提交推送前：执行且仅执行一次 `flutter analyze`（本轮未到提交阶段）。

## Progress

- `2026-02-20`：
  - 已完成：Step 1（ExecPlan 建立 + 差异清单 + 检查清单）。
  - 已变更：根据需求方最新指令“continue to next task”，恢复本计划执行，状态由 `blocked` 切换为 `active`。
  - 当前进行中：Step 2（朗读服务层与阅读页状态机接线）。

## Surprises & Discoveries

1. 当前 Flutter 阅读器已具备朗读相关点击动作枚举，但全部未接线到真实能力。
2. legacy 中朗读与章节/页面状态高度耦合，需优先保证生命周期与状态回放，不宜只做单点按钮替换。

## Decision Log

1. 本轮先实现系统 TTS 的基础闭环，保持与 legado 核心交互同义。
2. `ReadAloudDialog` 的高级设置（定时器/引擎管理）拆分为后续任务，避免本轮跨模块过度扩散。
3. `2026-02-20` 按需求方最新指令暂停 TTS 支线，优先继续阅读器“界面/设置”迁移，TTS 计划状态调整为 `blocked`。
4. `2026-02-20` 接收需求方“continue to next task”后，按计划索引中的下一待办恢复 TTS 任务并转为 `active`。

## Outcomes & Retrospective

- 待实现后回填。
