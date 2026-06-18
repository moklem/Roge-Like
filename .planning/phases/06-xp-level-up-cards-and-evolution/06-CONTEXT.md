# Phase 6: XP, Level-Up Cards & Evolution - Context

**Gathered:** 2026-06-18 (updated after Phase 5 completion)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the per-player progression loop: collecting XP orbs fills a per-player XP bar (screen-edge CanvasLayer HUD), reaching a threshold opens a 3-card selection overlay (non-blocking for other players), card picks apply immediately (weapon upgrades, element upgrades, stat boosts, weapon unlocks), and hitting stage XP thresholds triggers character evolution (Stage 1 car → Stage 2 Proto-Bot → Stage 3 Full AutoBot). Phase 6 also wires XP grant into the existing XpOrb collection path (currently missing from XpOrb.gd), adds XP/level/stage/element_tier to Player's MultiplayerSynchronizer replication config, and adds the card overlay CanvasLayer UI.

**Pre-condition:** Phase 5 (Roles & Elements) is complete. Element upgrade cards and the Stage 2 signature ability auto-grant require Phase 5 role and element systems — both now exist.

</domain>

<decisions>
## Implementation Decisions

### XP Thresholds & Pacing

- **D-01:** Each XP orb grants **5 XP** to the collecting player.
- **D-02:** Level-up XP thresholds scale with the formula: level N requires **(100 + (N-1) × 50) XP** above the previous level. Level 1→2: 100 XP. Level 2→3: 150 XP. Level 3→4: 200 XP. Etc.
- **D-03:** **Stage 2 (Proto-Bot)** unlocks at the level threshold where it can realistically be reached **before Room 3 in Run 1** (approximately 8–10 minutes in). Planner must calculate the exact level (likely Level 5–7) and verify that 5 XP/orb + current enemy spawn rate produces this timing. If not, adjust either XP per orb or the stage threshold.
- **D-04:** **Stage 3 (Full AutoBot)** is designed to be reached in **Room 2 of the second run** (Run 2). Per LOOP-06, XP and evolution stage carry over between rooms within a session; they reset only on full team wipe. Stage 3 is a stretch goal — players who don't die see it in the second loop.
- **D-05:** XP and level are **per-player** (not shared). Each player accumulates their own XP and reaches their own level thresholds independently.

### XP / Level State Ownership

- **D-17:** `xp: int`, `level: int`, and `element_tier: int` live on the **Player node** (not GameState.gd). They follow the same pattern as `evolution_stage`, `health`, `shield_active` — all per-player state lives on Player, replicated via MultiplayerSynchronizer. The owning peer increments `xp` when `receive_xp` RPC fires and detects level-up locally. Host sends `receive_xp.rpc_id(peer_id, amount)` after confirming orb collection. GameState.gd does NOT track per-player XP or level.

### Per-Player XP HUD

- **D-18:** The XP bar, level number, and stage indicator use a **screen-edge CanvasLayer** local to the owning peer — NOT world-space nodes floating on the Player character. Layout: anchored to the bottom of the screen. Left: "LVL N" Label. Center: XP ProgressBar (most of width). Right: "Stage N" Label or colored indicator. The CanvasLayer is shown only on the owning peer's screen (guarded by `is_multiplayer_authority()` in `_ready()`).

### Card Overlay UX

- **D-06:** When a player levels up, a card selection overlay appears **for that player only** (local CanvasLayer). Per pitfall W4: this is implemented as a CanvasLayer — `SceneTree.paused` is NOT used. Other players continue playing normally.
- **D-07:** The leveling player is **frozen** (input locked) and **briefly invulnerable** while the overlay is open. Invulnerability is implemented as a flag on the Player node (`is_picking_card: bool`). Enemy damage checks skip players with this flag. There is **no time limit** — the overlay waits indefinitely until the player picks.
- **D-08:** Card navigation: **A/D keys** to cycle between the 3 cards, **Space or Enter** to confirm selection. No mouse click required (keyboard-only per PROJECT.md).
- **D-09:** Card display: 3 `ColorRect + Label` panels side by side. Each card shows: card type, weapon/stat name, and effect description. A highlight border shows the currently selected card (A/D cycles it). No sprites needed.
- **D-10:** **Teammate indicator**: when a player is picking a card, a small `"[Name] is leveling up!"` Label appears above their frozen character in world space. This is visible on all peers (the Label is on the Player node, so it replicates via the existing scene structure). Label disappears when the card is picked.

### Element Upgrade Cards

- **D-19:** Picking an element upgrade card **boosts proc rate** for Fire and Ice:
  - Tier 1 (lobby default): 25% proc rate
  - Tier 2 (first upgrade card): 50% proc rate
  - Tier 3 (second upgrade card): 75% proc rate
  - After Tier 3, element upgrade cards are **removed from the pool** for that player (XP-05 filter). `element_tier: int` tracks current tier on the Player node (default 1).
- **D-20:** Fire and Ice support **2 upgrades max** (Tier 1 → 2 → 3). After Tier 3 the card type is filtered out. The existing `element` String on Player already identifies which proc logic to scale.
- **D-21:** Earth element has no proc rate. Upgrading Earth boosts **both team heal rate and shockwave cooldown**:
  - Tier 1: +2 HP/sec team heal, 8s shockwave cooldown
  - Tier 2: +4 HP/sec team heal, 6s shockwave cooldown
  - Tier 3: +6 HP/sec team heal, 5s shockwave cooldown, shockwave also briefly slows enemies (×0.5 speed for 1s)

### Weapon Upgrade Stats (per-weapon, Level 2 and Level 3)

- **D-11:** Weapon upgrades are **per-weapon** — each weapon has its own Level 2 and Level 3 behavior. `weapon_level` dict already exists in WeaponManager from Phase 4; Phase 6 adds the stat-application logic that reads it.

| Weapon | Level 2 | Level 3 |
|--------|---------|---------|
| **Screws & Bolts** | Fire 2 bolts in a ±15° spread | 3 bolts (±30° fan), cooldown 0.5s→0.35s |
| **Exhaust Flames** | Cone widens 60°→90°, range 120→160px | Cone 120°, enemies hit are slowed (×0.5 speed for 1s) |
| **Spinning Tires** | 4th orbit node added, rotation speed +25% | 5 orbit nodes, damage per tick 12→18 |
| **Antenna Beam** | Fires twice per activation (two bursts 0.2s apart) | Damage 20→30, hitbox width doubles |
| **Horn Shockwave** | Radius 150→220px, cooldown 3s→2.5s | Knock-back range ×2, brief enemy stun (enemy velocity zeroed for 0.5s) |
| **Airbag Shield** | Absorbs lethal hit AND heals to 25% HP (instead of 1 HP) | 2 simultaneous charges (`airbag_count: int` replaces `airbag_active: bool`) |

### Evolution Visuals (Placeholder Shapes)

- **D-12:** Stage transitions are **visual-only in terms of placeholder art**. **Locomotion is UNCHANGED** — WASD movement mechanics are identical across all stages. "Car vs robot movement" is flavor text; the code has never enforced car-specific movement. Visual placeholder shapes:
  - **Stage 1 (Normal Car):** Compact horizontal rectangle (existing Sprite node), neutral color (blue/grey)
  - **Stage 2 (Proto-Bot):** Cross/T-shape arrangement of 3–4 ColorRects (body + 2 arm stubs), darker color (grey), no armor plates — raw skeletal look
  - **Stage 3 (Full AutoBot):** Larger rectangle with a border/frame of additional ColorRects (armored plates), brighter accent color
- **D-13:** Stage change is **instant** (no animation). The Player node's existing Sprite is hidden; the new stage visual nodes are shown. Each stage visual is a set of child ColorRect nodes parented to the Player scene, shown/hidden per stage.
- **D-14:** Stage resets to 1 (car form) at the start of each new run (EVOL-06). This is handled in the same game-over/reset path as weapon reset.
- **D-22:** Stage 3 activation grants a **stat boost** on top of the visual change: **+20% damage** (applied as a multiplier on all weapon damage) and **+25 max HP** (MAX_HP increases, player is immediately healed by 25 HP). Applied once when `evolution_stage` transitions to 3.

### Phase 5 Dependency Ordering

- **D-15:** Phase 6 planning does NOT begin until **Phase 5 (Roles & Elements) is complete**. ✅ Phase 5 is now complete.
- **D-16:** Stage 2 signature ability is **auto-granted** at the stage XP threshold (not via a card pick). When the Stage 2 evolution triggers, `set_evolution_stage.rpc_id(peer_id, 2)` is called — `_use_role_ability()` in Player.gd already dispatches to `_use_stage2_ability()` when `evolution_stage >= 2`. No separate "grant" method needed; setting the stage is the grant.

### Claude's Discretion

- Exact level at which Stage 2 and Stage 3 unlock (planner should calculate from XP formula and target timing)
- Exact XP orb value may be tuned by the planner to hit the Stage 2 timing target (5 XP/orb is the starting point)
- Exact invulnerability duration during card pick (suggest full duration of pick — `is_picking_card = true` blocks damage until card confirmed)
- Color choices for evolution stage placeholder shapes
- Card pool draw logic implementation (random from eligible pool, fallback card always available per XP-06)
- Whether the level-up indicator on teammates uses RPC broadcast or is derived from the synced `is_picking_card` property
- Earth Tier 2/3 exact `element_tier` application in `_tick_element` (planner extends the match statement in Player.gd)
- Stage 3 damage multiplier implementation (a `stage3_damage_mult: float` var on Player, default 1.0, set to 1.2 on Stage 3 — each weapon's fire path multiplies by this)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Architecture & Patterns

- `.planning/phases/04-weapons-and-item-pickups/04-CONTEXT.md` — WeaponManager architecture, weapon_level dict, pickup collection pattern, host-authoritative weapon unlock RPC, W1/W2/W4 pitfall notes
- `.planning/phases/03-room-1-enemy-ai-combat-core/03-CONTEXT.md` — XP orb spawn/collection pattern, PickupSpawner, host-authoritative despawn
- `.planning/phases/01-network-foundation-and-lobby/01-CONTEXT.md` — Three-autoload pattern (Lobby/GameEvents/GameState), RPC discipline

### Live Code (read before modifying)

- `scenes/Player.gd` — All per-player state lives here (health, evolution_stage, element, shield_active, is_downed). Phase 6 adds: `xp`, `level`, `element_tier`, `is_picking_card`, `stage3_damage_mult`. `set_evolution_stage` RPC stub already exists (line ~447). `receive_damage` already has i-frame and shield checks — add `is_picking_card` guard here.
- `scenes/pickups/XpOrb.gd` — `_request_collect` (host-side, line ~25): runs on host, uses `_collected` guard. Phase 6 adds XP grant here via `player_node.receive_xp.rpc_id(peer_id, 5)` after confirming collection. Host gets collector peer_id from `multiplayer.get_remote_sender_id()`.
- `scenes/weapons/WeaponManager.gd` — `weapon_level` dict, `add_weapon()`, `reset()`. Phase 6 reads `weapon_level[weapon_id]` in each weapon's fire path to apply D-11 stat scaling. `airbag_active: bool` becomes `airbag_count: int` for Level 3 Airbag.
- `autoloads/GameState.gd` — Stage/XP reset goes in `_broadcast_game_over` (line ~48). Phase 6 adds `xp = 0`, `level = 1`, `element_tier = 1`, `stage = 1` resets alongside the existing `WeaponManager.reset()` calls.
- `scenes/Game.gd` — `weapon_unlocked` RPC pattern — card pick confirmation follows same `@rpc("authority", "call_local", "reliable")` pattern.

### Project Requirements

- `.planning/REQUIREMENTS.md` §XP & Level-Up (XP-01–09), §Evolution (EVOL-01–06) — 15 requirements this phase must satisfy
- `.planning/ROADMAP.md` §Phase 6 — goal, success criteria, pitfall watch (W3 card pool empty, W4 SceneTree pause, W5 XP sync lag, P8 GameState authority)
- `.planning/PROJECT.md` — Placeholder art, keyboard-only input, host-authoritative model, CARIAD demo context

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`XpOrb.gd` `_request_collect` pattern** — Phase 6 adds XP grant by calling `player_node.receive_xp.rpc_id(peer_id, 5)` from within the existing host-side handler, using `multiplayer.get_remote_sender_id()` to identify the collector. Existing `_collected` guard prevents double-grant.
- **`weapon_unlocked` RPC in `Game.gd`** — Card pick confirmation follows the same `@rpc("authority", "call_local")` pattern. Host validates the card selection, then broadcasts the effect to the relevant player peer.
- **`receive_damage` / `receive_revive` RPC pattern in `Player.gd`** — `receive_xp` and `trigger_level_up` use the same `@rpc("any_peer", "call_remote", "reliable")` approach (host calls rpc_id to owning peer).
- **`_broadcast_game_over` in `GameState.gd`** — Stage/XP/level/element_tier reset should be wired into this same broadcast path, alongside weapon reset.
- **`MultiplayerSynchronizer` on Player** — Add `xp`, `level`, `element_tier`, `is_picking_card`, `stage3_damage_mult` to the existing replication config. These are the properties other peers need to see the XP bar, level badge, stage visual, and level-up indicator.
- **`_use_role_ability()` dispatch already stage-gated** — `evolution_stage >= 2` check already routes to `_use_stage2_ability()`. No new dispatch logic needed for Stage 2 ability grant.

### Established Patterns

- **Host-authoritative state changes:** XP grant, level-up trigger, card effect application, and stage transitions all require host validation. Client sends intent → host validates and executes → host broadcasts confirmed result.
- **CanvasLayer for local UI:** Card overlay AND the new XP bar HUD are both CanvasLayer children shown only on the owning peer's screen. `SceneTree.paused` is never set (W4).
- **`call_deferred` for physics-safe operations:** Node add/remove during physics frame (stage visual swap) uses `call_deferred`.
- **`is_multiplayer_authority()` guard:** All per-player input (A/D card navigation, Space/Enter confirm) guarded on the owning peer only.

### Integration Points

- **`XpOrb.gd`:** Add `receive_xp` RPC call from host to collecting player peer after `queue_free()`.
- **`Player.gd`:** Add `xp`, `level`, `element_tier`, `is_picking_card`, `stage3_damage_mult` vars. Add `receive_xp()` RPC. Add level-up detection logic. Add card overlay show/hide. Add stage visual node management. Add HUD CanvasLayer show/update.
- **`WeaponManager.gd`:** Each weapon's fire path reads `weapon_level[weapon_id]` and applies D-11 stat scaling. `airbag_active: bool` → `airbag_count: int` for Level 3.
- **`GameState.gd`:** Extend `_broadcast_game_over` to reset `xp`, `level`, `element_tier`, `evolution_stage` on all Player nodes.
- **`Game.gd`:** Add `confirm_card_pick` RPC (client sends selection → host validates → host calls effect RPCs on player). Follows `weapon_unlocked` pattern.

</code_context>

<specifics>
## Specific Ideas

- **XP orb grant flow:** `XpOrb._request_collect` (host) → `multiplayer.get_remote_sender_id()` to get collector peer → `player_node.receive_xp.rpc_id(peer_id, 5)` → owning peer increments `xp` → if `xp >= threshold`: show card overlay, set `is_picking_card = true`, set `is_invulnerable = true`.
- **Card overlay hiding:** After pick, `is_picking_card = false`, invulnerability clears, overlay hides. Host receives `confirm_card_pick` RPC, validates selection, broadcasts card effect.
- **Level-up label on teammates:** A Label node on the Player (e.g., `LevelUpLabel`) is always present but hidden. When `is_picking_card` is true (synced via MultiplayerSynchronizer), other peers' Player `_process` shows this label with "[role] is leveling up!".
- **Airbag Shield Level 3:** Changes `airbag_active: bool` to `airbag_count: int`. `consume_airbag()` decrements count instead of clearing bool. `WeaponManager.reset()` sets `airbag_count = 0`.
- **Evolution stage visual swap:** Player.tscn gets 3 child containers (one per stage), each with their ColorRect arrangement. Stage change = hide current container, show new container. Simple and reversible.
- **Stage 3 stat boost:** On `set_evolution_stage(3)`: `stage3_damage_mult = 1.2`, `MAX_HP += 25`, `health = mini(health + 25, MAX_HP)`. Each weapon's fire path multiplies damage by `get_parent().stage3_damage_mult` (read from Player).
- **Element tier scaling:** `element_tier: int` on Player (default 1). Fire/Ice proc rate = `0.25 * element_tier` (tier 1 = 25%, tier 2 = 50%, tier 3 = 75%). Earth values read from a const array indexed by tier. `_tick_element` already reads `element` — add `element_tier` reads alongside.
- **XP HUD CanvasLayer:** A new scene `scenes/ui/PlayerHUD.tscn` with a CanvasLayer containing: HBoxContainer at screen bottom with LevelLabel + XPBar (ProgressBar) + StageLabel. Added as a child of Player.tscn, shown only when `is_multiplayer_authority()`.

</specifics>

<deferred>
## Deferred Ideas

- **Stat boost card numbers:** The exact +% values for speed/HP/damage/cooldown-reduction stat boost cards are tuning decisions. Planner can start with +10% per pick and adjust.
- **XP magnet range:** Currently XP orbs require direct contact. A magnet pull effect (orbs drift toward nearby players) is a nice QOL touch but belongs in v2 polish.
- **Card pick visual polish:** Card overlay uses plain ColorRect panels. Animated card flip, glow effects, or sound cues are v2 scope.
- **Stage 2 locomotion mechanics:** Confirmed purely visual — no strafe, no speed change. "Moves like a robot" is flavor only. Do not implement movement changes.

</deferred>

---

*Phase: 6-xp-level-up-cards-and-evolution*
*Context gathered: 2026-06-18 (updated after Phase 5 completion)*
