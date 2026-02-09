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
