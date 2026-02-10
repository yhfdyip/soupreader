# SoupReader 开发进度日志

> 用途：按日期记录“做了什么/为什么/下一步做什么”，让进度一眼可见。  
> 开发计划见：`docs/DEV_PLAN.md`

## 更新规则（请遵守）

1) **每次开发完成一个可交付点**（修复/新增/调整）后，追加一条记录。  
2) 记录要写清：**变更点**、**影响范围**、**如何验证**。  
3) 如果影响书源兼容：必须写明“可能影响哪些旧书源表现”。  
4) 代码改动后，先执行 `flutter analyze`；通过后再本地 `git commit`，默认不执行 `git push`。

## 记录模板（复制一段即可）

```text
## YYYY-MM-DD

### 已完成
- …

### 进行中
- …

### 下一步
- …

### 验证方式
- 命令：…
- 手工：…
```

---

## 2026-02-09

### 已完成
- 新增开发计划：`docs/DEV_PLAN.md`
- 新增进度日志：`docs/DEV_PROGRESS.md`
- 明确协作流程：每次改动后先运行 `flutter analyze`，通过后本地 `git commit`，不自动 `git push`
- 执行一次流程落地：清理当前 `flutter analyze` 告警并验证通过（No issues found）
- P0 跨阶段变量兼容：新增解析引擎阶段级变量清理开关，支持在“详情 -> 目录”链路复用 `@put/@get` 变量
- 加书链路接入：`BookAddService` 在详情阶段清理变量，在目录阶段保留变量，兼容 legado 常见跨阶段变量写法
- 新增回归用例：覆盖“详情 `@put` 变量被目录 `@get` 使用”场景

### 下一步
- 根据当前优先级，从 P0 开始逐项勾选并落地（建议从“导入/搜索/正文分页”开始）

### 验证方式
- 命令：`flutter analyze`
- 手工：确认仅执行本地提交，不进行远程推送
- 命令：`flutter test test/rule_parser_engine_next_url_compat_test.dart`
- 命令：`flutter test test/rule_parser_engine_variable_rule_compat_test.dart`

### 兼容影响
- 本次为无用代码与分析告警清理，不涉及书源规则语义变更，旧书源兼容性预期不受影响。
- 本次新增“可选保留运行时变量”能力，默认行为不变（默认仍清理）；仅在加书链路中显式开启跨阶段保留，属于兼容增强。

## 2026-02-09（P0：stage-js 时机补齐）

### 已完成
- 修复 `searchDebug` / `exploreDebug` 中误植入的目录阶段变量引用（移除错误的 `tocRule/fullUrl/stageBody` 片段，恢复使用 `body` 解析），消除编译风险。
- 在目录/正文链路统一补齐阶段响应脚本执行：
  - 目录阶段：`ruleToc.preUpdateJs`
  - 正文阶段：`ruleContent.webJs`
  - 覆盖生产链路与调试链路（`getToc`、`getTocDebug`、`getContent`、`getContentDebug` 及对应 debug flow）。
- 新增阶段 JS 回退解析能力：当运行时 JS 引擎不可用或执行返回空时，支持对常见脚本模式（赋值、拼接、`JSON.stringify`、`result/content` 变量）做轻量回退，避免链路直接退回原始响应。
- 新增回归测试：`test/rule_parser_engine_stage_js_compat_test.dart`，覆盖 `preUpdateJs` 与 `webJs` 在解析前生效。

### 为什么
- 现网与调试链路此前对 `preUpdateJs/webJs` 的执行时机不完整，导致一类 legado 书源在目录/正文阶段无法按预期预处理响应。
- 在当前测试环境中，原生 JS 动态库可能不可用；若无回退策略，阶段 JS 会“静默失效”，影响兼容性与可调试性。

### 验证方式
- 命令：`flutter analyze`
- 命令：`flutter test test/rule_parser_engine_stage_js_compat_test.dart`
- 命令：`flutter test test/rule_parser_engine_next_url_compat_test.dart`
- 命令：`flutter test test/rule_parser_engine_css_nth_compat_test.dart`

### 兼容影响
- 默认行为不变：当未配置 `preUpdateJs/webJs` 时，解析流程与旧行为一致。
- 兼容增强：配置阶段 JS 的书源在目录/正文阶段可按预期预处理响应；JS 引擎不可用时新增轻量回退，优先保障旧书源“可解析而非直接失效”。
- 回退策略仅在 JS 主执行返回空时启用，尽量不干扰已有可用脚本行为。

## 2026-02-09（P0-1：导入解析增强）

### 已完成
- 增强 `SourceImportExportService.importFromJson` 的输入容错：
  - 支持自动剥离 UTF-8 BOM（`\uFEFF`）前缀。
  - 支持多层字符串 JSON 递归解包（剪贴板/中转平台常见双重、三重转义场景）。
  - 条目级字符串对象同样走多层解包后再解析为书源对象。
- 保持原有重复 URL 覆盖策略与告警输出不变，仅增强“可读入能力”。
- 新增回归用例：
  - `importFromJson supports multi-level nested json string payload`
  - `importFromJson supports utf8 bom prefix payload`

### 为什么
- P0-1 要求“剪贴板导入支持对象/数组/字符串嵌套 JSON”。
- 实际分享场景下，书源文本常被多次 `jsonEncode` 或带 BOM；旧逻辑只解一层，容易导入失败。

### 验证方式
- 命令：`flutter analyze`
- 命令：`flutter test test/source_import_export_service_test.dart test/source_import_export_conflict_logic_test.dart`

### 兼容影响
- 默认行为不变：标准对象/数组导入逻辑不受影响。
- 兼容增强：此前因多层转义或 BOM 失败的输入现在可被正确导入。

## 2026-02-09（P0-2：搜索/发现失败源可诊断）

### 已完成
- 搜索页接入逐源调试结果聚合：每个书源独立执行，不因单源失败中断整体搜索；失败源以“可查看”入口展示。
- 发现页接入逐源调试结果聚合：保持与搜索页一致的失败源提示与查看交互。
- 新增失败原因归类与压缩展示：覆盖请求错误（含 HTTP 状态码）、解析错误、列表命中但关键字段缺失（`name/bookUrl`）等场景。
- 空结果态补充引导：当本次存在失败书源时，明确提示用户查看失败详情继续定位。

### 为什么
- 对齐 `DEV_PLAN` 的 P0-2 目标：
  - 单个书源失败不影响其他书源继续执行；
  - 请求/解析失败要给出可读、可定位的信息。
- 现有流程虽可继续执行，但失败原因主要停留在调试页，搜索/发现主流程缺少聚合反馈，不利于快速排障。

### 验证方式
- 命令：`flutter analyze`
- 命令：`flutter test test/rule_parser_engine_rule_split_compat_test.dart test/rule_parser_engine_variable_rule_compat_test.dart test/rule_parser_engine_next_url_compat_test.dart`
- 手工：在搜索页/发现页触发多书源请求，确认失败源显示“查看”入口，弹窗可见按书源分组的失败原因。

### 兼容影响
- 规则语义无变更：未修改解析引擎协议语义，仅调整搜索/发现页对调试结果的消费与展示。
- 行为增强：失败反馈从“弱提示/静默”提升为“可读可定位”，对旧书源兼容性预期无负向影响。

## 2026-02-09（对标输入收敛：截图 + 官方指南）

### 已完成
- 基于用户提供的 10 张同类软件截图，提炼阅读主界面、快捷设置、界面设置、点击区域等核心对标项。
- 引入官方操作指南链接作为对标输入（`https://www.jinlintech.com.cn/product/guide/`），并与现有实现进行能力盘点。
- 新增对标矩阵文档：`docs/HAPPY_PARITY_MATRIX.md`，按“已实现/部分实现/待实现”输出分项清单。
- 更新开发计划 `docs/DEV_PLAN.md`：在 P2 增补“阅读主界面对标、界面设置精调、阅读态换源闭环”三项任务。

### 为什么
- 本轮需求明确要求“对标同类软件功能”，同时强调“规则协议以 legado 为标准”。
- 需先把对标输入结构化，避免后续开发只做 UI 模仿而偏离协议兼容与主链路稳定目标。

### 验证方式
- 文档检查：
  - `docs/HAPPY_PARITY_MATRIX.md`
  - `docs/DEV_PLAN.md`
  - `docs/DEV_PROGRESS.md`
- 一致性校验：对标项均标注“协议语义不变（legado 优先）”约束。

### 兼容影响
- 本次仅新增/更新文档，不涉及运行时代码与规则解析逻辑改动。
- 对旧书源兼容性无影响。

## 2026-02-09（P0-3：加入书架稳定性增强）

### 已完成
- 增强 `BookAddService` 目录回退策略：
  - 优先使用详情页 `tocUrl`；
  - 若目录为空且与 `bookUrl` 不同，则自动回退尝试 `bookUrl`。
- 细化加书失败提示：当目录为空时，补充“已尝试目录地址/书籍地址”的上下文和调试摘要（HTTP/解析提示）。
- 增强章节入库前过滤：过滤章节名或章节链接为空的目录项，并重建连续索引，避免脏数据写入。
- 新增入库后校验与回滚：
  - 若章节入库数量为 0，自动回滚已写入书籍并返回明确错误；
  - 若实际章节数与书籍记录不一致，自动修正 `totalChapters`。
- 异常路径补充保护：写入链路异常时自动回滚已写入书籍，避免“书在书架但无目录”的半成功状态。
- 新增回归测试：`test/book_add_service_test.dart`
  - 覆盖“`tocUrl` 失败后回退 `bookUrl` 成功”；
  - 覆盖“目录条目无效时返回清晰错误且不落库”。

### 为什么
- 对齐 `DEV_PLAN` 的 P0-3 要求：
  - 详情解析失败/目录异常时要有兜底；
  - 目录为空要给出可定位提示，不做静默失败；
  - 章节写入结果要可靠，避免出现 0 章或不一致。

### 验证方式
- 命令：`flutter analyze`
- 命令：`flutter test test/book_add_service_test.dart`
- 命令：`flutter test test/rule_parser_engine_next_url_compat_test.dart test/rule_parser_engine_variable_rule_compat_test.dart`

### 兼容影响
- 规则语义不变：未修改 legado 规则协议解析，仅增强加书业务层兜底与提示。
- 行为增强：目录异常场景从“泛化失败”提升为“可读错误 + 自动回退 + 半成功回滚”，对旧书源预期为正向兼容。

## 2026-02-09（P0-3 补充：目录去重语义对齐 legado）

### 已完成
- 在 `BookAddService` 的章节构建阶段增加“按章节 URL 去重”逻辑，避免同一目录地址被重复入库。
- 维持“过滤空标题/空链接 + 连续重建章节索引”行为不变，确保最终落库章节可读且索引稳定。
- 更新回归用例 `test/book_add_service_test.dart`：在“`tocUrl` 回退 `bookUrl` 成功”场景注入重复章节 URL，验证最终只入库唯一章节。

### 为什么
- 对齐 legado 的目录处理语义：目录聚合后会按章节唯一性去重，避免翻页或规则重复命中造成重复章节。
- 对齐 flutter_novel 的“加书即能读”目标：减少重复目录导致的阅读跳章、进度错位风险。

### 验证方式
- 命令：`flutter test test/book_add_service_test.dart`
- 命令：`flutter analyze`

### 兼容影响
- 规则协议无变更：不影响 `ruleToc` 语义与 URL 解析。
- 行为优化：仅在同 URL 重复章节场景生效，旧书源正常目录不受影响。

## 2026-02-09（P0-2 补充：搜索/发现结果去重与稳定排序）

### 已完成
- 搜索页改为按书源权重稳定执行：启用书源按 `weight` 降序、名称升序顺序运行，避免每次顺序漂移。
- 发现页保持同样的稳定排序策略（原有 `_eligibleSources` 排序继续沿用），与搜索页行为一致。
- 搜索/发现新增聚合去重：按 `sourceUrl + bookUrl` 作为唯一键去重，同一来源重复结果仅保留首条。

### 为什么
- 对齐 legado 常见多源聚合体验：减少重复书目干扰，提升结果列表可读性。
- 对齐 flutter_novel 的“能快速找到并加入正确书籍”目标：去重后用户选择成本更低。

### 验证方式
- 命令：`flutter analyze`
- 命令：`flutter test test/book_add_service_test.dart`
- 手工：多书源搜索/发现同一本书，确认列表内同源同链接结果不重复，加载顺序稳定。

### 兼容影响
- 规则协议无变更：不影响解析规则与请求链路。
- 行为优化：仅影响结果展示聚合，减少重复项，不改变单条结果字段语义。

## 2026-02-09（P0-2 补充：书单导入逐源异常隔离）

### 已完成
- 增强 `BookshelfBooklistImportService.importBySearching`：单个书源搜索异常不再中断当前书目导入，会继续尝试后续可用书源。
- 新增书单导入错误摘要压缩：当某书未导入且存在书源异常时，错误信息附带“部分书源异常”与书源名/摘要，便于快速定位。
- 新增回归测试 `test/bookshelf_booklist_import_service_test.dart`：
  - 覆盖“高权重书源异常但低权重书源成功命中时，导入仍成功”；
  - 覆盖“全部书源异常时，失败信息包含书源级异常提示”。

### 为什么
- 对齐 P0-2 的“单源失败不影响整体”要求，并将该语义补齐到“书单批量导入”链路。
- 现有书单导入在多源场景下对书源异常可观测性不足，难以快速判断是“真未搜到”还是“可用源异常”。

### 验证方式
- 命令：`flutter test test/bookshelf_booklist_import_service_test.dart`
- 命令：`flutter analyze`

### 兼容影响
- 规则协议无变更：仅调整书单导入流程容错与提示文本。
- 行为增强：异常场景下导入成功率提升，失败反馈更可诊断；对正常书源流程无影响。

## 2026-02-09（P0-1 补充：网络导入可诊断性增强）

### 已完成
- 重构 `SourceImportExportService.importFromUrl` 的请求入口，支持注入式 `httpFetcher`，便于单测覆盖网络导入分支。
- 网络导入新增“重定向提示”：当请求地址与最终 `realUri` 不一致时，将“已跟随重定向”写入导入警告。
- Web 场景 CORS 错误提示升级为可执行文案：明确建议改用“从剪贴板导入”或“从文件导入”。
- 网络异常消息细化：对连接超时/接收超时/证书异常/HTTP 状态异常等场景输出更可读提示。
- 新增回归测试（`test/source_import_export_service_test.dart`）：
  - `importFromUrl adds redirect warning when realUri changed`
  - `importFromUrl returns actionable CORS hint on web`

### 为什么
- 对齐 `DEV_PLAN` 的 P0-1 要求：网络导入需可观测、可落地替代，不应只返回泛化错误。
- 真实用户导入场景中“短链跳转 + Web 跨域失败”较常见，需要明确告知下一步操作。

### 验证方式
- 命令：`flutter test test/source_import_export_service_test.dart test/source_import_export_conflict_logic_test.dart test/legado_json_test.dart`
- 命令：`flutter analyze`

### 兼容影响
- 规则协议无变更：仅增强导入服务错误/警告语义与可测性。
- 行为增强：网络导入失败更可诊断，成功导入时可见重定向路径提示；不影响文件/剪贴板导入流程。

## 2026-02-09（P0-4 补充：阅读进度按章节保存）

### 已完成
- `SettingsService` 新增章节维度滚动偏移键：支持按 `bookId + chapterIndex` 保存/读取滚动进度。
- 保留旧版书籍维度偏移回退：当章节键不存在时自动回退到旧键，保证历史数据可继续恢复。
- `SimpleReaderView` 保存进度时改为写入“当前章节偏移”，避免章节切换后偏移互相覆盖。
- `SimpleReaderView` 恢复进度时增加偏移钳制（`0..maxScrollExtent`），避免页面内容变化导致越界跳转。
- 新增回归测试：`SettingsService stores scroll offsets by chapter with fallback`。

### 为什么
- 对齐 `DEV_PLAN` 的 P0-4 要求：阅读进度要可靠保存与恢复，尤其在章节切换后不能串位。
- 旧实现仅按书保存偏移，切换章节后容易恢复到错误位置，影响连续阅读体验。

### 验证方式
- 命令：`flutter test test/rule_parser_engine_next_url_compat_test.dart test/app_settings_test.dart`
- 命令：`flutter analyze`

### 兼容影响
- 规则协议无变更：不影响 `ruleContent/nextContentUrl` 解析语义。
- 行为增强：滚动模式下章节进度恢复更准确；旧用户数据通过回退键保持可用。

## 2026-02-09（P0-4 补充：翻页模式章节进度恢复）

### 已完成
- `SettingsService` 新增章节级“分页进度”持久化：
  - `saveChapterPageProgress(bookId, chapterIndex, progress)`
  - `getChapterPageProgress(bookId, chapterIndex)`
- `SimpleReaderView` 进度保存统一写入章节进度（滚动模式按偏移、翻页模式按 `PageFactory` 页码占比）。
- 修复章节恢复顺序：翻页模式先 `jumpToChapter`，再按章节进度恢复页码，避免被章节跳转覆盖。
- 修复初始化覆盖问题：首次进入 `restoreOffset=true` 时不立即回写进度，避免旧进度被 0 覆盖。
- 新增回归测试：`SettingsService stores chapter page progress and clamps values`。

### 为什么
- 对齐 `DEV_PLAN` 的 P0-4 目标：除滚动模式外，翻页模式也要实现稳定的“退出再进恢复到合理位置”。
- 旧逻辑仅保存滚动偏移，翻页模式缺少章节内页码进度持久化，恢复精度不足。

### 验证方式
- 命令：`flutter test test/rule_parser_engine_next_url_compat_test.dart test/app_settings_test.dart`
- 命令：`flutter analyze`

### 兼容影响
- 规则协议无变更：仅增强阅读进度持久化策略。
- 行为增强：翻页模式恢复更稳定；旧数据仍可通过原偏移键回退读取。

## 2026-02-09（P0-4 补充：恢复期进度防覆盖 + replaceRegex 链容错）

### 已完成
- 阅读器新增 `_isRestoringProgress` 保护：章节恢复阶段忽略滚动结束触发的自动保存，避免旧进度被瞬时偏移覆盖。
- 正文 `replaceRegex` 链执行改为“单条失败不中断”：
  - 某条正则编译失败时回退为字面量替换；
  - 当前条仍失败则跳过，但后续条继续执行。
- 新增回归用例：`ruleContent.replaceRegex keeps later rules when one is invalid`，验证坏规则不影响后续替换链。

### 为什么
- 对齐 `DEV_PLAN` P0-4 的“进度保存可靠 + 正文净化可用”目标：恢复流程不应破坏历史进度，净化规则异常不应导致整体失效。
- 真实书源中 `replaceRegex` 常含旧规则/异常规则，需具备链式容错能力。

### 验证方式
- 命令：`flutter test test/rule_parser_engine_next_url_compat_test.dart test/rule_parser_engine_stage_js_compat_test.dart test/app_settings_test.dart`
- 命令：`flutter analyze`

### 兼容影响
- 规则协议无变更：`replaceRegex` 语法保持不变。
- 行为增强：异常规则影响范围缩小到单条，阅读恢复阶段更稳定。

## 2026-02-09（P0-4 补充：滚动/翻页模式切换进度一致性）

### 已完成
- 新增阅读进度换算工具 `ChapterProgressUtils`，统一“分页索引 ↔ 章节进度”转换公式，避免不同路径使用不同口径。
- `SimpleReaderView._updateSettings` 切换模式时改为复用统一换算逻辑：
  - 翻页 → 滚动：先取章节进度再映射到滚动偏移；
  - 滚动 → 翻页：按章节进度恢复到目标页，且目标页与当前页一致时不重复跳转。
- `SimpleReaderView._loadChapter` 章节恢复页码改为统一换算逻辑，确保“保存进度/恢复进度/模式切换”三条链路语义一致。
- `SimpleReaderView._getChapterProgress` 在翻页模式下改为复用统一工具，保证状态栏进度展示与持久化进度口径一致。
- 新增测试 `test/chapter_progress_utils_test.dart`：覆盖边界值、钳制和“progress→page→progress”稳定性。

### 为什么
- 对齐 `DEV_PLAN` P0-4 的“进度保存可靠”要求：模式切换前后应尽量保持同一阅读位置，不应出现跨页漂移。
- 之前不同位置存在“基于 `total`”与“基于 `total-1`”的混用，易导致切换后页码偏差或重复触发进度写入。

### 验证方式
- 命令：`flutter test test/chapter_progress_utils_test.dart test/app_settings_test.dart`
- 命令：`flutter test test/rule_parser_engine_next_url_compat_test.dart test/rule_parser_engine_stage_js_compat_test.dart`
- 命令：`flutter analyze`

### 兼容影响
- 规则协议无变更：不涉及书源规则解析与 legado 语义。
- 行为优化：仅统一阅读进度换算与恢复策略，提升模式切换后的定位稳定性；旧进度数据仍可按现有键读取。

## 2026-02-09（P0-5 补充：调试摘要结构化与导出增强）

### 已完成
- 新增调试摘要解析器 `SourceDebugSummaryParser`：从调试日志中提取结构化诊断信息，按“请求 / 解析 / 错误”三段输出。
- 请求摘要增强：提取阶段、请求序号、URL、HTTP 状态码、耗时、CookieJar 开关、请求决策信息，以及关键请求头（自动脱敏 `Cookie/Authorization/Token`）。
- 解析摘要增强：提取列表大小、书籍总数、章节总数、正文分页统计（提取长度/清理后长度）与正文翻页停止原因。
- 调试页新增“结构化调试摘要（脱敏）”查看与复制入口，便于用户反馈时快速给出可读信息。
- 调试包导出新增 `summary.json`，并在 `bundle.json` 中追加 `structuredSummary` 字段，保持“文本日志 + 结构化摘要”双轨输出。

### 为什么
- 对齐 `DEV_PLAN` 的 P0-5 要求：失败时需快速判断是“请求失败/解析规则问题/分页中断”，降低只能读长日志的排查成本。
- 现有调试能力以文本日志为主，虽信息全但不易机器聚合和用户反馈；补齐结构化摘要可提升定位效率。

### 验证方式
- 命令：`flutter test test/source_debug_summary_parser_test.dart`
- 命令：`flutter test test/source_import_export_service_test.dart test/source_import_export_conflict_logic_test.dart test/legado_json_test.dart`
- 命令：`flutter analyze`

### 兼容影响
- 规则协议无变更：未修改 legado 规则语义与解析流程。
- 行为增强：仅新增调试信息聚合与导出字段，不影响正常阅读/书源导入主链路。

## 2026-02-09（P0-5 补充：调试页失败分类标签）

### 已完成
- 在结构化摘要中新增 `diagnosis` 字段，输出：
  - `labels`（失败分类标签）
  - `hints`（定位建议）
  - `primary`（主标签）
- 分类规则落地：
  - `request_failure`：请求失败/HTTP 异常/超时等网络层问题；
  - `parse_failure`：请求成功但列表/章节/正文为空、规则不匹配等解析层问题；
  - `paging_interrupted`：命中“下一章阻断”或正文分页异常提前结束；
  - `ok` / `no_data`：无明显异常 / 暂无调试数据。
- 调试页新增“诊断标签”卡片：顶部直接显示彩色标签与定位建议，支持点击查看结构化详情。
- 保持导出一致：`bundle.json` 的 `structuredSummary` 自动包含新 `diagnosis` 信息，便于问题反馈复现。

### 为什么
- 对齐 `DEV_PLAN` 的 P0-5 可诊断目标：用户应先看到“失败属于哪一类”，再决定看请求头、规则字段还是分页规则。
- 之前虽有日志与摘要，但缺少“可直接行动”的分类标签，排查路径不够收敛。

### 验证方式
- 命令：`flutter test test/source_debug_summary_parser_test.dart`
- 命令：`flutter analyze`
- 手工：书源编辑页 → 调试 Tab → 运行调试后确认顶部出现“请求失败/解析失败/分页中断/基本正常”等标签与建议。

### 兼容影响
- 规则协议无变更：不影响 legado 规则解析语义。
- 行为增强：仅新增调试可视化诊断层；导出字段向后兼容（新增字段不会影响旧消费方）。

## 2026-02-09（P0-5 补充：可用性检测接入失败分类）

### 已完成
- 新增 `SourceAvailabilityDiagnosisService`，将可用性检测结果统一映射为诊断标签：
  - `request_failure` / `parse_failure` / `paging_interrupted` / `ok` / `no_data`
- `SourceAvailabilityCheckView` 的每个检测项新增 `diagnosis` 字段，检测流程中按 search/explore 结果实时写入分类。
- 检测列表 UI 增强：在状态右侧新增诊断标签胶囊（主标签），长按/点击详情可看到完整建议。
- 检测详情文本增强：新增“诊断/建议”字段，便于一键复制反馈。
- 检测报告增强：导出/复制文本增加 `diag=` 信息，支持批量结果快速筛查。

### 为什么
- 对齐 P0-5 的可诊断目标：批量检测时不仅看“失败/空列表”，还要能快速知道“请求层问题”还是“规则解析问题”。
- 避免用户逐条进入调试页排查，先在检测总览阶段收敛排查方向。

### 验证方式
- 命令：`flutter test test/source_availability_diagnosis_service_test.dart test/source_debug_summary_parser_test.dart`
- 命令：`flutter analyze`
- 手工：书源管理 → 可用性检测，完成后检查列表右侧出现诊断标签（如“请求失败/解析失败/基本正常”），详情页可见“诊断/建议”。

### 兼容影响
- 规则协议无变更：仅新增诊断映射与展示层。
- 行为增强：不改变原有检测判定（可用/失败/空列表），仅追加分类维度与报告信息。

## 2026-02-09（计划治理：DEV_PLAN 改为 Todo 看板）

### 已完成
- 将 `docs/DEV_PLAN.md` 增补“当前执行 Todo（滚动看板）”区块，按 `Done / Doing / Todo` 展示下一阶段开发顺序。
- 已完成项（P0-1 ~ P0-5）统一标记为 `[x]`，与当前代码/测试现状一致。
- 明确当前进行中项：`P1-1 书源管理交互收敛`，并列出后续待办，便于连续开发执行。

### 为什么
- 当前开发已从“阶段规划”进入“连续执行”模式，需要一个可直接落地的 Todo 看板而非纯愿景型计划。
- 统一计划状态与已落地能力，避免后续开发中重复做已完成事项。

### 验证方式
- 文档检查：`docs/DEV_PLAN.md`
- 对照检查：`docs/DEV_PROGRESS.md` 中的 P0 交付记录与 `DEV_PLAN` 中的 `[x]` 项一致。

### 兼容影响
- 本次仅文档调整，不涉及运行时代码与规则语义。
- 对旧书源与现有功能行为无影响。

## 2026-02-09（P1-1 补充：书源管理筛选与批量启用禁用）

### 已完成
- 书源管理页新增“启用状态筛选”分段控件：`全部状态 / 仅启用 / 仅失效`，可与分组筛选叠加使用。
- 新增批量操作：
  - `批量启用当前筛选`
  - `批量禁用当前筛选`
  支持对“当前分组 + 当前状态筛选”结果集批量生效。
- 删除失效书源改为“先确认再删除”，并在无可删项时给出明确提示。
- 抽离筛选逻辑到 `SourceFilterHelper`（构建分组/分组过滤/启用状态过滤），避免 UI 层重复拼装规则。
- 新增单测 `test/source_filter_helper_test.dart`，覆盖分组提取、分组过滤与状态过滤。

### 为什么
- 对齐 P1-1 的“书源管理更好用”目标：用户需要在大量书源下快速筛选并批量修正启用状态。
- 之前仅支持单条开关，维护成本高；批量能力可显著降低清理失效源的操作成本。

### 验证方式
- 命令：`flutter test test/source_filter_helper_test.dart test/source_availability_diagnosis_service_test.dart`
- 命令：`flutter analyze`
- 手工：书源管理页切换分组与状态筛选，使用“更多”菜单执行批量启用/禁用，确认数量与筛选范围一致。

### 兼容影响
- 规则协议无变更：仅改进书源管理交互与批量操作。
- 行为增强：新增批量入口与删除确认，不影响原有单条启用开关与导入导出链路。

## 2026-02-09（P1-2：书源编辑器规则页一键测试补齐）

### 已完成
- 书源编辑页「规则」Tab 新增“规则页快速测试”区块：
  - `测试搜索规则`：优先使用 `ruleSearch.checkKeyWord`，为空时回退 `我的`，自动切到调试页并立即执行。
  - `测试正文规则`：优先使用最近一次调试提取的 `chapterUrl`，自动组装 `--contentUrl` 并执行；若缺少章节链接给出明确提示。
- 新增 `SourceQuickTestHelper`，统一封装快速测试 key 生成逻辑（搜索 key 回退、正文 key 组装），避免 UI 层散落拼接规则。
- 新增单测 `test/source_quick_test_helper_test.dart`，覆盖：
  - 搜索 key 优先/回退行为；
  - 正文 key 的空值处理、`--` 前缀补齐与幂等行为。
- 对快速测试流程做了等价简化（提炼公共 guard 与跳转执行函数），减少重复逻辑，行为保持不变。

### 为什么
- 对齐 `DEV_PLAN` 的 P1-2 目标：书源编辑器需要“边改规则边验证”的最短闭环，优先覆盖搜索与正文两条高频链路。
- 之前用户需手动切 Tab、手填 key、再点调试，步骤多且容易输错；快速入口可明显降低调试成本。

### 验证方式
- 命令：`flutter test test/source_quick_test_helper_test.dart test/source_filter_helper_test.dart test/source_availability_diagnosis_service_test.dart`
- 命令：`flutter analyze`
- 手工：书源编辑页 → 规则 Tab → 点击“测试搜索规则/测试正文规则”，确认会自动切到调试 Tab 并触发调试；无章节链接时正文测试会提示先获取 `chapterUrl`。

### 兼容影响
- 规则协议无变更：未修改 legado 规则语义、字段结构与解析流程。
- 行为增强：仅新增规则页快速测试入口与提示，不影响原有调试页手动输入 key 流程。

## 2026-02-09（P2 首批：阅读界面对标与换源入口打通）

### 已完成
- 新增阅读器对标任务看板：`docs/READER_PARITY_TODO.md`，按 `P0/P1/P2` 拆分“顶栏动作、底栏结构、快捷设置、换源闭环”等可执行项。
- 阅读页顶栏对标增强（参考你提供的同类阅读器截图）：
  - `ReaderTopMenu` 新增 `换源 / 净化 / 刷新` 动作入口；
  - `净化` 直连 `ReadingSettings.cleanChapterTitle`，支持一键切换；
  - 顶栏章节副标题增加当前源名展示（`源名 · 章节名`）。
- 阅读页换源链路补齐最小闭环：
  - 新增 `ReaderSourceSwitchHelper`（候选筛选/排序）：按“书名匹配 + 作者优先”，排除当前源；
  - 换源时并发尝试启用书源搜索（单源失败隔离），弹出候选列表；
  - 选择候选后拉取详情与目录，重建本书章节并更新书籍 `sourceUrl/sourceId`；
  - 尝试按当前章节名定位新源章节；失败时回退到相近索引，保证可继续阅读。
- 底栏与快捷设置信息架构对标收敛：
  - 底栏文案改为 `目录 / 字体 / 界面 / 设置`；
  - 快捷设置 Tab 改为 `字体 / 界面 / 设置 / 更多`；
  - `界面` Tab 增加四边内容边距（上/下/左/右）与页眉页脚显隐/分割线开关；
  - `更多` Tab 增加“净化章节标题/音量键翻页”开关与“打开完整阅读设置”入口。

### 为什么
- 你提供的截图核心是“阅读态高频操作前置”：换源、净化、刷新不应深藏在多层面板。
- 之前阅读页虽有完整设置能力，但入口分散、命名与同类阅读器差异较大；本次先把高频路径对齐，减少学习成本。

### 验证方式
- 命令：`flutter analyze`
- 命令：`flutter test test/reader_source_switch_helper_test.dart test/chapter_progress_utils_test.dart`
- 手工：
  - 阅读页唤出菜单，检查顶栏出现“换源/净化/刷新”；
  - 点“净化”后正文标题净化开关应立即生效；
  - 点“换源”出现候选列表，切换后章节可继续打开；
  - 底栏为“目录/字体/界面/设置”，并能打开对应快捷设置分组。

### 兼容影响
- 书源规则语义无变更：仍以 legado 协议为准，未修改规则解析引擎协议行为。
- 行为增强：阅读页新增换源与快捷动作入口；若换源失败，会提示原因并保留当前源，不影响既有阅读链路。

## 2026-02-09（P2 续：阅读态换源闭环增强）

### 已完成
- 增强 `ReaderSourceSwitchHelper`：
  - 候选去重由“仅 bookUrl”升级为“`source + bookUrl`”组合去重，避免跨源误去重；
  - 新增 `normalizeChapterTitle`，对章节标题做编号/符号归一，提升跨源章节对齐成功率；
  - 新增 `resolveTargetChapterIndex`，支持“章节名精确匹配 → 章节名弱匹配 → 索引回退”三级策略。
- 阅读页换源流程升级：
  - 切源后目标章节定位改为调用 `resolveTargetChapterIndex`；
  - 章节加载改为 `restoreOffset: true`，切源后尽量保持阅读进度连续；
  - 增加失败回滚：若切源中途异常，自动恢复旧章节列表与旧源信息，避免读到一半丢上下文。
- 新增/增强单测：
  - `test/reader_source_switch_helper_test.dart` 增加候选去重、章节定位和回退索引覆盖用例。

### 为什么
- 同名书跨源后章节标题经常存在“第X章/ChapterX/符号差异”，仅做简单字符串等值匹配命中率不够。
- 换源异常时必须保障“当前阅读不被破坏”，这是阅读态高频操作的稳定性底线。

### 验证方式
- 命令：`flutter test test/reader_source_switch_helper_test.dart`
- 命令：`flutter analyze`
- 手工：阅读页执行“换源”，确认：
  - 同名章节可优先跳转；
  - 无同名章节时按接近索引回退；
  - 异常场景下仍保留原源与原章节可继续阅读。

### 兼容影响
- 规则协议无变更：未改 legado 规则解析语义。
- 行为增强：仅提升换源候选筛选、章节定位与失败回滚鲁棒性。

## 2026-02-09（P2 续：完整阅读设置面板结构细化）

### 已完成
- 完整阅读设置面板（`SimpleReaderView`）的 Tab 文案统一为：`排版 / 界面 / 翻页 / 其他`，与当前“底栏 + 快捷设置”信息架构保持一致。
- 清理完整设置中的不可达分支：移除 `case 10/11/12` 对应的旧入口逻辑，并删除遗留未使用的旧面板方法，避免后续维护误导。
- 界面设置分组补齐并前置高频项：
  - 新增 `界面设置（常用）` 卡片，亮度与“跟随系统亮度”置顶；
  - 新增 `内容边距（常用）`（上/下/左/右独立调节）；
  - 新增 `页眉页脚（常用）`（隐藏页眉/页脚 + 分割线）。
- 翻页设置分组前置高频项：
  - 将翻页模式、`音量键翻页`、`净化章节标题` 收敛到 `翻页设置（常用）`；
  - 保留 `翻页手感`（动画/灵敏）作为进阶参数。
- 其他设置分组文案统一为 `其他设置`，减少与“更多/其他”混用造成的理解成本。

### 为什么
- 对齐阅读器对标 Todo 的 P1 目标：`“排版设置/界面设置/其他设置”文案与分组统一`、`常用项顺序优化（高频项前置）`。
- 之前完整设置存在老分支残留（不可达 case）与命名不一致问题，容易造成“快捷设置和完整设置不是同一套概念”的使用割裂。

### 验证方式
- 命令：`flutter analyze lib/features/reader/views/simple_reader_view.dart lib/features/reader/widgets/reader_bottom_menu.dart lib/features/reader/widgets/reader_quick_settings_sheet.dart`
- 命令：`flutter test test/reader_source_switch_helper_test.dart test/chapter_progress_utils_test.dart`
- 手工：阅读页打开完整设置，确认：
  - Tab 顺序为 `排版/界面/翻页/其他`；
  - `界面` 首屏可直接调亮度、边距、页眉页脚显隐；
  - `翻页` 首屏可直接切模式并开关“音量键翻页/净化章节标题”。

### 兼容影响
- 规则协议无变更：未修改 legado 书源规则语义与解析链路。
- 行为调整仅限阅读设置 UI 分组与入口顺序，原设置字段保持兼容。

## 2026-02-09（P2 续：阅读页整体 UI/UX 重构，对标同类阅读器）

### 已完成
- 阅读页顶部菜单重构（`ReaderTopMenu`）：
  - 改为“渐变沉浸 + 圆角操作按钮”视觉层级；
  - 保留并强化高频动作：`换源 / 净化 / 刷新 / 目录`；
  - 书名与“源名·章节名”合并为主次信息，提升信息密度与可读性。
- 阅读页底部菜单重构（`ReaderBottomMenuNew`）：
  - 从“单一底部导航”升级为“章节进度 + 高频设置 + 底部导航”复合结构；
  - 新增高频行内操作：亮度（含常亮切换）、字号 `A-/A+`、翻页模式 chips、音量键翻页、净化标题、自动阅读；
  - 保留 `目录 / 字体 / 界面 / 设置` 导航入口，交互对齐截图中的阅读器布局。
- 新增右侧悬浮快捷栏（`SimpleReaderView`）：
  - 提供 `书签 / 目录 / 字体 / 界面 / 自动阅读` 五个快捷操作；
  - 支持书签状态高亮、自动阅读运行态高亮；
  - 快捷栏操作统一与底栏能力联动，减少深层菜单跳转。
- 阅读交互细节联调：
  - 新增菜单收起统一方法，打开快捷设置/目录时自动关闭阅读菜单并恢复沉浸模式；
  - 自动阅读入口重新打通（菜单与悬浮栏均可控制开始/停止）；
  - 章节切换后自动刷新当前章节书签状态，避免状态滞后。
- 快捷设置面板微调：
  - 头部左侧由“完成”改为关闭图标，贴近参考界面；
  - Tab 文案 `设置` 调整为 `翻页`，语义更明确。

### 为什么
- 用户提供的同类阅读器截图核心特征是“阅读态高频能力外露”：不依赖多层弹窗即可完成换源、净化、目录、字体与翻页调整。
- 现有阅读页虽然功能完整，但入口分散、视觉层级偏弱；本次重构优先解决“操作路径长、状态反馈弱、视觉一致性不足”的体验问题。

### 验证方式
- 命令：`flutter analyze lib/features/reader/views/simple_reader_view.dart lib/features/reader/widgets/reader_bottom_menu.dart lib/features/reader/widgets/reader_menus.dart lib/features/reader/widgets/reader_quick_settings_sheet.dart`
- 命令：`flutter test test/reader_source_switch_helper_test.dart test/chapter_progress_utils_test.dart`
- 手工：阅读页唤出菜单后验证：
  - 顶栏展示重构后的操作布局与信息层级；
  - 右侧浮动栏可执行书签/目录/字体/界面/自动阅读；
  - 底栏可直接调亮度、字号、翻页模式、音量键翻页和净化标题。

### 兼容影响
- 规则协议无变更：不涉及 legado 规则语义修改。
- 行为调整集中在阅读 UI/UX 与入口组织，底层阅读链路（目录/正文/翻页/进度）保持兼容。

## 2026-02-09（P0：书源能力 legado 全量对标梳理）

### 已完成
- 新增 `docs/LEGADO_SOURCE_PARITY_MATRIX.md`：
  - 以 `legado` 的 `BookSource/BaseSource/AnalyzeRule/AnalyzeUrl` 为基线，完成书源能力分模块对照；
  - 逐项标注 `✅/🟡/⬜`，覆盖字段层、规则语义层、URL 请求链、五段链路、调试与编辑器能力；
  - 输出“完全对标阻塞项”与 `P0/P1/P2` 可执行 Todo。
- 更新 `docs/next_development_checklist.md`：
  - 将“建立 legado 规则对齐矩阵”从待办改为已完成；
  - 在未完成项中补充矩阵文档链接，统一后续整改入口。
- 更新 `docs/DEV_PLAN.md`：
  - 在 Done 增补“书源能力 legado 对标矩阵与分级 Todo”；
  - 在 Todo 增补三项 P0 任务：登录语义链、段评/正文扩展语义、导入导出保真。

### 为什么
- 当前项目已具备主流程能力，但“声明级完全对标 legado”还缺少统一可追溯的差距矩阵。
- 在继续功能开发前先把协议差距明确化，可避免后续出现“功能能跑但语义不兼容”的返工。

### 验证方式
- 文档检查：
  - 打开 `docs/LEGADO_SOURCE_PARITY_MATRIX.md`，核对每个模块均有“基线 + 映射 + 状态 + 结论”；
  - 打开 `docs/next_development_checklist.md`，确认 2.1 第一项已标记完成并带矩阵链接；
  - 打开 `docs/DEV_PLAN.md`，确认 Done/Todo 已同步本次梳理结果。
- 一致性检查：
  - 矩阵中的未对齐项（如登录链、`ruleReview`、`imageDecode/payAction`）在代码中应能找到“仅字段存在、执行链缺失”的对应事实。

### 兼容影响
- 本次仅更新文档与计划，不修改运行时代码；
- 对现有书源解析行为无直接变更。

## 2026-02-09（P0 续：书源导入流程向 legado 保真语义对齐）

### 已完成
- 导入服务增强：`SourceImportResult` 新增 `sourceRawJsonByUrl`，在 `importFromJson` 阶段保留每个书源的原始 JSON（按 `LegadoJson` 归一）。
- 导入入库链路调整：`SourceListView` 在导入提交时优先使用 `SourceRepository.upsertSourceRawJson` 写入（按 URL 取对应 rawJson），避免导入阶段丢失未知字段。
- 导入相关回归测试补充：新增 `importFromJson keeps raw json mapping by source url` 用例，验证重复 URL 场景下会保留“后出现项”的原始字段。
- 文档/计划同步：
  - `docs/LEGADO_SOURCE_PARITY_MATRIX.md` 增补“书源界面使用逻辑（导入/调试/编辑）”对齐表；
  - `docs/DEV_PLAN.md` 与 `docs/next_development_checklist.md` 增补“书源界面流程对齐 legado”任务。

### 为什么
- 你要求“书源界面使用逻辑、导入书源、调试书源都应与 legado 一样”。
- 其中导入链路是兼容性的基础环节；若导入即丢字段，后续调试/编辑再完善也会受限。

### 验证方式
- 命令：`flutter test test/source_import_export_service_test.dart`
- 命令：`flutter analyze lib/features/source/services/source_import_export_service.dart lib/features/source/views/source_list_view.dart`
- 手工：
  - 导入包含自定义未知字段的书源 JSON；
  - 在书源编辑页切换 JSON 视图确认字段仍保留；
  - 重复 URL 导入时确认采用“后出现项覆盖”。

### 兼容影响
- 行为增强：导入阶段更偏向 legado 保真语义（未知字段不轻易丢失）。
- 无破坏性变更：原有导入入口、冲突处理和错误提示保持兼容。

## 2026-02-09（P0 续：登录态缓存与请求链对齐 legado）

### 已完成
- 新增 `lib/core/services/source_login_store.dart`：
  - 支持按书源 key 持久化 `loginHeader`（JSON Map）与 `loginInfo`（文本）；
  - 提供读取/保存/清理接口，语义对齐 legado `BaseSource` 登录缓存能力。
- 请求链路接入登录头：
  - `RuleParserEngine` 的 `_fetch/_fetchDebug` 增加 `sourceKey`，会在请求头构建时自动合并 `SourceLoginStore` 中的登录头；
  - 合并顺序对齐 legado：`书源 header -> 登录 header -> URL option headers`（URL option 最高优先级）。
- 书源编辑页补登录态缓存入口（`SourceEditView`）：
  - 新增“登录头缓存(JSON)”与“登录信息缓存”输入项；
  - 新增“加载登录态缓存 / 保存登录态缓存 / 清除登录态缓存”操作；
  - 保存书源时会静默保存登录态缓存。
- 测试补充：
  - 新增 `test/source_login_store_test.dart`；
  - `test/rule_parser_engine_url_option_compat_test.dart` 增加“登录头并入与 URL option 覆盖优先级”用例。

### 为什么
- legado 的登录能力不仅是字段存在，还包括“登录态缓存 + 请求自动携带”。
- 先补齐这一基础语义后，再推进 `loginUrl/loginCheckJs` 脚本执行闭环，能显著降低兼容风险。

### 验证方式
- 命令：`flutter test test/source_login_store_test.dart test/rule_parser_engine_url_option_compat_test.dart test/source_import_export_service_test.dart`
- 命令：`flutter analyze lib/features/source/views/source_edit_view.dart lib/features/source/services/rule_parser_engine.dart lib/core/services/source_login_store.dart`
- 手工：
  - 在书源编辑页“网络/登录”填写“登录头缓存(JSON)”并保存；
  - 再次进入该书源编辑页点击“加载登录态缓存”，确认回显；
  - 执行书源调试，检查请求头摘要中可看到登录头生效（若未被 URL option 覆盖）。

### 兼容影响
- 行为增强：请求会自动并入该书源的登录头缓存（与 legado 登录头语义一致）。
- 未完成项：`loginUrl/loginCheckJs` 执行链仍在后续 P0 Todo。

## 2026-02-10（阅读器 UI/UX 对标截图：菜单/目录/缓存/常亮）

### 已完成
- 阅读页底部菜单语义对齐：
  - 修复亮度区“跟随系统/常亮”错绑问题，新增“常亮”开关直连 `ReadingSettings.keepScreenOn`；
  - “更多”入口改为打开完整阅读设置（避免把“更多”误导到翻页页签）。
- 快捷阅读设置面板对齐：
  - Tab 文案对齐为 `字体 / 界面 / 设置 / 更多`（将原“翻页”更名为“设置”）；
  - “更多”页签补齐 `屏幕常亮 / 繁体显示` 等常用开关。
- 目录/书签/笔记面板重构并补齐动作：
  - 抽离为独立组件 `lib/features/reader/widgets/reader_catalog_sheet.dart`，对齐暖色目录抽屉样式；
  - 支持目录搜索/倒序、显示“已缓存”章节标记；
  - 支持书签列表与右滑删除；
  - 接入“清理本书缓存”和“刷新目录（检查更新）”两个工具按钮：
    - 清缓存：清除本书章节缓存内容但保留目录；
    - 刷新目录：基于“当前书源搜索 -> 目录抓取 -> 仅追加（append）新章节”的安全策略更新目录，避免重排导致书签错位。
- 平台能力补齐：新增 `KeepScreenOnService` + iOS/Android MethodChannel（阅读时可真正常亮）。

### 为什么
- 你提供的截图核心是“阅读态高频动作前置 + 目录抽屉可操作 + 设置分层清晰”，现有实现存在：
  - 亮度区开关文案与实际行为不一致；
  - 目录抽屉有 UI 但关键动作为空；
  - “常亮”只是配置项，缺少平台落地。
- 本次以“最小可用闭环”为目标：保证用户从阅读页能完成目录/书签/清缓存/检查更新/常亮等高频操作。

### 验证方式
- 命令：`flutter analyze`
- 命令：`flutter test`
- 手工：
  - 阅读页唤出菜单 → 底部亮度区切换“跟随系统/常亮”，确认亮度与常亮行为符合预期；
  - 打开目录抽屉 → 搜索章节/倒序 → 点击跳转章节；
  - 在书签页右滑删除书签；
  - 点击“清理缓存”，确认缓存标记消失且阅读不中断；
  - 点击“刷新目录”，当目录存在追加章节时提示“新增 X 章”。

### 兼容影响
- 规则协议无变更：未修改 legado 书源字段与解析语义。
- 行为增强：新增“常亮”平台落地、目录抽屉动作补齐与目录安全追加更新策略；对旧书源兼容性预期为正向增强。

## 2026-02-10（阅读器视觉统一：Design Tokens + 三主轴主题）

### 已完成
- 新增统一视觉令牌文件 `lib/app/theme/design_tokens.dart`：
  - 全局品牌/语义色（主品牌蓝、CTA 绿、成功/警告/错误/信息）；
  - 中性色（文本、边框、分割线、浅/深表面）；
  - 统一圆角（控件/卡片/弹层）与动效时长（150/220/300ms）；
  - 阅读主题令牌（`ReaderThemeTokens`）及“日间/护眼/夜间”三主轴。
- `lib/app/theme/colors.dart` 接入统一令牌，阅读主题改由 `ReaderThemeTokens` 映射，保持现有 9 个主题顺序不变（避免 `themeIndex` 历史数据错位）。
- `lib/app/theme/app_theme.dart` 对齐视觉一致性：
  - 统一卡片/按钮/输入框圆角为 token；
  - 修正按钮 `onPrimary` 对比度（深色主题改白字）；
  - 统一按钮前景色语义，提升可读性与一致性。
- `lib/features/reader/views/reader_view.dart` 增加主题索引边界保护，避免历史异常配置导致索引越界。

### 为什么
- 当前阅读器已有多主题能力，但视觉语义分散在各文件中，长期会造成“同一产品多套视觉语言并存”的漂移风险。
- 本次目标是先建立“可复用且可约束”的令牌层，再把现有主题映射到统一主轴，实现“整体协调”且不破坏现有用户习惯。

### 验证方式
- 命令：`dart format lib/app/theme/design_tokens.dart lib/app/theme/colors.dart lib/app/theme/app_theme.dart lib/features/reader/views/reader_view.dart`
- 命令：`flutter analyze --no-pub`
- 命令：`flutter test test/rule_parser_engine_css_nth_compat_test.dart`
- 手工：阅读页切换各主题，确认主题可用且 `themeIndex` 历史配置不出现错位或崩溃。

### 兼容影响
- 规则协议无变更：本次仅涉及阅读器 UI 主题层，不触及书源解析语义。
- 行为兼容：保留原 9 主题名称与顺序，旧配置可无缝迁移；仅提升配色一致性和可读性。

## 2026-02-10（P2：全页面 UI/UX 统一改造 - 第一批）

### 已完成
- 新增全局 Cupertino 主题文件 `lib/app/theme/cupertino_theme.dart`：
  - 统一应用级 `CupertinoThemeData`（字体、主色、导航栏、Tab 文本）；
  - 补齐底部 Tab 的背景/激活色/未激活色/分隔线统一规则；
  - 明确亮暗模式下同一套语义色映射，避免页面各自定义。
- `lib/main.dart` 接入全局主题：
  - `CupertinoApp.theme` 改为 `AppCupertinoTheme.build(brightness)`；
  - `CupertinoTabBar` 统一使用主题 token（背景、边框、激活态）；
  - 保持原有 5 主 Tab 信息架构不变，仅统一视觉基线。
- 核心高频页首批统一（先覆盖用户每天都用的入口）：
  - `SearchView`：重构为“统一导航 + 顶部搜索面板 + 状态卡片 + 统一结果卡片”样式；
  - `DiscoveryView`：接入统一导航边框、状态卡片与结果卡片视觉语义；
  - `BookshelfView`：接入统一导航边框与页面背景渐变；
  - `SourceListView`：接入统一导航边框与页面背景渐变；
  - `SettingsView`：接入统一导航边框与页面背景渐变。
- 代码稳定性修正：
  - 清理 `SearchView` 中已损坏的重复代码片段并重建页面实现，恢复可维护状态。

### 为什么
- 你明确要求“所有页面都重新设计 UI/UX”，而不是局部修补。
- 若不先建立全局主题与视觉 token，逐页改造会反复返工、难以保证整体协调。
- 因此先做“主题中台 + 高频页首批落地”，再进入第二批全量页面收口，是风险最低、产出最高的路线。

### 验证方式
- 命令：`dart format lib/main.dart lib/app/theme/cupertino_theme.dart lib/features/search/views/search_view.dart lib/features/discovery/views/discovery_view.dart lib/features/bookshelf/views/bookshelf_view.dart lib/features/source/views/source_list_view.dart lib/features/settings/views/settings_view.dart`
- 命令：`flutter analyze --no-pub`
- 命令：`flutter test test/rule_parser_engine_css_nth_compat_test.dart`
- 手工：在五个主 Tab（书架/发现/搜索/书源/设置）切换，确认导航栏、背景层次、卡片边框与状态提示样式一致。

### 兼容影响
- 规则协议无变更：本次仅涉及 UI/UX 展示层，不触及 legado 书源语义解析逻辑。
- 交互兼容：保留原有核心业务入口与功能流程，主要调整视觉组织与信息层级。

## 2026-02-10（P2：全页面 UI/UX 统一改造 - 第二批收口）

### 已完成
- 基于 `ui-ux-pro-max` 技能检索并确认“移动端阅读产品的统一层级与留白优先”方向，继续沿用现有 Cupertino 极简风格做全页面收口。
- 新增并批量接入统一页面容器 `lib/app/widgets/app_cupertino_page_scaffold.dart`，将导航栏边框、背景层次、SafeArea 策略统一下沉到基础壳层。
- 第二批页面完成统一接入（不改业务逻辑，仅替换外层页面壳）：
  - 设置相关：`about/appearance/backup/function/global_reading/other_hub/other/reading_* /source_management/storage/text_rules/theme/settings`。
  - 书源相关：`source_list_view`、`source_edit_view`、`source_web_verify_view`、`source_availability_check_view`、`source_debug_text_view`。
  - 其他业务页：`bookshelf_view`、`reading_history_view`、`search_view`、`discovery_view`、`replace_rule_list_view`、`replace_rule_edit_view`。
- 全量扫描后，`lib/features` 下仅保留 `simple_reader_view` 使用 `CupertinoPageScaffold`（阅读页全屏沉浸态，刻意保留独立壳层）。

### 为什么
- 第一批完成主题中台与主 Tab 统一后，仍存在大量二级页样式分散、视觉节奏不一致问题。
- 本次将“导航 + 背景 + 安全区”抽象为统一壳层，减少后续 UI 维护成本，确保页面间切换的一致体验。

### 验证方式
- 命令：`dart format $(git diff --name-only -- '*.dart')`
- 命令：`flutter analyze --no-pub`
- 命令：`flutter test test/rule_parser_engine_css_nth_compat_test.dart`

### 兼容影响
- 规则协议无变更：不涉及书源字段、规则语义和解析链路。
- 行为兼容：业务流程、入口与数据结构保持不变，仅统一视觉外壳与页面层级。

## 2026-02-10（P2：阅读页沉浸式 UI/UX 协调改造）

### 已完成
- 阅读主视图 `simple_reader_view`：
  - 菜单态增加轻遮罩层（点击空白可关闭菜单），提升“内容层/控制层”层级感与聚焦性；
  - 右侧悬浮快捷栏改为“统一容器 + 一致间距 + 统一激活色反馈”，减少散点控件噪声。
- 顶部菜单 `reader_menus.dart`：
  - 小屏宽度下自动进入紧凑模式（隐藏“换源”芯片，保留高频动作）；
  - 顶栏图标/芯片边框与底色对比度微调，提升可读性与触控识别。
- 底部菜单 `reader_bottom_menu.dart`：
  - 接入 `AppDesignTokens`，按阅读主题明暗自动映射强调色（亮色主品牌、暗色品牌副色）；
  - 统一底部面板、卡片、标签、按钮、滑杆的明暗模式色彩语义；
  - 保持原有功能结构不变（章节进度、亮度字体、翻页与其他、底部四入口），仅做视觉重构。

### 为什么
- 你要求“所有页面重新设计且保持整体协调”，阅读页是高频核心场景，若仍保留旧视觉权重分配会造成全局风格断层。
- 本次采用“只改展示层，不动阅读业务链路”的策略，保证体验升级同时降低功能回归风险。

### 验证方式
- 命令：`dart format lib/features/reader/views/simple_reader_view.dart lib/features/reader/widgets/reader_bottom_menu.dart lib/features/reader/widgets/reader_menus.dart`
- 命令：`flutter analyze --no-pub`
- 命令：`flutter test test/rule_parser_engine_css_nth_compat_test.dart`

### 兼容影响
- 规则协议无变更：不涉及书源字段与 legado 规则语义。
- 行为兼容：阅读功能入口与交互路径保持一致，仅优化视觉层级、状态反馈与多主题协调性。
