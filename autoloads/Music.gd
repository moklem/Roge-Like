extends Node
## Music — global background music (autoload). One looping track at a time; survives scene
## changes because autoloads persist. Loaded at runtime with existence checks so a missing
## file never breaks anything.

const LOBBY_PATH  := "res://assets/audio/lobby.mp3"
const INGAME_PATH := "res://assets/audio/ingame.mp3"

## Lobby/menu music stays quiet ("leise"); in-game a touch louder but not blasting.
const LOBBY_DB  := -20.0
const INGAME_DB := -12.0

var _player: AudioStreamPlayer = null
var _current: String = ""

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)

## Quiet lobby/menu track — used in MainMenu and LobbyScreen.
func play_lobby() -> void:
	_play(LOBBY_PATH, LOBBY_DB)

## In-game track — started when the Game scene loads.
func play_ingame() -> void:
	_play(INGAME_PATH, INGAME_DB)

func stop() -> void:
	if _player:
		_player.stop()
	_current = ""

func _play(path: String, volume_db: float) -> void:
	if _player == null:
		return
	if _current == path and _player.playing:
		return  # already playing this track — don't restart on scene re-enter
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	# Make MP3 tracks loop seamlessly.
	if stream is AudioStreamMP3:
		stream.loop = true
	_player.stream = stream
	_player.volume_db = volume_db
	_player.play()
	_current = path
