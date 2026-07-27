extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var view = MAIN_SCENE.instantiate()
	var save_path := OS.get_temp_dir().path_join("topbar_shop_upgrade_progress_self_check_%d.json" % OS.get_process_id())
	view.set("save_path", save_path)
	view.set("broken_save_path", save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var top_bar := view.get_node_or_null("Root/TopBar") as HBoxContainer
	var body := view.get_node_or_null("Root/Body") as HBoxContainer
	var coins_label := view.get_node_or_null("Root/TopBar/CoinsLabel") as Label
	var reputation_label := view.get_node_or_null("Root/TopBar/ReputationLabel") as Label
	var coins_skin := view.get_node_or_null("Root/TopBar/CoinsLabel/SkinTexture") as TextureRect
	var reputation_skin := view.get_node_or_null("Root/TopBar/ReputationLabel/SkinTexture") as TextureRect
	var coins_progress := view.get_node_or_null("Root/TopBar/CoinsLabel/UpgradeProgress") as ProgressBar
	var reputation_progress := view.get_node_or_null("Root/TopBar/ReputationLabel/UpgradeProgress") as ProgressBar
	for required_node in [top_bar, body, coins_label, reputation_label, coins_skin, reputation_skin, coins_progress, reputation_progress]:
		if required_node == null:
			_fail("top bar should declare coin and reputation labels with single-texture skinned upgrade progress bars")
			_finish(view, save_path)
			return
	if coins_skin.texture == null:
		_fail("coin skin should load the seamless derived texture")
		_finish(view, save_path)
		return

	_expect_equal("coin skin texture", coins_skin.texture.resource_path, "res://resources/ui/skin_v1/top_star_progress_174.png")
	_expect_equal("coin skin source width", coins_skin.texture.get_width(), 660)
	_expect_equal("coin skin source height", coins_skin.texture.get_height(), 167)
	_expect(coins_skin.get_node_or_null("TrackTexture") == null, "coin skin should not keep a separate track layer")
	_expect(coins_skin.get_node_or_null("IconTexture") == null, "coin skin should not keep a separate icon layer")
	_expect_equal("reputation skin texture", reputation_skin.texture.resource_path, "res://resources/ui/skin_v1/progress_cake.png")
	_expect_equal("coin skin expand mode", coins_skin.expand_mode, TextureRect.EXPAND_IGNORE_SIZE)
	_expect_equal("coin skin stretch mode", coins_skin.stretch_mode, TextureRect.STRETCH_SCALE)
	_expect_equal("reputation skin expand mode", reputation_skin.expand_mode, TextureRect.EXPAND_IGNORE_SIZE)
	_expect_equal("reputation skin stretch mode", reputation_skin.stretch_mode, TextureRect.STRETCH_SCALE)
	_expect(coins_skin.show_behind_parent and reputation_skin.show_behind_parent, "skin textures should render behind resource text")
	_expect(coins_progress.show_behind_parent and reputation_progress.show_behind_parent, "progress fills should render behind resource text")
	var coins_background := coins_progress.get_theme_stylebox("background") as StyleBoxFlat
	var reputation_background := reputation_progress.get_theme_stylebox("background") as StyleBoxFlat
	_expect(coins_background != null and is_equal_approx(coins_background.bg_color.a, 1.0), "coin track should be opaque enough to hide baked progress")
	_expect(reputation_background != null and is_equal_approx(reputation_background.bg_color.a, 1.0), "reputation track should be opaque enough to hide baked progress")
	_expect_equal("coin text left margin", int(coins_label.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT)), 42)
	_expect_equal("coin text right margin", int(coins_label.get_theme_stylebox("normal").get_content_margin(SIDE_RIGHT)), 13)
	_expect_equal("reputation text left margin", int(reputation_label.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT)), 42)
	_expect_equal("reputation text right margin", int(reputation_label.get_theme_stylebox("normal").get_content_margin(SIDE_RIGHT)), 13)
	_expect_equal("coin text size", coins_label.get_theme_font_size("font_size"), 14)
	_expect_equal("reputation text size", reputation_label.get_theme_font_size("font_size"), 14)
	_expect(coins_label.get_theme_color("font_color").is_equal_approx(Color("#fff4d1")), "coin text should use the cream foreground")
	_expect(reputation_label.get_theme_color("font_color").is_equal_approx(Color("#fff4d1")), "reputation text should use the cream foreground")
	_expect(coins_label.get_theme_color("font_outline_color").is_equal_approx(Color("#4a2414")), "coin text should use the chocolate outline")
	_expect(reputation_label.get_theme_color("font_outline_color").is_equal_approx(Color("#4a2414")), "reputation text should use the chocolate outline")
	_expect_equal("coin text outline size", coins_label.get_theme_constant("outline_size"), 3)
	_expect_equal("reputation text outline size", reputation_label.get_theme_constant("outline_size"), 3)

	var state = GAME_STATE.new_game()
	state.level = 1
	state.coins = 899
	state.reputation = 29
	view.set("state", state)
	view.call("_refresh_resource_bar")
	_expect_equal("Lv.1 coin progress text", coins_label.text, "金币 899 / 900")
	_expect_equal("Lv.1 reputation progress text", reputation_label.text, "口碑 29 / 30")
	_expect_equal("Lv.1 coin maximum", int(coins_progress.max_value), 900)
	_expect_equal("Lv.1 coin value", int(coins_progress.value), 899)
	_expect_equal("Lv.1 reputation maximum", int(reputation_progress.max_value), 30)
	_expect_equal("Lv.1 reputation value", int(reputation_progress.value), 29)
	_expect(coins_progress.visible and reputation_progress.visible, "Lv.1 should show both upgrade progress bars")
	_expect(coins_skin.visible and reputation_skin.visible, "Lv.1 should show both upgrade progress skins")
	_expect_equal("top bar keeps its original height", int(top_bar.size.y), 44)
	_expect_equal("body keeps its original vertical position", int(body.position.y), 52)
	_expect_equal("coin resource module height", int(coins_label.size.y), 44)
	_expect_equal("reputation resource module height", int(reputation_label.size.y), 44)
	_expect_equal("coin skin left offset", int(coins_skin.position.x), 3)
	_expect_equal("coin skin width", int(coins_skin.size.x), 174)
	_expect_equal("coin skin height", int(coins_skin.size.y), 44)
	_expect_equal("reputation skin left offset", int(reputation_skin.position.x), 3)
	_expect_equal("reputation skin width", int(reputation_skin.size.x), 174)
	_expect_equal("reputation skin height", int(reputation_skin.size.y), 44)
	_expect_equal("coin progress left offset", int(coins_progress.position.x), 42)
	_expect_equal("coin progress top offset", int(coins_progress.position.y), 15)
	_expect_equal("coin progress width", int(coins_progress.size.x), 125)
	_expect_equal("coin progress height", int(coins_progress.size.y), 17)
	_expect_equal("reputation progress left offset", int(reputation_progress.position.x), 42)
	_expect_equal("reputation progress top offset", int(reputation_progress.position.y), 15)
	_expect_equal("reputation progress width", int(reputation_progress.size.x), 125)
	_expect_equal("reputation progress height", int(reputation_progress.size.y), 17)
	_expect(coins_label.tooltip_text.contains("扣除"), "coin tooltip should explain that upgrade coins are deducted")
	_expect(reputation_label.tooltip_text.contains("不扣除"), "reputation tooltip should explain that cumulative reputation is retained")
	view.call("_set_coins_label_roll_value", 0.5, 100, 200)
	_expect_equal("coin roll keeps the upgrade denominator", coins_label.text, "金币 150 / 900")
	_expect_equal("coin roll keeps progress synchronized", int(coins_progress.value), 150)

	state.coins = 1200
	state.reputation = 45
	view.call("_refresh_resource_bar")
	_expect_equal("excess coins remain visible", coins_label.text, "金币 1200 / 900")
	_expect_equal("excess reputation remains visible", reputation_label.text, "口碑 45 / 30")
	_expect_equal("coin bar clamps at its maximum", int(coins_progress.value), 900)
	_expect_equal("reputation bar clamps at its maximum", int(reputation_progress.value), 30)

	state.coins = 900
	state.reputation = 30
	_expect(state.upgrade(), "ready Lv.1 state should upgrade")
	view.call("_refresh_resource_bar")
	_expect_equal("upgraded coin denominator switches to Lv.3", coins_label.text, "金币 0 / 2200")
	_expect_equal("upgraded reputation denominator switches to Lv.3", reputation_label.text, "口碑 30 / 80")

	var level_zero = GAME_STATE.new_game()
	level_zero.coins = 123
	level_zero.reputation = 4
	view.set("state", level_zero)
	view.call("_refresh_resource_bar")
	_expect_equal("Lv.0 keeps plain coin balance", coins_label.text, "金币: 123")
	_expect_equal("Lv.0 keeps plain reputation balance", reputation_label.text, "口碑: 4")
	_expect(not coins_progress.visible and not reputation_progress.visible, "Lv.0 should hide manual upgrade progress")
	_expect(not coins_skin.visible and not reputation_skin.visible, "Lv.0 should hide both upgrade progress skins")

	var capped_state = GAME_STATE.new_game()
	capped_state.level = 247
	capped_state.coins = 321
	capped_state.reputation = 654
	view.set("state", capped_state)
	view.call("_refresh_resource_bar")
	_expect_equal("missing definition keeps plain coin balance", coins_label.text, "金币: 321")
	_expect_equal("missing definition keeps plain reputation balance", reputation_label.text, "口碑: 654")
	_expect(not coins_progress.visible and not reputation_progress.visible, "missing upgrade definition should hide both progress bars")
	_expect(not coins_skin.visible and not reputation_skin.visible, "missing upgrade definition should hide both progress skins")

	_finish(view, save_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish(view: Node, save_path: String) -> void:
	view.queue_free()
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".broken")
	if _failures.is_empty():
		print("TOPBAR_SHOP_UPGRADE_PROGRESS_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("TOPBAR_SHOP_UPGRADE_PROGRESS_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
