# SoupReader 开发清单（对齐版）

> 目标重申：**功能对标 dbss，协议/规则 100% 使用 legado 语义**。
>
> 本清单用于约束后续开发方向，避免“功能能跑但规则不兼容”或“规则兼容但链路不可用”。

## 0. 不可妥协原则（硬约束）

### 0.1 协议/规则层：100% legado

- 书源协议字段、规则解析顺序、运算符语义、URL 选项语义，全部以 `legado` 为唯一标准。
- 禁止引入会改变 legado 旧书源行为的“自定义语义”。
- 若实现简化与 legado 有差异，必须：
  1) 在文档明确标注；
  2) 提供回退兼容方案；
  3) 补最小复现测试。

### 0.2 功能链路层：对标 dbss 可用性

- 搜索 / 发现 / 详情 / 目录 / 正文 五段链路，以 `dbss/source_analyzer` 的可跑通结果为落地目标。
- 同一书源、同一输入下，SoupReader 与 dbss 在“可用性结果”上应一致：
  - 能否成功拉取；
  - 关键字段是否可解析；
  - 分页是否可持续；
  - 异常是否可诊断。

### 0.3 冲突处理优先级

1. **legado 规则语义不退化**；
2. **dbss 功能链路可跑通**；
3. 再做性能/UI 优化。

---

## 1. 当前状态（截至本次）

### 1.1 已完成（✅）

- ✅ URL 规则链兼容：`@js` / `<js>` / URL option / `jsLib`。
- ✅ Web 端 JS 运行时适配（规避 FFI 造成的 Web 构建/运行问题）。
- ✅ `nextContentUrl`：多候选顺序消费 + 下一章阻断。
- ✅ `nextTocUrl`：多候选顺序消费。
- ✅ Web 书源网络导入移除 `HttpClient`（避免 `Unsupported operation: platform_version`）。
- ✅ 调试链路补“next 候选决策日志”（入队/丢弃原因可观测）。
- ✅ 调试链路补“请求决策日志”（method/retry/charset/body）。
- ✅ 调试包补“运行时变量快照（脱敏）”。
- ✅ 调试页支持“一键复制最小复现信息”。
- ✅ 可用性检测增强：结果筛选 / 一键禁用失效源 / 检测报告导出。
- ✅ 源编辑器增加“规则体检（字段 lint + 缺失风险）”。

### 1.2 未完成（⚠️）

- ⚠️ legado 规则全集仍未达“声明级 100% 覆盖”。
- ⚠️ 与 dbss 缺少系统化“对照回归样本集”（目前多为单点回归）。
- ⚠️ dbss 对照样本集与通过率统计尚未建立。

---

## 2. P0 清单（先做，必须落地）

## 2.1 legado 协议规则 100% 对齐（最高优先级）

- [ ] 建立《legado 规则对齐矩阵》并逐项打勾（字段/语义/边界）。
- [ ] 复核 `@put/@get` 跨阶段作用域（搜索→详情→目录→正文）。
- [ ] 复核 `&& / || / %%` 在嵌套模板、JsonPath 过滤、正则中的边界行为。
- [ ] 复核 `ruleToc.preUpdateJs`、`ruleContent.webJs` 的执行时机与上下文绑定。
- [ ] 复核 header/URL option 在动态脚本+转义输入下的 legado 行为一致性。

**验收标准**
- 每一项至少有 1 个最小复现用例。
- 不允许只给“人工验证通过”的结论。

## 2.2 dbss 五段链路能力对标（同优先级）

- [ ] 建立《dbss 链路对照样本集》（至少 20 个典型书源）。
- [ ] 搜索链路：结果数量、关键字段（name/author/bookUrl/coverUrl）可比对。
- [ ] 详情链路：`tocUrl` 回退策略与 dbss 对齐。
- [ ] 目录链路：分页稳定性、章节去重与顺序一致。
- [ ] 正文链路：分页拼接、下一章阻断、replaceRegex 后处理一致。

**验收标准**
- 对照样本集通过率可统计；失败案例有定位标签（请求/规则/编码/分页）。

## 2.3 调试与可观测（保障可维护）

- [x] next 候选队列日志（入队/丢弃理由）。
- [x] 请求决策日志：method/retry/charset/body 编码决策。
- [x] 导出调试包包含运行时变量快照（脱敏）。
- [x] 调试结果支持“一键复制最小复现信息”。

---

## 3. P1 清单（稳定后推进）

## 3.1 源编辑器与规则验证

- [x] 字段级 lint（空值、非法表达式、常见误写）。
- [x] 字段即时预览（chapterName/chapterUrl/content）。
- [x] 一次性校验“legado 关键字段缺失风险”。

## 3.2 阅读链路与缓存策略

- [ ] 分页抓取参数化（最大页数、重试、超时、限流）。
- [ ] 章节缓存命中统计与可视化。
- [ ] 预取策略（可开关）与失败回退策略。

## 3.3 Web 导入体验完善

- [x] CORS 失败时给出“可执行替代流程”（剪贴板/文件导入）。
- [x] URL 导入前校验 + 友好提示（协议、域名、可访问性）。
- [x] 统一导入错误文案，杜绝底层异常直出给用户。

---

## 4. P2 清单（长期）

- [ ] 备份增强（书源/设置/书架分项导出）。
- [ ] WebDAV/云同步最小实现。
- [ ] 书源订阅市场基础能力（拉取、更新、冲突处理）。

---

## 5. 测试与发布门禁

## 5.1 必跑测试（解析引擎改动）

- [x] `test/rule_parser_engine_next_url_compat_test.dart`
- [x] `test/rule_parser_engine_rule_split_compat_test.dart`
- [x] `test/rule_parser_engine_variable_rule_compat_test.dart`
- [x] `test/rule_parser_engine_url_option_compat_test.dart`
- [x] `test/rule_parser_engine_css_nth_compat_test.dart`

## 5.2 Web 发布流程

- [x] `flutter build web --release --no-wasm-dry-run --pwa-strategy=none`
- [x] 同步到 `/home/wwwroot/chat.jdsharecodes.top`
- [x] 校验 `https://happy.jdsharecodes.top` 与 `main.dart.js` 返回 `200`

---

## 6. 下一迭代执行顺序（建议）

1. 完成 `@put/@get` 跨阶段语义对齐 + 回归用例（P0-2.1）。
2. 建立 dbss 对照样本集并跑通 20 个源（P0-2.2）。
3. 补请求决策日志与调试包变量快照（P0-2.3）。
4. 再进入 Web 导入体验与源编辑器增强（P1）。
