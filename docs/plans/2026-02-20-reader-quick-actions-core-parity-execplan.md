# Legado -> SoupReader 阅读器快捷动作区四按钮同义迁移（搜索/自动翻页/替换规则/夜间模式）

- 状态：`done`
- 负责人：`Reader-UI`
- 更新时间：`2026-02-20`
- 范围类型：迁移级别（核心功能）

## 背景与目标

### 背景

- `docs/plans/2026-02-20-reader-ui-core-parity-audit-execplan.md` 识别出高优先级偏差 `O-01`：快捷动作区按钮集合与排序与 legado 不同。
- legado 基线在 `view_read_menu.xml` 与 `ReadMenu.kt` 中明确使用四个快捷按钮：`搜索 / 自动翻页 / 替换规则 / 夜间模式`。
- SoupReader 当前 `simple_reader_view.dart` 右侧悬浮快捷栏为六按钮（包含书签、目录、朗读、界面、设置），与 legado 快捷动作语义不一致。

### 目标

- 将阅读页快捷动作区收敛为 legado 同义四按钮集合及顺序：
  - 搜索正文
  - 自动翻页（运行态可见）
  - 替换规则
  - 日夜主题切换
- 保持按钮触发后的状态流转可观测，不引入扩展能力开发。

### 非目标

- 不处理书源操作菜单（`O-02`）。
- 不处理顶栏书籍信息/章节链接入口（`O-03`）。
- 不解锁扩展能力（朗读引擎、HTTP TTS、漫画能力）。

### 成功标准

- 快捷动作区按钮集合与排序与 legado 同义（四按钮）。
- 四按钮触发行为可复现并有定向测试证据。
- ExecPlan 完整回填“做了什么、为什么、如何验证、兼容影响”。

## 差异点清单（含文件位置/原因/影响）

| ID | 差异 | legado 基准 | soupreader 现状 | 原因 | 影响 |
| --- | --- | --- | --- | --- | --- |
| QA-01 | 快捷动作区按钮集合超集 | `view_read_menu.xml` + `ReadMenu.kt`：`搜索/自动翻页/替换规则/夜间模式` | `simple_reader_view.dart:_buildFloatingActionRail`：`搜索/书签/目录/朗读/界面/设置` | 历史将“高频入口”并入悬浮栏 | 按钮语义与触发集合偏离 legado |
| QA-02 | 自动翻页状态反馈未绑定快捷栏 | `ReadMenu.setAutoPage(autoPage)` 根据运行态切图标与文案 | 悬浮栏无自动翻页按钮 | 自动翻页入口迁移至其它菜单 | 快捷动作区缺少核心触发入口 |
| QA-03 | 替换规则入口缺失 | `ReadBookActivity.openReplaceRule()` 跳转规则页 | 悬浮栏无替换规则入口 | 入口迁移过程中遗漏 | 规则入口层级与 legado 不同 |
| QA-04 | 日夜切换入口语义缺失 | `fabNightTheme` 切换日夜主题 | 悬浮栏无日夜切换入口 | 主题切换入口分散到设置页 | 快捷动作区语义不完整 |

## 逐项检查清单（实施前固定项）

| 检查项 | 结果 |
| --- | --- |
| 入口 | 已覆盖：阅读页菜单展开后的右侧快捷栏 |
| 状态 | 已覆盖：自动翻页运行态与日夜主题切换态 |
| 异常 | 已覆盖：替换规则页返回后内容刷新链路 |
| 文案 | 已覆盖：按钮语义文案与可访问标签 |
| 排版 | 已覆盖：四按钮纵向排列与点击热区 |
| 交互触发 | 已覆盖：点击触发、关闭菜单与回流行为 |
| 按钮 | 已覆盖：集合、顺序、运行态图标 |
| 跳转层级 | 已覆盖：替换规则页 push/pop 返回路径 |

## 实施步骤（含依赖/并行/验收）

### Step 1：基线对照固化（已完成）

- 依赖：无
- 并行性：串行
- 做了什么：
  - 完整读取 legado 基准文件：
    - `/home/server/legado/app/src/main/res/layout/view_read_menu.xml`
    - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
    - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
    - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookViewModel.kt`
  - 读取 soupreader 对应文件：
    - `lib/features/reader/views/simple_reader_view.dart`
    - `lib/features/replace/views/replace_rule_list_view.dart`
- 预期结果：
  - 快捷动作区行为基线可直接映射到 Flutter 实现。
- 验证方式：
  - 差异点清单 `QA-01~QA-04` 落盘。

### Step 2：快捷动作区四按钮迁移实现（已完成）

- 依赖：Step 1
- 并行性：串行
- 做什么：
  - 重构 `simple_reader_view.dart` 的快捷栏按钮集合为 legado 四按钮顺序。
  - 补齐自动翻页运行态图标与替换规则入口。
  - 引入可测试的动作顺序 helper，锁定迁移语义。
- 预期结果：
  - UI 与触发语义对齐 legado 快捷动作区。
- 验证方式：
  - 新增/更新定向测试（动作顺序与主题切换映射）。

#### Step 2 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `lib/features/reader/views/simple_reader_view.dart`
    - 将 `_buildFloatingActionRail` 收敛为 legado 四按钮顺序：`搜索 -> 自动翻页 -> 替换规则 -> 日夜切换`；
    - 新增快捷动作方法：`_toggleAutoPageFromQuickAction`、`_openReplaceRuleFromMenu`、`_toggleDayNightThemeFromQuickAction`；
    - 引入可访问语义标签（`Semantics`）用于按钮文案与测试回归；
    - 替换规则入口改为跳转 `ReplaceRuleListView`，返回后清理 `_replaceStageCache` 并重载当前章节。
  - `lib/features/reader/services/reader_legacy_quick_action_helper.dart`
    - 新增 legado 快捷动作顺序常量与日夜主题切换索引计算 helper。
  - 新增测试：
    - `test/reader_legacy_quick_action_helper_test.dart`
    - `test/simple_reader_view_compile_test.dart`
- 为什么：
  - 修复 `O-01` 中“快捷动作区按钮集合与排序漂移”的核心偏差，并对齐 legado 的入口语义。
- 如何验证：
  - `flutter test test/reader_legacy_quick_action_helper_test.dart test/simple_reader_view_compile_test.dart`
  - 结果：`All tests passed`
- 兼容影响：
  - 阅读页右侧快捷栏不再承载“书签/目录/朗读/界面/设置”入口，这些入口仍可从顶栏/底栏访问；
  - 书源解析链路与持久化结构未变化。

### Step 3：验证与文档回填（已完成）

- 依赖：Step 2
- 并行性：串行
- 做什么：
  - 执行定向测试。
  - 回填计划文档 `Progress/Decision Log/Outcomes`。
- 预期结果：
  - 形成可复现证据并完成本次可交付点。
- 验证方式：
  - `flutter test <定向测试文件>`

#### Step 3 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 执行本次改动对应定向测试并记录结果；
  - 回填本 ExecPlan 全部动态章节，状态更新为 `done`。
- 为什么：
  - 满足迁移级任务“可复现证据 + 文档闭环”要求。
- 如何验证：
  - `flutter test test/reader_legacy_quick_action_helper_test.dart test/simple_reader_view_compile_test.dart`
- 兼容影响：
  - 无新增数据库或配置 schema 变更。

## 风险与回滚

- 风险 1：替换规则页返回后未刷新当前章节，导致用户感知“规则未生效”。
  - 回滚/兜底：保留原逻辑，必要时先仅补入口并提示刷新章节。
- 风险 2：快速切换菜单态导致自动翻页面板显隐冲突。
  - 回滚/兜底：复用现有 `_showAutoReadPanel` 状态机，不新增第二状态源。

## 验收与证据

### 命令验证

- 本轮仅执行与改动相关的定向测试；
- 不执行 `flutter analyze`（遵循仓库规则：仅提交推送前执行一次）。

### 手工回归路径

1. 阅读页打开菜单 -> 观察右侧快捷栏顺序为：搜索、自动翻页、替换规则、夜间模式。
2. 点击自动翻页 -> 进入/退出自动翻页运行态，图标与状态一致。
3. 点击替换规则 -> 进入规则页，返回后当前章节内容保持可读并刷新。
4. 点击日夜切换 -> 主题在明暗之间切换并即时生效。

## Progress

- [x] Step 1：基线对照固化
- [x] Step 2：快捷动作区四按钮迁移实现
- [x] Step 3：验证与文档回填

## Surprises & Discoveries

- 当前 `simple_reader_view.dart` 快捷栏是“同类阅读器聚合入口”思路，并非 legado 快捷动作语义。
- 现有替换规则能力在仓库内已具备独立页面（`ReplaceRuleListView`），缺失的是阅读页快捷入口。
- legado 的 `openReplaceRule` 在返回后会触发 `replaceRuleChanged()` 重载正文；Flutter 侧需要在返回后显式清理替换缓存并重载当前章节，才能保持用户感知同义。

## Decision Log

- 决策 1：本轮只处理 `O-01`，其余 `O-02/O-03/O-04` 不并行启动。
  - 原因：遵循“继续下一任务”口径，保持单可交付点闭环。
- 决策 2：快捷动作顺序以 legado 四按钮为唯一基准，不保留额外动作在同一区域。
  - 原因：迁移级别要求按钮集合与排序同义。
- 决策 3：日夜切换不直接绑定固定主题索引，而是按“当前明暗 -> 相反明暗”计算目标主题。
  - 原因：兼容多主题列表，保持 legado“日夜切换”语义而不破坏用户已有主题集。
- 决策 4：新增独立 helper（而非在 UI 内硬编码顺序）锁定 legacy 动作顺序。
  - 原因：降低后续改动将动作顺序再次漂移的风险，并提供可单元测试证据。

## Outcomes & Retrospective

- 本轮已完成 `O-01`：阅读页快捷动作区从六按钮收敛为 legado 同义四按钮，并补齐自动翻页状态反馈、替换规则入口、日夜切换入口。
- 本轮未触发扩展能力开发，符合“核心优先、扩展冻结”约束。
- 后续建议（下一任务）：按审计计划继续处理 `O-02`（书源操作菜单缺失）或 `O-03`（顶栏书籍信息/章节链接入口缺失）。
