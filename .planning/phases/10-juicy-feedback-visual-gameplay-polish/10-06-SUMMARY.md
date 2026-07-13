---
phase: 10-juicy-feedback-visual-gameplay-polish
plan: 06
subsystem: gameplay-vfx
tags: [godot, gdscript, tween, canvaslayer, multiplayer-cosmetic]

# Dependency graph
requires:
  - phase: 10-01
    provides: Juice.gd autoload facade + FxLayer convention (not needed directly by this plan, but the collection-feedback juice follows the same purely-cosmetic/no-new-RPC discipline it establishes)
provides:
  - Cosmetic XP-orb magnetism drifting orbs toward the nearest player within pickup range
  - Ghost-clone dart-to-bar travel effect with arrival-gated XP bar increase
affects: [phase-10-progression-moments, phase-10-final-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Cosmetic-only per-peer Node2D _process reacting to already-replicated group positions (no new sync/RPC)"
    - "Screen-space ghost-clone dart parented to the target CanvasLayer, converted from world position via viewport.get_canvas_transform()"

key-files:
  created: []
  modified:
    - scenes/pickups/XpOrb.gd
    - scenes/ui/PlayerHUD.gd

key-decisions:
  - "Dart destination computed via viewport.get_canvas_transform() * global_position, since PlayerHUD's CanvasLayer has an identity transform (no offset/scale), making its Control.global_position values directly comparable to converted world coordinates"
  - "Dart parented to the collecting player's own PlayerHUD CanvasLayer (not the orb, not FxLayer) so it survives the orb's queue_free() and stays in the same coordinate space as the XP bar"
  - "_find_nearest_player reused instead of a second search when spawning the dart — _on_body_entered already receives the collecting player as `body`, so no additional group scan was needed there"

patterns-established:
  - "Ghost-clone cosmetic effects for host-authoritative collection: real RPC/state path untouched, presentation reacts to the same event locally per peer"

requirements-completed: [PICK-01, PICK-02]

coverage:
  - id: D1
    description: "XP orbs cosmetically drift toward the nearest player within MAGNET_RADIUS at MAGNET_SPEED, on every peer, without touching the host-authoritative collection RPC"
    requirement: "PICK-01"
    verification:
      - kind: other
        ref: "Godot headless boot check (--import + --quit-after 60s) — zero ERROR/SCRIPT ERROR/Parse Error lines; static grep confirms _process/MAGNET_RADIUS/MAGNET_SPEED/get_nodes_in_group/_request_collect all present in scenes/pickups/XpOrb.gd"
        status: pass
    human_judgment: true
    rationale: "Visual drift quality/feel and in-game magnetism radius tuning require a human playtest to confirm it 'feels tactile' per the plan's intent — headless boot check only proves the script loads and parses without error, not that the visual behavior looks correct in a running session."
  - id: D2
    description: "Collecting an orb launches a ghost-clone dart to the local player's XP bar (~0.3s, TRANS_CUBIC/EASE_IN); the displayed bar value only rises inside arrive_xp() with a ~0.15s pulse, decoupled from the instantly-synced XP value; update_hud signature/call sites and the real host-authoritative collection RPC/XP value are unchanged"
    requirement: "PICK-02"
    verification:
      - kind: other
        ref: "Godot headless boot check (--import + --quit-after 60s) — zero ERROR/SCRIPT ERROR/Parse Error lines; static grep confirms _displayed_xp/arrive_xp in PlayerHUD.gd and dart/create_tween/arrive_xp in XpOrb.gd"
        status: pass
    human_judgment: true
    rationale: "Whether the dart visually lands on the XP bar and the pulse reads well in a real running session (screen-space coordinate conversion correctness in practice, not just at parse time) requires a human playtest — headless boot check cannot exercise runtime gameplay/rendering behavior."

# Metrics
duration: 25min
completed: 2026-07-13
status: complete
---

# Phase 10 Plan 06: XP Orb Magnetism + Dart-to-Bar Summary

**Cosmetic XP-orb magnetism (drift toward nearest player) and a ghost-clone dart-to-bar with arrival-gated XP bar increase, both purely additive over the unchanged host-authoritative collection RPC**

## Performance

- **Duration:** 25 min
- **Started:** 2026-07-13T20:47:00Z
- **Completed:** 2026-07-13T21:12:39Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments
- `XpOrb.gd` gains a local `_process(delta)` that drifts each orb toward the nearest `players`-group node once within `MAGNET_RADIUS` (90px) at `MAGNET_SPEED` (260px/s) — runs identically on every peer against already-replicated player positions, no new sync/RPC (PICK-01)
- `XpOrb.gd` spawns a cosmetic ghost-clone dart on the local collecting peer at the moment of collision, parented to that player's own `PlayerHUD` CanvasLayer, tweening in ~0.3s (`TRANS_CUBIC`/`EASE_IN`) from the orb's converted screen position to the XP bar; calls `arrive_xp()` on arrival, then frees itself with a backstop timer as a safety net (PICK-02, D-15)
- `PlayerHUD.gd` decouples the displayed XP bar value (`_displayed_xp`) from the instantly-synced target (`_target_xp`); `arrive_xp()` is now the only place the bar's value rises, with a short scale-pulse + Accent-color fill flash

## Task Commits

Each task was committed atomically:

1. **Task 1: XP orb magnetism — cosmetic drift toward the nearest player (PICK-01)** - `5420cae` (feat)
2. **Task 2: Dart-to-bar ghost clone + PlayerHUD arrival-gated bar increase (PICK-02, D-15)** - `33be9ec` (feat)

**Plan metadata:** committed alongside this SUMMARY

## Files Created/Modified
- `scenes/pickups/XpOrb.gd` - Added `MAGNET_RADIUS`/`MAGNET_SPEED` consts, `_magnetized` flag, `_process`/`_find_nearest_player` for cosmetic magnetism (PICK-01); added `_spawn_collection_dart` launched from `_on_body_entered` for the dart-to-bar ghost clone (PICK-02)
- `scenes/ui/PlayerHUD.gd` - Added `_displayed_xp`/`_target_xp` fields, decoupled `update_hud`'s bar-value drive, added `arrive_xp()` arrival-pulse method (PICK-02)

## Decisions Made
- Dart destination uses `viewport.get_canvas_transform() * global_position` to convert the orb's world position into the same screen-pixel space as the PlayerHUD CanvasLayer (which has an identity transform), so no camera/viewport lookup beyond the local `get_viewport()` call was needed
- Dart is parented to the collecting player's `PlayerHUD` CanvasLayer rather than `Juice._fx_layer()`, since the destination (XP bar) lives in that same CanvasLayer's coordinate space and the dart must survive the orb's `queue_free()`
- Reused the `body` parameter already passed into `_on_body_entered` as the dart's target player, avoiding a redundant group search

## Deviations from Plan

None - plan executed exactly as written. Both tasks were implemented per the `<action>` and `<acceptance_criteria>` blocks; the host-authoritative `_request_collect`/`_collected`/`peer_id` flow and `update_hud` signature/call sites are untouched.

## Issues Encountered

To keep each task's commit atomic despite both tasks touching `scenes/pickups/XpOrb.gd`, Task 2's dart-spawn code was written after Task 1's magnetism code but temporarily removed before the Task 1 commit, then reapplied before the Task 2 commit — this is a mechanical commit-sequencing detail, not a plan deviation; the final code is identical to a single-pass implementation.

## User Setup Required

None - no external service configuration required.

## Self-Check: PASSED

**Files verified:**
- FOUND: scenes/pickups/XpOrb.gd
- FOUND: scenes/ui/PlayerHUD.gd

**Commits verified:**
- FOUND: 5420cae (feat(10-06): XP orb cosmetic magnetism toward nearest player (PICK-01))
- FOUND: 33be9ec (feat(10-06): dart-to-bar ghost clone + arrival-gated XP bar increase (PICK-02, D-15))

**Static verification (plan's automated `<verify>` blocks):**
- Task 1: `_process`, `MAGNET_RADIUS`, `MAGNET_SPEED`, `get_nodes_in_group`, `_request_collect` all present in `scenes/pickups/XpOrb.gd` — PASS
- Task 2: `_displayed_xp`, `arrive_xp` present in `scenes/ui/PlayerHUD.gd`; dart/ghost/arrive_xp/create_tween present in `scenes/pickups/XpOrb.gd` — PASS

**Mandatory Godot headless boot check (real engine load, not just static grep):**
```
$ "/Applications/Godot 2.app/Contents/MacOS/Godot" --headless --path . --import 2>&1 | grep -iE 'ERROR|Parse Error'
(no output — zero matches)

$ "/Applications/Godot 2.app/Contents/MacOS/Godot" --headless --path . --quit-after 60 2>&1 \
    | grep -viE '^(Godot Engine|OpenGL|Vulkan|Metal|--- Debug|Using |Shader cache|TextServer|WARNING: Blocking|^$)'
(no output — zero unexpected lines)

Raw boot log:
Godot Engine v4.6.3.stable.official.7d41c59c4 - https://godotengine.org
```
No `ERROR`, `SCRIPT ERROR`, or `Parse Error` lines in either the import pass or the 60-second headless run. `git status --short` after both runs is clean (no stray `.uid` or generated files to commit).

## Next Phase Readiness
- PICK-01/PICK-02 collection feedback complete; host-authoritative collection RPC and true replicated team XP value are unchanged, so downstream progression-moment work (PROG-01–03, level-up burst, card overlay pop-in, evolution) can build on the same `update_hud` call sites without any migration
- No blockers. In-engine visual/feel verification (does the drift/dart look and feel right in a live multiplayer session) is deferred to human playtest per the `human_judgment: true` coverage entries above — headless boot check only proves the scripts load and parse cleanly.

---
*Phase: 10-juicy-feedback-visual-gameplay-polish*
*Completed: 2026-07-13*
