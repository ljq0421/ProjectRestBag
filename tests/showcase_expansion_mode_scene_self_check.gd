extends SceneTree

const BOARD_SCENE := preload("res://scenes/ui/storefront/showcase_board.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var board = BOARD_SCENE.instantiate()
	get_root().add_child(board)
	for path in [
		"ExpansionToolbar",
		"ExpansionToolbar/ExpansionContent/ExpansionToolRow/CellToolButton",
		"ExpansionToolbar/ExpansionContent/ExpansionToolRow/RowToolButton",
		"ExpansionToolbar/ExpansionContent/ExpansionToolRow/ColumnToolButton",
		"ExpansionToolbar/ExpansionContent/ExpansionQuoteLabel",
		"ExpansionToolbar/ExpansionContent/ExpansionActionRow/ExpansionConfirmButton",
		"ExpansionToolbar/ExpansionContent/ExpansionActionRow/ExpansionCancelButton"
	]:
		if board.get_node_or_null(path) == null:
			push_error("showcase expansion mode is missing node: %s" % path)
			quit(1)
			return
	for signal_name in ["expansion_tool_requested", "expansion_confirm_requested", "expansion_cancel_requested"]:
		if not board.has_signal(signal_name):
			push_error("showcase board is missing expansion signal: %s" % signal_name)
			quit(1)
			return
	board.set_expansion_mode(true, "cells", "已选 2 格｜合计 630 金币", true)
	if not board.get_node("ExpansionToolbar").visible:
		push_error("expansion toolbar should become visible in expansion mode")
		quit(1)
		return
	if board.get_node("ExpansionToolbar/ExpansionContent/ExpansionActionRow/ExpansionConfirmButton").disabled:
		push_error("valid expansion quote should enable confirmation")
		quit(1)
		return
	print("SHOWCASE_EXPANSION_MODE_SCENE_SELF_CHECK_PASS")
	quit(0)
