extends Node
## Volume control and a pooled, throttled SFX player (buses: default_bus_layout.tres).

const SFX_DIR := "res://assets/audio/sfx/"
const POOL_SIZE := 12
## Minimum seconds between two plays of the same sound, so physics pile-ups do not turn into noise.
const MIN_INTERVAL := {"thud": 0.06, "grab": 0.04, "release": 0.04, "crash": 0.1, "tick": 0.5, "boing": 0.08, "oof": 0.3}
const SOUNDS: Array[String] = ["grab", "release", "thud", "crash", "jump", "delivered", "click", "win", "lose", "tick", "error", "boing", "oof", "hup"]

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}


func _ready() -> void:
	# Buses come from res://default_bus_layout.tres. Never add them at runtime: on the Web
	# export (sample playback) sounds routed through runtime-created buses are silent.
	for bus_name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			push_error("Audio bus missing from default_bus_layout.tres: " + bus_name)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for sound in SOUNDS:
		var path: String = SFX_DIR + sound + ".wav"
		if ResourceLoader.exists(path):
			_streams[sound] = load(path)
	Settings.changed.connect(_apply_volumes)
	_apply_volumes()


func play(sound: String, pitch_variation := 0.0, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -1.0)) < float(MIN_INTERVAL.get(sound, 0.0)):
		return
	_last_played[sound] = now
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_variation, pitch_variation))
	p.play()


func _apply_volumes() -> void:
	_set_bus("Master", Settings.master_volume)
	_set_bus("Music", Settings.music_volume)
	_set_bus("SFX", Settings.sfx_volume)
	_set_bus("UI", Settings.sfx_volume)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))
