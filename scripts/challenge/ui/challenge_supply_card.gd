class_name ChallengeSupplyCard
extends Button

signal recipe_drag_started(recipe_id: String)

const RecipeIconService = preload("res://scripts/recipe_icon_service.gd")
const ShowcaseIconService = preload("res://scripts/ui/storefront/showcase_icon_service.gd")
const ROLE_NAMES := {
	"tempo": "周转",
	"pairing": "联动",
	"signature": "招牌",
	"softness": "柔软",
	"flavor": "风味",
	"shape": "形状",
	"sustain": "持续",
	"space": "空间"
}
const TAG_NAMES := {
	"fast": "快速",
	"bake": "烘焙",
	"fruit": "水果",
	"drink": "饮品",
	"set": "搭配",
	"signature": "招牌",
	"chocolate": "巧克力",
	"aromatic": "香气",
	"soft": "软糯",
	"tea": "茶香",
	"crisp": "香脆",
	"savory": "咸香",
	"hearty": "饱腹",
	"refreshing": "清爽",
	"rich": "浓郁",
	"spatial": "空间"
}

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
	var roles: Array = recipe_definition.get("build_roles", [])
	var cycle_seconds := float(recipe_definition.get("cycle_ms", 0)) / 1000.0
	var cycle_text := (
		"%d" % int(cycle_seconds)
		if is_equal_approx(cycle_seconds, float(int(cycle_seconds)))
		else "%.1f" % cycle_seconds
	)
	var tags := _display_tags(recipe_definition.get("tags", []))
	$StatsLabel.text = "%s 秒/次 · 满足 %d · 库存 %d" % [
		cycle_text,
		int(recipe_definition.get("satisfaction", 0)),
		int(recipe_definition.get("virtual_stock", 0))
	]
	$TagsLabel.text = "标签：" + (" / ".join(tags) if not tags.is_empty() else "无")
	$EffectBadge.text = (
		"强化 ×%d" % source_ids.size()
		if not source_ids.is_empty()
		else String(ROLE_NAMES.get(String(roles[0]), "")) if not roles.is_empty() else ""
	)
	tooltip_text = "%s\n%s 秒售卖一次 · 每次提供 %d 满足力 · 最多售卖 %d 次\n挑战备货 %d · 最多摆放 %d 份\n标签：%s\n上下左右贴边才能触发本场相邻加成；不消耗经营库存" % [
		$NameLabel.text,
		cycle_text,
		int(recipe_definition.get("satisfaction", 0)),
		int(recipe_definition.get("virtual_stock", 0)),
		int(recipe_definition.get("supply_cost", 0)),
		int(recipe_definition.get("copy_limit", 0)),
		" / ".join(tags) if not tags.is_empty() else "无"
	]
	if not source_ids.is_empty():
		tooltip_text += "\n本局强化：" + "、".join(source_ids)
	elif not roles.is_empty():
		tooltip_text += "\n构筑方向：" + String(ROLE_NAMES.get(String(roles[0]), String(roles[0])))
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


func _display_tags(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values:
		var tag := String(value)
		var label := String(TAG_NAMES.get(tag, tag))
		if not label.is_empty() and not result.has(label):
			result.append(label)
	return result
