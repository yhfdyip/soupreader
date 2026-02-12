# SoupReader 开发进度日志

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
