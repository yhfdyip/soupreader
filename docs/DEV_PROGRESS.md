# DEV Progress

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
