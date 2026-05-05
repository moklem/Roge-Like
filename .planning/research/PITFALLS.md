# Pitfalls: Roge-Like (Godot 4 LAN Multiplayer Roguelike)

---

## P1 — RPC Signature Mismatch (CRITICAL)

**What:** Every `@rpc`-annotated function must exist with an **identical** annotation and function signature on BOTH host and client, at the **same NodePath**. Godot computes a checksum over ALL RPCs in a script simultaneously. One mismatch (wrong argument count, wrong type hint, missing annotation on one side) breaks every RPC call in that script with cryptic errors like "RPC target not found" or silent drops — not pointing to the actual mismatch.

**Warning signs:**
- RPC calls silently do nothing
- Log shows "RPC `function_name` not found on peer"
- Works in editor (single player) but not LAN

**Prevention:**
- Define RPCs in both host and client script from day one
- Never add an `@rpc` function to only one branch of an if/else scene setup
- When an RPC stops working, check ALL `@rpc` functions in that script for signature drift

**Phase:** Phase 1 (Lobby) — establish RPC discipline before anything else

---

## P2 — Calling RPCs Before Peer Is Connected

**What:** Calling an RPC on a peer that hasn't finished connecting yet either crashes or silently fails. Common during lobby setup when the host tries to broadcast player data before all peers have acknowledged connection.

**Warning signs:**
- Intermittent "peer not ready" errors on join
- New client doesn't receive initial game state

**Prevention:**
```gdscript
# Host: Wait for peer_connected signal before sending initial state
multiplayer.peer_connected.connect(func(id): _send_state_to_peer.rpc_id(id, ...))
```
- Never call RPCs in `_ready()` on a node that might exist before the peer connection is established
- Use Lobby's `player_connected` signal as the gate for all initial sync

**Phase:** Phase 1 (Lobby)

---

## P3 — Missing is_multiplayer_authority() Guards

**What:** Every system that should only run on the host (enemy AI, bullet physics, timer, game state) must be guarded with `if not is_multiplayer_authority(): return`. Without it, every client runs the same AI logic, producing divergent enemy positions and double-triggering game events.

**Warning signs:**
- Enemies teleport or stutter on client screens
- Damage applied twice per hit
- Timer runs at different speeds on different machines

**Prevention:**
```gdscript
func _physics_process(delta):
    if not is_multiplayer_authority(): return
    # ... host-only logic
```
- Apply to: Enemy `_physics_process`, Bullet spawner, GameState timer tick, upgrade card display trigger
- Rule of thumb: if it changes game state, guard it

**Phase:** Phase 2 (enemy + bullets)

---

## P4 — MultiplayerSynchronizer Over-Syncing

**What:** Syncing every property of every node every frame creates bandwidth spikes and latency on LAN (even though LAN is fast, Godot's serialization overhead compounds). Common mistake: syncing velocity, animation state, element modifier, and ability cooldowns all in one synchronizer.

**Warning signs:**
- Stuttering in client movement that isn't present in solo play
- Frame drops when many enemies are active
- Log shows high RPC/packet counts

**Prevention:**
- Sync only what clients need to display: `position`, `health`, `is_downed`
- Leave velocity, animation, and local state to be derived on each client
- For enemies: sync position + health + `state` enum (IDLE/CHASING/ATTACKING). Don't sync pathfinding intermediate values.
- Set `replication_interval` on MultiplayerSynchronizer to 0.05 (20 Hz) rather than every frame

**Phase:** Phase 2 (player sync), Phase 3 (enemy sync)

---

## P5 — Bullet Sync Strategy: Spawner vs Manual RPC

**What:** Syncing bullet positions every frame via MultiplayerSynchronizer is expensive for fast-moving projectiles. The common alternative (manual RPC per bullet) is cleaner but requires careful cleanup.

**Recommended approach:**
- Host spawns bullets via MultiplayerSpawner (clients auto-instantiate the scene)
- Bullets move via `move_and_slide()` on host, position synced minimally (or not at all — clients predict movement locally)
- On hit: host calls `@rpc("call_local")` to despawn bullet and apply damage
- Bullet position prediction on clients: client copies initial velocity and simulates. Small desyncs are invisible on LAN.

**Warning signs:**
- Many bullets cause lag spikes
- Bullets appear to "snap back" on clients

**Prevention:**
- Do NOT add a MultiplayerSynchronizer to each Bullet instance
- Use SpawnState in MultiplayerSpawner to pass initial position + direction
- Despawn via `queue_free()` called by host, propagated via MultiplayerSpawner automatically

**Phase:** Phase 3 (bullet system)

---

## P6 — NavigationAgent2D Running on Clients

**What:** If NavigationAgent2D pathfinding runs on all peers, each client computes enemy paths independently. Small floating-point differences accumulate into divergent enemy positions across screens.

**Warning signs:**
- Enemies appear in slightly different positions on different clients
- Enemies on clients occasionally chase wrong player

**Prevention:**
```gdscript
func _ready():
    set_physics_process(is_multiplayer_authority())
    navigation_agent.avoidance_enabled = false  # perf optimization for swarms
```
- Clients only render the position synced from host's MultiplayerSynchronizer
- Only host calls `navigation_agent.target_position = ...`

**Phase:** Phase 3 (enemy AI)

---

## P7 — Scene Spawnable List Gaps

**What:** MultiplayerSpawner requires that every scene it might spawn is pre-registered in its spawnable scenes list. If a new enemy type or bullet variant is added later and not registered, the spawn call silently fails on clients (host spawns it, clients see nothing).

**Warning signs:**
- New enemy type visible on host but not on clients
- No error in log — just missing entities on client screen

**Prevention:**
- Register ALL scene variants in the spawner at build time
- Create a single `EnemySpawner` node that holds all enemy types in its list from Phase 1
- Add a comment in spawner's `_ready()` listing every registered scene — update it when adding new types

**Phase:** Phase 2 (spawner setup)

---

## P8 — GameState Not Authoritative

**What:** If upgrades, revive counts, or loop timer are stored locally per-client (e.g., in a local variable in Player.gd), clients will get desynced. One player uses a revive in their local state; host doesn't know; another player's screen still shows revive available.

**Warning signs:**
- Players see different revive counts
- Loop timer at different values on different screens
- Upgrade card selections diverge

**Prevention:**
- All mutable game state lives in `GameState` autoload, authoritative on host
- Clients never write to GameState directly — they RPC to host, host validates and updates
- MultiplayerSynchronizer on GameState node syncs read-only view to clients

**Phase:** Phase 4 (roguelike loop)

---

## P9 — Host Disconnect Not Handled

**What:** When host (peer 1) disconnects, Godot fires `peer_disconnected(1)` on all clients. Without a handler, clients remain in the Game scene indefinitely — controls still work, enemies freeze (host AI is gone), game appears to hang.

**Warning signs:**
- Client freezes when host closes
- No "game over" screen after host crash in testing

**Prevention:**
```gdscript
# In Lobby autoload:
func _ready():
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_disconnected(id: int):
    if id == 1:  # host disconnected
        get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
        # pass reason: "Host disconnected"
```
- Test this explicitly in Phase 1 before any gameplay

**Phase:** Phase 1 (Lobby)

---

## P10 — Room Transition Desync

**What:** `get_tree().change_scene_to_file()` called only on the host means only the host loads the new room. Clients stay in the old scene, producing a split-brain state.

**Warning signs:**
- Host shows Room 2; clients still show Room 1
- Players "disappear" after room clear on client screens

**Prevention:**
```gdscript
@rpc("call_local", "reliable")
func _transition_to_room(path: String):
    get_tree().change_scene_to_file(path)
```
- Always use `call_local` variant so host also transitions in the same call
- After transition, host waits one frame before spawning enemies (new scene tree must settle)
- Test room transitions with 2 players before building Room 2

**Phase:** Phase 5 (room 2 + 3)

---

## P11 — HUD Events Fired Before Client Connects

**What:** If a HUD event fires (via `GameEvents.fire_hud_event.rpc(...)`) before a client peer is fully connected, the late client misses all pre-connection events. In a lobby game this is low risk, but if the HUD fires during loading/transition, the client miss is silent.

**Prevention:**
- Gate all game-event RPCs to fire only after `Lobby.all_players_ready` signal
- HUD indicators are ephemeral (light up, fade out) — missed events are non-critical for demo
- V2X auto-trigger: start its timer only after `Game.tscn` scene is fully loaded on all peers

**Phase:** Phase 4 (HUD wiring)

---

## P12 — Input Authority: Client Calling RPC on Wrong Peer's Player

**What:** If players can issue RPCs that affect other players' nodes (e.g., a client calling `player.take_damage.rpc()` directly), any player can act as any character. Input authority must be enforced.

**Prevention:**
```gdscript
# In Player.gd — only the owning peer handles input
func _process(delta):
    if not is_multiplayer_authority(): return
    # ... read input, move, fire ability
```
- RPC calls that affect other players must route through the host:
  `host_request_revive.rpc_id(1, target_player_id)` — host validates proximity, then confirms
- Never expose `take_damage` as an RPC callable by clients

**Phase:** Phase 2 (player authority), Phase 3 (revive system)

---

## P13 — Upgrade Cards Not Synced to All Clients

**What:** Upgrade card selection happens between loops. If host generates cards locally and only shows them on the host screen, clients wait at a black screen and can't pick.

**Prevention:**
- Host generates card options → broadcasts via `@rpc("call_local")` → all clients show UI
- Each client sends their selection as RPC to host → host records in GameState
- Host waits for all alive players to confirm selection before starting next loop
- Add a timeout (30s) — if a player doesn't pick, auto-assign first card

**Phase:** Phase 4 (roguelike loop)
