extends CharacterBody2D
## Player movement controller — handles WASD input, wall collision, health, downed state, revive.
## P3: All input handling guarded by is_multiplayer_authority().
## P4: MultiplayerSynchronizer replicates position, health, is_downed at 20 Hz (interval = 0.05).
## D-17: health and is_downed synced via MultiplayerSynchronizer from owning peer.
## Pitfall 3: receive_damage is @rpc("any_peer") so host (any_peer) calls rpc_id(peer_id) —
##   owning peer decrements health, MultiplayerSynchronizer replicates outward.

var SPEED: float = 200.0
var MAX_HP: int = 100
const REVIVE_DURATION: float = 3.5   # D-13: 3-4 seconds
const REVIVE_PROXIMITY: float = 60.0 # pixels — must be within this range to revive

## Phase 5 Plan 02: Tank shield constants (D-08, D-09)
const TANK_SHIELD_S1: float = 3.0      # Stage-1 shield duration (seconds)
const TANK_SHIELD_S2: float = 6.0      # Stage-2 shield duration (seconds)
const TANK_SHIELD_COOLDOWN: float = 8.0 # cooldown after shield expires
const TANK_REFLECT_PCT: float = 0.5    # Stage-2: reflect 50% of blocked damage
const TANK_REFLECT_MIN: int = 5        # Stage-2: minimum reflection damage

## Phase 5 Plan 02: Speedster dash constants (D-11, D-12)
const DASH_DURATION: float = 0.4       # dash speed-burst and i-frame duration
const DASH_MULT: float = 3.0           # velocity multiplier during dash
const DASH_COOLDOWN: float = 4.0       # cooldown after dash
const DASH_WINDOW: float = 0.8         # double-dash availability window (Stage-2)
const DASH_SHOCK_RADIUS: float = 80.0  # shockwave Area2D radius (Stage-2 second dash)
const DASH_SHOCK_DAMAGE: int = 25      # shockwave damage to enemies

## Engineer drone constants
const ENGINEER_DRONE_COOLDOWN: float = 18.0  # drone lives 10s, 8s gap before re-deploy (+5s)

## Phase 6: XP/evolution tuning constants (D-01/D-02/D-03/D-04, planner-calculated)
const XP_PER_ORB: int = 15           # D-01 tuned: 5→15 to hit Stage 2 in ~8-12 min
const STAGE2_LEVEL: int = 5          # D-03: Proto-Bot at Level 5 (cumulative 700 XP)
const STAGE3_LEVEL: int = 10         # D-04: Full AutoBot at Level 10 (cumulative 2700 XP)

@export var peer_id: int = 0
@export var role_label: String = ""

## D-17: replicated via MultiplayerSynchronizer SceneReplicationConfig
var health: int = MAX_HP
var is_downed: bool = false

## MAP-07: mirrors the host's revive gate (GameState.revives_used — one revive per player per
## sub-room) so every peer, not just the host, knows whether a downed player can still be picked
## up. The shared camera needs that answer locally: a downed player who can still be revived
## holds the frame, one whose revive is spent does not. Replicated like health/is_downed —
## written on the owning peer inside revive(), reset by Game._reset_revive_limits().
var revive_used: bool = false

## Phase 5: Role/element/ability state
var evolution_stage: int = 1        # D-04: Phase 6 sets via RPC when XP threshold reached
var element: String = ""            # D-03: "fire" | "ice" | "earth" | ""
var shield_active: bool = false     # D-08/D-09: Tank shield active flag (replicated)
var dash_invincible: bool = false   # D-11: Speedster invincibility frames flag (replicated)
var _ability_cooldown: float = 0.0  # D-06: single ability cooldown timer
var _dash_window_timer: float = 0.0 # D-12: Speedster double-dash window
var _ice_trail_timer: float = 0.0   # D-18: Ice Trail spawn interval
var _fire_burst_timer: float = 0.0  # D-17: Fire Burst auto-fire interval

## Phase 6: XP/level/evolution progression state (D-05, D-17). Replicated via MultiplayerSynchronizer.
var xp: int = 0
var level: int = 1
var element_tier: int = 1
var is_picking_card: bool = false
## Local-only, deliberately NOT replicated: this peer has the ESC settings overlay open.
## Gates this peer's own input in _physics_process. Teammates neither see nor care — the
## character stays in the world and stays a valid target while the overlay is up.
var menu_open: bool = false
var stage3_damage_mult: float = 1.0
var _pending_card_picks: int = 0
## Set when the sub-room weapon choice arrives while a level-up pick is already open;
## drained in _trigger_pending_card_pick.
var _pending_weapon_choice: bool = false

## Weapons offered by the sub-room weapon-choice overlay (airbag_shield disabled as a weapon).
const WEAPON_CHOICE_IDS := ["exhaust_flames", "spinning_tires", "antenna_beam", "horn_shockwave"]

## Driver Mode (CarHUD): team-wide timed effect rolled per sub-room by the host and applied
## on every peer via GameEvents.driver_mode. Duration is host-rolled (3-5s) and arrives with
## the signal, then the effect auto-resets. driver_damage_mult is read by the weapon fire
## paths (like stage3_damage_mult); the speed mult only matters on the authority peer; the
## heal is applied on the authority peer only.
var driver_damage_mult: float = 1.0
var _driver_speed_mult: float = 1.0
var _driver_heal_rate: float = 0.0   # HP/sec while active (authority only)
var _driver_heal_accum: float = 0.0  # fractional-HP carry for integer heal ticks
var _driver_timer: float = 0.0
var _driver_particles: CPUParticles2D = null

## AUTOBONK character sprites (Tank / Engineer / Speedster use animated PNG art).
## Animation key per role; "" means no art → fall back to ColorRect placeholder.
var _sprite_key: String = ""

## Target on-screen height (px) of the drawn character per evolution stage.
## Same for every role — characters grow slightly with each stage.
const CHAR_TARGET_HEIGHT := {1: 56.0, 2: 62.0, 3: 68.0}
## stage → {"scale": Vector2, "offset": Vector2}, filled by _compute_char_fit()
var _char_fit: Dictionary = {}
var _uses_char_sprite: bool = false
var _last_anim_pos: Vector2 = Vector2.ZERO
var _move_timer: float = 0.0   # keeps "walk" anim alive between 20 Hz position syncs on remote peers

## Phase 5 Plan 02: Tank shield state
var _shield_timer: float = 0.0          # counts down active shield duration
var _shield_ring: ColorRect = null       # reusable outer ring node (created on first show)
var _last_attacker_path: String = ""     # attacker NodePath for Stage-2 reflection

## Phase 5 Plan 02: Speedster dash state
var _dash_timer: float = 0.0            # counts down i-frame duration after dash

func _ready() -> void:
	# Set authority based on peer_id — only the owning peer controls this player
	set_multiplayer_authority(peer_id)
	# Required for enemy group discovery and game-over check
	add_to_group("players")
	# Update role label display (MOVE-04)
	if has_node("RoleLabel"):
		$RoleLabel.text = role_label
	# Comic UI pass: comic font + ink outlines on the nameplate and world-space bars
	UiStyle.style_player_nameplate(self)
	# Phase 5: Apply role-specific stats and read element from Lobby
	_apply_role_stats()
	# Lobby stores the element capitalized ("Fire"/"Ice"/"Earth"); gameplay compares lowercase.
	# Normalize here so _tick_element, WeaponManager procs and the Earth aura actually match.
	element = Lobby.players.get(peer_id, {}).get("element", "").to_lower()
	# Phase 5: Initialise element/ability timers so they don't fire immediately
	_fire_burst_timer = 4.0
	## Phase 9 (D-01, MAP-07): Camera2D enabled only for the local authority player.
	## Non-authority peers keep the camera disabled — never sync camera position over network.
	_setup_camera()
	# AUTOBONK: swap ColorRect placeholder for animated character art when available
	_setup_char_sprite()
	_setup_draw_layers()
	# Driver Mode: react to the host's per-sub-room roll on every peer (this player's copy).
	GameEvents.driver_mode.connect(_on_driver_mode)

## Layering so weapon/item visuals never hide the character. WeaponManager sits AFTER the
## character in the scene tree, so its weapon nodes (orbiting tires, shield/airbag rings,
## flames, beams) would draw on top. Push the character above those (z=1) and keep the HP
## bar + labels on top of everything (z=2).
func _setup_draw_layers() -> void:
	for n in ["Sprite", "CharSprite", "Stage1Container", "Stage2Container", "Stage3Container"]:
		var node: CanvasItem = get_node_or_null(n)
		if node:
			node.z_index = 1
	for n in ["RoleLabel", "HealthBar", "ReviveBar"]:
		var node: CanvasItem = get_node_or_null(n)
		if node:
			node.z_index = 2

## AUTOBONK: Choose the character art set for this role and switch from the ColorRect
## placeholder to the AnimatedSprite2D. Runs on all peers (role_label is set before _ready
## by the spawner).
func _setup_char_sprite() -> void:
	match role_label:
		"Tank": _sprite_key = "tank"
		"Engineer": _sprite_key = "engineer"   # Healer art
		"Speedster": _sprite_key = "speedster"
		_: _sprite_key = ""
	_uses_char_sprite = _sprite_key != "" and has_node("CharSprite")
	if not _uses_char_sprite:
		return
	# Hide the placeholder rects — the animated sprite represents all evolution stages
	if has_node("Sprite"):
		$Sprite.visible = false
	for s in [1, 2, 3]:
		var c := get_node_or_null("Stage%dContainer" % s)
		if c:
			c.visible = false
	$CharSprite.visible = true
	# Size normalization: scale is derived per role AND stage from the opaque bounding box
	# of the idle art (see _compute_char_fit), so every character renders equally tall.
	_compute_char_fit()
	_last_anim_pos = global_position
	_update_char_visual(0.0)

## Visual size normalization — measure the opaque bounding box of each stage's idle art
## and derive scale + centering offset so the DRAWN character (not the padded canvas) is
## CHAR_TARGET_HEIGHT px tall for every role. The art canvases are uniform (256px) but the
## character fills 50–95% of them depending on role/stage, which made on-screen sizes
## wildly inconsistent (Tank even shrank from stage 1 → 2).
func _compute_char_fit() -> void:
	_char_fit.clear()
	var frames: SpriteFrames = $CharSprite.sprite_frames
	if frames == null:
		return
	for stage in [1, 2, 3]:
		var anim := "%s_%d_idle" % [_sprite_key, stage]
		if not frames.has_animation(anim) or frames.get_frame_count(anim) == 0:
			continue
		var tex: Texture2D = frames.get_frame_texture(anim, 0)
		if tex == null:
			continue
		var img: Image = tex.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		var used: Rect2i = img.get_used_rect()
		if used.size.y <= 0:
			continue
		var s: float = CHAR_TARGET_HEIGHT[stage] / float(used.size.y)
		var canvas_center := Vector2(img.get_width(), img.get_height()) * 0.5
		var used_center := Vector2(used.position) + Vector2(used.size) * 0.5
		_char_fit[stage] = {"scale": Vector2(s, s), "offset": canvas_center - used_center}

## Apply the measured fit for the current stage. Falls back to the old fixed scaling when
## the fit could not be measured (e.g. texture without retrievable image data).
func _apply_char_fit(stage: int, spr: AnimatedSprite2D) -> void:
	if not _char_fit.has(stage):
		spr.scale = Vector2(0.25, 0.25)
		return
	var fit: Dictionary = _char_fit[stage]
	spr.scale = fit["scale"]
	var off: Vector2 = fit["offset"]
	# flip_h mirrors the art inside its canvas, so the centering shift mirrors with it
	spr.offset = Vector2(-off.x if spr.flip_h else off.x, off.y)

# ──────────────────────────────────────────────────────────────────────────────
# MAP-07: shared co-op camera — one frame for the whole team, Mario-style.
#
# Every peer draws the same rect: the bounding box of the players that still matter. The player
# who runs ahead pushes the frame, the one at the back holds it, and nobody can leave it —
# _clamp_to_camera_leash() stops the leader at the edge instead of letting the team split. The
# camera is never networked; each peer derives it locally from the replicated positions.
# ──────────────────────────────────────────────────────────────────────────────

## Zoomed in far enough that the play area is SMALLER than every sub-room. Below ~1.63 the whole
## room fits on screen and the camera has nothing left to scroll — which is exactly what it did
## before this change.
const CAMERA_ZOOM: float = 1.6
## The CarHUD panel is opaque and covers the right 200 screen px, so that strip is not play area.
## Both the framing and the leash subtract it — otherwise the leading player gets walled at a
## boundary he cannot see, behind the dashboard.
const HUD_PANEL_WIDTH: float = 200.0
## Keeps the sprite and its nameplate clear of the screen edge when the leash bites.
const CAMERA_EDGE_MARGIN: float = 24.0

## Pixel bounds of the sub-room the camera may show — set by Game.gd on every (sub-)room
## transition, on every peer.
var _room_rect_px: Rect2 = Rect2()

func _setup_camera() -> void:
	if not has_node("Camera2D"):
		return
	var cam: Camera2D = $Camera2D
	cam.enabled = is_multiplayer_authority()
	cam.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	## The camera frames the GROUP, not this player, so it must not ride along with its parent.
	cam.top_level = true
	## Position is recomputed from the group's bounding box every frame. Smoothing would let the
	## frame lag behind the leash and draw players outside the box we just walled them into.
	cam.position_smoothing_enabled = false
	## Shift the view right by half the HUD width so the UNCOVERED part of the screen — the part
	## the player actually plays in — ends up centred on the group. Written once, not per frame:
	## Juice.gd caches this as the base offset it adds screen shake on top of (Juice.gd:47).
	cam.offset = Vector2(HUD_PANEL_WIDTH * 0.5 / CAMERA_ZOOM, 0.0)
	## Camera2D.limit_* is deliberately unused: it clamps the FULL view, so the camera would stop
	## while the room's right edge was still hidden behind the HUD panel. _shared_camera_center()
	## clamps the play area instead.
	cam.limit_left = -100000000
	cam.limit_top = -100000000
	cam.limit_right = 100000000
	cam.limit_bottom = 100000000

## World-space size of the part of the screen a player can actually see and use: viewport minus
## the HUD strip, divided by the zoom. (Stretch mode is canvas_items, so the viewport stays at its
## base size and the 200px HUD panel lives in that same coordinate space.)
func _play_area_size() -> Vector2:
	var view: Vector2 = get_viewport_rect().size / CAMERA_ZOOM
	return Vector2(view.x - HUD_PANEL_WIDTH / CAMERA_ZOOM, view.y)

## The players the camera must keep on screen: everyone still standing, plus downed players who
## can still be picked up. A downed player whose revive is already spent (D-22: one per sub-room)
## drops out of the frame, so the team may leave him behind instead of being locked to his body.
func _framing_players() -> Array:
	var framed: Array = []
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if p.is_downed and p.revive_used:
			continue
		framed.append(p)
	return framed

## Centre of the group's bounding box, pulled back so the play area never leaves the sub-room.
## A room smaller than the play area on an axis (the connector corridor is 5 tiles high) is
## centred on that axis instead of clamped, or it would stick to the top-left corner.
func _shared_camera_center(framed: Array) -> Vector2:
	var mn: Vector2 = framed[0].global_position
	var mx: Vector2 = mn
	for p in framed:
		mn.x = minf(mn.x, p.global_position.x)
		mn.y = minf(mn.y, p.global_position.y)
		mx.x = maxf(mx.x, p.global_position.x)
		mx.y = maxf(mx.y, p.global_position.y)
	var c: Vector2 = (mn + mx) * 0.5
	if _room_rect_px.size == Vector2.ZERO:
		return c   # no room bounds yet (first frame after spawn) — frame the group unclamped
	var half: Vector2 = _play_area_size() * 0.5
	for axis in [Vector2.AXIS_X, Vector2.AXIS_Y]:
		if _room_rect_px.size[axis] > half[axis] * 2.0:
			c[axis] = clampf(c[axis], _room_rect_px.position[axis] + half[axis], _room_rect_px.end[axis] - half[axis])
		else:
			c[axis] = _room_rect_px.position[axis] + _room_rect_px.size[axis] * 0.5
	return c

## Frame the group. Runs every physics frame on the authority peer — including the frames where
## this player is frozen (countdown, card pick) or downed, so the camera keeps following the team
## when he himself cannot move.
func _update_shared_camera() -> void:
	if not has_node("Camera2D"):
		return
	var cam: Camera2D = $Camera2D
	if not cam.enabled:
		return
	var framed: Array = _framing_players()
	if framed.is_empty():
		framed = [self]   # whole team down and spent: game over is already on its way
	cam.global_position = _shared_camera_center(framed)

## The Mario co-op rule: the team can never spread wider than the frame. Whoever runs ahead is
## stopped at the edge rather than dragging the camera off his team-mates — that is what forces
## the team to move together. Clamps the SPREAD, not the distance to the camera: clamping against
## the camera would let the leader creep forward at half speed, since the frame follows the
## midpoint and would keep sliding after him.
##
## Runs at the very end of the frame so it also catches the Speedster dash, which does its own
## move_and_slide() inside _tick_ability (_do_dash) and would otherwise burst through the edge.
func _clamp_to_camera_leash() -> void:
	var max_spread: Vector2 = _play_area_size() - Vector2(CAMERA_EDGE_MARGIN, CAMERA_EDGE_MARGIN) * 2.0
	var others_min: Vector2 = Vector2.INF
	var others_max: Vector2 = -Vector2.INF
	for p in _framing_players():
		if p == self:
			continue
		others_min.x = minf(others_min.x, p.global_position.x)
		others_min.y = minf(others_min.y, p.global_position.y)
		others_max.x = maxf(others_max.x, p.global_position.x)
		others_max.y = maxf(others_max.y, p.global_position.y)
	if is_inf(others_min.x):
		return   # solo run, or the only one the camera still frames — nothing to stay near
	global_position.x = clampf(global_position.x, others_max.x - max_spread.x, others_min.x + max_spread.x)
	global_position.y = clampf(global_position.y, others_max.y - max_spread.y, others_min.y + max_spread.y)

## Phase 9 (D-03, MAP-07): Called by Game.gd on every peer after each sub-room is built.
## sub_room_rect_px: Rect2 = Rect2(origin_x_px, origin_y_px, width_px, height_px)
func update_camera_limits(sub_room_rect_px: Rect2) -> void:
	_room_rect_px = sub_room_rect_px

## Tracks last-seen health so _process can fire a heal particle burst when it rises (all peers).
var _last_health_seen: int = -1

## DMG-04/D-07: Reddish ghost overlay child of $HealthBar, same treatment as Enemy.gd's
## _health_ghost (Plan 10-03) — spans old→new HP value and shrinks toward the new-value
## edge while fading to alpha 0 over ~0.4s. Created lazily on first damage frame.
var _health_ghost: ColorRect = null
var _health_ghost_tween: Tween = null

## Tracks previous is_picking_card value so _process can fire the level-up burst only on
## the false→true rising edge (PROG-01/D-13).
var _last_picking_card: bool = false

## DMG-02: guards the per-frame downed-tint/idle modulate reset below (both the
## _uses_char_sprite and non-char paths write modulate unconditionally every frame) so it
## does not fight the Juice.flash tween applied to the same node on a damage frame — without
## this, the flash color would be overwritten on the very next _process call.
var _hit_flash_active: bool = false

## PROG-03/D-14: guards the per-frame modulate reset (mirrors _hit_flash_active above) while
## the evolution charge-up/reveal tween owns `modulate` for its ~0.5s+ duration, so the
## per-frame idle/downed-tint write does not stomp the element-colored glow ramp.
var _evolution_transform_active: bool = false

## ABIL-02/D-20: Speedster dash afterimage trail — tracks the dash_invincible edge and
## throttles ghost spawn rate so a single 0.4s dash produces ~8 fading ghosts, not one
## per frame.
var _last_dash_invincible: bool = false
var _afterimage_timer: float = 0.0
## The dash stretch and whoosh need the dash DIRECTION, which lives only on the dashing
## peer (input is not replicated). Rather than sync a cosmetic field, every peer reads the
## direction off the position delta — during a 3x-speed dash that delta is unmistakable.
## It is zero on the frame the dash starts, so the pop fires on the first frame that has
## actually moved (one frame / ~16ms later, which is not perceptible) and only once.
var _dash_prev_pos: Vector2 = Vector2.ZERO
var _dash_popped: bool = false

## ABIL-04/D-20: Tank aura ring pulse — fires once on the shield_active false->true edge.
var _last_shield_active: bool = false

## COOP-01/COOP-03/D-18: tracks is_downed for the every-peer _process diff so the collapse
## (rising edge) and success burst + snap-back (falling edge) fire exactly once each.
var _last_downed: bool = false

## COOP-01/COOP-03/D-18: guards the per-frame downed-tint modulate reset (mirrors
## _hit_flash_active above) so the collapse desaturate-tween and the revive success
## snap-back tween own `modulate` for their duration without being stomped every frame.
var _downed_collapse_active: bool = false

## COOP-02/D-18: world-space revive-progress ring child (lazily created) + its current
## progress value, read by _draw_revive_ring via the CanvasItem `draw` signal idiom.
var _revive_ring: Node2D = null
var _revive_ring_progress: float = 0.0

func _process(_delta: float) -> void:
	# AUTOBONK: drive animated character art (walk/idle, flip, stage) on all peers
	if _uses_char_sprite:
		_update_char_visual(_delta)
	elif not _hit_flash_active and not _downed_collapse_active and not _evolution_transform_active:
		# D-12: downed visual tint runs on ALL peers from synced is_downed value
		if is_downed:
			$Sprite.modulate = Color(0.4, 0.4, 0.4)   # grayscale tint
		else:
			$Sprite.modulate = Color.WHITE
	# COOP-01/COOP-03/D-18: is_downed is replicated (D-17), so this diff fires on every peer
	# with zero new RPC — the collapse and success juice are inherently team-visible.
	if is_downed and not _last_downed:
		_play_downed_collapse()
	elif not is_downed and _last_downed:
		_play_revive_success()
	_last_downed = is_downed
	# HLTH-01: Update health bar from synced health value (all peers)
	if has_node("HealthBar"):
		$HealthBar.value = float(health) / float(MAX_HP) * 100.0
	# Heal cue: health is synced, so every peer sees the burst (drone pulse, Earth heal, revive).
	# Mirrors the Enemy.gd _last_hp_seen hit-cue pattern. -1 sentinel skips the first frame.
	if _last_health_seen >= 0 and health > _last_health_seen:
		_spawn_heal_particles()
	# DMG-02/DMG-03/DMG-04 (D-06, D-07, Pitfall 5): damage cue on every peer (hit-flash + HP
	# ghost-chip react to the already-replicated health value), but screen shake is gated to
	# the local authority peer's own Camera2D so a teammate's hit never shakes your screen.
	if _last_health_seen >= 0 and health < _last_health_seen:
		Juice.flash($CharSprite if _uses_char_sprite else $Sprite, Color(1.0, 0.3, 0.25, 1.0), 0.15)
		_hit_flash_active = true
		get_tree().create_timer(0.15).timeout.connect(func() -> void:
			_hit_flash_active = false
		)
		_update_health_ghost(_last_health_seen, health)
		if is_multiplayer_authority():
			# Shake and vignette both scale with how hard the hit landed, so an Elite/Boss
			# blow reads as heavier than a chip of contact damage without needing to know
			# who dealt it — the replicated health drop already carries that.
			var bite: float = clampf(float(_last_health_seen - health) / 30.0, 0.0, 1.0)
			Juice.add_trauma(lerpf(0.5, 0.95, bite))
			Juice.vignette_pulse(lerpf(0.55, 1.0, bite))
	_last_health_seen = health
	# The persistent low-HP tint is fed only by the owning peer, and only while it can still
	# act — once downed, the collapse desaturate owns the screen and this fades itself out.
	if is_multiplayer_authority() and not is_downed:
		Juice.set_low_hp_ratio(float(health) / float(MAX_HP))
	# Phase 6 D-10: LevelUpLabel driven by synced is_picking_card (visible on ALL peers)
	if has_node("LevelUpLabel"):
		$LevelUpLabel.visible = is_picking_card
		if is_picking_card:
			# TEAM XP: everyone levels together — label shows who is still choosing
			$LevelUpLabel.text = "%s is choosing..." % role_label
	# PROG-01/D-13: element-colored level-up burst on the is_picking_card rising edge.
	# is_picking_card is already replicated, so this fires on every peer with zero new RPC.
	if is_picking_card and not _last_picking_card:
		Juice.spawn_burst(global_position, Juice.element_color(element))
	_last_picking_card = is_picking_card
	# ABIL-02/D-20: Speedster dash afterimage trail — dash_invincible is already replicated,
	# so this fires in the every-peer _process with zero new RPC and shows on all screens.
	if dash_invincible:
		if not _last_dash_invincible:
			_dash_popped = false
			_afterimage_timer = 0.0
		# One-shot launch pop, as soon as the position delta gives us a usable direction.
		var moved: Vector2 = global_position - _dash_prev_pos
		if not _dash_popped and moved.length() > 1.0:
			_dash_popped = true
			var dir: Vector2 = moved.normalized()
			Juice.stretch($CharSprite if _uses_char_sprite else $Sprite, dir, 0.26, 0.32)
			_spawn_dash_whoosh(dir)
		_afterimage_timer -= _delta
		if _afterimage_timer <= 0.0:
			_afterimage_timer = 0.05  # ~8 ghosts over the 0.4s dash — a solid streak, not dots
			_spawn_dash_afterimage()
	_dash_prev_pos = global_position
	_last_dash_invincible = dash_invincible
	# ABIL-04/D-20: Tank aura ring pulse — shield_active is already replicated; fires only
	# on the rising edge (no RPC, no gameplay change).
	if shield_active and not _last_shield_active:
		_spawn_aura_pulse()
	_last_shield_active = shield_active
	# Driver Mode: count the active effect down on every peer so all mult copies reset in sync.
	_tick_driver_effect(_delta)

func _physics_process(delta: float) -> void:
	# P3: Only the authority peer reads input and moves
	if not is_multiplayer_authority():
		return
	# MAP-07: frame the team first — the camera has to keep tracking them through every early
	# return below (countdown, downed, card pick), or it freezes while the others fight on.
	_update_shared_camera()
	# Start countdown gate — no movement, weapons, or abilities until GO
	var game := get_node_or_null("/root/Game")
	if game != null and game.get("countdown_active") == true:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# HLTH-04: Downed players cannot act
	if is_downed:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# Phase 6 D-07: Freeze movement while picking a card (no time limit)
	if is_picking_card:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# ESC settings overlay is open on THIS peer only. The world deliberately keeps running —
	# a real pause would mean pausing the SceneTree, which desyncs every other peer — but this
	# peer's input is frozen, because WASD is bound to ui_left/right/up/down and without the
	# gate, dragging a slider with A/D would also walk the character.
	if menu_open:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED * _driver_speed_mult   # Driver Mode: ECO speeds up / SPORT slows
	move_and_slide()
	# D-08: Delegate all weapon firing to WeaponManager (ScrewsAndBolts + future weapons)
	if has_node("WeaponManager"):
		$WeaponManager.tick(delta)
	# Phase 5: Role ability cooldown + Space input dispatch
	_tick_ability(delta)
	# Phase 5: Passive element timers (Ice Trail, Fire Burst, Earth heal/shockwave)
	_tick_element(delta)
	# HLTH-05: Check revive input (R key) each frame
	_check_revive(delta)
	# MAP-07: last thing in the frame, after the dash's own move_and_slide — hold the leash.
	_clamp_to_camera_leash()

## ABIL-03/COOP-04/D-20: One-shot green sparkle rise at the player — self-frees when
## finished. Fired from the every-peer `_process` health-increase diff (never gated behind
## is_multiplayer_authority()), so every teammate sees the heal, satisfying COOP-04's
## team-visible healing per D-17.
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

## DMG-04/D-07: Positions the ghost overlay to span the just-lost HP segment (old_hp→new_hp)
## and tweens it to shrink toward the new-value edge while fading to alpha 0 over ~0.4s. The
## primary $HealthBar.value already snapped to the new percentage this same frame (above).
## Mirrors Enemy.gd's _update_health_ghost (Plan 10-03) so both bars read identically.
func _update_health_ghost(old_hp: int, new_hp: int) -> void:
	if not has_node("HealthBar"):
		return
	if _health_ghost == null:
		# Created lazily as a child of $HealthBar so its local coordinate space matches the
		# ProgressBar's 0..size.x == value 0..100 range.
		_health_ghost = ColorRect.new()
		_health_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_health_ghost.visible = false
		$HealthBar.add_child(_health_ghost)
	var bar: ProgressBar = $HealthBar
	var bar_size: Vector2 = bar.size
	var old_pct: float = clampf(float(old_hp) / float(MAX_HP), 0.0, 1.0)
	var new_pct: float = clampf(float(new_hp) / float(MAX_HP), 0.0, 1.0)
	var old_x: float = old_pct * bar_size.x
	var new_x: float = new_pct * bar_size.x
	if _health_ghost_tween != null and _health_ghost_tween.is_valid():
		_health_ghost_tween.kill()
	_health_ghost.color = Color(1.0, 0.3, 0.25, 0.85)
	_health_ghost.position = Vector2(new_x, 0.0)
	_health_ghost.size = Vector2(maxf(old_x - new_x, 0.0), bar_size.y)
	_health_ghost.visible = true
	_health_ghost_tween = create_tween()
	_health_ghost_tween.set_parallel(true)
	_health_ghost_tween.tween_property(_health_ghost, "size:x", 0.0, 0.4)
	_health_ghost_tween.tween_property(_health_ghost, "color:a", 0.0, 0.4)
	_health_ghost_tween.chain().tween_callback(func() -> void:
		_health_ghost.visible = false
	)

# ------------------------------------------------------------------------------
# Driver Mode — per-sub-room team-wide timed effect (CarHUD "Driver Mode: …")
# ------------------------------------------------------------------------------

## SPORT halves your speed, so its particles must read as braking, not as a buff — a bright
## colour here signals "power-up" and fights the mechanic. Anthracite tyre smoke instead,
## taken from the project's existing comic-ink family (UiStyle.INK = 0.08, 0.07, 0.10) and
## lifted so it reads as drifting smoke rather than a black blob on dark floors.
const DRIVER_BRAKE_SMOKE := Color(0.24, 0.23, 0.27, 0.85)

## GameEvents.driver_mode fires on ALL peers (host-rolled, call_local). Configures this
## player's copy: sets the active mult/heal, starts the timer, spawns matching sparkles.
## REPAIR reuses the existing green heal cue — the per-tick health gain triggers it on every
## peer automatically (see _process), so no extra particle emitter is needed for it.
##
## ECO buffs and SPORT punishes, not the other way round: the driver burning fuel must never be
## the move that makes the team stronger, or the game teaches the opposite of what it should.
func _on_driver_mode(mode: String, duration: float) -> void:
	_clear_driver_effect()  # cancel any lingering effect before applying the new one
	_driver_timer = duration
	match mode:
		"eco":
			_driver_speed_mult = 1.5
			_spawn_driver_particles(Color(0.45, 0.8, 1.0, 0.9))     # light blue
		"sport":
			_driver_speed_mult = 0.5                                # half speed (deutlich stärker)
			_spawn_driver_particles(DRIVER_BRAKE_SMOKE)             # anthracite tyre smoke — see const
		"repair":
			_driver_heal_rate = 5.0
			_spawn_driver_particles(Color(0.3, 1.0, 0.45, 0.95))    # green (like drone/earth heal)
		"overdrive":
			driver_damage_mult = 1.3
			_spawn_driver_particles(Color(0.7, 0.3, 1.0, 0.9))      # purple

## Runs on every peer from _process. Ticks the timer; applies heal-over-time on the authority
## peer only (health is authority-owned + synced). Resets all mults when the effect ends.
func _tick_driver_effect(delta: float) -> void:
	if _driver_timer <= 0.0:
		return
	_driver_timer -= delta
	if _driver_heal_rate > 0.0 and is_multiplayer_authority() and not is_downed:
		_driver_heal_accum += _driver_heal_rate * delta
		if _driver_heal_accum >= 1.0:
			var whole: int = int(_driver_heal_accum)
			_driver_heal_accum -= float(whole)
			health = mini(health + whole, MAX_HP)
	if _driver_timer <= 0.0:
		_clear_driver_effect()

## Reset all Driver Mode state to neutral and stop any active sparkle emitter.
func _clear_driver_effect() -> void:
	_driver_timer = 0.0
	_driver_speed_mult = 1.0
	driver_damage_mult = 1.0
	_driver_heal_rate = 0.0
	_driver_heal_accum = 0.0
	if is_instance_valid(_driver_particles):
		_driver_particles.emitting = false          # stop new sparkles; let live ones fade out
		_driver_particles.finished.connect(_driver_particles.queue_free)
	_driver_particles = null

## Continuous sparkle emitter around the player for the effect duration (all peers).
## Emits in a ring around the player so the effect reads clearly on screen.
func _spawn_driver_particles(color: Color) -> void:
	var p := CPUParticles2D.new()
	p.amount = 20
	p.lifetime = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 22.0
	p.spread = 180.0
	p.direction = Vector2.UP
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0.0, -35.0)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.5
	p.color = color
	p.z_index = 3
	p.emitting = true
	add_child(p)
	_driver_particles = p

## HLTH-05: Check if holding E near a downed teammate; send request to host each frame
func _check_revive(_delta: float) -> void:
	if not Input.is_action_pressed("revive"):
		# Hide revive bar if not pressing revive
		if has_node("ReviveBar"):
			$ReviveBar.visible = false
		return
	var nearby := _find_nearby_downed()
	if nearby == null:
		if has_node("ReviveBar"):
			$ReviveBar.visible = false
		return
	# Send attempt_revive to host (Game.gd accumulates progress per-frame).
	# attempt_revive is @rpc("call_remote") — rpc_id(1) is a no-op when the reviver
	# IS the host, so the host could never revive anyone. Call it directly on the
	# server, mirror the request_deploy_drone / _fire_burst pattern for clients.
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("attempt_revive"):
		if multiplayer.is_server():
			game.attempt_revive(peer_id, nearby.peer_id)
		else:
			game.attempt_revive.rpc_id(1, peer_id, nearby.peer_id)

## Find downed player within REVIVE_PROXIMITY range
func _find_nearby_downed() -> Node:
	for p in get_tree().get_nodes_in_group("players"):
		if p == self:
			continue
		if not p.is_downed:
			continue
		if global_position.distance_to(p.global_position) <= REVIVE_PROXIMITY:
			return p
	return null

## Phase 5: Apply role-specific stat overrides (D-05). Called from _ready() on all peers.
func _apply_role_stats() -> void:
	match role_label:
		"Tank":
			MAX_HP = 150
			health = 150   # D-07: Tank spawns with 150 HP (ROLE-01)
		"Speedster":
			SPEED = 280    # D-10: Speedster moves faster (ROLE-04)
		"Engineer":
			pass           # HP and SPEED stay at default 100 / 200 (D-05)

## Phase 5: Ability cooldown timer and Space key dispatch (D-06, Pattern 2).
## Runs only on the authority (owning) peer — guarded by _physics_process P3 check.
func _tick_ability(delta: float) -> void:
	if _ability_cooldown > 0.0:
		_ability_cooldown -= delta
	if _dash_window_timer > 0.0:
		_dash_window_timer -= delta
	# Tank shield countdown — expire when timer reaches zero
	if _shield_timer > 0.0:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			shield_active = false
			_hide_shield_ring()
	# Speedster dash i-frame countdown
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			dash_invincible = false
	if Input.is_action_just_pressed("role_ability"):
		if _ability_cooldown <= 0.0:
			_use_role_ability()
		elif role_label == "Speedster" and _dash_window_timer > 0.0:
			_use_second_dash()

## Phase 5: Stage gate dispatch — routes to Stage-1 or Stage-2 based on evolution_stage (D-20).
func _use_role_ability() -> void:
	if evolution_stage >= 2:
		_use_stage2_ability()
	else:
		_use_stage1_ability()

## Phase 5: Stage-1 abilities — Tank shield, Speedster dash, Engineer drone deploy (D-08, D-11, D-14).
func _use_stage1_ability() -> void:
	match role_label:
		"Tank":
			# D-08: 3-second full damage shield; cooldown starts after shield expires
			_activate_shield(TANK_SHIELD_S1)
			_ability_cooldown = TANK_SHIELD_S1 + TANK_SHIELD_COOLDOWN  # 11.0 s total
		"Speedster":
			# D-11: 0.3-second speed burst with invincibility frames; 4-second cooldown
			_do_dash()
			_ability_cooldown = DASH_COOLDOWN
		"Engineer":
			# D-14: Deploy Heal Drone — max 2 active, 12s cooldown
			var game := get_node_or_null("/root/Game")
			if game and game.has_method("request_deploy_drone"):
				if multiplayer.is_server():
					game.request_deploy_drone(peer_id)
				else:
					game.request_deploy_drone.rpc_id(1, peer_id)
			_ability_cooldown = ENGINEER_DRONE_COOLDOWN

## Phase 5: Stage-2 abilities — Tank Stage-2 shield + reflect, Speedster double-dash, Engineer Stage-2 drone (D-09, D-12, D-15).
func _use_stage2_ability() -> void:
	match role_label:
		"Tank":
			# D-09: 6-second shield + Stage-2 reflection; cooldown starts after shield expires
			_activate_shield(TANK_SHIELD_S2)
			_ability_cooldown = TANK_SHIELD_S2 + TANK_SHIELD_COOLDOWN  # 14.0 s total
		"Speedster":
			# D-12: First dash of double-dash sequence; opens second-dash window
			_do_dash()
			_dash_window_timer = DASH_WINDOW  # 0.8 s window for second dash
			_ability_cooldown = DASH_COOLDOWN  # reset if window lapses unused
		"Engineer":
			# D-15: Stage-2 drone follows Engineer — max 2 active, 12s cooldown
			var game := get_node_or_null("/root/Game")
			if game and game.has_method("request_deploy_drone"):
				if multiplayer.is_server():
					game.request_deploy_drone(peer_id)
				else:
					game.request_deploy_drone.rpc_id(1, peer_id)
			_ability_cooldown = ENGINEER_DRONE_COOLDOWN

## Phase 5: Speedster Stage-2 second-dash — triggers shockwave landing (D-12).
## Called when Space pressed during _dash_window_timer > 0.0.
func _use_second_dash() -> void:
	_do_dash()
	_spawn_dash_shockwave(global_position)
	_dash_window_timer = 0.0  # close the window — sequence complete

## Phase 5 Plan 04: Passive element timer tick — Fire Burst auto-fire + Ice Trail spawn request.
## Runs inside _physics_process which is already authority-guarded — only owning peer ticks.
## D-17 (ELEM-02): Fire Burst every 4s at nearest enemy with force_burn flag.
## D-18 (ELEM-04): Ice Trail zone requested every 0.3s while moving (velocity.length() >= 10).
func _tick_element(delta: float) -> void:
	match element:
		"fire":
			# Phase 6 D-19: Fire Burst proc rate scales with element_tier.
			# T1=4s interval, T2=2s, T3=1.33s (proc rate = 0.25 * element_tier)
			_fire_burst_timer -= delta
			var fire_interval: float = 4.0 / float(element_tier)
			if _fire_burst_timer <= 0.0:
				_fire_burst_timer = fire_interval
				_fire_burst()
		"ice":
			# D-18 (ELEM-04): Ice Trail — only while moving (velocity threshold)
			if velocity.length() < 10.0:
				return  # idle — no trail spawned
			_ice_trail_timer -= delta
			# Ice Trail drops an occasional frost patch instead of a continuous trail.
			# T1=3s, T2=1.5s, T3=1s between zones (scales with element_tier).
			var ice_interval: float = 3.0 / float(element_tier)
			if _ice_trail_timer <= 0.0:
				_ice_trail_timer = ice_interval
				var game := get_node_or_null("/root/Game")
				if game and game.has_method("request_ice_trail"):
					if multiplayer.is_server():
						game.request_ice_trail(global_position)
					else:
						game.request_ice_trail.rpc_id(1, global_position)
		# Phase 6 D-21: Earth element_tier is read by Game.gd _tick_earth_effects directly
		# from the Player node — no additional action needed here.

## D-17 (ELEM-02): Fire Burst — auto-fire 3-5 projectiles at nearest enemy with 100% burn proc.
## Modelled on WeaponManager._fire_screws() lines 51-69. Fires on the owning peer's authority;
## host spawns directly, client sends request_fire RPC. "fire_burst": true in dict so Plan 05
## _do_spawn_bullet extension can set force_burn on the spawned bullet.
func _fire_burst() -> void:
	var nearest := _find_nearest_enemy_global()
	if nearest == null:
		return
	var base_dir: Vector2 = (nearest.global_position - global_position).normalized()
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	var count: int = randi_range(3, 5)
	for i in range(count):
		var spread: Vector2 = base_dir.rotated(randf_range(-0.3, 0.3))
		if multiplayer.is_server():
			if game.has_node("BulletSpawner"):
				game.get_node("BulletSpawner").spawn({
					"pos": global_position,
					"dir": spread,
					"owner_id": peer_id,
					"fire_burst": true   # Plan 05 _do_spawn_bullet sets b.force_burn = true
				})
		else:
			if game.has_method("request_fire"):
				game.request_fire.rpc_id(1, global_position, spread, peer_id, true)
	# ELEM-07: HUD event — host-only (T-05-14 mitigation)
	if multiplayer.is_server():
		GameEvents.emit_hud.rpc("engine")

## Helper: find the nearest enemy node in group "enemies" using global_position.
## Cloned from WeaponManager._find_nearest_enemy but operates on self.global_position.
func _find_nearest_enemy_global() -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest

# ──────────────────────────────────────────────────────────────────────────────
# Plan 02 helpers — Tank shield
# ──────────────────────────────────────────────────────────────────────────────

## Activate the Tank damage shield for the given duration.
## Sets shield_active (replicated via MultiplayerSynchronizer) and shows the blue ring.
func _activate_shield(duration: float) -> void:
	shield_active = true
	_shield_timer = duration
	_show_shield_ring()
	Sfx.play("shield_up")

## Show (or create) the blue hollow-ring visual around the player.
## Mirrors AirbagShield.gd ring construction; blue instead of yellow.
func _show_shield_ring() -> void:
	const RING_RADIUS: float = 32.0
	const RING_THICKNESS: float = 5.0
	if _shield_ring == null:
		# Create once; reuse on subsequent activations
		_shield_ring = ColorRect.new()
		_shield_ring.name = "TankShieldRing"
		_shield_ring.color = Color(0.3, 0.6, 1.0, 0.85)  # blue (not yellow like AirbagShield)
		var outer_size: float = (RING_RADIUS + RING_THICKNESS) * 2.0
		_shield_ring.size = Vector2(outer_size, outer_size)
		_shield_ring.pivot_offset = Vector2(outer_size / 2.0, outer_size / 2.0)
		_shield_ring.position = Vector2(-outer_size / 2.0, -outer_size / 2.0)
		var ring_inner := ColorRect.new()
		ring_inner.name = "TankShieldRingInner"
		ring_inner.color = Color(0, 0, 0, 0)  # transparent cutout
		var inner_size: float = RING_RADIUS * 2.0
		ring_inner.size = Vector2(inner_size, inner_size)
		ring_inner.position = Vector2(RING_THICKNESS, RING_THICKNESS)
		_shield_ring.add_child(ring_inner)
		add_child(_shield_ring)
	_shield_ring.visible = true

## Hide the shield ring when the shield expires.
func _hide_shield_ring() -> void:
	if _shield_ring and is_instance_valid(_shield_ring):
		_shield_ring.visible = false

## ABIL-04/D-20: expanding soft ring pulse in the aura's established blue on the
## shield_active rising edge (mirrors _show_dash_shockwave's scale+fade tween shape).
## Parented to FxLayer (Juice._fx_layer), not to the player, so it survives the player
## despawning mid-tween; degrades to a no-op if FxLayer isn't present yet.
func _spawn_aura_pulse() -> void:
	var layer := Juice._fx_layer()
	if layer == null:
		return
	const RADIUS: float = 40.0
	var ring := ColorRect.new()
	ring.color = Color(0.3, 0.6, 1.0, 0.6)  # aura blue, softer than the solid shield ring
	ring.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	ring.pivot_offset = Vector2(RADIUS, RADIUS)
	ring.scale = Vector2(0.3, 0.3)
	layer.add_child(ring)
	ring.global_position = global_position - Vector2(RADIUS, RADIUS)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(1.6, 1.6), 0.4)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)

# ──────────────────────────────────────────────────────────────────────────────
# COOP-01/COOP-02/COOP-03/D-18 — Downed collapse, revive ring, revive success
# ──────────────────────────────────────────────────────────────────────────────

## COOP-01/D-18: tip 90 degrees (EASE_OUT) + desaturate toward grey + a dust puff on the
## is_downed rising edge. Runs from the every-peer _process diff (is_downed replicated —
## D-17), so the collapse is inherently team-visible with zero new RPC.
func _play_downed_collapse() -> void:
	_downed_collapse_active = true
	var target: CanvasItem = $CharSprite if _uses_char_sprite else $Sprite
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "rotation", deg_to_rad(90.0), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate", Color(0.55, 0.55, 0.55, 1.0), 0.3).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func() -> void:
		_downed_collapse_active = false
	)
	_spawn_downed_dust()

## COOP-01/D-18: one-shot brown/grey dust puff at the player's feet. Parented to FxLayer
## (Pitfall 3/4), never to self, so it survives even if this player node is freed mid-effect.
func _spawn_downed_dust() -> void:
	var layer := Juice._fx_layer()
	if layer == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.direction = Vector2.UP
	p.spread = 90.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 40.0
	p.gravity = Vector2(0.0, 40.0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.color = Color(0.45, 0.38, 0.28, 0.85)  # brown/grey dust puff (UI-SPEC)
	p.z_index = 1
	p.emitting = true
	layer.add_child(p)
	p.global_position = global_position + Vector2(0.0, 10.0)  # feet offset
	p.finished.connect(p.queue_free)

## COOP-03/D-18: green sparkle burst + white ring flash + rotation/modulate snap-back on the
## is_downed falling edge (successful revive). Runs from the every-peer _process diff
## (is_downed replicated), so the success feedback is team-visible with zero new RPC.
func _play_revive_success() -> void:
	Juice.spawn_burst(global_position, Color(0.4, 1.0, 0.4, 1.0))
	_spawn_success_ring_flash()
	_downed_collapse_active = true
	var target: CanvasItem = $CharSprite if _uses_char_sprite else $Sprite
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "rotation", 0.0, 0.2)
	tween.tween_property(target, "modulate", Color.WHITE, 0.2)
	tween.chain().tween_callback(func() -> void:
		_downed_collapse_active = false
	)

## COOP-03/D-18: brief white ring flash on successful revive (mirrors _spawn_aura_pulse's
## scale+fade tween shape). Parented to FxLayer, degrades to a no-op if absent.
func _spawn_success_ring_flash() -> void:
	var layer := Juice._fx_layer()
	if layer == null:
		return
	const RADIUS: float = 28.0
	var ring := ColorRect.new()
	ring.color = Color(1.0, 1.0, 1.0, 0.9)
	ring.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	ring.pivot_offset = Vector2(RADIUS, RADIUS)
	ring.scale = Vector2(0.2, 0.2)
	layer.add_child(ring)
	ring.global_position = global_position - Vector2(RADIUS, RADIUS)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(1.8, 1.8), 0.3)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ring.queue_free)

## Stage-2 shield reflection — compute reflect amount and route to host.
## Pitfall 3: enemy.take_damage() is host-only; must send RPC to host if we're a client.
func _request_reflect(amount: int, attacker_path: String) -> void:
	if attacker_path == "":
		return  # no attacker info — reflection skipped (best-effort per deferred scope)
	var reflect_amount: int = maxi(int(amount * TANK_REFLECT_PCT), TANK_REFLECT_MIN)
	if multiplayer.is_server():
		request_reflect(attacker_path, reflect_amount)
	else:
		request_reflect.rpc_id(1, attacker_path, reflect_amount)

## Host-side RPC: resolve attacker path and apply reflected damage to the enemy.
## T-05-04 mitigation: only host runs enemy.take_damage (Enemy.take_damage also self-guards).
@rpc("any_peer", "call_remote", "reliable")
func request_reflect(attacker_path: String, reflect_amount: int) -> void:
	if not multiplayer.is_server():
		return
	var enemy := get_node_or_null(attacker_path)
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(reflect_amount)

# ──────────────────────────────────────────────────────────────────────────────
# Plan 02 helpers — Speedster dash
# ──────────────────────────────────────────────────────────────────────────────

## Apply a burst of velocity in the current input direction with i-frames active.
## Sets dash_invincible (replicated) and _dash_timer for duration countdown.
func _do_dash() -> void:
	dash_invincible = true
	_dash_timer = DASH_DURATION
	Sfx.play("dash")
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT  # fallback direction when no input held
	velocity = dir * SPEED * DASH_MULT
	move_and_slide()  # apply burst immediately

## ABIL-02/D-20: Speedster dash afterimage — a lightweight ghost copy of the current
## visual, parented to FxLayer (Juice._fx_layer) and faded out over ~0.3s. Runs from the
## every-peer _process diff on dash_invincible, so every screen sees the trail with no RPC.
## Degrades to a no-op if FxLayer isn't present yet.
func _spawn_dash_afterimage() -> void:
	var layer := Juice._fx_layer()
	if layer == null:
		return
	var ghost: CanvasItem
	if _uses_char_sprite:
		var spr: AnimatedSprite2D = $CharSprite
		var g := Sprite2D.new()
		g.texture = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
		g.flip_h = spr.flip_h
		g.scale = spr.scale
		g.offset = spr.offset
		ghost = g
	else:
		var rect := $Sprite as ColorRect
		var g2 := ColorRect.new()
		g2.color = rect.color
		g2.size = rect.size
		g2.position = -rect.size / 2.0  # center the rect on the captured position
		ghost = g2
	layer.add_child(ghost)
	ghost.z_index = 1
	ghost.global_position = global_position
	# Element-tinted and held longer than the dash itself, so the ghosts overlap into a
	# continuous streak instead of reading as separate stamps.
	var tint: Color = Juice.element_color(element)
	ghost.modulate = Color(tint.r, tint.g, tint.b, 0.75)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.45)
	tween.tween_callback(ghost.queue_free)

## Speed lines torn out backwards along the dash — the burst reads as air being ripped past
## rather than as an explosion at the feet. Element-colored, flat (no gravity: top-down view),
## parented to the persistent FxLayer like every other transient VFX.
func _spawn_dash_whoosh(dir: Vector2) -> void:
	var layer := Juice._fx_layer()
	if layer == null:
		return
	var p := ImpactBurst.build(Juice.element_color(element), 16, 0.35, -dir, 20.0, 130.0, 280.0, 1.2, 2.6)
	p.gravity = Vector2.ZERO
	layer.add_child(p)
	p.global_position = global_position
	Juice._backstop_free(p, 1.0)

## Spawn the Speedster Stage-2 shockwave at the landing position.
## Visual: yellow expanding ring (clone of HornShockwave._show_visual, RADIUS=80, yellow).
## Damage: host-only, enemies within DASH_SHOCK_RADIUS take DASH_SHOCK_DAMAGE + knockback.
func _spawn_dash_shockwave(pos: Vector2) -> void:
	_show_dash_shockwave.rpc(pos)  # call_local via annotation — visual on all peers
	if not multiplayer.is_server():
		return
	# Host-only: apply damage and knockback to enemies within radius (T-05-05 mitigation)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(pos) <= DASH_SHOCK_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(DASH_SHOCK_DAMAGE)
			# Knockback: push enemy away from shockwave origin
			# CR-005: guard against freed enemy (take_damage may queue_free if enemy dies)
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
				continue
			enemy.velocity += (enemy.global_position - pos).normalized() * 300.0

## Visual-only RPC for Speedster shockwave ring — yellow, 80px radius.
## Mirrors HornShockwave._show_visual exactly; no game-state mutation.
@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_dash_shockwave(pos: Vector2) -> void:
	const RADIUS: float = 80.0
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	Sfx.play("dash_shockwave")  # rides the existing every-peer visual RPC
	var ring := ColorRect.new()
	ring.color = Color(1.0, 1.0, 0.0, 0.8)  # yellow (Speedster shockwave — Claude's discretion)
	ring.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	ring.pivot_offset = Vector2(RADIUS, RADIUS)
	ring.position = pos - Vector2(RADIUS, RADIUS)
	ring.scale = Vector2(0.1, 0.1)
	game.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.35)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)

## HLTH-02 / Pitfall 3: Called via rpc_id(peer_id) from host (Enemy.gd or Bullet.gd).
## Uses @rpc("any_peer") because the host (peer 1) is NOT the node's multiplayer authority
## (authority = owning peer via set_multiplayer_authority). "any_peer" allows host to send
## this RPC to the owning peer. Owning peer applies damage to own health —
## MultiplayerSynchronizer then replicates health outward to all clients.
## Plan 02: attacker_path optional param added (Open Question 3) — callers may omit it;
##   reflection is best-effort and skipped when path is empty.
@rpc("any_peer", "call_remote", "reliable")
func receive_damage(amount: int, attacker_path: String = "", from_elite: bool = false) -> void:
	# Plan 02 D-11: Speedster i-frames ignore ALL damage (checked before everything else)
	if dash_invincible:
		return
	# Phase 6 D-07: invulnerable while picking a card
	if is_picking_card:
		return
	# Phase 6 D-11 airbag migration: airbag_active bool → airbag_count int; Level 2 heals to 25%
	if health - amount <= 0 and has_node("WeaponManager") and $WeaponManager.airbag_count > 0:
		var airbag_level: int = $WeaponManager.weapon_level.get("airbag_shield", 1)
		if airbag_level >= 2:
			health = maxi(1, MAX_HP >> 2)  # D-11 L2: heal to 25% HP instead of 1
		else:
			health = 1                     # D-11 L1: survive at 1 HP
		$WeaponManager.consume_airbag()
		return
	# Plan 02 D-08/D-09: Tank shield intercept — block all damage while active
	if shield_active:
		_last_attacker_path = attacker_path
		if evolution_stage >= 2:
			# Stage-2: reflect 50% (min 5) of blocked damage back to attacker via host
			_request_reflect(amount, attacker_path)
		return  # block damage regardless of stage
	health -= amount
	# Phase 7 Plan 03 (HUD-06, D-09): SUSPENSION fires on elite enemy hits only (WR-02 fix).
	# Placed after health -= amount so blocked/absorbed hits (shield, airbag, dash) never reach here.
	# WR-02: using from_elite flag instead of amount >= 15 threshold — at loop 3+ normal enemies
	# deal CONTACT_DAMAGE=15 (int(10 * 1.5)) and would incorrectly trigger SUSPENSION otherwise.
	# Routing: receive_damage runs on owning peer (may be client) — call host via RPC,
	# host validates is_server() and calls emit_hud.rpc("suspension") to all peers (T-07-07).
	if from_elite:
		var game := get_node_or_null("/root/Game")
		if game and game.has_method("notify_significant_hit"):
			# COOP-05/D-16: thread global_position through so the team-visible big_hit
			# broadcast renders at the actual hit location (Open Question 2, 10-RESEARCH.md).
			if multiplayer.is_server():
				# Host owns this player: call directly (no self-RPC needed)
				game.notify_significant_hit(global_position)
			else:
				# Client owns this player: route to host via rpc_id(1)
				# Mirrors Enemy.gd lines 135-138 and confirm_card_pick host-routing pattern
				game.notify_significant_hit.rpc_id(1, global_position)
	if health <= 0:
		health = 0
		_enter_downed()

## Phase 5: Heal this player by amount, clamped to MAX_HP (Pattern 6).
## Called by host via rpc_id(peer_id, amount) for Engineer passive, Earth heal, Drone pulse.
@rpc("any_peer", "call_remote", "reliable")
func receive_heal(amount: int) -> void:
	if is_downed:
		return
	health = mini(health + amount, MAX_HP)

## TEAM XP: progression moved to GameState (shared team pool). xp/level on this
## node mirror the team values — GameState._sync_team_xp writes them on the local
## player of every peer, and triggers _trigger_card_pick / _check_stage_threshold.

## Phase 5/6: Set evolution stage (D-04/D-20, D-13, D-22). Called by Phase 6 when XP threshold reached.
@rpc("any_peer", "call_remote", "reliable")
func set_evolution_stage(stage: int) -> void:
	evolution_stage = stage
	_play_evolution_transform(stage)  # PROG-03/D-14: charge-up, then deferred swap + reveal
	if stage == 3:
		# D-22: Stage 3 stat boost — applied once on transition to Full AutoBot
		stage3_damage_mult = 1.2
		MAX_HP += 25
		health = mini(health + 25, MAX_HP)

## PROG-03/D-14: ~0.5s element-colored charge-up glow ramp on the character before the stage
## reveal (Task 2 wires the reveal itself). `set_evolution_stage` already broadcasts via RPC
## on every peer (Pattern B), so the glow is visible identically to every peer; the rising
## shake build-up is gated `is_multiplayer_authority()` so a teammate's transform never shakes
## your screen (T-10-26). Driven by a plain non-blocking `Tween` — no await/yield, no input
## disable, no Camera2D change, no tree pause (T-10-25/T-10-26).
func _play_evolution_transform(stage: int) -> void:
	var target: CanvasItem = $CharSprite if _uses_char_sprite else $Sprite
	var color := Juice.element_color(element)
	_evolution_transform_active = true
	# One of only two moments that get a music reaction (the other is boss death). The sting
	# layers over the running shuffle rather than interrupting it — the transform is a beat in
	# the run, not a cutscene.
	Sfx.play("evolution")
	Music.play_evolution_sting()
	var charge := create_tween()
	charge.tween_method(func(t: float) -> void:
		var glow_scale: float = 1.0 + t * 0.6
		var c: Color = Color.WHITE.lerp(color, t)
		target.modulate = Color(c.r * glow_scale, c.g * glow_scale, c.b * glow_scale, 1.0)
		if is_multiplayer_authority():
			Juice.add_trauma(0.015)  # rising shake build-up, owner screen only (D-14/T-10-26)
	, 0.0, 1.0, 0.5)
	charge.tween_callback(func() -> void:
		_reveal_evolution_stage(stage, target, color)
	)

## PROG-03/D-14: fires at the end of the charge-up — sprite swap + element-colored burst +
## brief cosmetic hit-stop, then restores modulate to normal. `_swap_stage_visual` and
## `Juice.spawn_burst` both run on every peer (set_evolution_stage broadcasts via RPC), so the
## reveal is identical for all; `Juice.hitstop` is the local per-peer cosmetic dip only —
## never Engine.time_scale (T-10-25). Stage stat effects are untouched by this presentation-only
## composition. Total charge+reveal stays well within the ~1-1.5s cap (roadmap hard constraint).
func _reveal_evolution_stage(stage: int, target: CanvasItem, color: Color) -> void:
	call_deferred("_swap_stage_visual", stage)  # D-13: instant, deferred for physics safety
	Juice.spawn_burst(global_position, color, 20, 0.5)
	Juice.hitstop(0.08)  # brief snappy beat (D-06), local cosmetic dip only — never engine-global
	var restore := create_tween()
	restore.tween_property(target, "modulate", Color.WHITE, 0.15)
	restore.tween_callback(func() -> void:
		_evolution_transform_active = false
	)

## AUTOBONK: Update the animated character sprite each frame on every peer.
## Picks walk vs idle from position delta (works for remote peers too, since position is
## the replicated value), flips horizontally by travel direction, and selects the animation
## for the current evolution_stage. delta_t bridges the gap between 20 Hz position syncs.
func _update_char_visual(delta_t: float) -> void:
	if not has_node("CharSprite"):
		return
	var spr: AnimatedSprite2D = $CharSprite
	var move_delta: Vector2 = global_position - _last_anim_pos
	_last_anim_pos = global_position
	# Facing: the local player flips by the input direction it is pressing (responds
	# instantly, even when blocked by a wall). Remote peers have no access to that
	# input, so they flip by the replicated position delta instead.
	# Tank stage-2 art is mirrored relative to every other role/stage (drawn facing right,
	# not left), so its facing flag has to be inverted to match travel direction.
	var facing_inverted: bool = _sprite_key == "tank" and evolution_stage == 2
	if is_multiplayer_authority() and not is_downed:
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if absf(input_dir.x) > 0.1:
			spr.flip_h = (input_dir.x > 0.0) != facing_inverted
	elif absf(move_delta.x) > 0.5:
		spr.flip_h = (move_delta.x > 0.0) != facing_inverted
	if move_delta.length() > 0.5:
		_move_timer = 0.15
	else:
		_move_timer = maxf(0.0, _move_timer - delta_t)
	var stage: int = clampi(evolution_stage, 1, 3)
	var anim: String = "%s_%d_%s" % [_sprite_key, stage, "walk" if _move_timer > 0.0 else "idle"]
	if spr.animation != StringName(anim) or not spr.is_playing():
		spr.play(anim)
	# Normalized size per stage (also re-applies on evolution and mirrors the offset on flip)
	_apply_char_fit(stage, spr)
	# DMG-02/COOP-01/COOP-03/PROG-03: skip the per-frame modulate reset while a hit-flash tween,
	# the downed collapse/success tween, or the evolution charge-up/reveal tween owns it (see
	# _hit_flash_active / _downed_collapse_active / _evolution_transform_active doc comments).
	if not _hit_flash_active and not _downed_collapse_active and not _evolution_transform_active:
		spr.modulate = Color(0.4, 0.4, 0.4) if is_downed else Color.WHITE

func _swap_stage_visual(stage: int) -> void:
	_update_xp_hud()
	# AUTOBONK: animated roles encode the stage in the animation name, not container visibility
	if _uses_char_sprite:
		return
	# D-12, D-13: Hide all stage containers, show correct one
	for s in [1, 2, 3]:
		var container := get_node_or_null("Stage%dContainer" % s)
		if container:
			container.visible = (s == stage)

func _update_xp_hud() -> void:
	if has_node("PlayerHUD") and is_multiplayer_authority():
		$PlayerHUD.update_hud(xp, level, GameState.team_xp_threshold(level), evolution_stage)

## Phase 6 (D-03, D-04, EVOL-02, EVOL-03): Self-apply stage change after level-up.
## TEAM XP: level mirrors the team level, so all players evolve together.
func _check_stage_threshold() -> void:
	if level >= STAGE2_LEVEL and evolution_stage < 2:
		set_evolution_stage.rpc(2)
		set_evolution_stage(2)
	if level >= STAGE3_LEVEL and evolution_stage < 3:
		set_evolution_stage.rpc(3)
		set_evolution_stage(3)

## Phase 6 (XP-03, XP-04, XP-05, XP-06): Build eligible card pool for this player.
func _build_card_pool() -> Array:
	var pool: Array = []
	var wm: Node = get_node_or_null("WeaponManager")
	if wm:
		# Weapon unlocks removed from the level-up draw — new weapons come exclusively from
		# the sub-room weapon-choice overlay (_trigger_weapon_choice).
		# Weapon upgrades — exclude maxed weapons (XP-05)
		for wid in wm.unlocked_weapons:
			var lvl: int = wm.weapon_level.get(wid, 1)
			if lvl < 3:
				pool.append({"type": "weapon_upgrade", "weapon_id": wid, "new_level": lvl + 1})
	# Element upgrade (D-19, D-20): Fire/Ice max Tier 3; Earth also max Tier 3 (D-21)
	if element_tier < 3:
		pool.append({"type": "element_upgrade", "new_tier": element_tier + 1})
	# Stat boosts — always eligible (XP-04)
	for stat in ["Speed", "Max HP", "Damage"]:
		pool.append({"type": "stat_boost", "stat": stat, "amount": 10})
	# XP-06: fallback ensures pool never empty
	if pool.size() == 0:
		pool.append({"type": "fallback"})
	return pool

func _draw_cards(pool: Array) -> Array:
	pool.shuffle()
	var cards: Array = []
	for i in range(mini(3, pool.size())):
		cards.append(pool[i])
	# XP-06: pad to 3 with fallback if pool had fewer than 3 entries
	while cards.size() < 3:
		cards.append({"type": "fallback"})
	return cards

## Phase 6 (XP-02, D-06, D-07): Show card overlay for this player only.
## TEAM XP: GameState._sync_team_xp calls this on the LOCAL player of every peer,
## so all players pick simultaneously — each with their own card pool.
## Guards against rapid double level-ups by queuing extra picks.
func _trigger_card_pick() -> void:
	if not is_multiplayer_authority():
		return
	if is_picking_card:
		_pending_card_picks += 1
		return
	is_picking_card = true    # D-07: freezes input + invulnerability (see _physics_process + receive_damage)
	var pool: Array = _build_card_pool()
	var cards: Array = _draw_cards(pool)
	if has_node("CardOverlay"):
		$CardOverlay.show_cards(cards)
	_update_xp_hud()

## Called by Game._card_pick_complete after clearing is_picking_card, to drain the queue.
func _trigger_pending_card_pick() -> void:
	if _pending_weapon_choice:
		_pending_weapon_choice = false
		_trigger_weapon_choice()
		return
	if _pending_card_picks > 0:
		_pending_card_picks -= 1
		_trigger_card_pick()

## Sub-room weapon choice (end of sub-rooms 2 and 4): show 2 random not-yet-owned weapons.
## Reuses the level-up card flow — same is_picking_card freeze/invuln, same confirm path
## (Game.confirm_card_pick validates weapon_unlock against the host pool).
func _trigger_weapon_choice() -> void:
	if not is_multiplayer_authority():
		return
	if is_picking_card:
		_pending_weapon_choice = true
		return
	var wm: Node = get_node_or_null("WeaponManager")
	if wm == null or wm.unlocked_weapons.size() >= wm.MAX_WEAPONS:
		return
	var candidates: Array = []
	for wid in WEAPON_CHOICE_IDS:
		if not wm.unlocked_weapons.has(wid):
			candidates.append({"type": "weapon_unlock", "weapon_id": wid})
	if candidates.is_empty():
		return
	candidates.shuffle()
	is_picking_card = true
	if has_node("CardOverlay"):
		$CardOverlay.show_cards(candidates.slice(0, 2), "NEW WEAPON — PICK ONE")

func _confirm_card_pick() -> void:
	Sfx.play("ui_confirm")
	var selected_index: int = 0
	var selected_card: Dictionary = {}
	if has_node("CardOverlay"):
		selected_index = $CardOverlay.get_selected_index()
		selected_card = $CardOverlay.get_selected_card()
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("confirm_card_pick"):
		if multiplayer.is_server():
			game.confirm_card_pick(peer_id, selected_index, selected_card)
		else:
			game.confirm_card_pick.rpc_id(1, peer_id, selected_index, selected_card)

## Phase 6 (D-19): Host calls this RPC to increment element_tier on the owning peer.
@rpc("any_peer", "call_remote", "reliable")
func receive_element_tier_up() -> void:
	element_tier = mini(element_tier + 1, 3)  # D-20: max Tier 3
	_update_xp_hud()

## Phase 6 (D-08): Keyboard card navigation — A/D cycle, Enter confirm.
## Only active on owning peer while is_picking_card is true.
func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if not is_picking_card:
		return
	if event.is_action_pressed("ui_left"):    # A key
		if has_node("CardOverlay"):
			$CardOverlay.navigate(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"): # D key
		if has_node("CardOverlay"):
			$CardOverlay.navigate(1)
		get_viewport().set_input_as_handled()
	elif _is_confirm_key(event): # Enter or Space
		_confirm_card_pick()
		get_viewport().set_input_as_handled()

## Confirm with Enter or Space. Space also being role_ability is harmless here:
## while is_picking_card is true the ability dispatch in _physics_process is frozen.
func _is_confirm_key(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] \
			or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	return false

## HLTH-04: Enter downed state — disable actions, trigger visual, notify GameState
func _enter_downed() -> void:
	is_downed = true
	# GameState.track_downed checks if all players are down → game over (added in Plan 05)
	if GameState.has_method("track_downed"):
		GameState.track_downed(peer_id)
	# COOP-01: lights up the previously-scaffolded GameEvents.player_downed signal on every
	# peer. emit_player_downed is @rpc("authority", ...), so only the host may call .rpc() —
	# guard to host-authoritative sites only (acceptance criteria, Task 2d).
	if multiplayer.is_server():
		GameEvents.emit_player_downed.rpc(peer_id)

## Called by Game.gd when host confirms revive complete (via receive_revive RPC — see Plan 05)
func revive() -> void:
	health = MAX_HP >> 1  # revive with 50% HP (bit-shift avoids int-division warning)
	is_downed = false
	# MAP-07: this player's one revive for the sub-room is now spent. Runs on the owning peer
	# (receive_revive targets the authority), so the flag replicates outward from here.
	revive_used = true
	# COOP-03: lights up the previously-scaffolded GameEvents.player_revived signal — see the
	# emit_player_downed guard comment above (host-authoritative sites only).
	if multiplayer.is_server():
		GameEvents.emit_player_revived.rpc(peer_id)

## HLTH-06/COOP-02/D-18: Update ReviveBar (local UI) AND a world-space blue progress ring
## drawn on self via draw_arc — team-visible (called by Game.gd revive accumulator via RPC).
## progress: 0.0 to 1.0
## Widened any_peer/call_remote -> any_peer/call_local (COOP-02, T-10-22 mitigation): Player
## nodes are deterministically named Player_%d, so the broadcast resolves the same self node
## on every peer — the whole team sees the ring, not just the target's own client.
@rpc("any_peer", "call_local", "reliable")
func set_revive_progress(progress: float) -> void:
	if has_node("ReviveBar"):
		$ReviveBar.visible = progress > 0.0
		$ReviveBar.value = progress * 100.0
	_revive_ring_progress = progress
	_ensure_revive_ring()
	_revive_ring.queue_redraw()

## COOP-02/D-18: lazily creates the world-space revive-ring child Node2D and wires its
## `draw` signal — the CanvasItem custom-draw idiom for a plain Node2D: draw_* calls made
## from a function connected to `draw` apply to that same CanvasItem during its draw phase.
func _ensure_revive_ring() -> void:
	if _revive_ring != null:
		return
	_revive_ring = Node2D.new()
	_revive_ring.name = "ReviveRing"
	_revive_ring.z_index = 3
	add_child(_revive_ring)
	_revive_ring.draw.connect(_draw_revive_ring)

## Draws the blue revive-progress ring — radius ~28px, 4px stroke, Color(0.30,0.65,1.0),
## sweeping 0->360 degrees as _revive_ring_progress goes 0->1 (UI-SPEC). Hidden when <= 0.
func _draw_revive_ring() -> void:
	if _revive_ring_progress <= 0.0:
		return
	const RADIUS: float = 28.0
	const THICKNESS: float = 4.0
	var end_angle: float = TAU * clampf(_revive_ring_progress, 0.0, 1.0)
	_revive_ring.draw_arc(
		Vector2.ZERO, RADIUS, -PI / 2.0, -PI / 2.0 + end_angle, 32,
		Color(0.30, 0.65, 1.0), THICKNESS, true
	)

## Called by Game.gd attempt_revive when revive duration is complete.
## @rpc("any_peer") allows host (any_peer) to send this to the owning peer.
## Owning peer calls revive() locally — health and is_downed sync outward via
## MultiplayerSynchronizer.
@rpc("any_peer", "call_remote", "reliable")
func receive_revive() -> void:
	revive()
