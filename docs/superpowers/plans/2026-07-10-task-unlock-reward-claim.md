# Task Unlock And Reward Claim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make task completion immediately apply progression unlocks while keeping coins, reputation, ingredients, and tool items behind an explicit reward-claim action.

**Architecture:** `TaskService` remains the single owner of task reward semantics. It splits the existing `reward` dictionary by key: progression fields are applied in `_complete_task()`, economic fields are applied in `claim_task_reward()`, and the UI consumes separate formatter functions so it never describes an already-active unlock as pending. `GameState` keeps the existing `completed_tasks` and `claimed_tasks` persistence without adding migration logic.

**Tech Stack:** Godot 4.6.1, GDScript, scene-backed task overlay, headless `SceneTree` self-checks.

## Global Constraints

- Apply the split to all task types: completion advances content; claiming grants economic resources.
- Completion fields are exactly `unlock_devices`, `unlock_tools`, and `set_level`.
- Claim fields are exactly `coins`, `reputation`, `ingredients`, and `tools`.
- Do not add `experience` in this change.
- Do not implement old-save migration; existing development saves may be deleted.
- Keep Lv.1-Lv.5 conditions and prerequisite IDs unchanged.
- Add only the approved coin bonuses for mainline tasks that currently lack an economic reward.
- Preserve the existing notification queue and task-button claimable count.
- Run every Godot command from `D:\Project\ProjectRest\project-rest` with `--log-file "$env:TEMP\godot-headless.log"`.
- Do not commit unless the user explicitly requests it.

---

### Task 1: Lock The Split-Settlement Contract In The Focused Self-Check

**Files:**
- Modify: `tests/task_mainline_self_check.gd:30-115`
- Test: `tests/task_mainline_self_check.gd`

**Interfaces:**
- Consumes: `GameState.record_task_event(event_name: String, payload: Dictionary)`, `GameState.claim_task_reward(task_id: String) -> bool`, `TaskService.get_task_definitions() -> Dictionary`.
- Produces: executable expectations for immediate progression effects, delayed economic rewards, next-task availability, and duplicate-claim protection.

- [ ] **Step 1: Add reward-definition assertions for the approved bonuses**

Add assertions beside the existing `set_level` checks:

```gdscript
_expect((definitions["main_l0_harvest_rice"] as Dictionary).get("reward", {}).get("coins") == 20, "rice harvest should expose a 20 coin claim reward")
_expect((definitions["main_l0_first_product"] as Dictionary).get("reward", {}).get("coins") == 30, "first product should expose a 30 coin claim reward")
_expect((definitions["main_l0_list_product"] as Dictionary).get("reward", {}).get("coins") == 50, "first listing should expose a 50 coin claim reward")
_expect((definitions["main_l1_upgrade"] as Dictionary).get("reward", {}).get("coins") == 60, "Lv.2 opening should expose a 60 coin claim reward")
_expect((definitions["main_l2_upgrade"] as Dictionary).get("reward", {}).get("coins") == 80, "Lv.3 opening should expose an 80 coin claim reward")
_expect((definitions["main_l3_upgrade"] as Dictionary).get("reward", {}).get("coins") == 100, "Lv.4 opening should expose a 100 coin claim reward")
_expect((definitions["main_l4_upgrade"] as Dictionary).get("reward", {}).get("coins") == 150, "Lv.5 opening should expose a 150 coin claim reward")
_expect((definitions["main_l5_mvp_complete"] as Dictionary).get("reward", {}).get("coins") == 300, "MVP completion should expose a 300 coin claim reward")
```

- [ ] **Step 2: Replace the first-task claim-gated unlock assertions**

Use the initial coin count to prove that completion unlocks the round pot but does not pay coins:

```gdscript
var initial_coins := int(state.coins)
state.record_task_event("harvest", {"item_id": "rice", "amount": 1, "site_id": "farm"})
_expect(state.is_task_completed("main_l0_harvest_rice"), "harvest should complete the first mainline task")
_expect(state.is_device_unlocked("round_pot"), "completed task should unlock round_pot immediately")
_expect(int(state.coins) == initial_coins, "completed task should leave coin reward pending")
_expect(_active_task_ids(state).has("main_l0_first_product"), "next task should open before reward claim")
_expect(_task_ids(state.get_claimable_tasks()).has("main_l0_harvest_rice"), "completed task should retain a claimable economic reward")
_expect(state.claim_task_reward("main_l0_harvest_rice"), "claiming the first task reward should succeed")
_expect(int(state.coins) == initial_coins + 20, "claiming should grant only the 20 coin reward")
_expect(state.is_device_unlocked("round_pot"), "claiming should not undo the completed-task unlock")
_expect(not state.claim_task_reward("main_l0_harvest_rice"), "duplicate claim should fail")
_expect(int(state.coins) == initial_coins + 20, "duplicate claim should not grant coins twice")
```

- [ ] **Step 3: Assert level rewards apply before coin claims**

After each upgrade task completes, assert the new level before calling `claim_task_reward()`, then assert only the approved coin delta after claiming. For Lv.1 use:

```gdscript
var coins_before_l2_claim := int(state.coins)
_expect(state.is_task_completed("main_l1_upgrade"), "Lv.1 resource gate should complete")
_expect(int(state.level) == 2, "Lv.1 upgrade completion should open Lv.2 immediately")
_expect(state.claim_task_reward("main_l1_upgrade"), "Lv.1 upgrade coin reward should be claimable")
_expect(int(state.coins) == coins_before_l2_claim + 60, "Lv.1 upgrade claim should grant 60 coins")
```

Repeat with exact expected deltas `80`, `100`, and `150` for `main_l2_upgrade`, `main_l3_upgrade`, and `main_l4_upgrade`.

- [ ] **Step 4: Run the focused self-check and confirm it fails for the intended reasons**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/task_mainline_self_check.gd
```

Expected: FAIL because the reward definitions lack the new coin values and progression effects still wait for `claim_task_reward()`.

---

### Task 2: Split Progression Effects From Claimable Rewards In TaskService

**Files:**
- Modify: `scripts/task_service.gd:35-350`
- Test: `tests/task_mainline_self_check.gd`

**Interfaces:**
- Consumes: existing task `reward: Dictionary` values and `GameState` mutation methods.
- Produces: `TaskService.format_progression_effects(reward_value: Variant) -> String`, `TaskService.format_claimable_reward(reward_value: Variant) -> String`, immediate progression application in `_complete_task()`, and economic-only behavior in `claim_task_reward()`.

- [ ] **Step 1: Add the approved economic rewards to task definitions**

Change only the following reward dictionaries:

```gdscript
{"unlock_devices": ["round_pot"], "coins": 20}
{"unlock_devices": ["grinder"], "coins": 30}
{"set_level": 1, "coins": 50}
{"set_level": 2, "coins": 60}
{"set_level": 3, "coins": 80}
{"set_level": 4, "coins": 100}
{"set_level": 5, "coins": 150}
{"coins": 300}
```

Apply them respectively to `main_l0_harvest_rice`, `main_l0_first_product`, `main_l0_list_product`, `main_l1_upgrade`, `main_l2_upgrade`, `main_l3_upgrade`, `main_l4_upgrade`, and `main_l5_mvp_complete`.

- [ ] **Step 2: Add separate reward applicators**

Replace `_apply_reward()` with two focused functions:

```gdscript
static func _apply_progression_effects(state, reward_value: Variant) -> void:
	if not reward_value is Dictionary:
		return
	var reward: Dictionary = reward_value
	for tool_id in _sanitize_string_array(reward.get("unlock_tools", [])):
		state.unlock_tool(tool_id)
	for device_id in _sanitize_string_array(reward.get("unlock_devices", [])):
		state.unlock_device(device_id)
	if reward.has("set_level"):
		var target_level := int(reward.get("set_level", state.level))
		if target_level > int(state.level):
			state.level = target_level


static func _apply_claimable_reward(state, reward_value: Variant) -> void:
	if not reward_value is Dictionary:
		return
	var reward: Dictionary = reward_value
	state.coins = maxi(0, int(state.coins) + int(reward.get("coins", 0)))
	state.reputation = maxi(0, int(state.reputation) + int(reward.get("reputation", 0)))
	var tool_rewards: Variant = reward.get("tools", {})
	if tool_rewards is Dictionary:
		for tool_id: Variant in (tool_rewards as Dictionary).keys():
			state.add_tool(String(tool_id), int((tool_rewards as Dictionary)[tool_id]))
	var ingredient_rewards: Variant = reward.get("ingredients", {})
	if ingredient_rewards is Dictionary:
		for item_id: Variant in (ingredient_rewards as Dictionary).keys():
			state.add_ingredient(String(item_id), int((ingredient_rewards as Dictionary)[item_id]))
```

- [ ] **Step 3: Add public formatters for UI and notification copy**

Add:

```gdscript
static func format_progression_effects(reward_value: Variant) -> String:
	if not reward_value is Dictionary:
		return ""
	var reward: Dictionary = reward_value
	var parts: Array[String] = []
	if reward.has("set_level"):
		parts.append("店铺 Lv.%d" % int(reward.get("set_level", 0)))
	for device_id in _sanitize_string_array(reward.get("unlock_devices", [])):
		parts.append("解锁 %s" % _device_name(device_id))
	for tool_id in _sanitize_string_array(reward.get("unlock_tools", [])):
		parts.append("解锁 %s" % _tool_name(tool_id))
	return "、".join(parts)


static func format_claimable_reward(reward_value: Variant) -> String:
	if not reward_value is Dictionary:
		return ""
	var reward: Dictionary = reward_value
	var parts: Array[String] = []
	if int(reward.get("coins", 0)) > 0:
		parts.append("金币 +%d" % int(reward.get("coins", 0)))
	if int(reward.get("reputation", 0)) > 0:
		parts.append("口碑 +%d" % int(reward.get("reputation", 0)))
	var tool_rewards: Variant = reward.get("tools", {})
	if tool_rewards is Dictionary:
		for tool_id: Variant in (tool_rewards as Dictionary).keys():
			parts.append("%s x%d" % [_tool_name(String(tool_id)), int((tool_rewards as Dictionary)[tool_id])])
	var ingredient_rewards: Variant = reward.get("ingredients", {})
	if ingredient_rewards is Dictionary:
		var ingredients := Catalog.new().get_ingredients()
		for item_id: Variant in (ingredient_rewards as Dictionary).keys():
			var item: Dictionary = ingredients.get(String(item_id), {})
			parts.append("%s x%d" % [String(item.get("name", item_id)), int((ingredient_rewards as Dictionary)[item_id])])
	return "、".join(parts)
```

Use `not format_claimable_reward(reward_value).is_empty()` as the single claimability predicate.

- [ ] **Step 4: Apply progression during completion and only economics during claim**

Rewrite the state-changing core as:

```gdscript
static func _complete_task(state, task: Dictionary) -> void:
	var task_id := String(task.get("id", ""))
	if task_id.is_empty() or not state.complete_task(task_id):
		return
	var reward: Variant = task.get("reward", {})
	var previous_level := int(state.level)
	_apply_progression_effects(state, reward)
	var progression_text := format_progression_effects(reward)
	var claimable_text := format_claimable_reward(reward)
	if claimable_text.is_empty() and not state.claimed_tasks.has(task_id):
		state.claimed_tasks.append(task_id)
	var body := String(task.get("notification_body", ""))
	if not progression_text.is_empty():
		body += "\n已生效：%s" % progression_text
	if not claimable_text.is_empty():
		body += "\n奖励待领取：%s" % claimable_text
	state.enqueue_notification(String(task.get("notification_title", "任务完成")), body.strip_edges())
	if int(state.level) > previous_level:
		_enqueue_level_up_notification(state, int(state.level))


static func claim_task_reward(state, task_id: String) -> bool:
	if state == null or task_id.is_empty() or not state.is_task_completed(task_id) or state.is_task_reward_claimed(task_id):
		return false
	var definitions := get_task_definitions()
	if not definitions.has(task_id):
		return false
	var task: Dictionary = definitions[task_id]
	var reward_text := format_claimable_reward(task.get("reward", {}))
	if reward_text.is_empty():
		return false
	_apply_claimable_reward(state, task.get("reward", {}))
	state.claimed_tasks.append(task_id)
	state.add_log("task_reward_claim:%s" % task_id)
	state.enqueue_notification("领取任务奖励：%s" % String(task.get("title", task_id)), reward_text)
	return true
```

Update `get_completed_tasks()`, `get_claimable_tasks()`, and `format_task_panel()` so a completed task without economic rewards is archived rather than presented as claimable, and use `format_claimable_reward()` for claim lists.

- [ ] **Step 5: Run the focused self-check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/task_mainline_self_check.gd
```

Expected: PASS with `Task mainline self-check passed.`

---

### Task 3: Make The Task UI Distinguish Active Unlocks From Claimable Rewards

**Files:**
- Modify: `scripts/main_view.gd:4390-4466`
- Modify: `scripts/ui/overlays/task_detail_content.gd:10-35`
- Modify: `tests/task_mainline_self_check.gd:119-205`
- Test: `tests/task_mainline_self_check.gd`

**Interfaces:**
- Consumes: `TaskService.format_progression_effects()` and `TaskService.format_claimable_reward()` from Task 2.
- Produces: separate “完成后解锁” and “可领取奖励” detail rows while retaining the existing claim button and task-button count.

- [ ] **Step 1: Add failing UI assertions**

Complete `main_l0_harvest_rice` through `record_task_event()` rather than directly calling `complete_task()`, open the task overlay, select that task, and assert the joined detail text contains all of:

```gdscript
_expect(detail_text.find("解锁已生效") != -1, "completed task detail should label progression effects as active")
_expect(detail_text.find("蒸煮一体的圆锅") != -1, "completed task detail should name the active unlock")
_expect(detail_text.find("可领取奖励") != -1, "completed task detail should separate claimable economics")
_expect(detail_text.find("金币 +20") != -1, "completed task detail should show the pending coin reward")
_expect(detail_text.find("领取奖励") != -1, "completed unclaimed task should keep the claim action")
```

- [ ] **Step 2: Replace the combined reward formatter in MainView**

Keep `_task_reward_text()` as the claimable formatter and add an unlock formatter:

```gdscript
func _task_reward_text(reward_value: Variant) -> String:
	var text := TaskService.format_claimable_reward(reward_value)
	return text if not text.is_empty() else "无"


func _task_unlock_text(reward_value: Variant) -> String:
	var text := TaskService.format_progression_effects(reward_value)
	return text if not text.is_empty() else "无"
```

Keep `_refresh_task_button_badge()` and `_on_task_claim_reward_pressed()` unchanged except for any formatter call required by the new service API.

- [ ] **Step 3: Render separate rows in task_detail_content.gd**

Replace the single reward line with status-aware labels:

```gdscript
var completed := String(task.get("status", "")) == "completed"
var unlock_label := "解锁已生效" if completed else "完成后解锁"
detail_text.text = "%s\n\n%s\n\n进度：%s\n%s：%s\n可领取奖励：%s\n状态：%s\n来源：%s\nID：%s\n弹窗提示：%d 条\n已完成：%s" % [
	String(task.get("title", task.get("id", ""))),
	String(task.get("description", "")),
	String(view.call("_task_progress_text", task)),
	unlock_label,
	String(view.call("_task_unlock_text", task.get("reward", {}))),
	String(view.call("_task_reward_text", task.get("reward", {}))),
	String(view.call("_task_claim_status_text", task)),
	String(task.get("source_stage", "经营")),
	_task_id,
	pending_count,
	String(view.call("_task_completed_id_text", completed_tasks))
]
```

Retain the existing `领取奖励` / `已领取` button behavior.

- [ ] **Step 4: Run the focused UI self-check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/task_mainline_self_check.gd
```

Expected: PASS with claim badge, claim button, separated text, scroll bounds, and shared drag behavior all intact.

---

### Task 4: Update Broad MVP Expectations And Run Regression Gates

**Files:**
- Modify: `tests/mvp_self_check.gd:1180-1370`
- Modify: `tests/mvp_self_check.gd:1425-1450`
- Modify: `tests/mvp_self_check.gd:1765-1790`
- Modify: `tests/mvp_self_check.gd:2270-2320`
- Modify: `tests/mvp_self_check.gd:2970-3000`
- Test: `tests/mvp_self_check.gd`
- Test: `tests/component_contract_self_check.gd`

**Interfaces:**
- Consumes: final `TaskService` and UI behavior from Tasks 2-3.
- Produces: broad route coverage with no stale assertion that claims unlock devices or levels.

- [ ] **Step 1: Rewrite every stale claim-gated progression assertion**

Use this exact rule in each listed block:

```gdscript
# Before claim
if not state.is_device_unlocked("round_pot"):
	_fail("rice harvest completion should unlock round_pot immediately")
var coins_before_claim := int(state.coins)
if not state.claim_task_reward("main_l0_harvest_rice"):
	_fail("rice harvest economic reward should be claimable")
if int(state.coins) != coins_before_claim + 20:
	_fail("rice harvest claim should grant 20 coins")
```

Apply the equivalent expectations for:

- `main_l0_first_product`: grinder is unlocked before claim; claim grants `30` coins.
- `main_l0_list_product`: `level == 1` before claim; claim grants `50` coins.
- `main_l1_upgrade`: `level == 2` before claim; claim grants `60` coins.
- `main_l2_upgrade`: `level == 3` before claim; claim grants `80` coins.
- `main_l3_upgrade`: `level == 4` before claim; claim grants `100` coins.
- `main_l4_upgrade`: `level == 5` before claim; claim grants `150` coins.

Remove assertions that expect level-up notifications to be created by the claim call; assert those notifications immediately after the completion event instead.

- [ ] **Step 2: Verify no stale wording remains in tests or runtime copy**

Run:

```powershell
rg -n "wait.*claim|claiming.*unlock|领取.*解锁|奖励领取后.*解锁|wait to unlock" tests scripts
```

Expected: no assertions or player-facing copy that says device, tool type, or level unlocks wait for reward claim.

- [ ] **Step 3: Run the focused task gate**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/task_mainline_self_check.gd
```

Expected: `Task mainline self-check passed.`

- [ ] **Step 4: Run the full MVP gate**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: `MVP_SELF_CHECK_PASS` and process exit code `0`.

- [ ] **Step 5: Run the component contract gate**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/component_contract_self_check.gd
```

Expected: `COMPONENT_CONTRACT_SELF_CHECK_PASS` and process exit code `0`.

- [ ] **Step 6: Run a parse/startup smoke check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" --quit
```

Expected: process exit code `0`. The known root-certificate warning may appear and is not a failure.

- [ ] **Step 7: Review the final diff without committing**

Run:

```powershell
git diff -- scripts/task_service.gd scripts/main_view.gd scripts/ui/overlays/task_detail_content.gd tests/task_mainline_self_check.gd tests/mvp_self_check.gd docs/superpowers/specs/2026-07-10-task-unlock-and-reward-claim-design.zh.md docs/superpowers/plans/2026-07-10-task-unlock-reward-claim.md
```

Expected: only the approved split-settlement behavior, UI copy, reward values, tests, spec, and plan are present; no unrelated workspace changes are included.
