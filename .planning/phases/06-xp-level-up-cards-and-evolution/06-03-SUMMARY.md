---
phase: 06-xp-level-up-cards-and-evolution
plan: "03"
subsystem: progression
tags: [xp, level-up, card-flow, evolution, airbag-migration, multiplayer, rpc]
dependency_graph:
  requires: [06-01, 06-02]
  provides: [XP-02, XP-03, XP-04, XP-05, XP-06, XP-07, XP-08, EVOL-02, EVOL-03, EVOL-04]
  affects:
    - scenes/Player.gd
    - scenes/Player.tscn
    - scenes/weapons/WeaponManager.gd
    - scenes/Game.gd
tech_stack:
  added: []
  patterns:
    - rpc-any_peer-call_remote-reliable
    - host-authoritative-card-validation
    - call_deferred-physics-safety
    - is_multiplayer_authority-input-gate
    - wrapi-navigation
    - peer-lookup-by-peer_id
key_files:
  created: []
  modified:
    - scenes/Player.gd
    - scenes/Player.tscn
    - scenes/weapons/WeaponManager.gd
    - scenes/Game.gd
decisions:
  - "set_evolution_stage uses call_deferred for _swap_stage_visual (D-13: physics safety)"
  - "_check_stage_threshold uses Option C: owning peer self-applies since receive_xp is host-authorized"
  - "confirm_card_pick uses any_peer + is_server() guard (mirrors attempt_revive pattern)"
  - "_card_pick_complete sent via rpc_id to owning peer only (not broadcast)"
  - "upgrade_weapon is an RPC on WeaponManager so host can push via rpc_id to owning peer"
  - "Cooldown stat boost deferred to Phase 7 (no cooldown infrastructure yet)"
  - "airbag L2 heal: maxi(1, MAX_HP / 4) — 25% HP floor per D-11"
metrics:
  duration: "~10 min"
  completed_date: "2026-06-18"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 4
---

# Phase 6 Plan 03: Card Flow Wiring + Evolution Stage Transitions Summary

Full level-up card flow wired end-to-end: killing enemies fills XP → level-up triggers 3-card overlay → A/D navigation + Space/Enter confirm → host validates pick → card effect applied immediately; stage visual swap on STAGE2/3_LEVEL thresholds with D-22 stat boost; airbag migrated from bool to int count.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Player.gd — card pool, card pick trigger, input handler, stage visual swap, HUD update, evolution | 3d9f138 | scenes/Player.gd |
| 2 | WeaponManager.gd airbag migration + upgrade_weapon; Game.gd confirm_card_pick RPC; Player.tscn HUD+Overlay instances | 68b3ef2 | scenes/weapons/WeaponManager.gd, scenes/Game.gd, scenes/Player.tscn |

## What Was Built

**scenes/Player.gd additions:**

- `set_evolution_stage` body filled: `call_deferred("_swap_stage_visual", stage)` + Stage 3 stat boost (`stage3_damage_mult = 1.2`, `MAX_HP += 25`, `health = mini(health + 25, MAX_HP)`)
- `_swap_stage_visual(stage)`: hides all StageNContainer nodes, shows correct one, calls `_update_xp_hud`
- `_update_xp_hud()`: calls `$PlayerHUD.update_hud(xp, level, _xp_threshold(level), evolution_stage)` guarded by `is_multiplayer_authority()`
- `_check_stage_threshold()`: self-applies Stage 2 at STAGE2_LEVEL, Stage 3 at STAGE3_LEVEL (Option C pattern)
- `_build_card_pool()`: weapon unlocks (exclude owned), weapon upgrades (exclude maxed), element upgrade (if tier < 3), 4 stat boosts, fallback if empty
- `_draw_cards(pool)`: shuffle, take up to 3, pad to 3 with fallback
- `_trigger_card_pick()`: sets is_picking_card, builds pool, shows CardOverlay, calls _update_xp_hud
- `_confirm_card_pick()`: gets selected index from CardOverlay, sends confirm_card_pick RPC to host (or direct if host)
- `receive_element_tier_up()` RPC: increments element_tier capped at 3, updates HUD
- `_unhandled_input()`: A/D navigate cards, Space/Enter confirm — authority + is_picking_card gated
- `_physics_process` extended: is_picking_card freeze gate (velocity = ZERO + return) after is_downed check
- `_process` extended: LevelUpLabel driven by synced is_picking_card (all peers see "[Role] is leveling up!")
- `receive_damage` extended: `if is_picking_card: return` guard after `if dash_invincible`; airbag_count check with L2 heal to 25% HP

**scenes/weapons/WeaponManager.gd changes:**

- `airbag_active: bool = false` → `airbag_count: int = 0` with `MAX_AIRBAG_CHARGES: int = 2`
- `add_weapon` airbag re-arm: level-aware cap (`MAX_AIRBAG_CHARGES if lvl >= 3 else 1`); increments up to cap
- First-unlock arm: `airbag_count = 1` (was bool true)
- `reset()`: `airbag_count = 0`
- `consume_airbag()`: decrements count to 0 minimum; hides ring only when count == 0
- `upgrade_weapon(weapon_id)` RPC: increments weapon_level up to 3; L3 screws_and_bolts updates wait_time to 0.35s

**scenes/Game.gd additions:**

- `confirm_card_pick(requester_peer_id, card_index)` RPC: any_peer + is_server() guard; is_picking_card race-condition guard; rebuilds pool on host; validates index; calls _apply_card_effect + _card_pick_complete.rpc_id
- `_build_card_pool_for_player(player_node)`: host-side pool rebuild for P8 validation — matches client build logic
- `_apply_card_effect(peer_id, player_node, card)`: match on card type — weapon_unlock reuses weapon_unlocked.rpc; weapon_upgrade calls upgrade_weapon.rpc_id; element_upgrade calls receive_element_tier_up.rpc_id; stat_boost calls _apply_stat_boost_rpc.rpc_id
- `_apply_stat_boost_rpc(stat, amount)` RPC: Speed/MaxHP/Damage boosts applied on owning peer; Cooldown deferred to Phase 7
- `_card_pick_complete(_for_peer_id)` RPC: clears is_picking_card, hides CardOverlay, calls _update_xp_hud on owning peer

**scenes/Player.tscn changes:**

- `load_steps` 5 → 7 (two new ext_resources)
- `ext_resource` entries for PlayerHUD.tscn (id=3_player_hud) and CardOverlay.tscn (id=4_card_overlay)
- `[node name="PlayerHUD" parent="." instance=ExtResource("3_player_hud")]`
- `[node name="CardOverlay" parent="." instance=ExtResource("4_card_overlay")]`

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- `"Cooldown"` stat boost match branch: `pass` (D-11 Cooldown stat has no infrastructure yet). This is intentional per plan text ("TODO Phase 7") — the Cooldown stat card appears in the pool and can be drawn, but picking it does nothing until Phase 7 adds per-weapon cooldown reduction. The card pick still completes and is_picking_card is cleared, so gameplay flow is unbroken.

## Threat Surface

All threat model mitigations implemented as designed:

- T-06-07 (Tampering — card_index): Host rebuilds pool from synced state; `card_index < 0 or >= pool.size()` falls back to card 0
- T-06-08 (Elevation — pick while not leveling): `if not player_node.is_picking_card: return` in confirm_card_pick
- T-06-09 (Tampering — upgrade_weapon): upgrade_weapon is RPC but only called by host _apply_card_effect via rpc_id; Game.gd controls when it fires
- T-06-10 (DoS — empty card pool): Both client and host pool builders append `{"type": "fallback"}` when pool is empty; _draw_cards pads to 3
- T-06-11 (DoS — SceneTree pause): CardOverlay is CanvasLayer visible toggle only; SceneTree.paused never set

No new threat surface beyond what the plan's threat model documents.

## Self-Check: PASSED

Files exist:
- scenes/Player.gd — FOUND (modified)
- scenes/Player.tscn — FOUND (modified)
- scenes/weapons/WeaponManager.gd — FOUND (modified)
- scenes/Game.gd — FOUND (modified)

Commits:
- 3d9f138 — FOUND (feat(06-03): Player.gd card flow, stage visual, HUD update, input handler, airbag migration)
- 68b3ef2 — FOUND (feat(06-03): WeaponManager airbag migration, upgrade_weapon RPC; Game.gd confirm_card_pick; Player.tscn HUD+Overlay)
