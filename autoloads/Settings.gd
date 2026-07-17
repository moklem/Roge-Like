extends Node
## Settings — per-client, never-synced settings store (D-10, autoload).
## Holds screen-shake intensity + music/sfx volume. In-memory per launch only,
## no persistence (Claude's discretion per CONTEXT.md — user did not require it).
## Volume setters degrade to a no-op when the target audio bus doesn't exist yet
## (mirrors the safe-load guard convention in autoloads/Sfx.gd), so Plan 10-01 can
## ship before Plan 10-02 creates the "Music"/"SFX" buses.

## Screen-shake intensity tiers (UI-SPEC "Screen Shake" intensity table).
const SHAKE_OFF: int = 0
const SHAKE_LOW: int = 1
const SHAKE_NORMAL: int = 2

## D-10: defaults to normal (index 2).
var shake_intensity: int = SHAKE_NORMAL

## D-09: volume sliders, 0.0-1.0, default full volume.
var music_volume: float = 1.0
var sfx_volume: float = 1.0

## Music mute toggle (main-menu corner button). Independent of music_volume so
## unmuting restores the previous slider position.
var music_muted: bool = false

## Mutes/unmutes the Music bus. No-op when the "Music" bus doesn't exist (Pitfall 7).
func set_music_muted(muted: bool) -> void:
	music_muted = muted
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)

func toggle_music_muted() -> bool:
	set_music_muted(not music_muted)
	return music_muted

## Trauma multiplier per intensity tier (UI-SPEC table: Off 0.0x, Low 0.4x, Normal 1.0x).
## D-11: this setting governs screen shake ONLY — hit-stop/flash/particles always play.
func shake_multiplier() -> float:
	match shake_intensity:
		SHAKE_OFF:
			return 0.0
		SHAKE_LOW:
			return 0.4
		_:
			return 1.0

## Advances the shake intensity 0 -> 1 -> 2 -> 0 (for the Settings-panel cycle button).
func cycle_shake() -> int:
	shake_intensity = (shake_intensity + 1) % 3
	return shake_intensity

func set_shake_intensity(value: int) -> void:
	shake_intensity = clampi(value, SHAKE_OFF, SHAKE_NORMAL)

## Human-readable label for the Settings-panel cycle button (UI-SPEC copy: OFF/LOW/NORMAL).
func shake_label() -> String:
	match shake_intensity:
		SHAKE_OFF:
			return "OFF"
		SHAKE_LOW:
			return "LOW"
		_:
			return "NORMAL"

## Quietest audible slider position, in dB. Below this the bus is hard-muted.
const MIN_VOLUME_DB: float = -40.0

## Slider position (0..1) -> bus dB, linear in dB rather than in amplitude.
## `linear_to_db()` is the physically correct amplitude mapping, but it crams almost all
## of the audible range into the bottom fifth of the slider: 0.75 lands on -2.5 dB and
## 0.5 on -6 dB, which is inaudible over the -20 dB menu track. Interpolating in dB
## instead spreads the change across the whole travel.
func _slider_to_db(v: float) -> float:
	if v <= 0.0:
		return -80.0
	return lerpf(MIN_VOLUME_DB, 0.0, v)

## Sets Music-bus volume. No-op when the "Music" bus doesn't exist (Pitfall 7).
func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, _slider_to_db(music_volume))

## Sets SFX-bus volume. No-op when the "SFX" bus doesn't exist (Pitfall 7).
func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, _slider_to_db(sfx_volume))
