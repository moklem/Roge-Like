---
phase: 10-juicy-feedback-visual-gameplay-polish
plan: 03
subsystem: gameplay-vfx
tags: [godot4, multiplayer, cpuparticles2d, tween, juice-facade]

# Dependency graph
requires:
  - phase: 10-juicy-feedback-visual-gameplay-polish
    provides: "Plan 10-01 Juice autoload facade (spawn_damage_number, flash, spawn_burst, hitstop, element_color) and FxLayer/DamageNumber pool"
provides:
  - "Enemy._process diff-watch extended with pooled damage numbers, white hit-flash, and HP ghost chip-away — zero new RPCs"
  - "Enemy._exit_tree() death burst + kill hit-stop hook that runs on every peer via the replicated queue_free, guarded against purge-frees"
  - "_damage_number_color() hook (returns white) for Plan 10-08 to extend with is_burning/is_slowed"
affects: [10-04, 10-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Presentation-only reactions to already-replicated state (current_hp) run unguarded in _process/_exit_tree on every peer — no authority check, no new RPC"
    - "Ghost HP-bar overlay: a ColorRect child of the ProgressBar sharing its local coordinate space (0..size.x == value 0..100), tweened size:x -> 0 and color:a -> 0 in parallel, killed/restarted on repeat hits"
    - "Death VFX fires from _exit_tree (triggered identically on every peer by the host's replicated queue_free) rather than a per-node RPC, avoiding Pitfall 3/4 (randi()-named node RPC targeting, VFX racing the freed node)"

key-files:
  created: []
  modified:
    - scenes/enemies/Enemy.gd

key-decisions:
  - "Boss-vs-elite heavier hit-stop (0.12s) detected via `is_elite or has_method(\"_enter_phase\")` instead of adding a new is_boss flag — avoids touching Boss/EliteEnemy gameplay fields (is_elite already gates the SUSPENSION indicator elsewhere) while still giving Boss the weightier hit-stop"
  - "Ghost chip-away implemented as a runtime-created ColorRect (not a .tscn edit) since the plan's files_modified scope is Enemy.gd only; EliteEnemy.tscn/Boss.tscn inherit it automatically since they share the HealthBar node name and the Enemy.gd script"

patterns-established:
  - "Pattern: HP-bar ghost overlay as ProgressBar-child ColorRect + parallel Tween(size:x, color:a) — reusable as-is for the Player HP bar in Plan 10-04"

requirements-completed: [DMG-01, DMG-04, DMG-05, DMG-06]

coverage:
  - id: D1
    description: "Hitting an enemy spawns a pooled floating damage number and a white hit-flash, on host and client alike, via the existing current_hp diff-watch"
    requirement: "DMG-01"
    verification:
      - kind: other
        ref: "Godot headless boot check (--import + --quit-after 60): zero ERROR/Parse Error/SCRIPT ERROR lines after adding Juice.spawn_damage_number/Juice.flash calls to Enemy._process"
        status: pass
    human_judgment: true
    rationale: "Visual timing/readability of the damage number pop and flash requires a human to actually observe combat in a running client — a static boot check only proves the script parses and loads without runtime errors, not that the effect looks/reads correctly in play"
  - id: D2
    description: "An enemy's health bar shows a ghost chip-away when it loses HP rather than only snapping"
    requirement: "DMG-04"
    verification:
      - kind: other
        ref: "Godot headless boot check: zero errors after adding the ColorRect ghost child + Tween in Enemy._ready/_update_health_ghost"
        status: pass
    human_judgment: true
    rationale: "Ghost overlay shrink/fade timing (~0.4s) and visual correctness against a live ProgressBar can only be judged by watching it in play"
  - id: D3
    description: "Killing an enemy produces a CPUParticles2D burst at its position on every peer and a brief local cosmetic hit-stop, fired from a hook that runs on every peer using a captured position, never parented to the dying enemy node"
    requirement: "DMG-05, DMG-06"
    verification:
      - kind: other
        ref: "Godot headless boot check: zero errors after adding Enemy._exit_tree() (Juice.spawn_burst + Juice.hitstop); grep confirms no new rpc() added in Enemy.gd for the burst"
        status: pass
    human_judgment: true
    rationale: "Confirming the burst is genuinely parented to FxLayer (not self) and reads the correct color per enemy type, and that hit-stop feels right, requires observing an actual multiplayer kill — beyond what a static boot check can prove"

duration: 25min
completed: 2026-07-13
status: complete
---

# Phase 10 Plan 03: Enemy Combat Juice Summary

**Enemy._process diff-watch extended with pooled damage numbers, white hit-flash, and an HP ghost chip-away; new Enemy._exit_tree() fires a color-matched CPUParticles2D death burst plus a cosmetic kill hit-stop on every peer, all via the shared Juice facade with zero new RPCs.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-07-13T20:22:00Z
- **Completed:** 2026-07-13T20:47:15Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Enemy hits now spawn a pooled floating damage number (`Juice.spawn_damage_number`) and a white over-bright flash (`Juice.flash`) on the existing `current_hp < _last_hp_seen` diff branch — runs identically on host and clients, no new RPC.
- Added `_damage_number_color()` returning `Color.WHITE`, the single hook Plan 10-08 will extend for burning/slowed coloring.
- Added a reddish HP-bar ghost chip-away: a `ColorRect` child of `$HealthBar` spanning the old→new HP segment, tweened to shrink toward the new-value edge and fade to alpha 0 over ~0.4s, on the same damage frame the primary bar snaps.
- Added `Enemy._exit_tree()`: guarded to `current_hp <= 0` (so Game.gd's room-transition purge-free of enemies with HP remaining never triggers death VFX), reads the dying node's own live `$Sprite.color` (so normal/Elite/Boss bursts read differently with zero subclass edits), fires `Juice.spawn_burst` (parented to FxLayer, never to self) and `Juice.hitstop` (0.07s normal, 0.12s elite/boss).
- Death VFX fires via the MultiplayerSpawner-replicated `queue_free()` reaching every peer's `_exit_tree` independently — no per-enemy RPC, avoiding the "RPC-target a `randi()`-named node" anti-pattern.

## Task Commits

Each task was committed atomically:

1. **Task 1: Damage number + white hit-flash + HP ghost chip in Enemy._process** - `489573f` (feat)
2. **Task 2: Enemy death burst + kill hit-stop on every peer** - `e26764e` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `scenes/enemies/Enemy.gd` - `_damage_number_color()` hook; damage-number/flash/ghost-chip additions in `_process`; new `_health_ghost`/`_health_ghost_tween` fields + `_update_health_ghost()` helper; new `_exit_tree()` death-burst + hit-stop hook.

## Decisions Made
- Detected Boss for the heavier hit-stop via `has_method("_enter_phase")` rather than adding a new `is_boss` field, since `is_elite` is already load-bearing elsewhere (SUSPENSION indicator gating in `_on_hurtbox_body_entered`) and setting it on Boss would have been an unrelated gameplay change.
- Implemented the HP ghost chip-away as a runtime-created `ColorRect` (added as a child of `$HealthBar` in `_ready()`) rather than editing the `.tscn` files, since the plan scopes `files_modified` to `Enemy.gd` only; `EliteEnemy.tscn`/`Boss.tscn` both share the `HealthBar` node name and the same `Enemy.gd`-derived script, so they get the ghost bar automatically with no scene edits.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `_damage_number_color()` hook is ready for Plan 10-08 to extend with `is_burning`/`is_slowed` element coloring.
- The HP-bar ghost-chip pattern (ProgressBar-child ColorRect + parallel Tween) is directly reusable for the Player HP bar in Plan 10-04.
- Godot headless boot check (`--import` + `--quit-after 60`) reported zero `ERROR`/`Parse Error`/`SCRIPT ERROR` lines after both tasks; `git status --short` clean (no stray untracked files) after the boot run.

## Self-Check: PASSED

- `scenes/enemies/Enemy.gd` exists and contains `_damage_number_color`, `_update_health_ghost`, and `_exit_tree` (confirmed via grep after edits).
- Commit `489573f` found in `git log --oneline`.
- Commit `e26764e` found in `git log --oneline`.
- Godot headless boot check output (both commands, run from worktree root):
  - `Godot --headless --path . --import 2>&1 | grep -iE 'ERROR|Parse Error'` → no output (clean).
  - `Godot --headless --path . --quit-after 60 2>&1 | grep -viE '^(Godot Engine|OpenGL|Vulkan|Metal|--- Debug|Using |Shader cache|TextServer|WARNING: Blocking|^$)'` → no output (clean, no ERROR/SCRIPT ERROR/WARNING lines beyond the standard filtered boot banner).

---
*Phase: 10-juicy-feedback-visual-gameplay-polish*
*Completed: 2026-07-13*
