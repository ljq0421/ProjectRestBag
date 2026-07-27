# 研发失败逐级线索 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将研发失败转化为按目标配方永久累计的三级线索，并在研发页常驻显示真实接近度与研发笔记。

**Architecture:** `GameState` 只持久化每个配方的线索等级和最近目标 ID；`RecipeBook` 负责候选筛选、稳定排序、线索升级和结构化展示数据；`Main.tscn` 的外部工作台场景声明研发笔记节点，`main_view.gd` 只绑定结果和刷新界面。新增一个聚焦 Godot 自检覆盖存档、规则与交互，再用现有布局和组件自检锁定回归。

**Tech Stack:** Godot 4.6.1、GDScript、`.tscn` 场景、项目内 `SceneTree` 头部自检、PowerShell。

## Global Constraints

- 只提示尚未解锁、等级不高于当前店铺等级、所需设备已解锁的可出售成品配方；不提示加工配方。
- 至少命中一种正确材料才建立目标线索；仅设备正确不能绑定目标。
- 候选按“命中材料数、设备正确、多余材料更少、缺少材料更少、配方 ID 升序”稳定排序。
- 一级不显示配方名或具体缺料；二级显示配方名、正确设备和缺料类别；三级显示完整材料及已有、缺少、选错状态。
- 线索按目标配方累计至三级；更换材料但仍指向同一目标时不能重置。
- 线索系统不得额外消耗材料；当前 `RecipeBook._fail_research(..., consume_selected)` 的既有消耗行为保持不变。
- 现有 `discovered_hints` 字符串字典保持兼容；新进度使用独立字段。
- 页面删除“研发成功率”，只显示真实命中数与线索等级。
- 稳定界面结构写入 `.tscn`；`main_view.gd` 不复制配方匹配规则。
- 不修改配方目录数据、制作、加工、补货或随机机制。
- 所有 Godot 头部命令从 `D:\Project\ProjectRest\project-rest` 运行，并显式传入可写的 `--log-file "$env:TEMP\...log"`。
- 当前工作树已有用户改动；实施前后只检查和暂存本计划列出的文件，不覆盖无关修改。
- 未经用户明确授权不执行 `git commit`；每个任务末尾仅提供建议提交命令。

## File Map

- Create: `tests/research_progressive_hints_self_check.gd` — 本功能唯一聚焦自检入口，依次验证存档、规则和页面交互。
- Modify: `scripts/game_state.gd` — 保存、加载、清洗 `research_hint_progress` 与 `latest_research_hint_recipe_id`。
- Modify: `scripts/recipe_book.gd` — 选择最近目标、升级三级线索、构造结构化提示。
- Modify: `scenes/ui/pages/workbench_pages.tscn` — 声明常驻研发笔记面板、标题和正文。
- Modify: `scripts/main_view.gd` — 绑定研发笔记节点，刷新摘要/笔记并保留即时状态反馈。
- Modify: `tests/layout_refinement_self_check.gd` — 将旧“研发成功率”断言替换为真实摘要与新面板布局断言。
- Modify: `tests/component_contract_self_check.gd` — 锁定研发笔记场景节点契约。

---

### Task 1: 持久化并清洗研发线索进度

**Files:**
- Create: `tests/research_progressive_hints_self_check.gd`
- Modify: `scripts/game_state.gd:77-81`
- Modify: `scripts/game_state.gd:131-135`
- Modify: `scripts/game_state.gd:167-171`
- Modify: `scripts/game_state.gd:1098-1121`
- Modify: `scripts/game_state.gd:1229-1252`

**Interfaces:**
- Consumes: `Catalog.RECIPES` through the existing `GameState._recipes()` helper.
- Produces: `var research_hint_progress: Dictionary`, `var latest_research_hint_recipe_id: String`, and `func research_hint_level(recipe_id: String) -> int` for `RecipeBook` and the UI.

- [ ] **Step 1: Write the focused self-check skeleton and failing persistence assertions**

Create `tests/research_progressive_hints_self_check.gd` with this initial content:

```gdscript
extends SceneTree

const GameState := preload("res://scripts/game_state.gd")
const RecipeBook := preload("res://scripts/recipe_book.gd")
const MainScene := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "res://tests/research_progressive_hints_self_check.save.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_state_defaults_and_sanitization()
	_cleanup_test_save()
	_finish()


func _test_state_defaults_and_sanitization() -> void:
	var fresh = GameState.new_game()
	_expect(fresh.research_hint_progress == {}, "new game should start without research hint progress")
	_expect(fresh.latest_research_hint_recipe_id == "", "new game should start without a latest research hint")

	var loaded = GameState.from_dict({
		"research_hint_progress": {
			"sponge_cake": 2,
			"butter_cookie": 99,
			"missing_recipe": 3
		},
		"latest_research_hint_recipe_id": "sponge_cake"
	})
	_expect(loaded.research_hint_level("sponge_cake") == 2, "valid hint level should load")
	_expect(loaded.research_hint_level("butter_cookie") == 3, "hint level should clamp to three")
	_expect(not loaded.research_hint_progress.has("missing_recipe"), "unknown recipe hint should be removed")
	_expect(loaded.latest_research_hint_recipe_id == "sponge_cake", "valid latest hint target should load")

	var invalid_latest = GameState.from_dict({
		"research_hint_progress": {"sponge_cake": 1},
		"latest_research_hint_recipe_id": "missing_recipe"
	})
	_expect(invalid_latest.latest_research_hint_recipe_id == "", "invalid latest hint target should clear")

	var round_trip = GameState.from_dict(loaded.to_dict())
	_expect(round_trip.research_hint_progress == loaded.research_hint_progress, "hint progress should survive round trip")
	_expect(round_trip.latest_research_hint_recipe_id == "sponge_cake", "latest target should survive round trip")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("RESEARCH_PROGRESSIVE_HINTS_SELF_CHECK: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _cleanup_test_save() -> void:
	for path in [TEST_SAVE_PATH, "%s.tmp" % TEST_SAVE_PATH]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
```

- [ ] **Step 2: Run the self-check and verify RED**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\research-progressive-hints-red.log" -s res://tests/research_progressive_hints_self_check.gd
```

Expected: exit code `1` with invalid-property failures for `research_hint_progress` or `latest_research_hint_recipe_id`. If it fails on parsing instead, fix only the test syntax and rerun until the missing feature is the reason for failure.

- [ ] **Step 3: Add state fields, defaults, sanitization, query API and serialization**

In `scripts/game_state.gd`, place these fields beside `discovered_hints`:

```gdscript
var discovered_hints: Dictionary = {}
var research_hint_progress: Dictionary = {}
var latest_research_hint_recipe_id: String = ""
```

Initialize them in `new_game()`:

```gdscript
state.discovered_hints = {}
state.research_hint_progress = {}
state.latest_research_hint_recipe_id = ""
```

Load and validate them after `unlocked_recipes` has been sanitized in `from_dict()`:

```gdscript
state.discovered_hints = state._sanitize_dictionary(data.get("discovered_hints", {}))
state.research_hint_progress = state._sanitize_research_hint_progress(data.get("research_hint_progress", {}))
state.latest_research_hint_recipe_id = String(data.get("latest_research_hint_recipe_id", ""))
if not state.research_hint_progress.has(state.latest_research_hint_recipe_id):
	state.latest_research_hint_recipe_id = ""
```

Add the query and sanitizer near the existing recipe sanitizers:

```gdscript
func research_hint_level(recipe_id: String) -> int:
	return clampi(int(research_hint_progress.get(recipe_id, 0)), 0, 3)


func _sanitize_research_hint_progress(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized
	var recipes: Dictionary = _recipes()
	for recipe_value: Variant in (raw_value as Dictionary).keys():
		var recipe_id := String(recipe_value)
		if not recipes.has(recipe_id):
			continue
		var level := clampi(int((raw_value as Dictionary).get(recipe_value, 0)), 0, 3)
		if level > 0:
			sanitized[recipe_id] = level
	return sanitized
```

Add both fields to `to_dict()` next to `discovered_hints`:

```gdscript
"discovered_hints": discovered_hints.duplicate(true),
"research_hint_progress": research_hint_progress.duplicate(true),
"latest_research_hint_recipe_id": latest_research_hint_recipe_id,
```

- [ ] **Step 4: Run the focused self-check and verify GREEN**

Run the Step 2 command again with log file `$env:TEMP\research-progressive-hints-state-green.log`.

Expected: `RESEARCH_PROGRESSIVE_HINTS_SELF_CHECK: PASS`, exit code `0`.

- [ ] **Step 5: Review the task diff and prepare the optional commit**

Run:

```powershell
git diff -- scripts/game_state.gd tests/research_progressive_hints_self_check.gd
```

Confirm the diff does not overwrite unrelated `game_state.gd` edits. Suggested commit, only after explicit authorization:

```powershell
git add scripts/game_state.gd tests/research_progressive_hints_self_check.gd
git commit -m "feat: persist progressive research hints"
```

---

### Task 2: 在 RecipeBook 中实现稳定目标和三级线索

**Files:**
- Modify: `tests/research_progressive_hints_self_check.gd`
- Modify: `scripts/recipe_book.gd:7-83`
- Modify: `scripts/recipe_book.gd:193-303`
- Modify: `scripts/recipe_book.gd:364-403`

**Interfaces:**
- Consumes: `state.research_hint_progress`, `state.latest_research_hint_recipe_id`, `state.research_hint_level(recipe_id)`, `Catalog.get_recipes()`, `Catalog.get_ingredients()`, and `Catalog.get_devices()`.
- Produces: `static func research_hint_view(state, device_id: String, material_ids: Array) -> Dictionary`; failed `research()` results may include a `hint: Dictionary` with `target_recipe_id`, `level`, `direction`, `recipe_name`, `matched_count`, `required_count`, `correct_device_id`, `missing_categories`, `missing_material_ids`, `extra_material_ids`, and `material_statuses`.

- [ ] **Step 1: Extend the self-check with failing rule assertions**

Call a new test from `_run()` immediately after the state test:

```gdscript
_test_progressive_hint_rules()
```

Add:

```gdscript
func _test_progressive_hint_rules() -> void:
	var state = GameState.new_game()
	state.level = 1
	state.shop_level = 1
	for item_id in ["flour", "egg", "vanilla", "milk"]:
		state.add_ingredient(item_id, 5)

	var first: Dictionary = RecipeBook.research(state, "oven", ["flour", "egg", "vanilla"])
	var first_hint: Dictionary = first.get("hint", {})
	_expect(not bool(first.get("ok", false)), "close combination should fail before exact match")
	_expect(String(first_hint.get("target_recipe_id", "")) == "sponge_cake", "closest target should be sponge cake")
	_expect(int(first_hint.get("level", 0)) == 1, "first close failure should grant level one")
	_expect(String(first_hint.get("recipe_name", "")) == "", "level one should hide recipe name")
	_expect(String(first.get("message", "")).find("海绵杯蛋糕") == -1, "level one status should not leak recipe name")
	_expect(String(first.get("message", "")).find("白糖") == -1, "level one status should not leak exact missing material")

	var second: Dictionary = RecipeBook.research(state, "oven", ["flour", "egg", "milk"])
	var second_hint: Dictionary = second.get("hint", {})
	_expect(String(second_hint.get("target_recipe_id", "")) == "sponge_cake", "changed materials should keep the same closest target")
	_expect(int(second_hint.get("level", 0)) == 2, "second close failure should grant level two")
	_expect(String(second_hint.get("recipe_name", "")) == "海绵杯蛋糕", "level two should reveal recipe name")
	_expect(String(second_hint.get("correct_device_id", "")) == "oven", "level two should reveal the correct device")
	_expect((second_hint.get("missing_categories", []) as Array).has("调味"), "level two should reveal missing material category")
	_expect(String(second.get("message", "")).find("海绵杯蛋糕") != -1, "level two status should reveal recipe name")
	_expect(String(second.get("message", "")).find("白糖") == -1, "level two status should still hide exact missing material")

	var third: Dictionary = RecipeBook.research(state, "oven", ["flour", "egg", "vanilla"])
	var third_hint: Dictionary = third.get("hint", {})
	_expect(int(third_hint.get("level", 0)) == 3, "third close failure should grant level three")
	_expect((third_hint.get("missing_material_ids", []) as Array).has("sugar"), "level three should reveal missing sugar")
	_expect((third_hint.get("extra_material_ids", []) as Array).has("vanilla"), "level three should reveal extra vanilla")
	_expect((third_hint.get("material_statuses", []) as Array).size() >= 4, "level three should expose full material statuses")
	_expect(String(third.get("message", "")).find("白糖") != -1, "level three status should reveal exact missing material")
	_expect(state.research_hint_level("sponge_cake") == 3, "state should persist the highest hint level")
	_expect(state.latest_research_hint_recipe_id == "sponge_cake", "state should remember latest valid target")

	var capped: Dictionary = RecipeBook.research(state, "oven", ["flour", "egg", "milk"])
	_expect(int((capped.get("hint", {}) as Dictionary).get("level", 0)) == 3, "further failures should stay capped at three")

	var unrelated_state = GameState.new_game()
	unrelated_state.level = 1
	unrelated_state.shop_level = 1
	var unrelated_before := unrelated_state.research_hint_progress.duplicate(true)
	var unrelated: Dictionary = RecipeBook.research_hint_view(unrelated_state, "oven", ["coffee", "mint"])
	_expect(unrelated.is_empty(), "unrelated materials should not bind an arbitrary target")
	_expect(unrelated_state.research_hint_progress == unrelated_before, "read-only hint view should not mutate progress")

	var low_level = GameState.new_game()
	low_level.level = 1
	low_level.shop_level = 1
	var hidden: Dictionary = RecipeBook.research_hint_view(low_level, "mixer", ["sponge_cake", "cream", "strawberry"])
	_expect(hidden.is_empty(), "higher-level or locked-device recipe should not leak")

	var unlocked = GameState.new_game()
	unlocked.level = 1
	unlocked.shop_level = 1
	unlocked.add_recipe("sponge_cake")
	var unlocked_hint: Dictionary = RecipeBook.research_hint_view(unlocked, "oven", ["flour", "egg", "vanilla"])
	_expect(String(unlocked_hint.get("target_recipe_id", "")) != "sponge_cake", "unlocked recipe should leave the candidate pool")

	var tie_state = GameState.new_game()
	tie_state.level = 1
	tie_state.shop_level = 1
	var stable_target := ""
	for attempt in range(5):
		var tie_hint: Dictionary = RecipeBook.research_hint_view(tie_state, "oven", ["flour"])
		var target_id := String(tie_hint.get("target_recipe_id", ""))
		if attempt == 0:
			stable_target = target_id
		_expect(target_id == stable_target, "equal-score target selection should remain stable")

	var duplicate_view: Dictionary = RecipeBook.research_hint_view(tie_state, "oven", ["flour", "flour", "egg"])
	_expect(int(duplicate_view.get("matched_count", 0)) <= int(duplicate_view.get("required_count", 0)), "duplicate selections should use multiset counts")
```

- [ ] **Step 2: Run the focused self-check and verify RED**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\research-progressive-hints-rules-red.log" -s res://tests/research_progressive_hints_self_check.gd
```

Expected: exit code `1`, first failing assertion reports missing `hint` payload or missing `research_hint_view`.

- [ ] **Step 3: Add multiset comparison, candidate filtering and stable ranking**

In `scripts/recipe_book.gd`, add helpers with these exact contracts:

```gdscript
static func research_hint_view(state, device_id: String, material_ids: Array) -> Dictionary:
	if state == null:
		return {}
	var catalog := Catalog.new()
	return _research_hint_for_attempt(
		state,
		device_id,
		_normalize_hint_materials(material_ids),
		catalog.get_ingredients(),
		catalog.get_recipes(),
		catalog.get_devices()
	)


static func _normalize_hint_materials(raw_materials: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not raw_materials is Array:
		return normalized
	for material_value: Variant in (raw_materials as Array):
		var material_id := String(material_value)
		if not material_id.is_empty():
			normalized.append(material_id)
	return normalized


static func _material_counts(material_ids: Array[String]) -> Dictionary:
	var counts := {}
	for material_id in material_ids:
		counts[material_id] = int(counts.get(material_id, 0)) + 1
	return counts
```

Implement `_research_hint_for_attempt(...)` so it:

1. skips unlocked recipes, recipes above `_state_level(state)`, and recipes whose device fails `_research_tool_available`;
2. calculates multiset `matched_count`, `missing_material_ids`, and `extra_material_ids`;
3. rejects candidates with `matched_count == 0`;
4. compares candidates using this array in descending order, except the final ID which is ascending:

```gdscript
[
	matched_count,
	1 if String(recipe.get("device", "")) == device_id else 0,
	-extra_material_ids.size(),
	-missing_material_ids.size()
]
```

5. breaks equal score with `recipe_id < best_recipe_id`;
6. returns an unpersisted view for the best candidate.

Do not call `_normalize_materials()` for hint scoring because that existing helper intentionally removes duplicates for the current research contract.

- [ ] **Step 4: Add level-aware payload formatting and progress upgrade**

Add:

```gdscript
static func _material_category(material_id: String, ingredients: Dictionary, recipes: Dictionary) -> String:
	if ingredients.has(material_id):
		return String(ingredients[material_id].get("type", "食材"))
	if recipes.has(material_id):
		return "已制作成品"
	return "食材"


static func _upgrade_research_hint(state, target_recipe_id: String) -> int:
	var previous := int(state.research_hint_progress.get(target_recipe_id, 0))
	var next_level := clampi(previous + 1, 1, 3)
	state.research_hint_progress[target_recipe_id] = next_level
	state.latest_research_hint_recipe_id = target_recipe_id
	return next_level
```

The view dictionary must always include internal matching fields but gate user-facing fields by level:

```gdscript
var view := {
	"target_recipe_id": recipe_id,
	"level": level,
	"direction": String(devices.get(correct_device_id, {}).get("research_meaning", "研发")),
	"recipe_name": String(recipe.get("name", recipe_id)) if level >= 2 else "",
	"matched_count": matched_count,
	"required_count": recipe_material_ids.size(),
	"correct_device_id": correct_device_id if level >= 2 else "",
	"missing_categories": missing_categories if level >= 2 else [],
	"missing_material_ids": missing_material_ids if level >= 3 else [],
	"extra_material_ids": extra_material_ids if level >= 3 else [],
	"material_statuses": material_statuses if level >= 3 else []
}
```

Each `material_statuses` entry uses:

```gdscript
{"item_id": material_id, "status": "已有"}     # selected count satisfies this unit
{"item_id": material_id, "status": "缺少"}     # required but not selected
{"item_id": material_id, "status": "选错"}     # selected beyond target requirements
```

- [ ] **Step 5: Route eligible research failures through progressive hints**

Keep validation failures for null state, fewer than two materials, unknown IDs, insufficient inventory, invalid device, level lock and already-unlocked recipes direct and explicit.

For wrong-device, missing-material and generic no-match branches, replace the plain `_fail_research(...)` call with a helper that:

```gdscript
var hint := _research_hint_for_attempt(state, device_id, selected, ingredients, recipes, devices)
if not hint.is_empty():
	var target_recipe_id := String(hint.get("target_recipe_id", ""))
	var level := _upgrade_research_hint(state, target_recipe_id)
	hint = _research_hint_for_target(state, target_recipe_id, device_id, selected, ingredients, recipes, devices, level)
```

Then call the existing material-consumption and failure-log behavior exactly once. If no eligible hint exists, preserve the original failure message. If a hint exists, replace the user-facing and `discovered_hints` message with a level-gated message; do not concatenate the original wrong-device or missing-one message because it may reveal the answer too early.

Add `static func _research_hint_message(hint: Dictionary, ingredients: Dictionary, recipes: Dictionary, devices: Dictionary) -> String` with these outputs:

```gdscript
match int(hint.get("level", 0)):
	1:
		return "研发失败：方向接近，已记录第 1 级线索。"
	2:
		return "研发失败：可能接近%s，正确设备为%s，缺少类别：%s。研发线索提升至 2 级。" % [
			String(hint.get("recipe_name", "未知配方")),
			String(devices.get(String(hint.get("correct_device_id", "")), {}).get("name", "未知设备")),
			"、".join(hint.get("missing_categories", []))
		]
	_:
		return "完整线索已记录：%s；缺少%s；选错%s。" % [
			String(hint.get("recipe_name", "未知配方")),
			_names_for_ids(hint.get("missing_material_ids", []), ingredients, recipes),
			_names_for_ids(hint.get("extra_material_ids", []), ingredients, recipes)
		]
```

Pass this gated message to `_record_research_failure`, attach the `hint` dictionary to the returned failure result, and use the same gated message in `result["message"]`. At level three, use “完整线索已记录” instead of claiming another upgrade. Do not consume materials inside `_research_hint_for_attempt` or `_upgrade_research_hint`; preserve the existing `consume_selected` flag in the failure path.

When `research_hint_view()` is called for page refresh and `state.latest_research_hint_recipe_id` is valid, build the view for that saved target rather than upgrading it. If there is no saved target, it may return the closest unpersisted candidate for the current selection at level `0`, but must not expose its name.

- [ ] **Step 6: Run the focused self-check and verify GREEN**

Run the Step 2 command again with log file `$env:TEMP\research-progressive-hints-rules-green.log`.

Expected: `RESEARCH_PROGRESSIVE_HINTS_SELF_CHECK: PASS`, exit code `0`.

- [ ] **Step 7: Run existing MVP research assertions as a regression check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\mvp-research-regression.log" -s res://tests/mvp_self_check.gd
```

Expected: no new failures mentioning `research`, `discovered_hints`, recipe unlock, wrong device, missing material or material consumption. If unrelated known failures remain, record their exact messages without attributing them to this task.

- [ ] **Step 8: Review the task diff and prepare the optional commit**

Run `git diff -- scripts/recipe_book.gd tests/research_progressive_hints_self_check.gd` and verify each eligible failure records at most one hint upgrade and consumes materials at most once.

Suggested commit, only after explicit authorization:

```powershell
git add scripts/recipe_book.gd tests/research_progressive_hints_self_check.gd
git commit -m "feat: add progressive research failure hints"
```

---

### Task 3: 在研发页显示真实摘要和常驻研发笔记

**Files:**
- Modify: `tests/research_progressive_hints_self_check.gd`
- Modify: `scenes/ui/pages/workbench_pages.tscn`
- Modify: `scripts/main_view.gd:80-92`
- Modify: `scripts/main_view.gd:2009-2028`
- Modify: `scripts/main_view.gd:2355-2375`
- Modify: `scripts/main_view.gd:2604-2619`
- Modify: `scripts/main_view.gd:2762-2787`
- Modify: `scripts/main_view.gd:2790-2836`
- Modify: `scripts/main_view.gd:4755-4803`
- Modify: `scripts/main_view.gd:4842-4845`

**Interfaces:**
- Consumes: `RecipeBook.research_hint_view(state, selected_research_tool_id, _selected_research_material_ids())` and the `hint` dictionary returned by `RecipeBook.research()`.
- Produces: scene nodes `ListRow/PrimaryList/ResearchHintPanel/ResearchHintContent/ResearchHintTitle` and `ResearchHintBody`; view helpers `func _refresh_research_hint_panel() -> void`, `func _research_summary_text(hint: Dictionary) -> String`, and `func _research_hint_body_text(hint: Dictionary) -> String`.

- [ ] **Step 1: Extend the self-check with failing scene and interaction assertions**

Call a new async test from `_run()` before cleanup:

```gdscript
await _test_research_hint_ui()
```

Add:

```gdscript
func _test_research_hint_ui() -> void:
	var view = MainScene.instantiate()
	view.set("save_path", TEST_SAVE_PATH)
	root.add_child(view)
	await process_frame

	var state = GameState.new_game()
	state.level = 1
	state.shop_level = 1
	state.research_hint_progress = {"sponge_cake": 2}
	state.latest_research_hint_recipe_id = "sponge_cake"
	for item_id in ["flour", "egg", "milk"]:
		state.add_ingredient(item_id, 2)
	view.set("state", state)
	view.set("selected_research_tool_id", "oven")
	view.set("selected_research_material_ids", ["flour", "egg", "milk"])
	view.call("_show_page", "research")
	await process_frame

	var page_description: RichTextLabel = view.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/PageHeaderRow/PageDescription")
	var hint_panel: PanelContainer = view.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/PrimaryList/ResearchHintPanel")
	var hint_title: Label = hint_panel.get_node("ResearchHintContent/ResearchHintTitle")
	var hint_body: RichTextLabel = hint_panel.get_node("ResearchHintContent/ResearchHintBody")
	_expect(page_description.text.find("研发成功率") == -1, "research page should remove fake success rate")
	_expect(page_description.text.find("海绵杯蛋糕") != -1, "level two summary should reveal recipe name")
	_expect(page_description.text.find("接近度 2/3") != -1, "summary should show real material match count")
	_expect(hint_panel.visible, "research page should show the persistent hint panel")
	_expect(hint_title.text.find("线索等级 2") != -1, "hint title should show saved level")
	_expect(hint_body.text.find("正确设备：烤箱") != -1, "level two notebook should show correct device")
	_expect(hint_body.text.find("调味") != -1, "level two notebook should show missing category")

	state.research_hint_progress["sponge_cake"] = 3
	view.call("_refresh_research_hint_panel")
	_expect(hint_title.text.find("完整线索") != -1, "level three title should mark complete hint")
	_expect(hint_body.text.find("白糖：缺少") != -1, "level three notebook should name missing sugar")
	_expect(hint_body.text.find("牛奶：选错") != -1, "level three notebook should name extra milk")

	var saved_title := hint_title.text
	view.set("selected_research_material_ids", ["coffee", "mint"])
	view.call("_refresh_research_hint_panel")
	_expect(hint_title.text == saved_title, "unrelated selection should not replace latest valid notebook target")
	_expect(hint_body.text.find("白糖") != -1, "latest complete notebook should remain available after unrelated selection")

	view.call("_set_status", "研发线索提升至 3 级。")
	view.set("save_path", "res://tests/missing_hint_save_dir/save.json")
	var save_ok: bool = bool(view.call("_save_game"))
	var status_label: Label = view.get_node("Root/StatusBar/StatusLabel")
	_expect(not save_ok, "invalid save directory should report failure")
	_expect(status_label.text.find("研发线索提升至 3 级") != -1, "save failure should preserve research feedback")
	_expect(status_label.text.find("存档失败") != -1, "save failure should append persistence warning")

	view.queue_free()
	await process_frame
```

- [ ] **Step 2: Run the focused self-check and verify RED**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\research-progressive-hints-ui-red.log" -s res://tests/research_progressive_hints_self_check.gd
```

Expected: exit code `1` because `ResearchHintPanel` and `_refresh_research_hint_panel` do not exist, or because the page still contains “研发成功率”.

- [ ] **Step 3: Declare the research notebook in the workbench scene**

In `scenes/ui/pages/workbench_pages.tscn`, add after `ToolGrid`:

```ini
[node name="ResearchHintPanel" type="PanelContainer" parent="PrimaryList"]
visible = false
custom_minimum_size = Vector2(0, 104)
layout_mode = 2
size_flags_horizontal = 3

[node name="ResearchHintContent" type="VBoxContainer" parent="PrimaryList/ResearchHintPanel"]
layout_mode = 2
theme_override_constants/separation = 4

[node name="ResearchHintTitle" type="Label" parent="PrimaryList/ResearchHintPanel/ResearchHintContent"]
layout_mode = 2
text = "研发笔记｜暂无有效线索"

[node name="ResearchHintBody" type="RichTextLabel" parent="PrimaryList/ResearchHintPanel/ResearchHintContent"]
custom_minimum_size = Vector2(0, 72)
layout_mode = 2
size_flags_horizontal = 3
bbcode_enabled = true
text = "选择至少 2 个食材并进行研发，接近失败会留下永久线索。"
scroll_active = false
fit_content = true
```

Do not create these nodes dynamically in `main_view.gd`.

- [ ] **Step 4: Bind and position the scene nodes only on the research page**

Add `@onready` bindings beside the research grids:

```gdscript
@onready var research_hint_panel: PanelContainer = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/PrimaryList/ResearchHintPanel
@onready var research_hint_title: Label = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/PrimaryList/ResearchHintPanel/ResearchHintContent/ResearchHintTitle
@onready var research_hint_body: RichTextLabel = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/PrimaryList/ResearchHintPanel/ResearchHintContent/ResearchHintBody
```

In `_clear_page_controls()` set `research_hint_panel.visible = false`.

In `_show_research_inventory_tool_panel()` add:

```gdscript
research_hint_panel.visible = true
primary_list_panel.move_child(research_hint_panel, 2)
```

This preserves `ToolGrid`, `InventoryGrid`, `ResearchHintPanel` order above the expanding recipe area.

- [ ] **Step 5: Replace fake probability with level-aware summary and notebook text**

Replace `_research_success_rate_text()` with:

```gdscript
func _research_summary_text(hint: Dictionary) -> String:
	var material_count := _selected_research_material_ids().size()
	if material_count < 2:
		return "至少选择 2 个食材开始研发"
	if hint.is_empty() or int(hint.get("level", 0)) <= 0:
		return "当前线索：暂无｜选择设备和食材进行尝试"
	var level := int(hint.get("level", 0))
	var matched := int(hint.get("matched_count", 0))
	var required := int(hint.get("required_count", 0))
	if level == 1:
		return "当前线索：%s方向｜接近度 %d/%d｜线索等级 1" % [
			String(hint.get("direction", "研发")), matched, required
		]
	if level == 2:
		return "当前线索：%s｜接近度 %d/%d｜线索等级 2" % [
			String(hint.get("recipe_name", "未知配方")), matched, required
		]
	return "完整线索：%s｜可按研发笔记准备材料" % String(hint.get("recipe_name", "未知配方"))
```

Add `_research_hint_body_text(hint)` that returns exactly these level shapes:

```gdscript
if hint.is_empty() or int(hint.get("level", 0)) <= 0:
	return "选择至少 2 个食材并进行研发，接近失败会留下永久线索。"
if int(hint.get("level", 0)) == 1:
	return "方向：%s\n已确认：%d/%d 种材料\n再次接近失败将揭示目标配方。" % [direction, matched, required]
if int(hint.get("level", 0)) == 2:
	return "正确设备：%s\n已确认：%d/%d 种材料\n缺少类别：%s\n再次接近失败将揭示完整材料。" % [device_name, matched, required, "、".join(missing_categories)]
```

For level three, iterate `material_statuses` in returned order and append `"%s：%s" % [_material_name(item_id), status]`. Do not derive missing or extra sets in the view.

Add:

```gdscript
func _refresh_research_hint_panel() -> void:
	var hint := RecipeBook.research_hint_view(state, selected_research_tool_id, _selected_research_material_ids())
	page_description.text = "研发制作｜%s" % _research_summary_text(hint)
	var level := int(hint.get("level", 0))
	if level <= 0:
		research_hint_title.text = "研发笔记｜暂无有效线索"
	else:
		var label := "完整线索" if level >= 3 else "线索等级 %d" % level
		var recipe_name := String(hint.get("recipe_name", ""))
		research_hint_title.text = "研发笔记｜%s%s" % [label, "｜%s" % recipe_name if not recipe_name.is_empty() else ""]
	research_hint_body.text = _research_hint_body_text(hint)
```

Call `_refresh_research_hint_panel()` at the end of `_refresh_research_page()`, after material/tool grids are filled. Replace direct assignments to `page_description.text` in material select, material clear and tool select handlers with `_refresh_research_hint_panel()`.

- [ ] **Step 6: Preserve immediate research feedback and append save failure**

Keep `_research_selected_recipe()` responsible for setting the result message. `_on_primary_action()` already saves and refreshes after it, so do not add a second save call inside `RecipeBook` or `_research_selected_recipe()`.

Change `_save_game()` to return a result and append rather than replace the current feedback:

```gdscript
func _save_game() -> bool:
	if SaveSystem.save_game(state, save_path):
		return true
	var prefix := status_label.text.strip_edges()
	status_label.text = "%s｜存档失败，请检查用户目录权限。" % prefix if not prefix.is_empty() else "存档失败，请检查用户目录权限。"
	return false
```

Existing callers may ignore the returned `bool`; no call site needs a signature change.

- [ ] **Step 7: Run the focused self-check and verify GREEN**

Run the Step 2 command again with log file `$env:TEMP\research-progressive-hints-ui-green.log`.

Expected: `RESEARCH_PROGRESSIVE_HINTS_SELF_CHECK: PASS`, exit code `0`.

- [ ] **Step 8: Inspect rendered node geometry through the existing layout test before changing its assertions**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\layout-with-research-hints.log" -s res://tests/layout_refinement_self_check.gd
```

Expected: the old assertion requiring “研发成功率” fails. Any new clipping or slot-size failure must be corrected in the `.tscn` layout before Task 4; do not weaken the existing exact `120x48` tool and `120x96` material slot assertions.

- [ ] **Step 9: Review the task diff and prepare the optional commit**

Run:

```powershell
git diff -- scenes/ui/pages/workbench_pages.tscn scripts/main_view.gd tests/research_progressive_hints_self_check.gd
```

Suggested commit, only after explicit authorization:

```powershell
git add scenes/ui/pages/workbench_pages.tscn scripts/main_view.gd tests/research_progressive_hints_self_check.gd
git commit -m "feat: show persistent research notebook"
```

---

### Task 4: 锁定场景契约并完成回归验证

**Files:**
- Modify: `tests/layout_refinement_self_check.gd:69-70`
- Modify: `tests/layout_refinement_self_check.gd:107-144`
- Modify: `tests/component_contract_self_check.gd`
- Verify: `tests/research_progressive_hints_self_check.gd`
- Verify: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: final scene node paths and UI text from Task 3.
- Produces: durable regression coverage for research notebook structure, visibility, ordering, exact slot sizes and removal of fake success-rate copy.

- [ ] **Step 1: Update the layout self-check first and verify the new assertions fail if the scene contract is incomplete**

In `tests/layout_refinement_self_check.gd`, bind:

```gdscript
var research_hint_panel: PanelContainer = main.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/PrimaryList/ResearchHintPanel")
var research_hint_title: Label = research_hint_panel.get_node("ResearchHintContent/ResearchHintTitle")
var research_hint_body: RichTextLabel = research_hint_panel.get_node("ResearchHintContent/ResearchHintBody")
```

Replace the old success-rate assertion with:

```gdscript
if page_description.text.find("研发成功率") != -1:
	_fail("research page should not show a fake random success rate")
if page_description.text.find("至少选择 2 个食材") == -1:
	_fail("research page should explain how to start research")
if not research_hint_panel.visible:
	_fail("research page should show the persistent research notebook")
if primary_list_panel.get_child_count() < 4 \
		or primary_list_panel.get_child(0) != research_tool_grid \
		or primary_list_panel.get_child(1) != research_inventory_grid \
		or primary_list_panel.get_child(2) != research_hint_panel:
	_fail("research upper area should order tools, materials, then research notebook")
if research_hint_title.text.find("研发笔记") == -1 or research_hint_body.text.is_empty():
	_fail("research notebook should expose stable title and body content")
```

Run the layout command from Task 3 Step 8. Expected before any remaining scene correction: a focused failure naming the incomplete contract; after correction: `LAYOUT_REFINEMENT_SELF_CHECK_PASS` and exit code `0`.

- [ ] **Step 2: Extend the component contract self-check**

In `tests/component_contract_self_check.gd`, load `res://scenes/ui/pages/workbench_pages.tscn`, instantiate it, and assert these exact relative paths and types:

```gdscript
var hint_panel = instance.get_node_or_null("PrimaryList/ResearchHintPanel")
var hint_title = instance.get_node_or_null("PrimaryList/ResearchHintPanel/ResearchHintContent/ResearchHintTitle")
var hint_body = instance.get_node_or_null("PrimaryList/ResearchHintPanel/ResearchHintContent/ResearchHintBody")
if not hint_panel is PanelContainer:
	_fail("workbench pages should declare ResearchHintPanel")
if not hint_title is Label:
	_fail("research hint panel should declare ResearchHintTitle")
if not hint_body is RichTextLabel:
	_fail("research hint panel should declare ResearchHintBody")
```

Use the test file's existing instantiate/free and `_fail` patterns; do not introduce a second test runner.

- [ ] **Step 3: Run component and focused checks**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\component-contract-research-hints.log" -s res://tests/component_contract_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\research-progressive-hints-final.log" -s res://tests/research_progressive_hints_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\layout-research-hints-final.log" -s res://tests/layout_refinement_self_check.gd
```

Expected: all three exit `0` with their PASS markers and no parse errors.

- [ ] **Step 4: Run project parse/startup verification**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-research-hints-startup.log" --quit
```

Expected: exit code `0`, no GDScript parse errors, invalid node paths or invalid property errors.

- [ ] **Step 5: Run the broad MVP check and classify any unrelated baseline failures**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\mvp-research-hints-final.log" -s res://tests/mvp_self_check.gd
```

Expected: no failures caused by research hints, `GameState` serialization, recipe unlocks, failure material consumption, or node paths. If the suite is not fully green, report every remaining failure verbatim and demonstrate that the three focused checks and startup check are green; do not claim the broad suite passes.

- [ ] **Step 6: Perform final scope and diff review**

Run:

```powershell
git status --short
git diff --check
git diff -- scripts/game_state.gd scripts/recipe_book.gd scenes/ui/pages/workbench_pages.tscn scripts/main_view.gd tests/research_progressive_hints_self_check.gd tests/layout_refinement_self_check.gd tests/component_contract_self_check.gd docs/superpowers/specs/2026-07-11-research-progressive-failure-hints-design.md docs/superpowers/plans/2026-07-11-research-progressive-failure-hints.md
```

Confirm:

- no unrelated dirty file was overwritten or staged;
- no user-facing “研发成功率” remains on the research page;
- level-one UI does not display a recipe name or exact material;
- high-level, locked-device and already-unlocked recipes do not become targets;
- each failed attempt upgrades at most one target and never above level three;
- hint persistence contains only valid recipe IDs and levels `1..3`;
- existing failure material consumption happens at most once and is not expanded;
- the research notebook is declared in `.tscn` and ordered after the material grid;
- all completion claims cite fresh command output from Steps 3-5.

- [ ] **Step 7: Prepare the optional final commit**

Only after explicit authorization:

```powershell
git add scripts/game_state.gd scripts/recipe_book.gd scenes/ui/pages/workbench_pages.tscn scripts/main_view.gd tests/research_progressive_hints_self_check.gd tests/layout_refinement_self_check.gd tests/component_contract_self_check.gd docs/superpowers/specs/2026-07-11-research-progressive-failure-hints-design.md docs/superpowers/plans/2026-07-11-research-progressive-failure-hints.md
git commit -m "feat: add progressive research failure guidance"
```
