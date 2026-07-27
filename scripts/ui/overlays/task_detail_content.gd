extends VBoxContainer

const TaskService = preload("res://scripts/task_service.gd")
const TaskObjectiveRowScene := preload("res://scenes/ui/overlays/task_objective_row.tscn")

var detail_text: RichTextLabel
var objective_list: VBoxContainer
var action_button: Button

var _view
var _task_id := ""
var _action_kind := ""


func configure(view, task: Dictionary, empty_text: String = "") -> void:
	_bind_nodes()
	_view = view
	_task_id = String(task.get("id", ""))
	_action_kind = String(task.get("action_kind", ""))
	_clear_objectives()
	if task.is_empty():
		detail_text.text = empty_text if not empty_text.is_empty() else "当前没有可处理的任务。"
		action_button.text = "暂无操作"
		action_button.disabled = true
	else:
		var task_status := String(task.get("status", ""))
		var unlock_label := "解锁已生效" if task_status == "completed" else "完成后解锁"
		var reward_text := String(view.call("_task_reward_text", task.get("reward", {})))
		var rating_text := _rating_detail(task)
		if _action_kind == "shop_upgrade":
			detail_text.text = "%s\n\n%s\n\n进度：%s\n升级效果：%s\n操作：达标后点击“升级店铺”，扣除金币；累计口碑不扣除。\n状态：%s" % [
				String(task.get("title", task.get("id", ""))),
				String(task.get("description", "")),
				String(view.call("_task_progress_text", task)),
				String(task.get("effect_text", "开放下一等级经营内容")),
				_upgrade_requirement_status(task)
			]
		else:
			detail_text.text = "%s\n\n%s\n\n进度：%s%s\n%s：%s\n任务奖励：%s\n状态：%s\n来源：%s" % [
				String(task.get("title", task.get("id", ""))),
				String(task.get("description", "")),
				String(view.call("_task_progress_text", task)),
				rating_text,
				unlock_label,
				String(view.call("_task_unlock_text", task.get("reward", {}))),
				reward_text,
				String(view.call("_task_claim_status_text", task)),
				String(task.get("source_stage", "经营"))
			]
		_fill_objectives(task)
		var is_claimable := task_status == "completed" and String(task.get("claim_status", "")) == "claimable"
		if _action_kind == "shop_upgrade":
			action_button.text = "升级店铺"
			action_button.disabled = not bool(task.get("can_upgrade", false))
			action_button.tooltip_text = _upgrade_tooltip(task)
		else:
			action_button.text = "选择合同" if task_status == "candidate" else "领取奖励" if is_claimable else "前往"
			action_button.disabled = false
			action_button.tooltip_text = ""


func _ready() -> void:
	_bind_nodes()
	if not action_button.pressed.is_connected(_on_action_pressed):
		action_button.pressed.connect(_on_action_pressed)


func _on_action_pressed() -> void:
	if _view == null:
		return
	if _action_kind == "shop_upgrade":
		_view.call("_on_task_shop_upgrade_requested", _task_id)
	elif action_button.text == "选择合同":
		_view.call("_on_task_contract_select_requested", _task_id)
	elif action_button.text == "领取奖励":
		_view.call("_on_task_claim_reward_pressed", _task_id)
	else:
		_view.call("_on_task_go_button_pressed", _task_id)


func _upgrade_tooltip(task: Dictionary) -> String:
	if bool(task.get("can_upgrade", false)):
		return "扣除 %d 金币并升级；累计口碑不会扣除。" % int(task.get("cost", 0))
	var missing: Array[String] = []
	var missing_coins := maxi(0, int(task.get("missing_coins", 0)))
	var missing_reputation := maxi(0, int(task.get("missing_reputation", 0)))
	if missing_coins > 0:
		missing.append("金币 %d" % missing_coins)
	if missing_reputation > 0:
		missing.append("口碑 %d" % missing_reputation)
	return "还缺%s。" % "、".join(missing)


func _upgrade_requirement_status(task: Dictionary) -> String:
	if bool(task.get("can_upgrade", false)):
		return "可以升级"
	var missing: Array[String] = []
	var missing_coins := maxi(0, int(task.get("missing_coins", 0)))
	var missing_reputation := maxi(0, int(task.get("missing_reputation", 0)))
	if missing_coins > 0:
		missing.append("金币 %d" % missing_coins)
	if missing_reputation > 0:
		missing.append("累计口碑 %d" % missing_reputation)
	return "条件未满足｜还需%s" % "、".join(missing)


func _bind_nodes() -> void:
	if detail_text != null:
		return
	detail_text = $TaskDetailText
	objective_list = $TaskObjectiveList
	action_button = $TaskActionButton


func _fill_objectives(task: Dictionary) -> void:
	var progress: Dictionary = task.get("progress", {})
	for objective in TaskService.task_objective_entries(task, progress):
		var row := TaskObjectiveRowScene.instantiate()
		row.call("configure", objective)
		objective_list.add_child(row)


func _clear_objectives() -> void:
	for child in objective_list.get_children():
		objective_list.remove_child(child)
		child.queue_free()


func _rating_detail(task: Dictionary) -> String:
	var tiers_value: Variant = task.get("tiers", [])
	if not tiers_value is Array or (tiers_value as Array).is_empty():
		return ""
	var tier_ids: Array[String] = []
	for tier_value in tiers_value as Array:
		if tier_value is Dictionary:
			tier_ids.append(String((tier_value as Dictionary).get("id", "")).capitalize())
	var lines: Array[String] = ["\n评级：%s" % " / ".join(tier_ids)]
	var progress: Dictionary = task.get("progress", {})
	var evaluation: Dictionary = progress.get("evaluation", {})
	var highest := String(evaluation.get("highest_tier", ""))
	if not highest.is_empty():
		lines.append("本轮最高：%s" % highest.capitalize())
	var next_failures: Array = evaluation.get("next_failures", [])
	for failure_value in next_failures.slice(0, 3):
		if failure_value is Dictionary:
			lines.append("未达成：%s" % String((failure_value as Dictionary).get("reason", "")))
	return "\n".join(lines)
