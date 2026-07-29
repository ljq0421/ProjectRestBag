class_name ChallengeUpgradeSelectView
extends PanelContainer

const UiStyle = preload("res://scripts/challenge/ui/challenge_ui_style.gd")

signal upgrade_requested(offer_id: String, upgrade_id: String)

var _offer_id := ""
var _candidate_ids: Array[String] = []
var _submitted := false


func _ready() -> void:
	for index in range(3):
		var button: Button = get_node("Content/Candidates/Candidate%d" % index)
		button.pressed.connect(func() -> void: _submit(index))


func bind(offer: Dictionary) -> void:
	_offer_id = String(offer.get("offer_id", ""))
	$Content/Eyebrow.text = (
		"本局强化 · 只持续到本次无尽爬升结束"
		if String(offer.get("mode", "standard")) == "endless"
		else "本局强化 · 只持续到这条短链结束"
	)
	_candidate_ids.clear()
	_submitted = false
	var candidates: Array = offer.get("candidates", [])
	for index in range(3):
		var button: Button = get_node("Content/Candidates/Candidate%d" % index)
		if index >= candidates.size() or not candidates[index] is Dictionary:
			button.visible = false
			continue
		var candidate: Dictionary = candidates[index]
		var upgrade_id := String(candidate.get("upgrade_id", candidate.get("id", "")))
		_candidate_ids.append(upgrade_id)
		var category := String(candidate.get("category", ""))
		button.visible = true
		button.disabled = false
		button.text = "%s\n\n%s\n\n%s · 点击选择" % [
			String(candidate.get("display_name", upgrade_id)),
			String(candidate.get("description", "")),
			_category_label(category)
		]
		UiStyle.apply_choice(button, category)
	$Content/OfferIdentity.text = "三选一 · 本轮候选已锁定，离开后也不会刷新"


func _submit(index: int) -> void:
	if _submitted or index < 0 or index >= _candidate_ids.size():
		return
	_submitted = true
	for button_index in range(3):
		get_node("Content/Candidates/Candidate%d" % button_index).disabled = true
	upgrade_requested.emit(_offer_id, _candidate_ids[index])


func _category_label(category: String) -> String:
	match category:
		"compatible":
			return "适配当前构筑"
		"universal":
			return "通用强化"
		"pivot":
			return "转型路线"
	return category
