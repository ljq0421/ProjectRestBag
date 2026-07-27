# Backpack Boss Vertical Slice Playtest

Date: 2026-07-27
Build: `feature/backpack-boss-vertical-slice`

## Technical Build Evidence

These are deterministic automated runs, not human playtests.

| Run | Build direction | Supply | Relations | Window result | Final result | Confirmed decision |
|---|---|---:|---:|---|---|---|
| T-01 | Fast build: 3 butter cookies + 3 strawberry jellies | 12 / 16 | 0 | Early pass, relation fail, sustained pass | Timeout loss, 147 satisfaction | Fast pieces cover tempo but cannot clear 197 pickiness |
| T-02 | Set build: 2 puddings + 2 muffins + 2 cookies | 16 / 16 | 2 | All three windows pass | Victory at 30s, 212 satisfaction | Orthogonal drink/bake placement converts the same budget into a full clear |
| T-03 | Signature build: sponge + lava cake + 3 cookies | 16 / 16 | 0 | Early pass, relation fail, sustained pass | Victory at 30s, 225 satisfaction | Large 2x2 pieces trade board flexibility and one failed window for late power |

The aggregate release gate asserts all three rows from committed configuration and battle code.

## Human-Observed Runs

No human participant was available during implementation. The rows below are deliberately marked pending; automated execution is not counted as human observation.

| Run | Player familiarity | Build direction | Understood loop within 2 min | Identified exact loss cause | Chose to rearrange | Result |
|---|---|---|---|---|---|---|
| H-01 | Unfamiliar player required | Fast build | Pending observation | Pending observation | Pending observation | Not run |
| H-02 | Familiar player required | Set build | Pending observation | Pending observation | Pending observation | Not run |
| H-03 | Familiar player required | Signature build | Pending observation | Pending observation | Pending observation | Not run |

## Runtime Verification

- Confirmed the default project entry opens the new 1920×1080 preparation scene.
- Confirmed all 8s / 16s / 24s / 30s Boss timeline points are visible before battle.
- Confirmed the battle view visibly exposes the reputation defense and Boss pickiness pressure bars.
- Confirmed resolved demand windows show exact actual/target values and pass/fail color.
- Confirmed the failed report names `sustained_service` and displays `8 / 30`, recipe contribution, and fixed-rule suggestions.
- Confirmed first-loss state retains confidence 1 and the same encounter/seed.
- Confirmed interrupted battle state restores paused through automated scene coverage.
- The connected runtime input bridge and Windows high-DPI automation could not complete a trustworthy drag gesture. Drag/drop remains covered by the board scene contract, but human mouse verification is still required.

## Go/No-Go

- Technical Stage 1 gate: **GO**. All ten self-checks and the aggregate dependency scan pass with zero logged script errors.
- Product exit gate: **NO-GO pending human observation**.
- Continue only if the unfamiliar player identifies the failed window without developer explanation.
- Continue only if all three build directions produce a distinct placement decision.
- Stop and revise feedback if a player describes the result only as “数值不够”.
