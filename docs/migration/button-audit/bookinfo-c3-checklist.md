# 详情链路对照清单（T09 / C3）

- 任务状态：`done`
- 对应计划：`PLANS.md` / `T09`
- 产出日期：`2026-02-20`
- 对照基准：
  - `../legado/app/src/main/res/menu/book_info.xml`
  - `../legado/app/src/main/java/io/legado/app/ui/book/info/BookInfoActivity.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/info/BookInfoViewModel.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/info/edit/BookInfoEditActivity.kt`

## 1. 差异点清单（实现前 -> 本次收敛）

| 差异ID | legacy 行为 | soupreader 原状态 | 本次处理 | 影响 |
|---|---|---|---|---|
| BI-001 | `menu_share_it` 为二维码分享入口（详情页直接进入二维码载体） | 分享按钮仅复制分享串到剪贴板 | 改为进入二维码分享页，保留系统分享兜底 | 详情页分享交互路径与 legacy 同义 |
| BI-002 | `menu_split_long_chapter` 切换后会触发重新加载详情/目录，并在关闭时提示耗时 | 仅切换配置状态，不触发重载 | 切换后补充加载状态与重载流程，关闭时补充耗时提示 | 状态流转与边界反馈更贴近 legacy |
| BI-003 | `menu_top` 同时影响置顶与最近阅读排序可见性 | 仅更新 `addedTime` | 置顶时同时更新 `addedTime + lastReadTime` | “最近添加/最近阅读”两种排序下均可见置顶效果 |

## 2. 逐项检查清单（入口/状态/异常/文案/排版/触发）

### 2.1 详情页顶栏动作（编辑/分享/更多）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：顶栏保留“编辑（书架内可见）/分享/更多”三入口 | `lib/features/search/views/search_book_info_view.dart:1673`, `lib/features/search/views/search_book_info_view.dart:1678`, `lib/features/search/views/search_book_info_view.dart:1683` |
| 状态 | 已同义：编辑入口仅在书架内展示；更多按钮在切源中显示加载态 | `lib/features/search/views/search_book_info_view.dart:1671`, `lib/features/search/views/search_book_info_view.dart:1685` |
| 异常 | 已同义：缺少可分享链接时可观测提示 | `lib/features/search/views/search_book_info_view.dart:620` |
| 文案 | 已同义：二维码页标题使用书名（空值回落“书籍二维码”） | `lib/features/search/views/search_book_info_view.dart:629` |
| 排版 | 已同义：分享入口仍位于详情页顶栏右上，层级与 legacy toolbar 行为等价 | `lib/features/search/views/search_book_info_view.dart:1663` |
| 交互触发 | 已同义：点击分享进入二维码页并可继续系统分享 | `lib/features/search/views/search_book_info_view.dart:625`, `lib/features/source/views/source_qr_share_view.dart:31` |
| 输入 | 不涉及（顶栏动作无表单输入） | - |
| 交互逻辑 | 已同义：二维码页支持 PNG 分享失败时回落文本分享 | `lib/features/source/views/source_qr_share_view.dart:35`, `lib/features/source/views/source_qr_share_view.dart:51` |

### 2.2 更多菜单（`book_info`）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：`上传到远程/刷新/登录/置顶/源变量/书籍变量/复制链接/允许更新/分割长章节/删除提醒/清理缓存/日志` 均可达 | `lib/features/search/views/search_book_info_view.dart:1347`, `lib/features/search/views/search_book_info_view.dart:1461` |
| 状态 | 已同义：登录/变量/允许更新/分割长章节按书源与书籍类型动态显隐 | `lib/features/search/views/search_book_info_view.dart:1331`, `lib/features/search/views/search_book_info_view.dart:1334`, `lib/features/search/views/search_book_info_view.dart:1337` |
| 异常 | 已同义：书架缺失置顶、链接缺失复制、书源缺失登录等均可观测 | `lib/features/search/views/search_book_info_view.dart:712`, `lib/features/search/views/search_book_info_view.dart:928`, `lib/features/search/views/search_book_info_view.dart:674` |
| 文案 | 已同义：允许更新/分割长章节/删除提醒采用开关态文案 | `lib/features/search/views/search_book_info_view.dart:1422`, `lib/features/search/views/search_book_info_view.dart:1430`, `lib/features/search/views/search_book_info_view.dart:1437` |
| 排版 | 已同义：更多动作聚合为 `CupertinoActionSheet`，顺序与 legacy 菜单一致 | `lib/features/search/views/search_book_info_view.dart:1325` |
| 交互触发 | 已同义：每个 action 均绑定显式 handler，未出现“点击无响应” | `lib/features/search/views/search_book_info_view.dart:1329` |
| 输入 | 已同义：源变量/书籍变量弹窗支持输入、取消、保存 | `lib/features/search/views/search_book_info_view.dart:751`, `lib/features/search/views/search_book_info_view.dart:813` |
| 交互逻辑 | 已同义：分割长章节切换后进入加载态并触发上下文重载；关闭时提示“重载耗时” | `lib/features/search/views/search_book_info_view.dart:954`, `lib/features/search/views/search_book_info_view.dart:966`, `lib/features/search/views/search_book_info_view.dart:969` |

### 2.3 置顶语义（`menu_top`）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：置顶入口常驻于更多菜单 | `lib/features/search/views/search_book_info_view.dart:1384` |
| 状态 | 已同义：仅书架内有效，书架外阻断并提示 | `lib/features/search/views/search_book_info_view.dart:710` |
| 异常 | 已同义：书架记录不存在时可观测提示 | `lib/features/search/views/search_book_info_view.dart:717` |
| 文案 | 已同义：完成后反馈“已置顶（按最近添加/最近阅读可见）” | `lib/features/search/views/search_book_info_view.dart:731` |
| 排版 | 已同义：维持 ActionSheet 中部操作组位置 | `lib/features/search/views/search_book_info_view.dart:1325` |
| 交互触发 | 已同义：点击后立即落库并刷新页面状态 | `lib/features/search/views/search_book_info_view.dart:723`, `lib/features/search/views/search_book_info_view.dart:730` |
| 输入 | 不涉及 | - |
| 交互逻辑 | 已同义：置顶同时更新 `addedTime + lastReadTime`，覆盖两种排序口径 | `lib/features/search/views/search_book_info_view.dart:724` |

## 3. 回归路径 C3（详情）

- 路径：搜索结果或书架条目 -> 书籍详情 -> 顶栏分享/更多菜单。
- 手工核验点：
  - 分享入口进入二维码页，二维码页右上“分享”可触发系统分享。
  - 分割长章节切换后有加载态，关闭时提示“重载可能耗时更长”。
  - 置顶后在“最近添加/最近阅读”排序下都能把该书顶到前列。

## 4. 命令验证证据

```bash
flutter test test/search_book_info_view_compile_test.dart
flutter test test/search_book_info_menu_helper_test.dart
flutter test test/source_qr_share_view_compile_test.dart
```

- 结果：通过。
- 说明：按仓库规则，本阶段未执行 `flutter analyze`（保留到 T18 提交前一次执行）。

## 5. 保留差异与后续

- 保留差异：legacy 详情页仍包含封面编辑、分组调整、作者/书名点击搜索等入口，当前 `T09` 仅覆盖 `book_info` 菜单与顶栏动作同义，不扩展到非菜单入口重排。
- 回补计划：在后续 `T10/T11`（目录/正文）完成后，再统一进入 `T12~T16A` 的全局交互逻辑复核，按同一模板补齐详情页非菜单入口对照。
