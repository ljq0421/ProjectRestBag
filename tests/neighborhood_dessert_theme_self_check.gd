extends SceneTree

const THEME_PATH := "res://resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const OUTPUT_CELL_SCENE_PATH := "res://scenes/ui/pages/output_cell.tscn"
const KITCHEN_AUTOMATION_SCENE_PATH := "res://scenes/ui/pages/kitchen_automation_panel.tscn"
const PANEL_V1_TEXTURE_PATH := "res://resources/ui/skin/neighborhood_dessert/runtime/panel_v1.png"
const LEGACY_MAIN_PANEL_TEXTURE_PATH := "res://resources/ui/skin/neighborhood_dessert/runtime/panel_main_normal.png"

const TEXT_PRIMARY := Color(0.411765, 0.215686, 0.0980392, 1)
const TEXT_HOVER := Color(0.352941, 0.164706, 0.0627451, 1)
const TEXT_MUTED := Color(0.411765, 0.294118, 0.215686, 0.65)
const TEXT_INVERSE := Color(1, 0.968627, 0.862745, 1)
const VERTICAL_SCROLLBAR_WIDTH := 8.0
const VERTICAL_SCROLLBAR_SIDE_MARGIN := 4.0

const REQUIRED_STYLES := {
	"DessertPrimaryButton": ["normal", "hover", "pressed", "disabled"],
	"DessertSecondaryButton": ["normal", "hover", "pressed", "disabled"],
	"DessertFlatButton": ["normal", "hover", "pressed", "disabled"],
	"DessertIconButton": ["normal", "hover", "pressed", "disabled"],
	"DessertTopTabButton": ["normal", "hover", "pressed", "disabled"],
	"DessertMainPanel": ["panel"],
	"DessertSectionPanel": ["panel"],
	"DessertInsetPanel": ["panel"],
	"DessertModalPanel": ["panel"],
	"DessertWorkbenchPanel": ["panel"],
	"DessertDangerButton": ["normal", "hover", "pressed", "disabled"],
	"DessertTextInput": ["normal", "focus", "read_only"],
	"DessertDropdownInput": ["normal", "hover", "pressed", "disabled"],
	"DessertNumberInput": ["normal", "focus", "read_only"],
	"DessertProgressBar": ["background", "fill"],
	"DessertTopTabBar": ["tab_unselected", "tab_hovered", "tab_selected", "tab_disabled"],
	"DessertPopupMenu": ["panel"],
	"DessertStatusTagNormal": ["normal"],
	"DessertStatusTagPositive": ["normal"],
	"DessertStatusTagWarning": ["normal"],
	"DessertStatusTagNegative": ["normal"],
	"DessertNoticeDialog": ["panel"],
	"DessertAutomationPanel": ["panel"],
	"DessertDragPreviewPanel": ["panel"],
}

const REQUIRED_TOGGLE_ICONS := [
	&"unchecked",
	&"checked",
	&"unchecked_hover",
	&"checked_hover",
	&"unchecked_disabled",
	&"checked_disabled",
]

const REQUIRED_SCROLLBAR_STYLES := [
	&"scroll",
	&"grabber",
	&"grabber_highlight",
	&"grabber_pressed",
]

const REQUIRED_TEXT_COLORS := {
	"Label": {"font_color": TEXT_PRIMARY},
	"RichTextLabel": {"default_color": TEXT_PRIMARY},
	"Button": {
		"font_color": TEXT_PRIMARY,
		"font_hover_color": TEXT_HOVER,
		"font_pressed_color": TEXT_PRIMARY,
		"font_disabled_color": TEXT_MUTED,
	},
	"CheckBox": {
		"font_color": TEXT_PRIMARY,
		"font_hover_color": TEXT_HOVER,
		"font_pressed_color": TEXT_PRIMARY,
		"font_disabled_color": TEXT_MUTED,
	},
	"CheckButton": {
		"font_color": TEXT_PRIMARY,
		"font_hover_color": TEXT_HOVER,
		"font_pressed_color": TEXT_PRIMARY,
		"font_disabled_color": TEXT_MUTED,
	},
	"LineEdit": {
		"font_color": TEXT_PRIMARY,
		"font_uneditable_color": TEXT_MUTED,
		"font_selected_color": TEXT_INVERSE,
	},
	"TextEdit": {
		"font_color": TEXT_PRIMARY,
		"font_readonly_color": TEXT_MUTED,
		"font_selected_color": TEXT_INVERSE,
	},
	"OptionButton": {
		"font_color": TEXT_PRIMARY,
		"font_hover_color": TEXT_HOVER,
		"font_pressed_color": TEXT_PRIMARY,
		"font_disabled_color": TEXT_MUTED,
	},
	"TabBar": {
		"font_unselected_color": TEXT_PRIMARY,
		"font_hovered_color": TEXT_HOVER,
		"font_selected_color": TEXT_PRIMARY,
		"font_disabled_color": TEXT_MUTED,
	},
	"ItemList": {"font_color": TEXT_PRIMARY},
}

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var theme := load(THEME_PATH) as Theme
	if theme == null:
		_fail("Theme is missing")
		_finish()
		return

	for large_panel_variation: StringName in [
		&"DessertMainPanel",
		&"DessertModalPanel",
		&"DessertNoticeDialog",
		&"DessertShowcaseBoard",
		&"DessertWorkbenchPanel",
	]:
		_check_stylebox_texture_path(theme, &"panel", large_panel_variation, PANEL_V1_TEXTURE_PATH)
	_check_stylebox_texture_path(theme, &"panel", &"DessertMetricPanel", LEGACY_MAIN_PANEL_TEXTURE_PATH)

	for theme_type: String in REQUIRED_TEXT_COLORS:
		var colors: Dictionary = REQUIRED_TEXT_COLORS[theme_type]
		for color_name: String in colors:
			var expected: Color = colors[color_name]
			var actual := theme.get_color(color_name, theme_type)
			if not actual.is_equal_approx(expected):
				_fail("%s/%s should be %s, got %s" % [theme_type, color_name, expected, actual])

	if theme.get_color("font_color", "DessertPrimaryButton") != TEXT_INVERSE:
		_fail("DessertPrimaryButton must preserve inverse cream text")
	if theme.get_color("font_pressed_color", "DessertTopTabButton") != TEXT_INVERSE:
		_fail("Selected DessertTopTabButton must preserve inverse cream text")
	if theme.get_color("font_color", "DessertShowcaseBadgeReady") != TEXT_INVERSE:
		_fail("DessertShowcaseBadgeReady must preserve inverse cream text")
	for icon_name: StringName in REQUIRED_TOGGLE_ICONS:
		_check_texture_icon(theme, icon_name, &"DessertToggle")
	if theme.get_icon(&"checked_hover", &"DessertToggle") != theme.get_icon(&"checked", &"DessertToggle"):
		_fail("DessertToggle checked hover must preserve the on-state thumb position")
	if theme.get_icon(&"checked_disabled", &"DessertToggle") != theme.get_icon(&"checked", &"DessertToggle"):
		_fail("DessertToggle checked disabled must preserve the on-state thumb position")
	for scrollbar_type: StringName in [&"HScrollBar", &"VScrollBar"]:
		for style_name: StringName in REQUIRED_SCROLLBAR_STYLES:
			_check_stylebox_texture(theme, style_name, scrollbar_type)
	for style_name: StringName in REQUIRED_SCROLLBAR_STYLES:
		var vertical_style := theme.get_stylebox(style_name, &"VScrollBar") as StyleBoxTexture
		if vertical_style == null or vertical_style.texture == null:
			continue
		if not is_equal_approx(vertical_style.texture.get_width(), VERTICAL_SCROLLBAR_WIDTH):
			_fail("VScrollBar/%s texture width should be %s" % [style_name, VERTICAL_SCROLLBAR_WIDTH])
		if not is_equal_approx(vertical_style.texture_margin_left, VERTICAL_SCROLLBAR_SIDE_MARGIN) \
				or not is_equal_approx(vertical_style.texture_margin_right, VERTICAL_SCROLLBAR_SIDE_MARGIN):
			_fail("VScrollBar/%s side margins should both be %s" % [style_name, VERTICAL_SCROLLBAR_SIDE_MARGIN])
		if not is_equal_approx(vertical_style.get_minimum_size().x, VERTICAL_SCROLLBAR_WIDTH):
			_fail("VScrollBar/%s minimum width should be %s" % [style_name, VERTICAL_SCROLLBAR_WIDTH])
	_check_stylebox_texture(theme, &"panel", &"TooltipPanel")

	for variation: String in REQUIRED_STYLES:
		var expected_size := Vector2.ZERO
		var expected_texture_margins := Vector4.ZERO
		var expected_content_margins := Vector4.ZERO
		for style_name: String in REQUIRED_STYLES[variation]:
			var style := theme.get_stylebox(style_name, variation)
			if not style is StyleBoxTexture:
				_fail("%s/%s must be StyleBoxTexture" % [variation, style_name])
				continue
			var texture_style := style as StyleBoxTexture
			if texture_style.texture == null:
				_fail("%s/%s texture is missing" % [variation, style_name])
				continue
			var texture_size := texture_style.texture.get_size()
			var texture_margins := Vector4(
				texture_style.texture_margin_left,
				texture_style.texture_margin_top,
				texture_style.texture_margin_right,
				texture_style.texture_margin_bottom
			)
			var content_margins := Vector4(
				texture_style.content_margin_left,
				texture_style.content_margin_top,
				texture_style.content_margin_right,
				texture_style.content_margin_bottom
			)
			if expected_size == Vector2.ZERO:
				expected_size = texture_size
				expected_texture_margins = texture_margins
				expected_content_margins = content_margins
			elif texture_size != expected_size \
					or texture_margins != expected_texture_margins \
					or content_margins != expected_content_margins:
				_fail("%s states must share texture size and margins" % variation)

	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Main scene is missing")
		_finish()
		return

	var main := packed.instantiate()
	if main.theme != theme:
		_fail("Main scene must load the neighborhood dessert Theme")
	var workbench_panel := main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel") as VBoxContainer
	if workbench_panel == null:
		_fail("WorkbenchPanel must remain a VBoxContainer")
	else:
		if workbench_panel.theme_type_variation != &"DessertWorkbenchPanel":
			_fail("WorkbenchPanel must use DessertWorkbenchPanel")
		if workbench_panel.get_script() == null:
			_fail("WorkbenchPanel must load its skin drawing script")
		if workbench_panel.get_node_or_null("ProductionWorkbench") == null \
				or workbench_panel.get_node_or_null("WorkbenchLauncher") == null:
			_fail("WorkbenchPanel must preserve direct ProductionWorkbench and WorkbenchLauncher paths")
	_check_variation(
		main,
		"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ActionRow/ResearchActionButton",
		"DessertPrimaryButton"
	)
	_check_variation(
		main,
		"Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/ActionRow/SecondaryActionButton",
		"DessertSecondaryButton"
	)
	_check_variation(
		main,
		"Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/ActionRow/TertiaryActionButton",
		"DessertFlatButton"
	)
	_check_variation(main, "GlobalOverlayLayer", "DessertModalPanel")
	_check_variation(main, "Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/TaskButton", "DessertLauncherIconButton")
	_check_variation(main, "Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/PurchaseButton", "DessertLauncherIconButton")
	_check_variation(
		main,
		"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/CurrentBuildPanel",
		"DessertSectionPanel"
	)
	_check_variation(
		main,
		"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/CombinationBonusPanel",
		"DessertSectionPanel"
	)
	_check_variation(main, "TaskPopup", "DessertNoticeDialog")
	_check_variation(main, "AutomationReportDialog", "DessertNoticeDialog")
	_check_variation(main, "RecipeRestockDialog", "DessertNoticeDialog")
	_check_variation(main, "ShowcaseRoundSettlementDialog", "DessertNoticeDialog")
	_check_variation(
		main,
		"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PurchaseRegionsGrid/FarmRegion",
		"DessertSectionPanel"
	)
	_check_variation(
		main,
		"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputContextMenu",
		"DessertPopupMenu"
	)
	_check_variation(
		main,
		"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventorySummaryRow/InventorySearchInput",
		"DessertTextInput"
	)
	_check_variation(
		main,
		"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventorySummaryRow/InventorySortButton",
		"DessertDropdownInput"
	)
	_check_variation(
		main,
		"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventoryMainPanel/InventoryTabs",
		"DessertTopTabBar"
	)
	_check_variation(
		main,
		"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogFilterTabs",
		"DessertTopTabBar"
	)

	var backdrop := main.get_node_or_null("GlobalPopupBackdrop") as Button
	if backdrop == null or not backdrop.flat or not backdrop.theme_type_variation.is_empty():
		_fail("GlobalPopupBackdrop must remain an unskinned flat button")

	var research_dialog_scene := load("res://scenes/ui/overlays/research_progress_dialog.tscn") as PackedScene
	var research_dialog := research_dialog_scene.instantiate()
	var research_failure_content := research_dialog.get_node_or_null("DialogMargin/DialogContent/StateContent/ResearchFailureContent") as VBoxContainer
	if research_failure_content == null or not research_failure_content.theme_type_variation.is_empty():
		_fail("research notebook content must remain frameless and unskinned")
	research_dialog.free()

	var output_scene := load("res://scenes/ui/pages/output_site_region.tscn") as PackedScene
	var output_region := output_scene.instantiate() as Control
	if output_region.theme_type_variation != &"DessertInsetPanel":
		_fail("OutputSiteRegion variation should be DessertInsetPanel")
	_check_variation(output_region, "OutputSiteBox/OutputSiteBody/PlotColumn/OutputSitePager/OutputPrevPageButton", "DessertIconButton")
	output_region.free()

	var output_cell_scene := load(OUTPUT_CELL_SCENE_PATH) as PackedScene
	var output_cell := output_cell_scene.instantiate() as Button
	root.add_child(output_cell)
	await process_frame
	_check_variation(output_cell, "ProductionProgressBar", "DessertProgressBar")
	_check_variation(output_cell, "AutomationToggle", "DessertToggle")
	_check_variation(output_cell, "AutomationStatusLabel", "DessertStatusTagNormal")
	var drag_preview := output_cell.call("_make_drag_preview") as PanelContainer
	if drag_preview == null or drag_preview.theme_type_variation != &"DessertDragPreviewPanel":
		_fail("Output drag preview should use DessertDragPreviewPanel")
	elif drag_preview.get_theme_stylebox(&"panel") == null:
		_fail("Output drag preview should resolve a panel skin")
	if drag_preview != null:
		drag_preview.free()
	output_cell.call("configure_automation", true, true, "托管中", {})
	_check_variation(output_cell, "AutomationStatusLabel", "DessertStatusTagPositive")
	output_cell.call("configure_automation", true, true, "缺少原料", {"next_step": "补货"})
	_check_variation(output_cell, "AutomationStatusLabel", "DessertStatusTagWarning")
	output_cell.queue_free()

	var kitchen_scene := load(KITCHEN_AUTOMATION_SCENE_PATH) as PackedScene
	var kitchen := kitchen_scene.instantiate() as Control
	root.add_child(kitchen)
	await process_frame
	if kitchen.theme_type_variation != &"DessertAutomationPanel":
		_fail("KitchenAutomationPanel should use DessertAutomationPanel")
	elif kitchen.get_theme_stylebox(&"panel") == null:
		_fail("KitchenAutomationPanel should resolve a panel skin")
	_check_variation(kitchen, "Header/PauseToggle", "DessertToggle")
	_check_variation(kitchen, "Editor/RecipeOption", "DessertDropdownInput")
	_check_variation(kitchen, "Editor/BatchOption", "DessertDropdownInput")
	_check_variation(kitchen, "Editor/PriorityOption", "DessertDropdownInput")
	var target_stock_spin := kitchen.get_node_or_null("Editor/TargetStockSpin") as SpinBox
	if target_stock_spin == null or target_stock_spin.get_line_edit().theme_type_variation != &"DessertNumberInput":
		_fail("Editor/TargetStockSpin line edit should use DessertNumberInput")
	_check_variation(kitchen, "Editor/SaveRuleButton", "DessertPrimaryButton")
	_check_variation(kitchen, "Editor/RemoveRuleButton", "DessertDangerButton")
	_check_variation(kitchen, "StatusLabel", "DessertStatusTagNormal")
	kitchen.call("show_service_result", {"ok": true}, "save")
	_check_variation(kitchen, "StatusLabel", "DessertStatusTagPositive")
	kitchen.call("show_service_result", {"ok": false, "reason": "invalid_rule"}, "save")
	_check_variation(kitchen, "StatusLabel", "DessertStatusTagNegative")
	kitchen.queue_free()

	main.set("save_path", OS.get_temp_dir().path_join("neighborhood_dessert_theme_self_check_save.json"))
	root.add_child(main)
	await process_frame
	await process_frame
	_check_variation(main, "InventoryVariantMenu", "DessertPopupMenu")
	main.queue_free()
	_finish()


func _check_variation(root_node: Node, path: NodePath, expected: StringName) -> void:
	var themed_node := root_node.get_node_or_null(path)
	if themed_node == null:
		_fail("Missing control: %s" % path)
	elif themed_node.get("theme_type_variation") != expected:
		_fail("%s variation should be %s" % [path, expected])


func _check_texture_icon(theme: Theme, icon_name: StringName, variation: StringName) -> void:
	if theme.get_icon(icon_name, variation) == null:
		_fail("%s/%s texture is missing" % [variation, icon_name])


func _check_stylebox_texture(theme: Theme, style_name: StringName, variation: StringName) -> void:
	var style := theme.get_stylebox(style_name, variation)
	if not style is StyleBoxTexture:
		_fail("%s/%s must be StyleBoxTexture" % [variation, style_name])
	elif (style as StyleBoxTexture).texture == null:
		_fail("%s/%s texture is missing" % [variation, style_name])


func _check_stylebox_texture_path(theme: Theme, style_name: StringName, variation: StringName, expected_path: String) -> void:
	var style := theme.get_stylebox(style_name, variation)
	if not style is StyleBoxTexture:
		_fail("%s/%s must be StyleBoxTexture" % [variation, style_name])
		return
	var texture_style := style as StyleBoxTexture
	if texture_style.texture == null:
		_fail("%s/%s texture is missing" % [variation, style_name])
	elif texture_style.texture.resource_path != expected_path:
		_fail("%s/%s should use %s, got %s" % [variation, style_name, expected_path, texture_style.texture.resource_path])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
