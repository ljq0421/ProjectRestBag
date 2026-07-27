# 店铺升级与研发路线解耦实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Lv.1 至 Lv.5 的店铺升级只受金币和口碑门槛控制，研发与阶段教学任务不再阻塞升级。

**Architecture:** 保留现有 `TaskService` 的资源门槛与即时等级奖励机制，只移除四个升级任务的 `prerequisites`。教学任务本身及其奖励不改，升级后的旧等级任务仍由现有最低等级判定继续开放。

**Tech Stack:** Godot 4.6.1、GDScript、仓库内 SceneTree headless self-check。

## Global Constraints

- Lv.0 升 Lv.1 的新手引导路径保持不变。
- 升级不扣除金币或口碑，升级任务的可领取金币奖励保持不变。
- 不删除研发任务，不改变研发配方、奖励或完成事件。
- 不提交或覆盖工作区中的其他用户改动。

---

### Task 1: 锁定升级独立性的回归契约

**Files:**
- Modify: `tests/task_mainline_self_check.gd`

**Interfaces:**
- Consumes: `TaskService.get_task_definitions()`、`GameState.record_task_event()`。
- Produces: 四个升级任务无前置条件的契约，以及 Lv.2 未完成研发也可升级的行为证明。

- [x] **Step 1: 写失败测试**

将升级契约改为断言 `main_l1_upgrade`、`main_l2_upgrade`、`main_l3_upgrade`、`main_l4_upgrade` 的 `prerequisites` 为空；在 Lv.2 行为用例中，不发送 `cream_shortcake` 的 `research_success`，直接设置金币 360、口碑 22 并记录 `business_result`，断言升级成功且研发任务尚未完成。

- [x] **Step 2: 验证测试按预期失败**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/task_mainline_self_check.gd
```

Expected: FAIL，指出升级任务仍含旧前置条件，且未完成 `main_l2_composite_recipe` 时无法完成 `main_l2_upgrade`。

### Task 2: 移除资源型升级任务的任务前置

**Files:**
- Modify: `scripts/task_service.gd`
- Test: `tests/task_mainline_self_check.gd`

**Interfaces:**
- Consumes: `_main_task(... prerequisites, reward, ...)`。
- Produces: `main_l1_upgrade`、`main_l2_upgrade`、`main_l3_upgrade`、`main_l4_upgrade` 的空前置数组。

- [x] **Step 1: 最小实现**

仅将四个资源型升级任务的 `prerequisites` 参数改为 `[]`；保留事件、金币/口碑条件、即时 `set_level` 和可领取金币奖励。

- [x] **Step 2: 验证聚焦测试通过**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/task_mainline_self_check.gd
```

Expected: `TASK_MAINLINE_SELF_CHECK_PASS`。

### Task 3: 同步路线说明并做最终核对

**Files:**
- Modify: `doc/2026-07-05-progressive-unlock-route-and-tasks.md`
- Test: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: 当前等级门槛表和主线任务表。
- Produces: 明确的“研发任务不阻塞升级”玩家规则。

- [x] **Step 1: 更新文档**

在等级门槛章节补充：Lv.1 至 Lv.5 仅检查金币和口碑；阶段任务均为教学与奖励，不作为升级前置。保留鲜奶油小蛋糕作为可选复合配方教学目标。

- [x] **Step 2: 运行广域回归并区分既有失败**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: 新增升级独立性断言通过；若存在与本改动无关的既有失败，单独记录，不把它们误报为本功能通过或失败。

- [x] **Step 3: 检查补丁边界**

Run:

```powershell
git diff --check
git diff -- scripts/task_service.gd tests/task_mainline_self_check.gd doc/2026-07-05-progressive-unlock-route-and-tasks.md
```

Expected: 无空白错误，补丁只涉及升级前置、对应测试和路线文案。
