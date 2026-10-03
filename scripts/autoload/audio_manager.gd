extends Node
## Volume control and a pooled, throttled SFX player (buses: default_bus_layout.tres).

const SFX_DIR := "res://assets/audio/sfx/"
const POOL_SIZE := 12
## Minimum seconds between two plays of the same sound, so physics pile-ups do not turn into noise.
const MIN_INTERVAL := {"thud": 0.06, "grab": 0.04, "release": 0.04, "crash": 0.1, "tick": 0.5, "boing": 0.08, "oof": 0.3}
const SOUNDS: Array[String] = ["grab", "release", "thud", "crash", "jump", "delivered", "click", "win", "lose", "tick", "error", "boing", "oof", "hup"]

const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC_FADE := 0.8

var _streams := {}
var _music: Array[AudioStreamPlayer] = []
var _music_current := 0
var _music_name := ""
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
	for i in 2:  # two players so tracks can crossfade
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
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


## Crossfades to a looping track from assets/audio/music ("" fades out).
func play_music(track: String, fade := MUSIC_FADE) -> void:
	if track == _music_name:
		return
	_music_name = track
	var old := _music[_music_current]
	_music_current = 1 - _music_current
	var new := _music[_music_current]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, fade)
	tw.chain().tween_callback(old.stop)
	if track == "":
		return
	var path := MUSIC_DIR + track + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	new.stream = stream
	new.volume_db = -30.0
	new.play()
	create_tween().tween_property(new, "volume_db", -6.0, fade)


func current_music() -> String:
	return _music_name


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
