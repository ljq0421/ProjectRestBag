extends Button

signal task_selected(task_id: String)

const TaskService = preload("res://scripts/task_service.gd")

var _task_id := ""


func configure(task: Dictionary, selected_task_id: String) -> void:
	_task_id = String(task.get("id", ""))
	var progress: Dictionary = task.get("progress", {})
	var goal := maxi(1, int(task.get("goal", progress.get("goal", 1))))
	var count := maxi(0, int(progress.get("count", 0)))
	var status_text := "%d/%d" % [count, goal]
	if task.get("objectives", []) is Array and not (task.get("objectives", []) as Array).is_empty():
		status_text = "%d/%d 项" % [count, (task.get("objectives", []) as Array).size()]
	if String(task.get("status", "")) == "candidate":
		status_text = "可选择"
	if String(task.get("status", "")) == "completed":
		if String(task.get("claim_status", "")) == "claimable":
			status_text = "可领取"
		else:
			status_text = "已生效" if TaskService.format_claimable_reward(task.get("reward", {})).is_empty() else "已领取"
	var progress_text := String(task.get("progress_detail", task.get("progress_text", "")))
	var type_label := _type_label(String(task.get("type", "")))
	var best_tier := String(progress.get("best_tier", ""))
	if not best_tier.is_empty():
		status_text = "%s｜%s" % [best_tier.capitalize(), status_text]
	text = "%s｜Lv.%d  %s\n%s  %s" % [
		type_label,
		int(task.get("level", 0)),
		String(task.get("title", _task_id)),
		progress_text,
		status_text
	]
	tooltip_text = String(task.get("description", ""))
	button_pressed = _task_id == selected_task_id


func _type_label(task_type: String) -> String:
	match task_type:
		"tutorial": return "教学"
		"growth": return "成长"
		"upgrade": return "升级"
		"contract": return "合同"
		"daily": return "日常"
		"feature": return "自动化"
	return "任务"


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func _on_pressed() -> void:
	task_selected.emit(_task_id)
