---
phase: 07-carhud-loop-timer-difficulty-scaling
plan: "02"
subsystem: ui, enemies
tags: [carhud, hud-indicators, elite-enemy, tween, canvas-layer]
status: complete

dependency_graph:
  requires:
    - "07-01-PLAN.md (GameEvents.emit_hud as authority RPC, GameState.loop_number=1, Enemy const→var)"
  provides:
    - "scenes/ui/CarHUD.tscn — global CanvasLayer layer=3 dashboard with 5 indicators + Loop label"
    - "scenes/ui/CarHUD.gd — hud_event listener, per-indicator StyleBoxFlat activation, loop polling"
    - "scenes/enemies/EliteEnemy.tscn — CharacterBody2D with purple 48×48 visual, mirrors Enemy.tscn structure"
    - "scenes/enemies/EliteEnemy.gd — extends Enemy.gd; MAX_HP=100, CONTACT_DAMAGE=15 overrides in _ready()"
  affects:
    - "scenes/Game.gd (07-03) instantiates CarHUD.tscn in _ready() and pre-registers EliteEnemy.tscn in EnemySpawner"

tech_stack:
  added: []
  patterns:
    - "CanvasLayer layer=3 global dashboard (above PlayerHUD layer=1 and CardOverlay layer=2)"
    - "Per-indicator StyleBoxFlat programmatic construction in _ready() (mirrors Game.gd lines 86–93)"
    - "Tween modulate:a fade (never StyleBoxFlat.bg_color) — mirrors Game.gd lines 119–121 anti-pattern avoidance"
    - "extends 'res://scenes/enemies/Enemy.gd' subclass with super._ready() stat overrides (D-14)"

key_files:
  created:
    - scenes/ui/CarHUD.tscn
    - scenes/ui/CarHUD.gd
    - scenes/enemies/EliteEnemy.tscn
    - scenes/enemies/EliteEnemy.gd
  modified: []

decisions:
  - "ColorRect visual child accessed by name 'Sprite' (confirmed from Enemy.tscn line 28 — not 'ColorRect')"
  - "EliteEnemy.tscn CollisionShape2D enlarged proportionally (radius 18, height 48) to match 48x48 visual body"
  - "Tween creates on panel node (not CanvasLayer root) so modulate:a fade scopes to each indicator independently"
  - "Loop label color set to Color(0.85, 0.85, 0.85, 1) always-on (UI-SPEC Loop Label States)"

metrics:
  duration: "~5 minutes"
  completed: "2026-06-19"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 0
  files_created: 4
---

# Phase 7 Plan 02: CarHUD Scene & EliteEnemy Summary

**One-liner:** Global CanvasLayer CarHUD dashboard with 5 colour-coded fade indicators + Loop label; EliteEnemy GDScript subclass with 2× HP / 1.5× damage and dark-purple 48×48 visual.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Build CarHUD scene and controller | 8b16ede | scenes/ui/CarHUD.tscn, scenes/ui/CarHUD.gd |
| 2 | Build EliteEnemy scene extending Enemy | 2dbf960 | scenes/enemies/EliteEnemy.tscn, scenes/enemies/EliteEnemy.gd |

## What Was Built

### Task 1 — CarHUD Scene and Controller

**`scenes/ui/CarHUD.tscn`**
- Root `CarHUD` node: `CanvasLayer` with `layer = 3` (above PlayerHUD/CardOverlay at layers 1/2)
- `CarHUDPanel` (`ColorRect`): right-strip anchoring (`anchor_left=1.0, anchor_right=1.0, offset_left=-200, offset_right=0`), panel color `Color(0.05, 0.05, 0.05, 0.92)` per UI-SPEC
- `CarHUDContainer` (`VBoxContainer`): fills CarHUDPanel with 8px inset offsets and 8px separation
- `LoopLabel` (`Label`): text `"Loop: 1"`, `custom_minimum_size.y = 32`, centered, color `Color(0.85, 0.85, 0.85, 1)`
- 5 indicator `PanelContainer` + `Label` pairs with `custom_minimum_size.y = 48`:
  - `AcIndicator` / `AcLabel` — `"AC ❄️ COLD"`
  - `EngineIndicator` / `EngineLabel` — `"ENGINE 🔥 OVERHEAT"`
  - `SeatMassageIndicator` / `SeatMassageLabel` — `"SEAT MASSAGE 🌿 ACTIVE"`
  - `SuspensionIndicator` / `SuspensionLabel` — `"SUSPENSION ⚡ IMPACT"`
  - `LidarIndicator` / `LidarLabel` — `"LIDAR 🔴 OBJECT DETECTED"`

**`scenes/ui/CarHUD.gd`**
- `_ready()`: connects `GameEvents.hud_event` → `_on_hud_event`; builds `_indicators` dict with per-indicator `{panel, label, style, lit_color, tween}`; caches `_loop_label`; sets initial text from `GameState.loop_number`
- `_process(_delta)`: polling pattern — updates `LoopLabel.text` only when `GameState.loop_number != _last_loop_number`
- `_build_indicators()`: creates per-indicator `StyleBoxFlat` (idle bg `Color(0.10,0.10,0.10,1)`) via `add_theme_stylebox_override("panel", style)`
- `_on_hud_event(event_name)` → `_activate_indicator(event_name)`: kills existing tween, sets lit StyleBoxFlat color, white label text, outline_size=1, resets modulate.a=1.0
- Tween sequence: `tween_interval(2.0)` → `tween_property(panel, "modulate:a", 0.0, 0.5)` → `tween_callback(_restore_idle.bind(event_name))`
- `_restore_idle(event_name)`: sets panel.modulate.a=1.0, restores idle bg color, restores dim label text `Color(0.35,0.35,0.35,1)`, removes outline

### Task 2 — EliteEnemy Scene Extending Enemy

**`scenes/enemies/EliteEnemy.gd`**
- `extends "res://scenes/enemies/Enemy.gd"` (D-14 subclass reuse — confirmed viable with var MAX_HP/CONTACT_DAMAGE from Plan 01)
- `_ready()` calls `super._ready()` first → preserves group registration, P6 physics-process guard `set_physics_process(is_multiplayer_authority())`, hurtbox connections
- Stat overrides after super: `MAX_HP = 100` (2× base 50), `CONTACT_DAMAGE = 15` (1.5× base 10), `current_hp = MAX_HP`
- Visual override via `has_node("Sprite")` guard: sets `$Sprite.color = Color(0.55, 0.1, 0.55, 1)` (dark purple per UI-SPEC), enlarges offsets to ±24 (48×48 total)

**`scenes/enemies/EliteEnemy.tscn`**
- Root `EliteEnemy` (`CharacterBody2D`): same `collision_layer=4`, `collision_mask=3` as Enemy.tscn
- `Sprite` (`ColorRect`): purple `Color(0.55, 0.1, 0.55, 1)`, offset ±24 for 48×48 size
- `CollisionShape2D` (`CapsuleShape2D`): radius=18, height=48 (proportional to enlarged body)
- `NavigationAgent2D` — identical to Enemy.tscn
- `HurtboxArea` (`Area2D`): same `collision_layer=16`, `collision_mask=34`; `CircleShape2D` radius=22
- `HealthBar` (`ProgressBar`): offset adjusted to sit above larger body
- Single `MultiplayerSynchronizer`: replicates `position`, `current_hp`, `state` at 0.05s interval — exactly matching Enemy.tscn synced vars (no new variables added)

## Deviations from Plan

None — plan executed exactly as written.

The PATTERNS.md node tree for EliteEnemy listed optional HealthBar; it was included to match Enemy.tscn parity. The Sprite child name was confirmed as `"Sprite"` from Enemy.tscn line 28 (not `"ColorRect"` as the plan's generic description suggested); the has_node guard in EliteEnemy.gd handles this correctly.

## Known Stubs

None. All four files are fully wired:
- `CarHUD.tscn`: complete scene tree with all 5 indicators
- `CarHUD.gd`: connects to GameEvents.hud_event, implements full activate/restore-idle cycle
- `EliteEnemy.gd`: fully functional subclass with stat overrides and visual change
- `EliteEnemy.tscn`: structurally ready for EnemySpawner pre-registration in Plan 03

The CarHUD is passive (display only) until Plan 03 wires it into Game.tscn via `add_child()` in Game.gd `_ready()`. The EliteEnemy is spawnable as soon as Plan 03 calls `$EnemySpawner.add_spawnable_scene("res://scenes/enemies/EliteEnemy.tscn")` and adds the spawn timer logic.

## Threat Flags

No new network surface introduced in this plan.

- T-07-04: CarHUD is a passive read-only listener — it reacts to local `hud_event` signal only, never sends RPCs or mutates game state. No authority surface. (accepted)
- T-07-05: EliteEnemy inherits `set_physics_process(is_multiplayer_authority())` via `super._ready()`; clients never run elite AI, only render synced position. (mitigated)
- T-07-06: EliteEnemy.tscn reuses Enemy.tscn MultiplayerSynchronizer var set (`current_hp`, `state`) — one synchronizer, no extra client-writable replicated fields. (mitigated)

## Self-Check: PASSED

- scenes/ui/CarHUD.tscn: FOUND
- scenes/ui/CarHUD.gd: FOUND
- scenes/enemies/EliteEnemy.tscn: FOUND
- scenes/enemies/EliteEnemy.gd: FOUND
- Commit 8b16ede (Task 1): FOUND
- Commit 2dbf960 (Task 2): FOUND
