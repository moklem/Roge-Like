# Technology Stack

**Project:** Roge-Like (Godot 4 LAN Co-op Roguelike)
**Researched:** 2026-05-05
**Godot stable at research time:** 4.6.2-stable (GitHub releases, confirmed)

---

## Recommended Stack

### Engine

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Godot Engine | **4.6.2-stable** | Game engine | Mandated by project. Latest stable as of research date. Use this exact version — do not downgrade to 4.3/4.4 |
| GDScript | built-in | Scripting language | No C# overhead, matches all official LAN multiplayer examples, faster to iterate for a demo team |
| Compatibility renderer | built-in | 2D rendering | Top-down 2D has zero need for Forward+/Vulkan; Compatibility (OpenGL) runs on all Windows laptops without driver issues |

---

## Multiplayer Layer

### Transport

| Node/API | Version Added | Purpose | Why |
|----------|--------------|---------|-----|
| `ENetMultiplayerPeer` | Godot 4.0 | UDP transport | Built into engine, no addon needed. ENet is Godot's only bundled reliable-UDP peer. Mandated by project constraints |
| `MultiplayerAPI` | Godot 4.0 | High-level multiplayer hub | Exposes `is_server()`, `get_unique_id()`, `peer_connected`, `peer_disconnected`, `server_disconnected` — all signals needed for this game |
| `OfflineMultiplayerPeer` | Godot 4.0 | Offline/reset state | Use to cleanly terminate sessions: `multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()` |

**Server init pattern (confirmed from official docs):**
```gdscript
# Host
var peer = ENetMultiplayerPeer.new()
var err = peer.create_server(PORT, MAX_CLIENTS)  # MAX_CLIENTS = 2 (clients; host is not a client)
multiplayer.multiplayer_peer = peer

# Client
var peer = ENetMultiplayerPeer.new()
var err = peer.create_client(ip_address, PORT)
multiplayer.multiplayer_peer = peer
```

**PORT:** Use `7000` (unprivileged, unlikely to conflict on LAN). Hardcode for demo simplicity.

### Synchronization

| Node | Purpose | When to Use |
|------|---------|-------------|
| `MultiplayerSynchronizer` | Property replication from authority → all peers | Player positions, health, state flags — anything that needs continuous sync |
| `MultiplayerSpawner` | Auto-replicates node spawns/despawns across peers | Enemy instances, bullet nodes — spawned on host, auto-appears on clients |
| `@rpc` annotation | Explicit function calls across peers | Events, state transitions, HUD triggers — anything that is a one-shot command |

**Authority model:** Server ID is always `1`. Host player has `multiplayer.get_unique_id() == 1`. All enemy AI, bullet physics, damage logic, and spawns run only on the host and replicate via MultiplayerSynchronizer / MultiplayerSpawner.

**`@rpc` modes for this game:**
```gdscript
# Input: client → server only
@rpc("any_peer", "call_remote", "reliable")
func send_input(direction: Vector2): pass

# Server → all clients (e.g. HUD events)
@rpc("authority", "call_local", "reliable")
func trigger_hud_event(event_type: String): pass

# Server → specific client
# Use rpc_id(peer_id, ...) with a reliable RPC
```

**Critical warning (confirmed from official docs):** Every function annotated `@rpc` on ANY node must be declared with the **identical signature and annotation** on both host and client scripts running that node path. RPC signatures are validated by checksum of all RPCs in the script. Mismatches print cryptic errors. NodePath must also match exactly — use `force_readable_name: true` on `add_child()` for dynamically spawned nodes that need RPCs.

---

## Scene Structure

### Autoloads (Singletons)

| Autoload Name | Purpose | Notes |
|--------------|---------|-------|
| `Lobby` | Network init/teardown, peer registry, lobby handshake | Persists across scene changes. Contains `create_game()`, `join_game(ip)`, `remove_multiplayer_peer()`, `players` dict keyed by peer ID |
| `GameEvents` | Global signal bus for HUD triggers and game events | `signal hud_event(type: String)`, `signal player_downed(peer_id: int)`, `signal loop_completed()` — purely signals, no state |
| `GameState` | Loop timer, score/difficulty scaling, upgrade tracking | Single source of truth for loop number, difficulty multiplier |

**Why signal bus (GameEvents)?** The CARIAD HUD must react to events from enemies, bullets, players in different scenes. Without a bus, you'd need to wire cross-scene node references that break on scene reload. Autoloaded signals survive scene changes cleanly.

### Scene Tree

```
/root
├── Lobby (Autoload)          # Network singleton
├── GameEvents (Autoload)     # Signal bus
├── GameState (Autoload)      # Loop state
└── [Active Scene]
    ├── Main (Node2D)         # Root for current game room
    │   ├── TileMap           # Room geometry + collision
    │   ├── NavigationRegion2D  # Baked navmesh for enemies
    │   ├── MultiplayerSpawner  # spawn_path = "Entities"
    │   ├── Entities (Node2D)   # Parent for all spawned nodes
    │   │   ├── Player_1 (CharacterBody2D)
    │   │   ├── Player_2 (CharacterBody2D)
    │   │   ├── Enemy_xxx (CharacterBody2D)
    │   │   └── Bullet_xxx (Area2D)
    │   └── HUD (CanvasLayer)   # layer = 1, always on top
    │       ├── HealthBars
    │       ├── LoopTimer
    │       ├── CarHUDPanel     # CARIAD side panel
    │       └── RevivePrompt
```

**Why Entities as a shared parent?** `MultiplayerSpawner.spawn_path` points to one node. All spawnable types (enemies, bullets, drone units) go under `Entities`. The spawner auto-replicates `add_child()` to clients.

### Individual Scene Templates

**Player.tscn:**
```
CharacterBody2D (root)         ← set_multiplayer_authority(peer_id) after spawn
  ColorRect (placeholder body)
  CollisionShape2D
  Area2D (hurtbox)
    CollisionShape2D
  MultiplayerSynchronizer      ← replicates: position, health, is_downed
```

**Enemy.tscn:**
```
CharacterBody2D (root)         ← authority = host (peer 1), always
  ColorRect (placeholder body)
  CollisionShape2D
  NavigationAgent2D
  MultiplayerSynchronizer      ← replicates: position, current_hp, state enum
```

**Bullet.tscn:**
```
Area2D (root)                  ← authority = host, area_entered on host only
  ColorRect
  CollisionShape2D
  MultiplayerSynchronizer      ← replicates: position (or use RPC for hit event)
```

**Why `Area2D` for bullets, not `CharacterBody2D`?** Bullets don't need `move_and_slide()`. `Area2D` with `body_entered`/`area_entered` is simpler and cheaper for projectiles that travel in straight lines.

---

## 2D Gameplay Layer

### Character Movement

| Node | Purpose | Notes |
|------|---------|-------|
| `CharacterBody2D` | All moving actors (players, enemies) | `move_and_slide()` handles collision response; `velocity` property set each physics frame |
| `CollisionShape2D` | Collision body | Use `CapsuleShape2D` or `CircleShape2D` for top-down actors (rectangular shapes cause edge-catching) |

**Top-down 8-way movement:**
```gdscript
# In player _physics_process, INPUT only read where is_multiplayer_authority()
func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return
    var dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    velocity = dir * speed
    move_and_slide()
    # Then RPC input to server or let MultiplayerSynchronizer handle position
```

### Collision Layers (recommended assignment)

| Layer | Name | Used By |
|-------|------|---------|
| 1 | `world` | TileMap walls |
| 2 | `players` | Player CharacterBody2D |
| 3 | `enemies` | Enemy CharacterBody2D |
| 4 | `player_hurtbox` | Player Area2D hurtbox |
| 5 | `enemy_hurtbox` | Enemy Area2D hurtbox |
| 6 | `bullets` | Bullet Area2D |

Set these in Project Settings → Layer Names → 2D Physics. Naming layers prevents magic-number bugs when configuring masks.

### Enemy AI

| Node | Purpose | Notes |
|------|---------|-------|
| `NavigationAgent2D` | Pathfinding for enemies | **Experimental** label in 4.6 docs — but stable enough for production use per community; the "experimental" tag refers to the API potentially changing, not instability at runtime |
| `NavigationRegion2D` | Baked navigation polygon | One per room. Bake in editor; rooms are hand-crafted so dynamic rebaking not needed |

**Enemy chase pattern (host-only):**
```gdscript
func _physics_process(delta: float) -> void:
    if not multiplayer.is_server():
        return  # AI logic only on host
    var target = _get_nearest_player()
    if target:
        nav_agent.target_position = target.global_position
    velocity = (nav_agent.get_next_path_position() - global_position).normalized() * speed
    move_and_slide()
```

**Why not just `global_position.direction_to(player)` without navigation?** The rooms have walls (ERBA island rocks, Bamberg corridor walls, Burg Altenburg boss room). Pure direction chase causes enemies to get stuck. NavigationAgent2D handles wall avoidance correctly on the fixed hand-crafted maps.

---

## HUD Layer

| Node | Purpose | Notes |
|------|---------|-------|
| `CanvasLayer` | HUD root, layer=1 | Renders above game world regardless of camera pan; does not move with camera |
| `Control` nodes inside | UI panels, labels, progress bars | Use anchors for layout; `AnchorPreset.FULL_RECT` for side panel |

**CARIAD HUD wiring pattern:**
```gdscript
# In CarHUDPanel.gd
func _ready() -> void:
    GameEvents.hud_event.connect(_on_hud_event)

func _on_hud_event(event_type: String) -> void:
    match event_type:
        "ice_attack":  _flash_indicator($ACSensor, "AC ❄️ COLD")
        "fire_damage": _flash_indicator($EngineSensor, "ENGINE 🔥 OVERHEAT")
        # ...
```

**Trigger from anywhere:**
```gdscript
# In player ability script (runs on host, replicated via RPC)
@rpc("authority", "call_local", "reliable")
func _broadcast_hud_event(event_type: String) -> void:
    GameEvents.hud_event.emit(event_type)
```

The HUD reacts to `GameEvents.hud_event` locally on each peer. The RPC broadcasts the event string from host to all clients; each client's local signal bus then fires the HUD animation. This means zero additional synchronization state for HUD — it's purely event-driven.

---

## Room / Level Layer

| Node | Purpose | Notes |
|------|---------|-------|
| `TileMap` | Room geometry and walls | Use built-in collision on tiles via TileSet; no need for separate StaticBody2D walls |
| `TileSet` | Tile definitions | Placeholder colored tiles; define collision shapes per tile in TileSet editor |
| `NavigationRegion2D` + `NavigationPolygon` | Walkable area for enemies | Bake once per room in editor; collision from TileMap can be used as obstruction input |
| `Node2D` named `SpawnPoints` | Player and enemy spawn positions | Child `Marker2D` nodes for each spawn slot |

**Why TileMap over hand-placed `StaticBody2D` walls?** For 3 hand-crafted rooms with placeholder art, TileMap is the fastest path: draw rooms in the editor, collision is automatic per tile type. StaticBody2D walls require manual node placement and are harder to iterate on.

---

## Game Loop / State Layer

| Node/Pattern | Purpose | Notes |
|-------------|---------|-------|
| `Timer` node | Loop countdown (15 min), boss wave intervals, revive window | Use `one_shot = true` for revive timer; `wait_time = 900.0` for loop timer |
| `Resource` subclass | Player stats, enemy base stats, upgrade card definitions | `class_name PlayerStatsResource extends Resource` with `@export` fields — edit values in Inspector, no hardcoding |
| Custom `Node` state machine | Player state (alive, downed, reviving), enemy state (idle, chase, attack) | Simple `enum State { IDLE, CHASE, ATTACK }` + match statement. No addon needed for 3-state machines |

---

## What NOT to Use

| Technology | Why Not |
|------------|---------|
| **WebRTC / WebSocket peers** | LAN-only game; ENet is built-in and purpose-fit. WebRTC adds STUN/TURN complexity that doesn't apply |
| **Steam Networking / GodotSteam addon** | Internet matchmaking. Out of scope. LAN = ENet only |
| **Nakama / PlayFab / Mirror** | Server-authoritative online backends. Overkill for a 3-laptop demo |
| **C# scripting** | Adds .NET 8 runtime requirement, longer compile times, harder for small team to iterate. GDScript is correct here |
| **Dedicated server export mode** | Host-as-player model (peer ID = 1 is a player). Dedicated server is a different topology |
| **AnimationPlayer for HUD flashes** | Use `Tween` (built-in, scriptable, no animation files needed) for indicator flash animations |
| **Mirage.Godot (C# networking addon)** | C# dependency + unnecessary abstraction layer over the built-in system |
| **NavigationAgent2D `avoidance_enabled = true`** | RVO avoidance has significant CPU cost when many agents are active. For a roguelike with mob swarms, leave avoidance off and rely on pathfinding + physical collision to separate agents. Only enable avoidance if agents visibly clump badly |
| **Multiple MultiplayerAPI instances** | Used for running server+client in one instance (testing topology). For this project, one instance per machine = single default MultiplayerAPI is correct |
| **`KinematicBody2D`** | Godot 3 API — was renamed `CharacterBody2D` in Godot 4. Never use the old name |

---

## Addons: None Required

This project intentionally uses zero addons. The built-in Godot 4.6 API covers:

- ✅ ENet multiplayer transport
- ✅ Node-based scene synchronization
- ✅ Auto-spawn/despawn replication
- ✅ 2D navigation with pathfinding
- ✅ CanvasLayer HUD
- ✅ TileMap rooms
- ✅ Timer-based game loops

The only candidate addon worth knowing about is **Godot Rollback Netcode** (by snopek-games) — but it's for competitive games requiring rewind/rollback. A co-op host-authoritative roguelike over LAN with 3 players has zero need for it.

---

## Project Settings to Configure

```ini
# In project.godot or Project Settings UI:
[network]
# Nothing special needed for ENet LAN — defaults work

[layer_names]
# 2d_physics/layer_1 = "world"
# 2d_physics/layer_2 = "players"
# 2d_physics/layer_3 = "enemies"
# 2d_physics/layer_4 = "player_hurtbox"
# 2d_physics/layer_5 = "enemy_hurtbox"
# 2d_physics/layer_6 = "bullets"

[rendering]
# renderer/rendering_method = "gl_compatibility"  # Force Compatibility renderer
```

---

## Confidence Levels

| Area | Confidence | Source |
|------|------------|--------|
| Godot version (4.6.2-stable) | **HIGH** | GitHub Releases API, confirmed |
| ENet server/client init | **HIGH** | Official docs (https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) |
| `@rpc` annotation modes and signature rules | **HIGH** | Official docs — warning explicitly documented |
| MultiplayerSynchronizer / MultiplayerSpawner | **HIGH** | Official class docs, both verified |
| NavigationAgent2D "experimental" label | **HIGH** | Official class docs note, confirmed usable |
| `CharacterBody2D` for top-down movement | **HIGH** | Official docs, standard pattern |
| Signal bus (Autoload) architecture | **HIGH** | Official docs recommend Autoloads for cross-scene communication |
| TileMap for hand-crafted rooms | **HIGH** | Official docs, standard pattern |
| No addons needed | **HIGH** | Verified all required features exist in built-in API |

---

## Sources

- Godot 4.6 High-level multiplayer: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- ENetMultiplayerPeer class reference: https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html
- MultiplayerSynchronizer class reference: https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html
- MultiplayerSpawner class reference: https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html
- NavigationAgent2D class reference: https://docs.godotengine.org/en/stable/classes/class_navigationagent2d.html
- CanvasLayer class reference: https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html
- Godot 4.6.2-stable release: GitHub Releases API (2026-04-01)
- Context7: /websites/godotengine_en_stable (HIGH reputation, verified)
