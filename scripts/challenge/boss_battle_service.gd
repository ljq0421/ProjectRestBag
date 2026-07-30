class_name BossBattleService
extends RefCounted


func create_state(snapshot: Dictionary, encounter: Dictionary, seed: int) -> Dictionary:
	var snapshot_copy := snapshot.duplicate(true)
	var encounter_copy := encounter.duplicate(true)
	var normalized_instances: Array = snapshot_copy.get("instances", [])
	for index in normalized_instances.size():
		if not normalized_instances[index] is Dictionary:
			continue
		var normalized_instance: Dictionary = normalized_instances[index]
		normalized_instance["tags"] = _sorted_tags(normalized_instance.get("tags", []))
		normalized_instances[index] = normalized_instance
	snapshot_copy["instances"] = normalized_instances
	var relation_bonus_by_instance := {}
	var relation_upgrade_sources_by_instance := {}
	for relation_value in snapshot_copy.get("relations", []):
		if not relation_value is Dictionary:
			continue
		var relation: Dictionary = relation_value
		var bonus_pct := int(relation.get("bonus_pct", encounter_copy.get("relation_bonus_pct", 0)))
		for key in ["left_instance_id", "right_instance_id"]:
			var instance_id := String(relation.get(key, ""))
			if instance_id.is_empty():
				continue
			relation_bonus_by_instance[instance_id] = maxi(
				int(relation_bonus_by_instance.get(instance_id, 0)),
				bonus_pct
			)
			relation_upgrade_sources_by_instance[instance_id] = _merged_tags(
				relation_upgrade_sources_by_instance.get(instance_id, []),
				relation.get("upgrade_source_ids", [])
			)

	var item_states := {}
	for instance_value in snapshot_copy.get("instances", []):
		if not instance_value is Dictionary:
			continue
		var instance: Dictionary = instance_value
		var instance_id := String(instance.get("instance_id", ""))
		var cycle_ms := int(instance.get("cycle_ms", 0))
		item_states[instance_id] = {
			"instance_id": instance_id,
			"recipe_id": String(instance.get("recipe_id", "")),
			"next_sale_ms": cycle_ms,
			"remaining_stock": int(instance.get("virtual_stock", 0)),
			"sales_count": 0,
			"satisfaction": 0,
			"cycle_ms": cycle_ms,
			"base_satisfaction": int(instance.get("base_satisfaction", 0)),
			"relation_bonus_pct": int(relation_bonus_by_instance.get(instance_id, 0)),
			"tags": _sorted_tags(instance.get("tags", [])),
			"upgrade_source_ids": _sorted_tags(instance.get("upgrade_source_ids", [])),
			"relation_upgrade_source_ids": _sorted_tags(
				relation_upgrade_sources_by_instance.get(instance_id, [])
			)
		}

	var effective_rules: Dictionary = snapshot_copy.get("effective_rules", {})
	return {
		"phase": "running",
		"elapsed_ms": 0,
		"pickiness": maxi(0, int(encounter_copy.get("initial_pickiness", 0))),
		"reputation": maxi(0, int(encounter_copy.get("initial_reputation", 0))),
		"item_states": item_states,
		"resolved_windows": {},
		"events": [],
		"outcome": "",
		"sales_count": 0,
		"total_satisfaction": 0,
		"next_event_seq": 0,
		"seed": seed,
		"first_window_guard_remaining": int(effective_rules.get("first_window_guard", 0)),
		"first_window_guard_source_ids": _sorted_tags(
			effective_rules.get("first_window_guard_source_ids", [])
		),
		"_snapshot": snapshot_copy,
		"_encounter": encounter_copy
	}


func advance(state: Dictionary, target_elapsed_ms: int) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	next_state.erase("error")
	var current_elapsed := int(next_state.get("elapsed_ms", 0))
	if target_elapsed_ms < current_elapsed:
		next_state["error"] = "cannot_move_backward"
		return next_state
	if String(next_state.get("phase", "")) != "running":
		return next_state

	var encounter: Dictionary = next_state.get("_encounter", {})
	var duration_ms := int(encounter.get("duration_ms", 0))
	var target_ms := mini(target_elapsed_ms, duration_ms)
	while String(next_state.get("phase", "")) == "running" and int(next_state.get("elapsed_ms", 0)) < target_ms:
		var event_time := _next_event_time(next_state, target_ms)
		if event_time < 0:
			next_state["elapsed_ms"] = target_ms
			break
		next_state["elapsed_ms"] = event_time
		_resolve_sales(next_state, event_time)
		if int(next_state.get("pickiness", 0)) <= 0:
			_finish_battle(next_state, "victory")
			break
		_resolve_demand_windows(next_state, event_time)
		if int(next_state.get("reputation", 0)) <= 0:
			_finish_battle(next_state, "loss_reputation")
			break
		if event_time >= duration_ms:
			_finish_battle(next_state, "loss_timeout")
			break

	if String(next_state.get("phase", "")) == "running" and int(next_state.get("elapsed_ms", 0)) < target_ms:
		next_state["elapsed_ms"] = target_ms
	return next_state


func simulate(snapshot: Dictionary, encounter: Dictionary, seed: int) -> Dictionary:
	return advance(create_state(snapshot, encounter, seed), int(encounter.get("duration_ms", 0)))


func next_window_progress(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {}
	var encounter: Dictionary = state.get("_encounter", {})
	var resolved_windows: Dictionary = state.get("resolved_windows", {})
	var elapsed_ms := int(state.get("elapsed_ms", 0))
	for window_value in encounter.get("windows", []):
		if not window_value is Dictionary:
			continue
		var window: Dictionary = window_value
		if resolved_windows.has(String(window.get("id", ""))):
			continue
		var progress := window.duplicate(true)
		progress["actual"] = _window_metric_at(
			state,
			window,
			mini(elapsed_ms, int(window.get("at_ms", elapsed_ms)))
		)
		progress["remaining"] = maxi(
			0,
			int(window.get("target", 0)) - int(progress.get("actual", 0))
		)
		return progress
	return {}


func _next_event_time(state: Dictionary, target_ms: int) -> int:
	var elapsed_ms := int(state.get("elapsed_ms", 0))
	var candidate := target_ms + 1
	var found := false
	var item_states: Dictionary = state.get("item_states", {})
	for instance_id in item_states:
		var item: Dictionary = item_states[instance_id]
		if int(item.get("remaining_stock", 0)) <= 0:
			continue
		var next_sale_ms := int(item.get("next_sale_ms", -1))
		if next_sale_ms > elapsed_ms and next_sale_ms <= target_ms:
			candidate = mini(candidate, next_sale_ms)
			found = true

	var encounter: Dictionary = state.get("_encounter", {})
	var resolved_windows: Dictionary = state.get("resolved_windows", {})
	for window_value in encounter.get("windows", []):
		if not window_value is Dictionary:
			continue
		var window: Dictionary = window_value
		var window_id := String(window.get("id", ""))
		var at_ms := int(window.get("at_ms", -1))
		if not resolved_windows.has(window_id) and at_ms > elapsed_ms and at_ms <= target_ms:
			candidate = mini(candidate, at_ms)
			found = true

	var duration_ms := int(encounter.get("duration_ms", 0))
	if duration_ms > elapsed_ms and duration_ms <= target_ms:
		candidate = mini(candidate, duration_ms)
		found = true
	return candidate if found else -1


func _resolve_sales(state: Dictionary, event_time: int) -> void:
	var item_states: Dictionary = state.get("item_states", {})
	var due_instance_ids: Array[String] = []
	for instance_id_variant in item_states:
		var instance_id := String(instance_id_variant)
		var item: Dictionary = item_states[instance_id_variant]
		if int(item.get("remaining_stock", 0)) > 0 and int(item.get("next_sale_ms", -1)) == event_time:
			due_instance_ids.append(instance_id)
	due_instance_ids.sort()

	var relation_events: Array[Dictionary] = []
	var pickiness_after_sales := int(state.get("pickiness", 0))
	for instance_id in due_instance_ids:
		var item: Dictionary = item_states[instance_id]
		var base_satisfaction := int(item.get("base_satisfaction", 0))
		var relation_bonus_pct := int(item.get("relation_bonus_pct", 0))
		var relation_bonus := base_satisfaction * relation_bonus_pct / 100
		var final_satisfaction := base_satisfaction + relation_bonus
		var pickiness_before := pickiness_after_sales
		var pickiness_reduction := mini(final_satisfaction, pickiness_before)
		pickiness_after_sales = maxi(0, pickiness_before - pickiness_reduction)
		item["remaining_stock"] = int(item.get("remaining_stock", 0)) - 1
		item["sales_count"] = int(item.get("sales_count", 0)) + 1
		item["satisfaction"] = int(item.get("satisfaction", 0)) + final_satisfaction
		if int(item.get("remaining_stock", 0)) > 0:
			item["next_sale_ms"] = event_time + int(item.get("cycle_ms", 0))
		else:
			item["next_sale_ms"] = -1
		item_states[instance_id] = item
		state["sales_count"] = int(state.get("sales_count", 0)) + 1
		state["total_satisfaction"] = int(state.get("total_satisfaction", 0)) + final_satisfaction
		_append_event(state, {
			"at_ms": event_time,
			"type": "sale",
			"source_id": instance_id,
			"recipe_id": String(item.get("recipe_id", "")),
			"tags": _sorted_tags(item.get("tags", [])),
			"base_satisfaction": base_satisfaction,
			"relation_bonus": relation_bonus,
			"final_satisfaction": final_satisfaction,
			"pickiness_before": pickiness_before,
			"pickiness_reduction": pickiness_reduction,
			"pickiness_after": pickiness_after_sales,
			"upgrade_source_ids": _merged_tags(
				item.get("upgrade_source_ids", []),
				item.get("relation_upgrade_source_ids", [])
			)
		})
		if relation_bonus > 0:
			relation_events.append({
				"at_ms": event_time,
				"type": "relation_trigger",
				"source_id": instance_id,
				"bonus_pct": relation_bonus_pct,
				"bonus_satisfaction": relation_bonus,
				"upgrade_source_ids": _sorted_tags(
					item.get("relation_upgrade_source_ids", [])
				)
			})

	for relation_event in relation_events:
		_append_event(state, relation_event)
	state["item_states"] = item_states
	state["pickiness"] = pickiness_after_sales


func _resolve_demand_windows(state: Dictionary, event_time: int) -> void:
	var encounter: Dictionary = state.get("_encounter", {})
	var resolved_windows: Dictionary = state.get("resolved_windows", {})
	for window_value in encounter.get("windows", []):
		if not window_value is Dictionary:
			continue
		var window: Dictionary = window_value
		var window_id := String(window.get("id", ""))
		if resolved_windows.has(window_id) or int(window.get("at_ms", -1)) != event_time:
			continue
		var actual := _window_metric(state, window)
		var target := int(window.get("target", 0))
		var passed := actual >= target
		var base_reputation_damage := 0 if passed else int(window.get("reputation_damage", 0))
		var guard_absorbed := 0
		var guard_source_ids: Array[String] = []
		if resolved_windows.is_empty():
			var guard_remaining := int(state.get("first_window_guard_remaining", 0))
			guard_absorbed = mini(base_reputation_damage, guard_remaining)
			state["first_window_guard_remaining"] = 0
			if guard_absorbed > 0:
				guard_source_ids = _sorted_tags(
					state.get("first_window_guard_source_ids", [])
				)
		var reputation_damage := maxi(0, base_reputation_damage - guard_absorbed)
		state["reputation"] = maxi(0, int(state.get("reputation", 0)) - reputation_damage)
		var demand_event := {
			"at_ms": event_time,
			"type": "demand_window",
			"window_id": window_id,
			"metric": String(window.get("metric", "")),
			"actual": actual,
			"target": target,
			"passed": passed,
			"base_reputation_damage": base_reputation_damage,
			"guard_absorbed": guard_absorbed,
			"reputation_damage": reputation_damage,
			"reputation_after": int(state.get("reputation", 0)),
			"upgrade_source_ids": guard_source_ids
		}
		_append_event(state, demand_event)
		resolved_windows[window_id] = demand_event.duplicate(true)
	state["resolved_windows"] = resolved_windows


func _window_metric(state: Dictionary, window: Dictionary) -> int:
	return _window_metric_at(state, window, int(window.get("at_ms", 0)))


func _window_metric_at(state: Dictionary, window: Dictionary, to_ms: int) -> int:
	match String(window.get("metric", "")):
		"sales_count":
			return int(state.get("sales_count", 0))
		"active_relation_count":
			var snapshot: Dictionary = state.get("_snapshot", {})
			return (snapshot.get("relations", []) as Array).size()
		"window_satisfaction":
			var from_ms := int(window.get("from_ms", 0))
			return _sale_satisfaction_in_range(state.get("events", []), from_ms, to_ms)
		"tag_sales_count":
			return _tag_sales_count(
				state.get("events", []),
				String(window.get("tag", "")),
				to_ms
			)
		"tag_satisfaction":
			return _tag_satisfaction(
				state.get("events", []),
				String(window.get("tag", "")),
				int(window.get("from_ms", 0)),
				to_ms
			)
		"distinct_tag_count":
			return _distinct_tag_count(
				state.get("events", []),
				_window_target_tags(window),
				to_ms
			)
	return 0


func _sale_satisfaction_in_range(events: Array, from_ms: int, to_ms: int) -> int:
	var total := 0
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var at_ms := int(event.get("at_ms", -1))
		if event.get("type") == "sale" and from_ms < at_ms and at_ms <= to_ms:
			total += int(event.get("final_satisfaction", 0))
	return total


func _tag_sales_count(events: Array, tag: String, to_ms: int) -> int:
	if tag.is_empty():
		return 0
	var count := 0
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		if (
			event.get("type") == "sale"
			and int(event.get("at_ms", -1)) <= to_ms
			and _event_has_tag(event, tag)
		):
			count += 1
	return count


func _tag_satisfaction(events: Array, tag: String, from_ms: int, to_ms: int) -> int:
	if tag.is_empty():
		return 0
	var total := 0
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var at_ms := int(event.get("at_ms", -1))
		if (
			event.get("type") == "sale"
			and from_ms < at_ms
			and at_ms <= to_ms
			and _event_has_tag(event, tag)
		):
			total += int(event.get("final_satisfaction", 0))
	return total


func _distinct_tag_count(events: Array, target_tags: Array[String], to_ms: int) -> int:
	var sold_tags := {}
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		if event.get("type") != "sale" or int(event.get("at_ms", -1)) > to_ms:
			continue
		for tag in _sorted_tags(event.get("tags", [])):
			if target_tags.is_empty() or target_tags.has(tag):
				sold_tags[tag] = true
	return sold_tags.size()


func _window_target_tags(window: Dictionary) -> Array[String]:
	if window.has("target_tags"):
		return _sorted_tags(window.get("target_tags", []))
	if window.has("tags"):
		return _sorted_tags(window.get("tags", []))
	var tag := String(window.get("tag", ""))
	return [] if tag.is_empty() else [tag]


func _event_has_tag(event: Dictionary, tag: String) -> bool:
	return _sorted_tags(event.get("tags", [])).has(tag)


func _sorted_tags(tags_value: Variant) -> Array[String]:
	var tags: Array[String] = []
	if not tags_value is Array:
		return tags
	for tag_value in tags_value:
		var tag := String(tag_value)
		if tag.is_empty() or tags.has(tag):
			continue
		tags.append(tag)
	tags.sort()
	return tags


func _finish_battle(state: Dictionary, outcome: String) -> void:
	if String(state.get("phase", "")) == "finished":
		return
	state["phase"] = "finished"
	state["outcome"] = outcome
	_append_event(state, {
		"at_ms": int(state.get("elapsed_ms", 0)),
		"type": "battle_end",
		"outcome": outcome,
		"pickiness_after": int(state.get("pickiness", 0)),
		"reputation_after": int(state.get("reputation", 0))
	})


func _append_event(state: Dictionary, event: Dictionary) -> void:
	var events: Array = state.get("events", [])
	var stored_event := event.duplicate(true)
	stored_event["seq"] = int(state.get("next_event_seq", 0))
	state["next_event_seq"] = int(state.get("next_event_seq", 0)) + 1
	events.append(stored_event)
	state["events"] = events


func _merged_tags(left_values: Variant, right_values: Variant) -> Array[String]:
	var result := _sorted_tags(left_values)
	for value in _sorted_tags(right_values):
		if not result.has(value):
			result.append(value)
	result.sort()
	return result
