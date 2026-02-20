# Legado -> SoupReader 阅读器书源操作菜单同义迁移（登录/章节购买/编辑书源/禁用书源）

- 状态：`blocked`
- 负责人：`Reader-UI`
- 更新时间：`2026-02-20`
- 范围类型：迁移级别（核心功能）

## 背景与目标

### 背景

- `docs/plans/2026-02-20-reader-ui-core-parity-audit-execplan.md` 标记高优先级偏差 `O-02`：阅读页缺失 legado 的书源操作菜单语义。
- legado 基线在 `ReadMenu.kt` + `book_read_source.xml` 中明确提供四个操作：`登录 / 章节购买 / 编辑书源 / 禁用书源`。
- soupreader 当前阅读页顶部仅提供“换源”入口，缺失书源动作菜单层级。

### 目标

- 在阅读页顶部恢复 legado 同义的书源操作入口（显示当前书源名并弹出菜单）。
- 补齐四个菜单动作及其触发链路：
  - 登录
  - 章节购买
  - 编辑书源
  - 禁用书源
- 保持“核心优先、扩展冻结”约束，不启动扩展能力开发。

### 非目标

- 不处理 `O-03`（顶栏书籍信息/章节链接入口）。
- 不处理 `O-04`（`pref_config_read.xml` 批量配置补齐）。
- 不启动扩展能力（朗读引擎、HTTP TTS、漫画能力）。

### 成功标准

- 阅读页顶部出现书源动作入口，菜单结构与顺序与 legado 同义。
- 四个动作具备可复现触发路径，至少提供定向测试证据。
- ExecPlan 动态章节完整回填（做了什么、为什么、如何验证、兼容影响）。

## 差异点清单（含文件位置/原因/影响）

| ID | 差异 | legado 基准 | soupreader 现状 | 原因 | 影响 |
| --- | --- | --- | --- | --- | --- |
| SA-01 | 入口语义偏移 | `ReadMenu.tvSourceAction` 点击弹出四动作菜单 | `ReaderTopMenu` 仅“换源”芯片 | 历史将入口简化为换源流程 | 缺失登录/购买/编辑/禁用入口 |
| SA-02 | 菜单结构缺失 | `book_read_source.xml`：登录/章节购买/编辑/禁用 | 无对应菜单结构 | 迁移时未复刻 `sourceMenu` | 用户无法执行源内关键操作 |
| SA-03 | 动作可见条件缺失 | `menu_login/menu_chapter_pay` 按登录地址与章节状态控制可见 | 无可见条件逻辑 | 无书源菜单实现 | 交互边界与 legado 偏离 |
| SA-04 | 禁用书源动作缺失 | `ReadBookViewModel.disableSource()` 直接禁用当前源 | 阅读页无禁用动作 | 入口缺失 | 无法在阅读态快速屏蔽异常书源 |

## 逐项检查清单（实施前固定项）

| 检查项 | 结果 |
| --- | --- |
| 入口 | 已完成：阅读页顶栏入口改为书源动作入口，本地书籍隐藏 |
| 状态 | 部分完成：登录条件已对齐；章节购买在 `EX-SA-01` 下使用回退可见条件 |
| 异常 | 已完成：无书源/本地书籍/执行失败均有可观测提示 |
| 文案 | 已完成：菜单项文案按 legado 语义（登录/章节购买/编辑书源/禁用书源） |
| 排版 | 已完成：顶栏入口与动作菜单层级落地 |
| 交互触发 | 已完成：四动作点击均有触发链路与反馈 |
| 按钮 | 已完成：四动作集合与顺序固定 |
| 跳转层级 | 部分完成：登录/编辑已同义；章节购买受 `EX-SA-02` 阻塞 |

## 实施步骤（含依赖/并行/验收）

### Step 1：基线固化与计划落盘（已完成）

- 依赖：无
- 并行性：串行
- 做了什么：
  - 完整读取 legado 对照文件：
    - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
    - `/home/server/legado/app/src/main/res/layout/view_read_menu.xml`
    - `/home/server/legado/app/src/main/res/menu/book_read_source.xml`
    - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
    - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookViewModel.kt`
  - 读取 soupreader 对应实现：
    - `lib/features/reader/views/simple_reader_view.dart`
    - `lib/features/reader/widgets/reader_menus.dart`
    - `lib/features/discovery/views/discovery_view.dart`（复用登录/编辑书源交互基线）
- 预期结果：
  - 书源菜单迁移基线明确，可直接进入实现。
- 验证方式：
  - 本计划 `SA-01~SA-04` 差异点落盘。

### Step 2：阅读页顶栏书源入口与菜单结构迁移（已完成）

- 依赖：Step 1
- 并行性：串行
- 做什么：
  - 顶栏将“换源芯片”收敛为“书源动作入口”（显示当前书源名）。
  - 新增书源动作菜单并固定顺序：`登录 -> 章节购买 -> 编辑书源 -> 禁用书源`。
  - 实现菜单项可见条件映射（至少覆盖 `loginUrl` 与本地书籍边界）。
- 预期结果：
  - 菜单入口与结构同义 legado。
- 验证方式：
  - Widget/Helper 定向测试 + 手工路径核验。

#### Step 2 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `lib/features/reader/widgets/reader_menus.dart`
    - 顶栏“换源”芯片改为“书源动作入口”芯片（显示当前书源名，空态回退为“书源”）。
    - 本地书籍场景隐藏该入口（对齐 legado `ReadBook.isLocalBook` 时隐藏 `tvSourceAction` 的语义）。
  - `lib/features/reader/views/simple_reader_view.dart`
    - 接入 `onShowSourceActions` 顶栏回调。
    - 顶栏入口点击后弹出书源动作菜单，固定顺序：`登录 -> 章节购买 -> 编辑书源 -> 禁用书源`。
- 为什么：
  - 修复 `SA-01/SA-02`（入口语义偏移、菜单结构缺失）。
- 如何验证：
  - `flutter test test/reader_source_action_helper_test.dart test/simple_reader_view_compile_test.dart`
- 兼容影响：
  - 顶栏不再用“换源”文案承载该入口；“换源”仍保留在“阅读操作”更多菜单，主链路未中断。

### Step 3：四动作触发链路接入（阻塞中）

- 依赖：Step 2
- 并行性：可与 Step 4 部分并行（测试先行）
- 做什么：
  - 登录：复用 `SourceLoginFormView` / `SourceWebVerifyView`。
  - 章节购买：接入确认流程与结果反馈；无法等价项按 `1.1.2` 记录。
  - 编辑书源：跳转 `SourceEditLegacyView.fromSource`。
  - 禁用书源：调用 `SourceRepository.updateSource(enabled=false)`。
- 预期结果：
  - 四动作均可触发并可观测反馈。
- 验证方式：
  - 动作级定向测试 + 手工回归路径。

#### Step 3 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `lib/features/reader/views/simple_reader_view.dart`
    - 登录动作：复用 `SourceLoginFormView` / `SourceWebVerifyView`（同 `discovery_view.dart` 逻辑）。
    - 编辑书源动作：接入 `SourceEditLegacyView.fromSource`。
    - 禁用书源动作：接入确认弹窗后调用 `SourceRepository.updateSource(enabled=false)`。
    - 章节购买动作：接入确认弹窗 + `payAction` 执行结果分支（URL 打开网页、`true` 刷新当前章节、其它结果可观测提示）。
    - 增加章节 `isVip/isPay` 的运行态映射缓存（仅在阅读器内可获取 `TocItem` 时缓存）。
  - `lib/features/reader/services/reader_source_action_helper.dart`
    - 新增书源动作 helper，固化动作顺序、章节购买可见条件与 `payAction` 输出解析。
- 为什么：
  - 修复 `SA-03/SA-04`（可见条件缺失、禁用书源动作缺失），并完成四动作主触发链路。
- 如何验证：
  - `flutter test test/reader_source_action_helper_test.dart test/simple_reader_view_compile_test.dart`
- 兼容影响：
  - 章节购买可见条件在“缺少章节持久化 `isVip/isPay`”时采用回退策略（`loginUrl + payAction` 可见），与 legado 精确条件存在偏差（见 `EX-SA-01`）。
  - `payAction` 运行时当前为轻量 JS `eval` 上下文，不是 legado `AnalyzeRule` 完整上下文（见 `EX-SA-02`）。

### Step 4：验证与文档回填（已完成）

- 依赖：Step 3
- 并行性：串行
- 做什么：
  - 执行与改动相关的定向测试。
  - 回填 Progress / Decision Log / Surprises / Outcomes。
- 预期结果：
  - 形成可复现证据，完成本次可交付点。
- 验证方式：
  - `flutter test <定向测试文件>`

#### Step 4 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 执行定向测试并回填本 ExecPlan 动态章节。
  - 将暂无法等价项按第 `1.1.2` 章记录为阻塞例外。
- 为什么：
  - 满足迁移级任务“证据 + 例外记录 + 决策留痕”要求。
- 如何验证：
  - `flutter test test/reader_source_action_helper_test.dart test/simple_reader_view_compile_test.dart`
- 兼容影响：
  - 无数据库 schema 变更；例外项仅影响章节购买精确语义。

## 风险与回滚

- 风险 1：章节购买动作依赖 payAction 运行时上下文，Flutter 侧能力若不完备可能导致行为偏差。
  - 回滚/兜底：保留入口并提供可观测提示，同时按 `1.1.2` 标记 `blocked` 并记录回补计划。
- 风险 2：禁用当前书源后仍停留阅读页，后续拉取可能失败。
  - 回滚/兜底：禁用后保留明确提示并建议换源，必要时回退禁用动作。
- 风险 3：顶栏入口替换影响“换源”快捷路径。
  - 回滚/兜底：保留“换源”在阅读操作菜单中的入口，避免主链路中断。

## 验收与证据

### 命令验证

- 本轮仅执行与改动相关的定向测试。
- 不执行 `flutter analyze`（遵守仓库规则：仅提交推送前执行一次）。

### 手工回归路径

1. 阅读页打开菜单 -> 顶栏点击书源名入口 -> 弹出四动作菜单。
2. 登录动作：进入登录页面并可返回阅读页。
3. 章节购买动作：展示确认流程，执行后给出成功/失败可观测反馈。
4. 编辑书源动作：进入书源编辑页并可返回阅读页。
5. 禁用书源动作：当前书源被禁用并有用户可见提示。

## Progress

- [x] Step 1：基线固化与计划落盘
- [x] Step 2：阅读页顶栏书源入口与菜单结构迁移
- [ ] Step 3：四动作触发链路接入（`blocked`：`EX-SA-01/EX-SA-02` 待确认）
- [x] Step 4：验证与文档回填

## Surprises & Discoveries

- 当前 `Chapter` 持久化结构未保存 `isVip/isPay` 标记，可能影响“章节购买”菜单项的精确可见条件映射。
- `EX-SA-01`（阻塞例外）：
  - 原因：章节持久化结构无 `isVip/isPay`，阅读态并非总能拿到当前章节付费状态。
  - 影响范围：`章节购买` 菜单项可见条件无法 1:1 复刻 legado `isVip && !isPay`。
  - 替代方案：短期采用回退策略（`loginUrl + payAction` 可见）；若有运行态 `TocItem` 则优先使用其 `isVip/isPay`。
  - 回补计划：补齐章节模型与存储层字段迁移，目录拉取时持久化 `isVip/isPay`，再恢复 legado 精确条件判断。
- `EX-SA-02`（阻塞例外）：
  - 原因：legado `payAction` 依赖 `AnalyzeRule` 运行时上下文；Flutter 侧当前仅实现轻量 JS `eval` 上下文。
  - 影响范围：复杂 `payAction` 脚本（依赖 legado 专有上下文/函数）可能无法等价执行。
  - 替代方案：保留入口并对 URL/布尔返回值提供可观测流程，其余返回结果明确提示“不支持”。
  - 回补计划：在 `RuleParserEngine` 侧补齐与 legado `AnalyzeRule.evalJS` 同等的执行上下文后再闭环。

## Decision Log

- 决策 1：按审计顺序优先处理 `O-02`，不并行启动 `O-03/O-04`。
  - 原因：保持单可交付点闭环并降低回归面。
- 决策 2：登录/编辑书源优先复用已有页面能力，不新建流程。
  - 原因：仓库已有同类流程，复用可降低实现风险并保持行为一致。
- 决策 3：在 `EX-SA-01` 未回补前，`章节购买` 可见条件采用“优先章节标记，缺失时回退”的策略。
  - 原因：在无法完整持久化章节付费标记前，优先保证动作可达与可观测。
- 决策 4：对 `payAction` 先落地“URL/布尔”可执行子集，并将完整语义迁移升级为阻塞项。
  - 原因：满足核心动作链路可触发，同时遵守例外阻塞记录机制。

## Outcomes & Retrospective

- 本轮已完成：
  - 顶栏书源入口与四动作菜单结构迁移；
  - 登录/编辑书源/禁用书源动作闭环；
  - 章节购买基础流程（确认、执行结果分支、可观测提示）。
- 本轮未完成（阻塞）：
  - `EX-SA-01`：章节 `isVip/isPay` 持久化缺失导致可见条件无法精确等价。
  - `EX-SA-02`：`payAction` 缺少 legado `AnalyzeRule` 完整运行时上下文。
