extends SceneTree

const GameState := preload("res://scripts/game_state.gd")
const CoreFeatureUnlockService := preload("res://scripts/core_feature_unlock_service.gd")
const MainScene := preload("res://scenes/Main.tscn")
const ResearchProgressDialogScene := preload("res://scenes/ui/overlays/research_progress_dialog.tscn")
const TEST_SAVE_PATH := "res://tests/research_wait_dialog_self_check.save.json"
const REQUESTED_DIALOG_SIZE := Vector2i(520, 420)

var failures: Array[String] = []
var dialog_confirm_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_dialog_states()
	await _test_waited_research_flow()
	_cleanup_test_save()
	_finish()


func _test_dialog_states() -> void:
	var dialog := ResearchProgressDialogScene.instantiate()
	root.add_child(dialog)
	await process_frame
	dialog.result_confirmed.connect(_on_dialog_confirmed)
	var panel_style: StyleBox = dialog.get_theme_stylebox(&"panel")
	_expect(panel_style is StyleBoxTexture, "research progress dialog should use a textured panel background")
	if panel_style is StyleBoxTexture:
		var texture_style := panel_style as StyleBoxTexture
		_expect(texture_style.texture != null and texture_style.texture.resource_path == "res://resources/ui/skin/neighborhood_dessert/runtime/panel_v1.png", "research progress dialog should use the shared panel_v1 background")
		for margin_name in ["texture_margin_left", "texture_margin_top", "texture_margin_right", "texture_margin_bottom"]:
			_expect(is_equal_approx(float(texture_style.get(margin_name)), 52.0), "research progress dialog %s should preserve panel_v1 ornaments" % margin_name)

	dialog.call("show_waiting")
	await process_frame
	var baseline_dialog_size: Vector2i = dialog.size
	var dialog_margin := dialog.get_node("DialogMargin") as MarginContainer
	var state_content := dialog.get_node("DialogMargin/DialogContent/StateContent") as Control
	var default_result_center := state_content.get_node("DefaultResultCenter") as CenterContainer
	var result_content := default_result_center.get_node("ResultContent")
	var result_icon := result_content.get_node("ResultIcon") as TextureRect
	var result_name_label := result_content.get_node("ResultNameLabel") as Label
	var message_label := result_content.get_node("MessageLabel") as RichTextLabel
	var failure_content := state_content.get_node("ResearchFailureContent") as VBoxContainer
	var failure_message := failure_content.get_node("FailureMessageLabel") as RichTextLabel
	var hint_title := failure_content.get_node("ResearchHintTitle") as Label
	var hint_body := failure_content.get_node("ResearchHintBody") as RichTextLabel
	var confirm_button := dialog.get_node("DialogMargin/DialogContent/ConfirmButton") as Button
	_expect(dialog.visible, "waiting dialog should open immediately")
	_expect(bool(dialog.call("is_waiting")), "dialog should expose its waiting state")
	_expect(message_label.text.find("研发中") != -1, "waiting dialog should show the temporary research text")
	_expect(default_result_center.visible and not failure_content.visible, "waiting dialog should use only the default centered result layout")
	_expect(default_result_center.position == Vector2.ZERO and default_result_center.size == state_content.size, "default results should retain the original full-state centered layout")
	_expect(failure_message.text.is_empty() and hint_title.text.is_empty() and hint_body.text.is_empty(), "waiting dialog should clear the research failure content")
	_expect(baseline_dialog_size.x >= REQUESTED_DIALOG_SIZE.x and baseline_dialog_size.y >= REQUESTED_DIALOG_SIZE.y, "waiting dialog should honor the requested size without clipping its content minimum")
	_expect(dialog.min_size == Vector2i.ZERO and dialog.max_size == Vector2i.ZERO, "research dialog should not override the original adaptive window limits")
	_expect(
		_dialog_margin_is_symmetric(dialog_margin, baseline_dialog_size),
		"research dialog content should keep symmetric outer insets inside the panel safe area (dialog=%s, margin_position=%s, margin_size=%s)" % [baseline_dialog_size, dialog_margin.position, dialog_margin.size]
	)
	_expect(not confirm_button.visible and confirm_button.disabled, "waiting dialog should not expose confirmation")
	dialog.close_requested.emit()
	await process_frame
	_expect(dialog.visible, "close requests should not dismiss the waiting dialog")

	var test_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	test_image.fill(Color.WHITE)
	var test_texture := ImageTexture.create_from_image(test_image)
	dialog.call("show_item_success", test_texture, "测试配方", "研发成功：测试配方。", "研发")
	await process_frame
	_expect(result_icon.visible and result_icon.texture == test_texture, "item success should show the supplied icon")
	_expect(result_name_label.visible and result_name_label.text == "测试配方", "item success should show the supplied name")
	_expect(message_label.text.find("研发成功") != -1, "recipe success should keep the success message")
	_expect(default_result_center.visible and not failure_content.visible, "recipe success should keep the default centered result layout")
	_expect(dialog.size == baseline_dialog_size, "research success should preserve the waiting-state runtime size")
	_expect(_control_has_bottom_inset(confirm_button, dialog, 24.0), "research success confirmation should remain inside the panel bottom inset")

	dialog.call(
		"show_result",
		false,
		"设备不对，请更换研发工具。",
		"研发",
		"研发笔记｜线索等级 2｜测试配方",
		"正确设备：烤箱\n缺少类别：调味"
	)
	await process_frame
	_expect(dialog.visible and bool(dialog.call("is_result_ready")), "the same dialog should enter result state")
	_expect(failure_message.text.find("设备不对") != -1, "research failure layout should preserve the business message")
	_expect(not result_icon.visible and result_icon.texture == null, "failure result should clear the previous item icon")
	_expect(not result_name_label.visible and result_name_label.text.is_empty(), "failure result should clear the previous item name")
	_expect(not default_result_center.visible and failure_content.visible, "research failure should use only its dedicated content layout")
	_expect(hint_title.text.find("线索等级 2") != -1 and hint_body.text.find("正确设备：烤箱") != -1, "research failure should preserve notebook title and body")
	_expect(failure_content.position == Vector2.ZERO, "research failure content should start at the state area's top-left origin")
	_expect(failure_content.size == state_content.size, "research failure content should fill the state area without right or bottom drift")
	_expect(failure_message.position.y == 0.0, "research failure message should remain fixed at the top of its content area")
	_expect(dialog.size == baseline_dialog_size, "research failure with a notebook should preserve the waiting-state runtime size")
	dialog.call("show_result", false, "加工失败：材料不匹配。", "加工", "不应显示的笔记", "不应显示")
	await process_frame
	_expect(default_result_center.visible and not failure_content.visible, "processing failures should return to the default centered result layout")
	_expect(failure_message.text.is_empty() and hint_title.text.is_empty() and hint_body.text.is_empty(), "processing failures should ignore and clear research notebook content")
	_expect(dialog.size == baseline_dialog_size, "processing failure should preserve the waiting-state runtime size")
	_expect(confirm_button.visible and not confirm_button.disabled, "result state should expose confirmation")
	confirm_button.pressed.emit()
	await process_frame
	_expect(not dialog.visible, "confirming a result should close the dialog")
	_expect(dialog_confirm_count == 1, "result confirmation should emit exactly once")

	dialog.call("show_item_success", null, "缺图产物", "研发成功：缺图产物。", "研发")
	await process_frame
	_expect(not result_icon.visible and result_icon.texture == null, "missing icon resources should hide only the icon area")
	_expect(result_name_label.visible and result_name_label.text == "缺图产物", "missing icon resources should retain the item name")
	_expect(message_label.text.find("研发成功") != -1 and confirm_button.visible, "missing icon resources should retain the message and confirmation")
	_expect(default_result_center.visible and not failure_content.visible, "the next success should keep the default centered result layout")
	_expect(failure_message.text.is_empty() and hint_title.text.is_empty() and hint_body.text.is_empty(), "the next success should clear the previous failure notebook")
	_expect(dialog.size == baseline_dialog_size, "missing-icon success should preserve the waiting-state runtime size")
	confirm_button.pressed.emit()
	await process_frame
	_expect(dialog_confirm_count == 2, "missing-icon success should remain confirmable")

	dialog.queue_free()
	await process_frame


func _test_waited_research_flow() -> void:
	var view = MainScene.instantiate()
	view.set("save_path", TEST_SAVE_PATH)
	root.add_child(view)
	await process_frame

	var state = GameState.new_game()
	state.level = 2
	state.shop_level = 2
	state.tutorial_guide_skipped = true
	state.unlock_core_feature(CoreFeatureUnlockService.OUTPUT)
	state.unlock_core_feature(CoreFeatureUnlockService.INVENTORY)
	state.unlock_core_feature(CoreFeatureUnlockService.RESEARCH)
	state.unlock_device("grinder")
	state.unlock_device("round_pot")
	for item_id in ["rice", "spring_water", "sugar"]:
		state.add_ingredient(item_id, 4)
	view.set("state", state)
	view.call("_show_page", "research")
	await process_frame

	_expect(is_equal_approx(float(view.call("_research_wait_duration_seconds", 1)), 0.5), "one material should wait 0.5 seconds")
	_expect(is_equal_approx(float(view.call("_research_wait_duration_seconds", 2)), 1.0), "two materials should wait 1.0 second")
	_expect(is_equal_approx(float(view.call("_research_wait_duration_seconds", 3)), 1.5), "three materials should wait 1.5 seconds")
	_expect(is_equal_approx(float(view.call("_research_wait_duration_seconds", 6)), 1.5), "more than three materials should stay capped at 1.5 seconds")

	var research_dialog := view.get_node("ResearchProgressDialog")
	var dialog_state_content := research_dialog.get_node("DialogMargin/DialogContent/StateContent") as Control
	var dialog_default_center := dialog_state_content.get_node("DefaultResultCenter") as CenterContainer
	var dialog_result_content := dialog_default_center.get_node("ResultContent")
	var dialog_failure_content := dialog_state_content.get_node("ResearchFailureContent") as VBoxContainer
	var dialog_failure_message := dialog_failure_content.get_node("FailureMessageLabel") as RichTextLabel
	var dialog_hint_title := dialog_failure_content.get_node("ResearchHintTitle") as Label
	var dialog_hint_body := dialog_failure_content.get_node("ResearchHintBody") as RichTextLabel
	var task_popup := view.get_node("TaskPopup") as AcceptDialog
	var empty_materials: Array[String] = []
	view.set("selected_research_material_ids", empty_materials)
	view.set("selected_research_tool_id", "grinder")
	view.call("_on_primary_action")
	_expect(not bool(view.get("research_request_busy")), "invalid empty input should fail before starting a wait")
	_expect(not research_dialog.visible, "invalid empty input should not open the dialog")

	var one_material: Array[String] = ["rice"]
	view.set("selected_research_material_ids", one_material)
	view.set("selected_research_tool_id", "grinder")
	var rice_before_processing: int = int(state.get_ingredient_count("rice"))
	view.call("_on_primary_action")
	view.call("_on_primary_action")
	await process_frame
	var integration_baseline_size: Vector2i = research_dialog.size
	_expect(bool(view.get("research_request_busy")), "valid processing should set the shared busy guard")
	_expect(research_dialog.visible and bool(research_dialog.call("is_waiting")), "one-material processing should use the research waiting dialog")
	await create_timer(0.25).timeout
	_expect(state.get_ingredient_count("rice") == rice_before_processing, "processing must not consume its material before 0.5 seconds")
	await create_timer(0.40).timeout
	_expect(state.get_ingredient_count("rice") == rice_before_processing - 1, "processing should consume material once after the wait")
	_expect(state.get_ingredient_count("rice_flour") == 2, "processing should settle exactly once despite a repeated click")
	_expect(bool(research_dialog.call("is_result_ready")), "processing should reveal its result in the waiting dialog")
	_expect((research_dialog.get_node("DialogMargin/DialogContent/TitleLabel") as Label).text == "加工成功", "single-material success should identify itself as processing")
	var process_icon := dialog_result_content.get_node("ResultIcon") as TextureRect
	var process_name := dialog_result_content.get_node("ResultNameLabel") as Label
	var process_message := dialog_result_content.get_node("MessageLabel") as RichTextLabel
	_expect(process_icon.visible and process_icon.texture != null, "processing success should show the output ingredient icon")
	if process_icon.texture != null:
		_expect(process_icon.texture.get_width() == 1024 and process_icon.texture.get_height() == 1024, "rice flour success should load the 1024x1024 ingredient_v1 texture")
	_expect(process_icon.custom_minimum_size == Vector2(128, 128), "processing success should keep a 128x128 display area")
	_expect(process_name.visible and process_name.text == "大米粉", "processing success should show the output ingredient name")
	_expect(process_message.text.find("加工完成：大米粉 x2") != -1, "processing success should keep the output quantity message")
	_expect(dialog_default_center.visible and not dialog_failure_content.visible, "single-material processing should keep the default centered result layout")
	_expect(research_dialog.size == integration_baseline_size, "single-material processing should preserve the waiting-state runtime size")
	_confirm_research_dialog(research_dialog)
	await process_frame
	_expect(not bool(view.get("research_request_busy")), "confirming the processing result should clear the busy guard")

	var two_materials: Array[String] = ["rice", "spring_water"]
	view.set("selected_research_material_ids", two_materials)
	view.set("selected_research_tool_id", "round_pot")
	var rice_before_research: int = int(state.get_ingredient_count("rice"))
	var water_before_research: int = int(state.get_ingredient_count("spring_water"))
	view.call("_on_primary_action")
	await create_timer(0.50).timeout
	_expect(not state.is_recipe_unlocked("rice_milk_drink"), "two-material recipe must remain locked during its 1.0 second wait")
	_expect(state.get_ingredient_count("rice") == rice_before_research and state.get_ingredient_count("spring_water") == water_before_research, "research must not consume materials during its wait")
	await create_timer(0.65).timeout
	_expect(state.is_recipe_unlocked("rice_milk_drink"), "two-material recipe should unlock after its wait")
	_expect(state.get_ingredient_count("rice") == rice_before_research - 1 and state.get_ingredient_count("spring_water") == water_before_research - 1, "successful research should settle exactly one material set")
	_expect(bool(research_dialog.call("is_result_ready")), "successful research should reuse the waiting dialog for its result")
	_expect((research_dialog.get_node("DialogMargin/DialogContent/TitleLabel") as Label).text == "研发成功", "research success should use a success title")
	var success_icon := dialog_result_content.get_node("ResultIcon") as TextureRect
	var success_name := dialog_result_content.get_node("ResultNameLabel") as Label
	var success_message := dialog_result_content.get_node("MessageLabel") as RichTextLabel
	_expect(success_icon.visible and success_icon.texture != null, "research success should show the recipe icon")
	if success_icon.texture != null:
		_expect(success_icon.texture.get_width() == 128 and success_icon.texture.get_height() == 128, "rice milk research success should load its exact 128x128 pilot texture")
	_expect(success_icon.custom_minimum_size == Vector2(128, 128), "research success should keep a 128x128 display area")
	_expect(success_name.visible and success_name.text == "米浆饮", "research success should show the unlocked recipe name")
	_expect(success_message.text.find("研发成功：米浆饮") != -1, "research success should keep the existing success message")
	_expect(dialog_default_center.visible and not dialog_failure_content.visible, "successful research should keep the default centered result layout")
	_expect(research_dialog.size == integration_baseline_size, "successful research should preserve the waiting-state runtime size")
	_expect(_control_has_bottom_inset(research_dialog.get_node("DialogMargin/DialogContent/ConfirmButton") as Button, research_dialog, 24.0), "successful research confirmation should remain inside the panel bottom inset")
	_expect(not _has_recipe_unlock_notification(state), "the custom result dialog should suppress the duplicate recipe unlock notification")
	_confirm_research_dialog(research_dialog)
	await process_frame
	task_popup.hide()
	state.pending_notifications.clear()

	var three_materials: Array[String] = ["rice", "spring_water", "sugar"]
	view.set("selected_research_material_ids", three_materials)
	view.set("selected_research_tool_id", "round_pot")
	var sugar_before_failure: int = int(state.get_ingredient_count("sugar"))
	view.call("_on_primary_action")
	await create_timer(0.75).timeout
	_expect(bool(research_dialog.call("is_waiting")), "three-material research should still wait at the halfway point")
	_expect(state.get_ingredient_count("sugar") == sugar_before_failure, "failed research must not settle before 1.5 seconds")
	await create_timer(0.90).timeout
	_expect(bool(research_dialog.call("is_result_ready")), "failed research should replace the waiting content with a result")
	_expect((research_dialog.get_node("DialogMargin/DialogContent/TitleLabel") as Label).text == "研发失败", "failed research should use a failure title")
	_expect(not (dialog_result_content.get_node("ResultIcon") as TextureRect).visible, "research failure should clear the previous item icon")
	_expect(not (dialog_result_content.get_node("ResultNameLabel") as Label).visible, "research failure should clear the previous item name")
	_expect(not dialog_default_center.visible and dialog_failure_content.visible, "failed research should switch to the dedicated failure layout")
	_expect(not dialog_failure_message.text.is_empty(), "failed research should show its business message in the dedicated failure layout")
	_expect(dialog_hint_title.text.find("研发笔记") != -1 and not dialog_hint_body.text.is_empty(), "failed research should show a populated notebook title and body")
	_expect(dialog_failure_content.position == Vector2.ZERO and dialog_failure_content.size == dialog_state_content.size, "failed research content should stay top-left aligned and fill the state area")
	_expect(research_dialog.size == integration_baseline_size, "failed research notebook should preserve the waiting-state runtime size")

	state.enqueue_notification("等待后通知", "研发结果确认后再展示。")
	view.call("_show_next_notification")
	_expect(not task_popup.visible, "global notifications should remain blocked while the research result is visible")
	_confirm_research_dialog(research_dialog)
	await process_frame
	_expect(task_popup.visible, "confirming the research result should resume the pending notification queue")
	_expect(not bool(view.get("research_request_busy")), "confirming a failed result should clear the busy guard")

	view.queue_free()
	await process_frame


func _confirm_research_dialog(dialog: Node) -> void:
	var confirm_button := dialog.get_node("DialogMargin/DialogContent/ConfirmButton") as Button
	confirm_button.pressed.emit()


func _dialog_margin_is_symmetric(dialog_margin: MarginContainer, dialog_size: Vector2i) -> bool:
	var right_inset := float(dialog_size.x) - dialog_margin.position.x - dialog_margin.size.x
	var bottom_inset := float(dialog_size.y) - dialog_margin.position.y - dialog_margin.size.y
	return dialog_margin.position.x >= 24.0 \
		and dialog_margin.position.y >= 24.0 \
		and is_equal_approx(dialog_margin.position.x, right_inset) \
		and is_equal_approx(dialog_margin.position.y, bottom_inset)


func _control_has_bottom_inset(control: Control, dialog: Window, minimum_inset: float) -> bool:
	var control_rect := control.get_global_rect()
	return float(dialog.size.y) - control_rect.end.y >= minimum_inset - 0.5


func _has_recipe_unlock_notification(state) -> bool:
	for notification_value: Variant in state.pending_notifications:
		if not notification_value is Dictionary:
			continue
		var title := String((notification_value as Dictionary).get("title", ""))
		if title.begins_with("解锁新配方"):
			return true
	return false


func _on_dialog_confirmed() -> void:
	dialog_confirm_count += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _cleanup_test_save() -> void:
	for path in [TEST_SAVE_PATH, "%s.tmp" % TEST_SAVE_PATH]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func _finish() -> void:
	if failures.is_empty():
		print("RESEARCH_WAIT_DIALOG_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
