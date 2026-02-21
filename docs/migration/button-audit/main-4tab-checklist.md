# 主入口与 4 Tab 对照清单（T06）

- 任务状态：`done`
- 对应计划：`PLANS.md` / `T06`
- 产出日期：`2026-02-20`
- 对照基准：`../legado/app/src/main/res/menu/main_bnv.xml`、`main_bookshelf.xml`、`main_explore.xml`、`main_rss.xml`、`main_my.xml`

## 1. 差异点清单（实现前 -> 本次收敛）

| 差异ID | legacy 行为 | soupreader 原状态 | 本次处理 | 影响 |
|---|---|---|---|---|
| M-001 | 重选书架 Tab 时可回顶/收缩（`MainActivity` 重选逻辑） | 仅发现页支持重选压缩，书架重选无动作 | 已补齐：新增 `reselectSignal` + 书架滚动回顶 | 主入口交互同义收敛 |
| M-002 | 底栏按 `showDiscovery/showRss/defaultHomePage` 控制可见性与默认页 | 已实现，但缺少文档级逐项对照 | 已补齐本对照清单 | 降低后续迁移遗漏风险 |
| M-003 | 书架/发现/RSS/设置页顶栏菜单有固定入口语义 | soupreader 入口已存在，部分为占位动作 | 保持占位并按 T05 规范标注（扩展冻结） | 不影响核心链路，扩展项继续 `blocked` |

## 2. 逐项检查清单（入口/状态/异常/文案/排版/触发）

### 2.1 底栏（Main）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：书架/发现/RSS/我的 四入口由配置控制可见 | `lib/main.dart:414`, `lib/main.dart:423` |
| 状态 | 已同义：默认页按 `defaultHomePage` 解析 | `lib/main.dart:443` |
| 异常 | 已同义：索引越界直接返回，避免异常跳转 | `lib/main.dart:388` |
| 文案 | 已同义：底栏文案为“书架/发现/RSS/我的” | `lib/main.dart:410`, `lib/main.dart:419`, `lib/main.dart:428`, `lib/main.dart:437` |
| 排版 | 已同义：统一 `CupertinoTabBar`，层级与 legdo 主入口等价 | `lib/main.dart:474` |
| 交互触发 | 已同义：重选发现触发压缩；重选书架触发回顶 | `lib/main.dart:387`, `lib/main.dart:393`, `lib/main.dart:396` |

### 2.2 书架 Tab（Bookshelf）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：顶栏搜索 + 更多菜单入口齐全 | `lib/features/bookshelf/views/bookshelf_view.dart:557`, `lib/features/bookshelf/views/bookshelf_view.dart:570` |
| 状态 | 已同义：图墙/列表两种状态都接入同一滚动控制 | `lib/features/bookshelf/views/bookshelf_view.dart:640`, `lib/features/bookshelf/views/bookshelf_view.dart:774` |
| 异常 | 已同义：无滚动客户端时回顶逻辑安全返回 | `lib/features/bookshelf/views/bookshelf_view.dart:115` |
| 文案 | 已同义：菜单项文案按 legacy 顺序迁移 | `lib/features/bookshelf/views/bookshelf_view.dart:372` |
| 排版 | 已同义：`AppCupertinoPageScaffold` + 右上角双按钮 | `lib/features/bookshelf/views/bookshelf_view.dart:557` |
| 交互触发 | 已同义：外部重选信号触发 `_scrollToTop()` | `lib/features/bookshelf/views/bookshelf_view.dart:25`, `lib/features/bookshelf/views/bookshelf_view.dart:106`, `lib/features/bookshelf/views/bookshelf_view.dart:114` |

### 2.3 发现 Tab（Discovery）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：顶栏分组筛选入口保留 | `lib/features/discovery/views/discovery_view.dart:465` |
| 状态 | 已同义：重选信号驱动收缩/回顶 | `lib/features/discovery/views/discovery_view.dart:27`, `lib/features/discovery/views/discovery_view.dart:182` |
| 异常 | 已同义：分组为空有提示，不进入空筛选状态 | `lib/features/discovery/views/discovery_view.dart:148` |
| 文案 | 已同义：支持 `group:` 搜索语义提示 | `lib/features/discovery/views/discovery_view.dart:476` |
| 排版 | 已同义：顶栏按钮 + 搜索输入组合与 legacy 语义等价 | `lib/features/discovery/views/discovery_view.dart:461` |
| 交互触发 | 已同义：分组 ActionSheet 点击写入 `group:` 查询 | `lib/features/discovery/views/discovery_view.dart:163` |

### 2.4 RSS Tab

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：收藏/分组/设置三入口 | `lib/features/rss/views/rss_subscription_view.dart:56`, `lib/features/rss/views/rss_subscription_view.dart:62` |
| 状态 | 已同义：分组筛选弹层按分组刷新列表 | `lib/features/rss/views/rss_subscription_view.dart:233` |
| 异常 | 已同义：无分组时提示并中止筛选 | `lib/features/rss/views/rss_subscription_view.dart:233` |
| 文案 | 已同义：分组筛选与 legacy `group:` 语义一致 | `lib/features/rss/views/rss_subscription_view.dart:367` |
| 排版 | 已同义：顶部按钮组布局稳定 | `lib/features/rss/views/rss_subscription_view.dart:47` |
| 交互触发 | 已同义：分组按钮触发 `_openGroupFilterSheet` | `lib/features/rss/views/rss_subscription_view.dart:62` |

### 2.5 我的/设置 Tab

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：源管理/主题/阅读/备份等主入口可达 | `lib/features/settings/views/settings_view.dart:145`, `lib/features/settings/views/settings_view.dart:204` |
| 状态 | 已同义：列表分组在加载后可展示汇总状态 | `lib/features/settings/views/settings_view.dart:120` |
| 异常 | 已同义：扩展入口统一走占位提示，不出现“点击无响应” | `lib/features/settings/views/settings_view.dart:185`, `lib/features/settings/views/settings_view.dart:294` |
| 文案 | 近同义：tab 文案为“我的”，页标题为“设置”（语义一致） | `lib/main.dart:437`, `lib/features/settings/views/settings_view.dart:137` |
| 排版 | 已同义：分组列表层级与 legacy 设置主页等价 | `lib/features/settings/views/settings_view.dart:141` |
| 交互触发 | 已同义：所有入口具备 onTap 反馈路径 | `lib/features/settings/views/settings_view.dart:148` |

## 3. 回归路径 M1（主入口）

- 路径：底栏四 Tab -> 各页顶栏按钮 -> 主要二级入口
- 实测结论：
  - 书架重选 Tab 可触发回顶（本次新增）
  - 发现重选 Tab 可触发收缩/回顶（原有）
  - RSS 分组筛选按钮可打开筛选弹层
  - 设置页扩展入口均有统一占位反馈

## 4. 命令验证证据

```bash
flutter test test/bookshelf_view_compile_test.dart
flutter test test/widget_test.dart
```

- 结果：均通过。
- 说明：按仓库规则，本阶段未执行 `flutter analyze`（保留到提交前 T18 一次执行）。

## 5. 保留差异与后续

- 保留差异：设置页部分扩展入口仍为占位（符合“扩展冻结”策略）。
- 回补计划：在需求方明确“开始做扩展功能”后，由 `T15` 解锁执行。
