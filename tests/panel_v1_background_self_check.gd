extends SceneTree

const THEME_PATH := "res://resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres"
const SOURCE_TEXTURE_PATH := "res://resources/ui/skin_v1/panel_v1.png"
const RUNTIME_TEXTURE_PATH := "res://resources/ui/skin/neighborhood_dessert/runtime/panel_v1.png"
const LEGACY_MAIN_TEXTURE_PATH := "res://resources/ui/skin/neighborhood_dessert/runtime/panel_main_normal.png"
const MAIN_BACKGROUND_TEXTURE_PATH := "res://resources/ui/skin_v1/background.png"

const MainScene := preload("res://scenes/Main.tscn")
const CatalogPopupScene := preload("res://scenes/ui/overlays/catalog_card_action_popup.tscn")
const ResearchProgressScene := preload("res://scenes/ui/overlays/research_progress_dialog.tscn")
const PurchaseCategoryScene := preload("res://scenes/ui/pages/purchase_category_panel.tscn")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var source_texture := load(SOURCE_TEXTURE_PATH) as Texture2D
	var runtime_texture := load(RUNTIME_TEXTURE_PATH) as Texture2D
	_expect(source_texture != null and source_texture.get_size() == Vector2(2720, 1536), "panel_v1 source should remain the supplied 2720x1536 texture")
	_expect(runtime_texture != null and runtime_texture.get_size() == Vector2(320, 181), "panel_v1 runtime texture should be 320x181")

	var theme := load(THEME_PATH) as Theme
	_expect(theme != null, "neighborhood dessert theme should load")
	if theme != null:
		for variation: StringName in [
			&"DessertMainPanel",
			&"DessertModalPanel",
			&"DessertNoticeDialog",
			&"DessertShowcaseBoard",
			&"DessertWorkbenchPanel",
		]:
			_check_panel_style(theme.get_stylebox(&"panel", variation), RUNTIME_TEXTURE_PATH, 52.0, "%s theme style" % variation)
		_check_panel_style(theme.get_stylebox(&"panel", &"DessertMetricPanel"), LEGACY_MAIN_TEXTURE_PATH, 30.0, "metric panel exclusion")

	var main := MainScene.instantiate()
	var page_background := main.get_node("PageBackground") as TextureRect
	_expect(page_background.texture != null and page_background.texture.resource_path == MAIN_BACKGROUND_TEXTURE_PATH, "PageBackground should use the dedicated full-screen background")
	_expect(page_background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "PageBackground should cover the viewport without distortion")
	var default_surface := main.get_node("GlobalOverlayLayer/DefaultModalSurface") as PanelContainer
	_expect(default_surface.theme_type_variation == &"DessertModalPanel", "shared workbench popup background should use the verified modal panel variation")
	_expect(main.get_node_or_null("GlobalOverlayLayer/PurchasePopupBackground") == null, "purchase popup should not duplicate the default background")
	_expect(main.get_node_or_null("GlobalOverlayLayer/CatalogPopupBackground") == null, "catalog popup should not duplicate the default background")
	main.free()

	_check_scene_panel(CatalogPopupScene, RUNTIME_TEXTURE_PATH, 52.0, "catalog action popup")
	_check_scene_panel(ResearchProgressScene, RUNTIME_TEXTURE_PATH, 52.0, "research progress dialog")

	var purchase_category := PurchaseCategoryScene.instantiate() as Control
	_expect(purchase_category.get_theme_stylebox(&"panel") is StyleBoxFlat, "purchase category should keep its functional section background")
	purchase_category.free()
	_finish()


func _check_scene_panel(scene: PackedScene, expected_path: String, expected_margin: float, label: String) -> void:
	var themed_node := scene.instantiate()
	var panel_style := themed_node.call("get_theme_stylebox", &"panel") as StyleBox
	_check_panel_style(panel_style, expected_path, expected_margin, label)
	themed_node.free()


func _check_panel_style(style: StyleBox, expected_path: String, expected_margin: float, label: String) -> void:
	_expect(style is StyleBoxTexture, "%s should use StyleBoxTexture" % label)
	if not style is StyleBoxTexture:
		return
	var texture_style := style as StyleBoxTexture
	_expect(texture_style.texture != null and texture_style.texture.resource_path == expected_path, "%s should use %s" % [label, expected_path])
	for margin_name in [&"texture_margin_left", &"texture_margin_top", &"texture_margin_right", &"texture_margin_bottom"]:
		_expect(is_equal_approx(float(texture_style.get(margin_name)), expected_margin), "%s %s should be %s" % [label, margin_name, expected_margin])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PANEL_V1_BACKGROUND_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("PANEL_V1_BACKGROUND_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
