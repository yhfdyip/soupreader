# SoupReader 书源能力对标矩阵（Legado 基线）

> 更新时间：2026-02-09  
> 目标：梳理“阅读器书源相关能力”与 `legado` 的对齐情况，给出可执行整改 Todo。  
> 范围：书源协议字段、规则解析、URL/请求链路、五段流程（搜索/发现/详情/目录/正文）、调试能力。  
> 说明：UI/UX 对标（含截图、`flutter_novel`）不在本矩阵主范围，本矩阵只聚焦“书源协议与解析能力”。

## 0. 判定标准

- ✅ 已对齐：核心语义与运行链路已具备，可用于主流程。
- 🟡 部分对齐：字段存在或局部实现，但执行链路不完整/存在兼容风险。
- ⬜ 未对齐：Legado 有明确能力，SoupReader 当前缺少执行实现。

## 1. 对标基线（Legado）

- `legado/app/src/main/java/io/legado/app/data/entities/BookSource.kt`
- `legado/app/src/main/java/io/legado/app/data/entities/BaseSource.kt`
- `legado/app/src/main/java/io/legado/app/data/entities/rule/*.kt`
- `legado/app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeRule.kt`
- `legado/app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeUrl.kt`
- `legado/app/src/main/java/io/legado/app/model/analyzeRule/RuleAnalyzer.kt`

## 2. 协议字段与存储层

| 模块 | Legado 要求 | SoupReader 对应实现 | 状态 | 结论 |
|---|---|---|---|---|
| `BookSource` 顶层字段 | 字段名与语义兼容（`searchUrl`、`exploreUrl`、`rule*` 等） | `lib/features/source/models/book_source.dart` | ✅ | 字段覆盖度高，名称基本一致。 |
| 子规则结构 | `SearchRule/ExploreRule/BookInfoRule/TocRule/ContentRule/ReviewRule` | `book_source.dart` 内各 Rule 类 | ✅ | 结构层已建模，含 `ruleReview`、`imageDecode`、`payAction` 等字段。 |
| 非 null 导出风格 | Legado/Gson 默认不输出 null | `lib/core/utils/legado_json.dart` + 导出逻辑 | ✅ | 具备 `LegadoJson` 归一能力。 |
| 未知字段保真 | 导入编辑导出尽量不丢未知字段 | 编辑器 rawJson 路径：`SourceRepository.upsertSourceRawJson` | 🟡 | 编辑器路径可保真；列表导入/导出仍走 `BookSource` 对象，可能丢未知字段。 |
| 旧存储回填 | 旧数据迁移应尽量保持原语义 | `lib/core/database/repositories/source_repository.dart` | 🟡 | fallback 存在硬编码默认值（如 `enabledCookieJar: true`、`ruleReview: null`），有语义漂移风险。 |

## 3. 规则解析语义层

| 模块 | Legado 要求 | SoupReader 对应实现 | 状态 | 结论 |
|---|---|---|---|---|
| 顶层平衡切分 | `&& / || / %%` 在引号/括号/表达式中不误切 | `_splitRuleByTopLevelOperator` in `rule_parser_engine.dart` | ✅ | 已做平衡切分。 |
| `&& / ||` 规则链 | 串联与兜底语义一致 | `_parseRule` / `_parseValueOnNode` | ✅ | 语义基本一致。 |
| `%%` 交织合并 | 列表结果按索引交织 | `_mergeRuleListResults` | ✅ | 已支持，作用于列表解析链。 |
| CSS/XPath/JsonPath/Regex | 自动识别并按模式解析 | `_looksLikeXPath/_looksLikeJsonPath/_looksLikeRegexRule` + 对应解析器 | ✅ | 主流规则模式覆盖。 |
| `@put` | 可在规则中写入变量 | `_extractPutRules` + `_applyPutRules` | ✅ | 已支持。 |
| `@get` | 运行时变量读取 | `_replaceGetTokens` | ✅ | 已支持。 |
| `{{js}}` / 模板表达式 | 支持模板内 JS/变量求值 | `_applyTemplateJsTokens` | ✅ | 已支持并注入 `vars/baseUrl`。 |
| `replaceRegex` 链 | 支持 `##` 链式替换 | `_applyReplaceRegex` | ✅ | 已支持并做异常兜底。 |
| `ruleToc.preUpdateJs` | 目录页预处理 JS | `getToc/getTocDebug` 内 `_applyStageResponseJs` | ✅ | 已支持。 |
| `ruleContent.webJs` | 正文页预处理 JS | `getContent/getContentDebug` 内 `_applyStageResponseJs` | ✅ | 已支持。 |
| `nextTocUrl` | 目录多页抓取 | `getToc/getTocDebug` + next 候选队列 | ✅ | 已支持多候选去重与循环保护。 |
| `nextContentUrl` | 正文分页抓取 | `getContent/getContentDebug` + next 候选队列 | ✅ | 已支持多候选与“下一章阻断”。 |
| `ruleReview` 段评规则 | 段评抓取与动作链 | 仅模型字段存在，解析链无实现 | ⬜ | 目前未实现段评执行链。 |
| `sourceRegex/imageStyle/imageDecode/payAction` | 正文字段扩展语义 | 仅模型字段存在，解析链无消费 | ⬜ | 正文扩展能力未落地。 |
| `coverDecodeJs` | 封面解码脚本 | 仅字段/编辑输入 | ⬜ | 未接入封面获取链路。 |

## 4. URL 与请求执行链

| 模块 | Legado 要求 | SoupReader 对应实现 | 状态 | 结论 |
|---|---|---|---|---|
| URL 构建基础 | 相对路径转绝对、参数替换 | `_buildUrl` + `_absoluteUrl` | ✅ | 基础可用。 |
| `@js:` / `<js>` URL 片段 | 支持脚本动态构建 URL | `_applyUrlJsSegments` | ✅ | 已支持。 |
| URL option 基础字段 | `method/body/charset/retry/headers/origin/js` | `_LegadoUrlOption` + `_parseLegadoStyleUrl` + `_normalizeRequestPlan` | ✅ | 主流字段可用。 |
| header 多格式兼容 | JSON/双重转义/多行 `k:v`/`@js` `<js>` | `_parseRequestHeaders` | ✅ | 兼容性较好。 |
| URL option JS 改写请求 | `java.url`、`java.headerMap.put/putAll` | `_applyLegadoUrlOptionJs` | ✅ | 已支持并含 fallback。 |
| CookieJar 持久化 | 按源会话复用 | `CookieStore` + `RuleParserEngine._dioCookie` | ✅ | 非 Web 为持久化；Web 为内存态。 |
| 并发率 `concurrentRate` | 按规则限流/并发控制 | 字段存在，未见请求调度实现 | 🟡 | 语义未完整落地。 |
| 登录执行链 | `BaseSource.login/getLoginJs/getLoginHeaderMap/getLoginInfo` | 已接入登录头/登录信息持久化与请求自动带入；脚本登录未落地 | 🟡 | 登录态缓存能力已补齐，仍缺 `loginUrl/loginCheckJs` 执行闭环。 |
| URL option 扩展字段 | `type/webView/webJs/serverID/webViewDelayTime` | `_LegadoUrlOption` 未覆盖这些字段 | ⬜ | 媒体/浏览器态扩展未对齐。 |
| 上传接口 | `AnalyzeUrl.upload(fileRequest)` | 未见等效 API | ⬜ | 上传场景未实现。 |

## 5. 五段链路能力（书源主流程）

| 链路 | SoupReader 实现入口 | 状态 | 说明 |
|---|---|---|---|
| 搜索 `search` | `RuleParserEngine.search/searchDebug` | ✅ | HTML/JSON 双模式、失败可诊断。 |
| 发现 `explore` | `RuleParserEngine.explore/exploreDebug` | ✅ | 支持 `exploreUrl + ruleExplore`。 |
| 详情 `bookInfo` | `RuleParserEngine.getBookInfo/getBookInfoDebug` | ✅ | 支持 `tocUrl` 回退（详情页即目录）。 |
| 目录 `toc` | `RuleParserEngine.getToc/getTocDebug` | ✅ | 支持 `preUpdateJs`、`nextTocUrl`、`formatJs`。 |
| 正文 `content` | `RuleParserEngine.getContent/getContentDebug` | ✅ | 支持 `webJs`、`nextContentUrl`、`replaceRegex`。 |

## 6. 调试/可观测与编辑器

| 模块 | SoupReader 对应实现 | 状态 | 说明 |
|---|---|---|---|
| 调试日志流 | `RuleParserEngine.debugRun` + `SourceEditView` 调试页 | ✅ | 已覆盖搜索/发现/详情/目录/正文。 |
| 请求诊断 | `_fetchDebug`（method/retry/charset/body/header/response） | ✅ | 诊断维度较完整。 |
| 变量快照 | `debugRuntimeVariablesSnapshot` + 调试摘要/导出 | ✅ | 支持脱敏快照。 |
| 调试包导出 | `SourceEditView` 生成 summary/debug bundle | ✅ | 可复现场景信息较完整。 |
| 规则编辑器覆盖度 | `SourceEditView` | 🟡 | 覆盖核心字段，但缺 `ruleReview`、`content.imageDecode/payAction/sourceRegex/imageStyle` 等专用编辑入口。 |

## 6.1 书源界面使用逻辑（对标 legado）

| 模块 | Legado 体验基线 | SoupReader 现状 | 状态 | 说明 |
|---|---|---|---|---|
| 书源管理主列表 | 分组筛选、启用开关、快捷操作统一 | 已有分组/状态筛选与启用开关 | ✅ | 核心管理入口可用。 |
| 导入流程交互 | 文件/剪贴板/网络导入 + 冲突处理 + 可解释错误 | 已支持三入口与冲突弹窗 | 🟡 | 交互接近，但细节文案/步骤还未完全按 legado 交互复刻。 |
| 导入保真 | 导入后规则字段尽量不丢失 | 已补 rawJson 优先入库链路 | 🟡 | 导入保真已增强，导出链路仍需继续对齐。 |
| 调试流程 | 一键调试五段链路、错误可定位 | 已有调试日志流与调试包导出 | 🟡 | 能力齐全，但调试入口组织与 legado 仍有差异。 |
| 编辑器覆盖度 | 关键字段可视化编辑 + JSON 保真 | 已有结构化编辑 + JSON 编辑 | 🟡 | 缺 `ruleReview` 与正文扩展字段结构化入口。 |

## 7. 当前“完全对标 legado”阻塞项（P0）

1. 登录语义链未完整落地（已支持登录头/信息缓存与请求带入，仍缺 `loginUrl` 脚本执行与登录检测）。
2. 段评 `ruleReview` 无执行链。
3. 正文扩展字段（`sourceRegex/imageDecode/payAction/imageStyle`）无执行链。
4. `coverDecodeJs` 无接入封面获取流程。
5. 导入/导出与批量入库路径对未知字段保真不完整（非 rawJson 路径可能丢字段）。

## 8. 可执行 Todo（按优先级）

### P0（必须，完成后才可宣称“书源能力对标 legado”）

- [ ] P0-1 登录链路对齐：实现 `loginUrl`（`@js`/`<js>`）执行与登录态缓存（header/info）读写接口。
- [ ] P0-2 段评链路落地：新增 `ruleReview` 解析 API（至少支持 `reviewUrl/avatarRule/contentRule/postTimeRule` 读取）。
- [ ] P0-3 正文扩展能力：在正文抓取链路接入 `sourceRegex/imageDecode/payAction/imageStyle` 语义。
- [ ] P0-4 封面解码能力：在封面获取流程接入 `coverDecodeJs`。
- [ ] P0-5 保真导入导出：列表导入/导出与仓库存储优先走 rawJson，保证未知字段不丢失。
- [ ] P0-6 回归样本：为以上能力补最小复现测试（优先解析引擎测试 + 导入导出兼容测试）。
- [ ] P0-7 书源页面流程对齐：导入/调试/编辑入口与 legado 操作路径逐项对齐。

### P1（重要，提升复杂源兼容）

- [ ] P1-1 URL option 扩展字段对齐：`type/webView/webJs/serverID/webViewDelayTime`。
- [ ] P1-2 上传能力：补等价 `upload(fileRequest)` 请求路径。
- [ ] P1-3 并发率语义：将 `concurrentRate` 接入请求调度与节流策略。
- [ ] P1-4 编辑器补栏位：补齐 `ruleReview` 与正文扩展字段的结构化编辑入口。

### P2（体系化与验收）

- [ ] P2-1 建立 legado 对照样本集（20+ 典型源）并统计通过率。
- [ ] P2-2 建立 dbss 对照回归（五段链路一致性 + 错误分类）。
- [ ] P2-3 输出长期维护基线：新增字段/语义必须先更新本矩阵再开发。

## 9. 验收口径（声明“完全对标 legado”前必须满足）

- 功能层：P0 全部完成并具备自动化回归。
- 语义层：同源同规则下，解析结果与 legado 无协议级偏差。
- 诊断层：失败可归类为请求/规则/编码/分页/登录，并可导出最小复现信息。
- 保真层：导入→编辑→导出循环后，未知字段与已知字段不应被无意丢弃。
