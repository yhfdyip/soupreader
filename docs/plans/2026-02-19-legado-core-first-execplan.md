# Legado -> SoupReader 核心优先迁移（iOS 优先）

- 状态：`active`
- 基线：`../legado` 当前 `HEAD`
- 更新时间：2026-02-19

## 背景与目标

### 背景

`soupreader` 已完成书源、阅读、书架、设置等基础能力，但仍存在 legado 全量迁移差异，且部分入口显示“暂未实现”。用户已明确新的执行口径：

1. 优先完成核心功能同义迁移。
2. 扩展功能先记录，后续再迭代完成。
3. 仿真翻页保留当前 Shader 实现，不替换技术路径。

### 目标

1. 核心阅读链路达到迁移级别：`search/explore/bookInfo/toc/content` 可用且可调试。
2. 核心阅读体验可用：书架 -> 阅读全链路，含翻页、进度、替换净化。
3. 将扩展能力（RSS/TTS/字典/Android 专属）挂账，形成后续可执行计划。
4. 建立“Shader 保留”回归防线，避免后续改动误删仿真能力。

### 范围

- 核心范围：五段链路、书源管理、书架加书、阅读器主功能、替换净化、核心设置。
- 扩展范围：RSS、TTS、字典规则、Android 专属 API/Service 等。

### 非目标

- 本阶段不完成 Android 专属能力等价复刻（记录为 `blocked`/`pending`）。
- 不在本阶段引入与 legado 无关的新产品功能。

### 成功标准

1. 核心链路具备可复现验证证据（测试与手工路径）。
2. 扩展能力有明确台账（原因、影响、替代、回补）。
3. 仿真翻页 Shader 路径有自动化守护测试。

## 差异点清单（核心+扩展）

| 模块 | legado 对应 | soupreader 当前 | 差异原因 | 影响 |
|---|---|---|---|---|
| RSS/订阅 | `ui/main/rss`, `ui/rss/*`, `RssSource.kt` 等 | 无 `features/rss` | 尚未迁移 | 扩展阅读场景缺失 |
| TTS/朗读 | `TTSReadAloudService.kt` 等 | 设置与阅读器存在“暂未实现”入口 | 尚未迁移 | 无语音阅读 |
| 字典规则 | `ui/dict/*`, `DictRule.kt` | 无对应模块 | 尚未迁移 | 无词典能力 |
| Android API | `api/controller/*`, `ReaderProvider.kt` | 无等价层 | 平台专属 | 跨应用集成缺失 |
| 简繁转换 | legado 支持繁简转换 | 阅读器中为 TODO 占位 | 实现缺失 | 繁体显示无效（核心） |
| 仿真翻页守护 | legado 仿真能力稳定 | 有 Shader 实现，缺回归守护 | 测试缺失 | 后续改动存在误删风险 |

## 本批次差异点清单（2026-02-19：简繁三态）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/help/config/AppConfig.kt` | `chineseConverterType` 三态（0/1/2） | `lib/features/reader/models/reading_settings.dart` 为 `chineseTraditional:bool` | 数据模型未迁移 | 缺少“繁转简”能力 |
| `../legado/app/src/main/java/io/legado/app/help/book/ContentProcessor.kt` | 正文按三态转换 | `lib/features/reader/views/simple_reader_view.dart` 仅支持“简转繁” | 转换器仅实现单向 | 书源正文在繁体场景下不可一键转简 |
| `../legado/app/src/main/java/io/legado/app/data/entities/BookChapter.kt` | 标题按三态转换 | 标题不参与简繁转换 | 标题处理链路未接入 | 标题/正文语义不一致 |
| `../legado/app/src/main/java/io/legado/app/ui/book/read/config/ChineseConverter.kt` | UI 入口为三态选择 | 多处为开关（阅读器/设置） | 交互口径未对齐 | 用户无法显式选择转换方向 |
| `../legado/app/src/main/java/io/legado/app/utils/ChineseUtils.kt` | T2S 含 `fixT2sDict` 例外词 | 无 T2S 例外词处理 | 复刻不完整 | 特定词条存在误转风险 |

## 本批次差异点清单（2026-02-19：目录标题展示链路）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/toc/ChapterListAdapter.kt` | 目录标题经 `getDisplayTitle` 处理后展示 | `lib/features/search/views/search_book_info_view.dart` 直接展示 `TocItem.name` | 缺少目录标题展示处理层 | 简繁转换开启后目录弹窗仍显示原始字形 |
| `../legado/app/src/main/java/io/legado/app/data/entities/BookChapter.kt` | 标题链路含“去换行 + 简繁转换 + 替换规则” | 搜索详情目录未接入阅读设置与替换规则 | 标题处理能力未复用到 bookInfo -> toc 入口 | 目录搜索命中与阅读器标题语义不一致 |

## 本批次差异点清单（2026-02-19：阅读器目录弹窗标题链路）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/toc/ChapterListAdapter.kt` | 阅读器目录列表通过 `getDisplayTitle` 渲染展示标题 | `lib/features/reader/widgets/reader_catalog_sheet.dart` 直接展示 `chapter.title` | 目录弹窗未接入标题展示处理层 | 阅读器目录与 legado 在简繁/替换规则开启时存在字形偏差 |
| `../legado/app/src/main/java/io/legado/app/data/entities/BookChapter.kt` | 标题链路为“去换行 -> 简繁转换 -> 标题替换规则” | `lib/features/reader/views/simple_reader_view.dart` 打开目录时仅传原始章节列表 | 入口未提供 display title 上下文 | 阅读器目录可见语义落后于已对齐的 `bookInfo -> toc` 入口 |

## 本批次差异点清单（2026-02-19：书源调试 key 判定顺序）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/model/Debug.kt` | key 判定顺序：`absUrl -> contains("::") -> ++ -> -- -> keyword` | `lib/features/source/services/source_debug_key_parser.dart` 为 `absUrl -> ++ -> -- -> contains("::") -> keyword` | 解析器判定顺序未完全复刻 | `SourceDebugOrchestrator` 的 intent 标签/摘要可能与 `RuleParserEngine.debugRun` 实际链路不一致（如 `++系统::url`） |

## 本批次差异点清单（2026-02-19：换源章节定位）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/help/book/BookHelp.kt` | `getDurChapter` 使用“候选窗口 + 章节号提取 + 标题相似度 + 回退索引”综合定位 | `lib/features/reader/services/reader_source_switch_helper.dart` 仅做标题归一后的全量匹配/包含匹配 | 章节定位算法未迁移 | 换源后章节可能跳错，尤其在目录结构变化或标题轻微变动时 |
| `../legado/app/src/main/java/io/legado/app/help/book/BookHelp.kt` | 候选窗口依赖旧目录总章数（`oldChapterListSize`）与当前索引共同估算 | `resolveTargetChapterIndex` 无“旧目录总章数”输入 | 定位上下文缺参 | 旧新目录长度差异较大时，定位窗口可能偏离 legado 语义 |
| `../legado/app/src/main/java/io/legado/app/data/entities/Book.kt` | `durChapterTitle` 由阅读进度链路维护并用于换源定位 | `lib/features/reader/views/simple_reader_view.dart` 换源定位使用 `_currentTitle`（显示标题） | 调用参数语义混用（展示标题 vs 章节原始标题） | 简繁转换/替换规则开启时，换源定位命中率下降 |

## 本批次差异点清单（2026-02-19：18+ 域名主域提取）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/help/source/SourceHelp.kt` | 导入拦截使用 `is18Plus` + 主域匹配（eTLD+1） | `lib/features/source/services/source_import_commit_service.dart` 按“最后两段”提取主域 | 主域提取策略未对齐 | `.co.uk/.com.cn` 等多段后缀域名可能漏拦截 |
| `../legado/app/src/main/java/io/legado/app/utils/NetworkUtils.kt` | `getSubDomain` 基于 `PublicSuffixDatabase.getEffectiveTldPlusOne` | `_extractSecondLevelDomain` 未复用主域分组能力 | 复刻不完整 | 导入阶段 18+ 域名判断语义与 legado 不同 |

## 本批次差异点清单（2026-02-19：清 Cookie 主域作用域）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/source/edit/BookSourceEditViewModel.kt` | 编辑页“清 Cookie”调用 `CookieStore.removeCookie(url)` | `lib/features/source/views/source_edit_view.dart` / `lib/features/source/views/source_edit_legacy_view.dart` 仅按书源 URL 作用域清理 | 清理候选缺少主域作用域 | 子域书源在主域（eTLD+1）Cookie 留存时，清理后仍可能复用旧会话 |
| `../legado/app/src/main/java/io/legado/app/help/http/CookieStore.kt` + `../legado/app/src/main/java/io/legado/app/utils/NetworkUtils.kt` | `removeCookie` 基于 `getSubDomain`（eTLD+1）删除 Cookie 记录 | `SourceCookieScopeResolver.resolveCandidates` 未包含主域候选 | 复刻不完整 | `.co.uk/.com.cn` 等多段后缀域名下清理口径与 legado 不一致 |

## 本批次差异点清单（2026-02-19：滚动偏移回退与书架排序可变性）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/model/ReadBook.kt` | 阅读进度持久化在 `Book.durChapterPos` 单值字段，读取链路天然具备“统一回退值”语义 | `lib/core/services/settings_service.dart` 的 `getScrollOffset(chapterIndex)` 仅查章节键，不回退书籍键；章节写入也未同步书籍键 | 章节级偏移存储迁移时遗漏兼容回退语义 | 章节未命中时返回 `0.0`，导致滚动恢复与旧键兼容行为偏离 |
| `../legado/app/src/main/java/io/legado/app/ui/main/bookshelf/style2/BookshelfFragment2.kt` + `../legado/app/src/main/java/io/legado/app/ui/main/bookshelf/style1/books/BooksFragment.kt` | 书架排序使用 `sortedBy/sortedWith` 返回新列表，不对上游列表原地修改 | `lib/features/bookshelf/views/bookshelf_view.dart` 在 `_loadBooks()` 中直接对 `_bookRepo.getAllBooks()` 结果执行原地 `sort` | 本地实现假设仓储返回列表恒为可变 | 当仓储返回不可变列表时触发 `Unsupported operation: Cannot modify an unmodifiable list`，书架初始化失败 |

## 本批次差异点清单（2026-02-19：搜索输入帮助链路）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` (`upHistory`) | 输入关键字时同步展示“书架匹配 + 历史词过滤” | `lib/features/search/views/search_view.dart` 仅展示历史词卡片，无书架匹配区块 | 输入帮助链路未完整迁移 | 用户无法从搜索输入态快速回到书架同名书详情 |
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` (`searchHistory`) + `../legado/app/src/main/java/io/legado/app/data/dao/BookDao.kt` (`findByName`) | 点击历史词时：若命中书架同名书且当前输入不同，则仅填充关键字，不立即搜索 | `search_view.dart` 点击历史词始终立即触发 `_search()` | 历史词触发条件未对齐 | 历史词点击行为偏离 legado，触发时机过早 |
| `../legado/app/src/main/java/io/legado/app/data/dao/SearchKeywordDao.kt` (`flowSearch`) | 非空输入时历史词按关键字过滤展示 | `search_view.dart` 历史词展示不随输入关键字过滤 | 输入联动逻辑缺失 | 输入帮助噪声偏高，历史词与输入上下文不一致 |

## 本批次差异点清单（2026-02-19：书源调试空输入语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt` | 调试入口提交时直接使用当前输入（仅 `null` 才回退 `"我的"`） | `lib/features/source/services/source_debug_quick_action_helper.dart` 的 `normalizeStartKey` 将空输入默认回退为 `"我的"` | 起始关键字归一逻辑加入了非 legado 的隐式回退 | 用户在调试页空输入提交时会被强制切到“搜索关键字=我的”路径，偏离 legado 输入语义 |
| `../legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt` + `BookSourceDebugModel.kt` | 搜索框内容保持用户原样输入后传给 `startDebug` | `lib/features/source/views/source_debug_legacy_view.dart` 在 `_runDebug` 中调用 `normalizeStartKey(... fallback: "我的")` | 视图层仍沿用了默认回退参数 | 调试起始 key 与用户输入不一致，影响“空输入/手工前缀输入”边界行为复刻 |

## 本批次差异点清单（2026-02-19：书源校验发现链路失败语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/service/CheckSourceService.kt` (`doCheckSource`) | 发现链路在已拿到分类 URL 后，若请求/解析异常会进入失败分支并标记 `网站失效/js失效` | `lib/features/source/services/source_availability_check_task_service.dart` 的 `_runExploreStage` 在 `fetch.body == null` 且报错含“规则为空”时按成功处理并添加 `发现规则为空` | 本地增加了“规则为空文本兜底成功”的启发式分支 | 会将本应失败的发现链路误判为成功，导致校验结果、分组与错误备注偏离 legado |

## 本批次差异点清单（2026-02-19：搜索范围选择语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchScopeDialog.kt` (`RecyclerAdapter.selectGroups`) | 多分组选择按用户点击顺序保留，确认时按该顺序 `joinToString(",")` | `lib/features/search/views/search_scope_picker_view.dart` 使用 `Set` 存储并按 `_groups` 顺序回放 | 选中分组容器与序列化策略未对齐 | 多分组 scope 文本顺序与 legado 不一致，影响菜单显示与状态可追溯性 |
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchScopeDialog.kt` + `../legado/app/src/main/java/io/legado/app/data/dao/BookSourceDao.kt` (`flowSearch`) | 书源筛选覆盖 `name/group/url/comment` 四字段 | `search_scope_picker_view.dart` 本地过滤未覆盖 `bookSourceComment` | 筛选字段复刻不完整 | 关键字命中书源备注时，选择器结果少于 legado |
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchScopeDialog.kt` (`ItemRadioButton` 交互) | 书源单选为“选中即置当前源”，同一项再次点击不会清空回到未选 | `search_scope_picker_view.dart` 书源点击为“再次点击同项则取消选中” | Radio 交互语义偏差 | 书源模式下误触会回退到“全部书源”，与 legado 行为不一致 |
| `../legado/app/src/main/res/values-zh/strings.xml` (`all_source`) | 中文统一文案为 `全部书源` | `lib/features/search/views/search_view.dart` 空结果提示仍使用 `所有书源` | 局部文案未同步收敛 | 搜索范围相关提示语义不一致，降低迁移一致性 |

## 本批次差异点清单（2026-02-19：发现页搜索入口与筛选语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreAdapter.kt` (`menu_search`) + `ExploreFragment.kt` (`searchBook`) | 长按菜单“搜索”直接进入 `SearchActivity` 并仅注入 `searchScope`，不弹关键词输入框 | `lib/features/discovery/views/discovery_view.dart` 的 `_searchInSource` 先弹关键词对话框，再以 `initialKeyword + autoSearchOnOpen` 立即触发搜索 | 入口流程新增了 legado 不存在的中间步骤 | 用户无法按 legado 语义先进入单源搜索页再决定关键词，交互路径偏移 |
| `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt` (`upExploreData`) + `../legado/app/src/main/java/io/legado/app/data/dao/BookSourceDao.kt` (`flowExplore`) | 发现页普通关键字筛选仅覆盖 `bookSourceName/bookSourceGroup`，`group:` 前缀按独立分支匹配分组 | `discovery_view.dart` 的 `_applyQueryFilter` 额外按 `bookSourceUrl` 匹配，并对前缀判定做了大小写放宽 | 本地筛选条件未按 DAO 语义收敛 | 发现书源列表命中范围大于 legado，导致筛选结果与状态预期不一致 |

## 本批次差异点清单（2026-02-19：搜索下一页继续加载入口语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` (`scrollToBottom`, `searchFinally`, `fbStartStop`) | 搜索结束且 `hasMore=true` 时，存在显式“继续加载”入口（播放键），不依赖列表必须可滚动 | `lib/features/search/views/search_view.dart` 仅在 `_onResultScroll` 触底时 `loadNextPage` | 下一页触发入口未完整迁移 | 当首屏结果不足一屏时，用户缺少继续翻页入口，后续页无法触发 |
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchViewModel.kt` (`search("")`) | `search("")` 复用当前关键词继续拉取下一页，不重置本次会话 | `search_view.dart` 无“继续加载”显式触发点，仅保留滚动监听 | 状态流转迁移不完整 | 搜索“有更多结果”状态在非滚动场景下不可达，影响搜索链路完整性 |

## 本批次差异点清单（2026-02-19：搜索输入帮助覆盖层与焦点语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` (`visibleInputHelp`, `onQueryTextFocusChange`, `upHistory`) | 输入帮助展示由焦点与搜索态驱动：搜索中隐藏；非搜索时按焦点/结果/输入状态切换，输入变化可实时看到“书架匹配 + 历史词” | `lib/features/search/views/search_view.dart` 仅在 `_displayResults.isEmpty` 时渲染 `_buildEmptyBody`，结果存在时无法进入输入帮助视图 | 将输入帮助与“空结果态”绑定，未复刻 legado 的独立覆盖层状态机 | 已有搜索结果后编辑关键词时，无法按 legado 语义实时查看输入帮助；输入态回流路径缺失 |
| `../legado/app/src/main/res/layout/activity_book_search.xml` (`ll_input_help`) | 输入帮助层与结果列表同级，作为覆盖层显示/隐藏，不依赖结果列表是否为空 | `search_view.dart` 将输入帮助面板作为 empty body 子树，与结果列表互斥 | 布局层级未按 legado 复刻 | 输入帮助不能覆盖当前结果页，交互层级与 legado 不一致 |
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` (`onQueryTextSubmit`) | 提交搜索后先 `clearFocus()`，再执行搜索并隐藏输入帮助 | `search_view.dart` 提交搜索未显式收起焦点 | 焦点流转细节未对齐 | 搜索提交后输入帮助显隐时机与 legado 存在偏差 |

## 本批次差异点清单（2026-02-19：搜索范围变更触发时机）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` (`searchScope.stateLiveData.observe`) | 搜索范围变更后仅在 `llInputHelp` 隐藏时触发 `setQuery(..., true)` 重搜 | `lib/features/search/views/search_view.dart` 的 `_updateScopeAndMaybeSearch` 仅按“关键字非空”判定，未绑定输入帮助显隐 | 触发条件未复用输入帮助状态机 | 输入态（帮助面板可见）调整范围时会被提前触发搜索，早于 legado 语义 |
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` + `SearchScopeDialog.kt` | 快捷菜单与多分组/单源弹窗均走同一 scope 变更回调，再由输入帮助显隐决定是否重搜 | `search_view.dart` 在快捷范围菜单与 `_openScopePicker` 两条入口都直接“非空即重搜” | 两入口未统一复刻 legacy 判定 | 搜索范围切换触发时机与 `visibleInputHelp` 状态流脱节，交互可预期性下降 |

## 本批次差异点清单（2026-02-19：书架目录更新任务流与更新中状态）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/main/bookshelf/BaseBookshelfFragment.kt` + `../legado/app/src/main/res/menu/main_bookshelf.xml` | 菜单含 `menu_update_toc`，触发 `activityViewModel.upToc(books)` 批量更新当前书架目录 | `lib/features/bookshelf/views/bookshelf_view.dart` 的“书架”菜单无“更新目录”入口 | 更新入口未迁移 | 用户无法从书架直接触发批量目录更新 |
| `../legado/app/src/main/java/io/legado/app/ui/main/MainViewModel.kt` | `onUpTocBooks` 持续维护“正在更新”的书籍 URL 集合，适配器通过 `isUpdate(bookUrl)` 实时读取 | `_updatingBookIds` 仅在 `bookshelf_view.dart` 中占位，未接入任何任务流 | 任务状态流未落地 | 图墙角标“更新中”始终不可达 |
| `../legado/app/src/main/java/io/legado/app/ui/main/bookshelf/style2/BooksAdapterGrid.kt` + `BooksAdapterList.kt` | 图墙/列表都在更新时显示 loading，非更新时显示未读徽标 | soup 仅图墙分支有 loading 分支；列表分支无“更新中”指示 | 列表渲染分支未对齐 | 列表模式无法感知目录更新进度，交互反馈弱于 legado |

## 本批次差异点清单（2026-02-19：搜索详情目录检索字段语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/info/BookInfoActivity.kt` (`tvTocView -> openChapterList`) + `../legado/app/src/main/java/io/legado/app/ui/book/toc/ChapterListFragment.kt` (`upChapterList`) + `../legado/app/src/main/java/io/legado/app/data/dao/BookChapterDao.kt` (`search`) | 书籍详情页进入目录后，检索按 `BookChapter.title`（原始标题字段）匹配；展示标题由 `getDisplayTitle` 单独处理 | `lib/features/search/views/search_book_info_view.dart` 的 `_SearchBookTocView._filtered` 按 `displayTitles` 过滤 | 将“目录展示标题”与“目录检索字段”错误耦合 | 简繁/替换开启时，目录可见标题被替换后会改变检索命中范围，与 legado `title like` 语义不一致 |

## 本批次差异点清单（2026-02-19：搜索输入变更继续加载入口语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` (`onQueryTextChange`) | 输入关键字变更时立即 `stop()` 并隐藏播放键（继续加载入口） | `lib/features/search/views/search_view.dart` 的输入框 `onChanged` 仅在“正在搜索”时取消会话，非搜索态不会清除 `_hasMore` | 输入变更未同步重置分页继续态 | 用户编辑关键字但尚未重新搜索时，页面仍可能显示“继续”入口，触发上一关键词的下一页加载 |

## 本批次差异点清单（2026-02-19：搜索页返回键焦点语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` (`finish`) | 当搜索框有焦点时，返回键先 `clearFocus()`，当前页不退出；再次返回才退出页面 | `lib/features/search/views/search_view.dart` 未拦截返回事件 | 页面返回与输入焦点状态机未复刻 | 输入态误触返回会直接退出搜索页，打断输入帮助与范围切换的连续操作 |

## 本批次差异点清单（2026-02-19：阅读器更新目录流程语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt` (`menu_update_toc`) + `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookViewModel.kt` (`loadChapterListAwait`) + `../legado/app/src/main/java/io/legado/app/model/webBook/WebBook.kt` (`getChapterListAwait`) | 阅读器“更新目录”会重拉完整目录并整库替换，不依赖“旧目录是新目录前缀” | `lib/features/reader/views/simple_reader_view.dart` 的 `_refreshCatalogFromSource` 仅允许前缀追加，否则抛出“目录结构变化较大” | 刷新目录实现采用“增量追加”策略，未复刻 legado 全量替换语义 | 目录出现插章/重排/去重后，阅读器更新目录会误失败，且章节总数/最新章节无法及时收敛 |
| `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookViewModel.kt` (`loadChapterListAwait`) | 目录刷新时调用 `WebBook.getChapterListAwait(..., runPerJs=true)`，细节页失败不应阻断目录刷新主链路 | `_refreshCatalogFromSource` 先请求 `getBookInfo`，失败即中断，不继续尝试目录拉取 | 详情与目录链路被强耦合 | 详情接口偶发失败时，阅读器目录刷新不可用，偏离 legado 可用性语义 |

## 本批次差异点清单（2026-02-19：阅读器目录面板 Tab 结构）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/toc/TocActivity.kt` (`TabFragmentPageAdapter`) | 目录页固定两栏：`章节` / `书签`，`getCount()==2` | `lib/features/reader/widgets/reader_catalog_sheet.dart` 提供三栏：`目录` / `书签` / `笔记` | 沿用扩展式抽屉草稿，未按 legado Tab 结构收敛 | 用户可见入口层级偏离 legado，存在无实现能力入口 |
| `../legado/app/src/main/java/io/legado/app/ui/book/toc/TocActivity.kt` + `ChapterListFragment.kt` | 搜索/过滤状态机仅覆盖目录与书签两链路 | `reader_catalog_sheet.dart` 额外维护“笔记”分支与占位文案 | 为未迁移能力保留了扩展分支 | 造成“可切换但不可用”的假入口，不符合迁移级别口径 |

## 本批次差异点清单（2026-02-19：搜索入口初始焦点与首搜触发语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` (`receiptIntent`) | 进入搜索页时：`key` 为空则请求搜索框焦点，`key` 非空则 `setQuery(key, true)` 自动提交搜索 | `lib/features/search/views/search_view.dart` 在 `initState` 仅写入 `initialKeyword`，未对空关键词执行聚焦；非空关键词是否自动搜索受本地扩展参数 `autoSearchOnOpen` 约束 | 入口初始化状态机未按 legado 收敛，且保留了可改变首搜时机的扩展开关 | 打开搜索页时无法直接输入（需额外点击）；携带初始关键词场景可能停留在“已填充但未提交”，与 legado 首次触发语义不一致 |

## 本批次差异点清单（2026-02-19：搜索页书源管理入口）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` (`onCompatOptionsItemSelected`) | 搜索页菜单提供 `menu_source_manage`，点击后直接进入 `BookSourceActivity` | `lib/features/search/views/search_view.dart` 的“搜索设置”仅提供过滤/范围/缓存等项，无“书源管理”直达入口 | 菜单入口迁移时遗漏 legado 的管理跳转项 | 用户需离开搜索链路绕行设置页才能进入书源管理，入口层级与 legado 不一致 |

## 本批次差异点清单（2026-02-19：搜索精准筛选开关语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` + `../legado/app/src/main/res/menu/book_search.xml` | 菜单为单一 `menu_precision_search` 勾选项，点击即在“精准搜索 开/关”间切换并按当前关键字重搜 | `lib/features/search/views/search_view.dart` 使用“搜索过滤”三态动作（不过滤/普通过滤/精准过滤） | 迁移时引入了 legado 不存在的扩展入口与额外状态 | 用户可见菜单结构与状态流转偏离 legado，难以直接对应“精准搜索”开关语义 |
| `../legado/app/src/main/java/io/legado/app/model/webBook/SearchModel.kt` (`precision` 布尔判定) | 搜索过滤仅由布尔 `precisionSearch` 控制（开=仅保留命中，关=保留非命中） | `lib/core/models/app_settings.dart` 存在 `SearchFilterMode.none/normal/precise` 三态；`lib/features/search/services/search_cache_service.dart` 按模式名参与缓存 key | 本地设置模型未按 legado 单开关收敛 | 旧配置中的 `none` 会形成与 `normal` 分裂的缓存键，且设置文案/配置项语义不一致 |

## 本批次差异点清单（2026-02-19：搜索页日志入口语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` (`onCompatOptionsItemSelected`) + `../legado/app/src/main/res/menu/book_search.xml` (`menu_log`) | 搜索页菜单提供 `日志` 入口，点击后直接打开日志面板（`AppLogDialog`） | `lib/features/search/views/search_view.dart` 的“搜索设置”动作表无日志入口 | 菜单迁移时遗漏 `menu_log` 分支 | 搜索链路异常定位需绕行设置页，入口层级与 legado 不一致，降低可观测性 |

## 本批次差异点清单（2026-02-19：搜索设置菜单结构与排序语义）

| 文件位置 | legado 语义 | soupreader 改造前 | 差异原因 | 影响 |
|---|---|---|---|---|
| `../legado/app/src/main/res/menu/book_search.xml` + `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt` (`onCompatOptionsItemSelected`) | 搜索菜单固定四项：`精准搜索 -> 书源管理 -> 搜索范围 -> 日志`，不存在额外设置入口 | `lib/features/search/views/search_view.dart` 的“搜索设置”动作表在上述能力外仍保留 `并发任务/缓存保留/封面开关/清除缓存/清空历史` 等扩展项，且顺序为 `精准搜索 -> 搜索范围 -> 书源管理 -> 日志 -> ...` | 菜单结构收敛不彻底，保留了 legacy 外扩展入口并改变了菜单顺序 | 用户可见菜单层级与触发路径偏离 legado，且扩展入口违背迁移级别“禁止保留导致行为偏差的扩展入口”约束 |

## 实施步骤

### Step 1：ExecPlan 基础设施（已完成）

- 动作：创建 `PLANS.md` 与本计划文档。
- 预期结果：迁移执行有单一事实来源。
- 验证方式：文档存在且结构满足 AGENTS 规范。

### Step 2：核心缺口补齐（已完成）

- 动作：实现阅读器“简体 -> 繁体”转换，替换 TODO 占位。
- 预期结果：繁体显示开关具备真实转换效果。
- 验证方式：新增转换单测覆盖常见句子、ASCII/emoji 稳定性。

### Step 3：Shader 回归守护（已完成）

- 动作：新增测试确保 `page_curl.frag` 继续被声明与加载，且仿真模式仍可见。
- 预期结果：仿真翻页路径不被后续改动破坏。
- 验证方式：新增 `reader_shader_guard_test.dart`。

### Step 4：扩展能力挂账（已完成）

- 动作：统一将“暂未实现”文案口径调整为“扩展阶段”语义，并持续沉淀扩展清单。
- 预期结果：用户侧语义与当前策略一致，不误导为近期完成。
- 验证方式：设置占位弹窗与标签文案检查。

### Step 5：后续核心迁移批次（进行中）

- 动作：按核心模块继续推进 legacy 同义对齐（阅读链路细节、异常边界、交互路径）。
- 预期结果：核心范围逐项达到“同义”。
- 验证方式：逐项对照清单 + 定向测试 + 手工回归。

#### Step 5.1：简繁三态配置与链路语义对齐（已完成）

- 动作：将 `ReadingSettings` 从布尔“繁体显示”升级为 legado 同义三态（关闭/繁转简/简转繁），并同步正文与标题转换链路、所有设置入口与兼容迁移。
- 预期结果：阅读器可按三态执行转换；旧布尔配置无损迁移；正文与标题语义一致。
- 验证方式：
  - `flutter test test/chinese_script_converter_test.dart`
  - `flutter test test/reading_settings_test.dart`

#### Step 5.2：搜索详情页目录标题展示链路对齐（已完成）

- 动作：新增目录标题展示 helper，并将 `bookInfo -> toc` 目录弹窗接入“简繁转换 + 标题替换规则”链路。
- 预期结果：搜索详情页目录展示语义与 legado 一致（不再直接显示原始标题）。
- 验证方式：
  - `flutter test test/chapter_title_display_helper_test.dart`
  - `flutter test test/search_book_info_view_compile_test.dart`
  - `flutter test test/chinese_script_converter_test.dart`

#### Step 5.3：阅读器目录弹窗标题展示链路对齐（已完成）

- 动作：阅读器目录弹窗接入“简繁转换 + 标题替换规则”显示链路，并保持目录搜索字段语义与 legado 一致（按原始标题字段过滤）。
- 预期结果：阅读器目录标题不再直接显示原始抓取文本；标题展示顺序与 legado `getDisplayTitle` 同义。
- 验证方式：
  - `flutter test test/reader_catalog_sheet_test.dart`
  - `flutter test test/chapter_title_display_helper_test.dart`

#### Step 5.4：书源调试 key 判定顺序对齐（已完成）

- 动作：将 `SourceDebugKeyParser` 判定顺序调整为 legado 同义（`absUrl -> contains("::") -> ++ -> -- -> keyword`），并补充冲突 key 的定向测试。
- 预期结果：调试意图标签与实际执行链路保持一致；`++系统::url`/`--系统::url` 等边界 key 不再出现“UI 标记为目录/正文，实际执行发现”的偏差。
- 验证方式：
  - `flutter test test/source_debug_key_parser_test.dart`
  - `flutter test test/source_debug_quick_action_helper_test.dart`
  - `flutter test test/source_debug_legacy_view_compile_test.dart`

#### Step 5.5：换源章节定位语义对齐（已完成）

- 动作：迁移 `BookHelp.getDurChapter` 的核心策略（候选窗口 + 章号匹配 + 标题相似度 + 回退逻辑）到 `ReaderSourceSwitchHelper.resolveTargetChapterIndex`，并在换源入口补齐旧目录总章数上下文。
- 预期结果：换源后章节定位在目录长度变化、标题格式变化、简繁差异场景下与 legado 保持同义。
- 验证方式：
  - `flutter test test/reader_source_switch_helper_test.dart`

#### Step 5.6：18+ 域名拦截主域提取语义对齐（已完成）

- 动作：将 `SourceImportCommitService` 的主域提取逻辑改为复用 `SourceHostGroupHelper.groupHost`（支持多段公共后缀），并补充 `.co.uk` 场景回归测试。
- 预期结果：18+ 域名拦截在多段后缀域名场景与 legado 主域语义保持同义。
- 验证方式：
  - `flutter test test/source_import_commit_service_test.dart`
  - `flutter test test/source_host_group_helper_test.dart`

#### Step 5.7：清 Cookie 主域作用域语义对齐（已完成）

- 动作：新增 `SourceCookieScopeResolver.resolveClearCandidates`，统一合并“书源 URL 作用域 + 主域（eTLD+1）作用域”候选；编辑页与 legacy 编辑页“清 Cookie”入口统一改用该候选集合。
- 预期结果：对子域书源执行“清 Cookie”时，可同步清理主域 Cookie，行为与 legado `CookieStore.removeCookie(getSubDomain(url))` 同义。
- 验证方式：
  - `flutter test test/source_cookie_scope_resolver_test.dart`
  - `flutter test test/source_edit_view_compile_test.dart`
  - `flutter test test/source_edit_legacy_view_compile_test.dart`

#### Step 5.8：滚动偏移回退与书架排序可变性对齐（已完成）

- 动作：对齐阅读偏移回退语义（章节键未命中时回退书籍键，并在章节保存时同步书籍键）；修复书架加载阶段对不可变列表原地排序导致的崩溃。
- 预期结果：阅读进度恢复具备 legado 同义的回退行为；书架初始化不再因列表可变性差异崩溃。
- 验证方式：
  - `flutter test test/app_settings_test.dart`
  - `flutter test test/widget_test.dart`
  - `flutter test`

#### Step 5.9：搜索输入帮助链路语义对齐（已完成）

- 动作：新增 `SearchInputHintHelper`，将搜索页输入阶段接入“书架匹配 + 历史词过滤”；并对齐历史词点击语义（命中书架同名时仅填充关键字，不立即触发搜索）。
- 预期结果：搜索输入阶段与 legado `upHistory/searchHistory` 行为同义，用户可从输入帮助区直接进入书架书籍详情。
- 验证方式：
  - `flutter test test/search_input_hint_helper_test.dart`
  - `flutter test test/search_scope_test.dart`

#### Step 5.10：书源调试空输入语义对齐（已完成）

- 动作：移除调试起始 key 对 `"我的"` 的隐式回退；调试页提交时按用户输入原样执行（保留调用方显式 fallback 能力）。
- 预期结果：`SourceDebugLegacyView` 的空输入/手工输入行为与 legado `BookSourceDebugActivity` 同义，不再默认改写为 `"我的"`。
- 验证方式：
  - `flutter test test/source_debug_quick_action_helper_test.dart`
  - `flutter test test/source_debug_legacy_view_compile_test.dart`

#### Step 5.11：书源校验发现链路失败语义对齐（已完成）

- 动作：移除发现阶段“请求失败但报错含规则为空即视为成功”的启发式分支；`fetch` 失败统一按失败处理，并按 legado 语义标记 `网站失效/js失效`。
- 预期结果：当发现链路已进入实际请求阶段且请求失败时，检测结果稳定落在失败态，不再误归类为“发现规则为空”成功分支。
- 验证方式：
  - `flutter test test/source_check_task_config_test.dart`
  - `flutter test test/source_list_view_compile_test.dart`
  - `flutter test test/source_check_source_state_helper_test.dart`

#### Step 5.12：搜索范围选择语义对齐（已完成）

- 动作：将搜索范围选择器按 legado `SearchScopeDialog` 语义收敛（多分组选择顺序、书源筛选字段、单源单选行为、`全部书源` 文案一致性），并抽离 `SearchScopePickerHelper` 统一决策。
- 预期结果：搜索范围“快捷菜单 + 多分组/单源弹窗”在状态流转、筛选与确认语义上与 legado 同义。
- 验证方式：
  - `flutter test test/search_scope_test.dart`
  - `flutter test test/search_scope_picker_helper_test.dart`
  - `flutter test test/search_scope_picker_view_compile_test.dart`
  - `flutter test test/search_scope_group_helper_test.dart`

#### Step 5.13：发现页搜索入口与筛选语义对齐（已完成）

- 动作：将发现页“源内搜索”入口改为 legado 同义的“直接进入单源搜索页（仅注入 scope）”；并把发现页普通关键词筛选收敛为 `bookSourceName/bookSourceGroup`，不再额外按 URL 命中。
- 预期结果：发现页长按菜单“源内搜索”与 legado `ExploreAdapter.menu_search` 入口层级一致；发现列表筛选结果与 `BookSourceDao.flowExplore(key)` 语义一致。
- 验证方式：
  - `flutter test test/discovery_filter_helper_test.dart`
  - `flutter test test/discovery_view_compile_test.dart`

#### Step 5.14：搜索下一页继续加载入口语义对齐（已完成）

- 动作：在搜索页补齐 legado 同义的“有更多结果时手动继续加载”入口，并保留触底自动加载分支；抽离 `SearchLoadMoreHelper` 统一入口显示判定。
- 预期结果：当结果列表不足一屏且仍有下一页时，用户可通过显式入口继续加载，不再依赖滚动事件触发。
- 验证方式：
  - `flutter test test/search_load_more_helper_test.dart`
  - `flutter test test/search_view_compile_test.dart`

#### Step 5.15：搜索输入帮助覆盖层与焦点语义对齐（已完成）

- 动作：将搜索输入帮助改为 legado 同义“覆盖层 + 焦点驱动显示”状态机，补齐提交搜索收起焦点语义。
- 预期结果：已存在搜索结果时，用户编辑输入仍可实时看到“书架匹配 + 历史词”输入帮助；提交搜索后输入帮助按 legacy 语义收起。
- 验证方式：
  - `flutter test test/search_input_hint_helper_test.dart`
  - `flutter test test/search_view_compile_test.dart`

#### Step 5.16：搜索范围变更触发时机语义对齐（已完成）

- 动作：将快捷范围菜单与范围选择器回写统一绑定“输入帮助覆盖层显隐”判定，替换“关键字非空即重搜”。
- 预期结果：范围切换仅在输入帮助层隐藏时自动重搜，触发时机与 legado `searchScope.stateLiveData.observe` 同义。
- 验证方式：
  - `flutter test test/search_input_hint_helper_test.dart`
  - `flutter test test/search_view_compile_test.dart`

#### Step 5.17：书架目录更新任务流与更新中状态语义对齐（已完成）

- 动作：补齐书架“更新目录”入口、批量目录更新任务流、更新中状态集维护，以及图墙/列表更新中指示。
- 预期结果：用户可从书架直接触发批量目录更新；更新中书籍在图墙与列表均可见 loading 状态；结束后提供汇总结果。
- 验证方式：
  - `flutter test test/bookshelf_catalog_update_service_test.dart`
  - `flutter test test/bookshelf_view_compile_test.dart`

#### Step 5.18：搜索详情目录检索字段语义对齐（已完成）

- 动作：将 `bookInfo -> toc` 目录弹窗检索逻辑收敛为 legado 同义“按原始标题字段匹配”，同时保留展示标题的“去换行 -> 简繁转换 -> 替换规则”处理顺序。
- 预期结果：目录检索命中范围与 legado `BookChapterDao.search(title like ...)` 同义，不受展示标题替换副作用影响。
- 验证方式：
  - `flutter test test/search_book_toc_filter_helper_test.dart`
  - `flutter test test/search_book_info_view_compile_test.dart`

#### Step 5.19：搜索输入变更继续加载入口语义对齐（已完成）

- 动作：在搜索框 `onChanged` 分支对齐 legado `onQueryTextChange`，输入一旦变化即清空 `_hasMore`，同步隐藏“继续加载下一页”入口。
- 预期结果：编辑关键字时不再保留上一轮搜索会话的继续加载状态；“继续”入口仅在本次关键词搜索完成且 `hasMore=true` 后可见。
- 验证方式：
  - `flutter test test/search_load_more_helper_test.dart`
  - `flutter test test/search_view_compile_test.dart`

#### Step 5.20：搜索页返回键焦点语义对齐（已完成）

- 动作：在搜索页返回链路增加“输入框有焦点先收起焦点、阻止直接退出”的拦截；并将该判定收敛到 `SearchInputHintHelper` 单点语义方法。
- 预期结果：搜索页输入态按返回键时先退出焦点，再次返回才真正离开页面，行为与 legado `SearchActivity.finish` 同义。
- 验证方式：
  - `flutter test test/search_input_hint_helper_test.dart`
  - `flutter test test/search_view_compile_test.dart`

#### Step 5.21：阅读器更新目录流程语义对齐（已完成）

- 动作：将 `SimpleReaderView._refreshCatalogFromSource` 收敛为 legado 同义“完整目录刷新并写回”链路，不再要求新目录必须是旧目录前缀；并复用已落地的目录更新服务，保证详情失败不阻断目录刷新。
- 预期结果：阅读器内“更新目录”在目录重排/插章场景可稳定完成，错误语义与书架更新目录链路一致。
- 验证方式：
  - `flutter test test/bookshelf_catalog_update_service_test.dart`
  - `flutter test test/reader_catalog_sheet_test.dart`
  - `flutter test test/reader_shader_guard_test.dart`

#### Step 5.22：阅读器目录面板 Tab 结构语义对齐（已完成）

- 动作：将阅读器目录面板 Tab 收敛到 legado 同义的“目录 + 书签”双栏结构，移除“笔记”占位入口与对应分支状态机。
- 预期结果：阅读器目录面板入口层级、搜索占位与空态分支不再包含未迁移扩展入口，交互语义与 legado `TocActivity` 同义。
- 验证方式：
  - `flutter test test/reader_catalog_sheet_test.dart`

#### Step 5.23：搜索入口初始焦点与首搜触发语义对齐（已完成）

- 动作：将 `SearchView` 入口初始化收敛到 legado `receiptIntent` 语义：空初始关键词自动请求输入焦点，非空初始关键词自动提交搜索；并移除 `autoSearchOnOpen` 扩展开关，避免首搜触发时机偏移。
- 预期结果：搜索页首次进入即具备 legado 同义输入态/首搜态行为，不再出现“初始关键词已填充但未提交”与“空输入未聚焦”偏差。
- 验证方式：
  - `flutter test test/search_input_hint_helper_test.dart`
  - `flutter test test/search_view_compile_test.dart`
  - `flutter test test/source_edit_legacy_view_compile_test.dart`

#### Step 5.24：搜索页书源管理入口语义对齐（已完成）

- 动作：在搜索页“搜索设置”动作表补齐 legado 同义“书源管理”入口，点击后直接跳转 `SourceListView`。
- 预期结果：搜索页内可一跳进入书源管理，入口层级与 legado `menu_source_manage -> BookSourceActivity` 同义。
- 验证方式：
  - `flutter test test/search_view_compile_test.dart`
  - `flutter test test/source_list_view_compile_test.dart`

#### Step 5.25：搜索精准筛选开关语义对齐（已完成）

- 动作：将搜索页“搜索过滤三态”收敛为 legado 同义“精准搜索开关”单入口；并将历史 `searchFilterMode.none` 配置归一到普通模式，消除缓存键分裂。
- 预期结果：搜索页设置入口、切换时机与 legado `menu_precision_search` 同义，且旧配置读取后不再保留三态分叉。
- 验证方式：
  - `flutter test test/app_settings_test.dart`
  - `flutter test test/search_cache_service_test.dart`
  - `flutter test test/search_view_compile_test.dart`

#### Step 5.26：搜索页日志入口语义对齐（已完成）

- 动作：在搜索页“搜索设置”动作表补齐 legado 同义“日志”入口，点击后直接打开异常日志页。
- 预期结果：搜索页内可一跳进入日志查看能力，入口层级与 legado `menu_log -> AppLogDialog` 同义。
- 验证方式：
  - `flutter test test/search_view_compile_test.dart`
  - `flutter test test/exception_logs_view_compile_test.dart`

#### Step 5.27：搜索设置菜单结构与排序语义对齐（已完成）

- 动作：将搜索页“搜索设置”动作表收敛到 legado `book_search.xml` 同义四项结构（精准搜索、书源管理、搜索范围、日志）并按同序展示，移除 legacy 外扩展入口。
- 预期结果：搜索设置菜单结构、排序与触发入口层级与 legado 保持同义，不再暴露会导致行为偏差的扩展菜单项。
- 验证方式：
  - `flutter test test/search_view_compile_test.dart`
  - `flutter test test/source_list_view_compile_test.dart`
  - `flutter test test/exception_logs_view_compile_test.dart`

### Step 6：扩展能力分期计划落盘（已完成）

- 动作：基于 legado 扩展模块关键实现（RSS/TTS/Dict/Android API）输出分期 ExecPlan，并在 `PLANS.md` 建立活跃索引。
- 预期结果：扩展能力从“挂账”升级为可执行分期路线图，后续迭代具备单一事实来源。
- 验证方式：
  - `sed -n '1,220p' docs/plans/2026-02-19-legado-extension-roadmap-execplan.md`
  - `sed -n '1,120p' PLANS.md`

## 风险与回滚

### 失败模式

1. 简繁转换仅字符级映射，语境词组转换仍可能不完全。
2. 大体量字符映射表增加体积与维护成本。
3. 后续重构可能误改仿真 Shader 路径。

### 阻塞条件

1. 发现 legado 核心语义无法等价复现。
2. iOS 平台能力不足以承载某核心语义。

### 回滚策略

1. 字符转换能力可按文件级回退（`chinese_script_converter.dart` + map 文件）。
2. Shader 守护测试可先保留，防止误删路径。

## 验收与证据

### 命令验证

- 定向测试：
  - `flutter test test/reader_catalog_sheet_test.dart`
  - `flutter test test/chapter_title_display_helper_test.dart`
  - `flutter test test/search_book_toc_filter_helper_test.dart`
  - `flutter test test/search_book_info_view_compile_test.dart`
  - `flutter test test/chinese_script_converter_test.dart`
  - `flutter test test/reading_settings_test.dart`
  - `flutter test test/reader_shader_guard_test.dart`
  - `flutter test test/source_debug_key_parser_test.dart`
  - `flutter test test/source_debug_quick_action_helper_test.dart`
  - `flutter test test/source_debug_legacy_view_compile_test.dart`
  - `flutter test test/source_check_task_config_test.dart`
  - `flutter test test/source_list_view_compile_test.dart`
  - `flutter test test/source_check_source_state_helper_test.dart`
  - `flutter test test/search_scope_picker_helper_test.dart`
  - `flutter test test/search_scope_picker_view_compile_test.dart`
  - `flutter test test/discovery_filter_helper_test.dart`
  - `flutter test test/discovery_view_compile_test.dart`
  - `flutter test test/reader_source_switch_helper_test.dart`
  - `flutter test test/source_import_commit_service_test.dart`
  - `flutter test test/source_host_group_helper_test.dart`
  - `flutter test test/source_cookie_scope_resolver_test.dart`
  - `flutter test test/source_edit_view_compile_test.dart`
  - `flutter test test/source_edit_legacy_view_compile_test.dart`
  - `flutter test test/app_settings_test.dart`
  - `flutter test test/search_cache_service_test.dart`
  - `flutter test test/search_input_hint_helper_test.dart`
  - `flutter test test/search_scope_test.dart`
  - `flutter test test/search_load_more_helper_test.dart`
  - `flutter test test/search_view_compile_test.dart`
  - `flutter test test/exception_logs_view_compile_test.dart`
  - `flutter test test/bookshelf_catalog_update_service_test.dart`
  - `flutter test test/bookshelf_view_compile_test.dart`
  - `flutter test test/widget_test.dart`
  - `flutter test`
- 迁移规则约束：`flutter analyze` 仅在提交推送前执行一次（本阶段不执行）。

### 手工回归路径

1. 阅读器打开任意中文章节。
2. 在阅读设置将“简繁转换”依次切换为“简转繁 / 繁转简 / 关闭”。
3. 验证正文与章节标题均随模式变化（保持章节/翻页功能正常）。
4. 切换翻页模式到“仿真”，确认效果与原 Shader 路径一致。
5. 在搜索页进入任意书籍详情，打开目录弹窗并搜索章节名，验证展示标题随简繁/替换规则变化；目录检索仍按原始章节标题字段匹配。
6. 在阅读器内打开“目录”面板，验证目录标题随简繁设置变化，并可应用标题替换规则。
7. 在阅读器执行“换源”，验证跳转章节与换源前章节号/标题语义一致（目录长度变化时不偏移到明显错误章节）。
8. 在搜索页输入与书架同名的关键词，验证出现“书架匹配”区块，点击后可直接进入该书详情。
9. 在搜索页点击历史词时，验证“同名书存在且当前输入不同”场景仅填充关键字，不立即触发搜索；其余场景直接触发搜索。
10. 在搜索页点击“搜索设置 -> 搜索范围”，依次验证：快捷菜单“全部书源/单分组”切换、进入“多分组/单源模式”后分组选择顺序、书源备注关键字筛选命中、单源重复点击不取消。
11. 在发现页长按任一书源点击“源内搜索”，验证直接进入单源搜索页（无关键词弹窗）；在发现页输入普通关键字时，验证仅按书源名/分组筛选，不按 URL 命中。
12. 在搜索页执行一次有结果的搜索后，若列表未填满首屏且状态仍“有更多结果”，验证顶部出现“继续”入口；点击“继续”后可加载下一页。
13. 在搜索页聚焦输入框后按一次系统返回，验证仅收起输入焦点并保留当前搜索页；再次返回才退出页面。
14. 在搜索页“搜索设置”连续切换“精准搜索 开/关”，验证：关键字非空时会立即重搜；关键字为空时仅更新开关状态，不触发异常请求。
15. 在搜索页打开“搜索设置 -> 日志”，验证可直接进入“异常日志”页面并可返回搜索页，当前搜索会话状态保持不变。
16. 在搜索页打开“搜索设置”，验证动作项固定为“精准搜索/书源管理/搜索范围/日志”且顺序一致，不再出现并发、缓存、封面、清缓存等扩展项。

### 预期输出

- 简繁转换三态生效，正文与标题方向一致，非中文字符不受影响。
- 仿真翻页仍可用，且 `page_curl.frag` 路径保持不变。
- 搜索页“搜索设置”可直接进入日志页，保持 legado 同义入口层级。
- 搜索页过滤入口收敛为 legado 同义“精准搜索开关”，切换语义与缓存维度保持一致。

## Progress

- [x] 2026-02-19：创建 ExecPlan 索引与主计划文档。
  - 做了什么：新增 `PLANS.md` 和本任务 ExecPlan。
  - 为什么：满足迁移任务必须先落盘计划的硬约束。
  - 如何验证：文件存在且章节完整。
  - 兼容影响：无运行时影响。

- [x] 2026-02-19：实现简繁转换核心能力（字符级 OpenCC 映射）。
  - 做了什么：新增 `chinese_script_converter` 与生成映射表；阅读器改为真实转换。
  - 为什么：修复阅读核心能力中的 TODO 占位缺口。
  - 如何验证：新增并通过 `flutter test test/chinese_script_converter_test.dart`。
  - 兼容影响：开启“繁体显示”后正文会被转换；默认关闭不影响旧行为。

- [x] 2026-02-19：新增仿真 Shader 保留回归测试。
  - 做了什么：新增 `reader_shader_guard_test.dart`，守护 shader 声明、加载路径、模式可见性。
  - 为什么：落实“保留当前 shader 实现”硬约束。
  - 如何验证：通过 `flutter test test/reader_shader_guard_test.dart`。
  - 兼容影响：仅测试层影响，无运行时行为变更。

- [x] 2026-02-19：占位文案口径统一为“扩展阶段”。
  - 做了什么：更新设置占位 token 与弹窗标题。
  - 为什么：与“核心优先、扩展后置”策略一致。
  - 如何验证：设置页相关入口弹窗文案检查。
  - 兼容影响：仅文案变更，不影响业务流程。

- [x] 2026-02-19：补齐简繁转换词组级语义（OpenCC 短语覆盖）。
  - 做了什么：新增 `chinese_s2t_phrase_overrides.g.dart`（仅保留与字符级结果不同的短语），并在转换器中实现“最长短语优先 + 字符兜底”。
  - 为什么：对齐 legado 的词组级转换语义，修复“理发/分钟/髮”等字符级误判。
  - 如何验证：更新并通过 `flutter test test/chinese_script_converter_test.dart`。
  - 兼容影响：开启“繁体显示”时，正文转换结果更接近 OpenCC/legado；默认关闭不影响旧行为。

- [x] 2026-02-19：收敛简繁三态配置差异（布尔 -> 三态）并补齐标题/正文双链路。
  - 做了什么：
    - `ReadingSettings` 新增 `chineseConverterType`（0=关闭、1=繁转简、2=简转繁），保留旧 `chineseTraditional` 向前兼容读取；
    - 阅读器正文与章节标题统一接入三态转换；
    - 阅读器面板、快速设置、设置页“文本处理”入口统一改为“简繁转换”三态选择；
    - 转换器新增 `traditionalToSimplified`，并引入 legado `fixT2sDict` 例外词。
  - 为什么：对齐 legado 的交互语义与状态流转，消除“只有简转繁且仅正文生效”的行为偏差。
  - 如何验证：
    - `flutter test test/chinese_script_converter_test.dart`
    - `flutter test test/reading_settings_test.dart`
  - 兼容影响：
    - 历史 `reading_settings` 中 `chineseTraditional=true` 将自动迁移为 `简转繁`；
    - `false` 迁移为 `关闭`；
    - 默认行为不变（关闭）。

- [x] 2026-02-19：修复搜索详情页目录标题“原样展示”差异并补回归测试。
  - 做了什么：
    - 新增 `chapter_title_display_helper`，统一“去换行 -> 简繁转换 -> 标题替换规则”目录标题链路；
    - `search_book_info_view` 打开目录时预处理 `displayTitles`，目录列表展示与过滤改为使用处理后标题；
    - 新增 `chapter_title_display_helper_test.dart` 覆盖三态转换与处理顺序。
  - 为什么：对齐 legado `bookInfo/toc` 入口的目录标题展示语义，避免目录弹窗仍停留在原始抓取文本。
  - 如何验证：
    - `flutter test test/chapter_title_display_helper_test.dart`
    - `flutter test test/search_book_info_view_compile_test.dart`
    - `flutter test test/chinese_script_converter_test.dart`
  - 兼容影响：
    - 仅影响搜索详情页目录弹窗的标题展示与搜索命中；
    - 不改动目录数据存储结构与阅读跳转索引。

- [x] 2026-02-19：收敛阅读器目录弹窗标题展示链路并补回归测试。
  - 做了什么：
    - `ReaderCatalogSheet` 新增目录展示标题能力：支持初始 display title 映射 + 异步逐章解析回调；
    - `SimpleReaderView` 接入 `chapter_title_display_helper`，为目录弹窗提供“去换行 -> 简繁转换 -> 标题替换规则”链路，并增加章节级标题缓存；
    - 新增 `reader_catalog_sheet_test.dart` 覆盖“初始标题映射优先 + 异步失败回退原始标题”。
  - 为什么：对齐 legado 阅读器目录列表 `getDisplayTitle` 展示语义，避免阅读器目录仍停留在原始章节名。
  - 如何验证：
    - `flutter test test/reader_catalog_sheet_test.dart`
    - `flutter test test/chapter_title_display_helper_test.dart`
  - 兼容影响：
    - 仅影响阅读器目录弹窗（目录 Tab）标题展示；
    - 目录搜索字段仍按原始标题过滤，以保持 legado `BookChapterDao.search(title like ...)` 语义。

- [x] 2026-02-19：收敛书源调试 key 判定顺序并补回归测试。
  - 做了什么：
    - 调整 `SourceDebugKeyParser.parse` 顺序为 `absUrl -> contains("::") -> ++ -> -- -> search`；
    - 新增 `source_debug_key_parser_test.dart`，覆盖 `++系统::url`/`--系统::url` 等冲突 key 场景。
  - 为什么：对齐 legado `Debug.startDebug` 的分支顺序，避免调试摘要与实际执行链路语义不一致。
  - 如何验证：
    - `flutter test test/source_debug_key_parser_test.dart`
    - `flutter test test/source_debug_quick_action_helper_test.dart`
    - `flutter test test/source_debug_legacy_view_compile_test.dart`
  - 兼容影响：
    - 仅影响调试 key 的“意图归类与摘要标签”；
    - 不改变 `RuleParserEngine.debugRun` 现有网络请求与解析行为。

- [x] 2026-02-19：收敛换源章节定位语义并补回归测试。
  - 做了什么：
    - `ReaderSourceSwitchHelper.resolveTargetChapterIndex` 迁移为 legado 风格：候选窗口 + 标题相似度 + 章号匹配 + 索引回退；
    - 新增 `oldChapterCount` 语义参数，对齐 legado `oldChapterListSize` 窗口估算；
    - `SimpleReaderView` 换源入口改为传入“当前章节原始标题 + 旧目录总章数”，避免展示标题参与定位。
  - 为什么：对齐 legado `BookHelp.getDurChapter` 的状态流，修复简繁/替换开启后换源定位命中率下降问题。
  - 如何验证：
    - `flutter test test/reader_source_switch_helper_test.dart`
  - 兼容影响：
    - 仅影响换源后的目标章节定位；
    - 不改变换源候选检索、目录抓取和正文抓取流程。

- [x] 2026-02-19：收敛 18+ 域名拦截主域提取语义并补回归测试。
  - 做了什么：
    - `SourceImportCommitService._extractSecondLevelDomain` 改为复用 `SourceHostGroupHelper.groupHost`；
    - 新增 `source_import_commit_service_test.dart` 多段后缀场景（`reader.news.co.uk -> news.co.uk`）拦截回归用例。
  - 为什么：对齐 legado `NetworkUtils.getSubDomain` 的主域提取语义，修复多段后缀域名在 18+ 拦截链路中的漏判风险。
  - 如何验证：
    - `flutter test test/source_import_commit_service_test.dart`
    - `flutter test test/source_host_group_helper_test.dart`
  - 兼容影响：
    - 仅影响书源导入阶段的 18+ 域名拦截判断；
    - 不改变导入选中策略、字段保留策略与排序归一流程。

- [x] 2026-02-19：收敛清 Cookie 主域作用域语义并补回归测试。
  - 做了什么：
    - `SourceCookieScopeResolver` 新增 `resolveClearCandidates`，统一返回“URL 作用域 + 主域作用域（eTLD+1）”去重候选；
    - `source_edit_view` 与 `source_edit_legacy_view` 的“清 Cookie”入口改为使用统一候选；
    - 新增 `source_cookie_scope_resolver_test.dart` 覆盖清理候选合并与去重语义。
  - 为什么：对齐 legado `CookieStore.removeCookie` 的主域清理口径，修复子域书源清理后仍可能复用主域会话的问题。
  - 如何验证：
    - `flutter test test/source_cookie_scope_resolver_test.dart`
    - `flutter test test/source_edit_view_compile_test.dart`
    - `flutter test test/source_edit_legacy_view_compile_test.dart`
  - 兼容影响：
    - 仅影响书源编辑页“清 Cookie”的作用域覆盖范围；
    - 原有 URL 作用域清理行为保持不变，新增主域补充清理。

- [x] 2026-02-19：收敛滚动偏移回退语义与书架排序可变性并补回归测试。
  - 做了什么：
    - `SettingsService.saveScrollOffset` 在写入章节键时同步写入书籍键；
    - `SettingsService.getScrollOffset` 在章节键未命中时回退到书籍键；
    - `BookshelfView._loadBooks` 改为先复制可变列表再排序，避免直接修改仓储返回列表。
  - 为什么：对齐 legado 的阅读进度单值回退语义，并消除书架初始化阶段的不可变列表崩溃风险。
  - 如何验证：
    - `flutter test test/app_settings_test.dart`
    - `flutter test test/widget_test.dart`
    - `flutter test`
  - 兼容影响：
    - 仅影响阅读滚动偏移读取回退与书架排序稳定性；
    - 不改变章节偏移键结构与书架排序规则本身。

- [x] 2026-02-19：收敛搜索输入帮助链路语义并补回归测试。
  - 做了什么：
    - 新增 `SearchInputHintHelper`，统一“书架匹配过滤 + 历史词过滤 + 历史词点击触发条件”逻辑；
    - `SearchView` 接入书架书籍流，空态面板新增“书架匹配”区块；
    - 历史词点击改为 legado 同义：当书架存在同名书且当前输入不同，只填充关键字不立即搜索。
  - 为什么：对齐 legado `upHistory/searchHistory` 的输入帮助与触发时机语义，补齐搜索主链路的输入态交互。
  - 如何验证：
    - `flutter test test/search_input_hint_helper_test.dart`
    - `flutter test test/search_scope_test.dart`
  - 兼容影响：
    - 仅影响搜索页输入帮助区块（历史词与书架匹配）；
    - 不改变搜索结果解析、缓存、并发与分页逻辑。

- [x] 2026-02-19：收敛书源调试空输入语义并补回归测试。
  - 做了什么：
    - `SourceDebugQuickActionHelper.normalizeStartKey` 默认 fallback 改为空字符串，不再隐式回退 `"我的"`；
    - `SourceDebugLegacyView._runDebug` 移除 `fallback: '我的'` 传参，调试起始 key 保持用户输入原样。
  - 为什么：对齐 legado `BookSourceDebugActivity` 的输入语义，避免空输入被强制改写成搜索默认词导致链路偏移。
  - 如何验证：
    - `flutter test test/source_debug_quick_action_helper_test.dart`
    - `flutter test test/source_debug_legacy_view_compile_test.dart`
  - 兼容影响：
    - 仅影响书源调试页起始 key 归一逻辑；
    - 不改变 `SourceDebugKeyParser` 分类顺序与 `RuleParserEngine.debugRun` 的执行流程。

- [x] 2026-02-19：收敛书源校验发现链路请求失败语义并补回归验证。
  - 做了什么：
    - `SourceAvailabilityCheckTaskService._runExploreStage` 移除“错误文案命中规则为空即判成功”的启发式分支；
    - 发现阶段请求失败统一标记为失败，并落入 `js失效/网站失效` 分组语义；
    - 清理未再使用的 `_looksLikeRuleMissing` 私有方法。
  - 为什么：对齐 legado `CheckSourceService.doCheckSource` 的失败流转，避免发现链路在真实请求失败场景被误判成功。
  - 如何验证：
    - `flutter test test/source_check_task_config_test.dart`
    - `flutter test test/source_list_view_compile_test.dart`
    - `flutter test test/source_check_source_state_helper_test.dart`
  - 兼容影响：
    - 仅影响书源校验任务中“发现阶段请求失败”的结果分类与分组副作用；
    - 不改变“未配置发现 URL/分类 URL 缺失”时的 `发现规则为空` 语义。

- [x] 2026-02-19：收敛搜索范围选择语义并补回归测试。
  - 做了什么：
    - `search_scope_picker_view` 将分组选择容器从 `Set` 改为 `List`，按用户点击顺序维护多分组；
    - 新增 `SearchScopePickerHelper`，统一筛选字段（name/url/group/comment）与分组选择行为；
    - 书源单选改为 radio 语义（点击同一项不清空选择）；
    - 统一搜索空结果提示文案为 `全部书源`；
    - 新增 `search_scope_picker_helper_test.dart` 与 `search_scope_picker_view_compile_test.dart`。
  - 为什么：对齐 legado `SearchScopeDialog` 与 `R.string.all_source` 的交互与文案语义，消除搜索范围状态流在多分组/单源场景的偏差。
  - 如何验证：
    - `flutter test test/search_scope_test.dart`
    - `flutter test test/search_scope_picker_helper_test.dart`
    - `flutter test test/search_scope_picker_view_compile_test.dart`
    - `flutter test test/search_scope_group_helper_test.dart`
  - 兼容影响：
    - 仅影响搜索页“搜索范围”配置入口（快捷菜单与多分组/单源弹窗）；
    - 不改变搜索请求并发、缓存、结果聚合与分页逻辑。

- [x] 2026-02-19：收敛发现页搜索入口与筛选语义并补回归测试。
  - 做了什么：
    - 发现页“源内搜索”移除关键词弹窗，改为直接进入 `SearchView.scoped`（仅注入单源 scope）；
    - 新增 `DiscoveryFilterHelper`，统一发现页筛选分支（`group:` 精确分组 + 普通关键字仅 `name/group`）；
    - `DiscoveryView` 接入 helper，并移除与 legado 不一致的 URL 命中过滤；
    - 新增 `discovery_filter_helper_test.dart` 与 `discovery_view_compile_test.dart`。
  - 为什么：对齐 legado `ExploreAdapter.menu_search` 与 `BookSourceDao.flowExplore(key)` 语义，消除发现页入口与筛选命中范围偏移。
  - 如何验证：
    - `flutter test test/discovery_filter_helper_test.dart`
    - `flutter test test/discovery_view_compile_test.dart`
  - 兼容影响：
    - 仅影响发现页长按菜单“源内搜索”触发流程与发现列表本地筛选命中字段；
    - 不改变发现入口解析、发现二级页分页加载与书籍详情跳转链路。

- [x] 2026-02-19：收敛搜索下一页继续加载入口语义并补回归测试。
  - 做了什么：
    - `SearchView` 新增“有更多结果，可继续加载下一页”状态面板与 `继续` 按钮，调用 `_loadNextPage`；
    - 保留原有触底自动加载逻辑，避免改动既有分页触发路径；
    - 新增 `SearchLoadMoreHelper`，统一“继续加载入口”显示判定。
  - 为什么：对齐 legado `SearchActivity` 的播放键语义，修复“首屏不足一屏时无法继续加载下一页”的状态流缺口。
  - 如何验证：
    - `flutter test test/search_load_more_helper_test.dart`
    - `flutter test test/search_view_compile_test.dart`
  - 兼容影响：
    - 仅影响搜索页分页触发入口可见性；
    - 不改变搜索请求参数、聚合去重、并发与缓存语义。

- [x] 2026-02-19：收敛搜索输入帮助覆盖层与焦点语义并补回归测试。
  - 做了什么：
    - `SearchView` 新增输入框 `FocusNode` 与 legacy 同义显隐状态机，并将输入帮助改为覆盖层渲染（不再与空结果态绑定）；
    - 提交搜索时统一执行 `unfocus`，补齐 legado `onQueryTextSubmit -> clearFocus` 语义；
    - `SearchInputHintHelper` 新增 `shouldShowInputHelpPanel` 单点判定，覆盖“搜索态/焦点态/结果态/输入态”组合分支。
  - 为什么：对齐 legado `visibleInputHelp` 与布局层级语义，修复“已有结果后编辑输入无法看到输入帮助”的交互偏差。
  - 如何验证：
    - `flutter test test/search_input_hint_helper_test.dart`
    - `flutter test test/search_view_compile_test.dart`
  - 兼容影响：
    - 仅影响搜索页输入帮助面板的显示层级与触发时机；
    - 不改变搜索请求参数、结果聚合、分页与缓存语义。

- [x] 2026-02-19：收敛搜索范围变更触发时机语义并补回归测试。
  - 做了什么：
    - `SearchInputHintHelper` 新增 `shouldAutoSearchOnScopeChanged`，以输入帮助显隐状态机作为 scope 变更后是否自动搜索的唯一判定；
    - `SearchView` 在快捷范围切换（`_updateScopeAndMaybeSearch`）与范围选择器回写（`_openScopePicker`）统一改为该判定，不再“关键字非空即重搜”；
    - 补充 `search_input_hint_helper_test.dart` 覆盖“输入为空/输入帮助可见/输入帮助隐藏”三类分支。
  - 为什么：对齐 legado `searchScope.stateLiveData.observe` 的重搜触发条件，确保 scope 变更仅在输入帮助隐藏时触发搜索。
  - 如何验证：
    - `flutter test test/search_input_hint_helper_test.dart`
    - `flutter test test/search_view_compile_test.dart`
  - 兼容影响：
    - 仅影响搜索范围切换后的自动触发时机；
    - 不改变搜索结果聚合、分页、缓存与请求参数语义。

- [x] 2026-02-19：收敛书架目录更新任务流与更新中状态语义并补回归测试。
  - 做了什么：
    - 新增 `BookshelfCatalogUpdateService`，复用 legado 同义目录刷新语义（详情失败不阻断目录刷新、目录全量写回、逐本结果汇总）；
    - `BookshelfView` 菜单新增“更新目录”入口，并接入批量更新任务流；
    - `_updatingBookIds` 从占位态改为真实状态集，图墙/列表都可展示“更新中” loading 指示；
    - 新增 `bookshelf_catalog_update_service_test.dart` 与 `bookshelf_view_compile_test.dart`。
  - 为什么：对齐 legado `menu_update_toc + MainViewModel.onUpTocBooks + BooksAdapter.upRefresh` 的交互路径与状态流，修复“书架无法批量更新目录、更新中状态不可达”的核心差异。
  - 如何验证：
    - `flutter test test/bookshelf_catalog_update_service_test.dart`
    - `flutter test test/bookshelf_view_compile_test.dart`
  - 兼容影响：
    - 仅影响书架页“更新目录”入口与更新中可视状态；
    - 不改变阅读器内“单本更新目录”入口语义与书源解析规则。

- [x] 2026-02-19：收敛搜索详情目录检索字段语义并补回归测试。
  - 做了什么：
    - 新增 `SearchBookTocFilterHelper`，统一目录检索按 `TocItem.name`（原始标题）匹配，并在过滤后再执行倒序；
    - `search_book_info_view` 的 `_SearchBookTocView` 改为使用 helper，目录展示仍渲染 `displayTitles`；
    - 新增 `search_book_toc_filter_helper_test.dart`，覆盖空关键字、原始标题命中、大小写、倒序与“展示标题不参与命中”分支。
  - 为什么：对齐 legado `BookInfoActivity -> TocActivity -> BookChapterDao.search(title like ...)` 语义，消除展示标题替换带来的检索范围漂移。
  - 如何验证：
    - `flutter test test/search_book_toc_filter_helper_test.dart`
    - `flutter test test/search_book_info_view_compile_test.dart`
  - 兼容影响：
    - 仅影响搜索详情页目录弹窗的检索字段；
    - 目录展示标题链路（简繁转换/替换规则）保持不变。

- [x] 2026-02-19：收敛搜索输入变更继续加载入口语义并补回归验证。
  - 做了什么：
    - `SearchView` 输入框 `onChanged` 在非搜索态新增 `_hasMore` 重置逻辑，输入变更即清空“继续加载下一页”状态；
    - 保留“搜索中输入变更先取消会话”的既有分支，继续沿用 `_cancelOngoingSearch`。
  - 为什么：对齐 legado `SearchActivity.onQueryTextChange` 的“输入变更即隐藏播放键”语义，避免继续入口跨关键词残留。
  - 如何验证：
    - `flutter test test/search_load_more_helper_test.dart`
    - `flutter test test/search_view_compile_test.dart`
  - 兼容影响：
    - 仅影响搜索页输入变更时的继续加载入口显隐；
    - 不改变搜索请求参数、结果聚合、分页抓取与缓存语义。

- [x] 2026-02-19：收敛搜索页返回键焦点语义并补回归验证。
  - 做了什么：
    - `SearchView` 外层新增 `PopScope`，输入框聚焦时拦截返回事件并先执行 `unfocus`；
    - `SearchInputHintHelper` 新增 `shouldConsumeBackToClearFocus` 单点判定方法；
    - `search_input_hint_helper_test.dart` 新增返回语义断言。
  - 为什么：对齐 legado `SearchActivity.finish` 的“先清焦点、后退出”交互路径，避免输入态误触返回直接离开搜索页。
  - 如何验证：
    - `flutter test test/search_input_hint_helper_test.dart`
    - `flutter test test/search_view_compile_test.dart`
  - 兼容影响：
    - 仅影响搜索页返回键在输入聚焦态的处理时机；
    - 不改变搜索结果、范围、分页和缓存链路。

- [x] 2026-02-19：收敛阅读器更新目录流程语义并补回归验证。
  - 做了什么：
    - `SimpleReaderView._refreshCatalogFromSource` 改为复用 `BookshelfCatalogUpdateService.updateBooks`，统一走“完整目录刷新 + 章节重建 + 书籍元数据回写”链路；
    - 移除“新目录必须是旧目录前缀”的增量追加限制，不再抛出“目录结构变化较大，暂不自动合并”；
    - 目录刷新失败提示改为透传服务端逐书失败原因，阅读器与书架更新目录错误语义保持同源。
  - 为什么：对齐 legado `ReadBookActivity.menu_update_toc -> ReadBookViewModel.loadChapterListAwait -> WebBook.getChapterListAwait` 的全量刷新状态流，修复目录重排/插章场景下阅读器刷新目录误失败问题。
  - 如何验证：
    - `flutter test test/bookshelf_catalog_update_service_test.dart`
    - `flutter test test/reader_catalog_sheet_test.dart`
    - `flutter test test/reader_shader_guard_test.dart`
  - 兼容影响：
    - 仅影响阅读器内“更新目录”入口；
    - 刷新后目录不再要求仅末尾追加，章节重排场景会按最新目录完整收敛。

- [x] 2026-02-19：收敛阅读器目录面板 Tab 结构语义并补回归验证。
  - 做了什么：
    - `ReaderCatalogSheet` Tab 结构从“目录/书签/笔记”收敛为 legado 同义“目录/书签”双栏；
    - 移除“笔记”占位分支、搜索占位分支与空态文案分支，避免无实现能力入口外露；
    - `reader_catalog_sheet_test.dart` 新增“双栏收敛”断言，校验“目录/书签”存在且“笔记”入口不存在。
  - 为什么：对齐 legado `TocActivity.TabFragmentPageAdapter` 的两栏结构，消除迁移阶段遗留的扩展入口，避免用户进入不可用流程。
  - 如何验证：
    - `flutter test test/reader_catalog_sheet_test.dart`
  - 兼容影响：
    - 仅影响阅读器目录面板的可见入口结构与分支状态机；
    - 不影响目录检索字段、目录刷新、书签跳转与删除等已对齐能力。

- [x] 2026-02-19：收敛搜索入口初始焦点与首搜触发语义并补回归验证。
  - 做了什么：
    - `SearchView` 初始化对齐 legado `receiptIntent`：空关键词首帧请求输入框焦点，非空关键词首帧自动提交搜索；
    - `SearchInputHintHelper` 新增 `shouldAutoSubmitInitialKeyword/shouldRequestFocusOnOpen`，统一入口判定语义；
    - 移除 `SearchView` 的 `autoSearchOnOpen` 扩展开关，并同步清理 `source_edit_legacy_view` 调用参数。
  - 为什么：对齐 legado 搜索页首次进入状态机，修复“空输入需额外点一次输入框”“初始关键词已填充但未提交”的交互偏差。
  - 如何验证：
    - `flutter test test/search_input_hint_helper_test.dart`
    - `flutter test test/search_view_compile_test.dart`
    - `flutter test test/source_edit_legacy_view_compile_test.dart`
  - 兼容影响：
    - 仅影响搜索页首次进入时的焦点与首搜触发时机；
    - 不改变搜索范围、过滤、分页与缓存链路。

- [x] 2026-02-19：收敛搜索页书源管理入口语义并补回归验证。
  - 做了什么：
    - `SearchView` 的“搜索设置”动作表新增 `书源管理` 选项；
    - 新增 `_openSourceManage`，入口统一跳转 `SourceListView`；
    - 搜索设置动作枚举新增 `sourceManage` 分支，避免与其它设置项耦合。
  - 为什么：对齐 legado `SearchActivity.onCompatOptionsItemSelected` 的 `menu_source_manage` 入口语义，消除“搜索页缺少书源管理直达入口”的交互偏差。
  - 如何验证：
    - `flutter test test/search_view_compile_test.dart`
    - `flutter test test/source_list_view_compile_test.dart`
  - 兼容影响：
    - 仅影响搜索页“搜索设置”动作表的入口结构；
    - 不改变搜索请求、范围、分页、缓存与输入帮助状态流。

- [x] 2026-02-19：收敛搜索精准筛选开关语义并补回归验证。
  - 做了什么：
    - `SearchView` 将“搜索过滤三态”入口收敛为 legado 同义“精准搜索（开/关）”单动作；
    - `AppSettings` 将历史 `searchFilterMode.none` 归一为 `normal`，并在写回时仅持久化 `normal/precise`；
    - `SearchCacheService` 缓存键按精准开关归一，消除 `none/normal` 双键分裂。
  - 为什么：对齐 legado `menu_precision_search + SearchModel.precision` 的单开关语义，移除不必要扩展状态并避免缓存维度漂移。
  - 如何验证：
    - `flutter test test/app_settings_test.dart`
    - `flutter test test/search_cache_service_test.dart`
    - `flutter test test/search_view_compile_test.dart`
  - 兼容影响：
    - 历史配置中的 `searchFilterMode.none` 会自动迁移到 `normal`；
    - 旧 `none` 缓存键不再继续复用，后续将按 `normal` 键重新建立缓存。

- [x] 2026-02-19：收敛搜索页日志入口语义并补回归验证。
  - 做了什么：
    - `SearchView` 的“搜索设置”动作表新增 `日志` 选项；
    - 新增 `_openExceptionLogs`，入口统一跳转 `ExceptionLogsView`；
    - 搜索设置动作枚举新增 `logs` 分支，避免日志入口与其它设置项耦合。
  - 为什么：对齐 legado `SearchActivity.onCompatOptionsItemSelected` 的 `menu_log` 入口语义，消除“搜索页缺少日志直达入口”的层级偏差。
  - 如何验证：
    - `flutter test test/search_view_compile_test.dart`
    - `flutter test test/exception_logs_view_compile_test.dart`
  - 兼容影响：
    - 仅影响搜索页“搜索设置”动作表的入口结构；
    - 不改变搜索请求、范围、分页、缓存与输入帮助状态流。

- [x] 2026-02-19：收敛搜索设置菜单结构与排序语义并补回归验证。
  - 做了什么：
    - `SearchView` 的“搜索设置”动作表收敛为 legacy 同义四项：`精准搜索 -> 书源管理 -> 搜索范围 -> 日志`；
    - 移除 legacy 外扩展动作入口（并发任务、缓存保留、封面开关、清除缓存、清空历史）以及对应分支逻辑；
    - 搜索设置卡片摘要移除“并发”展示，避免与 legado 菜单语义产生误导。
  - 为什么：对齐 legado `book_search.xml + SearchActivity.onCompatOptionsItemSelected` 的菜单结构与排序语义，消除迁移阶段残留扩展入口。
  - 如何验证：
    - `flutter test test/search_view_compile_test.dart`
    - `flutter test test/source_list_view_compile_test.dart`
    - `flutter test test/exception_logs_view_compile_test.dart`
  - 兼容影响：
    - 仅影响搜索页“搜索设置”动作表的可见菜单项与显示顺序；
    - 不改变搜索主链路（请求、范围解析、分页、缓存、输入帮助）语义。

- [x] 2026-02-19：扩展能力分期计划落盘并接入索引。
  - 做了什么：
    - 新增 `docs/plans/2026-02-19-legado-extension-roadmap-execplan.md`，沉淀 RSS/TTS/Dict/Android API 分期步骤与验收路径；
    - 更新 `PLANS.md` 活跃计划索引，接入扩展迁移计划入口。
  - 为什么：将扩展能力从“仅挂账”推进到“可执行分期”，避免后续迭代缺少统一计划基线。
  - 如何验证：
    - `sed -n '1,220p' docs/plans/2026-02-19-legado-extension-roadmap-execplan.md`
    - `sed -n '1,120p' PLANS.md`
  - 兼容影响：
    - 仅文档层改动，不影响现有运行时行为。

## 本批次逐项对照清单（2026-02-19：简繁三态）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 配置模型 | `AppConfig.chineseConverterType` 三态整数 | `ReadingSettings.chineseConverterType` 三态整数，并兼容旧布尔字段 | 已同义 |
| 交互入口 | 阅读配置弹窗三态选择 | 阅读器更多设置、快速设置、设置页均为三态选择 | 已同义 |
| 正文转换 | `ContentProcessor` 按 0/1/2 执行关闭/繁转简/简转繁 | `_postProcessContent` 按 0/1/2 执行同向转换 | 已同义 |
| 标题转换 | `BookChapter.getDisplayTitle` 按 0/1/2 转换 | `_postProcessTitle` 应用于阅读器标题与分页章节标题 | 已同义 |
| T2S 例外词 | `ChineseUtils.fixT2sDict` 维护例外词 | 转换器内置同批例外词并优先匹配 | 已同义 |
| 历史配置兼容 | 旧配置长期存在 | 读取 `chineseTraditional` 并映射到新三态 | 已同义 |

## 本批次逐项对照清单（2026-02-19：目录标题展示链路）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| bookInfo 目录入口展示 | `ChapterListAdapter` 通过 `BookChapter.getDisplayTitle` 渲染 | `_SearchBookTocView` 使用 `displayTitles` 渲染，不再直接使用 `TocItem.name` | 已同义 |
| 简繁设置联动 | `AppConfig.chineseConverterType` 影响目录标题 | 读取 `ReadingSettings.chineseConverterType` 处理目录标题 | 已同义 |
| 标题替换规则联动 | `getDisplayTitle(... replaceRules ...)` 支持标题替换 | 目录弹窗通过 `ReplaceRuleService.applyTitle` 应用标题规则 | 已同义 |
| 目录搜索命中字段 | `BookChapterDao.search` 按原始 `title` 字段匹配 | `_SearchBookTocView` 已改为按 `TocItem.name`（原始标题）过滤，展示继续渲染 `displayTitles` | 已同义 |

## 本批次逐项对照清单（2026-02-19：阅读器目录弹窗标题链路）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 阅读器目录标题展示 | `ChapterListAdapter` 渲染 `getDisplayTitle` | `ReaderCatalogSheet` 渲染 `display title`（非原始 `chapter.title`） | 已同义 |
| 简繁设置联动 | `AppConfig.chineseConverterType` 影响目录标题 | 读取 `ReadingSettings.chineseConverterType` 处理目录标题 | 已同义 |
| 标题替换规则联动 | `getDisplayTitle(... replaceRules ...)` 支持标题替换 | 目录弹窗经 `ChapterTitleDisplayHelper + ReplaceRuleService.applyTitle` 处理 | 已同义 |
| 目录搜索字段语义 | `BookChapterDao.search` 按原始 `title` 字段匹配 | `ReaderCatalogSheet` 保持按原始 `chapter.title` 过滤 | 已同义 |

## 本批次逐项对照清单（2026-02-19：书源调试 key 判定顺序）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| key 判定顺序 | `Debug.startDebug` 先判断 `contains("::")`，再判断 `++/--` | `SourceDebugKeyParser` 已改为同序 | 已同义 |
| 冲突 key 归类 | `++系统::url`/`--系统::url` 走发现链路 | parser 归类为 `explore`，与 `RuleParserEngine.debugRun` 执行链路一致 | 已同义 |
| 调试摘要语义 | UI intent 标签应与实际执行链路一致 | `SourceDebugOrchestrator` 持久化的 `intentType` 与执行链路一致 | 已同义 |

## 本批次逐项对照清单（2026-02-19：换源章节定位）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 定位策略主链路 | `BookHelp.getDurChapter` 使用“窗口估算 -> 标题相似度 -> 章号匹配 -> 回退索引” | `ReaderSourceSwitchHelper.resolveTargetChapterIndex` 已按同序执行 | 已同义 |
| 旧目录规模参与估算 | `oldChapterListSize` 参与估算 `durIndex` | 通过 `oldChapterCount` 参与估算搜索窗口 | 已同义 |
| 输入标题语义 | 定位输入使用阅读进度链路维护的章节标题语义（非 UI 临时展示态） | 换源入口改为传入章节原始标题，不再依赖 `_currentTitle` 展示文本 | 已同义 |
| 边界回退 | `oldDurChapterIndex<=0` 直接回退 0；空目录时保留旧索引 | 同步实现上述边界策略 | 已同义 |

## 本批次逐项对照清单（2026-02-19：18+ 域名主域提取）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 主域提取口径 | `NetworkUtils.getSubDomain` 采用主域语义（eTLD+1） | 导入拦截复用 `SourceHostGroupHelper.groupHost`（含多段后缀） | 已同义 |
| 18+ 拦截命中 | `SourceHelp.is18Plus` 以主域参与匹配 | `_isBlockedByDomain` 以主域参与匹配，不再固定“最后两段” | 已同义 |
| 多段后缀场景 | `reader.news.co.uk` 主域应为 `news.co.uk` | 新增回归测试覆盖并通过 | 已同义 |

## 本批次逐项对照清单（2026-02-19：清 Cookie 主域作用域）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 清理入口语义 | 编辑页“清 Cookie”调用 `CookieStore.removeCookie(url)` | 两个编辑页均统一调用 `SourceCookieScopeResolver.resolveClearCandidates` 后逐项删除 | 已同义 |
| 主域口径 | `removeCookie` 使用 `NetworkUtils.getSubDomain`（eTLD+1） | 清理候选补充 `resolveDomainCandidates`（含 eTLD+1） | 已同义 |
| 子域场景 | 子域 URL 清理应覆盖主域 Cookie | `https://sub.a.example.co.uk/path` 清理候选含 `https://example.co.uk` | 已同义 |
| 多段后缀场景 | `.co.uk/.com.cn` 需按主域处理 | 通过 `SourceHostGroupHelper.groupHost` 产出主域候选并回归测试覆盖 | 已同义 |

## 本批次逐项对照清单（2026-02-19：滚动偏移回退与书架排序可变性）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 阅读偏移持久化基线 | `ReadBook.saveRead` 始终维护 `Book.durChapterPos` 单值进度 | `saveScrollOffset` 在章节写入时同步写入书籍级偏移键 | 已同义 |
| 章节偏移未命中回退 | 读取链路自然回退到同一 `durChapterPos` 语义 | `getScrollOffset(chapterIndex)` 未命中时回退书籍级偏移键 | 已同义 |
| 书架排序实现方式 | 排序通过 `sortedBy/sortedWith` 产生新列表，不修改上游数据 | `_loadBooks` 先 `List.from(...)` 再排序，避免对不可变列表原地修改 | 已同义 |
| 运行时稳定性 | 书架加载不应因数据容器可变性崩溃 | `widget_test` 回归通过，`Unsupported operation` 不再复现 | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索输入帮助链路）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 输入帮助组成 | `upHistory` 在非空输入时同时更新书架匹配与历史词列表 | 空态面板已接入“书架匹配 + 历史词过滤”双区块 | 已同义 |
| 书架匹配规则 | `BookDao.flowSearch(key)` 按书名/作者匹配 | `SearchInputHintHelper.filterBookshelfBooks` 按书名/作者匹配 | 已同义 |
| 历史词过滤规则 | `SearchKeywordDao.flowSearch(key)` 按关键字过滤 | `SearchInputHintHelper.filterHistoryKeywords` 按关键字过滤 | 已同义 |
| 历史词点击触发时机 | `searchHistory`：同名书存在且当前输入不同时仅填充，不立即搜索 | `shouldSubmitHistoryKeyword` 复刻同一分支条件 | 已同义 |
| 书架快捷入口 | 点击书架匹配项进入书籍详情 | 搜索页“书架匹配”项已接入 `SearchBookInfoView.fromBookshelf` | 已同义 |

## 本批次逐项对照清单（2026-02-19：书源调试空输入语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 调试起始 key 默认值 | `onQueryTextSubmit` 仅在 `query == null` 时回退 `"我的"` | `normalizeStartKey` 默认不再注入 `"我的"`，空输入保持空值 | 已同义 |
| 视图层调用参数 | `startSearch(query ?: "我的")` 使用当前输入值 | `_runDebug` 不再传 `fallback: '我的'`，保持 `_debugKeyCtrl` 原始输入 | 已同义 |
| 快捷 fallback 能力 | 文本按钮“我的/系统”由用户显式触发 | `normalizeStartKey(... fallback: ...)` 仍支持调用方显式 fallback | 已同义 |

## 本批次逐项对照清单（2026-02-19：书源校验发现链路失败语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 发现规则为空触发条件 | 仅在 `exploreKinds().firstOrNull { url 非空 }` 为空时标记 `发现规则为空` | 仅在 `_resolveFirstExploreUrl` 返回 `null` 时进入 `发现规则为空` 分支 | 已同义 |
| 发现请求失败语义 | 已进入发现请求后，异常应落入失败分支并携带错误 | `_runExploreStage` 在 `fetch.body == null` 时统一判定失败并保留错误信息 | 已同义 |
| 失败分组副作用 | 失败时应标记 `网站失效/js失效`，不保留 `发现规则为空` 成功语义 | 失败分支统一添加 `网站失效/js失效` 并移除 `发现规则为空` | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索范围选择语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 全部书源文案 | `R.string.all_source` 中文为 `全部书源` | `SearchScope.display` 与搜索空结果提示统一为 `全部书源` | 已同义 |
| 多分组顺序语义 | `selectGroups` 按用户点击顺序写回 scope | 分组选择按点击顺序维护，确认时按同序生成 `groupA,groupB` | 已同义 |
| 书源筛选字段 | `flowSearch` 覆盖 `name/group/url/comment` | `SearchScopePickerHelper.filterSourcesByQuery` 覆盖同四字段 | 已同义 |
| 单源选择交互 | radio 语义：点击同一项不反选为未选 | 书源点击始终置当前项，不再二次点击清空 | 已同义 |
| 确认回退语义 | 书源模式未选中时确认回退 `全部书源` | `_submit` 在 `source + null` 场景返回空 scope | 已同义 |

## 本批次逐项对照清单（2026-02-19：发现页搜索入口与筛选语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 源内搜索入口层级 | `ExploreAdapter.menu_search` 直接跳转 `SearchActivity` 并传 `searchScope` | `DiscoveryView._searchInSource` 直接跳转 `SearchView.scoped(sourceUrls)`，无关键词弹窗 | 已同义 |
| 源内搜索触发时机 | 进入搜索页后由用户决定是否提交关键词 | 移除 `initialKeyword + autoSearchOnOpen` 强制搜索分支 | 已同义 |
| 普通关键字筛选字段 | `flowExplore(key)` 仅按 `bookSourceName/bookSourceGroup` 匹配 | `DiscoveryFilterHelper.applyQueryFilter` 普通分支仅匹配 `name/group` | 已同义 |
| `group:` 分支语义 | 前缀 `group:` 触发分组精确匹配 | helper 保持 `group:` 分支并按拆分后的分组项精确命中 | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索下一页继续加载入口语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 下一页手动入口 | 搜索结束且 `hasMore=true` 时显示播放键，可手动继续 | 搜索页新增“继续”入口，满足 `!isSearching && hasMore && resultCount>0` 时显示 | 已同义 |
| 非滚动场景可达性 | 结果不足一屏仍可通过播放键继续拉取下一页 | 不依赖滚动监听，点击“继续”可触发 `_loadNextPage` | 已同义 |
| 自动触底加载 | 滚动到底仍可继续拉取 | 原 `_onResultScroll` 触底加载逻辑保留 | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索输入帮助覆盖层与焦点语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 输入帮助显隐状态机 | `visibleInputHelp`：搜索中隐藏；非搜索按“焦点 + 结果 + 输入”切换 | `SearchInputHintHelper.shouldShowInputHelpPanel` 复刻同序判定 | 已同义 |
| 输入帮助布局层级 | `ll_input_help` 为与结果列表同级覆盖层 | 搜索页改为 `Stack + Positioned.fill` 覆盖层，不再仅作为空态子树 | 已同义 |
| 提交搜索焦点流转 | `onQueryTextSubmit` 先 `clearFocus` 再搜索 | `_search()` 入口先 `unfocus` 再执行搜索流程 | 已同义 |
| 输入变化后的帮助可达性 | 结果存在时，输入框聚焦可实时显示“书架匹配 + 历史词” | 结果列表存在时输入框聚焦仍显示输入帮助覆盖层 | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索范围变更触发时机）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 自动重搜触发前置条件 | `searchScope.stateLiveData` 回调中仅在 `!llInputHelp.isVisible` 时 `setQuery(..., true)` | `SearchInputHintHelper.shouldAutoSearchOnScopeChanged` 仅在输入帮助隐藏时返回 true | 已同义 |
| 快捷范围菜单入口 | 范围菜单切换后沿用同一输入帮助判定决定是否重搜 | `_updateScopeAndMaybeSearch` 改为 helper 判定，不再“关键字非空即重搜” | 已同义 |
| 多分组/单源选择器入口 | 对话框确认后沿用同一输入帮助判定决定是否重搜 | `_openScopePicker` 回写范围后改为 helper 判定，语义与快捷入口一致 | 已同义 |

## 本批次逐项对照清单（2026-02-19：书架目录更新任务流与更新中状态）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 书架更新入口 | `menu_update_toc` 触发 `upToc(books)` 批量更新目录 | 书架菜单新增“更新目录”，触发 `BookshelfCatalogUpdateService.updateBooks(_books)` | 已同义 |
| 更新中状态源 | `MainViewModel.onUpTocBooks` 维护书籍更新中集合，适配器通过 `isUpdate(bookUrl)` 判定 | `BookshelfView` 通过 `onBookUpdatingChanged` 维护 `_updatingBookIds`，逐本开始/结束回调同步 UI | 已同义 |
| 图墙更新中显示 | `BooksAdapterGrid.upRefresh`：更新中显示 loading，非更新显示未读徽标 | 图墙卡片沿用同语义：更新中显示 loading，非更新显示未读角标 | 已同义 |
| 列表更新中显示 | `BooksAdapterList.upRefresh`：更新中显示 loading | 列表项尾部新增 loading 指示，更新结束恢复右箭头 | 已同义 |
| 刷新写回语义 | `updateToc` 更新目录后回写书籍元数据与章节列表 | 服务端按“清旧目录 + 写新目录 + 回写 total/latest/current/source/bookUrl”执行 | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索详情目录检索字段语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 检索字段语义 | `BookChapterDao.search` 使用 `title like`（原始章节标题） | `SearchBookTocFilterHelper` 统一按 `TocItem.name` 过滤 | 已同义 |
| 展示与检索关系 | `ChapterListAdapter` 展示 `getDisplayTitle`，检索仍走 `title` 字段 | `_SearchBookTocView` 展示 `displayTitles`，检索独立走原始标题 | 已同义 |
| 倒序处理时机 | 目录顺序变化不应改变检索字段来源 | helper 先过滤后倒序，且过滤始终基于原始标题字段 | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索输入变更继续加载入口语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 输入变更时继续入口显隐 | `onQueryTextChange` 触发后，播放键立即隐藏 | `SearchView.onChanged` 在非搜索态输入变更时重置 `_hasMore`，立即隐藏“继续”入口 | 已同义 |
| 搜索中输入变更语义 | 输入变化先 `stop()` 终止当前搜索 | 搜索中输入变化仍走 `_cancelOngoingSearch` 终止会话 | 已同义 |
| 继续入口触发上下文 | 仅对当前关键词搜索结果会话有效 | “继续”入口仅在当前关键词完成搜索且 `hasMore=true` 时显示 | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索页返回键焦点语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 返回键焦点优先级 | `SearchActivity.finish`：搜索框有焦点时先 `clearFocus()` 并阻止退出 | `SearchView` 通过 `PopScope` 在输入框聚焦时先 `unfocus`、阻止 pop | 已同义 |
| 无焦点返回行为 | 输入框无焦点时执行正常页面退出 | `PopScope.canPop` 在无焦点时为 `true`，返回直接退出 | 已同义 |
| 判定收敛 | 由 `SearchView` 内部焦点状态驱动 | `SearchInputHintHelper.shouldConsumeBackToClearFocus` 统一判定 | 已同义 |

## 本批次逐项对照清单（2026-02-19：阅读器更新目录流程语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 刷新链路主干 | `menu_update_toc` 调用 `loadChapterListAwait`，目录按全量重拉后整库替换 | 阅读器刷新入口改为复用 `BookshelfCatalogUpdateService.updateBooks`，执行“清旧目录 + 写新目录 + 回写书籍元数据” | 已同义 |
| 详情失败容错 | 目录刷新主链路不应被详情请求失败阻断（`getChapterListAwait` 主导） | 刷新目录不再强依赖 `getBookInfo` 成功，详情失败会继续目录拉取 | 已同义 |
| 目录结构变化处理 | 目录重排/插章时仍可刷新完成，不要求旧目录是新目录前缀 | 移除 `_isUrlPrefix` 限制，不再抛出“目录结构变化较大，暂不自动合并” | 已同义 |
| 错误语义一致性 | 阅读器与书架目录刷新失败原因均落到统一错误提示链路 | 阅读器刷新失败直接复用 `BookshelfCatalogUpdateService` 失败摘要 | 已同义 |

## 本批次逐项对照清单（2026-02-19：阅读器目录面板 Tab 结构）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| Tab 入口层级 | `TocActivity.TabFragmentPageAdapter` 固定两栏（章节/书签） | `ReaderCatalogSheet` 已收敛为两栏（目录/书签） | 已同义 |
| 搜索分支覆盖范围 | 搜索状态机仅覆盖目录与书签 | 搜索占位与过滤分支仅保留目录/书签两链路 | 已同义 |
| 无效入口控制 | 不暴露未迁移能力入口 | 已移除“笔记”占位入口与空态文案分支 | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索入口初始焦点与首搜触发语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 空关键词入场焦点 | `receiptIntent` 在 `key` 为空时请求搜索框焦点 | `SearchView.initState` 空 `initialKeyword` 首帧执行 `_searchFocusNode.requestFocus()` | 已同义 |
| 非空关键词首搜触发 | `receiptIntent` 在 `key` 非空时 `setQuery(key, true)` 自动提交搜索 | `SearchView.initState` 非空 `initialKeyword` 首帧执行 `_search()`，并沿用现有搜索状态流 | 已同义 |
| 扩展开关收敛 | 不存在额外“首搜是否自动触发”开关 | 已移除 `autoSearchOnOpen` 参数，首搜触发仅由 `initialKeyword` 是否非空决定 | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索页书源管理入口）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 搜索页书源管理入口 | 菜单包含 `menu_source_manage`，点击直接跳转 `BookSourceActivity` | 搜索设置动作表新增“书源管理”，点击直达 `SourceListView` | 已同义 |
| 入口层级 | 入口位于搜索页内部，不需绕行其它页面 | 搜索页内可直接打开书源管理，无需返回设置主页 | 已同义 |
| 状态隔离 | 打开书源管理不应重置当前搜索态 | 跳转行为仅新增页面导航，不改动搜索会话状态字段 | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索精准筛选开关语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 精准搜索入口结构 | `book_search.xml` 仅保留 `menu_precision_search` 勾选项 | 搜索设置动作表收敛为“精准搜索”单项，展示 `开启/关闭` 状态 | 已同义 |
| 开关切换触发时机 | `onCompatOptionsItemSelected` 切换后对当前 query 触发 `setQuery(..., true)` 重搜 | `_togglePrecisionSearchLikeLegado` 切换后在关键字非空时立即 `_search()` | 已同义 |
| 配置模型语义 | `precisionSearch` 布尔开关 | `searchFilterMode` 运行时与持久化均归一为 `normal/precise`（`none` 仅兼容读取） | 已同义 |
| 缓存维度语义 | 精准开关仅分“开/关”两类搜索结果 | `buildCacheKey` 统一输出 `normal/precise`，`none` 与 `normal` 同键 | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索页日志入口语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 搜索页日志入口 | `book_search.xml` 含 `menu_log`，点击后进入日志面板 | 搜索设置动作表新增 `日志`，点击直达 `ExceptionLogsView` | 已同义 |
| 入口层级 | 日志入口位于搜索页菜单内部，无需绕行设置 | 搜索页内一跳进入日志页 | 已同义 |
| 状态隔离 | 打开日志不应重置搜索会话状态 | 跳转行为仅新增页面导航，不改动搜索会话字段 | 已同义 |

## 本批次逐项对照清单（2026-02-19：搜索设置菜单结构与排序语义）

| 对照项 | legado 基准 | soupreader 当前 | 结论 |
|---|---|---|---|
| 菜单项数量与结构 | `book_search.xml` 固定四项（精准搜索、书源管理、搜索范围、日志） | 搜索设置动作表已收敛为同义四项 | 已同义 |
| 菜单顺序 | `menu_precision_search -> menu_source_manage -> menu_search_scope -> menu_log` | 动作表顺序已调整为“精准搜索 -> 书源管理 -> 搜索范围 -> 日志” | 已同义 |
| 扩展入口控制 | 搜索菜单不暴露 legacy 外扩展项 | 已移除并发、缓存、封面、清缓存、清历史等扩展动作入口 | 已同义 |
| 入口触发语义 | 四项动作分别对应精准开关、书源管理、范围配置、日志查看 | 四项动作触发逻辑分别对应 `_togglePrecisionSearchLikeLegado/_openSourceManage/_showScopeQuickSheet/_openExceptionLogs` | 已同义 |

## Surprises & Discoveries

1. 阅读器“繁体显示”开关已接入设置，但实际转换逻辑此前为 no-op。
2. 当前仿真翻页已使用 Shader 实现，但缺少自动化回归守护。
3. 设置中“暂未实现”入口较多，若不统一文案会与当前策略冲突。
4. 单纯字符映射会把部分词组转换错误（如“理发”->“理發”），必须引入短语优先策略。
5. legado 的繁转简路径存在例外词（`fixT2sDict`）；若不补齐，会在港台词汇上产生误转。
6. 搜索详情页目录弹窗此前复用了原始 TOC 数据，但没有复用标题展示处理链路，导致目录可见语义落后于阅读器。
7. 阅读器目录弹窗同样存在“原始标题直出”问题，且入口比 `bookInfo -> toc` 使用频次更高，需优先补齐展示链路。
8. 调试 key 解析器若不与 `Debug.startDebug` 同序，会出现“调试摘要显示目录/正文，但执行链路实际走发现”的错位。
9. 换源定位此前使用 `_currentTitle`（展示标题）参与匹配，在简繁转换/标题替换开启时会放大定位误差。
10. 18+ 域名拦截若仅按“最后两段”截取主域，会在 `.co.uk/.com.cn` 等场景与 legado 主域语义偏离。
11. 编辑页“清 Cookie”若仅按原 URL 主机清理，子域书源在主域 Cookie 未删除时会继续命中旧会话。
12. 全量测试揭示了两个隐藏回归：章节滚动偏移缺少书籍级回退，以及书架初始化对不可变列表原地排序导致崩溃。
13. 搜索页输入帮助此前仅保留历史词卡片，缺少书架联动与历史词触发分支，导致输入阶段的状态流与 legado 偏离。
14. 复核 `BookSourceDebugActivity` 后发现，调试页并不会把空输入强制归一到 `"我的"`；该 fallback 仅适用于调用方显式传参场景。
15. 复核 `CheckSourceService.doCheckSource` 后发现，发现链路只有“分类 URL 缺失”才是 `发现规则为空`；一旦进入请求阶段失败必须记为失败，不能按文案启发式回退为成功。
16. 复核 `SearchScopeDialog` 后发现，分组 scope 的写回顺序不是“全局分组顺序”，而是“用户点击顺序”；若用 `Set + 全量分组顺序回放` 会造成状态文本漂移。
17. 复核 `ExploreAdapter.menu_search` 与 `BookSourceDao.flowExplore(key)` 后发现，发现页“源内搜索”不应弹关键词输入框，且普通关键字筛选不应按 URL 命中。
18. 复核 `SearchActivity.searchFinally + fbStartStop` 后发现，legado 在 `hasMore=true` 时始终保留显式继续入口；仅依赖滚动事件会在首屏不足一屏时丢失后续页触发点。
19. 复核 `SearchActivity.visibleInputHelp` 与 `activity_book_search.xml` 后发现，legado 的输入帮助是独立覆盖层而非空态区域；若仅在“无结果”时展示会丢失焦点驱动语义。
20. 复核 `SearchActivity.searchScope.stateLiveData.observe` 后发现，scope 变更是否立即重搜受 `llInputHelp` 显隐约束；“关键字非空即重搜”会让输入态切换范围时机提前。
21. 复核 `BookshelfView` 时发现 `_updatingBookIds` 只存在占位注释且没有任何任务流写入，导致“更新中”角标分支永远不可达。
22. 复核 `BookInfoActivity -> TocActivity -> BookChapterDao.search` 后发现，legado 目录检索始终基于原始 `title` 字段；若按展示标题过滤会被简繁/替换规则放大命中范围。
23. 复核 `SearchActivity.onQueryTextChange` 后发现，legado 会在输入变更时立即隐藏播放键；若本地不清空 `_hasMore`，继续入口会跨关键词残留。
24. 复核 `SearchActivity.finish` 后发现，搜索页返回键语义受输入焦点影响；若未拦截返回，输入态会直接退页并中断当前检索上下文。
25. 复核 `ReadBookActivity.menu_update_toc` 与 `ReadBookViewModel.loadChapterListAwait` 后发现，legado 的“更新目录”是全量刷新语义；本地“仅前缀追加”策略会在目录重排时误报失败。
26. 复核 `TocActivity.TabFragmentPageAdapter` 后发现，legado 目录页仅有“章节/书签”两栏；本地遗留“笔记”占位入口会形成可见但不可用的扩展分支。
27. 复核 `SearchActivity.receiptIntent` 后发现，legado 进入搜索页时会按 `key` 空/非空切换“自动聚焦/自动提交搜索”；本地把首搜触发挂到扩展参数上，导致入口状态机偏离。
28. 复核 `SearchActivity.onCompatOptionsItemSelected` 后发现，legado 搜索页内置“书源管理”直达入口；本地迁移过程中该入口缺失，导致管理路径层级偏深。
29. 复核 `SearchModel.precision` 后发现，本地 `none/normal` 虽行为近似，但会造成缓存键分裂与入口文案冗余，需按“精准开关”统一收敛。
30. 复核 `book_search.xml` 与 `SearchActivity.onCompatOptionsItemSelected` 后发现，legado 搜索页始终保留 `menu_log` 日志入口；本地未补齐时，异常定位需绕行设置页，入口层级偏离。
31. 复核 `book_search.xml` 后发现，legado 搜索菜单只有四项且顺序固定；本地“搜索设置”仍挂载并发/缓存/封面等扩展动作，会直接造成菜单结构与排序偏差。

## Decision Log

1. 采用“核心优先 + 扩展挂账”执行策略，不在本阶段实现 RSS/TTS/字典。
2. 简繁转换采用“OpenCC 短语覆盖 + 字符映射”同步策略，保证调用链不改为异步。
3. 明确保留 `lib/features/reader/shaders/page_curl.frag` 作为仿真翻页主实现路径。
4. 采用“一次迁移”策略直接收敛简繁三态：数据模型、UI 入口、正文/标题链路与兼容读取同批落地，避免阶段性语义漂移。
5. 复刻 legado 的 T2S 例外词策略，在繁转简路径中加入同批词典并设为短语优先。
6. 目录标题展示逻辑抽为 `chapter_title_display_helper`，优先让 `bookInfo -> toc` 与 legado 同义，再逐步扩展到其它目录入口复用。
7. 阅读器目录弹窗继续复用 `chapter_title_display_helper`，并采用“初始缓存 + 异步增量解析”策略，兼顾展示同义与大目录性能。
8. 调试 key 的判定顺序以 `Debug.startDebug` 为单一基准，解析器与执行器保持同序，避免摘要/日志语义漂移。
9. 换源章节定位直接复刻 `BookHelp.getDurChapter` 的核心决策顺序，并保留 `oldChapterIndex<=0` 的早返回语义，避免行为漂移。
10. 导入拦截主域提取统一复用 `SourceHostGroupHelper`，以单点规则收敛多段后缀域名语义，避免重复实现漂移。
11. 清 Cookie 作用域统一由 `SourceCookieScopeResolver` 产出，明确覆盖 URL 与主域两层候选，避免各编辑页各自实现造成语义分叉。
12. 滚动偏移保持“章节键优先 + 书籍键回退”策略，且章节写入同步书籍键，以兼容旧键和 legado 单值进度语义。
13. 搜索输入帮助抽为 `SearchInputHintHelper` 单点决策，统一历史词过滤、书架匹配与“是否立即搜索”判定，避免 UI 层重复分支。
14. 书源调试起始 key 以 legado `BookSourceDebugActivity` 为准，不在 helper/视图层注入隐式 `"我的"` 回退，避免输入语义漂移。
15. 书源校验发现链路移除“规则为空文案即成功”的启发式特判，统一以 legado 的状态流转为准：进入请求后失败即失败。
16. 搜索范围选择收敛到“helper 单点决策 + 视图轻状态”模式，确保分组顺序、筛选字段、单源选择与文案统一复刻 legado 语义。
17. 发现页筛选抽离到 `DiscoveryFilterHelper` 单点决策，并移除“源内搜索关键词弹窗”扩展流程，确保入口层级与筛选命中范围严格对齐 legado。
18. 搜索分页入口采用“双通道”策略：保留触底自动加载，同时补齐显式“继续”入口，确保非滚动场景与 legado 同步可达。
19. 搜索输入帮助采用“helper 状态机 + 视图覆盖层”双层收敛策略，确保显隐条件与布局层级同时对齐 legado，避免只改其一造成行为漂移。
20. 搜索范围变更后的自动重搜统一绑定输入帮助状态机判定，确保快捷菜单与多分组/单源选择器入口触发时机同义。
21. 书架目录更新采用“service 统一编排 + 视图仅维护状态集”策略，避免把目录更新网络链路直接堆叠到 `BookshelfView` 导致后续状态回归困难。
22. 搜索详情目录采用“展示与检索解耦”策略：展示继续走 `ChapterTitleDisplayHelper`，检索统一回落到原始 `TocItem.name` 字段，复刻 legado `title like` 语义。
23. 搜索输入变更后继续入口采用“输入即重置 hasMore”策略，确保播放键语义与当前关键词会话强绑定，避免跨会话续页。
24. 搜索页返回链路采用“焦点优先”策略：当输入框聚焦时优先消费返回并清焦点，确保输入帮助与范围切换的状态机不被提前中断。
25. 阅读器刷新目录入口复用 `BookshelfCatalogUpdateService`，统一书架与阅读器的目录更新状态流与失败语义，避免双实现分叉。
26. 阅读器目录面板 Tab 结构收敛到 legado 双栏（目录/书签），移除“笔记”占位分支，避免迁移阶段暴露无实现能力入口。
27. 搜索入口初始化收敛到 legado `receiptIntent` 单一状态机：空关键词首帧聚焦、非空关键词首帧自动提交，并移除 `autoSearchOnOpen` 扩展开关，避免首搜触发时机分叉。
28. 搜索页设置菜单补齐 legado 同义“书源管理”入口，采用单独 action 枚举分支跳转 `SourceListView`，避免后续设置项扩展时入口语义回退。
29. 搜索过滤策略保留 `SearchFilterMode.none` 仅作历史兼容，不再暴露为用户入口；运行时、持久化与缓存键统一归一到 legado 同义“精准开关”双态。
30. 搜索页设置菜单补齐 legado 同义“日志”入口，复用现有 `ExceptionLogsView` 作为日志承载页，保持入口层级同义且避免新增日志实现分叉。
31. 搜索页设置菜单结构按 legado `book_search.xml` 固定为四项并按同序展示，移除 legacy 外扩展动作，避免迁移阶段保留多余入口导致行为偏差。
32. 扩展能力迁移拆分为独立 ExecPlan（RSS/TTS/Dict/Android API），确保扩展项以阶段化交付推进，不与核心链路回归混写。

## Outcomes & Retrospective

- 当前结果：已完成计划基础设施、核心缺口（简繁双向）修复（含短语级语义与 T2S 例外词）、搜索详情页与阅读器目录弹窗的标题展示链路对齐、Shader 守护测试与扩展文案对齐、书源调试 key 判定顺序对齐、换源章节定位语义对齐、18+ 域名拦截主域提取语义对齐、编辑页清 Cookie 主域作用域语义对齐、滚动偏移回退与书架排序可变性修复、搜索输入帮助链路语义对齐、书源调试空输入语义对齐、书源校验发现链路失败语义对齐、搜索范围选择语义对齐、发现页搜索入口与筛选语义对齐、搜索下一页继续加载入口语义对齐、搜索输入帮助覆盖层与焦点语义对齐、搜索范围变更触发时机语义对齐、书架目录更新任务流与更新中状态语义对齐、搜索详情目录检索字段语义对齐、搜索输入变更继续加载入口语义对齐、搜索页返回键焦点语义对齐、阅读器更新目录流程语义对齐、阅读器目录面板 Tab 结构语义对齐、搜索入口初始焦点与首搜触发语义对齐、搜索页书源管理入口语义对齐、搜索精准筛选开关语义对齐、搜索页日志入口语义对齐、搜索设置菜单结构与排序语义对齐，并完成扩展能力分期计划（RSS/TTS/Dict/Android API）落盘与索引接入。
- 下一步改进：
  1. 推进核心链路逐项对照（尤其异常边界与状态流）。
  2. 继续收敛其它目录入口的标题处理顺序（含替换规则与简繁转换的执行时机）与 legado 保持同义。
  3. 按 `docs/plans/2026-02-19-legado-extension-roadmap-execplan.md` 启动 Phase A（RSS）首批实现。
