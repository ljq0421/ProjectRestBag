extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const POPUP_SIZE := Vector2i(460, 560)

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("catalog_card_action_popup_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = VIEWPORT_SIZE
	var view := MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame
	var state = view.get("state")
	if not state.is_recipe_unlocked("rice_milk_drink"):
		state.add_recipe("rice_milk_drink")
	view.call("_show_catalog_global_popup")
	await process_frame

	var overlay := view.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay")
	_expect(overlay.get_node_or_null("CatalogContent/CatalogDetailPanel") == null, "catalog page removes CatalogDetailPanel")
	var popup := overlay.get_node_or_null("CatalogCardActionPopup") as PopupPanel
	_expect(popup != null, "catalog page mounts CatalogCardActionPopup")
	if popup != null:
		var panel_style := popup.get_theme_stylebox("panel")
		_expect(panel_style is StyleBoxTexture, "catalog action popup uses the neighborhood dessert texture background")
		if panel_style is StyleBoxTexture:
			var panel_texture_style := panel_style as StyleBoxTexture
			_expect(panel_texture_style.texture != null and panel_texture_style.texture.resource_path.ends_with("/resources/ui/skin/neighborhood_dessert/runtime/panel_v1.png"), "catalog action popup uses the shared panel_v1 background")
			for margin_name in ["texture_margin_left", "texture_margin_top", "texture_margin_right", "texture_margin_bottom"]:
				_expect(is_equal_approx(float(panel_texture_style.get(margin_name)), 52.0), "catalog action popup %s should preserve panel_v1 ornaments" % margin_name)

	var grid := overlay.get_node("CatalogContent/CatalogGridPanel/CatalogGrid") as GridContainer
	var unlocked_card: Button = null
	var locked_card: Button = null
	for child in grid.get_children():
		if not child is Button or not child.has_meta("recipe_id"):
			continue
		var card := child as Button
		var recipe_id := String(card.get_meta("recipe_id", ""))
		if state.is_recipe_unlocked(recipe_id) and unlocked_card == null:
			unlocked_card = card
		elif not state.is_recipe_unlocked(recipe_id) and locked_card == null:
			locked_card = card

	_expect(unlocked_card != null, "catalog page exposes an unlocked card")
	_expect(locked_card != null, "catalog page exposes a locked card")
	if locked_card != null:
		_expect(locked_card.disabled, "locked catalog card cannot be clicked")
		_expect(locked_card.tooltip_text == locked_card.text, "locked catalog hover clue remains unchanged")
	if unlocked_card != null:
		var hover_text := unlocked_card.tooltip_text
		_expect(hover_text.contains("食材：") and hover_text.contains("工具："), "unlocked catalog hover remains the existing concise tooltip")
		unlocked_card.pressed.emit()
		await process_frame

	if popup != null:
		_expect(popup.visible, "clicking an unlocked card opens the action popup")
		_expect(popup.size == POPUP_SIZE, "action popup uses 460x560, got %s" % popup.size)
		var detail_text := popup.get_node_or_null("PopupMargin/PopupContent/DetailScroll/DetailText") as RichTextLabel
		_expect(detail_text != null, "action popup contains scrollable detail text")
		if detail_text != null:
			for field in ["名称：", "售价：", "标签：", "食材：", "工具：", "解锁来源：", "首次售卖加成：", "顾客偏好：", "组合关联：", "成长状态："]:
				_expect(detail_text.text.contains(field), "action popup includes %s" % field)
		_expect(popup.get_node_or_null("PopupMargin/PopupContent/ActionRow/ClaimRewardButton") is Button, "action popup contains claim button")
		_expect(popup.get_node_or_null("PopupMargin/PopupContent/ActionRow/MakeButton") is Button, "action popup contains make button")
		var popup_rect := Rect2(Vector2(popup.position), Vector2(popup.size))
		_expect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)).encloses(popup_rect), "action popup stays inside viewport: %s" % popup_rect)

		overlay.call("refresh_panel", view)
		await process_frame
		_expect(not popup.visible, "refreshing filters or pages closes the action popup")
		var refreshed_card: Button = null
		for child in grid.get_children():
			if child is Button and child.has_meta("recipe_id") and state.is_recipe_unlocked(String(child.get_meta("recipe_id", ""))):
				refreshed_card = child as Button
				break
		_expect(refreshed_card != null, "refreshed catalog keeps an unlocked card")
		if refreshed_card != null:
			refreshed_card.pressed.emit()
			await process_frame

		var claim_button := popup.get_node("PopupMargin/PopupContent/ActionRow/ClaimRewardButton") as Button
		var starlight_before := int(state.recipe_starlight_available)
		_expect(not claim_button.disabled, "newly unlocked recipe exposes its claimable starlight")
		if not claim_button.disabled:
			claim_button.pressed.emit()
			await process_frame
			await process_frame
			_expect(int(state.recipe_starlight_available) > starlight_before, "claim button grants recipe starlight")
			_expect(popup.visible, "claiming starlight keeps the action popup open")
			_expect(claim_button.disabled and claim_button.text == "星辉已领取", "claim button refreshes to claimed state")

		var make_button := popup.get_node("PopupMargin/PopupContent/ActionRow/MakeButton") as Button
		make_button.pressed.emit()
		await process_frame
		_expect(not popup.visible, "make button closes the action popup")
		_expect(not (view.get_node("GlobalOverlayLayer") as Control).visible, "make button closes the catalog overlay")
		_expect(String(view.get("global_popup_mode")).is_empty(), "make button returns to the fixed research workbench")

	view.call("_close_global_popup")
	await process_frame
	if popup != null:
		_expect(not popup.visible, "closing catalog also closes action popup")
	view.queue_free()
	_cleanup()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _cleanup() -> void:
	for path in [_save_path, _save_path + ".broken"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _finish() -> void:
	if _failures.is_empty():
		print("CATALOG_CARD_ACTION_POPUP_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("CATALOG_CARD_ACTION_POPUP_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
