# Legado -> SoupReader 扩展能力分期迁移（RSS / TTS / Dict / Android API）

- 状态：`active`
- 基线：`../legado` 当前 `HEAD`
- 更新时间：2026-02-19

## 背景与目标

### 背景

核心链路（`search/explore/bookInfo/toc/content`）已进入逐项同义收敛阶段，但扩展能力仍处于“挂账”状态。为避免扩展项长期停留在占位文案，需要将扩展能力从“记录”推进到“可执行分期”。

本计划基于已完整复核的 legado 关键实现文件：

- RSS：`../legado/app/src/main/java/io/legado/app/ui/main/rss/RssFragment.kt`、`../legado/app/src/main/java/io/legado/app/ui/main/rss/RssViewModel.kt`、`../legado/app/src/main/java/io/legado/app/ui/rss/source/manage/RssSourceActivity.kt`、`../legado/app/src/main/java/io/legado/app/ui/rss/source/manage/RssSourceViewModel.kt`
- TTS：`../legado/app/src/main/java/io/legado/app/service/TTSReadAloudService.kt`、`../legado/app/src/main/java/io/legado/app/service/BaseReadAloudService.kt`
- Dict：`../legado/app/src/main/java/io/legado/app/ui/dict/DictDialog.kt`、`../legado/app/src/main/java/io/legado/app/ui/dict/DictViewModel.kt`、`../legado/app/src/main/java/io/legado/app/ui/dict/rule/DictRuleActivity.kt`、`../legado/app/src/main/java/io/legado/app/ui/dict/rule/DictRuleViewModel.kt`
- Android API：`../legado/app/src/main/java/io/legado/app/api/ReaderProvider.kt`、`../legado/app/src/main/java/io/legado/app/api/controller/BookController.kt`、`../legado/app/src/main/java/io/legado/app/api/controller/BookSourceController.kt`、`../legado/app/src/main/java/io/legado/app/api/controller/RssSourceController.kt`、`../legado/app/src/main/java/io/legado/app/api/controller/ReplaceRuleController.kt`

### 目标

1. 将 RSS/TTS/Dict/Android API 的迁移差异固化为分期执行清单（阶段目标、依赖、风险、验收证据）。
2. 保证每一阶段都可独立交付，不引入“未完成但可见入口”。
3. 在不破坏核心链路的前提下，建立扩展能力回归路径。

### 范围

- 仅产出分期执行方案与优先级，不在本计划内直接实现扩展功能。
- 输出每阶段的入口语义、状态流与验证要求。

### 非目标

- 本计划不直接落地 RSS/TTS/Dict/Android API 业务代码。
- 不改变核心链路既有已对齐行为。

### 成功标准

1. 扩展能力具备单一事实来源的 ExecPlan 文档。
2. 每个扩展模块都有明确“首批可交付范围 + 验收证据”。
3. 在 `PLANS.md` 中可追踪该计划状态与入口。

## 差异点清单（扩展能力）

| 模块 | legado 文件位置 | soupreader 当前 | 差异原因 | 影响 |
|---|---|---|---|---|
| RSS 主链路 | `ui/main/rss/*`、`ui/rss/*`、`model/rss/*` | `lib/features/rss` 目录缺失；设置页仅占位文案（`lib/features/settings/views/settings_view.dart`） | 模块未迁移 | 无法使用订阅源管理、文章列表与 RSS 阅读链路 |
| TTS 朗读服务 | `service/TTSReadAloudService.kt`、`service/BaseReadAloudService.kt` | 阅读器入口为占位提示（`lib/features/reader/views/simple_reader_view.dart:3108`）；无 `lib/features/tts` | 服务层未迁移 | 无语音朗读、无音频焦点/通知/定时朗读状态流 |
| Dict 词典与规则 | `ui/dict/*`、`ui/dict/rule/*` | 无 `lib/features/dict`；无词典规则管理入口 | 模块未迁移 | 无选词查词、无词典规则可配置能力 |
| Android API/Provider | `api/ReaderProvider.kt`、`api/controller/*` | 无等价 Flutter 插件层；`lib/platform/api` 目录缺失 | 平台接口层未迁移 | 无跨应用数据互通（书源、书架、目录/正文读取） |

## 本批次差异点清单（2026-02-19：Phase A-1 RSS 源管理与订阅列表）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/data/entities/RssSource.kt` + `../legado/app/src/main/java/io/legado/app/data/dao/RssSourceDao.kt` | RSS 源具备独立实体与 DAO，支持 `flowAll/flowEnabled/flowGroupSearch/flowLogin/flowNoGroup` 等筛选链路 | `lib` 下无 RSS 实体/仓储，无法持久化 RSS 源列表 | 数据层未迁移 | RSS 源管理与订阅列表都无法建立稳定状态流 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/source/manage/RssSourceActivity.kt` + `RssSourceViewModel.kt` + `RssSourceAdapter.kt` | 订阅源管理提供搜索、分组过滤、启停、置顶置底、编辑、删除、分组维护等入口 | `lib/features/settings/views/settings_view.dart` 与 `source_management_view.dart` 仅显示“订阅管理暂未实现” | 管理页 UI/状态流未迁移 | 用户无法维护 RSS 源，后续订阅链路无数据可用 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/source/manage/GroupManageDialog.kt` | 分组管理支持新增/重命名/删除，且“新增分组”会分配给无分组源 | soupreader 无 RSS 分组管理入口与批量分组维护逻辑 | 分组状态流未迁移 | 分组筛选、分组菜单、批量运营能力缺失 |
| `../legado/app/src/main/java/io/legado/app/ui/main/rss/RssFragment.kt` + `RssAdapter.kt` + `RssViewModel.kt` | 订阅页展示启用源列表，支持 `group:` 搜索、长按动作、`singleUrl` 打开策略与“源管理”入口 | soupreader 无订阅列表页面，设置页也无可跳转的 RSS 主入口 | 订阅主链路未迁移 | 用户无法从已配置 RSS 源进入订阅浏览 |
| `../legado/app/src/main/java/io/legado/app/ui/main/rss/RssFragment.kt` (`openRss`) | `singleUrl=true` 时解析 `sortUrl/sourceUrl` 后直开；否则进入文章列表链路 | soupreader 无 `singleUrl` 打开策略 | 打开分支语义未迁移 | 单 URL RSS 源在首批阶段不可用 |

## 本批次差异点清单（2026-02-19：Phase A-1 Step 2.2 RSS 源管理页面）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/rss/source/manage/RssSourceActivity.kt` (`initSearchView`, `upSourceFlow`, `onCompatOptionsItemSelected`) | 搜索框与快捷筛选统一驱动 `all/enabled/disabled/login/noGroup/group:/keyword` 状态流 | 仅有 `lib/features/rss/services/rss_source_manage_helper.dart`，缺少管理页 UI 与搜索态绑定 | 页面状态机未落地 | 用户无法在 RSS 管理入口执行 legado 同义筛选流程 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/source/manage/GroupManageDialog.kt` + `RssSourceViewModel.kt` (`addGroup/upGroup/delGroup`) | 分组管理支持新增/重命名/删除；新增分组会分配给无分组源 | Flutter 侧无分组管理入口，helper 尚未接入仓储更新 | 分组管理交互未迁移 | 分组筛选依赖的分组集无法在 App 内维护 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/source/manage/RssSourceAdapter.kt` | 单源操作包含启停、编辑、置顶、置底、删除 | Flutter 侧无 RSS 管理列表页，单源操作入口缺失 | 列表操作层未迁移 | 用户无法在 RSS 源维度完成维护闭环 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/source/manage/RssSourceActivity.kt` + `../legado/app/src/main/res/menu/rss_source.xml` | “订阅源管理”是可直接进入的功能入口 | `lib/features/settings/views/settings_view.dart`、`lib/features/settings/views/source_management_view.dart` 仍为“订阅管理暂未实现”占位 | 入口层级未迁移 | RSS 管理链路在设置页不可达 |

## 本批次差异点清单（2026-02-19：Phase A-1 Step 2.3 RSS 订阅列表入口）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/main/rss/RssFragment.kt` (`initSearchView`, `upRssFlowJob`) + `../legado/app/src/main/java/io/legado/app/ui/main/rss/RssViewModel.kt` | 订阅页默认展示启用源（`flowEnabled`），输入 `group:` 时切换 `flowEnabledByGroup`，其余关键字走启用源搜索 | Flutter 侧仅有 RSS 源管理页，未提供“启用源订阅列表 + group: 搜索”页面 | 订阅入口状态机未迁移 | 用户无法按 legado 路径浏览“可订阅源列表”，也无法在订阅入口执行 `group:` 定位 |
| `../legado/app/src/main/java/io/legado/app/ui/main/rss/RssFragment.kt` + `../legado/app/src/main/res/menu/main_rss.xml` | 订阅页顶部具备“收藏/分组/设置”菜单，分组项来自 `flowEnabledGroups` 动态注入 | soupreader 无等价订阅页导航与动态分组菜单 | 菜单结构与入口层级未迁移 | 订阅入口缺少 legado 关键操作路径（分组筛选、进入订阅管理） |
| `../legado/app/src/main/java/io/legado/app/ui/main/rss/RssAdapter.kt` + `../legado/app/src/main/res/menu/rss_main_item.xml` | 订阅列表长按提供 `置顶/编辑/禁用/删除`，点击执行 `openRss` | soupreader 无 RSS 订阅列表视图，因此也无长按动作与点击打开链路 | 列表交互层未迁移 | 订阅入口无法在源维度直接做维护动作，交互效率低于 legado |
| `../legado/app/src/main/java/io/legado/app/ui/main/rss/RssFragment.kt` (`openRss`) + `../legado/app/src/main/java/io/legado/app/ui/main/rss/RssViewModel.kt` (`getSingleUrl`) | `singleUrl=true` 时优先解析 `sortUrl`（含 `@js:`/`<js>` + `::` 拆分），再决定“内置阅读/外部打开”；`singleUrl=false` 进入文章列表链路 | soupreader 未实现 `singleUrl` 打开策略与分支决策 | 打开链路语义未迁移 | 单 URL RSS 源无法按 legado 语义直接进入阅读目标，首批可用性不达标 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/article/RssSortActivity.kt` + `RssSortViewModel.kt` | 非 `singleUrl` 通过 `url=sourceUrl` 进入文章列表链路（后续再按分类 URL 展开） | soupreader 当前没有可承接的 RSS 文章列表入口 | 下游承接页面缺失 | 即使完成订阅列表也无法进入下一跳，链路中断 |

## 本批次差异点清单（2026-02-19：Phase A-2 RSS 文章列表与阅读承载）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/rss/article/RssSortActivity.kt` + `RssSortViewModel.kt` | 文章页按 `sortUrls` 动态生成 Tab；菜单含 `登录/刷新分类/源变量/编辑源/清空文章/切换排版/阅读记录` | `lib/features/rss/views/rss_articles_placeholder_view.dart` 仅占位提示，无分类 Tab 与菜单动作 | 文章承载页尚未迁移 | 用户无法按 legado 路径切换分类、刷新分类缓存或管理阅读记录 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/article/RssArticlesFragment.kt` + `RssArticlesViewModel.kt` | 列表页支持下拉刷新、触底+手动“继续加载”、`hasMore` 判定、阅读后标记已读 | 订阅入口仍跳转占位页，缺少真实文章列表状态机 | 列表页与分页状态流未迁移 | RSS 文章链路停在占位提示，无法进入稳定阅读闭环 |
| `../legado/app/src/main/java/io/legado/app/data/entities/RssArticle.kt` + `../legado/app/src/main/java/io/legado/app/data/dao/RssArticleDao.kt` | 文章实体持久化并通过 `flowByOriginSort` 与阅读记录表联查回填 `read` 状态 | soupreader 仅有 `RssSourceRecords`，缺少 `RssArticle` 持久层 | 数据层缺失 | 列表刷新/分页与“已读灰显”无法复用持久化状态 |
| `../legado/app/src/main/java/io/legado/app/data/entities/RssReadRecord.kt` + `../legado/app/src/main/java/io/legado/app/data/dao/RssReadRecordDao.kt` + `ReadRecordDialog.kt` | 阅读记录独立存储，支持“查看记录/清空记录”菜单路径 | soupreader 无 RSS 阅读记录模型与入口 | 阅读记录链路未迁移 | 无法对齐 legado 的“阅读记录”可观测与清理语义 |
| `../legado/app/src/main/java/io/legado/app/model/rss/Rss.kt` + `RssParserByRule.kt` + `RssParserDefault.kt` | 文章解析支持“自定义规则优先，规则为空回退默认 RSS XML 解析”；支持 `ruleNextPage=PAGE` 与 `-ruleArticles` 反转语义 | soupreader 尚无 RSS 文章抓取/解析服务 | 解析链路未迁移 | 无法按 legado 规则解析文章列表与下一页 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/read/ReadRssActivity.kt` + `ReadRssViewModel.kt` | 阅读承载支持 `ruleContent` 抓取正文或 URL 直开 WebView；菜单含刷新、收藏、分享、朗读、登录、浏览器打开 | `RssReadPlaceholderView` 仍为占位，无阅读菜单与正文加载状态机 | 阅读页未迁移 | `singleUrl` 的 HTTP 分支缺少真实承载，收藏/分享/朗读入口不可达 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/read/ReadRssActivity.kt` (`shouldInterceptRequest`, `shouldOverrideUrlLoading`) | WebView 支持白名单/黑名单资源拦截与 `shouldOverrideUrlLoading` JS 钩子 | 占位页没有 WebView 链路 | WebView 规则链路未迁移 | 部分 RSS 源依赖注入脚本/拦截规则时无法正常阅读 |
| `../legado/app/src/main/res/menu/main_rss.xml` + `rss_read.xml` | RSS 主链路保留“收藏、阅读记录、排版切换、登录”等可操作菜单 | 当前 RSS 页面仅实现首批筛选与管理动作，收藏与阅读菜单缺失 | A-1 仅迁移首批闭环 | 用户可见入口层级仍低于 legado，扩展链路可操作性不足 |

## 本批次差异点清单（2026-02-19：Phase A-2 Step 2.7 文章列表承载页）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/rss/article/RssSortActivity.kt` + `RssSortViewModel.kt` | 文章入口按 `sortUrls` 动态构建分类 Tab；菜单含 `登录/刷新分类/编辑源/清空/排版切换/阅读记录` | `lib/features/rss/views/rss_subscription_view.dart` 仍跳转 `lib/features/rss/views/rss_articles_placeholder_view.dart` | Step 2.3 仅打通入口，未迁移承载页状态机 | 非 `singleUrl` 场景仍停留占位，无法进入分类文章流 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/article/RssArticlesFragment.kt` | 分类列表支持下拉刷新、触底加载、手动“继续加载”双入口，且 `hasMore` 与加载态联动 | Flutter 侧已有 `lib/features/rss/services/rss_article_sync_service.dart` 与 `rss_article_load_more_helper.dart`，但未接入页面 | 数据层先行落地，UI 状态流尚未串接 | 用户无法触发下一页加载与分页状态可视化 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/article/RssArticlesViewModel.kt` | 点击文章后写入 `RssReadRecord`，列表通过 `flowByOriginSort` 联查回填 `read` 灰显 | `lib/core/database/repositories/rss_article_repository.dart` 已实现联查，但缺少页面消费与点击写回 | 缺少读写闭环的视图层调用 | “阅读后返回灰显”不可见，弱化可观测反馈 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/article/RssArticlesAdapter*.kt` | 三态 `articleStyle` 切换（0/1/2），其中 `2` 为双列网格布局 | `lib/features/rss/services/rss_article_style_helper.dart` 已存在但未用于任何页面 | 排版状态仅停留在 helper | 用户无法按 legado 语义切换 RSS 列表排版 |
| `../legado/app/src/main/java/io/legado/app/ui/rss/article/ReadRecordDialog.kt` | 菜单可查看阅读记录并支持一键清空 | `lib/core/database/repositories/rss_article_repository.dart` 内 `RssReadRecordRepository` 已实现 DAO 语义，但无 RSS 阅读记录入口 | 仅完成数据层，未迁移 UI 承载 | 文章链路缺少“阅读记录”入口，菜单语义不完整 |
| `../legado/app/src/main/res/layout/activity_rss_artivles.xml` + `fragment_rss_articles.xml` | 页面结构为“标题栏 + 分类 Tab + 列表容器”，分类单项时隐藏 Tab | 占位页使用静态信息卡片，无分类容器显隐逻辑 | 占位实现与结构差异过大 | 分类维度不可达，影响多分类源可用性 |

## 实施步骤

### Step 1：扩展能力契约与阶段边界固化（已完成）

- 动作：基于 legado 关键实现梳理扩展模块的入口、状态流与最小可交付单元，落盘本计划。
- 预期结果：扩展迁移从“挂账”变为“可执行分期”。
- 验证方式：本 ExecPlan 文档存在且包含分期步骤、风险与验收路径。

### Step 2：Phase A（RSS）首批迁移（进行中）

- 动作：先落地 RSS 源管理与订阅列表主链路，再补文章详情与阅读页。
- 预期结果：用户可完成“管理 RSS 源 -> 浏览订阅列表 -> 进入文章链路”。
- 验证方式：
  - 定向测试：RSS 源管理筛选/启停/分组
  - 手工路径：设置入口 -> RSS 源管理 -> 订阅列表 -> 文章列表

#### Step 2.1：RSS 源数据模型与持久化（已完成）

- 动作：新增 RSS 源模型与仓储，先对齐 legado 的核心字段与筛选状态流（`all/enabled/disabled/login/noGroup/group:`）。
- 预期结果：RSS 源管理页与订阅页共享同一持久化数据源。
- 验证方式：定向测试覆盖核心筛选语义与读写回写。

#### Step 2.2：RSS 源管理页面首批迁移（已完成）

- 动作：迁移“搜索 + 快捷过滤 + 分组管理 + 单源操作（编辑/删除/启停/置顶置底）”首批能力。
- 预期结果：设置页可进入 RSS 源管理并完成基础维护闭环。
- 验证方式：手工回归“新增/编辑/删除/启停/分组过滤”路径。

#### Step 2.3：订阅列表入口首批迁移（已完成）

- 动作：新增 RSS 订阅列表页，接入启用源列表、`group:` 搜索与 `singleUrl` 打开分支；文章列表页先以占位承接下一阶段。
- 预期结果：用户可从 RSS 源管理进入订阅列表并触发单源打开链路。
- 验证方式：手工回归“订阅列表 -> 打开单源 -> 返回”路径。

#### Step 2.4：Phase A-1 回归与证据补齐（已完成）

- 动作：补齐首批定向测试（筛选 helper + 页面编译）并在 ExecPlan 记录证据。
- 预期结果：首批迁移具备可重复验证结果。
- 验证方式：执行相关 `flutter test` 用例。

#### Step 2.5：Phase A-2 差异清单与边界清单落盘（已完成）

- 动作：完整复核 legado RSS A-2 关键实现（文章列表/阅读承载/实体与 DAO/解析器）并补齐本批次差异点清单。
- 预期结果：A-2 编码前具备“文件位置 + 语义 + 影响”单一基线，满足迁移级别前置约束。
- 验证方式：
  - `sed -n '70,220p' docs/plans/2026-02-19-legado-extension-roadmap-execplan.md`
  - `sed -n '1,220p' ../legado/app/src/main/java/io/legado/app/ui/rss/article/RssSortActivity.kt`
  - `sed -n '1,280p' ../legado/app/src/main/java/io/legado/app/ui/rss/read/ReadRssViewModel.kt`

#### Step 2.6：Phase A-2 数据层与解析层迁移（已完成）

- 动作：迁移 RSS 文章/阅读记录数据模型与仓储，补齐规则解析与默认 XML 解析、分页状态持久化。
- 预期结果：形成可复用的 `文章抓取 -> 入库 -> 流式读取 -> 已读回写` 数据闭环。
- 验证方式：
  - `flutter pub run build_runner build --delete-conflicting-outputs`
  - `flutter test test/rss_default_xml_parser_test.dart`
  - `flutter test test/rss_article_repository_test.dart`
  - `flutter test test/rss_article_sync_service_test.dart`

#### Step 2.7：Phase A-2 文章列表真实承载页迁移（待实施）

- 动作：以 legado `RssSortActivity + RssArticlesFragment` 为基准迁移分类 Tab、列表排版切换、手动继续加载、阅读记录入口。
- 预期结果：订阅入口不再停留占位页，用户可完成“订阅源 -> 分类文章列表 -> 点击阅读”的稳定路径。
- 验证方式：
  - 定向测试覆盖页面编译与关键 helper；
  - 手工回归“切换分类/下拉刷新/继续加载/阅读后回到列表灰显”。

#### Step 2.8：Phase A-2 阅读承载页与收藏入口迁移（待实施）

- 动作：迁移 `ReadRssActivity/ReadRssViewModel` 核心语义（`ruleContent` 优先、URL 回退、WebView 拦截与 JS 钩子、收藏菜单入口）。
- 预期结果：`singleUrl` HTTP 分支进入真实阅读承载，收藏/分享/登录入口可用且状态流可观测。
- 验证方式：
  - 定向测试覆盖 `ruleContent` 与 URL 回退分支；
  - 手工回归“单 URL 源打开 -> 阅读菜单 -> 收藏/分享/浏览器打开”。

### Step 3：Phase B（TTS）朗读主链路（待实施）

- 动作：迁移阅读器 TTS 基础状态机（启动/暂停/恢复/停止、焦点处理、进度同步），并保留服务可观测输出。
- 预期结果：阅读器可稳定语音朗读，朗读状态不破坏现有翻页与进度链路。
- 验证方式：
  - 定向测试：朗读状态机、进度映射、异常恢复
  - 手工路径：阅读器内启动朗读 -> 暂停/恢复 -> 切章延续

### Step 4：Phase C（Dict）词典与规则（待实施）

- 动作：迁移词典查询弹窗与规则管理入口，先支持规则增删改与启停，再补查询链路。
- 预期结果：用户可配置词典规则并在阅读中触发查词。
- 验证方式：
  - 定向测试：规则持久化、启停与排序
  - 手工路径：规则管理 -> 阅读中查词 -> 结果展示

### Step 5：Phase D（Android API）平台接口（待实施）

- 动作：以 Android 平台插件方式承接 Provider 能力，优先覆盖书源/书架读写与目录正文查询接口。
- 预期结果：Android 端具备 legado 同义的外部集成能力；iOS 保持无侵入。
- 验证方式：
  - 平台集成测试：URI 路由与返回结构
  - 手工路径：调用方 App 读写书源/书籍/目录正文

## 风险与回滚

### 失败模式

1. 扩展功能实现与核心链路共享状态耦合，导致已对齐语义回退。
2. TTS 与 Android 平台能力差异导致跨平台实现分叉。
3. Android API 插件若缺少统一异常语义，调用方兼容成本过高。

### 阻塞条件

1. 扩展阶段与核心迁移并行时，出现同文件/同逻辑区块冲突。
2. Android 侧缺少可用的 Provider/Plugin 桥接能力验证环境。

### 回滚策略

1. 扩展功能使用独立入口开关，必要时可按模块回滚，不影响核心链路。
2. 平台接口分阶段发布：先只读，再读写；异常时回退到只读能力。

## 验收与证据

### 命令验证

- 代码生成与定向测试（Phase A-1 Step 2.1）：
  - `flutter pub run build_runner build --delete-conflicting-outputs`
  - `flutter test test/rss_source_filter_helper_test.dart`
  - `flutter test test/rss_source_repository_test.dart`
  - `flutter test test/repository_write_read_consistency_test.dart`
- 定向测试（Phase A-1 Step 2.2）：
  - `flutter test test/rss_source_manage_helper_test.dart`
  - `flutter test test/rss_source_manage_view_compile_test.dart`
  - `flutter test test/rss_source_filter_helper_test.dart`
  - `flutter test test/rss_source_repository_test.dart`
- 定向测试（Phase A-1 Step 2.3 / 2.4）：
  - `flutter test test/rss_subscription_helper_test.dart`
  - `flutter test test/rss_subscription_view_compile_test.dart`
  - `flutter test test/rss_source_manage_view_compile_test.dart`
- 计划文档校验（Phase A-2 Step 2.5）：
  - `sed -n '70,220p' docs/plans/2026-02-19-legado-extension-roadmap-execplan.md`
  - `sed -n '1,220p' ../legado/app/src/main/java/io/legado/app/ui/rss/article/RssSortActivity.kt`
  - `sed -n '1,280p' ../legado/app/src/main/java/io/legado/app/ui/rss/read/ReadRssViewModel.kt`
- 定向测试（Phase A-2 Step 2.6）：
  - `flutter pub run build_runner build --delete-conflicting-outputs`
  - `flutter test test/rss_default_xml_parser_test.dart`
  - `flutter test test/rss_article_repository_test.dart`
  - `flutter test test/rss_article_sync_service_test.dart`
- 计划文档与索引检查：
  - `sed -n '1,320p' docs/plans/2026-02-19-legado-extension-roadmap-execplan.md`
  - `sed -n '1,120p' PLANS.md`
- 迁移规则约束：`flutter analyze` 仅在提交推送前执行一次（本阶段不执行）。

### 手工回归路径

1. 打开 `PLANS.md`，确认新增扩展计划索引与状态。
2. 打开本计划文档，确认四个扩展模块均有分期步骤与验收路径。
3. 在设置/阅读入口确认现有扩展占位文案仍保持“扩展阶段”语义，不误报已实现。

### 预期输出

- 扩展能力迁移具备可执行路线图，可按阶段串行推进。
- 每个阶段均具备可复现验收方式，避免“只改代码不留证据”。

## Progress

- [x] 2026-02-19：完成扩展能力分期计划落盘与索引接入。
  - 做了什么：新增本 ExecPlan，并在 `PLANS.md` 增加活跃计划索引。
  - 为什么：将扩展能力从“挂账”推进到“可执行分期”，避免后续迭代缺少统一基线。
  - 如何验证：
    - `sed -n '1,220p' docs/plans/2026-02-19-legado-extension-roadmap-execplan.md`
    - `sed -n '1,120p' PLANS.md`
  - 兼容影响：仅文档层改动，不影响现有运行时行为。

- [x] 2026-02-19：完成 Phase A（RSS）首批差异点细化（对照 legado 代码）。
  - 做了什么：完整复核 RSS 关键实现（`RssFragment/RssViewModel/RssAdapter/RssSourceActivity/RssSourceViewModel/RssSourceAdapter/GroupManageDialog/RssSourceDao/RssSource`）并输出本批次差异点清单。
  - 为什么：满足迁移级别“实现前先落盘差异清单”要求，避免未对齐 legacy 语义就编码。
  - 如何验证：
    - `sed -n '1,320p' docs/plans/2026-02-19-legado-extension-roadmap-execplan.md`
    - `sed -n '1,260p' ../legado/app/src/main/java/io/legado/app/ui/main/rss/RssFragment.kt`
    - `sed -n '1,520p' ../legado/app/src/main/java/io/legado/app/ui/rss/source/manage/RssSourceActivity.kt`
  - 兼容影响：仅计划文档更新，不影响运行时行为。

- [x] 2026-02-19：完成 Phase A-1 Step 2.1（RSS 源数据模型与持久化）首批落地。
  - 做了什么：
    - 新增 `lib/features/rss/models/rss_source.dart`，对齐 legado `RssSource` 核心字段、JSON 解析与分组辅助能力；
    - 新增 `lib/features/rss/services/rss_source_filter_helper.dart`，复刻 DAO 侧筛选语义（`all/enabled/disabled/login/noGroup/group:`）与分组拆分排序；
    - 新增 `lib/core/database/repositories/rss_source_repository.dart`，提供 `flowAll/flowSearch/flowGroupSearch/flowEnabled/flowDisabled/flowLogin/flowNoGroup/flowEnabledByGroup/flowGroups/flowEnabledGroups` 等同义接口，并支持 `rawJson` 回写；
    - drift 新增 `RssSourceRecords` 表并升级 schema（`source_drift_database.dart` + `source_drift_database.g.dart` + `source_drift_service.dart`），启动链路补齐 `RssSourceRepository.bootstrap`（`lib/main.dart`）。
  - 为什么：先完成 Phase A-1 的数据层基座，确保后续“RSS 源管理页/订阅列表页”可以直接复用同一持久化与筛选状态流，避免 UI 先行导致语义漂移。
  - 如何验证：
    - `flutter pub run build_runner build --delete-conflicting-outputs`
    - `flutter test test/rss_source_filter_helper_test.dart`
    - `flutter test test/rss_source_repository_test.dart`
    - `flutter test test/repository_write_read_consistency_test.dart`
  - 兼容影响：
    - 仅新增 RSS 专用数据表与仓储，不影响现有书源/书架/阅读主链路；
    - `DatabaseService.clearAll` 现会额外清空 `rssSourceRecords`；
    - 启动阶段新增 RSS 仓储 bootstrap，不改变其它仓储初始化顺序语义。

- [x] 2026-02-19：完成 Phase A-1 Step 2.2（RSS 源管理页面首批迁移）。
  - 做了什么：
    - 新增 `lib/features/rss/views/rss_source_manage_view.dart`，接入 `RssSourceRepository.watchAllSources` + `RssSourceManageHelper.parse/applyQueryIntent`，实现 `all/enabled/disabled/login/noGroup/group:/keyword` 查询态；
    - 新增 `lib/features/rss/views/rss_group_manage_view.dart`，实现分组新增/重命名/删除，并复刻 `addGroup` 对“无分组源”的批量分配副作用；
    - 设置入口打通：`lib/features/settings/views/settings_view.dart` 与 `lib/features/settings/views/source_management_view.dart` 的“订阅管理”改为直达 RSS 源管理页；
    - 单源操作补齐：编辑、删除、启停、置顶、置底。
  - 为什么：Phase A-1 需要先完成“可进入、可筛选、可维护”的 RSS 管理闭环，才能进入 Step 2.3 的订阅列表入口迁移。
  - 如何验证：
    - `flutter test test/rss_source_manage_helper_test.dart`
    - `flutter test test/rss_source_manage_view_compile_test.dart`
    - `flutter test test/rss_source_filter_helper_test.dart`
    - `flutter test test/rss_source_repository_test.dart`
  - 兼容影响：
    - 仅影响“订阅管理”入口与 RSS 管理页，不改动书源管理、搜索、阅读主链路；
    - 仍未迁移 RSS 导入/导出与订阅列表展示，留待 Step 2.3/2.4 继续收敛。

- [x] 2026-02-19：完成 Phase A-1 Step 2.3（RSS 订阅列表入口首批迁移）。
  - 做了什么：
    - 新增 `lib/features/rss/services/rss_subscription_helper.dart`，复刻 `RssFragment.upRssFlowJob` 的启用源筛选语义（默认 `flowEnabled`、`group:` 前缀走分组筛选、其余关键字走启用源搜索）；
    - 新增 `lib/features/rss/views/rss_subscription_view.dart`，落地订阅列表页（启用源列表、`group:` 搜索、动态分组筛选、长按动作 `置顶/编辑/禁用/删除`）；
    - 新增 `lib/features/rss/views/rss_articles_placeholder_view.dart`，承接非 `singleUrl` 的文章列表下一跳与 `singleUrl` 的阅读承接占位；
    - 在 `lib/features/rss/views/rss_source_manage_view.dart` 增加“进入订阅列表”入口按钮，完成“管理 -> 订阅”链路闭环。
  - 为什么：Step 2.3 要求用户能从 RSS 管理页进入订阅列表，并打通 `singleUrl` 与非 `singleUrl` 的打开分支，否则 Phase A-1 主链路仍中断。
  - 如何验证：
    - `flutter test test/rss_subscription_helper_test.dart`
    - `flutter test test/rss_subscription_view_compile_test.dart`
    - `flutter test test/rss_source_manage_view_compile_test.dart`
  - 兼容影响：
    - 仅新增 RSS 扩展路径页面与 helper，不影响书源管理、搜索、阅读主链路；
    - `singleUrl` 的 HTTP 目标暂由占位页承接（下一阶段迁移真实阅读页），但分支判定语义已对齐 legado。

- [x] 2026-02-19：完成 Phase A-1 Step 2.4（首批回归与证据补齐）。
  - 做了什么：
    - 新增 `test/rss_subscription_helper_test.dart`，覆盖启用源筛选、`group:` 查询、`singleUrl(@js:/<js>/::)` 分支、外链分支与错误分支；
    - 新增 `test/rss_subscription_view_compile_test.dart`，覆盖订阅列表与占位页编译链路；
    - 回归 `test/rss_source_manage_view_compile_test.dart`，确保管理页新增入口后仍可编译。
  - 为什么：Step 2.4 要求对 Step 2.3 的首批迁移提供可重复执行证据，防止后续迭代回退入口语义。
  - 如何验证：
    - `flutter test test/rss_subscription_helper_test.dart`
    - `flutter test test/rss_subscription_view_compile_test.dart`
    - `flutter test test/rss_source_manage_view_compile_test.dart`
  - 兼容影响：仅新增/扩展 RSS 定向测试，不影响运行时行为。

- [x] 2026-02-19：完成 Phase A-2 Step 2.5（差异清单与边界清单落盘）。
  - 做了什么：
    - 完整复核 legado A-2 关键文件：`RssSortActivity/RssSortViewModel/RssArticlesFragment/RssArticlesViewModel/Rss.kt/RssParserByRule/RssParserDefault/ReadRssActivity/ReadRssViewModel/RssArticleDao/RssReadRecordDao`；
    - 在本计划新增“Phase A-2 RSS 文章列表与阅读承载”差异点清单，明确数据层、解析层、页面层与菜单层缺口；
    - 将 Phase A 拆分为 Step 2.6~2.8（数据解析 -> 文章列表 -> 阅读承载）可执行子阶段。
  - 为什么：迁移级别任务在实现前必须先有差异清单；A-2 涉及跨层改动（仓储/服务/UI），需要先固定边界与依赖。
  - 如何验证：
    - `sed -n '70,220p' docs/plans/2026-02-19-legado-extension-roadmap-execplan.md`
    - `sed -n '1,220p' ../legado/app/src/main/java/io/legado/app/ui/rss/article/RssSortActivity.kt`
    - `sed -n '1,280p' ../legado/app/src/main/java/io/legado/app/ui/rss/read/ReadRssViewModel.kt`
  - 兼容影响：仅更新 ExecPlan 文档，不影响当前运行时行为。

- [x] 2026-02-19：完成 Phase A-2 Step 2.6（RSS 数据层与解析层迁移）。
  - 做了什么：
    - 新增 `RssArticle/RssReadRecord` 模型与 drift 表（`rss_article_records`、`rss_read_record_records`），并升级 schema/migration；
    - 新增 `RssArticleRepository` 与 `RssReadRecordRepository`，补齐 `get/flowByOriginSort/insert/append/clearOld/getRecords/count/deleteAll`；
    - 新增 `RssDefaultXmlParser`，对齐 legado `RssParserDefault` 的默认 XML 解析与图片回退语义；
    - 新增 `RssArticleFetchService + RssArticleSyncService`，补齐“规则解析优先 + 默认 XML 回退 + PAGE/nextPage 解析 + 首尾重复停止翻页”的状态流。
  - 为什么：Phase A-2 进入 UI 承载迁移前，必须先完成文章抓取、入库、读取、阅读记录回填的可复用底座，避免页面层重复堆叠解析逻辑。
  - 如何验证：
    - `flutter pub run build_runner build --delete-conflicting-outputs`
    - `flutter test test/rss_default_xml_parser_test.dart`
    - `flutter test test/rss_article_repository_test.dart`
    - `flutter test test/rss_article_sync_service_test.dart`
  - 兼容影响：
    - RSS 新增两张专用表，`DatabaseService.clearAll` 会同步清空文章与阅读记录；
    - 当前阶段 `RssArticle.variable` 仍未从规则引擎回填（保留到 Step 2.8 与阅读承载联动时补齐），不影响 A-2 Step 2.6 的列表/分页闭环。

## 本批次逐项对照清单（2026-02-19：Phase A-1 Step 2.1 RSS 数据模型与持久化）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| RSS 源实体核心字段 | `RssSource.kt` 含 `sourceUrl/sourceName/sourceGroup/sourceComment/enabled/loginUrl/sortUrl/singleUrl/customOrder` 等核心字段 | `RssSource` 模型完成同字段映射，支持 JSON 读写与默认值兼容 | 已同义 |
| 筛选状态流 | `RssSourceDao` 提供 `flowAll/flowEnabled/flowDisabled/flowLogin/flowNoGroup/flowGroupSearch/flowSearch` | `RssSourceRepository` 暴露对应 `flow*` 接口，筛选逻辑由 `RssSourceFilterHelper` 统一复刻 | 已同义 |
| 分组边界匹配 | `flowGroupSearch/flowEnabledByGroup` 使用逗号分组边界匹配，不是简单 contains | helper 采用分组拆分后精确项匹配，避免 `新玄幻派` 命中 `玄幻` | 已同义 |
| 分组聚合与排序 | DAO `dealGroups`：拆分、去重、`cnCompare` 排序 | helper 实现拆分去重 + `cnCompareLikeLegado` 排序 | 已同义 |
| 持久化与缓存 | DAO 基于表 `rssSources`，支持读写与回写 | drift 新增 `RssSourceRecords`，仓储支持增删改查、流式监听与 `rawJson` 回写 | 已同义 |
| 运行时接入 | RSS DAO 可被管理页/订阅页复用 | 启动阶段新增 `RssSourceRepository.bootstrap`，为后续页面直接复用提供缓存基线 | 已同义 |

## 本批次逐项对照清单（2026-02-19：Phase A-1 Step 2.2 RSS 源管理页面）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 设置入口层级 | `RssSourceActivity` 可从设置链路直达 | “订阅管理”入口改为直达 `RssSourceManageView` | 已同义 |
| 搜索与快捷筛选状态流 | `upSourceFlow` 支持 `all/enabled/disabled/login/noGroup/group:/search` | `RssSourceManageHelper.parse/applyQueryIntent` + 搜索框复刻同序状态流 | 已同义 |
| 动态分组筛选 | 菜单分组来自 `flowGroups`，可回填 `group:xxx` | 筛选弹层从 `flowGroups/allGroups` 生成动态分组，点击写入 `group:xxx` | 已同义 |
| 分组管理副作用 | `addGroup` 会把新分组写入“无分组源” | `RssGroupManageView` 新增分组调用 `addGroupToNoGroupSources` 批量回写 | 已同义 |
| 单源维护动作 | 适配器提供启停、编辑、置顶、置底、删除 | 管理页列表补齐启停开关与动作菜单（编辑/置顶/置底/删除） | 已同义 |

## 本批次逐项对照清单（2026-02-19：Phase A-1 Step 2.3 RSS 订阅列表入口）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 订阅列表默认数据流 | `RssFragment.upRssFlowJob`：空查询走 `flowEnabled` | `RssSubscriptionHelper.filterEnabledSourcesByQuery` 空查询走启用源筛选 | 已同义 |
| `group:` 查询语义 | `upRssFlowJob`：`group:` 前缀走 `flowEnabledByGroup` | helper 识别 `group:` 并按分组 token 精确筛选启用源 | 已同义 |
| 关键字查询语义 | 非 `group:` 查询走 `flowEnabled(searchKey)` | helper 非 `group:` 分支按名称/分组/URL/备注筛选启用源 | 已同义 |
| 长按动作集合 | `RssAdapter + rss_main_item.xml`：`置顶/编辑/禁用/删除` | 订阅列表长按动作收敛为 `置顶/编辑/禁用/删除` | 已同义 |
| `singleUrl` 打开分支 | `openRss + getSingleUrl`：解析 `sortUrl/sourceUrl`（含 `@js:`/`<js>` 与 `::`）后区分内置阅读/外部打开 | `RssSubscriptionHelper.resolveSingleUrl/decideOpenAction` 复刻同序分支；HTTP 目标进入阅读占位页、非 HTTP 走外部打开 | 已同义（阅读承载页为阶段占位） |
| 非 `singleUrl` 下一跳 | `openRss` 非 `singleUrl` 进入 `RssSortActivity(url=sourceUrl)` | 非 `singleUrl` 进入 `RssArticlesPlaceholderView(sourceUrl)` 承接后续 Phase A-2 | 已同义（内容页为阶段占位） |
| 管理 -> 订阅入口 | 用户可从 RSS 管理链路进入订阅列表 | `RssSourceManageView` 增加订阅入口按钮并复用同仓储实例跳转 | 已同义 |

## 本批次逐项对照清单（2026-02-19：Phase A-1 Step 2.4 回归与证据）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 筛选状态机可回归 | `RssFragment.upRssFlowJob` 分支行为可被重复验证 | `rss_subscription_helper_test.dart` 覆盖空查询/`group:`/关键字三分支 | 已同义 |
| `singleUrl` 分支可回归 | `getSingleUrl` 的 `::` 与脚本分支有确定行为 | `rss_subscription_helper_test.dart` 覆盖 `::`、`@js:`、错误分支、外链分支 | 已同义 |
| 页面编译防线 | 入口页面需保证可编译 | `rss_subscription_view_compile_test.dart` + `rss_source_manage_view_compile_test.dart` 已覆盖 | 已同义 |

## 本批次逐项对照清单（2026-02-19：Phase A-2 Step 2.5 差异清单落盘）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| A-2 关键文件复核范围 | 覆盖 `ui/rss/article/*`、`ui/rss/read/*`、`model/rss/*`、`RssArticleDao/RssReadRecordDao` | 已完成逐文件复核并记录语义差异 | 已同义（文档基线） |
| 差异清单完整性 | 需包含文件位置、差异原因、影响范围 | 已新增“Phase A-2 RSS 文章列表与阅读承载”差异点清单并覆盖数据/解析/UI/菜单层 | 已同义（文档基线） |
| 实施步骤可执行性 | 复杂迁移需拆分为可串行阶段并标注验证方式 | 已拆分 Step 2.6/2.7/2.8，明确依赖与验收口径 | 已同义（文档基线） |

## 本批次逐项对照清单（2026-02-19：Phase A-2 Step 2.6 数据层与解析层迁移）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| RSS 文章实体与主键 | `RssArticle(origin, link)` 复合主键，含 `sort/title/order/pubDate/description/content/image/group/read/variable` | 新增 `RssArticle` 模型与 drift `rss_article_records`（复合主键 `origin+link`），字段对齐 | 已同义（列表闭环） |
| 阅读记录实体与主键 | `RssReadRecord(record)` 主键，支持 `title/readTime/read` | 新增 `RssReadRecord` 模型与 drift `rss_read_record_records`（主键 `record`） | 已同义 |
| 列表读取 join 语义 | `flowByOriginSort` 通过 `LEFT JOIN rssReadRecords` 回填 `read` 并按 `order desc` | `RssArticleRepository.flowByOriginSort` 使用 SQL left join 回填 `read`，按 `order_value desc` 排序 | 已同义 |
| 写入策略 | `insert(REPLACE)`、`append(IGNORE)`、`clearOld(origin,sort,order)` | `insertAllOnConflictUpdate` + `insertOrIgnore` + `clearOld` 条件删除 | 已同义 |
| 默认 XML 解析 | `ruleArticles` 为空时走 `RssParserDefault`，支持 `media:thumbnail/enclosure/description/content:encoded` 图片回退 | 新增 `RssDefaultXmlParser`，按 item 分段解析并复刻图片回退优先级 | 已同义 |
| nextPage 语义 | `ruleNextPage=PAGE` 返回当前 sortUrl；其他规则解析后按 `sortUrl` 补绝对地址 | `RssArticleFetchService` 对齐 `PAGE` 常量与规则分支，nextUrl 统一按 `sortUrl` 绝对化 | 已同义 |
| loadMore 停止语义 | `loadMoreSuccess`：若“首条和末条”均已存在则停止继续加载 | `RssArticleSyncService.loadMore` 复刻首尾重复判定并置 `hasMore=false` | 已同义 |
| variable 回填 | `RssParserByRule` 通过 `RuleData` 回填 `RssArticle.variable` | 当前规则分支复用 `SearchDebugResult`，暂未回填 `variable` | 保留差异（Step 2.8 回补） |

## Surprises & Discoveries

1. soupreader 当前不存在 `lib/features/rss`、`lib/features/dict`、`lib/features/tts` 目录，扩展能力尚无代码骨架。
2. TTS 在 soupreader 现阶段仅保留阅读器入口提示，尚未建立服务态与系统焦点联动。
3. legado 的 Android API 通过 `ReaderProvider + controller` 输出跨应用能力，Flutter 侧需额外平台桥接设计。
4. `RssSourceDao.flowGroupSearch/flowEnabledByGroup` 使用“逗号分组字段”的边界匹配语义（精确项，不是简单 contains），需要单独 helper 复刻。
5. `GroupManageDialog.addGroup` 会把新分组直接分配给“无分组源”，不是只维护分组字典，需要同步迁移该副作用。
6. `RssFragment.openRss` 的 `singleUrl` 分支依赖 `sortUrl/sourceUrl` 解析策略，若缺失会导致单 URL 订阅源无法打开。
7. 由于 RSS 源持久化接入 drift，新表落地必须同步更新 `schemaVersion` 与生成文件；否则仓储代码会在编译阶段缺失 `RssSourceRecord` 类型。
8. `flutter_js` 的执行结果在部分场景会返回带引号字符串，`singleUrl` 脚本分支需要先做 JSON 字符串解包，避免把引号带入 URL。
9. `RssFragment` 菜单中的“收藏”在当前阶段尚未迁移；若直接暴露占位入口会产生“可见但不可用”的偏差，因此 Step 2.3 先保留已落地能力入口并在后续阶段补齐。
10. `RssArticleDao.flowByOriginSort` 使用 `rssArticles LEFT JOIN rssReadRecords` 回填 `read` 字段，本地若只在文章表维护布尔值会与 legado 的记录链路脱节。
11. `RssArticlesViewModel.loadMoreSuccess` 通过“首条和末条是否都已存在”判定分页终止，避免重复翻页；该去重停止语义需要单独回归。
12. `ReadRssActivity` 的 WebView 链路不仅是展示页面，还承载黑白名单拦截、`shouldOverrideUrlLoading` JS 钩子与导入协议处理，不能仅用纯文本页替代。
13. `package:html` 的 `getElementsByTagName('media:thumbnail')` 会被按伪类解析并抛异常；默认 XML 解析需按原始 XML 文本分段处理命名空间标签。
14. `SearchDebugResult` 当前不暴露规则执行中的变量态，`RssArticle.variable` 在规则分支无法直接回填，需要在阅读承载阶段补齐。

## Decision Log

1. 扩展能力按 `RSS -> TTS -> Dict -> Android API` 顺序推进，优先保证用户可感知能力闭环。
2. Android API 仅在 Android 阶段实现，iOS 不引入等价空实现入口，避免误导。
3. 扩展阶段继续遵循迁移级别：入口层级、状态流、错误语义与 legado 同义。
4. Phase A-1 先交付“RSS 源管理 + 订阅列表入口 + singleUrl 打开分支”，文章详情/阅读页延后到下一批次，避免一次性跨越过大导致回归范围失控。
5. RSS 源管理首批不引入 legado 之外的新入口，先按 legacy 菜单结构收敛核心动作（新增/编辑/删除/启停/分组/置顶置底）。
6. RSS 数据层采用“关键筛选字段列 + `rawJson` 全量回写”策略：既保证 DAO 级筛选可直接查询，也保留后续扩展字段兼容空间，避免重复迁移表结构。
7. RSS 源管理视图采用“搜索字符串 + helper 解析”单状态方案，保证快捷筛选、搜索框与动态分组入口共用同一查询语义，避免多入口状态漂移。
8. `singleUrl` 解析抽到 `RssSubscriptionHelper` 单点实现，统一处理 `@js:`/`<js>`、`::` 分支和打开目标决策，避免页面层重复实现造成语义漂移。
9. Phase A-1 对“非 `singleUrl` 文章列表”和“`singleUrl` HTTP 阅读承载”使用占位页承接，但保持入口参数与分支判定同义，确保下一阶段可无缝替换承载实现。
10. Phase A-2 先落盘差异与边界，再实施跨层改造，避免在缺少基线时直接迁移导致语义偏航。
11. Phase A-2 执行顺序固定为“数据解析层 -> 文章列表页 -> 阅读承载页”，保证上层页面始终依赖稳定的数据与解析结果。
12. 阅读承载页优先对齐 legado 菜单与状态流（刷新/收藏/分享/登录/浏览器打开），暂不提前引入 legado 外扩展入口。
13. 规则解析分支优先复用 `RuleParserEngine.searchDebug/getBookInfoDebug`，以继承既有 URL 选项、请求头、编码与 JS 规则语义，避免在 RSS 模块重复实现 DSL 解释器。
14. 默认 XML 解析改为“raw item 分段 + 标签正则抽取”，避免 HTML 选择器在命名空间标签场景的兼容性偏差。

## Outcomes & Retrospective

- 当前结果：扩展能力已从“挂账描述”升级为可执行分期计划，并完成 Phase A-1 Step 2.1（RSS 数据模型与持久化）+ Step 2.2（RSS 源管理页面首批迁移）+ Step 2.3（订阅列表入口首批迁移）+ Step 2.4（首批回归与证据补齐）+ Step 2.5（A-2 差异清单落盘）+ Step 2.6（A-2 数据层与解析层迁移），已具备“订阅源 -> 抓取解析 -> 入库 -> 已读回填 -> 分页去重停止”的可复用底座。
- 下一步改进：
  1. 进入 Step 2.7：迁移 RSS 文章列表真实承载页（分类 Tab、翻页、阅读记录）替换占位页。
  2. 进入 Step 2.8：迁移 `singleUrl` 真实阅读承载页与收藏入口，补齐阅读菜单语义。
  3. 在 Step 2.8 中回补 `RssArticle.variable` 的规则变量透传语义，完成阅读页与规则变量链路闭环。
