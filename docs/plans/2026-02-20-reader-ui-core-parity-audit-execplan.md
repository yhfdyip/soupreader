# Legado -> SoupReader 阅读器界面全量一致性排查（核心范围，报告版）

- 状态：`done`
- 负责人：`Reader-Audit`
- 更新时间：`2026-02-20`
- 范围类型：迁移级别（核心功能排查，扩展能力保持冻结）

## 背景与目标

### 背景

- 需求要求：阅读器界面所有功能（按钮、菜单、入口层级、交互触发）与 legado 同义，UI 风格差异可接受。
- 当前仓库已有阅读器迁移计划，但本轮需要执行一次“全量排查报告”交付，不直接改代码。
- 按需求确认，本轮范围为“仅核心功能”，扩展能力（朗读引擎/HTTP TTS/漫画等）继续 `blocked`。

### 目标

- 输出阅读器界面的完整差异台账，不遗漏按钮、菜单、入口和设置项。
- 给出逐项对照结果（已同义/部分同义/缺失/blocked）。
- 给出可直接进入下一轮修复的优先级与阻塞项说明。

### 非目标

- 本轮不执行业务代码修复。
- 本轮不解锁扩展功能开发。
- 本轮不执行 `flutter analyze`（遵守仓库规则：仅提交推送前执行一次）。

### 成功标准

- 差异点清单完整覆盖：入口、状态、异常、文案、排版、交互触发、按钮、跳转层级。
- 形成按钮/菜单矩阵、路由层级矩阵、配置项覆盖矩阵三套台账。
- 给出阻塞项四要素：原因、影响、替代方案、回补计划。

## 差异点清单（含文件位置/原因/影响）

| ID | 差异 | legado 基准 | soupreader 现状 | 原因 | 影响 |
| --- | --- | --- | --- | --- | --- |
| D-01 | 快捷动作区按钮集合漂移 | `view_read_menu.xml:129`（`fabSearch/fabAutoPage/fabReplaceRule/fabNightTheme`）+ `ReadMenu.kt:435` | `simple_reader_view.dart:3077`（`search/bookmark/catalog/readAloud/interface/settings`） | 历史交互重组为“右侧悬浮栏” | 按钮集合、排序、触发语义与 legado 不同 |
| D-02 | 书源操作菜单缺失 | `ReadMenu.kt:104`、`ReadMenu.kt:368`（登录/付费/编辑/禁用） | `reader_menus.dart:102` + `simple_reader_view.dart:3218`（仅“换源”） | 仅迁移了换源候选流程 | 源内登录、付费、编辑、禁用入口缺失 |
| D-03 | 顶栏标题/章节点击跳转缺失 | `ReadMenu.kt:326`、`ReadMenu.kt:329`（书籍信息/章节链接） | `reader_menus.dart:73`（纯文本展示） | 顶栏被改为只读展示 | 点击跳转层级不一致 |
| D-04 | 朗读动作语义不完整 | `ReadMenu.kt:472`、`ReadMenu.kt:477` + `ReadBookActivity.kt:1119` | `reader_bottom_menu.dart:334` + `simple_reader_view.dart:3190`（显示“暂未实现”） | TTS 扩展未解锁 | “朗读”按钮存在但核心行为不可达 |
| D-05 | 9 宫格动作集合含未实现动作 | `ClickActionConfigDialog.kt`（动作可执行） | `reading_settings.dart:893` + `simple_reader_view.dart:1766`（多动作 toast） | 动作枚举迁移先行，执行未补齐 | 配置可选但运行不可用，行为偏差 |
| D-06 | MoreConfig 配置项覆盖不足 | `pref_config_read.xml:5`~`201` | `reading_*_settings_view.dart` + `simple_reader_view.dart:4446` | 只迁移了部分高频项 | 多个 legado 配置项无等价入口 |
| D-07 | 鼠标滚轮翻页开关语义缺失 | `pref_config_read.xml:90`（`mouseWheelPage` 可开关） | `simple_reader_view.dart:1700`（滚轮固定生效） | 未迁移开关状态位 | 无法按 legado 关闭滚轮翻页 |
| D-08 | 亮度交互细节不一致 | `ReadMenu.kt:378`、`ReadMenu.kt:397`（自动亮度+左右换位） | `reader_bottom_menu.dart:272`（跟随系统+水平滑杆） | 跨平台交互实现重构 | 亮度行为同类但细节语义不同 |

## 逐项检查清单（实施前固定项）

| 检查项 | 结果 |
| --- | --- |
| 入口 | 已覆盖：全局入口、阅读页顶栏、底栏、弹窗入口均纳入矩阵 |
| 状态 | 已覆盖：菜单显隐、章节边界、自动翻页状态、亮度跟随状态 |
| 异常 | 已覆盖：无菜单兜底、未实现动作 toast、目录更新失败提示 |
| 文案 | 已覆盖：按钮文案与动作文案逐项核对 |
| 排版 | 已覆盖：分组结构与按钮热区层级（风格差异不计） |
| 交互触发 | 已覆盖：点击/长按/滑杆/开关触发路径 |
| 按钮 | 已覆盖：集合、排序、可见/可点击条件 |
| 跳转层级 | 已覆盖：一级/二级/三级入口与返回路径 |

## 实施步骤（执行记录）

### Step 1：对照基线固化（已完成）

- 做了什么：
  - 重新读取 legado 阅读器基准实现：`ReadMenu.kt`、`ReadBookActivity.kt`、`ReadStyleDialog.kt`、`TipConfigDialog.kt`、`MoreConfigDialog.kt`、`view_read_menu.xml`、`pref_config_read.xml`。
  - 读取 soupreader 对应实现：`simple_reader_view.dart`、`reader_menus.dart`、`reader_bottom_menu.dart`、`reading_*settings_view.dart`、`reading_settings.dart`。
- 为什么：
  - 确保差异结论来自代码事实，不依赖历史计划摘要。
- 如何验证：
  - 对照文件均有逐段读取记录（见本计划各矩阵证据路径）。
- 兼容影响：
  - 仅文档排查，无运行时代码改动。

### Step 2：按钮与菜单对照矩阵（已完成）

#### Button & Menu Inventory Matrix

| 项目 | legado 基准 | soupreader 现状 | 结论 |
| --- | --- | --- | --- |
| 底栏四按钮顺序 | `目录 -> 朗读 -> 界面 -> 设置`（`view_read_menu.xml:288`） | `reader_bottom_menu.dart:324` | `已同义` |
| 章节滑杆与上下章 | `tv_pre/seek_read_page/tv_next`（`view_read_menu.xml:233`） | `reader_bottom_menu.dart:133` | `已同义` |
| 快捷动作区按钮集合 | `搜索/自动翻页/替换/夜间`（`view_read_menu.xml:137`） | `搜索/书签/目录/朗读/界面/设置`（`simple_reader_view.dart:3099`） | `不一致` |
| 书源动作入口 | `tvSourceAction` 弹出菜单（`ReadMenu.kt:368`） | 顶栏“换源”单动作（`reader_menus.dart:102`） | `不一致` |
| 顶栏书名/章节点击 | 可打开书籍信息/章节链接（`ReadMenu.kt:326`） | 顶栏文本不可点击（`reader_menus.dart:73`） | `不一致` |
| 朗读长按入口 | 长按打开朗读配置（`ReadMenu.kt:477`） | 无长按，仅点击（`reader_bottom_menu.dart:337`） | `部分同义` |
| 顶栏更多菜单 | legado 通过原菜单组合触发相关动作 | ActionSheet（搜索/自动翻页/书签/刷新/换源/更新目录）`simple_reader_view.dart:2644` | `部分同义` |
| 亮度条入口 | 亮度组件独立侧栏，可调位置（`ReadMenu.kt:397`） | 底部菜单内“亮度+跟随系统”`reader_bottom_menu.dart:272` | `部分同义` |

### Step 3：跳转层级与返回路径对照（已完成）

#### Navigation Hierarchy Matrix

| 入口层级 | legado 基准 | soupreader 现状 | 结论 |
| --- | --- | --- | --- |
| 全局阅读设置一级入口 | 通过阅读配置入口进入样式/设置分组 | `GlobalReadingSettingsView` 保持“界面（样式）/设置（行为）”`global_reading_settings_view.dart:20` | `已同义` |
| 阅读页“界面”入口 | `llFont -> showReadStyle()`（`ReadMenu.kt:483`） | `onShowInterfaceSettings -> _showReadingSettingsSheet(tabs 0/1)`（`simple_reader_view.dart:2576`） | `部分同义` |
| 阅读页“设置”入口 | `llSetting -> showMoreSetting()`（`ReadMenu.kt:490`） | `onShowBehaviorSettings -> _showReadingSettingsSheet(tabs 2/3)`（`simple_reader_view.dart:2585`） | `部分同义` |
| 书籍信息入口 | `titleBar.toolbar -> openBookInfoActivity()`（`ReadMenu.kt:326`） | 无等价点击入口 | `缺失` |
| 章节链接入口 | `tvChapterName/tvChapterUrl` 点击打开链接（`ReadMenu.kt:329`） | 无等价入口 | `缺失` |

### Step 4：`pref_config_read.xml` 配置项覆盖矩阵（已完成）

> legado 配置项基准：`/home/server/legado/app/src/main/res/xml/pref_config_read.xml:5`~`201`  
> 检索证据：`rg` 统计显示多项 key 在 `lib/` 命中为 `0`

| legado key | soupreader 对应项 | 结论 | 备注 |
| --- | --- | --- | --- |
| `screenOrientation` | 无 | `缺失` | 屏幕方向入口未迁移 |
| `keep_light` | `keepScreenOn`（`reading_other_settings_view.dart:43`） | `部分同义` | legado 为超时策略，当前为布尔开关 |
| `hideStatusBar` | `showStatusBar`（反向语义，`reading_status_action_settings_view.dart:45`） | `已同义` | 文案方向相反但语义等价 |
| `hideNavigationBar` | 无 | `缺失` | 导航栏显示策略未迁移 |
| `readBodyToLh` | 无 | `缺失` | 正文延伸策略未迁移 |
| `paddingDisplayCutouts` | 无 | `缺失` | 刘海区补边策略未迁移 |
| `doubleHorizontalPage` | 无 | `缺失` | 双页模式未迁移 |
| `progressBarBehavior` | `progressBarBehavior`（`simple_reader_view.dart:4457`） | `已同义` | |
| `useZhLayout` | 无 | `缺失` | 中式排版开关未迁移 |
| `textFullJustify` | `textFullJustify`（`reading_preferences_view.dart:341`） | `已同义` | |
| `textBottomJustify` | `textBottomJustify`（`simple_reader_view.dart:3688`） | `已同义` | 仅阅读内设置面板提供入口 |
| `mouseWheelPage` | 固定滚轮翻页（`simple_reader_view.dart:1700`） | `部分同义` | 功能存在但缺少开关 |
| `volumeKeyPage` | `volumeKeyPage`（`reading_page_settings_view.dart:62`） | `已同义` | |
| `volumeKeyPageOnPlay` | 无 | `缺失` | 与朗读联动项未迁移 |
| `keyPageOnLongPress` | 无 | `缺失` | 长按按键翻页未迁移 |
| `pageTouchSlop` | `pageTouchSlop`（`reading_page_settings_view.dart:43`） | `已同义` | |
| `autoChangeSource` | 无 | `缺失` | 自动换源开关未迁移 |
| `selectText` | 无 | `缺失` | 文本选择开关未迁移 |
| `showBrightnessView` | `showBrightnessView`（`reading_status_action_settings_view.dart:83`） | `已同义` | |
| `noAnimScrollPage` | `noAnimScrollPage`（`reading_page_settings_view.dart:49`） | `已同义` | |
| `previewImageByClick` | 无 | `缺失` | 图片预览行为开关未迁移 |
| `optimizeRender` | 无 | `缺失` | 渲染优化开关未迁移 |
| `clickRegionalConfig` | `点击区域（9宫格）`（`reading_status_action_settings_view.dart:96`） | `已同义` | |
| `disableReturnKey` | 无 | `缺失` | 返回键禁用开关未迁移 |
| `customPageKey` | 无 | `缺失` | 自定义翻页按键未迁移 |
| `expandTextMenu` | 无 | `缺失` | 扩展文本菜单未迁移 |
| `showReadTitleAddition` | 无 | `缺失` | 标题附加信息开关未迁移 |
| `readBarStyleFollowPage` | 无 | `缺失` | 菜单样式跟随页面未迁移 |

### Step 5：阻塞项归档与结论（已完成）

#### Blocked Exceptions（按 1.1.2 记录四要素）

| ID | 原因 | 影响范围 | 替代方案 | 回补计划 |
| --- | --- | --- | --- | --- |
| B-01 | 朗读引擎能力未解锁（扩展冻结计划） | 底栏“朗读”入口与 9 宫格朗读动作无法提供等价执行语义 | 保留入口并提供明确提示：`语音朗读（TTS）暂未实现`（`simple_reader_view.dart:3190`） | 待 `docs/plans/2026-02-19-reader-extensions-blocked-execplan.md` 解锁后迁移 ReadAloud 全链路 |
| B-02 | 9 宫格动作中的 `editContent/toggleReplaceRule/syncBookProgress/readAloud*` 未全部落地 | 用户可配置但点击后出现 toast，不是 legado 的可执行动作 | 运行时可观测提示，避免静默失败（`simple_reader_view.dart:1766`） | 扩展解锁后分批补齐动作执行器；未补齐前建议在 UI 层隐藏对应动作 |

#### 开放问题（非扩展冻结导致）

| ID | 问题 | 严重性 | 处理建议 |
| --- | --- | --- | --- |
| O-01 | 快捷动作区按钮集合与排序漂移 | 高 | 对齐为 legado `搜索/自动翻页/替换/夜间` |
| O-02 | 书源操作菜单（登录/付费/编辑/禁用）缺失 | 高 | 迁移 `tvSourceAction` 弹出菜单语义 |
| O-03 | 顶栏缺失书籍信息与章节链接点击入口 | 中 | 补齐点击热区与目标路由 |
| O-04 | `pref_config_read.xml` 多项配置缺失 | 高 | 按核心优先拆批回补，先补屏幕方向/导航栏/文本选择/按键相关 |

## 风险与回滚

- 本轮仅产出报告，未改运行时逻辑，因此不存在代码回滚动作。
- 风险在于：若直接宣称“已一致”会掩盖 `O-01~O-04` 的真实偏差，导致后续验收失败。

## 验收与证据

### 命令验证（本轮仅定向测试）

- 执行命令：
  - `flutter test test/reading_settings_navigation_parity_test.dart test/reader_bottom_menu_new_test.dart test/reading_behavior_settings_views_test.dart test/reading_tip_settings_view_test.dart test/reading_preferences_view_test.dart test/reading_settings_test.dart test/reader_source_switch_helper_test.dart test/reader_tip_selection_helper_test.dart`
- 结果：
  - `All tests passed!`
  - 说明：本轮未执行 `flutter analyze`，符合仓库“仅提交推送前执行一次”的约束。

### 手工回归路径（报告阶段待执行）

- 本轮为“排查报告版”，未执行人工 UI 回归。
- 下一轮修复实施后必须回归：
  - 阅读页开菜单 -> 顶栏动作全链路
  - 快捷动作区按钮集合与顺序
  - 底栏四按钮点击反馈与返回路径
  - `界面/设置` 下钻入口与返回路径
  - 9 宫格动作配置与执行

### 兼容影响

- 本轮无代码改动，对现网配置与书源兼容性无新增风险。
- 但台账显示当前仍存在行为偏差，尚不能宣称“与 legado 一致”。

## Progress

- [x] Step 1：基线文件完整读取与差异点重建
- [x] Step 2：按钮与菜单对照矩阵
- [x] Step 3：跳转层级对照矩阵
- [x] Step 4：`pref_config_read.xml` 配置项覆盖矩阵
- [x] Step 5：阻塞项归档与结论输出

## Surprises & Discoveries

- 发现阅读器内已经存在“全量设置面板（tabs 0/1/2/3）”，但与 legado `ReadStyleDialog + MoreConfigDialog` 的按钮集合仍有明显漂移（特别是快捷动作区）。
- 发现 `clickActions` 枚举先于执行器落地，导致多个动作“可配置但不可执行”。
- 发现 `pref_config_read.xml` 中大量 legacy key 在 `lib/` 中命中为 `0`，属于真实缺失而非命名差异。

## Decision Log

- 决策 1：本轮按“报告版”执行，不做业务代码修复。
  - 原因：需求已明确选择“先只出排查报告”。
- 决策 2：扩展能力维持冻结，不借本轮排查绕过“扩展解锁”规则。
  - 原因：遵循核心优先策略与既有扩展冻结计划。
- 决策 3：一致性结论采用“已同义/部分同义/缺失/blocked”四级，不使用“基本一致”。
  - 原因：避免验收语义模糊。

## Outcomes & Retrospective

- 本轮输出了可执行的全量差异台账，覆盖按钮、菜单、路由层级、配置项。
- 核心结论：
  - `已同义`：底栏四按钮顺序、章节滑杆、状态栏部分开关、9 宫格基础兜底。
  - `未同义`：快捷动作区、书源操作菜单、顶栏点击入口、大量 MoreConfig 配置项。
  - `blocked`：朗读与部分点击动作执行链路（扩展冻结）。
- 后续修复建议（按优先级）：
  1. 先修 `O-01/O-02/O-03`（用户感知最强的按钮与入口偏差）。
  2. 再分批补齐 `pref_config_read.xml` 核心配置项。
  3. 扩展解锁后处理 `B-01/B-02`。
