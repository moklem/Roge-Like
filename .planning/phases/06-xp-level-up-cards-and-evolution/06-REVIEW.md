---
phase: 06-xp-level-up-cards-and-evolution
reviewed: 2026-06-18T00:00:00Z
depth: standard
files_reviewed: 15
files_reviewed_list:
  - autoloads/GameState.gd
  - scenes/Game.gd
  - scenes/Player.gd
  - scenes/Player.tscn
  - scenes/pickups/XpOrb.gd
  - scenes/ui/CardOverlay.gd
  - scenes/ui/CardOverlay.tscn
  - scenes/ui/PlayerHUD.gd
  - scenes/ui/PlayerHUD.tscn
  - scenes/weapons/AirbagShield.gd
  - scenes/weapons/AntennaBeam.gd
  - scenes/weapons/ExhaustFlames.gd
  - scenes/weapons/HornShockwave.gd
  - scenes/weapons/SpinningTires.gd
  - scenes/weapons/WeaponManager.gd
findings:
  critical: 6
  warning: 7
  info: 3
  total: 16
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-06-18
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

The Phase 6 XP/level-up/card implementation is largely correct in structure. Host-authority is enforced in the right places and the RPC direction (host → owning peer via `rpc_id`) follows the established pattern from earlier phases. However, several issues will cause silent failures or incorrect behavior in multiplayer: a mismatched `@rpc` mode blocks the stat-boost RPC from ever reaching clients, the host's card-complete signal uses a leaky path that clears the wrong player's state, the `_check_stage_threshold` self-applies evolution on the owning peer without broadcasting it to other peers, a peer-ID spoofing hole exists in `confirm_card_pick`, and multiple debug `print()` statements remain in the hot damage path.

---

## Critical Issues

### CR-01: `_apply_stat_boost_rpc` declared `@rpc("authority")` but called via `.rpc_id()` from host — stat boosts silently fail for all clients

**File:** `scenes/Game.gd:410-404`

**Issue:** `_apply_stat_boost_rpc` is annotated `@rpc("authority", "call_remote", "reliable")`. In Godot 4, `"authority"` means only the node's multiplayer authority (peer 1 / host, since `Game` is not re-owned) can *send* this RPC — that is consistent. However, `"call_remote"` means the RPC body does NOT execute on the sender. When host calls `_apply_stat_boost_rpc.rpc_id(peer_id, ...)` (lines 404, 407), Godot routes it to the target peer correctly. The core issue is that when `peer_id == multiplayer.get_unique_id()` (i.e., the host player is picking a card), the host calls `.rpc_id(1, ...)` on itself, but `"call_remote"` prevents it from executing — the host's own stats are never boosted. The `"stat_boost"` and `"fallback"` card types are broken for the host player.

**Fix:**
```gdscript
# In _apply_card_effect, handle the host-local case explicitly:
"stat_boost":
    if peer_id == multiplayer.get_unique_id():
        _apply_stat_boost_rpc(card.get("stat", ""), card.get("amount", 10))  # direct call
    else:
        _apply_stat_boost_rpc.rpc_id(peer_id, card.get("stat", ""), card.get("amount", 10))
"fallback":
    if peer_id == multiplayer.get_unique_id():
        _apply_stat_boost_rpc("Damage", 5)
    else:
        _apply_stat_boost_rpc.rpc_id(peer_id, "Damage", 5)
```

---

### CR-02: `_check_stage_threshold` calls `set_evolution_stage()` locally on owning peer — other peers never see the visual stage change

**File:** `scenes/Player.gd:532-536`

**Issue:** `_check_stage_threshold` is called from within `receive_xp`, which runs on the owning peer only. It calls `set_evolution_stage(2)` or `set_evolution_stage(3)` as a plain local function call. `evolution_stage` IS in the `MultiplayerSynchronizer` config (Player.tscn line 28), so the integer itself replicates — but `set_evolution_stage` also calls `call_deferred("_swap_stage_visual", stage)` and applies the Stage-3 stat boost (`stage3_damage_mult`, `MAX_HP`, `health`). Other peers will receive the updated `evolution_stage` int, but `_swap_stage_visual` only runs on the peer that called `set_evolution_stage`. All non-owning peers will render the Stage-1 car sprite regardless of evolution level. The Stage-3 stat-bump also only applies on the owning peer; `stage3_damage_mult` is replicated but `MAX_HP` is not replicated, so Tank's +25 MAX_HP only exists on the owning peer.

**Fix:** `set_evolution_stage` is already an `@rpc("any_peer", "call_remote", "reliable")` — it just needs to be broadcast:
```gdscript
func _check_stage_threshold() -> void:
    if level == STAGE2_LEVEL and evolution_stage < 2:
        # Broadcast to all peers so every client swaps visuals
        set_evolution_stage.rpc(2)   # call_local would also work: set_evolution_stage(2) + rpc to others
        set_evolution_stage(2)       # apply locally on owning peer
    elif level == STAGE3_LEVEL and evolution_stage < 3:
        set_evolution_stage.rpc(3)
        set_evolution_stage(3)
```
Or change the `@rpc` mode to `"call_local"` and always call via `.rpc()`.

---

### CR-03: `confirm_card_pick` accepts `requester_peer_id` from the client — any peer can claim to be another player and steal their card pick

**File:** `scenes/Game.gd:344-362`

**Issue:** The RPC is `@rpc("any_peer", "call_remote", "reliable")`. The `requester_peer_id` is a parameter the *client* supplies. Although the host looks up the player node and checks `is_picking_card`, a malicious or glitched client can send `confirm_card_pick(victim_peer_id, card_index)` to force the host to apply a card effect to any player and clear their `is_picking_card` flag, denying them their level-up choice. The RPC sender identity should be used instead.

**Fix:**
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func confirm_card_pick(_unused_peer_id: int, card_index: int) -> void:
    if not multiplayer.is_server():
        return
    # Use actual sender identity — not the client-supplied parameter
    var requester_peer_id: int = multiplayer.get_remote_sender_id()
    if requester_peer_id == 0:
        requester_peer_id = multiplayer.get_unique_id()  # host calling locally
    # ... rest unchanged
```

---

### CR-04: `weapon_unlocked.rpc(...)` in `_apply_card_effect` broadcasts weapon unlock to ALL peers, not just the owning peer

**File:** `scenes/Game.gd:390`

**Issue:** `weapon_unlocked` is declared `@rpc("authority", "call_remote", "reliable")` (line 330). Calling `.rpc(...)` (no `_id`) sends it to every connected peer. Every player's WeaponManager will attempt to add the weapon to every player node in `get_nodes_in_group("players")` filtered by `collector_peer_id`. The filter prevents the wrong node being upgraded, but the weapon node itself (`_activate_weapon_node`) is instantiated and added as a child on *every* peer's copy of the target player node — resulting in every peer spawning a weapon scene child that should only exist on the owning peer's local game state. This is incorrect because weapon activation creates timers and Area2D nodes that will fire on all peers.

**Fix:**
```gdscript
"weapon_unlock":
    if peer_id == multiplayer.get_unique_id():
        weapon_unlocked(card["weapon_id"], peer_id)  # host-local call
    else:
        weapon_unlocked.rpc_id(peer_id, card["weapon_id"], peer_id)
```

---

### CR-05: `_card_pick_complete` clears `is_picking_card` by matching `local_id` on the receiving peer, but the `_for_peer_id` parameter is ignored — incorrect when host is also a player

**File:** `scenes/Game.gd:425-435`

**Issue:** `_card_pick_complete` is sent via `.rpc_id(requester_peer_id, requester_peer_id)` — it only ever runs on one peer. On that peer, it looks up `local_id = multiplayer.get_unique_id()` and clears the first player whose `peer_id` matches. This is correct for clients. However the parameter `_for_peer_id` is completely unused (underscore-prefixed, never read). If this function were ever called with `.rpc()` instead of `.rpc_id()` (e.g., by a future refactor), it would clear the wrong player's state on every peer. The unused parameter is a latent design trap.

Additionally, `hide_overlay()` is the correct method name in `CardOverlay.gd` (line 23), but `_card_pick_complete` calls `p.get_node("CardOverlay").hide_overlay()` — this is correct. No crash here, but the unused parameter makes the function contract misleading.

**Fix:** Remove the parameter or use it:
```gdscript
@rpc("authority", "call_remote", "reliable")
func _card_pick_complete() -> void:  # no parameter needed — "call_remote" + rpc_id guarantees correct peer
    var local_id := multiplayer.get_unique_id()
    for p in get_tree().get_nodes_in_group("players"):
        if p.peer_id == local_id:
            p.is_picking_card = false
            if p.has_node("CardOverlay"):
                p.get_node("CardOverlay").hide_overlay()
            if p.has_method("_update_xp_hud"):
                p._update_xp_hud()
            return
```
And update the call site: `_card_pick_complete.rpc_id(requester_peer_id)`.

---

### CR-06: `WeaponManager.MAX_WEAPONS = 3` but there are 6 weapon IDs — only 2 non-default weapons can ever be unlocked; card pool generates invalid "weapon_unlock" cards for weapons that can never be added

**File:** `scenes/weapons/WeaponManager.gd:9`, `scenes/Game.gd:370-376`, `scenes/Player.gd:544-551`

**Issue:** `MAX_WEAPONS` is 3 and `screws_and_bolts` is always added in `_ready()`, occupying one slot. That leaves 2 slots for the 5 optional weapons. Both `_build_card_pool_for_player` (Game.gd) and `_build_card_pool` (Player.gd) enumerate all 5 optional weapons and offer an "unlock" card for any that are not yet in `unlocked_weapons`. But once 2 are unlocked, `add_weapon()` silently returns `false` at the cap check (line 108) even though the card was presented and confirmed. The player receives no weapon but `is_picking_card` is cleared and the card pick is consumed. This is a silent no-op that wastes a level-up. The card pool should filter out weapons that cannot be added:

**Fix:** In both `_build_card_pool_for_player` and `_build_card_pool`:
```gdscript
for wid in ["exhaust_flames", "spinning_tires", "antenna_beam", "horn_shockwave", "airbag_shield"]:
    if not wm.unlocked_weapons.has(wid):
        # Only offer unlock if there is room
        if wm.unlocked_weapons.size() < WeaponManager.MAX_WEAPONS:
            pool.append({"type": "weapon_unlock", "weapon_id": wid})
```

---

## Warnings

### WR-01: Debug `print()` statements remain in `receive_damage` hot path — spams output on every hit

**File:** `scenes/Player.gd:443, 458, 468`

**Issue:** Three `print()` calls in `receive_damage` fire on every single damage event for every player during a session. In a multiplayer game with many projectiles these saturate the Godot output log and cause measurable frame hitches in debug builds. They should not ship.

**Fix:** Remove all three:
```gdscript
# Line 443: remove print("receive_damage called! ...")
# Line 458: remove print("Airbag absorbed lethal hit! ...")
# Line 468: remove print("receive_damage done! ...")
```

---

### WR-02: `_show_earth_shockwave` declared `@rpc("any_peer", ...)` — any client can trigger the visual on all peers

**File:** `scenes/Game.gd:606`

**Issue:** The earth shockwave visual RPC is annotated `"any_peer"`, meaning any connected client can call `_show_earth_shockwave.rpc(...)` from their client and have the visual render on all peers including the host. Only the host should be able to initiate this. Compare `_show_dash_shockwave` in `Player.gd` (line 416) which has the same problem but at least it is called from an authority-guarded context. For `_show_earth_shockwave` in `Game.gd`, an exploiting client could spam shockwave visuals.

**Fix:** Change to `@rpc("authority", "call_local", "unreliable_ordered")`. The function is only ever called by the host's `_tick_earth_effects`, so restricting to `"authority"` is safe.

---

### WR-03: `_check_stage_threshold` uses `level == STAGE2_LEVEL` (equality) — misses players who skip the exact threshold level

**File:** `scenes/Player.gd:533-536`

**Issue:** `receive_xp` handles multiple level-ups in one grant via a `while xp >= threshold` loop. If a player somehow crosses both STAGE2_LEVEL (5) and STAGE3_LEVEL (10) in a single XP grant (possible with large XP sources added in future phases), the `level == STAGE2_LEVEL` equality check will not fire for Stage 2 because by the time the loop exits, `level` is already 10. The stage 2 evolution would be skipped entirely, jumping straight to Stage 3 but with `evolution_stage` still at 1.

**Fix:** Use `>=` with the current `evolution_stage` guard:
```gdscript
func _check_stage_threshold() -> void:
    if level >= STAGE2_LEVEL and evolution_stage < 2:
        set_evolution_stage(2)
    if level >= STAGE3_LEVEL and evolution_stage < 3:  # use 'if', not 'elif'
        set_evolution_stage(3)
```

---

### WR-04: `AntennaBeam._on_fire_timer` uses `await get_tree().create_timer(0.2).timeout` inside a timer callback — risks use-after-free if weapon is deactivated during the await

**File:** `scenes/weapons/AntennaBeam.gd:82`

**Issue:** When `level >= 2`, the timer callback fires the first beam then awaits 0.2s before firing the second. There is a `is_instance_valid(self)` guard after the await (line 84). However, `player` and `weapon_manager` are captured by value as local variables before the await. If the player is downed, revived, or the weapon reset during those 0.2s, `player.global_position` and `level` used on lines 88-90 may refer to stale state. Specifically, if `player.is_downed` becomes true during the await, the second beam will still fire since the downed check (line 67) is not re-evaluated.

**Fix:** Re-check downed state after await:
```gdscript
await get_tree().create_timer(0.2).timeout
if not is_instance_valid(self):
    return
if not is_instance_valid(player) or player.is_downed:  # re-check after await
    return
```

---

### WR-05: `SpinningTires.damage_per_tick` ignores the `DAMAGE` constant entirely — introduces an inconsistency with other weapons

**File:** `scenes/weapons/SpinningTires.gd:62`

**Issue:** `damage_per_tick` is hardcoded as `12` (L1/L2) and `18` (L3), but the class-level `const DAMAGE: int = 15` is never used. Every other weapon uses its `DAMAGE` constant as the base. This is not a crash but it means the constant is dead code that misleads future maintainers — if someone tunes `DAMAGE` they get no effect.

**Fix:** Use the constant:
```gdscript
var damage_per_tick: int = int(float(DAMAGE) * (1.2 if level >= 3 else 0.8))
# Or explicit: L1/L2 = 12, L3 = 18 is actually not 15±, so document the deliberate override.
```
At minimum, either remove `const DAMAGE: int = 15` or add a comment explaining why it is not used.

---

### WR-06: `HornShockwave._on_fire_timer` mutates `_timer.wait_time` on every L2+ fire event — wait_time is permanently changed after first L2 shot

**File:** `scenes/weapons/HornShockwave.gd:61`

**Issue:** Inside `_on_fire_timer`, the line `_timer.wait_time = 2.5` is executed every time the timer fires at level 2. This is idempotent in practice, but it is wrong architecture: cooldown changes should be applied once in `upgrade_weapon`, not re-applied each fire. More importantly, if the weapon somehow downgrades (e.g., in a future reset-and-re-add path), the timer stays at 2.5s because `reset()` recreates the node but the upgrade path could cause this to persist. Currently harmless but fragile.

**Fix:** Apply the wait_time change once in `upgrade_weapon` callback or in `_on_fire_timer` only when the value differs:
```gdscript
if level >= 2 and _timer.wait_time != 2.5:
    _timer.wait_time = 2.5
```

---

### WR-07: `GameState._broadcast_game_over` directly mutates `p.xp`, `p.level`, `p.element_tier`, `p.is_picking_card` on all peers but these are owning-peer-authoritative variables

**File:** `autoloads/GameState.gd:57-63`

**Issue:** The broadcast runs on all peers (`call_local`), and on each peer it iterates all player nodes and resets their progression fields. For the local player node this is fine because the owning peer controls those fields. But for non-local player nodes (remote player representations), directly writing `p.xp = 0`, `p.level = 1`, etc. sets values in the local copy that the `MultiplayerSynchronizer` will overwrite from the owning peer on the next replication tick. Since the scene is about to change, this is practically harmless — but `p.set_evolution_stage(1)` calls `call_deferred("_swap_stage_visual", 1)` which runs after the `call_deferred`, potentially after `change_scene_to_file` is already queued. If the old scene is freed before the deferred callback runs, `_swap_stage_visual` will attempt to access freed child nodes.

**Fix:** Skip `set_evolution_stage` entirely in the game-over path since the scene is being destroyed anyway:
```gdscript
# Just reset the data fields; visual cleanup is unnecessary before scene change
p.xp = 0
p.level = 1
p.element_tier = 1
p.is_picking_card = false
p.evolution_stage = 1  # direct assignment, no deferred visual swap needed
```

---

## Info

### IN-01: `CardOverlay._refresh_display` iterates indices 0-2 hardcoded but pool can theoretically have fewer than 3 cards

**File:** `scenes/ui/CardOverlay.gd:37`

**Issue:** `_refresh_display` always loops `for i in range(3)`. The `_draw_cards` function in `Player.gd` pads to 3 entries with fallback cards (lines 569-571), so this is safe in current code. However `show_cards` in `CardOverlay.gd` does not pad — if `show_cards` is called with a raw pool (not via `_draw_cards`), the missing node will be hidden correctly (`card_node.visible = false`) so there is no crash. Worth noting but not a blocker.

---

### IN-02: `XpOrb._request_collect` accesses `p.XP_PER_ORB` as an instance property but it is a `const` — works in GDScript but is unconventional

**File:** `scenes/pickups/XpOrb.gd:40-42`

**Issue:** `p.XP_PER_ORB` accesses the constant through an instance reference. In GDScript 4 this works, but the idiomatic form for a class constant is `Player.XP_PER_ORB`. Using the instance reference means if `p` were ever `null` this would crash rather than produce a compile-time reference. Since `p` is already validated not-null at this point the risk is theoretical, but it is non-idiomatic.

---

### IN-03: `TODO` for Cooldown reduction in `_apply_stat_boost_rpc` — Cooldown cards are offered in the pool but do nothing

**File:** `scenes/Game.gd:420`

**Issue:** The card pool always includes a "Cooldown" stat boost card (Game.gd line 379, Player.gd line 556), but the matching arm in `_apply_stat_boost_rpc` is `pass`. A player will pick this card, the host will confirm it, and nothing will happen — no error, no feedback. The card appears to succeed but is a silent no-op. Either remove "Cooldown" from the pool until it is implemented, or show a "not yet implemented" message.

---

_Reviewed: 2026-06-18_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
