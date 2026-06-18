# Phase 6: XP, Level-Up Cards & Evolution — Research

**Researched:** 2026-06-18
**Domain:** Godot 4.6 GDScript — per-player XP/level progression, card selection overlay UI, MultiplayerSynchronizer extension, weapon upgrade stat scaling, evolution stage visuals
**Confidence:** HIGH (all findings verified against live codebase; no external library dependencies)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Each XP orb grants 5 XP to the collecting player.
- **D-02:** Level-up XP thresholds: level N requires (100 + (N-1) × 50) XP above previous. L1→2: 100 XP. L2→3: 150 XP. L3→4: 200 XP.
- **D-03:** Stage 2 unlocks at a level reachable before Room 3 in Run 1 (~8–10 min). Planner must calculate exact level, verify timing, adjust if needed.
- **D-04:** Stage 3 reachable in Room 2 of Run 2. XP/evolution carry over between rooms; reset only on full team wipe.
- **D-05:** XP and level are per-player (not shared).
- **D-06:** Card selection overlay = local CanvasLayer per player. SceneTree.paused is NEVER set. Other players keep playing.
- **D-07:** Leveling player is frozen (is_picking_card = true) and briefly invulnerable while picking. No time limit.
- **D-08:** Card navigation: A/D cycle, Space/Enter confirm. No mouse.
- **D-09:** 3 ColorRect + Label panels side by side. Highlight border on selected card. No sprites.
- **D-10:** Teammate sees "[RoleName] is leveling up!" Label above frozen player (world-space Label on Player).
- **D-11:** Per-weapon level 2/3 stat upgrades (see upgrade table in CONTEXT.md).
- **D-12:** Stage visuals — Stage 1: compact horizontal rect (existing Sprite, blue/grey). Stage 2: cross/T-shape, dark grey. Stage 3: larger rect + armor-plate border, brighter accent. No movement changes.
- **D-13:** Stage change is instant (no animation). Sprite hidden; new stage visual nodes shown.
- **D-14:** Stage resets to 1 at start of each new run.
- **D-15:** Phase 5 complete — dependency satisfied.
- **D-16:** Stage 2 auto-grants signature ability via set_evolution_stage RPC. _use_role_ability() already dispatches to _use_stage2_ability() when evolution_stage >= 2.
- **D-17:** xp, level, element_tier live on Player node (same pattern as evolution_stage, health, shield_active).
- **D-18:** XP/Level/Stage HUD = screen-edge CanvasLayer local to owning peer. Bottom-anchored. LevelLabel + XPBar + StageLabel.
- **D-19:** Element upgrade cards boost proc rate: Tier 1 = 25%, Tier 2 = 50%, Tier 3 = 75%. element_tier on Player (default 1).
- **D-20:** Fire/Ice: 2 upgrades max (Tier 1→2→3). Earth: upgrades boost team heal rate and shockwave cooldown.
- **D-21:** Earth Tier upgrades: T1 = +2 HP/s, 8s cooldown; T2 = +4 HP/s, 6s cooldown; T3 = +6 HP/s, 5s cooldown, slow enemies.
- **D-22:** Stage 3 stat boost: +20% damage (stage3_damage_mult = 1.2) + +25 max HP on transition. Applied once on set_evolution_stage(3).

### Claude's Discretion

- Exact level for Stage 2 and Stage 3 thresholds (planner calculates from formula + timing target)
- XP per orb may be tuned to hit Stage 2 timing target (5 XP/orb is starting point)
- Invulnerability duration = full is_picking_card duration (D-07 clarification)
- Color choices for evolution stage placeholder shapes (defined in 06-UI-SPEC.md)
- Card pool draw logic (random from eligible pool, fallback always available per XP-06)
- Whether LevelUpLabel uses RPC broadcast or derived from synced is_picking_card property
- Earth Tier 2/3 exact element_tier application in _tick_element
- stage3_damage_mult implementation: float var on Player, default 1.0, set 1.2 on Stage 3

### Deferred Ideas (OUT OF SCOPE)

- Exact +% values for stat boost cards (planner starts with +10% per pick)
- XP magnet range (v2 polish)
- Card pick visual polish (animated card flip, glow, sound — v2 scope)
- Stage 2 locomotion mechanics (confirmed visual-only; no strafe, no speed change)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| XP-01 | Collecting XP orbs fills a visible XP bar on the player's HUD | PlayerHUD CanvasLayer with ProgressBar; receive_xp updates XPBar.value |
| XP-02 | On level-up, a card selection overlay appears for that player | CardOverlay CanvasLayer show/hide via is_picking_card flag |
| XP-03 | Card selection shows 3 random cards drawn from an eligible pool | Card pool filter logic; random draw from eligible list |
| XP-04 | Card types include weapon unlock, weapon upgrade, element upgrade, stat boost | All types mapped to pool entries; card data dict per type |
| XP-05 | Card pool filtered: unlock removed if owned, upgrade removed if at max | Filter reads WeaponManager.unlocked_weapons and weapon_level |
| XP-06 | Fallback card always available so pool never runs dry (W3) | Fallback "Damage Boost" appended after filter if pool size < 3 |
| XP-07 | Card selection non-blocking — other players continue playing | CanvasLayer only, no SceneTree.paused (W4 compliance) |
| XP-08 | Selected cards take effect immediately and stack for session | Effect applied by host confirm_card_pick RPC; persists until reset |
| XP-09 | Level number visible on player's screen | LevelLabel in PlayerHUD CanvasLayer, owning peer only |
| EVOL-01 | Players start Stage 1 (Normal Car) — car visual, starter stats | Stage1Container with existing Sprite; evolution_stage = 1 default |
| EVOL-02 | Stage 2 threshold triggers Proto-Bot transformation + signature ability | set_evolution_stage(2) RPC; Stage2Container shown; _use_stage2_ability auto-routes |
| EVOL-03 | Stage 3 threshold triggers Full AutoBot + all abilities + stat bonuses | set_evolution_stage(3) RPC; Stage3Container; stage3_damage_mult = 1.2; MAX_HP += 25 |
| EVOL-04 | Stage visible on own and teammates' characters | Stage containers on Player node replicated via scene structure (Node2D children follow position); is_picking_card synced |
| EVOL-05 | Stage thresholds same for all roles | Threshold constants in Player.gd, not role-conditional |
| EVOL-06 | Stage resets to 1 on new run | _broadcast_game_over resets evolution_stage = 1 alongside WeaponManager.reset() |
</phase_requirements>

---

## Summary

Phase 6 delivers the core Vampire Survivors-style progression loop on top of the existing Godot 4.6 ENet multiplayer foundation. All required systems have well-established patterns already in the codebase: XP collection extends XpOrb.gd's existing `_request_collect` host-authoritative handler; the card overlay follows the same CanvasLayer pattern used by the existing `HUD` node in Game.tscn; weapon level scaling extends the `weapon_level` dict already tracked in WeaponManager.gd; and stage visual swaps are pure Node2D show/hide operations using `call_deferred`.

The key integration constraint is that **all state changes are host-authoritative**. XP grant flows host→owning-peer via RPC (not client-incremented). Card selection flows owning-peer→host→effect-RPC. Stage transition flows host→owning-peer via `set_evolution_stage.rpc_id`. The MultiplayerSynchronizer on Player must be extended with five new properties (`xp`, `level`, `element_tier`, `is_picking_card`, `stage3_damage_mult`) so other peers see the XP bar, level badge, and the LevelUpLabel when a teammate is picking.

The largest coordination risk is the `airbag_active: bool → airbag_count: int` migration in WeaponManager.gd and Player.gd's `receive_damage`, which touches two files simultaneously. The weapon upgrade stat scaling must be added to six weapon fire paths across five .gd files and WeaponManager._fire_screws(), each with slightly different fire patterns — this is mechanical but high line-count work. Stage 3 damage multiplier needs to propagate through every weapon's damage application site.

**Primary recommendation:** Plan in four waves — (1) XP plumbing + new Player vars + MultiplayerSynchronizer extension, (2) PlayerHUD CanvasLayer + CardOverlay CanvasLayer UI, (3) card pool + confirm_card_pick RPC + weapon upgrade stats + airbag migration, (4) evolution stage visuals + Stage 3 stat boost + game-over reset extension.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| XP grant (orb → player) | Host (XpOrb._request_collect) | Owning peer (receive_xp RPC recipient) | XP grant is game state mutation; host validates orb collection then sends authoritative XP amount |
| Level-up detection | Owning peer (inside receive_xp) | — | Only the owning peer runs receive_xp; threshold check is pure arithmetic on local xp var |
| Card overlay display | Owning peer (local CanvasLayer) | — | Non-blocking UI, local only; other players must not see or be affected |
| Card selection input | Owning peer (Player._unhandled_input) | — | Only authority peer handles A/D/Space; is_picking_card guard blocks movement/ability input |
| Card pick confirmation | Host (confirm_card_pick RPC target) | Owning peer (sends pick index) | P8: card effects are game state; host validates and broadcasts effect RPCs |
| Weapon level upgrade | Host → owning peer (effect RPC after confirm) | Owning peer (WeaponManager reads level at fire time) | weapon_level dict lives on WeaponManager (owning peer's client); host confirms pick, owning peer increments level |
| Element tier upgrade | Host → owning peer (effect RPC) | Owning peer (element proc reads element_tier) | element_tier is per-player state on Player node |
| Stage transition | Host (triggers set_evolution_stage RPC) | Owning peer (applies visual swap and stat boost) | Stage threshold check runs on owning peer (inside receive_xp); host must confirm/trigger to remain authoritative |
| Stage visual swap | Owning peer + all peers (Node2D children replicate) | — | Stage containers are Node2D children of Player, visible on all peers via scene structure |
| XP/Level/Stage HUD | Owning peer only (CanvasLayer) | — | D-18: local CanvasLayer, shown only when is_multiplayer_authority() |
| LevelUpLabel (teammate indicator) | All peers (derived from synced is_picking_card) | — | is_picking_card is synced via MultiplayerSynchronizer; _process shows label when true |
| Game-over XP/stage reset | All peers (call_local _broadcast_game_over) | — | Mirrors existing WeaponManager.reset() pattern in GameState._broadcast_game_over |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot 4.6 | 4.6 | Engine | Project constraint |
| GDScript | built-in | Scripting | Project constraint |
| ENet via MultiplayerSynchronizer | built-in | State replication | Established in Phase 1 |

### Supporting (Godot built-ins used by Phase 6)
| Node Type | Purpose | When to Use |
|-----------|---------|-------------|
| CanvasLayer | Per-player HUD and card overlay | All screen-space UI (PlayerHUD, CardOverlay) |
| ProgressBar | XP bar fill | XPBar in PlayerHUD |
| ColorRect | Card panels, stage visuals, borders | All placeholder visuals per PROJECT.md policy |
| Label | Level/stage labels, card text, LevelUpLabel | All text display |
| HBoxContainer / VBoxContainer | Layout containers | HUDRow (HBox), OverlayContainer (VBox), CardsRow (HBox) |
| PanelContainer | Card wrapper with min size | Card0, Card1, Card2 in CardsRow |
| Node2D | Stage visual containers in Player.tscn world space | Stage1Container, Stage2Container, Stage3Container |
| SceneReplicationConfig | MultiplayerSynchronizer property list | Extend Player.tscn to add xp, level, element_tier, is_picking_card, stage3_damage_mult |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CanvasLayer for HUD | World-space Labels on Player | CanvasLayer is correct per D-18; world-space would scale/move with camera |
| SceneTree pause for card pick | is_picking_card flag | Pause would block all other players' input (W4 violation) |
| Shared XP pool | Per-player XP on Player | Per-player is D-05; shared would require GameState tracking |

**Installation:** No npm/external packages. All Godot built-ins.

---

## Architecture Patterns

### System Architecture Diagram

```
[Enemy dies]
     │
     ▼
[Game.gd _on_enemy_died] → PickupSpawner.spawn XpOrb
                                    │
                                    ▼ (orb touches player)
                            [XpOrb._on_body_entered]
                                    │
                                    ▼
                            [_request_collect RPC → host]
                                    │
                             ┌──────┴──────┐
                             │  HOST ONLY  │
                             │  _collected │
                             │  guard      │
                             │  queue_free │
                             │  receive_xp │◄── NEW: player_node.receive_xp.rpc_id(peer_id, 5)
                             └──────┬──────┘
                                    │ RPC to owning peer
                                    ▼
                            [Player.receive_xp(amount)]  ← owning peer
                                    │
                             xp += amount
                             update XPBar.value
                                    │
                             if xp >= threshold?
                                    │ YES
                             ┌──────▼──────────────┐
                             │  is_picking_card = true (synced)
                             │  is_invulnerable = true
                             │  CardOverlay.visible = true
                             │  level += 1
                             │  draw_cards() → 3 random eligible cards
                             └──────┬──────────────┘
                                    │ A/D cycles, Space/Enter confirms
                                    ▼
                    [Player sends confirm_card_pick RPC → host (card_index)]
                                    │
                             ┌──────▼──────┐
                             │  HOST       │
                             │  validates  │
                             │  broadcasts │
                             │  effect RPC │
                             └──────┬──────┘
                                    │ effect RPC(s) to owning peer
                                    ▼
                    [apply_card_effect on owning peer]
                    (WeaponManager.add_weapon / weapon_level++ / element_tier++ / stat boost)
                                    │
                    [is_picking_card = false, xp = 0, XPBar reset]

[Stage threshold check]  ←──────── runs in receive_xp after level increment
     │  level == STAGE2_LEVEL?
     ▼  YES
[host calls set_evolution_stage.rpc_id(peer_id, 2)]
     │
     ▼
[Player.set_evolution_stage(2)]  ← owning peer
     │
[call_deferred("_swap_stage_visual", 2)]
[_use_role_ability() now routes to _use_stage2_ability()]
```

### Recommended Project Structure

No new top-level directories needed. New files slot into existing structure:

```
scenes/
├── ui/
│   ├── PlayerHUD.tscn       # NEW: per-player XP/Level/Stage HUD CanvasLayer
│   └── CardOverlay.tscn     # NEW: 3-card level-up selection CanvasLayer
├── Player.gd                # MODIFY: xp/level/element_tier/is_picking_card/stage3_damage_mult vars,
│                            #         receive_xp RPC, set_evolution_stage body, _swap_stage_visual,
│                            #         _build_card_pool, _draw_cards, _unhandled_input card nav,
│                            #         element_tier application in _tick_element
├── Player.tscn              # MODIFY: SceneReplicationConfig + Stage1/2/3Container nodes +
│                            #         LevelUpLabel + PlayerHUD + CardOverlay as children
├── pickups/
│   └── XpOrb.gd             # MODIFY: add receive_xp call in _request_collect
├── weapons/
│   ├── WeaponManager.gd     # MODIFY: airbag_active→airbag_count, upgrade_weapon() method
│   ├── ExhaustFlames.gd     # MODIFY: level 2/3 stat scaling in _on_fire_timer
│   ├── SpinningTires.gd     # MODIFY: level 2/3 orbit count and speed in _physics_process
│   ├── AntennaBeam.gd       # MODIFY: level 2/3 burst and damage scaling in _on_fire_timer
│   ├── HornShockwave.gd     # MODIFY: level 2/3 radius/cooldown/stun in _on_fire_timer
│   └── AirbagShield.gd      # MODIFY: airbag_count support
├── Game.gd                  # MODIFY: add confirm_card_pick RPC
autoloads/
└── GameState.gd             # MODIFY: _broadcast_game_over adds xp/level/element_tier/stage resets
```

---

### Pattern 1: XP Grant — host → owning peer RPC

**What:** Host receives orb collection in `_request_collect`, identifies collecting player by `multiplayer.get_remote_sender_id()`, then sends `receive_xp` RPC to that peer's Player node. [VERIFIED: live XpOrb.gd + Player.gd]

**When to use:** Immediately after `queue_free()` in `_request_collect`.

```gdscript
# Source: XpOrb.gd _request_collect — verified live code pattern
@rpc("any_peer", "call_remote", "reliable")
func _request_collect(_orb_name: String) -> void:
    if not multiplayer.is_server():
        return
    if _collected:
        return
    _collected = true
    # Identify collector — sender_id is the peer who called rpc_id(1, name)
    var collector_peer_id: int = multiplayer.get_remote_sender_id()
    # Find Player node for that peer
    var player_node: Node = null
    for p in get_tree().get_nodes_in_group("players"):
        if p.peer_id == collector_peer_id:
            player_node = p
            break
    if player_node:
        player_node.receive_xp.rpc_id(collector_peer_id, 5)
    queue_free()
```

**Note:** `multiplayer.get_remote_sender_id()` returns 0 when host calls directly (not via RPC). The `if body.peer_id != multiplayer.get_unique_id(): return` guard in `_on_body_entered` already ensures only the collecting peer sends the RPC to host, so `get_remote_sender_id()` will always be the correct non-zero peer_id. [VERIFIED: XpOrb.gd lines 15-22]

---

### Pattern 2: receive_xp RPC — owning peer handles level-up and stage check

**What:** `receive_xp` runs on the owning peer only (`@rpc("any_peer", "call_remote", "reliable")`). Increments `xp`, updates HUD, checks level threshold, checks stage threshold. Stage threshold check must send RPC back to host to trigger `set_evolution_stage`. [VERIFIED: established RPC pattern in receive_damage, receive_heal, receive_revive]

```gdscript
# Source: Pattern derived from receive_damage / receive_heal — verified live code
@rpc("any_peer", "call_remote", "reliable")
func receive_xp(amount: int) -> void:
    if is_downed:
        return
    xp += amount
    _update_xp_hud()
    var threshold: int = _xp_threshold(level)
    if xp >= threshold:
        xp -= threshold
        level += 1
        _trigger_card_pick()
        _check_stage_threshold()

func _xp_threshold(lvl: int) -> int:
    return 100 + (lvl - 1) * 50  # D-02

func _check_stage_threshold() -> void:
    # Stage threshold decision: send to host to remain authoritative (P8)
    if level == STAGE2_LEVEL and evolution_stage < 2:
        if multiplayer.is_server():
            set_evolution_stage(2)
        else:
            set_evolution_stage.rpc_id(1, 2)  # host triggers RPC back to self
    elif level == STAGE3_LEVEL and evolution_stage < 3:
        if multiplayer.is_server():
            set_evolution_stage(3)
        else:
            set_evolution_stage.rpc_id(1, 3)
```

**Key issue:** `set_evolution_stage` is `@rpc("any_peer", "call_remote", "reliable")`. The owning peer (not host) calls this. For stage check to remain host-authoritative, the owning peer must send the stage check intent to the host, and the host then calls `set_evolution_stage.rpc_id(peer_id, stage)` on the owning peer. See Pattern 3.

---

### Pattern 3: set_evolution_stage — existing RPC stub, Phase 6 extends the body

**What:** `set_evolution_stage` already exists as `@rpc("any_peer", "call_remote", "reliable")` with an empty body (Player.gd line 447). Phase 6 fills in the body: sets `evolution_stage`, calls `_swap_stage_visual`, applies Stage 3 stat boost. [VERIFIED: Player.gd line 445-448]

```gdscript
# Source: Player.gd lines 445-448 — existing stub, Phase 6 fills body
@rpc("any_peer", "call_remote", "reliable")
func set_evolution_stage(stage: int) -> void:
    evolution_stage = stage
    call_deferred("_swap_stage_visual", stage)  # D-13: instant, deferred for physics safety
    if stage == 3:
        # D-22: Stage 3 stat boost — applied once on transition
        stage3_damage_mult = 1.2
        MAX_HP += 25
        health = mini(health + 25, MAX_HP)

func _swap_stage_visual(stage: int) -> void:
    # Hide all stage containers, show the correct one
    for s in [1, 2, 3]:
        var container := get_node_or_null("Stage%dContainer" % s)
        if container:
            container.visible = (s == stage)
    # Update StageLabel text/color in PlayerHUD
    _update_stage_hud(stage)
```

---

### Pattern 4: confirm_card_pick RPC — follows weapon_unlocked pattern exactly

**What:** Client sends card pick index to host. Host validates, calls effect RPCs. Mirrors `weapon_unlocked` in Game.gd (`@rpc("authority", "call_remote", "reliable")`). [VERIFIED: Game.gd lines 330-336]

```gdscript
# Source: Pattern from Game.gd weapon_unlocked lines 330-336
# Client (owning peer) sends:
game.confirm_card_pick.rpc_id(1, peer_id, _selected_card)

# Host receives and applies:
@rpc("any_peer", "call_remote", "reliable")
func confirm_card_pick(requester_peer_id: int, card_index: int) -> void:
    if not multiplayer.is_server():
        return
    # Re-validate card still eligible (edge case: multiple level-ups fast)
    var card_data: Dictionary = _get_card_at_index(requester_peer_id, card_index)
    if card_data.is_empty():
        return
    _apply_card_effect(requester_peer_id, card_data)
    # Broadcast "pick complete" back to owning peer
    _card_pick_complete.rpc_id(requester_peer_id)
```

---

### Pattern 5: MultiplayerSynchronizer extension — SceneReplicationConfig in .tscn

**What:** New properties are added directly to the `SceneReplicationConfig` sub-resource in Player.tscn. Godot 4 supports adding properties to an existing `SceneReplicationConfig` without breaking existing replication — the config is just an ordered list. New entries are appended as properties/6 through properties/10. [VERIFIED: Player.tscn lines 10-29 — existing config structure]

```tscn
# Source: Player.tscn SceneReplicationConfig sub-resource — verified live format
[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_1"]
# ... existing properties/0 through properties/5 unchanged ...
properties/6/path = NodePath(".:xp")
properties/6/allow_spawn = true
properties/6/replication_mode = 2
properties/7/path = NodePath(".:level")
properties/7/allow_spawn = true
properties/7/replication_mode = 2
properties/8/path = NodePath(".:element_tier")
properties/8/allow_spawn = true
properties/8/replication_mode = 2
properties/9/path = NodePath(".:is_picking_card")
properties/9/allow_spawn = true
properties/9/replication_mode = 2
properties/10/path = NodePath(".:stage3_damage_mult")
properties/10/allow_spawn = true
properties/10/replication_mode = 2
```

**Important:** `replication_mode = 2` is the integer for `REPLICATION_MODE_ALWAYS` (syncs every interval). Matches existing properties. [VERIFIED: Player.tscn line 15]

---

### Pattern 6: Weapon upgrade stat scaling — read weapon_level in fire path

**What:** Each weapon's fire timer callback reads `weapon_manager.get_parent().get_node("WeaponManager").weapon_level[weapon_id]` (or equivalent) to choose damage/spread/etc. The `weapon_level` dict is already on WeaponManager, set to 1 at unlock. Card picks increment it. [VERIFIED: WeaponManager.gd line 97]

**Stage 3 damage multiplier:** Each weapon's damage line must multiply by `get_parent().get_parent().stage3_damage_mult` (WeaponManager → Player). Default is 1.0. Set to 1.2 on Stage 3.

Example for ScrewsAndBolts in WeaponManager._fire_screws():
```gdscript
# Source: WeaponManager.gd lines 51-69 — existing _fire_screws pattern
func _fire_screws() -> void:
    var player: CharacterBody2D = get_parent()
    var level: int = weapon_level.get("screws_and_bolts", 1)
    var nearest := _find_nearest_enemy(player)
    if nearest == null:
        return
    var base_dir: Vector2 = (nearest.global_position - player.global_position).normalized()
    var game := get_node_or_null("/root/Game")
    if game == null:
        return
    # Level 1: 1 bolt straight
    # Level 2: 2 bolts ±15°  (D-11)
    # Level 3: 3 bolts ±30°, cooldown 0.35s  (D-11)
    var dirs: Array = _get_screws_dirs(base_dir, level)
    for d in dirs:
        if multiplayer.is_server():
            game.get_node("BulletSpawner").spawn({"pos": player.global_position, "dir": d, "owner_id": player.peer_id})
        else:
            game.request_fire.rpc_id(1, player.global_position, d, player.peer_id)
```

---

### Pattern 7: Airbag bool → int migration

**What:** `airbag_active: bool` in WeaponManager becomes `airbag_count: int`. `consume_airbag()` decrements instead of clearing. `Player.receive_damage` check becomes `airbag_count > 0` instead of `airbag_active`. [VERIFIED: WeaponManager.gd line 22, Player.gd line 419]

```gdscript
# WeaponManager changes (verified from lines 22, 89-100, 118, 173-176):
var airbag_count: int = 0   # was: airbag_active: bool = false

# in add_weapon("airbag_shield"):
#   was: if not airbag_active: airbag_active = true
#   now: airbag_count = mini(airbag_count + 1, MAX_AIRBAG_LEVEL2_CHARGES)  # level 3 = 2 charges

func consume_airbag() -> void:
    airbag_count = maxi(airbag_count - 1, 0)
    if airbag_count == 0:
        if has_node("AirbagShield"):
            get_node("AirbagShield").hide_ring()

# Player.gd receive_damage change (verified from line 419):
#   was: if health - amount <= 0 and has_node("WeaponManager") and $WeaponManager.airbag_active:
#   now: if health - amount <= 0 and has_node("WeaponManager") and $WeaponManager.airbag_count > 0:
```

**Level 2 airbag behavior:** Absorbs lethal hit AND heals to 25% HP instead of 1 HP. Requires reading `weapon_level.get("airbag_shield", 1)` inside receive_damage or consume_airbag path to know whether to heal.

---

### Pattern 8: Card pool construction and filtering

**What:** Card pool is built fresh each time a player levels up. Filter reads current WeaponManager state. [VERIFIED: WeaponManager.gd unlocked_weapons and weapon_level fields]

```gdscript
# Source: Pattern derived from CONTEXT.md D-11/D-19/D-20, XP-05/XP-06 requirements
func _build_card_pool() -> Array[Dictionary]:
    var pool: Array[Dictionary] = []
    var wm: Node = get_node("WeaponManager")

    # Weapon unlocks (XP-04, XP-05)
    for wid in ["exhaust_flames", "spinning_tires", "antenna_beam", "horn_shockwave", "airbag_shield"]:
        if not wm.unlocked_weapons.has(wid):
            pool.append({"type": "weapon_unlock", "weapon_id": wid})

    # Weapon upgrades (XP-04, XP-05)
    for wid in wm.unlocked_weapons:
        var lvl: int = wm.weapon_level.get(wid, 1)
        if lvl < 3:  # max level is 3
            pool.append({"type": "weapon_upgrade", "weapon_id": wid, "new_level": lvl + 1})

    # Element upgrades (D-19, D-20)
    if element_tier < 3:
        pool.append({"type": "element_upgrade", "new_tier": element_tier + 1})

    # Stat boosts (XP-04) — always eligible
    for stat in ["Speed", "Max HP", "Damage", "Cooldown"]:
        pool.append({"type": "stat_boost", "stat": stat, "amount": 10})

    # XP-06: Fallback always ensures pool never empty
    if pool.size() == 0:
        pool.append({"type": "fallback"})

    return pool

func _draw_cards(pool: Array[Dictionary]) -> Array[Dictionary]:
    pool.shuffle()
    var cards: Array[Dictionary] = []
    for i in range(mini(3, pool.size())):
        cards.append(pool[i])
    # XP-06: Pad to 3 with fallback if needed
    while cards.size() < 3:
        cards.append({"type": "fallback"})
    return cards
```

---

### Pattern 9: LevelUpLabel driven by synced is_picking_card

**What:** `is_picking_card` is replicated via MultiplayerSynchronizer. All peers' `_process` can check `is_picking_card` on remote Player nodes and show/hide the LevelUpLabel accordingly. No RPC needed — the label state is purely derived from the already-synced bool. [VERIFIED: CONTEXT.md D-10, Pattern follows existing `_process` usage in Player.gd lines 71-79]

```gdscript
# In Player.gd _process (runs on ALL peers from synced values):
func _process(_delta: float) -> void:
    # ... existing downed tint logic ...
    # D-10: Show LevelUpLabel when this player is picking a card
    if has_node("LevelUpLabel"):
        $LevelUpLabel.visible = is_picking_card
        if is_picking_card:
            $LevelUpLabel.text = "%s is leveling up!" % role_label
```

---

### Anti-Patterns to Avoid

- **SceneTree.paused for card pick:** Blocks all other players' _process. Use is_picking_card flag and CanvasLayer only (W4).
- **Client-side XP increment:** Client should never increment xp directly from body_entered. Must flow through host via _request_collect + receive_xp RPC (P8).
- **Empty card pool without fallback:** Always append fallback before drawing. Test with all weapons max-level, element_tier = 3 (W3).
- **Double-level from multiple orbs landing simultaneously:** xp threshold check must subtract threshold from xp and re-check; do not just set xp = 0 (handles multiple levels in quick succession).
- **Stage threshold check client-side without host round-trip:** The owning peer detects the threshold but must route the stage change through the host (or use the existing set_evolution_stage RPC which is "any_peer" — host calls it on owning peer). See note in Pattern 2.
- **Forgetting to call add_weapon in WeaponManager for weapon_unlock cards:** The confirm_card_pick handler in Game.gd can reuse the existing `weapon_unlocked.rpc_id(peer_id, weapon_id)` call for weapon_unlock card effects.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Screen-space HUD anchoring | Custom position update in _process | CanvasLayer + Control anchor presets | CanvasLayer is always screen-relative; no manual offset math |
| Card panel selection highlight | Manual ColorRect color loop | Direct `get_node("Card%dBorder" % i).color = ...` in _process | Simple and already the pattern used for all visuals in this project |
| Weapon stat lookup | Per-weapon if-chains in fire paths | `weapon_level.get(weapon_id, 1)` dict read | Already exists in WeaponManager; just read it |
| RPC for LevelUpLabel visibility | Separate broadcast RPC | Derived from synced is_picking_card in _process | Reuses existing MultiplayerSynchronizer replication; fewer RPCs |
| Custom animation for stage swap | Tween-based transform | call_deferred("_swap_stage_visual", N) — instant show/hide | D-13 explicitly locks instant swap; animation is v2 |

**Key insight:** Every problem in Phase 6 has a pre-paved path from Phases 3–5. The collision guard patterns, authority guard patterns, deferred add_child patterns, and RPC routing patterns all have proven examples in the codebase. Do not deviate from established patterns.

---

## Common Pitfalls

### Pitfall W3: Empty card pool crash
**What goes wrong:** At high level with all weapons maxed and element at Tier 3, the filtered pool might have only stat boost entries. If stat boosts are also removed or pool.size() returns 0, `_draw_cards` crashes on index 0.
**Why it happens:** Forgetting to always include at least one fallback entry.
**How to avoid:** After all filters, always append `{"type": "fallback"}` if `pool.size() == 0`. The `_draw_cards` pad loop ensures 3 cards even if pool has < 3 entries.
**Warning signs:** Crash in receive_xp or _trigger_card_pick when playing with a veteran player.

### Pitfall W4: SceneTree pause blocks other players
**What goes wrong:** Using `get_tree().paused = true` when a player levels up freezes all physics, input, and _process for ALL players, not just the leveling one.
**Why it happens:** Tempting as a quick "freeze game while picking" solution.
**How to avoid:** `is_picking_card = true` flag blocks movement/ability input in `_physics_process` and `_unhandled_input` on the owning peer only. CanvasLayer does not need SceneTree pause to display.
**Warning signs:** Testing with 2 players: Player 2 freezes when Player 1 levels up.

### Pitfall W5: XP sync lag / double-grant
**What goes wrong:** If XP were incremented client-side from `_on_body_entered`, the orb could be collected by two peers simultaneously before the host's `_collected` guard fires.
**Why it happens:** The `_on_body_entered` fires on all peers locally when physics detects contact.
**How to avoid:** XpOrb already has `if body.peer_id != multiplayer.get_unique_id(): return` — only the touching peer sends the RPC. Host validates with `_collected` guard. `receive_xp` is sent from host only after `queue_free()`, preventing double-grant.
**Warning signs:** Player XP jumping by 10 instead of 5 on orb collection.

### Pitfall P8: Card effect applied without host validation
**What goes wrong:** Client applies weapon level++ directly without confirm_card_pick RPC, allowing forged card effects.
**Why it happens:** Shortcut: "the client knows which card they picked."
**How to avoid:** Owning peer sends `confirm_card_pick.rpc_id(1, peer_id, card_index)`. Host re-validates eligibility (card still valid for current state) then broadcasts effect RPC. For weapon_unlock effects, host can reuse `weapon_unlocked.rpc_id(peer_id, weapon_id)`.
**Warning signs:** Clients can level up weapons faster than expected; desync between host and client weapon_level.

### Pitfall: Stage 3 damage multiplier missing from one weapon
**What goes wrong:** `stage3_damage_mult` applied to 5 of 6 weapons; one weapon still does base damage at Stage 3.
**Why it happens:** Six separate weapon fire paths must each be modified; easy to miss one.
**How to avoid:** After implementing all weapon upgrades, do a grep for all `take_damage` and bullet spawn calls and verify each multiplies by `get_parent().get_parent().stage3_damage_mult` or passes the modified damage.
**Warning signs:** Stage 3 damage boost feels less than 20% because one weapon is not multiplied.

### Pitfall: airbag_active references in Player.gd not updated after migration
**What goes wrong:** Player.gd `receive_damage` still checks `$WeaponManager.airbag_active` (bool) after WeaponManager migrates to `airbag_count: int`.
**Why it happens:** Two files reference the same field; updating one without updating the other.
**How to avoid:** Search for all `airbag_active` references before the migration task and update all simultaneously: WeaponManager.gd (declaration, add_weapon, consume_airbag, reset) and Player.gd (receive_damage check).
**Warning signs:** Airbag Level 2/3 behavior broken; Level 1 may still work if `int > 0` is truthy in GDScript (it is, but the heal-to-25% logic requires explicit level check).

### Pitfall: MultiplayerSynchronizer property added in script but not .tscn
**What goes wrong:** New vars `xp`, `level`, etc. are declared in Player.gd but not added to `SceneReplicationConfig` in Player.tscn, so other peers never see updated values.
**Why it happens:** Godot 4 MultiplayerSynchronizer config lives in the .tscn, not auto-detected from script vars.
**How to avoid:** Player.tscn SceneReplicationConfig must be manually extended with new property paths. Verify by checking if `$MultiplayerSynchronizer.get_replication_config()` contains the new paths in debug.
**Warning signs:** Other players always see XP = 0 and level = 1 for remote players; LevelUpLabel never appears.

---

## Code Examples

### Verified Fire Pattern Reference (ExhaustFlames.gd — Level Scaling Insertion Point)

```gdscript
# Source: ExhaustFlames.gd _on_fire_timer (verified live) — shows WHERE level reads insert
func _on_fire_timer(weapon_manager: Node) -> void:
    var player: Node = weapon_manager.get_parent()
    if not player.is_multiplayer_authority():
        return
    if player.is_downed:
        return
    # Phase 6 insertion: read level and compute level-specific params
    var level: int = weapon_manager.weapon_level.get("exhaust_flames", 1)
    var half_angle: float = HALF_ANGLE                  # L1: ±30° (60° total)
    var radius: float = RADIUS                          # L1: 120px
    var damage: int = int(DAMAGE * player.stage3_damage_mult)
    if level >= 2:
        half_angle = deg_to_rad(45.0)                   # L2: 90° total
        radius = 160.0
    if level >= 3:
        half_angle = deg_to_rad(60.0)                   # L3: 120° total
        # L3 slow applied in damage loop below
    # ... rest of fire logic uses half_angle, radius, damage ...
```

### Verified Game.gd RPC Pattern (weapon_unlocked — template for confirm_card_pick)

```gdscript
# Source: Game.gd lines 330-336 — confirmed live template
@rpc("authority", "call_remote", "reliable")
func weapon_unlocked(weapon_id: String, collector_peer_id: int) -> void:
    for p in get_tree().get_nodes_in_group("players"):
        if p.peer_id == collector_peer_id:
            if p.has_node("WeaponManager"):
                p.get_node("WeaponManager").add_weapon(weapon_id)
            return
# confirm_card_pick follows the same @rpc("any_peer", "call_remote", "reliable") pattern
# (note: weapon_unlocked uses "authority" but confirm_card_pick must accept from any peer,
# so use "any_peer" + is_server() guard — same as attempt_revive pattern)
```

### Verified _broadcast_game_over Reset Pattern (GameState.gd)

```gdscript
# Source: GameState.gd lines 48-56 — confirmed live template for Phase 6 extension
@rpc("authority", "call_local", "reliable")
func _broadcast_game_over() -> void:
    for p in get_tree().get_nodes_in_group("players"):
        if p.has_node("WeaponManager"):
            p.get_node("WeaponManager").reset()
        # Phase 6 additions (D-14, EVOL-06):
        p.xp = 0
        p.level = 1
        p.element_tier = 1
        p.stage3_damage_mult = 1.0
        if p.has_method("set_evolution_stage"):
            p.set_evolution_stage(1)  # triggers _swap_stage_visual(1) via call_deferred
    get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Shared/global XP pool | Per-player XP on Player node | Design decision (D-05) | Each player levels independently |
| Loop-end card picks | Mid-run XP-triggered picks | Design decision | Standard Vampire Survivors feel |
| airbag_active: bool | airbag_count: int (Phase 6) | Phase 6 migration | Enables Level 3 dual-charge airbag |
| set_evolution_stage RPC stub (empty body) | Full body with visual swap + stats | Phase 6 implements | Stage transition actually works |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `multiplayer.get_remote_sender_id()` correctly returns the collecting peer's ID in `_request_collect` when called via `_request_collect.rpc_id(1, name)` from the client | Pattern 1 — XP Grant | If it returns 0 (host-call case), xp grant would fail silently. Mitigated: the `_on_body_entered` guard ensures non-host peers call rpc_id(1), so sender will be non-zero peer. [ASSUMED — not verified by running the code] |
| A2 | Stage threshold level numbers (e.g., Level 6 for Stage 2) will produce the correct ~8-10 min timing with 5 XP/orb and current enemy density | D-03 timing | Wrong threshold means Stage 2 comes too early (trivial) or too late (players never reach it in demo). Planner must calculate from formula and verify empirically. [ASSUMED — timing requires gameplay testing] |
| A3 | Adding 5 new properties to SceneReplicationConfig does not degrade multiplayer performance noticeably | Pattern 5 — MultiplayerSynchronizer | At 20 Hz sync interval, 5 extra int/bool/float properties add < 20 bytes per sync packet. Should be negligible on LAN. [ASSUMED — not measured] |

---

## Open Questions

1. **Stage 2 and Stage 3 exact level thresholds (D-03, D-04)**
   - What we know: D-02 formula gives XP-to-level mapping. D-03 says Stage 2 must be reachable before Room 3 (~8-10 min). Enemy density is ~8 initial enemies, respawning on death (Game.gd _on_enemy_died always spawns a replacement).
   - What's unclear: Exact enemies-per-minute rate in Room 1 with current spawn setup. 8 enemies × 5 XP/kill = 40 XP per "clear". Level 2 requires 100 XP (20 kills), Level 3 requires 150 XP more (30 kills). At ~3-5 enemies per minute, Level 2 in ~4-7 min, Level 5 in ~18-25 min.
   - Recommendation: Planner should calculate Stage 2 at Level 5 (requires 100+150+200+250 = 700 XP total) and Stage 3 at Level 10 or higher. Start with Stage 2 = Level 5, Stage 3 = Level 10. Adjust XP per orb if timing is off.

2. **Stage threshold authority: who detects and who triggers?**
   - What we know: `receive_xp` runs on owning peer. `set_evolution_stage` is `@rpc("any_peer", "call_remote")`.
   - What's unclear: The cleanest authoritative path. Option A: owning peer detects threshold in `receive_xp`, sends `request_stage_change.rpc_id(1, stage)` to host, host calls `set_evolution_stage.rpc_id(peer_id, stage)`. Option B: owning peer calls `set_evolution_stage.rpc_id(1, stage)` to host, host re-calls `set_evolution_stage.rpc_id(peer_id, stage)`. Option C: since level/xp are already authoritative via receive_xp (host sent the XP), owning peer can self-apply stage change directly.
   - Recommendation: Option C is simplest and consistent with how health changes work (receive_damage runs on owning peer and directly mutates health). The owning peer's `receive_xp` is already gated by the host's `receive_xp.rpc_id(peer_id)` call — it's host-authorized. Stage change from that same path is implicitly authorized. Planner should adopt Option C to avoid extra RPC round-trips.

3. **confirm_card_pick RPC: where does the card pool live during pick?**
   - What we know: Card pool is built on the owning peer in `_trigger_card_pick()`. After Space is pressed, owning peer sends `confirm_card_pick.rpc_id(1, peer_id, card_index)`.
   - What's unclear: Host re-validates by re-building the card pool. But between the card draw and the confirmation, no state has changed (is_picking_card prevents new level-ups). Host can safely re-build the same pool deterministically since weapon_level and element_tier are synced.
   - Recommendation: Host re-builds pool using the same `_build_card_pool()` logic (move to Player.gd as a static-like helper), validates `card_index < pool.size()`, then applies. Host reads WeaponManager state from the player node's synced properties.

---

## Environment Availability

Phase 6 is purely code/configuration changes within the existing Godot 4.6 project. No new external tools, services, or runtimes required. Step 2.6: SKIPPED (no external dependencies beyond existing Godot engine installation).

---

## Validation Architecture

Step skipped — `workflow.nyquist_validation` is explicitly `false` in `.planning/config.json`.

---

## Security Domain

This is a LAN-only game (PROJECT.md: "LAN only, manual IP entry"). No internet exposure, no authentication, no user data. No ASVS categories apply to this game phase.

---

## Sources

### Primary (HIGH confidence)
- `scenes/Player.gd` — All per-player state, RPC patterns, receive_damage, set_evolution_stage stub, _tick_element, _apply_role_stats — verified live
- `scenes/Player.tscn` — MultiplayerSynchronizer SceneReplicationConfig properties 0–5, node structure — verified live
- `scenes/pickups/XpOrb.gd` — _request_collect host-authoritative handler, _collected guard, _on_body_entered peer filter — verified live
- `scenes/weapons/WeaponManager.gd` — weapon_level dict, airbag_active bool, add_weapon, reset, _fire_screws, _activate_weapon_node — verified live
- `scenes/weapons/ExhaustFlames.gd` — fire timer pattern with authority guard, damage application — verified live
- `scenes/weapons/SpinningTires.gd` — _physics_process orbit + host-only damage — verified live
- `scenes/weapons/AntennaBeam.gd` — two-burst potential (Lv2), _apply_damage RPC — verified live
- `scenes/weapons/HornShockwave.gd` — radius, cooldown, show_visual pattern — verified live
- `scenes/weapons/AirbagShield.gd` — hide_ring, deactivate, show_ring — verified live
- `scenes/Game.gd` — weapon_unlocked RPC template, confirm_card_pick template target, _on_enemy_died spawn pattern — verified live
- `autoloads/GameState.gd` — _broadcast_game_over structure and reset path — verified live
- `.planning/phases/06-xp-level-up-cards-and-evolution/06-CONTEXT.md` — 22 implementation decisions D-01 through D-22 — primary design authority
- `.planning/phases/06-xp-level-up-cards-and-evolution/06-UI-SPEC.md` — exact node names, sizes, colors, strings, keyboard map — design contract

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` — XP-01 through XP-09, EVOL-01 through EVOL-06 requirement text
- `.planning/ROADMAP.md` — Phase 6 pitfall watch W3/W4/W5/P8, success criteria

---

## Metadata

**Confidence breakdown:**
- Codebase state audit: HIGH — all key files read and verified
- Standard stack: HIGH — Godot built-ins only, no external deps
- Architecture patterns: HIGH — all patterns derived from verified live code
- Pitfalls: HIGH — W3/W4/W5/P8 verified against live code structure, specific lines identified
- XP timing (Stage threshold levels): LOW — requires gameplay testing to confirm, D-03 explicitly marks as "planner must calculate"

**Research date:** 2026-06-18
**Valid until:** 2026-07-18 (stable codebase — no external library versioning concerns)
