# 发现链路对照清单（T08 / C2）

- 任务状态：`done`
- 对应计划：`PLANS.md` / `T08`
- 产出日期：`2026-02-21`
- 对照基准：
  - `../legado/app/src/main/res/menu/main_explore.xml`
  - `../legado/app/src/main/res/menu/explore_item.xml`
  - `../legado/app/src/main/java/io/legado/app/data/dao/BookSourceDao.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreAdapter.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/main/MainActivity.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/explore/ExploreShowActivity.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/explore/ExploreShowViewModel.kt`

## 1. 差异点清单（实现前 -> 本次收敛）

| 差异ID | legacy 行为 | soupreader 原状态 | 本次处理 | 影响 |
|---|---|---|---|---|
| E-001 | 发现列表过滤条件为 `enabledExplore=1 && hasExploreUrl=1`，按 `customOrder` 排序 | 额外要求 `enabled=true`、`ruleExplore!=null`，且按 `customOrder+weight+name` 排序 | 改为仅按 `enabledExplore + exploreUrl` 过滤，按 `customOrder` 升序（同序保持原顺序） | 发现入口与 legacy 可见性、排序语义对齐 |
| E-002 | 分组菜单仅展示分组项（`menu_group` 子菜单） | 分组弹层额外提供“清空筛选” | 移除“清空筛选”动作，仅保留分组项 + 取消 | 去除额外扩展入口，回归 legacy 菜单语义 |
| E-003 | 发现长按菜单顺序：编辑/置顶/登录/搜索/刷新/删除 | “搜索”在“登录”前，且文案为“源内搜索” | 调整顺序与文案：编辑/置顶/登录/搜索/刷新发现缓存/删除 | 长按菜单触发顺序与 legacy 同义 |
| E-004 | 发现二级页（ExploreShow）无顶部刷新按钮，依赖下拉到底自动加载与错误重试 | 顶部存在刷新按钮 | 移除顶部刷新按钮，保留滚动加载与失败重试 | 去除非 legacy 扩展动作，保持链路一致 |

## 2. 逐项检查清单（入口/状态/异常/文案/排版/触发）

### 2.1 发现主页（`main_explore`）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：发现页顶部有“分组筛选”入口，点击进入分组列表 | `../legado/app/src/main/res/menu/main_explore.xml:5`, `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt:84`, `lib/features/discovery/views/discovery_view.dart:452`, `lib/features/discovery/views/discovery_view.dart:457` |
| 状态 | 已同义：空态仅在“无结果且查询为空”展示；有查询但无结果不显示空态文案 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt:167`, `lib/features/discovery/services/discovery_filter_helper.dart:43`, `lib/features/discovery/views/discovery_view.dart:447` |
| 异常 | 已同义：发现入口解析失败后显示 `ERROR` 可点击项，并弹窗展示错误摘要 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreAdapter.kt:93`, `lib/features/discovery/views/discovery_view.dart:223`, `lib/features/discovery/views/discovery_view.dart:241` |
| 文案 | 已同义：页面主语义文案保持“发现/按分组筛选/分组筛选” | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt:97`, `lib/features/discovery/views/discovery_view.dart:453`, `lib/features/discovery/views/discovery_view.dart:155`, `lib/features/discovery/views/discovery_view.dart:486` |
| 排版 | 已同义：顶部筛选区 + 列表区 + 空态区的主层级结构一致 | `../legado/app/src/main/res/layout/fragment_explore.xml:8`, `../legado/app/src/main/res/layout/fragment_explore.xml:18`, `../legado/app/src/main/res/layout/fragment_explore.xml:27`, `lib/features/discovery/views/discovery_view.dart:462`, `lib/features/discovery/views/discovery_view.dart:497` |
| 交互触发 | 已同义：点分组后写入 `group:<组名>` 并立即按分组筛选 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt:187`, `lib/features/discovery/views/discovery_view.dart:162`, `lib/features/discovery/services/discovery_filter_helper.dart:15` |
| 输入 | 已同义：普通关键词匹配书源名/分组；`group:` 走分组精确项匹配 | `../legado/app/src/main/java/io/legado/app/data/dao/BookSourceDao.kt:111`, `../legado/app/src/main/java/io/legado/app/data/dao/BookSourceDao.kt:121`, `lib/features/discovery/services/discovery_filter_helper.dart:24`, `lib/features/discovery/services/discovery_filter_helper.dart:19` |
| 交互逻辑 | 已同义：底栏重选发现时优先折叠展开项，否则回到顶部 | `../legado/app/src/main/java/io/legado/app/ui/main/MainActivity.kt:168`, `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt:230`, `lib/main.dart:395`, `lib/features/discovery/views/discovery_view.dart:174` |

### 2.2 书源长按菜单（`explore_item`）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：长按书源标题区域弹出操作菜单 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreAdapter.kt:138`, `lib/features/discovery/views/discovery_view.dart:585`, `lib/features/discovery/views/discovery_view.dart:257` |
| 状态 | 已同义：登录项按 `loginUrl` 是否存在动态显示 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreAdapter.kt:159`, `lib/features/discovery/views/discovery_view.dart:278` |
| 异常 | 已同义：删除操作需二次确认；登录地址非法给出可观测提示 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt:214`, `lib/features/discovery/views/discovery_view.dart:394`, `lib/features/discovery/views/discovery_view.dart:353`, `lib/features/discovery/views/discovery_view.dart:359` |
| 文案 | 已同义：菜单主文案与 legacy 语义一致（编辑/置顶/登录/搜索/刷新/删除） | `../legado/app/src/main/res/menu/explore_item.xml:4`, `lib/features/discovery/views/discovery_view.dart:265`, `lib/features/discovery/views/discovery_view.dart:272`, `lib/features/discovery/views/discovery_view.dart:280`, `lib/features/discovery/views/discovery_view.dart:287`, `lib/features/discovery/views/discovery_view.dart:294`, `lib/features/discovery/views/discovery_view.dart:302` |
| 排版 | 已同义：菜单为分组动作列表 + 取消按钮 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreAdapter.kt:157`, `lib/features/discovery/views/discovery_view.dart:260`, `lib/features/discovery/views/discovery_view.dart:309` |
| 交互触发 | 已同义：编辑/置顶/登录/搜索/刷新缓存/删除均绑定明确动作 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreAdapter.kt:162`, `lib/features/discovery/views/discovery_view.dart:268`, `lib/features/discovery/views/discovery_view.dart:275`, `lib/features/discovery/views/discovery_view.dart:283`, `lib/features/discovery/views/discovery_view.dart:290`, `lib/features/discovery/views/discovery_view.dart:297`, `lib/features/discovery/views/discovery_view.dart:305` |
| 输入 | 已同义：搜索动作将当前书源作为 scope 注入搜索页 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt:225`, `lib/features/discovery/views/discovery_view.dart:374` |
| 交互逻辑 | 已同义：刷新只清缓存并在当前展开项即时重载，不污染其它项状态 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreAdapter.kt:170`, `lib/features/discovery/views/discovery_view.dart:382`, `lib/features/discovery/views/discovery_view.dart:389` |

### 2.3 发现二级结果页（ExploreShow）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：点击发现分类进入“单书源+单分类”结果页 | `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt:195`, `lib/features/discovery/views/discovery_view.dart:246`, `lib/features/discovery/views/discovery_explore_results_view.dart:149` |
| 状态 | 已同义：初次进入自动加载，滚动到底继续分页；无增量时停止加载 | `../legado/app/src/main/java/io/legado/app/ui/book/explore/ExploreShowActivity.kt:56`, `../legado/app/src/main/java/io/legado/app/ui/book/explore/ExploreShowActivity.kt:77`, `lib/features/discovery/views/discovery_explore_results_view.dart:51`, `lib/features/discovery/views/discovery_explore_results_view.dart:66`, `lib/features/discovery/views/discovery_explore_results_view.dart:112` |
| 异常 | 已同义：请求失败可观测（错误文本）并支持重试 | `../legado/app/src/main/java/io/legado/app/ui/book/explore/ExploreShowViewModel.kt:80`, `../legado/app/src/main/java/io/legado/app/ui/book/explore/ExploreShowActivity.kt:35`, `lib/features/discovery/views/discovery_explore_results_view.dart:122`, `lib/features/discovery/views/discovery_explore_results_view.dart:191`, `lib/features/discovery/views/discovery_explore_results_view.dart:213` |
| 文案 | 已同义：标题来自发现项名称，空态/重试文案可理解且业务语义一致 | `../legado/app/src/main/java/io/legado/app/ui/book/explore/ExploreShowActivity.kt:31`, `lib/features/discovery/views/discovery_explore_results_view.dart:149`, `lib/features/discovery/views/discovery_explore_results_view.dart:223`, `lib/features/discovery/views/discovery_explore_results_view.dart:214` |
| 排版 | 已同义：顶部标题 + 列表 + 底部加载状态结构一致 | `../legado/app/src/main/res/layout/activity_explore_show.xml:8`, `../legado/app/src/main/res/layout/view_load_more.xml:8`, `lib/features/discovery/views/discovery_explore_results_view.dart:150`, `lib/features/discovery/views/discovery_explore_results_view.dart:231`, `lib/features/discovery/views/discovery_explore_results_view.dart:332` |
| 交互触发 | 已同义：点击结果项进入书籍详情 | `../legado/app/src/main/java/io/legado/app/ui/book/explore/ExploreShowAdapter.kt:75`, `lib/features/discovery/views/discovery_explore_results_view.dart:252`, `lib/features/discovery/views/discovery_explore_results_view.dart:133` |
| 输入 | 已同义：加载请求始终携带 `source + exploreUrl + page` | `../legado/app/src/main/java/io/legado/app/ui/book/explore/ExploreShowViewModel.kt:73`, `lib/features/discovery/views/discovery_explore_results_view.dart:92`, `lib/features/discovery/views/discovery_explore_results_view.dart:95` |
| 交互逻辑 | 已同义：本轮移除额外顶部刷新入口，避免非 legacy 扩展动作 | `../legado/app/src/main/java/io/legado/app/ui/book/explore/ExploreShowActivity.kt:30`, `lib/features/discovery/views/discovery_explore_results_view.dart:148` |

## 3. 回归路径 C2（发现）

- 路径：发现 Tab -> 分组筛选 -> 展开书源 -> 长按菜单动作 -> 进入发现二级页 -> 点书进入详情。
- 手工核验点：
  - 分组筛选仅包含分组项，不出现额外扩展入口。
  - 列表可见源与排序符合 `enabledExplore + exploreUrl + customOrder`。
  - 长按菜单顺序与 legacy `explore_item` 一致。
  - 二级页支持滚动分页与错误重试，无额外刷新入口。

## 4. 命令验证证据

```bash
flutter test test/discovery_filter_helper_test.dart
flutter test test/discovery_view_compile_test.dart
```

- 结果：通过。
- 说明：按仓库规则，本阶段未执行 `flutter analyze`（保留到 T18 提交前一次执行）。

## 5. 保留差异与后续

- 保留差异：发现主列表卡片中额外展示了书源 URL 与分组文本；legacy 列表仅展示书源名。
- 差异性质：信息增强，不改变入口层级、触发顺序与状态流。
- 回补计划：在 T16（全局排版一致性复核）阶段结合截图矩阵评估是否收敛为 legacy 更简版布局。
