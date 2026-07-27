class_name RecipeGrowthChoiceDialog
extends ConfirmationDialog

signal trait_selected(recipe_id: String, trait_id: String)

@onready var title_label: Label = $ChoiceBody/ChoiceContent/TitleLabel
@onready var candidate_list: ItemList = $ChoiceBody/ChoiceContent/CandidateList
@onready var impact_label: RichTextLabel = $ChoiceBody/ChoiceContent/ImpactLabel

var _recipe_id := ""
var _candidates: Array[Dictionary] = []
var _selected_trait_id := ""


func _ready() -> void:
	var select_handler := Callable(self, "_on_candidate_selected")
	if not candidate_list.item_selected.is_connected(select_handler):
		candidate_list.item_selected.connect(select_handler)
	var confirm_handler := Callable(self, "_on_confirmed")
	if not confirmed.is_connected(confirm_handler):
		confirmed.connect(confirm_handler)


func show_choice(recipe_id: String, recipe_name: String, mastery_name: String, candidates: Array[Dictionary]) -> void:
	if not is_node_ready():
		await ready
	_recipe_id = recipe_id
	_candidates = candidates.duplicate(true)
	_selected_trait_id = ""
	title_label.text = "%s 成长为%s" % [recipe_name, mastery_name]
	candidate_list.clear()
	for candidate in _candidates:
		candidate_list.add_item(String(candidate.get("label", candidate.get("id", "成长特性"))))
		candidate_list.set_item_metadata(candidate_list.item_count - 1, String(candidate.get("id", "")))
	if not _candidates.is_empty():
		candidate_list.select(0)
		_on_candidate_selected(0)
	get_ok_button().disabled = _selected_trait_id.is_empty()
	popup_centered(Vector2i(760, 560))


func _on_candidate_selected(index: int) -> void:
	if index < 0 or index >= _candidates.size():
		_selected_trait_id = ""
		get_ok_button().disabled = true
		return
	var candidate: Dictionary = _candidates[index]
	_selected_trait_id = String(candidate.get("id", ""))
	impact_label.text = String(candidate.get("impact_text", "暂无收益预估"))
	get_ok_button().disabled = _selected_trait_id.is_empty()


func _on_confirmed() -> void:
	if not _recipe_id.is_empty() and not _selected_trait_id.is_empty():
		trait_selected.emit(_recipe_id, _selected_trait_id)
