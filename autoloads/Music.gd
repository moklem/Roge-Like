extends Node
## Music — global background music (autoload). Survives scene changes because autoloads
## persist. Loaded at runtime with existence checks so a missing file never breaks anything.
##
## Track mapping (user, fixed order — no shuffle):
##   Menu / Lobby            -> lobby.mp3 (quiet, looping)
##   Room 1 (ERBA, all subs) -> Erba.ogg
##   Room 2 subs 1-3         -> altstadt1.mp3
##   Room 2 subs 4-5         -> altstadt2.ogg
##   Room 2 sub 6 (Übergang) -> Altenburg.ogg   (theme starts AT the connector)
##   Room 3 (Burg Altenburg) -> Altenburg.ogg
## Every track loops until the next zone switches it; re-entering the same zone is a no-op.

## Lobby/menu track (loops seamlessly, quiet).
const LOBBY_TRACK := "res://assets/audio/lobby.mp3"

const TRACK_ERBA       := "res://assets/audio/Erba.ogg"
const TRACK_ALTSTADT_1 := "res://assets/audio/altstadt1.mp3"
const TRACK_ALTSTADT_2 := "res://assets/audio/altstadt2.ogg"
const TRACK_ALTENBURG  := "res://assets/audio/Altenburg.ogg"

## Menu/lobby stays quiet ("leise"); in-game a touch louder but not blasting.
const LOBBY_DB  := -20.0
const INGAME_DB := -12.0

var _player: AudioStreamPlayer = null
var _current_path: String = ""
var _volume_db: float = -12.0
var _sting: AudioStreamPlayer = null

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)
	_player.finished.connect(_on_finished)
	_sting = AudioStreamPlayer.new()
	_sting.bus = "Music"
	add_child(_sting)

## Safety net: WAV tracks loop via their .import settings (edit/loop_mode=Forward), so
## `finished` never fires for them. If a track ends anyway (e.g. a re-imported file lost
## its loop flag), restart it instead of falling silent.
func _on_finished() -> void:
	if not _current_path.is_empty():
		_play_path(_current_path, true)

## Main-menu music — same quiet lobby track as the lobby.
func play_menu() -> void:
	_play_single(LOBBY_TRACK, LOBBY_DB)

## Lobby music — quiet, looping lobby track.
func play_lobby() -> void:
	_play_single(LOBBY_TRACK, LOBBY_DB)

## In-game — fixed track per zone. Called on match start and on every room/sub-room
## transition; _play_single no-ops when the mapped track is already running, so crossing
## sub-rooms inside the same zone never restarts the music.
func play_zone(room: int, sub_room: int) -> void:
	_play_single(_zone_track(room, sub_room), INGAME_DB)

func _zone_track(room: int, sub_room: int) -> String:
	match room:
		1:
			return TRACK_ERBA
		2:
			if sub_room <= 3:
				return TRACK_ALTSTADT_1
			if sub_room <= 5:
				return TRACK_ALTSTADT_2
			return TRACK_ALTENBURG  # sub 6 = Übergang: Altenburg theme starts here
		_:
			return TRACK_ALTENBURG

func stop() -> void:
	if _player:
		_player.stop()
	if _sting:
		_sting.stop()
	_current_path = ""

## Two — and only two — moments get a music reaction, layered OVER the running track rather
## than interrupting it: the evolution transform and the boss death that ends the loop. Boss
## phase changes stay SFX-only, so the music layer keeps marking the genuine climaxes.
## Same safe-load discipline as everything else: a missing sting file is silent, not a crash.
const EVOLUTION_STING := "res://assets/audio/evolution_sting.wav"
const BOSS_DEATH_STING := "res://assets/audio/boss_death_sting.wav"
const STING_DB := -8.0

func play_evolution_sting() -> void:
	_play_sting(EVOLUTION_STING)

func play_boss_death_sting() -> void:
	_play_sting(BOSS_DEATH_STING)

## Fire-and-forget one-shot on its own player, so it overlaps the music instead of stopping
## it. Loop is forced off — a sting that looped would never stop.
func _play_sting(path: String) -> void:
	if _sting == null or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamMP3:
		stream.loop = false
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		stream.loop = false
	_sting.stream = stream
	_sting.volume_db = STING_DB
	_sting.play()

## Single looping track. No-op if that track is already playing (avoids restart on re-enter).
func _play_single(path: String, volume_db: float) -> void:
	if _player == null:
		return
	if _current_path == path and _player.playing:
		return
	_volume_db = volume_db
	_current_path = path
	_play_path(path, true)

## Loads and plays a single stream, looping at the stream level.
## WAV loop points come from the .import settings (edit/loop_mode=Forward) — forcing
## LOOP_FORWARD at runtime on a stream imported without markers leaves loop_end at 0
## and plays pure silence, so WAVs are deliberately left untouched here (Pitfall).
## A WAV that slips through without an import loop is caught by _on_finished instead.
func _play_path(path: String, loop: bool) -> void:
	if _player == null or path.is_empty():
		return
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamMP3:
		stream.loop = loop
	elif stream is AudioStreamOggVorbis:
		stream.loop = loop
	_player.stream = stream
	_player.volume_db = _volume_db
	_player.play()
