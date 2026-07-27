extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const PURCHASE_ROW_PATH := "res://scenes/ui/pages/purchase_quantity_row.tscn"
const RECIPE_ROW_PATH := "res://scenes/ui/pages/production_queue_recipe_row.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect_component_targets()
	await _expect_main_targets()
	_finish()


func _expect_component_targets() -> void:
	var purchase_row := (load(PURCHASE_ROW_PATH) as PackedScene).instantiate()
	_expect(purchase_row.has_method("tutorial_target"), "purchase row should expose semantic tutorial targets")
	if purchase_row.has_method("tutorial_target"):
		_expect(purchase_row.call("tutorial_target", "increase") == purchase_row.get_node("PurchasePlusButton"), "purchase increase target should be the plus button")
	purchase_row.free()

	var recipe_row := (load(RECIPE_ROW_PATH) as PackedScene).instantiate()
	recipe_row.call("configure", {
		"recipe_id": "rice_milk_drink",
		"entry_kind": "finished",
		"name": "Rice Milk Drink",
		"materials": [],
		"duration_seconds": 2,
		"price": 10,
		"action_kind": "make"
	})
	_expect(recipe_row.has_method("tutorial_target"), "recipe row should expose semantic tutorial targets")
	if recipe_row.has_method("tutorial_target"):
		_expect(recipe_row.call("tutorial_target", "make") == recipe_row.get_node("Content/ActionButton"), "recipe make target should be the row action button")
		_expect(recipe_row.call("tutorial_target", "list") == recipe_row.get_node("Content/ProductIconButton"), "recipe list target should be the row product icon")
	recipe_row.free()


func _expect_main_targets() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "Main scene should load")
	if packed == null:
		return
	var main := packed.instantiate() as Control
	main.set("save_path", OS.get_temp_dir().path_join("tutorial_guide_dynamic_target_self_check.json"))
	main.set("broken_save_path", OS.get_temp_dir().path_join("tutorial_guide_dynamic_target_self_check.broken.json"))
	root.add_child(main)
	await process_frame
	await process_frame
	_expect(main.has_method("_tutorial_target_for_step"), "MainView should resolve semantic tutorial targets")
	if not main.has_method("_tutorial_target_for_step"):
		main.queue_free()
		await process_frame
		return

	var state = GAME_STATE.new_game()
	main.set("state", state)
	main.call("_show_page", "purchase")
	await process_frame
	var purchase_plus := main.call("_tutorial_target_for_step", "purchase") as Control
	_expect(purchase_plus != null and purchase_plus.name == &"PurchasePlusButton", "empty rice-seed cart should target its plus button")
	main.call("_on_purchase_cart_quantity_pressed", "rice_seed", 1)
	var purchase_confirm := main.call("_tutorial_target_for_step", "purchase") as Control
	_expect(purchase_confirm == main.get("purchase_confirm_button"), "rice seed in cart should target the purchase overlay confirmation button")

	state.tutorial_guide_step = "output"
	state.add_ingredient("rice_seed", 1)
	main.call("_show_page", "output")
	await process_frame
	var output_idle := main.call("_tutorial_target_for_step", "output") as Control
	_expect(output_idle != null and String(output_idle.get_meta("site_id", "")) == "farm" and String(output_idle.get_meta("output_kind", "")) == "idle", "output should first target the farm idle slot")
	_expect(output_idle != main.get("primary_action_button"), "locked one-click harvest should never be a tutorial target")

	state.production_slots = [{
		"site_id": "farm", "slot_index": 0, "item_id": "rice_seed",
		"started_at_unix": 1, "duration_seconds": 1, "ready_at_unix": 2, "ready": true, "accelerator_id": ""
	}]
	main.call("_show_page", "output")
	await process_frame
	var ready_output := main.call("_tutorial_target_for_step", "output") as Control
	_expect(ready_output != null and String(ready_output.get_meta("site_id", "")) == "farm" and String(ready_output.get_meta("output_kind", "")) == "active", "ready tutorial output should target its manual slot")
	_expect(ready_output != main.get("primary_action_button"), "ready output should still avoid one-click harvest")

	state.tutorial_guide_step = "research"
	state.tutorial_guide_harvested_ids.assign(["rice", "spring_water"])
	state.add_ingredient("rice", 3)
	state.add_ingredient("spring_water", 2)
	state.unlock_device("round_pot")
	main.set("selected_research_material_ids", [])
	main.call("_show_page", "research")
	await process_frame
	var material_slot := main.call("_tutorial_target_for_step", "research") as Control
	_expect(material_slot != null and material_slot.has_meta("tutorial_research_slot_index"), "research should target an empty material slot")

	main.call("_on_research_material_cell_pressed", "rice")
	main.call("_on_research_material_cell_pressed", "spring_water")
	main.call("_on_research_tool_cell_pressed", "round_pot")
	main.call("_refresh_current_page")
	await process_frame
	var research_action := main.call("_tutorial_target_for_step", "research") as Control
	_expect(research_action == main.get("primary_action_button"), "complete rice-milk inputs should target research")

	state.tutorial_guide_step = "craft"
	state.add_recipe("rice_milk_drink")
	main.call("_refresh_current_page")
	await process_frame
	var craft_entry_target := main.call("_tutorial_target_for_step", "craft") as Control
	_expect(craft_entry_target != null and craft_entry_target.name == &"ActionButton", "craft tutorial should target the rice-milk queue-row action")

	state.tutorial_guide_step = "list"
	state.add_product("rice_milk_drink", 3)
	main.call("_refresh_current_page")
	await process_frame
	var list_target := main.call("_tutorial_target_for_step", "list") as Control
	_expect(list_target != null and list_target.name == &"ProductIconButton", "listing should target the rice-milk row product icon")

	state.tutorial_guide_step = "rulebook"
	var rulebook_target := main.call("_tutorial_target_for_step", "rulebook") as Control
	var expected_rulebook_target := main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/RulebookButton") as Control
	_expect(rulebook_target != null and rulebook_target == expected_rulebook_target, "rulebook step should target the showcase rulebook button")

	state.tutorial_guide_step = "storefront"
	var storefront_target := main.call("_tutorial_target_for_step", "storefront") as Control
	_expect(storefront_target == main.get("storefront_manage_button"), "final step should target storefront management")

	main.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TUTORIAL_GUIDE_DYNAMIC_TARGET_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("TUTORIAL_GUIDE_DYNAMIC_TARGET_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
