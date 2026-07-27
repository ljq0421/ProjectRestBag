# Crisp Font Scaling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `project-rest-new` render dynamic fonts at the actual output resolution while preserving the complete 1920×1080 16:9 layout with black bars in non-16:9 windows.

**Architecture:** Keep 1920×1080 as the sole logical design size, replace root `viewport` stretching with `canvas_items`, and restore the `keep` aspect policy. Lock the contract in the existing focused scaling self-check, update the architecture reference, and use existing scene-level layout tests to detect regressions without restructuring UI scenes.

**Tech Stack:** Godot 4.6.1, GDScript self-checks, Godot project settings, PowerShell

## Global Constraints

- Modify only `D:\Project\ProjectRest\project-rest-new`; do not modify `project-rest`.
- Keep `window/size/viewport_width=1920` and `window/size/viewport_height=1080`.
- Use `window/stretch/mode="canvas_items"` and `window/stretch/aspect="keep"`.
- Preserve existing scenes, control sizes, font sizes, font resources, image assets, input handling, and gameplay logic.
- Non-16:9 windows must preserve the complete 16:9 design and may display black bars.
- Every Godot headless command must pass `--log-file` with a writable `$env:TEMP` path.
- Preserve all unrelated user changes in the dirty working tree.

---

### Task 1: Replace fixed-viewport scaling with target-resolution canvas scaling

**Files:**
- Modify: `tests/ui_scaling_self_check.gd:3-4`
- Modify: `project.godot:24-27`
- Modify: `doc/2026-07-09-codebase-architecture-maintenance.md:14-16`

**Interfaces:**
- Consumes: Godot project settings `display/window/size/viewport_width`, `display/window/size/viewport_height`, `display/window/stretch/mode`, and `display/window/stretch/aspect`.
- Produces: A project-wide `canvas_items + keep` rendering contract guarded by `tests/ui_scaling_self_check.gd`.

- [ ] **Step 1: Change the focused self-check to express the new rendering contract**

Replace the constants at the top of `tests/ui_scaling_self_check.gd` with:

```gdscript
const EXPECTED_STRETCH_MODE := "canvas_items"
const EXPECTED_STRETCH_ASPECT := "keep"
```

Do not change the test's failure collection or exit behavior. The existing assertions already read the authoritative project settings and report both mismatches.

- [ ] **Step 2: Run the focused self-check and verify the new contract fails before implementation**

Run from `D:\Project\ProjectRest\project-rest-new`:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-ui-scaling-red.log" `
  -s res://tests/ui_scaling_self_check.gd
```

Expected: non-zero exit with `display/window/stretch/mode should be canvas_items, got viewport`. The current missing `window/stretch/aspect` may also report `display/window/stretch/aspect should be keep, got ignore`; that second failure is expected and confirms the aspect regression.

- [ ] **Step 3: Apply the minimal project setting change**

Keep the viewport size lines in `project.godot` and make the complete `[display]` section read:

```ini
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

Do not add a content scale factor, window override size, DPI override, texture filter override, or runtime scaling script.

- [ ] **Step 4: Update the architecture reference so it no longer prescribes the obsolete mode**

In `doc/2026-07-09-codebase-architecture-maintenance.md`, replace the existing stretch summary with:

```markdown
- 视口：`1920x1080`
- 拉伸：`window/stretch/mode="canvas_items"`，`window/stretch/aspect="keep"`；动态字体按实际输出分辨率渲染，非 16:9 窗口保留黑边
```

Keep the surrounding renderer and autoload description unchanged.

- [ ] **Step 5: Run the focused self-check and verify the configuration is green**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-ui-scaling-green.log" `
  -s res://tests/ui_scaling_self_check.gd
```

Expected: exit code `0` and `UI_SCALING_SELF_CHECK_PASS`.

- [ ] **Step 6: Run the layout regression checks**

Run each command from `D:\Project\ProjectRest\project-rest-new`:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-layout-refinement.log" -s res://tests/layout_refinement_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-viewport-1920.log" -s res://tests/viewport_1920_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-output-layout.log" -s res://tests/output_layout_self_check.gd
```

Expected: all three commands exit `0`; output includes each script's corresponding `*_PASS` marker. If a command fails, record the exact assertion before changing any additional file and confirm the failure is caused by this scaling change.

- [ ] **Step 7: Run the main-flow regression check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-mvp.log" `
  -s res://tests/mvp_self_check.gd
```

Expected: exit code `0` and `MVP_SELF_CHECK_PASS`. If the process fails before assertions because the sandbox blocks `user://` writes, rerun through the approved Godot command path and report it as an environment failure unless a game assertion also fails.

- [ ] **Step 8: Verify the runtime presentation at the required output shapes**

Launch the standalone project in each requested window size, close it after inspecting the case, and do not edit scene geometry:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64.exe" --path . --resolution 1920x1080
& "D:\Godot\Godot_v4.6.1-stable_win64.exe" --path . --resolution 2560x1440
& "D:\Godot\Godot_v4.6.1-stable_win64.exe" --path . --resolution 1600x1000
```

```text
1920×1080: complete layout, no black bars, unchanged logical sizes.
2560×1440: complete layout, no black bars, visibly sharper dynamic text than viewport mode.
1600×1000: complete 16:9 layout centered with black bars above and below; no stretching or clipping.
```

Treat slight interpolation of PNG skin textures as separate from this bug. Acceptance is based on dynamic text no longer being enlarged from a fixed 1920×1080 intermediate viewport.

- [ ] **Step 9: Inspect the final patch and commit only the scoped implementation files**

Run:

```powershell
git diff --check
git diff -- project.godot tests/ui_scaling_self_check.gd doc/2026-07-09-codebase-architecture-maintenance.md
git status --short
```

Expected: no whitespace errors; the scoped diff contains only the stretch mode, restored aspect policy, test expectation, and architecture summary. Preserve all other dirty working-tree entries.

Commit only these files:

```powershell
git add -- project.godot tests/ui_scaling_self_check.gd doc/2026-07-09-codebase-architecture-maintenance.md
git commit -m "fix: render UI text at output resolution"
```
