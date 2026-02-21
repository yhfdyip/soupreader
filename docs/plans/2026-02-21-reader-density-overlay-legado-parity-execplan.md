# 2026-02-21 阅读器正文铺满与菜单分层对齐 legado（content C5）

状态：`done`

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
- `test/reading_settings_test.dart`

## 非目标
- 不改书源解析链路（search/explore/bookInfo/toc/content 抓取与规则执行）。
- 不引入新的业务入口或扩展开关。
- 不执行 `flutter analyze`（遵循仓库约束）。

## legado 对照文件（已读取）
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/res/layout/view_read_menu.xml`

## 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D1 | `ReadingSettings` 默认值 | `ReadBookConfig.Config` 默认排版 | 默认字号/行距/段距/边距更松 | 单屏内容量偏少 |
| D2 | 阅读菜单透明策略 | `view_read_menu.xml` + `ReadMenu` | 顶部菜单渐变透出正文 | 顶部/正文边界不清 |
| D3 | 配置弹层遮挡 | `ReadStyleDialog`/`MoreConfigDialog` | iOS 弹层 dim 与高度偏大 | 配置态遮挡感偏重 |

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

## 验收与证据
- 自动化测试（通过）：
  - `flutter test test/reading_settings_test.dart test/simple_reader_view_compile_test.dart test/reader_top_menu_test.dart test/reader_bottom_menu_new_test.dart test/app_settings_test.dart`
- 手工回归路径（待真机截图补充）：
  - C5：阅读页 -> 正文阅读 -> 打开菜单 -> 顶部栏/底部栏分层观察。
  - C5：阅读页 -> 界面/设置/信息弹层 -> 观察遮挡面积与关闭恢复。

## 兼容影响
- 低到中：
  - `ReadingSettings` 新增 `layoutPresetVersion` 字段；对旧默认值会执行一次迁移（用户自定义值不覆盖）。
  - 不涉及数据库结构、书源协议、网络接口。

## Progress
- [done] 默认排版参数对齐 legado v2。
- [done] 历史默认值迁移与版本化落盘。
- [done] 顶/底菜单分层与配置态遮挡优化。
- [done] 定向测试与计划记录回填。

## Surprises & Discoveries
- legacy 的菜单 dim 语义更接近“无遮罩”，而非 iOS 默认半透明遮罩；直接使用默认 `showCupertinoModalPopup` 会放大遮挡体感。
- 仅靠改 UI 透明度无法解决“内容不满”，默认排版参数与历史数据迁移必须一起做。

## Decision Log
- 决策 1：保留用户自定义值，只迁移“旧默认值”字段，避免强制覆盖。
- 决策 2：按 legado 语义优先，配置弹层减少 dim，优先保证正文可见。
- 决策 3：不引入新入口，限定在阅读器 C5 路径收敛。

## Outcomes & Retrospective
- 做了什么：完成正文密度参数与菜单分层联动收敛，补齐旧设置兼容迁移。
- 为什么：提升阅读信息密度，减少菜单/配置态干扰，贴近 legado 行为。
- 如何验证：模型/编译/组件/设置服务相关定向测试均通过。
