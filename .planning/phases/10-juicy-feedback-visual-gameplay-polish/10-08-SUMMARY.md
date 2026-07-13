---
phase: 10-juicy-feedback-visual-gameplay-polish
plan: 08
subsystem: gameplay-vfx
tags: [godot4, multiplayer-replication, cpuparticles2d, tween, scenereplicationconfig]

requires:
  - phase: 10-juicy-feedback-visual-gameplay-polish
    provides: "Plan 10-01 Juice.gd facade (element_color lookup, spawn_burst/FxLayer pool, flash/hitstop)"
  - phase: 10-juicy-feedback-visual-gameplay-polish
    provides: "Plan 10-03 Enemy.gd damage-number/hit-flash/HP-ghost hook (_damage_number_color())"
provides:
  - "Fixed the confirmed host-only burn/slow status-visibility bug (ABIL-01): is_burning/is_slowed now replicate via SceneReplicationConfig"
  - "Element-colored damage numbers + fire/ice hit burst for burning/slowed enemies (DMG-07)"
  - "Cosmetic enemy spawn-in materialize telegraph inherited by EliteEnemy/Boss (ABIL-06)"
affects: [enemies, multiplayer-sync, combat-feedback]

tech-stack:
  added: []
  patterns:
    - "Diff replicated boolean flags in _process() (runs on every peer) instead of writing modulate directly inside host-only _physics_process — the general fix pattern for any future host-only-authority-vs-client-visibility gap"
    - "Split modulate into RGB (status tint, driven every _process frame) vs alpha (spawn-telegraph fade-in tween) so two independent cosmetic systems never fight over the same property"

key-files:
  created: []
  modified:
    - scenes/enemies/Enemy.gd
    - scenes/enemies/Enemy.tscn

key-decisions:
  - "Status tint reassignment in _process only touches modulate.r/g/b, leaving modulate.a untouched, so it never conflicts with the spawn-telegraph fade-in tween (which animates modulate:a) or an in-flight HitFlash tween"
  - "Element hit burst reuses the existing _damage_number_color() helper's return value directly (amount=8, lifetime=0.4s) rather than a second color lookup, per the plan's 'never a second uncapped spawn path' constraint"
  - "Spawn telegraph ground ring is a plain ColorRect + Tween (mirrors the existing _show_dash_shockwave precedent in Player.gd) parented to /root/Game/FxLayer, not Juice.spawn_burst, since the shape/animation (expanding ring, not particle scatter) doesn't fit the ImpactBurst factory"

requirements-completed: [ABIL-01, DMG-07, ABIL-06]

coverage:
  - id: D1
    description: "Enemy burn (Fire) and slow (Ice) status tints replicate to every peer, not just the host (ABIL-01 sync gap fixed); DoT tick / speed_multiplier math stays host-only"
    requirement: "ABIL-01"
    verification:
      - kind: unit
        ref: "grep verification: is_burning/is_slowed replicated fields + properties/3,4 in SceneReplicationConfig_1 + _process tint reaction"
        status: pass
      - kind: other
        ref: "Godot 4.6.3 headless boot check (--import + --quit-after 60), zero ERROR/SCRIPT ERROR/Parse Error lines"
        status: pass
    human_judgment: true
    rationale: "Multiplayer client-visibility behavior (does the tint actually appear on a connected client's screen) requires a live two-peer session to observe visually; static grep + single-process boot check confirm the code loads and the replication config is structurally correct, not the cross-peer rendering itself."
  - id: D2
    description: "Hitting a burning/slowed enemy shows an element-colored impact burst (fire embers / ice shards) plus an element-colored damage number, burst-only ~0.4s"
    requirement: "DMG-07"
    verification:
      - kind: unit
        ref: "grep verification: _damage_number_color() returns Juice.element_color(fire/ice), Juice.spawn_burst call gated on is_burning/is_slowed"
        status: pass
      - kind: other
        ref: "Godot 4.6.3 headless boot check, zero errors"
        status: pass
    human_judgment: true
    rationale: "Visual color/particle correctness (burst reads as fire embers vs ice shards, timing feels right) is a subjective in-game visual judgment call, not something a headless boot check or grep can assess."
  - id: D3
    description: "Newly spawned enemies show a brief cosmetic materialize telegraph (fade-in + expanding ground ring) while remaining active immediately"
    requirement: "ABIL-06"
    verification:
      - kind: unit
        ref: "grep verification: _ready() calls _play_spawn_telegraph(), modulate.a tween with set_ignore_time_scale, ring Tween parented to FxLayer"
        status: pass
      - kind: other
        ref: "Godot 4.6.3 headless boot check, zero errors"
        status: pass
    human_judgment: true
    rationale: "Confirming the enemy is genuinely active immediately (no perceptible gameplay delay) alongside the fade-in/ring visual requires observing actual gameplay, not just reading the code path."

duration: 35min
completed: 2026-07-13
status: complete
---

# Phase 10 Plan 08: Status-Sync Fix + Element Hit VFX + Spawn Telegraph Summary

**Fixed the live host-only burn/slow visibility bug by replicating two booleans and moving the tint reaction to `_process`, then layered element-colored hit VFX and a cosmetic enemy spawn telegraph on top of the corrected sync state.**

## Performance

- **Duration:** 35 min
- **Started:** 2026-07-13T20:53:00Z
- **Completed:** 2026-07-13T21:28:00Z
- **Tasks:** 3/3 completed
- **Files modified:** 2

## Accomplishments
- Fixed ABIL-01: `is_burning`/`is_slowed` are now replicated fields (`SceneReplicationConfig_1` properties/3, properties/4); the tint write moved out of the host-only `_physics_process`/`apply_burn`/`apply_slow`/`_tick_status_effects` path and into `Enemy._process()`, which already runs identically on every peer. Burn DoT tick and slow `speed_multiplier` math are untouched and remain host-only.
- Built DMG-07 on top of the corrected sync state: `_damage_number_color()` (the hook Plan 10-03 left specifically for this) now returns `Juice.element_color("fire"/"ice")` from the replicated flags, and the existing damage branch in `_process` spawns a ~0.4s element-colored `Juice.spawn_burst` for burning/slowed enemies — burst-only, no ground decal, no new RPC.
- Added ABIL-06's cosmetic enemy spawn telegraph to `Enemy._ready()`: a ~0.4s `modulate.a` fade-in (`set_ignore_time_scale(true)`) plus a brief expanding neutral ground ring (`ColorRect` + `Tween`, mirroring the existing `_show_dash_shockwave` idiom in `Player.gd`) parented to `FxLayer`. `EliteEnemy`/`Boss` inherit it automatically via their existing `super._ready()` calls — no subclass edits.

## Task Commits

Each task was committed atomically:

1. **Task 1: ABIL-01 — replicate is_burning/is_slowed and move the status tint to _process** - `a13e9f4` (fix)
2. **Task 2: DMG-07 — element-colored damage numbers + fire/ice element hit burst** - `d6723db` (feat)
3. **Task 3: ABIL-06 — cosmetic enemy spawn-in telegraph (D-19)** - `786bf43` (feat)

_Note: this plan has `tdd="false"` on all tasks; no test → feat → refactor cycle applies._

## Files Created/Modified
- `scenes/enemies/Enemy.gd` — added `is_burning`/`is_slowed` fields; `apply_burn`/`apply_slow`/`_tick_status_effects` now set/clear the flags instead of writing `modulate` directly; `_process` reacts to the flags (RGB-only tint reassignment) and spawns the element hit burst on the damage branch; `_damage_number_color()` extended to element-aware; `_ready()` now triggers `_play_spawn_telegraph()` (new function: fade-in tween + expanding ring parented to FxLayer).
- `scenes/enemies/Enemy.tscn` — `SceneReplicationConfig_1` gains `properties/3` (`is_burning`) and `properties/4` (`is_slowed`), both `spawn = true` / `replication_mode = 2`.

## Decisions Made
- Status tint reassignment in `_process` compares/writes only `modulate.r/g/b`, leaving `modulate.a` alone, specifically so it does not fight the spawn-telegraph's `modulate:a` fade-in tween or an in-flight `HitFlash` tween (both restore/animate the full `modulate` Color) — this was the plan's explicit guard requirement ("apply the status tint only when not mid hit-flash... reassert the status color as the resting modulate").
- The element hit burst reuses `_damage_number_color()`'s return value directly rather than a second color lookup or a hand-rolled fire/ice branch, keeping a single source of truth per the plan's "never a second uncapped spawn path" constraint.
- The spawn-telegraph ground ring uses a plain `ColorRect` + `Tween` (matching the existing `_show_dash_shockwave` precedent in `Player.gd`) rather than `Juice.spawn_burst`, since an expanding ring shape doesn't fit the `ImpactBurst` particle-scatter factory; it is still parented to `FxLayer`, not the enemy, per Pitfall 3/4.

## Deviations from Plan

None - plan executed exactly as written. All three tasks' automated verification greps passed on first implementation; no auto-fixes, blockers, or architectural questions arose.

## Issues Encountered

None. The main design risk called out in the plan — the status tint (task 1) potentially fighting the hit-flash (task 1) and the spawn-telegraph fade (task 3) — was resolved at implementation time by splitting `modulate`'s RGB channel (status tint) from its alpha channel (telegraph fade), so the two systems never write the same sub-property in the same frame.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Enemy status-effect visibility, element hit VFX, and spawn telegraph are all built on the now-corrected replication state; no blockers for later waves that depend on `is_burning`/`is_slowed` reads (e.g., any future ability juice referencing enemy status). Cross-peer visual verification (does the client screen actually show the tint/burst/telegraph in a live two-peer session) is flagged `human_judgment: true` in this SUMMARY's coverage block and should be exercised in a manual multiplayer UAT pass — static verification (grep + headless Godot boot) confirms code correctness and scene-parse validity but cannot observe cross-peer rendering.

## Self-Check

**Files verified:**
```
FOUND: scenes/enemies/Enemy.gd
FOUND: scenes/enemies/Enemy.tscn
```

**Commits verified:**
```
FOUND: a13e9f4
FOUND: d6723db
FOUND: 786bf43
```

**Godot headless boot check (mandatory, real engine load — not a grep-only check):**

`--import` pass:
```
(no output — zero ERROR / Parse Error lines)
```

`--quit-after 60` runtime boot pass (filtered for anything other than expected startup banner lines):
```
(no output — zero ERROR / SCRIPT ERROR / Parse Error lines after filtering standard startup banner noise)
```
Raw log tail confirms clean engine startup:
```
Godot Engine v4.6.3.stable.official.7d41c59c4 - https://godotengine.org
```

## Self-Check: PASSED

---
*Phase: 10-juicy-feedback-visual-gameplay-polish*
*Completed: 2026-07-13*
