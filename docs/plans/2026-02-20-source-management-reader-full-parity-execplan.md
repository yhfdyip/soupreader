# Legado -> SoupReader 书源管理与阅读器全功能同义排查与迁移总计划（除 UI 风格外完全一致）

- 状态：`active`
- 负责人：`Core-Migration`（主）、`Source-Management-Audit`（并行分支 A）、`Reader-Full-Audit`（并行分支 B）
- 更新时间：`2026-02-20`
- 范围类型：迁移级别（全量范围排查；扩展实现当前冻结）

## 背景与目标

### 背景

- 当前仓库已有多份“阅读器分项迁移”计划，但缺少覆盖“书源管理 + 阅读器所有功能”的统一主计划。
- 需求方在 `2026-02-20` 明确提出：排查书源管理与阅读器所有功能，要求与 legado 除 UI 风格外完全同义。
- 现有计划中“扩展能力冻结”与新需求口径存在冲突，需要在计划层先完成状态切换与任务重排。

### 目标

- 输出书源管理全功能与阅读器全功能的完整差异点清单（含文件位置、原因、影响）。
- 输出逐项对照清单，覆盖：入口、状态、异常、文案、排版、交互触发、按钮、跳转层级。
- 对无法等价复现项严格按 `1.1.2` 流程记录为 `blocked`，并附四要素：原因、影响范围、替代方案、回补计划。
- 维持五段链路（`search/explore/bookInfo/toc/content`）可调试能力，并在排查中同步验证阅读态联动行为。

### 非目标

- 本计划当前阶段聚焦“排查与对照”，不在同一交付点内承诺完成全部代码修复。
- 本计划不改变 UI 风格体系（继续 `Shadcn + Cupertino`），仅对齐功能语义。
- 本计划阶段不执行 `flutter analyze`（遵守仓库规则：仅提交推送前执行一次）。
- 本计划不修改“仿真翻页（simulation）使用的 shader 实现”，该项已由需求方在 `2026-02-20` 明确确认为“不需要修改”。
- 本计划当前阶段不实现 TTS/漫画/朗读引擎等扩展能力，统一标记为 `blocked`，待需求方明确“开始做扩展功能”后再解锁。

### 成功标准

- 已形成统一主计划并在 `PLANS.md` 建立活跃索引。
- 已完成“差异点清单 + 逐项对照清单”双清单输出，且覆盖书源管理与阅读器全量功能。
- 所有阻塞例外均完成 `blocked` 记录与回补计划，不存在无记录偏航。
- 最终结论中不使用模糊措辞，明确区分：`已同义 / 部分同义 / 缺失 / blocked`。

## 差异点清单（计划级）

| ID | 差异 | 文件位置 | 原因 | 影响 |
| --- | --- | --- | --- | --- |
| P-01 | 缺少“书源管理 + 阅读器全功能”统一主计划 | `PLANS.md`、`docs/plans/*.md` | 现有计划按阅读器子专题拆分，未形成跨模块总览 | 排查范围不完整，优先级与依赖关系难统一管理 |
| P-02 | 书源管理尚无迁移级全量对照台账 | `lib/features/settings/views/source_management_view.dart`、`lib/features/source/views/source_list_view.dart`、`lib/features/source/views/source_edit_legacy_view.dart` | 既有计划重点在阅读器，不足以覆盖书源管理全部入口与状态 | 容易遗漏导入导出、登录、禁用、调试等关键语义 |
| P-03 | 阅读器存在分项计划但缺“全功能统一结论” | `docs/plans/2026-02-19-reader-core-config-parity-execplan.md`、`docs/plans/2026-02-20-reader-ui-core-parity-audit-execplan.md` 及其子计划 | 任务拆分后未回收为单一总账 | 难以判断“除 UI 外完全一致”是否已达成 |
| P-04 | 扩展能力执行口径存在历史切换 | `docs/plans/2026-02-19-reader-extensions-blocked-execplan.md` | 需求口径先后出现“全量排查”与“扩展暂不做”切换 | 若不统一口径会导致执行分支误判；当前已通过 `EX-BLK-EXT-01` 收敛 |
| P-05 | 阻塞项分散在多个子计划，缺统一收口 | `docs/plans/2026-02-20-reader-source-action-menu-core-parity-execplan.md` 等 | 历史上按子任务记录例外 | 阻塞风险难集中评估与排序，回补节奏不清晰 |

## 逐项检查清单（实施前固定项，T5 已落盘）

### T5 输入基线（来自 T4 差异台账）

| 输入 ID | 模块 | 差异摘要 | 严重级别 | 后续执行归属 |
| --- | --- | --- | --- | --- |
| `T4-01` | 书源管理（RSS） | RSS 导入入口缺失（本地/网络/扫码/默认导入） | `高` | `T6A` |
| `T4-02` | 书源管理（RSS） | RSS 批量能力缺失（启停/分组/导出/分享/区间） | `高` | `T6A` |
| `T4-03` | 阅读器核心 | 章节购买可见条件缺口（`isVip/isPay` 持久化不足） | `高` | `blocked`（`EX-SA-01`） |
| `T4-04` | 阅读器核心 | `payAction` 缺 legado `AnalyzeRule` 完整上下文 | `高` | `blocked`（`EX-SA-02`） |
| `T4-05` | 阅读器核心 | MoreConfig 剩余核心键未迁移 | `中高` | `T6B` |
| `T4-06` | 阅读器核心 | 9 宫格执行器仍有 3 个动作仅 toast | `中` | `T6B` |
| `T4-07` | 阅读器核心 | 顶栏书籍信息在临时会话场景不可达 | `低` | `T6B` |
| `T4-08` | 扩展冻结 | 朗读/TTS/漫画能力未实现 | `中` | `blocked`（`EX-BLK-EXT-01`） |

### 维度检查表（T6A/T6B 回填模板）

> 回填状态仅允许：`待执行 / 进行中 / 已同义 / 部分同义 / 缺失 / blocked`。

| 检查项 | 检查内容 | 书源管理（T6A） | 阅读器核心（T6B） | 备注 |
| --- | --- | --- | --- | --- |
| 入口 | 页面入口、菜单入口、二三级入口层级是否同义 | 待执行 | 待执行 | 对照 `T3-A/T3-B` 与 legado 原始菜单 |
| 状态 | 默认态、切换态、重进恢复、重启恢复是否同义 | 待执行 | 待执行 | 覆盖持久化回流与运行时重建 |
| 异常 | 空态、非法输入、网络失败、规则失败、权限失败反馈是否同义 | 待执行 | 待执行 | 需记录可观测输出与兜底文案 |
| 文案 | 用户可见文案业务语义是否同义 | 待执行 | 待执行 | 禁止以“近似表达”替代业务语义 |
| 排版 | 信息层级、间距节奏、热区结构是否同义（风格差异除外） | 待执行 | 待执行 | 最终由 `T7` 做专项终验 |
| 交互触发 | 点击、长按、滑动、开关、弹窗确认取消语义是否同义 | 待执行 | 待执行 | 需覆盖取消/撤销路径 |
| 按钮 | 按钮集合、顺序、可见条件、可点击条件是否同义 | 待执行 | 待执行 | 对应 `RD-M3`/`SM-M*` 菜单矩阵 |
| 跳转层级 | 路由目标、返回路径、页面层级关系是否同义 | 待执行 | 待执行 | 需覆盖“临时会话”与“书架会话” |

### 四态布局一致性专项（新增强制项）

| 模块 | 加载态 | 空态 | 错误态 | 成功态 | 当前状态 |
| --- | --- | --- | --- | --- | --- |
| 书源管理（`T6A`） | 待执行 | 待执行 | 待执行 | 待执行 | 待回填 |
| 阅读器核心（`T6B`） | 待执行 | 待执行 | 待执行 | 待执行 | 待回填 |

### 逐项结论记录口径（固定）

- `已同义`：入口、状态、异常、文案、排版、交互触发、按钮、跳转层级与 legado 同义。
- `部分同义`：主流程同义但边界或四态布局仍有差异，必须附文件路径与影响范围。
- `缺失`：对应能力未落地，必须转入 `T6A/T6B` 的待办或阻塞台账。
- `blocked`：满足第 `1.1.2` 例外流程并记录四要素后才可使用。

## Todo 列表（需求方确认版）

> 以下 `T0~T10` 为当前唯一主追踪清单；涉及排版与交互的同义要求已并入强制验收口径。

| Todo | 说明 | 依赖 | 并行性 | 验收口径 | 当前状态 |
| --- | --- | --- | --- | --- | --- |
| T0 | 口径锁定与计划落盘升级 | 无 | 串行 | 明确“功能 + 排版 + 交互 + 状态布局 + 生命周期 + 异常反馈”均需与 legado 同义（UI 风格差异除外） | `done` |
| T1 | legado 书源管理基线全量读取 | T0 | 串行 | 完整读取书源管理相关实现与布局文件，形成功能点目录与入口层级图 | `done` |
| T2 | legado 阅读器全功能基线全量读取 | T0 | 串行 | 完整读取阅读器核心与扩展（朗读/TTS/漫画）实现与布局文件，形成入口与状态图 | `done` |
| T3 | `legado -> soupreader` 对照矩阵建模（升级版） | T1,T2 | 串行 | 对照项必须含：功能语义、排版结构、间距节奏、对齐方式、热区、交互触发、状态流转、异常反馈、文案语义、跳转层级 | `done` |
| T4 | 迁移前“差异点清单”输出（强制门禁） | T3 | 串行 | 每条差异含文件位置、原因、影响范围、严重级别；未完成不得进入实现 | `done` |
| T5 | 逐项检查清单落盘（升级版） | T4 | 串行 | 固化检查维度：入口、状态、异常、文案、排版、交互触发、按钮、跳转层级；新增“加载/空态/错误/成功四态布局一致性” | `done` |
| T6A | 书源管理同义迁移与核验 | T5 | 并行分支 A | 完成书源管理全链路对齐，并逐项回填“已同义/部分同义/缺失/blocked” | `pending` |
| T6B | 阅读器核心功能同义迁移与核验 | T5 | 并行分支 B | 完成阅读器核心功能链路对齐并回填逐项结论；`EX-CF-01`（仿真翻页 shader）按确认保持不修改 | `pending` |
| T6C | 扩展能力冻结追踪（TTS/漫画/朗读） | T5 | 串行 | 扩展项统一标记 `blocked`，仅保留差异/阻塞台账，不进入实现 | `blocked` |
| T7 | 排版与交互专项验收 | T6A,T6B | 串行 | 对列表、详情、工具栏、弹窗逐项核对布局层级、间距节奏、热区与触发行为，不得以“主流程可用”替代 | `pending` |
| T8 | 阻塞例外统一收口 | T7,T6C | 串行 | 所有 `blocked` 项必须补齐四要素：原因、影响范围、替代方案、回补计划 | `pending` |
| T9 | 回归证据与提交前检查 | T8 | 串行 | 输出手工回归路径与定向测试证据；仅在提交前执行一次 `flutter analyze` | `pending` |
| T10 | 文档与索引同步 | 每个可交付点后 | 持续执行 | 实时更新 ExecPlan（Progress/Surprises/Decision Log/Outcomes）与 `PLANS.md` | `in_progress` |

## 实施步骤（含依赖/并行/验收）

> 映射说明：本节为历史步骤结构，执行追踪以 `T0~T10` 为准；两者语义一致。

### Step 0：需求口径确认与主计划落盘（已完成）

- Owner：`Core-Migration`
- 依赖：无
- 并行性：串行（前置）
- 做什么：
  - 记录需求方口径：“书源管理、阅读器所有功能与 legado 除 UI 风格外完全一致”。
  - 建立本主计划并准备更新索引与冻结计划状态。
- 预期结果：
  - 后续所有排查与迁移均以本计划为统一入口。
- 验证方式：
  - 本文件存在且被 `PLANS.md` 索引到“活跃计划”。

### Step 1：legado 基线全量读取与映射（已完成）

- Owner：`Core-Migration`
- 依赖：Step 0
- 并行性：串行（迁移前置，不可并行）
- 做什么：
  - 完整读取 legado 中“书源管理 + 阅读器所有功能”对应实现文件。
  - 建立“legado 文件 -> soupreader 文件”的一对一映射表。
- 预期结果：
  - 基线文件清单完整，后续差异结论均可追溯到源码位置。
- 验证方式：
  - 在本计划新增“基线文件清单（已完整读取）”章节并回填路径。

#### Step 1 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 完成 `T1`：全量读取 legado 书源管理相关实现与资源（含书源管理、编辑、调试、登录、校验、RSS 书源管理）。
  - 完成 `T2`：全量读取 legado 阅读器核心与扩展相关实现与资源（含阅读主链路、配置弹窗、分页渲染、换源链路、漫画、朗读/TTS、配置存储）。
  - 输出 “legado -> soupreader” 文件组映射，并固化核心入口层级图，作为 `T3/T4` 输入。
- 为什么：
  - 满足 AGENTS `1.1/1.1.1` 的迁移前置门禁：先确认 legado 真实语义，再做差异矩阵与后续迁移。
- 如何验证：
  - 逐文件结构提取结果落盘（类、关键方法、菜单与布局锚点）：
    - `/tmp/t1_source_scan.txt`（书源管理，947 行）
    - `/tmp/t2_reader_scan.txt`（阅读器全功能，3360 行）
  - 本计划新增“基线文件清单（已完整读取）”与“映射/入口层级”章节。
- 兼容影响：
  - 本步骤仅做基线读取与映射，不涉及业务代码改动，对旧书源兼容性无直接影响。

## 基线文件清单（已完整读取）

### T1：legado 书源管理基线

- 核心实现：
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/edit/*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/login/*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/source/*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/CheckSourceConfig.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/rss/source/manage/*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/rss/source/edit/*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/rss/source/debug/*.kt`
- 布局与菜单：
  - `/home/server/legado/app/src/main/res/layout/activity_book_source*.xml`
  - `/home/server/legado/app/src/main/res/layout/item_book_source.xml`
  - `/home/server/legado/app/src/main/res/layout/item_source_edit*.xml`
  - `/home/server/legado/app/src/main/res/layout/activity_source_debug.xml`
  - `/home/server/legado/app/src/main/res/layout/activity_source_login.xml`
  - `/home/server/legado/app/src/main/res/layout/dialog_login.xml`
  - `/home/server/legado/app/src/main/res/layout/fragment_web_view_login.xml`
  - `/home/server/legado/app/src/main/res/layout/dialog_check_source_config.xml`
  - `/home/server/legado/app/src/main/res/layout/activity_rss_source*.xml`
  - `/home/server/legado/app/src/main/res/layout/item_rss_source.xml`
  - `/home/server/legado/app/src/main/res/menu/book_source*.xml`
  - `/home/server/legado/app/src/main/res/menu/import_source.xml`
  - `/home/server/legado/app/src/main/res/menu/source_*.xml`
  - `/home/server/legado/app/src/main/res/menu/rss_source*.xml`

### T2：legado 阅读器全功能基线（核心 + 扩展）

- 核心实现：
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/**/*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/changesource/*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/model/ReadBook.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadTipConfig.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/config/AppConfig.kt`
- 扩展实现（按 `EX-BLK-EXT-01` 仅基线读取，当前不实现）：
  - `/home/server/legado/app/src/main/java/io/legado/app/model/ReadAloud.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadAloud*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/SpeakEngine*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/HttpTts*.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/model/ReadManga.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/manga/**/*.kt`
- 布局、菜单、配置：
  - `/home/server/legado/app/src/main/res/layout/activity_book_read.xml`
  - `/home/server/legado/app/src/main/res/layout/view_read_menu.xml`
  - `/home/server/legado/app/src/main/res/layout/view_search_menu.xml`
  - `/home/server/legado/app/src/main/res/layout/dialog_read_*.xml`
  - `/home/server/legado/app/src/main/res/layout/dialog_tip_config.xml`
  - `/home/server/legado/app/src/main/res/layout/dialog_click_action_config.xml`
  - `/home/server/legado/app/src/main/res/layout/dialog_book_change_source.xml`
  - `/home/server/legado/app/src/main/res/layout/dialog_chapter_change_source.xml`
  - `/home/server/legado/app/src/main/res/layout/activity_manga.xml`
  - `/home/server/legado/app/src/main/res/layout/view_manga_menu.xml`
  - `/home/server/legado/app/src/main/res/layout/dialog_manga_*.xml`
  - `/home/server/legado/app/src/main/res/menu/book_read*.xml`
  - `/home/server/legado/app/src/main/res/menu/book_manga.xml`
  - `/home/server/legado/app/src/main/res/menu/change_source*.xml`
  - `/home/server/legado/app/src/main/res/menu/content_edit.xml`
  - `/home/server/legado/app/src/main/res/menu/speak_engine*.xml`
  - `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`

## legado -> soupreader 映射（Step 1 输出）

### T1 映射（书源管理）

| legado 功能块 | legado 基线文件组 | soupreader 对应文件组 |
| --- | --- | --- |
| 书源列表管理（排序/筛选/批量/分组） | `ui/book/source/manage/*` + `menu/book_source*.xml` + `layout/activity_book_source.xml` | `lib/features/source/views/source_list_view.dart` + `lib/features/source/services/source_filter_helper.dart` |
| 书源编辑 | `ui/book/source/edit/*` + `menu/source_edit.xml` + `layout/activity_book_source_edit.xml` | `lib/features/source/views/source_edit_legacy_view.dart` + `lib/features/source/views/source_edit_view.dart` + `lib/features/source/services/source_rule_complete.dart` |
| 书源调试（五段链路） | `ui/book/source/debug/*` + `menu/book_source_debug.xml` + `layout/activity_source_debug.xml` | `lib/features/source/views/source_debug_legacy_view.dart` + `lib/features/source/services/source_debug_orchestrator.dart` + `lib/features/source/services/source_debug_summary_store.dart` |
| 书源登录（WebView / LoginUI） | `ui/login/*` + `menu/source_login.xml` + `menu/source_webview_login.xml` + `layout/dialog_login.xml` + `layout/fragment_web_view_login.xml` | `lib/features/source/views/source_web_verify_view.dart` + `lib/features/source/views/source_login_form_view.dart` + `lib/features/source/services/source_login_*` + `lib/core/services/source_login_store.dart` |
| 导入导出与校验设置 | `help/source/*` + `ui/config/CheckSourceConfig.kt` + `menu/import_source.xml` + `layout/dialog_check_source_config.xml` | `lib/features/source/services/source_import_export_service.dart` + `lib/features/source/services/source_import_commit_service.dart` + `lib/features/source/views/source_availability_check_view.dart` |
| RSS 书源管理（同级能力） | `ui/rss/source/manage/*` + `ui/rss/source/edit/*` + `ui/rss/source/debug/*` + `menu/rss_source*.xml` | `lib/features/rss/views/rss_source_manage_view.dart` + `lib/features/rss/views/rss_source_edit_view.dart` + `lib/features/rss/services/rss_source_manage_helper.dart` |

### T2 映射（阅读器全功能）

| legado 功能块 | legado 基线文件组 | soupreader 对应文件组 |
| --- | --- | --- |
| 阅读主流程（入口/生命周期/顶底栏/菜单） | `ui/book/read/ReadBookActivity.kt` + `ReadMenu.kt` + `SearchMenu.kt` + `TextActionMenu.kt` + `layout/activity_book_read.xml` + `layout/view_read_menu.xml` | `lib/features/reader/views/simple_reader_view.dart` + `lib/features/reader/widgets/reader_menus.dart` + `lib/features/reader/widgets/reader_bottom_menu.dart` |
| 阅读状态与调度模型 | `ui/book/read/ReadBookViewModel.kt` + `model/ReadBook.kt` | `lib/features/reader/views/simple_reader_view.dart` + `lib/features/bookshelf/services/bookshelf_catalog_update_service.dart` + `lib/core/database/repositories/*.dart` |
| 分页/滚动渲染与翻页动画 | `ui/book/read/page/**/*` + `ui/book/read/page/provider/**/*` | `lib/features/reader/widgets/paged_reader_widget.dart` + `lib/features/reader/widgets/page_factory.dart` + `lib/features/reader/widgets/page_delegate/*` + `lib/features/reader/widgets/scroll_text_layout_engine.dart` |
| 配置弹窗与阅读设置 | `ui/book/read/config/*` + `res/xml/pref_config_read.xml` + `help/config/ReadBookConfig.kt` + `help/config/ReadTipConfig.kt` | `lib/features/settings/views/reading_*.dart` + `lib/features/settings/views/global_reading_settings_view.dart` + `lib/features/reader/widgets/reader_quick_settings_sheet.dart` + `lib/features/reader/models/reading_settings.dart` |
| 换源与章节换源 | `ui/book/changesource/*` + `menu/change_source*.xml` + `layout/dialog_*change_source.xml` | `lib/features/reader/services/reader_source_switch_helper.dart` + `lib/features/reader/widgets/source_switch_candidate_sheet.dart` + `lib/features/reader/views/simple_reader_view.dart` |
| 顶栏书源动作（登录/章节购买/编辑/禁用） | `menu/book_read_source.xml` + `ReadMenu.kt` + `ReadBookActivity.kt` | `lib/features/reader/services/reader_source_action_helper.dart` + `lib/features/reader/views/simple_reader_view.dart` |
| 朗读/TTS 扩展 | `model/ReadAloud.kt` + `config/ReadAloud*.kt` + `config/SpeakEngine*.kt` + `config/HttpTts*.kt` | 当前按 `EX-BLK-EXT-01` 保持 `blocked`；已有占位入口：`lib/features/reader/views/simple_reader_view.dart`、`lib/features/settings/views/source_management_view.dart` |
| 漫画阅读扩展 | `model/ReadManga.kt` + `ui/book/manga/**/*` + `layout/activity_manga.xml` + `menu/book_manga.xml` | 当前按 `EX-BLK-EXT-01` 保持 `blocked`（未进入实现） |

## 入口层级图（Step 1 输出）

### T1：书源管理入口层级（legado 基线）

- 设置入口 -> 书源列表（BookSource/RSS） -> 单项菜单（登录/调试/搜索/启禁）或批量菜单（启禁/分组/导出/校验） -> 编辑页/调试页/登录页
- 导入链路：列表工具栏 -> 本地/网络/扫码导入 -> 导入策略菜单 -> 提交写入

### T2：阅读器入口层级（legado 基线）

- 书架/详情进入阅读 -> 顶栏/快捷区/底栏/更多菜单 -> 配置弹窗（样式/提示/更多/点击区域） -> 即时作用于阅读页
- 阅读页 -> 换源（整本/章节） -> 结果选择 -> 替换书源并保持章节进度
- 阅读页 -> 书源动作（登录/章节购买/编辑/禁用） -> 登录或支付动作执行
- 扩展入口（朗读/TTS/漫画）当前仅做基线追踪，不进入实现

### Step 2：T3 对照矩阵建模（升级版，已完成）

- Owner：`Core-Migration`
- 依赖：Step 1
- 并行性：串行（迁移门禁）
- 做什么：
  - 基于 `T1/T2` 基线文件，输出“书源管理 + 阅读器核心”统一对照矩阵。
  - 每个能力块按同一维度给出结论：功能语义、排版结构、间距节奏、对齐方式、热区、交互触发、状态流转、异常反馈、文案语义、跳转层级。
- 预期结果：
  - `T4` 可直接依赖 `T3` 产出，不再重复建模。
- 验证方式：
  - 本计划新增 `T3` 双模块矩阵并附 legado/soupreader 锚点。

#### Step 2 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 复核 legado 书源管理菜单与动作实现：
    - `/home/server/legado/app/src/main/res/menu/book_source*.xml`
    - `/home/server/legado/app/src/main/res/menu/rss_source*.xml`
    - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceActivity.kt`
    - `/home/server/legado/app/src/main/java/io/legado/app/ui/rss/source/manage/RssSourceActivity.kt`
  - 复核 soupreader 对应入口与动作实现：
    - `lib/features/source/views/source_list_view.dart`
    - `lib/features/source/views/source_edit_legacy_view.dart`
    - `lib/features/source/views/source_debug_legacy_view.dart`
    - `lib/features/source/views/source_login_form_view.dart`
    - `lib/features/source/views/source_web_verify_view.dart`
    - `lib/features/rss/views/rss_source_manage_view.dart`
  - 聚合阅读器子计划与当前代码证据：
    - `docs/plans/2026-02-20-reader-quick-actions-core-parity-execplan.md`
    - `docs/plans/2026-02-20-reader-topbar-bookinfo-chapter-link-core-parity-execplan.md`
    - `docs/plans/2026-02-20-reader-source-action-menu-core-parity-execplan.md`
    - `docs/plans/2026-02-20-reader-more-config-core-step1-execplan.md`
    - `lib/features/reader/views/simple_reader_view.dart`
    - `lib/features/reader/services/reader_source_action_helper.dart`
- 为什么：
  - 按 AGENTS `T3` 门禁，必须先形成统一矩阵，才能进入 `T4` 差异清单和后续 `T5/T6`。
- 如何验证：
  - 见本节 `T3-A/T3-B` 两张矩阵，均包含 10 维度结论与文件锚点。
- 兼容影响：
  - 本步骤仅产出对照文档，不修改运行时代码；对旧书源兼容性无直接行为影响。

### T3 产出：升级版对照矩阵（2026-02-20）

#### 结论标记

- `同义`：功能语义与触发路径已对齐（允许 UI 风格差异）。
- `部分`：主语义可用，但仍有边界或入口差异。
- `缺失`：对应能力未落地。
- `blocked`：已确认例外或依赖缺口，当前阶段不可继续收敛。
- `待T7`：已建模但尚未完成“排版/交互专项验收”终验。

#### T3-A：书源管理对照矩阵（BookSource + RSS）

| 能力块 | legado 基准锚点 | soupreader 锚点 | 维度结论（功能/排版/间距/对齐/热区/交互/状态/异常/文案/跳转） | 当前结论 |
| --- | --- | --- | --- | --- |
| `SM-M1` BookSource 列表/筛选/排序/单项动作 | `BookSourceActivity.kt` + `book_source.xml` + `book_source_item.xml` | `source_list_view.dart` | `同义/待T7/待T7/待T7/同义/同义/同义/同义/同义/同义` | `部分同义`（功能已对齐，排版终验待 `T7`） |
| `SM-M2` BookSource 批量操作与导入导出/校验 | `book_source_sel.xml` + `CheckSourceConfig.kt` | `source_list_view.dart`（批量栏 + 导入策略 + 校验任务） | `同义/待T7/待T7/待T7/同义/同义/同义/同义/同义/同义` | `部分同义`（功能已闭环，排版终验待 `T7`） |
| `SM-M3` 书源编辑/调试/登录链路 | `BookSourceEditActivity.kt` + `BookSourceDebugActivity.kt` + `SourceLoginActivity.kt` | `source_edit_legacy_view.dart` + `source_debug_legacy_view.dart` + `source_login_form_view.dart` + `source_web_verify_view.dart` | `同义/待T7/待T7/待T7/同义/同义/同义/同义/同义/同义` | `部分同义`（功能同义，排版终验待 `T7`） |
| `SM-M4` RSS 列表基础能力（筛选/编辑/启停/置顶置底/删除） | `RssSourceActivity.kt` + `rss_source_item.xml` | `rss_source_manage_view.dart` | `同义/待T7/待T7/待T7/同义/同义/同义/同义/同义/同义` | `部分同义`（基础链路可用） |
| `SM-M5` RSS 导入与批量能力（本地/网络/扫码/默认导入、批量导出/分享/区间） | `rss_source.xml` + `rss_source_sel.xml` + `RssSourceActivity.kt` | `rss_source_manage_view.dart` | `缺失/缺失/缺失/缺失/缺失/缺失/缺失/缺失/部分/缺失` | `缺失`（进入 `T4` 高优先级差异） |

#### T3-B：阅读器核心对照矩阵（扩展保持冻结）

| 能力块 | legado 基准锚点 | soupreader 锚点 | 维度结论（功能/排版/间距/对齐/热区/交互/状态/异常/文案/跳转） | 当前结论 |
| --- | --- | --- | --- | --- |
| `RD-M1` 快捷动作区四按钮（搜索/自动翻页/替换规则/夜间） | `view_read_menu.xml` + `ReadMenu.kt` | `simple_reader_view.dart` + `reader_legacy_quick_action_helper.dart` | `同义/待T7/待T7/待T7/同义/同义/同义/同义/同义/同义` | `部分同义`（功能同义，排版终验待 `T7`） |
| `RD-M2` 顶栏书籍信息与章节链接入口 | `ReadMenu.kt` (`titleBar/tvChapterName/tvChapterUrl`) | `reader_menus.dart` + `simple_reader_view.dart` + `reader_top_bar_action_helper.dart` | `部分/待T7/待T7/待T7/同义/同义/部分/同义/同义/部分` | `部分同义`（临时会话无书架记录场景仍有差异） |
| `RD-M3` 书源动作菜单（登录/章节购买/编辑/禁用） | `book_read_source.xml` + `ReadMenu.kt` | `simple_reader_view.dart` + `reader_source_action_helper.dart` | `部分/待T7/待T7/待T7/同义/部分/部分/同义/同义/部分` | `部分同义`（`EX-SA-01/EX-SA-02` 阻塞） |
| `RD-M4` MoreConfig Step1（方向/系统栏/滚轮/长按按键/返回键） | `pref_config_read.xml` + `MoreConfigDialog.kt` + `ReadBookActivity.kt` | `reading_settings.dart` + `settings_service.dart` + `simple_reader_view.dart` + `reader_system_ui_helper.dart` | `同义/待T7/待T7/待T7/同义/同义/同义/同义/同义/同义` | `部分同义`（本批 5 项已闭环，排版终验待 `T7`） |
| `RD-M5` MoreConfig 剩余核心项（`selectText/customPageKey/autoChangeSource/...`） | `pref_config_read.xml` + `MoreConfigDialog.kt` | `reading_settings.dart` + `reading_*_settings_view.dart` | `缺失/缺失/缺失/缺失/缺失/缺失/缺失/缺失/缺失/缺失` | `缺失`（进入 `T4` 中高优先级差异） |
| `RD-M6` 9 宫格点击动作执行器 | `ClickActionConfigDialog.kt` + `ReadBookActivity.kt` | `simple_reader_view.dart` (`ClickAction` 分发) | `部分/待T7/待T7/待T7/同义/部分/部分/同义/同义/部分` | `部分同义`（`editContent/toggleReplaceRule/syncBookProgress` 仍为 toast） |
| `RD-M7` 朗读/TTS/漫画扩展链路 | `ReadAloud*.kt` + `SpeakEngine*.kt` + `HttpTts*.kt` + `ui/book/manga/**/*` | `simple_reader_view.dart` + `source_management_view.dart`（占位入口） | `blocked/blocked/blocked/blocked/blocked/blocked/blocked/blocked/blocked/blocked` | `blocked`（`EX-BLK-EXT-01`） |

### Step 2.5：T4 迁移前差异点清单输出（已完成）

- Owner：`Core-Migration`
- 依赖：Step 2（`T3`）
- 并行性：串行（强制门禁）
- 做什么：
  - 将 `T3` 中 `部分/缺失/blocked` 的项转为可执行差异台账。
  - 每项包含：文件位置、原因、影响范围、严重级别、状态/回补去向。
- 预期结果：
  - `T5` 可直接复用该台账生成逐项检查表并落地核验。
- 验证方式：
  - 见本节 `T4-01~T4-08`。

#### T4 模块级差异点清单（含严重级别）

| ID | 模块 | 差异描述 | 文件位置 | 原因 | 影响范围 | 严重级别 | 状态/回补计划 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `T4-01` | 书源管理（RSS） | 缺少 RSS 导入入口（本地/网络/扫码/默认导入） | `lib/features/rss/views/rss_source_manage_view.dart` | RSS 管理页目前仅保留“新增/筛选/编辑”基础能力 | 订阅源迁移与批量接入效率下降，无法同义复刻 legado 管理路径 | `高` | `pending`，并入 `T6A` |
| `T4-02` | 书源管理（RSS） | 缺少 RSS 批量操作（启停/分组/导出/分享/区间） | `lib/features/rss/views/rss_source_manage_view.dart` | 未迁移 legado `rss_source_sel.xml` 选择模式与菜单动作 | 订阅源治理链路不完整，批量维护成本高 | `高` | `pending`，并入 `T6A` |
| `T4-03` | 阅读器核心 | `章节购买` 可见条件无法精确同义（`isVip/isPay` 持久化缺失） | `lib/features/reader/views/simple_reader_view.dart` + `lib/features/reader/services/reader_source_action_helper.dart` | 当前章节付费标记仅运行态缓存，不是稳定持久化字段 | 章节购买入口可见条件与 legado 存在边界偏差 | `高` | `blocked`（`EX-SA-01`） |
| `T4-04` | 阅读器核心 | `payAction` 缺少 legado `AnalyzeRule` 完整上下文 | `lib/features/reader/views/simple_reader_view.dart` | Flutter 侧当前是轻量 `eval` 执行，不含 legado 专有运行时 | 复杂购买脚本可能执行失败或语义偏差 | `高` | `blocked`（`EX-SA-02`） |
| `T4-05` | 阅读器核心 | MoreConfig 剩余核心键未迁移（`selectText/customPageKey/autoChangeSource/expandTextMenu/...`） | `lib/features/reader/models/reading_settings.dart` + `lib/features/settings/views/reading_*.dart` | 目前仅完成 `O-04 Step1` 的 5 项核心字段 | 阅读配置覆盖率不足，部分入口与状态流转缺口仍在 | `中高` | `pending`，进入 `O-04 Step2` 与 `T6B` |
| `T4-06` | 阅读器核心 | 9 宫格动作中 `editContent/toggleReplaceRule/syncBookProgress` 仍为 toast | `lib/features/reader/views/simple_reader_view.dart` | 动作枚举已迁移，执行器未全部回补 | 用户可配置但不可执行，行为与 legado 不同义 | `中` | `pending`，并入 `T6B` |
| `T4-07` | 阅读器核心 | 顶栏书籍信息入口在“临时会话无书架记录”场景不可达 | `lib/features/reader/views/simple_reader_view.dart` | `fromBookshelf` 入口依赖书架记录 ID | 少量临时阅读态返回路径与 legado 存在偏差 | `低` | `pending`，在 `T6B` 评估兜底路由 |
| `T4-08` | 扩展冻结 | 朗读/TTS/漫画能力未进入实现 | `lib/features/reader/views/simple_reader_view.dart` + `lib/features/settings/views/source_management_view.dart` | 需求方明确“扩展暂不做” | 扩展入口仅台账追踪，不作为本阶段交付目标 | `中` | `blocked`（`EX-BLK-EXT-01`） |

### Step 2.6：T5 逐项检查清单落盘（升级版，已完成）

- Owner：`Core-Migration`
- 依赖：Step 2.5（`T4`）
- 并行性：串行（实施前门禁）
- 做了什么：
  - 将 `T4-01~T4-08` 转换为固定输入基线，明确后续归属（`T6A/T6B/blocked`）。
  - 新增“维度检查表（T6A/T6B 回填模板）”，固定 8 大检查维度与允许状态值。
  - 新增“四态布局一致性专项”（加载/空态/错误/成功）作为 `T7` 前置必查项。
  - 固化逐项结论口径（`已同义/部分同义/缺失/blocked`），避免后续使用模糊措辞。
- 为什么：
  - 满足 AGENTS `2.4` 与主计划 `T5` 门禁要求，确保 `T6A/T6B` 进入实现前已有可执行、可回填、可追溯检查框架。
- 如何验证：
  - 本文“逐项检查清单（实施前固定项，T5 已落盘）”章节已包含：
    - `T5 输入基线（来自 T4 差异台账）`
    - `维度检查表（T6A/T6B 回填模板）`
    - `四态布局一致性专项（新增强制项）`
    - `逐项结论记录口径（固定）`
- 兼容影响：
  - 本步骤仅涉及计划文档结构升级，不改动运行时代码；对旧书源兼容性无直接行为影响。

### Step 3A：书源管理全功能逐项排查（待执行，并行分支 A）

- Owner：`Source-Management-Audit`
- 依赖：Step 2.6（`T5`）
- 并行性：可与 Step 3B 并行（不同 owner，避免同文件冲突）
- 做什么：
  - 覆盖书源列表、导入/导出、编辑、登录、启用禁用、删除、分组筛选、调试、可用性检测等全流程。
  - 建立“入口/状态/异常/文案/排版/交互/按钮/跳转”逐项核验结果。
- 预期结果：
  - 书源管理形成完整对照矩阵与结论。
- 验证方式：
  - 产出“书源管理逐项对照清单 + 手工回归路径”。

### Step 3B：阅读器核心功能逐项排查（待执行，并行分支 B）

- Owner：`Reader-Full-Audit`
- 依赖：Step 2.6（`T5`）
- 并行性：可与 Step 3A 并行（不同 owner，避免同文件冲突）
- 做什么：
  - 覆盖阅读器核心功能：顶栏/底栏/快捷动作/菜单/配置页、换源与书源动作等。
  - 对照 legado 的生命周期、状态流转、取消与清理行为。
- 预期结果：
  - 阅读器核心能力形成完整对照矩阵与结论；扩展项在 `T6C` 中持续 `blocked` 追踪。
- 验证方式：
  - 产出“阅读器逐项对照清单 + 手工回归路径”。

### Step 4：阻塞例外收口与回补计划（待执行）

- Owner：`Core-Migration`
- 依赖：Step 3A、Step 3B
- 并行性：串行（汇总步骤）
- 做什么：
  - 汇总各分支 `blocked` 项，统一补齐四要素（原因/影响范围/替代方案/回补计划）。
  - 对既有阻塞（如 `EX-SA-01/EX-SA-02`）重新分级与排序。
- 预期结果：
  - 阻塞台账集中、可执行、可追踪。
- 验证方式：
  - 本计划 `Surprises & Discoveries`、`Decision Log`、`Progress` 同步回填。

### Step 5：验收证据输出与提交前检查（待执行）

- Owner：`Core-Migration`
- 依赖：Step 4
- 并行性：串行（收尾）
- 做什么：
  - 输出最终逐项对照结论（`已同义/部分同义/缺失/blocked`）。
  - 提供命令验证与手工回归路径证据。
  - 若进入提交推送阶段，执行且仅执行一次 `flutter analyze`。
- 预期结果：
  - 形成可复现、可验收的迁移证据包。
- 验证方式：
  - 命令输出记录 + 手工路径记录 + 索引状态更新。

## 子计划与并行分工（本计划索引）

- 阅读器基础迁移主计划：`docs/plans/2026-02-19-reader-core-config-parity-execplan.md`
- 阅读器全量审计报告：`docs/plans/2026-02-20-reader-ui-core-parity-audit-execplan.md`
- 阅读器快捷动作：`docs/plans/2026-02-20-reader-quick-actions-core-parity-execplan.md`
- 阅读器书源动作菜单：`docs/plans/2026-02-20-reader-source-action-menu-core-parity-execplan.md`
- 阅读器顶栏入口：`docs/plans/2026-02-20-reader-topbar-bookinfo-chapter-link-core-parity-execplan.md`
- 阅读器 MoreConfig 核心项（方向/系统栏/按键）：`docs/plans/2026-02-20-reader-more-config-core-step1-execplan.md`
- 扩展冻结计划（当前 `blocked`）：`docs/plans/2026-02-19-reader-extensions-blocked-execplan.md`

## 风险与回滚

- 风险 1：范围扩大到“所有功能”后，单轮排查输出可能遗漏边界场景。
  - 控制：严格执行逐项检查清单，不允许“笼统一致”结论。
- 风险 2：扩展能力历史上被冻结，恢复排查后可能出现口径不一致。
  - 控制：以本计划为唯一主入口，统一状态与优先级。
- 风险 3：既有阻塞项分散导致回补顺序错误。
  - 控制：Step 4 统一收口后再安排实施优先级。
- 回滚策略：
  - 若发现计划口径偏移，立即将本计划状态改为 `blocked`，先回填偏移原因与纠偏决策，再继续执行。

## 已确认例外（需求方确认）

| ID | 事项 | 确认日期 | 结论 | 原因 | 影响范围 | 回补计划 |
| --- | --- | --- | --- | --- | --- | --- |
| EX-CF-01 | 仿真翻页（simulation）使用的 shader 实现 | `2026-02-20` | 不修改 | 需求方明确确认该项不在本轮修改范围 | 仅影响“仿真翻页 shader 实现细节”这一子项；不改变本计划其余功能/排版/交互同义排查口径 | 无；后续仅在需求方再次明确要求时再纳入变更 |
| EX-BLK-EXT-01 | TTS/漫画/朗读等扩展能力 | `2026-02-20` | 暂不实现，保持 `blocked` | 需求方明确要求“扩展暂时不做” | 扩展相关入口/流程/配置仅做台账追踪，不进入实现 | 待需求方明确“开始做扩展功能”后解锁并回补 |

## 验收与证据

### 当前交付（计划变更）验证

- 已完成 `T3`：本计划新增“升级版对照矩阵”（书源管理 + 阅读器核心，覆盖 10 维度）。
- 已完成 `T4`：本计划新增“模块级差异点清单”（含文件位置、原因、影响范围、严重级别、回补去向）。
- 已完成 `T5`：本计划新增“逐项检查清单升级版”（固定输入基线 + 8 维度回填模板 + 四态布局一致性专项）。
- 本次交付仍为文档收敛，不涉及业务代码改动与测试执行。

### 后续执行阶段验证

- 命令验证（提交前）：
  - `flutter analyze`（仅在提交推送前执行一次）
- 手工回归路径（至少）：
  1. 书源管理：列表 -> 搜索/筛选 -> 编辑/登录/启用禁用/删除 -> 导入导出。
  2. 阅读器：打开阅读页 -> 顶栏/底栏/快捷动作 -> 阅读设置 -> 书源动作 -> 换源 -> 章节跳转。
  3. 扩展能力：仅核对 `blocked` 台账与入口状态，不进入实现回归。

## Progress

- [x] T0：口径锁定与计划落盘升级
- [x] T1：legado 书源管理基线全量读取
- [x] T2：legado 阅读器全功能基线全量读取
- [x] T3：对照矩阵建模（升级版）
- [x] T4：迁移前差异点清单输出（强制门禁）
- [x] T5：逐项检查清单落盘（升级版）
- [ ] T6A：书源管理同义迁移与核验
- [ ] T6B：阅读器核心功能同义迁移与核验
- [ ] T6C：扩展能力冻结追踪（TTS/漫画/朗读，`blocked`）
- [ ] T7：排版与交互专项验收
- [ ] T8：阻塞例外统一收口
- [ ] T9：回归证据与提交前检查
- [x] T10：文档与索引同步（持续执行）

## Surprises & Discoveries

- 发现已有阅读器计划多为子专题闭环，无法直接支撑“书源管理 + 阅读器全功能”的一次性验收结论。
- 需求方在 `2026-02-20` 明确确认：“仿真翻页使用的 shader 不需要修改”，该项已作为例外 `EX-CF-01` 落盘。
- 需求方在 `2026-02-20` 追加确认：TTS/漫画/朗读等扩展当前阶段暂不做，统一 `blocked`。
- 书源管理在 legado 中实际是“双栈”（BookSource + RSS Source）并共用登录/分组/导入导出语义，`T1` 已将 RSS 一并纳入基线读取范围。
- 阅读器“换源/章节换源 + 书源动作（登录/章节购买/编辑/禁用）”在 legado 中属于核心链路，不是扩展链路，`T2` 已纳入主基线。
- `O-04 Step1` 已完成 5 项 MoreConfig 核心配置闭环（方向/导航栏/滚轮/长按按键/返回键）；`selectText` 仍留待下一子任务。
- `T3` 建模发现 RSS 管理链路存在结构性缺口：仅覆盖基础列表能力，未覆盖 legado 的导入与批量菜单族（`rss_source.xml` / `rss_source_sel.xml`）。
- `T3` 建模确认阅读器仍有三类未收敛项：`EX-SA-01/EX-SA-02`（章节购买链路）+ `O-04` 剩余配置键 + 9 宫格动作执行器未全量落地。
- `T5` 落盘时确认：后续 `T6A/T6B` 若未回填“加载/空态/错误/成功”四态布局检查，任务状态不得标记完成。

## Decision Log

- 决策 1（2026-02-20，已被决策 6 覆盖）：曾将“所有功能排查”解释为扩展解锁。
  - 说明：该解释在需求方追加“扩展暂不做”后失效，当前以决策 6 为准。
- 决策 2（2026-02-20）：以本计划作为主计划，既有阅读器子计划继续作为执行分支，不并行创建重复主计划。
  - 理由：避免索引分裂与状态冲突，保证阻塞项统一收口。
- 决策 3（2026-02-20）：当前交付仅修改计划，不提前执行 `flutter analyze`。
  - 理由：遵守仓库“提交推送前执行一次”的硬约束。
- 决策 4（2026-02-20）：将“仿真翻页 shader 不修改”作为需求方确认例外 `EX-CF-01` 固化到主计划。
  - 理由：避免后续执行分支将该项误判为待整改差异。
- 决策 5（2026-02-20）：将需求方确认的 `T0~T10` 作为唯一主追踪清单，并将 `Progress` 切换为 Todo 维度。
  - 理由：避免旧 `Step` 编号与新执行口径并存导致追踪歧义。
- 决策 6（2026-02-20）：将 TTS/漫画/朗读等扩展能力纳入 `EX-BLK-EXT-01`，当前阶段统一 `blocked`。
  - 理由：按需求方最新指令，先聚焦核心能力与排版交互同义收敛。
- 决策 7（2026-02-20）：`T1` 书源管理基线范围明确包含 `BookSource + RSS Source + 登录链路 + 校验配置`。
  - 理由：SoupReader “书源管理”入口同样覆盖两类书源，若只读 BookSource 会导致入口级对照遗漏。
- 决策 8（2026-02-20）：`T2` 在当前阶段对扩展能力执行“只读基线，不做实现”。
  - 理由：满足“先完整读取 legado 再下结论”的前置规则，同时遵守 `EX-BLK-EXT-01` 的冻结口径。
- 决策 9（2026-02-20）：Step 1 输出采用“文件组映射 + 入口层级图”作为 `T3` 对照矩阵的唯一输入基线。
  - 理由：降低跨子计划口径漂移，确保后续差异点清单可追溯。
- 决策 10（2026-02-20）：`O-04` 采用“核心项先行”拆分策略，先完成 `Step1`（方向/系统栏/按键），`selectText/customPageKey` 进入下一子任务。
  - 理由：控制单次改动面，确保本轮可交付点具备完整测试证据并降低回归风险。
- 决策 11（2026-02-20）：`T4` 严重级别分级采用“高/中高/中/低”，并将 `RSS 导入/批量缺口` 与 `章节购买阻塞` 列为同级高优先级。
  - 理由：这两类问题直接影响“入口层级同义”与“核心动作可执行”验收。
- 决策 12（2026-02-20）：`T5` 以 `T4-01~T4-08` 为唯一输入，先做检查表落盘再进入 `T6A/T6B` 实施。
  - 理由：防止实现阶段再次出现无台账偏航。
- 决策 13（2026-02-20）：`T5` 固化为“输入基线 + 维度模板 + 四态布局专项 + 结论口径”四段结构，作为 `T6A/T6B/T7` 的唯一回填骨架。
  - 理由：确保并行分支在同一验收语言下执行，降低排版/交互语义漂移风险。

## Outcomes & Retrospective

- 已完成主计划重建：将排查范围升级为“书源管理 + 阅读器所有功能”。
- 已完成例外落盘：`EX-CF-01`（仿真翻页 shader 不修改）已写入台账。
- 已完成扩展冻结落盘：`EX-BLK-EXT-01`（TTS/漫画/朗读暂不做）已写入台账。
- 已完成 Todo 落盘：`T0~T10`（含排版交互同义验收）已写入主计划并启用状态追踪。
- 已完成 `T1/T2`：基线文件清单、映射表、入口层级图已回填，可直接进入 `T3/T4`。
- 已完成 `T3`：书源管理与阅读器核心的 10 维度对照矩阵已落盘。
- 已完成 `T4`：模块级差异点清单（含严重级别与回补去向）已落盘。
- 已完成 `T5`：逐项检查清单升级版已落盘，`T6A/T6B` 具备统一回填模板与四态布局门禁。
- 已完成 `O-04 Step1` 子计划：阅读器 MoreConfig 核心 5 项已闭环，定向测试通过。
- 已明确串并行执行顺序与 owner 分工，后续可直接按步骤推进。
- 下一可交付点为 `T6A/T6B`：按 `T5` 模板分别推进书源管理与阅读器核心同义迁移，并逐项回填证据。
