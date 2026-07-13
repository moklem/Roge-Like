---
phase: 10-juicy-feedback-visual-gameplay-polish
plan: 01
subsystem: game-feel
tags: [godot4, gdscript, cpuparticles2d, camera-shake, juice, autoload]

requires: []
provides:
  - "Juice autoload: element_color(), add_trauma()/screen shake, hitstop()/cosmetic_delta(), spawn_damage_number(), flash(), spawn_burst()"
  - "Settings autoload: per-client shake intensity (off/low/normal) + music/sfx volume (bus-safe no-op until Plan 10-02 creates buses)"
  - "scenes/vfx/ builders: ImpactBurst.gd (CPUParticles2D factory), HitFlash.gd (tween flash), DamageNumber.gd/.tscn (pooled world-space Label)"
  - "Persistent FxLayer Node2D under Game.tscn root, high z_index, sibling of Room1/Room2/Room3"
affects: [10-02, 10-03, 10-04, 10-05, 10-06, 10-07, 10-08, 10-09, 10-10, 10-11, 10-12]

tech-stack:
  added: []
  patterns:
    - "Trauma-accumulator screen shake (clamp 0..1, squared falloff) scoped to the local authority Camera2D only"
    - "Local cosmetic hit-stop float (Juice.cosmetic_delta()) — never Engine.time_scale, never SceneTree.paused"
    - "Fixed-size pooled damage numbers with same-target aggregation window, drop-silently-when-exhausted (no unbounded spawn)"
    - "Every transient VFX parents to the persistent FxLayer, never to the triggering node; backstop create_timer cleanup alongside each particle's own finished-signal cleanup"

key-files:
  created:
    - autoloads/Settings.gd
    - autoloads/Juice.gd
    - scenes/vfx/ImpactBurst.gd
    - scenes/vfx/HitFlash.gd
    - scenes/vfx/DamageNumber.gd
    - scenes/vfx/DamageNumber.tscn
  modified:
    - project.godot
    - scenes/Game.tscn

key-decisions:
  - "Damage-number pool built lazily on first spawn_damage_number() call (avoids requiring FxLayer to exist at Juice._ready() time, since Juice is a global autoload loaded before Game.tscn)"
  - "Pool slot reuse tracks two separate windows per entry: a short aggregate_until (100ms, for same-target-id summing) and a longer busy_until (600ms, full float+fade duration) so a slot mid-animation is never yanked for an unrelated new hit"
  - "FxLayer given z_as_relative = false + z_index = 100 so bursts/numbers render above gameplay regardless of nesting depth"

requirements-completed: [SYS-01, SYS-02, SYS-03]

coverage:
  - id: D1
    description: "Settings autoload: shake intensity (off/low/normal, default normal) + music/sfx volume with missing-bus safe no-op guard, registered in project.godot"
    requirement: "SYS-01"
    verification:
      - kind: other
        ref: "grep -q 'func shake_multiplier' autoloads/Settings.gd && grep -q 'func cycle_shake' ... && grep -q 'Settings=\"*res://autoloads/Settings.gd\"' project.godot"
        status: pass
    human_judgment: false
  - id: D2
    description: "scenes/vfx/ builders (ImpactBurst CPUParticles2D-only factory, HitFlash tween helper, DamageNumber pooled magnitude-scaled Label) + persistent FxLayer Node2D under Game.tscn"
    requirement: "SYS-01"
    verification:
      - kind: other
        ref: "test -f scenes/vfx/ImpactBurst.gd && ... && grep -q 'name=\"FxLayer\"' scenes/Game.tscn; sed 's/#.*//' ImpactBurst.gd | grep -c GPUParticles2D == 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "Juice autoload: element_color, trauma-based screen shake read from Settings.shake_multiplier(), local cosmetic hit-stop (no Engine.time_scale), pooled/aggregated damage numbers, flash/spawn_burst with backstop cleanup"
    requirement: "SYS-02"
    verification:
      - kind: other
        ref: "grep -q 'func element_color|add_trauma|hitstop|cosmetic_delta|spawn_damage_number|spawn_burst' autoloads/Juice.gd; sed 's/#.*//' Juice.gd | grep -c time_scale == 0; project.godot lists Juice="
        status: pass
    human_judgment: true
    rationale: "Runtime behavior (actual shake feel, hit-stop timing feel, pool exhaustion/aggregation under real swarm load, 15-min leak soak) cannot be verified by static grep alone — no Godot binary available in this environment to run the game headlessly. Static structural/textual verification passed; a human playtest is needed to confirm the 'subtle & snappy' feel target (D-06) and confirm no leaks over a real session (SYS-03), which downstream consuming plans (10-02+) will exercise."

duration: ~15min
completed: 2026-07-13
status: complete
---

# Phase 10 Plan 01: Foundational Juice Infrastructure Summary

**Juice + Settings autoloads (trauma-based screen shake, local cosmetic hit-stop, pooled/aggregated damage numbers, hit-flash, CPUParticles2D burst factory), scenes/vfx/ builders, and a persistent FxLayer node — the shared engine every later Phase 10 wave consumes.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-07-13T20:41:00+02:00 (approx, first task commit 20:43)
- **Completed:** 2026-07-13T20:48:00+02:00 (approx, last task commit 20:47)
- **Tasks:** 3/3
- **Files modified:** 8 (2 created autoloads, 4 created vfx files, 2 modified: project.godot, Game.tscn)

## Accomplishments
- `Settings.gd` client-only autoload: shake intensity enum (off/low/normal, default normal per D-10), music/sfx volume with a missing-bus safe no-op guard (so Plan 10-02's audio-bus creation isn't a hard dependency of this plan)
- `scenes/vfx/` builders: `ImpactBurst.gd` (parametrized one-shot CPUParticles2D factory, CPUParticles2D-only per SYS-01), `HitFlash.gd` (tween-based modulate flash, `set_ignore_time_scale(true)`), `DamageNumber.gd`/`.tscn` (pooled world-space Label — Bangers font + 4px ink outline, D-03 continuous font-size ramp, punch-scale pop, float+fade, hides itself rather than `queue_free()`)
- Persistent `FxLayer` Node2D added as a sibling of Room1/Room2/Room3 under the `Game` root, high `z_index` so all future bursts/numbers render above gameplay
- `Juice.gd` execution autoload: shared `element_color()` lookup (fire/ice/earth/white), trauma-accumulator screen shake (clamped 0..1, squared falloff, scoped to the local authority player's `Camera2D` only, scaled by `Settings.shake_multiplier()`), local cosmetic hit-stop (`hitstop()`/`cosmetic_delta()` — never `Engine.time_scale`), pooled/aggregated `spawn_damage_number()` (fixed pool of 24, 100ms same-target aggregation, drops silently when exhausted), `flash()`/`spawn_burst()` delegating to the new vfx builders with FxLayer parenting + backstop cleanup timers

## Task Commits

Each task was committed atomically:

1. **Task 1: Settings client-only autoload (shake intensity + volume state)** - `caf36b9` (feat)
2. **Task 2: scenes/vfx/ builders + FxLayer node in Game.tscn** - `e4b460d` (feat)
3. **Task 3: Juice execution autoload (shake, hit-stop, damage-number pool, flash, burst, cleanup)** - `1ae0ecb` (feat)

_No plan-metadata commit yet — this worktree plan omits STATE.md/ROADMAP.md updates per orchestrator convention; only this SUMMARY.md is committed alongside the task commits._

## Files Created/Modified
- `autoloads/Settings.gd` - per-client shake intensity + music/sfx volume, missing-bus safe guard
- `autoloads/Juice.gd` - shake/hit-stop/damage-number-pool/flash/burst execution facade, element-color lookup
- `scenes/vfx/ImpactBurst.gd` - parametrized one-shot CPUParticles2D factory (SYS-01)
- `scenes/vfx/HitFlash.gd` - tween-based CanvasItem modulate flash helper
- `scenes/vfx/DamageNumber.gd` - pooled world-space Label, magnitude-scaled font size, punch-pop + float + fade
- `scenes/vfx/DamageNumber.tscn` - Label scene wiring DamageNumber.gd
- `project.godot` - registered `Settings=` and `Juice=` autoload entries
- `scenes/Game.tscn` - added persistent `FxLayer` Node2D (z_index 100, z_as_relative false) as a sibling of Room1/Room2/Room3

## Decisions Made
- Damage-number pool is built lazily on the first `spawn_damage_number()` call (not in `Juice._ready()`), because `Juice` is a global autoload that initializes before `Game.tscn`/`FxLayer` exists (e.g. at the main menu) — lazy pool construction avoids a null-FxLayer crash and matches the plan's "returns null safely if absent" requirement for `_fx_layer()`.
- Damage-number pool-slot reuse tracks two separate expiry windows per entry: a short `aggregate_until` (100ms, governs same-`target_id` summing) and a longer `busy_until` (600ms, the full float+fade duration) — this prevents a slot that is still mid-animation for one hit from being visually yanked to a new position/text by an unrelated hit landing within the same 100ms window but on a different target.
- `FxLayer` given both a high `z_index` (100) and `z_as_relative = false` so draw order is deterministic regardless of future nesting changes under the `Game` root.

## Deviations from Plan

None - plan executed exactly as written. All three tasks' automated `<verify>` grep checks and manual `<acceptance_criteria>` checks passed as specified in 10-01-PLAN.md.

## Issues Encountered

No Godot binary was available in this execution environment to run a headless parse/scene-load check. All verification was static (grep-based structural checks specified in the plan's `<verify>` blocks, plus manual review of GDScript syntax against this codebase's existing conventions — e.g. `PackedScene.instantiate()` return-value member access and `get_node()` return-value type assignment both follow patterns already used unmodified elsewhere in `Game.gd`/`RoomBuilder.gd`). A first real in-editor/in-game load by a downstream consuming plan (10-02+) is the first opportunity to catch any GDScript parse error this static review missed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `Juice` + `Settings` autoloads exist, registered, and expose every function later waves need (`element_color`, `add_trauma`, `hitstop`/`cosmetic_delta`, `spawn_damage_number`, `flash`, `spawn_burst`).
- `FxLayer` exists under `Game.tscn` — every later wave's transient VFX has a stable parent to attach to.
- No gameplay file was touched this plan (by design) — Plan 10-02+ (Combat Feedback wave) is the first real consumer and should hook `Enemy.gd`/`Player.gd`'s existing diff-watch `_process` blocks into these new `Juice` calls.
- Known open dependency for a later wave (not this plan): the Settings-panel volume sliders (D-09) will remain a no-op until Plan 10-02 creates the "Music"/"SFX" audio buses (RESEARCH.md Pitfall 7) — `Settings.set_music_volume`/`set_sfx_volume` already guard for this (`idx >= 0`) so no crash risk, just silently inert until then.

---
*Phase: 10-juicy-feedback-visual-gameplay-polish*
*Completed: 2026-07-13*

## Self-Check: PASSED

All created files found on disk (autoloads/Settings.gd, autoloads/Juice.gd, scenes/vfx/ImpactBurst.gd, scenes/vfx/HitFlash.gd, scenes/vfx/DamageNumber.gd, scenes/vfx/DamageNumber.tscn, this SUMMARY.md). All task commit hashes (caf36b9, e4b460d, 1ae0ecb) and the summary commit (d3dc32a) confirmed present in git log.
