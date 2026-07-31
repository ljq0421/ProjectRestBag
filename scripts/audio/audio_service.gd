extends Node

signal cue_started(cue_id: StringName)
signal music_context_changed(context: StringName)

const SFX_POOL_SIZE := 10
const MUSIC_FADE_SECONDS := 0.45
const SILENT_DB := -60.0

const CUES := {
	&"ui_confirm": {
		"path": "res://resources/audio/sfx/ui_confirm.wav",
		"volume_db": -5.0,
		"pitch_min": 0.98,
		"pitch_max": 1.02,
		"cooldown_ms": 45,
	},
	&"page_transition": {
		"path": "res://resources/audio/sfx/page_transition.wav",
		"volume_db": -7.0,
		"pitch_min": 0.99,
		"pitch_max": 1.01,
		"cooldown_ms": 120,
	},
	&"recipe_place": {
		"path": "res://resources/audio/sfx/recipe_place.wav",
		"volume_db": -3.0,
		"pitch_min": 0.96,
		"pitch_max": 1.04,
		"cooldown_ms": 25,
	},
	&"recipe_move": {
		"path": "res://resources/audio/sfx/recipe_place.wav",
		"volume_db": -5.0,
		"pitch_min": 1.06,
		"pitch_max": 1.10,
		"cooldown_ms": 25,
	},
	&"recipe_rotate": {
		"path": "res://resources/audio/sfx/recipe_rotate.wav",
		"volume_db": -4.0,
		"pitch_min": 0.98,
		"pitch_max": 1.03,
		"cooldown_ms": 25,
	},
	&"action_rejected": {
		"path": "res://resources/audio/sfx/action_rejected.wav",
		"volume_db": -3.0,
		"pitch_min": 0.99,
		"pitch_max": 1.01,
		"cooldown_ms": 120,
	},
	&"battle_start": {
		"path": "res://resources/audio/sfx/battle_start.wav",
		"volume_db": -1.0,
		"pitch_min": 0.995,
		"pitch_max": 1.005,
		"cooldown_ms": 500,
	},
	&"sale": {
		"path": "res://resources/audio/sfx/sale.wav",
		"volume_db": -6.0,
		"pitch_min": 0.96,
		"pitch_max": 1.06,
		"cooldown_ms": 55,
	},
	&"relation_bonus": {
		"path": "res://resources/audio/sfx/relation_bonus.wav",
		"volume_db": -3.0,
		"pitch_min": 0.98,
		"pitch_max": 1.03,
		"cooldown_ms": 140,
	},
	&"demand_success": {
		"path": "res://resources/audio/sfx/demand_success.wav",
		"volume_db": -3.0,
		"pitch_min": 0.99,
		"pitch_max": 1.02,
		"cooldown_ms": 180,
	},
	&"demand_failure": {
		"path": "res://resources/audio/sfx/demand_failure.wav",
		"volume_db": -2.0,
		"pitch_min": 0.99,
		"pitch_max": 1.01,
		"cooldown_ms": 180,
	},
	&"victory": {
		"path": "res://resources/audio/sfx/victory.wav",
		"volume_db": 0.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
		"cooldown_ms": 800,
	},
	&"defeat": {
		"path": "res://resources/audio/sfx/defeat.wav",
		"volume_db": 0.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
		"cooldown_ms": 800,
	},
	&"upgrade_unlock": {
		"path": "res://resources/audio/sfx/upgrade_unlock.wav",
		"volume_db": -1.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
		"cooldown_ms": 250,
	},
	&"research_unlock": {
		"path": "res://resources/audio/sfx/upgrade_unlock.wav",
		"volume_db": -1.0,
		"pitch_min": 1.05,
		"pitch_max": 1.05,
		"cooldown_ms": 250,
	},
	&"reward_claim": {
		"path": "res://resources/audio/sfx/upgrade_unlock.wav",
		"volume_db": 0.0,
		"pitch_min": 1.10,
		"pitch_max": 1.10,
		"cooldown_ms": 250,
	},
}

const MUSIC_BY_CONTEXT := {
	&"hub": "res://resources/audio/music/planning_loop.wav",
	&"preparation": "res://resources/audio/music/planning_loop.wav",
	&"upgrade": "res://resources/audio/music/planning_loop.wav",
	&"research": "res://resources/audio/music/planning_loop.wav",
	&"menu": "res://resources/audio/music/planning_loop.wav",
	&"summary": "res://resources/audio/music/planning_loop.wav",
	&"battle": "res://resources/audio/music/battle_loop.wav",
}

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_player := 0
var _music_context: StringName = &""
var _last_played_at: Dictionary = {}
var _stream_cache: Dictionary = {}
var _pitch_rng := RandomNumberGenerator.new()
var _music_tween: Tween


func _ready() -> void:
	_pitch_rng.seed = Time.get_ticks_usec() ^ get_instance_id()
	for index in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%02d" % index
		player.bus = &"SFX"
		add_child(player)
		_sfx_players.append(player)
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % index
		player.bus = &"Music"
		player.volume_db = SILENT_DB
		add_child(player)
		_music_players.append(player)


func _exit_tree() -> void:
	stop_all_audio()


func play_cue(cue_id: StringName) -> bool:
	if not CUES.has(cue_id):
		push_warning("Unknown audio cue: %s" % cue_id)
		return false
	var cue: Dictionary = CUES[cue_id]
	var now := Time.get_ticks_msec()
	var cooldown_ms := int(cue.get("cooldown_ms", 0))
	var last_played := int(_last_played_at.get(cue_id, -cooldown_ms - 1))
	if cooldown_ms > 0 and now - last_played < cooldown_ms:
		return false
	var player := _find_sfx_player()
	if player == null:
		return false
	var stream := _load_stream(String(cue.get("path", "")))
	if stream == null:
		return false
	player.stream = stream
	player.volume_db = float(cue.get("volume_db", 0.0))
	player.pitch_scale = _pitch_rng.randf_range(
		float(cue.get("pitch_min", 1.0)),
		float(cue.get("pitch_max", 1.0))
	)
	player.play()
	_last_played_at[cue_id] = now
	cue_started.emit(cue_id)
	return true


func play_music(context: StringName) -> bool:
	if not MUSIC_BY_CONTEXT.has(context):
		push_warning("Unknown music context: %s" % context)
		return false
	var next_stream := _load_stream(String(MUSIC_BY_CONTEXT[context]), true)
	if next_stream == null:
		return false
	var active_player := _music_players[_active_music_player]
	if _music_context == context and active_player.playing:
		return false
	if active_player.playing and active_player.stream == next_stream:
		_music_context = context
		music_context_changed.emit(context)
		return false
	var next_index := 1 - _active_music_player
	var next_player := _music_players[next_index]
	next_player.stop()
	next_player.stream = next_stream
	next_player.volume_db = SILENT_DB
	next_player.play()
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_tween.tween_property(next_player, "volume_db", -4.0, MUSIC_FADE_SECONDS)
	if active_player.playing:
		_music_tween.tween_property(active_player, "volume_db", SILENT_DB, MUSIC_FADE_SECONDS)
		_music_tween.chain().tween_callback(active_player.stop)
	_active_music_player = next_index
	_music_context = context
	music_context_changed.emit(context)
	return true


func current_music_context() -> StringName:
	return _music_context


func registered_cue_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for cue_id in CUES:
		result.append(cue_id)
	result.sort()
	return result


func set_bus_volume_linear(bus_name: StringName, linear_volume: float) -> bool:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return false
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(clampf(linear_volume, 0.0, 1.0))
		if linear_volume > 0.0
		else SILENT_DB
	)
	return true


func set_bus_muted(bus_name: StringName, muted: bool) -> bool:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return false
	AudioServer.set_bus_mute(bus_index, muted)
	return true


func stop_all_audio() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	for player in _music_players:
		player.stop()
		player.stream = null
	for player in _sfx_players:
		player.stop()
		player.stream = null
	_stream_cache.clear()


func _find_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	var oldest := _sfx_players[0]
	for player in _sfx_players:
		if player.get_playback_position() > oldest.get_playback_position():
			oldest = player
	return oldest


func _enable_music_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func _load_stream(path: String, loop := false) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path] as AudioStream
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Could not load audio stream: %s" % path)
		return null
	if loop:
		_enable_music_loop(stream)
	_stream_cache[path] = stream
	return stream
