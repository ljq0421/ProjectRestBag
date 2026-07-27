extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const GAME_STATE := preload("res://scripts/game_state.gd")
const CORE_FEATURE_UNLOCK_SERVICE := preload("res://scripts/core_feature_unlock_service.gd")
const TUTORIAL_PROGRESS := preload("res://scripts/tutorial_progress.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	main.set("save_path", OS.get_temp_dir().path_join("core_feature_lock_ui_self_check.json"))
	root.add_child(main)
	await process_frame
	await process_frame
	var state = GAME_STATE.new_game()
	main.set("state", state)
	main.call("_refresh_current_page")
	main.call("_refresh_showcase_round_controls")
	await process_frame

	var launcher := main.get_node("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher")
	var mapping := {
		"PurchaseButton": false,
		"OutputButton": true,
		"InventoryButton": true,
		"CatalogButton": true,
		"StorefrontManageButton": true,
		"TaskButton": true,
		"StarlightButton": true,
	}
	for button_name in mapping:
		var button := launcher.get_node(button_name) as Button
		_expect(button.visible, "%s should remain visible" % button_name)
		_expect(not button.disabled, "%s should remain clickable for lock reason" % button_name)
		_expect_equal("%s lock state" % button_name, bool(button.get_meta("access_locked", false)), bool(mapping[button_name]))
		var lock_badge := button.get_node_or_null("AccessLockBadge") as Label
		_expect(lock_badge != null and lock_badge.visible == bool(mapping[button_name]), "%s should render lock badge" % button_name)

	var output_button := launcher.get_node("OutputButton") as Button
	var mode_before_locked_click := String(main.get("global_popup_mode"))
	output_button.emit_signal("pressed")
	await process_frame
	_expect_equal("locked output does not open", String(main.get("global_popup_mode")), mode_before_locked_click)
	var status_label := main.get_node("Root/StatusBar/StatusLabel") as Label
	_expect(status_label.text.find("🔒") >= 0, "locked click should explain the reason")

	var research_button := main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ActionRow/ResearchActionButton") as Button
	_expect(bool(research_button.get_meta("access_locked", false)), "research action should show its lock")
	_expect(research_button.text.find("🔒") >= 0, "research action should render lock text")
	var rulebook_button := main.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/RulebookButton") as Button
	var business_button := main.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/StartRoundButton") as Button
	_expect(bool(rulebook_button.get_meta("access_locked", false)), "rulebook should show lock")
	_expect(bool(business_button.get_meta("access_locked", false)), "business should show lock")
	_expect(not rulebook_button.disabled and not business_button.disabled, "rulebook and business locks should remain clickable")

	state.unlock_core_feature(CORE_FEATURE_UNLOCK_SERVICE.OUTPUT)
	state.unlock_core_feature(CORE_FEATURE_UNLOCK_SERVICE.INVENTORY)
	main.call("_refresh_current_page")
	await process_frame
	_expect(not bool(output_button.get_meta("access_locked", true)), "successful prerequisite should remove output lock")
	output_button.emit_signal("pressed")
	await process_frame
	_expect_equal("unlocked output opens", String(main.get("global_popup_mode")), "output")

	for feature_id in [
		CORE_FEATURE_UNLOCK_SERVICE.RESEARCH,
		CORE_FEATURE_UNLOCK_SERVICE.CRAFT,
		CORE_FEATURE_UNLOCK_SERVICE.CATALOG,
		CORE_FEATURE_UNLOCK_SERVICE.LIST,
		CORE_FEATURE_UNLOCK_SERVICE.RULEBOOK,
		CORE_FEATURE_UNLOCK_SERVICE.ARRANGE,
		CORE_FEATURE_UNLOCK_SERVICE.BUSINESS,
	]:
		state.unlock_core_feature(feature_id)
	state.tutorial_guide_step = TUTORIAL_PROGRESS.STEP_BUSINESS
	state.add_recipe("rice_milk_drink")
	state.display_items = {
		"rice_milk_drink": {
			"cells": [Vector2i(5, 5)],
			"fresh_stock": 1,
			"carried_stock": 0,
			"stock": 1,
			"variant_id": "standard",
		}
	}
	main.call("_close_global_popup")
	main.call("_refresh_current_page")
	await process_frame
	var storefront_button := launcher.get_node("StorefrontManageButton") as Button
	_expect(bool(storefront_button.get_meta("access_locked", false)), "storefront management should still be locked before business starts")
	_expect(bool(main.call("_start_showcase_business_round")), "a valid tutorial business round should start")
	_expect(not bool(storefront_button.get_meta("access_locked", true)), "business start should immediately refresh the storefront-management unlock")

	main.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	_expect(actual == expected, "%s expected %s, got %s" % [label, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("CORE_FEATURE_LOCK_UI_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("CORE_FEATURE_LOCK_UI_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
