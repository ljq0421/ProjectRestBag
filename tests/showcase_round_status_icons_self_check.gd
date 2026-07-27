extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")
const ROUND_SERVICE := preload("res://scripts/business_round_service.gd")

const BOARD_PATH := "Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_round_status_icons_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var view = MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var weather_icon := view.get_node_or_null(BOARD_PATH + "/WeatherForecastIcon") as TextureRect
	var countdown_icon := view.get_node_or_null(BOARD_PATH + "/CountdownIcon") as Control
	var countdown_hand := view.get_node_or_null(BOARD_PATH + "/CountdownIcon/SecondHand") as TextureRect
	_expect("weather is rendered as an icon", weather_icon != null)
	_expect("countdown is rendered as an icon", countdown_icon != null)
	_expect("countdown icon exposes a rotating second hand", countdown_hand != null)
	_expect("countdown icon exposes a live tooltip updater", countdown_icon != null and countdown_icon.has_method("set_remaining_seconds"))
	_expect("old environment text node is removed", view.get_node_or_null(BOARD_PATH + "/EnvironmentLabel") == null)
	_expect("old countdown text node is removed", view.get_node_or_null(BOARD_PATH + "/CountdownLabel") == null)
	if weather_icon == null or countdown_icon == null or countdown_hand == null:
		_finish(view)
		return
	var alarm_face := view.get_node(BOARD_PATH + "/CountdownIcon/AlarmFace") as TextureRect
	var face_center := alarm_face.get_global_transform() * (alarm_face.size * 0.5)
	var hand_pivot := countdown_hand.get_global_transform() * countdown_hand.pivot_offset
	_expect("countdown hand pivot matches the alarm face center", hand_pivot.distance_to(face_center) < 0.01)

	var state = GAME_STATE.new_game()
	view.set("state", state)
	var round_state := ROUND_SERVICE.create_standard(1)
	round_state["environment"] = {
		"label": "甜食热潮｜晴朗天气",
		"weather": {"id": "clear_day", "label": "晴朗天气"},
		"total_price_pct": 8.0,
		"total_speed_pct": 3.0
	}
	round_state["hotspot"] = {"label": "入口甜点角"}
	state.active_business_round = round_state
	view.call("_refresh_showcase_round_controls")

	_expect("weather tooltip preserves the environment label", weather_icon.tooltip_text.find("甜食热潮｜晴朗天气") >= 0)
	_expect("weather tooltip preserves price and speed modifiers", weather_icon.tooltip_text.find("售价 +8%") >= 0 and weather_icon.tooltip_text.find("售速 +3%") >= 0)
	_expect("weather tooltip preserves the hotspot", weather_icon.tooltip_text.find("热点：入口甜点角") >= 0)
	_expect_equal("countdown tooltip starts at thirty seconds", countdown_icon.tooltip_text, "经营倒计时：30.0 秒")
	_expect_approx("thirty seconds starts at twelve", countdown_hand.rotation_degrees, 0.0)
	_expect_texture_suffix("clear weather icon", weather_icon, "weather_clear.svg")
	if countdown_icon.has_method("set_remaining_seconds"):
		var live_tooltip := countdown_icon.call("_make_custom_tooltip", countdown_icon.tooltip_text) as Label
		_expect("countdown creates a custom live tooltip label", live_tooltip != null)
		if live_tooltip != null:
			state.active_business_round["remaining_ms"] = 22500
			view.call("_refresh_showcase_round_controls")
			_expect_equal("visible countdown tooltip refreshes without leaving hover", live_tooltip.text, "经营倒计时：22.5 秒")
			live_tooltip.free()
		state.active_business_round["remaining_ms"] = 30000
		view.call("_refresh_showcase_round_controls")

	for weather_case in [
		{"id": "light_rain", "suffix": "weather_rain.svg"},
		{"id": "warm_day", "suffix": "weather_warm.svg"},
		{"id": "unknown", "suffix": "weather_generic.svg"}
	]:
		state.active_business_round["environment"]["weather"] = {"id": weather_case.id}
		view.call("_refresh_showcase_round_controls")
		_expect_texture_suffix("%s weather icon" % weather_case.id, weather_icon, weather_case.suffix)
	state.active_business_round["environment"] = {
		"id": "light_rain",
		"label": "小雨挑战",
		"total_price_pct": 4.0,
		"total_speed_pct": -3.0
	}
	view.call("_refresh_showcase_round_controls")
	_expect_texture_suffix("direct challenge weather id", weather_icon, "weather_rain.svg")

	state.active_business_round["phase"] = "running"
	for countdown_case in [
		{"remaining_ms": 22500, "degrees": 90.0},
		{"remaining_ms": 15000, "degrees": 180.0},
		{"remaining_ms": 7500, "degrees": 270.0},
		{"remaining_ms": 0, "degrees": 360.0}
	]:
		state.active_business_round["remaining_ms"] = countdown_case.remaining_ms
		view.call("_refresh_showcase_round_controls")
		_expect_approx(
			"%d milliseconds maps to the clock face" % countdown_case.remaining_ms,
			countdown_hand.rotation_degrees,
			countdown_case.degrees
		)
	_expect_equal("countdown tooltip reaches zero", countdown_icon.tooltip_text, "经营倒计时：0.0 秒")

	_finish(view)


func _expect_texture_suffix(label: String, icon: TextureRect, suffix: String) -> void:
	var path := icon.texture.resource_path if icon.texture != null else ""
	_expect(label, path.ends_with(suffix))


func _expect_approx(label: String, actual: float, expected: float) -> void:
	if not is_equal_approx(actual, expected):
		_fail("%s expected %.2f, got %.2f" % [label, expected, actual])


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _expect(label: String, condition: bool) -> void:
	if not condition:
		_fail(label)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish(view) -> void:
	if is_instance_valid(view):
		view.queue_free()
	for path in [_save_path, _save_path + ".tmp", _save_path + ".broken"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if _failures.is_empty():
		print("SHOWCASE_ROUND_STATUS_ICONS_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_ROUND_STATUS_ICONS_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
