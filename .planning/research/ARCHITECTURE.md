# Architecture: Roge-Like (Godot 4 LAN Multiplayer Roguelike)

## Scene Tree Structure

```
Main (Node) — autoloads accessible globally
├── Lobby (Autoload) — peer connection state, player registry, game start gate
├── GameEvents (Autoload) — signal bus for CARIAD HUD events, decoupled from scenes
├── GameState (Autoload) — authoritative state: timer, loop count, revive counts (host only)
├── ItemDatabase (Autoload) — all car-part item/weapon definitions (Resource dicts)
│
├── UI/
│   ├── MainMenu.tscn — host/join screen, IP entry
│   ├── LobbyScreen.tscn — role + element select (two independent picks), ready state, start button
│   └── GameOver.tscn — run ended (death or host disconnect)
│
└── Game.tscn (loaded after all players ready)
    ├── World (Node2D)
    │   ├── RoomManager — loads/transitions between Room1, Room2, Room3
    │   ├── Room1.tscn / Room2.tscn / Room3.tscn (hand-crafted tilemaps + collision)
    │   ├── EnemySpawner (MultiplayerSpawner, host-owned)
    │   │   └── [spawned Enemy nodes] (host-owned, synced to clients)
    │   ├── ProjectileSpawner (MultiplayerSpawner, host-owned)
    │   │   └── [spawned Bullet/Weapon projectile nodes]
    │   └── PickupSpawner (MultiplayerSpawner, host-owned)
    │       └── [spawned XpOrb / CarPartPickup nodes]
    │
    ├── Players (Node2D)
    │   └── [Player.tscn × N] (each owned by their peer, synced to others)
    │       └── WeaponManager (Node) — child of Player, holds active weapon scenes
    │           ├── ScrewBolt.tscn (starter, always present)
    │           └── [unlocked weapons added dynamically]
    │
    └── HUD (CanvasLayer — always on top)
        ├── HealthBars — watches all Player nodes
        ├── XpBar — reads local player's xp/level (per-player)
        ├── Timer — reads GameState.loop_timer
        ├── CarHUD — side panel, listens to GameEvents signals
        └── CardOverlay — per-player level-up card selection (non-blocking, shows only for levelling player)
```

---

## Autoloads

### Lobby (Autoload)
- Owns: ENetMultiplayerPeer creation, peer_connected/disconnected signals
- Stores: `players: Dictionary` — peer_id → {name, role, element, ready}
- Host sets `multiplayer.multiplayer_peer`
- Clients call `peer.create_client(ip, port)`
- On `peer_disconnected(id)`: if id == 1 (host), call `game_over("Host disconnected")`

### GameEvents (Autoload — signal bus)
```gdscript
signal hud_event(event_name: String)   # fires on ALL peers (via RPC)
signal player_downed(player_id: int)
signal player_revived(player_id: int)
signal loop_ended(reason: String)      # "boss_dead" | "all_dead" | "timer"
```
HUD listens to `hud_event`. Game systems emit via `GameEvents.emit_hud("AC_COLD")`.
Host broadcasts via `@rpc("call_local", "any_peer", "reliable")`.

### GameState (Autoload — host authoritative)
- Runs on host only (guarded by `is_multiplayer_authority()`)
- Stores: `loop_timer`, `loop_number`, `revives_used: Dictionary` (peer_id → count)
- Does NOT store per-player XP/weapons/upgrades — those live on the Player node itself
- Syncs to clients via MultiplayerSynchronizer on this node

---

## Host-Authoritative Split

| System | Runs On | How Clients Get State |
|--------|---------|----------------------|
| Enemy AI (chase, pathfind) | Host only | MultiplayerSynchronizer (position, health, state) |
| Enemy spawning | Host only | MultiplayerSpawner (scene path, spawn point) |
| Bullet / weapon projectile physics | Host only | MultiplayerSpawner (pos, dir, owner_id) |
| Bullet hit detection | Host only | RPC → emit damage → client shows hit flash |
| Item / XP orb drops | Host only | MultiplayerSpawner (PickupSpawner) |
| Player movement | Each player on their own peer | MultiplayerSynchronizer (position synced to others) |
| Player input | Each player locally | RPC to host if server-side action needed |
| Player XP + level | Host validates XP award; player node synced | MultiplayerSynchronizer (xp, level, stage) |
| Weapon fire (all weapons) | Owning player's peer (or host for bots) | MultiplayerSpawner for projectiles |
| Card selection | Host generates cards; client picks via RPC | `rpc_id` to player + `rpc_id(1)` for response |
| Evolution stage | Host triggers threshold; RPC call_local | stage property on Player, synced via Synchronizer |
| Game timer | Host only | GameState MultiplayerSynchronizer |
| HUD events | Host emits | `@rpc("call_local")` → GameEvents.hud_event fires on all |
| Revive logic | Host validates | RPC request → host approves → RPC confirm |

---

## Player Input → Movement Flow

```
Client peer (player 2):
  _process() → read WASD input → set local velocity
  move_and_slide() locally (feels responsive)
  MultiplayerSynchronizer syncs position to all other peers

Host (peer 1):
  Receives position via sync
  Runs authoritative collision with enemies (host checks bullet hits on players)
```

> No prediction rollback needed for LAN. Local movement + sync position is sufficient.

---

## Enemy AI Flow (Host Only)

```gdscript
func _physics_process(delta):
    if not is_multiplayer_authority(): return   # clients skip entirely
    var target = _find_nearest_player()
    navigation_agent.target_position = target.global_position
    velocity = navigation_agent.get_next_path_position() - global_position
    move_and_slide()
    # MultiplayerSynchronizer automatically replicates position + health to clients
```

---

## CARIAD HUD Event Flow

```
Game event happens (e.g., Engineer uses Ice ability):
  Engineer.gd calls: GameEvents.fire_hud_event.rpc("AC_COLD")

GameEvents.gd:
  @rpc("call_local", "any_peer", "reliable")
  func fire_hud_event(event_name: String):
      emit_signal("hud_event", event_name)

CarHUD.gd (on every peer's screen):
  func _ready():
      GameEvents.hud_event.connect(_on_hud_event)
  func _on_hud_event(name):
      _light_up_indicator(name)   # tween animation, 3s duration
```

---

## Room Transition Flow

```gdscript
# Host calls when room clear condition met
func transition_to_room(scene_path: String):
    _do_transition.rpc(scene_path)

@rpc("call_local", "reliable")
func _do_transition(scene_path: String):
    get_tree().change_scene_to_file(scene_path)
    # All peers load simultaneously — no loading barrier needed for LAN
```

> For safety: wait for `get_tree().node_added` before spawning enemies on new room.

---

## MultiplayerSpawner Configuration

```gdscript
# In EnemySpawner node (host-owned):
$MultiplayerSpawner.spawn_path = NodePath("../Enemies")
$MultiplayerSpawner.add_spawnable_scene("res://scenes/enemies/BasicEnemy.tscn")

# Host spawns:
func spawn_enemy(pos: Vector2):
    if not multiplayer.is_server(): return
    var e = $MultiplayerSpawner.spawn({"position": pos, "type": "basic"})
```

> Clients automatically instantiate the scene from the spawner's spawn list.
> Clients must have the scene in the spawnable list or spawn fails silently.

---

## MultiplayerSynchronizer Configuration

Each synced node has a `MultiplayerSynchronizer` child:

| Node | Synced Properties | Authority |
|------|------------------|-----------|
| Player | `position`, `health`, `is_downed`, `level`, `stage` | Player's own peer |
| Enemy | `position`, `health`, `state` | Host (peer 1) |
| GameState | `loop_timer`, `loop_number` | Host (peer 1) |
| Bullet/Projectile | Spawned via SpawnState, no sync needed (despawns on hit) | Host |
| XpOrb / Pickup | Spawned via PickupSpawner, despawns on collect | Host |

---

## Roguelike Loop State Machine (Host)

```
LOBBY → ROOM_1 → ROOM_2 → ROOM_3/BOSS →
  [any player alive] → LOOP_N+1 (back to ROOM_1, harder)
  [all dead]         → GAME_OVER

ROOM_N:
  - Enemy waves spawn continuously
  - Players earn XP → level up → card pick (per-player, non-blocking)
  - Players collect car-part drops → weapons unlock
  - Evolution stage advances at XP level thresholds (global check on every XP award)
  - Timer runs continuously across rooms
  - Room clear condition: kill required enemies → transition to next room
  - If timer hits 0 mid-room → GAME_OVER

Per-Player XP Loop (runs in parallel with room loop):
  - Enemy dies → XP orb drops (PickupSpawner)
  - Player collects orb → xp += value → check level threshold
  - Level threshold reached → host calls rpc_id(player, "show_cards", 3 cards)
  - Player picks card → rpc_id(1, "card_selected", card_id) → host applies effect
  - Weapon pickups → host validates → weapon added to WeaponManager via rpc call_local
```

State machine lives in `GameState` autoload. Transitions triggered by RPC from host,
received by all peers via `@rpc("call_local")`.

---

## Suggested Build Order

1. **Lobby + host/join** — ENet peer, role+element select, player registry. Test: 2 windows same machine.
2. **Player scene + sync** — WASD movement, MultiplayerSynchronizer (position, health, stage). Test: 2 players move independently.
3. **Room 1 + enemy + combat** — Tilemap walls, enemy chase AI, starter weapon (screws/bolts), hit detection, health bars, downed state + revive. Test: full combat loop in one room.
4. **Weapons + pickups** — PickupSpawner, car-part drops, WeaponManager, 5 weapon scenes, weapon timers. Test: collect part → new weapon fires.
5. **XP + level-up cards + evolution** — XP orbs, level threshold, CardOverlay UI, stage transitions. Test: kill enemies → level → pick card → stage changes visual.
6. **CarHUD + loop timer + difficulty scaling** — GameEvents signal bus, 6 indicators, 15-min timer, loop counter, enemy scaling. Test: full loop triggers all HUD lights.
7. **Roles + elements** — Role abilities per stage, Fire/Ice/Earth modifiers, element HUD triggers. Test: 3-player session with distinct role+element combos.
8. **Rooms 2 + 3 + boss** — Corridor room, boss arena, boss AI phases, mob swarm waves. Test: full 3-room run with boss.
