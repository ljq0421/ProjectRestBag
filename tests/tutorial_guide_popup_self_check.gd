extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate() as Control
	main.set("save_path", OS.get_temp_dir().path_join("tutorial_guide_popup_self_check.json"))
	main.set("broken_save_path", OS.get_temp_dir().path_join("tutorial_guide_popup_self_check.broken.json"))
	root.add_child(main)
	await process_frame
	await process_frame
	var state = GAME_STATE.new_game()
	main.set("state", state)
	main.call("_refresh_tutorial_guide")
	await process_frame
	var overlay := main.get_node("TutorialGuideOverlay") as Control
	_expect(overlay.visible, "active guide should start visible")
	_expect(overlay.call("is_dialogue_expanded"), "first grandma dialogue should start expanded")
	var dialogue_panel := overlay.get_node("DialoguePanel") as PanelContainer
	var icon_button := overlay.get_node("GrandmaIconButton") as Button
	var confirm_button := overlay.get_node("DialoguePanel/DialogueContent/DialogueBody/ActionRow/ConfirmButton") as Button
	_expect(not main.call("_is_tutorial_popup_blocking"), "the purchase step's matching purchase overlay should remain usable with grandma dialogue")

	main.call("_show_page", "output")
	await process_frame
	_expect(main.call("_is_tutorial_popup_blocking"), "an unrelated output overlay should block purchase-step grandma dialogue")
	main.call("_process", 0.0)
	_expect(not overlay.visible, "MainView process should automatically hide grandma dialogue behind an unrelated overlay")
	main.call("_close_global_popup")
	main.call("_process", 0.0)
	await process_frame
	await process_frame
	_expect(overlay.visible and dialogue_panel.visible, "closing an unrelated overlay should automatically restore the expanded grandma dialogue")

	var receipt := main.get_node("PurchaseReceiptDialog") as Control
	receipt.show()
	await process_frame
	_expect(main.call("_is_tutorial_popup_blocking"), "purchase receipt should block the guide")
	overlay.call("set_popup_paused", main.call("_is_tutorial_popup_blocking"))
	_expect(not overlay.visible, "purchase receipt should hide the guide")
	receipt.hide()
	await process_frame
	main.call("_refresh_tutorial_guide")
	await process_frame
	_expect(overlay.visible, "closing the purchase receipt should restore the same guide step")
	_expect(dialogue_panel.visible and overlay.call("is_dialogue_expanded"), "closing the purchase receipt should restore the previously expanded dialogue")
	_expect(String(state.tutorial_guide_step) == "purchase", "popup pause should not advance the guide")

	confirm_button.emit_signal("pressed")
	await process_frame
	_expect(icon_button.visible and not dialogue_panel.visible, "acknowledged grandma dialogue should collapse before the next popup")
	main.call("_show_task_global_popup")
	await process_frame
	_expect(main.call("_is_tutorial_popup_blocking"), "ordinary global overlay should block the guide")
	overlay.call("set_popup_paused", main.call("_is_tutorial_popup_blocking"))
	_expect(not overlay.visible, "ordinary global overlay should hide the guide")
	main.call("_close_global_popup")
	main.call("_refresh_tutorial_guide")
	await process_frame
	_expect(overlay.visible, "closing the global overlay should restore the guide")
	_expect(icon_button.visible and not dialogue_panel.visible, "closing the global overlay should restore the previously collapsed icon")

	state.tutorial_guide_step = "research"
	state.add_ingredient("rice", 3)
	state.add_ingredient("spring_water", 2)
	state.unlock_device("round_pot")
	main.call("_refresh_tutorial_guide")
	await process_frame
	_expect(String(main.get("global_popup_mode")) == "research", "research guide step should open the research overlay")
	main.call("_on_research_material_slot_pressed", 0)
	await process_frame
	await process_frame
	_expect(String(main.get("global_popup_mode")) == "inventory", "research material slot should open inventory")
	_expect(String(main.get("global_popup_return_mode")) == "research", "research picker should remember its return mode")
	var picker_target := overlay.get("_target") as Control
	_expect(picker_target != null and String(picker_target.get_meta("inventory_key", "")) == "ingredient:rice", "research inventory popup should retarget the arrow to rice")
	if picker_target != null:
		picker_target.emit_signal("pressed")
		await process_frame
		await process_frame
	_expect(String(main.get("global_popup_mode")) == "research", "selecting a research material should return to research")
	_expect((main.get("selected_research_material_ids") as Array).has("rice"), "selected research material should survive the inventory return")

	main.call("_on_research_material_slot_pressed", 1)
	await process_frame
	_expect(String(main.get("global_popup_mode")) == "inventory", "second material slot should reopen inventory")
	main.call("_on_overlay_close_button_pressed")
	await process_frame
	_expect(String(main.get("global_popup_mode")) == "research", "canceling the research picker should return to research")
	_expect(int(main.get("pending_research_material_slot_index")) == -1, "canceling the picker should clear the pending slot")

	main.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TUTORIAL_GUIDE_POPUP_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("TUTORIAL_GUIDE_POPUP_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
