# 阅读器样式中度优化与功能矩阵梳理（参考 legado）ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（核心 UI 同义 + 功能梳理，不改功能逻辑）`

## 背景与目标

### 背景

需求方提供阅读器现状截图（根目录 `IMG_6983.PNG`），要求：

1. 优化阅读器样式；
2. 梳理阅读器全部功能；
3. 指出按钮异常项（本轮先梳理不修逻辑）。

按仓库强约束，本轮对照 legado 基准：

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
- `/home/server/legado/app/src/main/res/layout/view_read_menu.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`

当前 soupreader 对应实现：

- `lib/features/reader/views/simple_reader_view.dart`
- `lib/features/reader/widgets/reader_menus.dart`
- `lib/features/reader/widgets/reader_bottom_menu.dart`
- `lib/features/reader/services/reader_legacy_menu_helper.dart`
- `lib/features/reader/models/reading_settings.dart`

### 目标（Success Criteria）

1. 样式：顶部菜单、右侧快捷栏、搜索浮层、底部菜单的层级/间距/遮挡体验改进，交互语义保持不变。
2. 梳理：输出“按钮-入口-行为-状态-legado 对照”功能矩阵文档，可直接用于后续修复排期。
3. 约束：不修改功能逻辑，不改变按钮触发目标，不引入扩展功能实现。
4. 验收：给出可复现的手工回归路径，并记录当前环境下的命令验证情况。

### 非目标（Non-goals）

1. 不实现 TTS/离线缓存/正文编辑/云端进度等占位能力。
2. 不变更抓取链路（search/explore/bookInfo/toc/content）。
3. 不进行无 legado 依据的功能重构。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| S1 | `reader_menus.dart:ReaderTopMenu` | `view_read_menu.xml:title_bar` | 顶栏控件密度高、书源标签长度未约束、正文沉浸感不足 | 顶栏遮挡感偏强 |
| S2 | `simple_reader_view.dart:_buildFloatingActionRail` | `view_read_menu.xml:ll_floating_button` | 右侧快捷栏底色偏重、按钮偏大、与正文抢视觉 | 阅读中断感增强 |
| S3 | `simple_reader_view.dart:_buildSearchMenuOverlay` | `ReadBookActivity` 搜索结果导航 | 搜索浮层边界弱、侧向翻找按钮与底面板风格不统一 | 搜索操作可读性一般 |
| S4 | `reader_bottom_menu.dart:ReaderBottomMenuNew` | `view_read_menu.xml:ll_bottom_bg` | 底栏虽然已同义结构，但边界与阴影层级还可收敛 | 工具层与正文分隔不清 |
| S5 | `simple_reader_view.dart:_executeLegacyReadMenuAction` | `ReadBookActivity` 对应回调 | 多个菜单项仍为占位提示 | 按钮“有问题”反馈持续存在 |

## 逐项检查清单（强制）

- 入口：顶部/右侧/底部/阅读操作菜单/点击区域动作均有文档映射。
- 状态：每个入口标注 `可用/占位/受限`。
- 异常：占位动作提示仍可观测，不出现静默点击无反馈。
- 文案：保持 legado 业务语义，不改功能名。
- 排版：顶部、右侧、底部、搜索浮层在同一视觉体系下。
- 交互触发：所有 onTap/onLongPress 目标函数保持不变。

## 实施步骤（含依赖与并行）

### Todo 列表（按依赖）

1. `T1`（串行，前置）建立本 ExecPlan 并更新索引。  
   依赖：无。
2. `T2`（串行，依赖 T1）产出阅读器功能矩阵文档（入口/状态/差异）。  
   依赖：T1。
3. `T3`（串行，依赖 T2）产出样式差异文档（soupreader vs legado）。  
   依赖：T2。
4. `T4`（并行，依赖 T3）实施样式中度优化。  
   分支 A：`reader_menus.dart` 顶栏；  
   分支 B：`simple_reader_view.dart` 右侧快捷栏/搜索浮层；  
   分支 C：`reader_bottom_menu.dart` 底栏质感优化。  
   依赖：T3。
5. `T5`（串行，依赖 T4）回填对照清单、验证记录与总结。  
   依赖：T4。

## 风险与回滚

### 失败模式

1. 样式收敛后小屏空间不足导致顶栏挤压或文字截断异常。
2. 快捷栏透明度调整不当，导致暗色主题对比不足。
3. 搜索浮层样式变更引入边界重叠（安全区/阴影裁切）。

### 阻塞条件（触发即 `blocked`）

1. 若发现样式改动必须连带功能逻辑改造才能成立，则暂停并记录例外。
2. 若 legado 对应语义无法确认，则停止继续改动该区域。

### 回滚策略

1. 按文件粒度回滚：`reader_menus.dart`、`simple_reader_view.dart`、`reader_bottom_menu.dart`。
2. 功能矩阵与样式差异文档独立保留，不随 UI 回滚丢失。

## 验收与证据

### 手工回归路径

1. 打开阅读器菜单，检查顶部标题区、右侧快捷栏、底部菜单遮挡与层级。
2. 打开正文搜索，验证左右导航按钮、底部结果面板的视觉一致性与可读性。
3. 逐个点击顶部/右侧/底部按钮，核对功能矩阵中的状态标注一致。
4. 打开“更多/阅读操作”，核对占位项提示可观测。

### 命令验证

- 开发阶段未执行 `flutter analyze`（遵守仓库规则：仅提交前执行一次）。
- 尝试定向测试时，当前环境出现 Flutter shader 资产写入异常（`build/unit_test_assets` 写入失败），已记录为环境限制。

## Progress

- `2026-02-20`：
  - 完成 `T1`：新增本 ExecPlan，并在 `PLANS.md` 建立索引。
  - 完成 `T2`：新增功能矩阵文档 `docs/reader/reader-feature-matrix-2026-02-20.md`。
  - 完成 `T3`：新增样式差异文档 `docs/reader/reader-style-diff-vs-legado-2026-02-20.md`。
  - 完成 `T4`：
    - `reader_menus.dart`：顶部菜单降噪（密度、宽度约束、层级边界）；
    - `simple_reader_view.dart`：右侧快捷栏与搜索浮层统一视觉语言；
    - `reader_bottom_menu.dart`：底栏阴影层级、字体节奏、亮度侧栏质感优化。
  - 完成 `T5`：回填本节、更新决策日志与结果总结。

## Surprises & Discoveries

1. “按钮有问题”与样式问题是两层问题：当前大量按钮已明确实现为占位提示，不是误触发。
2. 顶栏在小屏设备的主要风险来自“书源标签宽度”，需要约束上限才能保持操作区稳定。
3. 搜索浮层与右侧快捷栏此前采用不同视觉系统，统一后阅读干扰明显降低。

## Decision Log

1. 本轮严格执行“仅样式优化 + 功能梳理，不改功能逻辑”。
2. 所有回调与状态机保持原样，仅改视觉参数、边界、间距与组件容器样式。
3. 对占位能力不做“伪实现”，统一在功能矩阵中标记状态，留待后续修复任务。

## Outcomes & Retrospective

1. 阅读器主界面视觉层级更接近 legado 的“工具弱化、正文优先”语义。
2. 产出可执行的功能矩阵，为下一轮“按钮修复”直接提供排期输入。
3. 本轮未触碰功能逻辑，回归风险主要集中在布局与视觉，不影响主链路行为。
