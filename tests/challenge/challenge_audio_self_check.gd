extends SceneTree

const MANIFEST_PATH := "res://resources/audio/manifest.json"
const EXPECTED_CUES := [
	&"ui_confirm",
	&"page_transition",
	&"recipe_place",
	&"recipe_move",
	&"recipe_rotate",
	&"action_rejected",
	&"battle_start",
	&"sale",
	&"relation_bonus",
	&"demand_success",
	&"demand_failure",
	&"victory",
	&"defeat",
	&"upgrade_unlock",
	&"research_unlock",
	&"reward_claim",
]

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var manifest := _load_json(MANIFEST_PATH)
	_expect(
		String(manifest.get("generator", "")) == "tools/generate_audio.py",
		"manifest should identify the repository generator"
	)
	_expect(
		(manifest.get("third_party_samples", []) as Array).is_empty(),
		"manifest should explicitly record that no third-party samples are used"
	)
	var assets: Array = manifest.get("assets", [])
	_expect(assets.size() == 15, "audio pack should contain thirteen SFX and two music tracks")
	var sfx_count := 0
	var music_count := 0
	for value in assets:
		if not value is Dictionary:
			_fail("every manifest asset should be a dictionary")
			continue
		var asset: Dictionary = value
		var path := "res://" + String(asset.get("path", ""))
		_expect(FileAccess.file_exists(path), "manifest asset should exist: %s" % path)
		_expect(
			FileAccess.get_sha256(path) == String(asset.get("sha256", "")),
			"manifest digest should match: %s" % path
		)
		_expect(load(path) is AudioStream, "Godot should import audio stream: %s" % path)
		if String(asset.get("kind", "")) == "sfx":
			sfx_count += 1
		elif String(asset.get("kind", "")) == "music":
			music_count += 1
	_expect(sfx_count == 13, "audio pack should provide thirteen SFX files")
	_expect(music_count == 2, "audio pack should provide planning and battle music")

	_expect(AudioServer.get_bus_index(&"Music") >= 0, "Music bus should load")
	_expect(AudioServer.get_bus_index(&"SFX") >= 0, "SFX bus should load")
	var project_text := FileAccess.get_file_as_string("res://project.godot")
	_expect(
		project_text.find("AudioService=\"*res://scripts/audio/audio_service.gd\"") >= 0,
		"AudioService should be registered as an autoload"
	)

	var audio_service = root.get_node_or_null("AudioService")
	_expect(audio_service != null, "AudioService autoload should instantiate")
	if audio_service == null:
		_finish()
		return
	var registered: Array[StringName] = audio_service.registered_cue_ids()
	for cue_id: StringName in EXPECTED_CUES:
		_expect(registered.has(cue_id), "AudioService should register cue: %s" % cue_id)
	var emitted_cues: Array[StringName] = []
	audio_service.cue_started.connect(
		func(cue_id: StringName) -> void: emitted_cues.append(cue_id),
		CONNECT_ONE_SHOT
	)
	_expect(audio_service.play_cue(&"recipe_place"), "known cue should play")
	await process_frame
	_expect(emitted_cues == [&"recipe_place"], "known cue should emit semantic cue id")
	_expect(not registered.has(&"missing_cue"), "unknown cue should stay unregistered")

	audio_service.play_music(&"hub")
	await process_frame
	_expect(
		audio_service.current_music_context() == &"hub",
		"hub should select planning music"
	)
	audio_service.play_music(&"battle")
	await process_frame
	_expect(
		audio_service.current_music_context() == &"battle",
		"battle should select battle music"
	)

	var main_text := FileAccess.get_file_as_string(
		"res://scripts/challenge/challenge_main_view.gd"
	)
	var battle_text := FileAccess.get_file_as_string(
		"res://scripts/challenge/ui/challenge_battle_view.gd"
	)
	for required_hook in [
		"&\"battle_start\"",
		"&\"victory\"",
		"&\"defeat\"",
		"&\"recipe_place\"",
		"play_music(StringName(page))",
	]:
		_expect(main_text.find(required_hook) >= 0, "main flow should keep audio hook: %s" % required_hook)
	for required_hook in [
		"&\"sale\"",
		"&\"relation_bonus\"",
		"&\"demand_success\"",
		"&\"demand_failure\"",
	]:
		_expect(
			battle_text.find(required_hook) >= 0,
			"battle feedback should keep audio hook: %s" % required_hook
		)
	_expect(
		battle_text.find("if animate:\n\t\t\t\tAudioService.play_cue") >= 0,
		"restoring historical battle events should not replay their SFX"
	)
	audio_service.stop_all_audio()
	await process_frame
	_finish()


func _load_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	_fail("could not parse JSON dictionary: %s" % path)
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_AUDIO_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
