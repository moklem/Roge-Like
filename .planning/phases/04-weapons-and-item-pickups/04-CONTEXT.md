# Phase 4: Weapons & Item Pickups - Context

**Gathered:** 2026-05-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the Vampire Survivors weapon loop: enemies drop car-part item pickups on death, players collect them to unlock up to 6 auto-firing weapons. All 5 required car-themed weapons are implemented with correct damage patterns (simple visual shapes). Weapon level data model is created but upgrades are locked at Level 1 — Phase 6 card picks will raise levels. The XP orb infrastructure from Phase 3 is reused; a separate CarPartPickup scene handles weapon unlocks.

</domain>

<decisions>
## Implementation Decisions

### Weapon Unlock vs. Upgrade Split

- **D-01:** Phase 4 implements **weapon unlock only**. When a player picks up a Car-Part, the corresponding weapon is added to their WeaponManager at Level 1. If they pick up the same part again (weapon already unlocked), it is silently ignored — no upgrade, no effect.
- **D-02:** WeaponManager stores `weapon_level: Dictionary` (weapon_id → int, default 1). This data model is in place so Phase 6 card picks can increment levels without structural changes.

### Pickup Drop Logic

- **D-03:** On enemy death, **25% random chance** of dropping a CarPartPickup. Which of the 5 car parts drops is uniformly random. Same pattern as XP orb drop (Game.gd `_on_enemy_died` already exists — add parallel pickup drop logic).
- **D-04:** CarPartPickup is a **separate scene** from XpOrb (different visual, different collection signal). Reuse the same PickupSpawner in Game.gd (already registered). Pre-register CarPartPickup scene in PickupSpawner's spawnable list.
- **D-05:** Collection is **host-authoritative** using the same `_collected` guard pattern as XpOrb.gd. Client steps on pickup → sends RPC to host → host validates, despawns, and sends `weapon_unlocked` RPC to owning player peer.

### WeaponManager Architecture

- **D-06:** **WeaponManager is a child Node of each Player node** (added to Player.tscn in this phase). It owns:
  - `unlocked_weapons: Array[String]` — list of weapon IDs currently active
  - `weapon_level: Dictionary` — weapon_id → level (1 at unlock; Phase 6 raises this)
  - Per-weapon Timer nodes for auto-fire cooldowns
  - Spinning Tires orbit nodes (3 Area2D children, always present when weapon is unlocked)
- **D-07:** WeaponManager **fires under the same authority pattern** as the existing `_try_fire` in Player.gd:
  - Owning peer's WeaponManager ticks cooldowns and triggers fire
  - If `multiplayer.is_server()` → spawn directly via Game.gd spawner
  - If client → send `request_fire` RPC (or weapon-specific variant) to host
- **D-08:** The existing `FIRE_INTERVAL` / `_try_fire()` in Player.gd (screws/bolts starter weapon) is **moved into WeaponManager** as the "ScrewsAndBolts" weapon entry. Player.gd delegates to WeaponManager. This keeps all weapon logic in one place.

### Weapon Behaviors (5 weapons, correct mechanics, simple visuals)

- **D-09: Exhaust Flames** — Periodic **cone Area2D** aimed at nearest enemy (same direction logic as ScrewsAndBolts). Fires every ~1.5 seconds. Cone spans ~60° arc, radius ~120px. Enemies inside cone at moment of fire take damage. Visual: ColorRect triangle shape. Host detects collision hits.
- **D-10: Spinning Tires** — **3 Area2D nodes orbit the player** continuously (120° apart, radius ~50px, rotation speed configurable). Always active when weapon is unlocked. On each physics frame, host checks if any tire Area2D overlaps an enemy → apply damage with a ~0.5s per-enemy cooldown to avoid rapid-fire contact damage. Visual: small colored circles. Nodes are children of Player (all peers see them via Player sync).
- **D-11: Antenna Beam** — **RayCast2D or long thin Area2D** aimed at nearest enemy, fires every ~2 seconds. Piercing: hits all enemies along the ray. Visual: tall thin ColorRect that flashes briefly on fire. Hit detection host-only.
- **D-12: Horn Shockwave** — **Radial Area2D burst** (full 360°, radius ~150px) centered on player. Fires every ~3 seconds. Hits all enemies in radius simultaneously. Visual: brief expanding ring (ColorRect scaled up then freed). Host detects hits.
- **D-13: Airbag Shield** — **1 death-prevention charge**, not a timer-based weapon. When unlocked, player has `airbag_active: bool = true`. When a hit would reduce health to ≤ 0: if `airbag_active` → absorb the lethal hit (health stays at 1, `airbag_active = false`). Visual: persistent ring around player visible while charge is active. To get another charge: pick up the Airbag CarPart again. Reset on death (WEAP-08).

### Multiplayer: Spinning Tires Authority

- **D-14:** Spinning Tires Area2D nodes are **children of Player.tscn**, always visible on all peers. Collision detection for damage is **host-only** (`is_multiplayer_authority()` guard OR `multiplayer.is_server()` check on the damage-apply path). This matches the Enemy contact damage pattern from Phase 3 (D-09 in 03-CONTEXT.md).

### Weapon Slot Limit

- **D-15:** Max **6 active weapons** simultaneously (WEAP-05). WeaponManager enforces this: if `unlocked_weapons.size() >= 6`, new pickups are ignored. No UI for this limit in Phase 4 — cap is enforced silently. Phase 6 may surface this in the card-pick UI.

### Death Reset

- **D-16:** On player death (entering downed state leading to game over), WeaponManager resets: `unlocked_weapons = []`, `weapon_level = {}`, `airbag_active = false`. Spinning Tires nodes are hidden/disabled. WEAP-08 requirement.

### OpenCode's Discretion

- Exact damage values per weapon (starting point: 10–25 damage, tunable)
- Exact cooldown timers (starting point from D-09—D-12 above, tunable)
- CarPartPickup visual color/shape per weapon type
- Antenna Beam implementation choice: RayCast2D vs. long Area2D (use whichever works cleanly with existing physics layer setup)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior Phase Architecture

- `.planning/phases/01-network-foundation-and-lobby/01-CONTEXT.md` — Three-autoload pattern (Lobby/GameEvents/GameState), RPC discipline rules
- `.planning/phases/02-player-movement-and-sync/02-CONTEXT.md` — Player spawning via spawn_function, MultiplayerSynchronizer at 20 Hz, authority guards
- `.planning/phases/03-room-1-enemy-ai-combat-core/03-CONTEXT.md` — PickupSpawner pattern, XpOrb collection (D-16), bullet spawning pattern (D-05/D-07), authority guard rule (D-09/D-15)

### Live Code (read before modifying)

- `scenes/Player.gd` — existing `_try_fire`, `FIRE_INTERVAL`, authority guard pattern → to be refactored into WeaponManager
- `scenes/Game.gd` — PickupSpawner already registered; `_on_enemy_died` signal → add 25% drop branch here
- `scenes/pickups/XpOrb.gd` — `_collected` guard pattern to replicate in CarPartPickup.gd
- `autoloads/GameState.gd` — weapon reset on game-over hook

### Project Requirements

- `.planning/REQUIREMENTS.md` §Weapons & Items (WEAP-01–08) — 13 requirements this phase must satisfy
- `.planning/ROADMAP.md` §Phase 4 — goal, success criteria, pitfall watch (W1 double-collect, W2 weapon timers, P7 spawnable gaps, P8 GameState authority)
- `.planning/PROJECT.md` — Car-themed aesthetic, host-authoritative model, placeholder art only

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`XpOrb.gd` + `PickupSpawner` in Game.gd** — CarPartPickup.gd copies the `_collected` guard and host-authoritative despawn pattern exactly. PickupSpawner is already instantiated; just pre-register the new CarPartPickup scene.
- **`_try_fire()` in Player.gd** — The starter weapon auto-fire logic. Phase 4 moves this into WeaponManager as the ScrewsAndBolts entry. Player.gd calls `$WeaponManager.tick(delta)`.
- **`request_fire` RPC in Game.gd** — Client→host fire request pattern. WeaponManager for non-tile weapons (Exhaust, Antenna, Shockwave) extends this same RPC; or adds weapon-specific RPCs following the same `@rpc("any_peer", "call_remote", "reliable")` signature.
- **`_on_enemy_died` in Game.gd** — Already handles XP orb drop. Add parallel `if randf() < 0.25: $PickupSpawner.spawn.call_deferred(...)` branch.
- **`receive_damage` RPC on Player.gd** — `airbag_active` check inserts before `health -= amount` in the same function.

### Established Patterns

- **Host-authoritative spawn:** Only host calls `spawner.spawn()`; all scenes pre-registered in spawner's spawnable list before testing (Pitfall P7).
- **`call_deferred` for spawn in physics callbacks:** Game.gd already uses `spawn.call_deferred` in `_on_enemy_died` to avoid "Can't change state while flushing queries".
- **`is_multiplayer_authority()` guard:** All WeaponManager fire logic (cooldown ticks → spawn) must be inside this guard on the player-authority side.
- **20 Hz MultiplayerSynchronizer:** If WeaponManager state (e.g., `airbag_active`) needs to be visible to other peers, add it to the existing Player MultiplayerSynchronizer replication config.

### Integration Points

- **Player.tscn:** Add WeaponManager child node + 3 SpinningTire Area2D children (visible when Spinning Tires unlocked)
- **Game.gd:** Add `weapon_unlocked` RPC broadcast; add CarPartPickup drop branch in `_on_enemy_died`; pre-register CarPartPickup scene in PickupSpawner
- **GameState.gd:** Hook weapon reset (`WeaponManager.reset()`) into game-over broadcast or Player death path
- **Player.gd `receive_damage`:** Insert `airbag_active` death-prevention check before damage application

</code_context>

<specifics>
## Specific Ideas

- **Airbag Shield visual:** A visible colored ring around the player (e.g., yellow) while the charge is active. Ring disappears when charge is consumed.
- **Spinning Tires damage cooldown:** Use a `Dictionary` per tire (enemy node path → last_hit_time) to avoid applying damage faster than every 0.5 seconds per enemy.
- **Car-Part names** (thematic, for pickup labels): Exhaust Pipe, Hubcap, Hood Antenna, Car Horn, Airbag Module — one per weapon.
- **Weapon slot cap (6):** Enforced silently in Phase 4. The WeaponManager `add_weapon()` method returns `false` if capacity is full. Phase 6 card-pick UI can surface this with a visual indicator.

</specifics>

<deferred>
## Deferred Ideas

- **Weapon Upgrades (Level 2 and 3):** Level data model exists in Phase 4, but actual stat improvements (damage scaling, cooldown reduction, area expansion) are implemented in Phase 6 via card picks.
- **Per-weapon visual differentiation:** CarPart pickup shapes are placeholders. Visual polish (distinct colors, particle effects) deferred to v2 / production polish.
- **Weapon combo interactions:** No cross-weapon interactions in Phase 4. Future scope.

</deferred>

---

*Phase: 4-weapons-and-item-pickups*
*Context gathered: 2026-05-31*
