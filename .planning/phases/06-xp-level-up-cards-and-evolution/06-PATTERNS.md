# Phase 6: XP, Level-Up Cards & Evolution — Pattern Map

**Mapped:** 2026-06-18
**Files analyzed:** 13 new/modified files
**Analogs found:** 13 / 13

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scenes/ui/PlayerHUD.tscn` | component (CanvasLayer UI) | request-response | `scenes/Game.tscn` HUD CanvasLayer + Game.gd `_setup_player_hud` | exact |
| `scenes/ui/PlayerHUD.gd` | component | request-response | `scenes/Game.gd` `_setup_player_hud` / `_update_player_hud` | exact |
| `scenes/ui/CardOverlay.tscn` | component (CanvasLayer UI) | event-driven | `scenes/ui/GameOver.tscn` (full-screen control) + Game.tscn HUD CanvasLayer | role-match |
| `scenes/ui/CardOverlay.gd` | component | event-driven | `scenes/ui/LobbyScreen.gd` (multi-panel keyboard navigation) | role-match |
| `scenes/Player.gd` | controller | CRUD + event-driven | `scenes/Player.gd` itself — adds to existing file | exact |
| `scenes/Player.tscn` | config | — | `scenes/Player.tscn` itself — SceneReplicationConfig extension + child nodes | exact |
| `scenes/pickups/XpOrb.gd` | service | request-response | `scenes/pickups/CarPartPickup.gd` (`_request_collect` host-auth + RPC out) | exact |
| `scenes/weapons/WeaponManager.gd` | service | CRUD | `scenes/weapons/WeaponManager.gd` itself — airbag migration + upgrade_weapon | exact |
| `scenes/weapons/ExhaustFlames.gd` | service | event-driven | `scenes/weapons/ExhaustFlames.gd` `_on_fire_timer` — level read insertion point | exact |
| `scenes/weapons/SpinningTires.gd` | service | event-driven | `scenes/weapons/SpinningTires.gd` `_physics_process` — orbit count/speed scaling | exact |
| `scenes/weapons/AntennaBeam.gd` | service | event-driven | `scenes/weapons/AntennaBeam.gd` `_on_fire_timer` — burst + damage scaling | exact |
| `scenes/weapons/HornShockwave.gd` | service | event-driven | `scenes/weapons/HornShockwave.gd` `_on_fire_timer` — radius/cooldown/stun | exact |
| `scenes/weapons/AirbagShield.gd` | service | event-driven | `scenes/weapons/AirbagShield.gd` `hide_ring` + `consume_airbag` path | exact |
| `scenes/Game.gd` | controller | request-response | `scenes/Game.gd` `weapon_unlocked` RPC (lines 330-336) | exact |
| `autoloads/GameState.gd` | service | CRUD | `autoloads/GameState.gd` `_broadcast_game_over` (lines 48-56) | exact |

---

## Pattern Assignments

### `scenes/ui/PlayerHUD.tscn` (component, request-response)

**Analog:** `scenes/Game.tscn` lines 292-299 (HUD CanvasLayer node declaration)

**CanvasLayer node pattern** (Game.tscn lines 292-299):
```tscn
[node name="HUD" type="CanvasLayer" parent="." unique_id=1971261314]

[node name="PlayerLabel" type="Label" parent="HUD" unique_id=1065361644]
offset_left = 10.0
offset_top = 10.0
offset_right = 300.0
offset_bottom = 40.0
text = "Player"
```

**PlayerHUD.tscn target structure** (derived from Game.tscn CanvasLayer + LobbyScreen HBoxContainer pattern):
```tscn
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scenes/ui/PlayerHUD.gd" id="1_hud"]

[node name="PlayerHUD" type="CanvasLayer"]
script = ExtResource("1_hud")

[node name="HUDRow" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 7          # bottom-left anchor preset
anchor_left = 0.0
anchor_top = 1.0
anchor_right = 0.0
anchor_bottom = 1.0
offset_left = 10.0
offset_top = -40.0
offset_right = 500.0
offset_bottom = -10.0

[node name="LevelLabel" type="Label" parent="HUDRow"]
layout_mode = 2
text = "LVL 1"

[node name="XPBar" type="ProgressBar" parent="HUDRow"]
layout_mode = 2
size_flags_horizontal = 3
min_value = 0.0
max_value = 100.0
value = 0.0
show_percentage = false

[node name="StageLabel" type="Label" parent="HUDRow"]
layout_mode = 2
text = "Stage 1"
```

**Note:** CanvasLayer is added as child of Player.tscn at the .tscn level (not instantiated at runtime), visible only when `is_multiplayer_authority()` in `_ready`.

---

### `scenes/ui/PlayerHUD.gd` (component, request-response)

**Analog:** `scenes/Game.gd` lines 72-143 (`_setup_player_hud`, `_update_player_hud`)

**Authority guard pattern** (Game.gd lines 126-130 — basis for HUD owner-only visibility):
```gdscript
# Game.gd _update_player_hud — finds local player by peer_id match
var local_id := multiplayer.get_unique_id()
var local_player: Node = null
for p in get_tree().get_nodes_in_group("players"):
    if p.peer_id == local_id:
        local_player = p
        break
```

**HUD label update pattern** (Game.gd lines 136-143):
```gdscript
_hud_hp_label.text = "HP  %d / %d" % [local_player.health, local_player.MAX_HP]
var cd: float = local_player._ability_cooldown
if cd <= 0.0:
    _hud_ability_label.text = "[SPACE]  BEREIT"
    _hud_ability_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
else:
    _hud_ability_label.text = "[SPACE]  CD: %.1fs" % cd
    _hud_ability_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
```

**PlayerHUD.gd core pattern** (copy from Game.gd authority guard, adapt for CanvasLayer child of Player):
```gdscript
extends CanvasLayer

func _ready() -> void:
    # D-18: Only show on owning peer's screen
    var player: Node = get_parent()
    visible = player.is_multiplayer_authority()

func update_hud(xp: int, level: int, xp_threshold: int, stage: int) -> void:
    $HUDRow/LevelLabel.text = "LVL %d" % level
    $HUDRow/XPBar.max_value = float(xp_threshold)
    $HUDRow/XPBar.value = float(xp)
    $HUDRow/StageLabel.text = "Stage %d" % stage
```

---

### `scenes/ui/CardOverlay.tscn` (component, event-driven)

**Analog:** `scenes/ui/GameOver.tscn` (full-screen Control + VBoxContainer pattern lines 1-33) and `scenes/ui/LobbyScreen.tscn` (multi-panel HBoxContainer lines 1-110)

**GameOver.tscn full-screen overlay pattern** (lines 4-10):
```tscn
[node name="GameOver" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
```

**LobbyScreen.tscn multi-panel HBoxContainer pattern** (lines 11-18):
```tscn
[node name="HBoxContainer" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 20.0
offset_top = 20.0
```

**CardOverlay.tscn target structure:**
```tscn
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scenes/ui/CardOverlay.gd" id="1_overlay"]

[node name="CardOverlay" type="CanvasLayer"]
script = ExtResource("1_overlay")
visible = false

[node name="Background" type="ColorRect" parent="."]
# Dim background — full-screen
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.0, 0.0, 0.0, 0.6)

[node name="OverlayContainer" type="VBoxContainer" parent="."]
# Centered in screen
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -300.0
offset_top = -150.0
offset_right = 300.0
offset_bottom = 150.0

[node name="TitleLabel" type="Label" parent="OverlayContainer"]
text = "Level Up! Choose a card:"
horizontal_alignment = 1

[node name="CardsRow" type="HBoxContainer" parent="OverlayContainer"]
alignment = 1

[node name="Card0" type="PanelContainer" parent="OverlayContainer/CardsRow"]
custom_minimum_size = Vector2(160, 200)

[node name="CardLabel0" type="Label" parent="OverlayContainer/CardsRow/Card0"]
autowrap_mode = 3

[node name="Card1" type="PanelContainer" parent="OverlayContainer/CardsRow"]
custom_minimum_size = Vector2(160, 200)

[node name="CardLabel1" type="Label" parent="OverlayContainer/CardsRow/Card1"]
autowrap_mode = 3

[node name="Card2" type="PanelContainer" parent="OverlayContainer/CardsRow"]
custom_minimum_size = Vector2(160, 200)

[node name="CardLabel2" type="Label" parent="OverlayContainer/CardsRow/Card2"]
autowrap_mode = 3

[node name="HintLabel" type="Label" parent="OverlayContainer"]
text = "A/D to select — Space/Enter to confirm"
horizontal_alignment = 1
```

---

### `scenes/ui/CardOverlay.gd` (component, event-driven)

**Analog:** `scenes/ui/LobbyScreen.gd` (keyboard navigation to buttons); input handled via `_unhandled_input` in Player.gd (see Player.gd `_check_revive` pattern as model for per-frame input polling)

**Input guard pattern** (Player.gd lines 83-89 — basis for `is_picking_card` input gate in Player._physics_process):
```gdscript
func _physics_process(delta: float) -> void:
    # P3: Only the authority peer reads input and moves
    if not is_multiplayer_authority():
        return
    # HLTH-04: Downed players cannot act
    if is_downed:
        velocity = Vector2.ZERO
        move_and_slide()
        return
    var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
```

**CardOverlay.gd core pattern** (new, keyboard-driven, called from Player.gd):
```gdscript
extends CanvasLayer

var _cards: Array[Dictionary] = []
var _selected: int = 0

func show_cards(cards: Array[Dictionary]) -> void:
    _cards = cards
    _selected = 0
    _refresh_display()
    visible = true

func hide_overlay() -> void:
    visible = false
    _cards = []

func navigate(direction: int) -> void:
    # direction: -1 = left (A), +1 = right (D)
    _selected = wrapi(_selected + direction, 0, _cards.size())
    _refresh_display()

func get_selected_index() -> int:
    return _selected

func _refresh_display() -> void:
    for i in range(3):
        var panel: Node = get_node_or_null("OverlayContainer/CardsRow/Card%d" % i)
        var label: Node = get_node_or_null("OverlayContainer/CardsRow/Card%d/CardLabel%d" % [i, i])
        if panel == null or label == null:
            continue
        if i < _cards.size():
            label.text = _card_text(_cards[i])
            panel.visible = true
        else:
            panel.visible = false
        # Highlight selected card — copy StyleBox override pattern from Game.gd lines 86-93
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.4, 0.8, 1.0, 0.9) if i == _selected else Color(0.15, 0.15, 0.15, 0.8)
        style.set_corner_radius_all(4)
        if panel.has_method("add_theme_stylebox_override"):
            panel.add_theme_stylebox_override("panel", style)

func _card_text(card: Dictionary) -> String:
    match card.get("type", ""):
        "weapon_unlock":  return "UNLOCK\n%s" % card.get("weapon_id", "")
        "weapon_upgrade": return "UPGRADE\n%s\nLv%d" % [card.get("weapon_id", ""), card.get("new_level", 2)]
        "element_upgrade": return "ELEMENT\nTier %d" % card.get("new_tier", 2)
        "stat_boost":     return "BOOST\n%s\n+10%%" % card.get("stat", "")
        _:                return "DAMAGE\nBOOST\n+5%%"
```

---

### `scenes/Player.gd` (controller, CRUD + event-driven) — MODIFY

**Analog:** `scenes/Player.gd` itself — patterns below show the exact insertion points.

**New var declarations pattern** (copy from existing var block lines 9-56, append after line 48):
```gdscript
# Existing vars (lines 36-48) — copy pattern for new vars:
var health: int = MAX_HP
var is_downed: bool = false
var evolution_stage: int = 1
var element: String = ""
var shield_active: bool = false
var dash_invincible: bool = false

# Phase 6 additions — same declaration style:
var xp: int = 0
var level: int = 1
var element_tier: int = 1
var is_picking_card: bool = false
var stage3_damage_mult: float = 1.0
```

**receive_damage — airbag migration + is_picking_card guard** (insert into existing function lines 412-436):
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func receive_damage(amount: int, attacker_path: String = "") -> void:
    if dash_invincible:
        return
    # Phase 6 D-07: Invulnerable while picking a card
    if is_picking_card:
        return
    # Phase 6 D-13 airbag migration: airbag_active → airbag_count > 0
    if health - amount <= 0 and has_node("WeaponManager") and $WeaponManager.airbag_count > 0:
        health = 1
        $WeaponManager.consume_airbag()
        return
    if shield_active:
        _last_attacker_path = attacker_path
        if evolution_stage >= 2:
            _request_reflect(amount, attacker_path)
        return
    health -= amount
    if health <= 0:
        health = 0
        _enter_downed()
```

**set_evolution_stage RPC body** (fills existing stub at lines 445-448):
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func set_evolution_stage(stage: int) -> void:
    evolution_stage = stage
    call_deferred("_swap_stage_visual", stage)
    if stage == 3:
        # D-22: Stage 3 stat boost — applied once on transition
        stage3_damage_mult = 1.2
        MAX_HP += 25
        health = mini(health + 25, MAX_HP)
```

**receive_xp RPC** (new, after set_evolution_stage — follows receive_heal pattern at lines 437-443):
```gdscript
## Phase 6: Receive XP from host after orb collection. Runs on owning peer only.
## Mirrors receive_heal RPC pattern exactly (lines 437-443).
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
    # Option C from RESEARCH open question 2: owning peer self-applies since receive_xp
    # is already host-authorized (host called rpc_id → peer). Mirrors receive_heal pattern.
    if level == STAGE2_LEVEL and evolution_stage < 2:
        set_evolution_stage(2)
    elif level == STAGE3_LEVEL and evolution_stage < 3:
        set_evolution_stage(3)
```

**_trigger_card_pick pattern** (new helper — follows _use_role_ability dispatch pattern lines 167-171):
```gdscript
func _trigger_card_pick() -> void:
    if not is_multiplayer_authority():
        return
    is_picking_card = true
    var pool: Array[Dictionary] = _build_card_pool()
    var cards: Array[Dictionary] = _draw_cards(pool)
    if has_node("CardOverlay"):
        $CardOverlay.show_cards(cards)
```

**_process LevelUpLabel pattern** (append to existing _process at lines 71-80):
```gdscript
func _process(_delta: float) -> void:
    # ... existing lines 73-80 unchanged ...
    # Phase 6 D-10: LevelUpLabel driven by synced is_picking_card
    if has_node("LevelUpLabel"):
        $LevelUpLabel.visible = is_picking_card
        if is_picking_card:
            $LevelUpLabel.text = "%s is leveling up!" % role_label
```

**_physics_process card input gate** (append to existing _physics_process lines 81-99):
```gdscript
func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return
    if is_downed:
        velocity = Vector2.ZERO
        move_and_slide()
        return
    # Phase 6 D-07/D-08: Freeze movement and handle card nav input while picking
    if is_picking_card:
        velocity = Vector2.ZERO
        move_and_slide()
        return  # movement blocked; card input handled in _unhandled_input
    # ... rest of existing physics process unchanged ...
```

**_unhandled_input card navigation** (new — mirrors _tick_ability Space-input pattern lines 160-164):
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not is_multiplayer_authority():
        return
    if not is_picking_card:
        return
    if event.is_action_pressed("ui_left"):   # A key
        if has_node("CardOverlay"):
            $CardOverlay.navigate(-1)
    elif event.is_action_pressed("ui_right"): # D key
        if has_node("CardOverlay"):
            $CardOverlay.navigate(1)
    elif event.is_action_pressed("ui_accept"): # Space or Enter
        _confirm_card_pick()

func _confirm_card_pick() -> void:
    var selected_index: int = 0
    if has_node("CardOverlay"):
        selected_index = $CardOverlay.get_selected_index()
    var game := get_node_or_null("/root/Game")
    if game and game.has_method("confirm_card_pick"):
        if multiplayer.is_server():
            game.confirm_card_pick(peer_id, selected_index)
        else:
            game.confirm_card_pick.rpc_id(1, peer_id, selected_index)
```

**_swap_stage_visual pattern** (new — mirrors _show_shield_ring ColorRect management lines 305-324):
```gdscript
func _swap_stage_visual(stage: int) -> void:
    for s in [1, 2, 3]:
        var container := get_node_or_null("Stage%dContainer" % s)
        if container:
            container.visible = (s == stage)
    if has_node("PlayerHUD"):
        $PlayerHUD.update_hud(xp, level, _xp_threshold(level), stage)

func _update_xp_hud() -> void:
    if has_node("PlayerHUD") and is_multiplayer_authority():
        $PlayerHUD.update_hud(xp, level, _xp_threshold(level), evolution_stage)
```

**_tick_element element_tier scaling** (extend existing match block lines 228-248):
```gdscript
func _tick_element(delta: float) -> void:
    match element:
        "fire":
            # Phase 6: proc rate = 0.25 * element_tier. _fire_burst is 100% proc (force_burn);
            # element_tier affects how often auto-fire triggers via modified timer interval.
            _fire_burst_timer -= delta
            var fire_interval: float = 4.0 / float(element_tier)  # T1=4s, T2=2s, T3=1.33s
            if _fire_burst_timer <= 0.0:
                _fire_burst_timer = fire_interval
                _fire_burst()
        "ice":
            if velocity.length() < 10.0:
                return
            _ice_trail_timer -= delta
            if _ice_trail_timer <= 0.0:
                # Phase 6: proc rate = 0.25 * element_tier → shorter spawn interval
                _ice_trail_timer = 0.3 / float(element_tier)  # T1=0.3s, T2=0.15s, T3=0.1s
                var game := get_node_or_null("/root/Game")
                if game and game.has_method("request_ice_trail"):
                    if multiplayer.is_server():
                        game.request_ice_trail(global_position)
                    else:
                        game.request_ice_trail.rpc_id(1, global_position)
        # Phase 6: Earth element_tier handled by Game.gd _tick_earth_effects reading Player.element_tier
```

---

### `scenes/Player.tscn` (config) — MODIFY

**Analog:** `scenes/Player.tscn` itself — SceneReplicationConfig sub-resource and node list.

**Existing SceneReplicationConfig** (Player.tscn lines 10-29 — properties/0 through properties/5):
```tscn
[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_1"]
properties/0/path = NodePath(".:position")
properties/0/allow_spawn = true
properties/0/replication_mode = 2
properties/1/path = NodePath(".:health")
properties/1/allow_spawn = true
properties/1/replication_mode = 2
properties/2/path = NodePath(".:is_downed")
properties/2/allow_spawn = true
properties/2/replication_mode = 2
properties/3/path = NodePath(".:shield_active")
properties/3/allow_spawn = true
properties/3/replication_mode = 2
properties/4/path = NodePath(".:dash_invincible")
properties/4/allow_spawn = true
properties/4/replication_mode = 2
properties/5/path = NodePath(".:evolution_stage")
properties/5/allow_spawn = true
properties/5/replication_mode = 2
```

**Phase 6 additions** (append properties/6 through properties/10, `replication_mode = 2` = REPLICATION_MODE_ALWAYS):
```tscn
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

**Stage container child nodes** (append after existing WeaponManager node at line 79, mirrors Sprite ColorRect pattern lines 35-41):
```tscn
[node name="Stage1Container" type="Node2D" parent="."]
# Stage 1: Existing Sprite (ColorRect) shown, Stage1Container is empty wrapper
# visible = true (default Stage 1)

[node name="Stage2Container" type="Node2D" parent="."]
visible = false
# Children: 3-4 ColorRects in cross/T-shape (dark grey) — added at implementation time

[node name="Stage3Container" type="Node2D" parent="."]
visible = false
# Children: larger rect + border ColorRects (bright accent) — added at implementation time

[node name="LevelUpLabel" type="Label" parent="."]
offset_left = -60.0
offset_top = -65.0
offset_right = 60.0
offset_bottom = -50.0
horizontal_alignment = 1
text = ""
visible = false
```

**PlayerHUD and CardOverlay** (appended as CanvasLayer children — no unique_id required for new nodes):
```tscn
[ext_resource type="PackedScene" path="res://scenes/ui/PlayerHUD.tscn" id="3_player_hud"]
[ext_resource type="PackedScene" path="res://scenes/ui/CardOverlay.tscn" id="4_card_overlay"]

[node name="PlayerHUD" parent="." instance=ExtResource("3_player_hud")]
[node name="CardOverlay" parent="." instance=ExtResource("4_card_overlay")]
```

---

### `scenes/pickups/XpOrb.gd` (service, request-response) — MODIFY

**Analog:** `scenes/pickups/CarPartPickup.gd` lines 40-52 (`_request_collect` host-auth + RPC out to Game.gd)

**CarPartPickup _request_collect pattern** (lines 40-52 — exact template):
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func _request_collect(_pickup_name: String, collector_peer_id: int) -> void:
    # Runs on host only
    if not multiplayer.is_server():
        return
    if _collected:
        return  # W1: double-collect guard
    _collected = true
    var game := get_node_or_null("/root/Game")
    if game and game.has_method("weapon_unlocked"):
        game.weapon_unlocked.rpc(weapon_id, collector_peer_id)
    queue_free()
```

**XpOrb.gd Phase 6 modification** (extend existing `_request_collect` lines 24-33):
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func _request_collect(_orb_name: String) -> void:
    if not multiplayer.is_server():
        return
    if _collected:
        return  # Pitfall 5: double-collect guard
    _collected = true
    # Phase 6: Identify collector by RPC sender_id, grant XP to their Player node
    var collector_peer_id: int = multiplayer.get_remote_sender_id()
    if collector_peer_id != 0:
        for p in get_tree().get_nodes_in_group("players"):
            if p.peer_id == collector_peer_id:
                p.receive_xp.rpc_id(collector_peer_id, 5)  # D-01: 5 XP per orb
                break
    queue_free()
```

**Note on host-collecting edge case:** When host player collects an orb, `_request_collect` is called directly (not via RPC), so `get_remote_sender_id()` returns 0. Add fallback: check `multiplayer.get_unique_id()` against the body that triggered `_on_body_entered`. The existing `_on_body_entered` peer guard ensures only the touching peer triggers — for host, call `receive_xp(5)` directly (no rpc_id needed since host IS the authority).

---

### `scenes/weapons/WeaponManager.gd` (service, CRUD) — MODIFY

**Analog:** `scenes/weapons/WeaponManager.gd` itself — airbag var, add_weapon, consume_airbag, reset (lines 22, 85-102, 106-119, 171-176)

**airbag_active declaration** (line 22 — replace):
```gdscript
# BEFORE (line 22):
var airbag_active: bool = false

# AFTER (Phase 6 D-11, Level 3 dual-charge):
var airbag_count: int = 0
const MAX_AIRBAG_CHARGES: int = 2  # Level 3 dual-charge (D-11)
```

**add_weapon airbag special-case** (lines 89-93 — replace):
```gdscript
# BEFORE (lines 89-93):
if weapon_id == "airbag_shield" and unlocked_weapons.has(weapon_id):
    if not airbag_active:
        airbag_active = true
        return true
    return false

# AFTER:
if weapon_id == "airbag_shield" and unlocked_weapons.has(weapon_id):
    var lvl: int = weapon_level.get("airbag_shield", 1)
    var cap: int = MAX_AIRBAG_CHARGES if lvl >= 3 else 1
    if airbag_count < cap:
        airbag_count = mini(airbag_count + 1, cap)
        return true
    return false

# Also update the initial arm in add_weapon when first unlocking (line 99-100):
if weapon_id == "airbag_shield":
    airbag_count = 1  # was: airbag_active = true
```

**consume_airbag** (lines 171-176 — replace):
```gdscript
# BEFORE (lines 171-176):
func consume_airbag() -> void:
    airbag_active = false
    if has_node("AirbagShield"):
        get_node("AirbagShield").hide_ring()

# AFTER:
func consume_airbag() -> void:
    airbag_count = maxi(airbag_count - 1, 0)
    if airbag_count == 0:
        if has_node("AirbagShield"):
            get_node("AirbagShield").hide_ring()
```

**reset** (line 118 — replace airbag_active line):
```gdscript
# BEFORE (line 118):
airbag_active = false

# AFTER:
airbag_count = 0
```

**upgrade_weapon method** (new, called from Game.gd confirm_card_pick effect handler):
```gdscript
## Phase 6: Increment weapon level for a card pick (D-11).
## Called on the owning peer by host confirm_card_pick effect RPC.
func upgrade_weapon(weapon_id: String) -> void:
    if not unlocked_weapons.has(weapon_id):
        return
    var current: int = weapon_level.get(weapon_id, 1)
    if current >= 3:
        return  # max level
    weapon_level[weapon_id] = current + 1
    # Level 3 ScrewsAndBolts: update timer interval
    if weapon_id == "screws_and_bolts" and weapon_level[weapon_id] == 3:
        _screws_cooldown = 0.35  # D-11: cooldown 0.5s → 0.35s at Level 3
```

---

### `scenes/weapons/ExhaustFlames.gd` (service, event-driven) — MODIFY

**Analog:** `scenes/weapons/ExhaustFlames.gd` `_on_fire_timer` lines 61-81 — level read insertion immediately after authority/downed guards.

**Existing fire timer authority + downed guards** (lines 61-66 — keep unchanged):
```gdscript
func _on_fire_timer(weapon_manager: Node) -> void:
    var player: Node = weapon_manager.get_parent()
    if not player.is_multiplayer_authority():
        return
    if player.is_downed:
        return
```

**Phase 6 level scaling insertion** (insert after line 66, before line 67 nearest-enemy lookup):
```gdscript
    # Phase 6 D-11: Read weapon level and compute level-specific params
    var level: int = weapon_manager.weapon_level.get("exhaust_flames", 1)
    var half_angle: float = HALF_ANGLE                   # L1: ±30° (60° total)
    var radius: float = RADIUS                           # L1: 120px
    var damage: int = int(DAMAGE * player.stage3_damage_mult)  # D-22 Stage 3 mult
    if level >= 2:
        half_angle = deg_to_rad(45.0)                    # L2: 90° total
        radius = 160.0
    if level >= 3:
        half_angle = deg_to_rad(60.0)                    # L3: 120° total
    # L3 slow: applied inside hit loop below (enemy.velocity *= 0.5 for 1s via Timer)
```

**Stage 3 damage multiplier** (line 80 — replace `body.take_damage(DAMAGE)` with):
```gdscript
if abs(aim_dir.angle_to(to_enemy)) <= half_angle:
    body.take_damage(damage)  # uses level-computed damage (includes stage3_damage_mult)
    # L3: Brief slow — enemy velocity halved for 1s
    if level >= 3:
        body.velocity *= 0.5
        # Re-restore after 1s via SceneTree timer (mirrors HornShockwave pattern)
        get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(body): body.velocity *= 2.0)
```

---

### `scenes/weapons/SpinningTires.gd` (service, event-driven) — MODIFY

**Analog:** `scenes/weapons/SpinningTires.gd` `activate` (lines 18-49) and `_physics_process` (lines 51-77) — add 4th/5th orbit and speed scaling.

**Existing activate pattern** (lines 18-39 — range(3) becomes dynamic):
```gdscript
func activate() -> void:
    for i in range(3):  # Phase 6: becomes range(_tire_count(weapon_manager))
        var tire := Area2D.new()
        # ... existing setup unchanged ...
```

**Phase 6 _physics_process scaling** (insert level read at top of `_physics_process`, before `_angle += ORBIT_SPEED * delta`):
```gdscript
func _physics_process(delta: float) -> void:
    if not _active or _tires.is_empty():
        return
    # Phase 6 D-11: Read weapon level for speed and count scaling
    var weapon_manager: Node = get_parent()
    var level: int = weapon_manager.weapon_level.get("spinning_tires", 1)
    var speed_mult: float = 1.0
    if level >= 2:
        speed_mult = 1.25  # L2: +25% rotation speed
    var damage_per_tick: int = DAMAGE  # L1: 15
    if level >= 3:
        damage_per_tick = 18          # L3: 12→18 (DAMAGE base changed to 12 at L1)
    _angle += ORBIT_SPEED * speed_mult * delta
    var player: Node = get_parent().get_parent()
    if not is_instance_valid(player) or player.is_downed:
        return
    # Stage 3 multiplier on damage
    damage_per_tick = int(float(damage_per_tick) * player.stage3_damage_mult)
    # Orbit count: L1=3, L2=4, L3=5 — only active tires are updated
    var active_count: int = mini(_tires.size(), 3 + maxi(level - 1, 0))
    for i in range(active_count):
        var angle_offset: float = _angle + (float(i) * TAU / float(active_count))
        _tires[i].global_position = player.global_position + Vector2(
            cos(angle_offset), sin(angle_offset)
        ) * ORBIT_RADIUS
    # Host-only damage (unchanged pattern from line 66-77, use damage_per_tick)
```

**Note:** `activate()` must create 5 tires (max possible) and use `visible = false` for tires beyond current level. Alternatively, re-activate on upgrade. Simplest: create 5 in `activate()`, only orbit `active_count` of them.

---

### `scenes/weapons/AntennaBeam.gd` (service, event-driven) — MODIFY

**Analog:** `scenes/weapons/AntennaBeam.gd` `_on_fire_timer` lines 63-77 — level read insertion after authority/downed guards.

**Existing fire timer + _apply_damage dispatch** (lines 63-77 — keep structure, add level read):
```gdscript
func _on_fire_timer(weapon_manager: Node) -> void:
    var player: Node = weapon_manager.get_parent()
    if not player.is_multiplayer_authority():
        return
    if player.is_downed:
        return
    # Phase 6 D-11: Level scaling
    var level: int = weapon_manager.weapon_level.get("antenna_beam", 1)
    var dir: Vector2 = ...
    _show_visual.rpc(dir, player.global_position)
    if level >= 2:
        # L2: Fire twice, 0.2s apart
        if multiplayer.is_server():
            _apply_damage(player.global_position, dir)
        else:
            _apply_damage.rpc_id(1, player.global_position, dir)
        await get_tree().create_timer(0.2).timeout
        if not is_instance_valid(self):
            return
    if multiplayer.is_server():
        _apply_damage(player.global_position, dir, level)
    else:
        _apply_damage.rpc_id(1, player.global_position, dir, level)
```

**_apply_damage level scaling** (extend existing function lines 79-91):
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func _apply_damage(origin: Vector2, dir: Vector2, level: int = 1) -> void:
    if not multiplayer.is_server():
        return
    var player_node: Node = null  # needed for stage3_damage_mult
    # ... find player by origin proximity or pass peer_id in future refactor ...
    var base_dmg: int = DAMAGE       # L1/L2: 25
    if level >= 3:
        base_dmg = 30               # L3: 20→30 (D-11)
    var hit_radius: float = BEAM_WIDTH / 2.0 + 20.0
    if level >= 3:
        hit_radius *= 2.0           # L3: hitbox width doubles
    # Stage 3 mult: WeaponManager parent → Player
    var stage_mult: float = 1.0
    # (Pass stage3_damage_mult via extra param or look up from player group)
    for enemy in get_tree().get_nodes_in_group("enemies"):
        # ... existing dot-product check ...
        enemy.take_damage(int(float(base_dmg) * stage_mult))
```

**Simplest stage3_damage_mult lookup pattern** (mirrors WeaponManager → Player chain in ExhaustFlames line 62):
```gdscript
# Inside _apply_damage, find shooter player to get stage3_damage_mult:
# Not directly accessible in _apply_damage since it's host-only.
# Recommendation: pass requester_peer_id as additional parameter (add to RPC signature)
# and look up player node by peer_id — same as Game.gd attempt_revive lines 280-286.
```

---

### `scenes/weapons/HornShockwave.gd` (service, event-driven) — MODIFY

**Analog:** `scenes/weapons/HornShockwave.gd` `_on_fire_timer` lines 49-61 — level read insertion.

**Existing _on_fire_timer** (lines 49-61):
```gdscript
func _on_fire_timer(weapon_manager: Node) -> void:
    var player: Node = weapon_manager.get_parent()
    if not player.is_multiplayer_authority():
        return
    if player.is_downed:
        return
    _show_visual.rpc(player.global_position)
    if not multiplayer.is_server():
        return
    _area.global_position = player.global_position
    for body in _area.get_overlapping_bodies():
        if body.is_in_group("enemies"):
            body.take_damage(DAMAGE)
```

**Phase 6 D-11 level scaling insertion** (after line 52, before `_show_visual.rpc`):
```gdscript
    # Phase 6 D-11: Level scaling for Horn Shockwave
    var level: int = weapon_manager.weapon_level.get("horn_shockwave", 1)
    var radius: float = RADIUS          # L1: 150px
    var damage: int = int(DAMAGE * player.stage3_damage_mult)  # D-22
    var cooldown: float = COOLDOWN      # L1: 3.0s
    if level >= 2:
        radius = 220.0                  # L2: 150→220px
        cooldown = 2.5                  # L2: 3s→2.5s
        _timer.wait_time = cooldown
    if level >= 3:
        # L3: knockback range ×2 (applied below), brief stun (velocity = Vector2.ZERO for 0.5s)
        pass
    # Update area shape radius (must be done before get_overlapping_bodies)
    if _area and _area.get_child(0) is CollisionShape2D:
        var shape := _area.get_child(0).shape as CircleShape2D
        if shape:
            shape.radius = radius
```

**L3 stun in hit loop** (replace `body.take_damage(DAMAGE)` line 60):
```gdscript
    for body in _area.get_overlapping_bodies():
        if body.is_in_group("enemies"):
            body.take_damage(damage)
            # L2: knockback (existing pattern from Game.gd _tick_earth_effects line 483)
            if level >= 2:
                var knockback_dist: float = 300.0 if level < 3 else 600.0  # L3: ×2
                body.velocity += (body.global_position - player.global_position).normalized() * knockback_dist
            # L3: Brief stun — zero velocity for 0.5s
            if level >= 3 and is_instance_valid(body):
                body.velocity = Vector2.ZERO
                get_tree().create_timer(0.5).timeout.connect(func(): pass)  # stun expires naturally via enemy AI re-path
```

---

### `scenes/weapons/AirbagShield.gd` (service, event-driven) — MODIFY

**Analog:** `scenes/weapons/AirbagShield.gd` `hide_ring` / `show_ring` (lines 51-60) and Player.gd `receive_damage` airbag check (line 419).

**Level 2 airbag heal behavior** (Player.gd receive_damage airbag block — extend existing):
```gdscript
# Phase 6: Level 2 airbag heals to 25% HP instead of 1 HP (D-11)
if health - amount <= 0 and has_node("WeaponManager") and $WeaponManager.airbag_count > 0:
    var airbag_level: int = $WeaponManager.weapon_level.get("airbag_shield", 1)
    if airbag_level >= 2:
        health = maxi(1, MAX_HP / 4)  # heal to 25% HP
    else:
        health = 1                    # L1: survives at 1 HP
    $WeaponManager.consume_airbag()
    return
```

**AirbagShield.gd no structural changes needed** — hide_ring/show_ring API is unchanged. The `consume_airbag()` caller chain (Player.gd → WeaponManager.consume_airbag → AirbagShield.hide_ring) remains intact.

---

### `scenes/Game.gd` (controller, request-response) — MODIFY

**Analog:** `scenes/Game.gd` `weapon_unlocked` RPC lines 328-336 — exact template for `confirm_card_pick`.

**weapon_unlocked RPC template** (lines 328-336):
```gdscript
@rpc("authority", "call_remote", "reliable")
func weapon_unlocked(weapon_id: String, collector_peer_id: int) -> void:
    for p in get_tree().get_nodes_in_group("players"):
        if p.peer_id == collector_peer_id:
            if p.has_node("WeaponManager"):
                p.get_node("WeaponManager").add_weapon(weapon_id)
            return
```

**confirm_card_pick RPC** (new, follows attempt_revive `any_peer` + is_server() guard pattern lines 273-313):
```gdscript
## Phase 6: Client owning peer sends card pick index → host validates → applies effect.
## Uses "any_peer" + is_server() guard (not "authority") so any peer can send to host.
## Pattern from attempt_revive (lines 273-313): any_peer + is_server() guard + peer lookup.
@rpc("any_peer", "call_remote", "reliable")
func confirm_card_pick(requester_peer_id: int, card_index: int) -> void:
    if not multiplayer.is_server():
        return
    # Find the requesting player node
    var player_node: Node = null
    for p in get_tree().get_nodes_in_group("players"):
        if p.peer_id == requester_peer_id:
            player_node = p
            break
    if player_node == null:
        return
    if not player_node.is_picking_card:
        return  # race condition guard: player already picked
    # Rebuild card pool on host to validate index (uses synced weapon_level, element_tier)
    var pool: Array[Dictionary] = _build_card_pool_for_player(player_node)
    if card_index >= pool.size():
        card_index = 0  # fallback to first card
    var card: Dictionary = pool[card_index]
    _apply_card_effect(requester_peer_id, player_node, card)
    # Signal pick complete to owning peer
    _card_pick_complete.rpc_id(requester_peer_id)

@rpc("authority", "call_remote", "reliable")
func _card_pick_complete(target_peer_id: int) -> void:
    # Runs on the owning peer — clear picking state
    for p in get_tree().get_nodes_in_group("players"):
        if p.peer_id == target_peer_id:
            p.is_picking_card = false
            if p.has_node("CardOverlay"):
                p.get_node("CardOverlay").hide_overlay()
            return
```

**_apply_card_effect pattern** (new, mirrors weapon_unlocked handler structure):
```gdscript
func _apply_card_effect(peer_id: int, player_node: Node, card: Dictionary) -> void:
    match card.get("type", ""):
        "weapon_unlock":
            # Reuse existing weapon_unlocked RPC path (RESEARCH anti-pattern note)
            weapon_unlocked.rpc(card["weapon_id"], peer_id)
        "weapon_upgrade":
            # upgrade_weapon RPC to owning peer's WeaponManager
            var wm := player_node.get_node_or_null("WeaponManager")
            if wm:
                if peer_id == multiplayer.get_unique_id():
                    wm.upgrade_weapon(card["weapon_id"])
                else:
                    wm.upgrade_weapon.rpc_id(peer_id, card["weapon_id"])  # needs RPC on WM
        "element_upgrade":
            if peer_id == multiplayer.get_unique_id():
                player_node.element_tier += 1
            else:
                # element_tier is replicated; direct assignment on player node
                # Use receive_element_tier_up RPC on Player (same pattern as receive_heal)
                player_node.receive_element_tier_up.rpc_id(peer_id)
        "stat_boost":
            _apply_stat_boost(peer_id, player_node, card)
```

---

### `autoloads/GameState.gd` (service, CRUD) — MODIFY

**Analog:** `autoloads/GameState.gd` `_broadcast_game_over` lines 47-56 — append XP/level/evolution_stage resets inside the existing player loop.

**Existing _broadcast_game_over** (lines 47-56):
```gdscript
@rpc("authority", "call_local", "reliable")
func _broadcast_game_over() -> void:
    for p in get_tree().get_nodes_in_group("players"):
        if p.has_node("WeaponManager"):
            p.get_node("WeaponManager").reset()
    get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
```

**Phase 6 extension** (add inside the for-loop, before `get_tree().change_scene_to_file`):
```gdscript
@rpc("authority", "call_local", "reliable")
func _broadcast_game_over() -> void:
    for p in get_tree().get_nodes_in_group("players"):
        if p.has_node("WeaponManager"):
            p.get_node("WeaponManager").reset()
        # Phase 6 D-14, EVOL-06: Reset progression state for new run
        p.xp = 0
        p.level = 1
        p.element_tier = 1
        p.stage3_damage_mult = 1.0
        p.is_picking_card = false
        if p.has_method("set_evolution_stage"):
            p.set_evolution_stage(1)  # triggers _swap_stage_visual(1) via call_deferred
        if p.has_node("CardOverlay"):
            p.get_node("CardOverlay").hide_overlay()
        if p.has_node("PlayerHUD"):
            p.get_node("PlayerHUD").update_hud(0, 1, 100, 1)
    get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
```

---

## Shared Patterns

### RPC Authority — host → owning peer
**Source:** `scenes/Player.gd` lines 405-436 (`receive_damage`) and lines 437-443 (`receive_heal`)
**Apply to:** `receive_xp`, `receive_element_tier_up`, `_card_pick_complete`
```gdscript
# Canonical pattern: host calls rpc_id(peer_id, ...) on a function declared:
@rpc("any_peer", "call_remote", "reliable")
func receive_xp(amount: int) -> void:
    # "any_peer" because host (peer 1) is NOT the node's multiplayer_authority
    # "call_remote" so it only runs on the recipient, not the caller (host)
    if is_downed:
        return
    # ... mutate state ...
```

### is_server() Guard on Host-Only Functions
**Source:** `scenes/Game.gd` lines 231-235 (`request_fire`), `scenes/pickups/XpOrb.gd` lines 26-29
**Apply to:** `confirm_card_pick`, `_request_collect` extension, `_apply_card_effect`
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func confirm_card_pick(requester_peer_id: int, card_index: int) -> void:
    if not multiplayer.is_server():
        return
    # ... host-only logic ...
```

### call_deferred for Physics-Safe Node Operations
**Source:** `scenes/weapons/WeaponManager.gd` lines 126-148 (`_activate_weapon_node`)
**Apply to:** `_swap_stage_visual` call from `set_evolution_stage`, any node add/remove during physics frame
```gdscript
# All node show/hide during state-change RPCs use call_deferred:
func set_evolution_stage(stage: int) -> void:
    evolution_stage = stage
    call_deferred("_swap_stage_visual", stage)
```

### Player Node Lookup by peer_id
**Source:** `scenes/Game.gd` lines 280-286 (`attempt_revive`), lines 239-250 (`request_fire`)
**Apply to:** `confirm_card_pick`, `_request_collect` XP grant loop, `_broadcast_game_over` extension
```gdscript
var player_node: Node = null
for p in get_tree().get_nodes_in_group("players"):
    if p.peer_id == requester_peer_id:
        player_node = p
        break
if player_node == null:
    return
```

### is_multiplayer_authority() Guard for Input and UI
**Source:** `scenes/Player.gd` lines 83-89 (`_physics_process`)
**Apply to:** `PlayerHUD._ready` visibility, `CardOverlay` navigation calls, all `_unhandled_input` in Player
```gdscript
if not is_multiplayer_authority():
    return
```

### StyleBoxFlat for Panel Highlight
**Source:** `scenes/Game.gd` lines 86-93 (`_setup_player_hud`)
**Apply to:** `CardOverlay._refresh_display` selected-card highlight
```gdscript
var style := StyleBoxFlat.new()
style.bg_color = Color(0.0, 0.0, 0.0, 0.65)
style.set_corner_radius_all(5)
style.content_margin_left = 10
panel.add_theme_stylebox_override("panel", style)
```

### ColorRect Ring Visual (hollow ring via two overlapping ColorRects)
**Source:** `scenes/weapons/AirbagShield.gd` lines 19-33
**Apply to:** Stage 2/3 visual containers if ring accents needed; LevelUpLabel flash visual
```gdscript
_ring = ColorRect.new()
_ring.color = Color(1.0, 1.0, 0.0, 0.85)
var outer_size: float = (RING_RADIUS + RING_THICKNESS) * 2.0
_ring.size = Vector2(outer_size, outer_size)
_ring.pivot_offset = Vector2(outer_size / 2.0, outer_size / 2.0)
_ring.position = Vector2(-outer_size / 2.0, -outer_size / 2.0)
_ring_inner = ColorRect.new()
_ring_inner.color = Color(0, 0, 0, 0)  # transparent cutout
var inner_size: float = RING_RADIUS * 2.0
_ring_inner.size = Vector2(inner_size, inner_size)
_ring_inner.position = Vector2(RING_THICKNESS, RING_THICKNESS)
_ring.add_child(_ring_inner)
```

### Expanding Ring Tween Visual
**Source:** `scenes/weapons/HornShockwave.gd` lines 63-81 (`_show_visual`)
**Apply to:** Stage 2 evolution transition flash, Stage 3 evolution flash
```gdscript
var ring := ColorRect.new()
ring.color = Color(1.0, 0.9, 0.0, 0.8)
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

---

## No Analog Found

All files have close matches. No files require falling back to RESEARCH.md patterns alone.

---

## Metadata

**Analog search scope:** `scenes/`, `scenes/ui/`, `scenes/weapons/`, `scenes/pickups/`, `autoloads/`
**Files scanned:** 15 source files read directly
**Pattern extraction date:** 2026-06-18
