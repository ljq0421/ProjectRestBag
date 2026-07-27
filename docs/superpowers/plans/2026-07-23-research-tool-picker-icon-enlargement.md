# Research Tool Picker Icon Enlargement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render six `168×168` research-tool cards whose device textures fill each card, hide in-card names, and expose tool names through hover Tooltips inside a `720×504` picker.

**Architecture:** Keep dynamic card construction in `scripts/main_view.gd` and extend the existing slot-visual helper with a `show_name` flag. Preserve the shared scene and make the picker call request full-card imagery without a visible name layer, while the selected main tool slot and material slots retain their current defaults.

**Tech Stack:** Godot 4.6.1, GDScript, Godot `.tscn`, PowerShell, Git

## Global Constraints

- Modify only `D:\Project\ProjectRest\project-rest-new`.
- Picker card size is exactly `168×168`; picker size is exactly `720×504`.
- Keep three columns, two rows, `16px` card gaps, `64px` horizontal margins, and `48px` vertical margins.
- Picker textures fill their cards with `STRETCH_KEEP_ASPECT_CENTERED`; do not crop, stretch, edit, or replace `device_v1` PNG files.
- Hide picker-card `NameBackdrop` and `NameLabel`; set each card Tooltip to the exact tool name.
- Keep the selected main tool slot at `104×104` with its visible name layer and current Tooltip.
- Preserve all unrelated uncommitted changes in `workbench_pages.tscn`, `main_view.gd`, and `research_input_strip_self_check.gd`.
- Every Godot headless command must use a writable `--log-file`; never use `NUL`.

---

### Task 1: Enlarge picker cards and make their images name-free

**Files:**
- Modify: `scripts/main_view.gd:73-74`
- Modify: `scripts/main_view.gd:4292-4312`
- Modify: `scripts/main_view.gd:4437-4447`
- Modify: `scripts/main_view.gd:4506-4513`
- Modify: `scenes/ui/pages/workbench_pages.tscn:52-54`
- Test: `tests/research_input_strip_self_check.gd:125-170`

**Interfaces:**
- Consumes: `_set_research_input_slot_visual(button: Button, texture: Texture2D, display_name: String, empty: bool, fill_slot: bool = false, show_name: bool = true) -> void`
- Produces: `RESEARCH_TOOL_PICKER_CELL_SIZE = Vector2(168, 168)`, `RESEARCH_TOOL_PICKER_POPUP_SIZE = Vector2i(720, 504)`, full-card picker textures, hidden picker name layers, and exact-name Tooltips

- [ ] **Step 1: Write the failing picker contract**

Update the popup section of `_test_input_strip_ui()` to require the approved geometry and visual behavior:

```gdscript
	_expect(picker != null and picker.visible, "pressing ToolSlot should open the enlarged tool picker")
	if picker != null:
		_expect(picker.size == Vector2i(720, 504), "tool picker should open at 720x504, got %s" % str(picker.size))
		var expected_picker_position := (Vector2i(view.get_viewport().get_visible_rect().size) - picker.size) / 2
		_expect(picker.position == expected_picker_position, "tool picker should remain centered after enforcing its exact size")
		var picker_grid := picker.get_node_or_null("ToolPickerMargin/ToolPickerBox/ToolPickerGrid") as GridContainer
		_expect(picker_grid != null and picker_grid.columns == 3, "tool picker should keep a three-column grid")
		if picker_grid != null:
			_expect(picker_grid.get_child_count() == 6, "six unlocked devices should produce six tool cards")
			for child_value in picker_grid.get_children():
				var tool_button := child_value as Button
				_expect(tool_button != null and tool_button.custom_minimum_size == Vector2(168, 168) and tool_button.size == Vector2(168, 168), "every tool picker card should render at 168x168")
				if tool_button == null:
					continue
				var picker_tool_icon := tool_button.get_node_or_null("Icon") as TextureRect
				var picker_tool_backdrop := tool_button.get_node_or_null("NameBackdrop") as ColorRect
				var picker_tool_name := tool_button.get_node_or_null("NameLabel") as Label
				_expect(picker_tool_icon != null and _fills_parent(picker_tool_icon), "every picker device image should fill its 168x168 card")
				_expect(picker_tool_icon != null and picker_tool_icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "picker device images should preserve aspect ratio without cropping")
				_expect(picker_tool_backdrop != null and not picker_tool_backdrop.visible, "picker cards should hide their bottom name backdrop")
				_expect(picker_tool_name != null and not picker_tool_name.visible, "picker cards should hide their visible device name")
				if picker_tool_name != null:
					_expect(tool_button.tooltip_text == picker_tool_name.text, "picker card Tooltip should equal its device name")
		var mixer_button := _find_button_by_meta(picker, "tool_id", "mixer")
		_expect(mixer_button != null, "tool picker should list unlocked devices")
		if mixer_button != null:
			var mixer_name := mixer_button.get_node_or_null("NameLabel") as Label
			_expect(mixer_name != null and not mixer_name.visible and mixer_name.text == "搅拌机", "tool picker should hide the visible mixer name while retaining its exact text for the Tooltip")
```

Keep the existing assertions that the selected main tool slot is `104×104`, fills its own icon bounds, and shows its name layer.

- [ ] **Step 2: Run the focused test and verify the new contract fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-tool-icons-red.log" -s res://tests/research_input_strip_self_check.gd
```

Expected: nonzero exit with failures for the old `720×408` popup, `168×120` cards, non-filling `52×52` icons, visible name layers, and action-sentence Tooltips.

- [ ] **Step 3: Implement the exact picker geometry and name visibility control**

Change the constants in `scripts/main_view.gd`:

```gdscript
const RESEARCH_TOOL_PICKER_CELL_SIZE := Vector2(168, 168)
const RESEARCH_TOOL_PICKER_POPUP_SIZE := Vector2i(720, 504)
```

Extend the helper without changing existing callers' behavior:

```gdscript
func _set_research_input_slot_visual(button: Button, texture: Texture2D, display_name: String, empty: bool, fill_slot: bool = false, show_name: bool = true) -> void:
	button.text = ""
	var icon := button.get_node("Icon") as TextureRect
	var plus_label := button.get_node("PlusLabel") as Label
	var name_backdrop := button.get_node("NameBackdrop") as ColorRect
	var name_label := button.get_node("NameLabel") as Label
	if fill_slot:
		icon.anchor_left = 0.0
		icon.anchor_top = 0.0
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = 0.0
		icon.offset_top = 0.0
		icon.offset_right = 0.0
		icon.offset_bottom = 0.0
	icon.texture = texture
	icon.visible = not empty and texture != null
	plus_label.visible = empty
	name_backdrop.visible = not empty and show_name
	name_label.text = display_name
	name_label.visible = not empty and show_name
```

Make each picker card fill its image bounds, hide the name layer, and expose the exact name through its Tooltip:

```gdscript
func _make_research_tool_cell(entry: Dictionary) -> Button:
	var tool_id := String(entry.get("id", ""))
	var tool_name := String(entry.get("name", tool_id))
	var button := ResearchInputSlotScene.instantiate() as Button
	button.custom_minimum_size = RESEARCH_TOOL_PICKER_CELL_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_set_research_input_slot_visual(button, _device_icon_texture(tool_id), tool_name, false, true, false)
	button.tooltip_text = tool_name
	button.set_meta("tool_id", tool_id)
	button.pressed.connect(_on_research_tool_cell_pressed.bind(tool_id))
	return button
```

Keep the popup centered at its enforced runtime size:

```gdscript
func _on_research_tool_slot_pressed() -> void:
	_fill_research_tool_picker()
	research_tool_picker_popup.popup_centered()
	research_tool_picker_popup.size = RESEARCH_TOOL_PICKER_POPUP_SIZE
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	research_tool_picker_popup.position = (viewport_size - RESEARCH_TOOL_PICKER_POPUP_SIZE) / 2
```

Update the scene-declared size in `scenes/ui/pages/workbench_pages.tscn`:

```ini
[node name="ResearchToolPickerPopup" type="PopupPanel" parent="PrimaryList/ResearchInputBar"]
size = Vector2i(720, 504)
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-tool-icons-green.log" -s res://tests/research_input_strip_self_check.gd
```

Expected: exit code `0` and output containing `RESEARCH_INPUT_STRIP_SELF_CHECK: PASS`.

- [ ] **Step 5: Run broader verification**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-tool-icons-mvp.log" -s res://tests/mvp_self_check.gd
```

Expected: exit code `0` and output containing `MVP_SELF_CHECK_PASS`.

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-tool-icons-project-load.log" --quit
```

Expected: exit code `0` with no GDScript parse or missing-resource errors.

Run:

```powershell
git diff --check
```

Expected: no patch-format errors and exit code `0`.

- [ ] **Step 6: Commit only the picker enlargement contract**

Inspect all overlapping files first:

```powershell
git diff -- scripts/main_view.gd scenes/ui/pages/workbench_pages.tscn tests/research_input_strip_self_check.gd
git status --short -- scripts/main_view.gd scenes/ui/pages/workbench_pages.tscn tests/research_input_strip_self_check.gd
```

Build and apply this index-only patch against `HEAD`; it contains the complete focused implementation while excluding adjacent working-tree changes:

```powershell
$pickerIndexPatch = @'
diff --git a/scripts/main_view.gd b/scripts/main_view.gd
--- a/scripts/main_view.gd
+++ b/scripts/main_view.gd
@@ -73 +73,2 @@
-const RESEARCH_TOOL_PICKER_CELL_SIZE := Vector2(112, 80)
+const RESEARCH_TOOL_PICKER_CELL_SIZE := Vector2(168, 168)
+const RESEARCH_TOOL_PICKER_POPUP_SIZE := Vector2i(720, 504)
@@ -4286 +4287 @@
-func _set_research_input_slot_visual(button: Button, texture: Texture2D, display_name: String, empty: bool, fill_slot: bool = false) -> void:
+func _set_research_input_slot_visual(button: Button, texture: Texture2D, display_name: String, empty: bool, fill_slot: bool = false, show_name: bool = true) -> void:
@@ -4304 +4305 @@
-	name_backdrop.visible = not empty
+	name_backdrop.visible = not empty and show_name
@@ -4306 +4307 @@
-	name_label.visible = not empty
+	name_label.visible = not empty and show_name
@@ -4444,11 +4445,12 @@
-func _make_research_tool_cell(entry: Dictionary) -> Button:
-	var tool_id := String(entry.get("id", ""))
-	var button := ResearchInputSlotScene.instantiate() as Button
-	button.custom_minimum_size = RESEARCH_TOOL_PICKER_CELL_SIZE
-	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
-	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
-	_set_research_input_slot_visual(button, _device_icon_texture(tool_id), String(entry.get("name", tool_id)), false)
-	button.tooltip_text = "选择%s作为研发工具。" % String(entry.get("name", tool_id))
-	button.set_meta("tool_id", tool_id)
-	button.pressed.connect(_on_research_tool_cell_pressed.bind(tool_id))
-	return button
+func _make_research_tool_cell(entry: Dictionary) -> Button:
+	var tool_id := String(entry.get("id", ""))
+	var tool_name := String(entry.get("name", tool_id))
+	var button := ResearchInputSlotScene.instantiate() as Button
+	button.custom_minimum_size = RESEARCH_TOOL_PICKER_CELL_SIZE
+	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
+	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
+	_set_research_input_slot_visual(button, _device_icon_texture(tool_id), tool_name, false, true, false)
+	button.tooltip_text = tool_name
+	button.set_meta("tool_id", tool_id)
+	button.pressed.connect(_on_research_tool_cell_pressed.bind(tool_id))
+	return button
@@ -4515 +4517,4 @@
-	research_tool_picker_popup.popup_centered(Vector2i(420, 210))
+	research_tool_picker_popup.popup_centered()
+	research_tool_picker_popup.size = RESEARCH_TOOL_PICKER_POPUP_SIZE
+	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
+	research_tool_picker_popup.position = (viewport_size - RESEARCH_TOOL_PICKER_POPUP_SIZE) / 2
diff --git a/scenes/ui/pages/workbench_pages.tscn b/scenes/ui/pages/workbench_pages.tscn
--- a/scenes/ui/pages/workbench_pages.tscn
+++ b/scenes/ui/pages/workbench_pages.tscn
@@ -41 +41 @@
-size = Vector2i(420, 210)
+size = Vector2i(720, 504)
diff --git a/tests/research_input_strip_self_check.gd b/tests/research_input_strip_self_check.gd
--- a/tests/research_input_strip_self_check.gd
+++ b/tests/research_input_strip_self_check.gd
@@ -128,7 +128,28 @@
-	_expect(picker != null and picker.visible, "pressing ToolSlot should open the compact tool picker")
-	if picker != null:
-		var mixer_button := _find_button_by_meta(picker, "tool_id", "mixer")
-		_expect(mixer_button != null, "tool picker should list unlocked devices")
-		if mixer_button != null:
-			var mixer_name := mixer_button.get_node_or_null("NameLabel") as Label
-			_expect(mixer_name != null and mixer_name.visible and mixer_name.text == "搅拌机", "tool picker should keep device names")
+	_expect(picker != null and picker.visible, "pressing ToolSlot should open the enlarged tool picker")
+	if picker != null:
+		_expect(picker.size == Vector2i(720, 504), "tool picker should open at 720x504, got %s" % str(picker.size))
+		var expected_picker_position := (Vector2i(view.get_viewport().get_visible_rect().size) - picker.size) / 2
+		_expect(picker.position == expected_picker_position, "tool picker should remain centered after enforcing its exact size")
+		var picker_grid := picker.get_node_or_null("ToolPickerMargin/ToolPickerBox/ToolPickerGrid") as GridContainer
+		_expect(picker_grid != null and picker_grid.columns == 3, "tool picker should keep a three-column grid")
+		if picker_grid != null:
+			_expect(picker_grid.get_child_count() == 6, "six unlocked devices should produce six tool cards")
+			for child_value in picker_grid.get_children():
+				var tool_button := child_value as Button
+				_expect(tool_button != null and tool_button.custom_minimum_size == Vector2(168, 168) and tool_button.size == Vector2(168, 168), "every tool picker card should render at 168x168")
+				if tool_button == null:
+					continue
+				var picker_tool_icon := tool_button.get_node_or_null("Icon") as TextureRect
+				var picker_tool_backdrop := tool_button.get_node_or_null("NameBackdrop") as ColorRect
+				var picker_tool_name := tool_button.get_node_or_null("NameLabel") as Label
+				_expect(picker_tool_icon != null and _fills_parent(picker_tool_icon), "every picker device image should fill its 168x168 card")
+				_expect(picker_tool_icon != null and picker_tool_icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "picker device images should preserve aspect ratio without cropping")
+				_expect(picker_tool_backdrop != null and not picker_tool_backdrop.visible, "picker cards should hide their bottom name backdrop")
+				_expect(picker_tool_name != null and not picker_tool_name.visible, "picker cards should hide their visible device name")
+				if picker_tool_name != null:
+					_expect(tool_button.tooltip_text == picker_tool_name.text, "picker card Tooltip should equal its device name")
+		var mixer_button := _find_button_by_meta(picker, "tool_id", "mixer")
+		_expect(mixer_button != null, "tool picker should list unlocked devices")
+		if mixer_button != null:
+			var mixer_name := mixer_button.get_node_or_null("NameLabel") as Label
+			_expect(mixer_name != null and not mixer_name.visible and mixer_name.text == "搅拌机", "tool picker should hide the visible mixer name while retaining its exact text for the Tooltip")
'@
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$pickerIndexPatch | git apply --cached --unidiff-zero --whitespace=fix
git diff --cached --check
git diff --cached -- scripts/main_view.gd scenes/ui/pages/workbench_pages.tscn tests/research_input_strip_self_check.gd
```

Expected: the staged diff contains no ingredient icon route, research-hint removal, progress-dialog change, panel-skin change, or unrelated material-selection assertion. Commit:

```powershell
git commit -m "feat: enlarge research tool picker icons"
```

Expected: the focused picker enlargement is committed while all unrelated pre-existing working-tree changes remain unstaged.
