# ExecPlan 索引

本仓库迁移任务遵循 AGENTS 中 ExecPlan 机制。复杂功能与跨模块迁移必须先落盘计划再实现。

## 活跃计划

1. `docs/plans/2026-02-20-source-management-reader-full-parity-execplan.md`
   - 标题：Legado -> SoupReader 书源管理与阅读器全功能同义排查与迁移总计划（除 UI 风格外完全一致）
   - 状态：`active`
   - 当前焦点：`T6A`（书源管理同义迁移）与 `T6B`（阅读器核心同义迁移）
   - 最新进展：`T1~T5`（基线读取 + 升级矩阵 + 差异台账 + 逐项检查清单）已完成，`O-04 Step1`（方向/系统栏/按键）已完成
   - 已确认例外：`EX-CF-01`（仿真翻页 simulation 的 shader 实现不修改）
   - 扩展口径：`EX-BLK-EXT-01`（TTS/漫画/朗读当前阶段暂不做，保持 `blocked`）

## 阻塞计划

1. `docs/plans/2026-02-20-reader-source-action-menu-core-parity-execplan.md`
   - 标题：Legado -> SoupReader 阅读器书源操作菜单同义迁移（登录/章节购买/编辑书源/禁用书源）
   - 状态：`blocked`
   - 阻塞点：`EX-SA-01`（章节 `isVip/isPay` 未持久化，章节购买可见条件无法精确同义）；`EX-SA-02`（`payAction` 缺少 legado `AnalyzeRule` 完整运行时上下文）

2. `docs/plans/2026-02-19-reader-core-config-parity-execplan.md`
   - 标题：Legado -> SoupReader 核心链路与阅读器配置迁移（按钮/排版/跳转层级/交互一致）
   - 状态：`blocked`
   - 阻塞点：历史步骤 `S3B-07-R1` 需并入“全功能主计划”重排；`flutter analyze` 仍有仓库级既有告警待后续清理

3. `docs/plans/2026-02-19-reader-extensions-blocked-execplan.md`
   - 标题：Legado -> SoupReader 扩展阅读能力冻结（漫画/TTS/朗读引擎）
   - 状态：`blocked`
   - 口径：需求方 `2026-02-20` 最新确认“扩展暂不做”，待“开始做扩展功能”指令后再解锁

## 已完成计划

1. `docs/plans/2026-02-20-reader-ui-core-parity-audit-execplan.md`
   - 标题：Legado -> SoupReader 阅读器界面全量一致性排查（核心范围，报告版）
   - 状态：`done`
   - 结论：完成全量排查台账；当前一致性结论为“未达成完全同义”，并已记录 `O-01~O-04` 开放问题与 `B-01/B-02` 阻塞项

2. `docs/plans/2026-02-20-reader-quick-actions-core-parity-execplan.md`
   - 标题：Legado -> SoupReader 阅读器快捷动作区四按钮同义迁移（搜索/自动翻页/替换规则/夜间模式）
   - 状态：`done`
   - 结论：完成 `O-01`，快捷动作区已收敛为 legado 四按钮顺序并补齐替换规则入口/日夜切换/自动翻页状态反馈

3. `docs/plans/2026-02-20-reader-topbar-bookinfo-chapter-link-core-parity-execplan.md`
   - 标题：Legado -> SoupReader 阅读页顶栏入口同义迁移（书籍信息/章节链接）
   - 状态：`done`
   - 结论：完成 `O-03`，已补齐顶栏书名详情入口与章节链接点击/长按打开方式切换，并补齐 URL 规整与回归测试

4. `docs/plans/2026-02-20-reader-more-config-core-step1-execplan.md`
   - 标题：Legado -> SoupReader 阅读器 MoreConfig 核心配置迁移（O-04 Step1：方向/系统栏/按键）
   - 状态：`done`
   - 结论：完成 `MC-01~MC-05`，已补齐方向/系统栏/滚轮/长按按键/返回键五项配置的“入口 + 持久化 + 运行时生效”闭环

## 状态定义

- `draft`：草案，未进入实现
- `active`：实施中
- `blocked`：遇到阻塞或例外，待确认
- `done`：计划完成并具备验收证据
