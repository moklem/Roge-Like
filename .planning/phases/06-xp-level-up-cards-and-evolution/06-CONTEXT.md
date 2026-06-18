# Phase 6: XP, Level-Up Cards & Evolution - Context

**Gathered:** 2026-06-18
**Status:** Ready for planning

> **Phase ordering dependency:** Phase 5 (Roles & Elements) MUST be completed before Phase 6 planning begins. Phase 6 requires element upgrade cards and Stage 2 signature ability activation — both depend on Phase 5 role and element code being in place.

<domain>
## Phase Boundary

Deliver the per-player progression loop: collecting XP orbs fills a per-player XP bar, reaching a threshold opens a 3-card selection overlay (non-blocking for other players), card picks apply immediately (weapon upgrades, stat boosts, weapon unlocks), and hitting stage XP thresholds triggers full character evolution (Stage 1 car → Stage 2 Proto-Bot → Stage 3 Full AutoBot). Phase 6 also wires XP grant into the existing XpOrb collection path (currently missing from XpOrb.gd), adds XP/level/stage to Player's MultiplayerSynchronizer replication config, and adds the card overlay CanvasLayer UI.

**Pre-condition:** Phase 5 (Roles & Elements) must be complete. Element upgrade cards and the Stage 2 signature ability auto-grant require Phase 5 role and element systems to exist.

</domain>

<decisions>
## Implementation Decisions

### XP Thresholds & Pacing

- **D-01:** Each XP orb grants **5 XP** to the collecting player.
- **D-02:** Level-up XP thresholds scale with the formula: level N requires **(100 + (N-1) × 50) XP** above the previous level. Level 1→2: 100 XP. Level 2→3: 150 XP. Level 3→4: 200 XP. Etc.
- **D-03:** **Stage 2 (Proto-Bot)** unlocks at the level threshold where it can realistically be reached **before Room 3 in Run 1** (approximately 8–10 minutes in). Planner must calculate the exact level (likely Level 5–7) and verify that 5 XP/orb + current enemy spawn rate produces this timing. If not, adjust either XP per orb or the stage threshold.
- **D-04:** **Stage 3 (Full AutoBot)** is designed to be reached in **Room 2 of the second run** (Run 2). Per LOOP-06, XP and evolution stage carry over between rooms within a session; they reset only on full team wipe. This means Stage 3 is a stretch goal — players who don't die see it in the second loop.
- **D-05:** XP and level are **per-player** (not shared). Each player accumulates their own XP and reaches their own level thresholds independently.

### Card Overlay UX

- **D-06:** When a player levels up, a card selection overlay appears **for that player only** (local CanvasLayer). Per pitfall W4: this is implemented as a CanvasLayer — `SceneTree.paused` is NOT used. Other players continue playing normally.
- **D-07:** The leveling player is **frozen** (input locked) and **briefly invulnerable** while the overlay is open. Invulnerability is implemented as a flag on the Player node (`is_picking_card: bool`). Enemy damage checks skip players with this flag. There is **no time limit** — the overlay waits indefinitely until the player picks.
- **D-08:** Card navigation: **A/D keys** to cycle between the 3 cards, **Space or Enter** to confirm selection. No mouse click required (keyboard-only per PROJECT.md).
- **D-09:** Card display: 3 `ColorRect + Label` panels side by side. Each card shows: card type, weapon/stat name, and effect description. A highlight border shows the currently selected card (A/D cycles it). No sprites needed.
- **D-10:** **Teammate indicator**: when a player is picking a card, a small `"[Name] is leveling up!"` Label appears above their frozen character in world space. This is visible on all peers (the Label is on the Player node, so it replicates via the existing scene structure). Label disappears when the card is picked.

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

- **D-12:** Stage transitions are **visual-only in terms of placeholder art**. Locomotion style changes per EVOL-02 (car → robot movement) must be implemented per the Phase 5 design spec. Visual placeholder shapes:
  - **Stage 1 (Normal Car):** Compact horizontal rectangle (existing Sprite node), neutral color (blue/grey)
  - **Stage 2 (Proto-Bot):** Cross/T-shape arrangement of 3–4 ColorRects (body + 2 arm stubs), darker color (grey), no armor plates — raw skeletal look
  - **Stage 3 (Full AutoBot):** Larger rectangle with a border/frame of additional ColorRects (armored plates), brighter accent color
- **D-13:** Stage change is **instant** (no animation). The Player node's existing Sprite is hidden; the new stage visual nodes are shown. Each stage visual is a set of child ColorRect nodes parented to the Player scene, shown/hidden per stage.
- **D-14:** Stage resets to 1 (car form) at the start of each new run (EVOL-06). This is handled in the same game-over/reset path as weapon reset.

### Phase 5 Dependency Ordering

- **D-15:** Phase 6 planning does NOT begin until **Phase 5 (Roles & Elements) is complete**. The card pool includes element upgrade cards (XP-04) and Stage 2 auto-grants the role-specific signature ability (EVOL-02) — both require Phase 5 code.
- **D-16:** Stage 2 signature ability is **auto-granted** at the stage XP threshold (not via a card pick). When the Stage 2 evolution triggers, the owning player's role-specific ability is automatically activated. This requires Phase 5 to have exposed a method like `Player.activate_signature_ability()` or similar.

### Claude's Discretion

- Exact level at which Stage 2 and Stage 3 unlock (planner should calculate from XP formula and target timing)
- Exact XP orb value may be tuned by the planner to hit the Stage 2 timing target (5 XP/orb is the starting point)
- Exact invulnerability duration during card pick (suggest 0.5–1s after overlay appears, then enemies can damage again — or make it last the entire pick duration if that feels better)
- Color choices for evolution stage placeholder shapes
- Card pool draw logic implementation (random from eligible pool, fallback card always available per XP-06)
- Whether the level-up indicator on teammates uses RPC broadcast or is derived from a synced `is_picking_card` property

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Architecture & Patterns

- `.planning/phases/04-weapons-and-item-pickups/04-CONTEXT.md` — WeaponManager architecture (D-06–D-16), weapon_level dict, pickup collection pattern, host-authoritative weapon unlock RPC, W1/W2/W4 pitfall notes
- `.planning/phases/03-room-1-enemy-ai-combat-core/03-CONTEXT.md` — XP orb spawn/collection pattern (D-16), PickupSpawner, host-authoritative despawn
- `.planning/phases/01-network-foundation-and-lobby/01-CONTEXT.md` — Three-autoload pattern (Lobby/GameEvents/GameState), RPC discipline

### Live Code (read before modifying)

- `scenes/Player.gd` — Health, authority guard, MultiplayerSynchronizer replicated properties; XP/level/stage will be added here; `is_picking_card` flag goes here
- `scenes/pickups/XpOrb.gd` — Current collection logic has NO XP grant; Phase 6 must add `xp_granted` RPC call from host to collecting player after `queue_free()`
- `scenes/weapons/WeaponManager.gd` — `weapon_level` dict, `add_weapon()`, `reset()`; Phase 6 reads `weapon_level` in each weapon's fire path
- `autoloads/GameState.gd` — XP thresholds, per-player XP tracking, stage state should live here (host-authoritative); clients read via MultiplayerSynchronizer
- `scenes/Game.gd` — `weapon_unlocked` RPC pattern, spawner wiring — card pick confirmation follows the same `@rpc("authority", "call_local", "reliable")` pattern

### Project Requirements

- `.planning/REQUIREMENTS.md` §XP & Level-Up (XP-01–09), §Evolution (EVOL-01–06) — 15 requirements this phase must satisfy
- `.planning/ROADMAP.md` §Phase 6 — goal, success criteria, pitfall watch (W3 card pool empty, W4 SceneTree pause, W5 XP sync lag, P8 GameState authority)
- `.planning/PROJECT.md` — Placeholder art, keyboard-only input, host-authoritative model, CARIAD demo context

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`XpOrb.gd` `_request_collect` pattern** — Phase 6 adds XP grant by calling an RPC on the collecting Player node from within the existing `_request_collect` host-side handler, after `queue_free()`. Pattern: `player_node.receive_xp.rpc_id(player_peer_id, XP_VALUE)`.
- **`weapon_unlocked` RPC in `Game.gd`** — Card pick confirmation follows the same `@rpc("authority", "call_local")` pattern. Host validates the card selection, then broadcasts the effect to the relevant player peer.
- **`receive_damage` / `receive_revive` RPC pattern in `Player.gd`** — `receive_xp` and `trigger_level_up` will use the same `@rpc("any_peer", "call_remote", "reliable")` approach (host calls to owning peer).
- **`_broadcast_game_over` in `GameState.gd`** — Stage reset (EVOL-06) should be wired into this same broadcast path, alongside weapon reset.
- **`MultiplayerSynchronizer` on Player** — Add `xp`, `level`, `stage`, `is_picking_card` to the existing replication config (20 Hz interval). These are the properties other peers need to see the XP bar, level badge, stage visual, and level-up indicator.

### Established Patterns

- **Host-authoritative state changes:** XP grant, level-up trigger, card effect application, and stage transitions all require host validation. Client sends intent → host validates and executes → host broadcasts confirmed result.
- **CanvasLayer for local UI:** Card overlay is a CanvasLayer child of the Player's owning peer viewport. It does NOT exist on other peers' screens. `SceneTree.paused` is never set (W4).
- **`call_deferred` for physics-safe operations:** Any node add/remove during physics frame (e.g., adding stage visual nodes, removing old stage) uses `call_deferred`.
- **`is_multiplayer_authority()` guard:** All per-player input (A/D card navigation, Space/Enter confirm) guarded on the owning peer only.

### Integration Points

- **`XpOrb.gd`:** Add `receive_xp` RPC call from host to collecting player peer after `queue_free()`.
- **`Player.gd`:** Add `xp: int`, `level: int`, `stage: int`, `is_picking_card: bool` properties. Add `receive_xp()` RPC. Add level-up detection logic. Add card overlay show/hide. Add stage visual node management.
- **`WeaponManager.gd`:** Each weapon's fire path reads `weapon_level[weapon_id]` and applies D-11 stat scaling accordingly. `reset()` already exists for death.
- **`GameState.gd`:** Add per-player XP tracking dict, level thresholds array, stage thresholds. Host is sole writer.
- **`Game.gd`:** Add `confirm_card_pick` RPC (client sends selection → host validates → host calls effect RPCs on player). Follows `weapon_unlocked` pattern.

</code_context>

<specifics>
## Specific Ideas

- **XP orb grant flow:** `XpOrb._request_collect` (host) → grant XP to player → `Player.receive_xp.rpc_id(peer_id, 5)` → owning peer increments `xp` → if `xp >= threshold`: show card overlay, set `is_picking_card = true`, trigger `is_invulnerable = true`.
- **Card overlay hiding:** After pick, `is_picking_card = false`, `is_invulnerable = false`, overlay hides. Host receives `confirm_card_pick` RPC, validates selection, broadcasts card effect.
- **Level-up label on teammates:** A Label node on the Player (e.g., `LevelUpLabel`) is always present but hidden. When `is_picking_card` is true (synced via MultiplayerSynchronizer), other peers' Player `_process` shows this label with "[role] is leveling up!".
- **Airbag Shield Level 3:** Changes `airbag_active: bool` to `airbag_count: int`. `consume_airbag()` decrements count instead of clearing bool. `WeaponManager.reset()` sets `airbag_count = 0`.
- **Evolution stage visual swap:** Player.tscn gets 3 child containers (one per stage), each with their ColorRect arrangement. Stage change = hide current container, show new container. Simple and reversible.

</specifics>

<deferred>
## Deferred Ideas

- **Stat boost card numbers:** The exact +% values for speed/HP/damage/cooldown-reduction stat boost cards are tuning decisions. Planner can start with +10% per pick and adjust.
- **Element upgrade card pool:** Element upgrade cards (XP-04) exist in the spec but their implementation depends on Phase 5. Phase 6 includes the card draw/filter infrastructure; element-specific card effects are filled in after Phase 5 is complete.
- **XP magnet range:** Currently XP orbs require direct contact. A magnet pull effect (orbs drift toward nearby players) is a nice QOL touch but belongs in v2 polish.
- **Card pick visual polish:** Card overlay uses plain ColorRect panels. Animated card flip, glow effects, or sound cues are v2 scope.

</deferred>

---

*Phase: 6-xp-level-up-cards-and-evolution*
*Context gathered: 2026-06-18*
