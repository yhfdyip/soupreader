# 书源管理复刻对齐清单（Legado 基准）

更新时间：2026-02-13

## 对齐范围
- 目标：`/home/server/soupreader` 书源管理、导入、可用性检测、调试页交互。
- 基准：`/home/server/legado` 同名功能实现。

## 已对齐项
- [x] 导入协议
  - [x] 支持 `URL / JSON / sourceUrls` 统一导入入口。
  - [x] 支持 `#requestWithoutUA`（`User-Agent: null`）。
  - [x] 导入预览支持冲突识别、单条编辑、批量保留策略。
  - [x] 扫码导入与剪贴板导入语义一致。
- [x] 书源管理批量动作
  - [x] 批量启用/禁用、发现启停、分组加入/移除、置顶/置底、删除、导出。
  - [x] 批量分享改为“文件分享优先，失败回退复制 JSON”。
- [x] 检测流程
  - [x] 开始检测前支持关键词确认与持久化（默认回落 `我的`）。
  - [x] 检测任务改为服务化，离开检测页后任务可继续，回到页面可恢复当前进度。
  - [x] 检测页支持结果筛选、报告复制/导出、一键禁用失效源。
  - [x] 管理页展示最近检测摘要，并支持“一键筛选失败/空列表书源”。
- [x] 调试页
  - [x] legacy 快捷区布局与入口语义（`我的/系统/发现候选/详情URL/++目录/--正文`）。
  - [x] 菜单动作：查看搜索/详情/目录/正文源码、刷新发现快捷项、调试帮助。
  - [x] key 解析语义统一（URL/`标题::url`/`++`/`--`/关键字），多入口行为一致。
  - [x] `标题::url` 调试会实际使用输入 URL（对齐 legado `substringAfter("::")`）。
  - [x] 刷新发现快捷项会触发一次发现请求并合并本地候选刷新。
  - [x] 管理页展示最近调试摘要，并支持按“调试失败源”快速筛选。

## 当前差异（平台/实现差异，已记录）
- [ ] `CheckSource` 后台常驻任务与恢复机制（Android Service 语义）未 1:1 复刻。
  - 原因：当前仅实现应用内任务服务（页面可退出后继续），未实现 Android 前台 Service + 系统通知常驻。
  - 影响：应用进程被系统回收后任务不会继续执行；无系统级常驻通知入口。

## 复刻基准文件（本轮）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceViewModel.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/source/BookSourceExtensions.kt`
