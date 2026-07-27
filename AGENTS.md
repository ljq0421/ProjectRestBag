## Project Scope

This file applies to `D:\Project\ProjectRest` and its child project
`D:\Project\ProjectRest\project-rest-new`.

For imagegen-heavy work, avoid generating many images in one Codex thread.
Generated image payloads can bloat session JSONL files and cause Codex Desktop
to stall or reconnect. Split image batches into small threads and use saved
file paths for follow-up processing.

## Godot Headless Tests In Codex

When running Godot headless tests from Codex sandbox, always pass `--log-file`
to a writable path. Godot 4.6.1 can crash while opening the default
`user://logs/godot*.log` under sandbox restrictions.

Use a writable temp path by default:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  -s res://tests/mvp_self_check.gd
```

For one-off commands, replace only the script path:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  -s res://tests/your_self_check.gd
```

Do not use `--log-file NUL`; Godot treats `NUL` as a reserved Windows device
name and may still crash.

Run commands from the directory that contains `project.godot`, usually:

```powershell
cd D:\Project\ProjectRest\project-rest
```

If a test reports `File not found`, first verify the `res://tests/...` file
exists before debugging game logic.

## Optional Persistent Fix

If editing `addons/godot_ai/runtime/game_helper.gd`, keep game logger attachment
behind an active debugger check so headless sandbox runs do not touch Godot's
default `user://logs` path:

```gdscript
# ponytail: headless sandbox can crash when Godot's Logger opens user://logs;
# attach only when a live debugger can consume the logs.
if EngineDebugger.is_active() and ClassDB.class_exists("Logger") and OS.has_method("add_logger"):
	var logger_script := LoggerLoader.build(LoggerLoader.GAME_LOGGER_PATH)
	if logger_script != null:
		_logger = logger_script.new()
		OS.call("add_logger", _logger)
		_logger_attached = true
```

After updating `addons/godot_ai`, re-check this block because plugin updates may
overwrite local edits.
