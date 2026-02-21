# SoupReader 入口台账（T03）

- 任务ID：`T03`
- 来源范围：`lib/main.dart` + `lib/features/**/(views|widgets)/*.dart`
- 生成脚本：`docs/migration/button-audit/extract_soupreader_button_entries.pl`
- 生成时间：`2026-02-21 03:03:58 +0800`

## 提取口径

- 本台账聚焦“可点击入口”候选，覆盖 `CupertinoActionSheetAction`、`CupertinoButton`、`CupertinoListTile/ListTile`、`ShadButton`、`IconButton` 及阅读器 legacy 菜单构建入口。
- 记录字段：`module/page/file:line/widget_kind/label/trigger`，用于 T04 映射阶段做 legacy -> soupreader 一对一对照。
- `label=expr:*` 表示动态文案（插值/变量/函数返回），需在 T04 中结合运行态确认最终可见文案。
- `label=-` 表示当前代码块未抽取到显式文案（常见于仅图标按钮），需在 T04 补人工核对。

## 可复现命令

```bash
perl docs/migration/button-audit/extract_soupreader_button_entries.pl > /tmp/soupreader_button_entries.tsv
```

## 概览统计

| 指标 | 数值 |
|---|---:|
| 入口总数 | 546 |
| 覆盖文件数 | 58 |
| 覆盖页面数 | 58 |
| 无显式文案（`label=-`） | 80 |

## 模块分布

| 模块 | 入口数 |
|---|---:|
| `source` | 201 |
| `settings` | 144 |
| `reader` | 64 |
| `rss` | 37 |
| `search` | 35 |
| `bookshelf` | 27 |
| `replace` | 19 |
| `discovery` | 15 |
| `common` | 3 |
| `app` | 1 |

## 组件类型分布

| 组件类型 | 入口数 |
|---|---:|
| `CupertinoActionSheetAction` | 235 |
| `CupertinoListTile` | 168 |
| `CupertinoButton` | 120 |
| `ListTile` | 11 |
| `ShadButton` | 8 |
| `IconButton` | 3 |
| `ReaderLegacyMenuActions` | 1 |

## 阅读器动态菜单补充（人工补记）

> 自动提取会记录 `ReaderLegacyMenuHelper.buildReadMenuActions(...)` 调用点；为避免动态文案遗漏，补充 helper 中定义的菜单全集。

- 来源文件：`lib/features/reader/services/reader_legacy_menu_helper.dart`

### 正文菜单（ReadMenu）

`换源`、`刷新`、`离线缓存`、`TXT 目录规则`、`设置编码`、`添加书签`、`编辑正文`、`翻页动画`、`获取进度`、`覆盖进度`、`正文倒序`、`模拟阅读`、`启用替换规则`、`同名标题去重`、`重新分段`、`删除 ruby 标签`、`删除 h 标签`、`图片样式`、`更新目录`、`生效替换规则`、`日志`、`帮助`

### 目录菜单（TocMenu）

`倒序`、`使用替换规则`、`加载字数`、`TXT 目录规则`、`分割长章节`、`导出书签`、`导出 Markdown`、`日志`

## 全量条目（546）

| 序号 | 模块 | 页面 | 文件位置 | 组件类型 | 文案 | 触发器 |
|---:|---|---|---|---|---|---|
| 1 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:274` | `CupertinoActionSheetAction` | 图墙模式 | `onPressed=closure` |
| 2 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:282` | `CupertinoActionSheetAction` | 列表模式 | `onPressed=closure` |
| 3 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:291` | `CupertinoActionSheetAction` | expr:'排序：${_sortLabel(mode | `onPressed=closure` |
| 4 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:300` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 5 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:340` | `CupertinoActionSheetAction` | expr:_updateCatalogMenuText( | `onPressed=closure` |
| 6 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:347` | `CupertinoActionSheetAction` | 本机导入 | `onPressed=closure` |
| 7 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:354` | `CupertinoActionSheetAction` | 远程导入 | `onPressed=closure` |
| 8 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:361` | `CupertinoActionSheetAction` | URL 导入 | `onPressed=closure` |
| 9 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:368` | `CupertinoActionSheetAction` | 书架管理 | `onPressed=closure` |
| 10 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:375` | `CupertinoActionSheetAction` | 缓存导出 | `onPressed=closure` |
| 11 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:382` | `CupertinoActionSheetAction` | 分组管理 | `onPressed=closure` |
| 12 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:389` | `CupertinoActionSheetAction` | 书架布局 | `onPressed=closure` |
| 13 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:396` | `CupertinoActionSheetAction` | 导出书架 | `onPressed=closure` |
| 14 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:403` | `CupertinoActionSheetAction` | 导入书架 | `onPressed=closure` |
| 15 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:410` | `CupertinoActionSheetAction` | 日志 | `onPressed=closure` |
| 16 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:418` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 17 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:523` | `CupertinoButton` | - | `onPressed=_openGlobalSearch` |
| 18 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:529` | `CupertinoButton` | - | `onPressed=_showMoreMenu` |
| 19 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:581` | `ShadButton` | 导入本地书籍 | `onPressed=_importLocalBook` |
| 20 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:948` | `CupertinoActionSheetAction` | 书籍详情 | `onPressed=closure` |
| 21 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:955` | `CupertinoActionSheetAction` | 移除书籍 | `onPressed=closure_async` |
| 22 | `bookshelf` | `features/bookshelf/views/bookshelf_view` | `lib/features/bookshelf/views/bookshelf_view.dart:965` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 23 | `bookshelf` | `features/bookshelf/views/reading_history_view` | `lib/features/bookshelf/views/reading_history_view.dart:54` | `CupertinoListTile` | expr:Text(book.title | `onTap=closure=>` |
| 24 | `bookshelf` | `features/bookshelf/views/reading_history_view` | `lib/features/bookshelf/views/reading_history_view.dart:120` | `CupertinoActionSheetAction` | 继续阅读 | `onPressed=closure` |
| 25 | `bookshelf` | `features/bookshelf/views/reading_history_view` | `lib/features/bookshelf/views/reading_history_view.dart:127` | `CupertinoActionSheetAction` | 清除阅读记录 | `onPressed=closure_async` |
| 26 | `bookshelf` | `features/bookshelf/views/reading_history_view` | `lib/features/bookshelf/views/reading_history_view.dart:134` | `CupertinoActionSheetAction` | 从书架移除 | `onPressed=closure_async` |
| 27 | `bookshelf` | `features/bookshelf/views/reading_history_view` | `lib/features/bookshelf/views/reading_history_view.dart:143` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 28 | `common` | `features/common/views/qr_scan_view` | `lib/features/common/views/qr_scan_view.dart:53` | `CupertinoButton` | 取消 | `onPressed=closure=>` |
| 29 | `common` | `features/common/views/qr_scan_view` | `lib/features/common/views/qr_scan_view.dart:75` | `CupertinoButton` | 切换闪光灯 | `onPressed=closure=>` |
| 30 | `common` | `features/common/views/qr_scan_view` | `lib/features/common/views/qr_scan_view.dart:83` | `CupertinoButton` | 取消 | `onPressed=closure=>` |
| 31 | `discovery` | `features/discovery/views/discovery_explore_results_view` | `lib/features/discovery/views/discovery_explore_results_view.dart:150` | `CupertinoButton` | - | `onPressed=_loading` |
| 32 | `discovery` | `features/discovery/views/discovery_explore_results_view` | `lib/features/discovery/views/discovery_explore_results_view.dart:217` | `ShadButton` | 重试 | `onPressed=closure=>` |
| 33 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:159` | `CupertinoActionSheetAction` | expr:group | `onPressed=closure` |
| 34 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:166` | `CupertinoActionSheetAction` | 清空筛选 | `onPressed=closure` |
| 35 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:174` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 36 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:272` | `CupertinoActionSheetAction` | 编辑书源 | `onPressed=closure` |
| 37 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:279` | `CupertinoActionSheetAction` | 置顶 | `onPressed=closure` |
| 38 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:286` | `CupertinoActionSheetAction` | 源内搜索 | `onPressed=closure` |
| 39 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:294` | `CupertinoActionSheetAction` | 登录 | `onPressed=closure` |
| 40 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:301` | `CupertinoActionSheetAction` | 刷新发现缓存 | `onPressed=closure` |
| 41 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:308` | `CupertinoActionSheetAction` | 删除书源 | `onPressed=closure` |
| 42 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:317` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 43 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:437` | `ShadButton` | 好 | `onPressed=closure=>` |
| 44 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:462` | `CupertinoButton` | - | `onPressed=_showGroupFilterMenu` |
| 45 | `discovery` | `features/discovery/views/discovery_view` | `lib/features/discovery/views/discovery_view.dart:642` | `CupertinoButton` | - | `onPressed=closure=>` |
| 46 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:3323` | `ReaderLegacyMenuActions` | - | `builder:helper` |
| 47 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:3334` | `CupertinoActionSheetAction` | expr:_readerActionLabel(action | `onPressed=closure_async` |
| 48 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:3343` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 49 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:3779` | `IconButton` | - | `onTap=hasHits` |
| 50 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:3783` | `IconButton` | - | `onTap=hasHits` |
| 51 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:3905` | `IconButton` | - | `-` |
| 52 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:3909` | `CupertinoButton` | - | `onPressed=onTap` |
| 53 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:3929` | `CupertinoButton` | - | `onPressed=onTap` |
| 54 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:3961` | `CupertinoButton` | - | `onPressed=onTap` |
| 55 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:4230` | `CupertinoActionSheetAction` | - | `onPressed=closure=>` |
| 56 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:4243` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 57 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:4642` | `CupertinoActionSheetAction` | 登录 | `onPressed=closure_async` |
| 58 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:4650` | `CupertinoActionSheetAction` | 章节购买 | `onPressed=closure_async` |
| 59 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:4657` | `CupertinoActionSheetAction` | 编辑书源 | `onPressed=closure_async` |
| 60 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:4664` | `CupertinoActionSheetAction` | 禁用书源 | `onPressed=closure_async` |
| 61 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:4673` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 62 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:5773` | `CupertinoButton` | - | `onPressed=closure=>` |
| 63 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:5908` | `CupertinoButton` | 删除样式 | `onPressed=onDelete` |
| 64 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:5991` | `CupertinoActionSheetAction` | expr:name | `onPressed=closure=>` |
| 65 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:5996` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 66 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:6039` | `CupertinoActionSheetAction` | 选择内置背景 | `onPressed=closure=>` |
| 67 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:6044` | `CupertinoActionSheetAction` | 选择本地图片 | `onPressed=closure=>` |
| 68 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:6049` | `CupertinoActionSheetAction` | 使用纯色背景 | `onPressed=closure=>` |
| 69 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:6055` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 70 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:6107` | `CupertinoActionSheetAction` | expr:displayName.isEmpty ? name : displayName | `onPressed=closure=>` |
| 71 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:6112` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 72 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:6289` | `CupertinoButton` | - | `onPressed=safeProgress` |
| 73 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:6313` | `CupertinoButton` | - | `onPressed=safeProgress` |
| 74 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:6394` | `CupertinoButton` | - | `onPressed=closure=>` |
| 75 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:6502` | `CupertinoButton` | - | `onPressed=closure=>` |
| 76 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:7216` | `CupertinoButton` | expr:isHiddenMode ? '${mode.name}（隐藏）' : mode.name | `onPressed=isHiddenMode` |
| 77 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:8261` | `CupertinoActionSheetAction` | - | `onPressed=closure` |
| 78 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:8277` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 79 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:8583` | `CupertinoButton` | - | `onPressed=closure=>` |
| 80 | `reader` | `features/reader/views/simple_reader_view` | `lib/features/reader/views/simple_reader_view.dart:8602` | `CupertinoButton` | expr:font.name | `onPressed=closure` |
| 81 | `reader` | `features/reader/widgets/auto_pager` | `lib/features/reader/widgets/auto_pager.dart:249` | `CupertinoButton` | - | `onPressed=closure` |
| 82 | `reader` | `features/reader/widgets/auto_pager` | `lib/features/reader/widgets/auto_pager.dart:268` | `CupertinoButton` | - | `onPressed=widget.autoPager.toggle` |
| 83 | `reader` | `features/reader/widgets/bookmark_dialog` | `lib/features/reader/widgets/bookmark_dialog.dart:201` | `CupertinoButton` | - | `onPressed=_addBookmark` |
| 84 | `reader` | `features/reader/widgets/bookmark_dialog` | `lib/features/reader/widgets/bookmark_dialog.dart:222` | `CupertinoButton` | - | `onPressed=closure=>` |
| 85 | `reader` | `features/reader/widgets/bookmark_dialog` | `lib/features/reader/widgets/bookmark_dialog.dart:373` | `CupertinoButton` | - | `onPressed=closure=>` |
| 86 | `reader` | `features/reader/widgets/chapter_list_dialog` | `lib/features/reader/widgets/chapter_list_dialog.dart:160` | `CupertinoButton` | - | `onPressed=closure` |
| 87 | `reader` | `features/reader/widgets/click_action_config_dialog` | `lib/features/reader/widgets/click_action_config_dialog.dart:146` | `CupertinoButton` | 恢复默认 | `onPressed=_resetToDefault` |
| 88 | `reader` | `features/reader/widgets/click_action_config_dialog` | `lib/features/reader/widgets/click_action_config_dialog.dart:203` | `CupertinoButton` | - | `onPressed=closure=>` |
| 89 | `reader` | `features/reader/widgets/click_action_config_dialog` | `lib/features/reader/widgets/click_action_config_dialog.dart:321` | `CupertinoActionSheetAction` | - | `onPressed=closure` |
| 90 | `reader` | `features/reader/widgets/click_action_config_dialog` | `lib/features/reader/widgets/click_action_config_dialog.dart:344` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure` |
| 91 | `reader` | `features/reader/widgets/reader_catalog_sheet` | `lib/features/reader/widgets/reader_catalog_sheet.dart:498` | `CupertinoButton` | - | `onPressed=_busy` |
| 92 | `reader` | `features/reader/widgets/reader_catalog_sheet` | `lib/features/reader/widgets/reader_catalog_sheet.dart:509` | `CupertinoButton` | - | `onPressed=_busy` |
| 93 | `reader` | `features/reader/widgets/reader_catalog_sheet` | `lib/features/reader/widgets/reader_catalog_sheet.dart:520` | `CupertinoButton` | - | `onPressed=_busy` |
| 94 | `reader` | `features/reader/widgets/reader_catalog_sheet` | `lib/features/reader/widgets/reader_catalog_sheet.dart:616` | `CupertinoButton` | - | `onPressed=closure` |
| 95 | `reader` | `features/reader/widgets/reader_catalog_sheet` | `lib/features/reader/widgets/reader_catalog_sheet.dart:673` | `CupertinoActionSheetAction` | expr:_tocActionLabel(action | `onPressed=closure_async` |
| 96 | `reader` | `features/reader/widgets/reader_catalog_sheet` | `lib/features/reader/widgets/reader_catalog_sheet.dart:682` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 97 | `reader` | `features/reader/widgets/reader_menus` | `lib/features/reader/widgets/reader_menus.dart:476` | `CupertinoButton` | - | `onPressed=onTap` |
| 98 | `reader` | `features/reader/widgets/reader_menus` | `lib/features/reader/widgets/reader_menus.dart:488` | `CupertinoButton` | - | `onPressed=onTap` |
| 99 | `reader` | `features/reader/widgets/reader_menus` | `lib/features/reader/widgets/reader_menus.dart:541` | `CupertinoActionSheetAction` | - | `onPressed=closure` |
| 100 | `reader` | `features/reader/widgets/reader_menus` | `lib/features/reader/widgets/reader_menus.dart:589` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 101 | `reader` | `features/reader/widgets/reader_quick_settings_sheet` | `lib/features/reader/widgets/reader_quick_settings_sheet.dart:122` | `CupertinoButton` | - | `onPressed=closure=>` |
| 102 | `reader` | `features/reader/widgets/reader_quick_settings_sheet` | `lib/features/reader/widgets/reader_quick_settings_sheet.dart:142` | `CupertinoButton` | - | `onPressed=_showMoreActions` |
| 103 | `reader` | `features/reader/widgets/reader_quick_settings_sheet` | `lib/features/reader/widgets/reader_quick_settings_sheet.dart:224` | `CupertinoActionSheetAction` | 打开完整阅读设置 | `onPressed=closure` |
| 104 | `reader` | `features/reader/widgets/reader_quick_settings_sheet` | `lib/features/reader/widgets/reader_quick_settings_sheet.dart:231` | `CupertinoActionSheetAction` | 恢复默认设置 | `onPressed=closure` |
| 105 | `reader` | `features/reader/widgets/reader_quick_settings_sheet` | `lib/features/reader/widgets/reader_quick_settings_sheet.dart:240` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 106 | `reader` | `features/reader/widgets/reader_quick_settings_sheet` | `lib/features/reader/widgets/reader_quick_settings_sheet.dart:878` | `CupertinoButton` | 打开完整阅读设置 | `onPressed=onOpenFullSettings` |
| 107 | `reader` | `features/reader/widgets/source_switch_candidate_sheet` | `lib/features/reader/widgets/source_switch_candidate_sheet.dart:121` | `CupertinoButton` | 取消 | `onPressed=closure=>` |
| 108 | `reader` | `features/reader/widgets/source_switch_candidate_sheet` | `lib/features/reader/widgets/source_switch_candidate_sheet.dart:163` | `CupertinoButton` | - | `onPressed=closure=>` |
| 109 | `reader` | `features/reader/widgets/typography_settings_dialog` | `lib/features/reader/widgets/typography_settings_dialog.dart:255` | `CupertinoButton` | - | `onPressed=closure=>` |
| 110 | `replace` | `features/replace/views/replace_rule_edit_view` | `lib/features/replace/views/replace_rule_edit_view.dart:107` | `CupertinoButton` | 保存 | `onPressed=_save` |
| 111 | `replace` | `features/replace/views/replace_rule_edit_view` | `lib/features/replace/views/replace_rule_edit_view.dart:117` | `CupertinoListTile` | 启用 | `onChanged=closure=>` |
| 112 | `replace` | `features/replace/views/replace_rule_edit_view` | `lib/features/replace/views/replace_rule_edit_view.dart:141` | `CupertinoListTile` | 正则模式 | `onChanged=closure=>` |
| 113 | `replace` | `features/replace/views/replace_rule_edit_view` | `lib/features/replace/views/replace_rule_edit_view.dart:163` | `ListTile` | 有效性 | `-` |
| 114 | `replace` | `features/replace/views/replace_rule_edit_view` | `lib/features/replace/views/replace_rule_edit_view.dart:186` | `CupertinoListTile` | 作用于标题（scopeTitle） | `onChanged=closure=>` |
| 115 | `replace` | `features/replace/views/replace_rule_edit_view` | `lib/features/replace/views/replace_rule_edit_view.dart:194` | `CupertinoListTile` | 作用于正文（scopeContent） | `onChanged=closure=>` |
| 116 | `replace` | `features/replace/views/replace_rule_edit_view` | `lib/features/replace/views/replace_rule_edit_view.dart:231` | `CupertinoListTile` | 运行测试 | `onTap=_runTest` |
| 117 | `replace` | `features/replace/views/replace_rule_edit_view` | `lib/features/replace/views/replace_rule_edit_view.dart:236` | `ListTile` | 输出 | `-` |
| 118 | `replace` | `features/replace/views/replace_rule_edit_view` | `lib/features/replace/views/replace_rule_edit_view.dart:268` | `ListTile` | expr:Text(title | `onChanged=onChanged` |
| 119 | `replace` | `features/replace/views/replace_rule_list_view` | `lib/features/replace/views/replace_rule_list_view.dart:45` | `CupertinoButton` | - | `onPressed=_createRule` |
| 120 | `replace` | `features/replace/views/replace_rule_list_view` | `lib/features/replace/views/replace_rule_list_view.dart:51` | `CupertinoButton` | - | `onPressed=_showMoreMenu` |
| 121 | `replace` | `features/replace/views/replace_rule_list_view` | `lib/features/replace/views/replace_rule_list_view.dart:151` | `CupertinoButton` | 新建规则 | `onPressed=_createRule` |
| 122 | `replace` | `features/replace/views/replace_rule_list_view` | `lib/features/replace/views/replace_rule_list_view.dart:171` | `CupertinoListTile` | expr:Text(title | `onTap=closure=>` |
| 123 | `replace` | `features/replace/views/replace_rule_list_view` | `lib/features/replace/views/replace_rule_list_view.dart:205` | `CupertinoActionSheetAction` | 从剪贴板导入 | `onPressed=closure` |
| 124 | `replace` | `features/replace/views/replace_rule_list_view` | `lib/features/replace/views/replace_rule_list_view.dart:212` | `CupertinoActionSheetAction` | 从文件导入 | `onPressed=closure` |
| 125 | `replace` | `features/replace/views/replace_rule_list_view` | `lib/features/replace/views/replace_rule_list_view.dart:219` | `CupertinoActionSheetAction` | 从网络导入 | `onPressed=closure` |
| 126 | `replace` | `features/replace/views/replace_rule_list_view` | `lib/features/replace/views/replace_rule_list_view.dart:226` | `CupertinoActionSheetAction` | 导出 | `onPressed=closure` |
| 127 | `replace` | `features/replace/views/replace_rule_list_view` | `lib/features/replace/views/replace_rule_list_view.dart:233` | `CupertinoActionSheetAction` | 删除未启用规则 | `onPressed=closure` |
| 128 | `replace` | `features/replace/views/replace_rule_list_view` | `lib/features/replace/views/replace_rule_list_view.dart:242` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 129 | `rss` | `features/rss/views/rss_group_manage_view` | `lib/features/rss/views/rss_group_manage_view.dart:33` | `CupertinoButton` | - | `onPressed=_addGroup` |
| 130 | `rss` | `features/rss/views/rss_group_manage_view` | `lib/features/rss/views/rss_group_manage_view.dart:63` | `CupertinoListTile` | expr:Text(group | `onPressed=closure=>` |
| 131 | `rss` | `features/rss/views/rss_read_record_view` | `lib/features/rss/views/rss_read_record_view.dart:120` | `CupertinoButton` | 清空 | `onPressed=_loading` |
| 132 | `rss` | `features/rss/views/rss_source_edit_view` | `lib/features/rss/views/rss_source_edit_view.dart:185` | `CupertinoButton` | - | `onPressed=_saving` |
| 133 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:49` | `CupertinoButton` | - | `onPressed=_openSubscriptions` |
| 134 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:55` | `CupertinoButton` | - | `onPressed=_openAddSource` |
| 135 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:61` | `CupertinoButton` | - | `onPressed=_openQuickFilterSheet` |
| 136 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:140` | `CupertinoButton` | expr:action | `onPressed=noData` |
| 137 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:163` | `CupertinoListTile` | expr:Text(source.getDisplayNameGroup( | `onPressed=closure=>` |
| 138 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:234` | `CupertinoActionSheetAction` | 全部 | `onPressed=closure` |
| 139 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:241` | `CupertinoActionSheetAction` | 启用 | `onPressed=closure` |
| 140 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:248` | `CupertinoActionSheetAction` | 禁用 | `onPressed=closure` |
| 141 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:255` | `CupertinoActionSheetAction` | 需登录 | `onPressed=closure` |
| 142 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:262` | `CupertinoActionSheetAction` | 未分组 | `onPressed=closure` |
| 143 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:269` | `CupertinoActionSheetAction` | 分组管理 | `onPressed=closure` |
| 144 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:281` | `CupertinoActionSheetAction` | expr:group | `onPressed=closure` |
| 145 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:289` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 146 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:307` | `CupertinoActionSheetAction` | 编辑 | `onPressed=closure` |
| 147 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:314` | `CupertinoActionSheetAction` | 置顶 | `onPressed=closure` |
| 148 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:321` | `CupertinoActionSheetAction` | 置底 | `onPressed=closure` |
| 149 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:328` | `CupertinoActionSheetAction` | expr:groups.isEmpty ? '筛选与分组' : '筛选与分组 (${groups.length} | `onPressed=closure` |
| 150 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:335` | `CupertinoActionSheetAction` | 删除 | `onPressed=closure` |
| 151 | `rss` | `features/rss/views/rss_source_manage_view` | `lib/features/rss/views/rss_source_manage_view.dart:344` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 152 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:53` | `CupertinoButton` | - | `onPressed=_openFavorites` |
| 153 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:59` | `CupertinoButton` | - | `onPressed=_openGroupFilterSheet` |
| 154 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:65` | `CupertinoButton` | - | `onPressed=_openSourceSettings` |
| 155 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:144` | `CupertinoButton` | expr:action | `onPressed=noEnabled` |
| 156 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:171` | `CupertinoListTile` | expr:Text(source.sourceName | `onTap=closure=>` |
| 157 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:241` | `CupertinoActionSheetAction` | 全部 | `onPressed=closure` |
| 158 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:249` | `CupertinoActionSheetAction` | expr:group | `onPressed=closure` |
| 159 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:257` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 160 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:342` | `CupertinoActionSheetAction` | 置顶 | `onPressed=closure` |
| 161 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:349` | `CupertinoActionSheetAction` | 编辑 | `onPressed=closure` |
| 162 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:356` | `CupertinoActionSheetAction` | 禁用 | `onPressed=closure` |
| 163 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:364` | `CupertinoActionSheetAction` | expr:'分组筛选 (${groups.length} | `onPressed=closure` |
| 164 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:371` | `CupertinoActionSheetAction` | 删除 | `onPressed=closure` |
| 165 | `rss` | `features/rss/views/rss_subscription_view` | `lib/features/rss/views/rss_subscription_view.dart:380` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 166 | `search` | `features/search/views/search_book_info_edit_view` | `lib/features/search/views/search_book_info_edit_view.dart:91` | `CupertinoButton` | 取消 | `onPressed=closure=>` |
| 167 | `search` | `features/search/views/search_book_info_edit_view` | `lib/features/search/views/search_book_info_edit_view.dart:96` | `CupertinoButton` | 保存 | `onPressed=_submit` |
| 168 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1348` | `CupertinoActionSheetAction` | 上传到远程 | `onPressed=closure_async` |
| 169 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1355` | `CupertinoActionSheetAction` | 刷新 | `onPressed=closure_async` |
| 170 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1363` | `CupertinoActionSheetAction` | 登录 | `onPressed=closure_async` |
| 171 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1371` | `CupertinoActionSheetAction` | 置顶 | `onPressed=closure_async` |
| 172 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1379` | `CupertinoActionSheetAction` | 设置源变量 | `onPressed=closure_async` |
| 173 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1387` | `CupertinoActionSheetAction` | 设置书籍变量 | `onPressed=closure_async` |
| 174 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1395` | `CupertinoActionSheetAction` | 复制书籍链接 | `onPressed=closure_async` |
| 175 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1403` | `CupertinoActionSheetAction` | 复制目录链接 | `onPressed=closure_async` |
| 176 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1411` | `CupertinoActionSheetAction` | expr:_allowUpdate ? '允许更新：开' : '允许更新：关' | `onPressed=closure_async` |
| 177 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1419` | `CupertinoActionSheetAction` | expr:_splitLongChapter ? '分割长章节：开' : '分割长章节：关' | `onPressed=closure_async` |
| 178 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1426` | `CupertinoActionSheetAction` | expr:_deleteAlertEnabled ? '删除提醒：开' : '删除提醒：关' | `onPressed=closure_async` |
| 179 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1434` | `CupertinoActionSheetAction` | 清理缓存 | `onPressed=closure_async` |
| 180 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1441` | `CupertinoActionSheetAction` | 日志 | `onPressed=closure_async` |
| 181 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1449` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 182 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1617` | `ShadButton` | 好 | `onPressed=closure=>` |
| 183 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1658` | `CupertinoButton` | - | `onPressed=_openBookEdit` |
| 184 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1663` | `CupertinoButton` | - | `onPressed=_shareBook` |
| 185 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1668` | `CupertinoButton` | - | `onPressed=_showMoreActions` |
| 186 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1817` | `CupertinoButton` | 换源 | `onPressed=_switchingSource` |
| 187 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1837` | `CupertinoButton` | expr:_loadingToc ? '加载中' : '查看' | `onPressed=_loadingToc` |
| 188 | `search` | `features/search/views/search_book_info_view` | `lib/features/search/views/search_book_info_view.dart:1984` | `ShadButton` | 开始阅读 | `onPressed=(_loading \|\| _loadingToc` |
| 189 | `search` | `features/search/views/search_scope_picker_view` | `lib/features/search/views/search_scope_picker_view.dart:146` | `CupertinoButton` | 全部书源 | `onPressed=closure=>` |
| 190 | `search` | `features/search/views/search_scope_picker_view` | `lib/features/search/views/search_scope_picker_view.dart:154` | `CupertinoButton` | 取消 | `onPressed=closure=>` |
| 191 | `search` | `features/search/views/search_scope_picker_view` | `lib/features/search/views/search_scope_picker_view.dart:161` | `CupertinoButton` | 确定 | `onPressed=_submit` |
| 192 | `search` | `features/search/views/search_view` | `lib/features/search/views/search_view.dart:840` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 193 | `search` | `features/search/views/search_view` | `lib/features/search/views/search_view.dart:878` | `CupertinoActionSheetAction` | expr:title | `onPressed=closure=>` |
| 194 | `search` | `features/search/views/search_view` | `lib/features/search/views/search_view.dart:937` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 195 | `search` | `features/search/views/search_view` | `lib/features/search/views/search_view.dart:969` | `CupertinoActionSheetAction` | expr:label | `onPressed=closure=>` |
| 196 | `search` | `features/search/views/search_view` | `lib/features/search/views/search_view.dart:1100` | `ShadButton` | 好 | `onPressed=closure=>` |
| 197 | `search` | `features/search/views/search_view` | `lib/features/search/views/search_view.dart:1136` | `CupertinoButton` | - | `onPressed=_showSearchSettingsSheet` |
| 198 | `search` | `features/search/views/search_view` | `lib/features/search/views/search_view.dart:1178` | `ShadButton` | 搜索 | `onPressed=_isSearching` |
| 199 | `search` | `features/search/views/search_view` | `lib/features/search/views/search_view.dart:1547` | `CupertinoButton` | expr:book.title | `onPressed=closure=>` |
| 200 | `search` | `features/search/views/search_view` | `lib/features/search/views/search_view.dart:1625` | `CupertinoButton` | expr:keyword | `onPressed=closure=>` |
| 201 | `settings` | `features/settings/views/about_settings_view` | `lib/features/settings/views/about_settings_view.dart:47` | `CupertinoListTile` | 应用名称 | `-` |
| 202 | `settings` | `features/settings/views/about_settings_view` | `lib/features/settings/views/about_settings_view.dart:51` | `CupertinoListTile` | 版本 | `-` |
| 203 | `settings` | `features/settings/views/about_settings_view` | `lib/features/settings/views/about_settings_view.dart:60` | `CupertinoListTile` | 检查更新 | `onTap=_checkUpdate` |
| 204 | `settings` | `features/settings/views/about_settings_view` | `lib/features/settings/views/about_settings_view.dart:70` | `ListTile` | 如遇到书源解析问题，建议在“书源”中导出相关书源 JSON 便于排查。 | `-` |
| 205 | `settings` | `features/settings/views/appearance_settings_view` | `lib/features/settings/views/appearance_settings_view.dart:53` | `CupertinoListTile` | 跟随系统外观 | `onChanged=closure_async` |
| 206 | `settings` | `features/settings/views/appearance_settings_view` | `lib/features/settings/views/appearance_settings_view.dart:77` | `CupertinoListTile` | 深色模式 | `onChanged=followSystem` |
| 207 | `settings` | `features/settings/views/appearance_settings_view` | `lib/features/settings/views/appearance_settings_view.dart:99` | `ListTile` | 本页只影响应用整体外观，不影响阅读主题。 | `-` |
| 208 | `settings` | `features/settings/views/backup_settings_view` | `lib/features/settings/views/backup_settings_view.dart:47` | `CupertinoListTile` | 导出备份（推荐） | `onTap=closure=>` |
| 209 | `settings` | `features/settings/views/backup_settings_view` | `lib/features/settings/views/backup_settings_view.dart:53` | `CupertinoListTile` | 导出（含在线缓存） | `onTap=closure=>` |
| 210 | `settings` | `features/settings/views/backup_settings_view` | `lib/features/settings/views/backup_settings_view.dart:64` | `CupertinoListTile` | 从文件导入（合并） | `onTap=closure=>` |
| 211 | `settings` | `features/settings/views/backup_settings_view` | `lib/features/settings/views/backup_settings_view.dart:70` | `CupertinoListTile` | 从文件导入（覆盖） | `onTap=closure=>` |
| 212 | `settings` | `features/settings/views/backup_settings_view` | `lib/features/settings/views/backup_settings_view.dart:81` | `CupertinoListTile` | 服务器地址 | `onTap=closure=>` |
| 213 | `settings` | `features/settings/views/backup_settings_view` | `lib/features/settings/views/backup_settings_view.dart:98` | `CupertinoListTile` | WebDav 账号 | `onTap=closure=>` |
| 214 | `settings` | `features/settings/views/backup_settings_view` | `lib/features/settings/views/backup_settings_view.dart:116` | `CupertinoListTile` | WebDav 密码 | `onTap=closure=>` |
| 215 | `settings` | `features/settings/views/backup_settings_view` | `lib/features/settings/views/backup_settings_view.dart:135` | `CupertinoListTile` | 同步目录 | `onTap=closure=>` |
| 216 | `settings` | `features/settings/views/backup_settings_view` | `lib/features/settings/views/backup_settings_view.dart:152` | `CupertinoListTile` | 测试连接 | `onTap=_testWebDavConnection` |
| 217 | `settings` | `features/settings/views/backup_settings_view` | `lib/features/settings/views/backup_settings_view.dart:163` | `ListTile` | 备份包含：设置、书源、书架、本地书籍章节内容，以及“本书独立阅读设置”。 | `-` |
| 218 | `settings` | `features/settings/views/developer_tools_view` | `lib/features/settings/views/developer_tools_view.dart:24` | `CupertinoListTile` | 异常日志 | `onTap=closure=>` |
| 219 | `settings` | `features/settings/views/developer_tools_view` | `lib/features/settings/views/developer_tools_view.dart:39` | `ListTile` | 该页面用于查看关键节点的异常原因（启动、全局异常、书源五段链路、导入流程等）。 | `-` |
| 220 | `settings` | `features/settings/views/exception_logs_view` | `lib/features/settings/views/exception_logs_view.dart:55` | `CupertinoButton` | - | `onPressed=_clearLogs` |
| 221 | `settings` | `features/settings/views/exception_logs_view` | `lib/features/settings/views/exception_logs_view.dart:224` | `CupertinoButton` | - | `onPressed=closure=>` |
| 222 | `settings` | `features/settings/views/function_settings_view` | `lib/features/settings/views/function_settings_view.dart:24` | `CupertinoListTile` | 备份/同步 | `onTap=closure=>` |
| 223 | `settings` | `features/settings/views/function_settings_view` | `lib/features/settings/views/function_settings_view.dart:34` | `CupertinoListTile` | 阅读设置 | `onTap=closure=>` |
| 224 | `settings` | `features/settings/views/function_settings_view` | `lib/features/settings/views/function_settings_view.dart:44` | `CupertinoListTile` | 阅读记录 | `onTap=closure=>` |
| 225 | `settings` | `features/settings/views/function_settings_view` | `lib/features/settings/views/function_settings_view.dart:54` | `CupertinoListTile` | 隔空阅读（接力/Handoff）暂未实现 | `onTap=closure=>` |
| 226 | `settings` | `features/settings/views/function_settings_view` | `lib/features/settings/views/function_settings_view.dart:71` | `CupertinoListTile` | 其它设置 | `onTap=closure=>` |
| 227 | `settings` | `features/settings/views/global_reading_settings_view` | `lib/features/settings/views/global_reading_settings_view.dart:20` | `CupertinoListTile` | 界面（样式） | `onTap=closure=>` |
| 228 | `settings` | `features/settings/views/global_reading_settings_view` | `lib/features/settings/views/global_reading_settings_view.dart:31` | `CupertinoListTile` | 设置（行为） | `onTap=closure=>` |
| 229 | `settings` | `features/settings/views/other_hub_view` | `lib/features/settings/views/other_hub_view.dart:21` | `CupertinoListTile` | 分享暂未实现（可考虑接入 share_plus） | `onTap=closure=>` |
| 230 | `settings` | `features/settings/views/other_hub_view` | `lib/features/settings/views/other_hub_view.dart:33` | `CupertinoListTile` | 好评支持暂未实现 | `onTap=closure=>` |
| 231 | `settings` | `features/settings/views/other_hub_view` | `lib/features/settings/views/other_hub_view.dart:45` | `CupertinoListTile` | 关于我们 | `onTap=closure=>` |
| 232 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:59` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 233 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:74` | `CupertinoActionSheetAction` | - | `onPressed=closure_async` |
| 234 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:105` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 235 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:120` | `CupertinoActionSheetAction` | - | `onPressed=closure_async` |
| 236 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:150` | `CupertinoListTile` | 主页面（底部导航栏顺序/显示）暂未实现 | `onTap=closure=>` |
| 237 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:159` | `CupertinoListTile` | 更换图标暂未实现 | `onTap=closure=>` |
| 238 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:168` | `CupertinoListTile` | 自动刷新暂未实现 | `onTap=closure=>` |
| 239 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:177` | `CupertinoListTile` | 竖屏锁定暂未实现 | `onTap=closure=>` |
| 240 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:191` | `CupertinoListTile` | 服务器证书验证开关暂未实现（需要对 Dio/HttpClient 做统一配置） | `onTap=closure=>` |
| 241 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:200` | `CupertinoListTile` | 18+ 网址检测暂未实现 | `onTap=closure=>` |
| 242 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:209` | `CupertinoListTile` | 高级搜索设置暂未实现 | `onTap=closure=>` |
| 243 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:218` | `CupertinoListTile` | 智能评估暂未实现 | `onTap=closure=>` |
| 244 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:232` | `CupertinoListTile` | 书架显示方式 | `onTap=_pickBookshelfViewMode` |
| 245 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:242` | `CupertinoListTile` | 新书默认排序 | `onTap=_pickBookshelfSortMode` |
| 246 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:249` | `CupertinoListTile` | 启动自动跳转之前阅读暂未实现 | `onTap=closure=>` |
| 247 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:258` | `CupertinoListTile` | 新书默认开启净化替换暂未实现 | `onTap=closure=>` |
| 248 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:272` | `CupertinoListTile` | 下载与缓存 | `onTap=closure=>` |
| 249 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:287` | `CupertinoListTile` | 订阅设置暂未实现 | `onTap=closure=>` |
| 250 | `settings` | `features/settings/views/other_settings_view` | `lib/features/settings/views/other_settings_view.dart:301` | `CupertinoListTile` | 异常日志 | `onTap=closure=>` |
| 251 | `settings` | `features/settings/views/reading_behavior_settings_hub_view` | `lib/features/settings/views/reading_behavior_settings_hub_view.dart:91` | `CupertinoButton` | - | `onPressed=onTap` |
| 252 | `settings` | `features/settings/views/reading_interface_settings_hub_view` | `lib/features/settings/views/reading_interface_settings_hub_view.dart:130` | `CupertinoButton` | - | `onPressed=onTap` |
| 253 | `settings` | `features/settings/views/reading_other_settings_view` | `lib/features/settings/views/reading_other_settings_view.dart:42` | `CupertinoListTile` | 屏幕常亮 | `onChanged=closure=>` |
| 254 | `settings` | `features/settings/views/reading_other_settings_view` | `lib/features/settings/views/reading_other_settings_view.dart:50` | `CupertinoListTile` | 屏幕方向 | `onTap=_pickScreenOrientation` |
| 255 | `settings` | `features/settings/views/reading_other_settings_view` | `lib/features/settings/views/reading_other_settings_view.dart:57` | `CupertinoListTile` | 禁用返回键 | `onChanged=closure=>` |
| 256 | `settings` | `features/settings/views/reading_other_settings_view` | `lib/features/settings/views/reading_other_settings_view.dart:65` | `CupertinoListTile` | 自动阅读速度 | `onTap=_pickAutoReadSpeed` |
| 257 | `settings` | `features/settings/views/reading_other_settings_view` | `lib/features/settings/views/reading_other_settings_view.dart:76` | `CupertinoListTile` | 简繁转换 | `onTap=_pickChineseConverterType` |
| 258 | `settings` | `features/settings/views/reading_other_settings_view` | `lib/features/settings/views/reading_other_settings_view.dart:83` | `CupertinoListTile` | 净化章节标题 | `onChanged=closure=>` |
| 259 | `settings` | `features/settings/views/reading_other_settings_view` | `lib/features/settings/views/reading_other_settings_view.dart:141` | `CupertinoActionSheetAction` | expr:ChineseConverterType.label(mode | `onPressed=closure=>` |
| 260 | `settings` | `features/settings/views/reading_other_settings_view` | `lib/features/settings/views/reading_other_settings_view.dart:146` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 261 | `settings` | `features/settings/views/reading_other_settings_view` | `lib/features/settings/views/reading_other_settings_view.dart:163` | `CupertinoActionSheetAction` | expr:ReaderScreenOrientation.label(mode | `onPressed=closure=>` |
| 262 | `settings` | `features/settings/views/reading_other_settings_view` | `lib/features/settings/views/reading_other_settings_view.dart:168` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 263 | `settings` | `features/settings/views/reading_page_settings_view` | `lib/features/settings/views/reading_page_settings_view.dart:42` | `CupertinoListTile` | 翻页触发阈值 | `onTap=_pickTouchSlop` |
| 264 | `settings` | `features/settings/views/reading_page_settings_view` | `lib/features/settings/views/reading_page_settings_view.dart:48` | `CupertinoListTile` | 滚动翻页无动画 | `onChanged=closure=>` |
| 265 | `settings` | `features/settings/views/reading_page_settings_view` | `lib/features/settings/views/reading_page_settings_view.dart:61` | `CupertinoListTile` | 音量键翻页 | `onChanged=closure=>` |
| 266 | `settings` | `features/settings/views/reading_page_settings_view` | `lib/features/settings/views/reading_page_settings_view.dart:69` | `CupertinoListTile` | 鼠标滚轮翻页 | `onChanged=closure=>` |
| 267 | `settings` | `features/settings/views/reading_page_settings_view` | `lib/features/settings/views/reading_page_settings_view.dart:77` | `CupertinoListTile` | 长按按键翻页 | `onChanged=closure=>` |
| 268 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:76` | `CupertinoActionSheetAction` | - | `onPressed=closure` |
| 269 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:99` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 270 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:116` | `CupertinoActionSheetAction` | - | `onPressed=closure` |
| 271 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:148` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 272 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:166` | `CupertinoActionSheetAction` | - | `onPressed=closure` |
| 273 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:189` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 274 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:211` | `CupertinoActionSheetAction` | - | `onPressed=closure` |
| 275 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:234` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 276 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:279` | `CupertinoListTile` | 主题 | `onTap=_pickTheme` |
| 277 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:285` | `CupertinoListTile` | 字体 | `onTap=_pickFontFamily` |
| 278 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:291` | `CupertinoListTile` | 字重 | `onTap=_pickFontWeight` |
| 279 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:297` | `CupertinoListTile` | 翻页模式 | `onTap=_pickPageTurnMode` |
| 280 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:341` | `CupertinoListTile` | 两端对齐 | `onChanged=closure=>` |
| 281 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:349` | `CupertinoListTile` | 段首缩进 | `onChanged=closure=>` |
| 282 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:363` | `CupertinoListTile` | 排版与边距（高级） | `onTap=_openAdvancedTypography` |
| 283 | `settings` | `features/settings/views/reading_preferences_view` | `lib/features/settings/views/reading_preferences_view.dart:416` | `ListTile` | expr:Text(title | `onChanged=null` |
| 284 | `settings` | `features/settings/views/reading_status_action_settings_view` | `lib/features/settings/views/reading_status_action_settings_view.dart:44` | `CupertinoListTile` | 显示状态栏 | `onChanged=closure=>` |
| 285 | `settings` | `features/settings/views/reading_status_action_settings_view` | `lib/features/settings/views/reading_status_action_settings_view.dart:52` | `CupertinoListTile` | 隐藏导航栏 | `onChanged=closure=>` |
| 286 | `settings` | `features/settings/views/reading_status_action_settings_view` | `lib/features/settings/views/reading_status_action_settings_view.dart:60` | `CupertinoListTile` | 显示章节进度 | `onChanged=closure=>` |
| 287 | `settings` | `features/settings/views/reading_status_action_settings_view` | `lib/features/settings/views/reading_status_action_settings_view.dart:68` | `CupertinoListTile` | 显示时间 | `onChanged=closure=>` |
| 288 | `settings` | `features/settings/views/reading_status_action_settings_view` | `lib/features/settings/views/reading_status_action_settings_view.dart:75` | `CupertinoListTile` | 显示进度 | `onChanged=closure=>` |
| 289 | `settings` | `features/settings/views/reading_status_action_settings_view` | `lib/features/settings/views/reading_status_action_settings_view.dart:83` | `CupertinoListTile` | 显示电量 | `onChanged=closure=>` |
| 290 | `settings` | `features/settings/views/reading_status_action_settings_view` | `lib/features/settings/views/reading_status_action_settings_view.dart:90` | `CupertinoListTile` | 显示亮度条 | `onChanged=closure=>` |
| 291 | `settings` | `features/settings/views/reading_status_action_settings_view` | `lib/features/settings/views/reading_status_action_settings_view.dart:103` | `CupertinoListTile` | 点击区域（9 宫格） | `onTap=closure` |
| 292 | `settings` | `features/settings/views/reading_theme_settings_view` | `lib/features/settings/views/reading_theme_settings_view.dart:55` | `CupertinoListTile` | expr:Text(theme.name | `onTap=closure=>` |
| 293 | `settings` | `features/settings/views/reading_tip_settings_view` | `lib/features/settings/views/reading_tip_settings_view.dart:104` | `CupertinoListTile` | 页眉分割线 | `onChanged=closure=>` |
| 294 | `settings` | `features/settings/views/reading_tip_settings_view` | `lib/features/settings/views/reading_tip_settings_view.dart:155` | `CupertinoListTile` | 页脚分割线 | `onChanged=closure=>` |
| 295 | `settings` | `features/settings/views/reading_tip_settings_view` | `lib/features/settings/views/reading_tip_settings_view.dart:224` | `CupertinoListTile` | expr:Text(title | `onTap=onTap` |
| 296 | `settings` | `features/settings/views/reading_tip_settings_view` | `lib/features/settings/views/reading_tip_settings_view.dart:244` | `CupertinoActionSheetAction` | - | `onPressed=closure` |
| 297 | `settings` | `features/settings/views/reading_tip_settings_view` | `lib/features/settings/views/reading_tip_settings_view.dart:262` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 298 | `settings` | `features/settings/views/reading_tip_settings_view` | `lib/features/settings/views/reading_tip_settings_view.dart:505` | `ListTile` | expr:Text(title | `onChanged=null` |
| 299 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:145` | `CupertinoListTile` | 书源管理 | `onTap=closure=>` |
| 300 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:154` | `CupertinoListTile` | 替换净化 | `onTap=closure=>` |
| 301 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:163` | `CupertinoListTile` | 目录规则 | `onTap=closure=>` |
| 302 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:172` | `CupertinoListTile` | 订阅管理 | `onTap=closure=>` |
| 303 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:181` | `CupertinoListTile` | 语音管理（TTS）暂未实现 | `onTap=closure=>` |
| 304 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:190` | `CupertinoListTile` | 广告屏蔽规则暂未实现 | `onTap=closure=>` |
| 305 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:204` | `CupertinoListTile` | 应用外观 | `onTap=closure=>` |
| 306 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:213` | `CupertinoListTile` | 阅读主题 | `onTap=closure=>` |
| 307 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:222` | `CupertinoListTile` | 白天/黑夜主题（自动切换两套阅读主题）暂未实现 | `onTap=closure=>` |
| 308 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:231` | `CupertinoListTile` | 动态颜色/色差暂未实现 | `onTap=closure=>` |
| 309 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:245` | `CupertinoListTile` | 备份/同步 | `onTap=closure=>` |
| 310 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:254` | `CupertinoListTile` | 阅读设置（界面） | `onTap=closure=>` |
| 311 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:263` | `CupertinoListTile` | 阅读设置（行为） | `onTap=closure=>` |
| 312 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:272` | `CupertinoListTile` | 阅读记录 | `onTap=closure=>` |
| 313 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:281` | `CupertinoListTile` | 其它设置 | `onTap=closure=>` |
| 314 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:290` | `CupertinoListTile` | 隔空阅读（接力/Handoff）暂未实现 | `onTap=closure=>` |
| 315 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:304` | `CupertinoListTile` | 分享暂未实现（可考虑接入 share_plus） | `onTap=closure=>` |
| 316 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:313` | `CupertinoListTile` | 好评支持暂未实现 | `onTap=closure=>` |
| 317 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:322` | `CupertinoListTile` | 关于我们 | `onTap=closure=>` |
| 318 | `settings` | `features/settings/views/settings_view` | `lib/features/settings/views/settings_view.dart:336` | `CupertinoListTile` | 开发工具 | `onTap=closure=>` |
| 319 | `settings` | `features/settings/views/source_management_view` | `lib/features/settings/views/source_management_view.dart:23` | `CupertinoListTile` | 书源管理 | `onTap=closure` |
| 320 | `settings` | `features/settings/views/source_management_view` | `lib/features/settings/views/source_management_view.dart:35` | `CupertinoListTile` | 订阅管理 | `onTap=closure` |
| 321 | `settings` | `features/settings/views/source_management_view` | `lib/features/settings/views/source_management_view.dart:47` | `CupertinoListTile` | 语音管理（TTS）暂未实现 | `onTap=closure=>` |
| 322 | `settings` | `features/settings/views/source_management_view` | `lib/features/settings/views/source_management_view.dart:64` | `CupertinoListTile` | 替换净化 | `onTap=closure` |
| 323 | `settings` | `features/settings/views/source_management_view` | `lib/features/settings/views/source_management_view.dart:76` | `CupertinoListTile` | 目录规则 | `onTap=closure` |
| 324 | `settings` | `features/settings/views/source_management_view` | `lib/features/settings/views/source_management_view.dart:88` | `CupertinoListTile` | 广告屏蔽规则暂未实现 | `onTap=closure=>` |
| 325 | `settings` | `features/settings/views/storage_settings_view` | `lib/features/settings/views/storage_settings_view.dart:59` | `CupertinoListTile` | 仅 Wi‑Fi 下载 | `onChanged=closure_async` |
| 326 | `settings` | `features/settings/views/storage_settings_view` | `lib/features/settings/views/storage_settings_view.dart:77` | `CupertinoListTile` | 章节缓存占用 | `-` |
| 327 | `settings` | `features/settings/views/storage_settings_view` | `lib/features/settings/views/storage_settings_view.dart:82` | `CupertinoListTile` | 清理章节缓存（在线书籍） | `onTap=_confirmClearCache` |
| 328 | `settings` | `features/settings/views/storage_settings_view` | `lib/features/settings/views/storage_settings_view.dart:92` | `ListTile` | 清理缓存不会影响书架与阅读进度；本地导入书籍的正文不会被清理。 | `-` |
| 329 | `settings` | `features/settings/views/text_rules_settings_view` | `lib/features/settings/views/text_rules_settings_view.dart:42` | `CupertinoListTile` | 净化章节标题 | `onChanged=closure=>` |
| 330 | `settings` | `features/settings/views/text_rules_settings_view` | `lib/features/settings/views/text_rules_settings_view.dart:50` | `CupertinoListTile` | 简繁转换 | `onTap=_pickChineseConverterType` |
| 331 | `settings` | `features/settings/views/text_rules_settings_view` | `lib/features/settings/views/text_rules_settings_view.dart:62` | `CupertinoListTile` | 文本替换规则 | `onTap=_openReplaceRules` |
| 332 | `settings` | `features/settings/views/text_rules_settings_view` | `lib/features/settings/views/text_rules_settings_view.dart:72` | `ListTile` | 本页用于净化正文内容与标题。 | `-` |
| 333 | `settings` | `features/settings/views/text_rules_settings_view` | `lib/features/settings/views/text_rules_settings_view.dart:96` | `CupertinoActionSheetAction` | expr:ChineseConverterType.label(mode | `onPressed=closure=>` |
| 334 | `settings` | `features/settings/views/text_rules_settings_view` | `lib/features/settings/views/text_rules_settings_view.dart:101` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 335 | `settings` | `features/settings/views/theme_settings_view` | `lib/features/settings/views/theme_settings_view.dart:33` | `CupertinoListTile` | 应用外观 | `onTap=closure` |
| 336 | `settings` | `features/settings/views/theme_settings_view` | `lib/features/settings/views/theme_settings_view.dart:45` | `CupertinoListTile` | 阅读主题 | `onTap=closure` |
| 337 | `settings` | `features/settings/views/theme_settings_view` | `lib/features/settings/views/theme_settings_view.dart:57` | `CupertinoListTile` | 白天/黑夜主题（自动切换两套阅读主题）暂未实现 | `onTap=closure=>` |
| 338 | `settings` | `features/settings/views/theme_settings_view` | `lib/features/settings/views/theme_settings_view.dart:71` | `CupertinoListTile` | 动态颜色/色差暂未实现 | `onTap=closure=>` |
| 339 | `settings` | `features/settings/views/theme_settings_view` | `lib/features/settings/views/theme_settings_view.dart:80` | `CupertinoListTile` | 操作栏模糊暂未实现 | `onTap=closure=>` |
| 340 | `settings` | `features/settings/views/theme_settings_view` | `lib/features/settings/views/theme_settings_view.dart:89` | `CupertinoListTile` | 列表点击效果暂未实现 | `onTap=closure=>` |
| 341 | `settings` | `features/settings/views/theme_settings_view` | `lib/features/settings/views/theme_settings_view.dart:98` | `CupertinoListTile` | 网页主题化暂未实现 | `onTap=closure=>` |
| 342 | `settings` | `features/settings/views/theme_settings_view` | `lib/features/settings/views/theme_settings_view.dart:107` | `CupertinoListTile` | 界面缩放暂未实现 | `onTap=closure=>` |
| 343 | `settings` | `features/settings/views/theme_settings_view` | `lib/features/settings/views/theme_settings_view.dart:116` | `CupertinoListTile` | 自定义图标暂未实现 | `onTap=closure=>` |
| 344 | `settings` | `features/settings/views/theme_settings_view` | `lib/features/settings/views/theme_settings_view.dart:125` | `CupertinoListTile` | 自定义颜色（主色/强调色/背景/文字等）暂未实现 | `onTap=closure=>` |
| 345 | `source` | `features/source/views/source_availability_check_view` | `lib/features/source/views/source_availability_check_view.dart:506` | `CupertinoButton` | 复制 | `onPressed=_copyReport` |
| 346 | `source` | `features/source/views/source_availability_check_view` | `lib/features/source/views/source_availability_check_view.dart:512` | `CupertinoButton` | 导出 | `onPressed=_exportReportToFile` |
| 347 | `source` | `features/source/views/source_availability_check_view` | `lib/features/source/views/source_availability_check_view.dart:525` | `CupertinoListTile` | 进度 | `-` |
| 348 | `source` | `features/source/views/source_availability_check_view` | `lib/features/source/views/source_availability_check_view.dart:529` | `CupertinoListTile` | 结果 | `-` |
| 349 | `source` | `features/source/views/source_availability_check_view` | `lib/features/source/views/source_availability_check_view.dart:537` | `CupertinoListTile` | 结果筛选 | `-` |
| 350 | `source` | `features/source/views/source_availability_check_view` | `lib/features/source/views/source_availability_check_view.dart:559` | `CupertinoListTile` | 一键禁用失效源 | `onTap=_disableUnavailableSources` |
| 351 | `source` | `features/source/views/source_availability_check_view` | `lib/features/source/views/source_availability_check_view.dart:565` | `CupertinoListTile` | expr:_running ? (_stopRequested ? '停止中…' : '停止检测' | `onTap=_running` |
| 352 | `source` | `features/source/views/source_availability_check_view` | `lib/features/source/views/source_availability_check_view.dart:580` | `CupertinoListTile` | expr:Text(item.source.bookSourceName | `onTap=closure=>` |
| 353 | `source` | `features/source/views/source_debug_legacy_view` | `lib/features/source/views/source_debug_legacy_view.dart:275` | `CupertinoActionSheetAction` | expr:_exploreKinds[i].title | `onPressed=closure` |
| 354 | `source` | `features/source/views/source_debug_legacy_view` | `lib/features/source/views/source_debug_legacy_view.dart:285` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 355 | `source` | `features/source/views/source_debug_legacy_view` | `lib/features/source/views/source_debug_legacy_view.dart:341` | `CupertinoActionSheetAction` | 搜索源码 | `onPressed=closure` |
| 356 | `source` | `features/source/views/source_debug_legacy_view` | `lib/features/source/views/source_debug_legacy_view.dart:348` | `CupertinoActionSheetAction` | 详情源码 | `onPressed=closure` |
| 357 | `source` | `features/source/views/source_debug_legacy_view` | `lib/features/source/views/source_debug_legacy_view.dart:355` | `CupertinoActionSheetAction` | 目录源码 | `onPressed=closure` |
| 358 | `source` | `features/source/views/source_debug_legacy_view` | `lib/features/source/views/source_debug_legacy_view.dart:362` | `CupertinoActionSheetAction` | 正文源码 | `onPressed=closure` |
| 359 | `source` | `features/source/views/source_debug_legacy_view` | `lib/features/source/views/source_debug_legacy_view.dart:369` | `CupertinoActionSheetAction` | 刷新发现 | `onPressed=closure` |
| 360 | `source` | `features/source/views/source_debug_legacy_view` | `lib/features/source/views/source_debug_legacy_view.dart:376` | `CupertinoActionSheetAction` | 帮助 | `onPressed=closure` |
| 361 | `source` | `features/source/views/source_debug_legacy_view` | `lib/features/source/views/source_debug_legacy_view.dart:384` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 362 | `source` | `features/source/views/source_debug_legacy_view` | `lib/features/source/views/source_debug_legacy_view.dart:609` | `CupertinoButton` | - | `onPressed=_running` |
| 363 | `source` | `features/source/views/source_debug_legacy_view` | `lib/features/source/views/source_debug_legacy_view.dart:615` | `CupertinoButton` | - | `onPressed=_showMoreMenu` |
| 364 | `source` | `features/source/views/source_debug_text_view` | `lib/features/source/views/source_debug_text_view.dart:39` | `CupertinoButton` | 提示 | `onPressed=closure=>` |
| 365 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:337` | `CupertinoButton` | 保存 | `onPressed=_save` |
| 366 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:343` | `CupertinoButton` | 调试 | `onPressed=_saveAndOpenDebug` |
| 367 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:349` | `CupertinoButton` | - | `onPressed=_showMore` |
| 368 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:432` | `CupertinoButton` | expr:_typeLabel(_bookSourceType | `onPressed=_pickBookSourceType` |
| 369 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:641` | `CupertinoListTile` | expr:Text(_labelForField(key | `onPressed=closure` |
| 370 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:695` | `CupertinoActionSheetAction` | expr:entry.value | `onPressed=closure=>` |
| 371 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:700` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 372 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:720` | `CupertinoActionSheetAction` | 登录 | `onPressed=closure` |
| 373 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:727` | `CupertinoActionSheetAction` | 搜索 | `onPressed=closure` |
| 374 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:734` | `CupertinoActionSheetAction` | 清 Cookie | `onPressed=closure` |
| 375 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:741` | `CupertinoActionSheetAction` | expr:'自动补全 ${_autoComplete ? '✓' : ''}' | `onPressed=closure` |
| 376 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:749` | `CupertinoActionSheetAction` | 复制书源 | `onPressed=closure` |
| 377 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:756` | `CupertinoActionSheetAction` | 粘贴书源 | `onPressed=closure` |
| 378 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:763` | `CupertinoActionSheetAction` | 设置源变量 | `onPressed=closure` |
| 379 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:770` | `CupertinoActionSheetAction` | 扫码导入 | `onPressed=closure` |
| 380 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:777` | `CupertinoActionSheetAction` | 分享二维码 | `onPressed=closure` |
| 381 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:784` | `CupertinoActionSheetAction` | 分享文本 | `onPressed=closure` |
| 382 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:791` | `CupertinoActionSheetAction` | 帮助 | `onPressed=closure` |
| 383 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:799` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 384 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:824` | `CupertinoActionSheetAction` | 插入URL参数 | `onPressed=closure` |
| 385 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:831` | `CupertinoActionSheetAction` | 书源教程 | `onPressed=closure` |
| 386 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:838` | `CupertinoActionSheetAction` | js教程 | `onPressed=closure` |
| 387 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:845` | `CupertinoActionSheetAction` | 正则教程 | `onPressed=closure` |
| 388 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:852` | `CupertinoActionSheetAction` | expr:onGroupField ? '插入分组' : '选择文件' | `onPressed=closure` |
| 389 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:864` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 390 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:900` | `CupertinoButton` | 取消 | `onPressed=closure=>` |
| 391 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:913` | `CupertinoButton` | 插入 | `onPressed=closure` |
| 392 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:1055` | `CupertinoActionSheetAction` | expr:group | `onPressed=closure=>` |
| 393 | `source` | `features/source/views/source_edit_legacy_view` | `lib/features/source/views/source_edit_legacy_view.dart:1060` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 394 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:459` | `CupertinoButton` | 保存 | `onPressed=_save` |
| 395 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:465` | `CupertinoButton` | - | `onPressed=_showMore` |
| 396 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:618` | `CupertinoListTile` | chapterName 预览 | `onTap=_previewChapterName` |
| 397 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:637` | `CupertinoListTile` | chapterUrl 预览 | `onTap=_previewChapterUrl` |
| 398 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:656` | `CupertinoListTile` | content 预览 | `onTap=_debugContentResult` |
| 399 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:683` | `CupertinoListTile` | 测试搜索规则 | `onTap=_runQuickSearchRuleTest` |
| 400 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:689` | `CupertinoListTile` | 测试正文规则 | `onTap=_runQuickContentRuleTest` |
| 401 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:703` | `CupertinoListTile` | 规则体检（Lint） | `onTap=_runRuleLint` |
| 402 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:709` | `CupertinoListTile` | 同步到 JSON | `onTap=closure=>` |
| 403 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:715` | `CupertinoListTile` | 从 JSON 解析 | `onTap=_syncJsonToFields` |
| 404 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:745` | `CupertinoListTile` | 启用 | `onChanged=closure=>` |
| 405 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:752` | `CupertinoListTile` | 启用发现 | `onChanged=closure=>` |
| 406 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:769` | `CupertinoListTile` | CookieJar | `onChanged=closure=>` |
| 407 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:825` | `CupertinoListTile` | 加载登录态缓存 | `onTap=_loginStateLoading` |
| 408 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:833` | `CupertinoListTile` | 保存登录态缓存 | `onTap=_loginStateLoading` |
| 409 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:839` | `CupertinoListTile` | 清除登录态缓存 | `onTap=_loginStateLoading` |
| 410 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:888` | `CupertinoListTile` | 同步到 JSON | `onTap=closure=>` |
| 411 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:894` | `CupertinoListTile` | 从 JSON 解析 | `onTap=_syncJsonToFields` |
| 412 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:961` | `CupertinoButton` | 格式化 | `onPressed=_formatJson` |
| 413 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:969` | `CupertinoButton` | 校验 | `onPressed=_validateJson` |
| 414 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1157` | `CupertinoListTile` | Key | `onChanged=closure=>` |
| 415 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1174` | `ShadButton` | expr:_debugLoading ? '调试运行中…' : '开始调试' | `onPressed=_debugLoading` |
| 416 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1202` | `CupertinoListTile` | expr:Text(quickToggleTitle | `onTap=closure` |
| 417 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1213` | `CupertinoListTile` | 菜单 | `onTap=_showDebugLegacyMenuSheet` |
| 418 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1221` | `CupertinoListTile` | 高级工具 | `onTap=_showDebugMoreToolsSheet` |
| 419 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1227` | `CupertinoListTile` | 复制控制台（全部） | `onTap=hasLogs` |
| 420 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1233` | `CupertinoListTile` | 一键导出调试包（推荐） | `onTap=hasLogs` |
| 421 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1321` | `CupertinoActionSheetAction` | 扫码填充 Key | `onPressed=closure=>` |
| 422 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1331` | `CupertinoActionSheetAction` | 查看搜索源码 | `onPressed=closure=>` |
| 423 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1337` | `CupertinoActionSheetAction` | 查看详情源码 | `onPressed=closure=>` |
| 424 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1343` | `CupertinoActionSheetAction` | 查看目录源码 | `onPressed=closure=>` |
| 425 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1349` | `CupertinoActionSheetAction` | 查看正文源码 | `onPressed=closure=>` |
| 426 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1355` | `CupertinoActionSheetAction` | 刷新发现快捷项 | `onPressed=closure=>` |
| 427 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1365` | `CupertinoActionSheetAction` | 调试帮助 | `onPressed=closure=>` |
| 428 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1372` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 429 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1397` | `CupertinoActionSheetAction` | 网页验证（Cloudflare） | `onPressed=closure=>` |
| 430 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1401` | `CupertinoActionSheetAction` | 高级诊断与源码 | `onPressed=closure=>` |
| 431 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1407` | `CupertinoActionSheetAction` | 结构化调试摘要 | `onPressed=closure=>` |
| 432 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1418` | `CupertinoActionSheetAction` | 复制调试摘要（脱敏） | `onPressed=closure=>` |
| 433 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1430` | `CupertinoActionSheetAction` | 一键导出调试包（推荐） | `onPressed=closure=>` |
| 434 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1440` | `CupertinoActionSheetAction` | 导出调试包（更多选项） | `onPressed=closure=>` |
| 435 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1450` | `CupertinoActionSheetAction` | 运行时变量快照（脱敏） | `onPressed=closure=>` |
| 436 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1461` | `CupertinoActionSheetAction` | 复制变量快照（脱敏） | `onPressed=closure=>` |
| 437 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1473` | `CupertinoActionSheetAction` | 复制控制台（全部） | `onPressed=closure=>` |
| 438 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1477` | `CupertinoActionSheetAction` | 复制最小复现信息 | `onPressed=closure=>` |
| 439 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1481` | `CupertinoActionSheetAction` | 清空控制台 | `onPressed=closure=>` |
| 440 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1487` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 441 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1706` | `CupertinoActionSheetAction` | expr:entry.value | `onPressed=closure` |
| 442 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:1715` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 443 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2024` | `CupertinoListTile` | 结构化调试摘要 | `onTap=structuredSummaryText` |
| 444 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2036` | `CupertinoListTile` | 复制调试摘要（脱敏） | `onTap=structuredSummaryText` |
| 445 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2048` | `CupertinoListTile` | 列表页源码 | `onTap=listHtml` |
| 446 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2057` | `CupertinoListTile` | 详情页源码 | `onTap=bookHtml` |
| 447 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2066` | `CupertinoListTile` | 目录页源码 | `onTap=tocHtml` |
| 448 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2074` | `CupertinoListTile` | 正文页源码 | `onTap=contentHtml` |
| 449 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2083` | `CupertinoListTile` | 正文结果 | `onTap=contentResult` |
| 450 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2093` | `CupertinoListTile` | 运行时变量快照（脱敏） | `onTap=_debugRuntimeVarsSnapshot.isEmpty` |
| 451 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2107` | `CupertinoListTile` | 复制变量快照（脱敏） | `onTap=_debugRuntimeVarsSnapshot.isEmpty` |
| 452 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2150` | `CupertinoListTile` | expr:'总 $totalLines 行 · 展示 ${visibleLines.length} 行' | `-` |
| 453 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2157` | `CupertinoListTile` | 最近错误 | `onPressed=_copyMinimalReproInfo` |
| 454 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2185` | `CupertinoListTile` | expr:'当前展示最近 ${visibleLines.length} 行' | `-` |
| 455 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2193` | `CupertinoListTile` | 暂无日志 | `-` |
| 456 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2211` | `CupertinoListTile` | 日志上下文 | `onPressed=closure` |
| 457 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2502` | `CupertinoListTile` | 诊断标签（结构化） | `onTap=hasLogs` |
| 458 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2541` | `CupertinoListTile` | 定位建议 | `onTap=hasLogs` |
| 459 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2613` | `CupertinoActionSheetAction` | 复制调试包（不含源码，推荐） | `onPressed=closure` |
| 460 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2623` | `CupertinoActionSheetAction` | 保存调试包到文件（不含源码，推荐） | `onPressed=closure_async` |
| 461 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2630` | `CupertinoActionSheetAction` | 保存调试包到文件（含源码） | `onPressed=closure_async` |
| 462 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:2638` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 463 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:3037` | `CupertinoListTile` | expr:Text(title | `-` |
| 464 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:3053` | `CupertinoActionSheetAction` | 清 Cookie | `onPressed=closure` |
| 465 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:3060` | `CupertinoActionSheetAction` | 复制 JSON | `onPressed=closure` |
| 466 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:3068` | `CupertinoActionSheetAction` | 从剪贴板粘贴 JSON | `onPressed=closure` |
| 467 | `source` | `features/source/views/source_edit_view` | `lib/features/source/views/source_edit_view.dart:3076` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 468 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:183` | `CupertinoButton` | - | `onPressed=_showSortOptions` |
| 469 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:189` | `CupertinoButton` | - | `onPressed=_showGroupFilterOptions` |
| 470 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:195` | `CupertinoButton` | - | `onPressed=_showMainOptions` |
| 471 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:366` | `CupertinoButton` | expr:snapshot.stopRequested ? '停止中' : '停止' | `onPressed=snapshot.stopRequested` |
| 472 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:592` | `CupertinoButton` | - | `onPressed=closure` |
| 473 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:690` | `CupertinoButton` | - | `onPressed=closure=>` |
| 474 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:700` | `CupertinoButton` | - | `onPressed=closure=>` |
| 475 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:879` | `CupertinoButton` | - | `onPressed=totalCount` |
| 476 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:895` | `CupertinoButton` | 反选 | `onPressed=hasSelection` |
| 477 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:907` | `CupertinoButton` | 删除 | `onPressed=hasSelection` |
| 478 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:923` | `CupertinoButton` | - | `onPressed=hasSelection` |
| 479 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:947` | `CupertinoActionSheetAction` | 启用所选 | `onPressed=closure` |
| 480 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:954` | `CupertinoActionSheetAction` | 禁用所选 | `onPressed=closure` |
| 481 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:961` | `CupertinoActionSheetAction` | 加入分组 | `onPressed=closure` |
| 482 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:968` | `CupertinoActionSheetAction` | 移除分组 | `onPressed=closure` |
| 483 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:975` | `CupertinoActionSheetAction` | 启用发现 | `onPressed=closure` |
| 484 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:982` | `CupertinoActionSheetAction` | 禁用发现 | `onPressed=closure` |
| 485 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:989` | `CupertinoActionSheetAction` | 置顶 | `onPressed=closure` |
| 486 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:996` | `CupertinoActionSheetAction` | 置底 | `onPressed=closure` |
| 487 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1003` | `CupertinoActionSheetAction` | 导出所选 | `onPressed=closure` |
| 488 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1010` | `CupertinoActionSheetAction` | 分享所选 | `onPressed=closure` |
| 489 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1017` | `CupertinoActionSheetAction` | 校验所选 | `onPressed=closure` |
| 490 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1024` | `CupertinoActionSheetAction` | 选中所选区间 | `onPressed=closure` |
| 491 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1032` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 492 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1071` | `CupertinoActionSheetAction` | 新建书源 | `onPressed=closure` |
| 493 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1078` | `CupertinoActionSheetAction` | 从文件导入 | `onPressed=closure` |
| 494 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1085` | `CupertinoActionSheetAction` | 从网络导入 | `onPressed=closure` |
| 495 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1092` | `CupertinoActionSheetAction` | 扫码导入 | `onPressed=closure` |
| 496 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1099` | `CupertinoActionSheetAction` | expr:_groupSourcesByDomain ? '关闭按域名分组' : '按域名分组' | `onPressed=closure` |
| 497 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1106` | `CupertinoActionSheetAction` | 帮助 | `onPressed=closure` |
| 498 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1114` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 499 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1133` | `CupertinoActionSheetAction` | expr:'${_sortMode == _SourceSortMode.manual ? '✓ ' : ''}手动排序' | `onPressed=closure=>` |
| 500 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1138` | `CupertinoActionSheetAction` | expr:'${_sortMode == _SourceSortMode.weight ? '✓ ' : ''}权重' | `onPressed=closure=>` |
| 501 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1142` | `CupertinoActionSheetAction` | expr:'${_sortMode == _SourceSortMode.name ? '✓ ' : ''}名称' | `onPressed=closure=>` |
| 502 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1146` | `CupertinoActionSheetAction` | expr:'${_sortMode == _SourceSortMode.url ? '✓ ' : ''}地址' | `onPressed=closure=>` |
| 503 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1150` | `CupertinoActionSheetAction` | expr:'${_sortMode == _SourceSortMode.update ? '✓ ' : ''}更新时间' | `onPressed=closure=>` |
| 504 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1155` | `CupertinoActionSheetAction` | expr:'${_sortMode == _SourceSortMode.respond ? '✓ ' : ''}响应时间' | `onPressed=closure=>` |
| 505 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1160` | `CupertinoActionSheetAction` | expr:'${_sortMode == _SourceSortMode.enabled ? '✓ ' : ''}启用状态' | `onPressed=closure=>` |
| 506 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1165` | `CupertinoActionSheetAction` | expr:_sortAscending ? '切换为降序' : '切换为升序' | `onPressed=closure` |
| 507 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1173` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 508 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1188` | `CupertinoActionSheetAction` | 分组管理 | `onPressed=closure` |
| 509 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1195` | `CupertinoActionSheetAction` | 启用 | `onPressed=closure=>` |
| 510 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1199` | `CupertinoActionSheetAction` | 禁用 | `onPressed=closure=>` |
| 511 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1203` | `CupertinoActionSheetAction` | 需登录 | `onPressed=closure=>` |
| 512 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1207` | `CupertinoActionSheetAction` | 无分组 | `onPressed=closure=>` |
| 513 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1211` | `CupertinoActionSheetAction` | 启用发现 | `onPressed=closure=>` |
| 514 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1215` | `CupertinoActionSheetAction` | 禁用发现 | `onPressed=closure=>` |
| 515 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1220` | `CupertinoActionSheetAction` | expr:group | `onPressed=closure=>` |
| 516 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1226` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 517 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1265` | `CupertinoButton` | - | `onPressed=closure_async` |
| 518 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1275` | `CupertinoButton` | - | `onPressed=closure=>` |
| 519 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1327` | `CupertinoButton` | 编辑 | `onPressed=closure_async` |
| 520 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1341` | `CupertinoButton` | 删除 | `onPressed=closure_async` |
| 521 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1379` | `CupertinoActionSheetAction` | 置顶 | `onPressed=closure` |
| 522 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1387` | `CupertinoActionSheetAction` | 置底 | `onPressed=closure` |
| 523 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1395` | `CupertinoActionSheetAction` | 登录 | `onPressed=closure` |
| 524 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1402` | `CupertinoActionSheetAction` | 搜索 | `onPressed=closure_async` |
| 525 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1416` | `CupertinoActionSheetAction` | 调试 | `onPressed=closure` |
| 526 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1426` | `CupertinoActionSheetAction` | 删除 | `onPressed=closure` |
| 527 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1435` | `CupertinoActionSheetAction` | expr:source.enabledExplore ? '禁用发现' : '启用发现' | `onPressed=closure_async` |
| 528 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:1445` | `CupertinoActionSheetAction` | 取消 | `onPressed=closure=>` |
| 529 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:2028` | `CupertinoButton` | expr:group | `onPressed=closure` |
| 530 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:2524` | `CupertinoButton` | 取消 | `onPressed=closure=>` |
| 531 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:2543` | `CupertinoButton` | 导入 | `onPressed=closure` |
| 532 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:2612` | `CupertinoButton` | - | `onPressed=closure_async` |
| 533 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:2765` | `CupertinoButton` | 取消 | `onPressed=closure=>` |
| 534 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:2771` | `CupertinoButton` | 导入($selectedCount) | `onPressed=selectedCount` |
| 535 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:2825` | `CupertinoButton` | - | `onPressed=closure` |
| 536 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:2856` | `CupertinoButton` | 选择新增 | `onPressed=closure` |
| 537 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:2886` | `CupertinoButton` | 选择更新 | `onPressed=closure` |
| 538 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:2962` | `CupertinoButton` | expr:appendCustomGroup ? '追加' : '覆盖' | `onPressed=closure` |
| 539 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:3065` | `CupertinoButton` | 打开 | `onPressed=closure_async` |
| 540 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:3167` | `CupertinoButton` | 取消 | `onPressed=closure=>` |
| 541 | `source` | `features/source/views/source_list_view` | `lib/features/source/views/source_list_view.dart:3184` | `CupertinoButton` | 保存 | `onPressed=closure=>` |
| 542 | `source` | `features/source/views/source_login_form_view` | `lib/features/source/views/source_login_form_view.dart:171` | `CupertinoButton` | expr:row.name | `onPressed=closure=>` |
| 543 | `source` | `features/source/views/source_login_form_view` | `lib/features/source/views/source_login_form_view.dart:193` | `CupertinoButton` | 完成 | `onPressed=_loading` |
| 544 | `source` | `features/source/views/source_qr_share_view` | `lib/features/source/views/source_qr_share_view.dart:29` | `CupertinoButton` | 分享 | `onPressed=closure_async` |
| 545 | `source` | `features/source/views/source_web_verify_view` | `lib/features/source/views/source_web_verify_view.dart:148` | `CupertinoButton` | 操作 | `onPressed=closure=>` |
| 546 | `app` | `main` | `lib/main.dart:545` | `CupertinoButton` | expr:retrying ? '重试中…' : '重试初始化' | `onPressed=retrying` |
