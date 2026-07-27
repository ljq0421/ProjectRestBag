# Neighborhood Dessert Text Colors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace unreadable default white text on the neighborhood dessert skin's light surfaces with a coherent warm-brown text palette while preserving intentional light text on dark controls.

**Architecture:** Define the default palette once in the shared Godot `Theme`, so existing and dynamically created controls inherit readable colors without per-node overrides. Extend the existing focused theme self-check to lock the base palette and the intentional inverse-color variations.

**Tech Stack:** Godot 4.6.1, GDScript, Godot `.tres` Theme resources

## Global Constraints

- Ordinary text uses deep brown `Color(0.411765, 0.215686, 0.0980392, 1)`.
- Hovered text uses darker brown `Color(0.352941, 0.164706, 0.0627451, 1)`.
- Disabled and read-only text uses brown-gray `Color(0.411765, 0.294118, 0.215686, 0.65)`.
- Selected text on a brown selection background uses cream `Color(1, 0.968627, 0.862745, 1)`.
- Existing cream text on `DessertPrimaryButton`, selected `DessertTopTabButton`, and `DessertShowcaseBadgeReady` remains unchanged.
- Existing business-specific colors such as the storefront gold price label remain unchanged.
- Do not change fonts, font sizes, layout, textures, node structure, or scripts.
- Do not commit changes unless the user explicitly requests a commit.

---

### Task 1: Add a tested default text palette to the shared Theme

**Files:**
- Modify: `tests/neighborhood_dessert_theme_self_check.gd`
- Modify: `resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres`

**Interfaces:**
- Consumes: `Theme.get_color(name: StringName, theme_type: StringName) -> Color`
- Produces: inherited readable text colors for standard Godot text-bearing controls

- [x] **Step 1: Write the failing palette assertions**

Add these constants and checks to `tests/neighborhood_dessert_theme_self_check.gd`:

```gdscript
const TEXT_PRIMARY := Color(0.411765, 0.215686, 0.0980392, 1)
const TEXT_HOVER := Color(0.352941, 0.164706, 0.0627451, 1)
const TEXT_MUTED := Color(0.411765, 0.294118, 0.215686, 0.65)
const TEXT_INVERSE := Color(1, 0.968627, 0.862745, 1)

const REQUIRED_TEXT_COLORS := {
	"Label": {"font_color": TEXT_PRIMARY},
	"RichTextLabel": {"default_color": TEXT_PRIMARY},
	"Button": {
		"font_color": TEXT_PRIMARY,
		"font_hover_color": TEXT_HOVER,
		"font_pressed_color": TEXT_PRIMARY,
		"font_disabled_color": TEXT_MUTED,
	},
	"CheckBox": {
		"font_color": TEXT_PRIMARY,
		"font_hover_color": TEXT_HOVER,
		"font_pressed_color": TEXT_PRIMARY,
		"font_disabled_color": TEXT_MUTED,
	},
	"CheckButton": {
		"font_color": TEXT_PRIMARY,
		"font_hover_color": TEXT_HOVER,
		"font_pressed_color": TEXT_PRIMARY,
		"font_disabled_color": TEXT_MUTED,
	},
	"LineEdit": {
		"font_color": TEXT_PRIMARY,
		"font_uneditable_color": TEXT_MUTED,
		"font_selected_color": TEXT_INVERSE,
	},
	"TextEdit": {
		"font_color": TEXT_PRIMARY,
		"font_readonly_color": TEXT_MUTED,
		"font_selected_color": TEXT_INVERSE,
	},
	"OptionButton": {
		"font_color": TEXT_PRIMARY,
		"font_hover_color": TEXT_HOVER,
		"font_pressed_color": TEXT_PRIMARY,
		"font_disabled_color": TEXT_MUTED,
	},
	"TabBar": {
		"font_unselected_color": TEXT_PRIMARY,
		"font_hovered_color": TEXT_HOVER,
		"font_selected_color": TEXT_PRIMARY,
		"font_disabled_color": TEXT_MUTED,
	},
	"ItemList": {"font_color": TEXT_PRIMARY},
}
```

Inside `_run()`, immediately after the null-theme guard, add:

```gdscript
	for theme_type: String in REQUIRED_TEXT_COLORS:
		var colors: Dictionary = REQUIRED_TEXT_COLORS[theme_type]
		for color_name: String in colors:
			var expected: Color = colors[color_name]
			var actual := theme.get_color(color_name, theme_type)
			if not actual.is_equal_approx(expected):
				_fail("%s/%s should be %s, got %s" % [theme_type, color_name, expected, actual])

	if theme.get_color("font_color", "DessertPrimaryButton") != TEXT_INVERSE:
		_fail("DessertPrimaryButton must preserve inverse cream text")
	if theme.get_color("font_pressed_color", "DessertTopTabButton") != TEXT_INVERSE:
		_fail("Selected DessertTopTabButton must preserve inverse cream text")
	if theme.get_color("font_color", "DessertShowcaseBadgeReady") != TEXT_INVERSE:
		_fail("DessertShowcaseBadgeReady must preserve inverse cream text")
```

- [x] **Step 2: Run the focused check and verify RED**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-text-colors-red.log" -s res://tests/neighborhood_dessert_theme_self_check.gd
```

Expected: exit code `1` with one or more `NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_FAIL` messages reporting default white text colors.

- [x] **Step 3: Add the minimal Theme color entries**

Add the following entries at the start of `[resource]` in `resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres`:

```text
Label/colors/font_color = Color(0.411765, 0.215686, 0.0980392, 1)
RichTextLabel/colors/default_color = Color(0.411765, 0.215686, 0.0980392, 1)
Button/colors/font_color = Color(0.411765, 0.215686, 0.0980392, 1)
Button/colors/font_disabled_color = Color(0.411765, 0.294118, 0.215686, 0.65)
Button/colors/font_hover_color = Color(0.352941, 0.164706, 0.0627451, 1)
Button/colors/font_pressed_color = Color(0.411765, 0.215686, 0.0980392, 1)
CheckBox/colors/font_color = Color(0.411765, 0.215686, 0.0980392, 1)
CheckBox/colors/font_disabled_color = Color(0.411765, 0.294118, 0.215686, 0.65)
CheckBox/colors/font_hover_color = Color(0.352941, 0.164706, 0.0627451, 1)
CheckBox/colors/font_pressed_color = Color(0.411765, 0.215686, 0.0980392, 1)
CheckButton/colors/font_color = Color(0.411765, 0.215686, 0.0980392, 1)
CheckButton/colors/font_disabled_color = Color(0.411765, 0.294118, 0.215686, 0.65)
CheckButton/colors/font_hover_color = Color(0.352941, 0.164706, 0.0627451, 1)
CheckButton/colors/font_pressed_color = Color(0.411765, 0.215686, 0.0980392, 1)
LineEdit/colors/font_color = Color(0.411765, 0.215686, 0.0980392, 1)
LineEdit/colors/font_selected_color = Color(1, 0.968627, 0.862745, 1)
LineEdit/colors/font_uneditable_color = Color(0.411765, 0.294118, 0.215686, 0.65)
TextEdit/colors/font_color = Color(0.411765, 0.215686, 0.0980392, 1)
TextEdit/colors/font_readonly_color = Color(0.411765, 0.294118, 0.215686, 0.65)
TextEdit/colors/font_selected_color = Color(1, 0.968627, 0.862745, 1)
OptionButton/colors/font_color = Color(0.411765, 0.215686, 0.0980392, 1)
OptionButton/colors/font_disabled_color = Color(0.411765, 0.294118, 0.215686, 0.65)
OptionButton/colors/font_hover_color = Color(0.352941, 0.164706, 0.0627451, 1)
OptionButton/colors/font_pressed_color = Color(0.411765, 0.215686, 0.0980392, 1)
TabBar/colors/font_unselected_color = Color(0.411765, 0.215686, 0.0980392, 1)
TabBar/colors/font_hovered_color = Color(0.352941, 0.164706, 0.0627451, 1)
TabBar/colors/font_selected_color = Color(0.411765, 0.215686, 0.0980392, 1)
TabBar/colors/font_disabled_color = Color(0.411765, 0.294118, 0.215686, 0.65)
ItemList/colors/font_color = Color(0.411765, 0.215686, 0.0980392, 1)
```

- [x] **Step 4: Run the focused check and verify GREEN**

Run the Step 2 command again with log file `$env:TEMP\godot-text-colors-green.log`.

Expected: exit code `0` and `NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_PASS`.

- [x] **Step 5: Run parser and adjacent skin regression checks**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-text-colors-parse.log" --quit
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-skin.log" -s res://tests/showcase_skin_self_check.gd
```

Expected: parser command exits `0` without `SCRIPT ERROR`; showcase command exits `0` with `SHOWCASE_SKIN_SELF_CHECK_PASS`.
