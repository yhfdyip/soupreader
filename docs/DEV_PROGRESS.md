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
