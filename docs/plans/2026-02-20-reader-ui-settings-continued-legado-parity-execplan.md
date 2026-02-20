# 阅读器界面与设置继续对齐 legado（ReadStyle/MoreConfig）ExecPlan

- 状态：`active`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（UI/设置语义同义）`

## 背景与目标

### 背景

需求方最新指令：停止偏到 `TTS` 的分支，继续梳理并修改“阅读器中的界面及设置”。

当前 legado 对照基准（本轮已复核）：

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
- `/home/server/legado/app/src/main/res/layout/view_read_menu.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/res/layout/dialog_read_book_style.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/widget/DetailSeekBar.kt`
- `/home/server/legado/app/src/main/res/layout/view_detail_seek_bar.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`

当前 soupreader 相关实现：

- `lib/features/reader/views/simple_reader_view.dart`
- `lib/features/reader/widgets/reader_bottom_menu.dart`
- `lib/features/reader/models/reading_settings.dart`

### 目标（Success Criteria）

1. 阅读器 `界面` 与 `设置` 两个入口的弹层结构、入口层级、触发语义与 legado 同义（平台 UI 差异除外）。
2. `设置` 面板中的关键配置项（翻页、显示、点击区域、方向、返回键、亮度条、进度条行为）状态流转与持久化行为同义。
3. `界面` 面板中的 `信息` 入口流转与 legado `TipConfigDialog` 同义（标题/页眉页脚/提示信息配置链路完整）。
4. 明确区分“本轮主线必做项”与“扩展冻结项（blocked）”，不得混入未授权扩展实施。
5. 完成逐项对照清单回填，并提供手工回归路径证据。

### 非目标（Non-goals）

1. 不推进 `TTS` 朗读实现（已在独立 ExecPlan 标记 `blocked`）。
2. 不推进与当前指令无关的阅读扩展能力（如渲染实验、外部导入工具链）实现。
3. 不改动搜索/发现/详情/目录/正文抓取链路。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| UI-S1 | `simple_reader_view.dart:_showReadingSettingsSheet` | `MoreConfigDialog.kt` | 当前为 `0.78` 高度分段页签弹层；legado 为固定高度（`360dp`）偏好列表弹层 | 入口层级与布局节奏不一致 |
| UI-S2 | `simple_reader_view.dart:_buildMoreSettingsTab` + `reading_settings.dart:keepScreenOn` | `pref_config_read.xml:key=keep_light` | 当前为“屏幕常亮”布尔开关；legado 为“亮屏时长”列表配置语义 | 状态语义与生命周期行为不一致 |
| UI-S3 | `simple_reader_view.dart:_showReadStyleDialog`（`信息` 按钮） | `ReadStyleDialog.kt:tvTip -> TipConfigDialog` | 当前 `信息` 入口跳转到通用设置分页；legado 为专用信息配置对话框 | 交互路径偏移、可发现性下降 |
| UI-S4 | `reading_settings.dart` + `simple_reader_view.dart` | `pref_config_read.xml` | legado 偏好项中仍有未同义映射项（如 `paddingDisplayCutouts`、`volumeKeyPageOnPlay`、`customPageKey`、`showReadTitleAddition`、`readBarStyleFollowPage`） | 功能覆盖不完整，迁移结论不闭合 |
| UI-S5 | `simple_reader_view.dart:_executeLegacyReadMenuAction` | `ReadBookActivity.kt` / `ReadMenu.kt` | 与“设置相关”的阅读操作仍有占位（如 `设置编码`） | 设置链路存在断点，影响一致性验收 |

## 逐项检查清单（强制）

- 入口：阅读页菜单 `界面/设置` 两入口是否进入对应同义面板。
- 状态：设置修改后即时生效与持久化是否一致（重进阅读页验证）。
- 异常：空章节、无书源、滚动翻页模式下切换设置是否稳定。
- 文案：设置项文案是否保持 legado 业务语义（避免“近义改写”）。
- 排版：弹层高度、区块顺序、滑条/开关/选项行间距与热区是否同义。
- 交互触发：`信息`、`点击区域`、`翻页阈值`、`方向`、`返回键` 等动作是否可达且生效。

## 实施步骤（含依赖与并行）

### Step 1（串行，前置）

- 目标：完成 `MoreConfigDialog/pref_config_read.xml` 与 Flutter 设置项的逐项映射矩阵，并标注“主线必做/扩展冻结”。
- 预期结果：每个 legacy key 都有去向（同义实现、待实现、blocked）。
- 验证方式：矩阵回填到本 ExecPlan 的 `Progress` 与 `Decision Log`。
- 状态：`completed`（本轮已完成差异梳理与首轮分组）

### Step 2（串行，依赖 Step 1）

- 目标：调整 `设置` 弹层结构，使入口层级与布局节奏对齐 `MoreConfigDialog` 语义。
- 涉及：
  - `lib/features/reader/views/simple_reader_view.dart`
- 预期结果：`设置` 入口可在单屏偏好列表内完成主配置操作，避免与 `界面` 入口职责混淆。
- 验证方式：手工回归路径 B、C。
- 状态：`completed`

### Step 3（可并行，依赖 Step 2 主结构落位）

- 分支 3A（owner: A）
  - 目标：修正 `keep_light` 语义（亮屏时长/保持策略）并与现有 `keepScreenOn` 行为整合。
  - 涉及：
    - `lib/features/reader/models/reading_settings.dart`
    - `lib/features/reader/views/simple_reader_view.dart`
  - 验证：手工回归路径 D + 定向测试（若新增序列化字段）。
  - 状态：`completed`
- 分支 3B（owner: B）
  - 目标：将 `信息` 入口对齐到 `TipConfigDialog` 等价链路（标题/页眉页脚/提示信息配置）。
  - 涉及：
    - `lib/features/reader/views/simple_reader_view.dart`
  - 验证：手工回归路径 E。
  - 状态：`completed`

### Step 4（串行，依赖 Step 3A/3B）

- 目标：处理 `UI-S4/UI-S5` 未同义项，区分“本轮补齐”与“冻结 blocked”。
- 涉及：
  - `lib/features/reader/views/simple_reader_view.dart`
  - `lib/features/reader/models/reading_settings.dart`
  - 必要时补充测试文件
- 预期结果：未完成项必须标记 `blocked` 并给出原因、影响范围、替代方案、回补计划。
- 验证方式：逐项对照清单回填 + 文档复核。
- 状态：`completed`（含 `blocked` 例外项记录）

### Step 5（串行，收尾）

- 目标：完成本任务逐项检查清单、证据回填、兼容影响记录。
- 预期结果：形成可复现的验收结果，不使用“基本一致”笼统表述。
- 验证方式：手工路径 + 定向测试记录（提交前不提前跑 `flutter analyze`）。
- 状态：`pending`

## 风险与回滚

### 失败模式

1. 将 `设置` 面板结构改为同义路径后，现有字段映射发生错配导致配置失效。
2. `keep_light` 语义迁移不完整，导致锁屏或常亮行为异常。
3. `信息` 入口重构后，标题/页眉页脚配置出现回归。

### 阻塞条件（触发即标记 `blocked`）

1. 某 legacy 关键设置无法在当前平台以同义方式承载，且缺少可接受替代方案。
2. 同一设置项存在多处入口且语义冲突，无法在不破坏主流程的前提下统一。

### 回滚策略

1. 以函数/文件粒度回滚 `simple_reader_view.dart` 的弹层与入口改动。
2. 新增设置字段改动独立提交，问题出现时可仅回退模型层。
3. 保留差异矩阵与回归路径，避免重复引入偏差。

## 验收与证据

### 手工回归路径

1. 路径 A（入口）
   - 阅读页 -> 菜单 -> 点击 `界面` 与 `设置`。
   - 期望：进入各自同义面板，职责边界清晰。
2. 路径 B（设置主链路）
   - 在 `设置` 中切换进度条行为、翻页阈值、音量键翻页、滚动无动画。
   - 期望：即时生效，返回阅读页行为一致。
3. 路径 C（显示相关）
   - 切换状态栏/导航栏/亮度条显示，验证菜单展示与系统 UI 行为。
   - 期望：与 legado 语义同义。
4. 路径 D（持久化）
   - 修改设置 -> 退出阅读页 -> 重进。
   - 期望：设置持久化不丢失。
5. 路径 E（信息配置）
   - 在 `界面` 弹层点击 `信息`，调整标题/页眉页脚配置。
   - 期望：配置即时可见并可持久化。

### 命令验证

- 开发过程：执行与改动相关的定向测试/手工回归，不执行 `flutter analyze`。
- 提交推送前：执行且仅执行一次 `flutter analyze`。

## Progress

- `2026-02-20`：
  - 已完成：
    - 根据需求方新指令，将工作主线切回“阅读器界面及设置”；
    - 完成 legacy 基准复核（`ReadStyleDialog/MoreConfigDialog/TipConfigDialog/ReadMenu` 相关代码与布局）；
    - 完成首轮差异矩阵，落盘本 ExecPlan，并将 `TTS` 计划标记为 `blocked`。
    - 完成 Step 2：将菜单“设置”入口改为独立 `MoreConfig` 弹层（固定高度 `360dp` 语义、单屏偏好列表），不再复用四页签设置弹层；
    - 按 `pref_config_read.xml` 主链路顺序补齐已实现项入口（方向、亮屏、状态栏/导航栏、进度条行为、翻页触发阈值、点击区域、返回键等）；
    - 保持“界面”入口仍走 `ReadStyleDialog` 链路，完成 `界面/设置` 职责拆分。
    - 完成 Step 3A：`keep_light` 改为 legado 同义五档值（`0/60/300/600/-1`），并新增兼容字段映射（旧 `keepScreenOn=true` 迁移为 `-1` 常亮）；
    - 阅读器 `设置 -> 亮屏时长` 入口改为 `默认/1分钟/5分钟/10分钟/常亮`，对应值与 legado `screen_time_out(_value)` 一致；
    - 阅读器内新增计时策略：交互/翻页/滚动触发重置计时，超时后自动关闭 `keep_screen_on`；自动阅读运行时保持常亮。
    - 完成 Step 3B：`界面 -> 信息` 入口改为独立弹层链路 `_showLegacyTipConfigDialog`，不再复用通用“阅读设置页签弹层”；
    - `信息` 弹层按 `TipConfigDialog` 语义拆分为四组：`正文标题`、`页眉`、`页脚`、`页眉页脚`，覆盖标题模式/字号与上下间距、页眉页脚显示模式、左右中槽位配置、文字与分割线颜色；
    - `信息` 入口触发行为对齐 legado：在 `ReadStyleDialog` 内可直接打开信息配置弹层，不再切走到“设置”入口链路。
  - 进行中：
    - Step 5：逐项检查清单与最终验收证据回填。
  - 本轮新增（Step 4）：
    - 补齐 `pref_config_read.xml` 未覆盖主线 key 的可达实现：
      - `paddingDisplayCutouts`：新增设置字段并接入翻页/滚动模式的安全区留边逻辑；
      - `showReadTitleAddition`：新增开关，控制顶部菜单“章节/书源附加信息”展示；
      - `readBarStyleFollowPage`：新增开关，顶部/底部菜单支持按当前阅读主题着色。
    - 补齐 legacy 映射字段（持久化层）：
      - `volumeKeyPageOnPlay`：新增字段与设置入口，保留 legado 语义位；
      - `showReadTitleAddition`、`readBarStyleFollowPage`、`paddingDisplayCutouts`：新增 JSON roundtrip 与 sanitize 流程。
    - `UI-S5` 处理：
      - `设置编码` 占位提示改为带原因的可观测提示（“书籍级编码覆盖尚未接入正文解析链路”）。
    - 新增 `customPageKey` 的入口映射（显示为“翻页按键 -> 配置”），当前按扩展冻结口径保持 `blocked`。
  - Step 4 例外项（blocked，按 1.1.2 记录）：
    - 例外 A：`customPageKey`
      - 原因：Flutter 端尚无等价 `PageKeyDialog`（按键学习/映射录入）与对应持久化结构。
      - 影响范围：外接键盘/TV 遥控器的“自定义翻页按键”不可配置。
      - 替代方案：保留现有默认按键映射（方向键/PageUpDown/空格/音量键）并提供可观测提示。
      - 回补计划：在“扩展功能解锁”后新增键位采集弹层与键码持久化，再接线到按键翻页解析。
    - 例外 B：`volumeKeyPageOnPlay` 运行态联动
      - 原因：该能力依赖 TTS 播放状态；当前 TTS 计划在独立 ExecPlan 中为 `blocked`。
      - 影响范围：朗读功能未启用时该开关无可观测行为差异（仅完成配置迁移与持久化）。
      - 替代方案：先保留字段与入口，避免后续数据结构再次迁移。
      - 回补计划：TTS 计划解锁后，在按键事件分发中补齐“朗读中禁用/启用音量翻页”条件。
    - 例外 C：`设置编码`
      - 原因：当前正文解析链路缺少“书籍级 charset 覆盖”注入点；`RuleParserEngine.getContent` 仅按书源规则/响应推断。
      - 影响范围：阅读菜单中的“设置编码”无法像 legado 一样即时重载正文编码。
      - 替代方案：保留菜单入口并输出明确原因提示，避免静默失效。
      - 回补计划：后续新增 book-level charset 持久化字段与解析链路强制编码参数，再执行章节重载。
  - 命令验证（本轮）：
    - `dart format lib/features/reader/models/reading_settings.dart`
    - `dart format lib/features/reader/views/simple_reader_view.dart`
    - `dart format lib/features/reader/widgets/reader_menus.dart`
    - `dart format lib/features/reader/widgets/reader_bottom_menu.dart`
    - `dart format lib/features/reader/widgets/paged_reader_widget.dart`
    - `flutter test test/reading_settings_test.dart test/reader_bottom_menu_new_test.dart test/paged_reader_widget_non_simulation_test.dart test/simple_reader_view_compile_test.dart`
    - 未执行 `flutter analyze`（符合仓库规则：仅提交前执行一次）。
  - 兼容影响：
    - `设置` 入口交互路径发生变化（由“四页签弹层”改为“独立 MoreConfig 弹层”）；
    - `ReadingSettings` 新增 `keepLightSeconds`，并保留 `keepScreenOn` 兼容映射，已有配置可无损迁移；
    - `ReadingSettings` 新增 `paddingDisplayCutouts` / `volumeKeyPageOnPlay` / `showReadTitleAddition` / `readBarStyleFollowPage`，旧配置缺失字段时按 legado 默认值回填；
    - `keep_light` 语义差异已消除（现为 legado 同义时长列表与交互触发重置策略）。

## 逐项对照清单（Step 2/3 回填）

| 项目 | legado 基准 | 当前实现 | 结论 |
|---|---|---|---|
| 设置入口层级 | `ReadMenu.llSetting -> MoreConfigDialog` | 菜单“设置”直达 `_showLegacyMoreConfigDialog` | 已同义 |
| 弹层高度语义 | `setLayout(..., 360.dpToPx())` | 弹层高度 `360 + bottomInset` | 已同义（平台安全区差异） |
| 布局形态 | 偏好列表单屏滚动 | 单卡片偏好列表滚动，无页签 | 已同义 |
| 与界面入口职责分离 | `llFont` 与 `llSetting` 分离 | “界面”仍走 `_showReadStyleDialog`，“设置”走 MoreConfig | 已同义 |
| `keep_light` 语义 | 时长列表（`0/60/300/600/-1`） | 五档值 + 计时重置策略，保持旧布尔配置兼容迁移 | 已同义 |
| `信息` 入口链路 | `ReadStyleDialog.tvTip -> TipConfigDialog` | `ReadStyleDialog` 内直接打开 `_showLegacyTipConfigDialog` 独立弹层 | 已同义（入口链路） |
| `paddingDisplayCutouts` | `PageView.upPaddingDisplayCutouts` | 新增设置字段并接入 paged/scroll 安全区留边计算 | 已同义（平台 Insets 机制差异） |
| `showReadTitleAddition` | `ReadMenu.titleBarAddition` 显隐 | 新增开关控制顶部菜单附加信息（章节/书源）显隐 | 已同义 |
| `readBarStyleFollowPage` | `ReadMenu.immersiveMenu` 着色 | 新增开关控制顶部/底部菜单随阅读主题着色 | 已同义（配色插值实现差异） |
| `volumeKeyPageOnPlay` | 朗读时音量键翻页条件 | 已补字段与入口，待 TTS 状态接线 | `blocked`（依赖 TTS 计划） |
| `customPageKey` | `PageKeyDialog` 自定义键位 | 已补入口映射，当前仅提示不可用 | `blocked`（扩展冻结 + 平台能力缺口） |
| `设置编码` | `showCharsetConfig -> ReadBook.setCharset` | 保留入口并输出明确不可用原因 | `blocked`（解析链路缺口） |

## Surprises & Discoveries

1. `设置` 入口当前虽覆盖了部分选项，但交互形态与 legado 的 `MoreConfigDialog + pref_config_read` 语义差异仍然明显。
2. `信息` 入口曾被并入通用设置页，和 legacy 的独立 `TipConfigDialog` 路径不一致；本轮已改为独立弹层链路。
3. 通过“新增 `keepLightSeconds` + 保留 `keepScreenOn` 兼容字段”的双轨方案，可在不破坏旧配置数据的前提下完成时长语义迁移。
4. legado 在 `ReadView` 触摸/翻页流程中会多点触发 `screenOffTimerStart()`；Flutter 端需在点击、按键、滚轮、翻页和滚动起始处补齐计时重置。
5. 现有 Flutter `tip` 值域与 legado `ReadTipConfig.tipValues` 仍存在编码差异（例如 `batteryPercentage/totalProgress1` 语义尚未完全对齐）；已纳入 Step 4 分类处理。
6. legado 对 `volumeKeyPageOnPlay` 的默认值在 `pref_config_read.xml` 与 `AppConfig` getter 之间存在历史差异（`false` vs fallback `true`）；本轮沿 `AppConfig` 运行态默认值对齐为 `true`。

## Decision Log

1. 按需求方指令立即停止 `TTS` 计划推进，将其状态调整为 `blocked`。
2. 本轮优先修正“入口层级 + 设置语义”两类偏差，不先做高风险扩展项。
3. 对 legacy 未覆盖项采取“先分类后实现”策略：主线必做项进入实现，非主线保持 `blocked` 并记录回补计划。
4. Step 2 采用“先结构同义、后语义补齐”策略：先恢复 `MoreConfig` 单列表入口，再在 Step 3A/4 补齐 `keep_light` 时长语义与遗留 key。
5. Step 3A 采用“时长枚举主字段 + 布尔兼容迁移”策略，优先保证 legado 语义同义，同时避免破坏既有持久化数据。
6. Step 3B 采用“先恢复独立入口链路，再按 TipConfig 分组落位”的策略；`tip` 编码层差异保留到 Step 4 统一分类并决定回补方案。
7. Step 4 对 `UI-S4/UI-S5` 采用“主线先同义、例外先落盘”策略：可直接同义的 key 本轮补齐，无法等价项按 `blocked` 记录原因/影响/替代/回补计划。

## Outcomes & Retrospective

- 当前里程碑（Step 3A/3B）已完成：
  - `keep_light` 语义闭合（配置值、文案、状态流转、持久化兼容）；
  - `信息` 入口已恢复独立 `TipConfig` 链路（标题/页眉/页脚/颜色配置可达）；
- 当前里程碑（Step 4）已完成：
  - `paddingDisplayCutouts` / `showReadTitleAddition` / `readBarStyleFollowPage` 已落地并可持久化；
  - `customPageKey` / `volumeKeyPageOnPlay`（运行态联动）/ `设置编码` 已按规则记录为 `blocked` 例外项；
  - 仍待完成 Step 5 的最终逐项验收与证据收尾后再进入任务完成态。
