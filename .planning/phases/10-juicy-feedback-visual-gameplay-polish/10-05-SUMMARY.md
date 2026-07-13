---
phase: 10-juicy-feedback-visual-gameplay-polish
plan: 05
subsystem: ui
tags: [godot, gdscript, comic-ui, settings, audio-bus, hslider]

requires:
  - phase: 10-juicy-feedback-visual-gameplay-polish
    provides: "Plan 10-01 Settings autoload (cycle_shake/set_music_volume/set_sfx_volume/shake_label) and Plan 10-02 Music/SFX audio buses"
provides:
  - "MainMenu Settings button opening a comic-styled Settings sub-panel"
  - "Shake off/low/normal cycle control wired to the Settings autoload"
  - "Music/SFX volume sliders wired to the Music/SFX audio buses via Settings"
affects: [10-12-human-verify-gate]

tech-stack:
  added: []
  patterns:
    - "Settings sub-panel as a hidden Panel sibling of the menu VBoxContainer, shown/hidden via a button pair"
    - "Grouped VBoxContainer rows (label + control) nested inside a top-level VBoxContainer for group-vs-row spacing"

key-files:
  created: []
  modified:
    - scenes/ui/MainMenu.tscn
    - scenes/ui/MainMenu.gd

key-decisions:
  - "SettingsPanel uses a native Panel node; comic_box() applied via add_theme_stylebox_override(\"panel\", ...) in _ready() rather than a bespoke stylebox in the .tscn"
  - "Settings sub-panel node tree groups each label+control pair into its own small VBoxContainer (ShakeGroup/MusicGroup/SfxGroup) so the outer VBox's 32px separation matches the UI-SPEC's between-group spacing exactly, while inner groups use 8px"

patterns-established:
  - "Settings sub-panel pattern: hidden Panel + VBox children, styled via UiStyle.comic_box/style_buttons/style_labels sweep, wired to the per-client Settings autoload"

requirements-completed: [DMG-08]

coverage:
  - id: D1
    description: "Settings button on MainMenu opens/closes a comic-styled SettingsPanel"
    requirement: "DMG-08"
    verification:
      - kind: other
        ref: "grep-verified node names in scenes/ui/MainMenu.tscn + Godot headless import/boot check (zero ERROR/SCRIPT ERROR/Parse Error)"
        status: pass
    human_judgment: true
    rationale: "Visual/interaction confirmation (panel opens/closes, styling reads correctly, slider feel) requires human eyes — deferred to the Plan 10-12 human-verify gate per the plan's own <verification> section."
  - id: D2
    description: "Shake cycle button drives Settings.cycle_shake()/shake_label() (OFF/LOW/NORMAL)"
    requirement: "DMG-08"
    verification:
      - kind: other
        ref: "grep-verified Settings.cycle_shake/Settings.shake_label calls in scenes/ui/MainMenu.gd + Godot headless boot check clean"
        status: pass
    human_judgment: true
    rationale: "Confirming the cycle actually changes in-game shake feel requires the Plan 10-12 human-verify gate; this plan only wires the call sites."
  - id: D3
    description: "Music/SFX sliders drive Settings.set_music_volume/set_sfx_volume against the Music/SFX buses"
    requirement: "DMG-08"
    verification:
      - kind: other
        ref: "grep-verified Settings.set_music_volume/set_sfx_volume calls in scenes/ui/MainMenu.gd + Godot headless boot check clean"
        status: pass
    human_judgment: true
    rationale: "Audible volume-slider response is explicitly deferred to the Plan 10-12 human-verify gate per this plan's <verification> section."

duration: 20min
completed: 2026-07-13
status: complete
---

# Phase 10 Plan 05: MainMenu Settings Sub-Panel Summary

**Comic-styled Settings sub-panel on MainMenu with a shake OFF/LOW/NORMAL cycle button and Music/SFX volume sliders, wired to the per-client `Settings` autoload — no networking involved.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-13T21:05:35Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `SettingsButton` to the MainMenu `VBoxContainer` and a hidden `SettingsPanel` with `TitleLabel` ("SETTINGS"), a "SCREEN SHAKE" label + `ShakeCycleButton`, "MUSIC VOLUME"/"SFX VOLUME" labels + `HSlider`s, and a `CloseButton` — all copy strings match the UI-SPEC exactly.
- Wired `MainMenu.gd`: Settings/Close buttons toggle panel visibility; `ShakeCycleButton` calls `Settings.cycle_shake()` and refreshes its text from `Settings.shake_label()`; `MusicSlider`/`SfxSlider` `value_changed` call `Settings.set_music_volume`/`set_sfx_volume`; initial slider/button state seeded from the `Settings` autoload on `_ready()`.
- Applied the existing `UiStyle` comic sweep (`comic_box`, `style_buttons`, `style_labels`) to the new panel so it matches the rest of the Comic UI Pass with zero bespoke styling code.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Settings button + SettingsPanel nodes to MainMenu.tscn** - `82e0b64` (feat)
2. **Task 2: Wire MainMenu.gd panel open/close + controls to the Settings autoload** - `00a89a1` (feat)

_Note: no TDD tasks in this plan (both `tdd="false"`)._

## Files Created/Modified
- `scenes/ui/MainMenu.tscn` - `SettingsButton` sibling of Host/Join/Status; hidden `SettingsPanel` (Panel) with `SettingsVBox` (32px group separation) containing `TitleLabel`, `ShakeGroup`/`MusicGroup`/`SfxGroup` (8px row separation) each holding a label + control, and a `CloseButton`
- `scenes/ui/MainMenu.gd` - `@onready` refs for the new nodes; `_ready()` styling sweep + initial state seeding from `Settings`; five new handler functions (`_on_settings_pressed`, `_on_close_settings_pressed`, `_on_shake_cycle_pressed`, `_on_music_slider_changed`, `_on_sfx_slider_changed`)

## Decisions Made
- Grouped each label+control pair (Shake/Music/Sfx) into its own small `VBoxContainer` so the outer `SettingsVBox`'s 32px separation lands exactly on group-to-group gaps per the UI-SPEC's exact groups ("shake / music / sfx / close"), while inner groups carry the 8px label-to-control gap from the spacing scale.
- Used a native `Panel` node for `SettingsPanel` and applied `UiStyle.comic_box(UiStyle.PAPER)` via `add_theme_stylebox_override("panel", ...)` in script — matches the plan's suggestion of "a `Panel` or `Control`" and keeps all comic-box logic centralized in `UiStyle.gd`.

## Deviations from Plan

None - plan executed exactly as written. One incidental, plan-acknowledged effect: `UiStyle.style_buttons()` bumps the separation of any `BoxContainer` that directly parents a `Button` to 16px (existing shared helper behavior, not modified here). This means `ShakeGroup` (which holds `ShakeCycleButton`) ends up at 16px internal separation rather than the UI-SPEC's 8px label-to-control token, while `MusicGroup`/`SfxGroup` (which hold `HSlider`s, not `Button`s) correctly stay at 8px. This is an inherent consequence of reusing the existing shared `style_buttons()` sweep as the plan instructed, not a new bug — flagged here for visibility, not filed as a Rule 1-4 deviation since no plan requirement was violated (layout details were explicitly Claude's-discretion per 10-CONTEXT.md).

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The Settings panel is fully wired to the `Settings` autoload (Plan 10-01) and the Music/SFX buses (Plan 10-02); both already existed at Wave 1 so no stub/placeholder wiring was needed.
- Audible slider response and in-game shake-off feel are explicitly deferred to the Plan 10-12 human-verify gate (per this plan's own `<verification>` section) — nothing further required from this plan.

## Self-Check

**Files:**
- FOUND: scenes/ui/MainMenu.tscn (SettingsButton, SettingsPanel, ShakeCycleButton, MusicSlider, SfxSlider, CloseButton all present)
- FOUND: scenes/ui/MainMenu.gd (Settings.cycle_shake/set_music_volume/set_sfx_volume/shake_label + settings_panel all present)

**Commits:**
- FOUND: 82e0b64
- FOUND: 00a89a1

**Godot headless boot-check (mandatory, run from worktree root):**
```
$ "/Applications/Godot 2.app/Contents/MacOS/Godot" --headless --path . --import 2>&1 | grep -iE 'ERROR|Parse Error'
(no output — zero matches)

$ "/Applications/Godot 2.app/Contents/MacOS/Godot" --headless --path . --quit-after 60 2>&1 \
    | grep -viE '^(Godot Engine|OpenGL|Vulkan|Metal|--- Debug|Using |Shader cache|TextServer|WARNING: Blocking|^$)'
(no output — zero ERROR/SCRIPT ERROR/Parse Error lines, scene tree booted and quit cleanly)
```

## Self-Check: PASSED

---
*Phase: 10-juicy-feedback-visual-gameplay-polish*
*Completed: 2026-07-13*
