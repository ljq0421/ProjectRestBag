# Challenge Onboarding Verification

Date: 2026-07-27

## Automated evidence

| Path | Result | Evidence |
|---|---|---|
| New/missing save | PASS | `ChallengeSaveService.empty_save()` exposes onboarding version 1; aggregate and save self-checks pass. |
| Real drag | PASS | `challenge_tutorial_input_self_check.gd` uses `Input.parse_input_event` press/motion/release, observes the card drag signal and `gui_is_dragging()`, and places milk pudding through the board drop handler. |
| Real rotation | PASS | The same real-input path right-clicks the occupied pudding cell and reaches `read_risk`. |
| Victory | PASS | `challenge_tutorial_route_self_check.gd` verifies report exit advances victory to completion. |
| Retryable loss | PASS | Route/progress checks verify a retryable loss waits for a valid changed draft fingerprint. |
| Terminal loss | PASS | Route/progress checks verify terminal-loss report exit completes without deadlock. |
| Dismiss/resume/replay | PASS | `challenge_tutorial_replay_self_check.gd` verifies persisted dismissal and session-only completed replay. |
| Full challenge suite | PASS | All 16 `tests/challenge/*_self_check.gd` tests exited 0, printed explicit PASS markers, and logged no `ERROR:`, `SCRIPT ERROR:`, parse, or load errors. |
| Default scene smoke | PASS | Three-second headless default-scene smoke exited 0 with no scanned project errors. |

## Visual evidence

The bounded runtime session was verified to use `D:/Project/ProjectRest/project-rest-two/.worktrees/challenge-onboarding/`. All seven durable evidence files below are direct viewport captures from that runtime: valid PNG signature, literal `1920x1080` dimensions, and checked after writing. Their controlled fixture is ignored under `.superpowers`; it uses a unique `user://challenge_tutorial_visual_<mode>.json` save plus the existing `ChallengeRunService`, `start_battle()`, and `advance_battle_for_test(30000)` paths. It changes no production source, default save, reward, inventory, or reset behavior.

| Required state | Status | Evidence / observation |
|---|---|---|
| Boss brief spotlight | OBSERVED | [01-boss-brief.png](2026-07-27-challenge-onboarding/01-boss-brief.png) — readable Boss brief, intended spotlight, and top-bar `?`; root overlay only. |
| Supply-to-board drag target | OBSERVED | [02-supply-to-board.png](2026-07-27-challenge-onboarding/02-supply-to-board.png) — supply strip and board target are highlighted; hint is in bounds. |
| Placed pudding rotation target | OBSERVED | [03-pudding-rotation.png](2026-07-27-challenge-onboarding/03-pudding-rotation.png) — placed pudding and the right-click rotation step are visible. |
| Battle dual-pressure spotlight | OBSERVED | [04-battle-dual-pressure.png](2026-07-27-challenge-onboarding/04-battle-dual-pressure.png) — confidence and Boss-pressure regions are both targeted. |
| Retryable-loss report spotlight | OBSERVED | [05-retryable-loss-report.png](2026-07-27-challenge-onboarding/05-retryable-loss-report.png) — loss report and retry action are visible; no simultaneous root overlay. |
| Victory report spotlight | OBSERVED | [06-victory-report.png](2026-07-27-challenge-onboarding/06-victory-report.png) — success report and conclusion are visible. |
| Completion card and top-bar `?` | OBSERVED | [07-completion-card.png](2026-07-27-challenge-onboarding/07-completion-card.png) — completion card is in bounds and the replay `?` remains visible. |

The direct PNG fixture was required only to preserve reviewable evidence; the actual interaction contract remains covered by the dedicated real `Input.parse_input_event` self-check rather than fixture shortcuts.

## Human observation

| Question | Status | Observation |
|---|---|---|
| Player understands drag and rotation without explanation | PENDING | Requires human playtest. |
| Player can identify the failed demand window | PENDING | Requires human playtest. |
| Player chooses to rearrange after failure | PENDING | Requires human playtest. |

## Gate

- Automated implementation gate: PASS.
- Visual acceptance gate: PASS for the seven required runtime states, with literal 1920x1080 PNG evidence retained in this repository.
- Product-hand-feel gate: NO-GO until the three human observations are recorded.
