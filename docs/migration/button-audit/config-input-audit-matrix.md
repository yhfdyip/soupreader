# 配置与输入核对矩阵（T05A）

- 任务状态：`done`
- 对应计划：`PLANS.md` / `T05A`
- 产出日期：`2026-02-20`
- 口径：按 legado 配置语义做字段级对照，覆盖默认值、输入校验、保存/取消路径与异常可见性。

## 1. 抽样范围与方法

- 抽样条目：`22`（>= 20）
- 覆盖模块：主入口、书架、发现、RSS、书源编辑、阅读设置
- 核验方式：
  - 静态对照：legacy 与 soupreader 代码逐项映射
  - 命令证据：`flutter test test/widget_test.dart`、`flutter test test/bookshelf_view_compile_test.dart`
  - 手工路径：记录于本文第 3 节（M1 / I1 / I2）

## 2. 字段级矩阵（22 条）

| # | legacy 位置（字段） | soupreader 位置（字段） | 默认值对照 | 校验/边界 | 保存/取消语义 | 当前判定 |
|---|---|---|---|---|---|---|
| 1 | `../legado/app/src/main/res/xml/pref_config_other.xml:35` `showDiscovery` | `lib/core/models/app_settings.dart:50` `showDiscovery` + `lib/main.dart:414` | 均默认 `true` | 布尔开关 | 设置变更后重建底栏；取消保持原值 | 已同义 |
| 2 | `../legado/app/src/main/res/xml/pref_config_other.xml:41` `showRss` | `lib/core/models/app_settings.dart:51` `showRss` + `lib/main.dart:423` | 均默认 `true` | 布尔开关 | 设置变更后重建底栏；取消保持原值 | 已同义 |
| 3 | `../legado/app/src/main/res/xml/pref_config_other.xml:47` `defaultHomePage` | `lib/core/models/app_settings.dart:52` + `lib/main.dart:443` | 均默认书架 | 仅允许枚举值 | 保存后下次启动生效；取消不改动 | 已同义 |
| 4 | `../legado/app/src/main/java/io/legado/app/ui/main/bookshelf/BaseBookshelfFragment.kt:168` `bookshelfLayout` | `lib/core/models/app_settings.dart:54` + `lib/features/settings/views/other_settings_view.dart:73` | 均默认图墙 | 仅允许布局枚举 | 保存即持久化；取消保持原值 | 已同义 |
| 5 | `../legado/app/src/main/java/io/legado/app/ui/main/bookshelf/BaseBookshelfFragment.kt:169` `bookshelfSort` | `lib/core/models/app_settings.dart:55` + `lib/features/settings/views/other_settings_view.dart:119` | 均默认最近阅读 | 仅允许排序枚举 | 保存即持久化；取消保持原值 | 已同义 |
| 6 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt:152` `group:` 查询 | `lib/features/discovery/views/discovery_view.dart:163` `_setQuery('group:$group')` | 无默认组 | 空组弹提示 | 选择组后立即筛选；取消关闭弹层 | 已同义 |
| 7 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt:187` 分组菜单点击 | `lib/features/discovery/views/discovery_view.dart:146` `_showGroupFilterMenu()` | 无 | 分组为空提示“当前没有可用分组” | 取消按钮关闭，不改查询 | 已同义 |
| 8 | `../legado/app/src/main/java/io/legado/app/ui/main/rss/RssFragment.kt:92` `group:` 查询 | `lib/features/rss/views/rss_subscription_view.dart:233` `_openGroupFilterSheet()` | 无默认组 | 空组提示 | 选择后刷新筛选，取消仅关闭 | 已同义 |
| 9 | `../legado/app/src/main/java/io/legado/app/ui/rss/source/manage/RssSourceActivity.kt:140-153` 快速筛选 | `lib/features/rss/views/rss_source_manage_view.dart:226` `_openQuickFilterSheet()` | 默认“全部” | 关键词分支（启用/禁用/未分组/group） | 选择即应用筛选，取消关闭 | 已同义 |
| 10 | `../legado/app/src/main/java/io/legado/app/ui/rss/source/manage/RssSourceActivity.kt:138` 分组管理 | `lib/features/rss/views/rss_group_manage_view.dart:32` | 无默认 | 分组名非空 | 新增/编辑/删除后即时刷新，取消不改 | 已同义 |
| 11 | `../legado/app/src/main/java/io/legado/app/ui/book/source/edit/BookSourceEditActivity.kt:264` `bookSourceUrl` | `lib/features/source/views/source_edit_legacy_view.dart:496,1526` | legacy 可空占位，新端默认空串 | 非空且 URL 合法（含提示） | 保存失败会提示并阻断；取消返回 | 已同义 |
| 12 | `../legado/app/src/main/java/io/legado/app/ui/book/source/edit/BookSourceEditActivity.kt:265` `bookSourceName` | `lib/features/source/views/source_edit_legacy_view.dart:497,1527` | 默认空 | 名称缺失时按 legacy 语义处理显示名 | 保存写回模型；取消不提交 | 已同义 |
| 13 | `../legado/app/src/main/java/io/legado/app/ui/book/source/edit/BookSourceEditActivity.kt:266` `bookSourceGroup` | `lib/features/source/views/source_edit_legacy_view.dart:498,1528` | 默认空 | 支持多分组文本输入 | 保存写回；取消不落库 | 已同义 |
| 14 | `../legado/app/src/main/java/io/legado/app/ui/book/source/edit/BookSourceEditActivity.kt:267` `bookSourceComment` | `lib/features/source/views/source_edit_legacy_view.dart:499,1529` | 默认空 | 可空文本 | 保存写回；取消不落库 | 已同义 |
| 15 | `../legado/app/src/main/java/io/legado/app/ui/book/source/edit/BookSourceEditActivity.kt:268` `loginUrl` | `lib/features/source/views/source_edit_legacy_view.dart:501,1530` | 默认空 | 可空 URL | 保存写回；取消不落库 | 已同义 |
| 16 | `../legado/app/src/main/res/layout/activity_book_source_edit.xml:45` `cb_is_enable` | `lib/features/source/views/source_edit_legacy_view.dart:441` 启用书源 | 默认启用 | 布尔开关 | 保存时统一提交；取消不提交 | 已同义 |
| 17 | `../legado/app/src/main/res/layout/activity_book_source_edit.xml:52` `cb_is_enable_explore` | `lib/features/source/views/source_edit_legacy_view.dart:448,1542` | 默认启用发现 | 布尔开关 | 保存时写入 `enabledExplore` | 已同义 |
| 18 | `../legado/app/src/main/res/layout/activity_book_source_edit.xml:59` `cb_is_enable_cookie` | `lib/features/source/views/source_edit_legacy_view.dart:453,1543` | legacy 默认为 `false` | 布尔开关 | 保存时写入 `enabledCookieJar` | 已同义 |
| 19 | `../legado/app/src/main/res/xml/pref_config_read.xml:25` `hideStatusBar` | `lib/features/reader/models/reading_settings.dart:16` + `lib/features/settings/views/reading_status_action_settings_view.dart:47` `showStatusBar` | 语义做了反向映射，默认显示状态栏 | 布尔开关 | 变更即持久化；取消不改 | 已同义 |
| 20 | `../legado/app/src/main/res/xml/pref_config_read.xml:32` `hideNavigationBar` | `lib/features/reader/models/reading_settings.dart:17` + `lib/features/settings/views/reading_status_action_settings_view.dart:55` | 均默认不隐藏 | 布尔开关 | 变更即持久化；取消不改 | 已同义 |
| 21 | `../legado/app/src/main/res/xml/pref_config_read.xml:64` `progressBarBehavior` | `lib/features/reader/models/reading_settings.dart:29` | 默认按页模式 | 枚举值限制 | 保存后在阅读器生效 | 已同义 |
| 22 | `../legado/app/src/main/res/xml/pref_config_read.xml:78,92,99,168` `textFullJustify/mouseWheelPage/volumeKeyPage/clickRegionalConfig` | `lib/features/reader/models/reading_settings.dart:39,62,63,64,52` + `lib/features/settings/views/reading_preferences_view.dart:342` + `lib/features/settings/views/reading_page_settings_view.dart:64` + `lib/features/settings/views/reading_status_action_settings_view.dart:110` | 默认值与 legacy 一致 | 开关与点击区域配置均有限定结构 | 变更即持久化；取消返回前不提交 | 已同义 |

## 3. 抽样回归路径（输入类）

### I1：主入口与书架输入

1. 打开设置 -> 其它设置，切换“默认首页/书架布局/书架排序”。
2. 返回主入口确认底栏初始页与书架展示模式变化。
3. 取消弹窗时确认当前配置不变。

### I2：书源编辑输入

1. 打开书源编辑页，修改 `bookSourceUrl/bookSourceName/bookSourceGroup/loginUrl`。
2. 输入非法 URL，确认提示并阻断保存。
3. 点击保存后重新进入页面确认数据持久化；点击返回取消时确认未写入。

### I3：阅读设置输入

1. 打开阅读设置，依次切换“状态栏/导航栏/两端对齐/音量键翻页/鼠标滚轮翻页”。
2. 打开点击区域配置并修改任意分区动作。
3. 返回阅读器确认行为变化；不保存退出时保持旧值。

## 4. 结论

- T05A 交付物已补齐：形成 22 条配置/输入矩阵，并覆盖默认值、校验、保存/取消语义。
- 后续在 `T16A` 将补充“运行时状态流转截图/日志对照”，作为交互逻辑最终验收证据。
