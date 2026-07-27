extends VBoxContainer

const AutomationService = preload("res://scripts/automation_service.gd")
const Catalog = preload("res://scripts/catalog.gd")

signal rule_save_requested(rule: Dictionary)
signal rule_remove_requested(rule_id: String)
signal pause_toggled(paused: bool)

@onready var collapse_button: Button = $Header/CollapseButton
@onready var title_label: Label = $Header/TitleLabel
@onready var pause_toggle: CheckButton = $Header/PauseToggle
@onready var locked_message: Label = $LockedMessage
@onready var rule_list: ItemList = $RuleList
@onready var editor: GridContainer = $Editor
@onready var recipe_option: OptionButton = $Editor/RecipeOption
@onready var batch_option: OptionButton = $Editor/BatchOption
@onready var target_stock_spin: SpinBox = $Editor/TargetStockSpin
@onready var priority_option: OptionButton = $Editor/PriorityOption
@onready var material_reserve_list: VBoxContainer = $Editor/MaterialReserveList
@onready var save_rule_button: Button = $Editor/SaveRuleButton
@onready var remove_rule_button: Button = $Editor/RemoveRuleButton
@onready var status_label: Label = $StatusLabel

var _state
var _catalog := Catalog.new()
var _expanded := false
var _selected_rule_id := ""


func _ready() -> void:
	_apply_number_input_skin(target_stock_spin)
	collapse_button.pressed.connect(func() -> void: _set_expanded(not _expanded))
	pause_toggle.toggled.connect(func(paused: bool) -> void: pause_toggled.emit(paused))
	rule_list.item_selected.connect(_on_rule_selected)
	recipe_option.item_selected.connect(func(_index: int) -> void: _refresh_material_reserves({}))
	save_rule_button.pressed.connect(func() -> void: rule_save_requested.emit(_edited_rule()))
	remove_rule_button.pressed.connect(func() -> void: rule_remove_requested.emit(_selected_rule_id))
	_fill_static_options()
	_set_expanded(false)
	queue_redraw()


func _draw() -> void:
	var panel_style := get_theme_stylebox(&"panel")
	if panel_style != null:
		draw_style_box(panel_style, Rect2(Vector2.ZERO, size))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func refresh(state) -> void:
	_ensure_node_references()
	_state = state
	if batch_option.item_count == 0:
		_fill_static_options()
	var unlocked: bool = state != null and state.is_automation_unlocked("kitchen")
	pause_toggle.set_block_signals(true)
	pause_toggle.button_pressed = bool(state.automation_paused) if state != null else false
	pause_toggle.set_block_signals(false)
	pause_toggle.disabled = state == null or (not state.is_automation_unlocked("output") and not unlocked)
	pause_toggle.tooltip_text = "恢复后从当前时间继续全部自动化。" if pause_toggle.button_pressed else "同时暂停产地与厨房自动化。"
	locked_message.text = "尚未开放｜先解锁原料产地托管，再达到 Lv.4、累计 30 食谱星辉并完成“稳定出品”。"
	_fill_recipe_options()
	_fill_rule_list()
	_apply_upgrade_gates()
	_update_body_visibility()


func focus_rule(rule_id: String = "") -> void:
	_ensure_node_references()
	_selected_rule_id = rule_id
	_set_expanded(true)
	if _state == null:
		return
	_fill_rule_list()
	for index in range(rule_list.item_count):
		if String(rule_list.get_item_metadata(index)) == rule_id:
			rule_list.select(index)
			_on_rule_selected(index)
			return
	if rule_list.item_count > 0:
		rule_list.select(0)
		_on_rule_selected(0)


func show_service_result(result: Dictionary, action: String) -> void:
	_ensure_node_references()
	if bool(result.get("ok", false)):
		status_label.text = "规则已保存并开始按新排程执行。" if action == "save" else "规则已移除。"
		status_label.tooltip_text = ""
		status_label.theme_type_variation = &"DessertStatusTagPositive"
		return
	var reason := String(result.get("reason", "unknown"))
	var copy: String = String({
		"kitchen_locked": "厨房托管尚未解锁。",
		"invalid_rule": "规则内容无效，请检查甜品、设备与批量。",
		"limit_reached": "规则或托管设备数量已达当前上限。",
		"not_found": "这条规则已不存在，请刷新后重试。"
	}.get(reason, "服务未能处理这条规则：%s。" % reason))
	status_label.text = copy
	status_label.tooltip_text = "服务原因：%s" % reason
	status_label.theme_type_variation = &"DessertStatusTagNegative"


func _fill_static_options() -> void:
	batch_option.clear()
	batch_option.add_item("每轮 1 批")
	batch_option.set_item_metadata(0, 1)
	priority_option.clear()
	for entry in [["普通", 0], ["优先", 1], ["最高", 2]]:
		priority_option.add_item(String(entry[0]))
		priority_option.set_item_metadata(priority_option.item_count - 1, int(entry[1]))


func _set_expanded(expanded: bool) -> void:
	_ensure_node_references()
	_expanded = expanded
	collapse_button.text = "▾" if expanded else "▸"
	title_label.text = "厨房排程夹板" if expanded else "厨房排程夹板｜点击展开"
	_update_body_visibility()


func _update_body_visibility() -> void:
	_ensure_node_references()
	var unlocked: bool = _state != null and _state.is_automation_unlocked("kitchen")
	locked_message.visible = _expanded and not unlocked
	rule_list.visible = _expanded and unlocked
	editor.visible = _expanded and unlocked
	status_label.visible = _expanded and unlocked


func _fill_recipe_options() -> void:
	var preferred := _selected_option_metadata(recipe_option)
	recipe_option.clear()
	if _state == null:
		return
	var recipes: Dictionary = _catalog.get_recipes()
	var recipe_ids: Array[String] = []
	for recipe_value: Variant in recipes.keys():
		var recipe_id := String(recipe_value)
		if _state.is_recipe_unlocked(recipe_id):
			recipe_ids.append(recipe_id)
	recipe_ids.sort_custom(func(a: String, b: String) -> bool: return String(recipes[a].get("name", a)) < String(recipes[b].get("name", b)))
	for recipe_id in recipe_ids:
		var recipe: Dictionary = recipes[recipe_id]
		var device_id := String(recipe.get("device", ""))
		var device_name := String(_catalog.get_devices().get(device_id, {}).get("name", device_id))
		recipe_option.add_item("%s｜%s" % [String(recipe.get("name", recipe_id)), device_name])
		recipe_option.set_item_metadata(recipe_option.item_count - 1, recipe_id)
	_select_option_metadata(recipe_option, preferred)
	save_rule_button.disabled = recipe_option.item_count == 0


func _fill_rule_list() -> void:
	rule_list.clear()
	if _state == null or not _state.is_automation_unlocked("kitchen"):
		return
	rule_list.add_item("＋ 新建排程规则")
	rule_list.set_item_metadata(0, "")
	var recipes: Dictionary = _catalog.get_recipes()
	for rule_value: Variant in _state.kitchen_automation_rules:
		if not rule_value is Dictionary:
			continue
		var rule: Dictionary = rule_value
		var recipe_id := String(rule.get("recipe_id", ""))
		var recipe_name := String(recipes.get(recipe_id, {}).get("name", recipe_id))
		var status: Dictionary = AutomationService.kitchen_rule_status(_state, String(rule.get("id", "")))
		var state_text := "制作中" if bool(status.get("running", false)) else ("需处理" if bool(status.get("paused", false)) else "待排程")
		rule_list.add_item("%s｜%d 批｜目标 %d｜%s" % [recipe_name, int(rule.get("batches", 1)), int(rule.get("target_stock", 0)), state_text])
		rule_list.set_item_metadata(rule_list.item_count - 1, String(rule.get("id", "")))
	var selected_index := 0
	for index in range(rule_list.item_count):
		if String(rule_list.get_item_metadata(index)) == _selected_rule_id:
			selected_index = index
			break
	rule_list.select(selected_index)
	_on_rule_selected(selected_index)


func _on_rule_selected(index: int) -> void:
	if index < 0 or index >= rule_list.item_count:
		return
	_selected_rule_id = String(rule_list.get_item_metadata(index))
	var rule := _rule_by_id(_selected_rule_id)
	_apply_rule_to_editor(rule)


func _apply_rule_to_editor(rule: Dictionary) -> void:
	_select_option_metadata(recipe_option, String(rule.get("recipe_id", "")))
	_select_option_metadata(batch_option, int(rule.get("batches", 1)))
	target_stock_spin.value = maxi(0, int(rule.get("target_stock", 10)))
	_select_option_metadata(priority_option, int(rule.get("priority", 0)))
	_refresh_material_reserves(rule.get("material_reserves", {}) if rule.get("material_reserves", {}) is Dictionary else {})
	remove_rule_button.disabled = _selected_rule_id.is_empty()


func _refresh_material_reserves(reserves: Dictionary) -> void:
	for child in material_reserve_list.get_children():
		child.queue_free()
	var recipe_id := _selected_option_metadata(recipe_option)
	var recipe: Dictionary = _catalog.get_recipes().get(recipe_id, {})
	for material_value: Variant in recipe.get("materials", []):
		var material_id := String(material_value)
		var row := HBoxContainer.new()
		row.set_meta("material_id", material_id)
		var label := Label.new()
		label.text = "%s 保留" % _item_name(material_id)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var spin := SpinBox.new()
		_apply_number_input_skin(spin)
		spin.min_value = 0
		spin.max_value = 999
		spin.value = int(reserves.get(material_id, 0))
		spin.custom_minimum_size = Vector2(110, 0)
		row.add_child(label)
		row.add_child(spin)
		material_reserve_list.add_child(row)
	_apply_upgrade_gates()


func _apply_upgrade_gates() -> void:
	if _state == null:
		return
	var priority_enabled := AutomationService.priority_enabled(_state)
	priority_option.disabled = not priority_enabled
	priority_option.tooltip_text = "需要在自动化中枢购买“优先级排程”。" if not priority_enabled else "优先级更高的规则会先占用设备。"
	var policy_enabled := AutomationService.inventory_policy_enabled(_state)
	target_stock_spin.editable = policy_enabled
	target_stock_spin.tooltip_text = "需要在自动化中枢购买“库存策略”。" if not policy_enabled else "达到目标成品库存后暂停。"
	for row in material_reserve_list.get_children():
		for child in row.get_children():
			if child is SpinBox:
				(child as SpinBox).editable = policy_enabled
				(child as SpinBox).tooltip_text = "需要在自动化中枢购买“库存策略”。" if not policy_enabled else "低于保留量时暂停制作。"


func _edited_rule() -> Dictionary:
	var recipe_id := _selected_option_metadata(recipe_option)
	var recipe: Dictionary = _catalog.get_recipes().get(recipe_id, {})
	var reserves: Dictionary = {}
	for row in material_reserve_list.get_children():
		var material_id := String(row.get_meta("material_id", ""))
		for child in row.get_children():
			if child is SpinBox and int((child as SpinBox).value) > 0:
				reserves[material_id] = int((child as SpinBox).value)
	return {
		"id": _selected_rule_id,
		"recipe_id": recipe_id,
		"device_id": String(recipe.get("device", "")),
		"batches": 1,
		"target_stock": int(target_stock_spin.value),
		"priority": int(_selected_option_value(priority_option, 0)),
		"material_reserves": reserves,
		"enabled": true
	}


func _rule_by_id(rule_id: String) -> Dictionary:
	if _state == null or rule_id.is_empty():
		return {}
	for rule_value: Variant in _state.kitchen_automation_rules:
		if rule_value is Dictionary and String((rule_value as Dictionary).get("id", "")) == rule_id:
			return (rule_value as Dictionary).duplicate(true)
	return {}


func _selected_option_metadata(option: OptionButton) -> String:
	if option.item_count == 0 or option.selected < 0:
		return ""
	return String(option.get_item_metadata(option.selected))


func _selected_option_value(option: OptionButton, fallback: int) -> int:
	if option.item_count == 0 or option.selected < 0:
		return fallback
	return int(option.get_item_metadata(option.selected))


func _select_option_metadata(option: OptionButton, expected: Variant) -> void:
	for index in range(option.item_count):
		if option.get_item_metadata(index) == expected or String(option.get_item_metadata(index)) == String(expected):
			option.select(index)
			return
	if option.item_count > 0:
		option.select(0)


func _item_name(item_id: String) -> String:
	var ingredient: Dictionary = _catalog.get_ingredients().get(item_id, {})
	if not ingredient.is_empty():
		return String(ingredient.get("name", item_id))
	return String(_catalog.get_recipes().get(item_id, {}).get("name", item_id))


func _ensure_node_references() -> void:
	if is_instance_valid(collapse_button):
		return
	collapse_button = get_node("Header/CollapseButton") as Button
	title_label = get_node("Header/TitleLabel") as Label
	pause_toggle = get_node("Header/PauseToggle") as CheckButton
	locked_message = get_node("LockedMessage") as Label
	rule_list = get_node("RuleList") as ItemList
	editor = get_node("Editor") as GridContainer
	recipe_option = get_node("Editor/RecipeOption") as OptionButton
	batch_option = get_node("Editor/BatchOption") as OptionButton
	target_stock_spin = get_node("Editor/TargetStockSpin") as SpinBox
	priority_option = get_node("Editor/PriorityOption") as OptionButton
	material_reserve_list = get_node("Editor/MaterialReserveList") as VBoxContainer
	save_rule_button = get_node("Editor/SaveRuleButton") as Button
	remove_rule_button = get_node("Editor/RemoveRuleButton") as Button
	status_label = get_node("StatusLabel") as Label
	_apply_number_input_skin(target_stock_spin)


func _apply_number_input_skin(spin: SpinBox) -> void:
	if not is_instance_valid(spin):
		return
	var line_edit := spin.get_line_edit()
	if line_edit != null:
		line_edit.theme_type_variation = &"DessertNumberInput"
