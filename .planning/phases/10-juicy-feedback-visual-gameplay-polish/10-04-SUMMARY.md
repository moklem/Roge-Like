---
phase: 10-juicy-feedback-visual-gameplay-polish
plan: 04
subsystem: ui
tags: [godot, gdscript, juice, screen-shake, hit-flash, hp-bar, particles]

requires:
  - phase: 10-juicy-feedback-visual-gameplay-polish
    provides: "Juice autoload (add_trauma, flash, spawn_burst, element_color) and FxLayer from Plan 10-01"
provides:
  - "Player red/white hit-flash on the health-decrease diff (DMG-02)"
  - "Capped, local-authority-only screen shake via Juice.add_trauma on player damage (DMG-03)"
  - "Player HP-bar ghost chip-away matching the Enemy.gd treatment (DMG-04, D-07)"
  - "Element-colored level-up burst on the is_picking_card rising edge (PROG-01, D-13)"
affects: [10-05, 10-06, 10-07, 10-08]

tech-stack:
  added: []
  patterns:
    - "Pattern-A diff-watch reactions on already-replicated Player fields (health, is_picking_card) — zero new RPCs"
    - "_hit_flash_active guard flag to prevent a per-frame modulate reset from fighting a Juice.flash tween on the same node"

key-files:
  created: []
  modified:
    - scenes/Player.gd

key-decisions:
  - "Screen shake trauma amount tuned to 0.25 per contact hit for a short, sharp bump consistent with D-06 subtle-and-snappy target"
  - "Reused the exact ghost-chip ColorRect/tween approach from Enemy.gd (Plan 10-03) rather than introducing a second helper, per the plan's shared-treatment requirement"

patterns-established:
  - "_hit_flash_active flag: any node whose modulate is also written unconditionally every frame must gate that write behind an active-flash flag, or a Juice.flash tween on the same node is invisible (overwritten the very next frame)"

requirements-completed: [DMG-02, DMG-03, DMG-04, PROG-01]

coverage:
  - id: D1
    description: "Local player's sprite flashes red/white briefly when taking damage (DMG-02)"
    requirement: "DMG-02"
    verification:
      - kind: other
        ref: "grep -q 'Juice.flash' scenes/Player.gd; headless Godot boot check clean"
        status: pass
    human_judgment: true
    rationale: "Visual timing/color feel of the flash needs a human to confirm it reads correctly in-game; static grep + boot check only proves the code path exists and loads without error."
  - id: D2
    description: "Screen shakes briefly and capped on local damage, driven only by that peer's own Camera2D (DMG-03)"
    requirement: "DMG-03"
    verification:
      - kind: other
        ref: "grep -q 'is_multiplayer_authority' scenes/Player.gd (gates Juice.add_trauma); headless Godot boot check clean"
        status: pass
    human_judgment: true
    rationale: "Multiplayer isolation (a teammate's hit never shaking your own screen) requires a two-peer manual/UAT session to observe; cannot be proven by a single-process headless boot check."
  - id: D3
    description: "Player HP bar shows ghost chip-away drain on damage instead of only snapping (DMG-04)"
    requirement: "DMG-04"
    verification:
      - kind: other
        ref: "grep -qi 'ghost' scenes/Player.gd; headless Godot boot check clean"
        status: pass
    human_judgment: true
    rationale: "Visual drain timing/appearance needs human confirmation against the enemy bar's treatment for consistency; static checks only confirm the code exists and loads."
  - id: D4
    description: "Leveling up triggers an element-colored burst around the player, visible on every peer (PROG-01)"
    requirement: "PROG-01"
    verification:
      - kind: other
        ref: "grep -q 'Juice.spawn_burst' scenes/Player.gd; headless Godot boot check clean"
        status: pass
    human_judgment: true
    rationale: "Cross-peer visibility and correct element coloring require a live multiplayer UAT session to observe; not provable via static analysis or single-process boot check."

duration: 6min
completed: 2026-07-13
status: complete
---

# Phase 10 Plan 04: Player Hit-Flash, Self-Shake, HP Ghost-Chip & Level-Up Burst Summary

**Extended Player._process's existing health/is_picking_card diff-watch with a red/white hit-flash, capped local-authority-only screen shake, an Enemy-matching HP ghost-chip drain, and an element-colored level-up burst — all four zero-new-RPC Pattern-A reactions on already-replicated fields.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-13T22:48:53+02:00 (worktree base)
- **Completed:** 2026-07-13T22:54:47+02:00
- **Tasks:** 3
- **Files modified:** 1

## Accomplishments
- Player sprite flashes red/white (`Color(1.0, 0.3, 0.25, 1.0)`, 0.15s) on any health-decrease frame, on every peer, via `Juice.flash`
- Capped screen shake via `Juice.add_trauma(0.25)` fires only when `is_multiplayer_authority()` is true, so a teammate's damage never shakes your own camera (Pitfall 5)
- Player `$HealthBar` now ghost chip-aways on damage: primary fill still snaps instantly, and a `Color(1.0, 0.3, 0.25, 0.85)` ghost segment shrinks/fades over ~0.4s, matching Enemy.gd's Plan 10-03 treatment exactly
- Level-up burst: `_last_picking_card` diff-watch fires `Juice.spawn_burst(global_position, Juice.element_color(element))` on the `is_picking_card` false→true rising edge, visible on every peer with zero new RPCs

## Task Commits

Each task was committed atomically:

1. **Task 1: Player hit-flash + capped self-shake on the health-decrease diff** - `364824f` (feat)
2. **Task 2: Player HP-bar ghost chip-away** - `6e1cc2c` (feat)
3. **Task 3: Element-colored level-up burst on the is_picking_card diff** - `69ffd68` (feat)

_Note: no plan-metadata commit — the orchestrator, not this executor, owns STATE.md/ROADMAP.md writes after merge (per this plan's parallel-execution contract)._

## Files Created/Modified
- `scenes/Player.gd` - Health-decrease diff branch (hit-flash + capped self-shake + HP ghost-chip), `_update_health_ghost` helper (mirrors Enemy.gd), `_last_picking_card` diff-watch driving the level-up burst, `_hit_flash_active` guard fixing a modulate-reset conflict

## Decisions Made
- Screen-shake trauma amount for a normal contact hit set to `0.25` (Claude's discretion per plan, tuned against the "subtle & snappy" D-06 target)
- Ghost-chip overlay reuses the identical `ColorRect` + parallel-tween construction from `Enemy.gd` (position/size in the `ProgressBar`'s local 0..size.x space, same colors/timings) rather than inventing a new visual, per the plan's "shared helper/treatment" intent — implemented as a parallel method on `Player.gd` rather than a literally shared function, since `Player.gd` and `Enemy.gd` have no common base class to host one

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Guarded the pre-existing per-frame modulate reset so it doesn't cancel the new hit-flash tween**
- **Found during:** Task 1 (Player hit-flash + capped self-shake)
- **Issue:** `Player._process` already unconditionally rewrites the sprite's `modulate` every frame in two places — the non-char `$Sprite` branch (`is_downed` tint / `Color.WHITE`) and the end of `_update_char_visual` for the animated `$CharSprite` path. `Juice.flash` (via `HitFlash.flash`) starts a tween that interpolates `modulate` over 0.15s. Since the existing per-frame reset runs at the *start* of `_process` every frame — including the frame immediately after the flash tween begins — it would immediately stomp the tween's in-progress color back to white/tint, making the flash effectively invisible (at most a partial single-frame artifact) instead of the intended visible 0.15s pop.
- **Fix:** Added a `_hit_flash_active: bool` field, set `true` when the flash is triggered and cleared `false` via a 0.15s one-shot timer (matching the flash duration). Both pre-existing per-frame modulate-reset sites (`_process`'s non-char branch, now `elif not _hit_flash_active:`, and the last line of `_update_char_visual`) now skip their write while a flash is active, letting the tween own `modulate` for its full duration.
- **Files modified:** scenes/Player.gd
- **Verification:** Headless Godot boot check (`--import` then `--quit-after 60`) clean with zero ERROR/SCRIPT ERROR/Parse Error lines after the fix; the guard logic was traced by hand against the exact per-frame write order in `_process`/`_update_char_visual`.
- **Committed in:** 364824f (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** Necessary for the plan's own DMG-02 acceptance criterion ("flashes the local player's sprite red/white") to actually be observable — without the fix the flash call would exist in code but not read correctly on screen. No scope creep; the fix is scoped entirely to the modulate-write conflict this plan's own change introduced.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `Player.gd` now has the full player-side combat/progression juice reaction set (flash, capped self-shake, HP ghost-chip, level-up burst) ready for later waves (evolution burst in a later plan can reuse the same `element_color`/`spawn_burst` calls)
- Multiplayer isolation of screen shake (Pitfall 5) and cross-peer visibility of the level-up burst are flagged `human_judgment: true` in the coverage block above — a live two-peer UAT session is recommended before this plan is considered fully verified end-to-end
- No blockers for downstream plans (10-05 onward)

## Self-Check: PASSED

- `scenes/Player.gd` FOUND (modified, present on disk)
- Commit `364824f` FOUND in `git log --oneline --all`
- Commit `6e1cc2c` FOUND in `git log --oneline --all`
- Commit `69ffd68` FOUND in `git log --oneline --all`
- Static verify greps for all 3 tasks: PASS (`health < _last_health_seen`, `Juice.flash`, `Juice.add_trauma`, `is_multiplayer_authority`, `ghost`, `HealthBar`, `_last_picking_card`, `Juice.spawn_burst`, `Juice.element_color`)
- Godot headless `--import` pass: zero ERROR/Parse Error lines
- Godot headless `--quit-after 60` boot pass: zero ERROR/SCRIPT ERROR/Parse Error lines (filtered against the standard benign-line allowlist)
- Both boot checks were re-run at each intermediate commit point (after Task 1, Task 2, Task 3) to confirm no incremental breakage, not just at the final state

---
*Phase: 10-juicy-feedback-visual-gameplay-polish*
*Completed: 2026-07-13*
