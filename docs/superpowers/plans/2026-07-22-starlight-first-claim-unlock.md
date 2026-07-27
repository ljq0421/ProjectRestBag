# Starlight First-Claim Unlock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the starlight entry unlock on the first successful starlight claim, including during the tutorial, and repair current-format saves that already contain claimed starlight.

**Architecture:** Keep `GameState.claim_starlight_reward()` as the only live-event trigger and remove the unrelated task prerequisite from `CoreFeatureUnlockService`. During deserialization, derive missing starlight access from persisted starlight evidence without changing balances or reward records.

**Tech Stack:** Godot 4.6.1, GDScript, headless `SceneTree` self-checks.

## Global Constraints

- Work only in `D:\Project\ProjectRest\project-rest-new`.
- Preserve all unrelated uncommitted UI, scene, icon, and tooling changes already present in the working tree.
- New games remain locked until a successful starlight claim.
- Tutorial completion alone must not grant starlight or unlock the starlight entry.
- A successful claim during the tutorial must unlock the entry immediately, without unlocking tasks.
- Save repair may restore only the starlight core permission; it must not change balances, reward records, or automation unlocks.
- Do not change starlight reward values, automation upgrade prices, or the Lv.3/Lv.4 automation gates.
- Every Godot headless command must pass `--log-file` with a writable `%TEMP%` path.

## File Map

- `scripts/core_feature_unlock_service.gd`: owns prerequisite relationships between workbench core features.
- `scripts/game_state.gd`: owns successful starlight claims and current/legacy save reconstruction.
- `tests/post_tutorial_task_gate_self_check.gd`: verifies task gating and the live first-claim event during onboarding.
- `tests/legacy_core_unlock_reconstruction_self_check.gd`: verifies both legacy reconstruction and current-format permission repair.

---

### Task 1: Decouple Starlight Access From the Task Gate

**Files:**
- Modify: `scripts/core_feature_unlock_service.gd:50-64`
- Test: `tests/post_tutorial_task_gate_self_check.gd:14-51`

**Interfaces:**
- Consumes: `GameState.claim_starlight_reward(reward_key: String, amount: int) -> bool` and `GameState.is_core_feature_unlocked(feature_id: String) -> bool`.
- Produces: `CoreFeatureUnlockService.prerequisites(CoreFeatureUnlockService.STARLIGHT) -> []`, allowing the existing successful claim path to unlock starlight independently.

- [ ] **Step 1: Write the failing tutorial-time claim assertions**

Add the following block at the beginning of `_run()`, before the existing task-definition assertions in `tests/post_tutorial_task_gate_self_check.gd`:

```gdscript
	var during_tutorial = GAME_STATE.new_game()
	_expect(not during_tutorial.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.TASK), "task should stay locked during grandma tutorial")
	_expect(not during_tutorial.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "new game should start with starlight locked")
	_expect(during_tutorial.claim_starlight_reward("self_check:tutorial_first", 1), "first tutorial-time starlight claim should succeed")
	_expect(during_tutorial.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "first tutorial-time claim should open starlight immediately")
	_expect(not during_tutorial.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.TASK), "opening starlight should not open tasks")
	_expect_equal("tutorial-time total starlight", during_tutorial.recipe_starlight_total, 1)
	_expect_equal("tutorial-time available starlight", during_tutorial.recipe_starlight_available, 1)
	_expect(not during_tutorial.claim_starlight_reward("self_check:tutorial_first", 1), "duplicate tutorial-time claim should fail")
	_expect_equal("duplicate claim keeps total starlight", during_tutorial.recipe_starlight_total, 1)
	_expect(not during_tutorial.is_automation_unlocked("output"), "opening starlight should not unlock output automation")
	_expect(not during_tutorial.is_automation_unlocked("kitchen"), "opening starlight should not unlock kitchen automation")
```

- [ ] **Step 2: Run the focused self-check and verify the new assertion fails**

Run from `D:\Project\ProjectRest\project-rest-new`:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-post-tutorial-task-gate.log" -s res://tests/post_tutorial_task_gate_self_check.gd
```

Expected: exit code `1` with `POST_TUTORIAL_TASK_GATE_SELF_CHECK_FAIL: first tutorial-time claim should open starlight immediately`.

- [ ] **Step 3: Remove the task prerequisite from starlight**

Change only the `STARLIGHT` entry in `CoreFeatureUnlockService.PREREQUISITES`:

```gdscript
const PREREQUISITES := {
	PURCHASE: [],
	OUTPUT: [PURCHASE],
	INVENTORY: [PURCHASE],
	RESEARCH: [OUTPUT, INVENTORY],
	CRAFT: [RESEARCH],
	CATALOG: [RESEARCH],
	LIST: [CRAFT, CATALOG],
	RULEBOOK: [LIST],
	ARRANGE: [RULEBOOK],
	BUSINESS: [ARRANGE],
	STOREFRONT_MANAGE: [BUSINESS],
	TASK: [STOREFRONT_MANAGE],
	STARLIGHT: [],
}
```

Do not add an initial starlight entry to `default_unlocks()`; `GameState.claim_starlight_reward()` must remain the live trigger.

- [ ] **Step 4: Run the focused self-check and verify it passes**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-post-tutorial-task-gate.log" -s res://tests/post_tutorial_task_gate_self_check.gd
```

Expected: exit code `0` and `POST_TUTORIAL_TASK_GATE_SELF_CHECK_PASS`.

- [ ] **Step 5: Commit the live unlock behavior**

```powershell
git add -- scripts/core_feature_unlock_service.gd tests/post_tutorial_task_gate_self_check.gd
git commit -m "fix: unlock starlight on first claim"
```

---

### Task 2: Repair Existing Saves With Starlight Evidence

**Files:**
- Modify: `scripts/game_state.gd:317-365`
- Test: `tests/legacy_core_unlock_reconstruction_self_check.gd:14-80`

**Interfaces:**
- Consumes: persisted `recipe_starlight_total: int`, `claimed_starlight_rewards: Array[String]`, and `core_feature_unlocks: Dictionary`.
- Produces: a loaded `GameState` whose `core_feature_unlocks[CoreFeatureUnlockService.STARLIGHT]` is true whenever either persisted starlight evidence field proves a prior claim.

- [ ] **Step 1: Write failing current-format save-repair assertions**

Add this block in `tests/legacy_core_unlock_reconstruction_self_check.gd` immediately before the existing `no_guide_data` block:

```gdscript
	var current_starlight_data: Dictionary = GAME_STATE.new_game().to_dict()
	current_starlight_data["recipe_starlight_total"] = 1
	current_starlight_data["recipe_starlight_available"] = 1
	current_starlight_data["claimed_starlight_rewards"] = ["recipe_unlock:rice_milk_drink"]
	var current_core_unlocks: Dictionary = (current_starlight_data.get("core_feature_unlocks", {}) as Dictionary).duplicate(true)
	current_core_unlocks.erase(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT)
	current_starlight_data["core_feature_unlocks"] = current_core_unlocks
	var repaired_current = GAME_STATE.from_dict(current_starlight_data)
	_expect(repaired_current.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "current save with claimed starlight should restore starlight access")
	_expect(repaired_current.recipe_starlight_total == 1, "starlight repair should preserve total balance")
	_expect(repaired_current.recipe_starlight_available == 1, "starlight repair should preserve available balance")
	_expect(repaired_current.claimed_starlight_rewards == ["recipe_unlock:rice_milk_drink"], "starlight repair should preserve reward records")
	_expect(not repaired_current.is_automation_unlocked("output"), "starlight repair should not unlock output automation")
	_expect(not repaired_current.is_automation_unlocked("kitchen"), "starlight repair should not unlock kitchen automation")

	var current_without_starlight = GAME_STATE.from_dict(GAME_STATE.new_game().to_dict())
	_expect(not current_without_starlight.is_core_feature_unlocked(CORE_FEATURE_UNLOCK_SERVICE.STARLIGHT), "current save without starlight evidence should remain locked")
```

- [ ] **Step 2: Run the reconstruction self-check and verify the repair assertion fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-core-unlock-reconstruction.log" -s res://tests/legacy_core_unlock_reconstruction_self_check.gd
```

Expected: exit code `1` with `LEGACY_CORE_UNLOCK_RECONSTRUCTION_SELF_CHECK_FAIL: current save with claimed starlight should restore starlight access`.

- [ ] **Step 3: Restore starlight permission from persisted evidence**

In `GameState.from_dict()`, after legacy reconstruction and before `repair_core_feature_prerequisites()`, add exactly this repair:

```gdscript
	if not has_core_feature_data:
		state._reconstruct_core_feature_unlocks_from_legacy(data, legacy_tutorial_step_evidence, has_tutorial_guide_data)
	if state.recipe_starlight_total > 0 or not state.claimed_starlight_rewards.is_empty():
		state.core_feature_unlocks[CoreFeatureUnlockService.STARLIGHT] = true
	state.repair_core_feature_prerequisites()
```

Directly setting the persisted permission is intentional here: loading a save must not log a new live unlock event or mutate the balance and reward ledgers.

- [ ] **Step 4: Run both focused self-checks**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-core-unlock-reconstruction.log" -s res://tests/legacy_core_unlock_reconstruction_self_check.gd
```

Expected: exit code `0` and `LEGACY_CORE_UNLOCK_RECONSTRUCTION_SELF_CHECK_PASS`.

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-post-tutorial-task-gate.log" -s res://tests/post_tutorial_task_gate_self_check.gd
```

Expected: exit code `0` and `POST_TUTORIAL_TASK_GATE_SELF_CHECK_PASS`.

- [ ] **Step 5: Verify the scoped diff and commit save repair**

Run:

```powershell
git diff --check -- scripts/game_state.gd tests/legacy_core_unlock_reconstruction_self_check.gd
git diff -- scripts/game_state.gd tests/legacy_core_unlock_reconstruction_self_check.gd
```

Expected: no whitespace errors; the diff contains only the evidence-based repair and its regression coverage.

Commit only the scoped files:

```powershell
git add -- scripts/game_state.gd tests/legacy_core_unlock_reconstruction_self_check.gd
git commit -m "fix: repair starlight access in saves"
```

After the commit, rerun both focused self-checks once more with the same commands. Both must exit `0`, and no unrelated working-tree files may be staged or committed.
