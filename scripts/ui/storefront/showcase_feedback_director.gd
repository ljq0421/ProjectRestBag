class_name ShowcaseFeedbackDirector
extends RefCounted

const MAX_VISIBLE_EVENTS := 4
const COMBO_WINDOW_MSEC := 3000

var _pending: Array[Dictionary] = []
var _active_feedback_keys := {}
var _sequence := 0
var _combo_key := ""
var _combo_label := ""
var _combo_count := 0
var _combo_coins := 0
var _combo_deadline_msec := -1


func enqueue_sale(raw_event: Dictionary, now_msec: int) -> bool:
	if maxi(0, int(raw_event.get("earned_coins", 0))) <= 0:
		return false
	var event := _normalize_event(raw_event, now_msec)
	var key := String(event.get("combo_key", ""))
	if not key.is_empty() and key == _combo_key and now_msec <= _combo_deadline_msec:
		_combo_count += 1
		_combo_coins += int(event.get("earned_coins", 0))
	else:
		_combo_key = key
		_combo_label = String(event.get("combo_label", ""))
		_combo_count = 1
		_combo_coins = int(event.get("earned_coins", 0))
	_combo_deadline_msec = now_msec + COMBO_WINDOW_MSEC
	event["combo_count"] = _combo_count
	event["combo_coins"] = _combo_coins
	_pending.append(event)
	return true


func drain_visual_batch() -> Dictionary:
	var visible: Array[Dictionary] = []
	var available_slots := maxi(0, MAX_VISIBLE_EVENTS - _active_feedback_keys.size())
	while available_slots > 0 and not _pending.is_empty():
		var next_index := -1
		for pending_index in range(_pending.size()):
			var candidate: Dictionary = _pending[pending_index]
			if not _active_feedback_keys.has(String(candidate.get("feedback_key", ""))):
				next_index = pending_index
				break
		if next_index < 0:
			break
		var next_event: Dictionary = _pending[next_index]
		var feedback_key := String(next_event.get("feedback_key", ""))
		_pending.remove_at(next_index)
		visible.append(next_event.duplicate(true))
		_active_feedback_keys[feedback_key] = true
		available_slots -= 1
	return {
		"events": visible,
		"pending_count": _pending.size(),
		"active_count": _active_feedback_keys.size(),
		"combo_key": _combo_key,
		"combo_label": _combo_label,
		"combo_count": _combo_count,
		"combo_coins": _combo_coins
	}


func release_visual_slot(feedback_key: String) -> void:
	_active_feedback_keys.erase(feedback_key)


func pending_count() -> int:
	return _pending.size()


func active_count() -> int:
	return _active_feedback_keys.size()


func _normalize_event(raw_event: Dictionary, now_msec: int) -> Dictionary:
	var event := raw_event.duplicate(true)
	event["recipe_id"] = String(event.get("recipe_id", ""))
	event["anchor_slot"] = int(event.get("anchor_slot", -1))
	event["earned_coins"] = maxi(0, int(event.get("earned_coins", 0)))
	event["earned_reputation"] = maxi(0, int(event.get("earned_reputation", 0)))
	event["combo_key"] = String(event.get("combo_key", ""))
	event["combo_label"] = String(event.get("combo_label", ""))
	event["timestamp_msec"] = maxi(0, now_msec)
	var feedback_key := String(event.get("recipe_id", ""))
	if feedback_key.is_empty():
		feedback_key = String(event.get("event_id", ""))
	if feedback_key.is_empty():
		feedback_key = "anonymous_%d" % _sequence
	_sequence += 1
	event["feedback_key"] = feedback_key
	return event
