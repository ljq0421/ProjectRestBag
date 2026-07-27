extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const GameState := preload("res://scripts/game_state.gd")
const RecipeGrowthService := preload("res://scripts/recipe_growth_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var required_methods := [
		"_on_device_growth_upgrade_requested",
		"_on_device_growth_catalog_filter_requested",
		"_on_catalog_device_filter_changed",
		"_on_growth_detail_trait_requested"
	]
	for method_name in required_methods:
		_expect(main.has_method(method_name), "Main should provide %s" % method_name)
	if required_methods.any(func(method_name): return not main.has_method(method_name)):
		main.queue_free()
		await process_frame
		_finish()
		return

	var state = GameState.new_game()
	state.tutorial_guide_skipped = true
	state.unlock_device("round_pot")
	state.add_recipe("rice_milk_drink")
	main.state = state
	main.call("_show_storefront_manage_global_popup")
	await process_frame
	var manage_page = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay")
	var growth_page = manage_page.get_node("StorefrontManagePanel/ManagementCenterPages/DeviceGrowthPage")
	manage_page.call("show_tab", "device_growth")
	_expect(growth_page.visible, "device growth should be a dedicated management-center tab")
	_expect((growth_page.get_node("DeviceSelectorPanel/DeviceButtons/round_pot") as Button).text.find("L1") != -1, "round pot selector should show L1")
	_expect(growth_page.get_node_or_null("DeviceSelectorPanel/DeviceButtons/grinder") == null, "ingredient grinder should not appear in product-device growth")
	_expect((growth_page.get_node("DeviceDetailColumns/UpgradePanel/UpgradeContent/RequirementLabel") as Label).text.find("有效使用") != -1, "device page should show the use gap")

	main.call("_on_device_growth_catalog_filter_requested", "round_pot")
	await process_frame
	_expect(String(main.selected_catalog_device_filter) == "round_pot", "device-page catalog action should set the round-pot filter")
	_expect(main.get_node("GlobalOverlayLayer").visible, "device-page catalog action should open the catalog overlay")
	_expect(main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay").visible, "device-page catalog action should switch to the catalog page")

	var recipe: Dictionary = main.catalog.get_recipes().get("rice_milk_drink", {})
	var card = main.call("_make_catalog_cell", "rice_milk_drink", recipe)
	_expect(card.get_node_or_null("StageBadge") is Label, "catalog recipe card should declare StageBadge")
	_expect(card.get_node_or_null("MasterworkBadge") is Label, "catalog recipe card should declare MasterworkBadge")
	card.queue_free()

	var detail_text := String(main.call("_catalog_action_detail_text", "rice_milk_drink"))
	_expect(detail_text.find("成长状态：成长阶段：试作品") != -1, "catalog action detail should show the current growth stage")
	state.device_growth["round_pot"]["level"] = 4
	state.recipe_growth["rice_milk_drink"] = state.get_recipe_growth("rice_milk_drink")
	state.recipe_growth["rice_milk_drink"]["made_count"] = 33
	detail_text = String(main.call("_catalog_action_detail_text", "rice_milk_drink"))
	_expect(detail_text.find("制作：33") != -1, "catalog action detail should show actual production count")

	state.device_growth["round_pot"]["level"] = 5
	state.recipe_growth["rice_milk_drink"] = {
		"mastery_level": RecipeGrowthService.MASTERY_POPULAR,
		"stage_made_batches": 40,
		"stage_effective_rounds": 14,
		"stage_synergy_rounds": 8,
		"made_count": 40,
		"sold_count": 25,
		"adjacency_trigger_count": 10,
		"selected_traits": [],
		"masterwork_level": 0,
		"masterwork_xp_tenths": 0
	}
	state.record_recipe_made("rice_milk_drink", 1, 1, "manual")
	var available_traits: Array = state.get_recipe_growth("rice_milk_drink").get("available_traits", [])
	_expect(available_traits.size() >= 2, "signature fixture should expose two traits for catalog refresh")
	if available_traits.size() >= 2:
		main.selected_catalog_recipe_id = "rice_milk_drink"
		main.catalog_overlay.visible = true
		main.call("_on_recipe_growth_trait_selected", "rice_milk_drink", String(available_traits[0]))
		main.call("_on_recipe_growth_trait_selected", "rice_milk_drink", String(available_traits[1]))
		detail_text = String(main.call("_catalog_action_detail_text", "rice_milk_drink"))
		_expect(detail_text.find("名作：Lv.1") != -1, "catalog action detail should reflect masterwork after the second trait activates it")

	var showcase_slot_scene := load("res://scenes/ui/storefront/showcase_slot.tscn") as PackedScene
	var showcase_slot = showcase_slot_scene.instantiate()
	root.add_child(showcase_slot)
	_expect(showcase_slot.has_method("set_masterwork_visual"), "showcase slot should provide shared masterwork visuals")
	_expect(showcase_slot.get_node_or_null("MasterworkFrame") is Panel, "showcase slot should declare MasterworkFrame")
	_expect(showcase_slot.get_node_or_null("MasterworkGlow") is ColorRect, "showcase slot should declare MasterworkGlow")
	_expect(showcase_slot.get_node_or_null("MasterworkSeal") is Label, "showcase slot should declare MasterworkSeal")
	if showcase_slot.has_method("set_masterwork_visual"):
		showcase_slot.call("set_masterwork_visual", 3, true)
		_expect(showcase_slot.get_node("MasterworkFrame").visible, "Lv.3 should show the shared silver frame")
		showcase_slot.call("set_masterwork_visual", 6, true)
		_expect(showcase_slot.get_node("MasterworkGlow").visible, "Lv.6 should show the shared glow")
		showcase_slot.call("set_masterwork_visual", 10, true)
		_expect(showcase_slot.get_node("MasterworkSeal").visible, "Lv.10 anchor should show the masterwork seal")
	showcase_slot.queue_free()

	var upgrade_state = GameState.new_game()
	upgrade_state.tutorial_guide_skipped = true
	upgrade_state.level = 5
	upgrade_state.unlock_device("round_pot")
	upgrade_state.add_recipe("rice_milk_drink")
	upgrade_state.coins = 500
	upgrade_state.device_growth["round_pot"] = {"level": 2, "research_count": 30, "production_batch_count": 0}
	upgrade_state.recipe_growth["rice_milk_drink"] = {
		"mastery_level": RecipeGrowthService.MASTERY_TRIAL,
		"stage_made_batches": 30,
		"stage_effective_rounds": 10,
		"stage_synergy_rounds": 3
	}
	main.state = upgrade_state
	main.call("_show_storefront_manage_global_popup")
	await process_frame
	_expect((manage_page.get_node("StorefrontManagePanel/ManagementCenterTabs/DeviceGrowthTab") as Button).text.find("1 可升级") != -1, "device tab should show the upgrade-ready count")
	main.call("_on_device_growth_upgrade_requested", "round_pot")
	var upgrade_status_label := main.get("status_label") as Label
	_expect(upgrade_status_label != null and upgrade_status_label.text.find("立即晋级") >= 0, "device upgrade status should describe immediate recipe promotion")
	_expect(upgrade_status_label == null or upgrade_status_label.text.find("下次成功制作") == -1, "device upgrade status should not retain the old next-production wording")

	main.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("DEVICE_RECIPE_GROWTH_UI_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
