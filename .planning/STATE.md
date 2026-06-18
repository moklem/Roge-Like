---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: ready_to_execute
last_updated: "2026-06-18T00:00:00.000Z"
stopped_at: "Phase 6 planned — 4 plans ready"
resume_file: ".planning/phases/06-xp-level-up-cards-and-evolution/06-01-PLAN.md"
progress:
  total_phases: 8
  completed_phases: 5
  total_plans: 23
  completed_plans: 19
  percent: 63
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-05)

**Core value:** The CARIAD HUD must always fire convincingly — every major game event triggers the corresponding vehicle sensor indicator, making the gameplay feel like a real in-car system demo

**Current focus:** Phase 06 — xp-level-up-cards-and-evolution

---

## Current Phase

**Phase 6: XP, Level-Up Cards & Evolution**
Status: Ready to execute
Planned: 2026-06-18
Plans: 0/4 complete

### Phase Goal

Per-player progression loop — kill enemies to earn XP, level up triggers card pick, stage transforms appearance and unlocks ability

### Plans

- [ ] 06-01 (Wave 1): XP state vars + receive_xp RPC + XpOrb grant + MultiplayerSynchronizer + GameState reset
- [ ] 06-02 (Wave 2): PlayerHUD.tscn/gd (XP bar CanvasLayer) + CardOverlay.tscn/gd (card selection UI)
- [ ] 06-03 (Wave 3): Card flow wiring + evolution stage logic + confirm_card_pick RPC + airbag migration
- [ ] 06-04 (Wave 4): All 6 weapon Level 2/3 stat scaling + stage3_damage_mult + Earth element_tier

### Stopped At

Phase 6 planning complete (4 plans, 4 waves). Ready to execute.

---

## Previous Phase

**Phase 5: Roles & Elements**
Status: Complete
Started: 2026-06-15
Completed: 2026-06-15
Plans: 5/5 complete

### Phase Goal

Three mechanically distinct player roles (Tank, Speedster, Engineer) with Stage-1 and Stage-2 abilities; Fire/Ice/Earth element modifiers; element actions trigger CARIAD HUD indicators.

### Plans

- [x] 05-01 (Wave 1): Foundation — InputMap (R/Space), Player.gd scaffold, Player.tscn replication, Enemy.gd status effects
- [x] 05-02 (Wave 2): Role abilities — Tank shield, Speedster dash, Engineer deploy dispatch
- [x] 05-03 (Wave 2): Engineer HealDrone scene + Game.gd drone spawn + Engineer passive heal
- [x] 05-04 (Wave 3): Fire/Ice element procs on Bullet.gd + Player._tick_element
- [x] 05-05 (Wave 3): IceTrailZone scene + Earth heal/shockwave + force_burn wiring

### Stopped At

05-05 complete (9e312ba, f6559d2). Phase 5 fully complete. ELEM-04 through ELEM-07 implemented.

---

## Previous Phase

**Phase 4: Weapons & Item Pickups**
Status: Complete
Started: 2026-05-31
Completed: 2026-05-31
Plans: 5/5 complete

### Phase Goal

Vampire Survivors weapon loop — enemies drop car-part pickups (25% chance), players collect to unlock up to 6 auto-firing car-themed weapons.

### Plans

- [x] 04-01 (Wave 1): CarPartPickup scene + PickupSpawner wiring + 25% drop branch in Game.gd
- [x] 04-02 (Wave 2): WeaponManager scaffold + ScrewsAndBolts migration + Player.gd refactor
- [x] 04-03 (Wave 3): ExhaustFlames + SpinningTires weapon implementations
- [x] 04-04 (Wave 4): AntennaBeam + HornShockwave weapon implementations
- [x] 04-05 (Wave 5): AirbagShield visual + GameState death reset

### Stopped At

04-05 complete (d951fa6, 1dc72dd). Phase 4 complete. Ready for Phase 5.

---

## Phase History

### Phase 4: Weapons & Item Pickups

Status: Complete
Started: 2026-05-31
Completed: 2026-05-31

**Plans:** 04-01 through 04-05 (4 waves)
**Commits:** b47997f, ad402fc, 0a552e8, d031a82, 45b1459, bde4191, be0c1d1, 88e2338, d951fa6, 1dc72dd, 195743d
**Summary:** CarPartPickup scene (25% enemy drop, host-authoritative collection, W1 double-collect guard); WeaponManager child of Player with ScrewsAndBolts migration, 6-slot cap, weapon_level dict; 5 car-themed weapons implemented (ExhaustFlames cone, SpinningTires orbit, AntennaBeam piercing, HornShockwave 360° burst, AirbagShield death-prevention charge); GameState._broadcast_game_over resets all WeaponManagers on game-over (WEAP-08).

### Phase 3: Room 1, Enemy AI, Combat Core

Status: Complete
Started: 2026-05-09
Completed: 2026-05-09

**Plans:** 03-01 through 03-05 (4 waves)
**Commits:** 67ee1db, c051da6, fa19ced, 5cb622b
**Summary:** NavigationAgent2D navmesh baked; Enemy with chase AI + contact damage; XpOrb pickup; Player health/downed/revive state machine; Bullet auto-fire projectiles; Game.gd with all 3 MultiplayerSpawners, enemy death → orb drop, request_fire and attempt_revive RPCs; GameState game-over broadcast.

### Phase 2: Player Movement & Sync

Status: Complete
Started: 2026-05-09
Completed: 2026-05-09

**Plans:** 02-01 (Player movement & collision), 02-02 (Role labels & cross-peer spawning)
**Commits:** 3bb04fd, 651d64e, 66e76bc, e6b9e66
**Summary:** CharacterBody2D player with WASD movement, wall collision, MultiplayerSynchronizer at 20 Hz, host-authoritative spawning, role labels above characters.

### Phase 1: Network Foundation & Lobby

Status: Complete
Started: 2026-05-05
Completed: 2026-05-09

**Plans:** 01-01 (Autoloads + project config), 01-02 (Lobby UI)
**Summary:** ENet multiplayer foundation, Lobby/Game autoloads, lobby UI with role/element pick, ready-up, player list.

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases complete | 4 / 8 (Phase 5 complete, not yet counted in phase total) |
| Phase 5 plans shipped | 5 / 5 |
| v1 requirements shipped | ~32 / 84 (ELEM-04 through ELEM-07 added) |
| Active blockers | 0 |

---

## Active Decisions

See .planning/PROJECT.md → Key Decisions for the full decision log.

**Highlights relevant to Phase 1:**

- Host-authoritative model — ENet, no third-party libs, no host migration
- Driver is NPC auto-system — only 3 human players; HUD fires from game events
- Host disconnect = game over for all clients (no migration)
- Elements are a separate pick from role — chosen in lobby same screen as role

**Phase 4 decisions (04-01):**

- weapon_unlocked RPC lives on Game.gd (not Player.gd) with @rpc("authority") to avoid changing Player RPC checksum
- CarPartPickup spawns at pos + Vector2(10, 0) to avoid exact overlap with XpOrb on same death position
- Both XpOrb and CarPartPickup pre-registered with add_spawnable_scene in _ready() (P7 compliance)

**Phase 4 decisions (04-02):**

- WeaponManager.tick() receives delta from Player._physics_process — no separate _process hook needed
- add_weapon() silently caps (D-15) and ignores duplicates (D-01); airbag re-arm special case via bool check (D-13)
- weapon_level dict initialized at 1 on unlock — Phase 6 card picks will increment (D-02)
- Defensive `has_node("WeaponManager")` guard in Player.gd fire delegation protects solo scene editor tests

**Phase 4 decisions (04-03):**

- ExhaustFlames cone direction is -aim_dir (rear arc) matching D-09 "exhaust fires backward"
- SpinningTires orbit position update runs on all peers; D-14 is_multiplayer_authority() guard only on damage loop
- call_deferred used for both add_child and activate to avoid physics state mutation from pickup collection path
- WeaponManager.reset() deactivates all 4 timer weapons by name (Plan 04 entries guarded by has_node)

**Phase 4 decisions (04-04):**

- AntennaBeam uses long Area2D (not RayCast2D) — collision_mask=4 gives wall-piercing and all-enemy hit in one get_overlapping_bodies() call
- HornShockwave ring visual adds to player.get_parent() (Game scene) for world-space rendering; null check on get_parent() prevents crash
- Both antenna_beam and horn_shockwave use two-level security: W2 authority guard + is_server() damage guard
- WeaponManager.reset() already covered both node_names from Plan 03 — no changes needed to reset()

**Phase 5 decisions (05-01):**

- revive action rebound to R (physical_keycode=82); role_ability action added on Space (physical_keycode=32) — D-01/D-02
- const SPEED/MAX_HP converted to var so role match block can mutate them (Pitfall 1)
- Tank: MAX_HP=150/health=150 (ROLE-01); Speedster: SPEED=280 (ROLE-04); Engineer: defaults
- evolution_stage/shield_active/dash_invincible added to Player MultiplayerSynchronizer SceneReplicationConfig (T-05-03)
- receive_heal and set_evolution_stage RPCs use @rpc("any_peer","call_remote","reliable") — mirrors receive_damage pattern
- apply_burn/apply_slow on Enemy.gd called host-only; _tick_status_effects runs under P6 physics_process guard

**Phase 4 decisions (04-05):**

- AirbagShield ring uses two overlapping ColorRects (outer yellow + transparent inner) centered on Player via WeaponManager child-node hierarchy
- consume_airbag() encapsulates both flag clear and ring hide — Player.gd delegates instead of writing airbag_active directly
- GameState._broadcast_game_over resets all WeaponManagers via players group loop before scene change (call_local ensures per-peer execution)

**Phase 5 decisions (05-02):**

- receive_damage extended with optional attacker_path: String = "" (Open Question 3); reflection skipped when empty (best-effort)
- dash_invincible checked BEFORE airbag check in receive_damage — i-frames ignore all damage per D-11
- request_reflect RPC guards multiplayer.is_server() (T-05-04); enemy.take_damage only runs on host
- _spawn_dash_shockwave splits visual (call_local RPC) from damage (host-only loop) — T-05-05 mitigation
- _shield_ring ColorRect created once and reused via .visible toggle (mirrors AirbagShield.gd pattern)
- Engineer ability has_method("request_deploy_drone") guard — safe to ship before Plan 03

**Phase 5 decisions (05-03):**

- DroneSpawner spawn_path set to Room1/Entities matching all other MultiplayerSpawner siblings
- HealDrone authority stays on host (Pitfall 2); owning_peer is data field only — never transferred
- _tick_engineer_passive in Game.gd _process (host-guarded) keeps all drone/spawn logic co-located in Game.gd
- Engineer passive heals OTHER players only (not the Engineer themselves) matching D-13 — 200px proximity
- Drone visual is green 20x20 ColorRect — intentional placeholder art per PROJECT.md policy

**Phase 5 decisions (05-04):**

- force_burn @export on Bullet.gd bypasses 25% proc gate for Fire Burst projectiles (D-17)
- Element proc placed after take_damage, before queue_free, inside existing authority guard (Pitfall 5 compliance, T-05-11 mitigation)
- fire_burst: true dict key passed in BulletSpawner spawn data; Plan 05 _do_spawn_bullet reads it to set b.force_burn
- Ice Trail guard: velocity.length() < 10 prevents trail spawn when idle (D-18)
- request_ice_trail call guarded by has_method — safe before Plan 05 adds it to Game.gd
- All GameEvents.emit_hud() calls wrapped in multiplayer.is_server() (T-05-14 HUD dedup mitigation)
- _find_nearest_enemy_global() helper cloned from WeaponManager._find_nearest_enemy using self.global_position

**Phase 5 decisions (05-05):**

- IceTrailZone _slow_timer overridden to 1.5s after apply_slow() — trail slow is shorter than direct slow per D-18
- request_ice_trail emits emit_hud("ac") on host directly (not inside IceTrailZone) — host-only per T-05-18
- _tick_earth_effects appended to existing _process host-guard block — no new _process needed
- _show_earth_shockwave uses call_local so host renders the visual ring
- request_fire force_burn param defaults false — all existing screws/bolts callers remain valid (backward compatible)
- Earth shockwave checks is_instance_valid + is_queued_for_deletion before velocity write (post-death safety)

---

### Architectural Conventions (from research)

- **Three autoloads:** `Lobby` (connection lifecycle), `GameEvents` (HUD signal bus), `GameState` (authoritative run state)
- **RPC discipline (P1):** All `@rpc` annotations must be identical on both host and client at same NodePath — establish this in Phase 1 before any gameplay code
- **Authority guard rule (P3):** If it changes game state, guard it with `is_multiplayer_authority()`
- **Bullet sync (P5):** MultiplayerSpawner for instantiation + initial velocity; clients simulate locally; host sends RPC on hit
- **Sync interval:** MultiplayerSynchronizer `replication_interval = 0.05` (20 Hz, not per-frame)
- **Navmesh spike:** Do a 30-min NavigationAgent2D + TileMap baking spike before committing Room 1 geometry in Phase 3

### Pending Design Decisions

- Phase 7: Per-role ability specs (range, cooldown, AoE shape), Stage 2 signature mechanics, element modifier tuning
- Phase 8: Boss phase thresholds, HP scaling per loop, mob wave counts and composition

---

## Blockers

(None)

---

## Run Notes

Project initialized 2026-05-05. Research complete (HIGH confidence). Roadmap written 2026-05-05. Ready for Phase 1 planning.
