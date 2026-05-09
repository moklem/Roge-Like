# Phase 3: Room 1, Enemy AI, Combat Core — Research

**Researched:** 2026-05-09
**Domain:** Godot 4.6 NavigationAgent2D, MultiplayerSpawner, host-authoritative combat
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Enemy pathfinding updates every frame (~60 Hz). Host recalculates NavigationAgent2D target position continuously while chasing.
- **D-02:** Enemies use field-of-view detection with a configurable detection radius. Outside that radius, enemies idle.
- **D-03:** Room 1 geometry uses simple rectangular placeholder colliders (StaticBody2D + CollisionShape2D).
- **D-04:** Perform a 30-minute navmesh spike to validate NavigationAgent2D baking against existing geometry before committing final Room 1 layout.
- **D-05:** Bullets spawned via MultiplayerSpawner. Host spawns, all peers receive identical bullet instantiation with initial velocity baked in. Bullets pre-registered in spawner's spawnable list.
- **D-06:** Bullets aimed at nearest enemy within range.
- **D-07:** Bullet hit detection is host-only and authoritative. Host detects hits, broadcasts despawn RPC to all clients.
- **D-08:** Players are immune to their own bullets.
- **D-09:** Enemy contact damage is host-only and authoritative.
- **D-10:** Damage from enemy contact is once per contact (not damage-over-time).
- **D-11:** World-space health bars above all characters + optional HUD corner summary.
- **D-12:** Downed state appearance: color shift (grayscale or red tint).
- **D-13:** Revive hold duration is 3–4 seconds.
- **D-14:** When all players simultaneously downed, immediate game over.
- **D-15:** Enemy spawning follows spawn_function pattern (same as Phase 2 player spawning).
- **D-16:** XP orb collection host-authoritative via MultiplayerSpawner.
- **D-17:** Health synced via MultiplayerSynchronizer at 20 Hz. Downed state is a `bool downed` property that syncs with health.
- **D-18:** Single basic enemy type: chase + attack (melee contact).
- **D-19:** Fixed spawn points, 3–5 enemies at game start.

### Claude's Discretion

None specified beyond locked decisions.

### Deferred Ideas (OUT OF SCOPE)

- Map Data Import phase (Google Maps data for ERBA island — replace placeholder rectangles with actual footprints)
- Multiple enemy types (Phase 8+)
- Enemy wave spawning (Phase 6)
- Damage feedback VFX (Phase 7+)
- HUD event firing from combat (Phase 6)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CMBT-01 | At least one basic enemy type chases and attacks the nearest player | NavigationAgent2D chase pattern; host-only guard; detection radius |
| CMBT-02 | Enemy pathfinds around room walls | NavigationRegion2D + baked NavigationPolygon; parsed_geometry_type = STATIC_COLLIDERS covers StaticBody2D walls |
| CMBT-03 | Enemies spawned and controlled by host; clients see synced result | spawn_function pattern (D-15); MultiplayerSynchronizer at 20 Hz on enemy position |
| CMBT-04 | Starter weapon: screws and bolts fly outward automatically | Area2D bullet scene; fire timer; direction = nearest enemy; auto-fire on cooldown |
| CMBT-05 | Bullets/projectiles despawn on enemy or wall contact | host body_entered handler; queue_free propagates via MultiplayerSpawner |
| CMBT-06 | Bullet hits apply damage to struck enemy (host-authoritative) | host-only Area2D body_entered; damage call guarded by is_multiplayer_authority() |
| CMBT-07 | Enemy death removes enemy from all clients simultaneously | queue_free() on host propagates to all clients automatically via MultiplayerSpawner |
| CMBT-08 | Enemy death drops XP orb pickup at enemy position | PickupSpawner (MultiplayerSpawner); spawn XpOrb with position data |
| CMBT-09 | Player walking over XP orb collects it; orb despawns from all clients | Area2D orb; host validates body_entered; queue_free propagates |
| HLTH-01 | Each player has visible health bar shown to all players | World-space ProgressBar child of player node; value driven by synced health property |
| HLTH-02 | Enemies deal damage to players on contact | host-only CharacterBody2D overlap check or Area2D hurtbox; once-per-contact guard |
| HLTH-03 | Player health synced to all clients in real time | health property added to SceneReplicationConfig in Player.tscn MultiplayerSynchronizer |
| HLTH-04 | Player at 0 HP enters downed state | is_downed bool; state machine in Player.gd; synced via MultiplayerSynchronizer |
| HLTH-05 | Teammate can hold key near downed player to revive | Revive proximity check; Timer countdown; host validates |
| HLTH-06 | Revive has visible hold-progress bar | ProgressBar UI node above downed player; driven by revive_timer / REVIVE_DURATION |
| HLTH-08 | If all players simultaneously downed, run ends | GameState tracks downed count; when == total players, broadcast game_over RPC |
</phase_requirements>

---

## Summary

Phase 3 adds the entire combat layer on top of the Phase 2 networking skeleton. It involves three new scene types (Enemy.tscn, Bullet.tscn, XpOrb.tscn), extensions to Player.gd (health, downed state, revive logic), a new Game.gd subsystem (combat spawning, weapon fire timer, game-over detection), and world-space UI (health bars, revive progress bar).

The most technically risky item is the NavigationAgent2D navmesh. The existing Game.tscn already has a NavigationRegion2D node with an empty NavigationPolygon. Before finalizing the room obstacle layout, a 30-minute spike must bake the navmesh and confirm enemies pathfind around the four boundary walls and any interior obstacles. The baking happens in the editor via toolbar button — there is no `bake()` runtime method in Godot 4.6 standard workflow.

The second critical constraint is bullet handling. The correct pattern is: host spawns bullet via MultiplayerSpawner (all clients get it for free), clients simulate local movement from the initial velocity baked into the spawn data, host alone runs collision detection, and on hit the host calls `queue_free()` which MultiplayerSpawner propagates to all clients automatically. Do NOT add a MultiplayerSynchronizer per bullet.

All 17 requirements (CMBT-01 through CMBT-09, HLTH-01 through HLTH-08 excluding HLTH-07) are achievable within the established host-authoritative pattern with no new architectural concepts.

**Primary recommendation:** Implement in dependency order — navmesh spike first, then enemy scene + AI, then bullet scene + combat loop, then health/downed/revive UI. Each step is independently testable with 2 game windows on one machine.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Enemy AI pathfinding | Host (peer 1) | — | NavigationAgent2D query runs only on host; clients get synced position |
| Enemy spawn/despawn | Host via MultiplayerSpawner | All clients (receive) | Spawner propagates add/remove automatically |
| Bullet spawn/despawn | Host via MultiplayerSpawner | All clients (simulate locally) | spawn_function passes initial velocity; clients run local motion |
| Bullet hit detection | Host only | — | is_multiplayer_authority() guard; single source of truth |
| Enemy contact damage | Host only | — | Overlap detection in host physics; health RPC not needed (sync covers it) |
| Player health sync | Player's own peer (authority) | All clients (read) | MultiplayerSynchronizer on Player node replicates health + is_downed |
| Revive validation | Host | Reviving client (sends request) | Client sends RPC to host; host validates proximity and time |
| Game-over detection | Host (GameState) | All clients (receive RPC) | Host checks all downed; broadcasts game_over RPC via call_local |
| World-space health bars | Local peer (each client draws its own) | — | ProgressBar nodes under Player/Enemy, read synced health value |
| XP orb collection | Host validates | Client triggers (walks over) | Client body_entered fires request; host confirms and queue_frees |

---

## Standard Stack

### Core (all already in project — no installs needed)

| Node/API | Version | Purpose | Why Standard |
|----------|---------|---------|--------------|
| `NavigationAgent2D` | Godot 4.6 built-in | Enemy pathfinding | Only built-in 2D pathfinding API; "experimental" label is API-stability warning, not runtime instability [VERIFIED: docs.godotengine.org] |
| `NavigationRegion2D` + `NavigationPolygon` | Godot 4.6 built-in | Baked navmesh for Room 1 | Already present in Game.tscn as empty node; needs polygon drawn + baked |
| `MultiplayerSpawner` | Godot 4.6 built-in | Spawn enemies, bullets, XP orbs on all peers | Already used for players in Game.tscn |
| `MultiplayerSynchronizer` | Godot 4.6 built-in | Sync enemy position + health, player health + downed | Already used for player position; extend config for new properties |
| `CharacterBody2D` | Godot 4.6 built-in | Enemy body with move_and_slide() | Consistent with Player scene |
| `Area2D` | Godot 4.6 built-in | Bullet (no physics needed), XP orb, enemy hurtbox | Lighter than CharacterBody2D for non-colliding objects |
| `ProgressBar` (Control) | Godot 4.6 built-in | Health bars, revive progress | Standard Control node; works in world-space when not under CanvasLayer |
| `Timer` | Godot 4.6 built-in | Weapon fire rate, revive hold duration, damage cooldown | Built-in, one-shot or repeating |

### Physics Layer Assignments (already in project.godot)

| Layer | Name | Used By |
|-------|------|---------|
| 1 | `world` | TileMap walls, StaticBody2D room walls |
| 2 | `players` | Player CharacterBody2D |
| 3 | `enemies` | Enemy CharacterBody2D |
| 4 | `player_hurtbox` | Player Area2D hurtbox |
| 5 | `enemy_hurtbox` | Enemy Area2D hurtbox |
| 6 | `bullets` | Bullet Area2D |

Layer 7 (`pickups`) should be added for XP orbs — currently unassigned. [ASSUMED]

### Installation

No new dependencies. All nodes are Godot 4.6 built-in.

---

## Architecture Patterns

### System Architecture Diagram

```
[Host: _physics_process]
        |
        v
  [Enemy.gd] -- is_multiplayer_authority() guard
        |
        +-- detection radius check → nearest player
        |
        +-- NavigationAgent2D.target_position = player.global_position
        |
        +-- velocity = get_next_path_position() - global_position
        |
        +-- move_and_slide()
        |
        +-- overlap with player hurtbox?
              |
              yes → apply_damage(player_id, DAMAGE)  [once per contact guard]
                         |
                         v
               Player.health -= amount
               (MultiplayerSynchronizer replicates health + is_downed to all clients)

[Any peer: Player._physics_process]
        |
        +-- is_multiplayer_authority() guard
        |
        +-- fire_timer countdown → 0? → find_nearest_enemy()
              |
              +-- spawn bullet via MultiplayerSpawner.spawn({pos, dir, owner_id})
                         |
                         v
              [All peers: _do_spawn_bullet(data)]
                   → Area2D with velocity = data.dir * BULLET_SPEED
                   → clients simulate local movement (no Synchronizer)
                   → HOST: body_entered signal
                         |
                         enemy hit → enemy.take_damage(amount)
                         wall hit  → queue_free()   ← propagates to all clients
                         enemy hit → queue_free()   ← propagates to all clients

[Host: enemy.take_damage(amount)]
        |
        +-- current_hp -= amount
        +-- if current_hp <= 0:
              enemy.queue_free()   ← propagates to all clients (CMBT-07)
              spawn XP orb at position (PickupSpawner.spawn)

[Any peer: walk over XP orb]
        |
        +-- Area2D body_entered fires on ALL peers
        +-- only the stepping player calls: request_collect_orb.rpc_id(1, orb_name)
              |
              HOST validates proximity
              → orb.queue_free()   ← propagates to all clients (CMBT-09)

[Host: check_game_over()]
        |
        +-- count downed players == total alive players?
              |
              yes → _broadcast_game_over.rpc()  [call_local]
                         |
                         all peers → change_scene_to_file(GameOver.tscn)
```

### Recommended Scene/File Structure

```
scenes/
  Game.tscn             # EXISTING — add EnemySpawner, BulletSpawner, PickupSpawner nodes
  Game.gd               # EXISTING — add enemy spawn logic, weapon fire, game-over check
  Player.tscn           # EXISTING — add health bar, hurtbox Area2D, revive ProgressBar
  Player.gd             # EXISTING — add health, is_downed, revive state machine
  enemies/
    Enemy.tscn          # NEW
    Enemy.gd            # NEW
  projectiles/
    Bullet.tscn         # NEW
    Bullet.gd           # NEW
  pickups/
    XpOrb.tscn          # NEW
    XpOrb.gd            # NEW
autoloads/
  GameState.gd          # EXISTING — add track_downed(), check_game_over()
```

### Pattern 1: Enemy Scene Structure

```
Enemy (CharacterBody2D)
  collision_layer = 3 (enemies)
  collision_mask  = 1|2 (world + players)
  ColorRect           # placeholder body visual
  CollisionShape2D    # CapsuleShape2D radius=12
  NavigationAgent2D   # host-only pathfinding
  HurtboxArea (Area2D)
    collision_layer = 5 (enemy_hurtbox)
    collision_mask  = 6 (bullets)
    CollisionShape2D
  HealthBar (ProgressBar)  # world-space, offset above sprite
  MultiplayerSynchronizer  # replicates position, current_hp, state
```

### Pattern 2: Enemy.gd Core Logic

```gdscript
# Source: derived from ARCHITECTURE.md enemy chase pattern + PITFALLS P3, P6
extends CharacterBody2D

const SPEED := 80.0
const DETECT_RADIUS := 300.0
const CONTACT_DAMAGE := 10
const MAX_HP := 50

var current_hp: int = MAX_HP
var state: int = 0  # 0=IDLE, 1=CHASE
var _last_damage_peer: int = -1  # D-10: once per contact guard

func _ready() -> void:
    # P6: clients skip all physics processing entirely
    set_physics_process(is_multiplayer_authority())
    $HurtboxArea.body_entered.connect(_on_hurtbox_body_entered)

func _physics_process(delta: float) -> void:
    # guard is redundant here since set_physics_process handles it,
    # but kept as documentation intent
    var target := _find_nearest_player()
    if target == null or global_position.distance_to(target.global_position) > DETECT_RADIUS:
        state = 0  # IDLE
        velocity = Vector2.ZERO
    else:
        state = 1  # CHASE
        $NavigationAgent2D.target_position = target.global_position
        var next := $NavigationAgent2D.get_next_path_position()
        velocity = (next - global_position).normalized() * SPEED
    move_and_slide()
    $HealthBar.value = float(current_hp) / MAX_HP * 100.0

func _find_nearest_player() -> Node:
    var nearest: Node = null
    var nearest_dist := INF
    # Iterate players under Entities — Game.gd stores reference or use group
    for p in get_tree().get_nodes_in_group("players"):
        var d := global_position.distance_to(p.global_position)
        if d < nearest_dist:
            nearest_dist = d
            nearest = p
    return nearest

func take_damage(amount: int) -> void:
    if not is_multiplayer_authority():
        return
    current_hp -= amount
    if current_hp <= 0:
        _die()

func _die() -> void:
    # CMBT-07: queue_free on host propagates to all clients via MultiplayerSpawner
    # CMBT-08: spawn XP orb before freeing
    # (orb spawn handled by caller or signal)
    queue_free()

func _on_hurtbox_body_entered(body: Node) -> void:
    # D-09/D-10: host-only, once per contact
    if not is_multiplayer_authority():
        return
    if not body.is_in_group("players"):
        return
    var peer_id: int = body.peer_id
    if peer_id == _last_damage_peer:
        return
    _last_damage_peer = peer_id
    body.receive_damage(CONTACT_DAMAGE)
```

### Pattern 3: Bullet Scene Structure

```
Bullet (Area2D)          # root — authority = host
  collision_layer = 6 (bullets)
  collision_mask  = 1|5 (world + enemy_hurtbox)
  ColorRect              # tiny rectangle, rotated to face dir
  CollisionShape2D       # small circle or rect
  # NO MultiplayerSynchronizer — clients simulate from initial velocity
```

### Pattern 4: Bullet.gd Core Logic

```gdscript
# Source: PITFALLS P5 — MultiplayerSpawner for instantiation; no Synchronizer
extends Area2D

const SPEED := 400.0
const LIFETIME := 3.0

@export var direction: Vector2 = Vector2.RIGHT
@export var owner_peer_id: int = 0

var _elapsed: float = 0.0

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    area_entered.connect(_on_area_entered)
    rotation = direction.angle()

func _physics_process(delta: float) -> void:
    # ALL peers simulate local movement from initial velocity — no sync needed
    position += direction * SPEED * delta
    _elapsed += delta
    if _elapsed >= LIFETIME:
        queue_free()  # host triggers; propagates to clients via spawner

func _on_body_entered(body: Node) -> void:
    # Wall hit
    if not is_multiplayer_authority():
        return
    queue_free()

func _on_area_entered(area: Node) -> void:
    # Enemy hurtbox hit — D-07: host-only
    if not is_multiplayer_authority():
        return
    var enemy := area.get_parent()
    if enemy.has_method("take_damage"):
        # D-08: no self-damage — check owner
        enemy.take_damage(BULLET_DAMAGE)
    queue_free()
```

### Pattern 5: Player Health + Downed State Machine

```gdscript
# Extension to existing Player.gd — Source: CONTEXT.md D-17, D-12, D-13
const MAX_HP := 100
const REVIVE_DURATION := 3.5  # D-13: 3-4 seconds

var health: int = MAX_HP
var is_downed: bool = false

# REVIVE state
var _revive_progress: float = 0.0
var _reviver_id: int = -1

func receive_damage(amount: int) -> void:
    # Called by host on this node (authority is the owning peer, but damage
    # is applied via direct call from host — host owns enemy AI and bullets)
    health -= amount
    if health <= 0:
        health = 0
        _enter_downed()
    # MultiplayerSynchronizer replicates health + is_downed to all clients

func _enter_downed() -> void:
    is_downed = true
    GameState.track_downed(peer_id)
    # D-12: visual — tint sprite gray/red (clients apply from synced is_downed)

func _process(delta: float) -> void:
    if is_downed and is_multiplayer_authority():
        # D-12: Apply visual grayscale/red tint on all peers via synced is_downed
        $Sprite.modulate = Color(0.4, 0.4, 0.4)  # grayscale
    elif not is_downed and is_multiplayer_authority():
        $Sprite.modulate = Color.WHITE
```

### Pattern 6: Revive System (Host-Validated)

```gdscript
# In Player.gd of the REVIVING player
func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return
    # ... existing movement code ...
    _check_revive(delta)

func _check_revive(delta: float) -> void:
    if Input.is_action_pressed("ui_accept"):  # "E" key — add to InputMap
        var nearby := _find_downed_player()
        if nearby:
            _request_revive.rpc_id(1, nearby.peer_id, delta)

@rpc("any_peer", "call_remote", "reliable")
func _request_revive(target_peer_id: int, delta: float) -> void:
    # Runs on HOST — validate proximity, accumulate progress
    pass

# In Game.gd or GameState.gd:
@rpc("any_peer", "call_remote", "reliable")
func request_revive(revivier_id: int, target_id: int) -> void:
    if not multiplayer.is_server():
        return
    # validate proximity, accumulate timer, confirm when complete
    pass
```

**Cleaner approach for revive:** Put revive logic in Game.gd (host-only). Clients send `rpc_id(1, "attempt_revive", my_peer_id, target_peer_id)` each frame they hold E near downed player. Host accumulates time. When time >= REVIVE_DURATION, host calls `revive_player(target_id)`.

### Pattern 7: spawn_function for Enemies

```gdscript
# In Game.gd — mirrors existing _do_spawn() for players
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")

func _ready() -> void:
    # EXISTING for players:
    $MultiplayerSpawner.spawn_function = _do_spawn

    # NEW: second spawner for enemies
    $EnemySpawner.spawn_function = _do_spawn_enemy
    $BulletSpawner.spawn_function = _do_spawn_bullet
    $PickupSpawner.spawn_function = _do_spawn_pickup

    if multiplayer.is_server():
        _spawn_all_players()
        _spawn_enemies()  # D-19: fixed points, 3-5 enemies

func _spawn_enemies() -> void:
    var enemy_points := $Room1/EnemySpawnPoints.get_children()
    for i in range(min(5, enemy_points.size())):
        $EnemySpawner.spawn({"pos": enemy_points[i].global_position})

func _do_spawn_enemy(data: Dictionary) -> Node:
    var e := ENEMY_SCENE.instantiate()
    e.position = data["pos"]
    e.name = "Enemy_%d" % (randi() % 9999)
    return e
```

### Pattern 8: NavigationRegion2D Baking (Navmesh Spike)

The navmesh spike (D-04) must be completed before enemy pathfinding is tested. Steps:

1. Open Game.tscn in Godot editor
2. Select `NavigationRegion2D` node
3. In the `NavigationPolygon` resource: set `parsed_geometry_type = PARSED_GEOMETRY_STATIC_COLLIDERS` to pick up the four wall StaticBody2D nodes [VERIFIED: docs.godotengine.org/classes/class_navigationpolygon]
4. Draw the walkable outline polygon (the full room interior) using the editor toolbar
5. Click "Bake NavigationPolygon" toolbar button
6. Verify the resulting navmesh excludes wall colliders as holes
7. Add a test enemy to confirm `get_next_path_position()` returns valid path around walls

**Key finding:** `parsed_geometry_type = PARSED_GEOMETRY_STATIC_COLLIDERS` (value 1) is the correct mode to make StaticBody2D collision shapes register as navmesh holes. The existing walls use `collision_layer = 1` (world) — ensure `parsed_collision_mask` in the NavigationPolygon includes layer 1. [VERIFIED: docs.godotengine.org/classes/class_navigationpolygon]

**Pitfall:** Placing a smaller StaticBody2D shape inside a larger one can produce flipped polygon holes. The current room has only perimeter walls (no nesting), so this should not apply. [CITED: docs.godotengine.org/tutorials/navigation/navigation_using_navigationmeshes]

### Pattern 9: Once-Per-Contact Guard for Enemy Contact Damage

D-10 specifies "once per contact, player must move away for next hit." Implement with a `Set` (or Dictionary) tracking which player IDs the enemy is currently overlapping.

```gdscript
# In Enemy.gd
var _players_in_contact: Dictionary = {}  # peer_id → true

func _ready() -> void:
    # Use CharacterBody2D collision — after move_and_slide(), check get_slide_collision_count()
    # OR use a dedicated hurtbox Area2D with body_entered/body_exited

func _on_hurtbox_body_exited(body: Node) -> void:
    if body.is_in_group("players"):
        _players_in_contact.erase(body.peer_id)

func _on_hurtbox_body_entered(body: Node) -> void:
    if not is_multiplayer_authority():
        return
    if not body.is_in_group("players"):
        return
    if _players_in_contact.has(body.peer_id):
        return  # already in contact
    _players_in_contact[body.peer_id] = true
    body.receive_damage(CONTACT_DAMAGE)
```

### Anti-Patterns to Avoid

- **Per-bullet MultiplayerSynchronizer:** Never add a MultiplayerSynchronizer to each Bullet instance. The sync overhead for many fast-moving bullets will cause lag. Use spawn_function to pass initial velocity; clients simulate locally. (P5)
- **NavigationAgent2D on clients:** Never let clients call `navigation_agent.target_position` or `get_next_path_position()`. Use `set_physics_process(is_multiplayer_authority())` in `_ready()`. (P6)
- **Missing scene registration:** Both Enemy.tscn, Bullet.tscn, and XpOrb.tscn must be registered in their respective spawner's spawn_function before first test. Silent failures if omitted. (P7)
- **Setting target_position when navigation is finished:** After `is_navigation_finished()` returns true, stop calling get_next_path_position to prevent jitter. In practice, for continuous chase, re-evaluate only when enemy is not already at target. [CITED: docs.godotengine.org/tutorials/navigation/navigation_using_navigationagents]
- **Using avoidance_enabled on enemies:** RVO avoidance has CPU cost; leave `navigation_agent.avoidance_enabled = false` for swarms. (STACK.md)
- **Direct damage RPC from clients:** Never expose `take_damage` or `receive_damage` as client-callable RPCs. Damage must originate from host logic only. (P12)
- **Skipping group registration:** Enemies finding players and players detecting downed teammates both require group tags (`add_to_group("players")` in Player._ready, `add_to_group("enemies")` in Enemy._ready).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Enemy pathfinding around walls | Custom A* or steering behaviors | `NavigationAgent2D` + baked `NavigationRegion2D` | Built-in; handles concave polygons, navigation polygon holes, multiple regions |
| Bullet lifetime management | Timer node per bullet | Bullet self-destructs via `_elapsed >= LIFETIME` in `_physics_process` + `queue_free()` | Simpler, no extra nodes; queue_free propagates via spawner |
| Multi-peer despawn of enemies/bullets/orbs | RPC to every peer to call remove_child | `queue_free()` called on host — MultiplayerSpawner propagates despawn automatically | Spawner tracks all spawned nodes; host free = all-peers free |
| Health bar layout | Manual Label + ColorRect math | `ProgressBar` Control node as child of character, offset above | Built-in; value property, min/max; no math needed |
| Revive progress tracking | Repeated RPC messages with accumulating time | Single `float _revive_progress` on host, incremented by host each frame | Host is single source of truth; no message accumulation |
| Game-over broadcast | Manual RPC to each peer | `@rpc("authority", "call_local", "reliable")` game_over function | `call_local` fires on host too; one RPC reaches all |

**Key insight:** MultiplayerSpawner's `queue_free()` propagation eliminates the entire category of "despawn sync" RPCs that multiplayer beginners typically hand-roll.

---

## Common Pitfalls

### Pitfall 1: NavigationAgent2D Jitter When Already at Target

**What goes wrong:** If `get_next_path_position()` is called every frame even when `is_navigation_finished()` is true, the agent oscillates between the final path position and the current position.

**Why it happens:** The "next path position" at the end of a path can be slightly behind the agent's current position, causing a flip-flop in velocity direction.

**How to avoid:** Check `is_navigation_finished()` before calling `get_next_path_position()`. In a chase enemy, this matters when the target is inside the detection radius but the enemy has reached the exact player position. Since contact damage fires at that point anyway, IDLE-ing the enemy when `is_navigation_finished()` is correct behavior.

**Warning signs:** Enemy sprites vibrate in place when adjacent to a player.

### Pitfall 2: Bullet Spawner Data Missing Direction

**What goes wrong:** Host spawns bullet via `spawn(data)` but `data` does not include the direction vector. Clients receive the node with no velocity, bullet sits still.

**Why it happens:** spawn_function must bake ALL initial state into the `data` Dictionary. There is no second initialization call on clients.

**How to avoid:** Include `{"pos": ..., "dir": ..., "owner_id": ...}` in every bullet spawn call. `_do_spawn_bullet(data)` sets `bullet.direction = data.dir` and `bullet.owner_peer_id = data.owner_id` before returning the node.

**Warning signs:** Bullets visible on all peers but stationary. Works on host (velocity set locally) but not on clients.

### Pitfall 3: Player health Modified on Client Instead of Host

**What goes wrong:** If `receive_damage()` is called on the player node from the owning peer's local physics (not the host), health is decremented locally but not propagated because the owning peer is not the MultiplayerSynchronizer authority for game-critical state.

**Why it happens:** Player nodes have authority set to their owning peer (for movement). But damage is a host-only decision (D-09).

**How to avoid:** Damage application must originate on the host. The enemy `_on_hurtbox_body_entered` runs only on host (guarded by `is_multiplayer_authority()`). It calls `body.receive_damage()` directly — this is a direct local call on the host, which then gets replicated via the player's MultiplayerSynchronizer. The health property is in the player's SceneReplicationConfig with authority = player's peer. This creates a complication: only the owning peer can write to synced properties.

**Resolution:** Two valid approaches:
1. **Move health authority to host:** Set Player MultiplayerSynchronizer authority to host (peer 1) for health/is_downed. Player owns position sync only. Requires splitting the Synchronizer or using two Synchronizers.
2. **RPC to owning peer:** Host calls `rpc_id(player.peer_id, "apply_damage", amount)` on the player node. Player receives it and decrements own health. Health syncs outward from that peer. [ASSUMED — both approaches work; option 2 is simpler with current architecture]

**Recommended:** Use option 2 (RPC to owning peer) since Player.tscn already has the MultiplayerSynchronizer owned by the player peer. Add `apply_damage` as `@rpc("authority", "call_remote", "reliable")` on Player.gd, called via `rpc_id(player.peer_id, "apply_damage", amount)` from host.

**Warning signs:** Host sees health go to 0 and player dies on host screen; clients show player still alive.

### Pitfall 4: Enemy Position Sync Stutter

**What goes wrong:** Clients see enemies teleporting or stuttering rather than moving smoothly.

**Why it happens:** MultiplayerSynchronizer at 20 Hz sends position 20 times/second. Without interpolation, clients see discrete jumps.

**How to avoid:** For Phase 3, the 60-pixel-per-second jump between 20 Hz ticks at 80 speed is 4px — barely visible. Accept it for this phase. If it looks bad in testing, add simple lerp in client `_process()`: `global_position = global_position.lerp(sync_position, delta * 15.0)`. Only implement if testing reveals visible stutter. [ASSUMED — acceptable for demo quality]

**Warning signs:** Enemies appear to "teleport" in small steps on client screens.

### Pitfall 5: XP Orb Double-Collection

**What goes wrong:** Multiple players step on the same orb simultaneously. Both trigger `body_entered`; both request collection from host. Host collects it twice (or first collection queue_frees it before second request arrives, causing a null reference error).

**Why it happens:** `body_entered` fires per-client, not host-only, for Area2D nodes.

**How to avoid:** In `XpOrb.gd`, track a `_collected: bool` flag on host. When host processes the first collection request, set flag and call `queue_free()`. Subsequent requests are ignored via the flag check.

**Warning signs:** Error "attempt to call method on freed object" in log during testing with multiple players near same orb.

### Pitfall 6: Revive Interrupted But Timer Not Reset

**What goes wrong:** Player starts reviving a teammate, walks away mid-revive, and the revive progress is not reset. The next player who approaches picks up where the first left off.

**Why it happens:** Revive progress tracked as `_revive_progress: float` on host; no reset when reviver leaves proximity.

**How to avoid:** In Game.gd revive handler, check each frame whether the reviving peer is still within range AND still holding E. If either condition fails, reset `_revive_progress` to 0.

---

## Code Examples

### Enemy Scene SceneReplicationConfig

```gdscript
# In Enemy.tscn MultiplayerSynchronizer replication_config:
# properties/0/path = NodePath(".:position")
# properties/0/allow_spawn = true
# properties/0/replication_mode = 2  # REPLICATION_MODE_ALWAYS
# properties/1/path = NodePath(".:current_hp")
# properties/1/allow_spawn = true
# properties/1/replication_mode = 2
# properties/2/path = NodePath(".:state")
# properties/2/allow_spawn = true
# properties/2/replication_mode = 2
# replication_interval = 0.05  # 20 Hz — same as Player
# Source: STACK.md MultiplayerSynchronizer pattern
```

### Player Health Extension to SceneReplicationConfig

```gdscript
# Extend Player.tscn MultiplayerSynchronizer to add:
# properties/1/path = NodePath(".:health")
# properties/1/allow_spawn = true
# properties/1/replication_mode = 2
# properties/2/path = NodePath(".:is_downed")
# properties/2/allow_spawn = true
# properties/2/replication_mode = 2
# Source: ARCHITECTURE.md MultiplayerSynchronizer config pattern
```

### add_to_group Pattern (Ensures Enemy/Player Discovery)

```gdscript
# In Player._ready():
add_to_group("players")

# In Enemy._ready():
add_to_group("enemies")

# Enemy finding players:
get_tree().get_nodes_in_group("players")

# GameState finding all players for game-over check:
get_tree().get_nodes_in_group("players")
```

### Game-Over Check in GameState

```gdscript
# In GameState.gd
func track_downed(peer_id: int) -> void:
    if not multiplayer.is_server():
        return
    # D-14: check if all players are downed
    var players := get_tree().get_nodes_in_group("players")
    var all_downed := players.all(func(p): return p.is_downed)
    if all_downed and players.size() > 0:
        _broadcast_game_over.rpc()

@rpc("authority", "call_local", "reliable")
func _broadcast_game_over() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `KinematicBody2D` | `CharacterBody2D` | Godot 4.0 | Never use old name — crashes on load |
| Per-frame RPC for position | `MultiplayerSynchronizer` with interval | Godot 4.0 | Sync is declarative; no manual send/receive |
| `Navigation2D` (Godot 3) | `NavigationRegion2D` + `NavigationAgent2D` | Godot 4.0 | New API; old tutorials are incorrect |
| `yield()` for async | `await` keyword | Godot 4.0 | Any old GDScript tutorials using yield are wrong |

**Deprecated/outdated:**
- `NavigationAgent2D.set_target_location()`: renamed to `target_position` (property, not method) in Godot 4.x. Any tutorial using the old method name will error.
- `NavigationAgent2D.get_next_location()`: renamed to `get_next_path_position()`. Same issue with old tutorials.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Layer 7 should be added for XP orb pickups | Standard Stack | Minor: can use existing layers or unnumbered collision; no functional breakage |
| A2 | Option 2 (RPC to owning peer for damage) is simpler than splitting MultiplayerSynchronizer authority | Pitfall 3 | If wrong: choose option 1 (host-owned health sync), requires restructuring Player Synchronizer; manageable |
| A3 | 20 Hz enemy position sync without interpolation is visually acceptable for demo quality | Pitfall 4 | If wrong: add lerp in client _process; low implementation effort |
| A4 | `call_local` game-over RPC via GameState.gd is the correct broadcast path | Code Examples | If wrong: move broadcast to Game.gd node instead; architectural only |
| A5 | NavigationPolygon parsed_collision_mask must include layer 1 ("world") for StaticBody2D walls to register as holes | Navmesh Spike | If wrong: walls are transparent to navmesh; enemies walk through walls; HIGH impact — mitigated by required spike (D-04) |

---

## Open Questions

1. **NavigationPolygon manual outline vs auto-parse**
   - What we know: `parsed_geometry_type = PARSED_GEOMETRY_STATIC_COLLIDERS` should auto-detect StaticBody2D shapes
   - What's unclear: Whether the editor bake button requires the polygon outline to already be drawn, or whether it creates it from geometry
   - Recommendation: The 30-minute navmesh spike (D-04) resolves this. Document findings in a spike note before committing room geometry.

2. **Damage authority for player health**
   - What we know: Player.gd currently sets `set_multiplayer_authority(peer_id)` — the owning peer is authority
   - What's unclear: Whether MultiplayerSynchronizer can sync a property modified by the host on a node owned by a different peer (option 1 from Pitfall 3)
   - Recommendation: Use option 2 (RPC to owning peer for `apply_damage`). Simpler and compatible with existing authority setup.

3. **XP orb spawner vs player spawner: same or separate MultiplayerSpawner?**
   - What we know: Game.tscn currently has one MultiplayerSpawner under the root node pointing to Room1/Entities
   - What's unclear: Whether to use one spawner with multiple registered scenes, or separate spawners per entity type
   - Recommendation: Use separate spawner nodes (EnemySpawner, BulletSpawner, PickupSpawner) for clarity. All can share the same spawn_path = Room1/Entities. Each has its own spawn_function. This mirrors ARCHITECTURE.md's three-spawner design.

---

## Environment Availability

Step 2.6: SKIPPED — This phase is pure Godot GDScript code/scene changes. No external CLI tools, databases, or services required beyond the Godot 4.6 editor already confirmed in use.

---

## Sources

### Primary (HIGH confidence)
- [/websites/godotengine_en_stable] — NavigationAgent2D class reference: target_position, get_next_path_position(), is_navigation_finished()
- [/websites/godotengine_en_stable] — NavigationPolygon class reference: parsed_geometry_type enum (PARSED_GEOMETRY_STATIC_COLLIDERS), agent_radius
- [/websites/godotengine_en_stable] — MultiplayerSpawner class reference: spawn_function, spawn(), queue_free() propagation
- [/websites/godotengine_en_stable] — MultiplayerSynchronizer class reference: replication_interval, SceneReplicationConfig
- https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html — physics_process usage, is_navigation_finished() jitter warning
- https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_2d.html — editor bake workflow, NavigationRegion2D + NavigationPolygon
- https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmeshes.html — StaticBody2D nesting pitfall, parse_geometry_type options
- Project codebase: Game.tscn, Game.gd, Player.tscn, Player.gd, project.godot (VERIFIED: read directly)
- STACK.md, ARCHITECTURE.md, PITFALLS.md (project research, HIGH confidence)
- CONTEXT.md Phase 3 decisions D-01 through D-19 (locked)

### Secondary (MEDIUM confidence)
- ARCHITECTURE.md enemy chase pattern code snippet — derived from official docs; matches verified NavigationAgent2D API

### Tertiary (LOW confidence / ASSUMED)
- A2: Damage RPC approach (option 2) preferred over split-synchronizer — architectural judgment, not from official docs
- A3: 20 Hz sync without interpolation is visually acceptable at demo quality — not benchmarked

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all nodes verified in Godot 4.6 official docs and existing codebase
- Architecture patterns: HIGH — directly derived from existing Phase 2 patterns + official docs
- Navmesh baking: MEDIUM — bake button workflow verified; specific parsed_geometry_type behavior for StaticBody2D walls is cited from official class reference but untested against this project's geometry (mitigated by required spike D-04)
- Pitfalls: HIGH — P3/P5/P6/P7 are project-documented; P3 (damage authority) is a known Godot multiplayer pattern

**Research date:** 2026-05-09
**Valid until:** 2026-06-09 (Godot 4.6 stable — API unlikely to change for built-in nodes in this timeframe)
