# 2026-02-21 阅读器正文铺满与菜单分层对齐 legado（content C5）

状态：`active`（含 `blocked` 例外项）

## 背景与目标
用户反馈阅读器与参考图（`IMG_6995.PNG`、`IMG_6996.PNG`）相比存在三类偏差：
1. 正文字体与边距偏松，单屏内容密度不足。
2. 进入配置状态时遮挡感偏重。
3. 顶部与底部菜单层和正文分隔不够清晰，易混淆。

本批次按迁移级别对齐 legado 语义，优先修正默认排版、菜单层视觉分层和配置弹层遮挡策略。

## 范围
- `lib/features/reader/models/reading_settings.dart`
- `lib/features/reader/views/simple_reader_view.dart`
- `lib/features/reader/widgets/reader_menus.dart`
- `lib/features/reader/widgets/reader_bottom_menu.dart`
- `lib/features/reader/widgets/reader_menu_surface_style.dart`
- `lib/features/reader/views/simple_reader_view.dart`
- `lib/features/reader/widgets/paged_reader_widget.dart`
- `test/reading_settings_test.dart`
- `test/reader_bottom_menu_new_test.dart`
- `test/reader_top_menu_test.dart`
- `test/paged_reader_widget_non_simulation_test.dart`
- `test/paged_reader_widget_simulation_image_test.dart`

## 非目标
- 不改书源解析链路（search/explore/bookInfo/toc/content 抓取与规则执行）。
- 不引入新的业务入口或扩展开关。
- 不执行 `flutter analyze`（遵循仓库约束）。

## legado 对照文件（已读取）
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/provider/TextChapterLayout.kt`
- `/home/server/legado/app/src/main/res/layout/view_read_menu.xml`
- `/home/server/legado/app/src/main/res/layout/dialog_tip_config.xml`

## 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D1 | `ReadingSettings` 默认值 | `ReadBookConfig.Config` 默认排版 | 默认字号/行距/段距/边距更松 | 单屏内容量偏少 |
| D2 | 阅读菜单透明策略 | `view_read_menu.xml` + `ReadMenu` | 顶部菜单渐变透出正文 | 顶部/正文边界不清 |
| D3 | 配置弹层遮挡 | `ReadStyleDialog`/`MoreConfigDialog` | iOS 弹层 dim 与高度偏大 | 配置态遮挡感偏重 |
| D4 | 顶部/底部菜单配色来源 | `ReadMenu.initView()` 同一 `bgColor/textColor` | 顶部存在写死深色分支，底部走 token 体系 | 上下栏观感割裂 |
| D5 | 信息->正文标题模式 | `TipConfigDialog` `RadioGroup` + `TextChapterLayout` 标题居中逻辑 | 选中态文案可读性差；滚动模式居中不明显 | 标题模式交互与展示不一致 |
| D6 | 翻页模式页脚提示与底部菜单 | `ReadMenu` 打开时页面菜单层优先 | 翻页模式提示条持续绘制，菜单打开时与底部菜单层叠 | 底部进度/菜单视觉重叠 |
| D7 | 底部进度拖动条与四入口间距 | `view_read_menu.xml` 章节行上下 5dp 节奏 | 拖动条与下方入口区视觉过近 | 底栏观感拥挤 |
| D8 | 自动阅读速度/面板语义 | `AutoReadDialog.kt` + `AutoPager.kt` + `dialog_auto_read.xml` | 速度语义偏离“秒/页”，面板缺少目录/主菜单/停止/设置联动入口 | 自动阅读反馈弱、用户感知“点击无反应” |

## 逐项检查清单（实现后）
- 入口：界面/设置/信息入口可达且语义未改。
- 状态：菜单展开、弹层开启/关闭、阅读设置实时生效。
- 异常：旧配置反序列化与字段缺失兼容不崩溃。
- 文案：按钮与配置文案业务语义不变。
- 排版：正文密度提升，顶/底菜单分层明显。
- 交互触发：点击、滑杆、关闭流程可用。

## 实施步骤与结果
1. `ReadingSettings` 默认排版对齐 legado
   - 新增 `layoutPresetVersion`（`1 -> 2`）
   - 新增 v1/v2 默认常量，并将构造默认改为 legado v2（字号 20、行高 1.2、段距 2、正文左右边距 16、上下边距 6）。

2. 历史设置一次性迁移
   - `fromJson` 在 `layoutPresetVersion < 2` 时，仅对仍等于 v1 旧默认的字段执行迁移；用户自定义值保持原样。
   - 迁移后版本提升至 `2`，`toJson` 持久化。

3. 菜单分层与遮挡优化
   - `ReaderTopMenu` 改为实体背景层 + 明确下边界 + 阴影，降低正文穿透。
   - `ReaderBottomMenuNew` 提升底栏实体度，增加滑杆区与四入口区分隔线。
   - `ReadStyle/MoreConfig/TipConfig` 弹层 `barrierColor` 设为透明；`ReadStyle/TipConfig` 高度收敛至 `0.74` 屏高语义，减轻配置态遮挡。

4. 顶部/底部样式统一到同一解析器
   - 新增 `reader_menu_surface_style.dart`，收敛 `panel/text/border/divider/shadow/control` 统一计算。
   - `ReaderTopMenu` 移除写死深色 `0xFF1F2937`，改为与底部同源的 `resolveReaderMenuSurfaceStyle`。
   - `ReaderBottomMenuNew` 改用同一解析器，保证顶部/底部颜色与层级参数不再分叉。

5. 信息弹层正文标题模式修复
   - `SimpleReaderView._buildLegacyTitleModeSegment` 调整分段控件选中态文本颜色，避免选中项被 `thumbColor` 覆盖后不可读。
   - `SimpleReaderView._buildScrollSegment` 将标题 `Text` 扩展为 `SizedBox(width: double.infinity)`，保证 `titleMode=居中` 在滚动模式按 legado 语义生效。

6. 翻页模式底部重叠修复
   - `PagedReaderWidget` 新增 `showTipBars`，用于菜单态控制页眉页脚提示可见性。
   - `SimpleReaderView._buildPagedContent` 在菜单/搜索/自动阅读面板打开时传入 `showTipBars=false`。
   - `PagedReaderWidget` 保持页眉页脚占位逻辑独立于提示条绘制，隐藏提示条时正文不发生上下跳动。

7. 底部进度拖动条间距优化
   - `ReaderBottomMenuNew` 在进度拖动区与入口区之间新增垂直留白。
   - 章节滑杆行顶部间距从 4 调整为 5，贴近 legado 章节区 `5dp` 节奏。

8. 自动阅读链路对齐 legado
   - `AutoPager` 速度语义改为“秒/页”，范围 `1-120`；翻页模式按秒触发，滚动模式按“视口高度/秒”推进。
   - `AutoReadPanel` 改为 legado 同义结构：速度滑杆 + `目录/主菜单/停止/设置` 四入口。
   - `SimpleReaderView` 增加自动阅读面板回调（主菜单/目录/设置/停止）并补齐开启/停止反馈文案。
   - 设置页“自动阅读速度”统一为 `1-120（秒/页）`，显示值带 `s`。

## 验收与证据
- 自动化测试（通过）：
  - `flutter test test/reading_settings_test.dart test/simple_reader_view_compile_test.dart test/reader_top_menu_test.dart test/reader_bottom_menu_new_test.dart test/app_settings_test.dart`
  - `flutter test test/reader_bottom_menu_new_test.dart`（含底部安全区贴底回归用例）
  - `flutter test test/reader_top_menu_test.dart test/reader_bottom_menu_new_test.dart test/simple_reader_view_compile_test.dart`（通过）
  - `flutter test test/simple_reader_view_compile_test.dart test/reader_top_menu_test.dart test/reader_bottom_menu_new_test.dart`（通过）
  - `flutter test test/simple_reader_view_compile_test.dart test/paged_reader_widget_non_simulation_test.dart test/paged_reader_widget_simulation_image_test.dart`（通过）
  - `flutter test test/reader_bottom_menu_new_test.dart`（通过）
  - `flutter test test/auto_pager_test.dart test/simple_reader_view_compile_test.dart`（通过）
  - `flutter test test/reading_settings_test.dart`（通过）
- 手工回归路径（待真机截图补充）：
  - C5：阅读页 -> 正文阅读 -> 打开菜单 -> 顶部栏/底部栏分层观察。
  - C5：阅读页 -> 界面/设置/信息弹层 -> 观察遮挡面积与关闭恢复。

## 兼容影响
- 低到中：
  - `ReadingSettings` 新增 `layoutPresetVersion` 字段；对旧默认值会执行一次迁移（用户自定义值不覆盖）。
  - 自动阅读速度上限由 `100` 调整为 `120`，并统一为“秒/页”语义；旧值会按新边界安全收敛。
  - 不涉及数据库结构、书源协议、网络接口。

## Progress
- [done] 默认排版参数对齐 legado v2。
- [done] 历史默认值迁移与版本化落盘。
- [done] 顶/底菜单分层与配置态遮挡优化。
- [done] 底部菜单背景贴底到安全区，消除底部正文漏出。
- [done] 顶部/底部菜单统一到同一样式解析器，移除顶部写死色值分支。
- [done] 信息弹层正文标题模式可读性修复，滚动模式“居中”对齐恢复生效。
- [done] 翻页模式菜单态隐藏页眉页脚提示，消除底部进度与菜单层叠。
- [done] 底部进度拖动条与四入口间距优化，缓解视觉拥挤。
- [done] 自动阅读速度语义、控制面板入口和状态反馈对齐 legado。
- [done] 阅读器自定义取色器对齐 legado 自由取色盘语义（拖拽色盘 + 色相条 + HEX + 最近使用）。
- [done] 滚动模式页眉页脚样式与翻页模式提示层对齐，消除模式间观感分叉。
- [done] “界面”弹窗简繁入口改为 legado 同义 `简/繁` 高亮态，并切换为三选一弹窗交互。
- [done] 分页模式页眉/页脚边距设置接入完整链路（提示层绘制 + overlay + 分页高度计算）。
- [done] 定向测试与计划记录回填。

## Surprises & Discoveries
- legacy 的菜单 dim 语义更接近“无遮罩”，而非 iOS 默认半透明遮罩；直接使用默认 `showCupertinoModalPopup` 会放大遮挡体感。
- 仅靠改 UI 透明度无法解决“内容不满”，默认排版参数与历史数据迁移必须一起做。
- Flutter 中将底栏 `Container` 置于 `SafeArea` 内部时，安全区本身是透明区域；若不把 inset 合并进容器 padding，就会出现“底部漏底色”。
- 顶部与底部分散维护配色逻辑会持续漂移；只有统一样式解析入口才能稳定保持同义。
- Flutter `TextAlign.center` 只有在标题容器存在足够宽度时才可见；滚动模式标题若不占满宽度会表现为“看起来没居中”。
- 翻页模式提示条绘制与正文占位应分离；仅隐藏提示条而不调整占位，才能避免菜单开合时正文跳动。
- 底部工具栏拥挤感主要由“滑杆区与入口区贴得过紧”引发，增加小幅垂直留白即可缓解，不需改控件尺寸。
- 自动阅读若仅“定时翻页”而无面板反馈，用户容易误判为点击无效；需保留 legado 的底部控制面板语义来提供可观测状态。
- `CupertinoAlertDialog` 内容区在 intrinsic 布局阶段不支持 `LayoutBuilder`；取色盘需改为固定面板尺寸以避免渲染断言。
- legado 的滚动与非滚动模式共用 `PageView` 承载页眉页脚；若 Flutter 端拆成两套组件，极易出现样式漂移。
- 简繁切换如果只显示“简繁”静态文案，用户难以感知当前方向；需要用 `简/繁` 双字高亮态直观暴露状态。

## Decision Log
- 决策 1：保留用户自定义值，只迁移“旧默认值”字段，避免强制覆盖。
- 决策 2：按 legado 语义优先，配置弹层减少 dim，优先保证正文可见。
- 决策 3：不引入新入口，限定在阅读器 C5 路径收敛。
- 决策 4：底栏改为“容器直接贴底 + 安全区 inset 合并进容器内边距”，确保背景连续覆盖到底部。
- 决策 5：顶部/底部统一使用 `resolveReaderMenuSurfaceStyle`，禁止顶部继续维护写死颜色分支。
- 决策 6：信息弹层正文标题模式保持 legado 三档语义，分段控件只修正可读性，不更改配置项结构。
- 决策 7：翻页模式菜单态隐藏提示条但保留页眉页脚占位，优先消除重叠并保持阅读区域稳定。
- 决策 8：底部进度拖动条间距采用“小幅放松”策略（+3/+4dp 过渡），不调整功能热区。
- 决策 9：自动阅读速度改回 legado 的“秒/页”模型，并以 `1-120` 范围对齐 `dialog_auto_read.xml` 的滑杆边界。
- 决策 10：阅读器取色能力按 legado `TYPE_CUSTOM` 收敛为“自由取色盘为主 + 常用预设补充”，不再依赖少量样例色。
- 决策 11：滚动模式保留独立组件但样式语义向 `PagedReaderWidget` 提示层收敛（透明层、文本化电量、一致字号与分割线节奏）。
- 决策 12：简繁切换入口按 legado 改为 `简/繁` 高亮态 + 三选一弹窗，禁用循环切换以提升状态可见性与可预期性。

## Outcomes & Retrospective
- 做了什么：完成正文密度参数与菜单分层联动收敛，补齐旧设置兼容迁移。
- 为什么：提升阅读信息密度，减少菜单/配置态干扰，贴近 legado 行为。
- 如何验证：模型/编译/组件/设置服务相关定向测试均通过。
- 增量收敛：修复底部菜单安全区漏底，并以测试锁定该视觉边界行为。
- 增量收敛：完成顶部/底部菜单样式同源化，消除“上深下浅”视觉割裂。
- 增量收敛：修复正文标题模式选中态可读性与滚动模式居中生效问题。
- 增量收敛：修复翻页模式底部进度提示与菜单层叠问题，菜单态层级与 legado 语义一致。
- 增量收敛：优化底部进度拖动区与四入口区间距，底栏观感更松弛。
- 增量收敛：自动阅读入口反馈、速度模型与控制面板结构完成 legado 同义回补。
- 增量收敛：自定义颜色选择改为 legado 同义取色盘交互，并补齐 HEX 校验/最近使用回写测试。
- 增量收敛：滚动模式页眉页脚去除实体背景栏，页码改为动态值，和其它翻页模式视觉语义一致。

## 2026-02-21 增量：界面/设置选项排查（第 23 批）

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D9 | `MoreConfigDialog` -> 底部对齐 | `TextPage.upLinesPosition()` | `textBottomJustify` 在 soupreader 仅存储状态，未进入分页渲染 | 用户开关可见但视觉无变化 |
| D10 | `ReadStyleDialog` -> 共享布局 | `ReadBookConfig.shareLayout`（共享/独立布局切换） | soupreader `ReadStyleConfig` 无布局参数承载，`shareLayout` 仅切值不生效 | 样式切换期望与实际不一致 |
| D11 | `MoreConfigDialog` -> 翻页按键 | legado 按键映射配置入口 | soupreader 仍为占位提示 | 平台按键映射能力缺口 |

### 逐项检查清单（本轮）
- 入口：`界面`（`_showReadStyleDialog`）与 `设置`（`_showLegacyMoreConfigDialog`）入口均可达。
- 状态：`底部对齐` 改为真实生效；`共享布局` 与 `翻页按键` 标记为待迁移/占位，不再伪装为可用。
- 异常：未实现项统一走 `_showReaderActionUnavailable` 可观测提示。
- 文案：保持 legado 业务语义（底部对齐/共享布局/翻页按键）不变。
- 排版：`共享布局` 行改为“待迁移”标签，避免误导性勾选状态。
- 交互触发：`底部对齐` 开关触发分页渲染变化；其余阻塞项触发明确提示。

### 实施结果
1. 补齐 `textBottomJustify` 渲染语义  
   - 文件：`lib/features/reader/widgets/legacy_justified_text.dart`、`lib/features/reader/widgets/paged_reader_widget.dart`。  
   - 对齐策略：复刻 legado “仅在页面接近装满时分摊行间余量”语义。  
   - 关键点：
     - 新增 `composeContentLines` 与 `computeBottomJustifyGap`。
     - `paintContentOnCanvas` 与 `LegacyJustifiedTextBlock` 共用同一底部对齐计算。
     - `PagedReaderWidget` 普通渲染与 Picture 预渲染两条路径同步接入 `textBottomJustify`。

2. `shareLayout` 进入例外阻塞态（避免假生效）  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 处理：将“共享布局”改为“待迁移”提示入口，点击输出不可用原因，不再切换无效状态值。

3. 补充定向测试  
   - 文件：`test/legacy_justified_text_highlight_test.dart`。  
   - 新增断言：底部对齐仅在“接近满页”条件下生效；页面留白过大时不拉伸。

### 验证与证据
- `flutter test test/legacy_justified_text_highlight_test.dart test/paged_reader_widget_non_simulation_test.dart test/simple_reader_view_compile_test.dart`（通过）

### 兼容影响
- 中：`底部对齐` 从“仅存储”变为“真实影响分页页内行间距”；仅影响翻页模式文本呈现，不改章节索引与进度存储。
- 低：`共享布局` 入口由伪开关改为待迁移提示，不影响既有书源/阅读进度数据。

### 迁移例外（按 1.1.2 记录）
- 例外 E1：`shareLayout` 暂无法等价复刻  
  - 原因：当前 `ReadStyleConfig` 仅含背景/文字样式字段，缺少 legado `Config` 中的排版参数承载。  
  - 影响范围：仅“界面 -> 背景文字样式 -> 共享布局”开关语义。  
  - 替代方案：本轮改为明确“待迁移”提示，避免误导用户。  
  - 回补计划：后续扩展 `ReadStyleConfig` 的布局快照字段，并在 `themeIndex` 切换时按 `shareLayout` 应用共享/独立排版。
- 例外 E2：`翻页按键` 仍为占位  
  - 原因：跨平台硬件按键映射能力尚未补齐。  
  - 影响范围：仅“设置 -> 翻页按键”配置项。  
  - 替代方案：保留可观测占位提示。  
  - 回补计划：补齐按键映射配置模型与平台分发链路后开放入口。

### Progress（增量）
- [done] `textBottomJustify` 对齐 legado 语义，已进入渲染链路。
- [blocked] `shareLayout`（E1）待样式布局模型扩展。
- [blocked] `翻页按键`（E2）待平台按键映射能力补齐。

## 2026-02-21 增量：正文标题居中在分页模式不生效（第 24 批）

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D12 | `PagedReaderWidget` 分页渲染 | `TextChapterLayout` + `TextPage` 标题布局语义 | 标题在分页渲染里未独立绘制，`titleMode=居中` 在正文页无可见变化 | 用户切到“居中”后感知为无效 |

### 实施结果
1. 分页渲染标题改为独立绘制  
   - 文件：`lib/features/reader/widgets/paged_reader_widget.dart`。  
   - 关键实现：
     - 新增 `_resolvePageTitleRenderData`，仅在章节第一页提取标题前缀并分离正文。
     - Widget 渲染路径新增 `_wrapPageBodyWithTitle`，按 `titleMode` 应用 `left/center` 对齐。
     - Picture 预渲染路径新增 `_paintPageTitleOnCanvas`，保持动画/静态一致。

2. 回归测试补齐  
   - 文件：`test/paged_reader_widget_non_simulation_test.dart`。  
   - 新增用例：`正文标题居中模式在分页渲染中应生效`，断言标题 `TextAlign.center`。

### 验证与证据
- `flutter test test/paged_reader_widget_non_simulation_test.dart`（通过）
- `flutter test test/simple_reader_view_compile_test.dart`（通过）

### 兼容影响
- 低：仅修复分页阅读器标题渲染方式，不改章节索引、翻页边界和进度持久化结构。

## 2026-02-21 增量：阅读器自定义取色盘对齐 legado（第 25 批）

### legado 对照文件（本批新增，已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/BgTextConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/lib/prefs/ColorPreference.kt`

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D13 | `reader_color_picker_dialog.dart` | `ColorPickerDialog.TYPE_CUSTOM` + `ReadBookActivity.onColorSelected` | soupreader 取色入口以样例色块为主，缺少可拖拽取色盘交互 | 用户自定义颜色效率低，难以精准选色 |

### 逐项检查清单（本轮）
- 入口：`界面 -> 文字颜色/背景颜色` 与 `信息 -> 页眉页脚颜色` 均沿用原入口，无新增分叉。
- 状态：取色盘拖拽、色相条拖拽、HEX 输入三条路径可互相同步。
- 异常：HEX 非法输入时显示错误提示，阻止确认提交。
- 文案：保留“取消/确定”与颜色输入提示文案语义。
- 排版：弹窗保留既有 iOS 对话框骨架，内容改为 legado 同义“自由取色盘优先”。
- 交互触发：确认后仍返回 `AARRGGBB`（alpha 固定 255），并记录“最近使用”。

### 实施结果
1. 取色组件改为自由取色盘  
   - 文件：`lib/features/reader/widgets/reader_color_picker_dialog.dart`。  
   - 关键实现：
     - 新增可拖拽饱和度/明度面板（SV board）。
     - 新增可拖拽色相条（Hue strip）。
     - 新增“当前/选择”双预览块，实时显示结果颜色。
     - 保留 HEX 输入并实现与取色盘双向同步。
     - 保留“常用预设”与“最近使用”作为辅助，不再依赖样例色。

2. 回归测试更新  
   - 文件：`test/reader_color_picker_dialog_test.dart`。  
   - 关键实现：
     - 用例 1：验证取色盘选择后可回写，并在二次打开时出现“最近使用”。
     - 用例 2：验证 HEX 非法输入提示与合法输入提交。

### 验证与证据
- `flutter test test/reader_color_picker_dialog_test.dart`（通过）
- `flutter test test/simple_reader_view_compile_test.dart`（通过）
- `flutter test test/reading_tip_settings_view_test.dart`（通过）

### 兼容影响
- 低：`showReaderColorPickerDialog` 的函数签名与返回值不变，调用链无需改造。
- 低：颜色仍以 `0xFFRRGGBB` 持久化，不涉及数据结构迁移。

## 2026-02-21 增量：滚动模式页眉/状态栏样式对齐 legado（第 31 批）

### legado 对照文件（本批新增，已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/ReadView.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/PageView.kt`
- `/home/server/legado/app/src/main/res/layout/view_book_page.xml`

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D14 | `simple_reader_view.dart` + `reader_status_bar.dart` | `ReadView` + `PageView` 统一页眉页脚渲染 | soupreader 滚动模式走独立实体栏，翻页模式走提示层；两者视觉样式与页码语义分叉 | 用户感知“滚动模式状态栏页眉和其它模式不一致” |

### 逐项检查清单（本轮）
- 入口：仅影响阅读页滚动模式页眉/页脚显示层，无新增入口。
- 状态：菜单/搜索/自动阅读面板打开时，滚动模式仍按原逻辑隐藏页眉页脚。
- 异常：电量获取异常保持兜底，不阻断阅读渲染。
- 文案：页眉页脚内容项文案语义不变。
- 排版：滚动模式由实体背景栏改为透明提示层，与翻页模式一致。
- 交互触发：页码由固定 `1/1` 改为随章节进度动态变化。

### 实施结果
1. 滚动模式页眉/页脚样式收敛  
   - 文件：`lib/features/reader/widgets/reader_status_bar.dart`。  
   - 关键实现：
     - 顶/底栏改为 `IgnorePointer + Padding` 的透明提示层，不再绘制实体背景色。
     - 分割线节奏改为与翻页模式一致（页眉线在文本下方，页脚线在文本上方）。
     - 电量显示改为纯文本百分比，避免滚动模式出现独有电池图标样式。
     - 页眉字号调整为 `12`，页脚字号保持 `11`，对齐翻页模式提示文本。

2. 滚动模式页码语义修复  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - 新增 `_resolveScrollTipTotalPages/_resolveScrollTipCurrentPage`。
     - `ReaderHeaderBar/ReaderStatusBar` 传入的 `currentPage/totalPages` 改为动态值，不再固定 `1/1`。

### 验证与证据
- `flutter test test/simple_reader_view_compile_test.dart test/reading_tip_settings_view_test.dart`（通过）

### 兼容影响
- 低：仅调整滚动模式页眉/页脚视觉与页码展示，不影响正文解析、翻页逻辑与进度存储结构。

## 2026-02-21 增量：快速翻页跨章节卡顿优化（第 26 批）

### legado 对照文件（本批新增，已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/api/PageFactory.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/provider/TextPageFactory.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/provider/ChapterProvider.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/provider/TextChapterLayout.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/ReadView.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/model/ReadBook.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookViewModel.kt`

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D14 | `simple_reader_view.dart` `_handlePageFactoryContentChanged` | `TextPageFactory.moveToNextChapter` + `ChapterProvider` | soupreader 在翻页回调内重复执行章节后处理与图片 marker 扫描 | 快速翻页跨章节时主线程抖动，体感卡顿 |
| D15 | `simple_reader_view.dart` `_loadChapter/_prefetchChapterIfNeeded/_syncPageFactoryChapters` | `TextChapterLayout` 后台排版复用语义 | 同一章节在加载/预取/同步阶段重复 `_postProcessContent` | CPU 重复消耗，切章链路波动加剧 |

### 逐项检查清单（本轮）
- 入口：阅读器翻页链路入口不变（左右翻页、自动翻页、目录跳章）。
- 状态：章节索引、章节标题、正文内容和页码提示保持原有状态流转。
- 异常：章节为空/越界/在途下载等分支处理不变。
- 文案：不新增、不修改任何用户可见文案。
- 排版：不改正文布局参数与菜单结构，仅调整内部数据复用。
- 交互触发：跨章节翻页仍按原语义触发保存进度、邻章预取、朗读上下文同步。

### 实施结果
1. 新增章节后处理快照缓存  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - 新增 `_ResolvedChapterSnapshot` 与 `_resolveChapterSnapshotFromBase`。
     - 以“后处理签名 + 基础 title/content 哈希”为命中条件复用结果。
     - `_loadChapter`、`_loadScrollSegment`、`_prefetchChapterIfNeeded` 统一改为走快照，避免重复 `_postProcessContent`。

2. 翻页回调热路径降载  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - `_handlePageFactoryContentChanged` 改为先取快照，只有章节载荷变化时才更新 `_currentTitle/_currentContent`。
     - 同章翻页不再重复解析正文与图片 marker，仅保留必要的 UI 刷新与进度保存。

3. 图片 marker 元信息缓存  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - 新增 `_ChapterImageMetaSnapshot` 和 `_resolveChapterImageMetaSnapshot`。
     - 跨章时复用已解析的 marker 列表，减少 `_collectUniqueImageMarkerMetas` 高频扫描。
     - 增加上限（64）与章节清理策略，控制缓存规模。

4. PageFactory 章节同步路径复用  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - `_syncPageFactoryChapters` 改为生成章节快照列表，复用已处理的标题与正文。
     - 增加 `_pruneResolvedChapterCachesIfNeeded`，在章节集变化后清理失活缓存。

### 验证与证据
- `flutter test test/simple_reader_view_compile_test.dart --concurrency=1`（通过）
- `flutter test test/reader_top_menu_test.dart --concurrency=1`（通过）
- `flutter test test/reader_bottom_menu_new_test.dart --concurrency=1`（通过）

### 兼容影响
- 低：仅优化章节后处理与图片 marker 解析的执行时机，不改阅读菜单语义、章节跳转行为和进度持久化结构。
- 低：未新增配置项与数据模型字段，不涉及迁移脚本与存量数据格式变更。

## 2026-02-21 增量：简繁切换链路对齐 legado 近章节重载（第 27 批）

### legado 对照文件（本批新增，已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/model/ReadBook.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/book/ContentProcessor.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/AppConfig.kt`

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D16 | `simple_reader_view.dart` `_updateSettings -> _syncPageFactoryChapters` | `ReadStyleDialog` 发 `UP_CONFIG(5)`，`ReadBook.loadContent` 仅重载当前/前后章 | soupreader 简繁切换会全量遍历 `_chapters` 并后处理每章 | 本地大 TXT/大章节场景切换简繁卡顿明显 |
| D17 | `simple_reader_view.dart` `PageFactory` 章节刷新 | `ReadBook` 按翻页位置渐进加载 | soupreader 缺少“延迟全量刷新”机制，无法在翻到新章节时按需补齐 | 要么全量卡顿，要么远章节语义不一致 |

### 逐项检查清单（本轮）
- 入口：阅读器“简/繁转换”入口与原路径一致，无新增入口层级。
- 状态：切换后当前章即时生效；连续翻页时新章节按需更新。
- 异常：章节空内容、越界章节、在途下载分支行为不变。
- 文案：不新增、不修改用户可见文案。
- 排版：正文排版参数、菜单结构与交互热区不变。
- 交互触发：翻页、目录跳章、自动翻页仍走原状态流转。

### 实施结果
1. PageFactory 章节同步新增“近章节优先”策略  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - `_syncPageFactoryChapters` 新增 `preferCachedForFarChapters/centerIndex` 参数。
     - 简繁切换场景仅强制刷新中心章节及前后一章，远章节复用旧快照。

2. 新增快照新鲜度判定与按需补齐  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - 新增 `_isChapterSnapshotFresh`。
     - 在 `_handlePageFactoryContentChanged` 中检测“进入新章节但快照陈旧”场景，触发一次“当前+邻章”补刷新并重排。

3. 简繁切换触发路径改为“延迟全量刷新”  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - `_updateSettings` 中识别 `chineseConverterType` 变更后，启用 `_hasDeferredChapterTransformRefresh`。
     - 立即刷新范围缩小为当前章邻域，后续随阅读位置推进逐步补齐，贴齐 legado 行为节奏。

### 验证与证据
- `flutter test test/simple_reader_view_compile_test.dart --concurrency=1`（通过）
- `flutter test test/reader_top_menu_test.dart --concurrency=1`（通过）
- `flutter test test/reader_bottom_menu_new_test.dart --concurrency=1`（通过）

### 兼容影响
- 低：仅调整简繁切换时章节刷新范围与执行时机，不改章节索引、分页模式、进度持久化与菜单结构。
- 低：不涉及数据库结构与设置模型迁移；旧配置读取与存储路径不变。

## 2026-02-21 增量：自动阅读弹窗设置行为对齐 legado（第 28 批）

### legado 对照文件（本批新增，已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/AutoReadDialog.kt`
- `/home/server/legado/app/src/main/res/layout/dialog_auto_read.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/BaseReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D18 | `simple_reader_view.dart` `_openInterfaceSettingsFromAutoReadPanel` | `AutoReadDialog.llSetting -> showPageAnimConfig` | soupreader 自动阅读面板“设置”跳到界面设置弹窗 | 交互路径层级偏离 legado |
| D19 | `auto_pager.dart` `CupertinoSlider.onChanged` | `AutoReadDialog` 仅在 `onStopTrackingTouch` 提交速度 | soupreader 拖动过程中实时落盘并重启自动阅读定时器 | 大幅滑动时状态抖动，行为与 legado 不同 |

### 逐项检查清单（本轮）
- 入口：自动阅读面板保持 `目录/主菜单/停止/设置` 四入口，无新增层级。
- 状态：设置按钮弹出翻页动画选择；自动阅读面板不被强制关闭。
- 异常：隐藏翻页模式（仿真2）点击后保留不可选提示，不写入非法模式。
- 文案：速度标题、按钮文案与既有语义保持不变。
- 排版：自动阅读面板布局与热区尺寸不改，仅调整回调语义。
- 交互触发：速度拖动中仅更新显示，拖动结束才提交并持久化。

### 实施结果
1. 自动阅读面板“设置”回调改为翻页动画选择  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - 新增 `_openPageAnimConfigFromAutoReadPanel`，弹出 `CupertinoActionSheet` 选择翻页动画。
     - 选择后仅更新 `pageTurnMode`，不再关闭自动阅读面板并跳转界面设置弹窗。

2. 自动阅读速度提交时机改为 `onChangeEnd`  
   - 文件：`lib/features/reader/widgets/auto_pager.dart`。  
   - 关键实现：
     - 新增面板内 `_previewSpeed`，拖动过程中仅更新显示值。
     - 在 `onChangeEnd` 才调用 `AutoPager.setSpeed` 与外部设置持久化回调。

3. 回归测试补齐  
   - 文件：`test/auto_pager_test.dart`。  
   - 关键实现：
     - 新增 `AutoReadPanel` 测试，覆盖“设置按钮触发回调”与“onChangeEnd 才提交速度”。

### 验证与证据
- `flutter test test/auto_pager_test.dart --concurrency=1`（通过）
- `flutter test test/simple_reader_view_compile_test.dart --concurrency=1`（通过）
- `flutter test test/reader_top_menu_test.dart --concurrency=1`（通过）
- `flutter test test/reader_bottom_menu_new_test.dart --concurrency=1`（通过）

### 兼容影响
- 低：仅调整自动阅读面板的设置入口与速度提交时机，不改设置模型字段和默认值。
- 低：不涉及数据库结构、书源协议与正文链路逻辑。

## 2026-02-21 增量：快速翻页视觉同步修复（第 29 批）

### legado 对照文件（本批复用，已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/ReadView.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/CoverPageDelegate.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/NoAnimPageDelegate.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/SimulationPageDelegate.kt`

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D20 | `paged_reader_widget.dart` `_onPageFactoryContentChangedForRender` | `ReadView` 交互收尾后会刷新当前页绘制缓存 | soupreader 交互中仅标记 `_pendingPictureInvalidation`，缺少空闲帧自动刷新调度 | 快速连续翻页时视觉停留旧页，用户感知“内容不变” |
| D21 | `paged_reader_widget.dart` `_abortAnim` | legado 中断动画后会按新页状态继续绘制 | soupreader 中断动画提交换页后未同步收敛图片缓存晋升/失效 | 快速中断场景更易复用旧 `Picture` |

### 逐项检查清单（本轮）
- 入口：翻页手势/点击入口保持不变，无新增交互路径。
- 状态：快速连续翻页时画面应随页码推进同步变化。
- 异常：无上一页/下一页边界行为保持原语义。
- 文案：不新增、不修改用户可见文案。
- 排版：正文排版与提示条布局不改，仅调整渲染缓存时机。
- 交互触发：慢速翻页与快速翻页均保持可翻可停，不卡死。

### 实施结果
1. 挂起失效新增空闲帧刷新调度  
   - 文件：`lib/features/reader/widgets/paged_reader_widget.dart`。  
   - 关键实现：
     - 新增 `_markPictureInvalidationPending/_schedulePendingPictureInvalidationFlush`。
     - 交互中收到内容变更时，除打标外自动调度空闲帧 flush，避免挂起状态长期滞留。

2. 动画中断路径补齐图片缓存收敛  
   - 文件：`lib/features/reader/widgets/paged_reader_widget.dart`。  
   - 关键实现：
     - `_abortAnim` 在提交换页后同步执行 `_promoteCachedPicturesOnPageFilled`（命中邻页缓存）。
     - 未命中晋升时改为挂起失效并调度刷新，避免快速中断后持续显示旧图。

3. 回归测试补齐  
   - 文件：`test/paged_reader_widget_non_simulation_test.dart`。  
   - 关键实现：
     - 新增“slide 模式快速连续点击应持续推进页码”用例，覆盖快速中断路径下页码推进与交互连续性。

### 验证与证据
- `flutter test test/paged_reader_widget_non_simulation_test.dart --concurrency=1`（通过）
- `flutter test test/simple_reader_view_compile_test.dart --concurrency=1`（通过）

### 兼容影响
- 低：仅调整翻页渲染缓存的失效与刷新时机，不改章节索引、分页规则与菜单结构。
- 低：不涉及持久化字段、数据库结构与书源请求链路。

## 2026-02-21 增量：快速翻页空章节加载反馈修复（第 30 批）

### legado 对照文件（本批新增，已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/ReadView.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/PageDelegate.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/HorizontalPageDelegate.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/entities/TextPage.kt`

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D22 | `simple_reader_view.dart` `_handlePageFactoryContentChanged` | legado 翻页委托中断后仍会继续对当前页刷新/填充 | soupreader 在 `_isHydratingChapterFromPageFactory=true` 时直接返回，当前章可能不触发水合 | 快速翻页到空章节时“无反馈/无进展” |
| D23 | `simple_reader_view.dart` `_chapterContentInFlight` + UI loading | `TextPage` 默认有 `data_loading` 占位反馈 | soupreader 预取请求 `showLoading=false` 时，当前章命中在途请求但不显示加载反馈 | 用户感知界面“没反应” |
| D24 | `simple_reader_view.dart` `_hydrateCurrentFactoryChapter` | legado 不会在手势中断后强制重定位到旧章 | soupreader 水合复用 `_loadChapter`，可能触发章节重定位副作用 | 快速翻页时状态流转不稳定 |

### 逐项检查清单（本轮）
- 入口：翻页点击/手势入口不变，无新增菜单或弹层。
- 状态：快速翻页命中空章节时可见加载反馈；待水合章节按最新索引排队处理。
- 异常：在途请求失败仍不阻塞阅读主流程，保持原回退策略。
- 文案：不新增文案，沿用现有加载指示组件。
- 排版：阅读页布局不变，仅控制顶部 loading 指示显示条件。
- 交互触发：慢速/快速翻页都能进入章节加载链路，不被全局锁吞掉。

### 实施结果
1. PageFactory 水合补齐“最新章节排队”机制  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - 新增 `_activeHydratingChapterFromPageFactoryIndex/_pendingHydratingChapterFromPageFactoryIndex`。
     - `_handlePageFactoryContentChanged` 在水合进行中不再直接丢弃，而是记录最新待水合章节并在当前任务结束后继续处理。

2. 当前章节加载反馈与在途请求联动  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - 新增 `_isCurrentFactoryChapterLoading` 与 `_syncCurrentFactoryChapterLoadingState`。
     - 将“当前章空内容 + 在途请求/水合进行中/排队中”映射为可见 loading 指示，覆盖预取在途场景。

3. PageFactory 水合改为就地补齐，避免重定位副作用  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - `_hydrateCurrentFactoryChapter` 改为调用 `_prefetchChapterIfNeeded(showLoading: true)`。
     - 保持当前位置语义，避免 `_loadChapter` 路径的跳章重定位。

### 验证与证据
- `flutter test test/simple_reader_view_compile_test.dart --concurrency=1`（通过）
- `flutter test test/paged_reader_widget_non_simulation_test.dart --concurrency=1`（通过）
- `flutter test test/reader_top_menu_test.dart --concurrency=1`（通过）
- `flutter test test/reader_bottom_menu_new_test.dart --concurrency=1`（通过）

### 兼容影响
- 低：仅调整翻页模式章节水合调度与加载反馈，不改章节持久化结构与书源规则语义。
- 低：滚动模式链路不受影响；翻页模式仅增强空章节场景可观测性。

## 2026-02-21 增量：字距显示精度对齐实际刻度（第 32 批）

### legado 对照文件（本批复用，已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D25 | `simple_reader_view.dart` `_legacyLetterSpacingLabel` | legado 字距 seekbar 为 `0.01` 级映射（`(it-50)/100f`） | soupreader 标签显示保留 1 位小数，和内部 `0.01` 步进不一致 | 用户误感为“字距每次只按 0.1 变化” |

### 逐项检查清单（本轮）
- 入口：仅读取“界面”弹层的字距显示标签，不改入口结构。
- 状态：字距范围仍为 `-0.5 ~ 0.5`，内部步进仍为 `0.01`。
- 异常：无新增异常路径。
- 文案：仅数字格式变化，文案语义不变。
- 排版：标签宽度与布局不变。
- 交互触发：滑杆与 `- / +` 触发逻辑不变。

### 实施结果
1. 字距标签精度从 1 位提升到 2 位  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - `_legacyLetterSpacingLabel` 由 `toStringAsFixed(1)` 改为 `toStringAsFixed(2)`。
     - 保持 `_settings.copyWith(letterSpacing: (progress - 50) / 100)` 不变，仅修正显示层精度。

### 验证与证据
- `flutter test test/simple_reader_view_compile_test.dart`（通过）

### 兼容影响
- 低：仅 UI 显示精度调整，不影响实际字距计算、持久化、章节排版流程。

## 2026-02-21 增量：本地书籍入页性能收敛（第 33 批）

### legado 对照文件（本批复用，已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/ReadView.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/provider/TextPageFactory.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/provider/ChapterProvider.kt`

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D26 | `simple_reader_view.dart` `_initReader/_syncPageFactoryChapters` | legado 以当前阅读章节为中心逐步准备内容，不要求入页时全量重排全部章节 | soupreader 入页时会对所有章节执行 `_resolveChapterSnapshot`，本地书章节多时阻塞明显 | 用户进入本地书阅读页耗时偏长 |
| D27 | `simple_reader_view.dart` `_loadChapter` | legado 切章优先保障当前章节可读，远端章节按需补齐 | soupreader 切章同步 `PageFactory` 默认全量后处理，切章前期 CPU 峰值高 | 本地书切入/恢复进度体感卡顿 |

### 逐项检查清单（本轮）
- 入口：书架/阅读历史打开本地书入口不变。
- 状态：当前章节内容保持完整后处理；远端章节命中时仍会回到完整后处理链路。
- 异常：远端章节占位快照不进入“已完全处理”状态，避免脏缓存。
- 文案：无新增文案。
- 排版：正文最终排版语义不变，仅调整处理时机。
- 交互触发：翻页/滚动切章仍按既有触发链路执行。

### 实施结果
1. 初始化改为“近处完整、远端延迟”  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - `_initReader` 不再对全部章节直接 `_resolveChapterSnapshot`，改为 `_syncPageFactoryChapters(preferCachedForFarChapters: true)` 受控延迟远端处理。
     - 新增 `_shouldDeferFarChapterTransforms`，本地书与滚动模式默认启用远端章节延迟。

2. 切章同步链路接入延迟策略  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - `_loadChapter`（滚动/非滚动）同步 `PageFactory` 时传入 `preferCachedForFarChapters`，避免每次切章全量后处理。
     - `_syncPageFactoryChapters` 对“远端且无缓存”章节改用 `_resolveDeferredChapterSnapshot`。

3. 占位快照标识与新鲜度判定收敛  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - `_ResolvedChapterSnapshot` 新增 `isDeferredPlaceholder`。
     - `_resolveChapterSnapshotFromBase` 忽略占位快照命中，确保命中章节后会执行完整正文后处理并回写缓存。

### 验证与证据
- `flutter test test/simple_reader_view_compile_test.dart test/paged_reader_widget_non_simulation_test.dart --concurrency=1`（通过）

### 兼容影响
- 低：仅优化初始化与章节同步时机，不改书源协议、章节存储结构与用户可见设置语义。

## 2026-02-21 增量：滚动模式页眉/页脚边距回补（第 34 批）

### legado 对照文件（本批复用，已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/PageView.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/ReadView.kt`

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D28 | `reader_status_bar.dart` 滚动模式页眉/页脚定位 | legado header/footer 绘制基线分别是 `topSafe + 6`、`bottomSafe + 6` | soupreader 滚动模式页眉/页脚直接贴 `safeArea + 用户padding`，当 padding 较小时贴边明显 | 用户感知“页眉页脚太贴顶部底部” |

### 逐项检查清单（本轮）
- 入口：阅读页滚动模式状态栏显示入口不变。
- 状态：菜单/搜索/自动阅读面板打开时，页眉页脚仍按既有逻辑隐藏。
- 异常：无新增异常路径。
- 文案：无文案变更。
- 排版：页眉/页脚距屏幕边缘增加固定 6dp。
- 交互触发：仅视觉位置调整，不影响手势与点击。

### 实施结果
1. 滚动模式页脚增加底部边距  
   - 文件：`lib/features/reader/widgets/reader_status_bar.dart`。  
   - 关键实现：
     - 新增 `_legacyTipEdgeInset = 6.0`。
     - 页脚 `bottom` padding 改为 `safeArea + settings.footerPaddingBottom + 6.0`。

2. 滚动模式页眉增加顶部边距  
   - 文件：`lib/features/reader/widgets/reader_status_bar.dart`。  
   - 关键实现：
     - 页眉 `top` padding 改为 `safeArea + settings.headerPaddingTop + 6.0`。
     - 保持原有 header/footer 分割线与字号节奏不变。

### 验证与证据
- `flutter test test/simple_reader_view_compile_test.dart test/reading_tip_settings_view_test.dart --concurrency=1`（通过）

### 兼容影响
- 低：仅调整滚动模式提示层边距，不影响设置字段语义与阅读器主链路行为。

## 2026-02-21 增量：简繁切换入口视觉态对齐 legado（第 35 批）

### legado 对照文件（本批新增，已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ChineseConverter.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/res/values/arrays.xml`

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D29 | `simple_reader_view.dart` “界面”弹窗快捷入口 | legado `ChineseConverter` 使用 `简/繁` 双字并按当前模式高亮单字 | soupreader 仅显示“简繁”静态文案，无法直观看到当前转换方向 | 用户反馈“界面显示不明显” |
| D30 | `simple_reader_view.dart` 简繁点击交互 | legado 点击后弹出三选一列表（Off/繁转简/简转繁） | soupreader 使用循环切换，交互路径与 legado 不同 | 可预期性不足，误触后回退成本更高 |

### 逐项检查清单（本轮）
- 入口：“界面”弹窗工具条的简繁入口位置与热区保持不变。
- 状态：`关闭/繁转简/简转繁` 三态可见；高亮态与当前设置同步。
- 异常：非法类型值回退到 `off`，避免崩溃或显示异常。
- 文案：采用 legado 同义 `简/繁` 状态文案与三选项语义。
- 排版：沿用现有 chip 尺寸与边框，仅替换文案渲染方式。
- 交互触发：点击入口弹出 ActionSheet，选择后即时更新阅读设置。

### 实施结果
1. 简繁入口改为 legado 同义状态文案  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - 新增 `_buildChineseConverterActionChipLabel`，将快捷入口文案改为 `简/繁`。
     - `chineseConverterType=1` 时高亮“简”，`=2` 时高亮“繁”，`=0` 时不高亮。

2. 点击交互改为三选一弹窗  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - 新增 `_chineseConverterOptions`（关闭/繁转简/简转繁）。
     - 简繁入口点击后改为 `_showTipOptionPicker`，选择项后更新 `chineseConverterType`。
     - 移除原先“按序循环切换”路径，避免与 legado 交互分叉。

3. 芯片渲染函数扩展  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - `_buildReadStyleActionChip` 支持 `labelWidget`，用于承载富文本状态文案。
     - 其余入口继续复用原 `label` 文案，行为保持不变。

### 验证与证据
- `flutter test test/simple_reader_view_compile_test.dart --concurrency=1`（通过）
- `flutter test test/reader_top_menu_test.dart --concurrency=1`（通过）

### 兼容影响
- 低：仅调整简繁入口显示与交互方式，不改简繁转换三态枚举、正文转换实现与设置持久化字段。

## 2026-02-21 增量：分页模式页眉/页脚边距设置生效修复（第 36 批）

### legado 对照文件（本批新增，已完整读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/PageView.kt`
- `/home/server/legado/app/src/main/res/layout/view_book_page.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/PaddingConfigDialog.kt`

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D31 | `paged_reader_widget.dart` `_paintHeaderFooter/_buildOverlay` | legado `PageView` 对 header/footer 使用独立 `setPadding`（top/bottom/left/right） | soupreader 分页模式提示层仍混用固定 `6` 与正文 `widget.padding`，未完整读取 `header/footer padding` | 用户调节页眉/页脚边距后视觉无明显变化 |
| D32 | `simple_reader_view.dart` `_paginateContentLogicOnly` | legado 页内容高度受 header/footer 实际占位影响 | soupreader 分页高度仍按固定 `PagedReaderWidget.topOffset/bottomOffset=37` 计算 | 提示层即使位置变化，分页断点仍不随设置同步 |

### 逐项检查清单（本轮）
- 入口：边距弹窗“页眉/页脚”四向滑杆入口与热区保持不变。
- 状态：调整 `header/footer padding` 后，分页模式页眉/页脚位置与正文可视区同时变化。
- 异常：`padding` 极值下不发生崩溃，分割线仍按开关控制显示。
- 文案：无新增文案，无业务语义变更。
- 排版：页眉/页脚与正文保持清晰分层，分割线位置与 legado 同义。
- 交互触发：拖动滑杆即时生效，翻页动画/静态页显示一致。

### 实施结果
1. 提示层占位高度改为统一动态计算  
   - 文件：`lib/features/reader/widgets/paged_reader_widget.dart`。  
   - 关键实现：
     - 新增 `resolveHeaderSlotHeight/resolveFooterSlotHeight`，统一计算 `padding + 字号 + 分割线 + 6dp edge inset`。
     - `_headerSlotHeight/_footerSlotHeight` 改为复用统一计算结果，避免不同路径重复实现造成漂移。

2. 分页模式渲染路径统一接入 header/footer padding  
   - 文件：`lib/features/reader/widgets/paged_reader_widget.dart`。  
   - 关键实现：
     - `_paintHeaderFooter`：页眉/页脚文本与分割线的 `x/y` 坐标改为基于 `headerPadding* / footerPadding*`。
     - `_paintTipRow`：新增左右 padding 约束，居中文本按可用宽度居中，防止继续使用正文 padding。
     - `_buildOverlay`：改为 `Stack + Positioned`，顶部/底部提示与分割线均按 header/footer padding 定位，不再使用固定容器内边距。

3. 分页高度计算改为动态占位  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 关键实现：
     - `_paginateContentLogicOnly` 中 `topOffset/bottomOffset` 改为调用 `PagedReaderWidget.resolveHeaderSlotHeight/resolveFooterSlotHeight`。
     - 移除固定 `37` 占位依赖，确保“边距设置 -> 分页高度 -> 断点”链路同步生效。

### 验证与证据
- `flutter test test/paged_reader_widget_non_simulation_test.dart --concurrency=1`（通过）
- `flutter test test/simple_reader_view_compile_test.dart test/reading_tip_settings_view_test.dart --concurrency=1`（通过）

### 兼容影响
- 低：仅修复分页模式提示层与分页高度计算一致性，不改设置字段、菜单结构与正文抓取链路。
