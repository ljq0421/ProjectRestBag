class_name ResearchProgressDialog
extends PopupPanel

signal result_confirmed

const DIALOG_SIZE := Vector2i(520, 420)
const WAITING_MESSAGE := "研发中"

@onready var title_label: Label = $DialogMargin/DialogContent/TitleLabel
@onready var default_result_center: CenterContainer = $DialogMargin/DialogContent/StateContent/DefaultResultCenter
@onready var result_icon: TextureRect = $DialogMargin/DialogContent/StateContent/DefaultResultCenter/ResultContent/ResultIcon
@onready var result_name_label: Label = $DialogMargin/DialogContent/StateContent/DefaultResultCenter/ResultContent/ResultNameLabel
@onready var message_label: RichTextLabel = $DialogMargin/DialogContent/StateContent/DefaultResultCenter/ResultContent/MessageLabel
@onready var research_failure_content: VBoxContainer = $DialogMargin/DialogContent/StateContent/ResearchFailureContent
@onready var failure_message_label: RichTextLabel = $DialogMargin/DialogContent/StateContent/ResearchFailureContent/FailureMessageLabel
@onready var research_hint_title: Label = $DialogMargin/DialogContent/StateContent/ResearchFailureContent/ResearchHintTitle
@onready var research_hint_body: RichTextLabel = $DialogMargin/DialogContent/StateContent/ResearchFailureContent/ResearchHintBody
@onready var confirm_button: Button = $DialogMargin/DialogContent/ConfirmButton

var _waiting := false
var _result_ready := false


func _ready() -> void:
	if not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	close_requested.connect(_on_close_requested)
	_configure_waiting_controls()


func show_waiting() -> void:
	if not is_node_ready():
		await ready
	_waiting = true
	_result_ready = false
	title_label.text = "产品研发"
	_show_default_result()
	_clear_item_details()
	_clear_research_failure()
	message_label.text = "[center]%s[/center]" % WAITING_MESSAGE
	_configure_waiting_controls()
	popup_centered(DIALOG_SIZE)


func show_result(
	success: bool,
	message: String,
	action_name: String = "研发",
	hint_title: String = "",
	hint_body: String = ""
) -> void:
	if not is_node_ready():
		await ready
	_waiting = false
	_result_ready = true
	var safe_action_name := action_name if not action_name.is_empty() else "研发"
	title_label.text = "%s成功" % safe_action_name if success else "%s失败" % safe_action_name
	_clear_item_details()
	if not success and safe_action_name == "研发":
		_show_research_failure(message, hint_title, hint_body)
	else:
		_show_default_result()
		_clear_research_failure()
		message_label.text = "[center]%s[/center]" % _escape_bbcode(message)
	_show_confirmation()


func show_item_success(texture: Texture2D, item_name: String, message: String, action_name: String = "研发") -> void:
	if not is_node_ready():
		await ready
	_waiting = false
	_result_ready = true
	var safe_action_name := action_name if not action_name.is_empty() else "研发"
	title_label.text = "%s成功" % safe_action_name
	_show_default_result()
	_clear_research_failure()
	result_icon.texture = texture
	result_icon.visible = texture != null
	result_name_label.text = item_name
	result_name_label.visible = not item_name.is_empty()
	message_label.text = "[center]%s[/center]" % _escape_bbcode(message)
	_show_confirmation()


func is_waiting() -> bool:
	return _waiting


func is_result_ready() -> bool:
	return _result_ready


func _configure_waiting_controls() -> void:
	confirm_button.visible = false
	confirm_button.disabled = true


func _show_confirmation() -> void:
	confirm_button.visible = true
	confirm_button.disabled = false
	confirm_button.grab_focus()


func _clear_item_details() -> void:
	result_icon.texture = null
	result_icon.visible = false
	result_name_label.text = ""
	result_name_label.visible = false


func _show_default_result() -> void:
	default_result_center.visible = true
	research_failure_content.visible = false


func _show_research_failure(message: String, hint_title: String, hint_body: String) -> void:
	default_result_center.visible = false
	failure_message_label.text = "[center]%s[/center]" % _escape_bbcode(message)
	research_hint_title.text = hint_title
	research_hint_body.text = hint_body
	research_failure_content.visible = true


func _clear_research_failure() -> void:
	failure_message_label.text = ""
	research_hint_title.text = ""
	research_hint_body.text = ""
	research_failure_content.visible = false


func _on_confirm_pressed() -> void:
	if not _result_ready:
		return
	_result_ready = false
	hide()
	result_confirmed.emit()


func _on_close_requested() -> void:
	# Research completion must be acknowledged through the explicit confirm button.
	return


func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]")
