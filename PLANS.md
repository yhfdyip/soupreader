# SoupReader ExecPlans

## 任务：legado 功能按钮/排版/交互迁移（先做按钮与交互占位）

- 状态：`active`
- 优先级：`P0`
- 创建日期：`2026-02-20`
- 任务类型：迁移级别（跨模块、跨层、含大量交互语义对齐）
- 目标口径：以 `../legado` 为第一标准，先完成“按钮存在 + 排版同义 + 交互逻辑同义（含状态流转/边界处理/取消清理/错误反馈）”，真实业务实现后置。

### 1) 背景与目标

当前需求是先把 `soupreader` 的 UI 入口层与 legado 保持同义：  
1. 所有 legado 按钮要在 soupreader 有对应入口（含主入口、页面菜单、弹窗/Sheet、列表项快捷操作）。  
2. 所有入口要有交互反馈（导航/弹窗/ActionSheet/占位提示），不能点了没反应。  
3. 排版与交互热区语义对齐 legado（平台组件差异允许，但信息层级、操作顺序、可达路径一致）。  
4. 交互逻辑语义对齐 legado（状态流转、边界处理、取消/清理、错误提示与可观测输出）。  
5. 暂不要求真实业务逻辑等价，只做“入口与交互壳 + 交互状态语义”完整迁移。

### 2) 范围、非目标、成功标准

- 范围（本阶段）：
  - `main` 主入口与各功能页菜单、ActionSheet、弹窗入口。
  - 五段链路入口：`search/explore/bookInfo/toc/content`。
  - 书源管理、RSS、阅读器、设置、规则管理相关按钮入口。
  - 按钮文案、排序、分组、可见性条件、点击反馈。
  - 页面配置项与输入控件（文本输入、选择器、开关、校验提示、保存/取消触发）。
  - 排版结构与交互热区一致性检查。
- 非目标（本阶段不做）：
  - 真实网络/解析/同步/导入导出等业务逻辑完全等价实现。
  - 非必要的视觉风格像素级一致（仅要求语义一致）。
- 成功标准：
  - legado 菜单项全集（`res/menu`）在 soupreader 均有“可见入口 + 可触发反馈”。
  - 每个入口完成逐项检查：`入口/状态/异常/文案/排版/交互触发`。
  - 配置页与输入流程具备同义交互：可编辑、可取消、可保存、错误可见。
  - 页面级交互逻辑同义：状态流转、边界、取消/清理、错误反馈与日志语义一致。
  - 输出差异点清单与逐项对照清单，不使用笼统“已一致”表述。

### 3) 差异点清单（计划期基线）

> 本节为执行前基线，后续每完成一个批次必须更新为“已同义/保留差异/blocked”。

| 差异ID | legado 位置 | soupreader 位置 | 原因 | 影响 |
|---|---|---|---|---|
| D-001 | `../legado/app/src/main/res/menu/*.xml`（90 个文件，410 个 `<item>`） | 无统一“菜单基线清单”文件 | 迁移过程尚未建立“全量按钮账本” | 高风险遗漏按钮、顺序与可见性偏差 |
| D-002 | `main_bookshelf.xml/main_explore.xml/main_rss.xml/main_my.xml` | `lib/main.dart` + 各 tab 页面 | 主入口已分散到多文件，未有一对一映射文档 | 入口层级/点击行为可能偏移 |
| D-003 | `book_*`（搜索、详情、目录、阅读） | `lib/features/search/*`, `lib/features/reader/*`, `lib/features/bookshelf/*` | 多处菜单已实现，但仍存在占位与语义待核对项 | 五段链路交互可能“有按钮但行为非同义” |
| D-004 | `source_*`/`book_source_*` | `lib/features/source/*` + `lib/features/settings/views/source_management_view.dart` | 书源管理入口多、条件分支多，需逐项映射 | 高概率出现批量操作/筛选项遗漏 |
| D-005 | `rss_*` | `lib/features/rss/*` | RSS 主流程可见，但菜单粒度较多 | 组筛选/快捷操作语义可能不齐 |
| D-006 | `theme_*`, `dict_*`, `replace_*`, `txt_*`, `speak_*` 等 | `lib/features/settings/*`, `lib/features/replace/*` | 存在 `showNotImplemented` 占位分布 | 若未建立“占位交互标准”，易出现触发不一致 |
| D-007 | legado 多处 Toolbar/Menu + 对话框布局 | soupreader 各页面 `CupertinoActionSheet`/Dialog | 当前无“排版一致性核对矩阵” | 同功能在不同状态下可能单页走样 |

### 4) 基线事实（用于排期估算）

- legado 菜单文件数：`90`
- legado 菜单项总数：`410`
- legado 布局文件数（`res/layout`）：`183`
- soupreader `lib/features` Dart 文件数：`158`
- soupreader `*view*.dart` 文件数：`50`

### 5) 逐项检查清单模板（每个按钮必填）

每个按钮/入口在迁移核对时必须填写以下 6 项：

1. 入口：位于哪个页面/菜单/弹窗，层级是否同义。
2. 状态：默认/选中/禁用/加载中/空态是否同义。
3. 异常：触发失败时是否有可观测反馈（toast/dialog/log）。
4. 文案：按钮名称与业务语义是否同义。
5. 排版：位置、顺序、间距、热区、分组是否同义。
6. 交互触发：点击后是否进入同义路径（页面/弹窗/占位流程）。
7. 输入（补充）：默认值、校验、保存/取消、错误提示是否同义。
8. 交互逻辑（补充）：状态流转、边界处理、取消/清理、错误输出是否同义。

### 6) 详细 Todo（依赖 + 串并行 + Owner）

> 规则：迁移级别任务第 1 项必须先输出差异点清单；未完成前不启动实现分支。  
> 说明：`Owner-A/B/C` 为并行分工标签；若单人执行则按顺序串行完成。

| ID | 状态 | 类型 | 并行性 | 依赖 | Owner | 任务 | 交付物 | 验证方式 |
|---|---|---|---|---|---|---|---|---|
| T00 | done | 核心 | 串行 | 无 | A | 建立菜单基线统计（menu 文件与 item 总量） | 菜单基线数据（90/410） | 命令输出可复现 |
| T01 | done | 核心 | 串行 | T00 | A | 产出“差异点清单 v1”（含文件位置、原因、影响） | 本 ExecPlan 第 3 节 | 人工复核 |
| T02 | done | 核心 | 串行 | T01 | A | 建立“legado 按钮总台账”（410 项逐条） | `docs/migration/button-audit/legacy-button-ledger.md` | 抽样核对 20 项 |
| T03 | done | 核心 | 串行 | T02 | A | 建立“soupreader 入口台账”（按页面列按钮） | `docs/migration/button-audit/soupreader-button-ledger.md` | 页面抽样点击 |
| T04 | done | 核心 | 串行 | T03 | A | 生成一对一映射表（legacy -> soupreader） | `docs/migration/button-audit/button-mapping.csv` | 全量无空映射 |
| T05 | done | 核心 | 串行 | T04 | A | 定义统一占位交互规范（弹窗/Toast/导航） | `docs/migration/button-audit/placeholder-interaction-spec.md` | 5 个模块抽检 |
| T05A | done | 核心 | 串行 | T05 | A | 建立配置/输入核对矩阵（字段、默认值、校验、保存/取消） | `docs/migration/button-audit/config-input-audit-matrix.md` | 抽样 20 条输入流程 |
| T06 | done | 核心 | 串行 | T05A | A | 主入口迁移（底栏 + 顶栏）按钮/交互/排版同义 | `docs/migration/button-audit/main-4tab-checklist.md` | 手工回归路径 M1 |
| T07 | done | 核心 | 可并行 | T06 | A | 五段链路-搜索（search）按钮与交互同义 | search 对照清单 | 手工回归路径 C1 |
| T08 | done | 核心 | 可并行 | T06 | B | 五段链路-发现（explore）按钮与交互同义 | explore 对照清单 | 手工回归路径 C2 |
| T09 | done | 核心 | 可并行 | T06 | C | 五段链路-详情（bookInfo）按钮与交互同义 | bookInfo 对照清单 | 手工回归路径 C3 |
| T10 | done | 核心 | 可并行 | T06 | A | 五段链路-目录（toc）按钮与交互同义 | toc 对照清单 | 手工回归路径 C4 |
| T11 | active | 核心 | 可并行 | T06 | B | 五段链路-正文（content/reader）按钮与交互同义 | content 对照清单 | 手工回归路径 C5 |
| T12 | pending | 核心 | 可并行 | T07,T08,T09,T10,T11 | C | 书源管理按钮全量迁移（list/edit/debug/login） | source 对照清单 | 手工回归路径 S1 |
| T13 | pending | 核心 | 可并行 | T07,T08,T09,T10,T11 | A | RSS 按钮全量迁移（订阅/源管理/文章/阅读） | rss 对照清单 | 手工回归路径 R1 |
| T14 | pending | 核心 | 可并行 | T07,T08,T09,T10,T11 | B | 替换规则/目录规则/字典规则入口同义 | rules 对照清单 | 手工回归路径 X1 |
| T15 | blocked | 扩展 | 串行 | T12,T13,T14 | A | 设置扩展入口（语音/广告屏蔽/主题扩展等）逐项同义 | settings 扩展对照清单 | 需指令解锁 |
| T16 | pending | 核心 | 串行 | T12,T13,T14 | A | 全局排版一致性复核（加载/空态/错误/成功） | 排版核对矩阵 | 截图对照 |
| T16A | pending | 核心 | 串行 | T12,T13,T14 | A | 全局交互逻辑一致性复核（状态流转/边界/取消清理/错误） | 交互逻辑核对矩阵 | 手工路径 + 调试日志对照 |
| T17 | pending | 核心 | 串行 | T16,T16A | A | 输出“逐项对照清单 v1”（已同义/差异/原因） | `docs/migration/button-audit/final-compare-checklist.md` | 全量核对 |
| T18 | pending | 核心 | 串行 | T17 | A | 仅在提交前执行一次 `flutter analyze` | analyze 结果记录 | 命令验证 |

### 7) 分批实施步骤（每步预期结果 + 验证）

#### Step A：台账与映射（T02-T05A）

- 预期结果：
  - 有完整 legacy 按钮总台账（410 项）。
  - 有 soupreader 当前入口台账。
  - 有逐项映射表与“缺失/待补/已同义”状态。
  - 有配置/输入核对矩阵（覆盖编辑、校验、保存、取消）。
- 验证：
  - 随机抽查：主入口、搜索、阅读器、书源管理、设置各至少 20 条。
  - 映射表无空主键（legacy menu + item id）。

#### Step B：核心主链路入口同义（T06-T11）

- 预期结果：
  - 五段链路入口全部可触发。
  - 菜单顺序、文案语义、交互路径同义。
  - 关键交互逻辑同义（切换状态、失败重试、取消关闭、异常提示）。
  - 未实现业务均走统一占位交互规范。
- 验证：
  - 手工回归 C1-C5 全通过。
  - 每条按钮均填完 6 项检查。

#### Step C：外围核心模块（T12-T14）

- 预期结果：
  - 书源、RSS、规则类入口无遗漏。
  - 批量操作、筛选、更多菜单均有同义触发。
- 验证：
  - source/rss/rules 三条回归路径全通过。
  - 对照清单中“未覆盖项”数量为 0。

#### Step D：扩展冻结与解锁（T15）

- 规则：
  - 默认 `blocked`，等待需求方明确“开始做扩展功能”后再执行。
- 解锁后验证：
  - 扩展入口依旧满足 6 项检查模板。

#### Step E：总验收与收口（T16-T18）

- 预期结果：
  - 排版一致性矩阵完成。
  - 交互逻辑一致性矩阵完成。
  - 逐项对照清单可追踪每个 legacy 按钮状态。
  - 提交前执行且仅执行一次 `flutter analyze`。

### 8) 风险与回滚

- 风险 R1：按钮过多导致遗漏。
  - 缓解：必须以“410 项台账”为唯一验收主键。
  - 回滚：发现漏项立即回退对应模块合并，补齐台账后再提审。
- 风险 R2：排版一致性在特殊状态（空态/错误态）走样。
  - 缓解：强制四状态截图核对。
  - 回滚：保留差异记录并阻塞状态置 `blocked`，先修复后继续。
- 风险 R3：扩展入口提前落地导致违反“核心优先”。
  - 缓解：扩展任务统一标 `blocked`。
  - 回滚：移除提前实现入口，恢复为阻塞状态并记录决策。
- 风险 R4：无法确认 legado 对应行为。
  - 缓解：按规范暂停并记录例外。
  - 回滚：执行 `blocked` 流程，不继续主流程编码。
- 风险 R5：按钮在，但交互状态逻辑不一致（例如取消路径/异常分支偏差）。
  - 缓解：新增 T16A 交互逻辑核对矩阵，逐条记录状态流转和边界行为。
  - 回滚：发现偏差即回退至该模块修正，不进入最终对照清单完成态。

### 9) 验收与证据

- 命令验证：
  - 开发过程不执行 `flutter analyze`。
  - 提交前仅执行一次：`flutter analyze`。
- 手工回归路径：
  - M1 主入口：底栏四 tab -> 各页顶部菜单 -> 主要二级入口。
  - C1 搜索：搜索页菜单 -> 书籍详情 -> 编辑入口。
  - C2 发现：分组筛选 -> 源操作 -> 二级发现结果。
  - C3 详情：详情页菜单（编辑/分享/变量/日志等）触发检查。
  - C4 目录：目录搜索/排序/导出/规则入口。
  - C5 正文：阅读菜单/更多菜单/书源菜单/快捷设置。
  - S1 书源：列表批量操作/单项操作/调试入口。
  - R1 RSS：分组筛选/源管理/订阅阅读入口。
  - X1 规则：替换/字典/目录规则页面入口与菜单。

### 10) Progress（动态）

- `2026-02-21`（本轮）
  - T11 第十六批收敛：阅读器正文密度与菜单分层对齐 legado，修复“内容不满 + 配置态遮挡偏重 + 顶底与正文混淆”。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/models/reading_settings.dart`、`lib/features/reader/views/simple_reader_view.dart`、`lib/features/reader/widgets/reader_menus.dart`、`lib/features/reader/widgets/reader_bottom_menu.dart`、`test/reading_settings_test.dart`、`docs/plans/2026-02-21-reader-density-overlay-legado-parity-execplan.md`。
    - 关键实现：
      - `ReadingSettings` 新增 `layoutPresetVersion`（v1->v2）和旧默认值迁移规则；仅迁移“仍为旧默认”的字段，保留用户自定义值。
      - 正文默认参数对齐 legado v2：字号/行距/段距/正文边距收敛，提高单屏内容密度。
      - `ReaderTopMenu` 收敛为实体背景层 + 下边界 + 阴影，减少正文穿透。
      - `ReaderBottomMenuNew` 提升面板实体度并增加滑杆/入口分隔线，强化底栏与正文层级。
      - `ReadStyle/MoreConfig/TipConfig` 弹层 barrier 改为透明；ReadStyle/TipConfig 高度收敛至 0.74 屏高语义，减轻配置态遮挡。
  - 本轮实施记录：
    - 做了什么：完成默认排版迁移、菜单视觉分层和配置态遮挡收敛的联动改造。
    - 为什么：用户明确要求参考图观感与 legado 语义一致，重点是“正文优先 + 配置低干扰”。
    - 如何验证：
      - `flutter test test/reading_settings_test.dart test/simple_reader_view_compile_test.dart test/reader_top_menu_test.dart test/reader_bottom_menu_new_test.dart test/app_settings_test.dart`（通过）
    - 兼容影响：低到中。`ReadingSettings` 增加版本字段并触发一次性旧默认迁移；不涉及数据库结构与书源链路。
  - T11 当前状态：保持 `active`。本批次完成正文密度/菜单分层核心收敛，后续仅剩真机视觉回归与截图补证。

- `2026-02-21`（本轮）
  - T11 第十五批收敛：边距设置弹窗与信息设置弹窗按 legado 语义收口，并补齐页眉分割线默认值兼容。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/widgets/reader_padding_config_dialog.dart`、`lib/features/reader/views/simple_reader_view.dart`、`lib/features/reader/models/reading_settings.dart`、`PLANS.md`。
    - 关键实现：
      - 新增并接入 `ReaderPaddingConfigDialog`：结构改为 legado 平铺分段（页眉/正文/页脚 + 分割线开关 + 四向滑杆），去除卡片化与额外标题栏。
      - `SimpleReaderView._showLegacyTipConfigDialog` 收敛为 legacy 列表结构；正文标题由二级选择弹层改为内联单选分段，贴齐 `TipConfigDialog` 的 RadioGroup 语义。
      - `ReadingSettings.fromJson` 将 `showHeaderLine` 缺省回退修正为 `false`，与 legado 默认和本地构造默认一致，避免旧配置缺字段时出现分割线误显。
  - 本轮实施记录：
    - 做了什么：完成边距/信息两弹窗迁移收口，并修复配置兼容默认值偏差。
    - 为什么：用户要求“与 legado 一致”；此前存在样式卡片化、标题模式交互路径不一致，以及 `showHeaderLine` 默认值漂移问题。
    - 如何验证：
      - `flutter test test/simple_reader_view_compile_test.dart --concurrency=1`（通过）
      - `flutter test test/reader_top_menu_test.dart --concurrency=1`（通过）
      - `flutter test test/reader_bottom_menu_new_test.dart --concurrency=1`（通过）
      - 手工路径：C5（阅读器 -> 菜单 -> 边距/信息弹窗）待真机回归补图。
    - 兼容影响：低。仅调整阅读器配置弹窗结构与默认值兼容，不改书源协议、目录解析与正文分页主链路。
  - T11 当前状态：保持 `active`。本批次已完成弹窗收口，剩余差异继续按 C5 清单推进。

- `2026-02-21`（本轮）
  - T11 第十四批收敛：阅读页日/夜配色与浮层层级收敛，修复“夜间底栏发白 + 多层透明叠加压正文”的偏差。
  - T11 代码收敛：
    - 代码变更：`lib/app/theme/design_tokens.dart`、`lib/features/reader/views/simple_reader_view.dart`、`lib/features/reader/widgets/reader_bottom_menu.dart`、`lib/features/reader/widgets/reader_menus.dart`、`PLANS.md`。
    - 关键实现：
      - 新增 `ReaderOverlayTokens` 统一阅读浮层色板（panel/card/border/text）并在阅读页复用，避免分散 hardcode 导致日夜不一致。
      - `ReaderThemeTokens` 收敛：日间改为更稳定纸色轴（`#F7F4EE`），夜间正文/分割色对齐 legacy 语义（`text #ADADAD`）。
      - `SimpleReaderView` 新增 `_menuFollowPageTone`，将“阅读菜单样式随页面”限制为“仅纯色背景生效”，与 legacy `readBarStyleFollowPage && curBgType==0` 一致。
      - 右侧快捷栏与搜索浮层降低透明叠加噪点（提高基底不透明度、收敛强调色 alpha），提升正文主次。
      - `ReaderBottomMenuNew/ReaderTopMenu` 去除对 Shad 运行时色板的强依赖，改为“阅读主题暗亮度 + 统一浮层 token”驱动，避免夜间出现反向浅底。
  - 本轮实施记录：
    - 做了什么：重构阅读页日夜配色 token 与菜单着色链路，统一顶部菜单、底部菜单、右侧快捷栏、搜索浮层的层级规则。
    - 为什么：legacy 阅读菜单在“是否跟随页面”“夜间明暗约束”上有明确语义；现有实现混用 `ShadTheme` 与局部 alpha 叠加，导致夜间控件层反白、长读干扰正文。
    - 如何验证：
      - `flutter test test/reader_bottom_menu_new_test.dart --concurrency=1`（通过）
      - `flutter test test/reader_top_menu_test.dart --concurrency=1`（通过）
      - `flutter test test/simple_reader_view_compile_test.dart --concurrency=1`（通过）
      - 手工路径：C5（阅读器 -> 切换日间/夜间 -> 打开顶部菜单/右侧快捷栏/底部菜单/搜索面板）待真机回归补图。
    - 兼容影响：低。仅收敛阅读器 UI 颜色与浮层透明度策略，不改数据库、书源规则、同步协议与正文分页逻辑。
  - T11 当前状态：保持 `active`。阅读页配色层级已收敛，剩余差异聚焦图片分页与极端慢源场景（非本批次）。

- `2026-02-21`（本轮）
  - T11 第十三批收敛：更新 `docs/migration/button-audit/content-c5-checklist.md`，回补“失败类型分层采样 + 按书源预算策略”证据，并收敛图片样式保留差异口径。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/views/simple_reader_view.dart`、`docs/migration/button-audit/content-c5-checklist.md`、`PLANS.md`。
    - 关键实现：
      - 探测结果三态：`SimpleReaderView` 为图片尺寸探测新增 `_ReaderImageSizeProbeResult/_ReaderImageBytesProbeResult`，统一承载“是否实际探测 + 失败类型 + 成功尺寸”。
      - 失败类型分层：新增 `timeout/auth/decode/other` 分类，合并 `ImageProvider.resolve` 与 source-aware 双阶段探测的失败信号，避免仅用“空结果”统计导致调参失真。
      - 书源粒度遥测：新增 `_ReaderImageWarmupSourceTelemetry`，按 source URL 记录 success/timeout/auth/decode EMA 与连续失败计数。
      - 预算策略增强：`_resolveImageWarmupBudget` 接入 source-level 遥测，在连续超时/鉴权/解码失败时动态增配探测数量、总时窗与单次超时；高成功率场景自动回收预算，避免长期过配。
  - 本轮实施记录：
    - 做了什么：补齐“失败类型分层采样 + 按书源粒度预算”闭环，并将其接入现有预热探测链路。
    - 为什么：legacy `TextChapterLayout/ChapterProvider + ImageProvider.getImageSize` 的尺寸确定性来自持续探测与失败后继续收敛；现有实现虽有长图误差与章节耗时自适应，但缺少“失败性质”与“源站差异”两个维度，尾部慢源仍易反复估算分页。
    - 如何验证：
      - `flutter test test/simple_reader_view_compile_test.dart test/paged_reader_widget_non_simulation_test.dart test/paged_reader_widget_simulation_image_test.dart test/reader_image_marker_codec_test.dart test/reader_image_request_parser_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 图片样式 -> 慢源/鉴权/异常图片章节）已回填 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：中低。仅增强阅读器图片尺寸探测遥测与预算调参，不改数据库结构、WebDav 协议与菜单语义；探测失败仍按既有估算兜底，不阻断阅读主链路。
  - T11 当前状态：保持 `active`。失败分层与 source-level 预算已补齐，剩余差异聚焦“极端不可达慢源（双阶段探测持续失败）时的首帧真实尺寸确定性”。

- `2026-02-21`（本轮）
  - T11 第十二批收敛：更新 `docs/migration/button-audit/content-c5-checklist.md`，回补“source-aware 探测结果跨章节持久化 + 长图首帧误差采样收敛”证据，并收敛图片样式保留差异口径。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/services/reader_image_marker_codec.dart`、`lib/core/services/settings_service.dart`、`lib/features/reader/views/simple_reader_view.dart`、`lib/features/reader/widgets/paged_reader_widget.dart`、`test/reader_image_marker_codec_test.dart`、`test/app_settings_test.dart`、`docs/migration/button-audit/content-c5-checklist.md`。
    - 关键实现：
      - 尺寸缓存持久化：`ReaderImageMarkerCodec` 新增尺寸缓存 URL 级 key 归一化、LRU 管理与快照导入/导出；`SettingsService` 新增书籍级快照读写接口。
      - 阅读器接入闭环：`SimpleReaderView` 启动时恢复书籍快照，尺寸命中变化后防抖落盘，退出阅读时强制刷盘，保证“跨章节 + 重进会话”复用。
      - 长图误差采样：阅读期记录长图“首帧估算 vs 实际”误差并形成 EMA，`_resolveImageWarmupBudget` 根据误差样本自动增配探测张数/时窗/单次超时。
      - 渲染回写增强：`PagedReaderWidget` 新增 `onImageSizeResolved` 回调，阅读层可在图片解码成功后同步更新误差采样与持久化计划。
  - 本轮实施记录：
    - 做了什么：把图片尺寸缓存从“纯内存会话态”升级为“书籍级快照持久化 + 启动恢复”，并补齐长图误差到预算策略的反馈通道。
    - 为什么：legacy `BookHelp.saveImages + ImageProvider.getImageSize` 具备跨章节可复用特性；现有实现在重进阅读后命中率会冷启动回落，且长图偏差未反馈到探测预算，导致慢源下易重复估算分页。
    - 如何验证：
      - `flutter test test/reader_image_marker_codec_test.dart test/app_settings_test.dart test/simple_reader_view_compile_test.dart test/paged_reader_widget_non_simulation_test.dart test/paged_reader_widget_simulation_image_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 图片样式 -> 连续切章 -> 退出重进 -> 慢源长图）已回填 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：中低。仅增强阅读器图片尺寸缓存与预算策略，不改数据库结构、WebDav 协议与菜单语义；快照解析/落盘失败均按兜底路径回退，不阻断阅读主链路。
  - T11 当前状态：保持 `active`。跨章节持久化与长图误差采样已补齐，剩余差异聚焦“连续超时/偶发鉴权失败下的全量首帧真实尺寸确定性”。

- `2026-02-21`（本轮）
  - T11 第十一批收敛：更新 `docs/migration/button-audit/content-c5-checklist.md`，回补“source-aware 失败重试 + 长图尺寸提示增强”证据，并收敛图片样式保留差异口径。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/views/simple_reader_view.dart`、`docs/migration/button-audit/content-c5-checklist.md`。
    - 关键实现：
      - source-aware 探测重试：`_resolveImageIntrinsicSizeFromSourceAwareFetch` 从“单次回退”升级为“两段探测（`SourceCoverLoader` 缓存链路 + `RuleParserEngine.fetchCoverBytes` 直连重试）”，并按单次 warmup budget 切分超时窗口。
      - 相对 URL 探测补齐：source-aware 探测不再强依赖 `http(s)` 绝对 URL，允许 legacy 链路下的相对地址进入书源感知请求流程。
      - 长图提示增强：图片 marker 维度提示补齐 `style aspect-ratio` 推导与 URL query/CDN `w_*/h_*` 参数解析，提升“未命中真实尺寸时”的首帧比例估算精度。
      - 预热执行收敛：`_warmupPagedImageSizeCache` 调整为“provider 探测可选 + source-aware 探测必经回退”，避免 provider 不可用时直接跳过尺寸预热。
  - 本轮实施记录：
    - 做了什么：把图片尺寸探测从“单次 source-aware 回退”升级为“可重试探测”，并增强 marker 尺寸提示来源，收敛极端长图首帧分页误差。
    - 为什么：legacy `TextChapterLayout/ChapterProvider` 在分页阶段直接消费真实图片尺寸；现有实现虽已具备预热，但在慢源、相对 URL 与长图场景仍存在“单次失败即估算”的偏差。
    - 如何验证：
      - `flutter test test/simple_reader_view_compile_test.dart test/reader_image_request_parser_test.dart test/reader_image_marker_codec_test.dart test/paged_reader_widget_non_simulation_test.dart test/paged_reader_widget_simulation_image_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 阅读操作 -> 图片样式 -> 慢源/鉴权/长图章节）已回填 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：中低。仅增强阅读器图片尺寸探测与 marker 提示链路，不改数据库结构、WebDav 协议与菜单语义；探测失败仍保留估算兜底，不阻断阅读主流程。
  - T11 当前状态：保持 `active`。source-aware 重试与长图提示已补齐，剩余差异聚焦“超慢源/偶发鉴权失败下的全量首帧真实尺寸确定性”。

- `2026-02-21`（本轮）
  - T11 第十批收敛：更新 `docs/migration/button-audit/content-c5-checklist.md`，回补“鉴权图片尺寸探测补齐 + 预热窗口自适应”证据，并补齐 `url,{option}` header 语义。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/views/simple_reader_view.dart`、`lib/features/reader/widgets/paged_reader_widget.dart`、`lib/features/reader/services/reader_image_request_parser.dart`、`test/reader_image_request_parser_test.dart`、`docs/migration/button-audit/content-c5-checklist.md`。
    - 关键实现：
      - 图片请求解析器：新增 `ReaderImageRequestParser`，解析 legacy `url,{option}` 并提取 `headers`，补齐图片链路对 URL option 的语义保留。
      - 阅读器 provider 头部收敛：`SimpleReaderView/PagedReaderWidget` 的网络图片 provider 改为合并 `source.header + option header`；阅读器侧新增 CookieJar 缓存注入与 `Referer/Origin` 缺省补齐。
      - 鉴权尺寸回退探测：`_warmupPagedImageSizeCache` 在 `ImageProvider.resolve` 失败后，新增 source-aware 字节探测（`SourceCoverLoader.fetchCoverBytes`）并解码真实尺寸写回缓存。
      - 预热窗口自适应：基于“最近章节请求耗时 + 书源 respondTime + 登录态”动态放宽预热预算（探测张数/总时窗/单次超时），替代固定 180~260ms。
  - 本轮实施记录：
    - 做了什么：把“图片尺寸探测”从纯 `NetworkImage` 探测扩展为“provider 探测 + source-aware 回退”，并把固定预热窗口改为自适应预算。
    - 为什么：legacy 分页阶段会复用书源 Header/Cookie 与 URL option 获取图片尺寸；现有实现在鉴权图和慢源场景命中率不足，跨章节首帧仍易回落估算分页。
    - 如何验证：
      - `flutter test test/reader_image_request_parser_test.dart test/simple_reader_view_compile_test.dart test/reader_image_marker_codec_test.dart test/paged_reader_widget_non_simulation_test.dart test/paged_reader_widget_simulation_image_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 阅读操作 -> 图片样式 -> 含鉴权图片章节）已回填 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：中低。仅增强图片请求与尺寸探测链路，不改数据库结构、WebDav 协议与菜单语义；探测失败仍回退估算分页，不阻断阅读主流程。
  - T11 当前状态：保持 `active`。鉴权尺寸探测与慢源预算已补齐，剩余差异聚焦“极端长图在超时兜底下的首帧断点精度”。

- `2026-02-21`（本轮）
  - T11 第九批收敛：更新 `docs/migration/button-audit/content-c5-checklist.md`，回补“跨章节尺寸命中复用”证据，并收敛图片分页保留差异口径。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/views/simple_reader_view.dart`、`docs/migration/button-audit/content-c5-checklist.md`。
    - 关键实现：
      - 图片预热参数收敛：新增 `_chapterLoadImageWarmup*` 与 `_prefetchImageWarmup*` 常量，统一“当前章预热/邻章预热”窗口配置。
      - 邻章预取链路补齐预热：`_prefetchChapterIfNeeded` 在章节后处理完成后，执行轻量 `_warmupPagedImageSizeCache`（最多 6 张 / 180ms），提前为相邻章节落图片尺寸缓存。
      - 预取刷新边界收敛：仅在“邻章正文新拉取”或“replace stage 发生变化”时刷新 `PageFactory`，避免无差异重复重排。
  - 本轮实施记录：
    - 做了什么：把图片尺寸预热从“仅当前章节加载”扩展到“邻章预取阶段”，提升跨章节切换时的首帧真实尺寸命中率。
    - 为什么：legacy 在章节布局链路中会提前准备图片资源并按真实尺寸分页；现有实现此前只覆盖当前章预热，邻章虽已预取正文但仍可能首帧回落估算分页。
    - 如何验证：
      - `flutter test test/simple_reader_view_compile_test.dart test/reader_image_marker_codec_test.dart test/paged_reader_widget_non_simulation_test.dart test/paged_reader_widget_simulation_image_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 阅读操作 -> 图片样式 -> 连续切章）已回填 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：中低。仅调整阅读器预取阶段的尺寸探测与重排触发条件，不改数据库结构、网络协议与书源规则执行链。
  - T11 当前状态：保持 `active`。跨章节尺寸命中率已提升，剩余差异聚焦“鉴权图片/慢源超时导致的首帧估算回退”。

- `2026-02-20`（本轮）
  - T11 第八批收敛：更新 `docs/migration/button-audit/content-c5-checklist.md`，补齐“章节加载期图片尺寸预热”对照证据与保留差异说明。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/views/simple_reader_view.dart`、`docs/migration/button-audit/content-c5-checklist.md`。
    - 关键实现：
      - 新增分页前预热链路：`_loadChapter` 在非滚动模式下先执行 `_warmupPagedImageSizeCache`，对当前章 marker 图执行“尺寸提示入缓存 + 限时尺寸探测（最多 8 张 / 260ms）”，再进入首轮分页。
      - 新增图片尺寸探测器：`_resolveImageIntrinsicSize` 基于 `ImageProvider.resolve` 获取真实宽高，并通过 `_imageSizeWarmupInFlight` 去重并发探测。
      - 维持 legacy 兼容回退：超时/失败仍保留估算分页 + 后续回写重分页路径，避免阻塞阅读主链路。
  - 本轮实施记录：
    - 做了什么：把“图片渲染后回写重分页”前移为“章节加载期预热 + 渲染期回写”双阶段收口，提升首帧分页真实尺寸命中率。
    - 为什么：legacy 在 `TextChapterLayout/ChapterProvider` 分页阶段直接调用 `ImageProvider.getImageSize`，首帧依赖真实尺寸；现有实现仅靠渲染后回写，首帧仍易偏差。
    - 如何验证：
      - `flutter test test/simple_reader_view_compile_test.dart test/reader_image_marker_codec_test.dart test/paged_reader_widget_non_simulation_test.dart test/paged_reader_widget_simulation_image_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 阅读操作 -> 图片样式 -> 翻页模式）已回填 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：中低。仅在章节加载期新增限时尺寸探测，不改数据库/网络协议；探测失败保持原估算回退，不阻断阅读流程。
  - T11 当前状态：保持 `active`。首帧尺寸命中率已提升，剩余差异集中在“慢源/鉴权源导致预热超时时的极端长图分页精度”。

- `2026-02-20`（本轮）
  - T11 第七批收敛：更新 `docs/migration/button-audit/content-c5-checklist.md`，回补“图片尺寸提示/缓存分页 + simulation 图片页不再回退 cover”的对照证据与保留差异说明。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/services/reader_image_marker_codec.dart`、`lib/features/reader/widgets/reader_page_agent.dart`、`lib/features/reader/widgets/paged_reader_widget.dart`、`lib/features/reader/views/simple_reader_view.dart`、`test/reader_image_marker_codec_test.dart`、`test/paged_reader_widget_simulation_image_test.dart`。
    - 关键实现：
      - 图片标记元数据：`ReaderImageMarkerCodec` 从“仅 src”升级为“src + 可选尺寸提示”，并补齐 legacy 旧标记兼容解析、运行时尺寸缓存读写能力。
      - 分页高度策略：`ReaderPageAgent.paginateContent` 对图片块高度改为“运行时实测尺寸缓存 > 标记尺寸提示 > 估算值”，向 legacy `getImageSize` 驱动分页语义收敛。
      - 图片尺寸回写：`PagedReaderWidget` 在图片资源解码成功后回填尺寸缓存，并回调 `SimpleReaderView` 触发一次保进度重分页，减少后续页断点误差。
      - 仿真路径收口：移除 `simulation/simulation2` 遇图片页强制回退 `cover` 分支；图片标记页在仿真快照路径下转占位符绘制，确保仿真动画链路可达且不空白。
  - 本轮实施记录：
    - 做了什么：补齐“图片尺寸元数据 -> 运行时实测缓存 -> 重新分页”的闭环，并恢复 simulation 图片页翻页路径。
    - 为什么：legacy 在分页阶段直接消费真实图片尺寸且不会因图片页降级动画模式；现有实现存在“估算分页 + simulation 回退 cover”偏差。
    - 如何验证：
      - `flutter test test/reader_image_marker_codec_test.dart`（通过）
      - `flutter test test/paged_reader_widget_non_simulation_test.dart`（通过）
      - `flutter test test/paged_reader_widget_simulation_image_test.dart`（通过）
      - `flutter test test/simple_reader_view_compile_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 阅读操作 -> 图片样式 -> simulation/simulation2）已回填至 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：中。图片标记 payload 升级为 JSON 结构并保留旧格式兼容；翻页模式新增尺寸缓存驱动重分页，首次未命中缓存时仍会回落估算高度。
  - T11 当前状态：保持 `active`。`simulation/simulation2` 图片页回退差异已收口；剩余差异聚焦“首帧真实尺寸命中率与极端长图分页精度”。

- `2026-02-20`（本轮）
  - T11 第六批收敛：更新 `docs/migration/button-audit/content-c5-checklist.md`，回补“翻页模式图片样式不再占位回退”的对照证据与保留差异说明。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/services/reader_image_marker_codec.dart`、`lib/features/reader/views/simple_reader_view.dart`、`lib/features/reader/widgets/page_factory.dart`、`lib/features/reader/widgets/reader_page_agent.dart`、`lib/features/reader/widgets/paged_reader_widget.dart`、`test/reader_image_marker_codec_test.dart`、`test/paged_reader_widget_non_simulation_test.dart`。
    - 关键实现：
      - 正文后处理链路：翻页模式下非 `TEXT` 图片样式不再直接替换为 `▣`，改为可逆图片标记（`ReaderImageMarkerCodec`），保留图片来源信息进入分页层。
      - 分页器回补：`ReaderPageAgent.paginateContent` 新增图片标记识别与样式分支分页（`SINGLE` 独页，`FULL/DEFAULT` 块级高度预算），`PageFactory` 传递 `legacyImageStyle`。
      - 翻页渲染回补：`PagedReaderWidget` 新增图片页渲染路径（文本块 + 图片块），并在含图片页时跳过纯文本 `PictureRecorder` 快照路径，避免退化为占位字符。
      - 稳定性守卫：当动画模式为 `simulation/simulation2` 且当前邻页含图片标记时，渲染路径自动回退为 `cover`，防止 shader 管线出现图片页空白。
  - 本轮实施记录：
    - 做了什么：打通“图片标记编码 -> 分页参与 -> 翻页渲染”的端到端链路，关闭 T11 中“翻页模式图片仅占位”主偏差。
    - 为什么：legacy `ChapterProvider/TextChapterLayout` 在翻页模式将图片作为排版实体参与分页；现有实现仅在滚动模式渲染图片，翻页模式语义缺失。
    - 如何验证：
      - `flutter test test/reader_image_marker_codec_test.dart`（通过）
      - `flutter test test/paged_reader_widget_non_simulation_test.dart`（通过）
      - `flutter test test/page_factory_listener_test.dart`（通过）
      - `flutter test test/simple_reader_view_compile_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 阅读操作 -> 图片样式 -> 翻页模式）已回填至 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：中。翻页模式开始消费图片标记并渲染图片块；分页高度仍按估算值，极端长图场景与 legacy 真实尺寸分页存在可预期偏差。
  - T11 当前状态：保持 `active`。翻页模式图片渲染链路已收口；剩余差异聚焦“真实尺寸分页精度 + simulation/simulation2 图片页 shader 路径”。

- `2026-02-21`（本轮）
  - T11 第五批收敛：更新 `docs/migration/button-audit/content-c5-checklist.md`，回补 `syncBookProgress` 全局开关约束语义，关闭“仅按 WebDav 配置放行”的偏差。
  - T11 代码收敛：
    - 代码变更：`lib/core/models/app_settings.dart`、`lib/features/reader/views/simple_reader_view.dart`、`lib/features/settings/views/backup_settings_view.dart`、`test/app_settings_test.dart`。
    - 关键实现：
      - 对齐 legacy `AppConfig.syncBookProgress`：`AppSettings` 新增 `syncBookProgress` 字段（默认 `true`），补齐 JSON 兼容读取与持久化。
      - 阅读器同步守卫收敛：`_pullBookProgressFromWebDav/_pushBookProgressToWebDav` 与点击区 `ClickAction.syncBookProgress` 在触发前统一检查全局开关，关闭时直接短路。
      - 配置入口补齐：在“备份与恢复 -> WebDav 同步”新增“同步阅读进度”开关，支持显式启停该全局行为。
  - 本轮实施记录：
    - 做了什么：补齐全局同步开关模型、阅读器执行守卫和设置入口，清除 C5 保留差异中的 `syncBookProgress` 偏差。
    - 为什么：legacy 在 `ReadBookViewModel.syncBookProgress/ReadBook.syncProgress/AppWebDav.uploadBookProgress` 均受主开关约束；现有实现仅按 WebDav 配置放行，导致“关同步仍触发请求”风险。
    - 如何验证：
      - `flutter test test/backup_settings_view_compile_test.dart test/app_settings_test.dart test/simple_reader_view_compile_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 阅读操作 -> 获取进度/覆盖进度）与“备份设置 -> 同步阅读进度开关”已回填至 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：中低。新增一个 AppSettings 持久化布尔字段并默认开启；旧配置缺失该字段时按 `true` 回退，不影响历史 WebDav 配置读取。
  - T11 当前状态：保持 `active`。`syncBookProgress` 全局开关语义已收口，剩余差异聚焦翻页模式图片列分页排版。

- `2026-02-21`（本轮）
  - T11 第四批收敛：更新 `docs/migration/button-audit/content-c5-checklist.md`，补齐图片样式链路在“解析层保留图片 + 滚动模式渲染分流”的逐项对照与证据回填。
  - T11 代码收敛：
    - 代码变更：`lib/core/utils/html_text_formatter.dart`、`lib/features/source/services/rule_parser_engine.dart`、`lib/features/reader/views/simple_reader_view.dart`、`test/html_text_formatter_test.dart`、`test/rule_parser_engine_stage_js_compat_test.dart`。
    - 关键实现：
      - 对齐 legacy `HtmlFormatter.formatKeepImg`：新增 `HtmlTextFormatter.formatKeepImageTags`，保留 `<img src="...">` 并对 `src` 绝对化。
      - 正文解析链路对齐：`RuleParserEngine.getContent/getContentDebug` 改为使用保图清洗，避免图片信息在入库前被剥离。
      - 阅读渲染链路收敛：滚动模式新增图片分块渲染，`TEXT` 使用文字嵌入占位，`FULL/SINGLE` 走图片块布局分流并保留 `SINGLE` 居中语义。
      - 翻页模式安全回退：在分页引擎尚未支持图片列排版前，图片标签回退为占位字符，避免正文出现原始 `<img ...>` 文本。
  - 本轮实施记录：
    - 做了什么：补齐“图片样式渲染分流”的主链路前置条件（解析层保图）与滚动模式渲染路径，并新增回归测试覆盖。
    - 为什么：legacy 在 `BookContent.analyzeContent -> HtmlFormatter.formatKeepImg -> ChapterProvider/TextChapterLayout` 保留并消费图片标签；现有实现在解析阶段就丢失图片，导致菜单状态虽存在但渲染语义缺失。
    - 如何验证：
      - `flutter test test/html_text_formatter_test.dart test/rule_parser_engine_stage_js_compat_test.dart test/simple_reader_view_compile_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 阅读操作 -> 图片样式 -> 滚动模式）已补入 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：中。正文入库内容将保留 `<img>` 标签并绝对化 URL；滚动模式开始渲染图片块。翻页模式仍保留占位回退，未改数据库结构与网络协议。
  - T11 当前状态：保持 `active`。翻页模式尚未实现 legacy 等价的图片列分页排版；`syncBookProgress` 全局开关语义仍待后续收口。

- `2026-02-20`（本轮）
  - T11 第三批收敛：新增 `docs/migration/button-audit/content-c5-checklist.md`，补齐正文菜单 `编辑正文/获取进度/覆盖进度/重新分段/图片样式` 的逐项对照与证据回填。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/views/simple_reader_view.dart`。
    - 关键实现：
      - `menu_edit_content` 对齐 `ContentEditDialog` 重置语义：新增 `_reloadChapterRawContentForEditor`，将重置流程收敛为“清缓存 -> 重取正文 -> 回写章节 -> 重载当前章节”。
      - 编辑页交互补齐并发边界：重置进行中禁用保存/关闭/复制，增加忙碌指示，避免并发触发导致状态错乱。
      - `menu_get_progress/menu_cover_progress/menu_re_segment/menu_image_style` 本批次完成 C5 逐项核验，回填入口、状态、异常、文案、排版与触发证据。
  - 本轮实施记录：
    - 做了什么：回补正文编辑重置状态流转并补齐 C5 清单，收口正文菜单剩余 5 项证据链。
    - 为什么：legacy `ContentEditDialog` 的“重置即重新拉正文”语义在现有实现中缺失，导致“重置后仍停留旧快照”的行为偏差；同时 T11 缺少该批次动作的逐项对照记录。
    - 如何验证：
      - `flutter test test/app_settings_test.dart test/reader_legacy_menu_helper_test.dart test/simple_reader_view_compile_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 阅读操作 -> 编辑正文/获取进度/覆盖进度/重新分段/图片样式）已补入 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：中低。仅收敛阅读器菜单交互与编辑器重置流程；未改动数据库表结构与网络协议。
  - T11 当前状态：保持 `active`。图片样式渲染层对 `FULL/TEXT/SINGLE` 的布局分流仍待回补评估。

- `2026-02-21`（本轮）
  - T11 第二批收敛：更新 `docs/migration/button-audit/content-c5-checklist.md`，新增正文菜单 `正文倒序/模拟阅读/同名标题去重/删除 ruby 标签/删除 h 标签` 的逐项对照与证据回填。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/views/simple_reader_view.dart`、`lib/core/services/settings_service.dart`、`test/app_settings_test.dart`。
    - 关键实现：
      - `menu_reverse_content` 对齐 legacy `ReadBookViewModel.reverseContent`：新增“按行倒序 -> 落库 -> 重载当前章节”链路，替换占位提示。
      - `menu_simulated_reading` 对齐 legacy “从阅读菜单进入模拟阅读流程”语义：动作改为“先停止朗读冲突 -> 启动自动翻页 -> 打开自动阅读面板”。
      - `menu_same_title_removed` 对齐章节级开关语义：新增章节级持久化键 `chapter_same_title_removed_map`，并接入菜单勾选与正文处理链路。
      - `menu_del_ruby_tag/menu_del_h_tag` 对齐 epub 标签清理开关语义：新增书籍级持久化键 `book_del_ruby_tag_map/book_del_h_tag_map`，并在正文处理与缓存刷新链路生效。
  - 本轮实施记录：
    - 做了什么：回补正文链路 5 个高频菜单动作，补齐状态持久化、勾选态展示与正文重载流程。
    - 为什么：legacy 在 `book_read.xml` 与 `ReadBookActivity.kt` 明确这些动作不应停留在占位提示；现有实现存在入口已展示但状态流转缺失的问题。
    - 如何验证：
      - `flutter test test/app_settings_test.dart`（通过）
      - `flutter test test/reader_legacy_menu_helper_test.dart`（通过）
      - `flutter test test/simple_reader_view_compile_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 阅读操作 -> 正文倒序/模拟阅读/同名标题去重/删除标签）已补入 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：中低。新增阅读菜单持久化键与正文处理分支，不改数据库表结构与网络协议；对旧数据兼容（缺省值回退）已由 `app_settings_test` 覆盖。
  - T11 当前状态：保持 `active`。`编辑正文/获取进度/覆盖进度/重新分段` 已在后续批次回补，图片样式渲染分流仍待收口。

- `2026-02-20`（本轮）
  - T11 首批收敛：新增 `docs/migration/button-audit/content-c5-checklist.md`，回填 C5（正文）差异清单、逐项检查、回归路径与保留差异。
  - T11 代码收敛：
    - 代码变更：`lib/features/reader/views/simple_reader_view.dart`、`lib/features/reader/services/reader_legacy_menu_helper.dart`、`test/reader_legacy_menu_helper_test.dart`。
    - 关键实现：
      - `menu_change_source` 对齐 legacy 分支语义：新增 `章节换源/书籍换源` 二级菜单，章节换源补齐“候选 -> 定位对应章节 -> 拉正文 -> 覆写当前章节并重载”流程。
      - `menu_refresh` 对齐 legacy 分支语义：新增 `刷新当前章节/刷新之后章节/刷新全部章节` 二级菜单，并按分支范围清理缓存后重载当前章节。
      - 刷新边界对齐：本地书籍或无有效书源时回退为普通刷新，避免误清缓存导致正文空白。
      - Helper 与测试补齐：新增换源/刷新分支枚举、顺序与文案方法，并补充对应单测覆盖。
  - 本轮实施记录：
    - 做了什么：补齐正文链路中换源/刷新两个高频入口的 legacy 分支语义，并落地 C5 对照文档。
    - 为什么：legacy 在 `book_read_change_source.xml` 与 `book_read_refresh.xml` 明确定义了二级分支；现有实现仅保留单路径，导致入口层级与状态流转偏差。
    - 如何验证：
      - `flutter test test/reader_legacy_menu_helper_test.dart`（通过）
      - `flutter test test/simple_reader_view_compile_test.dart`（通过）
      - `flutter test test/reader_source_switch_helper_test.dart`（通过）
      - 手工路径：C5（阅读器 -> 阅读操作 -> 换源/刷新）步骤已记录于 `docs/migration/button-audit/content-c5-checklist.md`（待真机回归执行）
    - 兼容影响：低到中。新增正文菜单分支与章节缓存刷新流程，不改数据库表结构；章节换源新增网络拉取路径，失败时保留原正文并给出错误提示。
  - T11 当前状态：保持 `active`。`编辑正文/获取进度/覆盖进度/正文倒序/模拟阅读/同名标题去重/重新分段/删除标签/图片样式` 仍待下一批回补。

- `2026-02-20`（本轮）
  - 已完成 T10：新增 `docs/migration/button-audit/toc-c4-checklist.md`，完成 C4（目录菜单：章节/书签双 Tab）逐项对照清单与证据回填。
  - T10 代码收敛：
    - 代码变更：`lib/features/reader/services/reader_legacy_menu_helper.dart`、`lib/features/reader/widgets/reader_catalog_sheet.dart`、`lib/features/reader/views/simple_reader_view.dart`。
    - 关键实现：
      - TOC 菜单顺序对齐 `book_toc.xml` 分组语义：本地 TXT 下收敛为 `TXT 目录规则 -> 分割长章节 -> 倒序 -> 使用替换规则 -> 加载字数 -> 日志`。
      - `分割长章节` 切换补齐 legacy 同义状态流转：引入异步应用回调，切换时进入忙碌态，成功后回写状态，失败时保留原状态并输出错误提示。
      - 阅读器初始化补齐 `splitLongChapter` 持久化回填；目录面板切换时先落库，再对本地 TXT 触发重解析重载流程。
  - 本轮实施记录：
    - 做了什么：补齐目录链路 C4 对照文档，并回补 TOC 菜单顺序与 `分割长章节` 的状态流转/边界反馈偏差。
    - 为什么：legacy 的 `TocActivity` 在 `book_toc.xml` 分组顺序与 `menu_split_long_chapter` 的“切换即应用”语义明确；现有实现存在“顺序偏差 + 仅本地切换”的行为偏差。
    - 如何验证：
      - `flutter test test/reader_legacy_menu_helper_test.dart`（通过）
      - `flutter test test/reader_catalog_sheet_test.dart`（通过）
      - `flutter test test/simple_reader_view_compile_test.dart`（通过）
      - 手工路径：C4（阅读器 -> 目录面板 -> 章节/书签 Tab -> 更多菜单）步骤已记录于 `docs/migration/button-audit/toc-c4-checklist.md`（待真机回归执行）
    - 兼容影响：低。目录菜单仅收敛交互语义与状态流转；未改动网络协议与数据库表结构。`reverseToc` 持久化与目录字数字段仍保留差异，待后续回补。
  - 已将下一任务切换为 T11（`active`）：开始五段链路-正文（content/reader）按钮与交互同义迁移。

- `2026-02-20`（本轮）
  - 已完成 T09：新增 `docs/migration/button-audit/bookinfo-c3-checklist.md`，完成 C3（详情页菜单：编辑/分享/变量/日志）逐项对照清单与证据回填。
  - T09 代码收敛：
    - 代码变更：`lib/features/search/views/search_book_info_view.dart`、`lib/features/source/views/source_qr_share_view.dart`。
    - 关键实现：
      - 详情页分享入口改为二维码分享壳：从“复制分享串”收敛为“进入二维码页 + 系统分享兜底”，对齐 legacy `menu_share_it` 交互路径。
      - `分割长章节` 切换补齐 legacy 同义状态流转：切换后进入加载态并触发上下文重载；关闭时追加“重载可能更耗时”提示。
      - `置顶` 动作补齐双排序语义：落库同时更新 `addedTime + lastReadTime`，覆盖“最近添加/最近阅读”两种排序可见性。
  - 本轮实施记录：
    - 做了什么：补齐详情链路 C3 对照文档，并收敛详情页分享/置顶/分割长章节三处交互逻辑偏差。
    - 为什么：legacy 的 `BookInfoActivity` 在 `menu_share_it`、`menu_top`、`menu_split_long_chapter` 上存在明确交互语义；现有实现在交互载体与状态流转上仍有偏差，需要在 T09 阶段回补。
    - 如何验证：
      - `flutter test test/search_book_info_view_compile_test.dart`（通过）
      - `flutter test test/search_book_info_menu_helper_test.dart`（通过）
      - `flutter test test/source_qr_share_view_compile_test.dart`（通过）
      - 手工路径：C3（搜索/书架进入详情 -> 顶栏分享 -> 更多菜单）按 `docs/migration/button-audit/bookinfo-c3-checklist.md` 回填
    - 兼容影响：低。仅收敛详情页交互语义与二维码分享壳复用，不改动五段链路数据模型与网络协议。
  - 已将下一任务切换为 T10（`active`）：开始五段链路-目录（toc）按钮与交互同义迁移。

- `2026-02-21`（本轮）
  - 已完成 T08：新增 `docs/migration/button-audit/explore-c2-checklist.md`，完成 C2（分组筛选 -> 源操作 -> 二级发现结果）逐项对照清单与证据回填。
  - T08 代码收敛：
    - 代码变更：`lib/features/discovery/views/discovery_view.dart`、`lib/features/discovery/views/discovery_explore_results_view.dart`。
    - 关键实现：
      - 发现页可见源过滤回归 legacy `flowExplore` 语义：仅按 `enabledExplore + exploreUrl`，并按 `customOrder` 升序。
      - 分组筛选弹层移除“清空筛选”扩展入口；长按菜单顺序收敛为“编辑/置顶/登录/搜索/刷新/删除”。
      - 发现二级页移除顶部刷新按钮，保留滚动加载与错误重试。
  - 本轮实施记录：
    - 做了什么：补齐发现链路 C2 对照文档，并收敛发现页过滤/菜单/二级页入口差异。
    - 为什么：legacy 的 `BookSourceDao.flowExplore` 不依赖 `enabled` 与 `ruleExplore`；同时 `main_explore` 与 `explore_item` 菜单不存在“清空筛选”与二级页顶部刷新入口，需避免扩展行为偏差。
    - 如何验证：
      - `flutter test test/discovery_filter_helper_test.dart`（通过）
      - `flutter test test/discovery_view_compile_test.dart`（通过）
      - 手工路径：C2（分组筛选 -> 源操作 -> 二级发现结果）按 `docs/migration/button-audit/explore-c2-checklist.md` 回填
    - 兼容影响：低。仅收敛发现链路筛选与菜单交互语义，不改动搜索/阅读数据模型与网络请求协议。
  - 已将下一任务切换为 T09（`active`）：开始五段链路-详情（bookInfo）按钮与交互同义迁移。

- `2026-02-21`（本轮）
  - 已完成 T07：新增 `docs/migration/button-audit/search-c1-checklist.md`，完成 C1（搜索页菜单 -> 书籍详情 -> 编辑入口）逐项对照清单与证据回填。
  - T07 代码收敛：
    - 代码变更：`lib/features/search/views/search_book_info_view.dart`。
    - 关键实现：将 `book_info` 更多菜单中的“置顶/复制书籍链接/复制目录链接”改为常驻入口，贴齐 legado `BookInfoActivity.onMenuOpened` 的可见性语义。
  - 本轮实施记录：
    - 做了什么：补齐搜索链路 C1 对照文档，并收敛详情页更多菜单入口可见性差异。
    - 为什么：legacy 的 `book_info.xml` 相关入口为常驻项，现有实现按条件隐藏会造成入口层级偏差；同时 T07 缺少可复核交付物。
    - 如何验证：
      - `flutter test test/search_view_compile_test.dart`（通过）
      - `flutter test test/search_scope_picker_view_compile_test.dart`（通过）
      - `flutter test test/search_book_info_view_compile_test.dart`（通过）
      - `flutter test test/search_book_info_menu_helper_test.dart`（通过）
      - 手工路径：C1（搜索页菜单 -> 书籍详情 -> 编辑入口）按 `docs/migration/button-audit/search-c1-checklist.md` 回填
    - 兼容影响：低。仅调整详情页更多菜单入口可见性与迁移文档，不改动搜索/阅读数据模型与网络链路。
  - 已将下一任务切换为 T08（`active`）：开始五段链路-发现（explore）按钮与交互同义迁移。

- `2026-02-20`（本轮）
  - 已完成 T05A：新增 `docs/migration/button-audit/config-input-audit-matrix.md`，补齐 `22` 条配置/输入核对项（覆盖主入口、书架、发现、RSS、书源编辑、阅读设置），并逐项记录默认值/校验/保存取消语义。
  - 已完成 T06：新增 `docs/migration/button-audit/main-4tab-checklist.md`，输出主入口与 4 Tab 的差异清单、逐项检查清单（入口/状态/异常/文案/排版/触发）与 M1 回归记录。
  - T06 核心实现补齐：为书架 Tab 新增重选回顶语义。
    - 代码变更：`lib/main.dart`、`lib/features/bookshelf/views/bookshelf_view.dart`。
    - 关键实现：`MainScreen` 新增 `_bookshelfReselectSignal`，重选书架 Tab 时递增；`BookshelfView` 新增 `reselectSignal` 监听并在图墙/列表共用 `ScrollController` 执行 `animateTo(0)`。
  - 本轮实施记录：
    - 做了什么：补齐 T05A/T06 交付文档，修复书架重选缺口并打通主入口重选信号。
    - 为什么：T05A 缺失交付文档导致 T06 依赖未闭环；同时主入口存在“发现可重选收缩、书架不可重选回顶”的语义偏差。
    - 如何验证：
      - `flutter test test/bookshelf_view_compile_test.dart`（通过）
      - `flutter test test/widget_test.dart`（通过）
      - 手工路径：M1（底栏四 tab -> 顶栏按钮 -> 二级入口）按 `docs/migration/button-audit/main-4tab-checklist.md` 记录回填
    - 兼容影响：低。仅新增重选回顶控制与文档；未改动数据模型与网络链路。书架占位入口仍保持与 T05 规范一致，扩展项继续 `blocked`。
  - 已将下一任务切换为 T07（`active`）：开始五段链路-搜索（search）按钮与交互同义迁移。

- `2026-02-20`
  - 已完成 T04：重构 `docs/migration/button-audit/generate_button_mapping_candidates.pl`，加入菜单上下文规则、模糊匹配置信度门槛与占位兜底策略，重新生成 `docs/migration/button-audit/button-mapping.csv`。
  - T04 完成统计（410 条 legacy 项）：
    - `mapped_exact=52`
    - `mapped_exact_context=96`
    - `mapped_fuzzy_context=191`
    - `mapped_placeholder=71`
    - `empty_mapping_rows=0`
  - 已完成 T05：新增 `docs/migration/button-audit/placeholder-interaction-spec.md`，定义 A/B/C 三类占位交互语义与逐项检查模板，并完成 settings/bookshelf/reader/rss/source 五模块抽检。
  - T04 实施记录（收口版）：
    - 做了什么：改造映射脚本并收敛输出状态；将原 `auto_*`/`unmapped` 改为 `mapped_*` 分层，确保 `soup_seq/soup_file/soup_label` 全量非空。
    - 为什么：旧草案存在 `107` 未映射和 `96` 多候选歧义，无法直接支撑后续迁移核对。
    - 如何验证：
      - `perl docs/migration/button-audit/generate_button_mapping_candidates.pl > docs/migration/button-audit/button-mapping.csv`
      - `perl -ne '...mapping_status 计数...' docs/migration/button-audit/button-mapping.csv`
      - `perl -ne '...empty_mapping_rows 校验...' docs/migration/button-audit/button-mapping.csv` 输出 `empty_mapping_rows=0`
      - `perl -c docs/migration/button-audit/generate_button_mapping_candidates.pl` 输出 `syntax OK`
    - 兼容影响：低（仅迁移文档与脚本层变更，不改运行时代码；映射表中 `mapped_placeholder` 条目需在 T06~T14 分批回补）。
  - T05 实施记录：
    - 做了什么：落地统一占位交互规范文档，明确扩展冻结占位、核心缺口占位、整页占位三种交互行为与文案标准。
    - 为什么：避免不同页面“同类占位多种表现”，并为 T06 之后的入口替换提供统一验收口径。
    - 如何验证：按文档中 5 模块抽检表人工核对对应文件实现与交互语义。
    - 兼容影响：无（仅新增规范文档，不改运行时代码）。
  - 已将下一任务切换为 T05A（`active`）：开始建立配置/输入核对矩阵。

- `2026-02-21`
  - 已完成 T03：新增 `docs/migration/button-audit/soupreader-button-ledger.md`，建立 soupreader 入口台账（按页面列按钮）。
  - 新增可复现提取脚本 `docs/migration/button-audit/extract_soupreader_button_entries.pl`，统一抽取 `lib/main.dart` 与 `lib/features/**/(views|widgets)/*.dart` 中可点击入口候选。
  - T03 台账统计：共 `546` 条入口记录，覆盖 `58` 个文件与 `58` 个页面；其中 `80` 条为无显式文案（图标按钮等），已在台账中标记为 `label=-` 待 T04 人工核对。
  - 已补充阅读器动态菜单人工清单（ReadMenu/TocMenu），避免 `ReaderLegacyMenuHelper` 动态文案在自动提取中漏项。
  - 已启动 T04：新增 `docs/migration/button-audit/generate_button_mapping_candidates.pl`，输出 `docs/migration/button-audit/button-mapping.csv`（legacy -> soupreader 自动候选映射草案）。
  - T04 草案统计（410 条 legacy 项）：
    - `auto_exact=52`
    - `auto_exact_ambiguous=96`
    - `auto_fuzzy=155`
    - `unmapped=107`
  - T04 当前阻塞点：仍有 `107` 条未映射与 `96` 条精确多候选待人工消歧，暂不满足“全量无空映射”验收口径。
  - T03 实施记录：
    - 做了什么：落地 soupreader 入口台账与自动提取脚本，并回填统计结果。
    - 为什么：为 T04 一对一映射建立 soupreader 侧“页面-入口”主键，减少手工盘点遗漏。
    - 如何验证：`perl docs/migration/button-audit/extract_soupreader_button_entries.pl > /tmp/soupreader_button_entries.tsv`；`wc -l /tmp/soupreader_button_entries.tsv` 输出 547（含表头，数据 546）。
    - 兼容影响：无（仅新增文档与提取脚本，不改动运行时代码）。
  - T04 草案实施记录：
    - 做了什么：构建 legacy 字符串解析 + soupreader 入口匹配脚本，自动生成候选映射 CSV。
    - 为什么：先缩小人工映射范围，优先处理真正歧义/缺失项。
    - 如何验证：`perl docs/migration/button-audit/generate_button_mapping_candidates.pl > docs/migration/button-audit/button-mapping.csv`；`wc -l docs/migration/button-audit/button-mapping.csv` 输出 411（含表头，数据 410）。
    - 兼容影响：无（仅新增文档与脚本，不改动运行时代码）。
  - 已将下一任务切换为 T04（`active`）：开始生成 legacy -> soupreader 一对一映射表。

- `2026-02-20`
  - 已完成 T00：获取基线统计（90 个 menu 文件，410 个按钮项）。
  - 已完成初版差异识别（D-001 ~ D-007）。
  - 已输出详细 Todo（T00 ~ T18）并标注依赖、串并行、Owner、blocked 状态。
  - 已按需求补强“排版 + 交互逻辑同义”为硬验收条件，并新增 T16A。
  - 已完成 T02：新增 `docs/migration/button-audit/legacy-button-ledger.md`，落地 410 项 legacy `<item>` 全量台账。
  - 新增可复现提取脚本 `docs/migration/button-audit/extract_legacy_menu_items.pl`，支持嵌套 `<menu>/<group>` 场景下的全量提取。
  - T02 实施记录：
    - 做了什么：输出 legacy 按钮全量台账并固化提取脚本。
    - 为什么：为 T03/T04 提供唯一主键，避免后续映射遗漏。
    - 如何验证：`find ../legado/app/src/main/res/menu -maxdepth 1 -name '*.xml' | wc -l` 得到 90；`perl docs/migration/button-audit/extract_legacy_menu_items.pl | wc -l` 得到 411（含表头，数据 410）。
    - 兼容影响：无（仅新增文档与工具脚本，不改动运行时代码）。
  - 已将下一任务切换为 T03（`active`）：开始建立 soupreader 入口台账。

### 11) Surprises & Discoveries（动态）

- 边距/信息弹窗收口时发现 `ReadingSettings.fromJson` 对 `showHeaderLine` 的缺省回退为 `true`，与 legado `showHeaderLine=false` 语义不一致；旧配置缺字段会出现“无操作却显示分割线”的偏差，已改为 `false`。
- legado `TipConfigDialog` 的“标题显示”是内联单选组而非二级弹层；若沿用 ActionSheet 会改变交互路径，已改为内联分段控件。
- 发现 legacy 菜单规模远高于直觉（`410` 项），必须使用台账驱动，不能靠页面肉眼扫。
- soupreader 已有较多入口容器，但尚未形成“全量映射主键”，容易造成局部一致、全局遗漏。
- 设置模块存在多处 `showNotImplemented`，适合作为“先有交互壳”策略，但需统一占位语义。
- legacy 菜单存在“父级 `<item>` 内嵌 `<menu>` 子级 `<item>`”结构；线性正则提取会漏计，必须按标签流解析。
- soupreader 当前入口体量达到 `546` 条，自动提取能覆盖主干，但动态文案（插值/条件分支）与纯图标按钮仍需 T04 结合运行态补核。
- 阅读器 `ReaderLegacyMenuHelper` 采用运行时拼装菜单，若仅依赖视图层扫描会漏掉部分动作文案，需在台账中保留人工补记。
- 自动映射能快速收敛规模，但误配风险集中在高频文案（如“日志/帮助/登录/导出”）与语义相近入口（如“下载” vs “离线缓存”），必须在 T04 增加上下文约束后再宣称同义。
- 若仅按字符重叠做模糊匹配，英文字母偶然重合会导致明显误配（例如 `keyword` 与 `webdav`）；必须引入汉字重叠与置信度门槛。
- 同菜单内“先命中的历史文件”不一定是最佳占位挂载点（如阅读菜单先命中搜索入口）；占位兜底应先走菜单语义上下文，再走同菜单历史频次。
- T05A 在计划表中长期为 `active` 但缺少交付文件，导致 T06 依赖链看似“已开始”实则“未闭环”；本轮先补文档再推进实现可避免无记录偏航。
- 书架页引入 `ValueListenable` 信号后，若缺失 `foundation` 导入会直接导致编译失败；通过 `bookshelf_view_compile_test` 能快速暴露并修复该类问题。
- `book_info` 菜单若按“可执行性”而非“可见性语义”裁剪入口，会出现“legacy 常驻项在 soupreader 条件隐藏”的偏差；本轮改为入口常驻、动作内校验。
- `flowExplore` 的 legacy 过滤条件只依赖 `enabledExplore + hasExploreUrl`，并不依赖 `enabled` 与 `ruleExplore`；若沿用更严格条件会直接漏掉合法发现源。
- 发现链路中的“清空筛选”“二级页顶部刷新”属于非 legacy 入口，虽可用但会引入行为分叉；迁移阶段应回收为同义路径。
- 详情页“分享”若仅保留剪贴板复制，会偏离 legacy 的二维码承载路径；需要保留二维码载体并提供系统分享兜底。
- `分割长章节` 若只改开关状态而不触发重载，会导致目录/正文状态与 legacy 的“切换即重载”语义脱节。
- 目录菜单中的 `分割长章节` 若缺少“异步应用”阶段，会出现 UI 已切换但配置/重载失败的假阳性状态；需要“成功后回写状态”的流程约束。
- 刷新分支若在“本地书籍/无书源”场景直接清缓存，会导致正文内容被清空；必须对齐 legacy 回退为普通刷新。
- 章节换源若不先做“章节匹配”而直接用索引映射，跨源章节差异会导致错章；需要基于标题优先匹配并以索引做兜底。
- `同名标题去重` 在 legacy 为章节级状态而非全局设置；若只复用全局“净化章节标题”会造成状态粒度偏差，需补章节级持久化键。
- epub 标签清理切换若不触发缓存刷新，会出现“菜单勾选已切换但正文未生效”的假阳性；需串联全书缓存清理与当前章节重载。
- 编辑正文若仅把“重置”实现为回退本地初始快照，会偏离 legacy 的“清缓存后重新取正文”语义，必须把底层章节重载串进重置流程。
- soupreader 现有正文清洗实现会在解析阶段剥离 `<img>`，与 legacy `formatKeepImg` 不一致；若不先修正解析层，渲染层无法做图片样式分流。
- 当前滚动模式已接入 `FULL/TEXT/SINGLE` 图片分流，但翻页模式分页器仍缺少图片列建模能力，需要单独收口或按例外流程记录阻塞。
- legacy 的“拉取/覆盖进度”菜单可见性只依赖 WebDav 可用性，`syncBookProgress` 关闭时并不隐藏入口，而是在动作执行链路早期短路；迁移时需保持该层级语义不漂移。
- 翻页模式引入图片标记后，`PictureRecorder` 纯文本快照路径会把图片页重新降级为文本；必须在含图片页时切到组件渲染路径，否则会出现“状态已切换、画面仍占位”的假收口。
- 仿真模式空白页的根因不在 shader 程序本身，而在“图片标记页被禁止进入 Picture 快照路径”导致帧准备始终不就绪；放开快照路径并对标记行做占位降级后可恢复动画链路。
- 仅依赖“图片渲染后回写尺寸 -> 二次重分页”会在首帧出现页码抖动（先估算分页再回收断点）；在章节加载期增加小窗口预热（8 张 / 260ms）后，首帧跳页概率显著下降且不阻塞主链路。
- 图片 `src` 若包含 legacy `url,{option}`，此前在规范化阶段会提前剥离 option，导致鉴权 header 丢失；需要在 marker 编码、分页渲染与预热探测链路统一保留 option 并按请求阶段解析。
- source-aware 探测若只尝试单次回退，慢源 + 负缓存窗口会放大“首帧直接估算”的概率；补齐“缓存链路 + 直连重试”后命中更稳定。
- 长图在标签未显式提供 `width/height` 时，仍可从 `aspect-ratio` 与 URL `w/h` 参数恢复比例提示，可明显降低首帧断点偏移。
- 尺寸缓存若直接使用原始 `src`（含 `url,{option}`）作为键，会因 option 文本差异导致“同图不同键”并削弱跨章节复用；改为 URL 级归一化键后命中更稳定。
- 长图误差若只停留在“结果观察”而不反馈预算策略，慢源章节会重复触发估算分页；引入 EMA 采样回流到 warmup 预算后，后续章节可主动放宽探测窗口。
- 仅用“章节耗时 + 长图误差”做预算自适应时，无法区分 `timeout/auth/decode` 失败性质，容易出现“某书源持续失败但预算变化迟缓”的尾部偏差；补齐失败分层后预算调整更稳定。

### 12) Decision Log（动态）

- `2026-02-21`：T11 弹窗迁移采用“结构同义优先”策略：边距弹窗改为平铺分段列表；信息弹窗标题模式改为内联单选，不再使用二级 ActionSheet。
- `2026-02-21`：`showHeaderLine` 兼容回退值改为 `false`，优先与 legado 默认语义保持一致，避免旧配置行为漂移。
- `2026-02-20`：决定先做“按钮与交互壳”而非真实业务实现，符合当前需求与迁移节奏。
- `2026-02-20`：扩展任务（T15）按规范先标记 `blocked`，等待明确“开始做扩展功能”指令。
- `2026-02-20`：采用“台账 -> 映射 -> 批量迁移 -> 逐项对照”流水线，避免遗漏。
- `2026-02-20`：将“交互逻辑同义（状态流转/边界/取消清理/错误反馈）”提升为与排版同级的强制验收项。
- `2026-02-20`：legacy 按钮台账提取改为仓库脚本 `docs/migration/button-audit/extract_legacy_menu_items.pl`，统一以 410 项为后续映射主键。
- `2026-02-21`：soupreader 入口盘点采用“脚本自动提取 + 动态菜单人工补记”组合策略，优先保证覆盖率，再在 T04 做逐项人工消歧与映射收敛。
- `2026-02-21`：T04 先采用“自动候选映射 + 状态分层（exact/ambiguous/fuzzy/unmapped）”策略，避免直接手工全量 410 条导致遗漏不可追踪。
- `2026-02-20`：T04 收口采用“上下文优先 + 低置信模糊回落占位”策略，优先保证映射可追踪和可回补，避免以误配替代缺口。
- `2026-02-20`：新增 T05 占位交互规范文档，统一扩展冻结占位与核心缺口占位语义，作为 T06+ 迁移验收前置约束。
- `2026-02-20`：T06 采用“主入口信号驱动子页滚动控制”方案补齐书架重选回顶（`MainScreen` 发信号，`BookshelfView` 监听执行），以最小改动保持与 discovery 页重选机制一致。
- `2026-02-20`：设置页与书架中的扩展入口继续沿用 T05 占位规范，不在 T06 阶段提前实现扩展能力，维持“核心优先、扩展冻结”。
- `2026-02-21`：T07 在 `book_info` 菜单可见性上采用“入口常驻 + 动作内状态校验”策略，对齐 legacy 菜单层级并保留错误可观测反馈。
- `2026-02-21`：T08 发现链路改为严格复刻 `flowExplore` 口径（`enabledExplore + exploreUrl + customOrder`），避免因额外过滤条件导致入口缺失。
- `2026-02-21`：T08 回收发现链路扩展入口（分组“清空筛选”、二级页顶部刷新）并对齐 `explore_item` 菜单顺序，优先保证交互路径同义。
- `2026-02-20`：T09 复用 `SourceQrShareView` 作为书籍详情二维码分享壳，仅通过可配置提示文案区分“书源导入”与“书籍分享”，避免重复实现并保持交互一致。
- `2026-02-20`：T09 对 `menu_split_long_chapter` 采用“状态切换后立即重载上下文 + 关闭时提示耗时”策略，优先贴齐 legacy 的状态流转语义。
- `2026-02-20`：T10 对 `menu_split_long_chapter` 采用“先异步应用（保存+重载）再回写 UI 状态”策略，失败分支保留旧状态并输出错误，避免假阳性切换。
- `2026-02-20`：T11 将 `menu_change_source` 收敛为二级分支（章节/书籍）；章节分支采用“标题匹配优先 + 索引兜底”的目标章节定位策略，降低跨源错章风险。
- `2026-02-20`：T11 将 `menu_refresh` 收敛为二级分支（当前/之后/全部）；当检测到本地书籍或无有效书源时，按 legacy 语义回退为普通刷新。
- `2026-02-21`：T11 对 `menu_same_title_removed` 采用“章节级持久化 + 菜单勾选可见 + 当前章节重载”策略，避免复用全局开关造成行为漂移。
- `2026-02-21`：T11 对 `menu_simulated_reading` 采用“自动翻页面板承载”策略，在未完整迁移 legacy 日期/章节计划配置前，先保证入口层级与状态流转同义且可观测。
- `2026-02-20`：T11 对 `menu_edit_content` 采用“父页面回调重置（清缓存 + 重取正文 + 章节重载）”策略，编辑器内仅承载输入与交互状态，避免在弹层内直接改写阅读状态导致同步偏差。
- `2026-02-21`：T11 正文清洗链路改为保留 `<img>` 并绝对化 `src`，对齐 legacy `BookContent.analyzeContent -> HtmlFormatter.formatKeepImg` 语义，避免解析层提前丢失图片信息。
- `2026-02-21`：T11 在滚动模式先落地图片分块渲染；翻页模式在分页器未支持图片列前保持占位回退，并将其作为持续收口差异显式记录。
- `2026-02-21`：T11 对 `syncBookProgress` 采用“入口层级保持不变 + 动作执行前全局开关短路”策略；同时在备份设置补全开关入口，并以 `AppSettings` 默认 `true` 保障旧配置兼容。
- `2026-02-20`：T11 翻页模式图片链路采用“图片标记编码（正文层）-> 样式感知分页（分页层）-> 图片块渲染（UI 层）”三段式收口；`simulation/simulation2` 遇图片页时临时回退 `cover`，优先保证语义可见与交互稳定。
- `2026-02-20`：T11 将图片标记 payload 升级为“src + 可选尺寸提示”，并采用“运行时实测尺寸缓存优先、提示尺寸次之、估算兜底”的分页策略，在不改主调用链的前提下渐进逼近 legacy 真尺寸分页。
- `2026-02-20`：T11 移除 `simulation/simulation2 -> cover` 强制回退；仿真快照阶段对图片标记行使用占位符绘制，保证动画路径可达与帧准备稳定，再由静态态渲染还原真实图片块。
- `2026-02-20`：T11 新增“章节加载期限时预热（8 张 / 260ms）+ 渲染期回写重分页”双阶段策略，优先提升首帧真实尺寸命中率；预热超时仍回退估算，保障阅读主链路连续性。
- `2026-02-21`：T11 邻章预取链路采用“后处理后轻量预热（6 张 / 180ms）+ 仅有变化时刷新分页”策略，优先提升跨章节切换命中率并抑制无差异重排。
- `2026-02-21`：T11 图片请求链路采用“option/header 保留 + source-aware 回退探测 + 预算自适应”策略：优先走 `ImageProvider.resolve`，失败时回退 `SourceCoverLoader.fetchCoverBytes` 解码尺寸；预算按章节耗时与书源响应时间动态放宽，提升鉴权/慢源命中率。
- `2026-02-21`：T11 图片尺寸探测升级为“两段 source-aware 策略（缓存链路 + 直连重试）”，并在 marker 侧增加 `aspect-ratio + URL w/h` 维度提示，优先收敛慢源与长图首帧误差。
- `2026-02-21`：T11 对图片尺寸缓存采用“URL 归一化键 + 书籍级快照持久化”策略：跨章节与重进阅读优先复用历史探测结果，失败时回落运行时探测。
- `2026-02-21`：T11 对长图场景采用“误差 EMA 采样 -> warmup 预算增配”策略，优先收敛慢源章节重复估算分页，不改变主链路回退语义。
- `2026-02-21`：T11 对图片探测新增“失败类型分层采样 + source-level 遥测调参”策略：按 `timeout/auth/decode/other` 统计 EMA 与连续失败次数，动态增配探测预算并在高成功率时回收预算，避免慢源长期固定预算。

### 13) Outcomes & Retrospective（动态）

- 阶段性结果（截至 T11 第十五批收敛）：
  - 已完成任务：`T00,T01,T02,T03,T04,T05,T05A,T06,T07,T08,T09,T10`。
  - 当前进行中：`T11`（正文链路按钮与交互同义）。
  - 新增收益：C5 对照清单已覆盖十五批动作；本轮完成边距/信息弹窗与 legado 语义收口，并修复页眉分割线默认值兼容偏差。
  - 当前缺口：极端不可达慢源（双阶段探测持续失败）下仍会回落估算分页，距离 legacy “全量首帧真实尺寸确定性”仍有尾部偏差。
  - 回归状态：本轮定向测试 `simple_reader_view_compile_test`、`reader_top_menu_test`、`reader_bottom_menu_new_test` 通过；仍未执行 `flutter analyze`（保留到 T18 提交前一次执行）。
