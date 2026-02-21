# 正文链路对照清单（T11 / C5）

- 任务状态：`active`
- 对应计划：`PLANS.md` / `T11`
- 产出日期：`2026-02-21`
- 对照基准：
  - `../legado/app/src/main/res/menu/book_read.xml`
  - `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookViewModel.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/read/ContentEditDialog.kt`

## 1. 差异点清单（实现前 -> 本次收敛）

| 差异ID | legacy 行为 | soupreader 原状态 | 本次处理 | 影响 |
|---|---|---|---|---|
| C5-011 | `menu_edit_content` 的“重置”会执行“清缓存 -> 重新拉正文 -> 回填编辑器”，不是仅回到打开时快照 | 编辑页“重置”仅回填初始文本，未触发重新拉正文与底层章节重载 | 新增 `_reloadChapterRawContentForEditor`：重置时清空章节缓存、重新取正文、回写章节并重载当前章节 | 编辑正文状态流转与 legacy 同义，避免“重置后仍是旧缓存” |
| C5-012 | 编辑正文在加载期不会允许并发触发保存/关闭/重置 | 重置过程可重复触发，可能与保存/关闭并发 | 编辑页新增 `_resetting` 锁、按钮禁用与 `CupertinoActivityIndicator` | 取消/清理与边界行为更稳定 |
| C5-013 | `book_read.xml` 中 `获取进度/覆盖进度/重新分段/图片样式` 均为正文菜单一等入口 | 历史版本对这些入口有占位/语义偏差风险 | 逐项核验并保持动作链路可达，补齐 C5 清单证据回填 | T11 本批次可追踪，进入剩余差异收口 |
| C5-014 | 正文清洗阶段需保留 `<img src>` 并绝对化（`HtmlFormatter.formatKeepImg`），供渲染层按图片样式分流 | 解析层使用纯文本清洗，`<img>` 在入库前被剥离，后续无法按样式渲染 | `HtmlTextFormatter` 新增 `formatKeepImageTags`，`RuleParserEngine.getContent/getContentDebug` 改为保留图片标签并绝对化链接 | 滚动模式可进入图片分流渲染链路，补齐图片样式主干语义 |
| C5-015 | `syncBookProgress` 为全局开关（默认开启），关闭时手动“拉取/覆盖进度”与同步动作均应短路 | 仅按 WebDav 配置可用性放行，缺少全局开关约束 | `AppSettings` 新增 `syncBookProgress`（默认 `true`）并在阅读器“获取/覆盖进度 + 点击区同步动作”前统一守卫 | 与 legacy 的同步开关语义同义，避免“已关闭同步仍发请求” |
| C5-016 | 翻页模式需像 legacy `ChapterProvider/TextChapterLayout` 一样参与图片分页，不应把 `<img>` 回退为纯占位字符 | 旧实现在翻页模式将图片标签统一替换为 `▣`，导致图片样式菜单仅有状态无渲染语义 | 新增 `ReaderImageMarkerCodec` 元数据（`src + 可选尺寸`）与运行时尺寸缓存；`ReaderPageAgent` 分页高度改为“实测尺寸缓存 > 标记尺寸提示 > 估算值”；`PagedReaderWidget` 在图片加载成功后回写尺寸缓存并触发重新分页 | 翻页模式图片分页从“纯估算”收敛为“可渐进逼近真实尺寸”；首次未命中缓存时仍存在估算误差 |
| C5-017 | legacy 在 `simulation/simulation2` 下不因图片页而回退为 `cover`，仿真翻页路径保持可达 | 旧实现检测到图片标记页时会强制回退 `cover`，导致仿真路径被短路 | 移除 `simulation/simulation2 -> cover` 回退分支；图片标记页在仿真模式改走快照路径（标记行转占位符快照），并补充 simulation 图片页翻页测试 | 图片页可继续走仿真翻页交互链路，关闭“有图片即降级”偏差 |
| C5-018 | legacy 在分页阶段会先取图片真实尺寸再分页，首帧分页断点依赖真实尺寸 | 现有实现主要依赖“图片页渲染后回写尺寸 -> 二次重分页”，首次进章仍可能先用估算值 | 在 `_loadChapter` 增加“分页前图片尺寸预热”：对当前章 marker 图执行“尺寸提示落缓存 + 限时尺寸探测（最多 8 张 / 260ms）”再进入首轮分页 | 首帧命中率提升，常见章节可直接按真实尺寸分页；网络超时或鉴权图片仍回落估算兜底 |
| C5-019 | legacy 章节分页链路会在布局任务中提前准备图片（`BookHelp.saveImages + ImageProvider.getImageSize`），切章时真实尺寸命中率较高 | 现有实现仅在当前章节 `_loadChapter` 做预热，邻章预取仅拉正文不探测图片尺寸，切入邻章首帧仍易回落估算 | `_prefetchChapterIfNeeded` 新增“邻章后处理 + 轻量尺寸预热（最多 6 张 / 180ms）”；无论邻章正文来自缓存还是网络预取，均尝试提前落图片尺寸缓存 | 跨章节切换命中率提升，减少“已预取章节仍首帧估算分页”的偏差；鉴权/慢源仍存在超时兜底差异 |
| C5-020 | legacy 图片请求链路会复用书源 Header/Cookie 与 URL option（含鉴权/Referer），并在慢源下保持可观测重试窗口 | 现有实现 `NetworkImage` 默认无书源上下文，鉴权图尺寸探测容易失败；固定 180~260ms 预热窗口在慢源下命中率偏低 | 新增 `ReaderImageRequestParser`（保留 `url,{option}` 并解析 headers）；阅读器图片 provider 合并“书源 header + option header + CookieJar 缓存 + Referer/Origin”；预热链路新增 source-aware 尺寸探测回退（`SourceCoverLoader.fetchCoverBytes`）与按“最近章节请求耗时/书源 respondTime”自适应预算 | 鉴权图片尺寸探测成功率与慢源首帧命中率提升；超时兜底仍保留估算分页，未完全达到 legacy 的同步尺寸确定性 |
| C5-021 | legacy `TextChapterLayout/ChapterProvider` 在分页链路直接消费 `ImageProvider.getImageSize`，对相对 URL、慢源重试与长图比例具备更强稳定性 | 既有实现 source-aware 尺寸探测只有单次回退，且 marker 尺寸提示仅依赖标签 `width/height`，长图在超时兜底时估算偏差较大 | 新增“source-aware 两段探测”：先走 `SourceCoverLoader` 缓存链路，再走 `RuleParserEngine.fetchCoverBytes` 直连重试；同时补齐尺寸提示来源（`style aspect-ratio` 推导 + URL query/CDN `w_/h_` 解析）并写入 marker 元数据 | 慢源/鉴权/相对 URL 的尺寸命中率继续提升，极端长图在未命中真实尺寸时也能用更接近真实比例的提示参与首帧分页 |
| C5-022 | legacy `BookHelp.saveImages + ImageProvider.getImageSize` 形成“章节间可复用 + 重进阅读可复用”的尺寸命中效果，并可在长图偏差高时通过真实尺寸持续收敛 | 现有实现尺寸缓存仅驻留内存，重进阅读后冷启动命中率回落；长图偏差未反馈到预算策略 | `ReaderImageMarkerCodec` 增加尺寸快照导入/导出与 URL 级 key 归一化，`SettingsService` 新增书籍级快照持久化；`SimpleReaderView` 接入“启动恢复 + 防抖落盘 + 长图误差采样 -> warmup 预算自适应”闭环，`PagedReaderWidget` 增加尺寸回写回调 | source-aware 探测结果可跨章节与重进会话复用，长图高误差章节会自动放宽探测预算，进一步降低首帧估算分页概率 |
| C5-023 | legacy 在尺寸探测失败时会持续尝试并按源站表现动态收敛（超时/鉴权/解码失败不会长期固定同一预算） | 现有实现预算自适应仅依赖“章节耗时 + 长图误差”，缺少失败类型分层与按书源粒度调参 | `SimpleReaderView` 增加探测结果三态（成功/失败类型/是否实际探测）、失败类型分层采样（`timeout/auth/decode/other`）与按书源遥测；`_resolveImageWarmupBudget` 新增 source-level 超时/鉴权/解码速率与连续失败阈值调参 | 连续超时、偶发鉴权失败、解码异常场景下可针对当前书源自动放宽探测预算，减少“某些源长期首帧估算分页”的尾部偏差 |

## 2. 逐项检查清单（入口/状态/异常/文案/排版/触发）

### 2.1 编辑正文（`menu_edit_content`）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：正文菜单动作可直接进入编辑页 | `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt:514`, `lib/features/reader/views/simple_reader_view.dart:4513` |
| 状态 | 已同义：关闭/返回均会带回编辑结果并落库，重置期禁用保存/关闭避免并发 | `../legado/app/src/main/java/io/legado/app/ui/book/read/ContentEditDialog.kt:109`, `lib/features/reader/views/simple_reader_view.dart:9846` |
| 异常 | 已同义：章节不存在时阻断并提示；重置失败有可观测弹窗 | `lib/features/reader/views/simple_reader_view.dart:4514`, `lib/features/reader/views/simple_reader_view.dart:9898` |
| 文案 | 已同义：保留 `编辑正文/重置/复制全文` 业务语义 | `../legado/app/src/main/res/menu/content_edit.xml`, `lib/features/reader/views/simple_reader_view.dart:9931` |
| 排版 | 已同义：采用全屏编辑容器承载标题+正文编辑，符合 legacy 弹层编辑语义 | `../legado/app/src/main/java/io/legado/app/ui/book/read/ContentEditDialog.kt:41`, `lib/features/reader/views/simple_reader_view.dart:9929` |
| 交互触发 | 已同义：重置动作触发“清缓存 -> 重新取正文 -> 回填 -> 重载正文” | `../legado/app/src/main/java/io/legado/app/ui/book/read/ContentEditDialog.kt:80`, `lib/features/reader/views/simple_reader_view.dart:4564` |
| 输入 | 已同义：标题、正文都可编辑，空标题回退原章节标题 | `lib/features/reader/views/simple_reader_view.dart:4543`, `lib/features/reader/views/simple_reader_view.dart:9950` |
| 交互逻辑 | 已同义：重置与保存均会回流到当前章节重载，避免 UI 与缓存脱节 | `../legado/app/src/main/java/io/legado/app/ui/book/read/ContentEditDialog.kt:127`, `lib/features/reader/views/simple_reader_view.dart:4615` |

### 2.2 获取进度 / 覆盖进度（`menu_get_progress/menu_cover_progress`）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：WebDav 配置可用时显示菜单入口并可触发动作 | `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt:443`, `lib/features/reader/services/reader_legacy_menu_helper.dart:42` |
| 状态 | 已同义：新增全局开关守卫；开关关闭时动作短路，开启后仍保持“云端进度落后弹窗确认”流程 | `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookViewModel.kt:244`, `lib/core/models/app_settings.dart:63`, `lib/features/reader/views/simple_reader_view.dart:4582` |
| 异常 | 已同义：未配置/目录为空/请求失败保持可观测；全局开关关闭时按 legacy 语义直接短路 | `../legado/app/src/main/java/io/legado/app/help/AppWebDav.kt:248`, `lib/features/reader/views/simple_reader_view.dart:4671` |
| 文案 | 已同义：`获取进度/覆盖进度` 文案与业务含义保持一致 | `../legado/app/src/main/res/menu/book_read.xml:63`, `lib/features/reader/services/reader_legacy_menu_helper.dart:112` |
| 排版 | 已同义：入口仍在“阅读操作”ActionSheet 主动作区 | `lib/features/reader/views/simple_reader_view.dart:3444`, `lib/features/reader/views/simple_reader_view.dart:5097` |
| 交互触发 | 已同义：获取/覆盖触发前先检查全局开关，放行后执行原有拉取/上传链路 | `../legado/app/src/main/java/io/legado/app/model/ReadBook.kt:256`, `lib/features/reader/views/simple_reader_view.dart:4697` |
| 输入 | 不涉及 | - |
| 交互逻辑 | 已同义：覆盖分支在上传前先保存本地进度，且点击区同步动作同样受全局开关约束 | `lib/features/reader/views/simple_reader_view.dart:2155`, `lib/features/reader/views/simple_reader_view.dart:4670` |

### 2.3 重新分段（`menu_re_segment`）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：正文菜单可直接切换“重新分段” | `../legado/app/src/main/res/menu/book_read.xml:98`, `lib/features/reader/views/simple_reader_view.dart:5173` |
| 状态 | 已同义：菜单勾选态与持久化值同步 | `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt:430`, `lib/features/reader/views/simple_reader_view.dart:3486` |
| 异常 | 已同义：章节不存在时由章节加载链路兜底，不会崩溃 | `lib/features/reader/views/simple_reader_view.dart:1264`, `lib/features/reader/views/simple_reader_view.dart:4619` |
| 文案 | 已同义：保持“重新分段”业务语义 | `../legado/app/src/main/res/menu/book_read.xml:101`, `lib/features/reader/services/reader_legacy_menu_helper.dart:124` |
| 排版 | 已同义：勾选态通过 `✓` 前缀展示在阅读操作列表中 | `lib/features/reader/views/simple_reader_view.dart:3479` |
| 交互触发 | 已同义：切换后立即重建章节内容并重载当前章节 | `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt:527`, `lib/features/reader/views/simple_reader_view.dart:4628` |
| 输入 | 不涉及 | - |
| 交互逻辑 | 已同义：持久化后再重载，保证重进阅读时状态一致 | `lib/features/reader/views/simple_reader_view.dart:4621` |

### 2.4 图片样式（`menu_image_style`）

| 检查项 | 对照结果 | 证据 |
|---|---|---|
| 入口 | 已同义：正文菜单可进入“图片样式”选择 | `../legado/app/src/main/res/menu/book_read.xml:131`, `lib/features/reader/views/simple_reader_view.dart:4634` |
| 状态 | 已同义：`DEFAULT/FULL/TEXT/SINGLE` 选项可切换并持久化 | `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt:577`, `lib/features/reader/views/simple_reader_view.dart:4664` |
| 异常 | 已同义：取消选择不落库，不触发重载 | `lib/features/reader/views/simple_reader_view.dart:4660` |
| 文案 | 已同义：保留“图片样式”语义与四档风格常量 | `../legado/app/src/main/java/io/legado/app/data/entities/Book.kt:386`, `lib/features/reader/views/simple_reader_view.dart:264` |
| 排版 | 已同义：以 ActionSheet 承载样式列表并展示勾选态 | `lib/features/reader/views/simple_reader_view.dart:4638` |
| 交互触发 | 已同义：切换后立即重载当前章节；选择 `SINGLE` 时自动回落覆盖翻页动画 | `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt:586`, `lib/features/reader/views/simple_reader_view.dart:4674` |
| 输入 | 不涉及 | - |
| 交互逻辑 | 部分同义：滚动模式已按 `FULL/TEXT/SINGLE` 分流；翻页模式已支持图片标记分页与图片块渲染，并移除仿真模式“遇图回退 cover”分支。现阶段形成“当前章预热 + 邻章预热 + source-aware 双阶段探测（缓存链路 + 直连重试）+ 探测失败分层采样（timeout/auth/decode/other）+ 按书源预算自适应 + 尺寸回写重分页 + 书籍级快照恢复 + 长图误差采样自适应预算”闭环。连续超慢源且双阶段探测持续超时时仍可能回落估算值，尚未完全等价 legacy 的全量首帧真实尺寸分页 | `lib/features/reader/views/simple_reader_view.dart:2986`, `lib/features/reader/views/simple_reader_view.dart:3074`, `lib/features/reader/views/simple_reader_view.dart:3204`, `lib/features/reader/views/simple_reader_view.dart:3301`, `lib/features/reader/views/simple_reader_view.dart:11648`, `lib/features/reader/widgets/paged_reader_widget.dart:2403`, `lib/features/reader/services/reader_image_marker_codec.dart:131`, `lib/core/services/settings_service.dart:397` |

## 3. 回归路径 C5（正文）

- 路径：阅读器 -> 阅读操作 -> `编辑正文/获取进度/覆盖进度/重新分段/图片样式`。
- 手工核验点：
  - 编辑正文点击“重置”后会出现加载态，结束后正文被回填并刷新。
  - 备份设置关闭“同步阅读进度”后，阅读菜单与点击区同步动作均不再发起云端请求；重新开启后恢复。
  - 获取进度在“本地进度领先云端”时弹确认，确认后跳转到云端位置。
  - 覆盖进度会先保存本地进度，再上传并提示结果。
  - 重新分段切换后勾选态刷新，正文立即重载。
  - 非 `TEXT` 图片样式在翻页模式不再显示 `▣` 占位字符，可看到图片块并参与翻页。
  - 图片样式选择 `SINGLE` 后会强制切到覆盖翻页动画。
  - 翻页动画切到 `simulation/simulation2` 时，含图片页不再自动降级为 `cover`，右侧点击/滑动仍可完成翻页。
  - 连续翻到相邻章节时（触发过邻章预取），图片页更高概率在首帧直接按真实尺寸分页。
  - 退出并重新进入同一本书后，已探测过的图片尺寸可从快照恢复，首帧分页不必完全从估算冷启动。
  - 含 `url,{headers}` 的鉴权图片在翻页模式下可复用书源 header/Cookie 探测尺寸，慢源下预热窗口会放宽而非固定 180~260ms。
  - 含相对 URL 或慢源图片时，source-aware 探测会在缓存链路失败后走直连重试，不再只尝试单次回退。
  - 含 `w/h` query（或 CDN `w_*/h_*`）与 `aspect-ratio` 样式的图片，marker 会携带维度提示，首帧分页断点更接近真实比例。
  - 连续出现长图首帧偏差时，后续章节 warmup 探测预算会自动上调（探测张数/时窗/单次超时），抑制重复估算回退。
  - 对同一书源连续制造 `timeout/auth/decode` 失败后，后续章节 warmup 会按失败类型与连续次数继续增配预算，而非回退固定预算。

## 4. 命令验证证据

```bash
flutter test test/html_text_formatter_test.dart test/rule_parser_engine_stage_js_compat_test.dart test/simple_reader_view_compile_test.dart
flutter test test/backup_settings_view_compile_test.dart test/app_settings_test.dart test/simple_reader_view_compile_test.dart
flutter test test/reader_image_marker_codec_test.dart
flutter test test/paged_reader_widget_non_simulation_test.dart
flutter test test/paged_reader_widget_simulation_image_test.dart
flutter test test/reader_image_request_parser_test.dart
flutter test test/simple_reader_view_compile_test.dart test/reader_image_marker_codec_test.dart test/paged_reader_widget_non_simulation_test.dart test/paged_reader_widget_simulation_image_test.dart
flutter test test/page_factory_listener_test.dart
flutter test test/simple_reader_view_compile_test.dart
flutter test test/simple_reader_view_compile_test.dart test/reader_image_request_parser_test.dart test/reader_image_marker_codec_test.dart test/paged_reader_widget_non_simulation_test.dart test/paged_reader_widget_simulation_image_test.dart
flutter test test/reader_image_marker_codec_test.dart test/app_settings_test.dart test/simple_reader_view_compile_test.dart test/paged_reader_widget_non_simulation_test.dart test/paged_reader_widget_simulation_image_test.dart
flutter test test/simple_reader_view_compile_test.dart test/paged_reader_widget_non_simulation_test.dart test/paged_reader_widget_simulation_image_test.dart test/reader_image_marker_codec_test.dart test/reader_image_request_parser_test.dart
```

- 结果：通过。
- 说明：按仓库规则，本阶段未执行 `flutter analyze`（保留到 T18 提交前一次执行）。

## 5. 保留差异与后续

- 保留差异 1：legacy 在分页阶段直接通过 `ImageProvider.getImageSize` 同步获得真实尺寸；当前实现已补齐“章节加载/邻章预取预热 + source-aware 双阶段探测重试 + URL/样式维度提示 + 失败类型分层采样 + 按书源预算自适应 + 运行时回写重分页 + 书籍级快照恢复 + 长图误差预算自适应”，但在连续超时且双阶段探测均失败、或极端慢源不可达时，首帧仍会回落估算高度。
- 回补计划：后续继续推进“按失败类型拆分探测队列优先级（timeout/auth/decode）+ 真机慢源样本回放基准”，进一步逼近 legacy 的全量真实尺寸首帧分页。
