extends SceneTree

const SERVICE_PATH := "res://scripts/challenge/challenge_save_service.gd"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_challenge_save_state_test.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service = load(SERVICE_PATH)
	_expect(service != null, "challenge save service should load")
	if service == null:
		_finish()
		return

	var empty: Dictionary = service.empty_save()
	_expect(bool(service.validate_current(empty).get("ok", false)), "empty current save should validate")
	_expect(int(empty.get("schema_version", 0)) == 1, "schema marker should remain 1 during development")
	_expect(not empty.has("active_draft"), "current structure should not expose top-level active_draft")
	var meta: Dictionary = empty.get("meta", {})
	for field in [
		"research_points",
		"unlocked_recipe_ids",
		"unlocked_variant_ids",
		"unlocked_upgrade_ids",
		"revealed_research_node_ids",
		"boss_first_clear_ids",
		"applied_reward_transaction_ids",
		"endless_records",
		"onboarding"
	]:
		_expect(meta.has(field), "current meta should include %s" % field)

	var wrong_schema := empty.duplicate(true)
	wrong_schema["schema_version"] = 2
	_expect_incompatible(service, wrong_schema, "schema version mismatch")

	var legacy := empty.duplicate(true)
	legacy["active_run"] = {
		"run_id": "old-run",
		"mode": "vertical_slice"
	}
	_expect_incompatible(service, legacy, "legacy vertical_slice active run")

	var deprecated_draft := empty.duplicate(true)
	deprecated_draft["active_draft"] = {"placements": []}
	_expect_incompatible(service, deprecated_draft, "deprecated active_draft")

	var missing_ledger := empty.duplicate(true)
	missing_ledger["meta"].erase("applied_reward_transaction_ids")
	_expect_incompatible(service, missing_ledger, "missing permanent reward ledger")

	var unsafe := empty.duplicate(true)
	unsafe["meta"]["endless_records"] = {"bad": Vector2.ONE}
	_expect_incompatible(service, unsafe, "non JSON-safe value")

	var active_run := _active_run()
	var active_battle := _active_battle()
	var crash_states := [
		{"name": "battle running", "phase": "battle", "battle": active_battle},
		{"name": "battle report pending", "phase": "battle_result_win", "battle": active_battle},
		{
			"name": "upgrade offer pending",
			"phase": "upgrade_select",
			"battle": null,
			"offer": {
				"offer_id": "standard:1:42:upgrade:0",
				"candidate_ids": ["quick_service", "warm_display", "dessert_pivot"]
			}
		},
		{
			"name": "upgrade applied",
			"phase": "preparation",
			"battle": null,
			"upgrade_tx": "standard:1:42:upgrade:0:quick_service"
		},
		{
			"name": "research reward applied before run clear",
			"phase": "run_complete",
			"battle": null,
			"research_tx": "standard:1:42:research-complete"
		}
	]
	_cleanup()
	for crash_value in crash_states:
		var crash: Dictionary = crash_value
		var state := empty.duplicate(true)
		var run := active_run.duplicate(true)
		run["phase"] = crash["phase"]
		run["pending_upgrade_offer"] = crash.get("offer")
		if crash.has("upgrade_tx"):
			run["applied_run_reward_transaction_ids"].append(crash["upgrade_tx"])
			run["run_upgrades"].append({"upgrade_id": "quick_service"})
		if crash.has("research_tx"):
			state["meta"]["applied_reward_transaction_ids"].append(crash["research_tx"])
			state["meta"]["research_points"] = 3
			run["applied_run_reward_transaction_ids"].append(crash["research_tx"])
		state["active_run"] = run
		state["active_battle"] = crash.get("battle")
		var validation: Dictionary = service.validate_current(state)
		_expect(bool(validation.get("ok", false)), "%s state should validate" % crash["name"])
		var saved: Dictionary = service.save_to_path(_save_path, state)
		_expect(bool(saved.get("ok", false)), "%s state should save" % crash["name"])
		var loaded: Dictionary = service.load_from_path(_save_path)
		_expect(bool(loaded.get("ok", false)), "%s state should load" % crash["name"])
		var loaded_data: Dictionary = loaded.get("data", {})
		var loaded_run: Dictionary = loaded_data.get("active_run", {})
		_expect(String(loaded_run.get("phase", "")) == String(crash["phase"]), "%s phase should survive" % crash["name"])
		if crash.has("offer"):
			_expect(
				(loaded_run.get("pending_upgrade_offer", {}) as Dictionary).get("candidate_ids", [])
					== crash["offer"]["candidate_ids"],
				"upgrade candidate IDs and order should survive"
			)
		if crash.has("research_tx"):
			var loaded_meta: Dictionary = loaded_data.get("meta", {})
			_expect(int(loaded_meta.get("research_points", 0)) == 3, "research points should survive rewarded crash point")
			_expect(
				loaded_meta.get("applied_reward_transaction_ids", []).count(crash["research_tx"]) == 1,
				"permanent reward transaction should survive exactly once"
			)

	_test_incompatible_file(service)
	_cleanup()
	_finish()


func _active_run() -> Dictionary:
	return {
		"run_id": "standard:1:42",
		"mode": "standard",
		"seed": 42,
		"phase": "preparation",
		"route_id": "opening_route",
		"stage_index": 0,
		"confidence": 2,
		"permanent_pool_snapshot": {
			"recipe_ids": ["butter_cookie", "milk_pudding"],
			"variant_ids": [],
			"upgrade_ids": []
		},
		"run_upgrades": [],
		"encounter_instances": [
			{
				"encounter_instance_id": "standard:1:42:stage:0",
				"encounter_id": "breakfast_rush",
				"encounter_seed": 42,
				"reward_seed": 1042
			}
		],
		"loadout_draft": {"placements": []},
		"pending_upgrade_offer": null,
		"stage_history": [],
		"settled_settlement_ids": [],
		"applied_run_reward_transaction_ids": [],
		"next_attempt_index": 1
	}


func _active_battle() -> Dictionary:
	return {
		"battle_attempt_id": "standard:1:42:stage:0:attempt:0",
		"encounter_instance_id": "standard:1:42:stage:0",
		"stage_index": 0,
		"snapshot": {"instances": [], "relations": []},
		"elapsed_ms": 4200,
		"item_states": {},
		"pickiness": 75,
		"reputation": 30,
		"resolved_windows": {},
		"events": [{"seq": 0, "at_ms": 4000, "type": "sale"}],
		"next_event_seq": 1,
		"phase": "running"
	}


func _test_incompatible_file(service: Variant) -> void:
	_cleanup()
	var incompatible: Dictionary = service.empty_save()
	incompatible["schema_version"] = 99
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		_fail("test should create incompatible save")
		return
	file.store_string(JSON.stringify(incompatible))
	file.close()
	var loaded: Dictionary = service.load_from_path(_save_path)
	_expect(not bool(loaded.get("ok", true)), "incompatible development save should not be guessed or migrated")
	_expect(
		String(loaded.get("error", "")) == service.INCOMPATIBLE_ERROR,
		"incompatible development save should return an explicit rebuild signal"
	)
	_expect(not String(loaded.get("reason", "")).is_empty(), "incompatible save should explain the rejected structure")
	_expect(FileAccess.file_exists(_save_path + ".broken"), "incompatible file should be preserved for diagnostics")


func _expect_incompatible(service: Variant, data: Dictionary, context: String) -> void:
	var result: Dictionary = service.validate_current(data)
	_expect(not bool(result.get("ok", true)), "%s should be rejected" % context)
	_expect(
		String(result.get("error", "")) == service.INCOMPATIBLE_ERROR,
		"%s should return the explicit incompatibility error" % context
	)
	_expect(not String(result.get("reason", "")).is_empty(), "%s should include a reason" % context)


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var path: String = _save_path + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_SAVE_STATE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
