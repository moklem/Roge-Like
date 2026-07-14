# Phase 11: Whole-Game Sound Design Pass & Soak-Test Validation - Pattern Map

**Mapped:** 2026-07-14
**Files analyzed:** 20 (from 11-CONTEXT.md canonical_refs + code_context)
**Analogs found:** 20 / 20 (18 are self-analogs — extend the file's own existing pattern; 2 are sibling-file analogs)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `autoloads/Sfx.gd` | service (audio pool) | event-driven | itself (`shoot()`/`hit()`, lines 43-49) | exact |
| `autoloads/Music.gd` | service (audio player) | event-driven | itself (`_play_single`/`_play_shuffle`, lines 57-99) | exact |
| `autoloads/GameEvents.gd` | event bus (pub-sub) | pub-sub | itself — **likely unmodified**, already has the 3 hook signals needed | exact |
| `scenes/weapons/WeaponManager.gd` | controller (fire loop) | event-driven | itself (`_fire_screws` → `Sfx.shoot()`, line 73) | exact |
| `scenes/weapons/ExhaustFlames.gd` | component (weapon) | event-driven (fire-timer) | `WeaponManager._fire_screws` shape + own `_on_fire_timer` (lines 61-107) | exact |
| `scenes/weapons/AntennaBeam.gd` | component (weapon) | event-driven (fire-timer) | same fire-timer shape (lines 63-92) | exact |
| `scenes/weapons/HornShockwave.gd` | component (weapon) | event-driven (fire-timer) | same fire-timer shape (lines 49-76) | exact |
| `scenes/weapons/SpinningTires.gd` | component (weapon) | continuous/onset-per-target | itself — existing `_hit_times` per-enemy cooldown gate (lines 84-93) already implements onset discipline | exact |
| `scenes/weapons/AirbagShield.gd` | component (passive charge) | event-driven (one-shot) | itself (`activate()`/`show_ring()`/`hide_ring()`, lines 14-60) | exact |
| `scenes/Player.gd` | controller (abilities/progression) | event-driven (multi-site) | itself — many independent trigger functions, each a one-shot call site | exact |
| `scenes/roles/HealDrone.gd` | component (deployable) | continuous/onset-per-pulse | itself (`_on_pulse`, lines 121-134; `_spawn_deploy_effect`, lines 140-157) | exact |
| `scenes/elements/IceTrailZone.gd` | component (zone) | event-driven (Area2D enter, already onset) | itself (`_on_enemy_entered`, lines 43-50) | exact |
| `scenes/Game.gd` | controller (orchestrator) | event-driven + continuous-tick | itself — `GameEvents.big_hit.connect(_on_big_hit)` (line 143) is the model for a central listener | exact |
| `scenes/pickups/XpOrb.gd` | component (pickup) | event-driven (arrival) | itself (`_spawn_collection_dart` tween-callback, lines 90-98) | exact |
| `scenes/ui/MainMenu.gd` | UI controller | request-response (button) | itself + `LobbyScreen.gd`/`GameOver.gd` (identical `button.pressed.connect` shape) | exact |
| `scenes/ui/LobbyScreen.gd` | UI controller | request-response (button) | `MainMenu.gd` (lines 40-46) | exact |
| `scenes/ui/CardOverlay.gd` | UI component | request-response (navigate/confirm) | itself (`navigate()`, lines 112-116; `show_cards`/`hide_overlay`, lines 71-111) | exact |
| `scenes/ui/GameOver.gd` | UI controller | request-response (button) | `MainMenu.gd` `_on_host_pressed`-style handler | exact |
| `scenes/enemies/Boss.gd` | controller (enemy AI) | event-driven (phase/attack/death) | itself (`_enter_phase`/`_notify_phase_change`, lines 92-112) | exact |
| `autoloads/GameState.gd` | service (run state) | event-driven (loop transition) | itself (`start_next_loop`, lines 109-118) | exact |

**Not in the given file list, but flagged as a probable missing file** — see "No Analog Found / Planner Flags" below: `scenes/enemies/Enemy.gd` (already has the `Sfx.hit()` call site and the death-burst hook that the "kill fanfare" priority cue almost certainly needs).

---

## Pattern Assignments

### 1. Core Audio Autoloads

#### `autoloads/Sfx.gd` (service, event-driven) — the backbone every other file's cue calls into

**Analog:** itself, full file (50 lines)

**Existing structure to extend, not replace** (lines 1-49):
```gdscript
extends Node
## Sfx — global sound-effect manager (autoload).
## Kept deliberately quiet — these are subtle feedback cues, not the focus of the mix.

const POOL_SIZE: int = 12

## Per-effect loudness (dB) — negative keeps the cues subtle.
const SHOOT_DB: float = -17.0
const HIT_DB: float = -13.0

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _shoot: AudioStream = null
var _hit: AudioStream = null

func _ready() -> void:
	for _i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_shoot = _try_load("res://assets/audio/sfx/shoot.wav")
	_hit = _try_load("res://assets/audio/sfx/hit.wav")

func _try_load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null

## Round-robin through the pool so rapid sounds overlap instead of truncating.
func _play(stream: AudioStream, volume_db: float, pitch_min: float, pitch_max: float) -> void:
	if stream == null or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.play()

func shoot() -> void:
	_play(_shoot, SHOOT_DB, 0.95, 1.08)

func hit() -> void:
	_play(_hit, HIT_DB, 0.92, 1.10)
```

**Extension pattern for every new cue (per-cue-per-file discipline — one `AudioStream` var + one public method, same as `_shoot`/`_hit`/`shoot()`/`hit()`):**
- Add one `const XXX_DB: float` per new cue (keep the "negative dB, subtle" discipline unless D-05/D-06 calls for a punchier car-part hit).
- Add one `var _xxx: AudioStream = null`, loaded via `_try_load()` in `_ready()` — never `preload`, so a not-yet-delivered team asset degrades to silence, not a parse error.
- Add one `func xxx() -> void: _play(_xxx, XXX_DB, pitch_min, pitch_max)` per cue — this is the exact shape every call site in every other file below will invoke.

**D-01–D-04 priority-voice extension (no existing analog in this codebase — new design, built from two existing idioms already in the project):**
1. **Pool-size bump:** raise `POOL_SIZE` from 12 toward ~18-20 (D-01, D-03 — exact number is discretion).
2. **Reserved subset:** split `_players` into two arrays (or keep one array + a reserved-count constant and two separate round-robin indices) — e.g. `_players` (shared/routine, round-robin via `_next`) and `_priority_players` (reserved, round-robin via `_priority_next`). Routine `_play()` (used by `shoot()`, `hit()`, and all non-priority cues) only ever indexes into `_players`. A new `_play_priority()` only ever indexes into `_priority_players`.
3. **Overflow steal-from-shared (D-04):** when `_play_priority()` is called and every voice in `_priority_players` is `playing == true`, don't drop the cue — instead reuse the exact "find the next slot whose busy-until has passed, else take the oldest" idiom already used by `Juice._damage_number_pool` (`autoloads/Juice.gd` lines 157-166 — reproduced below) but sourced from `_players` (the shared pool) instead of a fresh array. Concretely: scan `_players` for `not p.playing`; if none free, forcibly `.stop()`/re-purpose `_players[_next]` (the routine round-robin slot) and advance `_next` as normal — this is the "steal a voice from the shared pool" behavior D-04 asks for, expressed with data structures the file already has.

**Analog for the steal/reuse idiom** — `autoloads/Juice.gd` lines 157-166 (pool-slot reuse-when-free pattern, the closest existing "don't grow the pool, just reuse a slot" precedent in the codebase):
```gdscript
	for entry in _damage_number_pool:
		if now >= entry["busy_until"]:
			entry["target_id"] = target_id
			entry["amount"] = amount
			entry["aggregate_until"] = now + DAMAGE_NUMBER_AGGREGATE_WINDOW
			entry["busy_until"] = now + DAMAGE_NUMBER_LIFETIME
			entry["node"].global_position = pos
			entry["node"].show_number(amount, color)
			return
	# Pool exhausted — drop silently, never grow (SYS-02).
```
For `AudioStreamPlayer`, `entry["busy_until"]` isn't needed — `p.playing` (a built-in bool) already tells you if a voice is free, which is simpler than `Juice.gd`'s manual `busy_until` bookkeeping.

**Priority cue set (fixed, D-02 — use these exact 7 method names or equivalents):** kill fanfare, evolution transform, downed, revive, boss phase-change, boss death, big-hit/level-up (shared).

---

#### `autoloads/Music.gd` (service, event-driven) — extend with a 3rd mode for the 2 reactive moments

**Analog:** itself, full file (122 lines)

**Existing dual-mode structure** (lines 26-99, condensed):
```gdscript
var _player: AudioStreamPlayer = null
var _mode: String = ""            # "single" or "shuffle"
var _pool: Array[String] = []
var _current_path: String = ""
var _volume_db: float = -12.0

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)
	_player.finished.connect(_on_finished)

func play_menu() -> void:
	_play_single(LOBBY_TRACK, LOBBY_DB)

func play_ingame() -> void:
	_play_shuffle(INGAME_POOL, INGAME_DB, INGAME_FIRST)

func _play_single(path: String, volume_db: float) -> void:
	if _mode == "single" and _current_path == path and _player.playing:
		return  # no-op if already playing — avoids restart on re-enter
	...

func _play_shuffle(pool: Array[String], volume_db: float, first: String) -> void:
	if _mode == "shuffle" and _player.playing:
		return  # no-op if a shuffle is already running
	...

func _play_path(path: String, loop: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	...
	_player.stream = stream
	_player.volume_db = _volume_db
	_player.play()
```

**D-08/D-09 extension pattern (2 reactive moments layered on the ongoing shuffle, not replacing it):**
- A single shared `_player` can't play two streams at once — the two options that fit the existing single-`AudioStreamPlayer` architecture:
  1. **Second, dedicated `AudioStreamPlayer` for stings/swells** (mirrors how `Sfx.gd`'s pool is entirely separate `AudioStreamPlayer`s from `Music.gd`'s single one) — cleanest, avoids fighting `_mode`/`_pool` state, and the sting layers audibly over the shuffle since it's a second mixer voice. **Recommended given the existing 2-autoload/2-bus split (`Music` bus, `SFX` bus) already established in Phase 10 (`10-02-PLAN.md`) — a sting player can share the `Music` bus.**
  2. Alternative: duck `_player.volume_db` briefly via a `Tween` while a one-shot plays on a transient player, then restore — more complex, not clearly better for a ~1-1.5s swell.
- New methods should follow the existing public-method-per-moment shape: `func play_evolution_sting() -> void` and `func play_boss_death_sting() -> void`, each internally using `_try_load`-equivalent existence checks (`ResourceLoader.exists`) exactly like `_play_path` (lines 88-89) so a missing team asset is silent, never a crash.
- **Do not touch `_mode`/`_pool`/`_current_path`** — those drive the ongoing shuffle exclusively; the sting/swell path must be additive (D-08: "layered on top... not replacing it").

---

#### `autoloads/GameEvents.gd` (event bus, pub-sub) — likely unmodified; reference for hook points

**Analog:** itself, full file (49 lines) — no new signal is obviously required for Phase 11's SFX plumbing, since 3 of the 4 existing signals are already exactly the priority-cue hook points:

```gdscript
signal player_downed(player_id: int)     # → Sfx "downed" priority cue
signal player_revived(player_id: int)    # → Sfx "revive" priority cue
signal big_hit(pos: Vector2)             # → Sfx "big-hit" priority cue (shared w/ level-up per D-02)
signal hud_event(event_name: String)     # → candidate for UI-echo cues (D-06 CarHUD-matched elemental SFX)
```

**Central-listener pattern to reuse (from `scenes/Game.gd` line 143, the existing precedent for "one `.connect()` call fans out to a reaction"):**
```gdscript
GameEvents.big_hit.connect(_on_big_hit)
...
func _on_big_hit(pos: Vector2) -> void:
	Juice.spawn_burst(pos, Color(1.0, 1.0, 1.0, 1.0), 20, 0.5)
```
Sfx.gd (or Game.gd, mirroring this exact call site) can add `GameEvents.player_downed.connect(func(_id): Sfx.downed())`, `GameEvents.player_revived.connect(func(_id): Sfx.revive())`, `GameEvents.big_hit.connect(func(_pos): Sfx.big_hit())` in `_ready()` — a **single central hook** instead of scattering `Sfx.xxx()` calls at every `emit_player_downed`/`emit_player_revived`/`emit_big_hit` call site (there is only one call site each today, but this is the more future-proof shape and matches the `code_context` recommendation).

**Kill fanfare, evolution transform, boss phase-change, boss death do NOT have a GameEvents signal today** — these need direct `Sfx.xxx()` calls inserted at their existing trigger functions (see sections 4 and 7 below), per the `code_context` guidance: "no new signals required for most of these."

---

### 2. Weapons (`scenes/weapons/*.gd` + `WeaponManager.gd`)

**Shared shape across `ExhaustFlames.gd`, `AntennaBeam.gd`, `HornShockwave.gd`:** a `Timer` fires `_on_fire_timer(weapon_manager)`, which authority-guards (`player.is_multiplayer_authority()`), then does an RPC'd visual (`_show_visual.rpc(...)`, `call_local unreliable_ordered`) plus host-only damage. **The correct Sfx call site is right after `_show_visual.rpc(...)` inside `_on_fire_timer`** — that line already runs identically on every peer (it's the `call_local` RPC target), so a `Sfx.xxx()` call placed in the RPC'd `_show_visual` function itself (not in `_on_fire_timer`) gives every peer the fire sound in sync with the visual, with **zero new RPC**, exactly mirroring how `WeaponManager._fire_screws` calls `Sfx.shoot()` locally on the owning peer only (screws is not RPC'd because it's a self-only cue) vs. how these three weapons need the cue to be heard by teammates too since the visual already broadcasts.

**Analog — `scenes/weapons/WeaponManager.gd` lines 59-73 (`_fire_screws`, existing exact analog for the "cheapest" case — self-only, no RPC needed):**
```gdscript
func _fire_screws() -> void:
	var player: CharacterBody2D = get_parent()
	var targets: Array = _find_nearest_enemies(player, 3)
	if targets.is_empty():
		return
	...
	# Subtle shoot cue — _fire_screws only runs on the owning peer (tick() authority guard),
	# so each player hears their own default attack, once per volley.
	Sfx.shoot()
```

**Analog — `scenes/weapons/ExhaustFlames.gd` lines 109-120 (`_show_visual`, the call_local RPC target where a team-audible weapon-fire cue belongs):**
```gdscript
@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_visual(aim_dir: Vector2, pos: Vector2) -> void:
	if not is_instance_valid(_area):
		return
	_area.global_position = pos
	_area.rotation = aim_dir.angle()
	if _area.has_node("ExhaustVisual"):
		var vis: ColorRect = _area.get_node("ExhaustVisual")
		vis.visible = true
		...
```
Insert `Sfx.exhaust_flames()` (or similarly-named) at the top of this function body — same call_local RPC context as `AntennaBeam._show_visual` (lines 122-132) and `HornShockwave._show_visual` (lines 87-105).

#### `scenes/weapons/SpinningTires.gd` (continuous/onset-per-target, D-11 Claude's discretion → default onset)

**Analog:** itself, lines 81-93 — the `_hit_times` dictionary already gates damage to once per `HIT_COOLDOWN` (0.5s) per enemy:
```gdscript
	if not multiplayer.is_server():
		return
	var now: float = Time.get_unix_time_from_system()
	for i in range(active_count):
		for body in _tires[i].get_overlapping_bodies():
			if not body.is_in_group("enemies"):
				continue
			var key: String = str(body.get_path())
			var last_hit: float = _hit_times.get(key, -INF)
			if now - last_hit >= HIT_COOLDOWN:
				_hit_times[key] = now
				body.take_damage(damage_per_tick)
```
**Problem to flag for the planner:** this loop is `multiplayer.is_server()`-gated (host-only), so a naive `Sfx.xxx()` call here only plays on the host. Because Enemy's `_process` already reacts to `current_hp` diffs on **every** peer (`Sfx.hit()` at `Enemy.gd` line 193), the onset-only Spinning Tires cue is **already covered for free** by the existing diff-watch pattern if the tick just calls `body.take_damage(...)` — no new cue needed here at all, OR (Claude's discretion) add a distinct, quieter "tire scrape" cue that must then be routed the same way `ExhaustFlames`/`HornShockwave` route their fire cue (through a `call_local` RPC), since this loop itself is host-only.

#### `scenes/weapons/AirbagShield.gd` (one-shot, event-driven)

**Analog:** itself, lines 14-35 (`activate()`/`_flash_pickup()`) for the pickup/arm cue, and `WeaponManager.gd` lines 230-236 (`consume_airbag()`) for the "shield break/absorb" cue:
```gdscript
## Called by Player.gd receive_damage after airbag absorbs a lethal hit.
func consume_airbag() -> void:
	airbag_count = maxi(airbag_count - 1, 0)
	if airbag_count == 0:
		if has_node("AirbagShield"):
			get_node("AirbagShield").hide_ring()
```
Both `activate()` and `consume_airbag()` run on the owning peer only (no RPC) — same self-only-cue shape as `Sfx.shoot()`.

---

### 3. Roles (`scenes/roles/HealDrone.gd`)

**Analog:** itself. Deploy one-shot at `_spawn_deploy_effect()` (lines 140-157, called from `_ready()` — runs identically on every peer since drone spawn is spawner-replicated, no RPC needed):
```gdscript
func _spawn_deploy_effect() -> void:
	const DEPLOY_COLOR: Color = Color(0.2, 0.9, 0.3, 0.9)
	Juice.spawn_burst(global_position, DEPLOY_COLOR, 10, 0.5)
	...
```
Heal-pulse onset cue at `_on_pulse()` (lines 121-134, already fires once per `PULSE_INTERVAL` = 3s, authority-guarded, so it's already onset-not-continuous — matches SFX-02 precedent per `code_context`):
```gdscript
func _on_pulse() -> void:
	if not is_multiplayer_authority():
		return
	...
	for p in get_tree().get_nodes_in_group("players"):
		...
		if global_position.distance_to(p.global_position) <= radius:
			if p.peer_id == multiplayer.get_unique_id():
				p.receive_heal(heal)
			else:
				p.receive_heal.rpc_id(p.peer_id, heal)
```
Note: `_on_pulse` is host-only (drone authority stays on host per Pitfall 2) — a cue placed directly here only plays for the host. Since the pulse has no existing visual broadcast RPC either, this cue (if added) needs its own small `call_local` RPC, OR — cheaper — piggyback on the servo-hum idea (D-06) as a **looping** ambient sound tied to drone lifetime instead of per-pulse, sidestepping the host-only-tick problem entirely (Claude's discretion per D-06's "soft servo/massage-chair hum").

---

### 4. Elements (`scenes/elements/IceTrailZone.gd`)

**Analog:** itself, lines 43-50 — Area2D `body_entered` signal is inherently onset-only already (fires once per contact, not per-tick):
```gdscript
func _on_enemy_entered(body: Node) -> void:
	if not is_multiplayer_authority():
		return
	if body.is_in_group("enemies") and body.has_method("apply_slow"):
		body.apply_slow()
		body._slow_timer = SLOW_DURATION
```
Same host-only-authority caveat as `HealDrone._on_pulse` above — this is host-only (`is_multiplayer_authority()` guard, and the zone itself is host-spawned per the file's own doc comment). D-06's "AC-compressor hiss" cue matching HUD's "AC ❄️ COLD" is the target sound; since `_on_enemy_entered` has no existing RPC, either add a lightweight `call_local` visual+SFX RPC (mirroring `HornShockwave._show_visual`'s shape) or accept host-only audio for this specific minor cue (Claude's discretion — likely acceptable since it's a minor per-enemy environmental effect, not a priority cue).

---

### 5. Pickups (`scenes/pickups/XpOrb.gd`)

**Analog:** itself, lines 90-98 — the collection-dart tween's `tween_callback`, which already runs **locally on the collecting peer only** (the dart is spawned locally in `_on_body_entered`, gated to `body.peer_id == multiplayer.get_unique_id()` at line 56) — this is the exact "arrival" moment (`code_context`: "XP pickup arrival cue site"):
```gdscript
	tween.tween_callback(func() -> void:
		if is_instance_valid(hud):
			hud.arrive_xp()
		if is_instance_valid(dart):
			dart.queue_free()
	)
```
Insert `Sfx.xp_arrive()` alongside `hud.arrive_xp()` — no RPC needed (self-only cue, same shape as `Sfx.shoot()`).

---

### 6. UI/Menu (`MainMenu.gd`, `LobbyScreen.gd`, `CardOverlay.gd`, `GameOver.gd`)

**Shared shape across all four:** every button already does `button.pressed.connect(_on_x_pressed)`; the cue goes at the top of each `_on_x_pressed` handler. Per D-07 (Claude's discretion), use `Sfx.gd`'s own doc-comment tiebreaker ("deliberately quiet... subtle feedback cues, not the focus of the mix") → favor subtle blips over punchy comic-matched stingers, consistent with `SHOOT_DB`/`HIT_DB` both being negative/quiet.

**Analog — `scenes/ui/MainMenu.gd` lines 58-113 (representative handler shape, click + settings-pressed + slider-changed all the same idiom):**
```gdscript
func _on_host_pressed() -> void:
	Lobby.create_game()
	status_label.text = "Hosting on %s" % Lobby.get_local_ip()
	get_tree().change_scene_to_file("res://scenes/ui/LobbyScreen.tscn")

func _on_settings_pressed() -> void:
	settings_panel.visible = true
```
**Analog — `scenes/ui/LobbyScreen.gd` lines 74-93 (`_on_role_pressed`/`_on_ready_pressed` — same shape, plus the "locked/no-op" early-return that a UI-blip cue must NOT fire past):**
```gdscript
func _on_role_pressed(role: String) -> void:
	if _is_ready:
		return  # D-02: locked when ready — a click here should stay silent (no false-positive cue)
	...
	Lobby.set_player_role.rpc(role)
```
**Analog — `scenes/ui/CardOverlay.gd` lines 112-124 (`navigate()`/`get_selected_card()` — the card-pick UI's own state, confirm cue belongs where `Player._confirm_card_pick()` reads `get_selected_card()`, not inside `CardOverlay.gd` itself, since the overlay is purely local presentation and the actual confirm routes through `Player.gd` → `Game.confirm_card_pick`):**
```gdscript
func navigate(direction: int) -> void:
	if _cards.is_empty():
		return
	_selected = wrapi(_selected + direction, 0, _cards.size())
	_refresh_display()
```
**Analog — `scenes/ui/GameOver.gd` full file (19 lines) — smallest/simplest handler, good template for a single "return to menu" click cue:**
```gdscript
func _on_return_pressed() -> void:
	Lobby.remove_multiplayer_peer()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
```

---

### 7. Enemies / Boss (`scenes/enemies/Boss.gd`)

**Analog:** itself. Two of the three boss priority cues already sit on `call_local`/spawner-propagated hooks that fire identically on every peer with **zero new RPC**:

**Phase-change (SFX-only per D-09 — explicitly no music) — `Boss.gd` lines 92-112:**
```gdscript
func _enter_phase(new_phase: int) -> void:
	phase = new_phase
	_notify_phase_change.rpc(new_phase)
	...

@rpc("authority", "call_local", "reliable")
func _notify_phase_change(new_phase: int) -> void:
	_apply_phase_visual(new_phase)
```
Insert `Sfx.boss_phase_change()` inside `_notify_phase_change` (the `call_local` RPC body) — runs on every peer in sync with the color-flash visual.

**Boss death (SFX + music resolve per D-09) — `Boss.gd` lines 78-89 (`take_damage`, the death branch):**
```gdscript
func take_damage(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	current_hp = max(current_hp - amount, 0)
	...
	if current_hp <= 0:
		died.emit(global_position)
		queue_free()
```
`queue_free()` here is host-only, but propagates to every client via the `MultiplayerSpawner` (same as regular `Enemy.gd`), and **`_exit_tree()` then runs identically on every peer with zero RPC** — this is the correct hook for both the boss-death SFX and the `Music.gd` loop-end resolve, **not** `take_damage()` itself (which only runs on the host).

---

### 8. Enemies — flagged missing file (`scenes/enemies/Enemy.gd`, not in the given file list)

**This file is almost certainly required for the "kill fanfare" priority cue and was not named in `11-CONTEXT.md`'s canonical_refs.** It already contains exactly the hooks Phase 11 needs, and Boss.gd inherits `_exit_tree()` from it unmodified:

**`Enemy.gd` lines 293-309 (`_exit_tree`, the shared death hook — already distinguishes normal/elite/boss kills via the existing `has_method("_enter_phase")` boss-detection idiom, which is the natural place to fork "kill fanfare" (regular enemy) vs. "boss death" (Boss) cues):**
```gdscript
func _exit_tree() -> void:
	if current_hp > 0:
		return
	var death_color: Color = $Sprite.color if has_node("Sprite") else Color(0.8, 0.2, 0.2, 1)
	Juice.spawn_burst(global_position, death_color, 14, 0.6)
	var stop_dur: float = 0.12 if (is_elite or has_method("_enter_phase")) else 0.07
	Juice.hitstop(stop_dur)
```
Recommended: add a branch here — `if has_method("_enter_phase"): Sfx.boss_death()` (also fires `Music`'s loop-end resolve) `elif is_elite: Sfx.elite_kill()` (Claude's discretion, not one of the 7 fixed priority cues) `else: Sfx.kill_fanfare()` **only for kills that should be "fanfare"-worthy** — re-check with the checklist whether every regular kill gets the fanfare tier or only a subtler routine "enemy pop" (the 7-cue priority list names one generic "kill fanfare", which most likely maps to a special/notable kill, not literally every trash-mob death — flag this ambiguity for the checklist-writing step, not this pattern map).

**`Enemy.gd` line 193 (`_process`, existing `Sfx.hit()` call site — direct analog every other file's hit-reaction cue should mirror):**
```gdscript
	if current_hp < _last_hp_seen:
		Sfx.hit()
```

---

### 9. Game Loop & Transitions (`scenes/Game.gd`, `autoloads/GameState.gd`)

**Room/sub-room transition cues** — all four transition functions are already `@rpc("authority", "call_local", "reliable")`, i.e. already fire identically on every peer with no new RPC:
- `_transition_to_room()` (lines 236-296)
- `_transition_to_sub_room()` (lines 368-412)
- `_open_exit_passage()` (lines 477-490)
- `_run_start_countdown()` (lines 187-216, not RPC'd itself but called identically from every peer's own `_ready` path)

**Analog — `scenes/Game.gd` lines 477-490 (`_open_exit_passage`, simplest transition RPC — model for where a "passage opens" cue goes):**
```gdscript
@rpc("authority", "call_local", "reliable")
func _open_exit_passage() -> void:
	var tm: TileMap = get_node_or_null("Room%d/TileMap" % current_room)
	if tm == null:
		return
	...
	_exit_open = true
```

**Earth continuous-tick effects (D-12 sibling discipline for Fire/Ice; Earth's own onset-only precedent already exists here)** — `_tick_earth_effects()` lines 1304-1361: heal fires once per accumulated interval (already onset, not per-frame) and shockwave fires once per `sw_cooldown` — both already call a `.rpc()`'d visual (`_show_earth_shockwave.rpc(earth_pos)`, line 1344) that is the correct SFX hook site (same shape as the weapon `_show_visual` RPCs above):
```gdscript
@rpc("authority", "call_local", "unreliable_ordered")
func _show_earth_shockwave(pos: Vector2) -> void:
	const RADIUS: float = 120.0
	var ring := ColorRect.new()
	...
```

**Boss death / loop-end (`GameState.gd` lines 107-118, `start_next_loop`) — host-only, NOT the right hook for the team-audible music resolve:**
```gdscript
func start_next_loop() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	...
	if not multiplayer.is_server():
		return
	loop_number += 1
	revives_used = {}
	print("Loop %d started" % loop_number)
```
This only runs on host — the music resolve (D-09) must hook at `Enemy.gd`'s `_exit_tree()` boss branch (section 8 above) instead, since that's what actually propagates to every client.

---

## Shared Patterns

### Safe-load discipline (every new cue, no exceptions)
**Source:** `autoloads/Sfx.gd` lines 27-30
```gdscript
func _try_load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null
```
**Apply to:** every new `AudioStream`/music-track reference in `Sfx.gd` and `Music.gd`. Never `preload()` a team-sourced asset that may not exist yet — a missing file must degrade to silence, never a parse-time crash. `Music.gd._play_path` (lines 85-99) already applies the same `ResourceLoader.exists()` guard before `load()`.

### Onset-only discipline for continuous/repeating effects
**Source:** `scenes/weapons/SpinningTires.gd` lines 84-93 (`_hit_times` per-enemy cooldown), `scenes/roles/HealDrone.gd` `_on_pulse` (fires once per `PULSE_INTERVAL`, not per-frame), `scenes/elements/IceTrailZone.gd` `_on_enemy_entered` (Area2D enter signal, not a tick)
**Apply to:** Spinning Tires (D-11) and Ice Trail Zone (D-12) — both already structurally onset-only in the existing code (gated by a cooldown dict or an `_entered` signal, never a raw per-`_physics_process` call), so "onset-only" mostly means "call the cue exactly where the existing gate already lets code through," not "add a new gate."

### Host-authoritative, presentation-only wiring (no new gameplay state)
**Source:** every RPC in this codebase already separates authority (`multiplayer.is_server()` / `is_multiplayer_authority()`) from the `call_local` visual/RPC layer — e.g. `ExhaustFlames._on_fire_timer` (authority-guards damage) vs. `_show_visual` (`call_local`, cosmetic only). Sound must attach to the **already-existing `call_local`/spawner-propagated hook**, never to the authority-only branch, or it will only play for the host.

### Central GameEvents listener (for the 3 already-signaled priority cues)
**Source:** `scenes/Game.gd` line 143 `GameEvents.big_hit.connect(_on_big_hit)` — the existing precedent for "one connect call reacts to a broadcast signal." Apply the same shape for `player_downed`, `player_revived`, `big_hit` → `Sfx.downed()`/`Sfx.revive()`/`Sfx.big_hit()`.

### Priority-voice pool (new design — D-01–D-04, no existing analog; nearest precedent is `Juice.gd`'s damage-number pool-slot-reuse idiom)
**Source:** `autoloads/Juice.gd` lines 157-166 (slot-reuse-when-free) — see full excerpt in the `Sfx.gd` section above. `AudioStreamPlayer.playing` replaces `Juice.gd`'s manual `busy_until` bookkeeping since it's a built-in signal of "is this voice free."

---

## No Analog Found / Planner Flags

| Item | Reason |
|---|---|
| Priority-voice reservation + steal-from-shared scheme (D-01–D-04) | No existing pool in this codebase reserves a subset of voices by cue tier — this is new design; closest precedent (`Juice.gd`'s damage-number pool reuse) is cited above as the nearest available idiom, adapted using `AudioStreamPlayer.playing`. |
| `Music.gd` sting/swell 3rd mode (D-08/D-09) | No existing second concurrent music player exists; recommended approach (dedicated 2nd `AudioStreamPlayer` on the `Music` bus) is a natural extension of the existing `Sfx.gd`-pool-is-separate-from-`Music.gd`-player split, not a copy of an existing in-repo pattern. |
| `scenes/enemies/Enemy.gd` | **Not listed in `11-CONTEXT.md`'s file set, but flagged above (section 8) as the most likely real hook site for "kill fanfare."** Planner should confirm whether this file needs its own plan/task even though the orchestrator's file list omitted it — its `_exit_tree()` already contains the exact boss/elite/normal-kill fork needed. |
| HealDrone `_on_pulse` / IceTrailZone `_on_enemy_entered` host-only-tick caveat | Both are gated by `is_multiplayer_authority()` with no existing `call_local` visual RPC to piggyback a cue onto — planner must decide whether to add a lightweight RPC (like the weapon `_show_visual` pattern) or accept host-only audio for these two minor continuous-effect cues (flagged inline in sections 3 and 4 above). |

## Metadata

**Analog search scope:** `autoloads/` (Sfx.gd, Music.gd, GameEvents.gd, GameState.gd, Juice.gd), `scenes/weapons/` (all 6 files), `scenes/Player.gd`, `scenes/Game.gd`, `scenes/enemies/` (Enemy.gd, Boss.gd), `scenes/roles/HealDrone.gd`, `scenes/elements/IceTrailZone.gd`, `scenes/pickups/XpOrb.gd`, `scenes/ui/` (MainMenu.gd, LobbyScreen.gd, CardOverlay.gd, GameOver.gd)
**Files scanned:** 20 target files + `Juice.gd` (cross-cutting VFX-pool analog) + `CarHUD.gd` (GameEvents listener precedent, lines 31-38, 89-91)
**Pattern extraction date:** 2026-07-14
