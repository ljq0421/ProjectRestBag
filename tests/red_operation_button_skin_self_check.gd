extends SceneTree

const THEME_PATH := "res://resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres"
const RED_NORMAL := "res://resources/ui/skin/neighborhood_dessert/runtime/button_red_normal.png"
const RED_HOVER := "res://resources/ui/skin/neighborhood_dessert/runtime/button_red_hover.png"
const RED_PRESSED := "res://resources/ui/skin/neighborhood_dessert/runtime/button_red_pressed.png"
const RED_SELECTED := "res://resources/ui/skin/neighborhood_dessert/runtime/button_red_selected.png"
const RED_DISABLED := "res://resources/ui/skin/neighborhood_dessert/runtime/button_red_disabled.png"
const RED_SIZE := Vector2(154, 40)
const RED_TEXTURE_MARGINS := Vector4(24, 12, 24, 12)
const ACTIVE_TEXT_COLOR := Color(1, 0.968627, 0.862745, 1)
const DISABLED_TEXT_COLOR := Color(0.486275, 0.356863, 0.278431, 0.82)

const ACTION_VARIATIONS := [
	&"DessertPrimaryButton",
	&"DessertSecondaryButton",
	&"DessertFlatButton",
	&"DessertDangerButton",
	&"DessertRedActionButton",
	&"DessertRedCompactButton",
]

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var theme := load(THEME_PATH) as Theme
	if theme == null:
		_fail("Red button theme is missing")
		_finish()
		return

	for variation: StringName in ACTION_VARIATIONS:
		_check_style(theme, variation, &"normal", RED_NORMAL)
		_check_style(theme, variation, &"focus", RED_NORMAL)
		_check_style(theme, variation, &"hover", RED_HOVER)
		_check_style(theme, variation, &"pressed", RED_PRESSED)
		_check_style(theme, variation, &"hover_pressed", RED_PRESSED)
		_check_style(theme, variation, &"disabled", RED_DISABLED)
		_check_color(theme, variation, &"font_color", ACTIVE_TEXT_COLOR)
		_check_color(theme, variation, &"font_disabled_color", DISABLED_TEXT_COLOR)

	_check_style(theme, &"DessertRedToggleButton", &"normal", RED_NORMAL)
	_check_style(theme, &"DessertRedToggleButton", &"hover", RED_HOVER)
	_check_style(theme, &"DessertRedToggleButton", &"pressed", RED_SELECTED)
	_check_style(theme, &"DessertRedToggleButton", &"hover_pressed", RED_SELECTED)
	_check_style(theme, &"DessertRedToggleButton", &"disabled", RED_DISABLED)
	_check_color(theme, &"DessertRedToggleButton", &"font_color", ACTIVE_TEXT_COLOR)
	_check_color(theme, &"DessertRedToggleButton", &"font_pressed_color", ACTIVE_TEXT_COLOR)
	_check_color(theme, &"DessertRedToggleButton", &"font_disabled_color", DISABLED_TEXT_COLOR)

	_check_style_not_red(theme, &"DessertContentButton", &"normal")
	_check_style_not_red(theme, &"DessertLegacyPrimaryButton", &"normal")
	_check_style_not_red(theme, &"DessertIconButton", &"normal")
	_check_style_not_red(theme, &"DessertTopTabButton", &"normal")

	_check_scene_variations(
		"res://scenes/ui/overlays/catalog_overlay.tscn",
		{
			"CatalogSummaryRow/CatalogClaimAllRewardsButton": &"DessertRedActionButton",
			"CatalogFilterTabs": &"DessertTopTabBar",
			"CatalogContent/CatalogGridPanel/CatalogPager/CatalogPrevButton": &"",
		}
	)
	_check_scene_variations(
		"res://scenes/ui/pages/device_growth_center_page.tscn",
		{
			"DeviceDetailColumns/UpgradePanel/UpgradeContent/UpgradeButton": &"DessertRedActionButton",
			"DeviceDetailColumns/DetailPanel/DetailContent/Header/CatalogButton": &"DessertSecondaryButton",
		}
	)
	_check_scene_variations(
		"res://scenes/ui/pages/production_workbench.tscn",
		{
			"ProductionQueueHeader/BulkActionButton": &"DessertSecondaryButton",
			"ProductionQueueHeader/KitchenScheduleButton": &"DessertSecondaryButton",
		}
	)
	_check_scene_variations(
		"res://scenes/ui/pages/production_queue_recipe_row.tscn",
		{
			"Content/ActionButton": &"DessertRedButton",
		}
	)
	_check_scene_variations(
		"res://scenes/ui/storefront/showcase_board.tscn",
		{
			"RoundControlBar/StartRoundButton": &"DessertRedCompactButton",
			"ExpansionToolbar/ExpansionContent/ExpansionToolRow/CellToolButton": &"DessertRedToggleButton",
		}
	)
	_check_scene_variations(
		"res://scenes/ui/pages/research_input_slot.tscn",
		{".": &"DessertContentButton"}
	)
	_check_scene_variations(
		"res://scenes/ui/overlays/task_entry_button.tscn",
		{".": &""}
	)

	_finish()


func _check_style(theme: Theme, variation: StringName, style_name: StringName, expected_path: String) -> void:
	var style := theme.get_stylebox(style_name, variation)
	if not style is StyleBoxTexture:
		_fail("%s/%s must be StyleBoxTexture" % [variation, style_name])
		return
	var texture_style := style as StyleBoxTexture
	if texture_style.texture == null:
		_fail("%s/%s texture is missing" % [variation, style_name])
		return
	if texture_style.texture.resource_path != expected_path:
		_fail("%s/%s should use %s" % [variation, style_name, expected_path])
	if texture_style.texture.get_size() != RED_SIZE:
		_fail("%s/%s should keep the normalized red texture size" % [variation, style_name])
	var margins := Vector4(
		texture_style.texture_margin_left,
		texture_style.texture_margin_top,
		texture_style.texture_margin_right,
		texture_style.texture_margin_bottom
	)
	if margins != RED_TEXTURE_MARGINS:
		_fail("%s/%s should keep common nine-patch margins" % [variation, style_name])


func _check_style_not_red(theme: Theme, variation: StringName, style_name: StringName) -> void:
	var style := theme.get_stylebox(style_name, variation)
	if not style is StyleBoxTexture:
		_fail("%s/%s must remain StyleBoxTexture" % [variation, style_name])
		return
	var texture_style := style as StyleBoxTexture
	if texture_style.texture != null and texture_style.texture.resource_path.begins_with(
		"res://resources/ui/skin/neighborhood_dessert/runtime/button_red_"
	):
		_fail("%s/%s must remain outside the red button family" % [variation, style_name])


func _check_color(theme: Theme, variation: StringName, color_name: StringName, expected: Color) -> void:
	var actual := theme.get_color(color_name, variation)
	if not actual.is_equal_approx(expected):
		_fail("%s/%s should be %s, got %s" % [variation, color_name, expected, actual])


func _check_scene_variations(scene_path: String, expected: Dictionary) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail("Missing scene: %s" % scene_path)
		return
	var instance := packed.instantiate()
	for node_path: String in expected:
		var control: Control = instance if node_path == "." else instance.get_node_or_null(node_path) as Control
		if control == null:
			_fail("Missing control: %s:%s" % [scene_path, node_path])
		elif control.theme_type_variation != expected[node_path]:
			_fail("%s:%s should use %s" % [scene_path, node_path, expected[node_path]])
	instance.free()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RED_OPERATION_BUTTON_SKIN_SELF_CHECK_PASS")
		quit(0)
	else:
		print("RED_OPERATION_BUTTON_SKIN_SELF_CHECK_FAIL: %s" % "; ".join(_failures))
		quit(1)
