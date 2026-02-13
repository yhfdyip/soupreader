# SoupReader 开发进度日志

## 2026-02-12（设置系统 UI/UX 优化第二批：全页密度一致性收口）

### 已完成
- 对剩余设置子页统一应用“紧凑留白”规范，收敛视觉密度：
  - `about_settings_view.dart`
  - `appearance_settings_view.dart`
  - `backup_settings_view.dart`
  - `storage_settings_view.dart`
  - `text_rules_settings_view.dart`
  - `reading_preferences_view.dart`
  - `reading_theme_settings_view.dart`
  - `reading_tip_settings_view.dart`
  - `reading_page_settings_view.dart`
  - `reading_status_action_settings_view.dart`
  - `reading_other_settings_view.dart`
- `storage_settings_view.dart` 缓存状态文案统一为短标签格式：
  - `缓存大小 · 章节数量`（复用 `SettingsUiTokens.status`）。
- 延续“计划中”弱化策略到 Hub/源管理等补充页面：
  - `source_management_view.dart`
  - `other_hub_view.dart`
  - `function_settings_view.dart`

### 为什么
- 第一批已优化首页和主二级页，但部分子页仍存在默认留白与文案密度不一致，切换页面时观感跳变明显。
- 需要将设置系统整体拉齐到同一信息密度与语义表达规范。

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 从设置首页依次进入“主题/功能&设置/源管理/其它设置/阅读设置”，确认列表顶部留白与分组密度一致；
  - 进入“下载与缓存”，确认缓存状态文案改为 `值 · 值` 的短标签风格；
  - 进入占位项，确认仍展示统一的“计划中”弹窗。

### 兼容影响
- 本批次仅为设置页面布局密度和文案样式统一，不涉及数据模型、存储键、网络与书源链路。
- 旧书源兼容性无协议级影响。

## 2026-02-12（设置系统 UI/UX 优化：信息密度优先 + 计划中弱化）

### 已完成
- 设置系统首页与二级页完成统一优化（iOS 风格、可用项优先）：
  - `settings_view.dart`
    - 四区块结构保持不变（源管理/主题/功能&设置/其它），但区块内按“可用优先、计划中后置”重排；
    - 压缩列表密度（顶部/底部留白、区块间距、行内垂直 padding、图标尺寸）；
    - 新增“计划中”弱化样式：占位项标题、图标和右侧状态文案统一降权；
    - 状态文案统一为短标签 + 数值（如 `仅 Wi‑Fi · 缓存 xxx`）。
  - `theme_settings_view.dart`、`other_settings_view.dart`、`function_settings_view.dart`、`source_management_view.dart`、`other_hub_view.dart`
    - 将右侧 `暂未实现` 统一改为 `计划中`，并使用次级颜色显示；
    - 页面列表统一收紧顶部/底部空白，提升同屏可见信息量。
  - `global_reading_settings_view.dart`
    - 同步收紧列表顶部间距；
    - `界面（样式）`摘要更新为 `主题 / 字体 / 排版 / 翻页动画`，与当前阅读设置语义一致。
- 新增设置 UI 规范常量：
  - `settings_ui_tokens.dart`：统一 `计划中` 文案、状态拼接与占位文案归一化能力。
- 占位弹窗统一：
  - `settings_placeholders.dart` 改为统一标题 `计划中`，并自动将传入文案中的 `暂未实现` 归一化为 `计划中`。

### 为什么
- 你要求对设置页做优化，目标是“信息密度 + 可读性”优先，并在全设置系统范围内保持一致。
- 原实现中“暂未实现”项视觉权重过高，且列表行高/留白偏松，导致有效信息同屏承载不足。

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 设置首页：确认可用项前置、`计划中`项弱化、同屏可见项增多；
  - 进入 `主题` / `其它设置` / `源管理` / `功能&设置`：确认占位项右侧文案统一为 `计划中`；
  - 点击任一占位项：弹窗标题统一为 `计划中`，内容文案不再出现“暂未实现”原词。

### 兼容影响
- 本次仅为设置系统 UI/UX 与文案层调整，不涉及数据结构、存储键、书源解析与请求链路。
- 旧书源兼容性无协议级影响。

## 2026-02-12（阅读器配置复刻 legado：布局排版与操作逻辑重排）

### 已完成
- 阅读页内配置弹层按 legado 语义重排：
  - `界面` 分组新增并承接 `翻页动画`（翻页模式 + 动画时长）；
  - 将 `页眉页脚` 的显示开关、分割线和三栏内容位配置迁移到 `界面` 分组；
  - `设置` 分组收敛为行为项：翻页触发/按键、状态栏显示、点击区域、自动阅读与其他行为。
- 全局阅读设置入口与阅读页分组同构：
  - `reading_interface_settings_hub_view.dart` 改为 `样式与排版`、`页眉页脚与标题`、`排版与边距（高级）` 三段结构；
  - 新增 `reading_tip_settings_view.dart` 承接 legado `TipConfig` 对应能力（标题位置、页眉页脚内容位/分割线）；
  - `reading_behavior_settings_hub_view.dart` 与子页面文案/分组同步收敛为行为域。
- 全局子页面职责重排：
  - `reading_preferences_view.dart` 增加 `翻页动画时长`（界面域）；
  - `reading_page_settings_view.dart` 移除动画项，仅保留翻页触发与按键/文本行为；
  - `reading_status_action_settings_view.dart` 移除页眉页脚配置，仅保留状态栏与点击区域。

### 为什么
- 需求要求“复刻 legado 的布局排版与操作逻辑”，并保持 `Shadcn + Cupertino` 组件约束。
- 现状中 `翻页动画` 与 `页眉页脚` 分散在行为页，导致与 legado 的 `界面/设置` 分工不一致，用户操作路径不稳定。

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 阅读页 -> 菜单 -> `界面`：确认可设置主题/排版/翻页动画/页眉页脚；
  - 阅读页 -> 菜单 -> `设置`：确认仅剩行为项（灵敏度/按键/点击区域/自动阅读等）；
  - 设置 -> 功能&设置 -> 阅读设置 -> `界面（样式）/设置（行为）`：确认分组与阅读页内同构。

### 兼容影响
- 仅调整阅读器配置 UI 的分组与入口，不变更 `ReadingSettings` 存储结构与解析逻辑。
- 不涉及书源解析、网络请求和五段链路（search/explore/bookInfo/toc/content）。
- 旧书源兼容性无协议级影响。

## 2026-02-12（阅读器配置 UI/UX 重构：操作路径对齐 legado + Shadcn）

### 已完成
- 阅读页底部菜单重构为 `目录 / 朗读 / 界面 / 设置` 固定入口，交互路径对齐 legado。
- `ReaderBottomMenuNew` 改为 Shadcn 风格卡片与按钮实现，保留章节进度与亮度调节。
- 阅读设置弹层支持按入口裁剪：
  - `界面` 入口只展示 `排版/界面` 两类配置；
  - `设置` 入口只展示 `翻页/其他` 两类配置。
- 新增朗读入口能力检测：当前版本未接入 TTS 时，明确提示 `语音朗读（TTS）暂未实现`。
- 全局阅读设置页重构：改为 `界面（样式）` 与 `设置（行为）` 两个主入口，与阅读页内操作语义保持一致。
- 新增两个 Hub 页面承接全局配置入口：
  - `reading_interface_settings_hub_view.dart`
  - `reading_behavior_settings_hub_view.dart`

### 为什么
- 需求要求优先重构阅读器配置界面 UI/UX，并“操作方式跟 legado 一样，UI 使用 shadcn”。
- 现有实现存在阅读页内与全局设置页路径分叉、命名不一致的问题，增加学习和维护成本。

### 如何验证
- 手工路径：
  - 阅读页打开菜单，确认底部主入口顺序为 `目录/朗读/界面/设置`。
  - 点击 `界面`，确认仅出现样式相关配置分组。
  - 点击 `设置`，确认仅出现行为相关配置分组。
  - 点击 `朗读`，确认触发能力检测并给出明确提示。
  - 进入“设置 -> 功能&设置 -> 阅读设置”，确认全局入口为 `界面（样式）/设置（行为）`。
- 静态检查：尝试执行 `flutter analyze`（当前环境缺少 Flutter 命令，无法执行）。

### 兼容影响
- 本次主要是阅读器 UI/交互路径重排，不改书源解析引擎与网络请求逻辑。
- 对旧书源兼容性无直接协议级影响。

## 2026-02-12（analyze 报错修复：主题类型导入 + concurrentRate 兼容回填）

### 已完成
- 修复 `reader_bottom_menu.dart` 缺失 `ReadingThemeColors` 导入导致的 `undefined_class`。
- 对标 legado 并发率语义，给 `RuleParserEngine` 回填并发率限流兼容能力：
  - 新增并发率记录池（按 `sourceKey` 共享）与测试重置入口 `debugResetConcurrentRateLimiterForTest()`；
  - 支持 `N`（间隔模式）与 `count/window`（窗口模式）两种 `concurrentRate` 语义；
  - 在 `_fetchDebug` 输出 `concurrentWaitMs` 与 `concurrentDecision`；
  - 在 `search/explore/bookInfo/toc/content` 的调试与实际请求链路统一透传 `source.concurrentRate`。
- 调试链路日志补充并发率决策与累计等待时间，保持五段链路可观测性。

### 为什么
- `flutter analyze` 报错包含：
  - 阅读器底部菜单类型未定义；
  - 并发率兼容测试依赖的调试接口（方法/字段）缺失。
- 按协作规范先对齐 legado：完整阅读并参照
  - `../legado/app/src/main/java/io/legado/app/help/ConcurrentRateLimiter.kt`
  - `../legado/app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeUrl.kt`
  的并发率状态流转与等待语义后再回填实现，避免主观改写。

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 并发率兼容验证路径（自动化）：
  - `test/rule_parser_engine_concurrent_rate_compat_test.dart` 中依赖的方法与字段已恢复可解析（`debugResetConcurrentRateLimiterForTest` / `concurrentWaitMs` / `concurrentDecision`）。

### 兼容影响
- 旧书源若 `concurrentRate` 为空或为 `0`，行为保持不变（不启用限流）。
- 旧书源若配置了 `concurrentRate`，请求链路将按 legado 语义执行等待：
  - `N`：间隔模式；
  - `count/window`：窗口模式（保持 legado 的计数判定细节）。
- 该改动可能改变同源高并发请求的时间分布，但这是对 legado 兼容行为的恢复。

## 2026-02-12（后续计划推进：目录规则入口落地）

### 已完成
- 将设置页与源管理页中的“目录规则”从“暂未实现”占位改为可用入口：
  - `SettingsView` 的“目录规则”点击后直接进入 `SourceListView`；
  - `SourceManagementView` 的“目录规则”点击后直接进入 `SourceListView`。
- “目录规则”右侧说明文案由“暂未实现”改为“书源编辑”，与实际能力一致。

### 为什么
- 原入口仅弹未实现提示，无法形成实际操作闭环。
- 按 legado 交互语义，目录规则属于书源编辑/调试体系，不是独立设置页：先进入书源管理，再在书源编辑里维护 `ruleToc`/`ruleContent`。
- 已对照并完整阅读 legado 对应实现：
  - `../legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceActivity.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/source/edit/BookSourceEditActivity.kt`

### 如何验证
- 手工路径：
  - 设置 -> 目录规则：应进入“书源管理”页面；
  - 设置 -> 源管理 -> 目录规则：应进入“书源管理”页面；
  - 在书源编辑页 `ruleToc` 分组可继续配置目录规则。
- 静态检查：`flutter analyze`（结果：`No issues found!`）。

### 兼容影响
- 不涉及书源解析逻辑与数据结构变更，仅为入口导航调整。
- 旧书源兼容性无协议级影响。

## 2026-02-12（协作规范更新：UI 约束升级为全局强制）

### 已完成
- 更新 `AGENTS.md` 的 `1.2 UI 规范（强制）`，将 `Shadcn + Cupertino` 从原则要求升级为全项目强制约束。
- 新增明确规则：
  - 全项目新增/改造 UI 必须使用 `Shadcn + Cupertino` 组合；
  - 禁止引入或混用其它 UI 体系作为主实现；
  - 特殊场景需在任务说明与进度文档中记录原因、范围和替代方案；
  - 不符合该规范的改动在评审中视为阻塞项。

### 为什么
- 需求明确要求“全局强制使用 `Shadcn + Cupertino`”，需要在项目协作规范中固化，避免后续执行口径不一致。

### 如何验证
- 手工检查：
  - 打开 `AGENTS.md`，确认 `1.2 UI 规范（强制）` 已包含上述 4 条新增约束。
  - 后续任务设计与实现需按该条款执行，若有例外必须在 `docs/DEV_PROGRESS.md` 记录说明。

### 兼容影响
- 该改动仅影响协作与评审规范，不影响现有运行时代码逻辑与旧书源兼容性。

## 2026-02-12（阅读器 UI 合规重构：SimpleReaderView 子弹窗 + 书签弹窗）

### 已完成
- `simple_reader_view.dart`：
  - 将翻页模式选择从 `ChoiceChip` 替换为 `CupertinoButton + 自定义容器` 方案，保留“隐藏模式”不可选语义；
  - 将字体选择弹窗条目从 `ListTile` 替换为 `CupertinoButton + Row` 方案，保留选中态勾选与点击即生效行为；
  - Material 导入收敛为 `show Colors`，避免引入 Material 组件实现。
- `bookmark_dialog.dart`：
  - 移除 `SnackBar/ScaffoldMessenger`，改为 Cupertino 弹出式轻提示；
  - 书签空态、滑删背景、列表项、删除按钮全部替换为 Cupertino 图标与 Cupertino 交互组件；
  - 移除 `ListTile`，改为自定义行布局，保留“点条目跳转 / 点删除移除 / 左滑删除”语义。
- 删除未被路由使用的旧页面：`lib/features/reader/views/reader_view.dart`。

### 为什么
- 协作规范已升级为全项目强制 `Shadcn + Cupertino`，阅读器仍存在 Material 组件残留（`ChoiceChip`、`ListTile`、`SnackBar` 等），与规范冲突。
- `ReaderView` 已不在实际跳转链路中，继续保留会造成维护噪音和潜在误用。

### 如何验证
- 静态检查：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 打开阅读器设置 -> 翻页设置，验证模式切换可用，带“隐藏”标识的模式不可点选；
  - 打开字体选择弹窗，点击任意字体应立即生效并关闭弹窗；
  - 打开书签弹窗，验证添加提示、点击跳转、右侧删除、左滑删除均可用。

### 兼容影响
- 对书源解析、网络请求与五段链路（search/explore/bookInfo/toc/content）无逻辑改动。
- 阅读器 UI 交互行为保持原语义，主要是组件实现替换与旧页清理。
- `ReaderView` 已删除；若有外部分支仍直接引用该页面，需要改为 `SimpleReaderView`。

## 2026-02-12（阅读器 UI 合规重构第二批：去除 Material Slider/InkWell）

### 已完成
- `lib/features/reader/widgets/reader_bottom_menu.dart`
  - 将章节进度与亮度控制从 Material `Slider/SliderTheme` 重构为 `CupertinoSlider`；
  - 移除 Material 依赖，仅保留 `Shadcn + Cupertino` 组合实现。
- `lib/features/reader/widgets/typography_settings_dialog.dart`
  - 将排版设置中的 Material `Slider` 重构为 `CupertinoSlider`；
  - 同步移除 Material 颜色常量依赖。
- `lib/features/reader/widgets/reader_menus.dart`
  - 将底部菜单按钮从 `Material + InkWell` 重构为 `CupertinoButton`；
  - 将章节/亮度滑杆替换为 `CupertinoSlider`，移除 Material 组件依赖。
- `lib/features/reader/models/reading_settings.dart`
  - 将翻页模式与翻页方向图标从 Material `Icons` 迁移为 `CupertinoIcons`，统一图标体系。

### 为什么
- 你要求继续按规则重构 UI，而阅读器链路中的多个菜单与设置面板仍在使用 Material 交互组件（`Slider`、`InkWell` 等），与全局 `Shadcn + Cupertino` 约束不一致。
- 本批次优先处理“正在阅读链路中可见且交互频繁”的组件，降低 UI 体系混用风险。

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径：
  - 阅读页菜单 -> 底部菜单：章节拖动与亮度拖动可用；
  - 阅读页菜单 -> 排版设置：所有滑杆可调且即时生效；
  - 阅读页顶部/底部菜单点击反馈与原交互语义一致。

### 兼容影响
- 本次仅替换 UI 组件实现，不改阅读数据结构、请求链路与书源解析逻辑。
- 旧书源兼容性无协议级影响。

## 2026-02-12（阅读器/书架 UI 合规重构第三批：清理 Colors 级别 Material 依赖）

### 已完成
- `lib/features/bookshelf/widgets/book_cover_card.dart`
  - 从 Material 迁移到 Cupertino：移除 `Theme.of`、`CircularProgressIndicator`；
  - 文本样式改为 `CupertinoTheme`，加载态改为 `CupertinoActivityIndicator`。
- 阅读器弹窗与面板清理 Material `Colors` 依赖：
  - `lib/features/reader/views/simple_reader_view.dart`
  - `lib/features/reader/widgets/chapter_list_dialog.dart`
  - `lib/features/reader/widgets/click_action_config_dialog.dart`
  - `lib/features/reader/widgets/reader_status_bar.dart`
  - `lib/features/reader/widgets/reader_quick_settings_sheet.dart`
  - `lib/features/reader/widgets/reader_catalog_sheet.dart`
- 上述文件均移除 `import 'package:flutter/material.dart' show Colors`，并用 `CupertinoColors` / `Color` 常量替代。

### 为什么
- 虽然上一批已去掉主要 Material 交互组件，但仍有若干文件仅为 `Colors` 引入 Material，属于 UI 体系混用残留。
- 本批次目标是继续收敛到 `Shadcn + Cupertino`，并尽量保持视觉和交互行为不变。

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径：
  - 书架页：封面卡片、占位图、加载态显示正常；
  - 阅读页：目录弹窗、快速设置、点击区域配置、状态栏、电池图标与配色显示正常。

### 兼容影响
- 本次为 UI 实现层替换，不涉及数据模型、书源解析和网络请求逻辑变更。
- 旧书源兼容性无协议级影响。

## 2026-02-12（阅读器 UI 合规重构第四批：分页链路移除 Material 依赖）

### 已完成
- 分页核心与翻页委托链路从 `material.dart` 迁移到基础层导入（`widgets`/`cupertino`），并清理 `Colors.*` 残留：
  - `lib/features/reader/widgets/page_factory.dart`
  - `lib/features/reader/widgets/reader_page_agent.dart`
  - `lib/features/reader/widgets/paged_reader_widget.dart`
  - `lib/features/reader/widgets/simulation_page_painter.dart`
  - `lib/features/reader/widgets/simulation_page_painter2.dart`
  - `lib/features/reader/widgets/page_delegate/page_delegate.dart`
  - `lib/features/reader/widgets/page_delegate/no_anim_delegate.dart`
  - `lib/features/reader/widgets/page_delegate/slide_delegate.dart`
  - `lib/features/reader/widgets/page_delegate/cover_delegate.dart`
- 仅替换导入与颜色常量，不调整翻页状态机、动画轨迹与分页算法。

### 为什么
- 阅读器链路里仍有一批基础模块因为 `Colors` 或历史导入习惯依赖 `material.dart`，与全局 `Shadcn + Cupertino` 约束不一致。
- 这批文件属于底层分页渲染链路，优先做“行为不变”的依赖收敛，降低后续维护中的 UI 体系混用风险。

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 阅读页切换 `滑动/覆盖/仿真/无动画/滚动` 等翻页模式，确认翻页方向、阴影与手势行为正常；
  - 阅读页反复切章并切换主题，确认分页与状态栏渲染无异常。

### 兼容影响
- 本次不涉及书源解析、网络请求、数据库结构与设置持久化字段变更。
- 旧书源兼容性无协议级影响。

## 2026-02-12（UI 合规重构第五批：基础主题文件去 Material 类型导入）

### 已完成
- 将以下基础主题文件从 `material.dart` 导入替换为更底层导入（不改字段语义）：
  - `lib/app/theme/design_tokens.dart`：改为 `dart:ui`
  - `lib/app/theme/colors.dart`：改为 `dart:ui`
  - `lib/app/theme/typography.dart`：改为 `package:flutter/painting.dart`
- 保留 `lib/app/theme/app_theme.dart` 的 Material 依赖（`ThemeData`/`ColorScheme`/`AppBarTheme` 等确实需要）。

### 为什么
- 在功能层 UI 已完成 `Shadcn + Cupertino` 收敛后，仍有基础主题文件仅因类型声明而依赖 Material。
- 该批次目的是继续做低风险依赖收敛，减少 UI 体系混用的“隐式入口”。

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`

### 兼容影响
- 本批次仅调整导入层级，不改变设计令牌、配色值、排版值或运行行为。
- 旧书源兼容性无协议级影响。

## 2026-02-12（UI 合规重构第六批：书源编辑调试文本去 Material 依赖）

### 已完成
- `lib/features/source/views/source_edit_view.dart`
  - 移除 `SelectableText` 的 Material 导入；
  - 将调试区两处可选中文本区域改为 `SelectableRegion + Text`（Cupertino 选择控件）；
  - 增加并释放两个 `FocusNode`，避免选择区域焦点资源泄露。

### 为什么
- 书源编辑页调试面板仍因可选中文本使用了 Material 组件，属于 UI 体系混用残留。
- 本批次在保持“可复制/可选中调试文本”能力不变的前提下，继续向 `Shadcn + Cupertino` 收敛。

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径：
  - 进入书源编辑 -> 调试标签页；
  - 在“控制台文本”和“决策摘要”区域长按并选择文本，确认选择与复制行为可用。

### 兼容影响
- 本次仅替换调试文本展示组件，不涉及书源解析、网络请求或持久化结构变更。
- 旧书源兼容性无协议级影响。

## 2026-02-12（UI 合规重构第七批：清理最后 Material 导入）

### 已完成
- `lib/main.dart`
  - 移除 `ThemeMode` 的 Material 导入；
  - 改为根据 `_effectiveBrightness` 直接构造并注入 Shad 主题（`theme`/`darkTheme` 同步为当前有效主题），保持亮/暗切换行为。
- 删除未被引用的旧 Material 主题文件：
  - `lib/app/theme/app_theme.dart`
- 全库扫描确认：`lib/` 下已无 `flutter/material.dart` 导入。

### 为什么
- 前几批重构后仅剩入口层与遗留主题文件在使用 Material。
- 本批次目标是完成全链路收敛，避免后续新增 UI 继续沿用 Material 入口。

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径：
  - 设置中切换外观模式（浅色/深色/跟随系统）；
  - 观察主界面与阅读器配色随设置变化是否正常。

### 兼容影响
- 不涉及书源解析、网络请求、数据库结构与阅读规则语义变更。
- 删除的 `app_theme.dart` 为未使用遗留文件；运行路径无功能依赖。

## 2026-02-12（功能入口落地：功能设置中的“阅读记录”接入实际页面）

### 已完成
- `lib/features/settings/views/function_settings_view.dart`
  - 将“阅读记录”从“暂未实现”占位改为实际可用入口；
  - 点击后跳转到 `ReadingHistoryView`；
  - 右侧说明文案从“暂未实现”调整为“历史列表”。

### 为什么
- legacy 对应行为是“我的 -> 阅读记录”直接进入阅读记录列表（`ReadRecordActivity`），不是占位弹窗。
- 当前项目已有 `ReadingHistoryView` 可承接该能力，继续保留占位会造成路径割裂。

### legado 对标（已完整读取）
- `../legado/app/src/main/java/io/legado/app/ui/about/ReadRecordActivity.kt`
- `../legado/app/src/main/java/io/legado/app/ui/main/my/MyFragment.kt`

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径：
  - 设置 -> 功能 & 设置 -> 阅读记录；
  - 应进入阅读记录列表页（`ReadingHistoryView`），不再弹“暂未实现”提示。

### 兼容影响
- 本次仅调整设置入口导航，不改阅读数据结构和记录存储逻辑。
- 旧书源兼容性无协议级影响。

## 2026-02-12（书源管理复刻 legado + 书源存储迁移到 drift）

### 已完成
- 书源域存储层改造为 drift（保留 Hive 仅作迁移来源）：
  - 新增 `lib/core/database/drift/source_drift_database.dart`
  - 新增 `lib/core/database/drift/source_drift_service.dart`
  - 新增 `lib/core/database/migration/source_hive_to_drift_migrator.dart`
- 启动流程接入迁移与缓存预热：
  - `DatabaseService.init()` 中新增 drift 初始化与 `Hive -> drift` 幂等迁移；
  - `main.dart` 新增 `SourceRepository.bootstrap` 启动步骤，确保上层同步读取可用。
- `SourceRepository` 重写为 drift 实现：
  - 写入：统一走 drift；
  - 读取：使用内存缓存 + `watchAllSources()` 流，兼容现有同步调用点；
  - 保留 `rawJson` 读写，继续支持 legado 字段保真。
- 书源管理页重构为 legado 管理语义（Shadcn + Cupertino）：
  - `source_list_view.dart` 从 Hive `ValueListenable` 改为 `SourceRepository.watchAllSources()`；
  - 新增排序模式（手动/权重/名称/地址/更新时间/响应时间/启用状态）与升降序切换；
  - 新增“按域名分组显示”与 host 头展示；
  - 新增选择模式、批量操作栏（全选/反选/区间补选、启停、发现启停、分组增删、导出、分享、删除）；
  - 新增分组管理弹层（新增、重命名、删除）；
  - 单项菜单补齐（编辑、置顶/置底、登录、调试、发现启停、分享、删除）。
- 导入能力升级为 legado 风格：
  - 导入预览弹层支持逐条勾选、仅新增、仅更新；
  - 新增保留策略开关：保留原名称 / 保留原分组 / 保留原启用状态；
  - 新增自定义分组与追加模式；
  - 导入策略配置持久化到设置。
- 管理链路联动改造：
  - `source_availability_check_view.dart` 与 `source_edit_view.dart` 联动改为基于 `BookSource + rawJson` 打开编辑；
  - `settings_view.dart` 书源统计改为 `SourceRepository`。

### 为什么
- 需求明确要求“优化书源管理功能，一切参考 legado”，且存储要求改为 drift。
- 原实现在管理页交互、批量操作、导入冲突策略、分组管理等方面与 legado 语义差异较大，且书源仍依赖 Hive。

### 如何验证
- 执行：`flutter pub get`
- 执行：`dart run build_runner build --delete-conflicting-outputs`
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 书源页验证排序/筛选/按域名分组；
  - 长按进入选择模式，验证批量操作；
  - 打开分组管理弹层，验证新增/改名/删除；
  - 用含“新增+更新+已有”的导入样本验证导入预览与保留策略。

### 兼容影响
- 书源读取/写入已切换为 drift；首次启动会自动从 Hive 迁移书源并写入迁移标记，迁移具备幂等性。
- 旧 Hive 书源数据保留在本地作为迁移来源，不作为主读写路径。
- 对旧书源 JSON 协议无破坏性变更，`rawJson` 保真策略继续生效。

## 2026-02-12（书源管理持续开发：补齐 legado 关键交互）

### 已完成
- `source_list_view.dart` 新增手动排序拖拽能力（仅在手动排序 + 全量列表场景启用）：
  - 使用拖拽手柄调整顺序；
  - 拖拽落位后重算 `customOrder` 并批量写入。
- 批量操作补齐 legado 高频动作：
  - 新增 `置顶` / `置底` 批量动作；
  - 新增 `校验` 批量动作（仅对已选书源进入可用性检测页）。
- 单项置顶/置底语义对齐 legado：
  - 当排序方向为降序时，单项“置顶/置底”会按 legado 行为映射到相反底层顺序操作。
- `source_availability_check_view.dart` 增加定向检测能力：
  - 新增可选参数 `sourceUrls`，支持只检测指定书源集合；
  - 当传入集合为空时安全退出，不触发无意义检测。

### 为什么
- 上一轮虽已完成主流程迁移，但仍缺少 legado 管理页中影响效率的关键操作：手动拖拽排序、批量置顶/置底、按选择集发起校验。
- 这些能力直接关系到书源维护效率和与 legado 的操作一致性。

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 书源页切到“手动排序 + 全部 + 无搜索”，验证拖拽手柄可排序；
  - 进入选择模式，选择多条书源，验证“置顶/置底”批量生效；
  - 选择若干书源点击“校验”，验证检测页仅包含所选书源。

### 兼容影响
- 不涉及书源协议字段和网络解析链路调整，仅为管理交互增强。
- 与已完成的 drift 存储方案兼容，写入仍统一走 `SourceRepository`。

## 2026-02-12（书源管理继续：单源搜索可用化 + 在线导入历史）

### 已完成
- `source_list_view.dart`
  - 单项菜单“搜索测试”从占位提示改为可用流程：
    - 先输入关键词；
    - 再进入搜索页并仅针对当前书源执行自动搜索。
  - 在线导入升级为带历史记录的弹层：
    - 支持历史地址回填、单条删除、清空历史；
    - 导入成功前会将 URL 维护到历史（去重并保留最近 20 条）。
  - 管理菜单新增“删除禁用书源”动作（带确认弹窗）。
- `search_view.dart`
  - 新增单源/多源范围搜索能力：
    - `sourceUrls`（可选）用于限定参与搜索的书源集合；
    - `initialKeyword` 与 `autoSearchOnOpen` 支持从书源管理页直接发起定向搜索。

### 为什么
- legado 的书源管理支持从单个书源直接进入搜索验证，当前实现为占位提示，影响校验效率。
- legado 在线导入包含历史输入复用语义，现有实现仅单次输入，频繁调源时效率偏低。
- 管理页需要保留“快速清理禁用源”的高频维护能力。

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 书源页 -> 单项菜单 -> 搜索测试：输入关键词后应跳转并仅搜索该书源；
  - 书源页 -> 从网络导入：验证历史地址展示、回填、删除与清空；
  - 书源页 -> 管理菜单 -> 删除禁用书源：验证数量提示与确认删除流程。

### 兼容影响
- 不改书源协议与解析引擎，仅增强管理交互与搜索入口参数。
- 搜索页默认行为不变（不传 `sourceUrls` 时仍是全启用书源搜索）。

## 2026-02-12（书源管理优先复刻：导入编辑闭环 + 扫码导入/调试）

### 已完成
- `source_list_view.dart`
  - 导入菜单新增“扫码导入”，扫码文本按 legado 导入语义处理：
    - `http/https` 按在线链接导入；
    - 其余文本按 JSON 导入；
    - 空结果直接取消，不触发错误弹窗。
  - 导入预览支持单条 JSON 编辑（弹层内“编辑JSON/已编辑”）：
    - 保存前校验 JSON、`bookSourceUrl`、`bookSourceName`；
    - 保存后实时重算“新增/更新/已有/重复”状态；
    - 导入提交时按 URL 去重（保留最后一条），并基于保留策略生成最终 `rawJson` 入库。
  - 补充导入重复 URL 提示，状态标签新增“重复”并高亮。
- 调试页 `source_edit_view.dart`
  - 调试“输入”区新增“扫码填充 Key”入口，扫码结果自动填入调试 key 输入框。
- 新增通用扫码能力：
  - `lib/features/common/views/qr_scan_view.dart`
  - `lib/core/services/qr_scan_service.dart`
  - `pubspec.yaml` 新增 `mobile_scanner`
  - Android/iOS 增加相机权限声明（用于扫码导入与扫码填 key）。

### 为什么
- legado 调试页提供扫码输入 key（`menu_scan`）用于快速复现实例，当前项目缺失该能力，调试效率不足。
- legado 导入流程强调“导入前可筛选 + 冲突感知 + 保留策略”，本轮优先把可影响导入正确性的闭环补齐（特别是重复 URL 与单条修正）。

### legado 对标（已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/association/ImportBookSourceViewModel.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 书源管理 -> 导入 -> 扫码导入：分别验证 URL 二维码 / JSON 二维码 / 空结果；
  - 导入预览中修改某条 JSON 的 URL 或名称后，验证状态标签与重复提示实时刷新；
  - 书源编辑 -> 调试 -> 扫码填充 Key -> 开始调试，验证 key 被正确注入并可执行调试流程。

### 兼容影响
- 不修改旧书源 JSON 协议字段，仅增强导入前校验与导入交互。
- 新增扫码依赖与相机权限声明；无相机权限时用户可继续使用剪贴板/文件/网络导入，不影响既有导入链路。

## 2026-02-12（书源管理持续复刻：sourceUrls 导入协议 + 校验关键词流程 + 域名分组排序细节）

### 已完成
- `source_import_export_service.dart`
  - 新增 `importFromText` 统一文本导入入口（URL / JSON / `sourceUrls`）。
  - 复刻 legado `sourceUrls` 语义：
    - 当输入为 `{"sourceUrls":[...]}` 时，逐条在线拉取并合并结果；
    - 汇总失败项告警与重复 URL 覆盖信息（后出现项覆盖前项）。
  - 在线导入补齐 `#requestWithoutUA` 兼容：
    - 识别 URL 后缀 `#requestWithoutUA`；
    - 请求时发送 `User-Agent: null`；
    - 导入结果附带对应提示信息。
  - 在线返回内容解析从“仅 JSON 书源”扩展为“再次走统一文本导入”，支持远端返回 `sourceUrls` 聚合入口。
- `source_list_view.dart`
  - 剪贴板导入、扫码导入切换为 `importFromText`，可直接识别 `sourceUrls` 聚合内容。
  - 批量校验与“检查可用性”入口增加“校验关键词”确认弹窗（默认记忆上次值，空输入回落到缓存值/`我的`）。
  - 向 `SourceAvailabilityCheckView` 透传 `keywordOverride`，对齐 legado `CheckSource.keyword` 流程。
  - 管理菜单新增“帮助（书源管理）”说明入口。
  - 按域名分组排序细节对齐 legado：无有效 host 的 `#` 分组排到最后；名称比较改为不区分大小写。
- `source_availability_check_view.dart`
  - 新增 `keywordOverride` 参数；
  - 搜索链路优先使用覆盖关键词，报告中记录本次关键词。

### 为什么
- legado 导入支持 `sourceUrls` 聚合入口和 `#requestWithoutUA` 兼容，当前实现未覆盖，导致一批真实分享源导入失败。
- legado 书源校验支持“运行前指定关键词并复用上次输入”，当前实现固定使用规则内关键词，复现问题时效率较低。
- 域名分组排序细节（`#` host 位置）与 legado 行为存在差异，需要补齐。

### legado 对标（已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceAdapter.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceViewModel.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/GroupManageDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceSort.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/association/ImportBookSourceDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/association/ImportBookSourceViewModel.kt`

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 导入：
    - 剪贴板放入 `{"sourceUrls":["https://..."]}`，验证可拉取导入；
    - 导入 URL 使用 `...#requestWithoutUA`，验证可识别并导入；
    - 扫码导入 `sourceUrls` JSON，验证与剪贴板一致。
  - 校验：
    - 书源管理 -> 批量“校验”或“检查可用性”，确认先弹“校验关键词”；
    - 输入关键词后进入检测页，确认报告中显示该关键词。
  - 分组排序：
    - 开启“按域名分组”后，确认无有效 host 的书源分组显示在列表末尾。

### 兼容影响
- 导入入口向后兼容原有 JSON/URL 语义；新增 `sourceUrls` 与 `#requestWithoutUA` 不影响旧书源导入。
- 校验关键词仅作为检测时覆盖参数，不修改书源规则字段本身。

## 2026-02-12（书源调试复刻：legacy 菜单动作 + 快捷区排版）

### 已完成
- `source_edit_view.dart` 调试 Tab 按 legacy 交互补齐：
  - 输入区新增 legacy 菜单同类动作入口：
    - 查看搜索源码 / 查看详情源码 / 查看目录源码 / 查看正文源码
    - 刷新发现快捷项
    - 调试帮助
  - 快捷区排版升级为“对标 Legado”语义：
    - 快捷按钮覆盖：`我的`、`系统`、`发现候选`、`详情URL`、`++目录`、`--正文`
    - `我的/系统/发现候选` 直接填充并执行调试
    - `++目录/--正文` 在已有 key 时自动加前缀并执行
  - 新增发现候选提取能力：
    - 从 `exploreUrl` 与 `exploreScreen`（JSON/文本）提取可用发现入口；
    - 候选过多时可弹出选择面板。
  - 新增调试帮助页（文本说明），集中说明 key 语法与快捷入口行为。

### 为什么
- legado 调试页具备“扫码 + 菜单动作 + 帮助提示 + 快捷输入”的完整闭环；
- 当前实现虽有调试能力，但缺少 legacy 菜单入口的直达体验，且快捷区语义不够完整。

### legado 对标（已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugModel.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugAdapter.kt`
- `/home/server/legado/app/src/main/res/menu/book_source_debug.xml`
- `/home/server/legado/app/src/main/res/layout/activity_source_debug.xml`
- `/home/server/legado/app/src/main/res/layout/item_log.xml`

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 书源编辑 -> 调试：
    - 验证“查看搜索/详情/目录/正文源码”入口可打开对应页面；
    - 验证“刷新发现快捷项”会更新候选并提示数量；
    - 验证“调试帮助”可查看完整说明。
  - 快捷区：
    - 点击“我的/系统/发现候选”应自动触发调试；
    - 输入详情 URL 后点击“详情URL”应按当前 key 重新执行；
    - 对已有 key 点击“++目录/--正文”应自动加前缀并执行。

### 兼容影响
- 调试增强仅影响调试页交互，不改书源协议字段与解析引擎核心逻辑。
- 发现候选提取是调试辅助能力，提取失败时不影响原有手动输入调试。

## 2026-02-12（书源管理收口：文件分享语义 + 校验摘要联动 + 调试刷新发现）

### 已完成
- `source_list_view.dart`
  - 批量“分享”改为文件分享语义（对齐 legado `saveToFile + share(file)`）：
    - 优先生成临时 JSON 文件并调用系统分享；
    - 系统分享不可用时回退为复制 JSON 到剪贴板。
  - 新增“最近校验摘要”联动展示区：
    - 显示最近校验时间、总量、可用/失败/空列表/超时/跳过统计；
    - 支持一键筛选“失败/空列表”书源；
    - 管理菜单新增“最近校验摘要”入口。
  - 失败筛选状态接入主列表过滤与排序摘要文案，可随时清除筛选。
- `source_availability_check_view.dart`
  - 每次检测完成后写入全局摘要状态（供管理页联动）。
  - 摘要包含：检测范围、关键词、统计计数、失败 URL 集合。
- `source_edit_view.dart`
  - “刷新发现快捷项”升级：
    - 基于当前编辑态书源触发一次 `exploreDebug` 请求；
    - 合并请求 URL 与本地 `exploreUrl/exploreScreen` 解析结果刷新候选；
    - 请求异常时仍保留本地候选并提示异常摘要。
  - 调试帮助文案改为统一常量，减少重复维护。
- `source_import_export_service.dart`
  - 新增 `exportToShareFile`：生成分享用临时 JSON 文件。
- 文档
  - 新增 `docs/source_management_parity_checklist.md`，整理当前对齐项与剩余差异。
  - 新增统一帮助文案文件：`lib/features/source/constants/source_help_texts.dart`。

### 为什么
- legado 书源管理“分享”是文件分享语义，复制 JSON 仅能作为兜底，需补齐系统分享主路径。
- 可用性检测结果需要回流到管理页，才能形成“检测 -> 定位失败源 -> 批量处理”的闭环。
- 调试页“刷新发现”需要体现“重新刷新候选 + 请求反馈”的能力，便于快速定位发现链路问题。

### legado 对标（已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceViewModel.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/source/BookSourceExtensions.kt`

### 如何验证
- 执行：`flutter analyze`
- 手工路径建议：
  - 书源管理 -> 选择多条 -> 分享：确认拉起系统分享面板（异常时回退复制 JSON）。
  - 书源管理 -> 检查可用性 -> 完成后返回：确认页面出现“最近校验摘要”，且可一键筛选失败源。
  - 书源编辑 -> 调试 -> 刷新发现快捷项：确认提示刷新数量；请求异常时能看到异常提示但候选仍可用。

### 兼容影响
- 批量分享新增 `share_plus` 依赖；在不支持系统分享的平台会自动回退到剪贴板，不影响既有导出能力。
- 校验摘要为 UI 联动状态，不改变书源存储结构与导入协议。

## 2026-02-12（书源调试差异收口：exploreKinds JS 缓存语义复刻）

### 已完成
- 新增 `source_explore_kinds_service.dart`，复刻 legado `BookSource.exploreKinds / clearExploreKindsCache` 关键行为：
  - 支持 `exploreUrl` 的普通文本、JSON 数组、`@js:`、`<js>` 四类语义；
  - `@js:`/`<js>` 执行结果支持持久化缓存（`sourceUrl + exploreUrl` 维度）；
  - 支持手动清理缓存后强制刷新，语义对齐 legado “刷新发现”。
- `source_edit_view.dart`
  - 调试页“刷新发现快捷项”改为：
    - 先清理 `exploreKinds` 缓存；
    - 再按 `exploreKinds` 规则重建候选；
    - 结合一次 `exploreDebug` 请求结果更新快捷项；
    - 保留 `exploreScreen` 兜底候选解析。
- `docs/source_management_parity_checklist.md`
  - 将“exploreKinds JS 缓存差异”从未对齐项移除，当前仅保留后台常驻校验差异。

### 为什么
- legado 的“刷新发现”依赖 `exploreKinds` 缓存清理 + 重算机制；
- 仅做本地字符串解析会导致复杂 `@js` 分类源无法按 legado 语义稳定刷新。

### legado 对标（已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/help/source/BookSourceExtensions.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`

### 如何验证
- 执行：`flutter analyze`
- 手工路径建议：
  - 书源编辑 -> 调试 -> 刷新发现快捷项，确认复杂 `@js` 发现配置也能产出候选；
  - 连续刷新两次，确认第二次仍可快速复用候选（缓存命中路径）；
  - 修改 `exploreUrl` 后刷新，确认可重新计算候选（缓存键随规则变化）。

### 兼容影响
- 新增缓存仅用于“发现候选提取”辅助链路，不影响搜索/详情/目录/正文主解析流程。

## 2026-02-13（调试链路收口：key parser + orchestrator + 管理页调试摘要联动）

### 已完成
- `source_debug_key_parser.dart`
  - 新增统一 key 解析器，按 legado `Debug.startDebug` 语义固化 5 类输入：
    - 绝对 URL -> 详情调试；
    - `标题::url` -> 发现调试；
    - `++url` -> 目录调试；
    - `--url` -> 正文调试；
    - 其他文本 -> 搜索调试。
  - 增加非法 key 的标准化错误提示（空 key、前缀缺 URL）。
- `source_debug_orchestrator.dart`
  - 新增调试编排层，统一“解析 key -> 执行调试 -> 聚合事件结果”流程；
  - 调试页不再直接调用 `RuleParserEngine.debugRun`，统一走编排层。
- `rule_parser_engine.dart`
  - 修复发现调试语义偏差：
    - `标题::url` 分支改为对齐 legado `substringAfter("::")`；
    - 发现调试实际使用输入 URL（不再忽略传入 URL）。
- `source_debug_summary_store.dart`
  - 新增调试摘要 store，记录最近调试历史与“最近失败状态”书源集合。
- `source_edit_view.dart`
  - 调试执行改为 orchestrator 驱动；
  - 调试结束后解析结构化摘要并写入 `SourceDebugSummaryStore`；
  - key 输入区新增“当前解析类型”提示（搜索/详情/发现/目录/正文）。
- `source_list_view.dart`
  - 新增“最近调试摘要”展示条；
  - 新增“筛选调试失败源/清除调试筛选/详情”操作；
  - 管理菜单补充“最近调试摘要”“清除调试筛选”入口；
  - 列表过滤支持“校验失败筛选 + 调试失败筛选”并行生效。

### 为什么
- 当前调试入口多，缺少统一 key 语义层，容易出现“同一 key 在不同入口行为不一致”。
- legado 的 `标题::url` 会直接用传入 URL 做发现调试，现有实现存在偏差，影响问题复现准确性。
- 调试结果需要回流书源管理页，形成“调试失败 -> 快速筛源 -> 再调试”的闭环。

### legado 对标（已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/model/Debug.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugModel.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/source/BookSourceExtensions.kt`

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 书源编辑 -> 调试，分别输入：
    - 关键字、`https://...`、`发现::https://...`、`++https://...`、`--https://...`；
    - 验证 key 类型提示与执行链路一致。
  - 书源编辑 -> 调试 -> 使用 `标题::url`：
    - 验证日志中的“开始访问发现页”与输入 URL 一致。
  - 调试完成后返回书源管理：
    - 验证出现“最近调试摘要”；
    - 点击“筛选调试失败源”，验证列表仅保留最近失败书源。

### 兼容影响
- 新增编排层和摘要 store 仅影响调试链路，不改书源协议和数据库结构。
- 修复 `标题::url` 行为后，发现调试会严格使用输入 URL，旧“误用 exploreUrl”行为不再保留。

## 2026-02-13（iOS 书源调试主流程重排：输入优先 + 高级能力下沉）

### 已完成
- `source_edit_view.dart`
  - 调试 Tab 按 legacy 主路径重排为 4 段：
    - 输入区（`Key`、扫码填充、开始调试）；
    - 快捷区（`我的/系统/发现候选/详情URL/++目录/--正文`）；
    - 工具区（查看源码、刷新发现快捷项、更多工具）；
    - 日志控制台（作为主屏主体）。
  - 将原先主屏上的高级动作下沉到“更多工具”弹层：
    - 调试帮助、网页验证、结构化摘要查看/复制、调试包导出、变量快照查看/复制、复制控制台、复制最小复现、清空控制台。
  - 新增“高级诊断与源码”二级页面入口，集中承载：
    - 诊断标签与定位建议；
    - 源码/结果查看与变量快照等高阶排障内容。
  - 新增“查看源码/结果”二级菜单（ActionSheet），统一打开列表/详情/目录/正文/正文结果。
  - 日志区补充“最近错误”高亮卡片，保证失败信息在主屏可见。

### 为什么
- legado 调试页是“输入并立即执行 + 日志主屏”，当前实现功能虽全但入口过多、主流程不够聚焦。
- 需要在不删能力的前提下把高阶导出/摘要能力下沉，避免干扰 iOS 侧常规调试路径。

### legado 对标（已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugModel.kt`
- `/home/server/legado/app/src/main/res/layout/activity_source_debug.xml`
- `/home/server/legado/app/src/main/res/menu/book_source_debug.xml`

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 书源编辑 -> 调试：确认主屏仅保留输入/快捷/工具/日志四段；
  - 点击“查看源码”：确认弹出二级菜单并可打开各源码页；
  - 点击“更多工具”：确认可触达摘要、导出、变量快照、帮助、网页验证等能力；
  - 触发一次失败调试：确认日志区顶部显示“最近错误”并高亮。

### 兼容影响
- 仅调整调试页 UI 信息架构与入口层级，不改调试引擎语义、书源协议和数据库结构。
- 高级能力未删除，仅从主屏迁移到二级入口。

## 2026-02-13（iOS 调试体验收口：日志自动跟随与手动回到底部）

### 已完成
- `source_edit_view.dart`
  - 调试控制台默认显示模式从“文本”调整为“逐行”，贴近 legado 日志列表主视图。
  - 新增调试页滚动跟随机制：
    - 日志实时输出时，若处于底部附近自动跟随到最新日志；
    - 用户上滑离开底部后自动暂停跟随，不强制拉回。
  - 新增“回到最新日志”入口（位于调试工具区）：
    - 在暂停跟随且存在日志时展示；
    - 点击后滚动到底并恢复自动跟随。
  - 在“开始调试 / 清空控制台”时重置为自动跟随状态，保证每次新调试都从最新日志开始。

### 为什么
- legado 调试页核心体验是“执行后连续看最新日志”；
- 当前实现在日志量大或手动回看后，缺少明确的“恢复跟随”能力，主流程可读性不足。

### legado 对标（已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`
- `/home/server/legado/app/src/main/res/layout/activity_source_debug.xml`

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 书源编辑 -> 调试 -> 开始调试，观察日志应持续停留在底部最新行；
  - 调试过程中手动上滑，确认不再自动拉回；
  - 点击“回到最新日志”，确认滚动到底并恢复自动跟随。

### 兼容影响
- 仅调试页滚动交互优化，不改调试引擎、书源协议、数据库结构。

## 2026-02-13（iOS 调试输入流程收口：回车提交 + 空 Key 默认值）

### 已完成
- `source_edit_view.dart`
  - 调试 Key 输入框接入 `TextInputAction.search`，支持键盘回车直接触发调试。
  - 新增空 Key 回落逻辑：
    - 若输入为空，自动回落到 `ruleSearch.checkKeyWord`；
    - 若校验词为空，默认回落 `我的`。
  - 开始调试时自动收起键盘，避免日志区被输入法遮挡。

### 为什么
- legado 调试入口是 SearchView 提交语义，回车即可执行；
- 当前实现对空输入直接报错，不利于快速复测，和 legado 的默认关键词路径不一致。

### legado 对标（已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 书源编辑 -> 调试，在 Key 输入框输入关键词后按键盘回车，确认直接开始调试；
  - 清空 Key 后点击“开始调试”，确认自动使用校验词/`我的` 执行；
  - 调试启动后确认键盘自动收起。

### 兼容影响
- 仅调试输入交互优化，不改调试引擎语义、书源协议、数据库结构。

## 2026-02-13（iOS 调试主屏再对齐 legado：控制台收敛为纯日志列表）

### 已完成
- `source_edit_view.dart`
  - 调试主屏控制台移除“显示模式/全量开关/过滤关键字/换行开关/全文控制台”控件，改为纯日志列表视图。
  - 主屏仅保留：
    - 最近错误提示；
    - 最近日志列表（逐行）；
    - 单行复制与上下文查看。
  - 当日志过多时，主屏提示“仅展示最近 600 行”，完整日志通过“更多工具 -> 复制控制台（全部）”导出。
  - 清理不再需要的分段日志模型与相关状态字段，简化调试页状态复杂度。

### 为什么
- legado 调试页核心是“输入提交 + 日志列表”，不强调主屏上的多模式控制。
- 当前主屏此前配置项偏多，会稀释关键日志信息，影响复现场景效率。

### legado 对标（已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`
- `/home/server/legado/app/src/main/res/layout/activity_source_debug.xml`

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 书源编辑 -> 调试 -> 开始调试，确认主屏控制台直接按日志行展示；
  - 长日志场景下确认出现“最近 600 行”提示；
  - 点击单条日志可查看上下文，点击复制图标可复制该行。

### 兼容影响
- 仅调试主屏 UI 简化，不改调试引擎、导出协议、书源协议与数据库结构。

## 2026-02-13（iOS 调试帮助区显隐复刻：focus 打开 / 提交隐藏）

### 已完成
- `source_edit_view.dart`
  - 调试快捷帮助区显隐语义向 legado 对齐：
    - 默认显示；
    - 提交调试后自动隐藏；
    - 重新聚焦 Key 输入框后自动展开。
  - 工具区补充“显示快捷提示”入口，便于在隐藏状态下手动恢复快捷区。
  - “我的”快捷按钮文案改为动态显示默认搜索词（优先 `ruleSearch.checkKeyWord`，否则 `我的`），行为与点击值保持一致。

### 为什么
- legado 调试页中帮助区随搜索框 focus/submit 切换；
- 当前实现快捷区长期常驻，信息密度偏高，不利于日志主屏阅读。

### legado 对标（已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`

### 如何验证
- 执行：`flutter analyze`
- 结果：`No issues found!`
- 手工路径建议：
  - 书源编辑 -> 调试：初始可见快捷帮助区；
  - 点击开始调试后，快捷帮助区自动隐藏；
  - 点击 Key 输入框后，快捷帮助区重新显示；
  - 若书源配置了 `checkKeyWord`，确认“我的”按钮文案显示该值。

### 兼容影响
- 仅调试页 UI 交互收口，不改调试引擎、书源协议、数据库结构。
