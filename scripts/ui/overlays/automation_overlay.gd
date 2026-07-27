extends VBoxContainer

const AutomationService = preload("res://scripts/automation_service.gd")
const StarProgressionService = preload("res://scripts/star_progression_service.gd")
const TaskService = preload("res://scripts/task_service.gd")

signal close_requested()
signal upgrade_requested(upgrade_id: String)
signal pause_all_requested()

const UPGRADE_COPY := {
	"output_capacity_1": ["托管扩容 I", "可托管产地提升至 2 块"],
	"offline_duration_1": ["离线延长 I", "离线结算提升至 4 小时"],
	"output_capacity_2": ["托管扩容 II", "可托管产地提升至 3 块"],
	"offline_duration_2": ["离线延长 II", "离线结算提升至 8 小时"],
	"output_capacity_all": ["全产地托管", "取消托管产地上限"],
	"kitchen_devices_2": ["双设备排程", "同时托管 2 类厨房设备"],
	"kitchen_rules_3": ["规则扩容", "自动制作规则提升至 3 条"],
	"kitchen_priority": ["优先级排程", "可调整规则执行顺序"],
	"kitchen_inventory_policy": ["库存策略", "可设置目标库存与原料保留"],
	"kitchen_all": ["全厨房托管", "全部设备、最多 8 条规则"]
}

@onready var starlight_balance_label: Label = $SummaryRow/StarlightBalanceLabel
@onready var next_unlock_label: Label = $SummaryRow/NextUnlockLabel
@onready var output_status_label: Label = $OutputSection/OutputStatusLabel
@onready var output_upgrade_grid: GridContainer = $OutputSection/OutputUpgradeGrid
@onready var kitchen_status_label: Label = $KitchenSection/KitchenStatusLabel
@onready var kitchen_upgrade_grid: GridContainer = $KitchenSection/KitchenUpgradeGrid
@onready var pause_all_button: Button = $Footer/PauseAllButton


func _ready() -> void:
	for grid in [output_upgrade_grid, kitchen_upgrade_grid]:
		for child in grid.get_children():
			if child is Button and child.has_meta("upgrade_id"):
				(child as Button).pressed.connect(_on_upgrade_pressed.bind(String(child.get_meta("upgrade_id"))))
	pause_all_button.pressed.connect(func() -> void: pause_all_requested.emit())


func refresh(state) -> void:
	if state == null:
		return
	_ensure_node_references()
	starlight_balance_label.text = "食谱星辉 可用 %d｜累计 %d" % [state.recipe_starlight_available, state.recipe_starlight_total]
	next_unlock_label.text = _next_unlock_text(state)
	output_status_label.text = _output_status_text(state)
	kitchen_status_label.text = _kitchen_status_text(state)
	refresh_upgrade_buttons(state)
	pause_all_button.text = "恢复全部自动化" if state.automation_paused else "暂停全部自动化"
	pause_all_button.disabled = not state.is_automation_unlocked("output") and not state.is_automation_unlocked("kitchen")
	if pause_all_button.disabled:
		pause_all_button.tooltip_text = "解锁原料产地自动化后可统一暂停。"
	else:
		pause_all_button.tooltip_text = "恢复后从当前时间继续自动化。" if state.automation_paused else "暂停产地收获、续产与厨房自动制作。"


func _ensure_node_references() -> void:
	if not is_instance_valid(starlight_balance_label):
		starlight_balance_label = get_node("SummaryRow/StarlightBalanceLabel") as Label
		next_unlock_label = get_node("SummaryRow/NextUnlockLabel") as Label
		output_status_label = get_node("OutputSection/OutputStatusLabel") as Label
		output_upgrade_grid = get_node("OutputSection/OutputUpgradeGrid") as GridContainer
		kitchen_status_label = get_node("KitchenSection/KitchenStatusLabel") as Label
		kitchen_upgrade_grid = get_node("KitchenSection/KitchenUpgradeGrid") as GridContainer
		pause_all_button = get_node("Footer/PauseAllButton") as Button


func show_mode(_mode: String = "automation") -> void:
	visible = true


func hide_mode() -> void:
	visible = false


func refresh_upgrade_buttons(state) -> void:
	for grid in [output_upgrade_grid, kitchen_upgrade_grid]:
		for child in grid.get_children():
			if child is Button and child.has_meta("upgrade_id"):
				_refresh_upgrade_button(child as Button, state)


func _refresh_upgrade_button(button: Button, state) -> void:
	var upgrade_id := String(button.get_meta("upgrade_id", ""))
	var definition := StarProgressionService.upgrade_definition(upgrade_id)
	var cost := maxi(0, int(definition.get("cost", 0)))
	var copy: Array = UPGRADE_COPY.get(upgrade_id, [upgrade_id, "自动化能力提升"])
	var base_text := "%s｜%s｜消耗 %d 星辉" % [copy[0], copy[1], cost]
	button.text = base_text
	button.disabled = true
	if definition.is_empty():
		button.tooltip_text = "升级配置缺失。"
		return
	if bool(state.automation_upgrades.get(upgrade_id, false)):
		button.text = "%s｜已购买" % base_text
		button.tooltip_text = "该升级已生效。"
		return
	var feature_id := String(definition.get("feature", ""))
	if not state.is_automation_unlocked(feature_id):
		button.tooltip_text = "先完成对应功能任务，解锁%s自动化。" % ("原料产地" if feature_id == "output" else "厨房甜品")
		return
	var missing_names: Array[String] = []
	var required_value: Variant = definition.get("requires_upgrades", [])
	if required_value is Array:
		for required_id_value: Variant in required_value:
			var required_id := String(required_id_value)
			if not bool(state.automation_upgrades.get(required_id, false)):
				var required_copy: Array = UPGRADE_COPY.get(required_id, [required_id, ""])
				missing_names.append(String(required_copy[0]))
	if not missing_names.is_empty():
		button.tooltip_text = "先购买：%s。" % "、".join(missing_names)
		return
	if int(state.recipe_starlight_available) < cost:
		button.tooltip_text = "星辉不足，还差 %d。" % (cost - int(state.recipe_starlight_available))
		return
	button.disabled = false
	button.tooltip_text = "购买后立即生效，消耗 %d 食谱星辉。" % cost


func _on_upgrade_pressed(upgrade_id: String) -> void:
	upgrade_requested.emit(upgrade_id)


func _next_unlock_text(state) -> String:
	if not state.is_automation_unlocked("output"):
		return "下一解锁：原料产地｜%s · 完成“产地轮转”" % _feature_gate_text("output")
	if not state.is_automation_unlocked("kitchen"):
		return "下一解锁：厨房甜品｜%s · 完成“稳定出品”" % _feature_gate_text("kitchen")
	return "两类自动化已解锁｜星辉可继续投入托管与排程升级"


func _output_status_text(state) -> String:
	if not state.is_automation_unlocked("output"):
		return "未解锁｜达到 %s 并完成“产地轮转”\n产地轮转：%s" % [_feature_gate_text("output"), _feature_task_progress_text(state, "feature_output_automation")]
	var limit := AutomationService.output_site_limit(state)
	var limit_text := "全部产地" if limit < 0 else "%d 块产地" % limit
	var paused_text := "全局暂停" if state.automation_paused else "运行中"
	return "%s｜已托管 %d｜上限 %s｜离线结算 %d 小时" % [paused_text, state.managed_production_sites.size(), limit_text, AutomationService.offline_seconds_limit(state) / 3600]


func _kitchen_status_text(state) -> String:
	if not state.is_automation_unlocked("kitchen"):
		return "未解锁｜先解锁原料产地，再达到 %s 并完成“稳定出品”\n稳定出品：%s" % [_feature_gate_text("kitchen"), _feature_task_progress_text(state, "feature_kitchen_automation")]
	var device_limit := AutomationService.kitchen_device_limit(state)
	var device_text := "全部设备" if device_limit < 0 else "%d 类设备" % device_limit
	var paused_text := "全局暂停" if state.automation_paused else "运行中"
	return "%s｜规则 %d/%d｜可托管 %s" % [paused_text, state.kitchen_automation_rules.size(), AutomationService.kitchen_rule_limit(state), device_text]


func _feature_gate_text(feature_id: String) -> String:
	var gate := StarProgressionService.feature_gate(feature_id)
	return "Lv.%d · 累计 %d 星辉" % [int(gate.get("level", 0)), int(gate.get("lifetime_starlight", 0))]


func _feature_task_progress_text(state, task_id: String) -> String:
	var task: Dictionary = TaskService.get_task_definitions().get(task_id, {})
	var progress: Dictionary = state.task_progress.get(task_id, {})
	return TaskService.format_task_progress_detail(task, progress)
