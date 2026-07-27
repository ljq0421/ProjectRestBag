# Challenge Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent, event-driven first-run tutorial for the Stage 1 Boss challenge that teaches real placement, rotation, battle reading, report reading, and failure-driven rearrangement without supplying a winning build.

**Architecture:** A pure `ChallengeTutorialProgress` service owns tutorial state and accepts semantic success events. Reusable scene-first overlay components render spotlight targets without intercepting game input, while `ChallengeMainView` coordinates existing board, battle, settlement, save, and tutorial surfaces. Challenge business services remain authoritative; the tutorial never mutates draft, run, battle, confidence, or settlement data.

**Tech Stack:** Godot 4.6.1, GDScript, `.tscn` scene resources, JSON save data, headless self-check scripts, real `InputEventMouse*` acceptance checks.

## Global Constraints

- Work only in `D:\Project\ProjectRest\project-rest-two`; `project-rest-new` must remain unchanged.
- Implement on `feature/challenge-onboarding`.
- The first automatic tutorial uses real successful events; replay mode may use `下一步`.
- Do not add a tutorial-only Boss, winning build, forced loss, reward, confidence refill, recipe unlock, or draft reset.
- Keep stable overlay and popup structure in `.tscn`; scripts bind state, signals, targets, and refreshes.
- The visual overlay must not intercept placement, drag, right-click rotation, battle, or settlement controls.
- New saves and saves without `onboarding` default to tutorial version `1`.
- Persist tutorial data inside `user://project_rest_two_save_v1.json`; never read or write `project_rest_new` save paths.
- A first-battle victory completes after report exit; a retryable loss requires one real valid rearrangement; a terminal loss completes after report exit.
- Existing challenge tests and the default-scene smoke test must remain green.
- Pass a writable `--log-file` to every headless Godot invocation.

---

## File Structure

### New files

- `scripts/challenge/challenge_tutorial_progress.gd` — pure tutorial state normalization, transitions, and draft fingerprinting.
- `scripts/challenge/ui/challenge_tutorial_overlay.gd` — spotlight rendering, target tracking, hint positioning, and presentation signals.
- `shaders/challenge/tutorial_spotlight.gdshader` — up to four transparent spotlight holes in the nightberry dim layer.
- `scenes/challenge/challenge_tutorial_overlay.tscn` — stable overlay, arrow, hint card, and buttons.
- `tests/challenge/challenge_tutorial_progress_self_check.gd` — state, migration, branching, fingerprint, dismissal, and replay tests.
- `tests/challenge/challenge_board_tutorial_events_self_check.gd` — successful board event and target-rectangle tests.
- `tests/challenge/challenge_tutorial_overlay_self_check.gd` — scene structure, pass-through input, target fallback, and safe-layout tests.
- `tests/challenge/challenge_tutorial_route_self_check.gd` — preparation, battle, settlement, and rearrangement routing tests.
- `tests/challenge/challenge_tutorial_replay_self_check.gd` — close, resume, completed replay, and context migration tests.
- `tests/challenge/challenge_tutorial_input_self_check.gd` — real mouse press/motion/release/right-click integration path.
- `docs/superpowers/verification/2026-07-27-challenge-onboarding-playtest.md` — final technical and human-observation evidence.

### Modified files

- `scripts/challenge/challenge_save_service.gd` — include default onboarding state without interpreting tutorial transitions.
- `scripts/challenge/ui/challenge_board.gd` — emit semantic success signals and expose tutorial target rectangles.
- `scenes/challenge/challenge_board.tscn` — add stable tutorial target groups for header/risk/board regions.
- `scripts/challenge/ui/challenge_settlement_dialog.gd` — expose report action and tutorial presentation interfaces.
- `scenes/challenge/challenge_settlement_dialog.tscn` — instantiate the report-local overlay and help entry.
- `scripts/challenge/challenge_main_view.gd` — coordinate progress, semantic events, saves, surfaces, dismissal, and replay.
- `scenes/challenge/challenge_main.tscn` — add the top-bar help button and root tutorial overlay instance.
- `tests/challenge/challenge_save_service_self_check.gd` — assert default and round-trip onboarding data.
- `tests/challenge/challenge_main_scene_self_check.gd` — assert tutorial nodes, help entry, and startup state.
- `tests/challenge/challenge_vertical_slice_self_check.gd` — add tutorial resources and full-route aggregate assertions.

---

### Task 1: Tutorial Progress and Save Contract

**Files:**
- Create: `scripts/challenge/challenge_tutorial_progress.gd`
- Create: `tests/challenge/challenge_tutorial_progress_self_check.gd`
- Modify: `scripts/challenge/challenge_save_service.gd:8-20`
- Modify: `tests/challenge/challenge_save_service_self_check.gd:13-63`

**Interfaces:**
- Produces: `ChallengeTutorialProgress.default_state(start_step: String = "boss_brief") -> Dictionary`
- Produces: `ChallengeTutorialProgress.normalize(raw: Variant, context_surface: String = "preparation") -> Dictionary`
- Produces: `ChallengeTutorialProgress.apply_event(state: Dictionary, event_id: String, context: Dictionary = {}) -> Dictionary`
- Produces: `ChallengeTutorialProgress.dismiss(state: Dictionary) -> Dictionary`
- Produces: `ChallengeTutorialProgress.resume(state: Dictionary, context_surface: String) -> Dictionary`
- Produces: `ChallengeTutorialProgress.draft_fingerprint(draft: Dictionary) -> String`
- Consumes: existing `ChallengeSaveService.empty_save()` and JSON round-trip behavior.

- [ ] **Step 1: Write the failing tutorial progress self-check**

Create a `SceneTree` self-check that loads the new service and asserts exact states:

```gdscript
extends SceneTree

const TutorialProgress = preload("res://scripts/challenge/challenge_tutorial_progress.gd")

var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var service = TutorialProgress.new()
	var state := service.normalize(null, "preparation")
	_expect(state["version"] == 1, "tutorial version defaults to 1")
	_expect(state["status"] == "active", "missing state auto activates")
	_expect(state["step_id"] == "boss_brief", "preparation starts at boss brief")

	state = service.apply_event(state, "boss_acknowledged")
	_expect(state["step_id"] == "place_recipe", "boss acknowledgement advances")
	_expect(service.apply_event(state, "drag_started")["step_id"] == "place_recipe", "drag start cannot advance")
	state = service.apply_event(state, "recipe_placed", {"recipe_id": "butter_cookie"})
	_expect(state["step_id"] == "rotate_recipe", "successful placement advances")
	_expect(service.apply_event(state, "instance_rotated", {
		"recipe_id": "butter_cookie",
		"shape_changed": false
	})["step_id"] == "rotate_recipe", "non-rotatable recipe cannot advance")
	state = service.apply_event(state, "instance_rotated", {
		"recipe_id": "milk_pudding",
		"shape_changed": true
	})
	_expect(state["step_id"] == "read_risk", "real rotatable shape change advances")

	var initial_draft := {"placements": [{
		"instance_id": "milk_pudding_1",
		"recipe_id": "milk_pudding",
		"origin": [1, 1],
		"rotation": 90
	}]}
	state = service.apply_event(state, "risk_acknowledged", {"draft_valid": true})
	state = service.apply_event(state, "battle_started", {"draft": initial_draft})
	_expect(state["step_id"] == "observe_battle", "successful battle start advances")
	_expect(not String(state["pre_battle_draft_fingerprint"]).is_empty(), "battle stores draft fingerprint")
	state = service.apply_event(state, "battle_finished")
	_expect(state["step_id"] == "read_report", "real battle finish opens report step")

	var victory := service.apply_event(state, "report_exited", {
		"outcome": "victory",
		"confidence": 2
	})
	_expect(victory["step_id"] == "complete", "victory skips rearrange")

	var retryable_loss := service.apply_event(state, "report_exited", {
		"outcome": "loss_timeout",
		"confidence": 1
	})
	_expect(retryable_loss["step_id"] == "rearrange", "retryable loss requires rearrange")
	_expect(service.apply_event(retryable_loss, "draft_changed", {
		"draft": initial_draft,
		"draft_valid": true
	})["step_id"] == "rearrange", "same fingerprint does not advance")

	var changed_draft := initial_draft.duplicate(true)
	changed_draft["placements"][0]["origin"] = [2, 1]
	retryable_loss = service.apply_event(retryable_loss, "draft_changed", {
		"draft": changed_draft,
		"draft_valid": true
	})
	_expect(retryable_loss["step_id"] == "complete", "real valid rearrangement advances")

	var terminal_loss := service.apply_event(state, "report_exited", {
		"outcome": "loss_reputation",
		"confidence": 0
	})
	_expect(terminal_loss["step_id"] == "complete", "terminal loss cannot deadlock")

	var dismissed := service.dismiss(state)
	_expect(dismissed["status"] == "dismissed", "dismiss stores status")
	var resumed_settlement := service.resume(dismissed, "settlement")
	_expect(resumed_settlement["status"] == "active", "help resumes dismissed tutorial")
	_expect(resumed_settlement["step_id"] == "read_report", "resume coerces to current surface")
	_finish()
```

Include `_expect`, `_fail`, and `_finish` helpers matching the existing challenge self-check pattern, with success marker `CHALLENGE_TUTORIAL_PROGRESS_SELF_CHECK_PASS`.

- [ ] **Step 2: Run the progress self-check and verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-tutorial-progress-red.log" -s res://tests/challenge/challenge_tutorial_progress_self_check.gd
```

Expected: non-zero exit or parse/load failure because `challenge_tutorial_progress.gd` does not exist.

- [ ] **Step 3: Implement the pure progress service**

Create the service with exact constants and public entry points:

```gdscript
class_name ChallengeTutorialProgress
extends RefCounted

const VERSION := 1
const VALID_STATUSES := ["active", "dismissed", "completed"]
const STEPS := [
	"boss_brief",
	"place_recipe",
	"rotate_recipe",
	"read_risk",
	"start_battle",
	"observe_battle",
	"read_report",
	"rearrange",
	"complete"
]
const ROTATABLE_RECIPE_IDS := ["milk_pudding", "blueberry_muffin"]

static func default_state(start_step: String = "boss_brief") -> Dictionary:
	return {
		"version": VERSION,
		"status": "active",
		"step_id": start_step if STEPS.has(start_step) else "boss_brief",
		"completed_step_ids": [],
		"pre_battle_draft_fingerprint": ""
	}

func normalize(raw: Variant, context_surface: String = "preparation") -> Dictionary:
	var fallback_step := _context_step(context_surface)
	if not raw is Dictionary:
		return default_state(fallback_step)
	var value: Dictionary = raw.duplicate(true)
	if int(value.get("version", 0)) > VERSION:
		value["unsupported_newer_version"] = true
		return value
	value["version"] = VERSION
	if not VALID_STATUSES.has(String(value.get("status", ""))):
		value["status"] = "active"
	if not STEPS.has(String(value.get("step_id", ""))):
		value["step_id"] = fallback_step
	var completed: Array[String] = []
	for step_value in value.get("completed_step_ids", []):
		var step_id := String(step_value)
		if STEPS.has(step_id) and not completed.has(step_id):
			completed.append(step_id)
	value["completed_step_ids"] = completed
	value["pre_battle_draft_fingerprint"] = String(value.get("pre_battle_draft_fingerprint", ""))
	return value

func apply_event(state: Dictionary, event_id: String, context: Dictionary = {}) -> Dictionary:
	var next := normalize(state)
	if String(next.get("status", "")) != "active":
		return next
	var step := String(next.get("step_id", "boss_brief"))
	match step:
		"boss_brief":
			if event_id == "boss_acknowledged":
				_complete_and_advance(next, "place_recipe")
		"place_recipe":
			if event_id == "recipe_placed":
				_complete_and_advance(next, "rotate_recipe")
		"rotate_recipe":
			if (
				event_id == "instance_rotated"
				and ROTATABLE_RECIPE_IDS.has(String(context.get("recipe_id", "")))
				and bool(context.get("shape_changed", false))
			):
				_complete_and_advance(next, "read_risk")
		"read_risk":
			if event_id == "risk_acknowledged" and bool(context.get("draft_valid", false)):
				_complete_and_advance(next, "start_battle")
		"start_battle":
			if event_id == "battle_started" and context.get("draft") is Dictionary:
				next["pre_battle_draft_fingerprint"] = draft_fingerprint(context["draft"])
				_complete_and_advance(next, "observe_battle")
		"observe_battle":
			if event_id == "battle_finished":
				_complete_and_advance(next, "read_report")
		"read_report":
			if event_id == "report_exited":
				var outcome := String(context.get("outcome", ""))
				var confidence := int(context.get("confidence", 0))
				_complete_and_advance(
					next,
					"rearrange" if outcome.begins_with("loss_") and confidence > 0 else "complete"
				)
		"rearrange":
			if (
				event_id == "draft_changed"
				and bool(context.get("draft_valid", false))
				and draft_fingerprint(context.get("draft", {}))
					!= String(next.get("pre_battle_draft_fingerprint", ""))
			):
				_complete_and_advance(next, "complete")
		"complete":
			if event_id == "tutorial_completed":
				_mark_completed(next)
	return next

func dismiss(state: Dictionary) -> Dictionary:
	var next := normalize(state)
	if String(next.get("status", "")) != "completed":
		next["status"] = "dismissed"
	return next

func resume(state: Dictionary, context_surface: String) -> Dictionary:
	var next := normalize(state, context_surface)
	if String(next.get("status", "")) != "completed":
		next["status"] = "active"
		if not _step_is_compatible(String(next.get("step_id", "")), context_surface):
			next["step_id"] = _context_step(context_surface)
	return next

static func draft_fingerprint(draft: Dictionary) -> String:
	var normalized: Array[Dictionary] = []
	for placement_value in draft.get("placements", []):
		var placement: Dictionary = placement_value
		normalized.append({
			"instance_id": String(placement.get("instance_id", "")),
			"recipe_id": String(placement.get("recipe_id", "")),
			"origin": placement.get("origin", []).duplicate(),
			"rotation": posmod(int(placement.get("rotation", 0)), 360)
		})
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["instance_id"]) < String(b["instance_id"])
	)
	return JSON.stringify(normalized)
```

Implement private `_context_step`, `_complete_and_advance`, and `_mark_completed` so completed IDs are appended once and completion sets `status = "completed"`.

```gdscript
func _context_step(context_surface: String) -> String:
	match context_surface:
		"battle":
			return "observe_battle"
		"settlement":
			return "read_report"
		"finished":
			return "complete"
	return "boss_brief"

func _complete_and_advance(state: Dictionary, next_step: String) -> void:
	var completed: Array = state.get("completed_step_ids", [])
	var current := String(state.get("step_id", ""))
	if STEPS.has(current) and not completed.has(current):
		completed.append(current)
	state["completed_step_ids"] = completed
	state["step_id"] = next_step

func _mark_completed(state: Dictionary) -> void:
	var completed: Array = state.get("completed_step_ids", [])
	if not completed.has("complete"):
		completed.append("complete")
	state["completed_step_ids"] = completed
	state["status"] = "completed"

func _step_is_compatible(step_id: String, context_surface: String) -> bool:
	match context_surface:
		"battle":
			return step_id == "observe_battle"
		"settlement":
			return step_id == "read_report"
		"finished":
			return step_id == "complete"
	return step_id in [
		"boss_brief",
		"place_recipe",
		"rotate_recipe",
		"read_risk",
		"start_battle",
		"rearrange",
		"complete"
	]
```

Add a test using `{"version": 2, "future_field": {"keep": true}}` and assert normalization preserves `future_field` while adding only the runtime marker `unsupported_newer_version`. The coordinator must never write this normalized runtime marker back over the future-version dictionary.

- [ ] **Step 4: Add onboarding to the default save and save round-trip test**

Update `ChallengeSaveService.empty_save()`:

```gdscript
static func empty_save() -> Dictionary:
	return {
		"schema_version": 1,
		"meta": {
			"research_points": 0,
			"unlocked_recipe_ids": [],
			"revealed_research_node_ids": [],
			"boss_first_clear_ids": [],
			"endless_records": {}
		},
		"onboarding": {
			"version": 1,
			"status": "active",
			"step_id": "boss_brief",
			"completed_step_ids": [],
			"pre_battle_draft_fingerprint": ""
		},
		"active_run": null,
		"active_draft": {"placements": []},
		"active_battle": null
	}
```

Extend `challenge_save_service_self_check.gd` to assert `onboarding` survives the existing primary-save and backup-recovery round trips without changing `active_run`, `active_draft`, or `active_battle`.

- [ ] **Step 5: Run focused tests**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-tutorial-progress-green.log" -s res://tests/challenge/challenge_tutorial_progress_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-save-onboarding-green.log" -s res://tests/challenge/challenge_save_service_self_check.gd
```

Expected markers:

```text
CHALLENGE_TUTORIAL_PROGRESS_SELF_CHECK_PASS
CHALLENGE_SAVE_SERVICE_SELF_CHECK_PASS
```

- [ ] **Step 6: Commit**

```powershell
git add scripts/challenge/challenge_tutorial_progress.gd scripts/challenge/challenge_tutorial_progress.gd.uid scripts/challenge/challenge_save_service.gd tests/challenge/challenge_tutorial_progress_self_check.gd tests/challenge/challenge_tutorial_progress_self_check.gd.uid tests/challenge/challenge_save_service_self_check.gd
git commit -m "feat: add challenge tutorial progress"
```

---

### Task 2: Board Semantic Events and Tutorial Targets

**Files:**
- Modify: `scripts/challenge/ui/challenge_board.gd:4-5,55-116,136-157,205-265`
- Modify: `scenes/challenge/challenge_board.tscn:46-82`
- Create: `tests/challenge/challenge_board_tutorial_events_self_check.gd`

**Interfaces:**
- Consumes: existing `place_recipe`, `move_instance`, `rotate_instance`, `remove_instance`, `_commit_candidate`, and `_analysis`.
- Produces signals: `recipe_placed(instance_id: String, recipe_id: String)`
- Produces signals: `instance_moved(instance_id: String)`
- Produces signals: `instance_rotated(instance_id: String, recipe_id: String, rotation: int, shape_changed: bool)`
- Produces signals: `instance_removed(instance_id: String)`
- Produces: `get_tutorial_target_rects(kind: String, instance_id: String = "") -> Array[Rect2]`
- Produces: `is_current_draft_valid() -> bool`

- [ ] **Step 1: Write the failing board event self-check**

Instantiate `challenge_board.tscn`, bind real recipe definitions and the loadout service, then capture signal payloads:

```gdscript
var events: Array[String] = []
board.recipe_placed.connect(func(instance_id: String, recipe_id: String) -> void:
	events.append("placed:%s:%s" % [instance_id, recipe_id])
)
board.instance_rotated.connect(func(
	instance_id: String,
	recipe_id: String,
	rotation: int,
	shape_changed: bool
) -> void:
	events.append("rotated:%s:%s:%d:%s" % [instance_id, recipe_id, rotation, shape_changed])
)

_expect(board.place_recipe("milk_pudding", [1, 1], 0, "pudding_1"), "pudding placement succeeds")
_expect(events == ["placed:pudding_1:milk_pudding"], "successful placement emits once")
_expect(board.rotate_instance("pudding_1"), "pudding rotation succeeds")
_expect(events[1] == "rotated:pudding_1:milk_pudding:90:true", "shape-changing rotation emits")

var event_count := events.size()
_expect(not board.place_recipe("sponge_cake", [7, 5]), "out-of-bounds placement fails")
_expect(events.size() == event_count, "rejected placement emits no success event")
_expect(board.is_current_draft_valid(), "committed draft remains valid")
_expect(not board.get_tutorial_target_rects("board").is_empty(), "board target resolves")
_expect(not board.get_tutorial_target_rects("risk").is_empty(), "risk target resolves")
_expect(not board.get_tutorial_target_rects("instance", "pudding_1").is_empty(), "instance cells resolve")
```

Expected success marker: `CHALLENGE_BOARD_TUTORIAL_EVENTS_SELF_CHECK_PASS`.

- [ ] **Step 2: Run the board event test and verify it fails**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-board-tutorial-red.log" -s res://tests/challenge/challenge_board_tutorial_events_self_check.gd
```

Expected: parse or invalid-signal failure because the semantic interfaces do not exist.

- [ ] **Step 3: Emit events only after a successful commit**

Add typed signals:

```gdscript
signal recipe_placed(instance_id: String, recipe_id: String)
signal instance_moved(instance_id: String)
signal instance_rotated(
	instance_id: String,
	recipe_id: String,
	rotation: int,
	shape_changed: bool
)
signal instance_removed(instance_id: String)
```

Refactor each public mutator to emit only when `_commit_candidate(candidate)` returns `true`. For rotation, capture the previous and new normalized cell sets:

```gdscript
const ChallengeLoadoutServiceClass = preload("res://scripts/challenge/challenge_loadout_service.gd")

func rotate_instance(instance_id: String) -> bool:
	if _locked:
		return false
	var candidate := get_draft()
	var recipe_id := ""
	var previous_rotation := 0
	var next_rotation := 0
	var found := false
	for placement in candidate.get("placements", []):
		if String(placement.get("instance_id", "")) == instance_id:
			recipe_id = String(placement.get("recipe_id", ""))
			previous_rotation = posmod(int(placement.get("rotation", 0)), 360)
			next_rotation = posmod(previous_rotation + 90, 360)
			placement["rotation"] = next_rotation
			found = true
			break
	if not found or not _commit_candidate(candidate):
		return false
	var shape: Array = (_recipe_defs.get(recipe_id, {}) as Dictionary).get("shape_cells", [])
	var before := ChallengeLoadoutServiceClass.rotated_cells(shape, previous_rotation)
	var after := ChallengeLoadoutServiceClass.rotated_cells(shape, next_rotation)
	instance_rotated.emit(instance_id, recipe_id, next_rotation, before != after)
	return true
```

Use the same success-after-commit structure for placement, move, and removal. `set_draft()` must not emit semantic player-action events.

- [ ] **Step 4: Add target resolution**

Add stable node groups or metadata in `challenge_board.tscn`:

```ini
[node name="Header" type="HBoxContainer" parent="." groups=["tutorial_board_header"]]
[node name="RiskLabel" type="Label" parent="." groups=["tutorial_board_risk"]]
[node name="BoardFrame" type="PanelContainer" parent="." groups=["tutorial_board_grid"]]
```

Add:

```gdscript
func is_current_draft_valid() -> bool:
	return bool(_analysis.get("valid", false))

func get_tutorial_target_rects(kind: String, instance_id: String = "") -> Array[Rect2]:
	match kind:
		"board":
			return [$BoardFrame.get_global_rect()]
		"risk":
			return [$Header.get_global_rect(), $RiskLabel.get_global_rect(), $RelationSummary.get_global_rect()]
		"instance":
			var rects: Array[Rect2] = []
			for cell in $BoardFrame/BoardGrid.get_children():
				if String(cell.get_meta("instance_id", "")) == instance_id:
					rects.append(cell.get_global_rect())
			return rects
	return []
```

Ensure `_refresh_cells()` writes each occupied cell's `instance_id` metadata and clears it for empty cells.

- [ ] **Step 5: Run focused board tests**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-board-tutorial-green.log" -s res://tests/challenge/challenge_board_tutorial_events_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-board-regression.log" -s res://tests/challenge/challenge_board_scene_self_check.gd
```

Expected markers:

```text
CHALLENGE_BOARD_TUTORIAL_EVENTS_SELF_CHECK_PASS
CHALLENGE_BOARD_SCENE_SELF_CHECK_PASS
```

- [ ] **Step 6: Commit**

```powershell
git add scripts/challenge/ui/challenge_board.gd scenes/challenge/challenge_board.tscn tests/challenge/challenge_board_tutorial_events_self_check.gd tests/challenge/challenge_board_tutorial_events_self_check.gd.uid
git commit -m "feat: expose tutorial board events"
```

---

### Task 3: Reusable Spotlight Overlay

**Files:**
- Create: `shaders/challenge/tutorial_spotlight.gdshader`
- Create: `scripts/challenge/ui/challenge_tutorial_overlay.gd`
- Create: `scenes/challenge/challenge_tutorial_overlay.tscn`
- Create: `tests/challenge/challenge_tutorial_overlay_self_check.gd`

**Interfaces:**
- Produces signals: `confirm_requested`, `dismiss_requested`, `next_requested`
- Produces: `show_step(step_number: int, total_steps: int, title: String, body: String, targets: Array[Rect2], confirm_text: String = "", replay_mode: bool = false) -> void`
- Produces: `set_targets(targets: Array[Rect2]) -> void`
- Produces: `hide_step() -> void`
- Produces: `is_showing_step() -> bool`
- Produces: `get_hint_rect_for_test() -> Rect2`
- Consumes: viewport coordinates from main, board, battle, and settlement target resolvers.

- [ ] **Step 1: Write the failing overlay self-check**

Instantiate the overlay at 1920×1080 and assert stable nodes and input behavior:

```gdscript
var packed := load("res://scenes/challenge/challenge_tutorial_overlay.tscn") as PackedScene
var overlay = packed.instantiate()
root.add_child(overlay)
overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
await process_frame

_expect(overlay.get_node("VisualOverlay").mouse_filter == Control.MOUSE_FILTER_IGNORE, "visual layer passes input")
_expect(overlay.get_node("HintHost/HintPanel/DismissButton").mouse_filter == Control.MOUSE_FILTER_STOP, "dismiss button receives input")

overlay.show_step(
	2,
	9,
	"挑一份挑战备货",
	"把任意配方拖进展示柜。",
	[Rect2(40, 180, 420, 240)],
	"",
	false
)
await process_frame
_expect(overlay.is_showing_step(), "overlay becomes visible")
_expect(Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(overlay.get_hint_rect_for_test()), "hint remains in viewport")

overlay.set_targets([])
await process_frame
_expect(overlay.get_node("Arrow").visible == false, "missing target hides arrow")
_expect(overlay.get_node("HintHost/HintPanel").visible, "missing target keeps safe hint")
```

Emit and assert `confirm_requested`, `dismiss_requested`, and replay-only `next_requested`. Expected marker: `CHALLENGE_TUTORIAL_OVERLAY_SELF_CHECK_PASS`.

Instantiate two overlays, set different targets, and assert their `ShaderMaterial` target uniforms differ; this proves the root and settlement overlays do not share mutable shader state.

- [ ] **Step 2: Run the overlay test and verify it fails**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-tutorial-overlay-red.log" -s res://tests/challenge/challenge_tutorial_overlay_self_check.gd
```

Expected: resource load failure because the overlay scene does not exist.

- [ ] **Step 3: Create the spotlight shader**

Implement four normalized rectangular holes:

```glsl
shader_type canvas_item;

uniform int target_count = 0;
uniform vec4 target_0 = vec4(0.0);
uniform vec4 target_1 = vec4(0.0);
uniform vec4 target_2 = vec4(0.0);
uniform vec4 target_3 = vec4(0.0);
uniform vec4 dim_color : source_color = vec4(0.06, 0.035, 0.11, 0.72);

bool inside_rect(vec2 point, vec4 rect) {
	return point.x >= rect.x
		&& point.y >= rect.y
		&& point.x <= rect.x + rect.z
		&& point.y <= rect.y + rect.w;
}

void fragment() {
	bool spotlight = false;
	if (target_count > 0) spotlight = spotlight || inside_rect(UV, target_0);
	if (target_count > 1) spotlight = spotlight || inside_rect(UV, target_1);
	if (target_count > 2) spotlight = spotlight || inside_rect(UV, target_2);
	if (target_count > 3) spotlight = spotlight || inside_rect(UV, target_3);
	COLOR = spotlight ? vec4(0.0) : dim_color;
}
```

- [ ] **Step 4: Build the scene-first overlay**

The scene must contain:

```text
ChallengeTutorialOverlay (Control, mouse_filter IGNORE)
  VisualOverlay (ColorRect, mouse_filter IGNORE, spotlight shader)
  OutlineHost (Control, mouse_filter IGNORE)
    TargetOutline0 (Panel, mouse_filter IGNORE)
    TargetOutline1 (Panel, mouse_filter IGNORE)
    TargetOutline2 (Panel, mouse_filter IGNORE)
    TargetOutline3 (Panel, mouse_filter IGNORE)
  Arrow (Label, mouse_filter IGNORE)
  HintHost (Control, mouse_filter IGNORE)
    HintPanel (PanelContainer, mouse_filter PASS)
      Margin
        Content
          StepLabel
          TitleLabel
          BodyLabel
          ActionRow
            DismissButton
            ConfirmButton
            NextButton
```

Use the confirmed nightberry/custard/raspberry/gold colors and keep text at or above the existing challenge UI body size.
Set the `ShaderMaterial` subresource to `resource_local_to_scene = true`; otherwise the root and settlement instances would overwrite each other's target uniforms.

Implement the script with:

```gdscript
class_name ChallengeTutorialOverlay
extends Control

signal confirm_requested
signal dismiss_requested
signal next_requested

const SAFE_MARGIN := 24.0
const TARGET_PADDING := 8.0
const MAX_TARGETS := 4

var _targets: Array[Rect2] = []

func _ready() -> void:
	$HintHost/HintPanel/Margin/Content/ActionRow/DismissButton.pressed.connect(
		func() -> void: dismiss_requested.emit()
	)
	$HintHost/HintPanel/Margin/Content/ActionRow/ConfirmButton.pressed.connect(
		func() -> void: confirm_requested.emit()
	)
	$HintHost/HintPanel/Margin/Content/ActionRow/NextButton.pressed.connect(
		func() -> void: next_requested.emit()
	)

func show_step(
	step_number: int,
	total_steps: int,
	title: String,
	body: String,
	targets: Array[Rect2],
	confirm_text: String = "",
	replay_mode: bool = false
) -> void:
	visible = true
	$HintHost/HintPanel/Margin/Content/StepLabel.text = "%d / %d" % [step_number, total_steps]
	$HintHost/HintPanel/Margin/Content/TitleLabel.text = title
	$HintHost/HintPanel/Margin/Content/BodyLabel.text = body
	$HintHost/HintPanel/Margin/Content/ActionRow/ConfirmButton.visible = not confirm_text.is_empty()
	$HintHost/HintPanel/Margin/Content/ActionRow/ConfirmButton.text = confirm_text
	$HintHost/HintPanel/Margin/Content/ActionRow/NextButton.visible = replay_mode
	set_targets(targets)

func set_targets(targets: Array[Rect2]) -> void:
	_targets.clear()
	for target in targets.slice(0, MAX_TARGETS):
		_targets.append(target.grow(TARGET_PADDING))
	var viewport_size := get_viewport_rect().size
	var material := $VisualOverlay.material as ShaderMaterial
	material.set_shader_parameter("target_count", _targets.size())
	for index in MAX_TARGETS:
		var normalized := Vector4()
		if index < _targets.size() and viewport_size.x > 0.0 and viewport_size.y > 0.0:
			var rect := _targets[index]
			normalized = Vector4(
				rect.position.x / viewport_size.x,
				rect.position.y / viewport_size.y,
				rect.size.x / viewport_size.x,
				rect.size.y / viewport_size.y
			)
		material.set_shader_parameter("target_%d" % index, normalized)
		var outline: Control = $OutlineHost.get_child(index)
		outline.visible = index < _targets.size()
		if outline.visible:
			outline.position = _targets[index].position
			outline.size = _targets[index].size
	$Arrow.visible = not _targets.is_empty()
	call_deferred("_layout_hint")

func hide_step() -> void:
	visible = false
	_targets.clear()

func is_showing_step() -> bool:
	return visible

func get_hint_rect_for_test() -> Rect2:
	return $HintHost/HintPanel.get_global_rect()

func _layout_hint() -> void:
	var hint: Control = $HintHost/HintPanel
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var target_union := Rect2(viewport_rect.get_center(), Vector2.ZERO)
	if not _targets.is_empty():
		target_union = _targets[0]
		for target in _targets.slice(1):
			target_union = target_union.merge(target)
	var candidates := [
		Vector2(target_union.end.x + 24.0, target_union.position.y),
		Vector2(target_union.position.x - hint.size.x - 24.0, target_union.position.y),
		Vector2(target_union.position.x, target_union.end.y + 24.0),
		Vector2(target_union.position.x, target_union.position.y - hint.size.y - 24.0)
	]
	var safe := viewport_rect.grow(-SAFE_MARGIN)
	var chosen := safe.get_center() - hint.size * 0.5
	for candidate in candidates:
		var candidate_rect := Rect2(candidate, hint.size)
		if safe.encloses(candidate_rect) and not candidate_rect.intersects(target_union):
			chosen = candidate
			break
	hint.position = chosen
	if _targets.is_empty():
		$Arrow.visible = false
		return
	$Arrow.position = (hint.get_global_rect().get_center() + target_union.get_center()) * 0.5
	$Arrow.text = "→" if target_union.get_center().x >= hint.get_global_rect().get_center().x else "←"
```

Convert global pixel rects to normalized shader uniforms, pad and clamp them, draw gold outlines in `OutlineLayer`, then choose the first safe hint candidate in this order: right, left, below, above, centered fallback. Arrow points from the hint edge toward the union center of the targets.

- [ ] **Step 5: Run the overlay self-check**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-tutorial-overlay-green.log" -s res://tests/challenge/challenge_tutorial_overlay_self_check.gd
```

Expected: `CHALLENGE_TUTORIAL_OVERLAY_SELF_CHECK_PASS`.

- [ ] **Step 6: Commit**

```powershell
git add shaders/challenge/tutorial_spotlight.gdshader scripts/challenge/ui/challenge_tutorial_overlay.gd scripts/challenge/ui/challenge_tutorial_overlay.gd.uid scenes/challenge/challenge_tutorial_overlay.tscn tests/challenge/challenge_tutorial_overlay_self_check.gd tests/challenge/challenge_tutorial_overlay_self_check.gd.uid
git commit -m "feat: add challenge tutorial spotlight"
```

---

### Task 4: Preparation Tutorial Integration

**Files:**
- Modify: `scenes/challenge/challenge_main.tscn:93-264`
- Modify: `scripts/challenge/challenge_main_view.gd:4-43,57-117,147-184,227-290,327-343`
- Create: `tests/challenge/challenge_tutorial_route_self_check.gd`
- Modify: `tests/challenge/challenge_main_scene_self_check.gd:13-76`

**Interfaces:**
- Consumes: `ChallengeTutorialProgress`, board semantic signals, board target rectangles, root overlay presentation API.
- Produces: `resolve_tutorial_targets(step_id: String) -> Array[Rect2]`
- Produces: `get_tutorial_state_for_test() -> Dictionary`
- Produces: `acknowledge_tutorial_for_test() -> void`
- Produces: persistent preparation progression through `start_battle`.

- [ ] **Step 1: Write failing preparation route assertions**

In `challenge_tutorial_route_self_check.gd`, instantiate `challenge_main.tscn` with a temporary `save_path`, then:

```gdscript
var main = load(MAIN_PATH).instantiate()
main.save_path = "user://challenge_tutorial_route_self_check.json"
root.add_child(main)
await process_frame

_expect(main.get_tutorial_state_for_test()["step_id"] == "boss_brief", "new save starts tutorial")
_expect(main.get_node("TutorialCanvasLayer/TutorialOverlay").visible, "root overlay is visible")
main.acknowledge_tutorial_for_test()
_expect(main.get_tutorial_state_for_test()["step_id"] == "place_recipe", "boss acknowledgement advances")

var board = main.get_node("Root/Body/PreparationPanel/MainColumns/ChallengeBoard")
_expect(board.place_recipe("butter_cookie", [0, 0], 0, "cookie_1"), "real placement succeeds")
_expect(main.get_tutorial_state_for_test()["step_id"] == "rotate_recipe", "placement signal advances")
_expect(board.rotate_instance("cookie_1"), "square item call remains valid")
_expect(main.get_tutorial_state_for_test()["step_id"] == "rotate_recipe", "non-shape rotation cannot advance")
_expect(board.place_recipe("milk_pudding", [2, 0], 0, "pudding_1"), "pudding placement succeeds")
_expect(board.rotate_instance("pudding_1"), "pudding rotation succeeds")
_expect(main.get_tutorial_state_for_test()["step_id"] == "read_risk", "real shape rotation advances")
```

Continue through risk acknowledgement and successful `start_battle()`, asserting the step becomes `observe_battle` and the saved onboarding fingerprint is non-empty. Expected marker: `CHALLENGE_TUTORIAL_ROUTE_SELF_CHECK_PASS`.

Use these exact fixtures, already verified by the Stage 1 aggregate:

```gdscript
func _passing_draft() -> Dictionary:
	return {"placements": [
		{"instance_id": "pudding_1", "recipe_id": "milk_pudding", "origin": [0, 0], "rotation": 0},
		{"instance_id": "muffin_1", "recipe_id": "blueberry_muffin", "origin": [1, 0], "rotation": 0},
		{"instance_id": "pudding_2", "recipe_id": "milk_pudding", "origin": [0, 3], "rotation": 0},
		{"instance_id": "muffin_2", "recipe_id": "blueberry_muffin", "origin": [1, 3], "rotation": 0},
		{"instance_id": "cookie_1", "recipe_id": "butter_cookie", "origin": [4, 0], "rotation": 0},
		{"instance_id": "cookie_2", "recipe_id": "butter_cookie", "origin": [4, 1], "rotation": 0}
	]}

func _fast_losing_draft() -> Dictionary:
	return {"placements": [
		{"instance_id": "cookie_1", "recipe_id": "butter_cookie", "origin": [0, 0], "rotation": 0}
	]}
```

- [ ] **Step 2: Run the route test and verify it fails**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-tutorial-route-red.log" -s res://tests/challenge/challenge_tutorial_route_self_check.gd
```

Expected: missing tutorial node or method failure.

- [ ] **Step 3: Add stable main-scene tutorial nodes**

Add a top-bar button without shrinking the existing labels below their current minimum sizes:

```ini
[node name="TutorialHelpButton" type="Button" parent="Root/TopBar"]
custom_minimum_size = Vector2(48, 48)
text = "？"
tooltip_text = "新手引导"

[node name="TutorialCanvasLayer" type="CanvasLayer" parent="."]
layer = 100

[node name="TutorialOverlay" parent="TutorialCanvasLayer" instance=ExtResource("tutorial_overlay")]
```

The overlay instance uses full-rect anchors. Add the packed-scene `ext_resource` rather than constructing nodes in the script.

- [ ] **Step 4: Wire progress, board events, and preparation targets**

Add:

```gdscript
const ChallengeTutorialProgress = preload("res://scripts/challenge/challenge_tutorial_progress.gd")

var _tutorial_progress = ChallengeTutorialProgress.new()
var _tutorial_state: Dictionary = {}
var _tutorial_replay_mode := false
var _tutorial_persistence_blocked := false

func _initialize_tutorial() -> void:
	var surface := _current_tutorial_surface()
	var raw_onboarding = _save_data.get("onboarding")
	_tutorial_state = _tutorial_progress.normalize(raw_onboarding, surface)
	_tutorial_persistence_blocked = bool(
		_tutorial_state.get("unsupported_newer_version", false)
	)
	if _tutorial_persistence_blocked:
		_hide_all_tutorial_surfaces()
		push_warning("Challenge onboarding was created by a newer client; leaving it unchanged.")
		return
	_save_data["onboarding"] = _tutorial_state.duplicate(true)
	if not raw_onboarding is Dictionary or raw_onboarding != _tutorial_state:
		_save_now(not battle_state.is_empty())
	_refresh_tutorial()

func _apply_tutorial_event(event_id: String, context: Dictionary = {}) -> void:
	if _tutorial_replay_mode or _tutorial_persistence_blocked:
		return
	var next := _tutorial_progress.apply_event(_tutorial_state, event_id, context)
	if next == _tutorial_state:
		return
	_tutorial_state = next
	_save_data["onboarding"] = next.duplicate(true)
	_save_now($Root/Body/BattlePanel.visible)
	_refresh_tutorial()

func _refresh_tutorial() -> void:
	if _tutorial_persistence_blocked:
		_hide_all_tutorial_surfaces()
		return
	if $SettlementDialog.visible or _current_tutorial_surface() == "finished":
		$TutorialCanvasLayer/TutorialOverlay.hide_step()
		return
	var step_id := String(_tutorial_state.get("step_id", "boss_brief"))
	var copy := _tutorial_copy(step_id)
	$TutorialCanvasLayer/TutorialOverlay.show_step(
		ChallengeTutorialProgress.STEPS.find(step_id) + 1,
		ChallengeTutorialProgress.STEPS.size(),
		String(copy.get("title", "")),
		String(copy.get("body", "")),
		resolve_tutorial_targets(step_id),
		String(copy.get("confirm", "")),
		false
	)

func _hide_all_tutorial_surfaces() -> void:
	$TutorialCanvasLayer/TutorialOverlay.hide_step()

func _current_tutorial_surface() -> String:
	if $SettlementDialog.visible:
		return "settlement"
	if $Root/Body/BattlePanel.visible:
		return "battle"
	return "preparation"

func _on_tutorial_confirm_requested() -> void:
	match String(_tutorial_state.get("step_id", "")):
		"boss_brief":
			_apply_tutorial_event("boss_acknowledged")
		"read_risk":
			var board = $Root/Body/PreparationPanel/MainColumns/ChallengeBoard
			_apply_tutorial_event("risk_acknowledged", {
				"draft_valid": board.is_current_draft_valid()
			})
		"complete":
			_apply_tutorial_event("tutorial_completed")

func get_tutorial_state_for_test() -> Dictionary:
	return _tutorial_state.duplicate(true)

func acknowledge_tutorial_for_test() -> void:
	_on_tutorial_confirm_requested()
```

Call `_initialize_tutorial()` only after the active surface is known:

```gdscript
func start_vertical_slice() -> void:
	_load_configuration()
	_bind_preparation()
	_load_or_create_run()
	_refresh_top_bar()
	if _restore_active_battle():
		_initialize_tutorial()
		_schedule_battle_tutorial_fade()
		return
	_show_preparation()
	var saved_draft = _save_data.get("active_draft")
	if saved_draft is Dictionary:
		$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.set_draft(saved_draft)
	else:
		$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.set_draft({"placements": []})
	_initialize_tutorial()
	_save_now(false)
```

Task 4 may call `_schedule_battle_tutorial_fade()` through an empty local method; Task 5 replaces it with the real three-second behavior:

```gdscript
func _schedule_battle_tutorial_fade() -> void:
	pass
```

Connect board events in `_ready()`:

```gdscript
board.recipe_placed.connect(func(_instance_id: String, recipe_id: String) -> void:
	_apply_tutorial_event("recipe_placed", {"recipe_id": recipe_id})
)
board.instance_rotated.connect(func(
	_instance_id: String,
	recipe_id: String,
	_rotation: int,
	shape_changed: bool
) -> void:
	_apply_tutorial_event("instance_rotated", {
		"recipe_id": recipe_id,
		"shape_changed": shape_changed
	})
)
$TutorialCanvasLayer/TutorialOverlay.confirm_requested.connect(
	_on_tutorial_confirm_requested
)
```

After a valid risk acknowledgement, pass `board.is_current_draft_valid()`. Immediately after `ChallengeBattleView.start_battle()` succeeds, call:

```gdscript
_apply_tutorial_event("battle_started", {"draft": draft})
```

Do not call it on any early-return path.

- [ ] **Step 5: Implement target and copy resolution**

Use a single table method:

```gdscript
func _tutorial_copy(step_id: String) -> Dictionary:
	match step_id:
		"boss_brief":
			return {"title": "先看 Boss 的完整要求", "body": "8、16、24 秒检查阶段需求，30 秒前要清空挑剔值。", "confirm": "开始备货"}
		"place_recipe":
			return {"title": "挑一份挑战备货", "body": "把任意配方拖进展示柜。本模式不消耗经营库存。"}
		"rotate_recipe":
			return {"title": "试试右键旋转", "body": "牛奶布丁和蓝莓松饼可以改变占格方向。"}
		"read_risk":
			return {"title": "先看覆盖，再决定开战", "body": "预算、联动和失败窗口预测会随布局变化。", "confirm": "看懂风险了"}
		"start_battle":
			return {"title": "锁定构筑，开始挑战", "body": "开战后展示柜锁定，战斗会完全自动进行。"}
		"observe_battle":
			return {"title": "同时看住两条压力", "body": "满足力会降低 Boss 挑剔值，需求失败则会损伤口碑防线。"}
		"read_report":
			return {"title": "从战报找出下一步", "body": "先看失败窗口，再看各配方贡献与调整建议。"}
		"rearrange":
			return {"title": "根据战报重排一次", "body": "移动、旋转、增加或移除配方；合法布局发生变化才算完成。"}
		"complete":
			return {"title": "核心循环已经掌握", "body": "以后可以通过顶部的问号重播引导。", "confirm": "完成引导"}
	return {"title": "", "body": ""}
```

`resolve_tutorial_targets()` maps:

- `boss_brief` → `BossPreview.get_global_rect()`
- `place_recipe` → `SupplyStrip.get_global_rect()` plus board `"board"`
- `rotate_recipe` → board instance rectangles for the earliest placed `milk_pudding` or `blueberry_muffin`; otherwise both corresponding supply cards
- `read_risk` → board `"risk"`
- `start_battle` → `StartButton.get_global_rect()`

If no target resolves, pass an empty array so the overlay uses its safe fallback.

- [ ] **Step 6: Run preparation and main-scene tests**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-tutorial-route-green.log" -s res://tests/challenge/challenge_tutorial_route_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-main-tutorial-green.log" -s res://tests/challenge/challenge_main_scene_self_check.gd
```

Expected markers:

```text
CHALLENGE_TUTORIAL_ROUTE_SELF_CHECK_PASS
CHALLENGE_MAIN_SCENE_SELF_CHECK_PASS
```

- [ ] **Step 7: Commit**

```powershell
git add scenes/challenge/challenge_main.tscn scripts/challenge/challenge_main_view.gd tests/challenge/challenge_tutorial_route_self_check.gd tests/challenge/challenge_tutorial_route_self_check.gd.uid tests/challenge/challenge_main_scene_self_check.gd
git commit -m "feat: guide challenge preparation"
```

---

### Task 5: Battle, Report, and Rearrangement Branches

**Files:**
- Modify: `scripts/challenge/challenge_main_view.gd:73-117,199-225,292-325`
- Modify: `scripts/challenge/ui/challenge_settlement_dialog.gd:4-48`
- Modify: `scenes/challenge/challenge_settlement_dialog.tscn:30-120`
- Modify: `tests/challenge/challenge_tutorial_route_self_check.gd`
- Modify: `tests/challenge/challenge_vertical_slice_self_check.gd:44-180`

**Interfaces:**
- Consumes: progress events `battle_finished`, `report_exited`, and `draft_changed`.
- Produces signal: `ChallengeSettlementDialog.report_action_requested(action: String)`
- Produces: `ChallengeSettlementDialog.show_tutorial_report(outcome: String, replay_mode: bool = false) -> void`
- Produces: `ChallengeSettlementDialog.hide_tutorial_report() -> void`
- Produces: `ChallengeSettlementDialog.resolve_tutorial_targets(outcome: String) -> Array[Rect2]`

- [ ] **Step 1: Extend the route test with all three result branches**

Create isolated temporary saves or three fresh main instances:

```gdscript
const ChallengeSaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const ChallengeRunService = preload("res://scripts/challenge/challenge_run_service.gd")

# Victory
var victory_main = await _create_battle_ready_main(
	"user://challenge_tutorial_victory.json",
	2
)
victory_main.set_draft_for_test(_passing_draft())
victory_main.start_battle()
victory_main.advance_battle_for_test(30000)
await process_frame
_expect(victory_main.get_tutorial_state_for_test()["step_id"] == "read_report", "victory opens report step")
victory_main.exit_report_for_test("back")
_expect(victory_main.get_tutorial_state_for_test()["step_id"] == "complete", "victory completes after report")

# Retryable loss
var loss_main = await _create_battle_ready_main(
	"user://challenge_tutorial_retryable_loss.json",
	2
)
loss_main.set_draft_for_test(_fast_losing_draft())
loss_main.start_battle()
loss_main.advance_battle_for_test(30000)
await process_frame
_expect(loss_main.run_state["confidence"] == 1, "first loss leaves one confidence")
loss_main.exit_report_for_test("retry")
_expect(loss_main.get_tutorial_state_for_test()["step_id"] == "rearrange", "retryable loss waits for rearrangement")
var original := loss_main.get_node(BOARD_PATH).get_draft()
_expect(loss_main.get_tutorial_state_for_test()["step_id"] == "rearrange", "return alone does not complete")
_expect(loss_main.get_node(BOARD_PATH).move_instance("cookie_1", [1, 0]), "real move succeeds")
_expect(loss_main.get_tutorial_state_for_test()["step_id"] == "complete", "real move completes rearrangement")

# Terminal loss from an upgraded legacy save with one confidence
var terminal_main = await _create_battle_ready_main(
	"user://challenge_tutorial_terminal_loss.json",
	1
)
terminal_main.set_draft_for_test(_fast_losing_draft())
terminal_main.start_battle()
terminal_main.advance_battle_for_test(30000)
await process_frame
_expect(terminal_main.run_state["confidence"] == 0, "terminal loss consumes final confidence")
terminal_main.exit_report_for_test("back")
_expect(terminal_main.get_tutorial_state_for_test()["step_id"] == "complete", "terminal loss cannot request rearrangement")

func _create_battle_ready_main(path: String, confidence: int) -> Node:
	var data := ChallengeSaveService.empty_save()
	data["active_run"] = ChallengeRunService.new().create_single_encounter(
		"tutorial-route",
		42,
		"picky_food_critic"
	)
	data["active_run"]["confidence"] = confidence
	data["onboarding"] = {
		"version": 1,
		"status": "active",
		"step_id": "start_battle",
		"completed_step_ids": [
			"boss_brief",
			"place_recipe",
			"rotate_recipe",
			"read_risk"
		],
		"pre_battle_draft_fingerprint": ""
	}
	ChallengeSaveService.save_to_path(path, data)
	var instance = load("res://scenes/challenge/challenge_main.tscn").instantiate()
	instance.save_path = path
	root.add_child(instance)
	await process_frame
	return instance
```

Assert merely showing the settlement dialog does not count as `report_exited`.

- [ ] **Step 2: Run the extended route test and verify it fails**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-tutorial-results-red.log" -s res://tests/challenge/challenge_tutorial_route_self_check.gd
```

Expected: missing report tutorial interfaces or wrong post-report step.

- [ ] **Step 3: Add report-local overlay structure**

Instantiate the reusable overlay inside `ChallengeSettlementDialog`:

```ini
[node name="TutorialReportOverlay" parent="." instance=ExtResource("tutorial_overlay")]
visible = false

[node name="TutorialHelpButton" type="Button" parent="Margin/Content/ActionRow"]
custom_minimum_size = Vector2(48, 48)
text = "？"
tooltip_text = "新手引导"
```

Keep the existing result content and action buttons in the scene. Do not dynamically create report tutorial labels in the script.

- [ ] **Step 4: Expose report actions and targets**

Preserve existing `retry_requested` and `back_requested` signals and add:

```gdscript
signal report_action_requested(action: String)
signal tutorial_help_requested

func _ready() -> void:
	$Margin/Content/ActionRow/RetryButton.pressed.connect(func() -> void:
		report_action_requested.emit("retry")
		retry_requested.emit()
	)
	$Margin/Content/ActionRow/BackButton.pressed.connect(func() -> void:
		report_action_requested.emit("back")
		back_requested.emit()
	)
	$Margin/Content/ActionRow/TutorialHelpButton.pressed.connect(func() -> void:
		tutorial_help_requested.emit()
	)

func resolve_tutorial_targets(outcome: String) -> Array[Rect2]:
	if outcome == "victory":
		return [
			$Margin/Content/WindowRows.get_global_rect(),
			$Margin/Content/ContributionRows.get_global_rect()
		]
	return [
		$Margin/Content/PrimaryFailure.get_global_rect(),
		$Margin/Content/SuggestionList.get_global_rect(),
		$Margin/Content/ActionRow/RetryButton.get_global_rect()
	]
```

`show_tutorial_report()` uses title/body copy appropriate to victory or loss and calls the local overlay. `hide_tutorial_report()` hides it.

```gdscript
func show_tutorial_report(outcome: String, replay_mode: bool = false) -> void:
	var victory := outcome == "victory"
	$TutorialReportOverlay.show_step(
		7,
		9,
		"读懂胜利来自哪里" if victory else "先找出本场主要缺口",
		"查看需求窗口和配方贡献。" if victory else "查看失败窗口，再按建议重排展示柜。",
		resolve_tutorial_targets(outcome),
		"",
		replay_mode
	)

func hide_tutorial_report() -> void:
	$TutorialReportOverlay.hide_step()
```

- [ ] **Step 5: Route battle and report events in the main coordinator**

Extend `resolve_tutorial_targets()` with battle and post-report surfaces:

```gdscript
"observe_battle":
	return [
		$Root/Body/BattlePanel/ChallengeBattleView/TopStatus.get_global_rect(),
		$Root/Body/BattlePanel/ChallengeBattleView/BossPanel/DemandTimeline.get_global_rect()
	]
"rearrange":
	return $Root/Body/PreparationPanel/MainColumns/ChallengeBoard.get_tutorial_target_rects("board")
"complete":
	return [$Root/TopBar/TutorialHelpButton.get_global_rect()]
```

Show the automatic battle explanation only once for three seconds while leaving the logical step at `observe_battle`:

```gdscript
var _battle_tutorial_hint_shown := false

func _schedule_battle_tutorial_fade() -> void:
	if (
		_battle_tutorial_hint_shown
		or String(_tutorial_state.get("step_id", "")) != "observe_battle"
	):
		return
	_battle_tutorial_hint_shown = true
	_refresh_tutorial()
	await get_tree().create_timer(3.0).timeout
	if (
		String(_tutorial_state.get("step_id", "")) == "observe_battle"
		and not _tutorial_replay_mode
	):
		$TutorialCanvasLayer/TutorialOverlay.hide_step()
```

Call `_schedule_battle_tutorial_fade()` after a successful new battle start and after restoring an active battle with an `observe_battle` onboarding step.

After `_on_battle_finished()` receives the real final state and after `register_result()` updates confidence, call:

```gdscript
_apply_tutorial_event("battle_finished")
```

When the settlement popup becomes visible:

```gdscript
$TutorialCanvasLayer/TutorialOverlay.hide_step()
if String(_tutorial_state.get("step_id", "")) == "read_report":
	$SettlementDialog.show_tutorial_report(String(battle_state.get("outcome", "")))
```

Handle the semantic action before existing retry/back behavior loses the outcome context:

```gdscript
func _on_report_action_requested(_action: String) -> void:
	_apply_tutorial_event("report_exited", {
		"outcome": String(battle_state.get("outcome", "")),
		"confidence": int(run_state.get("confidence", 0))
	})
	$SettlementDialog.hide_tutorial_report()

func exit_report_for_test(action: String) -> void:
	_on_report_action_requested(action)
	if action == "retry":
		retry_same_encounter()
	else:
		_return_to_preparation()
```

On every successful board mutation while step is `rearrange`, call:

```gdscript
_apply_tutorial_event("draft_changed", {
	"draft": board.get_draft(),
	"draft_valid": board.is_current_draft_valid()
})
```

Do not compare only the most recent event; the progress service compares the canonical full draft fingerprint with the saved battle-start fingerprint.

- [ ] **Step 6: Run route and aggregate tests**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-tutorial-results-green.log" -s res://tests/challenge/challenge_tutorial_route_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-vertical-tutorial-green.log" -s res://tests/challenge/challenge_vertical_slice_self_check.gd
```

Expected markers:

```text
CHALLENGE_TUTORIAL_ROUTE_SELF_CHECK_PASS
CHALLENGE_VERTICAL_SLICE_SELF_CHECK_PASS
```

- [ ] **Step 7: Commit**

```powershell
git add scripts/challenge/challenge_main_view.gd scripts/challenge/ui/challenge_settlement_dialog.gd scenes/challenge/challenge_settlement_dialog.tscn tests/challenge/challenge_tutorial_route_self_check.gd tests/challenge/challenge_vertical_slice_self_check.gd
git commit -m "feat: guide battle report and rearrangement"
```

---

### Task 6: Dismissal, Resume, Replay, and Context Migration

**Files:**
- Modify: `scripts/challenge/challenge_main_view.gd`
- Modify: `scripts/challenge/ui/challenge_settlement_dialog.gd`
- Create: `tests/challenge/challenge_tutorial_replay_self_check.gd`
- Modify: `tests/challenge/challenge_save_service_self_check.gd`

**Interfaces:**
- Consumes: progress `dismiss()` and `resume()`, root and report overlay signals.
- Produces: `dismiss_tutorial() -> void`
- Produces: `open_tutorial_help() -> void`
- Produces: session-only `_tutorial_replay_mode`
- Produces: `advance_tutorial_replay() -> void`
- Produces: context migration for `preparation`, `battle`, `settlement`, and finished states.

- [ ] **Step 1: Write the replay and migration self-check**

Cover exact persistence boundaries:

```gdscript
var main = await _create_main("dismiss")
main.acknowledge_tutorial_for_test()
main.dismiss_tutorial()
_expect(main.get_tutorial_state_for_test()["status"] == "dismissed", "dismiss stores status")
var saved := ChallengeSaveService.load_from_path(main.save_path)
_expect(saved["data"]["onboarding"]["status"] == "dismissed", "dismiss writes immediately")

main.open_tutorial_help()
_expect(main.get_tutorial_state_for_test()["status"] == "active", "help resumes incomplete tutorial")
_expect(main.get_tutorial_state_for_test()["step_id"] == "place_recipe", "resume preserves step")

var completed_path := "user://challenge_tutorial_completed_self_check.json"
var completed_data := ChallengeSaveService.empty_save()
completed_data["onboarding"] = {
	"version": 1,
	"status": "completed",
	"step_id": "complete",
	"completed_step_ids": ChallengeTutorialProgress.STEPS.duplicate(),
	"pre_battle_draft_fingerprint": ""
}
ChallengeSaveService.save_to_path(completed_path, completed_data)
var completed_main = await _create_main_for_path(completed_path)
var completed_before := completed_main.get_tutorial_state_for_test().duplicate(true)
completed_main.open_tutorial_help()
_expect(completed_main.is_tutorial_replay_for_test(), "completed help starts replay mode")
completed_main.advance_tutorial_replay()
_expect(completed_main.get_tutorial_state_for_test() == completed_before, "replay does not rewrite completion")

func _create_main_for_path(path: String) -> Node:
	var instance = load("res://scenes/challenge/challenge_main.tscn").instantiate()
	instance.save_path = path
	root.add_child(instance)
	await process_frame
	return instance
```

Create a save without `onboarding` for each context:

- preparation → `boss_brief`;
- active battle → `observe_battle`;
- settlement with `last_outcome` → `read_report`;
- completed run without visible settlement → remains non-destructive and help-accessible.

Also create a version `2` onboarding dictionary with an unknown nested field, start the main scene, save unrelated challenge progress, and assert the version `2` dictionary remains byte-for-byte equivalent after removing the runtime-only diagnostic marker.

Expected marker: `CHALLENGE_TUTORIAL_REPLAY_SELF_CHECK_PASS`.

- [ ] **Step 2: Run the replay test and verify it fails**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-tutorial-replay-red.log" -s res://tests/challenge/challenge_tutorial_replay_self_check.gd
```

Expected: missing dismissal/replay methods.

- [ ] **Step 3: Wire close and help signals**

Both root and report overlays call the same coordinator:

```gdscript
var _tutorial_replay_step_index := 0

func dismiss_tutorial() -> void:
	if _tutorial_replay_mode:
		_tutorial_replay_mode = false
		_hide_all_tutorial_surfaces()
		return
	_tutorial_state = _tutorial_progress.dismiss(_tutorial_state)
	_save_data["onboarding"] = _tutorial_state.duplicate(true)
	_save_now($Root/Body/BattlePanel.visible)
	_hide_all_tutorial_surfaces()

func open_tutorial_help() -> void:
	if _tutorial_persistence_blocked:
		return
	if String(_tutorial_state.get("status", "")) == "completed":
		_tutorial_replay_mode = true
		_tutorial_replay_step_index = 0
	else:
		_tutorial_state = _tutorial_progress.resume(
			_tutorial_state,
			_current_tutorial_surface()
		)
		_save_data["onboarding"] = _tutorial_state.duplicate(true)
		_save_now($Root/Body/BattlePanel.visible)
	_refresh_tutorial()

func is_tutorial_replay_for_test() -> bool:
	return _tutorial_replay_mode
```

Extend `_ready()` with exact signal wiring:

```gdscript
$TutorialCanvasLayer/TutorialOverlay.dismiss_requested.connect(dismiss_tutorial)
$TutorialCanvasLayer/TutorialOverlay.next_requested.connect(advance_tutorial_replay)
$Root/TopBar/TutorialHelpButton.pressed.connect(open_tutorial_help)
$SettlementDialog.tutorial_help_requested.connect(open_tutorial_help)
$SettlementDialog.get_node("TutorialReportOverlay").dismiss_requested.connect(dismiss_tutorial)
$SettlementDialog.get_node("TutorialReportOverlay").next_requested.connect(advance_tutorial_replay)
```

- [ ] **Step 4: Implement session-only replay navigation**

Replay uses the same copy and target resolvers but not `apply_event()`:

```gdscript
func advance_tutorial_replay() -> void:
	if not _tutorial_replay_mode:
		return
	_tutorial_replay_step_index += 1
	if _tutorial_replay_step_index >= ChallengeTutorialProgress.STEPS.size():
		_tutorial_replay_mode = false
		_hide_all_tutorial_surfaces()
		return
	_refresh_tutorial()

func _active_tutorial_step_id() -> String:
	if _tutorial_replay_mode:
		return ChallengeTutorialProgress.STEPS[_tutorial_replay_step_index]
	return String(_tutorial_state.get("step_id", "boss_brief"))
```

Replace the Task 4 `_refresh_tutorial()` with a replay-aware version:

```gdscript
func _refresh_tutorial() -> void:
	if _tutorial_persistence_blocked:
		_hide_all_tutorial_surfaces()
		return
	var step_id := _active_tutorial_step_id()
	if $SettlementDialog.visible and step_id == "read_report":
		$TutorialCanvasLayer/TutorialOverlay.hide_step()
		$SettlementDialog.show_tutorial_report(
			String(battle_state.get("outcome", "")),
			_tutorial_replay_mode
		)
		return
	$SettlementDialog.hide_tutorial_report()
	if _current_tutorial_surface() == "finished" and not _tutorial_replay_mode:
		$TutorialCanvasLayer/TutorialOverlay.hide_step()
		return
	var copy := _tutorial_copy(step_id)
	$TutorialCanvasLayer/TutorialOverlay.show_step(
		ChallengeTutorialProgress.STEPS.find(step_id) + 1,
		ChallengeTutorialProgress.STEPS.size(),
		String(copy.get("title", "")),
		String(copy.get("body", "")),
		resolve_tutorial_targets(step_id),
		String(copy.get("confirm", "")),
		_tutorial_replay_mode
	)

func _hide_all_tutorial_surfaces() -> void:
	$TutorialCanvasLayer/TutorialOverlay.hide_step()
	$SettlementDialog.hide_tutorial_report()
```

If a replay target is unavailable in the current surface, show the copy in safe fallback position and keep `下一步` enabled. Do not route pages, close settlement, reset a run, or mutate the board.

- [ ] **Step 5: Normalize missing onboarding from current context**

Determine the context only from already loaded state and visible surface:

```gdscript
func _current_tutorial_surface() -> String:
	if $SettlementDialog.visible:
		return "settlement"
	if String(run_state.get("phase", "")) in ["completed", "ended"]:
		return "finished"
	if $Root/Body/BattlePanel.visible:
		return "battle"
	return "preparation"
```

When a missing onboarding field is detected:

- `preparation` initializes `boss_brief`;
- `battle` initializes `observe_battle`;
- `settlement` initializes `read_report`;
- `finished` initializes `complete`, keeps onboarding active, and suppresses automatic display until help is opened; it never resets the run.

Persist the initialized dictionary once. Do not use old `project-rest-new` tutorial fields.

- [ ] **Step 6: Run replay, save, and main tests**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-tutorial-replay-green.log" -s res://tests/challenge/challenge_tutorial_replay_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-save-replay-green.log" -s res://tests/challenge/challenge_save_service_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-main-replay-green.log" -s res://tests/challenge/challenge_main_scene_self_check.gd
```

Expected markers:

```text
CHALLENGE_TUTORIAL_REPLAY_SELF_CHECK_PASS
CHALLENGE_SAVE_SERVICE_SELF_CHECK_PASS
CHALLENGE_MAIN_SCENE_SELF_CHECK_PASS
```

- [ ] **Step 7: Commit**

```powershell
git add scripts/challenge/challenge_main_view.gd scripts/challenge/ui/challenge_settlement_dialog.gd tests/challenge/challenge_tutorial_replay_self_check.gd tests/challenge/challenge_tutorial_replay_self_check.gd.uid tests/challenge/challenge_save_service_self_check.gd
git commit -m "feat: persist and replay challenge tutorial"
```

---

### Task 7: Real Input, Visual Evidence, and Full Regression

**Files:**
- Create: `tests/challenge/challenge_tutorial_input_self_check.gd`
- Modify: `tests/challenge/challenge_vertical_slice_self_check.gd:8-42,44-180`
- Create: `docs/superpowers/verification/2026-07-27-challenge-onboarding-playtest.md`

**Interfaces:**
- Consumes: the completed tutorial route, actual scene input handlers, default main scene, and all prior self-checks.
- Produces: real mouse-path evidence and a final aggregate gate.

- [ ] **Step 1: Write the real-input self-check**

Use actual viewport input, not direct calls to `place_recipe()` or `rotate_instance()`:

```gdscript
func _drag(from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	Input.parse_input_event(press)
	await process_frame

	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.relative = to - from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await process_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	Input.parse_input_event(release)
	await process_frame

func _right_click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		event.position = position
		Input.parse_input_event(event)
		await process_frame
```

The test must:

1. start at `boss_brief`;
2. press the real confirm button;
3. drag the milk pudding card to a legal board cell;
4. assert tutorial step becomes `rotate_recipe`;
5. right-click an occupied pudding cell;
6. assert step becomes `read_risk`;
7. prove the overlay remained visible during drag and did not intercept input.

Expected marker: `CHALLENGE_TUTORIAL_INPUT_SELF_CHECK_PASS`.

- [ ] **Step 2: Run the input self-check and fix only real input failures**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-tutorial-input.log" -s res://tests/challenge/challenge_tutorial_input_self_check.gd
```

Expected: `CHALLENGE_TUTORIAL_INPUT_SELF_CHECK_PASS`.

If coordinate delivery fails, inspect viewport scale and use each target control's `get_global_rect().get_center()`; do not replace the test with direct method calls.

- [ ] **Step 3: Extend the aggregate resource and forbidden-dependency checks**

Add these resources to `REQUIRED_RESOURCES` or `REQUIRED_FILES`:

```gdscript
"res://scripts/challenge/challenge_tutorial_progress.gd",
"res://scripts/challenge/ui/challenge_tutorial_overlay.gd",
"res://scenes/challenge/challenge_tutorial_overlay.tscn",
"res://shaders/challenge/tutorial_spotlight.gdshader",
```

Assert:

- default main scene contains the help button and root overlay;
- default save contains onboarding version 1;
- challenge scripts do not reference `project_rest_new_save`, old `TutorialProgress`, old `tutorial_guide_overlay`, purchase, production, crafting, or long-term inventory writers;
- identical input tutorial events yield identical progress state.

- [ ] **Step 4: Run every challenge self-check with clean logs**

Run each `tests/challenge/*_self_check.gd` in a loop:

```powershell
$godot = "D:\Godot\Godot_v4.6.1-stable_win64_console.exe"
$tests = Get-ChildItem -LiteralPath "tests\challenge" -Filter "*_self_check.gd" | Sort-Object Name
foreach ($test in $tests) {
	$log = Join-Path $env:TEMP ("project-rest-two-onboarding-" + $test.Name + ".log")
	$output = & $godot --headless --path . --log-file $log -s ("res://tests/challenge/" + $test.Name) 2>&1
	$output | ForEach-Object { Write-Output $_ }
	if ($LASTEXITCODE -ne 0) { throw "$($test.Name) exited $LASTEXITCODE" }
	if (-not ($output -match "_PASS")) { throw "$($test.Name) printed no PASS marker" }
	$bad = Select-String -LiteralPath $log -Pattern "ERROR:|SCRIPT ERROR:"
	if ($bad) {
		$bad | ForEach-Object { $_.Line }
		throw "$($test.Name) logged errors"
	}
}
```

Expected: every test exits `0`, prints its explicit PASS marker, and logs no `ERROR:` or `SCRIPT ERROR:`.

- [ ] **Step 5: Run the default-scene smoke test**

```powershell
$log = Join-Path $env:TEMP "project-rest-two-onboarding-default-smoke.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log --quit-after 3
if ($LASTEXITCODE -ne 0) { throw "default scene smoke failed" }
if (Select-String -LiteralPath $log -Pattern "ERROR:|SCRIPT ERROR:") { throw "default scene logged errors" }
```

Expected: exit `0` and no error markers.

- [ ] **Step 6: Perform runtime visual acceptance**

Launch the real default scene and capture these states at 1920×1080:

1. Boss brief spotlight;
2. supply-to-board drag target;
3. placed pudding rotation target;
4. battle dual-pressure spotlight;
5. retryable-loss report spotlight;
6. victory report spotlight;
7. completion card and top-bar `？`.

Verify:

- target content is undimmed;
- arrow points to the intended control;
- hint card stays within the viewport;
- tutorial text remains readable;
- root and report overlays never display simultaneously;
- no tutorial layer blocks board or report controls.

- [ ] **Step 7: Write the verification report**

Create the report with explicit evidence rows:

```markdown
# Challenge Onboarding Verification

Date: 2026-07-27

## Automated evidence

| Path | Result | Evidence |
|---|---|---|
| New/missing save | PASS | Starts `boss_brief`, onboarding version 1 saved |
| Real drag | PASS | Milk pudding placed through mouse press/motion/release |
| Real rotation | PASS | Right-click changes pudding shape and advances |
| Victory | PASS | Report exit advances to completion |
| Retryable loss | PASS | Return waits for valid changed fingerprint |
| Terminal loss | PASS | Report exit completes without deadlock |
| Dismiss/resume/replay | PASS | Persistent status and session-only replay verified |

## Human observation

| Question | Status | Observation |
|---|---|---|
| Player understands drag and rotation without explanation | PENDING | Requires human playtest |
| Player can identify the failed demand window | PENDING | Requires human playtest |
| Player chooses to rearrange after failure | PENDING | Requires human playtest |

## Gate

- Technical implementation gate: GO only if all automated and visual checks pass.
- Product-hand-feel gate: NO-GO until the three human observations are recorded.
```

Do not mark human rows PASS without an observed human session.

- [ ] **Step 8: Verify repository isolation and patch cleanliness**

```powershell
git diff --check
git status --short
git -C "D:\Project\ProjectRest\project-rest-new" status --porcelain=v1
git -C "D:\Project\ProjectRest\project-rest-new" rev-parse HEAD
```

Expected:

- `git diff --check` prints nothing;
- target changes are limited to the onboarding plan's files;
- source status prints nothing;
- source HEAD remains `147ce4b1e3c25e5608dd844fa4c00fd2c3e52323`.

- [ ] **Step 9: Commit**

```powershell
git add tests/challenge/challenge_tutorial_input_self_check.gd tests/challenge/challenge_tutorial_input_self_check.gd.uid tests/challenge/challenge_vertical_slice_self_check.gd docs/superpowers/verification/2026-07-27-challenge-onboarding-playtest.md
git commit -m "test: verify challenge onboarding"
```

---

## Final Handoff Checklist

- [ ] All seven task commits are present on `feature/challenge-onboarding`.
- [ ] `git status --short` is clean.
- [ ] Every `tests/challenge/*_self_check.gd` passes from the final tree.
- [ ] Default main scene smoke test passes with no logged errors.
- [ ] Runtime screenshots cover preparation, battle, loss report, victory report, and completion.
- [ ] Verification report distinguishes automated evidence from pending human observation.
- [ ] `project-rest-new` remains clean at `147ce4b1e3c25e5608dd844fa4c00fd2c3e52323`.
- [ ] The branch is not merged or pushed without an explicit user choice.
