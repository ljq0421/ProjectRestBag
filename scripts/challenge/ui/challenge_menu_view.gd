class_name ChallengeMenuView
extends PanelContainer

const MenuService = preload("res://scripts/challenge/challenge_menu_service.gd")
const UiStyle = preload("res://scripts/challenge/ui/challenge_ui_style.gd")

signal back_requested
signal save_requested(recipe_ids: Array[String])
signal preset_save_requested(preset_id: String, display_name: String, recipe_ids: Array[String])
signal preset_load_requested(preset_id: String)

const ROLE_NAMES := {
	"tempo": "快速周转",
	"pairing": "搭配联动",
	"signature": "招牌输出",
	"softness": "柔软质感",
	"flavor": "风味覆盖",
	"shape": "形状构筑",
	"sustain": "持续供给",
	"space": "空间组合",
	"other": "其他"
}

var _service = MenuService.new()
var _available_ids: Array[String] = []
var _selected_ids: Array[String] = []
var _recipe_defs: Dictionary = {}
var _catalog_recipes: Dictionary = {}
var _manifest_recipes: Dictionary = {}
var _default_ids: Array[String] = []
var _saved_menus: Array = []
var _role_filter := ""
var _branch_filter := ""
var _tag_filter := ""
var _shape_filter := ""


func _ready() -> void:
	UiStyle.apply_secondary($Content/Header/BackButton)
	UiStyle.apply_secondary($Content/Body/MenuPanel/Menu/Actions/RestoreDefaultButton)
	UiStyle.apply_primary($Content/Body/MenuPanel/Menu/Actions/SaveButton)
	UiStyle.apply_secondary($Content/Body/MenuPanel/Menu/PresetRow/LoadPresetButton)
	UiStyle.apply_secondary($Content/Body/MenuPanel/Menu/PresetRow/SavePresetButton)
	$Content/Header/BackButton.pressed.connect(func() -> void: back_requested.emit())
	$Content/Body/MenuPanel/Menu/Actions/SaveButton.pressed.connect(
		func() -> void: save_requested.emit(_selected_ids.duplicate())
	)
	$Content/Body/MenuPanel/Menu/Actions/RestoreDefaultButton.pressed.connect(_restore_default)
	$Content/Body/MenuPanel/Menu/PresetRow/LoadPresetButton.pressed.connect(_load_selected_preset)
	$Content/Body/MenuPanel/Menu/PresetRow/SavePresetButton.pressed.connect(_save_selected_preset)
	$Content/Body/CollectionPanel/Collection/Filters/Search.text_changed.connect(
		func(_text: String) -> void: _rebuild_collection()
	)
	$Content/Body/CollectionPanel/Collection/Filters/RoleFilter.item_selected.connect(
		_on_role_filter_selected
	)
	$Content/Body/CollectionPanel/Collection/Filters/BranchFilter.item_selected.connect(
		_on_branch_filter_selected
	)
	$Content/Body/CollectionPanel/Collection/Filters/TagFilter.item_selected.connect(
		_on_tag_filter_selected
	)
	$Content/Body/CollectionPanel/Collection/Filters/ShapeFilter.item_selected.connect(
		_on_shape_filter_selected
	)
	_manifest_recipes = _load_manifest_recipes()


func bind(
	available_ids: Array[String],
	selected_ids: Array[String],
	recipe_defs: Dictionary,
	catalog_recipes: Dictionary,
	default_ids: Array[String] = [],
	saved_menus: Array = []
) -> void:
	_available_ids = available_ids.duplicate()
	_selected_ids = []
	for recipe_id in selected_ids:
		if _available_ids.has(recipe_id) and not _selected_ids.has(recipe_id):
			_selected_ids.append(recipe_id)
	_recipe_defs = recipe_defs.duplicate(true)
	_catalog_recipes = catalog_recipes.duplicate(true)
	_default_ids = default_ids.duplicate()
	_saved_menus = saved_menus.duplicate(true)
	_rebuild_filters()
	_rebuild_presets()
	_rebuild_all()


func selected_recipe_ids() -> Array[String]:
	return _selected_ids.duplicate()


func _rebuild_all() -> void:
	_rebuild_collection()
	_rebuild_slots()
	_refresh_summary()


func _rebuild_filters() -> void:
	var filter: OptionButton = $Content/Body/CollectionPanel/Collection/Filters/RoleFilter
	filter.clear()
	filter.add_item("全部构筑方向")
	filter.set_item_metadata(0, "")
	var roles: Array[String] = []
	for recipe_id in _available_ids:
		var recipe: Dictionary = _recipe_defs.get(recipe_id, {})
		var role := _service.primary_role(recipe)
		if not roles.has(role):
			roles.append(role)
	roles.sort()
	for role in roles:
		filter.add_item(String(ROLE_NAMES.get(role, role)))
		filter.set_item_metadata(filter.item_count - 1, role)
	_role_filter = ""
	_build_metadata_filter(
		$Content/Body/CollectionPanel/Collection/Filters/BranchFilter,
		"全部研究分支",
		_collect_manifest_values("research_branch_id")
	)
	_build_metadata_filter(
		$Content/Body/CollectionPanel/Collection/Filters/TagFilter,
		"全部战斗标签",
		_collect_recipe_tags()
	)
	_build_metadata_filter(
		$Content/Body/CollectionPanel/Collection/Filters/ShapeFilter,
		"全部占格形状",
		["1", "2", "3+"]
	)
	_branch_filter = ""
	_tag_filter = ""
	_shape_filter = ""


func _rebuild_collection() -> void:
	var grid: GridContainer = $Content/Body/CollectionPanel/Collection/CollectionScroll/CollectionGrid
	for child in grid.get_children():
		child.queue_free()
	var query := String(
		$Content/Body/CollectionPanel/Collection/Filters/Search.text
	).strip_edges().to_lower()
	for recipe_id in _available_ids:
		var recipe: Dictionary = _recipe_defs.get(recipe_id, {})
		var role := _service.primary_role(recipe)
		var manifest: Dictionary = _manifest_recipes.get(recipe_id, {})
		var branch_id := String(manifest.get("research_branch_id", ""))
		var tags: Array = recipe.get("tags", [])
		var cell_count := (recipe.get("shape_cells", []) as Array).size()
		var display_name := _recipe_name(recipe_id)
		if not _role_filter.is_empty() and role != _role_filter:
			continue
		if not _branch_filter.is_empty() and branch_id != _branch_filter:
			continue
		if not _tag_filter.is_empty() and not tags.has(_tag_filter):
			continue
		if not _shape_filter.is_empty() and _shape_bucket(cell_count) != _shape_filter:
			continue
		if (
			not query.is_empty()
			and query not in display_name.to_lower()
			and query not in recipe_id.to_lower()
		):
			continue
		var button := Button.new()
		button.set_meta("recipe_id", recipe_id)
		button.custom_minimum_size = Vector2(310, 72)
		button.text = "%s%s\n%s · %d 秒" % [
			"✓ " if _selected_ids.has(recipe_id) else "",
			display_name,
			String(ROLE_NAMES.get(role, role)),
			int(recipe.get("cycle_ms", 0)) / 1000
		]
		var role_summary := String(manifest.get("challenge_role_summary", ""))
		var action_hint := (
			"点击移出本局菜单" if _selected_ids.has(recipe_id) else "点击加入本局菜单"
		)
		button.tooltip_text = "%s\n%s" % [role_summary, action_hint]
		if _selected_ids.has(recipe_id):
			UiStyle.apply_primary(button, Color("#546BDD"))
		else:
			UiStyle.apply_secondary(button)
		button.pressed.connect(_toggle_recipe.bind(recipe_id))
		grid.add_child(button)


func _rebuild_slots() -> void:
	var slots: GridContainer = $Content/Body/MenuPanel/Menu/MenuSlots
	for child in slots.get_children():
		child.queue_free()
	for index in range(MenuService.MAX_RECIPES):
		var button := Button.new()
		button.custom_minimum_size = Vector2(260, 82)
		if index < _selected_ids.size():
			var recipe_id := _selected_ids[index]
			var role := _service.primary_role(_recipe_defs.get(recipe_id, {}))
			button.text = "%02d  %s\n%s" % [
				index + 1,
				_recipe_name(recipe_id),
				String(ROLE_NAMES.get(role, role))
			]
			button.tooltip_text = "点击从本局菜单移除"
			button.pressed.connect(_toggle_recipe.bind(recipe_id))
			UiStyle.apply_secondary(button)
		else:
			button.text = "%02d  待上桌\n可从左侧收藏加入" % (index + 1)
			button.disabled = true
			UiStyle.apply_secondary(button)
		slots.add_child(button)


func _refresh_summary() -> void:
	var analysis := _service.analyze_menu(_selected_ids, _recipe_defs)
	var role_counts: Dictionary = analysis.get("role_counts", {})
	var role_parts: Array[String] = []
	for role in role_counts:
		role_parts.append("%s %d" % [
			String(ROLE_NAMES.get(String(role), String(role))),
			int(role_counts[role])
		])
	role_parts.sort()
	$Content/Body/MenuPanel/Menu/MenuTitle.text = "本局菜单 %d / %d" % [
		_selected_ids.size(),
		MenuService.MAX_RECIPES
	]
	$Content/Body/MenuPanel/Menu/MenuSummary.text = (
		" · ".join(role_parts) if not role_parts.is_empty() else "尚未选择构筑方向"
	)
	var valid := (
		_selected_ids.size() >= MenuService.MIN_RECIPES
		and _selected_ids.size() <= MenuService.MAX_RECIPES
	)
	$Content/Body/MenuPanel/Menu/Actions/SaveButton.disabled = not valid
	var missing_roles: Array[String] = []
	for required_role in ["tempo", "pairing", "signature"]:
		if not role_counts.has(required_role):
			missing_roles.append(String(ROLE_NAMES.get(required_role, required_role)))
	$Content/Body/MenuPanel/Menu/CoverageSummary.text = (
		"当前标准路线覆盖：周转、联动、招牌均已具备"
		if missing_roles.is_empty()
		else "当前标准路线缺少：" + "、".join(missing_roles)
	)
	if _selected_ids.size() < MenuService.MIN_RECIPES:
		$Content/Body/MenuPanel/Menu/Status.text = "至少还需加入 %d 个配方" % (
			MenuService.MIN_RECIPES - _selected_ids.size()
		)
	elif _selected_ids.size() < MenuService.MAX_RECIPES:
		$Content/Body/MenuPanel/Menu/Status.text = "还可加入 %d 个配方" % (
			MenuService.MAX_RECIPES - _selected_ids.size()
		)
	else:
		$Content/Body/MenuPanel/Menu/Status.text = "菜单已满；移除后可替换"


func _toggle_recipe(recipe_id: String) -> void:
	if _selected_ids.has(recipe_id):
		_selected_ids.erase(recipe_id)
	elif _selected_ids.size() < MenuService.MAX_RECIPES:
		_selected_ids.append(recipe_id)
	_rebuild_all()


func _on_role_filter_selected(index: int) -> void:
	var filter: OptionButton = $Content/Body/CollectionPanel/Collection/Filters/RoleFilter
	_role_filter = String(filter.get_item_metadata(index))
	_rebuild_collection()


func _on_branch_filter_selected(index: int) -> void:
	var filter: OptionButton = $Content/Body/CollectionPanel/Collection/Filters/BranchFilter
	_branch_filter = String(filter.get_item_metadata(index))
	_rebuild_collection()


func _on_tag_filter_selected(index: int) -> void:
	var filter: OptionButton = $Content/Body/CollectionPanel/Collection/Filters/TagFilter
	_tag_filter = String(filter.get_item_metadata(index))
	_rebuild_collection()


func _on_shape_filter_selected(index: int) -> void:
	var filter: OptionButton = $Content/Body/CollectionPanel/Collection/Filters/ShapeFilter
	_shape_filter = String(filter.get_item_metadata(index))
	_rebuild_collection()


func _restore_default() -> void:
	_selected_ids = []
	for recipe_id in _default_ids:
		if _available_ids.has(recipe_id) and _selected_ids.size() < MenuService.MAX_RECIPES:
			_selected_ids.append(recipe_id)
	_rebuild_all()


func _rebuild_presets() -> void:
	var selector: OptionButton = $Content/Body/MenuPanel/Menu/PresetRow/PresetSelector
	selector.clear()
	for preset_value in _saved_menus:
		if not preset_value is Dictionary:
			continue
		selector.add_item(String(preset_value.get("display_name", preset_value.get("id", ""))))
		selector.set_item_metadata(selector.item_count - 1, String(preset_value.get("id", "")))
	$Content/Body/MenuPanel/Menu/PresetRow/LoadPresetButton.disabled = selector.item_count == 0


func _load_selected_preset() -> void:
	var selector: OptionButton = $Content/Body/MenuPanel/Menu/PresetRow/PresetSelector
	if selector.item_count > 0:
		preset_load_requested.emit(String(selector.get_item_metadata(selector.selected)))


func _save_selected_preset() -> void:
	var selector: OptionButton = $Content/Body/MenuPanel/Menu/PresetRow/PresetSelector
	var preset_id := ""
	var display_name := ""
	if selector.item_count > 0 and selector.selected >= 0:
		preset_id = String(selector.get_item_metadata(selector.selected))
		display_name = selector.get_item_text(selector.selected)
	else:
		var next_index := _saved_menus.size() + 1
		preset_id = "menu_preset_%d" % next_index
		display_name = "菜单方案 %d" % next_index
	preset_save_requested.emit(preset_id, display_name, _selected_ids.duplicate())


func _build_metadata_filter(filter: OptionButton, title: String, values: Array[String]) -> void:
	filter.clear()
	filter.add_item(title)
	filter.set_item_metadata(0, "")
	for value in values:
		filter.add_item(value)
		filter.set_item_metadata(filter.item_count - 1, value)


func _collect_manifest_values(field: String) -> Array[String]:
	var result: Array[String] = []
	for recipe_id in _available_ids:
		var value := String((_manifest_recipes.get(recipe_id, {}) as Dictionary).get(field, ""))
		if not value.is_empty() and not result.has(value):
			result.append(value)
	result.sort()
	return result


func _collect_recipe_tags() -> Array[String]:
	var result: Array[String] = []
	for recipe_id in _available_ids:
		for tag in (_recipe_defs.get(recipe_id, {}) as Dictionary).get("tags", []):
			var value := String(tag)
			if not value.is_empty() and not result.has(value):
				result.append(value)
	result.sort()
	return result


func _shape_bucket(cell_count: int) -> String:
	if cell_count <= 1:
		return "1"
	if cell_count == 2:
		return "2"
	return "3+"


func _load_manifest_recipes() -> Dictionary:
	var file := FileAccess.open("res://doc/challenge/recipe_progression_manifest.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return (
		(parsed as Dictionary).get("recipes", {})
		if parsed is Dictionary
		else {}
	)


func _recipe_name(recipe_id: String) -> String:
	return String((_catalog_recipes.get(recipe_id, {}) as Dictionary).get("name", recipe_id))
