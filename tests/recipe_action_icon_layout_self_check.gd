extends SceneTree

const QUEUE_ROW_SCENE_PATH := "res://scenes/ui/pages/production_queue_recipe_row.tscn"
const WORKBENCH_SCENE_PATH := "res://scenes/ui/pages/production_workbench.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("RECIPE_ACTION_ICON_LAYOUT_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _run() -> void:
	var queue_row := (load(QUEUE_ROW_SCENE_PATH) as PackedScene).instantiate()
	var queue_icon := queue_row.get_node_or_null("Content/ProductIconButton") as Button
	var progress_fill := queue_row.get_node_or_null("ProgressFill") as ColorRect
	_expect(queue_icon != null, "queue row should declare its recipe icon")
	if queue_icon != null:
		_expect(queue_icon.custom_minimum_size == Vector2(68, 68), "queue recipe icon should match the approved 68px row height")
		_expect(queue_icon.has_method("configure_drag"), "queue recipe icon should preserve completed-stock dragging")
	_expect(progress_fill != null, "queue row should declare one full-row progress fill")
	_expect(queue_row.get_node_or_null("Content/BatchSlots") == null, "queue row should not retain per-batch slots")
	queue_row.free()

	var workbench := (load(WORKBENCH_SCENE_PATH) as PackedScene).instantiate()
	_expect(workbench.get_node_or_null("ProductionQueueHeader/SearchField") is LineEdit, "workbench should declare header search")
	_expect(workbench.get_node_or_null("ProductionQueueHeader/BulkActionButton") is MenuButton, "workbench should declare one bulk action menu")
	_expect(workbench.get_node_or_null("RecipeEntryBar") == null, "workbench should remove the old recipe-entry footer")
	workbench.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
