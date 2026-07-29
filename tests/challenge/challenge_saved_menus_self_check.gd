extends SceneTree

const MenuService = preload("res://scripts/challenge/challenge_menu_service.gd")
var failures: Array[String] = []

func _init() -> void:
	var ids: Array[String] = ["a", "b", "c", "d", "e"]
	var defs := {}
	for id in ids:
		defs[id] = {}
	var service = MenuService.new()
	var meta := {"saved_menus": []}
	for index in range(3):
		var saved := service.save_preset(meta, "p%d" % index, "方案%d" % index, ids.slice(0, 4), ids, defs)
		_expect(bool(saved.get("applied", false)), "first three presets should save")
		meta = saved.get("meta", {})
	var fourth := service.save_preset(meta, "p3", "第四套", ids.slice(0, 4), ids, defs)
	_expect(not bool(fourth.get("applied", true)), "fourth preset should be rejected")
	var loaded := service.load_preset(meta, "p1", ids, defs)
	_expect(bool(loaded.get("applied", false)), "saved preset should load")
	_expect(loaded.get("recipe_ids", []) == ["a", "b", "c", "d"], "loaded preset should retain order")
	_finish()

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _finish() -> void:
	if failures.is_empty(): print("CHALLENGE_SAVED_MENUS_SELF_CHECK_PASS"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)
