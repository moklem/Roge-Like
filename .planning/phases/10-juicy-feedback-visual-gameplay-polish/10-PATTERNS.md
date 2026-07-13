# Phase 10: Juicy Feedback — Visual & Gameplay Polish - Pattern Map

**Mapped:** 2026-07-13
**Files analyzed:** 22 (new + modified)
**Analogs found:** 22 / 22 (all resolved to strong in-codebase analogs; zero "no analog" files this phase)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `autoloads/Juice.gd` (NEW) | service/utility (juice facade) | event-driven, local | `autoloads/Sfx.gd` (pool + `_play` facade) | role-match |
| `autoloads/Settings.gd` (NEW) | service/store (client-only settings) | request-response (get/set) | `autoloads/GameState.gd` (autoload holding local/shared mutable state) | role-match |
| `scenes/vfx/DamageNumber.gd`/`.tscn` (NEW) | component (transient world-space VFX) | transform/event-driven | `Player._spawn_heal_particles()` (Player.gd:299-316) | role-match (particle-builder pattern, same "one-shot, self-frees" idiom) |
| `scenes/vfx/HitFlash.gd` (NEW) | utility (tween helper) | transform | `Player._on_driver_mode`/tween usage in `Game._show_dash_shockwave` (Player.gd:686-704) | role-match |
| `scenes/vfx/ImpactBurst.gd` (NEW) | utility (parametrized particle factory) | transform | `Player._spawn_driver_particles()` (Player.gd:372-379) | exact (same CPUParticles2D one-shot factory shape, just parametrized) |
| `scenes/enemies/Enemy.gd` (MODIFIED) | model/controller (host-authoritative AI) | CRUD (state diff-watch) | itself — extend existing `_process`/`_last_hp_seen` idiom | exact |
| `scenes/enemies/Enemy.tscn` (MODIFIED) | config (SceneReplicationConfig) | CRUD (replication) | itself — existing 3-property `SceneReplicationConfig` block | exact |
| `scenes/Player.gd` (MODIFIED) | model/controller | CRUD (state diff-watch) + request-response (RPC) | itself — extend existing `_process`/`_last_health_seen` idiom, `receive_damage`, `set_evolution_stage`, `_enter_downed`/`revive` | exact |
| `scenes/pickups/XpOrb.gd` (MODIFIED) | model (pickup) | event-driven (local cosmetic tween) | itself — `_process`-less Area2D gets a new local-only `_process` mirroring the diff-watch/tween style used elsewhere | role-match |
| `scenes/ui/PlayerHUD.gd` (MODIFIED) | component (CanvasLayer UI) | CRUD (display state) | itself — `update_hud()` display-decouple | exact |
| `scenes/Game.gd` (MODIFIED) | controller (host authority hub) | request-response (RPC) + event-driven | itself — `attempt_revive`/`_update_revive_bar` (widen to broadcast), `notify_significant_hit` (extend payload) | exact |
| `Game.tscn` (MODIFIED — add `FxLayer` Node2D) | config | file-I/O (scene tree) | `Game.gd`'s `add_child(ring)` pattern in `_show_dash_shockwave` (Player.gd:700, called against `/root/Game`) | role-match |
| `autoloads/GameEvents.gd` (MODIFIED — add `big_hit`) | service (signal bus / RPC broadcaster) | pub-sub (RPC broadcast) | itself — `emit_hud`/`emit_driver_mode` (GameEvents.gd:21-29) | exact |
| `autoloads/Sfx.gd` (MODIFIED — bus reassignment) | service (audio pool) | CRUD (config) | itself | exact |
| `autoloads/Music.gd` (MODIFIED — bus reassignment) | service (audio player) | CRUD (config) | itself | exact |
| `default_bus_layout.tres` (NEW) | config | file-I/O | none in-repo (first audio-bus resource) — build per Godot `AudioBusLayout` schema | no analog (see below) |
| `scenes/ui/CardOverlay.gd`/`.tscn` (MODIFIED) | component (CanvasLayer UI) | CRUD (display) + transform (pop-in) | `scenes/ui/PlayerHUD.gd` (`_apply_comic_style`, comic restyle pattern) | exact (style source), role-match (pop-in is greenfield) |
| `scenes/ui/MainMenu.gd`/`.tscn` (MODIFIED — Settings sub-panel) | component (Control UI) | request-response (button → panel) | `scenes/ui/MainMenu.gd` itself (`_on_host_pressed`/`_on_join_pressed` button-handler idiom) + `UiStyle.style_buttons`/`comic_box` | exact |
| `scenes/roles/HealDrone.gd` (MODIFIED — deploy pop-in) | model/controller (ability entity) | event-driven | `Player._spawn_heal_particles` / `_show_dash_shockwave` (deploy-time one-shot burst) | role-match |
| `scenes/enemies/EliteEnemy.gd`/`Boss.gd` (MODIFIED — spawn telegraph) | model/controller | event-driven (`_ready()` hook) | `Enemy._setup_enemy_sprite()` (Enemy.gd:63-86, runs identically on every peer in `_ready`) | role-match |

## Pattern Assignments

### `scenes/enemies/Enemy.gd` + `scenes/enemies/Enemy.tscn` (model, CRUD/replication) — ABIL-01 fix, DMG-01/04/06/07

**Analog:** itself (Enemy.gd:34-116, Enemy.tscn:13-22)

**Diff-watch idiom to extend** (`scenes/enemies/Enemy.gd:34-51,104-116`):
```gdscript
## Tracks last-seen hp so _process can fire a subtle hit cue when it drops (all peers).
var _last_hp_seen: int = 0
...
func _ready() -> void:
	current_hp = MAX_HP
	_last_hp_seen = current_hp
	set_physics_process(is_multiplayer_authority())
...
## WR-003: Health bar update runs on ALL peers so clients see synced current_hp.
func _process(_delta: float) -> void:
	if has_node("HealthBar"):
		$HealthBar.value = float(current_hp) / float(MAX_HP) * 100.0
	if current_hp < _last_hp_seen:
		Sfx.hit()
	_last_hp_seen = current_hp
```
Extend this exact `_process` block: add `Juice.spawn_damage_number(...)`, `Juice.flash(self)`, hp-ghost-chip, and death-burst hook alongside the existing `Sfx.hit()` call — same frame, same idiom, zero new RPC.

**Status-flag replication fix (ABIL-01)** — current gap, confirmed at `Enemy.tscn:13-22`:
```
[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_1"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 2
properties/1/path = NodePath(".:current_hp")
properties/1/spawn = true
properties/1/replication_mode = 2
properties/2/path = NodePath(".:state")
properties/2/spawn = true
properties/2/replication_mode = 2
```
Add `properties/3` (`is_burning`) and `properties/4` (`is_slowed`) with the same `spawn = true` / `replication_mode = 2` shape. Corresponding `Enemy.gd` fields already sketched in RESEARCH.md — the existing burn/slow logic (`Enemy.gd:162-192`) currently sets `modulate` directly inside host-only `_tick_status_effects`/`apply_burn`/`apply_slow`; move the *visual reaction* into `_process()` reading the new replicated bools, keep the DoT/speed math exactly where it is.

**Death-burst-before-`queue_free()`** (`Enemy.gd:150-160`):
```gdscript
func take_damage(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		died.emit(global_position)   # CMBT-08: emit position before freeing
		queue_free()
```
`died` signal is consumed by `Game.gd` (spawns XP orb) — hook the death-burst RPC into this same `died.emit` call site or into `_exit_tree()` (runs on every peer once the spawner-replicated `queue_free()` removes the node). Never parent VFX as a child of `self` here — parent to the new `FxLayer`.

---

### `scenes/Player.gd` (controller, CRUD diff-watch + RPC) — DMG-02/03/04, PROG-01/03, COOP-01/02/03/04, ABIL-02/03/04

**Analog:** itself (Player.gd:236-263, 655-780, 969-996)

**Health diff-watch to extend** (`Player.gd:236-263`):
```gdscript
var _last_health_seen: int = -1

func _process(_delta: float) -> void:
	if _uses_char_sprite:
		_update_char_visual(_delta)
	else:
		if is_downed:
			$Sprite.modulate = Color(0.4, 0.4, 0.4)   # grayscale tint — extend for D-18 90° tip
		else:
			$Sprite.modulate = Color.WHITE
	if has_node("HealthBar"):
		$HealthBar.value = float(health) / float(MAX_HP) * 100.0
	if _last_health_seen >= 0 and health > _last_health_seen:
		_spawn_heal_particles()
	_last_health_seen = health
```
Add a `health < _last_health_seen` branch here for hit-flash (red/white, D-02), HP-bar ghost-chip (D-07), and local-only screen shake gated `is_multiplayer_authority()`. `is_downed` branch is the D-18 collapse hook (already runs on ALL peers per the comment). `shield_active`/`dash_invincible` diffs (declared `Player.gd:47-48`) are the ABIL-04/ABIL-02 hook points — same idiom, new `_last_*_seen` vars.

**Particle-builder pattern to copy for new `ImpactBurst.gd`/heal sparkle extensions** (`Player.gd:299-316`):
```gdscript
func _spawn_heal_particles() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.7
	p.explosiveness = 0.9
	p.direction = Vector2.UP
	p.spread = 40.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0.0, -30.0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.color = Color(0.3, 1.0, 0.45, 0.9)
	p.z_index = 2
	p.emitting = true
	add_child(p)
	p.finished.connect(p.queue_free)
```
Continuous-ring variant for ability auras (`_spawn_driver_particles`, `Player.gd:372-379`, `EMISSION_SHAPE_SPHERE` + `spread = 180.0`) — this is the Tank-aura/ability-ring precedent (ABIL-04).

**RPC-broadcast + world-space ring precedent for evolution transform / death burst / spawn telegraph** (`Player.gd:686-704`):
```gdscript
@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_dash_shockwave(pos: Vector2) -> void:
	const RADIUS: float = 80.0
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	var ring := ColorRect.new()
	ring.color = Color(1.0, 1.0, 0.0, 0.8)
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
This is the exact template for: element hit VFX rings, evolution charge-up ring, revive-success ring, enemy spawn telegraph ring, drone-deploy ring. Swap `ColorRect`/tween curve for `CPUParticles2D` where a burst (not a ring) is wanted, per SYS-01.

**`set_evolution_stage` RPC — hook for PROG-03 charge-up/reveal** (`Player.gd:770-779`):
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func set_evolution_stage(stage: int) -> void:
	evolution_stage = stage
	call_deferred("_swap_stage_visual", stage)  # D-13: instant, deferred for physics safety
	if stage == 3:
		stage3_damage_mult = 1.2
		MAX_HP += 25
		health = mini(health + 25, MAX_HP)
```
Already fires on every peer (`call_remote` from the RPC dispatch context — confirmed to broadcast per RESEARCH.md). Insert the ~0.5s charge-up tween before `_swap_stage_visual`, then the element-colored burst (D-14) — element-colored per `element` field (`Player.gd:46`).

**`receive_damage` — COOP-05 big-hit trigger site** (`Player.gd:713-756`, specifically 738-753):
```gdscript
if from_elite:
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("notify_significant_hit"):
		if multiplayer.is_server():
			game.notify_significant_hit()
		else:
			game.notify_significant_hit.rpc_id(1)
```
D-16 reuses this exact site — thread `global_position` (or `self`) through into `notify_significant_hit()`'s param per RESEARCH.md Open Question 2.

**Downed/revive hooks** (`Player.gd:969-996`):
```gdscript
func _enter_downed() -> void:
	is_downed = true
	if GameState.has_method("track_downed"):
		GameState.track_downed(peer_id)

func revive() -> void:
	health = MAX_HP >> 1
	is_downed = false

@rpc("any_peer", "call_remote", "reliable")
func set_revive_progress(progress: float) -> void:
	if has_node("ReviveBar"):
		$ReviveBar.visible = progress > 0.0
		$ReviveBar.value = progress * 100.0
```
`set_revive_progress` currently only updates the local `ReviveBar` — widen the RPC annotation to `call_local` (see Game.gd pattern below) and add the D-18 world-space ring drawn on `self` here so every peer renders it, not just the owning client.

---

### `scenes/Game.gd` (controller, host-authority hub) — COOP-02 revive broadcast, COOP-05 big-hit

**Analog:** itself (Game.gd:884-965)

**Widen `set_revive_progress` from single-target to broadcast** — current call site (`Game.gd:958-965`):
```gdscript
func _update_revive_bar(target_id: int, progress: float) -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == target_id:
			p.set_revive_progress.rpc_id(target_id, progress)   # reaches ONLY target_id's client
			break
```
Change call to `p.set_revive_progress.rpc(progress)` (broadcast) and change the `Player.gd` RPC annotation from `@rpc("any_peer", "call_remote", "reliable")` to `@rpc("any_peer", "call_local", "reliable")` — mirrors `GameEvents.emit_hud`'s `authority + call_local` shape for "every peer must see this."

**`notify_significant_hit` — extend for big-hit position payload** (`Game.gd:944-956`):
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func notify_significant_hit() -> void:
	if not multiplayer.is_server():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_suspension_emit < SUSPENSION_DEBOUNCE:
		return
	_last_suspension_emit = now
	GameEvents.emit_hud.rpc("suspension")
```
Add a `Vector2 pos` param (defaulted) alongside the existing debounce logic, then call the new `GameEvents.emit_big_hit.rpc(pos)` right after (or instead of relying on) `emit_hud.rpc("suspension")`.

---

### `autoloads/GameEvents.gd` (service, pub-sub RPC broadcaster) — COOP-05

**Analog:** itself (GameEvents.gd:19-29)

```gdscript
@rpc("authority", "call_local", "reliable")
func emit_hud(event_name: String) -> void:
	hud_event.emit(event_name)

@rpc("authority", "call_local", "reliable")
func emit_driver_mode(mode: String, duration: float) -> void:
	driver_mode.emit(mode, duration)
```
Add, in the exact same shape:
```gdscript
signal big_hit(pos: Vector2)

@rpc("authority", "call_local", "reliable")
func emit_big_hit(pos: Vector2) -> void:
	big_hit.emit(pos)
```
`player_downed`/`player_revived` signals already declared (`GameEvents.gd:13-15`, `@warning_ignore("unused_signal")`) but unwired — COOP-01/02/03 wiring should follow this identical `authority + call_local` RPC-emit shape if a new broadcast site is needed beyond the `is_downed`/revive-ring diff-watch approach already covered above.

---

### `scenes/pickups/XpOrb.gd` (model, event-driven local cosmetic) — PICK-01/02

**Analog:** itself (XpOrb.gd:1-38) — real collection flow untouched, add local-only `_process`

```gdscript
extends Area2D
var _collected: bool = false

func _ready() -> void:
	add_to_group("xp_orbs")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("players"):
		return
	if body.peer_id != multiplayer.get_unique_id():
		return
	...
@rpc("any_peer", "call_remote", "reliable")
func _request_collect(_orb_name: String) -> void:
	if not multiplayer.is_server():
		return
	if _collected:
		return
	_collected = true
	...
	queue_free()
```
Add a new `_process(delta)` doing local ghost-clone magnetism/dart-to-bar (D-15) — purely cosmetic, does not touch `_request_collect`/`_collected`/`body_entered`. `PLAYER_SCRIPT.XP_PER_ORB` constant reference at top of file shows the project's cross-script const-access convention if the dart target (XP bar screen position) needs similar lookup.

---

### `scenes/ui/PlayerHUD.gd` (component, CRUD display) — PICK-02 bar decouple

**Analog:** itself (PlayerHUD.gd:35-53)

```gdscript
func update_hud(xp_value: int, level_value: int, xp_threshold: int, stage_value: int) -> void:
	var lvl := get_node_or_null("HUDPanel/HUDRow/LevelLabel")
	var bar := get_node_or_null("HUDPanel/HUDRow/XPBar")
	var stg := get_node_or_null("HUDPanel/HUDRow/StageLabel")
	if lvl:
		lvl.text = "TEAM LVL %d" % level_value
	if bar:
		bar.max_value = float(maxi(xp_threshold, 1))
		bar.value = float(xp_value)
	...
```
`bar.value = float(xp_value)` is the instant-set line to decouple — introduce a `_displayed_xp` field updated only on dart-arrival (tween `finished` callback from the new `XpOrb` dart), leaving `update_hud`'s signature/call sites (from `Player.gd`) unchanged.

---

### `autoloads/Sfx.gd` / `autoloads/Music.gd` (service, audio pool/player) — DMG-08/D-09, Pitfall 7

**Analog:** themselves (Sfx.gd:19-24, Music.gd:30-33)

```gdscript
# Sfx.gd _ready()
for _i in range(POOL_SIZE):
	var p := AudioStreamPlayer.new()
	p.bus = "Master"     # → change to "SFX"
	add_child(p)
	_players.append(p)
```
```gdscript
# Music.gd _ready()
_player = AudioStreamPlayer.new()
_player.bus = "Master"   # → change to "Music"
add_child(_player)
```
Both hard-code `"Master"` — confirmed no `default_bus_layout.tres` exists yet (Pitfall 7). New `Settings.gd` autoload's `set_music_volume`/`set_sfx_volume` (see RESEARCH.md Code Examples, already vetted) call `AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"/"SFX"), ...)` — bus creation must land before this bus reassignment or the sliders silently no-op.

---

### `scenes/ui/CardOverlay.gd`/`.tscn` (component, CRUD display + pop-in) — D-12, PROG-02

**Analog for comic restyle:** `scenes/ui/PlayerHUD.gd:14-28` (`_apply_comic_style`, the established comic-restyle recipe)
```gdscript
func _apply_comic_style() -> void:
	var panel: Panel = get_node_or_null("HUDPanel")
	if panel:
		panel.add_theme_stylebox_override("panel", UiStyle.comic_box(
			Color(UiStyle.PAPER.r, UiStyle.PAPER.g, UiStyle.PAPER.b, 0.95)))
	var f := UiStyle.button_font()
	for n in [...]:
		var lbl: Label = get_node_or_null(n)
		if lbl:
			if f:
				lbl.add_theme_font_override("font", f)
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.add_theme_color_override("font_color", UiStyle.INK)
	UiStyle.style_world_bar(get_node_or_null(...), Color(...))
```
`CardOverlay.gd` (read in full, `_refresh_display`/`show_cards`, lines 1-128) currently has ZERO `UiStyle` calls — call `_apply_comic_style()`-equivalent from `_ready()`, targeting `OverlayBackground`, `TitleLabel`, and each `Card%dBorder`/`Card%dTypeLabel`/`Card%dNameLabel`/`Card%dDescLabel` node path (paths confirmed at `CardOverlay.gd:56-61`).

**Pop-in tween:** no existing entrance-animation analog in this file; use the `_show_dash_shockwave` tween-chain shape (`Player.gd:701-704`, `create_tween()` + `tween_property` + `tween_callback`) applied to `scale`/`modulate:a` on `show_cards()` entry instead of `visible = true` being instant.

---

### `scenes/ui/MainMenu.gd`/`.tscn` (component, request-response UI) — D-08/D-09 Settings sub-panel

**Analog:** itself — existing button-handler idiom (`MainMenu.gd:15-44`, confirmed via grep: `_ready`, `_on_host_pressed`, `_on_join_pressed`) plus `UiStyle.style_buttons`/`comic_box` (`UiStyle.gd:69-90`, `153-161`).

```gdscript
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton

func _ready() -> void:
	...
func _on_host_pressed() -> void:
	...
func _on_join_pressed() -> void:
	...
```
Add `@onready var settings_button: Button = $VBoxContainer/SettingsButton` + `_on_settings_pressed()` toggling a new `SettingsPanel` Control child, styled via `UiStyle.style_buttons(panel)` / `UiStyle.comic_box(UiStyle.PAPER)` exactly as every other panel in this codebase. Shake-cycle button and two `HSlider`s inside the panel call into the new `Settings.gd` autoload (`set_shake_intensity()`, `set_music_volume()`, `set_sfx_volume()`).

## Shared Patterns

### Diff-watch reactive juice (Pattern A — the dominant pattern this phase)
**Source:** `scenes/enemies/Enemy.gd:34-51,104-116` and `scenes/Player.gd:236-263`
**Apply to:** Enemy.gd (hit-flash, damage numbers, death burst trigger, status tint), Player.gd (hit-flash, HP ghost-chip, downed collapse, shield/dash ability juice, heal sparkle already-existing)
```gdscript
var _last_X_seen: int = ...
func _process(_delta: float) -> void:
	if X < _last_X_seen:
		# fire local juice — every peer independently
		...
	_last_X_seen = X
```
Zero new RPCs — the field is already replicated via `MultiplayerSynchronizer`.

### RPC-broadcast + independent local execution (Pattern B)
**Source:** `autoloads/GameEvents.gd:21-29` (`emit_hud`/`emit_driver_mode`), `scenes/Player.gd:686-704` (`_show_dash_shockwave`)
**Apply to:** death burst, `emit_big_hit`, widened `set_revive_progress`, evolution transform (already an existing RPC), enemy spawn telegraph (via `_ready()`, no RPC needed since it already runs on every peer)
```gdscript
@rpc("authority", "call_local", "reliable")
func emit_X(payload) -> void:
	signal_name.emit(payload)
```
Never target dynamically-`randi()`-named `Enemy_%d`/`Bullet_%d` nodes directly with a new RPC — route through `Game.gd`/`GameEvents` or deterministically-named `Player_%d` nodes only (confirmed anti-pattern in RESEARCH.md).

### CPUParticles2D one-shot builder
**Source:** `scenes/Player.gd:299-316` (`_spawn_heal_particles`), `scenes/Player.gd:372-379` (`_spawn_driver_particles`, continuous ring variant)
**Apply to:** every new particle effect in `scenes/vfx/ImpactBurst.gd` — parametrize `color`, `amount`, `lifetime`, `direction`/`emission_shape`, keep the `one_shot = true` + `p.finished.connect(p.queue_free)` cleanup idiom (SYS-03 leak prevention). **`CPUParticles2D` only — never `GPUParticles2D`** (SYS-01, silently fails under `gl_compatibility`).

### Comic UI styling
**Source:** `scenes/ui/UiStyle.gd:62-161` (`INK`, `PAPER`, `style_buttons`, `style_world_bar`, `comic_box`), consumed identically at `scenes/ui/PlayerHUD.gd:14-28`
**Apply to:** CardOverlay restyle, Settings sub-panel, damage numbers (Bangers font source: `UiStyle.BUTTON_FONT_PATH`/`button_font()`, `UiStyle.gd:9,16-19`)

### Autoload registration
**Source:** `project.godot:17-23`
```
[autoload]
Lobby="*res://autoloads/Lobby.gd"
GameEvents="*res://autoloads/GameEvents.gd"
GameState="*res://autoloads/GameState.gd"
Sfx="*res://autoloads/Sfx.gd"
Music="*res://autoloads/Music.gd"
```
Add `Juice="*res://autoloads/Juice.gd"` and `Settings="*res://autoloads/Settings.gd"` as two new lines in this exact `"*res://autoloads/X.gd"` format.

### Never Engine.time_scale / SceneTree.paused
**Source:** RESEARCH.md Pitfall 1, confirmed no existing usage anywhere in the codebase (`Bullet.gd` has no `MultiplayerSynchronizer`, trusts identical per-peer deltas)
**Apply to:** `Juice.gd` hitstop implementation — local cosmetic float only, read exclusively by presentation code (camera shake decay, sprite flash tween, particle timestep), never by movement/AI/cooldown/RPC-dispatch code.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `default_bus_layout.tres` | config | file-I/O | No `AudioBusLayout` resource exists anywhere in this project yet (confirmed via filesystem search per RESEARCH.md). Planner should author this via the Godot editor's Audio panel (or hand-author the `.tres` per the standard `AudioBusLayout` resource schema) rather than copy an in-repo pattern — see RESEARCH.md Open Question 1 for the recommended fallback (`checkpoint:human-verify` if headless authoring proves unreliable). |

## Metadata

**Analog search scope:** `scenes/`, `autoloads/`, `scenes/ui/`, `scenes/enemies/`, `scenes/pickups/`, `project.godot`
**Files scanned:** `scenes/enemies/Enemy.gd`, `scenes/enemies/Enemy.tscn`, `scenes/Player.gd`, `scenes/Game.gd`, `autoloads/GameEvents.gd`, `autoloads/Sfx.gd`, `autoloads/Music.gd`, `scenes/pickups/XpOrb.gd`, `scenes/ui/PlayerHUD.gd`, `scenes/ui/UiStyle.gd`, `scenes/ui/CardOverlay.gd`, `scenes/ui/MainMenu.gd`, `project.godot`
**Pattern extraction date:** 2026-07-13
