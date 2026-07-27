# “一键收获”30次解锁实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `project-rest` 与 `project-rest-new` 中，把“一键收获”的解锁门槛从 10 次成功单槽手动收获提高到 30 次。

**Architecture:** 保留现有 `manual_harvest -> feature_harvest_all -> harvest_all` 数据流，只调整任务配置、界面门槛常量和聚焦测试。计数入口、批次去重、自动化排除、功能奖励与按钮隐藏逻辑均不重写。

**Tech Stack:** Godot 4.6.1、GDScript、JSON 任务配置、Godot headless 自检。

## Global Constraints

- 两个工程的任务 ID、事件名、目标值和玩家可见文案保持一致。
- 只有成功的单槽手动收获计数；失败、一键收获、自动和离线收获不计数。
- 第 29 次保持锁定，第 30 次自动完成、立即显示按钮并通知解锁。
- 不增加存档迁移；停止正在运行的游戏场景后，只删除两个工程各自的主开发存档。
- 保留脏工作区中与本功能无关的改动，尤其是 `project-rest-new/scripts/main_view.gd` 的教程改动。
- 所有 Godot headless 命令都使用 `--log-file` 指向 `D:\Project\ProjectRest\tmp`。

---

### Task 1: 用聚焦测试固定30次门槛

**Files:**
- Modify: `project-rest/tests/harvest_all_unlock_self_check.gd`
- Modify: `project-rest-new/tests/harvest_all_unlock_self_check.gd`

**Interfaces:**
- Consumes: `TaskService.get_task_definitions()`、`GameState.record_task_event("manual_harvest", payload)`、`main_view.gd` 的 `HARVEST_ALL_TASK_GOAL`。
- Produces: 29/30 锁定、30/30 解锁、完成后封顶 30/30 的回归契约。

- [ ] **Step 1: 把任务定义断言改为30次**

```gdscript
_expect(int(definition.get("goal", 0)) == 30, "harvest-all task should require thirty manual harvests")
```

- [ ] **Step 2: 把纯状态进度用例改为29次未完成、第30次完成**

```gdscript
for index in range(29):
	state.record_task_event("manual_harvest", {"harvest_batch_id": "manual:%d" % index})
_expect(int(state.task_progress.get(FEATURE_TASK_ID, {}).get("count", 0)) == 29, "twenty-nine manual harvests should produce 29/30 progress")
_expect(not state.is_task_completed(FEATURE_TASK_ID), "twenty-nine manual harvests should not complete the task")

state.record_task_event("manual_harvest", {"harvest_batch_id": "manual:29"})
_expect(state.is_task_completed(FEATURE_TASK_ID), "the thirtieth manual harvest should complete the task")
_expect(state.call("is_feature_unlocked", FEATURE_ID), "the thirtieth manual harvest should unlock one-click harvest")
```

- [ ] **Step 3: 把完成后封顶和界面显示夹具改为30**

```gdscript
state.record_task_event("manual_harvest", {"harvest_batch_id": "manual:30"})
_expect(int(state.task_progress.get(FEATURE_TASK_ID, {}).get("count", 0)) == 30, "completed task progress should remain capped at 30/30")

for index in range(1, 30):
	state.record_task_event("manual_harvest", {"harvest_batch_id": "ui:%d" % index})
```

- [ ] **Step 4: 运行两个工程的测试并确认 RED**

从各工程目录运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\harvest-goal-30-red.log" -s res://tests/harvest_all_unlock_self_check.gd
```

Expected: 两个工程均因任务目标或界面门槛仍为 10 而退出码为 1；失败信息必须包含 30 次目标相关断言。

### Task 2: 最小实现30次任务目标

**Files:**
- Modify: `project-rest/game_data.json`
- Modify: `project-rest/scripts/main_view.gd`
- Modify: `project-rest-new/game_data.json`
- Modify: `project-rest-new/scripts/main_view.gd`

**Interfaces:**
- Consumes: 现有任务 `feature_harvest_all`、事件 `manual_harvest`、功能 ID `harvest_all`。
- Produces: JSON 任务目标 30，以及锁定提示和进度 clamp 使用的 `HARVEST_ALL_TASK_GOAL := 30`。

- [ ] **Step 1: 修改两个任务配置**

`project-rest/game_data.json`：

```json
"description": "手动收获30次，解锁一键收获。",
"progress_text": "手动收获30次",
"event": "manual_harvest",
"goal": 30
```

`project-rest-new/game_data.json` 中对应单行任务保持相同字段和值。

- [ ] **Step 2: 修改两个界面门槛常量**

```gdscript
const HARVEST_ALL_TASK_GOAL := 30
```

只修改该常量，不改 `manual_harvest` 广播点、批量收获处理器或任务服务。

- [ ] **Step 3: 运行聚焦测试确认 GREEN**

从两个工程目录分别运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\harvest-goal-30-green.log" -s res://tests/harvest_all_unlock_self_check.gd
```

Expected: `HARVEST_ALL_UNLOCK_SELF_CHECK_PASS`，退出码为 0。

- [ ] **Step 4: 运行解析与相邻功能回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\harvest-goal-30-quit.log" --quit
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\harvest-goal-30-research.log" -s res://tests/research_batch_unlock_self_check.gd
```

Expected: 两条命令均退出码为 0；研究制作批量按钮门槛不受影响。

- [ ] **Step 5: 检查差异卫生**

```powershell
git diff --check -- game_data.json scripts/main_view.gd tests/harvest_all_unlock_self_check.gd
git diff -- game_data.json scripts/main_view.gd tests/harvest_all_unlock_self_check.gd
```

Expected: 无空白错误；`main_view.gd` 中本任务新增差异只有 `HARVEST_ALL_TASK_GOAL` 的 10 到 30，既存无关差异保持原样。

### Task 3: 清理开发存档并最终复核

**Files:**
- Delete if present: `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\project-rest\neighbor_dessert_save.json`
- Delete if present: `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\project-rest-new\project_rest_new_save.json`

**Interfaces:**
- Consumes: 两个工程 `project.godot` 的 `config/name` 与 `save_system.gd` 的主存档文件名。
- Produces: 下次运行时从 0/30 开始的新开发存档。

- [ ] **Step 1: 只读核对运行中的游戏场景与目标路径**

检查 Godot 进程命令行，仅停止带有对应工程路径和 `--scene res://scenes/Main.tscn` 的运行场景；不要停止编辑器或 Godot AI 服务。

- [ ] **Step 2: 删除精确主存档**

使用绝对路径、`-LiteralPath` 和父目录白名单校验删除两个主存档。不存在的 `.broken.json` 或 `.tmp` 同名候选视为已清理；不要递归删除 `app_userdata` 目录。

- [ ] **Step 3: 最终确认**

再次验证两个主存档 `Test-Path` 均为 `False`，聚焦测试仍为通过状态，并记录任何与本功能无关的既存测试失败。

## 提交策略

当前两个工作区含有本功能之外的未提交修改，且 `game_data.json`、`main_view.gd` 与上一项“一键补货”功能发生文件重叠。实施时不自动提交这些代码文件；完成后提供精确差异与验证结果，由用户决定是否把相关功能合并提交。
