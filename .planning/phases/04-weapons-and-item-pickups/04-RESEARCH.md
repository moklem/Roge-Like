# Phase 4: Weapons & Item Pickups — Research

**Researched:** 2026-05-31
**Domain:** Godot 4 WeaponManager, Area2D weapon shapes, host-authoritative pickup collection, MultiplayerSpawner registration
**Confidence:** HIGH — all findings verified against live codebase and existing phase research documents

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Phase 4 implements **weapon unlock only**. When a player picks up a Car-Part, the corresponding weapon is added to their WeaponManager at Level 1. If they pick up the same part again (weapon already unlocked), it is silently ignored — no upgrade, no effect.
- **D-02:** WeaponManager stores `weapon_level: Dictionary` (weapon_id → int, default 1). This data model is in place so Phase 6 card picks can increment levels without structural changes.
- **D-03:** On enemy death, **25% random chance** of dropping a CarPartPickup. Which of the 5 car parts drops is uniformly random. Same pattern as XP orb drop (Game.gd `_on_enemy_died` already exists — add parallel pickup drop logic).
- **D-04:** CarPartPickup is a **separate scene** from XpOrb (different visual, different collection signal). Reuse the same PickupSpawner in Game.gd (already registered). Pre-register CarPartPickup scene in PickupSpawner's spawnable list.
- **D-05:** Collection is **host-authoritative** using the same `_collected` guard pattern as XpOrb.gd. Client steps on pickup → sends RPC to host → host validates, despawns, and sends `weapon_unlocked` RPC to owning player peer.
- **D-06:** **WeaponManager is a child Node of each Player node** (added to Player.tscn in this phase). It owns: `unlocked_weapons: Array[String]`, `weapon_level: Dictionary`, per-weapon Timer nodes for auto-fire cooldowns, Spinning Tires orbit nodes (3 Area2D children).
- **D-07:** WeaponManager **fires under the same authority pattern** as the existing `_try_fire` in Player.gd: owning peer's WeaponManager ticks cooldowns; if `multiplayer.is_server()` → spawn directly; if client → send `request_fire` RPC to host.
- **D-08:** The existing `FIRE_INTERVAL` / `_try_fire()` in Player.gd is **moved into WeaponManager** as the "ScrewsAndBolts" weapon entry. Player.gd delegates to WeaponManager.
- **D-09: Exhaust Flames** — Periodic **cone Area2D** aimed at nearest enemy. ~1.5s cooldown. ~60° arc, ~120px radius. Enemies inside cone at moment of fire take damage. Visual: ColorRect triangle shape. Host detects hits.
- **D-10: Spinning Tires** — **3 Area2D nodes orbit the player** continuously (120° apart, ~50px radius). Always active when unlocked. Host checks overlap each physics frame; ~0.5s per-enemy damage cooldown. Visual: small colored circles.
- **D-11: Antenna Beam** — **RayCast2D or long thin Area2D** aimed at nearest enemy, fires every ~2s. Piercing: hits all enemies along the ray. Visual: tall thin ColorRect that flashes briefly. Host-only hit detection.
- **D-12: Horn Shockwave** — **Radial Area2D burst** (full 360°, ~150px radius) centered on player. Fires every ~3s. Visual: brief expanding ring. Host detects hits.
- **D-13: Airbag Shield** — **1 death-prevention charge**, not a timer-based weapon. `airbag_active: bool = true`. Lethal hit → absorb if active, health stays at 1, `airbag_active = false`. Visual: persistent ring while charge active. Re-arm: pick up Airbag CarPart again.
- **D-14:** Spinning Tires damage detection is **host-only** (`is_multiplayer_authority()` guard on damage-apply path).
- **D-15:** Max **6 active weapons** silently enforced by WeaponManager. `add_weapon()` returns `false` if at capacity.
- **D-16:** On player death/game-over, WeaponManager resets: `unlocked_weapons = []`, `weapon_level = {}`, `airbag_active = false`. Spinning Tires nodes hidden/disabled.

### OpenCode's Discretion

- Exact damage values per weapon (starting point: 10–25 damage, tunable)
- Exact cooldown timers (starting points from D-09—D-12 above, tunable)
- CarPartPickup visual color/shape per weapon type
- Antenna Beam implementation choice: RayCast2D vs. long Area2D

### Deferred Ideas (OUT OF SCOPE)

- **Weapon Upgrades (Level 2 and 3):** Level data model exists but actual stat improvements are implemented in Phase 6.
- **Per-weapon visual differentiation:** CarPart pickup shapes are placeholders. Visual polish deferred.
- **Weapon combo interactions:** No cross-weapon interactions in Phase 4.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WEAP-01 | Enemies occasionally drop a car-part item pickup on death | D-03: 25% chance in `_on_enemy_died`; parallel branch to existing XP orb drop |
| WEAP-02 | Player walking over item pickup collects it; triggers weapon unlock | D-05: Area2D body_entered → _collected guard → host despawn + weapon_unlocked RPC |
| WEAP-03 | Collecting new car-part unlocks corresponding weapon (added to WeaponManager) | D-06/D-07: WeaponManager.add_weapon() called by host after validating pickup |
| WEAP-04 | Active weapons fire automatically on independent cooldown timers | D-06: per-weapon Timer nodes in WeaponManager; authority-guarded fire() |
| WEAP-05 | Player can hold up to 6 active weapons simultaneously | D-15: WeaponManager enforces cap silently |
| WEAP-06a | Exhaust Flames — fire cone behind the player | D-09: periodic cone Area2D, 60° arc, 120px radius, 1.5s cooldown |
| WEAP-06b | Spinning Tires — orbiting projectiles | D-10: 3 Area2D orbit children, always active, host-only damage detection |
| WEAP-06c | Antenna Beam — long-range piercing laser | D-11: RayCast2D or long thin Area2D, 2s cooldown, piercing |
| WEAP-06d | Horn Shockwave — close-range area burst | D-12: 360° radial Area2D, 150px radius, 3s cooldown |
| WEAP-06e | Airbag Shield — damage-absorbing shell | D-13: death-prevention charge, not timer-based, absorbed lethal hit |
| WEAP-07 | Each weapon can be upgraded to level 3 (data model only in Phase 4) | D-01/D-02: unlock at Level 1; weapon_level dict in place for Phase 6 |
| WEAP-08 | All active weapons and levels reset on death | D-16: WeaponManager.reset() called from game-over/death path |

</phase_requirements>

---

## Summary

Phase 4 adds the Vampire Survivors weapon loop on top of Phase 3's combat foundation. The core work is threefold: (1) refactor the existing `_try_fire()` in Player.gd into a new WeaponManager child node, (2) implement 5 car-themed weapons as Area2D/RayCast2D shapes with independent cooldown Timers, and (3) wire a new CarPartPickup scene through the existing PickupSpawner so that enemy drops unlock weapons for the collecting player.

The existing codebase provides all the scaffolding this phase needs. The PickupSpawner in Game.gd already uses a custom `spawn_function` pattern — CarPartPickup registers alongside XpOrb in the same spawner. The XpOrb's `_collected` guard (bool + host-only validation) is the exact pattern CarPartPickup must replicate to prevent double-collect. The existing `request_fire` RPC in Game.gd extends naturally to cover all 5 new weapon fire requests. Every new scene (CarPartPickup, WeaponManager, 5 weapon Area2D scenes) must be pre-registered before any multiplayer testing.

The most complex weapon is Spinning Tires: its 3 orbit Area2D nodes live as children of Player.tscn (visible on all peers via Player sync), but damage detection is host-only. The simpler weapons (Exhaust, Beam, Shockwave) are one-shot Area2D overlaps triggered by a Timer. Airbag Shield is not a weapon at all — it's a death-prevention flag that intercepts `receive_damage` before health subtraction.

**Primary recommendation:** Implement in waves — (1) CarPartPickup + PickupSpawner registration, (2) WeaponManager scaffold + ScrewsAndBolts migration, (3) the four timer-based weapons, (4) Airbag Shield, (5) death reset + multiplayer authority hardening. Never test a new weapon without first pre-registering all 5 weapon projectile scenes.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Enemy death → pickup drop | API / Backend (host) | — | Host is already sole writer of `_on_enemy_died`; adds 25% branch |
| CarPartPickup collection validation | API / Backend (host) | Client sends RPC | Same as XpOrb: client detects body_entered, host validates and despawns |
| Weapon unlock state | Each player's own peer | Host confirms via RPC | WeaponManager lives on Player node; host sends `weapon_unlocked` RPC to owning peer |
| Weapon cooldown tick | Each player's own peer | — | Authority-guarded timer inside WeaponManager; only owning peer's WM ticks and calls fire() |
| Projectile spawn (ScrewsAndBolts, Exhaust, Beam, Shockwave) | API / Backend (host) | Client requests via RPC | Same pattern as existing BulletSpawner; owning peer sends request_fire → host spawns |
| Spinning Tires orbit (visual) | All peers | — | Orbit nodes are children of Player.tscn, synced via existing MultiplayerSynchronizer |
| Spinning Tires damage detection | API / Backend (host) | — | `is_multiplayer_authority()` guard on damage-apply path (D-14) |
| Airbag Shield absorption | Each player's own peer | — | `airbag_active` flag checked inside `receive_damage` on owning peer; synced via MultiplayerSynchronizer |
| WeaponManager reset on death | Each player's own peer | Triggered by host RPC | Called from game-over path, same node as the weapon state |

---

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| Godot 4 | 4.6.2-stable | Engine | Project mandate |
| GDScript | built-in | Scripting | All existing code is GDScript |
| Area2D | built-in | Weapon hit detection (cone, orbit, radial, beam) | Cheapest overlap query in Godot 2D; no physics step needed for one-shot checks |
| RayCast2D | built-in | Antenna Beam (alternative to Area2D) | Native piercing line query; simpler than long thin Area2D for pierce-all-enemies |
| Timer (Node) | built-in | Per-weapon fire cooldowns | Decoupled from _process; fires timeout signal regardless of frame rate |
| MultiplayerSpawner | built-in | CarPartPickup and weapon projectile replication | Existing PickupSpawner + BulletSpawner already use this pattern |
| MultiplayerSynchronizer | built-in | Airbag shield flag + orbit node visibility | Player.tscn already has a Synchronizer; add `airbag_active` to replication config |

### Supporting

| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| call_deferred | built-in | Safe spawn inside physics callbacks | Already used in `_on_enemy_died` — must use for CarPartPickup spawn too |
| Dictionary | built-in | Per-enemy damage cooldown tracking (Spinning Tires) | `_tire_hit_times: Dictionary` (enemy node path → last_hit timestamp) |
| ColorRect | built-in | Placeholder visuals for all weapon shapes and pickups | Project constraint: placeholder art only |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Separate weapon scene files | Inline weapon logic in WeaponManager | Scenes are reloadable, inspectable in editor; inline logic becomes a 500-line god-script |
| Timer node per weapon | `_fire_cooldown -= delta` in _physics_process | Timer approach avoids per-frame arithmetic and decouples from frame rate; consistent with existing ScrewsAndBolts pattern |
| Long thin Area2D for Antenna Beam | RayCast2D | RayCast2D pierces all bodies in one call; Area2D requires overlap_get_contacts(); either works — choose based on ease |
| RPC per weapon fire | One generic `request_fire` with weapon_id param | Generic RPC is simpler; weapon_id string routes to correct spawn logic on host |

**No installation needed** — all tooling is built into Godot 4.6.2-stable.

---

## Architecture Patterns

### System Architecture Diagram

```
[Owning Player Peer — e.g., Client Peer 2]
  Player._physics_process()
    └── $WeaponManager.tick(delta)         [authority guard inside]
          ├── ScrewsAndBolts.Timer.timeout → _try_fire() → request_fire.rpc_id(1, ...)
          ├── ExhaustFlames.Timer.timeout  → _try_fire() → request_fire.rpc_id(1, ...)
          ├── AntennaBeam.Timer.timeout    → _try_fire() → request_fire.rpc_id(1, ...)
          ├── HornShockwave.Timer.timeout  → _try_fire() → request_fire.rpc_id(1, ...)
          └── SpinningTires               → orbit update (visual only on clients)

[Host — Peer 1]
  Game.request_fire(weapon_id, pos, dir, peer_id)
    └── BulletSpawner.spawn() or WeaponProjectileSpawner.spawn()
         └── [Bullet/WeaponEffect replicated to all peers via MultiplayerSpawner]

  SpinningTires._physics_process() [host only via is_multiplayer_authority()]
    └── for tire in orbit_nodes:
          for enemy in overlapping_bodies:
            if cooldown elapsed → enemy.take_damage()

  Enemy.take_damage() → died.emit(pos)
    └── Game._on_enemy_died(pos)
          ├── (always) PickupSpawner.spawn.call_deferred({"pos": pos, "type": "xp_orb"})
          └── (25%) PickupSpawner.spawn.call_deferred({"pos": pos, "type": random_car_part})

[All Peers]
  CarPartPickup.body_entered(player)
    └── if body.peer_id == my peer_id
          → _request_collect.rpc_id(1, pickup_name, peer_id)

  [Host validates _collected flag]
    └── queue_free() [propagates via PickupSpawner]
    └── weapon_unlocked.rpc_id(player_peer, weapon_id)

[Owning Player Peer receives weapon_unlocked]
  Player.receive_weapon_unlock(weapon_id)
    └── $WeaponManager.add_weapon(weapon_id)
          └── if size < 6: append to unlocked_weapons, start Timer
```

### Recommended Project Structure

```
scenes/
├── Player.tscn            # Add WeaponManager child + SpinningTire Area2D children
├── Player.gd              # Remove _try_fire()/_fire_cooldown; add $WeaponManager delegation
├── Game.gd                # Add CarPartPickup drop branch + weapon_unlocked RPC
├── Game.tscn              # Add CarPartPickup to PickupSpawner spawnable list
├── weapons/
│   ├── WeaponManager.gd   # NEW — owns unlocked_weapons, weapon_level, add/reset
│   ├── ScrewsAndBolts.gd  # Migrated from Player._try_fire() — starter weapon
│   ├── ExhaustFlames.gd   # Cone Area2D, 1.5s cooldown
│   ├── SpinningTires.gd   # 3 orbit Area2D nodes, continuous, host-only damage
│   ├── AntennaBeam.gd     # RayCast2D or long Area2D, 2s cooldown, piercing
│   ├── HornShockwave.gd   # 360° Area2D burst, 3s cooldown
│   └── AirbagShield.gd    # Death-prevention charge; passive, not timer-based
├── pickups/
│   ├── XpOrb.tscn/gd      # Unchanged from Phase 3
│   └── CarPartPickup.tscn  # NEW — Area2D, collision_layer=64, mask=2
│       └── CarPartPickup.gd # Replicates XpOrb _collected guard; sends weapon_unlocked RPC
```

### Pattern 1: Host-Authoritative Pickup Collection (reuse from XpOrb.gd)

**What:** Client detects body overlap → sends RPC to host → host validates `_collected` flag → host despawns pickup → host sends weapon_unlocked RPC to owning peer.
**When to use:** Any pickup that must only be collected once.

```gdscript
# CarPartPickup.gd — mirrors XpOrb._collected guard exactly
# Source: verified from scenes/pickups/XpOrb.gd (live codebase)
extends Area2D

@export var weapon_id: String = ""   # set by Game._do_spawn_pickup via data dict
var _collected: bool = false

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if not body.is_in_group("players"):
        return
    # Only the peer who physically stepped on it sends the RPC (W1 prevention)
    if body.peer_id != multiplayer.get_unique_id():
        return
    if multiplayer.is_server():
        _request_collect(name, body.peer_id)
    else:
        _request_collect.rpc_id(1, name, body.peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_collect(_pickup_name: String, collector_peer_id: int) -> void:
    if not multiplayer.is_server():
        return
    if _collected:
        return  # W1: double-collect guard
    _collected = true
    # Send weapon unlock to the collecting player
    var game := get_node_or_null("/root/Game")
    if game and game.has_method("weapon_unlocked"):
        game.weapon_unlocked.rpc_id(collector_peer_id, weapon_id)
    queue_free()   # propagates to all clients via PickupSpawner
```

### Pattern 2: WeaponManager Architecture

**What:** Child Node of Player.tscn — owns the weapon list, weapon_level dict, timers, and all fire delegation.
**When to use:** All weapon unlock/fire/reset operations go through this node.

```gdscript
# WeaponManager.gd
# Source: synthesized from WEAPONS_XP.md + Phase 3 Player.gd fire pattern [VERIFIED: live codebase]
extends Node

const MAX_WEAPONS := 6
const WEAPON_IDS := ["screws_and_bolts", "exhaust_flames", "spinning_tires",
                     "antenna_beam", "horn_shockwave", "airbag_shield"]

var unlocked_weapons: Array[String] = []
var weapon_level: Dictionary = {}   # weapon_id → int (always 1 in Phase 4)
var airbag_active: bool = false

func _ready() -> void:
    # ScrewsAndBolts is always unlocked (migrated from Player._try_fire)
    add_weapon("screws_and_bolts")

func add_weapon(weapon_id: String) -> bool:
    if unlocked_weapons.size() >= MAX_WEAPONS:
        return false    # D-15: silent cap
    if unlocked_weapons.has(weapon_id):
        return false    # D-01: already unlocked — silent ignore
    unlocked_weapons.append(weapon_id)
    weapon_level[weapon_id] = 1
    _activate_weapon_node(weapon_id)
    if weapon_id == "airbag_shield":
        airbag_active = true
    return true

func reset() -> void:
    # D-16: called on death/game-over
    for id in unlocked_weapons:
        _deactivate_weapon_node(id)
    unlocked_weapons = []
    weapon_level = {}
    airbag_active = false
```

### Pattern 3: Authority-Guarded Weapon Fire (W2 prevention)

**What:** Timers run on ALL peers (unavoidable — Timer is a child of Player which every peer has). Only the owning peer's timer triggers `_try_fire()`. Only the host spawns the projectile.
**When to use:** Every weapon that spawns a projectile or fires an effect.

```gdscript
# Inside each weapon's Timer.timeout handler
# Source: Player.gd _try_fire() pattern [VERIFIED: live codebase]
func _on_fire_timer() -> void:
    # W2: Only owning player's peer reaches this (is_multiplayer_authority on Player)
    # WeaponManager is a child of Player — get_parent() == Player
    if not get_parent().is_multiplayer_authority():
        return
    _try_fire()

func _try_fire() -> void:
    var player: Node = get_parent()     # WeaponManager parent is Player
    var game := get_node_or_null("/root/Game")
    if game == null:
        return
    var dir := _compute_fire_direction(player)
    if multiplayer.is_server():
        _spawn_effect_direct(game, player.global_position, dir)
    else:
        game.request_fire.rpc_id(1, weapon_id, player.global_position, dir, player.peer_id)
```

### Pattern 4: Spinning Tires — Continuous Orbit with Per-Enemy Damage Cooldown

**What:** 3 Area2D children of Player orbit continuously (120° apart). Host-only damage; Dictionary tracks last-hit-time per enemy to prevent spam.
**When to use:** Melee-orbit weapons that deal continuous contact damage.

```gdscript
# SpinningTires.gd
# Source: D-10 from 04-CONTEXT.md [VERIFIED: CONTEXT]
extends Node

const ORBIT_RADIUS: float = 50.0
const ORBIT_SPEED: float = 2.0   # radians/sec
const DAMAGE: int = 15
const HIT_COOLDOWN: float = 0.5

var _angle: float = 0.0
var _hit_times: Dictionary = {}   # enemy node path → float (time of last hit)

func _physics_process(delta: float) -> void:
    _angle += ORBIT_SPEED * delta
    var player: Node = get_parent().get_parent()   # WeaponManager → Player
    for i in range(3):
        var angle_offset: float = _angle + (i * TAU / 3.0)
        var tire: Area2D = get_child(i)
        tire.global_position = player.global_position + Vector2(
            cos(angle_offset), sin(angle_offset)
        ) * ORBIT_RADIUS
    # D-14: Host-only damage detection
    if not player.is_multiplayer_authority():
        return
    for i in range(3):
        var tire: Area2D = get_child(i)
        for body in tire.get_overlapping_bodies():
            if not body.is_in_group("enemies"):
                continue
            var key: String = str(body.get_path())
            var last_hit: float = _hit_times.get(key, -INF)
            if Time.get_unix_time_from_system() - last_hit >= HIT_COOLDOWN:
                _hit_times[key] = Time.get_unix_time_from_system()
                body.take_damage(DAMAGE)
```

### Pattern 5: PickupSpawner Data Extension for Typed Pickups

**What:** Existing `_do_spawn_pickup` in Game.gd returns XpOrb unconditionally. Phase 4 extends to support typed spawns.
**When to use:** When `spawn_type` key is added to the data dict.

```gdscript
# Game.gd — extend _do_spawn_pickup [VERIFIED: live codebase at scenes/Game.gd]
const CAR_PART_SCENE := preload("res://scenes/pickups/CarPartPickup.tscn")
const CAR_PART_IDS := ["exhaust_flames", "spinning_tires",
                       "antenna_beam", "horn_shockwave", "airbag_shield"]

func _on_enemy_died(pos: Vector2) -> void:
    if not multiplayer.is_server():
        return
    # Always drop XP orb
    $PickupSpawner.spawn.call_deferred({"type": "xp_orb", "pos": pos})
    # D-03: 25% random chance for a car-part pickup
    if randf() < 0.25:
        var part_id: String = CAR_PART_IDS[randi() % CAR_PART_IDS.size()]
        $PickupSpawner.spawn.call_deferred({"type": "car_part", "pos": pos, "weapon_id": part_id})

func _do_spawn_pickup(data: Dictionary) -> Node:
    match data.get("type", "xp_orb"):
        "xp_orb":
            var orb := ORB_SCENE.instantiate()
            orb.position = data["pos"]
            orb.name = "XpOrb_%d" % (randi() % 9999)
            return orb
        "car_part":
            var pickup := CAR_PART_SCENE.instantiate()
            pickup.position = data["pos"]
            pickup.weapon_id = data["weapon_id"]
            pickup.name = "CarPart_%d" % (randi() % 9999)
            return pickup
    return null
```

### Pattern 6: Airbag Shield — Intercept receive_damage

**What:** `receive_damage` on Player.gd intercepts lethal hits when `airbag_active` is true.
**When to use:** Death-prevention mechanic; passive, not timer-based.

```gdscript
# Player.gd receive_damage — insert airbag check [VERIFIED: live codebase]
@rpc("any_peer", "call_remote", "reliable")
func receive_damage(amount: int) -> void:
    var new_hp: int = health - amount
    if new_hp <= 0 and $WeaponManager.airbag_active:
        # D-13: Absorb lethal hit; health stays at 1
        health = 1
        $WeaponManager.airbag_active = false
        # WeaponManager will hide the airbag ring visual
        return
    health -= amount
    if health <= 0:
        health = 0
        _enter_downed()
```

### Anti-Patterns to Avoid

- **Weapon timers calling fire() on ALL peers (W2):** Timer.timeout fires on every peer that has the node. MUST guard with `get_parent().is_multiplayer_authority()` BEFORE doing any spawn work. Clients will see bullets appear (via MultiplayerSpawner) but must never spawn them themselves.
- **CarPartPickup calling queue_free() on client (W1):** Only host calls `queue_free()`. Client calls `_request_collect.rpc_id(1, ...)`. The `_collected` bool on the host instance prevents double-collect.
- **Forgetting to pre-register CarPartPickup in PickupSpawner (P7):** PickupSpawner's `add_spawnable_scene()` list must include CarPartPickup.tscn BEFORE any enemy can die and drop one. Otherwise clients never see the pickup appear.
- **Weapon nodes added to WeaponManager without a call_deferred on physics frame:** If `add_child()` is called from inside a physics callback chain, it can trigger "Can't change state while flushing queries". Use `call_deferred("add_child", node)` when adding weapon nodes from a pickup collection path.
- **Applying airbag absorption on the host-side receive_damage, not the owning-peer side:** `receive_damage` is `@rpc("any_peer", "call_remote", "reliable")` — it runs on the OWNING peer. The airbag check is correct there. Do NOT add a separate host-side intercept.
- **Syncing weapon loadout via MultiplayerSynchronizer:** The loadout is a dynamic array; add a `weapon_unlocked` RPC instead. Each player owns their own WeaponManager and updates it locally after host confirmation.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Area2D cone detection | Custom angular intersection math | Area2D + `get_overlapping_bodies()` + manual angle filter | Godot's overlap query handles broad phase; you only need `angle_to()` for the 60° filter |
| Piercing beam | Complex ray-loop with enemy list | RayCast2D with `hit_from_inside = true` and `exclude_parent = true` | One call returns all bodies in order along ray |
| Pickup double-collect prevention | Timestamped Set of collected pickup IDs in GameState | `_collected: bool` on the pickup node (XpOrb pattern) | Node is freed after collection — bool lives only as long as needed; no cleanup required |
| Weapon fire rate independent of frame rate | `_fire_cooldown -= delta` in `_physics_process` | Timer node | Timer is decoupled from physics; fires reliably on slow machines and doesn't accumulate drift |
| Orbit position math | Complex recursive chain | Simple `Vector2(cos(angle), sin(angle)) * radius` per frame | One line per tire; no dependency on previous frame position |
| Radial shockwave "expanding ring" visual | AnimationPlayer keyframes | Tween node (scale up + fade out + queue_free) | Per STACK.md: use Tween for HUD flashes and similar ephemeral animations |

**Key insight:** The weapon system is almost entirely data + collision configuration. The hard work (spawn, replicate, authority) is already in the existing codebase patterns. New weapons are mostly "configure Area2D, connect Timer, guard with authority check."

---

## Common Pitfalls

### Pitfall W1: Pickup Double-Collect

**What goes wrong:** Two players step on the same CarPartPickup in the same frame. Both trigger `body_entered`, both call `_request_collect.rpc_id(1, ...)`. Host receives both RPCs; first processes fine, second fires after `queue_free()` is queued but before it executes — so `_collected` is already true.
**Why it happens:** `queue_free()` is deferred; the node and its `_collected = true` remain alive for the current frame. Second RPC arrives in the same processing batch.
**How to avoid:** The `_collected: bool` guard (copied from XpOrb.gd) handles this correctly — second RPC sees `_collected = true` and returns immediately. Do NOT skip this flag.
**Warning signs:** Player receives two different weapons from one pickup node.

### Pitfall W2: Weapon Timers Fire on Clients

**What goes wrong:** Timer.timeout fires on every peer. Without authority guard, every client runs `_try_fire()`, which either calls `spawn()` directly (crashing because PickupSpawner is host-only) or sends duplicate RPCs to host.
**Why it happens:** Timer nodes are children of WeaponManager, which is a child of Player.tscn — ALL peers instantiate Player.tscn, including the non-owning peers.
**How to avoid:** Every Timer.timeout handler MUST start with `if not get_parent().get_parent().is_multiplayer_authority(): return` (WeaponManager's parent is Player, and `is_multiplayer_authority()` is set per Player peer_id). Use `get_parent().is_multiplayer_authority()` from the WeaponManager level.
**Warning signs:** Bullets appear to duplicate; two bullets fired where only one should be.

### Pitfall P7: Spawnable List Gaps

**What goes wrong:** CarPartPickup scene not added to PickupSpawner's spawnable list. Host spawns it; clients receive the spawn RPC but have no matching scene → pickup is invisible on all client screens.
**Why it happens:** Spawnable scenes must be pre-registered in the editor (via `add_spawnable_scene()` in `_ready()` or directly in the tscn). No runtime error is produced.
**How to avoid:** Add `$PickupSpawner.add_spawnable_scene("res://scenes/pickups/CarPartPickup.tscn")` in Game.gd `_ready()` before testing. Same rule applies to any new weapon projectile scenes.
**Warning signs:** Pickups visible on host but absent on all client screens.

### Pitfall P8: Weapon Loadout Not Flowing Through Host

**What goes wrong:** Client-side WeaponManager directly adds weapon on `body_entered` without going through host. Two clients picking up the same part get it independently, and their loadouts can diverge.
**How to avoid:** D-05 specifies: `_request_collect.rpc_id(1, ...)` → host validates → host calls `weapon_unlocked.rpc_id(collector_peer_id, weapon_id)` → owning peer's WeaponManager.add_weapon(). Never add weapons on the client side without host confirmation.

### Pitfall: Spinning Tires orbit_area get_overlapping_bodies() empty on clients

**What goes wrong:** `get_overlapping_bodies()` only returns results when the Area2D's physics is actually being tracked. On clients where physics_process is guarded, the Area2D may still be monitoring — but because collision detection is host-only, the damage check must also be host-only.
**How to avoid:** D-14 already addresses this: `is_multiplayer_authority()` guard in the damage application path. The orbit visual (position update) runs on all peers; the damage check runs only on host.

### Pitfall: call_deferred missing on pickup spawn from physics callback

**What goes wrong:** `_on_enemy_died` is called from Enemy.gd's `take_damage` → which is called from Bullet.gd's `_on_area_entered` — all inside a physics callback. Calling `spawn()` directly triggers "Can't change state while flushing queries."
**How to avoid:** The existing code already uses `$PickupSpawner.spawn.call_deferred(...)`. The new CarPartPickup spawn call must use the same `call_deferred` wrapper.
**Warning signs:** "Can't change state while flushing queries" error in output.

### Pitfall: Antenna Beam firing toward NULL (no enemies alive)

**What goes wrong:** If all enemies are dead, `_find_nearest_enemy()` returns null. Trying to compute direction to null → crash.
**How to avoid:** All 4 timer-based weapons that target "nearest enemy" must guard: `if nearest == null: return` before computing direction. ScrewsAndBolts already has this guard.

### Pitfall: WeaponManager add_child() during body_entered callback

**What goes wrong:** When `weapon_unlocked` RPC triggers `add_weapon()` which calls `add_child(weapon_node)`, if this lands in a physics frame, it may trigger physics state mutation errors.
**How to avoid:** Use `call_deferred("add_child", weapon_node)` inside `add_weapon()` when adding weapon nodes to the scene tree.

---

## Code Examples

### Collision Layer Configuration (from live codebase)

```
# Verified from project.godot [VERIFIED: live codebase]
Layer 1 = "world"           bitmask = 1
Layer 2 = "players"         bitmask = 2
Layer 3 = "enemies"         bitmask = 4
Layer 4 = "player_hurtbox"  bitmask = 8
Layer 5 = "enemy_hurtbox"   bitmask = 16
Layer 6 = "bullets"         bitmask = 32
Layer 7 = "pickups"         bitmask = 64
```

CarPartPickup collision config (matches XpOrb.tscn):
- `collision_layer = 64` (layer 7 "pickups")
- `collision_mask = 2`  (layer 2 "players" — only detects player bodies)

WeaponEffect Area2D nodes (Exhaust, Shockwave, etc.):
- `collision_layer = 0` (invisible to other detection)
- `collision_mask = 4`  (layer 3 "enemies" — only detects enemy CharacterBody2D)
- Note: Enemy's `HurtboxArea` is on layer 5 (mask 34 = bullets 32 + players 2). Weapon effects that target enemies directly should use the Enemy CharacterBody2D body (layer 3), NOT the HurtboxArea.

Spinning Tires Area2D:
- `collision_layer = 0`
- `collision_mask = 4`  (detect enemy CharacterBody2D for `get_overlapping_bodies()`)

### PickupSpawner Pre-Registration Pattern (from Game.gd)

```gdscript
# Game.gd _ready() — add CarPartPickup to PickupSpawner's spawnable list
# Source: P7 pattern from PITFALLS.md [VERIFIED: live codebase context]
func _ready() -> void:
    $MultiplayerSpawner.spawn_function = _do_spawn
    $EnemySpawner.spawn_function  = _do_spawn_enemy
    $BulletSpawner.spawn_function = _do_spawn_bullet
    $PickupSpawner.spawn_function = _do_spawn_pickup
    # P7: Pre-register ALL scenes PickupSpawner may spawn
    $PickupSpawner.add_spawnable_scene("res://scenes/pickups/XpOrb.tscn")
    $PickupSpawner.add_spawnable_scene("res://scenes/pickups/CarPartPickup.tscn")
    # NOTE: add_spawnable_scene is additive; registering XpOrb twice is harmless
    # but prefer registering once from scratch for clarity
```

### weapon_unlocked RPC in Game.gd

```gdscript
# Game.gd — host sends weapon unlock to collecting player
# Source: D-05 from 04-CONTEXT.md; mirrors receive_damage RPC pattern [VERIFIED: CONTEXT]
@rpc("authority", "call_remote", "reliable")
func weapon_unlocked(weapon_id: String) -> void:
    # Runs on the collecting player's peer
    var my_player: Node = null
    for p in get_tree().get_nodes_in_group("players"):
        if p.peer_id == multiplayer.get_unique_id():
            my_player = p
            break
    if my_player and my_player.has_node("WeaponManager"):
        my_player.get_node("WeaponManager").add_weapon(weapon_id)
```

### GameState Integration for WeaponManager Reset

```gdscript
# GameState.gd _broadcast_game_over — add weapon reset
# Source: autoloads/GameState.gd (live codebase) [VERIFIED: live codebase]
@rpc("authority", "call_local", "reliable")
func _broadcast_game_over() -> void:
    # D-16: Reset all weapon managers before scene change
    for p in get_tree().get_nodes_in_group("players"):
        if p.has_node("WeaponManager"):
            p.get_node("WeaponManager").reset()
    get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-bullet MultiplayerSynchronizer | MultiplayerSpawner spawn + local simulation | Phase 3 (existing) | Bullets already work this way; weapon effects follow same pattern |
| Global XP drop on enemy death | Per-enemy die signal wired in `_do_spawn_enemy` | Phase 3 (existing) | CarPartPickup drop slots in the same `_on_enemy_died` callback |
| Hardcoded FIRE_INTERVAL in Player.gd | WeaponManager child with Timer nodes | Phase 4 (this phase) | Enables per-weapon independent cooldowns |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `get_overlapping_bodies()` on Area2D works correctly on host for Spinning Tires damage detection even when the tire's global_position is updated each frame | Weapon behaviors D-10 | If Godot requires a physics frame settling time after moving an Area2D, the overlap list may be stale by one frame. Mitigation: use `force_shapecast_update()` if needed, or accept one-frame lag (cosmetic only). |
| A2 | Timers added as children of weapon nodes (themselves children of WeaponManager under Player) run on all peers without explicit `set_process(false)` on non-authority peers | Pattern 3 | If timers are authority-gated somehow, fire() would never trigger on clients. The authority guard inside the timeout handler handles this: timers fire on all peers, logic only runs on owning peer. |

**All other claims verified from live codebase or prior phase research documents.**

---

## Open Questions (RESOLVED)

1. **Should `weapon_unlocked` RPC be on Game.gd or on Player.gd?**
   - What we know: `receive_damage` and `receive_revive` are RPCs on Player.gd (host calls `rpc_id(peer_id, ...)` on the Player node). `weapon_unlocked` follows the same pattern.
   - What's unclear: Whether to put it on Game.gd (`@rpc("authority")`) or Player.gd (`@rpc("any_peer", "call_remote")`).
   - Recommendation: Put on Game.gd as `@rpc("authority", "call_remote", "reliable")` called with `rpc_id(collector_peer_id, weapon_id)`. This matches the `_update_revive_bar` RPC calling pattern from Game.gd and avoids adding more `@rpc` methods to Player.gd that change its RPC checksum.

2. **How should Antenna Beam handle the case where it should pierce through walls?**
   - What we know: D-11 says "hits all enemies along the ray." RayCast2D hits the FIRST obstacle in its collision mask. If walls are in the mask, the beam stops at the first wall.
   - What's unclear: Should the beam stop at walls (thematic: beam hits wall and stops) or pass through walls?
   - Recommendation: Set RayCast2D `collision_mask = 4` (enemies only, not walls). The beam pierces infinitely. Or use a long thin Area2D with `collision_mask = 4` to collect all enemies in range regardless of wall position. Either is valid — decide at implementation time based on feel.

3. **Does `is_multiplayer_authority()` on WeaponManager return the Player's authority?**
   - What we know: `is_multiplayer_authority()` on a child node returns true if the node's owner (or ancestor with authority set) matches the local peer. Since Player has `set_multiplayer_authority(peer_id)` in `_ready()`, all children inherit this.
   - Recommendation: Call `get_parent().is_multiplayer_authority()` from WeaponManager to be explicit, matching the existing Player.gd guard pattern. [ASSUMED — standard Godot 4 authority inheritance; would need confirmation in a test run]

---

## Environment Availability

*Step 2.6 SKIPPED — this is a pure Godot GDScript code change with no external tools, services, or runtimes beyond the project's own engine.*

---

## Validation Architecture

> `workflow.nyquist_validation` is explicitly `false` in `.planning/config.json`. Section skipped.

---

## Security Domain

> This phase is a local-only multiplayer game with no internet exposure, no user accounts, no stored credentials, and no web surface. ASVS categories do not apply. Standard Godot 4 host-authoritative RPC validation (authority guards, `_collected` flag) covers all trust boundary concerns for LAN multiplayer.

---

## Sources

### Primary (HIGH confidence)
- `scenes/Player.gd` (live codebase) — `_try_fire`, `FIRE_INTERVAL`, authority guard pattern, `receive_damage` RPC
- `scenes/Game.gd` (live codebase) — PickupSpawner, `_on_enemy_died`, `request_fire` RPC, `call_deferred` spawn pattern
- `scenes/pickups/XpOrb.gd` (live codebase) — `_collected` guard pattern
- `autoloads/GameState.gd` (live codebase) — `_broadcast_game_over` RPC, game-over hook
- `scenes/enemies/Enemy.gd` (live codebase) — `take_damage`, `died` signal, contact damage pattern
- `scenes/projectiles/Bullet.gd` (live codebase) — `is_multiplayer_authority()` guard on despawn, local simulation
- `scenes/Player.tscn` (live codebase) — SceneReplicationConfig, collision layers
- `scenes/pickups/XpOrb.tscn` (live codebase) — collision_layer=64, collision_mask=2
- `scenes/enemies/Enemy.tscn` (live codebase) — HurtboxArea layer 16, mask 34
- `project.godot` (live codebase) — collision layer names confirmed
- `.planning/phases/04-weapons-and-item-pickups/04-CONTEXT.md` — all D-xx locked decisions
- `.planning/research/WEAPONS_XP.md` — WeaponManager architecture patterns
- `.planning/research/PITFALLS.md` — W1/W2/P7/P8 pitfall definitions
- `.planning/research/ARCHITECTURE.md` — host-authoritative split table
- `.planning/research/STACK.md` — Godot 4.6.2-stable stack, collision layer design

### Secondary (MEDIUM confidence)
- `.planning/phases/03-room-1-enemy-ai-combat-core/03-CONTEXT.md` — D-09, D-14, D-15, D-16 authority guard patterns from Phase 3

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tooling is Godot 4 built-in; verified against live codebase
- Architecture patterns: HIGH — all patterns derived from existing working code in the repo
- Pitfalls: HIGH — W1/W2/P7/P8 are defined in `.planning/research/PITFALLS.md` + verified live patterns
- Weapon behaviors: HIGH — all 5 weapon behaviors locked in 04-CONTEXT.md decisions

**Research date:** 2026-05-31
**Valid until:** 2026-07-01 (Godot 4.6.x is stable; project constraints are locked)
