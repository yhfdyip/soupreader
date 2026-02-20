# Legado -> SoupReader 阅读器 MoreConfig 核心配置迁移（O-04 Step1：方向/系统栏/按键）

- 状态：`done`
- 负责人：`Reader-UI`
- 更新时间：`2026-02-20`
- 范围类型：迁移级别（核心功能）

## 背景与目标

### 背景

- `docs/plans/2026-02-20-reader-ui-core-parity-audit-execplan.md` 记录 `O-04`：`pref_config_read.xml` 存在多项核心配置缺口。
- 已完成 `O-01/O-03`，`O-02` 进入阻塞例外收口；下一项进入 `O-04` 的核心可闭环子集。
- legado 对应实现已完整复读：
  - `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/BaseReadBookActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/config/AppConfig.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/constant/PreferKey.kt`

### 目标

- 回补本轮核心项并确保运行时生效：
  - `screenOrientation`（阅读页方向）
  - `hideNavigationBar`（系统导航栏隐藏策略）
  - `mouseWheelPage`（鼠标滚轮翻页开关）
  - `keyPageOnLongPress`（按键长按翻页语义）
  - `disableReturnKey`（返回键禁用）
- 保持用户可见入口、状态流转、边界提示与 legado 同义。

### 非目标

- 本轮不处理扩展冻结项（朗读/TTS/漫画）。
- 本轮不处理 `selectText` 完整可选中文本能力（独立子任务处理）。
- 本轮不处理 `customPageKey`、`volumeKeyPageOnPlay` 等依赖更大按键体系的子项。

### 成功标准

- 上述 5 个配置项具备：`设置入口 -> 持久化 -> 阅读页生效` 闭环。
- 定向测试覆盖配置解析/按键行为/页面基础编译。
- ExecPlan 动态章节完整回填（含兼容影响）。

## 差异点清单（含文件位置/原因/影响）

| ID | 差异 | legado 基准 | soupreader 现状 | 原因 | 影响 |
| --- | --- | --- | --- | --- | --- |
| MC-01 | `screenOrientation` 缺失 | `BaseReadBookActivity.setOrientation()` | 无阅读页方向设置与应用逻辑 | 未迁移对应字段与系统调用 | 无法按阅读配置锁定方向 |
| MC-02 | `hideNavigationBar` 缺失 | `upSystemUiVisibility(toolBarHide, hideNavigationBar)` | 仅按菜单态切 `SystemUiMode` | 缺少配置位与显隐矩阵 | 系统栏行为与 legado 偏离 |
| MC-03 | `mouseWheelPage` 缺失 | `ReadBookActivity.mouseWheelPage()` 受 `AppConfig.mouseWheelPage` 控制 | 滚轮翻页恒生效 | 缺少配置开关 | 桌面/模拟器滚轮行为不可控 |
| MC-04 | `keyPageOnLongPress` 缺失 | `handleKeyPage()` 长按语义分支 | 键盘事件无长按策略开关 | 未迁移长按配置位 | 按键翻页节奏与 legado 不同 |
| MC-05 | `disableReturnKey` 缺失 | 返回键拦截分支 | `PopScope` 默认会在阅读态弹出菜单 | 无对应配置位 | 无法实现“返回键禁用”语义 |

## 逐项检查清单（实施前固定项）

| 检查项 | 检查内容 | 当前状态 |
| --- | --- | --- |
| 入口 | 全局设置页与阅读页设置面板均可配置 | 通过 |
| 状态 | 配置变更后即时生效，重进可恢复 | 通过 |
| 异常 | 非法值回退、平台不支持时有兜底 | 通过 |
| 文案 | 与 legado 业务语义同向（非字面强制） | 通过 |
| 排版 | 设置分组与条目顺序稳定，不混入扩展项 | 通过 |
| 交互触发 | 点击/开关/键盘/滚轮/返回键触发路径同义 | 通过 |
| 按钮 | 开关可见条件、默认值、点击反馈一致 | 通过 |
| 跳转层级 | 设置入口层级与返回路径不变 | 通过 |

## 实施步骤（含依赖/并行/验收）

### Step 1：基线固化与计划落盘（已完成）

- 依赖：无
- 并行性：串行
- 做了什么：完成 legado 相关文件完整复读并落盘差异点。
- 验证方式：本计划 `MC-01~MC-05` 与复读文件清单已落盘。

### Step 2：配置模型与持久化补齐（已完成）

- 依赖：Step 1
- 并行性：串行
- 做什么：
  - 在 `ReadingSettings` 新增字段与序列化/反序列化/sanitize。
  - 在设置页增加对应配置入口。
- 验证方式：模型单测 + 设置页 widget 测试。

#### Step 2 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - `lib/features/reader/models/reading_settings.dart`
    - 新增 `hideNavigationBar/mouseWheelPage/keyPageOnLongPress/disableReturnKey/screenOrientation` 字段；
    - 同步 `fromJson/toJson/sanitize/copyWith`；
    - 新增 `ReaderScreenOrientation` 标签工具。
  - `lib/core/services/settings_service.dart`
    - 阅读设置 schema 版本从 `2` 升到 `3`，确保新增字段统一回写。
  - 设置页补齐入口：
    - `lib/features/settings/views/reading_page_settings_view.dart`
    - `lib/features/settings/views/reading_status_action_settings_view.dart`
    - `lib/features/settings/views/reading_other_settings_view.dart`
    - `lib/features/settings/views/reading_behavior_settings_hub_view.dart`
- 为什么：
  - 先闭环“配置项可持久化 + 可配置入口可见”，再接入运行时行为，避免“行为接入后无入口可调”的验收死角。
- 如何验证：
  - `flutter test test/reading_settings_test.dart`
  - `flutter test test/reading_behavior_settings_views_test.dart`
- 兼容影响：
  - 旧配置会按默认值自动迁移并持久化新增字段；无数据库 schema 变更。

### Step 3：阅读页运行时行为接入（已完成）

- 依赖：Step 2
- 并行性：可与 Step 4 部分并行
- 做什么：
  - 接入方向锁定。
  - 接入系统栏显隐矩阵。
  - 接入滚轮开关、长按按键语义、返回键禁用。
- 验证方式：helper/行为单测 + 编译测试。

#### Step 3 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 新增 `lib/features/reader/services/reader_system_ui_helper.dart`：
    - `screenOrientation` 到 `DeviceOrientation` 的映射；
    - 菜单态/阅读态的系统栏显隐矩阵映射（`showStatusBar + hideNavigationBar`）。
  - `lib/features/reader/views/simple_reader_view.dart`：
    - 增加方向同步与离开页面恢复默认方向；
    - 系统 UI 改为“配置+菜单态”驱动，而非固定沉浸模式；
    - 鼠标滚轮翻页受 `mouseWheelPage` 控制；
    - `KeyRepeatEvent` 受 `keyPageOnLongPress` 控制；
    - `PopScope` 增加 `disableReturnKey` 分支（阅读态禁用返回键时不弹菜单不退出）。
- 为什么：
  - 对齐 legado `MoreConfigDialog + BaseReadBookActivity + ReadBookActivity` 的状态机语义。
- 如何验证：
  - `flutter test test/reader_system_ui_helper_test.dart test/reader_key_paging_helper_test.dart`
  - `flutter test test/simple_reader_view_compile_test.dart`
- 兼容影响：
  - 阅读页系统栏行为由配置项控制，默认值保持 legacy 默认（状态栏显示、导航栏不隐藏）。
  - 不影响扩展冻结链路（朗读/TTS/漫画）。

### Step 4：验证与文档回填（已完成）

- 依赖：Step 2、Step 3
- 并行性：串行
- 做什么：执行定向测试并回填动态章节。
- 验证方式：`flutter test <定向测试文件>`。

#### Step 4 实施记录（做了什么 / 为什么 / 如何验证 / 兼容影响）

- 做了什么：
  - 执行本任务所有定向测试并回填计划动态章节；
  - 同步 `PLANS.md` 活跃索引，标记本子任务完成态。
- 为什么：
  - 满足迁移级任务“证据 + 记录 + 结论”闭环要求。
- 如何验证：
  - `flutter test test/reading_settings_test.dart`
  - `flutter test test/reader_system_ui_helper_test.dart test/reader_key_paging_helper_test.dart`
  - `flutter test test/reading_behavior_settings_views_test.dart test/simple_reader_view_compile_test.dart`
- 兼容影响：
  - 未执行 `flutter analyze`（遵守“提交前仅一次”）；本轮仅定向验证。

## 风险与回滚

- 风险 1：系统栏显隐在不同平台表现差异。
  - 回滚：保持现有菜单态显隐逻辑，关闭新开关入口。
- 风险 2：方向锁定若未恢复可能影响离开阅读页后的页面。
  - 回滚：在 `dispose` 强制恢复默认方向策略。
- 风险 3：按键长按策略可能影响现有键盘用户习惯。
  - 回滚：默认值保持 legado（`false`），仅用户开启后生效。

## 验收与证据

### 命令验证

- 本轮仅执行与改动相关的定向测试。
- 不执行 `flutter analyze`（遵守“提交前仅一次”）。
- 已执行：
  - `flutter test test/reading_settings_test.dart`
  - `flutter test test/reader_system_ui_helper_test.dart test/reader_key_paging_helper_test.dart`
  - `flutter test test/reading_behavior_settings_views_test.dart test/simple_reader_view_compile_test.dart`
- 结果：
  - `All tests passed`

### 手工回归路径

1. 阅读设置 -> 切换方向模式 -> 返回阅读页验证方向锁定。
2. 阅读设置 -> 切换隐藏导航栏 -> 菜单显隐状态下验证系统栏行为。
3. 阅读设置 -> 关闭鼠标滚轮翻页 -> 滚轮不再翻页。
4. 阅读设置 -> 开启/关闭长按按键翻页 -> 长按翻页行为变化可见。
5. 阅读设置 -> 开启禁用返回键 -> 阅读态返回键不再弹菜单/退出。

## Progress

- [x] Step 1：基线固化与计划落盘
- [x] Step 2：配置模型与持久化补齐
- [x] Step 3：阅读页运行时行为接入
- [x] Step 4：验证与文档回填

## Surprises & Discoveries

- legado 的系统栏控制不是“固定沉浸模式”，而是“菜单态强制显示 + 阅读态按 hideStatusBar/hideNavigationBar 分离控制”。
- Flutter 侧当前已存在 `showStatusBar`，但缺失导航栏与方向联动配置位。
- `flutter test` 在 root 环境会输出权限警告，但不影响测试执行结果；本轮命令均正常完成。

## Decision Log

- 决策 1：本轮只做 `MC-01~MC-05`，不并行拉入更大键位自定义能力。
  - 原因：保证单可交付点闭环，降低回归面。
- 决策 2：保持扩展冻结口径，不借按键改造引入朗读联动逻辑。
  - 原因：遵守核心优先约束。
- 决策 3：`selectText` 不在本轮实现，留在后续独立子任务。
  - 原因：当前阅读正文渲染以分页/画布排版为主，直接并入会扩大改动面并干扰本轮核心闭环。

## Outcomes & Retrospective

- 本轮完成 `MC-01~MC-05`：方向、导航栏、滚轮、长按按键、返回键五项已达成“入口 + 持久化 + 运行时生效”闭环。
- 保留差异：
  - `selectText` 未纳入本轮（已在非目标声明，后续单独拆分）。
- 下一步建议：
  1. 在 `O-04 Step2` 继续处理 `selectText` 与 `customPageKey` 等剩余配置项；
  2. 回到主计划推进 `T3/T4` 总对照矩阵与差异清单收口。
