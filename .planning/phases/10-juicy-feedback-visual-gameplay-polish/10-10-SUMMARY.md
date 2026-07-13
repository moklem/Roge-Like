---
phase: 10-juicy-feedback-visual-gameplay-polish
plan: 10
subsystem: gameplay
tags: [godot, gdscript, multiplayer-rpc, coop, vfx, particles]

# Dependency graph
requires:
  - phase: 10-01
    provides: Juice.gd facade (spawn_burst, element_color, FxLayer resolution)
  - phase: 10-09
    provides: prior wave-4 juice conventions this plan mirrors
provides:
  - Live GameEvents.player_downed/player_revived signals (previously scaffolded, unused)
  - GameEvents.big_hit(pos) team-visible broadcast primitive
  - Player downed collapse (tip/desaturate/dust), team-visible revive ring, revive success burst
  - Team-visible big-hit cue broadcast from the significant-hit trigger site
affects: [future co-op juice/VFX phases, any phase touching downed/revive/significant-hit flow]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CanvasItem draw signal idiom for custom world-space drawing on a plain Node2D child (no subclass needed)"
    - "Widening a single-target rpc_id RPC to any_peer/call_local when Player nodes are deterministically named (Player_%d)"

key-files:
  created: []
  modified:
    - autoloads/GameEvents.gd
    - scenes/Player.gd
    - scenes/Game.gd

key-decisions:
  - "Host-authoritative emit_player_downed/emit_player_revived calls are guarded by multiplayer.is_server() exactly as the plan's acceptance criteria specify, matching the emit_hud authority+call_local RPC shape"
  - "Revive progress ring implemented via a lazily-created Node2D child using the CanvasItem draw signal + draw_arc, rather than a full custom CanvasItem subclass"
  - "Big-hit team cue reuses Juice.spawn_burst/ImpactBurst (white, amount 20) instead of inventing a new particle factory"

patterns-established:
  - "Team-visible broadcast RPCs mirror GameEvents.emit_hud's authority+call_local+reliable shape exactly"

requirements-completed: [COOP-01, COOP-02, COOP-03, COOP-05]

coverage:
  - id: D1
    description: "Downed players show a team-visible collapse (tip 90deg + desaturate + dust puff)"
    requirement: "COOP-01"
    verification:
      - kind: manual_procedural
        ref: "Boot Game.tscn headless (--quit-after 60) with GameEvents/Player.gd/Game.gd all parsing cleanly; live multiplayer downed/collapse visual requires a running co-op session to observe"
        status: unknown
    human_judgment: true
    rationale: "Visual/animation timing (tween easing, particle look) requires a human to observe an actual co-op play session; static/headless checks only confirm the code parses and loads without error"
  - id: D2
    description: "Reviving shows a team-visible circular progress ring, not just to the two involved players"
    requirement: "COOP-02"
    verification:
      - kind: manual_procedural
        ref: "grep verification confirms set_revive_progress widened to any_peer/call_local and Game._update_revive_bar calls .rpc() (broadcast, no residual rpc_id); visual ring rendering requires live co-op observation"
        status: unknown
    human_judgment: true
    rationale: "Team-visibility of the world-space draw_arc ring across multiple connected clients requires a human to run a multi-peer session and observe"
  - id: D3
    description: "A successful revive triggers a team-visible green success burst + snap-back"
    requirement: "COOP-03"
    verification:
      - kind: manual_procedural
        ref: "Code review + grep confirms Juice.spawn_burst call and rotation/modulate snap-back tween on the is_downed falling edge"
        status: unknown
    human_judgment: true
    rationale: "Visual burst/tween appearance requires human observation of a live revive"
  - id: D4
    description: "A significant/big hit triggers team-visible feedback via a broadcast at the hit position"
    requirement: "COOP-05"
    verification:
      - kind: manual_procedural
        ref: "grep verification confirms emit_big_hit wired end-to-end (Player.receive_damage -> Game.notify_significant_hit(pos) -> GameEvents.emit_big_hit.rpc(pos) -> Game._on_big_hit -> Juice.spawn_burst)"
        status: unknown
    human_judgment: true
    rationale: "Team-wide visibility of the hit-position cue requires a live multi-peer session to observe"
  - id: D5
    description: "The scaffolded GameEvents.player_downed/player_revived signals are now emitted at host-authoritative sites"
    requirement: "COOP-01"
    verification:
      - kind: unit
        ref: "grep -qE 'emit_player_downed|emit_player_revived' scenes/Player.gd (Task 2 automated verify)"
        status: pass
    human_judgment: false

# Metrics
duration: 45min
completed: 2026-07-13
status: complete
---

# Phase 10 Plan 10: Downed/Revive/Big-Hit Team-Visible Juice Summary

**Wires the scaffolded GameEvents.player_downed/player_revived signals and adds a team-visible downed collapse, revive progress ring, revive success burst, and big-hit broadcast — all riding existing replicated state or the emit_hud authority/call_local RPC shape.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-07-13T20:59:00Z (approx.)
- **Completed:** 2026-07-13T21:44:24Z
- **Tasks:** 3/3 completed
- **Files modified:** 3

## Accomplishments
- `GameEvents.gd`: `emit_player_downed`/`emit_player_revived` RPCs light up the previously scaffolded (`@warning_ignore("unused_signal")`) signals; new `signal big_hit(pos: Vector2)` + `emit_big_hit(pos)` RPC, mirroring `emit_hud` exactly (`authority`/`call_local`/`reliable`)
- `Player.gd`: `_last_downed` edge-detector drives a team-visible collapse (90deg tip + desaturate tween + brown/grey dust puff) on the `is_downed` rising edge, and a green success burst + white ring flash + snap-back tween on the falling edge — both from the already-replicated `is_downed` diff (zero new RPC)
- `Player.gd`: `set_revive_progress` widened from `any_peer/call_remote` to `any_peer/call_local`; now draws a world-space blue `draw_arc` progress ring (radius ~28px, 4px stroke) on a lazily-created `ReviveRing` child, in addition to the existing `$ReviveBar`
- `Player.gd`: host-authoritative `_enter_downed`/`revive` sites now call `GameEvents.emit_player_downed.rpc(peer_id)` / `emit_player_revived.rpc(peer_id)`, guarded by `multiplayer.is_server()`
- `Game.gd`: `_update_revive_bar` now broadcasts via `p.set_revive_progress.rpc(progress)` (no residual single-target `rpc_id`); `notify_significant_hit` threads an optional `pos` param through the existing `SUSPENSION_DEBOUNCE` and fires `GameEvents.emit_big_hit.rpc(pos)`; `Game._ready()` connects `GameEvents.big_hit` to a new `_on_big_hit` handler that renders the shared cue via `Juice.spawn_burst`
- `Player.receive_damage`'s `from_elite` call site now threads `global_position` through to `notify_significant_hit`, both for the host-direct call and the `rpc_id(1, ...)` client-routed call

## Task Commits

Each task was committed atomically:

1. **Task 1: GameEvents — light up player_downed/player_revived + add big_hit broadcast** - `e1b5050` (feat)
2. **Task 2: Player — downed collapse, team-visible revive ring, revive success burst** - `871ec17` (feat)
3. **Task 3: Game — broadcast revive progress, thread big-hit position, render big_hit on every peer** - `35d0eda` (feat)

_No TDD tasks — all three are `tdd="false"`._

## Files Created/Modified
- `autoloads/GameEvents.gd` - Live `emit_player_downed`/`emit_player_revived` RPCs, new `big_hit(pos)` signal + `emit_big_hit` RPC
- `scenes/Player.gd` - Downed collapse/success juice on the `is_downed` diff, widened team-visible revive ring, host-side downed/revived signal emits, `receive_damage` threads `global_position` to `notify_significant_hit`
- `scenes/Game.gd` - Broadcasted revive-progress RPC, `notify_significant_hit(pos)`, `big_hit` local render handler wired in `_ready()`

## Decisions Made
- Followed the plan's literal acceptance criteria for the `multiplayer.is_server()` guard on `emit_player_downed`/`emit_player_revived` calls at the `_enter_downed`/`revive` sites, matching the `emit_hud` authority/call_local RPC convention used throughout the codebase.
- Implemented the revive-progress ring using the CanvasItem `draw` signal on a plain `Node2D` child (`ReviveRing`) rather than writing a dedicated subclass script file — keeps the change contained to `Player.gd` per the plan's `files_modified` scope.
- Reused `Juice.spawn_burst`/`ImpactBurst.build` for both the revive-success burst and the big-hit team cue rather than adding a new particle factory (per the threat register's T-10-24 mitigation).

## Deviations from Plan

None - plan executed exactly as written. All three tasks' automated `<verify>` grep checks passed on first attempt.

## Issues Encountered

None during implementation. During the mandatory Godot boot verification, loading `scenes/Game.tscn` directly (headless, `--quit-after 60`, beyond the mandated default-scene check) produced a generic engine-level `WARNING: ObjectDB instances leaked at exit` / `ERROR: 1 resources still in use at exit` pair. This is unrelated to script correctness: `grep` for `SCRIPT ERROR`, `Parse Error`, `Invalid get index`, `Nonexistent function`, and `null instance` patterns against that log returned zero matches. This scene expects lobby-provided multiplayer/session state (`GameState.start_room`, spawner registration, etc.) that isn't present when loading the scene standalone, and abruptly cutting the scene off mid-load via `--quit-after` is a known source of this generic resource-cleanup noise, independent of the changes in this plan (none of the new `is_downed`/revive-ring/big-hit code paths execute without an actual multiplayer session and spawned Player nodes, neither of which exist in this standalone load).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `GameEvents.player_downed`/`player_revived`/`big_hit` are now live, host-authoritative broadcast primitives available to any future co-op juice work.
- The `set_revive_progress` broadcast pattern (widening a single-target `rpc_id` to `any_peer/call_local` when targeting a deterministically-named node) is now an established precedent for future team-visibility fixes.
- No blockers for subsequent phase-10 plans.

---
*Phase: 10-juicy-feedback-visual-gameplay-polish*
*Completed: 2026-07-13*

## Self-Check

**1. Created/modified files exist:**
- FOUND: autoloads/GameEvents.gd
- FOUND: scenes/Player.gd
- FOUND: scenes/Game.gd

**2. Commits exist in git log:**
- FOUND: e1b5050 (Task 1: GameEvents)
- FOUND: 871ec17 (Task 2: Player)
- FOUND: 35d0eda (Task 3: Game)

**3. Automated `<verify>` grep checks (all three tasks):** PASS (see Task Commits above; each task's exact verify command from PLAN.md was re-run and returned success)

**4. Godot headless boot verification (mandatory):**
- `Godot --headless --path . --import 2>&1 | grep -iE 'ERROR|Parse Error'` → **zero output** (clean)
- `Godot --headless --path . --quit-after 60 2>&1 | grep -viE '^(Godot Engine|OpenGL|Vulkan|Metal|--- Debug|Using |Shader cache|TextServer|WARNING: Blocking|^$)'` → **zero output** (clean; this boots the project's default/main scene, which loads the `GameEvents`/`Juice` autoloads modified/consumed by this plan)
- Additional diligence: `Godot --headless --path . res://scenes/Game.tscn --quit-after 60` (directly loads `Player.gd`/`Game.gd`, which the default-scene check above does not reach) → produced only a generic `WARNING: ObjectDB instances leaked at exit` / `ERROR: 1 resources still in use at exit` pair (engine-level cleanup noise from abruptly cutting off a scene mid-load, not a script error — confirmed via targeted grep for `SCRIPT ERROR`/`Parse Error`/`Invalid get index`/`Nonexistent function`/`null instance`, all zero matches).

## Self-Check: PASSED
