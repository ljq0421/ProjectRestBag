class_name ChallengeSupplyCard
extends Button

signal recipe_drag_started(recipe_id: String)

const RecipeIconService = preload("res://scripts/recipe_icon_service.gd")
const ShowcaseIconService = preload("res://scripts/ui/storefront/showcase_icon_service.gd")

var recipe_id := ""
var recipe_definition: Dictionary = {}
var selected_count := 0
var _showcase_icons = ShowcaseIconService.new()


func _ready() -> void:
	pressed.connect(_emit_recipe_intent)
	_showcase_icons.load_manifest()


func bind(next_recipe_id: String, definition: Dictionary, display_name: String = "") -> void:
	recipe_id = next_recipe_id
	recipe_definition = definition.duplicate(true)
	$NameLabel.text = display_name if not display_name.is_empty() else next_recipe_id
	$CostBadge.text = "备货 %d" % int(recipe_definition.get("supply_cost", 0))
	var source_ids: Array = recipe_definition.get("_upgrade_source_ids", [])
	$EffectBadge.text = "强化 ×%d" % source_ids.size() if not source_ids.is_empty() else ""
	tooltip_text = "%s\n挑战备货 %d · 最多 %d 份\n不消耗经营库存" % [
		$NameLabel.text,
		int(recipe_definition.get("supply_cost", 0)),
		int(recipe_definition.get("copy_limit", 0))
	]
	if not source_ids.is_empty():
		tooltip_text += "\n本局强化：" + "、".join(source_ids)
	_refresh_icon()
	set_selected_count(selected_count)


func set_selected_count(count: int) -> void:
	selected_count = maxi(0, count)
	var copy_limit := int(recipe_definition.get("copy_limit", 0))
	$CountBadge.text = "%d / %d" % [selected_count, copy_limit]
	disabled = copy_limit > 0 and selected_count >= copy_limit


func _get_drag_data(_at_position: Vector2) -> Variant:
	if recipe_id.is_empty() or disabled:
		return null
	recipe_drag_started.emit(recipe_id)
	var preview := Label.new()
	preview.text = $NameLabel.text
	preview.add_theme_font_size_override("font_size", 18)
	preview.add_theme_color_override("font_color", Color("#29213d"))
	set_drag_preview(preview)
	return {
		"kind": "challenge_recipe",
		"recipe_id": recipe_id
	}


func _emit_recipe_intent() -> void:
	if not recipe_id.is_empty():
		recipe_drag_started.emit(recipe_id)


func _refresh_icon() -> void:
	var icon_texture: Texture2D = null
	var shape_cells: Array = recipe_definition.get("shape_cells", [])
	if shape_cells.size() == 1:
		icon_texture = _showcase_icons.fragment(recipe_id, "standard", 0, Vector2i.ZERO, 0)
	if icon_texture == null:
		icon_texture = RecipeIconService.texture(recipe_id, 0, "catalog")
	$Icon.texture = icon_texture
