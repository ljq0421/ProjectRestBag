# Device V1 Runtime Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every current `project-rest-new` runtime device-icon surface load the six device textures from `res://resources/ui/device_v1`.

**Architecture:** Preserve the centralized `DEVICE_ICON_DIRECTORY` and `_device_icon_texture(device_id)` loading path in `scripts/main_view.gd`. Strengthen the existing research input self-check so the same test covers complete device-file presence and proves the runtime helper returns textures whose resource paths are under `device_v1`.

**Tech Stack:** Godot 4.6.1, GDScript, PowerShell, Git

## Global Constraints

- Modify only `D:\Project\ProjectRest\project-rest-new`.
- Keep `resources/device_icons` in place; do not delete or overwrite its PNG or `.import` files.
- Use these exact device IDs and filenames: `round_pot`, `grinder`, `oven`, `chiller`, `griddle`, `mixer`.
- Do not change device unlock, research, growth, recipe, layout, scaling, or display-name behavior.
- Preserve all unrelated uncommitted changes in the working tree.
- Every Godot headless command must use `--log-file` with a writable path; never use `NUL`.

---

### Task 1: Route all runtime device icons through `device_v1`

**Files:**
- Modify: `tests/research_input_strip_self_check.gd:37-40`
- Modify: `tests/research_input_strip_self_check.gd:43-47`
- Modify: `scripts/main_view.gd:44`

**Interfaces:**
- Consumes: `const DEVICE_IDS: Array`, `MainScene.instantiate()`, and `main_view._device_icon_texture(device_id: String) -> Texture2D`
- Produces: `DEVICE_ICON_DIRECTORY = "res://resources/ui/device_v1"` and a focused regression contract for all six device IDs

- [ ] **Step 1: Write the failing runtime-path test**

Change `_test_device_icon_contract()` and extend `_test_input_strip_ui()` immediately after the instantiated view enters the tree:

```gdscript
func _test_device_icon_contract() -> void:
	for device_id in DEVICE_IDS:
		var path := "res://resources/ui/device_v1/%s.png" % device_id
		_expect(FileAccess.file_exists(ProjectSettings.globalize_path(path)), "device v1 icon should exist for %s" % device_id)
```

```gdscript
	var view = MainScene.instantiate()
	view.set("save_path", TEST_SAVE_PATH)
	root.add_child(view)
	await process_frame
	for device_id in DEVICE_IDS:
		var expected_path := "res://resources/ui/device_v1/%s.png" % device_id
		var device_texture := view.call("_device_icon_texture", device_id) as Texture2D
		_expect(device_texture != null, "runtime device icon should load for %s" % device_id)
		if device_texture != null:
			_expect(device_texture.resource_path == expected_path, "runtime device icon for %s should load from device_v1, got %s" % [device_id, device_texture.resource_path])
```

- [ ] **Step 2: Run the focused test and verify it fails for the old runtime route**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-device-v1-red.log" -s res://tests/research_input_strip_self_check.gd
```

Expected: nonzero exit with six failures containing `should load from device_v1` and actual paths under `res://resources/device_icons/`. The file-existence assertions for `resources/ui/device_v1` must pass.

- [ ] **Step 3: Switch the centralized runtime directory**

In `scripts/main_view.gd`, change only the device directory constant:

```gdscript
const DEVICE_ICON_DIRECTORY := "res://resources/ui/device_v1"
```

Do not change `_device_icon_texture()`, `_refresh_research_tool_slot()`, or `_make_research_tool_cell()`; both current UI surfaces already consume the centralized helper.

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-device-v1-green.log" -s res://tests/research_input_strip_self_check.gd
```

Expected: exit code `0` and output containing `RESEARCH_INPUT_STRIP_SELF_CHECK_PASS`.

- [ ] **Step 5: Audit active references and project parsing**

Run:

```powershell
rg -n --glob "*.gd" --glob "*.tscn" --glob "*.tres" --glob "*.json" "res://resources/device_icons|resources/device_icons" scripts scenes tests project.godot
```

Expected: no matches. Old-directory `.import` metadata and historical Markdown documents are intentionally outside this active-reference audit.

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-device-v1-project-load.log" --quit
```

Expected: exit code `0` with no GDScript parse or missing-resource errors.

Run:

```powershell
git diff --check
```

Expected: no output and exit code `0`.

- [ ] **Step 6: Review and commit the focused replacement**

Run:

```powershell
git diff -- scripts/main_view.gd tests/research_input_strip_self_check.gd resources/ui/device_v1
git status --short -- scripts/main_view.gd tests/research_input_strip_self_check.gd resources/ui/device_v1
```

Expected: the intended constant and test changes plus the six new `device_v1` PNG files and Godot-generated `.import` sidecars; unrelated pre-existing hunks in the two modified files may remain visible and must not be staged accidentally.

Stage the new assets and use an index-only patch for the exact code/test hunks so adjacent pre-existing working-tree changes are not included:

```powershell
git add -- resources/ui/device_v1
$deviceV1IndexPatch = @'
diff --git a/scripts/main_view.gd b/scripts/main_view.gd
--- a/scripts/main_view.gd
+++ b/scripts/main_view.gd
@@ -44 +44 @@
-const DEVICE_ICON_DIRECTORY := "res://resources/device_icons"
+const DEVICE_ICON_DIRECTORY := "res://resources/ui/device_v1"
diff --git a/tests/research_input_strip_self_check.gd b/tests/research_input_strip_self_check.gd
--- a/tests/research_input_strip_self_check.gd
+++ b/tests/research_input_strip_self_check.gd
@@ -39 +39 @@
-		var path := "res://resources/device_icons/%s.png" % device_id
+		var path := "res://resources/ui/device_v1/%s.png" % device_id
@@ -47,0 +48,6 @@
+	for device_id in DEVICE_IDS:
+		var expected_path := "res://resources/ui/device_v1/%s.png" % device_id
+		var device_texture := view.call("_device_icon_texture", device_id) as Texture2D
+		_expect(device_texture != null, "runtime device icon should load for %s" % device_id)
+		if device_texture != null:
+			_expect(device_texture.resource_path == expected_path, "runtime device icon for %s should load from device_v1, got %s" % [device_id, device_texture.resource_path])
'@
$deviceV1IndexPatch | git apply --cached --unidiff-zero
git diff --cached --check
git diff --cached -- scripts/main_view.gd tests/research_input_strip_self_check.gd resources/ui/device_v1
```

Expected: the staged diff contains only the six PNG files, their generated `.import` sidecars, the `DEVICE_ICON_DIRECTORY` change, and the focused device-path assertions. Then commit:

```powershell
git commit -m "feat: use device v1 icons at runtime"
```

Expected: the commit contains the six `device_v1` PNG files, their generated `.import` sidecars, the `DEVICE_ICON_DIRECTORY` change, and the focused device-path assertions only.
