class_name ShowcasePropDragButton
extends Button

@export var prop_id := ""
@export var prop_label := "陈列道具"
@export var shape_cells: Array[Vector2i] = [Vector2i(0, 0)]


func configure_available(available: bool, unlock_level: int, effect_text: String, status_text: String = "") -> void:
	disabled = not available
	var resolved_status := status_text
	if resolved_status.is_empty():
		resolved_status = "可放置" if available else "Lv.%d" % unlock_level
	text = "%s｜%s｜%s" % [prop_label, effect_text, resolved_status]
	var action_text := "拖到橱窗空格放置"
	if resolved_status == "营业中锁定":
		action_text = "营业开始后道具布局已锁定"
	elif resolved_status.begins_with("Lv."):
		action_text = "Lv.%d 阶段奖励解锁" % unlock_level
	elif resolved_status == "已放置":
		action_text = "可拖到新的橱窗空格重新放置"
	tooltip_text = "%s\n%s\n%s" % [
		action_text,
		effect_text,
		"营业开始后道具布局锁定"
	]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled or prop_id.is_empty():
		return null
	var preview := PanelContainer.new()
	preview.theme_type_variation = &"DessertDragPreviewPanel"
	var label := Label.new()
	label.text = "%s\n占格 %d" % [prop_label, shape_cells.size()]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_child(label)
	set_drag_preview(preview)
	return {
		"kind": "showcase_prop",
		"prop_id": prop_id,
		"shape_cells": shape_cells.duplicate()
	}
