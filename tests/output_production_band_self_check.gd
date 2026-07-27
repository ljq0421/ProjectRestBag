extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const GAME_STATE_PATH := "res://scripts/game_state.gd"
const CATALOG_PATH := "res://scripts/catalog.gd"
const EXPECTED_SITE_IMAGE := "res://resources/ui/output_v1/farm.png"
const NOW_UNIX := 1000

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("main scene should load")
		_finish()
		return

	var main := packed_scene.instantiate() as Control
	var save_path := OS.get_temp_dir().path_join("output_production_band_self_check.json")
	main.set("save_path", save_path)
	main.set("broken_save_path", save_path + ".broken")
	root.add_child(main)
	await process_frame
	await process_frame

	var game_state_script := load(GAME_STATE_PATH)
	_expect_eight_slot_limit(game_state_script)
	var state = game_state_script.new_game()
	state.level = 5
	state.production_slot_unlocks["farm"] = 8
	state.production_slots = [
		{
			"site_id": "farm",
			"slot_index": 0,
			"item_id": "wheat_seed",
			"started_at_unix": 880,
			"duration_seconds": 20,
			"ready_at_unix": 900
		},
		{
			"site_id": "farm",
			"slot_index": 4,
			"item_id": "glutinous_rice_seed",
			"started_at_unix": 990,
			"duration_seconds": 20,
			"ready_at_unix": 1010
		},
		_slot("farm", 1, "rice_seed"),
		_slot("farm", 2, "red_bean_seed"),
		_slot("farm", 3, "black_sesame_seed"),
		_slot("farm", 5, "pumpkin_seed"),
		_slot("farm", 6, "chestnut_seed"),
		_slot("farm", 7, "oats_seed"),
		_slot("farm", 8, "nuts"),
		_slot("forest", 0, "strawberry_seed"),
		_slot("forest", 1, "blueberry_seed"),
		_slot("forest", 2, "banana_seed"),
		_slot("forest", 3, "apple_seed"),
		_slot("forest", 4, "lemon_seed"),
		_slot("forest", 5, "peach_seed"),
		_slot("forest", 6, "orange_seed"),
		_slot("forest", 7, "mango_seed"),
		{
			"site_id": "ranch",
			"slot_index": 7,
			"item_id": "chick",
			"started_at_unix": 0,
			"duration_seconds": 12,
			"ready_at_unix": 0,
			"automation_paused": true,
			"pause_reason": {"code": "missing_input", "item_id": "chick"}
		}
	]
	main.set("state", state)

	_expect_cross_page_summary(main)
	main.call("_show_page", "output")
	await process_frame
	await process_frame
	_expect_horizontal_band(main)
	main.call("_change_output_site_page", "farm", 1)
	await process_frame
	await process_frame
	_expect_horizontal_band(main)
	var farm_region := _region_for(_output_row(main), "farm")
	var page_label := farm_region.get_node_or_null("OutputSiteBox/OutputSiteBody/PlotColumn/OutputSitePager/OutputPageLabel") as Label if farm_region != null else null
	if page_label == null or page_label.text != "2/2":
		_fail("changing page should update the four-plot page indicator below the plots")

	main.queue_free()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if FileAccess.file_exists(save_path + ".broken"):
		DirAccess.remove_absolute(save_path + ".broken")
	_finish()


func _expect_cross_page_summary(main: Control) -> void:
	if not main.has_method("_output_site_production_summary"):
		_fail("main view should expose the two-page production summary")
		return
	var summary_value: Variant = main.call("_output_site_production_summary", "farm", NOW_UNIX)
	if not summary_value is Array:
		_fail("farm production summary should be an Array")
		return
	var summary: Array = summary_value
	var wheat := _entry_for(summary, "wheat")
	var glutinous_rice := _entry_for(summary, "glutinous_rice")
	if int(wheat.get("ready_amount", 0)) != 3 or int(wheat.get("producing_amount", 0)) != 0:
		_fail("ready first-page wheat should aggregate as ready_amount 3")
	if int(glutinous_rice.get("ready_amount", 0)) != 0 or int(glutinous_rice.get("producing_amount", 0)) != 3:
		_fail("active second-page glutinous rice should aggregate as producing_amount 3")
	if not _entry_for(summary, "nuts").is_empty():
		_fail("slot index 8 should be outside the eight-slot production summary")
	var paused_summary: Array = main.call("_output_site_production_summary", "ranch", NOW_UNIX)
	if not paused_summary.is_empty():
		_fail("paused automation placeholder should not be reported as producing")


func _expect_horizontal_band(main: Control) -> void:
	var output_row := _output_row(main)
	if output_row == null or output_row.get_child_count() != 4:
		_fail("output page should render four production bands")
		return
	var farm_region := _region_for(output_row, "farm")
	if farm_region == null:
		_fail("farm production band should exist")
		return
	var body := farm_region.get_node_or_null("OutputSiteBox/OutputSiteBody") as HBoxContainer
	var identity_column := farm_region.get_node_or_null("OutputSiteBox/OutputSiteBody/SiteIdentityColumn") as VBoxContainer
	var plot_column := farm_region.get_node_or_null("OutputSiteBox/OutputSiteBody/PlotColumn") as VBoxContainer
	var pager := farm_region.get_node_or_null("OutputSiteBox/OutputSiteBody/PlotColumn/OutputSitePager") as HBoxContainer
	var site_image := farm_region.get_node_or_null("OutputSiteBox/OutputSiteBody/SiteIdentityColumn/OutputSiteImage") as TextureRect
	var summary_list := farm_region.get_node_or_null("OutputSiteBox/OutputSiteBody/ProductionSummaryPanel/ProductionSummaryBox/ProductionSummaryList") as VBoxContainer
	var summary_column := farm_region.get_node_or_null("OutputSiteBox/OutputSiteBody/ProductionSummaryPanel") as VBoxContainer
	var grid := farm_region.get_node_or_null("OutputSiteBox/OutputSiteBody/PlotColumn/OutputSiteGrid") as GridContainer
	if body == null:
		_fail("production band should use a stable horizontal body")
	if pager == null:
		_fail("page controls should sit below the production plots")
	if site_image == null or site_image.texture == null or site_image.texture.resource_path != EXPECTED_SITE_IMAGE:
		_fail("farm band should display the supplied farm image")
	elif site_image.custom_minimum_size != Vector2(132, 132):
		_fail("site image should reserve a 132x132 area")
	if identity_column == null or identity_column.custom_minimum_size.x < 132.0:
		_fail("site identity column should reserve at least 132px width")
	if summary_column == null or summary_column.custom_minimum_size.x < 96.0 or summary_column.custom_minimum_size.x > 104.0:
		_fail("production summary should use a compact width around 100px")
	if summary_list == null:
		_fail("production band should include the live production summary column")
	elif summary_list.get_child_count() != 8:
		_fail("production summary should show all eight valid outputs as single compact lines")
	else:
		_expect_single_line_summary(summary_list)
	if grid == null or grid.columns != 4 or grid.get_child_count() != 4:
		_fail("production band should show four larger current-page plot cells")
	var forest_region := _region_for(output_row, "forest")
	var forest_summary := forest_region.get_node_or_null("OutputSiteBox/OutputSiteBody/ProductionSummaryPanel/ProductionSummaryBox/ProductionSummaryList") as VBoxContainer if forest_region != null else null
	if forest_summary == null or forest_summary.get_child_count() != 8:
		_fail("all eight valid forest outputs should fit in the compact single-column summary")
	if body != null and body.get_child_count() >= 3:
		if body.get_child(0).name != "SiteIdentityColumn" \
				or body.get_child(1).name != "ProductionSummaryPanel" \
				or body.get_child(2).name != "PlotColumn":
			_fail("production band order should be image, summary, then plot column")
	if plot_column == null or plot_column.get_child_count() < 2 \
			or plot_column.get_child(0).name != "OutputSiteGrid" \
			or plot_column.get_child(1).name != "OutputSitePager":
		_fail("plot column should place the four plots above the pager")


func _expect_single_line_summary(summary_list: VBoxContainer) -> void:
	for entry_value: Variant in summary_list.get_children():
		var line := entry_value as Label
		if line == null:
			_fail("each production summary entry should be one plain Label")
			continue
		if line.get_theme_font_size("font_size") < 14:
			_fail("production summary lines should use readable 14px text")
		if line.text.find(" · ") == -1 or (line.text.find("待收获") == -1 and line.text.find("生产中") == -1):
			_fail("production status should follow the item name on the same line")


func _expect_eight_slot_limit(game_state_script) -> void:
	var catalog = (load(CATALOG_PATH)).new()
	for site_id in ["farm", "ranch", "forest", "pond"]:
		if int(catalog.get_production_sites().get(site_id, {}).get("base_slots", 0)) != 8:
			_fail("%s should expose exactly eight production slots" % site_id)
	var loaded = game_state_script.from_dict({
		"production_slot_unlocks": {"farm": 10},
		"production_slots": [_slot("farm", 7, "oats_seed"), _slot("farm", 8, "nuts")]
	})
	if int(loaded.production_slot_unlocks.get("farm", 0)) != 8:
		_fail("loaded production unlock count should clamp to eight")
	if loaded.production_slots.size() != 1 or int((loaded.production_slots[0] as Dictionary).get("slot_index", -1)) != 7:
		_fail("loading should discard production slots beyond index 7")


func _entry_for(summary: Array, item_id: String) -> Dictionary:
	for entry_value: Variant in summary:
		if entry_value is Dictionary and String((entry_value as Dictionary).get("item_id", "")) == item_id:
			return entry_value as Dictionary
	return {}


func _slot(site_id: String, slot_index: int, item_id: String) -> Dictionary:
	return {
		"site_id": site_id,
		"slot_index": slot_index,
		"item_id": item_id,
		"started_at_unix": 990,
		"duration_seconds": 20,
		"ready_at_unix": 1010
	}


func _region_for(output_row: Control, site_id: String) -> Control:
	for child_value: Variant in output_row.get_children():
		if child_value is Control and String((child_value as Control).get_meta("site_id", "")) == site_id:
			return child_value as Control
	return null


func _output_row(main: Control) -> Control:
	var output_row := main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputScroll/OutputGridRow")
	return output_row as Control


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("OUTPUT_PRODUCTION_BAND_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("OUTPUT_PRODUCTION_BAND_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
