# Daily Task Runtime Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan inline. Do not dispatch subagents for this task.

**Goal:** Connect the configured daily tasks to `TaskService`, real gameplay events, reward claiming, daily reset, and the daily task UI filter.

**Architecture:** `game_data.json` becomes the structured source for daily definitions. `TaskService` merges enabled daily definitions with the existing mainline definitions and resets only `daily_*` runtime state when the local calendar day changes. `GameState` persists the current daily day key; existing task completion and reward-claim APIs remain shared.

**Tech Stack:** Godot 4.6.1, GDScript, JSON, headless SceneTree self-checks.

## Global Constraints

- Do not use subagents.
- Do not add save migration; missing daily fields initialize naturally.
- Keep NPC gifting configured but hidden until an NPC gifting runtime exists.
- Translate unsupported configured rewards to existing resources: shop XP to reputation, feed to ranch input, and random bundles to deterministic current inventory items.
- Keep individual and one-click task reward claiming unchanged.

---

### Task 1: Structured Daily Definitions and Runtime Reset

**Files:**
- Modify: `game_data.json`
- Modify: `scripts/task_service.gd`
- Modify: `scripts/game_state.gd`
- Test: `tests/daily_task_self_check.gd`

**Interfaces:**
- Produces: `TaskService.ensure_daily_tasks_current(state, day_key := "") -> void`
- Produces: `GameState.sync_daily_tasks(day_key := "") -> void`
- Persists: `GameState.daily_task_day_key: String`

- [ ] Write a failing self-check that requires six visible `type == "daily"` tasks, excludes `daily_neighbor_gift`, advances farm harvest progress, and clears `daily_*` completion/progress/claim state on a day-key change.
- [ ] Run `res://tests/daily_task_self_check.gd` and verify failure because daily definitions and reset APIs are absent.
- [ ] Replace the seven descriptive daily rows with structured `id`, `event`, `condition`, `goal`, `availability`, and `reward` fields; set the NPC gift row to `enabled: false`.
- [ ] Merge sanitized daily rows into `TaskService.get_task_definitions()` and call daily synchronization before event application and task queries.
- [ ] Persist `daily_task_day_key`; reset only IDs beginning with `daily_` from `completed_tasks`, `claimed_tasks`, and `task_progress` when the key changes.
- [ ] Re-run the focused self-check.

### Task 2: Real Event Wiring and Daily UI Filtering

**Files:**
- Modify: `scripts/main_view.gd`
- Modify: `scripts/task_service.gd`
- Modify: `scripts/ui/overlays/task_overlay.gd`
- Test: `tests/daily_task_self_check.gd`

**Interfaces:**
- Consumes: `state.record_task_event(event_name, payload)`
- Produces: `research_attempt` events after a valid research action reaches `RecipeBook.research()`.

- [ ] Extend the failing self-check for sales quantity, order count, research attempts, ranch harvests, reward claiming, and daily-tab isolation from mainline tasks.
- [ ] Run the focused self-check and verify the event/filter assertions fail.
- [ ] Record one `research_attempt` for every actual multi-material research call.
- [ ] Teach daily order progress to count sale entries while daily sales continue to count sold quantity.
- [ ] Change the `daily` task overlay branch to include only daily active and daily claimable tasks.
- [ ] Re-run the focused self-check and component contract self-check.

### Task 3: Verification

**Files:**
- Verify all files above.

- [ ] Run `res://tests/daily_task_self_check.gd` and require exit code 0.
- [ ] Run `res://tests/task_bulk_claim_self_check.gd` and require exit code 0.
- [ ] Run `res://tests/component_contract_self_check.gd` and require exit code 0.
- [ ] Run Godot headless startup with `--quit` and a writable `--log-file`.
- [ ] Run `git diff --check` for all touched files and inspect the final diff without reverting unrelated worktree changes.
