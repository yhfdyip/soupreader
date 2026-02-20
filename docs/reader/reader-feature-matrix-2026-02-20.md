# 阅读器功能矩阵（2026-02-20）

> 范围：`simple_reader_view` 阅读页内可见入口、菜单动作、点击区域动作。  
> 口径：按 legado 语义对照，标注当前状态为 `可用` / `占位` / `受限`。  
> 说明：本轮按需求仅做样式优化与梳理，不改动功能逻辑。

## 1. 顶部菜单（Top Menu）

文件：`lib/features/reader/widgets/reader_menus.dart`、`lib/features/reader/views/simple_reader_view.dart`

| 入口 | 触发函数 | 当前行为 | 状态 | legado 对照 |
|---|---|---|---|---|
| 返回按钮 | `Navigator.pop(context)` | 退出阅读页 | 可用 | 同义 |
| 书名（点击） | `_openBookInfoFromTopMenu` | 打开书籍详情（书架书籍） | 可用 | 同义 |
| 章节名/章节链接（点击） | `_openChapterLinkFromTopMenu` | 打开当前章节网页（可配置浏览器/内置） | 可用 | 同义 |
| 章节名/章节链接（长按） | `_toggleChapterLinkOpenModeFromTopMenu` | 切换章节链接打开方式 | 可用 | 同义 |
| 书源按钮 | `_showSourceActionsMenu` | 打开书源动作菜单（登录/购买/编辑/禁用） | 可用（条件） | 同义 |
| 净化/净化中 | `_toggleCleanChapterTitleFromTopMenu` | 切换章节标题净化并提示 | 可用 | 同义 |
| 刷新 | `_refreshChapter` | 重新加载当前章节 | 可用 | 同义 |
| 搜索 | `_showContentSearchDialog` | 打开正文关键词搜索对话框 | 可用 | 同义 |
| 目录图标 | `_showChapterList` | 打开目录/书签面板 | 可用 | 同义 |
| 更多图标 | `_showReaderActionsMenu` | 打开“阅读操作”菜单 | 可用 | 同义 |

## 2. 书源动作菜单

文件：`lib/features/reader/views/simple_reader_view.dart`

| 菜单项 | 触发函数 | 当前行为 | 状态 | legado 对照 |
|---|---|---|---|---|
| 登录 | `_openSourceLoginFromReader` | 打开书源登录页（表单或网页验证） | 可用（条件） | 同义 |
| 章节购买 | `_triggerChapterPayAction` | 执行 payAction，支持 URL/成功刷新 | 可用（条件） | 同义 |
| 编辑书源 | `_openSourceEditorFromReader` | 打开书源编辑页 | 可用 | 同义 |
| 禁用书源 | `_disableSourceFromReader` | 确认后禁用当前书源 | 可用 | 同义 |

## 3. 右侧快捷栏（Legacy Quick Actions）

文件：`lib/features/reader/views/simple_reader_view.dart`、`lib/features/reader/services/reader_legacy_quick_action_helper.dart`

| 快捷按钮 | 触发函数 | 当前行为 | 状态 | legado 对照 |
|---|---|---|---|---|
| 搜索正文 | `_showContentSearchDialog` | 打开正文搜索 | 可用 | 同义 |
| 自动翻页（开始/停止） | `_toggleAutoPageFromQuickAction` | 启停自动翻页 | 可用 | 同义 |
| 替换规则 | `_openReplaceRuleFromMenu` | 打开替换规则列表 | 可用 | 同义 |
| 日夜切换 | `_toggleDayNightThemeFromQuickAction` | 在亮/暗主题间切换 | 可用 | 同义 |

## 4. 底部菜单（章节 + 四入口 + 亮度侧栏）

文件：`lib/features/reader/widgets/reader_bottom_menu.dart`、`lib/features/reader/views/simple_reader_view.dart`

| 入口 | 触发函数 | 当前行为 | 状态 | legado 对照 |
|---|---|---|---|---|
| 上一章 | `onChapterChanged -> _loadChapter(index-1)` | 跳转上一章 | 可用（边界禁用） | 同义 |
| 章节/分页滑条 | `onSeekChapterProgress` / `onPageChanged` | 按模式跳转章节或页码 | 可用 | 同义 |
| 下一章 | `onChapterChanged -> _loadChapter(index+1)` | 跳转下一章 | 可用（边界禁用） | 同义 |
| 目录 | `_openChapterListFromMenu` | 打开目录/书签面板 | 可用 | 同义 |
| 朗读 | `_openReadAloudFromMenu -> _openReadAloudAction` | 当前仅提示“语音朗读即将上线” | 占位 | 不同义（legado 有完整 TTS 流程） |
| 界面 | `_openInterfaceSettingsFromMenu` | 打开阅读样式面板 | 可用 | 同义 |
| 设置 | `_openBehaviorSettingsFromMenu` | 打开阅读设置面板 | 可用 | 同义 |
| 亮度自动 | `onSettingsChanged(useSystemBrightness)` | 自动/手动亮度切换 | 可用 | 同义 |
| 亮度滑条 | `onSettingsChanged(brightness)` | 调整亮度值 | 可用 | 同义 |
| 亮度左右位置 | `onSettingsChanged(brightnessViewOnRight)` | 切换亮度侧栏位置 | 可用 | 同义 |

## 5. 阅读操作菜单（“更多”）

文件：`lib/features/reader/services/reader_legacy_menu_helper.dart`、`lib/features/reader/views/simple_reader_view.dart`

| 菜单项 | 当前行为 | 状态 | legado 对照 |
|---|---|---|---|
| 换源 | 打开换源面板 | 可用 | 同义 |
| 刷新 | 刷新当前章节 | 可用 | 同义 |
| 离线缓存 | 仅提示“当前版本暂未支持” | 占位 | 不同义 |
| TXT 目录规则 | 仅提示“当前版本暂未支持” | 占位 | 不同义 |
| 设置编码 | 仅提示“书籍级编码覆盖尚未接入正文解析链路” | 占位 | 不同义 |
| 添加书签 | 添加/取消当前章节书签 | 可用 | 同义 |
| 编辑正文 | 仅提示“当前版本暂未支持” | 占位 | 不同义 |
| 翻页动画 | 打开“界面”设置 | 可用 | 同义 |
| 获取进度 | 仅提示“当前版本暂未支持” | 占位 | 不同义 |
| 覆盖进度 | 仅提示“当前版本暂未支持” | 占位 | 不同义 |
| 正文倒序 | 仅提示“当前版本暂未支持” | 占位 | 不同义 |
| 模拟阅读 | 仅提示“当前版本暂未支持” | 占位 | 不同义 |
| 启用替换规则 | 切换替换规则并重载章节 | 可用 | 同义 |
| 同名标题去重 | 仅提示“当前版本暂未支持” | 占位 | 不同义 |
| 重新分段 | 仅提示“当前版本暂未支持” | 占位 | 不同义 |
| 删除 ruby 标签 | 仅提示“当前版本暂未支持” | 占位 | 不同义 |
| 删除 h 标签 | 仅提示“当前版本暂未支持” | 占位 | 不同义 |
| 图片样式 | 仅提示“当前版本暂未支持” | 占位 | 不同义 |
| 更新目录 | 拉取并更新目录，提示更新章数 | 可用 | 同义 |
| 生效替换规则 | 打开替换规则列表 | 可用 | 同义 |
| 日志 | 打开异常日志页 | 可用 | 同义 |
| 帮助 | 显示阅读菜单帮助提示 | 可用 | 同义 |

## 6. 目录/书签面板动作（Catalog Sheet）

文件：`lib/features/reader/widgets/reader_catalog_sheet.dart`

| 菜单项 | 当前行为 | 状态 | legado 对照 |
|---|---|---|---|
| 倒序 | 目录顺序切换 | 可用 | 同义 |
| 使用替换规则 | 切换目录替换开关 | 可用 | 同义 |
| 加载字数 | 切换目录字数显示 | 可用 | 同义 |
| TXT 目录规则 | 未注入回调时提示不可用 | 受限 | 同义（条件能力） |
| 分割长章节 | 切换分割开关 | 可用 | 同义 |
| 导出书签 | 注入回调时可导出，否则提示不可用 | 受限 | 同义（条件能力） |
| 导出 Markdown | 注入回调时可导出，否则提示不可用 | 受限 | 同义（条件能力） |
| 日志 | 注入回调时可打开，否则提示不可用 | 受限 | 同义（条件能力） |

## 7. 点击区域动作（9 宫格）

文件：`lib/features/reader/models/reading_settings.dart`、`lib/features/reader/views/simple_reader_view.dart`

| 动作 | 当前行为 | 状态 | legado 对照 |
|---|---|---|---|
| 无 | 不做处理 | 可用 | 同义 |
| 菜单 | 打开阅读菜单 | 可用 | 同义 |
| 下一页 / 上一页 | 翻页（滚动或分页模式） | 可用 | 同义 |
| 下一章 / 上一章 | 跳章节 | 可用 | 同义 |
| 书签 | 添加/取消书签 | 可用 | 同义 |
| 编辑正文 | 仅提示“正文编辑暂未实现” | 占位 | 不同义 |
| 替换开关 | 切换替换规则 | 可用 | 同义 |
| 目录 | 打开目录面板 | 可用 | 同义 |
| 搜索正文 | 打开搜索框 | 可用 | 同义 |
| 同步进度 | 仅提示“云端进度同步暂未实现” | 占位 | 不同义 |
| 朗读上一段 / 下一段 / 暂停继续 | 统一进入朗读入口，当前返回占位提示 | 占位 | 不同义 |

## 结论摘要

1. 主阅读链路可用入口大多已打通，问题集中在“legacy 菜单中的扩展能力”仍为占位。
2. 你反馈的“有些按钮功能有问题”与代码现状一致：属于显式占位而非偶发故障。
3. 下一轮若要修按钮，应优先从以下三组开始：
   - `朗读（TTS）`；
   - `阅读操作菜单`中的占位项；
   - `点击区域动作`中的占位项（编辑正文/同步进度/朗读段落控制）。
