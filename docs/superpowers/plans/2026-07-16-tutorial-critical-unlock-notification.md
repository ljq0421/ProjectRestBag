# 新手教学关键解锁提示实施计划

**目标：** 在不增加独立教学任务的前提下，让“采集教学材料”分别记录大米与泉水的真实收获；只有两者都收获后才解锁蒸煮一体的圆锅并显示一次性居中提示。

**依据：** `docs/superpowers/specs/2026-07-16-tutorial-critical-unlock-notification-design.zh.md`

**实施原则：**

- 使用 RED → GREEN → REFACTOR；每个行为先由聚焦 Godot 自检固定。
- `game_data.json.tasks` 继续作为教学文案和子目标配置的唯一真相来源。
- 通知使用现有 `GameState.pending_notifications` 与 `MainView._show_next_notification()`，不新建另一套提示 UI。
- 只在关键即时解锁确实改变状态时通知；普通任务进度保持安静。
- 复合材料按物品 ID 去重，顺序不限；不以当前库存替代真实收获记录。
- 白糖不纳入解锁门槛，缺糖时继续由研发失败提示引导采购。
- 不实现旧存档或旧任务进度迁移，不提交 Git。

## Task 1：固定复合收获门槛的失败用例

**Files**

- Modify: `tests/task_objective_progress_self_check.gd`
- Modify: `tests/task_catalog_config_self_check.gd`
- Modify: `tests/task_mainline_self_check.gd`

**RED**

- 只收获大米时，断言圆锅未解锁、子目标未完成、通知为空、进度为 `1/2`。
- 再次收获大米时，断言进度仍为 `1/2`。
- 随后收获泉水时，断言圆锅解锁、子目标完成、通知只新增一次。
- 用“泉水后大米”的反向顺序重复验证顺序无关。
- 目录断言复合条件为 `item_ids: ["rice", "spring_water"]` 且目标值为 `2`。

**Verify RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-tutorial-unlock-red.log" -s res://tests/task_objective_progress_self_check.gd
```

## Task 2：实现复合收获进度并更新配置

**Files**

- Modify: `game_data.json`
- Modify: `scripts/task_service.gd`
- Modify: `scripts/task_catalog_service.gd`

**GREEN**

- 把 `gather_material` 改为 `goal: 2`，条件改为 `item_ids: ["rice", "spring_water"]`。
- 任务服务为 `item_ids` 条件维护去重的 `matched_item_ids`，以已匹配 ID 数量生成进度。
- 目录校验器要求 `item_ids` 是至少包含一个非空 ID 的数组，且引用的食材存在。
- 在 `gather_material` 子目标中加入：
  - 标题：`新设备已解锁：蒸煮一体的圆锅`
  - 正文：`大米和泉水已经备齐。前往“研发制作”，使用圆锅尝试研发第一款商品。`
- 目录校验器允许可选 `notification` 字典，并要求非空 `title`、`body`。
- 没有 `notification` 的现有子目标不受影响。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-tutorial-unlock-catalog.log" -s res://tests/task_catalog_config_self_check.gd
```

## Task 3：只在首次有效解锁时生成子目标通知

**Files**

- Modify: `scripts/task_service.gd`
- Modify: `tests/task_objective_progress_self_check.gd`

**GREEN**

- 子目标首次完成前记录即时效果涉及的解锁状态。
- 应用现有 `_apply_progression_effects()`。
- 仅当至少一个 `unlock_tools`、`unlock_devices` 或 `unlock_automation` 项由未解锁变为已解锁时，调用现有 `enqueue_notification()`。
- 通知生成仍位于“子目标由未完成变为完成”的分支中，复用现有完成标记保证幂等。

**REFACTOR**

- 将“即时效果是否产生新解锁”封装为小型辅助函数，避免在目标进度循环中硬编码圆锅 ID。
- 不把通知职责下沉到 `GameState.unlock_device()`，避免其他非教学解锁被动弹窗。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-tutorial-unlock-objective.log" -s res://tests/task_objective_progress_self_check.gd
```

## Task 4：验证真实收获入口立即展示提示

**Files**

- Modify: `tests/showcase_task_l0_route_self_check.gd`
- Modify: `tests/showcase_task_overlay_self_check.gd`（仅在需要验证下一步跳转时）

**RED**

- 通过真实 `ProductionSite.harvest_slot()` 或等价 Lv.0 收获路径分别收获大米和泉水。
- 断言第一次收获后主视图不显示圆锅解锁弹窗。
- 断言主视图调用既有通知展示入口后，任务弹窗可见并显示圆锅解锁标题和下一步正文。
- 关闭弹窗后，断言当前教学卡仍只完成采集子目标，“前往”目标为研发制作。

**GREEN**

- 如真实收获入口已经调用 `_show_next_notification()`，不修改主视图，仅补回归测试。
- 只有在真实入口未展示通知时，才在操作成功后的现有刷新边界补调用；不在任务服务中直接操作 UI。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-tutorial-unlock-route.log" -s res://tests/showcase_task_l0_route_self_check.gd
```

## Task 5：完成聚焦回归与静态检查

**Verify**

```powershell
$tests = @(
  'task_catalog_config_self_check.gd',
  'task_objective_progress_self_check.gd',
  'showcase_task_l0_route_self_check.gd',
  'showcase_task_overlay_self_check.gd',
  'task_mainline_self_check.gd',
  'mvp_self_check.gd'
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-$test.log" -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-tutorial-unlock-import.log" --quit
```

```powershell
git diff --check
```

## 最终验收

- 玩家真实收获大米和泉水后，圆锅解锁与提示在第二种材料收获操作中发生。
- 只收获一种材料或重复收获同一种材料不会提前解锁。
- 弹窗明确说明设备全名和下一步操作位置。
- 重复采集、重复应用事件、预先解锁圆锅均不会产生重复或虚假提示。
- 教学任务数量仍为三张，没有恢复单独的“解锁圆锅”任务。
- 普通任务进度和非关键解锁没有新增弹窗。
- 配置校验、目标进度、Lv.0 真实路线、任务面板和 MVP 自检通过。
