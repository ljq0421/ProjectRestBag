extends SceneTree

const FixtureService = preload(
	"res://scripts/challenge/stage11_playtest_fixture_service.gd"
)
const SaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const TelemetryService = preload(
	"res://scripts/challenge/stage11_playtest_telemetry_service.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	var fixtures = FixtureService.new()
	var telemetry = TelemetryService.new()
	var cohort_counts := {"new": 0, "mid": 0, "late": 0}
	var expected_counts := [6, 6, 30, 64, 112, 166]
	var profile_ids: Array[String] = fixtures.profile_ids()
	_expect(profile_ids.size() == 6, "stage 11 must define exactly six participant profiles")
	for index in range(profile_ids.size()):
		var profile_id := profile_ids[index]
		var fixture: Dictionary = fixtures.build_fixture(profile_id)
		var meta: Dictionary = fixture.get("meta", {})
		var definition: Dictionary = fixtures.profile_definition(profile_id)
		var cohort: String = String(definition.get("cohort", ""))
		cohort_counts[cohort] = int(cohort_counts.get(cohort, 0)) + 1
		_expect(
			(meta.get("unlocked_recipe_ids", []) as Array).size() == expected_counts[index],
			"%s should expose %d recipes" % [profile_id, expected_counts[index]]
		)
		var menu: Array = meta.get("active_menu_recipe_ids", [])
		_expect(menu.size() >= 4 and menu.size() <= 8, "%s menu must contain 4-8 recipes" % profile_id)
		for recipe_id in menu:
			_expect(
				(meta.get("unlocked_recipe_ids", []) as Array).has(recipe_id),
				"%s menu must be a subset of its collection" % profile_id
			)
		_expect(
			telemetry.validate(meta.get("stage11_playtest", {})).is_empty(),
			"%s telemetry state should validate" % profile_id
		)
		_expect(
			bool(SaveService.validate_current(fixture).get("ok", false)),
			"%s fixture must satisfy the current save contract" % profile_id
		)
	for cohort in cohort_counts:
		_expect(int(cohort_counts[cohort]) == 2, "stage 11 cohort %s must contain two profiles" % cohort)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("STAGE11_PLAYTEST_FIXTURE_SELF_CHECK_PASS profiles=6 cohorts=3")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
