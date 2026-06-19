# Phase 7: CarHUD, Loop Timer & Difficulty Scaling - Research

**Researched:** 2026-06-19
**Domain:** Godot 4 multiplayer UI (CanvasLayer HUD), RPC broadcast, enemy variants, loop/difficulty state
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** CarHUD is a single global CanvasLayer added as a child of Game.tscn — not per-player. One panel for all clients.
**D-02:** Panel positioned as a right-side vertical strip, anchored to the right edge. 200px wide, full viewport height. New `CarHUD.tscn` scene instantiated in Game.tscn at startup.
**D-03:** 5 active indicators (V2X removed): AC ❄️ COLD, ENGINE 🔥 OVERHEAT, SEAT MASSAGE 🌿 ACTIVE, SUSPENSION ⚡ IMPACT, LIDAR 🔴 OBJECT DETECTED.
**D-04:** Indicator idle = dark/grey StyleBoxFlat; active = bright per-indicator StyleBoxFlat. Labels include emoji exactly as in requirements.
**D-05:** Each indicator holds lit for 2 seconds then fades 0.5 seconds (Tween). Each indicator manages its own tween independently.
**D-06:** Loop number display on CarHUD panel: "Loop: N" label at top. Reads from `GameState.loop_number`.
**D-07:** `GameEvents.emit_hud(event_name: String)` becomes `@rpc("authority", "call_local", "reliable")`. Host calls → all peers receive → local CarHUD lights up matching indicator.
**D-08:** All existing `emit_hud()` callers are already host-guarded — they work without change.
**D-09:** SUSPENSION (HUD-06) fires when a player takes 15 or more damage in a single hit, checked in `Player.receive_damage()`.
**D-10:** LIDAR (HUD-07) fires only when an elite enemy spawns — not for normal enemy spawns.
**D-11:** V2X (HUD-08) removed from Phase 7 scope entirely.
**D-12:** Elite enemy: 2× base HP, 1.5× base damage, larger visual, low random frequency spawn.
**D-13:** Elite enemy spawn: host timer fires every 45–90 seconds (random interval). One elite per trigger at a random spawn point. Triggers `GameEvents.emit_hud("lidar")`.
**D-14:** Elite enemy is a separate scene (`EliteEnemy.tscn`) or reuses `Enemy.tscn` with different stats — planner decides based on Enemy.gd structure. Must be pre-registered in EnemySpawner.
**D-15:** No visible countdown timer. LOOP-01 removed.
**D-16:** `GameState.loop_number` initialized to 1 at game start. Displayed as "Loop: N" on CarHUD.
**D-17:** Phase 7 provides hook point: `GameState.start_next_loop()` — increments `loop_number`, resets `revives_used`, applies difficulty multipliers. Phase 8 calls this after boss defeat.
**D-18:** LOOP-06 carry-over is already handled by `_broadcast_game_over` reset path — no new logic needed.
**D-19:** Difficulty scaling per loop:
  - HP: `base_HP × (1.0 + (loop_number - 1) × 0.25)`
  - Damage: same multiplier as HP
  - Spawn count: `INITIAL_ENEMY_COUNT × 1.5^(loop_number - 1)`, rounded
  - XP per orb: `5 × (1.0 + (loop_number - 1) × 0.25)`, rounded
**D-20:** Scaling applied at spawn time, not retroactively.
**D-21:** Multipliers computed from `GameState.loop_number` — no stored multiplier vars.
**D-22:** Revive limit: check `GameState.revives_used.get(target_id, 0) >= 1` before completing revive. After revive: increment `revives_used[target_id]`. `start_next_loop()` clears `revives_used = {}`.

### Claude's Discretion

- Elite enemy exact visual: suggest larger ColorRect, distinct color — dark red or purple
- Elite enemy exact base stats: suggest 40 HP base vs 20 for normal; planner tunes from there
- Elite enemy spawn timer exact randomization: 45–90s range; planner implements with randf_range
- Whether elite enemy drops a car-part pickup at higher rate than normal enemies
- CarHUD panel exact dimensions: suggest 200px wide, full viewport height
- Loop: N label position within the panel (top or bottom of the indicator list)
- Whether LIDAR indicator uses same fade pattern or stays lit longer

### Deferred Ideas (OUT OF SCOPE)

- V2X auto-trigger indicator — removed from Phase 7 scope
- Visible 15-minute countdown timer (LOOP-01) — removed by user decision
- LIDAR for all enemy spawns — only elite triggers LIDAR; mob swarms during boss fight are Phase 8 (ROOM-06)
- Cooldown reduction stat boost (Game.gd line 432 `# TODO Phase 7`) — evaluate but likely defer
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HUD-01 | Car HUD side panel always visible on all players' screens | CanvasLayer global scene in Game.tscn; verified in existing code |
| HUD-02 | Panel contains AC, ENGINE, SEAT MASSAGE, SUSPENSION, LIDAR labeled boxes | 5-indicator CarHUD.tscn node inventory (V2X removed per D-11) |
| HUD-03 | Ice ability → "AC ❄️ COLD" lights up | `emit_hud("ac")` already called from `request_ice_trail()` in Game.gd line 538 |
| HUD-04 | Fire ability → "ENGINE 🔥 OVERHEAT" lights up | `emit_hud("engine")` already called from `_fire_burst()` in Player.gd line 306 |
| HUD-05 | Earth healing → "SEAT MASSAGE 🌿 ACTIVE" lights up | `emit_hud("seat_massage")` already called twice in `_tick_earth_effects()` in Game.gd |
| HUD-06 | Significant hit → "SUSPENSION ⚡ IMPACT" lights up | Add check in `Player.receive_damage()` — D-09 details threshold and emit site |
| HUD-07 | Enemy spawns → "LIDAR 🔴 OBJECT DETECTED" lights up | Fires only on elite enemy spawn (D-10); not for normal replacements |
| HUD-08 | V2X random interval trigger | REMOVED — out of scope per D-11 |
| HUD-09 | Each indicator fades out after seconds | 2.0s hold + 0.5s tween fade per D-05; per-indicator independent Tween |
| HUD-10 | HUD event broadcasts via RPC | `emit_hud` gets `@rpc("authority","call_local","reliable")` per D-07 |
| LOOP-01 | Visible 15-minute countdown | REMOVED per D-15 |
| LOOP-02 | Room clear → simultaneous transition | Out of scope for Phase 7 — Phase 8 owns room transitions |
| LOOP-03 | Run ends on boss defeat or timer | Phase 8 calls `start_next_loop()`; Phase 7 provides the hook |
| LOOP-04 | Each loop increases enemy HP, damage, spawn density | D-19 scaling formulas; applied at spawn time per D-20 |
| LOOP-05 | Loop number visible to all players | "Loop: N" label on CarHUD, reads `GameState.loop_number` per D-06 |
| LOOP-06 | Weapons/XP/evolution carry over within session | Already handled by `_broadcast_game_over` reset path per D-18 |
| HLTH-07 | Revived at most once per loop; resets at loop end | D-22: check/increment `revives_used` dict in `attempt_revive()`; reset in `start_next_loop()` |
</phase_requirements>

---

## Summary

Phase 7 is a pure GDScript integration phase for a Godot 4 multiplayer roguelike — no third-party packages, no npm, no build systems. All work is surgical modification of existing `.gd` files and creation of two new scenes (`CarHUD.tscn` and `EliteEnemy.tscn`). The phase has unusually rich prior context: the CONTEXT.md provides exact method signatures, line numbers, and formulas, and the UI-SPEC.md provides exact color values and node tree structure. Nearly every implementation decision is already locked.

The three pillars of this phase are: (1) converting `GameEvents.emit_hud()` from a local signal to a network-synced RPC call and building the CarHUD panel that listens to it; (2) adding a second elite enemy type with a host-side timer trigger and LIDAR HUD connection; and (3) wiring difficulty scaling at enemy spawn time using `GameState.loop_number`, initializing that state, and adding the revive-once-per-loop gate to `attempt_revive()`.

All five HUD event emitters (`emit_hud("ac")`, `emit_hud("engine")`, `emit_hud("seat_massage")`, `emit_hud("suspension")`, `emit_hud("lidar")`) are either already in the codebase at exact known locations or require a single additional emit call. The planner should treat this as a high-confidence integration task with well-defined file and line touchpoints.

**Primary recommendation:** Follow the CONTEXT.md decisions exactly. All architectural choices are locked; the planner should focus on wave structure (file creation order) and explicit code touchpoints rather than design exploration.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| CarHUD indicator display | Frontend/UI (CanvasLayer) | — | Pure visual; CanvasLayer draws above game world on all clients |
| HUD event broadcast | Network (RPC on autoload) | Frontend/UI | `emit_hud` RPC on GameEvents fires hud_event signal → UI reacts |
| SUSPENSION trigger | Backend (Player.gd on owning peer) | Network (emit via host) | Damage received on owning peer; emit guarded by `is_server()` |
| LIDAR trigger | Backend (Game.gd host timer) | Network (emit via host) | Elite spawn is host-authoritative; emit fires on spawn |
| Elite enemy AI | Backend (Enemy AI on host only) | Replication (MultiplayerSpawner) | P6 pattern: `set_physics_process(is_multiplayer_authority())` |
| Difficulty scaling | Backend (GameState + spawn time) | — | Applied in `_do_spawn_enemy()` reading `GameState.loop_number` |
| Loop number state | Backend (GameState autoload) | Frontend/UI (CarHUD polls it) | GameState is host-authoritative; CarHUD reads on all peers |
| Revive limit gate | Backend (Game.gd `attempt_revive()`) | State (GameState dict) | Host-only revive validation path already in place |
| XP scaling per loop | Backend (XpOrb `_request_collect()`) | State (GameState.loop_number) | Scaling computed inline at collection time |

---

## Standard Stack

### Core (Godot 4 built-ins — no external packages)

| Component | Godot Type | Purpose | Why Standard |
|-----------|-----------|---------|--------------|
| CarHUD panel | `CanvasLayer` + `ColorRect` | Global overlay always on top | Established pattern in this project (PlayerHUD, CardOverlay use same approach) [VERIFIED: Game.tscn lines 292-299] |
| Indicator containers | `PanelContainer` + `StyleBoxFlat` | Per-indicator visual box with styleable background | Project pattern; `StyleBoxFlat` used for HUD panels in Game.gd `_setup_player_hud()` [VERIFIED: Game.gd lines 87-93] |
| Tween animation | `node.create_tween()` | Indicator lit→fade animation | Used in existing `_on_hud_event()` Game.gd line 119 and `_show_earth_shockwave()` lines 628-631 [VERIFIED: Game.gd] |
| RPC broadcast | `@rpc("authority","call_local","reliable")` | Sync HUD events across all peers | Established pattern: `_broadcast_game_over`, `_show_earth_shockwave` [VERIFIED: GameState.gd line 48, Game.gd line 618] |
| Elite enemy spawning | `MultiplayerSpawner` + `spawn_function` | Replicate elite spawn to all clients | P7 pattern: all spawners use `spawn_function` forwarding data dict [VERIFIED: Game.gd lines 42-54] |
| Host timer | `Timer` node or float accumulator in `_process` | Elite spawn interval, randf_range 45–90s | Float accumulator pattern used for `_engineer_passive_accum`, `_earth_heal_accum` [VERIFIED: Game.gd lines 36-39] |

**No npm packages, no PyPI packages, no external dependencies. Godot 4 built-ins only.**

**Package Legitimacy Audit:** N/A — Godot 4 game. No package registry involved.

---

## Architecture Patterns

### System Architecture Diagram

```
Game event fires on host
  │
  ├─► GameEvents.emit_hud.rpc("event_key")          [RPC to all peers]
  │     │
  │     └─► Every peer: GameEvents.hud_event signal fires
  │               │
  │               └─► CarHUD._on_hud_event("event_key")
  │                       │
  │                       └─► _indicators["event_key"].activate()
  │                               ├─ StyleBoxFlat → lit color
  │                               ├─ Label text → white
  │                               └─ Tween: hold 2.0s → fade 0.5s → restore idle

Elite enemy host timer (45–90s interval)
  │
  ├─► $EnemySpawner.spawn.call_deferred({"type":"elite","pos":...})
  │     │
  │     └─► _do_spawn_enemy() → instantiate EliteEnemy scene → all peers via replication
  │
  └─► GameEvents.emit_hud.rpc("lidar") → LIDAR indicator activates on all screens

Player.receive_damage(amount) on owning peer
  │
  └─► if multiplayer.is_server() and amount >= 15:
        GameEvents.emit_hud.rpc("suspension") → SUSPENSION on all screens

GameState.loop_number (host-authoritative)
  │
  ├─► CarHUD._process() polls → "Loop: N" label updated
  │
  └─► _do_spawn_enemy() reads at spawn time → applies HP/damage/spawn-count multiplier
```

### Recommended File Structure

```
autoloads/
├── GameEvents.gd          # ADD @rpc annotation to emit_hud()
└── GameState.gd           # SET loop_number=1 in _ready(), ADD start_next_loop()

scenes/
├── Game.gd                # MODIFY: add elite timer, wire SUSPENSION emit,
│                          #         wire revives_used check in attempt_revive(),
│                          #         instantiate CarHUD in _ready(),
│                          #         modify _do_spawn_enemy() for elite + difficulty scaling,
│                          #         modify _on_enemy_died() for elite-tier drops
├── Game.tscn              # ADD: CarHUD node reference (via _ready instantiation)
├── Player.gd              # MODIFY: add SUSPENSION emit in receive_damage()
├── ui/
│   └── CarHUD.tscn        # NEW: CanvasLayer + ColorRect + VBoxContainer + 5 indicators
├── enemies/
│   ├── Enemy.gd           # READ ONLY: understand base stats for elite variant
│   └── EliteEnemy.tscn    # NEW: CharacterBody2D reusing Enemy.gd, different stats
└── pickups/
    └── XpOrb.gd           # MODIFY: scale XP per orb by loop_number formula
```

### Pattern 1: RPC annotation on autoload function

**What:** Adding `@rpc("authority","call_local","reliable")` to `emit_hud()` in GameEvents.gd converts a local signal emit to a network-synced broadcast.
**When to use:** Any time a host-side game event must fire a visual/UI reaction on all peers simultaneously.
**Critical gotcha:** The function must still call the signal manually via `hud_event.emit(event_name)` — the `@rpc` annotation does NOT automatically emit the signal on all peers; it only replicates the function CALL. The existing body `hud_event.emit(event_name)` runs on all peers because `call_local` is set.

```gdscript
# Source: Godot 4 Multiplayer docs (ASSUMED — training knowledge, pattern confirmed by existing @rpc usage in GameState.gd)
@rpc("authority", "call_local", "reliable")
func emit_hud(event_name: String) -> void:
    hud_event.emit(event_name)
```

Callers do NOT change — they already call `GameEvents.emit_hud("ac")` on the host. The host calling this function will now also RPC it to all peers.

### Pattern 2: Per-indicator Tween with restart

**What:** Each indicator has its own tween. If activated while already tweening, kill the old tween and restart.
**When to use:** Any indicator node `activate()` call.

```gdscript
# Source: Game.gd _show_earth_shockwave pattern (lines 628-631) [VERIFIED: Game.gd]
# and _on_hud_event (lines 119-121) [VERIFIED: Game.gd]
var _tween: Tween = null

func activate() -> void:
    if _tween and _tween.is_valid():
        _tween.kill()
    # Set lit state
    _style.bg_color = _lit_color
    _label.add_theme_color_override("font_color", Color.WHITE)
    # Tween: hold 2s then fade modulate.a to 0 over 0.5s
    _tween = create_tween()
    _tween.tween_interval(2.0)
    _tween.tween_property(self, "modulate:a", 0.0, 0.5)
    _tween.tween_callback(_restore_idle)

func _restore_idle() -> void:
    modulate.a = 1.0
    _style.bg_color = Color(0.10, 0.10, 0.10, 1)
    _label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35, 1))
```

### Pattern 3: Float accumulator for host-only timers

**What:** Float accumulators in `_process()` with host guard — same pattern as `_engineer_passive_accum` and `_earth_heal_accum`.
**When to use:** Any periodic host-only action (elite spawn timer).

```gdscript
# Source: Game.gd lines 36-39, _tick_engineer_passive pattern [VERIFIED: Game.gd]
var _elite_spawn_timer: float = 0.0
var _elite_spawn_interval: float = 0.0  # set in _ready() via randf_range

func _process(delta: float) -> void:
    if multiplayer.is_server():
        _tick_elite_spawn(delta)

func _tick_elite_spawn(delta: float) -> void:
    _elite_spawn_timer += delta
    if _elite_spawn_timer >= _elite_spawn_interval:
        _elite_spawn_timer = 0.0
        _elite_spawn_interval = randf_range(45.0, 90.0)  # next interval
        _spawn_elite_enemy()

func _spawn_elite_enemy() -> void:
    var points := $Room1/EnemySpawnPoints.get_children()
    if points.is_empty():
        return
    var pos: Vector2 = points[randi() % points.size()].global_position
    $EnemySpawner.spawn.call_deferred({"type": "elite", "pos": pos})
    GameEvents.emit_hud.rpc("lidar")
```

### Pattern 4: Difficulty scaling at spawn time

**What:** Read `GameState.loop_number` in `_do_spawn_enemy()`, compute multiplier, apply to enemy stats before returning the node.
**When to use:** Every enemy spawn in Phase 7+.

```gdscript
# Source: CONTEXT.md D-19, D-20, D-21 [VERIFIED: CONTEXT.md]
func _do_spawn_enemy(data: Dictionary) -> Node:
    var scene = ENEMY_SCENE if data.get("type", "") != "elite" else ELITE_ENEMY_SCENE
    var e := scene.instantiate()
    e.position = data["pos"]
    e.name = "Enemy_%d" % (randi() % 9999)
    # Difficulty scaling — applied at spawn, never retroactively (D-20)
    var mult: float = 1.0 + (GameState.loop_number - 1) * 0.25
    e.current_hp = int(e.MAX_HP * mult)
    # Note: Enemy.gd uses const MAX_HP — planner must decide whether to export
    # MAX_HP or apply scaling via a separate 'spawn_hp_override' field
    e.died.connect(_on_enemy_died)
    return e
```

**CRITICAL ISSUE — const vs export:** Enemy.gd declares `const MAX_HP: int = 50` and `const CONTACT_DAMAGE: int = 10`. These are constants, not variables — they cannot be written after instantiation. The planner MUST address this: either convert `MAX_HP` and `CONTACT_DAMAGE` to `var` (or `@export var`), or pass spawn data values that the enemy reads in `_ready()` from the data dict. The `_do_spawn_enemy` spawn_function signature only receives a Dictionary, but the enemy itself must read override values from it.

**Recommended approach:** In `_do_spawn_enemy`, set data-driven vars on the enemy node using custom fields that Enemy.gd and EliteEnemy.gd read in `_ready()`:

```gdscript
# In _do_spawn_enemy:
e.hp_override = int(e.MAX_HP * mult)  # enemy reads this in _ready()
e.damage_override = int(e.CONTACT_DAMAGE * mult)

# In Enemy.gd _ready():
if hp_override > 0:
    current_hp = hp_override
```

Or simpler: change `const MAX_HP` to `var MAX_HP` in Enemy.gd and set it directly.

### Pattern 5: Revive gate insertion point

**What:** In `Game.gd attempt_revive()`, before line 312 (`target.receive_revive.rpc_id(...)`), insert the `revives_used` check.
**When to use:** HLTH-07 gate.

```gdscript
# Exact insertion point: after _revive_progress[target_id] >= REVIVE_DURATION check,
# before receive_revive.rpc_id. Source: Game.gd lines 306-313 [VERIFIED: Game.gd]
if progress >= REVIVE_DURATION:
    _revive_progress.erase(target_id)
    # HLTH-07: check revive limit per loop
    if GameState.revives_used.get(target_id, 0) >= 1:
        return  # silently blocked — CONTEXT.md D-22
    GameState.revives_used[target_id] = GameState.revives_used.get(target_id, 0) + 1
    target.receive_revive.rpc_id(target.peer_id)
```

### Anti-Patterns to Avoid

- **Tweening `StyleBoxFlat.bg_color` directly:** Godot 4 Tween cannot directly tween resource properties like `StyleBoxFlat.bg_color` using `tween_property`. Tween the *node's* `modulate:a` instead, then restore the style in the tween callback. This is exactly how the existing `_on_hud_event` label fade works (lines 119-121 in Game.gd).
- **Calling `emit_hud` from clients:** All `emit_hud` calls must be host-guarded (`if multiplayer.is_server()`). The `@rpc("authority",...)` annotation only allows host to initiate the call — if a client calls this RPC, Godot will reject it silently.
- **Adding MultiplayerSynchronizer to EliteEnemy separately:** The EliteEnemy scene is spawned via the existing `EnemySpawner` (a MultiplayerSpawner). The spawner itself handles replication. EliteEnemy does NOT need its own MultiplayerSynchronizer unless it has extra synced vars beyond what Enemy.gd already syncs (current_hp, state).
- **Using SceneTree.paused for CarHUD:** CarHUD must never pause the scene tree. It is a passive listener only. All interaction is RPC-driven.
- **Forgetting `call_deferred` on elite spawn:** The elite spawn timer fires from `_process`. Direct `$EnemySpawner.spawn(...)` inside `_process` causes "Can't change state while flushing queries". Use `$EnemySpawner.spawn.call_deferred(...)` — the same pattern used in `_on_enemy_died()` (Game.gd lines 196-205).
- **XP scaling using `PLAYER_SCRIPT.XP_PER_ORB` hardcoded constant:** `XpOrb.gd` currently calls `p.receive_xp(PLAYER_SCRIPT.XP_PER_ORB)` (line 42). Phase 7 must replace this with a computed value that reads `GameState.loop_number`. The `XP_PER_ORB` const on Player.gd becomes a base value for the formula.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HUD fade animation | Custom `_process` timer for alpha | Godot `Tween` (`create_tween()`) | Project already uses this pattern in `_on_hud_event` and `_show_earth_shockwave` |
| Network event broadcast | Signal-only emit | `@rpc("authority","call_local","reliable")` annotation on autoload func | Established pattern in GameState; matches `_broadcast_game_over` |
| Elite enemy scene | New base class | Reuse `Enemy.gd` (via `extends` or instance with overrides) | Enemy.gd has all needed AI, status effects, collision hooks |
| Spawn interval randomization | Custom PRNG | `randf_range(45.0, 90.0)` | Godot built-in; already used in project for random positions |
| Loop state persistence | Separate class | Extend existing `GameState.gd` vars | `loop_number` and `revives_used` already declared in GameState.gd |

---

## Common Pitfalls

### Pitfall 1: emit_hud called on clients breaks RPC

**What goes wrong:** After adding `@rpc("authority",...)` to `emit_hud`, any peer that calls `GameEvents.emit_hud(...)` without an `is_server()` guard will trigger a Godot RPC validation error and the call will be silently dropped.
**Why it happens:** `@rpc("authority",...)` means only the RPC authority (the host/multiplayer authority of the autoload node) may call it.
**How to avoid:** Audit ALL `emit_hud` callsites. Current callsites: `request_ice_trail()` (Game.gd line 538, already inside `if not multiplayer.is_server(): return`), `_fire_burst()` (Player.gd line 306, guarded by `if multiplayer.is_server()`), `_tick_earth_effects()` (Game.gd lines 587, 613, inside `if multiplayer.is_server()` block in `_process`), new SUSPENSION emit (must add guard), new LIDAR emit (in `_spawn_elite_enemy()`, host-only function).
**Warning signs:** HUD fires on host but not on clients; or fires on clients but not host; or Godot prints RPC authority error.

### Pitfall 2: const MAX_HP prevents difficulty scaling

**What goes wrong:** `Enemy.gd` declares `const MAX_HP: int = 50`. Writing `e.MAX_HP = int(50 * mult)` in `_do_spawn_enemy` will cause a GDScript error at runtime ("Cannot assign to constant").
**Why it happens:** `const` in GDScript is truly immutable — unlike `@export` vars, they cannot be overwritten on an instance.
**How to avoid:** Convert `const MAX_HP: int = 50` to `var MAX_HP: int = 50` (and similarly `const CONTACT_DAMAGE` to `var CONTACT_DAMAGE`) in Enemy.gd. This is a minimal change. Alternatively, add `var hp_override: int = 0` and `var damage_override: int = 0` vars that are checked in `_ready()`.
**Warning signs:** GDScript error on first enemy spawn after scaling wired; or all enemies have loop-1 stats regardless of loop number.

### Pitfall 3: CarHUD instantiated before HUD CanvasLayer exists

**What goes wrong:** If CarHUD.tscn is added as a child of the wrong node, or if Game.tscn's `HUD` CanvasLayer node already holds PlayerHUD-style content that conflicts, z-ordering and visibility will be wrong.
**Why it happens:** Game.tscn has an existing `HUD` CanvasLayer (line 292 in Game.tscn). CarHUD should be a SEPARATE CanvasLayer (layer=3 per UI-SPEC.md) added to the Game root, NOT inside the existing HUD.
**How to avoid:** In `Game.gd _ready()`, instantiate CarHUD.tscn and call `add_child(car_hud_instance)` directly on `self` (the Game node) — not `$HUD.add_child(...)`. CarHUD.gd's `_ready()` connects to `GameEvents.hud_event`.
**Warning signs:** CarHUD overlaps with PlayerHUD or doesn't appear on screen; LayerError if CanvasLayer layer conflicts.

### Pitfall 4: SUSPENSION fires for every small hit flood

**What goes wrong:** If `emit_hud.rpc("suspension")` fires every frame a player is in contact with an enemy (CONTACT_DAMAGE=10 per contact, rapidly), the SUSPENSION indicator becomes permanently lit.
**Why it happens:** Enemy contact damage fires on `body_entered` (once per contact entry) — so CONTACT_DAMAGE=10 is a single event, not per frame. However the threshold D-09 is 15, so no single normal enemy contact triggers it. Verify: normal enemy CONTACT_DAMAGE=10 < 15 threshold, so SUSPENSION only fires from unusual damage sources (multi-hit weapon impacts, future boss attacks).
**How to avoid:** Confirm threshold is 15 (locked in D-09). Normal enemies deal 10 per contact — safely below threshold. Add the emit only after the `health -= amount` line and shield/airbag checks have passed, so it reflects actual delivered damage.
**Warning signs:** SUSPENSION fires constantly even against weak enemies.

### Pitfall 5: Elite enemy not pre-registered in EnemySpawner

**What goes wrong:** `$EnemySpawner.spawn({"type":"elite",...})` calls `_do_spawn_enemy` which instantiates EliteEnemy. But if EliteEnemy.tscn is not pre-registered in EnemySpawner via `add_spawnable_scene(...)`, Godot's MultiplayerSpawner will not replicate it to clients.
**Why it happens:** MultiplayerSpawner requires all spawnable scene paths to be registered before any spawn of that type occurs.
**How to avoid:** In `Game.gd _ready()`, add `$EnemySpawner.add_spawnable_scene("res://scenes/enemies/EliteEnemy.tscn")` (if using separate scene). If reusing Enemy.tscn for elites (passing data in dict), no additional registration needed — Enemy.tscn is already registered implicitly as the EnemySpawner's scene.
**Warning signs:** Elite appears on host but not on clients; Godot multiplayer error about unregistered scene.

### Pitfall 6: GameState.loop_number not initialized until _ready

**What goes wrong:** If `_do_spawn_enemy` reads `GameState.loop_number` before `GameState._ready()` runs (e.g., if enemies spawn before autoloads finish `_ready()`), `loop_number` may be 0 — causing a formula like `1.0 + (0 - 1) * 0.25 = 0.75` to scale enemies DOWN below base.
**Why it happens:** Autoload `_ready()` order is not guaranteed relative to scene `_ready()` in all edge cases. `loop_number` is declared as `var loop_number: int = 0` (not 1).
**How to avoid:** Set `loop_number = 1` in `GameState._ready()` AND as the default initializer value (change `var loop_number: int = 0` to `var loop_number: int = 1`). This ensures correct behavior even if `_ready()` hasn't run yet.
**Warning signs:** Loop 1 enemies have 75% of base HP instead of 100%.

### Pitfall 7: XpOrb XP scaling breaks existing receive_xp flow

**What goes wrong:** `XpOrb.gd` calls `p.receive_xp(PLAYER_SCRIPT.XP_PER_ORB)` which is `15`. Replacing this with a loop-scaled formula changes the XP-per-orb for ALL loops, including loop 1 (which should be unchanged from current behavior).
**Why it happens:** The formula `5 × (1.0 + (loop_number - 1) × 0.25)` — at loop_number=1 gives `5 × 1.0 = 5`, but current codebase XP_PER_ORB is 15 (tuned in Phase 6 D-01 to hit Stage 2 in 8-12 min). These are DIFFERENT base values.
**How to avoid:** The D-19 formula uses base XP=5 as the *scaling formula's* base, NOT the current Player.gd `XP_PER_ORB = 15`. The planner must decide: either use `XP_PER_ORB * mult` (keeping 15 as base and scaling it) or use the formula `5 * mult` (which reduces loop-1 XP from 15 to 5). Recommend using `round(XP_PER_ORB * mult)` to keep existing tuning intact while scaling up per loop. This is a discretion call for the planner.

---

## Code Examples

Verified patterns from existing codebase:

### Tween fade-out (model for indicator fade)

```gdscript
# Source: Game.gd lines 119-121 [VERIFIED: Game.gd]
var tween := _hud_event_label.create_tween()
tween.tween_property(_hud_event_label, "modulate:a", 0.0, 1.2).set_delay(0.5)
tween.tween_callback(func(): _hud_event_label.visible = false)
```

### Earth shockwave tween (model for scale animation)

```gdscript
# Source: Game.gd lines 628-631 [VERIFIED: Game.gd]
var tween := ring.create_tween()
tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.35)
tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
tween.tween_callback(ring.queue_free)
```

### Host-only process timer accumulator (model for elite spawn timer)

```gdscript
# Source: Game.gd _tick_engineer_passive lines 462-468 [VERIFIED: Game.gd]
func _tick_engineer_passive(delta: float) -> void:
    _engineer_passive_accum += delta
    if _engineer_passive_accum < 5.0:
        return
    _engineer_passive_accum = 0.0
    # ... host-only action
```

### RPC with call_local (model for emit_hud upgrade)

```gdscript
# Source: GameState.gd lines 48-49 [VERIFIED: GameState.gd]
@rpc("authority", "call_local", "reliable")
func _broadcast_game_over() -> void:
    # ... runs on all peers
```

### Spawner pre-registration (model for EliteEnemy registration)

```gdscript
# Source: Game.gd lines 47-54 [VERIFIED: Game.gd]
$PickupSpawner.add_spawnable_scene("res://scenes/pickups/XpOrb.tscn")
$PickupSpawner.add_spawnable_scene("res://scenes/pickups/CarPartPickup.tscn")
$DroneSpawner.add_spawnable_scene("res://scenes/roles/HealDrone.tscn")
```

### call_deferred for physics-safe spawn inside _on_enemy_died

```gdscript
# Source: Game.gd lines 196-205 [VERIFIED: Game.gd]
$PickupSpawner.spawn.call_deferred({"type": "xp_orb", "pos": pos})
$EnemySpawner.spawn.call_deferred({"pos": spawn_pos})
```

### Difficulty scaling formula (exact formula from CONTEXT.md)

```gdscript
# Source: CONTEXT.md D-19 [VERIFIED: CONTEXT.md]
# HP and damage multiplier
var mult: float = 1.0 + (GameState.loop_number - 1) * 0.25
# Loop 1 = 1.0, Loop 2 = 1.25, Loop 3 = 1.5

# Spawn count: INITIAL_ENEMY_COUNT * 1.5^(loop_number-1), rounded
var spawn_count: int = roundi(INITIAL_ENEMY_COUNT * pow(1.5, GameState.loop_number - 1))
# Loop 1=8, Loop 2=12, Loop 3=18

# XP per orb: XP_PER_ORB (as base) * mult, rounded
var xp_amount: int = roundi(float(PLAYER_SCRIPT.XP_PER_ORB) * mult)
```

### start_next_loop() implementation (exact design from CONTEXT.md)

```gdscript
# Source: CONTEXT.md D-17, D-22 [VERIFIED: CONTEXT.md]
func start_next_loop() -> void:
    if not multiplayer.is_server():
        return
    loop_number += 1
    revives_used = {}
    print("Loop %d started" % loop_number)
    # Phase 8 will extend this for room reset and respawn
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Local signal only (`hud_event.emit()`) | `@rpc("authority","call_local","reliable")` | Phase 7 | HUD fires on ALL clients simultaneously, not just host |
| No difficulty scaling | Formula-based scaling at spawn time | Phase 7 | Loop 2+ enemies are measurably harder |
| Unlimited revives | Once-per-loop gate via `revives_used` dict | Phase 7 | HLTH-07 enforced |
| `loop_number = 0` (unused) | `loop_number = 1` (initialized, displayed) | Phase 7 | Loop counter visible; Phase 8 can call `start_next_loop()` |

**Deprecated/outdated in Phase 7:**
- `_on_hud_event()` text-label handler in Game.gd (lines 109-121): replaced by CarHUD.gd delegation. The `GameEvents.hud_event.connect(_on_hud_event)` in `_setup_player_hud()` (line 106) must be removed or the handler must become a no-op. Otherwise both the old text label and the new CarHUD will respond to HUD events.

---

## Implementation Touchpoints (Complete Map)

This section documents every file that changes in Phase 7 with the exact modification type.

### Files Modified

| File | Change Type | What Changes |
|------|------------|--------------|
| `autoloads/GameEvents.gd` | Add `@rpc` annotation | `emit_hud` function gets `@rpc("authority","call_local","reliable")` |
| `autoloads/GameState.gd` | Add vars + method | `loop_number = 1` default; `start_next_loop()` method |
| `scenes/Game.gd` | Multiple insertions | (1) Instantiate CarHUD in `_ready()`, (2) add `ELITE_ENEMY_SCENE` const + preload, (3) add `EnemySpawner` elite pre-registration, (4) add elite spawn timer vars + `_tick_elite_spawn()` + `_spawn_elite_enemy()`, (5) modify `_do_spawn_enemy()` for elite type dispatch + difficulty scaling, (6) modify `_on_enemy_died()` to optionally emit LIDAR if source is elite (or handle via spawn path), (7) insert `revives_used` check in `attempt_revive()`, (8) remove or neutralize old `GameEvents.hud_event.connect(_on_hud_event)` and text label HUD handler |
| `scenes/Player.gd` | One insertion | In `receive_damage()`, after shields pass, after `health -= amount`: `if multiplayer.is_server() and amount >= 15: GameEvents.emit_hud.rpc("suspension")` |
| `scenes/enemies/Enemy.gd` | Const → var | `const MAX_HP` → `var MAX_HP`; `const CONTACT_DAMAGE` → `var CONTACT_DAMAGE` (enables spawn-time override) |
| `scenes/pickups/XpOrb.gd` | Formula change | Replace `PLAYER_SCRIPT.XP_PER_ORB` with `roundi(float(PLAYER_SCRIPT.XP_PER_ORB) * (1.0 + (GameState.loop_number - 1) * 0.25))` |

### Files Created

| File | What It Is |
|------|-----------|
| `scenes/ui/CarHUD.tscn` | New CanvasLayer scene with CarHUDPanel, CarHUDContainer, LoopLabel, 5 indicator PanelContainers |
| `scenes/ui/CarHUD.gd` | CanvasLayer script: `_ready()` connects to `GameEvents.hud_event`, builds `_indicators` dict, polls `GameState.loop_number` in `_process()`; each indicator has `activate()` method |
| `scenes/enemies/EliteEnemy.tscn` | CharacterBody2D: purple 48×48 ColorRect, extends Enemy.gd (or new EliteEnemy.gd that extends "res://scenes/enemies/Enemy.gd") |
| `scenes/enemies/EliteEnemy.gd` | (If separate from Enemy.gd): `extends "res://scenes/enemies/Enemy.gd"` with overridden `_ready()` that sets `MAX_HP = 100`, `CONTACT_DAMAGE = 15` (2× and 1.5× the base values before difficulty mult) |

---

## Open Questions

1. **Elite enemy: reuse Enemy.gd or create EliteEnemy.gd?**
   - What we know: `Enemy.gd` has all needed behavior (AI, status effects, damage, death signal)
   - What's unclear: Whether `extends "res://scenes/enemies/Enemy.gd"` with stat overrides is cleaner than just using Enemy.tscn with data dict
   - Recommendation: Create `EliteEnemy.gd extends "res://scenes/enemies/Enemy.gd"` with `_ready()` that calls `super._ready()` then sets `MAX_HP = 100; CONTACT_DAMAGE = 15; current_hp = MAX_HP` and changes the visual. This keeps the scenes cleanly separate and avoids data-dict ambiguity in `_do_spawn_enemy`.

2. **SUSPENSION emit position in receive_damage()**
   - What we know: `receive_damage()` runs on the owning peer (not the host). The emit must be guarded by `is_server()`. But the owning peer may not be the server.
   - What's unclear: How to emit from the owning peer if they're a client?
   - Recommendation: Move SUSPENSION check to Enemy.gd or the damage SOURCE. In Enemy.gd `_on_hurtbox_body_entered`, after applying damage: `if CONTACT_DAMAGE >= 15: GameEvents.emit_hud.rpc("suspension")`. This runs on host (Enemy AI is host-only). For bullet damage, the SUSPENSION check could go in `Bullet.gd` on the host side. This avoids needing the owning peer to call the RPC.
   - Alternative: The CONTEXT.md D-09 places the check in `Player.receive_damage()`. Since receive_damage runs on the owning peer and they may be a client, the emit needs to be sent to the host first. The pattern would be: owning peer detects hit >= 15, sends an RPC to host, host calls `emit_hud.rpc("suspension")`. This is more complex. The simpler Enemy.gd source approach is recommended.

3. **XP base for loop scaling: 5 or 15?**
   - What we know: CONTEXT.md D-19 formula uses 5 as the base. Player.gd `XP_PER_ORB = 15` is the tuned Phase 6 value.
   - What's unclear: Whether loop-2 XP should scale from 5 (giving 6.25) or from 15 (giving 18.75)
   - Recommendation: Use `round(XP_PER_ORB * mult)` — keeps Phase 6 XP tuning intact for loop 1 and scales proportionally for later loops. Loop 2 = ~19 XP/orb, loop 3 = ~23. This is Claude's discretion per CONTEXT.md.

4. **CarHUD LoopLabel update strategy: polling or signal?**
   - What we know: UI-SPEC notes "CarHUD._process() polls GameState.loop_number each frame OR GameState emits a signal on change"
   - Recommendation: Polling in `_process()` is simpler and consistent with how PlayerHUD updates itself. Add a `_last_loop_number: int = 0` var; update label only when value changes.

---

## Environment Availability

Step 2.6 SKIPPED — Phase 7 is a pure GDScript / Godot 4 scene modification phase with no external CLI tools, databases, or services beyond the Godot engine itself. The project has no package manager involvement.

---

## Security Domain

Security enforcement is enabled (not explicitly disabled). Phase 7 has limited security surface:

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | Yes | Host-only guards on all game-state mutations |
| V5 Input Validation | Yes | RPC sender validation; `is_server()` guards |
| V6 Cryptography | No | — |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Client calls `emit_hud` directly | Tampering | `@rpc("authority",...)` + `is_server()` guard at callsite |
| Client sends forged `attempt_revive` to increment their own revive count | Tampering | Revive check happens on host only (existing `if not multiplayer.is_server(): return` guard in `attempt_revive`) |
| Client sends elite spawn RPC | Elevation of privilege | Elite spawn is host-only; no client-callable RPC triggers it |
| False SUSPENSION trigger flood | Denial of service | Threshold gate (>=15 damage) limits frequency; host-only emit |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `GameEvents` autoload node's multiplayer authority is the host (peer 1), making `@rpc("authority",...)` callable by host | Architecture Patterns | If authority is wrong, emit_hud RPC never fires on clients |
| A2 | `extends "res://scenes/enemies/Enemy.gd"` works in GDScript for EliteEnemy | Open Questions | If not, planner must copy-paste Enemy.gd logic |
| A3 | SUSPENSION threshold of 15 never fires from normal enemy contact (CONTACT_DAMAGE=10) | Common Pitfalls | If normal enemy damage is >= 15 in some edge case, SUSPENSION is spammy |
| A4 | `randf_range(45.0, 90.0)` is available in Godot 4 GDScript | Standard Stack | N/A — this is a known Godot 4 global function |

---

## Sources

### Primary (HIGH confidence — verified against live codebase)

- `autoloads/GameEvents.gd` — current `emit_hud` signature; `hud_event` signal declaration
- `autoloads/GameState.gd` — `loop_number`, `revives_used` declarations; `_broadcast_game_over` RPC pattern
- `scenes/Game.gd` — spawner patterns; `_on_hud_event` handler; `attempt_revive` insertion point; `_tick_engineer_passive` accumulator pattern; `_show_earth_shockwave` tween pattern
- `scenes/Player.gd` — `receive_damage()` signature and body; authority patterns
- `scenes/enemies/Enemy.gd` — `const MAX_HP`, `const CONTACT_DAMAGE` (const issue)
- `scenes/pickups/XpOrb.gd` — XP grant path; `PLAYER_SCRIPT.XP_PER_ORB` reference
- `scenes/Game.tscn` — HUD CanvasLayer node at line 292; existing spawner nodes

### Secondary (HIGH confidence — verified against CONTEXT.md and UI-SPEC.md)

- `.planning/phases/07-carhud-loop-timer-difficulty-scaling/07-CONTEXT.md` — all locked decisions D-01 through D-22
- `.planning/phases/07-carhud-loop-timer-difficulty-scaling/07-UI-SPEC.md` — node inventory, color values, exact label strings, indicator dimensions

### Tertiary (ASSUMED — training knowledge)

- Godot 4 `@rpc("authority","call_local","reliable")` annotation semantics
- Godot 4 `extends "res://path/file.gd"` inheritance syntax
- Godot 4 Tween `tween_interval()` method availability

---

## Metadata

**Confidence breakdown:**
- Implementation touchpoints: HIGH — all file and line references verified against live codebase
- GDScript patterns: HIGH — all patterns verified from existing code in this project
- Difficulty formula: HIGH — exact formulas from locked CONTEXT.md decisions
- Tween behavior: HIGH — verified from two existing uses in Game.gd
- RPC semantics: MEDIUM — Godot 4 docs not fetched this session; patterns inferred from existing working code

**Research date:** 2026-06-19
**Valid until:** 2026-08-19 (stable Godot 4 GDScript patterns; no fast-moving external dependencies)
