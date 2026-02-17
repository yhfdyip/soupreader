# DEV Progress

## 2026-02-17 - 书源管理页语义收敛（管理流程与排版结构）

### 做了什么
- `lib/features/source/views/source_list_view.dart`
  - 管理页结构收敛为“搜索 + 列表 + 批量操作栏”主流程，移除页面内校验/调试摘要条与相关筛选状态。
  - 顶部入口收敛：
    - 保留导入菜单（新建、扫码、文件、网络）。
    - 管理菜单改为“排序选项、分组筛选、分组管理、按域名分组、帮助”。
  - 分组筛选改为 legado 同语义：
    - 静态项：启用/禁用/需登录/无分组/启用发现/禁用发现。
    - 动态项：从书源 `bookSourceGroup` 拆分去重后生成，并按中文比较规则排序。
  - 排序语义修正：
    - 名称排序与“启用状态”次级排序改为中文比较规则。
    - 更新时间在升序模式下改为“新到旧”（与 legado 相同）。
  - 列表项交互收敛：
    - 常驻勾选（不再依赖选择模式开关）。
    - 独立编辑按钮 + 更多菜单。
    - 更多菜单顺序调整为：置顶、置底、登录、搜索、调试、删除、发现启停（按条件显示）。
  - 批量操作栏改造：
    - 常驻显示，支持全选/反选/区间补选。
    - 操作集合与顺序收敛为：删除、启用、禁用、加分组、移分组、启发现、停发现、置顶、置底、导出、分享、校验。
  - 分组管理边界修正：
    - 重命名分组允许空值，空值场景等价于移除原分组（不再直接返回）。

### 为什么
- 当前管理页存在多处非核心入口与结构扩展，导致书源管理主流程路径与操作节奏偏离。
- 部分关键排序与分组边界语义（更新时间方向、中文排序、分组重命名空值处理）与基准行为存在偏差，需要统一收敛。

### 如何验证
- 静态检查：
  - `flutter analyze`
- 相关回归：
  - `flutter test test/search_scope_group_helper_test.dart`
  - `flutter test test/source_import_export_conflict_logic_test.dart`
  - `flutter test test/source_filter_helper_test.dart`

### 兼容影响
- **有兼容影响（界面与交互路径）**：
  - 管理页入口布局和可见操作将更聚焦主流程，部分原有扩展入口不再在管理页直接展示。
- **逻辑影响（正向）**：
  - 排序与分组相关行为更稳定（中文排序、更新时间方向、分组重命名空值语义）。

## 2026-02-15 - legado 全链路语义对齐（除仿真翻页）

### 做了什么
- `lib/features/source/services/rule_parser_engine.dart`
  - 目录链路对齐 legado：
    - `preUpdateJs` 改为“目录前置执行”（不再改写目录响应体）。
    - 目录解析补齐 `isVolume/isVip/isPay/tag` 字段（JSON/HTML 双路径）。
    - 章节链接为空时新增 legado 回退：卷使用 `title+index`，非卷使用当前目录页 URL。
    - 目录后处理与去重后保留上述元字段，不再丢失。
    - 目录分页移除固定小上限（原 12），改为 visited/队列驱动并保留安全阈值（1000）。
  - 正文链路对齐 legado：
    - `ruleContent.content` 为空时，直接返回章节链接（普通/调试接口一致）。
    - 正文分页移除固定小上限（原 8），改为 visited/队列驱动并保留安全阈值（1000）。
  - 登录检查对齐 legado：
    - 在 `_fetch/_fetchDebug` 注入 `loginCheckJs`，统一覆盖搜索、发现、详情、目录、正文与调试链路。
  - 调试链路一致性：
    - `_debugTocThenContent`、`_debugContentOnly` 同步采用上述目录/正文语义。
  - `TocItem` 模型扩展并默认值兼容：新增 `isVolume/isVip/isPay/tag`。

- `lib/features/search/views/search_view.dart`
  - 搜索聚合与过滤对齐 legado `SearchModel`：
    - 去除大小写/空白归一化比较。
    - 分组键使用原始 `name+author`（按 `==` 语义归并）。
    - 排序分桶使用原始 `== / contains`（区分大小写）。
    - 精准过滤改为原始 `contains`（不过度归一化）。

- 测试补充与调整
  - `test/rule_parser_engine_stage_js_compat_test.dart`
    - 更新 `preUpdateJs` 语义测试为“前置执行，不改写响应体”。
    - 新增 `loginCheckJs` 在搜索、发现、详情、目录、正文（含 `getContentDebug`）生效测试。
    - 新增“正文规则为空返回章节链接”测试。
  - `test/rule_parser_engine_next_url_compat_test.dart`
    - 新增目录元字段保留与 `chapterUrl` 回退测试。
    - 新增目录分页超过 12 页与正文分页超过 8 页的回归测试。

### 为什么
- 当前实现与 legado 在关键规则语义上仍存在偏差（`loginCheckJs`、`preUpdateJs`、正文空规则、分页上限、搜索聚合比较规则），会导致部分旧书源行为与调试结果不一致。
- 本次目标是按要求将书源处理行为对齐到 legado（仅排除仿真翻页）。

### 如何验证
- 自动校验：`flutter analyze`
- 关键回归：
  - `test/rule_parser_engine_stage_js_compat_test.dart`
  - `test/rule_parser_engine_next_url_compat_test.dart`

### 兼容影响
- **有兼容影响（正向）**：
  - 旧书源中依赖 `loginCheckJs`、目录 `isVolume/isVip/isPay/tag`、空正文规则和多页正文/目录的场景将更贴近 legado 原行为。
- **行为变化点**：
  - `preUpdateJs` 不再作为目录响应改写脚本使用，而是目录前置执行语义；依赖其“改写响应体”的非 legado 用法将不再生效。

## 2026-02-16 - legado BookList 语义对齐（搜索/发现）

### 做了什么
- `lib/features/source/services/rule_parser_engine.dart`
  - 新增并接入统一列表解析内核（主链路与调试链路复用）：
    - `_resolveBookListRuleForStage(...)`
    - `_analyzeBookListLikeLegado(...)`
    - `_parseInfoAsSearchResultLikeLegado(...)`
    - `_parseBookDetailFromBodyLikeLegado(...)`
    - `_postProcessBookListLikeLegado(...)`
  - 搜索链路对齐 legado `BookList`：
    - 支持 `bookUrlPattern` 命中后按“详情页”解析返回结果。
    - 列表为空且 `bookUrlPattern` 为空时，回退按“详情页”解析。
    - 列表项 `bookUrl` 为空时回退为当前页面 URL。
    - 支持列表规则前缀 `-`（逆序）与 `+`（剥离）语义。
    - 引擎层增加去重后处理（对齐 legado `LinkedHashSet` 行为）。
  - 发现链路对齐 legado `BookList` 规则选择：
    - 当 `ruleExplore.bookList` 为空时，自动回退使用 `ruleSearch`。
  - 调试链路同构：
    - `searchDebug`、`exploreDebug`、`debugRun` 的列表入口统一使用同一解析内核。

- 测试新增
  - 新增 `test/rule_parser_engine_book_list_parity_test.dart`，覆盖：
    - `bookUrlPattern` 详情页识别
    - 列表为空详情回退
    - 空 `bookUrl` 回退
    - `explore` 回退 `searchRule`
    - `-` 逆序规则
    - `searchDebug` 与主链路语义一致

### 为什么
- 第一阶段完成后，五段链路核心能力已对齐，但搜索/发现的 `BookList` 仍缺少 legado 的关键分支（详情页识别、空列表回退、规则回退、逆序与去重），导致部分旧书源在列表阶段行为不一致。
- 本次补齐后，搜索/发现主链路与调试链路的行为收敛到同一规则内核。

### 如何验证
- 自动校验：`flutter analyze`
- 回归测试：
  - `flutter test test/rule_parser_engine_book_list_parity_test.dart test/rule_parser_engine_stage_js_compat_test.dart test/rule_parser_engine_next_url_compat_test.dart`

### 兼容影响
- **有兼容影响（正向）**：
  - 依赖 `bookUrlPattern`、列表空回退详情、`ruleExplore` 空列表规则回退到 `ruleSearch` 的书源，将与 legado 行为一致。
- **潜在行为变化点**：
  - 列表阶段新增引擎层去重与 `-` 逆序语义后，部分重复条目或顺序可能与旧实现不同，但与 legado 一致。

## 2026-02-16 - legado BookList 复核修正（去重与重定向 bookUrl）

### 做了什么
- `lib/features/source/services/rule_parser_engine.dart`
  - 书籍列表去重语义修正为“仅按 `bookUrl` 去重”，对齐 legado `SearchBook.equals/hashCode`（`LinkedHashSet` 去重键即 `bookUrl`）。
  - 搜索详情分支 `bookUrl` 计算改为显式 `isRedirect` 驱动：
    - 重定向场景取响应最终 URL；
    - 非重定向场景取请求 URL（去掉 URL option 后）。
  - `_fetch` 增加重定向标记回调；`search/explore` 与 `searchDebug/exploreDebug/debugRun` 的列表解析统一透传该标记。
  - `FetchDebugResult` 增加 `isRedirect` 字段，保证调试链路与主链路同语义。

- `test/rule_parser_engine_book_list_parity_test.dart`
  - 新增“按 `bookUrl` 去重”回归用例，验证重复 `bookUrl` 仅保留首条，行为与 legado 一致。

### 为什么
- 复核 legado `BookList.kt` 后发现，去重键应为 `bookUrl`，此前全字段去重会导致重复链接未被正确折叠。
- 复核 `getInfoItem` 后确认 `bookUrl` 取值应由“是否发生重定向”决定，不能仅依赖 URL 字符串差异推断。

### 如何验证
- 自动校验：`flutter analyze`
- 回归测试：
  - `flutter test test/rule_parser_engine_book_list_parity_test.dart test/rule_parser_engine_stage_js_compat_test.dart test/rule_parser_engine_next_url_compat_test.dart`

### 兼容影响
- **有兼容影响（正向）**：
  - 重复详情链接的列表将更接近 legado：同 `bookUrl` 条目去重后仅保留首条。
  - 搜索命中详情页且存在重定向的场景，返回 `bookUrl` 与 legado 一致。

## 2026-02-16 - legado 字段格式化语义对齐（BookList/BookInfo）

### 做了什么
- `lib/features/source/services/rule_parser_engine.dart`
  - 新增并接入 legado 风格字段格式化：
    - `name`：按 `AppPattern.nameRegex` 语义清洗（去除“作者…”尾缀）。
    - `author`：按 `AppPattern.authorRegex` 语义清洗（去除“作者:”前缀与“著”后缀）。
    - `wordCount`：按 `StringUtils.wordCountFormat` 语义格式化（如 `12001 -> 1.2万字`，`9999 -> 9999字`）。
    - `intro`：按 `HtmlFormatter.format` 语义做 HTML 转文本清理。
  - `kind` 字段改为对齐 legado 的 `getStringList(...).joinToString(",")`：
    - HTML/JSON 路径统一按“列表提取后逗号拼接”输出，而非单值提取。
  - 对齐范围覆盖：
    - 搜索/发现列表解析（`_analyzeBookListLikeLegado`）；
    - 列表详情回退解析（`_parseBookDetailFromBodyLikeLegado`）；
    - 详情主链路与调试链路（`getBookInfo/getBookInfoDebug/_debugBookInfo`）。

- `test/rule_parser_engine_book_list_parity_test.dart`
  - 新增“搜索列表字段格式化语义”回归：
    - 验证 `name/author/kind/wordCount/intro` 与 legado 语义一致。
  - 新增“详情字段格式化语义”回归：
    - 验证 `getBookInfo` 的同字段格式化行为与 legado 一致。

### 为什么
- 复核 legado `BookList.kt` 与 `BookInfo.kt` 后，当前实现虽已覆盖链路分支，但字段值后处理仍存在差异（尤其 `kind` 列表、字数字符串和简介 HTML 清理），会导致旧书源展示结果与 legado 不一致。

### 如何验证
- 自动校验：`flutter analyze`
- 回归测试：
  - `flutter test test/rule_parser_engine_book_list_parity_test.dart test/rule_parser_engine_stage_js_compat_test.dart test/rule_parser_engine_next_url_compat_test.dart`

### 兼容影响
- **有兼容影响（正向）**：
  - 书名/作者噪声文本、字数字段显示、分类聚合与简介展示将更接近 legado。
- **潜在行为变化点**：
  - 先前依赖“未格式化原文”的展示可能出现文案变化（例如 `12001` 变为 `1.2万字`），但与 legado 基准一致。

## 2026-02-16 - legado 链接匹配与详情回退语义复核修正

### 做了什么
- `lib/features/source/services/rule_parser_engine.dart`
  - `bookUrlPattern` 匹配改为“整串匹配”语义（对齐 Kotlin `String.matches`），不再使用子串命中。
  - 新增 `_resolveBookInfoTocUrlLikeLegado(...)`，用于对齐 `AnalyzeRule.getString(..., isUrl=true)`：
    - `tocUrl` 规则为空时，回退请求 URL（`baseUrl`）；
    - `tocUrl` 非空时，以重定向后的 URL（`redirectUrl`）做绝对化。
  - `getBookInfo/getBookInfoDebug/_debugBookInfo` 全部切换为上述语义。
  - 详情页源码复用缓存条件同步对齐：从“等于重定向 URL”改为“等于请求 URL”时缓存（与 legado `book.tocHtml` 条件一致）。

- `test/rule_parser_engine_book_list_parity_test.dart`
  - 新增 `bookUrlPattern` 全匹配回归用例。
  - 新增“详情重定向且 `tocUrl` 为空时回退请求 URL”回归（同时验证 `getBookInfoDebug`）。

### 为什么
- 复核 `legado` 的 `BookList.kt` 与 `AnalyzeRule.kt` 后发现：
  - `bookUrlPattern` 在 legado 使用 `matches`，是整串匹配；
  - `BookInfo` 的 `tocUrl` 空值回退基准是请求 URL，而不是重定向后的最终 URL。
- 现有实现在上述两点存在偏差，可能导致详情识别分支与目录回退行为不一致。

### 如何验证
- 自动校验：`flutter analyze`
- 回归测试：
  - `flutter test test/rule_parser_engine_book_list_parity_test.dart test/rule_parser_engine_stage_js_compat_test.dart test/rule_parser_engine_next_url_compat_test.dart`

### 兼容影响
- **有兼容影响（正向）**：
  - `bookUrlPattern` 写法不完整（仅子串）的书源不再被误判为详情页。
  - 详情页发生重定向且目录规则缺失时，目录链接回退将与 legado 完全一致。

## 2026-02-16 - legado 搜索聚合排序语义复核修正（SearchView）

### 做了什么
- `lib/features/search/views/search_view.dart`
  - 搜索书源调度顺序改为按 `customOrder` 升序，移除按 `weight` 排序，统一到 legado `SearchScope.getBookSourceParts()` 语义。
  - `customOrder` 相同场景下保持原序稳定，不再引入书源名次级排序，避免额外排序噪声。
  - 搜索范围命中结果为空时自动回退到“全部启用书源”，避免因范围失效导致搜索直接不可用（对齐 legado 范围兜底策略）。
  - 搜索入口新增“范围失效自动持久化回写”：
    - 当已保存范围与当前启用书源无任何命中时，自动将范围设置回“全部书源”（空范围存储），与 legado `SearchScope` 的自动修正策略一致。
  - 新增“范围内搜空”的 legado 式提示链路：
    - 精准过滤开启且结果为空时，提示“关闭精准过滤并重试”；
    - 非精准过滤且范围非全量时，提示“切换到所有书源并重试”；
    - 用户确认后自动执行重试。
  - 过滤模式或搜索范围变更后，若当前有查询词则自动重跑搜索（不再只做本地重排），对齐 legado 菜单改动后的重搜行为。
  - 搜索并发 worker 增加 30 秒单源总超时上限（对齐 legado `SearchModel` 外层 `withTimeout(30000)` 语义）。
  - 单源超时改为“静默跳过并继续下一个书源”，不再额外记为失败提示，贴近 legado `mapParallelSafe` 的容错流。
  - 对齐 legado `SearchModel.mergeItems` 的“同名同作者合并”语义：
    - 合并时只累计来源集合（`origins`），不再用后续结果回填/覆盖首条字段。
    - 原始结果缓存去重改为“首条保留”策略（`sourceUrl + bookUrl` 首次命中即固定）。
  - 对齐排序稳定性语义：
    - `exact/contains` 仍按来源数降序；
    - 当来源数相同，改为保持“上一次列表顺序”的稳定排序，不再固定按首见顺序回退。
  - 展示语义收敛到 legado 主条目行为：
    - 封面来源使用主条目（首条）而非“跨来源找首个非空封面”；
    - “已在书架中”判定以主条目为准，不再对所有来源做 `any` 判定。
- `lib/features/bookshelf/services/book_add_service.dart`
  - `isInBookshelf` 对齐 legado 搜索命中语义，改为多键匹配：
    - `name-author`
    - `name`
    - `bookUrl`
  - 新增 `buildSearchBookshelfKeys()`，供搜索页一次性构建键集合，避免逐条重复扫描书架。
- `lib/features/search/views/search_book_info_view.dart`
- `lib/features/reader/views/simple_reader_view.dart`
  - 两处“换源”入口的启用书源遍历统一改为 `customOrder` 升序（同序号保持原序稳定），避免未排序遍历导致候选顺序与 legado 不一致。
  - 两处“换源”搜索调用补齐 legado 风格过滤：
    - 书名需精确匹配；
    - 作者按“包含”匹配（作者为空则不限制）。
- `lib/features/source/services/rule_parser_engine.dart`
  - `search(...)` 新增并贯通 legado 同款参数：
    - `filter(name, author)`：按书名/作者过滤搜索结果；
    - `shouldBreak(size)`：满足条件后提前结束列表解析。
  - `_analyzeBookListLikeLegado` 与详情回退分支同步接入上述参数，保证过滤与提前终止语义在列表解析阶段生效。
- `lib/features/search/views/search_scope_picker_view.dart`
  - 搜索范围选择列表排序去除 `weight` 次排序，收敛为 `customOrder` 优先顺序（同序号保持原序稳定），减少与 legado 范围列表顺序偏差。
- `test/bookshelf_booklist_import_service_test.dart`
  - 同步更新测试桩 `search(...)` 覆盖签名，适配引擎新参数。
- `test/rule_parser_engine_book_list_parity_test.dart`
  - 新增 `filter/shouldBreak` 对齐回归：
    - 搜索列表解析支持 `filter(name, author)`；
    - 搜索列表解析支持 `shouldBreak(size)` 提前终止；
    - “列表空回退详情”分支同样受 `filter` 约束。

### 为什么
- 复核 legado `SearchModel.kt` 与 `SearchAdapter.kt` 后确认：
  - 搜索书源范围输出顺序以 `customOrder` 为准；
  - `customOrder` 相同场景应保持稳定顺序，不引入额外字段次排；
  - 搜索范围失效（如目标书源缺失）时会回退到全部启用书源，而不是保持空范围；
  - 范围内搜空时会引导关闭精准搜索或切回全部范围并自动重试；
  - 精准搜索开关与范围切换会触发当前查询重搜，而不是仅对已有结果做前端过滤；
  - 单书源搜索应受 30 秒总超时保护，避免长耗时源拖慢整页流程；
  - 单源超时应按“跳过继续”处理，避免阻断或污染整体搜索结果；
  - “在书架中”判定应兼容同名同作者或同链接场景，不仅限 source+bookUrl 精确 ID；
  - 书源候选遍历顺序应优先遵循 `customOrder`，保证换源候选输出稳定；
  - 换源搜索应在源内阶段就执行“书名精确 + 作者包含”过滤，避免无关候选干扰；
  - 搜索解析阶段应支持 `filter/shouldBreak`，与 legado `WebBook.searchBookAwait` 行为一致；
  - 搜索聚合对象在合并重复书目时只做 `addOrigin`，不会做字段补全；
  - 排序依赖稳定排序与当前列表顺序，不应在同权重时回退到固定首见序；
  - 列表展示使用聚合主条目的字段（含封面/点击目标）。
- 当前实现在这几处存在偏差，导致相同书源集合下的展示字段与顺序可能和 legado 不一致。

### 如何验证
- 自动校验：`flutter analyze`
- 回归测试：
  - `flutter test test/rule_parser_engine_book_list_parity_test.dart`
  - `flutter test test/bookshelf_booklist_import_service_test.dart`

### 兼容影响
- **有兼容影响（正向）**：
  - 多来源同名合并结果的字段与排序将更贴近 legado。
- **潜在行为变化点**：
  - 某些结果项封面可能从“后续来源补齐封面”回退为主条目封面（与 legado 一致）。

## 2026-02-16 - SearchScopeDialog/SearchScope 语义对齐（分组模式 + 单源模式）

### 做了什么
- `lib/features/search/models/search_scope.dart`
  - 新增 legado 风格搜索范围语义模型：
    - `""`（全部书源）
    - `groupA,groupB`（分组模式）
    - `name::url`（单源模式）
  - 落地 `resolve(...)` 规则：
    - 分组模式按分组映射启用书源；
    - 无效分组自动剔除并回写；
    - 单源 URL 失效时回退到全部书源；
    - 返回范围展示文案与 `displayNames`。
- `lib/core/models/app_settings.dart`
  - 新增 `searchScope` 持久化字段（字符串语义）。
  - 保留旧 `searchScopeSourceUrls` 读取以兼容历史配置，并在“单 URL”历史值上迁移为 `::url`。
- `lib/features/search/views/search_scope_picker_view.dart`
  - 搜索范围选择改为 legado 对齐双模式：
    - 分组模式：多选分组；
    - 书源模式：单选书源 + 关键字筛选（含禁用书源）；
  - 增加“全部书源/取消/确定”操作链路；
  - 返回值改为 `SearchScope` 字符串语义（不再返回 URL 列表）。
- `lib/features/search/views/search_view.dart`
  - 搜索范围生效链路改为基于 `searchScope` 解析：
    - 搜索前自动规范化并在需要时持久化修正；
    - 分组失效自动回退“全部书源”；
    - 单源模式按 legado 语义允许使用禁用书源（只要 URL 存在）；
    - 单源失效（URL 不存在）时自动回退“全部书源”；
    - 搜索设置中的范围标签改为展示当前分组/单源语义。
  - `SearchView.scoped(...)` 改为“注入单源 scope”语义（与 legado 入口传 scope 行为一致），不再硬锁范围。
  - 搜空提示链路改为按“scope 是否为 all”判断（对齐 legado）：
    - 精准过滤模式可提示关闭并重试；
    - 非全量范围可提示切回全部并重试。
- `test/search_scope_test.dart`
  - 新增范围语义回归：
    - 全量、分组、单源、无效回退、`fromSource` 名称清洗。
- `test/app_settings_test.dart`
  - 增加 `searchScope` roundtrip 与旧 `searchScopeSourceUrls` 迁移用例。

### 为什么
- legado 的 `SearchScope` 是“字符串语义”而非“URL 列表语义”：
  - URL 列表无法表达“分组模式”与“name::url 单源模式”；
  - 无法复刻无效分组剔除、单源失效回退等状态流转。
- 当前 SoupReader 搜索范围仅支持 URL 多选，导致与 legado 的范围选择语义和搜空提示边界不一致。

### 如何验证
- 静态检查：`flutter analyze`
- 相关测试：
  - `flutter test test/search_scope_test.dart`
  - `flutter test test/app_settings_test.dart`

### 兼容影响
- **有兼容影响（正向）**：
  - 搜索范围语义从“纯 URL 列表”收敛到 legado 语义（分组/单源/全量）。
  - 单源范围失效、分组失效时会自动回退全部书源，避免空范围阻断搜索。
- **迁移说明**：
  - 历史 `searchScopeSourceUrls` 若仅 1 个 URL，会迁移为 `::url`；
  - 历史多 URL 自定义范围无法 1:1 映射到 legado `SearchScope`，会按新语义逐步由用户在范围选择页重设。

## 2026-02-16 - SearchScope 继续收口（动态范围菜单 + 默认态复刻）

### 做了什么
- `lib/features/search/views/search_view.dart`
  - 新增 legado 风格“动态范围快捷菜单”（在“搜索设置 -> 搜索范围”进入）：
    - 当前已选范围项（分组或单源）可直接点选移除；
    - 提供“所有书源”快速切换；
    - 提供可选分组列表（选中即切到单分组）；
    - 提供“多分组/单源模式…”入口跳转到范围选择页。
  - 范围来源收口为“两套集合”：
    - 分组模式基于启用书源；
    - 单源模式基于全部书源（含禁用），对齐 legado `isSource` 分支行为。
- `lib/features/search/views/search_scope_picker_view.dart`
  - 默认态复刻 legado：
    - 默认进入“分组模式”；
    - 不根据当前 scope 预选任何分组/书源。
- `lib/features/search/models/search_scope.dart`
  - `resolve(...)` 新增 `allSourcesForSourceMode` 参数，用于单源模式按全量书源解析。
- `test/search_scope_test.dart`
  - 新增“单源可命中禁用书源”回归用例。

### 为什么
- legado 搜索范围存在两条并行交互：
  - 顶部菜单动态切换/移除当前范围；
  - 对话框用于多分组或单源重设。
- 当前实现若只保留“范围选择页”，会缺少快捷切换语义；若单源只基于启用书源，也会偏离 legado。
- legado 的 SearchScopeDialog 默认不预选当前范围，需复刻该默认态以保持交互一致。

### 如何验证
- 静态检查：`flutter analyze`
- 相关测试：
  - `flutter test test/search_scope_test.dart`
  - `flutter test test/app_settings_test.dart --plain-name "AppSettings JSON roundtrip"`
  - `flutter test test/app_settings_test.dart --plain-name "AppSettings migrates legacy single source scope urls"`

### 兼容影响
- **有兼容影响（正向）**：
  - 搜索范围切换路径更接近 legado（支持快捷切换与移除）。
  - 单源范围可直接覆盖到禁用书源，行为与 legado 对齐。
- **潜在行为变化点**：
  - 打开“多分组/单源模式”选择页时不再回显当前选择（按 legado 默认态）。

## 2026-02-16 - SearchScope 分组来源与排序对齐（flowEnabledGroups / dealGroups）

### 做了什么
- 新增 `lib/features/search/models/search_scope_group_helper.dart`：
  - 抽取并统一分组处理逻辑，语义对齐 legado `BookSourceDao.dealGroups(...)`：
    - 仅统计启用书源；
    - 分组按 `[,;，；]` 拆分；
    - 去空、去重；
    - 排序输出。
- `lib/features/search/views/search_view.dart`
  - 搜索范围快捷菜单中的分组来源改为“flow 风格”：
    - 订阅 `SourceRepository.watchAllSources()`；
    - 实时派生启用分组缓存（等价 legado `flowEnabledGroups().map(dealGroups)`）；
    - 菜单展示优先读取该缓存，首帧未就绪时再用当前快照兜底。
  - 删除原本页面内重复的 `_enabledGroups(...)` 本地拼装逻辑，避免与对话框实现分叉。
- `lib/features/search/views/search_scope_picker_view.dart`
  - 分组列表改为复用 `SearchScopeGroupHelper.enabledGroupsFromSources(...)`，不再维护独立 `_buildGroups(...)`。
- 新增测试 `test/search_scope_group_helper_test.dart`：
  - 覆盖启用过滤、legacy 分隔符拆分、去重与排序。

### 为什么
- 之前 `SearchView` 与 `SearchScopePickerView` 各自实现分组拼装与排序，存在两套逻辑，无法保证与 legado `flowEnabledGroups + dealGroups` 行为稳定一致。
- legado 的分组来源是“启用书源集合的流式派生”，不是仅在弹窗时临时扫描；若不统一来源和处理规则，菜单分组与对话框分组可能出现偏差。

### 如何验证
- 静态检查：`flutter analyze`
- 相关测试：
  - `flutter test test/search_scope_group_helper_test.dart`
  - `flutter test test/search_scope_test.dart`

### 兼容影响
- **有兼容影响（正向）**：
  - 搜索范围快捷菜单与范围对话框的分组展示来源、拆分和排序规则收敛到同一实现，行为更贴近 legado。
- **潜在行为变化点**：
  - 分组顺序将以统一排序结果为准，可能与此前“页面局部临时排序”存在差异。

## 2026-02-16 - SearchScope 中文分组排序对齐（cnCompare）

### 做了什么
- `pubspec.yaml`
  - 新增依赖 `pinyin`，用于中文分组排序键计算。
- `lib/features/search/models/search_scope_group_helper.dart`
  - 新增 `cnCompareLikeLegado(...)` 比较器：
    - 中文字符转换为无声调拼音后比较；
    - 非中文字符按小写原文比较；
    - 拼音键一致时回退原文比较，保证稳定性。
  - `dealGroups(...)` 排序从 `compareTo` 改为 `cnCompareLikeLegado`。
  - 增加轻量排序键缓存，降低频繁弹菜单时的重复转换开销。
- `test/search_scope_group_helper_test.dart`
  - 新增中文分组排序回归：验证“都市/历史/武侠/玄幻”按拼音序输出。

### 为什么
- legado `BookSourceDao.dealGroups(...)` 最终使用 `cnCompare`（中文 Collator）排序；此前 Dart 侧使用默认 `compareTo`，中文分组顺序存在偏差。
- 本次目标是把 SearchScope 分组展示顺序进一步收敛到 legado 的中文排序语义。

### 如何验证
- 静态检查：`flutter analyze`
- 相关测试：
  - `flutter test test/search_scope_group_helper_test.dart`
  - `flutter test test/search_scope_test.dart`

### 兼容影响
- **有兼容影响（正向）**：
  - 中文分组展示顺序将更贴近 legado `cnCompare` 效果。
- **潜在行为变化点**：
  - 某些中英混合分组名的相对顺序可能与旧版 `compareTo` 不同。

## 2026-02-16 - SearchScope 中文排序二次校准（多音字短语 + 中英混排）

### 做了什么
- `lib/features/search/models/search_scope_group_helper.dart`
  - `cnCompareLikeLegado(...)` 增加排序类别优先级：
    - 数字开头分组优先；
    - 其次中文；
    - 再次英文字母开头；
    - 最后其它字符。
  - 中文排序键由“逐字拼音”改为“整词拼音”（`PinyinHelper.getPinyinE(value, ...)`）：
    - 改善多音字短语排序，如“重庆/重生/中文”。
- `test/search_scope_group_helper_test.dart`
  - 新增“中英混排排序优先级”回归。
  - 新增“多音字短语整词拼音排序”回归。

### 为什么
- 首轮 `cnCompare` 对齐后，纯中文分组已明显改善，但中英混排与部分多音字短语仍有偏差风险。
- 本次通过“类别优先级 + 整词拼音键”进一步收敛到 legado 的中文排序观感。

### 如何验证
- 静态检查：`flutter analyze`
- 相关测试：
  - `flutter test test/search_scope_group_helper_test.dart`
  - `flutter test test/search_scope_test.dart`

### 兼容影响
- **有兼容影响（正向）**：
  - 中英混排分组排序更稳定，且更接近中文场景直觉与 legado 行为。
- **潜在行为变化点**：
  - 混合符号分组名（如特殊前缀）排序位置可能与旧逻辑不同。

## 2026-02-16 - SearchScope 中文排序样本扩展回归（稳定性补强）

### 做了什么
- `test/search_scope_group_helper_test.dart`
  - 在已有排序回归基础上，新增三组样本矩阵：
    - 常见中文分组：`都市/科幻/男频/女频/轻小说/玄幻`；
    - 符号+中英数字混排：`2区/!活动/_其它/历史/玄幻/A区/B区`；
    - 同拼音前缀细分：`东京/东野/斗罗/斗破/斗气/都市`。
  - 目标是覆盖 legacy 书源分组中最容易出现排序抖动的边界场景，防止后续迭代回退到 `compareTo` 风格排序。

### 为什么
- 完成 `cnCompare` 近似对齐后，需要通过更贴近实际书源命名的数据样本，持续验证排序稳定性与可预期性。
- 这一步主要是“测试面补强”，避免未来改动在不知情情况下破坏当前对齐成果。

### 如何验证
- 静态检查：`flutter analyze`
- 相关测试：
  - `flutter test test/search_scope_group_helper_test.dart`
  - `flutter test test/search_scope_test.dart`

### 兼容影响
- **无功能语义新增**（仅测试覆盖增强）。
- **风险下降**：分组排序回归被更早发现，降低旧书源显示顺序漂移风险。

## 2026-02-16 - 根目录图片忽略规则修正（PNG）

### 做了什么
- `.gitignore`
  - 根目录图片忽略规则从仅 `/*.IMG` 扩展为同时忽略 `/*.PNG`。
- Git 索引清理
  - 将已误提交的 `IMG_6955.PNG` ~ `IMG_6962.PNG` 从索引移除（保留本地文件）。

### 为什么
- 之前规则只覆盖 `.IMG` 扩展，实际文件是 `.PNG`，因此未被忽略并进入版本库。

### 如何验证
- `git check-ignore -v IMG_6955.PNG` 命中 `/.gitignore` 的 `/*.PNG` 规则。
- `git status --short` 显示图片为删除（索引移除），但本地文件仍存在。

### 兼容影响
- 仅影响版本控制，不影响运行时功能与书源兼容性。

## 2026-02-16 - Git 历史图片清理（IMG_*.PNG / IMG_*.IMG）

### 做了什么
- 使用 `git filter-branch` 重写全历史提交，移除根目录匹配 `IMG_*.PNG`、`IMG_*.IMG` 的文件对象。
- 清理 `filter-branch` 生成的备份引用（`refs/original/*`），并执行 `reflog expire + gc --prune=now`。
- 将重写后的 `main` 强制更新到远端，并清理镜像推送过程中误生成的远端分支 `origin/main`、`origin/HEAD`。

### 为什么
- 虽然最新提交已删除图片并补了 ignore 规则，但旧提交仍保留图片二进制对象，仓库历史体积与泄漏风险仍在。
- 本次目标是“历史级彻底清理”，确保旧提交不再包含这批图片文件。

### 如何验证
- `git rev-list main --objects | rg 'IMG_[0-9]+\\.(PNG|IMG)$'` 无结果。
- `git ls-remote --heads origin` 仅保留 `refs/heads/main`（无误推的 `origin/*` 分支）。
- `git rev-list origin/main --objects | rg 'IMG_[0-9]+\\.(PNG|IMG)$'` 无结果。

### 兼容影响
- **有兼容影响**：历史提交哈希已整体变更，依赖旧 commit hash 的本地分支/PR 需要 rebase 或重拉。

## 2026-02-17 - 非仿真翻页对齐 legado（最小偏差修复）

### 做了什么
- `lib/features/reader/models/reading_settings.dart`
  - 新增设置项 `noAnimScrollPage`（默认 `false`，对标 legado `AppConfig.noAnimScrollPage`）。
  - 打通 `fromJson/toJson/sanitize/copyWith`，保证冷启动与持久化一致。
  - 调整 `PageTurnModeUi.values(...)` 展示顺序为：
    - `cover -> slide -> simulation -> scroll -> none`
  - 保留 `simulation2` 隐藏策略；当当前值为 `simulation2` 时，仍插入列表用于可见但不可选。
- `lib/features/reader/views/simple_reader_view.dart`
  - 在滚动翻页逻辑 `_scrollPage(...)` 中接入 `noAnimScrollPage`：
    - 开启时使用 `jumpTo`（无动画）；
    - 关闭时保留 `animateTo`（现有动画时长）。
  - 在阅读设置面板新增“滚动翻页无动画”开关（仅 `scroll` 模式显示）。
- `test/reading_settings_test.dart`
  - 新增回归测试覆盖：
    - `PageTurnModeUi` legacy 顺序；
    - `simulation2` 选中时的可见插入；
    - `noAnimScrollPage` 默认值与 JSON 往返。

### 为什么
- 按 legado 语义对齐“非仿真翻页”中的明显偏差：
  - 当前项目翻页模式展示顺序与 legado 不一致；
  - 当前项目滚动翻页缺少 legacy 的“无动画点击翻页”能力。

### 如何验证
- 静态检查：`flutter analyze`
- 相关测试：
  - `flutter test test/reading_settings_test.dart`

### 兼容影响
- **有兼容影响（正向）**：
  - 翻页模式选项顺序将与 legado 更一致。
  - scroll 模式新增可选“无动画翻页”行为，默认关闭，不影响旧配置体验。

## 2026-02-17 - 协作规范调整：`flutter analyze` 触发时机

### 做了什么
- `AGENTS.md`
  - 将测试与验收章节标题从“提交前检查”明确为“提交推送前检查”。
  - 将执行条件从“修改代码后”调整为“在提交推送前”，命令仍为 `flutter analyze`。

### 为什么
- 对齐当前协作流程，避免在开发中间态频繁执行静态检查，统一在提交推送前做最终把关。

### 如何验证
- 手工检查 `AGENTS.md` 第 3 节文案，确认触发时机已改为“提交推送前”。

### 兼容影响
- 无运行时兼容影响（仅流程文档调整）。

## 2026-02-17 - 非仿真翻页视觉对齐（none 真无动画 + 交互期快照兜底）

### 做了什么
- `lib/features/reader/widgets/paged_reader_widget.dart`
  - 新增 `_isLegacyNonSimulationMode`，统一识别 `slide/cover/none`。
  - `none` 模式在 `_startTurnAnimation()` 中改为 legacy 语义：
    - 直接执行 `_completeNoAnimationTurn()`；
    - 不再启动 `_startScroll()` 动画链路。
  - 新增 `_completeNoAnimationTurn()`：
    - 非取消场景立即 `fillPage`；
    - 直接走 `_stopScroll(...)` 收尾，确保状态一致。
  - `_buildRecordedPage(...)` 在交互期间（`slide/cover/none`）统一禁止回退到 widget 重排路径：
    - 优先使用快照兜底；
    - 无可用快照时返回纯背景，避免单帧重排造成抖动。
  - `_buildNoAnimation(...)` 调整为始终显示当前页快照，不渲染中间过渡帧。
- `test/paged_reader_widget_non_simulation_test.dart`
  - 新增回归：`none` 模式点击翻页应立即生效，不依赖动画时长。

### 为什么
- 用户要求“除仿真外，翻页视觉效果与 legado 一致，过渡帧不能卡顿”。
- 现状中 `none` 模式仍共享通用动画链，并且非仿真模式交互时存在回退到 widget 重排路径的可能，易导致观感抖动。

### 如何验证
- 相关测试：
  - `flutter test test/paged_reader_widget_non_simulation_test.dart`
  - `flutter test test/reading_settings_test.dart`

### 兼容影响
- **有兼容影响（正向）**：
  - `none` 模式不再显示中间过渡效果，改为 legacy 风格“立即切页”。
  - 非仿真模式交互期间渲染路径更稳定，降低卡顿与闪动风险。

## 2026-02-17 - 非仿真翻页实现对齐 legado（slide/cover 公式、曲线、阴影）

### 做了什么
- `lib/features/reader/widgets/paged_reader_widget.dart`
  - 在 `_startTurnAnimation()` 中为 `slide/cover` 单独走 `_onAnimStartHorizontalLegacy()`，不再复用仿真翻页位移公式。
  - 新增 `_onAnimStartHorizontalLegacy()`，按 legado `SlidePageDelegate/CoverPageDelegate` 的 `distanceX` 计算完成/取消翻页位移。
  - `_nextPageByAnim()` / `_prevPageByAnim()` 对齐 legado 触发起点：
    - next: `x=0.9w`，`y` 按起点是否在下半区取 `0.9h` 或 `1`；
    - prev: `x=0`，`y=h`。
  - `_startScroll()` 去除时长 clamp，保留 legacy 距离比例时长计算。
  - `_computeScroll()` 改为线性进度（`AnimationController.value`），对齐 legado `LinearInterpolator` 语义。
  - `_buildSlideAnimation()`：
    - 增加 legado 同款“反向位移直接返回当前帧”保护；
    - 位移布局改为 `distanceX` 模型（`next`/`prev` 两支与 legado 一致）。
  - `_buildCoverAnimation()`：
    - 改为 legacy `distanceX` 驱动；
    - 对齐 next 分支的 reveal + 当前页平移；
    - 对齐 prev 分支的 `offsetX <= width` 与 `> width` 语义。
  - `_buildLegacyCoverShadow()` 改为 legado 同款 `addShadow(left)` 语义（`left<0` 时右移 `+width`）。
- `test/paged_reader_widget_non_simulation_test.dart`
  - 补充 `slide/cover` 回归：
    - 拖拽取消不翻页；
    - 点击触发可前进并返回；
  - 保留 `none` 模式“立即翻页”回归，确保无动画语义不回退。

### 为什么
- 用户要求“除仿真翻页外，其它翻页方式实现与 legado 完全一致”，重点是动画轨迹、阴影与过渡帧行为。
- 当前实现虽已接近，但在 `slide/cover` 的动画公式、曲线、时长策略与边界渲染分支仍存在 legacy 偏差，需要做实现层收敛。

### 如何验证
- 相关测试：
  - `flutter test test/paged_reader_widget_non_simulation_test.dart test/reading_settings_test.dart`
- `flutter analyze`：
  - 按项目协作规范，保留在提交推送前执行。

### 兼容影响
- **有兼容影响（正向）**：
  - `slide/cover` 的完成/取消翻页手感、阴影位置和过渡帧更接近 legado。
  - 不涉及数据结构与书源规则变更，对旧书源解析兼容性无负面影响。

## 2026-02-17 - 滚动翻页卡帧优化（节流同步 + 段落预切分）

### 做了什么
- `lib/features/reader/views/simple_reader_view.dart`
  - 滚动通知链路增加节流与门控：
    - 新增滚动 UI 同步节流（120ms）；
    - 新增预加载检查节流（160ms）；
    - 新增程序化滚动标记 `_programmaticScrollInFlight`，避免 `animateTo` 期间高频触发可见章节同步。
  - `_scrollPage(...)` 改造：
    - `animateTo/jumpTo` 用 `try/finally` 包裹，确保程序化滚动标记可靠收敛；
    - 动画曲线调整为 `Curves.linearToEaseOut`，降低尾段突变感；
    - 动画完成后统一做一次章节同步与进度保存。
  - 进度保存节流从 350ms 调整为 450ms，减少滚动期高频 IO 触发。
  - 滚动正文渲染改造：
    - `_ScrollSegment` 新增 `paragraphs` 字段；
    - 章节加载时一次性完成段落拆分并缓存；
    - 构建滚动正文时直接使用缓存段落，移除 build 期重复 `split`。
- `lib/features/reader/widgets/scroll_runtime_helper.dart`（新增）
  - 提供滚动运行时辅助方法：
    - `splitParagraphs`：段落预切分并过滤空段；
    - `shouldRun`：通用最小间隔判定。
- `test/scroll_runtime_helper_test.dart`（新增）
  - 覆盖段落切分与节流判定的核心用例。

### 为什么
- 用户反馈“滚动翻页点击与拖动都卡帧”，并优先要求流畅性。
- 现状中滚动通知每帧都可能触发章节同步和预加载检查，同时正文 build 期重复拆分长文本，容易造成主线程抖动与掉帧。

### 如何验证
- 相关测试：
  - `flutter test test/scroll_runtime_helper_test.dart`
  - `flutter test test/paged_reader_widget_non_simulation_test.dart test/reading_settings_test.dart`
- `flutter analyze`：
  - 按协作规范保留在提交推送前执行。

### 兼容影响
- **有兼容影响（正向）**：
  - 滚动模式章节进度/标题刷新改为节流更新（更稳、更省资源）；
  - 可能出现轻微“非每帧实时”进度更新，但滚动结束时会强制同步，最终进度准确。

## 2026-02-17 - 书源编辑主流程对齐 legado（6 Tab 主编辑页 + 保存语义 + 自动补全）

### 做了什么
- 新增 `lib/features/source/views/source_edit_legacy_view.dart`
  - 新建 legacy 主编辑页，结构对齐 legado：
    - 顶部开关与类型：`enabled / enabledExplore / enabledCookieJar / bookSourceType`；
    - 六个分栏：`基础 / 搜索 / 发现 / 详情 / 目录 / 正文`。
  - 字段写回按 legado 语义补齐：
    - `ruleBookInfo.canReName / downloadUrls`
    - `ruleToc.isVolume / updateTime / isVip / isPay`
    - `ruleContent.webJs / sourceRegex / imageStyle / imageDecode / payAction`
  - 菜单动作补齐主流程能力：保存、调试、登录、搜索、清 Cookie、自动补全、复制/粘贴、扫码导入、帮助，以及“打开高级工作台”（承接 JSON/高级调试能力）。
  - 增加未保存退出确认（对齐 legado 退出前确认语义）。
- 新增 `lib/features/source/services/source_rule_complete.dart`
  - 复刻 legado `RuleComplete.autoComplete` 规则补全核心语义（文本/链接/图片三种类型）。
- 新增 `lib/features/source/services/source_legacy_save_service.dart`
  - 统一 legacy 保存语义：
    - `bookSourceName/bookSourceUrl` 非空校验；
    - 仅在源内容变更时刷新 `lastUpdateTime`；
    - `exploreUrl` 变化时清理旧源发现缓存；
    - `jsLib` 变化时预留 scope 清理回调；
    - 通过 `originalUrl` 语义执行 URL 变更保存。
- 入口切换（主编辑页默认走 legacy）：
  - `lib/features/source/views/source_list_view.dart`
  - `lib/features/discovery/views/discovery_view.dart`
  - 编辑入口默认跳 `SourceEditLegacyView`；调试入口（`initialTab=3`）继续走高级工作台 `SourceEditView`。
- 新增测试：
  - `test/source_rule_complete_test.dart`
  - `test/source_legacy_save_service_test.dart`

### 为什么
- 当前项目书源编辑主流程与 legado 在页面结构、字段覆盖、保存语义上存在偏差，导致“主编辑页行为不一致”。
- 本次以“主流程严格对齐 legado，增强能力迁移到二级入口”为原则，确保编辑、保存、搜索/登录联动语义一致，同时保留现有高级调试能力。

### 如何验证
- 相关测试：
  - `flutter test test/source_rule_complete_test.dart test/source_legacy_save_service_test.dart`
- 静态检查：
  - `flutter analyze`

### 兼容影响
- **有兼容影响（正向）**：书源编辑默认入口切换为 legacy 主编辑页，主流程交互与字段写回更接近 legado。
- 高级 JSON/调试能力仍保留在 `SourceEditView`，通过“调试入口”或“打开高级工作台”进入，不影响原有深度调试场景。

## 2026-02-17 - 书源编辑对齐补充：设置源变量（sourceVariable）

### 做了什么
- 新增 `lib/core/services/source_variable_store.dart`
  - 对齐 legado `BaseSource.setVariable/getVariable` 键语义，使用 `sourceVariable_{bookSourceUrl}` 持久化存储。
  - 提供 `getVariable / putVariable / removeVariable`。
- 更新 `lib/features/source/views/source_edit_legacy_view.dart`
  - “更多”菜单新增“设置源变量”。
  - 行为对齐 legado：
    - 先保存当前书源；
    - 读取并展示当前源变量；
    - 备注说明拼接 `variableComment + 源变量默认说明`；
    - 保存空文本时清理变量。
- 新增测试 `test/source_variable_store_test.dart`
  - 覆盖变量写入、读取、空值清理与删除。

### 为什么
- legado 主编辑页支持“设置源变量”，用于规则/JS 调试时按源维度保存自定义变量。
- 当前实现缺失该入口与持久化能力，主编辑语义不完整。

### 如何验证
- `flutter test test/source_variable_store_test.dart`
- `flutter analyze`

### 兼容影响
- **有兼容影响（正向）**：新增与 legacy 同名语义的书源变量存储，不影响已有书源 JSON 结构。

## 2026-02-17 - 滚动模式卡帧修复（legacy 对齐：偏移驱动同步 + 动画回归）

### 做了什么
- `lib/features/reader/views/simple_reader_view.dart`
  - 滚动章节同步从“每次遍历 RenderBox + localToGlobal”改为“偏移区间驱动”:
    - 新增 `_scrollSegmentOffsetRanges`，基于章节高度构建 `start/end` 区间；
    - `_syncCurrentChapterFromScroll()` 改为以 `scrollOffset + anchorWithinViewport` 直接命中区间，减少滚动期布局树读取。
  - 滚动监听链路调整：
    - 新增 `_scrollController` listener 统一处理预加载与 UI 同步；
    - `NotificationListener` 仅保留 `ScrollEndNotification` 的落盘兜底。
  - 点击翻页动画对齐 legacy 手感：
    - `animateTo` 曲线改为 `Curves.linear`；
    - 时长改为直接使用 `pageAnimDuration`（仅保底 `>=1ms`），移除 100~600 的 clamp。
  - 回退“章节加载时预切分段落”:
    - `_ScrollSegment` 移除 `paragraphs` 缓存字段；
    - 构建阶段恢复按内容分段渲染，避免跨章加载时的同步拆分峰值。
  - 节流参数回调至更接近流畅优先：
    - UI 同步间隔 `120ms -> 16ms`；
    - 预加载检查间隔 `160ms -> 80ms`。

### 为什么
- 用户反馈滚动模式“拖动与点击都卡”，且要求与 legado 体验一致。
- 原实现在滚动同步阶段存在高频 RenderBox 扫描，叠加节流门控后会出现“非连续更新”体感；点击翻页动画曲线也与 legado 存在偏差。

### 如何验证
- 相关测试：
  - `flutter test test/scroll_runtime_helper_test.dart`
  - `flutter test test/paged_reader_widget_non_simulation_test.dart test/reading_settings_test.dart`
- 静态检查：
  - `flutter analyze`

### 兼容影响
- **有兼容影响（正向）**：滚动模式章节同步实现改为偏移驱动，滚动期更少布局计算，预期掉帧与卡顿降低。
- 不涉及书源数据结构与解析语义，旧书源兼容性无负面影响。

## 2026-02-17 - 滚动模式二次优化（仅绘制可见行 + 文本绘制缓存）

### 做了什么
- 更新 `lib/features/reader/widgets/scroll_segment_paint_view.dart`：
  - `CustomPainter` 绘制从“遍历整章所有行”改为“按当前可见裁剪区只绘制可见行”；
  - 新增首可见行二分查找，避免每帧从第 1 行线性扫描；
  - 引入全局 LRU `TextPainter` 缓存（按 `style + text`），减少重复创建 `TextPainter`；
  - 增加 `CustomPaint(isComplex: true, willChange: false)`，帮助 Flutter 栅格缓存判定。

### 为什么
- 用户继续反馈“滚动模式仍卡顿”。
- 之前已降低滚动期 `setState` 与布局树读取，但正文绘制阶段仍存在长章节每帧全量循环，CPU 开销偏高。
- 该改动对齐 legado 的“预排版后按可见内容渲染”的思路，优先削减滚动帧内重复计算。

### 如何验证
- `flutter test test/scroll_text_layout_engine_test.dart`
- `flutter test test/scroll_runtime_helper_test.dart`
- `flutter test test/paged_reader_widget_non_simulation_test.dart test/reading_settings_test.dart`
- `flutter analyze`

### 兼容影响
- **有兼容影响（正向）**：滚动模式长章节绘制负载显著下降，预期拖动连续性更好、卡帧概率降低。
- 不涉及书源解析与翻页语义，不影响旧书源兼容性。

## 2026-02-17 - 书源编辑对齐 legado（主编辑页语义补齐）

### 做了什么
- 更新 `lib/features/source/views/source_edit_legacy_view.dart`：
  - 移除“打开高级工作台”入口，主编辑页菜单收敛到 legacy 主流程；
  - 菜单补充“分享文本 / 分享二维码（当前以复制 JSON 兜底）”；
  - `enabledCookieJar` 在编辑页加载与回填时，缺省按 legacy 语义处理为 `false`；
  - `SourceLegacySaveService` 注入 `clearJsLibScope` 回调位，保留 legacy 的 jsLib 变更清理触发链路；
  - 规则对象写回改为始终回填 `ruleSearch/ruleExplore/ruleBookInfo/ruleToc/ruleContent`（不再按空规则折叠为 `null`）。
- 更新 `lib/features/source/models/book_source.dart`：
  - `enabledCookieJar` 默认值从 `true` 调整为 `false`；
  - `fromJson` 在缺失 `enabledCookieJar` 字段时默认 `false`，对齐 legacy `?: false` 语义。
- 新增测试 `test/book_source_model_cookie_default_test.dart`：
  - 覆盖构造默认值、缺失字段默认值与显式 true 的解析行为。

### 为什么
- 用户要求“书源编辑保持与 legado 一致”。
- 之前在 CookieJar 默认、菜单结构与规则序列化结构上仍有偏差，导致主编辑页行为与 legacy 不一致。

### 如何验证
- `flutter test test/book_source_model_cookie_default_test.dart`
- `flutter test test/source_legacy_save_service_test.dart test/source_rule_complete_test.dart test/source_variable_store_test.dart`
- `flutter analyze`

### 兼容影响
- **有兼容影响（行为对齐）**：
  - 旧书源 JSON 缺失 `enabledCookieJar` 字段时，运行默认从 `true` 改为 `false`；
  - 主编辑页保存后规则字段结构更稳定（不再因“空规则”被折叠为 `null`）。
- “分享二维码”当前无原生二维码分享能力，采用“复制 JSON”兜底并提示，已在菜单文案明确。

## 2026-02-17 - 书源管理文案收敛（仅业务短句）

### 做了什么
- 更新 `lib/features/source/views/source_edit_view.dart`：
  - 调试页中包含技术来源说明的标题/说明文案改为纯业务表达：
    - “菜单（…）” -> “菜单”
    - “快捷（…）” -> “快捷”
    - “调试帮助（…）” -> “调试帮助”
    - 输入区说明改为“关键字/URL/前缀调试；完整语法见工具菜单里的调试帮助”。
- 更新 `lib/features/source/constants/source_help_texts.dart`：
  - 调试帮助标题从带技术来源说明改为“调试输入规则：”。
- 更新 `lib/features/source/services/rule_parser_engine.dart`：
  - 请求编码决策文本从“请求参数按 legacy escape 编码”改为“请求参数按 escape 编码”。
- 更新 `lib/features/source/services/source_rule_lint_service.dart`：
  - 体检提示“数量不一致”改为“数量不同”。
- 同步清理书源模块相关注释中的迁移口吻（仅文字层，不改逻辑）：
  - `lib/core/services/source_variable_store.dart`
  - `lib/core/services/source_login_store.dart`
  - `lib/features/source/services/source_cover_loader.dart`
  - `lib/features/source/services/source_explore_kinds_service.dart`
  - `lib/features/source/services/source_debug_key_parser.dart`
  - `lib/features/source/services/source_availability_check_task_service.dart`
  - `lib/features/source/views/source_list_view.dart`
  - `lib/features/source/views/source_edit_legacy_view.dart`
- 更新测试断言 `test/rule_parser_engine_url_option_compat_test.dart` 以匹配新文案。

### 为什么
- 用户要求书源管理界面只保留业务语义短句，不出现技术来源、迁移状态或实现口径说明。
- 之前调试页与帮助文案仍包含这类说明，影响界面表达统一性。

### 如何验证
- `flutter test test/source_rule_lint_service_test.dart test/rule_parser_engine_url_option_compat_test.dart`
- `flutter test test/source_legacy_save_service_test.dart test/source_rule_complete_test.dart test/source_variable_store_test.dart test/source_login_store_test.dart`
- `flutter analyze`

### 兼容影响
- **无功能语义变更**：本次主要是文案与注释收敛，不改变书源处理流程与规则解析行为。
- 调试输出中的请求编码说明文本有变更，依赖该固定文案的外部解析需同步更新。
