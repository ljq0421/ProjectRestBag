extends SceneTree

const SERVICE_PATH := "res://scripts/recipe_growth_service.gd"
const GAME_STATE_PATH := "res://scripts/game_state.gd"
const RecipeGrowthService := preload("res://scripts/recipe_growth_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	_finish()


func _run() -> void:
	var service = load(SERVICE_PATH)
	_expect(service != null, "RecipeGrowthService should load")
	if service == null:
		return

	var growth: Dictionary = service.default_growth("rice_milk_drink")
	_expect(int(growth.get("masterwork_level", -1)) == 0, "new recipes should not start as masterworks")
	_expect(int(growth.get("masterwork_xp_tenths", -1)) == 0, "new recipes should start with zero masterwork XP")

	var required_methods := [
		"can_activate_masterwork",
		"masterwork_level_for_xp_tenths",
		"masterwork_next_threshold",
		"masterwork_milestone",
		"masterwork_title"
	]
	for method_name in required_methods:
		_expect(service.has_method(method_name), "RecipeGrowthService should provide %s" % method_name)
	if _failures.size() > 0:
		return

	var inactive := {"mastery_level": RecipeGrowthService.MASTERY_SIGNATURE, "selected_traits": ["classic_price"]}
	var active := {"mastery_level": RecipeGrowthService.MASTERY_SIGNATURE, "selected_traits": ["classic_price", "sweet_speed"]}
	_expect(not service.can_activate_masterwork(inactive), "signature recipe with one trait should remain inactive")
	_expect(service.can_activate_masterwork(active), "signature recipe with two traits should activate masterwork")

	var thresholds := [0, 200, 500, 900, 1400, 2000, 2750, 3650, 4700, 6000]
	for index in range(thresholds.size()):
		_expect(int(service.masterwork_level_for_xp_tenths(thresholds[index])) == index + 1, "threshold %d should produce Lv.%d" % [thresholds[index], index + 1])
	_expect(int(service.masterwork_level_for_xp_tenths(999999)) == 10, "masterwork level should cap at Lv.10")

	_expect(String(service.masterwork_milestone(2).get("frame", "")) == "", "Lv.2 should not have a milestone frame")
	_expect(String(service.masterwork_milestone(3).get("frame", "")) == "silver", "Lv.3 should unlock a silver frame")
	_expect(bool(service.masterwork_milestone(6).get("glow", false)), "Lv.6 should unlock the shared glow")
	var level_ten: Dictionary = service.masterwork_milestone(10)
	_expect(String(level_ten.get("frame", "")) == "gold", "Lv.10 should unlock a gold frame")
	_expect(bool(level_ten.get("seal", false)), "Lv.10 should unlock the masterwork seal")
	_expect(String(service.masterwork_title("米浆饮", 10)) == "米浆饮名匠", "Lv.10 title should use the recipe-name-plus-master-craftsman format")
	_expect_masterwork_events()


func _expect_masterwork_events() -> void:
	var game_state_script = load(GAME_STATE_PATH)
	var state = game_state_script.new_game()
	state.unlock_device("round_pot")
	state.add_recipe("rice_milk_drink")
	state.device_growth["round_pot"] = {
		"level": 5,
		"use_count": 150,
		"research_count": 150,
		"production_batch_count": 0
	}
	state.recipe_growth["rice_milk_drink"] = {
		"mastery_level": RecipeGrowthService.MASTERY_POPULAR,
		"stage_made_batches": 40,
		"stage_effective_rounds": 14,
		"stage_synergy_rounds": 8,
		"made_count": 40,
		"sold_count": 25,
		"adjacency_trigger_count": 10,
		"display_traits": [],
		"available_traits": [],
		"selected_traits": [],
		"selected_display_traits": [],
		"pending_trait_choice": false,
		"masterwork_level": 0,
		"masterwork_xp_tenths": 0
	}
	state.record_recipe_made("rice_milk_drink", 1, 1, "manual")
	var signature: Dictionary = state.get_recipe_growth("rice_milk_drink")
	_expect(int(signature.get("mastery_level", 0)) == RecipeGrowthService.MASTERY_SIGNATURE, "qualified production should reach signature before masterwork")
	_expect(int(signature.get("masterwork_level", -1)) == 0, "signature production before trait selection should grant no masterwork XP")
	var traits: Array = signature.get("available_traits", [])
	_expect(traits.size() >= 2, "signature recipe should expose at least two trait candidates")
	if traits.size() < 2:
		return
	state.pending_notifications.clear()
	_expect(state.select_recipe_trait("rice_milk_drink", String(traits[0])), "first signature trait should be selectable")
	_expect(int(state.get_recipe_growth("rice_milk_drink").get("masterwork_level", -1)) == 0, "first trait should not activate masterwork")
	_expect(state.select_recipe_trait("rice_milk_drink", String(traits[1])), "second signature trait should be selectable")
	var activated: Dictionary = state.get_recipe_growth("rice_milk_drink")
	_expect(int(activated.get("masterwork_level", 0)) == 1, "second trait should activate masterwork at Lv.1")
	_expect(int(activated.get("masterwork_xp_tenths", -1)) == 0, "masterwork activation should not backfill prior events")
	_expect(state.pending_notifications.size() == 1, "masterwork activation should enqueue one notification")

	state.pending_notifications.clear()
	state.record_recipe_made("rice_milk_drink", 3, 1, "manual")
	_expect(int(state.get_recipe_growth("rice_milk_drink").get("masterwork_xp_tenths", 0)) == 24, "L5 manual batch should grant 2.4 XP")
	state.record_recipe_made("rice_milk_drink", 3, 1, "automation")
	_expect(int(state.get_recipe_growth("rice_milk_drink").get("masterwork_xp_tenths", 0)) == 36, "L5 automation batch should grant 1.2 XP")
	state.record_recipe_sold("rice_milk_drink", 2, false)
	_expect(int(state.get_recipe_growth("rice_milk_drink").get("masterwork_xp_tenths", 0)) == 76, "two sold items should grant four XP")
	var adjacency_before := int(state.get_recipe_growth("rice_milk_drink").get("adjacency_trigger_count", 0))
	state.record_recipe_sold("rice_milk_drink", 3, true)
	var after_sale: Dictionary = state.get_recipe_growth("rice_milk_drink")
	_expect(int(after_sale.get("masterwork_xp_tenths", 0)) == 166, "three positive-adjacency sales should grant nine XP")
	_expect(int(after_sale.get("adjacency_trigger_count", 0)) == adjacency_before + 1, "one positive sale event should add one adjacency trigger")

	state.recipe_growth["rice_milk_drink"]["masterwork_xp_tenths"] = 190
	state.recipe_growth["rice_milk_drink"]["masterwork_level"] = 1
	state.pending_notifications.clear()
	state.record_recipe_made("rice_milk_drink", 60, 20, "manual")
	var jumped: Dictionary = state.get_recipe_growth("rice_milk_drink")
	_expect(int(jumped.get("masterwork_level", 0)) == 3, "one large event should cross multiple masterwork thresholds")
	_expect(state.pending_notifications.size() == 1, "multi-level masterwork jump should enqueue one notification")

	state.recipe_growth["rice_milk_drink"]["masterwork_xp_tenths"] = 5900
	state.recipe_growth["rice_milk_drink"]["masterwork_level"] = 9
	state.pending_notifications.clear()
	state.record_recipe_made("rice_milk_drink", 30, 10, "manual")
	var capped: Dictionary = state.get_recipe_growth("rice_milk_drink")
	_expect(int(capped.get("masterwork_level", 0)) == 10, "masterwork should reach Lv.10")
	_expect(int(capped.get("masterwork_xp_tenths", 0)) == 6000, "masterwork XP should cap at 6000 tenths")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RECIPE_MASTERWORK_GROWTH_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
