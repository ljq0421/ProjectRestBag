class_name Stage11PlaytestFixtureService
extends RefCounted

const SaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const TelemetryService = preload(
	"res://scripts/challenge/stage11_playtest_telemetry_service.gd"
)

const RECIPE_PATH := "res://doc/challenge/challenge_recipes.json"
const MANIFEST_PATH := "res://doc/challenge/recipe_progression_manifest.json"
const TREE_PATH := "res://doc/challenge/research_tree.json"
const ROUTE_PATH := "res://doc/challenge/standard_run.json"

const PROFILE_ORDER := ["P01", "P02", "P03", "P04", "P05", "P06"]
const PROFILES := {
	"P01": {
		"cohort": "new",
		"target_recipe_count": 6,
		"focus": "从新档到第一次研究解锁"
	},
	"P02": {
		"cohort": "new",
		"target_recipe_count": 6,
		"focus": "从新档到第一次研究解锁"
	},
	"P03": {
		"cohort": "mid",
		"target_recipe_count": 30,
		"focus": "使用 30 配方收藏完成路线 A/B"
	},
	"P04": {
		"cohort": "mid",
		"target_recipe_count": 64,
		"focus": "使用 64 配方收藏完成路线 A/B"
	},
	"P05": {
		"cohort": "late",
		"target_recipe_count": 112,
		"focus": "使用 112 配方收藏挑战路线 C 与无尽"
	},
	"P06": {
		"cohort": "late",
		"target_recipe_count": 166,
		"focus": "使用完整收藏挑战路线 C 与无尽"
	}
}

var _telemetry = TelemetryService.new()


func profile_ids() -> Array[String]:
	var result: Array[String] = []
	for value in PROFILE_ORDER:
		result.append(String(value))
	return result


func profile_definition(profile_id: String) -> Dictionary:
	return (PROFILES.get(profile_id, {}) as Dictionary).duplicate(true)


func build_fixture(profile_id: String) -> Dictionary:
	if not PROFILES.has(profile_id):
		return {}
	var profile: Dictionary = PROFILES[profile_id]
	var recipe_config: Dictionary = _json(RECIPE_PATH)
	var manifest: Dictionary = _json(MANIFEST_PATH)
	var tree: Dictionary = _json(TREE_PATH)
	var routes: Dictionary = _json(ROUTE_PATH).get("routes", {})
	var target_count: int = int(profile.get("target_recipe_count", 6))
	var recipe_ids: Array[String] = _recipe_pool(
		target_count,
		recipe_config.get("starter_recipe_ids", []),
		manifest.get("recipes", {})
	)
	var save: Dictionary = SaveService.empty_save()
	var meta: Dictionary = save.get("meta", {})
	meta["unlocked_recipe_ids"] = recipe_ids.duplicate()
	meta["active_menu_recipe_ids"] = _menu_for_profile(
		String(profile.get("cohort", "new")),
		recipe_ids,
		routes,
		recipe_config.get("starter_recipe_ids", [])
	)
	meta["revealed_research_node_ids"] = _revealed_nodes(recipe_ids, tree)
	meta["research_points"] = 0 if target_count == 6 else 9 if target_count <= 64 else 24
	if target_count > 6:
		meta["route_first_clear_ids"] = ["standard_short_chain"]
		meta["unlocked_route_ids"] = ["standard_short_chain", "flavor_texture_route"]
		meta["onboarding"] = _completed_onboarding()
	if target_count >= 112:
		meta["route_first_clear_ids"] = [
			"standard_short_chain", "flavor_texture_route"
		]
		meta["unlocked_route_ids"] = [
			"standard_short_chain", "flavor_texture_route", "grand_composition_route"
		]
		meta["endless_records"] = {
			"unlocked": true,
			"best_floor": 10,
			"best_snapshot": {},
			"last_run_snapshot": {},
			"total_runs": 1,
			"standard_completion_count": 2,
			"standard_completion_run_ids": ["fixture:a", "fixture:b"]
		}
	meta = _telemetry.begin(meta, profile_id, String(profile.get("cohort", "")))
	meta = _telemetry.record(meta, "fixture_created", {
		"target_recipe_count": target_count,
		"focus": String(profile.get("focus", ""))
	})
	save["meta"] = meta
	return save


func _recipe_pool(
	target_count: int,
	starter_values: Array,
	manifest_recipes: Dictionary
) -> Array[String]:
	var result: Array[String] = []
	for value in starter_values:
		var recipe_id := String(value)
		if not recipe_id.is_empty() and not result.has(recipe_id):
			result.append(recipe_id)
	if target_count <= result.size():
		return result.slice(0, target_count)
	var allowed_batches := ["baseline"]
	if target_count >= 30:
		allowed_batches.append("A")
	if target_count >= 64:
		allowed_batches.append("B")
	if target_count >= 112:
		allowed_batches.append("C")
	if target_count >= 166:
		allowed_batches.append("D")
	for recipe_id_value in manifest_recipes:
		var recipe_id := String(recipe_id_value)
		var entry: Dictionary = manifest_recipes.get(recipe_id, {})
		if (
			allowed_batches.has(String(entry.get("migration_batch", "")))
			and not result.has(recipe_id)
		):
			result.append(recipe_id)
	return result.slice(0, mini(target_count, result.size()))


func _menu_for_profile(
	cohort: String,
	recipe_ids: Array[String],
	routes: Dictionary,
	starter_values: Array
) -> Array[String]:
	if cohort == "new":
		return _string_array(starter_values)
	var route_id := "flavor_texture_route" if cohort == "mid" else "grand_composition_route"
	var route: Dictionary = routes.get(route_id, {})
	var menus: Array = route.get("validation_menus", [])
	for reverse_index in range(menus.size()):
		var menu := _string_array(menus[menus.size() - 1 - reverse_index])
		if menu.size() < 4 or menu.size() > 8:
			continue
		var valid := true
		for recipe_id in menu:
			if not recipe_ids.has(recipe_id):
				valid = false
				break
		if valid:
			return menu
	return _string_array(starter_values)


func _revealed_nodes(recipe_ids: Array[String], tree: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for node_id_value in (tree.get("nodes", {}) as Dictionary):
		var node_id := String(node_id_value)
		var node: Dictionary = (tree.get("nodes", {}) as Dictionary).get(node_id, {})
		for unlock_value in node.get("unlocks", []):
			if (
				unlock_value is Dictionary
				and String((unlock_value as Dictionary).get("type", "")) == "recipe"
				and recipe_ids.has(String((unlock_value as Dictionary).get("id", "")))
			):
				result.append(node_id)
				break
	return result


func _completed_onboarding() -> Dictionary:
	return {
		"version": 2,
		"status": "completed",
		"step_id": "complete",
		"completed_step_ids": [
			"boss_brief", "place_recipe", "rotate_recipe", "read_risk",
			"start_battle", "observe_battle", "read_report", "rearrange", "complete"
		],
		"pre_battle_draft_fingerprint": "",
		"seen_stage_two_hint_ids": [
			"five_stage_route", "upgrade_choice", "upgrade_prediction",
			"completion_reward", "research_unlock", "next_run_recipe"
		]
	}


func _json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func _string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values:
			var text := String(value)
			if not text.is_empty() and not result.has(text):
				result.append(text)
	return result
