extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const GameState := preload("res://scripts/game_state.gd")
const TEST_SAVE_PATH := "res://tests/research_recipe_restock_self_check.save.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var view = MainScene.instantiate()
	view.set("save_path", TEST_SAVE_PATH)
	root.add_child(view)
	await process_frame

	var test_state = GameState.new_game()
	test_state.level = 2
	test_state.coins = 100
	test_state.ingredient_inventory.clear()
	test_state.add_recipe("sponge_cake")
	view.set("state", test_state)

	if not view.has_method("_material_requirements") or not view.has_method("_recipe_restock_quote"):
		_expect(false, "main view should expose recipe restock quote helpers")
		view.free()
		_finish()
		return

	var requirements: Dictionary = view.call("_material_requirements", ["sugar", "sugar", "egg"])
	_expect(int(requirements.get("sugar", 0)) == 2, "duplicate materials should aggregate")
	_expect(int(requirements.get("egg", 0)) == 1, "single material should remain one unit")

	var bulk_state = GameState.new_game()
	bulk_state.level = 6
	bulk_state.coins = 9999
	bulk_state.ingredient_inventory.clear()
	bulk_state.product_inventory.clear()
	bulk_state.add_recipe("sponge_cake")
	bulk_state.add_recipe("cream_shortcake")
	bulk_state.add_recipe("butter_cookie")
	view.set("state", bulk_state)
	_expect(view.has_method("_research_bulk_restock_requirements"), "main view should aggregate bulk restock requirements")
	_expect(view.has_method("_research_bulk_restock_quote"), "main view should quote bulk restock")
	if view.has_method("_research_bulk_restock_requirements") and view.has_method("_research_bulk_restock_quote"):
		var actual: Dictionary = view.call("_research_bulk_restock_requirements")
		var expected := {}
		var recipes: Dictionary = view.get("catalog").get_recipes()
		var processes: Dictionary = view.get("catalog").get_processing_recipes()
		for recipe_id in view.call("_unlocked_recipe_ids"):
			for value: Variant in recipes.get(recipe_id, {}).get("materials", []):
				var id := String(value)
				expected[id] = int(expected.get(id, 0)) + 1
		for process_id in view.call("_available_process_ids"):
			for value: Variant in processes.get(process_id, {}).get("materials", []):
				var id := String(value)
				expected[id] = int(expected.get(id, 0)) + 1
		_expect(actual == expected, "bulk requirements should include every unlocked recipe and available process once")
		var shared_material_id := ""
		for material_id_value: Variant in expected.keys():
			var material_id := String(material_id_value)
			if int(expected.get(material_id, 0)) > 1:
				shared_material_id = material_id
				break
		_expect(not shared_material_id.is_empty(), "bulk fixture should include a shared material")
		var ingredients: Dictionary = view.get("catalog").get_ingredients()
		if ingredients.has(shared_material_id):
			bulk_state.add_ingredient(shared_material_id, 1)
		else:
			bulk_state.add_product(shared_material_id, 1)
		var bulk_quote: Dictionary = view.call("_research_bulk_restock_quote")
		var shared_missing := -1
		var sponge_missing := -1
		for value: Variant in bulk_quote.get("entries", []):
			var entry: Dictionary = value
			if String(entry.get("item_id", "")) == shared_material_id:
				shared_missing = int(entry.get("missing", -1))
			if String(entry.get("item_id", "")) == "sponge_cake":
				sponge_missing = int(entry.get("missing", -1))
		_expect(shared_missing == int(expected.get(shared_material_id, 0)) - 1, "shared inventory should be subtracted once after aggregation")
		_expect(sponge_missing > 0, "planned output should not satisfy a current product shortage")

	view.set("state", test_state)
	var quote: Dictionary = view.call("_recipe_restock_quote", "sponge_cake")
	_expect(bool(quote.get("ok", false)), "unlocked recipe should produce a restock quote")
	_expect(quote.get("entries", []) is Array, "quote should expose shortage entries")
	_expect(int(quote.get("total_cost", -1)) == 3, "sponge cake should only price one missing sugar")
	_expect(quote.get("purchasable_entries", []).size() == 1, "only sugar should be directly purchasable")
	_expect(quote.get("unavailable_entries", []).size() == 2, "flour and egg should remain unavailable")
	test_state.add_recipe("cream_shortcake")
	test_state.add_product("sponge_cake", 1)
	var layered_quote: Dictionary = view.call("_recipe_restock_quote", "cream_shortcake")
	var sponge_shortage_found := false
	for entry_value: Variant in layered_quote.get("entries", []):
		var entry: Dictionary = entry_value
		if String(entry.get("item_id", "")) == "sponge_cake":
			sponge_shortage_found = true
	_expect(not sponge_shortage_found, "owned recipe products should satisfy layered recipe requirements")

	if not view.has_method("_purchase_recipe_restock"):
		_expect(false, "main view should expose atomic recipe restock purchase")
		view.free()
		_finish()
		return

	var coins_before := int(test_state.coins)
	var purchase_result: Dictionary = view.call("_purchase_recipe_restock", "sponge_cake")
	_expect(bool(purchase_result.get("ok", false)), "affordable restock should succeed")
	_expect(int(test_state.coins) == coins_before - int(quote.get("total_cost", 0)), "restock should charge exact total")
	_expect(test_state.get_ingredient_count("sugar") == 1, "restock should add the missing sugar")
	_expect(test_state.get_ingredient_count("egg") == 0, "restock should not add unavailable egg")

	var poor_state = GameState.new_game()
	poor_state.level = 2
	poor_state.coins = 0
	poor_state.ingredient_inventory.clear()
	poor_state.add_recipe("sponge_cake")
	view.set("state", poor_state)
	var poor_inventory_before: Dictionary = poor_state.ingredient_inventory.duplicate(true)
	view.call("_on_recipe_restock_pressed", "sponge_cake")
	view.call("_on_recipe_restock_confirmed")
	_expect(int(poor_state.task_progress.get("feature_restock_all", {}).get("count", 0)) == 0, "failed confirmed single restock should not count progress")
	var failed_result: Dictionary = view.call("_purchase_recipe_restock", "sponge_cake")
	_expect(not bool(failed_result.get("ok", false)), "unaffordable restock should fail")
	_expect(int(poor_state.coins) == 0, "failed restock should preserve coins")
	_expect(poor_state.ingredient_inventory == poor_inventory_before, "failed restock should preserve inventory")

	_expect(view.has_method("_purchase_research_bulk_restock"), "main view should expose atomic bulk purchase")
	if view.has_method("_purchase_research_bulk_restock"):
		var poor_bulk_state = GameState.new_game()
		poor_bulk_state.level = 2
		poor_bulk_state.coins = 0
		poor_bulk_state.ingredient_inventory.clear()
		poor_bulk_state.add_recipe("butter_cookie")
		view.set("state", poor_bulk_state)
		var bulk_inventory_before: Dictionary = poor_bulk_state.ingredient_inventory.duplicate(true)
		var poor_bulk_result: Dictionary = view.call("_purchase_research_bulk_restock")
		_expect(String(poor_bulk_result.get("reason", "")) == "金币不足", "bulk purchase should report insufficient coins")
		_expect(int(poor_bulk_state.coins) == 0, "failed bulk purchase should preserve coins")
		_expect(poor_bulk_state.ingredient_inventory == bulk_inventory_before, "failed bulk purchase should preserve all inventory")

		var latest_state = GameState.new_game()
		latest_state.level = 2
		latest_state.coins = 9999
		latest_state.ingredient_inventory.clear()
		latest_state.add_recipe("butter_cookie")
		view.set("state", latest_state)
		var opened_bulk_quote: Dictionary = view.call("_research_bulk_restock_quote")
		latest_state.add_ingredient("sugar", 1)
		var latest_bulk_quote: Dictionary = view.call("_research_bulk_restock_quote")
		var latest_coins_before := int(latest_state.coins)
		var latest_result: Dictionary = view.call("_purchase_research_bulk_restock")
		_expect(bool(latest_result.get("ok", false)), "affordable bulk purchase should succeed")
		_expect(int(latest_state.coins) == latest_coins_before - int(latest_bulk_quote.get("total_cost", 0)), "bulk purchase should charge the latest quote")
		_expect(int(latest_bulk_quote.get("total_cost", 0)) <= int(opened_bulk_quote.get("total_cost", 0)), "new stock should not increase confirmation cost")

		var bulk_success_state = GameState.new_game()
		bulk_success_state.level = 2
		bulk_success_state.coins = 9999
		bulk_success_state.ingredient_inventory.clear()
		bulk_success_state.add_recipe("butter_cookie")
		bulk_success_state.unlock_feature("research_bulk_restock")
		view.set("state", bulk_success_state)
		view.call("_on_research_bulk_restock_pressed")
		view.call("_on_recipe_restock_confirmed")
		_expect(int(bulk_success_state.task_progress.get("feature_restock_all", {}).get("count", 0)) == 0, "successful bulk restock should not advance its own unlock task")

	var dialog = view.get_node_or_null("RecipeRestockDialog")
	_expect(dialog is ConfirmationDialog, "main scene should mount RecipeRestockDialog")
	if dialog != null:
		dialog.call("configure", quote)
		_expect(String(dialog.get_node("Body/RestockList").text).find("不可直接采购") != -1, "dialog should label unavailable shortages")
		_expect(String(dialog.get_node("Body/RestockList").text).find("单价 3｜小计 3 金币") != -1, "dialog should show unit price and subtotal")
		_expect(String(dialog.get_node("Body/TotalLabel").text).find(str(quote.get("total_cost", 0))) != -1, "dialog should show total cost")

	var bulk_button := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/ProductionQueueHeader/BulkActionButton") as MenuButton
	_expect(bulk_button != null, "production queue header should declare its bulk menu")
	var button_state = GameState.new_game()
	button_state.level = 2
	button_state.coins = 0
	button_state.ingredient_inventory.clear()
	button_state.add_recipe("butter_cookie")
	button_state.unlock_feature("research_bulk_restock")
	view.set("state", button_state)
	view.call("_refresh_current_page")
	await process_frame
	_expect(
		bulk_button != null and not bulk_button.get_popup().is_item_disabled(bulk_button.get_popup().get_item_index(1)),
		"production header should expose unlocked bulk restock"
	)
	view.call("_on_research_bulk_restock_pressed")
	_expect(dialog.visible and dialog.get_ok_button().disabled, "insufficient coins should disable confirmation")
	_expect(String(dialog.get_node("Body/HintLabel").text).find("金币不足") != -1, "dialog should explain insufficient coins")
	dialog.hide()

	var unavailable_bulk_quote: Dictionary = view.call("_research_bulk_restock_quote")
	for entry_value: Variant in unavailable_bulk_quote.get("purchasable_entries", []):
		var entry: Dictionary = entry_value
		button_state.add_ingredient(String(entry.get("item_id", "")), int(entry.get("missing", 0)))
	var unavailable_only_quote: Dictionary = view.call("_research_bulk_restock_quote")
	_expect((unavailable_only_quote.get("purchasable_entries", []) as Array).is_empty(), "unavailable-only bulk shortage should expose no purchasable entries")

	var remaining_bulk_quote: Dictionary = view.call("_research_bulk_restock_quote")
	var ingredients: Dictionary = view.get("catalog").get_ingredients()
	for entry_value: Variant in remaining_bulk_quote.get("unavailable_entries", []):
		var entry: Dictionary = entry_value
		var item_id := String(entry.get("item_id", ""))
		var amount := int(entry.get("missing", 0))
		if ingredients.has(item_id):
			button_state.add_ingredient(item_id, amount)
		else:
			button_state.add_product(item_id, amount)
	var full_bulk_quote: Dictionary = view.call("_research_bulk_restock_quote")
	_expect((full_bulk_quote.get("entries", []) as Array).is_empty(), "fully stocked bulk target should expose an empty quote")

	view.set("state", test_state)
	var missing_picker_entries: Array = view.call("_production_picker_entries", "missing")
	var sponge_entry := _entry_for_id(missing_picker_entries, "sponge_cake")
	_expect(not sponge_entry.is_empty(), "unlocked shortage should appear in the missing-material picker")
	if not sponge_entry.is_empty():
		_expect(not bool(sponge_entry.get("restockable", true)), "unavailable-only shortage should disable the card restock action")
		_expect(String(sponge_entry.get("reason", "")).find("不足") >= 0, "unavailable-only shortage should expose its reason")

	if not view.has_method("_on_recipe_restock_confirmed"):
		_expect(false, "main view should handle recipe restock confirmation")
		view.free()
		_finish()
		return

	var confirm_state = GameState.new_game()
	confirm_state.level = 2
	confirm_state.coins = 100
	confirm_state.ingredient_inventory.clear()
	confirm_state.add_recipe("butter_cookie")
	for feature_id in ["purchase", "output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage", "task"]:
		confirm_state.unlock_core_feature(feature_id)
	view.set("state", confirm_state)
	var purchasable_entry := _entry_for_id(view.call("_production_picker_entries", "missing"), "butter_cookie")
	_expect(not purchasable_entry.is_empty() and bool(purchasable_entry.get("restockable", false)), "purchasable shortage should keep card restock enabled")
	view.call("_on_recipe_restock_pressed", "butter_cookie")
	_expect(int(confirm_state.task_progress.get("feature_restock_all", {}).get("count", 0)) == 0, "opening a single restock quote should not count progress")
	var opened_quote: Dictionary = view.call("_recipe_restock_quote", "butter_cookie")
	_expect(int(opened_quote.get("total_cost", 0)) == 9, "empty butter cookie stock should quote butter and sugar")
	confirm_state.add_ingredient("sugar", 1)
	var latest_quote: Dictionary = view.call("_recipe_restock_quote", "butter_cookie")
	var confirm_coins_before := int(confirm_state.coins)
	_expect(dialog.confirmed.is_connected(Callable(view, "_on_recipe_restock_confirmed")), "dialog should connect its confirmed signal")
	dialog.confirmed.emit()
	_expect(int(confirm_state.coins) == confirm_coins_before - int(latest_quote.get("total_cost", 0)), "confirmation should charge the latest quote")
	_expect(confirm_state.get_ingredient_count("butter") == 1, "confirmation should buy missing butter")
	_expect(confirm_state.get_ingredient_count("sugar") == 1, "confirmation should not overbuy sugar added after opening")
	_expect(int(confirm_state.task_progress.get("feature_restock_all", {}).get("count", 0)) == 1, "successful confirmed single restock should count once")

	confirm_state.add_ingredient("flour", 1)
	dialog.hide()
	var full_stock_missing_entry := _entry_for_id(view.call("_production_picker_entries", "missing"), "butter_cookie")
	var full_stock_craftable_entry := _entry_for_id(view.call("_production_picker_entries", "craftable"), "butter_cookie")
	_expect(full_stock_missing_entry.is_empty(), "fully stocked recipe should leave the missing-material tab")
	_expect(not full_stock_craftable_entry.is_empty(), "fully stocked recipe should move to the craftable tab")
	view.call("_on_recipe_restock_pressed", "butter_cookie")
	_expect(not dialog.visible, "fully stocked recipe should not open restock dialog")
	var status_label: Label = view.get_node("Root/StatusBar/StatusLabel")
	_expect(status_label.text.find("当前配方材料充足") != -1, "fully stocked recipe should explain that materials are sufficient")

	view.free()
	_cleanup_test_save()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _entry_for_id(entries: Array, item_id: String) -> Dictionary:
	for entry_value: Variant in entries:
		if entry_value is Dictionary and String((entry_value as Dictionary).get("id", "")) == item_id:
			return entry_value as Dictionary
	return {}


func _finish() -> void:
	if failures.is_empty():
		print("RESEARCH_RECIPE_RESTOCK_SELF_CHECK: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _cleanup_test_save() -> void:
	for path in [TEST_SAVE_PATH, "%s.tmp" % TEST_SAVE_PATH]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
