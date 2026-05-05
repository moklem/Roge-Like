# Weapons, XP & Evolution — Godot 4 Implementation Patterns

**Project:** Roge-Like — Vampire Survivors-style weapon + XP system
**Researched:** 2026-05-05

---

## 1. Weapon System Architecture

### Recommended Structure: WeaponManager as Player Child

```
Player (CharacterBody2D)
├── MultiplayerSynchronizer   — position, health, stage, xp
├── WeaponManager (Node)      — owns all active weapons
│   ├── ScrewBolt (Weapon)    — starter weapon, always present
│   ├── ExhaustFlame (Weapon) — added on pickup
│   └── SpinningTire (Weapon) — added on pickup
├── HitBox (Area2D)
└── Sprite2D / visuals
```

**Why WeaponManager:** Weapons need their own independent timers, upgrade levels, and fire logic. A dedicated node makes it easy to:
- Iterate all active weapons in `_physics_process`
- Add/remove weapons without touching Player logic
- Serialize weapon state for sync (array of {id, level} dicts)

### Weapon as Scene / Resource

Each weapon is a **scene** (`ScrewBolt.tscn`, `ExhaustFlame.tscn`) that:
- Has its own `Timer` node for fire rate
- Has `level: int` property (1–3)
- Has `func fire()` that spawns a projectile or area effect
- Connects its own timer's `timeout` signal to its `fire()` function

```gdscript
# WeaponManager.gd
var active_weapons: Array[Node] = []
const MAX_WEAPONS = 6

func add_weapon(weapon_scene: PackedScene) -> void:
    if active_weapons.size() >= MAX_WEAPONS: return
    var w = weapon_scene.instantiate()
    add_child(w)
    active_weapons.append(w)

func upgrade_weapon(weapon_id: String) -> void:
    for w in active_weapons:
        if w.weapon_id == weapon_id:
            w.level = min(w.level + 1, 3)
            w.apply_level_stats()
            return
```

### Network Authority: Weapons Fire on Host Only

```gdscript
# Weapon.gd
func _ready():
    $Timer.timeout.connect(_on_fire_timer)

func _on_fire_timer():
    if not get_parent().get_parent().is_multiplayer_authority():
        return  # only host (or owning player) fires
    fire()

func fire():
    # Spawn projectile via BulletSpawner
    # Host-authoritative: spawn position + direction sent to all via MultiplayerSpawner
    pass
```

**Client experience:** Clients see bullet spawns via `MultiplayerSpawner` (same pattern as enemy bullets). Weapon timers run everywhere but only host calls `fire()`. Divergence on timer drift is negligible on LAN (timers are cosmetic on clients — actual damage is server-side).

### Syncing Weapon State Across Network

Weapon loadout is NOT synced via MultiplayerSynchronizer (too dynamic). Instead:
```gdscript
# When host confirms a weapon pick:
@rpc("call_local", "reliable")
func sync_weapon_add(peer_id: int, weapon_id: String):
    if peer_id == multiplayer.get_unique_id():
        $WeaponManager.add_weapon_by_id(weapon_id)
```

Each player owns their own weapon list. Host validates picks, broadcasts weapon additions to all.

---

## 2. Item Pickup System

### Enemy Death → Pickup Drop

```gdscript
# Enemy.gd (host only — guarded by is_multiplayer_authority())
func die():
    if not is_multiplayer_authority(): return
    var drop_chance = randf()
    if drop_chance < DROP_RATE:
        _spawn_pickup.rpc(global_position, _pick_random_item())
    queue_free()

@rpc("call_local", "reliable")
func _spawn_pickup(pos: Vector2, item_id: String):
    var pickup = PICKUP_SCENE.instantiate()
    pickup.item_id = item_id
    pickup.global_position = pos
    get_tree().root.add_child(pickup)
```

**Alternative (MultiplayerSpawner):**
- Add a `PickupSpawner` (MultiplayerSpawner) node in the World scene
- Register all pickup scene variants
- Host calls `$PickupSpawner.spawn({"pos": ..., "item_id": ...})`
- Clients auto-instantiate the pickup

**Recommended:** Use MultiplayerSpawner for pickups — consistent with enemy spawning pattern, automatic cleanup on despawn.

### Pickup → Weapon Unlock Flow

```gdscript
# Pickup.gd
@export var item_id: String

func _on_body_entered(body: Node) -> void:
    if not body.is_in_group("player"): return
    if not body.is_multiplayer_authority(): return  # only collecting player responds
    body.collect_item.rpc_id(1, item_id)  # RPC to host for validation
    queue_free()

# Player.gd — host validates
@rpc("any_peer", "reliable")
func collect_item(item_id: String):
    if not is_multiplayer_authority(): return
    var sender = multiplayer.get_remote_sender_id()
    # validate sender is authorized (they own this player)
    _give_item_to_player(sender, item_id)
```

### Item Data: Resource Pattern

```gdscript
# ItemData.gd (Resource)
class_name ItemData extends Resource
@export var item_id: String
@export var display_name: String
@export var weapon_scene: PackedScene  # null if stat item
@export var stat_bonuses: Dictionary   # {"speed": 0.1, "damage": 5}
@export var description: String
```

Store all items in an `ItemDatabase` autoload (Dictionary of item_id → ItemData).

---

## 3. XP + Level-Up System

### XP as Host-Authoritative Property

```gdscript
# PlayerState.gd (synced via MultiplayerSynchronizer)
var xp: int = 0             # synced
var level: int = 1          # synced
var stage: int = 0          # synced (0=car, 1=proto-bot, 2=autobot)

# Level thresholds (example — tune during playtesting)
const LEVEL_XP = [0, 100, 250, 450, 700, 1000, 1350, 1750, ...]
const STAGE_2_LEVEL = 8    # Normal Car → Proto-Bot
const STAGE_3_LEVEL = 18   # Proto-Bot → Full AutoBot
```

### XP Drop from Enemies

```gdscript
# Enemy.gd (host only)
func die():
    if not is_multiplayer_authority(): return
    # Award XP to nearest player (or all players proportionally)
    var target = _find_nearest_player()
    _award_xp.rpc_id(target.get_multiplayer_authority(), XP_VALUE)
    _maybe_drop_pickup()
    queue_free()

# Player.gd
@rpc("authority", "reliable")
func _award_xp(amount: int):
    xp += amount
    _check_level_up()
```

### Level-Up → Card Pick (all players simultaneously)

```gdscript
# Player.gd (host authority)
func _check_level_up():
    if not is_multiplayer_authority(): return
    while level < LEVEL_XP.size() and xp >= LEVEL_XP[level]:
        level += 1
        _check_stage_up()
        _trigger_level_up_cards.rpc()  # broadcast to all — PAUSE GAME

@rpc("call_local", "reliable")
func _trigger_level_up_cards():
    GameEvents.emit_signal("show_upgrade_cards", multiplayer.get_remote_sender_id())
```

**Design decision:** Each player levels up independently. When player A levels up, the game does NOT pause for other players — only player A sees their card choice overlay. Enemies continue for other players. (Simpler than synced global-pause, better for LAN co-op feel.)

**Alternative:** Global pause when any player levels up. More complex (all clients must pause), better for co-op coordination. Recommend starting with per-player non-pause, evaluate in playtest.

---

## 4. Card Pool + Selection System

### Card Pool Structure

```gdscript
# CardPool.gd (Resource or Autoload)
# Three card categories:
# 1. WEAPON_UNLOCK — offer if player doesn't have this weapon yet
# 2. WEAPON_UPGRADE — offer if player has weapon at level < max
# 3. ELEMENT_UPGRADE — can appear N times, improves element stats
# 4. STAT_BOOST — speed / max_hp / damage_mult / cooldown_reduction

func get_random_cards(player: Node, count: int = 3) -> Array[CardData]:
    var pool = _build_eligible_pool(player)
    pool.shuffle()
    return pool.slice(0, count)

func _build_eligible_pool(player: Node) -> Array[CardData]:
    var eligible = []
    for card in ALL_CARDS:
        if card.type == CardType.WEAPON_UNLOCK:
            if not player.has_weapon(card.weapon_id):
                eligible.append(card)
        elif card.type == CardType.WEAPON_UPGRADE:
            if player.has_weapon(card.weapon_id) and player.weapon_level(card.weapon_id) < 3:
                eligible.append(card)
        elif card.type in [CardType.ELEMENT_UPGRADE, CardType.STAT_BOOST]:
            eligible.append(card)
    return eligible
```

### Card Selection Flow (per-player, non-blocking)

```
Player reaches XP threshold
→ Host generates 3 cards for that player
→ Host sends cards to that player via rpc_id(player_peer, "show_cards", cards)
→ Player's screen shows card overlay
→ Player picks → rpc(1, "card_selected", card_id) to host
→ Host applies card effect
→ Card overlay hides
```

### Applying Card Effects

```gdscript
# Player.gd (host side)
func apply_card(card: CardData) -> void:
    match card.type:
        CardType.WEAPON_UNLOCK:
            $WeaponManager.add_weapon_by_id(card.weapon_id)
        CardType.WEAPON_UPGRADE:
            $WeaponManager.upgrade_weapon(card.weapon_id)
        CardType.STAT_BOOST:
            _apply_stat_boost.rpc_id(get_multiplayer_authority(), card.stat_bonuses)
        CardType.ELEMENT_UPGRADE:
            element_level += 1
            _update_element_effects()
```

---

## 5. Evolution Stage System

### Stage Properties and Thresholds

```gdscript
# Sync via MultiplayerSynchronizer
var stage: int = 0  # 0 = Normal Car, 1 = Proto-Bot, 2 = Full AutoBot

func _check_stage_up():
    if stage == 0 and level >= STAGE_2_LEVEL:
        _set_stage.rpc(1)
    elif stage == 1 and level >= STAGE_3_LEVEL:
        _set_stage.rpc(2)

@rpc("call_local", "reliable")
func _set_stage(new_stage: int):
    stage = new_stage
    _apply_stage_visual()
    _apply_stage_abilities()
    GameEvents.fire_hud_event.rpc("STAGE_UP")  # optional HUD trigger
```

### Stage-Gated Abilities

```gdscript
func _apply_stage_abilities():
    match stage:
        0:  # Normal Car — moves/fights like a car, starter weapon only
            pass
        1:  # Proto-Bot — car FULLY transforms; now moves and fights like a robot
            # Locomotion changes: robot walk animation/movement replaces car movement
            # Visual: skeletal robot shape — raw limbs, no armor, exposed geometry
            _unlock_signature_ability()
            # visual: swap to proto-bot shape/color (distinct from car shape)
        2:  # Full AutoBot — same robot movement as Proto-Bot, now fully armored
            # No locomotion change from Stage 1 (Proto-Bot); difference is power + visuals
            _activate_all_abilities()
            max_hp_bonus = 50
            speed_bonus = 0.2
            # visual: swap to full-armor shape (larger, more decorated than proto-bot)
```

### Visual Representation (Placeholder)

Since visuals are placeholder shapes, the key is that Stage 1→2 is a shape REPLACEMENT (car shape → robot shape), not an addition. Stage 2→3 is the same robot shape made larger and more elaborate:

- **Stage 0 (Normal Car):** horizontal rectangle (car body proportions), role color
- **Stage 1 (Proto-Bot):** vertical rectangle with protruding limb rectangles — upright robot silhouette; same color but different shape entirely; noticeably raw/skeletal (thin limbs)
- **Stage 2 (Full AutoBot):** same upright robot silhouette but broader body, thicker limbs, additional detail rectangles suggesting armor plating; glow modulate applied

When sprites are added later, swap `apply_stage_visual()` to set `$Sprite2D.texture` based on stage.

### Syncing Stage to Other Clients

Stage is a property on the Player node, included in its MultiplayerSynchronizer:
```
MultiplayerSynchronizer (on Player node):
  Replicated properties: position, health, is_downed, stage, xp_visual (for XP bar display)
```

Other clients see the stage change and update their local visual via `set_notify_local_transform(true)` or a setter on `stage`:
```gdscript
var stage: int = 0:
    set(val):
        stage = val
        _apply_stage_visual()  # runs on every peer that receives the sync
```

---

## Pitfall Additions (New Systems)

**W1 — Card UI blocks input globally:** If card selection pauses the entire game and blocks enemy updates, the game freezes for players who didn't level up. Use per-player overlay with game continuing in background.

**W2 — Weapon timers drift between host and clients:** If weapon timers run on all peers and trigger fire() on clients too, you get duplicate bullets. Guard every fire() with `is_multiplayer_authority()`.

**W3 — Pickup spam / double-collect:** Two players overlapping the same pickup can each collect it before the first `queue_free()` propagates. Host must track picked-up IDs and reject duplicate `collect_item` RPCs.

**W4 — Card pool empty crash:** If a player has max-leveled every weapon AND every element AND every stat boost, `get_random_cards()` returns an empty slice. Always include a fallback card (e.g., +10% damage) that's always eligible.

**W5 — XP sync lag shows wrong level on clients:** Don't use XP value for client-side level display — sync `level` explicitly. XP on clients is display-only (XP bar); level is the authoritative gating variable.
