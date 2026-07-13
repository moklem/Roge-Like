---
phase: 10-juicy-feedback-visual-gameplay-polish
plan: 02
subsystem: infra
tags: [godot, audio-bus, audiostreamplayer, audioserver]

# Dependency graph
requires: []
provides:
  - "default_bus_layout.tres declaring Master/Music/SFX buses (Music and SFX both send to Master)"
  - "Sfx.gd pooled players routed to the SFX bus (was Master)"
  - "Music.gd player routed to the Music bus (was Master)"
affects: [10-01, 10-05, 10-12]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Hand-authored AudioBusLayout .tres resource (no in-repo analog existed prior to this plan)"

key-files:
  created:
    - default_bus_layout.tres
  modified:
    - autoloads/Sfx.gd
    - autoloads/Music.gd

key-decisions:
  - "Hand-authored the AudioBusLayout resource directly (no spaces around '=' in key/value pairs) rather than requiring a Godot editor session, per RESEARCH.md Open Question 1's fallback guidance"

patterns-established:
  - "Standard AudioBusLayout resource schema (bus/N/name, solo, mute, bypass_fx, volume_db, send) for any future bus additions"

requirements-completed: [DMG-08]

coverage:
  - id: D1
    description: "default_bus_layout.tres exists with Master (index 0), Music (index 1, send=Master), SFX (index 2, send=Master)"
    requirement: "DMG-08"
    verification:
      - kind: unit
        ref: "grep-based file-content check (see plan Task 1 <verify> block) — type=\"AudioBusLayout\", bus/1/name=\"Music\", bus/2/name=\"SFX\", bus/1/send=\"Master\", bus/2/send=\"Master\""
        status: pass
    human_judgment: false
  - id: D2
    description: "Sfx.gd pooled players assigned to SFX bus, Music.gd player assigned to Music bus, no residual Master references, safe-load pattern unchanged"
    requirement: "DMG-08"
    verification:
      - kind: unit
        ref: "grep-based file-content check (see plan Task 2 <verify> block) — p.bus = \"SFX\" in Sfx.gd, _player.bus = \"Music\" in Music.gd, zero \"Master\" occurrences in Sfx.gd, zero _player.bus = \"Master\" in Music.gd"
        status: pass
    human_judgment: true
    rationale: "Runtime audibility of the sliders driving these buses is deferred to the Plan 10-12 human-verify gate (per plan's own <verification> note) — this plan only proves static routing correctness, not that audio is actually audible/attenuated at runtime."

# Metrics
duration: 2min
completed: 2026-07-13
status: complete
---

# Phase 10 Plan 02: Audio Bus Foundation Summary

**Hand-authored `default_bus_layout.tres` (Master/Music/SFX) and reassigned Sfx.gd/Music.gd off the hard-coded Master bus, unblocking the DMG-08 Settings-panel volume sliders.**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-07-13T18:42:21Z
- **Completed:** 2026-07-13T18:43:14Z
- **Tasks:** 2 completed
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- Created `default_bus_layout.tres` at the project root defining three buses: `Master` (index 0), `Music` (index 1, routed `send="Master"`), `SFX` (index 2, routed `send="Master"`) — all at 0 dB, unmuted, no solo/bypass.
- Reassigned `autoloads/Sfx.gd`'s pooled `AudioStreamPlayer` instances from `bus = "Master"` to `bus = "SFX"`.
- Reassigned `autoloads/Music.gd`'s single player from `_player.bus = "Master"` to `_player.bus = "Music"`.
- Preserved the existing safe-load pattern (`ResourceLoader.exists` / `_try_load`) in both files unchanged — a missing audio file still degrades to silence, never a crash.

## Task Commits

Each task was committed atomically:

1. **Task 1: Author default_bus_layout.tres with Master, Music, SFX buses** - `0f4fe0b` (feat)
2. **Task 2: Reassign Sfx.gd and Music.gd off Master onto the new buses** - `94f13d4` (feat)

_Note: No TDD tasks in this plan — both tasks used automated grep-based verification per their `<verify>` blocks._

## Files Created/Modified
- `default_bus_layout.tres` - New AudioBusLayout resource defining Master/Music/SFX buses (Music/SFX send to Master)
- `autoloads/Sfx.gd` - Pooled players now route to the SFX bus instead of Master
- `autoloads/Music.gd` - Player now routes to the Music bus instead of Master

## Decisions Made
- Hand-authored the `.tres` file directly rather than requiring a live Godot editor session (RESEARCH.md's Open Question 1 flagged this as the primary approach, with an editor session as fallback only if hand-authoring failed to parse). The resource follows the standard `AudioBusLayout` schema (`bus/N/name`, `solo`, `mute`, `bypass_fx`, `volume_db`, `send`) with no spaces around `=` — this is valid Godot resource-file syntax and satisfies the plan's exact automated verification grep patterns.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `AudioServer.get_bus_index("Music")` and `AudioServer.get_bus_index("SFX")` will resolve to valid indices once Godot loads this project (the bus layout is auto-loaded from `res://default_bus_layout.tres` at startup), unblocking Plan 10-05's `Settings.gd` volume-slider wiring (`set_music_volume`/`set_sfx_volume` per RESEARCH.md's Code Examples).
- Runtime audibility of the buses (do the sliders actually attenuate Music/SFX playback) is intentionally deferred to the Plan 10-12 human-verify gate, per this plan's own `<verification>` section — this plan only guarantees static routing correctness.
- No blockers for downstream plans (10-01 Juice engine, 10-05 Settings panel).

---
*Phase: 10-juicy-feedback-visual-gameplay-polish*
*Completed: 2026-07-13*
