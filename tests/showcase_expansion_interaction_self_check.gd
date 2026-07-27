extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const GameState := preload("res://scripts/game_state.gd")

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var state = GameState.new_game()
	state.level = 2
	state.shop_level = 2
	state.coins = 1000
	state.add_recipe("butter_cookie")
	_expect(state.place_display_item("butter_cookie", [Vector2i(5, 6)]), "fixture should place a zero-stock product")
	main.set("state", state)
	main.call("_refresh_showcase_layout_projection")
	main.call("_show_page", "storefront_manage")
	main.call("_enter_showcase_expansion_mode")
	await process_frame
	var toolbar: Control = main.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ExpansionToolbar")
	_expect(toolbar.visible, "entering expansion should reveal the real-grid toolbar")
	_expect(bool(main.get("showcase_expansion_active")), "entering expansion should set the interaction mode")
	var grid: GridContainer = main.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid")
	_expect(grid.custom_minimum_size.y == 780.0, "expansion mode should compact the grid so the toolbar remains visible at 1080p")
	var product_button: Button = grid.get_child(61)
	_expect(String(product_button.get_meta("recipe_id", "")) == "butter_cookie", "fixture product should render in the expansion grid")
	_expect(product_button.call("_get_drag_data", Vector2.ZERO) == null, "expansion mode should prevent listed products from starting a drag")

	# Row 4, column 6 is directly above the initial area.
	main.call("_select_showcase_expansion_from_slot", 47)
	var selected: Array = main.get("showcase_expansion_selected_cells")
	_expect(selected == [Vector2i(4, 6)], "clicking an adjacent locked cell should select it")
	var quote_label: Label = main.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ExpansionToolbar/ExpansionContent/ExpansionQuoteLabel")
	_expect(quote_label.text.find("300") >= 0 and quote_label.text.find("余额 1000") >= 0, "selection should expose live price and balance")
	main.call("_confirm_showcase_expansion_purchase")
	_expect(state.is_showcase_cell_unlocked(Vector2i(4, 6)), "confirmation should unlock the selected cell")
	_expect(state.coins == 700, "confirmation should deduct the final atomic quote")

	main.call("_set_showcase_expansion_tool", "row")
	main.call("_select_showcase_expansion_from_slot", 46)
	selected = main.get("showcase_expansion_selected_cells")
	_expect(selected == [Vector2i(4, 5), Vector2i(4, 7), Vector2i(4, 8), Vector2i(4, 9)], "row tool should select every locked cell directly touching the pre-purchase area")
	var confirm_button: Button = main.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ExpansionToolbar/ExpansionContent/ExpansionActionRow/ExpansionConfirmButton")
	_expect(confirm_button.disabled, "an unaffordable row quote should stay visible but disable confirmation")
	main.call("_cancel_showcase_expansion_mode")
	_expect(not toolbar.visible and not bool(main.get("showcase_expansion_active")), "cancel should clear and hide expansion mode")
	_expect(grid.custom_minimum_size.y == 864.0, "leaving expansion should restore normal showcase cell size")

	main.queue_free()
	_finish()


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SHOWCASE_EXPANSION_INTERACTION_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
