# SoupReader ExecPlans（重建版）

## 当前主计划

- 计划名称：`legado 全功能逐项迁移（One-by-One）`
- 状态：`active`
- 主执行文档：`docs/plans/2026-02-21-legado-all-features-one-by-one-execplan.md`
- 逐项跟踪台账：`docs/plans/2026-02-21-legado-feature-item-tracker.csv`
- 功能项优先级队列：`docs/plans/2026-02-21-legado-feature-priority-queue.csv`
- 执行口径：以 `seq=1..410` 为最小执行单元，一项一处理、一项一验收、一项一回填。

## 执行原则

- 严格以 `../legado` 行为语义为第一标准。
- 逐项串行推进，不并发处理同一功能链路。
- 全量优先级执行顺序：`P1 -> P2 -> P3 -> P4 -> P5 -> P6 -> P8 -> P7 -> P10 -> P9`。
- 具体功能项执行顺序以 `priority_order` 为准（见 `docs/plans/2026-02-21-legado-feature-priority-queue.csv`）。
- 用户约束（2026-02-21）：`book_manga.xml` 全部功能先不做，统一标记 `blocked`，优先推进文字阅读链路（`book_read*.xml`、`book_toc.xml`、`book_info*.xml`）。
- 细节项后置（2026-02-21）：排序/文案/拷贝/日志/帮助/主题类差异默认放到主功能完成后处理。
- 细节项执行闸门（2026-02-21）：`current_status=pending` 且 `priority_reason` 含 `detail_later` 的项，统一排在所有非 `detail_later` 的 `pending` 项之后；主功能未清零前不得执行细节项。
- 每个功能项完成后，必须同步更新：
  - `docs/plans/2026-02-21-legado-feature-item-tracker.csv`（`status/owner/verify/notes`）
  - `docs/plans/2026-02-21-legado-all-features-one-by-one-execplan.md`（`Progress/Decision Log`）
- 未到“提交推送”阶段，不执行 `flutter analyze`。

## 全量优先级（覆盖 410 项）

| 优先级层 | Phase | 项数 | 排序依据 | 说明 |
|---|---|---:|---|---|
| S0 | P2 + P3 | 127 | 核心五段链路直接相关 | 优先完成搜索/详情/目录与阅读正文全链路 |
| S1 | P4 + P5 | 131 | 核心链路关键依赖 | 书源管理与规则能力影响主链路可用性 |
| S2 | P6 + P8 | 58 | 核心链路支撑能力 | 书架缓存分组、导入导出与备份能力 |
| S3 | P7 | 47 | 独立业务域 | RSS 不阻塞主阅读链路 |
| S4 | P10 + P9 | 26 | 收口域 | 系统工具与主题外观放在最后收口 |
| HOLD | P3(book_manga) | 18 | 用户冻结 | 漫画功能暂缓，待解锁后恢复执行 |

优先级落地规则：
- `P1`（21 项）已完成，保持 `done`。
- 所有未完成项按“优先级层 -> Phase -> seq 升序”执行。
- 同一优先级层内不并行推进多个 Phase，避免跨域回归干扰。
- 在同一优先级层内，进一步按 `docs/plans/2026-02-21-legado-feature-priority-queue.csv` 的 `priority_order` 执行到功能项（seq）级别。
- `HOLD` 层不执行，直到收到“开始做漫画功能”的明确指令。
- 标记为 `detail_later` 的项统一后置到主功能序列之后执行（不是“模块内穿插后置”，而是“全局队列后置”）。

## Todo（依赖与串并行）

| ID | 优先级 | 状态 | 并行性 | 依赖 | 任务 | 交付物 | 验证 |
|---|---|---|---|---|---|---|---|
| T00 | - | done | 串行 | 无 | 清理历史计划/进度文件并重建计划基线 | 新 `PLANS.md` + 新 ExecPlan + 新 410 项跟踪台账 | 文件存在且计数正确 |
| T01 | - | done | 串行 | T00 | Phase P1：主入口与导航（21项）逐项迁移与验收 | 跟踪台账 P1 全部 `done` | 定向测试 + 手工路径 |
| T02 | S0 | active | 串行 | T01 | Phase P2：搜索/详情/目录（38项）逐项迁移与验收 | 跟踪台账 P2 全部 `done` | 定向测试 + 手工路径 |
| T03 | S0 | pending | 串行 | T02 | Phase P3：阅读与朗读（文字链路）逐项迁移与验收 | 跟踪台账 P3（非漫画项）全部 `done` | 定向测试 + 手工路径 |
| T03A | HOLD | blocked | 串行 | T11 | Phase P3：漫画链路（`book_manga.xml`，18项）冻结 | 跟踪台账漫画项保持 `blocked` | 待需求解锁 |
| T04 | S1 | pending | 串行 | T03 | Phase P4：书源管理与换源（85项）逐项迁移与验收 | 跟踪台账 P4 全部 `done` | 定向测试 + 手工路径 |
| T05 | S1 | pending | 串行 | T04 | Phase P5：规则与净化（46项）逐项迁移与验收 | 跟踪台账 P5 全部 `done` | 定向测试 + 手工路径 |
| T06 | S2 | pending | 串行 | T05 | Phase P6：书架/缓存/分组（31项）逐项迁移与验收 | 跟踪台账 P6 全部 `done` | 定向测试 + 手工路径 |
| T07 | S2 | pending | 串行 | T06 | Phase P8：导入导出与备份（27项）逐项迁移与验收 | 跟踪台账 P8 全部 `done` | 定向测试 + 手工路径 |
| T08 | S3 | pending | 串行 | T07 | Phase P7：RSS（47项）逐项迁移与验收 | 跟踪台账 P7 全部 `done` | 定向测试 + 手工路径 |
| T09 | S4 | pending | 串行 | T08 | Phase P10：系统与工具（24项）逐项迁移与验收 | 跟踪台账 P10 全部 `done` | 定向测试 + 手工路径 |
| T10 | S4 | pending | 串行 | T09 | Phase P9：主题与外观（2项）逐项迁移与验收 | 跟踪台账 P9 全部 `done` | 定向测试 + 手工路径 |
| T11 | 收口 | pending | 串行 | T10 | 全量复核与最终收口（410项） | 最终对照清单与收尾结论 | 仅提交前一次 `flutter analyze` |

## Progress（动态）

- `2026-02-22`
  - 完成规范调整：按需求“开发完成不要编写 test”更新 `AGENTS.md`，在第 3 章新增强制条款“开发完成后禁止新增、编写或改造测试用例（除非需求方明确要求）”。
  - 同步收敛验收口径：`2.3` 命令验证示例改为仅 `flutter analyze`；第 3 章中途校验改为“仅手工回归路径”；迁移级别任务的回归验证改为“手工回归验证”；第 4 章“如何验证”改为“`flutter analyze` 或手工路径”。
  - 变更原因：需求方明确要求“开发完成不要编写 test”，需将仓库协作规范改为禁止新增测试代码。
  - 如何验证：`rg -n '禁止新增、编写或改造测试用例|仅使用与改动相关的手工回归路径|手工回归验证' AGENTS.md`；`rg -n "命令验证（如 .*flutter analyze.*）|如何验证（.*flutter analyze.*）" AGENTS.md`；`sed -n '90,132p' AGENTS.md`。
  - 兼容影响：仅文档流程约束变更，不影响既有书源运行时兼容性。

- `2026-02-21`
  - 队列再收紧：将全部 `pending + detail_later` 功能项统一下沉到主功能项之后，当前 `pending` 列表中首个细节项位置为第 `297` 位（此前为第 `52` 位），确保“主功能绝对优先”。
  - 新增执行约束：排序/文案/拷贝/日志/帮助/主题类差异归为 `detail_later`，默认后置到主功能完成后处理。
  - 新增用户约束：漫画功能先不做，`book_manga.xml`（`seq46~63`）统一冻结为 `blocked`，优先推进文字阅读链路。
  - 优先级队列重排：功能项级队列新增 `HOLD` 层，漫画项降级到末尾冻结区。
  - 新增功能项级优先级输出：生成 `docs/plans/2026-02-21-legado-feature-priority-queue.csv`（`411` 行，含表头；覆盖全部 `410` 功能项），字段含 `priority_order/priority_tier/priority_score/priority_reason`，用于替代“仅模块级”排序。
  - 计划重排：按“覆盖全部 410 项”的优先级模型重排执行顺序，调整为 `P2 -> P3 -> P4 -> P5 -> P6 -> P8 -> P7 -> P10 -> P9`，并在 Todo 中补充优先级层 `S0~S4`。
  - 完成 T00：已清空历史计划/进度文档，并重建新的单一主计划与 410 项跟踪台账。
  - 当前进入 T01：从 `P1 主入口与导航` 开始逐项推进。
  - 完成 `T01-seq257`（`main_bnv.xml / menu_bookshelf / 书架`）：修正重选触发为 legado 同义的 `300ms` 双击回顶语义；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq258`（`main_bnv.xml / menu_discovery / 发现`）：修正重选触发为 legado 同义的 `300ms` 双击压缩/回顶语义；验证 `flutter test test/discovery_view_compile_test.dart test/widget_test.dart` 通过。
  - 完成 `T01-seq259`（`main_bnv.xml / menu_rss / 订阅`）：回补底栏文案为“订阅”并保持导航行为同义；验证 `flutter test test/widget_test.dart test/discovery_view_compile_test.dart test/rss_subscription_view_compile_test.dart` 通过。
  - 完成 `T01-seq260`（`main_bnv.xml / menu_my_config / 我的`）：确认入口文案与导航行为同义；验证 `flutter test test/widget_test.dart test/discovery_view_compile_test.dart test/rss_subscription_view_compile_test.dart` 通过。
  - 完成 `T01-seq261`（`main_bookshelf.xml / menu_search / 搜索`）：确认书架顶栏常驻搜索入口点击后打开搜索页，保持 legado `SearchActivity` 触发语义同义；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq262`（`main_bookshelf.xml / menu_update_toc / 更新目录`）：确认“更多菜单 -> 更新目录”触发更新链路，并在空书架场景给出同义失败反馈；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq263`（`main_bookshelf.xml / menu_add_local / 添加本地`）：将书架更多菜单文案由“本机导入”收敛为 legado 同义“添加本地”，保持触发本地导入链路不变；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq264`（`main_bookshelf.xml / menu_remote / 远程书籍`）：将书架更多菜单文案由“远程导入”收敛为 legado 同义“远程书籍”，并由占位提示改为进入远程书籍承载页；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq265`（`main_bookshelf.xml / menu_add_url / 添加网址`）：将书架更多菜单文案由“URL 导入”收敛为 legado 同义“添加网址”，并接入“添加书籍网址”输入弹窗、可取消的“添加中”状态与网址加书链路；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq266`（`main_bookshelf.xml / menu_bookshelf_manage / 书架管理`）：将书架更多菜单“书架管理”由占位提示收敛为页面导航入口，保持 legado 同层级入口语义；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq267`（`main_bookshelf.xml / menu_download / 缓存/导出`）：将书架更多菜单文案由“缓存导出”收敛为 legado 同义“缓存/导出”，并由占位提示改为进入缓存/导出承载页；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq268`（`main_bookshelf.xml / menu_group_manage / 分组管理`）：将书架更多菜单“分组管理”由占位提示收敛为弹窗承载入口，保持 legado `GroupManageDialog` 同层级触发语义；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq269`（`main_bookshelf.xml / menu_bookshelf_layout / 书架布局`）：将入口改为 legado 同义的确认式配置弹窗，补齐布局/排序索引与未读/更新时间/待更新计数/快速滚动条等配置落盘并接入书架展示行为；验证 `flutter test test/widget_test.dart test/app_settings_test.dart` 通过。
  - 完成 `T01-seq270`（`main_bookshelf.xml / menu_export_bookshelf / 导出书单`）：将书架更多菜单文案由“导出书架”收敛为 legado 同义“导出书单”，并补齐导出成功弹窗中的路径展示与复制动作，导出异常口径统一为“导出书籍出错”；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq271`（`main_bookshelf.xml / menu_import_bookshelf / 导入书单`）：将书架更多菜单文案由“导入书架”收敛为 legado 同义“导入书单”，补齐 legado 同义的 `url/json` 输入弹窗与“选择文件（txt/json）”双入口，并将导入解析口径收敛为 `http/https 或 JSON 数组`；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq272`（`main_bookshelf.xml / menu_log / 日志`）：将书架“日志”入口由“异常日志页面跳转”收敛为 legado 同义“日志弹层”语义，保留清空动作与空态可见反馈；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq273`（`main_explore.xml / menu_group / 分组`）：将发现页分组入口收敛为 legado 同义的“动态分组菜单 -> 选择后写入 `group:<分组>` 即时筛选”语义，并将分组排序/筛选规则对齐 legado；验证 `flutter test test/discovery_view_compile_test.dart test/widget_test.dart` 通过。
  - 完成 `T01-seq274`（`main_my.xml / menu_help / 帮助`）：补齐“我的”页右上角帮助入口，接入 legado 同源 `appHelp.md` 文档资产并以弹层展示，保持 `showHelp("appHelp")` 同义触发语义；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq275`（`main_rss.xml / menu_rss_star / 收藏`）：确认订阅页顶栏星标保持 legado `menu_rss_star -> RssFavoritesActivity` 的一级入口语义，并补齐“点击收藏进入收藏页”定向回归用例；验证 `flutter test test/widget_test.dart` 通过。
  - 完成 `T01-seq276`（`main_rss.xml / menu_group / 分组`）：将订阅页分组入口由含“全部”扩展项的选项面板收敛为 legado 同义“动态分组菜单”，选择分组后写入 `group:<分组>` 并即时筛选；验证 `flutter test test/rss_subscription_view_group_menu_test.dart test/widget_test.dart` 通过。
  - 完成 `T01-seq277`（`main_rss.xml / menu_rss_config / 设置`）：确认订阅页顶栏“设置”保持 legado `menu_rss_config -> RssSourceActivity` 的一级入口语义，并补齐“点击设置进入订阅源管理页”定向回归用例；验证 `flutter test test/widget_test.dart --plain-name "RSS settings action opens source manage page"`、`flutter test test/rss_subscription_view_group_menu_test.dart` 通过。
  - 阶段收口：`P1` 共 `21/21` 项已完成，`blocked=0`。
  - 当前进入 `T02`：从 `P2 搜索/详情/目录` 开始逐项推进。
  - 完成 `T02-seq30`（`book_info.xml / menu_edit / 编辑`）：确认详情页“编辑”入口仅在书架内书籍显示，点击后进入“编辑书籍信息”页并保持保存回写语义同义；验证 `flutter test test/search_book_info_edit_helper_test.dart test/search_book_info_menu_helper_test.dart test/search_book_info_view_edit_action_test.dart` 通过。
  - 完成 `T02-seq31`（`book_info.xml / menu_share_it / 分享`）：将详情页分享行为收敛为 legado 同义 `bookUrl#bookJson + shareWithQr` 语义，点击顶栏分享后直接调用系统分享二维码图片，并补齐“文字太多，生成二维码失败”失败提示；验证 `flutter test test/search_book_info_edit_helper_test.dart test/search_book_info_menu_helper_test.dart test/search_book_info_share_helper_test.dart test/search_book_info_view_compile_test.dart test/search_book_info_view_edit_action_test.dart` 通过。
  - 完成 `T02-seq32`（`book_info.xml / menu_upload / 上传 WebDav`）：将详情页更多菜单文案由“上传到远程”收敛为 legado 同义“上传 WebDav”，并对齐 `sure_upload` 的提醒弹窗语义与“上传中.....”等待态；验证 `flutter test test/search_book_info_view_upload_action_test.dart test/search_book_info_view_edit_action_test.dart test/search_book_info_menu_helper_test.dart test/search_book_info_share_helper_test.dart test/search_book_info_view_compile_test.dart` 通过。
  - 完成 `T02-seq33`（`book_info.xml / menu_refresh / 刷新`）：将详情页刷新行为收敛为 legado `refreshBook` 同义链路，书架内本地书籍触发 TXT/EPUB 重解析并回写章节与书籍元数据，书架内网络书籍继续刷新详情+目录，非书架场景保持详情重载；验证 `flutter test test/search_book_info_refresh_helper_test.dart test/search_book_info_view_upload_action_test.dart test/search_book_info_view_edit_action_test.dart test/search_book_info_menu_helper_test.dart test/search_book_info_share_helper_test.dart test/search_book_info_view_compile_test.dart` 通过。
  - 完成 `T02-seq34`（`book_info.xml / menu_login / 登录`）：确认详情页“登录”入口仅在 `bookSource.loginUrl` 非空时显示，点击后按 legado 同义优先级走 `loginUi` 表单登录或网页登录流程；验证 `flutter test test/search_book_info_menu_helper_test.dart test/search_book_info_view_login_action_test.dart` 通过。
  - 完成 `T02-seq35`（`book_info.xml / menu_top / 置顶`）：将详情页置顶动作收敛为 legado 同义“点击即写库”语义，移除前置拦截提示并补齐置顶写库 helper 与页面级回归用例；验证 `flutter test test/search_book_info_top_helper_test.dart test/search_book_info_view_top_action_test.dart test/search_book_info_menu_helper_test.dart test/search_book_info_view_login_action_test.dart` 通过。
  - 完成 `T02-seq36`（`book_info.xml / menu_set_source_variable / 设置源变量`）：将源变量存储边界收敛为 legado 同义（空串保留，仅 `null` 删除），详情页保存后不再追加“源变量已保存”扩展提示，并将缺失书源提示收敛为“书源不存在”；验证 `flutter test test/source_variable_store_test.dart test/search_book_info_view_source_variable_action_test.dart` 通过。
  - 完成 `T02-seq37`（`book_info.xml / menu_set_book_variable / 设置书籍变量`）：将书籍变量存储边界收敛为 legado 同义（空串保留，仅 `null` 删除），详情页保存后不再追加“书籍变量已保存”扩展提示，并将缺失书源提示收敛为“书源不存在”；验证 `flutter test test/book_variable_store_test.dart test/search_book_info_view_book_variable_action_test.dart` 通过。
  - 完成 `T02-seq38`（`book_info.xml / menu_copy_book_url / 拷贝书籍 URL`）：将详情页菜单文案由“复制书籍链接”收敛为 legado 同义“拷贝书籍 URL”，并对齐 `sendToClip` 语义为“写入剪贴板 + 复制完成提示（空字符串也复制）”；验证 `flutter test test/search_book_info_view_copy_book_url_action_test.dart test/search_book_info_view_compile_test.dart` 通过。
  - 完成 `T02-seq39`（`book_info.xml / menu_copy_toc_url / 拷贝目录 URL`）：将详情页菜单文案由“复制目录链接”收敛为 legado 同义“拷贝目录 URL”，并对齐 `sendToClip` 语义为“写入剪贴板 + 复制完成提示（空字符串也复制）”；验证 `flutter test test/search_book_info_view_copy_toc_url_action_test.dart test/search_book_info_view_copy_book_url_action_test.dart` 通过。
  - 完成 `T02-seq40`（`book_info.xml / menu_can_update / 允许更新`）：将详情页“允许更新”收敛为 legado 同义 `checkable` 语义（标题固定“允许更新”，通过勾选态表达开关），移除切换后的“已开启/已关闭”扩展提示，并保持“仅书架内持久化”边界行为；验证 `flutter test test/search_book_info_view_allow_update_action_test.dart test/search_book_info_view_compile_test.dart` 通过。
  - 完成 `T02-seq41`（`book_info.xml / menu_split_long_chapter / 拆分超长章节`）：将“分割长章节”从“仅保存状态”收敛为 legado 同义“保存后立即生效”语义，详情页切换后强制触发本地 TXT 重解析并回写章节缓存；同时为 `TxtParser.reparseFromFile` 增加 `splitLongChapter` 参数并贯穿详情/阅读两侧调用，确保同一 `bookId` 开关行为一致；验证 `flutter test test/txt_parser_charset_override_test.dart test/search_book_info_refresh_helper_test.dart test/search_book_info_view_compile_test.dart test/simple_reader_view_compile_test.dart` 通过。
  - 完成 `T02-seq42`（`book_info.xml / menu_delete_alert / 删除提醒`）：将详情页“删除提醒”收敛为 legado 同义 `checkable` 语义（标题固定“删除提醒”，通过勾选态表达开关），移除切换后的“已开启/已关闭删除提醒”扩展提示，并保持全局持久化设置边界；验证 `flutter test test/search_book_info_view_delete_alert_action_test.dart test/search_book_info_view_allow_update_action_test.dart` 通过。
  - 完成 `T02-seq43`（`book_info.xml / menu_clear_cache / 清理缓存`）：将详情页清理缓存动作收敛为 legado 同义“点击即清理 + 统一成功提示“成功清理缓存””语义，移除“当前书籍不在书架，无法清理缓存 / 暂无可清理的章节缓存 / 已清理缓存：x 章”扩展分支；并补齐非书架 `ephemeral` 书籍清理回归，同时修复 `Chapter.copyWith` 无法显式置空 `content` 导致清理后内存缓存残留的问题；验证 `flutter test test/search_book_info_view_clear_cache_action_test.dart test/search_book_info_view_compile_test.dart` 通过。
  - 完成 `T02-seq44`（`book_info.xml / menu_log / 日志`）：将详情页“日志”入口由“异常日志页面跳转”收敛为 legado 同义 `menu_log -> AppLogDialog` 弹层语义，保留“清空/暂无日志”可见反馈并移除“异常日志”页面级文案偏差；验证 `flutter test test/search_book_info_view_log_action_test.dart test/search_book_info_view_compile_test.dart` 通过。
  - 完成 `T02-seq45`（`book_info_edit.xml / menu_save / 保存`）：将编辑页保存动作收敛为 legado 同义 `menu_save` 语义，字段按输入值直接落库（作者空白不回退旧值），保存后仅返回详情页且不追加“书籍信息已保存”扩展提示，并补齐保存失败可观测提示；验证 `flutter test test/search_book_info_edit_helper_test.dart test/search_book_info_view_edit_action_test.dart test/search_book_info_view_compile_test.dart` 通过。
  - 完成 `T02-seq101`（`book_remote.xml / menu_refresh / 刷新`）：将远程书籍页 `menu_refresh` 收敛为 legado 同义“重载当前目录”语义，刷新时清空当前目录列表后重新发起 WebDav `PROPFIND` 拉取，并保持路径栏与“返回上级”联动；失败分支统一可观测输出“获取webDav书籍出错\n<原因>”；验证 `flutter test test/remote_books_service_test.dart test/remote_books_placeholder_view_test.dart test/widget_test.dart` 通过。
  - 完成 `T02-seq102`（`book_remote.xml / menu_sort / 排序`）：在远程书籍页顶栏补齐 legado 同义“排序”入口并接入子菜单弹层，菜单项收敛为“名称排序/更新时间排序”，具体排序行为按后续 `seq103/seq104` 逐项收敛；验证 `flutter test test/remote_books_placeholder_view_test.dart test/remote_books_service_test.dart test/widget_test.dart` 通过。
  - 完成 `T02-seq103`（`book_remote.xml / menu_sort_name / 名称排序`）：将远程书籍页“名称排序”收敛为 legado 同义 `sortCheck(RemoteBookSort.Name)` 语义，首次点击切换名称升序、再次点击同项切换升降序，并保持每次切换后重载当前目录；同时补齐 legado `AlphanumComparator` 的 Dart 等价比较，确保 `b2/b10` 等自然排序结果一致；验证 `flutter test test/remote_books_placeholder_view_test.dart test/remote_books_service_test.dart test/widget_test.dart` 通过。
  - 完成 `T02-seq104`（`book_remote.xml / menu_sort_time / 更新时间排序`）：将远程书籍页“更新时间排序”收敛为 legado 同义 `sortCheck(RemoteBookSort.Default)` 语义，从名称排序切回时先进入时间升序，再次点击同项切换降序，并保持每次切换后重载当前目录；验证 `flutter test test/remote_books_placeholder_view_test.dart test/remote_books_service_test.dart test/widget_test.dart` 通过。
  - 完成 `T02-seq105`（`book_remote.xml / menu_server_config / 服务器配置`）：在远程书籍页顶栏补齐“更多 -> 服务器配置”入口，新增服务器配置承载页（WebDav 地址/账号/密码/目录与测试连接），并在配置页关闭后触发当前目录重载，对齐 legado `onDialogDismiss -> upPath` 语义；验证 `flutter test test/remote_books_placeholder_view_test.dart`、`flutter test test/widget_test.dart --plain-name "Bookshelf remote action opens remote books page"` 通过。
  - 完成 `T02-seq106`（`book_remote.xml / menu_help / 帮助`）：在远程书籍页“更多”菜单补齐“帮助”入口，接入 legado 同源 `webDavBookHelp.md` 文档资产并复用帮助弹层展示链路，保持文档加载失败可观测提示；验证 `flutter test test/remote_books_placeholder_view_test.dart` 通过。
  - 完成 `T02-seq107`（`book_remote.xml / menu_log / 日志`）：在远程书籍页“更多”菜单补齐“日志”入口并接入 legado 同义 `menu_log -> AppLogDialog` 弹层链路，保持“清空/暂无日志”可见反馈并不引入“异常日志”扩展文案；验证 `flutter test test/remote_books_placeholder_view_test.dart` 通过。
  - 完成 `T02-seq108`（`book_search.xml / menu_precision_search / 精准搜索`）：将搜索设置里的“精准搜索”从“开/关文本”收敛为 legado 同义 `checkable` 勾选态，并将切换后的行为统一为 `setQuery(..., true)` 同义重提交流程；验证 `flutter test test/search_view_precision_search_action_test.dart test/search_view_compile_test.dart` 通过。
  - 完成 `T02-seq109`（`book_search.xml / menu_source_manage / 书源管理`）：将搜索设置中的“书源管理”入口收敛为 legado 同义 `menu_source_manage -> BookSourceActivity` 页面跳转语义，并修复 Linux/测试环境进入书源管理页时 QuickJS 动态库缺失导致的崩溃（改为惰性初始化 + 缺失时降级）；验证 `flutter test test/search_view_source_manage_action_test.dart test/search_view_compile_test.dart` 通过。
  - 完成 `T02-seq110`（`book_search.xml / menu_search_scope / 多分组/书源`）：将搜索设置入口文案由“搜索范围”收敛为 legado 同义“多分组/书源”，并改为点击后直接进入搜索范围页（移除扩展 quick sheet 与“无书源即阻断”分支）；验证 `flutter test test/search_view_precision_search_action_test.dart test/search_view_source_manage_action_test.dart test/search_view_search_scope_action_test.dart test/search_scope_picker_view_compile_test.dart` 通过。
  - 完成 `T02-seq111`（`book_search.xml / menu_log / 日志`）：将搜索设置“日志”入口由 `ExceptionLogsView` 页面跳转收敛为 legado 同义 `menu_log -> AppLogDialog` 弹层语义，保持“清空/暂无日志”可见反馈并移除“异常日志”页面级文案偏差；验证 `flutter test test/search_view_log_action_test.dart test/search_view_precision_search_action_test.dart test/search_view_source_manage_action_test.dart test/search_view_search_scope_action_test.dart test/search_view_compile_test.dart` 通过。
  - 完成 `T02-seq112`（`book_search_scope.xml / menu_screen / 筛选`）：将搜索范围页的筛选入口收敛为 legado 同义“仅书源模式展示顶栏筛选 actionView”语义，筛选框迁移到导航栏 trailing 并在分组模式隐藏，保持书源名/分组/URL/备注四字段筛选与模式切换后筛选词持续生效；验证 `flutter test test/search_scope_picker_view_menu_screen_test.dart test/search_scope_picker_helper_test.dart test/search_scope_picker_view_compile_test.dart test/search_view_search_scope_action_test.dart` 通过。
  - 完成 `T02-seq113`（`book_source.xml / action_sort / 排序`）：将书源管理排序弹层父级标题由“排序选项”收敛为 legado 同义“排序”，并补齐“顶栏排序入口打开排序菜单”定向回归用例；验证 `flutter test test/source_list_view_sort_action_test.dart` 通过。
  - 完成 `T02-seq114`（`book_source.xml / menu_sort_desc / 反序`）：将书源管理排序菜单中的动态切换文案（“切换为降序/升序”）收敛为 legado 同义固定“反序” checkable 语义，点击后仅切换排序方向与勾选态；验证 `flutter test test/source_list_view_sort_action_test.dart` 通过。
  - 完成 `T02-seq115`（`book_source.xml / menu_sort_manual / 手动排序`）：补齐 legado 同义“手动排序单选勾选项”迁移证据，新增“先切到其它排序再切回手动”定向回归并确认仅“手动排序”保留勾选态；验证 `flutter test test/source_list_view_sort_action_test.dart` 通过。
  - 完成 `T02-seq116`（`book_source.xml / menu_sort_auto / 智能排序`）：将书源管理排序菜单该子项文案由“权重”收敛为 legado 同义“智能排序”，并补齐“点击后单选勾选态保持”的页面级回归用例；验证 `flutter test test/source_list_view_sort_action_test.dart` 通过。
  - 完成 `T02-seq117`（`book_source.xml / menu_sort_name / 名称排序`）：将书源管理排序菜单该子项文案由“名称”收敛为 legado 同义“名称排序”，并补齐“点击后单选勾选态保持”的页面级回归用例；验证 `flutter test test/source_list_view_sort_action_test.dart` 通过。
  - 完成 `T02-seq118`（`book_source.xml / menu_sort_url / 地址排序`）：将书源管理排序菜单该子项文案由“地址”收敛为 legado 同义“地址排序”，并补齐“点击后单选勾选态保持”的页面级回归用例；验证 `flutter test test/source_list_view_sort_action_test.dart` 通过。
  - 完成 `T02-seq119`（`book_source.xml / menu_sort_time / 更新时间排序`）：将书源管理排序菜单该子项文案由“更新时间”收敛为 legado 同义“更新时间排序”，并补齐“更新时间排序勾选态保持 + 反序联动勾选态保持”的页面级回归用例；验证 `flutter test test/source_list_view_sort_action_test.dart` 通过。
  - 完成 `T02-seq120`（`book_source.xml / menu_sort_respondTime / 响应时间排序`）：将书源管理排序菜单该子项文案由“响应时间”收敛为 legado 同义“响应时间排序”，并补齐“点击后单选勾选态保持”的页面级回归用例；验证 `flutter test test/source_list_view_sort_action_test.dart` 通过。
  - 完成 `T02-seq121`（`book_source.xml / menu_sort_enable / 是否启用`）：将书源管理排序菜单该子项文案由“启用状态”收敛为 legado 同义“是否启用”，并修正 `enabled` 排序在反序场景的边界语义为“仅反转启用分组、同组名称保持正序”；验证 `flutter test test/source_list_view_sort_action_test.dart` 通过。
  - 完成 `T02-seq122`（`book_source.xml / menu_group / 分组`）：将书源管理顶栏分组入口图标由 `folder` 收敛为 legado `ic_groups` 同义的分组语义图标，并补齐“分组入口弹层触发 + 动态分组写入 `group:` 即时筛选”的页面级回归证据；验证 `flutter test test/source_list_view_sort_action_test.dart test/search_view_source_manage_action_test.dart` 通过。
  - 完成 `T02-seq123`（`book_source.xml / menu_group_manage / 分组管理`）：将书源管理分组菜单中的“分组管理”入口收敛为 legado 同义“一级入口直接打开分组管理弹层”语义，并对齐分组管理弹层标题、新增分组入口与分组行“编辑/删除”操作入口层级；验证 `flutter test test/source_list_view_sort_action_test.dart test/search_view_source_manage_action_test.dart` 通过。
  - 完成 `T02-seq124`（`book_source.xml / menu_enabled_group / 已启用`）：将书源管理分组菜单该子项文案由“启用”收敛为 legado 同义“已启用”，并对齐点击后写入查询词“已启用”立即筛选 `enabled=true` 的触发语义；验证 `flutter test test/source_list_view_sort_action_test.dart test/search_view_source_manage_action_test.dart` 通过。
  - 完成 `T02-seq125`（`book_source.xml / menu_disabled_group / 已禁用`）：将书源管理分组菜单该子项文案由“禁用”收敛为 legado 同义“已禁用”，并对齐点击后写入查询词“已禁用”立即筛选 `enabled=false` 的触发语义；验证 `flutter test test/source_list_view_sort_action_test.dart test/search_view_source_manage_action_test.dart` 通过。
  - 完成 `T02-seq126`（`book_source.xml / menu_group_login / 需要登录`）：将书源管理分组菜单该子项文案由“需登录”收敛为 legado 同义“需要登录”，并对齐点击后写入查询词“需要登录”立即筛选 `loginUrl` 非空书源，同时保留“需登录”旧词兼容匹配；验证 `flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理顶栏分组入口会打开分组菜单"`、`flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理分组菜单需要登录项写入需要登录查询并即时筛选"`、`flutter test test/search_view_source_manage_action_test.dart` 通过。
  - 完成 `T02-seq127`（`book_source.xml / menu_group_null / 未分组`）：将书源管理分组菜单该子项文案由“无分组”收敛为 legado 同义“未分组”，并对齐点击后写入查询词“未分组”立即筛选 `bookSourceGroup` 为空或包含“未分组”的书源；同时保留“无分组”旧词兼容匹配，避免历史输入失效；验证 `flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理顶栏分组入口会打开分组菜单"`、`flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理分组菜单未分组项写入未分组查询并即时筛选"`、`flutter test test/search_view_source_manage_action_test.dart` 通过。
  - 完成 `T02-seq128`（`book_source.xml / menu_enabled_explore_group / 已启用发现`）：将书源管理分组菜单该子项文案由“启用发现”收敛为 legado 同义“已启用发现”，并对齐点击后写入查询词“已启用发现”立即筛选 `enabledExplore=true` 书源；同时保留“启用发现”旧词兼容匹配，避免历史输入失效；验证 `flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理顶栏分组入口会打开分组菜单"`、`flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理分组菜单已启用发现项写入已启用发现查询并即时筛选"` 通过。
  - 完成 `T02-seq129`（`book_source.xml / menu_disabled_explore_group / 已禁用发现`）：将书源管理分组菜单该子项文案由“禁用发现”收敛为 legado 同义“已禁用发现”，并对齐点击后写入查询词“已禁用发现”立即筛选 `enabledExplore=false` 书源；同时保留“禁用发现”旧词兼容匹配，避免历史输入失效；验证 `flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理顶栏分组入口会打开分组菜单"`、`flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理分组菜单已禁用发现项写入已禁用发现查询并即时筛选"` 通过。
  - 完成 `T02-seq130`（`book_source.xml / menu_add_book_source / 新建书源`）：确认书源管理“更多”菜单中的“新建书源”入口保持 legado `menu_add_book_source -> BookSourceEditActivity` 同义语义，点击后进入书源编辑页并默认开启“自动保存Cookie”；验证 `flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理更多菜单新建书源入口会打开书源编辑页"` 通过。
  - 完成 `T02-seq131`（`book_source.xml / menu_import_local / 本地导入`）：将书源管理“更多”菜单文案由“从文件导入”收敛为 legado 同义“本地导入”，并同步收敛网络导入 CORS 降级提示口径，确保本地导入语义在入口与异常提示保持一致；验证 `flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理更多菜单本地导入入口文案与 legado 一致"`、`flutter test test/source_import_export_service_test.dart --plain-name "importFromUrl returns actionable CORS hint on web"` 通过。
  - 完成 `T02-seq132`（`book_source.xml / menu_import_onLine / 网络导入`）：将书源管理“更多”菜单文案由“从网络导入”收敛为 legado 同义“网络导入”，并将网络导入弹层标题收敛为“网络导入”、输入占位收敛为“输入书源网址”；同时统一跨域降级提示口径为“本地导入”，避免同一导入链路文案漂移；验证 `flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理更多菜单网络导入入口文案与 legado 一致"`、`flutter test test/source_import_export_service_test.dart --plain-name "importFromUrl returns actionable CORS hint on web"` 通过。
  - 完成 `T02-seq133`（`book_source.xml / menu_import_qr / 二维码导入`）：将书源管理“更多”菜单文案由“扫码导入”收敛为 legado 同义“二维码导入”，并移除扫码 URL 自动写入网络导入历史的扩展路径，统一为“扫码结果直接进入书源导入解析链路”；验证 `flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理更多菜单"` 通过。
  - 完成 `T02-seq134`（`book_source.xml / menu_group_sources_by_domain / 按域名分组显示`）：将书源管理“更多”菜单该子项从“开/关文案切换”收敛为 legado 同义固定文案“按域名分组显示”并以勾选态表达开关状态；点击后保持按域名排序分组与域名分组头展示语义；验证 `flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理更多菜单按域名分组显示为勾选态切换语义"` 通过。
  - 完成 `T02-seq135`（`book_source.xml / menu_help / 帮助`）：将书源管理“更多”菜单帮助动作从本地简版文本提示收敛为 legado 同义 `showHelp("SourceMBookHelp")` 语义，接入同源 `SourceMBookHelp.md` 文档并复用帮助弹层展示链路；首次进入书源管理也改为加载同一文档，文档加载失败保持可观测提示；验证 `flutter test test/source_list_view_sort_action_test.dart --plain-name "书源管理更多菜单帮助入口会打开帮助弹层"` 通过。
  - 完成 `T02-seq136`（`book_source_debug.xml / menu_scan / 扫描二维码`）：将书源调试页扫码动作标题由“扫码调试”收敛为 legado 同义“扫描二维码”，并补齐可注入扫描启动器以稳定验证“点击顶栏扫码入口触发扫码动作”的同义链路；验证 `flutter test test/source_debug_legacy_view_scan_action_test.dart test/source_debug_legacy_view_compile_test.dart` 通过。
  - 完成 `T02-seq137`（`book_source_debug.xml / menu_search_src / 搜索源码`）：将书源调试页“搜索源码”动作从“源码为空时拦截提示”收敛为 legado 同义“点击即打开源码承载”语义，并将承载标题收敛为 legacy 同义 `html`；验证 `flutter test test/source_debug_legacy_view_search_src_action_test.dart test/source_debug_legacy_view_scan_action_test.dart test/source_debug_legacy_view_compile_test.dart` 通过。
  - 完成 `T02-seq138`（`book_source_debug.xml / menu_book_src / 书籍源码`）：将书源调试页“书籍源码”动作从“源码为空时拦截提示”收敛为 legado 同义“点击即打开源码承载”语义，并将菜单文案与承载标题分别收敛为 legacy 同义“书籍源码 / html”；验证 `flutter test test/source_debug_legacy_view_book_src_action_test.dart test/source_debug_legacy_view_search_src_action_test.dart test/source_debug_legacy_view_scan_action_test.dart test/source_debug_legacy_view_compile_test.dart` 通过。
  - 完成 `T02-seq139`（`book_source_debug.xml / menu_toc_src / 目录源码`）：将书源调试页“目录源码”动作从“源码为空时拦截提示”收敛为 legado 同义“点击即打开源码承载”语义，并将承载标题收敛为 legacy 同义 `html`；验证 `flutter test test/source_debug_legacy_view_toc_src_action_test.dart test/source_debug_legacy_view_book_src_action_test.dart test/source_debug_legacy_view_search_src_action_test.dart test/source_debug_legacy_view_scan_action_test.dart test/source_debug_legacy_view_compile_test.dart` 通过。
  - 完成 `T02-seq140`（`book_source_debug.xml / menu_content_src / 正文源码`）：将书源调试页“正文源码”动作从“源码为空时拦截提示”收敛为 legado 同义“点击即打开源码承载”语义，并将承载标题收敛为 legacy 同义 `html`；验证 `flutter test test/source_debug_legacy_view_content_src_action_test.dart test/source_debug_legacy_view_toc_src_action_test.dart test/source_debug_legacy_view_book_src_action_test.dart test/source_debug_legacy_view_search_src_action_test.dart test/source_debug_legacy_view_scan_action_test.dart test/source_debug_legacy_view_compile_test.dart` 通过。
  - 完成 `T02-seq141`（`book_source_debug.xml / menu_refresh_explore / 刷新发现`）：补齐书源调试页“刷新发现”与 legado 同义的刷新状态流转证据，动作顺序对齐为“清发现缓存 -> 清日志 -> 帮助区可见 -> 强制重载发现分类”；同时新增可选注入回调用于稳定验证刷新链路，默认运行时行为保持不变；验证 `flutter test test/source_debug_legacy_view_refresh_explore_action_test.dart test/source_debug_legacy_view_compile_test.dart` 通过。
  - 完成 `T02-seq142`（`book_source_debug.xml / menu_help / 帮助`）：将书源调试页“帮助”动作从内置提示文本收敛为 legado 同义 `showHelp("debugHelp")` 语义，接入同源 `debugHelp.md` 文档资产并复用统一帮助弹层；文档加载失败时保持“帮助文档加载失败：<error>”可观测提示；验证 `flutter test test/source_debug_legacy_view_help_action_test.dart test/source_debug_legacy_view_refresh_explore_action_test.dart test/source_debug_legacy_view_compile_test.dart` 通过。
  - 完成 `T02-seq143`（`book_source_item.xml / menu_top / 置顶`）：对齐 legado `menu_top` 语义，补齐“仅手动排序显示置顶入口 + 反序时置顶传递 `toTop=false`”定向证据；新增 `moveSourcesHandler` 可选注入点与条目更多按钮稳定 key 用于回归验证，默认运行时行为不变；验证 `flutter test test/source_list_view_item_top_action_test.dart test/source_list_view_compile_test.dart` 通过。
  - 完成 `T02-seq144`（`book_source_item.xml / menu_bottom / 置底`）：对齐 legado `menu_bottom` 语义，补齐“仅手动排序显示置底入口 + 升序时置底传递 `toTop=false` + 反序时置底传递 `toTop=true`”定向证据，保持运行时写库链路不变；验证 `flutter test test/source_list_view_item_top_action_test.dart test/source_list_view_compile_test.dart` 通过。
  - 完成 `T02-seq145`（`book_source_item.xml / menu_login / 登录`）：对齐 legado `menu_login` 语义，补齐“`loginUrl` 为空不显示入口 + 非空且存在 `loginUi` 点击后进入表单登录页”定向证据；登录动作改为按 `bookSourceUrl` 回查书源后再触发，缺失时提示“未找到书源”；验证 `flutter test test/source_list_view_item_top_action_test.dart` 通过。
  - 完成 `T02-seq146`（`book_source_item.xml / menu_search / 搜索`）：对齐 legado `menu_search -> SearchActivity(searchScope=SearchScope(bookSource))` 语义，点击后改为按条目快照先写入 `searchScope=<书源名去冒号>::<bookSourceUrl>` 再进入搜索页，不再依赖二次查库生成 scope；补齐“action sheet 打开后书源被删除仍保持 scope 快照并可进入搜索页”定向回归；验证 `flutter test test/source_list_view_item_top_action_test.dart`、`flutter test test/source_list_view_compile_test.dart` 通过。
  - 完成 `T02-seq147`（`book_source_item.xml / menu_debug_source / 调试`）：对齐 legado `menu_debug_source -> debug(source)` 语义，条目菜单点击“调试”后改为按条目快照直接打开书源调试页，不再先二次查库拦截；补齐“action sheet 打开后书源被删除仍可进入调试页”定向回归；验证 `flutter test test/source_list_view_item_top_action_test.dart`、`flutter test test/source_list_view_compile_test.dart` 通过。
  - 完成 `T02-seq148`（`book_source_item.xml / menu_del / 删除`）：对齐 legado `menu_del` 语义，删除确认弹窗标题由“提示”收敛为 `draw` 同义“提醒”，正文保持“是否确认删除？\\n<书源名>`；条目菜单点击“删除”后继续先移除选中态，再进入二次确认，取消不恢复，确认后删除书源记录并执行源变量清理。验证 `flutter test test/source_list_view_item_top_action_test.dart --plain-name "书源条目菜单删除会先移除选中态，取消后保留条目"`、`flutter test test/source_list_view_item_top_action_test.dart --plain-name "书源条目菜单确认删除后会删除条目"`、`flutter test test/source_variable_store_test.dart --plain-name "remove variable"` 通过。
  - 完成 `T02-seq149`（`book_source_item.xml / menu_enable_explore / 启用发现`）：对齐 legado `menu_enable_explore -> enableExplore(!enabledExplore, source)` 语义，保持“仅 `exploreUrl` 非空显示入口 + 文案按 `enabledExplore` 状态在启用/禁用间切换”；点击动作由直接 `updateSource(copyWith)` 收敛为“按 `bookSourceUrl` 回查现存记录后再更新”，避免 action sheet 打开期间书源被删除时被意外重建；验证 `flutter test test/source_list_view_item_top_action_test.dart --plain-name "书源条目菜单启用发现入口显隐与切换文案对齐 legado"`、`flutter test test/source_list_view_item_top_action_test.dart --plain-name "书源条目菜单启用发现在弹层期间删除书源不会重建记录"` 通过。
  - 完成 `T02-seq162`（`book_toc.xml / menu_search / 搜索`）：将目录页搜索从“常驻内联输入框”收敛为 legado 同义 `menu_search` 顶栏 action 语义，默认折叠为搜索图标；点击图标展开搜索框，输入后实时按章节标题过滤；失焦自动收起，关闭按钮清空查询并恢复全量目录。验证 `flutter test test/search_book_info_view_toc_search_action_test.dart test/search_book_info_view_compile_test.dart` 通过。
  - 完成 `T02-seq163`（`book_toc.xml / menu_toc_regex / TXT 目录规则`）：补齐目录页本地 TXT 场景的 legado 同义入口，仅本地 TXT 展示“TXT 目录规则”；新增书籍级 `tocRuleRegex` 持久化并打通 `TxtParser/SearchBookInfoRefreshHelper/阅读器重解析` 透传链路，选择规则后立即按该规则重建目录，取消不生效。验证 `flutter test test/txt_parser_toc_rule_regex_test.dart test/search_book_info_refresh_helper_test.dart test/app_settings_test.dart test/search_book_info_view_toc_search_action_test.dart test/search_book_info_view_compile_test.dart` 通过。
  - 完成 `T02-seq165`（`book_toc.xml / menu_reverse_toc / 反转目录`）：将目录页“倒序按钮”收敛为 legado 同义 `menu_reverse_toc` 菜单动作，统一在“更多 -> 反转目录”触发目录顺序切换；保留“先按章节标题过滤，再执行倒序”的检索边界，不引入 checkable 勾选态。验证 `flutter test test/search_book_info_view_toc_search_action_test.dart test/search_book_info_view_compile_test.dart` 通过。
  - 完成 `T02-seq168`（`book_toc.xml / menu_export_bookmark / 导出`）：对齐 legado `menu_export_bookmark -> saveBookmark` 语义，在目录页“更多”菜单补齐固定文案“导出”，并接入书签 JSON 导出链路；成功统一提示“导出成功”，取消不提示，失败写入异常日志并保持可观测反馈。验证 `flutter test test/search_book_info_view_toc_search_action_test.dart test/search_book_info_view_compile_test.dart` 通过。
  - 完成 `T02-seq169`（`book_toc.xml / menu_export_md / 导出(MD)`）：对齐 legado `menu_export_md -> saveBookmarkMd` 语义，在目录页“更多”菜单新增固定文案“导出(MD)”并接入书签 Markdown 导出链路；成功统一提示“导出成功”，取消不提示，失败写入异常日志并保持可观测反馈。验证 `flutter test test/search_book_info_view_toc_search_action_test.dart test/search_book_info_view_compile_test.dart` 通过。
  - 完成 `T02-seq64`（`book_read.xml / menu_change_source / 换源`）：将阅读页“换源”入口从“更多菜单二级动作”收敛为 legado 同义“顶栏一级动作”，并将默认点击行为收敛为整书换源；同时补齐顶栏换源图标长按分支弹层以承载“章节换源/书籍换源”菜单。验证 `flutter test test/reader_top_menu_test.dart test/simple_reader_view_compile_test.dart` 通过。
  - 完成 `T02-seq65`（`book_read.xml / menu_refresh / 刷新`）：将阅读页“刷新”入口从“更多菜单二级动作”收敛为 legado 同义“顶栏一级动作”，并将顶部刷新按钮点击语义对齐为 `menu_refresh=menu_refresh_dur`（刷新当前章节）；同时补齐顶部刷新图标长按分支弹层以承载“刷新当前章节/刷新之后章节/刷新全部章节”菜单，更多菜单移除刷新项以保持入口层级一致。验证 `flutter test test/reader_top_menu_test.dart test/reader_legacy_menu_helper_test.dart test/simple_reader_view_compile_test.dart` 通过。
  - 完成 `T02-seq66`（`book_read.xml / menu_download / 离线缓存`）：将阅读页“离线缓存”入口从“更多菜单二级动作”收敛为 legado 同义“顶栏一级动作”，并在点击后补齐章节范围输入对话框与范围缓存执行链路；同时将该动作从“阅读操作”菜单移除以保持单入口层级，失败分支写入异常日志保证可观测。验证 `flutter test test/reader_top_menu_test.dart test/reader_legacy_menu_helper_test.dart test/simple_reader_view_compile_test.dart` 通过。
  - 完成 `T02-seq67`（`book_read.xml / menu_toc_regex / TXT 目录规则`）：将阅读页 TXT 目录规则入口收敛为 legado 同义“取消不生效、确定统一提交”交互语义，新增确认式规则弹窗并保持“仅本地 TXT 显示”边界；点击确定后立即按当前编码与拆分配置重建目录，不追加扩展成功提示，失败路径统一可观测为 `LoadTocError`。验证 `flutter test test/reader_txt_toc_rule_dialog_test.dart test/reader_top_menu_test.dart test/reader_legacy_menu_helper_test.dart test/simple_reader_view_compile_test.dart` 通过。
  - 完成 `T02-seq68`（`book_read.xml / menu_set_charset / 设置编码`）：将阅读页“设置编码”从“阅读操作”二级菜单收敛为 legado 同义“本地书籍顶栏一级动作”；交互从固定选项改为输入式对话框（标题“设置编码”、输入框 `charset`，保留 legado 字符集建议值但允许自由输入）；确认后统一持久化编码并立即触发本地目录重载，本地 TXT 走带编码重解析、本地非 TXT 也执行目录重载，取消不生效且不追加扩展成功提示。验证 `flutter test test/reader_top_menu_test.dart test/reader_legacy_menu_helper_test.dart test/simple_reader_view_compile_test.dart` 通过。
  - 完成 `T02-seq83`（`book_read.xml / menu_update_toc / 更新目录`）：将阅读页“更新目录”收敛为 legado 同义语义：点击后进入加载态并执行目录重载，移除“目录已更新，共X章”扩展成功提示；在线书失败口径统一为“加载目录失败”，本地书失败统一为 `LoadTocError:*`；同时补齐本地目录刷新链路（含 TXT 目录规则/编码透传与 EPUB 刷新前缓存清理语义）。验证 `flutter test test/reader_top_menu_test.dart test/reader_legacy_menu_helper_test.dart test/simple_reader_view_compile_test.dart test/search_book_info_refresh_helper_test.dart` 与 `flutter test test/reader_catalog_sheet_test.dart` 通过。
  - 完成 `T02-seq94`（`book_read_refresh.xml / menu_refresh_dur / 刷新当前章节`）：对齐 legado `menu_refresh=menu_refresh_dur` 同分支语义，新增 `ReaderLegacyMenuHelper.defaultRefreshAction()` 固化默认刷新动作，并将阅读菜单 `refresh` 与顶栏刷新点击统一收敛到“刷新当前章节”主链路；长按刷新仍仅承载“刷新当前章节/刷新之后章节/刷新全部章节”分支入口。验证 `flutter test test/reader_legacy_menu_helper_test.dart test/reader_top_menu_test.dart test/simple_reader_view_compile_test.dart` 通过。
  - 完成 `T02-seq95`（`book_read_refresh.xml / menu_refresh_after / 刷新之后章节`）：补齐 legado `menu_refresh_after` 的范围语义证据，新增 `ReaderRefreshScopeHelper` 固化“从当前章节开始清理后续缓存”的计算与持久化范围；阅读页长按刷新选择“刷新之后章节”后，当前与后续章节缓存统一清理并重载当前章节，前序章节缓存保持不变；无可用书源时仍回落到当前章节重载，保持 legado `bookSource == null -> upContent()` 同义边界。验证 `flutter test test/reader_refresh_scope_helper_test.dart test/reader_legacy_menu_helper_test.dart test/reader_top_menu_test.dart test/simple_reader_view_compile_test.dart` 通过。
  - 完成 `T02-seq96`（`book_read_refresh.xml / menu_refresh_all / 刷新全部章节`）：对齐 legado `menu_refresh_all` 语义，复核并固化“有可用书源时从首章开始清理全量章节缓存并重载当前章节；无可用书源时回落当前章节重载”的边界；补充 `ReaderRefreshScopeHelper` 全量刷新映射与全量清缓存回写用例，确保 `menu_refresh_all` 具备独立可复现证据。验证 `flutter test test/reader_refresh_scope_helper_test.dart test/reader_legacy_menu_helper_test.dart test/reader_top_menu_test.dart test/simple_reader_view_compile_test.dart` 通过。
  - 完成 `T02-seq97`（`book_read_source.xml / menu_login / 登录`）：对齐 legado `menu_login -> SourceLoginActivity(key=bookSourceUrl)` 的实时触发语义，阅读页书源动作菜单点击“登录”后改为按 `bookSourceUrl` 回查当前书源再触发登录；`loginUrl` 为空保持入口隐藏，回查缺失统一提示“未找到书源”，避免 action sheet 打开期间使用过期书源快照。验证手工路径 `阅读页(网络书) -> 顶部书源名 -> 登录`（校验 `loginUrl` 为空不展示登录、非空点击可进入登录流程）。
  - 完成 `T02-seq98`（`book_read_source.xml / @+id/menu_chapter_pay / 购买`）：对齐 legado `menu_chapter_pay` 语义，书源动作菜单“购买”入口收敛为“仅 `loginUrl` 非空且当前章节 `isVip=true && isPay!=true` 显示”；点击后保留确认弹窗，确认分支改为按 `bookSourceUrl` 回查当前书源后执行 `payAction`，结果按 legado 分流为“绝对 URL 打开网页 / `isTrue` 返回值触发清缓存并刷新目录”；异常改为仅写日志 `执行购买操作出错`，移除扩展成功/失败提示。验证手工路径 `阅读页(网络书,VIP未购买章节) -> 顶部书源名 -> 章节购买 -> 确定`（校验显隐条件、URL 分支、truthy 分支与异常日志分支）。
  - 完成 `T02-seq99`（`book_read_source.xml / @+id/menu_edit_source / 编辑书源`）：对齐 legado `menu_edit_source -> openSourceEditActivity` 的实时触发语义，阅读页书源动作菜单点击“编辑书源”后改为按 `bookSourceUrl` 回查当前书源再打开编辑页；回查缺失统一提示“未找到书源”，避免 action sheet 打开期间使用过期书源快照；仅在编辑页保存返回时刷新阅读页书源显示，对齐 legado `RESULT_OK -> upBookSource/upMenuView` 回调边界。验证手工路径 `阅读页(网络书) -> 顶部书源名 -> 编辑书源`（校验可进入编辑页、弹层期间删除书源时提示“未找到书源”、取消返回不刷新、保存返回刷新书源显示）。
  - 完成 `T02-seq100`（`book_read_source.xml / @+id/menu_disable_source / 禁用书源`）：对齐 legado `menu_disable_source -> disableSource()` 语义，阅读页书源动作菜单点击“禁用书源”后收敛为“按 `bookSourceUrl` 回查当前书源并直接写库禁用”；移除确认弹窗与“已禁用书源”扩展成功提示，避免偏离 legado 的直接执行路径；回查缺失统一提示“未找到书源”。验证手工路径 `阅读页(网络书) -> 顶部书源名 -> 禁用书源`（校验无确认弹窗、点击后书源立即变为禁用、无成功 toast）。
  - 完成 `T02-seq164`（`book_toc.xml / @+id/menu_split_long_chapter / 拆分超长章节`）：目录页“更多”菜单补齐 legado 同义 `checkable` 入口“拆分超长章节”，仅本地 TXT 显示；点击后立即切换勾选态并触发本地 TXT 目录重建，目录列表实时刷新。验证手工路径 `书籍详情页 -> 查看目录 -> 更多 -> 拆分超长章节`（校验本地 TXT 显隐、勾选态同步、切换后目录即时刷新）。
  - 完成 `T02-seq166`（`book_toc.xml / @+id/menu_use_replace / 使用替换`）：目录页“更多”菜单补齐 legado 同义 `checkable` 入口“使用替换”，标题固定且通过勾选态表达状态；点击后仅切换全局目录替换开关并即时重算目录展示标题，不追加成功提示；同时将该开关持久化为全局设置以保持跨页面一致。验证手工路径 `书籍详情页 -> 查看目录 -> 更多 -> 使用替换`（校验固定文案、勾选态切换、切换后目录标题即时刷新且无成功 toast）。
  - 完成 `T02-seq167`（`book_toc.xml / @+id/menu_load_word_count / 加载字数`）：目录页“更多”菜单补齐 legado 同义 `checkable` 入口“加载字数”，标题固定并通过勾选态表达状态；新增全局持久化键 `toc_ui_load_word_count`（默认 `true`）并在详情目录页/阅读目录页统一读写。目录列表展示补齐“仅开关开启 + 章节存在可用字数字段时显示字数”的同义边界；当前实现先对齐已缓存章节的字数展示（按 legado 口径格式化为 `xx字/xx万字`），无可用字数字段时保持不显示。验证 `flutter test test/search_book_info_view_compile_test.dart`、`flutter test test/simple_reader_view_compile_test.dart`、`flutter test test/reader_catalog_sheet_test.dart` 通过；手工路径 `书籍详情页 -> 查看目录 -> 更多 -> 加载字数`（校验固定文案、勾选态切换、无成功提示、目录项字数按开关显隐）。
  - 完成 `T02-seq69`（`book_read.xml / @+id/menu_add_bookmark / 添加书签`）：将阅读页“添加书签”从“有则删无则加”收敛为 legado 同义“弹出书签编辑框 -> 取消不保存 -> 确定新增”；阅读操作菜单与九宫格点击动作统一复用该流程，默认预填当前阅读页文本并记录章节进度，目录书签页点击书签后补齐按 `chapterPos` 恢复阅读进度。
  - 验证：手工路径 `阅读页 -> 阅读操作 -> 添加书签`、`阅读页 -> 九宫格点击动作(添加书签)`、`阅读页 -> 目录/书签 -> 选择书签`（校验弹窗标题“书签”、章节标题展示、内容/备注输入框可编辑、取消不落库、确定后新增可见并可按进度跳转）。
  - 兼容影响：无旧书源兼容性破坏；本序号仅收敛书签交互语义与书签跳转进度恢复，未改动书源解析与网络链路。
  - 完成 `T02-seq70`（`book_read.xml / @+id/menu_edit_content / 编辑内容`）：对齐 legado `menu_edit_content -> ContentEditDialog` 的异常与加载边界，补齐正文抓取失败时“记录日志 + 回退当前显示内容 + 保持入口可继续”的兜底语义，避免异常中断编辑链路；编辑页“重置”期间增加全屏遮罩与整页交互锁定，贴齐 legado `loadState` 下不可交互语义，同时保持关闭/返回自动保存行为不变。
  - 验证：手工路径 `阅读页 -> 阅读操作 -> 编辑正文 -> 重置`、`阅读页 -> 阅读操作 -> 编辑正文 -> 关闭`、`阅读页 -> 阅读操作 -> 正文倒序`（校验重置期间全屏 loading 与交互锁定、关闭自动保存、正文抓取失败时提示“获取正文失败，已回退当前显示内容”且日志节点可观测）。
  - 兼容影响：无旧书源兼容性破坏；本序号仅收敛 `menu_edit_content` 的异常兜底与重置加载态，不改动书源解析规则与网络请求参数。
  - 下一项：`seq71`（`book_read.xml / @+id/menu_page_anim / 翻页动画（本书）`）。

## 说明

- 你已明确要求“挨个处理所有功能”，本计划据此将全功能域纳入执行范围。
- 若过程中出现 legado 无法等价复现项，将按 `blocked` 记录在主 ExecPlan 后再继续后续可推进项。
