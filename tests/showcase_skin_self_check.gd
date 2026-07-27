extends SceneTree

const THEME_PATH := "res://resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres"
const BOARD_SCENE_PATH := "res://scenes/ui/storefront/showcase_board.tscn"
const SLOT_SCENE_PATH := "res://scenes/ui/storefront/showcase_slot.tscn"

const REQUIRED_STYLES := {
	"DessertShowcaseSlot": ["normal", "hover", "pressed", "disabled"],
	"DessertShowcaseSlotLocked": ["normal", "hover", "pressed", "disabled"],
	"DessertShowcaseSlotReward": ["normal", "hover", "pressed", "disabled"],
	"DessertShowcaseBadge": ["normal"],
	"DessertShowcaseBadgeReady": ["normal"],
	"DessertShowcaseBoard": ["panel"],
}

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var theme := load(THEME_PATH) as Theme
	if theme == null:
		_fail("Neighborhood dessert Theme is missing")
		_finish()
		return

	for variation: String in REQUIRED_STYLES:
		for style_name: String in REQUIRED_STYLES[variation]:
			var style := theme.get_stylebox(style_name, variation)
			if not style is StyleBoxTexture or (style as StyleBoxTexture).texture == null:
				_fail("%s/%s must use a texture style" % [variation, style_name])

	var board_scene := load(BOARD_SCENE_PATH) as PackedScene
	var board := board_scene.instantiate() as Control
	if board.get_script() == null:
		_fail("Showcase board script must load")
	if not board is VBoxContainer:
		_fail("Showcase board must preserve its VBoxContainer contract")
	if board.theme_type_variation != &"DessertShowcaseBoard":
		_fail("Showcase board must use DessertShowcaseBoard")
	if board.get_node_or_null("ShowcaseGrid") == null:
		_fail("Showcase board must preserve the direct ShowcaseGrid path")
	board.free()

	var slot_scene := load(SLOT_SCENE_PATH) as PackedScene
	var slot := slot_scene.instantiate() as Button
	root.add_child(slot)
	await process_frame
	if slot.theme_type_variation != &"DessertShowcaseSlot":
		_fail("Showcase slot must start with DessertShowcaseSlot")
	var outline := slot.get_node_or_null("GroupOutline") as Panel
	if outline == null:
		_fail("Showcase slot must expose a GroupOutline overlay")
	if not slot.has_method("set_skin_state"):
		_fail("Showcase slot must expose set_skin_state")
	else:
		slot.call("set_skin_state", &"locked")
		if slot.theme_type_variation != &"DessertShowcaseSlotLocked":
			_fail("locked state must use DessertShowcaseSlotLocked")
		slot.call("set_skin_state", &"reward")
		if slot.theme_type_variation != &"DessertShowcaseSlotReward":
			_fail("reward state must use DessertShowcaseSlotReward")
	if slot.has_method("set_outline_edges"):
		slot.call("set_outline_edges", true, true, true, true, Color(1, 0.68, 0.08), false)
		if slot.has_theme_stylebox_override("normal"):
			_fail("group outline must not replace the slot Button skin")
		if outline != null and not outline.has_theme_stylebox_override("panel"):
			_fail("group outline must render on the overlay panel")
	if slot.has_method("set_status_badge"):
		slot.call("set_status_badge", "可售")
		var badge := slot.get_node_or_null("StatusBadge") as Label
		if badge == null or badge.theme_type_variation != &"DessertShowcaseBadgeReady":
			_fail("ready badge must use DessertShowcaseBadgeReady")

	slot.queue_free()
	_finish()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_SKIN_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("SHOWCASE_SKIN_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
