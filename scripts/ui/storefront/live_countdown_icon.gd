class_name LiveCountdownIcon
extends Control

const TOOLTIP_MIN_WIDTH := 156.0

var _live_tooltip_label: Label


func set_remaining_seconds(remaining_seconds: float) -> void:
	var next_text := "经营倒计时：%.1f 秒" % maxf(0.0, remaining_seconds)
	tooltip_text = next_text
	if is_instance_valid(_live_tooltip_label):
		_live_tooltip_label.text = next_text


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty():
		return null
	var label := Label.new()
	label.custom_minimum_size.x = TOOLTIP_MIN_WIDTH
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = &"TooltipLabel"
	label.text = tooltip_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_live_tooltip_label = label
	return label
