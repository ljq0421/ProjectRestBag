# 已完成任务领奖前保留实施计划

**目标：** 已完成但尚未领取奖励的任务保留在原分类列表顶部；单项或批量领取后才消失，同时不阻塞下一任务开放。

**依据：** `docs/superpowers/specs/2026-07-16-task-claimable-retention-design.zh.md`

**实施原则：**

- 使用 RED → GREEN → REFACTOR，每个行为先由聚焦 Godot 自检固定。
- 复用 `TaskService.build_task_snapshot()` 已有的 `claimable` 数据，不新增任务页签或存档字段。
- 复用现有任务条目、详情和领取处理入口，不建立第二套领奖逻辑。
- 保持下一任务在任务完成时开放，不把领奖设为前置条件。
- 不提交 Git，不改动工作区内其他功能的未提交内容。

## Task 1：固定快照中的保留、分类与顺序

**Files**

- Modify: `tests/task_visibility_selection_self_check.gd`
- Modify: `scripts/task_service.gd`

**RED**

- 完成第一张教学任务但不领奖，断言“当前目标”同时包含：
  1. 顶部的 `tutorial_l0_first_product`，状态为 `completed/claimable`。
  2. 后续的 `tutorial_l0_open_shop`，状态为 `active`。
- 断言 `current_slot_count` 仍为 `1`，待领取任务不占用当前目标槽位。
- 构造已完成日常任务，断言它保留在“支线任务”顶部，而未完成日常仍在其后。
- 领取单项奖励后重新生成快照，断言该条目消失，后续任务仍存在。

**GREEN**

- 在 `build_task_snapshot()` 中只计算一次 `claimable`。
- 按 `tutorial/growth/contract` 与 `daily/feature` 分流待领取条目。
- 将待领取条目按完成顺序倒序插入原分类列表顶部。
- 保持 `current_slot_count` 为进行中的当前目标数量，并新增 `side_slot_count` 表示进行中的支线数量。
- 防止同一任务 ID 在合并结果中重复。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-retention-snapshot.log" -s res://tests/task_visibility_selection_self_check.gd
```

## Task 2：让待领取详情执行单项领取

**Files**

- Modify: `tests/showcase_task_overlay_self_check.gd`
- Modify: `scripts/ui/overlays/task_detail_content.gd`

**RED**

- 用待领取任务配置详情组件，断言主按钮显示“领取奖励”。
- 触发按钮，断言调用现有 `_on_task_claim_reward_pressed(task_id)` 而不是“前往”。
- 领取后刷新任务页，断言已领取条目消失并自动选中下一任务。

**GREEN**

- 详情组件根据 `status == completed && claim_status == claimable` 配置“领取奖励”动作。
- 动作直接调用主视图已有单项领取入口。
- 候选合同继续调用“选择合同”，进行中任务继续调用“前往”。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-retention-overlay.log" -s res://tests/showcase_task_overlay_self_check.gd
```

## Task 3：修正摘要计数并验证批量领取消失

**Files**

- Modify: `scripts/main_view.gd`
- Modify: `tests/task_bulk_claim_self_check.gd`

**RED**

- 两个教学任务待领取时，断言两者都可在“当前目标”列表中看到。
- 断言摘要仍区分进行中目标、进行中支线和待领取数量。
- 点击一键领取后，断言两个待领取条目都从列表消失，奖励只发放一次。

**GREEN**

- 摘要中的“支线”改用快照 `side_slot_count`，不直接使用包含待领取条目的列表长度。
- 保持现有一键领取与汇总通知流程；领取后刷新快照自然移除条目。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-retention-bulk.log" -s res://tests/task_bulk_claim_self_check.gd
```

## Task 4：最终验证

```powershell
$tests = @(
  'task_visibility_selection_self_check.gd',
  'showcase_task_overlay_self_check.gd',
  'task_bulk_claim_self_check.gd',
  'task_mainline_self_check.gd',
  'task_objective_progress_self_check.gd',
  'mvp_self_check.gd'
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-$test.log" -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-retention-import.log" --quit
```

```powershell
git diff --check
```

## 最终验收

- 已完成未领奖任务保留在原分类并置顶。
- 后续进行中任务同时可见且不被领奖状态阻塞。
- 单项领取和一键领取后，对应任务从列表消失。
- 已领取任务不进入历史列表。
- 顶部摘要计数不把待领取任务误算为进行中任务。
