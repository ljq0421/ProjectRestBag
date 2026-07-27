# Production Zone Natural Integration Implementation Plan

> Implement this plan task by task. Keep the approved design document and this plan uncommitted unless the user separately authorizes documentation commits.

**Goal:** Make the right-side production queue read as a natural in-store workbench by clearing the top curtain, removing the full panel shell, adding a faded warm tile wall and shallow wooden counter, and providing restrained active-production light and steam feedback.

**Architecture:** Preserve the existing `WorkbenchPanel/ProductionWorkbench` and `WorkbenchPanel/WorkbenchLauncher` paths. Convert only the main-page `WorkbenchPanel` from a skinned `VBoxContainer` into a scene-authored `Control` shell with fixed background/effect children and manually anchored existing content. Add one small shell script that accepts visual state; continue deriving all production business state in `main_view.gd`.

**Tech Stack:** Godot 4.6.1, GDScript, scene-first `.tscn` layout, repository-local headless self-checks, runtime screenshot and real-input acceptance.

## Global Constraints

- Target checkout: `D:\Project\ProjectRest\project-rest-new`.
- Source of truth: `docs/superpowers/specs/2026-07-26-production-zone-natural-integration-design.zh.md`.
- Do not commit the approved design document or this plan.
- Do not implement until the user separately authorizes implementation.
- Keep `WorkbenchPanel` at `820px` wide and its existing direct-child paths stable.
- Place visible production content at approximately `y=176px` in `1920×1080`, below the background curtain.
- Preserve `68px` queue-row height, current column widths, search, bulk actions, automation entry, bottom launcher, completed-stock drag, and all production business behavior.
- Accept approximately nine fully visible rows; remaining rows scroll.
- Do not change saves, production ordering, queue settlement, restock, automation, listing, or showcase drop contracts.
- Do not modify the global `DessertWorkbenchPanel` theme.
- Stable visuals belong in `.tscn`; scripts only bind activity/completion state and run animations.
- Every new visual `Control` must use `MOUSE_FILTER_IGNORE`.
- Every Godot headless command must pass a writable `--log-file`; never use `NUL`.

## File Map

- `scenes/Main.tscn`
  - Converts the main-page `WorkbenchPanel` to a transparent `Control`.
  - Declares tile fade, warm light, counter surface, counter edge, steam, and the anchored existing workbench/launcher.
- `scripts/ui/pages/production_zone_shell.gd`
  - Owns only visual activity state, steam timing, and one-shot completion pulse.
- `scenes/ui/pages/production_workbench.tscn`
  - Reduces the workbench/columns height and adds the existing mixer icon to the title.
- `scripts/main_view.gd`
  - Passes existing active-count state and existing completion feedback to the shell.
- `tests/production_zone_shell_self_check.gd`
  - Locks shell structure, state transitions, mouse filtering, and non-restarting animation behavior.
- `tests/production_queue_scene_self_check.gd`
  - Updates the workbench height and nine-row contract while preserving row and column geometry.
- `tests/main_page_background_self_check.gd`
  - Locks the curtain clearance and continuous-background contract.
- `tests/production_queue_interaction_self_check.gd`
  - Confirms visual layers do not block real clicks, scrolling, or completed-stock dragging.
- `tests/production_queue_performance_self_check.gd`
  - Confirms repeated runtime refreshes do not recreate shell nodes or restart unchanged visual state.

---

## Task 1: Lock the New Geometry and Visual-State Contract

**Files:**

- Create: `tests/production_zone_shell_self_check.gd`
- Modify: `tests/production_queue_scene_self_check.gd`
- Modify: `tests/main_page_background_self_check.gd`
- Modify: `tests/production_queue_interaction_self_check.gd`
- Modify: `tests/production_queue_performance_self_check.gd`

### Step 1: Replace the obsolete 858/794/10-row expectations

Update `production_queue_scene_self_check.gd` to require:

```gdscript
_expect_equal("workbench height", int(workbench.custom_minimum_size.y), 766)
_expect_equal("production columns height", int(body.custom_minimum_size.y), 702)
_expect_equal("queue viewport height", int(queue_column.custom_minimum_size.y), 702)
_expect_equal("nine rows fit fully", 9 * 68 + 8 * 6 <= 702, true)
_expect_equal("tenth row remains scrollable", 10 * 68 + 9 * 6 > 702, true)
```

Keep the current assertions for:

- `820px` total column width;
- `104px` completed-stock column;
- `708px` queue column;
- `8px` inter-column gap;
- `68px` row height;
- `6px` row/cell separation;
- one-line header;
- full-row progress;
- absence of the old footer/picker.

### Step 2: Add a focused shell scene test

Create `production_zone_shell_self_check.gd` and instantiate `Main.tscn` at `1920×1080`.

Assert:

- `WorkbenchPanel` is a `Control`, not a `VBoxContainer`;
- `WorkbenchPanel` has no `skinned_vbox_container.gd` script;
- it does not use `DessertWorkbenchPanel`;
- `TileFade`, `WarmLight`, `CounterSurface`, `CounterTopEdge`, and `SteamEffect` exist;
- every visual node ignores mouse input;
- `ProductionWorkbench` and `WorkbenchLauncher` remain direct children;
- both existing paths still resolve;
- the production workbench global top is approximately `176px`;
- the launcher remains at the body bottom;
- tile/counter nodes are static and survive repeated state updates.

Add public test-facing shell methods only if they are also the intended runtime API:

```gdscript
set_activity_state(active: bool) -> void
pulse_completion() -> void
```

### Step 3: Lock visual-state transition behavior

The shell test must assert:

- initial idle state hides steam;
- `set_activity_state(true)` enables warm light and steam scheduling;
- calling `set_activity_state(true)` again does not restart the same animation/timer;
- `set_activity_state(false)` stops steam and returns light to idle;
- `pulse_completion()` runs once without changing business state;
- no scene child count changes during these calls.

### Step 4: Lock the curtain-clearance contract

Update `main_page_background_self_check.gd` to assert:

- production content top is between approximately `172px` and `180px`;
- the top is below the accepted curtain boundary;
- `WorkbenchPanel` itself still occupies the existing body allocation;
- the global page background and scaling mode are unchanged.

Do not encode screenshot pixel sampling into a headless test. Use the accepted geometric boundary and later visual acceptance for the irregular curtain edge.

### Step 5: Extend interaction/performance tests

In `production_queue_interaction_self_check.gd`, assert the visual nodes are ignored by hit testing before running the current real make/process/drag paths.

In `production_queue_performance_self_check.gd`, capture:

- shell child instance IDs;
- current activity-state transition counter or animation generation;

Then call runtime refresh repeatedly with unchanged active state and assert:

- shell nodes retain their instance IDs;
- no new effect nodes appear;
- animation state is not restarted.

### Step 6: Run the focused tests and verify the intended failures

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-shell-red.log" -s res://tests/production_zone_shell_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-scene-red.log" -s res://tests/production_queue_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-background-red.log" -s res://tests/main_page_background_self_check.gd
```

Expected failures must identify the current skinned shell, curtain overlap, `858/794` heights, ten-row expectation, and missing visual-state API.

---

## Task 2: Build the Scene-First Production Zone Shell

**Files:**

- Modify: `scenes/Main.tscn`
- Create: `scripts/ui/pages/production_zone_shell.gd`
- Test: `tests/production_zone_shell_self_check.gd`
- Test: `tests/main_page_background_self_check.gd`

### Step 1: Preserve the node path while changing the shell type

In `Main.tscn`:

- keep the node name `WorkbenchPanel`;
- change its type from `VBoxContainer` to `Control`;
- preserve `custom_minimum_size.x = 820`;
- preserve horizontal and vertical size flags required by `MainArea`;
- remove only its local `DessertWorkbenchPanel` theme variation;
- detach only `skinned_vbox_container.gd`;
- leave the shared theme and script files untouched.

Confirm `main_view.gd` still resolves all existing direct-child paths.

### Step 2: Add static background/effect nodes

Add the following children before interactive content:

```text
TileFade
WarmLight
CounterSurface
```

Add `SteamEffect` after interactive content for drawing order, with mouse input ignored.

Implementation requirements:

- use generated hand-painted transparent PNG overlays for the tile wall and counter;
- use the existing main background and panel art as style references;
- use warm cream tiles with soft caramel-brown hand-painted grout;
- start the tile fade near local `x=96`;
- fade toward the stable right-side strength by approximately local `x=360`;
- keep maximum tile opacity near `28%`;
- keep the total counter visual height at or below `72px`;
- bake the highlighted top lip and approximately `68px` counter body into one transparent texture;
- retain the shader only for dynamic warm-light feedback.
- replace the standalone boundary post with a generated hand-painted
  single-column shelf background inside `CompletedColumn`;
- keep `CompletedColumn` at `104px` and its content height at `702px`;
- preserve `68×68px` completed-stock drag cells;
- render at most `9` completed product types per page with `2px` separation;
- add `26px` previous/next buttons and an `18px` page indicator;
- clamp the current page whenever completed product types are removed;
- preserve the existing `inventory_product` drag payload and completion-record ordering;
- do not add the B-scheme utensil rail.

### Step 3: Anchor the existing content manually

Keep:

```text
WorkbenchPanel/ProductionWorkbench
WorkbenchPanel/WorkbenchLauncher
```

Anchor/offset them so:

- workbench local top is approximately `112px`;
- workbench height is approximately `766px`;
- launcher remains approximately `76px` high at the shell bottom;
- workbench/launcher separation is approximately `8px`;
- neither child overlaps the curtain.

### Step 4: Implement the visual-only shell API

Attach `production_zone_shell.gd` to `WorkbenchPanel`.

The script should:

- cache declared scene nodes;
- store the last active boolean;
- transition only when the value changes;
- play/stop a scene-authored steam animation or timer;
- expose a one-shot completion pulse;
- reset safely if effects are missing.

It must not know recipe IDs, inventory, saves, automation, or showcase behavior.

### Step 5: Run shell/background tests

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-shell-green.log" -s res://tests/production_zone_shell_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-background-green.log" -s res://tests/main_page_background_self_check.gd
```

---

## Task 3: Resize the Workbench and Add the Existing Mixer Icon

**Files:**

- Modify: `scenes/ui/pages/production_workbench.tscn`
- Modify: `tests/production_queue_scene_self_check.gd`

### Step 1: Apply the approved heights

Change:

- `ProductionWorkbench.custom_minimum_size.y` from `858` to approximately `766`;
- `ProductionColumns.custom_minimum_size.y` from `794` to approximately `702`;
- `CompletedColumn`, `CompletedScroll/CompletedCenter`, `QueueColumn`, and other fixed-height declarations from `794` to approximately `702`.

Do not change:

- total width `820`;
- completed column `104`;
- queue column `708`;
- column separation `8`;
- row height `68`;
- row separation `6`;
- title/header height `54`.

### Step 2: Add the title icon in the scene

Add an external texture resource:

```text
res://resources/device_icons/mixer.png
```

Add a `TextureRect` before `QueueTitleLabel`:

- target size `24×24px`;
- keep aspect ratio;
- ignore mouse input;
- vertically center within the existing single header row.

Increase the title group allocation only as much as needed. Do not create a second toolbar row or reduce action-button minimum widths.

### Step 3: Verify runtime geometry

Update and run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-queue-scene.log" -s res://tests/production_queue_scene_self_check.gd
```

The test should instantiate at `1920×1080` and verify nine complete rows can fit without shrinking existing row content.

---

## Task 4: Bind Existing Queue State to the Visual Shell

**Files:**

- Modify: `scripts/main_view.gd`
- Modify: `scripts/ui/pages/production_zone_shell.gd`
- Modify: `tests/production_zone_shell_self_check.gd`
- Modify: `tests/production_queue_performance_self_check.gd`

### Step 1: Add one stable shell reference

Add an on-ready reference for:

```text
Root/Body/MainArea/WorkbenchPanel
```

Use the shell script API without changing existing `ProductionWorkbench` or `WorkbenchLauncher` references.

### Step 2: Update activity state from existing counts

Both structural and runtime refresh paths already compute an active count:

- `_render_unified_production_queue()`;
- `_refresh_production_queue_tick(now_unix)`.

After computing the existing count, pass only:

```gdscript
production_zone_shell.set_activity_state(active_count > 0)
```

Do not rescan snapshots or queue arrays a second time for visual state.

Refactor to a local `active_count` variable if needed so the same computed value feeds both the workbench and shell.

### Step 3: Reuse the existing completion path

Use the current captured production-completion feedback to request one shell pulse when a new completion is recorded.

Requirements:

- no new completion business event;
- no duplicate inventory/state mutation;
- no pulse on ordinary runtime ticks;
- no pulse loop while feedback remains visible for its existing lifetime.

If necessary, return a boolean from the existing capture function or compare feedback length before/after capture. Keep the change local and deterministic.

### Step 4: Verify unchanged-state ticks

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-performance.log" -s res://tests/production_queue_performance_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-shell-state.log" -s res://tests/production_zone_shell_self_check.gd
```

---

## Task 5: Real Interaction and Visual Acceptance

**Files:**

- Modify only if evidence requires it:
  - `scenes/Main.tscn`
  - `scenes/ui/pages/production_workbench.tscn`
  - `scripts/ui/pages/production_zone_shell.gd`
- Test:
  - `tests/production_queue_interaction_self_check.gd`
  - existing focused production/background tests

### Step 1: Run focused headless checks

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-scene.log" -s res://tests/production_queue_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-shell.log" -s res://tests/production_zone_shell_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-background.log" -s res://tests/main_page_background_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-interaction.log" -s res://tests/production_queue_interaction_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\prn-zone-performance.log" -s res://tests/production_queue_performance_self_check.gd
```

Also run existing completed-stock, production-timing, output/production-band, and main-scene shell checks.

### Step 2: Inspect the real running page at 1920×1080

Capture and review:

1. idle queue;
2. active production;
3. completion pulse/flash;
4. scrolled queue;
5. completed stock beside active queue;
6. popup open over the production area.

Visual acceptance:

- curtain is fully visible and not covered;
- production content starts near `y=176px`;
- no complete right-side panel rectangle remains;
- tile fade has no hard left edge;
- rightmost tile contrast remains below row contrast;
- counter is no taller than the approved shallow band;
- the launcher reads as sitting on the counter;
- steam remains subtle and never covers controls;
- left storefront remains the primary visual focus.

### Step 3: Exercise real input

Use real press/motion/release paths:

- type and clear search;
- mouse-wheel the queue;
- click make/process/restock;
- open automation schedule;
- click every bottom launcher entry;
- drag completed stock to an unlocked showcase slot;
- attempt an invalid drop and confirm stock is preserved.

Do not accept manually emitted signals as interaction proof.

### Step 4: Run proportional regressions

After focused checks pass, run the current production, tutorial target, overlay, showcase drag, output, and MVP checks that exist in this checkout. Report unrelated fixture failures separately rather than weakening focused assertions.

### Step 5: Handoff

Report:

- changed code/scene/test files;
- exact focused test PASS markers;
- runtime screenshots reviewed;
- real input paths exercised;
- any unrelated regression failures;
- Git status;
- documentation remains uncommitted unless the user explicitly changes that instruction.
