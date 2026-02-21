# 搜索链路对照清单（T07 / C1）

- 任务状态：`done`
- 对应计划：`PLANS.md` / `T07`
- 产出日期：`2026-02-21`
- 对照基准：
  - `../legado/app/src/main/res/menu/book_search.xml`
  - `../legado/app/src/main/res/menu/book_search_scope.xml`
  - `../legado/app/src/main/res/menu/search_view.xml`
  - `../legado/app/src/main/res/menu/book_info.xml`
  - `../legado/app/src/main/res/menu/book_info_edit.xml`
  - `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchActivity.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/search/SearchScopeDialog.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/info/BookInfoActivity.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/info/edit/BookInfoEditActivity.kt`

## 1. 差异点清单（实现前 -> 本次收敛）

| 差异ID | legacy 行为 | soupreader 原状态 | 本次处理 | 影响 |
|---|---|---|---|---|
| S-001 | `book_info` 菜单中的“置顶/拷贝链接”入口常驻 | “置顶”仅书架内可见；“复制链接”按 URL 非空显示 | 已收敛为常驻入口，点击后按当前状态给出同义反馈 | 详情页入口层级与 legacy 更一致 |
| S-002 | 搜索页菜单包含“精准搜索/书源管理/多分组或书源/日志” | 入口已具备，但缺少 C1 逐项对照文档 | 补齐本清单，逐项落证据与回归路径 | 降低后续 T08~T11 迁移遗漏 |
| S-003 | 搜索范围支持“快速切组 + 多分组/单源弹层” | 已实现，但缺少与 legacy 状态流转的逐项核验记录 | 完成入口/状态/异常/文案/排版/触发核验 | 搜索范围状态切换可追踪 |

## 2. 逐项检查清单（入口/状态/异常/文案/排版/触发）

### 2.1 搜索页菜单（`book_search` / `search_view`）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：右上设置菜单包含“精准搜索/书源管理/搜索范围/日志”四入口 | `lib/features/search/views/search_view.dart:900`, `lib/features/search/views/search_view.dart:912`, `lib/features/search/views/search_view.dart:918`, `lib/features/search/views/search_view.dart:924`, `lib/features/search/views/search_view.dart:933` |
| 状态 | 已同义：精准搜索开关状态可见（开/关），并体现在摘要文案 | `lib/features/search/views/search_view.dart:737`, `lib/features/search/views/search_view.dart:988` |
| 异常 | 已同义：搜索范围无启用书源时可观测提示 | `lib/features/search/views/search_view.dart:470` |
| 文案 | 已同义：菜单文案与 legacy 语义一致（精准搜索/书源管理/搜索范围/日志） | `lib/features/search/views/search_view.dart:912`, `lib/features/search/views/search_view.dart:918`, `lib/features/search/views/search_view.dart:924`, `lib/features/search/views/search_view.dart:933` |
| 排版 | 已同义：顶部搜索框 + 右上菜单入口，菜单采用 ActionSheet 组织，层级等价 | `lib/features/search/views/search_view.dart:1139`, `lib/features/search/views/search_view.dart:1192` |
| 交互触发 | 已同义：四入口分别落到对应动作（切精准、书源管理、范围、日志） | `lib/features/search/views/search_view.dart:948`, `lib/features/search/views/search_view.dart:951`, `lib/features/search/views/search_view.dart:954`, `lib/features/search/views/search_view.dart:957` |
| 输入 | 已同义：范围变更后按 legacy 条件触发自动重搜（仅输入帮助层隐藏时） | `lib/features/search/views/search_view.dart:763`, `lib/features/search/views/search_view.dart:1024` |
| 交互逻辑 | 已同义：精准搜索切换后会按当前关键词重搜（有关键词）或仅更新展示（无关键词） | `lib/features/search/views/search_view.dart:988` |

### 2.2 搜索范围弹层（`book_search_scope`）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：范围菜单可进入多分组/单源弹层 | `lib/features/search/views/search_view.dart:772`, `lib/features/search/views/search_view.dart:1001` |
| 状态 | 已同义：支持“分组/书源”双模式切换与单选/多选状态 | `lib/features/search/views/search_scope_picker_view.dart:100`, `lib/features/search/views/search_scope_picker_view.dart:176`, `lib/features/search/views/search_scope_picker_view.dart:227` |
| 异常 | 已同义：无匹配书源与无可选分组均有空态文案 | `lib/features/search/views/search_scope_picker_view.dart:179`, `lib/features/search/views/search_scope_picker_view.dart:231` |
| 文案 | 已同义：保留“全部书源/取消/确定”等 legacy 语义文案 | `lib/features/search/views/search_scope_picker_view.dart:151`, `lib/features/search/views/search_scope_picker_view.dart:159`, `lib/features/search/views/search_scope_picker_view.dart:166` |
| 排版 | 已同义：标题 + 模式切换 + 列表 + 底部操作栏的层级结构等价 | `lib/features/search/views/search_scope_picker_view.dart:95`, `lib/features/search/views/search_scope_picker_view.dart:132`, `lib/features/search/views/search_scope_picker_view.dart:136` |
| 交互触发 | 已同义：确定返回 scope 字符串，供搜索页落盘与重搜策略使用 | `lib/features/search/views/search_scope_picker_view.dart:82`, `lib/features/search/views/search_scope_picker_view.dart:86` |
| 输入 | 已同义：书源模式支持按关键字筛选书源 | `lib/features/search/views/search_scope_picker_view.dart:57`, `lib/features/search/services/search_scope_picker_helper.dart:8` |
| 交互逻辑 | 已同义：范围保存前统一标准化，避免 legacy 中“失效 scope”残留 | `lib/features/search/views/search_view.dart:1002`, `lib/features/search/models/search_scope.dart:35` |

### 2.3 书籍详情更多菜单（`book_info`）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：`上传到远程/刷新/登录/置顶/源变量/书籍变量/复制链接/允许更新/分割长章节/删除提醒/清理缓存/日志` 均可达 | `lib/features/search/views/search_book_info_view.dart:1329`, `lib/features/search/views/search_book_info_view.dart:1351`, `lib/features/search/views/search_book_info_view.dart:1358`, `lib/features/search/views/search_book_info_view.dart:1366`, `lib/features/search/views/search_book_info_view.dart:1373`, `lib/features/search/views/search_book_info_view.dart:1381`, `lib/features/search/views/search_book_info_view.dart:1389`, `lib/features/search/views/search_book_info_view.dart:1396`, `lib/features/search/views/search_book_info_view.dart:1403`, `lib/features/search/views/search_book_info_view.dart:1411`, `lib/features/search/views/search_book_info_view.dart:1419`, `lib/features/search/views/search_book_info_view.dart:1426`, `lib/features/search/views/search_book_info_view.dart:1434`, `lib/features/search/views/search_book_info_view.dart:1441` |
| 状态 | 已同义：登录、变量、允许更新、分割长章节按来源/书籍类型动态显示 | `lib/features/search/views/search_book_info_view.dart:1332`, `lib/features/search/views/search_book_info_view.dart:1335`, `lib/features/search/views/search_book_info_view.dart:1338` |
| 异常 | 已同义：未在书架置顶、链接缺失复制、书源缺失登录等均有可观测提示 | `lib/features/search/views/search_book_info_view.dart:702`, `lib/features/search/views/search_book_info_view.dart:915`, `lib/features/search/views/search_book_info_view.dart:924`, `lib/features/search/views/search_book_info_view.dart:682` |
| 文案 | 已同义：菜单主文案与 legacy 语义一致（允许更新/分割长章节/删除提醒采用开关态文案） | `lib/features/search/views/search_book_info_view.dart:1411`, `lib/features/search/views/search_book_info_view.dart:1419`, `lib/features/search/views/search_book_info_view.dart:1426` |
| 排版 | 已同义：详情页顶栏“编辑/分享/更多”与底部“书架/阅读”两段式结构等价 | `lib/features/search/views/search_book_info_view.dart:1655`, `lib/features/search/views/search_book_info_view.dart:1660`, `lib/features/search/views/search_book_info_view.dart:1665`, `lib/features/search/views/search_book_info_view.dart:1985` |
| 交互触发 | 已同义：更多菜单每项都绑定明确动作，未出现“点击无响应” | `lib/features/search/views/search_book_info_view.dart:1329` |
| 输入 | 已同义：源变量/书籍变量提供输入框并支持保存/取消 | `lib/features/search/views/search_book_info_view.dart:740`, `lib/features/search/views/search_book_info_view.dart:802` |
| 交互逻辑 | 已同义：刷新目录路径区分书架/非书架，失败分支可观测且不污染当前状态 | `lib/features/search/views/search_book_info_view.dart:1192`, `lib/features/search/views/search_book_info_view.dart:1231`, `lib/features/search/views/search_book_info_view.dart:1318` |

### 2.4 编辑入口（`book_info_edit`）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：书架内可见编辑入口，进入编辑页可取消/保存 | `lib/features/search/views/search_book_info_view.dart:1655`, `lib/features/search/views/search_book_info_edit_view.dart:90`, `lib/features/search/views/search_book_info_edit_view.dart:94`, `lib/features/search/views/search_book_info_edit_view.dart:99` |
| 状态 | 已同义：编辑草稿由当前书籍信息初始化 | `lib/features/search/views/search_book_info_view.dart:645`, `lib/features/search/views/search_book_info_edit_view.dart:22` |
| 异常 | 已同义：非书架或记录缺失时阻断并提示 | `lib/features/search/views/search_book_info_view.dart:629`, `lib/features/search/views/search_book_info_view.dart:635` |
| 文案 | 已同义：书名/作者/封面链接/简介字段语义与 legacy 编辑页一致 | `lib/features/search/views/search_book_info_edit_view.dart:115`, `lib/features/search/views/search_book_info_edit_view.dart:121`, `lib/features/search/views/search_book_info_edit_view.dart:127`, `lib/features/search/views/search_book_info_edit_view.dart:134` |
| 排版 | 已同义：顶部取消/保存，主体表单分组布局 | `lib/features/search/views/search_book_info_edit_view.dart:90`, `lib/features/search/views/search_book_info_edit_view.dart:106` |
| 交互触发 | 已同义：保存返回 draft 并回写书架记录 | `lib/features/search/views/search_book_info_edit_view.dart:44`, `lib/features/search/views/search_book_info_view.dart:656` |
| 输入 | 已同义：四字段可编辑并保留多行简介输入 | `lib/features/search/views/search_book_info_edit_view.dart:55`, `lib/features/search/views/search_book_info_edit_view.dart:136` |
| 交互逻辑 | 已同义：保存后同步详情展示并重置简介展开状态 | `lib/features/search/views/search_book_info_view.dart:657`, `lib/features/search/views/search_book_info_view.dart:661` |

## 3. 回归路径 C1（搜索）

- 路径：搜索页菜单 -> 搜索结果 -> 书籍详情 -> 编辑入口
- 手工核验点：
  - 搜索页右上菜单可触发四入口；精准搜索切换可重搜
  - 搜索范围可做“快速切组”和“多分组/单源”确认
  - 详情页更多菜单所有入口均可触发反馈（含新收敛的“置顶/复制链接”常驻入口）
  - 书架内编辑入口可保存并回写详情页

## 4. 命令验证证据

```bash
flutter test test/search_view_compile_test.dart
flutter test test/search_scope_picker_view_compile_test.dart
flutter test test/search_book_info_view_compile_test.dart
flutter test test/search_book_info_menu_helper_test.dart
```

- 结果：通过。
- 说明：按仓库规则，本阶段未执行 `flutter analyze`（保留到 T18 提交前一次执行）。

## 5. 保留差异与后续

- 保留差异：`分享` 当前为“复制分享串”，而 legacy 为二维码分享弹层；业务语义一致但交互载体不同。
- 回补计划：在后续 `bookInfo` 深度收敛阶段补齐二维码分享交互壳（不改变当前核心链路）。
