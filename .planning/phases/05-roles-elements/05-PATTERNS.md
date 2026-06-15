# Phase 5: Roles & Elements - Pattern Map

**Mapped:** 2026-06-15
**Files analyzed:** 8 new/modified files
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scenes/Player.gd` | controller | request-response + event-driven | `scenes/Player.gd` (self — additive) | exact |
| `scenes/enemies/Enemy.gd` | controller | event-driven | `scenes/enemies/Enemy.gd` (self — additive) | exact |
| `scenes/Game.gd` | service | CRUD + event-driven | `scenes/Game.gd` (self — additive) | exact |
| `scenes/projectiles/Bullet.gd` | controller | request-response | `scenes/projectiles/Bullet.gd` (self — additive) | exact |
| `scenes/roles/HealDrone.gd` | service | event-driven | `scenes/weapons/HornShockwave.gd` | role-match |
| `scenes/roles/HealDrone.tscn` | config | — | `scenes/pickups/XpOrb.tscn` (spawnable) | role-match |
| `scenes/elements/IceTrailZone.gd` | utility | event-driven | `scenes/weapons/HornShockwave.gd` (Area2D zone) | partial |
| `scenes/elements/IceTrailZone.tscn` | config | — | `scenes/pickups/XpOrb.tscn` (spawnable) | partial |
| `project.godot` | config | — | `project.godot` (self — additive) | exact |

---

## Pattern Assignments

### `scenes/Player.gd` (controller — additive extension)

**Analog:** `scenes/Player.gd` (self) — all changes are pure additions to existing structure.

**Current const declarations to convert to var** (lines 9–10):
```gdscript
# BEFORE (current):
const SPEED: float = 200.0
const MAX_HP: int = 100

# AFTER (required — role stats cannot mutate const):
var SPEED: float = 200.0
var MAX_HP: int = 100
```

**New variables to add after existing `var health` block** (after line 19):
```gdscript
var evolution_stage: int = 1        # D-04: Phase 6 sets via RPC when XP threshold reached
var element: String = ""            # D-03: "fire" | "ice" | "earth" | ""
var shield_active: bool = false     # D-08/D-09: Tank shield active flag (add to MultiplayerSynchronizer)
var dash_invincible: bool = false   # D-11: Speedster invincibility frames flag
var _ability_cooldown: float = 0.0  # D-06: single ability cooldown timer
var _dash_window_timer: float = 0.0 # D-12: Speedster double-dash window
var _ice_trail_timer: float = 0.0   # D-18: Ice Trail spawn interval
var _fire_burst_timer: float = 0.0  # D-17: Fire Burst auto-fire interval
var _earth_heal_timer: float = 0.0  # D-19: Earth Team Heal tick interval
var _earth_shockwave_timer: float = 0.0  # D-19: Earth Shockwave interval
var _engineer_passive_timer: float = 0.0 # D-13: Engineer passive heal tick interval
```

**Imports/preloads pattern** — none needed (project has no import system; uses `get_node_or_null`).

**`_ready()` extension pattern** (insert after line 28, after existing RoleLabel block):
```gdscript
# Copy from existing Player.gd _ready() structure (lines 21-28), then add:
func _ready() -> void:
    set_multiplayer_authority(peer_id)
    add_to_group("players")
    if has_node("RoleLabel"):
        $RoleLabel.text = role_label
    # Phase 5: Role stats and element assignment
    _apply_role_stats()
    element = Lobby.players.get(peer_id, {}).get("element", "")
    # Phase 5: Initialise timers
    _fire_burst_timer = 4.0   # start at full interval so burst doesn't fire immediately
    _earth_shockwave_timer = 8.0
    _earth_heal_timer = 1.0
    _engineer_passive_timer = 5.0

func _apply_role_stats() -> void:
    match role_label:
        "Tank":
            MAX_HP = 150
            health = 150
        "Speedster":
            SPEED = 280
        "Engineer":
            pass  # HP and SPEED stay at default; passive wired in _tick_element
```

**`_physics_process` extension pattern** (model: current lines 40-56):
```gdscript
func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return
    if is_downed:
        velocity = Vector2.ZERO
        move_and_slide()
        return
    var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    velocity = dir * SPEED
    move_and_slide()
    if has_node("WeaponManager"):
        $WeaponManager.tick(delta)
    _tick_ability(delta)      # Phase 5: role ability cooldown + Space input
    _tick_element(delta)      # Phase 5: passive element timers and Ice Trail
    _check_revive(delta)

func _tick_ability(delta: float) -> void:
    if _ability_cooldown > 0.0:
        _ability_cooldown -= delta
    if _dash_window_timer > 0.0:
        _dash_window_timer -= delta
    if Input.is_action_just_pressed("role_ability"):
        if _ability_cooldown <= 0.0:
            _use_role_ability()
        elif role_label == "Speedster" and _dash_window_timer > 0.0:
            _use_second_dash()

func _use_role_ability() -> void:
    if evolution_stage >= 2:
        _use_stage2_ability()
    else:
        _use_stage1_ability()
```

**`receive_damage` Tank shield intercept** (insert before health decrement at current line 99, after airbag check):
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func receive_damage(amount: int) -> void:
    print("receive_damage called! hp=", health, " -> ", health - amount)
    # Existing airbag check (lines 95-99 — unchanged)
    if health - amount <= 0 and has_node("WeaponManager") and $WeaponManager.airbag_active:
        health = 1
        $WeaponManager.consume_airbag()
        return
    # Phase 5: Tank shield check (insert here)
    if shield_active:
        if evolution_stage >= 2:
            # Stage-2: request host to reflect 50% damage back to last attacker
            # (attacker_path extension needed — see Open Question 3 in RESEARCH.md)
            _request_reflect(amount)
        return  # block all damage regardless of stage
    health -= amount
    if health <= 0:
        health = 0
        _enter_downed()
```

**`receive_heal` RPC — new, mirrors `receive_damage` exactly** (add after `receive_damage`):
```gdscript
# Model: receive_damage pattern (lines 91-104), same rpc signature
@rpc("any_peer", "call_remote", "reliable")
func receive_heal(amount: int) -> void:
    if is_downed:
        return
    health = mini(health + amount, MAX_HP)

# Called on host via — mirrors Enemy.gd lines 91-94:
#   if player.peer_id == multiplayer.get_unique_id():
#       player.receive_heal(amount)
#   else:
#       player.receive_heal.rpc_id(player.peer_id, amount)
```

**`set_evolution_stage` RPC — new, called by Phase 6:**
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func set_evolution_stage(stage: int) -> void:
    evolution_stage = stage
```

**`_check_revive` key binding change** (line 60 — string change only):
```gdscript
# BEFORE:
if not Input.is_action_pressed("revive"):  # currently bound to E (physical_keycode=69)
# AFTER: no code change needed — only project.godot binding changes (see project.godot section)
# The string "revive" stays the same; project.godot maps it to R instead of E.
```

---

### `scenes/enemies/Enemy.gd` (controller — additive extension)

**Analog:** `scenes/enemies/Enemy.gd` (self) — pure additions.

**New variables to add after existing `_players_in_contact` block** (after line 18):
```gdscript
# Phase 5: Status effect fields
var speed_multiplier: float = 1.0   # D-18 Ice Slow: reduces to 0.5 for 2 sec
var _slow_timer: float = 0.0        # counts down slow duration
var _burn_timer: float = 0.0        # counts down burn duration (max 3 sec)
var _burn_tick_timer: float = 0.0   # 1-sec interval for burn damage ticks
```

**`_physics_process` extension** (add at end of existing method, host-only because P6 guard in line 26):
```gdscript
func _physics_process(_delta: float) -> void:
    # ... existing AI code unchanged (lines 33-49) ...
    # Phase 5: Burn DoT and Slow countdown (host-only — P6 guard already applied)
    _tick_status_effects(_delta)

func _tick_status_effects(delta: float) -> void:
    # Ice Slow
    if _slow_timer > 0.0:
        _slow_timer -= delta
        if _slow_timer <= 0.0:
            speed_multiplier = 1.0
            modulate = Color.WHITE  # clear blue tint
    # Burn DoT
    if _burn_timer > 0.0:
        _burn_timer -= delta
        _burn_tick_timer -= delta
        if _burn_tick_timer <= 0.0:
            _burn_tick_timer = 1.0
            take_damage(5)  # 5 damage/sec — host-only, take_damage already guards
        if _burn_timer <= 0.0:
            modulate = Color.WHITE  # clear orange tint
```

**SPEED reference update** (existing `_physics_process` line 44 uses `SPEED` constant; Ice Slow must multiply by `speed_multiplier`):
```gdscript
# BEFORE (line 44):
velocity = (next - global_position).normalized() * SPEED
# AFTER:
velocity = (next - global_position).normalized() * SPEED * speed_multiplier
```

**New status effect methods** (add after `take_damage`):
```gdscript
# Called by Bullet.gd _on_area_entered after host-only proc check
func apply_burn() -> void:
    # Refresh duration — burns do not stack (D-17)
    _burn_timer = 3.0
    _burn_tick_timer = 1.0
    modulate = Color(1.0, 0.6, 0.2)  # orange tint (Claude's discretion)

func apply_slow() -> void:
    speed_multiplier = 0.5
    _slow_timer = 2.0
    modulate = Color(0.5, 0.7, 1.0)  # blue tint (Claude's discretion)
```

---

### `scenes/Game.gd` (service — additive extension)

**Analog:** `scenes/Game.gd` (self) — follows exact existing spawner and RPC patterns.

**New preloads to add at top** (copy pattern from lines 7-13):
```gdscript
const HEAL_DRONE_SCENE := preload("res://scenes/roles/HealDrone.tscn")
const ICE_TRAIL_SCENE  := preload("res://scenes/elements/IceTrailZone.tscn")
```

**`_ready()` spawner registration** (copy exact PickupSpawner pattern, lines 29-32):
```gdscript
# Phase 5: Add inside _ready() after existing spawner registrations
$DroneSpawner.spawn_function = _do_spawn_drone
$DroneSpawner.add_spawnable_scene("res://scenes/roles/HealDrone.tscn")
$IceTrailSpawner.spawn_function = _do_spawn_ice_trail
$IceTrailSpawner.add_spawnable_scene("res://scenes/elements/IceTrailZone.tscn")
```

**`request_deploy_drone` RPC** (copy exact `request_fire` structure, lines 129-148):
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func request_deploy_drone(requester_peer_id: int) -> void:
    if not multiplayer.is_server():
        return
    # Remove existing drone for this player (max 1 drone — D-14)
    for child in get_children():
        if child.name == "HealDrone_%d" % requester_peer_id:
            child.queue_free()
    var player_node: Node = null
    for p in get_tree().get_nodes_in_group("players"):
        if p.peer_id == requester_peer_id:
            player_node = p
            break
    if player_node == null or player_node.is_downed:
        return
    $DroneSpawner.spawn({
        "pos": player_node.global_position,
        "peer_id": requester_peer_id,
        "stage": player_node.evolution_stage
    })

func _do_spawn_drone(data: Dictionary) -> Node:
    var drone := HEAL_DRONE_SCENE.instantiate()
    drone.position = data["pos"]
    drone.owning_peer = data["peer_id"]
    drone.stage = data.get("stage", 1)
    drone.name = "HealDrone_%d" % data["peer_id"]
    return drone
```

**`request_ice_trail` RPC + spawn** (copy `call_deferred` pattern from line 96):
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func request_ice_trail(pos: Vector2) -> void:
    if not multiplayer.is_server():
        return
    # call_deferred required — same reason as PickupSpawner line 96
    $IceTrailSpawner.spawn.call_deferred({"pos": pos})

func _do_spawn_ice_trail(data: Dictionary) -> Node:
    var zone := ICE_TRAIL_SCENE.instantiate()
    zone.position = data["pos"]
    zone.name = "IceTrail_%d" % (randi() % 99999)
    return zone
```

**Earth passive timer and Shockwave** (host-only `_process` or explicit Timer nodes — follows HornShockwave timer-in-node pattern):
```gdscript
# In Game.gd _process(delta) or via Timer signal connected in _ready():
# Earth element timers tick per player with element == "earth"
# Pattern: same loop structure as _find_player_by_peer_id used in attempt_revive
func _tick_earth_effects(delta: float) -> void:
    # Called only on host — wrap with: if not multiplayer.is_server(): return
    for p in get_tree().get_nodes_in_group("players"):
        if not p.is_in_group("players") or p.element != "earth" or p.is_downed:
            continue
        # Earth heal (+2/sec to ALL players — D-19)
        # Earth shockwave (every 8 sec around Earth player — D-19)
        # Pattern for calling receive_heal — exact Enemy.gd lines 91-94 mirror:
        for target in get_tree().get_nodes_in_group("players"):
            if target.peer_id == multiplayer.get_unique_id():
                target.receive_heal(2)
            else:
                target.receive_heal.rpc_id(target.peer_id, 2)
        if multiplayer.is_server():
            GameEvents.emit_hud("seat_massage")
```

**Earth Shockwave visual** (copy exact HornShockwave._show_visual pattern, lines 63-81):
```gdscript
# Earth shockwave visual — clone HornShockwave._show_visual with ~120px radius
# Color: Color(0.4, 0.8, 0.2, 0.8) (green/earth tone — Claude's discretion)
@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_earth_shockwave(pos: Vector2) -> void:
    const RADIUS: float = 120.0
    var ring := ColorRect.new()
    ring.color = Color(0.4, 0.8, 0.2, 0.8)
    ring.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
    ring.pivot_offset = Vector2(RADIUS, RADIUS)
    ring.position = pos - Vector2(RADIUS, RADIUS)
    ring.scale = Vector2(0.1, 0.1)
    add_child(ring)
    var tween := ring.create_tween()
    tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.35)
    tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
    tween.tween_callback(ring.queue_free)
```

---

### `scenes/projectiles/Bullet.gd` (controller — additive extension)

**Analog:** `scenes/projectiles/Bullet.gd` (self) — element proc inserted inside existing `_on_area_entered`.

**`_on_area_entered` extension** (after `enemy.take_damage(BULLET_DAMAGE)` on current line 53, before `queue_free()`):
```gdscript
func _on_area_entered(area: Node) -> void:
    # Existing guard (line 47-50 — unchanged)
    if not is_multiplayer_authority():
        return
    var enemy := area.get_parent()
    if not enemy.is_in_group("enemies"):
        return
    # Existing damage (line 52-53 — unchanged)
    if enemy.has_method("take_damage"):
        enemy.take_damage(BULLET_DAMAGE)
    # Phase 5: Element proc — host-only (already inside authority guard above)
    var owner_elem: String = Lobby.players.get(owner_peer_id, {}).get("element", "")
    if owner_elem != "":
        match owner_elem:
            "fire":
                if randf() < 0.25:
                    if enemy.has_method("apply_burn"):
                        enemy.apply_burn()
                    if multiplayer.is_server():
                        GameEvents.emit_hud("engine")
            "ice":
                if randf() < 0.25:
                    if enemy.has_method("apply_slow"):
                        enemy.apply_slow()
                    if multiplayer.is_server():
                        GameEvents.emit_hud("ac")
    queue_free()
```

**Note on Fire Burst projectiles** — Fire Burst (ELEM-02) spawns via existing `request_fire` / BulletSpawner path in Game.gd. After spawn, host sets `modulate = Color(1.0, 0.5, 0.0)` on the bullet node AND sets the bullet's `_force_burn: bool = true` so it procs burn at 100% (bypassing 25% check). This requires one extra `bool` export on Bullet.gd.

---

### `scenes/roles/HealDrone.gd` (service — new file)

**Analog:** `scenes/weapons/HornShockwave.gd` — timer-driven Area2D effect, host-authoritative, visual ring broadcast via RPC.

**Pattern to copy from HornShockwave.gd:**

```gdscript
# Structure (mirrors HornShockwave.gd layout exactly):
extends Node2D
## HealDrone — Engineer deployable heal zone. Spawned by Game.gd DroneSpawner.
## D-14/D-15: Stage-1 stays fixed; Stage-2 follows Engineer.
## Host authority: all logic runs under is_multiplayer_authority() (host owns spawned nodes by default).

@export var owning_peer: int = 0
@export var stage: int = 1

const PULSE_INTERVAL: float = 3.0
# Stage-1 stats
const PULSE_HEAL_S1: int = 15
const PULSE_RADIUS_S1: float = 150.0
# Stage-2 stats
const PULSE_HEAL_S2: int = 25
const PULSE_RADIUS_S2: float = 200.0

var _pulse_timer: Timer = null
var _area: Area2D = null

func _ready() -> void:
    # Drone authority stays with host (default) — see Pitfall 2 in RESEARCH.md
    # DO NOT call set_multiplayer_authority(owning_peer)
    _setup_area()
    _setup_timer()
    _draw_visual()  # simple ColorRect circle placeholder

func _physics_process(_delta: float) -> void:
    # Stage-2: follow Engineer position (host-only)
    if not is_multiplayer_authority():
        return
    if stage < 2:
        return
    for p in get_tree().get_nodes_in_group("players"):
        if p.peer_id == owning_peer:
            global_position = p.global_position
            break
```

**Timer pattern** (copy from HornShockwave._setup_timer, lines 41-47):
```gdscript
func _setup_timer() -> void:
    _pulse_timer = Timer.new()
    _pulse_timer.wait_time = PULSE_INTERVAL
    _pulse_timer.autostart = true
    _pulse_timer.one_shot = false
    _pulse_timer.timeout.connect(_on_pulse)
    add_child(_pulse_timer)

func _on_pulse() -> void:
    if not is_multiplayer_authority():
        return
    var radius := PULSE_RADIUS_S2 if stage >= 2 else PULSE_RADIUS_S1
    var heal   := PULSE_HEAL_S2  if stage >= 2 else PULSE_HEAL_S1
    _area.global_position = global_position
    for p in get_tree().get_nodes_in_group("players"):
        if p.is_downed:
            continue
        if global_position.distance_to(p.global_position) <= radius:
            # receive_heal RPC pattern — exact Enemy.gd lines 91-94 mirror:
            if p.peer_id == multiplayer.get_unique_id():
                p.receive_heal(heal)
            else:
                p.receive_heal.rpc_id(p.peer_id, heal)
```

**Area2D setup** (copy HornShockwave._setup_area, lines 27-39):
```gdscript
func _setup_area() -> void:
    _area = Area2D.new()
    _area.name = "DroneArea"
    _area.collision_layer = 0
    _area.collision_mask = 2   # layer 2 "players"
    _area.monitoring = true
    _area.monitorable = false
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = PULSE_RADIUS_S1  # expand dynamically in _on_pulse or keep max
    shape.shape = circle
    _area.add_child(shape)
    add_child(_area)
```

**Visual placeholder** (small green circle — Claude's discretion; copy AirbagShield ColorRect approach):
```gdscript
func _draw_visual() -> void:
    # Small green circle — ColorRect (40×40px, pivot center), distinct from SpinningTires
    var rect := ColorRect.new()
    rect.color = Color(0.2, 0.9, 0.3, 0.9)   # green
    rect.size = Vector2(20.0, 20.0)
    rect.pivot_offset = Vector2(10.0, 10.0)
    rect.position = Vector2(-10.0, -10.0)
    add_child(rect)
```

**Requires MultiplayerSynchronizer on HealDrone.tscn** for position sync when Stage-2 (following). Follow same approach as Player.tscn — sync `global_position` or `position` at 20 Hz. Add in editor when creating HealDrone.tscn.

---

### `scenes/elements/IceTrailZone.gd` (utility — new file)

**Analog:** `scenes/weapons/HornShockwave.gd` (Area2D setup pattern) and AirbagShield (ColorRect visual).

**Complete pattern:**
```gdscript
extends Node2D
## IceTrailZone — frost patch spawned by Ice element player movement.
## D-18: Slows enemies that enter (50% speed, 1.5 sec). Lifetime 2 seconds, then queue_free.
## Host-authoritative: spawned by Game.gd IceTrailSpawner (host-only spawn).
## Clients see zone if IceTrailSpawner replicates it; if host-only, visual skipped.

const SLOW_DURATION: float = 1.5
const LIFETIME: float = 2.0
const ZONE_RADIUS: float = 20.0    # ~40px diameter

var _elapsed: float = 0.0
var _area: Area2D = null

func _ready() -> void:
    _setup_area()
    _draw_visual()

func _setup_area() -> void:
    # Copy HornShockwave._setup_area (lines 27-39) with enemy collision mask
    _area = Area2D.new()
    _area.name = "TrailArea"
    _area.collision_layer = 0
    _area.collision_mask = 4    # layer 3 "enemies"
    _area.monitoring = true
    _area.monitorable = false
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = ZONE_RADIUS
    shape.shape = circle
    _area.add_child(shape)
    _area.body_entered.connect(_on_enemy_entered)
    add_child(_area)

func _physics_process(delta: float) -> void:
    # Host-only lifetime expiry
    if not is_multiplayer_authority():
        return
    _elapsed += delta
    if _elapsed >= LIFETIME:
        queue_free()

func _on_enemy_entered(body: Node) -> void:
    if not is_multiplayer_authority():
        return
    if body.is_in_group("enemies") and body.has_method("apply_slow"):
        body.apply_slow()   # apply_slow sets _slow_timer = 2.0 but zone uses 1.5 sec
        # Note: apply_slow() on Enemy.gd sets _slow_timer = 2.0 (from ScrewsAndBolts hit)
        # For trail-triggered slow, override after the call:
        body._slow_timer = SLOW_DURATION

func _draw_visual() -> void:
    # Light-blue ColorRect (40×40px, semi-transparent) — Claude's discretion
    var rect := ColorRect.new()
    rect.color = Color(0.6, 0.85, 1.0, 0.5)   # light blue, semi-transparent
    rect.size = Vector2(40.0, 40.0)
    rect.pivot_offset = Vector2(20.0, 20.0)
    rect.position = Vector2(-20.0, -20.0)
    add_child(rect)
```

---

### `project.godot` (config — additive)

**Analog:** `project.godot` (self — existing InputMap section).

**Verified current state** (from RESEARCH.md):
- `revive` action: `physical_keycode=69` (E key) — change to `physical_keycode=82` (R key)
- `role_ability` action: does not exist — add with `physical_keycode=32` (Space)

**Pattern to follow** (exact format of existing `revive` action in project.godot):
```
[input]
revive={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":82,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
role_ability={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

---

## Shared Patterns

### Host-to-Remote-Peer RPC Routing
**Source:** `scenes/enemies/Enemy.gd` lines 91–94
**Apply to:** `receive_heal` call sites in Game.gd (Engineer passive, Earth heal, Drone pulse), and `receive_damage` in Player.gd shield reflection RPC.
```gdscript
# For every host→player call (damage or heal):
if target.peer_id == multiplayer.get_unique_id():
    target.receive_heal(amount)       # or receive_damage
else:
    target.receive_heal.rpc_id(target.peer_id, amount)
```

### `call_deferred` for Physics-Frame Spawns
**Source:** `scenes/Game.gd` line 96
**Apply to:** `request_ice_trail` in Game.gd, any Engineer drone spawn triggered inside physics callbacks.
```gdscript
$IceTrailSpawner.spawn.call_deferred({"pos": pos})
$DroneSpawner.spawn.call_deferred({...})  # if triggered inside _physics_process
```

### MultiplayerSpawner Registration
**Source:** `scenes/Game.gd` lines 29–32
**Apply to:** DroneSpawner and IceTrailSpawner setup in Game.gd `_ready()`.
```gdscript
$DroneSpawner.spawn_function = _do_spawn_drone
$DroneSpawner.add_spawnable_scene("res://scenes/roles/HealDrone.tscn")
$IceTrailSpawner.spawn_function = _do_spawn_ice_trail
$IceTrailSpawner.add_spawnable_scene("res://scenes/elements/IceTrailZone.tscn")
```

### Multiplayer Authority Guard (host-only logic)
**Source:** `scenes/enemies/Enemy.gd` line 65, `scenes/weapons/HornShockwave.gd` line 51, `scenes/projectiles/Bullet.gd` line 39
**Apply to:** ALL new host-only methods (element proc, drone pulse, shockwave, Earth heal timer, status effect tick on Enemy).
```gdscript
if not is_multiplayer_authority():
    return
# OR for server-only:
if not multiplayer.is_server():
    return
```

### GameEvents HUD Emission
**Source:** `autoloads/GameEvents.gd` line 15
**Apply to:** All element ability activations (Fire Burst, Ice Trail spawn, Earth Shockwave, Burn/Slow proc). Always wrap in `if multiplayer.is_server():`.
```gdscript
if multiplayer.is_server():
    GameEvents.emit_hud("engine")        # Fire
    GameEvents.emit_hud("ac")            # Ice
    GameEvents.emit_hud("seat_massage")  # Earth
```

### Shield / Active-Flag Visual Pattern
**Source:** `scenes/weapons/AirbagShield.gd` lines 14–34
**Apply to:** Tank shield visual ring in Player.gd (or a TankShield.gd child, same as AirbagShield.gd structure).
```gdscript
# Two ColorRects — outer colored ring + transparent inner cutout (hollow ring)
_ring = ColorRect.new()
_ring.color = Color(0.3, 0.6, 1.0, 0.85)  # blue for Tank (not yellow like AirbagShield)
var outer_size: float = (RING_RADIUS + RING_THICKNESS) * 2.0
_ring.size = Vector2(outer_size, outer_size)
_ring.pivot_offset = Vector2(outer_size / 2.0, outer_size / 2.0)
_ring.position = Vector2(-outer_size / 2.0, -outer_size / 2.0)
_ring_inner = ColorRect.new()
_ring_inner.color = Color(0, 0, 0, 0)
var inner_size: float = RING_RADIUS * 2.0
_ring_inner.size = Vector2(inner_size, inner_size)
_ring_inner.position = Vector2(RING_THICKNESS, RING_THICKNESS)
_ring.add_child(_ring_inner)
player.add_child(_ring)
```

### Expanding Ring Visual (Shockwave / Dash)
**Source:** `scenes/weapons/HornShockwave.gd` lines 63–81
**Apply to:** Speedster shockwave landing visual and Earth Shockwave visual.
```gdscript
@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_visual(pos: Vector2) -> void:
    const RADIUS: float = 80.0   # 80px for Speedster; 120px for Earth
    var ring := ColorRect.new()
    ring.color = Color(1.0, 1.0, 0.0, 0.8)   # yellow for Speedster
    ring.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
    ring.pivot_offset = Vector2(RADIUS, RADIUS)
    ring.position = pos - Vector2(RADIUS, RADIUS)
    ring.scale = Vector2(0.1, 0.1)
    get_node_or_null("/root/Game").add_child(ring)
    var tween := ring.create_tween()
    tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.35)
    tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
    tween.tween_callback(ring.queue_free)
```

### WeaponManager Cooldown Tick Pattern
**Source:** `scenes/weapons/WeaponManager.gd` lines 37–48
**Apply to:** `_tick_ability(delta)` in Player.gd for role ability cooldown and all element timers.
```gdscript
# Same delta-decrement pattern as WeaponManager._screws_cooldown:
_ability_cooldown -= delta
if _ability_cooldown <= 0.0:
    _ability_cooldown = COOLDOWN_DURATION  # reset on use, not on tick
```

### Fire Burst / Auto-Projectile Pattern
**Source:** `scenes/weapons/WeaponManager.gd` `_fire_screws()` lines 51–69
**Apply to:** Fire Burst (ELEM-02) in Player.gd `_tick_element()`. Copy `_fire_screws()` structure; add orange modulate on spawned bullet.
```gdscript
func _fire_burst() -> void:
    # Model: WeaponManager._fire_screws() lines 51-69
    var nearest := _find_nearest_enemy_global()  # same _find_nearest_enemy logic
    if nearest == null:
        return
    var dir: Vector2 = (nearest.global_position - global_position).normalized()
    var game := get_node_or_null("/root/Game")
    if game == null:
        return
    # Fire 3-5 projectiles with slight spread
    for i in range(randi_range(3, 5)):
        var spread_dir := dir.rotated(randf_range(-0.3, 0.3))
        if multiplayer.is_server():
            game.get_node("BulletSpawner").spawn({
                "pos": global_position,
                "dir": spread_dir,
                "owner_id": peer_id,
                "fire_burst": true  # flag for 100% burn proc
            })
        else:
            game.request_fire.rpc_id(1, global_position, spread_dir, peer_id)
    if multiplayer.is_server():
        GameEvents.emit_hud("engine")
```

---

## No Analog Found

All files in Phase 5 have close analogs in the existing codebase. No gaps.

---

## Metadata

**Analog search scope:** `scenes/`, `scenes/weapons/`, `scenes/enemies/`, `scenes/projectiles/`, `autoloads/`, root config files
**Files read:** Player.gd, Enemy.gd, Game.gd, WeaponManager.gd, AirbagShield.gd, HornShockwave.gd, Bullet.gd, GameEvents.gd
**Pattern extraction date:** 2026-06-15
