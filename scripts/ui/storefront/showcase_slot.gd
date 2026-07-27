extends "res://scripts/output_cell.gd"

const SKIN_VARIATIONS := {
	&"normal": &"DessertShowcaseSlot",
	&"locked": &"DessertShowcaseSlotLocked",
	&"reward": &"DessertShowcaseSlotReward",
}

var recipe_icon: TextureRect
var preview_tint: ColorRect
var group_outline: Panel
var status_badge: Label
var masterwork_frame: Panel
var masterwork_glow: ColorRect
var masterwork_seal: Label
var sale_complete_flash: ColorRect

var _outline_key := ""
var _sale_complete_tween: Tween


func _ready() -> void:
	super()
	_bind_visual_nodes()
	clear_product_visual()


func set_icon_fragment(texture: Texture2D, preview: bool = false) -> void:
	_bind_visual_nodes()
	recipe_icon.texture = texture
	recipe_icon.modulate = Color(1, 1, 1, 0.55 if preview else 1.0)


func set_status_badge(text: String) -> void:
	_bind_visual_nodes()
	status_badge.text = text
	status_badge.theme_type_variation = &"DessertShowcaseBadgeReady" if text == "可售" else &"DessertShowcaseBadge"
	status_badge.visible = not text.is_empty()


func set_masterwork_visual(level: int, is_anchor: bool) -> void:
	_bind_visual_nodes()
	var clean_level := clampi(level, 0, 10)
	masterwork_frame.visible = clean_level >= 3
	masterwork_glow.visible = clean_level >= 6
	masterwork_seal.visible = clean_level >= 10 and is_anchor
	if masterwork_frame.visible:
		masterwork_frame.add_theme_stylebox_override("panel", _masterwork_frame_style("gold" if clean_level >= 10 else "silver"))
	else:
		masterwork_frame.remove_theme_stylebox_override("panel")


func set_skin_state(state_name: StringName) -> void:
	theme_type_variation = SKIN_VARIATIONS.get(state_name, &"DessertShowcaseSlot")


func set_preview_state(active: bool, valid: bool) -> void:
	_bind_visual_nodes()
	preview_tint.visible = active
	preview_tint.color = Color(0.2, 0.75, 0.35, 0.16) if valid else Color(0.9, 0.2, 0.15, 0.2)


func _make_drag_preview() -> Control:
	print(
		"[showcase_unlist_drag] event=preview_created recipe=%s kind=%s" % [
			String(drag_data.get("recipe_id", "")),
			String(drag_data.get("kind", ""))
		]
	)
	var preview := Control.new()
	preview.name = "ShowcaseProductDragPreview"
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return preview


func _clear_sale_complete_feedback() -> void:
	if _sale_complete_tween != null and _sale_complete_tween.is_valid():
		_sale_complete_tween.kill()
	_sale_complete_tween = null
	sale_complete_flash.visible = false
	sale_complete_flash.color.a = 0.0


func play_sale_complete_feedback() -> void:
	_bind_visual_nodes()
	if _sale_complete_tween != null and _sale_complete_tween.is_valid():
		_sale_complete_tween.kill()
	sale_complete_flash.visible = true
	sale_complete_flash.color.a = 0.58
	_sale_complete_tween = create_tween()
	_sale_complete_tween.tween_property(sale_complete_flash, "color:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_sale_complete_tween.tween_callback(_finish_sale_complete_feedback)


func set_outline_edges(top: bool, right: bool, bottom: bool, left: bool, color: Color, hovered: bool = false) -> void:
	var key := "%d%d%d%d|%s|%d" % [int(top), int(right), int(bottom), int(left), color.to_html(), int(hovered)]
	if key == _outline_key:
		return
	_outline_key = key
	var normal := _outline_style(top, right, bottom, left, color, 0.18 if hovered else 0.1, 4 if hovered else 3)
	var hover := _outline_style(top, right, bottom, left, color, 0.2, 4)
	group_outline.visible = true
	group_outline.add_theme_stylebox_override("panel", hover if hovered else normal)


func clear_product_visual() -> void:
	_bind_visual_nodes()
	_clear_sale_complete_feedback()
	recipe_icon.texture = null
	recipe_icon.modulate = Color.WHITE
	status_badge.text = ""
	status_badge.visible = false
	preview_tint.visible = false
	masterwork_frame.visible = false
	masterwork_glow.visible = false
	masterwork_seal.visible = false
	clear_outline()


func clear_outline() -> void:
	_bind_visual_nodes()
	_outline_key = ""
	group_outline.visible = false
	group_outline.remove_theme_stylebox_override("panel")


func _outline_style(top: bool, right: bool, bottom: bool, left: bool, color: Color, bg_alpha: float, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, bg_alpha * 0.45)
	style.border_color = color
	style.border_width_top = width if top else 0
	style.border_width_right = width if right else 0
	style.border_width_bottom = width if bottom else 0
	style.border_width_left = width if left else 0
	style.corner_radius_top_left = 12 if top and left else 0
	style.corner_radius_top_right = 12 if top and right else 0
	style.corner_radius_bottom_right = 12 if bottom and right else 0
	style.corner_radius_bottom_left = 12 if bottom and left else 0
	return style


func _masterwork_frame_style(frame: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("f3c85b") if frame == "gold" else Color("b9c8d8")
	style.border_width_left = 3 if frame == "gold" else 2
	style.border_width_top = 3 if frame == "gold" else 2
	style.border_width_right = 3 if frame == "gold" else 2
	style.border_width_bottom = 3 if frame == "gold" else 2
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_right = 9
	style.corner_radius_bottom_left = 9
	return style


func _bind_visual_nodes() -> void:
	if recipe_icon == null:
		recipe_icon = get_node("RecipeIcon") as TextureRect
	if preview_tint == null:
		preview_tint = get_node("PreviewTint") as ColorRect
	if group_outline == null:
		group_outline = get_node("GroupOutline") as Panel
	if status_badge == null:
		status_badge = get_node("StatusBadge") as Label
	if masterwork_frame == null:
		masterwork_frame = get_node("MasterworkFrame") as Panel
	if masterwork_glow == null:
		masterwork_glow = get_node("MasterworkGlow") as ColorRect
	if masterwork_seal == null:
		masterwork_seal = get_node("MasterworkSeal") as Label
	if sale_complete_flash == null:
		sale_complete_flash = get_node("SaleCompleteFlash") as ColorRect


func _finish_sale_complete_feedback() -> void:
	sale_complete_flash.visible = false
	_sale_complete_tween = null
