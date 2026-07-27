extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const GAME_STATE_PATH := "res://scripts/game_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	var game_state_script := load(GAME_STATE_PATH)
	if packed_scene == null or game_state_script == null:
		_fail("missing main scene or game state script")
		_finish()
		return

	var main := packed_scene.instantiate() as Control
	root.add_child(main)
	await process_frame
	await process_frame

	var state = game_state_script.new_game()
	state.level = 5
	state.shop_level = 5
	main.set("state", state)

	var now := int(Time.get_unix_time_from_system())
	var ranch_cases: Array[Dictionary] = [
		{"item_id": "chick", "outputs": {"egg": 2, "chicken": 1}, "label": "ranch chick"},
		{"item_id": "calf", "outputs": {"milk": 2, "beef": 1}, "label": "ranch calf"},
		{"item_id": "duckling", "outputs": {"duck_egg": 2, "duck_meat": 1}, "label": "ranch duckling"},
		{"item_id": "lamb", "outputs": {"goat_milk": 2, "mutton": 1}, "label": "ranch lamb"}
	]
	var ranch_cells: Array[Button] = []
	for index in ranch_cases.size():
		var ranch_case: Dictionary = ranch_cases[index]
		var ranch_cell := main.call("_make_active_output_cell", index, {
			"site_id": "ranch",
			"slot_index": index,
			"item_id": String(ranch_case.get("item_id", "")),
			"started_at_unix": now - 5,
			"ready_at_unix": now + 15,
			"duration_seconds": 20
		}) as Button
		ranch_cells.append(ranch_cell)
		_expect_product_cell(ranch_cell, ranch_case.get("outputs", {}), true, String(ranch_case.get("label", "ranch")))

	var forest_cell := main.call("_make_active_output_cell", 1, {
		"site_id": "forest",
		"slot_index": 0,
		"item_id": "strawberry_seed",
		"started_at_unix": now - 5,
		"ready_at_unix": now + 15,
		"duration_seconds": 20
	}) as Button
	_expect_product_cell(forest_cell, {"strawberry": 3}, false, "forest strawberry")
	_expect_main_view_missing_texture_contract(main)
	_expect_missing_icon_fallback_and_overflow()

	for ranch_cell in ranch_cells:
		if ranch_cell != null:
			ranch_cell.free()
	if forest_cell != null:
		forest_cell.free()
	main.queue_free()
	_finish()


func _expect_main_view_missing_texture_contract(main: Control) -> void:
	if not main.has_method("_output_product_entry"):
		_fail("main view should build output entries through a dedicated missing-texture-safe helper")
		return
	var product: Dictionary = main.call("_output_product_entry", "missing_actual_output", 2)
	if String(product.get("id", "")) != "missing_actual_output" or int(product.get("amount", 0)) != 2:
		_fail("main view output entry should preserve the actual output id and amount")
	if product.get("texture") != null:
		_fail("main view should leave a missing actual-output texture null so the cell renders ?")


func _expect_missing_icon_fallback_and_overflow() -> void:
	var packed_cell := load("res://scenes/ui/pages/output_cell.tscn") as PackedScene
	var cell := packed_cell.instantiate() as Button
	var products: Array[Dictionary] = [
		{"id": "missing_a", "name": "缺图甲", "amount": 2, "texture": null},
		{"id": "missing_b", "name": "缺图乙", "amount": 1, "texture": null},
		{"id": "missing_c", "name": "缺图丙", "amount": 4, "texture": null}
	]
	cell.configure_products(products)
	var primary_missing := cell.get_node_or_null("ProductDisplayArea/PrimaryProductIcon/MissingIconLabel") as Label
	var secondary_missing := cell.get_node_or_null("ProductDisplayArea/SecondaryProductIcon/MissingIconLabel") as Label
	if primary_missing == null or not primary_missing.visible or secondary_missing == null or not secondary_missing.visible:
		_fail("missing product textures should render visible fallback markers")
	var overflow := cell.get_node_or_null("ProductDisplayArea/OverflowLabel") as Label
	if overflow == null or not overflow.visible or overflow.text != "+1":
		_fail("three products should render a +1 overflow badge")
	if cell.tooltip_text.find("缺图甲 ×2") == -1 or cell.tooltip_text.find("缺图丙 ×4") == -1:
		_fail("overflow product tooltip should retain the complete output list")
	cell.free()


func _expect_product_cell(cell: Button, expected_outputs: Dictionary, expects_dual: bool, label: String) -> void:
	if cell == null:
		_fail("%s should create an active output cell" % label)
		return
	if cell.custom_minimum_size != Vector2(112, 112):
		_fail("%s should remain 112x112, got %s" % [label, str(cell.custom_minimum_size)])
	if not cell.text.is_empty():
		_fail("%s should not render product names, countdowns, or status text in the button" % label)

	var display_area := cell.get_node_or_null("ProductDisplayArea") as Control
	if display_area == null:
		_fail("%s should contain ProductDisplayArea" % label)
		return
	if display_area.custom_minimum_size != Vector2(112, 96):
		_fail("%s ProductDisplayArea should be 112x96, got %s" % [label, str(display_area.custom_minimum_size)])

	var primary := display_area.get_node_or_null("PrimaryProductIcon") as TextureRect
	var secondary := display_area.get_node_or_null("SecondaryProductIcon") as TextureRect
	if primary == null or secondary == null:
		_fail("%s should contain stable primary and secondary product icon nodes" % label)
		return
	if not primary.visible or primary.texture == null:
		_fail("%s should show a loaded primary product icon" % label)
	if secondary.visible != expects_dual:
		_fail("%s secondary product icon visibility expected %s" % [label, str(expects_dual)])
	if expects_dual and secondary.texture == null:
		_fail("%s should load the secondary product icon" % label)

	var expected_icon_size := Vector2(60, 60) if expects_dual else Vector2(92, 92)
	if primary.custom_minimum_size != expected_icon_size:
		_fail("%s primary icon should be %s, got %s" % [label, str(expected_icon_size), str(primary.custom_minimum_size)])
	if expects_dual and secondary.custom_minimum_size != Vector2(60, 60):
		_fail("%s secondary icon should be 60x60, got %s" % [label, str(secondary.custom_minimum_size)])
	if expects_dual:
		if primary.position != Vector2(0, 8) or secondary.position != Vector2(52, 28):
			_fail("%s dual icons should use the approved overlap positions, got %s and %s" % [label, str(primary.position), str(secondary.position)])
		var horizontal_overlap := primary.position.x + 60.0 - secondary.position.x
		if not is_equal_approx(horizontal_overlap, 8.0):
			_fail("%s dual icons should overlap horizontally by 8px, got %.1f" % [label, horizontal_overlap])
	elif primary.position != Vector2(10, 2):
		_fail("%s single icon should remain centered in the 112x96 display area, got %s" % [label, str(primary.position)])

	var expected_ids: Array = expected_outputs.keys()
	var actual_ids := [String(primary.get_meta("item_id", ""))]
	if expects_dual:
		actual_ids.append(String(secondary.get_meta("item_id", "")))
	if actual_ids != expected_ids:
		_fail("%s should show actual harvest outputs %s, got %s" % [label, str(expected_ids), str(actual_ids)])

	var primary_quantity := primary.get_node_or_null("QuantityLabel") as Label
	if primary_quantity == null or primary_quantity.text != "×%d" % int(expected_outputs.get(expected_ids[0], 0)):
		_fail("%s should show the primary output quantity" % label)
	if expects_dual:
		var secondary_quantity := secondary.get_node_or_null("QuantityLabel") as Label
		if secondary_quantity == null or secondary_quantity.text != "×%d" % int(expected_outputs.get(expected_ids[1], 0)):
			_fail("%s should show the secondary output quantity" % label)

	var automation_status := cell.get_node_or_null("AutomationStatusLabel") as Label
	if automation_status != null and automation_status.visible:
		_fail("%s should not show per-cell automation/status text" % label)
	if cell.get_node_or_null("ProductionProgressBar") == null:
		_fail("%s should retain the top production progress bar" % label)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("OUTPUT_CELL_PRODUCT_ICONS_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("OUTPUT_CELL_PRODUCT_ICONS_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
