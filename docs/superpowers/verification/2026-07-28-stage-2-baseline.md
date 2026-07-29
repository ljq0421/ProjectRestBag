# Stage 2 Baseline

Date: 2026-07-28

## Project Rest Two

- Baseline commit: `bbad15b784b2d8fd8c68af68f3ffabee2633ad1a`
- Branch: `main`
- The only pre-implementation repository addition was the untracked Stage 2
  implementation plan:
  `docs/superpowers/plans/2026-07-28-backpack-boss-standard-short-chain.md`.

## Automated Regression Baseline

All 16 existing `tests/challenge/*_self_check.gd` scripts passed before Stage 2
game-code changes:

- Boss battle report
- Boss battle service
- Battle view
- Challenge board
- Board tutorial events
- Challenge configuration
- Challenge loadout
- Challenge main scene
- Challenge run service
- Challenge save service
- Tutorial input
- Tutorial overlay
- Tutorial progress
- Tutorial replay
- Tutorial route
- Vertical slice aggregate

Result: `BASELINE_TOTAL=16`, `BASELINE_FAILED=0`.

All runs used Godot 4.6.1 headless with an explicit writable `--log-file`.

## Source Project Isolation Baseline

`project-rest-new` was not clean when Stage 2 implementation began:

- HEAD: `147ce4b1e3c25e5608dd844fa4c00fd2c3e52323`
- Existing modified files:
  - `scripts/main_view.gd`
  - `tests/tutorial_guide_popup_self_check.gd`

These changes predate Stage 2 work and must remain untouched. Isolation checks
must compare against this recorded status rather than expecting an empty status.

## Product Evidence

Technical regression gate: **GO**.

Human product evidence remains a separate exit condition. Stage 2 engineering
may proceed, but Stage 3's 166-recipe migration remains blocked until the
required human observations are recorded.
