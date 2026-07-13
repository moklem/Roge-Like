extends Node
## Sfx — global sound-effect manager (autoload).
## Small voice pool so overlapping shots/hits don't cut each other off. Streams are
## load()-ed at runtime (not preload) so a missing/late import never breaks parsing.
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

## Subtle shoot 'pew' — played locally when the owning player fires screws/bolts.
func shoot() -> void:
	_play(_shoot, SHOOT_DB, 0.95, 1.08)

## Subtle hit 'tick' — played when an enemy takes damage (on every peer via hp change).
func hit() -> void:
	_play(_hit, HIT_DB, 0.92, 1.10)
