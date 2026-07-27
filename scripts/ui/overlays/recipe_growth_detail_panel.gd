class_name RecipeGrowthDetailPanel
extends VBoxContainer

signal trait_choice_requested(recipe_id: String)

const RecipeGrowthService = preload("res://scripts/recipe_growth_service.gd")

var _recipe_id := ""


func _ready() -> void:
	$ChooseTraitButton.pressed.connect(_on_choose_trait_pressed)


func refresh(state, catalog, recipe_id: String) -> void:
	_recipe_id = recipe_id
	if state == null or recipe_id.is_empty() or not state.is_recipe_unlocked(recipe_id):
		visible = false
		return
	visible = true
	var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
	var growth: Dictionary = state.get_recipe_growth(recipe_id)
	var status: Dictionary = state.recipe_growth_status(recipe_id)
	var mastery_level := int(growth.get("mastery_level", 0))
	var stage_name := RecipeGrowthService.mastery_name(mastery_level)
	$StageLabel.text = "成长阶段｜%s" % stage_name
	var stage_parts: Array[String] = []
	for stage_level in range(3):
		var label := RecipeGrowthService.mastery_name(stage_level)
		stage_parts.append("【%s】" % label if stage_level == mastery_level else label)
	$StageTrackLabel.text = " → ".join(stage_parts)
	_refresh_stage_requirement_rows(status, device_name_from(catalog, recipe))
	$CountLabel.text = "生涯统计｜制作成品 %d｜售卖 %d｜正向邻接 %d" % [
		int(growth.get("made_count", 0)),
		int(growth.get("sold_count", 0)),
		int(growth.get("adjacency_trigger_count", 0))
	]
	var device_name := device_name_from(catalog, recipe)
	if bool(status.get("waiting_for_device", false)):
		$DeviceStatusLabel.text = "%s L%d｜其他条件已完成，升级设备后将立即检查晋级" % [device_name, int(status.get("device_level", 1))]
	else:
		$DeviceStatusLabel.text = "%s L%d%s" % [device_name, int(status.get("device_level", 1)), "｜名作制作经验 +20%" if int(status.get("device_level", 1)) >= 4 else ""]
	var masterwork_level := int(growth.get("masterwork_level", 0))
	var xp_tenths := int(growth.get("masterwork_xp_tenths", 0))
	if masterwork_level <= 0:
		$MasterworkLabel.text = "名作｜招牌款并完成两次特性选择后开启"
		$MasterworkProgress.max_value = 1
		$MasterworkProgress.value = 0
	else:
		var next_threshold := RecipeGrowthService.masterwork_next_threshold(masterwork_level)
		var title := RecipeGrowthService.masterwork_title(String(recipe.get("name", recipe_id)), masterwork_level)
		$MasterworkLabel.text = "名作 Lv.%d｜经验 %.1f / %.1f%s" % [masterwork_level, xp_tenths / 10.0, next_threshold / 10.0, "｜称号 %s" % title if not title.is_empty() else ""]
		$MasterworkProgress.max_value = maxi(1, next_threshold)
		$MasterworkProgress.value = xp_tenths
	var selected_labels := RecipeGrowthService.trait_labels(growth.get("selected_traits", []))
	$TraitLabel.text = "已选特性：%s" % ("暂无" if selected_labels.is_empty() else "、".join(selected_labels))
	$ChooseTraitButton.visible = bool(growth.get("pending_trait_choice", false))
	$ChooseTraitButton.disabled = not bool(growth.get("pending_trait_choice", false))


func _refresh_stage_requirement_rows(status: Dictionary, device_name: String) -> void:
	var complete := bool(status.get("complete", false))
	$NextStageLabel.text = "三阶段成长已完成" if complete else "下一阶段｜%s" % String(status.get("next_mastery_name", ""))
	$StageMadeRow.visible = not complete
	$StageEffectiveRoundRow.visible = not complete
	$StageSynergyRoundRow.visible = not complete and int(status.get("synergy_rounds_target", 0)) > 0
	$StageDeviceRow.visible = not complete and int(status.get("device_target_level", 0)) > 1
	$AllConditionsHintLabel.visible = not complete
	if complete:
		return
	$StageMadeRow.text = _progress_row_text("制作批次", int(status.get("made_batches", 0)), int(status.get("made_batches_target", 0)), int(status.get("made_batches_remaining", 0)), bool(status.get("made_batches_complete", false)))
	$StageEffectiveRoundRow.text = _progress_row_text("有效营业", int(status.get("effective_rounds", 0)), int(status.get("effective_rounds_target", 0)), int(status.get("effective_rounds_remaining", 0)), bool(status.get("effective_rounds_complete", false)))
	$StageSynergyRoundRow.text = _progress_row_text("协同营业", int(status.get("synergy_rounds", 0)), int(status.get("synergy_rounds_target", 0)), int(status.get("synergy_rounds_remaining", 0)), bool(status.get("synergy_rounds_complete", false)))
	$StageDeviceRow.text = "%s等级｜L%d / L%d%s" % [device_name, int(status.get("device_level", 1)), int(status.get("device_target_level", 1)), "（完成）" if bool(status.get("device_level_complete", false)) else "（等待升级）"]


func _progress_row_text(label: String, current: int, target: int, remaining: int, complete: bool) -> String:
	return "%s｜%d / %d%s" % [label, current, target, "（完成）" if complete else "（还差 %d）" % remaining]


func device_name_from(catalog, recipe: Dictionary) -> String:
	return String(catalog.get_devices().get(String(recipe.get("device", "")), {}).get("name", "设备"))


func _on_choose_trait_pressed() -> void:
	if not _recipe_id.is_empty():
		trait_choice_requested.emit(_recipe_id)
