extends SceneTree

const TASK_CATALOG_SERVICE_PATH := "res://scripts/task_catalog_service.gd"
const GAME_DATA_PATH := "res://game_data.json"
const REQUIRED_CATEGORIES := [
	"tutorial_tasks",
	"round_contracts",
	"growth_tasks",
	"side_tasks"
]

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service = load(TASK_CATALOG_SERVICE_PATH)
	if service == null:
		_fail("TaskCatalogService should exist")
		_finish()
		return

	var data := _load_game_data()
	var catalog: Dictionary = service.load_catalog()
	for category in REQUIRED_CATEGORIES:
		_expect(catalog.has(category), "Task catalog should include %s" % category)
		_expect(catalog.get(category, []) is Array, "%s should be an array" % category)

	var definitions: Dictionary = service.definitions_by_id(catalog)
	for task_id in [
		"growth_l1_sales_rhythm",
		"growth_l3_inventory_pressure",
		"contract_fast_turnover",
		"daily_farm_harvest",
		"feature_output_automation",
		"feature_kitchen_automation"
	]:
		_expect(definitions.has(task_id), "Unified task catalog should include %s" % task_id)
	_expect_equal("NPC tutorial should not create task cards", (catalog.get("tutorial_tasks", []) as Array).size(), 0)
	_expect_equal("simplified Lv.1-Lv.5 growth task count", (catalog.get("growth_tasks", []) as Array).size(), 7)
	for removed_id in ["tutorial_l0_first_product", "tutorial_l0_open_shop", "tutorial_l0_first_business"]:
		_expect(not definitions.has(removed_id), "Removed tutorial task should stay absent: %s" % removed_id)
	var first_growth: Dictionary = definitions.get("growth_l1_sales_rhythm", {})
	_expect((first_growth.get("prerequisites", []) as Array).is_empty(), "First Lv.1 growth task should not reference deleted tutorials")
	var raw_tasks: Dictionary = data.get("tasks", {})
	for legacy_group in ["build_courses", "stage_evaluations", "resource_side_tasks"]:
		_expect(not raw_tasks.has(legacy_group), "Legacy task group should be removed: %s" % legacy_group)
	_expect(not definitions.has("tutorial_l0_inspect_terms"), "Sales terms should not be a standalone tutorial task")
	for legacy_id in [
		"tutorial_l0_gather", "tutorial_l0_craft", "tutorial_l0_list", "tutorial_l0_start_round", "tutorial_l0_real_sale", "tutorial_l0_settle",
		"course_l1_standard_round", "course_l2_two_roles", "build_l3_refill_pressure", "evaluation_l5_signature"
	]:
		_expect(not definitions.has(legacy_id), "Legacy task id should be removed: %s" % legacy_id)
	_expect((catalog.get("round_contracts", []) as Array).size() >= 3, "Lv.6+ should have at least three contract templates")
	for contract_value in catalog.get("round_contracts", []):
		var contract: Dictionary = contract_value
		_expect(not (contract.get("reward", {}) as Dictionary).has("rating_points"), "Store rating should be applied at settlement, not as a claimable reward")
		_expect(not (contract.get("tiers", []) as Array).is_empty(), "Every repeatable contract should keep rating tiers")
	for task_value in definitions.values():
		if not task_value is Dictionary:
			continue
		var task: Dictionary = task_value
		var task_type := String(task.get("type", ""))
		if ["tutorial", "growth"].has(task_type):
			_expect(not task.has("tiers"), "%s should not contain rating tiers" % String(task.get("id", "")))
			_expect(not task.has("required_tier"), "%s should not require a rating tier" % String(task.get("id", "")))
		if task_type == "growth" and int(task.get("level", 0)) >= 3:
			_expect_equal("Lv.3+ growth event", String(task.get("event", "")), "business_round_completed")

	var automation: Dictionary = data.get("automation", {})
	_expect(not automation.has("feature_tasks"), "Automation config should not keep a second task-definition catalog")
	var feature_unlocks: Dictionary = automation.get("feature_unlocks", {})
	for feature_value: Variant in feature_unlocks.values():
		if not feature_value is Dictionary:
			continue
		var task_id := String((feature_value as Dictionary).get("task_id", ""))
		_expect(definitions.has(task_id), "Automation feature task reference should resolve: %s" % task_id)

	var daily_ids: Array[String] = service.task_ids_with_reset_policy(catalog, "daily")
	_expect(daily_ids.size() == 7, "Catalog should keep all seven configured daily resource tasks")
	_expect(daily_ids.has("daily_neighbor_gift"), "Disabled daily tasks should remain defined for future availability")

	var validation_errors: Array[String] = service.validate_catalog(catalog, data)
	for error in validation_errors:
		_fail("Task catalog validation should pass: %s" % error)

	var invalid_catalog := catalog.duplicate(true)
	var invalid_tutorials: Array = invalid_catalog.get("tutorial_tasks", [])
	if not invalid_tutorials.is_empty():
		var duplicate: Dictionary = (invalid_tutorials[0] as Dictionary).duplicate(true)
		invalid_tutorials.append(duplicate)
		invalid_catalog["tutorial_tasks"] = invalid_tutorials
		_expect(
			not service.validate_catalog(invalid_catalog, data).is_empty(),
			"Duplicate task ids should fail catalog validation"
		)

	var invalid_objectives := catalog.duplicate(true)
	var invalid_rows: Array = (invalid_objectives.get("tutorial_tasks", []) as Array).duplicate(true)
	if not invalid_rows.is_empty():
		var invalid_task: Dictionary = (invalid_rows[0] as Dictionary).duplicate(true)
		var objectives: Array = (invalid_task.get("objectives", []) as Array).duplicate(true)
		if not objectives.is_empty():
			objectives.append((objectives[0] as Dictionary).duplicate(true))
			invalid_task["objectives"] = objectives
			invalid_rows[0] = invalid_task
			invalid_objectives["tutorial_tasks"] = invalid_rows
			_expect(not service.validate_catalog(invalid_objectives, data).is_empty(), "Duplicate objective ids should fail catalog validation")

	for invalid_notification: Variant in [
		{"title": "", "body": "缺少标题"},
		{"title": "缺少正文", "body": ""},
		"invalid"
	]:
		var invalid_notification_catalog := catalog.duplicate(true)
		var notification_rows: Array = (invalid_notification_catalog.get("tutorial_tasks", []) as Array).duplicate(true)
		if notification_rows.is_empty():
			continue
		var notification_task: Dictionary = (notification_rows[0] as Dictionary).duplicate(true)
		var notification_objectives: Array = (notification_task.get("objectives", []) as Array).duplicate(true)
		if notification_objectives.is_empty():
			continue
		var notification_objective: Dictionary = (notification_objectives[0] as Dictionary).duplicate(true)
		notification_objective["notification"] = invalid_notification
		notification_objectives[0] = notification_objective
		notification_task["objectives"] = notification_objectives
		notification_rows[0] = notification_task
		invalid_notification_catalog["tutorial_tasks"] = notification_rows
		var notification_errors: Array[String] = service.validate_catalog(invalid_notification_catalog, data)
		_expect(_contains_text(notification_errors, "tutorial_l0_first_product:gather_material"), "Invalid objective notification should identify its task and objective")

	for invalid_item_ids: Variant in [[], ["missing_tutorial_material"], "invalid"]:
		var invalid_material_catalog := catalog.duplicate(true)
		var material_rows: Array = (invalid_material_catalog.get("tutorial_tasks", []) as Array).duplicate(true)
		if material_rows.is_empty():
			continue
		var material_task: Dictionary = (material_rows[0] as Dictionary).duplicate(true)
		var material_objectives: Array = (material_task.get("objectives", []) as Array).duplicate(true)
		if material_objectives.is_empty():
			continue
		var material_objective: Dictionary = (material_objectives[0] as Dictionary).duplicate(true)
		var material_condition: Dictionary = (material_objective.get("condition", {}) as Dictionary).duplicate(true)
		material_condition["item_ids"] = invalid_item_ids
		material_objective["condition"] = material_condition
		material_objectives[0] = material_objective
		material_task["objectives"] = material_objectives
		material_rows[0] = material_task
		invalid_material_catalog["tutorial_tasks"] = material_rows
		var material_errors: Array[String] = service.validate_catalog(invalid_material_catalog, data)
		_expect(_contains_text(material_errors, "tutorial_l0_first_product:gather_material"), "Invalid objective item_ids should identify its task and objective")

	_finish()


func _objective_by_id(task_value: Variant, objective_id: String) -> Dictionary:
	if not task_value is Dictionary:
		return {}
	for objective_value: Variant in (task_value as Dictionary).get("objectives", []):
		if objective_value is Dictionary and String((objective_value as Dictionary).get("id", "")) == objective_id:
			return objective_value
	return {}


func _contains_text(values: Array[String], expected: String) -> bool:
	for value in values:
		if value.contains(expected):
			return true
	return false


func _load_game_data() -> Dictionary:
	var file := FileAccess.open(GAME_DATA_PATH, FileAccess.READ)
	if file == null:
		_fail("Could not open game_data.json")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("game_data.json should parse as a dictionary")
		return {}
	return parsed


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TASK_CATALOG_CONFIG_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)
