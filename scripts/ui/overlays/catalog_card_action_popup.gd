extends PopupPanel

signal reward_claim_requested(recipe_id: String)
signal make_requested(recipe_id: String)

const POPUP_SIZE := Vector2i(460, 560)
const CARD_GAP := 8

var _recipe_id := ""

@onready var detail_text: RichTextLabel = $PopupMargin/PopupContent/DetailScroll/DetailText
@onready var claim_reward_button: Button = $PopupMargin/PopupContent/ActionRow/ClaimRewardButton
@onready var make_button: Button = $PopupMargin/PopupContent/ActionRow/MakeButton


func _ready() -> void:
	claim_reward_button.pressed.connect(_on_claim_reward_pressed)
	make_button.pressed.connect(_on_make_pressed)


func show_recipe(recipe_id: String, content: String, claimable_amount: int, anchor_rect: Rect2) -> void:
	_recipe_id = recipe_id
	_apply_content(content, claimable_amount)
	popup(Rect2i(_popup_position(anchor_rect), POPUP_SIZE))


func refresh_recipe(recipe_id: String, content: String, claimable_amount: int) -> void:
	if recipe_id != _recipe_id:
		return
	_apply_content(content, claimable_amount)


func close_menu() -> void:
	_recipe_id = ""
	hide()


func selected_recipe_id() -> String:
	return _recipe_id


func _apply_content(content: String, claimable_amount: int) -> void:
	detail_text.text = content
	claim_reward_button.disabled = claimable_amount <= 0
	claim_reward_button.text = "领取 %d 星辉" % claimable_amount if claimable_amount > 0 else "星辉已领取"
	claim_reward_button.tooltip_text = "领取该配方已达成的星辉奖励。" if claimable_amount > 0 else "继续提升配方熟练度可获得新的星辉。"


func _popup_position(anchor_rect: Rect2) -> Vector2i:
	var viewport_size := Vector2i(get_tree().root.size)
	var x := roundi(anchor_rect.end.x) + CARD_GAP
	if x + POPUP_SIZE.x > viewport_size.x:
		x = roundi(anchor_rect.position.x) - POPUP_SIZE.x - CARD_GAP
	x = clampi(x, 0, maxi(0, viewport_size.x - POPUP_SIZE.x))
	var y := clampi(roundi(anchor_rect.position.y), 0, maxi(0, viewport_size.y - POPUP_SIZE.y))
	return Vector2i(x, y)


func _on_claim_reward_pressed() -> void:
	if not _recipe_id.is_empty():
		reward_claim_requested.emit(_recipe_id)


func _on_make_pressed() -> void:
	if not _recipe_id.is_empty():
		make_requested.emit(_recipe_id)
