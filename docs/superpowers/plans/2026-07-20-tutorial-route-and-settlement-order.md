# Tutorial Route and Settlement Ordering Implementation Plan

**Goal:** Make the first two tutorial pages open only from their dialogue action buttons, refresh storefront-management access immediately after business starts, and converge storefront viewing with a confirmed real-sale settlement in either order.

**Architecture:** Keep page presentation in `main_view.gd` and business evidence in `TutorialProgress`. Reuse persisted `core_unlock_progress` keys for the two terminal conditions, and let one internal progression helper advance to `complete` only when both are true.

## Task 1: Add failing state-machine coverage

**Files:**
- Modify: `tests/core_unlock_event_chain_self_check.gd`
- Modify: `tests/tutorial_guide_state_self_check.gd`

1. Add a case where a valid settlement occurs during `STEP_STOREFRONT`; assert the evidence persists but the step does not complete.
2. View storefront afterward; assert the guide advances directly to `STEP_COMPLETE`.
3. Preserve the existing view-first, settlement-second path.
4. Assert zero-sale or unconfirmed settlement does not write valid evidence.

## Task 2: Make the terminal events order-independent

**Files:**
- Modify: `scripts/tutorial_progress.gd`

1. Let `on_business_round_settled()` accept valid reports while the guide is at `STEP_STOREFRONT` or `STEP_SETTLEMENT`.
2. Persist `first_sale_settlement_completed` only when the confirmed report sold at least one item.
3. Persist `storefront_viewed` from the actual storefront button event.
4. Add one private helper that advances to `STEP_COMPLETE` only when both persisted facts are true.
5. Keep repeated calls idempotent.

## Task 3: Move purchase/output routing to dialogue action clicks

**Files:**
- Modify: `scripts/main_view.gd`
- Modify: `tests/tutorial_guide_route_self_check.gd`

1. Exclude `STEP_PURCHASE` and `STEP_OUTPUT` from automatic routing in `_refresh_tutorial_guide()`.
2. In `_on_tutorial_dialogue_acknowledged()`, open purchase or output only for those two steps.
3. Assert the initial purchase dialogue preserves the current background until acknowledgement.
4. After a real rice-seed purchase advances to output, assert the purchase page remains visible until “去农场看看” is acknowledged.
5. Confirm acknowledgement opens the correct destination without advancing the tutorial step.

## Task 4: Refresh storefront-management access at business start

**Files:**
- Modify: `scripts/main_view.gd`
- Modify: `tests/core_feature_lock_ui_self_check.gd`

1. After `TutorialProgress.on_business_round_started()`, refresh the workbench core-feature access state.
2. Assert the storefront-management launcher is unlocked when the storefront dialogue appears.
3. Preserve business-start failure behavior: no unlock and no refresh-driven false state.

## Task 5: Integrate and verify

**Files:**
- Modify only affected tests if their old assertions encode automatic routing or order-dependent settlement.

Run focused checks with a writable Godot log path:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\projectrest-tutorial-route.log" -s res://tests/tutorial_guide_route_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\projectrest-core-chain.log" -s res://tests/core_unlock_event_chain_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\projectrest-guide-state.log" -s res://tests/tutorial_guide_state_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\projectrest-core-ui.log" -s res://tests/core_feature_lock_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\projectrest-mvp.log" -s res://tests/mvp_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\projectrest-load.log" --quit
```

Finally run `git diff --check` and inspect the scoped diff without modifying unrelated workspace changes.
