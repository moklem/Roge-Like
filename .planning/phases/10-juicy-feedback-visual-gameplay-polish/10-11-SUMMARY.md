---
phase: 10-juicy-feedback-visual-gameplay-polish
plan: 11
subsystem: gameplay-vfx
tags: [godot, gdscript, tween, cpuparticles2d, evolution, multiplayer-rpc]

# Dependency graph
requires:
  - phase: 10-juicy-feedback-visual-gameplay-polish
    provides: "Juice.gd facade (element_color, add_trauma, spawn_burst, hitstop) from Plan 10-01"
provides:
  - "Evolution transform closure moment (PROG-03/D-14): ~0.5s element-colored charge-up glow build-up followed by a sprite swap + element-colored burst + brief hit-stop reveal, hooked into the existing set_evolution_stage RPC"
affects: [any future plan touching Player.gd modulate/evolution-stage code]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Guard-flag pattern for per-frame modulate ownership: _evolution_transform_active mirrors the existing _hit_flash_active / _downed_collapse_active convention so a multi-stage cosmetic Tween can own `modulate` across both the char-sprite and legacy-Sprite _process paths without being stomped every frame."
    - "Charge-then-reveal Tween composition: tween_method for a continuous glow ramp, ending in tween_callback that fires the reveal (sprite swap + burst + hit-stop) — same non-blocking Tween idiom as _show_dash_shockwave/_play_downed_collapse, extended to a two-phase sequence."

key-files:
  created: []
  modified:
    - scenes/Player.gd

key-decisions:
  - "Charge-up ramps modulate via Color.WHITE.lerp(element_color, t) scaled by (1 + t*0.6) for a brightening glow rather than a pulsing oscillation — reads as a build-up without needing a second animation curve, and stays trivially non-blocking (single linear tween_method call)."
  - "Owner-only rising shake implemented as a per-frame Juice.add_trauma(0.015) call inside the charge tween_method (not a separate timer) — Juice's existing trauma decay (2.5/sec) naturally shapes it into a felt 'rising' build rather than a instant spike, reusing the existing shake pipeline with zero new state."
  - "Reveal burst amount/lifetime (20 particles, 0.5s) and hit-stop duration (0.08s) chosen within the D-06 'subtle & snappy' target band already established for other hit-stop call sites in this phase."

requirements-completed: [PROG-03]

coverage:
  - id: D1
    description: "set_evolution_stage begins a ~0.5s non-blocking, element-colored charge-up glow build-up (with owner-gated rising shake) before the stage reveal, visible identically on every peer via the existing broadcast RPC"
    requirement: "PROG-03"
    verification:
      - kind: unit
        ref: "grep verification (func set_evolution_stage / Juice.element_color / Juice.add_trauma / is_multiplayer_authority all present in scenes/Player.gd; zero get_tree().paused / SceneTree.paused tokens)"
        status: pass
      - kind: integration
        ref: "Godot headless boot check (--import + --quit-after 60) — zero ERROR/SCRIPT ERROR/Parse Error lines"
        status: pass
    human_judgment: true
    rationale: "Visual feel of the charge-up glow ramp and shake build-up (whether it 'reads' as a satisfying transform beat, not a cutscene) requires a human watching the game in motion — static grep/boot checks can only confirm the code path exists and loads cleanly, not that the timing/intensity feels right."
  - id: D2
    description: "The charge-up-then-reveal sequence fires _swap_stage_visual + an element-colored Juice.spawn_burst + a brief Juice.hitstop at the end of the charge-up via tween_callback, restores modulate afterward, stays within the ~1-1.5s cap, and never touches Engine.time_scale, SceneTree.paused, Camera2D, or input — for the transforming player or any teammate"
    requirement: "PROG-03"
    verification:
      - kind: unit
        ref: "grep verification (_swap_stage_visual / Juice.spawn_burst / Juice.hitstop / tween_callback all present; zero Engine.time_scale / get_tree().paused / SceneTree.paused tokens)"
        status: pass
      - kind: integration
        ref: "Godot headless boot check (--import + --quit-after 60) — zero ERROR/SCRIPT ERROR/Parse Error lines"
        status: pass
    human_judgment: true
    rationale: "Confirming the transform never freezes input or locks the camera for teammates still fighting live, and that the total ~0.65s sequence feels capped/non-blocking rather than a cutscene, is an experiential/agency judgment call that requires a human playtesting live co-op, not a static check."

# Metrics
duration: 35min
completed: 2026-07-13
status: complete
---

# Phase 10 Plan 11: Evolution Transform Closure Moment Summary

**Charge-up-then-reveal evolution transform (PROG-03/D-14) hooked into the existing `set_evolution_stage` RPC — a ~0.5s element-colored glow ramp with owner-gated rising shake, then a `tween_callback`-fired sprite swap + element-colored `CPUParticles2D` burst + brief cosmetic hit-stop, fully non-blocking for every peer.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-07-13T21:49:43Z
- **Tasks:** 2/2 completed
- **Files modified:** 1 (`scenes/Player.gd`)

## Accomplishments

- `set_evolution_stage` now starts a ~0.5s non-blocking charge-up: sprite `modulate` ramps from white toward `Juice.element_color(element)` with a brightening glow-scale multiplier, visible identically on every peer since `set_evolution_stage` already broadcasts via RPC.
- Owner-only rising shake build-up during the charge-up, gated `is_multiplayer_authority()` — a teammate's screen never shakes for someone else's transform.
- At the end of the charge-up (via `tween_callback`), the reveal fires the existing `_swap_stage_visual(stage)` (unchanged, deferred for physics safety) plus an element-colored `Juice.spawn_burst` and a brief `Juice.hitstop(0.08)`, then a restore tween returns `modulate` to `Color.WHITE`.
- Added a new `_evolution_transform_active` guard flag (mirroring the existing `_hit_flash_active`/`_downed_collapse_active` convention) so the per-frame modulate reset in both the `_uses_char_sprite` (`_update_char_visual`) and legacy `$Sprite` (`_process`) paths does not stomp the charge/reveal tween.
- No `SceneTree.paused`, no `Engine.time_scale`, no `Camera2D` change, no input disable anywhere in the new code — confirmed by comment-stripped greps and by a real Godot headless boot check.

## Task Commits

Each task was committed atomically:

1. **Task 1: ~0.5s charge-up build-up hooked into set_evolution_stage (D-14)** - `89e0301` (feat)
2. **Task 2: Element-colored reveal burst + sprite swap, capped and non-blocking (PROG-03, D-14)** - `b2fddf8` (feat)

_Note: no plan-metadata commit is created by this executor — the orchestrator owns STATE.md/ROADMAP.md writes after merge per this plan's execution contract._

## Files Created/Modified
- `scenes/Player.gd` - Added `_evolution_transform_active` guard var; extended both per-frame modulate-reset guards (`_process` and `_update_char_visual`) to respect it; replaced the immediate `call_deferred("_swap_stage_visual", stage)` in `set_evolution_stage` with `_play_evolution_transform(stage)` (charge-up Tween) and a new `_reveal_evolution_stage(stage, target, color)` helper (reveal: swap + burst + hit-stop + modulate restore).

## Decisions Made
- Glow ramp uses a brightening lerp-toward-element-color curve (not oscillating pulse) — simplest non-blocking `tween_method` implementation that still reads as a charge-up.
- Rising shake reuses `Juice.add_trauma` called every charge-tween frame rather than adding new shake-curve state to `Juice.gd` — the existing trauma decay already shapes it into a felt build-up.
- Reveal constants (20-particle burst, 0.5s lifetime, 0.08s hit-stop) chosen to match the phase's established "subtle & snappy" (D-06) feel rather than introducing a separate tuning table.

## Deviations from Plan

None - plan executed exactly as written. Both tasks matched their described action/verify/acceptance criteria without requiring bug fixes, missing-functionality additions, or architectural changes.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Mandatory Build Verification

Ran the required Godot 4.6.3 headless boot check from the worktree root (per this plan's mandatory verification gate):

```
"$GODOT" --headless --path . --import 2>&1 | grep -iE 'ERROR|Parse Error'
# (no output — zero import errors)

"$GODOT" --headless --path . --quit-after 60 2>&1 | grep -viE '^(Godot Engine|OpenGL|Vulkan|Metal|--- Debug|Using |Shader cache|TextServer|WARNING: Blocking|^$)'
# (no output beyond the version banner — zero ERROR/SCRIPT ERROR/Parse Error lines)
```

Full `--import` output showed the normal asset-reimport pipeline (scripts registering `UiStyle`, `HitFlash`, `ImpactBurst`, `RoomBuilder`, `RoomLayouts`, then all textures/audio/fonts) with no `ERROR`/`Parse Error` lines. Full `--quit-after 60` output was just the `Godot Engine v4.6.3.stable.official.7d41c59c4` banner line and nothing else — a clean headless boot and quit with zero error output.

No generated `.uid` files appeared (`git status --short` was empty after both task commits).

## Next Phase Readiness

- The evolution transform closure moment is complete and this was the last (highest agency-risk) plan of Phase 10's wave 5/6 sequencing.
- No blockers. The transform composes cleanly with the existing hit-flash/downed-collapse modulate-guard convention already established by earlier Phase 10 plans, so future juice work touching `Player.gd` modulate should extend the same guard-flag pattern rather than adding a parallel one.

## Self-Check: PASSED

- FOUND: scenes/Player.gd (exists, modified as described)
- FOUND: 89e0301 (Task 1 commit, verified via `git log --oneline --all`)
- FOUND: b2fddf8 (Task 2 commit, verified via `git log --oneline --all`)
- Godot headless boot check: CLEAN (zero ERROR/SCRIPT ERROR/Parse Error lines in both `--import` and `--quit-after 60` runs)

---
*Phase: 10-juicy-feedback-visual-gameplay-polish*
*Completed: 2026-07-13*
