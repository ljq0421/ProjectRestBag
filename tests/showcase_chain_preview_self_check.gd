extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var state = GAME_STATE.new_game()
	state.display_items = {
		"a": {"cells": [Vector2i(6, 7)], "stock": 1},
		"b": {"cells": [Vector2i(6, 8)], "stock": 1}
	}
	main.set("state", state)
	main.call("_refresh_storefront_showcase")
	await process_frame
	main.call("_refresh_showcase_chain_preview", {
		"a": {"role": "advance", "targets": ["b"]},
		"b": {"role": "lure", "targets": ["a"]}
	})
	var layer: Control = main.get_node("ShowcaseFeedbackLayer")
	var arrow: Label = layer.get_node_or_null("ShowcaseChainArrow_a_b")
	if arrow == null or arrow.text != "→" or not arrow.visible:
		_fail("adjacent directional chain should render a visible arrow")

	main.call("_refresh_showcase_chain_preview", {
		"a": {"role": "advance", "targets": []},
		"b": {"role": "lure", "targets": []}
	})
	if layer.get_node_or_null("ShowcaseChainBroken_a") != null:
		_fail("isolated advance role should end silently without a broken-chain marker")
	if layer.get_node_or_null("ShowcaseChainArrow_a_b") != null:
		_fail("stale chain arrows should be cleared when the layout changes")

	for popup_mode in ["inventory", "catalog", "task"]:
		main.call("_open_global_popup_mode", popup_mode)
		if layer.visible:
			_fail("showcase feedback layer should hide behind the %s overlay" % popup_mode)
		main.call("_close_global_popup")
		if not layer.visible:
			_fail("closing the %s overlay should restore the showcase feedback layer" % popup_mode)

	main.queue_free()
	_finish()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_CHAIN_PREVIEW_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("SHOWCASE_CHAIN_PREVIEW_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
