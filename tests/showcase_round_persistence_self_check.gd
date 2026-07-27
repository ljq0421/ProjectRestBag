extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const SAVE_SYSTEM := preload("res://scripts/save_system.gd")
const SALE_SERVICE := preload("res://scripts/showcase_round_sale_service.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_round_persistence_self_check.json")


func _init() -> void:
	var state = GAME_STATE.new_game()
	state.business_round_id = 5
	state.active_business_round = {
		"round_id": 5,
		"phase": "running",
		"duration_ms": 30000,
		"elapsed_ms": 12000,
		"remaining_ms": 18000,
		"initial_item_states": {
			"sponge_cake": {
				"recipe_id": "sponge_cake",
				"anchor_cell": Vector2i(5, 5)
			}
		},
		"role_snapshot": {
			"sponge_cake": {
				"recipe_id": "sponge_cake",
				"anchor_cell": Vector2i(5, 5)
			}
		},
		"item_states": {
			"sponge_cake": {
				"recipe_id": "sponge_cake",
				"anchor_cell": Vector2i(5, 5),
				"duration_ms": 16000,
				"cycle_elapsed_ms": 12000,
				"fresh_stock": 2,
				"carried_stock": 0,
				"display_capacity": 3,
				"unit_price": 20,
				"waiting_for_refill": false
			}
		}
	}
	_expect_equal("running round saves", SAVE_SYSTEM.save_game(state, _save_path, 1000), true)
	var saved_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	var saved_round: Dictionary = saved_data.get("active_business_round", {})
	var saved_item: Dictionary = (saved_round.get("item_states", {}) as Dictionary).get("sponge_cake", {})
	var saved_anchor: Variant = saved_item.get("anchor_cell")
	_expect(
		saved_anchor is Array and saved_anchor.size() == 2 and int(saved_anchor[0]) == 5 and int(saved_anchor[1]) == 5,
		"round anchor should be saved as the JSON coordinate pair [5, 5]"
	)
	var restored = SAVE_SYSTEM.load_game(_save_path, _save_path + ".broken", 5000)
	_expect_equal("offline time does not advance showcase elapsed", int(restored.active_business_round.get("elapsed_ms", 0)), 12000)
	var restored_item: Dictionary = restored.active_business_round.get("item_states", {}).get("sponge_cake", {})
	_expect_equal("cycle progress survives save load", int(restored_item.get("cycle_elapsed_ms", 0)), 12000)
	_expect(restored_item.get("anchor_cell") is Vector2i and restored_item.get("anchor_cell") == Vector2i(5, 5), "item anchor should restore as Vector2i(5, 5)")
	var restored_initial: Dictionary = (restored.active_business_round.get("initial_item_states", {}) as Dictionary).get("sponge_cake", {})
	_expect(restored_initial.get("anchor_cell") is Vector2i and restored_initial.get("anchor_cell") == Vector2i(5, 5), "initial item anchor should restore as Vector2i(5, 5)")
	var restored_role: Dictionary = (restored.active_business_round.get("role_snapshot", {}) as Dictionary).get("sponge_cake", {})
	_expect(restored_role.get("anchor_cell") is Vector2i and restored_role.get("anchor_cell") == Vector2i(5, 5), "role anchor should restore as Vector2i(5, 5)")
	var refill_result: Dictionary = SALE_SERVICE.refill_item(restored.active_business_round.get("item_states", {}), "sponge_cake", 4, 12000)
	_expect_equal("restored legacy capacity does not cap refill", int(refill_result.get("accepted_amount", 0)), 4)
	_expect_equal("restored legacy capacity rejects no refill stock", int(refill_result.get("rejected_amount", -1)), 0)
	var refilled_item: Dictionary = (refill_result.get("item_states", {}) as Dictionary).get("sponge_cake", {})
	_expect_equal("restored legacy item receives the full refill", int(refilled_item.get("fresh_stock", 0)), 6)
	var sale_result: Dictionary = SALE_SERVICE.advance(refill_result.get("item_states", {}), 12000, 16000)
	_expect_equal("restored round completes sale after remaining four seconds", (sale_result.get("events", []) as Array).size(), 1)
	var sold_state: Dictionary = (sale_result.get("item_states", {}) as Dictionary).get("sponge_cake", {})
	_expect_equal("restored item continues selling after unlimited refill", int(sold_state.get("fresh_stock", 0)), 5)
	if not (sale_result.get("events", []) as Array).is_empty():
		var event_anchor: Variant = ((sale_result.get("events", []) as Array)[0] as Dictionary).get("anchor_cell")
		_expect(event_anchor is Vector2i and event_anchor == Vector2i(5, 5), "restored sale event should keep a Vector2i anchor")
	var legacy_restored = GAME_STATE.from_dict({
		"active_business_round": {
			"phase": "running",
			"item_states": {
				"legacy_item": {"anchor_cell": "(5, 5)"}
			},
			"role_snapshot": {
				"legacy_item": {"anchor_cell": "(5, 5)"}
			}
		}
	})
	var legacy_item: Dictionary = (legacy_restored.active_business_round.get("item_states", {}) as Dictionary).get("legacy_item", {})
	_expect(legacy_item.get("anchor_cell") is Vector2i and legacy_item.get("anchor_cell") == Vector2i(5, 5), "legacy string anchors should recover as Vector2i")
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	if FileAccess.file_exists(_save_path + ".tmp"):
		DirAccess.remove_absolute(_save_path + ".tmp")
	_finish()


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_ROUND_PERSISTENCE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_ROUND_PERSISTENCE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
