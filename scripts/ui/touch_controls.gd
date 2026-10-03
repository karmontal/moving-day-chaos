class_name TouchControls
extends Control
## On-screen controls for phones and tablets. Left side: floating move stick. Right side: drag to
## look (which also raises and lowers the arms) plus buttons. Grab buttons toggle (tap to start
## reaching/holding, tap again to let go) so the same thumb can keep aiming while carrying.

signal pause_pressed

const STICK_RADIUS := 120.0
const LOOK_SPEED := 0.0055
## Touches that start left of this fraction of the screen drive the stick.
const STICK_ZONE := 0.42

var move := Vector2.ZERO
var grab: Array[bool] = [false, false]
var jump := false
var rotate := 0.0
## Hand states for the button highlights (set by the rig each frame).
var holding: Array[bool] = [false, false]

var _look_delta := Vector2.ZERO
var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _look_index := -1
var _look_last := Vector2.ZERO
var _pressed := {}  # touch index -> button id
var _buttons: Array[Dictionary] = []
var _icons := {}

const BUTTON_COLORS := {
	"both": Color("f26b4e"), "left": Color("2a8c99"), "right": Color("2a8c99"),
	"jump": Color("e5b022"), "rot_l": Color("a98bdb"), "rot_r": Color("a98bdb"), "pause": Color("fff4e0"),
}


## True on phones/tablets; Engine meta "force_touch" lets desktop screenshots show the layout.
static func wanted() -> bool:
	return Settings.is_mobile() or DisplayServer.is_touchscreen_available() or Engine.get_meta("force_touch", false)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_layout()
	get_viewport().size_changed.connect(_layout)


## Accumulated look drag since the last call (pixels).
func take_look() -> Vector2:
	var d := _look_delta * LOOK_SPEED
	_look_delta = Vector2.ZERO
	return d


func _layout() -> void:
	var s := get_viewport_rect().size
	_buttons = [
		{"id": "both", "pos": Vector2(s.x - 260, s.y - 270), "r": 118.0, "label": "TOUCH_GRAB"},
		{"id": "left", "pos": Vector2(s.x - 490, s.y - 370), "r": 74.0, "label": "TOUCH_LEFT"},
		{"id": "right", "pos": Vector2(s.x - 150, s.y - 500), "r": 74.0, "label": "TOUCH_RIGHT"},
		{"id": "jump", "pos": Vector2(s.x - 470, s.y - 130), "r": 72.0, "label": "TOUCH_JUMP"},
		{"id": "rot_l", "pos": Vector2(s.x - 690, s.y - 130), "r": 60.0, "label": ""},
		{"id": "rot_r", "pos": Vector2(s.x - 690, s.y - 290), "r": 60.0, "label": ""},
		{"id": "pause", "pos": Vector2(s.x * 0.5 - 190, 82), "r": 46.0, "label": ""},
	]
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _stick_index:
			var v: Vector2 = (event.position - _stick_origin).limit_length(STICK_RADIUS)
			_stick_knob = _stick_origin + v
			move = v / STICK_RADIUS
			queue_redraw()
		elif event.index == _look_index:
			_look_delta += event.position - _look_last
			_look_last = event.position


func _touch_down(index: int, at: Vector2) -> void:
	for b in _buttons:
		if at.distance_to(b.pos) <= b.r * 1.15:
			_pressed[index] = b.id
			_press(b.id)
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
	if at.x < get_viewport_rect().size.x * STICK_ZONE:
		if _stick_index == -1:
			_stick_index = index
			_stick_origin = at
			_stick_knob = at
	elif _look_index == -1:
		_look_index = index
		_look_last = at
	queue_redraw()


func _touch_up(index: int) -> void:
	if index == _stick_index:
		_stick_index = -1
		move = Vector2.ZERO
	elif index == _look_index:
		_look_index = -1
	elif _pressed.has(index):
		var id: String = _pressed[index]
		_pressed.erase(index)
		match id:
			"jump":
				jump = false
			"rot_l", "rot_r":
				rotate = 0.0
	queue_redraw()


func _press(id: String) -> void:
	match id:
		"both":
			var on := not (grab[0] and grab[1])
			grab = [on, on]
		"left":
			grab[0] = not grab[0]
		"right":
			grab[1] = not grab[1]
		"jump":
			jump = true
		"rot_l":
			rotate = 1.0
		"rot_r":
			rotate = -1.0
		"pause":
			pause_pressed.emit()
	AudioManager.play("click", 0.0, -8.0)
	PlatformServices.vibrate(15)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := UITheme.FONT
	# Move stick: a chunky ring with a coral knob (ghosted until touched).
	var ghost := _stick_index == -1
	var base := Vector2(260, get_viewport_rect().size.y - 260) if ghost else _stick_origin
	var knob := base if ghost else _stick_knob
	var a := 0.45 if ghost else 0.9
	draw_circle(base + Vector2(0, 8), STICK_RADIUS, Color(0, 0, 0, 0.18 * a))
	draw_circle(base, STICK_RADIUS, Color(Palette.CREAM, 0.35 * a))
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 64, Color(Palette.CHOCOLATE, 0.8 * a), 6.0, true)
	_sticker(knob, 52.0, Color(Palette.PLAYER_COLORS[0], a), false, a)
	for b in _buttons:
		var id := String(b.id)
		var pressed := _pressed.values().has(id)
		var r: float = b.r
		var color: Color = BUTTON_COLORS.get(id, Palette.CREAM)
		var hand := -1
		match id:
			"both":
				pressed = pressed or (grab[0] and grab[1])
			"left":
				hand = 0
				pressed = pressed or grab[0]
			"right":
				hand = 1
				pressed = pressed or grab[1]
		var holding_now := (hand >= 0 and holding[hand]) or (id == "both" and holding[0] and holding[1])
		var c := _sticker(b.pos, r, color, pressed, 1.0, holding_now)
		match id:
			"both", "left", "right":
				var tex := _icon("glove_fist" if holding_now or pressed else "glove_open")
				_draw_icon(tex, c, r * (1.25 if id == "both" else 1.15), id == "left")
				if id != "both":
					_badge(c + Vector2(r * 0.62, -r * 0.62), tr(b.label), font)
			"jump":
				_draw_icon(_icon("boot"), c, r * 1.25, false)
			"rot_l":
				_draw_icon(_icon("rotate_ccw"), c, r * 1.2, false)
			"rot_r":
				_draw_icon(_icon("rotate_cw"), c, r * 1.2, false)
			"pause":
				draw_rect(Rect2(c + Vector2(-15, -18), Vector2(10, 36)), Palette.CHOCOLATE)
				draw_rect(Rect2(c + Vector2(5, -18), Vector2(10, 36)), Palette.CHOCOLATE)


## A raised cartoon button: drop shadow, outline, top highlight; sinks when pressed.
## Returns the face centre (moved down while pressed).
func _sticker(pos: Vector2, r: float, color: Color, pressed: bool, alpha := 1.0, glow := false) -> Vector2:
	var depth := 3.0 if pressed else 9.0
	var face := pos + Vector2(0, 9.0 - depth)
	draw_circle(pos + Vector2(0, 9), r, Color(Palette.CHOCOLATE, 0.55 * alpha))
	if glow:
		draw_circle(face, r + 10.0, Color(Palette.HIVIS, 0.75 * alpha))
	draw_circle(face, r, color.darkened(0.12) if pressed else color)
	draw_circle(face + Vector2(0, -r * 0.18), r * 0.78, Color(color.lightened(0.28), 0.55 * alpha))
	draw_circle(face, r * 0.7, Color(color.darkened(0.12) if pressed else color, 1.0))
	draw_arc(face, r, 0.0, TAU, 64, Color(Palette.CHOCOLATE, alpha), 6.0, true)
	draw_arc(face, r * 0.86, -PI * 0.85, -PI * 0.35, 16, Color(1, 1, 1, 0.55 * alpha), 5.0, true)
	return face


func _badge(pos: Vector2, text: String, font: Font) -> void:
	var size := 26
	var w := maxf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 18.0, 40.0)
	var rect := Rect2(pos - Vector2(w * 0.5, 20), Vector2(w, 40))
	draw_style_box(UITheme.box(Palette.CREAM, 20, 4), rect)
	draw_string(font, Vector2(rect.position.x + (w - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) * 0.5, pos.y + 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Palette.CHOCOLATE)


func _draw_icon(tex: Texture2D, center: Vector2, size: float, mirror: bool) -> void:
	if tex == null:
		return
	var rect := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	if mirror:
		draw_set_transform(center, 0.0, Vector2(-1, 1))
		rect.position = -Vector2(size, size) * 0.5
		draw_texture_rect(tex, rect, false)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect(tex, rect, false)


## Icons are cached: textures loaded inside _draw and dropped come back white (Kitchen Survivors).
func _icon(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		_icons[icon_name] = load("res://assets/ui/%s.png" % icon_name)
	return _icons[icon_name]
