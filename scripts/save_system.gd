class_name SaveSystem
extends RefCounted

const GameStateScript = preload("res://scripts/game_state.gd")
const Catalog = preload("res://scripts/catalog.gd")
const ProductionSite = preload("res://scripts/production_site.gd")
const AutomationService = preload("res://scripts/automation_service.gd")

const SAVE_PATH := "user://project_rest_new_save.json"
const BROKEN_SAVE_PATH := "user://project_rest_new_save.broken.json"


static func save_game(state, path: String = SAVE_PATH, now_unix: int = -1) -> bool:
	if state == null or not state.has_method("to_dict"):
		return false

	var save_data: Dictionary = state.to_dict()
	var actual_now_unix := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var should_sync_last_saved := _has_property(state, "last_saved_at_unix")
	if should_sync_last_saved:
		save_data["last_saved_at_unix"] = actual_now_unix

	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open temp save file for writing: %s" % temp_path)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	var saved := _replace_file_with_temp(temp_path, path)
	if saved and should_sync_last_saved:
		state.last_saved_at_unix = actual_now_unix
	return saved


static func load_game(path: String = SAVE_PATH, broken_path: String = "", now_unix: int = -1, automation_event_limit_override: int = -1):
	var actual_broken_path := _resolve_broken_path(path, broken_path)
	var actual_now_unix := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	if not FileAccess.file_exists(path):
		return GameStateScript.new_game()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file for reading: %s" % path)
		return GameStateScript.new_game()

	var raw_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_error: int = json.parse(raw_text)
	if parse_error != OK or not json.data is Dictionary:
		_backup_broken_save(raw_text, actual_broken_path)
		return GameStateScript.new_game()

	var original_data: Dictionary = (json.data as Dictionary).duplicate(true)
	var state = GameStateScript.from_dict(original_data)
	var unread_displaying_report: Dictionary = {}
	if bool(state.pending_automation_report.get("ui_displaying", false)):
		unread_displaying_report = state.pending_automation_report.duplicate(true)
	var previous_automation_unix := int(state.automation_last_settled_unix)
	apply_offline_recipe_production(state, actual_now_unix)
	var automation_report: Dictionary = apply_offline_automation(state, actual_now_unix, automation_event_limit_override)
	_apply_offline_ready_state(state, actual_now_unix)
	_enqueue_automation_report_notification(state, automation_report, previous_automation_unix, actual_now_unix)
	if not unread_displaying_report.is_empty():
		state.pending_automation_report = unread_displaying_report
	if not save_game(state, path, actual_now_unix):
		var rollback_state = GameStateScript.from_dict(original_data)
		rollback_state.pending_automation_report = (original_data.get("pending_automation_report", {}) as Dictionary).duplicate(true) if original_data.get("pending_automation_report", {}) is Dictionary else {}
		rollback_state.add_log("offline_automation_save_failed")
		return rollback_state
	return state


static func apply_offline_recipe_production(state, now_unix: int) -> Dictionary:
	if state == null or not state.has_method("complete_ready_manual_recipe_productions"):
		return {
			"completed_batches": 0,
			"product_outputs": {},
			"completed_processes": 0,
			"ingredient_outputs": {}
		}
	var report: Dictionary = state.complete_ready_manual_recipe_productions(now_unix)
	var process_report: Dictionary = {}
	if state.has_method("complete_ready_ingredient_processes"):
		process_report = state.complete_ready_ingredient_processes(now_unix)
	report["completed_processes"] = int(process_report.get("completed_processes", 0))
	report["ingredient_outputs"] = (
		process_report.get("ingredient_outputs", {}) as Dictionary
	).duplicate(true) if process_report.get("ingredient_outputs", {}) is Dictionary else {}
	report["completed_process_slots"] = (
		process_report.get("completed_process_slots", []) as Array
	).duplicate(true) if process_report.get("completed_process_slots", []) is Array else []
	var completed_batches := int(report.get("completed_batches", 0))
	var completed_processes := int(report.get("completed_processes", 0))
	if completed_batches <= 0 and completed_processes <= 0:
		return report
	var completed_text := _recipe_production_output_text(report.get("product_outputs", {}))
	var processed_text := _ingredient_processing_output_text(report.get("ingredient_outputs", {}))
	var body_parts: Array[String] = []
	if completed_batches > 0:
		body_parts.append(
			"完成 %d 批商品%s" % [
				completed_batches,
				"：%s" % completed_text if not completed_text.is_empty() else ""
			]
		)
	if completed_processes > 0:
		body_parts.append(
			"完成 %d 项加工%s" % [
				completed_processes,
				"：%s" % processed_text if not processed_text.is_empty() else ""
			]
		)
	var body := "离线期间%s，产物已自动入库。" % "；".join(body_parts)
	state.enqueue_notification(
		"制作完成",
		body,
		{
			"kind": "recipe_production_report",
			"report": report.duplicate(true)
		}
	)
	return report


static func _ingredient_processing_output_text(ingredient_outputs_value: Variant) -> String:
	if not ingredient_outputs_value is Dictionary:
		return ""
	var ingredient_outputs: Dictionary = ingredient_outputs_value
	var ingredient_ids: Array = ingredient_outputs.keys()
	ingredient_ids.sort()
	var ingredients: Dictionary = Catalog.new().get_ingredients()
	var parts: Array[String] = []
	for ingredient_id_value: Variant in ingredient_ids:
		var ingredient_id := String(ingredient_id_value)
		var amount := maxi(0, int(ingredient_outputs.get(ingredient_id_value, 0)))
		if amount <= 0:
			continue
		var ingredient: Dictionary = ingredients.get(ingredient_id, {})
		parts.append("%s x%d" % [String(ingredient.get("name", ingredient_id)), amount])
		if parts.size() >= 3:
			break
	return "、".join(parts)


static func _recipe_production_output_text(product_outputs_value: Variant) -> String:
	if not product_outputs_value is Dictionary:
		return ""
	var product_outputs: Dictionary = product_outputs_value
	var recipe_ids: Array = product_outputs.keys()
	recipe_ids.sort()
	var recipes: Dictionary = Catalog.new().get_recipes()
	var parts: Array[String] = []
	for recipe_id_value: Variant in recipe_ids:
		var recipe_id := String(recipe_id_value)
		var amount := maxi(0, int(product_outputs.get(recipe_id_value, 0)))
		if amount <= 0:
			continue
		var recipe: Dictionary = recipes.get(recipe_id, {})
		parts.append("%s x%d" % [String(recipe.get("name", recipe_id)), amount])
		if parts.size() >= 3:
			break
	return "、".join(parts)


static func _enqueue_automation_report_notification(state, report: Dictionary, previous_unix: int, now_unix: int) -> void:
	if state == null or previous_unix <= 0 or now_unix == previous_unix:
		return
	var pauses: Array = report.get("pauses", []) if report.get("pauses", []) is Array else []
	var paused_slots: Array = report.get("paused_slots", []) if report.get("paused_slots", []) is Array else []
	var meaningful := int(report.get("event_count", 0)) > 0 or not pauses.is_empty() or not paused_slots.is_empty() or bool(report.get("event_limit_reached", false)) or bool(report.get("truncated", false))
	if not meaningful:
		return
	var report_id := "%d:%d" % [int(report.get("from_unix", previous_unix)), int(report.get("to_unix", now_unix))]
	for notification_value: Variant in state.pending_notifications:
		if not notification_value is Dictionary:
			continue
		var metadata: Dictionary = (notification_value as Dictionary).get("metadata", {}) if (notification_value as Dictionary).get("metadata", {}) is Dictionary else {}
		if String(metadata.get("kind", "")) == "automation_report" and String(metadata.get("report_id", "")) == report_id:
			return
	state.enqueue_notification("自动化交班简报", "离线托管已有新结果，请查看并处理暂停项目。", {
		"kind": "automation_report",
		"report_id": report_id,
		"report": report.duplicate(true)
	})


static func apply_offline_automation(state, now_unix: int, event_limit_override: int = -1) -> Dictionary:
	if state == null:
		return {}

	var previous_unix := int(state.automation_last_settled_unix)
	if previous_unix <= 0:
		var baseline_report := _new_offline_report(now_unix, now_unix)
		state.automation_last_settled_unix = maxi(0, now_unix)
		state.automation_resume_floor_unix = maxi(int(state.automation_resume_floor_unix), maxi(0, now_unix))
		state.pending_automation_report = baseline_report.duplicate(true)
		return baseline_report

	if now_unix < previous_unix:
		var rollback_report := _new_offline_report(previous_unix, now_unix)
		rollback_report["pauses"] = [{
			"reason": {
				"code": "clock_rollback",
				"first_stopped_at_unix": now_unix
			}
		}]
		state.pending_automation_report = rollback_report.duplicate(true)
		return rollback_report

	if now_unix == previous_unix:
		return state.pending_automation_report.duplicate(true)

	var offline_limit_seconds := AutomationService.offline_seconds_limit(state)
	var report := AutomationService.settle(state, previous_unix, now_unix, offline_limit_seconds, event_limit_override)
	var was_truncated := int(report.get("to_unix", now_unix)) < now_unix or bool(report.get("event_limit_reached", false))
	report["truncated"] = was_truncated
	report["requested_to_unix"] = now_unix
	if was_truncated:
		_reanchor_truncated_automation(state, now_unix)
		state.automation_resume_floor_unix = maxi(int(state.automation_resume_floor_unix), now_unix)
	state.automation_last_settled_unix = now_unix
	state.pending_automation_report = report.duplicate(true)
	return report


static func _reanchor_truncated_automation(state, now_unix: int) -> void:
	for index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[index]
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		var site_id := String(slot.get("site_id", ""))
		if not state.is_output_site_managed(site_id):
			continue
		var ready_at_unix := int(slot.get("ready_at_unix", 0))
		if ready_at_unix <= 0 or ready_at_unix > now_unix or bool(slot.get("automation_paused", false)):
			continue
		var duration_seconds := maxi(1, int(slot.get("duration_seconds", 1)))
		slot["started_at_unix"] = now_unix
		slot["ready_at_unix"] = now_unix + duration_seconds
		slot["ready"] = false
		state.production_slots[index] = slot



static func _new_offline_report(from_unix: int, to_unix: int) -> Dictionary:
	return {
		"from_unix": from_unix,
		"to_unix": to_unix,
		"event_count": 0,
		"output_cycle_count": 0,
		"kitchen_cycle_count": 0,
		"outputs": {},
		"product_outputs": {},
		"paused_slots": [],
		"pauses": [],
		"event_limit_reached": false
	}


static func _apply_offline_ready_state(state, now_unix: int) -> void:
	if state == null:
		return

	ProductionSite.evaluate_slots(state, now_unix)

	if not _has_property(state, "last_saved_at_unix"):
		return

	var last_saved_at_unix := int(state.last_saved_at_unix)
	var has_offline_interval := last_saved_at_unix > 0 and now_unix > last_saved_at_unix
	var newly_ready_count := _offline_ready_slot_count(state, last_saved_at_unix, now_unix) if has_offline_interval else 0
	var had_pending_prompt := int(state.offline_ready_count) > 0
	var ready_count := _unmanaged_ready_slot_count(state, now_unix) if had_pending_prompt or newly_ready_count > 0 else 0
	var should_prompt := newly_ready_count > 0
	if has_offline_interval and _has_property(state, "offline_ready_count"):
		state.offline_ready_count = ready_count

	if should_prompt:
		var message := "offline_ready:%d" % ready_count
		if state.has_method("add_log") and not _log_contains_exact(state, message):
			state.add_log(message)


static func _offline_ready_slot_count(state, last_saved_at_unix: int, now_unix: int) -> int:
	if state == null:
		return 0

	var count := 0
	for index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[index]
		if not slot_value is Dictionary:
			continue

		var slot: Dictionary = slot_value
		var site_id := String(slot.get("site_id", ""))
		if state.is_output_site_managed(site_id):
			continue
		if not ProductionSite.is_slot_ready(state, index, now_unix):
			continue
		var ready_at_unix := int(slot.get("ready_at_unix", 0))
		if ready_at_unix > last_saved_at_unix and ready_at_unix <= now_unix:
			count += 1
	return count


static func _unmanaged_ready_slot_count(state, now_unix: int) -> int:
	if state == null:
		return 0

	var count := 0
	for index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[index]
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		var site_id := String(slot.get("site_id", ""))
		if state.is_output_site_managed(site_id):
			continue
		if ProductionSite.is_slot_ready(state, index, now_unix):
			count += 1
	return count


static func _has_property(value, property_name: String) -> bool:
	if value == null or not value.has_method("get_property_list"):
		return false

	for property: Dictionary in value.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


static func _log_contains_exact(state, message: String) -> bool:
	if state == null or not state.has_method("to_dict"):
		return false

	var data: Dictionary = state.to_dict()
	var log_value: Variant = data.get("feedback_log", [])
	if not log_value is Array:
		return false

	var log_entries: Array = log_value as Array
	for entry: Variant in log_entries:
		if String(entry) == message:
			return true
	return false


static func _replace_file_with_temp(temp_path: String, target_path: String) -> bool:
	var temp_abs := ProjectSettings.globalize_path(temp_path)
	var target_abs := ProjectSettings.globalize_path(target_path)
	var backup_abs := ProjectSettings.globalize_path(target_path + ".previous")

	if FileAccess.file_exists(target_path + ".previous"):
		var remove_old_backup_err := DirAccess.remove_absolute(backup_abs)
		if remove_old_backup_err != OK:
			push_warning("Could not remove old save backup: %s" % (target_path + ".previous"))
			return false

	var had_target := FileAccess.file_exists(target_path)
	if had_target:
		var backup_err := DirAccess.rename_absolute(target_abs, backup_abs)
		if backup_err != OK:
			push_warning("Could not move existing save before replace: %s" % target_path)
			DirAccess.remove_absolute(temp_abs)
			return false

	var rename_err := DirAccess.rename_absolute(temp_abs, target_abs)
	if rename_err == OK:
		if had_target:
			DirAccess.remove_absolute(backup_abs)
		return true

	push_warning("Could not replace save file: %s" % target_path)
	if had_target:
		DirAccess.rename_absolute(backup_abs, target_abs)
	DirAccess.remove_absolute(temp_abs)
	return false


static func _resolve_broken_path(path: String, broken_path: String) -> String:
	if not broken_path.is_empty():
		return broken_path
	if path == SAVE_PATH:
		return BROKEN_SAVE_PATH
	return path + ".broken.json"


static func _backup_broken_save(raw_text: String, broken_path: String) -> void:
	var backup := FileAccess.open(broken_path, FileAccess.WRITE)
	if backup == null:
		push_warning("Could not back up broken save file: %s" % broken_path)
		return

	backup.store_string(raw_text)
	backup.close()
