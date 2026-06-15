# Phase 5: Roles & Elements - Context

**Gathered:** 2026-06-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver three mechanically distinct player roles (Tank, Speedster, Engineer) with role-specific passive stats and Stage-1 active abilities (Space bar); implement Stage-2 signature ability variants gated behind `evolution_stage >= 2` (always false until Phase 6 sets it); add three element modifiers (Fire, Ice, Earth) as passive effects that trigger automatically from ScrewsAndBolts hits or on a timer. Element abilities fire CARIAD HUD indicators (ELEM-07). Revive key changes from E to R (input map update).

Phase 4's WeaponManager, Player.gd, and authority patterns are the foundation; role/element logic extends them without restructuring the network layer.

</domain>

<decisions>
## Implementation Decisions

### Key Bindings (changed from original setup)

- **D-01:** Revive key changes from **E → R** (`revive` action in Godot InputMap). Player.gd `_check_revive` references the action name only — a string change suffices, no logic change.
- **D-02:** Role ability (Stage-1 and Stage-2) maps to **Space** (`role_ability` input action). Space replaces Stage-1 when Stage-2 unlocks — same key, stronger variant.
- **D-03:** All element abilities are **passive** — no dedicated element key. Fire, Ice, Earth effects trigger automatically from game events (projectile hit, timer, position trail). No player input required for elements.

### Role Stats Architecture

- **D-04:** `evolution_stage: int = 1` added to **Player.gd** alongside `health` and `is_downed`. Phase 6 sets it via RPC when XP threshold is reached. Ability code checks `if evolution_stage >= 2:` — evaluates false until Phase 6.
- **D-05:** Role-specific stats are applied in Player.gd `_ready()` using a match block on `role_label`. No separate resource file — constants dict in Player.gd.
- **D-06:** Ability cooldowns live in Player.gd (one `_ability_cooldown: float` timer, reset on use). Authority guard: only owning peer reads Space input; sends RPC to host; host executes effect and syncs result.

### Tank Role

- **D-07:** Tank max HP = **150** (vs. 100 default). Set in `_ready()` via role match: `MAX_HP = 150; health = 150`.
- **D-08:** Tank Stage-1 ability (Space, ROLE-02 redesigned): **3-second full damage shield.** While active: all incoming damage is blocked (0 damage). Visual: colored ring around player (different color from AirbagShield). Cooldown: **8 seconds** after shield expires.
- **D-09:** Tank Stage-2 (ROLE-03): same Space key — **6-second shield** + **damage reflection**: each blocked hit deals 50% of the blocked damage back to the attacker (enemy that hit the player). Host validates reflection and applies damage via enemy `receive_damage`.

### Speedster Role

- **D-10:** Speedster base speed = **280** (vs. 200 default). Set in `_ready()` via role match: `SPEED = 280`.
- **D-11:** Speedster Stage-1 ability (Space, ROLE-05): **0.3-second speed burst** — velocity = `direction * SPEED * 3.0`, Invincibility Frames (ignore all incoming damage for 0.3 sec). Cooldown: **4 seconds**.
- **D-12:** Speedster Stage-2 (ROLE-06): **Double Dash** — after the first dash, a second dash is available within **0.8 seconds** (window timer). The second dash triggers a **shockwave landing** at the endpoint: Area2D (~80px radius), ~25 damage to all enemies inside, knockback. If second dash not used within 0.8 sec, normal cooldown resumes.

### Engineer Role

- **D-13:** Engineer passive (ROLE-07): Every **5 seconds**, +10 HP healed to all teammates within **200px radius**. Host-authoritative: host checks proximity and calls `receive_heal` RPC on each nearby Player. Engineer HP stays at default 100.
- **D-14:** Engineer Stage-1 ability (Space, ROLE-08 redesigned): **Deploy Heal Drone** at current position. Drone is a spawnable scene (host spawns, visible to all clients). Drone pulses every **3 seconds**: +15 HP to all players (including Engineer) within **150px radius**. Maximum 1 drone active; deploying a new one removes the old one.
- **D-15:** Engineer Stage-2 (ROLE-09): Stage-2 drone **follows the Engineer** (instead of staying fixed). Stats upgrade: +25 HP per pulse, **200px radius**. Same 3-second pulse interval. Implementation: Stage-2 drone has a `follow_target: NodePath` set to the Engineer; updates position each `_physics_process` tick (host-authoritative movement).

### Element Modifiers

- **D-16:** Element effects trigger exclusively from **ScrewsAndBolts projectile hits** with a **25% proc chance** per hit. No other weapon or damage source triggers element effects.
- **D-17:** **Fire element (ROLE has Fire element selected):**
  - ELEM-01 (Burn DoT): 25% proc on ScrewsAndBolts hit → enemy burns for **5 damage/sec for 3 seconds** (total 15 damage). Burn status tracked on Enemy.gd with a Timer. Multiple burns don't stack — refresh duration.
  - ELEM-02 (Fire Burst, redesigned): Every **4 seconds**, automatic burst of **3-5 ScrewsAndBolts-style projectiles** aimed at nearest enemy. These projectiles have fire color (orange/red `modulate`) and apply **100% Burn proc** on hit. Host spawns them via existing `request_fire` / spawner path.
- **D-18:** **Ice element:**
  - ELEM-03 (Slow): 25% proc on ScrewsAndBolts hit → enemy slowed to **50% movement speed for 2 seconds**. Implemented as `speed_multiplier` float on Enemy.gd, reset after duration.
  - ELEM-04 (Ice Trail): Ice player leaves frost zones along their movement path. Implementation: every 0.3 seconds of movement, spawn a small Area2D at current position (lifetime 2 seconds). Enemies that enter the Area2D are slowed (same 50% slow, 1.5 sec). Host spawns trail zones; despawns after lifetime.
- **D-19:** **Earth element:**
  - ELEM-05 (Team Heal): Passive +2 HP/sec healed to all players (no proximity requirement). Host ticks a timer and calls `receive_heal` on all Player nodes each second.
  - ELEM-06 (Shockwave): Triggered automatically every **8 seconds** (no player input). Area2D burst (~120px radius) around the Earth player. All enemies inside are pushed back (impulse via `velocity +=` on Enemy.gd) + take ~15 damage. Host-authoritative.
  - ELEM-07: All element ability activations (Fire Burst, Ice Trail spawn, Earth Shockwave, Burn proc) call `GameEvents.emit_hud()` with the appropriate HUD string. Fire → `"engine"`, Ice → `"ac"`, Earth → `"seat_massage"`. Wrapped in `if multiplayer.is_server():` guard.

### Stage-2 Gate

- **D-20:** `evolution_stage` starts at 1 in Player.gd. Ability dispatch in `_use_role_ability()`: `if evolution_stage >= 2: _use_stage2_ability() else: _use_stage1_ability()`. Phase 6 sets `evolution_stage = 2` or `3` via `set_evolution_stage` RPC on Player.

### Engineer Drone Architecture

- **D-21:** Drone is a **separate spawnable scene** (HealDrone.tscn), registered in Game.gd's spawner. Host spawns it via `$DroneSpawner.spawn()`. Drone has:
  - `owning_peer: int` (set at spawn time, used for Stage-2 follow logic)
  - `pulse_timer: Timer` (3 sec interval, `autostart = true`)
  - Stage-1: static position; Stage-2: `_physics_process` sets `global_position = owner_player.global_position` (host only, synced via MultiplayerSynchronizer on the Drone node).

### Claude's Discretion

- Exact damage value for Tank shield reflection (starting point: 50% of blocked damage, min 5)
- Exact cooldown for Fire Burst auto-timer (starting point: 4 seconds)
- Burn/Slow visual indicators on enemies (color modulate — orange for burn, blue for slow)
- Ice Trail zone visual (small light-blue Area2D ColorRect, semi-transparent)
- Drone visual (small colored circle following/staying, distinct from SpinningTires)
- Speedster shockwave visual (brief yellow ring expansion at dash landing point)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior Phase Architecture

- `.planning/phases/01-network-foundation-and-lobby/01-CONTEXT.md` — Three-autoload pattern (Lobby/GameEvents/GameState), RPC discipline rules
- `.planning/phases/02-player-movement-and-sync/02-CONTEXT.md` — Player spawning, MultiplayerSynchronizer at 20 Hz, authority guards
- `.planning/phases/03-room-1-enemy-ai-combat-core/03-CONTEXT.md` — PickupSpawner pattern, host-authoritative spawn, bullet/projectile authority
- `.planning/phases/04-weapons-and-item-pickups/04-CONTEXT.md` — WeaponManager architecture (D-06–D-16), authority pattern for weapon fire, airbag charge pattern (model for shield)

### Live Code (read before modifying)

- `scenes/Player.gd` — `SPEED`, `MAX_HP`, `receive_damage`, `_check_revive` (E→R rename), `is_multiplayer_authority()` guard pattern, `has_node("WeaponManager")` delegation pattern
- `scenes/weapons/WeaponManager.gd` — `tick(delta)` pattern, authority guard in `tick`, `_fire_screws()` → model for Fire Burst
- `autoloads/Lobby.gd` — `players` Dictionary stores `role` and `element` per peer — Phase 5 reads these in Player `_ready()` to set stats
- `autoloads/GameEvents.gd` — `emit_hud(event_name: String)` — call this on every element ability activation
- `scenes/enemies/Enemy.gd` — `receive_damage` RPC pattern, movement speed (need to add `speed_multiplier` for Ice Slow)
- `scenes/Game.gd` — `$DroneSpawner` (new, to add alongside PickupSpawner), `request_fire` RPC pattern

### Project Requirements

- `.planning/REQUIREMENTS.md` §Roles (ROLE-01–10) and §Elements (ELEM-01–07) — 17 requirements this phase must satisfy
- `.planning/ROADMAP.md` §Phase 5 — goal, success criteria, pitfall watch (P3 authority guards, P12 input authority)
- `.planning/PROJECT.md` — CARIAD HUD is core value; every element action must fire HUD; host-authoritative model; placeholder art only

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`WeaponManager.tick(delta)`** — Model for role ability cooldown ticking. Phase 5 adds `_ability_cooldown` timer to Player.gd using the same pattern.
- **`_fire_screws()` in WeaponManager.gd** — Fire Burst (ELEM-02) reuses this exact spawn path with fire-colored projectiles.
- **`AirbagShield` in WeaponManager.gd** — `airbag_active: bool` and damage intercept in `receive_damage` is the model for Tank shield. Tank shield uses same intercept point but with timer instead of one-shot.
- **`XpOrb.gd` + PickupSpawner pattern** — Heal Drone uses the same host-spawn / MultiplayerSynchronizer pattern.
- **`GameEvents.emit_hud()`** — Already wired. Phase 5 just calls it from element trigger sites.
- **`Lobby.players` dict** — `Lobby.players[multiplayer.get_unique_id()].role` and `.element` give the role/element strings in Player `_ready()`.

### Established Patterns

- **Host-authoritative spawn:** Only host calls `spawner.spawn()`. HealDrone scene must be pre-registered in DroneSpawner's spawnable list before testing.
- **`is_multiplayer_authority()` guard:** All ability trigger logic (cooldown tick → activate) runs inside this guard on the owning peer's Player.
- **RPC chain: client input → host execute → sync result:** Ability activation follows same chain as weapon fire. Owning peer detects Space press → `request_ability.rpc_id(1)` → host executes damage/heal/shield effect → MultiplayerSynchronizer propagates state.
- **`call_deferred` for spawn in physics callbacks:** Any spawner calls from `_physics_process` (e.g., Ice Trail) must use `spawn.call_deferred(...)`.
- **20 Hz MultiplayerSynchronizer on Player:** `evolution_stage`, `shield_active`, `dash_invincible` need to be added to Player's replication config if other peers need to see them (e.g., shield visual ring visible to all).

### Integration Points

- **Player.gd `_ready()`:** Add role match block to set `SPEED`/`MAX_HP` from `Lobby.players[peer_id].role`; set `element` var from `.element`.
- **Player.gd `receive_damage`:** Insert shield check before damage application (same slot as airbag check in WeaponManager's receive_damage intercept path).
- **Player.gd `_physics_process`:** Add `_tick_ability(delta)` call (after WeaponManager.tick); add Ice Trail spawn logic.
- **Enemy.gd:** Add `speed_multiplier: float = 1.0` and `burn_timer` / `slow_timer` for element DoT/Slow status.
- **Game.gd:** Add `$DroneSpawner` node; pre-register HealDrone.tscn; add `receive_heal` RPC callable on Player; add Earth passive heal timer.
- **InputMap (project.godot):** Change `revive` action from E to R; add `role_ability` action on Space.

</code_context>

<specifics>
## Specific Ideas

- **Tank shield visual:** Colored ring (different color from AirbagShield yellow — suggest blue or white). Ring visible to all peers via MultiplayerSynchronizer `shield_active: bool` on Player.
- **Speedster double-dash window:** A `_dash_window_timer: float` in Player.gd. After first dash: `_dash_window_timer = 0.8`. Each frame: if `_dash_window_timer > 0` and Space pressed → trigger second dash + shockwave. If timer expires → normal cooldown.
- **Fire Burst (ELEM-02) fire color:** Set `modulate = Color(1.0, 0.5, 0.0)` on spawned Bullet nodes (orange). Host sets modulate after spawn via the existing bullet scene.
- **Ice Trail zone:** Small ColorRect (40×40px, light blue, alpha 0.5) as Area2D child. Lifetime 2 seconds, then `queue_free()`. Enemies' `body_entered` signal applies slow.
- **Engineer drone visual:** Small circle (white or green, ~20px radius), distinct from SpinningTires (which are ~10px, colored per weapon). Stage-2 drone follows engineer — same visual but moves.
- **Proc chance implementation:** In WeaponManager `_fire_screws()` (or at enemy `receive_damage` call site), after confirming hit: `if Lobby.players[get_parent().peer_id].element == "fire" and randf() < 0.25: apply_burn(enemy)`.

</specifics>

<deferred>
## Deferred Ideas

- **Elemental combo interactions (e.g., Fire + Ice = Steam):** Explicitly out of scope per PROJECT.md. Future v2.
- **Per-role visual differentiation beyond color:** Placeholder shapes only in this build. Sprites/animations deferred to production polish.
- **Tank shield reflecting AOE damage (e.g., HornShockwave):** Reflection logic only applies to direct enemy contact and single-target hits in Phase 5. Area-of-effect reflection is v2 scope.
- **Multiple drones (Engineer):** Only 1 drone active at a time in Phase 5. Multi-drone support (Engineer upgrade card) is Phase 6 card scope.

</deferred>

---

*Phase: 5-roles-elements*
*Context gathered: 2026-06-15*
