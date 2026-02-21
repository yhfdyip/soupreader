# 目录链路对照清单（T10 / C4）

- 任务状态：`done`
- 对应计划：`PLANS.md` / `T10`
- 产出日期：`2026-02-20`
- 对照基准：
  - `../legado/app/src/main/res/menu/book_toc.xml`
  - `../legado/app/src/main/java/io/legado/app/ui/book/toc/TocActivity.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/toc/TocViewModel.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/toc/ChapterListFragment.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/toc/ChapterListAdapter.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/toc/BookmarkFragment.kt`

## 1. 差异点清单（实现前 -> 本次收敛）

| 差异ID | legacy 行为 | soupreader 原状态 | 本次处理 | 影响 |
|---|---|---|---|---|
| TC-001 | `book_toc.xml` 中目录页菜单顺序为 `TXT组 -> TOC组 -> 日志` | 本地 TXT 下顺序为 `TOC组 -> TXT组 -> 日志` | 调整 `buildTocMenuActions` 顺序，先输出 `tocRule/splitLongChapter` 再输出 `reverse/useReplace/loadWordCount` | 目录操作层级与 legado 菜单分组同义 |
| TC-002 | `menu_split_long_chapter` 切换后会走“保存配置 -> 重载目录/正文 -> 反馈结果” | 仅切换本地布尔值并提示，不保存配置、不触发重载 | 新增异步应用回调 `onApplySplitLongChapter`，切换时进入忙碌态，成功后回写状态，失败给出可观测错误 | `分割长章节` 状态流转/边界反馈贴齐 legado |
| TC-003 | `TocActivity` 打开菜单时以持久化值回填勾选态 | 阅读器内 `initialSplitLongChapter` 默认 `false`，未读取设置 | 阅读器初始化时读取 `SettingsService.getBookSplitLongChapter(..., fallback: true)` 并传给目录面板 | 目录菜单初始开关态与书籍配置一致 |

## 2. 逐项检查清单（入口/状态/异常/文案/排版/触发）

### 2.1 目录页菜单（章节 Tab）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：章节 Tab 菜单包含 `TXT 目录规则/分割长章节/倒序/使用替换规则/加载字数/日志` | `../legado/app/src/main/res/menu/book_toc.xml:14`, `lib/features/reader/services/reader_legacy_menu_helper.dart:141` |
| 状态 | 已同义：`倒序/使用替换规则/加载字数/分割长章节` 提供勾选态显示 | `../legado/app/src/main/java/io/legado/app/ui/book/toc/TocActivity.kt:108`, `lib/features/reader/widgets/reader_catalog_sheet.dart:692` |
| 异常 | 已同义：分割长章节应用失败时显示可观测错误提示 | `lib/features/reader/widgets/reader_catalog_sheet.dart:746` |
| 文案 | 已同义：菜单核心文案与 legacy 对应关系一致 | `../legado/app/src/main/res/menu/book_toc.xml:23`, `lib/features/reader/services/reader_legacy_menu_helper.dart:151` |
| 排版 | 已同义：动作入口统一在目录面板右上“更多”ActionSheet 中承载，分组顺序与 legacy 菜单分组同义 | `lib/features/reader/widgets/reader_catalog_sheet.dart:662`, `lib/features/reader/services/reader_legacy_menu_helper.dart:130` |
| 交互触发 | 已同义：每个菜单项均绑定显式 handler，未出现无响应项 | `lib/features/reader/widgets/reader_catalog_sheet.dart:704` |
| 输入 | 不涉及（本批次目录菜单无表单输入） | - |
| 交互逻辑 | 已同义：`分割长章节` 切换遵循“应用 -> 成功回写/失败提示 -> 退出忙碌态” | `lib/features/reader/widgets/reader_catalog_sheet.dart:731`, `lib/features/reader/views/simple_reader_view.dart:8794` |

### 2.2 书签页菜单（书签 Tab）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：书签 Tab 菜单保留 `导出书签/导出 Markdown/日志` | `../legado/app/src/main/res/menu/book_toc.xml:54`, `lib/features/reader/services/reader_legacy_menu_helper.dart:134` |
| 状态 | 已同义：切到书签 Tab 后只展示书签组动作，不混入 TOC/TXT 组动作 | `../legado/app/src/main/java/io/legado/app/ui/book/toc/TocActivity.kt:99`, `lib/features/reader/services/reader_legacy_menu_helper.dart:134` |
| 异常 | 已同义：导出能力缺失时有显式提示，不静默失败 | `lib/features/reader/widgets/reader_catalog_sheet.dart:756`, `lib/features/reader/widgets/reader_catalog_sheet.dart:763` |
| 文案 | 已同义：导出动作与日志文案保持业务语义一致 | `lib/features/reader/services/reader_legacy_menu_helper.dart:163` |
| 排版 | 已同义：与章节 Tab 共用 ActionSheet 容器，按 Tab 状态切换动作集合 | `lib/features/reader/widgets/reader_catalog_sheet.dart:662` |
| 交互触发 | 已同义：导出 JSON / Markdown、日志动作均具备独立回调 | `lib/features/reader/widgets/reader_catalog_sheet.dart:756`, `lib/features/reader/widgets/reader_catalog_sheet.dart:770` |
| 输入 | 不涉及 | - |
| 交互逻辑 | 已同义：书签导出动作按能力探测走“执行/不可用提示”分支 | `lib/features/reader/widgets/reader_catalog_sheet.dart:757`, `lib/features/reader/widgets/reader_catalog_sheet.dart:764` |

## 3. 回归路径 C4（目录）

- 路径：阅读器 -> 打开目录面板 -> 章节 Tab/书签 Tab -> 右上菜单。
- 手工核验点：
  - 本地 TXT 书籍菜单顺序为：`TXT 目录规则 -> 分割长章节 -> 倒序 -> 使用替换规则 -> 加载字数 -> 日志`。
  - `分割长章节` 切换时会进入处理状态；成功后展示开关反馈，失败显示错误原因。
  - 切到书签 Tab 后菜单仅保留 `导出书签/导出 Markdown/日志`。

## 4. 命令验证证据

```bash
flutter test test/reader_legacy_menu_helper_test.dart
flutter test test/reader_catalog_sheet_test.dart
flutter test test/simple_reader_view_compile_test.dart
```

- 结果：通过。
- 说明：按仓库规则，本阶段未执行 `flutter analyze`（保留到 T18 提交前一次执行）。

## 5. 保留差异与后续

- 保留差异 1：legacy 的 `reverseToc` 会持久化反转目录并回传阅读结果；当前实现仍是目录面板内的视图级倒序，不改数据库章节顺序。
- 保留差异 2：legacy `load_word_count` 使用目录源字段 `wordCount`；当前章节模型未持久化该字段，仅保留开关语义与入口。
- 回补计划：在 `T11`（正文链路）与后续 `T16A` 全局交互复核阶段，补齐 `reverseToc` 持久化与目录字数展示的数据链路可行性评估。
