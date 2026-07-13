---
phase: 10-juicy-feedback-visual-gameplay-polish
plan: 09
subsystem: gameplay-vfx
tags: [godot, gdscript, multiplayer-synchronizer, cpuparticles2d, tween, juice-facade]

requires:
  - phase: 10-juicy-feedback-visual-gameplay-polish
    provides: "Juice autoload facade (spawn_burst, element_color, _fx_layer) from 10-01; Player.gd hit-flash guard (_hit_flash_active) from 10-04"
provides:
  - "Speedster dash afterimage trail (ABIL-02) on the dash_invincible diff"
  - "Tank aura expanding ring pulse (ABIL-04) on the shield_active rising edge"
  - "Engineer heal green sparkle rise confirmed team-visible (ABIL-03, COOP-04)"
  - "Engineer drone deploy pop-in burst + ring (ABIL-05) in HealDrone._ready()"
affects: [gameplay-vfx, role-abilities, engineer, tank, speedster]

tech-stack:
  added: []
  patterns:
    - "Ability-juice-on-replicated-diff: cosmetic reactions to already-replicated bool
       fields (dash_invincible, shield_active) fired from the every-peer _process, never
       gated behind is_multiplayer_authority(), so every peer renders the effect with
       zero new RPCs."
    - "Spawner-replicated _ready() juice: one-shot deploy effects hooked into a spawned
       node's _ready() run identically on every peer via MultiplayerSpawner, so no RPC is
       needed for spawn-moment VFX."

key-files:
  created: []
  modified:
    - scenes/Player.gd
    - scenes/roles/HealDrone.gd

key-decisions:
  - "Dash afterimages clone the player's current visual (AnimatedSprite2D frame texture or ColorRect fallback) rather than reusing a shared ghost scene, keeping the effect self-contained in Player.gd alongside the existing _show_dash_shockwave precedent."
  - "Aura ring pulse reuses the Tank shield's established blue (Color(0.3, 0.6, 1.0)) at lower alpha rather than Juice.element_color(element), so the pulse reads as part of the same shield identity already shown by the solid ring."
  - "Drone deploy effect combines Juice.spawn_burst() (particle pop) with a manually-built ColorRect ring tween (not a Juice API) since Juice has no ring-pulse helper yet — mirrors the _show_dash_shockwave/aura-pulse ring shape for visual consistency."

patterns-established:
  - "Ring-pulse ColorRect tween shape (pivot-centered, scale 0.2-0.3 -> ~1.5, modulate:a -> 0 in parallel, ~0.35-0.4s) reused across Player.gd (aura) and HealDrone.gd (deploy) — a Juice.spawn_ring() helper would be the natural next-wave extraction if a fourth consumer appears."

requirements-completed: [ABIL-02, ABIL-03, ABIL-04, ABIL-05, COOP-04]

coverage:
  - id: D1
    description: "Speedster dash leaves a fading afterimage trail (3-4 ghosts, ~0.3s fade) visible on every peer"
    requirement: ABIL-02
    verification:
      - kind: manual_procedural
        ref: "Godot headless boot check (--import + --quit-after 60) clean; grep confirms _last_dash_invincible/_spawn_dash_afterimage wired into the every-peer _process diff on dash_invincible"
        status: pass
    human_judgment: true
    rationale: "Visual timing/readability (ghost count, fade curve, alpha) requires eyes-on verification in a live multiplayer session; headless boot only proves the script loads without error."
  - id: D2
    description: "Tank aura shows an expanding soft ring pulse in the aura color on shield activation"
    requirement: ABIL-04
    verification:
      - kind: manual_procedural
        ref: "Godot headless boot check clean; grep confirms _last_shield_active rising-edge check calls _spawn_aura_pulse()"
        status: pass
    human_judgment: true
    rationale: "Ring pulse timing/color legibility against the existing solid shield ring requires visual judgment."
  - id: D3
    description: "Engineer heal produces a team-visible green sparkle rise on the healed player"
    requirement: "ABIL-03, COOP-04"
    verification:
      - kind: manual_procedural
        ref: "Code inspection confirms _spawn_heal_particles() fires from the every-peer health-increase _process branch (line ~269-270), never authority-gated"
        status: pass
    human_judgment: false
  - id: D4
    description: "Engineer drone deployment shows a pop-in burst + ring at the deploy point on all peers"
    requirement: ABIL-05
    verification:
      - kind: manual_procedural
        ref: "Godot headless boot check clean; grep confirms HealDrone._ready() calls _spawn_deploy_effect() (Juice.spawn_burst + ring tween)"
        status: pass
    human_judgment: true
    rationale: "Visual pop-in timing and ring legibility at the drone's deploy point requires eyes-on verification in a live session."

duration: 15min
completed: 2026-07-13
status: complete
---

# Phase 10 Plan 09: Role-Ability Juice (Dash Trail, Aura Pulse, Heal Sparkle, Drone Deploy) Summary

**Speedster dash afterimages, Tank aura ring pulse, and Engineer drone deploy burst added as zero-RPC cosmetic reactions to already-replicated Player fields (dash_invincible, shield_active) and a spawner-replicated HealDrone._ready(); the existing heal-sparkle path was confirmed to already satisfy team-visible healing (COOP-04).**

## Performance

- **Duration:** ~15 min
- **Tasks:** 3/3 completed
- **Files modified:** 2

## Accomplishments
- Speedster's dash leaves a 3-4-ghost fading afterimage trail (ABIL-02), rendered from the every-peer `_process` diff on `dash_invincible` with zero new RPC.
- Tank's aura pulses with an expanding soft blue ring (ABIL-04) on the `shield_active` false→true rising edge.
- Engineer's heal green sparkle rise (ABIL-03) was confirmed to already fire un-gated in the every-peer health-increase branch, making it inherently team-visible (COOP-04) per D-17.
- Engineer drone deployment now shows a pop-in particle burst + expanding ring (ABIL-05) hooked into `HealDrone._ready()`, which runs identically on every peer via the MultiplayerSpawner.

## Task Commits

Each task was committed atomically:

1. **Task 1: Speedster dash afterimage trail (ABIL-02, D-20)** - `a0eae0a` (feat)
2. **Task 2: Tank aura ring pulse + team-visible Engineer heal sparkle (ABIL-04, ABIL-03, COOP-04)** - `a0d990c` (feat)
3. **Task 3: Engineer drone deploy burst + ring (ABIL-05, D-20)** - `0663e37` (feat)

_Note: no plan-metadata commit is included here — the orchestrator owns STATE.md/ROADMAP.md writes after merge (per this plan's execution instructions)._

## Files Created/Modified
- `scenes/Player.gd` - Added `_last_dash_invincible`/`_afterimage_timer` + `_spawn_dash_afterimage()` (ghost clone of the current visual, FxLayer-parented, 0.3s fade); added `_last_shield_active` + `_spawn_aura_pulse()` (expanding blue ring, 0.4s expand-and-fade); confirmed/documented `_spawn_heal_particles()` as the team-visible ABIL-03/COOP-04 path.
- `scenes/roles/HealDrone.gd` - Added `_spawn_deploy_effect()` called from `_ready()`: `Juice.spawn_burst()` pop + a brief expanding ring tween (0.35s) at the drone's spawn position.

## Decisions Made
- Dash afterimage ghosts clone the live visual (AnimatedSprite2D current frame texture, or a ColorRect fallback for any future non-char-sprite role) rather than using a dedicated ghost scene — keeps the effect self-contained and consistent with the existing `_show_dash_shockwave` precedent in the same file.
- Aura ring pulse color reuses the Tank shield's own blue (`Color(0.3, 0.6, 1.0)`) at reduced alpha instead of `Juice.element_color(element)`, so the pulse reads as part of the shield's established visual identity rather than the player's elemental color.
- The drone deploy effect combines `Juice.spawn_burst()` (existing facade API) with a hand-built ring tween (mirroring the aura-pulse/dash-shockwave shape), since `Juice.gd` does not yet expose a ring-pulse helper. If a fourth ring consumer appears in a later phase, extracting a `Juice.spawn_ring()` helper would be the natural next step.

## Deviations from Plan

None - plan executed exactly as written. Task 2's "confirm/adjust `_spawn_heal_particles`" instruction required no functional code change (the existing green upward one-shot CPUParticles2D burst already satisfies ABIL-03/COOP-04); only a doc-comment was added for traceability.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Self-Check: PASSED

**Files verified:**
- `scenes/Player.gd` - FOUND
- `scenes/roles/HealDrone.gd` - FOUND

**Commits verified (git log --oneline --all):**
- `a0eae0a` - FOUND
- `a0d990c` - FOUND
- `0663e37` - FOUND

**Godot headless boot check (mandatory build verification):**
```
$ "/Applications/Godot 2.app/Contents/MacOS/Godot" --headless --path . --import 2>&1 | grep -iE 'ERROR|Parse Error'
(no output — zero matches)

$ "/Applications/Godot 2.app/Contents/MacOS/Godot" --headless --path . --quit-after 60 2>&1 \
    | grep -viE '^(Godot Engine|OpenGL|Vulkan|Metal|--- Debug|Using |Shader cache|TextServer|WARNING: Blocking|^$)'
(no output — zero ERROR/SCRIPT ERROR/Parse Error lines; only the Godot Engine version
banner line was present in the raw log, filtered out by the noise-exclusion pattern)
```
Both commands completed with exit code 0 and produced zero ERROR / SCRIPT ERROR / Parse Error lines. Real headless boot confirmed clean — this is not a grep-only static check.

No new `.uid` files were generated by the import pass (`git status --short` was empty after `--import`).

## Next Phase Readiness

All four ABIL-02/03/04/05 + COOP-04 role-ability juice deliverables are in place with zero new RPCs, extending the established every-peer diff-watch (`Player._process`) and spawner-replicated `_ready()` (`HealDrone`) idioms. No STATE.md/ROADMAP.md changes were made — the orchestrator updates those after merge. No blockers for subsequent phase-10 plans.

---
*Phase: 10-juicy-feedback-visual-gameplay-polish*
*Plan: 09*
*Completed: 2026-07-13*
