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
	if _stick_index != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.16))
		draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 48, Color(Palette.CHOCOLATE, 0.4), 4.0, true)
		draw_circle(_stick_knob, 50.0, Color(Palette.ACCENT, 0.8))
	else:
		# Ghost stick so first-time players know where to put their thumb.
		var ghost := Vector2(260, get_viewport_rect().size.y - 260)
		draw_arc(ghost, STICK_RADIUS, 0.0, TAU, 48, Color(Palette.CREAM, 0.35), 4.0, true)
		draw_circle(ghost, 50.0, Color(Palette.CREAM, 0.25))
	for b in _buttons:
		var active := _pressed.values().has(b.id)
		var fill := Color(Palette.CREAM, 0.30)
		match String(b.id):
			"both":
				active = active or (grab[0] and grab[1])
				if holding[0] and holding[1]:
					fill = Color(Palette.HIVIS, 0.85)
			"left":
				active = active or grab[0]
				if holding[0]:
					fill = Color(Palette.HIVIS, 0.85)
			"right":
				active = active or grab[1]
				if holding[1]:
					fill = Color(Palette.HIVIS, 0.85)
		if active and fill.a < 0.5:
			fill = Color(Palette.CREAM, 0.75)
		var r: float = b.r
		draw_circle(b.pos, r, fill)
		draw_arc(b.pos, r, 0.0, TAU, 48, Color(Palette.CHOCOLATE, 0.7), 5.0, true)
		var ink := Palette.CHOCOLATE
		match String(b.id):
			"rot_l", "rot_r":
				_draw_spin_arrow(b.pos, r * 0.5, 1.0 if b.id == "rot_l" else -1.0, ink)
			"pause":
				draw_rect(Rect2(b.pos + Vector2(-14, -18), Vector2(9, 36)), ink)
				draw_rect(Rect2(b.pos + Vector2(5, -18), Vector2(9, 36)), ink)
			_:
				var text := tr(b.label)
				var size := 40 if r > 100.0 else 32
				var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				draw_string(font, b.pos + Vector2(-w * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)


## A curved arrow: counter-clockwise when dir > 0.
func _draw_spin_arrow(c: Vector2, r: float, dir: float, ink: Color) -> void:
	var a0 := -PI * 0.9
	var a1 := PI * 0.4
	draw_arc(c, r, a0, a1, 24, ink, 6.0, true)
	var tip_angle := a1 if dir < 0.0 else a0
	var tip := c + Vector2(cos(tip_angle), sin(tip_angle)) * r
	var tangent := Vector2(-sin(tip_angle), cos(tip_angle)) * (1.0 if dir < 0.0 else -1.0)
	var normal := Vector2(cos(tip_angle), sin(tip_angle))
	draw_colored_polygon(PackedVector2Array([tip + tangent * 16.0, tip - normal * 12.0, tip + normal * 12.0]), ink)
