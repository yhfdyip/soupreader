# 占位交互规范（T05）

- 任务状态：`done`
- 对应计划：`PLANS.md` / T05
- 产出日期：`2026-02-20`
- 目标：在“核心优先、扩展冻结”约束下，统一 `legacy -> soupreader` 占位入口的触发反馈、文案语义、状态流转与可观测输出。

## 1. 适用范围

- 适用入口：菜单项、ActionSheet 项、设置列表项、占位页面入口。
- 本规范覆盖：`showNotImplemented` 弹窗、阅读器/书架占位提示、RSS 占位页。
- 不覆盖：真实业务实现（网络/解析/存储），仅约束占位交互壳语义。

## 2. 统一交互类型

### A. 扩展冻结占位（默认）

- 触发条件：扩展任务未解锁（遵循“未收到开始扩展功能指令前保持 blocked”）。
- 交互形式：`CupertinoAlertDialog`。
- 标题：`扩展阶段`。
- 文案规则：`<功能名>将在扩展阶段实现`（由 `SettingsUiTokens.normalizePlannedText` 归一）。
- 动作：仅 `好`，点击后关闭对话框。
- 可观测性：进入该分支时应输出 `debugPrint('[placeholder][extension] ...')`（后续实现项）。

### B. 核心迁移缺口占位（临时）

- 触发条件：该入口属于核心链路但实现仍缺失；映射台账中表现为 `mapped_placeholder`。
- 交互形式：
  - 优先 `CupertinoAlertDialog`（明确“未完成 + 将补齐”）；
  - 次选轻提示（如 `_showToast`），仅用于阅读器内不打断流程动作。
- 文案规则：`<动作名>暂未实现，已保留与 legado 同层入口` 或 `TODO:<动作名>`。
- 动作：确认后立即返回当前上下文，不产生额外状态副作用。
- 可观测性：必须可追踪到触发点（日志或统一 helper）。

### C. 占位承载页（整页）

- 触发条件：入口链路已迁移，但目标页能力后置（例如 RSS 文章列表/阅读页）。
- 交互形式：页面内占位卡片 + 状态说明。
- 文案规则：
  - 标题显示“扩展阶段/核心入口已迁移”；
  - 明确已完成能力与待补能力。
- 可观测性：页面标题、来源参数、blocked 原因可见。

## 3. 逐项检查模板（占位入口必须逐条满足）

1. 入口：与 legado 同层级可达，位置和顺序语义一致。
2. 状态：默认可点击；触发后必有反馈（弹窗/轻提示/页面跳转）。
3. 异常：上下文失效（`!mounted`）时安全返回，不抛未处理异常。
4. 文案：必须说明“未实现/扩展阶段/回补计划”，禁止无语义提示。
5. 排版：对话框/卡片遵循 Cupertino + 分组背景，不出现 Material 风格主实现。
6. 交互触发：点击后可关闭、可返回，且无残留遮罩。
7. 输入（如有）：占位输入框必须具备取消与确认路径。
8. 交互逻辑：触发 -> 反馈 -> 关闭三段完整，禁止“点击无响应”。

## 4. 文案与状态机规范

- 标题保留字：`扩展阶段`、`提示`。
- 说明文案必须包含一个动作动词（例如：分享、朗读、导入、同步）。
- 状态机（占位入口）：
  - `idle` -> `triggered` -> `feedback_visible` -> `dismissed` -> `idle`
- 禁止状态：
  - `triggered` 后无 UI 反馈；
  - `dismissed` 后仍残留遮罩/弹层。

## 5. 5 模块抽检记录

| 模块 | 文件 | 入口样例 | 当前实现 | 结论 |
|---|---|---|---|---|
| settings | `lib/features/settings/views/settings_placeholders.dart` | `showNotImplemented()` | `CupertinoAlertDialog` + `扩展阶段` + `好` | 符合 A 类 |
| bookshelf | `lib/features/bookshelf/views/bookshelf_view.dart` | `_showPendingAction('远程导入')` | 统一提示“暂未实现，已保留与 legado 同层入口” | 符合 B 类 |
| reader | `lib/features/reader/views/simple_reader_view.dart` | `ClickAction.editContent/syncBookProgress` | `_showToast('...暂未实现')`，可关闭 | 符合 B 类（轻提示） |
| rss | `lib/features/rss/views/rss_articles_placeholder_view.dart` | `RssArticlesPlaceholderView` | 整页占位卡片，明确“扩展阶段/blocked” | 符合 C 类 |
| source | `lib/features/source/views/source_list_view.dart` | `_showToastMessage(...)` | 已有统一轻提示通道，可作为 B 类落点 | 可复用，需补 placeholder 日志规范 |

## 6. 与 T04 映射联动规则

- `button-mapping.csv` 中 `mapping_status=mapped_placeholder` 的条目，默认落入 B 类规范。
- 每个 `TODO:<title>` 必须挂载到可达页面（`soup_file/soup_seq` 不为空），并在后续 T06~T14 迁移时逐项替换为真实动作。
- 替换完成后应将映射状态改为 `mapped_exact`/`mapped_exact_context`/`mapped_fuzzy_context` 中之一，不得长期保留 `mapped_placeholder`。

## 7. 后续执行要求

- 在 T06 起的功能迁移中，新增占位入口优先复用统一 helper，避免各页面自定义散落文案。
- 补齐日志规范：`[placeholder][module][action]`（建议在统一 helper 中实现）。
- 对 `mapped_placeholder` 集中模块（如 `book_read.xml`）优先回补，避免核心链路长期占位。
