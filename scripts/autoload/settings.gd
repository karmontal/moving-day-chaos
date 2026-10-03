extends Node
## Player settings persisted to user://settings.cfg, plus the game's input actions.

signal changed

const PATH := "user://settings.cfg"

var master_volume := 0.8
var music_volume := 0.6
var sfx_volume := 0.8
var fullscreen := false
var vsync := true
var language := ""
var vibration := true
var floating_text := true
## Show value popups when furniture is delivered or damaged.
var mouse_sensitivity := 1.0
## Chosen crew member (0-3, see Palette.PLAYER_COLORS / assets/models/mover_<n>.glb).
var character := 0
var player_name := ""
var invert_y := false


func _ready() -> void:
	_register_input_actions()
	load_settings()
	if player_name == "":
		player_name = "Mover %d" % (randi() % 900 + 100)
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	vsync = cfg.get_value("video", "vsync", vsync)
	language = cfg.get_value("game", "language", language)
	vibration = cfg.get_value("game", "vibration", vibration)
	floating_text = cfg.get_value("game", "floating_text", floating_text)
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	character = cfg.get_value("game", "character", character)
	player_name = cfg.get_value("game", "player_name", player_name)
	invert_y = cfg.get_value("controls", "invert_y", invert_y)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("game", "language", language)
	cfg.set_value("game", "vibration", vibration)
	cfg.set_value("game", "floating_text", floating_text)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("game", "character", character)
	cfg.set_value("game", "player_name", player_name)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.save(PATH)


## Applies the window settings; audio and language listen to `changed` themselves.
func apply() -> void:
	if not is_mobile() and DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	changed.emit()


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	save_settings()
	apply()


static func is_mobile() -> bool:
	return OS.has_feature("mobile")


static func is_web() -> bool:
	return OS.has_feature("web")


func _register_input_actions() -> void:
	_add_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action("move_up", [_key(KEY_W), _key(KEY_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action("move_down", [_key(KEY_S), _key(KEY_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add_action("look_left", [_joy_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add_action("look_right", [_joy_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add_action("look_up", [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add_action("look_down", [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_add_action("grab_left", [_mouse(MOUSE_BUTTON_LEFT), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add_action("grab_right", [_mouse(MOUSE_BUTTON_RIGHT), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add_action("grab_both", [_key(KEY_F)])
	_add_action("jump", [_key(KEY_SPACE), _joy_button(JOY_BUTTON_A)])
	_add_action("rotate_left", [_key(KEY_Q), _joy_button(JOY_BUTTON_LEFT_SHOULDER)])
	_add_action("rotate_right", [_key(KEY_E), _joy_button(JOY_BUTTON_RIGHT_SHOULDER)])
	_add_action("pause", [_key(KEY_ESCAPE), _joy_button(JOY_BUTTON_START)])
	_add_action("debug_overlay", [_key(KEY_F3)])


func _add_action(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for e: InputEvent in events:
		InputMap.action_add_event(action, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e
