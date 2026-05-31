---
phase: 04-weapons-and-item-pickups
reviewed: 2026-05-31T14:32:19Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - autoloads/GameState.gd
  - scenes/Game.gd
  - scenes/Player.gd
  - scenes/pickups/CarPartPickup.gd
  - scenes/weapons/AirbagShield.gd
  - scenes/weapons/AntennaBeam.gd
  - scenes/weapons/ExhaustFlames.gd
  - scenes/weapons/HornShockwave.gd
  - scenes/weapons/SpinningTires.gd
  - scenes/weapons/WeaponManager.gd
findings:
  critical: 3
  warning: 4
  info: 3
  total: 10
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-05-31T14:32:19Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 4 introduces WeaponManager, five car-part weapons, and the CarPartPickup collection flow. The overall architecture is sound — `call_deferred` for weapon-node add_child is correct, the W1 double-collect `_collected` guard is present on the host side, and the Timer-based weapons all guard with `is_multiplayer_authority()` before firing. However, three critical bugs were found:

1. **Host self-delivery is broken for weapon unlocks** — `weapon_unlocked` uses `call_remote`, so when the host player picks up a car part, `rpc_id(1, weapon_id)` is a no-op and the host never gains the weapon.
2. **`receive_damage` lacks an authority guard** — any peer can call this RPC on any player's node and reduce their health, bypassing the host-authoritative damage model.
3. **`SpinningTires._physics_process` uses `is_multiplayer_authority()` (owning peer) instead of `is_server()` for damage** — in a 2-player game the host's own player correctly applies damage, but any client-authority player on a non-host peer also applies damage, duplicating it alongside whatever the host would do; the intent was host-only hit detection per D-14.

Four warnings cover the airbag re-arm ring visual regression (acknowledged in summary notes), a stale `_pickup_name` parameter, `receive_damage` debug `print` calls, and a potential null-deref from double `queue_free` in reset.

---

## Critical Issues

### CR-01: Host player never receives weapon unlock (host collects own pickup)

**File:** `scenes/pickups/CarPartPickup.gd:39`

**Issue:** `game.weapon_unlocked` is declared `@rpc("authority", "call_remote", "reliable")` (Game.gd line 208). When the host is the collector, `_request_collect` runs directly on the host (line 24), then calls `game.weapon_unlocked.rpc_id(collector_peer_id, weapon_id)` where `collector_peer_id == 1` (the host's own peer id). In Godot 4, `call_remote` means the RPC is **not** executed on the sender — so `rpc_id(1, ...)` called from peer 1 is a no-op. The host player silently never receives the weapon.

The same `call_remote` trap already bit `XpOrb.gd` and was explicitly documented as a pitfall — XpOrb avoids it by calling `_request_collect(name)` directly (no RPC) when `is_server()`. `CarPartPickup` copies the `_collected` guard but misses this host-local-call fix for the downstream `weapon_unlocked` call.

**Fix:**
```gdscript
# In CarPartPickup._request_collect(), replace:
game.weapon_unlocked.rpc_id(collector_peer_id, weapon_id)

# With:
if collector_peer_id == multiplayer.get_unique_id():
    # Host is the collector — call_remote would be a no-op; invoke directly
    game.weapon_unlocked(weapon_id)
else:
    game.weapon_unlocked.rpc_id(collector_peer_id, weapon_id)
```

Alternatively, change `weapon_unlocked` to `@rpc("authority", "call_local", "reliable")` and always use `rpc_id`, but that would require a guard inside `weapon_unlocked` to only act on the targeted peer, which is the existing pattern anyway.

---

### CR-02: `receive_damage` has no authority guard — any peer can damage any player

**File:** `scenes/Player.gd:91-104`

**Issue:** `receive_damage` is declared `@rpc("any_peer", "call_remote", "reliable")` with no check that the caller is actually the host. The comment explains this is used because "host (peer 1) is NOT the node's multiplayer authority", but `any_peer` means **any connected peer** can call `player_node.receive_damage.rpc_id(target_peer_id, amount)` targeting any player and dealing arbitrary damage. There is no `multiplayer.get_remote_sender_id() == 1` guard inside the function body.

In a LAN setting with trusted peers this is low practical risk, but it violates the host-authoritative damage contract stated in CONTEXT.md D-07 / ROADMAP Pitfall 3, and any peer misbehaving (even unintentionally, e.g., a desync bug sending a duplicate) can kill another player.

**Fix:**
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func receive_damage(amount: int) -> void:
    # Guard: only host is authorised to deal damage
    if multiplayer.get_remote_sender_id() != 1:
        return
    # ... existing body
```

---

### CR-03: `SpinningTires` damage guard uses `is_multiplayer_authority()` (wrong authority) instead of `is_server()`

**File:** `scenes/weapons/SpinningTires.gd:66`

**Issue:** D-14 in CONTEXT.md states: "Collision detection for damage is **host-only** (`is_multiplayer_authority()` guard OR `multiplayer.is_server()` check on the damage-apply path)". The comment says "D-14: Host-only damage detection" but the guard is `if not player.is_multiplayer_authority()` — the *player's* multiplayer authority, which is the **owning peer** (set by `set_multiplayer_authority(peer_id)`). 

This means:
- On peer A who owns their own character: `player.is_multiplayer_authority() == true` → damage runs.
- On the host (peer 1) watching peer A's player: `player.is_multiplayer_authority() == false` → damage skipped.

So damage is applied by the **owning peer**, not the host. In a two-player game where the host has their own player, the host correctly applies damage for their own character. But for client-owned players (any non-host player), damage runs on the client, not the host — violating the host-authoritative damage model. Furthermore, if somehow both the owning peer AND the host's physics tick overlap, damage could apply twice.

All four other timer-based weapons correctly split: `is_multiplayer_authority()` guard fires the visual, then an inner `if not multiplayer.is_server(): return` guard before calling `body.take_damage()`. SpinningTires skips this second guard entirely.

**Fix:**
```gdscript
func _physics_process(delta: float) -> void:
    if not _active or _tires.is_empty():
        return
    _angle += ORBIT_SPEED * delta
    var player: Node = get_parent().get_parent()
    if not is_instance_valid(player):
        return
    # Update orbit positions — runs on ALL peers for visual sync (D-14 visual half)
    for i in range(_tires.size()):
        var angle_offset: float = _angle + (float(i) * TAU / 3.0)
        _tires[i].global_position = player.global_position + Vector2(
            cos(angle_offset), sin(angle_offset)
        ) * ORBIT_RADIUS
    # D-14: Host-only damage detection — must use is_server(), NOT is_multiplayer_authority()
    if not multiplayer.is_server():
        return
    var now: float = Time.get_unix_time_from_system()
    for tire in _tires:
        for body in tire.get_overlapping_bodies():
            if not body.is_in_group("enemies"):
                continue
            var key: String = str(body.get_path())
            var last_hit: float = _hit_times.get(key, -INF)
            if now - last_hit >= HIT_COOLDOWN:
                _hit_times[key] = now
                body.take_damage(DAMAGE)
```

---

## Warnings

### WR-01: Airbag re-arm path does not call `show_ring()` — ring stays hidden after re-collect

**File:** `scenes/weapons/WeaponManager.gd:82-85`

**Issue:** When the player picks up a second Airbag car part after their charge was consumed (`airbag_active == false`), `add_weapon` enters the re-arm branch (lines 82–85), sets `airbag_active = true`, and returns early. `_activate_weapon_node` is never called, and neither is `AirbagShield.show_ring()`. The AirbagShield node (which already exists as a child from the first collect) keeps its ring invisible. The airbag is mechanically active (`airbag_active = true`) but visually appears uncharged — a misleading game state for the player.

This was acknowledged in the phase-05 summary notes as a known gap deferred to Phase 5 polish. Recording here as a WARNING so it is tracked for fix.

**Fix:**
```gdscript
# In add_weapon(), re-arm branch:
if weapon_id == "airbag_shield" and unlocked_weapons.has(weapon_id):
    if not airbag_active:
        airbag_active = true
        # Re-show ring on the existing AirbagShield node
        if has_node("AirbagShield"):
            get_node("AirbagShield").show_ring()
        return true
    return false
```

---

### WR-02: `WeaponManager.reset()` calls `deactivate()` then `queue_free()` — double-free risk on weapon nodes

**File:** `scenes/weapons/WeaponManager.gd:107-108`

**Issue:** `reset()` calls both `get_node(node_name).deactivate()` and then immediately `get_node(node_name).queue_free()` on the same node. Every `deactivate()` implementation (e.g., `ExhaustFlames.deactivate`, `AntennaBeam.deactivate`) already calls `_timer.queue_free()` and `_area.queue_free()` on the weapon's internal children, then the outer `queue_free()` in `reset()` frees the weapon node itself. This is fine as written.

However, `AirbagShield.deactivate()` calls `_ring.queue_free()` and sets `_ring = null`, but the outer `queue_free()` then also schedules the AirbagShield node itself. If `deactivate()` + `queue_free()` are called in the same frame, `AirbagShield._ring` is freed twice if Godot processes the deferred queue between the two calls. In practice Godot batches `queue_free` calls so this is unlikely to crash, but the pattern is fragile — `deactivate()` logically finalises the node, making the subsequent `queue_free()` in `reset()` redundant if `deactivate()` itself called `queue_free` on self.

**Fix:** Have `deactivate()` on each weapon node call `queue_free()` on `self` at the end (as the single finalisation point), and remove the `queue_free()` call from `reset()`:
```gdscript
# In reset(), replace:
get_node(node_name).deactivate()
get_node(node_name).queue_free()
# With:
get_node(node_name).deactivate()  # deactivate() handles its own queue_free()
```
Each weapon's `deactivate()` should add `queue_free()` at its end. Alternatively, keep the current `reset()` pattern and remove `queue_free()` calls from within `deactivate()` bodies to make the ownership clear.

---

### WR-03: `_pickup_name` parameter in `_request_collect` is unused — vestigial dead parameter

**File:** `scenes/pickups/CarPartPickup.gd:29`

**Issue:** `_request_collect(_pickup_name: String, collector_peer_id: int)` receives `_pickup_name` but never uses it. The leading underscore signals intentional discard, but the parameter is passed by the caller (`name` — the node's own name) and exists in the RPC signature. The `XpOrb._request_collect` uses `_orb_name` for the same no-op pattern. In both cases the host already owns the node and uses `self` directly; the name parameter adds network payload and confusion. Worth removing to match the minimal interface principle.

**Fix:**
```gdscript
# Remove _pickup_name from signature:
@rpc("any_peer", "call_remote", "reliable")
func _request_collect(collector_peer_id: int) -> void:
    ...
# Update callers accordingly:
_request_collect(body.peer_id)           # host path
_request_collect.rpc_id(1, body.peer_id) # client path
```

---

### WR-04: `receive_damage` contains three `print()` debug calls — will spam output in production

**File:** `scenes/Player.gd:93, 98, 101`

**Issue:** Three `print()` calls fire on every damage event including every airbag absorption. In multiplayer with projectile spam these will flood the Godot output panel and measurably degrade performance in debug builds. The calls pre-date Phase 4 (they appear to be from Phase 3 integration) but remain in the submitted code.

```gdscript
print("receive_damage called! hp=", health, " -> ", health - amount)  # line 93
print("Airbag absorbed lethal hit! hp=1")                              # line 98
print("receive_damage done! hp=", health)                              # line 101
```

**Fix:** Remove all three `print()` calls. If damage tracing is needed during development, use `push_warning()` gated on a debug constant or Godot's built-in `OS.is_debug_build()`.

---

## Info

### IN-01: `weapon_unlocked` on Game.gd has no `is_multiplayer_authority()` guard inside its body

**File:** `scenes/Game.gd:209-218`

**Issue:** `weapon_unlocked` is `@rpc("authority", ...)` which means only the host (the node's authority holder) can *send* this RPC — correct. However the function body itself has no guard. If the RPC annotation is accidentally changed (or another path calls it locally without the RPC), it would execute on whatever peer runs it. A defensive `if multiplayer.get_unique_id() != multiplayer.get_remote_sender_id()` or simply `if multiplayer.is_server(): return` guard would protect against future refactors.

**Fix:** Not required for current correctness, but consider:
```gdscript
func weapon_unlocked(weapon_id: String) -> void:
    # Sanity: this should only run on the collecting peer, never on the host itself
    # (host calls rpc_id(collector_id, ...) so call_remote means it runs only on target)
    var my_player: Node = null
    ...
```

---

### IN-02: Node name collision probability with `randi() % 9999`

**File:** `scenes/Game.gd:79, 100, 106`

**Issue:** Enemy, XpOrb, and CarPart nodes use `randi() % 9999` for name suffixes. With 5 enemies and potentially many pickups alive simultaneously, the chance of a name collision within a single spawner's children is low but non-zero. Godot appends `@N` suffixes to deduplicate names automatically — so this does not crash — but it means node names are not stable and `get_node("CarPart_1234")` type lookups would be unreliable if ever used. The bullet spawner uses `% 99999` (5 digits) which is better.

**Fix:** Either use a monotonically incrementing counter (static var in Game.gd), or use Godot's built-in node name deduplication intentionally by accepting the `@N` suffix. A counter is cleaner:
```gdscript
static var _pickup_counter: int = 0
# ...
pickup.name = "CarPart_%d" % (_pickup_counter)
_pickup_counter += 1
```

---

### IN-03: `HornShockwave._spawn_ring_visual` adds a `ColorRect` to the Game scene's root — no cleanup if `queue_free` callback is missed

**File:** `scenes/weapons/HornShockwave.gd:80-84`

**Issue:** `parent_node.add_child(ring)` adds the ring to whatever node contains the Player (expected: the Game scene root). The tween calls `ring.queue_free` at the end. If the tween is interrupted (e.g., the scene changes mid-animation during a game-over), the `ring` ColorRect will leak in the scene tree until freed by the scene change itself. This is cosmetic-only risk and the scene change will ultimately free all nodes, but it's worth noting.

**Fix:** Store the ring reference and `queue_free` it in `deactivate()` if still valid, or use `tween.finished.connect(ring.queue_free)` with a fallback timer:
```gdscript
# Add a safety fallback:
var tween := ring.create_tween()
tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.35)
tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
tween.tween_callback(ring.queue_free)
# Fallback: auto-free after 1 second regardless
var fallback := get_tree().create_timer(1.0)
fallback.timeout.connect(func():
    if is_instance_valid(ring):
        ring.queue_free()
)
```

---

_Reviewed: 2026-05-31T14:32:19Z_
_Reviewer: OpenCode (gsd-code-reviewer)_
_Depth: standard_
