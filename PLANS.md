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
- 标记为 `detail_later` 的项默认在对应模块主功能可用后再处理。

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

- `2026-02-21`
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
  - 下一项：`seq123`（`book_source.xml / menu_group_manage / 分组管理`）。

## 说明

- 你已明确要求“挨个处理所有功能”，本计划据此将全功能域纳入执行范围。
- 若过程中出现 legado 无法等价复现项，将按 `blocked` 记录在主 ExecPlan 后再继续后续可推进项。
