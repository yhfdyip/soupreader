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
