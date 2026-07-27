class_name GameState
extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const TutorialProgress = preload("res://scripts/tutorial_progress.gd")
const TaskService = preload("res://scripts/task_service.gd")
const DeviceGrowthService = preload("res://scripts/device_growth_service.gd")
const RecipeGrowthService = preload("res://scripts/recipe_growth_service.gd")
const StarProgressionService = preload("res://scripts/star_progression_service.gd")
const ShowcaseRegionService = preload("res://scripts/showcase_region_service.gd")
const ShowcaseExpansionService = preload("res://scripts/showcase_expansion_service.gd")
const CoreFeatureUnlockService = preload("res://scripts/core_feature_unlock_service.gd")

const INITIAL_COINS := 120
const INITIAL_REPUTATION := 0
const INITIAL_LEVEL := 0
const SAVE_VERSION := 1
const TUTORIAL_GUIDE_CONTENT_VERSION := 2
const MAX_LOG_ENTRIES := 20
const MAX_RECENT_SHOWCASE_SALES := 30
const MAX_CONCURRENT_RECIPE_BATCHES := 1
const DISPLAY_SLOT_COUNT := 168
const DISPLAY_GRID_ROWS := 12
const DISPLAY_GRID_COLUMNS := 14
const SHOWCASE_UNLOCKED_ROW_MIN := 5
const SHOWCASE_UNLOCKED_ROW_MAX := 8
const SHOWCASE_UNLOCKED_COLUMN_MIN := 6
const SHOWCASE_UNLOCKED_COLUMN_MAX := 9
const DEFAULT_SHOWCASE_UNLOCKED_BOUNDS := {
	"min_row": SHOWCASE_UNLOCKED_ROW_MIN,
	"max_row": SHOWCASE_UNLOCKED_ROW_MAX,
	"min_column": SHOWCASE_UNLOCKED_COLUMN_MIN,
	"max_column": SHOWCASE_UNLOCKED_COLUMN_MAX
}
const SHOWCASE_PROP_UNLOCK_LEVELS := {
	"cake_stand": 2,
	"chilled_case": 3,
	"retro_tray": 4,
	"sample_sign": 4,
	"gift_corner": 5
}
const SHOWCASE_PROP_ORDER := ["cake_stand", "chilled_case", "retro_tray", "sample_sign", "gift_corner"]
const SHOWCASE_THEME_UNLOCK_LEVELS := {"summer": 2, "retro": 3, "tea": 5}
const SHOWCASE_THEME_ORDER := ["summer", "retro", "tea"]
const DISPLAY_PROP_SHAPES := {
	"cake_stand": {"prop_id": "cake_stand", "name": "蛋糕架", "cells": [Vector2i(0, 0)]},
	"chilled_case": {"prop_id": "chilled_case", "name": "冷藏展示柜", "cells": [Vector2i(0, 0), Vector2i(0, 1)]},
	"retro_tray": {"prop_id": "retro_tray", "name": "复古托盘", "cells": [Vector2i(0, 0)]},
	"sample_sign": {"prop_id": "sample_sign", "name": "试吃牌", "cells": [Vector2i(0, 0)]},
	"gift_corner": {"prop_id": "gift_corner", "name": "礼盒角", "cells": [Vector2i(0, 0)]}
}

var version: int = SAVE_VERSION
var coins: int = INITIAL_COINS
var reputation: int = INITIAL_REPUTATION
var _shop_level: int = INITIAL_LEVEL
var level: int:
	get:
		return _shop_level
	set(value):
		_shop_level = value
var shop_level: int:
	get:
		return _shop_level
	set(value):
		_shop_level = value
var ingredient_inventory: Dictionary = {}
var product_inventory: Dictionary = {}
var tool_inventory: Dictionary = {}
var equipped_accelerators: Dictionary = {}
var unlocked_tools: Array[String] = []
var unlocked_devices: Array[String] = []
var completed_tasks: Array[String] = []
var claimed_tasks: Array[String] = []
var task_progress: Dictionary = {}
var tutorial_guide_step: String = "purchase"
var tutorial_guide_finished: bool = false
var tutorial_guide_skipped: bool = false
var tutorial_guide_dialogue_acknowledged_step: String = ""
var tutorial_guide_dismissed_step: String = ""
var tutorial_guide_content_version: int = TUTORIAL_GUIDE_CONTENT_VERSION
var tutorial_guide_harvested_ids: Array[String] = []
var tutorial_guide_showcase_moved: bool = false
var tutorial_guide_showcase_rotated: bool = false
var daily_task_day_key := ""
var daily_task_selected_ids: Array[String] = []
var pending_notifications: Array[Dictionary] = []
var production_slots: Array = []
var production_slot_unlocks: Dictionary = {}
var production_bag_page_unlocks: Dictionary = {}
var display_slots: Array = []

# ========== 新增：橱窗摆放数据 ==========
# key: recipe_id (String)
# value: { "cells": Array[Vector2i], "stock": int, "fresh_stock": int, "carried_stock": int }
var display_items: Dictionary = {}
var display_props: Dictionary = {}
var showcase_theme_id: String = ""
var showcase_unlocked_bounds: Dictionary = DEFAULT_SHOWCASE_UNLOCKED_BOUNDS.duplicate(true)
var showcase_unlocked_cells: Array[Vector2i] = []
var unlocked_showcase_prop_ids: Array[String] = []
var unlocked_showcase_theme_ids: Array[String] = []
var device_growth: Dictionary = {}
var recipe_growth: Dictionary = {}
var recipe_production_queue: Array = []
var ingredient_processing_queue: Array = []
var production_ready_recipe_records: Dictionary = {}
var recipe_starlight_total: int = 0
var recipe_starlight_available: int = 0
var claimed_starlight_rewards: Array[String] = []
var feature_unlocks: Dictionary = {}
var core_feature_unlocks: Dictionary = {}
var core_unlock_progress: Dictionary = {}
var automation_unlocks: Dictionary = {}
var automation_upgrades: Dictionary = {}
# Legacy field retained only so old saves and older callers can be migrated.
var managed_production_slots: Array[String] = []
var managed_production_sites: Array[String] = []
var kitchen_automation_rules: Array[Dictionary] = []
var kitchen_rule_next_id: int = 1
var automation_paused: bool = false
var automation_resume_floor_unix: int = 0
var automation_last_settled_unix: int = 0
var pending_automation_report: Dictionary = {}
var recent_showcase_sales: Array[Dictionary] = []
var recent_showcase_round_reports: Array = []
var showcase_seed: int = 20260714
var business_round_id: int = 1
var active_business_round: Dictionary = {}
var pending_showcase_settlement: Dictionary = {}
var applied_showcase_settlement_ids: Array[String] = []
var pending_showcase_challenge: Dictionary = {}
var completed_showcase_challenge_ids: Array[String] = []
var contract_best_tiers: Dictionary = {}
var store_rating_points: int = 0
var applied_contract_report_ids: Array[String] = []
var showcase_contract_choices: Array[Dictionary] = []

var unlocked_recipes: Array[String] = []
var ingredient_purchase_unlocks: Array[String] = []
var ingredient_process_unlocks: Array[String] = []
var discovered_hints: Dictionary = {}
var research_hint_progress: Dictionary = {}
var latest_research_hint_recipe_id: String = ""
var feedback_log: Array[String] = []
var business_runs: int = 0
var last_saved_at_unix: int = 0
var offline_ready_count: int = 0
var logs: Array[String]:
	get:
		return feedback_log
	set(value):
		feedback_log = _sanitize_feedback_log(value)


static func new_game():
	var script: GDScript = load("res://scripts/game_state.gd") as GDScript
	var state = script.new()
	state.version = SAVE_VERSION
	state.coins = INITIAL_COINS
	state.reputation = INITIAL_REPUTATION
	state.level = INITIAL_LEVEL
	state.ingredient_inventory = {"spring_water": 10}
	state.product_inventory = {}
	state.tool_inventory = {}
	state.equipped_accelerators = {}
	state.unlocked_tools.clear()
	state.unlocked_devices.clear()
	state.completed_tasks.clear()
	state.claimed_tasks.clear()
	state.task_progress = {}
	state.tutorial_guide_step = "purchase"
	state.tutorial_guide_finished = false
	state.tutorial_guide_skipped = false
	state.tutorial_guide_dialogue_acknowledged_step = ""
	state.tutorial_guide_dismissed_step = ""
	state.tutorial_guide_harvested_ids.clear()
	state.tutorial_guide_showcase_moved = false
	state.tutorial_guide_showcase_rotated = false
	state.daily_task_day_key = ""
	state.daily_task_selected_ids.clear()
	state.pending_notifications.clear()
	state.production_slots = []
	state.production_slot_unlocks = _default_production_unlocks()
	state.production_bag_page_unlocks = _default_production_unlocks()
	state.display_slots = []
	state.display_items = {}  # 新增：初始化橱窗数据为空
	state.display_props = {}
	state.showcase_theme_id = ""
	state.showcase_unlocked_bounds = DEFAULT_SHOWCASE_UNLOCKED_BOUNDS.duplicate(true)
	state.showcase_unlocked_cells = state._showcase_cells_from_bounds(state.showcase_unlocked_bounds)
	state.unlocked_showcase_prop_ids.clear()
	state.unlocked_showcase_theme_ids.clear()
	state.device_growth = {}
	state.recipe_growth = {}
	state.recipe_production_queue = []
	state.ingredient_processing_queue = []
	state.production_ready_recipe_records = {}
	state.recipe_starlight_total = 0
	state.recipe_starlight_available = 0
	state.claimed_starlight_rewards.clear()
	state.feature_unlocks = {}
	state.core_feature_unlocks = CoreFeatureUnlockService.default_unlocks()
	state.core_unlock_progress = {}
	state.automation_unlocks = {}
	state.automation_upgrades = {}
	state.managed_production_slots.clear()
	state.managed_production_sites.clear()
	state.kitchen_automation_rules.clear()
	state.kitchen_rule_next_id = 1
	state.automation_paused = false
	state.automation_resume_floor_unix = 0
	state.automation_last_settled_unix = 0
	state.pending_automation_report = {}
	state.recent_showcase_sales.clear()
	state.recent_showcase_round_reports.clear()
	state.showcase_seed = 20260714
	state.business_round_id = 1
	state.active_business_round = {}
	state.pending_showcase_settlement = {}
	state.applied_showcase_settlement_ids.clear()
	state.pending_showcase_challenge = {}
	state.completed_showcase_challenge_ids.clear()
	state.contract_best_tiers = {}
	state.store_rating_points = 0
	state.applied_contract_report_ids.clear()
	state.showcase_contract_choices.clear()
	state.unlocked_recipes.clear()
	state.ingredient_purchase_unlocks.clear()
	state.ingredient_process_unlocks.clear()
	state.discovered_hints = {}
	state.research_hint_progress = {}
	state.latest_research_hint_recipe_id = ""
	state.feedback_log.clear()
	state.business_runs = 0
	state.last_saved_at_unix = 0
	state.offline_ready_count = 0
	state._resize_display_slots(DISPLAY_SLOT_COUNT)
	state.add_log("new_game")
	return state


static func from_dict(data: Dictionary):
	var state = new_game()
	var has_core_feature_data := data.has("core_feature_unlocks")
	var legacy_tutorial_step_evidence := String(data.get("tutorial_guide_step", "purchase"))
	state.version = maxi(1, int(data.get("version", SAVE_VERSION)))
	state.coins = maxi(0, int(data.get("coins", state.coins)))
	state.reputation = maxi(0, int(data.get("reputation", state.reputation)))
	var loaded_level: int = int(data.get("shop_level", data.get("level", state.level)))
	state.level = maxi(0, loaded_level)
	state.ingredient_inventory = state._sanitize_inventory(data.get("ingredient_inventory", {}))
	state.product_inventory = state._sanitize_inventory(data.get("product_inventory", {}))
	state.tool_inventory = state._sanitize_tool_inventory(data.get("tool_inventory", {}))
	state.equipped_accelerators = state._sanitize_equipped_accelerators(data.get("equipped_accelerators", {}))
	state.unlocked_tools = state._sanitize_unlocked_tools(data.get("unlocked_tools", state.unlocked_tools))
	state.unlocked_devices = state._sanitize_unlocked_devices(data.get("unlocked_devices", data.get("unlocked_tools", state.unlocked_devices)))
	state.device_growth = state._sanitize_device_growth(data.get("device_growth", {}))
	state.completed_tasks = state._sanitize_string_array(data.get("completed_tasks", []))
	if data.has("claimed_tasks"):
		state.claimed_tasks = state._sanitize_string_array(data.get("claimed_tasks", []))
	else:
		state.claimed_tasks = state.completed_tasks.duplicate()
	state.task_progress = state._sanitize_task_progress(data.get("task_progress", {}))
	var has_tutorial_guide_data := data.has("tutorial_guide_step") or data.has("tutorial_guide_finished") or data.has("tutorial_guide_skipped")
	if has_tutorial_guide_data:
		state.tutorial_guide_step = TutorialProgress.sanitize_step(String(data.get("tutorial_guide_step", "purchase")))
		state.tutorial_guide_finished = bool(data.get("tutorial_guide_finished", false))
		state.tutorial_guide_skipped = bool(data.get("tutorial_guide_skipped", false))
		state.tutorial_guide_dialogue_acknowledged_step = String(data.get("tutorial_guide_dialogue_acknowledged_step", ""))
		state.tutorial_guide_dismissed_step = String(data.get("tutorial_guide_dismissed_step", ""))
		state.tutorial_guide_harvested_ids = state._sanitize_string_array(data.get("tutorial_guide_harvested_ids", []))
		state.tutorial_guide_showcase_moved = bool(data.get("tutorial_guide_showcase_moved", false))
		state.tutorial_guide_showcase_rotated = bool(data.get("tutorial_guide_showcase_rotated", false))
		var loaded_tutorial_content_version := int(data.get("tutorial_guide_content_version", 0))
		if loaded_tutorial_content_version < TUTORIAL_GUIDE_CONTENT_VERSION \
				and state.tutorial_guide_finished \
				and not state.tutorial_guide_skipped:
			state.tutorial_guide_step = TutorialProgress.STEP_PURCHASE
			state.tutorial_guide_finished = false
			state.tutorial_guide_dialogue_acknowledged_step = ""
			state.tutorial_guide_dismissed_step = ""
			state.tutorial_guide_harvested_ids.clear()
			state.tutorial_guide_showcase_moved = false
			state.tutorial_guide_showcase_rotated = false
		state.tutorial_guide_content_version = TUTORIAL_GUIDE_CONTENT_VERSION
	else:
		state.tutorial_guide_skipped = true
	state.daily_task_day_key = String(data.get("daily_task_day_key", ""))
	state.daily_task_selected_ids = state._sanitize_string_array(data.get("daily_task_selected_ids", []))
	state.pending_notifications = state._sanitize_notifications(data.get("pending_notifications", []))
	state.production_slots = state._sanitize_production_slots(data.get("production_slots", []))
	state.production_slot_unlocks = state._sanitize_production_unlocks(data.get("production_slot_unlocks", {}), 8)
	state.production_bag_page_unlocks = state._sanitize_production_unlocks(data.get("production_bag_page_unlocks", {}), 5)
	state.unlocked_recipes = state._sanitize_unlocked_recipes(data.get("unlocked_recipes", []))
	state.ingredient_purchase_unlocks = state._sanitize_ingredient_purchase_unlocks(data.get("ingredient_purchase_unlocks", []))
	state.ingredient_process_unlocks = state._sanitize_ingredient_process_unlocks(data.get("ingredient_process_unlocks", data.get("ingredient_purchase_unlocks", [])))
	state.discovered_hints = state._sanitize_dictionary(data.get("discovered_hints", {}))
	state.research_hint_progress = state._sanitize_research_hint_progress(data.get("research_hint_progress", {}))
	state.latest_research_hint_recipe_id = String(data.get("latest_research_hint_recipe_id", ""))
	if not state.research_hint_progress.has(state.latest_research_hint_recipe_id):
		state.latest_research_hint_recipe_id = ""
	state.feedback_log = state._sanitize_feedback_log(data.get("feedback_log", data.get("logs", state.feedback_log)))
	state.business_runs = maxi(0, int(data.get("business_runs", 0)))
	state.last_saved_at_unix = maxi(0, int(data.get("last_saved_at_unix", 0)))
	state.offline_ready_count = maxi(0, int(data.get("offline_ready_count", 0)))

	state.display_slots = state._sanitize_display_slots(data.get("display_slots", []), DISPLAY_SLOT_COUNT)
	if data.has("showcase_unlocked_cells"):
		state.set_showcase_unlocked_cells(data.get("showcase_unlocked_cells", []))
	else:
		state.set_showcase_unlocked_bounds(data.get("showcase_unlocked_bounds", DEFAULT_SHOWCASE_UNLOCKED_BOUNDS))
	state.unlocked_showcase_prop_ids = state._sanitize_string_array(data.get("unlocked_showcase_prop_ids", []))
	state.unlocked_showcase_theme_ids = state._sanitize_string_array(data.get("unlocked_showcase_theme_ids", []))
	state.sync_showcase_collection_unlocks()
	state.display_items = state._sanitize_display_items(data.get("display_items", {}))  # 新增：加载橱窗数据
	state.display_props = state._sanitize_display_props(data.get("display_props", {}))
	state.showcase_theme_id = String(data.get("showcase_theme_id", ""))
	state.recipe_growth = state._sanitize_recipe_growth(data.get("recipe_growth", {}))
	state.recipe_production_queue = state._sanitize_recipe_production_queue(data.get("recipe_production_queue", []))
	state.ingredient_processing_queue = state._sanitize_ingredient_processing_queue(
		data.get("ingredient_processing_queue", [])
	)
	state.production_ready_recipe_records = state._sanitize_production_ready_recipe_records(
		data.get("production_ready_recipe_records", {})
	)
	for recipe_id_value: Variant in state.production_ready_recipe_records.keys():
		state.prune_recipe_production_ready_record(String(recipe_id_value))
	state.recipe_starlight_total = maxi(0, int(data.get("recipe_starlight_total", 0)))
	state.recipe_starlight_available = clampi(int(data.get("recipe_starlight_available", 0)), 0, state.recipe_starlight_total)
	state.claimed_starlight_rewards = state._sanitize_string_array(data.get("claimed_starlight_rewards", []))
	state.feature_unlocks = state._sanitize_dictionary(data.get("feature_unlocks", {}))
	if state.completed_tasks.has("feature_harvest_all"):
		state.feature_unlocks["harvest_all"] = true
	if state.completed_tasks.has("feature_restock_all"):
		state.feature_unlocks["research_bulk_restock"] = true
	if state.completed_tasks.has("feature_make_all"):
		state.feature_unlocks["research_make_all"] = true
	if state.completed_tasks.has("feature_list_all"):
		state.feature_unlocks["research_list_all"] = true
	state.core_feature_unlocks = CoreFeatureUnlockService.sanitize_unlocks(data.get("core_feature_unlocks", {}))
	state.core_unlock_progress = state._sanitize_dictionary(data.get("core_unlock_progress", {}))
	state.automation_unlocks = state._sanitize_dictionary(data.get("automation_unlocks", {}))
	state.automation_upgrades = state._sanitize_dictionary(data.get("automation_upgrades", {}))
	state.managed_production_slots = state._sanitize_managed_production_slots(data.get("managed_production_slots", []))
	if data.has("managed_production_sites"):
		state.managed_production_sites = state._sanitize_managed_production_sites(data.get("managed_production_sites", []))
	else:
		state.managed_production_sites = state._managed_sites_from_legacy_slots(state.managed_production_slots)
	state.pending_automation_report = state._sanitize_dictionary(data.get("pending_automation_report", {}))
	state.recent_showcase_sales = state._sanitize_recent_showcase_sales(data.get("recent_showcase_sales", []))
	state.recent_showcase_round_reports = state._sanitize_showcase_round_reports(data.get("recent_showcase_round_reports", []))
	state.showcase_seed = maxi(1, int(data.get("showcase_seed", 20260714)))
	state.business_round_id = maxi(1, int(data.get("business_round_id", 1)))
	state.active_business_round = state._sanitize_active_business_round(data.get("active_business_round", {}))
	state.pending_showcase_settlement = state._sanitize_dictionary(data.get("pending_showcase_settlement", {}))
	state.applied_showcase_settlement_ids = state._sanitize_string_array(data.get("applied_showcase_settlement_ids", []))
	state.pending_showcase_challenge = state._sanitize_dictionary(data.get("pending_showcase_challenge", {}))
	state.completed_showcase_challenge_ids = state._sanitize_string_array(data.get("completed_showcase_challenge_ids", []))
	state.contract_best_tiers = state._sanitize_dictionary(data.get("contract_best_tiers", {}))
	state.store_rating_points = maxi(0, int(data.get("store_rating_points", 0)))
	state.applied_contract_report_ids = state._sanitize_string_array(data.get("applied_contract_report_ids", []))
	state.showcase_contract_choices = state._sanitize_dictionary_array(data.get("showcase_contract_choices", []))
	state.kitchen_rule_next_id = maxi(1, int(data.get("kitchen_rule_next_id", 1)))
	state.kitchen_automation_rules = state._sanitize_kitchen_automation_rules(data.get("kitchen_automation_rules", []))
	state.automation_paused = bool(data.get("automation_paused", false))
	state.automation_resume_floor_unix = maxi(0, int(data.get("automation_resume_floor_unix", 0)))
	state.automation_last_settled_unix = maxi(0, int(data.get("automation_last_settled_unix", 0)))
	if not has_core_feature_data:
		state._reconstruct_core_feature_unlocks_from_legacy(data, legacy_tutorial_step_evidence, has_tutorial_guide_data)
	if state.recipe_starlight_total > 0 or not state.claimed_starlight_rewards.is_empty():
		state.core_feature_unlocks[CoreFeatureUnlockService.STARLIGHT] = true
	state.repair_core_feature_prerequisites()
	if state.is_core_feature_unlocked(CoreFeatureUnlockService.RESEARCH):
		state.unlock_device("round_pot")
	state._purge_removed_tutorial_task_state()
	return state

# ========== 原有库存方法保留 ==========
func add_ingredient(item_id: String, amount: int) -> bool:
	return _add_inventory(ingredient_inventory, item_id, amount)


func remove_ingredient(item_id: String, amount: int) -> bool:
	return _remove_inventory(ingredient_inventory, item_id, amount)


func has_ingredient(item_id: String, amount: int = 1) -> bool:
	return _has_inventory(ingredient_inventory, item_id, amount)


func get_ingredient_count(item_id: String) -> int:
	return _get_inventory_count(ingredient_inventory, item_id)


func add_product(recipe_id: String, amount: int) -> bool:
	return _add_inventory(product_inventory, recipe_id, amount)


func remove_product(recipe_id: String, amount: int) -> bool:
	if not _remove_inventory(product_inventory, recipe_id, amount):
		return false
	prune_recipe_production_ready_record(recipe_id)
	return true


func has_product(recipe_id: String, amount: int = 1) -> bool:
	return _has_inventory(product_inventory, recipe_id, amount)


func get_product_count(recipe_id: String) -> int:
	return _get_inventory_count(product_inventory, recipe_id)


func add_tool(tool_id: String, amount: int) -> bool:
	if not _tools().has(tool_id):
		return false

	return _add_inventory(tool_inventory, tool_id, amount)


func remove_tool(tool_id: String, amount: int) -> bool:
	if not _tools().has(tool_id):
		return false

	return _remove_inventory(tool_inventory, tool_id, amount)


func get_tool_count(tool_id: String) -> int:
	return _get_inventory_count(tool_inventory, tool_id)


func unlock_tool(tool_id: String) -> bool:
	if not _tools().has(tool_id):
		return false
	if unlocked_tools.has(tool_id):
		return false

	unlocked_tools.append(tool_id)
	add_log("tool_unlocked:%s" % tool_id)
	return true


func is_tool_unlocked(tool_id: String) -> bool:
	var tools: Dictionary = _tools()
	if not tools.has(tool_id):
		return false

	var tool: Dictionary = tools[tool_id]
	return int(tool.get("unlock_level", 1)) <= level or unlocked_tools.has(tool_id)


func unlock_device(device_id: String) -> bool:
	if not _devices().has(device_id):
		return false
	if unlocked_devices.has(device_id):
		return false

	unlocked_devices.append(device_id)
	if DeviceGrowthService.supports_growth(device_id, _devices()):
		device_growth[device_id] = DeviceGrowthService.default_state()
	add_log("device_unlocked:%s" % device_id)
	return true


func is_device_unlocked(device_id: String) -> bool:
	var devices: Dictionary = _devices()
	if not devices.has(device_id):
		return false

	var device: Dictionary = devices[device_id]
	return int(device.get("unlock_level", 1)) <= level or unlocked_devices.has(device_id)


func get_device_growth(device_id: String) -> Dictionary:
	var devices := _devices()
	if not DeviceGrowthService.supports_growth(device_id, devices):
		return {
			"status": "unsupported",
			"error": "unsupported",
			"device_id": device_id
		}
	if not is_device_unlocked(device_id):
		var locked := DeviceGrowthService.default_state()
		locked["status"] = "locked"
		locked["error"] = "locked"
		locked["device_id"] = device_id
		return locked
	var stored_growth: Dictionary = device_growth.get(device_id, DeviceGrowthService.default_state())
	var result: Dictionary = DeviceGrowthService.sanitize_state(stored_growth)
	result["status"] = "ok"
	result["error"] = ""
	result["device_id"] = device_id
	return result


func device_growth_quote(device_id: String) -> Dictionary:
	return DeviceGrowthService.upgrade_quote(
		device_id,
		get_device_growth(device_id),
		coins,
		is_device_unlocked(device_id),
		_devices()
	)


func upgrade_device_growth(device_id: String) -> Dictionary:
	var quote := device_growth_quote(device_id)
	if not bool(quote.get("can_upgrade", false)):
		quote["ok"] = false
		return quote
	_ensure_device_growth(device_id)
	var cost := int(quote.get("coin_cost", 0))
	var next_level := int(quote.get("next_level", 1))
	if coins < cost:
		quote["ok"] = false
		quote["error"] = "requirements_not_met"
		quote["missing_coins"] = cost - coins
		return quote
	coins -= cost
	var growth: Dictionary = device_growth[device_id]
	growth["level"] = next_level
	device_growth[device_id] = DeviceGrowthService.sanitize_state(growth)
	var promoted_recipe_count := 0
	var recipes := _recipes()
	for recipe_id_value in unlocked_recipes:
		var recipe_id := String(recipe_id_value)
		if String(recipes.get(recipe_id, {}).get("device", "")) != device_id:
			continue
		var before_level := int(get_recipe_growth(recipe_id).get("mastery_level", 0))
		var updated_growth := _update_recipe_growth(recipe_id, true, "device")
		if int(updated_growth.get("mastery_level", 0)) > before_level:
			promoted_recipe_count += 1
	var result := device_growth_quote(device_id)
	result["ok"] = true
	result["upgraded_level"] = next_level
	result["spent_coins"] = cost
	result["promoted_recipe_count"] = promoted_recipe_count
	var waiting_recipe_count := _waiting_recipe_count_for_device(device_id)
	result["waiting_recipe_count"] = waiting_recipe_count
	var device_name := String(_devices().get(device_id, {}).get("name", device_id))
	var cap_name := RecipeGrowthService.mastery_name(DeviceGrowthService.stage_cap(next_level))
	enqueue_notification(
		"%s 已升至 L%d" % [device_name, next_level],
		"%s培养已开放。%d 道配方立即晋级，%d 道仍等待更高设备等级。" % [cap_name, promoted_recipe_count, waiting_recipe_count],
		{"kind": "device_growth_upgrade", "device_id": device_id, "level": next_level, "promoted_recipe_count": promoted_recipe_count, "waiting_recipe_count": waiting_recipe_count}
	)
	add_log("device_growth_upgraded:%s:%d" % [device_id, next_level])
	return result


func record_device_research_success(device_id: String) -> Dictionary:
	if not DeviceGrowthService.supports_growth(device_id, _devices()) or not is_device_unlocked(device_id):
		return {"ok": false, "error": "unsupported_or_locked", "device_id": device_id}
	_ensure_device_growth(device_id)
	var growth: Dictionary = device_growth[device_id]
	growth["research_count"] = maxi(0, int(growth.get("research_count", 0))) + 1
	growth["use_count"] = int(growth.get("research_count", 0)) + int(growth.get("production_batch_count", 0))
	device_growth[device_id] = DeviceGrowthService.sanitize_state(growth)
	var result := get_device_growth(device_id)
	result["ok"] = true
	return result


func record_device_production_batches(device_id: String, batches: int) -> Dictionary:
	if batches <= 0 or not DeviceGrowthService.supports_growth(device_id, _devices()) or not is_device_unlocked(device_id):
		return {"ok": false, "error": "unsupported_locked_or_empty", "device_id": device_id}
	_ensure_device_growth(device_id)
	var growth: Dictionary = device_growth[device_id]
	growth["production_batch_count"] = maxi(0, int(growth.get("production_batch_count", 0))) + batches
	growth["use_count"] = int(growth.get("research_count", 0)) + int(growth.get("production_batch_count", 0))
	device_growth[device_id] = DeviceGrowthService.sanitize_state(growth)
	var result := get_device_growth(device_id)
	result["ok"] = true
	return result


func is_automation_unlocked(feature_id: String) -> bool:
	return bool(automation_unlocks.get(feature_id, false))


func is_feature_unlocked(feature_id: String) -> bool:
	return bool(feature_unlocks.get(feature_id, false))


func unlock_feature(feature_id: String) -> bool:
	if feature_id.is_empty() or is_feature_unlocked(feature_id):
		return false
	feature_unlocks[feature_id] = true
	add_log("feature_unlock:%s" % feature_id)
	return true


func is_core_feature_unlocked(feature_id: String) -> bool:
	return CoreFeatureUnlockService.is_unlocked(core_feature_unlocks, feature_id)


func unlock_core_feature(feature_id: String) -> bool:
	if not CoreFeatureUnlockService.unlock(core_feature_unlocks, feature_id):
		return false
	add_log("core_feature_unlock:%s" % feature_id)
	return true


func repair_core_feature_prerequisites() -> bool:
	return CoreFeatureUnlockService.repair_prerequisites(core_feature_unlocks)


func core_feature_locked_reason(feature_id: String) -> String:
	return CoreFeatureUnlockService.locked_reason(core_feature_unlocks, feature_id)


func record_core_unlock_progress(progress_id: String, value: Variant = true) -> bool:
	if progress_id.is_empty() or core_unlock_progress.get(progress_id) == value:
		return false
	core_unlock_progress[progress_id] = value
	return true


func get_core_unlock_progress(progress_id: String, default_value: Variant = null) -> Variant:
	return core_unlock_progress.get(progress_id, default_value)


func _reconstruct_core_feature_unlocks_from_legacy(data: Dictionary, tutorial_step_evidence: String, has_tutorial_data: bool) -> void:
	core_feature_unlocks = CoreFeatureUnlockService.default_unlocks()
	core_unlock_progress["legacy_reconstructed"] = true
	var tutorial_index := TutorialProgress.STEPS.find(TutorialProgress.sanitize_step(tutorial_step_evidence))
	if tutorial_index >= TutorialProgress.STEPS.find(TutorialProgress.STEP_OUTPUT):
		_unlock_core_feature_through(CoreFeatureUnlockService.INVENTORY)
		core_feature_unlocks[CoreFeatureUnlockService.OUTPUT] = true
	if tutorial_index >= TutorialProgress.STEPS.find(TutorialProgress.STEP_RESEARCH):
		_unlock_core_feature_through(CoreFeatureUnlockService.RESEARCH)
	if tutorial_index >= TutorialProgress.STEPS.find(TutorialProgress.STEP_CRAFT):
		_unlock_core_feature_through(CoreFeatureUnlockService.CRAFT)
		core_feature_unlocks[CoreFeatureUnlockService.CATALOG] = true
	if tutorial_index >= TutorialProgress.STEPS.find(TutorialProgress.STEP_LIST):
		_unlock_core_feature_through(CoreFeatureUnlockService.LIST)
	if tutorial_index >= TutorialProgress.STEPS.find(TutorialProgress.STEP_RULEBOOK):
		_unlock_core_feature_through(CoreFeatureUnlockService.RULEBOOK)
	if tutorial_index >= TutorialProgress.STEPS.find(TutorialProgress.STEP_ARRANGE):
		_unlock_core_feature_through(CoreFeatureUnlockService.ARRANGE)
	if tutorial_index >= TutorialProgress.STEPS.find(TutorialProgress.STEP_BUSINESS):
		_unlock_core_feature_through(CoreFeatureUnlockService.BUSINESS)
	if tutorial_index >= TutorialProgress.STEPS.find(TutorialProgress.STEP_STOREFRONT):
		_unlock_core_feature_through(CoreFeatureUnlockService.STOREFRONT_MANAGE)
	if tutorial_index >= TutorialProgress.STEPS.find(TutorialProgress.STEP_COMPLETE):
		_unlock_core_feature_through(CoreFeatureUnlockService.TASK)

	if ingredient_inventory.has("rice_seed") or ingredient_inventory.has("rice") or not production_slots.is_empty():
		_unlock_core_feature_through(CoreFeatureUnlockService.INVENTORY)
		core_feature_unlocks[CoreFeatureUnlockService.OUTPUT] = true
	if unlocked_devices.has("round_pot") or ingredient_inventory.has("rice") or not unlocked_recipes.is_empty():
		_unlock_core_feature_through(CoreFeatureUnlockService.RESEARCH)
	if unlocked_recipes.has(TutorialProgress.TUTORIAL_RECIPE_ID):
		_unlock_core_feature_through(CoreFeatureUnlockService.CRAFT)
		core_feature_unlocks[CoreFeatureUnlockService.CATALOG] = true
	if not product_inventory.is_empty():
		_unlock_core_feature_through(CoreFeatureUnlockService.LIST)
	if not display_items.is_empty() or _legacy_display_slots_have_product():
		_unlock_core_feature_through(CoreFeatureUnlockService.RULEBOOK)
	if tutorial_guide_showcase_moved or tutorial_guide_showcase_rotated:
		_unlock_core_feature_through(CoreFeatureUnlockService.ARRANGE)
	if business_runs > 0 or not active_business_round.is_empty() or not pending_showcase_settlement.is_empty():
		_unlock_core_feature_through(CoreFeatureUnlockService.STOREFRONT_MANAGE)
	if not recent_showcase_round_reports.is_empty() or not recent_showcase_sales.is_empty():
		_unlock_core_feature_through(CoreFeatureUnlockService.STOREFRONT_MANAGE)

	var legacy_had_unrestricted_access := not has_tutorial_data or tutorial_guide_skipped
	if level >= 1 or tutorial_guide_finished or legacy_had_unrestricted_access:
		_unlock_core_feature_through(CoreFeatureUnlockService.TASK)
	if recipe_starlight_total > 0 or not claimed_starlight_rewards.is_empty():
		_unlock_core_feature_through(CoreFeatureUnlockService.STARLIGHT)
	CoreFeatureUnlockService.repair_prerequisites(core_feature_unlocks)


func _unlock_core_feature_through(feature_id: String) -> void:
	for prerequisite_id in CoreFeatureUnlockService.prerequisite_closure(feature_id):
		core_feature_unlocks[prerequisite_id] = true
	core_feature_unlocks[feature_id] = true


func _legacy_display_slots_have_product() -> bool:
	for slot_value: Variant in display_slots:
		if slot_value != null:
			return true
	return false


func _purge_removed_tutorial_task_state() -> void:
	const REMOVED_TUTORIAL_TASK_IDS := [
		"tutorial_l0_first_product",
		"tutorial_l0_open_shop",
		"tutorial_l0_first_business",
	]
	for task_id in REMOVED_TUTORIAL_TASK_IDS:
		completed_tasks.erase(task_id)
		claimed_tasks.erase(task_id)
		task_progress.erase(task_id)
	var retained_notifications: Array[Dictionary] = []
	for notification in pending_notifications:
		if _is_removed_tutorial_notification(notification, REMOVED_TUTORIAL_TASK_IDS):
			continue
		retained_notifications.append(notification)
	pending_notifications = retained_notifications


func _is_removed_tutorial_notification(notification: Dictionary, removed_ids: Array) -> bool:
	var metadata_value: Variant = notification.get("metadata", {})
	var metadata: Dictionary = metadata_value if metadata_value is Dictionary else {}
	var task_id := String(metadata.get("task_id", metadata.get("id", "")))
	if removed_ids.has(task_id):
		return true
	var combined_text := "%s\n%s" % [String(notification.get("title", "")), String(notification.get("body", ""))]
	for marker in ["第一份商品完成", "第一轮营业开始", "完整营业教学完成", "tutorial_l0_"]:
		if combined_text.contains(marker):
			return true
	return false


func unlock_automation(feature_id: String) -> bool:
	if feature_id.is_empty() or is_automation_unlocked(feature_id):
		return false
	automation_unlocks[feature_id] = true
	add_log("automation_unlock:%s" % feature_id)
	return true


func unlock_ingredient_purchase(item_id: String) -> bool:
	if not _is_process_purchase_unlockable(item_id):
		return false
	if ingredient_purchase_unlocks.has(item_id):
		return false

	ingredient_purchase_unlocks.append(item_id)
	add_log("ingredient_purchase_unlocked:%s" % item_id)
	return true


func is_ingredient_purchase_unlocked(item_id: String) -> bool:
	if not _is_process_purchase_unlockable(item_id):
		return false
	return ingredient_purchase_unlocks.has(item_id)


func unlock_ingredient_process(item_id: String) -> bool:
	if not _is_process_unlockable(item_id):
		return false
	if ingredient_process_unlocks.has(item_id):
		return false

	ingredient_process_unlocks.append(item_id)
	add_log("ingredient_process_unlocked:%s" % item_id)
	return true


func is_ingredient_process_unlocked(item_id: String) -> bool:
	if not _is_process_unlockable(item_id):
		return false
	return ingredient_process_unlocks.has(item_id)


func equip_accelerator(target_id: String, tool_id: String) -> bool:
	if not _tool_matches_accelerator_target(tool_id, target_id):
		return false
	if not _tools().has(tool_id):
		return false
	if get_tool_count(tool_id) <= 0:
		return false

	var existing_tool := get_equipped_accelerator(target_id)
	if not existing_tool.is_empty():
		if not unequip_accelerator(target_id):
			return false

	if not _remove_inventory(tool_inventory, tool_id, 1):
		return false

	equipped_accelerators[target_id] = tool_id
	add_log("accelerator_equip:%s:%s" % [target_id, tool_id])
	return true


func unequip_accelerator(target_id: String) -> bool:
	var tool_id := get_equipped_accelerator(target_id)
	if tool_id.is_empty():
		return false

	equipped_accelerators.erase(target_id)
	_add_inventory(tool_inventory, tool_id, 1)
	add_log("accelerator_unequip:%s:%s" % [target_id, tool_id])
	return true


func get_equipped_accelerator(target_id: String) -> String:
	return String(equipped_accelerators.get(target_id, ""))


func set_display_slot(index: int, recipe_id: String) -> bool:
	if index < 0 or index >= display_slots.size():
		return false

	if recipe_id.is_empty():
		display_slots[index] = null
		add_log("display_slot_cleared:%d" % index)
		return true

	if not is_recipe_unlocked(recipe_id):
		return false

	if not has_product(recipe_id):
		return false

	display_slots[index] = recipe_id
	add_log("display_slot_set:%d:%s" % [index, recipe_id])
	TutorialProgress.on_product_displayed(self, recipe_id)
	return true


func list_product_in_display_slot(index: int, recipe_id: String, quantity: int = 1) -> bool:
	if index < 0 or index >= display_slots.size():
		return false
	if recipe_id.is_empty() or quantity <= 0:
		return false
	if not is_recipe_unlocked(recipe_id):
		return false
	if not has_product(recipe_id, quantity):
		return false

	var current_quantity := 0
	var slot_value: Variant = display_slots[index]
	if slot_value is Dictionary:
		var slot: Dictionary = slot_value
		if String(slot.get("recipe_id", "")) != recipe_id:
			return false
		current_quantity = maxi(0, int(slot.get("quantity", 0)))
	elif slot_value != null:
		if String(slot_value) != recipe_id:
			return false
		current_quantity = 1

	if not remove_product(recipe_id, quantity):
		return false

	display_slots[index] = {
		"recipe_id": recipe_id,
		"quantity": current_quantity + quantity
	}
	add_log("display_slot_listed:%d:%s:%d" % [index, recipe_id, quantity])
	TutorialProgress.on_product_displayed(self, recipe_id)
	return true


func sell_display_slot(index: int, quantity: int = 1) -> bool:
	if index < 0 or index >= display_slots.size() or quantity <= 0:
		return false

	var slot_value: Variant = display_slots[index]
	if not slot_value is Dictionary:
		return false

	var slot: Dictionary = slot_value
	var current_quantity := maxi(0, int(slot.get("quantity", 0)))
	if current_quantity < quantity:
		return false

	var remaining := current_quantity - quantity
	if remaining <= 0:
		display_slots[index] = null
	else:
		slot["quantity"] = remaining
		display_slots[index] = slot
	return true

# ========== 新增：自由摆放橱窗核心方法 ==========
## 判断产品能否摆放到橱窗指定格子（不扣库存）
func can_place_display_item(recipe_id: String, cells: Array, variant_id: String = "") -> bool:
	if _is_showcase_layout_locked():
		return false
	return not _normalized_display_cells(recipe_id, cells, variant_id).is_empty()


## 摆放产品到橱窗指定格子（仅设置位置，不扣库存）
func place_display_item(recipe_id: String, cells: Array, variant_id: String = "") -> bool:
	if _is_showcase_layout_locked():
		return false
	var normalized_cells := _normalized_display_cells(recipe_id, cells, variant_id)
	if normalized_cells.is_empty():
		return false

	var existing_stock: int = 0
	var base_sale_seconds := 0
	var current_variant_id := "standard" if variant_id.is_empty() else variant_id
	if display_items.has(recipe_id):
		existing_stock = display_items[recipe_id].get("stock", 0)
		base_sale_seconds = maxi(0, int(display_items[recipe_id].get("base_sale_seconds", 0)))
		if variant_id.is_empty():
			current_variant_id = String(display_items[recipe_id].get("variant_id", "standard"))

	display_items[recipe_id] = {
		"cells": normalized_cells,
		"stock": existing_stock,
		"base_sale_seconds": base_sale_seconds,
		"variant_id": current_variant_id
	}
	add_log("display_item_placed:%s" % recipe_id)
	return true

## 向橱窗产品追加库存（从仓库扣除，与原 list 逻辑一致）
func add_display_item_stock(recipe_id: String, amount: int, base_sale_seconds: int = 0) -> bool:
	if recipe_id.is_empty() or amount <= 0:
		return false
	if not display_items.has(recipe_id):
		return false  # 必须先摆放位置才能加货
	if not has_product(recipe_id, amount):
		return false

	if not remove_product(recipe_id, amount):
		return false

	var item: Dictionary = display_items[recipe_id]
	var carried_stock := maxi(0, int(item.get("carried_stock", 0)))
	var fresh_stock := maxi(0, int(item.get("fresh_stock", item.get("stock", 0))))
	fresh_stock += amount
	item["fresh_stock"] = fresh_stock
	item["carried_stock"] = carried_stock
	item["stock"] = fresh_stock + carried_stock
	if base_sale_seconds > 0:
		item["base_sale_seconds"] = base_sale_seconds
	display_items[recipe_id] = item
	add_log("display_item_stock_add:%s:%d" % [recipe_id, amount])
	TutorialProgress.on_product_displayed(self, recipe_id, amount)
	return true


## 摆放并上架库存（扣仓库库存）
func list_display_item(recipe_id: String, cells: Array, amount: int = 1, variant_id: String = "standard", base_sale_seconds: int = 0) -> bool:
	if not place_display_item(recipe_id, cells, variant_id):
		return false
	return add_display_item_stock(recipe_id, amount, base_sale_seconds)


func can_list_display_item_during_round(recipe_id: String, cells: Array, amount: int = 1, variant_id: String = "standard") -> bool:
	if String(active_business_round.get("phase", "")) != "running" \
			or recipe_id.is_empty() \
			or amount <= 0 \
			or display_items.has(recipe_id) \
			or not has_product(recipe_id, amount) \
			or not are_showcase_cells_unlocked(cells):
		return false
	return not _normalized_display_cells(recipe_id, cells, variant_id).is_empty()


func is_display_item_sold_out_during_round(recipe_id: String) -> bool:
	if String(active_business_round.get("phase", "")) != "running" \
			or recipe_id.is_empty() \
			or not display_items.has(recipe_id):
		return false
	var item_states: Dictionary = active_business_round.get("item_states", {})
	if not item_states.has(recipe_id):
		return false
	var item: Dictionary = item_states.get(recipe_id, {})
	return bool(item.get("waiting_for_refill", false)) \
		and maxi(0, int(item.get("fresh_stock", 0))) + maxi(0, int(item.get("carried_stock", 0))) <= 0


func can_replace_display_item_during_round(
	replaced_recipe_id: String,
	recipe_id: String,
	cells: Array,
	amount: int = 1,
	variant_id: String = "standard"
) -> bool:
	if replaced_recipe_id.is_empty() \
			or recipe_id.is_empty() \
			or recipe_id == replaced_recipe_id \
			or amount <= 0 \
			or display_items.has(recipe_id) \
			or not has_product(recipe_id, amount) \
			or not is_display_item_sold_out_during_round(replaced_recipe_id) \
			or not are_showcase_cells_unlocked(cells):
		return false
	var replaced_cells: Array = display_items.get(replaced_recipe_id, {}).get("cells", [])
	var overlaps_replaced := false
	for cell_value in cells:
		if replaced_cells.has(cell_value):
			overlaps_replaced = true
			break
	if not overlaps_replaced:
		return false
	return not _normalized_display_cells(recipe_id, cells, variant_id, replaced_recipe_id).is_empty()


func replace_sold_out_display_item_during_round(
	replaced_recipe_id: String,
	recipe_id: String,
	cells: Array,
	amount: int = 1,
	variant_id: String = "standard",
	base_sale_seconds: int = 0
) -> bool:
	if not can_replace_display_item_during_round(replaced_recipe_id, recipe_id, cells, amount, variant_id):
		return false
	var normalized_cells := _normalized_display_cells(recipe_id, cells, variant_id, replaced_recipe_id)
	if normalized_cells.is_empty() or not remove_product(recipe_id, amount):
		return false
	display_items.erase(replaced_recipe_id)
	display_items[recipe_id] = {
		"cells": normalized_cells,
		"fresh_stock": amount,
		"carried_stock": 0,
		"stock": amount,
		"base_sale_seconds": maxi(0, base_sale_seconds),
		"variant_id": "standard" if variant_id.is_empty() else variant_id
	}
	var item_states: Dictionary = active_business_round.get("item_states", {})
	item_states.erase(replaced_recipe_id)
	active_business_round["item_states"] = item_states
	return true


func unlist_sold_out_display_item_during_round(recipe_id: String) -> bool:
	if not is_display_item_sold_out_during_round(recipe_id):
		return false
	display_items.erase(recipe_id)
	var item_states: Dictionary = active_business_round.get("item_states", {})
	item_states.erase(recipe_id)
	active_business_round["item_states"] = item_states
	return true


func is_showcase_cell_unlocked(cell: Vector2i) -> bool:
	return showcase_unlocked_cells.has(cell)


func get_showcase_unlocked_cells() -> Array[Vector2i]:
	return showcase_unlocked_cells.duplicate()


func set_showcase_unlocked_cells(cells_value: Variant) -> void:
	showcase_unlocked_cells = _sanitize_showcase_unlocked_cells(cells_value)
	showcase_unlocked_bounds = _showcase_bounds_from_cells(showcase_unlocked_cells)


func get_showcase_unlocked_bounds() -> Dictionary:
	return _showcase_bounds_from_cells(showcase_unlocked_cells)


func get_showcase_region_layout() -> Dictionary:
	return ShowcaseRegionService.resolve_regions_for_cells(
		get_showcase_unlocked_cells(),
		DISPLAY_GRID_ROWS,
		DISPLAY_GRID_COLUMNS
	)


func set_showcase_unlocked_bounds(bounds: Dictionary) -> void:
	showcase_unlocked_bounds = _sanitize_showcase_unlocked_bounds(bounds)
	showcase_unlocked_cells = _showcase_cells_from_bounds(showcase_unlocked_bounds)


func quote_showcase_cell_purchase(cells: Array) -> Dictionary:
	var unlocked := get_showcase_unlocked_cells()
	var max_unlocked := ShowcaseExpansionService.max_unlocked_cells_for_level(level)
	var base := {
		"ok": false,
		"reason": "",
		"count": 0,
		"first_price": 0,
		"last_price": 0,
		"total_cost": 0,
		"unlocked_count": unlocked.size(),
		"max_unlocked_cells": max_unlocked,
		"remaining_quota": maxi(0, max_unlocked - unlocked.size()),
		"coin_shortfall": 0,
		"cells": []
	}
	if _is_showcase_layout_locked():
		base.reason = "layout_locked"
		return base
	if cells.is_empty():
		base.reason = "empty_selection"
		return base
	if level < 2:
		base.reason = "level_required"
		return base
	var selected: Array[Vector2i] = []
	for cell_value in cells:
		if not cell_value is Vector2i:
			base.reason = "invalid_selection"
			return base
		var cell: Vector2i = cell_value
		if cell.x < 1 or cell.x > DISPLAY_GRID_ROWS \
				or cell.y < 1 or cell.y > DISPLAY_GRID_COLUMNS \
				or unlocked.has(cell) or selected.has(cell):
			base.reason = "invalid_selection"
			return base
		selected.append(cell)
	if not ShowcaseExpansionService.is_connected_purchase(unlocked, selected):
		base.reason = "disconnected"
		return base
	if unlocked.size() + selected.size() > max_unlocked:
		base.reason = "level_cap"
		base.count = selected.size()
		base.cells = selected
		return base
	var price_quote: Dictionary = ShowcaseExpansionService.quote(unlocked.size(), selected.size())
	for key in price_quote:
		base[key] = price_quote[key]
	base.cells = selected
	if coins < int(base.total_cost):
		base.reason = "insufficient_coins"
		base.coin_shortfall = int(base.total_cost) - coins
		return base
	base.ok = true
	return base


func purchase_showcase_cells(cells: Array) -> Dictionary:
	var purchase_quote := quote_showcase_cell_purchase(cells)
	if not bool(purchase_quote.get("ok", false)):
		return purchase_quote
	var selected: Array = purchase_quote.get("cells", [])
	var updated := get_showcase_unlocked_cells()
	updated.append_array(selected)
	coins -= int(purchase_quote.get("total_cost", 0))
	set_showcase_unlocked_cells(updated)
	active_business_round["hotspot"] = {}
	add_log("showcase_cells_purchased:%d:%d" % [selected.size(), int(purchase_quote.get("total_cost", 0))])
	purchase_quote["unlocked_count"] = showcase_unlocked_cells.size()
	purchase_quote["remaining_quota"] = maxi(0, int(purchase_quote.max_unlocked_cells) - showcase_unlocked_cells.size())
	return purchase_quote


func are_showcase_cells_unlocked(cells: Array) -> bool:
	if cells.is_empty():
		return false
	for cell_value in cells:
		if not cell_value is Vector2i or not is_showcase_cell_unlocked(cell_value as Vector2i):
			return false
	return true


func list_display_item_during_round(recipe_id: String, cells: Array, amount: int = 1, variant_id: String = "standard", base_sale_seconds: int = 0) -> bool:
	if not can_list_display_item_during_round(recipe_id, cells, amount, variant_id):
		return false
	var normalized_cells := _normalized_display_cells(recipe_id, cells, variant_id)
	if normalized_cells.is_empty() or not remove_product(recipe_id, amount):
		return false
	display_items[recipe_id] = {
		"cells": normalized_cells,
		"fresh_stock": amount,
		"carried_stock": 0,
		"stock": amount,
		"base_sale_seconds": maxi(0, base_sale_seconds),
		"variant_id": "standard" if variant_id.is_empty() else variant_id
	}
	add_log("display_item_live_listed:%s:%d" % [recipe_id, amount])
	TutorialProgress.on_product_displayed(self, recipe_id, amount)
	return true

## 扣减橱窗产品库存（出售时调用）
func remove_display_item_stock(recipe_id: String, amount: int) -> bool:
	if recipe_id.is_empty() or amount <= 0:
		return false
	if not display_items.has(recipe_id):
		return false

	var item: Dictionary = display_items[recipe_id]
	var carried_stock := maxi(0, int(item.get("carried_stock", 0)))
	var fresh_stock := maxi(0, int(item.get("fresh_stock", item.get("stock", 0))))
	var current_stock := fresh_stock + carried_stock
	if current_stock < amount:
		return false

	var remaining: int = current_stock - amount
	var carried_sold := mini(carried_stock, amount)
	carried_stock -= carried_sold
	fresh_stock -= amount - carried_sold
	item["fresh_stock"] = maxi(0, fresh_stock)
	item["carried_stock"] = maxi(0, carried_stock)
	item["stock"] = maxi(0, remaining)
	display_items[recipe_id] = item
	add_log("display_item_stock_remove:%s:%d" % [recipe_id, amount])
	return true

## 从橱窗移除产品，剩余库存退回仓库
func remove_display_item(recipe_id: String) -> bool:
	if _is_showcase_layout_locked():
		return false
	if recipe_id.is_empty() or not display_items.has(recipe_id):
		return false

	var remaining_stock: int = display_items[recipe_id].get("stock", 0)
	if remaining_stock > 0:
		add_product(recipe_id, remaining_stock)

	display_items.erase(recipe_id)
	add_log("display_item_removed:%s" % recipe_id)
	return true

## 获取橱窗产品库存
func get_display_item_stock(recipe_id: String) -> int:
	if not display_items.has(recipe_id):
		return 0
	return maxi(0, int(display_items[recipe_id].get("stock", 0)))

## 获取橱窗产品占用的格子
func get_display_item_cells(recipe_id: String) -> Array:
	if not display_items.has(recipe_id):
		return []
	return display_items[recipe_id].get("cells", [])


func record_showcase_sale(event: Dictionary) -> void:
	var sanitized := _sanitize_showcase_sale_event(event)
	if String(sanitized.get("recipe_id", "")).is_empty() or int(sanitized.get("quantity", 0)) <= 0:
		return
	recent_showcase_sales.append(sanitized)
	while recent_showcase_sales.size() > MAX_RECENT_SHOWCASE_SALES:
		recent_showcase_sales.pop_front()


func apply_showcase_round_sale(event: Dictionary) -> bool:
	if String(active_business_round.get("phase", "")) != "running":
		return false
	var event_id := String(event.get("event_id", ""))
	var recipe_id := String(event.get("recipe_id", ""))
	var quantity := maxi(0, int(event.get("quantity", 0)))
	var bonus_only := bool(event.get("bonus_only", false))
	if event_id.is_empty() or recipe_id.is_empty() or quantity <= 0 and not bonus_only:
		return false
	var applied_ids: Array = active_business_round.get("applied_sale_event_ids", [])
	if applied_ids.has(event_id):
		return false
	coins = maxi(0, int(coins)) + maxi(0, int(event.get("earned_coins", 0)))
	reputation = maxi(0, int(reputation)) + maxi(0, int(event.get("earned_reputation", 0)))
	record_showcase_sale(event)
	if quantity > 0:
		record_recipe_sold(recipe_id, quantity, bool(event.get("positive_adjacency", false)))
	applied_ids.append(event_id)
	active_business_round["applied_sale_event_ids"] = applied_ids
	add_log("business_sale:showcase_round:%s:%s" % [event_id, recipe_id])
	return true


func apply_showcase_round_settlement(result: Dictionary) -> bool:
	if not bool(result.get("ok", false)):
		return false
	var settlement_id := String(result.get("settlement_id", result.get("applied_settlement_id", "")))
	if settlement_id.is_empty() or applied_showcase_settlement_ids.has(settlement_id):
		return false
	var pending_id := String(pending_showcase_settlement.get("settlement_id", ""))
	if not pending_id.is_empty() and pending_id != settlement_id:
		return false
	var item_states: Dictionary = result.get("item_states", {})
	for recipe_id_value in item_states.keys():
		var recipe_id := String(recipe_id_value)
		if not display_items.has(recipe_id):
			continue
		var item: Dictionary = display_items.get(recipe_id, {})
		var round_item: Dictionary = item_states.get(recipe_id_value, {})
		var fresh_stock := maxi(0, int(round_item.get("fresh_stock", 0)))
		var carried_stock := maxi(0, int(round_item.get("carried_stock", 0)))
		item["fresh_stock"] = fresh_stock
		item["carried_stock"] = carried_stock
		item["stock"] = fresh_stock + carried_stock
		display_items[recipe_id] = item
	coins = maxi(0, int(coins)) + maxi(0, int(result.get("earned_coins", 0)))
	business_runs = maxi(0, int(business_runs)) + 1
	var report_value: Variant = result.get("round_report", {})
	if report_value is Dictionary and bool((report_value as Dictionary).get("is_complete", false)):
		var report: Dictionary = (report_value as Dictionary).duplicate(true)
		var products_value: Variant = report.get("products", {})
		if products_value is Dictionary:
			var products: Dictionary = products_value
			for recipe_id_value in products.keys():
				var product_value: Variant = products.get(recipe_id_value)
				if not product_value is Dictionary:
					continue
				var product: Dictionary = (product_value as Dictionary).duplicate(true)
				var applied_growth := record_recipe_growth_round(
					String(recipe_id_value),
					bool(product.get("growth_effective_round", false)),
					bool(product.get("growth_synergy_round", false))
				)
				product["growth_effective_round"] = bool(applied_growth.get("growth_effective_round", false))
				product["growth_synergy_round"] = bool(applied_growth.get("growth_synergy_round", false))
				product["growth_before_mastery"] = int(applied_growth.get("growth_before_mastery", -1))
				product["growth_after_mastery"] = int(applied_growth.get("growth_after_mastery", -1))
				product["growth_promoted"] = bool(applied_growth.get("growth_promoted", false))
				products[recipe_id_value] = product
			report["products"] = products
		recent_showcase_round_reports.append(report)
		while recent_showcase_round_reports.size() > 10:
			recent_showcase_round_reports.pop_front()
	elif report_value is Dictionary and not (report_value as Dictionary).is_empty():
		add_log("showcase_round_report_incomplete:%s" % settlement_id)
	applied_showcase_settlement_ids.append(settlement_id)
	while applied_showcase_settlement_ids.size() > 50:
		applied_showcase_settlement_ids.pop_front()
	pending_showcase_settlement = {}
	add_log("showcase_round_settlement:%s" % settlement_id)
	return true


func accept_showcase_challenge(snapshot: Dictionary) -> bool:
	if snapshot.is_empty() or not pending_showcase_challenge.is_empty():
		return false
	if String(active_business_round.get("phase", "adjusting")) in ["running", "settlement"]:
		return false
	var deposit := maxi(0, int(snapshot.get("deposit", 0)))
	if coins < deposit:
		return false
	var task_id := String(snapshot.get("task_id", snapshot.get("id", "")))
	var is_repeatable_contract := String(snapshot.get("type", "")) == "contract" and not task_id.is_empty()
	if is_repeatable_contract and completed_tasks.has(task_id) and not claimed_tasks.has(task_id):
		return false
	coins -= deposit
	if is_repeatable_contract:
		completed_tasks.erase(task_id)
		claimed_tasks.erase(task_id)
		task_progress.erase(task_id)
	pending_showcase_challenge = snapshot.duplicate(true)
	add_log("showcase_challenge_accepted:%s" % String(snapshot.get("instance_id", snapshot.get("id", ""))))
	return true


func apply_showcase_challenge_result(result: Dictionary) -> bool:
	if not bool(result.get("valid", true)):
		return false
	var instance_id := String(result.get("instance_id", ""))
	var task_id := String(result.get("task_id", result.get("challenge_id", "")))
	var report_id := String(result.get("report_id", ""))
	if not task_id.is_empty() and (report_id.is_empty() or applied_contract_report_ids.has(report_id)):
		return false
	if instance_id.is_empty() or completed_showcase_challenge_ids.has(instance_id):
		return false
	if pending_showcase_challenge.is_empty() or String(pending_showcase_challenge.get("instance_id", "")) != instance_id:
		return false
	if bool(result.get("success", false)):
		coins += maxi(0, int(result.get("reward_coins", 0))) + maxi(0, int(result.get("deposit_returned", 0)))
		if not task_id.is_empty():
			var tier := String(result.get("highest_tier", ""))
			var previous_tier := String(contract_best_tiers.get(task_id, ""))
			if _contract_tier_rank(tier) > _contract_tier_rank(previous_tier):
				contract_best_tiers[task_id] = tier
			store_rating_points += _contract_tier_rank(tier) + 1
	if not task_id.is_empty():
		applied_contract_report_ids.append(report_id)
		while applied_contract_report_ids.size() > 100:
			applied_contract_report_ids.pop_front()
	completed_showcase_challenge_ids.append(instance_id)
	while completed_showcase_challenge_ids.size() > 50:
		completed_showcase_challenge_ids.pop_front()
	pending_showcase_challenge = {}
	add_log("showcase_challenge_result:%s:%s" % [instance_id, "success" if bool(result.get("success", false)) else "failed"])
	return true


func _contract_tier_rank(tier: String) -> int:
	match tier:
		"bronze": return 0
		"silver": return 1
		"gold": return 2
	return -1

## 判断产品是否已在橱窗摆放
func is_display_item_placed(recipe_id: String) -> bool:
	return display_items.has(recipe_id) and not get_display_item_cells(recipe_id).is_empty()

## 清空所有橱窗，库存全部退回仓库
func clear_all_display_items() -> void:
	if _is_showcase_layout_locked():
		return
	for recipe_id in display_items.keys():
		var remaining_stock: int = display_items[recipe_id].get("stock", 0)
		if remaining_stock > 0:
			add_product(recipe_id, remaining_stock)
	display_items.clear()
	display_props.clear()
	add_log("display_items_cleared")


func set_showcase_theme(theme_id: String) -> bool:
	if _is_showcase_layout_locked():
		return false
	if not theme_id.is_empty() and not unlocked_showcase_theme_ids.has(theme_id):
		return false
	showcase_theme_id = theme_id
	add_log("showcase_theme:%s" % ("none" if theme_id.is_empty() else theme_id))
	return true


func can_place_display_prop(prop_id: String, cells: Array) -> bool:
	if _is_showcase_layout_locked() or not unlocked_showcase_prop_ids.has(prop_id):
		return false
	return not _normalized_prop_cells(prop_id, cells).is_empty()


func place_display_prop(prop_id: String, cells: Array) -> bool:
	if _is_showcase_layout_locked() or not unlocked_showcase_prop_ids.has(prop_id):
		return false
	var normalized_cells := _normalized_prop_cells(prop_id, cells)
	if normalized_cells.is_empty():
		return false
	display_props[prop_id] = {
		"prop_id": prop_id,
		"cells": normalized_cells
	}
	add_log("display_prop_placed:%s" % prop_id)
	return true


func sync_showcase_collection_unlocks() -> Dictionary:
	var newly_unlocked_props: Array[String] = []
	var newly_unlocked_themes: Array[String] = []
	for prop_id in SHOWCASE_PROP_ORDER:
		if level >= int(SHOWCASE_PROP_UNLOCK_LEVELS.get(prop_id, 999)) and not unlocked_showcase_prop_ids.has(prop_id):
			unlocked_showcase_prop_ids.append(prop_id)
			newly_unlocked_props.append(prop_id)
	for theme_id in SHOWCASE_THEME_ORDER:
		if level >= int(SHOWCASE_THEME_UNLOCK_LEVELS.get(theme_id, 999)) and not unlocked_showcase_theme_ids.has(theme_id):
			unlocked_showcase_theme_ids.append(theme_id)
			newly_unlocked_themes.append(theme_id)
	return {"props": newly_unlocked_props, "themes": newly_unlocked_themes}


func get_unlocked_showcase_prop_ids() -> Array[String]:
	var result: Array[String] = []
	for prop_id in SHOWCASE_PROP_ORDER:
		if unlocked_showcase_prop_ids.has(prop_id):
			result.append(prop_id)
	return result


func get_unlocked_showcase_theme_ids() -> Array[String]:
	var result: Array[String] = []
	for theme_id in SHOWCASE_THEME_ORDER:
		if unlocked_showcase_theme_ids.has(theme_id):
			result.append(theme_id)
	return result


func remove_display_prop(prop_id: String) -> bool:
	if _is_showcase_layout_locked():
		return false
	if prop_id.is_empty() or not display_props.has(prop_id):
		return false
	display_props.erase(prop_id)
	add_log("display_prop_removed:%s" % prop_id)
	return true


func _is_showcase_layout_locked() -> bool:
	return String(active_business_round.get("phase", "adjusting")) in ["running", "settlement"]

# ========== 原有配方/任务/通知/升级方法保留 ==========
func add_recipe(recipe_id: String, notify: bool = false) -> bool:
	var recipes: Dictionary = _recipes()
	if not recipes.has(recipe_id):
		return false

	var recipe: Dictionary = recipes[recipe_id]
	if int(recipe.get("unlock_level", 1)) > level:
		return false

	if unlocked_recipes.has(recipe_id):
		return false

	unlocked_recipes.append(recipe_id)
	add_log("recipe_unlocked:%s" % recipe_id)
	if notify:
		_enqueue_recipe_unlock_notification(recipe_id, recipe)
	return true


func is_recipe_unlocked(recipe_id: String) -> bool:
	return unlocked_recipes.has(recipe_id)


func get_recipe_growth(recipe_id: String) -> Dictionary:
	if recipe_id.is_empty() or not _recipes().has(recipe_id):
		return RecipeGrowthService.default_growth(recipe_id)
	var stored_growth: Dictionary = recipe_growth.get(recipe_id, RecipeGrowthService.default_growth(recipe_id))
	return stored_growth.duplicate(true)


func recipe_mastery_level(recipe_id: String) -> int:
	if recipe_id.is_empty():
		return RecipeGrowthService.MASTERY_TRIAL
	var stored_value: Variant = recipe_growth.get(recipe_id, {})
	if not stored_value is Dictionary:
		return RecipeGrowthService.MASTERY_TRIAL
	return clampi(
		int((stored_value as Dictionary).get("mastery_level", RecipeGrowthService.MASTERY_TRIAL)),
		RecipeGrowthService.MASTERY_TRIAL,
		RecipeGrowthService.MASTERY_SIGNATURE
	)


func recipe_growth_status(recipe_id: String) -> Dictionary:
	if recipe_id.is_empty() or not _recipes().has(recipe_id):
		return {}
	var recipe: Dictionary = _recipes()[recipe_id]
	var device_id := String(recipe.get("device", ""))
	var status := RecipeGrowthService.growth_status(get_recipe_growth(recipe_id), get_device_growth(device_id))
	status["recipe_id"] = recipe_id
	status["device_id"] = device_id
	return status


func record_recipe_made(recipe_id: String, output_amount: int, batches: int = 1, source: String = "manual") -> Dictionary:
	if recipe_id.is_empty() or output_amount <= 0 or batches <= 0 or not _recipes().has(recipe_id):
		return {}
	var recipe: Dictionary = _recipes()[recipe_id]
	var device_id := String(recipe.get("device", ""))
	_ensure_recipe_growth(recipe_id)
	var was_masterwork_active := int(recipe_growth[recipe_id].get("masterwork_level", 0)) > 0
	var growth: Dictionary = recipe_growth[recipe_id]
	growth["made_count"] = maxi(0, int(growth.get("made_count", 0))) + output_amount
	if int(growth.get("mastery_level", 0)) < RecipeGrowthService.MASTERY_SIGNATURE:
		growth["stage_made_batches"] = maxi(0, int(growth.get("stage_made_batches", 0))) + batches
	recipe_growth[recipe_id] = growth
	record_device_production_batches(device_id, batches)
	if source not in ["manual", "automation"]:
		source = "manual"
	var updated := _update_recipe_growth(recipe_id, true, "made")
	_try_activate_masterwork(recipe_id, true)
	if was_masterwork_active:
		var base_xp_tenths := 20 if source == "manual" else 10
		var multiplier := DeviceGrowthService.production_growth_multiplier(_recipe_device_growth_level(recipe_id))
		return _add_masterwork_xp(recipe_id, roundi(base_xp_tenths * batches * multiplier), true)
	return updated


func record_recipe_sold(recipe_id: String, amount: int, positive_adjacency: bool = false) -> Dictionary:
	if recipe_id.is_empty() or not _recipes().has(recipe_id):
		return {}
	_ensure_recipe_growth(recipe_id)
	var growth: Dictionary = recipe_growth[recipe_id]
	var was_masterwork_active := int(growth.get("masterwork_level", 0)) > 0
	if amount > 0:
		growth["sold_count"] = maxi(0, int(growth.get("sold_count", 0))) + amount
	if positive_adjacency:
		growth["adjacency_trigger_count"] = maxi(0, int(growth.get("adjacency_trigger_count", 0))) + 1
	recipe_growth[recipe_id] = growth
	var updated := _update_recipe_growth(recipe_id, false, "sale")
	_try_activate_masterwork(recipe_id, true)
	if was_masterwork_active and amount > 0:
		var xp_tenths := amount * 20
		if positive_adjacency:
			xp_tenths += amount * 10
		return _add_masterwork_xp(recipe_id, xp_tenths, true)
	return updated


func record_recipe_growth_round(recipe_id: String, effective_round: bool, synergy_round: bool = false) -> Dictionary:
	var result := {
		"growth_effective_round": false,
		"growth_synergy_round": false,
		"growth_before_mastery": -1,
		"growth_after_mastery": -1,
		"growth_promoted": false
	}
	if recipe_id.is_empty() or not _recipes().has(recipe_id):
		return result
	_ensure_recipe_growth(recipe_id)
	var growth: Dictionary = recipe_growth[recipe_id]
	var before_mastery := int(growth.get("mastery_level", 0))
	result["growth_before_mastery"] = before_mastery
	result["growth_after_mastery"] = before_mastery
	if not effective_round or before_mastery >= RecipeGrowthService.MASTERY_SIGNATURE:
		return result
	growth["stage_effective_rounds"] = maxi(0, int(growth.get("stage_effective_rounds", 0))) + 1
	if synergy_round:
		growth["stage_synergy_rounds"] = maxi(0, int(growth.get("stage_synergy_rounds", 0))) + 1
	recipe_growth[recipe_id] = growth
	var updated := _update_recipe_growth(recipe_id, true, "round")
	var after_mastery := int(updated.get("mastery_level", before_mastery))
	result["growth_effective_round"] = true
	result["growth_synergy_round"] = synergy_round
	result["growth_after_mastery"] = after_mastery
	result["growth_promoted"] = after_mastery > before_mastery
	return result


func recipe_growth_stage_name(recipe_id: String) -> String:
	return RecipeGrowthService.mastery_name(int(get_recipe_growth(recipe_id).get("mastery_level", 0)))


func select_recipe_trait(recipe_id: String, trait_id: String) -> bool:
	if recipe_id.is_empty() or trait_id.is_empty() or not _recipes().has(recipe_id):
		return false
	_ensure_recipe_growth(recipe_id)
	var growth: Dictionary = get_recipe_growth(recipe_id)
	var available: Array = growth.get("available_traits", growth.get("display_traits", []))
	if not available.has(trait_id):
		return false
	var selected: Array[String] = _sanitize_string_array(growth.get("selected_traits", growth.get("selected_display_traits", [])))
	if selected.has(trait_id):
		return false
	selected.append(trait_id)
	growth["selected_traits"] = selected
	growth["selected_display_traits"] = selected.duplicate()
	recipe_growth[recipe_id] = growth
	var updated := _update_recipe_growth(recipe_id, false)
	_try_activate_masterwork(recipe_id, true)
	updated = get_recipe_growth(recipe_id)
	add_log("recipe_trait_selected:%s:%s" % [recipe_id, trait_id])
	return not updated.is_empty() and (updated.get("selected_traits", []) as Array).has(trait_id)


func recipe_production_preview(recipe_id: String, batches: int = 1) -> Dictionary:
	var recipes := _recipes()
	if not recipes.has(recipe_id):
		return {}
	var recipe: Dictionary = recipes[recipe_id]
	var output_count := maxi(1, int(recipe.get("output_count", 1))) * maxi(1, batches)
	var growth: Dictionary = get_recipe_growth(recipe_id)
	var next_made := int(growth.get("made_count", 0)) + output_count
	return {
		"recipe_id": recipe_id,
		"device_id": String(recipe.get("device", "")),
		"batches": maxi(1, batches),
		"output_count": output_count,
		"made_count_delta": output_count,
		"current_made_count": int(growth.get("made_count", 0)),
		"next_made_count": next_made,
		"growth_targets": ["made_count"],
		"materials": _sanitize_string_array(recipe.get("materials", []))
	}


func queue_recipe_production(
	recipe_id: String,
	batches: int = 1,
	now_unix: int = -1,
	source: String = "manual",
	automation_rule_id: String = ""
) -> bool:
	var clean_source := source if source in ["manual", "automation"] else "manual"
	if batches != 1:
		return false
	var recipes := _recipes()
	if not recipes.has(recipe_id) or not is_recipe_unlocked(recipe_id):
		return false
	var recipe: Dictionary = recipes[recipe_id]
	var device_id := String(recipe.get("device", ""))
	if device_id.is_empty() or not is_device_unlocked(device_id):
		return false
	if _active_recipe_production_batch_count(recipe_id) + batches > MAX_CONCURRENT_RECIPE_BATCHES:
		return false
	var materials := _sanitize_string_array(recipe.get("materials", []))
	if not _has_recipe_materials(materials, batches):
		return false
	if not _consume_recipe_materials(materials, batches):
		return false
	var started_at := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var duration := _recipe_queue_duration_seconds(recipe, batches, clean_source)
	recipe_production_queue.append({
		"queue_sequence": _next_recipe_production_queue_sequence(),
		"recipe_id": recipe_id,
		"device_id": device_id,
		"batches": batches,
		"output_count": maxi(1, int(recipe.get("output_count", 1))) * batches,
		"started_at_unix": started_at,
		"duration_seconds": duration,
		"ready_at_unix": started_at + duration,
		"source": clean_source,
		"automation_rule_id": automation_rule_id if clean_source == "automation" else ""
	})
	add_log("recipe_queue_start:%s:%d" % [recipe_id, batches])
	return true


func complete_recipe_production(index: int, now_unix: int = -1) -> bool:
	if index < 0 or index >= recipe_production_queue.size():
		return false
	var slot: Dictionary = recipe_production_queue[index]
	var current_time := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	if current_time < int(slot.get("ready_at_unix", 0)):
		return false
	var recipe_id := String(slot.get("recipe_id", ""))
	if recipe_id.is_empty() or not _recipes().has(recipe_id):
		return false
	var output_count := maxi(1, int(slot.get("output_count", 1)))
	var completed_device_id := String(slot.get("device_id", ""))
	var completed_batches := int(slot.get("batches", 1))
	var completed_sequence := maxi(1, int(slot.get("queue_sequence", index + 1)))
	if not add_product(recipe_id, output_count):
		return false
	mark_recipe_production_ready(recipe_id, completed_sequence, current_time)
	var completed_source := String(slot.get("source", "manual"))
	record_recipe_made(recipe_id, output_count, completed_batches, completed_source)
	recipe_production_queue.remove_at(index)
	add_log("recipe_queue_complete:%s:%d" % [recipe_id, output_count])
	TutorialProgress.on_product_made(self, recipe_id, output_count)
	record_task_event("recipe_queue_complete", {
		"recipe_id": recipe_id,
		"device_id": completed_device_id,
		"batches": completed_batches,
		"amount": output_count
	})
	return true


func complete_ready_manual_recipe_productions(now_unix: int = -1) -> Dictionary:
	var current_time := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var result := {
		"completed_batches": 0,
		"product_outputs": {},
		"completed_recipe_slots": []
	}
	for index in range(recipe_production_queue.size() - 1, -1, -1):
		var queued_value: Variant = recipe_production_queue[index]
		if not queued_value is Dictionary:
			continue
		var queued: Dictionary = queued_value
		if String(queued.get("source", "manual")) != "manual":
			continue
		if current_time < int(queued.get("ready_at_unix", 0)):
			continue
		var recipe_id := String(queued.get("recipe_id", ""))
		var output_count := maxi(1, int(queued.get("output_count", 1)))
		var batches := maxi(1, int(queued.get("batches", 1)))
		var completed_slot := {
			"recipe_id": recipe_id,
			"queue_sequence": int(queued.get("queue_sequence", 0)),
			"source": "manual",
			"batches": batches,
			"output_count": output_count
		}
		if not complete_recipe_production(index, current_time):
			continue
		var completed_recipe_slots: Array = result.get("completed_recipe_slots", [])
		completed_recipe_slots.append(completed_slot)
		result["completed_recipe_slots"] = completed_recipe_slots
		result["completed_batches"] = int(result.get("completed_batches", 0)) + batches
		var product_outputs: Dictionary = result.get("product_outputs", {})
		product_outputs[recipe_id] = int(product_outputs.get(recipe_id, 0)) + output_count
		result["product_outputs"] = product_outputs
	return result


func recipe_production_queue_summary(now_unix: int = -1) -> Dictionary:
	var current_time := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var summary: Dictionary = {}
	for queue_index in range(recipe_production_queue.size()):
		var queued_value: Variant = recipe_production_queue[queue_index]
		if not queued_value is Dictionary:
			continue
		var queued: Dictionary = queued_value
		var recipe_id := String(queued.get("recipe_id", ""))
		if recipe_id.is_empty():
			continue
		var started_at_unix := int(queued.get("started_at_unix", current_time))
		var ready_at_unix := int(queued.get("ready_at_unix", current_time))
		var duration_seconds := maxi(1, int(queued.get("duration_seconds", ready_at_unix - started_at_unix)))
		var batch_count := maxi(1, int(queued.get("batches", 1)))
		var queue_sequence := maxi(1, int(queued.get("queue_sequence", queue_index + 1)))
		var entry: Dictionary = summary.get(recipe_id, {
			"active_count": 0,
			"active_task_count": 0,
			"nearest_ready_at_unix": ready_at_unix,
			"remaining_seconds": maxi(0, ready_at_unix - current_time),
			"batch_progress": []
		})
		entry["active_count"] = int(entry.get("active_count", 0)) + batch_count
		entry["active_task_count"] = int(entry.get("active_task_count", 0)) + 1
		if ready_at_unix < int(entry.get("nearest_ready_at_unix", ready_at_unix)):
			entry["nearest_ready_at_unix"] = ready_at_unix
			entry["remaining_seconds"] = maxi(0, ready_at_unix - current_time)
		var batch_progress: Array = entry.get("batch_progress", [])
		var progress := clampf(float(current_time - started_at_unix) / float(duration_seconds), 0.0, 1.0)
		for batch_index in range(batch_count):
			batch_progress.append({
				"queue_sequence": queue_sequence,
				"batch_index": batch_index,
				"started_at_unix": started_at_unix,
				"ready_at_unix": ready_at_unix,
				"duration_seconds": duration_seconds,
				"remaining_seconds": maxi(0, ready_at_unix - current_time),
				"progress": progress,
				"source": String(queued.get("source", "manual")),
				"automation_rule_id": String(queued.get("automation_rule_id", ""))
			})
		entry["batch_progress"] = batch_progress
		summary[recipe_id] = entry
	for recipe_id_value: Variant in summary.keys():
		var recipe_id := String(recipe_id_value)
		var entry: Dictionary = summary[recipe_id]
		var batch_progress: Array = entry.get("batch_progress", [])
		batch_progress.sort_custom(_recipe_batch_progress_less)
		if batch_progress.size() > MAX_CONCURRENT_RECIPE_BATCHES:
			batch_progress.resize(MAX_CONCURRENT_RECIPE_BATCHES)
		entry["batch_progress"] = batch_progress
		summary[recipe_id] = entry
	return summary


func queue_ingredient_processing(
	process_id: String,
	now_unix: int = -1,
	source: String = "manual"
) -> bool:
	var processes := _processing_recipes()
	if not processes.has(process_id):
		return false
	if active_ingredient_processing_count(process_id) > 0:
		return false
	var process: Dictionary = processes[process_id]
	if int(process.get("unlock_level", 1)) > level:
		return false
	var device_id := String(process.get("device", ""))
	if device_id.is_empty() or not is_device_unlocked(device_id):
		return false
	var output_item_id := String(process.get("output_item_id", ""))
	if output_item_id.is_empty() or not _ingredients().has(output_item_id):
		return false
	var materials := _sanitize_string_array(process.get("materials", []))
	if materials.is_empty() or not _has_recipe_materials(materials, 1):
		return false
	if not _consume_recipe_materials(materials, 1):
		return false
	var started_at := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var duration_seconds := maxi(1, int(process.get("production_duration_seconds", 1)))
	ingredient_processing_queue.append({
		"queue_sequence": _next_ingredient_processing_queue_sequence(),
		"process_id": process_id,
		"device_id": device_id,
		"output_item_id": output_item_id,
		"output_count": maxi(1, int(process.get("output_count", 1))),
		"started_at_unix": started_at,
		"duration_seconds": duration_seconds,
		"ready_at_unix": started_at + duration_seconds,
		"source": source if source in ["manual", "automation"] else "manual"
	})
	add_log("ingredient_process_queue_start:%s" % process_id)
	return true


func complete_ingredient_processing(index: int, now_unix: int = -1) -> bool:
	if index < 0 or index >= ingredient_processing_queue.size():
		return false
	var queued_value: Variant = ingredient_processing_queue[index]
	if not queued_value is Dictionary:
		return false
	var queued: Dictionary = queued_value
	var current_time := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	if current_time < int(queued.get("ready_at_unix", 0)):
		return false
	var process_id := String(queued.get("process_id", ""))
	var processes := _processing_recipes()
	if process_id.is_empty() or not processes.has(process_id):
		return false
	var process: Dictionary = processes[process_id]
	var output_item_id := String(queued.get("output_item_id", process.get("output_item_id", "")))
	var output_count := maxi(1, int(queued.get("output_count", process.get("output_count", 1))))
	if not add_ingredient(output_item_id, output_count):
		return false
	unlock_ingredient_process(output_item_id)
	ingredient_processing_queue.remove_at(index)
	add_log("ingredient_process_queue_complete:%s:%s:%d" % [process_id, output_item_id, output_count])
	record_task_event("ingredient_process_complete", {
		"process_id": process_id,
		"device_id": String(queued.get("device_id", process.get("device", ""))),
		"ingredient_id": output_item_id,
		"amount": output_count
	})
	return true


func complete_ready_ingredient_processes(now_unix: int = -1) -> Dictionary:
	var current_time := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var result := {
		"completed_processes": 0,
		"ingredient_outputs": {},
		"completed_process_slots": []
	}
	for index in range(ingredient_processing_queue.size() - 1, -1, -1):
		var queued_value: Variant = ingredient_processing_queue[index]
		if not queued_value is Dictionary:
			continue
		var queued: Dictionary = queued_value
		if current_time < int(queued.get("ready_at_unix", 0)):
			continue
		var process_id := String(queued.get("process_id", ""))
		var output_item_id := String(queued.get("output_item_id", ""))
		var output_count := maxi(1, int(queued.get("output_count", 1)))
		var completed_slot := {
			"process_id": process_id,
			"queue_sequence": int(queued.get("queue_sequence", 0)),
			"source": String(queued.get("source", "manual")),
			"ingredient_id": output_item_id,
			"output_count": output_count
		}
		if not complete_ingredient_processing(index, current_time):
			continue
		var completed_slots: Array = result.get("completed_process_slots", [])
		completed_slots.append(completed_slot)
		result["completed_process_slots"] = completed_slots
		result["completed_processes"] = int(result.get("completed_processes", 0)) + 1
		var ingredient_outputs: Dictionary = result.get("ingredient_outputs", {})
		ingredient_outputs[output_item_id] = int(ingredient_outputs.get(output_item_id, 0)) + output_count
		result["ingredient_outputs"] = ingredient_outputs
	return result


func ingredient_processing_queue_summary(now_unix: int = -1) -> Dictionary:
	var current_time := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var summary: Dictionary = {}
	for queue_index in range(ingredient_processing_queue.size()):
		var queued_value: Variant = ingredient_processing_queue[queue_index]
		if not queued_value is Dictionary:
			continue
		var queued: Dictionary = queued_value
		var process_id := String(queued.get("process_id", ""))
		if process_id.is_empty():
			continue
		var started_at_unix := int(queued.get("started_at_unix", current_time))
		var ready_at_unix := int(queued.get("ready_at_unix", current_time))
		var duration_seconds := maxi(1, int(queued.get("duration_seconds", ready_at_unix - started_at_unix)))
		summary[process_id] = {
			"active_count": 1,
			"active_task_count": 1,
			"queue_sequence": maxi(1, int(queued.get("queue_sequence", queue_index + 1))),
			"started_at_unix": started_at_unix,
			"ready_at_unix": ready_at_unix,
			"duration_seconds": duration_seconds,
			"remaining_seconds": maxi(0, ready_at_unix - current_time),
			"progress": clampf(float(current_time - started_at_unix) / float(duration_seconds), 0.0, 1.0),
			"source": String(queued.get("source", "manual"))
		}
	return summary


func active_ingredient_processing_count(process_id: String) -> int:
	for queued_value: Variant in ingredient_processing_queue:
		if queued_value is Dictionary and String((queued_value as Dictionary).get("process_id", "")) == process_id:
			return 1
	return 0


func _next_ingredient_processing_queue_sequence() -> int:
	var highest_sequence := 0
	for queued_value: Variant in ingredient_processing_queue:
		if queued_value is Dictionary:
			highest_sequence = maxi(highest_sequence, int((queued_value as Dictionary).get("queue_sequence", 0)))
	return highest_sequence + 1


func _active_recipe_production_batch_count(recipe_id: String) -> int:
	var active_count := 0
	for queued_value: Variant in recipe_production_queue:
		if not queued_value is Dictionary:
			continue
		var queued: Dictionary = queued_value
		if String(queued.get("recipe_id", "")) == recipe_id:
			active_count += maxi(1, int(queued.get("batches", 1)))
	return active_count


func active_recipe_production_batch_count(recipe_id: String) -> int:
	return _active_recipe_production_batch_count(recipe_id)


func mark_recipe_production_ready(recipe_id: String, display_sequence: int, completed_at_unix: int) -> void:
	if recipe_id.is_empty() or not _recipes().has(recipe_id):
		return
	var record: Dictionary = production_ready_recipe_records.get(recipe_id, {})
	if record.is_empty():
		record["display_sequence"] = maxi(1, display_sequence)
	record["last_completed_at_unix"] = maxi(0, completed_at_unix)
	production_ready_recipe_records[recipe_id] = record


func prune_recipe_production_ready_record(recipe_id: String) -> void:
	if recipe_id.is_empty() or not production_ready_recipe_records.has(recipe_id):
		return
	if get_product_count(recipe_id) > 0 or active_recipe_production_batch_count(recipe_id) > 0:
		return
	production_ready_recipe_records.erase(recipe_id)


func production_ready_recipe_record(recipe_id: String) -> Dictionary:
	var record: Variant = production_ready_recipe_records.get(recipe_id, {})
	return (record as Dictionary).duplicate(true) if record is Dictionary else {}


func _next_recipe_production_queue_sequence() -> int:
	var highest_sequence := 0
	for queued_value: Variant in recipe_production_queue:
		if queued_value is Dictionary:
			highest_sequence = maxi(highest_sequence, int((queued_value as Dictionary).get("queue_sequence", 0)))
	for ready_value: Variant in production_ready_recipe_records.values():
		if ready_value is Dictionary:
			highest_sequence = maxi(highest_sequence, int((ready_value as Dictionary).get("display_sequence", 0)))
	return highest_sequence + 1


func _recipe_batch_progress_less(first: Dictionary, second: Dictionary) -> bool:
	var first_queue_sequence := int(first.get("queue_sequence", 0))
	var second_queue_sequence := int(second.get("queue_sequence", 0))
	if first_queue_sequence != second_queue_sequence:
		return first_queue_sequence < second_queue_sequence
	return int(first.get("batch_index", 0)) < int(second.get("batch_index", 0))


func complete_task(task_id: String) -> bool:
	if task_id.is_empty() or completed_tasks.has(task_id):
		return false

	completed_tasks.append(task_id)
	add_log("task_complete:%s" % task_id)
	return true


func is_task_completed(task_id: String) -> bool:
	return completed_tasks.has(task_id)


func is_task_reward_claimed(task_id: String) -> bool:
	return claimed_tasks.has(task_id)


func get_claimable_tasks() -> Array:
	return TaskService.get_claimable_tasks(self)


func sync_daily_tasks(day_key: String = "") -> void:
	TaskService.ensure_daily_tasks_current(self, day_key)


func claim_task_reward(task_id: String) -> bool:
	if not TaskService.claim_task_reward(self, task_id):
		return false
	var starlight_amount := StarProgressionService.task_starlight_amount(task_id)
	if starlight_amount > 0:
		claim_starlight_reward("task:%s" % task_id, starlight_amount)
	return true


func claim_all_task_rewards() -> Dictionary:
	var claimed_task_ids: Array[String] = []
	for task_value: Variant in get_claimable_tasks():
		if not task_value is Dictionary:
			continue
		var task_id := String((task_value as Dictionary).get("id", ""))
		if task_id.is_empty() or not TaskService.claim_task_reward(self, task_id, false):
			continue
		var starlight_amount := StarProgressionService.task_starlight_amount(task_id)
		if starlight_amount > 0:
			claim_starlight_reward("task:%s" % task_id, starlight_amount)
		claimed_task_ids.append(task_id)
	return {
		"ok": not claimed_task_ids.is_empty(),
		"task_ids": claimed_task_ids
	}


func record_task_event(event_name: String, payload: Dictionary = {}) -> Array:
	if not is_core_feature_unlocked(CoreFeatureUnlockService.TASK):
		return []
	return TaskService.apply_event(self, event_name, payload)


func get_task_snapshot() -> Dictionary:
	return TaskService.build_task_snapshot(self)


func get_active_tasks() -> Array:
	return TaskService.get_visible_tasks(self)


func enqueue_notification(title: String, body: String, metadata: Dictionary = {}) -> void:
	if title.is_empty() and body.is_empty():
		return

	pending_notifications.append({
		"title": title,
		"body": body,
		"metadata": _sanitize_notification_metadata(metadata)
	})
	add_log("notification:%s" % title)


func _enqueue_recipe_unlock_notification(recipe_id: String, recipe: Dictionary) -> void:
	var recipe_name := String(recipe.get("name", recipe_id))
	var device_id := String(recipe.get("device", ""))
	var device_name := ""
	if not device_id.is_empty():
		var device: Dictionary = Catalog.new().get_devices().get(device_id, {})
		device_name = String(device.get("name", device_id))

	var body := "材料配方已加入图鉴。"
	if not device_name.is_empty():
		body = "可在%s制作，材料配方已加入图鉴。" % device_name
	enqueue_notification("解锁新配方：%s" % recipe_name, body)


func pop_notification() -> Dictionary:
	if pending_notifications.is_empty():
		return {}

	var notification: Dictionary = pending_notifications[0]
	pending_notifications.remove_at(0)
	return notification


func upgrade_eligibility() -> Dictionary:
	var target_level := level + 1
	var target: Dictionary = Catalog.new().get_upgrade_definition(target_level)
	var cost := int(target.get("cost", 0))
	var required_reputation := int(target.get("required_reputation", 0))
	var result := {
		"ok": false,
		"reason": "",
		"target_level": target_level,
		"cost": cost,
		"required_reputation": required_reputation,
		"missing_coins": maxi(0, cost - coins),
		"missing_reputation": maxi(0, required_reputation - reputation),
		"device_id": String(target.get("device_id", "")),
		"milestone": target.get("milestone", {}).duplicate(true)
	}
	if level < 1:
		result.reason = "tutorial_required"
		return result
	if target.is_empty():
		result.reason = "definition_missing"
		return result
	result.ok = int(result.missing_coins) == 0 and int(result.missing_reputation) == 0
	result.reason = "ready" if bool(result.ok) else "insufficient_resources"
	return result


func can_upgrade() -> bool:
	return bool(upgrade_eligibility().get("ok", false))


func upgrade() -> bool:
	var eligibility := upgrade_eligibility()
	if not bool(eligibility.get("ok", false)):
		return false

	var target_level := int(eligibility.get("target_level", level + 1))
	coins -= int(eligibility.get("cost", 0))
	level = target_level
	_resize_display_slots(DISPLAY_SLOT_COUNT)
	add_log("upgrade:%d" % level)
	var device_id := String(eligibility.get("device_id", ""))
	var body := "经营等级提升，新的长期目标已经开放。"
	if not device_id.is_empty():
		var device: Dictionary = _devices().get(device_id, {})
		body = "新设备已开放：%s。" % String(device.get("name", device_id))
	enqueue_notification("店铺升级 Lv.%d" % level, body)
	record_task_event("upgrade", {"level": level})
	return true


func claim_starlight_reward(reward_key: String, amount: int) -> bool:
	if reward_key.is_empty() or amount <= 0 or claimed_starlight_rewards.has(reward_key):
		return false
	claimed_starlight_rewards.append(reward_key)
	recipe_starlight_total += amount
	recipe_starlight_available += amount
	unlock_core_feature(CoreFeatureUnlockService.STARLIGHT)
	add_log("starlight_claim:%s:%d" % [reward_key, amount])
	return true


func claim_recipe_starlight(recipe_id: String = "") -> Dictionary:
	var claimed := 0
	var keys: Array[String] = []
	for reward in StarProgressionService.claimable_recipe_rewards(self, recipe_id):
		var key := String(reward.get("key", ""))
		var amount := int(reward.get("amount", 0))
		if claim_starlight_reward(key, amount):
			claimed += amount
			keys.append(key)
	return {"ok": claimed > 0, "amount": claimed, "keys": keys}


func claim_catalog_milestone(percent: int) -> Dictionary:
	var rewards: Dictionary = StarProgressionService.get_config().get("starlight_rewards", {})
	var milestone_rewards: Dictionary = rewards.get("catalog_milestones", {})
	var percent_key := str(percent)
	if not milestone_rewards.has(percent_key):
		return {"ok": false, "amount": 0, "reason": "invalid_milestone"}
	var total_recipes := maxi(1, Catalog.new().get_recipes().size())
	var target := int(ceil(float(total_recipes) * float(percent) / 100.0))
	if unlocked_recipes.size() < target:
		return {"ok": false, "amount": 0, "reason": "milestone_locked", "target": target}
	var reward_key := "catalog_milestone:%d" % percent
	var amount := maxi(0, int(milestone_rewards.get(percent_key, 0)))
	if not claim_starlight_reward(reward_key, amount):
		return {"ok": false, "amount": 0, "reason": "already_claimed", "target": target}
	return {"ok": true, "amount": amount, "keys": [reward_key], "target": target}


func spend_starlight(amount: int) -> bool:
	if amount <= 0 or recipe_starlight_available < amount:
		return false
	recipe_starlight_available -= amount
	return true


func purchase_automation_upgrade(upgrade_id: String) -> Dictionary:
	var definition := StarProgressionService.upgrade_definition(upgrade_id)
	if upgrade_id.is_empty() or definition.is_empty():
		return {"ok": false, "reason": "invalid_upgrade"}
	if bool(automation_upgrades.get(upgrade_id, false)):
		return {"ok": false, "reason": "already_purchased"}
	var feature_id := String(definition.get("feature", ""))
	if feature_id.is_empty() or not is_automation_unlocked(feature_id):
		return {"ok": false, "reason": "feature_locked", "feature": feature_id}
	var missing_prerequisites: Array[String] = []
	var required_value: Variant = definition.get("requires_upgrades", [])
	if required_value is Array:
		for required_id_value: Variant in required_value:
			var required_id := String(required_id_value)
			if not required_id.is_empty() and not bool(automation_upgrades.get(required_id, false)):
				missing_prerequisites.append(required_id)
	if not missing_prerequisites.is_empty():
		return {"ok": false, "reason": "missing_prerequisite", "requires": missing_prerequisites}
	var cost := maxi(0, int(definition.get("cost", 0)))
	if recipe_starlight_available < cost:
		return {"ok": false, "reason": "insufficient_starlight", "cost": cost, "missing": cost - recipe_starlight_available}
	if cost > 0 and not spend_starlight(cost):
		return {"ok": false, "reason": "insufficient_starlight", "cost": cost}
	automation_upgrades[upgrade_id] = true
	add_log("automation_upgrade:%s:%d" % [upgrade_id, cost])
	return {"ok": true, "upgrade_id": upgrade_id, "cost": cost}


func to_dict() -> Dictionary:
	return {
		"version": version,
		"coins": coins,
		"reputation": reputation,
		"shop_level": shop_level,
		"level": level,
		"ingredient_inventory": ingredient_inventory.duplicate(true),
		"product_inventory": product_inventory.duplicate(true),
		"tool_inventory": tool_inventory.duplicate(true),
		"equipped_accelerators": equipped_accelerators.duplicate(true),
		"unlocked_tools": unlocked_tools.duplicate(true),
		"unlocked_devices": unlocked_devices.duplicate(true),
		"completed_tasks": completed_tasks.duplicate(true),
		"claimed_tasks": claimed_tasks.duplicate(true),
		"task_progress": task_progress.duplicate(true),
		"tutorial_guide_step": tutorial_guide_step,
		"tutorial_guide_finished": tutorial_guide_finished,
		"tutorial_guide_skipped": tutorial_guide_skipped,
		"tutorial_guide_dialogue_acknowledged_step": tutorial_guide_dialogue_acknowledged_step,
		"tutorial_guide_dismissed_step": tutorial_guide_dismissed_step,
		"tutorial_guide_content_version": tutorial_guide_content_version,
		"tutorial_guide_harvested_ids": tutorial_guide_harvested_ids.duplicate(),
		"tutorial_guide_showcase_moved": tutorial_guide_showcase_moved,
		"tutorial_guide_showcase_rotated": tutorial_guide_showcase_rotated,
		"daily_task_day_key": daily_task_day_key,
		"daily_task_selected_ids": daily_task_selected_ids.duplicate(),
		"pending_notifications": pending_notifications.duplicate(true),
		"production_slots": production_slots.duplicate(true),
		"production_slot_unlocks": production_slot_unlocks.duplicate(true),
		"production_bag_page_unlocks": production_bag_page_unlocks.duplicate(true),
		"unlocked_recipes": unlocked_recipes.duplicate(true),
		"ingredient_purchase_unlocks": ingredient_purchase_unlocks.duplicate(true),
		"ingredient_process_unlocks": ingredient_process_unlocks.duplicate(true),
		"display_slots": display_slots.duplicate(true),
		"display_items": _serialize_display_items(),  # 新增：序列化橱窗数据
		"display_props": _serialize_display_props(),
		"showcase_theme_id": showcase_theme_id,
		"showcase_unlocked_bounds": get_showcase_unlocked_bounds(),
		"showcase_unlocked_cells": _serialize_showcase_unlocked_cells(),
		"unlocked_showcase_prop_ids": get_unlocked_showcase_prop_ids(),
		"unlocked_showcase_theme_ids": get_unlocked_showcase_theme_ids(),
		"device_growth": device_growth.duplicate(true),
		"recipe_growth": recipe_growth.duplicate(true),
		"recipe_production_queue": recipe_production_queue.duplicate(true),
		"ingredient_processing_queue": ingredient_processing_queue.duplicate(true),
		"production_ready_recipe_records": production_ready_recipe_records.duplicate(true),
		"recipe_starlight_total": recipe_starlight_total,
		"recipe_starlight_available": recipe_starlight_available,
		"claimed_starlight_rewards": claimed_starlight_rewards.duplicate(true),
		"feature_unlocks": feature_unlocks.duplicate(true),
		"core_feature_unlocks": core_feature_unlocks.duplicate(true),
		"core_unlock_progress": core_unlock_progress.duplicate(true),
		"automation_unlocks": automation_unlocks.duplicate(true),
		"automation_upgrades": automation_upgrades.duplicate(true),
		"managed_production_sites": managed_production_sites.duplicate(true),
		"kitchen_automation_rules": kitchen_automation_rules.duplicate(true),
		"kitchen_rule_next_id": kitchen_rule_next_id,
		"automation_paused": automation_paused,
		"automation_resume_floor_unix": automation_resume_floor_unix,
		"automation_last_settled_unix": automation_last_settled_unix,
		"pending_automation_report": pending_automation_report.duplicate(true),
		"recent_showcase_sales": recent_showcase_sales.duplicate(true),
		"recent_showcase_round_reports": recent_showcase_round_reports.duplicate(true),
		"showcase_seed": showcase_seed,
		"business_round_id": business_round_id,
		"active_business_round": _serialize_showcase_round_value(active_business_round),
		"pending_showcase_settlement": pending_showcase_settlement.duplicate(true),
		"applied_showcase_settlement_ids": applied_showcase_settlement_ids.duplicate(),
		"pending_showcase_challenge": pending_showcase_challenge.duplicate(true),
		"completed_showcase_challenge_ids": completed_showcase_challenge_ids.duplicate(),
		"contract_best_tiers": contract_best_tiers.duplicate(true),
		"store_rating_points": store_rating_points,
		"applied_contract_report_ids": applied_contract_report_ids.duplicate(),
		"showcase_contract_choices": showcase_contract_choices.duplicate(true),
		"discovered_hints": discovered_hints.duplicate(true),
		"research_hint_progress": research_hint_progress.duplicate(true),
		"latest_research_hint_recipe_id": latest_research_hint_recipe_id,
		"feedback_log": feedback_log.duplicate(true),
		"business_runs": business_runs,
		"last_saved_at_unix": last_saved_at_unix,
		"offline_ready_count": offline_ready_count
	}


func add_log(message: String) -> void:
	if message.is_empty():
		return

	feedback_log.append(message)
	while feedback_log.size() > MAX_LOG_ENTRIES:
		feedback_log.pop_front()

# ========== 原有内部工具方法保留 ==========
func _add_inventory(inventory: Dictionary, item_id: String, amount: int) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	inventory[item_id] = _get_inventory_count(inventory, item_id) + amount
	return true


func _remove_inventory(inventory: Dictionary, item_id: String, amount: int) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	var current: int = _get_inventory_count(inventory, item_id)
	if current < amount:
		return false

	var remaining: int = current - amount
	if remaining == 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = remaining
	return true


func _has_inventory(inventory: Dictionary, item_id: String, amount: int) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	return _get_inventory_count(inventory, item_id) >= amount


func _get_inventory_count(inventory: Dictionary, item_id: String) -> int:
	return maxi(0, int(inventory.get(item_id, 0)))


func _sanitize_inventory(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized

	var raw: Dictionary = raw_value
	for item_id: Variant in raw.keys():
		var count: int = maxi(0, int(raw[item_id]))
		if count > 0:
			sanitized[String(item_id)] = count
	return sanitized


func _sanitize_tool_inventory(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized

	var tools: Dictionary = _tools()
	var raw: Dictionary = raw_value
	for tool_id: Variant in raw.keys():
		var id := String(tool_id)
		var count: int = maxi(0, int(raw[tool_id]))
		if tools.has(id) and count > 0:
			sanitized[id] = count
	return sanitized


func _sanitize_equipped_accelerators(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized

	var tools: Dictionary = _tools()
	var raw: Dictionary = raw_value
	for target_id: Variant in raw.keys():
		var id := String(target_id)
		var tool_id := String(raw[target_id])
		if tools.has(tool_id) and _tool_matches_accelerator_target(tool_id, id):
			sanitized[id] = tool_id
	return sanitized


func _sanitize_unlocked_tools(raw_value: Variant) -> Array[String]:
	var sanitized: Array[String] = []
	if not raw_value is Array:
		return sanitized

	var tools: Dictionary = _tools()
	var raw: Array = raw_value
	for tool_id: Variant in raw:
		var id := String(tool_id)
		if tools.has(id) and not sanitized.has(id):
			sanitized.append(id)
	return sanitized


func _sanitize_unlocked_devices(raw_value: Variant) -> Array[String]:
	var sanitized: Array[String] = []
	if raw_value is Array:
		var devices: Dictionary = _devices()
		var raw: Array = raw_value
		for device_id: Variant in raw:
			var id := String(device_id)
			if devices.has(id) and not sanitized.has(id):
				sanitized.append(id)
	return sanitized


func _sanitize_unlocked_recipes(raw_value: Variant) -> Array[String]:
	var sanitized: Array[String] = []
	if not raw_value is Array:
		return sanitized

	var recipes: Dictionary = _recipes()
	var raw: Array = raw_value
	for recipe_id: Variant in raw:
		var id: String = String(recipe_id)
		if recipes.has(id) and not sanitized.has(id):
			sanitized.append(id)
	return sanitized


func research_hint_level(recipe_id: String) -> int:
	return clampi(int(research_hint_progress.get(recipe_id, 0)), 0, 3)


func _sanitize_research_hint_progress(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized
	var recipes: Dictionary = _recipes()
	var raw: Dictionary = raw_value
	for recipe_value: Variant in raw.keys():
		var recipe_id := String(recipe_value)
		if not recipes.has(recipe_id):
			continue
		var level := clampi(int(raw.get(recipe_value, 0)), 0, 3)
		if level > 0:
			sanitized[recipe_id] = level
	return sanitized


func _sanitize_ingredient_purchase_unlocks(raw_value: Variant) -> Array[String]:
	var sanitized: Array[String] = []
	if not raw_value is Array:
		return sanitized

	var raw: Array = raw_value
	for item_id: Variant in raw:
		var id: String = String(item_id)
		if _is_process_purchase_unlockable(id) and not sanitized.has(id):
			sanitized.append(id)
	return sanitized


func _sanitize_ingredient_process_unlocks(raw_value: Variant) -> Array[String]:
	var sanitized: Array[String] = []
	if not raw_value is Array:
		return sanitized

	var raw: Array = raw_value
	for item_id: Variant in raw:
		var id: String = String(item_id)
		if _is_process_unlockable(id) and not sanitized.has(id):
			sanitized.append(id)
	return sanitized


func _is_process_purchase_unlockable(item_id: String) -> bool:
	var ingredient: Dictionary = _ingredients().get(item_id, {})
	if ingredient.is_empty():
		return false
	if bool(ingredient.get("purchasable", true)):
		return false
	return not String(ingredient.get("purchase_unlock_condition", "")).is_empty()


func _is_process_unlockable(item_id: String) -> bool:
	var ingredients := _ingredients()
	if not ingredients.has(item_id):
		return false

	var catalog := Catalog.new()
	for process_value: Variant in catalog.get_processing_recipes().values():
		if not process_value is Dictionary:
			continue
		var process: Dictionary = process_value
		if String(process.get("output_item_id", "")) == item_id:
			return true
	return false


func _sanitize_string_array(raw_value: Variant) -> Array[String]:
	var sanitized: Array[String] = []
	if not raw_value is Array:
		return sanitized

	var raw: Array = raw_value
	for value: Variant in raw:
		var text := String(value)
		if not text.is_empty() and not sanitized.has(text):
			sanitized.append(text)
	return sanitized


func _sanitize_notifications(raw_value: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if not raw_value is Array:
		return sanitized

	var raw: Array = raw_value
	for notification_value: Variant in raw:
		if not notification_value is Dictionary:
			continue

		var notification: Dictionary = notification_value
		var title := String(notification.get("title", ""))
		var body := String(notification.get("body", ""))
		if title.is_empty() and body.is_empty():
			continue
		sanitized.append({
			"title": title,
			"body": body,
			"metadata": _sanitize_notification_metadata(notification.get("metadata", {}))
		})
	return sanitized


func _sanitize_notification_metadata(raw_value: Variant) -> Dictionary:
	var sanitized: Dictionary = {}
	if not raw_value is Dictionary:
		return sanitized
	var raw: Dictionary = raw_value
	for key_value: Variant in raw.keys():
		var key := String(key_value)
		if key.is_empty():
			continue
		var value: Variant = _sanitize_notification_metadata_value(raw.get(key_value))
		if value != null:
			sanitized[key] = value
	return sanitized


func _sanitize_notification_metadata_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_DICTIONARY:
			return _sanitize_notification_metadata(value)
		TYPE_ARRAY:
			var sanitized: Array = []
			for entry: Variant in value as Array:
				var clean_entry: Variant = _sanitize_notification_metadata_value(entry)
				if clean_entry != null:
					sanitized.append(clean_entry)
			return sanitized
	return null


func _sanitize_feedback_log(raw_value: Variant) -> Array[String]:
	var sanitized: Array[String] = []
	if not raw_value is Array:
		return feedback_log.duplicate(true)

	var raw: Array = raw_value
	for message: Variant in raw:
		var text: String = String(message)
		if not text.is_empty():
			sanitized.append(text)

	while sanitized.size() > MAX_LOG_ENTRIES:
		sanitized.pop_front()
	return sanitized


func _sanitize_logs(raw_value: Variant) -> Array[String]:
	return _sanitize_feedback_log(raw_value)


func _sanitize_array(raw_value: Variant) -> Array:
	if raw_value is Array:
		var raw: Array = raw_value
		return raw.duplicate(true)
	return []


func _sanitize_dictionary(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		var raw: Dictionary = raw_value
		return raw.duplicate(true)
	return {}


func _sanitize_active_business_round(raw_value: Variant) -> Dictionary:
	if not raw_value is Dictionary:
		return {}
	var restored: Variant = _restore_showcase_round_anchor_cells((raw_value as Dictionary).duplicate(true))
	return restored as Dictionary if restored is Dictionary else {}


func _restore_showcase_round_anchor_cells(value: Variant) -> Variant:
	if value is Dictionary:
		var restored := {}
		for key_value in (value as Dictionary).keys():
			var key := String(key_value)
			var child: Variant = (value as Dictionary).get(key_value)
			restored[key_value] = _showcase_round_anchor_cell_from_value(child) \
				if key == "anchor_cell" \
				else _restore_showcase_round_anchor_cells(child)
		return restored
	if value is Array:
		var restored_array: Array = []
		for child in value as Array:
			restored_array.append(_restore_showcase_round_anchor_cells(child))
		return restored_array
	return value


func _showcase_round_anchor_cell_from_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is String:
		var text := String(value).strip_edges()
		if text.begins_with("Vector2i(") and text.ends_with(")"):
			text = text.substr(9, text.length() - 10)
		elif text.begins_with("(") and text.ends_with(")"):
			text = text.substr(1, text.length() - 2)
		var parts := text.split(",", false)
		if parts.size() >= 2:
			var row_text := String(parts[0]).strip_edges()
			var column_text := String(parts[1]).strip_edges()
			if row_text.is_valid_int() and column_text.is_valid_int():
				return Vector2i(int(row_text), int(column_text))
	return Vector2i(9999, 9999)


func _serialize_showcase_round_value(value: Variant) -> Variant:
	if value is Vector2i:
		return [value.x, value.y]
	if value is Dictionary:
		var serialized := {}
		for key_value in (value as Dictionary).keys():
			serialized[key_value] = _serialize_showcase_round_value((value as Dictionary).get(key_value))
		return serialized
	if value is Array:
		var serialized_array: Array = []
		for child in value as Array:
			serialized_array.append(_serialize_showcase_round_value(child))
		return serialized_array
	return value


func _sanitize_showcase_sale_event(event: Dictionary) -> Dictionary:
	return {
		"recipe_id": String(event.get("recipe_id", "")),
		"recipe_name": String(event.get("recipe_name", "")),
		"quantity": maxi(0, int(event.get("quantity", 0))),
		"unit_price": maxi(0, int(event.get("unit_price", event.get("final_price", 0)))),
		"earned_coins": maxi(0, int(event.get("earned_coins", 0))),
		"earned_reputation": maxi(0, int(event.get("earned_reputation", 0))),
		"timestamp": maxi(0, int(event.get("timestamp", 0))),
		"anchor_slot": int(event.get("anchor_slot", -1)),
		"cell_indices": _sanitize_int_array(event.get("cell_indices", [])),
		"attribution": _sanitize_dictionary(event.get("attribution", {})),
		"groups": _sanitize_array(event.get("groups", [])),
		"reasons": _sanitize_cashier_reasons(event.get("reasons", []))
	}


func _sanitize_recent_showcase_sales(raw_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_value is Array:
		return result
	for event_value in raw_value as Array:
		if not event_value is Dictionary:
			continue
		var event := _sanitize_showcase_sale_event(event_value)
		if String(event.get("recipe_id", "")).is_empty() or int(event.get("quantity", 0)) <= 0:
			continue
		result.append(event)
	while result.size() > MAX_RECENT_SHOWCASE_SALES:
		result.pop_front()
	return result


func _sanitize_showcase_round_reports(raw_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_value is Array:
		return result
	for report_value in raw_value as Array:
		if report_value is Dictionary:
			result.append((report_value as Dictionary).duplicate(true))
	while result.size() > 10:
		result.pop_front()
	return result


func _sanitize_dictionary_array(raw_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw_value is Array:
		for value in raw_value as Array:
			if value is Dictionary:
				result.append((value as Dictionary).duplicate(true))
	return result


func _sanitize_int_array(raw_value: Variant) -> Array[int]:
	var result: Array[int] = []
	if raw_value is Array:
		for value in raw_value as Array:
			result.append(int(value))
	return result


func _sanitize_cashier_reasons(raw_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_value is Array:
		return result
	for reason_value in raw_value as Array:
		if not reason_value is Dictionary:
			continue
		var reason: Dictionary = reason_value
		var reason_text := String(reason.get("text", "")).strip_edges()
		if reason_text.is_empty():
			continue
		result.append({
			"source": String(reason.get("source", "")),
			"text": reason_text,
			"price_pct": float(reason.get("price_pct", 0.0)),
			"speed_pct": float(reason.get("speed_pct", 0.0))
		})
	return result


func _sanitize_managed_production_slots(raw_value: Variant) -> Array[String]:
	var sanitized: Array[String] = []
	var production_sites: Dictionary = Catalog.new().get_production_sites()
	for target_id in _sanitize_string_array(raw_value):
		var parts := target_id.split(":")
		if parts.size() != 2 or not parts[1].is_valid_int():
			continue
		var site_id := String(parts[0])
		var slot_index := int(parts[1])
		if not production_sites.has(site_id):
			continue
		if slot_index < 0:
			continue
		var site: Dictionary = production_sites[site_id]
		var base_slots := maxi(0, int(site.get("base_slots", 0)))
		var unlocked_slots := clampi(int(production_slot_unlocks.get(site_id, 0)), 0, base_slots)
		if slot_index >= unlocked_slots:
			continue
		var canonical_target_id := "%s:%d" % [site_id, slot_index]
		if not sanitized.has(canonical_target_id):
			sanitized.append(canonical_target_id)
	return sanitized


func _sanitize_managed_production_sites(raw_value: Variant) -> Array[String]:
	var sanitized: Array[String] = []
	var production_sites: Dictionary = Catalog.new().get_production_sites()
	for site_id in _sanitize_string_array(raw_value):
		if production_sites.has(site_id) and not sanitized.has(site_id):
			sanitized.append(site_id)
	return sanitized


func _managed_sites_from_legacy_slots(legacy_slots: Array[String]) -> Array[String]:
	var sites: Array[String] = []
	for slot_key in legacy_slots:
		var site_id := slot_key.get_slice(":", 0)
		if not site_id.is_empty() and not sites.has(site_id):
			sites.append(site_id)
	return sites


func is_output_site_managed(site_id: String) -> bool:
	return managed_production_sites.has(site_id)


func _sanitize_kitchen_automation_rules(raw_value: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if not raw_value is Array:
		return sanitized
	var recipes := _recipes()
	var devices := _devices()
	var paused: Array = pending_automation_report.get("pauses", [])
	var seen_ids: Dictionary = {}
	var enabled_devices: Dictionary = {}
	var automation_effects := StarProgressionService.resolved_automation_effects(self)
	var rule_limit := int(automation_effects.get("kitchen_rules", 0))
	var device_limit := int(automation_effects.get("managed_kitchen_devices", 0))
	var inventory_policy_enabled := bool(automation_effects.get("inventory_policy_enabled", false))
	var priority_enabled := bool(automation_effects.get("priority_enabled", false))
	for rule_value: Variant in raw_value:
		if not rule_value is Dictionary:
			continue
		var rule: Dictionary = rule_value
		var rule_id := String(rule.get("id", ""))
		var recipe_id := String(rule.get("recipe_id", ""))
		var device_id := String(rule.get("device_id", ""))
		if rule_id.is_empty() or not recipes.has(recipe_id):
			paused.append({"rule_id": rule_id, "reason": {"code": "invalid_recipe"}})
			continue
		if not devices.has(device_id) or String(recipes[recipe_id].get("device", "")) != device_id:
			paused.append({"rule_id": rule_id, "reason": {"code": "invalid_device"}})
			continue
		if seen_ids.has(rule_id):
			continue
		seen_ids[rule_id] = true
		var batches := 1
		var reserves: Dictionary = {}
		if rule.get("material_reserves", {}) is Dictionary:
			for item_value: Variant in (rule.get("material_reserves", {}) as Dictionary).keys():
				var item_id := String(item_value)
				var reserve := maxi(0, int((rule.get("material_reserves", {}) as Dictionary).get(item_value, 0)))
				if not item_id.is_empty() and reserve > 0:
					reserves[item_id] = reserve
		var normalized := {
			"id": rule_id,
			"recipe_id": recipe_id,
			"device_id": device_id,
			"batches": batches,
			"target_stock": maxi(0, int(rule.get("target_stock", 0))),
			"material_reserves": reserves if inventory_policy_enabled else {},
			"priority": int(rule.get("priority", 0)) if priority_enabled else 0,
			"sort_order": maxi(0, int(rule.get("sort_order", 0))),
			"enabled": bool(rule.get("enabled", true))
		}
		if rule.has("pause_reason") and rule.get("pause_reason") is Dictionary:
			normalized["pause_reason"] = (rule.get("pause_reason", {}) as Dictionary).duplicate(true)
		var exceeds_rule_limit := sanitized.size() >= rule_limit
		var exceeds_device_limit := device_limit >= 0 and not enabled_devices.has(device_id) and enabled_devices.size() >= device_limit
		if exceeds_rule_limit or exceeds_device_limit:
			normalized["enabled"] = false
			normalized["pause_reason"] = {"code": "limit_reached"}
			paused.append({"rule_id": rule_id, "reason": {"code": "limit_reached"}})
		elif bool(normalized.get("enabled", false)):
			enabled_devices[device_id] = true
		sanitized.append(normalized)
		var suffix := rule_id.trim_prefix("rule_")
		if suffix.is_valid_int():
			kitchen_rule_next_id = maxi(kitchen_rule_next_id, int(suffix) + 1)
	pending_automation_report["pauses"] = paused
	return sanitized


func _sanitize_task_progress(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized

	var raw: Dictionary = raw_value
	for task_id: Variant in raw.keys():
		var id := String(task_id)
		if id.is_empty() or not raw[task_id] is Dictionary:
			continue
		var progress: Dictionary = raw[task_id]
		var entry := {
			"count": maxi(0, int(progress.get("count", 0))),
			"goal": maxi(1, int(progress.get("goal", 1))),
			"title": String(progress.get("title", id))
		}
		for count_field in ["harvest_count", "next_set_count", "completion_count"]:
			if progress.has(count_field):
				entry[count_field] = maxi(0, int(progress.get(count_field, 0)))
		for ids_field in ["harvest_site_ids", "harvest_batch_ids", "device_ids"]:
			if progress.has(ids_field):
				entry[ids_field] = _sanitize_string_array(progress.get(ids_field, []))
		if progress.has("last_harvest_batch_id"):
			entry["last_harvest_batch_id"] = String(progress.get("last_harvest_batch_id", ""))
		var objectives_value: Variant = progress.get("objectives", {})
		if objectives_value is Dictionary:
			var objectives := {}
			for objective_id_value: Variant in (objectives_value as Dictionary).keys():
				var objective_id := String(objective_id_value)
				var objective_value: Variant = (objectives_value as Dictionary).get(objective_id_value, {})
				if objective_id.is_empty() or not objective_value is Dictionary:
					continue
				var objective: Dictionary = objective_value
				objectives[objective_id] = {
					"count": maxi(0, int(objective.get("count", 0))),
					"goal": maxi(1, int(objective.get("goal", 1))),
					"title": String(objective.get("title", objective_id)),
					"completed": bool(objective.get("completed", false))
				}
			entry["objectives"] = objectives
		sanitized[id] = entry
	return sanitized


static func _default_production_unlocks() -> Dictionary:
	return {
		"farm": 1,
		"ranch": 1,
		"forest": 1,
		"pond": 1
	}


func _sanitize_production_unlocks(raw_value: Variant, max_count: int) -> Dictionary:
	var sanitized := _default_production_unlocks()
	if raw_value is Dictionary:
		var raw: Dictionary = raw_value
		for site_id in sanitized.keys():
			sanitized[site_id] = clampi(int(raw.get(site_id, sanitized[site_id])), 1, max_count)
	return sanitized


func _sanitize_production_slots(raw_value: Variant) -> Array:
	var sanitized := _sanitize_array(raw_value)
	var production_sites: Dictionary = Catalog.new().get_production_sites()
	var valid_slots: Array = []
	for slot_value: Variant in sanitized:
		if slot_value is Dictionary:
			var slot: Dictionary = slot_value
			var site_id := String(slot.get("site_id", ""))
			if production_sites.has(site_id) and slot.has("slot_index"):
				var max_slots := int((production_sites[site_id] as Dictionary).get("base_slots", 0))
				var slot_index := int(slot.get("slot_index", -1))
				if slot_index < 0 or slot_index >= max_slots:
					continue
		valid_slots.append(slot_value)
	return valid_slots


func _sanitize_display_slots(raw_value: Variant, slot_count: int) -> Array:
	var sanitized := []
	var raw: Array = []
	if raw_value is Array:
		raw = raw_value

	for index in range(slot_count):
		if index >= raw.size() or raw[index] == null:
			sanitized.append(null)
			continue

		var raw_slot: Variant = raw[index]
		if raw_slot is Dictionary:
			var slot: Dictionary = raw_slot
			var recipe_id := String(slot.get("recipe_id", ""))
			var quantity := maxi(0, int(slot.get("quantity", 0)))
			if not recipe_id.is_empty() and quantity > 0 and is_recipe_unlocked(recipe_id):
				sanitized.append({
					"recipe_id": recipe_id,
					"quantity": quantity
				})
			else:
				sanitized.append(null)
			continue

		var recipe_id: String = String(raw_slot)
		if not recipe_id.is_empty() and is_recipe_unlocked(recipe_id) and has_product(recipe_id):
			sanitized.append(recipe_id)
		else:
			sanitized.append(null)
	return sanitized

# ========== 新增：橱窗数据序列化与清洗 ==========
## 序列化 display_items 为可存档格式（Vector2i 转二维数组）
func _serialize_display_items() -> Dictionary:
	var serialized := {}
	for recipe_id in display_items.keys():
		var item: Dictionary = display_items[recipe_id]
		var fresh_stock := maxi(0, int(item.get("fresh_stock", item.get("stock", 0))))
		var carried_stock := maxi(0, int(item.get("carried_stock", 0)))
		var cells_raw: Array = item.get("cells", [])
		var cells_serialized: Array = []
		for cell in cells_raw:
			if cell is Vector2i:
				cells_serialized.append([cell.x, cell.y])
			else:
				cells_serialized.append(cell)
		serialized[recipe_id] = {
			"cells": cells_serialized,
			"stock": fresh_stock + carried_stock,
			"fresh_stock": fresh_stock,
			"carried_stock": carried_stock,
			"base_sale_seconds": maxi(1, int(item.get("base_sale_seconds", 1))),
			"variant_id": String(item.get("variant_id", "standard"))
		}
	return serialized


func _serialize_display_props() -> Dictionary:
	var serialized := {}
	for prop_id in display_props.keys():
		var item: Dictionary = display_props[prop_id]
		var cells_raw: Array = item.get("cells", [])
		var cells_serialized: Array = []
		for cell in cells_raw:
			if cell is Vector2i:
				cells_serialized.append([cell.x, cell.y])
			else:
				cells_serialized.append(cell)
		serialized[prop_id] = {
			"prop_id": String(item.get("prop_id", prop_id)),
			"cells": cells_serialized
		}
	return serialized

## 清洗加载的橱窗数据，转回 Vector2i 格式
func _sanitize_display_items(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized
	var recipes: Dictionary = _recipes()
	var raw: Dictionary = raw_value
	for recipe_id: Variant in raw.keys():
		var id: String = String(recipe_id)
		if id.is_empty() or not recipes.has(id):
			continue
		var item_data: Variant = raw[recipe_id]
		if not item_data is Dictionary:
			continue
		var item: Dictionary = item_data

		# 转换格子坐标为 Vector2i
		var cells_raw: Array = item.get("cells", [])
		var cells: Array[Vector2i] = []
		for cell_data in cells_raw:
			if cell_data is Array and cell_data.size() == 2:
				cells.append(Vector2i(int(cell_data[0]), int(cell_data[1])))
			elif cell_data is Vector2i:
				cells.append(cell_data)

		var fresh_stock := maxi(0, int(item.get("fresh_stock", item.get("stock", 0))))
		var carried_stock := maxi(0, int(item.get("carried_stock", 0)))
		var stock := fresh_stock + carried_stock
		if cells.is_empty():
			continue  # 无格子坐标的脏数据丢弃
		sanitized[id] = {
			"cells": cells,
			"stock": stock,
			"fresh_stock": fresh_stock,
			"carried_stock": carried_stock,
			"base_sale_seconds": maxi(1, int(item.get("base_sale_seconds", 1))),
			"variant_id": String(item.get("variant_id", "standard"))
		}
	return sanitized


func _sanitize_display_props(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized
	var raw: Dictionary = raw_value
	for prop_id_value: Variant in raw.keys():
		var prop_id := String(prop_id_value)
		if not DISPLAY_PROP_SHAPES.has(prop_id):
			continue
		var item_data: Variant = raw[prop_id_value]
		if not item_data is Dictionary:
			continue
		var cells_raw: Array = (item_data as Dictionary).get("cells", [])
		var cells: Array[Vector2i] = []
		for cell_data in cells_raw:
			if cell_data is Array and cell_data.size() == 2:
				cells.append(Vector2i(int(cell_data[0]), int(cell_data[1])))
			elif cell_data is Vector2i:
				cells.append(cell_data)
		var normalized := _normalized_prop_cells(prop_id, cells)
		if normalized.is_empty():
			continue
		sanitized[prop_id] = {
			"prop_id": prop_id,
			"cells": normalized
		}
	return sanitized


func _sanitize_showcase_unlocked_bounds(raw_value: Variant) -> Dictionary:
	var raw_bounds: Dictionary = raw_value if raw_value is Dictionary else DEFAULT_SHOWCASE_UNLOCKED_BOUNDS
	return ShowcaseRegionService.normalize_bounds(
		raw_bounds,
		DISPLAY_GRID_ROWS,
		DISPLAY_GRID_COLUMNS
	)


func _sanitize_showcase_unlocked_cells(raw_value: Variant) -> Array[Vector2i]:
	var sanitized: Array[Vector2i] = []
	if raw_value is Array:
		for cell_value in raw_value:
			var cell := Vector2i.ZERO
			if cell_value is Vector2i:
				cell = cell_value
			elif cell_value is Dictionary:
				cell = Vector2i(int(cell_value.get("row", 0)), int(cell_value.get("column", 0)))
			elif cell_value is Array and cell_value.size() >= 2:
				cell = Vector2i(int(cell_value[0]), int(cell_value[1]))
			if cell.x < 1 or cell.x > DISPLAY_GRID_ROWS or cell.y < 1 or cell.y > DISPLAY_GRID_COLUMNS or sanitized.has(cell):
				continue
			sanitized.append(cell)
	if sanitized.is_empty():
		return _showcase_cells_from_bounds(DEFAULT_SHOWCASE_UNLOCKED_BOUNDS)
	sanitized.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		return left.x < right.x or left.x == right.x and left.y < right.y
	)
	return sanitized


func _showcase_cells_from_bounds(bounds: Dictionary) -> Array[Vector2i]:
	var normalized := _sanitize_showcase_unlocked_bounds(bounds)
	var cells: Array[Vector2i] = []
	for row in range(int(normalized.min_row), int(normalized.max_row) + 1):
		for column in range(int(normalized.min_column), int(normalized.max_column) + 1):
			cells.append(Vector2i(row, column))
	return cells


func _showcase_bounds_from_cells(cells: Array[Vector2i]) -> Dictionary:
	if cells.is_empty():
		return DEFAULT_SHOWCASE_UNLOCKED_BOUNDS.duplicate(true)
	var min_row := DISPLAY_GRID_ROWS
	var max_row := 1
	var min_column := DISPLAY_GRID_COLUMNS
	var max_column := 1
	for cell in cells:
		min_row = mini(min_row, cell.x)
		max_row = maxi(max_row, cell.x)
		min_column = mini(min_column, cell.y)
		max_column = maxi(max_column, cell.y)
	return {"min_row": min_row, "max_row": max_row, "min_column": min_column, "max_column": max_column}


func _serialize_showcase_unlocked_cells() -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for cell in showcase_unlocked_cells:
		serialized.append({"row": cell.x, "column": cell.y})
	return serialized


func _sanitize_recipe_production_queue(raw_value: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if not raw_value is Array:
		return sanitized
	var recipes := _recipes()
	var used_sequences: Dictionary = {}
	var next_sequence := 1
	for slot_value: Variant in raw_value:
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		var recipe_id := String(slot.get("recipe_id", ""))
		if recipe_id.is_empty() or not recipes.has(recipe_id):
			continue
		var recipe: Dictionary = recipes[recipe_id]
		var queue_sequence := maxi(0, int(slot.get("queue_sequence", 0)))
		if queue_sequence <= 0 or used_sequences.has(queue_sequence):
			while used_sequences.has(next_sequence):
				next_sequence += 1
			queue_sequence = next_sequence
		used_sequences[queue_sequence] = true
		next_sequence = maxi(next_sequence, queue_sequence + 1)
		sanitized.append({
			"queue_sequence": queue_sequence,
			"recipe_id": recipe_id,
			"device_id": String(slot.get("device_id", recipe.get("device", ""))),
			"batches": maxi(1, int(slot.get("batches", 1))),
			"output_count": maxi(1, int(slot.get("output_count", recipe.get("output_count", 1)))),
			"started_at_unix": maxi(0, int(slot.get("started_at_unix", 0))),
			"duration_seconds": maxi(1, int(slot.get("duration_seconds", 1))),
			"ready_at_unix": maxi(0, int(slot.get("ready_at_unix", 0))),
			"source": String(slot.get("source", "manual")) if String(slot.get("source", "manual")) in ["manual", "automation"] else "manual",
			"automation_rule_id": String(slot.get("automation_rule_id", "")) if String(slot.get("source", "manual")) == "automation" else ""
		})
	return sanitized


func _sanitize_ingredient_processing_queue(raw_value: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if not raw_value is Array:
		return sanitized
	var processes := _processing_recipes()
	var ingredients := _ingredients()
	var active_process_ids: Dictionary = {}
	var used_sequences: Dictionary = {}
	var next_sequence := 1
	for queued_value: Variant in raw_value:
		if not queued_value is Dictionary:
			continue
		var queued: Dictionary = queued_value
		var process_id := String(queued.get("process_id", ""))
		if process_id.is_empty() or not processes.has(process_id) or active_process_ids.has(process_id):
			continue
		var process: Dictionary = processes[process_id]
		var output_item_id := String(queued.get("output_item_id", process.get("output_item_id", "")))
		if output_item_id.is_empty() or not ingredients.has(output_item_id):
			continue
		var queue_sequence := maxi(0, int(queued.get("queue_sequence", 0)))
		if queue_sequence <= 0 or used_sequences.has(queue_sequence):
			while used_sequences.has(next_sequence):
				next_sequence += 1
			queue_sequence = next_sequence
		used_sequences[queue_sequence] = true
		next_sequence = maxi(next_sequence, queue_sequence + 1)
		var started_at_unix := maxi(0, int(queued.get("started_at_unix", 0)))
		var duration_seconds := maxi(
			1,
			int(queued.get("duration_seconds", process.get("production_duration_seconds", 1)))
		)
		var ready_at_unix := maxi(
			started_at_unix + duration_seconds,
			int(queued.get("ready_at_unix", started_at_unix + duration_seconds))
		)
		sanitized.append({
			"queue_sequence": queue_sequence,
			"process_id": process_id,
			"device_id": String(queued.get("device_id", process.get("device", ""))),
			"output_item_id": output_item_id,
			"output_count": maxi(1, int(queued.get("output_count", process.get("output_count", 1)))),
			"started_at_unix": started_at_unix,
			"duration_seconds": duration_seconds,
			"ready_at_unix": ready_at_unix,
			"source": String(queued.get("source", "manual")) if String(queued.get("source", "manual")) in ["manual", "automation"] else "manual"
		})
		active_process_ids[process_id] = true
	return sanitized


func _sanitize_production_ready_recipe_records(raw_value: Variant) -> Dictionary:
	var sanitized: Dictionary = {}
	if not raw_value is Dictionary:
		return sanitized
	for recipe_id_value: Variant in (raw_value as Dictionary).keys():
		var recipe_id := String(recipe_id_value)
		var record_value: Variant = (raw_value as Dictionary).get(recipe_id_value, {})
		if recipe_id.is_empty() or not _recipes().has(recipe_id) or not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		var display_sequence := int(record.get("display_sequence", 0))
		if display_sequence <= 0:
			continue
		sanitized[recipe_id] = {
			"display_sequence": display_sequence,
			"last_completed_at_unix": maxi(0, int(record.get("last_completed_at_unix", 0)))
		}
	return sanitized


func _ensure_recipe_growth(recipe_id: String) -> void:
	if not recipe_growth.has(recipe_id):
		recipe_growth[recipe_id] = RecipeGrowthService.default_growth(recipe_id)


func _ensure_device_growth(device_id: String) -> void:
	if not device_growth.has(device_id):
		device_growth[device_id] = DeviceGrowthService.default_state()
	else:
		device_growth[device_id] = DeviceGrowthService.sanitize_state(device_growth[device_id])


func _sanitize_device_growth(raw_value: Variant) -> Dictionary:
	var result := {}
	if not raw_value is Dictionary:
		return result
	var devices := _devices()
	var raw: Dictionary = raw_value
	for device_id_value in raw:
		var device_id := String(device_id_value)
		if not DeviceGrowthService.supports_growth(device_id, devices):
			continue
		if not is_device_unlocked(device_id):
			continue
		result[device_id] = DeviceGrowthService.sanitize_state(raw[device_id_value])
	return result


func _update_recipe_growth(recipe_id: String, notify: bool, trigger: String = "generic", _natural_level_before: int = -1) -> Dictionary:
	var recipes := _recipes()
	if not recipes.has(recipe_id):
		return {}
	var before_level := int(recipe_growth.get(recipe_id, {}).get("mastery_level", 0))
	var device_level := _recipe_device_growth_level(recipe_id)
	var catalog := Catalog.new()
	var current_growth: Dictionary = recipe_growth.get(recipe_id, RecipeGrowthService.default_growth(recipe_id))
	var updated := RecipeGrowthService.advance_one_stage(
		recipe_id,
		current_growth,
		recipes[recipe_id],
		catalog.get_recipe_display_config(),
		device_level
	) if trigger in ["made", "round", "device"] else RecipeGrowthService.evaluate_growth(
		recipe_id,
		current_growth,
		recipes[recipe_id],
		catalog.get_recipe_display_config(),
		device_level
	)
	recipe_growth[recipe_id] = updated
	var after_level := int(updated.get("mastery_level", 0))
	if notify and after_level > before_level:
		var recipe_name := String(recipes[recipe_id].get("name", recipe_id))
		var next_requirement := RecipeGrowthService.stage_requirement(after_level)
		var fixed_benefit := "当前阶段进度已清零。"
		if after_level == RecipeGrowthService.MASTERY_POPULAR:
			fixed_benefit = "固定收益：售价 +5%；已开放第 1 项成长特性。"
		elif after_level == RecipeGrowthService.MASTERY_SIGNATURE:
			fixed_benefit = "新增固定收益：售价 +8%、售速 +5%；已开放第 2 项成长特性。"
		var next_device_level := int(next_requirement.get("device_level", 0))
		var next_requirement_text := "" if next_device_level <= 1 else " 下一阶段还需设备 L%d。" % next_device_level
		enqueue_notification(
			"%s 成长为%s" % [recipe_name, RecipeGrowthService.mastery_name(after_level)],
			"%s%s" % [fixed_benefit, next_requirement_text],
			{
				"kind": "recipe_growth_promoted",
				"recipe_id": recipe_id,
				"before_level": before_level,
				"after_level": after_level,
				"fixed_benefit": fixed_benefit,
				"pending_trait_choice": bool(updated.get("pending_trait_choice", false)),
				"next_device_level": next_device_level
			}
		)
		add_log("recipe_growth:%s:%d" % [recipe_id, after_level])
	elif notify:
		var status := RecipeGrowthService.stage_progress_status(updated, device_level)
		if bool(status.get("waiting_for_device", false)) and not bool(updated.get("stage_device_wait_notified", false)):
			updated["stage_device_wait_notified"] = true
			recipe_growth[recipe_id] = updated
			var recipe_name := String(recipes[recipe_id].get("name", recipe_id))
			var device_id := String(recipes[recipe_id].get("device", ""))
			var device_name := String(_devices().get(device_id, {}).get("name", "设备"))
			enqueue_notification(
				"%s 正在等待设备升级" % recipe_name,
				"制作与营业条件均已完成；将%s升至 L%d 后会立即检查晋级。" % [device_name, int(status.get("device_target_level", 1))],
				{"kind": "recipe_growth_device_wait", "recipe_id": recipe_id, "device_id": device_id, "target_level": int(status.get("device_target_level", 1))}
			)
	return updated.duplicate(true)


func _sanitize_recipe_growth(raw_value: Variant) -> Dictionary:
	var result := {}
	if not raw_value is Dictionary:
		return result
	var recipes := _recipes()
	var catalog := Catalog.new()
	var display_config := catalog.get_recipe_display_config()
	var raw: Dictionary = raw_value
	for recipe_id_value in raw.keys():
		var recipe_id := String(recipe_id_value)
		if not recipes.has(recipe_id):
			continue
		result[recipe_id] = RecipeGrowthService.sanitize_growth(recipe_id, raw[recipe_id_value], recipes[recipe_id], display_config, _recipe_device_growth_level(recipe_id))
	return result


func _recipe_device_growth_level(recipe_id: String) -> int:
	var recipe: Dictionary = _recipes().get(recipe_id, {})
	var device_id := String(recipe.get("device", ""))
	if device_id.is_empty():
		return 1
	return clampi(int(get_device_growth(device_id).get("level", 1)), 1, 5)


func _waiting_recipe_count_for_device(device_id: String) -> int:
	var count := 0
	var recipes := _recipes()
	var device_level := clampi(int(get_device_growth(device_id).get("level", 1)), 1, 5)
	for recipe_id in unlocked_recipes:
		if String(recipes.get(recipe_id, {}).get("device", "")) != device_id:
			continue
		var status := RecipeGrowthService.stage_progress_status(get_recipe_growth(recipe_id), device_level)
		if bool(status.get("waiting_for_device", false)):
			count += 1
	return count


func _try_activate_masterwork(recipe_id: String, notify: bool) -> bool:
	if not recipe_growth.has(recipe_id):
		return false
	var growth: Dictionary = recipe_growth[recipe_id]
	if int(growth.get("masterwork_level", 0)) > 0 or not RecipeGrowthService.can_activate_masterwork(growth):
		return false
	growth["masterwork_level"] = 1
	growth["masterwork_xp_tenths"] = 0
	recipe_growth[recipe_id] = growth
	if notify:
		var recipe_name := String(_recipes().get(recipe_id, {}).get("name", recipe_id))
		enqueue_notification(
			"%s 开启名作培养" % recipe_name,
			"招牌款与两项特性已经就绪，后续制作和真实销售将积累名作经验。",
			{"kind": "masterwork_activated", "recipe_id": recipe_id, "level": 1}
		)
	add_log("masterwork_activated:%s" % recipe_id)
	return true


func _add_masterwork_xp(recipe_id: String, xp_tenths: int, notify: bool) -> Dictionary:
	if xp_tenths <= 0 or not recipe_growth.has(recipe_id):
		return get_recipe_growth(recipe_id)
	var growth: Dictionary = recipe_growth[recipe_id]
	var before_level := int(growth.get("masterwork_level", 0))
	if before_level <= 0:
		return growth.duplicate(true)
	var before_xp := int(growth.get("masterwork_xp_tenths", 0))
	var after_xp := clampi(before_xp + xp_tenths, 0, RecipeGrowthService.MASTERWORK_MAX_XP_TENTHS)
	var after_level := RecipeGrowthService.masterwork_level_for_xp_tenths(after_xp)
	growth["masterwork_xp_tenths"] = after_xp
	growth["masterwork_level"] = after_level
	recipe_growth[recipe_id] = growth
	if notify and after_level > before_level:
		var recipe_name := String(_recipes().get(recipe_id, {}).get("name", recipe_id))
		var title := RecipeGrowthService.masterwork_title(recipe_name, after_level)
		var body := "名作经验 %.1f/%.1f。" % [after_xp / 10.0, RecipeGrowthService.masterwork_next_threshold(after_level) / 10.0]
		if not title.is_empty():
			body += " 获得称号：%s。" % title
		enqueue_notification(
			"%s 名作提升至 Lv.%d" % [recipe_name, after_level],
			body,
			{"kind": "masterwork_level_up", "recipe_id": recipe_id, "level": after_level}
		)
		add_log("masterwork_level:%s:%d" % [recipe_id, after_level])
	return growth.duplicate(true)


func _normalized_display_cells(recipe_id: String, cells: Array, variant_id: String = "", ignored_recipe_id: String = "") -> Array[Vector2i]:
	var normalized: Array[Vector2i] = []
	if recipe_id.is_empty() or cells.is_empty():
		return normalized
	if not is_recipe_unlocked(recipe_id):
		return normalized
	var recipes := _recipes()
	if not recipes.has(recipe_id):
		return normalized

	var display_config := Catalog.new().get_recipe_display_config()
	var recipe_display: Dictionary = display_config.get("recipes", {}).get(recipe_id, {})
	var configured_shape_cells := _display_shape_cells_from_value(recipe_display.get("shape_cells", []))
	var clean_variant_id := "standard" if variant_id.is_empty() else variant_id
	var expected_cell_count := _display_variant_cell_count(recipe_display, clean_variant_id)
	if cells.size() != expected_cell_count:
		return []

	var seen := {}
	for cell_value in cells:
		var cell := Vector2i.ZERO
		if cell_value is Vector2i:
			cell = cell_value
		elif cell_value is Array and cell_value.size() == 2:
			cell = Vector2i(int(cell_value[0]), int(cell_value[1]))
		else:
			return []
		if cell.x < 1 or cell.x > DISPLAY_GRID_ROWS or cell.y < 1 or cell.y > DISPLAY_GRID_COLUMNS:
			return []
		if not is_showcase_cell_unlocked(cell):
			return []
		var key := "%d:%d" % [cell.x, cell.y]
		if seen.has(key):
			return []
		seen[key] = true
		normalized.append(cell)

	if clean_variant_id == "standard" and not configured_shape_cells.is_empty() and not _cells_match_configured_shape(normalized, configured_shape_cells):
		return []

	if _cells_overlap_display_props(seen):
		return []

	for other_recipe_id in display_items.keys():
		if String(other_recipe_id) == recipe_id or String(other_recipe_id) == ignored_recipe_id:
			continue
		var other_cells: Array = display_items[other_recipe_id].get("cells", [])
		for other_cell in other_cells:
			var other := other_cell as Vector2i
			var key := "%d:%d" % [other.x, other.y]
			if seen.has(key):
				return []
	return normalized


func _normalized_prop_cells(prop_id: String, cells: Array) -> Array[Vector2i]:
	var normalized: Array[Vector2i] = []
	if prop_id.is_empty() or cells.is_empty() or not DISPLAY_PROP_SHAPES.has(prop_id):
		return normalized
	var shape_cells: Array = DISPLAY_PROP_SHAPES[prop_id].get("cells", [])
	if cells.size() != shape_cells.size():
		return []
	var seen := {}
	for cell_value in cells:
		var cell := Vector2i.ZERO
		if cell_value is Vector2i:
			cell = cell_value
		elif cell_value is Array and cell_value.size() == 2:
			cell = Vector2i(int(cell_value[0]), int(cell_value[1]))
		else:
			return []
		if cell.x < 1 or cell.x > DISPLAY_GRID_ROWS or cell.y < 1 or cell.y > DISPLAY_GRID_COLUMNS:
			return []
		if not is_showcase_cell_unlocked(cell):
			return []
		var key := "%d:%d" % [cell.x, cell.y]
		if seen.has(key):
			return []
		seen[key] = true
		normalized.append(cell)
	if _cells_overlap_display_items(seen) or _cells_overlap_other_props(prop_id, seen):
		return []
	return normalized


func _display_variant_cell_count(recipe_display: Dictionary, variant_id: String) -> int:
	var configured_shape_cells := _display_shape_cells_from_value(recipe_display.get("shape_cells", []))
	var base_count := configured_shape_cells.size() if not configured_shape_cells.is_empty() else maxi(1, int(recipe_display.get("cell_count", 1)))
	match variant_id:
		"small", "sample":
			return 1
		"gift_box", "large":
			return mini(DISPLAY_GRID_ROWS * DISPLAY_GRID_COLUMNS, base_count + 1)
		_:
			return base_count


func _cells_overlap_display_props(seen: Dictionary) -> bool:
	for prop_id in display_props.keys():
		var prop_cells: Array = display_props[prop_id].get("cells", [])
		for prop_cell in prop_cells:
			var cell := prop_cell as Vector2i
			if seen.has("%d:%d" % [cell.x, cell.y]):
				return true
	return false


func _cells_overlap_display_items(seen: Dictionary) -> bool:
	for recipe_id in display_items.keys():
		var item_cells: Array = display_items[recipe_id].get("cells", [])
		for item_cell in item_cells:
			var cell := item_cell as Vector2i
			if seen.has("%d:%d" % [cell.x, cell.y]):
				return true
	return false


func _cells_overlap_other_props(prop_id: String, seen: Dictionary) -> bool:
	for other_prop_id in display_props.keys():
		if String(other_prop_id) == prop_id:
			continue
		var prop_cells: Array = display_props[other_prop_id].get("cells", [])
		for prop_cell in prop_cells:
			var cell := prop_cell as Vector2i
			if seen.has("%d:%d" % [cell.x, cell.y]):
				return true
	return false


func _display_shape_cells_from_value(value: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not value is Array:
		return cells
	for cell_value in value:
		if cell_value is Vector2i:
			cells.append(cell_value)
		elif cell_value is Array and cell_value.size() == 2:
			cells.append(Vector2i(int(cell_value[0]), int(cell_value[1])))
	return cells


func _cells_match_configured_shape(cells: Array[Vector2i], shape_cells: Array[Vector2i]) -> bool:
	if cells.size() != shape_cells.size():
		return false
	var actual_keys := _normalized_display_shape_keys(cells)
	for variant in _display_shape_rotation_variants(shape_cells):
		if _display_shape_keys_match(actual_keys, _normalized_display_shape_keys(variant)):
			return true
	return false


func _recipe_queue_duration_seconds(recipe: Dictionary, batches: int, source: String = "manual") -> int:
	var base := maxi(1, int(recipe.get("production_duration_seconds", 1)))
	return base * maxi(1, batches) if source == "automation" else base


func _has_recipe_materials(materials: Array[String], batches: int) -> bool:
	var recipes := _recipes()
	for material_id in materials:
		var required := maxi(1, batches)
		if recipes.has(material_id):
			if not has_product(material_id, required):
				return false
		elif not has_ingredient(material_id, required):
			return false
	return true


func _consume_recipe_materials(materials: Array[String], batches: int) -> bool:
	if not _has_recipe_materials(materials, batches):
		return false
	var recipes := _recipes()
	for material_id in materials:
		var required := maxi(1, batches)
		var ok := remove_product(material_id, required) if recipes.has(material_id) else remove_ingredient(material_id, required)
		if not ok:
			return false
	return true


func _display_shape_rotation_variants(shape_cells: Array[Vector2i]) -> Array:
	var variants: Array = []
	var current := _normalized_display_shape_cells(shape_cells)
	for _turn in range(4):
		variants.append(current)
		current = _rotate_display_shape_cells_clockwise(current)
	return variants


func _rotate_display_shape_cells_clockwise(shape_cells: Array[Vector2i]) -> Array[Vector2i]:
	var rows := 0
	for cell in shape_cells:
		rows = maxi(rows, cell.x)
	var rotated: Array[Vector2i] = []
	for cell in shape_cells:
		rotated.append(Vector2i(cell.y, rows - cell.x + 1))
	return _normalized_display_shape_cells(rotated)


func _normalized_display_shape_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var normalized: Array[Vector2i] = []
	var min_row := DISPLAY_GRID_ROWS
	var min_col := DISPLAY_GRID_COLUMNS
	var found_cell := false
	for cell in cells:
		found_cell = true
		min_row = mini(min_row, cell.x)
		min_col = mini(min_col, cell.y)
	if not found_cell:
		return normalized
	for cell in cells:
		normalized.append(Vector2i(cell.x - min_row + 1, cell.y - min_col + 1))
	return normalized


func _normalized_display_shape_keys(cells: Array[Vector2i]) -> Dictionary:
	var keys := {}
	for cell in _normalized_display_shape_cells(cells):
		keys["%d:%d" % [cell.x, cell.y]] = true
	return keys


func _display_shape_keys_match(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key in left.keys():
		if not right.has(key):
			return false
	return true

func _resize_display_slots(slot_count: int) -> void:
	slot_count = DISPLAY_SLOT_COUNT
	while display_slots.size() < slot_count:
		display_slots.append(null)
	while display_slots.size() > slot_count:
		display_slots.pop_back()


func _display_slot_count_for_level(target_level: int) -> int:
	return DISPLAY_SLOT_COUNT


func _max_level() -> int:
	var max_level: int = INITIAL_LEVEL
	for upgrade_level: Variant in _upgrade_table().keys():
		max_level = maxi(max_level, int(upgrade_level))
	return max_level


func _recipes() -> Dictionary:
	return Catalog.new().get_recipes()


func _processing_recipes() -> Dictionary:
	return Catalog.new().get_processing_recipes()


func _ingredients() -> Dictionary:
	return Catalog.new().get_ingredients()


func _tools() -> Dictionary:
	return Catalog.new().get_tools()


func _devices() -> Dictionary:
	return Catalog.new().get_devices()


func _tool_matches_accelerator_target(tool_id: String, target_id: String) -> bool:
	var tools: Dictionary = _tools()
	if not tools.has(tool_id):
		return false

	var tool: Dictionary = tools[tool_id]
	var site_id := String(tool.get("compatible_site", ""))
	var production_sites: Dictionary = Catalog.new().get_production_sites()
	if not production_sites.has(site_id):
		return false
	if not target_id.begins_with("%s:" % site_id):
		return false

	var parts := target_id.split(":")
	if parts.size() != 2:
		return false

	var slot_index := int(parts[1])
	var site: Dictionary = production_sites[site_id]
	return slot_index >= 0 and slot_index < int(site.get("base_slots", 0))


func _upgrade_table() -> Dictionary:
	return Catalog.new().get_upgrade_table()
