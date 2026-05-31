---
phase: 04-weapons-and-item-pickups
verified: 2026-05-31T15:00:00Z
status: gaps_found
score: 11/13 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Player walking over CarPartPickup triggers weapon unlock on ALL players including the host"
    status: failed
    reason: "weapon_unlocked is @rpc('authority', 'call_remote', 'reliable'). When host (peer 1) collects a pickup, _request_collect runs directly on host then calls game.weapon_unlocked.rpc_id(1, weapon_id). Godot's call_remote means the RPC does NOT execute on the sender — so rpc_id(1, ...) from peer 1 is a no-op. The host player silently never receives the weapon. Affects 100% of solo-host sessions and the host player in all multiplayer sessions."
    artifacts:
      - path: "scenes/pickups/CarPartPickup.gd"
        issue: "_request_collect calls game.weapon_unlocked.rpc_id(collector_peer_id, weapon_id) unconditionally. When collector_peer_id == multiplayer.get_unique_id() (host), call_remote skips local execution."
      - path: "scenes/Game.gd"
        issue: "weapon_unlocked declared @rpc('authority', 'call_remote', 'reliable') — call_remote prevents host from receiving its own RPC call."
    missing:
      - "In CarPartPickup._request_collect(), add host self-delivery branch: if collector_peer_id == multiplayer.get_unique_id(): game.weapon_unlocked(weapon_id) else: game.weapon_unlocked.rpc_id(collector_peer_id, weapon_id)"
      - "Or change weapon_unlocked to @rpc('authority', 'call_local', 'reliable') and add an internal peer-id guard to skip non-target peers"

  - truth: "SpinningTires applies damage on host only (D-14 host-only damage requirement)"
    status: failed
    reason: "SpinningTires._physics_process uses player.is_multiplayer_authority() (owning peer check) instead of multiplayer.is_server() (host check) for the damage guard at line 66. In a 2-player session: the host's own player correctly applies damage (host is also the authority for host's player). But a client player's SpinningTires also passes is_multiplayer_authority() on the client's own machine, causing the client to apply damage directly via body.take_damage(DAMAGE) — bypassing host-authoritative damage. D-14 spec explicitly required 'Damage detection is HOST-ONLY'. This also risks duplicate damage if both peers apply it."
    artifacts:
      - path: "scenes/weapons/SpinningTires.gd"
        issue: "Line 66: 'if not player.is_multiplayer_authority(): return' — should be 'if not multiplayer.is_server(): return' to match D-14 and the host-only pattern used by ExhaustFlames, AntennaBeam, HornShockwave."
    missing:
      - "Replace 'if not player.is_multiplayer_authority(): return' with 'if not multiplayer.is_server(): return' in _physics_process damage path"
---

# Phase 4: Weapons & Item Pickups — Verification Report

**Phase Goal:** Vampire Survivors weapon loop — enemies drop car-part pickups, player collects to unlock weapons; 5 car-themed weapons implemented; WeaponManager is child of Player. Phase 4 = unlock only (Level 1); upgrades come in Phase 6.
**Verified:** 2026-05-31T15:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | Enemy death has a 25% chance to spawn a CarPartPickup visible on all clients | ✓ VERIFIED | `Game.gd:91` — `if randf() < 0.25:` spawns via PickupSpawner with type="car_part"; CAR_PART_IDS has all 5 weapon IDs |
| 2  | Player walking over CarPartPickup triggers RPC chain → weapon_unlocked back to owning peer | ✗ FAILED | Client path works. Host path broken: `weapon_unlocked.rpc_id(1, weapon_id)` from peer 1 is a no-op due to `call_remote` (CR-01) |
| 3  | CarPartPickup despawns on all clients after collection | ✓ VERIFIED | `CarPartPickup.gd:40` — `queue_free()` on host propagates via PickupSpawner; `_collected` guard prevents double-free |
| 4  | Double-collect is prevented | ✓ VERIFIED | `CarPartPickup.gd:33-35` — `if _collected: return` runs on host before any state change |
| 5  | WeaponManager is a child Node of Player.tscn | ✓ VERIFIED | `Player.tscn:69` — `[node name="WeaponManager" type="Node" parent="."]` with WeaponManager.gd script |
| 6  | Player.gd delegates fire to WeaponManager, old fire logic removed | ✓ VERIFIED | `Player.gd:53-54` — `if has_node("WeaponManager"): $WeaponManager.tick(delta)`; no FIRE_INTERVAL, _fire_cooldown, _try_fire, or _find_nearest_enemy present |
| 7  | add_weapon() silently caps at MAX_WEAPONS=6 and ignores duplicates | ✓ VERIFIED | `WeaponManager.gd:79-88` — cap check at line 79; duplicate check at line 87; airbag re-arm special case at 82-86 |
| 8  | All 5 car-themed weapons implemented and fire automatically | ✓ VERIFIED | ExhaustFlames.gd, SpinningTires.gd, AntennaBeam.gd, HornShockwave.gd, AirbagShield.gd all exist; all timer-based weapons have `autostart = true` |
| 9  | SpinningTires applies damage on host only (D-14) | ✗ FAILED | `SpinningTires.gd:66` uses `player.is_multiplayer_authority()` instead of `multiplayer.is_server()`; client players apply damage locally (CR-03) |
| 10 | Airbag intercepts lethal hits; ring hidden on consumption | ✓ VERIFIED | `Player.gd:95-98` — `if health - amount <= 0 and ... $WeaponManager.airbag_active: health = 1; $WeaponManager.consume_airbag()`; `WeaponManager.gd:166-169` — `consume_airbag()` sets flag false and calls `AirbagShield.hide_ring()` |
| 11 | weapon_level dict initialized to 1 at unlock (WEAP-07 data model) | ✓ VERIFIED | `WeaponManager.gd:90` — `weapon_level[weapon_id] = 1` in add_weapon; `reset()` clears at line 110 |
| 12 | GameState._broadcast_game_over calls WeaponManager.reset() on all players (WEAP-08) | ✓ VERIFIED | `GameState.gd:53-55` — loops over "players" group; `has_node("WeaponManager")` guard; calls `p.get_node("WeaponManager").reset()` before `change_scene_to_file` |
| 13 | CarPartPickup pre-registered in PickupSpawner before any enemy can die | ✓ VERIFIED | `Game.gd:31-32` — both XpOrb and CarPartPickup registered in `_ready()` via `add_spawnable_scene` |

**Score:** 11/13 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scenes/pickups/CarPartPickup.tscn` | Area2D pickup scene, collision_layer=64, collision_mask=2 | ✓ VERIFIED | Confirmed: `collision_layer = 64`, `collision_mask = 2`, root CarPartPickup Area2D |
| `scenes/pickups/CarPartPickup.gd` | _collected guard, _on_body_entered, _request_collect RPC | ✓ VERIFIED | All present; `@rpc("any_peer", "call_remote", "reliable")` on _request_collect |
| `scenes/Game.gd` | 25% drop branch, weapon_unlocked RPC, type-dispatch _do_spawn_pickup | ✓ EXISTS / ⚠️ CR-01 BUG | 25% drop verified; weapon_unlocked RPC exists but `call_remote` breaks host self-delivery |
| `scenes/weapons/WeaponManager.gd` | add_weapon, reset, tick, MAX_WEAPONS=6, weapon_level | ✓ VERIFIED | All present; 169 lines; full weapon API wired |
| `scenes/Player.tscn` | WeaponManager child node | ✓ VERIFIED | Node at line 69 with WeaponManager.gd script |
| `scenes/Player.gd` | WeaponManager.tick delegation; airbag intercept in receive_damage | ✓ VERIFIED | Both wired; consume_airbag() call at line 97 |
| `scenes/weapons/ExhaustFlames.gd` | Cone Area2D, 1.5s Timer autostart, 60° filter, host-only damage | ✓ VERIFIED | COOLDOWN=1.5, HALF_ANGLE=deg_to_rad(30), `if not multiplayer.is_server(): return` before damage |
| `scenes/weapons/SpinningTires.gd` | 3 orbit Area2D, _hit_times dict, host-only damage guard | ✓ EXISTS / ✗ WRONG GUARD | Exists and substantial; damage guard uses `is_multiplayer_authority()` instead of `is_server()` — CR-03 |
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
| `Game.gd weapon_unlocked` | `Player WeaponManager.add_weapon` | `rpc_id(collector_peer_id, weapon_id)` | ✗ PARTIAL | Works for clients; broken for host (CR-01 — `call_remote` makes `rpc_id(1, ...)` a no-op on host) |
| `Player.gd _physics_process` | `WeaponManager.tick(delta)` | `$WeaponManager.tick(delta)` | ✓ WIRED | Player.gd:53-54 |
| `WeaponManager.gd add_weapon` | Weapon node activation | `_activate_weapon_node(weapon_id)` | ✓ WIRED | WeaponManager.gd:94; dispatches to all 5 weapons via match block |
| `Player.gd receive_damage` | `WeaponManager.airbag_active` → intercept | `$WeaponManager.consume_airbag()` | ✓ WIRED | Player.gd:95-98 |
| `GameState._broadcast_game_over` | `WeaponManager.reset()` | loop over players group | ✓ WIRED | GameState.gd:53-55, before scene change |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `CarPartPickup.gd` | `weapon_id` | Set at spawn time from `CAR_PART_IDS[randi() % ...]` in `_do_spawn_pickup` | ✓ | ✓ FLOWING — random weapon ID assigned from array at spawn |
| `WeaponManager.gd` | `unlocked_weapons`, `weapon_level` | `add_weapon()` called from `weapon_unlocked` RPC | ✓ (clients) / ✗ (host) | ⚠️ HOLLOW for host — CR-01 means host never populates these from pickups |
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
| Host self-delivery of weapon_unlocked | `weapon_unlocked` is `call_remote`; `rpc_id(1,...)` from peer 1 is a no-op | ✗ FAIL |
| SpinningTires damage guard is host-only | `SpinningTires.gd:66` uses `player.is_multiplayer_authority()` not `multiplayer.is_server()` | ✗ FAIL |
| WeaponManager.reset() called in game-over | `grep "WeaponManager.*reset" GameState.gd` — found at line 55 | ✓ PASS |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| WEAP-01 | 04-01 | Enemies drop car-part pickup on death (random chance) | ✓ SATISFIED | `Game.gd:91` — `randf() < 0.25` drop branch |
| WEAP-02 | 04-01 | Player walks over pickup → weapon unlock triggered | ⚠️ PARTIAL | Client path works; host player path broken by CR-01 |
| WEAP-03 | 04-01, 04-02 | Collecting car-part unlocks weapon in WeaponManager | ⚠️ PARTIAL | add_weapon() correct; delivery broken for host (CR-01) |
| WEAP-04 | 04-02, 04-03, 04-04 | Active weapons fire automatically on independent cooldown timers | ✓ SATISFIED | ExhaustFlames, AntennaBeam, HornShockwave all have `autostart=true` Timers; SpinningTires uses _physics_process |
| WEAP-05 | 04-02 | Player holds up to 6 active weapons | ✓ SATISFIED | `WeaponManager.gd:9` — `const MAX_WEAPONS: int = 6`; checked at add_weapon line 79 |
| WEAP-06 | 04-03, 04-04, 04-05 | At least 5 car-themed weapons | ✓ SATISFIED | All 5 weapon files exist with substantive implementations |
| WEAP-06a | 04-03 | Exhaust Flames — fire cone behind player | ✓ SATISFIED | `ExhaustFlames.gd` — COOLDOWN=1.5, HALF_ANGLE=deg_to_rad(30), cone_dir=-aim_dir |
| WEAP-06b | 04-03 | Spinning Tires — orbiting projectiles | ✓ SATISFIED (with WARNING) | `SpinningTires.gd` — 3 orbiting Area2D nodes; damage guard wrong (CR-03) but weapon is functional |
| WEAP-06c | 04-04 | Antenna Beam — piercing laser | ✓ SATISFIED | `AntennaBeam.gd` — 500×8px Area2D, 2s Timer, `get_overlapping_bodies()` piercing |
| WEAP-06d | 04-04 | Horn Shockwave — close-range area burst | ✓ SATISFIED | `HornShockwave.gd` — 150px radius, 3s Timer, 360° overlap, Tween ring visual |
| WEAP-06e | 04-05 | Airbag Shield — damage-absorbing shell | ✓ SATISFIED | `AirbagShield.gd` + `receive_damage` intercept + `consume_airbag()` wiring |
| WEAP-07 | 04-02, 04-05 | weapon_level data model at unlock=1 (Phase 6 ready) | ✓ SATISFIED | `WeaponManager.gd:90` — `weapon_level[weapon_id] = 1`; reset() clears at line 110 |
| WEAP-08 | 04-05 | All weapons reset on death | ✓ SATISFIED | `GameState.gd:53-55` — reset loop before scene change; `WeaponManager.reset()` clears all state |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `scenes/Game.gd` | 208 | `@rpc("authority", "call_remote", "reliable")` on `weapon_unlocked` | 🛑 Blocker | Host player never receives weapon unlock — core pickup loop broken for host |
| `scenes/weapons/SpinningTires.gd` | 66 | `player.is_multiplayer_authority()` instead of `multiplayer.is_server()` for damage guard | 🛑 Blocker | Client-authority players apply SpinningTires damage directly, bypassing host-authoritative combat (D-14 violated) |
| `scenes/Player.gd` | 91 | `@rpc("any_peer", "call_remote", "reliable")` on `receive_damage` with no sender validation | ⚠️ Warning | Pre-Phase-4 issue; any peer can damage any player; low risk in LAN context but violates host-authoritative contract |
| `scenes/Player.gd` | 93, 98, 101 | Three `print()` debug calls inside `receive_damage` | ℹ️ Info | Output spam in debug builds; performance impact at high damage rates |
| `scenes/weapons/WeaponManager.gd` | 107-108 | `deactivate()` + `queue_free()` called in same reset loop | ⚠️ Warning | Fragile double-free pattern; unlikely to crash in practice due to Godot's batched queue_free |
| `scenes/pickups/CarPartPickup.gd` | 29 | `_pickup_name` parameter received but never used (only prefixed `_`) | ℹ️ Info | Dead parameter adds RPC payload; cosmetic issue |

---

## Human Verification Required

### 1. Airbag Re-arm Visual Not Wired

**Test:** Collect an AirbagShield pickup. Take a lethal hit — confirm ring disappears. Walk over a second AirbagShield pickup. Check if the ring reappears.
**Expected:** Ring should reappear after second pickup re-arms the charge.
**Why human:** The code review (04-REVIEW.md) and 04-05-SUMMARY.md both acknowledge this is a known stub — the re-arm branch in `add_weapon()` only sets `airbag_active=true` but does NOT call `AirbagShield.show_ring()` on the existing hidden node. The ring will stay hidden even though the charge is active. Cannot verify presence/absence of this sub-behavior without running the game.

### 2. Weapon Visual Appearance (All Weapons)

**Test:** Collect each of the 5 weapons via CarPartPickup. For each weapon: confirm it visually fires/activates.
**Expected:** ExhaustFlames shows orange flash behind player every 1.5s; SpinningTires shows 3 grey circles orbiting; AntennaBeam flashes cyan beam toward enemies every 2s; HornShockwave shows yellow expanding ring every 3s; AirbagShield shows yellow ring around player.
**Why human:** Visual rendering (ColorRect visibility, Tween animations, orbit positions) cannot be verified by static code inspection.

### 3. Host Player Weapon Unlock (CR-01 regression confirmation)

**Test:** Run as solo host. Kill enemies until a CarPartPickup drops. Walk over it. Check if a weapon activates.
**Expected (current broken state):** No weapon activates — pickup despawns but host's WeaponManager never receives add_weapon() call.
**Why human:** Confirms CR-01 real-world behavior in the actual Godot runtime (not just code analysis).

---

## Gaps Summary

Two critical gaps block full phase goal delivery:

**Gap 1 — Host Weapon Unlock (CR-01):** The `weapon_unlocked` RPC on Game.gd uses `call_remote`, which prevents the RPC from executing on the sender. When the host picks up a car-part pickup, `_request_collect` runs directly on the host (correct), but the subsequent `weapon_unlocked.rpc_id(1, weapon_id)` is a no-op because peer 1 is sending to itself with `call_remote`. The host player silently never receives weapon unlocks from pickups. This affects 100% of solo-host play and the host player in all multiplayer sessions. Fix: add a host self-call branch in `_request_collect` when `collector_peer_id == multiplayer.get_unique_id()`.

**Gap 2 — SpinningTires Damage Authority (CR-03):** `SpinningTires._physics_process` uses `player.is_multiplayer_authority()` as the damage guard instead of `multiplayer.is_server()`. Per D-14, damage detection must be host-only. In a 2-player session, the client player's SpinningTires will apply `body.take_damage(DAMAGE)` locally, while the host's SpinningTires may also apply it — resulting in doubled damage or clients applying damage without host validation. Fix: replace `if not player.is_multiplayer_authority(): return` with `if not multiplayer.is_server(): return` in the damage path.

**CR-02** (receive_damage lacks sender validation) is a pre-Phase-4 issue, not introduced in this phase, and is documented as a known limitation of the LAN-trusted-peers model. It is recorded as a warning but does not block this phase's deliverables.

Both blockers are 1-line fixes. All 5 weapons exist and fire; the data models are correct; reset is wired. The phase is structurally complete but has two targeted runtime correctness bugs that need patching before the weapon loop works correctly for all players.

---

*Verified: 2026-05-31T15:00:00Z*
*Verifier: OpenCode (gsd-verifier)*
