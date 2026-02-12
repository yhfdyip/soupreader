# SoupReader 开发进度日志

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
