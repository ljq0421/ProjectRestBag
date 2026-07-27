class_name ProductionZoneShell
extends Control

const IDLE_LIGHT_ALPHA := 0.12
const ACTIVE_LIGHT_ALPHA := 1.0

@onready var warm_light: Control = $WarmLight
@onready var steam_effect: Control = $SteamEffect
@onready var steam_timer: Timer = $SteamTimer

var _activity_active := false
var _activity_transitions := 0
var _completion_pulses := 0
var _warm_tween: Tween
var _steam_tween: Tween
var _steam_origin := Vector2.ZERO


func _ready() -> void:
	_steam_origin = steam_effect.position
	warm_light.visible = true
	warm_light.modulate.a = IDLE_LIGHT_ALPHA
	steam_effect.visible = false
	steam_effect.modulate.a = 0.0
	var steam_handler := Callable(self, "_play_steam_once")
	if not steam_timer.timeout.is_connected(steam_handler):
		steam_timer.timeout.connect(steam_handler)


func set_activity_state(active: bool) -> void:
	if active == _activity_active:
		return
	_activity_active = active
	_activity_transitions += 1
	_fade_warm_light(ACTIVE_LIGHT_ALPHA if active else IDLE_LIGHT_ALPHA)
	if active:
		steam_timer.start()
		_play_steam_once()
	else:
		steam_timer.stop()
		_stop_steam()


func pulse_completion() -> void:
	_completion_pulses += 1
	if _warm_tween != null and _warm_tween.is_valid():
		_warm_tween.kill()
	var resting_alpha := ACTIVE_LIGHT_ALPHA if _activity_active else IDLE_LIGHT_ALPHA
	warm_light.visible = true
	warm_light.modulate = Color(1.0, 1.0, 1.0, resting_alpha)
	_warm_tween = create_tween()
	_warm_tween.tween_property(
		warm_light,
		"modulate",
		Color(1.18, 1.08, 0.88, 1.0),
		0.16
	)
	_warm_tween.tween_property(
		warm_light,
		"modulate",
		Color(1.0, 1.0, 1.0, resting_alpha),
		0.34
	)


func activity_transition_count() -> int:
	return _activity_transitions


func completion_pulse_count() -> int:
	return _completion_pulses


func is_activity_active() -> bool:
	return _activity_active


func _fade_warm_light(target_alpha: float) -> void:
	if _warm_tween != null and _warm_tween.is_valid():
		_warm_tween.kill()
	warm_light.visible = true
	_warm_tween = create_tween()
	_warm_tween.tween_property(warm_light, "modulate:a", target_alpha, 0.28)


func _play_steam_once() -> void:
	if not _activity_active:
		return
	if _steam_tween != null and _steam_tween.is_valid():
		_steam_tween.kill()
	steam_effect.visible = true
	steam_effect.position = _steam_origin
	steam_effect.modulate.a = 0.0
	_steam_tween = create_tween()
	_steam_tween.tween_property(steam_effect, "modulate:a", 0.58, 0.32)
	_steam_tween.parallel().tween_property(
		steam_effect,
		"position:y",
		_steam_origin.y - 4.0,
		0.32
	)
	_steam_tween.tween_property(steam_effect, "modulate:a", 0.0, 0.72)
	_steam_tween.parallel().tween_property(
		steam_effect,
		"position:y",
		_steam_origin.y - 14.0,
		0.72
	)
	_steam_tween.finished.connect(_finish_steam_once, CONNECT_ONE_SHOT)


func _finish_steam_once() -> void:
	steam_effect.visible = false
	steam_effect.position = _steam_origin


func _stop_steam() -> void:
	if _steam_tween != null and _steam_tween.is_valid():
		_steam_tween.kill()
	steam_effect.visible = false
	steam_effect.position = _steam_origin
	steam_effect.modulate.a = 0.0
