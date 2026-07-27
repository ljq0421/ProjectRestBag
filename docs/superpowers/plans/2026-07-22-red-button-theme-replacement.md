# Red Operation Button Theme Replacement Plan

**Goal:** Replace every in-scope text operation button with the approved five-state red skin while preserving layout, behavior, and all excluded content/icon controls.

**Architecture:** Add one normalized `button_red` runtime texture family to the existing skin builder. Reuse those textures through action and toggle `StyleBoxTexture` resources in the centralized theme. Existing semantic text-button variations resolve to the action style; toggle text controls receive a dedicated selected-state variation. Controls that currently share a text-button variation but are excluded receive an explicit legacy/content variation so their appearance does not change.

## Task 1: Lock the scope with regression checks

- Add Python coverage for source mapping, per-state normalization, transparent-RGB cleanup, exact runtime size, and aligned alpha bounds.
- Extend the Godot theme self-check with red action/toggle texture paths and state mappings.
- Add a focused static coverage check for included and excluded representative controls.

## Task 2: Generate normalized five-state runtime textures

- Register `resources/ui/skin_v1/button_red_*_v1.png` as the source family.
- Crop each state by its alpha bounds, scale uniformly to the common height, and adjust only the flat center strip to reach the common width.
- Clear RGB values where alpha is zero and write deterministic RGBA outputs.
- Keep all five outputs at one size with identical outer alpha bounds.

## Task 3: Integrate action and selected themes

- Add red action and red toggle `StyleBoxTexture` resources with common texture and content margins.
- Point primary, secondary, flat, and danger text-button variations to the red action styles.
- Add a dedicated red toggle variation that maps persistent pressed states to `selected`.
- Preserve the legacy flat/primary visuals through explicit content/icon-exclusion variations where an excluded control currently shares a text semantic family.
- Use light text colors for every red background state.

## Task 4: Bind all in-scope text operation buttons

- Apply the red action variation to unthemed scene buttons that perform text actions.
- Apply the red toggle variation to one-line text filters and mode selectors.
- Leave tabs, cards, task entries, inventory/research/production/showcase cells, device content badges, popup backdrops, close/paging/plus-minus controls, and icon-only launchers unchanged.
- Do not change node names, dimensions, layout flags, signals, scripts, or business logic.

## Task 5: Verify and review

- Run the Python generator tests and builder check with the bundled Pillow runtime.
- Run focused Godot headless checks with an explicit writable `--log-file`.
- Run static scope audits and `git diff --check`.
- Inspect representative runtime textures/screens for stable corners, borders, alpha, and state alignment.
- Review the final diff against the pre-existing dirty worktree and report any baseline failures separately.
