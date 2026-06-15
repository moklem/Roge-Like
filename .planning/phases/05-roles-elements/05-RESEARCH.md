# Phase 5: Roles & Elements - Research

**Researched:** 2026-06-15
**Domain:** Godot 4 GDScript — multiplayer role/ability systems, status effects, spawnable scenes
**Confidence:** HIGH (all findings derive from direct codebase inspection of prior phases)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Key Bindings:**
- D-01: Revive key changes from E → R (`revive` action in Godot InputMap). String change only.
- D-02: Role ability (Stage-1 and Stage-2) maps to Space (`role_ability` input action). Same key, stronger Stage-2 variant.
- D-03: All element abilities are passive — no dedicated element key. Fire/Ice/Earth trigger automatically from game events.

**Role Stats Architecture:**
- D-04: `evolution_stage: int = 1` added to Player.gd alongside `health` and `is_downed`. Phase 6 sets it via RPC. Ability code checks `if evolution_stage >= 2:`.
- D-05: Role-specific stats applied in Player.gd `_ready()` using a match block on `role_label`. Constants dict in Player.gd — no separate resource file.
- D-06: Ability cooldowns live in Player.gd (one `_ability_cooldown: float` timer). Authority guard: owning peer reads Space; sends RPC to host; host executes effect and syncs result.

**Tank Role:**
- D-07: Tank max HP = 150 (vs. 100 default). Set in `_ready()` via role match.
- D-08: Tank Stage-1 (Space): 3-second full damage shield. All incoming damage blocked (0 damage). Visual: colored ring (different color from yellow AirbagShield). Cooldown: 8 seconds after shield expires.
- D-09: Tank Stage-2: 6-second shield + damage reflection: each blocked hit deals 50% back to attacker via enemy `receive_damage`. Host validates reflection.

**Speedster Role:**
- D-10: Speedster base speed = 280 (vs. 200 default). Set in `_ready()` via role match.
- D-11: Speedster Stage-1 (Space): 0.3-second speed burst — velocity = `direction * SPEED * 3.0`, invincibility frames (ignore all damage for 0.3 sec). Cooldown: 4 seconds.
- D-12: Speedster Stage-2: Double Dash — after first dash, second dash available within 0.8 seconds. Second dash triggers shockwave landing (~80px radius, ~25 damage, knockback). If second dash not used within 0.8 sec, normal cooldown resumes.

**Engineer Role:**
- D-13: Engineer passive: Every 5 seconds, +10 HP to all teammates within 200px radius. Host-authoritative: host checks proximity and calls `receive_heal` RPC on each nearby Player. Engineer HP stays at default 100.
- D-14: Engineer Stage-1 (Space): Deploy Heal Drone at current position. Host spawns via DroneSpawner. Drone pulses every 3 seconds: +15 HP to all players within 150px radius. Max 1 drone active — deploying removes old one.
- D-15: Engineer Stage-2: Drone follows Engineer (instead of fixed). Stats upgrade: +25 HP per pulse, 200px radius. Same 3-second pulse interval. `follow_target: NodePath` set to Engineer; updates position each `_physics_process` tick (host-authoritative).

**Element Modifiers:**
- D-16: Element effects trigger exclusively from ScrewsAndBolts projectile hits with 25% proc chance per hit. No other weapon triggers element effects.
- D-17: Fire element — Burn DoT: 25% proc → enemy burns 5 damage/sec for 3 sec (total 15). Burn tracked on Enemy.gd with Timer. Multiple burns don't stack — refresh duration. Fire Burst: every 4 seconds, automatic burst of 3-5 ScrewsAndBolts-style projectiles aimed at nearest enemy (orange/red modulate, 100% Burn proc). Host spawns via existing `request_fire` / spawner path.
- D-18: Ice element — Slow: 25% proc → enemy slowed to 50% movement for 2 seconds (`speed_multiplier` float on Enemy.gd). Ice Trail: every 0.3 seconds of movement, spawn small Area2D at current position (lifetime 2 sec). Enemies entering slowed (50%, 1.5 sec). Host spawns trail zones via `spawn.call_deferred`.
- D-19: Earth element — Team Heal: passive +2 HP/sec to all players (no proximity). Host ticks timer, calls `receive_heal` on all Player nodes each second. Shockwave: every 8 seconds (automatic), Area2D burst (~120px radius) around Earth player. Enemies pushed back (`velocity +=`) + ~15 damage. Host-authoritative. ELEM-07: All element activations call `GameEvents.emit_hud()` wrapped in `if multiplayer.is_server():`. Fire → "engine", Ice → "ac", Earth → "seat_massage".

**Stage-2 Gate:**
- D-20: `evolution_stage` starts at 1. Ability dispatch: `if evolution_stage >= 2: _use_stage2_ability() else: _use_stage1_ability()`. Phase 6 sets it via `set_evolution_stage` RPC on Player.

**Engineer Drone Architecture:**
- D-21: Drone is a separate spawnable scene (HealDrone.tscn), registered in Game.gd's DroneSpawner. Drone has: `owning_peer: int`, `pulse_timer: Timer` (3 sec, autostart = true). Stage-1 static; Stage-2 `_physics_process` sets `global_position = owner_player.global_position` (host only, synced via MultiplayerSynchronizer on Drone node).

### Claude's Discretion

- Exact damage value for Tank shield reflection (starting point: 50% of blocked damage, min 5)
- Exact cooldown for Fire Burst auto-timer (starting point: 4 seconds)
- Burn/Slow visual indicators on enemies (color modulate — orange for burn, blue for slow)
- Ice Trail zone visual (small light-blue Area2D ColorRect, semi-transparent)
- Drone visual (small colored circle, distinct from SpinningTires)
- Speedster shockwave visual (brief yellow ring expansion at dash landing point)

### Deferred Ideas (OUT OF SCOPE)

- Elemental combo interactions (Fire + Ice = Steam): Out of scope per PROJECT.md. Future v2.
- Per-role visual differentiation beyond color: Placeholder shapes only.
- Tank shield reflecting AOE damage (HornShockwave): Reflection only for direct enemy contact/single-target hits.
- Multiple drones (Engineer): Only 1 drone active at a time in Phase 5.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ROLE-01 | Tank has noticeably higher max HP than other roles | D-07: MAX_HP = 150 in role match block in Player.gd `_ready()` |
| ROLE-02 | Tank has a melee aura ability that damages nearby enemies | D-08: Redesigned as 3-sec damage shield (blocks all damage). Space key via `role_ability` action. |
| ROLE-03 | Tank's Stage 2 signature ability: sustained aura burst (larger radius, short duration) | D-09: 6-sec shield + damage reflection. `evolution_stage >= 2` gate. |
| ROLE-04 | Speedster moves faster than other roles | D-10: SPEED = 280 in role match block |
| ROLE-05 | Speedster has a dash ability (brief burst of speed / invincibility frames) | D-11: 0.3-sec burst, velocity * 3.0, invincibility frames for 0.3 sec |
| ROLE-06 | Speedster's Stage 2 signature ability: afterimage dash (leaves damaging trail) | D-12: Double Dash with shockwave landing at endpoint |
| ROLE-07 | Engineer has a passive heal that periodically restores HP to nearby teammates | D-13: Every 5 sec, +10 HP to players within 200px. Host-authoritative. |
| ROLE-08 | Engineer deploys a drone that targets nearby enemies | D-14: Redesigned as Heal Drone. Deploy via Space. Max 1 active. |
| ROLE-09 | Engineer's Stage 2 signature ability: repair pulse (burst heal to all teammates) | D-15: Stage-2 drone follows Engineer, +25 HP per pulse, 200px radius |
| ROLE-10 | Each role feels mechanically distinct in a 3-player session | Tank tanks, Speedster dashes, Engineer heals — all host-authoritative effects verified |
| ELEM-01 | Fire element adds a burn damage-over-time effect to enemies hit by the player | D-17: 25% proc on ScrewsAndBolts hit → 5 dmg/sec for 3 sec |
| ELEM-02 | Fire element has a periodic area ring that damages enemies in range | D-17: Fire Burst every 4 sec, 3-5 auto-projectiles at nearest enemy |
| ELEM-03 | Ice element applies a slow effect to enemies hit by the player | D-18: 25% proc → 50% movement speed for 2 sec via speed_multiplier |
| ELEM-04 | Ice element periodically creates a ground trail that blocks / slows enemy movement | D-18: Ice Trail Area2D zones every 0.3 sec of movement, lifetime 2 sec |
| ELEM-05 | Earth element provides passive healing per second to the whole team | D-19: +2 HP/sec to all players, no proximity, host-ticked timer |
| ELEM-06 | Earth element has a shockwave ability that pushes enemies back | D-19: Every 8 sec, ~120px Area2D burst, velocity knockback + ~15 dmg |
| ELEM-07 | Element abilities trigger the appropriate CARIAD HUD indicator when activated | D-19/GameEvents.emit_hud(): Fire→"engine", Ice→"ac", Earth→"seat_massage" |
</phase_requirements>

---

## Summary

Phase 5 extends the existing Godot 4 multiplayer codebase with three role-specific ability systems (Tank, Speedster, Engineer) and three element modifier systems (Fire, Ice, Earth). The implementation is purely additive — no existing systems are restructured. All decisions are locked in CONTEXT.md; research here verifies the codebase state and documents the exact integration patterns needed.

The project uses Godot 4.6 with ENet multiplayer, a host-authoritative model, and three autoloads (Lobby, GameEvents, GameState). Phase 4 delivered WeaponManager with AirbagShield, which is the direct model for the Tank shield ability. The Engineer Heal Drone follows the existing MultiplayerSpawner pattern (XpOrb/CarPartPickup). Element proc logic attaches to the Bullet.gd `_on_area_entered` hit handler, which is the single authoritative bullet-hit site.

The primary complexity areas are: (1) Tank shield interaction with the existing `receive_damage` RPC chain; (2) Engineer Drone as a new spawnable scene type requiring DroneSpawner registration in Game.gd; (3) Ice Trail spawning inside `_physics_process` requiring `call_deferred`; and (4) element proc logic that must read the owning player's element from `Lobby.players` inside Bullet.gd's host-only hit handler.

**Primary recommendation:** Implement in waves — role stat application first (isolated to Player.gd `_ready()`), then Space-key ability dispatch, then Engineer drone, then element procs, then HUD wiring. Each wave is independently testable.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Role stat application (HP, speed) | Player.gd `_ready()` | — | Stats are per-peer; set once at spawn from Lobby.players dict |
| Ability input detection (Space) | Owning peer (Player.gd `_physics_process`) | — | P3: input read only on authority peer |
| Ability RPC to host | Client → Game.gd or Player.gd RPC | — | P12: client input → host validation → broadcast |
| Tank shield damage intercept | Owning peer Player.gd `receive_damage` | Host reflection RPC | Shield active flag checked before health decrement |
| Engineer Heal Drone spawn | Host-only via DroneSpawner | MultiplayerSynchronizer | Same pattern as BulletSpawner/PickupSpawner |
| Engineer passive heal | Host-only timer in Player.gd or Game.gd | receive_heal RPC | Host ticks proximity check and pushes heal RPC |
| Element proc on bullet hit | Host-only (Bullet.gd `_on_area_entered`) | — | Bullet.gd already guards all hit logic with `is_multiplayer_authority()` |
| Ice Trail zone spawn | Host-only via IceTrailSpawner or direct add_child | — | `call_deferred` required inside `_physics_process` |
| Earth shockwave | Host-only timer → Area2D burst | — | Mirrors Earth passive heal timer pattern |
| HUD emit | Host-only `GameEvents.emit_hud()` | RPC broadcast (Phase 6) | ELEM-07: always wrapped in `if multiplayer.is_server():` |
| Evolution stage gate | Player.gd `evolution_stage` variable | — | Read locally; Phase 6 sets via RPC |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot 4.6 GDScript | 4.6 | All game logic | Project is already using this — locked |
| ENet multiplayer | Built-in | Peer-to-peer LAN | Already wired in Phase 1 |
| MultiplayerSynchronizer | Built-in | State replication at 20 Hz | Player position, health, shield_active sync |
| MultiplayerSpawner | Built-in | Host-authoritative scene spawn | All spawnable scenes (Bullet, Drone, IceTrail) |

**No external packages to install.** Pure Godot 4.6 GDScript. `[VERIFIED: codebase inspection]`

---

## Package Legitimacy Audit

> Not applicable. Phase 5 adds no external dependencies — all implementation uses Godot 4.6 built-ins and existing project code.

---

## Architecture Patterns

### System Architecture Diagram

```
Player Input (Space key, owning peer)
        |
        v
Player.gd _physics_process [authority guard]
        |
        +-- _use_role_ability()
        |       |
        |       +-- if evolution_stage >= 2 → _use_stage2_ability()
        |       +-- else                    → _use_stage1_ability()
        |       |
        |       +-- Tank: set shield_active=true (local), request_ability.rpc_id(1)
        |       +-- Speedster: apply speed burst + invincibility frames (local), notify host
        |       +-- Engineer: request_deploy_drone.rpc_id(1)
        |
        v
Host (Game.gd or Player.gd RPC handler)
        |
        +-- Tank: validates shield timer, broadcasts shield_active via MultiplayerSynchronizer
        +-- Speedster: validates dash, applies shockwave at landing (Stage-2)
        +-- Engineer: DroneSpawner.spawn({...})
        |
        v
MultiplayerSynchronizer → all clients see shield_active, dash_invincible, drone position

═══════════════════════════════════════════

Bullet.gd _on_area_entered [host-only]
        |
        +-- enemy.take_damage(BULLET_DAMAGE)
        |
        +-- Element proc check:
        |       var owner = find_player_by_peer_id(owner_peer_id)
        |       var elem  = Lobby.players[owner_peer_id].element
        |       if randf() < 0.25:
        |           if elem == "fire":  apply_burn(enemy)
        |           if elem == "ice":   apply_slow(enemy)
        |
        +-- GameEvents.emit_hud("engine" / "ac")   [if proc triggered]

═══════════════════════════════════════════

Host Timers (Game.gd or Player.gd host-only)
        |
        +-- Engineer passive heal timer (5 sec)
        |       → proximity check → receive_heal RPC on nearby players
        |
        +-- Earth heal timer (1 sec)
        |       → receive_heal RPC on ALL players
        |       → GameEvents.emit_hud("seat_massage")
        |
        +-- Earth shockwave timer (8 sec)
        |       → Area2D burst → enemy.take_damage + velocity knockback
        |       → GameEvents.emit_hud("seat_massage")
        |
        +-- Fire Burst timer (4 sec, fire element player only)
                → BulletSpawner.spawn x3-5 (orange modulate)
                → GameEvents.emit_hud("engine")

═══════════════════════════════════════════

Ice Trail (owning peer _physics_process, if moving)
        |
        +-- trail_timer decrements
        +-- when <= 0: request_ice_trail.rpc_id(1, global_position)
        +-- host: IceTrailSpawner.spawn({pos: ...}).call_deferred
```

### Recommended Project Structure

```
scenes/
├── Player.gd               # Add: role match block, evolution_stage, _use_role_ability(),
│                           #      _tick_ability(), shield_active, dash_invincible, receive_heal RPC
├── enemies/
│   └── Enemy.gd            # Add: speed_multiplier, burn_timer, apply_burn(), apply_slow()
├── roles/
│   ├── HealDrone.tscn      # New spawnable scene for Engineer drone
│   └── HealDrone.gd        # Drone pulse logic, follow_target (Stage-2)
├── elements/
│   └── IceTrailZone.tscn   # New: small Area2D with 2-sec lifetime
│   └── IceTrailZone.gd     # body_entered → apply_slow on enemy
├── Game.gd                 # Add: DroneSpawner node, IceTrailSpawner node,
│                           #      receive_heal RPC, Earth/Fire passive timers,
│                           #      request_deploy_drone RPC, request_ice_trail RPC
autoloads/
└── GameEvents.gd           # Already wired — no changes needed
project.godot               # Add: role_ability action (Space), change revive E→R
```

### Pattern 1: Role Stats Application in `_ready()`

**What:** Match on `role_label` to set role-specific constants immediately after authority is set.
**When to use:** Player spawn — runs on all peers, so every peer has correct local stats.

```gdscript
# Source: direct extension of existing Player.gd _ready() pattern
func _ready() -> void:
    set_multiplayer_authority(peer_id)
    add_to_group("players")
    if has_node("RoleLabel"):
        $RoleLabel.text = role_label
    # Phase 5 addition: role stats
    _apply_role_stats()
    # Phase 5 addition: element tracking
    element = Lobby.players.get(peer_id, {}).get("element", "")

func _apply_role_stats() -> void:
    match role_label:
        "Tank":
            MAX_HP = 150
            health = 150
        "Speedster":
            SPEED = 280
        "Engineer":
            pass  # HP and speed stay at default; passive wired separately
```

Note: `MAX_HP` and `SPEED` must become `var` (not `const`) in Player.gd to allow role-based mutation. [VERIFIED: codebase inspection — current Player.gd uses `const SPEED: float = 200.0` and `const MAX_HP: int = 100`]

### Pattern 2: Ability Dispatch with Stage Gate

**What:** Single Space keypress handler that routes to Stage-1 or Stage-2 based on `evolution_stage`.
**When to use:** `_physics_process` after existing WeaponManager tick.

```gdscript
# Source: CONTEXT.md D-06, D-20 — extends existing _physics_process pattern
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
    _tick_ability(delta)
    _check_revive(delta)
    _tick_element(delta)    # Ice trail, Fire burst timer

func _tick_ability(delta: float) -> void:
    if _ability_cooldown > 0.0:
        _ability_cooldown -= delta
    # Speedster double-dash window
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

### Pattern 3: Tank Shield — Intercept in `receive_damage`

**What:** Insert shield check before health decrement, mirroring AirbagShield pattern exactly.
**When to use:** Tank role only; shield_active flag checked first.

```gdscript
# Source: AirbagShield pattern in existing Player.gd receive_damage
@rpc("any_peer", "call_remote", "reliable")
func receive_damage(amount: int) -> void:
    # Existing airbag check
    if health - amount <= 0 and has_node("WeaponManager") and $WeaponManager.airbag_active:
        health = 1
        $WeaponManager.consume_airbag()
        return
    # Phase 5 Tank shield check
    if shield_active:
        if evolution_stage >= 2:
            # Stage-2: reflect 50% damage back to last attacker
            _reflect_damage(amount)
        return  # block all damage regardless of stage
    health -= amount
    if health <= 0:
        health = 0
        _enter_downed()
```

**Critical:** `shield_active` must be added to the Player's MultiplayerSynchronizer replication config so other peers see the shield ring visual. [ASSUMED — exact SceneReplicationConfig editing steps depend on Player.tscn structure, not yet read]

### Pattern 4: Host-Authoritative Drone Spawn

**What:** Game.gd DroneSpawner follows exact same pattern as BulletSpawner and PickupSpawner.
**When to use:** Engineer deploys drone (Space key → RPC to host → host spawns).

```gdscript
# Source: Game.gd existing _do_spawn_pickup / PickupSpawner pattern
# In Game.gd _ready():
$DroneSpawner.spawn_function = _do_spawn_drone
$DroneSpawner.add_spawnable_scene("res://scenes/roles/HealDrone.tscn")

func _do_spawn_drone(data: Dictionary) -> Node:
    var drone := HEAL_DRONE_SCENE.instantiate()
    drone.position = data["pos"]
    drone.owning_peer = data["peer_id"]
    drone.stage = data.get("stage", 1)
    drone.name = "HealDrone_%d" % data["peer_id"]
    return drone

@rpc("any_peer", "call_remote", "reliable")
func request_deploy_drone(requester_peer_id: int) -> void:
    if not multiplayer.is_server():
        return
    # Remove existing drone for this player
    for child in get_children():
        if child.name == "HealDrone_%d" % requester_peer_id:
            child.queue_free()
    var player_node := _find_player(requester_peer_id)
    if player_node == null or player_node.is_downed:
        return
    var stage: int = player_node.evolution_stage
    $DroneSpawner.spawn({
        "pos": player_node.global_position,
        "peer_id": requester_peer_id,
        "stage": stage
    })
```

### Pattern 5: Element Proc in Bullet.gd `_on_area_entered`

**What:** After applying bullet damage on the host, check element proc chance for the bullet's owner.
**When to use:** Host-only hit handler — already gated by `is_multiplayer_authority()`.

```gdscript
# Source: CONTEXT.md D-16, D-17, D-18 — extends existing Bullet.gd _on_area_entered
func _on_area_entered(area: Node) -> void:
    if not is_multiplayer_authority():
        return
    var enemy := area.get_parent()
    if not enemy.is_in_group("enemies"):
        return
    if enemy.has_method("take_damage"):
        enemy.take_damage(BULLET_DAMAGE)
    # Phase 5: Element proc (25% chance, owner's element)
    var owner_elem: String = Lobby.players.get(owner_peer_id, {}).get("element", "")
    if owner_elem != "" and randf() < 0.25:
        match owner_elem:
            "fire":
                if enemy.has_method("apply_burn"):
                    enemy.apply_burn()
                if multiplayer.is_server():
                    GameEvents.emit_hud("engine")
            "ice":
                if enemy.has_method("apply_slow"):
                    enemy.apply_slow()
                if multiplayer.is_server():
                    GameEvents.emit_hud("ac")
    queue_free()
```

### Pattern 6: `receive_heal` RPC on Player

**What:** New RPC mirroring `receive_damage` — called by host for Engineer passive and Earth element.
**When to use:** All heal sources (Engineer passive, Engineer drone pulse, Earth +2/sec).

```gdscript
# Source: models receive_damage pattern exactly
@rpc("any_peer", "call_remote", "reliable")
func receive_heal(amount: int) -> void:
    if is_downed:
        return
    health = mini(health + amount, MAX_HP)
```

Called from host via: `player.receive_heal.rpc_id(player.peer_id, amount)` for remote peers, or `player.receive_heal(amount)` for host's own Player node (mirrors the contact-damage host-peer pattern in Enemy.gd lines 91-94).

### Pattern 7: Ice Trail Zone Spawn (call_deferred in physics)

**What:** Ice player tracks position delta; every 0.3 sec of movement, request host to spawn a zone.
**When to use:** Ice element player's `_tick_element(delta)` inside `_physics_process`.

```gdscript
# Source: CONTEXT.md D-18 + existing call_deferred pattern from Game.gd
func _tick_element(delta: float) -> void:
    if element != "ice":
        return
    if velocity.length() < 10.0:  # not moving — no trail
        return
    _ice_trail_timer -= delta
    if _ice_trail_timer <= 0.0:
        _ice_trail_timer = 0.3
        var game := get_node_or_null("/root/Game")
        if game and game.has_method("request_ice_trail"):
            if multiplayer.is_server():
                game.request_ice_trail(global_position)
            else:
                game.request_ice_trail.rpc_id(1, global_position)
```

In Game.gd:
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func request_ice_trail(pos: Vector2) -> void:
    if not multiplayer.is_server():
        return
    $IceTrailSpawner.spawn.call_deferred({"pos": pos})
```

### Anti-Patterns to Avoid

- **Modifying `const` SPEED and MAX_HP:** Current Player.gd declares these as `const`. They must be changed to `var` for role stat mutation. Leaving them as `const` will cause a GDScript error at assignment. [VERIFIED: codebase inspection]
- **Calling spawner.spawn() directly in `_physics_process`:** Always use `call_deferred`. The existing codebase already enforces this pattern in `_on_enemy_died`. Violation causes "Can't change state while flushing queries" crash.
- **Applying element proc on non-host peers:** Bullet.gd already guards `_on_area_entered` with `is_multiplayer_authority()`. Element proc logic must stay inside that guard — do NOT add a separate proc check on the owning peer's side.
- **Forgetting to pre-register HealDrone.tscn and IceTrailZone.tscn in their spawner's `add_spawnable_scene`:** This is Pitfall P7 from the project's established pitfall list. Symptom: spawnable scenes visible on host but not on clients.
- **Tank shield blocking own `receive_damage` on owning peer before host can reflect:** The shield flag check happens on the owning peer's `receive_damage` (because the RPC routes to the owning peer). Reflection must be requested via a separate RPC to host — the shield intercept and the reflection are different operations.
- **Using `is_multiplayer_authority()` for element/ability timers on Drone node:** The Drone's `multiplayer_authority` is the host (default, since host spawns it). All Drone logic runs on host. Do not set authority to the owning engineer peer — keep default host authority on Drone.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spawning HealDrone across all clients | Custom scene instantiation per peer | MultiplayerSpawner (DroneSpawner) | Same pattern as BulletSpawner — one spawn call, all peers get the node automatically |
| Syncing drone position (Stage-2 follow) | Custom RPC to send position each frame | MultiplayerSynchronizer on HealDrone node | Already the pattern for Player position — 20 Hz sync is sufficient |
| Ice slow visual feedback on enemies | Custom shader or animation | `modulate = Color(0.5, 0.7, 1.0)` on Enemy Sprite | Placeholder art style throughout; ColorRect modulate matches codebase |
| Burn DoT timer management | Multiple Timer nodes per status | Single `burn_timer: float` delta-decremented in Enemy.gd `_physics_process` (host-only) | Enemy `_physics_process` already runs host-only (P6 pattern) — use it |
| HUD event routing | Direct Signal connections across scenes | `GameEvents.emit_hud("event_name")` | Already wired autoload signal bus — this is exactly what it's for |
| Shield visual ring | Custom Canvas/Shader | Two ColorRect nodes (outer + inner) mirroring AirbagShield.gd | AirbagShield.gd is the direct model — clone and recolor |

**Key insight:** Every new system in Phase 5 has a direct structural model in Phase 4 code. The pattern is always: timer → host check → RPC to owning peer or enemy. Never invent new patterns when an identical one already exists.

---

## Common Pitfalls

### Pitfall 1: `const` SPEED and MAX_HP Cannot Be Mutated

**What goes wrong:** GDScript `const` values cannot be reassigned. `SPEED = 280` in `_apply_role_stats()` will fail with a compiler error.
**Why it happens:** Player.gd declares both as `const` — correct for the default player but incompatible with role stats.
**How to avoid:** Change `const SPEED: float = 200.0` → `var SPEED: float = 200.0` and `const MAX_HP: int = 100` → `var MAX_HP: int = 100` before adding the role match block.
**Warning signs:** Any attempt to run `_apply_role_stats()` with const values will fail at startup (not runtime — GDScript catches const assignment at parse time).
[VERIFIED: codebase inspection]

### Pitfall 2: HealDrone Authority Must Remain on Host

**What goes wrong:** If `HealDrone.set_multiplayer_authority(engineer_peer_id)` is called at spawn, the drone's MultiplayerSynchronizer will try to replicate FROM the client, which requires that client to own the node. Client-owned spawned nodes have known sync issues in Godot 4.
**Why it happens:** Confusion between "owning player" (engineer's peer) and "scene authority" (who controls the node).
**How to avoid:** Leave HealDrone authority at default (host = peer 1). Store `owning_peer: int` as a data field to identify the engineer. Stage-2 follow logic runs in Drone's `_physics_process` on host only (guarded by `is_multiplayer_authority()`).
**Warning signs:** Drone visible on host but not syncing position to clients; MultiplayerSynchronizer errors in output.
[ASSUMED — based on established project pattern from prior phase decisions D-21]

### Pitfall 3: Tank Shield Reflect Must Route Through Host

**What goes wrong:** The shield reflect (`50% damage back to attacker`) cannot be applied directly from `receive_damage` on the owning peer, because the owning peer doesn't have authority over enemies.
**Why it happens:** Enemy `take_damage()` guards itself with `is_multiplayer_authority()` (Enemy.gd line 64). Only the host can call it.
**How to avoid:** When shield absorbs a hit, the owning peer records `_last_attacker_pos` or sends an RPC to host: `request_reflect.rpc_id(1, attacker_node_path, reflect_amount)`. Host validates and calls `enemy.take_damage(reflect_amount)`.
**Warning signs:** `take_damage` called on non-host peer silently does nothing — reflect appears to work locally but enemies don't lose HP on all clients.
[VERIFIED: codebase inspection — Enemy.gd `take_damage` has explicit `is_multiplayer_authority()` guard]

### Pitfall 4: Ice Trail spawn.call_deferred Race Condition

**What goes wrong:** `IceTrailSpawner.spawn({...})` called directly (without `call_deferred`) inside `_physics_process` causes "Can't change state while flushing queries" or "Can't add child node during physics step" error.
**Why it happens:** The physics step is in the middle of processing when spawner tries to instantiate and add a child.
**How to avoid:** Always route Ice Trail spawn through RPC to host, then use `$IceTrailSpawner.spawn.call_deferred({...})` — exactly as `_on_enemy_died` does for XP orbs.
**Warning signs:** Error in output: "Can't change state while flushing queries" on IceTrail spawn frames.
[VERIFIED: codebase inspection — Game.gd line 96 already uses `spawn.call_deferred`]

### Pitfall 5: Proc Chance Runs on Wrong Peer

**What goes wrong:** Element proc check (`randf() < 0.25`) placed in a code path that runs on both host and clients causes double-proc (both peers independently roll and apply, leading to burn timers firing twice, double damage, double HUD events).
**Why it happens:** Bullet.gd's `_on_area_entered` already guards with `is_multiplayer_authority()` — but if proc logic is placed BEFORE the guard, or in a separate listener, it fires on all peers.
**How to avoid:** Element proc logic must be inside `_on_area_entered`, after the `if not is_multiplayer_authority(): return` guard. No exceptions.
**Warning signs:** Burn timers on enemies ticking twice as fast; HUD indicator firing twice per bullet hit.
[VERIFIED: codebase inspection — Bullet.gd `_on_area_entered` pattern]

### Pitfall 6: Engineer Passive Heal Must Use RPC for Remote Peers

**What goes wrong:** Host calls `player.receive_heal(10)` directly on all Player nodes. This works for the host's own Player node but silently fails for remote peers' Player nodes — only the owning peer should mutate `health` (MultiplayerSynchronizer then replicates it).
**Why it happens:** Same issue as contact damage (Enemy.gd lines 91-94, solved with rpc_id pattern).
**How to avoid:** For each player in the proximity check: if `player.peer_id == multiplayer.get_unique_id()` → call directly; else → `player.receive_heal.rpc_id(player.peer_id, amount)`. Mirror Enemy.gd's contact damage pattern exactly.
**Warning signs:** Engineer passive appears to heal on host's HUD but not on remote clients' health bars.
[VERIFIED: codebase inspection — Enemy.gd lines 91-94 show the correct pattern]

### Pitfall 7: revive InputMap Action Must Be Updated

**What goes wrong:** `_check_revive` in Player.gd checks `Input.is_action_pressed("revive")`. Currently the `revive` action in project.godot is bound to E (physical_keycode=69). D-01 requires it change to R. If project.godot is not updated, the old E binding remains active.
**Why it happens:** project.godot is the authoritative InputMap source. Code references only the action name ("revive"), so the code doesn't change — only the project.godot binding changes.
**How to avoid:** In project.godot, replace the `revive` action's InputEventKey physical_keycode from 69 (E) to 82 (R). Also add `role_ability` action with Space (physical_keycode=32).
**Warning signs:** Pressing R doesn't revive; pressing E still revives; Space does nothing for abilities.
[VERIFIED: codebase inspection — project.godot line 45-50 shows `revive` action with physical_keycode=69 (E)]

---

## Code Examples

Verified patterns from codebase inspection:

### Existing: Host-to-Remote-Peer damage routing (Enemy.gd, model for receive_heal)
```gdscript
# Source: scenes/enemies/Enemy.gd lines 91-94
# Model for any host→player RPC (damage, heal, etc.)
if body.peer_id == multiplayer.get_unique_id():
    body.receive_damage(CONTACT_DAMAGE)
else:
    body.receive_damage.rpc_id(body.peer_id, CONTACT_DAMAGE)
```

### Existing: spawner call_deferred pattern (Game.gd, model for all new spawners)
```gdscript
# Source: scenes/Game.gd line 96
$PickupSpawner.spawn.call_deferred({"type": "xp_orb", "pos": pos})
```

### Existing: host-only visual RPC (HornShockwave.gd, model for Speedster shockwave)
```gdscript
# Source: scenes/weapons/HornShockwave.gd _show_visual RPC
@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_visual(pos: Vector2) -> void:
    var ring := ColorRect.new()
    ring.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
    ring.pivot_offset = Vector2(RADIUS, RADIUS)
    ring.position = pos - Vector2(RADIUS, RADIUS)
    ring.scale = Vector2(0.1, 0.1)
    game.add_child(ring)
    var tween := ring.create_tween()
    tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.35)
    tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
    tween.tween_callback(ring.queue_free)
```

### Existing: Shield visual ring construction (AirbagShield.gd, model for Tank shield)
```gdscript
# Source: scenes/weapons/AirbagShield.gd activate()
# Two ColorRects: outer colored ring + transparent inner to create hollow ring
_ring = ColorRect.new()
_ring.color = Color(1.0, 1.0, 0.0, 0.85)  # change to blue/white for Tank
var outer_size: float = (RING_RADIUS + RING_THICKNESS) * 2.0
_ring.size = Vector2(outer_size, outer_size)
_ring.pivot_offset = Vector2(outer_size / 2.0, outer_size / 2.0)
_ring.position = Vector2(-outer_size / 2.0, -outer_size / 2.0)
_ring_inner = ColorRect.new()
_ring_inner.color = Color(0, 0, 0, 0)  # transparent cutout
```

### Existing: Spawner pre-registration (Game.gd, model for DroneSpawner)
```gdscript
# Source: scenes/Game.gd _ready()
$PickupSpawner.spawn_function = _do_spawn_pickup
$PickupSpawner.add_spawnable_scene("res://scenes/pickups/XpOrb.tscn")
$PickupSpawner.add_spawnable_scene("res://scenes/pickups/CarPartPickup.tscn")
```

### Existing: GameEvents.emit_hud (GameEvents.gd)
```gdscript
# Source: autoloads/GameEvents.gd
func emit_hud(event_name: String) -> void:
    hud_event.emit(event_name)
# Phase 5 call sites wrap in: if multiplayer.is_server():
#   GameEvents.emit_hud("engine")   # Fire
#   GameEvents.emit_hud("ac")       # Ice
#   GameEvents.emit_hud("seat_massage")  # Earth
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Player SPEED/MAX_HP as const | Must change to var for role stats | Phase 5 | Small Player.gd change required |
| No role ability key | Add `role_ability` action (Space) in project.godot | Phase 5 | One line in project.godot |
| Revive on E key | Change to R (physical_keycode 82) in project.godot | Phase 5 (D-01) | String constant in project.godot only |
| evolution_stage absent | Add `var evolution_stage: int = 1` to Player.gd | Phase 5 (D-04) | Must add to MultiplayerSynchronizer config if Stage-2 shield visual is peer-visible |

**Key state from existing code:**
- `project.godot` currently has `revive` action on physical_keycode=69 (E). Needs change to 82 (R). [VERIFIED]
- `project.godot` has NO `role_ability` action. Must be added with Space (physical_keycode=32). [VERIFIED]
- `Player.gd` declares `const SPEED: float = 200.0` and `const MAX_HP: int = 100`. Must be `var`. [VERIFIED]
- `GameEvents.emit_hud()` exists and works — no changes needed to autoload. [VERIFIED]
- `Lobby.players[peer_id].element` is the correct access path for element string. [VERIFIED]
- `Enemy.gd` has no `speed_multiplier`, no `burn_timer`, no `apply_burn`/`apply_slow` methods. All must be added. [VERIFIED]
- `Game.gd` has no `DroneSpawner`, no `IceTrailSpawner`, no `request_deploy_drone`, no `request_ice_trail` RPCs. [VERIFIED]
- `Player.gd` has no `receive_heal` RPC. Must be added. [VERIFIED]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | HealDrone MultiplayerSynchronizer can sync position without setting authority to engineer peer | Pitfall 2 | If wrong: need client-owned drone approach (more complex) |
| A2 | Player.tscn SceneReplicationConfig can be extended at editor time to include `shield_active` and `evolution_stage` without breaking existing sync | Pattern 3 | If wrong: need separate RPC broadcast for shield visual |
| A3 | `IceTrailZone.tscn` as a separate spawnable scene via IceTrailSpawner is feasible; alternative is direct `add_child` on host with no client replication (trail only visual on host) | Architecture | If wrong: ice trail only visible on host — acceptable for placeholder since enemies are host-simulated |

---

## Open Questions (RESOLVED)

1. **Does Player.tscn's MultiplayerSynchronizer currently list specific variable names, or does it use the "All" replication mode?**
   - What we know: The sync works for `health` and `is_downed` (confirmed from prior phases).
   - What's unclear: Whether adding `shield_active`, `evolution_stage`, `dash_invincible` requires manual SceneReplicationConfig editing in the Godot editor (property list approach) or whether there's a script-based way to extend it.
   - Recommendation: The implementer should read Player.tscn's replication config before the first wave that needs `shield_active` visible to peers.
   - **RESOLVED → Plan 05-01 Task 3:** Explicitly edits Player.tscn SceneReplicationConfig to append `shield_active`, `evolution_stage`, `dash_invincible` as replicated properties.

2. **Should Ice Trail zones replicate to clients or stay host-only?**
   - What we know: Ice Trail slows enemies, which are host-simulated. Clients never need the zone for gameplay logic.
   - What's unclear: Whether the visual (light-blue Area2D) on clients is needed for player feedback.
   - Recommendation: Start with host-only (no spawner, direct `add_child` on host). If playtest shows it's confusing, add a client-facing visual later.
   - **RESOLVED → Plan 05-05 Task 1:** Uses `$IceTrailSpawner` (MultiplayerSpawner) so zones replicate to clients for visual feedback.

3. **How does the host know which enemy attacked the Tank (for shield reflection)?**
   - What we know: `receive_damage` is called by Enemy.gd via `rpc_id(body.peer_id, CONTACT_DAMAGE)`. The call comes from the enemy node.
   - What's unclear: Inside `receive_damage` on the owning peer, there is no parameter for "which enemy caused this." The host has already sent the RPC — the owning peer only knows the amount.
   - Recommendation: Extend `receive_damage(amount: int)` signature to `receive_damage(amount: int, attacker_path: String = "")` — host passes `enemy.get_path()` as a string. Owning peer, on shield intercept, sends `request_reflect.rpc_id(1, attacker_path, reflect_amount)` to host. Host resolves path to node and calls `take_damage`.
   - **RESOLVED → Plan 05-02 Task 1:** Extends `receive_damage` signature to `receive_damage(amount: int, attacker_path: String = "")` exactly per this recommendation.

---

## Environment Availability

> Step 2.6: SKIPPED. Phase 5 is pure GDScript code changes within the existing Godot 4 project. No external tools, CLIs, services, or runtimes beyond what Phase 4 already used.

---

## Validation Architecture

> nyquist_validation is explicitly set to false in .planning/config.json. Section skipped.

---

## Security Domain

> This is a LAN-only game with no internet exposure, no user authentication, no stored credentials, and no PII processing. ASVS categories are not applicable. The project's own security model is the host-authoritative RPC guard (P3: `is_multiplayer_authority()` and `multiplayer.is_server()` guards on all state-changing calls).

---

## Sources

### Primary (HIGH confidence — direct codebase inspection)
- `scenes/Player.gd` — `const SPEED`, `const MAX_HP`, `receive_damage`, `_check_revive`, authority guard pattern
- `scenes/weapons/WeaponManager.gd` — `tick(delta)` pattern, `_fire_screws()` as Fire Burst model
- `scenes/weapons/AirbagShield.gd` — Shield ring visual construction model for Tank shield
- `scenes/weapons/HornShockwave.gd` — Visual RPC pattern, Area2D burst model for shockwave effects
- `scenes/enemies/Enemy.gd` — `take_damage()` authority guard, `receive_damage` rpc_id pattern (lines 91-94), missing status effect fields confirmed
- `scenes/Game.gd` — Spawner registration pattern, `request_fire` RPC model, `call_deferred` pattern
- `scenes/projectiles/Bullet.gd` — `_on_area_entered` host-only hit handler, element proc insertion point
- `autoloads/Lobby.gd` — `players[peer_id].element` access pattern confirmed
- `autoloads/GameEvents.gd` — `emit_hud(event_name)` confirmed wired
- `project.godot` — Current InputMap confirmed: `revive` on E (physical_keycode=69), no `role_ability` action

### Secondary (MEDIUM confidence)
- `.planning/phases/05-roles-elements/05-CONTEXT.md` — All locked decisions (D-01 through D-21)
- `.planning/phases/04-weapons-and-item-pickups/04-CONTEXT.md` — Phase 4 architectural decisions that Phase 5 extends

### Tertiary (LOW confidence)
- None in this research. All claims derive from direct file inspection.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Godot 4.6, no new external dependencies, pure GDScript
- Architecture: HIGH — All patterns verified against existing Phase 4 code
- Pitfalls: HIGH — Each pitfall confirmed against specific file lines in the codebase

**Research date:** 2026-06-15
**Valid until:** End of Phase 5 implementation (stable codebase — no version drift risk)
