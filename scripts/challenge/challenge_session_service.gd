class_name ChallengeSessionService
extends RefCounted

const ChallengeSaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const ChallengeRunService = preload("res://scripts/challenge/challenge_run_service.gd")
const BossEncounterService = preload("res://scripts/challenge/boss_encounter_service.gd")
const RunUpgradeService = preload("res://scripts/challenge/run_upgrade_service.gd")
const RecipeResearchService = preload("res://scripts/challenge/recipe_research_service.gd")
const ChallengeMenuService = preload("res://scripts/challenge/challenge_menu_service.gd")
const ChallengeRouteService = preload("res://scripts/challenge/challenge_route_service.gd")
const ChallengeMasteryService = preload("res://scripts/challenge/challenge_mastery_service.gd")
const ChallengeLoadoutService = preload("res://scripts/challenge/challenge_loadout_service.gd")
const BossBattleService = preload("res://scripts/challenge/boss_battle_service.gd")
const BossBattleReportService = preload("res://scripts/challenge/boss_battle_report_service.gd")
const EndlessClimbService = preload("res://scripts/challenge/endless_climb_service.gd")

const RECIPE_CONFIG_PATH := "res://doc/challenge/challenge_recipes.json"
const ENCOUNTER_CONFIG_PATH := "res://doc/challenge/boss_encounters.json"
const ROUTE_CONFIG_PATH := "res://doc/challenge/standard_run.json"
const UPGRADE_CONFIG_PATH := "res://doc/challenge/run_upgrades.json"
const RESEARCH_TREE_PATH := "res://doc/challenge/research_tree.json"
const ENDLESS_CONFIG_PATH := "res://doc/challenge/endless_run.json"
const MASTERY_CONFIG_PATH := "res://doc/challenge/challenge_masteries.json"

var save_path := ChallengeSaveService.SAVE_PATH

var _recipe_config: Dictionary = {}
var _encounter_defs: Dictionary = {}
var _route_defs: Dictionary = {}
var _upgrade_defs: Dictionary = {}
var _research_tree: Dictionary = {}
var _endless_config: Dictionary = {}
var _mastery_defs: Dictionary = {}

var _run_service = ChallengeRunService.new()
var _encounter_service = BossEncounterService.new()
var _upgrade_service = RunUpgradeService.new()
var _research_service = RecipeResearchService.new()
var _menu_service = ChallengeMenuService.new()
var _route_service = ChallengeRouteService.new()
var _mastery_service = ChallengeMasteryService.new()
var _loadout_service = ChallengeLoadoutService.new()
var _battle_service = BossBattleService.new()
var _report_service = BossBattleReportService.new()
var _endless_service = EndlessClimbService.new()


func configure(
	recipe_config: Dictionary,
	encounter_defs: Dictionary,
	route_defs: Dictionary,
	upgrade_defs: Dictionary,
	research_tree: Dictionary,
	next_save_path: String = "",
	endless_config: Dictionary = {},
	mastery_defs: Dictionary = {}
) -> void:
	_recipe_config = recipe_config.duplicate(true)
	_encounter_defs = encounter_defs.duplicate(true)
	_route_defs = route_defs.duplicate(true)
	_upgrade_defs = upgrade_defs.duplicate(true)
	_research_tree = research_tree.duplicate(true)
	_endless_config = endless_config.duplicate(true)
	_mastery_defs = mastery_defs.duplicate(true)
	if not next_save_path.is_empty():
		save_path = next_save_path


func load_or_create() -> Dictionary:
	_ensure_configured()
	var loaded := ChallengeSaveService.load_from_path(save_path)
	var data: Dictionary
	var reset_reason := ""
	if bool(loaded.get("ok", false)):
		data = (loaded.get("data", {}) as Dictionary).duplicate(true)
	else:
		data = ChallengeSaveService.empty_save()
		reset_reason = String(loaded.get("error", "save_read_failed"))
	data = _bootstrap_save(data)
	var saved := ChallengeSaveService.save_to_path(save_path, data)
	if not bool(saved.get("ok", false)):
		return _result(false, data, String(saved.get("error", "save_failed")))
	var result := _result(true, data)
	result["source"] = loaded.get("source", "reset")
	if not reset_reason.is_empty():
		result["reset_reason"] = reset_reason
	return result


func create_standard_run(save_data: Dictionary, route_id: String, seed: int) -> Dictionary:
	_ensure_configured()
	var next_save := _bootstrap_save(save_data)
	if next_save.get("active_run") is Dictionary:
		return _result(false, next_save, "active_run_already_exists")
	if not _route_defs.has(route_id) or not _route_defs[route_id] is Dictionary:
		return _result(false, next_save, "unknown_route")
	var route_state := _route_service.route_state(next_save.get("meta", {}), route_id, _route_defs)
	if not bool(route_state.get("unlocked", false)):
		return _result(false, next_save, String(route_state.get("lock_reason", "route_locked")))
	var route: Dictionary = _route_defs[route_id]
	var recipe_ids := active_menu(next_save)
	var pool_snapshot := {
		"recipe_ids": recipe_ids.duplicate(),
		"recipe_defs": _recipe_subset(recipe_ids)
	}
	var run_id := "standard:%s:%d" % [route_id, seed]
	var run := _run_service.create_standard_run(run_id, seed, route_id, pool_snapshot)
	var created := _encounter_service.create_standard_encounters(
		run_id,
		seed,
		route,
		_encounter_defs,
		pool_snapshot
	)
	if not bool(created.get("ok", false)):
		return _result(false, next_save, _first_error(created, "encounter_creation_failed"))
	var locked := _run_service.lock_encounters(run, created.get("encounter_instances", []))
	if not bool(locked.get("applied", false)):
		return _result(false, next_save, String(locked.get("error", "encounter_lock_failed")))
	next_save["active_run"] = (locked.get("run", {}) as Dictionary).duplicate(true)
	next_save["active_battle"] = null
	return _commit(next_save, {
		"run_id": run_id,
		"route_id": route_id,
		"recipe_ids": recipe_ids
	})


func can_start_endless(save_data: Dictionary) -> bool:
	var meta: Dictionary = (_bootstrap_save(save_data).get("meta", {}) as Dictionary)
	var records: Dictionary = meta.get("endless_records", {})
	return bool(records.get("unlocked", false))


func create_endless_run(save_data: Dictionary, seed: int) -> Dictionary:
	_ensure_configured()
	var next_save := _bootstrap_save(save_data)
	if next_save.get("active_run") is Dictionary:
		return _result(false, next_save, "active_run_already_exists")
	if not can_start_endless(next_save):
		return _result(false, next_save, "endless_not_unlocked")
	var recipe_ids := active_menu(next_save)
	var pool_snapshot := {
		"recipe_ids": recipe_ids.duplicate(),
		"recipe_defs": _recipe_subset(recipe_ids)
	}
	var run_id := "endless:%d" % seed
	var created := _endless_service.create_run(
		run_id,
		seed,
		pool_snapshot,
		_endless_config,
		_encounter_defs
	)
	if not bool(created.get("ok", false)):
		return _result(false, next_save, _first_error(created, "endless_creation_failed"))
	next_save["active_run"] = (created.get("run", {}) as Dictionary).duplicate(true)
	next_save["active_battle"] = null
	return _commit(next_save, {
		"run_id": run_id,
		"route_id": String(_endless_config.get("id", "endless_climb")),
		"recipe_ids": recipe_ids
	})


func start_battle(save_data: Dictionary, draft: Dictionary) -> Dictionary:
	_ensure_configured()
	var next_save := save_data.duplicate(true)
	var run := _active_run(next_save)
	if run.is_empty():
		return _result(false, next_save, "active_run_required")
	var encounter := _run_service.current_encounter(run)
	if encounter.is_empty():
		return _result(false, next_save, "current_encounter_missing")
	var effective_context := effective_context_for_run(run)
	var route := _route_for_run(run)
	var built := _loadout_service.build_snapshot_from_context(
		draft,
		effective_context,
		encounter,
		int(route.get("grid_rows", _recipe_config.get("grid_rows", 6))),
		int(route.get("grid_columns", _recipe_config.get("grid_columns", 8)))
	)
	if not bool(built.get("ok", false)):
		var rejected := _result(false, next_save, _first_error(built, "invalid_loadout"))
		rejected["errors"] = (built.get("errors", []) as Array).duplicate()
		rejected["requires_rearrange"] = bool(built.get("requires_rearrange", false))
		return rejected
	run["loadout_draft"] = draft.duplicate(true)
	var begun := _run_service.begin_battle(run)
	if not bool(begun.get("applied", false)):
		return _result(false, next_save, String(begun.get("error", "battle_cannot_begin")))
	run = (begun.get("run", {}) as Dictionary).duplicate(true)
	var snapshot: Dictionary = built.get("snapshot", {})
	var battle := _battle_service.create_state(
		snapshot,
		encounter,
		int(encounter.get("encounter_seed", run.get("seed", 0)))
	)
	battle["battle_attempt_id"] = String(begun.get("battle_attempt_id", ""))
	battle["encounter_instance_id"] = String(begun.get("encounter_instance_id", ""))
	battle["stage_index"] = int(run.get("stage_index", 0))
	battle["snapshot"] = snapshot.duplicate(true)
	next_save["active_run"] = run
	next_save["active_battle"] = battle
	return _commit(next_save, {
		"battle_attempt_id": battle["battle_attempt_id"],
		"snapshot": snapshot.duplicate(true),
		"effective_context": effective_context
	})


func settle_battle(save_data: Dictionary, battle_state: Dictionary) -> Dictionary:
	_ensure_configured()
	var next_save := save_data.duplicate(true)
	var run := _active_run(next_save)
	if run.is_empty():
		return _result(false, next_save, "active_run_required")
	var identity_error := _battle_identity_error(run, battle_state)
	if not identity_error.is_empty():
		return _result(false, next_save, identity_error)
	if String(battle_state.get("phase", "")) != "finished":
		return _result(false, next_save, "battle_not_finished")
	var outcome := String(battle_state.get("outcome", ""))
	var battle_attempt_id := String(battle_state.get("battle_attempt_id", ""))
	var settlement_id := "%s:%s" % [battle_attempt_id, outcome]
	if (run.get("settled_settlement_ids", []) as Array).has(settlement_id):
		var duplicate := _result(false, next_save)
		duplicate["settlement_id"] = settlement_id
		return duplicate
	var registered := _run_service.register_result(run, {
		"settlement_id": settlement_id,
		"outcome": outcome,
		"encounter_instance_id": String(battle_state.get("encounter_instance_id", ""))
	})
	if not bool(registered.get("applied", false)):
		return _result(false, next_save, String(registered.get("error", "settlement_rejected")))
	run = (registered.get("run", {}) as Dictionary).duplicate(true)
	var mode := String(run.get("mode", ""))
	var meta: Dictionary = next_save.get("meta", {})
	var encounter := _run_service.current_encounter(run)
	if outcome == "victory" and mode == "standard":
		var encounter_id := String(encounter.get("encounter_id", ""))
		var reveal_ids: Array = (
			_research_tree.get("boss_reveals", {}) as Dictionary
		).get(encounter_id, [])
		var reveal_tx := "%s:boss-first-clear" % String(
			battle_state.get("encounter_instance_id", "")
		)
		var revealed := _research_service.reveal_for_boss_clear(
			meta,
			encounter_id,
			reveal_ids,
			reveal_tx
		)
		meta = (revealed.get("meta", meta) as Dictionary).duplicate(true)
		if String(run.get("phase", "")) == "run_complete":
			meta = _unlock_endless_for_standard_completion(meta, String(run.get("run_id", "")))
			var route_clear := _route_service.record_first_clear(
				meta,
				String(run.get("route_id", "")),
				_route_defs
			)
			meta = (route_clear.get("meta", meta) as Dictionary).duplicate(true)
			var mastery_result := _mastery_service.evaluate(meta, _mastery_defs)
			meta = (mastery_result.get("meta", meta) as Dictionary).duplicate(true)
	var stored_battle := battle_state.duplicate(true)
	if not stored_battle.has("snapshot"):
		stored_battle["snapshot"] = (
			stored_battle.get("_snapshot", {}) as Dictionary
		).duplicate(true)
	run["last_battle_snapshot"] = (
		stored_battle.get("snapshot", {}) as Dictionary
	).duplicate(true)
	var confidence_recovered := 0
	if mode == "endless" and outcome == "victory":
		var recovered := _endless_service.apply_floor_recovery(run, _endless_config)
		run = (recovered.get("run", run) as Dictionary).duplicate(true)
		confidence_recovered = int(recovered.get("confidence_recovered", 0))
	elif mode == "endless" and String(run.get("phase", "")) == "run_failed":
		var key_report := _report_service.build(stored_battle, encounter)
		var finalized := _finalize_endless_record(meta, run, key_report)
		meta = (finalized.get("meta", meta) as Dictionary).duplicate(true)
		run = (finalized.get("run", run) as Dictionary).duplicate(true)
		var mastery_result := _mastery_service.evaluate(meta, _mastery_defs)
		meta = (mastery_result.get("meta", meta) as Dictionary).duplicate(true)
	next_save["meta"] = meta
	next_save["active_run"] = run
	next_save["active_battle"] = stored_battle
	return _commit(next_save, {
		"settlement_id": settlement_id,
		"outcome": outcome,
		"phase": String(run.get("phase", "")),
		"confidence_recovered": confidence_recovered
	})


func acknowledge_battle_result(save_data: Dictionary) -> Dictionary:
	var next_save := save_data.duplicate(true)
	var run := _active_run(next_save)
	if run.is_empty():
		return _result(false, next_save, "active_run_required")
	var acknowledged := _run_service.acknowledge_battle_result(run)
	if not bool(acknowledged.get("applied", false)):
		return _result(false, next_save, String(acknowledged.get("error", "battle_result_not_ready")))
	next_save["active_run"] = (acknowledged.get("run", {}) as Dictionary).duplicate(true)
	next_save["active_battle"] = null
	return _commit(next_save, {
		"phase": String((next_save["active_run"] as Dictionary).get("phase", ""))
	})


func update_draft(save_data: Dictionary, draft: Dictionary) -> Dictionary:
	var next_save := save_data.duplicate(true)
	var run := _active_run(next_save)
	if run.is_empty():
		return _result(false, next_save, "active_run_required")
	if String(run.get("phase", "")) != "preparation":
		return _result(false, next_save, "draft_not_editable")
	run["loadout_draft"] = draft.duplicate(true)
	next_save["active_run"] = run
	return _commit(next_save)


func save_battle_progress(save_data: Dictionary, battle_state: Dictionary) -> Dictionary:
	var next_save := save_data.duplicate(true)
	var run := _active_run(next_save)
	if run.is_empty():
		return _result(false, next_save, "active_run_required")
	var identity_error := _battle_identity_error(run, battle_state)
	if not identity_error.is_empty():
		return _result(false, next_save, identity_error)
	var stored := battle_state.duplicate(true)
	if not stored.has("snapshot"):
		stored["snapshot"] = (stored.get("_snapshot", {}) as Dictionary).duplicate(true)
	next_save["active_battle"] = stored
	return _commit(next_save)


func update_onboarding(save_data: Dictionary, onboarding: Dictionary) -> Dictionary:
	var next_save := _bootstrap_save(save_data)
	var meta: Dictionary = next_save.get("meta", {})
	meta["onboarding"] = onboarding.duplicate(true)
	next_save["meta"] = meta
	return _commit(next_save)


func prepare_upgrade_offer(save_data: Dictionary, draft_analysis: Dictionary) -> Dictionary:
	_ensure_configured()
	var next_save := save_data.duplicate(true)
	var run := _active_run(next_save)
	if run.is_empty():
		return _result(false, next_save, "active_run_required")
	var existing: Dictionary = run.get("pending_upgrade_offer", {})
	if String(run.get("phase", "")) == "upgrade_select" and not existing.is_empty():
		var restored := _result(false, next_save)
		restored["offer"] = existing.duplicate(true)
		return restored
	var pool: Dictionary = run.get("permanent_pool_snapshot", {})
	var generated := _upgrade_service.generate_offer(
		run,
		draft_analysis,
		pool.get("recipe_ids", []),
		_upgrade_defs
	)
	if not bool(generated.get("ok", false)):
		return _result(false, next_save, String(generated.get("error", "upgrade_offer_failed")))
	var attached := _run_service.attach_upgrade_offer(run, generated.get("offer", {}))
	if not bool(attached.get("applied", false)):
		return _result(false, next_save, String(attached.get("error", "upgrade_offer_rejected")))
	next_save["active_run"] = (attached.get("run", {}) as Dictionary).duplicate(true)
	next_save["active_battle"] = null
	return _commit(next_save, {"offer": generated.get("offer", {}).duplicate(true)})


func choose_upgrade(save_data: Dictionary, offer_id: String, upgrade_id: String) -> Dictionary:
	_ensure_configured()
	var next_save := save_data.duplicate(true)
	var run := _active_run(next_save)
	if run.is_empty():
		return _result(false, next_save, "active_run_required")
	var offer: Dictionary = run.get("pending_upgrade_offer", {})
	if String(offer.get("offer_id", "")) != offer_id:
		return _result(false, next_save, "upgrade_offer_mismatch")
	var before_context := effective_context_for_run(run)
	var applied := _upgrade_service.apply_choice(run, offer, upgrade_id)
	if not bool(applied.get("applied", false)):
		return _result(false, next_save, String(applied.get("error", "upgrade_choice_rejected")))
	var effect_run: Dictionary = applied.get("run", {})
	var reward_tx := String(applied.get("reward_transaction_id", ""))
	var finalized := _run_service.finalize_upgrade_choice(
		effect_run,
		offer_id,
		upgrade_id,
		reward_tx
	)
	if not bool(finalized.get("applied", false)):
		return _result(false, next_save, String(finalized.get("error", "upgrade_finalize_failed")))
	run = (finalized.get("run", {}) as Dictionary).duplicate(true)
	if String(run.get("mode", "")) == "endless":
		var ensured := _endless_service.ensure_current_floor(run, _endless_config, _encounter_defs)
		if not bool(ensured.get("ok", false)):
			return _result(false, next_save, String(ensured.get("error", "floor_generation_failed")))
		run = (ensured.get("run", run) as Dictionary).duplicate(true)
	var after_context := effective_context_for_run(run)
	var summary := _upgrade_service.describe_effect(before_context, after_context, upgrade_id)
	next_save["active_run"] = run
	next_save["active_battle"] = null
	return _commit(next_save, {
		"upgrade_id": upgrade_id,
		"reward_transaction_id": reward_tx,
		"effect_summary": summary
	})


func grant_completion_reward(save_data: Dictionary) -> Dictionary:
	_ensure_configured()
	var next_save := save_data.duplicate(true)
	var run := _active_run(next_save)
	if run.is_empty():
		return _result(false, next_save, "active_run_required")
	if String(run.get("mode", "")) == "endless":
		return _grant_endless_completion_reward(next_save, run)
	var reward_tx := "%s:research-complete" % String(run.get("run_id", ""))
	var points := int(_research_tree.get("completion_reward_points", 3))
	var granted := _research_service.grant_run_completion(
		next_save.get("meta", {}),
		points,
		reward_tx
	)
	var marked := _run_service.mark_research_rewarded(run, reward_tx)
	if not bool(marked.get("applied", false)):
		if bool(run.get("research_rewarded", false)):
			return _result(false, next_save)
		return _result(false, next_save, String(marked.get("error", "research_reward_rejected")))
	next_save["meta"] = (granted.get("meta", next_save.get("meta", {})) as Dictionary).duplicate(true)
	next_save["active_run"] = (marked.get("run", {}) as Dictionary).duplicate(true)
	next_save["active_battle"] = null
	return _commit(next_save, {
		"points_granted": points if bool(granted.get("applied", false)) else 0,
		"reward_transaction_id": reward_tx
	})


func unlock_research(save_data: Dictionary, node_id: String) -> Dictionary:
	_ensure_configured()
	var next_save := _bootstrap_save(save_data)
	var reward_tx := "research-unlock:%s" % node_id
	var unlocked := _research_service.unlock_node(
		next_save.get("meta", {}),
		node_id,
		_research_tree,
		reward_tx
	)
	if not bool(unlocked.get("applied", false)):
		return _result(false, next_save, String(unlocked.get("error", "")))
	next_save["meta"] = (unlocked.get("meta", {}) as Dictionary).duplicate(true)
	return _commit(next_save, {
		"node_id": node_id,
		"spent_points": int(unlocked.get("spent_points", 0)),
		"granted_unlocks": (unlocked.get("granted_unlocks", []) as Array).duplicate(true)
	})


func return_to_hub(save_data: Dictionary) -> Dictionary:
	var next_save := save_data.duplicate(true)
	var run := _active_run(next_save)
	if run.is_empty():
		return _result(false, next_save, "active_run_required")
	var returned := _run_service.return_to_hub(run)
	if not bool(returned.get("applied", false)):
		return _result(false, next_save, String(returned.get("error", "run_not_ready_to_return")))
	var summary: Dictionary = returned.get("run", {})
	next_save["active_run"] = null
	next_save["active_battle"] = null
	return _commit(next_save, {"completed_run": summary.duplicate(true)})


func recover(save_data: Dictionary) -> Dictionary:
	var next_save := save_data.duplicate(true)
	var run := _active_run(next_save)
	var battle_value: Variant = next_save.get("active_battle")
	if run.is_empty() or battle_value == null:
		return _result(false, next_save)
	if not battle_value is Dictionary:
		next_save["active_battle"] = null
		run["phase"] = "preparation"
		next_save["active_run"] = run
		return _commit(next_save, {"recovery_reason": "active_battle_not_dictionary"})
	var battle: Dictionary = battle_value
	var identity_error := _battle_identity_error(run, battle)
	if not identity_error.is_empty():
		next_save["active_battle"] = null
		run["phase"] = "preparation"
		run["current_battle_attempt_id"] = ""
		next_save["active_run"] = run
		return _commit(next_save, {"recovery_reason": identity_error})
	if String(battle.get("phase", "")) == "running":
		battle["recovery_paused"] = true
		next_save["active_battle"] = battle
		return _commit(next_save, {"recovery_reason": "battle_restored_paused"})
	return _result(false, next_save)


func effective_context_for_run(run: Dictionary) -> Dictionary:
	var pool: Dictionary = run.get("permanent_pool_snapshot", {})
	var base_recipe_defs: Dictionary = pool.get("recipe_defs", {})
	var encounter := _run_service.current_encounter(run)
	var base_rules := {
		"supply_budget": int(
			encounter.get("supply_budget", _recipe_config.get("supply_budget", 16))
		)
	}
	return _upgrade_service.resolve_context(
		base_recipe_defs,
		base_rules,
		run.get("run_upgrades", [])
	)


func current_encounter(save_data: Dictionary) -> Dictionary:
	return _run_service.current_encounter(_active_run(save_data))


func research_tree() -> Dictionary:
	_ensure_configured()
	return _research_tree.duplicate(true)


func available_recipe_ids(save_data: Dictionary) -> Array[String]:
	_ensure_configured()
	var meta: Dictionary = (_bootstrap_save(save_data).get("meta", {}) as Dictionary)
	return _research_service.available_recipe_ids(meta, _research_tree)


func active_menu(save_data: Dictionary) -> Array[String]:
	_ensure_configured()
	var bootstrapped := _bootstrap_save(save_data)
	var meta: Dictionary = bootstrapped.get("meta", {})
	var result: Array[String] = []
	for value in meta.get("active_menu_recipe_ids", []):
		if value is String:
			result.append(String(value))
	return result


func menu_analysis(save_data: Dictionary) -> Dictionary:
	_ensure_configured()
	return _menu_service.analyze_menu(active_menu(save_data), _recipe_config.get("recipes", {}))


func set_active_menu(save_data: Dictionary, recipe_ids: Variant) -> Dictionary:
	_ensure_configured()
	var next_save := _bootstrap_save(save_data)
	if next_save.get("active_run") is Dictionary:
		return _result(false, next_save, "active_run_menu_locked")
	var available := available_recipe_ids(next_save)
	var changed := _menu_service.set_active_menu(
		next_save.get("meta", {}),
		recipe_ids,
		available,
		_recipe_config.get("recipes", {})
	)
	if not bool(changed.get("applied", false)):
		var rejected := _result(false, next_save, "invalid_active_menu")
		rejected["errors"] = (changed.get("errors", []) as Array).duplicate()
		return rejected
	next_save["meta"] = (changed.get("meta", {}) as Dictionary).duplicate(true)
	return _commit(next_save, {"recipe_ids": changed.get("recipe_ids", [])})


func save_menu_preset(
	save_data: Dictionary,
	preset_id: String,
	display_name: String,
	recipe_ids: Variant
) -> Dictionary:
	_ensure_configured()
	var next_save := _bootstrap_save(save_data)
	if next_save.get("active_run") is Dictionary:
		return _result(false, next_save, "active_run_menu_locked")
	var changed := _menu_service.save_preset(
		next_save.get("meta", {}),
		preset_id,
		display_name,
		recipe_ids,
		available_recipe_ids(next_save),
		_recipe_config.get("recipes", {})
	)
	if not bool(changed.get("applied", false)):
		var rejected := _result(false, next_save, "invalid_menu_preset")
		rejected["errors"] = (changed.get("errors", []) as Array).duplicate()
		return rejected
	next_save["meta"] = (changed.get("meta", {}) as Dictionary).duplicate(true)
	return _commit(next_save, {"preset": changed.get("preset", {})})


func load_menu_preset(save_data: Dictionary, preset_id: String) -> Dictionary:
	_ensure_configured()
	var next_save := _bootstrap_save(save_data)
	if next_save.get("active_run") is Dictionary:
		return _result(false, next_save, "active_run_menu_locked")
	var changed := _menu_service.load_preset(
		next_save.get("meta", {}),
		preset_id,
		available_recipe_ids(next_save),
		_recipe_config.get("recipes", {})
	)
	if not bool(changed.get("applied", false)):
		var rejected := _result(false, next_save, "invalid_menu_preset")
		rejected["errors"] = (changed.get("errors", []) as Array).duplicate()
		return rejected
	next_save["meta"] = (changed.get("meta", {}) as Dictionary).duplicate(true)
	return _commit(next_save, {"recipe_ids": changed.get("recipe_ids", [])})


func recipe_definitions() -> Dictionary:
	_ensure_configured()
	return (_recipe_config.get("recipes", {}) as Dictionary).duplicate(true)


func route_states(save_data: Dictionary) -> Array[Dictionary]:
	_ensure_configured()
	var meta: Dictionary = (_bootstrap_save(save_data).get("meta", {}) as Dictionary)
	return _route_service.all_states(meta, _route_defs)


func route_definitions() -> Dictionary:
	_ensure_configured()
	return _route_defs.duplicate(true)


func mastery_states(save_data: Dictionary) -> Array[Dictionary]:
	_ensure_configured()
	var meta: Dictionary = (_bootstrap_save(save_data).get("meta", {}) as Dictionary)
	return _mastery_service.states(meta, _mastery_defs)


func research_node_state(save_data: Dictionary, node_id: String) -> Dictionary:
	_ensure_configured()
	return _research_service.node_state(
		(save_data.get("meta", {}) as Dictionary),
		node_id,
		_research_tree
	)


func endless_config() -> Dictionary:
	_ensure_configured()
	return _endless_config.duplicate(true)


func _unlock_endless_for_standard_completion(meta_state: Dictionary, run_id: String) -> Dictionary:
	var meta := meta_state.duplicate(true)
	var records: Dictionary = (meta.get("endless_records", {}) as Dictionary).duplicate(true)
	var run_ids: Array = records.get("standard_completion_run_ids", [])
	if not run_ids.has(run_id):
		run_ids.append(run_id)
		records["standard_completion_count"] = int(records.get("standard_completion_count", 0)) + 1
	records["standard_completion_run_ids"] = run_ids
	records["unlocked"] = true
	meta["endless_records"] = records
	return meta


func _finalize_endless_record(
	meta_state: Dictionary,
	run_state: Dictionary,
	key_battle_report: Dictionary
) -> Dictionary:
	var meta := meta_state.duplicate(true)
	var run := run_state.duplicate(true)
	if bool(run.get("endless_record_finalized", false)):
		return {"meta": meta, "run": run}
	var snapshot := _endless_service.build_record_snapshot(run, key_battle_report)
	var records: Dictionary = (meta.get("endless_records", {}) as Dictionary).duplicate(true)
	records["unlocked"] = true
	records["total_runs"] = int(records.get("total_runs", 0)) + 1
	records["last_run_snapshot"] = snapshot.duplicate(true)
	if int(snapshot.get("highest_floor", 0)) > int(records.get("best_floor", 0)):
		records["best_floor"] = int(snapshot.get("highest_floor", 0))
		records["best_snapshot"] = snapshot.duplicate(true)
	meta["endless_records"] = records
	run["endless_record_finalized"] = true
	run["highest_cleared_floor"] = int(snapshot.get("highest_floor", 0))
	return {"meta": meta, "run": run, "snapshot": snapshot}


func _grant_endless_completion_reward(next_save: Dictionary, run_state: Dictionary) -> Dictionary:
	var run := run_state.duplicate(true)
	if String(run.get("phase", "")) != "run_failed":
		return _result(false, next_save, "endless_reward_not_expected")
	if bool(run.get("endless_rewarded", false)):
		return _result(false, next_save)
	var reward_tx := "%s:research-endless" % String(run.get("run_id", ""))
	var points := _endless_service.research_reward_for_run(run, _endless_config)
	var granted := _research_service.grant_run_completion(
		next_save.get("meta", {}),
		points,
		reward_tx
	)
	var transactions: Array = run.get("applied_run_reward_transaction_ids", [])
	if not transactions.has(reward_tx):
		transactions.append(reward_tx)
	run["applied_run_reward_transaction_ids"] = transactions
	run["research_reward_transaction_id"] = reward_tx
	run["research_rewarded"] = true
	run["endless_rewarded"] = true
	next_save["meta"] = (granted.get("meta", next_save.get("meta", {})) as Dictionary).duplicate(true)
	next_save["active_run"] = run
	next_save["active_battle"] = null
	return _commit(next_save, {
		"points_granted": points if bool(granted.get("applied", false)) else 0,
		"reward_transaction_id": reward_tx
	})


func _bootstrap_save(save_data: Dictionary) -> Dictionary:
	var next_save := save_data.duplicate(true)
	if next_save.is_empty():
		next_save = ChallengeSaveService.empty_save()
	var meta: Dictionary = _research_service.bootstrap_meta(next_save.get("meta", {}), _research_tree)
	meta = _route_service.bootstrap_meta(meta, _route_defs)
	meta = _mastery_service.bootstrap_meta(meta)
	var available := _research_service.available_recipe_ids(meta, _research_tree)
	var starters: Array[String] = []
	for value in _research_tree.get("starter_recipe_ids", []):
		if value is String:
			starters.append(String(value))
	meta = _menu_service.bootstrap_meta(meta, available, starters)
	var records: Dictionary = (meta.get("endless_records", {}) as Dictionary).duplicate(true)
	if not records.has("unlocked"):
		records["unlocked"] = false
	if not records.has("best_floor"):
		records["best_floor"] = 0
	if not records.has("best_snapshot"):
		records["best_snapshot"] = {}
	if not records.has("last_run_snapshot"):
		records["last_run_snapshot"] = {}
	if not records.has("total_runs"):
		records["total_runs"] = 0
	if not records.has("standard_completion_count"):
		records["standard_completion_count"] = 0
	if not records.has("standard_completion_run_ids"):
		records["standard_completion_run_ids"] = []
	meta["endless_records"] = records
	next_save["meta"] = meta
	return next_save


func _commit(data: Dictionary, payload: Dictionary = {}) -> Dictionary:
	var saved := ChallengeSaveService.save_to_path(save_path, data)
	if not bool(saved.get("ok", false)):
		return _result(false, data, String(saved.get("error", "save_failed")))
	var result := _result(true, data)
	for key in payload:
		result[key] = payload[key]
	return result


func _active_run(save_data: Dictionary) -> Dictionary:
	var value: Variant = save_data.get("active_run")
	if not value is Dictionary:
		return {}
	return (value as Dictionary).duplicate(true)


func _battle_identity_error(run: Dictionary, battle: Dictionary) -> String:
	if String(battle.get("battle_attempt_id", "")) != String(run.get("current_battle_attempt_id", "")):
		return "battle_attempt_identity_mismatch"
	if int(battle.get("stage_index", -1)) != int(run.get("stage_index", -2)):
		return "battle_stage_identity_mismatch"
	if String(battle.get("encounter_instance_id", "")) != String(
		run.get("current_encounter_instance_id", "")
	):
		return "battle_encounter_identity_mismatch"
	return ""


func _route_for_run(run: Dictionary) -> Dictionary:
	if String(run.get("mode", "")) == "endless":
		return _endless_config.duplicate(true)
	return (
		_route_defs.get(String(run.get("route_id", "")), {}) as Dictionary
	).duplicate(true)


func _recipe_subset(recipe_ids: Array[String]) -> Dictionary:
	var source: Dictionary = _recipe_config.get("recipes", {})
	var result := {}
	for recipe_id in recipe_ids:
		if source.has(recipe_id) and source[recipe_id] is Dictionary:
			result[recipe_id] = (source[recipe_id] as Dictionary).duplicate(true)
	return result


func _ensure_configured() -> void:
	if _recipe_config.is_empty():
		_recipe_config = _load_json(RECIPE_CONFIG_PATH)
	if _encounter_defs.is_empty():
		_encounter_defs = _load_json(ENCOUNTER_CONFIG_PATH).get("encounters", {})
	if _route_defs.is_empty():
		_route_defs = _load_json(ROUTE_CONFIG_PATH).get("routes", {})
	if _upgrade_defs.is_empty():
		_upgrade_defs = _load_json(UPGRADE_CONFIG_PATH).get("upgrades", {})
	if _research_tree.is_empty():
		_research_tree = _load_json(RESEARCH_TREE_PATH)
	if _endless_config.is_empty():
		_endless_config = _load_json(ENDLESS_CONFIG_PATH)
	if _mastery_defs.is_empty():
		_mastery_defs = _load_json(MASTERY_CONFIG_PATH).get("masteries", {})


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _first_error(result: Dictionary, fallback: String) -> String:
	var errors: Array = result.get("errors", [])
	return String(errors[0]) if not errors.is_empty() else fallback


func _result(applied: bool, data: Dictionary, error: String = "") -> Dictionary:
	var result := {
		"applied": applied,
		"save_data": data.duplicate(true)
	}
	if not error.is_empty():
		result["error"] = error
	return result
