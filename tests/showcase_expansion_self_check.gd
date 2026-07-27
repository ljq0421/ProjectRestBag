extends SceneTree

const GameState = preload("res://scripts/game_state.gd")

var failures: Array[String] = []

func _init() -> void:
	var state: GameState = GameState.new_game()
	state.level = 2
	var target := Vector2i(4, 6)
	var quote: Dictionary = state.quote_showcase_cell_purchase([target])
	_expect(int(quote.get("total_cost", 0)) == 300, "first purchased cell should cost 300")
	var before: Array[Vector2i] = state.get_showcase_unlocked_cells()
	_expect(not bool(state.purchase_showcase_cells([target]).get("ok", false)), "insufficient coins should reject atomically")
	_expect(state.get_showcase_unlocked_cells() == before, "failed purchase should not change unlocked cells")
	state.coins = 300
	_expect(bool(state.purchase_showcase_cells([target]).get("ok", false)), "funded adjacent-cell purchase should succeed")
	_expect(state.coins == 0, "purchase should spend exact cost")
	_expect(int(state.get_showcase_region_layout().get("unlocked_count", 0)) == 17, "purchase should unlock exactly the selected cell")
	var scene := load("res://scenes/Main.tscn") as PackedScene
	_expect(scene != null, "main scene should parse")
	if scene == null:
		_finish()
		return
	var view := scene.instantiate()
	_expect(view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/StrategyActionRow/StorefrontExpansionButton") != null, "storefront strategy tab should expose expansion purchase")
	view.free()
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("SHOWCASE_EXPANSION_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value: failures.append(message)
