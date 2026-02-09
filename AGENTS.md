# SoupReader 协作规范（AGENTS）

> 适用范围：`/home/server/soupreader` 全项目。

## 1) 总原则（强约束）

- 所有回复、说明、代码评审意见默认使用中文。
- **书源处理规则语义以同级项目 `legado` 为第一标准**（兼容优先于“自创规则”）。
- **功能落地与可用性以同级项目 `dbss` 的 `source_analyzer` 能力为优先目标**，`legado` 的功能体验作为参考补齐。
- 发生冲突时按以下顺序决策：
  1. 不破坏 legado 规则语义兼容；
  2. 确保 dbss 对应功能链路能跑通；
  3. 保持 SoupReader 现有架构与代码风格。

---

## 2) 参考基线（改动前先对齐）

### 2.1 legado（规则语义基线，最高优先级）

- `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeRule.kt`
- `app/src/main/java/io/legado/app/model/analyzeRule/RuleAnalyzer.kt`
- `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeUrl.kt`
- `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeByJSoup.kt`
- `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeByXPath.kt`
- `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeByJSonPath.kt`
- `app/src/main/java/io/legado/app/data/entities/BookSource.kt`
- `app/src/main/java/io/legado/app/data/entities/BaseSource.kt`
- `app/src/main/java/io/legado/app/data/entities/rule/*.kt`

### 2.2 dbss（功能落地目标）

- `asm/source_analyzer/src/source_analyze.dart`
- `asm/source_analyzer/src/analyze_url.dart`
- `asm/source_analyzer/src/analyze_rule.dart`
- `asm/source_analyzer/src/rule_analyzer.dart`
- `asm/source_analyzer/src/analyze_by_jsoup.dart`
- `asm/source_analyzer/src/analyze_by_xpath.dart`
- `asm/source_analyzer/src/analyze_by_jsonpath.dart`
- `asm/source_analyzer/src/analyze_by_regex.dart`
- `asm/source_analyzer/src/models/source.dart`
- `asm/source_analyzer/src/models/book.dart`
- `asm/source_analyzer/src/models/chapter.dart`
- `asm/source_analyzer/src/models/str_response.dart`

### 2.3 本项目锚点文件

- `lib/features/source/services/rule_parser_engine.dart`
- `lib/features/source/models/book_source.dart`
- `lib/features/source/views/source_edit_view.dart`
- `lib/features/source/services/source_import_export_service.dart`
- `lib/core/services/cookie_store.dart`
- `lib/core/utils/legado_json.dart`

---

## 3) 书源规则兼容要求（按 legado 语义实现）

### 3.1 字段与序列化

- `BookSource` 及子规则字段名必须与 legado 保持一致（例如 `searchUrl`、`exploreUrl`、`ruleSearch`、`ruleToc` 等）。
- 导入时兼容：对象 / 字符串化 JSON / 宽松 Map。
- 导出默认采用 legado/Gson 风格：**不输出 null 字段**（依赖 `LegadoJson` 处理）。

### 3.2 规则链语义

- 禁止直接 `split('&&')`、`split('||')` 处理复杂规则。
- 必须遵守平衡分割语义（括号、方括号、引号、代码块内不误切）：
  - `&&`：串联获取（合并结果）；
  - `||`：备选兜底（命中即停）；
  - `%%`：按索引交织合并。

### 3.3 规则模式识别

- 必须支持并维持 legado 常见模式：
  - CSS（含 `@CSS:` / `@@` 兼容写法）；
  - XPath（`@XPath:` 或 `/` 开头）；
  - JsonPath（`@Json:` 或 `$.` / `$[`）；
  - Regex（含 `##match##replace` 链）。
- 保持规则内嵌能力：`@put:{...}`、`@get:{...}`、`{{js}}`、`{$.rule}` 等。

### 3.4 URL/请求规则

- URL 规则需兼容 legado 常见能力：
  - `@js:`、`<js>...</js>`；
  - URL 选项 JSON（method/body/headers/charset/retry 等）；
  - 相对路径转绝对 URL；
  - `nextTocUrl`/`nextContentUrl` 多候选解析。
- `header` 解析需兼容：
  - 标准 JSON；
  - 双重转义 JSON；
  - 多行 `key:value`；
  - `@js:` / `<js>` 动态生成。

---

## 4) 功能落地要求（按 dbss 目标推进）

### 4.1 网络与会话

- 保持持久化 CookieJar（应用重启后可复用会话）。
- 维持请求/响应编码处理（含 GBK 等站点常见编码回退）。
- 请求层异常必须可观测（状态码、关键响应头、错误摘要）。

### 4.2 五段链路必须可调试

- 搜索（search）
- 发现（explore）
- 详情（bookInfo）
- 目录（toc）
- 正文（content）

任何影响上述链路的改动，必须同步维护调试输出与回归验证。

### 4.3 调试产物

- 继续维护“日志流 + 源码快照 + 导出调试包(zip/json)”能力。
- 新增解析能力时，要补充对应调试日志关键节点（请求、解析、结果、失败原因）。

---

## 5) 开发约束（必须遵守）

- 只做与当前需求直接相关的最小改动，避免无关重构。
- 规则兼容改动优先补在解析引擎，不要把兼容逻辑分散到 UI 层。
- 书源 JSON 的未知字段应尽量保留，不要在编辑流程里无意删除。
- 对用户可见行为的变更必须写明兼容影响。

---

## 6) 测试与验收（提交前检查）

- 修改书源解析相关代码后，至少执行：
  - `flutter test test/rule_parser_engine_css_nth_compat_test.dart`
- 若改动涉及 HTML 归一化/正文清洗，再执行：
  - `flutter test test/html_text_formatter_test.dart`
- 若改动涉及导入导出 JSON 兼容，再执行：
  - `flutter test test/legado_json_test.dart`
- 新增规则能力时：
  - 优先补“最小可复现”单测；
  - 不能只靠手工点点点验证。

---

## 7) 迭代优先级建议

1. 先保证规则语义兼容（legado）不回退。
2. 再补足 dbss 对应功能链路可用性。
3. 最后做 UI/交互与性能优化。

如果时间不足：宁可保兼容、保稳定，也不要引入“看起来更先进但不兼容旧书源”的实现。

---

## 8) 开发进度更新（必须）

- 每次完成一个可交付点（修复/新增/调整）后，**必须**同步更新：
  - `docs/DEV_PROGRESS.md`
- 更新内容至少包含：
  - 做了什么（变更点）
  - 为什么（问题/需求）
  - 如何验证（测试命令或手工路径）
- 若改动可能影响旧书源兼容性，必须在进度记录中写清“兼容影响”。

---

## 9) 任务执行与沟通流程（必须）

- 接到需求后，先拆分为可执行的 Todo 列表。
- 从第 1 项开始连续执行，直到所有 Todo 完成。
- 执行过程中，不要在每完成一项后询问“是否继续”。
- 仅在以下场景可以暂停并询问：
  1. 缺少必要信息，导致无法继续；
  2. 存在明显风险或破坏性操作（如删除、覆盖、付费、生产环境操作等）。
- 全部完成后，回复必须包含：
  - 完成情况汇总
  - 变更文件列表
  - 如何验证
