extends Node
## Music — global background music (autoload). Survives scene changes because autoloads
## persist. Loaded at runtime with existence checks so a missing file never breaks anything.
##
## Track mapping (user):
##   Menu / Lobby -> Erba_1 (quiet, looping)
##   In-game      -> permanent random shuffle of the remaining tracks, starting with Erba_2.
##                   Rotates forever; every finished track picks a new random one.

## Lobby/menu track (loops seamlessly, quiet).
const LOBBY_TRACK := "res://assets/audio/Erba_1.wav"

## In-game shuffle always opens with Erba_2, then rotates randomly through the whole pool.
const INGAME_FIRST := "res://assets/audio/Erba_2.wav"
const INGAME_POOL: Array[String] = [
	"res://assets/audio/Erba_2.wav",
	"res://assets/audio/Theme_1.wav",
	"res://assets/audio/Lobby_1.wav",
	"res://assets/audio/ingame.mp3",
]

## Menu/lobby stays quiet ("leise"); in-game a touch louder but not blasting.
const LOBBY_DB  := -20.0
const INGAME_DB := -12.0

var _player: AudioStreamPlayer = null
var _mode: String = ""            # "single" (looping track) or "shuffle" (random rotation)
var _pool: Array[String] = []     # shuffle pool
var _current_path: String = ""
var _volume_db: float = -12.0

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)
	_player.finished.connect(_on_finished)

## Main-menu music — same quiet Erba_1 track as the lobby.
func play_menu() -> void:
	_play_single(LOBBY_TRACK, LOBBY_DB)

## Lobby music — quiet, looping Erba_1.
func play_lobby() -> void:
	_play_single(LOBBY_TRACK, LOBBY_DB)

## In-game — permanent random shuffle, first track Erba_2. Started on match load and left
## running across all rooms (no per-room restart; the autoload persists the rotation).
func play_ingame() -> void:
	_play_shuffle(INGAME_POOL, INGAME_DB, INGAME_FIRST)

func stop() -> void:
	if _player:
		_player.stop()
	_mode = ""
	_current_path = ""

## Single looping track. No-op if that track is already playing (avoids restart on re-enter).
func _play_single(path: String, volume_db: float) -> void:
	if _player == null:
		return
	if _mode == "single" and _current_path == path and _player.playing:
		return
	_mode = "single"
	_pool = []
	_volume_db = volume_db
	_current_path = path
	_play_path(path, true)

## Permanent random rotation. No-op if a shuffle is already running (don't restart on
## repeated calls / scene re-enter). Opens with `first`, then random picks on every finish.
func _play_shuffle(pool: Array[String], volume_db: float, first: String) -> void:
	if _player == null:
		return
	if _mode == "shuffle" and _player.playing:
		return
	_mode = "shuffle"
	_pool = pool.duplicate()
	_volume_db = volume_db
	var start: String = first if ResourceLoader.exists(first) else _random_from_pool("")
	_current_path = start
	_play_path(start, false)

## Loads and plays a single stream. `loop` at the stream level for single tracks; shuffle
## tracks play once (loop off) so the `finished` signal advances the rotation.
func _play_path(path: String, loop: bool) -> void:
	if _player == null or path.is_empty():
		return
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamMP3:
		stream.loop = loop
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		stream.loop = loop
	_player.stream = stream
	_player.volume_db = _volume_db
	_player.play()

## Shuffle advance: a track finished, roll a new random one and keep going forever.
func _on_finished() -> void:
	if _mode != "shuffle":
		return
	var next: String = _random_from_pool(_current_path)
	_current_path = next
	_play_path(next, false)

## Random existing track from the pool, avoiding an immediate repeat when possible.
func _random_from_pool(exclude: String) -> String:
	var candidates: Array[String] = []
	for p in _pool:
		if ResourceLoader.exists(p) and p != exclude:
			candidates.append(p)
	if candidates.is_empty():
		for p in _pool:
			if ResourceLoader.exists(p):
				candidates.append(p)
	if candidates.is_empty():
		return ""
	return candidates[randi() % candidates.size()]
