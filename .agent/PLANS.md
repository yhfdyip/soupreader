# ExecPlan 索引（.agent）

## 活跃计划

### 1) 2026-02-20 阅读器设置界面（段距/字距）Legado 同义排查与迁移
- 状态：`blocked`
- 范围：阅读器内设置面板（核心：排版设置入口、段距/字距/行距/字号、页面排版结构）
- 非目标：书源链路、搜索链路、扩展阅读能力（TTS/漫画）
- 成功标准：
  - 入口层级与交互路径对齐 legado `ReadStyleDialog`
  - 段距/字距等控件顺序、文案、显示语义与 legado 同义
  - 布局结构（顶部动作行、滑条区、分割线、翻页动画区、样式区）在 Flutter 实现下语义对齐

#### 背景与目标
- 用户要求排查“阅读器设置界面是否与 legado 一致”，重点点名“段距、字距”，并要求界面排版完全一致。
- 现状是 soupreader 使用自定义多 Tab 卡片式设置面板，与 legado 的单面板 `ReadStyleDialog` 存在结构差异。

#### 逐项检查清单（实现前）
- [x] 入口：菜单动作是否进入阅读样式设置同层级入口
- [x] 状态：字号/字距/行距/段距状态字段是否可读可写并持久化
- [x] 异常：滑条边界与非法值是否有兜底（sanitize）
- [x] 文案：控件标题是否与 legado 同语义
- [x] 排版：顶部动作、滑条顺序、分割线、翻页动画块、样式块
- [x] 交互触发：加减按钮、拖动、分段选择、二级弹层入口

#### 差异点清单（实现前）
1. 入口层级差异
- legado：`../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt:1208` 直接 `showDialogFragment<ReadStyleDialog>()`
- soupreader：`lib/features/reader/views/simple_reader_view.dart:2664` 进入 `_showReadingSettingsSheet`（`allowedTabs: [0,1]`）
- 影响：用户到达“阅读样式”不是单一主面板，心智路径不一致

2. 主布局结构差异
- legado：`../legado/app/src/main/res/layout/dialog_read_book_style.xml` 为单纵向结构（顶部动作行 -> 4 条 DetailSeekBar -> 分割线 -> 翻页动画 -> 分割线 -> 样式区）
- soupreader：`lib/features/reader/views/simple_reader_view.dart:4289` 起为“多卡片 + 多分区 + 高级入口”
- 影响：信息层级和热区位置不一致

3. 段距/字距顺序与语义差异
- legado 顺序：字号 -> 字距 -> 行距 -> 段距（`dialog_read_book_style.xml:130-163`）
- soupreader 顺序：字号 -> 行距 -> 段距 -> 字距（`simple_reader_view.dart:4301-4343`）
- 影响：肌肉记忆与调参预期不一致

4. 数值映射差异
- legado：
  - 字号 `progress 0..45 => value 5..50`（`ReadStyleDialog.kt:78,147,190`）
  - 字距 `progress 0..100 => (p-50)/100 => -0.5..0.5`（`ReadStyleDialog.kt:81,150,191`）
  - 行距 `progress 0..20 => (p-10)/10 => -1..1`（`ReadStyleDialog.kt:84,153,192`）
  - 段距 `progress 0..20 => p/10 => 0..2`（`ReadStyleDialog.kt:85,156,193`）
- soupreader：字号/字距/行距/段距均采用另一套范围（`simple_reader_view.dart:4301-4343`）
- 影响：同名参数的调节手感和显示值不一致

5. 控件样式差异
- legado：`DetailSeekBar` 带固定 `title(60dp) + 减 + Slider + 加 + 值(60dp)`（`view_detail_seek_bar.xml:8-56`）
- soupreader：当前简化滑条行，无独立减/加按钮（`simple_reader_view.dart:5664-5708`）
- 影响：交互反馈和操作密度不一致

6. 样式管理能力缺口（记录）
- legado 样式区含“新增/长按编辑样式”能力（`ReadStyleDialog.kt:88-96,176-236` + `item_read_style.xml`）
- soupreader 目前仅支持预置主题切换，本轮新增了 `shareLayout` 持久化字段与复选框，但“新增/编辑样式”仍无等价实现
- 影响：样式区交互尚未完全同义，需后续补齐数据模型与编辑流程

#### 实施步骤
1. `S1`（已完成）：完成双仓定位与逐项检查清单、差异点清单落盘。
- 验证：路径与行号可追溯。

2. `S2`（已完成）：重排 soupreader 阅读样式主面板结构，使其同义于 legado 核心布局。
- 预期结果：
  - 入口优先进入“样式主面板”
  - 顶部动作行/滑条顺序/分割线/翻页动画区/样式区按 legado 结构呈现
- 验证：手工路径回归（阅读器 -> 菜单 -> 界面/阅读样式）

3. `S3`（已完成）：对段距/字距等滑条改为 legado 同义显示与交互（含减/加按钮）。
- 预期结果：显示语义和边界与 legado 对齐
- 验证：逐项操作后观察值变化与预期

4. `S4`（已完成）：输出逐项对照清单并更新动态章节。
- 预期结果：明确“已同义项/保留差异项”
- 验证：文档核对完整

#### 风险与回滚
- 风险1：同一文件 `simple_reader_view.dart` 近期变更多，改动冲突风险高。
  - 缓解：仅在阅读设置相关函数内局部改动，不触碰无关逻辑。
- 风险2：现有 `ReadingSettings` 数值语义与 legado 不完全等价。
  - 缓解：先做 UI 显示与交互映射对齐，保留模型层深度重构为后续项。
- 回滚策略：按函数粒度回退本次新增 UI 构建函数与调用点。

#### 验收与证据
- 命令验证：
  - `flutter test test/reading_settings_test.dart test/simple_reader_view_compile_test.dart`（通过）
  - 未执行 `flutter analyze`（按仓库规则仅提交前执行一次）
- 手工路径：
  1. 打开阅读器
  2. 打开阅读菜单
  3. 进入“界面/阅读样式”
  4. 检查顶部动作行、4 条滑条、翻页动画区、样式区
  5. 调整字距/段距并观察显示值、实际效果

#### 逐项对照清单（实现后）
- 入口：`simple_reader_view.dart` 中“界面”入口已改为 `_showReadStyleDialog`，与 legado 的单入口语义对齐（已同义）。
- 状态：新增 `ReadingSettings.shareLayout` 并持久化，字号/字距/行距/段距状态均可读写（已同义）。
- 异常：4 条滑条均做边界夹取，减/加按钮具备上下界禁用反馈（已同义）。
- 文案：滑条标题与区块标题按 legado 语义重排为“字号/字距/行距/段距 + 翻页动画 + 背景文字样式”（已同义）。
- 排版：顶部动作行、DetailSeekBar 结构、两条分割线、翻页动画区、样式区顺序已对齐（已同义）。
- 交互触发：滑条拖动、减/加、翻页动画切换、主题切换、shareLayout 复选框切换均可触发（已同义）。
- 保留差异：样式区“新增/编辑样式”仍未等价实现，仅保留“+”占位单元（未同义，阻塞项）。
- 兼容影响：`readingSettings` JSON 新增 `shareLayout` 字段（默认 `true`，向后兼容旧配置）。

#### Progress
- 2026-02-20 16:58
  - 已完成：`S1`（差异排查与清单）
  - 进行中：`S2`
  - 剩余：`S3`、`S4`
- 2026-02-20 18:11
  - 已完成：`S2`（入口与主布局重排）
  - 已完成：`S3`（4 条滑条映射 + 减/加按钮）
  - 已完成：`S4`（逐项对照清单与证据回填）
  - 当前阻塞：样式区“新增/编辑样式”无等价实现

#### Surprises & Discoveries
- 发现 1：当前工作区存在大量既有改动（含历史 ExecPlan 删除），本次只在目标文件局部增量修改。
- 发现 2：`share_layout` 在 legado 样式面板中存在，本轮已补齐 `ReadingSettings.shareLayout` 字段与 UI 复选框。
- 发现 3：legado 样式区依赖可编辑样式列表（新增/长按编辑）；soupreader 当前主题列表为静态预置，缺少编辑链路。

#### Decision Log
- 决策 1：优先按“核心排版设置同义”推进（段距/字距/布局结构），扩展项不提前开发。
- 决策 2：先在现有模型上做显示/交互映射，避免本轮扩大到阅读排版引擎重构。
- 决策 3：行距沿 legado 显示语义映射为 `progress(0..20) <-> label(-1..1)`，内部写回 `lineHeight = 1 + (p-10)/10`，兼容现有 Flutter 渲染模型。
- 决策 4：段距沿 legado 显示语义映射为 `progress(0..20) -> label(p/10)`，内部先保留对既有段距字段的写入（避免扩大到排版引擎重构）。

#### Outcomes & Retrospective
- 已落地：
  - 阅读菜单“界面”入口改为 legado 同义单面板样式入口。
  - 样式面板结构重排为：顶部动作行 -> 4 条 DetailSeekBar -> 分割线 -> 翻页动画 -> 分割线 -> 背景样式区。
  - 字号/字距/行距/段距控件顺序、显示语义、减/加交互均完成迁移。
  - 新增 `shareLayout` 设置项并持久化。
- 未闭合：
  - 样式区“新增/编辑样式”仍缺数据结构与编辑流程，当前为阻塞项；需需求方确认是否进入下一阶段补齐。
