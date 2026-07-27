extends SceneTree

const BOARD_SCENE_PATH := "res://scenes/ui/storefront/showcase_board.tscn"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const SLOT_SCENE_PATH := "res://scenes/ui/storefront/showcase_slot.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var board_scene := load(BOARD_SCENE_PATH) as PackedScene
	_expect(board_scene != null, "showcase board scene should load")
	if board_scene != null:
		var board := board_scene.instantiate()
		root.add_child(board)
		await process_frame
		var grid := board.get_node_or_null("ShowcaseGrid") as GridContainer
		_expect(grid != null, "showcase board should preserve the direct ShowcaseGrid path")
		if grid != null:
			_expect(grid.columns == 14, "showcase background must preserve fourteen columns")
			_expect(grid.custom_minimum_size == Vector2(1008, 864), "showcase background must preserve the 1008 by 864 grid")
			_expect(grid.item_rect_changed.is_connected(board.queue_redraw), "showcase background should redraw when the grid moves or resizes")
			var original_overlay_rect := board.call("_showcase_header_overlay_rect") as Rect2
			grid.position.y += 12.0
			var moved_overlay_rect := board.call("_showcase_header_overlay_rect") as Rect2
			_expect(is_equal_approx(moved_overlay_rect.size.y, original_overlay_rect.size.y + 12.0), "showcase header overlay should follow the live grid position")
		_expect(_has_property(board, &"showcase_header_overlay_style"), "showcase board should expose a scene-owned header overlay style")
		if _has_property(board, &"showcase_header_overlay_style"):
			var overlay_style := board.get("showcase_header_overlay_style") as StyleBoxFlat
			_expect(overlay_style != null, "showcase board should bind the cream header overlay style")
			if overlay_style != null:
				_expect(overlay_style.bg_color.a >= 0.65 and overlay_style.bg_color.a <= 0.75, "showcase header overlay should use about seventy percent opacity")
		board.queue_free()

	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	_expect(main_scene != null, "main scene should load")
	if main_scene != null:
		root.size = Vector2i(1920, 1080)
		var main := main_scene.instantiate()
		main.set("save_path", OS.get_temp_dir().path_join("showcase_background_self_check.json"))
		main.set("broken_save_path", OS.get_temp_dir().path_join("showcase_background_self_check.broken.json"))
		root.add_child(main)
		await process_frame
		await process_frame
		var storefront := main.get_node("Root/Body/MainArea/StorefrontPanel") as Control
		var showcase := storefront.get_node("ShowcasePanel") as Control
		_expect(storefront.get_node_or_null("StorefrontBackground") == null, "storefront should not keep a separate background node")
		_expect(showcase.get_global_rect() == storefront.get_global_rect(), "showcase content should share the StorefrontPanel bounds")
		main.queue_free()

	var slot_scene := load(SLOT_SCENE_PATH) as PackedScene
	_expect(slot_scene != null, "showcase slot scene should load")
	if slot_scene != null:
		var slot := slot_scene.instantiate() as Button
		root.add_child(slot)
		await process_frame
		_expect(slot.self_modulate.a < 1.0 and slot.self_modulate.a >= 0.65, "showcase slot surface should be moderately translucent")
		var icon := slot.get_node("RecipeIcon") as TextureRect
		_expect(is_equal_approx(icon.self_modulate.a, 1.0), "showcase slot transparency should not fade child visuals")
		slot.queue_free()

	_finish()


func _has_property(target: Object, property_name: StringName) -> bool:
	for property in target.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_BACKGROUND_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_BACKGROUND_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
