# Phase 3: Room 1, Enemy AI, Combat Core - Pattern Map

**Mapped:** 2026-05-09
**Files analyzed:** 10 (8 new, 2 modified scripts, 2 modified scenes)
**Analogs found:** 9 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scenes/enemies/Enemy.tscn` | scene/config | — | `scenes/Player.tscn` | role-match (CharacterBody2D + MultiplayerSynchronizer) |
| `scenes/enemies/Enemy.gd` | controller | event-driven + CRUD | `scenes/Player.gd` | role-match (CharacterBody2D authority-guard pattern) |
| `scenes/projectiles/Bullet.tscn` | scene/config | — | `scenes/Player.tscn` | partial (Area2D instead of CharacterBody2D) |
| `scenes/projectiles/Bullet.gd` | controller | event-driven | `scenes/Player.gd` | partial (authority guard + physics loop; different node type) |
| `scenes/pickups/XpOrb.tscn` | scene/config | — | `scenes/Player.tscn` | partial (Area2D, no synchronizer) |
| `scenes/pickups/XpOrb.gd` | controller | event-driven | `scenes/Player.gd` | partial (authority-only action from body_entered) |
| `scenes/Game.tscn` | scene/config | — | `scenes/Game.tscn` (self) | exact (extend existing node tree) |
| `scenes/Game.gd` | controller | CRUD + event-driven | `scenes/Game.gd` (self) | exact (extend existing spawn_function pattern) |
| `scenes/Player.gd` | controller | request-response + CRUD | `scenes/Player.gd` (self) | exact (extend existing authority-guard pattern) |
| `autoloads/GameState.gd` | service | CRUD | `autoloads/GameState.gd` (self) | exact (extend existing is_server() guard pattern) |
| `ui/HealthBar.tscn` + `HealthBar.gd` | component | request-response | none | no analog |

---

## Pattern Assignments

### `scenes/enemies/Enemy.tscn` (scene, CharacterBody2D + MultiplayerSynchronizer)

**Analog:** `scenes/Player.tscn`

**Scene structure to copy from Player.tscn (lines 1-40):**
```
[gd_scene load_steps=... format=3]

[sub_resource type="CapsuleShape2D" id="CapsuleShape2D_1"]
radius = 12.0
height = 32.0

[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_1"]
properties/0/path = NodePath(".:position")
properties/0/allow_spawn = true
properties/0/replication_mode = 2
properties/1/path = NodePath(".:current_hp")   # ADD: enemy health
properties/1/allow_spawn = true
properties/1/replication_mode = 2
properties/2/path = NodePath(".:state")         # ADD: IDLE/CHASE enum
properties/2/allow_spawn = true
properties/2/replication_mode = 2

[node name="Enemy" type="CharacterBody2D"]
collision_layer = 3    # enemies layer (not 2 like Player)
collision_mask = 1|2   # world + players (not just 1 like Player)
script = ExtResource("1_enemy")

[node name="Sprite" type="ColorRect" parent="."]
# placeholder rect — different size/color from Player

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CapsuleShape2D_1")

[node name="NavigationAgent2D" type="NavigationAgent2D" parent="."]
# avoidance_enabled = false (performance)

[node name="HurtboxArea" type="Area2D" parent="."]
collision_layer = 5    # enemy_hurtbox
collision_mask = 6     # bullets

[node name="CollisionShape2D" type="CollisionShape2D" parent="HurtboxArea"]
shape = SubResource("CapsuleShape2D_1")

[node name="HealthBar" type="ProgressBar" parent="."]
# world-space, positioned above sprite

[node name="MultiplayerSynchronizer" type="MultiplayerSynchronizer" parent="."]
replication_config = SubResource("SceneReplicationConfig_1")
replication_interval = 0.05    # 20 Hz — identical to Player
```

**Key differences from Player.tscn:**
- `collision_layer = 3` (enemies), `collision_mask = 1|2` (world + players)
- Added `NavigationAgent2D` child
- Added `HurtboxArea` (Area2D, layer 5, mask 6)
- Added `HealthBar` (ProgressBar) child
- SceneReplicationConfig includes `current_hp` and `state` in addition to `position`

---

### `scenes/enemies/Enemy.gd` (controller, event-driven + CRUD)

**Analog:** `scenes/Player.gd`

**Authority-guard pattern from Player.gd (lines 11-13, 19-22):**
```gdscript
func _ready() -> void:
    set_multiplayer_authority(peer_id)   # Enemy: set_multiplayer_authority(1) — host owns all enemies

func _physics_process(_delta: float) -> void:
    if not is_multiplayer_authority():
        return
```

**Core pattern — adapt Player.gd movement loop to navigation-driven movement:**
```gdscript
extends CharacterBody2D

const SPEED := 80.0
const DETECT_RADIUS := 300.0
const CONTACT_DAMAGE := 10
const MAX_HP := 50

var current_hp: int = MAX_HP
var state: int = 0  # 0=IDLE, 1=CHASE
var _players_in_contact: Dictionary = {}  # peer_id → true (D-10 once-per-contact guard)

func _ready() -> void:
    add_to_group("enemies")
    # P6: clients skip physics entirely — NavigationAgent2D must not run on clients
    set_physics_process(is_multiplayer_authority())
    $HurtboxArea.body_entered.connect(_on_hurtbox_body_entered)
    $HurtboxArea.body_exited.connect(_on_hurtbox_body_exited)

func _physics_process(delta: float) -> void:
    var target := _find_nearest_player()
    if target == null or global_position.distance_to(target.global_position) > DETECT_RADIUS:
        state = 0
        velocity = Vector2.ZERO
    else:
        state = 1
        $NavigationAgent2D.target_position = target.global_position
        if not $NavigationAgent2D.is_navigation_finished():  # Pitfall 1: jitter guard
            var next := $NavigationAgent2D.get_next_path_position()
            velocity = (next - global_position).normalized() * SPEED
        else:
            velocity = Vector2.ZERO
    move_and_slide()
    $HealthBar.value = float(current_hp) / MAX_HP * 100.0
```

**Group-based player discovery (no direct reference needed):**
```gdscript
func _find_nearest_player() -> Node:
    var nearest: Node = null
    var nearest_dist := INF
    for p in get_tree().get_nodes_in_group("players"):
        var d := global_position.distance_to(p.global_position)
        if d < nearest_dist:
            nearest_dist = d
            nearest = p
    return nearest
```

**Damage + death (host-authoritative):**
```gdscript
func take_damage(amount: int) -> void:
    if not is_multiplayer_authority():   # same guard as Player input check
        return
    current_hp -= amount
    if current_hp <= 0:
        queue_free()  # CMBT-07: MultiplayerSpawner propagates to all clients automatically

func _on_hurtbox_body_entered(body: Node) -> void:
    if not is_multiplayer_authority():
        return
    if not body.is_in_group("players"):
        return
    var peer_id: int = body.peer_id
    if _players_in_contact.has(peer_id):
        return  # D-10: once per contact
    _players_in_contact[peer_id] = true
    body.receive_damage.rpc_id(body.peer_id, CONTACT_DAMAGE)

func _on_hurtbox_body_exited(body: Node) -> void:
    if body.is_in_group("players"):
        _players_in_contact.erase(body.peer_id)
```

**XP orb spawn on death — insert before queue_free():**
```gdscript
# In Game.gd, Enemy calls signal or Game.gd connects to tree_exiting
# Simplest: Enemy emits signal, Game.gd spawns orb
signal died(pos: Vector2)

func take_damage(amount: int) -> void:
    if not is_multiplayer_authority():
        return
    current_hp -= amount
    if current_hp <= 0:
        died.emit(global_position)  # CMBT-08: Game.gd handler spawns XP orb
        queue_free()
```

---

### `scenes/projectiles/Bullet.tscn` (scene, Area2D — no synchronizer)

**Analog:** `scenes/Player.tscn` (structure reference only; Bullet uses Area2D not CharacterBody2D)

**Scene structure:**
```
[node name="Bullet" type="Area2D"]
collision_layer = 6     # bullets
collision_mask = 1|5    # world + enemy_hurtbox

[node name="Sprite" type="ColorRect" parent="."]
# tiny rect, e.g. 8x4

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
# small RectangleShape2D or CircleShape2D

# CRITICAL: NO MultiplayerSynchronizer — clients simulate from initial velocity (RESEARCH Pitfall 2, Anti-Pattern 1)
```

---

### `scenes/projectiles/Bullet.gd` (controller, event-driven)

**Analog:** `scenes/Player.gd` (authority-guard + physics loop pattern)

**Authority-guard from Player.gd (lines 19-22) — adapted for Area2D:**
```gdscript
extends Area2D

const SPEED := 400.0
const LIFETIME := 3.0
const BULLET_DAMAGE := 20

@export var direction: Vector2 = Vector2.RIGHT
@export var owner_peer_id: int = 0  # D-08: immune to own bullets

var _elapsed: float = 0.0

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    area_entered.connect(_on_area_entered)
    rotation = direction.angle()
    # ALL peers simulate movement — no authority guard on _physics_process
    # (clients need local simulation for smooth visuals)

func _physics_process(delta: float) -> void:
    position += direction * SPEED * delta
    _elapsed += delta
    if _elapsed >= LIFETIME:
        if is_multiplayer_authority():  # only host calls queue_free
            queue_free()

func _on_body_entered(_body: Node) -> void:
    # Wall hit — host-only (D-07)
    if not is_multiplayer_authority():
        return
    queue_free()  # propagates to all clients via MultiplayerSpawner

func _on_area_entered(area: Node) -> void:
    # Enemy hurtbox hit — host-only (D-07)
    if not is_multiplayer_authority():
        return
    var enemy := area.get_parent()
    if enemy.has_method("take_damage"):
        enemy.take_damage(BULLET_DAMAGE)
    queue_free()
```

**Spawn data requirement (Pitfall 2 — direction must be in spawn data):**
```gdscript
# In Game.gd _do_spawn_bullet(data):
func _do_spawn_bullet(data: Dictionary) -> Node:
    var b := BULLET_SCENE.instantiate()
    b.position = data["pos"]
    b.direction = data["dir"]        # REQUIRED: clients need this for local simulation
    b.owner_peer_id = data["owner_id"]
    b.name = "Bullet_%d" % (randi() % 99999)
    return b
```

---

### `scenes/pickups/XpOrb.tscn` (scene, Area2D)

**Analog:** `scenes/Player.tscn` (structure only)

**Scene structure:**
```
[node name="XpOrb" type="Area2D"]
collision_layer = 7     # pickups (new layer — add to project.godot)
collision_mask = 2      # players

[node name="Sprite" type="ColorRect" parent="."]
# small colored circle/rect

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
# small CircleShape2D radius=8

# NO MultiplayerSynchronizer — position is static after spawn
```

---

### `scenes/pickups/XpOrb.gd` (controller, event-driven)

**Analog:** `scenes/Player.gd` (authority-guard pattern)

**Core pattern — body_entered with double-collect guard (RESEARCH Pitfall 5):**
```gdscript
extends Area2D

var _collected: bool = false  # Pitfall 5: prevents double-collection race condition

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if not body.is_in_group("players"):
        return
    # Client stepping on orb sends request to host
    var peer_id: int = body.peer_id
    if peer_id == multiplayer.get_unique_id():
        _request_collect.rpc_id(1, name)  # host validates

@rpc("any_peer", "call_remote", "reliable")
func _request_collect(orb_name: String) -> void:
    # Runs on host only
    if not multiplayer.is_server():
        return
    if _collected:
        return  # Pitfall 5: already collected
    _collected = true
    queue_free()  # CMBT-09: MultiplayerSpawner propagates to all clients
```

---

### `scenes/Game.tscn` (scene, extend existing)

**Analog:** `scenes/Game.tscn` (self — extend existing node tree)

**Current MultiplayerSpawner node (Game.tscn line 102-104):**
```
[node name="MultiplayerSpawner" type="MultiplayerSpawner" parent="."]
spawn_path = NodePath("../Room1/Entities")
```

**Additions required:**
```
# Rename existing spawner for clarity or add alongside:
[node name="EnemySpawner" type="MultiplayerSpawner" parent="."]
spawn_path = NodePath("../Room1/Entities")

[node name="BulletSpawner" type="MultiplayerSpawner" parent="."]
spawn_path = NodePath("../Room1/Entities")

[node name="PickupSpawner" type="MultiplayerSpawner" parent="."]
spawn_path = NodePath("../Room1/Entities")

# Enemy spawn point markers under Room1:
[node name="EnemySpawnPoints" type="Node2D" parent="Room1"]
[node name="ESpawn1" type="Marker2D" parent="Room1/EnemySpawnPoints"]
position = Vector2(100, 100)
# ... 4 more at corners/edges
```

---

### `scenes/Game.gd` (controller, extend existing — CRUD + event-driven)

**Analog:** `scenes/Game.gd` (self — extend existing spawn_function pattern)

**Existing spawn_function pattern to mirror exactly (Game.gd lines 7-40):**
```gdscript
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

func _ready() -> void:
    $MultiplayerSpawner.spawn_function = _do_spawn
    if multiplayer.is_server():
        _spawn_all_players()

func _do_spawn(data: Dictionary) -> Node:
    var player := PLAYER_SCENE.instantiate()
    player.peer_id    = data["id"]
    player.role_label = data["role"]
    player.position   = data["pos"]
    player.name       = "Player_%d" % data["id"]
    return player
```

**New spawners follow identical pattern — add to _ready() and add new functions:**
```gdscript
const ENEMY_SCENE  := preload("res://scenes/enemies/Enemy.tscn")
const BULLET_SCENE := preload("res://scenes/projectiles/Bullet.tscn")
const ORB_SCENE    := preload("res://scenes/pickups/XpOrb.tscn")

func _ready() -> void:
    $MultiplayerSpawner.spawn_function = _do_spawn   # existing — keep unchanged
    $EnemySpawner.spawn_function  = _do_spawn_enemy
    $BulletSpawner.spawn_function = _do_spawn_bullet
    $PickupSpawner.spawn_function = _do_spawn_pickup

    if multiplayer.is_server():
        _spawn_all_players()   # existing — keep unchanged
        _spawn_enemies()       # new

func _spawn_enemies() -> void:
    var points := $Room1/EnemySpawnPoints.get_children()
    for i in range(min(5, points.size())):
        $EnemySpawner.spawn({"pos": points[i].global_position})

func _do_spawn_enemy(data: Dictionary) -> Node:
    var e := ENEMY_SCENE.instantiate()
    e.position = data["pos"]
    e.name = "Enemy_%d" % (randi() % 9999)
    return e

func _do_spawn_bullet(data: Dictionary) -> Node:
    var b := BULLET_SCENE.instantiate()
    b.position     = data["pos"]
    b.direction    = data["dir"]        # Pitfall 2: must bake dir into data
    b.owner_peer_id = data["owner_id"]
    b.name = "Bullet_%d" % (randi() % 99999)
    return b

func _do_spawn_pickup(data: Dictionary) -> Node:
    var orb := ORB_SCENE.instantiate()
    orb.position = data["pos"]
    orb.name = "XpOrb_%d" % (randi() % 9999)
    return orb
```

**Revive handler (host-only, accumulated per frame):**
```gdscript
# Uses multiplayer.is_server() guard — identical to GameState._process() guard pattern
var _revive_progress: Dictionary = {}  # target_peer_id → float seconds
const REVIVE_DURATION := 3.5

@rpc("any_peer", "call_remote", "reliable")
func attempt_revive(reviver_id: int, target_id: int) -> void:
    if not multiplayer.is_server():
        return
    # validate proximity in get_tree().get_nodes_in_group("players")
    # accumulate _revive_progress[target_id] += get_physics_process_delta_time()
    # when >= REVIVE_DURATION: call revive_player(target_id), reset progress
```

---

### `scenes/Player.gd` (extend existing — add health, downed state, revive, weapon fire)

**Analog:** `scenes/Player.gd` (self — extend existing authority-guard pattern)

**Existing authority-guard to extend (Player.gd lines 19-26):**
```gdscript
func _physics_process(_delta: float) -> void:
    if not is_multiplayer_authority():
        return
    var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    velocity = dir * SPEED
    move_and_slide()
```

**Health/downed additions — add to export block and _ready():**
```gdscript
# Add after existing @export var role_label: String = ""
const MAX_HP := 100
const REVIVE_DURATION := 3.5

var health: int = MAX_HP    # D-17: replicated via MultiplayerSynchronizer
var is_downed: bool = false  # D-17: replicated via MultiplayerSynchronizer
var _revive_progress: float = 0.0
var _fire_cooldown: float = 0.0
const FIRE_INTERVAL := 0.5  # seconds between auto-shots

func _ready() -> void:
    set_multiplayer_authority(peer_id)   # existing — keep unchanged
    if has_node("RoleLabel"):
        $RoleLabel.text = role_label     # existing — keep unchanged
    add_to_group("players")              # ADD: required for enemy group discovery
```

**Damage RPC — host calls rpc_id(peer_id, "receive_damage", amount) (Pitfall 3 resolution):**
```gdscript
@rpc("authority", "call_remote", "reliable")
func receive_damage(amount: int) -> void:
    # Runs on owning peer — they own health sync via MultiplayerSynchronizer
    health -= amount
    if health <= 0:
        health = 0
        _enter_downed()

func _enter_downed() -> void:
    is_downed = true
    # D-12: visual tint — apply on all peers from synced is_downed in _process
    GameState.track_downed(peer_id)  # host check for game-over
```

**Downed visual — in _process (not _physics_process, no authority guard needed for visuals):**
```gdscript
func _process(_delta: float) -> void:
    if is_downed:
        $Sprite.modulate = Color(0.4, 0.4, 0.4)  # D-12: grayscale tint
    else:
        $Sprite.modulate = Color.WHITE
```

**Weapon auto-fire — append to existing _physics_process after move_and_slide():**
```gdscript
func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return
    if is_downed:
        return  # downed players cannot act
    var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    velocity = dir * SPEED
    move_and_slide()
    # Auto-fire weapon
    _fire_cooldown -= delta
    if _fire_cooldown <= 0.0:
        _try_fire()
        _fire_cooldown = FIRE_INTERVAL

func _try_fire() -> void:
    var nearest := _find_nearest_enemy()
    if nearest == null:
        return
    var dir := (nearest.global_position - global_position).normalized()
    # Host spawns bullet — all clients receive via BulletSpawner
    # Game.gd holds reference to BulletSpawner; simplest path: get_node("/root/Game/BulletSpawner")
    var spawner := get_node_or_null("/root/Game/BulletSpawner")
    if spawner and multiplayer.is_server():
        spawner.spawn({"pos": global_position, "dir": dir, "owner_id": peer_id})

func _find_nearest_enemy() -> Node:
    var nearest: Node = null
    var nearest_dist := INF
    for e in get_tree().get_nodes_in_group("enemies"):
        var d := global_position.distance_to(e.global_position)
        if d < nearest_dist:
            nearest_dist = d
            nearest = e
    return nearest
```

**SceneReplicationConfig extension — add to Player.tscn MultiplayerSynchronizer sub_resource:**
```
properties/1/path = NodePath(".:health")
properties/1/allow_spawn = true
properties/1/replication_mode = 2
properties/2/path = NodePath(".:is_downed")
properties/2/allow_spawn = true
properties/2/replication_mode = 2
```

---

### `autoloads/GameState.gd` (service, extend existing — damage tracking, game-over)

**Analog:** `autoloads/GameState.gd` (self — extend existing is_server() guard pattern)

**Existing guard pattern to mirror (GameState.gd lines 16-22):**
```gdscript
func _process(delta: float) -> void:
    if not multiplayer.has_multiplayer_peer():
        return
    if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
        return
    if not multiplayer.is_server():
        return
```

**New methods to add — use identical is_server() guard:**
```gdscript
func track_downed(peer_id: int) -> void:
    # D-14: check if ALL players are downed → game over
    if not multiplayer.has_multiplayer_peer():
        return
    if not multiplayer.is_server():
        return
    var players := get_tree().get_nodes_in_group("players")
    if players.is_empty():
        return
    var all_downed: bool = players.all(func(p): return p.is_downed)
    if all_downed:
        _broadcast_game_over.rpc()

@rpc("authority", "call_local", "reliable")
func _broadcast_game_over() -> void:
    # D-14: immediate game over, no grace period
    get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
```

**RPC annotation reference — copy from Lobby.gd line 73:**
```gdscript
@rpc("authority", "call_local", "reliable")   # identical annotation to Lobby.notify_game_starting
```

---

### `ui/HealthBar.tscn` + `ui/HealthBar.gd` (component, world-space ProgressBar)

**No direct analog exists in the codebase.** Use RESEARCH.md pattern and Godot built-in ProgressBar.

**Scene structure (world-space — no CanvasLayer):**
```
[node name="HealthBar" type="ProgressBar"]
# positioned as child of Player or Enemy node
# offset above the sprite (e.g., position = Vector2(-20, -30))
min_value = 0.0
max_value = 100.0
value = 100.0
size = Vector2(40, 6)
# show_percentage = false for clean bar look
```

**Usage in Player.gd / Enemy.gd — driven by synced property:**
```gdscript
# In _process() on ALL peers (reads synced health value):
func _process(_delta: float) -> void:
    if has_node("HealthBar"):
        $HealthBar.value = float(health) / MAX_HP * 100.0
```

**Revive progress bar (separate node above downed player, driven by _revive_progress):**
```gdscript
# Same ProgressBar approach; value driven by revive progress from host
# Shown only when is_downed == true
```

---

## Shared Patterns

### Authority Guard (apply to ALL new .gd files)

**Source:** `scenes/Player.gd` lines 19-22
```gdscript
func _physics_process(_delta: float) -> void:
    if not is_multiplayer_authority():
        return
    # ... logic here
```
**Apply to:** Enemy.gd _physics_process, Bullet.gd hit handlers, XpOrb.gd request handler, Game.gd revive handler

### Server Check (apply to all host-only logic)

**Source:** `scenes/Game.gd` line 14, `autoloads/GameState.gd` lines 16-22
```gdscript
if multiplayer.is_server():
    _spawn_all_players()
```
```gdscript
# Full guard for autoloads (connection may not be ready):
if not multiplayer.has_multiplayer_peer():
    return
if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
    return
if not multiplayer.is_server():
    return
```
**Apply to:** `_spawn_enemies()` in Game.gd, `track_downed()` in GameState.gd, `attempt_revive()` in Game.gd

### spawn_function + spawn() Pattern

**Source:** `scenes/Game.gd` lines 7-40 (complete pattern)
```gdscript
$MultiplayerSpawner.spawn_function = _do_spawn   # wire in _ready()

func _do_spawn(data: Dictionary) -> Node:
    var node := SCENE.instantiate()
    node.position = data["pos"]
    node.name = "Name_%d" % data["id"]
    return node
```
**Apply to:** EnemySpawner, BulletSpawner, PickupSpawner — all follow identical wiring

### RPC Annotation Pattern

**Source:** `autoloads/Lobby.gd` lines 67, 73, 99, 115, 127, 141
```gdscript
@rpc("any_peer",  "call_remote", "reliable")   # client → host request
@rpc("authority", "call_local",  "reliable")   # host → all peers broadcast
@rpc("authority", "call_remote", "reliable")   # host → specific peer
```
**Apply to:**
- `XpOrb._request_collect` → `@rpc("any_peer", "call_remote", "reliable")`
- `GameState._broadcast_game_over` → `@rpc("authority", "call_local", "reliable")`
- `Player.receive_damage` → `@rpc("authority", "call_remote", "reliable")`

### Group Registration Pattern

**Source:** Established in RESEARCH.md; no existing analog yet
```gdscript
# In _ready():
add_to_group("players")   # Player.gd
add_to_group("enemies")   # Enemy.gd

# Discovery:
get_tree().get_nodes_in_group("players")
get_tree().get_nodes_in_group("enemies")
```
**Apply to:** Player._ready() and Enemy._ready() — required before group-based searches work

### MultiplayerSynchronizer Config Pattern

**Source:** `scenes/Player.tscn` lines 9-13 (SceneReplicationConfig sub_resource)
```
[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_1"]
properties/0/path = NodePath(".:position")
properties/0/allow_spawn = true
properties/0/replication_mode = 2
# replication_interval = 0.05 on the MultiplayerSynchronizer node
```
**Apply to:** Enemy.tscn (add current_hp + state), Player.tscn extension (add health + is_downed)

### queue_free() Propagation (no manual despawn RPC needed)

**Source:** RESEARCH.md Anti-Patterns section
```gdscript
# On host only — MultiplayerSpawner automatically propagates to all clients:
queue_free()
```
**Apply to:** Enemy death, Bullet wall hit, Bullet enemy hit, XpOrb collection — all just call queue_free() on host

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `ui/HealthBar.tscn` / `HealthBar.gd` | component | request-response | No world-space UI components exist yet; project only has CanvasLayer-based UI (MainMenu, LobbyScreen, GameOver) |

---

## Metadata

**Analog search scope:** `scenes/`, `autoloads/`, `scenes/ui/`
**Files scanned:** 9 source files (5 .gd scripts + 2 .tscn scenes + 2 additional .gd UI scripts)
**GDScript version:** Godot 4.6 (static typing with `: type` annotations, `await` not `yield`)
**Pattern extraction date:** 2026-05-09

**Critical constraints extracted from codebase:**
- `collision_layer = 1` is `world` (StaticBody2D walls) — confirmed in Game.tscn lines 8, 43, 55, 67, 79
- `collision_layer = 2` is `players` — confirmed in Player.tscn line 16
- `collision_mask = 1` on Player means "collide with world only" — confirmed in Player.tscn line 17
- `replication_interval = 0.05` (20 Hz) — confirmed in Player.tscn line 31
- `spawn_path = NodePath("../Room1/Entities")` — confirmed in Game.tscn line 103; all new spawners share this path
- `$MultiplayerSpawner.spawn_function = _do_spawn` before any spawn calls — confirmed in Game.gd line 12
- `set_multiplayer_authority(peer_id)` called in `_ready()` — confirmed in Player.gd line 13
