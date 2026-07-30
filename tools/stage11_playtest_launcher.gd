extends SceneTree

const FixtureService = preload(
	"res://scripts/challenge/stage11_playtest_fixture_service.gd"
)
const SaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const TelemetryService = preload(
	"res://scripts/challenge/stage11_playtest_telemetry_service.gd"
)

const MAIN_SCENE_PATH := "res://scenes/challenge/challenge_main.tscn"
const SAVE_DIRECTORY := "user://stage11_playtests"

var _fixture_service = FixtureService.new()
var _telemetry_service = TelemetryService.new()


func _initialize() -> void:
	call_deferred("_launch")


func _launch() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var profile_id := String(options.get("profile", "")).to_upper()
	if profile_id not in _fixture_service.profile_ids():
		_fail(
			"阶段 11 测试档无效。请传入 --profile=P01 到 --profile=P06。"
		)
		return
	var save_directory := String(options.get("save_directory", SAVE_DIRECTORY))
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(save_directory)
	)
	if directory_error != OK:
		_fail("无法创建阶段 11 测试档目录：%s" % error_string(directory_error))
		return
	var save_path := "%s/%s.json" % [save_directory, profile_id.to_lower()]
	var should_reset := bool(options.get("reset", false))
	var should_complete := bool(options.get("complete", false))
	if should_reset and should_complete:
		_fail("--reset 与 --complete 不能同时使用。")
		return
	var save_data: Dictionary
	if should_complete and not FileAccess.file_exists(save_path):
		_fail("找不到要结束的测试档：%s" % save_path)
		return
	if should_reset or not FileAccess.file_exists(save_path):
		save_data = _fixture_service.build_fixture(profile_id)
	else:
		var loaded := SaveService.load_from_path(save_path)
		if not bool(loaded.get("ok", false)):
			_fail("无法载入 %s：%s" % [profile_id, String(loaded.get("error", ""))])
			return
		save_data = (loaded.get("data", {}) as Dictionary).duplicate(true)
	var meta: Dictionary = save_data.get("meta", {})
	if should_complete:
		save_data["meta"] = _telemetry_service.complete(meta)
		var completed_save := SaveService.save_to_path(save_path, save_data)
		if not bool(completed_save.get("ok", false)):
			_fail("无法结束 %s：%s" % [profile_id, String(completed_save.get("error", ""))])
			return
		print(
			"STAGE11_PLAYTEST_COMPLETED profile=%s save=%s"
			% [profile_id, ProjectSettings.globalize_path(save_path)]
		)
		quit(0)
		return
	meta = _telemetry_service.record(meta, "launcher_opened", {
		"reset": should_reset,
		"save_path": save_path
	})
	save_data["meta"] = meta
	var saved := SaveService.save_to_path(save_path, save_data)
	if not bool(saved.get("ok", false)):
		_fail("无法写入 %s：%s" % [profile_id, String(saved.get("error", ""))])
		return
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("无法载入阶段 11 主场景：%s" % MAIN_SCENE_PATH)
		return
	var main := packed.instantiate()
	main.set("save_path", save_path)
	root.add_child(main)
	DisplayServer.window_set_title(
		"Project Rest Two - Stage 11 %s (%s)"
		% [profile_id, String(_fixture_service.profile_definition(profile_id).get("cohort", ""))]
	)
	print(
		"STAGE11_PLAYTEST_READY profile=%s save=%s reset=%s"
		% [profile_id, ProjectSettings.globalize_path(save_path), should_reset]
	)
	if bool(options.get("smoke", false)):
		for _frame in range(8):
			await process_frame
		print("STAGE11_PLAYTEST_LAUNCHER_SMOKE_PASS profile=%s" % profile_id)
		quit(0)


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var result := {
		"profile": "",
		"reset": false,
		"smoke": false,
		"complete": false,
		"save_directory": SAVE_DIRECTORY
	}
	for argument in arguments:
		if argument.begins_with("--profile="):
			result["profile"] = argument.trim_prefix("--profile=")
		elif argument == "--reset":
			result["reset"] = true
		elif argument == "--smoke":
			result["smoke"] = true
		elif argument == "--complete":
			result["complete"] = true
		elif argument.begins_with("--save-dir="):
			result["save_directory"] = argument.trim_prefix("--save-dir=")
	return result


func _fail(message: String) -> void:
	push_error(message)
	printerr("STAGE11_PLAYTEST_LAUNCHER_ERROR %s" % message)
	quit(2)
