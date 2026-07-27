extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const AUTOMATION_SPEC_PATH := "res://docs/superpowers/specs/2026-07-10-automation-starlight-design.zh.md"
const VIEWPORT_SIZE := Vector2i(1920, 1080)

const REQUIRED_SHELL_NODES := [
	"Root/TopBar",
	"Root/Body/MainArea/StorefrontPanel",
	"Root/Body/MainArea/WorkbenchPanel",
	"GlobalPopupBackdrop",
	"GlobalOverlayLayer",
	"GlobalOverlayLayer/OverlayFrame",
	"GlobalOverlayLayer/OverlayFrame/OverlayModeStack",
	"TaskPopup"
]

const MAIN_SCENE_INTERNAL_MARKERS := [
	"[node name=\"ShowcaseGrid\"",
	"[node name=\"PrimaryItemList\"",
	"[node name=\"InventoryGrid\" parent=\"Root/Body/MainArea/WorkbenchPanel",
	"[node name=\"ToolGrid\"",
	"[node name=\"RecipeScroll\"",
	"[node name=\"OutputGridRow\"",
	"[node name=\"TaskTabs\"",
	"[node name=\"InventoryTabs\"",
	"[node name=\"InventoryGrid\" parent=\"GlobalOverlayLayer",
	"[node name=\"CatalogGrid\""
]

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = VIEWPORT_SIZE
	var packed_scene := load(MAIN_SCENE_PATH)
	if packed_scene == null:
		_fail("Main scene is missing")
		_finish()
		return

	var main := (packed_scene as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	for node_path in REQUIRED_SHELL_NODES:
		if main.get_node_or_null(node_path) == null:
			_fail("missing shell node: %s" % node_path)

	var source := FileAccess.get_file_as_string(MAIN_SCENE_PATH)
	for marker in MAIN_SCENE_INTERNAL_MARKERS:
		if source.find(marker) != -1:
			_fail("Main.tscn still owns component internal marker: %s" % marker)

	var main_view_source := FileAccess.get_file_as_string("res://scripts/main_view.gd")
	var render_helper_markers := {
		"func _make_output_site_region": "main_view.gd should not own output region rendering",
		"func _make_production_recipe_row": "main_view.gd should not own research recipe row rendering",
		"func _make_processing_recipe_row": "main_view.gd should not own processing recipe row rendering",
		"func _create_purchase_quantity_row": "main_view.gd should not own purchase row rendering",
		"func _make_task_overlay_button": "main_view.gd should not own task overlay row rendering",
		"func _render_task_detail": "main_view.gd should not own task detail rendering",
		"func _render_task_reward_track": "main_view.gd should not own task reward track rendering",
		"func _render_catalog_milestones": "main_view.gd should not own catalog milestone rendering",
		"func _refresh_inventory_grid": "main_view.gd should not own inventory overlay rendering",
		"func _refresh_catalog_panel": "main_view.gd should not own catalog overlay rendering"
	}
	for marker in render_helper_markers:
		if main_view_source.find(marker) != -1:
			_fail(String(render_helper_markers[marker]))

	var automation_algorithm_markers := {
		"func _settle_automation_event": "main_view.gd should delegate automation settlement to AutomationService",
		"func _claimable_starlight_rewards": "main_view.gd should delegate starlight reward enumeration to StarProgressionService",
		"func _consume_automation_materials": "main_view.gd should delegate automation material transactions to domain services"
	}
	for marker in automation_algorithm_markers:
		if main_view_source.find(marker) != -1:
			_fail(String(automation_algorithm_markers[marker]))

	var automation_service := load("res://scripts/automation_service.gd")
	if automation_service == null or not automation_service.has_method("settle"):
		_fail("AutomationService should expose the public settle interface")
	var star_progression_service := load("res://scripts/star_progression_service.gd")
	if star_progression_service == null or not star_progression_service.has_method("claimable_recipe_rewards"):
		_fail("StarProgressionService should expose the public claimable_recipe_rewards interface")

	if not FileAccess.file_exists(AUTOMATION_SPEC_PATH):
		_fail("automation design spec should be versioned with the implemented UI")
	else:
		var automation_spec := FileAccess.get_file_as_string(AUTOMATION_SPEC_PATH)
		for required_text in ["当前无独立升级导航页", "工作台底部入口", "自动化中枢", "星级完成度", "产出格", "排程夹板", "交班简报"]:
			if automation_spec.find(required_text) == -1:
				_fail("automation design spec should describe the shipped UI: %s" % required_text)

	var component_sources := {
		"res://scripts/ui/pages/output_page.gd": [
			"make_site_region"
		]
	}
	for source_path in component_sources:
		var component_source := FileAccess.get_file_as_string(source_path)
		for marker in component_sources[source_path]:
			if component_source.find("func %s" % marker) != -1:
				_fail("%s should use .tscn templates instead of runtime stable UI factory: %s" % [source_path, marker])

	main.queue_free()
	_finish()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("MAIN_SCENE_SPLIT_SHELL_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("MAIN_SCENE_SPLIT_SHELL_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
