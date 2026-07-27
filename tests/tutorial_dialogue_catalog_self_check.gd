extends SceneTree

const DIALOGUE_CATALOG_PATH := "res://scripts/tutorial_dialogue_catalog.gd"
const EXPECTED_STEPS := [
	"purchase",
	"output",
	"research",
	"craft",
	"list",
	"rulebook",
	"arrange",
	"business",
	"storefront",
	"complete",
]
const REQUIRED_FIELDS := ["step_name", "dialogue", "action_hint", "confirm_label"]

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect(ResourceLoader.exists(DIALOGUE_CATALOG_PATH), "tutorial dialogue catalog script should exist")
	if not ResourceLoader.exists(DIALOGUE_CATALOG_PATH):
		_finish()
		return
	var catalog_script := load(DIALOGUE_CATALOG_PATH) as GDScript
	_expect(catalog_script != null, "tutorial dialogue catalog should load")
	if catalog_script == null:
		_finish()
		return
	_expect(catalog_script.has_method("dialogue_for_step"), "tutorial dialogue catalog should expose dialogue_for_step")
	if not catalog_script.has_method("dialogue_for_step"):
		_finish()
		return

	for step in EXPECTED_STEPS:
		var entry: Dictionary = catalog_script.call("dialogue_for_step", step)
		for field in REQUIRED_FIELDS:
			_expect(not String(entry.get(field, "")).strip_edges().is_empty(), "%s dialogue should define %s" % [step, field])

	var completion: Dictionary = catalog_script.call("dialogue_for_step", "complete")
	_expect_equal("completion confirmation", String(completion.get("confirm_label", "")), "结束引导")
	var fallback: Dictionary = catalog_script.call("dialogue_for_step", "unknown_step")
	for field in REQUIRED_FIELDS:
		_expect(not String(fallback.get(field, "")).strip_edges().is_empty(), "unknown step fallback should define %s" % field)

	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		return
	_expect(false, "%s expected %s, got %s" % [label, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("TUTORIAL_DIALOGUE_CATALOG_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("TUTORIAL_DIALOGUE_CATALOG_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
