extends Node
## Sfx — global sound-effect manager (autoload).
##
## Cues are declared once in CUES and played by name: `Sfx.play("dash")`. Streams are
## load()-ed at runtime (not preload) and a missing file resolves to null, so a cue whose
## .wav the team hasn't delivered yet degrades to silence instead of breaking anything.
## That safe-load property is what lets every trigger point be wired ahead of the audio.
##
## Two pools. Routine cues (shots, hits, weapons, UI) round-robin through the shared pool and
## may cut each other off under heavy fire — that's fine, they're texture. The must-hear
## stingers (see PRIORITY) get their own small reserved pool so a busy fight can never steal
## their voice. Kept deliberately quiet — these are feedback cues, not the focus of the mix.
##
## Cue names, file paths and their intended character are documented for the team in
## assets/audio/AUDIO_CHECKLIST.md — keep the two in sync.

const POOL_SIZE: int = 16
const PRIORITY_POOL_SIZE: int = 4

const SFX_DIR: String = "res://assets/audio/sfx/"

## cue name -> [file basename, volume_db, pitch_min, pitch_max]
## Negative dB keeps the cues subtle. Pitch jitter stops repeated cues sounding machine-gunned.
const CUES: Dictionary = {
	# --- combat (routine) ---
	"shoot":           ["shoot.wav",           -17.0, 0.95, 1.08],
	"hit":             ["hit.wav",             -13.0, 0.92, 1.10],
	"enemy_die":       ["enemy_die.wav",       -12.0, 0.90, 1.10],
	# --- weapons ---
	"exhaust_flames":  ["exhaust_flames.wav",  -15.0, 0.95, 1.05],
	"antenna_beam":    ["antenna_beam.wav",    -15.0, 0.95, 1.05],
	"horn_shockwave":  ["horn_shockwave.wav",  -14.0, 0.95, 1.05],
	"airbag_arm":      ["airbag_arm.wav",      -14.0, 1.00, 1.00],
	"airbag_break":    ["airbag_break.wav",    -11.0, 0.95, 1.05],
	# --- role abilities ---
	"dash":            ["dash.wav",            -14.0, 0.95, 1.08],
	"dash_shockwave":  ["dash_shockwave.wav",  -12.0, 0.95, 1.05],
	"shield_up":       ["shield_up.wav",       -14.0, 0.95, 1.05],
	"earth_shockwave": ["earth_shockwave.wav", -12.0, 0.95, 1.05],
	"engineer_heal":   ["engineer_heal.wav",   -16.0, 0.98, 1.04],
	"drone_deploy":    ["drone_deploy.wav",    -14.0, 0.95, 1.05],
	# --- elemental HUD echoes (onset-gated, see _on_hud_event) ---
	"ice_ac_hiss":     ["ice_ac_hiss.wav",     -15.0, 0.97, 1.03],
	"fire_engine":     ["fire_engine.wav",     -15.0, 0.97, 1.03],
	"earth_servo_hum": ["earth_servo_hum.wav", -16.0, 0.98, 1.02],
	"lidar_blip":      ["lidar_blip.wav",      -16.0, 0.98, 1.02],
	# --- pickups, transitions, UI ---
	"xp_arrive":       ["xp_arrive.wav",       -16.0, 0.96, 1.10],
	"exit_open":       ["exit_open.wav",       -12.0, 1.00, 1.00],
	"transition":      ["transition.wav",      -12.0, 1.00, 1.00],
	"run_start":       ["run_start.wav",       -10.0, 1.00, 1.00],
	"ui_click":        ["ui_click.wav",        -18.0, 0.98, 1.02],
	"ui_navigate":     ["ui_navigate.wav",     -20.0, 0.98, 1.06],
	"ui_confirm":      ["ui_confirm.wav",      -16.0, 1.00, 1.00],
	# --- priority stingers (reserved pool) ---
	"kill_fanfare":    ["kill_fanfare.wav",     -8.0, 0.98, 1.02],
	"boss_phase":      ["boss_phase.wav",       -7.0, 1.00, 1.00],
	"boss_death":      ["boss_death.wav",       -6.0, 1.00, 1.00],
	"evolution":       ["evolution.wav",        -7.0, 1.00, 1.00],
	"level_up":        ["level_up.wav",         -9.0, 1.00, 1.00],
	"downed":          ["downed.wav",           -8.0, 1.00, 1.00],
	"revive":          ["revive.wav",           -8.0, 1.00, 1.00],
	"big_hit":         ["big_hit.wav",          -8.0, 0.97, 1.03],
}

## Must-hear stingers — routed to the reserved pool so routine fire can't steal their voice.
const PRIORITY: Array[String] = [
	"kill_fanfare", "boss_phase", "boss_death", "evolution",
	"level_up", "downed", "revive", "big_hit",
]

## HUD event -> cue. The CARIAD indicators already fire on every peer for exactly the moments
## we want to sound, so echoing them here means no extra RPCs and no per-element edits
## scattered through the gameplay files. Cue character mirrors the indicator's car framing:
## AC COLD -> compressor hiss, ENGINE OVERHEAT -> engine rattle, SEAT MASSAGE -> servo hum.
const HUD_ECHO: Dictionary = {
	"ac":           "ice_ac_hiss",
	"engine":       "fire_engine",
	"seat_massage": "earth_servo_hum",
	"lidar":        "lidar_blip",
}

## SFX-02: a continuous effect re-emits its HUD event to keep the indicator lit (Earth's heal
## re-emits "seat_massage" every 1.0s; Fire bursts rapidly). Sounding every emit would be a
## machine-gun. The gate below re-fires a cue only after a real gap in the event stream, so a
## sustained effect collapses to a single cue at activation onset. Must stay comfortably above
## the fastest continuous re-emit interval (Earth: 1.0s).
const ONSET_GAP: float = 1.5

var _players: Array[AudioStreamPlayer] = []
var _priority_players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _next_priority: int = 0
var _streams: Dictionary = {}       # cue name -> AudioStream (absent when the file isn't there)
var _hud_last_seen: Dictionary = {} # hud event name -> last time seen (seconds)

func _ready() -> void:
	for _i in range(POOL_SIZE):
		_players.append(_make_player())
	for _i in range(PRIORITY_POOL_SIZE):
		_priority_players.append(_make_player())
	for cue in CUES:
		var stream := _try_load(SFX_DIR + CUES[cue][0])
		if stream != null:
			_streams[cue] = stream
	# Central listeners — these events already fire on every peer, so the cue rides along with
	# them and no gameplay file needs a separate sound call for them.
	GameEvents.hud_event.connect(_on_hud_event)
	GameEvents.player_downed.connect(func(_id: int) -> void: play("downed"))
	GameEvents.player_revived.connect(func(_id: int) -> void: play("revive"))
	GameEvents.big_hit.connect(func(_pos: Vector2) -> void: play("big_hit"))

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	add_child(p)
	return p

func _try_load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null

## Play a cue by name. An unknown name is a programming error — it warns, because a typo would
## otherwise be indistinguishable from a not-yet-delivered file, which is silent by design. A
## known cue whose file is missing is simply silent.
func play(cue: String) -> void:
	if not CUES.has(cue):
		push_warning("Sfx.play: unknown cue '%s'" % cue)
		return
	if not _streams.has(cue):
		return  # file not delivered yet — silent by design
	var is_priority: bool = cue in PRIORITY
	var pool: Array[AudioStreamPlayer] = _priority_players if is_priority else _players
	if pool.is_empty():
		return
	var p: AudioStreamPlayer
	if is_priority:
		p = pool[_next_priority]
		_next_priority = (_next_priority + 1) % pool.size()
	else:
		p = pool[_next]
		_next = (_next + 1) % pool.size()
	var cfg: Array = CUES[cue]
	p.stream = _streams[cue]
	p.volume_db = cfg[1]
	p.pitch_scale = randf_range(cfg[2], cfg[3])
	p.play()

## SFX-02 onset gate. The timestamp advances on EVERY event, so a source that keeps re-emitting
## never re-opens the gate; the cue only re-fires once the event stream has actually gone quiet
## for ONSET_GAP — i.e. on the next genuine activation.
func _on_hud_event(event_name: String) -> void:
	if not HUD_ECHO.has(event_name):
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var last: float = _hud_last_seen.get(event_name, -INF)
	_hud_last_seen[event_name] = now
	if now - last < ONSET_GAP:
		return
	play(HUD_ECHO[event_name])

## Subtle shoot 'pew' — played locally when the owning player fires screws/bolts.
func shoot() -> void:
	play("shoot")

## Subtle hit 'tick' — played when an enemy takes damage (on every peer via hp change).
func hit() -> void:
	play("hit")
