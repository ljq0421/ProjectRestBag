# Ingredient V1 Runtime Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route every `project-rest-new` runtime ingredient icon lookup to `res://resources/ui/ingredient_v1` while retaining the old asset directory without fallback.

**Architecture:** Preserve the existing centralized `_ingredient_icon_texture()` and `_material_icon_texture()` call chain. Change only its directory constant, then make the focused inventory icon self-check assert both the new route and complete `Catalog.INGREDIENTS` coverage.

**Tech Stack:** Godot 4.6.1, GDScript, PowerShell, ripgrep

## Global Constraints

- Modify only `D:\Project\ProjectRest\project-rest-new`.
- Keep `resources/ingredient_icons` on disk but do not use it as a runtime fallback.
- Do not change ingredient IDs, inventory data, business logic, recipe icons, device icons, or unrelated existing worktree changes.
- Run Godot headless commands with a writable `--log-file`; never use `NUL`.

---

### Task 1: Replace the centralized ingredient icon route

**Files:**
- Modify: `tests/inventory_recipe_icon_layout_self_check.gd:3-4,107-108`
- Modify: `scripts/main_view.gd:43`

**Interfaces:**
- Consumes: `Catalog.INGREDIENTS: Dictionary`, `main_view._material_icon_texture(item_id: String) -> Texture2D`
- Produces: `INGREDIENT_ICON_DIRECTORY = "res://resources/ui/ingredient_v1"` and focused coverage for every catalog ingredient ID

- [x] **Step 1: Update the focused test to require the new directory and all catalog IDs**

Add the catalog preload beside the existing test constants:

```gdscript
const Catalog = preload("res://scripts/catalog.gd")
```

Replace the single `rice` path assertion with:

```gdscript
	for ingredient_id_value in Catalog.INGREDIENTS.keys():
		var ingredient_id := String(ingredient_id_value)
		var catalog_texture := main.call("_material_icon_texture", ingredient_id) as Texture2D
		var expected_ingredient_path := "res://resources/ui/ingredient_v1/%s.png" % ingredient_id
		_expect(
			catalog_texture != null and catalog_texture.resource_path == expected_ingredient_path,
			"ingredient %s should load %s" % [ingredient_id, expected_ingredient_path]
		)
```

- [x] **Step 2: Run the focused test and verify the old runtime route fails**

Run from `D:\Project\ProjectRest\project-rest-new`:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\ingredient-v1-red.log" `
  -s res://tests/inventory_recipe_icon_layout_self_check.gd
```

Expected: exit code `1`; failures report that ingredient textures still resolve to `res://resources/ingredient_icons/<ingredient_id>.png`.

- [x] **Step 3: Switch the centralized runtime directory**

In `scripts/main_view.gd`, replace the constant with:

```gdscript
const INGREDIENT_ICON_DIRECTORY := "res://resources/ui/ingredient_v1"
```

Do not add a fallback to `resources/ingredient_icons`.

- [x] **Step 4: Import the new PNG resources**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --editor `
  --path . `
  --log-file "$env:TEMP\ingredient-v1-import.log" `
  --quit
```

Expected: exit code `0`; every PNG in `resources/ui/ingredient_v1` has a generated `.import` sidecar.

- [x] **Step 5: Run the focused test and verify complete runtime coverage**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\ingredient-v1-green.log" `
  -s res://tests/inventory_recipe_icon_layout_self_check.gd
```

Expected: exit code `0` and output contains `INVENTORY_RECIPE_ICON_LAYOUT_SELF_CHECK_PASS`.

- [x] **Step 6: Verify asset sets and remaining runtime references**

Run:

```powershell
$newIds = Get-ChildItem -LiteralPath "resources\ui\ingredient_v1" -Filter "*.png" -File |
  ForEach-Object BaseName | Sort-Object -Unique
$oldIds = Get-ChildItem -LiteralPath "resources\ingredient_icons" -Filter "*.png" -File |
  ForEach-Object BaseName | Sort-Object -Unique
Compare-Object -ReferenceObject $newIds -DifferenceObject $oldIds
rg -n --glob "!*.import" --glob "!docs/**" --glob "!resources/ingredient_icons/**" `
  "res://resources/ingredient_icons|resources/ingredient_icons" scripts scenes tests project.godot
```

Expected: `Compare-Object` produces no output, and `rg` exits with code `1` because no runtime/test old-directory references remain.

- [x] **Step 7: Run the project load check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\ingredient-v1-project-load.log" `
  --quit
```

Expected: exit code `0` with no parse or missing-resource errors.

- [x] **Step 8: Review the exact task diff**

Run:

```powershell
git diff -- scripts/main_view.gd tests/inventory_recipe_icon_layout_self_check.gd
git status --short
```

Expected: runtime/test diff contains only the directory replacement and catalog-wide assertion; unrelated pre-existing changes remain untouched.
