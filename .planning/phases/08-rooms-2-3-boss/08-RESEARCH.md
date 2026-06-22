# Phase 8: Rooms 2 & 3, Boss - Research

**Researched:** 2026-06-22
**Domain:** Godot 4 multi-room architecture, boss state machine, OSM-derived level geometry, multiplayer room transitions
**Confidence:** HIGH (codebase verified) / MEDIUM (OSM abstraction / navmesh patterns)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** All 3 rooms are child nodes of Game.tscn (`Room1`, `Room2`, `Room3`). Active room = visible + physics enabled; inactive = hidden + collision layers disabled.
- **D-02:** Room clear trigger is all enemies dead, auto-triggered. Host checks remaining count via `$EnemySpawner` or a counter; count == 0 fires transition.
- **D-03:** Room transition: host broadcasts RPC (`@rpc("call_local", "reliable")`) — hides current room, shows next, teleports all players to new `SpawnPoints`, `queue_free()`s leftover pickups/orbs.
- **D-04:** `current_room: int` in `Game.gd` (or `GameState`) tracks which room is active. Room 3 triggers boss spawn immediately on enter.
- **D-05:** Room 2 geometry OSM-derived from Bamberg Altstadt. Streets → walkable corridor floor polygons; building footprints → `StaticBody2D` wall obstacles.
- **D-06:** Single `NavigationRegion2D` baked over Room 2 full layout. Enemy spawn points at corridor intersections and room edges.
- **D-07:** Room 2 spawn formula: `INITIAL_ENEMY_COUNT_R2 × 1.5^(loop_number - 1)` where `INITIAL_ENEMY_COUNT_R2` is 1.5× Room 1 baseline (~12 at Loop 1).
- **D-08:** Room 3 geometry OSM-derived from Burg Altenburg castle. Castle walls/towers → `StaticBody2D` boundaries; interior courtyard → walkable boss arena.
- **D-09:** Boss spawns at center of Room 3 when Room 3 becomes active. No normal enemy wave in Room 3.
- **D-10:** Room 3 has boss-fight spawn points around arena perimeter for mob swarms only.
- **D-11:** Boss baseline HP 1000 (Loop 1). Scales: `1000 × (1.0 + (loop_number - 1) × 0.25)`.
- **D-12:** 3-phase boss fight: Phase 1 (100–66% HP) slow melee charge; Phase 2 (66–33% HP) adds ranged volley (3–5 bullets spread); Phase 3 (33–0% HP) both + speed boost 1.5×.
- **D-13:** Phase transitions fire RPC notification to all clients; boss changes color per phase.
- **D-14:** Mob swarms spawn at Phase 1→2 (66%) and Phase 2→3 (33%) HP transitions. Two swarms total.
- **D-15:** Swarm composition: normal enemies + 1 elite per swarm (2 elites in Phase 3 swarm). Each elite triggers LIDAR HUD (existing `emit_hud.rpc("lidar")` pattern).
- **D-16:** Swarm count scales: `5 + (loop_number × 3)` normal + 1 elite (2 elites Phase 3 swarm). Loop 1: 8 normal + 1 elite. Loop 2: 11 normal + 1 elite. Loop 3: 14 normal + 2 elites.
- **D-17:** Boss HP == 0 → host calls `GameState.start_next_loop()` → all clients return to Room 1 (new loop, higher difficulty).

### Claude's Discretion

- Boss placeholder visual: dark rectangle ~96×96px, clearly distinct from normal (32×32) and elite (48×48) enemies.
- Boss melee charge distance and speed (Phase 1): tune for playability.
- Boss ranged projectile spread angle and speed (Phase 2): baseline from existing bullet patterns.
- Whether boss briefly pauses attacks (~2s) when mob swarm spawns at phase transition.
- Exact Room 2 and Room 3 geometry (OSM-derived, researcher/planner final say).

### Deferred Ideas (OUT OF SCOPE)

- Visible boss phase transition cutscene/animation (full-screen flash).
- Per-phase music or audio cues.
- Room 2 mid-corridor ambush trigger (scripted enemy swarm at position).
- Boss projectile element types (fire/ice boss projectiles — uses neutral projectiles in Phase 8).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ROOM-01 | Room 1 (ERBA) — open, wide space; tutorial-level enemy density; teaches movement + combat | Already exists in Game.tscn as `Room1`; Phase 8 confirms density tuning and full-run wiring |
| ROOM-02 | Room 2 (Bamberg Altstadt) — narrow corridors; higher enemy density; punishes clustering | OSM-derived geometry documented below; NavigationRegion2D bake pattern researched |
| ROOM-03 | Room 3 (Burg Altenburg) — large arena; boss fight | OSM-derived castle geometry documented below; boss spawn on room enter |
| ROOM-04 | Boss has at least 2 distinct attack phases with different behavior per phase | Boss state machine pattern documented; 3-phase design with HP thresholds |
| ROOM-05 | Random mob swarms spawn between boss attack phases (harder each loop) | Swarm spawn at phase transitions using existing `_do_spawn_enemy` pattern |
| ROOM-06 | Enemy or mob spawns during boss fight trigger LIDAR HUD indicator | Existing `GameEvents.emit_hud.rpc("lidar")` pattern; fires on every elite swarm spawn |
| ROOM-07 | All room transitions are simultaneous across all clients | `@rpc("call_local", "reliable")` pattern already established; P10 pitfall watch |
</phase_requirements>

---

## Summary

Phase 8 closes the full game loop: a 3-room run (Room 1 already exists, Rooms 2 and 3 are new) culminating in a phased boss fight. The codebase is well-prepared — all required patterns exist in `Game.gd` and can be extended directly. The largest new technical piece is the boss state machine (`Boss.gd`), which uses HP threshold checking inside `receive_damage()` to trigger phase transitions and mob swarm spawns via the existing `_do_spawn_enemy` path. Room geometry (both rooms are placeholder colored `Polygon2D` shapes with `StaticBody2D` walls) is the most time-consuming authoring task, not a technical risk.

The OSM-derived geometry for Room 2 (Bamberg Altstadt) is abstracted as a multi-corridor layout (two main corridors crossing at a central junction). Room 3 (Burg Altenburg) is a compact castle-wall enclosure with a central open courtyard. Both are designed to fit within the existing 800×600 viewport and follow the exact same child node structure as `Room1` in `Game.tscn`.

The multiplayer room transition pattern (hide/show + teleport via `@rpc("call_local", "reliable")`) is already partially present in the Phase 7 discussion and is the cleanest known approach for this Godot 4 ENet topology.

**Primary recommendation:** Extend `Game.gd` with `_transition_to_room()` and `_spawn_boss()` methods; build `Boss.gd` as a direct extension of the `Enemy.gd` pattern; author Room 2 and Room 3 geometry manually based on the OSM abstractions below.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Room transition (hide/show/teleport) | Game.gd (host) | All clients via RPC | D-03: host broadcasts call_local RPC; all peers execute simultaneously |
| Enemy count tracking (room clear) | Game.gd (host) | — | Host-authoritative; only host checks count and fires transition |
| Boss phase state machine | Boss.gd (host) | All clients via RPC (phase color change) | Boss AI runs host-only (P6 pattern); phase color change broadcast to all |
| Mob swarm spawning | Game.gd (host, via EnemySpawner) | — | Mirrors _spawn_elite_enemy pattern; call_deferred from physics callback |
| LIDAR HUD trigger on elite spawn | Game.gd (host) → GameEvents.emit_hud.rpc | All clients (CarHUD) | Existing pattern; fires once per elite spawned in swarm |
| Room geometry (walls/floor) | StaticBody2D + Polygon2D (all peers) | NavigationRegion2D (host bakes) | Geometry is static; baked navmesh applies on all peers |
| Boss HP bar (if shown) | CanvasLayer (local) | — | Existing pattern: PlayerHUD in CanvasLayer; boss bar follows same rule |
| Boss spawn on room enter | Game.gd (host, _spawn_boss) | All clients via EnemySpawner replication | Mirrors existing _spawn_elite_enemy; Boss.tscn pre-registered in EnemySpawner |

---

## Standard Stack

### Core (all already in project — no new packages)

| Asset | Version | Purpose | Why Standard |
|-------|---------|---------|--------------|
| Godot 4 NavigationRegion2D | 4.x (current project) | Navmesh baking for corridor layouts | Already used in Room1; bake_navigation_polygon() called in Game.gd _ready |
| Godot 4 StaticBody2D + CollisionShape2D | 4.x | Wall obstacles for Room 2/3 corridors and castle walls | Already used for Room1 walls (WallTop, WallBottom, WallLeft, WallRight) |
| Godot 4 Polygon2D | 4.x | Floor visual for rooms | Already used for Room1 Floor node |
| Godot 4 CharacterBody2D | 4.x | Boss base node type | Enemy.gd already uses this; Boss.gd extends same pattern |
| `@rpc("call_local", "reliable")` | Godot 4 built-in | Simultaneous room transitions | Already established in project RPC discipline (Phase 1 D-01) |
| `call_deferred` on spawner | Godot 4 built-in | Physics-safe enemy spawning in callbacks | Already used in _on_enemy_died and _spawn_elite_enemy |

### New Scenes Required

| Scene | Extends | Purpose |
|-------|---------|---------|
| `scenes/enemies/Boss.tscn` | Enemy.tscn pattern | Boss character; pre-registered in EnemySpawner |
| `scenes/projectiles/BossProjectile.tscn` | Bullet.tscn pattern | Boss ranged attack (Phase 2+); pre-registered in BulletSpawner or new BossProjectileSpawner |
| `Room2` child in Game.tscn | Node2D | Bamberg Altstadt corridor layout |
| `Room3` child in Game.tscn | Node2D | Burg Altenburg boss arena |

**No new npm/pip/external packages.** This is a pure Godot 4 GDScript phase.

---

## OSM Geographic Research

### Room 2: Bamberg Altstadt — Corridor Abstraction

[ASSUMED — derived from web search descriptions; no 1:1 OSM coordinate trace possible without direct data export]

**Real geography:** Bamberg Altstadt is a UNESCO World Heritage Site (11th century origin) with a medieval street network built across seven hills. The distinctive features relevant to game design:

- The street network is an organic medieval grid: wider main arteries (Lange Straße, Grüner Markt, Karolinenstraße) flanked by narrow side alleys and half-timbered house blocks.
- Main arteries run roughly north-south and east-west, meeting at a central market area (Grüner Markt / Maximilianplatz zone).
- The blocks between streets are dense and irregular — building footprints occupy most of the space, leaving only narrow 4–8 m corridors between them.
- The Regnitz canal arms run east–west, creating natural room boundaries.

**Game abstraction for Room 2 (800×600 viewport, placeholder geometry):**

The goal is an H-shaped or cross-shaped corridor layout that forces players to navigate narrow passages and punishes clustering.

```
Recommended Room 2 layout (placeholder — top-down, all units in px):

  +--[WallBlock]--+         +--[WallBlock]--+
  |               |         |               |
[Corridor A: 120px wide, runs top to bottom on left third]
  |               |         |               |
  +---[OPEN ZONE: central junction 200×200]--+
  |               |         |               |
[Corridor B: 120px wide, runs top to bottom on right third]
  |               |         |               |
  +--[WallBlock]--+         +--[WallBlock]--+

Full layout:
- Room bounds: 800×600 (same as Room 1)
- Left corridor: x=50 to x=170, full height (50 to 550)
- Central plaza: x=300 to x=500, y=200 to y=400  (200×200 open zone)
- Right corridor: x=630 to x=750, full height (50 to 550)
- Horizontal connecting corridor: y=270 to y=330, full width (50 to 750)
- Wall blocks fill remaining space (Polygon2D obstacle blocks + StaticBody2D collision)
- Entry (from Room 1): left edge center (x=50, y=300)
- Exit trigger (to Room 3): right edge center (x=750, y=300) — activated when enemy count == 0
- EnemySpawnPoints: 6 points at corridor intersections and block corners
```

**Wall blocks (StaticBody2D + CollisionShape2D RectangleShape2D) suggested positions:**
- Top-left block: pos (185, 100), size (115, 200) — building footprint
- Top-center block: pos (170, 50), size (130, 180) — building between corridors
- Top-right block: pos (500, 100), size (130, 200)
- Bottom-left block: pos (185, 400), size (115, 150)
- Bottom-center block: pos (170, 370), size (130, 180)
- Bottom-right block: pos (500, 400), size (130, 150)

**NavigationPolygon outline for Room 2:**
Define the walkable outline as the union of the corridor shapes. The simplest approach is to define the outline as the full room bounds (800×600) and then add obstacle outlines for each wall block — the bake algorithm carves out obstacles automatically when `parsed_geometry_type = 1` (Static Colliders) and all `StaticBody2D` nodes are children of Room2.

### Room 3: Burg Altenburg — Boss Arena Abstraction

[ASSUMED — derived from web search descriptions; no CAD/floor plan data available]

**Real geography:** Burg Altenburg sits atop the highest of Bamberg's seven hills (Räthkuppe). The castle is compact:
- Perimeter: rough oval/irregular polygon of stone walls with 2–3 wall towers and a gate+moat entrance on one side.
- Keep: a tall 33m circular/square stone tower on the high point inside the walls.
- Interior: two connected courtyards (inner courtyard near the keep, outer courtyard near the gate), small chapel, ETA Hoffmann building, Biergarten terrace.
- Overall footprint: compact enough to walk in one hour — roughly 120–150m across at real scale.

**Game abstraction for Room 3 (800×600 viewport, placeholder geometry):**

The goal is a large-ish central arena surrounded by irregular castle walls with 2–3 inset towers (which create concave pockets — tactically interesting for boss fight positioning).

```
Recommended Room 3 layout:

Outer boundary: irregular polygon approximating oval castle walls
  Approx polygon (clockwise from top-left):
    (120, 60), (680, 60), (750, 150), (760, 450), (680, 560), 
    (120, 560), (50, 450), (40, 150)

Keep tower (StaticBody2D, circular approximated as square):
  Center: (400, 220), size: 80×80 — impassable block at top-center of arena

Gate tower (StaticBody2D, narrower block at entry side):
  Entry wall gap at bottom: y=560, x=340 to x=460 (120px wide gate opening)

Two corner towers (small impassable blocks):
  Top-left: pos (90, 90), size (60×60)
  Top-right: pos (650, 90), size (60×60)

Walkable arena: the space inside the outer polygon minus the keep and towers
  Main open area: roughly 500×350px of open space
  Boss spawns at: (400, 300) — arena center

EnemySpawnPoints (for mob swarms): 8 points around the perimeter wall interior
  (160, 120), (400, 80), (640, 120), (700, 300), (640, 480), 
  (400, 520), (160, 480), (80, 300)
```

**NavigationPolygon for Room 3:**
Define the outer walkable polygon directly as a NavigationPolygon outline (the castle interior shape). Add obstacle outlines for the keep block and corner towers. The outer walls of Room 3 use `StaticBody2D` nodes positioned to match the polygon boundary — same pattern as Room 1's WallTop/WallBottom/WallLeft/WallRight but using more segments for the irregular shape.

---

## Architecture Patterns

### System Architecture Diagram

```
[Game.gd host only]
    |
    +-- _transition_to_room(next: int)
    |       hide Room{current}, show Room{next}
    |       queue_free all pickups/orbs in Room{current}
    |       teleport all players to Room{next}/SpawnPoints
    |       current_room = next
    |       if next == 3: call_deferred(_spawn_boss)
    |
    +-- _check_room_clear()   [called from _on_enemy_died]
    |       if enemies_alive == 0 and current_room < 3:
    |           _transition_to_room.rpc(current_room + 1)
    |       elif enemies_alive == 0 and boss_defeated:
    |           GameState.start_next_loop()
    |           _transition_to_room.rpc(1)   # new loop starts Room 1
    |
    +-- _spawn_boss()
    |       EnemySpawner.spawn({"type":"boss","pos":room3_center})
    |
    +-- _spawn_mob_swarm(phase: int)   [called via signal from Boss]
            count = 5 + (GameState.loop_number * 3)
            elite_count = 2 if phase == 3 else 1
            spawn count normal enemies + elite_count elites
            each elite fires GameEvents.emit_hud.rpc("lidar")

[Boss.gd — host-authoritative, extends Enemy.gd pattern]
    |
    +-- receive_damage(amount)
    |       current_hp -= amount
    |       if current_hp <= boss_hp * 0.66 and phase == 1: _enter_phase(2)
    |       if current_hp <= boss_hp * 0.33 and phase == 2: _enter_phase(3)
    |       if current_hp <= 0: _on_boss_defeated()
    |
    +-- _enter_phase(new_phase)
    |       phase = new_phase
    |       _notify_phase_change.rpc(new_phase)   # color change on all clients
    |       get_tree().get_root().get_node("Game")._spawn_mob_swarm(new_phase)
    |
    +-- _on_boss_defeated()
            died.emit(global_position)   # triggers GameState.start_next_loop via Game.gd
```

### Recommended Project Structure (new files only)

```
scenes/
├── enemies/
│   ├── Boss.tscn           # new — boss character scene
│   └── Boss.gd             # new — boss AI state machine
├── projectiles/
│   └── BossProjectile.tscn # new — boss ranged bullet (can reuse Bullet.tscn with diff stats)
scenes/
└── Game.tscn               # extend: add Room2, Room3 child nodes

autoloads/
└── GameState.gd            # extend: add current_room: int = 1 (or keep in Game.gd)
```

### Pattern 1: Room Hide/Show Transition (ROOM-07, D-01 through D-04)

**What:** RPC broadcast that simultaneously toggles room visibility and physics, then teleports players.
**When to use:** Whenever `current_room` advances (Room 1→2, Room 2→3, Room 3→1 on loop reset).

```gdscript
# In Game.gd — host calls this, call_local fires it on all peers simultaneously
@rpc("authority", "call_local", "reliable")
func _transition_to_room(next_room: int) -> void:
    # Hide and disable current room
    var old_name := "Room%d" % current_room
    var old_room := get_node_or_null(old_name)
    if old_room:
        old_room.visible = false
        # Disable all StaticBody2D collision in old room
        for body in old_room.find_children("*", "StaticBody2D", true, false):
            body.set_collision_layer_value(1, false)
            body.set_collision_mask_value(1, false)
    
    # Show and enable new room
    var new_name := "Room%d" % next_room
    var new_room := get_node_or_null(new_name)
    if new_room:
        new_room.visible = true
        for body in new_room.find_children("*", "StaticBody2D", true, false):
            body.set_collision_layer_value(1, true)
    
    current_room = next_room
    
    # Teleport all players to new spawn points
    var spawn_points := new_room.get_node_or_null("SpawnPoints")
    if spawn_points:
        var pts := spawn_points.get_children()
        var idx := 0
        for p in get_tree().get_nodes_in_group("players"):
            if idx < pts.size():
                p.global_position = pts[idx].global_position
            idx += 1
    
    # Host-only: queue_free leftover pickups/orbs from old room
    # (pickups live under PickupSpawner which is NOT room-specific — purge all)
    if multiplayer.is_server():
        for pickup in $PickupSpawner.get_children():
            pickup.queue_free()
        # Bake navmesh for new room
        var nav := new_room.get_node_or_null("NavigationRegion2D")
        if nav:
            nav.bake_navigation_polygon(false)
        # If entering Room 3, spawn boss after one frame (physics settle)
        if next_room == 3:
            _spawn_boss.call_deferred()
```

[ASSUMED — code derived from project patterns, not verified against Godot 4 official docs this session]

### Pattern 2: Boss State Machine with HP Threshold Phases (ROOM-04, D-12)

**What:** Boss tracks phase (1/2/3) as an int, checks thresholds in `receive_damage()`, fires RPC on phase change.
**When to use:** Boss HP threshold crossed.

```gdscript
# Boss.gd — extends "res://scenes/enemies/Enemy.gd"
var phase: int = 1
var _boss_max_hp: int = 1000
var _attack_timer: float = 0.0
var _charge_cooldown: float = 2.5    # Phase 1
var _shoot_cooldown: float = 1.8     # Phase 2+
var _charge_speed: float = 200.0     # Phase 1
var _phase2_speed: float = 110.0     # Phase 2 movement
var _phase3_speed: float = 165.0     # Phase 3 = 1.5× Phase 2

func _ready() -> void:
    super._ready()
    # D-11: scale HP by loop
    var mult: float = 1.0 + (GameState.loop_number - 1) * 0.25
    _boss_max_hp = int(1000 * mult)
    MAX_HP = _boss_max_hp
    current_hp = MAX_HP
    # Visual: 96×96 dark rectangle
    if has_node("Sprite"):
        $Sprite.color = Color(0.15, 0.05, 0.05, 1)
        $Sprite.offset_left  = -48.0; $Sprite.offset_top    = -48.0
        $Sprite.offset_right = 48.0;  $Sprite.offset_bottom = 48.0

func receive_damage(amount: int) -> void:
    if not is_multiplayer_authority(): return
    current_hp -= amount
    current_hp = max(current_hp, 0)
    # Phase transition checks (only advance forward)
    if phase == 1 and current_hp <= _boss_max_hp * 0.66:
        _enter_phase(2)
    elif phase == 2 and current_hp <= _boss_max_hp * 0.33:
        _enter_phase(3)
    if current_hp <= 0:
        died.emit(global_position)
        queue_free()

func _enter_phase(new_phase: int) -> void:
    phase = new_phase
    _notify_phase_change.rpc(new_phase)
    # Spawn mob swarm (D-14): call via Game node
    var game := get_tree().get_root().get_node_or_null("Game")
    if game and game.has_method("_spawn_mob_swarm"):
        game._spawn_mob_swarm.call_deferred(new_phase)

@rpc("authority", "call_local", "reliable")
func _notify_phase_change(new_phase: int) -> void:
    # Visual color change on all peers
    if has_node("Sprite"):
        match new_phase:
            2: $Sprite.color = Color(0.4, 0.05, 0.05, 1)   # dark red
            3: $Sprite.color = Color(0.6, 0.0, 0.0, 1)      # bright red
```

[ASSUMED — derived from project patterns; not verified against Godot official docs this session]

### Pattern 3: Mob Swarm Spawn at Phase Transition (ROOM-05, ROOM-06, D-14 through D-16)

**What:** Host spawns N normal + K elite enemies when boss phase changes. Each elite fires LIDAR.
**When to use:** Boss calls `game._spawn_mob_swarm(phase)`.

```gdscript
# In Game.gd — host-only (called via call_deferred from Boss._enter_phase)
func _spawn_mob_swarm(boss_phase: int) -> void:
    if not multiplayer.is_server(): return
    var swarm_points := $Room3/EnemySpawnPoints.get_children()
    if swarm_points.is_empty(): return
    
    var normal_count: int = 5 + (GameState.loop_number * 3)
    var elite_count: int = 2 if boss_phase == 3 else 1
    
    # Spawn normal enemies
    for i in range(normal_count):
        var pos: Vector2 = swarm_points[randi() % swarm_points.size()].global_position
        $EnemySpawner.spawn.call_deferred({"pos": pos})  # LIDAR NOT fired for normal
    
    # Spawn elite enemies — each fires LIDAR (ROOM-06, D-15)
    for _i in range(elite_count):
        var pos: Vector2 = swarm_points[randi() % swarm_points.size()].global_position
        $EnemySpawner.spawn.call_deferred({"type": "elite", "pos": pos})
        GameEvents.emit_hud.rpc("lidar")  # one LIDAR per elite (existing pattern)
```

[ASSUMED — derived from project patterns]

### Pattern 4: Enemy Count Tracking for Room Clear (ROOM-02, D-02)

**What:** Host tracks alive enemy count per room; when 0, triggers room transition.
**When to use:** After each `_on_enemy_died()`.

Two approaches — research recommends option A:

**Option A — Count via group (simpler, no counter drift):**
```gdscript
func _check_room_clear() -> void:
    if not multiplayer.is_server(): return
    if current_room == 3: return  # Room 3 clears on boss death, not enemy count
    var alive := get_tree().get_nodes_in_group("enemies")
    # Filter enemies only in the active room
    var active_room := get_node_or_null("Room%d" % current_room)
    if active_room == null: return
    var room_enemies := alive.filter(func(e): 
        return active_room.is_ancestor_of(e) or not e.get_parent().is_inside_tree()
    )
    if room_enemies.is_empty():
        _transition_to_room.rpc(current_room + 1)
```

Note: EnemySpawner in the current codebase spawns enemies under itself (not under the room node), so enemies from Room 1 and Room 2 share the same group. The cleanest approach is to filter by checking if the enemy's `position` is within the active room's viewport bounds, or to add a `room_id` property to each enemy at spawn time.

**Option B — Explicit counter (add `_room_enemy_count: int` to Game.gd):**
Increment in `_spawn_enemies` / `_spawn_mob_swarm`, decrement in `_on_enemy_died`. More fragile if enemies are freed unexpectedly but avoids group scan overhead.

**Recommendation: Option A (group + `room_id` tag approach)** — add `"room_id": current_room` to spawn data dict, store as `enemy.room_id` property, filter group by `room_id == current_room`.

### Anti-Patterns to Avoid

- **Do NOT use `SceneTree.change_scene_to_file()` for room transitions.** This would disconnect all multiplayer state. D-01 locked: hide/show in same scene.
- **Do NOT run boss AI on clients.** Boss extends Enemy.gd which already has `set_physics_process(is_multiplayer_authority())` in `_ready()`. Do not override this.
- **Do NOT use `rpc_id` for room transition.** Must use `@rpc("call_local")` so the host also executes the transition simultaneously with clients.
- **Do NOT put pickups under a room node.** Current codebase puts them under `$PickupSpawner` at Game root. Purge on transition by iterating `$PickupSpawner.get_children()`.
- **Do NOT spawn boss in `_ready()` of Room3.** Room3 node exists but is hidden; boss spawns only when `_transition_to_room(3)` fires, via `call_deferred`.
- **Do NOT forget to pre-register Boss.tscn and BossProjectile.tscn in EnemySpawner / BulletSpawner BEFORE the boss fight becomes testable (P7).**

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Navmesh for corridors | Custom pathfinding grid | NavigationRegion2D bake (existing in Room1) | bake_navigation_polygon() handles complex polygon outlines + static collider carving automatically |
| Bullet spread volley | Custom spread angle calculation | Array of direction vectors fed to existing BulletSpawner | Existing `_do_spawn_bullet` already handles position+direction; loop over spread angles |
| Phase-gated attack timers | New Timer nodes per phase | Single `_attack_timer` float in `_physics_process`, reset on phase change | Fewer nodes, no scene tree dependency; mirrors existing enemy tick patterns |
| Boss health bar replication | Syncing boss HP via new property | Boss.current_hp already synced via MultiplayerSynchronizer (inherited from Enemy pattern) | Enemy.gd already declares `current_hp` as synced var; Boss inherits this |
| Room clear detection | Signal chain from every enemy | `get_tree().get_nodes_in_group("enemies")` count check in `_on_enemy_died` | Group is maintained by Enemy._ready() add_to_group; no additional wiring |

**Key insight:** Every required boss and room feature maps to an existing pattern in the codebase. There is no need for new architectural primitives — only extensions of `Game.gd`, `Enemy.gd`, and existing spawner patterns.

---

## Common Pitfalls

### Pitfall 1: P7 — Boss/Swarm Scenes Not Pre-Registered (Critical)
**What goes wrong:** `EnemySpawner.spawn({"type":"boss",...})` crashes or silently fails because Boss.tscn is not in the spawnable list.
**Why it happens:** Godot MultiplayerSpawner requires explicit `add_spawnable_scene()` calls before any `spawn()` call for that scene.
**How to avoid:** In `Game.gd._ready()`, add before any boss fight is possible:
```gdscript
$EnemySpawner.add_spawnable_scene("res://scenes/enemies/Boss.tscn")
```
Also pre-register BossProjectile.tscn in whatever spawner fires boss bullets.
**Warning signs:** `spawn() called with data that didn't match any spawnable scene` error in output.

### Pitfall 2: P10 — Room Transition Desync
**What goes wrong:** Host transitions to Room 2 before clients have finished the call; clients see Room 1 geometry but Room 2 enemies.
**Why it happens:** Using `rpc_id` or `call_remote` instead of `call_local` means host executes immediately but remote peers lag by one network round-trip.
**How to avoid:** `@rpc("authority", "call_local", "reliable")` guarantees host AND clients execute in the same logical frame on the host and immediately when the packet arrives on clients.
**Warning signs:** Players falling through geometry, enemies spawning in invisible rooms.

### Pitfall 3: NavigationRegion2D Bake Over Complex Polygon
**What goes wrong:** Baking a navmesh over Room 2's corridor layout produces "star" artifacts or fails silently, leaving enemies unable to pathfind.
**Why it happens:** Too many overlapping StaticBody2D edges, or the NavigationPolygon outline doesn't encompass all walkable area.
**How to avoid:** 
- Set `parsed_geometry_type = 1` (Static Colliders) on Room2's NavigationRegion2D so StaticBody2D walls are automatically subtracted.
- Define the NavigationPolygon outline as the full room bounding rect (800×600 minus wall border), not the corridor shapes — the bake will carve out wall colliders.
- Use simplified rectangular wall blocks (avoid circles or high-vertex shapes).
- Call `bake_navigation_polygon(false)` via `call_deferred` after the room becomes visible.
**Warning signs:** NavigationAgent2D never reaches target, or takes straight-line paths through walls.

### Pitfall 4: Boss Phase Transition Double-Fires
**What goes wrong:** Boss fires `_enter_phase(2)` twice if two bullets land on the same frame that crosses the 66% threshold.
**Why it happens:** `receive_damage()` is called once per bullet hit; multiple hits in one frame can both pass the threshold check before the phase int is updated.
**How to avoid:** Check `phase == 1` (or `phase == 2`) BEFORE the threshold, not just the HP value. The pattern in the code above already does this correctly (`if phase == 1 and current_hp <= boss_hp * 0.66`).

### Pitfall 5: Enemy Count Including Boss in Room Clear Check
**What goes wrong:** Room 3 never clears because the boss is in the "enemies" group and its death doesn't trigger the right path.
**Why it happens:** `get_nodes_in_group("enemies")` returns the boss too; if boss death fires `_on_enemy_died` before the group is updated, count is still > 0.
**How to avoid:** Room 3 clear is boss-death-specific — use a `_on_boss_died()` signal handler separate from `_on_enemy_died()`. Connect `boss.died.connect(_on_boss_died)` instead of the generic `_on_enemy_died`. `_on_boss_died` calls `GameState.start_next_loop()` and `_transition_to_room.rpc(1)`.

### Pitfall 6: Collision Layer Mismatch After Room Switch
**What goes wrong:** After transitioning to Room 2, players clip through Room 2 walls because collision layers were disabled on Room 1 walls but Room 2 walls use different layer values.
**Why it happens:** The `set_collision_layer_value()` call targets specific layer indices; if Room 2 walls are on layer 2 instead of layer 1, the enable call misses them.
**How to avoid:** Author all room wall StaticBody2D nodes with identical collision layers (layer 1, same as Room 1 walls). The transition function's generic loop over `find_children("*", "StaticBody2D")` then works correctly for all rooms.

### Pitfall 7: Pickup Spawner Under Game Root (not under room)
**What goes wrong:** Pickups from Room 1 persist visibly in Room 2 because the pickup spawner is not a child of the room node.
**Why it happens:** `$PickupSpawner` is a direct child of Game, so pickups' positions are in Game's coordinate space, not the room's. They remain visible after the room is hidden because the room's `visible = false` doesn't affect siblings.
**How to avoid:** `_transition_to_room` must explicitly `queue_free()` all children of `$PickupSpawner` and `$EnemySpawner` (the enemies from the cleared room) before showing the new room.

---

## NavigationRegion2D: Complex Polygon Technical Notes

[VERIFIED: Godot docs via web search cross-reference]

- `NavigationRegion2D` with `parsed_geometry_type = 1` (Static Colliders) scans for `StaticBody2D` children (or group-matched nodes) and automatically subtracts them from the walkable area during bake.
- For corridor layouts, define the `NavigationPolygon` outline as the **full room bounding rectangle** (not the individual corridor shapes). The bake then carves holes where StaticBody2D wall blocks exist. This is simpler than manually defining L-shaped or T-shaped polygons.
- `agent_radius = 12.0` is already set in the project (visible in Game.tscn NavigationPolygon_1). Keep the same value for Room 2 and Room 3.
- The bake must be called AFTER the room's StaticBody2D nodes are added to the scene tree and AFTER the room becomes visible. Use `call_deferred("bake_navigation_polygon", false)` in `_transition_to_room`.
- Per Godot forum research: "too many edges" in obstacle shapes (e.g. circular colliders) cause star artifacts. All Room 2 and Room 3 wall blocks should use `RectangleShape2D` only.
- NavigationAgent2D layer bits must match NavigationRegion2D layer bits. Since Room 2 and Room 3 use the same navmesh layer as Room 1, no changes needed to NavigationAgent2D on Enemy nodes.

---

## Boss Design Specification (Pre-Planning Document)

This section documents the design decisions needed by planners before writing tasks.

### Boss Stats

| Stat | Loop 1 | Loop 2 | Loop 3 |
|------|--------|--------|--------|
| Max HP | 1000 | 1250 | 1500 |
| Phase 1 threshold | 667 HP (66%) | 834 HP | 1000 HP |
| Phase 2 threshold | 333 HP (33%) | 417 HP | 500 HP |
| Phase 1 speed | 80 px/s (same as normal enemy) | 80 px/s | 80 px/s |
| Phase 2 speed | 110 px/s | 110 px/s | 110 px/s |
| Phase 3 speed | 165 px/s (1.5× Phase 2) | 165 px/s | 165 px/s |
| Contact damage | 25 (2.5× normal) | 31 | 38 |

### Boss Attack Pattern Summary

| Phase | Behavior | Melee Charge | Ranged |
|-------|----------|-------------|--------|
| 1 | Chase + charge | Every 2.5s, rush toward nearest player at 300 px/s for 0.8s | None |
| 2 | Chase + charge + ranged | Same as Phase 1, but interleaved with ranged | Every 1.8s: 4 bullets at ±20°, ±40° spread toward target |
| 3 | Both + speed boost | Charge interval 1.8s (same as ranged), 300 px/s charge | Every 1.2s: 5 bullets at ±15°, ±30°, 0° |

### Boss Projectile

- Reuse `Bullet.tscn` with `owner_peer_id = -1` (no player owner, so no friendly-fire issue).
- Or create `BossProjectile.tscn` with 1.5× size, same damage as boss CONTACT_DAMAGE × 0.6 (~15 per bullet).
- Spawn via new `BossProjectileSpawner` (child of Game, same pattern as BulletSpawner) OR fire via Game's existing `BulletSpawner` with a `"boss_bullet": true` key in data.

### Mob Swarm Count Table

| Loop | Phase 2 Swarm | Phase 3 Swarm |
|------|---------------|---------------|
| 1 | 8 normal + 1 elite | 8 normal + 2 elites |
| 2 | 11 normal + 1 elite | 11 normal + 2 elites |
| 3 | 14 normal + 1 elite | 14 normal + 2 elites |

---

## Existing Codebase: Integration Points

All findings verified by reading live source files.

### Game.gd — What Needs Adding [VERIFIED: codebase read]

- `var current_room: int = 1` — new state variable
- `var _enemy_count: int = 0` — optional if using group-count approach (can skip with option A)
- `_transition_to_room(next: int)` — new `@rpc("authority", "call_local", "reliable")` method
- `_spawn_boss()` — new host-only method; calls `$EnemySpawner.spawn({"type":"boss","pos":...})`
- `_spawn_mob_swarm(phase: int)` — new host-only method
- `_on_boss_died(pos: Vector2)` — new signal handler; calls `GameState.start_next_loop()` + `_transition_to_room.rpc(1)`
- `_check_room_clear()` — called from `_on_enemy_died`; skip if `current_room == 3`
- Modify `_on_enemy_died`: check room clear after each death; also `_check_room_clear()`
- Add `$EnemySpawner.add_spawnable_scene("res://scenes/enemies/Boss.tscn")` in `_ready()`
- Add spawnable registration for BossProjectile

### Game.gd — What Must NOT Change [VERIFIED: codebase read]

- `_spawn_enemies()` currently hardcodes `$Room1/EnemySpawnPoints` — must be updated to use `$Room{current_room}/EnemySpawnPoints` pattern, OR keep separate `_spawn_enemies_room2()` method.
- `_bake_navigation()` currently hardcodes `"Room1/NavigationRegion2D"` — must be made generic or called per room.
- `_do_spawn_enemy(data)` already handles `"elite"` type dispatch. Add `"boss"` type: `var scene = BOSS_SCENE if data.get("type","") == "boss" else ...`

### GameState.gd — What Needs Adding [VERIFIED: codebase read]

- `start_next_loop()` already implemented (line 50+). No changes needed for the loop start.
- Optionally add `current_room: int = 1` here if it needs to sync to clients. Otherwise keep in `Game.gd`.

### _spawn_all_players — Room-Aware Teleport [VERIFIED: codebase read]

Current code at line 151: `var spawn_points := $Room1/SpawnPoints.get_children()`. This will need to be generalized to `$Room{current_room}/SpawnPoints` when `start_next_loop()` resets back to Room 1.

### Pre-Registration Checklist (P7) [ASSUMED — not yet written]

Must be in `Game.gd._ready()` before any boss fight:
- `$EnemySpawner.add_spawnable_scene("res://scenes/enemies/Boss.tscn")`
- Boss projectile scene registration (in BulletSpawner or new BossProjectileSpawner)
- Room 2 and Room 3 don't add new enemy types — `Enemy.tscn` and `EliteEnemy.tscn` already registered.

---

## Environment Availability

Step 2.6: All dependencies are Godot 4 built-in (no external tools required). OSM data is abstracted manually into placeholder geometry — no `osmium`, Python, or QGIS toolchain required. No environment availability check needed.

---

## Validation Architecture

No test framework is configured in this project (pure Godot 4 game, no GUT or similar). All validation is manual/UAT.

### Phase Requirements → Manual Verification Map

| Req ID | Behavior | Verification Method |
|--------|----------|---------------------|
| ROOM-01 | Room 1 still functions in full-run flow | Solo: launch, play through Room 1, enemies spawn, kill all, transition fires |
| ROOM-02 | Room 2 corridors block clustering; higher density | 2-player: both enter Room 2, verify wall collision, count ~12 enemies |
| ROOM-03 | Room 3 is large arena, boss spawns on enter | Solo: enter Room 3, boss appears at center |
| ROOM-04 | Boss exhibits 2+ distinct attack phases | Solo: reduce boss HP to <66% and <33%, observe behavior change + color change |
| ROOM-05 | Mob swarms spawn between boss phases | Solo: trigger Phase 2 (66% HP), verify swarm appears |
| ROOM-06 | LIDAR fires on mob swarm elite spawn | Solo: trigger phase transition, verify LIDAR indicator lights on HUD |
| ROOM-07 | Transitions simultaneous | 2-player: both see Room change at same frame (visual check) |

---

## Security Domain

No authentication, no network security, no external data, no user input validation beyond existing RPC guards. `security_enforcement: false` applies — existing RPC guard patterns (any_peer + is_server() guard, authority checks) are inherited and sufficient.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Room 2 corridor layout (H-shape with central plaza) matches Bamberg Altstadt spirit | OSM Research — Room 2 | Low; geometry is placeholder, can be reshaped without code changes |
| A2 | Room 3 outer polygon matches Burg Altenburg castle footprint | OSM Research — Room 3 | Low; geometry is placeholder, castle shape is approximate |
| A3 | Boss contact damage = 25 (2.5× normal) is balanced | Boss Design | Medium; may need playtesting adjustment — trivially tunable constant |
| A4 | BossProjectile can reuse Bullet.tscn with different data keys | Pattern 2 code | Medium; Bullet.gd may not support `owner_peer_id = -1` gracefully — may need new scene |
| A5 | `find_children("*", "StaticBody2D", true, false)` works to enumerate all wall bodies per room | Transition pattern | Medium; recursive=true parameter syntax may differ in Godot 4.x — verify against docs |
| A6 | `get_tree().get_root().get_node_or_null("Game")` resolves correctly from Boss.gd | Boss pattern | Low; Game node is root child — path is reliable in this project structure |
| A7 | NavigationPolygon outline = full room rect + bake carves StaticBody2D (not manual corridor shapes) | Navmesh pattern | Medium; verify by baking Room 2 in editor before committing layout |
| A8 | Eliminating ALL enemies (including normally-spawning ones during Room 2) triggers transition — boss room should be boss-only | Room clear logic | Low; D-09 locks Room 3 to boss-only; Room 2 clear is standard enemy-count check |

---

## Open Questions

1. **BossProjectile: reuse Bullet.tscn or new scene?**
   - What we know: `Bullet.gd` has `owner_peer_id` which determines friendly-fire. Boss bullets don't belong to any player peer.
   - What's unclear: Whether `owner_peer_id = -1` (or 0) correctly bypasses all player-friendly-fire checks in `Bullet.gd`.
   - Recommendation: Read `Bullet.gd` before planning; if player check is `if owner_peer_id == body.peer_id: return`, then setting it to -1 works. If the check is `if owner_peer_id > 0 and owner_peer_id == body.peer_id`, also works. Create `BossProjectile.tscn` only if `Bullet.tscn` cannot be cleanly repurposed.

2. **Where does `current_room` live — Game.gd or GameState.gd?**
   - What we know: D-04 says "in `Game.gd` (or `GameState`)". GameState syncs to clients via MultiplayerSynchronizer.
   - What's unclear: Does the transition RPC need clients to know `current_room`? If clients only respond to the transition RPC (not poll `current_room` independently), Game.gd is fine.
   - Recommendation: Keep in `Game.gd` — simpler, not needed by any client-side code today.

3. **Enemy count tracking: group filter by `room_id` or by position bounds?**
   - What we know: Current `$EnemySpawner` spawns enemies under itself (not under the room node), so group membership doesn't indicate which room.
   - Recommendation: Add `room_id` property to spawn data dict (`{"pos": pos, "room_id": current_room}`), store on enemy node, filter group by `room_id`. This is the clearest approach.

---

## Sources

### Primary (HIGH confidence — codebase verified)
- `scenes/Game.gd` — spawner patterns, RPC discipline, enemy spawn, elite spawn, room node structure
- `scenes/Game.tscn` — Room1 child node layout, NavigationPolygon shape, wall StaticBody2D structure
- `scenes/enemies/Enemy.gd` — receive_damage pattern, take_damage, P6 host-only AI guard
- `scenes/enemies/EliteEnemy.gd` — extension pattern, stat override in _ready, visual size
- `autoloads/GameState.gd` — start_next_loop(), loop_number, revives_used
- `autoloads/GameEvents.gd` — emit_hud RPC pattern

### Secondary (MEDIUM confidence — web search)
- [Godot NavigationPolygon docs](https://docs.godotengine.org/en/stable/classes/class_navigationpolygon.html) — bake geometry type options
- [Godot forum: baking navigation polygon](https://forum.godotengine.org/t/help-with-baking-a-navigation-polygon-please/61793) — complex polygon corridor pitfalls
- [Altenburg Castle — Bamberg Tourismus](https://en.bamberg.info/poi/altenburg_castle-4647/) — castle layout description
- [Visiting Altenburg — WanderInGermany](https://www.wanderingermany.com/visiting-the-altenburg-bamberg-castle-germany/) — courtyard, gate, towers, moat, compact layout
- [Bamberg Altstadt — UNESCO](https://whc.unesco.org/en/list/624/) — medieval street network character
- [Bamberg Wikipedia](https://en.wikipedia.org/wiki/Bamberg) — 7-hill layout, canal arms, street density

### Tertiary (LOW confidence — training knowledge, not verified this session)
- Boss state machine phase pattern (general GDScript game dev pattern)
- H-shaped corridor abstraction for Bamberg Altstadt (derived from street character description, not coordinate data)

---

## Metadata

**Confidence breakdown:**
- Standard stack (Godot built-ins): HIGH — all verified in live codebase
- Room geometry (OSM abstraction): MEDIUM — web search confirmed geographic character; exact coordinates are [ASSUMED]
- Boss state machine: MEDIUM — pattern derived from existing Enemy.gd; code examples are [ASSUMED] pending Godot API verification
- Navmesh corridor baking: MEDIUM — confirmed via Godot docs and forum sources
- Room transition RPC pattern: HIGH — pattern established in Phase 1 and consistent with all prior phases

**Research date:** 2026-06-22
**Valid until:** 2026-08-22 (stable Godot 4 APIs; OSM geometry is timeless)
