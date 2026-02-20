# Legado -> SoupReader 核心链路与阅读器配置迁移（按钮/排版/跳转层级/交互一致）

- 状态：`blocked`
- 负责人：`Core-Migration`（主）、`Reader-UI`（并行分支）、`Reader-Persistence`（并行分支）
- 更新时间：`2026-02-20`
- 范围类型：迁移级别（非“最小收敛”）

## 背景与目标

### 背景
- 当前仓库处于 Legado 向 Flutter 的迁移阶段。
- 需求明确要求：阅读器功能配置在 **按钮语义**、**排版结构**、**点击跳转层级** 与 **交互语义** 上与 Legado 同义（仅 UI 风格差异除外）。
- 现状存在计划索引失真（`PLANS.md` 指向文件已删除），需先恢复可执行计划基线。

### 目标
- 完成核心五段链路（`search` / `explore` / `bookInfo` / `toc` / `content`）的可调试可回归迁移方案。
- 完成文本阅读器配置迁移方案，保证：
  - 功能配置项同义；
  - 按钮集合、顺序、可见/可点击条件与点击反馈语义同义；
  - 排版结构与信息层级同义；
  - 点击后跳转层级、返回路径与入口层级同义；
  - 交互触发、状态流转、反馈语义同义。
- 在未收到“开始做扩展功能”指令前，扩展能力保持 `blocked`。

### 非目标
- 本计划不启动漫画阅读配置迁移。
- 本计划不启动朗读引擎/HTTP TTS 配置迁移。
- 本计划不处理与核心链路无关的扩展入口。

### 成功标准
- 已输出并执行“差异点清单 + 逐项对照清单”。
- 按钮一致性、排版一致性、点击跳转层级一致性与交互一致性检查全部回填，且无未处理阻塞项。
- 五段链路具备可复现回归路径和调试证据。
- 计划文档动态章节持续更新，且状态流转清晰（`draft -> active -> blocked/done`）。

## 差异点清单（含文件位置/原因/影响）

| ID | 差异 | legado 基准 | soupreader 现状 | 原因 | 影响 |
| --- | --- | --- | --- | --- | --- |
| D-01 | 计划索引指向缺失 | `/home/server/soupreader/PLANS.md` | 指向已删除文件 | 历史清理后未修复索引 | 无法按计划执行与追踪 |
| D-02 | 阅读配置载体语义 | `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt` | `lib/features/reader/models/reading_settings.dart` + `lib/core/services/settings_service.dart` | 单配置模型与多套样式语义存在差异 | 配置迁移一致性风险 |
| D-03 | 阅读配置入口结构 | `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`、`TipConfigDialog.kt`、`MoreConfigDialog.kt`、`/home/server/legado/app/src/main/res/xml/pref_config_read.xml` | `lib/features/settings/views/reading_*.dart` + `lib/features/reader/views/simple_reader_view.dart` | 页面拆分策略不同 | 菜单层级、排序、触发语义偏差 |
| D-04 | 排版一致性验收机制 | Legado 阅读配置页（分组、间距、控件顺序） | 仅有功能项迁移，缺少排版核验台账 | 验收维度不足 | 可能“功能可用但布局走样” |
| D-05 | 交互一致性验收机制 | Legado 控件触发与反馈语义 | 缺少逐项交互闭环核验记录 | 验收维度不足 | 可能“入口一致但行为偏差” |
| D-06 | 按钮与跳转层级验收机制 | Legado 按钮集合、触发条件与页面跳转层级 | 现有台账偏重配置项语义，按钮级与路由级核验粒度不足 | 验收口径未细化 | 可能“按钮存在但顺序/跳转层级偏移” |

## 逐项检查清单（实施前固定项）

- 入口：入口层级、菜单路径、页面路由是否同义。
- 状态：默认值、切换值、重进恢复、重启恢复是否同义。
- 异常：非法值、缺字段、反序列化失败、网络异常下表现是否同义。
- 文案：标题、分组名、按钮文案、提示文案业务语义是否同义。
- 按钮：按钮集合、排序、可见/可点击条件、点击反馈是否同义。
- 排版：结构层级、间距节奏、控件排列、热区大小是否同义。
- 点击跳转层级：点击后的目标页面层级、返回路径、二级/三级入口关系是否同义。
- 交互触发：点击/滑杆/开关/弹窗确认取消行为是否同义。

## 实施步骤（含依赖/并行/验收）

### Step 1：迁移基线固化（已完成）
- Owner：`Core-Migration`
- 依赖：无
- 并行性：串行（前置步骤）
- 做什么：
  - 固化差异点清单（本节 D-01 ~ D-06）。
  - 修复计划索引，建立可执行入口。
- 预期结果：
  - 计划入口可用，执行不依赖聊天上下文。
- 验证方式：
  - `PLANS.md` 索引文件可打开且路径有效。

### Step 2：核心链路对照矩阵（已完成）
- Owner：`Core-Migration`
- 依赖：Step 1
- 并行性：串行（核心前置）
- 做什么：
  - 对照 Legado 对应能力，建立 `search/explore/bookInfo/toc/content` 矩阵。
  - 明确每段链路的正常态、异常态、可观测输出。
- 预期结果：
  - 五段链路均有“可调试定义”和“回归路径”。
- 验证方式：
  - 输出矩阵文档并附手工回归路径。

### Step 2 产出：核心五段链路对照矩阵（2026-02-19）

#### 2.1 对照基准文件（已完整读取）

- legado：
  - `/home/server/legado/app/src/main/java/io/legado/app/model/Debug.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/model/webBook/WebBook.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/model/webBook/BookList.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/model/webBook/BookInfo.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/model/webBook/BookChapterList.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/model/webBook/BookContent.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/model/webBook/SearchModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/explore/ExploreShowViewModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugModel.kt`
- soupreader：
  - `lib/features/source/services/rule_parser_engine.dart`
  - `lib/features/source/services/source_debug_key_parser.dart`
  - `lib/features/source/services/source_debug_orchestrator.dart`
  - `lib/features/source/services/source_availability_check_task_service.dart`
  - `lib/features/source/services/source_availability_diagnosis_service.dart`
  - `lib/features/source/views/source_debug_legacy_view.dart`
  - `lib/features/search/views/search_view.dart`
  - `lib/features/discovery/views/discovery_view.dart`
  - `lib/features/discovery/views/discovery_explore_results_view.dart`
  - `lib/features/search/views/search_book_info_view.dart`
  - `lib/features/bookshelf/services/book_add_service.dart`
  - `lib/features/reader/views/simple_reader_view.dart`

#### 2.2 五段链路矩阵（normal / error / observability）

| 链路 | legado 基准语义 | soupreader 现状 | 正常态定义 | 异常态定义 | 可观测输出 | 对照结论 |
| --- | --- | --- | --- | --- | --- | --- |
| `search` | `WebBook.searchBookAwait` -> `BookList.analyzeBookList`；`Debug.searchDebug` 驱动“搜索 -> 详情” | `RuleParserEngine.search/searchDebug`；`SearchView._runSearchPage` 逐源并发聚合 | 关键字构造 URL，解析列表，按书名/作者聚合并进入详情 | 规则缺失、HTTP 失败、列表有数据但字段缺失、超时 | `SearchDebugResult(fetch/status/listCount/error)`；`ExceptionLogService(node=source.search)`；搜索页 source issue 提示 | `已同义`（链路入口、异常可见性同义） |
| `explore` | `ExploreFragment` 入口 + `ExploreShowViewModel` 分页；`WebBook.exploreBookAwait`；`Debug.exploreDebug` | `DiscoveryView` -> `DiscoveryExploreResultsView`；`RuleParserEngine.explore/exploreDebug` | 发现入口解析后分页拉取列表，点书进入详情 | 发现入口空、解析失败、HTTP 失败、列表空 | `ExploreDebugResult`；`SourceAvailabilityDiagnosisService.diagnoseExplore`；页面错误态+重试 | `已同义`（入口层级、分页与失败反馈同义） |
| `bookInfo` | `WebBook.getBookInfoAwait` + `BookInfo.analyzeBookInfo`；目录链接缺省回退；调试状态 `20` | `RuleParserEngine.getBookInfo/getBookInfoDebug`；`SearchBookInfoView._loadContext` | 详情字段解析成功，`tocUrl` 回退到 `bookUrl`，进入目录链路 | 详情为空、规则失配、书源缺失；降级到书架缓存信息 | `BookInfoDebugResult`；`ExceptionLogService(node=source.bookInfo)`；详情页 `_error` 文案 | `基本同义`（保留差异 `B-01`） |
| `toc` | `WebBook.getChapterListAwait` + `BookChapterList.analyzeChapterList`；支持 `nextTocUrl` 多页与 `formatJs`；空目录抛异常 | `RuleParserEngine.getToc/getTocDebug`；详情页/加书架流程包含 fallback | 拉取并去重目录，重建章节索引，后续可进入正文 | 目录为空、章节字段缺失、请求失败 | `TocDebugResult`；`ExceptionLogService(node=source.toc)`；UI 侧“目录为空/解析失败”提示 | `部分同义`（保留差异 `T-01/T-02/T-03`） |
| `content` | `WebBook.getContentAwait` + `BookContent.analyzeContent`；支持 `nextContentUrl`；空正文抛 `ContentEmptyException`；调试状态 `40` | `RuleParserEngine.getContent/getContentDebug`；`SimpleReaderView._fetchChapterContentInternal` | 获取章节正文并缓存，阅读器支持相邻章节预取 | 正文为空、请求失败、规则失配、下一页链路异常 | `ContentDebugResult`；`ExceptionLogService(node=source.content)`；阅读页 toast/空内容表现 | `部分同义`（保留差异 `C-01/C-02/C-03`） |

#### 2.3 保留差异清单（Step 2 记录）

- `B-01`（详情重命名开关）：legado `BookInfo.analyzeBookInfo()` 存在 `canReName` 判定；soupreader 当前按解析结果直接回填详情字段。  
  影响：同名书跨源详情回填策略可能与 legado 的“条件重命名”边界不同。
- `T-01`（`preUpdateJs` 触发时机）：legado 由 `getChapterListAwait(runPerJs)` 控制；soupreader `getToc()` 默认执行。  
  影响：部分依赖前置脚本副作用的书源在非阅读入口的表现可能与 legado 时机不同。
- `T-02`（目录下一页调度策略）：legado 对多 `nextTocUrl` 支持并发；soupreader 当前为串行队列。  
  影响：超大目录站点在耗时与超时分布上可能偏离 legado。
- `T-03`（目录空结果语义）：legado 空目录抛 `TocEmptyException`；soupreader 返回空列表并由上层文案兜底。  
  影响：异常类型可观测语义不同，但用户可见反馈已覆盖。
- `C-01`（正文空结果语义）：legado 非卷章节空正文抛 `ContentEmptyException`；soupreader 返回空字符串。  
  影响：调用方若依赖异常类型做分类，行为存在偏差。
- `C-02`（卷章节正文短路）：legado 对 `isVolume && url.startsWith(title)` 走短路；soupreader 尚未同义短路。  
  影响：卷节点混入章节列表时，可能触发无效正文请求。
- `C-03`（正文下一页调度策略）：legado 对多 `nextContentUrl` 可并发；soupreader 当前为串行。  
  影响：长章节多分页书源的读取耗时可能高于 legado。

结论：上述差异已纳入迁移台账，当前未触发“无法继续实施”的硬阻塞；需在 Step 5 验收前完成“回补实现或迁移例外确认”。

#### 2.4 手工回归路径（Step 2 落地）

- 路径 A（搜索主链路）：
  - 入口：`SearchView`
  - 步骤：输入关键字 -> 查看结果 -> 进入 `SearchBookInfoView`
  - 预期：列表可见；失败源显示可读错误；可进入详情
- 路径 B（发现主链路）：
  - 入口：`DiscoveryView`
  - 步骤：展开书源 -> 选择发现入口 -> 进入 `DiscoveryExploreResultsView` -> 进入详情
  - 预期：发现分页可用；错误态可重试；详情可达
- 路径 C（详情 -> 目录）：
  - 入口：`SearchBookInfoView`
  - 步骤：加载详情 -> 打开目录/刷新目录
  - 预期：目录非空可进入阅读；空目录时给出规则失配提示
- 路径 D（正文）：
  - 入口：`SimpleReaderView`
  - 步骤：打开章节 -> 翻章 -> 观察预取与正文落库
  - 预期：正文可加载并缓存；异常时有用户可见提示
- 路径 E（五段调试）：
  - 入口：`SourceDebugLegacyView`（或对应调试入口）
  - 步骤：执行 `关键字` / `标题::url` / `++url` / `--url`
  - 预期：日志具备阶段标记；可查看 `10/20/30/40` 原始源码快照

#### 2.5 Step 2 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 完成 legado 与 soupreader 五段链路实现对照，形成矩阵与差异编号。
  - 固化每段链路的正常态、异常态、可观测输出与手工回归路径。
- 为什么：
  - Step 3A/3B 实施前必须先具备核心链路基线，避免后续 UI/配置迁移时误把链路偏差当成 UI 问题。
- 如何验证：
  - 文档核验：本节 `2.1`~`2.5` 完整落盘；
  - 代码核验：逐文件读取并对照（见 `2.1` 文件清单）；
  - 回归核验：按 `2.4` 路径执行。
- 兼容影响：
  - 本步骤仅新增对照文档，不修改运行时代码，对现有书源兼容性无直接行为变更。

### Step 3A：阅读器“界面（样式）”迁移（已完成，并行分支 A）
- Owner：`Reader-UI-A`
- 依赖：Step 2
- 并行性：可与 Step 3B 并行（避免同文件冲突）
- 做什么：
  - 对齐 `ReadStyleDialog` / `TipConfigDialog` 语义到 Flutter 入口。
  - 完成排版一致性检查回填。
- 涉及文件：
  - `lib/features/settings/views/reading_interface_settings_hub_view.dart`
  - `lib/features/settings/views/reading_preferences_view.dart`
  - `lib/features/settings/views/reading_tip_settings_view.dart`
  - `lib/features/reader/widgets/typography_settings_dialog.dart`
- 预期结果：
  - 入口与分组层级同义，排版节奏与控件语义同义。
- 验证方式：
  - 布局核验台账 + 手工路径回归。

#### Step 3A 子任务 S3A-01：标题排版入口补齐与文案收敛（已完成，含保留差异）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/res/layout/dialog_read_book_style.xml`
- `/home/server/legado/app/src/main/res/layout/dialog_tip_config.xml`
- `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadTipConfig.kt`

##### 差异点清单（S3A-01）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S3A-01-D1 | 标题排版入口缺项 | `TipConfigDialog` 提供 `titleSize/titleTop/titleBottom` 三个滑杆 | `ReadingTipSettingsView` 仅有“标题位置”，缺少三项调节 | 标题密度与间距无法按 legado 入口调整 |
| S3A-01-D2 | 入口文案漂移 | 动画时长固定，不存在“动画时长可调”入口语义 | 全局入口/界面 Hub 文案仍包含“翻页动画” | 文案与既有行为（固定 `300ms`）不一致 |
| S3A-01-D3 | 排版回归证据不足 | legado 通过页面行为验证标题排版项存在 | Flutter 侧缺少标题排版控件渲染回归测试 | 后续 UI 调整时可能静默丢失控件 |

##### 实施前逐项检查清单（S3A-01）

| 检查项 | 结果 |
| --- | --- |
| 入口（界面 Hub -> 页眉页脚与标题） | 通过：入口路径保持不变，文案改为同义描述 |
| 状态（默认值/调节后值） | 通过：`titleSize/titleTopSpacing/titleBottomSpacing` 均即时写入并持久化 |
| 异常（非法值/越界） | 通过：滑杆值由 `ReadingSettings.sanitize()` 与控件边界共同收敛 |
| 文案（业务语义） | 通过：移除“翻页动画可调”文案，避免语义漂移 |
| 排版（分组与顺序） | 通过：标题分组顺序扩展为“标题位置 -> 标题字号 -> 上边距 -> 下边距” |
| 交互触发（拖动即生效） | 通过：滑杆变化即时更新阅读设置 |

##### 逐项对照清单（S3A-01）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| 标题字号入口 | `dsb_title_size` 滑杆 | `ReadingTipSettingsView` 新增“标题字号偏移”滑杆 | 已同义（实现层差异） |
| 标题上下边距入口 | `dsb_title_top` / `dsb_title_bottom` | 新增“标题上边距 / 标题下边距”滑杆 | 已同义（实现层差异） |
| 界面入口文案 | 不暴露“动画时长可调”语义 | `GlobalReadingSettingsView` / `ReadingInterfaceSettingsHubView` 文案已收敛 | 已同义 |
| 回归证据 | 页面行为可回归 | 新增 `reading_tip_settings_view_test.dart` 覆盖控件渲染 | 已同义 |
| 页眉/页脚显示模式 | `headerMode(3态)` / `footerMode(2态)` | 仍为 `hideHeader/hideFooter` 布尔语义 | 部分同义（保留差异 `S3A-01-R1`） |
| 页眉/页脚颜色配置 | 支持 `tipColor` / `tipDividerColor` | 暂无对应配置字段与入口 | 部分同义（保留差异 `S3A-01-R2`） |

##### 保留差异（S3A-01）

> 状态更新：以下两项已在 `S3A-02` 回补完成，保留记录仅用于追溯迁移过程。

- `S3A-01-R1`：`headerMode/footerMode` 当前未完整复刻 legado 的多态显示语义（尤其 `headerMode=0` 的“状态栏显示时隐藏”）。
  - 影响范围：页眉/页脚显隐策略在个别状态下与 legado 仍可能偏差。
  - 替代方案：当前沿用 `hideHeader/hideFooter + showStatusBar` 组合语义，保证核心阅读可用。
  - 回补计划：放入 Step 3A 后续子任务（S3A-02）处理。
- `S3A-01-R2`：`tipColor/tipDividerColor` 尚未迁移到 `ReadingSettings` 与 UI 入口。
  - 影响范围：页眉/页脚文本与分割线颜色缺少与 legado 等价自定义。
  - 替代方案：继续沿用主题推导颜色，避免无效配置入口。
  - 回补计划：在 Step 4（持久化收口）前评估字段补齐成本并决定是否迁移或按例外流程处理。

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `ReadingTipSettingsView` 增加“标题字号偏移 / 标题上边距 / 标题下边距”三项滑杆。
  - `GlobalReadingSettingsView`、`ReadingInterfaceSettingsHubView` 收敛入口描述文案，移除过期“翻页动画可调”语义。
  - 新增 `test/reading_tip_settings_view_test.dart`，覆盖标题三项控件渲染。
- 为什么：
  - 对齐 legado `TipConfigDialog` 的标题排版入口，先补齐高频可见缺口并收敛入口文案漂移。
- 如何验证：
  - `flutter test test/reading_tip_settings_view_test.dart test/reader_tip_selection_helper_test.dart`
- 兼容影响：
  - 仅新增 UI 入口与文案收敛，不改书源链路与数据结构；历史阅读设置可直接复用。

#### Step 3A 子任务 S3A-02：`headerMode/footerMode/tipColor` 语义回补（已完成）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadTipConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/PageView.kt`
- `/home/server/legado/app/src/main/res/layout/dialog_tip_config.xml`
- `/home/server/legado/app/src/main/res/values/arrays.xml`
- `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`

##### 差异点清单（S3A-02）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S3A-02-D1 | 页眉/页脚显示模式 | `headerMode(0/1/2)` 与 `footerMode(0/1)`；`headerMode=0` 受状态栏显示状态影响 | 仅 `hideHeader/hideFooter` 布尔开关 | 状态栏与页眉联动语义缺失 |
| S3A-02-D2 | 页眉/页脚颜色 | `tipColor=0(同正文)/自定义`；`tipDividerColor=-1(默认)/0(同正文)/自定义` | 颜色完全由主题推导，无配置入口 | 文本/分割线颜色无法对齐 legado 行为 |
| S3A-02-D3 | 双入口一致性 | 阅读页内与全局设置页均可配置显示模式与颜色 | 全局页/阅读页内入口能力不一致 | 跨入口配置可能漂移 |

##### 实施前逐项检查清单（S3A-02）

| 检查项 | 结果 |
| --- | --- |
| 入口（全局设置页 + 阅读页内设置） | 通过：两处均提供模式与颜色入口 |
| 状态（默认值/切换后值/重启恢复） | 通过：模式与颜色写入 `ReadingSettings` 并持久化恢复 |
| 异常（非法颜色输入/旧配置兼容） | 通过：颜色输入仅接受 6 位 HEX；旧 `hideHeader/hideFooter` 自动迁移 |
| 文案（业务语义） | 通过：显示模式与颜色项文案按 legado 语义收敛 |
| 排版（分组与顺序） | 通过：全局页分组扩展为“标题/页眉/页脚/页眉页脚样式”，阅读页内卡片同步 |
| 交互触发（修改即生效） | 通过：模式/颜色切换后滚动与翻页渲染链路即时生效 |

##### 逐项对照清单（S3A-02）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| 页眉显示模式 | `0=显示状态栏时隐藏 1=显示 2=隐藏` | 新增 `headerMode` 字段与选择器，并按 `showStatusBar` 计算可见性 | 已同义 |
| 页脚显示模式 | `0=显示 1=隐藏` | 新增 `footerMode` 字段与选择器 | 已同义 |
| 页眉/页脚文字颜色 | `tipColor`：同正文或自定义 | 新增 `tipColor` 字段、入口与 HEX 自定义输入 | 已同义（实现层差异） |
| 分割线颜色 | `tipDividerColor`：默认/同正文/自定义 | 新增 `tipDividerColor` 字段、入口与 HEX 自定义输入 | 已同义（实现层差异） |
| 渲染链路生效 | `PageView.upTipStyle/upStyle` 统一应用模式与颜色 | `PagedReaderWidget` + `ReaderHeaderBar/ReaderStatusBar` 统一应用模式与颜色 | 已同义 |
| 旧字段兼容 | 历史配置可继续读取 | 保留 `hideHeader/hideFooter` 兼容映射，自动迁移到 mode 字段 | 已同义（兼容增强） |

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `ReadingSettings` 新增 `headerMode/footerMode/tipColor/tipDividerColor` 字段、可见性/颜色解析 helper 与旧字段迁移兼容。
  - `PagedReaderWidget`、`ReaderHeaderBar/ReaderStatusBar`、`SimpleReaderView` 改为按 mode 与 color 语义渲染，覆盖滚动与翻页两条链路。
  - `ReadingTipSettingsView` 与阅读页内设置卡片补齐显示模式与颜色入口（含自定义 HEX 输入）。
  - 补充 `test/reading_settings_test.dart` 迁移与颜色兼容用例。
- 为什么：
  - 回补 S3A-01 保留差异 `S3A-01-R1/R2`，消除 `TipConfigDialog` 关键语义缺口。
- 如何验证：
  - `flutter test test/reading_settings_test.dart test/reading_tip_settings_view_test.dart test/paged_reader_widget_non_simulation_test.dart test/reader_tip_selection_helper_test.dart`
- 兼容影响：
  - 历史 `hideHeader/hideFooter` 配置在读取时自动映射到 mode 字段；不影响旧书源解析链路与五段调试链路。

#### Step 3A 子任务 S3A-03：行为设置页排版归类与双入口一致性核验（已完成）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`

##### 差异点清单（S3A-03）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S3A-03-D1 | 条目归属重复 | `pageTouchSlop/volumeKeyPage/noAnimScrollPage` 属于翻页与按键；文本净化不在该分组 | `ReadingPageSettingsView` 与 `ReadingOtherSettingsView` 同时暴露“净化章节标题” | 信息层级与条目归属漂移 |
| S3A-03-D2 | 亮度条双入口不一致 | `showBrightnessView` 属于显示项，设置入口与阅读中面板应同义 | 阅读中“状态栏与显示”有“显示亮度条”，全局“状态栏与操作”缺失 | 全局配置与页内配置行为漂移 |
| S3A-03-D3 | 行为 Hub 摘要文案漂移 | 分组摘要应与子页真实条目一致 | Hub 文案仍描述旧分组（含重复项） | 用户预期与实际入口不一致 |
| S3A-03-D4 | 阅读页内分组偏移 | 文本处理项应在“其他设置/文本处理”语义分组 | 阅读页“翻页操作”卡片包含“净化章节标题” | 页内设置与全局设置分组不一致 |

##### 实施前逐项检查清单（S3A-03）

| 检查项 | 结果 |
| --- | --- |
| 入口（行为 Hub -> 三个子页） | 通过：入口路径不变，摘要文案与子页条目一致 |
| 状态（切换后即时生效） | 通过：条目归属调整后仍走同一 `ReadingSettings` 写入链路 |
| 异常（重复入口/缺失入口） | 通过：移除重复“净化章节标题”，补齐“显示亮度条”全局入口 |
| 文案（分组语义） | 通过：`翻页与按键/状态栏与操作/其他阅读行为` 摘要与条目同义 |
| 排版（分组顺序与热区） | 通过：各页面保留原有分组骨架，仅做条目归位与摘要收敛 |
| 交互触发（全局页与页内设置一致） | 通过：阅读页内“其他设置”与全局“其他”均承载文本处理项 |

##### 逐项对照清单（S3A-03）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| 翻页与按键分组 | `pageTouchSlop`、`volumeKeyPage`、`noAnimScrollPage` 同组 | `ReadingPageSettingsView` 现仅保留阈值/音量键/滚动无动画 | 已同义 |
| 文本处理分组 | 文本处理项不与翻页触发混放 | “净化章节标题”移至 `ReadingOtherSettingsView` 与阅读页“其他设置” | 已同义 |
| 显示亮度条入口 | `showBrightnessView` 属于显示项 | `ReadingStatusActionSettingsView` 补齐“显示亮度条” | 已同义 |
| 行为 Hub 摘要 | 摘要应映射真实子页条目 | `ReadingBehaviorSettingsHubView` 摘要文案已按三页条目收敛 | 已同义 |
| 双入口分组一致 | 全局设置与阅读中面板同类项归属一致 | 阅读页“翻页操作/其他设置”分组与全局页一致 | 已同义 |

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `ReadingPageSettingsView` 移除“净化章节标题”，将“按键与文本”分组收敛为“按键”。
  - `ReadingStatusActionSettingsView` 补齐“显示亮度条”开关。
  - `ReadingBehaviorSettingsHubView` 更新三项摘要文案，映射实际子页条目。
  - `SimpleReaderView` 将“净化章节标题”从“翻页操作”迁移到“其他设置”卡片，保证双入口同组语义。
  - 新增 `test/reading_behavior_settings_views_test.dart`，覆盖三个行为设置页的条目归属断言。
- 为什么：
  - 回补 Step 3A 剩余排版核验项，消除“条目重复 + 分组漂移 + 双入口不一致”三类迁移偏差。
- 如何验证：
  - `flutter test test/reading_behavior_settings_views_test.dart test/reading_settings_test.dart test/app_settings_test.dart`
- 兼容影响：
  - 仅调整设置入口分组与文案，不新增/删除配置字段；旧配置读取与书源链路行为不受影响。

#### Step 3A 子任务 S3A-04：全局入口与样式页分组排版收敛（已完成）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/res/layout/dialog_read_book_style.xml`
- `/home/server/legado/app/src/main/res/layout/dialog_tip_config.xml`
- `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadTipConfig.kt`
- `/home/server/legado/app/src/main/res/values-zh/strings.xml`
- `/home/server/legado/app/src/main/res/values-zh/arrays.xml`

##### 差异点清单（S3A-04）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S3A-04-D1 | 全局入口层级漂移 | 入口聚焦“界面/设置”两条主路径，不混入无对照扩展入口 | `GlobalReadingSettingsView` 仍保留“恢复默认阅读设置”独立卡片 | 主入口出现 legado 无对照扩展语义 |
| S3A-04-D2 | 样式页分组顺序漂移 | 样式优先展示字体/排版/翻页，排版项含字距 | `ReadingPreferencesView` 混入“亮度/恢复默认”，且缺少字距与字体字重入口 | 信息层级与控件语义不稳定 |
| S3A-04-D3 | 排版回归证据缺口 | 页面结构与入口顺序需有 widget 级证据 | 缺少 `GlobalReadingSettingsView` 与 `ReadingPreferencesView` 定向测试 | 后续改动易引入静默回归 |

##### 实施前逐项检查清单（S3A-04）

| 检查项 | 结果 |
| --- | --- |
| 入口（全局页 -> 界面/行为） | 通过：全局页仅保留两个主入口，顺序为“界面（样式）-> 设置（行为）” |
| 状态（设置写入与返回） | 通过：入口调整不改写入链路，仍通过 `SettingsService` 落盘 |
| 异常（扩展入口漂移） | 通过：移除“恢复默认阅读设置”扩展入口，避免无 legado 对照语义 |
| 文案（业务语义） | 通过：样式页文案收敛为“样式/排版/高级”三组 |
| 排版（分组顺序与间距） | 通过：`ReadingPreferencesView` 收敛为“样式 -> 排版 -> 高级”，移除亮度分组 |
| 交互触发（点击/滑杆即时生效） | 通过：主题、字体、字重、翻页模式与排版滑杆均即时写入 |

##### 逐项对照清单（S3A-04）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| 全局入口层级 | 主入口聚焦界面/行为配置 | `GlobalReadingSettingsView` 仅保留“界面（样式）/设置（行为）” | 已同义 |
| 样式页字体入口 | `ReadStyleDialog` 提供字体与字重入口 | `ReadingPreferencesView` 新增“字体/字重”选择器 | 已同义（实现层差异） |
| 排版核心滑杆 | 字号/字距/行距/段距按顺序可调 | `ReadingPreferencesView` 排版分组补齐“字距”并按同义顺序排列 | 已同义 |
| 非对照扩展入口 | legado 样式页无“亮度/恢复默认”入口 | 已移除“亮度”分组与“恢复默认阅读设置”条目 | 已同义 |
| 回归证据 | 页面行为可回归 | 新增 `reading_preferences_view_test.dart`、`global_reading_settings_view_test.dart` | 已同义 |

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `GlobalReadingSettingsView` 收敛为 `CupertinoListSection` 两入口结构，移除“恢复默认阅读设置”扩展入口。
  - `ReadingPreferencesView` 收敛分组为“样式/排版/高级”，新增“字体/字重/字距”入口，移除“亮度/恢复默认”条目。
  - 新增 `test/reading_preferences_view_test.dart` 与 `test/global_reading_settings_view_test.dart`，覆盖分组与入口顺序断言。
- 为什么：
  - 回补 Step 3A 排版核验剩余项，消除全局入口与样式页中无 legado 对照的扩展语义。
- 如何验证：
  - `flutter test test/reading_preferences_view_test.dart test/global_reading_settings_view_test.dart`
  - `flutter test test/reading_tip_settings_view_test.dart test/reading_behavior_settings_views_test.dart test/reading_settings_test.dart`
- 兼容影响：
  - 仅调整 UI 入口层级与分组，不改动配置字段与持久化格式；旧配置可无损读取。

#### Step 3A 子任务 S3A-05：阅读页内样式页签排版核验与入口收敛（已完成）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `/home/server/legado/app/src/main/res/layout/dialog_read_book_style.xml`
- `/home/server/legado/app/src/main/res/layout/dialog_tip_config.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadTipConfig.kt`

##### 差异点清单（S3A-05）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S3A-05-D1 | 阅读页“界面”入口缺少标题配置 | `TipConfigDialog` 提供 `titleMode/titleSize/titleTop/titleBottom` | `SimpleReaderView` 的 `allowedTabs[0,1]` 仅包含页眉页脚，不含标题四项 | 阅读中无法在“界面”入口完成标题排版调节 |
| S3A-05-D2 | 翻页模式入口层级偏移 | `ReadStyleDialog` 内可直接切换翻页动画模式 | `SimpleReaderView` 将翻页模式放在“设置”页签（tab 2） | “界面/设置”语义分层与 legado 不同，入口预期漂移 |
| S3A-05-D3 | 阅读页内样式分组顺序不完整 | 样式链路应覆盖“正文排版 -> 翻页模式 -> 标题/页眉页脚” | 样式页签缺少“章节标题”分组，且翻页模式不在样式入口 | 排版核验台账无法闭环，Step 3A 不能完结 |

##### 实施前逐项检查清单（S3A-05）

| 检查项 | 结果 |
| --- | --- |
| 入口（阅读页菜单 -> 界面） | 通过：`allowedTabs[0,1]` 仍为阅读内“界面”入口，不新增扩展路由 |
| 状态（默认值/切换后值） | 通过：标题四项与翻页模式均复用 `ReadingSettings` 既有字段与 sanitize 边界 |
| 异常（越界/隐藏模式） | 通过：标题滑杆边界对齐 `0..10/0..100`；`simulation2` 继续禁用并保留可观测显示 |
| 文案（业务语义） | 通过：分组命名收敛为“翻页模式”“章节标题”“页眉页脚” |
| 排版（分组顺序） | 通过：阅读页样式入口形成“排版 -> 翻页模式 -> 章节标题/页眉页脚”的同义层次 |
| 交互触发（改动即生效） | 通过：ActionSheet/滑杆/模式切换即时写入并驱动阅读渲染链路 |

##### 逐项对照清单（S3A-05）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| 标题位置入口 | `rg_title_mode` | 阅读页“界面”页签新增“标题显示”选择器 | 已同义 |
| 标题字号/间距入口 | `dsb_title_size/top/bottom` | 阅读页“界面”页签新增“字号偏移/上边距/下边距”滑杆 | 已同义（实现层差异） |
| 翻页模式入口归属 | `ReadStyleDialog.rgPageAnim` 位于“界面”入口 | 翻页模式卡片迁移到阅读页“排版”页签；“设置”页签移除该入口 | 已同义 |
| 行为页签职责 | `MoreConfigDialog` 侧重触发阈值与按键行为 | 阅读页 tab 2 保留“进度条/章节跳转确认/音量键/滚动无动画/触发阈值” | 已同义 |
| 样式核验闭环 | 阅读页内可完成样式主项调节 | `SimpleReaderView` 样式入口排版台账闭环 | 已同义 |

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `SimpleReaderView` 在“排版”页签补齐“翻页模式”卡片，并从“翻页”页签移除重复入口。
  - `SimpleReaderView` 在“界面”页签新增“章节标题”分组，补齐 `titleMode/titleSize/titleTopSpacing/titleBottomSpacing` 四项入口。
  - 保持页眉页脚与颜色配置分组位置不变，确保与已完成的 `S3A-02` 语义连续。
- 为什么：
  - 收口 Step 3A 最后未闭环项，确保阅读页内“界面（样式）”入口与 legado `ReadStyleDialog/TipConfigDialog` 同义。
- 如何验证：
  - `flutter test test/reading_settings_test.dart test/reading_tip_settings_view_test.dart test/reading_behavior_settings_views_test.dart`
  - `flutter test test/search_book_info_view_compile_test.dart`
  - 手工路径：阅读页底部菜单 -> 界面（tabs 0/1）-> 调整翻页模式与章节标题四项 -> 退出菜单并翻页观察即时生效
- 兼容影响：
  - 仅调整阅读页内设置入口归属，不变更持久化字段；历史配置读写与五段链路不受影响。

### Step 3B：阅读器“设置（行为）”迁移（进行中，并行分支 B）
- Owner：`Reader-UI-B`
- 依赖：Step 2
- 并行性：可与 Step 3A 并行
- 做什么：
  - 对齐 `MoreConfigDialog` / `pref_config_read.xml` 核心配置项语义。
  - 完成交互一致性检查回填。
- 涉及文件：
  - `lib/features/settings/views/reading_behavior_settings_hub_view.dart`
  - `lib/features/settings/views/reading_page_settings_view.dart`
  - `lib/features/settings/views/reading_status_action_settings_view.dart`
  - `lib/features/settings/views/reading_other_settings_view.dart`
  - `lib/features/reader/views/simple_reader_view.dart`
- 预期结果：
  - 配置项触发方式、确认/取消、生效时机与 Legado 同义。
- 验证方式：
  - 交互核验台账 + 手工路径回归。

#### Step 3B 子任务 S3B-01：换源候选面板筛选（已完成）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/data/dao/SearchBookDao.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/changesource/ChangeBookSourceDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/changesource/ChangeBookSourceViewModel.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookViewModel.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`

##### 差异点清单（S3B-01）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S3B-01-D1 | 候选筛选入口 | 换源列表内置 `SearchView`，按书源名/最新章节筛选 | 使用 `CupertinoActionSheet`，无筛选输入 | 候选较多时难定位目标书源 |
| S3B-01-D2 | 交互复用 | 阅读页/详情页均走同一换源筛选语义 | 两处各自维护 ActionSheet 逻辑 | 文案与行为易漂移 |
| S3B-01-D3 | 交互回归证据 | legado 依赖页面行为回归 | 缺少 Flutter 侧 Widget 级回归用例 | 改动后易产生 UI 回归 |

##### 实施前逐项检查清单（S3B-01）

| 检查项 | 结果 |
| --- | --- |
| 入口（阅读页/详情页） | 通过：均在“换源”动作进入候选面板 |
| 状态（空查询/有查询） | 通过：空查询显示全量，有查询按关键字过滤 |
| 异常（无候选/无匹配） | 通过：分别展示“暂无候选书源”“无匹配候选” |
| 文案（筛选提示） | 通过：提示语义为“筛选书源 / 最新章节” |
| 排版（面板结构与触达） | 通过：统一面板头部、搜索框、列表区与取消动作 |
| 交互触发（选择即返回） | 通过：点选候选后关闭面板并回传所选书源 |

##### 逐项对照清单（S3B-01）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| 筛选字段 | `originName`、`latestChapterTitle`（`changeSourceSearch`） | `source.bookSourceName`、`book.lastChapter` | 已同义 |
| 筛选触发 | 输入变化即筛选 | `CupertinoSearchTextField` 监听文本变化 | 已同义 |
| 候选选择 | 点选列表项进入换源 | 点选候选项返回并执行换源 | 已同义 |
| 空结果反馈 | 结果为空时列表无项 | 显式空态文案 | 已同义（反馈更直观） |
| 底部安全区 | 列表容器避免遮挡 | 去除重复 bottom inset，避免双倍留白 | 已同义 |

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 新增 `SourceSwitchCandidateSheet`，统一阅读页与详情页候选面板。
  - 抽取 `ReaderSourceSwitchHelper.filterCandidates`，按“书源名/最新章节”筛选。
  - 阅读页与详情页均改为调用统一候选面板入口。
  - 新增 `test/source_switch_candidate_sheet_test.dart`，覆盖筛选与选择回传。
  - 修正候选面板底部重复安全区留白。
- 为什么：
  - 对齐 legado 换源筛选语义并避免双入口逻辑漂移。
- 如何验证：
  - `flutter test test/reader_source_switch_helper_test.dart test/source_switch_candidate_sheet_test.dart`
- 兼容影响：
  - 对旧书源解析链路无变更；仅调整候选展示与筛选交互，兼容性风险低。

#### Step 3B 子任务 S3B-02：简繁转换与屏幕常亮联动（已完成）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/BaseReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/book/ContentProcessor.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ChineseConverter.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/EffectiveReplacesDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/AppConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/data/entities/BookChapter.kt`
- `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`

##### 差异点清单（S3B-02）

| ID | 差异 | legado 语义 | soupreader 当前 | 影响 |
| --- | --- | --- | --- | --- |
| S3B-02-D1 | 阅读中跨入口联动 | 读页内设置变更通过事件总线即时回流阅读页（`UP_CONFIG` / `keep_light`） | `SimpleReaderView` 仅消费本地 `_settings`，未监听 `SettingsService` 外部变更 | 设置页修改“简繁/常亮”后，已打开阅读页可能不即时生效 |
| S3B-02-D2 | 简繁切换后标题刷新 | `AppConfig.chineseConverterType` 改变后，正文与章节标题同批刷新 | 阅读页 `_updateSettings` 触发内容刷新时，当前标题赋值未走简繁转换 | 当前章标题在切换后可能短暂显示未转换文本 |
| S3B-02-D3 | 联动回归证据 | legado 通过运行时行为验证设置生效链路 | 目前缺少“阅读设置通知回流”定向测试 | 后续改动易回归且不易被发现 |

##### 实施前逐项检查清单（S3B-02）

| 检查项 | 结果 |
| --- | --- |
| 入口（设置页/阅读页双入口） | 通过：`SettingsService.readingSettingsListenable` 回流到 `SimpleReaderView` |
| 状态（切换前后即时生效） | 通过：简繁/常亮切换后阅读页即时刷新并保持 |
| 异常（平台通道/不支持平台） | 通过：常亮能力维持 best-effort，平台异常不阻塞阅读 |
| 文案（简繁模式/常亮开关） | 通过：保留“简繁转换/屏幕常亮”语义，不新增扩展文案 |
| 排版（设置项布局与分组） | 待核验：Step 3A 继续回填页面排版台账 |
| 交互触发（切换即生效并持久化） | 通过：切换后即时生效并写入持久化设置 |

##### 逐项对照清单（S3B-02）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| 简繁切换触发链路 | `AppConfig.chineseConverterType` 变更后 `ReadBook.loadContent(resetPageOffset=false)` | 阅读页订阅 `readingSettingsListenable`，外部变更触发 `_updateSettings(..., persist:false)` 并执行内容刷新 | 已同义 |
| 简繁切换标题刷新 | 正文与章节标题同批转换（`ContentProcessor` + `BookChapter.getDisplayTitle`） | `_updateSettings` 在内容变更分支改为 `_postProcessTitle(title)` 更新当前标题 | 已同义 |
| 屏幕常亮联动 | `keep_light` 变更后 `upScreenTimeOut -> keepScreenOn(...)` | `keepScreenOn` 变更统一走 `_syncNativeKeepScreenOn`，支持跨入口实时联动 | 已同义（实现层差异） |
| 设置可观测性 | 运行态事件链可验证 | 新增 `SettingsService` 通知流回归测试，覆盖“保存 -> 监听 -> 读取” | 已同义 |

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 在 `SettingsService` 增加 `readingSettingsListenable`，并在初始化/保存时同步通知。
  - `SimpleReaderView` 新增对阅读设置通知的订阅与解绑，支持阅读中接收外部设置更新。
  - 修复简繁切换时当前章节标题未走转换的问题（统一使用 `_postProcessTitle`）。
  - 新增 `test/app_settings_test.dart` 用例，覆盖“屏幕常亮 + 简繁转换”设置保存与通知联动。
- 为什么：
  - 对齐 legado 的“设置切换后阅读页即时生效”语义，避免双入口配置漂移。
- 如何验证：
  - `flutter test test/app_settings_test.dart test/reading_settings_test.dart`
  - `flutter test test/widget_test.dart`
- 兼容影响：
  - 不改动书源解析链路；仅增强阅读设置通知与阅读页状态同步，对旧书源兼容无负面影响。

#### Step 3B 子任务 S3B-03：`pageTouchSlop` 阈值语义对齐（已完成）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/AppConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/ReadView.kt`

##### 差异点清单（S3B-03）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S3B-03-D1 | `pageTouchSlop` 取值边界 | `0=系统默认`，可输入 `0..9999` | 以 `%` 语义限制为 `0..100` | 阈值语义偏差，迁移不等价 |
| S3B-03-D2 | 触发阈值计算 | `pageSlopSquare=(slop)^2`，`slop` 为系统默认或自定义数值 | 固定映射为 `5..50` 的比例阈值 | 手势触发灵敏度与 legado 行为不一致 |
| S3B-03-D3 | 入口一致性 | `MoreConfigDialog` 同时暴露 `pageTouchSlop` 与 `noAnimScrollPage` | 全局页缺 `noAnimScrollPage`，页内面板仅滑杆输入 | 双入口行为对齐不足 |

##### 实施前逐项检查清单（S3B-03）

| 检查项 | 结果 |
| --- | --- |
| 入口（全局页/阅读页内） | 通过：两处均可设置 `pageTouchSlop`，全局页补齐 `noAnimScrollPage` |
| 状态（默认值/自定义值） | 通过：`0` 显示“系统默认”，非 `0` 显示数值 |
| 异常（越界/非法输入） | 通过：输入按 `0..9999` 收敛，非法输入不落盘 |
| 文案（阈值语义） | 通过：统一“翻页触发阈值（0=系统默认）”语义 |
| 排版（分组与热区） | 通过：沿用现有分组结构，行项触发热区不变 |
| 交互触发（即时生效） | 通过：设置写入后即时作用于手势判定阈值 |

##### 逐项对照清单（S3B-03）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| `pageTouchSlop` 边界 | `0..9999`，`0` 使用系统默认 | `ReadingSettings` 收敛为 `0..9999`，`0` 保留默认语义 | 已同义 |
| 阈值计算公式 | 以 `slop^2` 判定是否越过拖拽阈值 | `PagedReaderWidget` 改为“`0 -> kTouchSlop`，否则直接使用自定义数值，再平方比较” | 已同义（平台常量实现差异） |
| 配置入口结构 | `MoreConfigDialog` 内聚相关开关 | 全局 `ReadingPageSettingsView` 与阅读页内面板均可触达阈值项，且全局页新增“滚动翻页无动画” | 已同义 |

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 将 `ReadingSettings.pageTouchSlop` 的边界从 `0..100` 调整为 `0..9999`。
  - `ReadingPageSettingsView` 将“翻页触发灵敏度(%)”改为“翻页触发阈值”，补齐 `0=系统默认` 文案与范围，并新增 `noAnimScrollPage` 开关。
  - `SimpleReaderView` 阅读页内设置面板将 `pageTouchSlop` 从滑杆改为数值输入，统一边界与文案。
  - `PagedReaderWidget` 手势判定从比例映射改为 legado 语义：`0` 走系统 `touch slop`，非 `0` 直接作为阈值参与平方比较。
  - 新增 `test/reading_settings_test.dart` 用例，覆盖 `pageTouchSlop` 边界与非法输入回退。
- 为什么：
  - 修复 `pageTouchSlop` 在边界和运行时触发语义上的迁移偏差，避免“同名配置不同手感”。
- 如何验证：
  - `flutter test test/reading_settings_test.dart test/app_settings_test.dart`
  - `flutter test test/widget_test.dart`
- 兼容影响：
  - 不涉及书源解析链路；仅调整翻页手势阈值配置语义。旧配置中 `0..100` 仍为合法子集，不会导致读取失败。

#### Step 3B 子任务 S3B-04：音量键翻页按键分发语义对齐（已完成）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/AppConfig.kt`

##### 差异点清单（S3B-04）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S3B-04-D1 | `volumeKeyPage` 控制范围 | `volumeKeyPage` 仅控制音量键翻页；方向键/翻页键不受该开关影响 | `_handleKeyEvent` 在 `volumeKeyPage=false` 时直接返回，方向键/翻页键被一并禁用 | 硬件键行为偏差，交互不等价 |
| S3B-04-D2 | 空格键映射 | `KEYCODE_SPACE` 触发下一页 | 未映射空格键翻页 | 外接键盘行为缺项 |
| S3B-04-D3 | 回归证据 | legado 依赖运行时按键行为 | 缺少按键映射定向单测 | 后续按键改动回归风险高 |

##### 实施前逐项检查清单（S3B-04）

| 检查项 | 结果 |
| --- | --- |
| 入口（阅读页硬件按键） | 通过：统一收口 `SimpleReaderView._handleKeyEvent` |
| 状态（`volumeKeyPage` 开/关） | 通过：仅影响音量键，方向键/翻页键保持可用 |
| 异常（菜单/搜索/自动阅读面板显示） | 通过：面板显示时继续拦截按键翻页 |
| 文案（配置文案） | 通过：不新增文案，沿用“音量键翻页”语义 |
| 排版（设置页布局） | 通过：本子任务不改动布局结构 |
| 交互触发（按键映射） | 通过：补齐空格键下一页并保持上下页方向一致 |

##### 逐项对照清单（S3B-04）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| 音量键受开关控制 | `volumeKeyPage=false` 时仅音量键失效 | `ReaderKeyPagingHelper` 对音量键映射受 `volumeKeyPageEnabled` 控制 | 已同义 |
| 方向键/翻页键独立生效 | 方向键、PageUp/PageDown 与音量键开关解耦 | 方向键、PageUp/PageDown、Space 不受 `volumeKeyPage` 影响 | 已同义 |
| 空格键翻页 | `KEYCODE_SPACE -> NEXT` | `LogicalKeyboardKey.space -> next` | 已同义 |
| 可观测与回归 | 行为回归可验证 | 新增按键映射定向单测覆盖开关边界 | 已同义 |

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 新增 `ReaderKeyPagingHelper`，集中维护“音量键/方向键/翻页键”映射规则。
  - `SimpleReaderView._handleKeyEvent` 改为通过 helper 分发，修复 `volumeKeyPage` 误控方向键的问题，并补齐空格键翻页。
  - 新增 `test/reader_key_paging_helper_test.dart`，覆盖音量键开关边界、方向键独立行为、空格键映射和非翻页键兜底。
- 为什么：
  - 对齐 legado “音量键开关仅作用于音量键”的交互语义，避免外接键盘行为偏差。
- 如何验证：
  - `flutter test test/reader_key_paging_helper_test.dart`
- 兼容影响：
  - 不涉及书源解析与持久化结构；仅修正硬件按键分发语义，对旧书源兼容无负面影响。

#### Step 3B 子任务 S3B-05：页眉/页脚内容位重复项清理语义对齐（已完成）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadTipConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/PageView.kt`

##### 差异点清单（S3B-05）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S3B-05-D1 | 重复项处理 | `TipConfigDialog.clearRepeat`：选择某内容位后，其他位置同类内容自动清空为“无” | 页眉/页脚内容位允许重复 | 同类信息可在多位置重复显示，行为偏离 legado |
| S3B-05-D2 | 双入口一致性 | 同一清理语义对阅读中面板与配置入口一致生效 | 全局设置页与阅读页内设置各自直接写值 | 入口间行为易漂移 |
| S3B-05-D3 | 回归证据 | legado 依赖运行时交互验证 | 缺少“跨页眉/页脚去重”定向测试 | 后续改动存在回归盲区 |

##### 实施前逐项检查清单（S3B-05）

| 检查项 | 结果 |
| --- | --- |
| 入口（全局页 + 阅读页内） | 通过：两处均接入统一 helper |
| 状态（选中非“无”） | 通过：同类内容位自动清空并回写新值 |
| 异常（选中“无”） | 通过：仅更新当前槽位，不触发额外清理 |
| 文案（选项与提示） | 通过：沿用既有文案，不新增扩展文案 |
| 排版（面板结构） | 通过：不改动布局结构，仅调整选择行为 |
| 交互触发（即时刷新） | 通过：选择后立即更新 `_settings` 并持久化 |

##### 逐项对照清单（S3B-05）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| 选择器触发 | 选择内容位后即时更新配置 | 两个入口均保留 ActionSheet 即时选择 | 已同义 |
| 重复项清理 | `clearRepeat(repeat)` 跨 6 个槽位清理重复值 | `ReaderTipSelectionHelper.applySelection` 统一执行跨页眉/页脚去重 | 已同义 |
| “无”选项行为 | 选择“无”不清理其他槽位 | helper 对“无”仅更新当前槽位 | 已同义 |
| 交互回归 | 运行时可验证 | 新增 helper 定向单测覆盖跨槽位去重边界 | 已同义 |

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 新增 `ReaderTipSelectionHelper`，统一维护页眉/页脚内容位的“去重 + 写入”规则。
  - `ReadingTipSettingsView` 与 `SimpleReaderView` 同时接入 helper，避免双入口逻辑漂移。
  - 新增 `test/reader_tip_selection_helper_test.dart`，覆盖跨页眉/页脚重复项清理与“无”选项边界。
- 为什么：
  - 对齐 legado `TipConfigDialog.clearRepeat` 语义，补齐“页眉/页脚内容位”交互一致性。
- 如何验证：
  - `flutter test test/reader_tip_selection_helper_test.dart test/reading_settings_test.dart`
- 兼容影响：
  - 不改动书源链路和页面结构；仅修正内容位选择行为。已有配置在用户下一次选择内容位后按新规则收敛。

#### Step 3B 子任务 S3B-06：翻页模式与动画时长语义收敛（已完成）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/BaseReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/ReadView.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/PageDelegate.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/HorizontalPageDelegate.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/SlidePageDelegate.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/CoverPageDelegate.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/ScrollPageDelegate.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/NoAnimPageDelegate.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/SimulationPageDelegate.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/model/ReadBook.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/constant/PageAnim.kt`

##### 差异点清单（S3B-06）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S3B-06-D1 | 动画时长可配置性 | `ReadView.defaultAnimationSpeed` 固定 `300`；`PageDelegate.startScroll` 仅按距离缩放 | 阅读设置暴露 `pageAnimDuration(100..600)` 并落盘 | 用户可见行为偏离 legado |
| S3B-06-D2 | 多入口一致性 | 翻页模式可选，动画时长无独立配置入口 | 全局设置页、阅读页内面板、快速设置均暴露“动画时长”滑杆 | 入口语义与 legado 不同 |
| S3B-06-D3 | 持久化语义 | 无“动画时长”用户配置字段 | `ReadingSettings` 持久化 `pageAnimDuration` | 旧配置会保留非 legado 取值 |

##### 实施前逐项检查清单（S3B-06）

| 检查项 | 结果 |
| --- | --- |
| 入口（全局页/阅读页内/快速设置） | 通过：三处入口均去除动画时长可调控件 |
| 状态（翻页模式切换） | 通过：切换后仍执行重排与章节进度保持 |
| 异常（历史配置含非 300 值） | 通过：读取后统一收敛到固定值，不影响启动 |
| 文案（动画语义） | 通过：不再暴露“可调动画时长”文案 |
| 排版（分组结构） | 通过：保留既有分组，仅移除滑杆行项 |
| 交互触发（即时生效） | 通过：翻页模式切换即时生效；动画时长固定执行 |

##### 逐项对照清单（S3B-06）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| 翻页模式集合与顺序 | `cover/slide/simulation/scroll/none` | `PageTurnModeUi` 顺序保持一致（`simulation2` 仍隐藏） | 已同义 |
| 模式切换生效链路 | 切换后 `upPageAnim + loadContent(false)` | `_updateSettings` 执行重排、模式切换与进度保持恢复 | 已同义（实现层差异） |
| 动画时长语义 | 固定 `300ms`（按滚动距离缩放） | `ReadingSettings` 固定 `300ms`，运行时统一使用常量 | 已同义 |
| 配置入口 | 不提供动画时长设置项 | 全局页/阅读页内/快速设置均移除动画时长滑杆 | 已同义 |

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `ReadingSettings` 新增 `legacyPageAnimDuration` 常量，并将 `pageAnimDuration` 收敛为固定 `300ms`。
  - 移除 `ReadingPreferencesView`、`SimpleReaderView`、`ReaderQuickSettingsSheet` 中“动画时长”可调滑杆。
  - 阅读运行时统一改为 `ReadingSettings.legacyPageAnimDuration`，覆盖翻页控件与滚动翻页动画时长。
  - 新增 `test/reading_settings_test.dart` 用例，覆盖“历史值输入后仍固定 300ms”语义。
- 为什么：
  - 对齐 legado 的核心语义：翻页模式可选、动画时长固定，不引入扩展配置入口。
- 如何验证：
  - `flutter test test/reading_settings_test.dart test/paged_reader_widget_non_simulation_test.dart`
- 兼容影响：
  - 历史配置中的 `pageAnimDuration` 非 `300` 值将被自动收敛；不涉及书源解析和数据结构破坏，兼容风险低。

#### Step 3B 子任务 S3B-07：点击区域 9 宫格动作与菜单兜底语义对齐（已完成，含保留差异）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ClickActionConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/BaseReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/ReadView.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/AppConfig.kt`
- `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`
- `/home/server/legado/app/src/main/res/layout/dialog_click_action_config.xml`

##### 差异点清单（S3B-07）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S3B-07-D1 | 动作集合缺失 | 9 宫格动作支持 `-1..13`（含朗读段落/正文编辑/替换开关/同步进度） | 仅支持 `0/1/2/3/4/7/10` | 配置项同名但能力不完整 |
| S3B-07-D2 | 默认映射不一致 | 默认 `tc=上一页`、`bc=下一页`，仅 `mc` 为菜单 | 默认 `tc=菜单`、`bc=菜单` | 点击热区行为偏离 legado |
| S3B-07-D3 | 菜单兜底缺失 | `detectClickArea()`：若 9 区都非菜单，自动恢复 `mc=菜单` 并提示 | 无兜底，可能出现“无菜单入口” | 用户可被困在无菜单态 |
| S3B-07-D4 | 保存触发时机 | 区域选项点击后立即持久化 | 需要额外点击“保存”才落盘 | 交互时机偏离 legado |

##### 实施前逐项检查清单（S3B-07）

| 检查项 | 结果 |
| --- | --- |
| 入口（全局“状态栏与操作” + 阅读页内设置） | 通过：两处均复用同一点击区域配置弹窗 |
| 状态（默认映射、重启恢复） | 通过：默认 9 宫格映射改为 legado 同义，并由设置持久化恢复 |
| 异常（非法动作值、缺失区域、无菜单区域） | 通过：非法值收敛为菜单；缺失区域补默认；无菜单自动恢复 `mc=菜单` |
| 文案（动作名称与业务语义） | 通过：动作名称扩展到 legado 的 `-1..13` 语义集合 |
| 排版（9 宫格结构与选择热区） | 通过：保留 3x3 结构与单格选择行为 |
| 交互触发（选择即生效） | 通过：移除“保存”按钮，改为选择动作后即时保存 |

##### 逐项对照清单（S3B-07）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| 动作 ID 集合 | `-1..13` | `ClickAction` 扩展到 `-1..13` 并统一标签 | 已同义 |
| 默认 9 宫格映射 | `tc=上一页`、`bc=下一页` | `defaultZoneConfig` 改为同义映射 | 已同义 |
| 无菜单兜底 | 9 区全非菜单时强制 `mc=菜单` | `ClickAction.normalizeConfig` 强制回补 `mc=菜单` 并提示 | 已同义 |
| 配置生效时机 | 选择动作即落盘 | 弹窗改为选择后即时 `onSave` | 已同义 |
| 阅读点击分发 | `ReadView.click(action)` 分发 `-1..13` | `SimpleReaderView._handleClickAction` 覆盖全集；可用动作直接执行 | 部分同义（保留差异 `S3B-07-R1`） |

##### 保留差异（S3B-07-R1）

- 差异内容：动作 `5/6/8/9/12/13` 当前未具备与 legado 等价运行能力（朗读段落、正文编辑、替换开关、云进度同步、朗读暂停/继续）。
- 当前处理：点击这些动作时统一给出可观测提示（明确“能力暂未实现”），避免静默失败。
- 影响范围：仅影响上述动作的执行效果，不影响 9 宫格映射、保存时机与菜单兜底语义。
- 回补计划：待扩展能力解锁后按扩展计划回补（与 `docs/plans/2026-02-19-reader-extensions-blocked-execplan.md` 联动）。

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `ReadingSettings/ClickAction` 扩展到 legado 动作全集（`-1..13`），并对齐默认 9 宫格映射。
  - 新增 `ClickAction.normalizeConfig/hasMenuZone`，统一执行“缺失补默认 + 非法值收敛 + 无菜单回补 `mc=菜单`”。
  - `ClickActionConfigDialog` 改为“选择即保存”，去除额外保存按钮，并在触发菜单回补时给出提示。
  - `SimpleReaderView` 点击分发补齐动作全集分支；可落地动作直接执行，不可落地动作输出可观测提示。
  - `PagedReaderWidget` 点击区域解析统一走 `normalizeConfig`，避免阅读运行时出现无菜单配置。
  - 新增/更新 `test/reading_settings_test.dart` 用例，覆盖默认映射、无菜单回补、非法值收敛和动作集合兼容。
- 为什么：
  - 对齐 legado 点击区域核心语义，避免“默认手势不一致”和“无菜单入口”这类迁移级行为偏差。
- 如何验证：
  - `flutter test test/reading_settings_test.dart test/paged_reader_widget_non_simulation_test.dart test/search_book_info_view_compile_test.dart`
- 兼容影响：
  - 历史点击配置中的非法动作值将被收敛；
  - 若历史配置导致无菜单区域，将自动恢复 `mc=菜单`；
  - 对旧书源解析链路无影响。

### Step 3C：按钮与点击跳转层级同义核验（已完成）
- Owner：`Core-Migration`（主）、`Reader-UI-A/B`（协作）
- 依赖：Step 3A、Step 3B
- 并行性：串行（Step 4 前置）
- 做什么：
  - 输出按钮对照清单（按钮名称、顺序、可见条件、可点击条件、点击反馈）。
  - 输出点击跳转层级对照清单（一级/二级/三级入口、返回路径、回退语义）。
  - 对不能等价复刻项按第 `1.1.2` 章标记 `blocked`，并记录替代方案与回补计划。
- 涉及文件：
  - `lib/features/settings/views/reading_*.dart`
  - `lib/features/reader/views/simple_reader_view.dart`
  - `docs/plans/2026-02-19-reader-core-config-parity-execplan.md`
- 预期结果：
  - 按钮与跳转层级核验台账闭环，且不再存在“同名入口但层级偏移”的未跟踪项。
- 验证方式：
  - Widget/手工双路径核验（不执行 `flutter analyze`）。
  - 手工路径覆盖“设置页入口 -> 二级页 -> 三级弹层/子页 -> 返回”。

#### Step 3C 子任务 S3C-01：按钮集合/排序/跳转层级核验与收敛（已完成）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/BaseReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ClickActionConfigDialog.kt`
- `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`
- `/home/server/legado/app/src/main/res/layout/dialog_read_book_style.xml`
- `/home/server/legado/app/src/main/res/layout/dialog_tip_config.xml`
- `/home/server/legado/app/src/main/res/layout/dialog_click_action_config.xml`

##### 差异点清单（S3C-01）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S3C-01-D1 | 阅读页内设置多余扩展按钮 | `ReadStyleDialog/TipConfigDialog/MoreConfigDialog` 无“恢复默认阅读配置”入口 | `SimpleReaderView` 的“设置”页签包含“恢复默认”卡片与确认流程 | 按钮集合多出 legado 无对照扩展入口，层级语义漂移 |
| S3C-01-D2 | 二级 Hub 按钮热区稳定性 | legado 按钮在固定容器内可稳定点击 | `ReadingInterfaceSettingsHubView/ReadingBehaviorSettingsHubView` 使用 `ShadButton + Expanded` 在无界宽度下出现布局断言 | 影响按钮可点击条件与测试可复现性 |
| S3C-01-D3 | 阅读底部四按钮热区与高度 | legado 底栏按钮“目录/朗读/界面/设置”均可稳定触发 | `ReaderBottomMenuNew` 底部四按钮在 `ShadButton` 约束下出现高度溢出，存在点击命中不稳定 | 影响按钮触发反馈一致性验收 |

##### 实施前逐项检查清单（S3C-01）

| 检查项 | 结果 |
| --- | --- |
| 入口（全局设置页/阅读页菜单） | 通过：全局入口、阅读页底栏入口与 legado 对照路径一致 |
| 状态（按钮可见/隐藏条件） | 通过：目录/朗读/界面/设置在阅读菜单显示时可见，局部按钮按章节边界禁用 |
| 异常（不可点击时反馈） | 通过：章节边界按钮禁用，不触发回调；无菜单配置仍由 `ClickAction` 兜底 |
| 文案（按钮命名） | 通过：一级入口文案收敛为 legado 同义语义 |
| 排版（排序与热区） | 通过：底部四按钮顺序固定为“目录 -> 朗读 -> 界面 -> 设置”，并修复热区溢出问题 |
| 交互触发（点击反馈） | 通过：按钮点击回调与目标入口一一对应，返回路径可回退到上一层 |
| 点击跳转层级（一级/二级/三级） | 通过：一级入口 -> 二级设置页 -> 三级弹层/子页路径可复现 |

##### 逐项对照清单（S3C-01）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| 阅读底栏四按钮集合与顺序 | `目录/朗读/界面/设置` | `ReaderBottomMenuNew` 顺序保持一致 | 已同义 |
| 底栏按钮点击反馈 | 点击后分别进入目录/朗读/界面/更多设置链路 | 回调映射一一对应并补齐热区稳定性 | 已同义 |
| 全局阅读设置一级入口 | 界面与行为入口分离 | `GlobalReadingSettingsView` 保持“界面（样式）/设置（行为）” | 已同义 |
| 二级 Hub 入口层级 | 界面与行为页下钻到具体设置页 | `ReadingInterfaceSettingsHubView` 与 `ReadingBehaviorSettingsHubView` 下钻链路稳定 | 已同义 |
| 阅读页内设置按钮集合 | 不包含“恢复默认阅读配置”入口 | 已移除 `SimpleReaderView` 中“恢复默认”卡片与确认流程 | 已同义 |
| 返回路径 | 子页/弹层可回退到上一级入口 | 新增导航回归测试覆盖“进入 -> 返回”路径 | 已同义 |

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `SimpleReaderView` 移除“恢复默认”卡片与对应确认弹层，收敛阅读页内设置按钮集合。
  - `ReadingInterfaceSettingsHubView`、`ReadingBehaviorSettingsHubView` 将列表项按钮从 `ShadButton` 收敛为 `CupertinoButton` 容器，修复无界宽度下热区布局异常。
  - `ReaderBottomMenuNew` 将底部四按钮触发组件从 `ShadButton` 收敛为 `CupertinoButton`，修复高度溢出与点击命中不稳定。
  - 新增 `test/reading_settings_navigation_parity_test.dart` 与 `test/reader_bottom_menu_new_test.dart`，覆盖按钮顺序、回调映射、可点击边界与跳转返回路径。
- 为什么：
  - Step 3C 的阻塞门槛是“按钮集合/排序/触发反馈 + 点击跳转层级”同义；上述差异会直接导致验收不闭环。
- 如何验证：
  - `flutter test test/reading_settings_navigation_parity_test.dart test/reader_bottom_menu_new_test.dart`
  - `flutter test test/global_reading_settings_view_test.dart test/reading_behavior_settings_views_test.dart test/reading_preferences_view_test.dart`
  - 手工路径：
    - 阅读页底栏：`目录 -> 朗读 -> 界面 -> 设置` 逐项点击；
    - 设置页：`阅读设置（全局） -> 界面（样式）/设置（行为） -> 二级页 -> 返回`。
- 兼容影响：
  - 仅调整按钮容器与入口收敛，不改动书源链路与配置字段持久化格式；
  - 历史阅读设置数据不受影响。

### Step 4：配置持久化与迁移策略收敛（已完成）
- Owner：`Reader-Persistence`
- 依赖：Step 3C
- 并行性：串行（收口步骤）
- 做什么：
  - 统一 `ReadingSettings` 字段边界与 `SettingsService` 落盘/迁移策略。
  - 确认双入口（全局页/阅读页）对同一字段行为一致。
- 涉及文件：
  - `lib/features/reader/models/reading_settings.dart`
  - `lib/core/services/settings_service.dart`
- 预期结果：
  - 默认值、旧字段兼容、异常回退、重启恢复行为稳定且同义。
- 验证方式：
  - 定向单测与手工回归（不执行 `flutter analyze`）。

#### Step 4 子任务 S4-01：持久化迁移策略与字段边界归一（已完成）

##### legado 对照基准（已完整读取）

- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadTipConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/AppConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/LocalConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/PageView.kt`
- `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`
- `/home/server/legado/app/src/main/res/values-zh/arrays.xml`

##### 差异点清单（S4-01）

| ID | 差异 | legado 语义 | soupreader 变更前 | 影响 |
| --- | --- | --- | --- | --- |
| S4-01-D1 | schema 迁移策略 | `LocalConfig.isLastVersion` 仅做版本位迁移，不重置阅读配置 | `SettingsService._migrateReadingSettingsSchema()` 在低版本时整包重置 `ReadingSettings` | 用户历史阅读配置可能被非预期清空 |
| S4-01-D2 | 翻页方向归一化时机 | 翻页模式与运行时方向语义一致，不依赖重启修正 | `pageDirection` 仅在 `init` 阶段归一化，保存路径缺少同义归一 | 双入口保存后可能出现“模式已改但方向字段未同步” |
| S4-01-D3 | 异常配置自愈 | 非法值读取后可回落默认并继续稳定持久化 | 解析异常时仅内存回落默认，不保证立即回写修复 | 异常 JSON 可能在后续冷启动重复触发解析失败 |
| S4-01-D4 | 默认值同义性 | `ReadBookConfig.Config.showHeaderLine` 默认 `false` | `ReadingSettings.showHeaderLine` 默认 `true` | 新安装默认体验与 legado 页眉分割线语义偏差 |

##### 实施前逐项检查清单（S4-01）

| 检查项 | 结果 |
| --- | --- |
| 入口（全局设置页/阅读页内） | 通过：两入口写入最终统一走 `SettingsService.saveReadingSettings` + `ReadingSettings.sanitize` |
| 状态（默认值/切换后/重启恢复） | 通过：schema 迁移保留历史值，且重启后保持一致 |
| 异常（非法 JSON/越界字段） | 通过：解析失败时回落默认并立即回写自愈 |
| 文案（业务语义） | 不涉及 UI 文案改动（N/A） |
| 排版（结构/间距） | 不涉及 UI 布局改动（N/A） |
| 交互触发（改动即生效） | 通过：双入口保存后同一字段即时生效，且持久化字段语义一致 |

##### 逐项对照清单（S4-01）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
| --- | --- | --- | --- |
| schema 迁移策略 | 版本位迁移不清空阅读配置 | schema 升级改为“保留原配置 + sanitize 归一 + 更新版本位” | 已同义 |
| 翻页方向归一 | 翻页模式与方向语义一致，不依赖重启修正 | `ReadingSettings.sanitize()` 统一按 `pageTurnMode` 推导 `pageDirection`，覆盖初始化与保存路径 | 已同义 |
| 异常配置自愈 | 非法配置回落后继续稳定可持久化 | 解析失败/结构异常时回落默认并回写可解析 JSON | 已同义 |
| 默认值（页眉分割线） | `showHeaderLine=false` | `ReadingSettings` 默认值收敛为 `false` | 已同义 |
| 双入口一致性 | 同一配置入口修改后行为一致 | 全局页与阅读页内入口最终都收敛到同一持久化链路 | 已同义 |

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `SettingsService` 移除 schema 迁移阶段的整包重置，改为“读取 -> sanitize 归一 -> 必要时回写 -> 更新版本位”。
  - `SettingsService` 在阅读设置 JSON 解析失败或结构异常时，自动回落默认并立即回写修复。
  - `ReadingSettings.sanitize()` 新增 `pageTurnMode/pageDirection` 统一归一规则，消除仅初始化阶段归一导致的双入口漂移。
  - `ReadingSettings` 将 `showHeaderLine` 默认值收敛为 legado 同义默认 `false`。
  - 新增/更新定向测试，覆盖 schema 迁移保留、异常 JSON 自愈、保存路径归一与重启恢复。
- 为什么：
  - Step 4 的目标是把“字段边界 + 落盘迁移 + 异常回退 + 重启恢复”收敛成单一可信链路，避免用户配置在迁移时被清空或不同入口写入语义漂移。
- 如何验证：
  - `flutter test test/reading_settings_test.dart test/app_settings_test.dart`
  - `flutter test test/reading_tip_settings_view_test.dart test/reading_preferences_view_test.dart test/reading_behavior_settings_views_test.dart test/reading_settings_navigation_parity_test.dart test/reader_bottom_menu_new_test.dart`
- 兼容影响：
  - 历史阅读配置不再因 schema 升级被整包重置；
  - 旧字段/异常字段继续通过 `sanitize` 回落到安全值；
  - 不影响书源解析链路与数据库结构。

### Step 5：迁移级验收与证据归档（已完成，带阻塞结论）
- Owner：`Core-Migration`
- 依赖：Step 4
- 并行性：串行（最终收口）
- 做什么：
  - 产出逐项对照清单：已同义/保留差异/blocked 原因。
  - 汇总命令验证与手工路径证据。
  - 进入提交前阶段后执行一次 `flutter analyze`。
- 预期结果：
  - 可复现、可审计、可回归。
- 验证方式：
  - 验收报告与命令输出记录。

#### Step 5 子任务 S5-01：验收证据归档与阻塞结论（已完成）

##### 逐项对照清单（S5-01）

| 类别 | 结论 |
| --- | --- |
| 排版一致性 | 已按 `Layout Parity Checklist` 全项 `done` 回填 |
| 交互一致性 | 除 `S3B-07-R1` 外均已 `done`；9 宫格未迁移动作维持可观测提示兜底 |
| 按钮与跳转层级一致性 | 已按 `Button & Navigation Parity Checklist` 全项 `done` 回填 |
| 保留差异/阻塞 | `S3B-07-R1`（动作 `5/6/8/9/12/13` 依赖扩展能力解锁） |

##### 命令验证结果（S5-01）

- `flutter test test/reading_settings_test.dart test/app_settings_test.dart test/reading_tip_settings_view_test.dart test/reading_preferences_view_test.dart test/reading_behavior_settings_views_test.dart test/reading_settings_navigation_parity_test.dart test/reader_bottom_menu_new_test.dart`
  - 结果：`All tests passed`。
- `flutter analyze`（提交前阶段执行且仅执行一次）
  - 结果：返回 `9 issues`（含 `reader_bottom_menu.dart` 的 `CupertinoButton.minSize` 废弃项与仓库既有告警）。
- `flutter test test/reader_bottom_menu_new_test.dart`
  - 结果：在将 `minSize` 替换为 `minimumSize: Size.zero` 后，定向用例 `All tests passed`。
- `flutter test test/source_switch_candidate_sheet_test.dart test/reader_source_switch_helper_test.dart`
  - 结果：在将 `source_switch_candidate_sheet.dart` 的 `CupertinoButton.minSize` 替换为 `minimumSize` 后，换源筛选相关用例 `All tests passed`。

##### 手工回归记录（S5-01）

- 核心链路 `search -> bookInfo -> toc -> content`、`explore -> bookInfo -> content`：
  - 状态：`待设备回归`（本轮终端环境仅完成命令与测试证据归档）。
- 配置链路“双入口修改互相回流 + 重启保持”：
  - 状态：`待设备回归`（路径与预期已在本计划“验收与证据”章节固化）。

##### 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 回填迁移级逐项对照清单，确认排版、交互、按钮与跳转层级的验收结论。
  - 在提交前阶段执行一次 `flutter analyze`，并记录告警清单与归因。
  - 修复本轮相关文件 `reader_bottom_menu.dart` 的 `CupertinoButton.minSize` 废弃用法，改为 `minimumSize: Size.zero`。
  - 修复 `source_switch_candidate_sheet.dart` 的 `CupertinoButton.minSize` 旧写法（`32/0`），统一改为 `minimumSize: const Size(32, 32) / Size.zero`。
- 为什么：
  - Step 5 目标是形成“可审计的验收证据 + 保留差异闭环”，避免仅凭口头结论宣称迁移一致。
- 如何验证：
  - 通过上述命令验证结果与三类 checklist 的状态回填。
- 兼容影响：
  - 不改变核心阅读链路语义；
  - `reader_bottom_menu.dart` 与 `source_switch_candidate_sheet.dart` 仅修复 API 兼容写法，不改变按钮顺序、筛选语义与回调逻辑。

## Layout Parity Checklist（排版一致性）

| 页面 | 状态 | 备注 |
| --- | --- | --- |
| 阅读全局入口（`GlobalReadingSettingsView`） | done | 入口收敛为“界面（样式）-> 设置（行为）”，移除无 legado 对照扩展入口 |
| 样式与排版（`ReadingPreferencesView`） | done | 分组收敛为“样式/排版/高级”，补齐字体/字重/字距并移除亮度与恢复默认扩展项 |
| 页眉页脚与标题（`ReadingTipSettingsView`） | done | 标题三项、显示模式与颜色语义已回补，入口顺序对齐 |
| 翻页与按键（`ReadingPageSettingsView`） | done | 条目归位为“阈值/音量键/滚动无动画”，移除重复文本项 |
| 状态栏与操作（`ReadingStatusActionSettingsView`） | done | 补齐“显示亮度条”，与阅读页内显示分组一致 |
| 其他（`ReadingOtherSettingsView`） | done | 文本处理分组保留“简繁转换/净化章节标题”语义 |
| 阅读页内设置面板（`SimpleReaderView`） | done | 已完成样式页签核验：补齐“章节标题”四项入口并将翻页模式收敛到界面入口 |

## Interaction Parity Checklist（交互一致性）

| 配置项 | 状态 | 要点 |
| --- | --- | --- |
| 翻页模式切换 | done | 模式切换后重排与章节进度保持策略对齐 |
| 动画时长 | done | 对齐 legado 固定 `300ms`，移除可调滑杆入口 |
| pageTouchSlop | done | 输入边界对齐 `0..9999`，`0=系统默认`，阅读中即时生效 |
| 音量键翻页 | done | `volumeKeyPage` 仅控制音量键；方向键/PageUp/PageDown/Space 独立生效 |
| 点击区域 9 宫格 | partial | 动作集合/默认映射/菜单兜底/即时保存已对齐；动作 `5/6/8/9/12/13` 见保留差异 `S3B-07-R1` |
| 页眉/页脚显示模式 | done | `headerMode(3态)`/`footerMode(2态)` 与状态栏联动语义已对齐 |
| 页眉/页脚颜色 | done | `tipColor/tipDividerColor`（含自定义输入与默认值语义）已对齐 |
| 页眉/页脚内容位 | done | 选择器触发、重复项策略、即时刷新（全局页与阅读页内入口统一） |
| 简繁转换 | done | 切换后正文与当前章节标题即时刷新，并保持持久化 |
| 屏幕常亮 | done | 切换后即同步原生常亮能力，跨入口变更可回流阅读页 |
| 换源候选筛选（书源名/最新章节） | done | 对齐 `changeSourceSearch` 语义，含空态与回传用例 |

## Button & Navigation Parity Checklist（按钮与跳转层级一致性）

| 核验项 | 状态 | 要点 |
| --- | --- | --- |
| 全局设置页按钮集合与顺序 | done | `GlobalReadingSettingsView` 保持“界面（样式） -> 设置（行为）”顺序，文案与显示条件同义 |
| 二级设置页按钮集合与禁用条件 | done | 界面/行为 Hub 下钻按钮可点击条件稳定，阅读边界按钮禁用条件有测试覆盖 |
| 阅读页内设置面板按钮与触发反馈 | done | 底栏四按钮顺序固定，点击回调一一对应；移除无 legado 对照的“恢复默认”入口 |
| 点击后跳转层级与返回路径 | done | 新增导航回归测试覆盖“一级入口 -> 二级页 -> 返回”路径 |
| 例外项记录闭环 | done | Step 3C 无新增例外；既有阻塞项仍沿用 `S3B-07-R1` 台账追踪 |

## 风险与回滚

### 主要风险
- 字段兼容风险：旧配置 JSON 与新字段边界冲突。
- 双入口一致性风险：阅读页内配置与全局配置出现行为漂移。
- 布局走样风险：平台组件替换导致结构语义偏差。

### 失败模式
- 用户重启后配置丢失或回退异常。
- 同一配置在不同入口显示与行为不一致。
- 五段链路调试输出不足，无法定位问题。

### 回滚策略
- 配置迁移采取版本化、可回退策略（保留兼容读取）。
- 每个步骤独立提交，允许阶段回滚。
- 遇到无法等价项立即 `blocked` 并记录例外，不带病继续。

## 验收与证据

### 命令验证
- 开发中：仅执行定向测试（禁止提前执行 `flutter analyze`）。
- 提交前：仅执行一次 `flutter analyze`。

### 手工回归路径（必须记录）
- 核心链路：
  - 搜索 -> 详情 -> 目录 -> 正文
  - 发现 -> 详情 -> 正文
- 配置链路：
  - 设置页修改配置 -> 进入阅读页验证
  - 阅读页内修改配置 -> 返回设置页验证
  - 重启应用后配置保持验证

### 预期输出
- 逐项对照清单（含差异原因与影响）。
- 排版一致性核验记录。
- 交互一致性核验记录。
- 核心链路调试证据与回归截图/步骤。

## Progress

- [x] Step 1：迁移基线固化（差异点清单 + 索引修复）
- [x] Step 2：核心链路对照矩阵
- [x] Step 3A：界面（样式）迁移与排版核验（S3A-01/S3A-02/S3A-03/S3A-04/S3A-05 已完成）
- [ ] Step 3B：设置（行为）迁移与交互核验（进行中：S3B-01/S3B-02/S3B-03/S3B-04/S3B-05/S3B-06/S3B-07 已完成，保留差异 `S3B-07-R1`）
- [x] Step 3C：按钮与点击跳转层级同义核验（S3C-01 已完成）
- [x] Step 4：配置持久化与迁移策略收敛（S4-01 已完成）
- [x] Step 5：迁移级验收与证据归档（S5-01 已完成，含阻塞结论与命令证据）

当前阻塞：`S3B-07-R1`（动作 `5/6/8/9/12/13` 依赖未解锁能力，暂以可观测提示兜底）；`flutter analyze` 仍有仓库级既有告警待后续清理（剩余数量待下次提交前 analyze 复核）。  
下一步：等待“开始做扩展功能”解锁后回补 `S3B-07-R1`，并在后续任务中清理仓库级 analyze 历史告警后再推进计划 `done` 收口。

## Surprises & Discoveries

- 发现 `PLANS.md` 仍引用已删除的计划文件，导致索引失真。
- 仓库当前存在与本计划无关的进行中改动，需在后续实施中避免覆盖他人变更。
- legado 五段调试链路以 `Debug.startDebug` 为统一入口，原始源码快照状态位固定为 `10/20/30/40`。
- 当前核心链路存在 `B-01`、`T-01~T-03`、`C-01~C-03` 保留差异，已在 Step 2 产出中编号追踪。
- legado 的换源筛选实际依赖 `SearchBookDao.changeSourceSearch`，关键字段为 `originName/latestChapterTitle`，并非作者字段。
- 阅读页 `_updateSettings` 在内容变更分支曾直接使用未转换标题，导致简繁切换后标题短暂不同步；已在 S3B-02 修复并补测试。
- 发现 `pageTouchSlop` 在 soupreader 里被实现为百分比阈值，而 legado 为“原始阈值数值 + 系统默认回退”，已在 S3B-03 对齐。
- 发现 `SimpleReaderView` 将 `volumeKeyPage` 误用于所有翻页键，导致方向键/PageUp/PageDown 在开关关闭时也失效；已在 S3B-04 修复。
- 发现页眉/页脚内容位在全局设置页与阅读页内面板均未实现 `clearRepeat` 去重，已在 S3B-05 通过统一 helper 收口。
- 发现 soupreader 将翻页动画时长扩展为可调配置（`100..600`），与 legado 固定 `300ms` 语义不一致；已在 S3B-06 收敛。
- 发现 soupreader 点击区域默认映射与 legado 不同（`tc/bc` 被设为菜单）且缺少“无菜单区域自动恢复”机制；已在 S3B-07 收敛。
- 发现 legado 9 宫格动作全集中有多项依赖尚未迁移能力（TTS/正文编辑/云同步），已记录 `S3B-07-R1` 并转为可观测提示兜底。
- 发现 `ReadingTipSettingsView` 缺少 `titleSize/titleTop/titleBottom` 入口且界面 Hub 文案仍保留“翻页动画可调”描述，已在 S3A-01 收敛并补回归测试。
- 发现 legado `headerMode=0` 与 `hideStatusBar` 是联动语义（状态栏显示时隐藏页眉），不能等价为单一布尔开关。
- 发现 legado 颜色配置以 `Int` 持久化，导入到 Dart 时可能出现有符号整型，需在 `ReadingSettings` 做 `ARGB` 归一化。
- 发现 `ReadingBehaviorSettingsHubView` 在 widget test 环境会触发 `Row/Expanded` 的既有宽度约束断言；本轮回归改为锁定三个子页条目归属，不在本子任务扩散修复该历史问题。
- 发现 `GlobalReadingSettingsView` 使用 `ShadButton + Expanded` 在 test 环境同样触发无界宽度断言，本轮改为 `CupertinoListSection` 收敛入口层级并规避约束问题。
- 发现 `SimpleReaderView` 的“界面”入口（`allowedTabs[0,1]`）缺少标题四项且翻页模式误归属到“设置”页签，已在 `S3A-05` 回补并完成排版核验闭环。
- `2026-02-19` 新增需求强调“按钮、排版、点击跳转层级”需与 legado 同义（仅 UI 风格可差异），计划已新增 Step 3C 做按钮级与路由级核验收口。
- Step 3C 执行中确认 `SimpleReaderView` 仍保留“恢复默认阅读配置”扩展入口（legado 无对照），已在 `S3C-01` 移除。
- Step 3C 执行中发现 `ReadingInterfaceSettingsHubView` 与 `ReadingBehaviorSettingsHubView` 的 `ShadButton + Expanded` 组合在无界宽度下会触发布局断言，已改为 `CupertinoButton` 容器收敛。
- Step 3C 执行中发现 `ReaderBottomMenuNew` 底栏按钮在 `ShadButton` 约束下存在高度溢出与命中不稳定，已改为 `CupertinoButton` 并补充回归测试。
- Step 4 执行中确认 `SettingsService` 的 schema 迁移曾采用整包重置策略，与 legado 的“版本位迁移不清配置”语义冲突，已改为非破坏迁移。
- Step 4 执行中确认 `pageDirection` 仅在初始化阶段归一，保存路径存在漂移风险；已下沉到 `ReadingSettings.sanitize` 统一归一。
- Step 4 执行中确认阅读设置 JSON 解析失败后缺少立即回写，已补齐异常自愈落盘。
- Step 5 执行中确认 `flutter analyze`（唯一一次）报告 9 条问题，其中 `reader_bottom_menu.dart` 为本轮相关告警，其余 8 条为仓库既有告警。
- Step 5 执行中确认将 `CupertinoButton.minSize` 替换为 `minimumSize: Size.zero` 后，底栏定向测试保持通过。
- Step 5 收口补充中发现换源候选面板仍残留 `CupertinoButton.minSize` 旧写法，已统一替换为 `minimumSize` 并通过筛选面板定向测试验证。

## Decision Log

- 决策 1：本轮严格采用“核心优先”，扩展项不并行启动。
  - 原因：AGENTS 强约束与当前需求边界一致。
- 决策 2：将“排版一致 + 交互一致”提升为阻塞验收门槛。
  - 原因：需求方明确提出，并符合迁移级别定义。
- 决策 3：先修索引再进入实施。
  - 原因：无有效计划入口将导致执行不可追踪。
- 决策 4：Step 2 的可观测口径统一采用 `RuleParserEngine.*Debug` + `SourceAvailabilityDiagnosisService`。
  - 原因：与 legado `Debug` 模式均为“链路阶段化 + 失败可归因”。
- 决策 5：保留差异不在 Step 2 直接实现，先入台账并在 Step 5 前完成“回补或例外确认”。
  - 原因：保持当前阶段“基线先行”，避免在无完整验收口径下混入实现偏航。
- 决策 6：S3B-01 筛选仅对齐 legado 的“书源名 + 最新章节”字段，不扩展作者/书名筛选。
  - 原因：避免超出 legado 交互语义，降低迁移偏差。
- 决策 7：阅读设置跨入口联动采用 `SettingsService.readingSettingsListenable`，避免在阅读页引入额外轮询。
  - 原因：保持持久化单一事实源，同时满足“设置改动即时生效”的迁移语义。
- 决策 8：`pageTouchSlop` 采用 legado 同义语义（`0=系统默认`，非 `0` 为直接阈值），不继续使用百分比映射。
  - 原因：百分比映射会改变手势触发边界，无法满足迁移级一致性。
- 决策 9：按键分发采用独立 helper 收口，明确“音量键受开关控制、方向键不受控”的分层规则。
  - 原因：降低 `SimpleReaderView` 条件分支复杂度，同时避免后续按键映射再次回归。
- 决策 10：页眉/页脚内容位去重采用独立 helper（而非在两个入口分别实现），统一复刻 legado `clearRepeat`。
  - 原因：双入口共享同一规则可避免后续交互漂移，并降低维护成本。
- 决策 11：翻页动画时长固定为 `300ms`，移除所有用户可调入口。
  - 原因：legado 无该配置项，固定时长为核心语义，扩展入口会引入行为偏差。
- 决策 12：点击区域动作全集保持 legado 编号与默认映射，运行时统一执行菜单兜底（`mc=菜单`）。
  - 原因：避免“无菜单入口”导致核心交互阻断，且与 legado `detectClickArea` 语义一致。
- 决策 13：对于当前未等价能力的点击动作（`5/6/8/9/12/13`），先保留入口并提供可观测提示，不做静默降级。
  - 原因：在扩展能力冻结约束下，优先保证核心链路可用并保留后续回补锚点。
- 决策 14：S3A-01 优先补齐标题三项排版入口并先修正文案漂移，`headerMode/footerMode/tipColor` 留在后续子任务回补。
  - 原因：先修复高频可见缺口，避免一次性改动过大导致 Step 3A 与 Step 4 同时偏航。
- 决策 15：S3A-02 同时改造全局设置页与阅读页内入口，并保留 `hideHeader/hideFooter` 兼容映射到 mode 字段。
  - 原因：保证双入口语义同义且不破坏历史配置读取。
- 决策 16：将“净化章节标题”从“翻页与按键”分组迁移到“其他/文本处理”分组，并同步阅读页内卡片归属。
  - 原因：对齐 legado 条目语义边界，消除同一配置在两个行为页重复暴露造成的信息层级偏差。
- 决策 17：在全局“状态栏与操作”页补齐“显示亮度条”开关，并保持与阅读页内“状态栏与显示”同名同义。
  - 原因：`showBrightnessView` 已在阅读页内生效，若全局入口缺失会造成双入口语义漂移。
- 决策 18：S3A-03 回归仅保留稳定的三子页 widget 用例，不在本子任务修复 Hub 页历史测试约束问题。
  - 原因：当前目标是完成条目归属核验，避免将无关历史布局 bug 混入本轮迁移收口。
- 决策 19：`GlobalReadingSettingsView` 收敛为 `CupertinoListSection` 双入口结构，不再保留“恢复默认阅读设置”扩展入口。
  - 原因：入口层级需与 legado 主语义同义，避免在全局入口暴露无对照扩展流程。
- 决策 20：`ReadingPreferencesView` 收敛为“样式/排版/高级”三组，并补齐“字体/字重/字距”入口，同时移除“亮度/恢复默认”扩展项。
  - 原因：对齐 `ReadStyleDialog` 的核心分组与控件顺序，防止页面语义被扩展入口稀释。
- 决策 21：阅读页内“翻页模式”入口收敛到“界面（样式）”侧，并在同一入口补齐“章节标题”四项配置。
  - 原因：对齐 legado `ReadStyleDialog + TipConfigDialog` 入口语义，关闭 Step 3A 样式页签排版遗留项。
- 决策 22：将“按钮集合/顺序/点击条件 + 点击跳转层级”提升为独立阻塞验收项（Step 3C），UI 风格差异不纳入功能差异。
  - 原因：需求方最新明确要求除 UI 风格外保持与 legado 一致，需避免“入口同名但跳转层级偏移”。
- 决策 23：移除阅读页内“恢复默认阅读配置”入口，不以确认弹层保留扩展流程。
  - 原因：legado 无对应按钮语义，保留会导致按钮集合与入口层级偏差。
- 决策 24：界面/行为 Hub 的入口按钮统一改用 `CupertinoButton` 容器实现，不继续使用 `ShadButton + Expanded` 组合。
  - 原因：该组合在无界宽度下存在布局断言，影响按钮可点击条件与测试可复现性。
- 决策 25：阅读底栏四按钮触发容器改用 `CupertinoButton`，并通过定向测试锁定“顺序 + 回调映射 + 边界可点击性”。
  - 原因：`ShadButton` 约束导致高度溢出与命中不稳定，不满足 Step 3C 验收口径。
- 决策 26：Step 4 将 schema 迁移策略调整为“非破坏迁移”，禁止低版本升级时整包重置阅读配置。
  - 原因：legado 基线是版本位迁移与兼容读取，不应在迁移阶段丢失用户阅读配置。
- 决策 27：将 `pageTurnMode/pageDirection` 归一逻辑下沉到 `ReadingSettings.sanitize`，由模型层统一兜底。
  - 原因：初始化归一不足以覆盖双入口保存路径，模型层收口可避免同字段跨入口漂移。
- 决策 28：阅读设置解析失败时立即回写默认可解析 JSON，不保留“坏数据原样留存”。
  - 原因：保证冷启动可重复稳定，避免同一异常在后续每次启动重复触发。
- 决策 29：Step 5 的 `flutter analyze` 严格按规范执行一次，不因修复局部告警追加二次全量 analyze。
  - 原因：遵循 AGENTS“提交前仅执行一次 `flutter analyze`”的约束。
- 决策 30：仅修复本轮相关文件的 analyze 告警，其余仓库级既有告警在后续独立任务中处理。
  - 原因：避免在迁移收口阶段扩散到非本任务模块，降低回归面。
- 决策 31：在不追加 `flutter analyze` 的前提下，优先清理已定位的 `CupertinoButton.minSize` 旧 API 并以定向测试闭环验证。
  - 原因：遵守“提交前仅一次 analyze”约束，同时推进既有兼容告警的可执行收口项。

## Outcomes & Retrospective

- Step 2 已交付：
  - 五段链路对照矩阵已落盘，回归路径与可观测口径已明确。
  - 保留差异已编号并纳入验收前追踪，不以“主链路可用”替代同义迁移结论。
- Step 3B 阶段进展：
  - 已完成 S3B-01（换源候选面板筛选）：阅读页/详情页统一交互入口，筛选语义对齐 legado。
  - 已补充 helper + widget 定向测试，覆盖筛选、空态与选择回传行为。
  - 已完成 S3B-02（简繁转换/屏幕常亮联动）：阅读页支持跨入口设置回流，当前标题与正文转换时机保持同义。
  - 已完成 S3B-03（翻页触发阈值）：`pageTouchSlop` 边界、文案、渲染阈值计算与入口结构对齐 legado。
  - 已完成 S3B-04（音量键翻页）：按键映射改为“音量键受开关控制，方向键/PageUp/PageDown/Space 独立生效”，并补齐单测。
  - 已完成 S3B-05（页眉/页脚内容位去重）：全局设置页与阅读页内面板统一执行跨槽位去重，并补齐定向单测。
  - 已完成 S3B-06（翻页模式/动画时长）：翻页模式切换链路保持同义，动画时长收敛为 legado 固定 `300ms` 并移除可调入口。
  - 已完成 S3B-07（点击区域 9 宫格）：动作集合、默认映射、菜单兜底和即时保存语义已对齐；未迁移动作已记录 `S3B-07-R1`。
- Step 3A 阶段进展：
  - 已完成 S3A-01（标题排版入口补齐与文案收敛）：补齐 `titleSize/titleTop/titleBottom` 控件，修正文案漂移，并补充 widget 回归测试。
  - 已完成 S3A-02（`headerMode/footerMode/tipColor` 语义回补）：模式联动、颜色配置与双入口交互已对齐，`S3A-01-R1/R2` 已关闭。
  - 已完成 S3A-03（行为设置页排版归类）：修复“净化章节标题”重复归属、补齐“显示亮度条”全局入口，并完成三子页定向回归测试。
  - 已完成 S3A-04（全局入口与样式页排版收敛）：全局入口收敛为“界面/行为”双入口，样式页补齐字体/字重/字距并移除无 legado 对照扩展项。
  - 已完成 S3A-05（阅读页内样式页签核验）：界面入口补齐标题四项，并将翻页模式入口收敛到样式页签，Step 3A 正式收口。
- Step 3C 阶段进展：
  - 已完成 S3C-01（按钮与跳转层级核验）：移除阅读页内“恢复默认”扩展入口，完成底栏四按钮顺序/反馈核验，并收敛二级 Hub 按钮热区实现。
  - 已新增 `reading_settings_navigation_parity_test.dart` 与 `reader_bottom_menu_new_test.dart`，覆盖“按钮排序 + 回调映射 + 层级跳转与返回路径”。
- Step 4 阶段进展：
  - 已完成 S4-01（持久化迁移策略与字段边界归一）：schema 迁移改为非破坏策略，异常 JSON 自愈回写，`pageTurnMode/pageDirection` 归一下沉到模型层。
  - 已新增/更新定向测试，覆盖“迁移保留历史值 + 异常回退 + 保存即归一 + 重启恢复”四类场景。
- Step 5 阶段进展：
  - 已完成 S5-01（验收证据归档与阻塞结论）：三类 checklist 全量回填，命令验证结果落盘。
  - 已在提交前阶段执行一次 `flutter analyze` 并记录 9 条问题；其中本轮相关告警已修复并通过底栏定向测试验证。
  - 已补充修复换源候选面板中的 `CupertinoButton.minSize` 旧写法，并通过换源筛选定向测试验证不回归。
  - 计划维持 `blocked`，待扩展能力解锁后回补 `S3B-07-R1`，并在后续任务中清理仓库级 analyze 既有告警。
- 计划收口更新（`2026-02-19`）：
  - 根据最新需求新增 Step 3C，要求对“按钮集合/排序/可点击条件/点击反馈”和“点击跳转层级/返回路径”做逐项核验。
  - Step 4 依赖更新为 Step 3C，确保先完成按钮与跳转层级一致性后再做持久化收口。
- 后续回填项（阻塞解除后补充）：
  - `S3B-07-R1` 解锁后的回补实现与验收结果；
  - 仓库级 analyze 既有告警清理结果；
  - 手工设备回归记录与截图证据。
