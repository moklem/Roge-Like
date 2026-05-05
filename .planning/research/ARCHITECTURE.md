# Architecture: Roge-Like (Godot 4 LAN Multiplayer Roguelike)

## Scene Tree Structure

```
Main (Node) — autoloads accessible globally
├── Lobby (Autoload) — peer connection state, player registry, game start gate
├── GameEvents (Autoload) — signal bus for CARIAD HUD events, decoupled from scenes
├── GameState (Autoload) — authoritative state: timer, upgrades, revive counts (host only)
│
├── UI/
│   ├── MainMenu.tscn — host/join screen, IP entry
│   ├── LobbyScreen.tscn — role select, ready state, start button (host only)
│   └── GameOver.tscn — run ended (death or host disconnect)
│
└── Game.tscn (loaded after all players ready)
    ├── World (Node2D)
    │   ├── RoomManager — loads/transitions between Room1, Room2, Room3
    │   ├── Room1.tscn / Room2.tscn / Room3.tscn (hand-crafted tilemaps + collision)
    │   ├── EnemySpawner (MultiplayerSpawner, host-owned)
    │   │   └── [spawned Enemy nodes] (host-owned, synced to clients)
    │   └── BulletSpawner (MultiplayerSpawner, host-owned)
    │       └── [spawned Bullet nodes]
    │
    ├── Players (Node2D)
    │   └── [Player.tscn × N] (each owned by their peer, synced to others)
    │
    └── HUD (CanvasLayer — always on top)
        ├── HealthBars — watches all Player nodes
        ├── Timer — reads GameState.loop_timer
        ├── CarHUD — side panel, listens to GameEvents signals
        └── UpgradeCards — shown between loops (host triggers, all see it)
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
- Stores: `loop_timer`, `loop_number`, `upgrades: Dictionary` (peer_id → [cards]), `revives_used: Dictionary`
- Syncs to clients via MultiplayerSynchronizer on this node

---

## Host-Authoritative Split

| System | Runs On | How Clients Get State |
|--------|---------|----------------------|
| Enemy AI (chase, pathfind) | Host only | MultiplayerSynchronizer (position, health, state) |
| Enemy spawning | Host only | MultiplayerSpawner (scene path, spawn point) |
| Bullet physics | Host only | MultiplayerSpawner (pos, dir, owner_id) |
| Bullet hit detection | Host only | RPC → emit damage → client shows hit flash |
| Player movement | Each player on their own peer | MultiplayerSynchronizer (position synced to others) |
| Player input | Each player locally | RPC to host if server-side action needed |
| Game timer | Host only | GameState MultiplayerSynchronizer |
| Upgrade cards | Host only | RPC "show_cards" → each client shows UI |
| HUD events | Host emits | `@rpc("call_local")` → GameEvents.hud_event fires on all |
| Revive logic | Host validates | RPC request from client → host approves → RPC confirm |

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
| Player | `position`, `health`, `is_downed` | Player's own peer |
| Enemy | `position`, `health`, `state` | Host (peer 1) |
| GameState | `loop_timer`, `loop_number` | Host (peer 1) |
| Bullet | Spawned via SpawnState, no sync needed (despawns on hit) | Host |

---

## Roguelike Loop State Machine (Host)

```
LOBBY → ROOM_1 → ROOM_2 → ROOM_3/BOSS →
  [all alive] → UPGRADE_SCREEN → LOOP_N+1 (back to ROOM_1, harder)
  [all dead]  → GAME_OVER

ROOM_N:
  - Enemy wave(s)
  - If any player alive → room clear → transition
  - Timer runs continuously across rooms
  - If timer hits 0 mid-room → GAME_OVER (optional: spawn boss early)
```

State machine lives in `GameState` autoload. Transitions triggered by RPC from host,
received by all peers via `@rpc("call_local")`.

---

## Suggested Build Order

1. **Lobby + host/join** — ENet peer, IP entry, player registry. Test: 2 windows same machine.
2. **Player scene + sync** — WASD movement, MultiplayerSynchronizer. Test: 2 players move independently.
3. **Room 1 tilemap + collision** — Static walls, single rectangular space. Test: players navigate.
4. **Enemy + AI (host-only)** — NavigationAgent2D, MultiplayerSpawner, sync. Test: enemy chases nearest player.
5. **Bullet system** — Auto-attack, MultiplayerSpawner bullets, hit detection on host. Test: bullets despawn on hit.
6. **Health + downed + revive** — Health bar sync, downed state RPC, proximity revive. Test: player takes damage, goes down, teammate revives.
7. **GameEvents signal bus + CarHUD** — Autoload, indicator tween. Test: trigger event → HUD lights up on all screens.
8. **Roguelike loop** — Timer, upgrade cards, loop counter, difficulty scaling. Test: full loop start to end.
9. **Roles + elements** — Role select screen, per-role ability set, element modifier. Test: 3 distinct role feels.
10. **Rooms 2 + 3 + boss** — Tighter room, boss AI phases, mob waves. Test: full 3-room run.
