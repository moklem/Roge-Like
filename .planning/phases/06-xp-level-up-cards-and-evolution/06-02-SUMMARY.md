---
phase: 06-xp-level-up-cards-and-evolution
plan: "02"
subsystem: ui
tags: [ui, canvas-layer, hud, card-overlay, level-up, xp, player-hud]
dependency_graph:
  requires: [06-01]
  provides: [XP-01, XP-02, XP-03, XP-09]
  affects:
    - scenes/ui/PlayerHUD.tscn
    - scenes/ui/PlayerHUD.gd
    - scenes/ui/CardOverlay.tscn
    - scenes/ui/CardOverlay.gd
tech_stack:
  added: []
  patterns: [CanvasLayer-local-ui, is_multiplayer_authority-visibility, get_node_or_null-safe-access, wrapi-wrap-navigation]
key_files:
  created:
    - scenes/ui/PlayerHUD.gd
    - scenes/ui/PlayerHUD.tscn
    - scenes/ui/CardOverlay.gd
    - scenes/ui/CardOverlay.tscn
  modified: []
decisions:
  - "PlayerHUD uses get_node_or_null paths (not $ shorthand) for robustness against node name changes"
  - "CardOverlay border is plain ColorRect (not StyleBoxFlat) per UI-SPEC explicit directive"
  - "CardOverlay._cards typed as Array (not Array[Dictionary]) for GDScript 4 compatibility with untyped input"
  - "navigate() guards _cards.is_empty() before wrapi to avoid modulo-by-zero on empty array"
metrics:
  duration: "~5 min"
  completed_date: "2026-06-18"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 4
---

# Phase 6 Plan 02: PlayerHUD + CardOverlay UI Scenes Summary

Two new self-contained CanvasLayer scenes: PlayerHUD (XP bar / level / stage strip shown on owning peer only) and CardOverlay (3-card level-up picker with green highlight border, exact UI-SPEC copywriting, no SceneTree pause).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create PlayerHUD.tscn + PlayerHUD.gd | 6afebfa | scenes/ui/PlayerHUD.gd, scenes/ui/PlayerHUD.tscn |
| 2 | Create CardOverlay.tscn + CardOverlay.gd | e75121b | scenes/ui/CardOverlay.gd, scenes/ui/CardOverlay.tscn |

## What Was Built

**PlayerHUD.gd:**
- `extends CanvasLayer`, `layer = 1`
- `_ready()`: guards visibility via `player.is_multiplayer_authority()` (D-18)
- `update_hud(xp_value: int, level_value: int, xp_threshold: int, stage_value: int)`: updates LevelLabel ("LVL N"), XPBar (value/max), StageLabel ("STG N") via `get_node_or_null` safe access
- StageLabel color override: grey at stage 2, blue at stage 3, neutral at stage 1 (matches UI-SPEC §StageLabel Color Override)

**PlayerHUD.tscn:**
- `CanvasLayer layer=1` with HUDPanel `ColorRect(0.08, 0.08, 0.08, 0.85)` bottom-center anchored (anchors_preset=7, offset_bottom=-48)
- HUDRow HBoxContainer with LevelLabel ("LVL 1"), XPBar (12px height, show_percentage=false, size_flags_horizontal=3), StageLabel ("STG 1")

**CardOverlay.gd:**
- `extends CanvasLayer`, `visible = false` by default, `layer = 2`
- `show_cards(cards: Array)`, `hide_overlay()`, `navigate(direction: int)`, `get_selected_index() -> int`
- `_refresh_display()`: per-card node path lookup with `get_node_or_null`, sets TypeLabel/NameLabel/DescLabel text, border color green (`Color(0.4, 1.0, 0.4, 1)`) on selected, grey (`Color(0.35, 0.35, 0.4, 1)`) on unselected
- All 5 card type headers: "New Weapon" / "Upgrade" / "Element Boost" / "Stat Boost" / "Damage Boost"
- All 12 weapon upgrade descriptions per UI-SPEC weapon table (character-for-character)
- `WEAPON_NAMES` dict: all 6 car-themed weapons mapped to display names

**CardOverlay.tscn:**
- `CanvasLayer layer=2, visible=false` with full-screen `OverlayBackground ColorRect(0,0,0,0.55)`
- Centered `OverlayContainer VBoxContainer` with TitleLabel, CardsRow HBoxContainer, HintLabel
- 3 cards (Card0/Card1/Card2): each `PanelContainer(160x64)` → `ColorRect border` → `VBoxContainer inner` → TypeLabel/NameLabel/DescLabel
- TitleLabel: `"LEVEL UP — PICK A CARD"` (exact UI-SPEC string)
- HintLabel: `"[A]/[D] Cycle     [Space]/[Enter] Confirm"` (exact UI-SPEC string)
- No `SceneTree.paused` (W4 compliance)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- `PlayerHUD._ready()` calls `player.is_multiplayer_authority()` — works when PlayerHUD is parented to a Player node. Plan 04 instances it under Player.tscn; standalone scene editor open will show hidden (fallback: `if player and player.has_method(...)` guard prevents crash).
- `CardOverlay._refresh_display()` uses `get_node_or_null` with full paths — relies on CardOverlay.tscn node structure being intact. No wiring to Player.gd yet (Plan 04 responsibility).
- These stubs are intentional: this plan creates the UI scenes in isolation; Plan 04 instances and drives them.

## Threat Surface

T-06-05: CardOverlay never calls `SceneTree.paused` — CanvasLayer local visibility toggle only. Other peers fully unaffected.
T-06-06: PlayerHUD visibility gated by `is_multiplayer_authority()` in `_ready()` — only rendered on owning peer's screen.

No new threat surface beyond what the plan's threat model documents.

## Self-Check: PASSED

Files exist:
- scenes/ui/PlayerHUD.gd — FOUND (created)
- scenes/ui/PlayerHUD.tscn — FOUND (created)
- scenes/ui/CardOverlay.gd — FOUND (created)
- scenes/ui/CardOverlay.tscn — FOUND (created)

Commits:
- 6afebfa — FOUND (feat(06-02): create PlayerHUD CanvasLayer scene + script)
- e75121b — FOUND (feat(06-02): create CardOverlay CanvasLayer scene + script)
