# Legado -> SoupReader RSS 书源导入链路同义迁移（T6A Step1）

- 状态：`active`
- 负责人：`Source-RSS`
- 更新时间：`2026-02-20`
- 范围类型：迁移级别（核心功能）

## 背景与目标

### 背景

- 主计划 `docs/plans/2026-02-20-source-management-reader-full-parity-execplan.md` 在 `T4-01` 标记：RSS 管理缺失导入入口（本地/网络/扫码/默认导入），属于 `高` 优先级缺口。
- 已完整读取 legado 对应实现（先读后改）：
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/rss/source/manage/RssSourceActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/rss/source/manage/RssSourceViewModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/association/ImportRssSourceDialog.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/association/ImportRssSourceViewModel.kt`
  - `/home/server/legado/app/src/main/res/menu/rss_source.xml`
  - `/home/server/legado/app/src/main/assets/defaultData/rssSources.json`
- SoupReader 现状 `lib/features/rss/views/rss_source_manage_view.dart` 仅保留“新增/筛选/跳转订阅页”，未提供导入链路。

### 目标

- 在 RSS 管理页补齐 legado 同义导入入口与流程：
  - 本地导入
  - 网络导入
  - 扫码导入
  - 默认订阅源导入
- 补齐导入前选择面板语义：新增/更新/已有状态、默认勾选策略、保留本地字段策略、自定义分组（覆盖/追加）。
- 保持可观测输出（导入统计、错误摘要、取消提示）。

### 非目标

- 本轮不处理 `T4-02`（RSS 批量操作菜单族），该项在 `T6A Step2` 单独推进。
- 不改造 RSS 订阅阅读流程（文章列表/阅读页）。
- 不触发扩展冻结能力（TTS/漫画/朗读）。

### 成功标准

- RSS 管理页存在并可触发四类导入入口。
- 导入选择面板可完成“勾选 + 策略 + 提交”，并正确写入仓库。
- 定向测试覆盖导入解析、选择策略和页面编译。

## 差异点清单（实现前）

| ID | 差异 | legado 基准 | soupreader 现状 | 影响 |
| --- | --- | --- | --- | --- |
| RS-IMP-01 | 导入入口缺失 | `rss_source.xml` + `RssSourceActivity.onCompatOptionsItemSelected` 提供本地/网络/扫码/默认导入 | `rss_source_manage_view.dart` 无导入入口 | RSS 迁移与接入效率明显下降 |
| RS-IMP-02 | 导入选择流程缺失 | `ImportRssSourceDialog` + `ImportRssSourceViewModel`：新增/更新/已有、默认勾选、保留策略、自定义分组 | 当前仅支持手工新增/编辑单条 | 导入覆盖策略不可控，无法同义复刻 legado 行为 |
| RS-IMP-03 | 默认源导入缺失 | `RssSourceViewModel.importDefault()` 读取 `defaultData/rssSources.json` | 未提供默认 RSS 导入能力 | 初次使用启动成本高 |

## 逐项检查清单（实施前固定项）

| 检查项 | 检查内容 | 状态 |
| --- | --- | --- |
| 入口 | 四类导入入口可见且可触发 | 待执行 |
| 状态 | 新增/更新/已有判定与默认勾选同义 | 待执行 |
| 异常 | 错误格式、空内容、网络异常、取消导入均有反馈 | 待执行 |
| 文案 | 导入状态与策略文案保持业务语义同向 | 待执行 |
| 排版 | 导入面板信息层级与触发区语义清晰 | 待执行 |
| 交互触发 | 点击、勾选、全选、选择新增/更新、提交链路可闭环 | 待执行 |
| 按钮 | 导入按钮禁用条件与数量提示正确 | 待执行 |
| 跳转层级 | RSS 管理页 -> 导入弹层 -> 返回路径稳定 | 待执行 |

## 实施步骤（含依赖/并行/验收）

### Step 1：基线对照与计划落盘（已完成）

- 依赖：无
- 并行性：串行
- 做了什么：完成 legado 与 soupreader RSS 管理/导入相关文件全量读取，形成本计划差异台账。
- 验证方式：差异点与检查清单落盘。

### Step 2：导入服务与策略 helper 落地（进行中）

- 依赖：Step 1
- 并行性：可与 Step 3 部分并行
- 做什么：
  - 新增 RSS 导入解析与导出服务；
  - 新增 RSS 导入候选/策略/提交计划 helper。
- 验证方式：新增服务层与 helper 单测。

### Step 3：RSS 管理页导入入口与弹层接入（待执行）

- 依赖：Step 2
- 并行性：串行
- 做什么：
  - 在 `RssSourceManageView` 接入四类导入入口；
  - 接入导入选择弹层与导入结果提示。
- 验证方式：页面编译测试 + 手工回归路径。

### Step 4：验证与文档回填（待执行）

- 依赖：Step 2、Step 3
- 并行性：串行
- 做什么：
  - 执行定向测试；
  - 回填主计划与本计划动态章节。
- 验证方式：`flutter test <定向测试文件>`。

## 风险与回滚

- 风险 1：导入 JSON 兼容路径不全导致部分 legado 书源文本导入失败。
  - 回滚：保持现有手工新增路径可用，并保留错误提示。
- 风险 2：导入策略覆盖本地字段导致用户已有配置被替换。
  - 回滚：默认保持“保留本地字段”开启，且导入前显式可切换。
- 风险 3：默认 RSS 资源路径错误导致“默认导入”失效。
  - 回滚：导入失败时给出可观测提示，不阻断其它导入入口。

## 验收与证据

### 命令验证

- 本轮仅执行与改动相关定向测试。
- 不执行 `flutter analyze`（遵守提交前仅一次约束）。

### 手工回归路径（计划）

1. RSS 管理页 -> 更多 -> 本地导入。
2. RSS 管理页 -> 更多 -> 网络导入（含历史记录）。
3. RSS 管理页 -> 更多 -> 扫码导入。
4. RSS 管理页 -> 更多 -> 导入默认订阅源。
5. 导入弹层中切换“保留策略/自定义分组”后提交并验证结果。

## Progress

- [x] Step 1：基线对照与计划落盘
- [ ] Step 2：导入服务与策略 helper 落地
- [ ] Step 3：RSS 管理页导入入口与弹层接入
- [ ] Step 4：验证与文档回填

## Surprises & Discoveries

- legado 的 RSS 导入流程支持 `json array`、`sourceUrls` 聚合对象、URL、URI 文本等多输入形态，且内置“新增/更新/已有”状态判定。
- 当前 SoupReader RSS 管理已有分组筛选与编辑能力，但导入链路是结构性缺失，不是单点按钮遗漏。

## Decision Log

- 决策 1（2026-02-20）：先执行 `T6A Step1`（导入链路），再执行 `T6A Step2`（批量菜单族）。
  - 理由：`T4-01` 是 `高` 优先级且对迁移效率影响最大。
- 决策 2（2026-02-20）：导入选择面板沿用 legado 核心语义（状态 + 默认勾选 + 保留策略 + 自定义分组）。
  - 理由：避免“仅有入口、无同义导入策略”造成行为偏差。

## Outcomes & Retrospective

- 当前为执行中计划，待 Step2~Step4 完成后回填结果与证据。
