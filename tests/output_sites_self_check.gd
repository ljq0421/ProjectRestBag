extends SceneTree

const GAME_STATE_PATH := "res://scripts/game_state.gd"
const PRODUCTION_SITE_PATH := "res://scripts/production_site.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var game_state_script := load(GAME_STATE_PATH)
	var production_site_script := load(PRODUCTION_SITE_PATH)
	if game_state_script == null:
		_fail("GameState script is missing")
		_finish()
		return
	if production_site_script == null:
		_fail("ProductionSite script is missing")
		_finish()
		return

	var cases := [
		{"site_id": "farm", "item_id": "rice_seed", "ready_at": 1002, "starter_inventory": {"rice_seed": 1}, "expected_inventory": {"rice": 3}},
		{"site_id": "ranch", "item_id": "chick", "ready_at": 1012, "starter_inventory": {"chick": 1}, "expected_inventory": {"egg": 2, "chicken": 1}},
		{"site_id": "forest", "item_id": "strawberry_seed", "ready_at": 1020, "starter_inventory": {"strawberry_seed": 1}, "expected_inventory": {"strawberry": 3}},
		{"site_id": "pond", "item_id": "spring_water_starter", "ready_at": 1010, "starter_inventory": {"spring_water_starter": 1}, "expected_inventory": {"spring_water": 2}, "consumed_inventory": {"spring_water_starter": 0}}
	]
	for case_value in cases:
		var case: Dictionary = case_value
		_expect_site_can_start_and_harvest(game_state_script, production_site_script, case)

	_finish()


func _expect_site_can_start_and_harvest(game_state_script, production_site_script, case: Dictionary) -> void:
	var state = game_state_script.new_game()
	state.level = 5
	var site_id := String(case.get("site_id", ""))
	var item_id := String(case.get("item_id", ""))
	var starter_inventory: Dictionary = case.get("starter_inventory", {})
	for starter_id: String in starter_inventory.keys():
		state.add_ingredient(starter_id, int(starter_inventory[starter_id]))
	var expected_inventory: Dictionary = case.get("expected_inventory", {})
	var inventory_before := {}
	for harvest_item_id: String in expected_inventory.keys():
		inventory_before[harvest_item_id] = state.get_ingredient_count(harvest_item_id)
	var started := bool(production_site_script.start_slot(state, site_id, item_id, 1000))
	if not started:
		_fail("%s should start %s in a new-game output area" % [site_id, item_id])
		return

	var slots: Array = state.to_dict().get("production_slots", [])
	if slots.size() != 1:
		_fail("%s should create exactly one slot, got %d" % [site_id, slots.size()])
		return

	var slot: Dictionary = slots[0]
	if String(slot.get("site_id", "")) != site_id:
		_fail("%s slot should keep site_id, got %s" % [site_id, String(slot.get("site_id", ""))])
	if String(slot.get("item_id", "")) != item_id:
		_fail("%s slot should keep item_id, got %s" % [site_id, String(slot.get("item_id", ""))])
	if int(slot.get("ready_at_unix", 0)) != int(case.get("ready_at", 0)):
		_fail("%s ready_at_unix expected %d, got %d" % [site_id, int(case.get("ready_at", 0)), int(slot.get("ready_at_unix", 0))])

	if bool(production_site_script.harvest_slot(state, 0, int(case.get("ready_at", 0)) - 1)):
		_fail("%s should not harvest before ready_at_unix" % site_id)
	if not bool(production_site_script.harvest_slot(state, 0, int(case.get("ready_at", 0)))):
		_fail("%s should harvest at ready_at_unix" % site_id)
	for harvest_item_id: String in expected_inventory.keys():
		var expected_total := int(inventory_before.get(harvest_item_id, 0)) + int(expected_inventory[harvest_item_id])
		if int(state.get_ingredient_count(harvest_item_id)) != expected_total:
			_fail("%s harvest should add %d %s for a total of %d, got %d" % [
				site_id,
				int(expected_inventory[harvest_item_id]),
				harvest_item_id,
				expected_total,
				int(state.get_ingredient_count(harvest_item_id))
			])
	var consumed_inventory: Dictionary = case.get("consumed_inventory", {})
	for consumed_item_id: String in consumed_inventory.keys():
		if int(state.get_ingredient_count(consumed_item_id)) != int(consumed_inventory[consumed_item_id]):
			_fail("%s production should consume to %d %s, got %d" % [
				site_id,
				int(consumed_inventory[consumed_item_id]),
				consumed_item_id,
				int(state.get_ingredient_count(consumed_item_id))
			])


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("OUTPUT_SITES_SELF_CHECK_PASS")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
