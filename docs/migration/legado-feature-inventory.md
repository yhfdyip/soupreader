# legado 功能清单（全量入口版）

- 文档状态：`active`
- 生成日期：2026-02-21
- 数据口径：`res/menu` 可观测入口（Toolbar/Menu/ActionSheet/上下文菜单）
- 数据来源：`../legado/app/src/main/res/menu/*.xml` + `docs/migration/button-audit/button-mapping.csv`
- 统计快照：90 个菜单文件，410 个功能入口

## 范围与说明

- 本清单以 legado 菜单入口为“功能可达性”主数据源，适用于迁移对照、遗漏排查与回归抽样。
- 清单中的“功能名称”取自 legado 字符串语义（`legacy_title_zh`）。
- 若需查看更底层属性（`showAsAction/visible/checkable`），请结合 `docs/migration/button-audit/legacy-button-ledger.md`。
- 本文档不替代运行时状态机说明；动态行为以各模块对照清单与 ExecPlan 为准。

## 功能域汇总（按菜单文件映射）

| 功能域 | 菜单文件数 | 功能入口数 | 说明 |
|---|---:|---:|---|
| 阅读与朗读 | 14 | 89 | 正文、目录内操作、朗读与编辑 |
| 书源管理与换源 | 12 | 85 | 书源列表、调试、订阅、登录 |
| RSS | 9 | 47 | RSS 源、文章、收藏、阅读记录 |
| 规则与净化 | 11 | 46 | 替换规则、字典规则、TXT 目录规则 |
| 搜索/详情/目录 | 7 | 38 | 搜索范围、书籍详情、目录管理 |
| 书架/缓存/分组 | 7 | 31 | 分组、缓存、书签、阅读记录 |
| 导入导出与备份 | 12 | 27 | 导入、备份恢复、文件操作 |
| 系统与工具 | 11 | 24 | 关于、日志、更新、扫码、Web |
| 主入口与导航 | 5 | 21 | 底栏与四 Tab 顶部菜单 |
| 主题与外观 | 2 | 2 | 主题配置与主题列表 |

## 菜单文件索引（90 文件）

| 菜单文件 | 功能域 | 入口数 |
|---|---|---:|
| `about.xml` | 系统与工具 | 2 |
| `app_log.xml` | 系统与工具 | 1 |
| `app_update.xml` | 系统与工具 | 1 |
| `audio_play.xml` | 阅读与朗读 | 6 |
| `backup_restore.xml` | 导入导出与备份 | 2 |
| `book_cache.xml` | 书架/缓存/分组 | 14 |
| `book_cache_download.xml` | 书架/缓存/分组 | 2 |
| `book_group_manage.xml` | 书架/缓存/分组 | 1 |
| `book_info.xml` | 搜索/详情/目录 | 15 |
| `book_info_edit.xml` | 搜索/详情/目录 | 1 |
| `book_manga.xml` | 阅读与朗读 | 18 |
| `book_read.xml` | 阅读与朗读 | 23 |
| `book_read_change_source.xml` | 阅读与朗读 | 2 |
| `book_read_record.xml` | 阅读与朗读 | 5 |
| `book_read_refresh.xml` | 阅读与朗读 | 3 |
| `book_read_source.xml` | 阅读与朗读 | 4 |
| `book_remote.xml` | 搜索/详情/目录 | 7 |
| `book_search.xml` | 搜索/详情/目录 | 4 |
| `book_search_scope.xml` | 搜索/详情/目录 | 1 |
| `book_source.xml` | 书源管理与换源 | 23 |
| `book_source_debug.xml` | 书源管理与换源 | 7 |
| `book_source_item.xml` | 书源管理与换源 | 7 |
| `book_source_sel.xml` | 书源管理与换源 | 12 |
| `book_toc.xml` | 搜索/详情/目录 | 9 |
| `bookmark.xml` | 书架/缓存/分组 | 2 |
| `bookshelf_manage.xml` | 书架/缓存/分组 | 4 |
| `bookshelf_menage_sel.xml` | 书架/缓存/分组 | 7 |
| `change_cover.xml` | 系统与工具 | 1 |
| `change_source.xml` | 书源管理与换源 | 10 |
| `change_source_item.xml` | 书源管理与换源 | 5 |
| `code_edit.xml` | 系统与工具 | 1 |
| `content_edit.xml` | 阅读与朗读 | 3 |
| `content_search.xml` | 阅读与朗读 | 1 |
| `content_select_action.xml` | 阅读与朗读 | 8 |
| `crash_log.xml` | 系统与工具 | 1 |
| `dialog_text.xml` | 系统与工具 | 1 |
| `dict_rule.xml` | 规则与净化 | 6 |
| `dict_rule_edit.xml` | 规则与净化 | 3 |
| `dict_rule_sel.xml` | 规则与净化 | 3 |
| `direct_link_upload_config.xml` | 导入导出与备份 | 3 |
| `explore_item.xml` | 系统与工具 | 6 |
| `file_chooser.xml` | 导入导出与备份 | 1 |
| `file_long_click.xml` | 导入导出与备份 | 1 |
| `font_select.xml` | 阅读与朗读 | 2 |
| `group_manage.xml` | 书架/缓存/分组 | 1 |
| `import_book.xml` | 导入导出与备份 | 7 |
| `import_book_sel.xml` | 导入导出与备份 | 1 |
| `import_replace.xml` | 导入导出与备份 | 1 |
| `import_source.xml` | 导入导出与备份 | 6 |
| `keyboard_assists_config.xml` | 阅读与朗读 | 1 |
| `main_bnv.xml` | 主入口与导航 | 4 |
| `main_bookshelf.xml` | 主入口与导航 | 12 |
| `main_explore.xml` | 主入口与导航 | 1 |
| `main_my.xml` | 主入口与导航 | 1 |
| `main_rss.xml` | 主入口与导航 | 3 |
| `open_url_confirm.xml` | 导入导出与备份 | 2 |
| `qr_code_scan.xml` | 系统与工具 | 1 |
| `replace_edit.xml` | 规则与净化 | 3 |
| `replace_rule.xml` | 规则与净化 | 8 |
| `replace_rule_item.xml` | 规则与净化 | 3 |
| `replace_rule_sel.xml` | 规则与净化 | 5 |
| `rss_articles.xml` | RSS | 7 |
| `rss_favorites.xml` | RSS | 3 |
| `rss_main_item.xml` | RSS | 4 |
| `rss_read.xml` | RSS | 6 |
| `rss_read_record.xml` | RSS | 1 |
| `rss_source.xml` | RSS | 12 |
| `rss_source_debug.xml` | RSS | 2 |
| `rss_source_item.xml` | RSS | 3 |
| `rss_source_sel.xml` | RSS | 9 |
| `save.xml` | 导入导出与备份 | 1 |
| `search_view.xml` | 搜索/详情/目录 | 1 |
| `server_config.xml` | 导入导出与备份 | 1 |
| `servers.xml` | 导入导出与备份 | 1 |
| `source_edit.xml` | 书源管理与换源 | 13 |
| `source_login.xml` | 书源管理与换源 | 4 |
| `source_picker.xml` | 书源管理与换源 | 1 |
| `source_sub_item.xml` | 书源管理与换源 | 1 |
| `source_subscription.xml` | 书源管理与换源 | 1 |
| `source_webview_login.xml` | 书源管理与换源 | 1 |
| `speak_engine.xml` | 阅读与朗读 | 5 |
| `speak_engine_edit.xml` | 阅读与朗读 | 8 |
| `theme_config.xml` | 主题与外观 | 1 |
| `theme_list.xml` | 主题与外观 | 1 |
| `txt_toc_rule.xml` | 规则与净化 | 6 |
| `txt_toc_rule_edit.xml` | 规则与净化 | 3 |
| `txt_toc_rule_item.xml` | 规则与净化 | 3 |
| `txt_toc_rule_sel.xml` | 规则与净化 | 3 |
| `verification_code.xml` | 系统与工具 | 3 |
| `web_view.xml` | 系统与工具 | 6 |

## 全量功能清单（410 项，按菜单文件分组）

> 说明：以下条目按 legado 原始菜单顺序列出；字段格式为 `序号. item_id｜功能名称｜标题引用`。

### about.xml（2 项）

1. `@+id/menu_share_it`｜分享｜`@string/share`
2. `@+id/menu_scoring`｜评分｜`@string/scoring`

### app_log.xml（1 项）

3. `@+id/menu_clear`｜清除｜`@string/clear`

### app_update.xml（1 项）

4. `@+id/menu_download`｜下载｜`@string/action_download`

### audio_play.xml（6 项）

5. `@+id/menu_change_source`｜换源｜`@string/change_origin`
6. `@+id/menu_login`｜登录｜`@string/login`
7. `@+id/menu_copy_audio_url`｜拷贝播放 URL｜`@string/copy_play_url`
8. `@+id/menu_edit_source`｜编辑书源｜`@string/edit_book_source`
9. `@+id/menu_wake_lock`｜音频服务唤醒锁｜`@string/audio_play_wake_lock`
10. `@+id/menu_log`｜日志｜`@string/log`

### backup_restore.xml（2 项）

11. `@+id/menu_help`｜帮助｜`@string/help`
12. `@+id/menu_log`｜日志｜`@string/log`

### book_cache.xml（14 项）

13. `@+id/menu_download`｜下载｜`@string/action_download`
14. `@+id/menu_book_group`｜分组｜`@string/group`
15. `@+id/menu_export_all`｜导出所有｜`@string/export_all`
16. `@+id/menu_enable_replace`｜替换净化｜`@string/replace_purify`
17. `@+id/menu_enable_custom_export`｜自定义Epub导出章节｜`@string/custom_export_section`
18. `@+id/menu_export_web_dav`｜导出到 WebDav｜`@string/export_to_web_dav`
19. `@+id/menu_export_no_chapter_name`｜TXT 不导出章节名｜`@string/export_no_chapter_name`
20. `@+id/menu_export_pics_file`｜TXT 导出图片｜`@string/export_pics_file`
21. `@+id/menu_parallel_export`｜多线程导出｜`@string/parallel_export_book`
22. `@+id/menu_export_folder`｜导出文件夹｜`@string/export_folder`
23. `@+id/menu_export_file_name`｜导出文件名｜`@string/export_file_name`
24. `@+id/menu_export_type`｜导出格式｜`@string/export_type`
25. `@+id/menu_export_charset`｜导出编码｜`@string/export_charset`
26. `@+id/menu_log`｜日志｜`@string/log`

### book_cache_download.xml（2 项）

27. `@+id/menu_download_after`｜下载之后章节｜`@string/menu_download_after`
28. `@+id/menu_download_all`｜下载全部章节｜`@string/menu_download_all`

### book_group_manage.xml（1 项）

29. `@+id/menu_add`｜添加分组｜`@string/add_group`

### book_info.xml（15 项）

30. `@+id/menu_edit`｜编辑｜`@string/edit`
31. `@+id/menu_share_it`｜分享｜`@string/share`
32. `@+id/menu_upload`｜上传 WebDav｜`@string/upload_to_remote`
33. `@+id/menu_refresh`｜刷新｜`@string/refresh`
34. `@+id/menu_login`｜登录｜`@string/login`
35. `@+id/menu_top`｜置顶｜`@string/to_top`
36. `@+id/menu_set_source_variable`｜设置源变量｜`@string/set_source_variable`
37. `@+id/menu_set_book_variable`｜设置书籍变量｜`@string/set_book_variable`
38. `@+id/menu_copy_book_url`｜拷贝书籍 URL｜`@string/copy_book_url`
39. `@+id/menu_copy_toc_url`｜拷贝目录 URL｜`@string/copy_toc_url`
40. `@+id/menu_can_update`｜允许更新｜`@string/allow_update`
41. `@+id/menu_split_long_chapter`｜拆分超长章节｜`@string/split_long_chapter`
42. `@+id/menu_delete_alert`｜删除提醒｜`@string/delete_alert`
43. `@+id/menu_clear_cache`｜清理缓存｜`@string/clear_cache`
44. `@+id/menu_log`｜日志｜`@string/log`

### book_info_edit.xml（1 项）

45. `@+id/menu_save`｜保存｜`@string/action_save`

### book_manga.xml（18 项）

46. `@+id/menu_change_source`｜换源｜`@string/change_origin`
47. `@+id/menu_refresh`｜刷新｜`@string/refresh`
48. `@+id/menu_catalog`｜目录｜`@string/chapter_list`
49. `@+id/menu_pre_manga_number`｜预下载｜`@string/pre_download`
50. `@+id/menu_disable_manga_scale`｜禁用漫画缩放｜`@string/disable_manga_scale`
51. `@+id/menu_disable_click_scroll`｜禁用点击翻页｜`@string/disable_manga_click_scroll`
52. `@+id/menu_enable_auto_page`｜开启自动翻页｜`@string/enable_auto_page_scroll`
53. `@+id/menu_enable_auto_scroll`｜开启滚动｜`@string/enable_auto_scroll`
54. `@+id/menu_manga_auto_page_speed`｜翻页速度 %s｜`@string/manga_auto_page_speed`
55. `@+id/menu_enable_horizontal_scroll`｜水平滚动｜`@string/enable_manga_horizontal_scroll`
56. `@+id/menu_disable_horizontal_page_snap`｜禁用水平翻页效果｜`@string/disable_horizontal_page_snap`
57. `@+id/menu_disable_manga_page_anim`｜禁用翻页动画｜`@string/disable_manga_page_anim`
58. `@+id/menu_manga_footer_config`｜页脚配置｜`@string/manga_footer_config`
59. `@+id/menu_manga_color_filter`｜滤镜｜`@string/manga_color_filter`
60. `@+id/menu_hide_manga_title`｜隐藏漫画列表标题｜`@string/hide_manga_title`
61. `@+id/menu_epaper_manga`｜墨水屏｜`@string/manga_epaper`
62. `@+id/menu_epaper_manga_setting`｜墨水屏设置｜`@string/manga_epaper_stting`
63. `@+id/menu_gray_manga`｜开启图片灰色｜`@string/enable_manga_gray`

### book_read.xml（23 项）

64. `@+id/menu_change_source`｜换源｜`@string/change_origin`
65. `@+id/menu_refresh`｜刷新｜`@string/refresh`
66. `@+id/menu_download`｜离线缓存｜`@string/offline_cache`
67. `@+id/menu_toc_regex`｜TXT 目录规则｜`@string/txt_toc_rule`
68. `@+id/menu_set_charset`｜设置编码｜`@string/set_charset`
69. `@+id/menu_add_bookmark`｜添加书签｜`@string/bookmark_add`
70. `@+id/menu_edit_content`｜编辑内容｜`@string/edit_content`
71. `@+id/menu_page_anim`｜翻页动画（本书）｜`@string/book_page_anim`
72. `@+id/menu_get_progress`｜拉取云端进度｜`@string/get_book_progress`
73. `@+id/menu_cover_progress`｜覆盖云端进度｜`@string/cover_book_progress`
74. `@+id/menu_reverse_content`｜反转内容｜`@string/reverse_content`
75. `@+id/menu_simulated_reading`｜模拟追读｜`@string/simulated_reading`
76. `@+id/menu_enable_replace`｜替换净化｜`@string/replace_rule_title`
77. `@+id/menu_same_title_removed`｜移除重复标题｜`@string/same_title_removed`
78. `@+id/menu_re_segment`｜重新分段｜`@string/re_segment`
79. `@+id/menu_enable_review`｜段评｜`@string/review`
80. `@+id/menu_del_ruby_tag`｜删除ruby标签｜`@string/del_ruby_tag`
81. `@+id/menu_del_h_tag`｜删除h标签｜`@string/del_h_tag`
82. `@+id/menu_image_style`｜图片样式｜`@string/image_style`
83. `@+id/menu_update_toc`｜更新目录｜`@string/update_toc`
84. `@+id/menu_effective_replaces`｜起效的替换｜`@string/effective_replaces`
85. `@+id/menu_log`｜日志｜`@string/log`
86. `@+id/menu_help`｜帮助｜`@string/help`

### book_read_change_source.xml（2 项）

87. `@+id/menu_chapter_change_source`｜单章换源｜`@string/chapter_change_source`
88. `@+id/menu_book_change_source`｜整书换源｜`@string/book_change_source`

### book_read_record.xml（5 项）

89. `@+id/menu_sort`｜排序｜`@string/sort`
90. `@+id/menu_sort_name`｜名称排序｜`@string/sort_by_name`
91. `@+id/menu_sort_read_long`｜阅读时长排序｜`@string/reading_time_sort`
92. `@+id/menu_sort_read_time`｜阅读时间排序｜`@string/last_read_time_sort`
93. `@+id/menu_enable_record`｜开启记录｜`@string/enable_record`

### book_read_refresh.xml（3 项）

94. `@+id/menu_refresh_dur`｜刷新当前章节｜`@string/menu_refresh_dur`
95. `@+id/menu_refresh_after`｜刷新之后章节｜`@string/menu_refresh_after`
96. `@+id/menu_refresh_all`｜刷新全部章节｜`@string/menu_refresh_all`

### book_read_source.xml（4 项）

97. `@+id/menu_login`｜登录｜`@string/login`
98. `@+id/menu_chapter_pay`｜购买｜`@string/chapter_pay`
99. `@+id/menu_edit_source`｜编辑书源｜`@string/edit_book_source`
100. `@+id/menu_disable_source`｜禁用书源｜`@string/disable_book_source`

### book_remote.xml（7 项）

101. `@+id/menu_refresh`｜刷新｜`@string/refresh`
102. `@+id/menu_sort`｜排序｜`@string/sort`
103. `@+id/menu_sort_name`｜名称排序｜`@string/sort_by_name`
104. `@+id/menu_sort_time`｜更新时间排序｜`@string/sort_by_lastUpdateTime`
105. `@+id/menu_server_config`｜服务器配置｜`@string/server_config`
106. `@+id/menu_help`｜帮助｜`@string/help`
107. `@+id/menu_log`｜日志｜`@string/log`

### book_search.xml（4 项）

108. `@+id/menu_precision_search`｜精准搜索｜`@string/precision_search`
109. `@+id/menu_source_manage`｜书源管理｜`@string/book_source_manage`
110. `@+id/menu_search_scope`｜多分组/书源｜`@string/groups_or_source`
111. `@+id/menu_log`｜日志｜`@string/log`

### book_search_scope.xml（1 项）

112. `@+id/menu_screen`｜筛选｜`@string/screen`

### book_source.xml（23 项）

113. `@+id/action_sort`｜排序｜`@string/sort`
114. `@+id/menu_sort_desc`｜反序｜`@string/sort_desc`
115. `@+id/menu_sort_manual`｜手动排序｜`@string/sort_manual`
116. `@+id/menu_sort_auto`｜智能排序｜`@string/sort_auto`
117. `@+id/menu_sort_name`｜名称排序｜`@string/sort_by_name`
118. `@+id/menu_sort_url`｜地址排序｜`@string/sort_by_url`
119. `@+id/menu_sort_time`｜更新时间排序｜`@string/sort_by_lastUpdateTime`
120. `@+id/menu_sort_respondTime`｜响应时间排序｜`@string/sort_by_respondTime`
121. `@+id/menu_sort_enable`｜是否启用｜`@string/is_enabled`
122. `@+id/menu_group`｜分组｜`@string/menu_action_group`
123. `@+id/menu_group_manage`｜分组管理｜`@string/group_manage`
124. `@+id/menu_enabled_group`｜已启用｜`@string/enabled`
125. `@+id/menu_disabled_group`｜已禁用｜`@string/disabled`
126. `@+id/menu_group_login`｜需要登录｜`@string/need_login`
127. `@+id/menu_group_null`｜未分组｜`@string/no_group`
128. `@+id/menu_enabled_explore_group`｜已启用发现｜`@string/enabled_explore`
129. `@+id/menu_disabled_explore_group`｜已禁用发现｜`@string/disabled_explore`
130. `@+id/menu_add_book_source`｜新建书源｜`@string/add_book_source`
131. `@+id/menu_import_local`｜本地导入｜`@string/import_local`
132. `@+id/menu_import_onLine`｜网络导入｜`@string/import_on_line`
133. `@+id/menu_import_qr`｜二维码导入｜`@string/import_by_qr_code`
134. `@+id/menu_group_sources_by_domain`｜按域名分组显示｜`@string/group_sources_by_domain`
135. `@+id/menu_help`｜帮助｜`@string/help`

### book_source_debug.xml（7 项）

136. `@+id/menu_scan`｜扫描二维码｜`@string/scan_qr_code`
137. `@+id/menu_search_src`｜搜索源码｜`@string/search_src`
138. `@+id/menu_book_src`｜书籍源码｜`@string/boo_src`
139. `@+id/menu_toc_src`｜目录源码｜`@string/toc_src`
140. `@+id/menu_content_src`｜正文源码｜`@string/content_src`
141. `@+id/menu_refresh_explore`｜刷新发现｜`@string/refresh_explore`
142. `@+id/menu_help`｜帮助｜`@string/help`

### book_source_item.xml（7 项）

143. `@+id/menu_top`｜置顶｜`@string/to_top`
144. `@+id/menu_bottom`｜置底｜`@string/to_bottom`
145. `@+id/menu_login`｜登录｜`@string/login`
146. `@+id/menu_search`｜搜索｜`@string/search`
147. `@+id/menu_debug_source`｜调试｜`@string/debug`
148. `@+id/menu_del`｜删除｜`@string/delete`
149. `@+id/menu_enable_explore`｜启用发现｜`@string/enable_explore`

### book_source_sel.xml（12 项）

150. `@+id/menu_enable_selection`｜启用所选｜`@string/enable_selection`
151. `@+id/menu_disable_selection`｜禁用所选｜`@string/disable_selection`
152. `@+id/menu_add_group`｜添加分组｜`@string/add_group`
153. `@+id/menu_remove_group`｜移除分组｜`@string/remove_group`
154. `@+id/menu_enable_explore`｜启用发现｜`@string/enable_explore`
155. `@+id/menu_disable_explore`｜禁用发现｜`@string/disable_explore`
156. `@+id/menu_top_sel`｜置顶所选｜`@string/selection_to_top`
157. `@+id/menu_bottom_sel`｜置底所选｜`@string/selection_to_bottom`
158. `@+id/menu_export_selection`｜导出所选｜`@string/export_selection`
159. `@+id/menu_share_source`｜分享选中源｜`@string/share_selected_source`
160. `@+id/menu_check_source`｜校验所选｜`@string/check_select_source`
161. `@+id/menu_check_selected_interval`｜选中所选区间｜`@string/check_selected_interval`

### book_toc.xml（9 项）

162. `@+id/menu_search`｜搜索｜`@string/search`
163. `@+id/menu_toc_regex`｜TXT 目录规则｜`@string/txt_toc_rule`
164. `@+id/menu_split_long_chapter`｜拆分超长章节｜`@string/split_long_chapter`
165. `@+id/menu_reverse_toc`｜反转目录｜`@string/reverse_toc`
166. `@+id/menu_use_replace`｜使用替换｜`@string/use_replace`
167. `@+id/menu_load_word_count`｜加载字数｜`@string/load_word_count`
168. `@+id/menu_export_bookmark`｜导出｜`@string/export`
169. `@+id/menu_export_md`｜导出(MD)｜`@string/export_md`
170. `@+id/menu_log`｜日志｜`@string/log`

### bookmark.xml（2 项）

171. `@+id/menu_export`｜导出｜`@string/export`
172. `@+id/menu_export_md`｜导出(MD)｜`@string/export_md`

### bookshelf_manage.xml（4 项）

173. `@+id/menu_book_group`｜分组｜`@string/group`
174. `@+id/menu_group_manage`｜分组管理｜`@string/group_manage`
175. `@+id/menu_export_all_use_book_source`｜导出所有书的书源｜`@string/export_all_use_book_source`
176. `@+id/menu_open_book_info_by_click_title`｜点击书名打开详情｜`@string/open_book_info_by_click_title`

### bookshelf_menage_sel.xml（7 项）

177. `@+id/menu_del_selection`｜删除｜`@string/delete`
178. `@+id/menu_update_enable`｜允许更新｜`@string/allow_update`
179. `@+id/menu_update_disable`｜禁止更新｜`@string/disable_update`
180. `@+id/menu_add_to_group`｜加入分组｜`@string/add_to_group`
181. `@+id/menu_change_source`｜批量换源｜`@string/change_source_batch`
182. `@+id/menu_clear_cache`｜清理缓存｜`@string/clear_cache`
183. `@+id/menu_check_selected_interval`｜选中所选区间｜`@string/check_selected_interval`

### change_cover.xml（1 项）

184. `@+id/menu_start_stop`｜停止｜`@string/stop`

### change_source.xml（10 项）

185. `@+id/menu_screen`｜筛选｜`@string/screen`
186. `@+id/menu_start_stop`｜停止｜`@string/stop`
187. `@+id/menu_source_manage`｜书源管理｜`@string/book_source_manage`
188. `@+id/menu_refresh_list`｜刷新列表｜`@string/refresh_list`
189. `@+id/menu_check_author`｜校验作者｜`@string/checkAuthor`
190. `@+id/menu_load_word_count`｜加载字数｜`@string/load_word_count`
191. `@+id/menu_load_info`｜加载详情页｜`@string/load_info`
192. `@+id/menu_load_toc`｜加载目录｜`@string/load_toc`
193. `@+id/menu_group`｜分组｜`@string/group`
194. `@+id/menu_close`｜关闭｜`@string/close`

### change_source_item.xml（5 项）

195. `@+id/menu_top_source`｜置顶｜`@string/to_top`
196. `@+id/menu_bottom_source`｜置底｜`@string/to_bottom`
197. `@+id/menu_edit_source`｜编辑源｜`@string/edit_source`
198. `@+id/menu_disable_source`｜禁用源｜`@string/disable_source`
199. `@+id/menu_delete_source`｜删除源｜`@string/delete_source`

### code_edit.xml（1 项）

200. `@+id/menu_save`｜保存｜`@string/action_save`

### content_edit.xml（3 项）

201. `@+id/menu_save`｜保存｜`@string/action_save`
202. `@+id/menu_reset`｜重置｜`@string/reset`
203. `@+id/menu_copy_all`｜拷贝所有｜`@string/copy_all`

### content_search.xml（1 项）

204. `@+id/menu_enable_replace`｜替换｜`@string/replace`

### content_select_action.xml（8 项）

205. `@+id/menu_replace`｜替换｜`@string/replace`
206. `@+id/menu_copy`｜copy｜`@android:string/copy`
207. `@+id/menu_bookmark`｜书签｜`@string/bookmark`
208. `@+id/menu_aloud`｜朗读｜`@string/read_aloud`
209. `@+id/menu_dict`｜字典｜`@string/dict`
210. `@+id/menu_search_content`｜全文搜索｜`@string/search_content`
211. `@+id/menu_browser`｜浏览器｜`@string/browser`
212. `@+id/menu_share_str`｜分享｜`@string/share`

### crash_log.xml（1 项）

213. `@+id/menu_clear`｜清除｜`@string/clear`

### dialog_text.xml（1 项）

214. `@+id/menu_close`｜关闭｜`@string/close`

### dict_rule.xml（6 项）

215. `@+id/menu_add`｜新建｜`@string/create`
216. `@+id/menu_import_local`｜本地导入｜`@string/import_local`
217. `@+id/menu_import_onLine`｜网络导入｜`@string/import_on_line`
218. `@+id/menu_import_qr`｜二维码导入｜`@string/import_by_qr_code`
219. `@+id/menu_import_default`｜导入默认规则｜`@string/import_default_rule`
220. `@+id/menu_help`｜帮助｜`@string/help`

### dict_rule_edit.xml（3 项）

221. `@+id/menu_save`｜保存｜`@string/action_save`
222. `@+id/menu_copy_rule`｜拷贝规则｜`@string/copy_rule`
223. `@+id/menu_paste_rule`｜粘贴规则｜`@string/paste_rule`

### dict_rule_sel.xml（3 项）

224. `@+id/menu_enable_selection`｜启用所选｜`@string/enable_selection`
225. `@+id/menu_disable_selection`｜禁用所选｜`@string/disable_selection`
226. `@+id/menu_export_selection`｜导出所选｜`@string/export_selection`

### direct_link_upload_config.xml（3 项）

227. `@+id/menu_copy_rule`｜拷贝规则｜`@string/copy_rule`
228. `@+id/menu_paste_rule`｜粘贴规则｜`@string/paste_rule`
229. `@+id/menu_import_default`｜导入默认规则｜`@string/import_default_rule`

### explore_item.xml（6 项）

230. `@+id/menu_edit`｜编辑｜`@string/edit`
231. `@+id/menu_top`｜置顶｜`@string/to_top`
232. `@+id/menu_login`｜登录｜`@string/login`
233. `@+id/menu_search`｜搜索｜`@string/search`
234. `@+id/menu_refresh`｜刷新｜`@string/refresh`
235. `@+id/menu_del`｜删除｜`@string/delete`

### file_chooser.xml（1 项）

236. `@+id/menu_create`｜创建文件夹｜`@string/create_folder`

### file_long_click.xml（1 项）

237. `@+id/menu_del`｜删除｜`@string/delete`

### font_select.xml（2 项）

238. `@+id/menu_default`｜默认字体｜`@string/default_font`
239. `@+id/menu_other`｜其它目录｜`@string/other_folder`

### group_manage.xml（1 项）

240. `@+id/menu_add`｜添加分组｜`@string/add_group`

### import_book.xml（7 项）

241. `@+id/menu_select_folder`｜选择文件夹｜`@string/select_folder`
242. `@+id/menu_sort`｜排序｜`@string/sort`
243. `@+id/menu_sort_name`｜名称排序｜`@string/sort_by_name`
244. `@+id/menu_sort_size`｜大小排序｜`@string/sort_by_size`
245. `@+id/menu_sort_time`｜时间排序｜`@string/sort_by_time`
246. `@+id/menu_scan_folder`｜智能扫描｜`@string/scan_folder`
247. `@+id/menu_import_file_name`｜导入文件名｜`@string/import_file_name`

### import_book_sel.xml（1 项）

248. `@+id/menu_del_selection`｜删除｜`@string/delete`

### import_replace.xml（1 项）

249. `@+id/menu_new_group`｜自定义源分组｜`@string/diy_source_group`

### import_source.xml（6 项）

250. `@+id/menu_new_group`｜自定义源分组｜`@string/diy_source_group`
251. `@+id/menu_select_new_source`｜选中新增源｜`@string/select_new_source`
252. `@+id/menu_select_update_source`｜选中更新源｜`@string/select_update_source`
253. `@+id/menu_keep_original_name`｜保留原名｜`@string/keep_original_name`
254. `@+id/menu_keep_group`｜保留分组｜`@string/keep_group`
255. `@+id/menu_keep_enable`｜保留启用状态｜`@string/keep_enable`

### keyboard_assists_config.xml（1 项）

256. `@+id/menu_add`｜添加｜`@string/add`

### main_bnv.xml（4 项）

257. `@+id/menu_bookshelf`｜书架｜`@string/bookshelf`
258. `@+id/menu_discovery`｜发现｜`@string/discovery`
259. `@+id/menu_rss`｜订阅｜`@string/rss`
260. `@+id/menu_my_config`｜我的｜`@string/my`

### main_bookshelf.xml（12 项）

261. `@+id/menu_search`｜搜索｜`@string/search`
262. `@+id/menu_update_toc`｜更新目录｜`@string/update_toc`
263. `@+id/menu_add_local`｜添加本地｜`@string/book_local`
264. `@+id/menu_remote`｜远程书籍｜`@string/add_remote_book`
265. `@+id/menu_add_url`｜添加网址｜`@string/add_url`
266. `@+id/menu_bookshelf_manage`｜书架管理｜`@string/bookshelf_management`
267. `@+id/menu_download`｜缓存/导出｜`@string/cache_export`
268. `@+id/menu_group_manage`｜分组管理｜`@string/group_manage`
269. `@+id/menu_bookshelf_layout`｜书架布局｜`@string/bookshelf_layout`
270. `@+id/menu_export_bookshelf`｜导出书单｜`@string/export_bookshelf`
271. `@+id/menu_import_bookshelf`｜导入书单｜`@string/import_bookshelf`
272. `@+id/menu_log`｜日志｜`@string/log`

### main_explore.xml（1 项）

273. `@+id/menu_group`｜分组｜`@string/group`

### main_my.xml（1 项）

274. `@+id/menu_help`｜帮助｜`@string/help`

### main_rss.xml（3 项）

275. `@+id/menu_rss_star`｜收藏｜`@string/favorite`
276. `@+id/menu_group`｜分组｜`@string/group`
277. `@+id/menu_rss_config`｜设置｜`@string/setting`

### open_url_confirm.xml（2 项）

278. `@+id/menu_disable_source`｜禁用源｜`@string/disable_source`
279. `@+id/menu_delete_source`｜删除源｜`@string/delete_source`

### qr_code_scan.xml（1 项）

280. `@+id/action_choose_from_gallery`｜图库｜`@string/gallery`

### replace_edit.xml（3 项）

281. `@+id/menu_save`｜保存｜`@string/action_save`
282. `@+id/menu_copy_rule`｜拷贝规则｜`@string/copy_rule`
283. `@+id/menu_paste_rule`｜粘贴规则｜`@string/paste_rule`

### replace_rule.xml（8 项）

284. `@+id/menu_group`｜分组｜`@string/menu_action_group`
285. `@+id/menu_group_manage`｜分组管理｜`@string/group_manage`
286. `@+id/menu_group_null`｜未分组｜`@string/no_group`
287. `@+id/menu_add_replace_rule`｜新建替换｜`@string/add_replace_rule`
288. `@+id/menu_import_local`｜本地导入｜`@string/import_local`
289. `@+id/menu_import_onLine`｜网络导入｜`@string/import_on_line`
290. `@+id/menu_import_qr`｜二维码导入｜`@string/import_by_qr_code`
291. `@+id/menu_help`｜帮助｜`@string/help`

### replace_rule_item.xml（3 项）

292. `@+id/menu_top`｜置顶｜`@string/to_top`
293. `@+id/menu_bottom`｜置底｜`@string/to_bottom`
294. `@+id/menu_del`｜删除｜`@string/delete`

### replace_rule_sel.xml（5 项）

295. `@+id/menu_enable_selection`｜启用所选｜`@string/enable_selection`
296. `@+id/menu_disable_selection`｜禁用所选｜`@string/disable_selection`
297. `@+id/menu_top_sel`｜置顶所选｜`@string/selection_to_top`
298. `@+id/menu_bottom_sel`｜置底所选｜`@string/selection_to_bottom`
299. `@+id/menu_export_selection`｜导出所选｜`@string/export_selection`

### rss_articles.xml（7 项）

300. `@+id/menu_login`｜登录｜`@string/login`
301. `@+id/menu_refresh_sort`｜刷新分类｜`@string/refresh_sort`
302. `@+id/menu_set_source_variable`｜设置源变量｜`@string/set_source_variable`
303. `@+id/menu_edit_source`｜编辑源｜`@string/edit_source`
304. `@+id/menu_switch_layout`｜切换布局｜`@string/switchLayout`
305. `@+id/menu_read_record`｜阅读记录｜`@string/read_record`
306. `@+id/menu_clear`｜清除｜`@string/clear`

### rss_favorites.xml（3 项）

307. `@+id/menu_group`｜分组｜`@string/group`
308. `@+id/menu_del_group`｜删除当前分组｜`@string/delete_select_group`
309. `@+id/menu_del_all`｜删除所有｜`@string/delete_all`

### rss_main_item.xml（4 项）

310. `@+id/menu_top`｜置顶｜`@string/to_top`
311. `@+id/menu_edit`｜编辑｜`@string/edit`
312. `@+id/menu_disable`｜禁用源｜`@string/disable_source`
313. `@+id/menu_del`｜删除｜`@string/delete`

### rss_read.xml（6 项）

314. `@+id/menu_rss_refresh`｜刷新｜`@string/refresh`
315. `@+id/menu_rss_star`｜收藏｜`@string/favorite`
316. `@+id/menu_share_it`｜分享｜`@string/share`
317. `@+id/menu_aloud`｜朗读｜`@string/read_aloud`
318. `@+id/menu_login`｜登录｜`@string/login`
319. `@+id/menu_browser_open`｜浏览器打开｜`@string/open_in_browser`

### rss_read_record.xml（1 项）

320. `@+id/menu_clear`｜清除｜`@string/clear`

### rss_source.xml（12 项）

321. `@+id/menu_group`｜分组｜`@string/menu_action_group`
322. `@+id/menu_group_manage`｜分组管理｜`@string/group_manage`
323. `@+id/menu_enabled_group`｜已启用｜`@string/enabled`
324. `@+id/menu_disabled_group`｜已禁用｜`@string/disabled`
325. `@+id/menu_group_login`｜需要登录｜`@string/need_login`
326. `@+id/menu_group_null`｜未分组｜`@string/no_group`
327. `@+id/menu_add`｜新建订阅源｜`@string/add_rss_source`
328. `@+id/menu_import_local`｜本地导入｜`@string/import_local`
329. `@+id/menu_import_onLine`｜网络导入｜`@string/import_on_line`
330. `@+id/menu_import_qr`｜二维码导入｜`@string/import_by_qr_code`
331. `@+id/menu_import_default`｜导入默认规则｜`@string/import_default_rule`
332. `@+id/menu_help`｜帮助｜`@string/help`

### rss_source_debug.xml（2 项）

333. `@+id/menu_list_src`｜列表源码｜`@string/list_src`
334. `@+id/menu_content_src`｜正文源码｜`@string/content_src`

### rss_source_item.xml（3 项）

335. `@+id/menu_top`｜置顶｜`@string/to_top`
336. `@+id/menu_bottom`｜置底｜`@string/to_bottom`
337. `@+id/menu_del`｜删除｜`@string/delete`

### rss_source_sel.xml（9 项）

338. `@+id/menu_enable_selection`｜启用所选｜`@string/enable_selection`
339. `@+id/menu_disable_selection`｜禁用所选｜`@string/disable_selection`
340. `@+id/menu_add_group`｜添加分组｜`@string/add_group`
341. `@+id/menu_remove_group`｜移除分组｜`@string/remove_group`
342. `@+id/menu_top_sel`｜置顶所选｜`@string/selection_to_top`
343. `@+id/menu_bottom_sel`｜置底所选｜`@string/selection_to_bottom`
344. `@+id/menu_export_selection`｜导出所选｜`@string/export_selection`
345. `@+id/menu_share_source`｜分享选中源｜`@string/share_selected_source`
346. `@+id/menu_check_selected_interval`｜选中所选区间｜`@string/check_selected_interval`

### save.xml（1 项）

347. `@+id/menu_save`｜保存｜`@string/action_save`

### search_view.xml（1 项）

348. `@+id/menu_search`｜搜索｜`@string/search`

### server_config.xml（1 项）

349. `@+id/menu_save`｜保存｜`@string/action_save`

### servers.xml（1 项）

350. `@+id/menu_add`｜新建｜`@string/create`

### source_edit.xml（13 项）

351. `@+id/menu_save`｜保存｜`@string/action_save`
352. `@+id/menu_debug_source`｜调试源｜`@string/debug_source`
353. `@+id/menu_login`｜登录｜`@string/login`
354. `@+id/menu_search`｜搜索｜`@string/search`
355. `@+id/menu_clear_cookie`｜清除 Cookie｜`@string/cookie`
356. `@+id/menu_auto_complete`｜自动补全｜`@string/auto_complete`
357. `@+id/menu_copy_source`｜拷贝源｜`@string/copy_source`
358. `@+id/menu_paste_source`｜粘贴源｜`@string/paste_source`
359. `@+id/menu_set_source_variable`｜设置源变量｜`@string/set_source_variable`
360. `@+id/menu_qr_code_camera`｜二维码导入｜`@string/import_by_qr_code`
361. `@+id/menu_share_qr`｜二维码分享｜`@string/qr_share`
362. `@+id/menu_share_str`｜字符串分享｜`@string/str_share`
363. `@+id/menu_help`｜帮助｜`@string/help`

### source_login.xml（4 项）

364. `@+id/menu_ok`｜确认｜`@string/ok`
365. `@+id/menu_show_login_header`｜查看登录头｜`@string/show_login_header`
366. `@+id/menu_del_login_header`｜删除登录头｜`@string/del_login_header`
367. `@+id/menu_log`｜日志｜`@string/log`

### source_picker.xml（1 项）

368. `@+id/menu_change_source_delay`｜换源间隔｜`@string/change_source_delay`

### source_sub_item.xml（1 项）

369. `@+id/menu_del`｜删除｜`@string/delete`

### source_subscription.xml（1 项）

370. `@+id/menu_add`｜添加｜`@string/add`

### source_webview_login.xml（1 项）

371. `@+id/menu_ok`｜确认｜`@string/ok`

### speak_engine.xml（5 项）

372. `@+id/menu_add`｜添加｜`@string/add`
373. `@+id/menu_default`｜导入默认规则｜`@string/import_default_rule`
374. `@+id/menu_import_local`｜本地导入｜`@string/import_local`
375. `@+id/menu_import_onLine`｜网络导入｜`@string/import_on_line`
376. `@+id/menu_export`｜导出｜`@string/export`

### speak_engine_edit.xml（8 项）

377. `@+id/menu_save`｜保存｜`@string/action_save`
378. `@+id/menu_login`｜登录｜`@string/login`
379. `@+id/menu_show_login_header`｜查看登录头｜`@string/show_login_header`
380. `@+id/menu_del_login_header`｜删除登录头｜`@string/del_login_header`
381. `@+id/menu_copy_source`｜拷贝源｜`@string/copy_source`
382. `@+id/menu_paste_source`｜粘贴源｜`@string/paste_source`
383. `@+id/menu_log`｜日志｜`@string/log`
384. `@+id/menu_help`｜帮助｜`@string/help`

### theme_config.xml（1 项）

385. `@+id/menu_theme_mode`｜主题模式｜`@string/theme_mode`

### theme_list.xml（1 项）

386. `@+id/menu_import`｜剪贴板导入｜`剪贴板导入`

### txt_toc_rule.xml（6 项）

387. `@+id/menu_add`｜添加｜`@string/add`
388. `@+id/menu_import_local`｜本地导入｜`@string/import_local`
389. `@+id/menu_import_onLine`｜网络导入｜`@string/import_on_line`
390. `@+id/menu_import_qr`｜二维码导入｜`@string/import_by_qr_code`
391. `@+id/menu_import_default`｜导入默认规则｜`@string/import_default_rule`
392. `@+id/menu_help`｜帮助｜`@string/help`

### txt_toc_rule_edit.xml（3 项）

393. `@+id/menu_save`｜保存｜`@string/action_save`
394. `@+id/menu_copy_rule`｜拷贝规则｜`@string/copy_rule`
395. `@+id/menu_paste_rule`｜粘贴规则｜`@string/paste_rule`

### txt_toc_rule_item.xml（3 项）

396. `@+id/menu_top`｜置顶｜`@string/to_top`
397. `@+id/menu_bottom`｜置底｜`@string/to_bottom`
398. `@+id/menu_del`｜删除｜`@string/delete`

### txt_toc_rule_sel.xml（3 项）

399. `@+id/menu_enable_selection`｜启用所选｜`@string/enable_selection`
400. `@+id/menu_disable_selection`｜禁用所选｜`@string/disable_selection`
401. `@+id/menu_export_selection`｜导出所选｜`@string/export_selection`

### verification_code.xml（3 项）

402. `@+id/menu_ok`｜确认｜`@string/ok`
403. `@+id/menu_disable_source`｜禁用源｜`@string/disable_source`
404. `@+id/menu_delete_source`｜删除源｜`@string/delete_source`

### web_view.xml（6 项）

405. `@+id/menu_ok`｜确认｜`@string/ok`
406. `@+id/menu_open_in_browser`｜浏览器打开｜`@string/open_in_browser`
407. `@+id/menu_copy_url`｜拷贝 URL｜`@string/copy_url`
408. `@+id/menu_full_screen`｜全屏｜`@string/full_screen`
409. `@+id/menu_disable_source`｜禁用源｜`@string/disable_source`
410. `@+id/menu_delete_source`｜删除源｜`@string/delete_source`


## 关联文档

- 菜单属性全量台账：`docs/migration/button-audit/legacy-button-ledger.md`
- legacy -> soupreader 映射：`docs/migration/button-audit/button-mapping.csv`
- 主入口对照：`docs/migration/button-audit/main-4tab-checklist.md`
- 五段链路对照：`docs/migration/button-audit/search-c1-checklist.md`、`docs/migration/button-audit/explore-c2-checklist.md`、`docs/migration/button-audit/bookinfo-c3-checklist.md`、`docs/migration/button-audit/toc-c4-checklist.md`、`docs/migration/button-audit/content-c5-checklist.md`
