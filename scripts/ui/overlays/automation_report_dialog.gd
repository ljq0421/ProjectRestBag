extends AcceptDialog

const Catalog = preload("res://scripts/catalog.gd")

signal navigate_requested(kind: String, key: String)

@onready var summary_label: Label = $ReportBody/Content/SummaryLabel
@onready var output_list: ItemList = $ReportBody/Content/OutputList
@onready var product_list: ItemList = $ReportBody/Content/ProductList
@onready var growth_list: ItemList = $ReportBody/Content/GrowthList
@onready var pause_list: ItemList = $ReportBody/Content/PauseList
@onready var navigate_button: Button = $ReportBody/Content/NavigateButton

var _catalog := Catalog.new()


func _ready() -> void:
	pause_list.item_selected.connect(_on_pause_selected)
	navigate_button.pressed.connect(_on_navigate_pressed)
	$DialogChrome/CloseButton.pressed.connect(_on_image_close_pressed)
	navigate_button.disabled = true


func _on_image_close_pressed() -> void:
	hide()
	close_requested.emit()


func configure(report: Dictionary) -> void:
	_ensure_node_references()
	var from_unix := int(report.get("from_unix", 0))
	var to_unix := int(report.get("to_unix", from_unix))
	var duration := maxi(0, to_unix - from_unix)
	var cutoff := bool(report.get("event_limit_reached", false))
	var duration_cutoff := bool(report.get("truncated", false)) and int(report.get("to_unix", 0)) < int(report.get("requested_to_unix", report.get("to_unix", 0)))
	summary_label.text = "离线 %s｜完成 %d 轮原料、%d 轮甜品%s" % [
		_duration_text(duration),
		int(report.get("output_cycle_count", 0)),
		int(report.get("kitchen_cycle_count", 0)),
		("｜已触及时长上限" if duration_cutoff else ("｜已触及事件上限" if cutoff else ""))
	]
	_fill_dictionary_list(output_list, report.get("outputs", {}), false, "原料：本次没有新增收获。")
	_fill_dictionary_list(product_list, report.get("product_outputs", {}), true, "甜品：本次没有完成制作。")
	growth_list.clear()
	var growth: Dictionary = report.get("growth", {}) if report.get("growth", {}) is Dictionary else {}
	if growth.is_empty():
		var kitchen_cycles := int(report.get("kitchen_cycle_count", 0))
		growth_list.add_item("成长：%s" % ("本次没有新增制作成长。" if kitchen_cycles == 0 else "自动制作已记录 %d 次配方成长。" % kitchen_cycles))
	else:
		var recipe_ids: Array[String] = []
		for recipe_value: Variant in growth.keys():
			recipe_ids.append(String(recipe_value))
		recipe_ids.sort()
		for recipe_id in recipe_ids:
			var entry_value: Variant = growth.get(recipe_id, {})
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				growth_list.add_item("成长：%s 成品×%d｜批次 %d｜%s → %s" % [
					_recipe_name(recipe_id),
					int(entry.get("made_count", 0)),
					int(entry.get("made_batches", 0)),
					String(entry.get("before_stage", "试作品")),
					String(entry.get("after_stage", entry.get("before_stage", "试作品")))
				])
			else:
				growth_list.add_item("成长：%s +%d" % [_recipe_name(recipe_id), int(entry_value)])
	_fill_pause_list(report)
	navigate_button.disabled = pause_list.get_selected_items().is_empty()


func _fill_dictionary_list(list: ItemList, value: Variant, products: bool, empty_text: String) -> void:
	list.clear()
	var entries: Dictionary = value if value is Dictionary else {}
	if entries.is_empty():
		list.add_item(empty_text)
		return
	var keys: Array[String] = []
	for key_value: Variant in entries.keys():
		keys.append(String(key_value))
	keys.sort()
	for key in keys:
		var display_name := _recipe_name(key) if products else _item_name(key)
		list.add_item("%s ×%d" % [display_name, int(entries.get(key, 0))])


func _fill_pause_list(report: Dictionary) -> void:
	pause_list.clear()
	var pauses: Array = report.get("pauses", []) if report.get("pauses", []) is Array else []
	for pause_value: Variant in pauses:
		if not pause_value is Dictionary:
			continue
		var pause: Dictionary = pause_value
		var rule_id := String(pause.get("rule_id", ""))
		var reason: Dictionary = pause.get("reason", {}) if pause.get("reason", {}) is Dictionary else {}
		var reason_code := String(reason.get("code", ""))
		pause_list.add_item(_reason_text(reason, "系统" if reason_code == "clock_rollback" else "厨房规则"))
		pause_list.set_item_metadata(
			pause_list.item_count - 1,
			{"kind": "system", "key": "clock_rollback"} if reason_code == "clock_rollback" else {"kind": "kitchen", "key": rule_id}
		)
	var paused_slots: Array = report.get("paused_slots", []) if report.get("paused_slots", []) is Array else []
	for pause_value: Variant in paused_slots:
		if not pause_value is Dictionary:
			continue
		var pause: Dictionary = pause_value
		var slot_key := String(pause.get("slot_key", ""))
		var reason: Dictionary = pause.get("reason", {}) if pause.get("reason", {}) is Dictionary else {}
		pause_list.add_item(_reason_text(reason, _slot_name(slot_key)))
		pause_list.set_item_metadata(pause_list.item_count - 1, {"kind": "output", "key": slot_key})
	if bool(report.get("event_limit_reached", false)):
		pause_list.add_item("结算事件达到安全上限；请关闭后继续在线运行。")
		pause_list.set_item_metadata(pause_list.item_count - 1, {"kind": "system", "key": "event_limit"})
	var duration_cutoff := bool(report.get("truncated", false)) and int(report.get("to_unix", 0)) < int(report.get("requested_to_unix", report.get("to_unix", 0)))
	if duration_cutoff:
		pause_list.add_item("本次已达到离线结算时长上限；超出部分不再追溯。")
		pause_list.set_item_metadata(pause_list.item_count - 1, {"kind": "system", "key": "time_limit"})
	if pauses.is_empty() and paused_slots.is_empty() and not bool(report.get("event_limit_reached", false)) and not duration_cutoff:
		pause_list.add_item("暂停：没有需要处理的项目。")
		pause_list.set_item_disabled(0, true)


func _on_pause_selected(index: int) -> void:
	navigate_button.disabled = index < 0 or index >= pause_list.item_count or pause_list.is_item_disabled(index)


func _on_navigate_pressed() -> void:
	var selected := pause_list.get_selected_items()
	if selected.is_empty():
		return
	var metadata: Variant = pause_list.get_item_metadata(selected[0])
	if metadata is Dictionary:
		navigate_requested.emit(String(metadata.get("kind", "system")), String(metadata.get("key", "")))


func _duration_text(seconds: int) -> String:
	var hours := seconds / 3600
	var minutes := (seconds % 3600) / 60
	if hours > 0:
		return "%d 小时 %d 分钟" % [hours, minutes]
	if minutes > 0:
		return "%d 分钟" % minutes
	return "%d 秒" % seconds


func _reason_text(reason: Dictionary, subject: String) -> String:
	var code := String(reason.get("code", "unknown"))
	var item_id := String(reason.get("item_id", ""))
	match code:
		"missing_input":
			return "%s：补充%s（现有 %d，需要 %d）。" % [subject, _item_name(item_id), int(reason.get("available", 0)), int(reason.get("required", 0))]
		"material_reserve":
			return "%s：%s已触及保留量。" % [subject, _item_name(item_id)]
		"target_reached":
			return "%s：目标库存已达成。" % subject
		"manual_queue_busy":
			return "%s：手动制作正在使用设备。" % subject
		"offline_disabled":
			return "%s：规则未允许离线制作。" % subject
		"invalid_recipe":
			return "%s：配方已失效，请重新选择甜品。" % subject
		"invalid_device":
			return "%s：制作设备不可用。" % subject
		"insufficient_coins":
			return "%s：金币不足，补足后将继续。" % subject
		"clock_rollback":
			return "系统时间回退，本次未结算。"
		"limit_reached":
			return "%s：已达到当前托管上限。" % subject
	return "%s：自动化暂停（%s）。" % [subject, code]


func _slot_name(slot_key: String) -> String:
	var parts := slot_key.split(":")
	var site_id := String(parts[0]) if not parts.is_empty() else ""
	var slot_number := int(parts[1]) + 1 if parts.size() > 1 else 1
	var site_name: String = String({"farm": "农场", "ranch": "牧场", "forest": "林场", "pond": "水塘"}.get(site_id, "产地"))
	return "%s %d 号槽" % [site_name, slot_number]


func _item_name(item_id: String) -> String:
	var ingredient: Dictionary = _catalog.get_ingredients().get(item_id, {})
	if not ingredient.is_empty():
		return String(ingredient.get("name", item_id))
	return _recipe_name(item_id)


func _recipe_name(recipe_id: String) -> String:
	return String(_catalog.get_recipes().get(recipe_id, {}).get("name", recipe_id))


func _ensure_node_references() -> void:
	if is_instance_valid(summary_label):
		return
	summary_label = get_node("ReportBody/Content/SummaryLabel") as Label
	output_list = get_node("ReportBody/Content/OutputList") as ItemList
	product_list = get_node("ReportBody/Content/ProductList") as ItemList
	growth_list = get_node("ReportBody/Content/GrowthList") as ItemList
	pause_list = get_node("ReportBody/Content/PauseList") as ItemList
	navigate_button = get_node("ReportBody/Content/NavigateButton") as Button
