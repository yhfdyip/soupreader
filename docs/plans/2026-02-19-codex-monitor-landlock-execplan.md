# Codex 监控脚本沙箱模式稳定化

- 状态：`done`
- 基线：`codex_task_monitor.sh`（仓库根）
- 更新时间：2026-02-19

## 背景与目标

### 背景

当前运行环境在使用 `workspace-write` 沙箱时会触发：

- `error applying legacy Linux sandbox restrictions: Sandbox(LandlockRestrict)`

根目录脚本 `codex_task_monitor.sh` 的默认命令同时出现 `-s danger-full-access` 与 `--full-auto`，存在参数语义冲突，实际运行时可能回退为 `workspace-write`，导致执行中断。

### 目标

1. 让脚本默认命令稳定落在 Full access 路径，避免 Landlock 沙箱失败。
2. 保留 `CODEX_MONITOR_CMD` 自定义覆盖能力，便于临时调试。
3. 增加可观测输出，快速确认当前实际执行命令。

### 范围

- `codex_task_monitor.sh` 的默认命令与日志输出。
- `PLANS.md` 索引更新。

### 非目标

- 不改动 watchdog 流程（FIFO、无输出超时、重启逻辑）。
- 不改动业务代码与 Flutter 相关模块。

### 成功标准

1. 默认运行不再依赖 `workspace-write`。
2. 日志可直接看到当前执行命令。
3. 在短时验证中可以看到 `sandbox: danger-full-access`。

## 差异点清单

| 文件 | 现状 | 差异原因 | 影响 |
|---|---|---|---|
| `codex_task_monitor.sh` | 默认命令含 `--full-auto`，且参数组合有冲突 | `--full-auto` 会把模式拉向 `workspace-write` | 在 Landlock 不兼容环境下执行失败 |
| `codex_task_monitor.sh` | 启动日志未打印实际执行命令 | 缺少运行态可观测信息 | 排查“参数被覆盖/回退”成本高 |

## 实施步骤

### Step 1：重写默认命令参数（已完成）

- 动作：将默认命令改为：
  - `codex --dangerously-bypass-approvals-and-sandbox exec --skip-git-repo-check "continue to next task"`
- 预期结果：默认执行固定走 Full access。
- 验证方式：运行脚本后观察 codex 头部日志中的 sandbox 字段。

### Step 2：补充命令可观测输出（已完成）

- 动作：新增 `print_current_command`，在每轮启动前输出完整命令（shell-safe quoted）。
- 预期结果：可快速确认是否使用了覆盖命令或默认命令。
- 验证方式：启动日志出现 `[codex-monitor] command: ...`。

### Step 3：同步 ExecPlan 索引（已完成）

- 动作：在 `PLANS.md` 增加本计划索引并标记为 `done`。
- 预期结果：计划与落地状态可追溯。
- 验证方式：`PLANS.md` 可见新增条目。

## 风险与回滚

### 失败模式

1. Full access 默认模式提升执行权限，需依赖外层权限策略控制。
2. 用户通过 `CODEX_MONITOR_CMD` 传入旧命令仍可能回退到 `workspace-write`。

### 阻塞条件

1. 运行环境强制注入外部沙箱参数并覆盖 CLI 参数。

### 回滚策略

1. 可将默认命令恢复为旧值（仅改一处 `cmd=(...)`）。
2. 或通过 `CODEX_MONITOR_CMD` 临时切换命令，不改脚本逻辑。

## 验收与证据

### 命令验证

- 语法检查：
  - `bash -n codex_task_monitor.sh`
- 自定义命令覆盖验证：
  - `CODEX_MONITOR_CMD='printf "probe\\n"' CODEX_MONITOR_INACTIVITY_TIMEOUT=2 CODEX_MONITOR_INTERVAL_SECONDS=1 timeout 4s bash ./codex_task_monitor.sh`
- 默认命令模式验证：
  - `CODEX_MONITOR_INACTIVITY_TIMEOUT=5 timeout 15s bash ./codex_task_monitor.sh`

### 手工回归路径

1. 在仓库根运行监控脚本。
2. 检查首轮日志是否打印 `[codex-monitor] command: ...`。
3. 检查 codex 会话头部 `sandbox` 字段为 `danger-full-access`。

### 预期输出

- 默认模式不再回退到 `workspace-write`。
- 运行日志包含实际执行命令，便于后续排查。

## Progress

- [x] 2026-02-19：修正默认命令并移除 `--full-auto`。
  - 做了什么：改为显式 `--dangerously-bypass-approvals-and-sandbox`；并加入 `--skip-git-repo-check`。
  - 为什么：规避 Landlock 环境下 `workspace-write` 失败。
  - 如何验证：脚本运行输出显示 `sandbox: danger-full-access`。
  - 兼容影响：默认权限策略变为 Full access；`CODEX_MONITOR_CMD` 覆盖能力保持不变。

- [x] 2026-02-19：新增启动命令回显。
  - 做了什么：新增 `print_current_command` 并在每轮 run 前打印。
  - 为什么：减少参数覆盖/回退问题排查成本。
  - 如何验证：日志输出包含 `[codex-monitor] command: ...`。
  - 兼容影响：仅增加日志，无行为副作用。

- [x] 2026-02-19：更新 ExecPlan 索引。
  - 做了什么：在 `PLANS.md` 增加本计划条目。
  - 为什么：满足计划机制的可追溯要求。
  - 如何验证：`PLANS.md` 中可见该条目。
  - 兼容影响：无运行时影响。

## Surprises & Discoveries

1. 脚本中同时出现 `-s danger-full-access` 与 `--full-auto` 时，实际运行可能仍显示 `workspace-write`。
2. `LandlockRestrict` 在当前内核/环境下会导致沙箱层初始化失败，命令尚未真正执行就中断。

## Decision Log

1. 默认策略采用 Full access，优先保证脚本持续运行稳定性。
2. 不引入“先试 workspace-write 再回退”的复杂分支，保持脚本可维护性。
3. 保留 `CODEX_MONITOR_CMD` 作为唯一高优先级覆盖入口。

## Outcomes & Retrospective

- 结果：监控脚本默认执行路径已稳定指向 Full access，Landlock 触发概率显著降低。
- 后续建议：
  1. 若将来运行环境升级并稳定支持 Landlock，可再评估恢复受限沙箱模式。
  2. 约定 `CODEX_MONITOR_CMD` 的推荐模板，避免用户手动传入 `--full-auto`。
