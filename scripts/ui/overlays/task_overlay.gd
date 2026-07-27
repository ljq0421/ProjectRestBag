extends VBoxContainer

signal close_requested()
signal task_rewards_claim_all_requested()

const TaskFilterButtonScene := preload("res://scenes/ui/overlays/task_filter_button.tscn")
const TaskEntryButtonScene := preload("res://scenes/ui/overlays/task_entry_button.tscn")
const TaskDetailContentScene := preload("res://scenes/ui/overlays/task_detail_content.tscn")

const TASK_FILTER_ORDER := ["current", "side"]
const TASK_FILTER_LABELS := {
	"current": "成长任务",
	"side": "支线任务"
}
var task_tabs: VBoxContainer
var task_list_panel: VBoxContainer
var task_detail_panel: VBoxContainer


func _ready() -> void:
	var claim_all_button := get_node_or_null("TaskRewardActions/TaskClaimAllRewardsButton") as Button
	if claim_all_button != null:
		claim_all_button.pressed.connect(_on_claim_all_rewards_pressed)


func _on_claim_all_rewards_pressed() -> void:
	task_rewards_claim_all_requested.emit()


func refresh(_state, _catalog) -> void:
	pass


func show_mode(_mode: String) -> void:
	visible = true


func hide_mode() -> void:
	visible = false


func refresh_panel(view, snapshot: Dictionary, selected_filter: String, selected_task_id: String) -> String:
	_bind_nodes()
	var claimable: Array = snapshot.get("claimable", [])
	_refresh_claim_actions(claimable.size())
	if not TASK_FILTER_ORDER.has(selected_filter):
		selected_filter = "current"
	_fill_filter_buttons(view, selected_filter)
	_clear_children(task_list_panel)
	_clear_children(task_detail_panel)
	var entries := _task_entries(snapshot, selected_filter)
	var next_selected_task_id := selected_task_id
	if next_selected_task_id.is_empty() and not entries.is_empty():
		next_selected_task_id = String((entries[0] as Dictionary).get("id", ""))
	for entry in entries:
		var button := TaskEntryButtonScene.instantiate()
		button.call("configure", entry, next_selected_task_id)
		button.connect("task_selected", Callable(view, "_on_task_overlay_button_pressed"))
		task_list_panel.add_child(button)
	var selected_entry := _entry_by_id(entries, next_selected_task_id)
	if selected_entry.is_empty() and not entries.is_empty():
		selected_entry = entries[0]
		next_selected_task_id = String(selected_entry.get("id", ""))
	var detail := TaskDetailContentScene.instantiate()
	var empty_text := String(snapshot.get("side_empty_text" if selected_filter == "side" else "current_empty_text", ""))
	detail.call("configure", view, selected_entry, empty_text)
	task_detail_panel.add_child(detail)
	return next_selected_task_id


func _fill_filter_buttons(view, selected_filter: String) -> void:
	_clear_children(task_tabs)
	for filter_id in TASK_FILTER_ORDER:
		var button := TaskFilterButtonScene.instantiate()
		button.call("configure", filter_id, String(TASK_FILTER_LABELS.get(filter_id, filter_id)), selected_filter)
		button.connect("filter_selected", Callable(view, "_on_task_filter_button_pressed"))
		task_tabs.add_child(button)


func _task_entries(snapshot: Dictionary, selected_filter: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var source_value: Variant = snapshot.get("side_entries" if selected_filter == "side" else "current_entries", [])
	if not source_value is Array:
		return entries
	for value: Variant in source_value:
		if not value is Dictionary:
			continue
		entries.append(value)
	return entries


func _entry_by_id(entries: Array[Dictionary], task_id: String) -> Dictionary:
	for entry in entries:
		if String(entry.get("id", "")) == task_id:
			return entry
	return {}


func _refresh_claim_actions(claimable_count: int) -> void:
	var button := get_node_or_null("TaskRewardActions/TaskClaimAllRewardsButton") as Button
	if button == null:
		return
	button.disabled = claimable_count <= 0
	button.text = "一键领取奖励（%d 项）" % claimable_count if claimable_count > 0 else "暂无可领取奖励"
	button.tooltip_text = "领取所有已完成任务的待领取奖励。" if claimable_count > 0 else "完成任务后可在此一键领取奖励。"


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _bind_nodes() -> void:
	if task_tabs != null:
		return
	task_tabs = $TaskBody/TaskTabs
	task_list_panel = $TaskBody/TaskListScroll/TaskListPanel
	task_detail_panel = $TaskBody/TaskDetailPanel
