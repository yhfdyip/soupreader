# Legado -> SoupReader 阅读页顶栏入口同义迁移（书籍信息/章节链接）

- 状态：`done`
- 负责人：`Reader-UI`
- 更新时间：`2026-02-20`
- 范围类型：迁移级别（核心功能）

## 背景与目标

### 背景

- `docs/plans/2026-02-20-reader-ui-core-parity-audit-execplan.md` 标记偏差 `O-03`：顶栏缺失“书籍信息入口”和“章节链接入口”。
- legado 基线：
  - `ReadMenu.kt`：`titleBar.toolbar` 点击触发 `openBookInfoActivity()`；
  - `ReadMenu.kt`：`tvChapterName/tvChapterUrl` 点击打开章节链接，长按切换“浏览器打开”策略；
  - `view_read_menu.xml`：`tv_chapter_name` 与 `tv_chapter_url` 双行点击热区。
- soupreader 当前顶栏为只读文案（书名 + 章节文案），无同义点击入口。

### 目标

- 在阅读页顶栏补齐与 legado 同义的两类入口：
  - 书名区域点击进入书籍详情；
  - 章节标题/章节链接点击打开章节 URL（并保留可观测反馈）。
- 对齐本地书籍边界：本地书籍不显示/不触发章节链接打开。
- 保持核心优先，不触发扩展功能开发。

### 非目标

- 不处理 `O-04`（`pref_config_read.xml` 批量配置补齐）。
- 不处理扩展冻结项（朗读引擎/HTTP TTS/漫画）。
- 不改动书源登录/购买完整 AnalyzeRule 运行时阻塞项（`EX-SA-02`）。

### 成功标准

- 顶栏书名可点击进入书籍详情（与 legado `openBookInfoActivity` 同义）。
- 顶栏章节区可点击打开章节链接；无效链接/本地书籍有可观测提示。
- 迁移差异、逐项对照、验证证据与兼容影响完整回填。

## 差异点清单（含文件位置/原因/影响）

| ID | 差异 | legado 基准 | soupreader 现状 | 原因 | 影响 |
| --- | --- | --- | --- | --- | --- |
| TB-01 | 书籍信息入口缺失 | `ReadMenu.kt`：`titleBar.toolbar` 点击 `openBookInfoActivity()` | `reader_menus.dart` 顶栏书名为纯文本 | 顶栏迁移时仅保留展示层 | 无法从阅读态直达书籍详情 |
| TB-02 | 章节链接入口缺失 | `ReadMenu.kt`：`tvChapterName/tvChapterUrl` 点击打开章节链接 | 顶栏只显示 `chapterLine`，无点击热区 | 双行结构未迁移 | 无法从阅读态打开当前章节链接 |
| TB-03 | 章节链接边界提示不足 | `ReadMenu.kt` 对本地书籍直接返回、异常可观测 | 当前无章节链接动作链路 | 入口缺失导致边界未实现 | 本地/空链接场景无反馈 |

## 逐项检查清单（实施前固定项）

| 检查项 | 结果 |
| --- | --- |
| 入口 | 已完成：顶栏书名、章节标题、章节链接热区均可触发 |
| 状态 | 已完成：在线书籍/本地书籍/空章节 URL 均有分支处理 |
| 异常 | 已完成：无书架记录、URL 非法、浏览器启动失败均有提示 |
| 文案 | 已完成：书源/章节/打开方式文案与 legado 业务语义同向 |
| 排版 | 已完成：顶栏信息层级收敛为“书名 + 章节标题 + 章节链接” |
| 交互触发 | 已完成：章节标题/链接支持点击打开、长按切换打开方式 |
| 按钮 | 已完成：书名与章节信息区域均具备明确点击语义 |
| 跳转层级 | 已完成：阅读页 -> 书籍详情 / 阅读页 -> 章节网页 |

## 实施步骤（含依赖/并行/验收）

### Step 1：基线复读与计划落盘（已完成）

- 依赖：无
- 并行性：串行
- 做了什么：
  - 完整读取 legado 文件：
    - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
    - `/home/server/legado/app/src/main/res/layout/view_read_menu.xml`
    - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
  - 读取 soupreader 文件：
    - `lib/features/reader/widgets/reader_menus.dart`
    - `lib/features/reader/views/simple_reader_view.dart`
- 预期结果：
  - `TB-01~TB-03` 差异明确，进入实现。
- 验证方式：
  - 差异点与检查清单落盘。

### Step 2：顶栏热区与回调迁移（已完成）

- 依赖：Step 1
- 并行性：串行
- 做什么：
  - 在 `ReaderTopMenu` 补齐书名点击回调。
  - 将章节区拆分为“章节标题 + 章节 URL”并补齐点击/长按回调。
  - 在 `SimpleReaderView` 接入对应动作：打开书籍详情、打开章节链接、边界提示。
- 预期结果：
  - 顶栏入口行为与 legado 同义。
- 验证方式：
  - 定向测试 + 手工回归路径。

#### Step 2 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `lib/features/reader/widgets/reader_menus.dart`
    - `ReaderTopMenu` 新增书名点击回调、章节点击回调、章节长按回调；
    - 顶栏章节区从单行 `chapterLine` 拆分为“章节标题 + 章节链接”双行展示；
    - 书源入口文案改为显示当前书源名（空态回退 `书源`），并保留 `showSourceAction`/`showChapterLink` 可见控制。
  - `lib/features/reader/views/simple_reader_view.dart`
    - 接入 `onOpenBookInfo`、`onOpenChapterLink`、`onToggleChapterLinkOpenMode` 顶栏回调；
    - 新增 `_openBookInfoFromTopMenu`（阅读页直达 `SearchBookInfoView.fromBookshelf`）；
    - 新增 `_openChapterLinkFromTopMenu`（按设置在应用内网页或外部浏览器打开章节 URL）；
    - 新增 `_toggleChapterLinkOpenModeFromTopMenu`（长按章节区切换打开方式）；
    - 顶栏章节 URL 显示改为通过 helper 按 legado 语义规整（含 `',{` 截断与相对链接解析）。
  - `lib/core/services/settings_service.dart`
    - 新增 `readerChapterUrlOpenInBrowser` 持久化开关及保存方法。
  - `lib/features/reader/services/reader_top_bar_action_helper.dart`
    - 新增章节 URL 规整/解析 helper（绝对 URL、相对 URL、非法 scheme 过滤）。
- 为什么：
  - 修复 `TB-01~TB-03`：恢复顶栏书籍信息入口、章节链接入口、边界提示与可观测反馈。
- 如何验证：
  - `flutter test test/reader_top_bar_action_helper_test.dart test/simple_reader_view_compile_test.dart test/reader_source_action_helper_test.dart`
- 兼容影响：
  - 临时阅读会话（无书架记录）点击书名时无法进入书籍详情，当前以可观测提示兜底；在线/本地阅读主链路不受影响。

### Step 3：验证与文档回填（已完成）

- 依赖：Step 2
- 并行性：可与测试补充并行
- 做什么：
  - 补充/更新定向测试。
  - 回填 ExecPlan 动态章节与 `PLANS.md` 索引状态。
- 预期结果：
  - 形成可复现证据并闭环文档。
- 验证方式：
  - `flutter test` 定向文件。

#### Step 3 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 新增单元测试 `test/reader_top_bar_action_helper_test.dart`；
  - 执行本任务定向测试并回填 ExecPlan 动态章节；
  - 同步 `PLANS.md` 索引状态。
- 为什么：
  - 满足迁移级任务“证据可复现 + 文档闭环”要求。
- 如何验证：
  - `flutter test test/reader_top_bar_action_helper_test.dart test/simple_reader_view_compile_test.dart test/reader_source_action_helper_test.dart`
- 兼容影响：
  - 无数据库 schema 变更；仅新增 SharedPreferences 键 `reader_chapter_url_open_in_browser`。

## 逐项对照清单（实施后）

| ID | 结果 | 说明 |
| --- | --- | --- |
| TB-01 | 已同义 | 顶栏书名点击进入书籍详情页（阅读态可直达） |
| TB-02 | 已同义 | 顶栏章节区提供章节标题/章节链接双行热区，点击打开章节 URL |
| TB-03 | 已同义 | 本地书籍、空 URL、非法 URL、浏览器失败均有可观测提示 |
| R-01（新增） | 保留差异 | 临时会话无书架记录时，书籍详情入口提示不可用（legado 常规场景无此状态） |

## 风险与回滚

- 风险 1：当前会话为临时阅读（无书架记录）时，书籍详情入口数据不足。
  - 回滚/兜底：提供可观测提示并保留阅读主链路。
- 风险 2：章节 URL 为相对路径或非 http(s) 时无法直接打开。
  - 回滚/兜底：解析失败给出提示，不影响正文阅读。
- 风险 3：顶栏增加可点击热区后，误触概率上升。
  - 回滚/兜底：仅对书名与章节文本区域开放点击，不影响右侧动作按钮。

## 验收与证据

### 命令验证

- 本轮仅执行与改动相关的定向测试。
- 不执行 `flutter analyze`（遵守仓库规则：仅提交推送前执行一次）。
- 已执行：
  - `flutter test test/reader_top_bar_action_helper_test.dart test/simple_reader_view_compile_test.dart test/reader_source_action_helper_test.dart`
- 结果：
  - `All tests passed`

### 手工回归路径

1. 阅读页打开菜单 -> 点击书名 -> 进入书籍详情页并可返回。
2. 阅读页打开菜单 -> 点击章节标题或章节链接 -> 打开章节网页。
3. 长按章节标题或章节链接 -> 切换章节链接打开方式。
4. 本地书籍场景点击章节区 -> 显示“不支持章节链接”提示。

## Progress

- [x] Step 1：基线复读与计划落盘
- [x] Step 2：顶栏热区与回调迁移
- [x] Step 3：验证与文档回填

## Surprises & Discoveries

- 章节 URL 在部分站点会附带 `',{...}` 后缀，需按 legado 语义先截断再打开，否则会命中无效链接。
- 当前阅读临时会话不落书架实体，无法完全复用“书籍详情页”数据入口，需以提示兜底。
- 顶栏原先把 `source + chapter` 合并为单行文案，拆分为双行后更接近 legado 热区结构且可读性更高。

## Decision Log

- 决策 1：章节链接长按保留“打开方式切换”语义，并持久化到 `SettingsService`。
  - 原因：与 legado `readUrlInBrowser` 长按切换语义对齐。
- 决策 2：应用内打开章节链接复用现有 `SourceWebVerifyView`，不新增 WebView 页面。
  - 原因：仓库已有稳定 WebView 容器，复用可降低风险。
- 决策 3：临时会话书籍详情入口采用可观测提示，不临时拼装不完整详情页。
  - 原因：避免伪造详情数据导致行为偏差与调试误导。

## Outcomes & Retrospective

- 本轮完成 `O-03` 顶栏入口迁移：书名详情入口、章节链接入口、长按打开方式切换均已落地。
- 已补齐 URL 规整与相对链接解析 helper，并通过定向测试锁定行为。
- 残留差异仅在“临时会话无书架记录”场景，已记录为保留差异并给出提示兜底。
