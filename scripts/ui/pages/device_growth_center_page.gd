class_name DeviceGrowthCenterPage
extends VBoxContainer

signal upgrade_requested(device_id: String)
signal catalog_filter_requested(device_id: String)

const DEVICE_ORDER := ["round_pot", "oven", "chiller", "griddle", "mixer"]
const DEVICE_ICON_DIRECTORY := "res://resources/ui/device_v1"

@onready var device_buttons: HBoxContainer = $DeviceSelectorPanel/DeviceButtons
@onready var detail_columns: HBoxContainer = $DeviceDetailColumns
@onready var empty_state_label: Label = $EmptyStateLabel
@onready var title_label: Label = $DeviceDetailColumns/DetailPanel/DetailContent/Header/TitleLabel
@onready var catalog_button: Button = $DeviceDetailColumns/DetailPanel/DetailContent/Header/CatalogButton
@onready var level_label: Label = $DeviceDetailColumns/DetailPanel/DetailContent/LevelLabel
@onready var current_effect_text: RichTextLabel = $DeviceDetailColumns/DetailPanel/DetailContent/EffectColumns/CurrentEffectPanel/CurrentEffectText
@onready var next_effect_text: RichTextLabel = $DeviceDetailColumns/DetailPanel/DetailContent/EffectColumns/NextEffectPanel/NextEffectText
@onready var recipe_summary: RichTextLabel = $DeviceDetailColumns/DetailPanel/DetailContent/RecipeSummary
@onready var waiting_label: Label = $DeviceDetailColumns/DetailPanel/DetailContent/WaitingLabel
@onready var honor_label: Label = $DeviceDetailColumns/DetailPanel/DetailContent/HonorLabel
@onready var upgrade_title: Label = $DeviceDetailColumns/UpgradePanel/UpgradeContent/UpgradeTitle
@onready var use_progress: ProgressBar = $DeviceDetailColumns/UpgradePanel/UpgradeContent/UseProgress
@onready var requirement_label: Label = $DeviceDetailColumns/UpgradePanel/UpgradeContent/RequirementLabel
@onready var upgrade_button: Button = $DeviceDetailColumns/UpgradePanel/UpgradeContent/UpgradeButton

var _state
var _catalog
var _selected_device_id := ""


func _ready() -> void:
	for device_id in DEVICE_ORDER:
		var button := device_buttons.get_node_or_null(device_id) as Button
		if button == null:
			continue
		var handler := Callable(self, "_on_device_pressed").bind(device_id)
		if not button.pressed.is_connected(handler):
			button.pressed.connect(handler)
	if not upgrade_button.pressed.is_connected(_on_upgrade_pressed):
		upgrade_button.pressed.connect(_on_upgrade_pressed)
	if not catalog_button.pressed.is_connected(_on_catalog_pressed):
		catalog_button.pressed.connect(_on_catalog_pressed)


func refresh(state, catalog, preferred_device_id: String = "") -> void:
	_state = state
	_catalog = catalog
	if _state == null or _catalog == null:
		_show_empty_state("设备培养数据暂不可用。")
		return
	var devices: Dictionary = _catalog.get_devices()
	for device_id in DEVICE_ORDER:
		_refresh_device_button(device_id, devices.get(device_id, {}))
	if not preferred_device_id.is_empty() and _is_device_unlocked(preferred_device_id):
		_selected_device_id = preferred_device_id
	elif not _selected_device_id.is_empty() and _is_device_unlocked(_selected_device_id):
		pass
	else:
		_selected_device_id = _first_unlocked_device_id()
	if _selected_device_id.is_empty():
		_show_empty_state("尚未解锁成品设备；解锁后可在这里查看培养进度。")
		return
	empty_state_label.visible = false
	detail_columns.visible = true
	_refresh_selected_button_state()
	_refresh_detail()


func upgrade_ready_count(state, catalog) -> int:
	if state == null or catalog == null:
		return 0
	var result := 0
	var devices: Dictionary = catalog.get_devices()
	for device_id in DEVICE_ORDER:
		var device: Dictionary = devices.get(device_id, {})
		if not bool(device.get("recipe_growth_enabled", false)):
			continue
		if not state.is_device_unlocked(device_id):
			continue
		if bool(state.device_growth_quote(device_id).get("can_upgrade", false)):
			result += 1
	return result


func selected_device_id() -> String:
	return _selected_device_id


func _refresh_device_button(device_id: String, device: Dictionary) -> void:
	var button := device_buttons.get_node_or_null(device_id) as Button
	if button == null:
		return
	var display_name := String(device.get("name", device_id))
	var icon_path := "%s/%s.png" % [DEVICE_ICON_DIRECTORY, device_id]
	button.icon = load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null
	button.tooltip_text = String(device.get("usage", ""))
	if not _is_device_unlocked(device_id):
		var unlock_level := int(device.get("unlock_level", 0))
		var unlock_text := "完成引导解锁" if unlock_level >= 999 else "店铺 Lv.%d 解锁" % unlock_level
		button.text = "%s\n🔒 %s" % [display_name, unlock_text]
		button.disabled = true
		button.button_pressed = false
		return
	var growth: Dictionary = _state.get_device_growth(device_id)
	var quote: Dictionary = _state.device_growth_quote(device_id)
	var level := int(growth.get("level", 1))
	if level >= 5:
		button.text = "%s  L5\n◆ 已满级" % display_name
		button.tooltip_text = "%s\n设备已满级" % button.tooltip_text
	else:
		var use_count := int(growth.get("use_count", 0))
		var required_uses := int(quote.get("required_uses", use_count))
		button.text = "%s  L%d\n%d/%d%s" % [
			display_name,
			level,
			use_count,
			required_uses,
			"  可升级" if bool(quote.get("can_upgrade", false)) else ""
		]
		if bool(quote.get("can_upgrade", false)):
			button.tooltip_text = "%s\n升级条件已满足" % button.tooltip_text
	button.disabled = false


func _refresh_detail() -> void:
	var devices: Dictionary = _catalog.get_devices()
	var device: Dictionary = devices.get(_selected_device_id, {})
	var growth: Dictionary = _state.get_device_growth(_selected_device_id)
	var quote: Dictionary = _state.device_growth_quote(_selected_device_id)
	var level := int(growth.get("level", 1))
	title_label.text = String(device.get("name", _selected_device_id))
	level_label.text = "当前 L%d%s" % [level, "　◆ 满级铭牌" if level >= 5 else ""]
	current_effect_text.text = "[b]当前效果[/b]\n%s" % String(quote.get("current_effect", ""))
	next_effect_text.text = "[b]下一等级[/b]\n%s" % String(quote.get("next_effect", "已满级"))
	var stage_counts := {0: 0, 1: 0, 2: 0}
	var waiting_count := 0
	var recipes: Dictionary = _catalog.get_recipes()
	for recipe_id_value in _state.unlocked_recipes:
		var recipe_id := String(recipe_id_value)
		if String(recipes.get(recipe_id, {}).get("device", "")) != _selected_device_id:
			continue
		var recipe_growth: Dictionary = _state.get_recipe_growth(recipe_id)
		var stage := clampi(int(recipe_growth.get("mastery_level", 0)), 0, 2)
		stage_counts[stage] = int(stage_counts.get(stage, 0)) + 1
		if bool(_state.recipe_growth_status(recipe_id).get("waiting_for_device", false)):
			waiting_count += 1
	recipe_summary.text = "[b]关联配方[/b]　试作 %d｜人气 %d｜招牌 %d" % [
		stage_counts[0],
		stage_counts[1],
		stage_counts[2]
	]
	waiting_label.text = "%d 道配方正在等待设备条件。" % waiting_count if waiting_count > 0 else "当前没有等待设备条件的配方。"
	honor_label.text = "荣誉记录　成功研发 %d 次｜累计制作 %d 批" % [
		int(growth.get("research_count", 0)),
		int(growth.get("production_batch_count", 0))
	]
	var use_count := int(growth.get("use_count", 0))
	var required_uses := maxi(1, int(quote.get("required_uses", use_count)))
	use_progress.max_value = required_uses
	use_progress.value = mini(use_count, required_uses)
	if level >= 5:
		upgrade_title.text = "设备已满级"
		requirement_label.text = "有效使用 %d 次\n无需继续升级。" % use_count
		upgrade_button.text = "设备已满级"
		upgrade_button.disabled = true
		upgrade_button.tooltip_text = "该设备已经达到最高等级。"
		return
	var next_level := int(quote.get("next_level", level + 1))
	var missing_uses := int(quote.get("missing_uses", 0))
	var missing_coins := int(quote.get("missing_coins", 0))
	var coin_cost := int(quote.get("coin_cost", 0))
	upgrade_title.text = "升级至 L%d" % next_level
	requirement_label.text = "有效使用 %d/%d\n升级费用 %d 金币\n仍缺：使用 %d 次｜金币 %d" % [
		use_count,
		required_uses,
		coin_cost,
		missing_uses,
		missing_coins
	]
	upgrade_button.text = "升级到 L%d" % next_level
	upgrade_button.disabled = not bool(quote.get("can_upgrade", false))
	upgrade_button.tooltip_text = "" if not upgrade_button.disabled else "还需有效使用 %d 次、金币 %d。" % [missing_uses, missing_coins]


func _refresh_selected_button_state() -> void:
	for device_id in DEVICE_ORDER:
		var button := device_buttons.get_node_or_null(device_id) as Button
		if button != null:
			button.button_pressed = device_id == _selected_device_id


func _first_unlocked_device_id() -> String:
	for device_id in DEVICE_ORDER:
		if _is_device_unlocked(device_id):
			return device_id
	return ""


func _is_device_unlocked(device_id: String) -> bool:
	return _state != null and _state.is_device_unlocked(device_id)


func _show_empty_state(message: String) -> void:
	_selected_device_id = ""
	detail_columns.visible = false
	empty_state_label.visible = true
	empty_state_label.text = message
	_refresh_selected_button_state()


func _on_device_pressed(device_id: String) -> void:
	if not _is_device_unlocked(device_id):
		return
	_selected_device_id = device_id
	_refresh_selected_button_state()
	_refresh_detail()


func _on_upgrade_pressed() -> void:
	if not _selected_device_id.is_empty():
		upgrade_requested.emit(_selected_device_id)


func _on_catalog_pressed() -> void:
	if not _selected_device_id.is_empty():
		catalog_filter_requested.emit(_selected_device_id)
