---
phase: 10-juicy-feedback-visual-gameplay-polish
plan: 07
subsystem: ui
tags: [godot, gdscript, comic-ui, tween, card-overlay]

# Dependency graph
requires:
  - phase: 10-01
    provides: UiStyle.gd comic helpers (comic_box, button_font, INK, PAPER) and the Comic UI Pass identity extended by PlayerHUD/MainMenu
provides:
  - CardOverlay comic restyle (paper/ink/Bangers) shared by both the level-up card pick and the sub-room weapon-choice presentation
  - Pop/scale-in entrance animation on show_cards, local CanvasLayer Tween only
affects: [phase-11-sound, any-future-ui-phase-touching-card-overlay]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PanelContainer 'panel' stylebox override swap (comic_box(PAPER) <-> comic_box(accent)) for a selected/unselected visual state, replacing an old flat ColorRect border-color swap"
    - "Two-stage Tween scale pop (0.7 -> 1.05 overshoot -> 1.0) with TRANS_BACK/EASE_OUT, mirroring the existing _show_dash_shockwave tween-chain shape"

key-files:
  created: []
  modified:
    - scenes/ui/CardOverlay.gd
    - scenes/ui/CardOverlay.tscn

key-decisions:
  - "Applied UiStyle.button_font()+INK directly (PlayerHUD._apply_comic_style recipe) rather than UiStyle.style_label() (which sets a light font color + outline meant for dark backgrounds) — matches the plan's explicit instruction and reads correctly on the paper-colored panel."
  - "Made the old Card{N}Border ColorRect fully transparent (both in the .tscn defaults and defensively in the script) since the PanelContainer's own 'panel' stylebox now draws the paper background + ink border + shadow; leaving it opaque would have painted over the new comic_box."
  - "Selection swap moved from ColorRect.color to PanelContainer.add_theme_stylebox_override('panel', ...) in _refresh_display, keeping the existing selection/navigation call path untouched."

patterns-established:
  - "Card overlay pop-in: local CanvasLayer Tween, alpha 0->0.55 (backdrop) in parallel with scale 0.7->1.05->1.0 (container), TRANS_BACK/EASE_OUT, ~0.25s total, reset on hide_overlay() for a clean re-trigger."

requirements-completed: [PROG-02]

coverage:
  - id: D1
    description: "CardOverlay comic-restyled at _ready: UiStyle.comic_box(PAPER) on each card, UiStyle.button_font()+INK on TitleLabel (28px)/HintLabel/Card{N}TypeLabel/NameLabel/DescLabel (DescLabel 16px), selected card shows accent comic_box swapped in _refresh_display"
    requirement: "PROG-02"
    verification:
      - kind: other
        ref: "grep -q 'UiStyle.comic_box' scenes/ui/CardOverlay.gd && grep -qE 'UiStyle.button_font|UiStyle.style_label' && grep -qE 'func _apply_comic_style|func _ready' (plan's automated verify block)"
        status: pass
      - kind: e2e
        ref: "Godot headless boot: --import, res://scenes/ui/CardOverlay.tscn --quit-after 30, res://scenes/Player.tscn --quit-after 30 — zero ERROR/SCRIPT ERROR/Parse Error lines"
        status: pass
    human_judgment: true
    rationale: "Visual comic-restyle correctness (paper/ink look, accent highlight legibility) is a design/aesthetic judgment call the boot check and grep cannot verify — needs a human glance in-editor or in a live playtest to confirm it reads as intended."
  - id: D2
    description: "show_cards() pop/scale-in entrance: OverlayBackground alpha 0->0.55 over 0.15s, OverlayContainer scale 0.7->1.05->1.0 over ~0.25s (TRANS_BACK/EASE_OUT), local CanvasLayer Tween only, no tree pause, no RPC; hide_overlay() resets scale/alpha for a clean re-trigger"
    requirement: "PROG-02"
    verification:
      - kind: other
        ref: "grep -q 'func show_cards' && grep -q 'create_tween' && grep -qiE 'TRANS_BACK|scale' && sed 's/#.*//' scenes/ui/CardOverlay.gd | grep -c 'paused' == 0 (plan's automated verify block)"
        status: pass
      - kind: e2e
        ref: "Godot headless boot: --import, res://scenes/ui/CardOverlay.tscn --quit-after 30, res://scenes/Player.tscn --quit-after 30 — zero ERROR/SCRIPT ERROR/Parse Error lines"
        status: pass
    human_judgment: true
    rationale: "Animation feel (overshoot amount, timing, 'event not a snap' quality) is a subjective juice judgment that headless boot checks cannot assess — needs a human to actually watch the pop-in play in a live level-up/sub-room weapon-choice moment."

duration: ~20min
completed: 2026-07-13
status: complete
---

# Phase 10 Plan 07: CardOverlay Comic Restyle + Pop-In Summary

**CardOverlay restyled with UiStyle paper/ink/Bangers comic language and a Tween-driven pop/scale-in entrance (0.7→1.05 overshoot→1.0, alpha 0→0.55), shared automatically by both the level-up card pick and the sub-room weapon-choice overlay.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-13T21:21:28Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments
- `CardOverlay.gd` now applies a full comic restyle at `_ready()`: `UiStyle.comic_box(UiStyle.PAPER)` on each `Card{N}` panel, Bangers font + `UiStyle.INK` on the title (28px Heading tier), hint, and each card's type/name/desc labels (desc bumped to 16px Body tier)
- The selected card is highlighted with an accent `comic_box(Color(1.0, 0.84, 0.25))` swapped in via `_refresh_display`, replacing the old flat green/grey `ColorRect` border color
- `show_cards()` now plays a pop/scale-in entrance instead of an instant `visible = true`: backdrop alpha fades 0→0.55 over 0.15s while the card container scales 0.7→1.05 (overshoot)→1.0 over ~0.25s total, `TRANS_BACK`/`EASE_OUT`, mirroring the existing `_show_dash_shockwave` tween-chain shape
- `hide_overlay()` resets scale/alpha to resting values so a subsequent `show_cards()` re-triggers a clean pop
- Both the level-up card pick (`Player.gd:957`) and the sub-room weapon-choice presentation (`Player.gd:991`) inherit the restyle and pop-in automatically since they call the same shared `CardOverlay.show_cards()`
- Confirmed no `SceneTree.paused` call and no RPC added anywhere in the file (W4 discipline preserved)

## Task Commits

Each task was committed atomically:

1. **Task 1: Comic restyle the CardOverlay (D-12)** - `276ad84` (feat)
2. **Task 2: Pop/scale-in entrance animation on show_cards (PROG-02)** - `7715559` (feat)

**Plan metadata:** committed with this SUMMARY (see final commit)

## Files Created/Modified
- `scenes/ui/CardOverlay.gd` - `_ready()`/`_apply_comic_style()` restyle pass, selected/unselected accent stylebox swap in `_refresh_display`, `_play_pop_in()` entrance Tween wired into `show_cards()`, scale/alpha reset in `hide_overlay()`
- `scenes/ui/CardOverlay.tscn` - `Card0Border`/`Card1Border`/`Card2Border` default color changed from flat `Color(0.35, 0.35, 0.4, 1)` to transparent `Color(0, 0, 0, 0)` so the new `PanelContainer` comic_box stylebox shows through instead of being painted over

## Decisions Made
- Used the exact `PlayerHUD._apply_comic_style` recipe (`button_font()` + `add_theme_color_override("font_color", UiStyle.INK)`) rather than `UiStyle.style_label()`, per the plan's explicit instruction — `style_label()` is tuned for light text with a black outline on dark backgrounds, which would read poorly on the new paper-colored cards.
- Moved the selected/unselected visual state from the `Card{N}Border` `ColorRect.color` to the `Card{N}` `PanelContainer`'s `panel` stylebox override, since `comic_box()` returns a `StyleBoxFlat` (paper bg + ink border + shadow) that only draws correctly through a stylebox slot, not a flat `ColorRect` color.
- Made the `Card{N}Border` `ColorRect` transparent in both the script (defensive) and the `.tscn` defaults (so the scene is self-consistent even before `_ready()` runs).

## Deviations from Plan

None - plan executed exactly as written. The `.tscn` edit (transparent `Border` default color) was anticipated by the plan's artifact list ("selected-card accent styling") and needed for the restyle to render correctly rather than being covered by the old opaque `ColorRect`.

## Issues Encountered

None. Both plan tasks implemented and verified in a single pass; no build/parse errors surfaced.

## Mandatory Build Verification

Godot 4.6.3 headless checks run from the worktree root, all clean (zero `ERROR`/`SCRIPT ERROR`/`Parse Error` lines):

```
$ "$GODOT" --headless --path . --import 2>&1 | grep -iE 'ERROR|Parse Error'
(no output)

$ "$GODOT" --headless --path . res://scenes/ui/CardOverlay.tscn --quit-after 30 2>&1
Godot Engine v4.6.3.stable.official.7d41c59c4 - https://godotengine.org
(exit code 0, no ERROR lines — exercises CardOverlay.tscn parse + _ready()/_apply_comic_style() execution directly)

$ "$GODOT" --headless --path . res://scenes/Player.tscn --quit-after 30 2>&1
Godot Engine v4.6.3.stable.official.7d41c59c4 - https://godotengine.org
(exit code 0, no ERROR lines — exercises CardOverlay as instanced inside Player.tscn, its real usage context)

$ "$GODOT" --headless --path . --quit-after 60 2>&1   (default main scene, MainMenu.tscn)
Godot Engine v4.6.3.stable.official.7d41c59c4 - https://godotengine.org
(exit code 0, no ERROR lines)
```

Ran the check twice: once after Task 1 alone (before splitting the commit), and once again on the final combined state after Task 2 — both passed clean.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- CardOverlay is fully comic-restyled and pop-in animated; both the level-up and sub-room weapon-choice call sites inherit it with zero additional wiring.
- Human visual verification recommended (see `coverage` block `human_judgment: true` entries) — a live playtest glance to confirm the paper/ink look and pop-in feel land as intended, since headless boot checks can only prove absence of parse/runtime errors, not visual/animation quality.
- No blockers for subsequent Phase 10 plans.

## Self-Check: PASSED

- FOUND: scenes/ui/CardOverlay.gd
- FOUND: scenes/ui/CardOverlay.tscn
- FOUND: .planning/phases/10-juicy-feedback-visual-gameplay-polish/10-07-SUMMARY.md
- FOUND commit: 276ad84 (feat(10-07): comic restyle the CardOverlay)
- FOUND commit: 7715559 (feat(10-07): pop/scale-in entrance animation on show_cards)

---
*Phase: 10-juicy-feedback-visual-gameplay-polish*
*Completed: 2026-07-13*
