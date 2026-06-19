# Phase 7: CarHUD, Loop Timer & Difficulty Scaling - Pattern Map

**Mapped:** 2026-06-19
**Files analyzed:** 10 (4 new, 6 modified)
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scenes/ui/CarHUD.tscn` | component/scene | event-driven | `scenes/ui/PlayerHUD.gd` + Game.gd HUD setup | role-match |
| `scenes/ui/CarHUD.gd` | component/controller | event-driven | `scenes/ui/PlayerHUD.gd` (CanvasLayer pattern) | role-match |
| `scenes/enemies/EliteEnemy.tscn` | scene | — | `scenes/enemies/Enemy.tscn` (reuse base) | exact |
| `scenes/enemies/EliteEnemy.gd` | controller | request-response | `scenes/enemies/Enemy.gd` | exact |
| `autoloads/GameEvents.gd` | service/autoload | pub-sub | itself — add `@rpc` annotation | exact |
| `autoloads/GameState.gd` | service/autoload | CRUD | itself — add `start_next_loop()` | exact |
| `scenes/Game.gd` | controller | event-driven + CRUD | itself — multiple surgical insertions | exact |
| `scenes/Player.gd` | controller | request-response | itself — one insertion in `receive_damage()` | exact |
| `scenes/enemies/Enemy.gd` | controller | CRUD | itself — `const` → `var` conversion | exact |
| `scenes/pickups/XpOrb.gd` | component | request-response | itself — formula change in `_request_collect()` | exact |

---

## Pattern Assignments

### `autoloads/GameEvents.gd` — Add `@rpc` annotation to `emit_hud`

**Analog:** `autoloads/GameState.gd` lines 48–49 (`_broadcast_game_over` RPC pattern)

**Current state** (GameEvents.gd lines 15–16):
```gdscript
func emit_hud(event_name: String) -> void:
    hud_event.emit(event_name)
```

**Target pattern — add `@rpc` above `func emit_hud`:**
```gdscript
# Copy RPC annotation from GameState.gd lines 48-49
@rpc("authority", "call_local", "reliable")
func emit_hud(event_name: String) -> void:
    hud_event.emit(event_name)
```

**Critical note:** `call_local` ensures the signal fires on the host too — the same mechanic as `_broadcast_game_over` (GameState.gd line 48). No call-site changes needed because all callers are already host-guarded.

---

### `autoloads/GameState.gd` — Initialize `loop_number`, add `start_next_loop()`

**Analog:** `autoloads/GameState.gd` `_broadcast_game_over` method (lines 49–63) for host-guard pattern; `track_downed` (lines 27–45) for multiplayer connection guard pattern.

**Change 1 — Fix default value** (GameState.gd line 7):
```gdscript
# BEFORE:
var loop_number: int = 0
# AFTER (also set in _ready for safety — Pitfall 6 in RESEARCH.md):
var loop_number: int = 1
```

**Change 2 — Initialize in `_ready`** (GameState.gd lines 10–11):
```gdscript
func _ready() -> void:
    loop_number = 1  # Pitfall 6: ensure correct base even before peers connect
```

**Change 3 — New method, copy host-guard pattern from `track_downed` lines 28–34:**
```gdscript
## LOOP-03 / D-17: Called by Phase 8 after boss defeat. Hook point for next-loop setup.
func start_next_loop() -> void:
    if not multiplayer.has_multiplayer_peer():
        return
    if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
        return
    if not multiplayer.is_server():
        return
    loop_number += 1
    revives_used = {}
    print("Loop %d started" % loop_number)
```

---

### `scenes/ui/CarHUD.gd` + `CarHUD.tscn` — New global CanvasLayer HUD

**Analog:** `scenes/ui/PlayerHUD.gd` (CanvasLayer extends, `_ready` pattern); `scenes/Game.gd` `_setup_player_hud` (lines 72–107, StyleBoxFlat + VBoxContainer construction); `scenes/Game.gd` `_on_hud_event` (lines 109–121, tween fade pattern).

**CanvasLayer base — copy from PlayerHUD.gd lines 1–9:**
```gdscript
extends CanvasLayer
## CarHUD — single global dashboard visible to all players simultaneously (D-01, D-02).
## CanvasLayer.layer = 3 to render above game world and PlayerHUD (layer 1).
## Connects to GameEvents.hud_event RPC signal in _ready().
```

**`_ready` pattern — connect to signal (copy from Game.gd line 106):**
```gdscript
func _ready() -> void:
    # Mirror Game.gd line 106: GameEvents.hud_event.connect(_on_hud_event)
    GameEvents.hud_event.connect(_on_hud_event)
    _build_indicators()
    _loop_label = $CarHUDPanel/VBox/LoopLabel  # (or get_node path per tscn layout)
    _last_loop_number = GameState.loop_number

func _process(_delta: float) -> void:
    # Polling pattern — same approach as _update_player_hud in Game.gd lines 123-143
    if GameState.loop_number != _last_loop_number:
        _last_loop_number = GameState.loop_number
        _loop_label.text = "Loop: %d" % _last_loop_number
```

**Indicator dict construction — copy StyleBoxFlat pattern from Game.gd lines 86–93:**
```gdscript
# Source: Game.gd _setup_player_hud lines 86-93
var style := StyleBoxFlat.new()
style.bg_color = Color(0.10, 0.10, 0.10, 1)  # idle: dark grey
style.set_corner_radius_all(4)
style.content_margin_left = 8
style.content_margin_right = 8
style.content_margin_top = 6
style.content_margin_bottom = 6
panel.add_theme_stylebox_override("panel", style)
```

**Indicator activation with tween — copy directly from Game.gd `_on_hud_event` lines 117–121:**
```gdscript
# Source: Game.gd lines 117-121 — tween modulate:a fade
func activate(lit_color: Color) -> void:
    if _tween and _tween.is_valid():
        _tween.kill()
    _style.bg_color = lit_color
    _label.add_theme_color_override("font_color", Color.WHITE)
    modulate.a = 1.0
    _tween = create_tween()
    _tween.tween_interval(2.0)
    _tween.tween_property(self, "modulate:a", 0.0, 0.5)
    _tween.tween_callback(_restore_idle)

func _restore_idle() -> void:
    modulate.a = 1.0
    _style.bg_color = Color(0.10, 0.10, 0.10, 1)
    _label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35, 1))
```

**Anti-pattern note:** Do NOT tween `StyleBoxFlat.bg_color` directly — Godot 4 cannot tween resource properties. Tween `modulate:a` on the node, as done in Game.gd line 120.

**CarHUD.tscn node tree (copy CanvasLayer → ColorRect + VBoxContainer pattern from existing HUD CanvasLayer in Game.tscn lines 292–299):**
```
CarHUD (CanvasLayer, layer=3)
  └── CarHUDPanel (PanelContainer, anchors: right-strip 200px wide, full height)
        └── VBox (VBoxContainer)
              ├── LoopLabel (Label, text="Loop: 1")
              ├── ACIndicator (PanelContainer)   → CarHUDIndicator.gd
              ├── ENGINEIndicator (PanelContainer)
              ├── SEATMASSAGEIndicator (PanelContainer)
              ├── SUSPENSIONIndicator (PanelContainer)
              └── LIDARIndicator (PanelContainer)
```

**Event routing in `_on_hud_event` — copy match pattern from Game.gd lines 112–116:**
```gdscript
func _on_hud_event(event_name: String) -> void:
    match event_name:
        "ac":           _indicators["ac"].activate(Color(0.2, 0.5, 1.0))    # blue
        "engine":       _indicators["engine"].activate(Color(1.0, 0.2, 0.1)) # red
        "seat_massage": _indicators["seat_massage"].activate(Color(0.1, 0.8, 0.2)) # green
        "suspension":   _indicators["suspension"].activate(Color(1.0, 0.85, 0.0)) # yellow
        "lidar":        _indicators["lidar"].activate(Color(1.0, 0.4, 0.0))  # orange-red
```

---

### `scenes/enemies/EliteEnemy.gd` + `EliteEnemy.tscn` — New elite enemy variant

**Analog:** `scenes/enemies/Enemy.gd` (entire file — EliteEnemy extends it)

**EliteEnemy.gd — extends Enemy.gd, override stats in `_ready`:**
```gdscript
extends "res://scenes/enemies/Enemy.gd"
## EliteEnemy — 2× HP, 1.5× damage, larger visual. Spawned by host timer (D-12, D-13).
## Triggers LIDAR indicator on spawn via Game.gd _spawn_elite_enemy().

func _ready() -> void:
    super._ready()  # Enemy._ready(): add_to_group, set_physics_process, connect hurtbox
    # D-12: 2× base HP (Enemy.MAX_HP after Phase 7 becomes var, default 50)
    MAX_HP = 100
    CONTACT_DAMAGE = 15  # 1.5× base (Enemy.CONTACT_DAMAGE default 10)
    current_hp = MAX_HP
    # Larger visual — purple ColorRect to distinguish from normal (dark red/purple)
    if has_node("ColorRect"):
        $ColorRect.color = Color(0.5, 0.1, 0.7)  # purple
        $ColorRect.size = Vector2(48, 48)          # 2× normal 24×24
```

**EliteEnemy.tscn node tree (copy Enemy.tscn structure exactly, assign EliteEnemy.gd as script):**
```
EliteEnemy (CharacterBody2D, script=EliteEnemy.gd)
  ├── ColorRect (48×48, purple Color(0.5, 0.1, 0.7))
  ├── HurtboxArea (Area2D) — same collision layers as Enemy.tscn
  ├── NavigationAgent2D
  ├── HealthBar (ProgressBar) — optional, same as Enemy.tscn
  └── MultiplayerSynchronizer — same synced vars as Enemy.tscn (current_hp, state)
```

---

### `scenes/Game.gd` — Multiple surgical insertions

**Analog:** `scenes/Game.gd` itself — 8 insertion points.

**1. New preload constants** (after line 16, copying lines 7–16 pattern):
```gdscript
# Copy preload pattern from Game.gd lines 7-16
const ELITE_ENEMY_SCENE := preload("res://scenes/enemies/EliteEnemy.tscn")
```

**2. New accumulator vars** (after line 38, copy `_engineer_passive_accum` pattern lines 34–38):
```gdscript
# Source: Game.gd lines 34-38 — float accumulator pattern
var _elite_spawn_timer: float = 0.0
var _elite_spawn_interval: float = 0.0  # randomized in _ready
```

**3. `_ready` additions** (after line 54, within existing `_ready`):
```gdscript
# Pre-register EliteEnemy — copy pattern from Game.gd lines 47-54
$EnemySpawner.add_spawnable_scene("res://scenes/enemies/EliteEnemy.tscn")

# Instantiate CarHUD as separate CanvasLayer on Game root (NOT inside $HUD — Pitfall 3)
var car_hud := preload("res://scenes/ui/CarHUD.tscn").instantiate()
add_child(car_hud)

# Initialize elite spawn interval
_elite_spawn_interval = randf_range(45.0, 90.0)

# Remove or disconnect old hud_event text-label connection (RESEARCH.md "Deprecated")
# GameEvents.hud_event.connect(_on_hud_event) in _setup_player_hud line 106 must be removed
# or _on_hud_event must be made a no-op after CarHUD is wired
```

**4. `_process` — elite spawn tick** (copy `_tick_engineer_passive` call pattern from Game.gd `_process`):
```gdscript
# Source: Game.gd _tick_engineer_passive call pattern
func _process(delta: float) -> void:
    # ... existing ...
    if multiplayer.is_server():
        _tick_elite_spawn(delta)
    # ... existing ...
```

**5. New `_tick_elite_spawn` + `_spawn_elite_enemy`** (copy from RESEARCH.md Pattern 3, verified against Game.gd lines 462–468):
```gdscript
# Source: Game.gd _tick_engineer_passive lines 462-468
func _tick_elite_spawn(delta: float) -> void:
    _elite_spawn_timer += delta
    if _elite_spawn_timer < _elite_spawn_interval:
        return
    _elite_spawn_timer = 0.0
    _elite_spawn_interval = randf_range(45.0, 90.0)
    _spawn_elite_enemy()

func _spawn_elite_enemy() -> void:
    var points := $Room1/EnemySpawnPoints.get_children()
    if points.is_empty():
        return
    var pos: Vector2 = points[randi() % points.size()].global_position
    # call_deferred pattern — source: Game.gd lines 196-205
    $EnemySpawner.spawn.call_deferred({"type": "elite", "pos": pos})
    GameEvents.emit_hud.rpc("lidar")
```

**6. `_do_spawn_enemy` — add elite dispatch + difficulty scaling** (modifies Game.gd lines 183–189):
```gdscript
# Source: Game.gd lines 183-189, extended with elite type and difficulty scaling
func _do_spawn_enemy(data: Dictionary) -> Node:
    var scene = ELITE_ENEMY_SCENE if data.get("type", "") == "elite" else ENEMY_SCENE
    var e := scene.instantiate()
    e.position = data["pos"]
    e.name = "Enemy_%d" % (randi() % 9999)
    # D-19/D-20: apply difficulty scaling at spawn time (Pitfall 2: MAX_HP must be var)
    var mult: float = 1.0 + (GameState.loop_number - 1) * 0.25
    e.MAX_HP = int(e.MAX_HP * mult)
    e.CONTACT_DAMAGE = int(e.CONTACT_DAMAGE * mult)
    e.current_hp = e.MAX_HP
    e.died.connect(_on_enemy_died)
    return e
```

**7. Revive gate in `attempt_revive`** (insert at Game.gd line 306, after `progress >= REVIVE_DURATION` check):
```gdscript
# Source: Game.gd lines 306-313 — insert before target.receive_revive.rpc_id
if progress >= REVIVE_DURATION:
    _revive_progress.erase(target_id)
    # HLTH-07: D-22 — block if already revived once this loop
    if GameState.revives_used.get(target_id, 0) >= 1:
        return  # silently blocked
    GameState.revives_used[target_id] = GameState.revives_used.get(target_id, 0) + 1
    target.receive_revive.rpc_id(target.peer_id)
```

**8. Remove old HUD handler** — In `_setup_player_hud` (Game.gd line 106), remove `GameEvents.hud_event.connect(_on_hud_event)`. The `_on_hud_event` method (lines 109–121) can be deleted or left as no-op (CarHUD handles all indicator events now).

---

### `scenes/Player.gd` — Add SUSPENSION emit in `receive_damage`

**Analog:** `scenes/Player.gd` `receive_damage` lines 442–468 (own file, one insertion).

**Insertion point — after `health -= amount` on line 465:**
```gdscript
# Source: Player.gd lines 442-468
health -= amount
# HUD-06 / D-09: SUSPENSION fires when actual delivered damage >= 15
# Note: RESEARCH.md Open Question 2 recommends emitting from Enemy.gd host-side instead.
# If placed here, Player.receive_damage runs on owning peer — requires owning peer to be host
# OR a separate "notify host" RPC. Simpler alternative: add check in Enemy.gd
# _on_hurtbox_body_entered after the rpc_id call, on the host side:
#   if CONTACT_DAMAGE >= 15: GameEvents.emit_hud.rpc("suspension")
# Planner must choose site. Both patterns exist in codebase.
if health <= 0:
    health = 0
    _enter_downed()
```

**Recommended site (Enemy.gd host-side, simpler):**
```gdscript
# In Enemy.gd _on_hurtbox_body_entered, after body.receive_damage call (lines 136-138):
# Host already runs this block (is_multiplayer_authority() guard at line 122)
if CONTACT_DAMAGE >= 15:
    GameEvents.emit_hud.rpc("suspension")
```

---

### `scenes/enemies/Enemy.gd` — Convert `const` to `var`

**Analog:** `scenes/enemies/Enemy.gd` itself (lines 8–11).

**Change:**
```gdscript
# BEFORE (Enemy.gd lines 8-11):
const SPEED: float = 80.0
const DETECT_RADIUS: float = 300.0
const CONTACT_DAMAGE: int = 10
const MAX_HP: int = 50

# AFTER (only CONTACT_DAMAGE and MAX_HP need to change — Pitfall 2 in RESEARCH.md):
const SPEED: float = 80.0
const DETECT_RADIUS: float = 300.0
var CONTACT_DAMAGE: int = 10  # must be var for spawn-time difficulty scaling
var MAX_HP: int = 50           # must be var for spawn-time difficulty scaling
```

**Health bar ratio fix** — Enemy.gd line 42 reads `float(MAX_HP)` which works the same whether `const` or `var`. No change needed there.

---

### `scenes/pickups/XpOrb.gd` — Scale XP by `loop_number`

**Analog:** `scenes/pickups/XpOrb.gd` itself — lines 42–44 (`_request_collect` XP grant).

**Change (lines 42–44):**
```gdscript
# BEFORE (XpOrb.gd lines 42-44):
p.receive_xp(PLAYER_SCRIPT.XP_PER_ORB)
# ...
p.receive_xp.rpc_id(collector_peer_id, PLAYER_SCRIPT.XP_PER_ORB)

# AFTER (D-19: scale from existing XP_PER_ORB base, not from 5 — see RESEARCH.md Pitfall 7):
var xp_amount: int = roundi(float(PLAYER_SCRIPT.XP_PER_ORB) * (1.0 + (GameState.loop_number - 1) * 0.25))
p.receive_xp(xp_amount)
# ...
p.receive_xp.rpc_id(collector_peer_id, xp_amount)
```

**Rationale (from RESEARCH.md Open Question 3):** Using `XP_PER_ORB * mult` keeps Phase 6 XP tuning (15/orb) intact for loop 1 and scales proportionally. Loop 2 = ~19 XP, loop 3 = ~23 XP. The CONTEXT.md D-19 formula using base=5 was an abstract example; planner discretion applies here per CONTEXT.md "Claude's Discretion."

---

## Shared Patterns

### RPC broadcast (host authority → all peers)
**Source:** `autoloads/GameState.gd` lines 48–49
**Apply to:** `GameEvents.emit_hud()` annotation; any new host-only broadcast functions
```gdscript
@rpc("authority", "call_local", "reliable")
func _broadcast_game_over() -> void:
```

### Host-guard multiplayer connection check
**Source:** `autoloads/GameState.gd` lines 16–21
**Apply to:** `GameState.start_next_loop()`, any new host-only methods in GameState
```gdscript
if not multiplayer.has_multiplayer_peer():
    return
if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
    return
if not multiplayer.is_server():
    return
```

### Float accumulator for host-only periodic actions
**Source:** `scenes/Game.gd` lines 34–38 (var declarations), lines 462–468 (`_tick_engineer_passive`)
**Apply to:** Elite enemy spawn timer (`_elite_spawn_timer`, `_tick_elite_spawn`)
```gdscript
var _engineer_passive_accum: float = 0.0

func _tick_engineer_passive(delta: float) -> void:
    _engineer_passive_accum += delta
    if _engineer_passive_accum < 5.0:
        return
    _engineer_passive_accum = 0.0
    # ... host-only action
```

### `call_deferred` for physics-safe spawns
**Source:** `scenes/Game.gd` lines 196–205
**Apply to:** `_spawn_elite_enemy()` call to `$EnemySpawner.spawn`
```gdscript
$PickupSpawner.spawn.call_deferred({"type": "xp_orb", "pos": pos})
$EnemySpawner.spawn.call_deferred({"pos": spawn_pos})
```

### Tween modulate:a fade (NOT StyleBoxFlat.bg_color)
**Source:** `scenes/Game.gd` lines 119–121
**Apply to:** CarHUD indicator `activate()` fade animation
```gdscript
var tween := _hud_event_label.create_tween()
tween.tween_property(_hud_event_label, "modulate:a", 0.0, 1.2).set_delay(0.5)
tween.tween_callback(func(): _hud_event_label.visible = false)
```

### StyleBoxFlat programmatic construction
**Source:** `scenes/Game.gd` lines 86–93
**Apply to:** CarHUD indicator idle and active state styling
```gdscript
var style := StyleBoxFlat.new()
style.bg_color = Color(0.0, 0.0, 0.0, 0.65)
style.set_corner_radius_all(5)
style.content_margin_left = 10
style.content_margin_right = 10
style.content_margin_top = 7
style.content_margin_bottom = 7
panel.add_theme_stylebox_override("panel", style)
```

### Spawnable scene pre-registration
**Source:** `scenes/Game.gd` lines 47–54
**Apply to:** `$EnemySpawner.add_spawnable_scene("res://scenes/enemies/EliteEnemy.tscn")` in `_ready`
```gdscript
$PickupSpawner.add_spawnable_scene("res://scenes/pickups/XpOrb.tscn")
$PickupSpawner.add_spawnable_scene("res://scenes/pickups/CarPartPickup.tscn")
$DroneSpawner.add_spawnable_scene("res://scenes/roles/HealDrone.tscn")
```

---

## No Analog Found

All files have analogs. No items in this section.

---

## Metadata

**Analog search scope:** `autoloads/`, `scenes/`, `scenes/ui/`, `scenes/enemies/`, `scenes/pickups/`
**Files scanned:** 7 live source files read directly
**Pattern extraction date:** 2026-06-19
