---
phase: 04-weapons-and-item-pickups
verified: 2026-05-31T16:00:00Z
status: passed
score: 13/13 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 11/13
  gaps_closed:
    - "Player walking over CarPartPickup triggers weapon unlock on ALL players including the host (CR-01 fix: host self-delivery branch in CarPartPickup._request_collect)"
    - "SpinningTires applies damage on host only — D-14 guard replaced is_multiplayer_authority() with multiplayer.is_server() (CR-03 fix)"
  gaps_remaining: []
  regressions: []
---

# Phase 4: Weapons & Item Pickups — Verification Report

**Phase Goal:** Vampire Survivors weapon loop — enemies drop car-part pickups, player collects to unlock weapons; 5 car-themed weapons implemented; WeaponManager is child of Player.
**Verified:** 2026-05-31T16:00:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure (CR-01, CR-03 fixes applied)

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | Enemy death has a 25% chance to spawn a CarPartPickup visible on all clients | ✓ VERIFIED | `Game.gd:91` — `if randf() < 0.25:` spawns via PickupSpawner with type="car_part"; CAR_PART_IDS has all 5 weapon IDs |
| 2  | Player walking over CarPartPickup triggers RPC chain → weapon_unlocked back to owning peer | ✓ VERIFIED | **CR-01 FIXED.** `CarPartPickup.gd:40-43` — host self-delivery branch: `if collector_peer_id == multiplayer.get_unique_id(): game.weapon_unlocked(weapon_id)` (direct call); `else: game.weapon_unlocked.rpc_id(collector_peer_id, weapon_id)` (RPC for clients). Both paths now deliver weapon unlock. |
| 3  | CarPartPickup despawns on all clients after collection | ✓ VERIFIED | `CarPartPickup.gd:44-45` — `queue_free()` on host propagates via PickupSpawner; `_collected` guard prevents double-free |
| 4  | Double-collect is prevented | ✓ VERIFIED | `CarPartPickup.gd:33-35` — `if _collected: return` runs on host before any state change |
| 5  | WeaponManager is a child Node of Player.tscn | ✓ VERIFIED | `Player.tscn:69` — `[node name="WeaponManager" type="Node" parent="."]` with WeaponManager.gd script |
| 6  | Player.gd delegates fire to WeaponManager, old fire logic removed | ✓ VERIFIED | `Player.gd:53-54` — `if has_node("WeaponManager"): $WeaponManager.tick(delta)`; no FIRE_INTERVAL, _fire_cooldown, _try_fire, or _find_nearest_enemy present |
| 7  | add_weapon() silently caps at MAX_WEAPONS=6 and ignores duplicates | ✓ VERIFIED | `WeaponManager.gd:79-88` — cap check at line 79; duplicate check at line 87; airbag re-arm special case at lines 82-86 |
| 8  | All 5 car-themed weapons implemented and fire automatically | ✓ VERIFIED | ExhaustFlames.gd, SpinningTires.gd, AntennaBeam.gd, HornShockwave.gd, AirbagShield.gd all exist; all timer-based weapons have `autostart = true` |
| 9  | SpinningTires applies damage on host only (D-14) | ✓ VERIFIED | **CR-03 FIXED.** `SpinningTires.gd:66` — `if not multiplayer.is_server(): return`; comment at line 65 confirms intent: "D-14: Host-only damage detection (CR-03 fix: use is_server(), not is_multiplayer_authority())" |
| 10 | Airbag intercepts lethal hits; ring hidden on consumption | ✓ VERIFIED | `Player.gd:95-98` — `if health - amount <= 0 and ... $WeaponManager.airbag_active: health = 1; $WeaponManager.consume_airbag()`; `WeaponManager.gd:166-169` — `consume_airbag()` sets flag false and calls `AirbagShield.hide_ring()` |
| 11 | weapon_level dict initialized to 1 at unlock (WEAP-07 data model) | ✓ VERIFIED | `WeaponManager.gd:90` — `weapon_level[weapon_id] = 1` in add_weapon; `reset()` clears at line 110 |
| 12 | GameState._broadcast_game_over calls WeaponManager.reset() on all players (WEAP-08) | ✓ VERIFIED | `GameState.gd:53-55` — loops over "players" group; `has_node("WeaponManager")` guard; calls `p.get_node("WeaponManager").reset()` before `change_scene_to_file` |
| 13 | CarPartPickup pre-registered in PickupSpawner before any enemy can die | ✓ VERIFIED | `Game.gd:31-32` — both XpOrb and CarPartPickup registered in `_ready()` via `add_spawnable_scene` |

**Score:** 13/13 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scenes/pickups/CarPartPickup.tscn` | Area2D pickup scene, collision_layer=64, collision_mask=2 | ✓ VERIFIED | Confirmed: `collision_layer = 64`, `collision_mask = 2`, root CarPartPickup Area2D |
| `scenes/pickups/CarPartPickup.gd` | _collected guard, _on_body_entered, _request_collect RPC, host self-delivery branch | ✓ VERIFIED | All present; host branch at lines 40-43; client RPC path at line 43 |
| `scenes/Game.gd` | 25% drop branch, weapon_unlocked RPC, type-dispatch _do_spawn_pickup | ✓ VERIFIED | 25% drop at line 91; weapon_unlocked at line 209; _do_spawn_pickup dispatches both types |
| `scenes/weapons/WeaponManager.gd` | add_weapon, reset, tick, MAX_WEAPONS=6, weapon_level | ✓ VERIFIED | All present; 169 lines; full weapon API wired |
| `scenes/Player.tscn` | WeaponManager child node | ✓ VERIFIED | Node at line 69 with WeaponManager.gd script |
| `scenes/Player.gd` | WeaponManager.tick delegation; airbag intercept in receive_damage | ✓ VERIFIED | Both wired; consume_airbag() call at line 97 |
| `scenes/weapons/ExhaustFlames.gd` | Cone Area2D, 1.5s Timer autostart, 60° filter, host-only damage | ✓ VERIFIED | COOLDOWN=1.5, HALF_ANGLE=deg_to_rad(30), `if not multiplayer.is_server(): return` before damage |
| `scenes/weapons/SpinningTires.gd` | 3 orbit Area2D, _hit_times dict, host-only damage guard (is_server) | ✓ VERIFIED | **CR-03 FIXED.** `if not multiplayer.is_server(): return` at line 66; orbit positions update on all peers |
| `scenes/weapons/AntennaBeam.gd` | RectangleShape2D 500×8px, 2s Timer, piercing loop, host-only | ✓ VERIFIED | COOLDOWN=2.0, BEAM_LENGTH=500.0, `if not multiplayer.is_server(): return`, `get_overlapping_bodies()` loop |
| `scenes/weapons/HornShockwave.gd` | CircleShape2D radius=150, 3s Timer, Tween ring visual, host-only | ✓ VERIFIED | COOLDOWN=3.0, RADIUS=150.0, `_spawn_ring_visual()` with Tween, `if not multiplayer.is_server(): return` |
| `scenes/weapons/AirbagShield.gd` | show_ring/hide_ring/deactivate, yellow ring visual | ✓ VERIFIED | All 3 methods present; two-ColorRect hollow ring construction |
| `autoloads/GameState.gd` | _broadcast_game_over → WeaponManager.reset() | ✓ VERIFIED | Reset loop at lines 53-55, before change_scene_to_file at line 56 |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `Game.gd _on_enemy_died` | `PickupSpawner.spawn.call_deferred` | `randf() < 0.25` branch | ✓ WIRED | Game.gd:91-93 — `randf() < 0.25` drops car_part; call_deferred prevents physics-flush crash |
| `CarPartPickup.gd _on_body_entered` | `Game.gd _request_collect` | `rpc_id(1, name, body.peer_id)` from client | ✓ WIRED | CarPartPickup.gd:26 — client path; line 24 — host direct call |
| `Game.gd weapon_unlocked` | `Player WeaponManager.add_weapon` | `game.weapon_unlocked(weapon_id)` (host) / `rpc_id(collector_peer_id, weapon_id)` (client) | ✓ WIRED | **CR-01 FIXED.** Both host and client delivery paths verified at CarPartPickup.gd:40-43 |
| `Player.gd _physics_process` | `WeaponManager.tick(delta)` | `$WeaponManager.tick(delta)` | ✓ WIRED | Player.gd:53-54 |
| `WeaponManager.gd add_weapon` | Weapon node activation | `_activate_weapon_node(weapon_id)` | ✓ WIRED | WeaponManager.gd:94; dispatches to all 5 weapons via match block |
| `Player.gd receive_damage` | `WeaponManager.airbag_active` → intercept | `$WeaponManager.consume_airbag()` | ✓ WIRED | Player.gd:95-98 |
| `GameState._broadcast_game_over` | `WeaponManager.reset()` | loop over players group | ✓ WIRED | GameState.gd:53-55, before scene change |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `CarPartPickup.gd` | `weapon_id` | Set at spawn time from `CAR_PART_IDS[randi() % ...]` in `_do_spawn_pickup` | ✓ | ✓ FLOWING — random weapon ID assigned from array at spawn |
| `WeaponManager.gd` | `unlocked_weapons`, `weapon_level` | `add_weapon()` called from `weapon_unlocked` — host via direct call, clients via RPC | ✓ (all peers) | ✓ FLOWING — **CR-01 fix makes host path live** |
| `WeaponManager.gd` | `airbag_active` | `add_weapon("airbag_shield")` sets flag; `consume_airbag()` clears | ✓ | ✓ FLOWING |

---

## Behavioral Spot-Checks

| Behavior | Check | Status |
|----------|-------|--------|
| All 5 weapon scripts exist and are non-stub | `ls scenes/weapons/*.gd` — all 5 present with >40 lines each | ✓ PASS |
| 25% drop chance in code | `grep "randf.*0.25" Game.gd` — found at line 91 | ✓ PASS |
| MAX_WEAPONS cap enforced | `grep "unlocked_weapons.size() >= MAX_WEAPONS" WeaponManager.gd` — found at line 79 | ✓ PASS |
| weapon_level initialized to 1 | `grep "weapon_level\[weapon_id\] = 1" WeaponManager.gd` — found at line 90 | ✓ PASS |
| Old Player.gd fire logic removed | `grep "_try_fire\|_fire_cooldown\|FIRE_INTERVAL" Player.gd` — no matches | ✓ PASS |
| Host self-delivery of weapon_unlocked | `CarPartPickup.gd:40-41` — `if collector_peer_id == multiplayer.get_unique_id(): game.weapon_unlocked(weapon_id)` | ✓ PASS |
| SpinningTires damage guard is host-only | `SpinningTires.gd:66` — `if not multiplayer.is_server(): return` | ✓ PASS |
| WeaponManager.reset() called in game-over | `grep "WeaponManager.*reset" GameState.gd` — found at line 55 | ✓ PASS |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| WEAP-01 | 04-01 | Enemies drop car-part pickup on death (random chance) | ✓ SATISFIED | `Game.gd:91` — `randf() < 0.25` drop branch |
| WEAP-02 | 04-01 | Player walks over pickup → weapon unlock triggered | ✓ SATISFIED | **CR-01 FIXED.** `CarPartPickup.gd:40-43` — both host and client delivery paths live |
| WEAP-03 | 04-01, 04-02 | Collecting car-part unlocks weapon in WeaponManager | ✓ SATISFIED | add_weapon() correctly called for all players; host path via direct call, clients via RPC |
| WEAP-04 | 04-02, 04-03, 04-04 | Active weapons fire automatically on independent cooldown timers | ✓ SATISFIED | ExhaustFlames, AntennaBeam, HornShockwave all have `autostart=true` Timers; SpinningTires uses _physics_process |
| WEAP-05 | 04-02 | Player holds up to 6 active weapons | ✓ SATISFIED | `WeaponManager.gd:9` — `const MAX_WEAPONS: int = 6`; checked at add_weapon line 79 |
| WEAP-06 | 04-03, 04-04, 04-05 | At least 5 car-themed weapons | ✓ SATISFIED | All 5 weapon files exist with substantive implementations |
| WEAP-06a | 04-03 | Exhaust Flames — fire cone behind player | ✓ SATISFIED | `ExhaustFlames.gd` — COOLDOWN=1.5, HALF_ANGLE=deg_to_rad(30), cone_dir=-aim_dir |
| WEAP-06b | 04-03 | Spinning Tires — orbiting projectiles | ✓ SATISFIED | **CR-03 FIXED.** `SpinningTires.gd` — 3 orbiting Area2D nodes; `if not multiplayer.is_server(): return` at line 66 |
| WEAP-06c | 04-04 | Antenna Beam — piercing laser | ✓ SATISFIED | `AntennaBeam.gd` — 500×8px Area2D, 2s Timer, `get_overlapping_bodies()` piercing |
| WEAP-06d | 04-04 | Horn Shockwave — close-range area burst | ✓ SATISFIED | `HornShockwave.gd` — 150px radius, 3s Timer, 360° overlap, Tween ring visual |
| WEAP-06e | 04-05 | Airbag Shield — damage-absorbing shell | ✓ SATISFIED | `AirbagShield.gd` + `receive_damage` intercept + `consume_airbag()` wiring |
| WEAP-07 | 04-02, 04-05 | weapon_level data model at unlock=1 (Phase 6 ready) | ✓ SATISFIED | `WeaponManager.gd:90` — `weapon_level[weapon_id] = 1`; reset() clears at line 110 |
| WEAP-08 | 04-05 | All weapons reset on death | ✓ SATISFIED | `GameState.gd:53-55` — reset loop before scene change; `WeaponManager.reset()` clears all state |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `scenes/Player.gd` | 91 | `@rpc("any_peer", "call_remote", "reliable")` on `receive_damage` with no sender validation | ⚠️ Warning | Pre-Phase-4 issue; any peer can damage any player; low risk in LAN context but violates host-authoritative contract |
| `scenes/Player.gd` | 93, 98, 101 | Three `print()` debug calls inside `receive_damage` | ℹ️ Info | Output spam in debug builds; performance impact at high damage rates |
| `scenes/weapons/WeaponManager.gd` | 107-108 | `deactivate()` + `queue_free()` called in same reset loop | ⚠️ Warning | Fragile double-free pattern; unlikely to crash in practice due to Godot's batched queue_free |
| `scenes/pickups/CarPartPickup.gd` | 29 | `_pickup_name` parameter received but never used (only prefixed `_`) | ℹ️ Info | Dead parameter adds RPC payload; cosmetic issue |

*Note: Both Phase-4 blocker anti-patterns (CR-01 in Game.gd, CR-03 in SpinningTires.gd) are now resolved. The `weapon_unlocked` RPC annotation remains `call_remote` — this is correct because the host self-delivery fix is implemented on the caller side (CarPartPickup), so the RPC annotation is no longer a problem.*

---

## Human Verification Required

### 1. Airbag Re-arm Visual Not Wired

**Test:** Collect an AirbagShield pickup. Take a lethal hit — confirm ring disappears. Walk over a second AirbagShield pickup. Check if the ring reappears.
**Expected:** Ring should reappear after second pickup re-arms the charge.
**Why human:** The re-arm branch in `add_weapon()` (WeaponManager.gd:83-85) only sets `airbag_active=true` but does NOT call `AirbagShield.show_ring()` on the existing hidden node. The ring will stay hidden even though the charge is active. This is a known cosmetic limitation documented in prior review; cannot verify presence/absence of this sub-behavior without running the game.

### 2. Weapon Visual Appearance (All Weapons)

**Test:** Collect each of the 5 weapons via CarPartPickup. For each weapon: confirm it visually fires/activates.
**Expected:** ExhaustFlames shows orange flash behind player every 1.5s; SpinningTires shows 3 grey circles orbiting; AntennaBeam flashes cyan beam toward enemies every 2s; HornShockwave shows yellow expanding ring every 3s; AirbagShield shows yellow ring around player.
**Why human:** Visual rendering (ColorRect visibility, Tween animations, orbit positions) cannot be verified by static code inspection.

---

## Gaps Summary

No gaps remain. Both previously-identified blockers are resolved:

**CR-01 (Host Weapon Unlock) — CLOSED:** `CarPartPickup.gd` now contains an explicit host self-delivery branch at lines 40-43. When `collector_peer_id == multiplayer.get_unique_id()` (host collecting), `game.weapon_unlocked(weapon_id)` is called directly — bypassing the `call_remote` RPC annotation entirely. The client path remains unchanged via `game.weapon_unlocked.rpc_id(collector_peer_id, weapon_id)`. Both delivery paths are now live and correct.

**CR-03 (SpinningTires D-14 Guard) — CLOSED:** `SpinningTires._physics_process` line 66 now reads `if not multiplayer.is_server(): return`, consistent with ExhaustFlames, AntennaBeam, and HornShockwave. The old `player.is_multiplayer_authority()` guard that allowed clients to apply damage locally has been replaced. D-14 host-only damage is now enforced across all 5 weapons.

Two human verification items remain (visual appearance, airbag re-arm visual), but these do not block phase goal delivery — all 13 observable truths are now code-verified.

---

*Verified: 2026-05-31T16:00:00Z*
*Verifier: OpenCode (gsd-verifier)*
*Re-verification after: CR-01 (host weapon unlock), CR-03 (SpinningTires is_server guard)*
